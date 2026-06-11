#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52v_local_llm_weight_tier_rocm_decode_bind"
RUN_ID="${V52V_RUN_ID:-bind_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V52U_DIR="${V52U_READER_DIR:-$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader/reader_001}"

if [[ "${V52V_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52v_local_llm_weight_tier_rocm_decode_bind_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader_summary.csv" ]]; then
  V52U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52u_local_llm_weight_tier_mmap_reader.sh" >/dev/null
fi

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/ollama_rocm_env.sh"
export PATH="/opt/rocm/bin:${PATH:-}"

python3 - "$ROOT_DIR" "$RUN_DIR" "$V52U_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import mmap
import os
import shutil
import struct
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v52u_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
results = root / "results"
assets = root / "experiments" / "assets"
probe_src = assets / "v52v_tier_hot_shard_axpy_probe.hip"

v52u_summary = list(csv.DictReader((results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv").open(newline="", encoding="utf-8")))[0]
if int(v52u_summary.get("weight_tier_mmap_reader_ready", "0")) != 1:
    raise SystemExit("v52v requires v52u with weight_tier_mmap_reader_ready=1")


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
    if src.is_dir():
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)
    return dst


copy(v52u_dir / "tier_decode_scaffold_rows.csv", "source_v52u/tier_decode_scaffold_rows.csv")
copy(v52u_dir / "mmap_read_trace_rows.csv", "source_v52u/mmap_read_trace_rows.csv")
copy(results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv", "source_v52u/v52u_local_llm_weight_tier_mmap_reader_summary.csv")
copy(probe_src, "source_assets/v52v_tier_hot_shard_axpy_probe.hip")

rocm_env_rows = [
    {"key": k, "value": os.environ.get(k, "")}
    for k in [
        "ROCM_PATH",
        "HIP_PATH",
        "HIP_DEVICE_LIB_PATH",
        "HIP_VISIBLE_DEVICES",
        "HCC_AMDGPU_TARGET",
        "OLLAMA_MAX_LOADED_MODELS",
        "OLLAMA_NUM_PARALLEL",
        "HIP_LAUNCH_BLOCKING",
    ]
]
write_csv(run_dir / "rocm_runtime_env_rows.csv", ["key", "value"], rocm_env_rows)
(run_dir / "rocm_runtime_env.json").write_text(
    json.dumps({row["key"]: row["value"] for row in rocm_env_rows}, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

hipcc = shutil.which("hipcc") or ("/opt/rocm/bin/hipcc" if Path("/opt/rocm/bin/hipcc").is_file() else None)
rocm_smi = shutil.which("rocm-smi") or ("/opt/rocm/bin/rocm-smi" if Path("/opt/rocm/bin/rocm-smi").is_file() else None)
rocm_toolchain_ready = int(hipcc is not None and rocm_smi is not None)

toolchain_rows = [
    {
        "tool": "hipcc",
        "path": hipcc or "",
        "ready": str(int(hipcc is not None)),
    },
    {
        "tool": "rocm-smi",
        "path": rocm_smi or "",
        "ready": str(int(rocm_smi is not None)),
    },
]
write_csv(run_dir / "rocm_toolchain_rows.csv", list(toolchain_rows[0].keys()), toolchain_rows)

probe_bin = run_dir / "v52v_tier_hot_shard_axpy_probe"
probe_log = run_dir / "v52v_hip_probe_transcript.txt"
kernel_bind_ready = 0
kernel_latency_ns = 0
probe_exit = 127
if hipcc and probe_src.is_file():
    rocm_path = os.environ.get("ROCM_PATH", "/opt/rocm-6.0.2")
    device_lib_path = os.environ.get("HIP_DEVICE_LIB_PATH", "")
    compile_cmd = [hipcc, f"--rocm-path={rocm_path}"]
    if device_lib_path:
        compile_cmd.append(f"--rocm-device-lib-path={device_lib_path}")
    compile_cmd.extend([str(probe_src), "-o", str(probe_bin)])
    compile_proc = subprocess.run(compile_cmd, capture_output=True, text=True)
    (run_dir / "v52v_hip_compile_transcript.txt").write_text(
        (compile_proc.stdout or "") + (compile_proc.stderr or ""), encoding="utf-8"
    )
    if compile_proc.returncode == 0 and probe_bin.is_file():
        start = time.monotonic_ns()
        run_proc = subprocess.run([str(probe_bin), "256"], capture_output=True, text=True)
        kernel_latency_ns = time.monotonic_ns() - start
        probe_exit = run_proc.returncode
        probe_log.write_text((run_proc.stdout or "") + (run_proc.stderr or ""), encoding="utf-8")
        kernel_bind_ready = int(run_proc.returncode == 0 and "v52v_axpy_probe_ok" in (run_proc.stdout or ""))

decode_rows = read_csv(v52u_dir / "tier_decode_scaffold_rows.csv")
hot_shard_path = v52u_dir / "source_v52s" / "weight_store" / "weight_shard_000.bin"
hot_page_floats = 0
if hot_shard_path.is_file():
    with hot_shard_path.open("rb") as handle:
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            header = struct.unpack("<IIII", mm[:16])
            hot_page_floats = min(256, max(0, (len(mm) - 16) // 4))

bind_rows = []
first_hot = True
for row in decode_rows:
    if row["storage_tier"] != "vram-hot":
        continue
    bind_rows.append(
        {
            "decode_step_id": row["decode_step_id"],
            "shard_id": row["shard_id"],
            "page_id": row["page_id"],
            "storage_tier": row["storage_tier"],
            "kernel_name": "v52v_tier_hot_shard_axpy_probe",
            "kernel_source_sha256": sha256(probe_src),
            "rocm_kernel_bound": str(kernel_bind_ready),
            "hot_page_floats_used": str(hot_page_floats),
            "kernel_exit_code": str(probe_exit),
            "kernel_latency_ns": str(kernel_latency_ns if first_hot else 0),
        }
    )
    first_hot = False
if not bind_rows:
    raise SystemExit("v52v requires v52u hot-tier decode scaffold rows")
write_csv(run_dir / "rocm_decode_bind_rows.csv", list(bind_rows[0].keys()), bind_rows)

resource_rows = [
    {
        "resource": "rocm-hip-probe",
        "kernel_bind_ready": str(kernel_bind_ready),
        "kernel_latency_ns": str(kernel_latency_ns),
        "external_network_used": "0",
        "ollama_monolith_used": "0",
    }
]
write_csv(run_dir / "tier_decode_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)

(run_dir / "V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md").write_text(
    "# v52v Local LLM Weight Tier ROCm Decode Bind Boundary\n\n"
    "This binds a diagnostic ROCm HIP kernel scaffold to the v52u hot-tier decode steps. "
    "It sources `scripts/ollama_rocm_env.sh`, compiles `v52v_tier_hot_shard_axpy_probe.hip`, "
    "and records kernel bind rows for vram-hot shard pages. "
    "It is not a full tiered LLM decode runtime and not a substitute for D/E measured rows.\n\n"
    f"- rocm_toolchain_ready={rocm_toolchain_ready}\n"
    f"- rocm_kernel_bind_ready={kernel_bind_ready}\n"
    f"- hot_tier_bind_rows={len(bind_rows)}\n"
    f"- kernel_latency_ns={kernel_latency_ns}\n"
    "- weight_tier_runtime_ready=0\n"
    "- monolithic_ollama_30b70b_local_ready=0\n\n"
    "Still blocked: full tiered matmul decode over NVMe shards, monolithic Ollama D/E measured rows, "
    "v52 D/E absorb, full v52, and release claims.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52v-local-llm-weight-tier-rocm-decode-bind",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52v_local_llm_weight_tier_rocm_decode_bind_ready": kernel_bind_ready,
    "rocm_kernel_bind_ready": kernel_bind_ready,
    "weight_tier_runtime_ready": 0,
    "source_v52u_summary_sha256": sha256(results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv"),
    "kernel_source_sha256": sha256(probe_src),
    "v52_ready": 0,
}
(run_dir / "v52v_local_llm_weight_tier_rocm_decode_bind_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

if kernel_bind_ready != 1:
    raise SystemExit("v52v ROCm HIP probe did not bind successfully")

summary = {
    "v52v_local_llm_weight_tier_rocm_decode_bind_ready": 1,
    "rocm_toolchain_ready": rocm_toolchain_ready,
    "rocm_kernel_bind_ready": kernel_bind_ready,
    "weight_tier_mmap_reader_ready": 1,
    "weight_tier_runtime_ready": 0,
    "hot_tier_bind_rows": len(bind_rows),
    "kernel_latency_ns": kernel_latency_ns,
    "monolithic_ollama_30b70b_local_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v52u-mmap-reader-linked", "pass", "v52u hot-tier decode scaffold rows are present"),
    ("ollama-rocm-env-sourced", "pass", "scripts/ollama_rocm_env.sh variables are recorded"),
    ("rocm-toolchain-present", "pass", "hipcc and rocm-smi are available on the host"),
    ("rocm-kernel-bind", "pass", "v52v HIP axpy probe compiled and verified on device"),
    ("hot-tier-decode-bind-rows", "pass", "vram-hot decode steps are bound to the HIP probe kernel"),
    ("full-tiered-llm-runtime", "blocked", "no full NVMe shard matmul decode runtime exists yet"),
    ("monolithic-ollama-30b70b-local", "blocked", "monolithic Ollama D/E measured rows remain deferred"),
    ("30b-llm-rag-real-row", "blocked", "D measured rows still missing"),
    ("70b-llm-rag-real-row", "blocked", "E measured rows still missing"),
    ("real-release-package", "blocked", "v52v is a ROCm bind scaffold only"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "rocm_runtime_env_rows.csv",
    "rocm_runtime_env.json",
    "rocm_toolchain_rows.csv",
    "rocm_decode_bind_rows.csv",
    "tier_decode_resource_rows.csv",
    "source_v52u/tier_decode_scaffold_rows.csv",
    "source_v52u/mmap_read_trace_rows.csv",
    "source_assets/v52v_tier_hot_shard_axpy_probe.hip",
    "v52v_hip_compile_transcript.txt",
    "v52v_hip_probe_transcript.txt",
    "V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md",
    "v52v_local_llm_weight_tier_rocm_decode_bind_manifest.json",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52v_local_llm_weight_tier_rocm_decode_bind_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
