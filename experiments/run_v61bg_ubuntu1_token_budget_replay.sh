#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bg_ubuntu1_token_budget_replay"
RUN_ID="${V61BG_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bg_ubuntu1_token_budget_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61X_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61x_hotset_runtime_replay_manifest.sh" >/dev/null
V61BD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh" >/dev/null
V61BF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bf_ubuntu1_tensor_tile_quant_probe.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

model_id = "mistralai/Mixtral-8x22B-v0.1"
active_page_reads_per_token = 4
tiles_per_page = 8
page_bytes = 2 * 1024 * 1024


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


v61x_dir = results / "v61x_hotset_runtime_replay_manifest" / "hotset_001"
v61bd_dir = results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay" / "replay_001"
v61bf_dir = results / "v61bf_ubuntu1_tensor_tile_quant_probe" / "probe_001"

v61x_summary = read_csv(results / "v61x_hotset_runtime_replay_manifest_summary.csv")[0]
v61bd_summary = read_csv(results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv")[0]
v61bf_summary = read_csv(results / "v61bf_ubuntu1_tensor_tile_quant_probe_summary.csv")[0]
if v61x_summary.get("v61x_hotset_runtime_replay_manifest_ready") != "1":
    raise SystemExit("v61bg requires v61x_hotset_runtime_replay_manifest_ready=1")
if v61x_summary.get("source_bound_replay_binding_ready") != "1":
    raise SystemExit("v61bg requires source_bound_replay_binding_ready=1")
if v61bd_summary.get("v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready") != "1":
    raise SystemExit("v61bg requires v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1")
if v61bd_summary.get("ubuntu1_direct_io_replay_ready") != "1":
    raise SystemExit("v61bg requires ubuntu1_direct_io_replay_ready=1")
if v61bf_summary.get("v61bf_ubuntu1_tensor_tile_quant_probe_ready") != "1":
    raise SystemExit("v61bg requires v61bf_ubuntu1_tensor_tile_quant_probe_ready=1")
if v61bf_summary.get("ubuntu1_q8_quant_probe_ready") != "1" or v61bf_summary.get("ubuntu1_q4_quant_probe_ready") != "1":
    raise SystemExit("v61bg requires ubuntu1 q8/q4 quant probes ready")

selected_target_path = v61bd_summary["selected_target_path"]
ubuntu1_hotset_root = v61bd_summary["ubuntu1_hotset_root"]

for src, rel in [
    (results / "v61x_hotset_runtime_replay_manifest_summary.csv", "source_v61x/v61x_hotset_runtime_replay_manifest_summary.csv"),
    (v61x_dir / "hotset_source_bound_workload_binding_rows.csv", "source_v61x/hotset_source_bound_workload_binding_rows.csv"),
    (v61x_dir / "hotset_runtime_page_rows.csv", "source_v61x/hotset_runtime_page_rows.csv"),
    (v61x_dir / "hotset_runtime_slot_rows.csv", "source_v61x/hotset_runtime_slot_rows.csv"),
    (v61x_dir / "sha256_manifest.csv", "source_v61x/sha256_manifest.csv"),
    (results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv", "source_v61bd/v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_read_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_read_rows.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_metric_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_metric_rows.csv"),
    (v61bd_dir / "sha256_manifest.csv", "source_v61bd/sha256_manifest.csv"),
    (results / "v61bf_ubuntu1_tensor_tile_quant_probe_summary.csv", "source_v61bf/v61bf_ubuntu1_tensor_tile_quant_probe_summary.csv"),
    (v61bf_dir / "ubuntu1_tensor_tile_probe_rows.csv", "source_v61bf/ubuntu1_tensor_tile_probe_rows.csv"),
    (v61bf_dir / "ubuntu1_tensor_tile_quant_metric_rows.csv", "source_v61bf/ubuntu1_tensor_tile_quant_metric_rows.csv"),
    (v61bf_dir / "sha256_manifest.csv", "source_v61bf/sha256_manifest.csv"),
]:
    copy(src, rel)

workload_rows = read_csv(v61x_dir / "hotset_source_bound_workload_binding_rows.csv")
direct_rows = read_csv(v61bd_dir / "ubuntu1_hotset_direct_io_read_rows.csv")
tile_rows = read_csv(v61bf_dir / "ubuntu1_tensor_tile_probe_rows.csv")
tile_metric = read_csv(v61bf_dir / "ubuntu1_tensor_tile_quant_metric_rows.csv")[0]

moe_direct_rows = [
    row for row in direct_rows
    if row["node_type"] == "moe_expert_page_node"
    and row["direct_read_hash_match"] == "1"
    and row["direct_io_used"] == "1"
]
if len(workload_rows) != 37:
    raise SystemExit("v61bg expects 37 source-bound workload bindings")
if len(moe_direct_rows) != 15:
    raise SystemExit("v61bg expects 15 hash-matched ubuntu-1 MoE direct-read rows")

tiles_by_remote_sample = defaultdict(list)
for row in tile_rows:
    if row["moe_expert_tile"] == "1":
        tiles_by_remote_sample[row["remote_sample_id"]].append(row)
for sample_id, rows in tiles_by_remote_sample.items():
    rows.sort(key=lambda item: int(item["tile_index_in_slice"]))
    if len(rows) != tiles_per_page:
        raise SystemExit(f"v61bg expects {tiles_per_page} ubuntu-1 tiles for {sample_id}")

direct_p50_ms = float(v61bd_summary["direct_io_read_latency_ms_p50"])
direct_p95_ms = float(v61bd_summary["direct_io_read_latency_ms_p95"])
ssd_read_bytes_per_token = active_page_reads_per_token * page_bytes
if str(ssd_read_bytes_per_token) != v61bd_summary["ssd_read_bytes_per_token"]:
    raise SystemExit("v61bg ssd_read_bytes_per_token disagrees with v61bd")
token_p50_ms = direct_p50_ms * active_page_reads_per_token
token_p95_ms = direct_p95_ms * active_page_reads_per_token
tile_values_per_token = (
    active_page_reads_per_token
    * tiles_per_page
    * int(tile_metric["tile_bf16_value_rows"])
    // int(tile_metric["tensor_tile_probe_rows"])
)
q8_error_budget_mean = float(tile_metric["q8_abs_error_mean"]) * active_page_reads_per_token * tiles_per_page
q4_error_budget_mean = float(tile_metric["q4_abs_error_mean"]) * active_page_reads_per_token * tiles_per_page

budget_rows = []
schedule_rows = []
tile_binding_rows = []
finite_budget_rows = 0
finite_tile_binding_rows = 0

for query_index, workload in enumerate(workload_rows):
    selected_direct = [
        moe_direct_rows[(query_index + offset) % len(moe_direct_rows)]
        for offset in range(active_page_reads_per_token)
    ]
    query_tile_rows = []
    for page_index, direct in enumerate(selected_direct):
        sample_id = direct["runtime_node_id"].replace("v61v_node_", "")
        tile_set = tiles_by_remote_sample[sample_id]
        schedule_id = f"v61bg_ubuntu1_schedule_{query_index:04d}_{page_index:02d}"
        schedule_rows.append(
            {
                "schedule_id": schedule_id,
                "workload_binding_id": workload["workload_binding_id"],
                "query_id": workload["query_id"],
                "query_family": workload["query_family"],
                "active_page_index": str(page_index),
                "direct_read_id": direct["direct_read_id"],
                "runtime_node_id": direct["runtime_node_id"],
                "remote_sample_id": sample_id,
                "tensor_role": direct["tensor_role"],
                "layer_index": direct["layer_index"],
                "expert_index": direct["expert_index"],
                "ubuntu1_page_path": direct["ubuntu1_page_path"],
                "bytes_read": direct["bytes_read"],
                "read_latency_ms": direct["read_latency_ms"],
                "direct_io_used": direct["direct_io_used"],
                "direct_read_hash_match": direct["direct_read_hash_match"],
                "checkpoint_payload_bytes_downloaded_by_v61bg": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "actual_model_generation_ready": "0",
                "production_latency_claim_ready": "0",
                "route_jump_rows": "0",
            }
        )
        for tile in tile_set:
            query_tile_rows.append(tile)
            tile_binding_rows.append(
                {
                    "tile_binding_id": f"v61bg_ubuntu1_tile_binding_{query_index:04d}_{page_index:02d}_{tile['tile_index_in_slice']}",
                    "schedule_id": schedule_id,
                    "workload_binding_id": workload["workload_binding_id"],
                    "query_id": workload["query_id"],
                    "ubuntu1_tile_id": tile["ubuntu1_tile_id"],
                    "remote_sample_id": sample_id,
                    "tensor_name": tile["tensor_name"],
                    "tensor_role": tile["tensor_role"],
                    "layer_index": tile["layer_index"],
                    "expert_index": tile["expert_index"],
                    "ubuntu1_page_path": tile["ubuntu1_page_path"],
                    "tile_bf16_values": tile["tile_bf16_values"],
                    "tile_hash_bound_to_remote_page": tile["tile_hash_bound_to_remote_page"],
                    "ubuntu1_page_hash_match": tile["ubuntu1_page_hash_match"],
                    "direct_read_hash_match": tile["direct_read_hash_match"],
                    "direct_io_used": tile["direct_io_used"],
                    "baseline_dot_finite": tile["baseline_dot_finite"],
                    "q8_dot_finite": tile["q8_dot_finite"],
                    "q4_dot_finite": tile["q4_dot_finite"],
                    "q8_error_finite": tile["q8_error_finite"],
                    "q4_error_finite": tile["q4_error_finite"],
                    "checkpoint_payload_bytes_downloaded_by_v61bg": "0",
                    "checkpoint_payload_bytes_committed_to_repo": "0",
                    "actual_model_generation_ready": "0",
                    "route_jump_rows": "0",
                }
            )
    finite_tiles = sum(
        1 for tile in query_tile_rows
        if tile["baseline_dot_finite"] == "1"
        and tile["q8_dot_finite"] == "1"
        and tile["q4_dot_finite"] == "1"
        and tile["q8_error_finite"] == "1"
        and tile["q4_error_finite"] == "1"
        and tile["ubuntu1_page_hash_match"] == "1"
        and tile["direct_read_hash_match"] == "1"
        and tile["direct_io_used"] == "1"
    )
    token_ready = int(
        workload["source_bound_query_pass"] == "1"
        and len(selected_direct) == active_page_reads_per_token
        and len(query_tile_rows) == active_page_reads_per_token * tiles_per_page
        and finite_tiles == len(query_tile_rows)
    )
    finite_budget_rows += token_ready
    finite_tile_binding_rows += finite_tiles
    budget_rows.append(
        {
            "ubuntu1_token_budget_id": f"v61bg_ubuntu1_token_budget_{query_index:04d}",
            "workload_binding_id": workload["workload_binding_id"],
            "query_id": workload["query_id"],
            "query_family": workload["query_family"],
            "requires_abstain": workload["requires_abstain"],
            "source_bound_query_pass": workload["source_bound_query_pass"],
            "active_page_reads_per_token": str(active_page_reads_per_token),
            "active_tile_probe_rows_per_token": str(active_page_reads_per_token * tiles_per_page),
            "tile_bf16_values_per_token": str(tile_values_per_token),
            "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
            "ubuntu1_direct_io_latency_ms_p50_per_page": fmt(direct_p50_ms),
            "ubuntu1_direct_io_latency_ms_p95_per_page": fmt(direct_p95_ms),
            "ubuntu1_token_direct_io_latency_ms_p50": fmt(token_p50_ms),
            "ubuntu1_token_direct_io_latency_ms_p95": fmt(token_p95_ms),
            "q8_abs_error_budget_mean_per_token": fmt(q8_error_budget_mean),
            "q4_abs_error_budget_mean_per_token": fmt(q4_error_budget_mean),
            "finite_tile_binding_rows": str(finite_tiles),
            "ubuntu1_token_budget_replay_ready": str(token_ready),
            "checkpoint_payload_bytes_downloaded_by_v61bg": "0",
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

tile_binding_count = len(tile_binding_rows)
schedule_count = len(schedule_rows)
budget_ready = int(
    len(budget_rows) == 37
    and schedule_count == 37 * active_page_reads_per_token
    and tile_binding_count == 37 * active_page_reads_per_token * tiles_per_page
    and finite_budget_rows == 37
    and finite_tile_binding_rows == tile_binding_count
)

metric_rows = [
    {
        "metric_id": "v61bg_ubuntu1_token_budget_metrics",
        "model_id": model_id,
        "selected_target_path": selected_target_path,
        "ubuntu1_hotset_root": ubuntu1_hotset_root,
        "source_bound_workload_binding_rows": str(len(workload_rows)),
        "token_budget_rows": str(len(budget_rows)),
        "token_page_schedule_rows": str(schedule_count),
        "token_tile_binding_rows": str(tile_binding_count),
        "finite_token_budget_rows": str(finite_budget_rows),
        "finite_tile_binding_rows": str(finite_tile_binding_rows),
        "active_page_reads_per_token": str(active_page_reads_per_token),
        "active_tile_probe_rows_per_token": str(active_page_reads_per_token * tiles_per_page),
        "tile_bf16_values_per_token": str(tile_values_per_token),
        "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
        "ubuntu1_token_direct_io_latency_ms_p50": fmt(token_p50_ms),
        "ubuntu1_token_direct_io_latency_ms_p95": fmt(token_p95_ms),
        "q8_abs_error_budget_mean_per_token": fmt(q8_error_budget_mean),
        "q4_abs_error_budget_mean_per_token": fmt(q4_error_budget_mean),
        "ubuntu1_token_budget_replay_ready": str(budget_ready),
        "checkpoint_payload_bytes_downloaded_by_v61bg": "0",
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
    {"gap": "v61x-source-bound-replay-binding", "status": "ready", "evidence": "37 source-bound workload bindings are hotset-bound"},
    {"gap": "v61bd-ubuntu1-direct-io-latency-input", "status": "ready", "evidence": f"ubuntu-1 direct-I/O p50/p95 per page are {fmt(direct_p50_ms)}/{fmt(direct_p95_ms)} ms"},
    {"gap": "v61bf-ubuntu1-numeric-tile-input", "status": "ready", "evidence": "128 finite ubuntu-1 BF16/q8/q4 tile probes are available"},
    {"gap": "ubuntu1-token-budget-replay", "status": "ready" if budget_ready else "blocked", "evidence": f"{finite_budget_rows}/{len(budget_rows)} token budget rows are finite and hash-bound"},
    {"gap": "explicit-download-execution", "status": "blocked", "evidence": "v61bg performs no checkpoint download"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only bounded sampled hotset pages are resident on ubuntu-1"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "token budget replay does not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "budget replay is not production latency evidence"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61x-source-bound-replay-binding", "status": "pass", "reason": "source-bound workload bindings are hotset-bound"},
    {"gate": "v61bd-ubuntu1-direct-io-latency-input", "status": "pass", "reason": "ubuntu-1 direct-I/O latency metrics are present"},
    {"gate": "v61bf-ubuntu1-numeric-tile-input", "status": "pass", "reason": "finite ubuntu-1 BF16/q8/q4 numeric tile probes are present"},
    {"gate": "ubuntu1-token-budget-replay", "status": "pass" if budget_ready else "blocked", "reason": f"{finite_budget_rows}/{len(budget_rows)} token budget rows are ready"},
    {"gate": "no-network-download-by-v61bg", "status": "pass", "reason": "checkpoint_payload_bytes_downloaded_by_v61bg=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived rows only; checkpoint payload bytes remain outside the repository"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "full checkpoint payload download remains disabled"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "budget replay is not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "ubuntu1_token_budget_rows.csv", list(budget_rows[0].keys()), budget_rows)
write_csv(run_dir / "ubuntu1_token_budget_page_schedule_rows.csv", list(schedule_rows[0].keys()), schedule_rows)
write_csv(run_dir / "ubuntu1_token_budget_tile_binding_rows.csv", list(tile_binding_rows[0].keys()), tile_binding_rows)
write_csv(run_dir / "ubuntu1_token_budget_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61bg_ubuntu1_token_budget_replay_ready": str(budget_ready),
    "v61x_hotset_runtime_replay_manifest_ready": v61x_summary["v61x_hotset_runtime_replay_manifest_ready"],
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready": v61bd_summary["v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready"],
    "v61bf_ubuntu1_tensor_tile_quant_probe_ready": v61bf_summary["v61bf_ubuntu1_tensor_tile_quant_probe_ready"],
    "model_id": model_id,
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "source_bound_workload_binding_rows": str(len(workload_rows)),
    "token_budget_rows": str(len(budget_rows)),
    "token_page_schedule_rows": str(schedule_count),
    "token_tile_binding_rows": str(tile_binding_count),
    "finite_token_budget_rows": str(finite_budget_rows),
    "finite_tile_binding_rows": str(finite_tile_binding_rows),
    "active_page_reads_per_token": str(active_page_reads_per_token),
    "active_tile_probe_rows_per_token": str(active_page_reads_per_token * tiles_per_page),
    "tile_bf16_values_per_token": str(tile_values_per_token),
    "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
    "ubuntu1_token_direct_io_latency_ms_p50": fmt(token_p50_ms),
    "ubuntu1_token_direct_io_latency_ms_p95": fmt(token_p95_ms),
    "q8_abs_error_budget_mean_per_token": fmt(q8_error_budget_mean),
    "q4_abs_error_budget_mean_per_token": fmt(q4_error_budget_mean),
    "ubuntu1_token_budget_replay_ready": str(budget_ready),
    "checkpoint_payload_bytes_downloaded_by_v61bg": "0",
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
    "artifact": "v61bg_ubuntu1_token_budget_replay",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "v61bg_ubuntu1_token_budget_replay_ready": budget_ready,
    "token_budget_rows": len(budget_rows),
    "token_page_schedule_rows": schedule_count,
    "token_tile_binding_rows": tile_binding_count,
    "active_page_reads_per_token": active_page_reads_per_token,
    "active_tile_probe_rows_per_token": active_page_reads_per_token * tiles_per_page,
    "tile_bf16_values_per_token": tile_values_per_token,
    "ssd_read_bytes_per_token": ssd_read_bytes_per_token,
    "ubuntu1_token_direct_io_latency_ms_p50": token_p50_ms,
    "ubuntu1_token_direct_io_latency_ms_p95": token_p95_ms,
    "checkpoint_payload_bytes_downloaded_by_v61bg": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "explicit_download_execution",
        "full_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61bg_ubuntu1_token_budget_replay_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

boundary = f"""# v61bg ubuntu-1 Token Budget Replay Boundary

This artifact binds v61x source-bound workload rows, v61bd ubuntu-1 sampled
direct-I/O latency evidence, and v61bf ubuntu-1 sampled BF16/q8/q4 numeric tile
probes into a bounded per-token hotset budget replay. It does not execute
Mixtral generation.

Evidence emitted:

- selected_target_path={selected_target_path}
- ubuntu1_hotset_root={ubuntu1_hotset_root}
- source_bound_workload_binding_rows={len(workload_rows)}
- token_budget_rows={len(budget_rows)}
- token_page_schedule_rows={schedule_count}
- token_tile_binding_rows={tile_binding_count}
- active_page_reads_per_token={active_page_reads_per_token}
- active_tile_probe_rows_per_token={active_page_reads_per_token * tiles_per_page}
- tile_bf16_values_per_token={tile_values_per_token}
- ssd_read_bytes_per_token={ssd_read_bytes_per_token}
- ubuntu1_token_direct_io_latency_ms_p50={fmt(token_p50_ms)}
- ubuntu1_token_direct_io_latency_ms_p95={fmt(token_p95_ms)}
- q8_abs_error_budget_mean_per_token={fmt(q8_error_budget_mean)}
- q4_abs_error_budget_mean_per_token={fmt(q4_error_budget_mean)}
- ubuntu1_token_budget_replay_ready={budget_ready}
- checkpoint_payload_bytes_downloaded_by_v61bg=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- real_100b_open_weight_materialized=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is bounded budget replay evidence over sampled real checkpoint pages
resident under the ubuntu-1 target. It is not full Mixtral checkpoint
materialization, full page-hash coverage, real Mixtral generation,
near-frontier quality, production latency, or release evidence.
"""
(run_dir / "V61BG_UBUNTU1_TOKEN_BUDGET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bg_ubuntu1_token_budget_replay_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
