#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54c_complete_source_grounded_generation_1000/generation_001"
SUMMARY_CSV="$RESULTS_DIR/v54c_complete_source_grounded_generation_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54c_complete_source_grounded_generation_1000_decision.csv"

V54C_REUSE_EXISTING="${V54C_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v54c_complete_source_grounded_generation_1000.sh" >/dev/null

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


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
compact_routehint_allowed_key_set = "input_surface,opaque_routehint,question,raw_context_appended,source_locator_absent"
expected = {
    "v54c_complete_source_grounded_generation_1000_ready": "1",
    "v54_generation_1000_ready": "1",
    "v53i_complete_source_query_instantiation_ready": "1",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "generation_rows": "1000",
    "answer_rows": "1000",
    "citation_rows": "1000",
    "unsupported_claim_rows": "160",
    "abstain_rows": "160",
    "generator_resource_rows": "1000",
    "wrong_answer_guard_rows": "1000",
    "grounded_generation_output_contract_rows": "9",
    "grounded_generation_output_contract_ready_rows": "9",
    "grounded_generation_output_contract_pm_required_rows": "7",
    "grounded_generation_output_contract_pm_required_ready_rows": "7",
    "grounded_generation_output_contract_sha256_bound_rows": "8",
    "grounded_generation_output_contract_raw_prompt_forbidden_rows": "9",
    "sha256sums_pm_recommended_csv_rows": "6",
    "sha256sums_pm_recommended_csv_ready": "1",
    "generated_from_source_span_rows": "1000",
    "v53ap_adapter_trace_provenance_ready": "1",
    "v53ap_adapter_trace_provenance_rows": "1000",
    "v53ap_adapter_trace_rows": "4000",
    "v53ap_evaluator_provenance_ready": "1",
    "v53ap_evaluator_provenance_rows": "1000",
    "v53ap_evaluator_rows": "4000",
    "v53ap_same_evaluator_contract_all_local_systems": "1",
    "v53ap_answer_eval_separate_rows": "1000",
    "v53ap_citation_eval_separate_rows": "1000",
    "v53ap_resource_eval_separate_rows": "1000",
    "v53ap_evaluator_resource_row_bound_rows": "1000",
    "missing_specific_abstain_rows": "30",
    "attention_blocks": "0",
    "transformer_blocks": "0",
    "raw_prompt_context_appended_rows": "0",
    "model_visible_leakage_guard_ready": "1",
    "model_visible_input_fields": "sanitized_question,opaque_routehint",
    "model_visible_forbidden_field_used_rows": "0",
    "model_visible_source_locator_rows": "0",
    "compact_routehint_forbidden_alias_rows": "0",
    "deterministic_source_span_generation_fixture_ready": "1",
    "real_model_generation_ready": "0",
    "compact_routehint_rows": "1000",
    "wrong_answer_rows": "0",
    "citation_correct_rows": "1000",
    "answer_correct_rows": "1000",
    "external_model_used": "0",
    "external_network_used": "0",
    "human_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54c {field}: expected {value}, got {summary.get(field)}")

if summary["source_query_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_query_rows.csv"):
    raise SystemExit("v54c query hash should bind source_v53i query rows")
if summary["source_span_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_span_rows.csv"):
    raise SystemExit("v54c span hash should bind source_v53i span rows")

required_files = [
    "answer_rows.csv",
    "citation_rows.csv",
    "unsupported_claim_rows.csv",
    "abstain_rows.csv",
    "generator_resource_rows.csv",
    "wrong_answer_guard_rows.csv",
    "grounded_generation_output_contract_rows.csv",
    "generator_input_rows.csv",
    "compact_routehint_rows.csv",
    "V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md",
    "v54c_complete_source_grounded_generation_manifest.json",
    "sha256_manifest.csv",
    "sha256sums.txt",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/complete_source_control_family_rows.csv",
    "source_v53ap/abgh_system_metric_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53ap/v53ap_complete_source_abgh_same_query_measured_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54c artifact: {rel}")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53i/complete_source_span_rows.csv")}
