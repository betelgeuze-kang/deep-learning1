#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gy_post_gx_first_real_slice_guarded_execution_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_guarded_execution_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gy first real slice workspace"

V61GY_REUSE_EXISTING="${V61GY_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gy_post_gx_first_real_slice_guarded_execution_publisher.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh" >/dev/null
"$PACKAGE_DIR/PRINT_GUARDED_EXECUTION_COMMAND.sh" >/dev/null

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
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready": "1",
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "guarded_runner_published": "0",
    "published_guard_file_rows": "0",
    "guarded_execution_ready_now": "0",
    "guarded_execution_attempted_by_v61gy": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "7",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "6",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "source_file_rows": "5",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gy default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_guarded_execution_source_rows.csv",
    "first_real_slice_guarded_execution_summary_rows.csv",
    "first_real_slice_guarded_execution_published_file_rows.csv",
    "first_real_slice_guarded_execution_stage_rows.csv",
    "first_real_slice_guarded_execution_command_rows.csv",
    "first_real_slice_guarded_execution_package_file_rows.csv",
    "V61GY_POST_GX_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER_BOUNDARY.md",
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_manifest.json",
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_summary.csv",
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_decision.csv",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_MANIFEST.json",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_SOURCE_ROWS.csv",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_SUMMARY_ROWS.csv",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHED_FILE_ROWS.csv",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_STAGE_ROWS.csv",
    "first_real_slice_guarded_execution_publisher/FIRST_REAL_SLICE_GUARDED_EXECUTION_COMMAND_ROWS.csv",
    "first_real_slice_guarded_execution_publisher/VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh",
    "first_real_slice_guarded_execution_publisher/PRINT_GUARDED_EXECUTION_COMMAND.sh",
    "source_v61gx/first_real_slice_context_bundle_summary_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gy artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh", "PRINT_GUARDED_EXECUTION_COMMAND.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gy executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gx-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gy default expected pass decision: {gate}")
for gate in ["work-root", "publish-request", "guarded-runner-published", "workspace-gap-preflight", "guarded-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gy default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gy sha256 mismatch: {rel}")

print("v61gy default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="gy_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61GY_RUN_ID="published_guard" \
V61GY_WORK_ROOT="$TMP_WORK_ROOT" \
V61GY_PUBLISH_GUARD=1 \
V61GY_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gy_post_gx_first_real_slice_guarded_execution_publisher.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/$PREFIX/published_guard" <<'PY'
import csv
import os
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])
run_dir = Path(sys.argv[4])


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
    "guarded_runner_published": "1",
    "published_guard_file_rows": "4",
    "context_bundle_published": "1",
    "open_gap_rows": "23",
    "content_witness_gap_rows": "7",
    "env_value_gap_rows": "16",
    "workspace_gap_preflight_ready": "0",
    "guarded_execution_ready_now": "0",
    "guarded_execution_attempted_by_v61gy": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "4",
    "blocked_stage_rows": "3",
    "ready_command_rows": "3",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gy published {field}: expected {value}, got {summary.get(field)}")

runner = work_root / "RUN_GAP_READY_FIRST_REAL_SLICE.sh"
guard_dir = work_root / "guarded_execution"
required = [
    runner,
    guard_dir / "RUN_GAP_READY_AUDIT_ONLY.sh",
    guard_dir / "GUARDED_EXECUTION_README.md",
    guard_dir / "GUARDED_EXECUTION_MANIFEST.json",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v61gy missing published guard file: {path}")
for path in [runner, guard_dir / "RUN_GAP_READY_AUDIT_ONLY.sh"]:
    if not os.access(path, os.X_OK):
        raise SystemExit(f"v61gy expected executable guard file: {path}")

run = subprocess.run([str(runner)], cwd=str(work_root), text=True, capture_output=True)
if run.returncode == 0:
    raise SystemExit("v61gy guard runner must fail closed while workspace_gap_preflight_ready=0")
if "workspace_gap_preflight_ready=0" not in run.stderr:
    raise SystemExit(f"v61gy guard runner stderr missing readiness blocker: {run.stderr}")
if "witness:review_comment.txt" not in run.stderr:
    raise SystemExit("v61gy guard runner should print missing witness item")
if (work_root / "minimal_slice" / "minimal_slice_rows.csv").exists():
    raise SystemExit("v61gy guard runner must not build minimal slice while gaps remain")

published = read_csv(run_dir / "first_real_slice_guarded_execution_published_file_rows.csv")
if len([row for row in published if row["published_path"]]) != 4:
    raise SystemExit("v61gy expected four published guard files")
if any(row["counts_as_evidence"] != "0" for row in published):
    raise SystemExit("v61gy published guard files must not count as evidence")
if any(row["payload_like"] != "0" for row in published):
    raise SystemExit("v61gy published guard files must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "publish-request", "guarded-runner-published"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gy published expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "guarded-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gy published expected blocked decision: {gate}")

print("v61gy guarded execution publish smoke passed")
PY

V61GY_RUN_ID="guard_001" V61GY_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gy_post_gx_first_real_slice_guarded_execution_publisher.sh" >/dev/null
