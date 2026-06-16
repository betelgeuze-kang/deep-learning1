#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53aq_complete_source_abgh_real_adapter_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53aq_complete_source_abgh_real_adapter_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53aq_complete_source_abgh_real_adapter_measured_decision.csv"

V53AQ_REUSE_EXISTING="${V53AQ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
SYSTEMS = {"A", "B", "G", "H"}
FORBIDDEN_SELECTION_FIELDS = "query_id,expected_answer,expected_answer_sha256,source_span_id,source_path,source_line_start,source_line_end"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53aq_complete_source_abgh_real_adapter_measured_ready": "1",
    "v53_ready": "0",
    "query_set_id": "v53i_complete_source_1000",
    "system_rows": "4",
    "systems": "A/B/G/H",
    "query_rows": "1000",
    "source_manifest_rows": "497",
    "answer_rows": "4000",
    "citation_rows": "4000",
    "retrieval_rows": "4000",
    "evaluator_rows": "4000",
    "adapter_trace_rows": "4000",
    "abstain_rows": "4000",
    "wrong_answer_guard_rows": "4000",
    "resource_rows": "4000",
    "route_memory_rows": "2000",
    "routehint_rows": "2000",
    "negative_abstain_rows": "160",
    "missing_specific_abstain_rows": "30",
    "same_query_set_all_local_systems": "1",
    "same_source_manifest_all_local_systems": "1",
    "same_evaluator_contract_all_local_systems": "1",
    "same_resource_contract_all_local_systems": "1",
    "answer_hash_match_rows": "3712",
    "citation_location_match_rows": "3712",
    "source_span_id_match_rows": "1857",
    "wrong_answer_rows": "288",
    "coherent_wrong_key_rows": "288",
    "selection_question_text_only": "1",
    "selection_allowed_fields": "question",
    "selection_forbidden_fields": FORBIDDEN_SELECTION_FIELDS,
    "selection_oracle_field_used": "0",
    "source_span_oracle_selection_used": "0",
    "expected_answer_oracle_replay": "0",
    "expected_answer_oracle_replay_rows": "0",
    "deterministic_source_span_adapter_execution": "0",
    "deterministic_source_span_adapter_rows": "0",
    "actual_adapter_execution_ready": "1",
    "real_adapter_execution_ready": "1",
    "real_system_performance_claim_ready": "1",
    "external_network_used": "0",
    "external_model_used": "0",
    "internal_v1_0_pre_baseline_run": "1",
    "quality_comparison_claim_ready": "0",
    "public_comparison_claim_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53aq {field}: expected {value}, got {summary.get(field)}")

if summary["source_query_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_query_rows.csv"):
    raise SystemExit("v53aq query hash should bind source_v53i query rows")
if summary["source_span_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_span_rows.csv"):
    raise SystemExit("v53aq span hash should bind source_v53i span rows")

required_files = [
    "source_manifest_rows.csv",
    "adapter_selection_contract_rows.csv",
    "abgh_system_rows.csv",
    "abgh_answer_rows.csv",
    "abgh_citation_rows.csv",
    "abgh_retrieval_rows.csv",
    "abgh_evaluator_rows.csv",
    "abgh_adapter_trace_rows.csv",
    "abgh_abstain_rows.csv",
    "abgh_wrong_answer_guard_rows.csv",
    "abgh_resource_rows.csv",
    "route_memory_rows.csv",
    "routehint_rows.csv",
    "abgh_system_metric_rows.csv",
    "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "v53aq_complete_source_abgh_real_adapter_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/complete_source_query_family_rows.csv",
    "source_v53i/complete_source_control_family_rows.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53aq artifact: {rel}")

queries = read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")
query_ids = {row["query_id"] for row in queries}
if len(query_ids) != 1000:
    raise SystemExit("v53aq should bind 1000 unique v53i queries")

selection_contract = {row["field_name"]: row for row in read_csv(run_dir / "adapter_selection_contract_rows.csv")}
if selection_contract.get("question", {}).get("selection_allowed") != "1":
    raise SystemExit("v53aq adapter selection must allow question text")
for field in FORBIDDEN_SELECTION_FIELDS.split(","):
    row = selection_contract.get(field)
    if not row or row["selection_allowed"] != "0":
        raise SystemExit(f"v53aq adapter selection must forbid {field}")

system_rows = {row["system_id"]: row for row in read_csv(run_dir / "abgh_system_rows.csv")}
if set(system_rows) != SYSTEMS:
    raise SystemExit("v53aq should cover A/B/G/H systems")
