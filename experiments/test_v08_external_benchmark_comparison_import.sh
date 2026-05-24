#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_import_fixture.csv"

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
V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_comparison_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_summary.csv"
COMPARISON_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_comparison.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope comparison_input_ready benchmark_comparison_ready publishable_comparison_ready default_promotion evidence_source comparable_rows route_memory_wins route_memory_losses route_memory_ties mean_delta action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 comparison import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08e" ||
        ($idx["comparison_input_ready"] + 0) != 1 ||
        ($idx["benchmark_comparison_ready"] + 0) != 1 ||
        ($idx["publishable_comparison_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["evidence_source"] != "provided-csv" ||
        ($idx["comparable_rows"] + 0) != 4 ||
        ($idx["route_memory_wins"] + 0) != 0 ||
        ($idx["route_memory_losses"] + 0) != 4 ||
        ($idx["route_memory_ties"] + 0) != 0 ||
        ($idx["mean_delta"] + 0) >= 0 ||
        $idx["action"] != "diagnostic-comparison-only") {
      die("supplied v08 comparison should compute diagnostic losses but stay unpublished before promotion", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 comparison import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 comparison import summary row", 5)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("verdict" in idx)) die("missing v08 comparison verdict column", 20)
    next
  }
  {
    rows++
    if ($idx["verdict"] == "route-memory-loss") losses++
  }
  END {
    if (rows != 4 || losses != 4) die("expected four route-memory loss comparison rows", 21)
  }
' "$COMPARISON_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "comparison-input" && $idx["status"] != "pass") die("comparison input should pass", 30)
    if ($idx["gate"] == "comparison-diagnostic" && $idx["status"] != "pass") die("diagnostic comparison should pass", 31)
    if ($idx["gate"] == "comparison-publish" && $idx["status"] != "blocked") die("comparison publish should remain blocked", 32)
    if ($idx["gate"] == "external-comparison" && $idx["status"] != "deferred") die("external comparison should remain deferred", 33)
  }
  END {
    if (rows != 5) die("expected v08 comparison import decision rows", 34)
  }
' "$DECISION_CSV"

echo "v08 external benchmark comparison import smoke passed"
