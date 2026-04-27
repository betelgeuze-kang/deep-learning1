#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
OUTPUT_CSV="$RESULTS_DIR/counter_lv0.csv"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

# Locked baseline: counter with lambda_v = 0.
"$ROOT_DIR/build/dmv02" \
  --dataset counter \
  --N 128 \
  --epochs 200 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --csv "$OUTPUT_CSV"

tail -n 5 "$OUTPUT_CSV"
