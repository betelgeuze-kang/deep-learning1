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

PREFIX="v08_external_benchmark_real_evidence_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_real_evidence_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

EVIDENCE_SUMMARY_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_summary.csv"
EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi
"$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" "${RUN_ARGS[@]}" >/dev/null

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v evidence_summary_csv="$EVIDENCE_SUMMARY_CSV" -v evidence_csv="$EVIDENCE_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function is_real_uri(value) {
    return value != "" &&
      value != "pending" &&
      value ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\// &&
      value !~ /^external:\/\// &&
      value !~ /^fixture:\/\//
  }
  function is_sha256(value, hex) {
    if (substr(value, 1, 7) != "sha256:") return 0
    hex = substr(value, 8)
    return length(hex) == 64 && hex !~ /[^0-9a-fA-F]/
  }
  FILENAME == evidence_summary_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("benchmark_families benchmark_evidence_schema_ready external_benchmark_ready evidence_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing v08 real evidence summary column: " required[i], 2)
    }
    next
  }
  FILENAME == evidence_summary_csv {
    summary_rows++
    benchmark_families = $sidx["benchmark_families"] + 0
    benchmark_evidence_schema_ready = $sidx["benchmark_evidence_schema_ready"] + 0
    external_benchmark_ready = $sidx["external_benchmark_ready"] + 0
    evidence_source = $sidx["evidence_source"]
    summary_routing = $sidx["routing_trigger_rate"] + 0
    summary_jump = $sidx["active_jump_rate"] + 0
    next
  }
  FILENAME == evidence_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("benchmark_family dataset_uri split_name license source_hash baseline_name baseline_metric route_memory_metric result_uri evaluator_version provenance_hash source_ready result_ready baseline_ready license_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing v08 real evidence row column: " required[i], 3)
    }
    next
  }
  FILENAME == evidence_csv {
    evidence_rows++
    row_ready = (($eidx["source_ready"] + 0) == 1 &&
      ($eidx["result_ready"] + 0) == 1 &&
      ($eidx["baseline_ready"] + 0) == 1 &&
      ($eidx["license_ready"] + 0) == 1)
    if (row_ready) ready_rows++
    if (is_real_uri($eidx["dataset_uri"])) real_dataset_uri_rows++
    if (is_real_uri($eidx["result_uri"])) real_result_uri_rows++
    if (is_sha256($eidx["source_hash"])) source_hash_rows++
    if (is_sha256($eidx["provenance_hash"])) provenance_hash_rows++
    if ($eidx["baseline_name"] != "" && $eidx["baseline_name"] != "pending") baseline_rows++
    if ($eidx["baseline_metric"] != "pending" && $eidx["route_memory_metric"] != "pending") metric_rows++
    if ($eidx["evaluator_version"] != "" && $eidx["evaluator_version"] != "pending") evaluator_rows++
    if ($eidx["license"] != "" && $eidx["license"] != "pending") license_rows++
    evidence_routing += $eidx["routing_trigger_rate"] + 0
    evidence_jump += $eidx["active_jump_rate"] + 0
    next
  }
  END {
    if (summary_rows != 1) die("expected one v08 real evidence summary row", 4)
    if (evidence_rows != 4) die("expected four v08 real evidence rows", 5)

    real_evidence_format_ready = 0
    if (benchmark_evidence_schema_ready == 1 &&
        external_benchmark_ready == 1 &&
        ready_rows == benchmark_families &&
        real_dataset_uri_rows == benchmark_families &&
        real_result_uri_rows == benchmark_families &&
        source_hash_rows == benchmark_families &&
        provenance_hash_rows == benchmark_families &&
        baseline_rows == benchmark_families &&
        metric_rows == benchmark_families &&
        evaluator_rows == benchmark_families &&
        license_rows == benchmark_families &&
        evidence_routing == 0.0 &&
        evidence_jump == 0.0) {
      real_evidence_format_ready = 1
    }

    real_external_benchmark_verified = 0
    action = "external-benchmark-real-evidence-missing"
    if (external_benchmark_ready == 1 && !real_evidence_format_ready) {
      action = "fixture-evidence-not-real-benchmark"
    } else if (real_evidence_format_ready) {
      action = "real-benchmark-verifier-missing"
    }

    print "benchmark_scope,benchmark_families,evidence_source,benchmark_evidence_schema_ready,external_benchmark_ready,ready_rows,real_dataset_uri_rows,real_result_uri_rows,source_hash_rows,provenance_hash_rows,baseline_rows,metric_rows,evaluator_rows,license_rows,real_evidence_format_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08f,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      benchmark_families,
      evidence_source,
      benchmark_evidence_schema_ready,
      external_benchmark_ready,
      ready_rows,
      real_dataset_uri_rows,
      real_result_uri_rows,
      source_hash_rows,
      provenance_hash_rows,
      baseline_rows,
      metric_rows,
      evaluator_rows,
      license_rows,
      real_evidence_format_ready,
      real_external_benchmark_verified,
      action,
      summary_routing + evidence_routing,
      summary_jump + evidence_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "evidence-schema,%s,schema_ready=%d\n",
      benchmark_evidence_schema_ready ? "pass" : "blocked",
      benchmark_evidence_schema_ready >> decision_csv
    printf "supplied-evidence,%s,external_benchmark_ready=%d ready_rows=%d\n",
      external_benchmark_ready ? "pass" : "blocked",
      external_benchmark_ready,
      ready_rows >> decision_csv
    printf "real-uri-format,%s,dataset_rows=%d result_rows=%d\n",
      (real_dataset_uri_rows == benchmark_families && real_result_uri_rows == benchmark_families) ? "pass" : "blocked",
      real_dataset_uri_rows,
      real_result_uri_rows >> decision_csv
    printf "provenance-format,%s,source_hash_rows=%d provenance_hash_rows=%d\n",
      (source_hash_rows == benchmark_families && provenance_hash_rows == benchmark_families) ? "pass" : "blocked",
      source_hash_rows,
      provenance_hash_rows >> decision_csv
    printf "real-evidence-format,%s,format_ready=%d\n",
      real_evidence_format_ready ? "pass" : "blocked",
      real_evidence_format_ready >> decision_csv
    printf "real-external-benchmark,%s,action=%s\n",
      real_external_benchmark_verified ? "ready" : "blocked",
      action >> decision_csv
  }
' "$EVIDENCE_SUMMARY_CSV" "$EVIDENCE_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
