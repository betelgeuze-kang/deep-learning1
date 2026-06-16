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
    "generated_from_source_span_rows": "1000",
    "v53ap_adapter_trace_provenance_ready": "1",
    "v53ap_adapter_trace_provenance_rows": "1000",
    "v53ap_adapter_trace_rows": "4000",
    "missing_specific_abstain_rows": "30",
    "attention_blocks": "0",
    "transformer_blocks": "0",
    "raw_prompt_context_appended_rows": "0",
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
adapter_traces = read_csv(run_dir / "source_v53ap/abgh_adapter_trace_rows.csv")

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
if len(adapter_traces) != 4000 or {row["system_id"] for row in adapter_traces} != {"A", "B", "G", "H"}:
    raise SystemExit("v54c should copy v53ap A/B/G/H adapter trace provenance")
if any(row["source_span_binding_match"] != "1" for row in adapter_traces):
    raise SystemExit("v54c copied adapter traces must remain source-span bound")

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
    if row["answer_correct"] != "1" or row["citation_correct"] != "1" or row["wrong_answer"] != "0":
        raise SystemExit("v54c answer should be correct, cited, and wrong-answer clean")

for row in inputs:
    if row["source_v53ap_adapter_trace_provenance"] != "1" or row["source_v53ap_adapter_trace_type"] != "routememory-routehint-scorer-policy":
        raise SystemExit("v54c generator input should bind v53ap H adapter trace provenance")
    if row["attention_blocks"] != "0" or row["transformer_blocks"] != "0":
        raise SystemExit("v54c generator should be non-attention")
    if row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" or row["retrieved_text_in_prompt"] != "0":
        raise SystemExit("v54c generator should not stuff raw prompt context")
for row in hints:
    if row["raw_context_appended"] != "0":
        raise SystemExit("v54c compact RouteHint should not append raw context")
    if row["source_v53ap_adapter_system_id"] != "H" or not row["source_v53ap_adapter_trace_id"].startswith("v53ap_H_"):
        raise SystemExit("v54c compact RouteHint should bind v53ap H adapter trace provenance")
for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v54c resources should stay local/no external model")
    if row["attention_blocks"] != "0" or row["transformer_blocks"] != "0" or row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v54c resources should record non-attention/no raw context")
    if row["answer_source"] != "source_span_grounded_generator" or row["generated_from_source_span"] != "1":
        raise SystemExit("v54c resources should disclose source-span grounded generation")
    if row["source_v53ap_adapter_trace_provenance"] != "1" or not row["source_v53ap_adapter_trace_id"].startswith("v53ap_H_"):
        raise SystemExit("v54c resources should bind v53ap H adapter trace provenance")
for row in guards:
    if row["answer_correct"] != "1" or row["citation_correct"] != "1" or row["abstain_correct"] != "1":
        raise SystemExit("v54c guards should pass answer/citation/abstain checks")
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
    "recommended-output-artifacts",
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
if manifest.get("v53ap_adapter_trace_provenance_ready") != 1 or manifest.get("v53ap_adapter_trace_provenance_rows") != 1000:
    raise SystemExit("v54c manifest should record v53ap adapter trace provenance")
if manifest.get("raw_prompt_context_appended_rows") != 0 or manifest.get("wrong_answer_rows") != 0:
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
for rel in ["answer_rows.csv", "citation_rows.csv", "generator_resource_rows.csv", "wrong_answer_guard_rows.csv"]:
    digest = sha256(run_dir / rel).removeprefix("sha256:")
    if f"{digest}  {rel}" not in sha_text:
        raise SystemExit(f"v54c sha256sums missing {rel}")

boundary = (run_dir / "V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000 grounded generation rows",
    "answer_rows=1000",
    "citation_rows=1000",
    "generated_from_source_span_rows=1000",
    "v53ap_adapter_trace_provenance_ready=1",
    "v53ap_adapter_trace_provenance_rows=1000",
    "generator_resource_rows=1000",
    "wrong_answer_guard_rows=1000",
    "raw_prompt_context_appended_rows=0",
    "wrong_answer_rows=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54c boundary missing snippet: {snippet}")
PY

echo "v54c complete-source grounded generation 1000 smoke passed"
