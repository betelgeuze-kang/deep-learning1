#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement/gpu_001"
SUMMARY_CSV="$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61l_gpu_page_dequant_matmul_measurement_decision.csv"

"$ROOT_DIR/experiments/run_v61l_gpu_page_dequant_matmul_measurement.sh" >/dev/null

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
    raise SystemExit(f"expected one v61l summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61l_gpu_page_dequant_matmul_measurement_ready": "1",
    "v61k_real_model_page_manifest_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_model_license": "apache-2.0",
    "page_size_bytes": "2097152",
    "q4_page_bytes": "2097152",
    "tile_m": "1024",
    "tile_k": "4096",
    "iterations": "20",
    "rocm_toolchain_ready": "1",
    "gpu_measurement_ready": "1",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "kv_cache_policy_ready": "0",
    "source_bound_qa_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61l {field}: expected {value}, got {summary.get(field)}")

for field in ["gpu_kernel_avg_ms", "gpu_page_dequant_gflops", "gpu_page_bandwidth_gbps"]:
    if float(summary[field]) <= 0.0:
        raise SystemExit(f"v61l {field} should be positive")
if float(summary["max_abs_delta"]) > 0.02:
    raise SystemExit("v61l max_abs_delta exceeds tolerance")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61k-real-model-page-manifest-input",
    "rocm-toolchain",
    "gpu-page-dequant-matmul-measurement",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61l gate should pass: {gate}")
for gate in [
    "real-checkpoint-weight-materialization",
    "safetensors-page-hash-binding",
    "kv-cache-policy",
    "source-bound-qa",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61l gate should remain blocked: {gate}")

required_files = [
    "gpu_page_dequant_matmul_rows.csv",
    "real_model_manifest_binding_rows.csv",
    "runtime_gap_rows.csv",
    "rocm_runtime_env_rows.csv",
    "rocm_toolchain_rows.csv",
    "rocm_device_rows.csv",
    "v61l_hip_compile_transcript.txt",
    "v61l_hip_probe_transcript.txt",
    "V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    "v61l_gpu_page_dequant_matmul_measurement_manifest.json",
    "sha256_manifest.csv",
    "source_assets/v61l_gpu_page_dequant_matmul_probe.hip",
    "source_v61k/real_model_identity_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61l artifact: {rel}")

measurement = read_csv(run_dir / "gpu_page_dequant_matmul_rows.csv")
if len(measurement) != 1:
    raise SystemExit("v61l should emit one GPU measurement row")
row = measurement[0]
if row["payload_kind"] != "synthetic-q4-page-geometry":
    raise SystemExit("v61l measurement should disclose synthetic q4 payload geometry")
if row["real_checkpoint_weight_bytes_materialized"] != "0" or row["gpu_measurement_ready"] != "1":
    raise SystemExit("v61l measurement boundary mismatch")
if int(row["weights_per_page"]) != 4194304:
    raise SystemExit("v61l should measure one 2 MiB q4 page worth of weights")

binding = read_csv(run_dir / "real_model_manifest_binding_rows.csv")[0]
if binding["manifest_binding_ready"] != "1" or binding["real_checkpoint_weight_bytes_materialized"] != "0":
    raise SystemExit("v61l should bind v61k manifest without materializing weights")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in [
    "real-checkpoint-weight-materialization",
    "safetensors-page-hash-binding",
    "kv-cache-policy",
    "source-bound-qa-workload",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61l gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61l_gpu_page_dequant_matmul_measurement_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61l_gpu_page_dequant_matmul_measurement_ready") != 1:
    raise SystemExit("v61l manifest readiness mismatch")
if manifest.get("real_checkpoint_weight_bytes_materialized") != 0:
    raise SystemExit("v61l manifest should not materialize checkpoint weights")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61l sha256 mismatch: {rel}")

boundary = (run_dir / "V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real ROCm/HIP page-dequant-matmul measurement",
    "synthetic q4 payload bytes",
    "real_checkpoint_weight_bytes_materialized=0",
    "kv_cache_policy_ready=0",
    "Allowed wording: ROCm page-kernel timing",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61l boundary missing {snippet}")
PY

echo "v61l GPU page dequant matmul measurement smoke passed"
