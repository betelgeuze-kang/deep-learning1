#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
OUTPUT_CSV_005="$RESULTS_DIR/counter_lv005.csv"
OUTPUT_CSV_025="$RESULTS_DIR/counter_lv025.csv"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

# Counter baseline is locked separately; this script probes positive lambda_v.
"$ROOT_DIR/build/dmv02" \
  --dataset counter \
  --N 128 \
  --epochs 200 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0.05 \
  --csv "$OUTPUT_CSV_005"

"$ROOT_DIR/build/dmv02" \
  --dataset counter \
  --N 128 \
  --epochs 200 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0.25 \
  --csv "$OUTPUT_CSV_025"

tail -n 5 "$OUTPUT_CSV_005"
tail -n 5 "$OUTPUT_CSV_025"
