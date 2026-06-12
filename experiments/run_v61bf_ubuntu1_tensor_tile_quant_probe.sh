#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bf_ubuntu1_tensor_tile_quant_probe"
RUN_ID="${V61BF_RUN_ID:-probe_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bf_ubuntu1_tensor_tile_quant_probe_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61be_ubuntu1_hotset_tensor_slice_verifier.sh" >/dev/null

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

model_id = "mistralai/Mixtral-8x22B-v0.1"
tiles_per_slice = int(os.environ.get("V61BF_TILES_PER_SLICE", "8"))
tile_elements_target = int(os.environ.get("V61BF_TILE_BF16_VALUES", "4096"))
if tiles_per_slice <= 0:
    raise SystemExit("V61BF_TILES_PER_SLICE must be positive")
if tile_elements_target <= 0:
    raise SystemExit("V61BF_TILE_BF16_VALUES must be positive")


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


def tile_starts(element_count, tile_elements, tile_count):
    if element_count < tile_elements:
        tile_elements = element_count
    if tile_elements <= 0:
        return []
    span = max(0, element_count - tile_elements)
    if tile_count == 1 or span == 0:
        return [0]
    return sorted({round(i * span / (tile_count - 1)) for i in range(tile_count)})


def activation_value(tile_ordinal, offset):
    phase = (tile_ordinal + 1) * (offset + 1)
    return math.sin(phase * 0.017) * 0.5 + math.cos((offset + 1) * 0.011) * 0.25


def quantize_dequantize(values, bits):
    qmax = (1 << (bits - 1)) - 1
    max_abs = max((abs(v) for v in values), default=0.0)
    if max_abs == 0.0:
        return [0.0 for _ in values], 1.0
    scale = max_abs / qmax
    dequantized = []
    for value in values:
        q = int(round(value / scale))
        q = max(-qmax, min(qmax, q))
        dequantized.append(q * scale)
    return dequantized, scale


def fmt(value):
    if math.isfinite(value):
        return f"{value:.9g}"
    return str(value)


v61be_dir = results / "v61be_ubuntu1_hotset_tensor_slice_verifier" / "verify_001"
v61be_summary_path = results / "v61be_ubuntu1_hotset_tensor_slice_verifier_summary.csv"
v61be_summary = read_csv(v61be_summary_path)[0]
if v61be_summary.get("v61be_ubuntu1_hotset_tensor_slice_verifier_ready") != "1":
    raise SystemExit("v61bf requires v61be_ubuntu1_hotset_tensor_slice_verifier_ready=1")
if v61be_summary.get("ubuntu1_bf16_tensor_slice_stats_ready") != "1":
    raise SystemExit("v61bf requires ubuntu1_bf16_tensor_slice_stats_ready=1")

selected_target_path = v61be_summary["selected_target_path"]
ubuntu1_hotset_root = v61be_summary["ubuntu1_hotset_root"]

for src, rel in [
    (v61be_summary_path, "source_v61be/v61be_ubuntu1_hotset_tensor_slice_verifier_summary.csv"),
    (results / "v61be_ubuntu1_hotset_tensor_slice_verifier_decision.csv", "source_v61be/v61be_ubuntu1_hotset_tensor_slice_verifier_decision.csv"),
    (v61be_dir / "ubuntu1_hotset_tensor_slice_stat_rows.csv", "source_v61be/ubuntu1_hotset_tensor_slice_stat_rows.csv"),
    (v61be_dir / "ubuntu1_hotset_tensor_slice_metric_rows.csv", "source_v61be/ubuntu1_hotset_tensor_slice_metric_rows.csv"),
    (v61be_dir / "runtime_gap_rows.csv", "source_v61be/runtime_gap_rows.csv"),
    (v61be_dir / "sha256_manifest.csv", "source_v61be/sha256_manifest.csv"),
]:
    copy(src, rel)

slice_rows = read_csv(v61be_dir / "ubuntu1_hotset_tensor_slice_stat_rows.csv")
if len(slice_rows) != 16:
    raise SystemExit("v61bf expects 16 v61be tensor slice rows")

tile_rows = []
sample_rows = []
tile_ordinal = 0
total_tile_values = 0
finite_baseline_rows = 0
finite_q8_rows = 0
finite_q4_rows = 0
finite_q8_error_rows = 0
finite_q4_error_rows = 0
ubuntu1_page_hash_match_rows = 0
direct_read_hash_match_rows = 0
moe_tile_rows = 0
embedding_tile_rows = 0
q8_abs_errors = []
q4_abs_errors = []

