#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ck_real_generation_unblocker_operator_matrix/matrix_001"
SUMMARY_CSV="$RESULTS_DIR/v61ck_real_generation_unblocker_operator_matrix_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ck_real_generation_unblocker_operator_matrix_decision.csv"

V61CK_REUSE_EXISTING="${V61CK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ck_real_generation_unblocker_operator_matrix.sh" >/dev/null

"$RUN_DIR/operator_matrix/VERIFY_UNBLOCKER_MATRIX.sh" >/dev/null

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
    "v61ck_real_generation_unblocker_operator_matrix_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cj_real_manifest_immediate_target_bridge_ready": "1",
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": "1",
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": "1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": "1",
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": "1",
    "unblocker_matrix_rows": "7",
    "ready_unblocker_operator_surfaces": "7",
    "blocked_unblocker_rows": "7",
    "operator_execution_order_rows": "11",
    "operator_matrix_file_rows": "3",
    "remaining_materialization_queue_rows": "58",
    "remaining_unverified_bytes": "276308963480",
    "checkpoint_materialization_promotion_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "1",
    "blocked_checkpoint_materialization_shard_rows": "58",
    "accepted_remaining_materialization_return_rows": "0",
    "missing_remaining_materialization_return_rows": "58",
    "promotion_missing_materialization_bytes": "276308963480",
    "remaining_page_hash_rows": "131808",
    "page_hash_execution_admission_ready": "0",
    "admitted_page_hash_execution_chunk_rows": "0",
    "materialization_blocked_page_hash_execution_chunk_rows": "286",
    "blocked_page_hash_rows": "131808",
    "blocked_page_hash_bytes": "276308963480",
    "runtime_execution_candidate_rows": "37",
    "runtime_execution_admitted_rows": "0",
    "runtime_execution_blocked_rows": "37",
    "materialization_blocked_runtime_rows": "37",
    "page_hash_admission_blocked_runtime_rows": "37",
    "real_manifest_runtime_execution_admission_ready": "0",
    "complete_source_query_rows": "1000",
    "runtime_admission_expansion_packet_rows": "1000",
    "runtime_admission_expansion_required_rows": "1000",
    "new_runtime_admission_rows_required": "1000",
    "runtime_admission_operator_command_rows": "5",
    "runtime_admission_return_artifact_rows": "5",
    "runtime_admission_expansion_packet_ready": "1",
    "expected_runtime_admission_return_artifacts": "5",
    "accepted_runtime_admission_return_artifacts": "0",
    "missing_runtime_admission_return_artifacts": "5",
    "accepted_runtime_admission_result_rows": "0",
    "missing_runtime_admission_result_rows": "1000",
    "runtime_admission_return_artifact_ready": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "accepted_remaining_page_hash_result_rows": "0",
    "missing_remaining_page_hash_result_rows": "131808",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "real_manifest_immediate_target_bridge_ready": "1",
    "review_return_operator_bundle_handoff_ready": "1",
    "generation_operator_bundle_handoff_ready": "1",
    "generation_unblocker_operator_matrix_ready": "1",
    "full_checkpoint_materialization_ready": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "review_return_ready": "0",
    "generation_result_admission_ready": "0",
    "generation_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ck": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ck {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_unblocker_matrix_rows.csv",
    "real_generation_operator_execution_order_rows.csv",
    "real_generation_claim_boundary_rows.csv",
    "real_generation_operator_matrix_file_rows.csv",
    "real_generation_unblocker_metric_rows.csv",
    "V61CK_REAL_GENERATION_UNBLOCKER_OPERATOR_MATRIX_BOUNDARY.md",
    "v61ck_real_generation_unblocker_operator_matrix_manifest.json",
    "operator_matrix/README.md",
    "operator_matrix/RETURN_DIRECTORY_LAYOUT.md",
    "operator_matrix/VERIFY_UNBLOCKER_MATRIX.sh",
    "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_rows.csv",
    "source_v61cn/page_hash_execution_materialization_admission_rows.csv",
    "source_v61co/real_manifest_runtime_execution_admission_rows.csv",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cq/complete_source_runtime_admission_operator_command_rows.csv",
    "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_requirement_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_metric_rows.csv",
    "source_v61ca/remaining_page_hash_result_requirement_rows.csv",
    "source_v61cb/full_page_hash_coverage_promotion_rows.csv",
    "source_v53u/reviewer_workload_chunk_rows.csv",
    "source_v61bt/actual_generation_result_requirement_rows.csv",
    "source_v61cg/source_bound_generation_operator_bundle_file_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ck artifact: {rel}")

