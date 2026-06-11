#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52w_local_llm_weight_tier_matmul_decode/runtime_001"
SUMMARY_CSV="$RESULTS_DIR/v52w_local_llm_weight_tier_matmul_decode_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52w_local_llm_weight_tier_matmul_decode_decision.csv"

V52W_REUSE_EXISTING="${V52W_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52w_local_llm_weight_tier_matmul_decode.sh" >/dev/null

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
    "v52w_local_llm_weight_tier_matmul_decode_ready": "1",
    "weight_tier_matmul_decode_ready": "1",
    "weight_tier_runtime_ready": "1",
    "rocm_kernel_bind_ready": "1",
    "weight_tier_mmap_reader_ready": "1",
    "tier_matmul_decode_rows": "24",
    "hot_tier_matmul_rows": "4",
    "warm_tier_matmul_rows": "8",
    "cold_tier_matmul_rows": "12",
    "monolithic_ollama_30b70b_local_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52w {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("total_kernel_latency_ns", "0")) <= 0:
    raise SystemExit("v52w total_kernel_latency_ns should be positive")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52v-rocm-bind-linked",
    "v52u-mmap-reader-linked",
    "hot-warm-cold-matmul-scaffold",
    "mmap-weight-bytes-consumed",
    "weight-tier-runtime-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52w gate should pass: {gate}")
for gate in ["full-transformer-decode", "monolithic-ollama-30b70b-local", "30b-llm-rag-real-row"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52w gate should remain blocked: {gate}")

matmul_rows = read_csv(run_dir / "tier_matmul_decode_rows.csv")
if len(matmul_rows) != 24:
    raise SystemExit("v52w should emit 24 tier matmul decode rows")
if {row["rocm_kernel_bound"] for row in matmul_rows} != {"1"}:
    raise SystemExit("v52w should bind all tier matmul rows")
if {row["numeric_check_pass"] for row in matmul_rows} != {"1"}:
    raise SystemExit("v52w numeric checks should pass for all rows")

probe = (run_dir / "v52w_hip_probe_transcript.txt").read_text(encoding="utf-8")
if probe.count("v52w_matmul_probe_ok") != 24:
    raise SystemExit("v52w HIP probe transcript should contain 24 success markers")

manifest = json.loads((run_dir / "v52w_local_llm_weight_tier_matmul_decode_manifest.json").read_text(encoding="utf-8"))
if manifest.get("weight_tier_runtime_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52w manifest readiness mismatch")

boundary = (run_dir / "V52W_LOCAL_LLM_WEIGHT_TIER_MATMUL_DECODE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["weight_tier_runtime_ready=1", "NVMe-mmap weight shard", "externally baked D/E"]:
    if snippet not in boundary:
        raise SystemExit(f"v52w boundary missing {snippet}")
PY

echo "v52w local LLM weight tier matmul decode smoke passed"