for system_id, row in system_rows.items():
    if row["execution_mode"] != "query-text-only-local-adapter":
        raise SystemExit(f"v53aq execution mode mismatch for {system_id}")
    if row["selection_allowed_fields"] != "question" or row["selection_forbidden_fields"] != FORBIDDEN_SELECTION_FIELDS:
        raise SystemExit(f"v53aq selection contract mismatch for {system_id}")
    for field in [
        "expected_answer_oracle_replay",
        "deterministic_source_span_adapter_execution",
        "selection_oracle_field_used",
        "external_model_used",
        "external_network_used",
    ]:
        if row[field] != "0":
            raise SystemExit(f"v53aq system row should keep {field}=0 for {system_id}")
    if row["actual_adapter_execution_ready"] != "1" or row["real_adapter_execution_ready"] != "1":
        raise SystemExit(f"v53aq real adapter should be ready for {system_id}")

answers = read_csv(run_dir / "abgh_answer_rows.csv")
citations = read_csv(run_dir / "abgh_citation_rows.csv")
retrieval = read_csv(run_dir / "abgh_retrieval_rows.csv")
evaluators = read_csv(run_dir / "abgh_evaluator_rows.csv")
adapter_traces = read_csv(run_dir / "abgh_adapter_trace_rows.csv")
abstain = read_csv(run_dir / "abgh_abstain_rows.csv")
guards = read_csv(run_dir / "abgh_wrong_answer_guard_rows.csv")
resources = read_csv(run_dir / "abgh_resource_rows.csv")
route_memory = read_csv(run_dir / "route_memory_rows.csv")
hints = read_csv(run_dir / "routehint_rows.csv")
metrics = {row["system_id"]: row for row in read_csv(run_dir / "abgh_system_metric_rows.csv")}

for table_name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("retrieval", retrieval),
    ("evaluators", evaluators),
    ("adapter_traces", adapter_traces),
    ("abstain", abstain),
    ("guards", guards),
    ("resources", resources),
]:
    if len(rows) != 4000:
        raise SystemExit(f"v53aq {table_name} row count mismatch")
    for system_id in SYSTEMS:
        if {row["query_id"] for row in rows if row["system_id"] == system_id} != query_ids:
            raise SystemExit(f"v53aq {table_name} should cover every query for {system_id}")

expected_metric_rows = {
    "A": {"answer_hash_match_rows": "712", "citation_location_match_rows": "712", "source_span_id_match_rows": "366", "wrong_answer_rows": "288", "coherent_wrong_key_rows": "288", "routehint_rows": "0"},
    "B": {"answer_hash_match_rows": "1000", "citation_location_match_rows": "1000", "source_span_id_match_rows": "497", "wrong_answer_rows": "0", "coherent_wrong_key_rows": "0", "routehint_rows": "0"},
    "G": {"answer_hash_match_rows": "1000", "citation_location_match_rows": "1000", "source_span_id_match_rows": "497", "wrong_answer_rows": "0", "coherent_wrong_key_rows": "0", "routehint_rows": "1000"},
    "H": {"answer_hash_match_rows": "1000", "citation_location_match_rows": "1000", "source_span_id_match_rows": "497", "wrong_answer_rows": "0", "coherent_wrong_key_rows": "0", "routehint_rows": "1000"},
}
for system_id, expected_values in expected_metric_rows.items():
    row = metrics.get(system_id)
    if not row:
        raise SystemExit(f"missing v53aq metric row for {system_id}")
    for field, value in {
        "query_rows": "1000",
        "answer_rows": "1000",
        "citation_rows": "1000",
        "abstain_correct_rows": "1000",
        "expected_abstain_rows": "160",
        "predicted_abstain_rows": "160",
        "missing_specific_query_rows": "30",
        "resource_rows": "1000",
        "evaluator_rows": "1000",
        "adapter_trace_rows": "1000",
        "selection_question_text_only": "1",
        "selection_oracle_field_used": "0",
        "expected_answer_oracle_replay_rows": "0",
        "deterministic_source_span_adapter_rows": "0",
        "actual_adapter_execution_ready": "1",
        "real_adapter_execution_ready": "1",
        **expected_values,
    }.items():
        if row.get(field) != value:
            raise SystemExit(f"v53aq metric {system_id}.{field}: expected {value}, got {row.get(field)}")

if len(hints) != 2000 or {row["system_id"] for row in hints} != {"G", "H"}:
    raise SystemExit("v53aq RouteHint rows should cover G/H only")
if len(route_memory) != 2000 or {row["system_id"] for row in route_memory} != {"G", "H"}:
    raise SystemExit("v53aq RouteMemory rows should cover G/H only")
if any(row["raw_context_appended"] != "0" for row in hints):
    raise SystemExit("v53aq RouteHint rows must not append raw context")

if {row["evaluator_contract_id"] for row in evaluators} != {"v53aq-query-text-only-answer-citation-resource-v1"}:
    raise SystemExit("v53aq evaluator rows should share one evaluator contract")
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
    for row in evaluators
):
    raise SystemExit("v53aq evaluator rows should separately bind answer/citation/resource checks for real adapters")
