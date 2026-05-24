#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_CSV="$RESULTS_DIR/v08_external_benchmark_real_evidence_placeholder_fixture.csv"

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
  "$ROOT_DIR/experiments/run_v08_external_benchmark_real_evidence_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_real_evidence_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_real_evidence_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("evidence_source external_benchmark_ready ready_rows real_dataset_uri_rows real_result_uri_rows source_hash_rows provenance_hash_rows baseline_rows metric_rows evaluator_rows license_rows real_evidence_format_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 real evidence placeholder summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["evidence_source"] != "provided-csv" ||
        ($idx["external_benchmark_ready"] + 0) != 1 ||
        ($idx["ready_rows"] + 0) != 4 ||
        ($idx["real_dataset_uri_rows"] + 0) != 0 ||
        ($idx["real_result_uri_rows"] + 0) != 0 ||
        ($idx["source_hash_rows"] + 0) != 0 ||
        ($idx["provenance_hash_rows"] + 0) != 0 ||
        ($idx["baseline_rows"] + 0) != 4 ||
        ($idx["metric_rows"] + 0) != 4 ||
        ($idx["evaluator_rows"] + 0) != 4 ||
        ($idx["license_rows"] + 0) != 4 ||
        ($idx["real_evidence_format_ready"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "fixture-evidence-not-real-benchmark") {
      die("placeholder v08 supplied evidence should not pass the real benchmark gate", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 real evidence placeholder", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 real evidence placeholder row", 5)
  }
' "$SUMMARY_CSV"

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
    if ($idx["gate"] == "supplied-evidence" && $idx["status"] != "pass") die("supplied placeholder evidence should pass supplied-evidence", 20)
    if ($idx["gate"] == "real-uri-format" && $idx["status"] != "blocked") die("placeholder URIs should block real-uri-format", 21)
    if ($idx["gate"] == "provenance-format" && $idx["status"] != "blocked") die("placeholder hashes should block provenance-format", 22)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block for placeholder evidence", 23)
  }
  END {
    if (rows < 6) die("expected v08 real evidence placeholder decision rows", 24)
  }
' "$DECISION_CSV"

echo "v08 external benchmark real evidence placeholder smoke passed"
