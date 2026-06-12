#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bw_ubuntu1_partial_page_hash_witness/hash_001"
SUMMARY_CSV="$RESULTS_DIR/v61bw_ubuntu1_partial_page_hash_witness_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bw_ubuntu1_partial_page_hash_witness_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BW_REUSE_EXISTING="${V61BW_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bw_ubuntu1_partial_page_hash_witness.sh" >/dev/null

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


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected_static = {
    "v61bw_ubuntu1_partial_page_hash_witness_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_expected": "281241493344",
    "total_checkpoint_unique_page_rows": "134161",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bw {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "partial_page_hash_witness_rows.csv",
    "partial_page_hash_shard_status_rows.csv",
    "partial_page_hash_requirement_rows.csv",
    "partial_page_hash_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BW_UBUNTU1_PARTIAL_PAGE_HASH_WITNESS_BOUNDARY.md",
    "v61bw_ubuntu1_partial_page_hash_witness_manifest.json",
    "sha256_manifest.csv",
    "source_v61bu/partial_checkpoint_materialization_witness_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61q/checkpoint_unique_page_rows.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bw artifact: {rel}")

page_rows = read_csv(run_dir / "partial_page_hash_witness_rows.csv")
shard_status_rows = read_csv(run_dir / "partial_page_hash_shard_status_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "partial_page_hash_requirement_rows.csv")}
metric = read_csv(run_dir / "partial_page_hash_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
materialization_rows = read_csv(run_dir / "source_v61t/local_checkpoint_materialization_rows.csv")
unique_page_rows = read_csv(run_dir / "source_v61q/checkpoint_unique_page_rows.csv")

identity_rows = [
    row
    for row in materialization_rows
    if row["local_identity_verified"] == "1" and row["local_file_exists"] == "1"
]
identity_shards = {row["shard_name"] for row in identity_rows}
identity_bytes = sum(int(row["actual_bytes"]) for row in identity_rows)
identity_page_rows = [row for row in unique_page_rows if row["shard_name"] in identity_shards]
identity_page_count = len(identity_page_rows)
identity_page_bytes = sum(int(row["page_bytes_in_shard"]) for row in identity_page_rows)
hashed_page_count = len(page_rows)
hashed_page_bytes = sum(int(row["bytes_read"]) for row in page_rows if row["page_hash_verified"] == "1")
partial_ready = "1" if identity_shards and hashed_page_count == identity_page_count and hashed_page_bytes == identity_page_bytes else "0"
full_ready = "1" if partial_ready == "1" and hashed_page_count == 134161 and len(identity_shards) == 59 else "0"

dynamic_expected = {
    "local_identity_verified_shard_rows": str(len(identity_shards)),
    "local_identity_verified_bytes": str(identity_bytes),
    "identity_shard_page_rows": str(identity_page_count),
    "identity_shard_page_bytes": str(identity_page_bytes),
    "page_hash_witness_rows": str(hashed_page_count),
    "page_hash_witness_bytes": str(hashed_page_bytes),
    "partial_full_shard_page_hash_ready": partial_ready,
    "full_safetensors_page_hash_binding_ready": full_ready,
    "observed_external_checkpoint_payload_bytes": str(identity_bytes),
}
for field, value in dynamic_expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bw {field}: expected {value}, got {summary.get(field)}")
    if metric.get(field) != value:
        raise SystemExit(f"v61bw metric {field}: expected {value}, got {metric.get(field)}")

if page_rows:
    if any(row["target_path"].startswith(ubuntu1_target) is False for row in page_rows):
        raise SystemExit("v61bw page witness rows must target ubuntu-1")
    if any(row["page_hash_verified"] != "1" for row in page_rows):
        raise SystemExit("v61bw all emitted page rows must verify")
    if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in page_rows):
        raise SystemExit("v61bw page rows must keep repo payload bytes at zero")
    if {row["shard_name"] for row in page_rows} != identity_shards:
        raise SystemExit("v61bw page rows must cover exactly identity shards")

for status in shard_status_rows:
    if status["shard_name"] == "none":
        continue
    if status["checkpoint_payload_bytes_downloaded_by_v61bw"] != "0" or status["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bw shard status rows must keep payload counters at zero")
    if status["partial_full_shard_page_hash_ready"] != partial_ready:
        raise SystemExit("v61bw shard partial readiness mismatch")

for requirement_id in ["v61bu-partial-materialization-input", "v61q-page-map-input", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bw requirement should pass: {requirement_id}")
if requirements["identity-verified-local-shard"]["status"] != ("pass" if identity_shards else "blocked"):
    raise SystemExit("v61bw identity requirement status mismatch")
if requirements["partial-full-shard-page-hash-witness"]["status"] != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bw partial page-hash requirement status mismatch")
for requirement_id in ["full-safetensors-page-hash-coverage", "actual-model-generation"]:
    if requirements[requirement_id]["status"] != ("pass" if requirement_id == "full-safetensors-page-hash-coverage" and full_ready == "1" else "blocked"):
        raise SystemExit(f"v61bw requirement status mismatch: {requirement_id}")

for gate in ["v61bu-partial-materialization-input", "v61q-page-map-input", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bw gate should pass: {gate}")
if decisions["identity-verified-local-shard"] != ("pass" if identity_shards else "blocked"):
    raise SystemExit("v61bw identity gate status mismatch")
if decisions["partial-full-shard-page-hash-witness"] != ("pass" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bw partial page-hash gate status mismatch")
if decisions["full-safetensors-page-hash-binding"] != ("pass" if full_ready == "1" else "blocked"):
    raise SystemExit("v61bw full page-hash gate status mismatch")
for gate in ["actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bw gate should stay blocked: {gate}")

if gaps["partial-full-shard-page-hash-witness"] != ("ready" if partial_ready == "1" else "blocked"):
    raise SystemExit("v61bw partial page-hash gap status mismatch")
for gap in ["full-safetensors-page-hash-binding", "actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != ("ready" if gap == "full-safetensors-page-hash-binding" and full_ready == "1" else "blocked"):
        raise SystemExit(f"v61bw gap status mismatch: {gap}")

if page_rows:
    sample_rows = [page_rows[0], page_rows[-1]]
    for row in sample_rows:
        path = Path(row["target_path"])
        start = int(row["page_start_byte"])
        length = int(row["page_bytes_in_shard"])
        with path.open("rb") as handle:
            handle.seek(start)
            data = handle.read(length)
        if len(data) != length:
            raise SystemExit("v61bw sample page read length mismatch")
        if sha256_bytes(data) != row["local_page_sha256"]:
            raise SystemExit("v61bw sample page hash mismatch")

boundary = (run_dir / "V61BW_UBUNTU1_PARTIAL_PAGE_HASH_WITNESS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"local_identity_verified_shard_rows={len(identity_shards)}",
    f"identity_shard_page_rows={identity_page_count}",
    f"page_hash_witness_rows={hashed_page_count}",
    f"partial_full_shard_page_hash_ready={partial_ready}",
    f"full_safetensors_page_hash_binding_ready={full_ready}",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bw=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bw boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bw_ubuntu1_partial_page_hash_witness_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bw_ubuntu1_partial_page_hash_witness_ready") != 1:
    raise SystemExit("v61bw manifest readiness mismatch")
if manifest.get("page_hash_witness_rows") != hashed_page_count:
    raise SystemExit("v61bw manifest page count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bw") != 0:
    raise SystemExit("v61bw manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bw sha256 mismatch: {rel}")
PY

echo "v61bw ubuntu-1 partial page-hash witness smoke passed"
