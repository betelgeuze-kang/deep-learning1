#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fy_post_fx_operator_handoff_receipt"
RUN_DIR="$RESULTS_DIR/$PREFIX/receipt_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="$RUN_DIR/operator_handoff_receipt"

V61FX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fx_post_fw_dual_return_operator_handoff_bundle.sh" >/dev/null

V61FY_REUSE_EXISTING="${V61FY_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fy_post_fx_operator_handoff_receipt.sh" >/dev/null

"$RECEIPT_DIR/VERIFY_OPERATOR_HANDOFF_RECEIPT.sh" >/dev/null

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
    "v61fy_post_fx_operator_handoff_receipt_ready": "1",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": "1",
    "ready_handoff_action_rows": "4",
    "executed_ready_handoff_action_rows": "4",
    "successful_ready_handoff_action_rows": "4",
    "failed_ready_handoff_action_rows": "0",
    "blocked_handoff_action_rows": "4",
    "blocked_handoff_action_execution_attempt_rows": "0",
    "guard_probe_rows": "2",
    "passed_guard_probe_rows": "2",
    "failed_guard_probe_rows": "0",
    "receipt_file_rows": "12",
    "stage_rows": "7",
    "ready_stage_rows": "5",
    "blocked_stage_rows": "2",
    "root_pinned_replay_script_ready": "1",
    "real_replay_command_executed": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fy": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": "7",
    "metadata_only_receipt_package_file_rows": "7",
    "payload_like_receipt_package_file_rows": "0",
    "source_file_rows": "7",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fy {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "operator_handoff_receipt_execution_rows.csv",
    "operator_handoff_guard_probe_rows.csv",
    "operator_handoff_receipt_file_rows.csv",
    "operator_handoff_receipt_stage_rows.csv",
    "operator_handoff_receipt_package_file_rows.csv",
    "V61FY_POST_FX_OPERATOR_HANDOFF_RECEIPT_BOUNDARY.md",
    "v61fy_post_fx_operator_handoff_receipt_manifest.json",
    "v61fy_post_fx_operator_handoff_receipt_summary.csv",
    "v61fy_post_fx_operator_handoff_receipt_decision.csv",
    "operator_handoff_receipt/OPERATOR_HANDOFF_RECEIPT_MANIFEST.json",
    "operator_handoff_receipt/OPERATOR_HANDOFF_RECEIPT_EXECUTION_ROWS.csv",
    "operator_handoff_receipt/OPERATOR_HANDOFF_GUARD_PROBE_ROWS.csv",
    "operator_handoff_receipt/OPERATOR_HANDOFF_RECEIPT_FILE_ROWS.csv",
    "operator_handoff_receipt/OPERATOR_HANDOFF_RECEIPT_STAGE_ROWS.csv",
    "operator_handoff_receipt/OPERATOR_HANDOFF_RECEIPT.md",
    "operator_handoff_receipt/VERIFY_OPERATOR_HANDOFF_RECEIPT.sh",
    "source_v61fx/v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "source_v61fx/v61fx_post_fw_dual_return_operator_handoff_bundle_decision.csv",
    "source_v61fx/dual_return_operator_handoff_action_rows.csv",
    "source_v61fx/dual_return_operator_handoff_stage_rows.csv",
    "source_v61fx/dual_return_operator_handoff_root_contract_rows.csv",
    "source_v61fx/DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json",
    "source_v61fx/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fy artifact: {rel}")

if not os.access(receipt_dir / "VERIFY_OPERATOR_HANDOFF_RECEIPT.sh", os.X_OK):
    raise SystemExit("v61fy verifier must be executable")

executions = read_csv(run_dir / "operator_handoff_receipt_execution_rows.csv")
if len(executions) != 8:
    raise SystemExit("v61fy expected eight execution rows")
ready_rows = [row for row in executions if row["ready_to_run_now"] == "1"]
blocked_rows = [row for row in executions if row["ready_to_run_now"] == "0"]
if len(ready_rows) != 4 or len(blocked_rows) != 4:
    raise SystemExit("v61fy ready/blocked action count mismatch")
if any(row["executed"] != "1" or row["success"] != "1" or row["exit_code"] != "0" for row in ready_rows):
    raise SystemExit("v61fy ready action execution failed")
