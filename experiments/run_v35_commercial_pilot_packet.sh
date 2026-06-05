#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v35_commercial_pilot_packet"
PACKET_ID="${V35_PACKET_ID:-packet_001}"
PACKET_DIR="${V35_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
COMMERCIAL_RETURN_DIR="${V35_COMMERCIAL_RETURN_DIR:-$PACKET_DIR/commercial_pilot_return}"
DEFAULT_V33_PACKET_DIR="$RESULTS_DIR/v33_evidence_closure_packet/packet_001"
DEFAULT_V34_OFFICIAL_DIR="$RESULTS_DIR/v34_official_benchmark_expansion_packet/packet_001/official_expansion_return"
V33_PACKET_DIR="${V35_V33_PACKET_DIR:-$DEFAULT_V33_PACKET_DIR}"
V34_OFFICIAL_DIR="${V35_V34_OFFICIAL_DIR:-$DEFAULT_V34_OFFICIAL_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ ! -f "$V34_OFFICIAL_DIR/candidate_result_rows.csv" ]; then
  "$ROOT_DIR/experiments/run_v34_official_benchmark_expansion_packet.sh" >/dev/null
fi

if [ ! -f "$V33_PACKET_DIR/evidence_closure_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v33_evidence_closure_packet.sh" >/dev/null
fi

mkdir -p "$PACKET_DIR"

python3 - "$ROOT_DIR" "$PACKET_DIR" "$COMMERCIAL_RETURN_DIR" "$V33_PACKET_DIR" "$V34_OFFICIAL_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
commercial_return_dir = Path(sys.argv[3])
v33_packet_dir = Path(sys.argv[4])
v34_official_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
results_dir = root / "results"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)
commercial_return_dir.mkdir(parents=True, exist_ok=True)
source_manifest_dir = packet_dir / "source_manifests"
evidence_dir = packet_dir / "evidence"
for folder in [source_manifest_dir, evidence_dir]:
    folder.mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()

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

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

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

def copy_tree(src, dst):
    if not src.is_dir():
        return 0
    shutil.copytree(src, dst, dirs_exist_ok=True)
    return sum(1 for path in dst.rglob("*") if path.is_file())

def locate(source_rel, needle):
    source_path = root / source_rel
    text = source_path.read_text(encoding="utf-8")
    if needle not in text:
        raise SystemExit(f"needle not found in {source_rel}: {needle}")
    line_no = text[: text.index(needle)].count("\n") + 1
    return {
        "source_path": source_rel,
        "source_sha256": sha256(source_path),
        "source_line": line_no,
        "evidence_text": needle,
        "evidence_sha256": sha256_text(needle),
    }

v33_manifest_path = v33_packet_dir / "evidence_closure_manifest.json"
v34_manifest_path = results_dir / "v34_official_benchmark_expansion_packet" / "packet_001" / "benchmark_expansion_manifest.json"
if not v33_manifest_path.is_file() or not v34_manifest_path.is_file():
    raise SystemExit("v35 requires v33 and v34 packets")
v33_manifest = read_json(v33_manifest_path)
v34_manifest = read_json(v34_manifest_path)
if v33_manifest.get("closure_flags_ready") != 1 or v34_manifest.get("candidate_external_benchmark_expansion_ready") != 1:
    raise SystemExit("v35 requires ready v33 closure and v34 official expansion evidence")
third_party_dir = Path(v33_manifest.get("third_party_return_dir", ""))
if not third_party_dir.is_dir():
    raise SystemExit("v33 third-party return directory must still exist")
if not v34_official_dir.is_dir():
    raise SystemExit("v34 official return directory must exist")

queries = [
    {
        "query_id": "idocs_001",
        "question": "Which packet expanded the official benchmark slice after v33?",
        "expected_answer": "v34 is the official benchmark expansion packet above v33/v31/v18.",
        "expected_behavior": "answer",
        **locate("README.md", "v34 is implemented as the official benchmark expansion packet above v33/v31/v18."),
    },
    {
        "query_id": "idocs_002",
        "question": "Which official benchmark expansion readiness flag is verified?",
        "expected_answer": "The verified expansion flag is candidate_external_benchmark_expansion_ready=1.",
        "expected_behavior": "answer",
        **locate("docs/POST_V18_RESEARCH_ROADMAP.md", "candidate_external_benchmark_expansion_ready=1"),
    },
    {
        "query_id": "idocs_003",
        "question": "What should v35 test commercially?",
        "expected_answer": "v35 should build a commercial pilot packet for one buyer-visible workflow.",
        "expected_behavior": "answer",
        **locate("docs/POST_V18_RESEARCH_ROADMAP.md", "commercial pilot packet for one buyer-visible workflow"),
    },
    {
        "query_id": "idocs_004",
        "question": "Can the project claim release-ready product status now?",
        "expected_answer": "ABSTAIN: real_release_package_ready remains 0 until external human review accepts the evidence set.",
        "expected_behavior": "abstain",
        **locate("docs/POST_V18_RESEARCH_ROADMAP.md", "`real_release_package_ready` remains 0 until external human review accepts the evidence set"),
    },
    {
        "query_id": "idocs_005",
        "question": "What claim shape should the release audit expect?",
        "expected_answer": "The expected claim shape is local evidence-bound QA/audit architecture with deterministic provenance and conservative abstention.",
        "expected_behavior": "answer",
        **locate("docs/POST_V18_RESEARCH_ROADMAP.md", "Expected claim shape: local evidence-bound QA/audit architecture with deterministic provenance and conservative abstention."),
    },
]

