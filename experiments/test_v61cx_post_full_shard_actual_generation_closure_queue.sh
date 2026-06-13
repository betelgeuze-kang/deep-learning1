#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cx_post_full_shard_actual_generation_closure_queue"
RUN_DIR="$RESULTS_DIR/$PREFIX/queue_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CX_REUSE_EXISTING="${V61CX_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cx_post_full_shard_actual_generation_closure_queue.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": "1",
    "closure_queue_rows": "5",
    "closed_closure_rows": "3",
    "blocked_closure_rows": "2",
    "next_action_rows": "3",
    "ready_next_action_rows": "2",
    "full_shard_prerequisites_closed": "1",
    "full_checkpoint_materialization_ready": "1",
    "checkpoint_shard_rows": "59",
    "total_identity_verified_checkpoint_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "runtime_artifact_blocked_acceptance_rows": "0",
    "runtime_result_blocked_acceptance_rows": "0",
    "runtime_page_binding_blocked_acceptance_rows": "0",
    "runtime_budget_blocked_acceptance_rows": "0",
    "runtime_identity_blocked_acceptance_rows": "0",
    "runtime_safety_blocked_acceptance_rows": "0",
    "guarded_runtime_admission_command_ready": "1",
    "complete_source_runtime_admission_execution_ready": "1",
    "review_return_operator_bundle_handoff_ready": "1",
    "review_return_acceptance_rows": "7000",
    "answer_review_accepted_rows": "0",
    "human_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "adjudication_accepted_rows": "0",
    "expected_adjudication_rows": "1000",
    "reviewer_identity_ready": "0",
    "conflict_disclosure_ready": "0",
    "acceptance_summary_ready": "0",
    "review_return_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "guarded_generation_command_ready": "0",
    "generation_operator_execution_ready": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cx summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "post_full_shard_generation_closure_queue_rows.csv",
    "post_full_shard_generation_next_action_rows.csv",
    "post_full_shard_generation_closure_metric_rows.csv",
    "V61CX_POST_FULL_SHARD_ACTUAL_GENERATION_CLOSURE_QUEUE_BOUNDARY.md",
    "v61cx_post_full_shard_actual_generation_closure_queue_manifest.json",
    "source_v61cv/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "source_v53u/review_return_expected_artifact_rows.csv",
    "source_v53v/complete_source_review_return_acceptance_rows.csv",
    "source_v61ct/GENERATION_RESULT_RETURN_TEMPLATE.csv",
    "source_v61cu/complete_source_generation_result_acceptance_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cx artifact: {rel}")

queue_rows = read_csv(run_dir / "post_full_shard_generation_closure_queue_rows.csv")
action_rows = read_csv(run_dir / "post_full_shard_generation_next_action_rows.csv")
metric_rows = read_csv(run_dir / "post_full_shard_generation_closure_metric_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(queue_rows) != 5:
    raise SystemExit("v61cx expected five closure rows")
if len(action_rows) != 3:
    raise SystemExit("v61cx expected three next-action rows")
if len(metric_rows) != 1:
    raise SystemExit("v61cx expected one metric row")
if sum(1 for row in queue_rows if row["ready"] == "1") != 3:
    raise SystemExit("v61cx should mark exactly three closure rows ready")
if sum(1 for row in queue_rows if row["ready"] == "0") != 2:
    raise SystemExit("v61cx should mark exactly two closure rows blocked")

action_ready = {row["action_id"]: row["ready_to_run_now"] for row in action_rows}
if action_ready.get("01-runtime-admission-return") != "1":
    raise SystemExit("v61cx runtime admission action should be ready")
if action_ready.get("02-review-return") != "1":
    raise SystemExit("v61cx review return action should be ready")
if action_ready.get("03-generation-execution-return") != "0":
    raise SystemExit("v61cx generation action should remain blocked")

for gate in [
    "full-checkpoint-materialization",
    "completed-full-safetensors-page-hash-coverage",
    "complete-source-runtime-admission-acceptance",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cx expected {gate} pass, got {decisions.get(gate)!r}")
for gate in [
    "complete-source-review-return",
    "complete-source-generation-result-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cx expected {gate} blocked, got {decisions.get(gate)!r}")

boundary = (run_dir / "V61CX_POST_FULL_SHARD_ACTUAL_GENERATION_CLOSURE_QUEUE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "closure_queue_rows=5",
    "closed_closure_rows=3",
    "blocked_closure_rows=2",
    "next_action_rows=3",
    "ready_next_action_rows=2",
    "full_shard_prerequisites_closed=1",
    "checkpoint_shard_rows=59",
    "total_verified_page_hash_rows=134161",
    "runtime_admission_acceptance_rows=1000",
    "runtime_admission_accepted_rows=1000",
    "review_return_acceptance_rows=7000",
    "answer_review_accepted_rows=0",
    "generation_result_acceptance_rows=1000",
    "generation_result_accepted_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cx=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cx boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cx_post_full_shard_actual_generation_closure_queue_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cx_post_full_shard_actual_generation_closure_queue_ready") != 1:
    raise SystemExit("v61cx manifest readiness mismatch")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v61cx manifest should mark full-shard prerequisites closed")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cx manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cx manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cx produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cx post-full-shard actual generation closure queue smoke passed"
