#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

CAUSAL_CSV="$RESULTS_DIR/v02_causal_next_byte_smoke.csv"
RECON_CSV="$RESULTS_DIR/v02_reconstruction_neighbor_smoke.csv"
INVALID_LOG="$RESULTS_DIR/v02_invalid_evaluation_mode.log"

"$BUILD_DIR/dmv02" \
  --dataset counter \
  --N 32 \
  --epochs 1 \
  --cycles-per-epoch 2 \
  --seed 1 \
  --evaluation-mode causal-next-byte \
  --csv "$CAUSAL_CSV" >/dev/null

"$BUILD_DIR/dmv02" \
  --dataset counter \
  --N 32 \
  --epochs 1 \
  --cycles-per-epoch 2 \
  --seed 1 \
  --csv "$RECON_CSV" >/dev/null

if "$BUILD_DIR/dmv02" \
  --dataset counter \
  --N 8 \
  --epochs 1 \
  --cycles-per-epoch 1 \
  --evaluation-mode future-leaking \
  --csv "$RESULTS_DIR/v02_invalid_evaluation_mode.csv" >"$INVALID_LOG" 2>&1; then
  echo "invalid evaluation mode should fail" >&2
  exit 1
fi

python3 - "$CAUSAL_CSV" "$RECON_CSV" "$INVALID_LOG" <<'PY'
import csv
import pathlib
import sys

causal_csv = pathlib.Path(sys.argv[1])
recon_csv = pathlib.Path(sys.argv[2])
invalid_log = pathlib.Path(sys.argv[3])

def last_row(path: pathlib.Path) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise SystemExit(f"missing rows: {path}")
    required = {"evaluation_causal_next_byte", "future_neighbor_used"}
    missing = required.difference(rows[-1])
    if missing:
        raise SystemExit(f"missing causal evaluation columns in {path}: {sorted(missing)}")
    return rows[-1]

causal = last_row(causal_csv)
recon = last_row(recon_csv)

if causal["evaluation_causal_next_byte"] != "1.000000":
    raise SystemExit("causal-next-byte run must identify its evaluation mode")
if causal["future_neighbor_used"] != "0.000000":
    raise SystemExit("causal-next-byte run must report future_neighbor_used=0")
if recon["evaluation_causal_next_byte"] != "0.000000":
    raise SystemExit("default reconstruction run must not claim causal evaluation")
if recon["future_neighbor_used"] != "1.000000":
    raise SystemExit("default reconstruction run must disclose future neighbor availability")
if "evaluation-mode must be one of" not in invalid_log.read_text(encoding="utf-8"):
    raise SystemExit("invalid evaluation mode error must name the allowed modes")
PY

echo "v02 causal next-byte evaluation smoke passed"
