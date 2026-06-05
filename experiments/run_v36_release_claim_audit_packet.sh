#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v36_release_claim_audit_packet"
PACKET_ID="${V36_PACKET_ID:-packet_001}"
PACKET_DIR="${V36_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
DEFAULT_V33_PACKET_DIR="$RESULTS_DIR/v33_evidence_closure_packet/packet_001"
DEFAULT_V34_PACKET_DIR="$RESULTS_DIR/v34_official_benchmark_expansion_packet/packet_001"
DEFAULT_V35_PACKET_DIR="$RESULTS_DIR/v35_commercial_pilot_packet/packet_001"
V33_PACKET_DIR="${V36_V33_PACKET_DIR:-$DEFAULT_V33_PACKET_DIR}"
V34_PACKET_DIR="${V36_V34_PACKET_DIR:-$DEFAULT_V34_PACKET_DIR}"
V35_PACKET_DIR="${V36_V35_PACKET_DIR:-$DEFAULT_V35_PACKET_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ ! -f "$V35_PACKET_DIR/commercial_pilot_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v35_commercial_pilot_packet.sh" >/dev/null
fi

if [ ! -f "$V34_PACKET_DIR/benchmark_expansion_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v34_official_benchmark_expansion_packet.sh" >/dev/null
fi

if [ ! -f "$V33_PACKET_DIR/evidence_closure_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v33_evidence_closure_packet.sh" >/dev/null
fi

mkdir -p "$PACKET_DIR"

python3 - "$ROOT_DIR" "$PACKET_DIR" "$V33_PACKET_DIR" "$V34_PACKET_DIR" "$V35_PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
v33_packet_dir = Path(sys.argv[3])
v34_packet_dir = Path(sys.argv[4])
v35_packet_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
results_dir = root / "results"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)
evidence_dir = packet_dir / "evidence"
evidence_dir.mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_one_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}, got {len(rows)}")
    return rows[0]

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def copy_optional(src, dst):
    if not src.is_file():
        return 0
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return 1

v33_manifest = read_json(v33_packet_dir / "evidence_closure_manifest.json")
v34_manifest = read_json(v34_packet_dir / "benchmark_expansion_manifest.json")
v35_manifest = read_json(v35_packet_dir / "commercial_pilot_manifest.json")
v33_summary = read_one_csv(results_dir / "v33_evidence_closure_packet_summary.csv")
v34_summary = read_one_csv(results_dir / "v34_official_benchmark_expansion_packet_summary.csv")
v35_summary = read_one_csv(results_dir / "v35_commercial_pilot_packet_summary.csv")

copy_file(v33_packet_dir / "evidence_closure_manifest.json", evidence_dir / "v33" / "evidence_closure_manifest.json")
copy_file(results_dir / "v33_evidence_closure_packet_summary.csv", evidence_dir / "v33" / "summary.csv")
copy_file(results_dir / "v33_evidence_closure_packet_decision.csv", evidence_dir / "v33" / "decision.csv")
copy_optional(v33_packet_dir / "CLAIM_BOUNDARY.md", evidence_dir / "v33" / "CLAIM_BOUNDARY.md")
copy_optional(v33_packet_dir / "human_review" / "HUMAN_REVIEW_REQUEST.md", evidence_dir / "v33" / "HUMAN_REVIEW_REQUEST.md")

copy_file(v34_packet_dir / "benchmark_expansion_manifest.json", evidence_dir / "v34" / "benchmark_expansion_manifest.json")
copy_file(results_dir / "v34_official_benchmark_expansion_packet_summary.csv", evidence_dir / "v34" / "summary.csv")
copy_file(results_dir / "v34_official_benchmark_expansion_packet_decision.csv", evidence_dir / "v34" / "decision.csv")
copy_optional(v34_packet_dir / "EXPANSION_BOUNDARY.md", evidence_dir / "v34" / "EXPANSION_BOUNDARY.md")

copy_file(v35_packet_dir / "commercial_pilot_manifest.json", evidence_dir / "v35" / "commercial_pilot_manifest.json")
copy_file(results_dir / "v35_commercial_pilot_packet_summary.csv", evidence_dir / "v35" / "summary.csv")
copy_file(results_dir / "v35_commercial_pilot_packet_decision.csv", evidence_dir / "v35" / "decision.csv")
copy_optional(v35_packet_dir / "COMMERCIAL_PILOT_BOUNDARY.md", evidence_dir / "v35" / "COMMERCIAL_PILOT_BOUNDARY.md")

