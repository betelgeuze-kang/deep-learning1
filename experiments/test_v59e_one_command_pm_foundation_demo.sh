#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59e_one_command_pm_foundation_demo/pm_foundation_001"
SUMMARY_CSV="$RESULTS_DIR/v59e_one_command_pm_foundation_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59e_one_command_pm_foundation_demo_decision.csv"
PR_SLICE_RUN_DIR="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate/gate_001"
PR_SLICE_SUMMARY_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_summary.csv"

"$ROOT_DIR/examples/v1_0_architecture_challenge_pm_foundation_demo.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PR_SLICE_RUN_DIR" "$PR_SLICE_SUMMARY_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
pr_slice_run_dir = Path(sys.argv[4])
pr_slice_summary_csv = Path(sys.argv[5])


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
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "v59_ready": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": "1",
    "one_command_replay_preflight_ready": "1",
    "stage_rows": "8",
    "ready_stage_rows": "8",
    "full_ready_stage_rows": "1",
    "pinned_public_sources_verified": "1",
    "public_source_snapshot_replay_rows": "10",
    "public_source_snapshot_replay_pass_rows": "10",
    "public_source_snapshot_replay_ready": "1",
    "source_snapshot_replay_used": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "pm_v53_freeze_ready": "1",
    "v53_negative_abstain_rows": "160",
    "v53_unsupported_control_rows": "100",
    "v53_ambiguous_control_rows": "30",
    "v53_missing_specific_control_rows": "30",
    "v53_doc_code_conflict_rows": "140",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "v53aq_complete_source_abgh_real_adapter_measured_ready": "1",
    "local_abgh_baseline_run_ready": "1",
    "local_abgh_row_contract_replay_rows": "2",
    "local_abgh_row_contract_replay_pass_rows": "2",
    "local_abgh_row_contract_replay_ready": "1",
    "local_abgh_deterministic_adapter_ready": "1",
    "local_abgh_real_adapter_ready": "1",
    "v53ap_expected_answer_oracle_replay": "0",
    "v53ap_deterministic_source_span_adapter_execution": "1",
    "v53ap_deterministic_source_span_adapter_rows": "4000",
    "v53ap_actual_adapter_execution_ready": "1",
    "v53ap_real_system_performance_claim_ready": "0",
    "v53aq_selection_question_text_only": "1",
    "v53aq_selection_oracle_field_used": "0",
    "v53aq_expected_answer_oracle_replay": "0",
    "v53aq_deterministic_source_span_adapter_execution": "0",
    "v53aq_real_adapter_execution_ready": "1",
    "v53aq_real_system_performance_claim_ready": "1",
    "v53aq_same_query_internal_prebaseline_rows_ready": "1",
    "v53aq_same_query_internal_prebaseline_rows": "1000",
    "v53aq_answer_hash_match_rows": "3713",
    "v53aq_coherent_wrong_key_rows": "287",
    "same_query_abgh_ready": "1",
    "route_memory_artifact_ready": "1",
    "v54c_complete_source_grounded_generation_1000_ready": "1",
    "grounded_generation_outputs_ready": "1",
    "v54c_output_contract_rows": "9",
    "v54c_output_contract_pm_required_rows": "7",
    "v54c_output_contract_raw_prompt_forbidden_rows": "9",
    "v54c_v53ap_evaluator_provenance_ready": "1",
    "v54c_v53ap_evaluator_provenance_rows": "1000",
    "v54c_v53ap_answer_eval_separate_rows": "1000",
    "v54c_v53ap_citation_eval_separate_rows": "1000",
    "v54c_v53ap_resource_eval_separate_rows": "1000",
    "h10_real_label_readiness_gate_ready": "1",
    "h10_real_label_promotion_ready": "0",
    "h10_real_label_acceptance_evidence_rows": "6",
    "h10_real_label_acceptance_evidence_ready_rows": "6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows": "0",
    "h10_real_label_acceptance_evidence_tests_only_rows": "0",
    "h10_accepted_query_rows_declared": "0",
    "h10_accepted_label_rows": "0",
    "h10_accepted_coherent_wrong_key_labels": "0",
    "h10_accepted_chunk_exact_labels": "0",
    "h10_accepted_near_miss_labels": "0",
    "h10_accepted_missing_query_labels": "0",
    "h10_accepted_source_provenance_labels": "0",
    "h10_real_label_acceptance_evidence_coverage_field_rows": "6",
    "h10_real_label_acceptance_evidence_zero_accepted_rows": "6",
    "h10_real_label_acceptance_evidence_coverage_blocked_rows": "6",
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows": "6",
    "v58_pm_blind_eval_blocker_ready": "1",
    "v58c_intake_artifact_available": "0",
    "v58c_dependency_blocker_ready": "1",
    "v58c_blind_response_evidence_intake_ready": "0",
    "v58c_expected_blind_response_rows": "0",
    "v58c_required_blind_response_ready": "0",
    "v58c_blind_response_absorb_ready": "0",
    "v58c_human_blind_review_ready": "0",
    "v58d_review_artifact_available": "0",
    "v58d_dependency_blocker_ready": "1",
    "v58d_blind_review_return_intake_ready": "0",
    "v58d_expected_required_review_rows": "0",
    "v58d_required_blind_review_ready": "0",
    "v58d_required_adjudication_ready": "0",
    "v58d_human_blind_review_ready": "0",
    "v58d_inter_rater_rows_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "answer_citation_separate_eval": "1",
    "blocker_false_positive_closed": "1",
    "undocumented_local_state_required": "0",
    "private_fixture_required": "0",
    "manual_postprocessing_required": "0",
    "network_required": "0",
    "downloads_required": "0",
    "full_v1_public_demo_ready": "0",
    "real_release_package_ready": "0",
    "pm_pr_claim_slice_gate_ready": "1",
    "pm_pr_claim_slice_bundle_ready": "1",
    "pm_pr_recommended_slice_rows": "10",
    "pm_pr_merge_gate_rows": "30",
    "pm_pr_current_merge_ready_rows": "9",
    "pm_pr_current_blocked_rows": "1",
    "pm_pr_tests_only_merge_condition_rows": "0",
    "pm_pr_v53_query_span_binding_audit_ready": "1",
    "pm_pr_v53_query_span_binding_audit_rows": "1000",
    "pm_pr_v53_query_span_binding_pass_rows": "1000",
    "pm_pr_v53_direct_pinned_manifest_ready": "1",
    "pm_pr_v53_direct_repo_manifest_rows": "10",
    "pm_pr_v53_direct_file_manifest_rows": "11266",
    "pm_pr_v53_direct_content_snapshot_rows": "11266",
    "pm_pr_v53_pm_acceptance_evidence_rows": "10",
    "pm_pr_v53_pm_acceptance_evidence_ready_rows": "10",
    "pm_pr_v53_pm_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_review_packet_rows": "10",
    "pm_pr_review_packet_files": "10",
    "pm_pr_review_packet_bundle_ready": "1",
    "pm_pr_acceptance_evidence_rows": "10",
    "pm_pr_acceptance_evidence_ready_rows": "9",
    "pm_pr_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_v56_replay_acceptance_evidence_rows": "4",
    "pm_pr_v56_replay_acceptance_evidence_ready_rows": "0",
    "pm_pr_v56_replay_acceptance_evidence_blocked_rows": "4",
    "pm_pr_v56_replay_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_v56_replay_acceptance_evidence_fixture_allowed_rows": "0",
    "pm_pr_v56_replay_acceptance_evidence_approval_rows": "4",
    "pm_pr_de_30b70b_acceptance_evidence_rows": "4",
    "pm_pr_de_30b70b_acceptance_evidence_ready_rows": "0",
    "pm_pr_de_30b70b_acceptance_evidence_blocked_rows": "4",
    "pm_pr_de_30b70b_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_de_30b70b_acceptance_evidence_fixture_allowed_rows": "0",
    "pm_pr_de_30b70b_acceptance_evidence_approval_rows": "4",
    "pm_pr_v59_one_command_acceptance_evidence_rows": "2",
    "pm_pr_v59_one_command_acceptance_evidence_ready_rows": "1",
    "pm_pr_v59_one_command_acceptance_evidence_blocked_rows": "1",
    "pm_pr_v59_one_command_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows": "0",
    "pm_pr_v59_one_command_acceptance_evidence_approval_rows": "2",
    "pm_blocker_closure_packet_rows": "6",
    "pm_blocker_closure_packet_files": "6",
    "pm_blocker_closure_packet_bundle_ready": "1",
    "pm_blocker_required_artifact_rows": "26",
    "pm_blocker_required_artifact_fixture_allowed_rows": "0",
    "pm_execution_lock_rows": "10",
    "pm_execution_lock_active_rows": "10",
    "pm_scope_drift_allowed": "0",
    "pm_new_scaffold_default_allowed": "0",
    "pm_external_return_template_rows": "26",
    "pm_external_return_template_files": "26",
    "pm_external_return_template_fixture_allowed_rows": "0",
    "pm_external_return_template_approval_rows": "26",
    "pm_external_return_template_bundle_ready": "1",
    "v58_return_artifact_contract_ready": "1",
    "v58_required_artifact_rows": "8",
    "v58_required_artifact_approval_rows": "8",
    "v58_required_artifact_fixture_allowed_rows": "0",
    "v58_return_template_rows": "8",
    "v58_return_template_ready_rows": "8",
    "v58_return_template_fixture_allowed_rows": "0",
    "v58_return_contract_map_rows": "8",
    "v58_return_contract_map_ready_rows": "8",
    "v58_return_contract_map_default_blocked_rows": "8",
    "v58_acceptance_evidence_rows": "8",
    "v58_acceptance_evidence_contract_ready_rows": "8",
    "v58_acceptance_evidence_default_blocked_rows": "8",
    "v58_acceptance_evidence_blind_eval_ready_rows": "0",
    "v58_acceptance_evidence_tests_only_rows": "0",
    "v58_acceptance_evidence_hidden_state_rows": "0",
    "pm_roadmap_requirement_rows": "20",
    "pm_roadmap_ready_rows": "14",
    "pm_roadmap_blocked_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59e {field}: expected {value}, got {summary.get(field)}")
