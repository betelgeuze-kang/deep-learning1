#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_adapter.sh" --smoke
"$ROOT_DIR/experiments/run_v08_external_benchmark_readiness.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_readiness_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_readiness_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families default_promotion benchmark_adapter_ready external_benchmark_source_ready external_benchmark_result_ready external_benchmark_ready action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 readiness summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["benchmark_families"] + 0) != 4 ||
        ($idx["benchmark_adapter_ready"] + 0) != 1 ||
        ($idx["external_benchmark_source_ready"] + 0) != 0 ||
        ($idx["external_benchmark_result_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        ($idx["external_benchmark_ready"] + 0) != 0) {
      die("external benchmark should have adapter coverage but remain source/result/promotion blocked", 3)
    }
    if ($idx["action"] != "defer-external-comparison") {
      die("v08 readiness action should defer external comparison", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08 readiness summary row", 6)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx)) die("missing v08 readiness decision columns", 20)
    next
  }
  {
    rows++
    if ($idx["gate"] == "external-benchmark" && $idx["status"] != "deferred") {
      die("external benchmark gate should be deferred", 21)
    }
    if ($idx["gate"] == "benchmark-adapter" && $idx["status"] != "pass") die("benchmark adapter should pass", 23)
    if ($idx["gate"] == "benchmark-source" && $idx["status"] != "blocked") die("benchmark source should remain blocked", 24)
    if ($idx["gate"] == "benchmark-results" && $idx["status"] != "blocked") die("benchmark results should remain blocked", 25)
    if ($idx["gate"] == "promotion-gate") promotion_seen++
    if ($idx["gate"] == "benchmark-adapter") adapter_seen++
    if ($idx["gate"] == "benchmark-source") source_seen++
    if ($idx["gate"] == "benchmark-results") results_seen++
    if ($idx["gate"] == "external-benchmark") external_seen++
  }
  END {
    if (rows != 5) die("expected exactly five v08 readiness decision rows", 22)
    if (promotion_seen != 1 || adapter_seen != 1 || source_seen != 1 || results_seen != 1 || external_seen != 1) {
      die("expected required v08 readiness gates exactly once", 26)
    }
  }
' "$DECISION_CSV"

echo "v08 external benchmark readiness smoke passed"
