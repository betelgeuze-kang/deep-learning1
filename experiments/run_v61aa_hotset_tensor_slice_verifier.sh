#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61aa_hotset_tensor_slice_verifier"
RUN_ID="${V61AA_RUN_ID:-verify_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61aa_hotset_tensor_slice_verifier_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61Z_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61z_hotset_direct_io_replay.sh" >/dev/null
V61V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61v_remote_page_tensor_binding.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import os
import shutil
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v61v_dir = results / "v61v_remote_page_tensor_binding" / "binding_001"
v61y_dir = results / "v61y_hotset_local_materialization_verifier" / "verify_001"
v61z_dir = results / "v61z_hotset_direct_io_replay" / "replay_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
samples_per_slice = int(os.environ.get("V61AA_BF16_SAMPLE_VALUES_PER_SLICE", "4096"))
if samples_per_slice <= 0:
    raise SystemExit("samples_per_slice must be positive")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def bf16_to_float32(raw_u16):
    return struct.unpack("<f", struct.pack("<I", raw_u16 << 16))[0]


def sample_indices(count, target):
    if count <= 0:
        return []
    target = min(count, target)
    if target == 1:
        return [0]
    return sorted({round(i * (count - 1) / (target - 1)) for i in range(target)})


v61z_summary = read_csv(results / "v61z_hotset_direct_io_replay_summary.csv")[0]
v61v_summary = read_csv(results / "v61v_remote_page_tensor_binding_summary.csv")[0]
v61y_summary = read_csv(results / "v61y_hotset_local_materialization_verifier_summary.csv")[0]
if v61z_summary.get("v61z_hotset_direct_io_replay_ready") != "1":
    raise SystemExit("v61aa requires v61z_hotset_direct_io_replay_ready=1")
if v61z_summary.get("direct_io_replay_ready") != "1":
    raise SystemExit("v61aa requires direct_io_replay_ready=1")
if v61v_summary.get("v61v_remote_page_tensor_binding_ready") != "1":
    raise SystemExit("v61aa requires v61v_remote_page_tensor_binding_ready=1")
if v61y_summary.get("hotset_payload_materialization_ready") != "1":
    raise SystemExit("v61aa requires hotset_payload_materialization_ready=1")

for src, rel in [
    (results / "v61z_hotset_direct_io_replay_summary.csv", "source_v61z/v61z_hotset_direct_io_replay_summary.csv"),
    (results / "v61z_hotset_direct_io_replay_decision.csv", "source_v61z/v61z_hotset_direct_io_replay_decision.csv"),
    (v61z_dir / "hotset_direct_io_read_rows.csv", "source_v61z/hotset_direct_io_read_rows.csv"),
    (v61z_dir / "hotset_direct_io_prefetch_order_rows.csv", "source_v61z/hotset_direct_io_prefetch_order_rows.csv"),
    (v61z_dir / "hotset_direct_io_metric_rows.csv", "source_v61z/hotset_direct_io_metric_rows.csv"),
    (v61z_dir / "sha256_manifest.csv", "source_v61z/sha256_manifest.csv"),
    (results / "v61v_remote_page_tensor_binding_summary.csv", "source_v61v/v61v_remote_page_tensor_binding_summary.csv"),
    (v61v_dir / "remote_sample_tensor_binding_rows.csv", "source_v61v/remote_sample_tensor_binding_rows.csv"),
    (v61v_dir / "remote_sample_runtime_node_rows.csv", "source_v61v/remote_sample_runtime_node_rows.csv"),
    (v61v_dir / "sha256_manifest.csv", "source_v61v/sha256_manifest.csv"),
    (results / "v61y_hotset_local_materialization_verifier_summary.csv", "source_v61y/v61y_hotset_local_materialization_verifier_summary.csv"),
    (v61y_dir / "hotset_local_materialization_rows.csv", "source_v61y/hotset_local_materialization_rows.csv"),
    (v61y_dir / "sha256_manifest.csv", "source_v61y/sha256_manifest.csv"),
]:
    copy(src, rel)

