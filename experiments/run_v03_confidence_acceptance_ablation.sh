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
    '{printf "%-18s byte=%s field=%s joint=%s trig=%s gap_pass=%s gap_mean=%s gap_max=%s gate=%s stress=%s conf=%s conf_max=%s cand=%s hit=%s active=%s jump_n=%s jump_d=%s\n", label, $3, $4, $19, $21, $27, $28, $29, $30, $31, $32, $33, $22, $23, $24, $25, $26}'
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
  --route-min-anchor-gap 0.0
  --route-reservoir-threshold 0.05
)

for gain in 0 0.05 0.10 0.20; do
  gain_tag="${gain//./p}"
  echo "acceptance slice: repeating-text gain=${gain}"
  run_case "$RESULTS_DIR/v03_accept_repeat_a${gain_tag}.csv" \
    --dataset repeating-text "${COMMON_ARGS[@]}" --route-accept-confidence-gain "$gain"
  echo "acceptance slice: fixture gain=${gain}"
  run_case "$RESULTS_DIR/v03_accept_fixture_a${gain_tag}.csv" \
    --input "$FIXTURE_PATH" "${COMMON_ARGS[@]}" --route-accept-confidence-gain "$gain"
done

echo
for gain in 0 0.05 0.10 0.20; do
  gain_tag="${gain//./p}"
  print_summary "repeat-a${gain_tag}" "$RESULTS_DIR/v03_accept_repeat_a${gain_tag}.csv"
done
for gain in 0 0.05 0.10 0.20; do
  gain_tag="${gain//./p}"
  print_summary "fixture-a${gain_tag}" "$RESULTS_DIR/v03_accept_fixture_a${gain_tag}.csv"
done
