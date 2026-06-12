#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bh_ubuntu1_kv_weight_token_budget_replay"
RUN_ID="${V61BH_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bh_ubuntu1_kv_weight_token_budget_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bg_ubuntu1_token_budget_replay.sh" >/dev/null
V61M_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61m_kv_cache_residency_eviction_policy.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def fmt(value):
    if math.isfinite(value):
        return f"{value:.9g}"
    return str(value)


v61bg_dir = results / "v61bg_ubuntu1_token_budget_replay" / "replay_001"
v61m_dir = results / "v61m_kv_cache_residency_eviction_policy" / "kv_001"
v61bg_summary = read_csv(results / "v61bg_ubuntu1_token_budget_replay_summary.csv")[0]
v61m_summary = read_csv(results / "v61m_kv_cache_residency_eviction_policy_summary.csv")[0]
if v61bg_summary.get("v61bg_ubuntu1_token_budget_replay_ready") != "1":
    raise SystemExit("v61bh requires v61bg_ubuntu1_token_budget_replay_ready=1")
if v61m_summary.get("kv_cache_policy_ready") != "1":
    raise SystemExit("v61bh requires kv_cache_policy_ready=1")
if v61m_summary.get("host_ram_kv_spill_enabled") != "0":
    raise SystemExit("v61bh requires host RAM KV spill disabled")

selected_target_path = v61bg_summary["selected_target_path"]
ubuntu1_hotset_root = v61bg_summary["ubuntu1_hotset_root"]

