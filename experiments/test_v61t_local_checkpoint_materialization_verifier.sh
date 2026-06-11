#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61t_local_checkpoint_materialization_verifier/verify_001"
SUMMARY_CSV="$RESULTS_DIR/v61t_local_checkpoint_materialization_verifier_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61t_local_checkpoint_materialization_verifier_decision.csv"

V61T_REUSE_EXISTING="${V61T_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null

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
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_expected": "281241493344",
    "ssd_warehouse_outside_repo": "1",
    "local_existing_shard_rows": "0",
    "local_size_match_shard_rows": "0",
    "local_header_hash_match_shard_rows": "0",
    "sampled_remote_page_hash_probe_rows": "3",
    "sampled_local_page_probe_rows": "3",
    "sampled_local_page_probe_attempted_rows": "0",
    "sampled_local_page_probe_match_rows": "0",
    "local_identity_verified_shard_rows": "0",
    "local_identity_verified_bytes": "0",
    "full_page_hash_coverage_ready_shard_rows": "0",
    "full_page_hash_verified_rows": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
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
        raise SystemExit(f"v61t {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "local_checkpoint_materialization_rows.csv",
    "sampled_local_page_hash_verification_rows.csv",
    "local_checkpoint_materialization_metric_rows.csv",
    "materialization_gap_rows.csv",
    "V61T_LOCAL_CHECKPOINT_MATERIALIZATION_VERIFIER_BOUNDARY.md",
    "v61t_local_checkpoint_materialization_verifier_manifest.json",
    "sha256_manifest.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv",
    "source_v61p/ssd_warehouse_probe_rows.csv",
    "source_v61p/ssd_disk_budget_rows.csv",
    "source_v61p/checkpoint_residency_requirement_rows.csv",
    "source_v61p/checkpoint_download_plan_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
    "source_v61p/sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_decision.csv",
    "source_v61r/page_hash_sweep_metric_rows.csv",
    "source_v61r/shard_page_hash_sweep_status_rows.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_manifest.json",
    "source_v61r/sha256_manifest.csv",
    "source_v61o/safetensors_header_probe_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61t artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61p-local-ssd-residency-preflight-input",
    "v61q-real-checkpoint-page-map-input",
    "v61r-full-page-hash-sweep-plan-input",
    "warehouse-outside-repository",
    "materialization-identity-verifier",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61t gate should pass: {gate}")
for gate in [
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61t gate should remain blocked: {gate}")

materialization_rows = read_csv(run_dir / "local_checkpoint_materialization_rows.csv")
sample_rows = read_csv(run_dir / "sampled_local_page_hash_verification_rows.csv")
metric = read_csv(run_dir / "local_checkpoint_materialization_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "materialization_gap_rows.csv")}
if len(materialization_rows) != 59 or len(sample_rows) != 3:
    raise SystemExit("v61t artifact row counts mismatch")
if metric["local_checkpoint_materialization_ready"] != "0" or metric["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61t metric readiness boundary mismatch")
for row in materialization_rows:
    if row["local_file_exists"] != "0" or row["local_identity_verified"] != "0":
        raise SystemExit("v61t should not verify absent local shards")
    if row["materialization_status"] != "missing-local-shard":
        raise SystemExit("v61t missing shard status mismatch")
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61t must never commit checkpoint payload bytes")
for row in sample_rows:
    if row["local_file_exists"] != "0" or row["bytes_read"] != "0" or row["sampled_page_hash_match"] != "0":
        raise SystemExit("v61t sampled local probes should remain unverified on this host")
for gap in [
    "local-shard-size-identity",
    "local-header-hash-binding",
    "sampled-local-page-hash-binding",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61t gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61t_local_checkpoint_materialization_verifier_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61t_local_checkpoint_materialization_verifier_ready") != 1:
    raise SystemExit("v61t manifest readiness mismatch")
if manifest.get("local_checkpoint_materialization_ready") != 0 or manifest.get("real_100b_open_weight_materialized") != 0:
    raise SystemExit("v61t manifest materialization boundary mismatch")

boundary = (run_dir / "V61T_LOCAL_CHECKPOINT_MATERIALIZATION_VERIFIER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "local checkpoint materialization identity verifier",
    "local_existing_shard_rows=0",
    "local_identity_verified_shard_rows=0",
    "local_checkpoint_materialization_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61t boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61t sha256 mismatch: {rel}")
PY

echo "v61t local checkpoint materialization verifier smoke passed"
