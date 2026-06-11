#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ad_kv_weight_token_budget_replay/replay_001"
SUMMARY_CSV="$RESULTS_DIR/v61ad_kv_weight_token_budget_replay_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ad_kv_weight_token_budget_replay_decision.csv"

V61AD_REUSE_EXISTING="${V61AD_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ad_kv_weight_token_budget_replay.sh" >/dev/null

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
    "v61ad_kv_weight_token_budget_replay_ready": "1",
    "v61ac_hotset_token_budget_replay_ready": "1",
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_bound_token_budget_rows": "37",
    "kv_context_profile_rows": "5",
    "combined_kv_weight_budget_rows": "185",
    "combined_kv_weight_budget_ready_rows": "185",
    "vram_policy_pass_rows": "185",
    "full_kv_vram_budget_pass_rows": "74",
    "nvme_eviction_required_rows": "111",
    "host_ram_spill_bytes_total": "0",
    "hot_window_tokens": "1024",
    "sink_tokens": "128",
    "kv_bytes_per_token": "229376",
    "ssd_read_bytes_per_token": "8388608",
    "weight_plus_new_kv_bytes_per_token": "8617984",
    "max_context_tokens": "8192",
    "max_kv_resident_vram_bytes": "270532608",
    "max_kv_evicted_nvme_bytes": "1639972864",
    "kv_weight_token_budget_replay_ready": "1",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ad {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "kv_weight_context_profile_rows.csv",
    "kv_weight_token_budget_rows.csv",
    "kv_weight_token_budget_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AD_KV_WEIGHT_TOKEN_BUDGET_BOUNDARY.md",
    "v61ad_kv_weight_token_budget_replay_manifest.json",
    "sha256_manifest.csv",
    "source_v61ac/hotset_token_budget_rows.csv",
    "source_v61ac/hotset_token_budget_metric_rows.csv",
    "source_v61m/kv_cache_geometry_rows.csv",
    "source_v61m/kv_budget_profile_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ad artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ac-hotset-token-budget-input",
    "v61m-kv-cache-policy-input",
    "combined-kv-weight-token-budget",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ad gate should pass: {gate}")
for gate in [
    "full-kv-vram-residency",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ad gate should stay blocked: {gate}")

profile_rows = read_csv(run_dir / "kv_weight_context_profile_rows.csv")
combined_rows = read_csv(run_dir / "kv_weight_token_budget_rows.csv")
metric = read_csv(run_dir / "kv_weight_token_budget_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(profile_rows) != 5:
    raise SystemExit("v61ad KV profile row count mismatch")
if len(combined_rows) != 185:
    raise SystemExit("v61ad combined budget row count mismatch")
if sum(1 for row in combined_rows if row["combined_kv_weight_budget_ready"] == "1") != 185:
    raise SystemExit("v61ad all combined rows should be ready")
if sum(1 for row in combined_rows if row["kv_vram_budget_pass"] == "1") != 185:
    raise SystemExit("v61ad all combined rows should pass resident KV VRAM budget")
if sum(1 for row in combined_rows if row["full_kv_vram_budget_pass"] == "1") != 74:
    raise SystemExit("v61ad full KV VRAM pass count mismatch")
if sum(1 for row in combined_rows if row["kv_nvme_eviction_required"] == "1") != 111:
    raise SystemExit("v61ad NVMe eviction-required count mismatch")
if any(row["host_ram_spill_bytes"] != "0" for row in combined_rows):
    raise SystemExit("v61ad must not use host RAM KV spill")
if any(row["ssd_read_bytes_per_token"] != "8388608" for row in combined_rows):
    raise SystemExit("v61ad SSD read bytes per token mismatch")
if any(row["kv_bytes_per_token"] != "229376" for row in combined_rows):
    raise SystemExit("v61ad KV bytes per token mismatch")
if any(row["weight_plus_new_kv_bytes_per_token"] != "8617984" for row in combined_rows):
    raise SystemExit("v61ad combined per-token bytes mismatch")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in combined_rows):
    raise SystemExit("v61ad must not commit checkpoint payload")
if any(row["actual_model_generation_ready"] != "0" for row in combined_rows):
    raise SystemExit("v61ad must keep generation blocked")
if any(row["production_latency_claim_ready"] != "0" for row in combined_rows):
    raise SystemExit("v61ad must keep production latency blocked")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ad metric {field}: expected {value}, got {metric[field]}")
for field in [
    "full_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61ad metric should keep {field}=0")

for gap in [
    "v61ac-hotset-token-budget-input",
    "v61m-kv-cache-policy-input",
    "combined-kv-weight-token-budget",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ad gap should be ready: {gap}")
for gap in [
    "full-kv-vram-residency",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ad gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ad_kv_weight_token_budget_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ad_kv_weight_token_budget_replay_ready") != 1:
    raise SystemExit("v61ad manifest readiness mismatch")
if manifest.get("combined_kv_weight_budget_rows") != 185:
    raise SystemExit("v61ad manifest row count mismatch")
if manifest.get("host_ram_spill_bytes_total") != 0:
    raise SystemExit("v61ad manifest should keep host RAM spill at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ad manifest should keep generation blocked")

boundary = (run_dir / "V61AD_KV_WEIGHT_TOKEN_BUDGET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "combined_kv_weight_budget_rows=185",
    "combined_kv_weight_budget_ready_rows=185",
    "full_kv_vram_budget_pass_rows=74",
    "nvme_eviction_required_rows=111",
    "host_ram_spill_bytes_total=0",
    "weight_plus_new_kv_bytes_per_token=8617984",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ad boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ad sha256 mismatch: {rel}")
PY

echo "v61ad KV + weight token budget replay smoke passed"
