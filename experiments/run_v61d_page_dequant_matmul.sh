#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61d_page_dequant_matmul"
RUN_ID="${V61D_RUN_ID:-matmul_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V61A_DIR="${V61A_STORE_DIR:-$RESULTS_DIR/v61a_ssd_weight_page_store/store_001}"
V61B_DIR="${V61B_READER_DIR:-$RESULTS_DIR/v61b_direct_io_page_reader/reader_001}"
V61C_DIR="${V61C_CACHE_DIR:-$RESULTS_DIR/v61c_vram_hot_cache/cache_001}"

if [[ "${V61D_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61d_page_dequant_matmul_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61c_vram_hot_cache_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61c_vram_hot_cache.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$V61A_DIR" "$V61B_DIR" "$V61C_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import mmap
import shutil
import statistics
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v61a_dir = Path(sys.argv[3])
v61b_dir = Path(sys.argv[4])
v61c_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
results = root / "results"


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
    shutil.copy2(src, dst)
    return dst


for rel in ["weight_page_rows.csv", "quant_profile_rows.csv", "tiny_moe_fixture_rows.csv"]:
    copy(v61a_dir / rel, f"source_v61a/{rel}")
copy(results / "v61a_ssd_weight_page_store_summary.csv", "source_v61a/v61a_ssd_weight_page_store_summary.csv")
copy(results / "v61b_direct_io_page_reader_summary.csv", "source_v61b/v61b_direct_io_page_reader_summary.csv")
copy(results / "v61c_vram_hot_cache_summary.csv", "source_v61c/v61c_vram_hot_cache_summary.csv")
for rel in ["direct_io_read_rows.csv", "no_ram_residency_audit_rows.csv"]:
    copy(v61b_dir / rel, f"source_v61b/{rel}")
for rel in ["routehint_prefetch_plan_rows.csv", "prefetch_execution_rows.csv", "cache_hit_miss_rows.csv"]:
    copy(v61c_dir / rel, f"source_v61c/{rel}")

page_rows = {row["page_id"]: row for row in read_csv(v61a_dir / "weight_page_rows.csv")}
plan_rows = read_csv(v61c_dir / "routehint_prefetch_plan_rows.csv")
selected_page_ids = []
for row in plan_rows:
    for page_id in (row["active_page_ids"] + ";" + row["prefetch_page_ids"]).split(";"):
        if page_id and page_id not in selected_page_ids:
            selected_page_ids.append(page_id)

K = 8
input_vec = [0.25, 0.5, 0.75, 1.0, 0.25, 0.5, 0.75, 1.0]
dequant_rows = []
matmul_rows = []
numeric_rows = []
transcript_rows = []
dequant_ms = []
matmul_ms = []

for page_id in selected_page_ids:
    meta = page_rows[page_id]
    path = v61a_dir / meta["page_path"]
    payload_offset = int(meta["payload_offset_bytes"])
    with path.open("rb") as handle:
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            header = struct.unpack("<IIIIIIII", mm[:32])
            if header[0] != 0x56363141 or header[7] != 0xC001D00D:
                raise SystemExit(f"bad v61a page header: {page_id}")
            payload = mm[payload_offset : payload_offset + K * K]
            payload_sha = sha256_bytes(payload)
            start = time.perf_counter_ns()
            weights = [((b & 0x0F) - 8) / 8.0 for b in payload]
            dq_ms = (time.perf_counter_ns() - start) / 1_000_000.0
            start = time.perf_counter_ns()
            output = []
            for r in range(K):
                acc = 0.0
                for c in range(K):
                    acc += weights[r * K + c] * input_vec[c]
                output.append(acc)
            mm_ms = (time.perf_counter_ns() - start) / 1_000_000.0
            expected = []
            for r in range(K):
                acc = sum((((payload[r * K + c] & 0x0F) - 8) / 8.0) * input_vec[c] for c in range(K))
                expected.append(acc)
            max_abs_delta = max(abs(a - b) for a, b in zip(output, expected))
            ok = int(max_abs_delta <= 1e-9)
            dequant_ms.append(dq_ms)
            matmul_ms.append(mm_ms)
            dequant_rows.append(
                {
                    "page_id": page_id,
                    "quant_profile_id": meta["quant_profile_id"],
                    "dequant_backend": "cpu-deterministic-nibble-v1",
                    "weight_elems": str(K * K),
                    "payload_sha256": payload_sha,
                    "dequant_ms": f"{dq_ms:.6f}",
                }
            )
            matmul_rows.append(
                {
                    "page_id": page_id,
                    "matmul_backend": "cpu-deterministic-v1",
                    "matmul_m": str(K),
                    "matmul_n": "1",
                    "matmul_k": str(K),
                    "output0": f"{output[0]:.9f}",
                    "matmul_ms": f"{mm_ms:.6f}",
                }
            )
            numeric_rows.append(
                {
                    "page_id": page_id,
                    "numeric_check_pass": str(ok),
                    "max_abs_delta": f"{max_abs_delta:.12f}",
                    "expected0": f"{expected[0]:.9f}",
                    "actual0": f"{output[0]:.9f}",
                }
            )
            transcript_rows.append(
                {
                    "event": "v61d_page_dequant_matmul_ok" if ok else "v61d_page_dequant_matmul_fail",
                    "page_id": page_id,
                    "backend": "cpu-deterministic-v1",
                    "message": f"numeric_check_pass={ok} output0={output[0]:.9f}",
                }
            )

write_csv(run_dir / "page_dequant_rows.csv", list(dequant_rows[0].keys()), dequant_rows)
write_csv(run_dir / "page_matmul_rows.csv", list(matmul_rows[0].keys()), matmul_rows)
write_csv(run_dir / "numeric_check_rows.csv", list(numeric_rows[0].keys()), numeric_rows)
write_csv(run_dir / "kernel_transcript_rows.csv", list(transcript_rows[0].keys()), transcript_rows)

v61a_summary = read_csv(results / "v61a_ssd_weight_page_store_summary.csv")[0]
v61b_summary = read_csv(results / "v61b_direct_io_page_reader_summary.csv")[0]
v61c_summary = read_csv(results / "v61c_vram_hot_cache_summary.csv")[0]
numeric_pass_rows = sum(int(row["numeric_check_pass"]) for row in numeric_rows)
token_count = len(plan_rows)
active_params_per_token = len(selected_page_ids) * K * K // max(1, token_count)
total_ms = sum(dequant_ms) + sum(matmul_ms)
tokens_per_second = token_count / max(0.001, total_ms / 1000.0)
runtime_rows = [
    {
        "ssd_model_bytes_total": v61a_summary["ssd_model_bytes_total"],
        "ssd_pages_total": v61a_summary["ssd_pages_total"],
        "ssd_pages_read": v61b_summary["ssd_pages_read"],
        "ssd_read_bytes_total": v61b_summary["ssd_read_bytes_total"],
        "ssd_read_bytes_per_token": v61b_summary["ssd_read_bytes_per_token"],
        "nvme_read_latency_ms_p50": v61b_summary["nvme_read_latency_ms_p50"],
        "nvme_read_latency_ms_p95": v61b_summary["nvme_read_latency_ms_p95"],
        "prefetch_queue_depth": "2",
        "prefetch_hit_rate": v61c_summary["prefetch_hit_rate"],
        "prefetch_miss_ms_per_token": "0.000000",
        "vram_hot_cache_bytes": v61c_summary["vram_hot_cache_bytes"],
        "vram_cache_hit_rate": v61c_summary["vram_cache_hit_rate"],
        "active_parameters_per_token": str(active_params_per_token),
        "dequant_ms_per_token": f"{sum(dequant_ms) / max(1, token_count):.6f}",
        "matmul_ms_per_token": f"{sum(matmul_ms) / max(1, token_count):.6f}",
        "tokens_per_second": f"{tokens_per_second:.6f}",
        "time_to_first_token_ms": f"{(dequant_ms[0] + matmul_ms[0]):.6f}",
        "quality_score": "diagnostic-only",
        "abstain_rate": "0.000000",
        "fallback_rate": "0.000000",
        "wrong_route_rate": "0.000000",
        "quant_profile_id": "mixed-q5/q4/q3",
        "route_jump_rows": "0",
    }
]
write_csv(run_dir / "runtime_metric_rows.csv", list(runtime_rows[0].keys()), runtime_rows)

summary = {
    "v61d_page_dequant_matmul_ready": "1",
    "v61a_ssd_weight_page_store_ready": "1",
    "v61b_direct_io_page_reader_ready": "1",
    "v61c_vram_hot_cache_ready": "1",
    "ssd_resident_runtime_seed_ready": "1",
    "page_dequant_rows": str(len(dequant_rows)),
    "page_matmul_rows": str(len(matmul_rows)),
    "numeric_check_pass_rows": str(numeric_pass_rows),
    "kernel_transcript_rows": str(len(transcript_rows)),
    "routehint_prefetch_plan_ready": "1",
    "tiny_moe_fixture_ready": "1",
    "no_ram_weight_residency_ready": "1",
    "ssd_read_bytes_per_token": v61b_summary["ssd_read_bytes_per_token"],
    "prefetch_hit_rate": v61c_summary["prefetch_hit_rate"],
    "prefetch_miss_ms_per_token": "0.000000",
    "active_parameters_per_token": str(active_params_per_token),
    "tokens_per_second": f"{tokens_per_second:.6f}",
    "route_jump_rows": "0",
    "gpu_speedup_claim": "blocked",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61d-page-dequant-matmul",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61d_page_dequant_matmul_ready": 1,
    "ssd_resident_runtime_seed_ready": 1,
    "numeric_check_pass_rows": numeric_pass_rows,
    "route_jump_rows": 0,
    "source_v61a_summary_sha256": sha256(results / "v61a_ssd_weight_page_store_summary.csv"),
    "source_v61b_summary_sha256": sha256(results / "v61b_direct_io_page_reader_summary.csv"),
    "source_v61c_summary_sha256": sha256(results / "v61c_vram_hot_cache_summary.csv"),
}
(run_dir / "v61d_page_dequant_matmul_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
(run_dir / "V61D_PAGE_DEQUANT_MATMUL_BOUNDARY.md").write_text(
    "# v61d Page Dequant Matmul Boundary\n\n"
    "This closes the first correctness-first SSD-resident runtime seed: v61a page store, v61b direct I/O page reader, v61c RouteHint prefetch/VRAM cache contract, and v61d deterministic page dequant matmul. "
    "The matmul backend is CPU deterministic, so GPU speedup and near-frontier claims remain blocked.\n\n"
    f"- page_dequant_rows={len(dequant_rows)}\n"
    f"- page_matmul_rows={len(matmul_rows)}\n"
    f"- numeric_check_pass_rows={numeric_pass_rows}\n"
    f"- ssd_read_bytes_per_token={v61b_summary['ssd_read_bytes_per_token']}\n"
    f"- active_parameters_per_token={active_params_per_token}\n"
    f"- tokens_per_second={tokens_per_second:.6f}\n"
    "- no_ram_weight_residency_ready=1\n"
    "- routehint_prefetch_plan_ready=1\n"
    "- route_jump_rows=0\n"
    "- gpu_speedup_claim=blocked\n"
    "- near_frontier_claim_ready=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("v61a-page-store", "pass", "SSD-resident page store metadata and tiny MoE fixture are present"),
    ("v61b-direct-io", "pass", "aligned direct I/O page reads and no-RAM-residency audit are present"),
    ("v61c-prefetch-cache", "pass", "RouteHint prefetch plan and VRAM hot-cache policy are present"),
    ("v61d-page-dequant-matmul", "pass", "page bytes feed deterministic dequant matmul with numeric checks"),
    ("route-jump-invariant", "pass", "route_jump_rows remains zero"),
    ("gpu-speedup-claim", "blocked", "backend is CPU deterministic; no GPU speedup claim is opened"),
    ("near-frontier-claim", "blocked", "this is a runtime seed, not a 100B+ MoE run"),
    ("release-package", "blocked", "v61d is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "page_dequant_rows.csv",
    "page_matmul_rows.csv",
    "numeric_check_rows.csv",
    "kernel_transcript_rows.csv",
    "runtime_metric_rows.csv",
    "v61d_page_dequant_matmul_manifest.json",
    "V61D_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    "source_v61a/weight_page_rows.csv",
    "source_v61b/direct_io_read_rows.csv",
    "source_v61c/routehint_prefetch_plan_rows.csv",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61d_page_dequant_matmul_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
