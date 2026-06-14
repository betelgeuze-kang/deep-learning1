#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fu_post_ft_external_return_closure_frontier"
RUN_DIR="$RESULTS_DIR/$PREFIX/frontier_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FRONTIER_DIR="$RUN_DIR/external_return_closure_frontier"

V61FD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null

V61FU_REUSE_EXISTING="${V61FU_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fu_post_ft_external_return_closure_frontier.sh" >/dev/null

"$FRONTIER_DIR/VERIFY_FRONTIER.sh" >/dev/null
"$FRONTIER_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FRONTIER_DIR" <<'PY'
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
frontier_dir = Path(sys.argv[4])


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
    "v61fu_post_ft_external_return_closure_frontier_ready": "1",
    "v61ft_active_goal_completion_audit_ready": "1",
    "v61ez_active_goal_post_ey_status_refresh_ready": "1",
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "active_goal_complete": "0",
    "v61ft_requirement_rows": "20",
    "v61ft_pass_requirement_rows": "13",
    "v61ft_blocked_requirement_rows": "7",
    "v61ez_requirement_rows": "12",
    "v61ez_ready_requirement_rows": "6",
    "v61ez_blocked_requirement_rows": "6",
    "v61fd_delta_rows": "14",
    "v61fd_open_delta_rows": "14",
    "v61fd_closed_delta_rows": "0",
    "v53_required_artifact_rows": "81",
    "v61_required_artifact_rows": "10",
    "dual_required_artifact_rows": "91",
    "missing_external_return_artifacts": "91",
    "missing_human_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_reviewer_identity_rows": "21",
    "missing_conflict_disclosure_rows": "210",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "missing_generation_execution_admission_rows": "1000",
    "missing_final_acceptance_rows": "1000",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "frontier_requirement_rows": "15",
    "ready_frontier_requirement_rows": "7",
    "blocked_frontier_requirement_rows": "8",
    "frontier_delta_rows": "14",
    "open_frontier_delta_rows": "14",
    "closed_frontier_delta_rows": "0",
    "frontier_action_rows": "7",
    "ready_frontier_action_rows": "4",
    "blocked_frontier_action_rows": "3",
    "frontier_package_file_rows": "7",
    "metadata_only_frontier_package_file_rows": "7",
    "payload_like_frontier_package_file_rows": "0",
    "source_summary_file_rows": "8",
    "source_artifact_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fu {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_closure_frontier_requirement_rows.csv",
    "external_return_closure_frontier_delta_rows.csv",
    "external_return_closure_frontier_action_rows.csv",
    "external_return_closure_frontier_metric_rows.csv",
    "external_return_closure_frontier_file_rows.csv",
    "V61FU_POST_FT_EXTERNAL_RETURN_CLOSURE_FRONTIER_BOUNDARY.md",
    "v61fu_post_ft_external_return_closure_frontier_manifest.json",
    "v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "v61fu_post_ft_external_return_closure_frontier_decision.csv",
    "external_return_closure_frontier/EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json",
    "external_return_closure_frontier/FRONTIER_REQUIREMENT_ROWS.csv",
    "external_return_closure_frontier/FRONTIER_DELTA_ROWS.csv",
    "external_return_closure_frontier/FRONTIER_ACTION_ROWS.csv",
    "external_return_closure_frontier/EXTERNAL_RETURN_CLOSURE_FRONTIER.md",
    "external_return_closure_frontier/VERIFY_FRONTIER.sh",
    "external_return_closure_frontier/READY_NOW_COMMANDS.sh",
    "source_v61ft/v61ft_active_goal_completion_audit_summary.csv",
    "source_v61ez/v61ez_active_goal_post_ey_status_refresh_summary.csv",
    "source_v61fd/v61fd_post_fc_real_return_closure_delta_ledger_summary.csv",
    "source_v61fc/v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "source_v61fd/post_fc_real_return_closure_delta_rows.csv",
    "source_v61fc/dual_external_return_required_artifact_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fu artifact: {rel}")

if not os.access(frontier_dir / "VERIFY_FRONTIER.sh", os.X_OK):
    raise SystemExit("v61fu verifier must be executable")
