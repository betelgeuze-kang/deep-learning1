#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate_decision.csv"
FIXTURE_LABEL_CSV="$RESULTS_DIR/v10_h10_real_label_fixture_evidence.csv"
SPOOFED_LABEL_CSV="$RESULTS_DIR/v10_h10_real_label_spoofed_fixture_evidence.csv"
MALFORMED_LABEL_CSV="$RESULTS_DIR/v10_h10_real_label_malformed_evidence.csv"

"$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

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
    "v10_h10_real_label_promotion_readiness_gate_ready": "1",
    "h10_real_label_promotion_ready": "0",
    "h10_source_verified_eval_ready": "0",
    "h10_diagnostic_scorer_signal_ready": "1",
    "source_provenance_binding_ready": "1",
    "v53ap_adapter_trace_provenance_ready": "1",
    "v53ap_adapter_trace_rows": "4000",
    "v53ap_evaluator_provenance_ready": "1",
    "v53ap_evaluator_rows": "4000",
    "v53ap_same_evaluator_contract_ready": "1",
    "v53ap_same_resource_contract_ready": "1",
    "v53ap_system_distinct_adapter_trace_ready": "1",
    "v53aq_real_adapter_provenance_ready": "1",
    "v53aq_wrong_key_signal_ready": "1",
    "v53aq_adapter_trace_rows": "4000",
    "v53aq_evaluator_rows": "4000",
    "v53aq_same_query_internal_prebaseline_rows": "1000",
    "v53aq_same_query_internal_prebaseline_rows_ready": "1",
    "v53aq_selection_question_text_only": "1",
    "v53aq_selection_oracle_field_used": "0",
    "v53aq_expected_answer_oracle_replay": "0",
    "v53aq_deterministic_source_span_adapter_execution": "0",
    "v53aq_real_adapter_execution_ready": "1",
    "v53aq_real_system_performance_claim_ready": "0",
    "v53aq_internal_real_adapter_metric_claim_ready": "1",
    "v53aq_public_real_system_performance_claim_ready": "0",
    "v53aq_answer_hash_match_rows": "3713",
    "v53aq_coherent_wrong_key_rows": "287",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v53t_foundation_real_adapter_evidence_ready": "1",
    "v53t_real_adapter_freeze_rows": "4",
    "v53t_real_adapter_freeze_pass_rows": "4",
    "v53t_real_adapter_freeze_ready": "1",
    "missing_query_abstain_ready": "1",
    "wrong_answer_guard_ready": "1",
    "same_query_abgh_ready": "1",
    "same_query_real_adapter_ready": "1",
    "external_human_label_evidence_ready": "0",
    "supplied_real_label_evidence_rows": "0",
    "accepted_real_label_evidence_rows": "0",
    "fixture_or_synthetic_label_evidence_rows": "0",
    "accepted_label_rows": "0",
    "accepted_query_rows_declared": "0",
    "accepted_coherent_wrong_key_labels": "0",
    "accepted_chunk_exact_labels": "0",
    "accepted_near_miss_labels": "0",
    "accepted_missing_query_labels": "0",
    "accepted_source_provenance_labels": "0",
    "h10_real_label_return_contract_rows": "6",
    "h10_real_label_return_contract_ready_rows": "6",
    "h10_real_label_return_contract_fixture_allowed_rows": "0",
    "h10_real_label_return_contract_approval_rows": "6",
    "h10_real_label_return_contract_pass_rows": "0",
    "h10_real_label_acceptance_evidence_rows": "6",
    "h10_real_label_acceptance_evidence_ready_rows": "6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows": "0",
    "h10_real_label_acceptance_evidence_tests_only_rows": "0",
    "h10_real_label_acceptance_evidence_fixture_allowed_rows": "0",
    "h10_real_label_acceptance_evidence_approval_rows": "6",
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "v53aq_complete_source_abgh_real_adapter_measured_ready": "1",
    "v54c_complete_source_grounded_generation_1000_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"h10 real-label PM gate {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "pm_h10_real_label_acceptance_rows.csv",
    "h10_real_label_evidence_template.csv",
    "h10_real_label_evidence_acceptance_rows.csv",
    "h10_real_label_return_contract_rows.csv",
    "h10_real_label_acceptance_evidence_rows.csv",
    "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md",
    "v10_h10_real_label_promotion_readiness_manifest.json",
    "sha256_manifest.csv",
    "source_h10s/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_summary.csv",
    "source_v53q/symmetric_system_metric_rows.csv",
    "source_v53ap/abgh_system_metric_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53aq/adapter_selection_contract_rows.csv",
    "source_v53aq/abgh_system_metric_rows.csv",
    "source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v53aq/abgh_evaluator_rows.csv",
    "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v53aq/abgh_wrong_answer_guard_rows.csv",
    "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v54c/wrong_answer_guard_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing h10 real-label gate artifact: {rel}")

