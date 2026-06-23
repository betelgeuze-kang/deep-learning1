#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_decision.csv"

V53T_REUSE_EXISTING="${V53T_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null

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
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v52y_f_optional_final_policy_ready": "0",
    "v52y_dependency_blocker_ready": "1",
    "f_optional_final_disposition_ready": "0",
    "f_optional_final_disposition": "blocked-by-v52y-dependency",
    "v53i_complete_source_query_instantiation_ready": "1",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "v53aq_complete_source_abgh_real_adapter_measured_ready": "1",
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "complete_source_span_rows": "1000",
    "core_system_count": "7",
    "core_answer_rows": "7000",
    "symmetric_scorer_rows": "7000",
    "symmetric_policy_rows": "7000",
    "review_packet_ready": "1",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "machine_complete_source_surface_ready": "1",
    "review_return_ready": "0",
    "human_review_completed": "0",
    "adjudication_completed": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "pm_v53_freeze_ready": "1",
    "pm_freeze_check_rows": "11",
    "pm_freeze_pass_rows": "11",
    "pm_freeze_blocked_rows": "0",
    "foundation_freeze_certificate_rows": "11",
    "foundation_freeze_pass_rows": "11",
    "foundation_freeze_blocked_rows": "0",
    "pm_acceptance_evidence_rows": "11",
    "pm_acceptance_evidence_ready_rows": "11",
    "pm_acceptance_evidence_replay_pass_rows": "11",
    "pm_acceptance_evidence_blocker_pass_rows": "11",
    "pm_acceptance_evidence_tests_only_rows": "0",
    "v1_exit_criteria_rows": "7",
    "v1_exit_criteria_ready_rows": "7",
    "v1_exit_criteria_blocked_rows": "0",
    "v1_exit_repo_count_within_band": "1",
    "v1_exit_query_rows_within_band": "1",
    "v1_exit_negative_control_share_ready": "1",
    "v1_exit_machine_foundation_ready": "1",
    "foundation_machine_freeze_ready": "1",
    "foundation_direct_evidence_ready": "1",
    "foundation_query_span_binding_audit_ready": "1",
    "foundation_query_span_binding_audit_rows": "1000",
    "foundation_query_span_binding_pass_rows": "1000",
    "foundation_query_span_binding_blocked_rows": "0",
    "unseen_repository_split_ready": "1",
    "unseen_repository_split_rows": "10",
    "unseen_repository_split_pass_rows": "10",
    "unseen_repository_holdout_repo_rows": "2",
    "unseen_repository_calibration_repo_rows": "8",
    "unseen_repository_holdout_query_rows": "200",
    "unseen_repository_calibration_query_rows": "800",
    "unseen_repository_split_query_rows": "1000",
    "foundation_direct_pinned_manifest_ready": "1",
    "foundation_direct_repo_manifest_ready": "1",
    "foundation_direct_content_snapshot_ready": "1",
    "foundation_direct_repo_manifest_rows": "10",
    "foundation_direct_file_manifest_rows": "11266",
    "foundation_direct_content_repo_rows": "10",
    "foundation_direct_content_snapshot_rows": "11266",
    "foundation_real_adapter_freeze_rows": "4",
    "foundation_real_adapter_freeze_pass_rows": "4",
    "foundation_real_adapter_freeze_blocked_rows": "0",
    "foundation_real_adapter_evidence_ready": "1",
    "foundation_real_adapter_same_query_rows_ready": "1",
    "foundation_real_adapter_same_query_ledger_ready": "1",
    "foundation_real_adapter_same_query_ledger_rows": "1000",
    "foundation_real_adapter_internal_contract_ready": "1",
    "foundation_real_adapter_internal_contract_rows": "4",
    "foundation_real_adapter_internal_contract_ready_rows": "4",
    "foundation_real_adapter_evaluator_rows": "4000",
    "foundation_real_adapter_evaluator_separate_rows": "4000",
    "v53aq_question_only_selection_contract_ready": "1",
    "v53aq_same_complete_source_query_hash": "1",
    "foundation_direct_query_rows": "1000",
    "foundation_direct_span_rows": "1000",
    "foundation_direct_abgh_answer_rows": "4000",
    "foundation_direct_abgh_citation_rows": "4000",
    "foundation_direct_abgh_evaluator_rows": "4000",
    "foundation_direct_abgh_resource_rows": "4000",
    "foundation_direct_abgh_adapter_trace_rows": "4000",
    "foundation_direct_evaluator_separate_rows": "4000",
    "foundation_direct_same_query_rows_ready": "1",
    "negative_abstain_rows": "160",
    "unsupported_control_rows": "100",
    "ambiguous_control_rows": "30",
    "missing_specific_control_rows": "30",
    "doc_code_conflict_rows": "140",
    "same_complete_source_query_hash": "1",
    "abgh_same_query_ready": "1",
    "v53ap_expected_answer_oracle_replay": "0",
    "v53ap_deterministic_source_span_adapter_execution": "1",
    "v53ap_deterministic_source_span_adapter_rows": "4000",
    "v53ap_actual_adapter_execution_ready": "1",
    "v53ap_real_system_performance_claim_ready": "0",
    "v53aq_selection_question_text_only": "1",
    "v53aq_selection_oracle_field_used": "0",
    "v53aq_expected_answer_oracle_replay": "0",
    "v53aq_deterministic_source_span_adapter_execution": "0",
    "v53aq_actual_adapter_execution_ready": "1",
    "v53aq_real_adapter_execution_ready": "1",
    "v53aq_real_system_performance_claim_ready": "0",
    "v53aq_internal_real_adapter_metric_claim_ready": "1",
    "v53aq_public_real_system_performance_claim_ready": "0",
    "v53aq_answer_hash_match_rows": "76",
    "v53aq_coherent_wrong_key_rows": "3924",
    "v53aq_selection_sanitized_question_only": "1",
    "v53aq_source_locator_in_question_removed_rows": "4000",
    "v53aq_selection_runtime_guard_passed_rows": "4000",
    "v53aq_public_comparison_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53t {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_audit_readiness_requirement_rows.csv",
    "complete_source_pm_freeze_check_rows.csv",
    "complete_source_foundation_freeze_rows.csv",
    "complete_source_pm_acceptance_evidence_rows.csv",
    "complete_source_abgh_real_adapter_freeze_rows.csv",
    "complete_source_v1_exit_criteria_rows.csv",
    "complete_source_query_span_binding_audit_rows.csv",
    "complete_source_unseen_repository_split_rows.csv",
    "complete_source_audit_claim_rows.csv",
    "complete_source_audit_readiness_metric_rows.csv",
    "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md",
    "v53t_complete_source_audit_readiness_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_v53ap/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "source_v53ap/abgh_system_rows.csv",
    "source_v53ap/abgh_answer_rows.csv",
    "source_v53ap/abgh_citation_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53ap/abgh_resource_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53ap/abgh_system_metric_rows.csv",
    "source_v53ap/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md",
    "source_v53aq/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "source_v53aq/adapter_selection_contract_rows.csv",
    "source_v53aq/abgh_answer_rows.csv",
    "source_v53aq/abgh_citation_rows.csv",
    "source_v53aq/abgh_evaluator_rows.csv",
    "source_v53aq/abgh_resource_rows.csv",
    "source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v53aq/abgh_system_metric_rows.csv",
    "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
    "source_v53aq/routehint_rows.csv",
    "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "source_v53r/v53r_complete_source_review_packet_summary.csv",
    "source_v53s/v53s_complete_source_review_return_intake_summary.csv",
    "source_v53s/review_return_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53t artifact: {rel}")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_audit_readiness_requirement_rows.csv")}
