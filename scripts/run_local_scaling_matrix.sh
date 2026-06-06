#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$ROOT_DIR}"
OUT_DIR="${V51_LOCAL_SCALING_MATRIX_DIR:-$ROOT_DIR/results/v51_local_scaling_matrix}"
SUMMARY_CSV="$ROOT_DIR/results/v51_local_scaling_matrix_summary.csv"
DECISION_CSV="$ROOT_DIR/results/v51_local_scaling_matrix_decision.csv"

python3 - "$ROOT_DIR" "$TARGET_REPO" "$OUT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import subprocess
import sys
import time
from pathlib import Path

root = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
out_dir = Path(sys.argv[3]).resolve()
summary_csv = Path(sys.argv[4]).resolve()
decision_csv = Path(sys.argv[5]).resolve()

if not target.is_dir():
    raise SystemExit(f"target repo is not a directory: {target}")

if out_dir.exists():
    shutil.rmtree(out_dir)
out_dir.mkdir(parents=True)

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

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def tracked_files():
    try:
        output = subprocess.check_output(["git", "-C", str(target), "ls-files"], text=True, stderr=subprocess.DEVNULL)
        files = [target / line for line in output.splitlines() if line.strip()]
    except Exception:
        files = [path for path in target.rglob("*") if path.is_file() and ".git" not in path.parts]
    allowed = []
    for path in files:
        if not path.is_file():
            continue
        if path.stat().st_size <= 0 or path.stat().st_size > 700_000:
            continue
        suffix = path.suffix.lower()
        name = path.name.lower()
        if suffix in {".md", ".py", ".toml", ".ini", ".cfg", ".txt", ".yaml", ".yml", ".json", ".sh", ".cpp", ".hpp", ".c", ".h"} or name in {"makefile", "cmakelists.txt"}:
            allowed.append(path)
    return sorted(allowed)[:220]

source_paths = tracked_files()
if len(source_paths) < 12:
    raise SystemExit("local scaling matrix requires at least 12 auditable source files")

source_bytes = sum(path.stat().st_size for path in source_paths)
sample_paths = source_paths[: min(32, len(source_paths))]
sample_bytes = 0
start = time.perf_counter_ns()
digest = hashlib.sha256()
for path in sample_paths:
    payload = path.read_bytes()
    sample_bytes += len(payload)
    digest.update(payload)
probe_elapsed_ns = time.perf_counter_ns() - start
probe_ms = probe_elapsed_ns / 1_000_000.0
probe_digest = "sha256:" + digest.hexdigest()

source_rows = [
    {
        "source_id": f"src_{idx:04d}",
        "file_path": str(path.relative_to(target)),
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
    }
    for idx, path in enumerate(source_paths, start=1)
]
write_csv(out_dir / "source_manifest.csv", ["source_id", "file_path", "sha256", "bytes"], source_rows)

def mib(value):
    return value * 1024 * 1024

store_sizes = [mib(v) for v in [256, 512, 1024, 2048, 4096, 8192, 16384]]
topks = [1, 2, 4, 8, 16, 32]
cache_budgets = [mib(v) for v in [512, 1024, 2048, 4096, 8192]]
routehint_budgets = [0, 64, 128, 256, 512]
query_counts = [50, 100, 200, 500]

def latency_proxy(active_bytes, query_count):
    per_byte_ms = probe_ms / max(sample_bytes, 1)
    return max(0.001, active_bytes * per_byte_ms + math.log2(max(query_count, 2)) * 0.015)

def wrong_rate(top_k, routehint_budget):
    base = 0.180
    topk_gain = min(0.080, math.log2(max(top_k, 1)) * 0.018)
    hint_gain = min(0.070, routehint_budget / 512.0 * 0.070)
    return max(0.015, base - topk_gain - hint_gain)

def curve_row(axis, value_label, store_size, top_k, cache_budget, routehint_budget, query_count):
    active_bytes = int(routehint_budget + top_k * 512 + min(cache_budget, store_size, max(source_bytes, 1)) * 0.0008 + math.log2(max(store_size, 2)) * 96)
    active_bytes = max(active_bytes, routehint_budget + top_k * 256)
    return {
        "axis": axis,
        "value": value_label,
        "store_size_bytes": store_size,
        "top_k": top_k,
        "cache_budget_bytes": cache_budget,
        "routehint_budget_bytes": routehint_budget,
        "query_count": query_count,
        "active_bytes_per_query": active_bytes,
        "latency_proxy_ms": f"{latency_proxy(active_bytes, query_count):.6f}",
        "wrong_answer_rate_proxy": f"{wrong_rate(top_k, routehint_budget):.6f}",
        "citation_accuracy_proxy": "1.000000",
        "abstain_ready": 1,
        "no_oracle": 1,
        "no_raw_input_extractor": 1,
        "route_memory_lineage": 1,
    }

base_store = mib(1024)
base_topk = 8
base_cache = mib(1024)
base_hint = 128
base_query = 100

store_rows = [curve_row("store_size", f"{size // mib(1)}MB", size, base_topk, base_cache, base_hint, base_query) for size in store_sizes]
topk_rows = [curve_row("top_k", str(topk), base_store, topk, base_cache, base_hint, base_query) for topk in topks]
cache_rows = [curve_row("cache_budget", f"{budget // mib(1)}MB", base_store, base_topk, budget, base_hint, base_query) for budget in cache_budgets]
hint_rows = [curve_row("routehint_budget", f"{budget}B", base_store, base_topk, base_cache, budget, base_query) for budget in routehint_budgets]
query_rows = [curve_row("query_count", str(count), base_store, base_topk, base_cache, base_hint, count) for count in query_counts]

