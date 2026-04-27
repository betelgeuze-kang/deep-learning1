#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

COMMON_ARGS=(
  --dataset counter
  --N 128
  --epochs 200
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --proposal-count 30
)

CONTROL_CSV="$RESULTS_DIR/v02b_counter_off_pc30.csv"
COUPLED_CSV="$RESULTS_DIR/v02b_counter_lv0_lb010_eb002_pc30.csv"

echo "counter: control (pc30, coupling off)"
"$ROOT_DIR/build/dmv02" "${COMMON_ARGS[@]}" --lambda-b 0 --eta-b 0 --csv "$CONTROL_CSV"

echo "counter: weak coupling (pc30, lambda_b=0.1, eta_b=0.02)"
"$ROOT_DIR/build/dmv02" "${COMMON_ARGS[@]}" --lambda-b 0.1 --eta-b 0.02 --csv "$COUPLED_CSV"

tail -n 5 "$CONTROL_CSV"
tail -n 5 "$COUPLED_CSV"
