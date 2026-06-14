#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fs_post_fr_ready_command_execution_receipt"
RUN_DIR="$RESULTS_DIR/$PREFIX/receipt_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="$RUN_DIR/post_fr_ready_command_execution_receipt"

V61FR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fr_post_fq_v1_ready_command_handoff.sh" >/dev/null

V61FS_REUSE_EXISTING="${V61FS_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fs_post_fr_ready_command_execution_receipt.sh" >/dev/null

"$RECEIPT_DIR/VERIFY_READY_COMMAND_RECEIPTS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
receipt_dir = run_dir / "post_fr_ready_command_execution_receipt"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61fs_post_fr_ready_command_execution_receipt_ready": "1",
    "v61fr_post_fq_v1_ready_command_handoff_ready": "1",
    "ready_command_rows": "4",
    "executed_ready_command_rows": "4",
    "successful_ready_command_rows": "4",
    "failed_ready_command_rows": "0",
    "blocked_command_rows": "4",
    "blocked_command_execution_attempt_rows": "0",
    "receipt_file_rows": "8",
    "stage_rows": "6",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "3",
    "required_external_input_rows": "5",
    "present_external_input_rows": "0",
    "missing_external_input_rows": "5",
    "send_bundle_ready": "1",
    "return_bundle_preflight_pass": "0",
    "external_review_return_ready": "0",
    "v1_0_comparison_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": "6",
    "metadata_only_receipt_package_file_rows": "6",
    "payload_like_receipt_package_file_rows": "0",
    "source_summary_file_rows": "4",
    "source_artifact_file_rows": "4",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fs {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fr_ready_command_execution_rows.csv",
    "post_fr_ready_command_execution_receipt_file_rows.csv",
    "post_fr_ready_command_execution_stage_rows.csv",
    "post_fr_ready_command_execution_package_file_rows.csv",
    "V61FS_POST_FR_READY_COMMAND_EXECUTION_RECEIPT_BOUNDARY.md",
    "v61fs_post_fr_ready_command_execution_receipt_manifest.json",
    "v61fs_post_fr_ready_command_execution_receipt_summary.csv",
    "v61fs_post_fr_ready_command_execution_receipt_decision.csv",
    "post_fr_ready_command_execution_receipt/READY_COMMAND_EXECUTION_RECEIPT_MANIFEST.json",
    "post_fr_ready_command_execution_receipt/READY_COMMAND_EXECUTION_ROWS.csv",
    "post_fr_ready_command_execution_receipt/READY_COMMAND_RECEIPT_FILE_ROWS.csv",
    "post_fr_ready_command_execution_receipt/READY_COMMAND_EXECUTION_STAGE_ROWS.csv",
    "post_fr_ready_command_execution_receipt/VERIFY_READY_COMMAND_RECEIPTS.sh",
    "post_fr_ready_command_execution_receipt/READY_COMMAND_EXECUTION_RECEIPT.md",
    "source_summaries/v61fr_post_fq_v1_ready_command_handoff_summary.csv",
    "source_summaries/v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "source_summaries/v53ah_complete_source_external_review_send_bundle_summary.csv",
    "source_artifacts/v61fr_command_rows.csv",
    "source_artifacts/v61fr_stage_rows.csv",
    "source_artifacts/v61fr_external_input_rows.csv",
    "source_artifacts/v61fr_handoff_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fs artifact: {rel}")

if not os.access(receipt_dir / "VERIFY_READY_COMMAND_RECEIPTS.sh", os.X_OK):
    raise SystemExit("v61fs verifier must be executable")

execution_rows = read_csv(run_dir / "post_fr_ready_command_execution_rows.csv")
if len(execution_rows) != 8:
    raise SystemExit("v61fs expected eight execution rows")
ready_rows = [row for row in execution_rows if row["ready_to_run_now"] == "1"]
blocked_rows = [row for row in execution_rows if row["ready_to_run_now"] == "0"]
if len(ready_rows) != 4 or len(blocked_rows) != 4:
    raise SystemExit("v61fs ready/blocked command row mismatch")
if any(row["executed"] != "1" or row["success"] != "1" or row["exit_code"] != "0" for row in ready_rows):
    raise SystemExit("v61fs all ready commands must execute successfully")
if any(row["executed"] != "0" or row["exit_code"] != "" for row in blocked_rows):
    raise SystemExit("v61fs blocked commands must not execute")
for row in ready_rows:
    for key in ["stdout_path", "stderr_path"]:
        path = run_dir / row[key]
        if not path.is_file():
            raise SystemExit(f"v61fs missing receipt stream: {path}")

receipt_files = read_csv(run_dir / "post_fr_ready_command_execution_receipt_file_rows.csv")
if len(receipt_files) != 8:
    raise SystemExit("v61fs expected eight receipt file rows")
if any(not (run_dir / row["path"]).is_file() for row in receipt_files):
    raise SystemExit("v61fs receipt file row points to missing file")

stages = read_csv(run_dir / "post_fr_ready_command_execution_stage_rows.csv")
if len(stages) != 6:
    raise SystemExit("v61fs expected six stage rows")
if sum(row["status"] == "ready" for row in stages) != 3:
    raise SystemExit("v61fs expected three ready stages")
if sum(row["status"] == "blocked" for row in stages) != 3:
    raise SystemExit("v61fs expected three blocked stages")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fr-handoff",
    "ready-command-execution",
    "receipt-files",
    "blocked-command-nonexecution",
    "zero-repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fs decision should pass: {gate}")
for gate in ["external-inputs", "v1-comparison", "actual-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fs decision should be blocked: {gate}")

ready_output = (run_dir / "command_receipts/04-print-ready-now-commands.stdout.txt").read_text(encoding="utf-8")
for snippet in [
    "Ready local verification commands",
    "Blocked until external inputs exist",
    "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle",
    "V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return",
]:
    if snippet not in ready_output:
        raise SystemExit(f"v61fs ready output missing snippet: {snippet}")

boundary = (run_dir / "V61FS_POST_FR_READY_COMMAND_EXECUTION_RECEIPT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fs_post_fr_ready_command_execution_receipt_ready=1",
    "ready_command_rows=4",
    "executed_ready_command_rows=4",
    "successful_ready_command_rows=4",
    "failed_ready_command_rows=0",
    "blocked_command_rows=4",
    "blocked_command_execution_attempt_rows=0",
    "receipt_file_rows=8",
    "missing_external_input_rows=5",
    "return_bundle_preflight_pass=0",
    "external_review_return_ready=0",
    "v1_0_comparison_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fs boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fs_post_fr_ready_command_execution_receipt_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fs_post_fr_ready_command_execution_receipt_ready") != 1:
    raise SystemExit("v61fs manifest readiness mismatch")
if manifest.get("successful_ready_command_rows") != 4:
    raise SystemExit("v61fs manifest command success mismatch")
if manifest.get("blocked_command_execution_attempt_rows") != 0:
    raise SystemExit("v61fs manifest must not execute blocked commands")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fs manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fs manifest must keep repo checkpoint payload zero")

print("v61fs post-v61fr ready command execution receipt test passed")
PY
