#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
OUTPUT_CSV="$RESULTS_DIR/v01_smoke.csv"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build"
cmake --build "$ROOT_DIR/build" -j

"$ROOT_DIR/build/dmv01" \
  --N 256 \
  --cycles 100 \
  --seed 1 \
  --csv "$OUTPUT_CSV"

tail -n 5 "$OUTPUT_CSV"