v33_ready = int(v33_summary.get("v33_evidence_closure_packet_ready") == "1" and v33_manifest.get("closure_flags_ready") == 1)
v34_ready = int(v34_summary.get("v34_official_benchmark_expansion_packet_ready") == "1" and v34_manifest.get("candidate_external_benchmark_expansion_ready") == 1)
v35_ready = int(v35_summary.get("v35_commercial_pilot_packet_ready") == "1" and v35_manifest.get("commercial_pilot_return_ready") == 1)
evidence_inputs_ready = int(v33_ready and v34_ready and v35_ready)
human_review_completed = 0
real_release_package_ready = 0
maximum_allowed_claim = "local evidence-bound QA/audit architecture with deterministic provenance, source-cited answers, conservative abstention, and externally reproducible evidence packets"

claim_rows = [
    {
        "claim_id": "bounded-local-qa-audit-architecture",
        "status": "allowed_limited",
        "public_wording": maximum_allowed_claim,
        "evidence": "v33 closure + v34 official RULER NIAH expansion + v35 internal-docs commercial pilot",
        "reason": "all evidence inputs are packeted and v18-verifiable; claim stays local/evidence-bound",
    },
    {
        "claim_id": "official-benchmark-expansion",
        "status": "allowed_limited",
        "public_wording": "first official RULER NIAH expansion slice, 6 raw prediction rows at fixed context length",
        "evidence": "v34 benchmark_expansion_manifest.json",
        "reason": "one-axis expansion is verified but is not a full benchmark or leaderboard result",
    },
    {
        "claim_id": "commercial-internal-docs-pilot",
        "status": "allowed_limited",
        "public_wording": "internal documentation QA pilot with citations, abstention, privacy review, and audit trail",
        "evidence": "v35 commercial_pilot_manifest.json",
        "reason": "supported internal_docs domain passes v18 commercial PoC intake",
    },
    {
        "claim_id": "release-ready-product",
        "status": "blocked",
        "public_wording": "",
        "evidence": "human_review_completed=0 and real_release_package_ready=0",
        "reason": "requires human review and separate release readiness, neither is complete",
    },
    {
        "claim_id": "general-llm-replacement",
        "status": "blocked",
        "public_wording": "",
        "evidence": "v33/v34/v35 claim boundaries",
        "reason": "evidence supports bounded QA/audit only",
    },
    {
        "claim_id": "transformer-replacement",
        "status": "blocked",
        "public_wording": "",
        "evidence": "v33/v34/v35 claim boundaries",
        "reason": "no comparative architecture-replacement evidence",
    },
    {
        "claim_id": "frontier-long-context-solved",
        "status": "blocked",
        "public_wording": "",
        "evidence": "v34 fixed-slice RULER NIAH expansion",
        "reason": "single-family small expansion is not a frontier long-context result",
    },
    {
        "claim_id": "gpu-acceleration",
        "status": "blocked",
        "public_wording": "",
        "evidence": "no real workload-speed evidence in v33/v34/v35",
        "reason": "release audit does not consume real GPU speed evidence",
    },
    {
        "claim_id": "full-commercial-deployment-ready",
        "status": "blocked",
        "public_wording": "",
        "evidence": "v35 is one pilot workflow",
        "reason": "pilot evidence is not deployment readiness",
    },
]
write_csv(packet_dir / "claim_matrix.csv", ["claim_id", "status", "public_wording", "evidence", "reason"], claim_rows)

evidence_rows = [
    {
        "input_id": "v33",
        "path": rel(v33_packet_dir),
        "ready": v33_ready,
        "summary_flag": v33_summary.get("v33_evidence_closure_packet_ready", "0"),
        "release_ready": v33_summary.get("real_release_package_ready", "0"),
        "human_review_completed": v33_summary.get("human_review_completed", "0"),
    },
    {
        "input_id": "v34",
        "path": rel(v34_packet_dir),
        "ready": v34_ready,
        "summary_flag": v34_summary.get("v34_official_benchmark_expansion_packet_ready", "0"),
        "release_ready": v34_summary.get("real_release_package_ready", "0"),
        "human_review_completed": v34_summary.get("human_review_completed", "0"),
    },
    {
        "input_id": "v35",
        "path": rel(v35_packet_dir),
        "ready": v35_ready,
        "summary_flag": v35_summary.get("v35_commercial_pilot_packet_ready", "0"),
        "release_ready": v35_summary.get("real_release_package_ready", "0"),
        "human_review_completed": v35_summary.get("human_review_completed", "0"),
    },
]
write_csv(packet_dir / "evidence_input_rows.csv", ["input_id", "path", "ready", "summary_flag", "release_ready", "human_review_completed"], evidence_rows)

