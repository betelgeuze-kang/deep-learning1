#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gv_post_gu_first_real_slice_workspace_gap_audit"
RUN_DIR="$RESULTS_DIR/$PREFIX/audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_workspace_gap_audit"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gv first real slice workspace"

V61GU_RUN_ID="workspace_001" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
V61GV_REUSE_EXISTING="${V61GV_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh" >/dev/null
"$PACKAGE_DIR/PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": "1",
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "workspace_layout_ready": "0",
    "env_template_exists": "0",
    "final_runner_executable": "0",
    "workspace_verifier_executable": "0",
    "witness_rows": "7",
    "ready_witness_rows": "0",
    "content_witness_gap_closed": "0",
    "env_rows": "20",
    "path_env_rows": "4",
    "ready_path_env_rows": "0",
    "value_env_rows": "16",
    "ready_value_env_rows": "0",
    "env_gap_closed": "0",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "10",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "9",
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "source_file_rows": "2",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gv default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_workspace_gap_source_rows.csv",
    "first_real_slice_workspace_layout_rows.csv",
    "first_real_slice_workspace_witness_rows.csv",
    "first_real_slice_workspace_env_rows.csv",
    "first_real_slice_workspace_missing_item_rows.csv",
    "first_real_slice_workspace_gap_stage_rows.csv",
    "first_real_slice_workspace_gap_command_rows.csv",
    "first_real_slice_workspace_gap_package_file_rows.csv",
    "V61GV_POST_GU_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT_BOUNDARY.md",
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_manifest.json",
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv",
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_decision.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_LAYOUT_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_WITNESS_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_ENV_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_MISSING_ITEM_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_GAP_STAGE_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_GAP_COMMAND_ROWS.csv",
    "first_real_slice_workspace_gap_audit/FIRST_REAL_SLICE_WORKSPACE_GAP_MANIFEST.json",
    "first_real_slice_workspace_gap_audit/VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh",
    "first_real_slice_workspace_gap_audit/PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh",
    "source_v61gu/v61gu_post_gt_first_real_slice_operator_workspace_initializer_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gv artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh", "PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gv executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gu-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gv default expected pass decision: {gate}")
for gate in ["work-root", "workspace-layout", "content-witness-gap", "env-gap", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gv default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gv sha256 mismatch: {rel}")

print("v61gv default no-work-root smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="gv_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61GV_RUN_ID="initialized_gap" \
V61GV_WORK_ROOT="$TMP_WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/initialized_gap" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
run_dir = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "workspace_layout_ready": "1",
    "env_template_exists": "1",
    "final_runner_executable": "1",
    "workspace_verifier_executable": "1",
    "ready_witness_rows": "0",
    "content_witness_gap_closed": "0",
    "ready_path_env_rows": "4",
    "ready_value_env_rows": "0",
    "env_gap_closed": "0",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "5",
    "blocked_stage_rows": "5",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gv initialized {field}: expected {value}, got {summary.get(field)}")

missing = read_csv(run_dir / "first_real_slice_workspace_missing_item_rows.csv")
if not any(row["item_family"] == "content-witness" for row in missing):
    raise SystemExit("v61gv initialized expected content witness gaps")
if not any(row["item_family"] == "env-value" for row in missing):
    raise SystemExit("v61gv initialized expected env value gaps")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "workspace-layout"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gv initialized expected pass decision: {gate}")
for gate in ["content-witness-gap", "env-gap", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gv initialized expected blocked decision: {gate}")

print("v61gv initialized workspace gap smoke passed")
PY

V61GU_RUN_ID="workspace_001" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
V61GV_RUN_ID="audit_001" V61GV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null
