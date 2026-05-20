#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

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
    required_count = split("benchmark_scope default_promotion external_benchmark_ready action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 readiness summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["default_promotion"] + 0) != 0 ||
        ($idx["external_benchmark_ready"] + 0) != 0) {
      die("external benchmark should remain deferred until promotion gate passes", 3)
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
  }
  END {
    if (rows < 2) die("expected v08 readiness decision rows", 22)
  }
' "$DECISION_CSV"

echo "v08 external benchmark readiness smoke passed"
