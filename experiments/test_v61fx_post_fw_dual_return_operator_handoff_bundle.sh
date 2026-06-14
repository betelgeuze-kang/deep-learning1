#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fx_post_fw_dual_return_operator_handoff_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/handoff_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
HANDOFF_DIR="$RUN_DIR/dual_return_operator_handoff_bundle"

V61FW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fw_post_fv_dual_return_replay_entrypoint_receipt.sh" >/dev/null

V61FX_REUSE_EXISTING="${V61FX_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fx_post_fw_dual_return_operator_handoff_bundle.sh" >/dev/null

"$HANDOFF_DIR/VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh" >/dev/null
"$HANDOFF_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$HANDOFF_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
handoff_dir = Path(sys.argv[4])


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
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": "1",
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_ready": "1",
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": "1",
    "v61fu_post_ft_external_return_closure_frontier_ready": "1",
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "root_contract_rows": "2",
    "v53_required_artifact_rows": "81",
    "v61_required_artifact_rows": "10",
    "dual_required_artifact_rows": "91",
    "open_delta_rows": "14",
    "missing_external_return_artifacts": "91",
    "receipt_ready_command_rows": "2",
    "receipt_successful_ready_command_rows": "2",
    "receipt_guard_probe_rows": "2",
    "receipt_passed_guard_probe_rows": "2",
    "handoff_stage_rows": "8",
    "ready_handoff_stage_rows": "5",
    "blocked_handoff_stage_rows": "3",
    "handoff_action_rows": "8",
    "ready_handoff_action_rows": "4",
    "blocked_handoff_action_rows": "4",
    "handoff_source_rows": "15",
    "operator_handoff_bundle_file_rows": "10",
    "metadata_only_operator_handoff_bundle_file_rows": "10",
    "payload_like_operator_handoff_bundle_file_rows": "0",
    "real_replay_command_executed": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fx {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_return_operator_handoff_root_contract_rows.csv",
    "dual_return_operator_handoff_stage_rows.csv",
    "dual_return_operator_handoff_action_rows.csv",
    "dual_return_operator_handoff_source_rows.csv",
    "dual_return_operator_handoff_package_file_rows.csv",
    "V61FX_POST_FW_DUAL_RETURN_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_manifest.json",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_decision.csv",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_ROOT_CONTRACT_ROWS.csv",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_OPERATOR_HANDOFF_STAGE_ROWS.csv",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_OPERATOR_HANDOFF_ACTION_ROWS.csv",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_OPERATOR_HANDOFF_SOURCE_ROWS.csv",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "dual_return_operator_handoff_bundle/VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh",
    "dual_return_operator_handoff_bundle/READY_NOW_COMMANDS.sh",
    "dual_return_operator_handoff_bundle/DUAL_RETURN_OPERATOR_HANDOFF.md",
    "source_v61fc/v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "source_v61fc/dual_external_return_required_artifact_rows.csv",
    "source_v61fd/v61fd_post_fc_real_return_closure_delta_ledger_summary.csv",
    "source_v61fd/post_fc_real_return_closure_delta_rows.csv",
    "source_v61fu/v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "source_v61fu/external_return_closure_frontier_requirement_rows.csv",
    "source_v61fv/v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "source_v61fv/dual_return_replay_entrypoint_command_rows.csv",
    "source_v61fv/dual_return_replay_required_env_rows.csv",
    "source_v61fv/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "source_v61fv/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "source_v61fw/v61fw_post_fv_dual_return_replay_entrypoint_receipt_summary.csv",
    "source_v61fw/dual_return_replay_entrypoint_receipt_execution_rows.csv",
    "source_v61fw/dual_return_replay_entrypoint_guard_probe_rows.csv",
    "source_v61fw/dual_return_replay_entrypoint_receipt_stage_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fx artifact: {rel}")

