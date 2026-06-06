#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_resource_envelope_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_resource_envelope_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
RESOURCE_PACKET_DIR="$RESULTS_DIR/v13_resource_envelope_smoke_packet/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_resource_envelope_bad_hash_run"
BAD_SPEEDUP_RUN_DIR="$RESULTS_DIR/v13_resource_envelope_bad_speedup_run"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v13-f summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-f summary row", 4)
    }
  ' "$summary_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-f file: $path" >&2
    exit 10
  fi
}

rewrite_hash_manifest() {
  local dir="$1"
  (
    cd "$dir"
    find . -type f ! -path './sha256sums.txt' -print | sort | while IFS= read -r file; do
      sha256sum "${file#./}"
    done
  ) >"$dir/sha256sums.txt"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_resource_envelope.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-f source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-f run hash"
expect_summary_value "$SUMMARY_CSV" "routeqa_packet_hash_ready" "1" "v13-f routeqa packet hash"
expect_summary_value "$SUMMARY_CSV" "public_codebase_routeqa_ready" "1" "v13-f routeqa ready"
expect_summary_value "$SUMMARY_CSV" "workload_rows" "1" "v13-f workload rows"
expect_summary_value "$SUMMARY_CSV" "resource_rows" "1" "v13-f resource rows"
expect_summary_value "$SUMMARY_CSV" "workload_artifact_rows" "1" "v13-f workload artifacts"
expect_summary_value "$SUMMARY_CSV" "nlg_result_hash_verified_rows" "1" "v13-f NLG hash"
expect_summary_value "$SUMMARY_CSV" "timing_artifact_hash_verified_rows" "1" "v13-f timing hash"
expect_summary_value "$SUMMARY_CSV" "environment_hash_verified_rows" "1" "v13-f environment hash"
expect_summary_value "$SUMMARY_CSV" "run_nlg_result_hash_match_rows" "1" "v13-f run NLG binding"
expect_summary_value "$SUMMARY_CSV" "workload_ready_rows" "1" "v13-f workload ready"
expect_summary_value "$SUMMARY_CSV" "metrics_positive_rows" "1" "v13-f metrics positive"
expect_summary_value "$SUMMARY_CSV" "speedup_positive_rows" "1" "v13-f speedup positive"
expect_summary_value "$SUMMARY_CSV" "measurement_source_fixture_rows" "1" "v13-f fixture source"
expect_summary_value "$SUMMARY_CSV" "real_hip_measurement_rows" "0" "v13-f real HIP"
expect_summary_value "$SUMMARY_CSV" "real_nvme_measurement_rows" "0" "v13-f real NVMe"
expect_summary_value "$SUMMARY_CSV" "non_fixture_workload_rows" "0" "v13-f nonfixture"
expect_summary_value "$SUMMARY_CSV" "benchmark_or_product_trace_verified_rows" "0" "v13-f benchmark trace"
expect_summary_value "$SUMMARY_CSV" "cpu_median_ms" "12.000000" "v13-f CPU median"
expect_summary_value "$SUMMARY_CSV" "hip_median_ms" "8.000000" "v13-f HIP median"
expect_summary_value "$SUMMARY_CSV" "median_speedup" "1.500000" "v13-f speedup"
expect_summary_value "$SUMMARY_CSV" "nvme_read_median_ms" "0.180000" "v13-f NVMe read"
expect_summary_value "$SUMMARY_CSV" "query_to_evidence_ms" "0.420000" "v13-f query evidence"
expect_summary_value "$SUMMARY_CSV" "query_to_first_token_ms" "4.000000" "v13-f first token"
expect_summary_value "$SUMMARY_CSV" "tokens_per_second_after_retrieval" "48.666667" "v13-f tokens"
expect_summary_value "$SUMMARY_CSV" "ssd_bytes_per_query" "64.000000" "v13-f SSD bytes"
expect_summary_value "$SUMMARY_CSV" "ram_used_gb" "0.031250" "v13-f RAM"
expect_summary_value "$SUMMARY_CSV" "vram_used_gb" "0.000000" "v13-f VRAM"
expect_summary_value "$SUMMARY_CSV" "h9h_diagnostic_workload_speed_ready" "1" "v13-f h9h diagnostic"
expect_summary_value "$SUMMARY_CSV" "h9h_real_workload_speed_evidence_ready" "0" "v13-f h9h real"
expect_summary_value "$SUMMARY_CSV" "h11d_real_pc_routelm_nlg_verified" "0" "v13-f h11d real"
expect_summary_value "$SUMMARY_CSV" "resource_packet_hash_ready" "1" "v13-f packet hash"
expect_summary_value "$SUMMARY_CSV" "diagnostic_resource_envelope_ready" "1" "v13-f diagnostic ready"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "1" "v13-f ready"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-f nonfixture"
expect_summary_value "$SUMMARY_CSV" "real_workload_speed_evidence_ready" "0" "v13-f real speed"
expect_summary_value "$SUMMARY_CSV" "gpu_speedup_claim" "deferred" "v13-f GPU claim"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-f release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-resource-envelope-bound-await-real-measurements" "v13-f action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-f routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-f jump"

expect_file "$RESOURCE_PACKET_DIR/resource_rows.csv"
expect_file "$RESOURCE_PACKET_DIR/resource_manifest.json"
expect_file "$RESOURCE_PACKET_DIR/sha256sums.txt"

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
    if ($idx["nlg_result_hash_verified"] != "1") die("v13-f NLG artifact hash should bind", 20)
    if ($idx["timing_artifact_hash_verified"] != "1") die("v13-f timing hash should bind", 21)
    if ($idx["environment_hash_verified"] != "1") die("v13-f environment hash should bind", 22)
    if ($idx["speedup_positive"] != "1") die("v13-f diagnostic speedup should be positive", 23)
    if ($idx["real_hip_measurement"] != "0") die("v13-f real HIP should stay blocked", 24)
  }
  END {
    if (rows != 1) die("expected one v13-f resource row", 25)
  }
