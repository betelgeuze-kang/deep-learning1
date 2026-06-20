#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ab_hotset_tensor_tile_quant_probe"
RUN_ID="${V61AB_RUN_ID:-probe_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ab_hotset_tensor_tile_quant_probe_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61aa_hotset_tensor_slice_verifier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import os
import shutil
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import torch

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

model_id = "mistralai/Mixtral-8x22B-v0.1"
tiles_per_slice = int(os.environ.get("V61AB_TILES_PER_SLICE", "8"))
tile_elements_target = int(os.environ.get("V61AB_TILE_BF16_VALUES", "4096"))
expert_ffn_root_raw = os.environ.get("V61AB_EXPERT_FFN_CHECKPOINT_ROOT", "").strip()
expert_ffn_layer = int(os.environ.get("V61AB_EXPERT_FFN_LAYER", "0"))
expert_ffn_expert = int(os.environ.get("V61AB_EXPERT_FFN_EXPERT", "0"))
expert_ffn_token_id = os.environ.get("V61AB_EXPERT_FFN_TOKEN_ID", "0")
expert_ffn_router_top_k = os.environ.get("V61AB_EXPERT_FFN_ROUTER_TOP_K", "2")
expert_ffn_model_revision = os.environ.get("V61AB_MODEL_REVISION", "not-supplied")
expert_ffn_tokenizer_revision = os.environ.get("V61AB_TOKENIZER_REVISION", "not-supplied")
expert_ffn_real_model_evidence_requested = int(os.environ.get("V61AB_EXPERT_FFN_REAL_MODEL_EVIDENCE", "0") == "1")
expert_ffn_runtime_bin = Path(
    os.environ.get("V61AB_EXPERT_FFN_RUNTIME_BIN", str(root / "build" / "expert_ffn_forward_parity"))
).expanduser()
if tiles_per_slice <= 0:
    raise SystemExit("V61AB_TILES_PER_SLICE must be positive")
if tile_elements_target <= 0:
    raise SystemExit("V61AB_TILE_BF16_VALUES must be positive")
torch.set_num_threads(1)


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


def bf16_bytes_to_torch_float32(data, shape):
    raw = np.frombuffer(data, dtype="<u2")
    fp32 = (raw.astype(np.uint32) << 16).view(np.float32)
    expected = math.prod(shape)
    if fp32.size != expected:
        raise RuntimeError(f"BF16 tensor element mismatch: {fp32.size} != {expected}")
    return torch.from_numpy(fp32.copy()).reshape(shape).to(torch.float32)


def tensor_bytes_to_torch(data, dtype, shape):
    if dtype == "BF16":
        return bf16_bytes_to_torch_float32(data, shape)
    if dtype == "F32":
        fp32 = np.frombuffer(data, dtype="<f4").copy()
        expected = math.prod(shape)
        if fp32.size != expected:
            raise RuntimeError(f"F32 tensor element mismatch: {fp32.size} != {expected}")
        return torch.from_numpy(fp32).reshape(shape).to(torch.float32)
    raise RuntimeError(f"unsupported expert FFN dtype: {dtype}")


def read_safetensors_tensor(checkpoint_root, index_json, tensor_name):
    weight_map = index_json.get("weight_map", {})
    shard_name = weight_map.get(tensor_name)
    if not shard_name:
        raise RuntimeError(f"tensor missing from weight_map: {tensor_name}")
    shard_path = checkpoint_root / shard_name
    with shard_path.open("rb") as handle:
        header_len_bytes = handle.read(8)
        if len(header_len_bytes) != 8:
            raise RuntimeError(f"short safetensors header length: {shard_name}")
        header_len = struct.unpack("<Q", header_len_bytes)[0]
        header = json.loads(handle.read(header_len).decode("utf-8"))
        spec = header.get(tensor_name)
        if spec is None:
            raise RuntimeError(f"tensor missing from shard header: {tensor_name}")
        offsets = spec["data_offsets"]
        data_base = 8 + header_len
        handle.seek(data_base + int(offsets[0]))
        data = handle.read(int(offsets[1]) - int(offsets[0]))
    return {
        "tensor": tensor_bytes_to_torch(data, spec["dtype"], list(spec["shape"])),
        "shard_name": shard_name,
        "dtype": spec["dtype"],
        "shape": "x".join(str(x) for x in spec["shape"]),
        "payload_bytes": len(data),
        "payload_sha256": sha256_bytes(data),
    }


