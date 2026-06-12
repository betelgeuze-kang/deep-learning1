#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bx_ubuntu1_page_hash_coverage_ledger/ledger_001"
SUMMARY_CSV="$RESULTS_DIR/v61bx_ubuntu1_page_hash_coverage_ledger_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bx_ubuntu1_page_hash_coverage_ledger_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BX_REUSE_EXISTING="${V61BX_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bx_ubuntu1_page_hash_coverage_ledger.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
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
    "v61bx_ubuntu1_page_hash_coverage_ledger_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bw_ubuntu1_partial_page_hash_witness_ready": "1",
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_unique_page_rows": "134161",
    "total_checkpoint_bytes_expected": "281241493344",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bx {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "page_hash_coverage_ledger_rows.csv",
    "page_hash_coverage_requirement_rows.csv",
    "page_hash_coverage_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BX_UBUNTU1_PAGE_HASH_COVERAGE_LEDGER_BOUNDARY.md",
    "v61bx_ubuntu1_page_hash_coverage_ledger_manifest.json",
    "sha256_manifest.csv",
    "source_v61bw/partial_page_hash_witness_rows.csv",
    "source_v61bw/partial_page_hash_shard_status_rows.csv",
    "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv",
    "source_v61bv/verified_checkpoint_shard_skip_rows.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bx artifact: {rel}")

ledger_rows = read_csv(run_dir / "page_hash_coverage_ledger_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "page_hash_coverage_requirement_rows.csv")}
metric = read_csv(run_dir / "page_hash_coverage_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
partial_shard_rows = [
    row
    for row in read_csv(run_dir / "source_v61bw/partial_page_hash_shard_status_rows.csv")
    if row["shard_name"] != "none" and row["partial_full_shard_page_hash_ready"] == "1"
]
partial_page_rows = read_csv(run_dir / "source_v61bw/partial_page_hash_witness_rows.csv")
remaining_queue_rows = [
    row
    for row in read_csv(run_dir / "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv")
    if row["shard_name"] != "none"
]
skip_rows = [
    row
    for row in read_csv(run_dir / "source_v61bv/verified_checkpoint_shard_skip_rows.csv")
    if row["shard_name"] != "none"
]
shard_page_rows = read_csv(run_dir / "source_v61q/checkpoint_shard_page_summary_rows.csv")

if len(ledger_rows) != 59 or len(shard_page_rows) != 59:
    raise SystemExit("v61bx ledger/source shard row count mismatch")
verified_rows = sum(int(row["verified_page_hash_rows"]) for row in ledger_rows)
verified_bytes = sum(int(row["verified_page_hash_bytes"]) for row in ledger_rows)
remaining_rows = sum(int(row["remaining_page_hash_rows"]) for row in ledger_rows)
remaining_bytes = sum(int(row["remaining_page_hash_bytes"]) for row in ledger_rows)
verified_shards = sum(1 for row in ledger_rows if row["full_shard_page_hash_coverage_ready"] == "1")
remaining_shards = len(ledger_rows) - verified_shards
queued_shards = sum(1 for row in ledger_rows if row["remaining_materialization_queued"] == "1")
skipped_shards = sum(1 for row in ledger_rows if row["verified_shard_skipped_by_materialization_queue"] == "1")
partial_ready = "1" if verified_rows > 0 and verified_rows == len(partial_page_rows) else "0"
full_ready = "1" if verified_rows == 134161 and verified_shards == 59 else "0"

dynamic_expected = {
    "verified_page_hash_shard_rows": str(verified_shards),
    "verified_page_hash_rows": str(verified_rows),
    "verified_page_hash_bytes": str(verified_bytes),
    "remaining_page_hash_shard_rows": str(remaining_shards),
    "remaining_page_hash_rows": str(remaining_rows),
    "remaining_page_hash_bytes": str(remaining_bytes),
    "remaining_materialization_queue_rows": str(len(remaining_queue_rows)),
    "queued_remaining_shard_rows": str(queued_shards),
    "skipped_verified_shard_rows": str(skipped_shards),
    "partial_page_hash_coverage_ledger_ready": partial_ready,
    "full_safetensors_page_hash_binding_ready": full_ready,
}
for field, value in dynamic_expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bx {field}: expected {value}, got {summary.get(field)}")
    if metric.get(field) != value:
        raise SystemExit(f"v61bx metric {field}: expected {value}, got {metric.get(field)}")

if verified_rows != len(partial_page_rows):
    raise SystemExit("v61bx verified rows must equal v61bw witness rows")
if verified_bytes != sum(int(row["hashed_page_bytes"]) for row in partial_shard_rows):
    raise SystemExit("v61bx verified bytes must equal v61bw shard bytes")
if verified_rows + remaining_rows != 134161:
    raise SystemExit("v61bx page rows must partition total checkpoint pages")
if verified_bytes + remaining_bytes != 281241493344:
    raise SystemExit("v61bx page bytes must partition total checkpoint bytes")
if queued_shards != len(remaining_queue_rows):
    raise SystemExit("v61bx queued shard count mismatch")
if skipped_shards != len(skip_rows):
    raise SystemExit("v61bx skipped shard count mismatch")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in ledger_rows):
    raise SystemExit("v61bx ledger rows must not commit payload bytes")

for requirement_id in [
    "v61bw-partial-page-hash-input",
    "v61q-page-map-input",
    "v61bv-remaining-materialization-queue-input",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bx requirement should pass: {requirement_id}")
if requirements["partial-page-hash-coverage-ledger"]["status"] != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bx partial ledger requirement status mismatch")
if requirements["completed-full-safetensors-page-hash-coverage"]["status"] != ("pass" if full_ready == "1" else "blocked"):
    raise SystemExit("v61bx full coverage requirement status mismatch")
if requirements["actual-model-generation"]["status"] != "blocked":
    raise SystemExit("v61bx generation requirement must stay blocked")

for gate in [
    "v61bw-partial-page-hash-input",
    "v61q-page-map-input",
    "v61bv-remaining-materialization-queue-input",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bx gate should pass: {gate}")
if decisions["partial-page-hash-coverage-ledger"] != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bx partial ledger gate status mismatch")
if decisions["completed-full-safetensors-page-hash-coverage"] != ("pass" if full_ready == "1" else "blocked"):
    raise SystemExit("v61bx full coverage gate status mismatch")
for gate in ["actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bx gate should remain blocked: {gate}")

if gaps["partial-page-hash-coverage-ledger"] != ("ready" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bx partial gap mismatch")
if gaps["completed-full-safetensors-page-hash-coverage"] != ("ready" if full_ready == "1" else "blocked"):
    raise SystemExit("v61bx full coverage gap mismatch")
for gap in ["actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bx gap should stay blocked: {gap}")

boundary = (run_dir / "V61BX_UBUNTU1_PAGE_HASH_COVERAGE_LEDGER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"verified_page_hash_rows={verified_rows}",
    f"verified_page_hash_bytes={verified_bytes}",
    f"remaining_page_hash_rows={remaining_rows}",
    f"remaining_page_hash_bytes={remaining_bytes}",
    f"partial_page_hash_coverage_ledger_ready={partial_ready}",
    f"full_safetensors_page_hash_binding_ready={full_ready}",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bx=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bx boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bx_ubuntu1_page_hash_coverage_ledger_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bx_ubuntu1_page_hash_coverage_ledger_ready") != 1:
    raise SystemExit("v61bx manifest readiness mismatch")
if manifest.get("verified_page_hash_rows") != verified_rows:
    raise SystemExit("v61bx manifest verified page count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bx") != 0:
    raise SystemExit("v61bx manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bx sha256 mismatch: {rel}")
PY

echo "v61bx ubuntu-1 page-hash coverage ledger smoke passed"