answers = read_csv(run_dir / "answer_rows.csv")
citations = read_csv(run_dir / "citation_rows.csv")
unsupported = read_csv(run_dir / "unsupported_claim_rows.csv")
abstain = read_csv(run_dir / "abstain_rows.csv")
resources = read_csv(run_dir / "generator_resource_rows.csv")
guards = read_csv(run_dir / "wrong_answer_guard_rows.csv")
inputs = read_csv(run_dir / "generator_input_rows.csv")
hints = read_csv(run_dir / "compact_routehint_rows.csv")
contracts = read_csv(run_dir / "grounded_generation_output_contract_rows.csv")
adapter_traces = read_csv(run_dir / "source_v53ap/abgh_adapter_trace_rows.csv")
evaluator_rows = read_csv(run_dir / "source_v53ap/abgh_evaluator_rows.csv")

for rows, name, count in [
    (answers, "answer", 1000),
    (citations, "citation", 1000),
    (resources, "resource", 1000),
    (guards, "guard", 1000),
    (inputs, "generator input", 1000),
    (hints, "routehint", 1000),
    (unsupported, "unsupported", 160),
    (abstain, "abstain", 160),
]:
    if len(rows) != count:
        raise SystemExit(f"v54c {name} row count mismatch")

if len({row["generation_id"] for row in answers}) != 1000:
    raise SystemExit("v54c generation ids should be unique")
contract_counts = {
    "answer-rows": ("answer_rows.csv", 1000),
    "citation-rows": ("citation_rows.csv", 1000),
    "unsupported-claim-rows": ("unsupported_claim_rows.csv", 160),
    "abstain-rows": ("abstain_rows.csv", 160),
    "generator-resource-rows": ("generator_resource_rows.csv", 1000),
    "wrong-answer-guard-rows": ("wrong_answer_guard_rows.csv", 1000),
    "generator-input-rows": ("generator_input_rows.csv", 1000),
    "compact-routehint-rows": ("compact_routehint_rows.csv", 1000),
}
contract_by_id = {row["artifact_id"]: row for row in contracts}
expected_contract_ids = set(contract_counts) | {"sha256sums"}
if len(contracts) != 9 or set(contract_by_id) != expected_contract_ids:
    raise SystemExit("v54c should write the full grounded-generation output contract")
if sum(row["pm_recommended_output"] == "1" for row in contracts) != 7:
    raise SystemExit("v54c output contract should mark seven PM recommended artifacts")
if any(row["contract_status"] != "ready" for row in contracts):
    raise SystemExit("v54c output contract rows should be ready")
for artifact_id, (artifact_path, expected_count) in contract_counts.items():
    row = contract_by_id[artifact_id]
    path = run_dir / artifact_path
    if row["artifact_path"] != artifact_path:
        raise SystemExit(f"v54c contract path mismatch for {artifact_id}")
    if row["expected_row_count"] != str(expected_count) or row["observed_row_count"] != str(expected_count):
        raise SystemExit(f"v54c contract row count mismatch for {artifact_id}")
    if row["artifact_sha256"] != sha256(path) or row["sha256_bound"] != "1":
        raise SystemExit(f"v54c contract sha256 binding mismatch for {artifact_id}")
    if row["source_span_bound"] != "1" or row["v53ap_provenance_bound"] != "1":
        raise SystemExit(f"v54c contract provenance binding mismatch for {artifact_id}")
    if row["raw_prompt_context_appended_allowed"] != "0" or row["raw_prompt_context_appended_rows"] != "0":
        raise SystemExit(f"v54c contract should forbid raw prompt context for {artifact_id}")
    if (
        row["model_visible_forbidden_field_used_rows"] != "0"
        or row["model_visible_source_locator_rows"] != "0"
        or row["model_visible_leakage_guard_ready"] != "1"
    ):
        raise SystemExit(f"v54c contract should forbid model-visible source/label leakage for {artifact_id}")
    if row["wrong_answer_guarded"] != "1":
        raise SystemExit(f"v54c contract should bind wrong-answer guard for {artifact_id}")
