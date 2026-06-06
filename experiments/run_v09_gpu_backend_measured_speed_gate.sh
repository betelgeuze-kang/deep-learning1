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

PREFIX="v09_gpu_backend_measured_speed_gate"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v09_gpu_backend_measured_speed_gate_smoke"
fi

"$ROOT_DIR/experiments/test_v09_gpu_backend_speed_evidence.sh" >/dev/null

BASE_SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_speed_evidence_summary.csv"
MEASUREMENT_CSV="$RESULTS_DIR/${PREFIX}_measurements.csv"
MEASUREMENT_SOURCE="pending-fixture"
if [[ -n "${V09_GPU_BACKEND_SPEED_MEASUREMENT_CSV:-}" ]]; then
  MEASUREMENT_CSV="$V09_GPU_BACKEND_SPEED_MEASUREMENT_CSV"
  MEASUREMENT_SOURCE="provided-csv"
  if [[ ! -s "$MEASUREMENT_CSV" ]]; then
    echo "V09_GPU_BACKEND_SPEED_MEASUREMENT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  cat >"$MEASUREMENT_CSV" <<'CSV'
measurement_id,cpu_backend,accelerated_backend,cpu_median_ms,accelerated_median_ms,warmup_runs,measured_runs,timing_artifact_uri,timing_artifact_hash,environment_uri,environment_hash,measurement_source,measurement_ready,routing_trigger_rate,active_jump_rate
pending,cpu,pending,0,0,0,0,pending,pending,pending,pending,pending,0,0,0
CSV
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

