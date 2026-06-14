#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fw_post_fv_dual_return_replay_entrypoint_receipt"
RUN_DIR="$RESULTS_DIR/$PREFIX/receipt_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="$RUN_DIR/dual_return_replay_entrypoint_receipt"

V61FV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fv_post_fu_dual_return_replay_entrypoint.sh" >/dev/null

V61FW_REUSE_EXISTING="${V61FW_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fw_post_fv_dual_return_replay_entrypoint_receipt.sh" >/dev/null

"$RECEIPT_DIR/VERIFY_ENTRYPOINT_RECEIPTS.sh" >/dev/null

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
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_ready": "1",
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": "1",
    "ready_command_rows": "2",
    "executed_ready_command_rows": "2",
    "successful_ready_command_rows": "2",
    "failed_ready_command_rows": "0",
    "blocked_command_rows": "1",
    "blocked_command_execution_attempt_rows": "0",
    "guard_probe_rows": "2",
    "passed_guard_probe_rows": "2",
    "failed_guard_probe_rows": "0",
    "receipt_file_rows": "8",
    "stage_rows": "6",
    "ready_stage_rows": "4",
    "blocked_stage_rows": "2",
    "real_replay_command_executed": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": "7",
    "metadata_only_receipt_package_file_rows": "7",
    "payload_like_receipt_package_file_rows": "0",
    "source_summary_file_rows": "2",
    "source_artifact_file_rows": "4",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fw {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_return_replay_entrypoint_receipt_execution_rows.csv",
    "dual_return_replay_entrypoint_guard_probe_rows.csv",
    "dual_return_replay_entrypoint_receipt_file_rows.csv",
    "dual_return_replay_entrypoint_receipt_stage_rows.csv",
    "dual_return_replay_entrypoint_receipt_package_file_rows.csv",
    "V61FW_POST_FV_DUAL_RETURN_REPLAY_ENTRYPOINT_RECEIPT_BOUNDARY.md",
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_manifest.json",
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_summary.csv",
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_decision.csv",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_RECEIPT_MANIFEST.json",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_RECEIPT_EXECUTION_ROWS.csv",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_GUARD_PROBE_ROWS.csv",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_RECEIPT_FILE_ROWS.csv",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_RECEIPT_STAGE_ROWS.csv",
    "dual_return_replay_entrypoint_receipt/ENTRYPOINT_RECEIPT.md",
    "dual_return_replay_entrypoint_receipt/VERIFY_ENTRYPOINT_RECEIPTS.sh",
    "source_v61fv/v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "source_v61fv/dual_return_replay_entrypoint_command_rows.csv",
    "source_v61fv/dual_return_replay_entrypoint_stage_rows.csv",
    "source_v61fv/dual_return_replay_required_env_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fw artifact: {rel}")

if not os.access(receipt_dir / "VERIFY_ENTRYPOINT_RECEIPTS.sh", os.X_OK):
    raise SystemExit("v61fw verifier must be executable")

executions = read_csv(run_dir / "dual_return_replay_entrypoint_receipt_execution_rows.csv")
if len(executions) != 3:
    raise SystemExit("v61fw expected three execution rows")
ready_rows = [row for row in executions if row["ready_to_run_now"] == "1"]
blocked_rows = [row for row in executions if row["ready_to_run_now"] == "0"]
if len(ready_rows) != 2 or len(blocked_rows) != 1:
    raise SystemExit("v61fw ready/blocked command count mismatch")
if any(row["executed"] != "1" or row["success"] != "1" or row["exit_code"] != "0" for row in ready_rows):
    raise SystemExit("v61fw ready command execution failed")
if blocked_rows[0]["executed"] != "0" or blocked_rows[0]["exit_code"] != "":
    raise SystemExit("v61fw blocked real replay command must not execute")

guard_rows = read_csv(run_dir / "dual_return_replay_entrypoint_guard_probe_rows.csv")
if len(guard_rows) != 2:
    raise SystemExit("v61fw expected two guard probes")
if any(row["passed"] != "1" or row["executed"] != "1" for row in guard_rows):
    raise SystemExit("v61fw guard probes must pass")
stderr_texts = []
for row in guard_rows:
    stderr_path = run_dir / row["stderr_path"]
    if not stderr_path.is_file():
        raise SystemExit(f"v61fw missing guard stderr: {stderr_path}")
    stderr_texts.append(stderr_path.read_text(encoding="utf-8"))
if "V61FV_V53_RETURN_BUNDLE_DIR" not in stderr_texts[0]:
    raise SystemExit("v61fw no-env guard did not reject missing v53 env")
if "rejecting v53 return provenance" not in stderr_texts[1]:
    raise SystemExit("v61fw fixture guard did not reject provenance")

receipt_files = read_csv(run_dir / "dual_return_replay_entrypoint_receipt_file_rows.csv")
if len(receipt_files) != 8:
    raise SystemExit("v61fw expected eight receipt stream files")
if any(not (run_dir / row["path"]).is_file() for row in receipt_files):
    raise SystemExit("v61fw receipt file row points to missing file")

stages = read_csv(run_dir / "dual_return_replay_entrypoint_receipt_stage_rows.csv")
if len(stages) != 6:
    raise SystemExit("v61fw expected six stage rows")
if sum(row["status"] == "ready" for row in stages) != 4:
    raise SystemExit("v61fw expected four ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61fw expected two blocked stages")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fv-entrypoint",
    "ready-command-execution",
    "blocked-command-nonexecution",
    "fail-closed-guard-probes",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fw expected pass decision: {gate}")
for gate in ["dual-external-return-real", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fw expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61fw_post_fv_dual_return_replay_entrypoint_receipt_manifest.json").read_text(encoding="utf-8"))
if manifest.get("blocked_command_execution_attempt_rows") != 0:
    raise SystemExit("v61fw manifest must keep blocked command unexecuted")
if manifest.get("passed_guard_probe_rows") != 2:
    raise SystemExit("v61fw manifest guard probe mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fw manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fw manifest must keep repo payload zero")

boundary = (run_dir / "V61FW_POST_FV_DUAL_RETURN_REPLAY_ENTRYPOINT_RECEIPT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_ready=1",
    "ready_command_rows=2",
    "executed_ready_command_rows=2",
    "successful_ready_command_rows=2",
    "blocked_command_rows=1",
    "blocked_command_execution_attempt_rows=0",
    "guard_probe_rows=2",
    "passed_guard_probe_rows=2",
    "real_replay_command_executed=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fw boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fw sha256 mismatch: {rel}")

print("v61fw post-fv dual return replay entrypoint receipt smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fw produced model/checkpoint payload-like files" >&2
  exit 1
fi