sha_contract = contract_by_id["sha256sums"]
if (
    sha_contract["artifact_path"] != "sha256sums.txt"
    or sha_contract["expected_row_count"] != "not-csv"
    or sha_contract["observed_row_count"] != "written-after-contract"
    or sha_contract["sha256_bound"] != "0"
    or sha_contract["raw_prompt_context_appended_allowed"] != "0"
    or sha_contract["raw_prompt_context_appended_rows"] != "0"
    or sha_contract["model_visible_forbidden_field_used_rows"] != "0"
    or sha_contract["model_visible_source_locator_rows"] != "0"
    or sha_contract["model_visible_leakage_guard_ready"] != "1"
):
    raise SystemExit("v54c sha256sums contract should preserve the post-contract hash-manifest boundary")
if len(adapter_traces) != 4000 or {row["system_id"] for row in adapter_traces} != {"A", "B", "G", "H"}:
    raise SystemExit("v54c should copy v53ap A/B/G/H adapter trace provenance")
if any(row["source_span_binding_match"] != "1" for row in adapter_traces):
    raise SystemExit("v54c copied adapter traces must remain source-span bound")
h_evaluators = {row["query_id"]: row for row in evaluator_rows if row["system_id"] == "H"}
if len(evaluator_rows) != 4000 or {row["system_id"] for row in evaluator_rows} != {"A", "B", "G", "H"}:
    raise SystemExit("v54c should copy v53ap A/B/G/H evaluator provenance")
if len(h_evaluators) != 1000:
    raise SystemExit("v54c should bind one H evaluator row per query")
for row in evaluator_rows:
    if row["evaluator_contract_id"] != "v53ap-source-bound-answer-citation-resource-v1":
        raise SystemExit("v54c evaluator rows should preserve the v53ap evaluator contract")
    if row["answer_eval_separate"] != "1" or row["citation_eval_separate"] != "1" or row["resource_eval_separate"] != "1":
        raise SystemExit("v54c evaluator rows should keep answer/citation/resource checks separate")
    if row["resource_row_bound"] != "1" or row["source_span_binding_match"] != "1":
        raise SystemExit("v54c evaluator rows should stay resource/source-span bound")
    if row["expected_answer_oracle_replay"] != "0" or row["real_system_performance_claim_ready"] != "0":
        raise SystemExit("v54c evaluator rows should keep oracle replay and performance claims closed")

for row in answers:
    query = queries[row["query_id"]]
    span = spans[query["source_span_id"]]
    if row["generated_answer_sha256"] != sha256_text(row["generated_answer"]):
        raise SystemExit("v54c generated answer hash mismatch")
    if row["expected_answer_sha256"] != query["expected_answer_sha256"]:
        raise SystemExit("v54c expected answer hash mismatch")
    if row["generated_answer_sha256"] != query["expected_answer_sha256"]:
        raise SystemExit("v54c generated answer should match frozen expected answer")
    if row["answer_source"] != "source_span_grounded_generator" or row["generated_from_source_span"] != "1":
        raise SystemExit("v54c generated answer should come from the bound source span generator")
    if row["source_span_id"] != span["source_span_id"]:
        raise SystemExit("v54c answer should bind the frozen source span")
    if not row["source_v53ap_adapter_trace_id"].startswith("v53ap_H_"):
        raise SystemExit("v54c answer should bind the v53ap H adapter trace provenance")
    if row["source_v53ap_evaluator_row_id"] != h_evaluators[row["query_id"]]["evaluator_row_id"]:
        raise SystemExit("v54c answer should bind the v53ap H evaluator row")
    if row["answer_correct"] != "1" or row["citation_correct"] != "1" or row["wrong_answer"] != "0":
        raise SystemExit("v54c answer should be correct, cited, and wrong-answer clean")

