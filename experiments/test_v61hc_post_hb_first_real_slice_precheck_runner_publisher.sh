#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hc_post_hb_first_real_slice_precheck_runner_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/precheck_runner_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_precheck_runner_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hc first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61hc checkpoint root"

V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER.sh" >/dev/null

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
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready": "1",
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "env_template_exists": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "precheck_runner_published": "0",
    "precheck_runner_executable": "0",
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
        raise SystemExit(f"v61hc default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_precheck_runner_source_rows.csv",
    "first_real_slice_precheck_runner_published_rows.csv",
    "first_real_slice_precheck_runner_stage_rows.csv",
    "first_real_slice_precheck_runner_command_rows.csv",
    "first_real_slice_precheck_runner_package_file_rows.csv",
    "V61HC_POST_HB_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER_BOUNDARY.md",
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_manifest.json",
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_summary.csv",
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_decision.csv",
    "first_real_slice_precheck_runner_publisher/FIRST_REAL_SLICE_PRECHECK_RUNNER_MANIFEST.json",
    "first_real_slice_precheck_runner_publisher/FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHED_ROWS.csv",
    "first_real_slice_precheck_runner_publisher/FIRST_REAL_SLICE_PRECHECK_RUNNER_STAGE_ROWS.csv",
    "first_real_slice_precheck_runner_publisher/FIRST_REAL_SLICE_PRECHECK_RUNNER_COMMAND_ROWS.csv",
    "first_real_slice_precheck_runner_publisher/VERIFY_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER.sh",
    "source_v61hb/v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_summary.csv",
    "source_v61gi/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py",
    "source_v61gv/first_real_slice_workspace_missing_item_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    if not (run_dir / rel).is_file():
        raise SystemExit(f"missing v61hc artifact: {rel}")

if not os.access(package_dir / "VERIFY_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER.sh", os.X_OK):
    raise SystemExit("v61hc verifier executable bit missing")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61hb-ready", "source-v61gi-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hc default expected pass decision: {gate}")
for gate in ["work-root", "env-template", "publish-request", "precheck-runner-published", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hc default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hc sha256 mismatch: {rel}")

print("v61hc default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="hc_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61HA_RUN_ID="hc_promoted_source_witness" \
V61HA_WORK_ROOT="$TMP_WORK_ROOT" \
V61HA_EXECUTE_PROMOTION=1 \
V61HA_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

V61HB_RUN_ID="hc_applied_checkpoint_root" \
V61HB_WORK_ROOT="$TMP_WORK_ROOT" \
V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" \
V61HB_APPLY_CHECKPOINT_ROOT=1 \
V61HB_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null

V61HC_RUN_ID="published_precheck_runner" \
V61HC_WORK_ROOT="$TMP_WORK_ROOT" \
V61HC_PUBLISH_PRECHECK_RUNNER=1 \
V61HC_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null

set +e
"$TMP_WORK_ROOT/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh" >/tmp/v61hc_precheck_stdout.txt 2>/tmp/v61hc_precheck_stderr.txt
precheck_exit=$?
set -e
if [[ "$precheck_exit" -eq 0 ]]; then
  echo "v61hc expected precheck-only runner to fail on incomplete witness/env values" >&2
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
    "env_template_exists": "1",
    "publish_requested": "1",
    "publish_admitted": "1",
    "precheck_runner_published": "1",
    "precheck_runner_executable": "1",
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
        raise SystemExit(f"v61hc published {field}: expected {value}, got {summary.get(field)}")

runner = work_root / "RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh"
if not runner.is_file() or not os.access(runner, os.X_OK):
    raise SystemExit("v61hc expected executable precheck runner")
report = work_root / "precheck_runner" / "FIRST_REAL_SLICE_INPUT_PRECHECK_ROWS.csv"
if not report.is_file():
    raise SystemExit("v61hc expected blocked precheck report CSV")
rows = read_csv(report)
if not any(row["status"] == "blocked" and "V61GI_REVIEWER_ID" in row["evidence"] for row in rows):
    raise SystemExit("v61hc expected reviewer id blocked row in precheck report")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "env-template", "publish-request", "precheck-runner-published", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hc published expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61hc published expected blocked decision: {gate}")

print("v61hc published precheck runner smoke passed")
PY

V61HC_RUN_ID="precheck_runner_001" V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
V61HB_RUN_ID="checkpoint_env_audit_001" V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
