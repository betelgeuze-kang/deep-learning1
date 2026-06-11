#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ag_checkpoint_warehouse_execution_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v61ag_checkpoint_warehouse_execution_preflight_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61ag-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61AF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null || true
  V61AG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null || true
}
trap cleanup EXIT

V61AG_REUSE_EXISTING=1 V61AG_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$TARGET_DIR" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
target_dir = Path(sys.argv[3]).resolve()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61af_summary = read_csv(run_dir / "source_v61af" / "v61af_checkpoint_warehouse_operator_bundle_summary.csv")[0]
command_rows = read_csv(run_dir / "source_v61af" / "checkpoint_warehouse_operator_command_rows.csv")
operator_env = (run_dir / "operator_bundle" / "operator_env.template").read_text(encoding="utf-8")
download_script = (run_dir / "operator_bundle" / "download_priority_queue.sh").read_text(encoding="utf-8")

for field, value in {
    "v61ag_checkpoint_warehouse_execution_preflight_ready": "1",
    "warehouse_root_override_supplied": "1",
    "download_dry_run_guard_ready": "1",
    "checkpoint_payload_bytes_downloaded_by_v61ag": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ag override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61ag override summary warehouse path mismatch")
if source_v61af_summary["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61ag override did not force fresh v61af bundle")
if Path(source_v61af_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61ag override source v61af warehouse path mismatch")

download_rows = [row for row in command_rows if row["command_type"] == "download-resume"]
if len(download_rows) != 59:
    raise SystemExit("v61ag override download row count mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in download_rows):
    raise SystemExit("v61ag override download targets should use override root")
for content, label in [(operator_env, "operator env"), (download_script, "download script")]:
    if str(target_dir) not in content or "V61AF_WAREHOUSE_ROOT" not in content:
        raise SystemExit(f"v61ag override {label} should preserve target root")
PY

echo "v61ag checkpoint warehouse execution preflight target override smoke passed"