if int(summary["bundle_files"]) < 35:
    raise SystemExit("v59e should copy a substantial PM foundation bundle")

stage_rows = read_csv(run_dir / "pm_foundation_stage_replay_rows.csv")
if [row["stage"] for row in stage_rows] != ["v53t", "v53ap", "v53aq", "v54c", "h10_pm", "v58c_dependency", "v58d_dependency", "v58_blocker"]:
    raise SystemExit("v59e stage order mismatch")
if any(row["ready"] != "1" for row in stage_rows):
    raise SystemExit("v59e all PM stages should be replay-ready")
if [row["full_ready"] for row in stage_rows] != ["0", "0", "0", "1", "0", "0", "0", "0"]:
    raise SystemExit("v59e should only mark v54 generation as full-ready")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "pinned-public-sources-verified",
    "public-source-replay-policy",
    "complete-source-query-freeze",
    "route-memory-artifact-built",
    "local-abgh-baseline-run",
    "local-abgh-deterministic-adapter-run",
    "local-abgh-real-adapter-run",
    "local-abgh-row-contract-replay",
    "evaluator-check",
    "grounded-generation-outputs",
    "h10-real-label-readiness-ledger",
    "v58c-intake-dependency-blocker",
    "v58d-review-return-dependency-blocker",
    "v58-blind-eval-blocker-ledger",
    "no-hidden-local-state",
    "blocker-false-positive-closed",
    "one-command-entrypoint",
    "challenge-bundle-written",
    "pm-pr-claim-slice-gate",
    "pm-execution-lock",
    "pm-external-return-templates",
    "v58-required-return-artifacts",
    "one-command-replay-preflight",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59e gate should pass: {gate}")
