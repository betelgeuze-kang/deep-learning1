#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ha_post_gz_first_real_slice_source_witness_promotion_audit"
RUN_DIR="$RESULTS_DIR/$PREFIX/promotion_audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_source_witness_promotion_audit"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61ha first real slice workspace"

V61HA_REUSE_EXISTING="${V61HA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh" >/dev/null
"$PACKAGE_DIR/PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh" >/dev/null

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
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready": "1",
    "v61gz_post_gy_first_real_slice_source_witness_candidate_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "source_candidate_hash_matches": "1",
    "source_candidate_published": "0",
    "promotion_requested": "0",
    "promotion_admitted": "0",
    "promoted_by_v61ha": "0",
    "source_witness_ready_after_audit": "0",
    "ready_witness_rows_after_audit": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": "8",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "7",
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "source_file_rows": "8",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ha default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_source_witness_promotion_audit_source_rows.csv",
    "first_real_slice_source_witness_promotion_audit_post_gv_source_rows.csv",
    "first_real_slice_source_witness_promotion_audit_rows.csv",
    "first_real_slice_source_witness_promotion_audit_stage_rows.csv",
    "first_real_slice_source_witness_promotion_audit_command_rows.csv",
    "first_real_slice_source_witness_promotion_audit_package_file_rows.csv",
    "V61HA_POST_GZ_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_BOUNDARY.md",
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_manifest.json",
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_summary.csv",
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_decision.csv",
    "first_real_slice_source_witness_promotion_audit/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_MANIFEST.json",
    "first_real_slice_source_witness_promotion_audit/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_ROWS.csv",
    "first_real_slice_source_witness_promotion_audit/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_STAGE_ROWS.csv",
    "first_real_slice_source_witness_promotion_audit/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_COMMAND_ROWS.csv",
    "first_real_slice_source_witness_promotion_audit/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh",
    "first_real_slice_source_witness_promotion_audit/PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh",
    "source_v61gz/first_real_slice_source_witness_candidate_rows.csv",
    "source_v61gv_post_promotion/first_real_slice_workspace_witness_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61ha artifact: {rel}")

for rel in ["VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh", "PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61ha executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gz-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ha default expected pass decision: {gate}")
for gate in ["work-root", "source-candidate-helper", "promotion-request", "promotion-admitted", "source-witness-ready", "workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ha default expected blocked decision: {gate}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ha sha256 mismatch: {rel}")

print("v61ha default no-promotion smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
V61GU_RUN_ID="ha_workspace_source" \
V61GU_INITIALIZE_WORKSPACE=1 \
V61GU_WORK_ROOT="$TMP_WORK_ROOT" \
V61GU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

V61HA_RUN_ID="promoted_source_witness" \
V61HA_WORK_ROOT="$TMP_WORK_ROOT" \
V61HA_EXECUTE_PROMOTION=1 \
V61HA_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/$PREFIX/promoted_source_witness" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])
run_dir = Path(sys.argv[4])


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
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "source_candidate_hash_matches": "1",
    "source_candidate_published": "1",
    "promotion_requested": "1",
    "promotion_admitted": "1",
    "promoted_by_v61ha": "1",
    "source_witness_ready_after_audit": "1",
    "source_witness_sha_matches_after_audit": "1",
    "ready_witness_rows_after_audit": "1",
    "open_gap_rows_after_audit": "22",
    "content_witness_gap_rows_after_audit": "6",
    "env_value_gap_rows_after_audit": "16",
    "workspace_gap_preflight_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "6",
    "blocked_stage_rows": "2",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ha promoted {field}: expected {value}, got {summary.get(field)}")

target = work_root / "final_content_witness" / "source_file.txt"
if not target.is_file():
    raise SystemExit("v61ha expected promoted source_file.txt")
if sha256(target) != "sha256:f1fa7d324478b36ef2f18fe0e835cda7c02851021ccb63531feb3d21d8070052":
    raise SystemExit("v61ha promoted source witness hash mismatch")

audit_rows = read_csv(run_dir / "first_real_slice_source_witness_promotion_audit_rows.csv")
if audit_rows[0]["accepted_as_real_evidence"] != "0":
    raise SystemExit("v61ha source promotion must not count as real evidence")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "source-candidate-helper", "promotion-request", "promotion-admitted", "source-witness-ready"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ha promoted expected pass decision: {gate}")
for gate in ["workspace-gap-preflight", "real-return-execution", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ha promoted expected blocked decision: {gate}")

print("v61ha promoted source witness audit smoke passed")
PY

V61HA_RUN_ID="promotion_audit_001" V61HA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null
