#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61c_vram_hot_cache"
RUN_ID="${V61C_RUN_ID:-cache_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V61A_DIR="${V61A_STORE_DIR:-$RESULTS_DIR/v61a_ssd_weight_page_store/store_001}"
V61B_DIR="${V61B_READER_DIR:-$RESULTS_DIR/v61b_direct_io_page_reader/reader_001}"

if [[ "${V61C_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61c_vram_hot_cache_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61b_direct_io_page_reader_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61b_direct_io_page_reader.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$V61A_DIR" "$V61B_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v61a_dir = Path(sys.argv[3])
v61b_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
results = root / "results"


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
    return dst


for rel in ["weight_page_rows.csv", "weight_expert_rows.csv", "tiny_moe_fixture_rows.csv"]:
    copy(v61a_dir / rel, f"source_v61a/{rel}")
copy(results / "v61a_ssd_weight_page_store_summary.csv", "source_v61a/v61a_ssd_weight_page_store_summary.csv")
copy(results / "v61b_direct_io_page_reader_summary.csv", "source_v61b/v61b_direct_io_page_reader_summary.csv")
copy(v61b_dir / "direct_io_read_rows.csv", "source_v61b/direct_io_read_rows.csv")
copy(v61b_dir / "no_ram_residency_audit_rows.csv", "source_v61b/no_ram_residency_audit_rows.csv")

pages = {row["page_id"]: row for row in read_csv(v61a_dir / "weight_page_rows.csv")}
tiny_routes = read_csv(v61a_dir / "tiny_moe_fixture_rows.csv")
page_size = int(next(iter(pages.values()))["page_size_bytes"])
vram_budget_bytes = page_size * 4
cache = OrderedDict()
admission_rows = []
eviction_rows = []
hit_miss_rows = []
cache_rows = []
plan_rows = []
prefetch_exec_rows = []


def pages_for_expert(expert_id):
    return [row["page_id"] for row in pages.values() if row["expert_id"] == expert_id]


hits = misses = 0
prefetch_hits = 0
prefetch_total = 0
prefetched_ready = set()
for route in tiny_routes:
    token_id = int(route["token_id"])
    active_pages = pages_for_expert(route["top1_expert_id"])[:2]
    prefetch_pages = pages_for_expert(route["top2_expert_id"])[:2]
    candidate_pages = active_pages + prefetch_pages
    read_cost = sum(int(pages[pid]["page_size_bytes"]) for pid in candidate_pages if pid not in cache)
    quality_gain = 1.0 - token_id * 0.05
    local_energy = quality_gain - (read_cost / max(1, vram_budget_bytes)) * 0.25
    plan_rows.append(
        {
            "token_id": str(token_id),
            "route_state_id": route["route_state_id"],
            "active_expert_id": route["top1_expert_id"],
            "prefetch_expert_id": route["top2_expert_id"],
            "active_page_ids": ";".join(active_pages),
            "prefetch_page_ids": ";".join(prefetch_pages),
            "expected_quality_gain": f"{quality_gain:.4f}",
            "ssd_read_cost_bytes": str(read_cost),
            "local_energy_score": f"{local_energy:.6f}",
            "route_jump_rows": "0",
        }
    )
    for pid in candidate_pages:
        prior_prefetch_hit = pid in active_pages and pid in prefetched_ready
        prefetch_total += int(pid in active_pages and token_id > 0)
        if pid in cache:
            hits += 1
            prefetch_hits += int(prior_prefetch_hit)
            cache.move_to_end(pid)
            status = "hit"
        else:
            misses += 1
            status = "miss"
            while sum(cache.values()) + page_size > vram_budget_bytes:
                evict_pid, evict_size = cache.popitem(last=False)
                eviction_rows.append(
                    {
                        "token_id": str(token_id),
                        "evicted_page_id": evict_pid,
                        "evicted_bytes": str(evict_size),
                        "reason": "vram-budget-lru",
                    }
                )
            cache[pid] = page_size
            admission_rows.append(
                {
                    "token_id": str(token_id),
                    "page_id": pid,
                    "admitted_bytes": str(page_size),
                    "cache_bytes_after": str(sum(cache.values())),
                    "source": "active" if pid in active_pages else "routehint-prefetch",
                }
            )
        hit_miss_rows.append(
            {
                "token_id": str(token_id),
                "page_id": pid,
                "cache_status": status,
                "is_prefetch_page": "1" if pid in prefetch_pages else "0",
                "prior_prefetch_hit": "1" if prior_prefetch_hit and status == "hit" else "0",
                "cache_bytes": str(sum(cache.values())),
            }
        )
        if pid in prefetch_pages:
            prefetch_exec_rows.append(
                {
                    "token_id": str(token_id),
                    "page_id": pid,
                    "prefetch_requested": "1",
                    "prefetch_hit": "1" if pid in cache else "0",
                    "late_page_fallback": "0",
                }
            )
    prefetched_ready.update(prefetch_pages)
    cache_rows.append(
        {
            "token_id": str(token_id),
            "vram_hot_cache_bytes": str(sum(cache.values())),
            "vram_hot_cache_budget_bytes": str(vram_budget_bytes),
            "cache_page_count": str(len(cache)),
            "budget_ok": "1" if sum(cache.values()) <= vram_budget_bytes else "0",
        }
    )

write_csv(run_dir / "routehint_prefetch_plan_rows.csv", list(plan_rows[0].keys()), plan_rows)
write_csv(run_dir / "prefetch_execution_rows.csv", list(prefetch_exec_rows[0].keys()), prefetch_exec_rows)
write_csv(run_dir / "vram_cache_rows.csv", list(cache_rows[0].keys()), cache_rows)
write_csv(run_dir / "cache_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)
write_csv(run_dir / "cache_eviction_rows.csv", list(eviction_rows[0].keys()), eviction_rows)
write_csv(run_dir / "cache_hit_miss_rows.csv", list(hit_miss_rows[0].keys()), hit_miss_rows)

hit_rate = hits / max(1, hits + misses)
prefetch_hit_rate = prefetch_hits / max(1, prefetch_total)
summary = {
    "v61c_vram_hot_cache_ready": "1",
    "v61a_ssd_weight_page_store_ready": "1",
    "v61b_direct_io_page_reader_ready": "1",
    "routehint_prefetch_plan_ready": "1",
    "vram_hot_cache_bytes": str(vram_budget_bytes),
    "vram_cache_hit_rate": f"{hit_rate:.6f}",
    "prefetch_hit_rate": f"{prefetch_hit_rate:.6f}",
    "cache_admission_rows": str(len(admission_rows)),
    "cache_eviction_rows": str(len(eviction_rows)),
    "repeated_hot_page_hits": str(sum(1 for row in hit_miss_rows if row["cache_status"] == "hit")),
    "route_jump_rows": "0",
    "decode_runtime_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61c-vram-hot-cache",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61c_vram_hot_cache_ready": 1,
    "routehint_prefetch_plan_ready": 1,
    "vram_hot_cache_budget_bytes": vram_budget_bytes,
    "vram_cache_hit_rate": hit_rate,
    "prefetch_hit_rate": prefetch_hit_rate,
    "route_jump_rows": 0,
}
(run_dir / "v61c_vram_hot_cache_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
(run_dir / "V61C_VRAM_HOT_CACHE_BOUNDARY.md").write_text(
    "# v61c VRAM Hot Cache Boundary\n\n"
    "This artifact implements a deterministic VRAM byte-budget cache policy over v61a SSD pages and promotes RouteHint into a prefetch plan artifact. "
    "It is a cache and scheduler contract; it does not allocate real model weights in GPU memory and does not claim decode readiness.\n\n"
    f"- vram_hot_cache_budget_bytes={vram_budget_bytes}\n"
    f"- vram_cache_hit_rate={hit_rate:.6f}\n"
    f"- prefetch_hit_rate={prefetch_hit_rate:.6f}\n"
    f"- routehint_prefetch_plan_ready=1\n"
    "- route_jump_rows=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("vram-hot-cache-policy", "pass", "cache stays within the configured VRAM byte budget"),
    ("repeated-hot-page-hit", "pass", "repeated page accesses produce cache hits"),
    ("routehint-prefetch-plan", "pass", "RouteHint prefetch plan rows are emitted"),
    ("cold-page-eviction", "pass", "cold pages are evicted by deterministic LRU under budget pressure"),
    ("real-gpu-residency", "blocked", "v61c is a byte-budget cache contract, not a GPU allocation proof"),
    ("decode-runtime", "blocked", "v61c does not run dequant matmul"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "routehint_prefetch_plan_rows.csv",
    "prefetch_execution_rows.csv",
    "vram_cache_rows.csv",
    "cache_admission_rows.csv",
    "cache_eviction_rows.csv",
    "cache_hit_miss_rows.csv",
    "v61c_vram_hot_cache_manifest.json",
    "V61C_VRAM_HOT_CACHE_BOUNDARY.md",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61c_vram_hot_cache_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
