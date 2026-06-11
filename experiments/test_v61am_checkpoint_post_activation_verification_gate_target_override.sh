#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61am_checkpoint_post_activation_verification_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61am_checkpoint_post_activation_verification_gate_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61am-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61AK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null || true
  V61AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61al_checkpoint_warehouse_activation_gate.sh" >/dev/null || true
  V61AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61am_checkpoint_post_activation_verification_gate.sh" >/dev/null || true
}
trap cleanup EXIT

V61AM_REUSE_EXISTING=1 V61AM_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61am_checkpoint_post_activation_verification_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$RESULTS_DIR" "$TARGET_DIR" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
results_dir = Path(sys.argv[3])
target_dir = Path(sys.argv[4]).resolve()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61al_summary = read_csv(run_dir / "source_v61al" / "v61al_checkpoint_warehouse_activation_gate_summary.csv")[0]
fresh_v61ak_summary = read_csv(
    results_dir
    / "v61al_checkpoint_warehouse_activation_gate"
    / "gate_001"
    / "source_v61ak"
    / "v61ak_checkpoint_warehouse_target_preflight_summary.csv"
)[0]
fresh_v61ak_targets = {
    row["target_id"]: row
    for row in read_csv(
        results_dir
        / "v61al_checkpoint_warehouse_activation_gate"
        / "gate_001"
        / "source_v61ak"
        / "checkpoint_warehouse_target_rows.csv"
    )
}

expected = {
    "v61am_checkpoint_post_activation_verification_gate_ready": "1",
    "v61al_checkpoint_warehouse_activation_gate_ready": "1",
    "warehouse_root_override_supplied": "1",
    "post_activation_verification_rows": "59",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61am": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61am override {field}: expected {value}, got {summary.get(field)}")

if source_v61al_summary["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61am override did not force fresh v61al planning")
if fresh_v61ak_summary["env_warehouse_root_supplied"] != "1":
    raise SystemExit("v61am override did not force fresh v61ak target probing")

env_target = fresh_v61ak_targets["env-v61ak-warehouse-root"]
if Path(env_target["target_path"]) != target_dir:
    raise SystemExit("v61am override target path mismatch")
for field, value in {
    "target_path_supplied": "1",
    "target_dir_exists": "1",
    "target_parent_writable": "1",
    "outside_repository": "1",
    "inside_repository": "0",
    "probe_ready": "1",
    "checkpoint_payload_bytes_downloaded_by_v61ak": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}.items():
    if env_target[field] != value:
        raise SystemExit(f"v61am override env target {field}: expected {value}, got {env_target[field]}")

verification_rows = read_csv(run_dir / "checkpoint_post_activation_verification_rows.csv")
if len(verification_rows) != 59:
    raise SystemExit("v61am override verification row count mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61am"] != "0" for row in verification_rows):
    raise SystemExit("v61am override must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in verification_rows):
    raise SystemExit("v61am override must not commit checkpoint payload bytes")
PY

echo "v61am checkpoint post-activation verification gate target override smoke passed"
