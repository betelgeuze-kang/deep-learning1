#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fv_post_fu_dual_return_replay_entrypoint"
RUN_DIR="$RESULTS_DIR/$PREFIX/entrypoint_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ENTRYPOINT_DIR="$RUN_DIR/dual_return_replay_entrypoint"
FIXTURE_ROOT="$RUN_DIR/fixture_reject_roots"

V61FU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fu_post_ft_external_return_closure_frontier.sh" >/dev/null

V61FV_REUSE_EXISTING="${V61FV_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fv_post_fu_dual_return_replay_entrypoint.sh" >/dev/null

"$ENTRYPOINT_DIR/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh" >/dev/null
"$ENTRYPOINT_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if "$ENTRYPOINT_DIR/RUN_DUAL_RETURN_REPLAY_IF_READY.sh" >/tmp/v61fv_no_env.out 2>/tmp/v61fv_no_env.err; then
  echo "v61fv entrypoint unexpectedly admitted without env" >&2
  exit 1
fi
grep -q "V61FV_V53_RETURN_BUNDLE_DIR" /tmp/v61fv_no_env.err

mkdir -p "$FIXTURE_ROOT/v53" "$FIXTURE_ROOT/v61"
if V61FV_V53_RETURN_BUNDLE_DIR="$FIXTURE_ROOT/v53" \
  V61FV_V53_RETURN_PROVENANCE="fixture-v53-return" \
  V61FV_V61_RETURN_BUNDLE_DIR="$FIXTURE_ROOT/v61" \
  V61FV_V61_RETURN_PROVENANCE="fixture-v61-return" \
  "$ENTRYPOINT_DIR/RUN_DUAL_RETURN_REPLAY_IF_READY.sh" >/tmp/v61fv_fixture.out 2>/tmp/v61fv_fixture.err; then
  echo "v61fv entrypoint unexpectedly admitted fixture provenance" >&2
  exit 1
fi
grep -q "rejecting v53 return provenance" /tmp/v61fv_fixture.err

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ENTRYPOINT_DIR" <<'PY'
import csv
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
entrypoint_dir = Path(sys.argv[4])


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
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": "1",
    "v61fu_post_ft_external_return_closure_frontier_ready": "1",
    "entrypoint_admitted_by_default": "0",
    "required_env_rows": "4",
    "present_required_env_rows_by_default": "0",
    "stage_rows": "10",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "9",
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "frontier_requirement_rows": "15",
    "blocked_frontier_requirement_rows": "8",
    "open_frontier_delta_rows": "14",
    "missing_external_return_artifacts": "91",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "entrypoint_file_rows": "9",
    "metadata_only_entrypoint_file_rows": "9",
    "payload_like_entrypoint_file_rows": "0",
    "source_summary_file_rows": "2",
    "source_artifact_file_rows": "4",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fv {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_return_replay_required_env_rows.csv",
    "dual_return_replay_entrypoint_stage_rows.csv",
    "dual_return_replay_entrypoint_command_rows.csv",
    "dual_return_replay_entrypoint_file_rows.csv",
    "V61FV_POST_FU_DUAL_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md",
    "v61fv_post_fu_dual_return_replay_entrypoint_manifest.json",
    "v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "v61fv_post_fu_dual_return_replay_entrypoint_decision.csv",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "dual_return_replay_entrypoint/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "dual_return_replay_entrypoint/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh",
    "dual_return_replay_entrypoint/READY_NOW_COMMANDS.sh",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_STAGE_ROWS.csv",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_COMMAND_ROWS.csv",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_REQUIRED_ENV_ROWS.csv",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_ENTRYPOINT_MANIFEST.json",
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_ENTRYPOINT.md",
    "source_v61fu/v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "source_v61fu/external_return_closure_frontier_requirement_rows.csv",
    "source_v61fu/external_return_closure_frontier_delta_rows.csv",
    "source_v61fu/external_return_closure_frontier_action_rows.csv",
    "source_v61fu/EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fv artifact: {rel}")

for rel in [
    "dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "dual_return_replay_entrypoint/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "dual_return_replay_entrypoint/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh",
    "dual_return_replay_entrypoint/READY_NOW_COMMANDS.sh",
]:
    if not os.access(run_dir / rel, os.X_OK):
        raise SystemExit(f"v61fv executable bit missing: {rel}")

env_rows = read_csv(run_dir / "dual_return_replay_required_env_rows.csv")
if [row["env_var"] for row in env_rows] != [
    "V61FV_V53_RETURN_BUNDLE_DIR",
    "V61FV_V53_RETURN_PROVENANCE",
    "V61FV_V61_RETURN_BUNDLE_DIR",
    "V61FV_V61_RETURN_PROVENANCE",
]:
    raise SystemExit("v61fv required env rows mismatch")

stages = read_csv(run_dir / "dual_return_replay_entrypoint_stage_rows.csv")
if len(stages) != 10:
    raise SystemExit("v61fv expected ten stage rows")
if sum(row["status"] == "ready" for row in stages) != 1:
    raise SystemExit("v61fv expected one ready stage by default")
if sum(row["status"] == "blocked" for row in stages) != 9:
    raise SystemExit("v61fv expected nine blocked stages by default")

commands = read_csv(run_dir / "dual_return_replay_entrypoint_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0"]:
    raise SystemExit("v61fv command readiness mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61fu-frontier", "entrypoint-files", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fv expected pass decision: {gate}")
for gate in [
    "default-admission",
    "real-v53-return-root",
    "real-v61-return-root",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fv expected blocked decision: {gate}")

entrypoint_manifest = json.loads((entrypoint_dir / "DUAL_RETURN_REPLAY_ENTRYPOINT_MANIFEST.json").read_text(encoding="utf-8"))
if entrypoint_manifest.get("entrypoint_admitted_by_default") != 0:
    raise SystemExit("v61fv entrypoint manifest must fail closed by default")
if entrypoint_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fv manifest must keep actual generation blocked")
if entrypoint_manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fv manifest must keep repo payload zero")

ready_output = subprocess.check_output([str(entrypoint_dir / "READY_NOW_COMMANDS.sh")], text=True)
for snippet in [
    "entrypoint verification only",
    "VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh",
    "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
]:
    if snippet not in ready_output:
        raise SystemExit(f"v61fv ready output missing snippet: {snippet}")

boundary = (run_dir / "V61FV_POST_FU_DUAL_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fv_post_fu_dual_return_replay_entrypoint_ready=1",
    "entrypoint_admitted_by_default=0",
    "required_env_rows=4",
    "stage_rows=10",
    "ready_stage_rows=1",
    "blocked_stage_rows=9",
    "missing_external_return_artifacts=91",
    "dual_external_return_real_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fv boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fv sha256 mismatch: {rel}")

print("v61fv post-fu dual return replay entrypoint smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fv produced model/checkpoint payload-like files" >&2
  exit 1
fi
