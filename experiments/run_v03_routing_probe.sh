#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" -j

BASE_ARGS=(
  --dataset repeating-text
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
)

print_summary() {
  local label="$1"
  local csv_path="$2"
  tail -n 1 "$csv_path" | awk -F, -v label="$label" \
    '{printf "%-12s byte=%s field=%s joint=%s trigger=%s candidates=%s hit=%s\n", label, $3, $4, $19, $21, $22, $23}'
}

echo "routing probe: no routing candidates"
"$BUILD_DIR/dmv02" "${BASE_ARGS[@]}" \
  --csv "$RESULTS_DIR/v03_routing_probe_off.csv"

echo "routing probe: input-byte candidate scaffold"
"$BUILD_DIR/dmv02" "${BASE_ARGS[@]}" \
  --K-jump 2 \
  --route-source input-byte \
  --route-reservoir-threshold 0.05 \
  --csv "$RESULTS_DIR/v03_routing_probe_input_byte.csv"

echo "routing probe: joint-code candidate scaffold"
"$BUILD_DIR/dmv02" "${BASE_ARGS[@]}" \
  --K-jump 2 \
  --route-source joint-code \
  --route-reservoir-threshold 0.05 \
  --csv "$RESULTS_DIR/v03_routing_probe_joint_code.csv"

echo
print_summary off "$RESULTS_DIR/v03_routing_probe_off.csv"
print_summary input-byte "$RESULTS_DIR/v03_routing_probe_input_byte.csv"
print_summary joint-code "$RESULTS_DIR/v03_routing_probe_joint_code.csv"
