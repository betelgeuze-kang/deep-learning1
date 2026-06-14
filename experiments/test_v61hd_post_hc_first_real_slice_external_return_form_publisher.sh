#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hd_post_hc_first_real_slice_external_return_form_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/external_return_form_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_external_return_form_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hd first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61hd checkpoint root"

V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER.sh" >/dev/null

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
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_ready": "1",
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "external_return_form_published": "0",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hd default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_external_return_form_source_rows.csv",
    "first_real_slice_external_return_form_published_rows.csv",
    "first_real_slice_external_return_form_stage_rows.csv",
    "first_real_slice_external_return_form_command_rows.csv",
    "first_real_slice_external_return_form_package_file_rows.csv",
    "V61HD_POST_HC_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER_BOUNDARY.md",
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_manifest.json",
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_summary.csv",
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_decision.csv",
    "first_real_slice_external_return_form_publisher/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_MANIFEST.json",
    "first_real_slice_external_return_form_publisher/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHED_ROWS.csv",
    "first_real_slice_external_return_form_publisher/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_STAGE_ROWS.csv",
    "first_real_slice_external_return_form_publisher/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_COMMAND_ROWS.csv",
    "first_real_slice_external_return_form_publisher/VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER.sh",
    "source_v61hc/v61hc_post_hb_first_real_slice_precheck_runner_publisher_summary.csv",
    "source_v61gi/MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "source_v61gv/first_real_slice_workspace_missing_item_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    if not (run_dir / rel).is_file():
        raise SystemExit(f"missing v61hd artifact: {rel}")

if not os.access(package_dir / "VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER.sh", os.X_OK):
    raise SystemExit("v61hd verifier executable bit missing")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61hc-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hd default expected pass decision: {gate}")
for gate in ["work-root", "publish-request", "external-return-form-published", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hd default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hd sha256 mismatch: {rel}")

print("v61hd default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="hd_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61HA_RUN_ID="hd_promoted_source_witness" \
V61HA_WORK_ROOT="$TMP_WORK_ROOT" \
V61HA_EXECUTE_PROMOTION=1 \
V61HA_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

V61HB_RUN_ID="hd_applied_checkpoint_root" \
V61HB_WORK_ROOT="$TMP_WORK_ROOT" \
V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" \
V61HB_APPLY_CHECKPOINT_ROOT=1 \
V61HB_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null

V61HC_RUN_ID="hd_precheck_runner" \
V61HC_WORK_ROOT="$TMP_WORK_ROOT" \
V61HC_PUBLISH_PRECHECK_RUNNER=1 \
V61HC_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null

V61HD_RUN_ID="published_external_return_form" \
V61HD_WORK_ROOT="$TMP_WORK_ROOT" \
V61HD_PUBLISH_FORM=1 \
V61HD_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null

set +e
"$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" \
  "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template" \
  "$TMP_WORK_ROOT/external_return_form/template.validation_rows.csv" \
  >/tmp/v61hd_form_stdout.txt 2>/tmp/v61hd_form_stderr.txt
form_exit=$?
set -e
if [[ "$form_exit" -eq 0 ]]; then
  echo "v61hd expected template validation to fail" >&2
  exit 1
fi

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import os
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "publish_requested": "1",
    "publish_admitted": "1",
    "external_return_form_published": "1",
    "open_gap_rows": "21",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hd published {field}: expected {value}, got {summary.get(field)}")

form_dir = work_root / "external_return_form"
for name in [
    "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template",
    "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py",
    "EXTERNAL_RETURN_FORM_README.md",
    "template.validation_rows.csv",
]:
    if not (form_dir / name).is_file():
        raise SystemExit(f"v61hd missing published form file: {name}")
if not os.access(form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py", os.X_OK):
    raise SystemExit("v61hd validator executable bit missing")
rows = read_csv(form_dir / "template.validation_rows.csv")
if not any(row["check_id"] == "source-class" and row["status"] == "blocked" for row in rows):
    raise SystemExit("v61hd expected source-class blocked row")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "publish-request", "external-return-form-published", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hd published expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hd published expected blocked decision: {gate}")

print("v61hd published external return form smoke passed")
PY

V61HD_RUN_ID="external_return_form_001" V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
V61HC_RUN_ID="precheck_runner_001" V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