for src, rel in [
    (results / "v61bg_ubuntu1_token_budget_replay_summary.csv", "source_v61bg/v61bg_ubuntu1_token_budget_replay_summary.csv"),
    (results / "v61bg_ubuntu1_token_budget_replay_decision.csv", "source_v61bg/v61bg_ubuntu1_token_budget_replay_decision.csv"),
    (v61bg_dir / "ubuntu1_token_budget_rows.csv", "source_v61bg/ubuntu1_token_budget_rows.csv"),
    (v61bg_dir / "ubuntu1_token_budget_metric_rows.csv", "source_v61bg/ubuntu1_token_budget_metric_rows.csv"),
    (v61bg_dir / "runtime_gap_rows.csv", "source_v61bg/runtime_gap_rows.csv"),
    (v61bg_dir / "sha256_manifest.csv", "source_v61bg/sha256_manifest.csv"),
    (results / "v61m_kv_cache_residency_eviction_policy_summary.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv"),
    (results / "v61m_kv_cache_residency_eviction_policy_decision.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_decision.csv"),
    (v61m_dir / "kv_cache_geometry_rows.csv", "source_v61m/kv_cache_geometry_rows.csv"),
    (v61m_dir / "kv_residency_policy_rows.csv", "source_v61m/kv_residency_policy_rows.csv"),
    (v61m_dir / "kv_budget_profile_rows.csv", "source_v61m/kv_budget_profile_rows.csv"),
    (v61m_dir / "kv_eviction_trace_rows.csv", "source_v61m/kv_eviction_trace_rows.csv"),
    (v61m_dir / "sha256_manifest.csv", "source_v61m/sha256_manifest.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61bg_dir / "ubuntu1_token_budget_rows.csv")
kv_profiles = read_csv(v61m_dir / "kv_budget_profile_rows.csv")
kv_geometry = read_csv(v61m_dir / "kv_cache_geometry_rows.csv")[0]
policy = read_csv(v61m_dir / "kv_residency_policy_rows.csv")[0]
if len(token_rows) != 37:
    raise SystemExit("v61bh expects 37 token budget rows")
if len(kv_profiles) != 5:
    raise SystemExit("v61bh expects five KV profile rows")

kv_bytes_per_token = int(kv_geometry["kv_bytes_per_token"])
ssd_read_bytes_per_token = int(v61bg_summary["ssd_read_bytes_per_token"])
weight_plus_new_kv_bytes_per_token = ssd_read_bytes_per_token + kv_bytes_per_token
vram_kv_budget_bytes = int(policy["vram_kv_budget_bytes"])
hot_window_tokens = int(policy["hot_window_tokens"])
sink_tokens = int(policy["sink_tokens"])

profile_rows = []
combined_rows = []
for profile in kv_profiles:
    profile_rows.append(
        {
            "profile_id": profile["profile_id"],
            "context_tokens": profile["context_tokens"],
            "total_kv_pages": profile["total_kv_pages"],
            "resident_vram_pages": profile["resident_vram_pages"],
            "resident_vram_bytes": profile["resident_vram_bytes"],
            "evicted_nvme_pages": profile["evicted_nvme_pages"],
            "evicted_nvme_bytes": profile["evicted_nvme_bytes"],
            "host_ram_spill_bytes": profile["host_ram_spill_bytes"],
            "vram_kv_budget_bytes": profile["vram_kv_budget_bytes"],
            "vram_budget_pass": profile["vram_budget_pass"],
            "full_kv_vram_budget_pass": profile["full_kv_vram_budget_pass"],
            "nvme_eviction_required": profile["nvme_eviction_required"],
            "kv_cache_policy_ready": "1",
        }
    )

for token in token_rows:
    for profile in kv_profiles:
        token_ready = int(token["ubuntu1_token_budget_replay_ready"])
        vram_budget_pass = int(profile["vram_budget_pass"])
        no_host_ram_spill = int(profile["host_ram_spill_bytes"] == "0")
        combined_ready = int(token_ready and vram_budget_pass and no_host_ram_spill)
        combined_rows.append(
            {
                "combined_budget_id": f"v61bh_{token['ubuntu1_token_budget_id']}_{profile['profile_id']}",
                "ubuntu1_token_budget_id": token["ubuntu1_token_budget_id"],
                "workload_binding_id": token["workload_binding_id"],
                "query_id": token["query_id"],
                "query_family": token["query_family"],
                "selected_target_path": selected_target_path,
                "ubuntu1_hotset_root": ubuntu1_hotset_root,
                "context_profile_id": profile["profile_id"],
                "context_tokens": profile["context_tokens"],
                "source_bound_query_pass": token["source_bound_query_pass"],
                "active_page_reads_per_token": token["active_page_reads_per_token"],
                "active_tile_probe_rows_per_token": token["active_tile_probe_rows_per_token"],
                "ssd_read_bytes_per_token": token["ssd_read_bytes_per_token"],
                "kv_bytes_per_token": str(kv_bytes_per_token),
                "weight_plus_new_kv_bytes_per_token": str(weight_plus_new_kv_bytes_per_token),
                "ubuntu1_token_direct_io_latency_ms_p50": token["ubuntu1_token_direct_io_latency_ms_p50"],
                "ubuntu1_token_direct_io_latency_ms_p95": token["ubuntu1_token_direct_io_latency_ms_p95"],
                "q8_abs_error_budget_mean_per_token": token["q8_abs_error_budget_mean_per_token"],
                "q4_abs_error_budget_mean_per_token": token["q4_abs_error_budget_mean_per_token"],
                "kv_total_pages": profile["total_kv_pages"],
                "kv_resident_vram_pages": profile["resident_vram_pages"],
                "kv_resident_vram_bytes": profile["resident_vram_bytes"],
                "kv_evicted_nvme_pages": profile["evicted_nvme_pages"],
                "kv_evicted_nvme_bytes": profile["evicted_nvme_bytes"],
                "host_ram_spill_bytes": profile["host_ram_spill_bytes"],
                "vram_kv_budget_bytes": profile["vram_kv_budget_bytes"],
                "kv_vram_budget_pass": profile["vram_budget_pass"],
                "full_kv_vram_budget_pass": profile["full_kv_vram_budget_pass"],
                "kv_nvme_eviction_required": profile["nvme_eviction_required"],
                "combined_kv_weight_budget_ready": str(combined_ready),
                "checkpoint_payload_bytes_downloaded_by_v61bh": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "full_checkpoint_materialization_ready": "0",
                "full_safetensors_page_hash_binding_ready": "0",
                "real_100b_open_weight_materialized": "0",
                "actual_model_generation_ready": "0",
                "near_frontier_claim_ready": "0",
                "production_latency_claim_ready": "0",
                "real_release_package_ready": "0",
                "route_jump_rows": "0",
            }
        )

combined_count = len(combined_rows)
combined_ready_rows = sum(1 for row in combined_rows if row["combined_kv_weight_budget_ready"] == "1")
vram_policy_pass_rows = sum(1 for row in combined_rows if row["kv_vram_budget_pass"] == "1")
full_kv_vram_pass_rows = sum(1 for row in combined_rows if row["full_kv_vram_budget_pass"] == "1")
nvme_eviction_required_rows = sum(1 for row in combined_rows if row["kv_nvme_eviction_required"] == "1")
host_ram_spill_bytes_total = sum(int(row["host_ram_spill_bytes"]) for row in combined_rows)
max_context_tokens = max(int(row["context_tokens"]) for row in combined_rows)
max_kv_resident_vram_bytes = max(int(row["kv_resident_vram_bytes"]) for row in combined_rows)
max_kv_evicted_nvme_bytes = max(int(row["kv_evicted_nvme_bytes"]) for row in combined_rows)
budget_ready = int(
    combined_count == 185
    and combined_ready_rows == 185
    and vram_policy_pass_rows == 185
    and full_kv_vram_pass_rows == 74
    and nvme_eviction_required_rows == 111
    and host_ram_spill_bytes_total == 0
)

metric_rows = [
    {
        "metric_id": "v61bh_kv_weight_token_budget_metrics",
        "selected_target_path": selected_target_path,
        "ubuntu1_hotset_root": ubuntu1_hotset_root,
        "source_bound_token_budget_rows": str(len(token_rows)),
        "kv_context_profile_rows": str(len(kv_profiles)),
        "combined_kv_weight_budget_rows": str(combined_count),
        "combined_kv_weight_budget_ready_rows": str(combined_ready_rows),
        "vram_policy_pass_rows": str(vram_policy_pass_rows),
        "full_kv_vram_budget_pass_rows": str(full_kv_vram_pass_rows),
        "nvme_eviction_required_rows": str(nvme_eviction_required_rows),
        "host_ram_spill_bytes_total": str(host_ram_spill_bytes_total),
        "hot_window_tokens": str(hot_window_tokens),
        "sink_tokens": str(sink_tokens),
        "kv_bytes_per_token": str(kv_bytes_per_token),
        "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
        "weight_plus_new_kv_bytes_per_token": str(weight_plus_new_kv_bytes_per_token),
        "ubuntu1_token_direct_io_latency_ms_p50": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p50"],
        "ubuntu1_token_direct_io_latency_ms_p95": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p95"],
        "q8_abs_error_budget_mean_per_token": v61bg_summary["q8_abs_error_budget_mean_per_token"],
        "q4_abs_error_budget_mean_per_token": v61bg_summary["q4_abs_error_budget_mean_per_token"],
        "max_context_tokens": str(max_context_tokens),
        "max_kv_resident_vram_bytes": str(max_kv_resident_vram_bytes),
        "max_kv_evicted_nvme_bytes": str(max_kv_evicted_nvme_bytes),
        "kv_weight_token_budget_replay_ready": str(budget_ready),
        "checkpoint_payload_bytes_downloaded_by_v61bh": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "full_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "real_100b_open_weight_materialized": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
]

runtime_gap_rows = [
    {"gap": "v61bg-ubuntu1-token-budget-input", "status": "ready", "evidence": "37 source-bound ubuntu-1 token-budget rows are ready"},
    {"gap": "v61m-kv-cache-policy-input", "status": "ready", "evidence": "KV VRAM-hot plus NVMe-cold policy is ready with host RAM spill disabled"},
    {"gap": "ubuntu1-combined-kv-weight-token-budget", "status": "ready" if budget_ready else "blocked", "evidence": f"{combined_ready_rows}/{combined_count} combined rows pass ubuntu-1 weight and KV policy gates"},
    {"gap": "full-kv-vram-residency", "status": "blocked", "evidence": f"only {full_kv_vram_pass_rows}/{combined_count} combined rows fit full KV in VRAM"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only sampled hotset pages are materialized"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "KV+weight budget replay does not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "budget replay is not production latency evidence"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61bg-ubuntu1-token-budget-input", "status": "pass", "reason": "source-bound ubuntu-1 token-budget replay is ready"},
    {"gate": "v61m-kv-cache-policy-input", "status": "pass", "reason": "KV policy is ready with host RAM spill disabled"},
    {"gate": "ubuntu1-combined-kv-weight-token-budget", "status": "pass" if budget_ready else "blocked", "reason": f"{combined_ready_rows}/{combined_count} combined rows pass"},
    {"gate": "no-network-download-by-v61bh", "status": "pass", "reason": "v61bh only consumes existing ubuntu-1 replay evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived rows only; checkpoint payload bytes remain outside the repository"},
    {"gate": "full-kv-vram-residency", "status": "blocked", "reason": "long contexts require NVMe cold KV tier"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "budget replay is not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "kv_weight_context_profile_rows.csv", list(profile_rows[0].keys()), profile_rows)
write_csv(run_dir / "kv_weight_token_budget_rows.csv", list(combined_rows[0].keys()), combined_rows)
write_csv(run_dir / "kv_weight_token_budget_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61bh_ubuntu1_kv_weight_token_budget_replay_ready": str(budget_ready),
    "v61bg_ubuntu1_token_budget_replay_ready": v61bg_summary["v61bg_ubuntu1_token_budget_replay_ready"],
    "v61m_kv_cache_residency_eviction_policy_ready": v61m_summary["v61m_kv_cache_residency_eviction_policy_ready"],
    "model_id": model_id,
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "source_bound_token_budget_rows": str(len(token_rows)),
    "kv_context_profile_rows": str(len(kv_profiles)),
    "combined_kv_weight_budget_rows": str(combined_count),
    "combined_kv_weight_budget_ready_rows": str(combined_ready_rows),
    "vram_policy_pass_rows": str(vram_policy_pass_rows),
    "full_kv_vram_budget_pass_rows": str(full_kv_vram_pass_rows),
    "nvme_eviction_required_rows": str(nvme_eviction_required_rows),
    "host_ram_spill_bytes_total": str(host_ram_spill_bytes_total),
    "hot_window_tokens": str(hot_window_tokens),
    "sink_tokens": str(sink_tokens),
    "kv_bytes_per_token": str(kv_bytes_per_token),
    "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
    "weight_plus_new_kv_bytes_per_token": str(weight_plus_new_kv_bytes_per_token),
    "ubuntu1_token_direct_io_latency_ms_p50": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p50"],
    "ubuntu1_token_direct_io_latency_ms_p95": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p95"],
    "q8_abs_error_budget_mean_per_token": v61bg_summary["q8_abs_error_budget_mean_per_token"],
    "q4_abs_error_budget_mean_per_token": v61bg_summary["q4_abs_error_budget_mean_per_token"],
    "max_context_tokens": str(max_context_tokens),
    "max_kv_resident_vram_bytes": str(max_kv_resident_vram_bytes),
    "max_kv_evicted_nvme_bytes": str(max_kv_evicted_nvme_bytes),
    "kv_weight_token_budget_replay_ready": str(budget_ready),
    "checkpoint_payload_bytes_downloaded_by_v61bh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61bh_ubuntu1_kv_weight_token_budget_replay",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "v61bh_ubuntu1_kv_weight_token_budget_replay_ready": budget_ready,
    "combined_kv_weight_budget_rows": combined_count,
    "combined_kv_weight_budget_ready_rows": combined_ready_rows,
    "kv_bytes_per_token": kv_bytes_per_token,
    "ssd_read_bytes_per_token": ssd_read_bytes_per_token,
    "weight_plus_new_kv_bytes_per_token": weight_plus_new_kv_bytes_per_token,
    "host_ram_spill_bytes_total": host_ram_spill_bytes_total,
    "max_context_tokens": max_context_tokens,
    "checkpoint_payload_bytes_downloaded_by_v61bh": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_100b_open_weight_materialized": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "full_kv_vram_residency",
        "full_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61bh_ubuntu1_kv_weight_token_budget_replay_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61bh Ubuntu-1 KV + Weight Token Budget Replay Boundary

This artifact binds v61bg ubuntu-1 source-bound token-budget rows to the v61m
KV-cache residency/eviction policy. It verifies that target-specific ubuntu-1
SSD weight reads and deterministic VRAM-hot/NVMe-cold KV residency fit the
local budget shape without host RAM KV spill. It does not execute Mixtral
generation.

Evidence emitted:

- selected_target_path={selected_target_path}
- ubuntu1_hotset_root={ubuntu1_hotset_root}
- source_bound_token_budget_rows={len(token_rows)}
- kv_context_profile_rows={len(kv_profiles)}
- combined_kv_weight_budget_rows={combined_count}
- combined_kv_weight_budget_ready_rows={combined_ready_rows}
- vram_policy_pass_rows={vram_policy_pass_rows}
- full_kv_vram_budget_pass_rows={full_kv_vram_pass_rows}
- nvme_eviction_required_rows={nvme_eviction_required_rows}
- host_ram_spill_bytes_total={host_ram_spill_bytes_total}
- kv_bytes_per_token={kv_bytes_per_token}
- ssd_read_bytes_per_token={ssd_read_bytes_per_token}
- weight_plus_new_kv_bytes_per_token={weight_plus_new_kv_bytes_per_token}
- ubuntu1_token_direct_io_latency_ms_p50={v61bg_summary["ubuntu1_token_direct_io_latency_ms_p50"]}
- ubuntu1_token_direct_io_latency_ms_p95={v61bg_summary["ubuntu1_token_direct_io_latency_ms_p95"]}
- q8_abs_error_budget_mean_per_token={v61bg_summary["q8_abs_error_budget_mean_per_token"]}
- q4_abs_error_budget_mean_per_token={v61bg_summary["q4_abs_error_budget_mean_per_token"]}
- max_context_tokens={max_context_tokens}
- max_kv_resident_vram_bytes={max_kv_resident_vram_bytes}
- max_kv_evicted_nvme_bytes={max_kv_evicted_nvme_bytes}
- kv_weight_token_budget_replay_ready={budget_ready}
- checkpoint_payload_bytes_downloaded_by_v61bh=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_kv_vram_residency=blocked
- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- real_100b_open_weight_materialized=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is bounded budget replay evidence over ubuntu-1 sampled real checkpoint
pages and deterministic KV policy rows. It is not full Mixtral checkpoint
materialization, full page-hash coverage, real Mixtral generation,
near-frontier quality, production latency, or release evidence.
"""
(run_dir / "V61BH_UBUNTU1_KV_WEIGHT_TOKEN_BUDGET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bh_ubuntu1_kv_weight_token_budget_replay_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
