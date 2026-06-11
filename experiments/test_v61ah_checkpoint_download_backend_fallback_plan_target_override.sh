#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ah_checkpoint_download_backend_fallback_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61ah_checkpoint_download_backend_fallback_plan_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61ah-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61AG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null || true
  V61AH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null || true
}
trap cleanup EXIT

V61AH_REUSE_EXISTING=1 V61AH_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$TARGET_DIR" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
target_dir = Path(sys.argv[3]).resolve()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61ag_summary = read_csv(run_dir / "source_v61ag" / "v61ag_checkpoint_warehouse_execution_preflight_summary.csv")[0]
source_v61af_summary = read_csv(run_dir / "source_v61af" / "v61af_checkpoint_warehouse_operator_bundle_summary.csv")[0]
plan_rows = read_csv(run_dir / "checkpoint_download_backend_plan_rows.csv")
script_path = run_dir / "operator_bundle" / "download_priority_queue_backend.sh"
script = script_path.read_text(encoding="utf-8")

for field, value in {
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "warehouse_root_override_supplied": "1",
    "download_backend_plan_rows": "59",
    "download_backend_dry_run_guard_ready": "1",
    "checkpoint_payload_bytes_downloaded_by_v61ah": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ah override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61ah override summary warehouse path mismatch")
for name, source_summary in [("v61ag", source_v61ag_summary), ("v61af", source_v61af_summary)]:
    if source_summary["warehouse_root_override_supplied"] != "1":
        raise SystemExit(f"v61ah override did not force fresh {name} planning")
    if Path(source_summary["ssd_warehouse_path"]) != target_dir:
        raise SystemExit(f"v61ah override {name} warehouse path mismatch")
if len(plan_rows) != 59:
    raise SystemExit("v61ah override plan row count mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in plan_rows):
    raise SystemExit("v61ah override target paths should use override root")
if any(str(target_dir) not in row["download_command"] for row in plan_rows[:5]):
    raise SystemExit("v61ah override download commands should preserve target root")
if str(target_dir) not in script or "V61AH_WAREHOUSE_ROOT" not in script:
    raise SystemExit("v61ah override backend script should preserve target root")
subprocess.run(["bash", "-n", str(script_path)], check=True)
PY

echo "v61ah checkpoint download backend fallback plan target override smoke passed"
