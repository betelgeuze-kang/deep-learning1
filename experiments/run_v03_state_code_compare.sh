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
    '{printf "%-24s byte=%s field=%s joint=%s trig=%s candidates=%s hit=%s active=%s jump_n=%s gap_pass=%s gate=%s\n", label, $3, $4, $19, $21, $22, $23, $24, $25, $27, $30}'
}

BASE_ARGS=(
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --K-jump 2
  --route-reservoir-threshold 0.05
)

JOINT_PROBE_ARGS=(
  --route-source joint-code
)

STATE_PROBE_ARGS=(
  --route-source state-code
  --route-refresh cycle
)

JOINT_GUARD_ARGS=(
  --route-source joint-code
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

STATE_GUARD_ARGS=(
  --route-source state-code
  --route-refresh cycle
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

STATE_EPOCH_GUARD_ARGS=(
  --route-source state-code
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

run_suite_for_dataset() {
  local dataset_label="$1"
  shift
  local dataset_args=("$@")

  echo "state-code compare: ${dataset_label} joint-code probe"
  run_case "$RESULTS_DIR/v03_state_code_${dataset_label}_joint_probe.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${JOINT_PROBE_ARGS[@]}"

  echo "state-code compare: ${dataset_label} state-code probe"
  run_case "$RESULTS_DIR/v03_state_code_${dataset_label}_state_probe.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_PROBE_ARGS[@]}"

  echo "state-code compare: ${dataset_label} joint-code guarded jump"
  run_case "$RESULTS_DIR/v03_state_code_${dataset_label}_joint_guard.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${JOINT_GUARD_ARGS[@]}"

  echo "state-code compare: ${dataset_label} state-code guarded jump"
  run_case "$RESULTS_DIR/v03_state_code_${dataset_label}_state_guard.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_GUARD_ARGS[@]}"

  echo "state-code compare: ${dataset_label} state-code epoch-guarded jump"
  run_case "$RESULTS_DIR/v03_state_code_${dataset_label}_state_epoch_guard.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_EPOCH_GUARD_ARGS[@]}"
}

print_suite_for_dataset() {
  local dataset_label="$1"

  print_summary "${dataset_label}-joint-probe" \
    "$RESULTS_DIR/v03_state_code_${dataset_label}_joint_probe.csv"
  print_summary "${dataset_label}-state-probe" \
    "$RESULTS_DIR/v03_state_code_${dataset_label}_state_probe.csv"
  print_summary "${dataset_label}-joint-guard" \
    "$RESULTS_DIR/v03_state_code_${dataset_label}_joint_guard.csv"
  print_summary "${dataset_label}-state-guard" \
    "$RESULTS_DIR/v03_state_code_${dataset_label}_state_guard.csv"
  print_summary "${dataset_label}-state-epoch-guard" \
    "$RESULTS_DIR/v03_state_code_${dataset_label}_state_epoch_guard.csv"
}

# Route-signal probe: compare state-key buckets against joint-code while keeping
# the learned joint-code anchor for gate/acceptance diagnostics.
run_suite_for_dataset repeat --dataset repeating-text
run_suite_for_dataset fixture --input "$FIXTURE_PATH"

echo
print_suite_for_dataset repeat
print_suite_for_dataset fixture
