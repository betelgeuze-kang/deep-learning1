#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_CSV="$RESULTS_DIR/v08_external_benchmark_evidence_import_fixture.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_CSV" <<'CSV'
benchmark_family,dataset_uri,split_name,license,source_hash,baseline_name,baseline_metric,route_memory_metric,result_uri,evaluator_version,provenance_hash,source_ready,result_ready,baseline_ready,license_ready,routing_trigger_rate,active_jump_rate
RULER,external://ruler/dev,dev,permissive,sha256-ruler,baseline-transformer,0.720000,0.710000,external://results/ruler,v08-evidence-v1,prov-ruler,1,1,1,1,0,0
LongBench,external://longbench/dev,dev,permissive,sha256-longbench,baseline-transformer,0.610000,0.590000,external://results/longbench,v08-evidence-v1,prov-longbench,1,1,1,1,0,0
codebase-retrieval,external://codebase/dev,dev,permissive,sha256-codebase,baseline-vector,0.540000,0.520000,external://results/codebase,v08-evidence-v1,prov-codebase,1,1,1,1,0,0
real-document-qa,external://docqa/dev,dev,permissive,sha256-docqa,baseline-rag,0.480000,0.470000,external://results/docqa,v08-evidence-v1,prov-docqa,1,1,1,1,0,0
CSV

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$FIXTURE_CSV" \
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
    required_count = split("benchmark_scope benchmark_families benchmark_adapter_ready benchmark_evidence_schema_ready external_benchmark_source_ready external_benchmark_result_ready external_benchmark_ready source_evidence_rows result_evidence_rows baseline_evidence_rows license_evidence_rows populated_source_rows populated_result_rows populated_baseline_rows populated_license_rows evidence_source action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 benchmark evidence import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v08 benchmark evidence import summary row has wrong column count", 3)
    if ($idx["benchmark_scope"] != "route-memory-v08c" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        ($idx["benchmark_adapter_ready"] + 0) != 1 ||
        ($idx["benchmark_evidence_schema_ready"] + 0) != 1 ||
        ($idx["external_benchmark_source_ready"] + 0) != 1 ||
        ($idx["external_benchmark_result_ready"] + 0) != 1 ||
        ($idx["external_benchmark_ready"] + 0) != 1 ||
        ($idx["source_evidence_rows"] + 0) != 4 ||
        ($idx["result_evidence_rows"] + 0) != 4 ||
        ($idx["baseline_evidence_rows"] + 0) != 4 ||
        ($idx["license_evidence_rows"] + 0) != 4 ||
        ($idx["populated_source_rows"] + 0) != 4 ||
        ($idx["populated_result_rows"] + 0) != 4 ||
        ($idx["populated_baseline_rows"] + 0) != 4 ||
        ($idx["populated_license_rows"] + 0) != 4 ||
        $idx["evidence_source"] != "provided-csv" ||
        $idx["action"] != "run-external-comparison") {
      die("v08 benchmark evidence import should mark complete supplied evidence ready", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 benchmark evidence import", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08 benchmark evidence import summary row", 6)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx)) die("missing v08 benchmark evidence import decision columns", 20)
    next
  }
  {
    rows++
    if ($idx["gate"] == "benchmark-source" && $idx["status"] != "pass") die("benchmark source should pass under supplied evidence", 21)
    if ($idx["gate"] == "benchmark-results" && $idx["status"] != "pass") die("benchmark results should pass under supplied evidence", 22)
    if ($idx["gate"] == "external-benchmark" && $idx["status"] != "ready") die("external benchmark should be ready under supplied evidence", 23)
  }
  END {
    if (rows != 5) die("expected v08 benchmark evidence import decision rows", 24)
  }
' "$DECISION_CSV"

echo "v08 external benchmark evidence import smoke passed"
