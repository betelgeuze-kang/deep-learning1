#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gb_post_ga_generation_unblock_runway_receipt"
RUN_DIR="$RESULTS_DIR/$PREFIX/receipt_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="$RUN_DIR/generation_unblock_runway_receipt"

V61GB_REUSE_EXISTING="${V61GB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gb_post_ga_generation_unblock_runway_receipt.sh" >/dev/null

"$RECEIPT_DIR/VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh" >/dev/null

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
    "v61gb_post_ga_generation_unblock_runway_receipt_ready": "1",
    "v61ga_post_fz_generation_unblock_runway_ready": "1",
    "ready_runway_command_rows": "2",
    "executed_ready_runway_command_rows": "2",
    "successful_ready_runway_command_rows": "2",
    "failed_ready_runway_command_rows": "0",
    "blocked_runway_command_rows": "3",
    "blocked_runway_command_execution_attempt_rows": "0",
    "receipt_file_rows": "4",
    "stage_rows": "5",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "2",
    "runway_requirement_rows": "18",
    "ready_runway_requirement_rows": "5",
    "blocked_runway_requirement_rows": "13",
    "minimum_batch_rows": "6",
    "blocked_minimum_batch_rows": "6",
    "missing_external_return_artifacts": "91",
    "missing_human_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": "6",
    "metadata_only_receipt_package_file_rows": "6",
    "payload_like_receipt_package_file_rows": "0",
    "source_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gb {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "generation_unblock_runway_receipt_execution_rows.csv",
    "generation_unblock_runway_receipt_file_rows.csv",
    "generation_unblock_runway_receipt_stage_rows.csv",
    "generation_unblock_runway_receipt_package_file_rows.csv",
    "generation_unblock_runway_receipt_source_rows.csv",
    "V61GB_POST_GA_GENERATION_UNBLOCK_RUNWAY_RECEIPT_BOUNDARY.md",
    "v61gb_post_ga_generation_unblock_runway_receipt_manifest.json",
    "v61gb_post_ga_generation_unblock_runway_receipt_summary.csv",
    "v61gb_post_ga_generation_unblock_runway_receipt_decision.csv",
    "generation_unblock_runway_receipt/GENERATION_UNBLOCK_RUNWAY_RECEIPT_MANIFEST.json",
    "generation_unblock_runway_receipt/GENERATION_UNBLOCK_RUNWAY_RECEIPT_EXECUTION_ROWS.csv",
    "generation_unblock_runway_receipt/GENERATION_UNBLOCK_RUNWAY_RECEIPT_FILE_ROWS.csv",
    "generation_unblock_runway_receipt/GENERATION_UNBLOCK_RUNWAY_RECEIPT_STAGE_ROWS.csv",
    "generation_unblock_runway_receipt/GENERATION_UNBLOCK_RUNWAY_RECEIPT.md",
    "generation_unblock_runway_receipt/VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh",
    "source_v61ga/v61ga_post_fz_generation_unblock_runway_summary.csv",
    "source_v61ga/v61ga_post_fz_generation_unblock_runway_decision.csv",
    "source_v61ga/generation_unblock_runway_replay_command_rows.csv",
    "source_v61ga/generation_unblock_runway_requirement_rows.csv",
    "source_v61ga/generation_unblock_runway_minimum_batch_rows.csv",
    "source_v61ga/GENERATION_UNBLOCK_RUNWAY_MANIFEST.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gb artifact: {rel}")

if not os.access(receipt_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh", os.X_OK):
    raise SystemExit("v61gb verifier must be executable")

executions = read_csv(run_dir / "generation_unblock_runway_receipt_execution_rows.csv")
if len(executions) != 5:
    raise SystemExit("v61gb expected five execution rows")
ready_rows = [row for row in executions if row["ready_to_run_now"] == "1"]
blocked_rows = [row for row in executions if row["ready_to_run_now"] == "0"]
if len(ready_rows) != 2 or len(blocked_rows) != 3:
    raise SystemExit("v61gb ready/blocked command count mismatch")
if any(row["executed"] != "1" or row["success"] != "1" or row["exit_code"] != "0" for row in ready_rows):
    raise SystemExit("v61gb ready command execution failed")
if any(row["executed"] != "0" or row["exit_code"] != "" for row in blocked_rows):
    raise SystemExit("v61gb blocked commands must not execute")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] for row in blocked_rows):
    raise SystemExit("v61gb blocked rows must include root-pinned replay")