binding_rows = read_csv(v61v_dir / "remote_sample_tensor_binding_rows.csv")
materialization_rows = {row["remote_sample_id"]: row for row in read_csv(v61y_dir / "hotset_local_materialization_rows.csv")}
direct_rows = {row["slot_id"]: row for row in read_csv(v61z_dir / "hotset_direct_io_read_rows.csv")}
if len(binding_rows) != 16:
    raise SystemExit("v61aa expects 16 v61v tensor binding rows")

slice_rows = []
sample_rows = []
sampled_total = 0
finite_total = 0
nan_total = 0
inf_total = 0
nonzero_total = 0
tensor_segment_bytes_total = 0
slice_hash_match_rows = 0
moe_slice_rows = 0
embedding_slice_rows = 0

for slice_index, binding in enumerate(binding_rows):
    sample_id = binding["remote_sample_id"]
    materialized = materialization_rows[sample_id]
    direct = direct_rows[materialized["slot_id"]]
    local_path = Path(materialized["planned_local_page_path"])
    page = local_path.read_bytes()
    page_sha = sha256_bytes(page)
    if page_sha != binding["remote_page_sha256"]:
        raise SystemExit(f"v61aa page hash mismatch for {sample_id}")
    start = int(binding["page_offset_start"])
    end = int(binding["page_offset_end"])
    segment = page[start:end]
    segment_bytes = len(segment)
    if segment_bytes != int(binding["tensor_segment_bytes"]):
        raise SystemExit(f"v61aa segment byte mismatch for {sample_id}")
    if segment_bytes % 2 != 0:
        raise SystemExit(f"v61aa BF16 segment has odd byte count for {sample_id}")
    element_count = segment_bytes // 2
    indices = sample_indices(element_count, samples_per_slice)
    finite_values = []
    nan_count = 0
    inf_count = 0
    zero_count = 0
    nonzero_count = 0
    first_hex = ""
    last_hex = ""
    for sample_index, element_index in enumerate(indices):
        byte_offset = element_index * 2
        raw = int.from_bytes(segment[byte_offset:byte_offset + 2], "little")
        value = bf16_to_float32(raw)
        raw_hex = f"0x{raw:04x}"
        if sample_index == 0:
            first_hex = raw_hex
        last_hex = raw_hex
        finite = math.isfinite(value)
        is_nan = math.isnan(value)
        is_inf = math.isinf(value)
        is_zero = finite and value == 0.0
        if finite:
            finite_values.append(value)
            if is_zero:
                zero_count += 1
            else:
                nonzero_count += 1
        elif is_nan:
            nan_count += 1
        elif is_inf:
            inf_count += 1
        sample_rows.append(
            {
                "sample_value_id": f"v61aa_sample_{slice_index:04d}_{sample_index:04d}",
                "binding_id": binding["binding_id"],
                "remote_sample_id": sample_id,
                "tensor_name": binding["tensor_name"],
                "tensor_role": binding["tensor_role"],
                "layer_index": binding["layer_index"],
                "expert_index": binding["expert_index"],
                "dtype": binding["dtype"],
                "element_index_in_segment": str(element_index),
                "byte_offset_in_page": str(start + byte_offset),
                "bf16_hex": raw_hex,
                "fp32_value": f"{value:.9g}" if finite else str(value),
                "finite": "1" if finite else "0",
                "is_nan": "1" if is_nan else "0",
                "is_inf": "1" if is_inf else "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )

    sample_count = len(indices)
    finite_count = len(finite_values)
    finite_total += finite_count
    sampled_total += sample_count
    nan_total += nan_count
    inf_total += inf_count
    nonzero_total += nonzero_count
    tensor_segment_bytes_total += segment_bytes
    if binding["moe_expert_page"] == "1":
        moe_slice_rows += 1
    if binding["embedding_page"] == "1":
        embedding_slice_rows += 1
    segment_sha = sha256_bytes(segment)
    segment_hash_bound = int(page_sha == binding["remote_page_sha256"] and direct["direct_read_hash_match"] == "1")
    slice_hash_match_rows += segment_hash_bound
    mean = math.fsum(finite_values) / finite_count if finite_count else 0.0
    mean_abs = math.fsum(abs(v) for v in finite_values) / finite_count if finite_count else 0.0
    rms = math.sqrt(math.fsum(v * v for v in finite_values) / finite_count) if finite_count else 0.0
    min_value = min(finite_values) if finite_values else 0.0
    max_value = max(finite_values) if finite_values else 0.0
    slice_rows.append(
        {
            "tensor_slice_id": f"v61aa_tensor_slice_{slice_index:04d}",
            "binding_id": binding["binding_id"],
            "remote_sample_id": sample_id,
            "model_id": model_id,
            "shard_name": binding["shard_name"],
            "shard_page_index": binding["shard_page_index"],
            "tensor_name": binding["tensor_name"],
            "tensor_role": binding["tensor_role"],
            "layer_index": binding["layer_index"],
            "expert_index": binding["expert_index"],
            "dtype": binding["dtype"],
            "local_page_path": str(local_path),
            "page_offset_start": binding["page_offset_start"],
            "page_offset_end": binding["page_offset_end"],
            "tensor_segment_bytes": str(segment_bytes),
            "tensor_segment_elements": str(element_count),
            "tensor_segment_sha256": segment_sha,
            "local_page_sha256": page_sha,
            "remote_page_sha256": binding["remote_page_sha256"],
            "segment_hash_bound_to_remote_page": str(segment_hash_bound),
            "direct_read_hash_match": direct["direct_read_hash_match"],
            "sampled_bf16_values": str(sample_count),
            "sampled_finite_values": str(finite_count),
            "sampled_nan_values": str(nan_count),
            "sampled_inf_values": str(inf_count),
            "sampled_zero_values": str(zero_count),
            "sampled_nonzero_values": str(nonzero_count),
            "sampled_min_fp32": f"{min_value:.9g}",
            "sampled_max_fp32": f"{max_value:.9g}",
            "sampled_mean_fp32": f"{mean:.9g}",
            "sampled_mean_abs_fp32": f"{mean_abs:.9g}",
            "sampled_rms_fp32": f"{rms:.9g}",
            "first_sample_bf16_hex": first_hex,
            "last_sample_bf16_hex": last_hex,
            "moe_expert_page": binding["moe_expert_page"],
            "embedding_page": binding["embedding_page"],
            "bf16_tensor_slice_stats_ready": "1" if finite_count == sample_count and segment_hash_bound else "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )

stats_ready = int(
    len(slice_rows) == 16
    and sampled_total == len(slice_rows) * samples_per_slice
    and finite_total == sampled_total
    and nan_total == 0
    and inf_total == 0
    and slice_hash_match_rows == len(slice_rows)
)

metric_rows = [
    {
        "metric_id": "v61aa_hotset_tensor_slice_metrics",
        "tensor_slice_rows": str(len(slice_rows)),
        "moe_tensor_slice_rows": str(moe_slice_rows),
        "embedding_tensor_slice_rows": str(embedding_slice_rows),
        "tensor_segment_bytes_bound": str(tensor_segment_bytes_total),
        "sampled_bf16_value_rows": str(sampled_total),
        "sampled_bf16_finite_rows": str(finite_total),
        "sampled_bf16_nan_rows": str(nan_total),
        "sampled_bf16_inf_rows": str(inf_total),
        "sampled_bf16_nonzero_rows": str(nonzero_total),
        "slice_hash_match_rows": str(slice_hash_match_rows),
        "bf16_tensor_slice_stats_ready": str(stats_ready),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "full_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
]

runtime_gap_rows = [
    {"gap": "v61z-direct-io-hotset-input", "status": "ready", "evidence": "16 direct-I/O reads match remote page hashes"},
    {"gap": "v61v-tensor-binding-input", "status": "ready", "evidence": "16 remote-hashed pages are bound to real tensor segments"},
    {"gap": "bf16-tensor-slice-stats", "status": "ready" if stats_ready else "blocked", "evidence": f"{finite_total}/{sampled_total} sampled BF16 values are finite"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only sampled hotset pages are materialized"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "tensor slice stats do not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "tensor slice stats are not production runtime latency"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61z-direct-io-hotset-input", "status": "pass", "reason": "sampled hotset pages are locally direct-read and hash verified"},
    {"gate": "v61v-tensor-binding-input", "status": "pass", "reason": "sampled pages are bound to real safetensors tensor segments"},
    {"gate": "bf16-tensor-slice-stats", "status": "pass" if stats_ready else "blocked", "reason": f"{finite_total}/{sampled_total} sampled BF16 values are finite"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived stats only; checkpoint payload bytes remain outside the repository"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "tensor slice stats are not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "hotset_tensor_slice_stat_rows.csv", list(slice_rows[0].keys()), slice_rows)
write_csv(run_dir / "hotset_tensor_slice_sample_value_rows.csv", list(sample_rows[0].keys()), sample_rows)
write_csv(run_dir / "hotset_tensor_slice_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61aa_hotset_tensor_slice_verifier_ready": "1",
    "v61z_hotset_direct_io_replay_ready": v61z_summary["v61z_hotset_direct_io_replay_ready"],
    "v61v_remote_page_tensor_binding_ready": v61v_summary["v61v_remote_page_tensor_binding_ready"],
    "model_id": model_id,
    "tensor_slice_rows": str(len(slice_rows)),
    "moe_tensor_slice_rows": str(moe_slice_rows),
    "embedding_tensor_slice_rows": str(embedding_slice_rows),
    "tensor_segment_bytes_bound": str(tensor_segment_bytes_total),
    "sampled_bf16_value_rows": str(sampled_total),
    "sampled_bf16_finite_rows": str(finite_total),
    "sampled_bf16_nan_rows": str(nan_total),
    "sampled_bf16_inf_rows": str(inf_total),
    "sampled_bf16_nonzero_rows": str(nonzero_total),
    "slice_hash_match_rows": str(slice_hash_match_rows),
    "bf16_tensor_slice_stats_ready": str(stats_ready),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61aa_hotset_tensor_slice_verifier",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61aa_hotset_tensor_slice_verifier_ready": 1,
    "tensor_slice_rows": len(slice_rows),
    "tensor_segment_bytes_bound": tensor_segment_bytes_total,
    "sampled_bf16_value_rows": sampled_total,
    "sampled_bf16_finite_rows": finite_total,
    "sampled_bf16_nan_rows": nan_total,
    "sampled_bf16_inf_rows": inf_total,
    "slice_hash_match_rows": slice_hash_match_rows,
    "bf16_tensor_slice_stats_ready": stats_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "full_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61aa_hotset_tensor_slice_verifier_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61aa Hotset Tensor Slice Verifier Boundary

This artifact interprets the bounded v61y/v61z local hotset pages as BF16
tensor segments using the real v61v safetensors tensor/page bindings.

Evidence emitted:

- tensor_slice_rows={len(slice_rows)}
- moe_tensor_slice_rows={moe_slice_rows}
- embedding_tensor_slice_rows={embedding_slice_rows}
- tensor_segment_bytes_bound={tensor_segment_bytes_total}
- sampled_bf16_value_rows={sampled_total}
- sampled_bf16_finite_rows={finite_total}
- sampled_bf16_nan_rows={nan_total}
- sampled_bf16_inf_rows={inf_total}
- sampled_bf16_nonzero_rows={nonzero_total}
- slice_hash_match_rows={slice_hash_match_rows}
- bf16_tensor_slice_stats_ready={stats_ready}
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is tensor-slice/stat evidence over sampled real checkpoint pages. It is
not full Mixtral checkpoint materialization, full page-hash coverage, real
Mixtral generation, near-frontier quality, production latency, or release
evidence.
"""
(run_dir / "V61AA_HOTSET_TENSOR_SLICE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61aa_hotset_tensor_slice_verifier_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
