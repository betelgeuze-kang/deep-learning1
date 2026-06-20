#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_decision.csv"

V61AB_REUSE_EXISTING="${V61AB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
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


def as_float(value):
    parsed = float(value)
    if not math.isfinite(parsed):
        raise SystemExit(f"nonfinite numeric field: {value}")
    return parsed


summary = read_csv(summary_csv)[0]
expected = {
    "v61ab_hotset_tensor_tile_quant_probe_ready": "1",
    "v61aa_hotset_tensor_slice_verifier_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "tensor_slice_rows": "16",
    "tensor_tile_probe_rows": "128",
    "moe_tensor_tile_probe_rows": "120",
    "embedding_tensor_tile_probe_rows": "8",
    "tile_bf16_value_rows": "524288",
    "tile_sample_trace_rows": "384",
    "finite_baseline_dot_rows": "128",
    "finite_q8_dot_rows": "128",
    "finite_q4_dot_rows": "128",
    "finite_q8_error_rows": "128",
    "finite_q4_error_rows": "128",
    "torch_matvec_parity_rows": "128",
    "torch_matvec_parity_pass_rows": "128",
    "hotset_numeric_tile_probe_ready": "1",
    "q8_quant_probe_ready": "1",
    "q4_quant_probe_ready": "1",
    "torch_matvec_parity_ready": "1",
    "expert_ffn_parity_rows": "1",
    "expert_ffn_parity_contract_ready": "1",
    "expert_ffn_parity_fixture_execution_ready": "0",
    "expert_ffn_parity_real_model_execution_ready": "0",
    "expert_ffn_parity_release_ready": "0",
    "expert_ffn_parity_status": "blocked",
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
        raise SystemExit(f"v61ab {field}: expected {value}, got {summary.get(field)}")

q8_mean = as_float(summary["q8_abs_error_mean"])
q4_mean = as_float(summary["q4_abs_error_mean"])
q8_max = as_float(summary["q8_abs_error_max"])
q4_max = as_float(summary["q4_abs_error_max"])
if q8_mean < 0 or q4_mean < 0 or q8_max < 0 or q4_max < 0:
    raise SystemExit("v61ab quant errors must be non-negative")

required_files = [
    "hotset_tensor_tile_probe_rows.csv",
    "hotset_tensor_tile_sample_trace_rows.csv",
    "hotset_tensor_tile_torch_parity_rows.csv",
    "expert_ffn_forward_parity_rows.csv",
    "hotset_tensor_tile_quant_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AB_HOTSET_TENSOR_TILE_QUANT_BOUNDARY.md",
    "v61ab_hotset_tensor_tile_quant_probe_manifest.json",
    "sha256_manifest.csv",
    "source_v61aa/hotset_tensor_slice_stat_rows.csv",
    "source_v61aa/hotset_tensor_slice_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ab artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61aa-bf16-tensor-slice-input",
    "hotset-bf16-dot-tile-probe",
    "torch-matvec-parity",
    "hotset-q8-q4-quant-probe",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ab gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ab gate should stay blocked: {gate}")
if decisions.get("expert-ffn-forward-parity") != "blocked":
    raise SystemExit("v61ab default expert FFN parity should remain blocked without local checkpoint root")

tile_rows = read_csv(run_dir / "hotset_tensor_tile_probe_rows.csv")
sample_rows = read_csv(run_dir / "hotset_tensor_tile_sample_trace_rows.csv")
torch_rows = read_csv(run_dir / "hotset_tensor_tile_torch_parity_rows.csv")
expert_ffn_rows = read_csv(run_dir / "expert_ffn_forward_parity_rows.csv")
metric = read_csv(run_dir / "hotset_tensor_tile_quant_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(tile_rows) != 128:
    raise SystemExit("v61ab tensor tile row count mismatch")
if len(sample_rows) != 384:
    raise SystemExit("v61ab sample trace row count mismatch")
if len(torch_rows) != 128:
    raise SystemExit("v61ab torch parity row count mismatch")
if len(expert_ffn_rows) != 1:
    raise SystemExit("v61ab expert FFN parity row count mismatch")
if sum(1 for row in tile_rows if row["moe_expert_tile"] == "1") != 120:
    raise SystemExit("v61ab MoE tile row count mismatch")
if sum(1 for row in tile_rows if row["embedding_tile"] == "1") != 8:
    raise SystemExit("v61ab embedding tile row count mismatch")
if any(row["tile_bf16_values"] != "4096" for row in tile_rows):
    raise SystemExit("v61ab each tile should contain 4096 BF16 values")
if any(row["tile_hash_bound_to_remote_page"] != "1" for row in tile_rows):
    raise SystemExit("v61ab all tiles must be hash-bound to remote pages")
if any(row["baseline_dot_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61ab all baseline dot rows should be finite")
if any(row["q8_dot_finite"] != "1" or row["q4_dot_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61ab q8/q4 dot rows should be finite")
if any(row["q8_error_finite"] != "1" or row["q4_error_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61ab q8/q4 error rows should be finite")
if any(row["torch_matvec_parity_pass"] != "1" for row in torch_rows):
    raise SystemExit("v61ab all torch matvec parity rows should pass")
if any(row["real_checkpoint_page_bound"] != "1" for row in torch_rows):
    raise SystemExit("v61ab torch parity rows should stay bound to real checkpoint pages")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in tile_rows + sample_rows):
    raise SystemExit("v61ab must not commit checkpoint payload")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in torch_rows):
    raise SystemExit("v61ab torch parity rows must not commit checkpoint payload")
if any(row["actual_model_generation_ready"] != "0" for row in tile_rows):
    raise SystemExit("v61ab must keep generation blocked")
if any(row["actual_model_generation_ready"] != "0" for row in torch_rows):
    raise SystemExit("v61ab torch parity must keep generation blocked")
expert_default = expert_ffn_rows[0]
if expert_default["contract_ready"] != "1":
    raise SystemExit("v61ab expert FFN parity contract should be ready")
if expert_default["fixture_execution_ready"] != "0" or expert_default["real_model_execution_ready"] != "0":
    raise SystemExit("v61ab default expert FFN parity should not claim fixture or real execution")
if expert_default["release_ready"] != "0" or expert_default["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61ab expert FFN default boundary should keep release/payload closed")
for row in tile_rows:
    for field in [
        "baseline_dot_fp32",
        "q8_dot_fp32",
        "q4_dot_fp32",
        "q8_abs_error",
        "q4_abs_error",
        "q8_rel_error",
        "q4_rel_error",
        "weight_mean_abs_fp32",
        "weight_rms_fp32",
        "weight_max_abs_fp32",
        "q8_scale",
        "q4_scale",
    ]:
        as_float(row[field])
for row in torch_rows:
    for field in [
        "python_baseline_dot_fp64",
        "torch_matvec_dot_fp64",
        "torch_abs_delta",
        "torch_tolerance",
    ]:
        as_float(row[field])
    if float(row["torch_abs_delta"]) > float(row["torch_tolerance"]):
        raise SystemExit("v61ab torch parity delta exceeds tolerance")

for field in [
    "hotset_numeric_tile_probe_ready",
    "q8_quant_probe_ready",
    "q4_quant_probe_ready",
    "torch_matvec_parity_ready",
    "expert_ffn_parity_contract_ready",
]:
    if metric[field] != "1":
        raise SystemExit(f"v61ab metric should keep {field}=1")
for field in [
    "expert_ffn_parity_real_model_execution_ready",
    "expert_ffn_parity_release_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61ab metric should keep {field}=0")
for field in [
    "full_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61ab metric should keep {field}=0")

for gap in ["v61aa-bf16-tensor-slice-input", "hotset-bf16-dot-tile-probe", "torch-matvec-parity", "hotset-q8-q4-quant-probe"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ab gap should be ready: {gap}")
if gaps.get("expert-ffn-forward-parity") != "blocked":
    raise SystemExit("v61ab expert FFN gap should remain blocked by default")
for gap in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ab gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ab_hotset_tensor_tile_quant_probe_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ab_hotset_tensor_tile_quant_probe_ready") != 1:
    raise SystemExit("v61ab manifest readiness mismatch")
if manifest.get("tensor_tile_probe_rows") != 128 or manifest.get("tile_bf16_value_rows") != 524288:
    raise SystemExit("v61ab manifest row count mismatch")
if manifest.get("torch_matvec_parity_rows") != 128 or manifest.get("torch_matvec_parity_pass_rows") != 128:
    raise SystemExit("v61ab manifest torch parity row count mismatch")
if manifest.get("torch_matvec_parity_ready") != 1:
    raise SystemExit("v61ab manifest should record torch matvec parity readiness")
if manifest.get("expert_ffn_parity_contract_ready") != 1:
    raise SystemExit("v61ab manifest should record expert FFN parity contract readiness")
if manifest.get("expert_ffn_parity_real_model_execution_ready") != 0:
    raise SystemExit("v61ab manifest should keep expert FFN real execution closed by default")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ab manifest should keep generation blocked")

boundary = (run_dir / "V61AB_HOTSET_TENSOR_TILE_QUANT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "tensor_tile_probe_rows=128",
    "tile_bf16_value_rows=524288",
    "finite_baseline_dot_rows=128",
    "torch_matvec_parity_rows=128",
    "torch_matvec_parity_pass_rows=128",
    "torch_matvec_parity_ready=1",
    "expert_ffn_parity_contract_ready=1",
    "expert_ffn_parity_real_model_execution_ready=0",
    "q8_quant_probe_ready=1",
    "q4_quant_probe_ready=1",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ab boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ab sha256 mismatch: {rel}")
PY

TMP_EXPERT_ROOT="${TMPDIR:-/tmp}/v61ab_expert_ffn_fixture_root"
rm -rf "$TMP_EXPERT_ROOT"
mkdir -p "$TMP_EXPERT_ROOT"
python3 - "$TMP_EXPERT_ROOT" <<'PY'
import json
import struct
import sys
from pathlib import Path

import numpy as np

root = Path(sys.argv[1])
shard = root / "model-00001-of-00001.safetensors"
tensors = {
    "model.layers.0.input_layernorm.weight": np.arange(4, dtype=np.float32) / 13.0,
    "model.layers.0.block_sparse_moe.gate.weight": np.arange(8, dtype=np.float32).reshape(2, 4) / 29.0,
    "model.layers.0.block_sparse_moe.experts.0.w1.weight": np.arange(12, dtype=np.float32).reshape(3, 4) / 17.0,
    "model.layers.0.block_sparse_moe.experts.0.w2.weight": np.arange(12, dtype=np.float32).reshape(4, 3) / 19.0,
    "model.layers.0.block_sparse_moe.experts.0.w3.weight": np.arange(12, dtype=np.float32).reshape(3, 4) / 23.0,
}


def f32_to_bf16_bytes(array):
    raw = array.astype("<f4").view("<u4")
    bf16 = (raw >> 16).astype("<u2")
    return bf16.tobytes()


offset = 0
header = {"__metadata__": {"format": "pt"}}
payloads = []
for name, array in tensors.items():
    payload = f32_to_bf16_bytes(array)
    header[name] = {"dtype": "BF16", "shape": list(array.shape), "data_offsets": [offset, offset + len(payload)]}
    payloads.append(payload)
    offset += len(payload)
header_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
shard.write_bytes(struct.pack("<Q", len(header_bytes)) + header_bytes + b"".join(payloads))
(root / "model.safetensors.index.json").write_text(
    json.dumps(
        {
            "metadata": {"total_size": sum(len(p) for p in payloads)},
            "weight_map": {name: shard.name for name in tensors},
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
(root / "config.json").write_text(
    json.dumps({"model_type": "mixtral", "hidden_size": 4, "intermediate_size": 3, "num_local_experts": 1}, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build" -DDLE_ENABLE_HIP="${DLE_VERIFY_ENABLE_HIP:-OFF}" >/dev/null
cmake --build "$ROOT_DIR/build" --target expert_ffn_forward_parity -j "${AI_VERIFY_JOBS:-2}" >/dev/null

V61AB_RUN_ID="ffn_fixture" \
V61AB_REUSE_EXISTING=0 \
V61AB_EXPERT_FFN_CHECKPOINT_ROOT="$TMP_EXPERT_ROOT" \
V61AB_EXPERT_FFN_LAYER=0 \
V61AB_EXPERT_FFN_EXPERT=0 \
V61AB_EXPERT_FFN_REAL_MODEL_EVIDENCE=1 \
"$ROOT_DIR/experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null

python3 - "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/ffn_fixture" "$SUMMARY_CSV" <<'PY'
import csv
import math
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary["expert_ffn_parity_contract_ready"] != "1":
    raise SystemExit("v61ab fixture expert FFN contract should be ready")
if summary["expert_ffn_parity_fixture_execution_ready"] != "1":
    raise SystemExit("v61ab fixture expert FFN execution should be ready")
if summary["expert_ffn_parity_real_model_execution_ready"] != "0":
    raise SystemExit("v61ab fixture expert FFN must not claim real model execution")
if summary["expert_ffn_parity_release_ready"] != "0":
    raise SystemExit("v61ab fixture expert FFN must not open release readiness")
rows = read_csv(run_dir / "expert_ffn_forward_parity_rows.csv")
if len(rows) != 1:
    raise SystemExit("v61ab fixture should emit one expert FFN row")
row = rows[0]
if row["status"] != "pass" or row["expert_ffn_parity_pass"] != "1":
    raise SystemExit("v61ab fixture expert FFN parity should pass")
if row["fixture_execution_ready"] != "1" or row["real_model_execution_ready"] != "0":
    raise SystemExit("v61ab fixture expert FFN typed readiness mismatch")
if row["w1_shape"] != "3x4" or row["w2_shape"] != "4x3" or row["w3_shape"] != "3x4":
    raise SystemExit("v61ab fixture expert FFN shapes mismatch")
for field in [
    "config_sha256",
    "shard_index_sha256",
    "full_manifest_sha256",
    "rmsnorm_payload_sha256",
    "router_payload_sha256",
    "residual_input_sha256",
    "residual_output_sha256",
    "independent_runtime_output_sha256",
    "candidate_output_sha256",
    "torch_reference_output_sha256",
]:
    if not row[field]:
        raise SystemExit(f"v61ab fixture expert FFN should populate {field}")
if row["transformers_expert_output_sha256"]:
    raise SystemExit("v61ab fixture expert FFN must not populate original Transformers output without module capture")
if row["router_top_k"] != "2" or row["token_id"] != "0":
    raise SystemExit("v61ab fixture expert FFN token/router metadata mismatch")
if not row["candidate_output_sha256"] or not row["torch_reference_output_sha256"]:
    raise SystemExit("v61ab fixture expert FFN should hash candidate/reference outputs")
if row["candidate_output_sha256"] != row["independent_runtime_output_sha256"]:
    raise SystemExit("v61ab fixture expert FFN candidate output must come from independent runtime")
if float(row["max_abs_delta"]) > float(row["tolerance"]):
    raise SystemExit("v61ab fixture expert FFN delta exceeds tolerance")
if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61ab fixture expert FFN must not commit checkpoint payload")
PY
"$ROOT_DIR/tools/verify_artifact.py" v61ab-tile-probe "$SUMMARY_CSV" \
  --run-dir "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/ffn_fixture" >/dev/null

V61AB_RUN_ID="probe_001" \
V61AB_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null

echo "v61ab hotset tensor tile quant probe smoke passed"
