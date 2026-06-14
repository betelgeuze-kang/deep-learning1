#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hb_post_ha_first_real_slice_checkpoint_root_env_audit"
RUN_DIR="$RESULTS_DIR/$PREFIX/checkpoint_env_audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_checkpoint_root_env_audit"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hb first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61hb checkpoint root"

V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh" >/dev/null

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
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready": "1",
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "env_template_exists": "0",
    "checkpoint_root_supplied": "0",
    "checkpoint_root_exists": "0",
    "checkpoint_root_outside_repo": "0",
    "expected_checkpoint_shard_rows": "59",
    "observed_checkpoint_safetensor_rows": "0",
    "checkpoint_root_valid": "0",
    "checkpoint_env_apply_requested": "0",
    "checkpoint_env_apply_admitted": "0",
    "checkpoint_env_applied": "0",
    "checkpoint_env_ready_after_audit": "0",
    "ready_value_env_rows_after_audit": "0",
    "env_value_gap_rows_after_audit": "16",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hb default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_checkpoint_root_env_audit_source_rows.csv",
    "first_real_slice_checkpoint_root_env_shard_rows.csv",
    "first_real_slice_checkpoint_root_env_candidate_rows.csv",
    "first_real_slice_checkpoint_root_env_apply_rows.csv",
    "first_real_slice_checkpoint_root_env_stage_rows.csv",
    "first_real_slice_checkpoint_root_env_command_rows.csv",
    "first_real_slice_checkpoint_root_env_package_file_rows.csv",
    "V61HB_POST_HA_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT_BOUNDARY.md",
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_manifest.json",
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_summary.csv",
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_decision.csv",
    "first_real_slice_checkpoint_root_env_audit/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_MANIFEST.json",
    "first_real_slice_checkpoint_root_env_audit/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_CANDIDATE_ROWS.csv",
    "first_real_slice_checkpoint_root_env_audit/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_APPLY_ROWS.csv",
    "first_real_slice_checkpoint_root_env_audit/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_STAGE_ROWS.csv",
    "first_real_slice_checkpoint_root_env_audit/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_COMMAND_ROWS.csv",
    "first_real_slice_checkpoint_root_env_audit/VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh",
    "source_v61ha/v61ha_post_gz_first_real_slice_source_witness_promotion_audit_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    if not (run_dir / rel).is_file():
        raise SystemExit(f"missing v61hb artifact: {rel}")

if not os.access(package_dir / "VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh", os.X_OK):
    raise SystemExit("v61hb verifier executable bit missing")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61ha-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hb default expected pass decision: {gate}")
for gate in ["work-root", "env-template", "checkpoint-root", "checkpoint-env-apply", "checkpoint-env-ready", "real-review-return", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hb default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hb sha256 mismatch: {rel}")

print("v61hb default no-checkpoint-root smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="hb_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61HA_RUN_ID="hb_promoted_source_witness" \
V61HA_WORK_ROOT="$TMP_WORK_ROOT" \
V61HA_EXECUTE_PROMOTION=1 \
V61HA_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

V61HB_RUN_ID="applied_checkpoint_root" \
V61HB_WORK_ROOT="$TMP_WORK_ROOT" \
V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" \
V61HB_APPLY_CHECKPOINT_ROOT=1 \
V61HB_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null

V61GV_RUN_ID="hb_post_checkpoint_env" \
V61GV_WORK_ROOT="$TMP_WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT" "$RESULTS_DIR/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])
checkpoint_root = Path(sys.argv[4])
gv_summary_csv = Path(sys.argv[5])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "env_template_exists": "1",
    "checkpoint_root_supplied": "1",
    "checkpoint_root_exists": "1",
    "checkpoint_root_outside_repo": "1",
    "observed_checkpoint_safetensor_rows": "59",
    "checkpoint_root_valid": "1",
    "checkpoint_env_present_before": "1",
    "checkpoint_env_was_placeholder": "1",
    "checkpoint_env_apply_requested": "1",
    "checkpoint_env_apply_admitted": "1",
    "checkpoint_env_applied": "1",
    "checkpoint_env_ready_after_audit": "1",
    "ready_value_env_rows_after_audit": "1",
    "env_value_gap_rows_after_audit": "15",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hb applied {field}: expected {value}, got {summary.get(field)}")

env_text = (work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh").read_text(encoding="utf-8")
expected_line = f"export V61GI_CHECKPOINT_ROOT='{checkpoint_root}'"
if expected_line not in env_text:
    raise SystemExit("v61hb expected quoted checkpoint root env line")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "env-template", "checkpoint-root", "checkpoint-env-apply", "checkpoint-env-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hb applied expected pass decision: {gate}")
for gate in ["real-review-return", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hb applied expected blocked decision: {gate}")

gv = read_csv(gv_summary_csv)[0]
gv_expected = {
    "ready_witness_rows": "1",
    "ready_value_env_rows": "1",
    "open_gap_rows": "21",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in gv_expected.items():
    if gv.get(field) != value:
        raise SystemExit(f"v61gv after v61hb {field}: expected {value}, got {gv.get(field)}")

print("v61hb applied checkpoint root env audit smoke passed")
PY

V61HB_RUN_ID="checkpoint_env_audit_001" V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
V61HA_RUN_ID="promotion_audit_001" V61HA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null
