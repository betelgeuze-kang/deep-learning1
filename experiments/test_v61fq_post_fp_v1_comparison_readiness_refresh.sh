#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fq_post_fp_v1_comparison_readiness_refresh"
RUN_DIR="$RESULTS_DIR/$PREFIX/refresh_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REFRESH_DIR="$RUN_DIR/post_fp_v1_comparison_readiness_refresh"

V61FP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger.sh" >/dev/null

V61FQ_REUSE_EXISTING="${V61FQ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fq_post_fp_v1_comparison_readiness_refresh.sh" >/dev/null

"$REFRESH_DIR/VERIFY_V1_COMPARISON_REFRESH.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
refresh_dir = run_dir / "post_fp_v1_comparison_readiness_refresh"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": "1",
    "v52y_f_optional_final_policy_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "v61dh_post_full_shard_claim_audit_gate_ready": "1",
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready": "1",
    "v52_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "f_final_deferred_with_reason": "1",
    "comparison_30b_150b_wording_status": "allowed-with-disclosure",
    "comparison_wording_claim_ready": "1",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "complete_source_review_rows_ready": "0",
    "return_acceptance_replay_ready": "1",
    "return_acceptance_replay_closed": "0",
    "v53_ready": "0",
    "claim_audit_ready": "1",
    "claim_rows": "15",
    "allowed_claim_rows": "7",
    "blocked_claim_rows": "8",
    "claim_invariant_pass_rows": "6",
    "claim_invariant_rows": "6",
    "full_shard_prerequisites_closed": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "post_full_shard_runtime_evidence_ready": "1",
    "runtime_execution_admitted_rows": "37",
    "runtime_admission_accepted_rows": "1000",
    "replay_entrypoint_ready": "1",
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "readiness_rows": "21",
    "ready_readiness_rows": "11",
    "blocked_readiness_rows": "10",
    "comparison_claim_rows": "8",
    "allowed_comparison_claim_rows": "4",
    "blocked_comparison_claim_rows": "4",
    "next_action_rows": "6",
    "ready_next_action_rows": "2",
    "blocked_next_action_rows": "4",
    "refresh_package_file_rows": "6",
    "metadata_only_refresh_package_file_rows": "6",
    "payload_like_refresh_package_file_rows": "0",
    "source_summary_file_rows": "10",
    "source_artifact_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fq {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fp_v1_comparison_readiness_rows.csv",
    "post_fp_v1_comparison_claim_boundary_rows.csv",
    "post_fp_v1_comparison_next_action_rows.csv",
    "post_fp_v1_comparison_metric_rows.csv",
    "post_fp_v1_comparison_file_rows.csv",
    "V61FQ_POST_FP_V1_COMPARISON_READINESS_REFRESH_BOUNDARY.md",
    "v61fq_post_fp_v1_comparison_readiness_refresh_manifest.json",
    "v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "v61fq_post_fp_v1_comparison_readiness_refresh_decision.csv",
    "post_fp_v1_comparison_readiness_refresh/V1_COMPARISON_REFRESH_MANIFEST.json",
    "post_fp_v1_comparison_readiness_refresh/V1_COMPARISON_READINESS_ROWS.csv",
    "post_fp_v1_comparison_readiness_refresh/V1_COMPARISON_CLAIM_BOUNDARY_ROWS.csv",
    "post_fp_v1_comparison_readiness_refresh/V1_COMPARISON_NEXT_ACTION_ROWS.csv",
    "post_fp_v1_comparison_readiness_refresh/V1_COMPARISON_REFRESH.md",
    "post_fp_v1_comparison_readiness_refresh/VERIFY_V1_COMPARISON_REFRESH.sh",
    "source_summaries/v52y_f_optional_final_policy_summary.csv",
    "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_summaries/v53am_complete_source_return_acceptance_replay_summary.csv",
    "source_summaries/v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "source_summaries/v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_summary.csv",
    "source_artifacts/v52y_f_optional_final_rows.csv",
    "source_artifacts/v52y_comparison_wording_rows.csv",
    "source_artifacts/v53t_requirement_rows.csv",
    "source_artifacts/v53am_replay_step_rows.csv",
    "source_artifacts/v61dh_claim_rows.csv",
    "source_artifacts/v61fp_ledger_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fq artifact: {rel}")