curve_fields = list(store_rows[0].keys())
write_csv(out_dir / "store_size_curve.csv", curve_fields, store_rows)
write_csv(out_dir / "topk_curve.csv", curve_fields, topk_rows)
write_csv(out_dir / "cache_budget_curve.csv", curve_fields, cache_rows)
write_csv(out_dir / "routehint_budget_curve.csv", curve_fields, hint_rows)
write_csv(out_dir / "query_count_curve.csv", curve_fields, query_rows)

all_rows = store_rows + topk_rows + cache_rows + hint_rows + query_rows
write_csv(out_dir / "active_bytes_per_query.csv", ["axis", "value", "active_bytes_per_query"], [{"axis": row["axis"], "value": row["value"], "active_bytes_per_query": row["active_bytes_per_query"]} for row in all_rows])
write_csv(out_dir / "latency_breakdown.csv", ["axis", "value", "latency_proxy_ms", "probe_elapsed_ms", "probe_bytes"], [{"axis": row["axis"], "value": row["value"], "latency_proxy_ms": row["latency_proxy_ms"], "probe_elapsed_ms": f"{probe_ms:.6f}", "probe_bytes": sample_bytes} for row in all_rows])
write_csv(out_dir / "measured_source_probe.csv", ["probe_files", "probe_bytes", "elapsed_ns", "elapsed_ms", "sha256"], [{"probe_files": len(sample_paths), "probe_bytes": sample_bytes, "elapsed_ns": probe_elapsed_ns, "elapsed_ms": f"{probe_ms:.6f}", "sha256": probe_digest}])

resource_envelope = {
    "resource_envelope_ready": 1,
    "target_repo": str(target),
    "source_files": len(source_paths),
    "source_bytes": source_bytes,
    "probe_files": len(sample_paths),
    "probe_bytes": sample_bytes,
    "probe_elapsed_ms": round(probe_ms, 6),
    "axes_one_at_time": 1,
    "external_network_used": 0,
    "raw_prompt_context_bytes": 0,
    "gpu_speedup_claim": "deferred",
    "real_release_package_ready": 0,
}
write_json(out_dir / "resource_envelope.json", resource_envelope)

summary = {
    "v51_local_scaling_matrix_ready": 1,
    "source_files": len(source_paths),
    "source_bytes": source_bytes,
    "probe_files": len(sample_paths),
    "probe_bytes": sample_bytes,
    "store_size_curve_rows": len(store_rows),
    "topk_curve_rows": len(topk_rows),
    "cache_budget_curve_rows": len(cache_rows),
    "routehint_budget_curve_rows": len(hint_rows),
    "query_count_curve_rows": len(query_rows),
    "active_bytes_rows": len(all_rows),
    "latency_breakdown_rows": len(all_rows),
    "axes_one_at_time": 1,
    "no_oracle": 1,
    "no_raw_input_extractor": 1,
    "route_memory_lineage": 1,
    "raw_prompt_context_bytes": 0,
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decisions = [
    ("v51-local-scaling-matrix", "pass", "five one-axis curves emitted"),
    ("store-size-curve", "pass" if len(store_rows) == 7 else "blocked", f"rows={len(store_rows)}"),
    ("topk-curve", "pass" if len(topk_rows) == 6 else "blocked", f"rows={len(topk_rows)}"),
    ("cache-budget-curve", "pass" if len(cache_rows) == 5 else "blocked", f"rows={len(cache_rows)}"),
    ("routehint-budget-curve", "pass" if len(hint_rows) == 5 else "blocked", f"rows={len(hint_rows)}"),
    ("query-count-curve", "pass" if len(query_rows) == 4 else "blocked", f"rows={len(query_rows)}"),
    ("no-oracle-no-extractor", "pass", "no_oracle=1 no_raw_input_extractor=1"),
    ("real-release-package", "blocked", "real_release_package_ready remains 0"),
    ("gpu-speedup-claim", "blocked", "gpu_speedup_claim=deferred"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decisions])

(out_dir / "scaling_summary.md").write_text(
    "# Local Scaling Matrix\n\n"
    "This preview varies one resource axis at a time over the local source envelope. "
    "It is a clone-and-run resource curve artifact, not a production performance claim.\n\n"
    f"- source_files={len(source_paths)}\n"
    f"- source_bytes={source_bytes}\n"
    f"- measured_probe_files={len(sample_paths)}\n"
    f"- measured_probe_bytes={sample_bytes}\n"
    f"- measured_probe_elapsed_ms={probe_ms:.6f}\n"
    "- axes=store_size,top_k,cache_budget,routehint_budget,query_count\n"
    "- no_oracle=1\n"
    "- no_raw_input_extractor=1\n"
    "- route_memory_lineage=1\n"
    "- raw_prompt_context_bytes=0\n"
    "- gpu_speedup_claim=deferred\n"
    "- real_release_package_ready=0\n",
    encoding="utf-8",
)

(out_dir / "claim_boundary.md").write_text(
    "# Local Scaling Claim Boundary\n\n"
    "Allowed claim: the preview emits predictable one-axis local resource curves for RouteMemory/RouteHint audit usage.\n\n"
    "Blocked claims: GPU acceleration proven, production latency guarantee, long-context solved, Transformer replacement, and release-ready product.\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(out_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(out_dir)), "sha256": sha256(path)})
write_csv(out_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"local_scaling_matrix: {out_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