matrix = read_csv(run_dir / "real_generation_unblocker_matrix_rows.csv")
execution = read_csv(run_dir / "real_generation_operator_execution_order_rows.csv")
claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "real_generation_claim_boundary_rows.csv")}
files = read_csv(run_dir / "real_generation_operator_matrix_file_rows.csv")
metric = read_csv(run_dir / "real_generation_unblocker_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(matrix) != 7 or len(execution) != 11 or len(files) != 3:
    raise SystemExit("v61ck matrix row count mismatch")
if any(row["operator_surface_ready"] != "1" for row in matrix):
    raise SystemExit("v61ck all operator surfaces should be ready")
if any(row["current_ready"] != "0" for row in matrix):
    raise SystemExit("v61ck all current unblockers should remain blocked")
if claims.get("real-manifest-immediate-targets") != "ready":
    raise SystemExit("v61ck immediate target claim should be ready")
for claim in ["actual-model-generation", "production-latency", "near-frontier-quality"]:
    if claims.get(claim) != "blocked":
        raise SystemExit(f"v61ck claim should stay blocked: {claim}")

for field, value in expected.items():
    if field.startswith("v61ck_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ck metric {field}: expected {value}, got {metric[field]}")

for gate in ["real-manifest-immediate-target-bridge", "operator-unblocker-matrix"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ck gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "completed-full-safetensors-page-hash-coverage",
    "real-manifest-runtime-execution-admission",
    "complete-source-runtime-admission-return-intake",
    "complete-source-review-return",
    "actual-generation-result-return",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ck gate should stay blocked: {gate}")

boundary = (run_dir / "V61CK_REAL_GENERATION_UNBLOCKER_OPERATOR_MATRIX_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "unblocker_matrix_rows=7",
    "ready_unblocker_operator_surfaces=7/7",
    "remaining_materialization_queue_rows=58",
    "remaining_unverified_bytes=276308963480",
    "checkpoint_materialization_promotion_rows=59",
    "ready_checkpoint_materialization_shard_rows=1",
    "blocked_checkpoint_materialization_shard_rows=58",
    "missing_remaining_materialization_return_rows=58",
    "promotion_missing_materialization_bytes=276308963480",
    "remaining_page_hash_rows=131808",
    "page_hash_execution_admission_ready=0",
    "admitted_page_hash_execution_chunk_rows=0",
    "materialization_blocked_page_hash_execution_chunk_rows=286",
    "blocked_page_hash_rows=131808",
    "blocked_page_hash_bytes=276308963480",
    "runtime_execution_candidate_rows=37",
    "runtime_execution_admitted_rows=0",
    "runtime_execution_blocked_rows=37",
    "materialization_blocked_runtime_rows=37",
    "page_hash_admission_blocked_runtime_rows=37",
    "real_manifest_runtime_execution_admission_ready=0",
    "complete_source_query_rows=1000",
    "runtime_admission_expansion_packet_rows=1000",
    "runtime_admission_expansion_required_rows=1000",
    "new_runtime_admission_rows_required=1000",
    "runtime_admission_operator_command_rows=5",
    "runtime_admission_return_artifact_rows=5",
    "runtime_admission_expansion_packet_ready=1",
    "expected_runtime_admission_return_artifacts=5",
    "accepted_runtime_admission_return_artifacts=0",
    "missing_runtime_admission_return_artifacts=5",
    "accepted_runtime_admission_result_rows=0",
    "missing_runtime_admission_result_rows=1000",
    "runtime_admission_return_artifact_ready=0",
    "complete_source_runtime_admission_execution_ready=0",
    "accepted_remaining_page_hash_result_rows=0",
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "expected_adjudication_rows=1000",
    "accepted_adjudication_rows=0",
    "expected_generation_result_artifacts=5",
    "accepted_generation_result_artifacts=0",
    "generation_unblocker_operator_matrix_ready=1",
    "full_checkpoint_materialization_ready=0",
    "completed_full_safetensors_page_hash_coverage_ready=0",
    "review_return_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ck=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ck boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ck_real_generation_unblocker_operator_matrix_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ck_real_generation_unblocker_operator_matrix_ready") != 1:
    raise SystemExit("v61ck manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ck manifest must keep generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ck manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ck sha256 mismatch: {rel}")
PY

echo "v61ck real generation unblocker operator matrix smoke passed"
