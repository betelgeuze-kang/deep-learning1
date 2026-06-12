#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bp_ubuntu1_payload_execution_launch_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v61bp_ubuntu1_payload_execution_launch_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bp_ubuntu1_payload_execution_launch_bundle_decision.csv"

V61BP_REUSE_EXISTING="${V61BP_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bp_ubuntu1_payload_execution_launch_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": "1",
    "v61bo_ubuntu1_payload_execution_readiness_gate_ready": "1",
    "selected_activation_target_id": "ubuntu-1-write-witness-admitted",
    "selected_payload_execution_target_id": "ubuntu-1-payload-readiness-pending-approval",
    "selected_launch_bundle_id": "ubuntu-1-payload-launch-bundle-dry-run-default",
    "selected_target_path": ubuntu1_target,
    "selected_backend_id": "curl-resume",
    "selected_backend_ready": "1",
    "payload_execution_preflight_ready": "1",
    "payload_execution_readiness_rows": "59",
    "launch_command_rows": "59",
    "priority_chunk_launch_rows": "3",
    "operator_bundle_file_rows": "7",
    "script_probe_rows": "4",
    "script_bash_syntax_pass_rows": "4",
    "script_executable_rows": "4",
    "dry_run_probe_rows": "1",
    "dry_run_guard_ready": "1",
    "approval_required_rows": "2",
    "approval_supplied_rows": "0",
    "payload_execution_approval_ready": "0",
    "payload_execution_launch_ready": "0",
    "payload_execution_ready_rows": "0",
    "payload_execution_blocked_rows": "59",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": "281241493344",
    "p0_remote_moe_sampled_rows": "15",
    "p0_embedding_sampled_rows": "1",
    "p2_checkpoint_backfill_rows": "43",
    "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bp {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_payload_execution_launch_command_rows.csv",
    "ubuntu1_payload_execution_chunk_launch_rows.csv",
    "ubuntu1_payload_execution_approval_rows.csv",
    "ubuntu1_payload_execution_script_probe_rows.csv",
    "ubuntu1_payload_execution_dry_run_probe_rows.csv",
    "ubuntu1_payload_execution_operator_bundle_file_rows.csv",
    "ubuntu1_payload_execution_launch_requirement_rows.csv",
    "ubuntu1_payload_execution_launch_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md",
    "v61bp_ubuntu1_payload_execution_launch_bundle_manifest.json",
    "sha256_manifest.csv",
    "operator_bundle/README.md",
    "operator_bundle/operator_env.template",
    "operator_bundle/ubuntu1_payload_execution_readiness_rows.csv",
    "operator_bundle/download_priority_chunks.sh",
    "operator_bundle/verify_materialization_after_download.sh",
    "operator_bundle/run_full_page_hash_after_download.sh",
    "operator_bundle/recheck_generation_after_download.sh",
    "source_v61bo/ubuntu1_payload_execution_readiness_rows.csv",
    "source_v61bo/ubuntu1_payload_execution_chunk_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bp artifact: {rel}")