criteria = {row["criterion"]: row for row in read_csv(run_dir / "pm_h10_real_label_acceptance_rows.csv")}
for criterion in [
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
]:
    if criterion not in criteria:
        raise SystemExit(f"missing PM h10 criterion: {criterion}")
if criteria["source-provenance-binding"]["machine_evidence_status"] != "pass":
    raise SystemExit("source provenance should be machine-bound")
if "v53aq_coherent_wrong_key_rows=287" not in criteria["coherent-wrong-key-reduction"]["evidence"]:
    raise SystemExit("coherent wrong-key criterion should cite v53aq wrong-key evidence")
if "v53aq_H_coherent_wrong_key_rows=0" not in criteria["coherent-wrong-key-reduction"]["evidence"]:
    raise SystemExit("coherent wrong-key criterion should cite v53aq H wrong-key evidence")
if "v53t_real_adapter_freeze_ready=1" not in criteria["coherent-wrong-key-reduction"]["evidence"]:
    raise SystemExit("coherent wrong-key criterion should cite v53t real-adapter freeze readiness")
if "v53ap_adapter_trace_rows=4000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53ap adapter trace rows")
if "v53ap_evaluator_rows=4000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53ap evaluator rows")
if "v53aq_adapter_trace_rows=4000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53aq adapter trace rows")
if "v53aq_evaluator_rows=4000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53aq evaluator rows")
if "v53aq_same_query_internal_prebaseline_rows=1000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53aq same-query prebaseline rows")
if "v53aq_same_query_internal_prebaseline_rows_ready=1" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53aq same-query prebaseline readiness")
if "v53t_real_adapter_freeze_rows=4" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53t real-adapter freeze rows")
if criteria["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("external/human label evidence should remain blocked by default")

return_contract_rows = {
    row["criterion"]: row
    for row in read_csv(run_dir / "h10_real_label_return_contract_rows.csv")
}
if set(return_contract_rows) != set(criteria):
    raise SystemExit("h10 return contract should cover exactly the six PM h10 criteria")
for criterion, row in return_contract_rows.items():
    if row["template_path"] != "h10_real_label_evidence_template.csv":
        raise SystemExit(f"h10 return contract should bind {criterion} to the shared evidence template")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1" or row["contract_ready"] != "1":
        raise SystemExit(f"h10 return contract should be no-fixture approval-required and ready for {criterion}")
    if row["acceptance_status"] != "blocked":
        raise SystemExit(f"h10 return contract should remain blocked by default for {criterion}")
for criterion, evidence_column in {
    "coherent-wrong-key-reduction": "coherent_wrong_key_labels",
    "chunk-exact-increase": "chunk_exact_labels",
    "near-miss-slash": "near_miss_labels",
    "missing-query-abstain": "missing_query_labels",
    "source-provenance-binding": "source_provenance_labels",
    "external-human-label-evidence": "human_reviewed; external_source_verified; non_fixture_declared",
}.items():
    if return_contract_rows[criterion]["evidence_column"] != evidence_column:
        raise SystemExit(f"h10 return contract evidence column mismatch for {criterion}")
if "v53aq_wrong_key_signal_ready=1" not in return_contract_rows["coherent-wrong-key-reduction"]["machine_evidence_dependency"]:
    raise SystemExit("h10 coherent wrong-key return contract should cite v53aq wrong-key machine dependency")
if "source_provenance_binding_ready=1" not in return_contract_rows["source-provenance-binding"]["machine_evidence_dependency"]:
    raise SystemExit("h10 source provenance return contract should cite machine provenance readiness")
if "query_rows>=1000" not in return_contract_rows["external-human-label-evidence"]["external_label_dependency"]:
    raise SystemExit("h10 external label return contract should require 1000 query rows")

acceptance_evidence_rows = {
    row["criterion"]: row
    for row in read_csv(run_dir / "h10_real_label_acceptance_evidence_rows.csv")
}
if set(acceptance_evidence_rows) != set(criteria):
    raise SystemExit("h10 acceptance evidence ledger should cover exactly the six PM h10 criteria")
for criterion, row in acceptance_evidence_rows.items():
    if row["claim_boundary_status"] != "pass":
        raise SystemExit(f"h10 acceptance evidence should pass claim boundary for {criterion}")
    if row["output_artifact_replay_status"] != "pass":
        raise SystemExit(f"h10 acceptance evidence should pass artifact replay for {criterion}")
    if row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"h10 acceptance evidence should pass blocker false-positive closure for {criterion}")
    if row["pm_acceptance_row_path"] != "pm_h10_real_label_acceptance_rows.csv":
        raise SystemExit(f"h10 acceptance evidence should bind PM acceptance rows for {criterion}")
    if row["pm_acceptance_row_count"] != "6":
        raise SystemExit(f"h10 acceptance evidence should record six PM acceptance rows for {criterion}")
    if row["pm_acceptance_sha256"] != sha256(run_dir / "pm_h10_real_label_acceptance_rows.csv"):
        raise SystemExit(f"h10 acceptance evidence PM acceptance sha mismatch for {criterion}")
    if row["return_contract_path"] != "h10_real_label_return_contract_rows.csv":
        raise SystemExit(f"h10 acceptance evidence should bind return contract rows for {criterion}")
    if row["return_contract_row_count"] != "6":
        raise SystemExit(f"h10 acceptance evidence should record six return contract rows for {criterion}")
    if row["return_contract_sha256"] != sha256(run_dir / "h10_real_label_return_contract_rows.csv"):
        raise SystemExit(f"h10 acceptance evidence return contract sha mismatch for {criterion}")
    if row["evidence_template_path"] != "h10_real_label_evidence_template.csv":
        raise SystemExit(f"h10 acceptance evidence should bind the evidence template for {criterion}")
    if row["evidence_acceptance_path"] != "h10_real_label_evidence_acceptance_rows.csv":
        raise SystemExit(f"h10 acceptance evidence should bind evidence acceptance rows for {criterion}")
    if row["accepted_real_label_evidence_rows"] != "0":
        raise SystemExit(f"h10 acceptance evidence should record zero accepted real-label evidence rows for {criterion}")
    if row["accepted_query_rows_declared"] != "0" or row["accepted_label_rows"] != "0":
        raise SystemExit(f"h10 acceptance evidence should record zero accepted query/label rows for {criterion}")
    if row["accepted_criterion_label_count"] != "0":
        raise SystemExit(f"h10 acceptance evidence should record zero criterion label coverage for {criterion}")
    if row["criterion_label_coverage_status"] != "blocked":
        raise SystemExit(f"h10 acceptance evidence should block criterion label coverage without accepted labels for {criterion}")
    if row["source_verified_eval_status"] != "blocked":
        raise SystemExit(f"h10 acceptance evidence should keep source-verified eval blocked for {criterion}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"h10 acceptance evidence should preserve no-fixture approval-required boundary for {criterion}")
    if row["contract_ready"] != "1" or row["acceptance_ready"] != "1":
        raise SystemExit(f"h10 acceptance evidence should keep the PM contract ready for {criterion}")
    if row["promotion_ready"] != "0":
        raise SystemExit(f"h10 acceptance evidence should keep promotion blocked without labels for {criterion}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"h10 acceptance evidence should reject tests-only merge condition for {criterion}")
    if row["replay_command"] != "experiments/test_v10_h10_real_label_promotion_readiness_gate.sh":
        raise SystemExit(f"h10 acceptance evidence should record the replay command for {criterion}")
    if "readiness ledger only" not in row["claim_boundary"]:
        raise SystemExit(f"h10 acceptance evidence should keep a readiness-only claim boundary for {criterion}")
if acceptance_evidence_rows["source-provenance-binding"]["machine_evidence_status"] != "pass":
    raise SystemExit("h10 acceptance evidence should preserve source provenance machine pass status")
if acceptance_evidence_rows["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("h10 acceptance evidence should keep external/human label evidence blocked")

adapter_traces = read_csv(run_dir / "source_v53ap/abgh_adapter_trace_rows.csv")
evaluators = read_csv(run_dir / "source_v53ap/abgh_evaluator_rows.csv")
if len(adapter_traces) != 4000:
    raise SystemExit("h10 PM gate should copy 4000 v53ap adapter trace rows")
if {row["system_id"] for row in adapter_traces} != {"A", "B", "G", "H"}:
    raise SystemExit("h10 PM gate v53ap adapter traces should cover A/B/G/H")
if any(row["source_span_binding_match"] != "1" or row["expected_answer_oracle_replay"] != "0" for row in adapter_traces):
    raise SystemExit("h10 PM gate v53ap adapter traces should preserve provenance/non-oracle boundary")
if len(evaluators) != 4000:
    raise SystemExit("h10 PM gate should copy 4000 v53ap evaluator rows")
if {row["system_id"] for row in evaluators} != {"A", "B", "G", "H"}:
    raise SystemExit("h10 PM gate v53ap evaluator rows should cover A/B/G/H")
if {row["evaluator_contract_id"] for row in evaluators} != {"v53ap-source-bound-answer-citation-resource-v1"}:
    raise SystemExit("h10 PM gate v53ap evaluator rows should share the v53ap evaluator contract")
if any(
    row["answer_eval_separate"] != "1"
    or row["citation_eval_separate"] != "1"
    or row["resource_eval_separate"] != "1"
    or row["source_span_binding_match"] != "1"
    or row["expected_answer_oracle_replay"] != "0"
    or row["real_system_performance_claim_ready"] != "0"
    for row in evaluators
):
    raise SystemExit("h10 PM gate v53ap evaluator rows should preserve separate source-bound non-oracle evaluation")

v53aq_adapter_traces = read_csv(run_dir / "source_v53aq/abgh_adapter_trace_rows.csv")
v53aq_evaluators = read_csv(run_dir / "source_v53aq/abgh_evaluator_rows.csv")
if len(v53aq_adapter_traces) != 4000:
    raise SystemExit("h10 PM gate should copy 4000 v53aq adapter trace rows")
if {row["system_id"] for row in v53aq_adapter_traces} != {"A", "B", "G", "H"}:
    raise SystemExit("h10 PM gate v53aq adapter traces should cover A/B/G/H")
if any(
    row["selection_question_text_used"] != "1"
    or row["selection_oracle_field_used"] != "0"
    or row["expected_answer_oracle_replay"] != "0"
    or row["deterministic_source_span_adapter_execution"] != "0"
    for row in v53aq_adapter_traces
):
    raise SystemExit("h10 PM gate v53aq adapter traces should preserve query-text-only non-oracle selection")
if len(v53aq_evaluators) != 4000:
    raise SystemExit("h10 PM gate should copy 4000 v53aq evaluator rows")
if {row["system_id"] for row in v53aq_evaluators} != {"A", "B", "G", "H"}:
    raise SystemExit("h10 PM gate v53aq evaluator rows should cover A/B/G/H")
if {row["evaluator_contract_id"] for row in v53aq_evaluators} != {"v53aq-query-text-only-answer-citation-resource-v1"}:
    raise SystemExit("h10 PM gate v53aq evaluator rows should share the v53aq evaluator contract")
if any(
    row["answer_eval_separate"] != "1"
    or row["citation_eval_separate"] != "1"
    or row["resource_eval_separate"] != "1"
    or row["selection_question_text_only"] != "1"
    or row["selection_oracle_field_used"] != "0"
    or row["expected_answer_oracle_replay"] != "0"
    or row["deterministic_source_span_adapter_execution"] != "0"
    or row["real_system_performance_claim_ready"] != "0"
    or row["internal_real_adapter_metric_claim_ready"] != "1"
    or row["public_real_system_performance_claim_ready"] != "0"
    for row in v53aq_evaluators
):
    raise SystemExit("h10 PM gate v53aq evaluator rows should preserve real-adapter separate evaluation")

v53aq_prebaseline_rows = read_csv(run_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
if len(v53aq_prebaseline_rows) != 1000:
    raise SystemExit("h10 PM gate should copy 1000 v53aq same-query internal prebaseline rows")
if {row["systems"] for row in v53aq_prebaseline_rows} != {"A/B/G/H"}:
    raise SystemExit("h10 PM gate v53aq same-query ledger should cover A/B/G/H")
for row in v53aq_prebaseline_rows:
    expected = {
        "answer_row_count": "4",
        "citation_row_count": "4",
        "evaluator_row_count": "4",
        "resource_row_count": "4",
        "adapter_trace_row_count": "4",
        "same_query_all_systems": "1",
        "same_evaluator_contract": "1",
        "same_resource_bound": "1",
        "selection_question_text_only_all": "1",
        "selection_oracle_field_used_any": "0",
        "expected_answer_oracle_replay_any": "0",
        "deterministic_source_span_adapter_execution_any": "0",
        "g_h_routehint_no_raw_context": "1",
        "public_comparison_claim_ready": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
    }
    for field, value in expected.items():
        if row[field] != value:
            raise SystemExit(f"h10 PM gate v53aq same-query ledger should preserve {field}={value}")

v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(v53t_real_adapter_rows) != 4:
    raise SystemExit("h10 PM gate should copy four v53t real-adapter freeze rows")
if any(row["status"] != "pass" for row in v53t_real_adapter_rows.values()):
    raise SystemExit("h10 PM gate v53t real-adapter freeze rows should all pass")
if "coherent_wrong_key_rows=287" not in v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("h10 PM gate v53t real-adapter freeze should preserve coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("h10 PM gate v53t real-adapter freeze should preserve public comparison blocker")
if "selection_question_text_only=1" not in v53t_real_adapter_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("h10 PM gate v53t real-adapter freeze should preserve question-only selection")
if "selection_oracle_field_used=0" not in v53t_real_adapter_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("h10 PM gate v53t real-adapter freeze should preserve no-oracle selection")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53-complete-source-symmetric-scorer-policy",
    "v53ap-abgh-same-query-prebaseline",
    "v53aq-abgh-real-adapter-evidence",
    "v53t-real-adapter-freeze",
    "v54c-grounded-generation-guard",
    "h10-diagnostic-scorer-signal",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"h10 PM gate should pass machine evidence gate: {gate}")
for gate in [
    "h10-source-verified-eval",
    "h10-external-human-label-evidence",
    "h10-real-label-promotion",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"h10 PM gate should block: {gate}")

manifest = json.loads((run_dir / "v10_h10_real_label_promotion_readiness_manifest.json").read_text(encoding="utf-8"))
if manifest.get("h10_real_label_promotion_ready") != 0:
    raise SystemExit("manifest must keep h10 real-label promotion blocked")
if manifest.get("source_provenance_binding_ready") != 1 or manifest.get("same_query_abgh_ready") != 1:
    raise SystemExit("manifest should record machine evidence readiness")
if manifest.get("v53ap_adapter_trace_provenance_ready") != 1 or manifest.get("v53ap_adapter_trace_rows") != 4000:
    raise SystemExit("manifest should record v53ap adapter trace provenance readiness")
if manifest.get("v53ap_evaluator_provenance_ready") != 1 or manifest.get("v53ap_evaluator_rows") != 4000:
    raise SystemExit("manifest should record v53ap evaluator provenance readiness")
if manifest.get("v53aq_real_adapter_provenance_ready") != 1 or manifest.get("v53aq_wrong_key_signal_ready") != 1:
    raise SystemExit("manifest should record v53aq real-adapter evidence readiness")
if manifest.get("v53aq_adapter_trace_rows") != 4000 or manifest.get("v53aq_evaluator_rows") != 4000:
    raise SystemExit("manifest should record v53aq provenance row counts")
if manifest.get("v53aq_same_query_internal_prebaseline_rows") != 1000:
    raise SystemExit("manifest should record v53aq same-query prebaseline row count")
if manifest.get("v53aq_same_query_internal_prebaseline_rows_ready") != 1:
    raise SystemExit("manifest should record v53aq same-query prebaseline readiness")
if manifest.get("v53aq_selection_question_text_only") != 1 or manifest.get("v53aq_selection_oracle_field_used") != 0:
    raise SystemExit("manifest should record v53aq query-text-only selection boundary")
if manifest.get("v53t_complete_source_audit_readiness_gate_ready") != 1:
    raise SystemExit("manifest should record v53t audit-readiness gate readiness")
if manifest.get("v53t_foundation_real_adapter_evidence_ready") != 1:
    raise SystemExit("manifest should record v53t foundation real-adapter evidence readiness")
if manifest.get("v53t_real_adapter_freeze_rows") != 4 or manifest.get("v53t_real_adapter_freeze_pass_rows") != 4:
    raise SystemExit("manifest should record v53t real-adapter freeze row counts")
if manifest.get("v53t_real_adapter_freeze_ready") != 1:
    raise SystemExit("manifest should record v53t real-adapter freeze readiness")
if manifest.get("h10_real_label_return_contract_rows") != 6:
    raise SystemExit("manifest should record six h10 real-label return contract rows")
if manifest.get("h10_real_label_return_contract_ready_rows") != 6:
    raise SystemExit("manifest should record six ready h10 real-label return contract rows")
if manifest.get("h10_real_label_return_contract_fixture_allowed_rows") != 0:
    raise SystemExit("manifest should forbid fixture h10 real-label return contracts")
if manifest.get("h10_real_label_return_contract_approval_rows") != 6:
    raise SystemExit("manifest should require approval for all h10 real-label return contracts")
if manifest.get("h10_real_label_return_contract_pass_rows") != 0:
    raise SystemExit("manifest should keep all h10 return contracts blocked without accepted labels")
if manifest.get("h10_real_label_acceptance_evidence_rows") != 6:
    raise SystemExit("manifest should record six h10 acceptance evidence rows")
if manifest.get("h10_real_label_acceptance_evidence_ready_rows") != 6:
    raise SystemExit("manifest should record six ready h10 acceptance evidence rows")
if manifest.get("h10_real_label_acceptance_evidence_promotion_ready_rows") != 0:
    raise SystemExit("manifest should keep h10 acceptance evidence promotion rows blocked")
if manifest.get("h10_real_label_acceptance_evidence_tests_only_rows") != 0:
    raise SystemExit("manifest should forbid tests-only h10 acceptance evidence")
if manifest.get("h10_real_label_acceptance_evidence_fixture_allowed_rows") != 0:
    raise SystemExit("manifest should forbid fixture h10 acceptance evidence")
if manifest.get("h10_real_label_acceptance_evidence_approval_rows") != 6:
    raise SystemExit("manifest should require approval for all h10 acceptance evidence rows")
if manifest.get("h10_real_label_acceptance_evidence_rows_sha256") != sha256(run_dir / "h10_real_label_acceptance_evidence_rows.csv"):
    raise SystemExit("manifest should hash-bind h10 acceptance evidence rows")
for field in [
    "accepted_query_rows_declared",
    "accepted_label_rows",
    "accepted_coherent_wrong_key_labels",
    "accepted_chunk_exact_labels",
    "accepted_near_miss_labels",
    "accepted_missing_query_labels",
    "accepted_source_provenance_labels",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"manifest should keep {field}=0 without accepted labels")
if "v53t" not in manifest.get("source_summary_sha256", {}):
    raise SystemExit("manifest should hash-bind the v53t summary")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"h10 PM gate sha mismatch: {rel}")

boundary = (run_dir / "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "h10_real_label_promotion_ready=0",
    "external_human_label_evidence_ready=0",
    "source_provenance_binding_ready=1",
    "v53ap_adapter_trace_provenance_ready=1",
    "v53ap_adapter_trace_rows=4000",
    "v53ap_evaluator_provenance_ready=1",
    "v53ap_evaluator_rows=4000",
    "v53aq_real_adapter_provenance_ready=1",
    "v53aq_wrong_key_signal_ready=1",
    "v53aq_adapter_trace_rows=4000",
    "v53aq_evaluator_rows=4000",
    "v53aq_same_query_internal_prebaseline_rows=1000",
    "v53aq_same_query_internal_prebaseline_rows_ready=1",
    "v53aq_selection_question_text_only=1",
    "v53aq_selection_oracle_field_used=0",
    "v53aq_coherent_wrong_key_rows=287",
    "v53t_real_adapter_freeze_ready=1",
    "v53t_real_adapter_freeze_rows=4",
    "accepted_query_rows_declared=0",
    "accepted_label_rows=0",
    "accepted_coherent_wrong_key_labels=0",
    "accepted_chunk_exact_labels=0",
    "accepted_near_miss_labels=0",
    "accepted_missing_query_labels=0",
    "accepted_source_provenance_labels=0",
    "h10_real_label_return_contract_rows=6",
    "h10_real_label_return_contract_ready_rows=6",
    "h10_real_label_return_contract_pass_rows=0",
    "h10_real_label_acceptance_evidence_rows=6",
    "h10_real_label_acceptance_evidence_ready_rows=6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows=0",
    "h10_real_label_acceptance_evidence_tests_only_rows=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"h10 PM gate boundary missing: {snippet}")
PY

{
  echo "label_evidence_id,label_scope,label_source,label_source_uri,label_artifact_sha256,reviewer_id,reviewer_conflict_checked,human_reviewed,external_source_verified,non_fixture_declared,fixture_or_synthetic_declared,query_rows,label_rows,coherent_wrong_key_labels,chunk_exact_labels,near_miss_labels,missing_query_labels,source_provenance_labels,acceptance_summary_sha256,routing_trigger_rate,active_jump_rate"
  echo "fixture-001,v53i-1000,fixture-human-return,https://review.invalid/h10.csv,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,reviewer-fixture,1,1,1,0,1,1000,1000,50,1000,50,30,1000,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,0,0"
} >"$FIXTURE_LABEL_CSV"

V10_H10_REAL_LABEL_EVIDENCE_CSV="$FIXTURE_LABEL_CSV" \
  "$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
checks = {
    "supplied_real_label_evidence_rows": "1",
    "accepted_real_label_evidence_rows": "0",
    "rejected_real_label_evidence_rows": "1",
    "fixture_or_synthetic_label_evidence_rows": "1",
    "accepted_label_rows": "0",
    "accepted_query_rows_declared": "0",
    "accepted_coherent_wrong_key_labels": "0",
    "accepted_chunk_exact_labels": "0",
    "accepted_near_miss_labels": "0",
    "accepted_missing_query_labels": "0",
    "accepted_source_provenance_labels": "0",
    "h10_real_label_return_contract_pass_rows": "0",
    "h10_real_label_acceptance_evidence_ready_rows": "6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows": "0",
    "external_human_label_evidence_ready": "0",
    "h10_real_label_promotion_ready": "0",
}
for field, expected in checks.items():
    if summary.get(field) != expected:
        raise SystemExit(f"fixture label evidence should not pass {field}: expected {expected}, got {summary.get(field)}")

rows = read_csv(run_dir / "h10_real_label_evidence_acceptance_rows.csv")
if rows[0]["acceptance_status"] != "rejected" or "non-fixture" not in rows[0]["failed_checks"]:
    raise SystemExit("fixture h10 label row should be rejected by non-fixture check")
ledger = read_csv(run_dir / "h10_real_label_acceptance_evidence_rows.csv")
if any(row["accepted_real_label_evidence_rows"] != "0" or row["criterion_label_coverage_status"] != "blocked" for row in ledger):
    raise SystemExit("fixture h10 label evidence should not open criterion label coverage")
PY

{
  echo "label_evidence_id,label_scope,label_source,label_source_uri,label_artifact_sha256,reviewer_id,reviewer_conflict_checked,human_reviewed,external_source_verified,non_fixture_declared,fixture_or_synthetic_declared,query_rows,label_rows,coherent_wrong_key_labels,chunk_exact_labels,near_miss_labels,missing_query_labels,source_provenance_labels,acceptance_summary_sha256,routing_trigger_rate,active_jump_rate"
  echo "fixture-spoof-001,v53i-1000,fixture-human-return,https://review.invalid/h10.csv,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,reviewer-fixture,1,1,1,1,0,1000,1000,50,1000,50,30,1000,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,0,0"
} >"$SPOOFED_LABEL_CSV"

V10_H10_REAL_LABEL_EVIDENCE_CSV="$SPOOFED_LABEL_CSV" \
  "$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary["supplied_real_label_evidence_rows"] != "1":
    raise SystemExit("spoofed h10 fixture should be supplied")
if summary["accepted_real_label_evidence_rows"] != "0" or summary["external_human_label_evidence_ready"] != "0":
    raise SystemExit("spoofed h10 fixture should not open external/human label readiness")
rows = read_csv(run_dir / "h10_real_label_evidence_acceptance_rows.csv")
failed = rows[0]["failed_checks"].split(";")
for check in ["non-placeholder-sha", "non-placeholder-source"]:
    if check not in failed:
        raise SystemExit(f"spoofed h10 fixture should fail {check}")
PY

{
  echo "label_evidence_id,label_scope,label_source"
  echo "bad-001,v53i-1000,fixture"
} >"$MALFORMED_LABEL_CSV"

if V10_H10_REAL_LABEL_EVIDENCE_CSV="$MALFORMED_LABEL_CSV" \
  "$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null 2>/dev/null; then
  echo "h10 real-label gate should reject malformed supplied evidence CSV" >&2
  exit 50
fi

"$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

echo "v10 h10 real-label promotion readiness gate smoke passed"
