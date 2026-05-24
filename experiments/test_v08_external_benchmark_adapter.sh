#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_adapter.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_adapter_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_adapter_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families adapter_rows benchmark_adapter_ready external_benchmark_source_ready external_benchmark_result_ready external_benchmark_ready source_ready_rows result_ready_rows baseline_ready_rows license_ready_rows action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 benchmark adapter summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v08 benchmark adapter summary row has wrong column count", 3)
    if ($idx["benchmark_scope"] != "route-memory-v08b" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        ($idx["adapter_rows"] + 0) != 4 ||
        ($idx["benchmark_adapter_ready"] + 0) != 1) {
      die("v08 benchmark adapter should cover RULER, LongBench, codebase retrieval, and real document QA schemas", 4)
    }
    if (($idx["external_benchmark_source_ready"] + 0) != 0 ||
        ($idx["external_benchmark_result_ready"] + 0) != 0 ||
        ($idx["external_benchmark_ready"] + 0) != 0 ||
        ($idx["source_ready_rows"] + 0) != 0 ||
        ($idx["result_ready_rows"] + 0) != 0 ||
        ($idx["baseline_ready_rows"] + 0) != 0 ||
        ($idx["license_ready_rows"] + 0) != 0 ||
        $idx["action"] != "adapter-ready-source-missing") {
      die("v08 benchmark adapter must not claim external sources/results", 5)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 benchmark adapter", 6)
    }
  }
  END {
    if (rows != 1) die("expected one v08 benchmark adapter summary row", 7)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing v08 benchmark adapter decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "benchmark-adapter" && $idx["status"] != "pass") die("benchmark adapter should pass", 21)
    if ($idx["gate"] == "benchmark-source" && $idx["status"] != "blocked") die("benchmark source should remain blocked", 22)
    if ($idx["gate"] == "benchmark-results" && $idx["status"] != "blocked") die("benchmark results should remain blocked", 23)
    if ($idx["gate"] == "external-benchmark" && $idx["status"] != "deferred") die("external benchmark should remain deferred", 24)
    if ($idx["gate"] == "benchmark-adapter") adapter_seen++
    if ($idx["gate"] == "benchmark-source") source_seen++
    if ($idx["gate"] == "benchmark-results") results_seen++
    if ($idx["gate"] == "external-benchmark") external_seen++
  }
  END {
    if (rows != 4) die("expected exactly four v08 benchmark adapter decision rows", 25)
    if (adapter_seen != 1 || source_seen != 1 || results_seen != 1 || external_seen != 1) {
      die("expected required v08 benchmark adapter gates exactly once", 26)
    }
  }
' "$DECISION_CSV"

echo "v08 external benchmark adapter smoke passed"
