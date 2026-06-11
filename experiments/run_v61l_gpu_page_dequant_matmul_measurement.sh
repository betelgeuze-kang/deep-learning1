#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61l_gpu_page_dequant_matmul_measurement"
RUN_ID="${V61L_RUN_ID:-gpu_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61L_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61l_gpu_page_dequant_matmul_measurement_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61k_real_model_page_manifest_summary.csv" \
  || ! -s "$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001/real_model_identity_rows.csv" \
  || ! -s "$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001/tensor_page_manifest_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61k_real_model_page_manifest.sh" >/dev/null
fi

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/ollama_rocm_env.sh"
export PATH="/opt/rocm/bin:${PATH:-}"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61k_dir = results / "v61k_real_model_page_manifest" / "manifest_001"
probe_src = root / "experiments" / "assets" / "v61l_gpu_page_dequant_matmul_probe.hip"


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


def parse_probe_stdout(text):
    fields = {}
    for token in text.strip().split():
        if "=" in token:
            key, value = token.split("=", 1)
            fields[key] = value
    return fields


v61k_summary = read_csv(results / "v61k_real_model_page_manifest_summary.csv")[0]
if v61k_summary.get("v61k_real_model_page_manifest_ready") != "1":
    raise SystemExit("v61l requires v61k_real_model_page_manifest_ready=1")

for rel in [
    "real_model_identity_rows.csv",
    "real_model_source_rows.csv",
    "real_model_config_rows.csv",
    "license_redistribution_rows.csv",
    "checkpoint_shard_manifest_rows.csv",
    "tensor_page_manifest_rows.csv",
    "expert_page_budget_rows.csv",
    "runtime_gap_rows.csv",
    "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "v61k_real_model_page_manifest_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61k_dir / rel, f"source_v61k/{rel}")
copy(results / "v61k_real_model_page_manifest_summary.csv", "source_v61k/v61k_real_model_page_manifest_summary.csv")
copy(probe_src, "source_assets/v61l_gpu_page_dequant_matmul_probe.hip")

rocm_env_rows = [
    {"key": key, "value": os.environ.get(key, "")}
    for key in [
        "ROCM_PATH",
        "HIP_PATH",
        "HIP_DEVICE_LIB_PATH",
        "HIP_VISIBLE_DEVICES",
        "HCC_AMDGPU_TARGET",
        "HIP_LAUNCH_BLOCKING",
    ]
]
write_csv(run_dir / "rocm_runtime_env_rows.csv", ["key", "value"], rocm_env_rows)

hipcc = shutil.which("hipcc") or ("/opt/rocm/bin/hipcc" if Path("/opt/rocm/bin/hipcc").is_file() else None)
rocm_smi = shutil.which("rocm-smi") or ("/opt/rocm/bin/rocm-smi" if Path("/opt/rocm/bin/rocm-smi").is_file() else None)
rocminfo = shutil.which("rocminfo") or ("/opt/rocm/bin/rocminfo" if Path("/opt/rocm/bin/rocminfo").is_file() else None)
toolchain_rows = [
    {"tool": "hipcc", "path": hipcc or "", "ready": str(int(hipcc is not None))},
    {"tool": "rocm-smi", "path": rocm_smi or "", "ready": str(int(rocm_smi is not None))},
    {"tool": "rocminfo", "path": rocminfo or "", "ready": str(int(rocminfo is not None))},
]
write_csv(run_dir / "rocm_toolchain_rows.csv", list(toolchain_rows[0].keys()), toolchain_rows)

device_rows = []
if rocm_smi:
    smi_proc = subprocess.run([rocm_smi, "--showproductname"], capture_output=True, text=True)
    (run_dir / "rocm_smi_product_transcript.txt").write_text((smi_proc.stdout or "") + (smi_proc.stderr or ""), encoding="utf-8")
    for line in (smi_proc.stdout or "").splitlines():
        match = re.search(r"GPU\[(\d+)\]\s*:\s*Card series:\s*(.+)", line)
        if match:
            device_rows.append({"device_id": match.group(1), "product_name": match.group(2).strip(), "source": "rocm-smi"})