if not os.access(frontier_dir / "READY_NOW_COMMANDS.sh", os.X_OK):
    raise SystemExit("v61fu ready-command printer must be executable")

requirements = read_csv(run_dir / "external_return_closure_frontier_requirement_rows.csv")
if len(requirements) != 15:
    raise SystemExit("v61fu expected 15 frontier requirement rows")
if sum(row["status"] == "ready" for row in requirements) != 7:
    raise SystemExit("v61fu expected seven ready frontier requirements")
if sum(row["status"] == "blocked" for row in requirements) != 8:
    raise SystemExit("v61fu expected eight blocked frontier requirements")
for requirement_id, missing in {
    "08-v53-external-return-artifacts": "81",
    "09-v61-generation-intake-artifacts": "10",
    "10-v53-human-review-rows": "7000",
    "11-v53-adjudication-rows": "1000",
    "12-v61-generation-result-artifacts": "5",
    "13-v61-generation-result-rows": "1000",
    "14-v61-actual-model-generation": "1",
    "15-v1-latency-quality-release": "3",
}.items():
    row = next(row for row in requirements if row["requirement_id"] == requirement_id)
    if row["status"] != "blocked" or row["missing_delta"] != missing:
        raise SystemExit(f"v61fu blocked requirement mismatch: {requirement_id}")

deltas = read_csv(run_dir / "external_return_closure_frontier_delta_rows.csv")
if len(deltas) != 14:
    raise SystemExit("v61fu expected 14 frontier delta rows")
if sum(row["status"] == "open" for row in deltas) != 14:
    raise SystemExit("v61fu all frontier deltas should be open")

actions = read_csv(run_dir / "external_return_closure_frontier_action_rows.csv")
if [row["ready_to_run_now"] for row in actions] != ["1", "1", "1", "1", "0", "0", "0"]:
    raise SystemExit("v61fu action readiness mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ft-active-goal-audit",
    "v61ez-post-ey-status",
    "v61fd-delta-ledger",
    "v61fc-dual-return-packet",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fu expected pass decision: {gate}")
for gate in [
    "dual-external-return-real",
    "v53-review-return",
    "v61-generation-result-return",
    "generation-acceptance-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fu expected blocked decision: {gate}")

frontier_manifest = json.loads((frontier_dir / "EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json").read_text(encoding="utf-8"))
if frontier_manifest.get("active_goal_complete") != 0:
    raise SystemExit("v61fu frontier manifest must keep active goal incomplete")
if frontier_manifest.get("missing_external_return_artifacts") != 91:
    raise SystemExit("v61fu frontier manifest missing artifact mismatch")
if frontier_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fu frontier manifest must keep generation blocked")
if frontier_manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fu frontier manifest must keep repo payload zero")

ready_output = subprocess.check_output([str(frontier_dir / "READY_NOW_COMMANDS.sh")], text=True)
for snippet in [
    "verification/frontier refresh only",
    "VERIFY_DUAL_RETURN_PACKET.sh",
    "VERIFY_DELTA_LEDGER.sh",
    "run_v61fu_post_ft_external_return_closure_frontier.sh",
]:
    if snippet not in ready_output:
        raise SystemExit(f"v61fu ready output missing snippet: {snippet}")

boundary = (run_dir / "V61FU_POST_FT_EXTERNAL_RETURN_CLOSURE_FRONTIER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fu_post_ft_external_return_closure_frontier_ready=1",
    "active_goal_complete=0",
    "frontier_requirement_rows=15",
    "ready_frontier_requirement_rows=7",
    "blocked_frontier_requirement_rows=8",
    "frontier_delta_rows=14",
    "open_frontier_delta_rows=14",
    "dual_required_artifact_rows=91",
    "missing_external_return_artifacts=91",
    "missing_human_review_rows=7000",
    "missing_generation_result_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fu boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fu sha256 mismatch: {rel}")

print("v61fu post-ft external return closure frontier smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fu produced model/checkpoint payload-like files" >&2
  exit 1
fi
