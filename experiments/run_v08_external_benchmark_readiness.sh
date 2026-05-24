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

PREFIX="v08_external_benchmark_readiness"
SOURCE_PREFIX="v07_route_memory_promotion_gate"
ADAPTER_PREFIX="v08_external_benchmark_adapter"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_readiness_smoke"
  SOURCE_PREFIX="v07_route_memory_promotion_gate_smoke"
  ADAPTER_PREFIX="v08_external_benchmark_adapter_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
ADAPTER_SUMMARY_CSV="$RESULTS_DIR/${ADAPTER_PREFIX}_summary.csv"
if [[ ! -s "$SOURCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$ADAPTER_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v08_external_benchmark_adapter.sh" "${RUN_ARGS[@]}" >/dev/null
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v source_csv="$SOURCE_SUMMARY_CSV" -v adapter_csv="$ADAPTER_SUMMARY_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  FILENAME == source_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("adaptive_scale_safe chunk_ready source_safe combined_ready default_promotion status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing v08 readiness source column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  FILENAME == source_csv {
    source_rows++
    default_promotion = $idx["default_promotion"] + 0
    promotion_status = $idx["status"]
    adaptive_scale_safe = $idx["adaptive_scale_safe"] + 0
    chunk_ready = $idx["chunk_ready"] + 0
    source_safe = $idx["source_safe"] + 0
    combined_ready = $idx["combined_ready"] + 0
    promotion_routing = $idx["routing_trigger_rate"] + 0
    promotion_jump = $idx["active_jump_rate"] + 0
    next
  }
  FILENAME == adapter_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) aidx[$i] = i
    required_count = split("benchmark_families benchmark_adapter_ready external_benchmark_source_ready external_benchmark_result_ready external_benchmark_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in aidx)) {
        printf "missing v08 readiness adapter column: %s\n", required[i] > "/dev/stderr"
        exit 4
      }
    }
    next
  }
  FILENAME == adapter_csv {
    adapter_rows++
    benchmark_families = $aidx["benchmark_families"] + 0
    benchmark_adapter_ready = $aidx["benchmark_adapter_ready"] + 0
    external_benchmark_source_ready = $aidx["external_benchmark_source_ready"] + 0
    external_benchmark_result_ready = $aidx["external_benchmark_result_ready"] + 0
    adapter_external_ready = $aidx["external_benchmark_ready"] + 0
    adapter_routing = $aidx["routing_trigger_rate"] + 0
    adapter_jump = $aidx["active_jump_rate"] + 0
    next
  }
  END {
    if (source_rows != 1) {
      print "expected one v08 readiness source row" > "/dev/stderr"
      exit 3
    }
    if (adapter_rows != 1) {
      print "expected one v08 benchmark adapter row" > "/dev/stderr"
      exit 5
    }

    external_ready = 0
    if (default_promotion == 1 &&
        promotion_status == "promotion-candidate" &&
        benchmark_adapter_ready == 1 &&
        external_benchmark_source_ready == 1 &&
        external_benchmark_result_ready == 1 &&
        adapter_external_ready == 1) {
      external_ready = 1
    }
    action = "run-external-comparison"
    if (!benchmark_adapter_ready) {
      action = "build-external-benchmark-adapter"
    } else if (!default_promotion) {
      action = "defer-external-comparison"
    } else if (!external_benchmark_source_ready) {
      action = "external-benchmark-source-missing"
    } else if (!external_benchmark_result_ready) {
      action = "external-benchmark-results-missing"
    } else if (!adapter_external_ready) {
      action = "external-benchmark-adapter-blocked"
    }

    print "benchmark_scope,benchmark_families,adaptive_scale_safe,chunk_ready,source_safe,combined_ready,default_promotion,benchmark_adapter_ready,external_benchmark_source_ready,external_benchmark_result_ready,external_benchmark_ready,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      benchmark_families,
      adaptive_scale_safe,
      chunk_ready,
      source_safe,
      combined_ready,
      default_promotion,
      benchmark_adapter_ready,
      external_benchmark_source_ready,
      external_benchmark_result_ready,
      external_ready,
      action,
      promotion_routing + adapter_routing,
      promotion_jump + adapter_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "promotion-gate,%s,source_status=%s\n",
      default_promotion ? "pass" : "blocked",
      promotion_status >> decision_csv
    printf "benchmark-adapter,%s,families=%d\n",
      benchmark_adapter_ready ? "pass" : "blocked",
      benchmark_families >> decision_csv
    printf "benchmark-source,%s,source_ready=%d\n",
      external_benchmark_source_ready ? "pass" : "blocked",
      external_benchmark_source_ready >> decision_csv
    printf "benchmark-results,%s,result_ready=%d\n",
      external_benchmark_result_ready ? "pass" : "blocked",
      external_benchmark_result_ready >> decision_csv
    printf "external-benchmark,%s,action=%s\n",
      external_ready ? "ready" : "deferred",
      action >> decision_csv
  }
' "$SOURCE_SUMMARY_CSV" "$ADAPTER_SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