if not os.access(refresh_dir / "VERIFY_V1_COMPARISON_REFRESH.sh", os.X_OK):
    raise SystemExit("v61fq verifier must be executable")

readiness = read_csv(run_dir / "post_fp_v1_comparison_readiness_rows.csv")
if len(readiness) != 21:
    raise SystemExit("v61fq expected 21 readiness rows")
ready_rows = [row for row in readiness if row["status"] == "ready"]
blocked_rows = [row for row in readiness if row["status"] == "blocked"]
if len(ready_rows) != 11 or len(blocked_rows) != 10:
    raise SystemExit("v61fq readiness ready/blocked counts mismatch")
for row_id in [
    "01-v52-ready",
    "02-f-optional-final-disposition",
    "03-f-deferred-with-reason",
    "04-required-30b-baseline",
    "05-required-70b-baseline",
    "06-30b-150b-wording",
    "07-complete-source-surface",
    "08-review-packet-ready",
    "12-full-shard-prerequisites",
    "13-runtime-admission",
    "14-replay-entrypoint",
]:
    row = next(row for row in readiness if row["row_id"] == row_id)
    if row["status"] != "ready":
        raise SystemExit(f"v61fq readiness row should be ready: {row_id}")
for row_id in [
    "09-human-review-return",
    "10-return-acceptance-replay",
    "11-v53-ready",
    "15-real-review-return",
    "16-real-return-replay",
    "17-generation-execution",
    "18-generation-result-acceptance",
    "19-actual-generation",
    "20-v1-comparison-ready",
    "21-release-claims",
]:
    row = next(row for row in readiness if row["row_id"] == row_id)
    if row["status"] != "blocked":
        raise SystemExit(f"v61fq readiness row should be blocked: {row_id}")

claims = read_csv(run_dir / "post_fp_v1_comparison_claim_boundary_rows.csv")
if len(claims) != 8:
    raise SystemExit("v61fq expected eight claim boundary rows")
if sum(row["claim_status"] == "allowed" for row in claims) != 4:
    raise SystemExit("v61fq expected four allowed claim rows")
if sum(row["claim_status"] == "blocked" for row in claims) != 4:
    raise SystemExit("v61fq expected four blocked claim rows")

actions = read_csv(run_dir / "post_fp_v1_comparison_next_action_rows.csv")
if [row["ready_to_run_now"] for row in actions] != ["1", "1", "0", "0", "0", "0"]:
    raise SystemExit("v61fq next-action readiness mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52-ready",
    "30b-150b-wording",
    "v53-machine-complete-source-surface",
    "full-shard-prerequisites",
    "zero-repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fq decision should pass: {gate}")
for gate in [
    "complete-source-review-return",
    "real-review-return",
    "generation-execution",
    "generation-result-acceptance",
    "v1-comparison",
    "actual-generation",
    "release-claims",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fq decision should be blocked: {gate}")

boundary = (run_dir / "V61FQ_POST_FP_V1_COMPARISON_READINESS_REFRESH_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready=1",
    "v52_ready=1",
    "f_optional_final_disposition=deferred-with-reason-final",
    "comparison_30b_150b_wording_status=allowed-with-disclosure",
    "comparison_wording_claim_ready=1",
    "v53_machine_complete_source_surface_ready=1",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "v1_0_comparison_ready=0",
    "actual_model_generation_ready=0",
    "readiness_rows=21",
    "ready_readiness_rows=11",
    "blocked_readiness_rows=10",
    "allowed_comparison_claim_rows=4",
    "blocked_comparison_claim_rows=4",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fq boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fq_post_fp_v1_comparison_readiness_refresh_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fq_post_fp_v1_comparison_readiness_refresh_ready") != 1:
    raise SystemExit("v61fq manifest readiness mismatch")
if manifest.get("comparison_wording_claim_ready") != 1:
    raise SystemExit("v61fq manifest should allow comparison wording only with disclosure")
if manifest.get("v1_0_comparison_ready") != 0:
    raise SystemExit("v61fq manifest must keep v1.0 comparison blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fq manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fq manifest must keep repo checkpoint payload zero")

print("v61fq post-v61fp v1 comparison readiness refresh test passed")
PY
