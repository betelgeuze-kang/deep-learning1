#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52w_local_llm_weight_tier_matmul_decode"
RUN_ID="${V52W_RUN_ID:-runtime_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V52V_DIR="${V52V_BIND_DIR:-$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind/bind_001}"
V52U_DIR="${V52U_READER_DIR:-$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader/reader_001}"

if [[ "${V52W_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52w_local_llm_weight_tier_matmul_decode_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv" ]]; then
  V52V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52v_local_llm_weight_tier_rocm_decode_bind.sh" >/dev/null
fi

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/ollama_rocm_env.sh"
export PATH="/opt/rocm/bin:${PATH:-}"

python3 - "$ROOT_DIR" "$RUN_DIR" "$V52V_DIR" "$V52U_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
v52v_dir = Path(sys.argv[3])
v52u_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
results = root / "results"
assets = root / "experiments" / "assets"
probe_src = assets / "v52w_tier_shard_matmul_probe.hip"
matmul_k = int(os.environ.get("V52W_MATMUL_K", "8"))

v52v_summary = list(csv.DictReader((results / "v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv").open(newline="", encoding="utf-8")))[0]
if int(v52v_summary.get("rocm_kernel_bind_ready", "0")) != 1:
    raise SystemExit("v52w requires v52v with rocm_kernel_bind_ready=1")


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