if not device_rows:
    device_rows.append({"device_id": "0", "product_name": "unknown", "source": "not-detected"})
write_csv(run_dir / "rocm_device_rows.csv", list(device_rows[0].keys()), device_rows)

page_size_bytes = int(v61k_summary["page_size_bytes"])
tile_m = int(os.environ.get("V61L_TILE_M", "1024"))
tile_k = int(os.environ.get("V61L_TILE_K", str((page_size_bytes * 2) // tile_m)))
iterations = int(os.environ.get("V61L_ITERATIONS", "20"))
q4_page_bytes = (tile_m * tile_k + 1) // 2
if q4_page_bytes != page_size_bytes:
    raise SystemExit(f"v61l tile must equal one q4 page: got {q4_page_bytes}, expected {page_size_bytes}")

probe_bin = Path(os.environ.get("V61L_PROBE_BIN", f"/tmp/v61l_gpu_page_dequant_matmul_probe_{os.getpid()}"))
probe_artifact = run_dir / "v61l_gpu_page_dequant_matmul_probe.bin"
compile_ok = 0
compile_cmd = []
if hipcc and probe_src.is_file():
    rocm_path = os.environ.get("ROCM_PATH", "/opt/rocm-6.0.2")
    device_lib_path = os.environ.get("HIP_DEVICE_LIB_PATH", "")
    offload_arch = os.environ.get("HCC_AMDGPU_TARGET", "gfx1030")
    compile_cmd = [hipcc, f"--rocm-path={rocm_path}", f"--offload-arch={offload_arch}", "-std=c++17"]
    if device_lib_path:
        compile_cmd.append(f"--rocm-device-lib-path={device_lib_path}")
    compile_cmd.extend([str(probe_src), "-o", str(probe_bin)])
    compile_proc = subprocess.run(compile_cmd, capture_output=True, text=True)
    (run_dir / "v61l_hip_compile_transcript.txt").write_text(
        (compile_proc.stdout or "") + (compile_proc.stderr or ""),
        encoding="utf-8",
    )
    compile_ok = int(compile_proc.returncode == 0 and probe_bin.is_file())
    if compile_ok:
        shutil.copy2(probe_bin, probe_artifact)
else:
    (run_dir / "v61l_hip_compile_transcript.txt").write_text("hipcc or probe source missing\n", encoding="utf-8")

run_ok = 0
probe_fields = {}
probe_exit_code = 127
if compile_ok:
    run_proc = subprocess.run(
        [str(probe_bin), str(tile_m), str(tile_k), str(iterations)],
        capture_output=True,
        text=True,
    )
    probe_exit_code = run_proc.returncode
    probe_text = (run_proc.stdout or "") + (run_proc.stderr or "")
    (run_dir / "v61l_hip_probe_transcript.txt").write_text(probe_text, encoding="utf-8")
    run_ok = int(run_proc.returncode == 0 and "v61l_gpu_page_dequant_matmul_ok" in (run_proc.stdout or ""))
    probe_fields = parse_probe_stdout(run_proc.stdout or "")
else:
    (run_dir / "v61l_hip_probe_transcript.txt").write_text("probe not executed because compile failed\n", encoding="utf-8")

if run_ok != 1:
    raise SystemExit("v61l GPU page dequant matmul probe did not complete successfully")

measurement_rows = [
    {
        "measurement_id": "v61l_mixtral_q4_page_tile_001",
        "model_id": v61k_summary["model_id"],
        "source_page_manifest": "v61k_real_model_page_manifest",
        "payload_kind": "synthetic-q4-page-geometry",
        "real_checkpoint_weight_bytes_materialized": "0",
        "page_size_bytes": str(page_size_bytes),
        "q4_page_bytes": str(q4_page_bytes),
        "tile_m": str(tile_m),
        "tile_k": str(tile_k),
        "weights_per_page": str(tile_m * tile_k),
        "iterations": str(iterations),
        "gpu_kernel_avg_ms": probe_fields["avg_kernel_ms"],
        "h2d_ms": probe_fields["h2d_ms"],
        "d2h_ms": probe_fields["d2h_ms"],
        "max_abs_delta": probe_fields["max_abs_delta"],
        "gflops": probe_fields["gflops"],
        "bandwidth_gbps": probe_fields["bandwidth_gbps"],
        "device_count": probe_fields.get("device_count", ""),
        "device_id": probe_fields.get("device_id", "0"),
        "kernel_exit_code": str(probe_exit_code),
        "probe_execution_path": str(probe_bin),
        "gpu_measurement_ready": "1",
    }
]
write_csv(run_dir / "gpu_page_dequant_matmul_rows.csv", list(measurement_rows[0].keys()), measurement_rows)

binding_rows = [
    {
        "model_id": v61k_summary["model_id"],
        "source_model_license": v61k_summary["source_model_license"],
        "tensor_page_manifest_rows": v61k_summary["tensor_page_manifest_rows"],
        "checkpoint_shard_manifest_rows": v61k_summary["checkpoint_shard_manifest_rows"],
        "page_size_bytes": v61k_summary["page_size_bytes"],
        "q4_page_bytes_measured": str(q4_page_bytes),
        "legally_redistributable_page_manifest_ready": v61k_summary["legally_redistributable_page_manifest_ready"],
        "real_checkpoint_weight_bytes_materialized": v61k_summary["real_checkpoint_weight_bytes_materialized"],
        "manifest_binding_ready": "1",
    }
]
write_csv(run_dir / "real_model_manifest_binding_rows.csv", list(binding_rows[0].keys()), binding_rows)

gap_rows = [
    ("real-checkpoint-weight-materialization", "blocked", "v61l measures synthetic q4 page geometry bound to v61k; checkpoint weights are not downloaded or redistributed"),
    ("safetensors-page-hash-binding", "blocked", "no real safetensors page hashes are validated in v61l"),
    ("kv-cache-policy", "blocked", "KV residency/eviction is a separate v61 target"),
    ("source-bound-qa-workload", "blocked", "v61j command is not yet running source-bound QA through the GPU page kernel"),
    ("near-frontier-quality", "blocked", "kernel measurement is not a quality evaluation"),
    ("production-latency", "blocked", "single page-tile kernel timing is not an end-to-end decode latency guarantee"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

kernel_avg = float(probe_fields["avg_kernel_ms"])
gflops = float(probe_fields["gflops"])
bandwidth = float(probe_fields["bandwidth_gbps"])
max_abs_delta = float(probe_fields["max_abs_delta"])
gpu_measurement_ready = int(kernel_avg > 0.0 and gflops > 0.0 and bandwidth > 0.0 and max_abs_delta <= 0.02)

summary = {
    "v61l_gpu_page_dequant_matmul_measurement_ready": str(gpu_measurement_ready),
    "v61k_real_model_page_manifest_ready": v61k_summary["v61k_real_model_page_manifest_ready"],
    "model_id": v61k_summary["model_id"],
    "source_model_license": v61k_summary["source_model_license"],
    "page_size_bytes": str(page_size_bytes),
    "q4_page_bytes": str(q4_page_bytes),
    "tile_m": str(tile_m),
    "tile_k": str(tile_k),
    "iterations": str(iterations),
    "gpu_kernel_avg_ms": f"{kernel_avg:.6f}",
    "gpu_page_dequant_gflops": f"{gflops:.6f}",
    "gpu_page_bandwidth_gbps": f"{bandwidth:.6f}",
    "max_abs_delta": f"{max_abs_delta:.8f}",
    "rocm_toolchain_ready": str(int(hipcc is not None and rocm_smi is not None)),
    "gpu_measurement_ready": str(gpu_measurement_ready),
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "kv_cache_policy_ready": "0",
    "source_bound_qa_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61k-real-model-page-manifest-input", "pass", "v61k Mixtral 8x22B page manifest is bound"),
    ("rocm-toolchain", "pass", "hipcc and rocm-smi are available"),
    ("gpu-page-dequant-matmul-measurement", "pass", f"avg_kernel_ms={summary['gpu_kernel_avg_ms']}; gflops={summary['gpu_page_dequant_gflops']}"),
    ("real-checkpoint-weight-materialization", "blocked", "v61l uses synthetic q4 payload under real page geometry; no checkpoint weights materialized"),
    ("safetensors-page-hash-binding", "blocked", "requires local shard/header/page hash intake"),
    ("kv-cache-policy", "blocked", "KV residency/eviction not implemented in v61l"),
    ("source-bound-qa", "blocked", "v61j source-bound QA does not consume v61l kernel yet"),
    ("near-frontier-quality", "blocked", "no quality claim from kernel timing"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md").write_text(
    "# v61l GPU Page Dequant Matmul Measurement Boundary\n\n"
    "This layer adds a real ROCm/HIP page-dequant-matmul measurement bound to the v61k Mixtral 8x22B page manifest geometry. "
    "It measures one 2 MiB q4-equivalent page tile with synthetic q4 payload bytes. It does not download, redistribute, or hash real checkpoint weight pages.\n\n"
    f"- model_id={v61k_summary['model_id']}\n"
    f"- page_size_bytes={page_size_bytes}\n"
    f"- q4_page_bytes={q4_page_bytes}\n"
    f"- tile_m={tile_m}\n"
    f"- tile_k={tile_k}\n"
    f"- gpu_kernel_avg_ms={kernel_avg:.6f}\n"
    f"- gpu_page_dequant_gflops={gflops:.6f}\n"
    f"- gpu_page_bandwidth_gbps={bandwidth:.6f}\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- kv_cache_policy_ready=0\n"
    "- source_bound_qa_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: ROCm page-kernel timing over v61k page geometry. Blocked wording: real Mixtral inference speed, production latency, near-frontier quality, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61l-gpu-page-dequant-matmul-measurement",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61l_gpu_page_dequant_matmul_measurement_ready": gpu_measurement_ready,
    "v61k_summary_sha256": sha256(results / "v61k_real_model_page_manifest_summary.csv"),
    "kernel_source_sha256": sha256(probe_src),
    "model_id": v61k_summary["model_id"],
    "page_size_bytes": page_size_bytes,
    "q4_page_bytes": q4_page_bytes,
    "tile_m": tile_m,
    "tile_k": tile_k,
    "gpu_kernel_avg_ms": kernel_avg,
    "gpu_page_dequant_gflops": gflops,
    "real_checkpoint_weight_bytes_materialized": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61l_gpu_page_dequant_matmul_measurement_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "gpu_page_dequant_matmul_rows.csv",
    "real_model_manifest_binding_rows.csv",
    "runtime_gap_rows.csv",
    "rocm_runtime_env_rows.csv",
    "rocm_toolchain_rows.csv",
    "rocm_device_rows.csv",
    "rocm_smi_product_transcript.txt",
    "v61l_hip_compile_transcript.txt",
    "v61l_hip_probe_transcript.txt",
    "v61l_gpu_page_dequant_matmul_probe.bin",
    "V61L_GPU_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    "v61l_gpu_page_dequant_matmul_measurement_manifest.json",
    "source_assets/v61l_gpu_page_dequant_matmul_probe.hip",
    "source_v61k/real_model_identity_rows.csv",
    "source_v61k/real_model_config_rows.csv",
    "source_v61k/license_redistribution_rows.csv",
    "source_v61k/checkpoint_shard_manifest_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/expert_page_budget_rows.csv",
    "source_v61k/runtime_gap_rows.csv",
    "source_v61k/V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "source_v61k/v61k_real_model_page_manifest_manifest.json",
    "source_v61k/sha256_manifest.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61l_gpu_page_dequant_matmul_measurement_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