allowed_rows = [row for row in claim_rows if row["status"].startswith("allowed")]
blocked_rows = [row for row in claim_rows if row["status"] == "blocked"]
release_decision_rows = [
    {"gate": "evidence-inputs", "status": "pass" if evidence_inputs_ready else "blocked", "reason": "v33/v34/v35 packets are ready" if evidence_inputs_ready else "one or more evidence packets are missing"},
    {"gate": "maximum-allowed-public-claim", "status": "pass", "reason": "bounded local evidence-bound QA/audit wording is selected"},
    {"gate": "overclaim-guard", "status": "pass", "reason": f"{len(blocked_rows)} stronger claims remain blocked"},
    {"gate": "human-review", "status": "blocked", "reason": "external human review has not been completed"},
    {"gate": "real-release-package", "status": "blocked", "reason": "real_release_package_ready remains 0"},
    {"gate": "release-ready-product", "status": "blocked", "reason": "product release requires human review and release readiness evidence"},
]
write_csv(packet_dir / "release_decision_rows.csv", ["gate", "status", "reason"], release_decision_rows)

audit_md = packet_dir / "RELEASE_CLAIM_AUDIT.md"
audit_md.write_text(
    "\n".join(
        [
            "# v36 Release Claim Audit",
            "",
            "Maximum allowed public claim:",
            "",
            f"- {maximum_allowed_claim}.",
            "",
            "Allowed with limits:",
            "",
            "- v33/v34/v35 support a bounded local QA/audit architecture claim.",
            "- v34 supports a first official RULER NIAH expansion slice claim.",
            "- v35 supports one internal-documentation commercial pilot claim.",
            "",
            "Blocked:",
            "",
            "- Release-ready product.",
            "- General LLM replacement.",
            "- Transformer replacement.",
            "- Frontier long-context solved.",
            "- GPU acceleration.",
            "- Full commercial deployment readiness.",
            "",
            "Decision:",
            "",
            "`real_release_package_ready` remains 0 because human review is incomplete and no release-readiness evidence has been approved.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v36-release-claim-audit-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "packet_id": packet_dir.name,
    "v33_ready": v33_ready,
    "v34_ready": v34_ready,
    "v35_ready": v35_ready,
    "evidence_inputs_ready": evidence_inputs_ready,
    "maximum_allowed_claim_decided": 1,
    "maximum_allowed_claim": maximum_allowed_claim,
    "allowed_claim_rows": len(allowed_rows),
    "blocked_claim_rows": len(blocked_rows),
    "human_review_completed": human_review_completed,
    "real_release_package_ready": real_release_package_ready,
    "release_recommendation": "do-not-release-product",
}
write_json(packet_dir / "v36_release_claim_audit_manifest.json", manifest)

sha_rows = []
for path in sorted(packet_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(packet_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(packet_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

v36_ready = int(evidence_inputs_ready and len(allowed_rows) > 0 and len(blocked_rows) >= 5 and audit_md.is_file())
summary_rows = [
    {
        "packet_id": packet_dir.name,
        "v36_release_claim_audit_packet_ready": v36_ready,
        "evidence_inputs_ready": evidence_inputs_ready,
        "maximum_allowed_claim_decided": 1,
        "v33_evidence_closure_packet_ready": v33_ready,
        "v34_official_benchmark_expansion_packet_ready": v34_ready,
        "v35_commercial_pilot_packet_ready": v35_ready,
        "allowed_claim_rows": len(allowed_rows),
        "blocked_claim_rows": len(blocked_rows),
        "human_review_completed": human_review_completed,
        "real_release_package_ready": real_release_package_ready,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

decision_rows = [
    {"gate": "v36-release-claim-audit-packet", "status": "pass" if v36_ready else "blocked", "reason": "release claim audit packet is ready" if v36_ready else "release claim audit packet incomplete"},
    *release_decision_rows,
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v36_release_claim_audit_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
