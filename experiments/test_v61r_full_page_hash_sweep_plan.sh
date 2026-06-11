#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61r_full_page_hash_sweep_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61r_full_page_hash_sweep_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61r_full_page_hash_sweep_plan_decision.csv"

V61R_REUSE_EXISTING="${V61R_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null

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
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "checkpoint_unique_page_rows": "134161",
    "page_hash_sweep_plan_rows": "134161",
    "local_resident_page_rows": "0",
    "ready_to_hash_page_rows": "0",
    "blocked_missing_local_shard_page_rows": "134161",
    "verified_page_hash_rows": "0",
    "verified_page_hash_bytes": "0",
    "sampled_remote_page_hash_probe_rows": "3",
    "sampled_remote_page_hash_page_overlap_rows": "6",
    "local_hash_sweep_enabled": "0",
    "local_checkpoint_residency_ready": "0",
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
        raise SystemExit(f"v61r {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "page_hash_sweep_plan_rows.csv",
    "local_page_hash_verification_rows.csv",
    "sampled_remote_page_hash_binding_rows.csv",
    "shard_page_hash_sweep_status_rows.csv",
    "page_hash_sweep_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61R_FULL_PAGE_HASH_SWEEP_PLAN_BOUNDARY.md",
    "v61r_full_page_hash_sweep_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/v61q_real_checkpoint_page_map_decision.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv",
    "source_v61p/ssd_warehouse_probe_rows.csv",
    "source_v61p/checkpoint_download_plan_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
    "source_v61p/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61r artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61q-real-checkpoint-page-map-input",
    "v61p-local-ssd-residency-preflight-input",
    "full-page-hash-sweep-plan",
    "sampled-remote-page-hash-binding",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61r gate should pass: {gate}")
for gate in [
    "local-ssd-checkpoint-residency",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61r gate should remain blocked: {gate}")

plan_rows = read_csv(run_dir / "page_hash_sweep_plan_rows.csv")
verification_rows = read_csv(run_dir / "local_page_hash_verification_rows.csv")
sample_binding_rows = read_csv(run_dir / "sampled_remote_page_hash_binding_rows.csv")
shard_status_rows = read_csv(run_dir / "shard_page_hash_sweep_status_rows.csv")
metric = read_csv(run_dir / "page_hash_sweep_metric_rows.csv")[0]
if len(plan_rows) != 134161 or len(verification_rows) != 0 or len(sample_binding_rows) != 6 or len(shard_status_rows) != 59:
    raise SystemExit("v61r artifact row counts mismatch")
if metric["full_safetensors_page_hash_binding_ready"] != "0" or metric["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61r metric readiness boundary mismatch")
if sum(1 for row in plan_rows if row["task_status"] == "blocked-missing-local-shard") != 134161:
    raise SystemExit("v61r should block every page on the current host")
for row in plan_rows[:10]:
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0" or row["page_hash_verified"] != "0":
        raise SystemExit("v61r plan rows should remain metadata-only and unverified on this host")
for row in sample_binding_rows:
    if row["remote_sample_hash_binding_ready"] != "1" or row["full_page_hash_verified"] != "0":
        raise SystemExit("v61r sampled bindings should remain partial, not full coverage")
for row in shard_status_rows:
    if row["local_shard_resident"] != "0" or row["verified_page_hash_rows"] != "0":
        raise SystemExit("v61r shard status should reflect no resident local shards")

manifest = json.loads((run_dir / "v61r_full_page_hash_sweep_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61r_full_page_hash_sweep_plan_ready") != 1:
    raise SystemExit("v61r manifest readiness mismatch")
if manifest.get("page_hash_sweep_plan_rows") != 134161 or manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61r manifest page-hash boundary mismatch")

boundary = (run_dir / "V61R_FULL_PAGE_HASH_SWEEP_PLAN_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "full safetensors page-hash sweep plan",
    "page_hash_sweep_plan_rows=134161",
    "blocked_missing_local_shard_page_rows=134161",
    "full_safetensors_page_hash_binding_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61r boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61r sha256 mismatch: {rel}")
PY

echo "v61r full page hash sweep plan smoke passed"
