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
    '{printf "%-13s byte=%s field=%s joint=%s trig=%s gap_pass=%s gap_mean=%s gap_max=%s gate=%s stress=%s conf=%s conf_max=%s cand=%s hit=%s active=%s jump_n=%s jump_d=%s\n", label, $3, $4, $19, $21, $27, $28, $29, $30, $31, $32, $33, $22, $23, $24, $25, $26}'
}

REPEATING_ARGS=(
  --dataset repeating-text
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
)

FIXTURE_ARGS=(
  --input "$FIXTURE_PATH"
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
)

echo "static routing: repeating-text off"
run_case "$RESULTS_DIR/v03_static_repeat_off.csv" "${REPEATING_ARGS[@]}"
echo "static routing: repeating-text probe"
run_case "$RESULTS_DIR/v03_static_repeat_probe.csv" "${REPEATING_ARGS[@]}" \
  --K-jump 2 --route-source joint-code --route-mode probe --route-reservoir-threshold 0.05
echo "static routing: repeating-text jump-neighbors"
run_case "$RESULTS_DIR/v03_static_repeat_jump.csv" "${REPEATING_ARGS[@]}" \
  --K-jump 2 --route-source joint-code --route-mode jump-neighbors --route-reservoir-threshold 0.05

echo "static routing: fixture off"
run_case "$RESULTS_DIR/v03_static_fixture_off.csv" "${FIXTURE_ARGS[@]}"
echo "static routing: fixture probe"
run_case "$RESULTS_DIR/v03_static_fixture_probe.csv" "${FIXTURE_ARGS[@]}" \
  --K-jump 2 --route-source joint-code --route-mode probe --route-reservoir-threshold 0.05
echo "static routing: fixture jump-neighbors"
run_case "$RESULTS_DIR/v03_static_fixture_jump.csv" "${FIXTURE_ARGS[@]}" \
  --K-jump 2 --route-source joint-code --route-mode jump-neighbors --route-reservoir-threshold 0.05

echo
print_summary repeat-off "$RESULTS_DIR/v03_static_repeat_off.csv"
print_summary repeat-probe "$RESULTS_DIR/v03_static_repeat_probe.csv"
print_summary repeat-jump "$RESULTS_DIR/v03_static_repeat_jump.csv"
print_summary fixture-off "$RESULTS_DIR/v03_static_fixture_off.csv"
print_summary fixture-probe "$RESULTS_DIR/v03_static_fixture_probe.csv"
print_summary fixture-jump "$RESULTS_DIR/v03_static_fixture_jump.csv"
