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
    "v52y_f_optional_final_policy_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
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
    "pm_freeze_check_rows": "10",
    "pm_freeze_pass_rows": "10",
    "pm_freeze_blocked_rows": "0",
    "foundation_freeze_certificate_rows": "10",
    "foundation_freeze_pass_rows": "10",
    "foundation_freeze_blocked_rows": "0",
    "foundation_machine_freeze_ready": "1",
    "foundation_direct_evidence_ready": "1",
    "foundation_real_adapter_freeze_rows": "4",
    "foundation_real_adapter_freeze_pass_rows": "4",
    "foundation_real_adapter_freeze_blocked_rows": "0",
    "foundation_real_adapter_evidence_ready": "1",
    "foundation_real_adapter_same_query_rows_ready": "1",
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
    "v53aq_real_system_performance_claim_ready": "1",
    "v53aq_answer_hash_match_rows": "3712",
    "v53aq_coherent_wrong_key_rows": "288",
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
    "complete_source_abgh_real_adapter_freeze_rows.csv",
    "complete_source_audit_claim_rows.csv",
    "complete_source_audit_readiness_metric_rows.csv",
    "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md",
    "v53t_complete_source_audit_readiness_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
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
    "f-optional-final-disposition",
    "complete-source-content-and-query-surface",
    "core-a-b-c-d-e-g-h-answer-citation-resource",
    "symmetric-scorer-policy-surface",
    "review-packet-ready",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53t requirement should pass: {requirement_id}")
for requirement_id in [
    "human-review-return-accepted",
    "adjudication-return-accepted",
    "reviewer-identity-conflict-ready",
    "quality-comparison-claim-ready",
    "release-package-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53t requirement should stay blocked: {requirement_id}")
if len(requirements) != 10:
    raise SystemExit("v53t requirement row count mismatch")

pm_freeze_checks = {row["check_id"]: row for row in read_csv(run_dir / "complete_source_pm_freeze_check_rows.csv")}
if len(pm_freeze_checks) != 10:
    raise SystemExit("v53t PM freeze check row count mismatch")
for check_id in [
    "pinned-public-repo-manifest",
    "source-span-bound-1000",
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

query_rows = read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")
span_rows = read_csv(run_dir / "source_v53i/complete_source_span_rows.csv")
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
v53aq_selection_contract = {row["field_name"]: row for row in read_csv(run_dir / "source_v53aq/adapter_selection_contract_rows.csv")}
if len(query_rows) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v53t should copy direct 1000 query/span rows")
if any(not row["source_span_id"] for row in query_rows):
    raise SystemExit("v53t direct query rows should bind source spans")
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
if v53aq_selection_contract.get("question", {}).get("selection_allowed") != "1":
    raise SystemExit("v53t v53aq selection contract should allow only question text")
for field in ["query_id", "expected_answer", "expected_answer_sha256", "source_span_id", "source_path", "source_line_start", "source_line_end"]:
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
    or row["real_system_performance_claim_ready"] != "1"
    for row in v53aq_evaluators
):
    raise SystemExit("v53t v53aq evaluator rows should preserve question-only real-adapter boundaries")

foundation_freeze_rows = {row["criterion_id"]: row for row in read_csv(run_dir / "complete_source_foundation_freeze_rows.csv")}
if len(foundation_freeze_rows) != 10:
    raise SystemExit("v53t foundation freeze certificate row count mismatch")
for criterion_id in [
    "pinned-public-repo-manifest",
    "source-span-bound-query-surface",
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
if foundation_freeze_rows["source-span-bound-query-surface"]["evidence_path"] != "source_v53i/complete_source_query_rows.csv":
    raise SystemExit("v53t source-span freeze evidence should point at direct query rows")
if foundation_freeze_rows["answer-citation-separated-evaluator"]["evidence_path"] != "source_v53ap/abgh_evaluator_rows.csv":
    raise SystemExit("v53t separated evaluator evidence should point at direct evaluator rows")
if foundation_freeze_rows["abgh-same-query-measured-run"]["evidence_path"] != "source_v53ap/abgh_evaluator_rows.csv":
    raise SystemExit("v53t A/B/G/H same-query evidence should point at direct evaluator rows")
if "real system performance" not in foundation_freeze_rows["abgh-same-query-measured-run"]["claim_boundary"]:
    raise SystemExit("v53t foundation freeze should keep A/B/G/H real system performance boundary closed")
if "forbids public comparison" not in foundation_freeze_rows["public-comparison-boundary-closed"]["claim_boundary"]:
    raise SystemExit("v53t foundation freeze should explicitly forbid public comparison wording")

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
if "selection_question_text_only=1" not in real_adapter_freeze_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose question-only selection")
if "coherent_wrong_key_rows=288" not in real_adapter_freeze_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v53t real-adapter freeze should expose coherent wrong-key evidence")
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
    "v52y-f-final-policy-input",
    "v53i-complete-source-query-input",
    "v53ap-abgh-same-query-input",
    "v53aq-abgh-real-adapter-input",
    "v53q-core-scorer-policy-input",
    "v53r-review-packet-input",
    "machine-complete-source-surface",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53t gate should pass: {gate}")
for gate in [
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
    "f_optional_final_disposition=deferred-with-reason-final",
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
    "pm_freeze_check_rows=10",
    "pm_freeze_blocked_rows=0",
    "foundation_freeze_certificate_rows=10",
    "foundation_machine_freeze_ready=1",
    "foundation_direct_evidence_ready=1",
    "foundation_real_adapter_freeze_rows=4",
    "foundation_real_adapter_evidence_ready=1",
    "foundation_real_adapter_same_query_rows_ready=1",
    "foundation_real_adapter_evaluator_rows=4000",
    "foundation_real_adapter_evaluator_separate_rows=4000",
    "v53aq_question_only_selection_contract_ready=1",
    "v53aq_same_complete_source_query_hash=1",
    "foundation_direct_query_rows=1000",
    "foundation_direct_span_rows=1000",
    "foundation_direct_abgh_evaluator_rows=4000",
    "foundation_direct_evaluator_separate_rows=4000",
    "foundation_direct_same_query_rows_ready=1",
    "unsupported_control_rows=100",
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
    "v53aq_answer_hash_match_rows=3712",
    "v53aq_coherent_wrong_key_rows=288",
    "v53aq_public_comparison_claim_ready=0",
    "v1_0_comparison_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53t boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53t_complete_source_audit_readiness_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53t_complete_source_audit_readiness_gate_ready") != 1:
    raise SystemExit("v53t manifest readiness mismatch")
if manifest.get("machine_complete_source_surface_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53t manifest boundary mismatch")
if manifest.get("pm_v53_freeze_ready") != 1 or manifest.get("pm_freeze_blocked_rows") != 0:
    raise SystemExit("v53t manifest PM freeze boundary mismatch")
if manifest.get("foundation_freeze_certificate_rows") != 10 or manifest.get("foundation_freeze_blocked_rows") != 0:
    raise SystemExit("v53t manifest foundation freeze row mismatch")
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
    manifest.get("foundation_real_adapter_freeze_rows") != 4
    or manifest.get("foundation_real_adapter_freeze_blocked_rows") != 0
    or manifest.get("foundation_real_adapter_evidence_ready") != 1
    or manifest.get("foundation_real_adapter_same_query_rows_ready") != 1
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
if manifest.get("missing_specific_control_rows") != 30 or manifest.get("abgh_same_query_ready") != 1:
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
    or manifest.get("v53aq_answer_hash_match_rows") != 3712
    or manifest.get("v53aq_coherent_wrong_key_rows") != 288
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