' "$RESOURCE_PACKET_DIR/resource_rows.csv"

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
    if ($idx["gate"] == "run-hash-manifest" && $idx["status"] != "pass") die("v13-f run hash should pass", 30)
    if ($idx["gate"] == "routeqa-chain" && $idx["status"] != "pass") die("v13-f routeqa should pass", 31)
    if ($idx["gate"] == "workload-artifact-hashes" && $idx["status"] != "pass") die("v13-f workload hashes should pass", 32)
    if ($idx["gate"] == "run-nlg-result-binding" && $idx["status"] != "pass") die("v13-f run NLG should pass", 33)
    if ($idx["gate"] == "diagnostic-speed-envelope" && $idx["status"] != "pass") die("v13-f diagnostic envelope should pass", 34)
    if ($idx["gate"] == "real-measurement-source" && $idx["status"] != "blocked") die("v13-f real measurement should block", 35)
    if ($idx["gate"] == "v13-resource-envelope" && $idx["status"] != "pass") die("v13-f final gate should pass", 36)
  }
  END {
    if (rows != 9) die("expected v13-f decision rows", 37)
  }
' "$DECISION_CSV"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\n' >>"$BAD_HASH_RUN_DIR/speed/workload.csv"
V13_RESOURCE_ENVELOPE_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_resource_envelope.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-f bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-f bad run hash"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "0" "v13-f bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-resource-envelope-run-hash-mismatch" "v13-f bad hash action"

rm -rf "$BAD_SPEEDUP_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_SPEEDUP_RUN_DIR"
awk -F, 'BEGIN { OFS = "," }
  NR == 1 { print; next }
  NR == 2 { $11 = "13.000000" }
  { print }
' "$BAD_SPEEDUP_RUN_DIR/speed/workload.csv" >"$BAD_SPEEDUP_RUN_DIR/speed/workload.tmp"
mv "$BAD_SPEEDUP_RUN_DIR/speed/workload.tmp" "$BAD_SPEEDUP_RUN_DIR/speed/workload.csv"
rewrite_hash_manifest "$BAD_SPEEDUP_RUN_DIR"
V13_RESOURCE_ENVELOPE_RUN_DIR="$BAD_SPEEDUP_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_resource_envelope.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-f bad-speedup source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-f bad-speedup run hash"
expect_summary_value "$SUMMARY_CSV" "hip_median_ms" "13.000000" "v13-f bad-speedup HIP median"
expect_summary_value "$SUMMARY_CSV" "median_speedup" "0.923077" "v13-f bad-speedup speedup"
expect_summary_value "$SUMMARY_CSV" "speedup_positive_rows" "0" "v13-f bad-speedup positive rows"
expect_summary_value "$SUMMARY_CSV" "diagnostic_resource_envelope_ready" "0" "v13-f bad-speedup diagnostic"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "0" "v13-f bad-speedup should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-resource-envelope-speedup-not-demonstrated" "v13-f bad-speedup action"

"$ROOT_DIR/experiments/run_v13_resource_envelope.sh" --smoke >/dev/null

echo "v13 resource envelope smoke passed"
