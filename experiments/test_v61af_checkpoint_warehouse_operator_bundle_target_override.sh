#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61af_checkpoint_warehouse_operator_bundle/operator_001"
SUMMARY_CSV="$RESULTS_DIR/v61af_checkpoint_warehouse_operator_bundle_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61af-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null || true
  V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null || true
  V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null || true
  V61W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null || true
  V61AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null || true
  V61AF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null || true
}
trap cleanup EXIT

V61AF_REUSE_EXISTING=1 V61AF_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null

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
source_v61p_summary = read_csv(run_dir / "source_v61p" / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
source_v61w_summary = read_csv(run_dir / "source_v61w" / "v61w_materialization_admission_resume_plan_summary.csv")[0]
source_v61t_summary = read_csv(run_dir / "source_v61t" / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
source_v61r_summary = read_csv(run_dir / "source_v61r" / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
source_v61ae_summary = read_csv(run_dir / "source_v61ae" / "v61ae_real_generation_admission_gate_summary.csv")[0]
command_rows = read_csv(run_dir / "checkpoint_warehouse_operator_command_rows.csv")
metric = read_csv(run_dir / "checkpoint_warehouse_operator_metric_rows.csv")[0]
source_resume_rows = read_csv(run_dir / "source_v61w" / "checkpoint_download_resume_plan_rows.csv")

expected = {
    "v61af_checkpoint_warehouse_operator_bundle_ready": "1",
    "warehouse_root_override_supplied": "1",
    "download_command_rows": "59",
    "operator_command_rows": "62",
    "checkpoint_payload_bytes_downloaded_by_v61af": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61af override {field}: expected {value}, got {summary.get(field)}")

if Path(summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61af override summary warehouse path mismatch")
if Path(source_v61p_summary["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61af override source v61p warehouse path mismatch")
for name, source_summary in [
    ("v61w", source_v61w_summary),
    ("v61t", source_v61t_summary),
    ("v61r", source_v61r_summary),
]:
    if source_summary["warehouse_root_override_supplied"] != "1":
        raise SystemExit(f"v61af override did not force fresh {name} planning")
    if Path(source_summary["ssd_warehouse_path"]) != target_dir:
        raise SystemExit(f"v61af override {name} warehouse path mismatch")
if source_v61ae_summary["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61af override did not force fresh v61ae admission planning")
if metric["warehouse_root_override_supplied"] != "1" or Path(metric["ssd_warehouse_path"]) != target_dir:
    raise SystemExit("v61af override metric warehouse fields mismatch")

download_rows = [row for row in command_rows if row["command_type"] == "download-resume"]
verify_rows = [row for row in command_rows if row["command_type"] == "verify"]
hash_rows = [row for row in command_rows if row["command_type"] == "hash"]
admission_rows = [row for row in command_rows if row["command_type"] == "admission"]
if len(download_rows) != 59 or len(verify_rows) != 1 or len(hash_rows) != 1 or len(admission_rows) != 1:
    raise SystemExit("v61af override command type row counts mismatch")
if any(not row["target_path"].startswith(str(target_dir)) for row in download_rows):
    raise SystemExit("v61af override download targets should use override root")
if "V61T_WAREHOUSE_ROOT=" + str(target_dir) not in verify_rows[0]["shell_command"]:
    raise SystemExit("v61af override verify command should preserve V61T warehouse root")
if "V61R_WAREHOUSE_ROOT=" + str(target_dir) not in hash_rows[0]["shell_command"]:
    raise SystemExit("v61af override hash command should preserve V61R warehouse root")
if "V61AE_WAREHOUSE_ROOT=" + str(target_dir) not in admission_rows[0]["shell_command"]:
    raise SystemExit("v61af override admission command should preserve V61AE warehouse root")
if any("V61T_WAREHOUSE_ROOT=" + str(target_dir) not in row["post_download_verify_command"] for row in source_resume_rows):
    raise SystemExit("v61af override source v61w verify commands should preserve target")
if any("V61R_WAREHOUSE_ROOT=" + str(target_dir) not in row["post_download_full_page_hash_command"] for row in source_resume_rows):
    raise SystemExit("v61af override source v61w hash commands should preserve target")
if any(row["checkpoint_payload_bytes_downloaded_by_v61af"] != "0" for row in command_rows):
    raise SystemExit("v61af override must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in command_rows):
    raise SystemExit("v61af override must not commit checkpoint payload bytes")

operator_env = (run_dir / "operator_bundle" / "operator_env.template").read_text(encoding="utf-8")
download_script = (run_dir / "operator_bundle" / "download_priority_queue.sh").read_text(encoding="utf-8")
verify_script = (run_dir / "operator_bundle" / "verify_materialization.sh").read_text(encoding="utf-8")
hash_script = (run_dir / "operator_bundle" / "run_full_page_hash_sweep.sh").read_text(encoding="utf-8")
admission_script = (run_dir / "operator_bundle" / "recheck_real_generation_admission.sh").read_text(encoding="utf-8")
for content, label in [
    (operator_env, "operator_env"),
    (download_script, "download_script"),
    (verify_script, "verify_script"),
    (hash_script, "hash_script"),
    (admission_script, "admission_script"),
]:
    if str(target_dir) not in content:
        raise SystemExit(f"v61af override {label} should include target path")
    if "V61AF_WAREHOUSE_ROOT" not in content:
        raise SystemExit(f"v61af override {label} should include V61AF_WAREHOUSE_ROOT")

for rel in [
    "operator_bundle/download_priority_queue.sh",
    "operator_bundle/verify_materialization.sh",
    "operator_bundle/run_full_page_hash_sweep.sh",
    "operator_bundle/recheck_real_generation_admission.sh",
]:
    subprocess.run(["bash", "-n", str(run_dir / rel)], check=True)
PY

echo "v61af checkpoint warehouse operator bundle target override smoke passed"
