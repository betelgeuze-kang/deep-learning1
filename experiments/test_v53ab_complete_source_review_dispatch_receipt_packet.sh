#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ab_complete_source_review_dispatch_receipt_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/dispatch_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AB_REUSE_EXISTING="${V53AB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ab_complete_source_review_dispatch_receipt_packet.sh" >/dev/null

"$RUN_DIR/operator_dispatch/VERIFY_REVIEW_DISPATCH_PACKET.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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
    "v53ab_complete_source_review_dispatch_receipt_packet_ready": "1",
    "v53aa_complete_source_review_chunk_work_packet_ready": "1",
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "dispatch_chunk_rows": "21",
    "ready_dispatch_chunk_rows": "21",
    "dispatch_task_rows": "8000",
    "dispatch_return_artifact_rows": "50",
    "aggregate_review_return_artifact_rows": "5",
    "dispatch_receipt_template_rows": "21",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_command_rows": "5",
    "ready_dispatch_command_rows": "3",
    "dispatch_package_file_rows": "8",
    "ready_dispatch_package_file_rows": "8",
    "embedded_work_packet_file_rows": "72",
    "ready_embedded_work_packet_file_rows": "72",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "review_return_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "v61_review_unblock_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ab {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_review_dispatch_chunk_rows.csv",
    "complete_source_review_dispatch_receipt_template_rows.csv",
    "complete_source_review_return_handoff_artifact_rows.csv",
    "complete_source_review_dispatch_command_rows.csv",
    "complete_source_review_dispatch_file_rows.csv",
    "complete_source_review_dispatch_requirement_rows.csv",
    "complete_source_review_dispatch_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AB_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_PACKET_BOUNDARY.md",
    "v53ab_complete_source_review_dispatch_receipt_packet_manifest.json",
    "operator_dispatch/README.md",
    "operator_dispatch/VERIFY_REVIEW_DISPATCH_PACKET.sh",
    "operator_dispatch/DISPATCH_CHUNK_ROWS.csv",
    "operator_dispatch/DISPATCH_RECEIPT_TEMPLATE_ROWS.csv",
    "operator_dispatch/REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv",
    "operator_dispatch/REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv",
    "operator_dispatch/review_work_packet/CHUNK_PACKET_INDEX.csv",
    "operator_dispatch/review_work_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv",
    "source_v53aa/v53aa_complete_source_review_chunk_work_packet_summary.csv",
    "source_v61df/v61df_external_review_generation_return_operator_packet_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ab artifact: {rel}")

dispatch_rows = read_csv(run_dir / "complete_source_review_dispatch_chunk_rows.csv")
receipt_rows = read_csv(run_dir / "complete_source_review_dispatch_receipt_template_rows.csv")
handoff_rows = read_csv(run_dir / "complete_source_review_return_handoff_artifact_rows.csv")
command_rows = read_csv(run_dir / "complete_source_review_dispatch_command_rows.csv")
file_rows = read_csv(run_dir / "complete_source_review_dispatch_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_dispatch_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_dispatch_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(dispatch_rows) != 21:
    raise SystemExit("v53ab expected 21 dispatch rows")
if any(row["dispatch_status"] != "ready-for-external-review" for row in dispatch_rows):
    raise SystemExit("v53ab dispatch rows must be ready")
if sum(int(row["task_rows"]) for row in dispatch_rows) != 8000:
    raise SystemExit("v53ab dispatch task sum mismatch")
if sum(int(row["required_return_artifacts"]) for row in dispatch_rows) != 50:
    raise SystemExit("v53ab dispatch return artifact sum mismatch")
if len(receipt_rows) != 21 or any(row["receipt_accepted"] != "0" for row in receipt_rows):
    raise SystemExit("v53ab receipt rows mismatch")
if len(handoff_rows) != 5 or any(row["accepted_rows"] != "0" for row in handoff_rows):
    raise SystemExit("v53ab handoff rows mismatch")
if len(command_rows) != 5:
    raise SystemExit("v53ab command row count mismatch")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "1", "0", "0"]:
    raise SystemExit("v53ab command readiness mismatch")
if len(file_rows) != 8 or any(row["file_ready"] != "1" for row in file_rows):
    raise SystemExit("v53ab file row readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53ab_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ab metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53aa-work-packet-input",
    "v61df-external-return-input",
    "dispatch-chunk-packet",
    "embedded-work-packet-files",
    "dispatch-package-files",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ab requirement should pass: {requirement_id}")
for requirement_id in [
    "dispatch-receipts-accepted",
    "review-return-accepted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ab requirement should stay blocked: {requirement_id}")

for gate in ["v53aa-work-packet-input", "v61df-external-return-input", "dispatch-packet"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ab decision should pass: {gate}")
for gate in ["dispatch-receipts", "review-return-accepted", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ab decision should stay blocked: {gate}")

if gaps.get("dispatch-packet") != "ready":
    raise SystemExit("v53ab dispatch-packet gap should be ready")
for gap in ["dispatch-receipts", "review-return-accepted", "v61-review-unblock"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ab gap should stay blocked: {gap}")

boundary = (run_dir / "V53AB_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "dispatch_chunk_rows=21",
    "ready_dispatch_chunk_rows=21",
    "dispatch_task_rows=8000",
    "dispatch_return_artifact_rows=50",
    "aggregate_review_return_artifact_rows=5",
    "dispatch_receipt_template_rows=21",
    "accepted_dispatch_receipt_rows=0",
    "dispatch_package_file_rows=8",
    "ready_dispatch_package_file_rows=8",
    "embedded_work_packet_file_rows=72",
    "ready_embedded_work_packet_file_rows=72",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "review_return_ready=0",
    "v53_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ab boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ab_complete_source_review_dispatch_receipt_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ab_complete_source_review_dispatch_receipt_packet_ready") != 1:
    raise SystemExit("v53ab manifest readiness mismatch")
if manifest.get("ready_dispatch_chunk_rows") != 21:
    raise SystemExit("v53ab manifest dispatch readiness mismatch")
if manifest.get("accepted_dispatch_receipt_rows") != 0:
    raise SystemExit("v53ab manifest must keep receipts at zero")
if manifest.get("answer_review_accepted_rows") != 0:
    raise SystemExit("v53ab manifest must keep accepted review rows at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ab manifest must keep generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53ab manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ab sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ab produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ab complete-source review dispatch receipt packet smoke passed"