if not any("V61FV_V53_RETURN_BUNDLE_DIR" in row["command"] for row in blocked_rows):
    raise SystemExit("v61gb blocked rows must include real root supply command")

receipt_files = read_csv(run_dir / "generation_unblock_runway_receipt_file_rows.csv")
if len(receipt_files) != 4:
    raise SystemExit("v61gb expected four receipt stream files")
if any(not (run_dir / row["path"]).is_file() for row in receipt_files):
    raise SystemExit("v61gb receipt file row points to missing file")

stages = read_csv(run_dir / "generation_unblock_runway_receipt_stage_rows.csv")
if len(stages) != 5:
    raise SystemExit("v61gb expected five stage rows")
if sum(row["status"] == "ready" for row in stages) != 3:
    raise SystemExit("v61gb expected three ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61gb expected two blocked stages")

package_rows = read_csv(run_dir / "generation_unblock_runway_receipt_package_file_rows.csv")
if len(package_rows) != 6:
    raise SystemExit("v61gb expected six package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61gb package rows must be metadata-only and non-payload")

sources = read_csv(run_dir / "generation_unblock_runway_receipt_source_rows.csv")
if len(sources) != 6:
    raise SystemExit("v61gb expected six source rows")
if any(row["metadata_only"] != "1" for row in sources):
    raise SystemExit("v61gb source rows must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61ga-runway", "ready-runway-commands", "blocked-command-nonexecution", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gb expected pass decision: {gate}")
for gate in ["dual-real-return-roots", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gb expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61gb_post_ga_generation_unblock_runway_receipt_manifest.json").read_text(encoding="utf-8"))
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61gb manifest must keep repo checkpoint payload zero")
if manifest.get("summary", {}).get("actual_model_generation_ready") != "0":
    raise SystemExit("v61gb manifest must keep actual generation blocked")

receipt_manifest = json.loads((receipt_dir / "GENERATION_UNBLOCK_RUNWAY_RECEIPT_MANIFEST.json").read_text(encoding="utf-8"))
if receipt_manifest.get("successful_ready_runway_command_rows") != 2:
    raise SystemExit("v61gb receipt manifest ready command mismatch")
if receipt_manifest.get("blocked_runway_command_execution_attempt_rows") != 0:
    raise SystemExit("v61gb receipt manifest must keep blocked commands unexecuted")

boundary = (run_dir / "V61GB_POST_GA_GENERATION_UNBLOCK_RUNWAY_RECEIPT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gb_post_ga_generation_unblock_runway_receipt_ready=1",
    "v61ga_post_fz_generation_unblock_runway_ready=1",
    "ready_runway_command_rows=2",
    "executed_ready_runway_command_rows=2",
    "successful_ready_runway_command_rows=2",
    "blocked_runway_command_rows=3",
    "blocked_runway_command_execution_attempt_rows=0",
    "receipt_file_rows=4",
    "runway_requirement_rows=18",
    "ready_runway_requirement_rows=5",
    "blocked_runway_requirement_rows=13",
    "minimum_batch_rows=6",
    "blocked_minimum_batch_rows=6",
    "missing_external_return_artifacts=91",
    "missing_human_review_rows=7000",
    "missing_adjudication_rows=1000",
    "missing_generation_result_artifacts=5",
    "missing_generation_result_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gb boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gb sha256 mismatch: {rel}")

if any(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"} for path in run_dir.rglob("*") if path.is_file()):
    raise SystemExit("v61gb must not emit payload-like files")

print("v61gb post-ga generation unblock runway receipt smoke passed")
PY
