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

PREFIX="v08_external_benchmark_evidence_ingestion"
ADAPTER_PREFIX="v08_external_benchmark_adapter"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  ADAPTER_PREFIX="v08_external_benchmark_adapter_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

ADAPTER_SUMMARY_CSV="$RESULTS_DIR/${ADAPTER_PREFIX}_summary.csv"
if [[ ! -s "$ADAPTER_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v08_external_benchmark_adapter.sh" "${RUN_ARGS[@]}" >/dev/null
fi

EVIDENCE_CSV="$RESULTS_DIR/${PREFIX}_evidence.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

cat >"$EVIDENCE_CSV" <<'CSV'
benchmark_family,dataset_uri,split_name,license,source_hash,baseline_name,baseline_metric,route_memory_metric,result_uri,evaluator_version,provenance_hash,source_ready,result_ready,baseline_ready,license_ready,routing_trigger_rate,active_jump_rate
RULER,pending,pending,pending,pending,pending,pending,pending,pending,v08-evidence-v1,pending,0,0,0,0,0,0
LongBench,pending,pending,pending,pending,pending,pending,pending,pending,v08-evidence-v1,pending,0,0,0,0,0,0
codebase-retrieval,pending,pending,pending,pending,pending,pending,pending,pending,v08-evidence-v1,pending,0,0,0,0,0,0
real-document-qa,pending,pending,pending,pending,pending,pending,pending,pending,v08-evidence-v1,pending,0,0,0,0,0,0
CSV

awk -F, -v evidence_csv="$EVIDENCE_CSV" -v adapter_csv="$ADAPTER_SUMMARY_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == adapter_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) aidx[$i] = i
    required_count = split("benchmark_families benchmark_adapter_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in aidx)) die("missing v08 benchmark evidence adapter column: " required[i], 2)
    }
    next
  }
  FILENAME == adapter_csv {
    adapter_rows++
    adapter_families = $aidx["benchmark_families"] + 0
    benchmark_adapter_ready = $aidx["benchmark_adapter_ready"] + 0
    adapter_routing = $aidx["routing_trigger_rate"] + 0
    adapter_jump = $aidx["active_jump_rate"] + 0
    next
  }
  FILENAME == evidence_csv && FNR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("benchmark_family dataset_uri split_name license source_hash baseline_name baseline_metric route_memory_metric result_uri evaluator_version provenance_hash source_ready result_ready baseline_ready license_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing v08 benchmark evidence column: " required[i], 3)
    }
    next
  }
  FILENAME == evidence_csv {
    evidence_rows++
    if (NF != header_fields) die("v08 benchmark evidence row has wrong column count", 4)
    family = $eidx["benchmark_family"]
    families[family] = 1
    if ($eidx["source_ready"] + 0 == 1) source_ready_rows++
    if ($eidx["result_ready"] + 0 == 1) result_ready_rows++
    if ($eidx["baseline_ready"] + 0 == 1) baseline_ready_rows++
    if ($eidx["license_ready"] + 0 == 1) license_ready_rows++
    evidence_routing += $eidx["routing_trigger_rate"] + 0
    evidence_jump += $eidx["active_jump_rate"] + 0
    next
  }
  END {
    if (adapter_rows != 1) die("expected one v08 benchmark adapter summary row", 5)

    required_families = 4
    family_count = 0
    if ("RULER" in families) family_count++
    if ("LongBench" in families) family_count++
    if ("codebase-retrieval" in families) family_count++
    if ("real-document-qa" in families) family_count++

    evidence_schema_ready = 0
    if (benchmark_adapter_ready == 1 &&
        adapter_families == required_families &&
        evidence_rows == required_families &&
        family_count == required_families &&
        evidence_routing == 0.0 &&
        evidence_jump == 0.0) {
      evidence_schema_ready = 1
    }

    external_benchmark_source_ready = 0
    if (source_ready_rows == evidence_rows && license_ready_rows == evidence_rows) external_benchmark_source_ready = 1
    external_benchmark_result_ready = 0
    if (result_ready_rows == evidence_rows && baseline_ready_rows == evidence_rows) external_benchmark_result_ready = 1
    external_benchmark_ready = 0
    if (evidence_schema_ready && external_benchmark_source_ready && external_benchmark_result_ready) external_benchmark_ready = 1

    action = "external-benchmark-source-missing"
    if (!benchmark_adapter_ready) {
      action = "build-external-benchmark-adapter"
    } else if (!evidence_schema_ready) {
      action = "build-external-benchmark-evidence-schema"
    } else if (external_benchmark_ready) {
      action = "run-external-comparison"
    } else if (external_benchmark_source_ready && !external_benchmark_result_ready) {
      action = "external-benchmark-results-missing"
    }

    print "benchmark_scope,benchmark_families,benchmark_adapter_ready,benchmark_evidence_schema_ready,external_benchmark_source_ready,external_benchmark_result_ready,external_benchmark_ready,source_evidence_rows,result_evidence_rows,baseline_evidence_rows,license_evidence_rows,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08c,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      family_count,
      benchmark_adapter_ready,
      evidence_schema_ready,
      external_benchmark_source_ready,
      external_benchmark_result_ready,
      external_benchmark_ready,
      source_ready_rows,
      result_ready_rows,
      baseline_ready_rows,
      license_ready_rows,
      action,
      adapter_routing + evidence_routing,
      adapter_jump + evidence_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "benchmark-adapter,%s,families=%d\n",
      benchmark_adapter_ready ? "pass" : "blocked",
      adapter_families >> decision_csv
    printf "benchmark-evidence-schema,%s,evidence_families=%d evidence_rows=%d\n",
      evidence_schema_ready ? "pass" : "blocked",
      family_count,
      evidence_rows >> decision_csv
    printf "benchmark-source,%s,source_ready_rows=%d license_ready_rows=%d\n",
      external_benchmark_source_ready ? "pass" : "blocked",
      source_ready_rows,
      license_ready_rows >> decision_csv
    printf "benchmark-results,%s,result_ready_rows=%d baseline_ready_rows=%d\n",
      external_benchmark_result_ready ? "pass" : "blocked",
      result_ready_rows,
      baseline_ready_rows >> decision_csv
    printf "external-benchmark,%s,action=%s\n",
      external_benchmark_ready ? "ready" : "deferred",
      action >> decision_csv
  }
' "$ADAPTER_SUMMARY_CSV" "$EVIDENCE_CSV"

echo "evidence: $EVIDENCE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
