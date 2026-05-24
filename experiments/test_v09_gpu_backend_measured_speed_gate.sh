#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

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
    required_count = split("scope speed_schema_ready measurement_source measurement_rows timing_artifact_rows environment_artifact_rows timing_artifact_hash_verified_rows environment_hash_verified_rows timing_ready_rows real_hip_measurement_rows speedup_positive_rows measured_speed_evidence_ready speed_evidence_ready gpu_speedup_claim median_speedup action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h9 measured speed summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["scope"] != "h9-g" ||
        ($idx["speed_schema_ready"] + 0) != 1 ||
        $idx["measurement_source"] != "pending-fixture" ||
        ($idx["measurement_rows"] + 0) != 1 ||
        ($idx["timing_artifact_rows"] + 0) != 0 ||
        ($idx["environment_artifact_rows"] + 0) != 0 ||
        ($idx["timing_artifact_hash_verified_rows"] + 0) != 0 ||
        ($idx["environment_hash_verified_rows"] + 0) != 0 ||
        ($idx["timing_ready_rows"] + 0) != 0 ||
        ($idx["real_hip_measurement_rows"] + 0) != 0 ||
        ($idx["speedup_positive_rows"] + 0) != 0 ||
        ($idx["measured_speed_evidence_ready"] + 0) != 0 ||
        ($idx["speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        ($idx["median_speedup"] + 0) != 0.0 ||
        $idx["action"] != "measured-speed-evidence-missing") {
      die("default h9 measured speed gate should remain no-claim", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h9 measured speed gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one h9 measured speed summary row", 5)
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
    if ($idx["gate"] == "speed-schema" && $idx["status"] != "pass") die("speed schema should pass", 20)
    if ($idx["gate"] == "timing-artifacts" && $idx["status"] != "blocked") die("timing artifacts should block by default", 21)
    if ($idx["gate"] == "real-hip-source" && $idx["status"] != "blocked") die("real HIP source should block by default", 22)
    if ($idx["gate"] == "speed-evidence" && $idx["status"] != "blocked") die("speed evidence should block by default", 23)
  }
  END {
    if (rows != 7) die("expected h9 measured speed decision rows", 24)
  }
' "$DECISION_CSV"

echo "h9 GPU backend measured speed gate smoke passed"
