#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gx_post_gw_first_real_slice_context_bundle_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/context_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_context_bundle_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gx first real slice workspace"

V61GX_REUSE_EXISTING="${V61GX_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gx_post_gw_first_real_slice_context_bundle_publisher.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh" >/dev/null
"$PACKAGE_DIR/PRINT_OPERATOR_CONTEXT_LOCATION.sh" >/dev/null

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
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "context_bundle_published": "0",
    "published_context_file_rows": "0",
    "selected_context_file_rows": "2",
    "review_worksheet_file_rows": "2",
    "witness_manifest_rows": "7",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "final_witness_files_written_by_v61gx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "8",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "6",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "source_file_rows": "14",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gx default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_context_bundle_source_rows.csv",
    "first_real_slice_context_bundle_summary_rows.csv",
    "first_real_slice_context_bundle_published_file_rows.csv",
    "first_real_slice_context_bundle_stage_rows.csv",
    "first_real_slice_context_bundle_command_rows.csv",
    "first_real_slice_context_bundle_package_file_rows.csv",
    "V61GX_POST_GW_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER_BOUNDARY.md",
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_manifest.json",
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_summary.csv",
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_decision.csv",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_MANIFEST.json",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_SOURCE_ROWS.csv",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_SUMMARY_ROWS.csv",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHED_FILE_ROWS.csv",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_STAGE_ROWS.csv",
    "first_real_slice_context_bundle_publisher/FIRST_REAL_SLICE_CONTEXT_BUNDLE_COMMAND_ROWS.csv",
    "first_real_slice_context_bundle_publisher/VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh",
    "first_real_slice_context_bundle_publisher/PRINT_OPERATOR_CONTEXT_LOCATION.sh",
    "source_v61gi/MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "source_v61gi/MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "source_v61gw/first_real_slice_live_checklist_gap_summary_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gx artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh", "PRINT_OPERATOR_CONTEXT_LOCATION.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gx executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gi-ready", "source-v61gw-ready", "zero-final-witness-created-by-v61gx", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gx default expected pass decision: {gate}")
for gate in ["work-root", "publish-request", "operator-context-published", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gx default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gx sha256 mismatch: {rel}")

print("v61gx default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="gx_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61GX_RUN_ID="published_context" \
V61GX_WORK_ROOT="$TMP_WORK_ROOT" \
V61GX_PUBLISH_CONTEXT=1 \
V61GX_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gx_post_gw_first_real_slice_context_bundle_publisher.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/$PREFIX/published_context" <<'PY'
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
    "context_bundle_published": "1",
    "published_context_file_rows": "9",
    "selected_context_file_rows": "2",
    "review_worksheet_file_rows": "2",
    "witness_manifest_rows": "7",
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
    "final_witness_files_written_by_v61gx": "0",
    "ready_stage_rows": "5",
    "blocked_stage_rows": "3",
    "ready_command_rows": "3",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gx published {field}: expected {value}, got {summary.get(field)}")

context_dir = work_root / "operator_context"
required_context_files = [
    "MINIMAL_SLICE_SELECTED_CONTEXT.json",
    "MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "CONTENT_WITNESS_MANIFEST_ROWS.csv",
    "MINIMAL_SLICE_REVIEW_WORKSHEET_ROWS.csv",
    "WITNESS_TO_CONTEXT_MAP.csv",
    "OPERATOR_CONTEXT_README.md",
    "RERUN_FIRST_REAL_SLICE_CONTEXT_BUNDLE.sh",
]
for rel in required_context_files:
    path = context_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v61gx missing published context file: {rel}")
if not os.access(context_dir / "RERUN_FIRST_REAL_SLICE_CONTEXT_BUNDLE.sh", os.X_OK):
    raise SystemExit("v61gx rerun script must be executable")

readme = (context_dir / "OPERATOR_CONTEXT_README.md").read_text(encoding="utf-8")
for snippet in ["non-evidence operator guide", "../final_content_witness/", "RERUN_FIRST_REAL_SLICE_GAP_AUDIT.sh"]:
    if snippet not in readme:
        raise SystemExit(f"v61gx context readme missing snippet: {snippet}")

witness_files = list((work_root / "final_content_witness").glob("*"))
if witness_files:
    raise SystemExit("v61gx must not create final witness files")

published = read_csv(run_dir / "first_real_slice_context_bundle_published_file_rows.csv")
if len([row for row in published if row["published_path"]]) != 9:
    raise SystemExit("v61gx expected nine published context files")
if any(row["counts_as_evidence"] != "0" for row in published):
    raise SystemExit("v61gx published context files must not count as evidence")
if any(row["payload_like"] != "0" for row in published):
    raise SystemExit("v61gx published context files must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "publish-request", "operator-context-published"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gx published expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gx published expected blocked decision: {gate}")

print("v61gx operator context publish smoke passed")
PY

V61GX_RUN_ID="context_001" V61GX_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gx_post_gw_first_real_slice_context_bundle_publisher.sh" >/dev/null