copy(v52v_dir / "rocm_decode_bind_rows.csv", "source_v52v/rocm_decode_bind_rows.csv")
copy(v52u_dir / "tier_decode_scaffold_rows.csv", "source_v52u/tier_decode_scaffold_rows.csv")
copy(v52u_dir / "mmap_read_trace_rows.csv", "source_v52u/mmap_read_trace_rows.csv")
copy(results / "v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv", "source_v52v/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv")
copy(results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv", "source_v52u/v52u_local_llm_weight_tier_mmap_reader_summary.csv")
copy(probe_src, "source_assets/v52w_tier_shard_matmul_probe.hip")

page_rows = read_csv(v52u_dir / "source_v52s" / "weight_page_rows.csv")
page_by_key = {(row["shard_id"], row["page_id"]): row for row in page_rows}
decode_rows = read_csv(v52u_dir / "tier_decode_scaffold_rows.csv")

hipcc = shutil.which("hipcc") or ("/opt/rocm/bin/hipcc" if Path("/opt/rocm/bin/hipcc").is_file() else None)
probe_bin = run_dir / "v52w_tier_shard_matmul_probe"
runtime_ready = 0
compile_ok = 0
if hipcc and probe_src.is_file():
    rocm_path = os.environ.get("ROCM_PATH", "/opt/rocm-6.0.2")
    device_lib_path = os.environ.get("HIP_DEVICE_LIB_PATH", "")
    compile_cmd = [hipcc, f"--rocm-path={rocm_path}", "-std=c++17"]
    if device_lib_path:
        compile_cmd.append(f"--rocm-device-lib-path={device_lib_path}")
    compile_cmd.extend([str(probe_src), "-o", str(probe_bin)])
    compile_proc = subprocess.run(compile_cmd, capture_output=True, text=True)
    (run_dir / "v52w_hip_compile_transcript.txt").write_text(
        (compile_proc.stdout or "") + (compile_proc.stderr or ""), encoding="utf-8"
    )
    compile_ok = int(compile_proc.returncode == 0 and probe_bin.is_file())

matmul_rows = []
resource_by_tier = {"vram-hot": 0, "dram-warm": 0, "nvme-cold": 0}
latency_by_tier = {"vram-hot": 0, "dram-warm": 0, "nvme-cold": 0}
bound_rows = 0
total_latency_ns = 0
probe_transcript_parts = []

if compile_ok:
    for row in decode_rows:
        shard_id = row["shard_id"]
        page_id = row["page_id"]
        tier = row["storage_tier"]
        page = page_by_key[(shard_id, page_id)]
        shard_path = v52u_dir / "source_v52s" / "weight_store" / f"weight_shard_{int(shard_id):03d}.bin"
        start = time.monotonic_ns()
        run_proc = None
        for _attempt in range(3):
            run_proc = subprocess.run(
                [str(probe_bin), str(matmul_k), str(shard_path), page["page_offset"], row["decode_step_id"]],
                capture_output=True,
                text=True,
            )
            transcript_try = (run_proc.stdout or "") + (run_proc.stderr or "")
            if run_proc.returncode == 0 and "v52w_matmul_probe_ok" in transcript_try:
                break
            time.sleep(0.05)
        latency_ns = time.monotonic_ns() - start
        transcript = (run_proc.stdout or "") + (run_proc.stderr or "")
        probe_transcript_parts.append(transcript)
        bound = int(run_proc.returncode == 0 and "v52w_matmul_probe_ok" in transcript)
        bound_rows += bound
        total_latency_ns += latency_ns
        resource_by_tier[tier] += int(row["bytes_touched"])
        latency_by_tier[tier] += latency_ns
        matmul_rows.append(
            {
                "decode_step_id": row["decode_step_id"],
                "shard_id": shard_id,
                "page_id": page_id,
                "storage_tier": tier,
                "decode_stage": row["decode_stage"],
                "kernel_name": "v52w_tier_shard_matmul_probe",
                "kernel_source_sha256": sha256(probe_src),
                "matmul_m": str(matmul_k),
                "matmul_n": "1",
                "matmul_k": str(matmul_k),
                "weight_bytes_source": f"mmap:{shard_path.name}@{page['page_offset']}",
                "rocm_kernel_bound": str(bound),
                "numeric_check_pass": str(bound),
                "kernel_exit_code": str(run_proc.returncode),
                "kernel_latency_ns": str(latency_ns),
                "prefetch_hit": row["prefetch_hit"],
            }
        )
    runtime_ready = int(bound_rows == len(decode_rows) and bound_rows > 0)
    (run_dir / "v52w_hip_probe_transcript.txt").write_text("".join(probe_transcript_parts), encoding="utf-8")
else:
    raise SystemExit("v52w HIP matmul probe compile failed")

write_csv(run_dir / "tier_matmul_decode_rows.csv", list(matmul_rows[0].keys()), matmul_rows)

resource_rows = [
    {
        "resource": "tiered-nvme-shard-matmul",
        "hot_bytes_touched": str(resource_by_tier["vram-hot"]),
        "warm_bytes_touched": str(resource_by_tier["dram-warm"]),
        "cold_bytes_touched": str(resource_by_tier["nvme-cold"]),
        "total_kernel_latency_ns": str(total_latency_ns),
        "external_network_used": "0",
        "ollama_monolith_used": "0",
        "weight_tier_runtime_ready": str(runtime_ready),
    }
]
write_csv(run_dir / "tier_matmul_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)

(run_dir / "V52W_LOCAL_LLM_WEIGHT_TIER_MATMUL_DECODE_BOUNDARY.md").write_text(
    "# v52w Local LLM Weight Tier Matmul Decode Boundary\n\n"
    "This extends the v52v ROCm bind into a diagnostic tiered matmul decode runtime over NVMe-mmap weight shard pages. "
    "It mmap-opens hot/warm/cold shard pages, feeds page payload bytes into a HIP matmul probe kernel, and records per-tier decode rows. "
    "It is a tier-runtime scaffold, not a full transformer decode loop and not a substitute for externally baked D/E measured rows.\n\n"
    f"- matmul_k={matmul_k}\n"
    f"- tier_matmul_decode_rows={len(matmul_rows)}\n"
    f"- hot_tier_matmul_rows={sum(1 for row in matmul_rows if row['storage_tier'] == 'vram-hot')}\n"
    f"- warm_tier_matmul_rows={sum(1 for row in matmul_rows if row['storage_tier'] == 'dram-warm')}\n"
    f"- cold_tier_matmul_rows={sum(1 for row in matmul_rows if row['storage_tier'] == 'nvme-cold')}\n"
    f"- weight_tier_runtime_ready={runtime_ready}\n"
    f"- rocm_kernel_bind_ready={runtime_ready}\n"
    "- monolithic_ollama_30b70b_local_ready=0\n"
    "- required_30b_baseline_ready=0\n"
    "- required_70b_baseline_ready=0\n\n"
    "Still blocked: full transformer decode over all layers, monolithic Ollama D/E measured rows unless externally baked, "
    "v52 D/E registry absorb, full v52, and release claims.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52w-local-llm-weight-tier-matmul-decode",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52w_local_llm_weight_tier_matmul_decode_ready": runtime_ready,
    "weight_tier_matmul_decode_ready": runtime_ready,
    "weight_tier_runtime_ready": runtime_ready,
    "rocm_kernel_bind_ready": runtime_ready,
    "matmul_k": matmul_k,
    "source_v52v_summary_sha256": sha256(results / "v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv"),
    "kernel_source_sha256": sha256(probe_src),
    "v52_ready": 0,
}
(run_dir / "v52w_local_llm_weight_tier_matmul_decode_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

if runtime_ready != 1:
    raise SystemExit("v52w tiered matmul decode runtime did not become ready")

summary = {
    "v52w_local_llm_weight_tier_matmul_decode_ready": 1,
    "weight_tier_matmul_decode_ready": 1,
    "weight_tier_runtime_ready": 1,
    "rocm_kernel_bind_ready": 1,
    "weight_tier_mmap_reader_ready": 1,
    "tier_matmul_decode_rows": len(matmul_rows),
    "hot_tier_matmul_rows": sum(1 for row in matmul_rows if row["storage_tier"] == "vram-hot"),
    "warm_tier_matmul_rows": sum(1 for row in matmul_rows if row["storage_tier"] == "dram-warm"),
    "cold_tier_matmul_rows": sum(1 for row in matmul_rows if row["storage_tier"] == "nvme-cold"),
    "total_kernel_latency_ns": total_latency_ns,
    "monolithic_ollama_30b70b_local_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v52v-rocm-bind-linked", "pass", "v52v ROCm toolchain and hot-tier bind scaffold are present"),
    ("v52u-mmap-reader-linked", "pass", "v52u tier decode scaffold rows drive per-page matmul probes"),
    ("hot-warm-cold-matmul-scaffold", "pass", "all hot/warm/cold decode steps run the HIP matmul probe"),
    ("mmap-weight-bytes-consumed", "pass", "matmul probes mmap NVMe shard pages and consume page payload bytes"),
    ("weight-tier-runtime-ready", "pass", "diagnostic tiered matmul decode runtime is ready across all tiers"),
    ("full-transformer-decode", "blocked", "no full transformer layer decode loop exists yet"),
    ("monolithic-ollama-30b70b-local", "blocked", "monolithic Ollama D/E measured rows remain deferred locally"),
    ("30b-llm-rag-real-row", "blocked", "D measured rows still require external bake or tier-runtime generation"),
    ("70b-llm-rag-real-row", "blocked", "E measured rows still require external bake or tier-runtime generation"),
    ("real-release-package", "blocked", "v52w is a tier-runtime scaffold only"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "tier_matmul_decode_rows.csv",
    "tier_matmul_resource_rows.csv",
    "source_v52v/rocm_decode_bind_rows.csv",
    "source_v52u/tier_decode_scaffold_rows.csv",
    "source_v52u/mmap_read_trace_rows.csv",
    "source_assets/v52w_tier_shard_matmul_probe.hip",
    "v52w_hip_compile_transcript.txt",
    "v52w_hip_probe_transcript.txt",
    "V52W_LOCAL_LLM_WEIGHT_TIER_MATMUL_DECODE_BOUNDARY.md",
    "v52w_local_llm_weight_tier_matmul_decode_manifest.json",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52w_local_llm_weight_tier_matmul_decode_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
