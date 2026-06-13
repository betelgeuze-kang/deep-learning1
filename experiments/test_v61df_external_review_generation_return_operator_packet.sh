#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61df_external_review_generation_return_operator_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DF_REUSE_EXISTING="${V61DF_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null

"$RUN_DIR/operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh" >/dev/null

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
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    "operator_stage_rows": "7",
    "ready_operator_stage_rows": "3",
    "blocked_operator_stage_rows": "4",
    "operator_command_rows": "6",
    "ready_operator_command_rows": "3",
    "operator_packet_file_rows": "8",
    "ready_operator_packet_file_rows": "8",
    "review_return_required_artifacts": "5",
    "generation_result_required_artifacts": "5",
    "review_chunk_rows": "21",
    "review_chunk_task_rows": "8000",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "runtime_admission_accepted_rows": "1000",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61df": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61df {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_operator_stage_rows.csv",
    "external_return_operator_command_rows.csv",
    "external_return_operator_packet_file_rows.csv",
    "external_return_operator_requirement_rows.csv",
    "external_return_operator_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DF_EXTERNAL_REVIEW_GENERATION_RETURN_OPERATOR_PACKET_BOUNDARY.md",
    "v61df_external_review_generation_return_operator_packet_manifest.json",
    "operator_packet/README.md",
    "operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh",
    "operator_packet/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    "operator_packet/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv",
    "operator_packet/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json",
    "operator_packet/generation_templates/GENERATION_RESULT_RETURN_TEMPLATE.csv",
    "operator_packet/generation_templates/GENERATION_EXECUTION_ENV.template",
    "source_v53z/review_return_v61_handoff_stage_rows.csv",
    "source_v61de/post_review_generation_result_handoff_stage_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61df artifact: {rel}")

stage_rows = read_csv(run_dir / "external_return_operator_stage_rows.csv")
command_rows = read_csv(run_dir / "external_return_operator_command_rows.csv")
file_rows = read_csv(run_dir / "external_return_operator_packet_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_operator_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_operator_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(stage_rows) != 7:
    raise SystemExit("v61df expected seven operator stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "ready", "ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61df stage status sequence mismatch")
if len(command_rows) != 6:
    raise SystemExit("v61df expected six command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "0", "0", "1", "0"]:
    raise SystemExit("v61df command readiness mismatch")
if len(file_rows) != 8 or any(row["file_ready"] != "1" for row in file_rows):
    raise SystemExit("v61df packet file readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61df_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61df metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53-review-return-operator-surface",
    "v53-to-v61-handoff-surface",
    "v61-post-review-generation-surface",
    "operator-packet-files",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61df requirement should pass: {requirement_id}")
for requirement_id in [
    "review-return-accepted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61df requirement should stay blocked: {requirement_id}")

for gate in ["operator-packet-files", "review-return-operator-surface", "generation-result-operator-surface"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61df decision should pass: {gate}")
for gate in [
    "review-return-accepted",
    "generation-result-accepted",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61df decision should stay blocked: {gate}")

if gaps["operator-packet-files"] != "ready":
    raise SystemExit("v61df operator packet gap should be ready")
for gap in [
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61df gap should stay blocked: {gap}")

boundary = (run_dir / "V61DF_EXTERNAL_REVIEW_GENERATION_RETURN_OPERATOR_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "operator_stage_rows=7",
    "ready_operator_stage_rows=3",
    "blocked_operator_stage_rows=4",
    "operator_packet_file_rows=8",
    "review_return_required_artifacts=5",
    "generation_result_required_artifacts=5",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "generation_result_accepted_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61df=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61df boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61df_external_review_generation_return_operator_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61df_external_review_generation_return_operator_packet_ready") != 1:
    raise SystemExit("v61df manifest readiness mismatch")
if manifest.get("ready_operator_packet_file_rows") != 8:
    raise SystemExit("v61df manifest file readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61df manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61df manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61df sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61df produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61df external review generation return operator packet smoke passed"