hash_matches() {
  local path="$1"
  local expected="$2"
  local expected_hex
  local actual_hex

  if [[ ! -f "$path" ]] || ! is_sha256 "$expected"; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

BASE_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("scope speed_schema_ready hip_tool_available speed_evidence_ready gpu_speedup_claim routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h9 measured speed base column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%s,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["scope"],
        $idx["speed_schema_ready"] + 0,
        $idx["hip_tool_available"] + 0,
        $idx["speed_evidence_ready"] + 0,
        $idx["gpu_speedup_claim"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h9 measured speed base row", 3)
    }
  ' "$BASE_SUMMARY_CSV"
)"

IFS=, read -r base_scope speed_schema_ready hip_tool_available base_speed_evidence_ready base_gpu_speedup_claim base_routing base_jump <<<"$BASE_VALUES"

measurement_rows=0
timing_artifact_rows=0
environment_artifact_rows=0
timing_artifact_hash_verified_rows=0
environment_hash_verified_rows=0
timing_ready_rows=0
real_hip_measurement_rows=0
speedup_positive_rows=0
measurement_routing="0.000000"
measurement_jump="0.000000"
median_speedup="0.000000"

while IFS=$'\t' read -r measurement_id cpu_backend accelerated_backend cpu_median_ms accelerated_median_ms warmup_runs measured_runs timing_artifact_uri timing_artifact_hash environment_uri environment_hash row_measurement_source measurement_ready routing_trigger_rate active_jump_rate; do
  ((measurement_rows += 1))

  if timing_path="$(uri_to_local_path "$timing_artifact_uri")"; then
    ((timing_artifact_rows += 1))
    if hash_matches "$timing_path" "$timing_artifact_hash"; then
      ((timing_artifact_hash_verified_rows += 1))
    fi
  fi

  if environment_path="$(uri_to_local_path "$environment_uri")"; then
    ((environment_artifact_rows += 1))
    if hash_matches "$environment_path" "$environment_hash"; then
      ((environment_hash_verified_rows += 1))
    fi
  fi

  row_speedup="$(awk -v cpu="$cpu_median_ms" -v acc="$accelerated_median_ms" 'BEGIN {
    if (cpu > 0 && acc > 0) printf "%.6f", cpu / acc; else printf "0.000000"
  }')"
  median_speedup="$(awk -v current="$median_speedup" -v row="$row_speedup" 'BEGIN {
    if (row > current) printf "%.6f", row; else printf "%.6f", current
  }')"

  if [[ "$measurement_ready" == "1" &&
        "$cpu_backend" == "cpu" &&
        "$accelerated_backend" == "hip" &&
        "$warmup_runs" =~ ^[0-9]+$ &&
        "$measured_runs" =~ ^[0-9]+$ &&
        "$warmup_runs" -ge 1 &&
        "$measured_runs" -ge 3 ]] &&
      awk -v cpu="$cpu_median_ms" -v acc="$accelerated_median_ms" 'BEGIN { exit !(cpu > 0 && acc > 0) }'; then
    ((timing_ready_rows += 1))
  fi

  if [[ "$row_measurement_source" == "real-hip" &&
        "$accelerated_backend" == "hip" &&
        "$measurement_ready" == "1" ]]; then
    ((real_hip_measurement_rows += 1))
  fi

  if awk -v speedup="$row_speedup" 'BEGIN { exit !(speedup > 1.0) }'; then
    ((speedup_positive_rows += 1))
  fi

  measurement_routing="$(awk -v a="$measurement_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  measurement_jump="$(awk -v a="$measurement_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("measurement_id cpu_backend accelerated_backend cpu_median_ms accelerated_median_ms warmup_runs measured_runs timing_artifact_uri timing_artifact_hash environment_uri environment_hash measurement_source measurement_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h9 measured speed column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%.6f\t%.6f\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%.6f\t%.6f\n",
        $idx["measurement_id"],
        $idx["cpu_backend"],
        $idx["accelerated_backend"],
        $idx["cpu_median_ms"] + 0,
        $idx["accelerated_median_ms"] + 0,
        $idx["warmup_runs"] + 0,
        $idx["measured_runs"] + 0,
        $idx["timing_artifact_uri"],
        $idx["timing_artifact_hash"],
        $idx["environment_uri"],
        $idx["environment_hash"],
        $idx["measurement_source"],
        $idx["measurement_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$MEASUREMENT_CSV"
)

measured_speed_evidence_ready=0
if [[ "$speed_schema_ready" == "1" &&
      "$hip_tool_available" == "1" &&
      "$measurement_rows" -gt 0 &&
      "$timing_artifact_rows" -eq "$measurement_rows" &&
      "$environment_artifact_rows" -eq "$measurement_rows" &&
      "$timing_artifact_hash_verified_rows" -eq "$measurement_rows" &&
      "$environment_hash_verified_rows" -eq "$measurement_rows" &&
      "$timing_ready_rows" -eq "$measurement_rows" &&
      "$real_hip_measurement_rows" -eq "$measurement_rows" &&
      "$speedup_positive_rows" -eq "$measurement_rows" &&
      "$measurement_routing" == "0.000000" &&
      "$measurement_jump" == "0.000000" ]]; then
  measured_speed_evidence_ready=1
fi

speed_evidence_ready="$measured_speed_evidence_ready"
gpu_speedup_claim="deferred"
action="measured-speed-evidence-missing"
if [[ "$measurement_rows" -gt 0 &&
      "$timing_artifact_hash_verified_rows" -eq "$measurement_rows" &&
      "$environment_hash_verified_rows" -eq "$measurement_rows" &&
      "$timing_ready_rows" -eq "$measurement_rows" &&
      "$real_hip_measurement_rows" -ne "$measurement_rows" ]]; then
  action="real-hip-measurement-missing"
elif [[ "$measurement_rows" -gt 0 &&
        "$timing_ready_rows" -eq "$measurement_rows" &&
        "$speedup_positive_rows" -ne "$measurement_rows" ]]; then
  action="gpu-speedup-not-demonstrated"
elif [[ "$measured_speed_evidence_ready" == "1" ]]; then
  gpu_speedup_claim="measured-candidate"
  action="speed-evidence-review-missing"
fi

total_routing="$(awk -v a="$base_routing" -v b="$measurement_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$base_jump" -v b="$measurement_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "scope,speed_schema_ready,hip_tool_available,measurement_source,measurement_rows,timing_artifact_rows,environment_artifact_rows,timing_artifact_hash_verified_rows,environment_hash_verified_rows,timing_ready_rows,real_hip_measurement_rows,speedup_positive_rows,measured_speed_evidence_ready,speed_evidence_ready,gpu_speedup_claim,median_speedup,action,routing_trigger_rate,active_jump_rate"
  printf "h9-g,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%s,%.6f,%.6f\n" \
    "$speed_schema_ready" \
    "$hip_tool_available" \
    "$MEASUREMENT_SOURCE" \
    "$measurement_rows" \
    "$timing_artifact_rows" \
    "$environment_artifact_rows" \
    "$timing_artifact_hash_verified_rows" \
    "$environment_hash_verified_rows" \
    "$timing_ready_rows" \
    "$real_hip_measurement_rows" \
    "$speedup_positive_rows" \
    "$measured_speed_evidence_ready" \
    "$speed_evidence_ready" \
    "$gpu_speedup_claim" \
    "$median_speedup" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "speed-schema,%s,schema_ready=%d\n" \
    "$([[ "$speed_schema_ready" == "1" ]] && echo pass || echo blocked)" \
    "$speed_schema_ready"
  printf "timing-artifacts,%s,timing_rows=%d environment_rows=%d\n" \
    "$([[ "$timing_artifact_rows" -eq "$measurement_rows" && "$environment_artifact_rows" -eq "$measurement_rows" ]] && echo pass || echo blocked)" \
    "$timing_artifact_rows" \
    "$environment_artifact_rows"
  printf "artifact-hashes,%s,timing_hash_rows=%d environment_hash_rows=%d\n" \
    "$([[ "$timing_artifact_hash_verified_rows" -eq "$measurement_rows" && "$environment_hash_verified_rows" -eq "$measurement_rows" ]] && echo pass || echo blocked)" \
    "$timing_artifact_hash_verified_rows" \
    "$environment_hash_verified_rows"
  printf "timing-contract,%s,timing_ready_rows=%d\n" \
    "$([[ "$timing_ready_rows" -eq "$measurement_rows" ]] && echo pass || echo blocked)" \
    "$timing_ready_rows"
  printf "real-hip-source,%s,real_hip_rows=%d hip_tool_available=%d\n" \
    "$([[ "$real_hip_measurement_rows" -eq "$measurement_rows" && "$hip_tool_available" == "1" ]] && echo pass || echo blocked)" \
    "$real_hip_measurement_rows" \
    "$hip_tool_available"
  printf "speedup-positive,%s,speedup_rows=%d median_speedup=%.6f\n" \
    "$([[ "$speedup_positive_rows" -eq "$measurement_rows" ]] && echo pass || echo blocked)" \
    "$speedup_positive_rows" \
    "$median_speedup"
  printf "speed-evidence,%s,claim=%s\n" \
    "$([[ "$speed_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$gpu_speedup_claim"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
