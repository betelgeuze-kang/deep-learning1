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
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_readiness_smoke"
  SOURCE_PREFIX="v07_route_memory_promotion_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
if [[ ! -s "$SOURCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  NR == 1 {
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
  {
    rows++
    default_promotion = $idx["default_promotion"] + 0
    external_ready = default_promotion == 1 && $idx["status"] == "promotion-candidate" ? 1 : 0
    action = external_ready ? "run-external-comparison" : "defer-external-comparison"
    print "benchmark_scope,adaptive_scale_safe,chunk_ready,source_safe,combined_ready,default_promotion,external_benchmark_ready,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      $idx["adaptive_scale_safe"] + 0,
      $idx["chunk_ready"] + 0,
      $idx["source_safe"] + 0,
      $idx["combined_ready"] + 0,
      default_promotion,
      external_ready,
      action,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0 >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "promotion-gate,%s,source_status=%s\n",
      default_promotion ? "pass" : "blocked",
      $idx["status"] >> decision_csv
    printf "external-benchmark,%s,action=%s\n",
      external_ready ? "ready" : "deferred",
      action >> decision_csv
  }
  END {
    if (rows != 1) {
      print "expected one v08 readiness source row" > "/dev/stderr"
      exit 3
    }
  }
' "$SOURCE_SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