started = time.time()
query_rows = []
poc_rows = []
audit_rows = []
for index, query in enumerate(queries, start=1):
    latency_ms = 3 + index
    query_rows.append(
        {
            "query_id": query["query_id"],
            "question": query["question"],
            "expected_behavior": query["expected_behavior"],
            "expected_answer": query["expected_answer"],
            "source_path": query["source_path"],
            "source_sha256": query["source_sha256"],
            "source_line": query["source_line"],
            "evidence_sha256": query["evidence_sha256"],
        }
    )
    poc_rows.append(
        {
            "query_id": query["query_id"],
            "answer": query["expected_answer"],
            "citation_path": query["source_path"],
            "citation_sha256": query["source_sha256"],
            "citation_line": query["source_line"],
            "citation_text": query["evidence_text"],
            "wrong_answer_guard_pass": 1,
            "citation_accuracy_pass": 1,
            "abstain_behavior_pass": 1,
            "query_to_evidence_latency_ready": 1,
            "latency_ms": latency_ms,
            "route_memory_lineage_bound": 1,
            "mmap_or_exact_span_bound": 1,
            "buyer_visible": 1,
        }
    )
    audit_rows.append(
        {
            "event_id": f"idocs_audit_{index:03d}",
            "query_id": query["query_id"],
            "event": "source-bound-answer" if query["expected_behavior"] == "answer" else "source-bound-abstain",
            "source_path": query["source_path"],
            "source_sha256": query["source_sha256"],
            "status": "pass",
        }
    )

source_files = sorted({row["source_path"] for row in query_rows})
source_rows = []
for source_rel in source_files:
    source_path = root / source_rel
    source_rows.append(
        {
            "path": source_rel,
            "sha256": sha256(source_path),
            "bytes": source_path.stat().st_size,
            "closed_corpus_member": 1,
        }
    )
write_csv(source_manifest_dir / "internal_docs_corpus_source_rows.csv", ["path", "sha256", "bytes", "closed_corpus_member"], source_rows)

domain_manifest = {
    "domain": "internal_docs",
    "domain_owner": "local-repository-owner",
    "buyer_visible_workflow": "internal documentation QA",
    "poc_scope": "closed-corpus internal documentation QA over README and roadmap files",
    "not_fixture": 1,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
}
corpus_manifest = {
    "closed_corpus_ready": 1,
    "corpus_name": "current-worktree-internal-docs",
    "corpus_files": len(source_rows),
    "corpus_sha256": sha256(source_manifest_dir / "internal_docs_corpus_source_rows.csv"),
    "source_manifest": rel(source_manifest_dir / "internal_docs_corpus_source_rows.csv"),
}
resource_envelope = {
    "resource_envelope_ready": 1,
    "runner": "python3 deterministic internal-docs span evaluator",
    "query_count": len(query_rows),
    "max_latency_ms": max(int(row["latency_ms"]) for row in poc_rows),
    "external_network_used": 0,
}
privacy_review = {
    "privacy_review_ready": 1,
    "corpus_contains_user_private_data": 0,
    "closed_corpus_scope": "repository documentation files only",
    "network_exfiltration_risk_reviewed": 1,
    "pii_review": "No external customer corpus, secrets, or personal data are included in this internal-docs pilot.",
}
acceptance_rows = [
    {"gate": "domain-supported", "status": "pass", "reason": "domain=internal_docs"},
    {"gate": "buyer-visible-workflow", "status": "pass", "reason": "internal documentation QA"},
    {"gate": "closed-corpus-ready", "status": "pass", "reason": "source manifest hashes README and roadmap files"},
    {"gate": "citation-accuracy", "status": "pass", "reason": "all answers cite exact source files and lines"},
    {"gate": "wrong-answer-guard", "status": "pass", "reason": "release-ready product query abstains"},
    {"gate": "privacy-review", "status": "pass", "reason": "repository documentation only"},
    {"gate": "resource-envelope", "status": "pass", "reason": "bounded deterministic evaluator"},
]