launch_rows = read_csv(run_dir / "ubuntu1_payload_execution_launch_command_rows.csv")
chunk_rows = read_csv(run_dir / "ubuntu1_payload_execution_chunk_launch_rows.csv")
approval_rows = {row["approval_requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_payload_execution_approval_rows.csv")}
script_rows = read_csv(run_dir / "ubuntu1_payload_execution_script_probe_rows.csv")
dry_run_rows = read_csv(run_dir / "ubuntu1_payload_execution_dry_run_probe_rows.csv")
bundle_file_rows = read_csv(run_dir / "ubuntu1_payload_execution_operator_bundle_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_payload_execution_launch_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_payload_execution_launch_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(launch_rows) != 59 or len(chunk_rows) != 3:
    raise SystemExit("v61bp launch row count mismatch")
if len(script_rows) != 4 or len(bundle_file_rows) != 7 or len(dry_run_rows) != 1:
    raise SystemExit("v61bp bundle/probe row count mismatch")
if any(row["payload_execution_preflight_ready"] != "1" for row in launch_rows):
    raise SystemExit("v61bp launch rows must be preflight ready")
if any(row["payload_execution_launch_ready"] != "0" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp must keep payload launch blocked")
if any(row["download_execution_ready"] != "0" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp must keep download execution blocked")
if any(row["dry_run_default"] != "1" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp launch rows must default to dry-run")
if any(row["requires_execute_flag"] != "1" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp launch rows must require execute flag")
if any(row["requires_approval_phrase"] != "1" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp launch rows must require approval phrase")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bp"] != "0" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in launch_rows + chunk_rows):
    raise SystemExit("v61bp must not commit checkpoint payload bytes")
if any(not row["target_path"].startswith(ubuntu1_target) for row in launch_rows):
    raise SystemExit("v61bp target paths must remain under ubuntu-1")
if any("/tmp/" in row["target_path"] for row in launch_rows):
    raise SystemExit("v61bp must not contain stale /tmp target paths")

chunk_counts = {row["priority_class"]: row["row_count"] for row in chunk_rows}
if chunk_counts != {
    "p0_remote_moe_sampled": "15",
    "p0_embedding_sampled": "1",
    "p2_checkpoint_backfill": "43",
}:
    raise SystemExit(f"v61bp chunk counts mismatch: {chunk_counts}")

if approval_rows["execute-flag"]["status"] != "blocked":
    raise SystemExit("v61bp execute flag approval should be blocked by default")
if approval_rows["approval-phrase"]["status"] != "blocked":
    raise SystemExit("v61bp approval phrase should be blocked by default")
if dry_run_rows[0]["payload_execution_blocked"] != "1" or dry_run_rows[0]["dry_run_guard_seen"] != "1":
    raise SystemExit("v61bp dry-run probe should block payload execution")
if dry_run_rows[0]["planned_payload_rows_processed"] != "1":
    raise SystemExit("v61bp dry-run probe should process one planned row")
if any(row["bash_syntax_pass"] != "1" or row["executable_bit_set"] != "1" for row in script_rows):
    raise SystemExit("v61bp scripts must pass syntax and executable checks")

for script in [
    "operator_bundle/download_priority_chunks.sh",
    "operator_bundle/verify_materialization_after_download.sh",
    "operator_bundle/run_full_page_hash_after_download.sh",
    "operator_bundle/recheck_generation_after_download.sh",
]:
    subprocess.run(["bash", "-n", str(run_dir / script)], check=True)

for script in [
    "operator_bundle/verify_materialization_after_download.sh",
    "operator_bundle/run_full_page_hash_after_download.sh",
    "operator_bundle/recheck_generation_after_download.sh",
]:
    content = (run_dir / script).read_text(encoding="utf-8")
    if ":-'" in content:
        raise SystemExit(f"v61bp script has literal quoted parameter default: {script}")
    if 'cd "$REPO_ROOT"' not in content:
        raise SystemExit(f"v61bp script should cd through quoted REPO_ROOT: {script}")

dry_env = os.environ.copy()
dry_env["V61BP_EXECUTE_PAYLOAD"] = "0"
dry_env["V61BP_MAX_ROWS"] = "1"
dry_proc = subprocess.run(
    ["bash", str(run_dir / "operator_bundle/download_priority_chunks.sh")],
    text=True,
    capture_output=True,
    env=dry_env,
    check=False,
    timeout=60,
)
if dry_proc.returncode != 0:
    raise SystemExit(f"v61bp dry-run script failed: {dry_proc.stderr}")
if "dry-run: set V61BP_EXECUTE_PAYLOAD=1" not in dry_proc.stdout:
    raise SystemExit("v61bp dry-run script did not show guard")
if "processed 1 planned payload rows" not in dry_proc.stdout:
    raise SystemExit("v61bp dry-run script did not process one row")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bp metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61bo-readiness-input",
    "launch-command-rows",
    "priority-chunk-launch-rows",
    "operator-bundle-files",
    "operator-script-syntax",
    "download-dry-run-guard",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bp requirement should pass: {requirement_id}")
for requirement_id in [
    "explicit-payload-execution-approval",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bp requirement should stay blocked: {requirement_id}")

for gate in [
    "v61bo-readiness-input",
    "launch-command-rows",
    "priority-chunk-launch-rows",
    "operator-bundle-files",
    "operator-script-syntax",
    "download-dry-run-guard",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bp gate should pass: {gate}")
for gate in [
    "explicit-payload-execution-approval",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bp gate should stay blocked: {gate}")

for gap in [
    "v61bo-readiness-input",
    "launch-command-rows",
    "priority-chunk-launch-rows",
    "operator-bundle-files",
    "download-dry-run-guard",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bp gap should be ready: {gap}")
for gap in [
    "explicit-payload-execution-approval",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bp gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bp_ubuntu1_payload_execution_launch_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bp_ubuntu1_payload_execution_launch_bundle_ready") != 1:
    raise SystemExit("v61bp manifest readiness mismatch")
if manifest.get("dry_run_guard_ready") != 1:
    raise SystemExit("v61bp manifest dry-run guard mismatch")
if manifest.get("payload_execution_approval_ready") != 0:
    raise SystemExit("v61bp manifest approval should be blocked by default")
if manifest.get("download_execution_ready") != 0:
    raise SystemExit("v61bp manifest must keep download execution blocked")

operator_readme = (run_dir / "operator_bundle/README.md").read_text(encoding="utf-8")
operator_env = (run_dir / "operator_bundle/operator_env.template").read_text(encoding="utf-8")
download_script = (run_dir / "operator_bundle/download_priority_chunks.sh").read_text(encoding="utf-8")
boundary = (run_dir / "V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "launch_command_rows=59",
    "priority_chunk_launch_rows=3",
    "payload_execution_launch_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bp=0",
]:
    if snippet not in operator_readme:
        raise SystemExit(f"v61bp operator README missing snippet: {snippet}")
for snippet in [
    "V61BP_EXECUTE_PAYLOAD=0",
    "V61BP_APPROVAL_PHRASE=",
    "execute-ubuntu1-checkpoint-payload",
]:
    if snippet not in operator_env:
        raise SystemExit(f"v61bp operator env missing snippet: {snippet}")
for snippet in [
    "V61BP_EXECUTE_PAYLOAD",
    "V61BP_APPROVAL_PHRASE",
    "dry-run",
    "processed",
]:
    if snippet not in download_script:
        raise SystemExit(f"v61bp download script missing snippet: {snippet}")
for snippet in [
    "selected_launch_bundle_id=ubuntu-1-payload-launch-bundle-dry-run-default",
    "payload_execution_preflight_ready=1",
    "launch_command_rows=59",
    "operator_bundle_file_rows=7",
    "dry_run_guard_ready=1",
    "approval_required_rows=2",
    "approval_supplied_rows=0",
    "payload_execution_approval_ready=0",
    "payload_execution_launch_ready=0",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bp=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bp boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bp sha256 mismatch: {rel}")
PY
