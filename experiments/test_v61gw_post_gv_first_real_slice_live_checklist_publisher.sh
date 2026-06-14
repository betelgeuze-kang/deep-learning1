#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gw_post_gv_first_real_slice_live_checklist_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/publish_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_live_checklist_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gw first real slice workspace"

V61GW_REUSE_EXISTING="${V61GW_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gw_post_gv_first_real_slice_live_checklist_publisher.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh" >/dev/null
"$PACKAGE_DIR/PRINT_LIVE_CHECKLIST_LOCATION.sh" >/dev/null

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
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_ready": "1",
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "live_checklist_published": "0",
    "published_file_rows": "0",
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
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "source_file_rows": "6",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gw default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_live_checklist_source_rows.csv",
    "first_real_slice_live_checklist_gap_summary_rows.csv",
    "first_real_slice_live_checklist_published_file_rows.csv",
    "first_real_slice_live_checklist_stage_rows.csv",
    "first_real_slice_live_checklist_command_rows.csv",
    "first_real_slice_live_checklist_package_file_rows.csv",
    "V61GW_POST_GV_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER_BOUNDARY.md",
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_manifest.json",
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_summary.csv",
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_decision.csv",
    "first_real_slice_live_checklist_publisher/FIRST_REAL_SLICE_LIVE_CHECKLIST_GAP_SUMMARY_ROWS.csv",
    "first_real_slice_live_checklist_publisher/FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHED_FILE_ROWS.csv",
    "first_real_slice_live_checklist_publisher/FIRST_REAL_SLICE_LIVE_CHECKLIST_STAGE_ROWS.csv",
    "first_real_slice_live_checklist_publisher/FIRST_REAL_SLICE_LIVE_CHECKLIST_COMMAND_ROWS.csv",
    "first_real_slice_live_checklist_publisher/FIRST_REAL_SLICE_LIVE_CHECKLIST_MANIFEST.json",
    "first_real_slice_live_checklist_publisher/VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh",
    "first_real_slice_live_checklist_publisher/PRINT_LIVE_CHECKLIST_LOCATION.sh",
    "source_v61gv/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gw artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh", "PRINT_LIVE_CHECKLIST_LOCATION.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gw executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gv-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gw default expected pass decision: {gate}")
for gate in ["work-root", "publish-request", "live-checklist-published", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gw default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gw sha256 mismatch: {rel}")

print("v61gw default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="gw_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61GW_RUN_ID="published_checklist" \
V61GW_WORK_ROOT="$TMP_WORK_ROOT" \
V61GW_PUBLISH_CHECKLIST=1 \
V61GW_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gw_post_gv_first_real_slice_live_checklist_publisher.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/$PREFIX/published_checklist" <<'PY'
import csv
import os
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
    "live_checklist_published": "1",
    "published_file_rows": "6",
    "open_gap_rows": "23",
    "content_witness_gap_rows": "7",
    "env_value_gap_rows": "16",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_command_rows": "3",
    "blocked_command_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gw published {field}: expected {value}, got {summary.get(field)}")

checklist = work_root / "live_gap_checklist" / "LIVE_FIRST_REAL_SLICE_GAP_CHECKLIST.md"
rerun = work_root / "live_gap_checklist" / "RERUN_FIRST_REAL_SLICE_GAP_AUDIT.sh"
if not checklist.is_file() or checklist.stat().st_size == 0:
    raise SystemExit("v61gw expected live checklist markdown")
if not rerun.is_file() or not os.access(rerun, os.X_OK):
    raise SystemExit("v61gw expected executable rerun script")
text = checklist.read_text(encoding="utf-8")
for snippet in ["open_gap_rows: 23", "content_witness_gap_rows: 7", "env_value_gap_rows: 16", "This checklist is not evidence"]:
    if snippet not in text:
        raise SystemExit(f"v61gw checklist missing snippet: {snippet}")

published = read_csv(run_dir / "first_real_slice_live_checklist_published_file_rows.csv")
if len([row for row in published if row["published_path"]]) != 6:
    raise SystemExit("v61gw expected six published files")
if any(row["payload_like"] != "0" for row in published):
    raise SystemExit("v61gw published files must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "publish-request", "live-checklist-published"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gw published expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gw published expected blocked decision: {gate}")

print("v61gw live checklist publish smoke passed")
PY

V61GW_RUN_ID="publish_001" V61GW_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gw_post_gv_first_real_slice_live_checklist_publisher.sh" >/dev/null
