#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v08_external_benchmark_adapter"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_adapter_smoke"
fi

MANIFEST_CSV="$RESULTS_DIR/${PREFIX}_manifest.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

cat >"$MANIFEST_CSV" <<'CSV'
benchmark_family,task_scope,input_adapter,label_adapter,metric,required_source,source_ready,result_ready,baseline_ready,route_memory_output,license_status,routing_trigger_rate,active_jump_rate
RULER,synthetic-long-context-retrieval,jsonl-context-query-answer,exact-match-span,exact_match,external-dataset,0,0,0,candidate-span,not-ingested,0,0
LongBench,long-context-qa,jsonl-document-question-answer,answer-string-or-span,f1-or-rouge,external-dataset,0,0,0,candidate-span,not-ingested,0,0
codebase-retrieval,repository-symbol-or-doc-retrieval,jsonl-repo-query-target,repo-path-span,top1-and-recall,external-repo-corpus,0,0,0,candidate-record,not-ingested,0,0
real-document-qa,grounded-document-qa,jsonl-document-question-citation,citation-span-and-answer,grounded-em-f1,external-doc-corpus,0,0,0,candidate-span,not-ingested,0,0
CSV

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family task_scope input_adapter label_adapter metric required_source source_ready result_ready baseline_ready route_memory_output license_status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 benchmark adapter column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v08 benchmark adapter row has wrong column count", 3)
    family = $idx["benchmark_family"]
    families[family] = 1
    if ($idx["input_adapter"] != "none" && $idx["label_adapter"] != "none" && $idx["metric"] != "none") adapter_rows++
    if ($idx["source_ready"] + 0 == 1) source_ready_rows++
    if ($idx["result_ready"] + 0 == 1) result_ready_rows++
    if ($idx["baseline_ready"] + 0 == 1) baseline_ready_rows++
    if ($idx["license_status"] != "not-ingested") license_ready_rows++
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    required_families = 4
    family_count = 0
    if ("RULER" in families) family_count++
    if ("LongBench" in families) family_count++
    if ("codebase-retrieval" in families) family_count++
    if ("real-document-qa" in families) family_count++

    benchmark_adapter_ready = 0
    if (rows == required_families && family_count == required_families && adapter_rows == rows && routing == 0.0 && jump == 0.0) benchmark_adapter_ready = 1
    external_benchmark_source_ready = 0
    if (source_ready_rows == rows && license_ready_rows == rows) external_benchmark_source_ready = 1
    external_benchmark_result_ready = 0
    if (result_ready_rows == rows && baseline_ready_rows == rows) external_benchmark_result_ready = 1
    external_benchmark_ready = 0
    if (benchmark_adapter_ready && external_benchmark_source_ready && external_benchmark_result_ready) external_benchmark_ready = 1

    print "benchmark_scope,benchmark_families,adapter_rows,benchmark_adapter_ready,external_benchmark_source_ready,external_benchmark_result_ready,external_benchmark_ready,source_ready_rows,result_ready_rows,baseline_ready_rows,license_ready_rows,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08b,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      family_count,
      adapter_rows,
      benchmark_adapter_ready,
      external_benchmark_source_ready,
      external_benchmark_result_ready,
      external_benchmark_ready,
      source_ready_rows,
      result_ready_rows,
      baseline_ready_rows,
      license_ready_rows,
      external_benchmark_ready ? "run-external-comparison" : "adapter-ready-source-missing",
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "benchmark-adapter,%s,families=%d adapter_rows=%d\n",
      benchmark_adapter_ready ? "pass" : "blocked",
      family_count,
      adapter_rows >> decision_csv
    printf "benchmark-source,%s,source_ready_rows=%d license_ready_rows=%d\n",
      external_benchmark_source_ready ? "pass" : "blocked",
      source_ready_rows,
      license_ready_rows >> decision_csv
    printf "benchmark-results,%s,result_ready_rows=%d baseline_ready_rows=%d\n",
      external_benchmark_result_ready ? "pass" : "blocked",
      result_ready_rows,
      baseline_ready_rows >> decision_csv
    printf "external-benchmark,%s,external_ready=%d\n",
      external_benchmark_ready ? "ready" : "deferred",
      external_benchmark_ready >> decision_csv
  }
' "$MANIFEST_CSV"

echo "manifest: $MANIFEST_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