for rel in [
    "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(handoff_dir / rel, os.X_OK):
        raise SystemExit(f"v61fx handoff file must be executable: {rel}")

handoff_run_script = (handoff_dir / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh").read_text(encoding="utf-8")
source_run_script = (run_dir / "source_v61fv" / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh").read_text(encoding="utf-8")
expected_root = str(run_dir.parents[2])
for label, script_text in [("handoff", handoff_run_script), ("source", source_run_script)]:
    if expected_root not in script_text:
        raise SystemExit(f"v61fx {label} replay script must pin the real repository root")
    if 'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.."' in script_text:
        raise SystemExit(f"v61fx {label} replay script must not infer repo root from the results directory")

contracts = read_csv(run_dir / "dual_return_operator_handoff_root_contract_rows.csv")
if len(contracts) != 2:
    raise SystemExit("v61fx expected two root contract rows")
contracts_by_id = {row["root_id"]: row for row in contracts}
if contracts_by_id["v53-external-return-root"]["required_artifact_rows"] != "81":
    raise SystemExit("v61fx v53 root must require 81 artifacts")
if contracts_by_id["v53-external-return-root"]["required_provenance_value"] != "real-external-return-bundle":
    raise SystemExit("v61fx v53 root provenance mismatch")
if contracts_by_id["v61-generation-intake-return-root"]["required_artifact_rows"] != "10":
    raise SystemExit("v61fx v61 root must require 10 artifacts")
if contracts_by_id["v61-generation-intake-return-root"]["required_provenance_value"] != "real-generation-intake-return-bundle":
    raise SystemExit("v61fx v61 root provenance mismatch")
if any(row["supplied_by_default"] != "0" or row["accepted_by_default"] != "0" for row in contracts):
    raise SystemExit("v61fx root contracts must not be supplied or accepted by default")

stages = read_csv(run_dir / "dual_return_operator_handoff_stage_rows.csv")
if len(stages) != 8:
    raise SystemExit("v61fx expected eight stage rows")
if sum(row["status"] == "ready" for row in stages) != 5:
    raise SystemExit("v61fx expected five ready stages")
if sum(row["status"] == "blocked" for row in stages) != 3:
    raise SystemExit("v61fx expected three blocked stages")

actions = read_csv(run_dir / "dual_return_operator_handoff_action_rows.csv")
if len(actions) != 8:
    raise SystemExit("v61fx expected eight action rows")
if sum(row["ready_to_run_now"] == "1" for row in actions) != 4:
    raise SystemExit("v61fx expected four ready actions")
if sum(row["ready_to_run_now"] == "0" for row in actions) != 4:
    raise SystemExit("v61fx expected four blocked actions")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] and row["ready_to_run_now"] == "0" for row in actions):
    raise SystemExit("v61fx must keep real replay command blocked")

sources = read_csv(run_dir / "dual_return_operator_handoff_source_rows.csv")
if len(sources) != 15:
    raise SystemExit("v61fx expected 15 source rows")
if any(row["metadata_only"] != "1" for row in sources):
    raise SystemExit("v61fx source rows must be metadata-only")

package_rows = read_csv(run_dir / "dual_return_operator_handoff_package_file_rows.csv")
if len(package_rows) != 10:
    raise SystemExit("v61fx expected ten package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61fx package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["upstream-v61fw-receipt", "dual-root-contract", "operator-handoff-package", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fx expected pass decision: {gate}")
for gate in ["real-return-roots", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fx expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61fx_post_fw_dual_return_operator_handoff_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("root_contract_rows") != 2:
    raise SystemExit("v61fx manifest root contract mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fx manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fx manifest must keep repo payload zero")

handoff_manifest = json.loads((handoff_dir / "DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json").read_text(encoding="utf-8"))
if handoff_manifest.get("dual_required_artifact_rows") != 91:
    raise SystemExit("v61fx handoff manifest required artifact mismatch")
if handoff_manifest.get("real_replay_command_executed") != 0:
    raise SystemExit("v61fx handoff manifest must keep replay unexecuted")

boundary = (run_dir / "V61FX_POST_FW_DUAL_RETURN_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready=1",
    "root_contract_rows=2",
    "dual_required_artifact_rows=91",
    "open_delta_rows=14",
    "receipt_ready_command_rows=2",
    "receipt_successful_ready_command_rows=2",
    "receipt_guard_probe_rows=2",
    "receipt_passed_guard_probe_rows=2",
    "handoff_action_rows=8",
    "ready_handoff_action_rows=4",
    "blocked_handoff_action_rows=4",
    "real_replay_command_executed=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fx boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fx sha256 mismatch: {rel}")

print("v61fx post-fw dual return operator handoff bundle smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fx produced model/checkpoint payload-like files" >&2
  exit 1
fi
