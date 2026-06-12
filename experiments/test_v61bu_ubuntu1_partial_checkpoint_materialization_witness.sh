#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bu_ubuntu1_partial_checkpoint_materialization_witness/witness_001"
SUMMARY_CSV="$RESULTS_DIR/v61bu_ubuntu1_partial_checkpoint_materialization_witness_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bu_ubuntu1_partial_checkpoint_materialization_witness_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BU_REUSE_EXISTING="${V61BU_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh" >/dev/null

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
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_expected": "281241493344",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bu {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "partial_checkpoint_materialization_witness_rows.csv",
    "partial_checkpoint_materialization_requirement_rows.csv",
    "partial_checkpoint_materialization_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BU_UBUNTU1_PARTIAL_CHECKPOINT_MATERIALIZATION_WITNESS_BOUNDARY.md",
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_manifest.json",
    "sha256_manifest.csv",
    "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv",
    "source_v61bq/ubuntu1_payload_execution_receipt_status_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bu artifact: {rel}")

witness_rows = read_csv(run_dir / "partial_checkpoint_materialization_witness_rows.csv")
live_rows = read_csv(run_dir / "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv")
materialization_rows = read_csv(run_dir / "source_v61t/local_checkpoint_materialization_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "partial_checkpoint_materialization_requirement_rows.csv")}
metric = read_csv(run_dir / "partial_checkpoint_materialization_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(live_rows) != 59 or len(materialization_rows) != 59:
    raise SystemExit("v61bu source row counts mismatch")
live_existing = sum(1 for row in live_rows if row["local_file_exists"] == "1")
live_size_match = sum(1 for row in live_rows if row["size_match"] == "1")
local_existing = sum(1 for row in materialization_rows if row["local_file_exists"] == "1")
local_size_match = sum(1 for row in materialization_rows if row["size_match"] == "1")
local_header_match = sum(1 for row in materialization_rows if row["local_header_hash_match"] == "1")
local_identity = sum(1 for row in materialization_rows if row["local_identity_verified"] == "1")
local_identity_bytes = sum(int(row["actual_bytes"]) for row in materialization_rows if row["local_identity_verified"] == "1")
expected_witness_rows = local_existing if local_existing else 1
partial_ready = "1" if local_identity > 0 else "0"
full_ready = "1" if local_identity == 59 else "0"
remaining_shards = 59 - local_identity
remaining_bytes = 281241493344 - local_identity_bytes

if len(witness_rows) != expected_witness_rows:
    raise SystemExit("v61bu witness row count mismatch")
if local_existing == 0 and witness_rows[0]["materialization_status"] != "no-live-full-shard":
    raise SystemExit("v61bu no-live path should emit a sentinel witness row")
for row in witness_rows:
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bu witness rows must not commit payload bytes")
    if row["local_identity_verified"] == "1" and row["materialization_status"] != "identity-verified":
        raise SystemExit("v61bu identity witness status mismatch")

dynamic_expected = {
    "live_existing_shard_rows": str(live_existing),
    "live_size_match_shard_rows": str(live_size_match),
    "local_existing_shard_rows": str(local_existing),
    "local_size_match_shard_rows": str(local_size_match),
    "local_header_hash_match_shard_rows": str(local_header_match),
    "local_identity_verified_shard_rows": str(local_identity),
    "local_identity_verified_bytes": str(local_identity_bytes),
    "remaining_identity_unverified_shard_rows": str(remaining_shards),
    "remaining_identity_unverified_bytes": str(remaining_bytes),
    "partial_checkpoint_materialization_witness_ready": partial_ready,
    "full_checkpoint_materialization_ready": full_ready,
    "observed_external_checkpoint_payload_bytes": str(local_identity_bytes),
}
for field, value in dynamic_expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bu {field}: expected {value}, got {summary.get(field)}")
    if metric.get(field) != value:
        raise SystemExit(f"v61bu metric {field}: expected {value}, got {metric.get(field)}")

for requirement_id in ["v61bq-live-presence-input", "v61t-identity-verifier-input"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bu requirement should pass: {requirement_id}")
if requirements["partial-shard-materialization-witness"]["status"] != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bu partial witness requirement status mismatch")
for requirement_id in ["receipt-backed-full-materialization", "full-page-hash-coverage", "actual-model-generation"]:
    if requirements[requirement_id]["status"] != ("pass" if requirement_id == "receipt-backed-full-materialization" and full_ready == "1" and summary["accepted_payload_execution_receipt_rows"] == "59" else "blocked"):
        raise SystemExit(f"v61bu requirement status mismatch: {requirement_id}")

for gate in ["v61bq-live-presence-input", "v61t-identity-verifier-input", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bu gate should pass: {gate}")
if decisions.get("partial-shard-materialization-witness") != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bu partial witness gate status mismatch")
for gate in ["full-safetensors-page-hash-binding", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bu gate should stay blocked: {gate}")

if gaps["partial-shard-materialization-witness"] != ("ready" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bu partial witness gap status mismatch")
for gap in ["full-safetensors-page-hash-binding", "actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bu gap should stay blocked: {gap}")

boundary = (run_dir / "V61BU_UBUNTU1_PARTIAL_CHECKPOINT_MATERIALIZATION_WITNESS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"live_existing_shard_rows={live_existing}",
    f"live_size_match_shard_rows={live_size_match}",
    f"local_identity_verified_shard_rows={local_identity}",
    f"local_identity_verified_bytes={local_identity_bytes}",
    f"partial_checkpoint_materialization_witness_ready={partial_ready}",
    f"full_checkpoint_materialization_ready={full_ready}",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bu=0",
    f"observed_external_checkpoint_payload_bytes={local_identity_bytes}",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bu boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready") != 1:
    raise SystemExit("v61bu manifest readiness mismatch")
if manifest.get("local_identity_verified_shard_rows") != local_identity:
    raise SystemExit("v61bu manifest identity count mismatch")
if manifest.get("observed_external_checkpoint_payload_bytes") != local_identity_bytes:
    raise SystemExit("v61bu manifest observed byte count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bu") != 0:
    raise SystemExit("v61bu manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bu sha256 mismatch: {rel}")
PY

echo "v61bu ubuntu-1 partial checkpoint materialization witness smoke passed"