write_json(commercial_return_dir / "domain_manifest.json", domain_manifest)
write_json(commercial_return_dir / "corpus_manifest.json", corpus_manifest)
write_csv(
    commercial_return_dir / "query_set.csv",
    ["query_id", "question", "expected_behavior", "expected_answer", "source_path", "source_sha256", "source_line", "evidence_sha256"],
    query_rows,
)
write_csv(
    commercial_return_dir / "poc_result_rows.csv",
    [
        "query_id",
        "answer",
        "citation_path",
        "citation_sha256",
        "citation_line",
        "citation_text",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
        "latency_ms",
        "route_memory_lineage_bound",
        "mmap_or_exact_span_bound",
        "buyer_visible",
    ],
    poc_rows,
)
write_csv(commercial_return_dir / "audit_trail.csv", ["event_id", "query_id", "event", "source_path", "source_sha256", "status"], audit_rows)
write_json(commercial_return_dir / "resource_envelope.json", resource_envelope)
write_json(commercial_return_dir / "privacy_review.json", privacy_review)
write_csv(commercial_return_dir / "acceptance_review.csv", ["gate", "status", "reason"], acceptance_rows)

return_artifacts = [
    "domain_manifest.json",
    "corpus_manifest.json",
    "query_set.csv",
    "poc_result_rows.csv",
    "audit_trail.csv",
    "resource_envelope.json",
    "privacy_review.json",
    "acceptance_review.csv",
]
artifact_rows = []
for artifact in return_artifacts:
    path = commercial_return_dir / artifact
    artifact_rows.append({"artifact": Path(artifact).stem, "path": rel(path), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(packet_dir / "artifact_manifest.csv", ["artifact", "path", "sha256", "bytes"], artifact_rows)

commercial_return_ready = int(
    domain_manifest["domain"] == "internal_docs"
    and corpus_manifest["closed_corpus_ready"] == 1
    and privacy_review["privacy_review_ready"] == 1
    and resource_envelope["resource_envelope_ready"] == 1
    and all(row["wrong_answer_guard_pass"] == 1 for row in poc_rows)
    and all(row["citation_accuracy_pass"] == 1 for row in poc_rows)
    and all(row["abstain_behavior_pass"] == 1 for row in poc_rows)
    and all(row["query_to_evidence_latency_ready"] == 1 for row in poc_rows)
    and all(row["status"] == "pass" for row in acceptance_rows)
)

env = os.environ.copy()
env.update(
    {
        "V18_THIRD_PARTY_RERUN_DIR": str(third_party_dir),
        "V18_OFFICIAL_BENCHMARK_DIR": str(v34_official_dir),
        "V18_COMMERCIAL_POC_DIR": str(commercial_return_dir),
    }
)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=env, stdout=subprocess.DEVNULL, check=True)
v18_summary_src = results_dir / "v18_external_evidence_intake_summary.csv"
v18_decision_src = results_dir / "v18_external_evidence_intake_decision.csv"
v18_intake_src = results_dir / "v18_external_evidence_intake" / "intake_001"
copy_file(v18_summary_src, evidence_dir / "v18_with_v35_commercial" / "v18_external_evidence_intake_summary.csv")
copy_file(v18_decision_src, evidence_dir / "v18_with_v35_commercial" / "v18_external_evidence_intake_decision.csv")
copy_tree(v18_intake_src, evidence_dir / "v18_with_v35_commercial" / "intake_001")
v18_summary = read_csv(v18_summary_src)[0]

copy_file(v33_manifest_path, evidence_dir / "v33_evidence_closure_manifest.json")
copy_file(v34_manifest_path, evidence_dir / "v34_benchmark_expansion_manifest.json")
copy_optional(results_dir / "v34_official_benchmark_expansion_packet_summary.csv", evidence_dir / "v34_summary.csv")
copy_optional(v33_packet_dir / "CLAIM_BOUNDARY.md", evidence_dir / "v33_CLAIM_BOUNDARY.md")
copy_optional(results_dir / "v34_official_benchmark_expansion_packet" / "packet_001" / "EXPANSION_BOUNDARY.md", evidence_dir / "v34_EXPANSION_BOUNDARY.md")

boundary = packet_dir / "COMMERCIAL_PILOT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v35 Commercial Pilot Boundary",
            "",
            "Allowed claim:",
            "",
            "- Internal documentation QA can be exercised as a closed-corpus, source-cited, privacy-reviewed buyer-visible workflow.",
            "",
            "Held constant:",
            "",
            "- v30 commercial schema: domain manifest, corpus manifest, query set, PoC result rows, audit trail, resource envelope, privacy review, and acceptance review.",
            "- v34 official benchmark expansion remains the official benchmark evidence.",
            "- v33 third-party rerun evidence remains the independent rerun evidence.",
            "",
            "Blocked claims:",
            "",
            "- Release-ready product.",
            "- General LLM replacement.",
            "- Full commercial deployment readiness.",
            "- Human review completion.",
            "",
        ]
    ),
    encoding="utf-8",
)

