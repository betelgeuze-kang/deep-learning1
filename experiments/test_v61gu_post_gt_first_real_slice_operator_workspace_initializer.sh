#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gu_post_gt_first_real_slice_operator_workspace_initializer"
RUN_DIR="$RESULTS_DIR/$PREFIX/workspace_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_operator_workspace_initializer"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gu first real slice workspace"

V61GU_REUSE_EXISTING="${V61GU_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh" >/dev/null
"$PACKAGE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import json
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
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "v61gt_post_gs_ack_packet_to_replay_handoff_ready": "1",
    "work_root_supplied": "0",
    "work_root_outside_repo": "0",
    "workspace_initialize_requested": "0",
    "workspace_initialized": "0",
    "workspace_file_rows": "0",
    "template_witness_file_rows": "0",
    "final_witness_file_rows": "7",
    "final_witness_ready_rows": "0",
    "final_witness_accepted_as_real_evidence_rows": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "7",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "5",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "source_file_rows": "6",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gu default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_operator_workspace_source_rows.csv",
    "first_real_slice_external_workspace_file_rows.csv",
    "first_real_slice_final_witness_rows.csv",
    "first_real_slice_operator_workspace_stage_rows.csv",
    "first_real_slice_operator_workspace_command_rows.csv",
    "first_real_slice_operator_workspace_package_file_rows.csv",
    "V61GU_POST_GT_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER_BOUNDARY.md",
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_manifest.json",
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_summary.csv",
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_decision.csv",
    "first_real_slice_operator_workspace_initializer/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_STAGE_ROWS.csv",
    "first_real_slice_operator_workspace_initializer/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_COMMAND_ROWS.csv",
    "first_real_slice_operator_workspace_initializer/FIRST_REAL_SLICE_FINAL_WITNESS_ROWS.csv",
    "first_real_slice_operator_workspace_initializer/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_MANIFEST.json",
    "first_real_slice_operator_workspace_initializer/VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh",
    "first_real_slice_operator_workspace_initializer/READY_NOW_COMMANDS.sh",
    "source_v61gi/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "source_v61gt/v61gt_post_gs_ack_packet_to_replay_handoff_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61gu artifact: {rel}")
    if rel != "first_real_slice_external_workspace_file_rows.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61gu artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh", "READY_NOW_COMMANDS.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gu executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gi-ready", "source-v61gt-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gu default expected pass decision: {gate}")
for gate in [
    "external-work-root",
    "workspace-initialized",
    "final-witness-files",
    "real-return-execution",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gu default expected blocked decision: {gate}")

manifest = json.loads((package_dir / "FIRST_REAL_SLICE_OPERATOR_WORKSPACE_MANIFEST.json").read_text(encoding="utf-8"))
if manifest["summary"].get("workspace_initialized") != 0:
    raise SystemExit("v61gu default package must not initialize workspace")
if manifest["summary"].get("real_external_review_return_rows") != 0:
    raise SystemExit("v61gu default package must not count review evidence")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gu sha256 mismatch: {rel}")

print("v61gu default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="initialized_workspace" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

"$TMP_WORK_ROOT/VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh" >/dev/null

python3 - "$TMP_WORK_ROOT" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/initialized_workspace" <<'PY'
import csv
import os
import sys
from pathlib import Path

work_root = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
run_dir = Path(sys.argv[4])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_outside_repo": "1",
    "workspace_initialize_requested": "1",
    "workspace_initialized": "1",
    "template_witness_file_rows": "7",
    "final_witness_file_rows": "7",
    "final_witness_ready_rows": "0",
    "final_witness_accepted_as_real_evidence_rows": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_command_rows": "3",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gu initialized {field}: expected {value}, got {summary.get(field)}")

required_paths = [
    "FIRST_REAL_SLICE_OPERATOR_STEPS.md",
    "FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh",
    "VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh",
    "final_content_witness",
    "content_witness_templates",
    "minimal_slice",
    "operator_roots/operator_input_root",
    "operator_roots/output_root",
]
for rel in required_paths:
    path = work_root / rel
    if not path.exists():
        raise SystemExit(f"missing initialized workspace path: {rel}")

for rel in [
    "FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh",
    "VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh",
]:
    if not os.access(work_root / rel, os.X_OK):
        raise SystemExit(f"workspace executable missing: {rel}")

witnesses = [
    "review_comment.txt",
    "adjudication_reason.txt",
    "credential_statement.txt",
    "conflict_statement.txt",
    "answer_text.txt",
    "run_transcript.txt",
    "source_file.txt",
]
for name in witnesses:
    if not (work_root / "content_witness_templates" / f"{name}.template").is_file():
        raise SystemExit(f"missing witness template: {name}")
    if (work_root / "final_content_witness" / name).exists():
        raise SystemExit(f"initializer must not create final witness file: {name}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["external-work-root", "workspace-initialized"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gu initialized expected pass decision: {gate}")
for gate in ["final-witness-files", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gu initialized expected blocked decision: {gate}")

workspace_rows = read_csv(run_dir / "first_real_slice_external_workspace_file_rows.csv")
if len(workspace_rows) < 11:
    raise SystemExit("v61gu initialized expected workspace file rows")
if any(row["payload_like"] != "0" for row in workspace_rows):
    raise SystemExit("v61gu workspace must not include payload-like files")

print("v61gu initialized workspace smoke passed")
PY

V61GU_RUN_ID="workspace_001" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
