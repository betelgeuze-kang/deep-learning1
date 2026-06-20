#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p1-atomic-run-dir.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"

python3 - "$TMP_DIR" <<'PY'
import csv
import sys
from pathlib import Path

from tools.pipeline_lib import atomic_run_dir, rebuild_manifest, run_packet_dir, write_summary_csv

root = Path(sys.argv[1])
final = run_packet_dir(root, "stage_a", "run_001")

with atomic_run_dir(final) as run_dir:
    if final.exists():
        raise SystemExit("final run dir must not exist before atomic publish")
    if run_dir == final:
        raise SystemExit("atomic run dir must write through a temporary directory")
    write_summary_csv(run_dir, {"stage_id": "stage_a", "run_id": "run_001", "ready": "1"})
    (run_dir / "artifact.txt").write_text("ok\n", encoding="utf-8")
    rebuild_manifest(run_dir)

if not (final / "summary.csv").is_file():
    raise SystemExit("atomic run dir must publish summary.csv")
if not (final / "artifact.txt").is_file():
    raise SystemExit("atomic run dir must publish payload artifacts")
with (final / "summary.csv").open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if rows != [{"stage_id": "stage_a", "run_id": "run_001", "ready": "1"}]:
    raise SystemExit(f"unexpected summary rows: {rows}")

try:
    with atomic_run_dir(final):
        pass
except FileExistsError:
    pass
else:
    raise SystemExit("atomic run dir must not overwrite existing run dirs")

failed = run_packet_dir(root, "stage_a", "run_failed")
try:
    with atomic_run_dir(failed) as run_dir:
        write_summary_csv(run_dir, {"stage_id": "stage_a", "run_id": "run_failed", "ready": "0"})
        (run_dir / "partial.txt").write_text("partial\n", encoding="utf-8")
        raise RuntimeError("synthetic failure")
except RuntimeError:
    pass
else:
    raise SystemExit("synthetic failure did not propagate")
if failed.exists():
    raise SystemExit("failed atomic run must not publish final directory")
if list(failed.parent.glob(f".{failed.name}.tmp-*")):
    raise SystemExit("failed atomic run must clean temporary directories")

missing_summary = run_packet_dir(root, "stage_a", "run_missing_summary")
try:
    with atomic_run_dir(missing_summary) as run_dir:
        (run_dir / "artifact.txt").write_text("missing summary\n", encoding="utf-8")
except FileNotFoundError:
    pass
else:
    raise SystemExit("atomic run dir must require summary.csv")
if missing_summary.exists():
    raise SystemExit("missing-summary atomic run must not publish final directory")

empty_summary = run_packet_dir(root, "stage_a", "run_empty_summary")
try:
    with atomic_run_dir(empty_summary) as run_dir:
        (run_dir / "summary.csv").write_text("", encoding="utf-8")
except FileNotFoundError:
    pass
else:
    raise SystemExit("atomic run dir must reject empty summary.csv")
if empty_summary.exists():
    raise SystemExit("empty-summary atomic run must not publish final directory")

for bad_stage, bad_run in [("bad/stage", "run_002"), ("stage_b", "bad/run")]:
    try:
        run_packet_dir(root, bad_stage, bad_run)
    except ValueError:
        pass
    else:
        raise SystemExit("run_packet_dir must reject path separators")

print("p1 atomic run-dir contract passed")
PY
