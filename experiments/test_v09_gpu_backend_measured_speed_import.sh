#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v09_gpu_backend_measured_speed_fixture"
MEASUREMENT_CSV="$RESULTS_DIR/v09_gpu_backend_measured_speed_fixture.csv"

mkdir -p "$FIXTURE_DIR"

printf '{"cpu_median_ms":100.0,"hip_median_ms":80.0}\n' >"$FIXTURE_DIR/timing.json"
printf 'fixture environment; not real HIP hardware attestation\n' >"$FIXTURE_DIR/environment.txt"

timing_hash="$(sha256sum "$FIXTURE_DIR/timing.json" | awk '{print $1}')"
environment_hash="$(sha256sum "$FIXTURE_DIR/environment.txt" | awk '{print $1}')"

cat >"$MEASUREMENT_CSV" <<CSV
measurement_id,cpu_backend,accelerated_backend,cpu_median_ms,accelerated_median_ms,warmup_runs,measured_runs,timing_artifact_uri,timing_artifact_hash,environment_uri,environment_hash,measurement_source,measurement_ready,routing_trigger_rate,active_jump_rate
fixture-speed,cpu,hip,100.000000,80.000000,2,5,file://$FIXTURE_DIR/timing.json,sha256:$timing_hash,file://$FIXTURE_DIR/environment.txt,sha256:$environment_hash,fixture,1,0,0
CSV

V09_GPU_BACKEND_SPEED_MEASUREMENT_CSV="$MEASUREMENT_CSV" \
  "$ROOT_DIR/experiments/run_v09_gpu_backend_measured_speed_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_measured_speed_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v09_gpu_backend_measured_speed_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("measurement_source measurement_rows timing_artifact_rows environment_artifact_rows timing_artifact_hash_verified_rows environment_hash_verified_rows timing_ready_rows real_hip_measurement_rows speedup_positive_rows measured_speed_evidence_ready speed_evidence_ready gpu_speedup_claim median_speedup action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h9 measured speed import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["measurement_source"] != "provided-csv" ||
        ($idx["measurement_rows"] + 0) != 1 ||
        ($idx["timing_artifact_rows"] + 0) != 1 ||
        ($idx["environment_artifact_rows"] + 0) != 1 ||
        ($idx["timing_artifact_hash_verified_rows"] + 0) != 1 ||
        ($idx["environment_hash_verified_rows"] + 0) != 1 ||
        ($idx["timing_ready_rows"] + 0) != 1 ||
        ($idx["real_hip_measurement_rows"] + 0) != 0 ||
        ($idx["speedup_positive_rows"] + 0) != 1 ||
        ($idx["measured_speed_evidence_ready"] + 0) != 0 ||
        ($idx["speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        ($idx["median_speedup"] + 0) != 1.25 ||
        $idx["action"] != "real-hip-measurement-missing") {
      die("supplied h9 measured speed fixture should verify artifacts but remain no-claim", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h9 measured speed import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one h9 measured speed import summary row", 5)
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
    if ($idx["gate"] == "timing-artifacts" && $idx["status"] != "pass") die("timing artifacts should pass", 20)
    if ($idx["gate"] == "artifact-hashes" && $idx["status"] != "pass") die("artifact hashes should pass", 21)
    if ($idx["gate"] == "timing-contract" && $idx["status"] != "pass") die("timing contract should pass", 22)
    if ($idx["gate"] == "speedup-positive" && $idx["status"] != "pass") die("positive speedup should pass for fixture", 23)
    if ($idx["gate"] == "real-hip-source" && $idx["status"] != "blocked") die("fixture should not pass real HIP source", 24)
    if ($idx["gate"] == "speed-evidence" && $idx["status"] != "blocked") die("speed evidence should remain blocked for fixture", 25)
  }
  END {
    if (rows != 7) die("expected h9 measured speed import decision rows", 26)
  }
' "$DECISION_CSV"

echo "h9 GPU backend measured speed import smoke passed"
