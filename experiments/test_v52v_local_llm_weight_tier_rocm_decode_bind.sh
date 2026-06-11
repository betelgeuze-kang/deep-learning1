#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind/bind_001"
SUMMARY_CSV="$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind_decision.csv"

V52V_REUSE_EXISTING="${V52V_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52v_local_llm_weight_tier_rocm_decode_bind.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v52v_local_llm_weight_tier_rocm_decode_bind_ready": "1",
    "rocm_toolchain_ready": "1",
    "rocm_kernel_bind_ready": "1",
    "weight_tier_mmap_reader_ready": "1",
    "weight_tier_runtime_ready": "0",
    "hot_tier_bind_rows": "4",
    "monolithic_ollama_30b70b_local_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52v {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("kernel_latency_ns", "0")) <= 0:
    raise SystemExit("v52v kernel_latency_ns should be positive")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52u-mmap-reader-linked",
    "ollama-rocm-env-sourced",
    "rocm-toolchain-present",
    "rocm-kernel-bind",
    "hot-tier-decode-bind-rows",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52v gate should pass: {gate}")
for gate in ["full-tiered-llm-runtime", "monolithic-ollama-30b70b-local", "30b-llm-rag-real-row"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52v gate should remain blocked: {gate}")

bind_rows = read_csv(run_dir / "rocm_decode_bind_rows.csv")
if len(bind_rows) != 4 or {row["rocm_kernel_bound"] for row in bind_rows} != {"1"}:
    raise SystemExit("v52v should bind four hot-tier decode rows")

env_rows = {row["key"]: row["value"] for row in read_csv(run_dir / "rocm_runtime_env_rows.csv")}
if env_rows.get("HCC_AMDGPU_TARGET") != "gfx1030" or env_rows.get("HIP_VISIBLE_DEVICES") != "0":
    raise SystemExit("v52v should record ollama_rocm_env settings")
if env_rows.get("HIP_LAUNCH_BLOCKING", "") not in ("", None):
    raise SystemExit("v52v should keep HIP_LAUNCH_BLOCKING unset")

probe = (run_dir / "v52v_hip_probe_transcript.txt").read_text(encoding="utf-8")
if "v52v_axpy_probe_ok" not in probe:
    raise SystemExit("v52v HIP probe transcript missing success marker")

manifest = json.loads((run_dir / "v52v_local_llm_weight_tier_rocm_decode_bind_manifest.json").read_text(encoding="utf-8"))
if manifest.get("rocm_kernel_bind_ready") != 1 or manifest.get("weight_tier_runtime_ready") != 0:
    raise SystemExit("v52v manifest readiness mismatch")

boundary = (run_dir / "V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["ollama_rocm_env.sh", "rocm_kernel_bind_ready=1", "weight_tier_runtime_ready=0"]:
    if snippet not in boundary:
        raise SystemExit(f"v52v boundary missing {snippet}")
PY

echo "v52v local LLM weight tier ROCm decode bind smoke passed"
