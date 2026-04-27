#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
OUTPUT_CSV="$RESULTS_DIR/text_lv0.csv"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

# Repeating-text baseline used for oracle1 comparison.
"$ROOT_DIR/build/dmv02" \
  --dataset repeating-text \
  --N 256 \
  --epochs 300 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --csv "$OUTPUT_CSV"

tail -n 5 "$OUTPUT_CSV"
