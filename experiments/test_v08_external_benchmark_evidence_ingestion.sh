#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_evidence_ingestion_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_evidence_ingestion_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families benchmark_adapter_ready benchmark_evidence_schema_ready external_benchmark_source_ready external_benchmark_result_ready external_benchmark_ready source_evidence_rows result_evidence_rows baseline_evidence_rows license_evidence_rows action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 benchmark evidence summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v08 benchmark evidence summary row has wrong column count", 3)
    if ($idx["benchmark_scope"] != "route-memory-v08c" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        ($idx["benchmark_adapter_ready"] + 0) != 1 ||
        ($idx["benchmark_evidence_schema_ready"] + 0) != 1) {
      die("v08 benchmark evidence schema should cover all required families", 4)
    }
    if (($idx["external_benchmark_source_ready"] + 0) != 0 ||
        ($idx["external_benchmark_result_ready"] + 0) != 0 ||
        ($idx["external_benchmark_ready"] + 0) != 0 ||
        ($idx["source_evidence_rows"] + 0) != 0 ||
        ($idx["result_evidence_rows"] + 0) != 0 ||
        ($idx["baseline_evidence_rows"] + 0) != 0 ||
        ($idx["license_evidence_rows"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-source-missing") {
      die("v08 benchmark evidence ingestion must not claim external evidence", 5)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 benchmark evidence", 6)
    }
  }
  END {
    if (rows != 1) die("expected one v08 benchmark evidence summary row", 7)
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
      die("missing v08 benchmark evidence decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "benchmark-adapter" && $idx["status"] != "pass") die("benchmark adapter should pass", 21)
    if ($idx["gate"] == "benchmark-evidence-schema" && $idx["status"] != "pass") die("benchmark evidence schema should pass", 22)
    if ($idx["gate"] == "benchmark-source" && $idx["status"] != "blocked") die("benchmark source should remain blocked", 23)
    if ($idx["gate"] == "benchmark-results" && $idx["status"] != "blocked") die("benchmark results should remain blocked", 24)
    if ($idx["gate"] == "external-benchmark" && $idx["status"] != "deferred") die("external benchmark should remain deferred", 25)
    if ($idx["gate"] == "benchmark-adapter") adapter_seen++
    if ($idx["gate"] == "benchmark-evidence-schema") schema_seen++
    if ($idx["gate"] == "benchmark-source") source_seen++
    if ($idx["gate"] == "benchmark-results") results_seen++
    if ($idx["gate"] == "external-benchmark") external_seen++
  }
  END {
    if (rows != 5) die("expected exactly five v08 benchmark evidence decision rows", 26)
    if (adapter_seen != 1 || schema_seen != 1 || source_seen != 1 || results_seen != 1 || external_seen != 1) {
      die("expected required v08 benchmark evidence gates exactly once", 27)
    }
  }
' "$DECISION_CSV"

echo "v08 external benchmark evidence ingestion smoke passed"
