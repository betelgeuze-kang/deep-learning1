#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61o_checkpoint_shard_header_probe/probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61o_checkpoint_shard_header_probe_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61o_checkpoint_shard_header_probe_decision.csv"

V61O_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61o_checkpoint_shard_header_probe.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61o summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61o_checkpoint_shard_header_probe_ready": "1",
    "v61k_real_model_page_manifest_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_model_license": "apache-2.0",
    "checkpoint_index_ready": "1",
    "checkpoint_shard_http_identity_rows": "59",
    "safetensors_header_probe_rows": "59",
    "safetensors_header_probe_ready_rows": "59",
    "sampled_page_hash_probe_rows": "3",
    "sampled_page_payload_bytes_read": "6291456",
    "sampled_safetensors_page_hash_binding_ready": "1",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_weight_bytes_persisted": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61o {field}: expected {value}, got {summary.get(field)}")

if int(summary["checkpoint_index_weight_map_tensor_rows"]) < 1000:
    raise SystemExit("v61o should bind a large safetensors index tensor map")
if int(summary["safetensors_header_tensor_rows"]) != int(summary["checkpoint_index_weight_map_tensor_rows"]):
    raise SystemExit("v61o header tensor rows should match index weight-map tensor rows")
if int(summary["safetensors_header_probe_bytes_read"]) <= 59 * 8:
    raise SystemExit("v61o should read non-empty safetensors headers")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61k-real-model-page-manifest-input",
    "checkpoint-index-intake",
    "checkpoint-shard-http-identity",
    "safetensors-header-probe",
    "sampled-page-hash-probe",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61o gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "local-ssd-checkpoint-residency",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61o gate should remain blocked: {gate}")

required_files = [
    "model.safetensors.index.json",
    "checkpoint_index_rows.csv",
    "checkpoint_shard_http_identity_rows.csv",
    "safetensors_header_probe_rows.csv",
    "safetensors_header_tensor_rows.csv",
    "sampled_page_hash_probe_rows.csv",
    "runtime_gap_rows.csv",
    "V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md",
    "v61o_checkpoint_shard_header_probe_manifest.json",
    "sha256_manifest.csv",
    "source_v61k/checkpoint_shard_manifest_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61o artifact: {rel}")

index_rows = read_csv(run_dir / "checkpoint_index_rows.csv")
if len(index_rows) != 1 or index_rows[0]["index_ready"] != "1":
    raise SystemExit("v61o index row readiness mismatch")
if index_rows[0]["checkpoint_shard_rows"] != "59":
    raise SystemExit("v61o index should bind 59 shards")

http_rows = read_csv(run_dir / "checkpoint_shard_http_identity_rows.csv")
if len(http_rows) != 59:
    raise SystemExit("v61o should emit 59 HTTP identity rows")
if any(row["http_identity_ready"] != "1" for row in http_rows):
    raise SystemExit("v61o every shard HTTP identity should be ready")
if any(int(row["content_length"]) <= 0 for row in http_rows):
    raise SystemExit("v61o every shard should have positive content length")
if any(row["weight_bytes_persisted"] != "0" for row in http_rows):
    raise SystemExit("v61o should not persist shard payload bytes")

header_rows = read_csv(run_dir / "safetensors_header_probe_rows.csv")
if len(header_rows) != 59:
    raise SystemExit("v61o should emit 59 safetensors header rows")
if any(row["safetensors_header_probe_ready"] != "1" for row in header_rows):
    raise SystemExit("v61o every safetensors header probe should be ready")
if any(int(row["header_len"]) <= 0 for row in header_rows):
    raise SystemExit("v61o every safetensors header should have positive length")
if any(row["weight_payload_bytes_persisted"] != "0" for row in header_rows):
    raise SystemExit("v61o should not persist weight payload bytes")

tensor_rows = read_csv(run_dir / "safetensors_header_tensor_rows.csv")
if len(tensor_rows) != int(summary["safetensors_header_tensor_rows"]):
    raise SystemExit("v61o tensor row count mismatch")
if not any("block_sparse_moe" in row["tensor_name"] for row in tensor_rows):
    raise SystemExit("v61o should bind Mixtral MoE tensor names")
if any(row["tensor_header_bound"] != "1" for row in tensor_rows[:100]):
    raise SystemExit("v61o sampled tensor rows should be header-bound")

page_rows = read_csv(run_dir / "sampled_page_hash_probe_rows.csv")
if len(page_rows) != 3:
    raise SystemExit("v61o should emit three sampled page hash probes")
if any(row["sampled_page_hash_binding_ready"] != "1" for row in page_rows):
    raise SystemExit("v61o sampled page hash probes should be ready")
if any(row["page_payload_bytes_persisted"] != "0" for row in page_rows):
    raise SystemExit("v61o sampled page probes should not persist payload bytes")
if any(int(row["page_probe_bytes_read"]) != 2097152 for row in page_rows):
    raise SystemExit("v61o sampled page probes should read one 2 MiB page each")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "local-ssd-checkpoint-residency",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61o gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61o_checkpoint_shard_header_probe_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61o_checkpoint_shard_header_probe_ready") != 1:
    raise SystemExit("v61o manifest readiness mismatch")
if manifest.get("checkpoint_weight_bytes_persisted") != 0 or manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61o manifest should keep full checkpoint/page-hash blockers")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61o sha256 mismatch: {rel}")

boundary = (run_dir / "V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "checkpoint_shard_http_identity_rows=59",
    "safetensors_header_probe_rows=59",
    "sampled_page_hash_probe_rows=3",
    "checkpoint_weight_bytes_persisted=0",
    "Blocked wording: full local checkpoint residency",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61o boundary missing {snippet}")
PY

echo "v61o checkpoint shard header probe smoke passed"
