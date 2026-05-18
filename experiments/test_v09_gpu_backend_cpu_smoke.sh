#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$RESULTS_DIR"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

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
    local key=$((51000 + i))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 32; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((51000 + i))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i")" >>"$path"
  done
}

FIXTURE="$TMP_DIR/h9_fixture.txt"
CSV="$RESULTS_DIR/v09_gpu_backend_cpu_smoke.csv"
make_fixture "$FIXTURE" 8
N_BYTES="$(wc -c <"$FIXTURE")"

"$BUILD_DIR/dmv02" \
  --backend cpu \
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
  --csv "$CSV" >/dev/null

python3 - "$CSV" <<'PY'
import csv
import sys

path = sys.argv[1]
rows = list(csv.DictReader(open(path, newline="")))
if not rows:
    raise SystemExit("no data rows")
row = rows[-1]
required = [
    "backend_active",
    "hip_enabled",
    "hip_device",
    "hip_kernel_calls",
    "hip_fallback_count",
    "route_hint_candidate_lookup_count",
    "route_hint_value_read_distance_mean",
    "routing_trigger_rate",
    "active_jump_rate",
]
missing = [name for name in required if name not in row]
if missing:
    raise SystemExit(f"missing backend columns: {missing}")
if float(row["backend_active"]) != 0.0:
    raise SystemExit("CPU backend smoke should not mark backend_active")
if float(row["hip_kernel_calls"]) != 0.0 or float(row["hip_fallback_count"]) != 0.0:
    raise SystemExit("CPU backend smoke should not call or fallback HIP kernels")
if float(row["route_hint_candidate_lookup_count"]) <= 0.0:
    raise SystemExit("route candidate lookup should stay active")
if float(row["route_hint_value_read_distance_mean"]) <= 0.0:
    raise SystemExit("value read distance should stay populated")
if float(row["routing_trigger_rate"]) != 0.0 or float(row["active_jump_rate"]) != 0.0:
    raise SystemExit("h9 must not revive jump-neighbor routing")
PY

echo "h9 CPU backend smoke passed"
