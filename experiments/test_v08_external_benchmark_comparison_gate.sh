#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" --smoke
"$ROOT_DIR/experiments/run_v08_external_benchmark_comparison_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families comparison_schema_ready comparison_input_ready benchmark_comparison_ready publishable_comparison_ready default_promotion evidence_source comparable_rows action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 benchmark comparison summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08e" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        ($idx["comparison_schema_ready"] + 0) != 1 ||
        ($idx["comparison_input_ready"] + 0) != 0 ||
        ($idx["benchmark_comparison_ready"] + 0) != 0 ||
        ($idx["publishable_comparison_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["evidence_source"] != "pending-fixture" ||
        ($idx["comparable_rows"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-source-missing") {
      die("default v08 benchmark comparison should remain evidence blocked", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 benchmark comparison", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 benchmark comparison summary row", 5)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx)) die("missing v08 comparison decision columns", 20)
    next
  }
  {
    rows++
    if ($idx["gate"] == "comparison-schema" && $idx["status"] != "pass") die("comparison schema should pass", 21)
    if ($idx["gate"] == "comparison-input" && $idx["status"] != "blocked") die("comparison input should remain blocked", 22)
    if ($idx["gate"] == "comparison-publish" && $idx["status"] != "blocked") die("comparison publish should remain blocked", 23)
  }
  END {
    if (rows != 5) die("expected v08 comparison decision rows", 24)
  }
' "$DECISION_CSV"

echo "v08 external benchmark comparison gate smoke passed"