for gate in ["public-source-download-execution", "v58-blind-response-intake", "v58-blind-review-intake", "real-blind-eval", "full-v59-public-demo", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59e gate should remain blocked: {gate}")

required_files = [
    "pm_foundation_stage_replay_rows.csv",
    "pm_foundation_one_command_rows.csv",
    "pm_foundation_replay_preflight_rows.csv",
    "local_abgh_row_contract_replay_rows.csv",
    "public_source_replay_policy_rows.csv",
    "public_source_snapshot_replay_rows.csv",
    "challenge_bundle_file_rows.csv",
    "pm_foundation_demo_gate_rows.csv",
    "pm_foundation_demo.sh",
    "README_RESULT.md",
    "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md",
    "v59e_one_command_pm_foundation_demo_manifest.json",
    "sha256_manifest.csv",
    "source_v53t/complete_source_pm_freeze_check_rows.csv",
    "source_v53ap/abgh_answer_rows.csv",
    "source_v53ap/abgh_citation_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53aq/adapter_selection_contract_rows.csv",
    "source_v53aq/abgh_system_metric_rows.csv",
    "source_v53aq/abgh_evaluator_rows.csv",
    "source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v53aq/routehint_rows.csv",
    "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "source_v54c/answer_rows.csv",
    "source_v54c/citation_rows.csv",
    "source_v54c/unsupported_claim_rows.csv",
    "source_v54c/abstain_rows.csv",
    "source_v54c/generator_resource_rows.csv",
    "source_v54c/wrong_answer_guard_rows.csv",
    "source_v54c/grounded_generation_output_contract_rows.csv",
    "source_v54c/generator_input_rows.csv",
    "source_v54c/compact_routehint_rows.csv",
    "source_v54c/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v54c/source_v53ap/abgh_evaluator_rows.csv",
    "source_v54c/sha256sums.txt",
    "source_v54c/V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md",
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv",
    "source_h10_pm/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53ap/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v58c_dependency/v58c_pm_blind_response_intake_dependency_rows.csv",
    "source_v58d_dependency/v58d_pm_blind_review_return_dependency_rows.csv",
    "source_v58_blocker/v58_pm_blind_eval_blocker_rows.csv",
    "v58_blind_eval_required_artifact_rows.csv",
    "v58_blind_eval_return_template_rows.csv",
    "v58_blind_eval_return_contract_map_rows.csv",
    "v58_blind_eval_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_summary.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_decision.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_merge_gate_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_blocker_closure_packet_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_pm_acceptance_evidence_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_query_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_span_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_answer_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_citation_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_evaluator_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_resource_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/adapter_selection_contract_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/abgh_system_metric_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/abgh_evaluator_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/routehint_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "source_pm_pr_claim_slice_gate/source_v59e/local_abgh_row_contract_replay_rows.csv",
    "source_pm_pr_claim_slice_gate/review_packets/docs__v1-roadmap.md",
    "source_pm_pr_claim_slice_gate/blocker_packets/v58c-intake-artifact-missing.md",
    "source_pm_pr_claim_slice_gate/blocker_packets/v58-real-blind-eval-missing.md",
    "source_pm_pr_claim_slice_gate/return_templates/v58c-intake-artifact-missing/v58c-intake-summary.csv",
    "source_pm_pr_claim_slice_gate/return_templates/v58-real-blind-eval-missing/v58d-review-return-intake.csv",
    "source_pm_pr_claim_slice_gate/return_templates/v60-release-evidence-missing/v59e-replay-preflight.csv",
    "source_pm_pr_claim_slice_gate/return_templates/v60-release-evidence-missing/v59-public-source-download-refresh.csv",
    "source_pm_pr_claim_slice_gate/return_templates/external-human-label-evidence-missing/h10-label-evidence-csv.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v59e artifact: {rel}")

acceptance_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/pm_pr_acceptance_evidence_rows.csv")
if len(acceptance_rows) != 10:
    raise SystemExit("v59e PM sidecar should carry ten PR acceptance evidence rows")
acceptance_by_id = {row["slice_id"]: row for row in acceptance_rows}
if sum(row["acceptance_ready"] == "1" for row in acceptance_rows) != 9:
    raise SystemExit("v59e PM sidecar should carry nine ready PR acceptance rows")
if any(row["tests_only_merge_condition"] != "0" for row in acceptance_rows):
    raise SystemExit("v59e PM sidecar PR acceptance rows should forbid tests-only merge conditions")
if acceptance_by_id["v53-query-instantiation-1000"]["replay_artifact_path"] != "source_v53t/complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("v59e PM sidecar v53 query acceptance should bind to query-span audit rows")
if acceptance_by_id["v53-system-a-b-g-h-measured"]["replay_artifact_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("v59e PM sidecar A/B/G/H acceptance should bind to local row-contract replay rows")
if acceptance_by_id["v59-one-command-demo"]["blocker_evidence_path"] != "source_v59e/public_source_replay_policy_rows.csv":
    raise SystemExit("v59e PM sidecar v59 acceptance should bind to public source replay policy rows")
v56_replay_acceptance_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv")
if len(v56_replay_acceptance_rows) != 4:
    raise SystemExit("v59e PM sidecar should carry four v56 replay acceptance evidence rows")
v56_replay_artifacts = {row["artifact_id"]: row for row in v56_replay_acceptance_rows}
for artifact_id in ["v56-contract-summary", "v56-contract-artifacts", "v56b-scale-summary", "v56b-scale-artifacts"]:
    row = v56_replay_artifacts.get(artifact_id)
    if not row:
        raise SystemExit(f"v59e PM sidecar missing v56 replay artifact row: {artifact_id}")
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v59e PM sidecar should keep v56 claim/blocker boundaries closed: {artifact_id}")
    if row["acceptance_ready"] != "0" or row["acceptance_status"] != "blocked":
        raise SystemExit(f"v59e PM sidecar should keep v56 artifact blocked without replay evidence: {artifact_id}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v59e PM sidecar should require approval and forbid fixtures for v56: {artifact_id}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v59e PM sidecar should forbid tests-only v56 acceptance: {artifact_id}")
if "V56B_ALLOW_CONTRACT_REBUILD=1" not in v56_replay_artifacts["v56b-scale-artifacts"]["validation_command"]:
    raise SystemExit("v59e PM sidecar should preserve the approval-gated v56b validation command")
de_acceptance_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv")
if len(de_acceptance_rows) != 4:
    raise SystemExit("v59e PM sidecar should carry four D/E 30B/70B acceptance evidence rows")
de_artifacts = {row["artifact_id"]: row for row in de_acceptance_rows}
for artifact_id, system_id in {
    "d-model-identity": "D",
    "d-answer-citation-resource": "D",
    "e-model-identity": "E",
    "e-answer-citation-resource": "E",
}.items():
    row = de_artifacts.get(artifact_id)
    if not row:
        raise SystemExit(f"v59e PM sidecar missing D/E artifact row: {artifact_id}")
    if row["system_id"] != system_id:
        raise SystemExit(f"v59e PM sidecar D/E system mismatch: {artifact_id}")
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v59e PM sidecar should keep D/E claim/blocker boundaries closed: {artifact_id}")
    if row["acceptance_ready"] != "0" or row["acceptance_status"] != "blocked":
        raise SystemExit(f"v59e PM sidecar should keep D/E baseline evidence blocked: {artifact_id}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v59e PM sidecar should require approval and forbid fixtures for D/E: {artifact_id}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v59e PM sidecar should forbid tests-only D/E acceptance: {artifact_id}")
if "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR>" not in de_artifacts["e-answer-citation-resource"]["validation_command"]:
    raise SystemExit("v59e PM sidecar should preserve the approval-gated D/E validation command")
v59_acceptance_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv")
if len(v59_acceptance_rows) != 2:
    raise SystemExit("v59e PM sidecar should carry two v59 one-command acceptance rows")
v59_artifacts = {row["artifact_id"]: row for row in v59_acceptance_rows}
row = v59_artifacts.get("v59e-local-abgh-row-contract-replay")
if not row or row["acceptance_ready"] != "1" or row["acceptance_status"] != "ready":
    raise SystemExit("v59e PM sidecar should preserve ready local A/B/G/H row-contract artifact")
if row["output_artifact_replay_status"] != "pass":
    raise SystemExit("v59e PM sidecar should preserve passing local A/B/G/H replay status")
refresh_row = v59_artifacts.get("v59-public-source-download-refresh")
if not refresh_row:
    raise SystemExit("v59e PM sidecar should carry public-source refresh row")
if refresh_row["acceptance_ready"] != "0" or refresh_row["acceptance_status"] != "blocked":
    raise SystemExit("v59e PM sidecar should keep live public-source refresh blocked")
if "full_public_source_download_ready=0" not in refresh_row["observed_signal"]:
    raise SystemExit("v59e PM sidecar should expose blocked full public-source download readiness")
for row in v59_acceptance_rows:
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v59e PM sidecar should keep v59 claim/blocker boundaries closed: {row['artifact_id']}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1" or row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v59e PM sidecar should preserve approval/no-fixture/no-tests-only boundary: {row['artifact_id']}")

pm_v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(pm_v53t_real_adapter_rows) != 4:
    raise SystemExit("v59e PM sidecar should carry four v53t real-adapter freeze rows")
if pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["status"] != "pass":
    raise SystemExit("v59e PM sidecar should carry passing v53t real-adapter execution evidence")
if "coherent_wrong_key_rows=287" not in pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v59e PM sidecar should preserve v53aq coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in pm_v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v59e PM sidecar should preserve v53aq public comparison blocker")

pm_v53_acceptance_rows = {
    row["requirement_id"]: row
    for row in read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/complete_source_pm_acceptance_evidence_rows.csv")
}
if len(pm_v53_acceptance_rows) != 10:
    raise SystemExit("v59e PM sidecar should carry ten v53 PM acceptance evidence rows")
if any(row["acceptance_ready"] != "1" or row["tests_only_merge_condition"] != "0" for row in pm_v53_acceptance_rows.values()):
    raise SystemExit("v59e PM sidecar v53 acceptance rows should be ready and not tests-only")
for requirement_id, snippet in {
    "source-span-query-freeze": "binding_audit_pass_rows=1000",
    "answer-citation-separated-evaluator": "separate_evaluator_rows=4000",
    "abgh-same-query-deterministic-prebaseline": "real_system_performance_claim_ready=0",
    "abgh-real-adapter-same-query-internal": "public_comparison_claim_ready=0",
    "public-comparison-boundary-closed": "required_30b_baseline_ready=0",
}.items():
    if snippet not in pm_v53_acceptance_rows[requirement_id]["actual_value"]:
        raise SystemExit(f"v59e PM sidecar v53 acceptance row should expose {snippet}: {requirement_id}")

repo_coverage_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
file_manifest_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
content_repo_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv")
content_snapshot_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")
binding_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv")
v53aq_prebaseline_rows = read_csv(run_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
pm_v53aq_prebaseline_rows = read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
if len(repo_coverage_rows) != 10 or len(content_repo_rows) != 10:
    raise SystemExit("v59e PM sidecar should carry direct 10-repo manifest rows")
if len(file_manifest_rows) != 11266 or len(content_snapshot_rows) != 11266:
    raise SystemExit("v59e PM sidecar should carry direct file/content manifest rows")
if len(binding_rows) != 1000 or any(row["binding_status"] != "pass" for row in binding_rows):
    raise SystemExit("v59e PM sidecar should carry 1000 passing query-span binding audit rows")
for label, rows in [("direct", v53aq_prebaseline_rows), ("PM sidecar", pm_v53aq_prebaseline_rows)]:
    if len(rows) != 1000:
        raise SystemExit(f"v59e should carry 1000 {label} v53aq same-query ledger rows")
    if any(row["same_evaluator_contract"] != "1" or row["same_resource_bound"] != "1" or row["public_comparison_claim_ready"] != "0" for row in rows):
        raise SystemExit(f"v59e {label} v53aq same-query ledger should preserve evaluator/resource and public-comparison boundary")
local_abgh_contract_rows = {
    row["source_stage"]: row
    for row in read_csv(run_dir / "local_abgh_row_contract_replay_rows.csv")
}
pm_local_abgh_contract_rows = {
    row["source_stage"]: row
    for row in read_csv(run_dir / "source_pm_pr_claim_slice_gate/source_v59e/local_abgh_row_contract_replay_rows.csv")
}
if set(local_abgh_contract_rows) != {"v53ap", "v53aq"}:
    raise SystemExit("v59e local A/B/G/H row-contract replay should cover v53ap and v53aq")
if pm_local_abgh_contract_rows != local_abgh_contract_rows:
    raise SystemExit("v59e PM sidecar should carry the same local A/B/G/H row-contract replay rows")
for stage, row in local_abgh_contract_rows.items():
    if (
        row["status"] != "pass"
        or row["systems"] != "A/B/G/H"
        or row["expected_query_rows"] != "1000"
        or row["observed_query_rows"] != "1000"
        or row["answer_rows"] != "4000"
        or row["citation_rows"] != "4000"
        or row["evaluator_rows"] != "4000"
        or row["resource_rows"] != "4000"
        or row["same_query_row_contract"] != "1"
        or row["same_evaluator_contract_all_local_systems"] != "1"
        or row["same_resource_contract_all_local_systems"] != "1"
        or row["evaluator_bound_rows"] != "4000"
        or row["answer_resource_bound_rows"] != "4000"
        or row["answer_eval_separate_rows"] != "4000"
        or row["citation_eval_separate_rows"] != "4000"
        or row["resource_eval_separate_rows"] != "4000"
        or row["resource_row_bound_rows"] != "4000"
        or row["expected_answer_oracle_replay_zero_rows"] != "4000"
        or row["expected_answer_oracle_replay_any"] != "0"
        or row["no_external_model_rows"] != "4000"
        or row["no_external_network_rows"] != "4000"
        or row["public_comparison_claim_ready"] != "0"
    ):
        raise SystemExit(f"v59e {stage} row-contract replay should pass row/evaluator/resource/public-claim checks")
if (
    local_abgh_contract_rows["v53ap"]["deterministic_source_span_adapter_execution_rows"] != "4000"
    or local_abgh_contract_rows["v53ap"]["actual_adapter_execution_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53ap"]["real_adapter_execution_ready_rows"] != "0"
    or local_abgh_contract_rows["v53ap"]["real_system_performance_claim_ready_rows"] != "0"
    or local_abgh_contract_rows["v53ap"]["same_query_internal_prebaseline_rows"] != "0"
):
    raise SystemExit("v59e v53ap row-contract replay should preserve deterministic adapter and blocked real-performance boundary")
if (
    local_abgh_contract_rows["v53aq"]["deterministic_source_span_adapter_execution_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["actual_adapter_execution_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["real_adapter_execution_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["real_system_performance_claim_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["selection_question_text_only_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["selection_oracle_field_used_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["same_query_internal_prebaseline_rows"] != "1000"
    or local_abgh_contract_rows["v53aq"]["same_query_internal_prebaseline_ready"] != "1"
):
    raise SystemExit("v59e v53aq row-contract replay should preserve query-text-only real-adapter and 1000-row prebaseline boundary")
if any(row["complete_source_tree_manifest_ready"] != "1" for row in repo_coverage_rows):
    raise SystemExit("v59e PM sidecar repo coverage rows should preserve ready tree manifests")
if any(row["content_snapshot_ready"] != "1" for row in content_repo_rows):
    raise SystemExit("v59e PM sidecar content repo rows should preserve ready content snapshots")

h10_v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(h10_v53t_real_adapter_rows) != 4:
    raise SystemExit("v59e h10 PM source bundle should carry four v53t real-adapter freeze rows")
if h10_v53t_real_adapter_rows["real-adapter-execution-rows"]["status"] != "pass":
    raise SystemExit("v59e h10 PM source bundle should carry passing v53t real-adapter execution evidence")
if "coherent_wrong_key_rows=287" not in h10_v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v59e h10 PM source bundle should preserve v53aq coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in h10_v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v59e h10 PM source bundle should preserve public comparison blocker")

for label, path in [
    ("h10 PM source bundle", run_dir / "source_h10_pm/h10_real_label_return_contract_rows.csv"),
    ("PM sidecar h10 bundle", run_dir / "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_return_contract_rows.csv"),
]:
    rows = read_csv(path)
    if len(rows) != 6:
        raise SystemExit(f"v59e {label} should carry six h10 return contract rows")
    if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in rows):
        raise SystemExit(f"v59e {label} should preserve no-fixture approval-required h10 return contracts")
    if any(row["contract_ready"] != "1" or row["acceptance_status"] != "blocked" for row in rows):
        raise SystemExit(f"v59e {label} should keep h10 return contracts ready but blocked without accepted labels")
    by_criterion = {row["criterion"]: row for row in rows}
    if by_criterion["source-provenance-binding"]["evidence_column"] != "source_provenance_labels":
        raise SystemExit(f"v59e {label} should bind source provenance labels")
    if "query_rows>=1000" not in by_criterion["external-human-label-evidence"]["external_label_dependency"]:
        raise SystemExit(f"v59e {label} should require 1000 query rows for external/human labels")

for label, path in [
    ("h10 PM source bundle", run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv"),
    ("PM sidecar h10 bundle", run_dir / "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_acceptance_evidence_rows.csv"),
]:
    rows = read_csv(path)
    if len(rows) != 6:
        raise SystemExit(f"v59e {label} should carry six h10 acceptance evidence rows")
    by_criterion = {row["criterion"]: row for row in rows}
    if set(by_criterion) != {
        "coherent-wrong-key-reduction",
        "chunk-exact-increase",
        "near-miss-slash",
        "missing-query-abstain",
        "source-provenance-binding",
        "external-human-label-evidence",
    }:
        raise SystemExit(f"v59e {label} h10 acceptance evidence criteria mismatch")
    if any(row["claim_boundary_status"] != "pass" or row["output_artifact_replay_status"] != "pass" for row in rows):
        raise SystemExit(f"v59e {label} should preserve claim/replay pass status")
    if any(row["blocker_false_positive_status"] != "pass" for row in rows):
        raise SystemExit(f"v59e {label} should preserve blocker false-positive closure")
    if any(row["acceptance_ready"] != "1" or row["promotion_ready"] != "0" for row in rows):
        raise SystemExit(f"v59e {label} should remain contract-ready but promotion-blocked")
    if any(row["tests_only_merge_condition"] != "0" or row["fixture_allowed"] != "0" for row in rows):
        raise SystemExit(f"v59e {label} should reject tests-only and fixture h10 acceptance evidence")
    for criterion, row in by_criterion.items():
        for field in [
            "accepted_real_label_evidence_rows",
            "accepted_query_rows_declared",
            "accepted_label_rows",
            "accepted_criterion_label_count",
            "required_criterion_label_count",
            "criterion_label_coverage_status",
            "source_verified_eval_status",
        ]:
            if field not in row:
                raise SystemExit(f"v59e {label} h10 acceptance evidence missing {field} for {criterion}")
        if row["accepted_real_label_evidence_rows"] != "0":
            raise SystemExit(f"v59e {label} should record zero accepted real-label rows for {criterion}")
        if row["accepted_query_rows_declared"] != "0" or row["accepted_label_rows"] != "0":
            raise SystemExit(f"v59e {label} should record zero accepted query/label rows for {criterion}")
        if row["accepted_criterion_label_count"] != "0":
            raise SystemExit(f"v59e {label} should keep criterion label coverage at zero for {criterion}")
        if row["criterion_label_coverage_status"] != "blocked":
            raise SystemExit(f"v59e {label} should keep criterion label coverage blocked for {criterion}")
        if row["source_verified_eval_status"] != "blocked":
            raise SystemExit(f"v59e {label} should keep source-verified eval blocked for {criterion}")

for label, path in [
    ("h10 PM source bundle", run_dir / "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
    ("PM sidecar h10 bundle", run_dir / "source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
]:
    rows = read_csv(path)
    if len(rows) != 1000:
        raise SystemExit(f"v59e {label} should carry 1000 v53aq same-query prebaseline rows")
    if any(
        row["same_query_all_systems"] != "1"
        or row["same_evaluator_contract"] != "1"
        or row["same_resource_bound"] != "1"
        or row["selection_question_text_only_all"] != "1"
        or row["selection_oracle_field_used_any"] != "0"
        or row["expected_answer_oracle_replay_any"] != "0"
        or row["deterministic_source_span_adapter_execution_any"] != "0"
        or row["g_h_routehint_no_raw_context"] != "1"
        or row["public_comparison_claim_ready"] != "0"
        for row in rows
    ):
        raise SystemExit(f"v59e {label} should preserve v53aq same-query/no-oracle/no-public-claim boundary")

v54c_expected_counts = {
    "answer_rows.csv": 1000,
    "citation_rows.csv": 1000,
    "unsupported_claim_rows.csv": 160,
    "abstain_rows.csv": 160,
    "generator_resource_rows.csv": 1000,
    "wrong_answer_guard_rows.csv": 1000,
    "compact_routehint_rows.csv": 1000,
}
for filename, expected_count in v54c_expected_counts.items():
    rows = read_csv(run_dir / "source_v54c" / filename)
    if len(rows) != expected_count:
        raise SystemExit(f"v59e should carry {expected_count} v54c rows for {filename}, got {len(rows)}")
generator_inputs = read_csv(run_dir / "source_v54c/generator_input_rows.csv")
if len(generator_inputs) != 1000:
    raise SystemExit("v59e should carry 1000 v54c generator input rows")
if any(row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" for row in generator_inputs):
    raise SystemExit("v59e v54c generator inputs should preserve the no raw prompt stuffing boundary")
v54c_contracts = read_csv(run_dir / "source_v54c/grounded_generation_output_contract_rows.csv")
v54c_contract_counts = {
    "answer-rows": ("answer_rows.csv", 1000),
    "citation-rows": ("citation_rows.csv", 1000),
    "unsupported-claim-rows": ("unsupported_claim_rows.csv", 160),
    "abstain-rows": ("abstain_rows.csv", 160),
    "generator-resource-rows": ("generator_resource_rows.csv", 1000),
    "wrong-answer-guard-rows": ("wrong_answer_guard_rows.csv", 1000),
    "generator-input-rows": ("generator_input_rows.csv", 1000),
    "compact-routehint-rows": ("compact_routehint_rows.csv", 1000),
}
v54c_contract_by_id = {row["artifact_id"]: row for row in v54c_contracts}
if len(v54c_contracts) != 9 or set(v54c_contract_by_id) != set(v54c_contract_counts) | {"sha256sums"}:
    raise SystemExit("v59e should carry the full v54c grounded-generation output contract")
if sum(row["pm_recommended_output"] == "1" for row in v54c_contracts) != 7:
    raise SystemExit("v59e v54c contract should preserve seven PM recommended artifacts")
for artifact_id, (artifact_path, expected_count) in v54c_contract_counts.items():
    row = v54c_contract_by_id[artifact_id]
    if row["artifact_path"] != artifact_path:
        raise SystemExit(f"v59e v54c contract path mismatch for {artifact_id}")
    if row["expected_row_count"] != str(expected_count) or row["observed_row_count"] != str(expected_count):
        raise SystemExit(f"v59e v54c contract row count mismatch for {artifact_id}")
    if row["artifact_sha256"] != sha256(run_dir / "source_v54c" / artifact_path) or row["sha256_bound"] != "1":
        raise SystemExit(f"v59e v54c contract sha256 binding mismatch for {artifact_id}")
    if row["raw_prompt_context_appended_allowed"] != "0" or row["raw_prompt_context_appended_rows"] != "0":
        raise SystemExit(f"v59e v54c contract should forbid raw prompt context for {artifact_id}")
    if row["source_span_bound"] != "1" or row["v53ap_provenance_bound"] != "1" or row["wrong_answer_guarded"] != "1":
        raise SystemExit(f"v59e v54c contract should preserve provenance and guard binding for {artifact_id}")
sha_contract = v54c_contract_by_id["sha256sums"]
if (
    sha_contract["artifact_path"] != "sha256sums.txt"
    or sha_contract["expected_row_count"] != "not-csv"
    or sha_contract["observed_row_count"] != "written-after-contract"
    or sha_contract["sha256_bound"] != "0"
    or sha_contract["raw_prompt_context_appended_rows"] != "0"
):
    raise SystemExit("v59e v54c sha256sums contract should preserve its post-contract boundary")

manifest = json.loads((run_dir / "v59e_one_command_pm_foundation_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v59e_one_command_pm_foundation_demo_ready") != 1 or manifest.get("v59_ready") != 0:
    raise SystemExit("v59e manifest readiness mismatch")
if (
    manifest.get("v53_negative_abstain_rows") != 160
    or manifest.get("v53_unsupported_control_rows") != 100
    or manifest.get("v53_ambiguous_control_rows") != 30
    or manifest.get("v53_missing_specific_control_rows") != 30
    or manifest.get("v53_doc_code_conflict_rows") != 140
):
    raise SystemExit("v59e manifest should record v53 control-row evidence")
if "h10-real-label-promotion" not in manifest.get("blocked_claims", []):
    raise SystemExit("v59e manifest should block h10 real-label promotion")
if "public-abgh-comparison" not in manifest.get("blocked_claims", []):
    raise SystemExit("v59e manifest should block public A/B/G/H comparison claims")
if (
    manifest.get("source_snapshot_replay_used") != 1
    or manifest.get("public_source_snapshot_replay_rows") != 10
    or manifest.get("public_source_snapshot_replay_pass_rows") != 10
    or manifest.get("public_source_snapshot_replay_ready") != 1
    or manifest.get("public_source_download_executed") != 0
    or manifest.get("public_source_download_approval_required") != 1
    or manifest.get("full_public_source_download_ready") != 0
):
    raise SystemExit("v59e manifest should preserve public source replay/download boundary")
if (
    manifest.get("local_abgh_row_contract_replay_rows") != 2
    or manifest.get("local_abgh_row_contract_replay_pass_rows") != 2
    or manifest.get("local_abgh_row_contract_replay_ready") != 1
    or manifest.get("local_abgh_deterministic_adapter_ready") != 1
    or manifest.get("v53ap_expected_answer_oracle_replay") != 0
    or manifest.get("v53ap_deterministic_source_span_adapter_execution") != 1
    or manifest.get("v53ap_deterministic_source_span_adapter_rows") != 4000
    or manifest.get("v53ap_actual_adapter_execution_ready") != 1
):
    raise SystemExit("v59e manifest should preserve the v53ap deterministic adapter boundary")
if "local_abgh_row_contract_replay_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind local A/B/G/H row-contract replay rows")
if (
    manifest.get("local_abgh_real_adapter_ready") != 1
    or manifest.get("v53aq_complete_source_abgh_real_adapter_measured_ready") != 1
    or manifest.get("v53aq_selection_question_text_only") != 1
    or manifest.get("v53aq_selection_oracle_field_used") != 0
    or manifest.get("v53aq_expected_answer_oracle_replay") != 0
    or manifest.get("v53aq_deterministic_source_span_adapter_execution") != 0
    or manifest.get("v53aq_real_adapter_execution_ready") != 1
    or manifest.get("v53aq_real_system_performance_claim_ready") != 1
    or manifest.get("v53aq_answer_hash_match_rows") != 3713
    or manifest.get("v53aq_coherent_wrong_key_rows") != 287
):
    raise SystemExit("v59e manifest should preserve the v53aq real-adapter boundary")
if (
    manifest.get("v54c_output_contract_rows") != 9
    or manifest.get("v54c_output_contract_pm_required_rows") != 7
    or manifest.get("v54c_output_contract_raw_prompt_forbidden_rows") != 9
):
    raise SystemExit("v59e manifest should record the v54c grounded-generation output contract")
if (
    manifest.get("h10_real_label_acceptance_evidence_rows") != 6
    or manifest.get("h10_real_label_acceptance_evidence_ready_rows") != 6
    or manifest.get("h10_real_label_acceptance_evidence_promotion_ready_rows") != 0
    or manifest.get("h10_real_label_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v59e manifest should record h10 acceptance evidence")
for field in [
    "h10_accepted_query_rows_declared",
    "h10_accepted_label_rows",
    "h10_accepted_coherent_wrong_key_labels",
    "h10_accepted_chunk_exact_labels",
    "h10_accepted_near_miss_labels",
    "h10_accepted_missing_query_labels",
    "h10_accepted_source_provenance_labels",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v59e manifest should keep {field}=0 without accepted h10 labels")
if manifest.get("h10_real_label_acceptance_evidence_coverage_field_rows") != 6:
    raise SystemExit("v59e manifest should record coverage fields for all h10 acceptance evidence rows")
if manifest.get("h10_real_label_acceptance_evidence_zero_accepted_rows") != 6:
    raise SystemExit("v59e manifest should record all h10 acceptance evidence rows as zero-accepted")
if manifest.get("h10_real_label_acceptance_evidence_coverage_blocked_rows") != 6:
    raise SystemExit("v59e manifest should keep h10 criterion label coverage blocked")
if manifest.get("h10_real_label_acceptance_evidence_source_verified_blocked_rows") != 6:
    raise SystemExit("v59e manifest should keep h10 source-verified eval blocked")
if "h10_real_label_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind h10 acceptance evidence rows")
if (
    manifest.get("v58c_intake_artifact_available") != 0
    or manifest.get("v58c_dependency_blocker_ready") != 1
    or manifest.get("v58c_blind_response_evidence_intake_ready") != 0
    or manifest.get("v58c_expected_blind_response_rows") != 0
    or manifest.get("v58c_required_blind_response_ready") != 0
    or manifest.get("v58c_human_blind_review_ready") != 0
):
    raise SystemExit("v59e manifest should preserve the v58c blind-response intake blocker boundary")
if (
    manifest.get("v58d_review_artifact_available") != 0
    or manifest.get("v58d_dependency_blocker_ready") != 1
    or manifest.get("v58d_blind_review_return_intake_ready") != 0
    or manifest.get("v58d_expected_required_review_rows") != 0
    or manifest.get("v58d_human_blind_review_ready") != 0
):
    raise SystemExit("v59e manifest should preserve the v58d blind-review return blocker boundary")
if (
    manifest.get("v58_return_artifact_contract_ready") != 1
    or manifest.get("v58_required_artifact_rows") != 8
    or manifest.get("v58_required_artifact_fixture_allowed_rows") != 0
    or manifest.get("v58_return_template_rows") != 8
    or manifest.get("v58_return_template_ready_rows") != 8
    or manifest.get("v58_return_template_fixture_allowed_rows") != 0
    or manifest.get("v58_return_contract_map_rows") != 8
    or manifest.get("v58_return_contract_map_ready_rows") != 8
    or manifest.get("v58_return_contract_map_default_blocked_rows") != 8
):
    raise SystemExit("v59e manifest should record v58 required return artifact contract readiness")
if (
    manifest.get("v58_acceptance_evidence_rows") != 8
    or manifest.get("v58_acceptance_evidence_contract_ready_rows") != 8
    or manifest.get("v58_acceptance_evidence_default_blocked_rows") != 8
    or manifest.get("v58_acceptance_evidence_blind_eval_ready_rows") != 0
    or manifest.get("v58_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("v58_acceptance_evidence_hidden_state_rows") != 0
):
    raise SystemExit("v59e manifest should record v58 acceptance evidence")
if "v58_blind_eval_return_contract_map_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind v58 return contract map rows")
if "v58_blind_eval_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind v58 acceptance evidence rows")
if manifest.get("pm_pr_claim_slice_bundle_ready") != 1:
    raise SystemExit("v59e manifest should include the PM PR sidecar bundle")
if (
    manifest.get("pm_pr_acceptance_evidence_rows") != 10
    or manifest.get("pm_pr_acceptance_evidence_ready_rows") != 9
    or manifest.get("pm_pr_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v59e manifest should record PM PR acceptance evidence rows")
if (
    manifest.get("pm_pr_v56_replay_acceptance_evidence_rows") != 4
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_ready_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_blocked_rows") != 4
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_approval_rows") != 4
):
    raise SystemExit("v59e manifest should record PM v56 replay acceptance evidence")
if "pm_pr_v56_replay_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind PM v56 replay acceptance evidence")
if (
    manifest.get("pm_pr_de_30b70b_acceptance_evidence_rows") != 4
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_ready_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_blocked_rows") != 4
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_approval_rows") != 4
):
    raise SystemExit("v59e manifest should record PM D/E 30B/70B acceptance evidence")
if "pm_pr_de_30b70b_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind PM D/E acceptance evidence")
if (
    manifest.get("pm_pr_v59_one_command_acceptance_evidence_rows") != 2
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_ready_rows") != 1
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_blocked_rows") != 1
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_approval_rows") != 2
):
    raise SystemExit("v59e manifest should record PM v59 one-command acceptance evidence")
if "pm_pr_v59_one_command_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("v59e manifest should hash-bind PM v59 one-command acceptance evidence")
if (
    manifest.get("pm_pr_v53_query_span_binding_audit_ready") != 1
    or manifest.get("pm_pr_v53_query_span_binding_audit_rows") != 1000
    or manifest.get("pm_pr_v53_query_span_binding_pass_rows") != 1000
):
    raise SystemExit("v59e manifest should record direct v53 query-span binding audit evidence")
if (
    manifest.get("pm_pr_v53_direct_pinned_manifest_ready") != 1
    or manifest.get("pm_pr_v53_direct_repo_manifest_rows") != 10
    or manifest.get("pm_pr_v53_direct_file_manifest_rows") != 11266
    or manifest.get("pm_pr_v53_direct_content_snapshot_rows") != 11266
):
    raise SystemExit("v59e manifest should record direct v53 pinned manifest evidence")
if (
    manifest.get("pm_pr_v53_pm_acceptance_evidence_rows") != 10
    or manifest.get("pm_pr_v53_pm_acceptance_evidence_ready_rows") != 10
    or manifest.get("pm_pr_v53_pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v59e manifest should record v53 PM acceptance evidence")
if manifest.get("pm_scope_drift_allowed") != 0:
    raise SystemExit("v59e manifest should keep PM scope drift locked")
if manifest.get("one_command_replay_preflight_ready") != 1:
    raise SystemExit("v59e manifest should record replay preflight readiness")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v59e sha256 mismatch: {rel}")

boundary = (run_dir / "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v59e_one_command_pm_foundation_demo_ready=1",
    "pm_v53_freeze_ready=1",
    "source_snapshot_replay_used=1",
    "public_source_snapshot_replay_ready=1",
    "public_source_snapshot_replay_rows=10",
    "public_source_download_executed=0",
    "public_source_download_approval_required=1",
    "full_public_source_download_ready=0",
    "v53_negative_abstain_rows=160",
    "v53_unsupported_control_rows=100",
    "v53_ambiguous_control_rows=30",
    "v53_missing_specific_control_rows=30",
    "v53_doc_code_conflict_rows=140",
    "local_abgh_row_contract_replay_rows=2",
    "local_abgh_row_contract_replay_pass_rows=2",
    "local_abgh_row_contract_replay_ready=1",
    "local_abgh_deterministic_adapter_ready=1",
    "local_abgh_real_adapter_ready=1",
    "v53ap_expected_answer_oracle_replay=0",
    "v53ap_deterministic_source_span_adapter_execution=1",
    "v53ap_deterministic_source_span_adapter_rows=4000",
    "v53ap_actual_adapter_execution_ready=1",
    "v53aq_real_adapter_execution_ready=1",
    "v53aq_selection_question_text_only=1",
    "v53aq_selection_oracle_field_used=0",
    "v53aq_answer_hash_match_rows=3713",
    "v53aq_coherent_wrong_key_rows=287",
    "v54c_output_contract_rows=9",
    "v54c_output_contract_pm_required_rows=7",
    "v54c_output_contract_raw_prompt_forbidden_rows=9",
    "v54c_v53ap_evaluator_provenance_ready=1",
    "v54c_v53ap_evaluator_provenance_rows=1000",
    "h10_real_label_promotion_ready=0",
    "h10_real_label_acceptance_evidence_rows=6",
    "h10_real_label_acceptance_evidence_ready_rows=6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows=0",
    "h10_real_label_acceptance_evidence_tests_only_rows=0",
    "h10_accepted_query_rows_declared=0",
    "h10_accepted_label_rows=0",
    "h10_accepted_coherent_wrong_key_labels=0",
    "h10_accepted_chunk_exact_labels=0",
    "h10_accepted_near_miss_labels=0",
    "h10_accepted_missing_query_labels=0",
    "h10_accepted_source_provenance_labels=0",
    "h10_real_label_acceptance_evidence_coverage_field_rows=6",
    "h10_real_label_acceptance_evidence_zero_accepted_rows=6",
    "h10_real_label_acceptance_evidence_coverage_blocked_rows=6",
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows=6",
    "v58c_intake_artifact_available=0",
    "v58c_dependency_blocker_ready=1",
    "v58c_blind_response_evidence_intake_ready=0",
    "v58c_expected_blind_response_rows=0",
    "v58c_required_blind_response_ready=0",
    "v58c_human_blind_review_ready=0",
    "v58d_review_artifact_available=0",
    "v58d_dependency_blocker_ready=1",
    "v58d_blind_review_return_intake_ready=0",
    "v58d_expected_required_review_rows=0",
    "v58d_human_blind_review_ready=0",
    "v58_full_blind_eval_ready=0",
    "v58_return_artifact_contract_ready=1",
    "v58_required_artifact_fixture_allowed_rows=0",
    "v58_return_template_fixture_allowed_rows=0",
    "v58_acceptance_evidence_rows=8",
    "v58_acceptance_evidence_contract_ready_rows=8",
    "v58_acceptance_evidence_default_blocked_rows=8",
    "v58_acceptance_evidence_blind_eval_ready_rows=0",
    "v58_acceptance_evidence_tests_only_rows=0",
    "v58_acceptance_evidence_hidden_state_rows=0",
    "pm_pr_claim_slice_bundle_ready=1",
    "pm_pr_v53_pm_acceptance_evidence_rows=10",
    "pm_pr_v53_pm_acceptance_evidence_ready_rows=10",
    "pm_pr_v53_pm_acceptance_evidence_tests_only_rows=0",
    "pm_scope_drift_allowed=0",
    "one_command_replay_preflight_ready=1",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v59e boundary missing: {snippet}")

policy_rows = read_csv(run_dir / "public_source_replay_policy_rows.csv")
if len(policy_rows) != 1:
    raise SystemExit("v59e should emit one public source replay policy row")
policy = policy_rows[0]
if (
    policy["pinned_public_sources_verified"] != "1"
    or policy["public_source_snapshot_replay_rows"] != "10"
    or policy["public_source_snapshot_replay_pass_rows"] != "10"
    or policy["public_source_snapshot_replay_ready"] != "1"
    or policy["source_snapshot_replay_used"] != "1"
    or policy["public_source_download_executed"] != "0"
    or policy["public_source_download_approval_required"] != "1"
    or policy["network_required_by_default"] != "0"
    or policy["downloads_required_by_default"] != "0"
    or policy["full_public_source_download_ready"] != "0"
    or policy["blocker_status"] != "blocked-full-public-demo"
):
    raise SystemExit("v59e public source replay policy boundary mismatch")
snapshot_rows = read_csv(run_dir / "public_source_snapshot_replay_rows.csv")
if len(snapshot_rows) != 10:
    raise SystemExit("v59e should emit ten public source snapshot replay rows")
if len({row["owner_repo"] for row in snapshot_rows}) != 10:
    raise SystemExit("v59e public source snapshot replay rows should cover ten distinct repositories")
if any(
    row["replay_status"] != "pass"
    or row["tree_manifest_ready"] != "1"
    or row["content_snapshot_ready"] != "1"
    or row["source_snapshot_replay_used"] != "1"
    or row["public_source_download_executed"] != "0"
    or row["network_required_by_default"] != "0"
    or row["downloads_required_by_default"] != "0"
    or not row["repo_url"].startswith("https://github.com/")
    or len(row["pinned_commit_sha"]) != 40
    for row in snapshot_rows
):
    raise SystemExit("v59e public source snapshot replay rows should preserve pinned no-download source evidence")
bundle_rows = read_csv(run_dir / "challenge_bundle_file_rows.csv")
if "public_source_replay_policy_rows.csv" not in {row["path"] for row in bundle_rows}:
    raise SystemExit("v59e bundle index should include public source replay policy rows")
if "public_source_snapshot_replay_rows.csv" not in {row["path"] for row in bundle_rows}:
    raise SystemExit("v59e bundle index should include public source snapshot replay rows")
if "pm_foundation_replay_preflight_rows.csv" not in {row["path"] for row in bundle_rows}:
    raise SystemExit("v59e bundle index should include replay preflight rows")
if "local_abgh_row_contract_replay_rows.csv" not in {row["path"] for row in bundle_rows}:
    raise SystemExit("v59e bundle index should include local A/B/G/H row-contract replay rows")
for rel in [
    "v58_blind_eval_required_artifact_rows.csv",
    "v58_blind_eval_return_template_rows.csv",
    "v58_blind_eval_return_contract_map_rows.csv",
    "v58_blind_eval_acceptance_evidence_rows.csv",
]:
    if rel not in {row["path"] for row in bundle_rows}:
        raise SystemExit(f"v59e bundle index should include {rel}")

v58_required_rows = read_csv(run_dir / "v58_blind_eval_required_artifact_rows.csv")
if len(v58_required_rows) != 8:
    raise SystemExit("v59e should emit eight v58 required artifact rows")
v58_required_by_blocker = {}
for row in v58_required_rows:
    v58_required_by_blocker.setdefault(row["blocker_class"], []).append(row)
if len(v58_required_by_blocker.get("v58c-intake-artifact-missing", [])) != 3:
    raise SystemExit("v59e v58 required artifact rows should include three v58c intake artifacts")
if len(v58_required_by_blocker.get("v58-real-blind-eval-missing", [])) != 5:
    raise SystemExit("v59e v58 required artifact rows should include five real blind-eval artifacts")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in v58_required_rows):
    raise SystemExit("v59e v58 required artifact rows should forbid fixtures and require approval")
expected_v58_artifacts = {
    "v58c-intake-summary",
    "v58c-intake-artifacts",
    "v58c-source-v58b-freeze",
    "v58-blind-response-rows",
    "v58-run-identity-rows",
    "v58-human-review-rows",
    "v58d-review-return-intake",
    "v58-sha256-manifest",
}
if {row["artifact_id"] for row in v58_required_rows} != expected_v58_artifacts:
    raise SystemExit("v59e v58 required artifact ids mismatch")

v58_template_rows = read_csv(run_dir / "v58_blind_eval_return_template_rows.csv")
if len(v58_template_rows) != 8:
    raise SystemExit("v59e should emit eight v58 return template rows")
if {row["artifact_id"] for row in v58_template_rows} != expected_v58_artifacts:
    raise SystemExit("v59e v58 return template ids mismatch")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" or row["template_ready"] != "1" for row in v58_template_rows):
    raise SystemExit("v59e v58 return templates should be ready, no-fixture, approval-required")

v58_contract_map_rows = read_csv(run_dir / "v58_blind_eval_return_contract_map_rows.csv")
if len(v58_contract_map_rows) != 8:
    raise SystemExit("v59e should emit eight v58 return contract map rows")
if {row["artifact_id"] for row in v58_contract_map_rows} != expected_v58_artifacts:
    raise SystemExit("v59e v58 return contract map ids mismatch")
if any(
    row["fixture_allowed"] != "0"
    or row["approval_required"] != "1"
    or row["template_ready"] != "1"
    or row["status"] != "ready"
    or row["default_acceptance_status"] != "blocked"
    for row in v58_contract_map_rows
):
    raise SystemExit("v59e v58 return contract map should be ready, blocked by default, no-fixture, approval-required")
v58_template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in v58_template_rows}
for row in v58_contract_map_rows:
    template = v58_template_by_key.get((row["blocker_class"], row["artifact_id"]))
    if template is None:
        raise SystemExit("v59e v58 return contract map should resolve every template key")
    if (
        row["return_template_path"] != template["template_path"]
        or row["return_template_kind"] != template["template_kind"]
        or row["template_sha256"] != template["template_sha256"]
    ):
        raise SystemExit("v59e v58 return contract map should bind each artifact to its exact return template")
v58_acceptance_evidence_rows = read_csv(run_dir / "v58_blind_eval_acceptance_evidence_rows.csv")
if len(v58_acceptance_evidence_rows) != 8:
    raise SystemExit("v59e should emit eight v58 acceptance evidence rows")
if {row["artifact_id"] for row in v58_acceptance_evidence_rows} != expected_v58_artifacts:
    raise SystemExit("v59e v58 acceptance evidence artifact ids mismatch")
if any(
    row["claim_boundary_status"] != "pass"
    or row["output_artifact_replay_status"] != "pass"
    or row["blocker_false_positive_status"] != "pass"
    or row["contract_ready"] != "1"
    or row["default_acceptance_status"] != "blocked"
    or row["blind_eval_ready"] != "0"
    for row in v58_acceptance_evidence_rows
):
    raise SystemExit("v59e v58 acceptance evidence should be contract-ready but blind-eval blocked")
if any(
    row["tests_only_merge_condition"] != "0"
    or row["fixture_allowed"] != "0"
    or row["approval_required"] != "1"
    or row["undocumented_local_state_required"] != "0"
    or row["private_fixture_required"] != "0"
    or row["manual_postprocessing_required"] != "0"
    or row["network_required_by_default"] != "0"
    or row["downloads_required_by_default"] != "0"
    for row in v58_acceptance_evidence_rows
):
    raise SystemExit("v59e v58 acceptance evidence should forbid tests-only, fixtures, hidden state, network, and downloads")

preflight_rows = read_csv(run_dir / "pm_foundation_replay_preflight_rows.csv")
expected_preflight_checks = {
    "entrypoint-present",
    "generated-replay-script-present",
    "pinned-source-snapshot-replay",
    "no-live-download-default",
    "no-private-fixture",
    "no-manual-postprocessing",
    "no-undocumented-local-state",
    "local-abgh-row-contract-replay",
    "pm-pr-sidecar-packaged",
    "v58-required-return-artifacts-packaged",
    "blocker-false-positive-closed",
    "no-remote-mutation",
}
if {row["check"] for row in preflight_rows} != expected_preflight_checks:
    raise SystemExit("v59e replay preflight checks mismatch")
if any(row["status"] != "pass" for row in preflight_rows):
    raise SystemExit("v59e replay preflight should pass every default local check")
if not any(row["check"] == "local-abgh-row-contract-replay" and "row-contract checked" in row["claim_boundary"] for row in preflight_rows):
    raise SystemExit("v59e replay preflight should preserve local A/B/G/H row-contract boundary")
if not any(row["check"] == "no-live-download-default" and "approval-required" in row["claim_boundary"] for row in preflight_rows):
    raise SystemExit("v59e replay preflight should preserve download approval boundary")
if not any(row["check"] == "no-manual-postprocessing" and "written by the command" in row["evidence"] for row in preflight_rows):
    raise SystemExit("v59e replay preflight should reject manual post-processing dependency")

pr_summary = read_csv(pr_slice_summary_csv)[0]
if pr_summary.get("v1_0_pm_pr_claim_slice_gate_ready") != "1":
    raise SystemExit("v59e one-command should refresh the PM PR claim slice gate")
if pr_summary.get("recommended_pr_slice_rows") != "10" or pr_summary.get("merge_gate_rows") != "30":
    raise SystemExit("v59e one-command PR slice gate should expose ten slices and 30 merge gates")
if pr_summary.get("tests_only_merge_condition_rows") != "0":
    raise SystemExit("v59e one-command PR slice gate must keep tests-only merge conditions forbidden")
if pr_summary.get("real_release_package_ready") != "0":
    raise SystemExit("v59e one-command PR slice gate must keep release blocked")
if pr_summary.get("pm_pr_review_packet_files") != "10":
    raise SystemExit("v59e one-command PR slice gate should emit ten review packets")
if pr_summary.get("pm_blocker_closure_packet_files") != "6":
    raise SystemExit("v59e one-command PR slice gate should emit six blocker packets")
if pr_summary.get("pm_execution_lock_rows") != "10" or pr_summary.get("pm_scope_drift_allowed") != "0":
    raise SystemExit("v59e one-command PR slice gate should keep the PM execution lock active")
if pr_summary.get("pm_external_return_template_files") != "26" or pr_summary.get("pm_external_return_template_fixture_allowed_rows") != "0":
    raise SystemExit("v59e one-command PR slice gate should emit no-fixture return templates")

pr_slice_rows = read_csv(pr_slice_run_dir / "pm_pr_slice_rows.csv")
if len(pr_slice_rows) != 10:
    raise SystemExit("v59e one-command should emit ten PM PR slice rows")
v56_rows = [row for row in pr_slice_rows if row["slice_id"] == "v56-ruler-longbench-expanded"]
if len(v56_rows) != 1:
    raise SystemExit("v59e one-command PR slice gate should include v56")
if v56_rows[0]["current_status"] != "blocked-missing-replay-artifact":
    raise SystemExit("v59e one-command should keep v56 blocked when replay artifact is absent")
if v56_rows[0]["replay_artifact_ok"] != "0" or v56_rows[0]["blocker_false_positive_closed"] != "1":
    raise SystemExit("v59e one-command should expose v56 as replay-blocked, not false-positive-open")
PY

echo "v59e one-command PM foundation demo smoke passed"
