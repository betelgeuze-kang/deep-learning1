#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61aj_checkpoint_storage_profile_admission_matrix/matrix_001"
SUMMARY_CSV="$RESULTS_DIR/v61aj_checkpoint_storage_profile_admission_matrix_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61aj-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61AI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ai_checkpoint_storage_budget_remediation_plan.sh" >/dev/null || true
  V61AJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh" >/dev/null || true
}
trap cleanup EXIT

V61AJ_REUSE_EXISTING=1 V61AJ_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh" >/dev/null

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
source_v61ai_summary = read_csv(run_dir / "source_v61ai" / "v61ai_checkpoint_storage_budget_remediation_plan_summary.csv")[0]
priority_rows = read_csv(run_dir / "source_v61w" / "checkpoint_shard_priority_rows.csv")
metric = read_csv(run_dir / "checkpoint_storage_profile_metric_rows.csv")[0]

for field, value in {
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": "1",
    "warehouse_root_override_supplied": "1",
    "profile_rows": "6",
    "storage_profile_admission_matrix_ready": "1",
    "checkpoint_payload_bytes_downloaded_by_v61aj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61aj override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61aj override summary warehouse path mismatch")
if source_v61ai_summary["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61aj override did not force fresh v61ai planning")
if Path(source_v61ai_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61aj override source v61ai warehouse path mismatch")
if metric["warehouse_root_override_supplied"] != "1" or Path(metric["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61aj override metric warehouse fields mismatch")
if len(priority_rows) != 59:
    raise SystemExit("v61aj override priority row count mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in priority_rows):
    raise SystemExit("v61aj override source v61w targets should use override root")
PY

echo "v61aj checkpoint storage profile admission matrix target override smoke passed"
