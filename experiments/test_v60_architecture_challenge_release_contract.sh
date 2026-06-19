#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v60_architecture_challenge_release_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_decision.csv"

"$ROOT_DIR/experiments/run_v60_architecture_challenge_release_contract.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v60 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v60_release_contract_ready": "1",
    "v60_ready": "0",
    "release_requirement_rows": "14",
    "release_requirement_ready_rows": "6",
    "release_requirement_blocked_rows": "8",
    "allowed_claim_rows": "3",
    "forbidden_claim_rows": "12",
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "source_snapshot_replay_used": "1",
    "public_source_snapshot_replay_rows": "10",
    "public_source_snapshot_replay_pass_rows": "10",
    "public_source_snapshot_replay_ready": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "pm_pr_claim_slice_bundle_ready": "1",
    "pm_scope_drift_allowed": "0",
    "pm_external_return_template_rows": "29",
    "one_command_replay_preflight_ready": "1",
    "v59_ready": "0",
    "required_30b_70b_baselines_ready": "0",
    "real_30b_70b_rows_ready": "0",
    "public_repo_query_scale_ready": "1",
    "v53_query_span_binding_audit_ready": "1",
    "v53_query_span_binding_audit_rows": "1000",
    "v53_query_span_binding_pass_rows": "1000",
    "pm_pr_v53_query_span_binding_audit_ready": "1",
    "v53_direct_pinned_manifest_ready": "1",
    "v53_direct_repo_manifest_rows": "10",
    "v53_direct_file_manifest_rows": "11266",
    "v53_direct_content_snapshot_rows": "11266",
    "v53_negative_abstain_rows": "160",
    "v53_unsupported_control_rows": "100",
    "v53_ambiguous_control_rows": "30",
    "v53_missing_specific_control_rows": "30",
    "v53_doc_code_conflict_rows": "140",
    "pm_pr_v53_direct_pinned_manifest_ready": "1",
    "pm_pr_v53_pm_acceptance_evidence_rows": "10",
    "pm_pr_v53_pm_acceptance_evidence_ready_rows": "10",
    "pm_pr_v53_pm_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_normalization_rows": "7",
    "pm_pr_normalization_split_required_rows": "7",
    "pm_pr_normalization_tests_only_rows": "0",
    "pm_pr_title_body_rows": "1",
    "pm_pr_title_body_rewrite_ready": "1",
    "pm_ready_semantic_rows": "7",
    "pm_ready_semantic_real_model_ready_rows": "0",
    "pm_ready_semantic_release_ready_rows": "0",
    "pm_ready_semantic_logical_100b_contract_fixture_ready": "1",
    "pm_ready_semantic_real_100b_inference_ready": "0",
    "pm_retrieval_leakage_guard_rows": "7",
    "pm_retrieval_leakage_guard_pass_rows": "7",
    "pm_retrieval_leakage_guard_blocked_rows": "0",
    "local_abgh_prebaseline_ready": "1",
    "local_abgh_prebaseline_ledger_ready": "1",
    "local_abgh_prebaseline_ledger_rows": "1000",
    "local_abgh_internal_contract_ready": "1",
    "local_abgh_internal_contract_rows": "4",
    "local_abgh_row_contract_replay_ready": "1",
    "local_abgh_row_contract_replay_rows": "2",
    "local_abgh_row_contract_replay_pass_rows": "2",
    "h10_real_label_promotion_ready": "0",
    "h10_source_verified_eval_ready": "0",
    "h10_external_human_label_evidence_ready": "0",
    "h10_pm_criteria_rows": "6",
    "h10_pm_criteria_ready": "1",
    "h10_pm_return_contract_rows": "6",
    "h10_pm_return_contract_ready": "1",
    "h10_pm_return_contract_fixture_allowed_rows": "0",
    "h10_pm_return_contract_approval_rows": "6",
    "h10_pm_return_contract_pass_rows": "0",
    "h10_pm_acceptance_evidence_rows": "6",
    "h10_pm_acceptance_evidence_ready": "1",
    "h10_pm_acceptance_evidence_promotion_ready_rows": "0",
    "h10_pm_acceptance_evidence_tests_only_rows": "0",
    "h10_accepted_query_rows_declared": "0",
    "h10_accepted_label_rows": "0",
    "h10_accepted_coherent_wrong_key_labels": "0",
    "h10_accepted_chunk_exact_labels": "0",
    "h10_accepted_near_miss_labels": "0",
    "h10_accepted_missing_query_labels": "0",
    "h10_accepted_source_provenance_labels": "0",
    "h10_pm_acceptance_evidence_coverage_field_rows": "6",
    "h10_pm_acceptance_evidence_zero_accepted_rows": "6",
    "h10_pm_acceptance_evidence_coverage_blocked_rows": "6",
    "h10_pm_acceptance_evidence_source_verified_blocked_rows": "6",
    "h10_pm_external_label_blocked": "1",
    "h10_pm_source_provenance_binding_ready": "1",
    "h10_pm_copied_files": "14",
    "pm_pr_v56_seed_dependency_blocker_ready": "1",
    "pm_pr_v56_seed_dependency_blocker_rows": "20",
    "pm_pr_v56_missing_seed_artifact_rows": "20",
    "pm_pr_v56_missing_v45_seed_artifact_rows": "11",
    "pm_pr_v56_missing_seed_network_or_download_approval_required": "1",
    "v54c_recommended_output_files_ready": "1",
    "v54c_recommended_output_file_rows": "9",
    "v54c_sha256sums_pm_recommended_csv_rows": "6",
    "v54c_sha256sums_pm_recommended_csv_ready": "1",
    "v54c_output_contract_ready": "1",
    "v54c_output_contract_rows": "9",
    "v54c_output_contract_pm_required_rows": "7",
    "v54c_output_contract_raw_prompt_forbidden_rows": "9",
    "routehint_generation_main_ready": "1",
    "scaling_law_main_ready": "0",
    "expanded_benchmark_ready": "0",
    "domain_expert_pack_ready": "0",
    "v58c_blind_response_intake_ready": "0",
    "v58c_intake_artifact_available": "0",
    "v58c_dependency_blocker_ready": "1",
    "v58d_blind_review_return_intake_ready": "0",
    "v58d_review_artifact_available": "0",
    "v58d_dependency_blocker_ready": "1",
    "v58d_human_blind_review_ready": "0",
    "v58d_inter_rater_rows_ready": "0",
    "v58d_pm_review_required_system_rows": "7",
    "v58d_pm_review_required_blind_response_rows": "3500",
    "v58d_pm_review_required_independent_review_rows": "7000",
    "v58d_pm_review_required_adjudication_rows": "3500",
    "v58d_pm_review_actual_ready": "0",
    "v58d_pm_review_missing_system_rows": "7",
    "v58d_pm_review_template_gap_rows": "7",
    "v58d_pm_review_unseen_split_ready": "0",
    "v58d_pm_review_source_span_exactness_ready": "0",
    "v58d_pm_review_unsupported_abstention_ready": "0",
    "v58d_pm_review_latency_memory_separate_ready": "0",
    "v58_return_artifact_contract_ready": "1",
    "v58_required_artifact_rows": "11",
    "v58_required_artifact_fixture_allowed_rows": "0",
    "v58_return_template_rows": "11",
    "v58_return_template_ready_rows": "11",
    "v58_return_template_fixture_allowed_rows": "0",
    "v58_return_contract_map_rows": "11",
    "v58_return_contract_map_ready_rows": "11",
    "v58_return_contract_map_default_blocked_rows": "11",
    "v58_acceptance_evidence_rows": "11",
    "v58_acceptance_evidence_contract_ready_rows": "11",
    "v58_acceptance_evidence_default_blocked_rows": "11",
    "v58_acceptance_evidence_blind_eval_ready_rows": "0",
    "v58_acceptance_evidence_tests_only_rows": "0",
    "v58_acceptance_evidence_hidden_state_rows": "0",
    "pm_pr_de_measured_registry_exclusion_rows": "2",
    "pm_pr_de_measured_registry_fixture_registry_rows": "0",
    "pm_pr_de_measured_registry_admission_ready_rows": "0",
    "pm_pr_de_measured_registry_blocked_rows": "2",
    "pm_pr_v58_real_execution_readiness_rows": "9",
    "pm_pr_v58_real_execution_ready_rows": "0",
    "pm_pr_v58_real_execution_blocked_rows": "9",
    "pm_pr_v58_real_execution_fixture_allowed_rows": "0",
    "pm_pr_v59_one_command_acceptance_evidence_rows": "2",
    "pm_pr_v59_one_command_acceptance_evidence_ready_rows": "1",
    "pm_pr_v59_one_command_acceptance_evidence_blocked_rows": "1",
    "pm_pr_v59_one_command_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows": "0",
    "pm_pr_v59_one_command_acceptance_evidence_approval_rows": "2",
    "blind_eval_ready": "0",
    "one_command_pm_foundation_ready": "1",
    "one_command_real_replay_ready": "0",
    "human_release_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v60 {field}: expected {value}, got {summary.get(field)}")
