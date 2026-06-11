#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61w_materialization_admission_resume_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61w_materialization_admission_resume_plan_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61w-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null || true
  V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null || true
  V61W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null || true
}
trap cleanup EXIT

V61W_REUSE_EXISTING=1 V61W_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null

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
source_v61t_summary = read_csv(run_dir / "source_v61t" / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
priority_rows = read_csv(run_dir / "checkpoint_shard_priority_rows.csv")
resume_rows = read_csv(run_dir / "checkpoint_download_resume_plan_rows.csv")
metric = read_csv(run_dir / "materialization_admission_metric_rows.csv")[0]

expected = {
    "v61w_materialization_admission_resume_plan_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "warehouse_root_override_supplied": "1",
    "checkpoint_shard_rows": "59",
    "download_resume_plan_rows": "59",
    "sampled_priority_shard_rows": "16",
    "moe_priority_shard_rows": "15",
    "checkpoint_payload_bytes_downloaded_by_v61w": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61w override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61w override summary warehouse path mismatch")
if Path(source_v61p_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61w override source v61p warehouse path mismatch")
if source_v61t_summary["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61w override did not force fresh v61t planning")
if Path(source_v61t_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61w override source v61t warehouse path mismatch")
if metric["warehouse_root_override_supplied"] != "1" or Path(metric["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61w override metric warehouse fields mismatch")
if len(priority_rows) != 59 or len(resume_rows) != 59:
    raise SystemExit("v61w override row counts mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in priority_rows):
    raise SystemExit("v61w override priority targets should use override root")
if any(not row["target_path"].startswith(str(target_dir)) for row in resume_rows):
    raise SystemExit("v61w override resume targets should use override root")
if any("V61T_WAREHOUSE_ROOT=" + str(target_dir) not in row["post_download_verify_command"] for row in resume_rows):
    raise SystemExit("v61w override verify commands should preserve V61T warehouse root")
if any("V61R_WAREHOUSE_ROOT=" + str(target_dir) not in row["post_download_full_page_hash_command"] for row in resume_rows):
    raise SystemExit("v61w override full-hash commands should preserve V61R warehouse root")
if any(row["checkpoint_payload_bytes_downloaded_by_v61w"] != "0" for row in resume_rows):
    raise SystemExit("v61w override must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in resume_rows):
    raise SystemExit("v61w override must not commit checkpoint payload bytes")
PY

echo "v61w materialization admission resume plan target override smoke passed"
