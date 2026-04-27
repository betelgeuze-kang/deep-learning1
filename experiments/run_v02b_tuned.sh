#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

"$ROOT_DIR/build/dmv02" \
  --dataset counter \
  --N 128 \
  --epochs 200 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --lambda-b 0.1 \
  --eta-b 0.02 \
  --proposal-count 30 \
  --csv "$RESULTS_DIR/v02b_counter_tuned.csv"

"$ROOT_DIR/build/dmv02" \
  --dataset repeating-text \
  --N 256 \
  --epochs 300 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --lambda-b 0.1 \
  --eta-b 0.02 \
  --proposal-count 30 \
  --csv "$RESULTS_DIR/v02b_text_tuned.csv"

tail -n 5 "$RESULTS_DIR/v02b_counter_tuned.csv"
tail -n 5 "$RESULTS_DIR/v02b_text_tuned.csv"
