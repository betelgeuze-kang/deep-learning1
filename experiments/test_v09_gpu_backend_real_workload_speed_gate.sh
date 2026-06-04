#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

BAD_WORKLOAD_CSV="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_bad_hash_fixture.csv"
MALFORMED_WORKLOAD_CSV="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_malformed_fixture.csv"

"$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_gate_smoke_decision.csv"
GOOD_WORKLOAD_CSV="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_gate_smoke_workload.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scope workload_source workload_rows diagnostic_artifact_ready pc_routelm_nlg_smoke_ready real_pc_routelm_nlg_verified h9_measured_speed_evidence_ready h9_speed_evidence_ready workload_artifact_rows nlg_result_hash_verified_rows timing_artifact_hash_verified_rows environment_hash_verified_rows workload_ready_rows metrics_positive_rows real_hip_measurement_rows real_nvme_measurement_rows non_fixture_workload_rows benchmark_or_product_trace_verified_rows speedup_positive_rows cpu_median_ms hip_median_ms median_speedup nvme_read_median_ms query_to_evidence_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb diagnostic_workload_speed_ready real_workload_speed_evidence_ready gpu_speedup_claim action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h9-h summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h9-h summary row has wrong column count", 3)
    if ($idx["scope"] != "h9h-real-workload-speed" ||
        $idx["workload_source"] != "generated-fixture" ||
        ($idx["workload_rows"] + 0) != 1 ||
        ($idx["diagnostic_artifact_ready"] + 0) != 1 ||
        ($idx["pc_routelm_nlg_smoke_ready"] + 0) != 1 ||
        ($idx["real_pc_routelm_nlg_verified"] + 0) != 0 ||
        ($idx["h9_measured_speed_evidence_ready"] + 0) != 0 ||
        ($idx["h9_speed_evidence_ready"] + 0) != 0 ||
        ($idx["workload_artifact_rows"] + 0) != 1 ||
        ($idx["nlg_result_hash_verified_rows"] + 0) != 1 ||
        ($idx["timing_artifact_hash_verified_rows"] + 0) != 1 ||
        ($idx["environment_hash_verified_rows"] + 0) != 1 ||
        ($idx["workload_ready_rows"] + 0) != 1 ||
        ($idx["metrics_positive_rows"] + 0) != 1 ||
        ($idx["real_hip_measurement_rows"] + 0) != 0 ||
        ($idx["real_nvme_measurement_rows"] + 0) != 0 ||
        ($idx["non_fixture_workload_rows"] + 0) != 0 ||
        ($idx["benchmark_or_product_trace_verified_rows"] + 0) != 0 ||
        ($idx["speedup_positive_rows"] + 0) != 1 ||
        ($idx["cpu_median_ms"] + 0) != 12.0 ||
        ($idx["hip_median_ms"] + 0) != 8.0 ||
        ($idx["median_speedup"] + 0) != 1.5 ||
        ($idx["nvme_read_median_ms"] + 0) != 0.18 ||
        ($idx["query_to_evidence_ms"] + 0) != 0.42 ||
        ($idx["query_to_first_token_ms"] + 0) != 4.0 ||
        ($idx["tokens_per_second_after_retrieval"] + 0) <= 0.0 ||
        ($idx["ssd_bytes_per_query"] + 0) <= 0.0 ||
        ($idx["ram_used_gb"] + 0) <= 0.0 ||
        ($idx["diagnostic_workload_speed_ready"] + 0) != 1 ||
        ($idx["real_workload_speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        $idx["action"] != "real-workload-speed-evidence-missing") {
      die("h9-h generated workload should pass diagnostic evidence only", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h9-h workload speed", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h9-h summary row", 6)
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
    if ($idx["gate"] == "pc-routelm-nlg-smoke" && $idx["status"] != "pass") die("NLG smoke should pass", 20)
    if ($idx["gate"] == "workload-artifacts" && $idx["status"] != "pass") die("workload artifacts should pass", 21)
    if ($idx["gate"] == "workload-hashes" && $idx["status"] != "pass") die("workload hashes should pass", 22)
    if ($idx["gate"] == "workload-contract" && $idx["status"] != "pass") die("workload contract should pass", 23)
    if ($idx["gate"] == "speedup-positive" && $idx["status"] != "pass") die("diagnostic speedup should pass", 24)
    if ($idx["gate"] == "h9-real-speed" && $idx["status"] != "blocked") die("h9 real speed should remain blocked", 25)
    if ($idx["gate"] == "real-workload-source" && $idx["status"] != "blocked") die("real workload source should remain blocked", 26)
    if ($idx["gate"] == "real-workload-speed" && $idx["status"] != "blocked") die("real workload speed should remain blocked", 27)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("jump guardrail should pass", 28)
  }
  END {
    if (rows != 9) die("expected h9-h decision rows", 29)
  }
' "$DECISION_CSV"

awk -F, 'BEGIN { OFS = "," }
  NR == 1 { print; next }
  NR == 2 {
    $7 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$GOOD_WORKLOAD_CSV" >"$BAD_WORKLOAD_CSV"

V09_GPU_BACKEND_WORKLOAD_SPEED_CSV="$BAD_WORKLOAD_CSV" \
  "$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" --smoke >/dev/null

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
    if (($idx["diagnostic_workload_speed_ready"] + 0) != 0 ||
        ($idx["workload_artifact_rows"] + 0) != 0 ||
        ($idx["timing_artifact_hash_verified_rows"] + 0) != 0 ||
        $idx["action"] != "workload-speed-artifact-hash-mismatch") {
      die("bad h9-h workload artifact hash should block diagnostic readiness", 40)
    }
  }
  END {
    if (rows != 1) die("expected one h9-h bad-hash summary row", 41)
  }
' "$SUMMARY_CSV"

{
  head -n 1 "$GOOD_WORKLOAD_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$GOOD_WORKLOAD_CSV")"
} >"$MALFORMED_WORKLOAD_CSV"

if V09_GPU_BACKEND_WORKLOAD_SPEED_CSV="$MALFORMED_WORKLOAD_CSV" \
     "$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h9-h should reject malformed workload speed CSV row widths" >&2
  exit 50
fi

"$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" --smoke >/dev/null

echo "h9 GPU backend real workload speed gate smoke passed"
