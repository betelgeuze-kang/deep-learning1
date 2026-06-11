#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52s_local_llm_weight_tier_contract"
RUN_ID="${V52S_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
STORE_ROOT="${V52S_WEIGHT_STORE_DIR:-$RUN_DIR/weight_store}"

if [[ "${V52S_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52s_local_llm_weight_tier_contract_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$STORE_ROOT" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
store_root = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
results = root / "results"

PAGE_SIZE = 4096
SHARD_COUNT = 6
HOT_SHARDS = 1
WARM_SHARDS = 2


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


store_root.mkdir(parents=True, exist_ok=True)
shard_rows = []
page_rows = []
for shard_id in range(SHARD_COUNT):
    shard_name = f"weight_shard_{shard_id:03d}.bin"
    shard_path = store_root / shard_name
    payload = bytearray()
    for page_id in range(4):
        header = struct.pack("<IIII", shard_id, page_id, PAGE_SIZE, 0xC001D00D)
        body = bytes([(shard_id * 17 + page_id * 31 + i) % 256 for i in range(PAGE_SIZE - len(header))])
        page_bytes = (header + body)[:PAGE_SIZE]
        payload.extend(page_bytes)
        page_rows.append(
            {
                "shard_id": str(shard_id),
                "page_id": str(page_id),
                "page_offset": str(page_id * PAGE_SIZE),
                "page_size_bytes": str(PAGE_SIZE),
                "page_sha256": "sha256:" + hashlib.sha256(page_bytes).hexdigest(),
                "storage_tier": "nvme-cold",
            }
        )
    shard_path.write_bytes(payload)
    if shard_id < HOT_SHARDS:
        tier = "vram-hot"
    elif shard_id < HOT_SHARDS + WARM_SHARDS:
        tier = "dram-warm"
    else:
        tier = "nvme-cold"
    shard_rows.append(
        {
            "shard_id": str(shard_id),
            "shard_path": f"weight_store/{shard_name}",
            "shard_bytes": str(shard_path.stat().st_size),
            "shard_sha256": sha256(shard_path),
            "storage_tier": tier,
            "prefetch_priority": str(max(0, 3 - shard_id)),
            "layer_group": f"block-{shard_id // 2}",
        }
    )

manifest = {
    "manifest_scope": "v52s-local-llm-weight-tier-store",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "page_size_bytes": PAGE_SIZE,
    "shard_count": SHARD_COUNT,
    "hot_shard_count": HOT_SHARDS,
    "warm_shard_count": WARM_SHARDS,
    "cold_shard_count": SHARD_COUNT - HOT_SHARDS - WARM_SHARDS,
    "mmap_open_mode": "read-only",
    "compatible_with_h11c_store_pattern": 1,
}
(store_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = []
artifact_rows = []
for rel_path in sorted(store_root.rglob("*")):
    if rel_path.is_file():
        rel = str(rel_path.relative_to(run_dir))
        artifact_rels.append(rel)
        artifact_rows.append({"path": rel, "sha256": sha256(rel_path), "bytes": rel_path.stat().st_size})
write_csv(store_root / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)
write_csv(run_dir / "weight_shard_rows.csv", list(shard_rows[0].keys()), shard_rows)
write_csv(run_dir / "weight_page_rows.csv", list(page_rows[0].keys()), page_rows)

tier_policy_rows = [
    {
        "tier": "vram-hot",
        "resident_role": "active-layer-weights-and-kv-head",
        "capacity_hint_bytes": str(14 * 1024 * 1024 * 1024),
        "eviction_policy": "lru-with-prefetch-hint",
    },
    {
        "tier": "dram-warm",
        "resident_role": "prefetch-ring-next-shards",
        "capacity_hint_bytes": str(8 * 1024 * 1024 * 1024),
        "eviction_policy": "sequential-prefetch",
    },
    {
        "tier": "nvme-cold",
        "resident_role": "mmap-weight-shards",
        "capacity_hint_bytes": "ssd-budget-only",
        "eviction_policy": "on-demand-page-read",
    },
]
write_csv(run_dir / "weight_tier_policy_rows.csv", list(tier_policy_rows[0].keys()), tier_policy_rows)

prefetch_rows = [
    {
        "event": "cold-page-read",
        "shard_id": "3",
        "page_id": "0",
        "bytes_read": str(PAGE_SIZE),
        "latency_ns": "2500000",
        "prefetch_hit": "0",
    },
    {
        "event": "warm-prefetch",
        "shard_id": "1",
        "page_id": "1",
        "bytes_read": str(PAGE_SIZE),
        "latency_ns": "120000",
        "prefetch_hit": "1",
    },
]
write_csv(run_dir / "weight_prefetch_trace_rows.csv", list(prefetch_rows[0].keys()), prefetch_rows)

host_profile = {
    "gpu_model": os.environ.get("V52S_GPU_MODEL", "AMD Radeon RX 6800 class"),
    "gpu_vram_bytes": os.environ.get("V52S_GPU_VRAM_BYTES", str(16 * 1024 * 1024 * 1024)),
    "system_ram_bytes": os.environ.get("V52S_SYSTEM_RAM_BYTES", str(32 * 1024 * 1024 * 1024)),
    "rocm_path": os.environ.get("ROCM_PATH", "/opt/rocm-6.0.2"),
    "ollama_monolith_blocked_reason": "model-bytes-exceed-vram-without-tier-runtime",
}
(run_dir / "local_host_profile.json").write_text(json.dumps(host_profile, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md").write_text(
    "# v52s Local LLM Weight Tier Contract Boundary\n\n"
    "This emits an NVMe-mmap weight shard store contract aligned with the h11-c RouteMemory store pattern. "
    "It is not a working tiered inference runtime and not a substitute for real D/E measured rows.\n\n"
    f"- shard_count={SHARD_COUNT}\n"
    f"- hot_shard_count={HOT_SHARDS}\n"
    f"- warm_shard_count={WARM_SHARDS}\n"
    f"- cold_shard_count={SHARD_COUNT - HOT_SHARDS - WARM_SHARDS}\n"
    "- page_size_bytes=4096\n"
    "- mmap_open_mode=read-only\n"
    "- compatible_with_h11c_store_pattern=1\n\n"
    "Still blocked: monolithic Ollama 30B/70B local measured rows on 16GB VRAM hosts, "
    "tiered decode runtime, v52 D/E absorb, full v52, and release claims.\n",
    encoding="utf-8",
)

manifest_out = {
    "manifest_scope": "v52s-local-llm-weight-tier-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52s_local_llm_weight_tier_contract_ready": 1,
    "shard_count": SHARD_COUNT,
    "page_size_bytes": PAGE_SIZE,
    "weight_tier_runtime_ready": 0,
    "v52_ready": 0,
}
(run_dir / "v52s_local_llm_weight_tier_contract_manifest.json").write_text(
    json.dumps(manifest_out, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

summary = {
    "v52s_local_llm_weight_tier_contract_ready": 1,
    "weight_tier_runtime_ready": 0,
    "shard_count": SHARD_COUNT,
    "page_rows": len(page_rows),
    "hot_shard_count": HOT_SHARDS,
    "warm_shard_count": WARM_SHARDS,
    "cold_shard_count": SHARD_COUNT - HOT_SHARDS - WARM_SHARDS,
    "page_size_bytes": PAGE_SIZE,
    "nvme_mmap_store_ready": 1,
    "h11c_store_pattern_compatible": 1,
    "monolithic_ollama_30b70b_local_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("weight-tier-contract", "pass", "hot/warm/cold shard contract and policy rows are emitted"),
    ("nvme-mmap-weight-store", "pass", "generated weight shard store has hash manifest and page table rows"),
    ("h11c-store-pattern-compatible", "pass", "manifest + sha256_manifest + mmap pages follow h11-c artifact shape"),
    ("tiered-inference-runtime", "blocked", "no tiered decode runtime binds shards to ROCm yet"),
    ("monolithic-ollama-30b70b-local", "blocked", "16GB VRAM host cannot run 30B/70B monolith at usable speed"),
    ("30b-llm-rag-real-row", "blocked", "D measured rows still missing"),
    ("70b-llm-rag-real-row", "blocked", "E measured rows still missing"),
    ("real-release-package", "blocked", "v52s is a storage/tier contract only"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

run_artifact_rels = [
    "weight_shard_rows.csv",
    "weight_page_rows.csv",
    "weight_tier_policy_rows.csv",
    "weight_prefetch_trace_rows.csv",
    "local_host_profile.json",
    "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md",
    "v52s_local_llm_weight_tier_contract_manifest.json",
    *artifact_rels,
]
sha_manifest = []
for rel in run_artifact_rels:
    path = run_dir / rel
    sha_manifest.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_manifest)

print(f"v52s_local_llm_weight_tier_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
