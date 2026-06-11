#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61r_full_page_hash_sweep_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61r_full_page_hash_sweep_plan_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61r-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null || true
  V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null || true
}
trap cleanup EXIT

V61R_REUSE_EXISTING=1 V61R_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null

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
source_v61p_summary = read_csv(run_dir / "source_v61p" / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
plan_rows = read_csv(run_dir / "page_hash_sweep_plan_rows.csv")
shard_rows = read_csv(run_dir / "shard_page_hash_sweep_status_rows.csv")
metric = read_csv(run_dir / "page_hash_sweep_metric_rows.csv")[0]

expected = {
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "warehouse_root_override_supplied": "1",
    "checkpoint_unique_page_rows": "134161",
    "page_hash_sweep_plan_rows": "134161",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61r override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61r override summary warehouse path mismatch")
if Path(source_v61p_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61r override did not force fresh v61p warehouse preflight")
if metric["warehouse_root_override_supplied"] != "1" or Path(metric["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61r override metric warehouse fields mismatch")
if len(plan_rows) != 134161 or len(shard_rows) != 59:
    raise SystemExit("v61r override row counts mismatch")
if any(not row["local_shard_path"].startswith(str(target_dir)) for row in plan_rows[:1000]):
    raise SystemExit("v61r override page-hash plan paths should use override root")
if any(not row["target_path"].startswith(str(target_dir)) for row in shard_rows):
    raise SystemExit("v61r override shard status paths should use override root")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in shard_rows):
    raise SystemExit("v61r override must not commit checkpoint payload bytes")
PY

echo "v61r full page hash sweep plan target override smoke passed"
