#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v14b_lite_prediction_lineage_summary.csv"
DECISION_CSV="$RESULTS_DIR/v14b_lite_prediction_lineage_decision.csv"
RUN_DIR="$RESULTS_DIR/v14b_lite_prediction_lineage_runs/lite_001"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v14-b-lite summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v14-b-lite summary row", 4)
    }
  ' "$summary_csv"
}

expect_decision_status() {
  local decision_csv="$1"
  local gate="$2"
  local expected="$3"

  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("v14-b-lite decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v14-b-lite decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

"$ROOT_DIR/experiments/run_v14b_lite_prediction_lineage.sh" >/dev/null

expect_summary_value "$SUMMARY_CSV" "dataset_rows" "50" "v14-b-lite dataset rows"
expect_summary_value "$SUMMARY_CSV" "routeqa_mini_target_rows" "50" "v14-b-lite target rows"
expect_summary_value "$SUMMARY_CSV" "routeqa_mini_ready" "1" "v14-b-lite RouteQA-mini readiness"
expect_summary_value "$SUMMARY_CSV" "raw_prediction_rows" "50" "v14-b-lite raw predictions"
expect_summary_value "$SUMMARY_CSV" "prediction_lineage_rows" "50" "v14-b-lite prediction lineage rows"
expect_summary_value "$SUMMARY_CSV" "prediction_lineage_ready" "1" "v14-b-lite prediction lineage"
expect_summary_value "$SUMMARY_CSV" "prediction_source_summary_ready" "1" "v14-b-lite prediction source summary"
expect_summary_value "$SUMMARY_CSV" "mmap_prediction_trace_ready" "1" "v14-b-lite mmap prediction trace"
expect_summary_value "$SUMMARY_CSV" "selected_candidate_trace_ready" "1" "v14-b-lite selected candidate trace"
expect_summary_value "$SUMMARY_CSV" "route_memory_prediction_rows_ready" "1" "v14-b-lite RouteMemory prediction rows"
expect_summary_value "$SUMMARY_CSV" "evidence_span_to_prediction_ready" "1" "v14-b-lite evidence span mapping"
expect_summary_value "$SUMMARY_CSV" "no_extractor_prediction_ready" "1" "v14-b-lite no extractor"
expect_summary_value "$SUMMARY_CSV" "oracle_prediction_used" "0" "v14-b-lite oracle flag"
expect_summary_value "$SUMMARY_CSV" "input_extractor_used" "0" "v14-b-lite extractor flag"
expect_summary_value "$SUMMARY_CSV" "route_memory_store_used" "1" "v14-b-lite RouteMemory store flag"
expect_summary_value "$SUMMARY_CSV" "mmap_read_used" "1" "v14-b-lite mmap read flag"
expect_summary_value "$SUMMARY_CSV" "candidate_value_pos_used" "1" "v14-b-lite value position flag"
expect_summary_value "$SUMMARY_CSV" "value_byte_read_used" "1" "v14-b-lite value byte flag"
expect_summary_value "$SUMMARY_CSV" "proposal_hint_used" "1" "v14-b-lite proposal hint flag"
expect_summary_value "$SUMMARY_CSV" "promoted_prediction_rows" "50" "v14-b-lite promoted predictions"
expect_summary_value "$SUMMARY_CSV" "promoted_route_memory_prediction_rows" "50" "v14-b-lite RouteMemory promoted predictions"
expect_summary_value "$SUMMARY_CSV" "generator_hint_nlg_rows" "50" "v14-b-lite generator rows"
expect_summary_value "$SUMMARY_CSV" "generator_hint_nlg_ready" "1" "v14-b-lite generator hint NLG"
expect_summary_value "$SUMMARY_CSV" "grounding_rows" "50" "v14-b-lite grounding rows"
expect_summary_value "$SUMMARY_CSV" "proposal_hint_nlg_used_rows" "50" "v14-b-lite generator hint use"
expect_summary_value "$SUMMARY_CSV" "shortcut_negative_suite_ready" "1" "v14-b-lite shortcut negative suite"
expect_summary_value "$SUMMARY_CSV" "negative_case_rows" "11" "v14-b-lite negative case rows"
expect_summary_value "$SUMMARY_CSV" "hash_clean_wrong_span_block" "1" "v14-b-lite wrong span block"
expect_summary_value "$SUMMARY_CSV" "corrupted_route_index_block" "1" "v14-b-lite corrupted route index block"
expect_summary_value "$SUMMARY_CSV" "corrupted_chunk_offsets_block" "1" "v14-b-lite corrupted chunk offsets block"
expect_summary_value "$SUMMARY_CSV" "input_extractor_promotion_block" "1" "v14-b-lite extractor promotion block"
expect_summary_value "$SUMMARY_CSV" "oracle_promotion_block" "1" "v14-b-lite oracle promotion block"
expect_summary_value "$SUMMARY_CSV" "routeqa_bound_rows" "50" "v14-b-lite RouteQA rows"
expect_summary_value "$SUMMARY_CSV" "benchmark_bound_rows" "50" "v14-b-lite benchmark rows"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "1" "v14-b-lite resource envelope"
expect_summary_value "$SUMMARY_CSV" "cpu_canonical" "1" "v14-b-lite CPU canonical"
expect_summary_value "$SUMMARY_CSV" "hip_optional_parity" "1" "v14-b-lite HIP optional parity"
expect_summary_value "$SUMMARY_CSV" "run_dir_under_5gb" "1" "v14-b-lite run directory size"
expect_summary_value "$SUMMARY_CSV" "query_count_within_lite" "1" "v14-b-lite query count envelope"
expect_summary_value "$SUMMARY_CSV" "requested_outputs_ready" "1" "v14-b-lite requested outputs"
expect_summary_value "$SUMMARY_CSV" "run_layout_ready" "1" "v14-b-lite run layout"
expect_summary_value "$SUMMARY_CSV" "objective_requirements_ready" "1" "v14-b-lite objective requirements"
expect_summary_value "$SUMMARY_CSV" "execution_chain_manifest_ready" "1" "v14-b-lite execution chain"
expect_summary_value "$SUMMARY_CSV" "runner_owned_query_result_evaluator_ready" "1" "v14-b-lite runner ready"
expect_summary_value "$SUMMARY_CSV" "candidate_external_benchmark_result_ready" "0" "v14-b-lite candidate external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v14-b-lite real external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v14-b-lite release"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v14-b-lite routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v14-b-lite jump"

expect_decision_status "$DECISION_CSV" "stage-8-l-prediction-lineage" "pass"
expect_decision_status "$DECISION_CSV" "stage-8-l-route-memory-prediction" "pass"
expect_decision_status "$DECISION_CSV" "stage-8-5-l-lightweight-benchmark" "pass"
expect_decision_status "$DECISION_CSV" "stage-8-2-l-shortcut-negative-suite" "pass"
expect_decision_status "$DECISION_CSV" "stage-9-l-generator-hint-nlg" "pass"
expect_decision_status "$DECISION_CSV" "stage-9-5-l-resource-envelope" "pass"
expect_decision_status "$DECISION_CSV" "stage-10-lite-evidence-bound-runtime" "pass"
expect_decision_status "$DECISION_CSV" "candidate-external-benchmark-result" "blocked"
expect_decision_status "$DECISION_CSV" "real-release-package" "blocked"

for file in \
  source/source_manifest.json \
  dataset/queries.jsonl \
  dataset/dataset.jsonl \
  query/queries.jsonl \
  store/route_memory_store.bin \
  store/route_index.bin \
  store/chunk_offsets \
  store/mmap_read_rows.csv \
  mmap/mmap_read_rows.csv \
  predictions/raw_predictions.jsonl \
  prediction/raw_predictions.jsonl \
  predictions/prediction_status.json \
  predictions/prediction_lineage.jsonl \
  predictions/prediction_source_summary.json \
  predictions/generator_hint_nlg.jsonl \
  predictions/shortcut_negative_summary.json \
  nlg/generator_hint_transcript.jsonl \
  nlg/generator_hint_status.json \
  traces/mmap_prediction_trace.jsonl \
  traces/selected_candidate_trace.jsonl \
  traces/generator_hint_trace.csv \
  evaluator/evaluator_output.csv \
  evaluator/evaluator_status.json \
  metrics/metrics.json \
  routeqa/routeqa_rows.csv \
  benchmark/benchmark_rows.csv \
  evidence/prediction_source_rows.csv \
  evidence/route_memory_prediction_rows.csv \
  evidence/evidence_span_to_prediction.csv \
  evidence/generator_hint_rows.csv \
  evidence/grounding_rows.csv \
  evidence/shortcut_negative_rows.csv \
  evidence/evidence_packet.csv \
  evidence/run_layout_manifest.json \
  evidence/objective_requirements_manifest.json \
  evidence/execution_chain_manifest.json \
  promotion/promotion_rows.csv \
  resource/resource_rows.csv \
  resource/resource_envelope.json \
  sha256sums.txt
do
  if [[ ! -s "$RUN_DIR/$file" ]]; then
    echo "missing v14-b-lite artifact: $file" >&2
    exit 20
  fi
done

python3 - "$RUN_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def jsonl(rel):
    with (run_dir / rel).open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]

def csv_rows(rel):
    with (run_dir / rel).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

sha_manifest = {}
with (run_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            digest, rel = line.strip().split(None, 1)
            sha_manifest[rel] = "sha256:" + digest

required_sha = [
    "query/queries.jsonl",
    "mmap/mmap_read_rows.csv",
    "prediction/raw_predictions.jsonl",
    "predictions/prediction_lineage.jsonl",
    "predictions/prediction_source_summary.json",
    "predictions/generator_hint_nlg.jsonl",
    "predictions/shortcut_negative_summary.json",
    "nlg/generator_hint_transcript.jsonl",
    "nlg/generator_hint_status.json",
    "traces/mmap_prediction_trace.jsonl",
    "traces/selected_candidate_trace.jsonl",
    "traces/generator_hint_trace.csv",
    "evidence/prediction_source_rows.csv",
    "evidence/route_memory_prediction_rows.csv",
    "evidence/evidence_span_to_prediction.csv",
    "evidence/generator_hint_rows.csv",
    "evidence/grounding_rows.csv",
    "evidence/shortcut_negative_rows.csv",
    "resource/resource_envelope.json",
]
for rel in required_sha:
    if sha_manifest.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"sha256 manifest does not bind {rel}")
if sha256(run_dir / "dataset/queries.jsonl") != sha256(run_dir / "query/queries.jsonl"):
    raise SystemExit("query alias hash mismatch")
if sha256(run_dir / "store/mmap_read_rows.csv") != sha256(run_dir / "mmap/mmap_read_rows.csv"):
    raise SystemExit("mmap alias hash mismatch")
if sha256(run_dir / "predictions/raw_predictions.jsonl") != sha256(run_dir / "prediction/raw_predictions.jsonl"):
    raise SystemExit("prediction alias hash mismatch")

dataset = {row["query_id"]: row for row in jsonl("dataset/dataset.jsonl")}
lineage = jsonl("predictions/prediction_lineage.jsonl")
raw_predictions = jsonl("predictions/raw_predictions.jsonl")
source_rows = csv_rows("evidence/prediction_source_rows.csv")
route_memory_rows = csv_rows("evidence/route_memory_prediction_rows.csv")
span_rows = csv_rows("evidence/evidence_span_to_prediction.csv")
generator_rows = jsonl("predictions/generator_hint_nlg.jsonl")
generator_transcript = jsonl("nlg/generator_hint_transcript.jsonl")
generator_trace = csv_rows("traces/generator_hint_trace.csv")
generator_hint_rows = csv_rows("evidence/generator_hint_rows.csv")
grounding_rows = csv_rows("evidence/grounding_rows.csv")
shortcut_rows = csv_rows("evidence/shortcut_negative_rows.csv")
summary = json.loads((run_dir / "predictions" / "prediction_source_summary.json").read_text(encoding="utf-8"))
shortcut_summary = json.loads((run_dir / "predictions" / "shortcut_negative_summary.json").read_text(encoding="utf-8"))
nlg_status = json.loads((run_dir / "nlg" / "generator_hint_status.json").read_text(encoding="utf-8"))
resource = json.loads((run_dir / "resource" / "resource_envelope.json").read_text(encoding="utf-8"))
layout = json.loads((run_dir / "evidence" / "run_layout_manifest.json").read_text(encoding="utf-8"))
objective = json.loads((run_dir / "evidence" / "objective_requirements_manifest.json").read_text(encoding="utf-8"))
chain = json.loads((run_dir / "evidence" / "execution_chain_manifest.json").read_text(encoding="utf-8"))

if not (len(dataset) == len(lineage) == len(raw_predictions) == len(source_rows) == len(route_memory_rows) == len(span_rows) == 50):
    raise SystemExit("v14-b-lite row counts do not match 50")
if len(generator_rows) != 50 or len(generator_trace) != 50 or len(generator_transcript) != 50 or len(generator_hint_rows) != 50 or len(grounding_rows) != 50:
    raise SystemExit("generator hint row counts do not match 50")
if len(shortcut_rows) != 11:
    raise SystemExit("shortcut negative row count does not match 11")

allowed = {"route_memory_exact", "route_memory_hint", "abstain", "fallback"}
present_rows = 0
for row in lineage:
    qid = row["query_id"]
    label = dataset[qid].get("label_type", "")
    if row.get("prediction_source") not in allowed:
        raise SystemExit("lineage used a non-RouteMemory source")
    if row.get("oracle_prediction_used") != 0 or row.get("input_extractor_used") != 0:
        raise SystemExit("lineage used oracle or input extractor")
    if row.get("route_memory_store_used") != 1 or row.get("proposal_hint_used") != 1:
        raise SystemExit("lineage did not bind RouteMemory/proposal hint")
    if label in {"missing", "near_miss"}:
        if row.get("prediction_source") != "abstain" or row.get("prediction_text") != "ABSTAIN":
            raise SystemExit("missing/near-miss query did not abstain")
        continue
    present_rows += 1
    if row.get("prediction_source") not in {"route_memory_exact", "route_memory_hint"}:
        raise SystemExit("present query did not use RouteMemory exact/hint")
    for flag in ["mmap_read_used", "candidate_value_pos_used", "value_byte_read_used"]:
        if row.get(flag) != 1:
            raise SystemExit(f"present lineage row missing {flag}")
    if not row.get("evidence_span_sha256", "").startswith("sha256:"):
        raise SystemExit("lineage row missing evidence hash")
if present_rows < 48:
    raise SystemExit("expected at least 48 present RouteQA-mini rows")

for row in raw_predictions:
    if row.get("oracle_prediction_used") != 0 or row.get("input_extractor_used") != 0:
        raise SystemExit("raw prediction used oracle or extractor")
for row in generator_rows:
    if row.get("proposal_hint_used") != 1:
        raise SystemExit("generator row did not use proposal hint")
    if row.get("proposal_hint") not in row.get("generator_output", ""):
        raise SystemExit("proposal hint is absent from generated output")
    if row.get("prediction_text") not in row.get("generator_output", ""):
        raise SystemExit("prediction text is absent from generated output")
for row in generator_trace:
    if row.get("proposal_hint_seen_in_output") != "1" or row.get("prediction_text_seen_in_output") != "1":
        raise SystemExit("generator trace does not prove hint/output binding")
for row in grounding_rows:
    if row.get("citation_span_bound") != "1" or row.get("unsupported_claims") != "0":
        raise SystemExit("grounding rows do not prove citation/no-unsupported-claims contract")
if nlg_status.get("ready") != 1 or nlg_status.get("generator_hint_used") != 1:
    raise SystemExit("NLG status is not ready")
for key in [
    "shortcut_negative_suite_ready",
    "hash_clean_wrong_span_block",
    "corrupted_route_index_block",
    "corrupted_chunk_offsets_block",
    "raw_input_shortcut_block",
    "input_extractor_promotion_block",
    "oracle_promotion_block",
]:
    if shortcut_summary.get(key) != 1:
        raise SystemExit(f"shortcut negative summary flag is not ready: {key}")
for row in shortcut_rows:
    if row.get("attempted_prediction_source") in {"oracle", "input_extractor"} and row.get("candidate_promotion_allowed") != "0":
        raise SystemExit("oracle/input extractor shortcut was allowed to promote")
    if row.get("case_id") in {"hash_clean_wrong_span", "corrupted_route_index", "corrupted_chunk_offsets"} and row.get("candidate_promotion_allowed") != "0":
        raise SystemExit("corruption shortcut was allowed to promote")

for key in [
    "prediction_lineage_ready",
    "prediction_source_summary_ready",
    "mmap_prediction_trace_ready",
    "route_memory_prediction_rows_ready",
    "evidence_span_to_prediction_ready",
    "no_extractor_prediction_ready",
    "generator_hint_nlg_ready",
    "shortcut_negative_suite_ready",
]:
    if summary.get(key) != 1:
        raise SystemExit(f"prediction source summary flag is not ready: {key}")
if summary.get("promoted_prediction_rows") != 50 or summary.get("promoted_route_memory_prediction_rows") != 50:
    raise SystemExit("promoted RouteMemory row counts mismatch")
if resource.get("resource_envelope_ready") != 1 or resource.get("cpu_canonical") != 1 or resource.get("hip_optional_parity") != 1:
    raise SystemExit("resource envelope is not ready")
if resource.get("query_count") != 50 or resource.get("query_count_within_lite") != 1 or resource.get("run_dir_under_5gb") != 1:
    raise SystemExit("resource envelope budget fields mismatch")

layout_scopes = {row.get("layout_scope") for row in layout.get("layout_groups", [])}
for scope in ["stage_10_lite_aliases", "prediction_lineage", "generator_hint_nlg", "shortcut_negative_suite", "resource_envelope"]:
    if scope not in layout_scopes:
        raise SystemExit(f"run layout missing scope {scope}")
if layout.get("run_layout_ready") != 1:
    raise SystemExit("run layout not ready")
objective_stages = {row.get("stage"): row for row in objective.get("stages", [])}
for stage in ["prediction_lineage", "generator_hint_nlg", "shortcut_negative_suite", "resource_envelope"]:
    if objective_stages.get(stage, {}).get("ready") != 1:
        raise SystemExit(f"objective stage not ready: {stage}")
if objective.get("objective_requirements_ready") != 1:
    raise SystemExit("objective requirements not ready")

artifact_names = {row.get("artifact") for row in chain.get("artifacts", [])}
for artifact in [
    "query_alias",
    "mmap_alias",
    "prediction_alias",
    "prediction_lineage",
    "prediction_source_summary",
    "mmap_prediction_trace",
    "selected_candidate_trace",
    "prediction_source_rows",
    "route_memory_prediction_rows",
    "evidence_span_to_prediction",
    "generator_hint_nlg",
    "generator_hint_transcript",
    "generator_hint_status",
    "generator_hint_rows",
    "grounding_rows",
    "generator_hint_trace",
    "shortcut_negative_rows",
    "shortcut_negative_summary",
    "resource_envelope",
]:
    if artifact not in artifact_names:
        raise SystemExit(f"execution chain missing artifact {artifact}")
for artifact in chain.get("artifacts", []):
    rel = artifact.get("path", "")
    path = run_dir / rel
    if artifact.get("ready") != 1 or not path.is_file():
        raise SystemExit(f"execution chain artifact not ready: {artifact.get('artifact')}")
    if artifact.get("sha256") != sha256(path):
        raise SystemExit(f"execution chain hash mismatch: {artifact.get('artifact')}")
if chain.get("prediction_lineage_ready") != 1 or chain.get("no_extractor_prediction_ready") != 1:
    raise SystemExit("execution chain does not bind v14-b-lite lineage readiness")
if chain.get("shortcut_negative_suite_ready") != 1:
    raise SystemExit("execution chain does not bind shortcut negative suite readiness")
if chain.get("promoted_prediction_rows") != chain.get("promoted_route_memory_prediction_rows"):
    raise SystemExit("execution chain promoted row counts mismatch")
if chain.get("candidate_external_benchmark_result_ready") != 0 or chain.get("real_release_package_ready") != 0:
    raise SystemExit("execution chain promoted external/release unexpectedly")
PY

echo "v14-b-lite prediction lineage smoke passed"