for requirement_id in [
    "complete-source-content-and-query-surface",
    "core-a-b-c-d-e-g-h-answer-citation-resource",
    "symmetric-scorer-policy-surface",
    "review-packet-ready",
    "unseen-repository-split-ready",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53t requirement should pass: {requirement_id}")
for requirement_id in [
    "f-optional-final-disposition",
    "human-review-return-accepted",
    "adjudication-return-accepted",
    "reviewer-identity-conflict-ready",
    "quality-comparison-claim-ready",
    "release-package-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53t requirement should stay blocked: {requirement_id}")
if len(requirements) != 11:
    raise SystemExit("v53t requirement row count mismatch")

pm_freeze_checks = {row["check_id"]: row for row in read_csv(run_dir / "complete_source_pm_freeze_check_rows.csv")}
if len(pm_freeze_checks) != 11:
    raise SystemExit("v53t PM freeze check row count mismatch")
for check_id in [
    "pinned-public-repo-manifest",
    "source-span-bound-1000",
    "unseen-repository-split",
    "negative-abstain-control-10pct",
    "unsupported-claim-control",
    "missing-specific-abstain-control",
    "doc-code-conflict-control",
    "answer-citation-separate-eval",
    "abgh-same-query-v53i",
    "replayable-artifact-chain",
    "blocker-false-positive-closed",
]:
    if pm_freeze_checks[check_id]["status"] != "pass":
        raise SystemExit(f"v53t PM freeze check should pass: {check_id}")
if pm_freeze_checks["missing-specific-abstain-control"]["actual_value"] != "30":
    raise SystemExit("v53t PM freeze missing-specific actual value mismatch")
if pm_freeze_checks["replayable-artifact-chain"]["status"] != "pass" or "direct_ready=1" not in pm_freeze_checks["replayable-artifact-chain"]["actual_value"]:
    raise SystemExit("v53t replayable artifact chain should be backed by direct row evidence")
if "binding_audit_pass=1000" not in pm_freeze_checks["source-span-bound-1000"]["actual_value"]:
    raise SystemExit("v53t source-span PM check should expose 1000 passing binding-audit rows")
if "holdout_query_rows=200" not in pm_freeze_checks["unseen-repository-split"]["actual_value"]:
    raise SystemExit("v53t unseen split PM check should expose 200 heldout query rows")
if "direct_pinned_manifest_ready=1" not in pm_freeze_checks["pinned-public-repo-manifest"]["actual_value"]:
    raise SystemExit("v53t pinned manifest check should expose direct pinned manifest readiness")
if "repo_manifest=10" not in pm_freeze_checks["replayable-artifact-chain"]["actual_value"]:
    raise SystemExit("v53t replayable artifact chain should include direct repo manifest rows")
if "binding_audit_pass=1000" not in pm_freeze_checks["replayable-artifact-chain"]["actual_value"]:
    raise SystemExit("v53t replayable artifact chain should include binding audit rows")
if "unseen_repository_split_ready=1" not in pm_freeze_checks["replayable-artifact-chain"]["actual_value"]:
    raise SystemExit("v53t replayable artifact chain should include unseen split readiness")

query_rows = read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")
span_rows = read_csv(run_dir / "source_v53i/complete_source_span_rows.csv")
binding_rows = read_csv(run_dir / "complete_source_query_span_binding_audit_rows.csv")
unseen_split_rows = read_csv(run_dir / "complete_source_unseen_repository_split_rows.csv")
content_repo_rows = read_csv(run_dir / "source_v53i/source_v53h/complete_source_content_repo_rows.csv")
content_snapshot_rows = read_csv(run_dir / "source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")
repo_coverage_rows = read_csv(run_dir / "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
file_manifest_rows = read_csv(run_dir / "source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
answer_rows = read_csv(run_dir / "source_v53ap/abgh_answer_rows.csv")
citation_rows = read_csv(run_dir / "source_v53ap/abgh_citation_rows.csv")
evaluator_rows = read_csv(run_dir / "source_v53ap/abgh_evaluator_rows.csv")
resource_rows = read_csv(run_dir / "source_v53ap/abgh_resource_rows.csv")
adapter_trace_rows = read_csv(run_dir / "source_v53ap/abgh_adapter_trace_rows.csv")
v53aq_answers = read_csv(run_dir / "source_v53aq/abgh_answer_rows.csv")
v53aq_citations = read_csv(run_dir / "source_v53aq/abgh_citation_rows.csv")
v53aq_evaluators = read_csv(run_dir / "source_v53aq/abgh_evaluator_rows.csv")
v53aq_resources = read_csv(run_dir / "source_v53aq/abgh_resource_rows.csv")
v53aq_adapter_traces = read_csv(run_dir / "source_v53aq/abgh_adapter_trace_rows.csv")
v53aq_prebaseline = read_csv(run_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
v53aq_contract_rows = {row["system_id"]: row for row in read_csv(run_dir / "source_v53aq/abgh_internal_prebaseline_contract_rows.csv")}
v53aq_selection_contract = {row["field_name"]: row for row in read_csv(run_dir / "source_v53aq/adapter_selection_contract_rows.csv")}
if len(query_rows) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v53t should copy direct 1000 query/span rows")
if len(binding_rows) != 1000:
    raise SystemExit("v53t should emit 1000 query-span binding audit rows")
if len(unseen_split_rows) != 10:
    raise SystemExit("v53t should emit 10 repo-level unseen split rows")
if any(row["split_status"] != "pass" for row in unseen_split_rows):
    raise SystemExit("v53t unseen repository split rows should all pass")
if sum(row["split_name"] == "unseen_holdout" for row in unseen_split_rows) != 2:
    raise SystemExit("v53t unseen repository split should reserve 2 heldout repos")
if sum(row["split_name"] == "calibration" for row in unseen_split_rows) != 8:
    raise SystemExit("v53t unseen repository split should keep 8 calibration repos")
if sum(int(row["query_rows"]) for row in unseen_split_rows if row["split_name"] == "unseen_holdout") != 200:
    raise SystemExit("v53t unseen repository split should reserve 200 heldout queries")
if sum(int(row["query_rows"]) for row in unseen_split_rows) != len(query_rows):
    raise SystemExit("v53t unseen repository split should assign every query exactly once")
if any(row["query_rows"] != "100" or row["source_span_rows"] != "100" for row in unseen_split_rows):
    raise SystemExit("v53t unseen repository split should preserve 100 query/span rows per repo")
for flag in [
    "repo_manifest_bound",
    "content_snapshot_bound",
    "head_sha_match",
    "tree_manifest_ready",
    "content_snapshot_ready",
]:
    if any(row[flag] != "1" for row in unseen_split_rows):
        raise SystemExit(f"v53t unseen repository split should pass {flag} for every repo")
if {row["owner_repo"] for row in unseen_split_rows} != {row["owner_repo"] for row in repo_coverage_rows}:
    raise SystemExit("v53t unseen repository split should cover every repo manifest row")
if any(not row["source_span_id"] for row in query_rows):
    raise SystemExit("v53t direct query rows should bind source spans")
if any(row["binding_status"] != "pass" for row in binding_rows):
    raise SystemExit("v53t query-span binding audit rows should all pass")
for flag in [
    "source_span_required",
    "span_row_present",
    "query_id_match",
    "owner_repo_match",
    "head_sha_match",
    "path_match",
    "line_start_match",
    "line_end_match",
    "source_file_sha256_match",
    "git_blob_sha_match",
    "content_row_present",
    "content_row_materialized",
]:
    if any(row[flag] != "1" for row in binding_rows):
        raise SystemExit(f"v53t binding audit should pass {flag} for every query")
if {row["query_id"] for row in binding_rows} != {row["query_id"] for row in query_rows}:
    raise SystemExit("v53t binding audit rows should cover every query ID")
if len(repo_coverage_rows) != 10 or len(content_repo_rows) != 10:
    raise SystemExit("v53t should copy direct 10-repo manifest and content repo rows")
if len(file_manifest_rows) != 11266 or len(content_snapshot_rows) != 11266:
    raise SystemExit("v53t should copy direct complete-source file/content manifest rows")
if any(len(row["head_sha"]) != 40 or row["complete_source_tree_manifest_ready"] != "1" for row in repo_coverage_rows):
    raise SystemExit("v53t repo coverage rows should bind pinned HEAD SHAs and ready tree manifests")
if any(len(row["head_sha"]) != 40 or row["content_snapshot_ready"] != "1" for row in content_repo_rows):
    raise SystemExit("v53t content repo rows should bind pinned HEAD SHAs and ready content snapshots")
repo_heads = {(row["owner_repo"], row["head_sha"]) for row in repo_coverage_rows}
content_heads = {(row["owner_repo"], row["head_sha"]) for row in content_repo_rows}
query_heads = {(row["owner_repo"], row["head_sha"]) for row in query_rows}
if repo_heads != content_heads or not query_heads.issubset(repo_heads):
    raise SystemExit("v53t direct repo/content/query rows should share pinned repo HEAD bindings")
for table_name, rows in [
    ("answer", answer_rows),
    ("citation", citation_rows),
    ("evaluator", evaluator_rows),
    ("resource", resource_rows),
    ("adapter_trace", adapter_trace_rows),
]:
    if len(rows) != 4000:
        raise SystemExit(f"v53t should copy 4000 direct A/B/G/H {table_name} rows")
query_ids = {row["query_id"] for row in query_rows}
for system_id in {"A", "B", "G", "H"}:
    if {row["query_id"] for row in evaluator_rows if row["system_id"] == system_id} != query_ids:
        raise SystemExit(f"v53t direct evaluator rows should cover all queries for {system_id}")
if any(
    row["answer_eval_separate"] != "1"
    or row["citation_eval_separate"] != "1"
    or row["resource_eval_separate"] != "1"
    or row["answer_hash_match"] != "1"
    or row["citation_span_match"] != "1"
    or row["resource_row_bound"] != "1"
    for row in evaluator_rows
):
    raise SystemExit("v53t direct evaluator rows should separately bind answer/citation/resource checks")
for table_name, rows in [
    ("v53aq_answer", v53aq_answers),
    ("v53aq_citation", v53aq_citations),
    ("v53aq_evaluator", v53aq_evaluators),
    ("v53aq_resource", v53aq_resources),
    ("v53aq_adapter_trace", v53aq_adapter_traces),
]:
    if len(rows) != 4000:
        raise SystemExit(f"v53t should copy 4000 direct {table_name} rows")
    for system_id in {"A", "B", "G", "H"}:
        if {row["query_id"] for row in rows if row["system_id"] == system_id} != query_ids:
            raise SystemExit(f"v53t {table_name} rows should cover all queries for {system_id}")
if v53aq_selection_contract.get("sanitized_question", {}).get("selection_allowed") != "1":
    raise SystemExit("v53t v53aq selection contract should allow sanitized question text")
if v53aq_selection_contract.get("question", {}).get("selection_allowed") != "0":
    raise SystemExit("v53t v53aq selection contract should forbid raw question text")
for field in [
    "query_id",
    "expected_answer",
    "expected_answer_sha256",
    "expected_behavior",
    "source_span_id",
    "source_path",
    "source_line_start",
    "source_line_end",
    "source_file_sha256",
    "source_git_blob_sha",
    "audit_type",
    "negative_or_abstain",
]:
    if v53aq_selection_contract.get(field, {}).get("selection_allowed") != "0":
        raise SystemExit(f"v53t v53aq selection contract should forbid {field}")
if any(
    row["answer_eval_separate"] != "1"
    or row["citation_eval_separate"] != "1"
    or row["resource_eval_separate"] != "1"
    or row["resource_row_bound"] != "1"
    or row["selection_question_text_only"] != "1"
    or row["selection_oracle_field_used"] != "0"
    or row["expected_answer_oracle_replay"] != "0"
    or row["deterministic_source_span_adapter_execution"] != "0"
    or row["real_system_performance_claim_ready"] != "0"
    or row["internal_real_adapter_metric_claim_ready"] != "1"
    or row["public_real_system_performance_claim_ready"] != "0"
    for row in v53aq_evaluators
):
    raise SystemExit("v53t v53aq evaluator rows should preserve question-only real-adapter boundaries")
if len(v53aq_prebaseline) != 1000 or {row["query_id"] for row in v53aq_prebaseline} != query_ids:
    raise SystemExit("v53t should copy 1000 v53aq same-query internal pre-baseline ledger rows")
for row in v53aq_prebaseline:
    for field, value in {
        "same_query_all_systems": "1",
        "same_evaluator_contract": "1",
        "same_resource_bound": "1",
        "selection_question_text_only_all": "1",
        "selection_sanitized_question_only_all": "1",
        "source_locator_in_question_removed_all": "1",
        "selection_oracle_field_used_any": "0",
        "expected_answer_oracle_replay_any": "0",
        "deterministic_source_span_adapter_execution_any": "0",
        "g_h_routehint_no_raw_context": "1",
        "public_comparison_claim_ready": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "internal_real_adapter_metric_claim_ready": "1",
        "public_real_system_performance_claim_ready": "0",
    }.items():
        if row[field] != value:
            raise SystemExit(f"v53t v53aq same-query ledger {field}: expected {value}, got {row[field]}")
for prefix in ["a", "b", "g", "h"]:
    if sum(row[f"{prefix}_coherent_wrong_key"] == "1" for row in v53aq_prebaseline) != 981:
        raise SystemExit(f"v53t v53aq same-query ledger should preserve {prefix.upper()} coherent wrong-key count")
if set(v53aq_contract_rows) != {"A", "B", "G", "H"}:
    raise SystemExit("v53t should copy the four-row v53aq internal prebaseline contract")
for system_id, row in v53aq_contract_rows.items():
    for field, value in {
        "query_set_id": "v53i_complete_source_1000",
        "source_query_rows_sha256": summary["current_v53i_query_rows_sha256"],
        "source_span_rows_sha256": sha256(run_dir / "source_v53i/complete_source_span_rows.csv"),
        "source_manifest_rows": "497",
        "query_rows": "1000",
        "answer_rows": "1000",
        "citation_rows": "1000",
        "evaluator_rows": "1000",
        "resource_rows": "1000",
        "adapter_trace_rows": "1000",
        "same_query_set": "1",
        "same_evaluator_contract": "1",
        "same_resource_contract": "1",
        "selection_question_text_only": "1",
        "selection_oracle_field_used": "0",
        "expected_answer_oracle_replay_rows": "0",
        "deterministic_source_span_adapter_rows": "0",
        "internal_real_adapter_metric_claim_ready": "1",
        "public_real_system_performance_claim_ready": "0",
        "public_comparison_claim_ready": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "contract_ready": "1",
    }.items():
        if row.get(field) != value:
            raise SystemExit(f"v53t v53aq contract {system_id}.{field}: expected {value}, got {row.get(field)}")
    if "no public comparison" not in row["claim_boundary"]:
        raise SystemExit(f"v53t v53aq contract should keep public comparison blocked for {system_id}")

foundation_freeze_rows = {row["criterion_id"]: row for row in read_csv(run_dir / "complete_source_foundation_freeze_rows.csv")}
if len(foundation_freeze_rows) != 11:
    raise SystemExit("v53t foundation freeze certificate row count mismatch")
for criterion_id in [
    "pinned-public-repo-manifest",
    "source-span-bound-query-surface",
    "unseen-repository-split",
    "negative-abstain-control-share",
    "unsupported-claim-control",
    "missing-specific-abstain-control",
    "doc-code-conflict-control",
    "answer-citation-separated-evaluator",
    "abgh-same-query-measured-run",
    "replayable-artifact-chain",
    "public-comparison-boundary-closed",
]:
    if foundation_freeze_rows[criterion_id]["status"] != "pass":
        raise SystemExit(f"v53t foundation freeze criterion should pass: {criterion_id}")
if foundation_freeze_rows["unsupported-claim-control"]["actual_value"] != "100":
    raise SystemExit("v53t foundation freeze unsupported-control actual value mismatch")
if foundation_freeze_rows["missing-specific-abstain-control"]["actual_value"] != "30":
    raise SystemExit("v53t foundation freeze missing-specific actual value mismatch")
if foundation_freeze_rows["doc-code-conflict-control"]["actual_value"] != "140":
    raise SystemExit("v53t foundation freeze doc-code conflict actual value mismatch")
if foundation_freeze_rows["source-span-bound-query-surface"]["evidence_path"] != "complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("v53t source-span freeze evidence should point at direct binding audit rows")
if "binding_audit_pass=1000" not in foundation_freeze_rows["source-span-bound-query-surface"]["actual_value"]:
    raise SystemExit("v53t source-span freeze should expose binding audit pass rows")
if foundation_freeze_rows["unseen-repository-split"]["evidence_path"] != "complete_source_unseen_repository_split_rows.csv":
    raise SystemExit("v53t unseen split freeze evidence should point at direct split rows")
if "holdout_query_rows=200" not in foundation_freeze_rows["unseen-repository-split"]["actual_value"]:
    raise SystemExit("v53t unseen split freeze should expose heldout query rows")
if foundation_freeze_rows["pinned-public-repo-manifest"]["evidence_path"] != "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv":
    raise SystemExit("v53t pinned manifest evidence should point at direct repo coverage rows")
if "direct_pinned_manifest_ready=1" not in foundation_freeze_rows["pinned-public-repo-manifest"]["actual_value"]:
    raise SystemExit("v53t foundation freeze should expose direct pinned manifest readiness")
if foundation_freeze_rows["answer-citation-separated-evaluator"]["evidence_path"] != "source_v53ap/abgh_evaluator_rows.csv":
    raise SystemExit("v53t separated evaluator evidence should point at direct evaluator rows")
if foundation_freeze_rows["abgh-same-query-measured-run"]["evidence_path"] != "source_v53ap/abgh_evaluator_rows.csv":
    raise SystemExit("v53t A/B/G/H same-query evidence should point at direct evaluator rows")
if "real system performance" not in foundation_freeze_rows["abgh-same-query-measured-run"]["claim_boundary"]:
    raise SystemExit("v53t foundation freeze should keep A/B/G/H real system performance boundary closed")
if "forbids public comparison" not in foundation_freeze_rows["public-comparison-boundary-closed"]["claim_boundary"]:
    raise SystemExit("v53t foundation freeze should explicitly forbid public comparison wording")
if "unseen_repository_split_ready=1" not in foundation_freeze_rows["replayable-artifact-chain"]["actual_value"]:
    raise SystemExit("v53t foundation freeze replay chain should include unseen split readiness")

pm_acceptance_rows = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_pm_acceptance_evidence_rows.csv")}
expected_pm_acceptance_ids = {
    "pinned-public-repo-manifest",
    "source-span-query-freeze",
    "unseen-repository-split",
    "negative-abstain-control-share",
    "unsupported-claim-control",
    "missing-specific-abstain-control",
    "doc-code-conflict-control",
    "answer-citation-separated-evaluator",
    "abgh-same-query-deterministic-prebaseline",
    "abgh-real-adapter-same-query-internal",
    "public-comparison-boundary-closed",
}
if set(pm_acceptance_rows) != expected_pm_acceptance_ids:
    raise SystemExit("v53t PM acceptance evidence row ids mismatch")
if any(row["status"] != "pass" or row["acceptance_ready"] != "1" for row in pm_acceptance_rows.values()):
    raise SystemExit("v53t PM acceptance evidence rows should all be ready")
if any(row["tests_only_merge_condition"] != "0" for row in pm_acceptance_rows.values()):
    raise SystemExit("v53t PM acceptance evidence must not use tests-only merge conditions")
if any(row["claim_boundary_status"] != "pass" or row["replay_artifact_status"] != "pass" or row["blocker_false_positive_status"] != "pass" for row in pm_acceptance_rows.values()):
    raise SystemExit("v53t PM acceptance evidence should pass claim/replay/blocker gates")
for row in pm_acceptance_rows.values():
    evidence_path = run_dir / row["evidence_path"]
    if not evidence_path.is_file() or evidence_path.stat().st_size == 0:
        raise SystemExit(f"v53t PM acceptance evidence path missing: {row['evidence_path']}")
    if row["evidence_sha256"] != sha256(evidence_path):
        raise SystemExit(f"v53t PM acceptance evidence sha mismatch: {row['requirement_id']}")
    if row["evidence_rows"] != str(len(read_csv(evidence_path))):
        raise SystemExit(f"v53t PM acceptance evidence row count mismatch: {row['requirement_id']}")
if pm_acceptance_rows["pinned-public-repo-manifest"]["evidence_rows"] != "10":
    raise SystemExit("v53t PM acceptance should expose ten repo manifest rows")
if pm_acceptance_rows["source-span-query-freeze"]["evidence_rows"] != "1000":
    raise SystemExit("v53t PM acceptance should expose 1000 query-span binding audit rows")
if pm_acceptance_rows["unseen-repository-split"]["evidence_rows"] != "10":
    raise SystemExit("v53t PM acceptance should expose 10 repo split rows")
if pm_acceptance_rows["answer-citation-separated-evaluator"]["evidence_rows"] != "4000":
    raise SystemExit("v53t PM acceptance should expose 4000 separated evaluator rows")
if pm_acceptance_rows["abgh-real-adapter-same-query-internal"]["evidence_rows"] != "1000":
    raise SystemExit("v53t PM acceptance should expose 1000 real-adapter same-query rows")
for requirement_id, snippet in {
    "source-span-query-freeze": "binding_audit_pass_rows=1000",
    "unseen-repository-split": "holdout_query_rows=200",
    "unsupported-claim-control": "unsupported_control_rows=100",
    "missing-specific-abstain-control": "missing_specific_control_rows=30",
    "doc-code-conflict-control": "doc_code_conflict_rows=140",
    "abgh-same-query-deterministic-prebaseline": "real_system_performance_claim_ready=0",
    "abgh-real-adapter-same-query-internal": "public_real_system_performance_claim_ready=0",
    "public-comparison-boundary-closed": "required_30b_baseline_ready=0",
}.items():
    if snippet not in pm_acceptance_rows[requirement_id]["actual_value"]:
        raise SystemExit(f"v53t PM acceptance row should expose {snippet}: {requirement_id}")
if "public comparison remains blocked" not in pm_acceptance_rows["abgh-same-query-deterministic-prebaseline"]["claim_boundary"]:
    raise SystemExit("v53t PM acceptance should keep A/B/G/H public comparison blocked")

v1_exit_rows = {row["criterion_id"]: row for row in read_csv(run_dir / "complete_source_v1_exit_criteria_rows.csv")}
expected_v1_exit_ids = {
    "repo-count-band-10-30",
    "query-row-band-1000-3000",
    "unseen-repository-split-ready",
    "negative-abstain-and-control-families",
    "answer-citation-separate-evaluator",
    "abgh-same-query-internal-prebaseline",
    "claim-boundary-replay-blocker-gate",
}
if set(v1_exit_rows) != expected_v1_exit_ids:
    raise SystemExit("v53t v1 exit criteria row ids mismatch")
if any(row["status"] != "pass" for row in v1_exit_rows.values()):
    raise SystemExit("v53t v1 exit criteria rows should all pass for the machine foundation")
if any(row["tests_only_merge_condition"] != "0" for row in v1_exit_rows.values()):
    raise SystemExit("v53t v1 exit criteria must not use tests-only merge conditions")
if any(row["claim_boundary_status"] != "pass" or row["replay_artifact_status"] != "pass" or row["blocker_false_positive_status"] != "pass" for row in v1_exit_rows.values()):
    raise SystemExit("v53t v1 exit criteria should pass claim/replay/blocker gates")
for row in v1_exit_rows.values():
    evidence_path = run_dir / row["evidence_path"]
    if not evidence_path.is_file() or evidence_path.stat().st_size == 0:
        raise SystemExit(f"v53t v1 exit evidence path missing: {row['evidence_path']}")
    if row["evidence_sha256"] != sha256(evidence_path):
        raise SystemExit(f"v53t v1 exit evidence sha mismatch: {row['criterion_id']}")
    if row["evidence_rows"] != str(len(read_csv(evidence_path))):
        raise SystemExit(f"v53t v1 exit evidence row count mismatch: {row['criterion_id']}")
if "repo_count=10" not in v1_exit_rows["repo-count-band-10-30"]["actual_value"]:
    raise SystemExit("v53t v1 exit repo band should expose repo_count=10")
if "query_rows=1000" not in v1_exit_rows["query-row-band-1000-3000"]["actual_value"]:
    raise SystemExit("v53t v1 exit query band should expose query_rows=1000")
if "holdout_query_rows=200" not in v1_exit_rows["unseen-repository-split-ready"]["actual_value"]:
    raise SystemExit("v53t v1 exit unseen split should expose 200 heldout query rows")
if "negative_abstain_rows=160" not in v1_exit_rows["negative-abstain-and-control-families"]["actual_value"]:
    raise SystemExit("v53t v1 exit controls should expose 160 negative/abstain rows")
if "public_comparison_claim_ready=0" not in v1_exit_rows["abgh-same-query-internal-prebaseline"]["actual_value"]:
    raise SystemExit("v53t v1 exit A/B/G/H row should keep public comparison blocked")
if "public_real_system_performance_claim_ready=0" not in v1_exit_rows["claim-boundary-replay-blocker-gate"]["actual_value"]:
    raise SystemExit("v53t v1 exit claim gate should keep public real system performance blocked")
if "forbids v53-ready" not in v1_exit_rows["claim-boundary-replay-blocker-gate"]["claim_boundary"]:
    raise SystemExit("v53t v1 exit claim boundary should forbid v53-ready wording")

real_adapter_freeze_rows = {row["criterion_id"]: row for row in read_csv(run_dir / "complete_source_abgh_real_adapter_freeze_rows.csv")}
if len(real_adapter_freeze_rows) != 4:
    raise SystemExit("v53t real-adapter freeze row count mismatch")
for criterion_id in [
    "v53aq-same-query-surface",
    "question-only-selection-contract",
    "real-adapter-execution-rows",
    "public-comparison-boundary-closed",
]:
    if real_adapter_freeze_rows[criterion_id]["status"] != "pass":
        raise SystemExit(f"v53t real-adapter freeze criterion should pass: {criterion_id}")
if "same_query_hash=1" not in real_adapter_freeze_rows["v53aq-same-query-surface"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should bind the same v53i query hash")
if "same_query_ledger_ready=1" not in real_adapter_freeze_rows["v53aq-same-query-surface"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose same-query ledger readiness")
if "internal_contract_ready=1" not in real_adapter_freeze_rows["v53aq-same-query-surface"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose per-system internal contract readiness")
if "internal_contract_rows=4" not in real_adapter_freeze_rows["v53aq-same-query-surface"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose four per-system internal contract rows")
if real_adapter_freeze_rows["v53aq-same-query-surface"]["evidence_path"] != "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv":
    raise SystemExit("v53t real-adapter same-query evidence should point at the direct per-query ledger")
if "selection_question_text_only=1" not in real_adapter_freeze_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose question-only selection")
if "selection_sanitized_question_only=1" not in real_adapter_freeze_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose sanitized-question selection")
if "source_locator_in_question_removed_rows=4000" not in real_adapter_freeze_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose source-locator removal")
if "coherent_wrong_key_rows=3924" not in real_adapter_freeze_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose coherent wrong-key evidence")
if "internal_real_adapter_metric_claim_ready=1" not in real_adapter_freeze_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose internal real-adapter metric readiness")
if "public_real_system_performance_claim_ready=0" not in real_adapter_freeze_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should keep public real-system performance claims blocked")
if "public_real_system_performance_claim_ready=0" not in real_adapter_freeze_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v53t real-adapter public boundary should expose public performance claim blocking")
if "public_comparison_claim_ready=0" not in real_adapter_freeze_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should keep public comparison blocked")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "complete_source_audit_claim_rows.csv")}
if claims["complete-source-machine-surface"] != "allowed-limited":
    raise SystemExit("v53t should allow only limited machine-surface wording")
if claims["pm-v53-freeze"] != "allowed-limited":
    raise SystemExit("v53t should allow limited PM v53 freeze wording")
for claim_id in ["human-reviewed-complete-source-audit", "30b-150b-quality-comparison", "v53-ready", "release-ready"]:
    if claims[claim_id] != "blocked":
        raise SystemExit(f"v53t claim should be blocked: {claim_id}")

metric = read_csv(run_dir / "complete_source_audit_readiness_metric_rows.csv")[0]
for field, value in expected.items():
    if field.startswith("v53t_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53t metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53i-complete-source-query-input",
    "v53ap-abgh-same-query-input",
    "v53aq-abgh-real-adapter-input",
    "v53q-core-scorer-policy-input",
    "v53r-review-packet-input",
    "machine-complete-source-surface",
    "unseen-repository-split",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53t gate should pass: {gate}")
for gate in [
    "v52y-f-final-policy-input",
    "v53s-review-return-input",
    "human-reviewed-audit",
    "quality-comparison-claim",
    "v53-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53t gate should stay blocked: {gate}")
if decisions.get("pm-v53-freeze") != "pass":
    raise SystemExit("v53t PM freeze gate should pass")

boundary = (run_dir / "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v52y_f_optional_final_policy_ready=0",
    "v52y_dependency_blocker_ready=1",
    "f_optional_final_disposition_ready=0",
    "f_optional_final_disposition=blocked-by-v52y-dependency",
    "complete_source_repo_count=10",
    "complete_source_query_rows=1000",
    "core_answer_rows=7000",
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "machine_complete_source_surface_ready=1",
    "review_return_ready=0",
    "quality_comparison_claim_ready=0",
    "v53_ready=0",
    "pm_v53_freeze_ready=1",
    "pm_freeze_check_rows=11",
    "pm_freeze_blocked_rows=0",
    "foundation_freeze_certificate_rows=11",
    "pm_acceptance_evidence_rows=11",
    "pm_acceptance_evidence_ready_rows=11",
    "pm_acceptance_evidence_tests_only_rows=0",
    "v1_exit_criteria_rows=7",
    "v1_exit_criteria_ready_rows=7",
    "v1_exit_criteria_blocked_rows=0",
    "v1_exit_repo_count_within_band=1",
    "v1_exit_query_rows_within_band=1",
    "v1_exit_negative_control_share_ready=1",
    "v1_exit_machine_foundation_ready=1",
    "foundation_machine_freeze_ready=1",
    "foundation_direct_evidence_ready=1",
    "foundation_query_span_binding_audit_ready=1",
    "foundation_query_span_binding_audit_rows=1000",
    "foundation_query_span_binding_pass_rows=1000",
    "foundation_query_span_binding_blocked_rows=0",
    "unseen_repository_split_ready=1",
    "unseen_repository_split_rows=10",
    "unseen_repository_split_pass_rows=10",
    "unseen_repository_holdout_repo_rows=2",
    "unseen_repository_calibration_repo_rows=8",
    "unseen_repository_holdout_query_rows=200",
    "unseen_repository_calibration_query_rows=800",
    "unseen_repository_split_query_rows=1000",
    "foundation_direct_pinned_manifest_ready=1",
    "foundation_direct_repo_manifest_ready=1",
    "foundation_direct_content_snapshot_ready=1",
    "foundation_direct_repo_manifest_rows=10",
    "foundation_direct_file_manifest_rows=11266",
    "foundation_direct_content_repo_rows=10",
    "foundation_direct_content_snapshot_rows=11266",
    "foundation_real_adapter_freeze_rows=4",
    "foundation_real_adapter_evidence_ready=1",
    "foundation_real_adapter_same_query_rows_ready=1",
    "foundation_real_adapter_same_query_ledger_ready=1",
    "foundation_real_adapter_same_query_ledger_rows=1000",
    "foundation_real_adapter_internal_contract_ready=1",
    "foundation_real_adapter_internal_contract_rows=4",
    "foundation_real_adapter_internal_contract_ready_rows=4",
    "foundation_real_adapter_evaluator_rows=4000",
    "foundation_real_adapter_evaluator_separate_rows=4000",
    "v53aq_question_only_selection_contract_ready=1",
    "v53aq_same_complete_source_query_hash=1",
    "foundation_direct_query_rows=1000",
    "foundation_direct_span_rows=1000",
    "foundation_direct_abgh_evaluator_rows=4000",
    "foundation_direct_evaluator_separate_rows=4000",
    "foundation_direct_same_query_rows_ready=1",
    "negative_abstain_rows=160",
    "unsupported_control_rows=100",
    "ambiguous_control_rows=30",
    "missing_specific_control_rows=30",
    "doc_code_conflict_rows=140",
    "same_complete_source_query_hash=1",
    "abgh_same_query_ready=1",
    "v53ap_expected_answer_oracle_replay=0",
    "v53ap_deterministic_source_span_adapter_execution=1",
    "v53ap_deterministic_source_span_adapter_rows=4000",
    "v53ap_actual_adapter_execution_ready=1",
    "v53ap_real_system_performance_claim_ready=0",
    "v53aq_selection_question_text_only=1",
    "v53aq_selection_oracle_field_used=0",
    "v53aq_expected_answer_oracle_replay=0",
    "v53aq_deterministic_source_span_adapter_execution=0",
    "v53aq_actual_adapter_execution_ready=1",
    "v53aq_real_adapter_execution_ready=1",
    "v53aq_internal_real_adapter_metric_claim_ready=1",
    "v53aq_public_real_system_performance_claim_ready=0",
    "v53aq_answer_hash_match_rows=76",
    "v53aq_coherent_wrong_key_rows=3924",
    "v53aq_selection_sanitized_question_only=1",
    "v53aq_source_locator_in_question_removed_rows=4000",
    "v53aq_selection_runtime_guard_passed_rows=4000",
    "v53aq_public_comparison_claim_ready=0",
    "v1_0_comparison_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53t boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53t_complete_source_audit_readiness_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53t_complete_source_audit_readiness_gate_ready") != 1:
    raise SystemExit("v53t manifest readiness mismatch")
if (
    manifest.get("v52y_f_optional_final_policy_ready") != 0
    or manifest.get("v52y_dependency_blocker_ready") != 1
    or manifest.get("f_optional_final_disposition_ready") != 0
    or manifest.get("f_optional_final_disposition") != "blocked-by-v52y-dependency"
):
    raise SystemExit("v53t manifest should preserve the v52y dependency blocker without blocking v53 machine freeze")
if manifest.get("machine_complete_source_surface_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53t manifest boundary mismatch")
if manifest.get("pm_v53_freeze_ready") != 1 or manifest.get("pm_freeze_blocked_rows") != 0:
    raise SystemExit("v53t manifest PM freeze boundary mismatch")
if manifest.get("foundation_freeze_certificate_rows") != 11 or manifest.get("foundation_freeze_blocked_rows") != 0:
    raise SystemExit("v53t manifest foundation freeze row mismatch")
if (
    manifest.get("pm_acceptance_evidence_rows") != 11
    or manifest.get("pm_acceptance_evidence_ready_rows") != 11
    or manifest.get("pm_acceptance_evidence_replay_pass_rows") != 11
    or manifest.get("pm_acceptance_evidence_blocker_pass_rows") != 11
    or manifest.get("pm_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("pm_acceptance_evidence_rows_sha256") != sha256(run_dir / "complete_source_pm_acceptance_evidence_rows.csv")
):
    raise SystemExit("v53t manifest PM acceptance evidence mismatch")
if (
    manifest.get("v1_exit_criteria_rows") != 7
    or manifest.get("v1_exit_criteria_ready_rows") != 7
    or manifest.get("v1_exit_criteria_blocked_rows") != 0
    or manifest.get("v1_exit_repo_count_within_band") != 1
    or manifest.get("v1_exit_query_rows_within_band") != 1
    or manifest.get("v1_exit_negative_control_share_ready") != 1
    or manifest.get("v1_exit_machine_foundation_ready") != 1
    or manifest.get("v1_exit_criteria_rows_sha256") != sha256(run_dir / "complete_source_v1_exit_criteria_rows.csv")
):
    raise SystemExit("v53t manifest v1 exit criteria mismatch")
if (
    manifest.get("v53ap_expected_answer_oracle_replay") != 0
    or manifest.get("v53ap_deterministic_source_span_adapter_execution") != 1
    or manifest.get("v53ap_deterministic_source_span_adapter_rows") != 4000
    or manifest.get("v53ap_actual_adapter_execution_ready") != 1
):
    raise SystemExit("v53t manifest v53ap deterministic adapter boundary mismatch")
if manifest.get("foundation_machine_freeze_ready") != 1:
    raise SystemExit("v53t manifest foundation machine freeze mismatch")
if manifest.get("foundation_direct_evidence_ready") != 1:
    raise SystemExit("v53t manifest should record direct foundation evidence readiness")
if (
    manifest.get("foundation_query_span_binding_audit_ready") != 1
    or manifest.get("foundation_query_span_binding_audit_rows") != 1000
    or manifest.get("foundation_query_span_binding_pass_rows") != 1000
    or manifest.get("foundation_query_span_binding_blocked_rows") != 0
):
    raise SystemExit("v53t manifest query-span binding audit mismatch")
if (
    manifest.get("unseen_repository_split_ready") != 1
    or manifest.get("unseen_repository_split_rows") != 10
    or manifest.get("unseen_repository_split_pass_rows") != 10
    or manifest.get("unseen_repository_holdout_repo_rows") != 2
    or manifest.get("unseen_repository_calibration_repo_rows") != 8
    or manifest.get("unseen_repository_holdout_query_rows") != 200
    or manifest.get("unseen_repository_calibration_query_rows") != 800
    or manifest.get("unseen_repository_split_query_rows") != 1000
    or manifest.get("unseen_repository_split_rows_sha256") != sha256(run_dir / "complete_source_unseen_repository_split_rows.csv")
):
    raise SystemExit("v53t manifest unseen repository split mismatch")
if (
    manifest.get("foundation_direct_pinned_manifest_ready") != 1
    or manifest.get("foundation_direct_repo_manifest_ready") != 1
    or manifest.get("foundation_direct_content_snapshot_ready") != 1
    or manifest.get("foundation_direct_repo_manifest_rows") != 10
    or manifest.get("foundation_direct_file_manifest_rows") != 11266
    or manifest.get("foundation_direct_content_repo_rows") != 10
    or manifest.get("foundation_direct_content_snapshot_rows") != 11266
):
    raise SystemExit("v53t manifest direct pinned manifest evidence mismatch")
if (
    manifest.get("foundation_real_adapter_freeze_rows") != 4
    or manifest.get("foundation_real_adapter_freeze_blocked_rows") != 0
    or manifest.get("foundation_real_adapter_evidence_ready") != 1
    or manifest.get("foundation_real_adapter_same_query_rows_ready") != 1
    or manifest.get("foundation_real_adapter_same_query_ledger_ready") != 1
    or manifest.get("foundation_real_adapter_same_query_ledger_rows") != 1000
    or manifest.get("foundation_real_adapter_internal_contract_ready") != 1
    or manifest.get("foundation_real_adapter_internal_contract_rows") != 4
    or manifest.get("foundation_real_adapter_internal_contract_ready_rows") != 4
    or manifest.get("foundation_real_adapter_evaluator_rows") != 4000
    or manifest.get("foundation_real_adapter_evaluator_separate_rows") != 4000
    or manifest.get("v53aq_question_only_selection_contract_ready") != 1
    or manifest.get("v53aq_same_complete_source_query_hash") != 1
):
    raise SystemExit("v53t manifest real-adapter freeze mismatch")
if (
    manifest.get("foundation_direct_query_rows") != 1000
    or manifest.get("foundation_direct_span_rows") != 1000
    or manifest.get("foundation_direct_abgh_evaluator_rows") != 4000
    or manifest.get("foundation_direct_evaluator_separate_rows") != 4000
    or manifest.get("foundation_direct_same_query_rows_ready") != 1
):
    raise SystemExit("v53t manifest direct foundation row counts mismatch")
if (
    manifest.get("negative_abstain_rows") != 160
    or manifest.get("unsupported_control_rows") != 100
    or manifest.get("ambiguous_control_rows") != 30
    or manifest.get("missing_specific_control_rows") != 30
    or manifest.get("doc_code_conflict_rows") != 140
    or manifest.get("abgh_same_query_ready") != 1
):
    raise SystemExit("v53t manifest PM freeze evidence mismatch")
if manifest.get("same_complete_source_query_hash") != 1:
    raise SystemExit("v53t manifest query hash binding mismatch")
if (
    manifest.get("v53aq_selection_question_text_only") != 1
    or manifest.get("v53aq_selection_oracle_field_used") != 0
    or manifest.get("v53aq_expected_answer_oracle_replay") != 0
    or manifest.get("v53aq_deterministic_source_span_adapter_execution") != 0
    or manifest.get("v53aq_actual_adapter_execution_ready") != 1
    or manifest.get("v53aq_real_adapter_execution_ready") != 1
    or manifest.get("v53aq_internal_real_adapter_metric_claim_ready") != 1
    or manifest.get("v53aq_public_real_system_performance_claim_ready") != 0
    or manifest.get("v53aq_answer_hash_match_rows") != 76
    or manifest.get("v53aq_coherent_wrong_key_rows") != 3924
    or manifest.get("v53aq_selection_sanitized_question_only") != 1
    or manifest.get("v53aq_source_locator_in_question_removed_rows") != 4000
    or manifest.get("v53aq_selection_runtime_guard_passed_rows") != 4000
    or manifest.get("v53aq_public_comparison_claim_ready") != 0
):
    raise SystemExit("v53t manifest v53aq real-adapter boundary mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53t sha256 mismatch: {rel}")
PY

echo "v53t complete-source audit readiness gate smoke passed"
