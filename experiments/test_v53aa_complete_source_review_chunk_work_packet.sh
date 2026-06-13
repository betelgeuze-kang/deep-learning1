#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53aa_complete_source_review_chunk_work_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/work_packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AA_REUSE_EXISTING="${V53AA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53aa_complete_source_review_chunk_work_packet.sh" >/dev/null

"$RUN_DIR/operator_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53aa_complete_source_review_chunk_work_packet_ready": "1",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "review_chunk_rows": "21",
    "ready_review_chunk_dispatch_rows": "21",
    "review_chunk_task_rows": "8000",
    "human_review_chunk_task_rows": "7000",
    "adjudication_chunk_task_rows": "1000",
    "review_chunk_return_artifact_rows": "50",
    "human_review_chunk_artifact_rows": "7",
    "adjudication_chunk_artifact_rows": "1",
    "reviewer_identity_chunk_artifact_rows": "21",
    "reviewer_conflict_chunk_artifact_rows": "21",
    "aggregate_review_return_artifact_rows": "5",
    "operator_chunk_packet_rows": "21",
    "ready_operator_chunk_packet_rows": "21",
    "operator_packet_file_rows": "72",
    "ready_operator_packet_file_rows": "72",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "answer_review_accepted_rows": "0",
    "review_return_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53aa {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_review_chunk_packet_rows.csv",
    "complete_source_review_chunk_packet_file_rows.csv",
    "complete_source_review_chunk_packet_requirement_rows.csv",
    "complete_source_review_chunk_packet_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AA_COMPLETE_SOURCE_REVIEW_CHUNK_WORK_PACKET_BOUNDARY.md",
    "v53aa_complete_source_review_chunk_work_packet_manifest.json",
    "operator_packet/README.md",
    "operator_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh",
    "operator_packet/CHUNK_PACKET_INDEX.csv",
    "operator_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv",
    "operator_packet/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json",
    "source_v53w/review_return_chunk_execution_rows.csv",
    "source_v53w/review_return_chunk_task_rows.csv",
    "source_v53w/review_return_chunk_artifact_rows.csv",
    "source_v53w/review_return_aggregate_artifact_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53aa artifact: {rel}")

packet_rows = read_csv(run_dir / "complete_source_review_chunk_packet_rows.csv")
file_rows = read_csv(run_dir / "complete_source_review_chunk_packet_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_chunk_packet_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_chunk_packet_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(packet_rows) != 21:
    raise SystemExit("v53aa expected 21 chunk packet rows")
if any(row["packet_ready"] != "1" for row in packet_rows):
    raise SystemExit("v53aa expected all chunk packets ready")
if sum(int(row["task_rows"]) for row in packet_rows) != 8000:
    raise SystemExit("v53aa task row sum mismatch")
if sum(int(row["expected_human_review_rows"]) for row in packet_rows) != 7000:
    raise SystemExit("v53aa human row sum mismatch")
if sum(int(row["expected_adjudication_rows"]) for row in packet_rows) != 1000:
    raise SystemExit("v53aa adjudication row sum mismatch")
if sum(int(row["required_return_artifacts"]) for row in packet_rows) != 50:
    raise SystemExit("v53aa required return artifact sum mismatch")
scope_counts = Counter(row["review_scope"] for row in packet_rows)
if scope_counts["primary-source-review"] != 7:
    raise SystemExit(f"v53aa primary chunk count mismatch: {scope_counts}")
if scope_counts["secondary-adjudication-review"] != 7:
    raise SystemExit(f"v53aa secondary chunk count mismatch: {scope_counts}")
if scope_counts["conflict-and-policy-review"] != 7:
    raise SystemExit(f"v53aa conflict chunk count mismatch: {scope_counts}")
if len(file_rows) != 72 or any(row["file_ready"] != "1" for row in file_rows):
    raise SystemExit("v53aa packet file readiness mismatch")

for row in packet_rows:
    chunk_dir = run_dir / "operator_packet" / row["packet_dir"]
    task_rows = read_csv(chunk_dir / "REVIEW_TASK_ROWS.csv")
    artifact_rows = read_csv(chunk_dir / "REQUIRED_RETURN_ARTIFACTS.csv")
    if len(task_rows) != int(row["task_rows"]):
        raise SystemExit(f"v53aa chunk task count mismatch: {row['review_chunk_id']}")
    if len(artifact_rows) != int(row["required_return_artifacts"]):
        raise SystemExit(f"v53aa chunk artifact count mismatch: {row['review_chunk_id']}")

for field, value in expected.items():
    if field.startswith("v53aa_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53aa metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53w-chunk-queue-input",
    "chunk-packet-index",
    "chunk-task-export",
    "chunk-return-artifact-map",
    "operator-packet-files",
    "manifest-only-no-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53aa requirement should pass: {requirement_id}")
for requirement_id in ["review-return-accepted", "v53-ready"]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53aa requirement should stay blocked: {requirement_id}")

for gate in ["v53w-chunk-queue-input", "chunk-work-packet", "operator-packet-files"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53aa gate should pass: {gate}")
for gate in ["review-return-accepted", "v53-ready", "v1-comparison", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53aa gate should stay blocked: {gate}")

if gaps["chunk-work-packet"] != "ready":
    raise SystemExit("v53aa chunk-work-packet gap should be ready")
for gap in ["review-return-accepted", "v53-ready", "v1-comparison"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53aa gap should stay blocked: {gap}")

boundary = (run_dir / "V53AA_COMPLETE_SOURCE_REVIEW_CHUNK_WORK_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_chunk_rows=21",
    "ready_review_chunk_dispatch_rows=21",
    "review_chunk_task_rows=8000",
    "human_review_chunk_task_rows=7000",
    "adjudication_chunk_task_rows=1000",
    "review_chunk_return_artifact_rows=50",
    "aggregate_review_return_artifact_rows=5",
    "operator_chunk_packet_rows=21",
    "ready_operator_chunk_packet_rows=21",
    "operator_packet_file_rows=72",
    "ready_operator_packet_file_rows=72",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "review_return_ready=0",
    "v53_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53aa boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53aa_complete_source_review_chunk_work_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53aa_complete_source_review_chunk_work_packet_ready") != 1:
    raise SystemExit("v53aa manifest readiness mismatch")
if manifest.get("operator_chunk_packet_rows") != 21:
    raise SystemExit("v53aa manifest chunk count mismatch")
if manifest.get("ready_operator_packet_file_rows") != 72:
    raise SystemExit("v53aa manifest file count mismatch")
if manifest.get("answer_review_accepted_rows") != 0:
    raise SystemExit("v53aa manifest must keep review accepted rows at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53aa manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53aa sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53aa produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53aa complete-source review chunk work packet smoke passed"