def expert_ffn_parity_rows():
    tensor_prefix = f"model.layers.{expert_ffn_layer}.block_sparse_moe.experts.{expert_ffn_expert}"
    rmsnorm_tensor_name = f"model.layers.{expert_ffn_layer}.input_layernorm.weight"
    router_tensor_name = f"model.layers.{expert_ffn_layer}.block_sparse_moe.gate.weight"
    tensor_names = {
        "w1": f"{tensor_prefix}.w1.weight",
        "w2": f"{tensor_prefix}.w2.weight",
        "w3": f"{tensor_prefix}.w3.weight",
    }
    base_row = {
        "checkpoint_id": model_id,
        "model_revision": expert_ffn_model_revision,
        "config_sha256": "",
        "tokenizer_revision": expert_ffn_tokenizer_revision,
        "shard_index_sha256": "",
        "full_manifest_sha256": "",
        "layer_index": str(expert_ffn_layer),
        "expert_index": str(expert_ffn_expert),
        "token_id": str(expert_ffn_token_id),
        "router_top_k": str(expert_ffn_router_top_k),
        "rmsnorm_tensor_name": rmsnorm_tensor_name,
        "rmsnorm_payload_sha256": "",
        "router_tensor_name": router_tensor_name,
        "router_payload_sha256": "",
        "w1_tensor_name": tensor_names["w1"],
        "w2_tensor_name": tensor_names["w2"],
        "w3_tensor_name": tensor_names["w3"],
        "contract_ready": "1",
        "fixture_execution_ready": "0",
        "real_model_execution_ready": "0",
        "heldout_metric_ready": "0",
        "human_review_ready": "0",
        "independent_reproduction_ready": "0",
        "release_ready": "0",
        "local_checkpoint_root_supplied": "1" if expert_ffn_root_raw else "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
        "route_jump_rows": "0",
    }
    if not expert_ffn_root_raw:
        row = dict(base_row)
        row.update({
            "status": "blocked",
            "reason": "V61AB_EXPERT_FFN_CHECKPOINT_ROOT not supplied",
            "w1_shape": "",
            "w2_shape": "",
            "w3_shape": "",
            "w1_payload_sha256": "",
            "w2_payload_sha256": "",
            "w3_payload_sha256": "",
            "input_hidden_size": "0",
            "intermediate_size": "0",
            "output_hidden_size": "0",
            "residual_input_sha256": "",
            "residual_output_sha256": "",
            "transformers_capture_backend": "",
            "transformers_capture_module_path": "",
            "transformers_capture_artifact_sha256": "",
            "transformers_expert_output_sha256": "",
            "independent_runtime_output_sha256": "",
            "candidate_output_sha256": "",
            "torch_reference_output_sha256": "",
            "max_abs_delta": "",
            "tolerance": "1e-06",
            "expert_ffn_parity_pass": "0",
        })
        return [row]
    checkpoint_root = Path(expert_ffn_root_raw).expanduser().resolve()
    index_path = checkpoint_root / "model.safetensors.index.json"
    row = dict(base_row)
    try:
        row["shard_index_sha256"] = sha256(index_path)
        config_path = checkpoint_root / "config.json"
        tokenizer_path = checkpoint_root / "tokenizer.json"
        if config_path.is_file():
            row["config_sha256"] = sha256(config_path)
        if tokenizer_path.is_file():
            row["tokenizer_revision"] = expert_ffn_tokenizer_revision
            row["full_manifest_sha256"] = sha256_bytes(
                (row["shard_index_sha256"] + row["config_sha256"] + sha256(tokenizer_path)).encode("utf-8")
            )
        else:
            row["full_manifest_sha256"] = sha256_bytes((row["shard_index_sha256"] + row["config_sha256"]).encode("utf-8"))
        index_json = json.loads(index_path.read_text(encoding="utf-8"))
        rmsnorm = read_safetensors_tensor(checkpoint_root, index_json, rmsnorm_tensor_name)
        router = read_safetensors_tensor(checkpoint_root, index_json, router_tensor_name)
        w1 = read_safetensors_tensor(checkpoint_root, index_json, tensor_names["w1"])
        w2 = read_safetensors_tensor(checkpoint_root, index_json, tensor_names["w2"])
        w3 = read_safetensors_tensor(checkpoint_root, index_json, tensor_names["w3"])
        w1_t = w1["tensor"]
        w2_t = w2["tensor"]
        w3_t = w3["tensor"]
        if w1_t.ndim != 2 or w2_t.ndim != 2 or w3_t.ndim != 2:
            raise RuntimeError("expert FFN tensors must be rank-2")
        if w1_t.shape != w3_t.shape:
            raise RuntimeError(f"w1/w3 shape mismatch: {tuple(w1_t.shape)} != {tuple(w3_t.shape)}")
        if w2_t.shape[1] != w1_t.shape[0] or w2_t.shape[0] != w1_t.shape[1]:
            raise RuntimeError(f"w2 shape incompatible with w1/w3: w1={tuple(w1_t.shape)} w2={tuple(w2_t.shape)}")
        hidden = int(w1_t.shape[1])
        inter = int(w1_t.shape[0])
        x = torch.linspace(-0.5, 0.5, hidden, dtype=torch.float32)
        if not expert_ffn_runtime_bin.is_file():
            raise RuntimeError(f"independent expert FFN runtime missing: {expert_ffn_runtime_bin}")
        gate = torch.nn.functional.silu(torch.matmul(w1_t, x))
        up = torch.matmul(w3_t, x)
        reference = torch.nn.functional.linear((gate * up).reshape(1, inter), w2_t).reshape(hidden)
        runtime_dir = run_dir / "expert_ffn_runtime_inputs"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        runtime_files = {
            "w1": runtime_dir / "w1.f32",
            "w2": runtime_dir / "w2.f32",
            "w3": runtime_dir / "w3.f32",
            "input": runtime_dir / "input.f32",
            "output": runtime_dir / "independent_output.f32",
        }
        runtime_files["w1"].write_bytes(w1_t.detach().cpu().numpy().astype("<f4").tobytes())
        runtime_files["w2"].write_bytes(w2_t.detach().cpu().numpy().astype("<f4").tobytes())
        runtime_files["w3"].write_bytes(w3_t.detach().cpu().numpy().astype("<f4").tobytes())
        runtime_files["input"].write_bytes(x.detach().cpu().numpy().astype("<f4").tobytes())
        subprocess.run(
            [
                str(expert_ffn_runtime_bin),
                "--hidden",
                str(hidden),
                "--intermediate",
                str(inter),
                "--w1",
                str(runtime_files["w1"]),
                "--w2",
                str(runtime_files["w2"]),
                "--w3",
                str(runtime_files["w3"]),
                "--input",
                str(runtime_files["input"]),
                "--output",
                str(runtime_files["output"]),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        independent = torch.from_numpy(
            np.frombuffer(runtime_files["output"].read_bytes(), dtype="<f4").copy()
        ).reshape(hidden).to(torch.float32)
        delta = torch.max(torch.abs(independent - reference)).item()
        tolerance = 1e-6
        candidate_bytes = independent.detach().cpu().numpy().astype("<f4").tobytes()
        reference_bytes = reference.detach().cpu().numpy().astype("<f4").tobytes()
        residual_input_sha = sha256_bytes(x.detach().cpu().numpy().astype("<f4").tobytes())
        residual_output_sha = sha256_bytes((x + independent).detach().cpu().numpy().astype("<f4").tobytes())
        parity_pass = int(math.isfinite(delta) and delta <= tolerance)
        fixture_ready = parity_pass
        real_model_ready = 0
        reason = (
            "expert FFN fixture tensors loaded from local safetensors root and independent C++ runtime output matches torch reference; "
            "original Transformers module output not supplied"
            if parity_pass
            else "expert FFN parity delta exceeds tolerance"
        )
        if expert_ffn_real_model_evidence_requested and parity_pass:
            reason += "; V61AB_EXPERT_FFN_REAL_MODEL_EVIDENCE is execution-mode metadata only and cannot declare evidence state"
        row.update({
            "status": "pass" if parity_pass else "blocked",
            "reason": reason,
            "fixture_execution_ready": str(fixture_ready),
            "real_model_execution_ready": str(real_model_ready),
            "w1_shape": w1["shape"],
            "w2_shape": w2["shape"],
            "w3_shape": w3["shape"],
            "rmsnorm_payload_sha256": rmsnorm["payload_sha256"],
            "router_payload_sha256": router["payload_sha256"],
            "w1_payload_sha256": w1["payload_sha256"],
            "w2_payload_sha256": w2["payload_sha256"],
            "w3_payload_sha256": w3["payload_sha256"],
            "input_hidden_size": str(hidden),
            "intermediate_size": str(inter),
            "output_hidden_size": str(int(independent.numel())),
            "residual_input_sha256": residual_input_sha,
            "residual_output_sha256": residual_output_sha,
            "transformers_capture_backend": "",
            "transformers_capture_module_path": "",
            "transformers_capture_artifact_sha256": "",
            "transformers_expert_output_sha256": "",
            "independent_runtime_output_sha256": sha256_bytes(candidate_bytes),
            "candidate_output_sha256": sha256_bytes(candidate_bytes),
            "torch_reference_output_sha256": sha256_bytes(reference_bytes),
            "max_abs_delta": fmt(delta),
            "tolerance": fmt(tolerance),
            "expert_ffn_parity_pass": str(parity_pass),
        })
    except Exception as exc:
        row.update({
            "status": "blocked",
            "reason": str(exc),
            "w1_shape": "",
            "w2_shape": "",
            "w3_shape": "",
            "w1_payload_sha256": "",
            "w2_payload_sha256": "",
            "w3_payload_sha256": "",
            "input_hidden_size": "0",
            "intermediate_size": "0",
            "output_hidden_size": "0",
            "residual_input_sha256": "",
            "residual_output_sha256": "",
            "transformers_capture_backend": "",
            "transformers_capture_module_path": "",
            "transformers_capture_artifact_sha256": "",
            "transformers_expert_output_sha256": "",
            "independent_runtime_output_sha256": "",
            "candidate_output_sha256": "",
            "torch_reference_output_sha256": "",
            "max_abs_delta": "",
            "tolerance": "1e-06",
            "expert_ffn_parity_pass": "0",
        })
    return [row]


v61aa_dir = results / "v61aa_hotset_tensor_slice_verifier" / "verify_001"
v61aa_summary = read_csv(results / "v61aa_hotset_tensor_slice_verifier_summary.csv")[0]
if v61aa_summary.get("v61aa_hotset_tensor_slice_verifier_ready") != "1":
    raise SystemExit("v61ab requires v61aa_hotset_tensor_slice_verifier_ready=1")
if v61aa_summary.get("bf16_tensor_slice_stats_ready") != "1":
    raise SystemExit("v61ab requires bf16_tensor_slice_stats_ready=1")

for src, rel in [
    (results / "v61aa_hotset_tensor_slice_verifier_summary.csv", "source_v61aa/v61aa_hotset_tensor_slice_verifier_summary.csv"),
    (results / "v61aa_hotset_tensor_slice_verifier_decision.csv", "source_v61aa/v61aa_hotset_tensor_slice_verifier_decision.csv"),
    (v61aa_dir / "hotset_tensor_slice_stat_rows.csv", "source_v61aa/hotset_tensor_slice_stat_rows.csv"),
    (v61aa_dir / "hotset_tensor_slice_metric_rows.csv", "source_v61aa/hotset_tensor_slice_metric_rows.csv"),
    (v61aa_dir / "runtime_gap_rows.csv", "source_v61aa/runtime_gap_rows.csv"),
    (v61aa_dir / "sha256_manifest.csv", "source_v61aa/sha256_manifest.csv"),
]:
    copy(src, rel)

slice_rows = read_csv(v61aa_dir / "hotset_tensor_slice_stat_rows.csv")
if len(slice_rows) != 16:
    raise SystemExit("v61ab expects 16 v61aa tensor slice rows")

tile_rows = []
sample_rows = []
torch_parity_rows = []
tile_ordinal = 0
total_tile_values = 0
finite_baseline_rows = 0
finite_q8_rows = 0
finite_q4_rows = 0
finite_q8_error_rows = 0
finite_q4_error_rows = 0
torch_matvec_parity_pass_rows = 0
moe_tile_rows = 0
embedding_tile_rows = 0
q8_abs_errors = []
q4_abs_errors = []

for slice_row in slice_rows:
    local_path = Path(slice_row["local_page_path"])
    page = local_path.read_bytes()
    local_sha = sha256_bytes(page)
    if local_sha != slice_row["remote_page_sha256"]:
        raise SystemExit(f"v61ab page hash mismatch for {slice_row['remote_sample_id']}")
    page_start = int(slice_row["page_offset_start"])
    page_end = int(slice_row["page_offset_end"])
    segment = page[page_start:page_end]
    segment_sha = sha256_bytes(segment)
    if segment_sha != slice_row["tensor_segment_sha256"]:
        raise SystemExit(f"v61ab segment hash mismatch for {slice_row['tensor_slice_id']}")
    element_count = int(slice_row["tensor_segment_elements"])
    tile_elements = min(tile_elements_target, element_count)
    starts = tile_starts(element_count, tile_elements, tiles_per_slice)
    if len(starts) != tiles_per_slice:
        raise SystemExit(f"v61ab tile planner produced {len(starts)} starts for {slice_row['tensor_slice_id']}")
    for tile_index, start_element in enumerate(starts):
        byte_start = start_element * 2
        byte_end = byte_start + tile_elements * 2
        tile_bytes = segment[byte_start:byte_end]
        if len(tile_bytes) != tile_elements * 2:
            raise SystemExit(f"v61ab short tile read for {slice_row['tensor_slice_id']}")
        values = [
            bf16_to_float32(int.from_bytes(tile_bytes[i:i + 2], "little"))
            for i in range(0, len(tile_bytes), 2)
        ]
        if not all(math.isfinite(v) for v in values):
            raise SystemExit(f"v61ab nonfinite BF16 tile value for {slice_row['tensor_slice_id']}")
        activations = [activation_value(tile_ordinal, i) for i in range(tile_elements)]
        q8_values, q8_scale = quantize_dequantize(values, 8)
        q4_values, q4_scale = quantize_dequantize(values, 4)
        baseline_dot = math.fsum(v * a for v, a in zip(values, activations))
        q8_dot = math.fsum(v * a for v, a in zip(q8_values, activations))
        q4_dot = math.fsum(v * a for v, a in zip(q4_values, activations))
        torch_values = torch.tensor(values, dtype=torch.float64, device="cpu").reshape(1, tile_elements)
        torch_activations = torch.tensor(activations, dtype=torch.float64, device="cpu").reshape(tile_elements, 1)
        torch_dot = float(torch.matmul(torch_values, torch_activations).item())
        torch_abs_delta = abs(torch_dot - baseline_dot)
        torch_tolerance = 1e-9
        torch_parity_pass = int(math.isfinite(torch_dot) and torch_abs_delta <= torch_tolerance)
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
        torch_matvec_parity_pass_rows += torch_parity_pass
        total_tile_values += tile_elements
        q8_abs_errors.append(q8_abs_error)
        q4_abs_errors.append(q4_abs_error)
        if slice_row["moe_expert_page"] == "1":
            moe_tile_rows += 1
        if slice_row["embedding_page"] == "1":
            embedding_tile_rows += 1
        tile_id = f"v61ab_tile_{tile_ordinal:04d}"
        tile_rows.append(
            {
                "tile_id": tile_id,
                "tensor_slice_id": slice_row["tensor_slice_id"],
                "binding_id": slice_row["binding_id"],
                "remote_sample_id": slice_row["remote_sample_id"],
                "model_id": model_id,
                "shard_name": slice_row["shard_name"],
                "shard_page_index": slice_row["shard_page_index"],
                "tensor_name": slice_row["tensor_name"],
                "tensor_role": slice_row["tensor_role"],
                "layer_index": slice_row["layer_index"],
                "expert_index": slice_row["expert_index"],
                "tile_index_in_slice": str(tile_index),
                "element_start_in_segment": str(start_element),
                "element_end_in_segment": str(start_element + tile_elements),
                "tile_bf16_values": str(tile_elements),
                "tile_byte_start_in_page": str(page_start + byte_start),
                "tile_byte_end_in_page": str(page_start + byte_end),
                "tile_sha256": sha256_bytes(tile_bytes),
                "tensor_segment_sha256": slice_row["tensor_segment_sha256"],
                "remote_page_sha256": slice_row["remote_page_sha256"],
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
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "actual_model_generation_ready": "0",
                "route_jump_rows": "0",
            }
        )
        torch_parity_rows.append(
            {
                "tile_id": tile_id,
                "tensor_slice_id": slice_row["tensor_slice_id"],
                "binding_id": slice_row["binding_id"],
                "remote_sample_id": slice_row["remote_sample_id"],
                "model_id": model_id,
                "shard_name": slice_row["shard_name"],
                "tensor_name": slice_row["tensor_name"],
                "tensor_role": slice_row["tensor_role"],
                "layer_index": slice_row["layer_index"],
                "expert_index": slice_row["expert_index"],
                "dtype_source": "BF16",
                "torch_reference_backend": "torch-cpu-float64-matmul",
                "tile_bf16_values": str(tile_elements),
                "tile_sha256": sha256_bytes(tile_bytes),
                "tensor_segment_sha256": slice_row["tensor_segment_sha256"],
                "remote_page_sha256": slice_row["remote_page_sha256"],
                "python_baseline_dot_fp64": fmt(baseline_dot),
                "torch_matvec_dot_fp64": fmt(torch_dot),
                "torch_abs_delta": fmt(torch_abs_delta),
                "torch_tolerance": fmt(torch_tolerance),
                "torch_matvec_parity_pass": str(torch_parity_pass),
                "real_checkpoint_page_bound": "1",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "actual_model_generation_ready": "0",
                "route_jump_rows": "0",
            }
        )
        for sample_offset in [0, tile_elements // 2, tile_elements - 1]:
            sample_rows.append(
                {
                    "sample_id": f"{tile_id}_sample_{sample_offset:04d}",
                    "tile_id": tile_id,
                    "tensor_slice_id": slice_row["tensor_slice_id"],
                    "sample_offset_in_tile": str(sample_offset),
                    "bf16_value_fp32": fmt(values[sample_offset]),
                    "activation_fp32": fmt(activations[sample_offset]),
                    "q8_dequant_fp32": fmt(q8_values[sample_offset]),
                    "q4_dequant_fp32": fmt(q4_values[sample_offset]),
                    "checkpoint_payload_bytes_committed_to_repo": "0",
                }
            )
        tile_ordinal += 1

tile_count = len(tile_rows)
q8_mean_abs_error = math.fsum(q8_abs_errors) / tile_count if tile_count else 0.0
q4_mean_abs_error = math.fsum(q4_abs_errors) / tile_count if tile_count else 0.0
expert_ffn_rows = expert_ffn_parity_rows()
expert_ffn_row = expert_ffn_rows[0]
numeric_ready = int(
    tile_count == len(slice_rows) * tiles_per_slice
    and total_tile_values == tile_count * tile_elements_target
    and finite_baseline_rows == tile_count
    and finite_q8_rows == tile_count
    and finite_q4_rows == tile_count
    and finite_q8_error_rows == tile_count
    and finite_q4_error_rows == tile_count
    and torch_matvec_parity_pass_rows == tile_count
)

metric_rows = [
    {
        "metric_id": "v61ab_hotset_tensor_tile_quant_metrics",
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
        "torch_matvec_parity_rows": str(len(torch_parity_rows)),
        "torch_matvec_parity_pass_rows": str(torch_matvec_parity_pass_rows),
        "q8_abs_error_mean": fmt(q8_mean_abs_error),
        "q4_abs_error_mean": fmt(q4_mean_abs_error),
        "q8_abs_error_max": fmt(max(q8_abs_errors) if q8_abs_errors else 0.0),
        "q4_abs_error_max": fmt(max(q4_abs_errors) if q4_abs_errors else 0.0),
        "hotset_numeric_tile_probe_ready": str(numeric_ready),
        "q8_quant_probe_ready": str(numeric_ready),
        "q4_quant_probe_ready": str(numeric_ready),
        "torch_matvec_parity_ready": str(numeric_ready),
        "expert_ffn_parity_contract_ready": expert_ffn_row["contract_ready"],
        "expert_ffn_parity_fixture_execution_ready": expert_ffn_row["fixture_execution_ready"],
        "expert_ffn_parity_real_model_execution_ready": expert_ffn_row["real_model_execution_ready"],
        "expert_ffn_parity_release_ready": expert_ffn_row["release_ready"],
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
    {"gap": "v61aa-bf16-tensor-slice-input", "status": "ready", "evidence": "16 sampled real checkpoint tensor slices are hash-bound and finite"},
    {"gap": "hotset-bf16-dot-tile-probe", "status": "ready" if numeric_ready else "blocked", "evidence": f"{finite_baseline_rows}/{tile_count} baseline dot tiles are finite"},
    {"gap": "torch-matvec-parity", "status": "ready" if torch_matvec_parity_pass_rows == tile_count else "blocked", "evidence": f"{torch_matvec_parity_pass_rows}/{tile_count} real-checkpoint BF16 tiles match torch CPU matvec reference"},
    {"gap": "hotset-q8-q4-quant-probe", "status": "ready" if numeric_ready else "blocked", "evidence": f"{finite_q8_error_rows}/{tile_count} q8 and {finite_q4_error_rows}/{tile_count} q4 quantized dot errors are finite"},
    {"gap": "expert-ffn-forward-parity", "status": "ready" if expert_ffn_row["real_model_execution_ready"] == "1" else "blocked", "evidence": expert_ffn_row["reason"]},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only sampled hotset pages are materialized"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "numeric tiles do not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "bounded tile probes are not production runtime latency"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61aa-bf16-tensor-slice-input", "status": "pass", "reason": "v61aa supplies hash-bound BF16 tensor slice rows"},
    {"gate": "hotset-bf16-dot-tile-probe", "status": "pass" if numeric_ready else "blocked", "reason": f"{finite_baseline_rows}/{tile_count} baseline dot tiles are finite"},
    {"gate": "torch-matvec-parity", "status": "pass" if torch_matvec_parity_pass_rows == tile_count else "blocked", "reason": f"{torch_matvec_parity_pass_rows}/{tile_count} real-checkpoint BF16 tiles match torch CPU matvec reference"},
    {"gate": "hotset-q8-q4-quant-probe", "status": "pass" if numeric_ready else "blocked", "reason": "bounded q8/q4 dequantized dot errors are finite"},
    {"gate": "expert-ffn-forward-parity", "status": "pass" if expert_ffn_row["real_model_execution_ready"] == "1" else "blocked", "reason": expert_ffn_row["reason"]},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived rows only; checkpoint payload bytes remain outside the repository"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "tile probes are not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "hotset_tensor_tile_probe_rows.csv", list(tile_rows[0].keys()), tile_rows)
write_csv(run_dir / "hotset_tensor_tile_sample_trace_rows.csv", list(sample_rows[0].keys()), sample_rows)
write_csv(run_dir / "hotset_tensor_tile_torch_parity_rows.csv", list(torch_parity_rows[0].keys()), torch_parity_rows)
write_csv(run_dir / "expert_ffn_forward_parity_rows.csv", list(expert_ffn_rows[0].keys()), expert_ffn_rows)
write_csv(run_dir / "hotset_tensor_tile_quant_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61ab_hotset_tensor_tile_quant_probe_ready": str(numeric_ready),
    "v61aa_hotset_tensor_slice_verifier_ready": v61aa_summary["v61aa_hotset_tensor_slice_verifier_ready"],
    "model_id": model_id,
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
    "torch_matvec_parity_rows": str(len(torch_parity_rows)),
    "torch_matvec_parity_pass_rows": str(torch_matvec_parity_pass_rows),
    "q8_abs_error_mean": fmt(q8_mean_abs_error),
    "q4_abs_error_mean": fmt(q4_mean_abs_error),
    "q8_abs_error_max": fmt(max(q8_abs_errors) if q8_abs_errors else 0.0),
    "q4_abs_error_max": fmt(max(q4_abs_errors) if q4_abs_errors else 0.0),
    "hotset_numeric_tile_probe_ready": str(numeric_ready),
    "q8_quant_probe_ready": str(numeric_ready),
    "q4_quant_probe_ready": str(numeric_ready),
    "torch_matvec_parity_ready": str(numeric_ready),
    "expert_ffn_parity_rows": str(len(expert_ffn_rows)),
    "expert_ffn_parity_contract_ready": expert_ffn_row["contract_ready"],
    "expert_ffn_parity_fixture_execution_ready": expert_ffn_row["fixture_execution_ready"],
    "expert_ffn_parity_real_model_execution_ready": expert_ffn_row["real_model_execution_ready"],
    "expert_ffn_parity_release_ready": expert_ffn_row["release_ready"],
    "expert_ffn_parity_status": expert_ffn_row["status"],
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
    "artifact": "v61ab_hotset_tensor_tile_quant_probe",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ab_hotset_tensor_tile_quant_probe_ready": numeric_ready,
    "tensor_tile_probe_rows": tile_count,
    "tile_bf16_value_rows": total_tile_values,
    "finite_baseline_dot_rows": finite_baseline_rows,
    "finite_q8_dot_rows": finite_q8_rows,
    "finite_q4_dot_rows": finite_q4_rows,
    "torch_matvec_parity_rows": len(torch_parity_rows),
    "torch_matvec_parity_pass_rows": torch_matvec_parity_pass_rows,
    "torch_matvec_parity_ready": numeric_ready,
    "expert_ffn_parity_rows": len(expert_ffn_rows),
    "expert_ffn_parity_contract_ready": int(expert_ffn_row["contract_ready"]),
    "expert_ffn_parity_fixture_execution_ready": int(expert_ffn_row["fixture_execution_ready"]),
    "expert_ffn_parity_real_model_execution_ready": int(expert_ffn_row["real_model_execution_ready"]),
    "expert_ffn_parity_release_ready": int(expert_ffn_row["release_ready"]),
    "q8_abs_error_mean": q8_mean_abs_error,
    "q4_abs_error_mean": q4_mean_abs_error,
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
(run_dir / "v61ab_hotset_tensor_tile_quant_probe_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61ab Hotset Tensor Tile Quant Probe Boundary

This artifact consumes the v61aa sampled real-checkpoint BF16 tensor slices and
runs bounded numeric dot-tile probes plus q8/q4 dequantized dot probes. It does
not execute Mixtral generation.

Evidence emitted:

- tensor_tile_probe_rows={tile_count}
- moe_tensor_tile_probe_rows={moe_tile_rows}
- embedding_tensor_tile_probe_rows={embedding_tile_rows}
- tile_bf16_value_rows={total_tile_values}
- finite_baseline_dot_rows={finite_baseline_rows}
- finite_q8_dot_rows={finite_q8_rows}
- finite_q4_dot_rows={finite_q4_rows}
- finite_q8_error_rows={finite_q8_error_rows}
- finite_q4_error_rows={finite_q4_error_rows}
- torch_matvec_parity_rows={len(torch_parity_rows)}
- torch_matvec_parity_pass_rows={torch_matvec_parity_pass_rows}
- torch_matvec_parity_ready={numeric_ready}
- expert_ffn_parity_rows={len(expert_ffn_rows)}
- expert_ffn_parity_contract_ready={expert_ffn_row["contract_ready"]}
- expert_ffn_parity_fixture_execution_ready={expert_ffn_row["fixture_execution_ready"]}
- expert_ffn_parity_real_model_execution_ready={expert_ffn_row["real_model_execution_ready"]}
- q8_quant_probe_ready={numeric_ready}
- q4_quant_probe_ready={numeric_ready}
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is bounded numeric/quantization evidence over sampled real checkpoint
pages. It is not full Mixtral checkpoint materialization, full page-hash
coverage, real Mixtral generation, near-frontier quality, production latency,
or release evidence.
"""
(run_dir / "V61AB_HOTSET_TENSOR_TILE_QUANT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ab_hotset_tensor_tile_quant_probe_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
