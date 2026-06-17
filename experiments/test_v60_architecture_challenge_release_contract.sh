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
    "forbidden_claim_rows": "11",
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
    "pm_external_return_template_rows": "26",
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
    "pm_pr_v53_direct_pinned_manifest_ready": "1",
    "local_abgh_prebaseline_ready": "1",
    "local_abgh_prebaseline_ledger_ready": "1",
    "local_abgh_prebaseline_ledger_rows": "1000",
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
    "h10_pm_external_label_blocked": "1",
    "h10_pm_source_provenance_binding_ready": "1",
    "h10_pm_copied_files": "12",
    "v54c_recommended_output_files_ready": "1",
    "v54c_recommended_output_file_rows": "9",
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
    "v58_return_artifact_contract_ready": "1",
    "v58_required_artifact_rows": "8",
    "v58_required_artifact_fixture_allowed_rows": "0",
    "v58_return_template_rows": "8",
    "v58_return_template_ready_rows": "8",
    "v58_return_template_fixture_allowed_rows": "0",
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
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_closure_queue_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v59e/source_v54c/answer_rows.csv",
    "source_v59e/source_v54c/citation_rows.csv",
    "source_v59e/source_v54c/unsupported_claim_rows.csv",
    "source_v59e/source_v54c/abstain_rows.csv",
    "source_v59e/source_v54c/generator_resource_rows.csv",
    "source_v59e/source_v54c/wrong_answer_guard_rows.csv",
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
    "source_v59e/source_pm_pr_claim_slice_gate/source_v59e/local_abgh_row_contract_replay_rows.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_summary.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_rows.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_summary.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_rows.csv",
    "source_v59e/v58_blind_eval_required_artifact_rows.csv",
    "source_v59e/v58_blind_eval_return_template_rows.csv",
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
    "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60 artifact: {rel}")

v60_pm_v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(v60_pm_v53t_real_adapter_rows) != 4:
    raise SystemExit("v60 should carry four v53t real-adapter freeze rows through v59e/PM sidecar")
if v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["status"] != "pass":
    raise SystemExit("v60 should carry passing v53t real-adapter execution evidence")
if "coherent_wrong_key_rows=287" not in v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in v60_pm_v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq public comparison blocker")

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
    or local_abgh_contract_rows["v53aq"]["selection_question_text_only_rows"] != "4000"
    or local_abgh_contract_rows["v53aq"]["selection_oracle_field_used_rows"] != "0"
    or local_abgh_contract_rows["v53aq"]["same_query_internal_prebaseline_rows"] != "1000"
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
if len(v58_required_rows) != 8:
    raise SystemExit("v60 should carry eight v58 required artifact rows")
v58_required_by_blocker = {}
for row in v58_required_rows:
    v58_required_by_blocker.setdefault(row["blocker_class"], []).append(row)
if len(v58_required_by_blocker.get("v58c-intake-artifact-missing", [])) != 3:
    raise SystemExit("v60 v58 required artifact rows should include three v58c intake artifacts")
if len(v58_required_by_blocker.get("v58-real-blind-eval-missing", [])) != 5:
    raise SystemExit("v60 v58 required artifact rows should include five real blind-eval artifacts")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in v58_required_rows):
    raise SystemExit("v60 v58 required artifact rows should forbid fixtures and require approval")
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
    raise SystemExit("v60 v58 required artifact ids mismatch")

v58_template_rows = read_csv(run_dir / "source_v59e/v58_blind_eval_return_template_rows.csv")
if len(v58_template_rows) != 8:
    raise SystemExit("v60 should carry eight v58 return template rows")
if {row["artifact_id"] for row in v58_template_rows} != expected_v58_artifacts:
    raise SystemExit("v60 v58 return template ids mismatch")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" or row["template_ready"] != "1" for row in v58_template_rows):
    raise SystemExit("v60 v58 return templates should be ready, no-fixture, approval-required")

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

allowed = read_csv(run_dir / "allowed_claim_rows.csv")
for claim in ["architecture-challenge-contract-scaffold", "pm-foundation-replay-bundle", "local-architecture-preview"]:
    if claim not in {row["claim_id"] for row in allowed}:
        raise SystemExit(f"v60 allowed claim missing {claim}")

forbidden = {row["claim_id"] for row in read_csv(run_dir / "forbidden_claim_rows.csv")}
for claim in [
    "v1_0_release_ready",
    "beats_30b_150b_llm_rag",
    "public_comparison_win",
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
if "v59e_public_source_snapshot_replay_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v59e public source snapshot replay rows")
if "v59e_local_abgh_row_contract_replay_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v59e local A/B/G/H row-contract replay rows")
if "v59e_v58_blind_eval_required_artifact_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 required artifact rows")
if "v59e_v58_blind_eval_return_template_sha256" not in manifest:
    raise SystemExit("v60 manifest should hash-bind v58 return template rows")
if manifest.get("h10_pm_criteria_rows") != 6 or manifest.get("h10_pm_criteria_ready") != 1:
    raise SystemExit("v60 manifest should record direct h10 PM criteria evidence")
if manifest.get("h10_pm_return_contract_rows") != 6 or manifest.get("h10_pm_return_contract_ready") != 1:
    raise SystemExit("v60 manifest should record direct h10 return contract evidence")
if manifest.get("h10_pm_return_contract_fixture_allowed_rows") != 0 or manifest.get("h10_pm_return_contract_approval_rows") != 6:
    raise SystemExit("v60 manifest should preserve h10 return contract fixture/approval boundaries")
if manifest.get("h10_pm_return_contract_pass_rows") != 0:
    raise SystemExit("v60 manifest should keep h10 return contract blocked without labels")
if manifest.get("h10_pm_external_label_blocked") != 1 or manifest.get("h10_pm_source_provenance_binding_ready") != 1:
    raise SystemExit("v60 manifest should preserve h10 blocker/provenance boundary")
if manifest.get("v54c_recommended_output_files_ready") != 1 or manifest.get("v54c_recommended_output_file_rows") != 9:
    raise SystemExit("v60 manifest should record direct v54c recommended output file evidence")

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
    "v58c blind-response intake artifact",
    "v58d blind-review/adjudication return artifact",
    "approved public-source download/refresh evidence",
    "Do not publish v1.0 release",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60 boundary missing {snippet}")
PY

echo "v60 architecture challenge release contract smoke passed"
