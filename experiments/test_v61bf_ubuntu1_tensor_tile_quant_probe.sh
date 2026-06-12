#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bf_ubuntu1_tensor_tile_quant_probe/probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61bf_ubuntu1_tensor_tile_quant_probe_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bf_ubuntu1_tensor_tile_quant_probe_decision.csv"

V61BF_REUSE_EXISTING="${V61BF_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bf_ubuntu1_tensor_tile_quant_probe.sh" >/dev/null

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
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"
ubuntu1_hotset_root = ubuntu1_target + "/.v61_sampled_hotset_pages"


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
    "v61bf_ubuntu1_tensor_tile_quant_probe_ready": "1",
    "v61be_ubuntu1_hotset_tensor_slice_verifier_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
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
    "ubuntu1_page_hash_match_rows": "16",
    "direct_read_hash_match_rows": "16",
    "ubuntu1_numeric_tile_probe_ready": "1",
    "ubuntu1_q8_quant_probe_ready": "1",
    "ubuntu1_q4_quant_probe_ready": "1",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bf {field}: expected {value}, got {summary.get(field)}")

q8_mean = as_float(summary["q8_abs_error_mean"])
q4_mean = as_float(summary["q4_abs_error_mean"])
q8_max = as_float(summary["q8_abs_error_max"])
q4_max = as_float(summary["q4_abs_error_max"])
if q8_mean < 0 or q4_mean < 0 or q8_max < 0 or q4_max < 0:
    raise SystemExit("v61bf quant errors must be non-negative")

required_files = [
    "ubuntu1_tensor_tile_probe_rows.csv",
    "ubuntu1_tensor_tile_sample_trace_rows.csv",
    "ubuntu1_tensor_tile_quant_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BF_UBUNTU1_TENSOR_TILE_QUANT_BOUNDARY.md",
    "v61bf_ubuntu1_tensor_tile_quant_probe_manifest.json",
    "sha256_manifest.csv",
    "source_v61be/ubuntu1_hotset_tensor_slice_stat_rows.csv",
    "source_v61be/ubuntu1_hotset_tensor_slice_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bf artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61be-ubuntu1-bf16-tensor-slice-input",
    "ubuntu1-bf16-dot-tile-probe",
    "ubuntu1-q8-q4-quant-probe",
    "no-network-download-by-v61bf",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bf gate should pass: {gate}")
for gate in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bf gate should stay blocked: {gate}")

tile_rows = read_csv(run_dir / "ubuntu1_tensor_tile_probe_rows.csv")
sample_rows = read_csv(run_dir / "ubuntu1_tensor_tile_sample_trace_rows.csv")
metric = read_csv(run_dir / "ubuntu1_tensor_tile_quant_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(tile_rows) != 128:
    raise SystemExit("v61bf tensor tile row count mismatch")
if len(sample_rows) != 384:
    raise SystemExit("v61bf sample trace row count mismatch")
if sum(1 for row in tile_rows if row["moe_expert_tile"] == "1") != 120:
    raise SystemExit("v61bf MoE tile row count mismatch")
if sum(1 for row in tile_rows if row["embedding_tile"] == "1") != 8:
    raise SystemExit("v61bf embedding tile row count mismatch")
if any(row["tile_bf16_values"] != "4096" for row in tile_rows):
    raise SystemExit("v61bf each tile should contain 4096 BF16 values")
if any(row["tile_hash_bound_to_remote_page"] != "1" for row in tile_rows):
    raise SystemExit("v61bf all tiles must be hash-bound to remote pages")
if any(row["ubuntu1_page_hash_match"] != "1" for row in tile_rows):
    raise SystemExit("v61bf all tiles must inherit ubuntu-1 page hash matches")
if any(row["direct_read_hash_match"] != "1" for row in tile_rows):
    raise SystemExit("v61bf all tiles must inherit direct-read hash matches")
if any(row["direct_io_used"] != "1" for row in tile_rows):
    raise SystemExit("v61bf all tiles must inherit direct I/O usage")
if any(row["baseline_dot_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61bf all baseline dot rows should be finite")
if any(row["q8_dot_finite"] != "1" or row["q4_dot_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61bf q8/q4 dot rows should be finite")
if any(row["q8_error_finite"] != "1" or row["q4_error_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61bf q8/q4 error rows should be finite")

for row in tile_rows:
    page_path = Path(row["ubuntu1_page_path"])
    if not str(page_path).startswith(ubuntu1_hotset_root + "/"):
        raise SystemExit("v61bf tile should read from ubuntu-1 hotset root")
    if sha256(page_path) != row["remote_page_sha256"]:
        raise SystemExit("v61bf filesystem hash should match remote sha")
    if row["checkpoint_payload_bytes_downloaded_by_v61bf"] != "0":
        raise SystemExit("v61bf must not download checkpoint payload")
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bf must not commit checkpoint payload")
    if row["actual_model_generation_ready"] != "0":
        raise SystemExit("v61bf must keep generation blocked")
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

if any(row["checkpoint_payload_bytes_downloaded_by_v61bf"] != "0" for row in sample_rows):
    raise SystemExit("v61bf sample rows must not claim payload download")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in sample_rows):
    raise SystemExit("v61bf sample rows must not claim payload commit")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bf metric {field}: expected {value}, got {metric[field]}")

for gap in ["v61be-ubuntu1-bf16-tensor-slice-input", "ubuntu1-bf16-dot-tile-probe", "ubuntu1-q8-q4-quant-probe"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bf gap should be ready: {gap}")
for gap in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bf gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bf_ubuntu1_tensor_tile_quant_probe_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bf_ubuntu1_tensor_tile_quant_probe_ready") != 1:
    raise SystemExit("v61bf manifest readiness mismatch")
if manifest.get("tensor_tile_probe_rows") != 128 or manifest.get("tile_bf16_value_rows") != 524288:
    raise SystemExit("v61bf manifest row count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bf") != 0:
    raise SystemExit("v61bf manifest must not download payload")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61bf manifest must not commit payload")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61bf manifest should keep generation blocked")

boundary = (run_dir / "V61BF_UBUNTU1_TENSOR_TILE_QUANT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "tensor_tile_probe_rows=128",
    "tile_bf16_value_rows=524288",
    "finite_baseline_dot_rows=128",
    "ubuntu1_page_hash_match_rows=16",
    "direct_read_hash_match_rows=16",
    "ubuntu1_q8_quant_probe_ready=1",
    "ubuntu1_q4_quant_probe_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61bf=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bf boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bf sha256 mismatch: {rel}")

print("v61bf ubuntu-1 tensor tile quant probe smoke passed")
PY
