#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ao_complete_source_actual_review_return_frontier_receipt"
RUN_DIR="$RESULTS_DIR/$PREFIX/receipt_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="$RUN_DIR/actual_review_return_frontier_receipt"

V53AO_REUSE_EXISTING="${V53AO_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ao_complete_source_actual_review_return_frontier_receipt.sh" >/dev/null

"$RECEIPT_DIR/VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIPT_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
receipt_dir = Path(sys.argv[4])


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
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready": "1",
    "v53an_complete_source_actual_review_return_frontier_ready": "1",
    "ready_frontier_action_rows": "2",
    "executed_ready_frontier_action_rows": "2",
    "successful_ready_frontier_action_rows": "2",
    "failed_ready_frontier_action_rows": "0",
    "blocked_frontier_action_rows": "4",
    "blocked_frontier_action_execution_attempt_rows": "0",
    "receipt_file_rows": "4",
    "stage_rows": "5",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "2",
    "operator_checklist_rows": "81",
    "missing_checklist_rows": "81",
    "preflight_pass_rows": "0",
    "preflight_rows": "81",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ao": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": "6",
    "metadata_only_receipt_package_file_rows": "6",
    "payload_like_receipt_package_file_rows": "0",
    "source_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ao {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "actual_review_return_frontier_receipt_execution_rows.csv",
    "actual_review_return_frontier_receipt_file_rows.csv",
    "actual_review_return_frontier_receipt_stage_rows.csv",
    "actual_review_return_frontier_receipt_package_file_rows.csv",
    "V53AO_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_BOUNDARY.md",
    "v53ao_complete_source_actual_review_return_frontier_receipt_manifest.json",
    "v53ao_complete_source_actual_review_return_frontier_receipt_summary.csv",
    "v53ao_complete_source_actual_review_return_frontier_receipt_decision.csv",
    "actual_review_return_frontier_receipt/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_MANIFEST.json",
    "actual_review_return_frontier_receipt/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_EXECUTION_ROWS.csv",
    "actual_review_return_frontier_receipt/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_FILE_ROWS.csv",
    "actual_review_return_frontier_receipt/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_STAGE_ROWS.csv",
    "actual_review_return_frontier_receipt/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.md",
    "actual_review_return_frontier_receipt/VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh",
    "source_v53an/v53an_complete_source_actual_review_return_frontier_summary.csv",
    "source_v53an/v53an_complete_source_actual_review_return_frontier_decision.csv",
    "source_v53an/actual_review_return_frontier_action_rows.csv",
    "source_v53an/actual_review_return_frontier_requirement_rows.csv",
    "source_v53an/actual_review_return_frontier_blocker_rows.csv",
    "source_v53an/ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ao artifact: {rel}")

if not os.access(receipt_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh", os.X_OK):
    raise SystemExit("v53ao verifier must be executable")

executions = read_csv(run_dir / "actual_review_return_frontier_receipt_execution_rows.csv")
if len(executions) != 6:
    raise SystemExit("v53ao expected six execution rows")
ready_rows = [row for row in executions if row["ready_to_run_now"] == "1"]
blocked_rows = [row for row in executions if row["ready_to_run_now"] == "0"]
if len(ready_rows) != 2 or len(blocked_rows) != 4:
    raise SystemExit("v53ao ready/blocked action count mismatch")
if any(row["executed"] != "1" or row["success"] != "1" or row["exit_code"] != "0" for row in ready_rows):
    raise SystemExit("v53ao ready action execution failed")
if any(row["executed"] != "0" or row["exit_code"] != "" for row in blocked_rows):
    raise SystemExit("v53ao blocked actions must not execute")
if not any("V53AM_RETURN_BUNDLE_DIR" in row["command"] for row in blocked_rows):
    raise SystemExit("v53ao blocked rows must include real v53am replay")

receipt_files = read_csv(run_dir / "actual_review_return_frontier_receipt_file_rows.csv")
if len(receipt_files) != 4:
    raise SystemExit("v53ao expected four receipt stream files")
if any(not (run_dir / row["path"]).is_file() for row in receipt_files):
    raise SystemExit("v53ao receipt file row points to missing file")

stages = read_csv(run_dir / "actual_review_return_frontier_receipt_stage_rows.csv")
if len(stages) != 5:
    raise SystemExit("v53ao expected five stage rows")
if sum(row["status"] == "ready" for row in stages) != 3:
    raise SystemExit("v53ao expected three ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v53ao expected two blocked stages")

package_rows = read_csv(run_dir / "actual_review_return_frontier_receipt_package_file_rows.csv")
if len(package_rows) != 6:
    raise SystemExit("v53ao expected six package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v53ao package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53an-frontier",
    "ready-frontier-actions",
    "blocked-action-nonexecution",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ao expected pass decision: {gate}")
for gate in ["review-return-real-root", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ao expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v53ao_complete_source_actual_review_return_frontier_receipt_manifest.json").read_text(encoding="utf-8"))
if manifest.get("blocked_frontier_action_execution_attempt_rows") != 0:
    raise SystemExit("v53ao manifest must keep blocked actions unexecuted")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ao manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53ao manifest must keep repo payload zero")

receipt_manifest = json.loads((receipt_dir / "ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_MANIFEST.json").read_text(encoding="utf-8"))
if receipt_manifest.get("successful_ready_frontier_action_rows") != 2:
    raise SystemExit("v53ao receipt manifest ready action mismatch")
if receipt_manifest.get("blocked_frontier_action_execution_attempt_rows") != 0:
    raise SystemExit("v53ao receipt manifest must keep blocked actions unexecuted")

boundary = (run_dir / "V53AO_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready=1",
    "ready_frontier_action_rows=2",
    "executed_ready_frontier_action_rows=2",
    "successful_ready_frontier_action_rows=2",
    "blocked_frontier_action_rows=4",
    "blocked_frontier_action_execution_attempt_rows=0",
    "preflight_pass_rows=0/81",
    "answer_review_accepted_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ao boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ao sha256 mismatch: {rel}")

print("v53ao complete-source actual review return frontier receipt smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v53ao produced model/checkpoint payload-like files" >&2
  exit 1
fi
