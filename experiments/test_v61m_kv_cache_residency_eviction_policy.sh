#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61m_kv_cache_residency_eviction_policy/kv_001"
SUMMARY_CSV="$RESULTS_DIR/v61m_kv_cache_residency_eviction_policy_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61m_kv_cache_residency_eviction_policy_decision.csv"

"$ROOT_DIR/experiments/run_v61m_kv_cache_residency_eviction_policy.sh" >/dev/null

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
    raise SystemExit(f"expected one v61m summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "v61k_real_model_page_manifest_ready": "1",
    "v61l_gpu_page_dequant_matmul_measurement_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_model_license": "apache-2.0",
    "kv_bytes_per_token": "229376",
    "kv_tokens_per_page": "9",
    "kv_page_payload_bytes": "2064384",
    "hot_window_tokens": "1024",
    "sink_tokens": "128",
    "vram_kv_budget_bytes": "402653184",
    "required_policy_pages": "129",
    "required_policy_bytes": "270532608",
    "max_context_tokens": "8192",
    "max_total_kv_bytes": "1879048192",
    "max_total_kv_pages": "911",
    "max_resident_vram_pages": "129",
    "max_resident_vram_bytes": "270532608",
    "max_evicted_nvme_pages": "782",
    "max_evicted_nvme_bytes": "1639972864",
    "sequence_profile_rows": "5",
    "kv_eviction_trace_rows": "1766",
    "kv_eviction_event_rows": "1208",
    "eviction_required_profile_rows": "3",
    "vram_budget_pass_all_profiles": "1",
    "full_kv_vram_budget_pass_all_profiles": "0",
    "host_ram_kv_spill_enabled": "0",
    "host_ram_spill_bytes": "0",
    "kv_cache_policy_ready": "1",
    "kv_eviction_trace_ready": "1",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "source_bound_qa_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61m {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61k-real-model-page-manifest-input",
    "v61l-gpu-page-kernel-input",
    "kv-cache-geometry",
    "kv-residency-policy",
    "kv-eviction-replay",
    "no-host-ram-kv-spill",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61m gate should pass: {gate}")
for gate in [
    "real-checkpoint-weight-materialization",
    "safetensors-page-hash-binding",
    "source-bound-qa",
    "long-context-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61m gate should remain blocked: {gate}")

required_files = [
    "kv_cache_geometry_rows.csv",
    "kv_residency_policy_rows.csv",
    "kv_budget_profile_rows.csv",
    "kv_eviction_trace_rows.csv",
    "kv_eviction_event_rows.csv",
    "runtime_gap_rows.csv",
    "V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md",
    "v61m_kv_cache_residency_eviction_policy_manifest.json",
    "sha256_manifest.csv",
    "source_v61k/real_model_config_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
    "source_v61l/gpu_page_dequant_matmul_rows.csv",
    "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61m artifact: {rel}")

geometry = read_csv(run_dir / "kv_cache_geometry_rows.csv")[0]
for field, value in {
    "hidden_size": "6144",
    "num_attention_heads": "48",
    "num_key_value_heads": "8",
    "head_dim": "128",
    "num_hidden_layers": "56",
    "kv_bytes_per_token": "229376",
    "kv_tokens_per_page": "9",
    "geometry_ready": "1",
}.items():
    if geometry.get(field) != value:
        raise SystemExit(f"v61m geometry {field}: expected {value}, got {geometry.get(field)}")

policy = read_csv(run_dir / "kv_residency_policy_rows.csv")[0]
if policy["resident_tiers"] != "vram_hot,nvme_cold" or policy["host_ram_kv_spill_enabled"] != "0":
    raise SystemExit("v61m policy should use VRAM hot plus NVMe cold, with no host RAM spill")
if policy["budget_pass"] != "1" or policy["kv_cache_policy_ready"] != "1":
    raise SystemExit("v61m policy should fit the configured KV budget")

budget_rows = read_csv(run_dir / "kv_budget_profile_rows.csv")
if len(budget_rows) != 5:
    raise SystemExit("v61m should emit five KV budget profiles")
budget_by_context = {row["context_tokens"]: row for row in budget_rows}
if budget_by_context["8192"]["resident_vram_pages"] != "129":
    raise SystemExit("v61m 8192-token resident page count mismatch")
if budget_by_context["8192"]["evicted_nvme_pages"] != "782":
    raise SystemExit("v61m 8192-token evicted page count mismatch")
if budget_by_context["8192"]["vram_budget_pass"] != "1":
    raise SystemExit("v61m resident KV pages should stay within budget")
if budget_by_context["8192"]["full_kv_vram_budget_pass"] != "0":
    raise SystemExit("v61m full KV cache should not fit the configured VRAM budget")
if any(row["host_ram_spill_bytes"] != "0" for row in budget_rows):
    raise SystemExit("v61m should not use host RAM spill bytes")

trace_rows = read_csv(run_dir / "kv_eviction_trace_rows.csv")
if len(trace_rows) != 1766:
    raise SystemExit(f"v61m eviction trace row count mismatch: {len(trace_rows)}")
tiers = {row["residency_tier"] for row in trace_rows}
if not {"vram_sink", "vram_hot", "nvme_cold"}.issubset(tiers):
    raise SystemExit("v61m trace should include sink, hot, and NVMe cold tiers")
if any(row["host_ram_spill_bytes"] != "0" for row in trace_rows):
    raise SystemExit("v61m trace should not use host RAM spill bytes")

event_rows = read_csv(run_dir / "kv_eviction_event_rows.csv")
if len(event_rows) != 1208:
    raise SystemExit(f"v61m eviction event row count mismatch: {len(event_rows)}")
if any(row["to_tier"] != "nvme_cold" for row in event_rows):
    raise SystemExit("v61m eviction events should spill to NVMe cold tier")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in [
    "real-checkpoint-weight-materialization",
    "safetensors-page-hash-binding",
    "source-bound-qa-workload",
    "long-context-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61m gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61m_kv_cache_residency_eviction_policy_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61m_kv_cache_residency_eviction_policy_ready") != 1:
    raise SystemExit("v61m manifest readiness mismatch")
if manifest.get("host_ram_kv_spill_enabled") != 0:
    raise SystemExit("v61m manifest should keep host RAM KV spill disabled")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61m sha256 mismatch: {rel}")

boundary = (run_dir / "V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "KV-cache residency and eviction policy",
    "host_ram_kv_spill_enabled=0",
    "kv_cache_policy_ready=1",
    "source_bound_qa_ready=0",
    "Allowed wording: KV-cache residency/eviction policy",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61m boundary missing {snippet}")
PY

echo "v61m KV cache residency eviction policy smoke passed"
