#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52u_local_llm_weight_tier_mmap_reader"
RUN_ID="${V52U_RUN_ID:-reader_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V52S_DIR="${V52S_CONTRACT_DIR:-$RESULTS_DIR/v52s_local_llm_weight_tier_contract/contract_001}"

if [[ "${V52U_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52u_local_llm_weight_tier_mmap_reader_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52s_local_llm_weight_tier_contract_summary.csv" ]]; then
  V52S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52s_local_llm_weight_tier_contract.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$V52S_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import mmap
import shutil
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v52s_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
results = root / "results"

if not v52s_dir.is_dir():
    raise SystemExit(f"v52u requires v52s contract dir: {v52s_dir}")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


copy(v52s_dir / "weight_store", "source_v52s/weight_store")
for rel in [
    "weight_shard_rows.csv",
    "weight_page_rows.csv",
    "weight_tier_policy_rows.csv",
    "local_host_profile.json",
    "v52s_local_llm_weight_tier_contract_manifest.json",
    "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md",
]:
    copy(v52s_dir / rel, f"source_v52s/{rel}")
copy(results / "v52s_local_llm_weight_tier_contract_summary.csv", "source_v52s/v52s_local_llm_weight_tier_contract_summary.csv")

v52s_summary = read_csv(results / "v52s_local_llm_weight_tier_contract_summary.csv")[0]
if int(v52s_summary.get("v52s_local_llm_weight_tier_contract_ready", "0")) != 1:
    raise SystemExit("v52u requires v52s with v52s_local_llm_weight_tier_contract_ready=1")

store_dir = run_dir / "source_v52s" / "weight_store"
manifest = json.loads((store_dir / "manifest.json").read_text(encoding="utf-8"))
page_size = int(manifest["page_size_bytes"])
shard_rows = read_csv(run_dir / "source_v52s/weight_shard_rows.csv")
page_rows = read_csv(run_dir / "source_v52s/weight_page_rows.csv")

for row in read_csv(store_dir / "sha256_manifest.csv"):
    rel = row["path"]
    if rel.startswith("weight_store/"):
        rel = rel.split("weight_store/", 1)[1]
    path = store_dir / rel
    if not path.is_file() or sha256(path) != row["sha256"]:
        raise SystemExit(f"v52s store hash mismatch: {rel}")

mmap_trace_rows = []
decode_rows = []
hot_reads = warm_reads = cold_reads = 0
prefetch_hits = 0
page_hash_matches = 0
mmap_opened_shards = 0
warm_prefetch_cache = set()

for shard in shard_rows:
    shard_id = shard["shard_id"]
    shard_path = run_dir / "source_v52s" / shard["shard_path"]
    tier = shard["storage_tier"]
    with shard_path.open("rb") as handle:
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            mmap_opened_shards += 1
            shard_pages = [row for row in page_rows if row["shard_id"] == shard_id]
            for page in shard_pages:
                page_id = int(page["page_id"])
                offset = int(page["page_offset"])
                size = int(page["page_size_bytes"])
                cache_key = (shard_id, page_id)
                prefetch_hit = 1 if cache_key in warm_prefetch_cache else 0
                if prefetch_hit:
                    prefetch_hits += 1
                warm_prefetch_cache.discard(cache_key)

                start_ns = time.monotonic_ns()
                page_bytes = mm[offset : offset + size]
                latency_ns = time.monotonic_ns() - start_ns

                if len(page_bytes) != size:
                    raise SystemExit(f"short mmap read shard={shard_id} page={page_id}")
                header = struct.unpack("<IIII", page_bytes[:16])
                if header[0] != int(shard_id) or header[1] != page_id or header[3] != 0xC001D00D:
                    raise SystemExit(f"page header mismatch shard={shard_id} page={page_id}")

                page_hash = sha256_bytes(page_bytes)
                if page_hash == page["page_sha256"]:
                    page_hash_matches += 1

                if tier == "vram-hot":
                    hot_reads += 1
                    decode_stage = "hot-resident-matmul-scaffold"
                elif tier == "dram-warm":
                    warm_reads += 1
                    decode_stage = "warm-prefetch-decode-scaffold"
                    next_key = (shard_id, page_id + 1)
                    if any(int(r["page_id"]) == page_id + 1 for r in shard_pages):
                        warm_prefetch_cache.add(next_key)
                else:
                    cold_reads += 1
                    decode_stage = "cold-nvme-mmap-decode-scaffold"

                mmap_trace_rows.append(
                    {
                        "shard_id": shard_id,
                        "page_id": str(page_id),
                        "storage_tier": tier,
                        "byte_offset": str(offset),
                        "bytes_read": str(size),
                        "latency_ns": str(latency_ns),
                        "page_sha256": page_hash,
                        "page_hash_match": "1" if page_hash == page["page_sha256"] else "0",
                        "prefetch_hit": str(prefetch_hit),
                    }
                )
                decode_rows.append(
                    {
                        "decode_step_id": f"{shard_id}-{page_id}",
                        "shard_id": shard_id,
                        "page_id": str(page_id),
                        "storage_tier": tier,
                        "decode_stage": decode_stage,
                        "rocm_kernel_bound": "0",
                        "bytes_touched": str(size),
                        "prefetch_hit": str(prefetch_hit),
                    }
                )