for row in inputs:
    query_id = row["query_id_evaluator_only"]
    if row["model_visible_input_fields"] != "sanitized_question,opaque_routehint":
        raise SystemExit("v54c generator input should expose only sanitized question and opaque RouteHint to the model")
    for field in [
        "model_visible_query_id_used",
        "model_visible_source_span_id_used",
        "model_visible_source_path_used",
        "model_visible_source_line_used",
        "model_visible_source_file_hash_used",
        "model_visible_expected_behavior_used",
        "model_visible_expected_label_used",
        "compact_routehint_contains_source_locator",
        "compact_routehint_forbidden_alias_used",
    ]:
        if row[field] != "0":
            raise SystemExit(f"v54c generator input should keep {field}=0")
    if row["compact_routehint_allowed_key_set"] != compact_routehint_allowed_key_set:
        raise SystemExit("v54c generator input should bind the compact RouteHint allowed key set")
    if "query_id" in row or "source_span_id" in row:
        raise SystemExit("v54c generator input should not expose query_id/source_span_id as model-visible column names")
    if row["source_span_id_evaluator_only"] != spans[queries[query_id]["source_span_id"]]["source_span_id"]:
        raise SystemExit("v54c generator input should keep source span IDs evaluator/provenance-only")
    if row["source_v53ap_adapter_trace_provenance"] != "1" or row["source_v53ap_adapter_trace_type"] != "routememory-routehint-scorer-policy":
        raise SystemExit("v54c generator input should bind v53ap H adapter trace provenance")
    if row["source_v53ap_evaluator_row_id"] != h_evaluators[query_id]["evaluator_row_id"]:
        raise SystemExit("v54c generator input should bind the v53ap H evaluator row")
    if row["source_v53ap_evaluator_contract_id"] != "v53ap-source-bound-answer-citation-resource-v1":
        raise SystemExit("v54c generator input should preserve the v53ap evaluator contract")
    if row["source_v53ap_evaluator_provenance"] != "1":
        raise SystemExit("v54c generator input should disclose evaluator provenance")
    if row["source_v53ap_answer_eval_separate"] != "1" or row["source_v53ap_citation_eval_separate"] != "1" or row["source_v53ap_resource_eval_separate"] != "1":
        raise SystemExit("v54c generator input should bind separate answer/citation/resource evaluation")
    if row["source_v53ap_evaluator_resource_row_bound"] != "1":
        raise SystemExit("v54c generator input should bind evaluator resource rows")
    if row["attention_blocks"] != "0" or row["transformer_blocks"] != "0":
        raise SystemExit("v54c generator should be non-attention")
    if row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" or row["retrieved_text_in_prompt"] != "0":
        raise SystemExit("v54c generator should not stuff raw prompt context")
    if row["deterministic_source_span_generation_fixture"] != "1" or row["real_model_generation_ready"] != "0":
        raise SystemExit("v54c generator input should disclose fixture generation and block real-model generation claims")
for row in hints:
    query_id = row["query_id_evaluator_only"]
    if row["raw_context_appended"] != "0":
        raise SystemExit("v54c compact RouteHint should not append raw context")
    if "query_id" in row or "source_span_id" in row:
        raise SystemExit("v54c compact RouteHint should not expose query_id/source_span_id as model-visible column names")
    if row["model_visible_input_fields"] != "sanitized_question,opaque_routehint" or row["contains_source_locator"] != "0":
        raise SystemExit("v54c compact RouteHint should stay opaque and source-locator-free")
    if row["compact_routehint_allowed_key_set"] != compact_routehint_allowed_key_set:
        raise SystemExit("v54c compact RouteHint should bind the fixed model-visible payload key set")
    for field in [
        "model_visible_query_id_used",
        "model_visible_source_span_id_used",
        "model_visible_source_path_used",
        "model_visible_source_line_used",
        "model_visible_source_file_hash_used",
        "model_visible_expected_behavior_used",
        "model_visible_expected_label_used",
        "compact_routehint_forbidden_alias_used",
    ]:
        if row[field] != "0":
            raise SystemExit(f"v54c compact RouteHint should keep {field}=0")
    if row["source_v53ap_adapter_system_id"] != "H" or not row["source_v53ap_adapter_trace_id"].startswith("v53ap_H_"):
        raise SystemExit("v54c compact RouteHint should bind v53ap H adapter trace provenance")
    if row["source_v53ap_evaluator_row_id"] != h_evaluators[query_id]["evaluator_row_id"]:
        raise SystemExit("v54c compact RouteHint should bind v53ap H evaluator provenance")
    if row["source_v53ap_evaluator_contract_id"] != "v53ap-source-bound-answer-citation-resource-v1":
        raise SystemExit("v54c compact RouteHint should preserve v53ap evaluator contract")