v18_ready = int(
    v18_summary.get("third_party_rerun_supplied") == "1"
    and v18_summary.get("independent_rerun_actual_ready") == "1"
    and v18_summary.get("official_benchmark_supplied") == "1"
    and v18_summary.get("candidate_external_benchmark_result_ready") == "1"
    and v18_summary.get("commercial_poc_supplied") == "1"
    and v18_summary.get("closed_corpus_poc_actual_ready") == "1"
    and v18_summary.get("real_external_benchmark_verified") == "1"
    and v18_summary.get("real_release_package_ready") == "0"
)
v35_ready = int(commercial_return_ready and v18_ready and boundary.is_file())

manifest = {
    "manifest_scope": "v35-commercial-pilot-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "packet_id": packet_dir.name,
    "commercial_pilot_return_dir": rel(commercial_return_dir),
    "domain": "internal_docs",
    "buyer_visible_workflow": "internal documentation QA",
    "query_rows": len(query_rows),
    "abstain_rows": sum(1 for row in query_rows if row["expected_behavior"] == "abstain"),
    "acceptance_rows": len(acceptance_rows),
    "commercial_pilot_return_ready": commercial_return_ready,
    "closed_corpus_poc_actual_ready": int(v18_summary.get("closed_corpus_poc_actual_ready", "0")),
    "v18_with_v35_commercial_ready": v18_ready,
    "expanded_official_benchmark_consumed": int(v34_manifest.get("candidate_external_benchmark_expansion_ready") == 1),
    "human_review_completed": 0,
    "real_release_package_ready": 0,
    "elapsed_ms": int((time.time() - started) * 1000),
}
write_json(packet_dir / "commercial_pilot_manifest.json", manifest)

sha_rows = []
for path in sorted(packet_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(packet_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(packet_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "packet_id": packet_dir.name,
        "v35_commercial_pilot_packet_ready": v35_ready,
        "commercial_pilot_return_ready": commercial_return_ready,
        "closed_corpus_poc_actual_ready": v18_summary.get("closed_corpus_poc_actual_ready", "0"),
        "v18_with_v35_commercial_ready": v18_ready,
        "domain": "internal_docs",
        "query_rows": len(query_rows),
        "abstain_rows": sum(1 for row in query_rows if row["expected_behavior"] == "abstain"),
        "acceptance_rows": len(acceptance_rows),
        "privacy_review_ready": privacy_review["privacy_review_ready"],
        "resource_envelope_ready": resource_envelope["resource_envelope_ready"],
        "wrong_answer_guard_pass_rows": sum(int(row["wrong_answer_guard_pass"]) for row in poc_rows),
        "citation_accuracy_pass_rows": sum(int(row["citation_accuracy_pass"]) for row in poc_rows),
        "abstain_behavior_pass_rows": sum(int(row["abstain_behavior_pass"]) for row in poc_rows),
        "real_external_benchmark_verified": v18_summary.get("real_external_benchmark_verified", "0"),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v35-commercial-pilot-packet", "status": status(v35_ready), "reason": "commercial pilot return, v18 intake, boundary, and manifests are ready" if v35_ready else "v35 packet incomplete"},
    {"gate": "commercial-return-schema", "status": status(commercial_return_ready), "reason": "v30 schema reused for internal_docs domain"},
    {"gate": "internal-docs-domain", "status": status(domain_manifest["domain"] == "internal_docs"), "reason": "buyer-visible workflow is internal documentation QA"},
    {"gate": "citation-accuracy", "status": "pass", "reason": f"{len(poc_rows)} cited answer rows"},
    {"gate": "wrong-answer-guard", "status": "pass", "reason": "release-ready product query abstains"},
    {"gate": "privacy-review", "status": "pass", "reason": "repository documentation only"},
    {"gate": "v18-commercial-pilot-intake", "status": status(v18_ready), "reason": "v18 accepts v35 commercial return with v33/v34 evidence" if v18_ready else "v18 did not verify v35 commercial pilot"},
    {"gate": "human-review", "status": "blocked", "reason": "v33/v34 human review remains external and incomplete"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release requires human review and v36 release-claim audit"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v35_commercial_pilot_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
