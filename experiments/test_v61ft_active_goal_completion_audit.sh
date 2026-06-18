#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ft_active_goal_completion_audit"
RUN_DIR="$RESULTS_DIR/$PREFIX/audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
AUDIT_DIR="$RUN_DIR/active_goal_completion_audit"

V61FS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fs_post_fr_ready_command_execution_receipt.sh" >/dev/null

V61FT_REUSE_EXISTING="${V61FT_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ft_active_goal_completion_audit.sh" >/dev/null

"$AUDIT_DIR/VERIFY_ACTIVE_GOAL_COMPLETION_AUDIT.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
audit_dir = run_dir / "active_goal_completion_audit"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61ft_active_goal_completion_audit_ready": "1",
    "v52y_f_optional_final_policy_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": "1",
    "v61fs_post_fr_ready_command_execution_receipt_ready": "1",
    "v52_ready": "0",
    "f_optional_final_disposition_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "comparison_wording_claim_ready": "0",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "v53_ready": "0",
    "real_manifest_fixture_replacement_ready": "1",
    "gpu_page_dequant_matmul_measurement_ready": "1",
    "kv_cache_policy_ready": "1",
    "v61j_source_bound_qa_command_pass": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "post_full_shard_runtime_evidence_ready": "1",
    "successful_ready_command_rows": "4",
    "ready_command_rows": "4",
    "present_external_input_rows": "0",
    "required_external_input_rows": "5",
    "actual_model_generation_ready": "0",
    "v1_0_comparison_ready": "0",
    "active_goal_complete": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ft": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "requirement_rows": "20",
    "pass_requirement_rows": "11",
    "blocked_requirement_rows": "9",
    "objective_section_rows": "3",
    "pass_objective_section_rows": "0",
    "blocked_objective_section_rows": "3",
    "blocker_rows": "9",
    "next_action_rows": "5",
    "ready_next_action_rows": "2",
    "blocked_next_action_rows": "3",
    "audit_package_file_rows": "7",
    "metadata_only_audit_package_file_rows": "7",
    "payload_like_audit_package_file_rows": "0",
    "source_summary_file_rows": "10",
    "source_artifact_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ft {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "active_goal_completion_requirement_rows.csv",
    "active_goal_completion_section_rows.csv",
    "active_goal_completion_blocker_rows.csv",
    "active_goal_completion_next_action_rows.csv",
    "active_goal_completion_metric_rows.csv",
    "active_goal_completion_file_rows.csv",
    "V61FT_ACTIVE_GOAL_COMPLETION_AUDIT_BOUNDARY.md",
    "v61ft_active_goal_completion_audit_manifest.json",
    "v61ft_active_goal_completion_audit_summary.csv",
    "v61ft_active_goal_completion_audit_decision.csv",
    "active_goal_completion_audit/ACTIVE_GOAL_COMPLETION_AUDIT_MANIFEST.json",
    "active_goal_completion_audit/ACTIVE_GOAL_REQUIREMENT_ROWS.csv",
    "active_goal_completion_audit/ACTIVE_GOAL_SECTION_ROWS.csv",
    "active_goal_completion_audit/ACTIVE_GOAL_BLOCKER_ROWS.csv",
    "active_goal_completion_audit/ACTIVE_GOAL_NEXT_ACTION_ROWS.csv",
    "active_goal_completion_audit/ACTIVE_GOAL_COMPLETION_AUDIT.md",
    "active_goal_completion_audit/VERIFY_ACTIVE_GOAL_COMPLETION_AUDIT.sh",
    "source_summaries/v52y_f_optional_final_policy_summary.csv",
    "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_summaries/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "source_summaries/v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "source_summaries/v61fs_post_fr_ready_command_execution_receipt_summary.csv",
    "source_artifacts/v52y_f_optional_final_rows.csv",
    "source_artifacts/v52y_v52_ready_condition_rows.csv",
    "source_artifacts/v53t_requirement_rows.csv",
    "source_artifacts/v61dg_runtime_evidence_rows.csv",
    "source_artifacts/v61fq_readiness_rows.csv",
    "source_artifacts/v61fs_execution_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ft artifact: {rel}")

if not os.access(audit_dir / "VERIFY_ACTIVE_GOAL_COMPLETION_AUDIT.sh", os.X_OK):
    raise SystemExit("v61ft verifier must be executable")

requirements = read_csv(run_dir / "active_goal_completion_requirement_rows.csv")
if len(requirements) != 20:
    raise SystemExit("v61ft expected 20 requirement rows")
if sum(row["status"] == "pass" for row in requirements) != 11:
    raise SystemExit("v61ft expected 11 passing requirements")
if sum(row["status"] == "blocked" for row in requirements) != 9:
    raise SystemExit("v61ft expected nine blocked requirements")
for requirement_id in [
    "02-v52-ready-condition",
    "03-30b-150b-wording-disclosure",
    "08-human-review-return",
    "09-adjudication-return",
    "10-v53-ready",
    "17-external-return-inputs",
    "18-actual-model-generation",
    "19-v1-comparison-ready",
    "20-near-frontier-production-release",
]:
    row = next(row for row in requirements if row["requirement_id"] == requirement_id)
    if row["status"] != "blocked":
        raise SystemExit(f"v61ft requirement should be blocked: {requirement_id}")

sections = read_csv(run_dir / "active_goal_completion_section_rows.csv")
if len(sections) != 3:
    raise SystemExit("v61ft expected three section rows")
if any(row["status"] != "blocked" for row in sections):
    raise SystemExit("v61ft v52/v53/v61 sections should remain blocked")

actions = read_csv(run_dir / "active_goal_completion_next_action_rows.csv")
if [row["ready_to_run_now"] for row in actions] != ["1", "1", "0", "0", "0"]:
    raise SystemExit("v61ft next-action readiness mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53-machine-complete-source-surface",
    "v61-real-model-runtime-evidence",
    "zero-repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61ft decision should pass: {gate}")
for gate in [
    "v52-f-optional-and-ready",
    "v53-review-return",
    "external-return-inputs",
    "actual-generation",
    "v1-comparison",
    "active-goal-complete",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ft decision should be blocked: {gate}")

boundary = (run_dir / "V61FT_ACTIVE_GOAL_COMPLETION_AUDIT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61ft_active_goal_completion_audit_ready=1",
    "active_goal_complete=0",
    "requirement_rows=20",
    "pass_requirement_rows=11",
    "blocked_requirement_rows=9",
    "v52_ready=0",
    "v53_machine_complete_source_surface_ready=1",
    "post_full_shard_runtime_evidence_ready=1",
    "successful_ready_command_rows=4/4",
    "present_external_input_rows=0/5",
    "v1_0_comparison_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ft boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ft_active_goal_completion_audit_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ft_active_goal_completion_audit_ready") != 1:
    raise SystemExit("v61ft manifest readiness mismatch")
if manifest.get("active_goal_complete") != 0:
    raise SystemExit("v61ft manifest must keep active goal incomplete")
if manifest.get("blocked_requirement_rows") != 7:
    raise SystemExit("v61ft manifest blocked requirement mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ft manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ft manifest must keep repo checkpoint payload zero")

print("v61ft active goal completion audit test passed")
PY