for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v54c resources should stay local/no external model")
    if row["attention_blocks"] != "0" or row["transformer_blocks"] != "0" or row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v54c resources should record non-attention/no raw context")
    if row["answer_source"] != "source_span_grounded_generator" or row["generated_from_source_span"] != "1":
        raise SystemExit("v54c resources should disclose source-span grounded generation")
    if row["source_v53ap_adapter_trace_provenance"] != "1" or not row["source_v53ap_adapter_trace_id"].startswith("v53ap_H_"):
        raise SystemExit("v54c resources should bind v53ap H adapter trace provenance")
    if row["source_v53ap_evaluator_row_id"] != h_evaluators[row["query_id"]]["evaluator_row_id"]:
        raise SystemExit("v54c resources should bind v53ap H evaluator provenance")
    if row["source_v53ap_evaluator_contract_id"] != "v53ap-source-bound-answer-citation-resource-v1":
        raise SystemExit("v54c resources should preserve v53ap evaluator contract")
    if row["source_v53ap_evaluator_provenance"] != "1":
        raise SystemExit("v54c resources should disclose evaluator provenance")
    if row["source_v53ap_answer_eval_separate"] != "1" or row["source_v53ap_citation_eval_separate"] != "1" or row["source_v53ap_resource_eval_separate"] != "1":
        raise SystemExit("v54c resources should bind separate answer/citation/resource evaluation")
    if row["source_v53ap_evaluator_resource_row_bound"] != "1":
        raise SystemExit("v54c resources should bind evaluator resource rows")
for row in guards:
    if row["answer_correct"] != "1" or row["citation_correct"] != "1" or row["abstain_correct"] != "1":
        raise SystemExit("v54c guards should pass answer/citation/abstain checks")
    if row["source_v53ap_evaluator_row_id"] != h_evaluators[row["query_id"]]["evaluator_row_id"]:
        raise SystemExit("v54c guards should bind v53ap H evaluator provenance")
    if row["source_v53ap_answer_eval_separate"] != "1" or row["source_v53ap_citation_eval_separate"] != "1" or row["source_v53ap_resource_eval_separate"] != "1":
        raise SystemExit("v54c guards should preserve separate evaluator checks")
    if row["source_v53ap_evaluator_resource_row_bound"] != "1":
        raise SystemExit("v54c guards should preserve evaluator resource binding")
    if row["wrong_answer"] != "0" or row["guard_status"] != "pass":
        raise SystemExit("v54c guards should block wrong answers")

missing = [row for row in unsupported if row["unsupported_claim_type"] == "missing-specific"]
if len(missing) != 30:
    raise SystemExit("v54c should preserve 30 missing-specific unsupported rows")
if {row["query_id"] for row in abstain} != {row["query_id"] for row in unsupported}:
    raise SystemExit("v54c abstain and unsupported rows should cover the same negative queries")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53i-source-bound-input",
    "v53ap-pre-baseline-input",
    "v53ap-adapter-trace-provenance",
    "v53ap-evaluator-provenance",
    "recommended-output-artifacts",
    "recommended-output-contract",
    "source-span-grounded-answer-generation",
    "generation-row-target",
    "compact-routehint-only",
    "non-attention-generator",
    "wrong-answer-guard",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v54c gate should pass: {gate}")
