#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_PATH="$ROOT_DIR/data/routing_probe_fixture.txt"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" -j

run_case() {
  local csv_path="$1"
  shift
  "$BUILD_DIR/dmv02" "$@" --csv "$csv_path"
}

print_summary() {
  local label="$1"
  local csv_path="$2"
  tail -n 1 "$csv_path" | awk -F, -v label="$label" \
    '{printf "%-18s byte=%s field=%s joint=%s trig=%s gap_pass=%s gap_mean=%s gap_max=%s gate=%s stress=%s cand=%s hit=%s active=%s jump_n=%s jump_d=%s\n", label, $3, $4, $19, $21, $27, $28, $29, $30, $31, $22, $23, $24, $25, $26}'
}

COMMON_ARGS=(
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --K-jump 2
  --route-source joint-code
  --route-mode jump-neighbors
  --route-reservoir-threshold 0.05
)

for scale in 0 10 11 12 13; do
  echo "adaptive gate: repeating-text scale=${scale}"
  run_case "$RESULTS_DIR/v03_adaptive_repeat_s${scale}.csv" \
    --dataset repeating-text "${COMMON_ARGS[@]}" --route-adaptive-gap-scale "$scale"
  echo "adaptive gate: fixture scale=${scale}"
  run_case "$RESULTS_DIR/v03_adaptive_fixture_s${scale}.csv" \
    --input "$FIXTURE_PATH" "${COMMON_ARGS[@]}" --route-adaptive-gap-scale "$scale"
done

echo
for scale in 0 10 11 12 13; do
  print_summary "repeat-s${scale}" "$RESULTS_DIR/v03_adaptive_repeat_s${scale}.csv"
done
for scale in 0 10 11 12 13; do
  print_summary "fixture-s${scale}" "$RESULTS_DIR/v03_adaptive_fixture_s${scale}.csv"
done
