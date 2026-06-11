#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61t_local_checkpoint_materialization_verifier/verify_001"
SUMMARY_CSV="$RESULTS_DIR/v61t_local_checkpoint_materialization_verifier_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61t-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null || true
  V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null || true
}
trap cleanup EXIT

V61T_REUSE_EXISTING=1 V61T_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null

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
warehouse_rows = read_csv(run_dir / "source_v61p" / "ssd_warehouse_probe_rows.csv")
materialization_rows = read_csv(run_dir / "local_checkpoint_materialization_rows.csv")

expected = {
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "warehouse_root_override_supplied": "1",
    "checkpoint_shard_rows": "59",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61t override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61t override summary warehouse path mismatch")
if Path(source_v61p_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61t override did not force fresh v61p warehouse preflight")
if len(warehouse_rows) != 1 or Path(warehouse_rows[0]["warehouse_path"]) != target_dir:
    raise SystemExit("v61t override source_v61p warehouse row mismatch")
for field, value in {
    "warehouse_dir_exists": "1",
    "warehouse_inside_repo": "0",
    "warehouse_outside_repo": "1",
    "warehouse_allowed": "1",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "checkpoint_payload_bytes_downloaded_by_v61p": "0",
}.items():
    if warehouse_rows[0][field] != value:
        raise SystemExit(f"v61t override warehouse row {field}: expected {value}, got {warehouse_rows[0][field]}")

if len(materialization_rows) != 59:
    raise SystemExit("v61t override materialization row count mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in materialization_rows):
    raise SystemExit("v61t override materialization target paths should use override root")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in materialization_rows):
    raise SystemExit("v61t override must not commit checkpoint payload bytes")
PY

echo "v61t local checkpoint materialization verifier target override smoke passed"
