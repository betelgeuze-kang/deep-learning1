#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61m_kv_cache_residency_eviction_policy"
RUN_ID="${V61M_RUN_ID:-kv_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61M_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61m_kv_cache_residency_eviction_policy_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61k_real_model_page_manifest_summary.csv" \
  || ! -s "$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001/real_model_config_rows.csv" \
  || ! -s "$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001/tensor_page_manifest_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61k_real_model_page_manifest.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement_summary.csv" \
  || ! -s "$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement/gpu_001/gpu_page_dequant_matmul_rows.csv" \
  || ! -s "$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement/gpu_001/V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md" ]]; then
  "$ROOT_DIR/experiments/run_v61l_gpu_page_dequant_matmul_measurement.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61k_dir = results / "v61k_real_model_page_manifest" / "manifest_001"
v61l_dir = results / "v61l_gpu_page_dequant_matmul_measurement" / "gpu_001"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def ceil_div(a, b):
    return (a + b - 1) // b


v61k_summary = read_csv(results / "v61k_real_model_page_manifest_summary.csv")[0]
v61l_summary = read_csv(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv")[0]
if v61k_summary.get("v61k_real_model_page_manifest_ready") != "1":
    raise SystemExit("v61m requires v61k_real_model_page_manifest_ready=1")
if v61l_summary.get("v61l_gpu_page_dequant_matmul_measurement_ready") != "1":
    raise SystemExit("v61m requires v61l_gpu_page_dequant_matmul_measurement_ready=1")

for rel in [
    "real_model_identity_rows.csv",
    "real_model_config_rows.csv",
    "checkpoint_shard_manifest_rows.csv",
    "tensor_page_manifest_rows.csv",
    "expert_page_budget_rows.csv",
    "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "v61k_real_model_page_manifest_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61k_dir / rel, f"source_v61k/{rel}")
copy(results / "v61k_real_model_page_manifest_summary.csv", "source_v61k/v61k_real_model_page_manifest_summary.csv")

for rel in [
    "gpu_page_dequant_matmul_rows.csv",
    "real_model_manifest_binding_rows.csv",
    "runtime_gap_rows.csv",
    "V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    "v61l_gpu_page_dequant_matmul_measurement_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61l_dir / rel, f"source_v61l/{rel}")
copy(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv")

config = read_csv(v61k_dir / "real_model_config_rows.csv")[0]
model_id = config["model_id"]
hidden_size = int(config["hidden_size"])
num_attention_heads = int(config["num_attention_heads"])
num_key_value_heads = int(config["num_key_value_heads"])
num_hidden_layers = int(config["num_hidden_layers"])
max_position_embeddings = int(config["max_position_embeddings"])
head_dim = hidden_size // num_attention_heads
kv_dtype = os.environ.get("V61M_KV_DTYPE", "bf16")
kv_bytes_per_element = int(os.environ.get("V61M_KV_BYTES_PER_ELEMENT", "2"))
kv_tensors_per_layer = 2
kv_bytes_per_token_per_layer = kv_tensors_per_layer * num_key_value_heads * head_dim * kv_bytes_per_element
kv_bytes_per_token = num_hidden_layers * kv_bytes_per_token_per_layer
page_size_bytes = int(v61k_summary["page_size_bytes"])
kv_tokens_per_page = max(1, page_size_bytes // kv_bytes_per_token)
kv_page_payload_bytes = kv_tokens_per_page * kv_bytes_per_token
kv_page_unused_bytes = page_size_bytes - kv_page_payload_bytes

hot_window_tokens = int(os.environ.get("V61M_HOT_WINDOW_TOKENS", "1024"))
sink_tokens = int(os.environ.get("V61M_SINK_TOKENS", "128"))
vram_kv_budget_bytes = int(os.environ.get("V61M_VRAM_KV_BUDGET_BYTES", str(384 * 1024 * 1024)))
context_lengths = [int(x) for x in os.environ.get("V61M_CONTEXT_TOKENS", "512,1024,2048,4096,8192").split(",") if x]
if not context_lengths:
    raise SystemExit("v61m requires at least one context length")

hot_window_pages = ceil_div(hot_window_tokens, kv_tokens_per_page)
sink_pages = ceil_div(sink_tokens, kv_tokens_per_page)
vram_page_budget = vram_kv_budget_bytes // page_size_bytes
required_policy_pages = hot_window_pages + sink_pages
if required_policy_pages > vram_page_budget:
    raise SystemExit("v61m default policy does not fit inside the VRAM KV budget")

geometry_rows = [
    {
        "model_id": model_id,
        "hidden_size": str(hidden_size),
        "num_attention_heads": str(num_attention_heads),
        "num_key_value_heads": str(num_key_value_heads),
        "head_dim": str(head_dim),
        "num_hidden_layers": str(num_hidden_layers),
        "kv_dtype": kv_dtype,
        "kv_bytes_per_element": str(kv_bytes_per_element),
        "kv_tensors_per_layer": str(kv_tensors_per_layer),
        "kv_bytes_per_token_per_layer": str(kv_bytes_per_token_per_layer),
        "kv_bytes_per_token": str(kv_bytes_per_token),
        "page_size_bytes": str(page_size_bytes),
        "kv_tokens_per_page": str(kv_tokens_per_page),
        "kv_page_payload_bytes": str(kv_page_payload_bytes),
        "kv_page_unused_bytes": str(kv_page_unused_bytes),
        "max_position_embeddings": str(max_position_embeddings),
        "geometry_ready": "1",
    }
]
write_csv(run_dir / "kv_cache_geometry_rows.csv", list(geometry_rows[0].keys()), geometry_rows)

policy_rows = [
    {
        "policy_id": "v61m_mixtral_kv_vram_hot_nvme_cold_001",
        "model_id": model_id,
        "policy_scope": "kv-cache-residency-eviction",
        "resident_tiers": "vram_hot,nvme_cold",
        "host_ram_kv_spill_enabled": "0",
        "hot_window_tokens": str(hot_window_tokens),
        "hot_window_pages": str(hot_window_pages),
        "sink_tokens": str(sink_tokens),
        "sink_pages": str(sink_pages),
        "vram_kv_budget_bytes": str(vram_kv_budget_bytes),
        "vram_page_budget": str(vram_page_budget),
        "required_policy_pages": str(required_policy_pages),
        "required_policy_bytes": str(required_policy_pages * page_size_bytes),
        "budget_pass": str(int(required_policy_pages <= vram_page_budget)),
        "eviction_policy": "deterministic-sink-plus-sliding-hot-window-lru",
        "cold_tier": "nvme-page-spill",
        "deterministic_replay_ready": "1",
        "kv_cache_policy_ready": "1",
        "long_context_quality_claim_ready": "0",
    }
]
write_csv(run_dir / "kv_residency_policy_rows.csv", list(policy_rows[0].keys()), policy_rows)

budget_rows = []
trace_rows = []
eviction_rows = []
for context_tokens in context_lengths:
    if context_tokens <= 0:
        raise SystemExit("v61m context lengths must be positive")
    total_pages = ceil_div(context_tokens, kv_tokens_per_page)
    sink_page_ids = set(range(min(sink_pages, total_pages)))
    hot_page_start = max(0, total_pages - hot_window_pages)
    hot_page_ids = set(range(hot_page_start, total_pages))
    resident_page_ids = sink_page_ids | hot_page_ids
    resident_pages = len(resident_page_ids)
    evicted_pages = total_pages - resident_pages
    total_kv_bytes = context_tokens * kv_bytes_per_token
    total_kv_page_bytes = total_pages * page_size_bytes
    resident_vram_bytes = resident_pages * page_size_bytes
    evicted_nvme_bytes = evicted_pages * page_size_bytes
    budget_rows.append(
        {
            "profile_id": f"context_{context_tokens}",
            "context_tokens": str(context_tokens),
            "total_kv_bytes": str(total_kv_bytes),
            "total_kv_pages": str(total_pages),
            "total_kv_page_bytes": str(total_kv_page_bytes),
            "resident_vram_pages": str(resident_pages),
            "resident_vram_bytes": str(resident_vram_bytes),
            "evicted_nvme_pages": str(evicted_pages),
            "evicted_nvme_bytes": str(evicted_nvme_bytes),
            "host_ram_spill_bytes": "0",
            "vram_kv_budget_bytes": str(vram_kv_budget_bytes),
            "vram_budget_pass": str(int(resident_vram_bytes <= vram_kv_budget_bytes)),
            "full_kv_vram_budget_pass": str(int(total_kv_page_bytes <= vram_kv_budget_bytes)),
            "nvme_eviction_required": str(int(evicted_pages > 0)),
        }
    )
    for page_id in range(total_pages):
        token_start = page_id * kv_tokens_per_page
        token_end = min(context_tokens, token_start + kv_tokens_per_page)
        if page_id in sink_page_ids:
            tier = "vram_sink"
            evict_after_token = ""
        elif page_id in hot_page_ids:
            tier = "vram_hot"
            evict_after_token = ""
        else:
            tier = "nvme_cold"
            evict_after_token = str(max(0, token_end + hot_window_tokens))
            eviction_rows.append(
                {
                    "profile_id": f"context_{context_tokens}",
                    "context_tokens": str(context_tokens),
                    "page_id": str(page_id),
                    "from_tier": "vram_hot",
                    "to_tier": "nvme_cold",
                    "evict_after_token": evict_after_token,
                    "page_size_bytes": str(page_size_bytes),
                    "host_ram_spill_bytes": "0",
                }
            )
        trace_rows.append(
            {
                "profile_id": f"context_{context_tokens}",
                "context_tokens": str(context_tokens),
                "page_id": str(page_id),
                "token_start": str(token_start),
                "token_end_exclusive": str(token_end),
                "kv_tokens_in_page": str(token_end - token_start),
                "residency_tier": tier,
                "resident_in_vram": str(int(tier.startswith("vram"))),
                "prefetch_required_for_exact_attention": str(int(tier == "nvme_cold")),
                "page_size_bytes": str(page_size_bytes),
                "kv_payload_bytes": str((token_end - token_start) * kv_bytes_per_token),
                "host_ram_spill_bytes": "0",
            }
        )

write_csv(run_dir / "kv_budget_profile_rows.csv", list(budget_rows[0].keys()), budget_rows)
write_csv(run_dir / "kv_eviction_trace_rows.csv", list(trace_rows[0].keys()), trace_rows)
write_csv(run_dir / "kv_eviction_event_rows.csv", list(eviction_rows[0].keys()), eviction_rows)

gap_rows = [
    ("real-checkpoint-weight-materialization", "blocked", "v61m consumes v61k/v61l metadata and synthetic kernel evidence; no checkpoint weights are materialized"),
    ("safetensors-page-hash-binding", "blocked", "local safetensors shard/header/page hash intake is still missing"),
    ("source-bound-qa-workload", "blocked", "source-bound code/doc QA is not yet routed through v61j with this KV policy"),
    ("long-context-quality", "blocked", "the policy emits residency/eviction rows, not answer-quality or exact long-context replay evidence"),
    ("production-latency", "blocked", "KV policy rows are not an end-to-end decode latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

max_budget = max(budget_rows, key=lambda row: int(row["context_tokens"]))
vram_budget_pass_all = int(all(row["vram_budget_pass"] == "1" for row in budget_rows))
full_kv_vram_budget_pass_all = int(all(row["full_kv_vram_budget_pass"] == "1" for row in budget_rows))
eviction_required_rows = sum(1 for row in budget_rows if row["nvme_eviction_required"] == "1")
summary = {
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "v61k_real_model_page_manifest_ready": v61k_summary["v61k_real_model_page_manifest_ready"],
    "v61l_gpu_page_dequant_matmul_measurement_ready": v61l_summary["v61l_gpu_page_dequant_matmul_measurement_ready"],
    "model_id": model_id,
    "source_model_license": v61k_summary["source_model_license"],
    "kv_bytes_per_token": str(kv_bytes_per_token),
    "kv_tokens_per_page": str(kv_tokens_per_page),
    "kv_page_payload_bytes": str(kv_page_payload_bytes),
    "hot_window_tokens": str(hot_window_tokens),
    "sink_tokens": str(sink_tokens),
    "vram_kv_budget_bytes": str(vram_kv_budget_bytes),
    "required_policy_pages": str(required_policy_pages),
    "required_policy_bytes": str(required_policy_pages * page_size_bytes),
    "max_context_tokens": max_budget["context_tokens"],
    "max_total_kv_bytes": max_budget["total_kv_bytes"],
    "max_total_kv_pages": max_budget["total_kv_pages"],
    "max_resident_vram_pages": max_budget["resident_vram_pages"],
    "max_resident_vram_bytes": max_budget["resident_vram_bytes"],
    "max_evicted_nvme_pages": max_budget["evicted_nvme_pages"],
    "max_evicted_nvme_bytes": max_budget["evicted_nvme_bytes"],
    "sequence_profile_rows": str(len(budget_rows)),
    "kv_eviction_trace_rows": str(len(trace_rows)),
    "kv_eviction_event_rows": str(len(eviction_rows)),
    "eviction_required_profile_rows": str(eviction_required_rows),
    "vram_budget_pass_all_profiles": str(vram_budget_pass_all),
    "full_kv_vram_budget_pass_all_profiles": str(full_kv_vram_budget_pass_all),
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
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61k-real-model-page-manifest-input", "pass", "v61m binds the Mixtral 8x22B v61k page manifest"),
    ("v61l-gpu-page-kernel-input", "pass", "v61m records that the v61l page-kernel timing seed is present"),
    ("kv-cache-geometry", "pass", f"kv_bytes_per_token={kv_bytes_per_token}; kv_tokens_per_page={kv_tokens_per_page}"),
    ("kv-residency-policy", "pass", "VRAM hot/sink policy fits the configured KV budget"),
    ("kv-eviction-replay", "pass", "deterministic page-level eviction trace is emitted"),
    ("no-host-ram-kv-spill", "pass", "policy uses VRAM hot tier and NVMe cold tier with host_ram_spill_bytes=0"),
    ("real-checkpoint-weight-materialization", "blocked", "no checkpoint weights materialized"),
    ("safetensors-page-hash-binding", "blocked", "local shard/header/page hashes are not bound"),
    ("source-bound-qa", "blocked", "no source-bound QA workload consumes v61m yet"),
    ("long-context-quality", "blocked", "KV policy is not answer-quality or full exact-attention replay evidence"),
    ("production-latency", "blocked", "not an end-to-end decode latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md").write_text(
    "# v61m KV Cache Residency Eviction Boundary\n\n"
    "This layer adds a deterministic KV-cache residency and eviction policy bound to the v61k Mixtral 8x22B config and the v61l page-kernel evidence. "
    "It computes Mixtral KV geometry, keeps a VRAM sink plus sliding hot window, and spills older KV pages to an NVMe cold tier. It does not use a host-RAM KV spill tier.\n\n"
    f"- model_id={model_id}\n"
    f"- kv_bytes_per_token={kv_bytes_per_token}\n"
    f"- kv_tokens_per_page={kv_tokens_per_page}\n"
    f"- hot_window_tokens={hot_window_tokens}\n"
    f"- sink_tokens={sink_tokens}\n"
    f"- vram_kv_budget_bytes={vram_kv_budget_bytes}\n"
    f"- max_context_tokens={summary['max_context_tokens']}\n"
    f"- max_resident_vram_bytes={summary['max_resident_vram_bytes']}\n"
    f"- max_evicted_nvme_bytes={summary['max_evicted_nvme_bytes']}\n"
    "- host_ram_kv_spill_enabled=0\n"
    "- kv_cache_policy_ready=1\n"
    "- source_bound_qa_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: KV-cache residency/eviction policy over Mixtral page geometry with deterministic NVMe cold-tier trace. "
    "Blocked wording: source-bound QA runtime, exact long-context quality, production latency, near-frontier local inference, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61m-kv-cache-residency-eviction-policy",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61m_kv_cache_residency_eviction_policy_ready": 1,
    "v61k_summary_sha256": sha256(results / "v61k_real_model_page_manifest_summary.csv"),
    "v61l_summary_sha256": sha256(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    "model_id": model_id,
    "kv_bytes_per_token": kv_bytes_per_token,
    "kv_tokens_per_page": kv_tokens_per_page,
    "hot_window_tokens": hot_window_tokens,
    "sink_tokens": sink_tokens,
    "vram_kv_budget_bytes": vram_kv_budget_bytes,
    "max_context_tokens": int(summary["max_context_tokens"]),
    "max_resident_vram_bytes": int(summary["max_resident_vram_bytes"]),
    "max_evicted_nvme_bytes": int(summary["max_evicted_nvme_bytes"]),
    "host_ram_kv_spill_enabled": 0,
    "source_bound_qa_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61m_kv_cache_residency_eviction_policy_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "kv_cache_geometry_rows.csv",
    "kv_residency_policy_rows.csv",
    "kv_budget_profile_rows.csv",
    "kv_eviction_trace_rows.csv",
    "kv_eviction_event_rows.csv",
    "runtime_gap_rows.csv",
    "V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md",
    "v61m_kv_cache_residency_eviction_policy_manifest.json",
    "source_v61k/real_model_identity_rows.csv",
    "source_v61k/real_model_config_rows.csv",
    "source_v61k/checkpoint_shard_manifest_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/expert_page_budget_rows.csv",
    "source_v61k/V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "source_v61k/v61k_real_model_page_manifest_manifest.json",
    "source_v61k/sha256_manifest.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
    "source_v61l/gpu_page_dequant_matmul_rows.csv",
    "source_v61l/real_model_manifest_binding_rows.csv",
    "source_v61l/runtime_gap_rows.csv",
    "source_v61l/V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    "source_v61l/v61l_gpu_page_dequant_matmul_measurement_manifest.json",
    "source_v61l/sha256_manifest.csv",
    "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61m_kv_cache_residency_eviction_policy_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
