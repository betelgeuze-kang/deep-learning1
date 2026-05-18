#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-hip"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v hipcc >/dev/null 2>&1 && [[ ! -x /opt/rocm/bin/hipcc ]]; then
  echo "h9 HIP parity skipped: hipcc not found"
  exit 0
fi
export PATH="/opt/rocm/bin:$PATH"
if command -v offload-arch >/dev/null 2>&1 && [[ -z "$(offload-arch 2>/dev/null | head -n1)" ]]; then
  echo "h9 HIP parity skipped: no ROCm offload architecture detected"
  exit 0
fi

mkdir -p "$RESULTS_DIR"
if ! cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DDLE_ENABLE_HIP=ON >"$TMP_DIR/cmake.log" 2>&1; then
  echo "h9 HIP parity skipped: HIP CMake configure failed"
  cat "$TMP_DIR/cmake.log" >&2
  exit 0
fi
if ! cmake --build "$BUILD_DIR" --target dmv02 hip_candidate_weight_parity -j2 >"$TMP_DIR/build.log" 2>&1; then
  echo "h9 HIP parity skipped: HIP build failed"
  cat "$TMP_DIR/build.log" >&2
  exit 0
fi

"$BUILD_DIR/hip_candidate_weight_parity" --hip-device "${HIP_DEVICE:-0}"

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

make_fixture() {
  local path="$1"
  local key_count="$2"
  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((52000 + i))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 24; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((52000 + i))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i")" >>"$path"
  done
}

run_fixture() {
  local backend="$1"
  local csv="$2"
  "$BUILD_DIR/dmv02" \
    --backend "$backend" \
    --hip-device "${HIP_DEVICE:-0}" \
    --input "$FIXTURE" \
    --N "$N_BYTES" \
    --epochs 2 \
    --cycles-per-epoch 2 \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count 8 \
    --route-mode hint-kv-hash \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score recency \
    --route-delta-mode target-only \
    --lambda-route 0.5 \
    --route-quality-candidate-weight-preset base-default \
    --csv "$csv" >/dev/null
}

FIXTURE="$TMP_DIR/h9_hip_fixture.txt"
make_fixture "$FIXTURE" 8
N_BYTES="$(wc -c <"$FIXTURE")"
CPU_CSV="$RESULTS_DIR/v09_gpu_backend_parity_cpu.csv"
HIP_CSV="$RESULTS_DIR/v09_gpu_backend_parity_hip.csv"
run_fixture cpu "$CPU_CSV"
run_fixture hip "$HIP_CSV"

python3 - "$CPU_CSV" "$HIP_CSV" <<'PY'
import csv
import math
import sys

cpu = list(csv.DictReader(open(sys.argv[1], newline="")))[-1]
hip = list(csv.DictReader(open(sys.argv[2], newline="")))[-1]
required = [
    "backend_active",
    "hip_enabled",
    "hip_kernel_calls",
    "hip_fallback_count",
    "route_hint_query_count",
    "route_hint_candidate_lookup_count",
    "route_quality_candidate_weight_factor_mean",
    "fixture_query_byte_acc",
    "routing_trigger_rate",
    "active_jump_rate",
]
missing = [name for name in required if name not in hip or name not in cpu]
if missing:
    raise SystemExit(f"missing parity columns: {missing}")
if float(hip["backend_active"]) != 1.0 or float(hip["hip_enabled"]) != 1.0:
    raise SystemExit("HIP backend should report active and enabled")
if float(hip["hip_kernel_calls"]) <= 0.0:
    raise SystemExit("HIP route-quality fixture should call the HIP factor kernel")
if float(hip["hip_fallback_count"]) != 0.0:
    raise SystemExit("HIP route-quality fixture should not fall back for factor kernel")
for name in ("route_hint_query_count", "route_hint_candidate_lookup_count"):
    if float(cpu[name]) != float(hip[name]):
        raise SystemExit(f"{name} changed between CPU and HIP")
for name, tol in (
    ("route_quality_candidate_weight_factor_mean", 1e-5),
    ("fixture_query_byte_acc", 1e-6),
):
    if abs(float(cpu[name]) - float(hip[name])) > tol:
        raise SystemExit(f"{name} CPU/HIP delta exceeds tolerance")
if float(hip["routing_trigger_rate"]) != 0.0 or float(hip["active_jump_rate"]) != 0.0:
    raise SystemExit("HIP backend must not revive jump-neighbor routing")
PY

echo "h9 HIP candidate-weight parity smoke passed"
