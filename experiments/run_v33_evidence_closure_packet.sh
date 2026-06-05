#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v33_evidence_closure_packet"
PACKET_ID="${V33_PACKET_ID:-packet_001}"
PACKET_DIR="${V33_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
THIRD_PARTY_DIR="${V33_THIRD_PARTY_RERUN_DIR:-}"
DEFAULT_OFFICIAL_BENCHMARK_DIR="$RESULTS_DIR/v31_official_ruler_niah_candidate_return/return_001/official_return"
DEFAULT_COMMERCIAL_POC_DIR="$RESULTS_DIR/v30_commercial_codebase_poc_return/return_001/commercial_return"
OFFICIAL_BENCHMARK_DIR="${V33_OFFICIAL_BENCHMARK_DIR:-$DEFAULT_OFFICIAL_BENCHMARK_DIR}"
COMMERCIAL_POC_DIR="${V33_COMMERCIAL_POC_DIR:-$DEFAULT_COMMERCIAL_POC_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ -z "$THIRD_PARTY_DIR" ]; then
  THIRD_PARTY_DIR="$(find "$RESULTS_DIR/v32_github_actions_third_party_rerun_kit/kit_001" -type d -path "*/github_actions_third_party_rerun/*/third_party_return" 2>/dev/null | sort -V | tail -1 || true)"
fi

mkdir -p "$PACKET_DIR"

if [ "${V33_REFRESH_COMMERCIAL_POC:-1}" = "1" ] && [ "$COMMERCIAL_POC_DIR" = "$DEFAULT_COMMERCIAL_POC_DIR" ]; then
  "$ROOT_DIR/experiments/run_v30_commercial_codebase_poc_return.sh" >/dev/null
fi

V18_THIRD_PARTY_RERUN_DIR="$THIRD_PARTY_DIR" \
V18_OFFICIAL_BENCHMARK_DIR="$OFFICIAL_BENCHMARK_DIR" \
V18_COMMERCIAL_POC_DIR="$COMMERCIAL_POC_DIR" \
  "$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKET_DIR" "$THIRD_PARTY_DIR" "$OFFICIAL_BENCHMARK_DIR" "$COMMERCIAL_POC_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
third_party_dir = Path(sys.argv[3]) if sys.argv[3] else Path()
official_dir = Path(sys.argv[4])
commercial_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
results_dir = root / "results"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def copy_file(src, dst):
    if not src.is_file():
        return 0
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return 1

def copy_tree(src, dst):
    if not src.is_dir():
        return 0
    shutil.copytree(src, dst, dirs_exist_ok=True)
    return sum(1 for path in dst.rglob("*") if path.is_file())

def read_one_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}, got {len(rows)}")
    return rows[0]

def is_one(row, field):
    return row.get(field) == "1"

v18_summary_src = results_dir / "v18_external_evidence_intake_summary.csv"
v18_decision_src = results_dir / "v18_external_evidence_intake_decision.csv"
v18_intake_src = results_dir / "v18_external_evidence_intake" / "intake_001"
v18_summary = read_one_csv(v18_summary_src)

evidence_dir = packet_dir / "evidence"
v18_dir = evidence_dir / "v18_intake"
third_party_files = copy_tree(third_party_dir, evidence_dir / "third_party_return") if third_party_dir else 0
official_files = copy_tree(official_dir, evidence_dir / "official_candidate_return")
commercial_files = copy_tree(commercial_dir, evidence_dir / "commercial_poc_return")
v18_intake_files = copy_tree(v18_intake_src, v18_dir / "intake_001")
v18_summary_copied = copy_file(v18_summary_src, v18_dir / "v18_external_evidence_intake_summary.csv")
v18_decision_copied = copy_file(v18_decision_src, v18_dir / "v18_external_evidence_intake_decision.csv")

claim_boundary = packet_dir / "CLAIM_BOUNDARY.md"
claim_boundary.write_text(
    "\n".join(
        [
            "# v33 Evidence Closure Claim Boundary",
            "",
            "Allowed claim:",
            "",
            "- Local evidence-bound QA/audit architecture with deterministic provenance, source-grounded answer lineage, conservative abstention, and externally reproducible evaluation packets.",
            "",
            "Current supporting evidence:",
            "",
            f"- Third-party clean-runner return copied from `{third_party_dir}`.",
            f"- Official benchmark candidate return copied from `{official_dir}`.",
            f"- Commercial closed-corpus PoC return copied from `{commercial_dir}`.",
            "- v18 verifies independent rerun, official benchmark candidate, commercial PoC, and real external benchmark evidence together.",
            "",
            "Blocked claims:",
            "",
            "- General LLM replacement.",
            "- Transformer replacement.",
            "- Frontier long-context model claim.",
            "- Learned sparse routing solved.",
            "- GPU acceleration claim.",
            "- Release-ready product or publishable release package.",
            "",
            "Release boundary:",
            "",
            "`real_release_package_ready` remains 0 until a separate release audit packet consumes v33, broader benchmark evidence, commercial pilot evidence, privacy/reliability review, and an explicit release-claim decision.",
            "",
        ]
    ),
    encoding="utf-8",
)

review_dir = packet_dir / "human_review"
review_dir.mkdir(parents=True, exist_ok=True)
(review_dir / "HUMAN_REVIEW_REQUEST.md").write_text(
    "\n".join(
        [
            "# v33 Human Review Request",
            "",
            "Review questions:",
            "",
            "1. Is the GitHub-hosted runner identity acceptable as clean-machine third-party rerun evidence for this stage?",
            "2. Do the copied v18 summary and decision rows support the allowed claim boundary?",
            "3. Are any copied artifacts missing, stale, or inconsistent with the sha256 manifest?",
            "4. Should the next step be a non-GitHub human rerun, broader official benchmark expansion, or a second commercial PoC?",
            "",
            "Return `human_review_rows.csv` using the template in this directory.",
            "",
        ]
    ),
    encoding="utf-8",
)
write_csv(
    review_dir / "human_review_template.csv",
    ["review_item", "status", "reason", "reviewer", "review_timestamp_utc"],
    [
        {"review_item": "github-runner-clean-machine-acceptability", "status": "", "reason": "", "reviewer": "", "review_timestamp_utc": ""},
        {"review_item": "claim-boundary-support", "status": "", "reason": "", "reviewer": "", "review_timestamp_utc": ""},
        {"review_item": "artifact-completeness", "status": "", "reason": "", "reviewer": "", "review_timestamp_utc": ""},
        {"review_item": "next-step-recommendation", "status": "", "reason": "", "reviewer": "", "review_timestamp_utc": ""},
    ],
)

closure_flags_ready = all(
    [
        is_one(v18_summary, "third_party_rerun_supplied"),
        is_one(v18_summary, "independent_rerun_actual_ready"),
        is_one(v18_summary, "official_benchmark_supplied"),
        is_one(v18_summary, "candidate_external_benchmark_result_ready"),
        is_one(v18_summary, "commercial_poc_supplied"),
        is_one(v18_summary, "closed_corpus_poc_actual_ready"),
        is_one(v18_summary, "real_external_benchmark_verified"),
        v18_summary.get("real_release_package_ready") == "0",
    ]
)
copies_ready = all([third_party_files > 0, official_files > 0, commercial_files > 0, v18_summary_copied, v18_decision_copied, v18_intake_files > 0])

manifest = {
    "manifest_scope": "v33-evidence-closure-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "packet_id": packet_dir.name,
    "third_party_return_dir": str(third_party_dir),
    "official_candidate_return_dir": str(official_dir),
    "commercial_poc_return_dir": str(commercial_dir),
    "v18_summary": v18_summary,
    "closure_flags_ready": int(closure_flags_ready),
    "copies_ready": int(copies_ready),
    "human_review_completed": 0,
    "allowed_claim": "local evidence-bound QA/audit architecture with deterministic provenance and conservative abstention",
    "blocked_claims": [
        "general LLM replacement",
        "Transformer replacement",
        "frontier long-context model",
        "learned sparse routing solved",
        "GPU acceleration",
        "release-ready product",
    ],
}
(packet_dir / "evidence_closure_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(packet_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    rel = path.relative_to(packet_dir)
    sha_rows.append({"path": str(rel), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(packet_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

sha_manifest_ready = int(len(sha_rows) > 0 and (packet_dir / "sha256_manifest.csv").is_file())
claim_boundary_ready = int(claim_boundary.is_file() and "Blocked claims:" in claim_boundary.read_text(encoding="utf-8"))
human_review_request_ready = int((review_dir / "HUMAN_REVIEW_REQUEST.md").is_file() and (review_dir / "human_review_template.csv").is_file())
v33_ready = int(all([closure_flags_ready, copies_ready, sha_manifest_ready, claim_boundary_ready, human_review_request_ready]))

summary_rows = [
    {
        "packet_id": packet_dir.name,
        "v33_evidence_closure_packet_ready": v33_ready,
        "third_party_return_copied": int(third_party_files > 0),
        "official_candidate_return_copied": int(official_files > 0),
        "commercial_poc_return_copied": int(commercial_files > 0),
        "v18_summary_copied": int(v18_summary_copied),
        "v18_decision_copied": int(v18_decision_copied),
        "sha256_manifest_ready": sha_manifest_ready,
        "claim_boundary_ready": claim_boundary_ready,
        "human_review_request_ready": human_review_request_ready,
        "human_review_completed": 0,
        "independent_rerun_actual_ready": v18_summary.get("independent_rerun_actual_ready", "0"),
        "candidate_external_benchmark_result_ready": v18_summary.get("candidate_external_benchmark_result_ready", "0"),
        "closed_corpus_poc_actual_ready": v18_summary.get("closed_corpus_poc_actual_ready", "0"),
        "real_external_benchmark_verified": v18_summary.get("real_external_benchmark_verified", "0"),
        "real_release_package_ready": v18_summary.get("real_release_package_ready", "0"),
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v33-evidence-closure-packet", "status": status(v33_ready), "reason": "v18 closure flags, copied evidence, claim boundary, and sha256 manifest are present" if v33_ready else "packet missing required closure evidence"},
    {"gate": "v18-closure-flags", "status": status(closure_flags_ready), "reason": "v18 verifies third-party rerun, official candidate, commercial PoC, and real external benchmark together"},
    {"gate": "third-party-return-copy", "status": status(third_party_files > 0), "reason": f"copied {third_party_files} files"},
    {"gate": "official-candidate-return-copy", "status": status(official_files > 0), "reason": f"copied {official_files} files"},
    {"gate": "commercial-poc-return-copy", "status": status(commercial_files > 0), "reason": f"copied {commercial_files} files"},
    {"gate": "claim-boundary", "status": status(claim_boundary_ready), "reason": "allowed and blocked claims are explicit"},
    {"gate": "sha256-manifest", "status": status(sha_manifest_ready), "reason": f"{len(sha_rows)} packet files hashed"},
    {"gate": "human-review", "status": "blocked", "reason": "next roadmap step; use human_review/HUMAN_REVIEW_REQUEST.md"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release requires v33 plus broader benchmark/commercial evidence and release audit"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v33_evidence_closure_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