if summary.get("v59_one_command_challenge_demo_contract_ready") not in {"0", "1"}:
    raise SystemExit("v60 legacy v59 contract readiness should be explicit")
if summary.get("legacy_v59_contract_source_ready") not in {"0", "1"}:
    raise SystemExit("v60 legacy v59 source readiness should be explicit")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v60-release-contract",
    "v59e-pm-foundation-input",
    "pm-pr-claim-slice-input",
    "claim-boundary",
    "v53-foundation-freeze",
    "local-abgh-prebaseline",
    "v54-grounded-generation-1000",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v60 gate should pass: {gate}")
if decisions.get("v59-contract-input") not in {"pass", "blocked"}:
    raise SystemExit("v60 legacy v59 input gate should be explicit")
for gate in [
    "real-30b-70b-baselines",
    "h10-real-label-promotion",
    "v56-replay-artifact",
    "v58c-blind-response-intake",
    "v58-real-blind-eval",
    "full-v59-public-demo",
    "human-release-review",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v60 gate should remain blocked: {gate}")

required_files = [
    "release_requirement_rows.csv",
    "allowed_claim_rows.csv",
    "forbidden_claim_rows.csv",
    "release_decision_rows.csv",
    "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md",
    "v60_architecture_challenge_release_manifest.json",
    "sha256_manifest.csv",
    "legacy_v59_contract_source_rows.csv",
    "source_v59e/pm_foundation_stage_replay_rows.csv",
    "source_v59e/pm_foundation_one_command_rows.csv",
    "source_v59e/pm_foundation_replay_preflight_rows.csv",
    "source_v59e/local_abgh_row_contract_replay_rows.csv",
    "source_v59e/public_source_replay_policy_rows.csv",
    "source_v59e/public_source_snapshot_replay_rows.csv",
    "source_v59e/challenge_bundle_file_rows.csv",
    "source_v59e/pm_foundation_demo_gate_rows.csv",
    "source_v59e/README_RESULT.md",
    "source_v59e/V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md",
    "source_v59e/v59e_one_command_pm_foundation_demo_manifest.json",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v56/v56_seed_dependency_blocker_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/de_measured_registry_exclusion_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/v58_real_execution_readiness_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_closure_queue_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_normalization_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_title_body_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_ready_semantic_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_retrieval_leakage_guard_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_pm_acceptance_evidence_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_v1_exit_criteria_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v59e/source_v54c/answer_rows.csv",
    "source_v59e/source_v54c/citation_rows.csv",
    "source_v59e/source_v54c/unsupported_claim_rows.csv",
    "source_v59e/source_v54c/abstain_rows.csv",
    "source_v59e/source_v54c/generator_resource_rows.csv",
    "source_v59e/source_v54c/wrong_answer_guard_rows.csv",
    "source_v59e/source_v54c/grounded_generation_output_contract_rows.csv",
    "source_v59e/source_v54c/generator_input_rows.csv",
    "source_v59e/source_v54c/compact_routehint_rows.csv",
    "source_v59e/source_v54c/sha256sums.txt",
    "source_v59e/source_v54c/V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_query_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_span_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_answer_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_citation_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_evaluator_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_resource_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v59e/local_abgh_row_contract_replay_rows.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_summary.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_rows.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_summary.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_rows.csv",
    "source_v59e/v58_blind_eval_required_artifact_rows.csv",
    "source_v59e/v58_blind_eval_return_template_rows.csv",
    "source_v59e/v58_blind_eval_return_contract_map_rows.csv",
    "source_v59e/v58_blind_eval_acceptance_evidence_rows.csv",
    "source_v59e/v59e_one_command_pm_foundation_demo_summary.csv",
    "source_pm_pr/v1_0_pm_pr_claim_slice_gate_summary.csv",
    "source_summaries/v52_llm_rag_baseline_war_summary.csv",
    "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "source_summaries/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    "source_summaries/v10_h10_real_label_promotion_readiness_gate_summary.csv",
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_evidence_template.csv",
    "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv",
    "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
    "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60 artifact: {rel}")

acceptance_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_acceptance_evidence_rows.csv")
if len(acceptance_rows) != 10:
    raise SystemExit("v60 should carry ten PM PR acceptance evidence rows")
acceptance_by_id = {row["slice_id"]: row for row in acceptance_rows}
if sum(row["acceptance_ready"] == "1" for row in acceptance_rows) != 9:
    raise SystemExit("v60 should carry nine ready PM PR acceptance evidence rows")
if any(row["tests_only_merge_condition"] != "0" for row in acceptance_rows):
    raise SystemExit("v60 PM PR acceptance evidence should forbid tests-only merge conditions")
if acceptance_by_id["v53-query-instantiation-1000"]["replay_artifact_path"] != "source_v53t/complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("v60 v53 query acceptance should bind to query-span audit rows")
if acceptance_by_id["v53-system-a-b-g-h-measured"]["replay_artifact_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("v60 A/B/G/H acceptance should bind to local row-contract replay rows")
if acceptance_by_id["v59-one-command-demo"]["blocker_evidence_path"] != "source_v59e/public_source_replay_policy_rows.csv":
    raise SystemExit("v60 v59 acceptance should bind to public source replay policy rows")
normalization_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_normalization_rows.csv")
if len(normalization_rows) != 7:
    raise SystemExit("v60 should carry seven PM PR normalization rows")
if any(row["tests_only_merge_condition"] != "0" or row["pr2_merge_as_is_recommended"] != "0" for row in normalization_rows):
    raise SystemExit("v60 PM PR normalization rows should reject tests-only/as-is merge")
title_body_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_title_body_rows.csv")
if len(title_body_rows) != 1 or title_body_rows[0]["split_required"] != "1" or title_body_rows[0]["release_ready"] != "0":
    raise SystemExit("v60 should carry PR #2 title/body split requirement")
ready_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/pm_ready_semantic_rows.csv")
if len(ready_rows) != 7:
    raise SystemExit("v60 should carry typed ready semantic rows")
if any(row["real_model_execution_ready"] != "0" or row["release_ready"] != "0" for row in ready_rows):
    raise SystemExit("v60 ready semantic rows should keep real model and release readiness closed")
leakage_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/pm_retrieval_leakage_guard_rows.csv")
if len(leakage_rows) != 7:
    raise SystemExit("v60 should carry retrieval leakage guard rows")
if any(row["status"] != "pass" or row["adapter_selection_blocked"] != "1" for row in leakage_rows):
    raise SystemExit("v60 retrieval leakage rows should keep oracle metadata blocked from adapter selection")
v56_replay_acceptance_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv")
if len(v56_replay_acceptance_rows) != 4:
    raise SystemExit("v60 should carry four v56 replay acceptance evidence rows through v59e/PM sidecar")
v56_replay_artifacts = {row["artifact_id"]: row for row in v56_replay_acceptance_rows}
for artifact_id in ["v56-contract-summary", "v56-contract-artifacts", "v56b-scale-summary", "v56b-scale-artifacts"]:
    row = v56_replay_artifacts.get(artifact_id)
    if not row:
        raise SystemExit(f"v60 missing v56 replay artifact row: {artifact_id}")
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v60 should preserve v56 claim/blocker boundaries: {artifact_id}")
    if row["acceptance_ready"] != "0" or row["acceptance_status"] != "blocked":
        raise SystemExit(f"v60 should keep v56 replay artifact blocked without replay evidence: {artifact_id}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v60 should require approval and forbid fixtures for v56 replay evidence: {artifact_id}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v60 should forbid tests-only v56 replay acceptance: {artifact_id}")
if "V56B_ALLOW_CONTRACT_REBUILD=1" not in v56_replay_artifacts["v56b-scale-artifacts"]["validation_command"]:
    raise SystemExit("v60 should preserve the approval-gated v56b validation command")
de_acceptance_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv")
if len(de_acceptance_rows) != 4:
    raise SystemExit("v60 should carry four D/E 30B/70B acceptance evidence rows through v59e/PM sidecar")
de_artifacts = {row["artifact_id"]: row for row in de_acceptance_rows}
for artifact_id, system_id in {
    "d-model-identity": "D",
    "d-answer-citation-resource": "D",
    "e-model-identity": "E",
    "e-answer-citation-resource": "E",
}.items():
    row = de_artifacts.get(artifact_id)
    if not row:
        raise SystemExit(f"v60 missing D/E acceptance artifact row: {artifact_id}")
    if row["system_id"] != system_id:
        raise SystemExit(f"v60 D/E system mismatch: {artifact_id}")
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v60 should preserve D/E claim/blocker boundaries: {artifact_id}")
    if row["acceptance_ready"] != "0" or row["acceptance_status"] != "blocked":
        raise SystemExit(f"v60 should keep D/E evidence blocked without real baseline rows: {artifact_id}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v60 should require approval and forbid fixtures for D/E evidence: {artifact_id}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v60 should forbid tests-only D/E acceptance: {artifact_id}")
if "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR>" not in de_artifacts["d-model-identity"]["validation_command"]:
    raise SystemExit("v60 should preserve the approval-gated D/E validation command")

v59_one_command_acceptance_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv")
if len(v59_one_command_acceptance_rows) != 2:
    raise SystemExit("v60 should carry two PM v59 one-command acceptance evidence rows through v59e/PM sidecar")
v59_one_command_artifacts = {row["artifact_id"]: row for row in v59_one_command_acceptance_rows}
local_abgh_row = v59_one_command_artifacts.get("v59e-local-abgh-row-contract-replay")
if not local_abgh_row:
    raise SystemExit("v60 missing v59 local A/B/G/H row-contract replay acceptance row")
if local_abgh_row["acceptance_ready"] != "1" or local_abgh_row["acceptance_status"] != "ready":
    raise SystemExit("v60 should preserve v59 local A/B/G/H row-contract replay readiness")
if local_abgh_row["output_artifact_replay_status"] != "pass":
    raise SystemExit("v60 should preserve passing v59 local A/B/G/H replay status")
refresh_row = v59_one_command_artifacts.get("v59-public-source-download-refresh")
if not refresh_row:
    raise SystemExit("v60 missing v59 public-source download/refresh acceptance row")
if refresh_row["acceptance_ready"] != "0" or refresh_row["acceptance_status"] != "blocked":
    raise SystemExit("v60 should keep v59 public-source download/refresh blocked without approval/evidence")
if refresh_row["output_artifact_replay_status"] != "blocked":
    raise SystemExit("v60 should preserve blocked v59 public-source replay status")
for row in v59_one_command_acceptance_rows:
    if row["claim_boundary_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v60 should preserve v59 claim/blocker boundaries: {row['artifact_id']}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v60 should require approval and forbid fixtures for v59 evidence: {row['artifact_id']}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v60 should forbid tests-only v59 acceptance: {row['artifact_id']}")
if "full_public_source_download_ready=0" not in refresh_row["observed_signal"]:
    raise SystemExit("v60 should expose blocked full public-source download readiness for v59 refresh")

de_measured_registry_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/de_measured_registry_exclusion_rows.csv")
if len(de_measured_registry_rows) != 2:
    raise SystemExit("v60 should carry two D/E measured registry exclusion rows through v59e/PM sidecar")
de_measured_registry_by_system = {row["system_id"]: row for row in de_measured_registry_rows}
if set(de_measured_registry_by_system) != {"D", "E"}:
    raise SystemExit("v60 D/E measured registry exclusion rows should cover D and E")
for system_id, row in de_measured_registry_by_system.items():
    if row["fixture_rows_in_measured_registry"] != "0":
        raise SystemExit(f"v60 D/E measured registry should keep fixture {system_id} rows out of measured registry")
    if row["measured_registry_admission_ready"] != "0":
        raise SystemExit(f"v60 D/E measured registry should keep {system_id} admission blocked without real evidence")
    if row["status"] != "blocked":
        raise SystemExit(f"v60 D/E measured registry should keep {system_id} status blocked")
    if row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v60 D/E measured registry should forbid fixtures and tests-only for {system_id}")
    if row["raw_answer_citation_output_required"] != "1" or row["answer_citation_raw_output_rows"] != "0":
        raise SystemExit(f"v60 D/E measured registry should still require raw answer/citation output for {system_id}")
    if row["resource_row_required"] != "1" or row["evaluator_version_required"] != "1" or row["same_query_set_required"] != "1":
        raise SystemExit(f"v60 D/E measured registry should preserve model/runtime/resource requirements for {system_id}")
    if "answer_citation_raw_output" not in row["missing_real_evidence_fields"]:
        raise SystemExit(f"v60 D/E measured registry should record missing raw answer/citation evidence for {system_id}")
    if "model_repository_exact_revision" not in row["required_real_evidence_fields"] or "runtime" not in row["required_real_evidence_fields"]:
        raise SystemExit(f"v60 D/E measured registry should preserve model and runtime evidence requirements for {system_id}")

v58_real_execution_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/v58_real_execution_readiness_rows.csv")
if len(v58_real_execution_rows) != 9:
    raise SystemExit("v60 should carry nine v58 real execution readiness rows through v59e/PM sidecar")
v58_real_execution_by_id = {row["requirement_id"]: row for row in v58_real_execution_rows}
expected_v58_real_execution_ids = {
    "ab-cdegh-real-responses",
    "same-corpus-context-budget",
    "blind-identity",
    "two-independent-reviewers",
    "disagreement-adjudication",
    "unseen-repository-split",
    "source-span-exactness",
    "unsupported-abstention",
    "latency-memory-separate",
}
if set(v58_real_execution_by_id) != expected_v58_real_execution_ids:
    raise SystemExit("v60 v58 real execution readiness requirement ids mismatch")
ab_response_row = v58_real_execution_by_id.get("ab-cdegh-real-responses", {})
if "A/B/C/D/E/G/H" not in ab_response_row.get("required_evidence", ""):
    raise SystemExit("v60 v58 real execution should require A/B/C/D/E/G/H actual blind responses")
for requirement_id, row in v58_real_execution_by_id.items():
    if row["required_for_v58_real_execution"] != "1":
        raise SystemExit(f"v60 v58 real execution row should be required: {requirement_id}")
    if row["contract_ready"] != "1":
        raise SystemExit(f"v60 v58 real execution row should be contract-ready: {requirement_id}")
    if row["real_execution_ready"] != "0":
        raise SystemExit(f"v60 v58 real execution should remain not ready: {requirement_id}")
    if row["status"] != "blocked":
        raise SystemExit(f"v60 v58 real execution should remain blocked: {requirement_id}")
    if row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v60 v58 real execution should forbid fixtures and tests-only merge: {requirement_id}")

v60_pm_v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(v60_pm_v53t_real_adapter_rows) != 4:
    raise SystemExit("v60 should carry four v53t real-adapter freeze rows through v59e/PM sidecar")
if v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["status"] != "pass":
    raise SystemExit("v60 should carry passing v53t real-adapter execution evidence")
if "coherent_wrong_key_rows=3916" not in v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in v60_pm_v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq public comparison blocker")

v60_pm_v53_acceptance_rows = {
    row["requirement_id"]: row
    for row in read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_pm_acceptance_evidence_rows.csv")
}
if len(v60_pm_v53_acceptance_rows) != 10:
    raise SystemExit("v60 should carry ten v53 PM acceptance evidence rows")
if any(row["acceptance_ready"] != "1" or row["tests_only_merge_condition"] != "0" for row in v60_pm_v53_acceptance_rows.values()):
    raise SystemExit("v60 v53 PM acceptance evidence should be ready and not tests-only")
for requirement_id, snippet in {
    "source-span-query-freeze": "binding_audit_pass_rows=1000",
    "answer-citation-separated-evaluator": "separate_evaluator_rows=4000",
    "abgh-same-query-deterministic-prebaseline": "real_system_performance_claim_ready=0",
    "abgh-real-adapter-same-query-internal": "public_comparison_claim_ready=0",
    "public-comparison-boundary-closed": "required_30b_baseline_ready=0",
}.items():
    if snippet not in v60_pm_v53_acceptance_rows[requirement_id]["actual_value"]:
        raise SystemExit(f"v60 v53 PM acceptance row should expose {snippet}: {requirement_id}")

repo_coverage_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
file_manifest_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
content_repo_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv")
content_snapshot_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")
binding_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv")
abgh_prebaseline_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
local_abgh_contract_rows = {
    row["source_stage"]: row
    for row in read_csv(run_dir / "source_v59e/local_abgh_row_contract_replay_rows.csv")
}
if len(repo_coverage_rows) != 10 or len(content_repo_rows) != 10:
    raise SystemExit("v60 should carry direct 10-repo manifest rows through v59e/PM sidecar")
if len(file_manifest_rows) != 11266 or len(content_snapshot_rows) != 11266:
    raise SystemExit("v60 should carry direct file/content manifest rows through v59e/PM sidecar")
if len(binding_rows) != 1000 or any(row["binding_status"] != "pass" for row in binding_rows):
    raise SystemExit("v60 should carry 1000 passing query-span binding audit rows through v59e/PM sidecar")
if len(abgh_prebaseline_rows) != 1000:
    raise SystemExit("v60 should carry 1000 A/B/G/H same-query internal pre-baseline ledger rows through v59e/PM sidecar")
if any(row["same_evaluator_contract"] != "1" or row["same_resource_bound"] != "1" or row["public_comparison_claim_ready"] != "0" for row in abgh_prebaseline_rows):
    raise SystemExit("v60 A/B/G/H internal pre-baseline ledger should preserve evaluator/resource and public-comparison boundary")
abgh_internal_contract_rows = read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53aq/abgh_internal_prebaseline_contract_rows.csv")
if len(abgh_internal_contract_rows) != 4:
    raise SystemExit("v60 should carry 4 A/B/G/H internal pre-baseline per-system contract rows through v59e/PM sidecar")
if {row["system_id"] for row in abgh_internal_contract_rows} != {"A", "B", "G", "H"}:
    raise SystemExit("v60 A/B/G/H internal pre-baseline contract rows should cover A/B/G/H")
if any(row["contract_ready"] != "1" for row in abgh_internal_contract_rows):
    raise SystemExit("v60 A/B/G/H internal pre-baseline per-system contract rows should all be ready")
if any(row["public_comparison_claim_ready"] != "0" for row in abgh_internal_contract_rows):
    raise SystemExit("v60 A/B/G/H internal pre-baseline contract rows should keep public comparison blocked")
if any(
    row["same_query_set"] != "1"
    or row["same_evaluator_contract"] != "1"
    or row["same_resource_contract"] != "1"
    or row["selection_question_text_only"] != "1"
    or row["selection_oracle_field_used"] != "0"
    or row["expected_answer_oracle_replay_rows"] != "0"
    or row["deterministic_source_span_adapter_rows"] != "0"
    or row["internal_real_adapter_metric_claim_ready"] != "1"
    or row["public_real_system_performance_claim_ready"] != "0"
    or row["required_30b_baseline_ready"] != "0"
    or row["required_70b_baseline_ready"] != "0"
    for row in abgh_internal_contract_rows
):
    raise SystemExit("v60 A/B/G/H internal pre-baseline contract rows should preserve no-oracle/internal-only boundaries")
if set(local_abgh_contract_rows) != {"v53ap", "v53aq"}:
    raise SystemExit("v60 should carry v59e local A/B/G/H row-contract replay rows for v53ap and v53aq")
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
        or row["answer_eval_separate_rows"] != "4000"
        or row["citation_eval_separate_rows"] != "4000"
        or row["resource_eval_separate_rows"] != "4000"
        or row["expected_answer_oracle_replay_any"] != "0"
        or row["no_external_model_rows"] != "4000"
        or row["no_external_network_rows"] != "4000"
        or row["public_comparison_claim_ready"] != "0"
    ):
        raise SystemExit(f"v60 should preserve passing v59e {stage} local A/B/G/H row-contract replay")
if (
    local_abgh_contract_rows["v53ap"]["deterministic_source_span_adapter_execution_rows"] != "4000"
    or local_abgh_contract_rows["v53ap"]["real_adapter_execution_ready_rows"] != "0"
    or local_abgh_contract_rows["v53ap"]["real_system_performance_claim_ready_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["deterministic_source_span_adapter_execution_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["real_adapter_execution_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["real_system_performance_claim_ready_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["internal_real_adapter_metric_claim_ready_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["public_real_system_performance_claim_ready_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["selection_question_text_only_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["selection_oracle_field_used_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["same_query_internal_prebaseline_rows"] != "1000"
    or local_abgh_contract_rows["v53aq"]["internal_prebaseline_contract_rows"] != "4"
    or local_abgh_contract_rows["v53aq"]["internal_prebaseline_contract_ready"] != "1"
):
    raise SystemExit("v60 should preserve v53ap deterministic and v53aq real-adapter row-contract boundaries")
if any(row["complete_source_tree_manifest_ready"] != "1" for row in repo_coverage_rows):
    raise SystemExit("v60 repo coverage rows should preserve ready tree manifests")
if any(row["content_snapshot_ready"] != "1" for row in content_repo_rows):
    raise SystemExit("v60 content repo rows should preserve ready content snapshots")

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
    rows = read_csv(run_dir / "source_v59e/source_v54c" / filename)
    if len(rows) != expected_count:
        raise SystemExit(f"v60 should carry {expected_count} v54c rows for {filename}, got {len(rows)}")
v54c_generator_inputs = read_csv(run_dir / "source_v59e/source_v54c/generator_input_rows.csv")
if len(v54c_generator_inputs) != 1000:
    raise SystemExit("v60 should carry 1000 v54c generator input rows")
if any(row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" for row in v54c_generator_inputs):
    raise SystemExit("v60 v54c generator inputs should preserve no raw prompt stuffing")
if any(
    row["model_visible_input_fields"] != "sanitized_question,opaque_routehint"
    or row["model_visible_query_id_used"] != "0"
    or row["model_visible_source_span_id_used"] != "0"
    or row["model_visible_source_path_used"] != "0"
    or row["model_visible_source_line_used"] != "0"
    or row["model_visible_source_file_hash_used"] != "0"
    or row["model_visible_expected_behavior_used"] != "0"
    or row["model_visible_expected_label_used"] != "0"
    or row["compact_routehint_contains_source_locator"] != "0"
    or row["deterministic_source_span_generation_fixture"] != "1"
    or row["real_model_generation_ready"] != "0"
    for row in v54c_generator_inputs
):
    raise SystemExit("v60 v54c generator inputs should preserve sanitized model-visible leakage guard")
v54c_contracts = read_csv(run_dir / "source_v59e/source_v54c/grounded_generation_output_contract_rows.csv")
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
    raise SystemExit("v60 should carry the full v54c grounded-generation output contract")
if sum(row["pm_recommended_output"] == "1" for row in v54c_contracts) != 7:
    raise SystemExit("v60 v54c contract should preserve seven PM recommended artifacts")
for artifact_id, (artifact_path, expected_count) in v54c_contract_counts.items():
    row = v54c_contract_by_id[artifact_id]
    if row["artifact_path"] != artifact_path:
        raise SystemExit(f"v60 v54c contract path mismatch for {artifact_id}")
    if row["expected_row_count"] != str(expected_count) or row["observed_row_count"] != str(expected_count):
        raise SystemExit(f"v60 v54c contract row count mismatch for {artifact_id}")
    if row["artifact_sha256"] != sha256(run_dir / "source_v59e/source_v54c" / artifact_path) or row["sha256_bound"] != "1":
        raise SystemExit(f"v60 v54c contract sha256 binding mismatch for {artifact_id}")
    if row["raw_prompt_context_appended_allowed"] != "0" or row["raw_prompt_context_appended_rows"] != "0":
        raise SystemExit(f"v60 v54c contract should forbid raw prompt context for {artifact_id}")
    if row["model_visible_leakage_guard_ready"] != "1" or row["model_visible_forbidden_field_used_rows"] != "0" or row["model_visible_source_locator_rows"] != "0":
        raise SystemExit(f"v60 v54c contract should preserve model-visible leakage guard for {artifact_id}")
    if row["source_span_bound"] != "1" or row["v53ap_provenance_bound"] != "1" or row["wrong_answer_guarded"] != "1":
        raise SystemExit(f"v60 v54c contract should preserve provenance and guard binding for {artifact_id}")
sha_contract = v54c_contract_by_id["sha256sums"]
if (
    sha_contract["artifact_path"] != "sha256sums.txt"
    or sha_contract["expected_row_count"] != "not-csv"
    or sha_contract["observed_row_count"] != "written-after-contract"
    or sha_contract["sha256_bound"] != "0"
    or sha_contract["raw_prompt_context_appended_rows"] != "0"
    or sha_contract["model_visible_leakage_guard_ready"] != "1"
    or sha_contract["model_visible_forbidden_field_used_rows"] != "0"
    or sha_contract["model_visible_source_locator_rows"] != "0"
):
    raise SystemExit("v60 v54c sha256sums contract should preserve its post-contract boundary")

requirements = read_csv(run_dir / "release_requirement_rows.csv")
if len(requirements) != 14:
    raise SystemExit("v60 should list fourteen release requirements")
ready_reqs = {row["requirement"] for row in requirements if row["ready"] == "1" and row["status"] == "pass"}
expected_ready = {
    "v52_baseline_registry_contract",
    "v53_public_repo_source_bound_1000_corpus",
    "v53_abgh_same_query_internal_prebaseline",
    "v54_grounded_generation_1000",
    "v59_pm_foundation_one_command_bundle",
    "pm_pr_claim_slice_gate_and_execution_lock",
}
if ready_reqs != expected_ready:
    raise SystemExit(f"v60 ready requirements mismatch: {ready_reqs}")
blocked_reqs = {row["requirement"] for row in requirements if row["ready"] == "0" and row["status"] == "blocked"}
for requirement in [
    "required_30b_70b_symmetric_baselines",
    "h10_real_label_source_verified_scorer",
    "v56_expanded_ruler_longbench_replay_artifact",
    "v58c_blind_response_intake_artifact",
    "v58_real_blind_eval",
    "full_v59_public_demo_real_replay",
    "human_release_review",
    "release_artifact_package",
]:
    if requirement not in blocked_reqs:
        raise SystemExit(f"v60 requirement should remain blocked: {requirement}")
for row in requirements:
    evidence_path = run_dir / row["evidence_path"]
    if not evidence_path.is_file() or evidence_path.stat().st_size == 0:
        raise SystemExit(f"v60 requirement evidence path is not replayable: {row['requirement']} -> {row['evidence_path']}")
v53_req = next(row for row in requirements if row["requirement"] == "v53_public_repo_source_bound_1000_corpus")
if v53_req["evidence_path"] != "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("v60 v53 requirement should point directly at copied query-span binding audit rows")
h10_req = next(row for row in requirements if row["requirement"] == "h10_real_label_source_verified_scorer")
abgh_req = next(row for row in requirements if row["requirement"] == "v53_abgh_same_query_internal_prebaseline")
if abgh_req["evidence_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("v60 A/B/G/H pre-baseline requirement should point directly at copied row-contract replay rows")
if h10_req["evidence_path"] != "source_h10_pm/pm_h10_real_label_acceptance_rows.csv":
    raise SystemExit("v60 h10 requirement should point directly at PM h10 criteria rows")
v58_req = next(row for row in requirements if row["requirement"] == "v58_real_blind_eval")
if v58_req["evidence_path"] != "source_v59e/v58_blind_eval_required_artifact_rows.csv":
    raise SystemExit("v60 v58 real blind-eval requirement should point directly at v58 required artifact rows")
h10_rows = read_csv(run_dir / h10_req["evidence_path"])
expected_h10_criteria = {
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
}
if {row["criterion"] for row in h10_rows} != expected_h10_criteria:
    raise SystemExit("v60 h10 PM criteria rows should cover all six PM scorer criteria")
h10_by_criterion = {row["criterion"]: row for row in h10_rows}
if h10_by_criterion["source-provenance-binding"]["machine_evidence_status"] != "pass":
    raise SystemExit("v60 h10 source provenance criterion should carry pass machine evidence")
if "v53ap_evaluator_rows=4000" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53ap evaluator rows")
if "v53aq_same_query_internal_prebaseline_rows=1000" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53aq same-query prebaseline rows")
if "v53aq_same_query_internal_prebaseline_rows_ready=1" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53aq same-query prebaseline readiness")
if "v53aq_internal_prebaseline_contract_rows=4" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53aq internal prebaseline contract rows")
if "v53aq_internal_prebaseline_contract_ready=1" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53aq internal prebaseline contract readiness")
if "v53t_real_adapter_freeze_rows=4" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53t real-adapter freeze rows")
if h10_by_criterion["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("v60 h10 external/human label criterion should remain blocked")
h10_return_contract_rows = read_csv(run_dir / "source_h10_pm/h10_real_label_return_contract_rows.csv")
if len(h10_return_contract_rows) != 6:
    raise SystemExit("v60 h10 return contract should cover six PM scorer criteria")
h10_return_contract_by_criterion = {row["criterion"]: row for row in h10_return_contract_rows}
if set(h10_return_contract_by_criterion) != expected_h10_criteria:
    raise SystemExit("v60 h10 return contract criteria mismatch")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in h10_return_contract_rows):
    raise SystemExit("v60 h10 return contract should preserve no-fixture approval-required boundaries")
if any(row["contract_ready"] != "1" or row["acceptance_status"] != "blocked" for row in h10_return_contract_rows):
    raise SystemExit("v60 h10 return contract should remain ready but blocked without accepted labels")
if h10_return_contract_by_criterion["source-provenance-binding"]["evidence_column"] != "source_provenance_labels":
    raise SystemExit("v60 h10 return contract should bind source provenance labels")
if "query_rows>=1000" not in h10_return_contract_by_criterion["external-human-label-evidence"]["external_label_dependency"]:
    raise SystemExit("v60 h10 return contract should require 1000 query rows for external/human labels")
h10_acceptance_evidence_rows = read_csv(run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv")
if len(h10_acceptance_evidence_rows) != 6:
    raise SystemExit("v60 h10 acceptance evidence should cover six PM scorer criteria")
h10_acceptance_evidence_by_criterion = {row["criterion"]: row for row in h10_acceptance_evidence_rows}
if set(h10_acceptance_evidence_by_criterion) != expected_h10_criteria:
    raise SystemExit("v60 h10 acceptance evidence criteria mismatch")
if any(row["claim_boundary_status"] != "pass" for row in h10_acceptance_evidence_rows):
    raise SystemExit("v60 h10 acceptance evidence should preserve claim-boundary pass status")
if any(row["output_artifact_replay_status"] != "pass" for row in h10_acceptance_evidence_rows):
    raise SystemExit("v60 h10 acceptance evidence should preserve replay pass status")
if any(row["blocker_false_positive_status"] != "pass" for row in h10_acceptance_evidence_rows):
    raise SystemExit("v60 h10 acceptance evidence should preserve blocker false-positive closure")
if any(row["acceptance_ready"] != "1" or row["promotion_ready"] != "0" for row in h10_acceptance_evidence_rows):
    raise SystemExit("v60 h10 acceptance evidence should remain contract-ready but promotion-blocked")
if any(row["tests_only_merge_condition"] != "0" or row["fixture_allowed"] != "0" for row in h10_acceptance_evidence_rows):
    raise SystemExit("v60 h10 acceptance evidence should reject tests-only and fixture promotion")
for criterion, row in h10_acceptance_evidence_by_criterion.items():
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
            raise SystemExit(f"v60 h10 acceptance evidence missing {field} for {criterion}")
    if row["accepted_real_label_evidence_rows"] != "0":
        raise SystemExit(f"v60 h10 acceptance evidence should record zero accepted real-label rows for {criterion}")
    if row["accepted_query_rows_declared"] != "0" or row["accepted_label_rows"] != "0":
        raise SystemExit(f"v60 h10 acceptance evidence should record zero accepted query/label rows for {criterion}")
    if row["accepted_criterion_label_count"] != "0":
        raise SystemExit(f"v60 h10 acceptance evidence should keep criterion label coverage at zero for {criterion}")
    if row["criterion_label_coverage_status"] != "blocked":
        raise SystemExit(f"v60 h10 acceptance evidence should keep criterion label coverage blocked for {criterion}")
    if row["source_verified_eval_status"] != "blocked":
        raise SystemExit(f"v60 h10 acceptance evidence should keep source-verified eval blocked for {criterion}")

public_source_snapshot_rows = read_csv(run_dir / "source_v59e/public_source_snapshot_replay_rows.csv")
if len(public_source_snapshot_rows) != 10:
    raise SystemExit("v60 should carry ten v59e public source snapshot replay rows")
if len({row["owner_repo"] for row in public_source_snapshot_rows}) != 10:
    raise SystemExit("v60 public source snapshot replay rows should cover ten distinct repositories")
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
    for row in public_source_snapshot_rows
):
    raise SystemExit("v60 should preserve v59e pinned no-download public source snapshot replay evidence")

v58_required_rows = read_csv(run_dir / "source_v59e/v58_blind_eval_required_artifact_rows.csv")
if len(v58_required_rows) != 11:
    raise SystemExit("v60 should carry eleven v58 required artifact rows")
v58_required_by_blocker = {}
for row in v58_required_rows:
    v58_required_by_blocker.setdefault(row["blocker_class"], []).append(row)
if len(v58_required_by_blocker.get("v58c-intake-artifact-missing", [])) != 3:
    raise SystemExit("v60 v58 required artifact rows should include three v58c intake artifacts")
if len(v58_required_by_blocker.get("v58-real-blind-eval-missing", [])) != 8:
    raise SystemExit("v60 v58 required artifact rows should include eight real blind-eval artifacts")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in v58_required_rows):
    raise SystemExit("v60 v58 required artifact rows should forbid fixtures and require approval")
expected_v58_artifacts = {
    "v58c-intake-summary",
    "v58c-intake-artifacts",
    "v58c-source-v58b-freeze",
    "v58-blind-response-rows",
    "v58-run-identity-rows",
    "v58-query-split-rows",
    "v58-resource-rows",
    "v58-human-review-rows",
    "v58-adjudication-rows",
    "v58d-review-return-intake",
    "v58-sha256-manifest",
}
if {row["artifact_id"] for row in v58_required_rows} != expected_v58_artifacts:
    raise SystemExit("v60 v58 required artifact ids mismatch")

v58_template_rows = read_csv(run_dir / "source_v59e/v58_blind_eval_return_template_rows.csv")
if len(v58_template_rows) != 11:
    raise SystemExit("v60 should carry eleven v58 return template rows")
if {row["artifact_id"] for row in v58_template_rows} != expected_v58_artifacts:
    raise SystemExit("v60 v58 return template ids mismatch")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" or row["template_ready"] != "1" for row in v58_template_rows):
    raise SystemExit("v60 v58 return templates should be ready, no-fixture, approval-required")

v58_contract_map_rows = read_csv(run_dir / "source_v59e/v58_blind_eval_return_contract_map_rows.csv")
if len(v58_contract_map_rows) != 11:
    raise SystemExit("v60 should carry eleven v58 return contract map rows")
if {row["artifact_id"] for row in v58_contract_map_rows} != expected_v58_artifacts:
    raise SystemExit("v60 v58 return contract map ids mismatch")
if any(
    row["fixture_allowed"] != "0"
    or row["approval_required"] != "1"
    or row["template_ready"] != "1"
    or row["status"] != "ready"
    or row["default_acceptance_status"] != "blocked"
    for row in v58_contract_map_rows
):
    raise SystemExit("v60 v58 return contract map should be ready, blocked by default, no-fixture, approval-required")
v58_template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in v58_template_rows}
for row in v58_contract_map_rows:
    template = v58_template_by_key.get((row["blocker_class"], row["artifact_id"]))
    if template is None:
        raise SystemExit("v60 v58 return contract map should resolve every template key")
    if (
        row["return_template_path"] != template["template_path"]
        or row["return_template_kind"] != template["template_kind"]
        or row["template_sha256"] != template["template_sha256"]
    ):
        raise SystemExit("v60 v58 return contract map should bind each artifact to its exact return template")
v58_acceptance_evidence_rows = read_csv(run_dir / "source_v59e/v58_blind_eval_acceptance_evidence_rows.csv")
if len(v58_acceptance_evidence_rows) != 11:
    raise SystemExit("v60 should carry eleven v58 acceptance evidence rows")
if {row["artifact_id"] for row in v58_acceptance_evidence_rows} != expected_v58_artifacts:
    raise SystemExit("v60 v58 acceptance evidence artifact ids mismatch")
if any(
    row["claim_boundary_status"] != "pass"
    or row["output_artifact_replay_status"] != "pass"
    or row["blocker_false_positive_status"] != "pass"
    or row["contract_ready"] != "1"
    or row["default_acceptance_status"] != "blocked"
    or row["blind_eval_ready"] != "0"
    for row in v58_acceptance_evidence_rows
):
    raise SystemExit("v60 v58 acceptance evidence should be contract-ready but blind-eval blocked")
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
    raise SystemExit("v60 v58 acceptance evidence should forbid tests-only, fixtures, hidden state, network, and downloads")

for label, path in [
    ("v59e direct h10 bundle", run_dir / "source_v59e/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
    ("v59e PM sidecar h10 bundle", run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
    ("v60 direct h10 bundle", run_dir / "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
]:
    rows = read_csv(path)
    if len(rows) != 1000:
        raise SystemExit(f"v60 {label} should carry 1000 v53aq same-query prebaseline rows")
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
        raise SystemExit(f"v60 {label} should preserve v53aq same-query/no-oracle/no-public-claim boundary")

for label, path in [
    ("v59e direct h10 bundle", run_dir / "source_v59e/source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv"),
    ("v59e PM sidecar h10 bundle", run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv"),
    ("v60 direct h10 bundle", run_dir / "source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv"),
]:
    rows = {row["system_id"]: row for row in read_csv(path)}
    if set(rows) != {"A", "B", "G", "H"}:
        raise SystemExit(f"v60 {label} should carry four v53aq internal prebaseline contract rows")
    for system_id, row in rows.items():
        if (
            row["same_query_set"] != "1"
            or row["same_evaluator_contract"] != "1"
            or row["same_resource_contract"] != "1"
            or row["selection_question_text_only"] != "1"
            or row["selection_oracle_field_used"] != "0"
            or row["expected_answer_oracle_replay_rows"] != "0"
            or row["deterministic_source_span_adapter_rows"] != "0"
            or row["internal_real_adapter_metric_claim_ready"] != "1"
            or row["public_real_system_performance_claim_ready"] != "0"
            or row["public_comparison_claim_ready"] != "0"
            or row["required_30b_baseline_ready"] != "0"
            or row["required_70b_baseline_ready"] != "0"
            or row["contract_ready"] != "1"
        ):
            raise SystemExit(f"v60 {label} contract should preserve internal-only boundary for {system_id}")

allowed = read_csv(run_dir / "allowed_claim_rows.csv")
for claim in ["architecture-challenge-contract-scaffold", "pm-foundation-replay-bundle", "local-architecture-preview"]:
    if claim not in {row["claim_id"] for row in allowed}:
        raise SystemExit(f"v60 allowed claim missing {claim}")

forbidden = {row["claim_id"] for row in read_csv(run_dir / "forbidden_claim_rows.csv")}
for claim in [
    "v1_0_release_ready",
    "beats_30b_150b_llm_rag",
    "public_comparison_win",
    "public_real_system_performance_claim",
    "h10_scientific_contribution_claim",
    "v59_public_demo_complete",
    "transformer_replacement",
    "frontier_local_llm_equivalence",
    "long_context_solved",
    "gpu_or_hip_acceleration",
    "expert_replacement",
    "production_release",
]:
    if claim not in forbidden:
        raise SystemExit(f"v60 forbidden claim missing {claim}")

manifest = json.loads((run_dir / "v60_architecture_challenge_release_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v60_release_contract_ready") != 1 or manifest.get("v60_ready") != 0:
    raise SystemExit("v60 manifest readiness boundary mismatch")
if manifest.get("real_release_package_ready") != 0 or manifest.get("release_requirement_blocked_rows") != 8:
    raise SystemExit("v60 manifest should keep release blocked")
if manifest.get("release_requirement_ready_rows") != 6:
    raise SystemExit("v60 manifest should record six PM-foundation ready requirements")
if (
    manifest.get("v53_query_span_binding_audit_ready") != 1
    or manifest.get("v53_query_span_binding_audit_rows") != 1000
    or manifest.get("v53_query_span_binding_pass_rows") != 1000
    or manifest.get("pm_pr_v53_query_span_binding_audit_ready") != 1
):
    raise SystemExit("v60 manifest should record direct v53 query-span binding audit evidence")
if (
    manifest.get("v53_direct_pinned_manifest_ready") != 1
    or manifest.get("v53_direct_repo_manifest_rows") != 10
    or manifest.get("v53_direct_file_manifest_rows") != 11266
    or manifest.get("v53_direct_content_snapshot_rows") != 11266
    or manifest.get("pm_pr_v53_direct_pinned_manifest_ready") != 1
):
    raise SystemExit("v60 manifest should record direct v53 pinned manifest evidence")
if (
    manifest.get("v53_negative_abstain_rows") != 160
    or manifest.get("v53_unsupported_control_rows") != 100
    or manifest.get("v53_ambiguous_control_rows") != 30
    or manifest.get("v53_missing_specific_control_rows") != 30
    or manifest.get("v53_doc_code_conflict_rows") != 140
):
    raise SystemExit("v60 manifest should record direct v53 control-row evidence")
if (
    manifest.get("pm_pr_v53_pm_acceptance_evidence_rows") != 10
    or manifest.get("pm_pr_v53_pm_acceptance_evidence_ready_rows") != 10
    or manifest.get("pm_pr_v53_pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v60 manifest should record v53 PM acceptance evidence")
if "v59e_public_source_snapshot_replay_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v59e public source snapshot replay rows")
if "v59e_local_abgh_row_contract_replay_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v59e local A/B/G/H row-contract replay rows")
if "v59e_v58_blind_eval_required_artifact_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 required artifact rows")
if "v59e_v58_blind_eval_return_template_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 return template rows")
if "v59e_v58_blind_eval_return_contract_map_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 return contract map rows")
if "v59e_v58_blind_eval_acceptance_evidence_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 acceptance evidence rows")
if "v59e_pm_pr_v56_replay_acceptance_evidence_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM v56 replay acceptance evidence rows")
if "v59e_pm_pr_v56_seed_dependency_blocker_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM v56 seed dependency blocker rows")
if "v59e_pm_pr_de_30b70b_acceptance_evidence_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM D/E 30B/70B acceptance evidence rows")
if "v59e_pm_pr_de_measured_registry_exclusion_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM D/E measured registry exclusion rows")
if "v59e_pm_pr_v58_real_execution_readiness_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM v58 real execution readiness rows")
if "v59e_pm_pr_v59_one_command_acceptance_evidence_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind PM v59 one-command acceptance evidence rows")
if (
    manifest.get("v58_acceptance_evidence_rows") != 11
    or manifest.get("v58_acceptance_evidence_contract_ready_rows") != 11
    or manifest.get("v58_acceptance_evidence_default_blocked_rows") != 11
    or manifest.get("v58_acceptance_evidence_blind_eval_ready_rows") != 0
    or manifest.get("v58_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("v58_acceptance_evidence_hidden_state_rows") != 0
):
    raise SystemExit("v60 manifest should record v58 acceptance evidence")
if (
    manifest.get("pm_pr_v56_replay_acceptance_evidence_rows") != 4
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_ready_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_blocked_rows") != 4
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_v56_replay_acceptance_evidence_approval_rows") != 4
):
    raise SystemExit("v60 manifest should record PM v56 replay acceptance evidence")
if (
    manifest.get("pm_pr_v56_seed_dependency_blocker_ready") != 1
    or manifest.get("pm_pr_v56_seed_dependency_blocker_rows") != 20
    or manifest.get("pm_pr_v56_missing_seed_artifact_rows") != 20
    or manifest.get("pm_pr_v56_missing_v45_seed_artifact_rows") != 11
    or manifest.get("pm_pr_v56_missing_seed_network_or_download_approval_required") != 1
):
    raise SystemExit("v60 manifest should record PM v56 seed dependency blocker evidence")
if (
    manifest.get("pm_pr_de_30b70b_acceptance_evidence_rows") != 4
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_ready_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_blocked_rows") != 4
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_de_30b70b_acceptance_evidence_approval_rows") != 4
):
    raise SystemExit("v60 manifest should record PM D/E 30B/70B acceptance evidence")
if (
    manifest.get("pm_pr_de_measured_registry_exclusion_rows") != 2
    or manifest.get("pm_pr_de_measured_registry_fixture_registry_rows") != 0
    or manifest.get("pm_pr_de_measured_registry_admission_ready_rows") != 0
    or manifest.get("pm_pr_de_measured_registry_blocked_rows") != 2
):
    raise SystemExit("v60 manifest should record D/E measured registry fixture exclusion")
if (
    manifest.get("pm_pr_v58_real_execution_readiness_rows") != 9
    or manifest.get("pm_pr_v58_real_execution_ready_rows") != 0
    or manifest.get("pm_pr_v58_real_execution_blocked_rows") != 9
    or manifest.get("pm_pr_v58_real_execution_fixture_allowed_rows") != 0
):
    raise SystemExit("v60 manifest should record v58 real execution blockers")
if (
    manifest.get("pm_pr_v59_one_command_acceptance_evidence_rows") != 2
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_ready_rows") != 1
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_blocked_rows") != 1
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("pm_pr_v59_one_command_acceptance_evidence_approval_rows") != 2
):
    raise SystemExit("v60 manifest should record PM v59 one-command acceptance evidence")
if (
    manifest.get("pm_pr_normalization_rows") != 7
    or manifest.get("pm_pr_normalization_split_required_rows") != 7
    or manifest.get("pm_pr_normalization_tests_only_rows") != 0
    or manifest.get("pm_pr_title_body_rows") != 1
    or manifest.get("pm_pr_title_body_rewrite_ready") != 1
):
    raise SystemExit("v60 manifest should record PM PR normalization and title/body rewrite rows")
if (
    manifest.get("pm_ready_semantic_rows") != 7
    or manifest.get("pm_ready_semantic_real_model_ready_rows") != 0
    or manifest.get("pm_ready_semantic_release_ready_rows") != 0
    or manifest.get("pm_ready_semantic_logical_100b_contract_fixture_ready") != 1
    or manifest.get("pm_ready_semantic_real_100b_inference_ready") != 0
):
    raise SystemExit("v60 manifest should preserve typed ready semantics")
if (
    manifest.get("pm_retrieval_leakage_guard_rows") != 7
    or manifest.get("pm_retrieval_leakage_guard_pass_rows") != 7
    or manifest.get("pm_retrieval_leakage_guard_blocked_rows") != 0
):
    raise SystemExit("v60 manifest should preserve retrieval leakage guards")
for field in [
    "v59e_pm_pr_normalization_rows_sha256",
    "v59e_pm_pr_title_body_rows_sha256",
    "v59e_pm_ready_semantic_rows_sha256",
    "v59e_pm_retrieval_leakage_guard_rows_sha256",
]:
    if field not in manifest:
        raise SystemExit(f"v60 manifest should hash-bind {field}")
if manifest.get("h10_pm_criteria_rows") != 6 or manifest.get("h10_pm_criteria_ready") != 1:
    raise SystemExit("v60 manifest should record direct h10 PM criteria evidence")
if manifest.get("h10_pm_return_contract_rows") != 6 or manifest.get("h10_pm_return_contract_ready") != 1:
    raise SystemExit("v60 manifest should record direct h10 return contract evidence")
if manifest.get("h10_pm_return_contract_fixture_allowed_rows") != 0 or manifest.get("h10_pm_return_contract_approval_rows") != 6:
    raise SystemExit("v60 manifest should preserve h10 return contract fixture/approval boundaries")
if manifest.get("h10_pm_return_contract_pass_rows") != 0:
    raise SystemExit("v60 manifest should keep h10 return contract blocked without labels")
if (
    manifest.get("h10_pm_acceptance_evidence_rows") != 6
    or manifest.get("h10_pm_acceptance_evidence_ready") != 1
    or manifest.get("h10_pm_acceptance_evidence_promotion_ready_rows") != 0
    or manifest.get("h10_pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v60 manifest should record direct h10 acceptance evidence")
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
        raise SystemExit(f"v60 manifest should keep {field}=0 without accepted h10 labels")
if manifest.get("h10_pm_acceptance_evidence_coverage_field_rows") != 6:
    raise SystemExit("v60 manifest should record coverage fields for all h10 acceptance evidence rows")
if manifest.get("h10_pm_acceptance_evidence_zero_accepted_rows") != 6:
    raise SystemExit("v60 manifest should record all h10 acceptance evidence rows as zero-accepted")
if manifest.get("h10_pm_acceptance_evidence_coverage_blocked_rows") != 6:
    raise SystemExit("v60 manifest should keep h10 criterion label coverage blocked")
if manifest.get("h10_pm_acceptance_evidence_source_verified_blocked_rows") != 6:
    raise SystemExit("v60 manifest should keep h10 source-verified eval blocked")
if "h10_pm_acceptance_evidence_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind h10 acceptance evidence")
if manifest.get("h10_pm_external_label_blocked") != 1 or manifest.get("h10_pm_source_provenance_binding_ready") != 1:
    raise SystemExit("v60 manifest should preserve h10 blocker/provenance boundary")
if (
    manifest.get("v54c_recommended_output_files_ready") != 1
    or manifest.get("v54c_recommended_output_file_rows") != 9
    or manifest.get("v54c_sha256sums_pm_recommended_csv_rows") != 6
    or manifest.get("v54c_sha256sums_pm_recommended_csv_ready") != 1
):
    raise SystemExit("v60 manifest should record direct v54c recommended output file evidence")
if (
    manifest.get("v54c_output_contract_ready") != 1
    or manifest.get("v54c_output_contract_rows") != 9
    or manifest.get("v54c_output_contract_pm_required_rows") != 7
    or manifest.get("v54c_output_contract_raw_prompt_forbidden_rows") != 9
    or manifest.get("v54c_model_visible_leakage_guard_ready") != 1
    or manifest.get("v54c_model_visible_forbidden_field_used_rows") != 0
    or manifest.get("v54c_model_visible_source_locator_rows") != 0
    or manifest.get("v54c_deterministic_source_span_generation_fixture_ready") != 1
    or manifest.get("v54c_real_model_generation_ready") != 0
):
    raise SystemExit("v60 manifest should record v54c grounded-generation output contract evidence")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v60 sha256 mismatch: {rel}")

boundary = (run_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed v1.0 Architecture Challenge Release",
    "Allowed wording",
    "v53 10-repo / 1000 source-span-bound query PM freeze",
    "direct v53 1000-row query-span binding audit copied through v59e PM sidecar",
    "direct v53 repo/file/content manifest evidence copied through v59e PM sidecar",
    "direct v59e A/B/G/H row-contract replay ledger",
    "direct 1000-row A/B/G/H same-query internal pre-baseline ledger copied through v59e PM sidecar",
    "real 30B/70B LLM+RAG comparison rows",
    "h10 real external/human label promotion evidence",
    "h10 PM criteria rows",
    "h10 acceptance evidence rows",
    "PM v59 one-command acceptance evidence preserves local A/B/G/H row-contract replay readiness",
    "v58c blind-response intake artifact",
    "v58d blind-review/adjudication return artifact",
    "v58 acceptance evidence rows",
    "approved public-source download/refresh evidence",
    "Do not publish v1.0 release",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60 boundary missing {snippet}")
PY

echo "v60 architecture challenge release contract smoke passed"
