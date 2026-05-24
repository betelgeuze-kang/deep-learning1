#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_speed_evidence_summary.csv"

mkdir -p "$RESULTS_DIR"

HIP_TOOL_AVAILABLE=0
if command -v hipcc >/dev/null 2>&1 || [[ -x /opt/rocm/bin/hipcc ]]; then
  HIP_TOOL_AVAILABLE=1
fi

cat >"$SUMMARY_CSV" <<CSV
scope,speed_schema_ready,hip_tool_available,speed_evidence_ready,gpu_speedup_claim,required_before_claim,routing_trigger_rate,active_jump_rate
h9-f,1,$HIP_TOOL_AVAILABLE,0,deferred,measured-cpu-hip-timings,0.000000,0.000000
CSV

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scope speed_schema_ready hip_tool_available speed_evidence_ready gpu_speedup_claim required_before_claim routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h9 speed evidence column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["scope"] != "h9-f" ||
        ($idx["speed_schema_ready"] + 0) != 1 ||
        ($idx["speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        $idx["required_before_claim"] != "measured-cpu-hip-timings") {
      die("h9 speed evidence must be schema-ready but no-claim by default", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h9 speed evidence", 4)
    }
  }
  END {
    if (rows != 1) die("expected one h9 speed evidence row", 5)
  }
' "$SUMMARY_CSV"

echo "h9 GPU backend speed evidence smoke passed"
