#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bz_ubuntu1_remaining_page_hash_operator_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BZ_REUSE_EXISTING="${V61BZ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = sys.argv[4]


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
expected_static = {
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61by_ubuntu1_remaining_page_hash_execution_plan_ready": "1",
    "target_root_path": ubuntu1_target,
    "verified_page_hash_rows": "134161",
    "skipped_verified_page_hash_rows": "134161",
    "remaining_page_hash_rows": "0",
    "remaining_page_hash_bytes": "0",
    "remaining_page_hash_execution_chunk_rows": "0",
    "operator_bundle_file_rows": "7",
    "script_probe_rows": "2",
    "script_bash_syntax_pass_rows": "2",
    "dry_run_guard_ready": "1",
    "remaining_page_hash_operator_bundle_ready": "1",
    "page_hash_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bz {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "remaining_page_hash_operator_script_probe_rows.csv",
    "remaining_page_hash_operator_dry_run_probe_rows.csv",
    "remaining_page_hash_operator_file_rows.csv",
    "remaining_page_hash_operator_requirement_rows.csv",
    "remaining_page_hash_operator_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BZ_UBUNTU1_REMAINING_PAGE_HASH_OPERATOR_BUNDLE_BOUNDARY.md",
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_manifest.json",
    "sha256_manifest.csv",
    "operator_bundle/README.md",
    "operator_bundle/operator_env.template",
    "operator_bundle/remaining_page_hash_execution_chunk_rows.csv",
    "operator_bundle/verified_page_hash_skip_rows.csv",
    "operator_bundle/remaining_page_hash_result_schema_rows.csv",
    "operator_bundle/hash_remaining_page_chunks.sh",
    "operator_bundle/verify_remaining_page_hash_results.sh",
    "source_v61by/remaining_page_hash_execution_chunk_rows.csv",
    "source_v61by/verified_page_hash_skip_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bz artifact: {rel}")

operator_chunks = read_csv(run_dir / "operator_bundle/remaining_page_hash_execution_chunk_rows.csv")
source_chunks = read_csv(run_dir / "source_v61by/remaining_page_hash_execution_chunk_rows.csv")
operator_skip = read_csv(run_dir / "operator_bundle/verified_page_hash_skip_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "remaining_page_hash_operator_requirement_rows.csv")}
metric = read_csv(run_dir / "remaining_page_hash_operator_metric_rows.csv")[0]
script_rows = read_csv(run_dir / "remaining_page_hash_operator_script_probe_rows.csv")
dry_run = read_csv(run_dir / "remaining_page_hash_operator_dry_run_probe_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if operator_chunks != source_chunks:
    raise SystemExit("v61bz operator chunks must mirror source chunks")
if len(operator_chunks) != 0:
    raise SystemExit("v61bz chunk count mismatch")
if any(row["page_hash_execution_status"] != "blocked-pending-materialization" for row in operator_chunks):
    raise SystemExit("v61bz chunks should stay blocked pending materialization")
if any(row["dry_run_default"] != "1" or row["requires_execute_flag"] != "1" or row["requires_approval_phrase"] != "1" for row in operator_chunks):
    raise SystemExit("v61bz chunks must remain dry-run and approval guarded")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in operator_chunks + operator_skip):
    raise SystemExit("v61bz rows must keep repo payload bytes at zero")

for row in script_rows:
    if row["bash_syntax_pass"] != "1" or row["executable_bit_set"] != "1":
        raise SystemExit("v61bz operator scripts must pass syntax and executable checks")
for script in [
    "operator_bundle/hash_remaining_page_chunks.sh",
    "operator_bundle/verify_remaining_page_hash_results.sh",
]:
    subprocess.run(["bash", "-n", str(run_dir / script)], check=True)

dry_env = os.environ.copy()
dry_env["V61BZ_EXECUTE_PAGE_HASH"] = "0"
dry_env["V61BZ_MAX_CHUNKS"] = "1"
dry_proc = subprocess.run(
    ["bash", str(run_dir / "operator_bundle/hash_remaining_page_chunks.sh")],
    text=True,
    capture_output=True,
    env=dry_env,
    check=False,
    timeout=60,
)
if dry_proc.returncode != 0:
    raise SystemExit(f"v61bz dry-run script failed: {dry_proc.stderr}")
if "dry-run: set V61BZ_EXECUTE_PAGE_HASH=1" not in dry_proc.stdout:
    raise SystemExit("v61bz dry-run guard message missing")
if "processed 0 remaining page-hash chunks" not in dry_proc.stdout:
    raise SystemExit("v61bz dry-run should process zero chunks after full coverage")
if dry_run["exit_code"] != "0" or dry_run["dry_run_guard_seen"] != "1" or dry_run["processed_one_chunk_seen"] != "0":
    raise SystemExit("v61bz stored dry-run probe mismatch")

blocked_env = os.environ.copy()
blocked_env["V61BZ_EXECUTE_PAGE_HASH"] = "1"
blocked_env["V61BZ_APPROVAL_PHRASE"] = "execute-ubuntu1-remaining-page-hash"
blocked_env["V61BZ_MAX_CHUNKS"] = "1"
blocked_proc = subprocess.run(
    ["bash", str(run_dir / "operator_bundle/hash_remaining_page_chunks.sh")],
    text=True,
    capture_output=True,
    env=blocked_env,
    check=False,
    timeout=60,
)
if blocked_proc.returncode == 0:
    raise SystemExit("v61bz execute path should require identity confirmation")
if "V61BZ_IDENTITY_VERIFIED_CONFIRM=1" not in blocked_proc.stderr:
    raise SystemExit("v61bz identity confirmation guard missing")

for requirement_id in [
    "v61by-remaining-page-hash-plan-input",
    "operator-script-syntax",
    "page-hash-dry-run-guard",
    "remaining-page-hash-operator-bundle",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bz requirement should pass: {requirement_id}")
if requirements["completed-full-safetensors-page-hash-coverage"]["status"] != "pass":
    raise SystemExit("v61bz full coverage should pass after upstream coverage")

for gate in [
    "v61by-remaining-page-hash-plan-input",
    "operator-script-syntax",
    "dry-run-guard",
    "remaining-page-hash-operator-bundle",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bz gate should pass: {gate}")
if decisions.get("explicit-page-hash-execution") != "not-applicable":
    raise SystemExit("v61bz explicit page-hash execution should be not-applicable with zero chunks")
if decisions.get("completed-full-safetensors-page-hash-coverage") != "pass":
    raise SystemExit("v61bz completed full page-hash gate should pass")
for gate in ["actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bz gate should stay blocked: {gate}")
if gaps["remaining-page-hash-operator-bundle"] != "ready":
    raise SystemExit("v61bz operator bundle gap should be ready")
if gaps.get("completed-full-safetensors-page-hash-coverage") != "ready":
    raise SystemExit("v61bz completed full page-hash gap should be ready")
for gap in ["explicit-page-hash-execution", "actual-model-generation", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bz gap should stay blocked: {gap}")

for field, value in expected_static.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bz metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61BZ_UBUNTU1_REMAINING_PAGE_HASH_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "remaining_page_hash_execution_chunk_rows=0",
    "operator_bundle_file_rows=7",
    "dry_run_guard_ready=1",
    "remaining_page_hash_operator_bundle_ready=1",
    "page_hash_execution_ready=0",
    "full_safetensors_page_hash_binding_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61bz=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bz boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bz sha256 mismatch: {rel}")
PY

echo "v61bz ubuntu-1 remaining page-hash operator bundle smoke passed"
