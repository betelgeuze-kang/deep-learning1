#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-v61ab-computed-ready.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_fail_with() {
  local expected="$1"
  shift
  local out="$TMP_DIR/expect_fail.out"
  if "$@" >"$out" 2>&1; then
    echo "v61ab computed-readiness negative control unexpectedly passed: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$out" >/dev/null; then
    echo "v61ab computed-readiness negative control failed for the wrong reason" >&2
    echo "expected diagnostic: $expected" >&2
    echo "actual output:" >&2
    cat "$out" >&2
    exit 1
  fi
}

V61AB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null
"$ROOT_DIR/tools/verify_artifact.py" v61ab-tile-probe "$SUMMARY_CSV" --run-dir "$RUN_DIR" >/dev/null

BAD_RUN_DIR="$TMP_DIR/probe_001"
cp -R "$RUN_DIR" "$BAD_RUN_DIR"
python3 - "$BAD_RUN_DIR/hotset_tensor_tile_torch_parity_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["torch_matvec_parity_pass"] = "0"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "torch_matvec_parity_pass_rows expected 127, got 128" \
  "$ROOT_DIR/tools/verify_artifact.py" v61ab-tile-probe "$SUMMARY_CSV" --run-dir "$BAD_RUN_DIR"

cp -R "$RUN_DIR" "$BAD_RUN_DIR.summary"
python3 - "$TMP_DIR/bad_summary.csv" "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

target = Path(sys.argv[1])
source = Path(sys.argv[2])
with source.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["actual_model_generation_ready"] = "1"
with target.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "actual_model_generation_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61ab-tile-probe "$TMP_DIR/bad_summary.csv" --run-dir "$BAD_RUN_DIR.summary"

echo "p0 v61ab computed-readiness negative controls passed"
