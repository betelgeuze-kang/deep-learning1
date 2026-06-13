#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61by_ubuntu1_remaining_page_hash_execution_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61by_ubuntu1_remaining_page_hash_execution_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61by_ubuntu1_remaining_page_hash_execution_plan_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BY_REUSE_EXISTING="${V61BY_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61by_ubuntu1_remaining_page_hash_execution_plan.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import math
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
    "v61by_ubuntu1_remaining_page_hash_execution_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bx_ubuntu1_page_hash_coverage_ledger_ready": "1",
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_unique_page_rows": "134161",
    "total_checkpoint_bytes_expected": "281241493344",
    "remaining_page_hash_execution_chunk_size_pages": "512",
    "full_safetensors_page_hash_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61by": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61by {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "remaining_page_hash_execution_chunk_rows.csv",
    "verified_page_hash_skip_rows.csv",
    "remaining_page_hash_execution_requirement_rows.csv",
    "remaining_page_hash_execution_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BY_UBUNTU1_REMAINING_PAGE_HASH_EXECUTION_PLAN_BOUNDARY.md",
    "v61by_ubuntu1_remaining_page_hash_execution_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61bx/page_hash_coverage_ledger_rows.csv",
    "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv",
    "source_v61bv/verified_checkpoint_shard_skip_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61by artifact: {rel}")

chunk_rows = read_csv(run_dir / "remaining_page_hash_execution_chunk_rows.csv")
skip_rows = [row for row in read_csv(run_dir / "verified_page_hash_skip_rows.csv") if row["shard_name"] != "none"]
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "remaining_page_hash_execution_requirement_rows.csv")}
metric = read_csv(run_dir / "remaining_page_hash_execution_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
ledger_rows = read_csv(run_dir / "source_v61bx/page_hash_coverage_ledger_rows.csv")
source_v61bv_summary = read_csv(run_dir / "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv")[0]
queue_rows = [
    row
    for row in read_csv(run_dir / "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv")
    if row["shard_name"] != "none"
]

remaining_pages = sum(int(row["remaining_page_hash_rows"]) for row in ledger_rows)
remaining_bytes = sum(int(row["remaining_page_hash_bytes"]) for row in ledger_rows)
verified_pages = sum(int(row["verified_page_hash_rows"]) for row in ledger_rows)
verified_bytes = sum(int(row["verified_page_hash_bytes"]) for row in ledger_rows)
expected_chunks = sum(math.ceil(int(row["remaining_page_hash_rows"]) / 512) for row in ledger_rows if int(row["remaining_page_hash_rows"]) > 0)
planned_pages = sum(int(row["planned_page_hash_rows"]) for row in chunk_rows)
skipped_pages = sum(int(row["verified_page_hash_rows"]) for row in skip_rows)
skipped_bytes = sum(int(row["verified_page_hash_bytes"]) for row in skip_rows)

dynamic_expected = {
    "verified_page_hash_rows": str(verified_pages),
    "verified_page_hash_bytes": str(verified_bytes),
    "skipped_verified_page_hash_rows": str(skipped_pages),
    "skipped_verified_page_hash_bytes": str(skipped_bytes),
    "remaining_page_hash_rows": str(remaining_pages),
    "remaining_page_hash_bytes": str(remaining_bytes),
    "remaining_page_hash_execution_chunk_rows": str(expected_chunks),
    "remaining_page_hash_execution_plan_ready": "1" if planned_pages == remaining_pages and expected_chunks == len(chunk_rows) else "0",
}
for field, value in dynamic_expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61by {field}: expected {value}, got {summary.get(field)}")
    if metric.get(field) != value:
        raise SystemExit(f"v61by metric {field}: expected {value}, got {metric.get(field)}")

if len(queue_rows) != int(source_v61bv_summary["remaining_queue_rows"]):
    raise SystemExit("v61by source remaining queue count mismatch")
if len(chunk_rows) != expected_chunks:
    raise SystemExit("v61by chunk row count mismatch")
if planned_pages != remaining_pages:
    raise SystemExit("v61by planned remaining page rows mismatch")
if skipped_pages != verified_pages or skipped_bytes != verified_bytes:
    raise SystemExit("v61by skipped verified page hash mismatch")
if verified_pages + remaining_pages != 134161:
    raise SystemExit("v61by page partition mismatch")
if verified_bytes + remaining_bytes != 281241493344:
    raise SystemExit("v61by byte partition mismatch")
if any(row["page_hash_execution_status"] != "blocked-pending-materialization" for row in chunk_rows):
    raise SystemExit("v61by chunks should remain blocked pending materialization")
if any(row["dry_run_default"] != "1" or row["requires_execute_flag"] != "1" for row in chunk_rows):
    raise SystemExit("v61by chunks must be dry-run/execute guarded")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in chunk_rows + skip_rows):
    raise SystemExit("v61by rows must keep repo payload bytes at zero")

for requirement_id in [
    "v61bx-coverage-ledger-input",
    "v61bv-remaining-materialization-input",
    "remaining-page-hash-execution-plan",
    "skip-already-verified-page-hash-shards",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61by requirement should pass: {requirement_id}")
if requirements["completed-full-safetensors-page-hash-coverage"]["status"] != "pass":
    raise SystemExit("v61by full coverage should pass after 0 remaining rows")

for gate in [
    "v61bx-coverage-ledger-input",
    "v61bv-remaining-materialization-input",
    "remaining-page-hash-execution-plan",
    "skip-already-verified-page-hash-shards",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61by gate should pass: {gate}")
if decisions.get("completed-full-safetensors-page-hash-coverage") != "pass":
    raise SystemExit("v61by completed full page-hash gate should pass")
for gate in ["actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61by gate should stay blocked: {gate}")

if gaps["remaining-page-hash-execution-plan"] != "ready":
    raise SystemExit("v61by remaining plan gap should be ready")
if gaps.get("completed-full-safetensors-page-hash-coverage") != "ready":
    raise SystemExit("v61by completed full page-hash gap should be ready")
for gap in ["actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61by gap should stay blocked: {gap}")

boundary = (run_dir / "V61BY_UBUNTU1_REMAINING_PAGE_HASH_EXECUTION_PLAN_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"verified_page_hash_rows={verified_pages}",
    f"skipped_verified_page_hash_rows={skipped_pages}",
    f"remaining_page_hash_rows={remaining_pages}",
    f"remaining_page_hash_execution_chunk_rows={expected_chunks}",
    "remaining_page_hash_execution_plan_ready=1",
    "full_safetensors_page_hash_binding_ready=1",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61by=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61by boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61by_ubuntu1_remaining_page_hash_execution_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61by_ubuntu1_remaining_page_hash_execution_plan_ready") != 1:
    raise SystemExit("v61by manifest readiness mismatch")
if manifest.get("remaining_page_hash_execution_chunk_rows") != expected_chunks:
    raise SystemExit("v61by manifest chunk row count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61by") != 0:
    raise SystemExit("v61by manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61by sha256 mismatch: {rel}")
PY

echo "v61by ubuntu-1 remaining page-hash execution plan smoke passed"
