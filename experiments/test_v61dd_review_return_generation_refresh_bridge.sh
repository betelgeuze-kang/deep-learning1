#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dd_review_return_generation_refresh_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DD_REUSE_EXISTING="${V61DD_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_REVIEW_GENERATION_REFRESH.sh" >/dev/null

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
    "v61dd_review_return_generation_refresh_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "v53y_complete_source_review_return_refresh_gate_ready": "1",
    "v61dc_complete_source_runtime_admission_local_return_materializer_ready": "1",
    "v61ck_real_generation_unblocker_operator_matrix_ready": "1",
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": "1",
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    "refresh_stage_rows": "6",
    "ready_refresh_stage_rows": "2",
    "blocked_refresh_stage_rows": "4",
    "refresh_command_rows": "3",
    "ready_refresh_command_rows": "1",
    "full_shard_prerequisites_closed": "1",
    "full_checkpoint_materialization_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "complete_source_runtime_admission_execution_ready": "1",
    "machine_complete_source_surface_ready": "1",
    "accepted_chunk_return_artifact_rows": "0",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "answer_review_accepted_rows": "0",
    "review_return_ready": "0",
    "v61_review_unblock_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "review_return_blocked_generation_rows": "1000",
    "generation_result_artifact_blocked_rows": "1000",
    "guarded_generation_command_ready": "0",
    "generation_operator_execution_ready": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "closure_queue_rows": "5",
    "closed_closure_rows": "3",
    "blocked_closure_rows": "2",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dd {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_generation_refresh_stage_rows.csv",
    "review_return_generation_refresh_command_rows.csv",
    "review_return_generation_refresh_requirement_rows.csv",
    "review_return_generation_refresh_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DD_REVIEW_RETURN_GENERATION_REFRESH_BRIDGE_BOUNDARY.md",
    "v61dd_review_return_generation_refresh_bridge_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_REVIEW_GENERATION_REFRESH.sh",
    "source_v53y/complete_source_review_return_refresh_stage_rows.csv",
    "source_v53y/runtime_gap_rows.csv",
    "source_v61ck/real_generation_unblocker_matrix_rows.csv",
    "source_v61cs/complete_source_generation_execution_admission_metric_rows.csv",
    "source_v61cs/runtime_gap_rows.csv",
    "source_v61ct/complete_source_generation_execution_operator_command_rows.csv",
    "source_v61cu/complete_source_generation_result_acceptance_metric_rows.csv",
    "source_v61cu/runtime_gap_rows.csv",
    "source_v61cx/post_full_shard_generation_closure_queue_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dd artifact: {rel}")

stage_rows = read_csv(run_dir / "review_return_generation_refresh_stage_rows.csv")
command_rows = read_csv(run_dir / "review_return_generation_refresh_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_generation_refresh_requirement_rows.csv")}
metric = read_csv(run_dir / "review_return_generation_refresh_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 6:
    raise SystemExit("v61dd expected six refresh stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61dd stage status sequence mismatch")
if len(command_rows) != 3:
    raise SystemExit("v61dd expected three command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "0", "0"]:
    raise SystemExit("v61dd command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61dd_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dd metric {field}: expected {value}, got {metric[field]}")

for requirement_id in ["full-shard-page-hash-closed", "runtime-admission-accepted"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61dd requirement should pass: {requirement_id}")
for requirement_id in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61dd requirement should stay blocked: {requirement_id}")

for gate in ["full-shard-page-hash-closed", "runtime-admission-accepted"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dd decision should pass: {gate}")
for gate in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dd decision should stay blocked: {gate}")

for gap in ["full-shard-page-hash-closed", "runtime-admission-accepted"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61dd gap should be ready: {gap}")
for gap in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61dd gap should stay blocked: {gap}")

boundary = (run_dir / "V61DD_REVIEW_RETURN_GENERATION_REFRESH_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_return_dir_supplied=0",
    "review_return_dir_exists=0",
    "refresh_stage_rows=6",
    "ready_refresh_stage_rows=2",
    "blocked_refresh_stage_rows=4",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "complete_source_runtime_admission_execution_ready=1",
    "machine_complete_source_surface_ready=1",
    "accepted_chunk_return_artifact_rows=0",
    "accepted_aggregate_review_return_artifact_rows=0",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "v61_review_unblock_ready=0",
    "generation_execution_admission_rows=1000",
    "generation_execution_admitted_rows=0",
    "review_return_blocked_generation_rows=1000",
    "generation_result_artifact_blocked_rows=1000",
    "actual_model_generation_ready_rows=0",
    "actual_model_generation_ready=0",
    "closed_closure_rows=3",
    "blocked_closure_rows=2",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dd boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dd_review_return_generation_refresh_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dd_review_return_generation_refresh_bridge_ready") != 1:
    raise SystemExit("v61dd manifest readiness mismatch")
if manifest.get("ready_refresh_stage_rows") != 2 or manifest.get("blocked_refresh_stage_rows") != 4:
    raise SystemExit("v61dd manifest stage count mismatch")
if manifest.get("runtime_admission_accepted_rows") != 1000:
    raise SystemExit("v61dd manifest runtime admission mismatch")
if manifest.get("answer_review_accepted_rows") != 0:
    raise SystemExit("v61dd manifest must not invent review acceptance")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dd manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dd manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dd sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dd produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dd review return generation refresh bridge smoke passed"