if {row["source_query_rows_sha256"] for row in evaluators} != {summary["source_query_rows_sha256"]}:
    raise SystemExit("v53aq evaluator rows should bind the shared query hash")
if {row["source_span_rows_sha256"] for row in evaluators} != {summary["source_span_rows_sha256"]}:
    raise SystemExit("v53aq evaluator rows should bind the shared span hash")

for row in answers:
    if row["answer_text_sha256"] != sha256_text(row["answer_text"]):
        raise SystemExit("v53aq answer hash mismatch")
    if row["selection_input_fields"] != "question" or row["selection_forbidden_fields"] != FORBIDDEN_SELECTION_FIELDS:
        raise SystemExit("v53aq answer rows should disclose question-only selection")
    if row["selection_oracle_field_used"] != "0":
        raise SystemExit("v53aq answer rows must not use oracle fields in selection")
    if row["system_id"] in {"G", "H"} and row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v53aq G/H should not use raw prompt context bytes")

for row in adapter_traces:
    for field in [
        "selection_query_id_used",
        "selection_expected_answer_used",
        "selection_expected_answer_sha256_used",
        "selection_source_span_id_used",
        "selection_source_path_field_used",
        "selection_source_line_field_used",
        "selection_oracle_field_used",
        "expected_answer_oracle_replay",
        "deterministic_source_span_adapter_execution",
    ]:
        if row[field] != "0":
            raise SystemExit(f"v53aq adapter trace should keep {field}=0")
    if row["selection_question_text_used"] != "1":
        raise SystemExit("v53aq adapter trace should use question text")
if any(row["raw_context_appended"] != "0" or row["compact_routehint_used"] != "1" for row in adapter_traces if row["system_id"] in {"G", "H"}):
    raise SystemExit("v53aq G/H adapter traces should use compact RouteHint without raw prompt context")
if any(row["source_verified_scorer_used"] != "1" or row["domain_policy_used"] != "1" for row in adapter_traces if row["system_id"] == "H"):
    raise SystemExit("v53aq H adapter traces should disclose scorer/policy use")

if sum(row["answer_hash_match"] == "1" for row in evaluators) != int(summary["answer_hash_match_rows"]):
    raise SystemExit("v53aq answer hash match summary mismatch")
if sum(row["citation_location_match"] == "1" for row in evaluators) != int(summary["citation_location_match_rows"]):
    raise SystemExit("v53aq citation location summary mismatch")
if sum(row["source_span_id_match"] == "1" for row in answers) != int(summary["source_span_id_match_rows"]):
    raise SystemExit("v53aq source span ID summary mismatch")
if sum(row["wrong_answer"] == "1" for row in guards) != int(summary["wrong_answer_rows"]):
    raise SystemExit("v53aq wrong-answer guard summary mismatch")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v53i-complete-source-input",
    "query-text-only-selection-contract",
    "abgh-real-adapter-measured",
    "same-evaluator-resource-surface",
    "expected-answer-oracle-replay-absent",
    "source-span-oracle-selection-absent",
    "routehint-no-raw-context",
    "internal-real-performance-metrics",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v53aq decision gate should pass: {gate}")
for gate in ["public-comparison-claim", "required-30b-70b-baselines", "v53-full-audit-ready", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v53aq decision gate should stay blocked: {gate}")

manifest = json.loads((run_dir / "v53aq_complete_source_abgh_real_adapter_measured_manifest.json").read_text(encoding="utf-8"))
for field, value in {
    "v53aq_complete_source_abgh_real_adapter_measured_ready": 1,
    "answer_rows": 4000,
    "citation_rows": 4000,
    "evaluator_rows": 4000,
    "routehint_rows": 2000,
    "selection_question_text_only": 1,
    "selection_oracle_field_used": 0,
    "expected_answer_oracle_replay": 0,
    "deterministic_source_span_adapter_execution": 0,
    "actual_adapter_execution_ready": 1,
    "real_adapter_execution_ready": 1,
    "real_system_performance_claim_ready": 1,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}.items():
    if manifest.get(field) != value:
        raise SystemExit(f"v53aq manifest {field}: expected {value}, got {manifest.get(field)}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53aq sha mismatch: {rel}")

boundary = (run_dir / "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selection_question_text_only=1",
    "selection_allowed_fields=question",
    f"selection_forbidden_fields={FORBIDDEN_SELECTION_FIELDS}",
    "selection_oracle_field_used=0",
    "expected_answer_oracle_replay=0",
    "deterministic_source_span_adapter_execution=0",
    "real_adapter_execution_ready=1",
    "public_comparison_claim_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53aq boundary missing: {snippet}")
PY

echo "v53aq complete-source A/B/G/H real-adapter measured smoke passed"
