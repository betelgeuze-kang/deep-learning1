#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate_decision.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61al-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61AK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null || true
  V61AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61al_checkpoint_warehouse_activation_gate.sh" >/dev/null || true
}
trap cleanup EXIT

V61AL_REUSE_EXISTING=1 V61AL_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61al_checkpoint_warehouse_activation_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$TARGET_DIR" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
target_dir = Path(sys.argv[4]).resolve()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61ak_summary = read_csv(run_dir / "source_v61ak" / "v61ak_checkpoint_warehouse_target_preflight_summary.csv")[0]

expected = {
    "v61al_checkpoint_warehouse_activation_gate_ready": "1",
    "v61ak_checkpoint_warehouse_target_preflight_ready": "1",
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "warehouse_root_override_supplied": "1",
    "activation_command_rows": "59",
    "selected_backend_id": "curl-resume",
    "backend_ready": "1",
    "explicit_execute_required": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61al": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61al override {field}: expected {value}, got {summary.get(field)}")

if source_v61ak_summary["env_warehouse_root_supplied"] != "1":
    raise SystemExit("v61al override did not force v61ak env target evaluation")
if summary["selected_target_id"] != source_v61ak_summary["selected_target_id"]:
    raise SystemExit("v61al selected target should mirror the fresh v61ak target preflight")
if summary["selected_target_path"] != source_v61ak_summary["selected_target_path"]:
    raise SystemExit("v61al selected target path should mirror the fresh v61ak target preflight")

target_rows = {row["target_id"]: row for row in read_csv(run_dir / "source_v61ak" / "checkpoint_warehouse_target_rows.csv")}
env_target = target_rows["env-v61ak-warehouse-root"]
if Path(env_target["target_path"]) != target_dir:
    raise SystemExit("v61al override target path mismatch")
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
        raise SystemExit(f"v61al override env target {field}: expected {value}, got {env_target[field]}")

activation_rows = read_csv(run_dir / "checkpoint_warehouse_activation_command_rows.csv")
if len(activation_rows) != 59:
    raise SystemExit("v61al override activation row count mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61al"] != "0" for row in activation_rows):
    raise SystemExit("v61al override must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in activation_rows):
    raise SystemExit("v61al override must not commit checkpoint payload bytes")

selected = summary["selected_target_id"] != "none"
if selected:
    if summary["activation_admitted_rows"] != "59" or summary["activation_package_ready"] != "1":
        raise SystemExit("v61al override selected target should admit all activation rows")
    if not all(row["command_preview"] for row in activation_rows):
        raise SystemExit("v61al override selected target should emit command previews")
else:
    if summary["activation_admitted_rows"] != "0" or summary["activation_package_ready"] != "0":
        raise SystemExit("v61al override with no selected target should keep activation blocked")
    if any(row["command_preview"] for row in activation_rows):
        raise SystemExit("v61al override without selected target should not emit command previews")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["v61ak-warehouse-target-input"] != "pass" or decisions["v61ah-backend-input"] != "pass":
    raise SystemExit("v61al override input gates should pass")
if decisions["explicit-download-execution"] != "blocked":
    raise SystemExit("v61al override should keep explicit payload execution blocked")
PY

echo "v61al checkpoint warehouse activation gate target override smoke passed"
