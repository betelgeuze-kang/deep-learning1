#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader/reader_001"
SUMMARY_CSV="$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader_decision.csv"

V52U_REUSE_EXISTING="${V52U_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52u_local_llm_weight_tier_mmap_reader.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v52u_local_llm_weight_tier_mmap_reader_ready": "1",
    "weight_tier_mmap_reader_ready": "1",
    "weight_tier_runtime_ready": "0",
    "v52s_contract_linked": "1",
    "mmap_opened_shards": "6",
    "mmap_page_reads": "24",
    "page_hash_matches": "24",
    "hot_tier_reads": "4",
    "warm_tier_reads": "8",
    "cold_tier_reads": "12",
    "rocm_kernel_bound": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52u {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("prefetch_hit_rows", "0")) < 1:
    raise SystemExit("v52u should record at least one warm-tier prefetch hit")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52s-weight-store-linked",
    "tiered-mmap-page-reads",
    "warm-prefetch-scaffold",
    "v13b-reader-abi-shape",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52u gate should pass: {gate}")
for gate in ["rocm-decode-kernel", "monolithic-ollama-30b70b-local", "30b-llm-rag-real-row", "70b-llm-rag-real-row"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52u gate should remain blocked: {gate}")

required = [
    "mmap_read_trace_rows.csv",
    "tier_decode_scaffold_rows.csv",
    "tier_reader_resource_rows.csv",
    "source_v52s/weight_store/manifest.json",
    "V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md",
    "v52u_local_llm_weight_tier_mmap_reader_manifest.json",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52u artifact: {rel}")

trace = read_csv(run_dir / "mmap_read_trace_rows.csv")
if len(trace) != 24 or {row["page_hash_match"] for row in trace} != {"1"}:
    raise SystemExit("v52u mmap trace should verify all page hashes")
if {row["storage_tier"] for row in trace} != {"vram-hot", "dram-warm", "nvme-cold"}:
    raise SystemExit("v52u should mmap-read hot/warm/cold tiers")

decode = read_csv(run_dir / "tier_decode_scaffold_rows.csv")
if len(decode) != 24 or {row["rocm_kernel_bound"] for row in decode} != {"0"}:
    raise SystemExit("v52u decode scaffold should stay ROCm-unbound")

manifest = json.loads((run_dir / "v52u_local_llm_weight_tier_mmap_reader_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52u_local_llm_weight_tier_mmap_reader_ready") != 1 or manifest.get("weight_tier_runtime_ready") != 0:
    raise SystemExit("v52u manifest readiness mismatch")

boundary = (run_dir / "V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["v13-b RouteLM mmap reader ABI shape", "weight_tier_mmap_reader_ready=1", "rocm_kernel_bound=0"]:
    if snippet not in boundary:
        raise SystemExit(f"v52u boundary missing {snippet}")
PY

echo "v52u local LLM weight tier mmap reader smoke passed"