write_csv(run_dir / "mmap_read_trace_rows.csv", list(mmap_trace_rows[0].keys()), mmap_trace_rows)
write_csv(run_dir / "tier_decode_scaffold_rows.csv", list(decode_rows[0].keys()), decode_rows)

resource_rows = [
    {
        "resource": "nvme-mmap-weight-shards",
        "bytes_read": str(sum(int(row["bytes_read"]) for row in mmap_trace_rows)),
        "page_reads": str(len(mmap_trace_rows)),
        "external_network_used": "0",
        "route_memory_store_used": "0",
    }
]
write_csv(run_dir / "tier_reader_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)

(run_dir / "V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md").write_text(
    "# v52u Local LLM Weight Tier Mmap Reader Boundary\n\n"
    "This is a diagnostic tiered-decode mmap reader scaffold over the v52s NVMe weight shard store. "
    "It follows the v13-b RouteLM mmap reader ABI shape but targets hot/warm/cold weight shards instead of RouteMemory chunks. "
    "It is not a ROCm matmul runtime and not a substitute for real D/E measured rows.\n\n"
    f"- mmap_opened_shards={mmap_opened_shards}\n"
    f"- mmap_page_reads={len(mmap_trace_rows)}\n"
    f"- page_hash_matches={page_hash_matches}\n"
    f"- hot_tier_reads={hot_reads}\n"
    f"- warm_tier_reads={warm_reads}\n"
    f"- cold_tier_reads={cold_reads}\n"
    f"- prefetch_hit_rows={prefetch_hits}\n"
    "- weight_tier_mmap_reader_ready=1\n"
    "- weight_tier_runtime_ready=0\n"
    "- rocm_kernel_bound=0\n\n"
    "Still blocked: ROCm decode kernel binding, monolithic Ollama 30B/70B local measured rows, "
    "v52 D/E absorb, full v52, and release claims.\n",
    encoding="utf-8",
)

manifest_out = {
    "manifest_scope": "v52u-local-llm-weight-tier-mmap-reader",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52u_local_llm_weight_tier_mmap_reader_ready": 1,
    "weight_tier_mmap_reader_ready": 1,
    "weight_tier_runtime_ready": 0,
    "mmap_opened_shards": mmap_opened_shards,
    "mmap_page_reads": len(mmap_trace_rows),
    "source_v52s_summary_sha256": sha256(results / "v52s_local_llm_weight_tier_contract_summary.csv"),
    "v52_ready": 0,
}
(run_dir / "v52u_local_llm_weight_tier_mmap_reader_manifest.json").write_text(
    json.dumps(manifest_out, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

reader_ready = int(
    mmap_opened_shards == len(shard_rows)
    and page_hash_matches == len(page_rows)
    and hot_reads >= 1
    and warm_reads >= 1
    and cold_reads >= 1
)
summary = {
    "v52u_local_llm_weight_tier_mmap_reader_ready": reader_ready,
    "weight_tier_mmap_reader_ready": reader_ready,
    "weight_tier_runtime_ready": 0,
    "v52s_contract_linked": 1,
    "mmap_opened_shards": mmap_opened_shards,
    "mmap_page_reads": len(mmap_trace_rows),
    "page_hash_matches": page_hash_matches,
    "hot_tier_reads": hot_reads,
    "warm_tier_reads": warm_reads,
    "cold_tier_reads": cold_reads,
    "prefetch_hit_rows": prefetch_hits,
    "rocm_kernel_bound": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
if reader_ready != 1:
    raise SystemExit("v52u mmap reader scaffold did not verify all shard pages")
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v52s-weight-store-linked", "pass", "v52s weight shard store and hash manifest are copied and verified"),
    ("tiered-mmap-page-reads", "pass", "hot/warm/cold shard pages are mmap-read with header and hash checks"),
    ("warm-prefetch-scaffold", "pass", "warm-tier prefetch-hit scaffold rows are emitted"),
    ("v13b-reader-abi-shape", "pass", "mmap trace and decode scaffold rows follow the v13-b reader pattern"),
    ("rocm-decode-kernel", "blocked", "no ROCm matmul kernel is bound to resident shards yet"),
    ("monolithic-ollama-30b70b-local", "blocked", "monolithic Ollama D/E measured rows remain deferred"),
    ("30b-llm-rag-real-row", "blocked", "D measured rows still missing"),
    ("70b-llm-rag-real-row", "blocked", "E measured rows still missing"),
    ("real-release-package", "blocked", "v52u is a mmap reader scaffold only"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "mmap_read_trace_rows.csv",
    "tier_decode_scaffold_rows.csv",
    "tier_reader_resource_rows.csv",
    "source_v52s/weight_shard_rows.csv",
    "source_v52s/weight_page_rows.csv",
    "source_v52s/weight_store/manifest.json",
    "source_v52s/weight_store/sha256_manifest.csv",
    "V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md",
    "v52u_local_llm_weight_tier_mmap_reader_manifest.json",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52u_local_llm_weight_tier_mmap_reader_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
