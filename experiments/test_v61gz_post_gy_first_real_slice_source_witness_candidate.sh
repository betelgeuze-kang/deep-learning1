#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gz_post_gy_first_real_slice_source_witness_candidate"
RUN_DIR="$RESULTS_DIR/$PREFIX/source_candidate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_source_witness_candidate"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61gz first real slice workspace"

V61GZ_REUSE_EXISTING="${V61GZ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gz_post_gy_first_real_slice_source_witness_candidate.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh" >/dev/null
"$PACKAGE_DIR/PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh" >/dev/null

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
    "v61gz_post_gy_first_real_slice_source_witness_candidate_ready": "1",
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready": "1",
    "source_candidate_hash_matches": "1",
    "source_candidate_published": "0",
    "published_source_candidate_file_rows": "0",
    "promoted_to_final_witness_by_v61gz": "0",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "8",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "6",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "source_file_rows": "6",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gz default {field}: expected {value}, got {summary.get(field)}")

candidate = package_dir / "source_file.txt.candidate"
if sha256(candidate) != "sha256:f1fa7d324478b36ef2f18fe0e835cda7c02851021ccb63531feb3d21d8070052":
    raise SystemExit("v61gz default candidate hash mismatch")

required_files = [
    "first_real_slice_source_witness_candidate_rows.csv",
    "first_real_slice_source_witness_summary_rows.csv",
    "first_real_slice_source_witness_published_file_rows.csv",
    "first_real_slice_source_witness_stage_rows.csv",
    "first_real_slice_source_witness_command_rows.csv",
    "first_real_slice_source_witness_package_file_rows.csv",
    "V61GZ_POST_GY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE_BOUNDARY.md",
    "v61gz_post_gy_first_real_slice_source_witness_candidate_manifest.json",
    "v61gz_post_gy_first_real_slice_source_witness_candidate_summary.csv",
    "v61gz_post_gy_first_real_slice_source_witness_candidate_decision.csv",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_MANIFEST.json",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE_ROWS.csv",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_SUMMARY_ROWS.csv",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_PUBLISHED_FILE_ROWS.csv",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_STAGE_ROWS.csv",
    "first_real_slice_source_witness_candidate/FIRST_REAL_SLICE_SOURCE_WITNESS_COMMAND_ROWS.csv",
    "first_real_slice_source_witness_candidate/source_file.txt.candidate",
    "first_real_slice_source_witness_candidate/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh",
    "first_real_slice_source_witness_candidate/PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh",
    "source_v53h/complete_source_content_snapshot_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gz artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh", "PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gz executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gy-ready", "source-snapshot-hash", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gz default expected pass decision: {gate}")
for gate in ["work-root", "publish-request", "source-candidate-published", "promotion", "workspace-gap-preflight", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gz default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gz sha256 mismatch: {rel}")

print("v61gz default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="gz_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61GZ_RUN_ID="published_source_candidate" \
V61GZ_WORK_ROOT="$TMP_WORK_ROOT" \
V61GZ_PUBLISH_CANDIDATE=1 \
V61GZ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gz_post_gy_first_real_slice_source_witness_candidate.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/$PREFIX/published_source_candidate" <<'PY'
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
    "source_candidate_published": "1",
    "published_source_candidate_file_rows": "5",
    "promoted_to_final_witness_by_v61gz": "0",
    "source_candidate_hash_matches": "1",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "5",
    "blocked_stage_rows": "3",
    "ready_command_rows": "3",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gz published {field}: expected {value}, got {summary.get(field)}")

candidate_dir = work_root / "source_witness_candidate"
required = [
    "source_file.txt.candidate",
    "SOURCE_FILE_WITNESS_CANDIDATE_MANIFEST.json",
    "VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh",
    "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh",
    "SOURCE_WITNESS_CANDIDATE_README.md",
]
for rel in required:
    path = candidate_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v61gz missing workspace candidate file: {rel}")
for rel in ["VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh", "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh"]:
    if not os.access(candidate_dir / rel, os.X_OK):
        raise SystemExit(f"v61gz expected executable candidate helper: {rel}")

subprocess.run([str(candidate_dir / "VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh")], cwd=str(candidate_dir), check=True, text=True, capture_output=True)
target = work_root / "final_content_witness" / "source_file.txt"
if target.exists():
    raise SystemExit("v61gz publish must not promote final witness by default")

blocked = subprocess.run([str(candidate_dir / "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh")], cwd=str(candidate_dir), text=True, capture_output=True)
if blocked.returncode == 0:
    raise SystemExit("v61gz promote helper must require explicit confirmation")
if target.exists():
    raise SystemExit("v61gz failed promotion must not create final witness")

ok = subprocess.run(
    [str(candidate_dir / "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh")],
    cwd=str(candidate_dir),
    text=True,
    capture_output=True,
    env={**os.environ, "V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION": "promote-selected-source-file-witness"},
)
if ok.returncode != 0:
    raise SystemExit(f"v61gz confirmed promotion failed: {ok.stderr}")
if not target.is_file() or target.stat().st_size == 0:
    raise SystemExit("v61gz confirmed promotion should create source_file.txt")

audit = subprocess.run(
    [str(work_root / "guarded_execution" / "RUN_GAP_READY_AUDIT_ONLY.sh")],
    cwd=str(work_root),
    text=True,
    capture_output=True,
)
if audit.returncode != 0:
    raise SystemExit(f"v61gz post-promotion audit command failed: {audit.stderr}")
latest = read_csv(Path("results/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv"))[0]
if latest.get("ready_witness_rows") != "1":
    raise SystemExit(f"v61gz expected one ready witness after source promotion, got {latest.get('ready_witness_rows')}")
if latest.get("workspace_gap_preflight_ready") != "0":
    raise SystemExit("v61gz source promotion alone must not open workspace preflight")

published = read_csv(run_dir / "first_real_slice_source_witness_published_file_rows.csv")
if len([row for row in published if row["published_path"]]) != 5:
    raise SystemExit("v61gz expected five published source candidate files")
if any(row["counts_as_evidence"] != "0" for row in published):
    raise SystemExit("v61gz published source candidate files must not count as evidence")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "publish-request", "source-candidate-published", "source-snapshot-hash"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gz published expected pass decision: {gate}")
for gate in ["promotion", "workspace-gap-preflight", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gz published expected blocked decision: {gate}")

print("v61gz source candidate publish smoke passed")
PY

V61GZ_RUN_ID="source_candidate_001" V61GZ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gz_post_gy_first_real_slice_source_witness_candidate.sh" >/dev/null
