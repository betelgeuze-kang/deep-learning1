#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52s_local_llm_weight_tier_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v52s_local_llm_weight_tier_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52s_local_llm_weight_tier_contract_decision.csv"

"$ROOT_DIR/experiments/run_v52s_local_llm_weight_tier_contract.sh" >/dev/null

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
    "v52s_local_llm_weight_tier_contract_ready": "1",
    "weight_tier_runtime_ready": "0",
    "shard_count": "6",
    "page_rows": "24",
    "hot_shard_count": "1",
    "warm_shard_count": "2",
    "cold_shard_count": "3",
    "page_size_bytes": "4096",
    "nvme_mmap_store_ready": "1",
    "h11c_store_pattern_compatible": "1",
    "monolithic_ollama_30b70b_local_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52s {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["weight-tier-contract", "nvme-mmap-weight-store", "h11c-store-pattern-compatible"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52s gate should pass: {gate}")
for gate in ["tiered-inference-runtime", "monolithic-ollama-30b70b-local", "30b-llm-rag-real-row", "70b-llm-rag-real-row"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52s gate should remain blocked: {gate}")

required = [
    "weight_shard_rows.csv",
    "weight_page_rows.csv",
    "weight_tier_policy_rows.csv",
    "weight_prefetch_trace_rows.csv",
    "local_host_profile.json",
    "weight_store/manifest.json",
    "weight_store/sha256_manifest.csv",
    "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md",
    "v52s_local_llm_weight_tier_contract_manifest.json",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52s artifact: {rel}")

shards = read_csv(run_dir / "weight_shard_rows.csv")
if len(shards) != 6 or {row["storage_tier"] for row in shards} == {"nvme-cold"}:
    raise SystemExit("v52s should emit hot/warm/cold shard tiers")
if not all((run_dir / row["shard_path"]).is_file() for row in shards):
    raise SystemExit("v52s shard files should exist under weight_store/")

manifest = json.loads((run_dir / "v52s_local_llm_weight_tier_contract_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52s_local_llm_weight_tier_contract_ready") != 1 or manifest.get("weight_tier_runtime_ready") != 0:
    raise SystemExit("v52s manifest readiness mismatch")

boundary = (run_dir / "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["NVMe-mmap weight shard store", "h11-c RouteMemory store pattern", "tiered decode runtime"]:
    if snippet not in boundary:
        raise SystemExit(f"v52s boundary missing {snippet}")
PY

echo "v52s local LLM weight tier contract smoke passed"
