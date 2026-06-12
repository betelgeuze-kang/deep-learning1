#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bv_ubuntu1_remaining_checkpoint_materialization_queue/queue_001"
SUMMARY_CSV="$RESULTS_DIR/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BV_REUSE_EXISTING="${V61BV_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
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
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": "1",
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "payload_execution_launch_ready": "0",
    "download_execution_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bv {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "remaining_checkpoint_materialization_queue_rows.csv",
    "verified_checkpoint_shard_skip_rows.csv",
    "remaining_checkpoint_materialization_chunk_rows.csv",
    "remaining_checkpoint_materialization_requirement_rows.csv",
    "remaining_checkpoint_materialization_metric_rows.csv",
    "remaining_checkpoint_materialization_script_probe_rows.csv",
    "remaining_checkpoint_materialization_dry_run_probe_rows.csv",
    "remaining_checkpoint_materialization_operator_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61BV_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_QUEUE_BOUNDARY.md",
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_manifest.json",
    "sha256_manifest.csv",
    "operator_bundle/README.md",
    "operator_bundle/operator_env.template",
    "operator_bundle/remaining_checkpoint_materialization_queue_rows.csv",
    "operator_bundle/download_remaining_checkpoint_shards.sh",
    "operator_bundle/verify_remaining_checkpoint_materialization.sh",
    "source_v61bp/ubuntu1_payload_execution_readiness_rows.csv",
    "source_v61bu/partial_checkpoint_materialization_witness_rows.csv",
    "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bv artifact: {rel}")

queue_rows = [row for row in read_csv(run_dir / "remaining_checkpoint_materialization_queue_rows.csv") if row["shard_name"] != "none"]
operator_queue_rows = [row for row in read_csv(run_dir / "operator_bundle/remaining_checkpoint_materialization_queue_rows.csv") if row["shard_name"] != "none"]
skip_rows = [row for row in read_csv(run_dir / "verified_checkpoint_shard_skip_rows.csv") if row["shard_name"] != "none"]
chunk_rows = [row for row in read_csv(run_dir / "remaining_checkpoint_materialization_chunk_rows.csv") if row["priority_class"] != "none"]
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "remaining_checkpoint_materialization_requirement_rows.csv")}
metric = read_csv(run_dir / "remaining_checkpoint_materialization_metric_rows.csv")[0]
script_rows = read_csv(run_dir / "remaining_checkpoint_materialization_script_probe_rows.csv")
dry_run = read_csv(run_dir / "remaining_checkpoint_materialization_dry_run_probe_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
source_readiness = read_csv(run_dir / "source_v61bp/ubuntu1_payload_execution_readiness_rows.csv")
source_materialization = read_csv(run_dir / "source_v61t/local_checkpoint_materialization_rows.csv")

verified_shards = {row["shard_name"] for row in source_materialization if row["local_identity_verified"] == "1"}
remaining_source = [row for row in source_readiness if row["shard_name"] not in verified_shards]
expected_remaining_bytes = 0
for row in remaining_source:
    local = next(item for item in source_materialization if item["shard_name"] == row["shard_name"])
    expected_remaining_bytes += max(int(row["expected_bytes"]) - int(local["actual_bytes"]), 0)
expected_identity_bytes = sum(int(row["actual_bytes"]) for row in source_materialization if row["local_identity_verified"] == "1")
expected_priority_counts = {}
for row in remaining_source:
    expected_priority_counts[row["priority_class"]] = expected_priority_counts.get(row["priority_class"], 0) + 1

if len(queue_rows) != len(remaining_source):
    raise SystemExit("v61bv remaining queue count mismatch")
if operator_queue_rows != queue_rows:
    raise SystemExit("v61bv operator queue must mirror queue rows")
if len(skip_rows) != len(verified_shards):
    raise SystemExit("v61bv skip row count mismatch")
if {row["shard_name"] for row in skip_rows} != verified_shards:
    raise SystemExit("v61bv skipped shard set mismatch")
if any(row["shard_name"] in verified_shards for row in queue_rows):
    raise SystemExit("v61bv queue must exclude verified shards")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in queue_rows + skip_rows):
    raise SystemExit("v61bv rows must keep repo payload bytes at zero")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bv"] != "0" for row in queue_rows):
    raise SystemExit("v61bv queue must not record payload downloads")
if any(row["dry_run_default"] != "1" or row["requires_execute_flag"] != "1" or row["requires_approval_phrase"] != "1" for row in queue_rows + chunk_rows):
    raise SystemExit("v61bv queue/chunk rows must be dry-run first")
if any(not row["target_path"].startswith(ubuntu1_target) for row in queue_rows):
    raise SystemExit("v61bv queue targets must remain under ubuntu-1")
if any("/tmp/" in row["target_path"] for row in queue_rows):
    raise SystemExit("v61bv queue must not include stale /tmp target paths")