if any(row["executed"] != "0" or row["exit_code"] != "" for row in blocked_rows):
    raise SystemExit("v61fy blocked handoff actions must not execute")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] for row in blocked_rows):
    raise SystemExit("v61fy blocked rows must include the real replay command")

guard_rows = read_csv(run_dir / "operator_handoff_guard_probe_rows.csv")
if len(guard_rows) != 2:
    raise SystemExit("v61fy expected two guard probes")
if any(row["passed"] != "1" or row["executed"] != "1" for row in guard_rows):
    raise SystemExit("v61fy guard probes must pass")
stderr_texts = []
for row in guard_rows:
    stderr_path = run_dir / row["stderr_path"]
    if not stderr_path.is_file():
        raise SystemExit(f"v61fy missing guard stderr: {stderr_path}")
    stderr_texts.append(stderr_path.read_text(encoding="utf-8"))
if "V61FV_V53_RETURN_BUNDLE_DIR" not in stderr_texts[0]:
    raise SystemExit("v61fy no-env guard did not reject missing v53 env")
if "rejecting v53 return provenance" not in stderr_texts[1]:
    raise SystemExit("v61fy fixture guard did not reject provenance")

run_script_text = (run_dir / "source_v61fx" / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh").read_text(encoding="utf-8")
expected_root = str(run_dir.parents[2])
if expected_root not in run_script_text:
    raise SystemExit("v61fy replay script must pin the real repository root")
if 'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.."' in run_script_text:
    raise SystemExit("v61fy replay script must not infer repo root from the results directory")

receipt_files = read_csv(run_dir / "operator_handoff_receipt_file_rows.csv")
if len(receipt_files) != 12:
    raise SystemExit("v61fy expected twelve receipt stream files")
if any(not (run_dir / row["path"]).is_file() for row in receipt_files):
    raise SystemExit("v61fy receipt file row points to missing file")

stages = read_csv(run_dir / "operator_handoff_receipt_stage_rows.csv")
if len(stages) != 7:
    raise SystemExit("v61fy expected seven stage rows")
if sum(row["status"] == "ready" for row in stages) != 5:
    raise SystemExit("v61fy expected five ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61fy expected two blocked stages")

package_rows = read_csv(run_dir / "operator_handoff_receipt_package_file_rows.csv")
if len(package_rows) != 7:
    raise SystemExit("v61fy expected seven package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61fy package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fx-operator-handoff",
    "ready-handoff-actions",
    "blocked-action-nonexecution",
    "fail-closed-guard-probes",
    "root-pinned-replay-script",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fy expected pass decision: {gate}")
for gate in ["dual-external-return-real", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fy expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61fy_post_fx_operator_handoff_receipt_manifest.json").read_text(encoding="utf-8"))
if manifest.get("root_pinned_replay_script_ready") != 1:
    raise SystemExit("v61fy manifest must record root-pinned replay script readiness")
if manifest.get("blocked_handoff_action_execution_attempt_rows") != 0:
    raise SystemExit("v61fy manifest must keep blocked actions unexecuted")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fy manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fy manifest must keep repo payload zero")

receipt_manifest = json.loads((receipt_dir / "OPERATOR_HANDOFF_RECEIPT_MANIFEST.json").read_text(encoding="utf-8"))
if receipt_manifest.get("successful_ready_handoff_action_rows") != 4:
    raise SystemExit("v61fy receipt manifest ready action mismatch")
if receipt_manifest.get("passed_guard_probe_rows") != 2:
    raise SystemExit("v61fy receipt manifest guard probe mismatch")

boundary = (run_dir / "V61FY_POST_FX_OPERATOR_HANDOFF_RECEIPT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fy_post_fx_operator_handoff_receipt_ready=1",
    "ready_handoff_action_rows=4",
    "executed_ready_handoff_action_rows=4",
    "successful_ready_handoff_action_rows=4",
    "blocked_handoff_action_rows=4",
    "blocked_handoff_action_execution_attempt_rows=0",
    "guard_probe_rows=2",
    "passed_guard_probe_rows=2",
    "root_pinned_replay_script_ready=1",
    "real_replay_command_executed=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fy boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fy sha256 mismatch: {rel}")

print("v61fy post-fx operator handoff receipt smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fy produced model/checkpoint payload-like files" >&2
  exit 1
fi
