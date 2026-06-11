#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61u_remote_checkpoint_page_hash_sampler/sample_001"
SUMMARY_CSV="$RESULTS_DIR/v61u_remote_checkpoint_page_hash_sampler_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61u_remote_checkpoint_page_hash_sampler_decision.csv"

V61U_REUSE_EXISTING="${V61U_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61u_remote_checkpoint_page_hash_sampler.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v61u_remote_checkpoint_page_hash_sampler_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_unique_page_rows": "134161",
    "remote_page_hash_sample_plan_rows": "16",
    "remote_page_hash_sample_rows": "16",
    "remote_page_hash_sample_ready_rows": "16",
    "remote_page_payload_bytes_read": "33554432",
    "prior_v61o_sampled_page_hash_probe_rows": "3",
    "full_safetensors_page_hash_binding_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "checkpoint_payload_bytes_persisted": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
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
        raise SystemExit(f"v61u {field}: expected {value}, got {summary.get(field)}")
if int(summary["remote_page_hash_sample_unique_shards"]) < 8:
    raise SystemExit("v61u should sample across multiple checkpoint shards")

required_files = [
    "remote_page_hash_sample_plan_rows.csv",
    "remote_page_hash_sample_rows.csv",
    "remote_page_hash_page_map_overlap_rows.csv",
    "remote_page_hash_sample_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61U_REMOTE_CHECKPOINT_PAGE_HASH_SAMPLER_BOUNDARY.md",
    "v61u_remote_checkpoint_page_hash_sampler_manifest.json",
    "sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61q/checkpoint_page_map_metric_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_manifest.json",
    "source_v61t/sha256_manifest.csv",
    "source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61u artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61q-real-checkpoint-page-map-input",
    "v61t-local-materialization-verifier-input",
    "remote-page-hash-sample-plan",
    "remote-page-hash-sample",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61u gate should pass: {gate}")
for gate in [
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61u gate should remain blocked: {gate}")

plan_rows = read_csv(run_dir / "remote_page_hash_sample_plan_rows.csv")
sample_rows = read_csv(run_dir / "remote_page_hash_sample_rows.csv")
overlap_rows = read_csv(run_dir / "remote_page_hash_page_map_overlap_rows.csv")
metric = read_csv(run_dir / "remote_page_hash_sample_metric_rows.csv")[0]
if len(plan_rows) != 16 or len(sample_rows) != 16 or len(overlap_rows) != 16:
    raise SystemExit("v61u artifact row counts mismatch")
if metric["remote_page_payload_bytes_read"] != "33554432" or metric["full_safetensors_page_hash_binding_ready"] != "0":
    raise SystemExit("v61u metric readiness boundary mismatch")
seen_pages = set()
seen_hashes = set()
for plan, sample, overlap in zip(plan_rows, sample_rows, overlap_rows):
    if plan["remote_sample_id"] != sample["remote_sample_id"] or sample["remote_sample_id"] != overlap["remote_sample_id"]:
        raise SystemExit("v61u sample ID binding mismatch")
    if plan["source_page_id"] != sample["source_page_id"] or sample["source_page_id"] != overlap["source_page_id"]:
        raise SystemExit("v61u source page binding mismatch")
    if sample["remote_page_hash_sample_ready"] != "1" or overlap["v61q_page_map_overlap_ready"] != "1":
        raise SystemExit("v61u remote page samples should be ready")
    if int(sample["remote_page_bytes_read"]) != 2097152:
        raise SystemExit("v61u remote page samples should read one full 2 MiB page")
    if sample["checkpoint_payload_bytes_persisted"] != "0" or sample["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61u must not persist or commit checkpoint payload bytes")
    if not sample["remote_page_sha256"].startswith("sha256:"):
        raise SystemExit("v61u sample hash format mismatch")
    seen_pages.add(sample["source_page_id"])
    seen_hashes.add(sample["remote_page_sha256"])
if len(seen_pages) != 16 or len(seen_hashes) < 8:
    raise SystemExit("v61u should sample distinct pages and varied hashes")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
if gaps.get("remote-page-hash-sample") != "ready":
    raise SystemExit("v61u remote sample gap should be ready")
for gap in [
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61u gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61u_remote_checkpoint_page_hash_sampler_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61u_remote_checkpoint_page_hash_sampler_ready") != 1:
    raise SystemExit("v61u manifest readiness mismatch")
if manifest.get("remote_page_hash_sample_rows") != 16 or manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61u manifest page-hash boundary mismatch")

boundary = (run_dir / "V61U_REMOTE_CHECKPOINT_PAGE_HASH_SAMPLER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "bounded remote checkpoint page-hash samples",
    "remote_page_hash_sample_rows=16",
    "remote_page_payload_bytes_read=33554432",
    "full_safetensors_page_hash_binding_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61u boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61u sha256 mismatch: {rel}")
PY

echo "v61u remote checkpoint page hash sampler smoke passed"