for gate in ["human-review-artifacts", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54c gate should remain blocked: {gate}")

manifest = json.loads((run_dir / "v54c_complete_source_grounded_generation_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v54c_complete_source_grounded_generation_1000_ready") != 1:
    raise SystemExit("v54c manifest readiness mismatch")
if manifest.get("generation_rows") != 1000 or manifest.get("unsupported_claim_rows") != 160:
    raise SystemExit("v54c manifest row count mismatch")
if manifest.get("generated_from_source_span_rows") != 1000:
    raise SystemExit("v54c manifest should record source-span generated answers")
if (
    manifest.get("grounded_generation_output_contract_rows") != 9
    or manifest.get("grounded_generation_output_contract_ready_rows") != 9
    or manifest.get("grounded_generation_output_contract_pm_required_rows") != 7
    or manifest.get("grounded_generation_output_contract_pm_required_ready_rows") != 7
    or manifest.get("grounded_generation_output_contract_sha256_bound_rows") != 8
    or manifest.get("grounded_generation_output_contract_raw_prompt_forbidden_rows") != 9
):
    raise SystemExit("v54c manifest should record grounded generation output contract evidence")
if manifest.get("sha256sums_pm_recommended_csv_rows") != 6 or manifest.get("sha256sums_pm_recommended_csv_ready") != 1:
    raise SystemExit("v54c manifest should record sha256sums coverage for all PM recommended CSV outputs")
if manifest.get("v53ap_adapter_trace_provenance_ready") != 1 or manifest.get("v53ap_adapter_trace_provenance_rows") != 1000:
    raise SystemExit("v54c manifest should record v53ap adapter trace provenance")
if manifest.get("v53ap_evaluator_provenance_ready") != 1 or manifest.get("v53ap_evaluator_provenance_rows") != 1000:
    raise SystemExit("v54c manifest should record v53ap evaluator provenance")
if (
    manifest.get("v53ap_answer_eval_separate_rows") != 1000
    or manifest.get("v53ap_citation_eval_separate_rows") != 1000
    or manifest.get("v53ap_resource_eval_separate_rows") != 1000
    or manifest.get("v53ap_evaluator_resource_row_bound_rows") != 1000
):
    raise SystemExit("v54c manifest should preserve separate evaluator/resource binding rows")
if (
    manifest.get("raw_prompt_context_appended_rows") != 0
    or manifest.get("model_visible_leakage_guard_ready") != 1
    or manifest.get("model_visible_forbidden_field_used_rows") != 0
    or manifest.get("model_visible_source_locator_rows") != 0
    or manifest.get("compact_routehint_forbidden_alias_rows") != 0
    or manifest.get("deterministic_source_span_generation_fixture_ready") != 1
    or manifest.get("real_model_generation_ready") != 0
    or manifest.get("wrong_answer_rows") != 0
):
    raise SystemExit("v54c manifest invariant mismatch")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v54c should keep release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel in {"sha256_manifest.csv", "sha256sums.txt"}:
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54c sha256 mismatch: {rel}")
sha_text = (run_dir / "sha256sums.txt").read_text(encoding="utf-8")
for rel in ["answer_rows.csv", "citation_rows.csv", "unsupported_claim_rows.csv", "abstain_rows.csv", "generator_resource_rows.csv", "wrong_answer_guard_rows.csv"]:
    digest = sha256(run_dir / rel).removeprefix("sha256:")
    if f"{digest}  {rel}" not in sha_text:
        raise SystemExit(f"v54c sha256sums missing {rel}")

boundary = (run_dir / "V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000 grounded generation rows",
    "answer_rows=1000",
    "citation_rows=1000",
    "generated_from_source_span_rows=1000",
    "grounded_generation_output_contract_rows=9",
    "grounded_generation_output_contract_pm_required_rows=7",
    "grounded_generation_output_contract_raw_prompt_forbidden_rows=9",
    "sha256sums_pm_recommended_csv_rows=6",
    "sha256sums_pm_recommended_csv_ready=1",
    "v53ap_adapter_trace_provenance_ready=1",
    "v53ap_adapter_trace_provenance_rows=1000",
    "v53ap_evaluator_provenance_ready=1",
    "v53ap_evaluator_provenance_rows=1000",
    "v53ap_answer_eval_separate_rows=1000",
    "v53ap_citation_eval_separate_rows=1000",
    "v53ap_resource_eval_separate_rows=1000",
    "generator_resource_rows=1000",
    "wrong_answer_guard_rows=1000",
    "raw_prompt_context_appended_rows=0",
    "model_visible_leakage_guard_ready=1",
    "model_visible_input_fields=sanitized_question,opaque_routehint",
    "model_visible_forbidden_field_used_rows=0",
    "model_visible_source_locator_rows=0",
    "compact_routehint_forbidden_alias_rows=0",
    "deterministic_source_span_generation_fixture_ready=1",
    "real_model_generation_ready=0",
    "wrong_answer_rows=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54c boundary missing snippet: {snippet}")
PY

echo "v54c complete-source grounded generation 1000 smoke passed"