dynamic_expected = {
    "verified_identity_shard_rows": str(len(verified_shards)),
    "skipped_verified_shard_rows": str(len(skip_rows)),
    "remaining_queue_rows": str(len(queue_rows)),
    "remaining_chunk_rows": str(len(chunk_rows)),
    "remaining_unverified_bytes": str(expected_remaining_bytes),
    "local_identity_verified_bytes": str(expected_identity_bytes),
    "remaining_queue_ready": "1" if queue_rows else "0",
    "script_probe_rows": str(len(script_rows)),
    "script_bash_syntax_pass_rows": str(sum(1 for row in script_rows if row["bash_syntax_pass"] == "1")),
    "dry_run_guard_ready": "1",
}
for field, value in dynamic_expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bv {field}: expected {value}, got {summary.get(field)}")
    if metric.get(field) != value:
        raise SystemExit(f"v61bv metric {field}: expected {value}, got {metric.get(field)}")
for priority_class, count in expected_priority_counts.items():
    field = f"{priority_class}_remaining_rows"
    if summary.get(field) != str(count):
        raise SystemExit(f"v61bv {field}: expected {count}, got {summary.get(field)}")

if int(summary["ubuntu1_available_bytes_live"]) <= 0:
    raise SystemExit("v61bv should record live ubuntu-1 available bytes")
if summary["remaining_bytes_fit_current_free_space"] not in {"0", "1"}:
    raise SystemExit("v61bv free-space fit flag must be boolean")
if int(summary["ubuntu1_available_bytes_live"]) >= expected_remaining_bytes and summary["remaining_bytes_fit_current_free_space"] != "1":
    raise SystemExit("v61bv fit flag should pass when current free bytes cover remaining bytes")

for row in script_rows:
    if row["bash_syntax_pass"] != "1" or row["executable_bit_set"] != "1":
        raise SystemExit("v61bv operator scripts must pass syntax and executable checks")
for script in [
    "operator_bundle/download_remaining_checkpoint_shards.sh",
    "operator_bundle/verify_remaining_checkpoint_materialization.sh",
]:
    subprocess.run(["bash", "-n", str(run_dir / script)], check=True)

dry_env = os.environ.copy()
dry_env["V61BV_EXECUTE_PAYLOAD"] = "0"
dry_env["V61BV_MAX_ROWS"] = "1"
dry_proc = subprocess.run(
    ["bash", str(run_dir / "operator_bundle/download_remaining_checkpoint_shards.sh")],
    text=True,
    capture_output=True,
    env=dry_env,
    check=False,
    timeout=60,
)
if dry_proc.returncode != 0:
    raise SystemExit(f"v61bv dry-run script failed: {dry_proc.stderr}")
if "dry-run: set V61BV_EXECUTE_PAYLOAD=1" not in dry_proc.stdout:
    raise SystemExit("v61bv dry-run guard message missing")
if "processed 1 remaining payload rows" not in dry_proc.stdout and queue_rows:
    raise SystemExit("v61bv dry-run should process one remaining row")
if dry_run["exit_code"] != "0" or dry_run["dry_run_guard_seen"] != "1" or dry_run["payload_execution_blocked"] != "1":
    raise SystemExit("v61bv stored dry-run probe mismatch")

for requirement_id in [
    "v61bp-launch-bundle-input",
    "v61bu-partial-witness-input",
    "skip-verified-shards",
    "remaining-materialization-queue",
    "operator-script-syntax",
    "download-dry-run-guard",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bv requirement should pass: {requirement_id}")
for requirement_id in [
    "explicit-payload-execution",
    "receipt-backed-full-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bv requirement should stay blocked: {requirement_id}")
if requirements["current-free-space-for-remaining-bytes"]["status"] != ("pass" if summary["remaining_bytes_fit_current_free_space"] == "1" else "blocked"):
    raise SystemExit("v61bv current free-space requirement status mismatch")

for gate in [
    "v61bp-launch-bundle-input",
    "v61bu-partial-witness-input",
    "skip-verified-shards",
    "remaining-materialization-queue",
    "operator-script-syntax",
    "download-dry-run-guard",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bv gate should pass: {gate}")
for gate in [
    "explicit-payload-execution",
    "receipt-backed-full-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bv gate should stay blocked: {gate}")
if gaps["remaining-materialization-queue"] != "ready":
    raise SystemExit("v61bv remaining queue gap should be ready")
for gap in ["explicit-payload-execution", "receipt-backed-full-materialization", "full-safetensors-page-hash-binding", "actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bv gap should stay blocked: {gap}")

boundary = (run_dir / "V61BV_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_QUEUE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"verified_identity_shard_rows={len(verified_shards)}",
    f"skipped_verified_shard_rows={len(skip_rows)}",
    f"remaining_queue_rows={len(queue_rows)}",
    f"remaining_unverified_bytes={expected_remaining_bytes}",
    "payload_execution_launch_ready=0",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bv=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bv boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready") != 1:
    raise SystemExit("v61bv manifest readiness mismatch")
if manifest.get("remaining_queue_rows") != len(queue_rows):
    raise SystemExit("v61bv manifest remaining count mismatch")
if manifest.get("remaining_unverified_bytes") != expected_remaining_bytes:
    raise SystemExit("v61bv manifest remaining bytes mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bv") != 0:
    raise SystemExit("v61bv manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bv sha256 mismatch: {rel}")
PY

echo "v61bv ubuntu-1 remaining checkpoint materialization queue smoke passed"