for slice_row in slice_rows:
    ubuntu1_path = Path(slice_row["ubuntu1_page_path"])
    page = ubuntu1_path.read_bytes()
    ubuntu1_sha = sha256_bytes(page)
    if ubuntu1_sha != slice_row["remote_page_sha256"]:
        raise SystemExit(f"v61bf page hash mismatch for {slice_row['remote_sample_id']}")
    if slice_row["ubuntu1_page_hash_match"] != "1":
        raise SystemExit(f"v61bf missing v61be page hash witness for {slice_row['remote_sample_id']}")
    if slice_row["direct_read_hash_match"] != "1":
        raise SystemExit(f"v61bf missing v61bd direct-read witness for {slice_row['remote_sample_id']}")
    ubuntu1_page_hash_match_rows += 1
    direct_read_hash_match_rows += 1
    page_start = int(slice_row["page_offset_start"])
    page_end = int(slice_row["page_offset_end"])
    segment = page[page_start:page_end]
    segment_sha = sha256_bytes(segment)
    if segment_sha != slice_row["tensor_segment_sha256"]:
        raise SystemExit(f"v61bf segment hash mismatch for {slice_row['ubuntu1_tensor_slice_id']}")
    element_count = int(slice_row["tensor_segment_elements"])
    tile_elements = min(tile_elements_target, element_count)
    starts = tile_starts(element_count, tile_elements, tiles_per_slice)
    if len(starts) != tiles_per_slice:
        raise SystemExit(f"v61bf tile planner produced {len(starts)} starts for {slice_row['ubuntu1_tensor_slice_id']}")
    for tile_index, start_element in enumerate(starts):
        byte_start = start_element * 2
        byte_end = byte_start + tile_elements * 2
        tile_bytes = segment[byte_start:byte_end]
        if len(tile_bytes) != tile_elements * 2:
            raise SystemExit(f"v61bf short tile read for {slice_row['ubuntu1_tensor_slice_id']}")
        values = [
            bf16_to_float32(int.from_bytes(tile_bytes[i:i + 2], "little"))
            for i in range(0, len(tile_bytes), 2)
        ]
        if not all(math.isfinite(v) for v in values):
            raise SystemExit(f"v61bf nonfinite BF16 tile value for {slice_row['ubuntu1_tensor_slice_id']}")
        activations = [activation_value(tile_ordinal, i) for i in range(tile_elements)]
        q8_values, q8_scale = quantize_dequantize(values, 8)
        q4_values, q4_scale = quantize_dequantize(values, 4)
        baseline_dot = math.fsum(v * a for v, a in zip(values, activations))
        q8_dot = math.fsum(v * a for v, a in zip(q8_values, activations))
        q4_dot = math.fsum(v * a for v, a in zip(q4_values, activations))
        q8_abs_error = abs(q8_dot - baseline_dot)
        q4_abs_error = abs(q4_dot - baseline_dot)
        denom = max(1.0, abs(baseline_dot))
        q8_rel_error = q8_abs_error / denom
        q4_rel_error = q4_abs_error / denom
        baseline_finite = math.isfinite(baseline_dot)
        q8_finite = math.isfinite(q8_dot)
        q4_finite = math.isfinite(q4_dot)
        q8_error_finite = math.isfinite(q8_abs_error) and math.isfinite(q8_rel_error)
        q4_error_finite = math.isfinite(q4_abs_error) and math.isfinite(q4_rel_error)
        weight_mean_abs = math.fsum(abs(v) for v in values) / tile_elements
        weight_rms = math.sqrt(math.fsum(v * v for v in values) / tile_elements)
        weight_max_abs = max(abs(v) for v in values)
        finite_baseline_rows += int(baseline_finite)
        finite_q8_rows += int(q8_finite)
        finite_q4_rows += int(q4_finite)
        finite_q8_error_rows += int(q8_error_finite)
        finite_q4_error_rows += int(q4_error_finite)
        total_tile_values += tile_elements
        q8_abs_errors.append(q8_abs_error)
        q4_abs_errors.append(q4_abs_error)
        if slice_row["moe_expert_page"] == "1":
            moe_tile_rows += 1
        if slice_row["embedding_page"] == "1":
            embedding_tile_rows += 1
        tile_id = f"v61bf_ubuntu1_tile_{tile_ordinal:04d}"
        tile_rows.append(
            {
                "ubuntu1_tile_id": tile_id,
                "ubuntu1_tensor_slice_id": slice_row["ubuntu1_tensor_slice_id"],
                "binding_id": slice_row["binding_id"],
                "remote_sample_id": slice_row["remote_sample_id"],
                "model_id": model_id,
                "shard_name": slice_row["shard_name"],
                "shard_page_index": slice_row["shard_page_index"],
                "tensor_name": slice_row["tensor_name"],
                "tensor_role": slice_row["tensor_role"],
                "layer_index": slice_row["layer_index"],
                "expert_index": slice_row["expert_index"],
                "ubuntu1_page_path": str(ubuntu1_path),
                "tile_index_in_slice": str(tile_index),
                "element_start_in_segment": str(start_element),
                "element_end_in_segment": str(start_element + tile_elements),
                "tile_bf16_values": str(tile_elements),
                "tile_byte_start_in_page": str(page_start + byte_start),
                "tile_byte_end_in_page": str(page_start + byte_end),
                "tile_sha256": sha256_bytes(tile_bytes),
                "tensor_segment_sha256": slice_row["tensor_segment_sha256"],
                "ubuntu1_page_sha256": ubuntu1_sha,
                "remote_page_sha256": slice_row["remote_page_sha256"],
                "ubuntu1_page_hash_match": slice_row["ubuntu1_page_hash_match"],
                "direct_read_hash_match": slice_row["direct_read_hash_match"],
                "direct_io_used": slice_row["direct_io_used"],
                "tile_hash_bound_to_remote_page": "1",
                "baseline_dot_fp32": fmt(baseline_dot),
                "q8_dot_fp32": fmt(q8_dot),
                "q4_dot_fp32": fmt(q4_dot),
                "q8_abs_error": fmt(q8_abs_error),
                "q4_abs_error": fmt(q4_abs_error),
                "q8_rel_error": fmt(q8_rel_error),
                "q4_rel_error": fmt(q4_rel_error),
                "weight_mean_abs_fp32": fmt(weight_mean_abs),
                "weight_rms_fp32": fmt(weight_rms),
                "weight_max_abs_fp32": fmt(weight_max_abs),
                "q8_scale": fmt(q8_scale),
                "q4_scale": fmt(q4_scale),
                "baseline_dot_finite": "1" if baseline_finite else "0",
                "q8_dot_finite": "1" if q8_finite else "0",
                "q4_dot_finite": "1" if q4_finite else "0",
                "q8_error_finite": "1" if q8_error_finite else "0",
                "q4_error_finite": "1" if q4_error_finite else "0",
                "moe_expert_tile": slice_row["moe_expert_page"],
                "embedding_tile": slice_row["embedding_page"],
                "checkpoint_payload_bytes_downloaded_by_v61bf": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "actual_model_generation_ready": "0",
                "route_jump_rows": "0",
            }
        )
        for sample_offset in [0, tile_elements // 2, tile_elements - 1]:
            sample_rows.append(
                {
                    "sample_id": f"{tile_id}_sample_{sample_offset:04d}",
                    "ubuntu1_tile_id": tile_id,
                    "ubuntu1_tensor_slice_id": slice_row["ubuntu1_tensor_slice_id"],
                    "sample_offset_in_tile": str(sample_offset),
                    "bf16_value_fp32": fmt(values[sample_offset]),
                    "activation_fp32": fmt(activations[sample_offset]),
                    "q8_dequant_fp32": fmt(q8_values[sample_offset]),
                    "q4_dequant_fp32": fmt(q4_values[sample_offset]),
                    "checkpoint_payload_bytes_downloaded_by_v61bf": "0",
                    "checkpoint_payload_bytes_committed_to_repo": "0",
                }
            )
        tile_ordinal += 1

tile_count = len(tile_rows)
q8_mean_abs_error = math.fsum(q8_abs_errors) / tile_count if tile_count else 0.0
q4_mean_abs_error = math.fsum(q4_abs_errors) / tile_count if tile_count else 0.0
numeric_ready = int(
    tile_count == len(slice_rows) * tiles_per_slice
    and total_tile_values == tile_count * tile_elements_target
    and finite_baseline_rows == tile_count
    and finite_q8_rows == tile_count
    and finite_q4_rows == tile_count
    and finite_q8_error_rows == tile_count
    and finite_q4_error_rows == tile_count
    and ubuntu1_page_hash_match_rows == len(slice_rows)
    and direct_read_hash_match_rows == len(slice_rows)
)

metric_rows = [
    {
        "metric_id": "v61bf_ubuntu1_tensor_tile_quant_metrics",
        "model_id": model_id,
        "selected_target_path": selected_target_path,
        "ubuntu1_hotset_root": ubuntu1_hotset_root,
        "tensor_slice_rows": str(len(slice_rows)),
        "tensor_tile_probe_rows": str(tile_count),
        "moe_tensor_tile_probe_rows": str(moe_tile_rows),
        "embedding_tensor_tile_probe_rows": str(embedding_tile_rows),
        "tile_bf16_value_rows": str(total_tile_values),
        "tile_sample_trace_rows": str(len(sample_rows)),
        "finite_baseline_dot_rows": str(finite_baseline_rows),
        "finite_q8_dot_rows": str(finite_q8_rows),
        "finite_q4_dot_rows": str(finite_q4_rows),
        "finite_q8_error_rows": str(finite_q8_error_rows),
        "finite_q4_error_rows": str(finite_q4_error_rows),
        "q8_abs_error_mean": fmt(q8_mean_abs_error),
        "q4_abs_error_mean": fmt(q4_mean_abs_error),
        "q8_abs_error_max": fmt(max(q8_abs_errors) if q8_abs_errors else 0.0),
        "q4_abs_error_max": fmt(max(q4_abs_errors) if q4_abs_errors else 0.0),
        "ubuntu1_page_hash_match_rows": str(ubuntu1_page_hash_match_rows),
        "direct_read_hash_match_rows": str(direct_read_hash_match_rows),
        "ubuntu1_numeric_tile_probe_ready": str(numeric_ready),
        "ubuntu1_q8_quant_probe_ready": str(numeric_ready),
        "ubuntu1_q4_quant_probe_ready": str(numeric_ready),
        "checkpoint_payload_bytes_downloaded_by_v61bf": "0",
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
    {"gap": "v61be-ubuntu1-bf16-tensor-slice-input", "status": "ready", "evidence": "16 ubuntu-1 resident real checkpoint tensor slices are hash-bound and finite"},
    {"gap": "ubuntu1-bf16-dot-tile-probe", "status": "ready" if numeric_ready else "blocked", "evidence": f"{finite_baseline_rows}/{tile_count} baseline dot tiles are finite"},
    {"gap": "ubuntu1-q8-q4-quant-probe", "status": "ready" if numeric_ready else "blocked", "evidence": f"{finite_q8_error_rows}/{tile_count} q8 and {finite_q4_error_rows}/{tile_count} q4 quantized dot errors are finite"},
    {"gap": "explicit-download-execution", "status": "blocked", "evidence": "v61bf performs no checkpoint download"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only bounded sampled hotset pages are resident on ubuntu-1"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "numeric tiles do not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "bounded tile probes are not production runtime latency"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61be-ubuntu1-bf16-tensor-slice-input", "status": "pass", "reason": "v61be supplies ubuntu-1 resident hash-bound BF16 tensor slice rows"},
    {"gate": "ubuntu1-bf16-dot-tile-probe", "status": "pass" if numeric_ready else "blocked", "reason": f"{finite_baseline_rows}/{tile_count} baseline dot tiles are finite"},
    {"gate": "ubuntu1-q8-q4-quant-probe", "status": "pass" if numeric_ready else "blocked", "reason": "bounded q8/q4 dequantized dot errors are finite"},
    {"gate": "no-network-download-by-v61bf", "status": "pass", "reason": "checkpoint_payload_bytes_downloaded_by_v61bf=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived rows only; checkpoint payload bytes remain outside the repository"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "full checkpoint payload download remains disabled"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "tile probes are not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "ubuntu1_tensor_tile_probe_rows.csv", list(tile_rows[0].keys()), tile_rows)
write_csv(run_dir / "ubuntu1_tensor_tile_sample_trace_rows.csv", list(sample_rows[0].keys()), sample_rows)
write_csv(run_dir / "ubuntu1_tensor_tile_quant_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61bf_ubuntu1_tensor_tile_quant_probe_ready": str(numeric_ready),
    "v61be_ubuntu1_hotset_tensor_slice_verifier_ready": v61be_summary["v61be_ubuntu1_hotset_tensor_slice_verifier_ready"],
    "model_id": model_id,
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "tensor_slice_rows": str(len(slice_rows)),
    "tensor_tile_probe_rows": str(tile_count),
    "moe_tensor_tile_probe_rows": str(moe_tile_rows),
    "embedding_tensor_tile_probe_rows": str(embedding_tile_rows),
    "tile_bf16_value_rows": str(total_tile_values),
    "tile_sample_trace_rows": str(len(sample_rows)),
    "finite_baseline_dot_rows": str(finite_baseline_rows),
    "finite_q8_dot_rows": str(finite_q8_rows),
    "finite_q4_dot_rows": str(finite_q4_rows),
    "finite_q8_error_rows": str(finite_q8_error_rows),
    "finite_q4_error_rows": str(finite_q4_error_rows),
    "q8_abs_error_mean": fmt(q8_mean_abs_error),
    "q4_abs_error_mean": fmt(q4_mean_abs_error),
    "q8_abs_error_max": fmt(max(q8_abs_errors) if q8_abs_errors else 0.0),
    "q4_abs_error_max": fmt(max(q4_abs_errors) if q4_abs_errors else 0.0),
    "ubuntu1_page_hash_match_rows": str(ubuntu1_page_hash_match_rows),
    "direct_read_hash_match_rows": str(direct_read_hash_match_rows),
    "ubuntu1_numeric_tile_probe_ready": str(numeric_ready),
    "ubuntu1_q8_quant_probe_ready": str(numeric_ready),
    "ubuntu1_q4_quant_probe_ready": str(numeric_ready),
    "checkpoint_payload_bytes_downloaded_by_v61bf": "0",
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
    "artifact": "v61bf_ubuntu1_tensor_tile_quant_probe",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "v61bf_ubuntu1_tensor_tile_quant_probe_ready": numeric_ready,
    "tensor_tile_probe_rows": tile_count,
    "tile_bf16_value_rows": total_tile_values,
    "finite_baseline_dot_rows": finite_baseline_rows,
    "finite_q8_dot_rows": finite_q8_rows,
    "finite_q4_dot_rows": finite_q4_rows,
    "q8_abs_error_mean": q8_mean_abs_error,
    "q4_abs_error_mean": q4_mean_abs_error,
    "ubuntu1_page_hash_match_rows": ubuntu1_page_hash_match_rows,
    "direct_read_hash_match_rows": direct_read_hash_match_rows,
    "checkpoint_payload_bytes_downloaded_by_v61bf": 0,
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
(run_dir / "v61bf_ubuntu1_tensor_tile_quant_probe_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

boundary = f"""# v61bf ubuntu-1 Tensor Tile Quant Probe Boundary

This artifact consumes the v61be ubuntu-1 resident real-checkpoint BF16 tensor
slices and runs bounded numeric dot-tile probes plus q8/q4 dequantized dot
probes. It does not execute Mixtral generation.

Evidence emitted:

- selected_target_path={selected_target_path}
- ubuntu1_hotset_root={ubuntu1_hotset_root}
- tensor_tile_probe_rows={tile_count}
- moe_tensor_tile_probe_rows={moe_tile_rows}
- embedding_tensor_tile_probe_rows={embedding_tile_rows}
- tile_bf16_value_rows={total_tile_values}
- finite_baseline_dot_rows={finite_baseline_rows}
- finite_q8_dot_rows={finite_q8_rows}
- finite_q4_dot_rows={finite_q4_rows}
- finite_q8_error_rows={finite_q8_error_rows}
- finite_q4_error_rows={finite_q4_error_rows}
- ubuntu1_page_hash_match_rows={ubuntu1_page_hash_match_rows}
- direct_read_hash_match_rows={direct_read_hash_match_rows}
- ubuntu1_q8_quant_probe_ready={numeric_ready}
- ubuntu1_q4_quant_probe_ready={numeric_ready}
- checkpoint_payload_bytes_downloaded_by_v61bf=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- real_100b_open_weight_materialized=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is bounded numeric/quantization evidence over sampled real checkpoint
pages resident under the ubuntu-1 target. It is not full Mixtral checkpoint
materialization, full page-hash coverage, real Mixtral generation,
near-frontier quality, production latency, or release evidence.
"""
(run_dir / "V61BF_UBUNTU1_TENSOR_TILE_QUANT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bf_ubuntu1_tensor_tile_quant_probe_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
