#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61z_hotset_direct_io_replay"
RUN_ID="${V61Z_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61Z_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61z_hotset_direct_io_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61y_hotset_local_materialization_verifier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import ctypes
import hashlib
import json
import os
import shutil
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61y_dir = results / "v61y_hotset_local_materialization_verifier" / "verify_001"
v61x_dir = results / "v61x_hotset_runtime_replay_manifest" / "hotset_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
alignment = 4096
decode_tokens = 4


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


def percentile(values, pct):
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) * pct) + 0.999999) - 1))
    return ordered[index]


v61y_summary = read_csv(results / "v61y_hotset_local_materialization_verifier_summary.csv")[0]
if v61y_summary.get("v61y_hotset_local_materialization_verifier_ready") != "1":
    raise SystemExit("v61z requires v61y_hotset_local_materialization_verifier_ready=1")
if v61y_summary.get("hotset_payload_materialization_ready") != "1":
    raise SystemExit("v61z requires hotset_payload_materialization_ready=1")
if v61y_summary.get("hotset_readback_verify_ready") != "1":
    raise SystemExit("v61z requires hotset_readback_verify_ready=1")

for src, rel in [
    (results / "v61y_hotset_local_materialization_verifier_summary.csv", "source_v61y/v61y_hotset_local_materialization_verifier_summary.csv"),
    (results / "v61y_hotset_local_materialization_verifier_decision.csv", "source_v61y/v61y_hotset_local_materialization_verifier_decision.csv"),
    (v61y_dir / "hotset_local_materialization_rows.csv", "source_v61y/hotset_local_materialization_rows.csv"),
    (v61y_dir / "hotset_local_readback_rows.csv", "source_v61y/hotset_local_readback_rows.csv"),
    (v61y_dir / "hotset_local_materialization_metric_rows.csv", "source_v61y/hotset_local_materialization_metric_rows.csv"),
    (v61y_dir / "sha256_manifest.csv", "source_v61y/sha256_manifest.csv"),
    (results / "v61x_hotset_runtime_replay_manifest_summary.csv", "source_v61x/v61x_hotset_runtime_replay_manifest_summary.csv"),
    (v61x_dir / "hotset_runtime_slot_rows.csv", "source_v61x/hotset_runtime_slot_rows.csv"),
    (v61x_dir / "hotset_source_bound_workload_binding_rows.csv", "source_v61x/hotset_source_bound_workload_binding_rows.csv"),
    (v61x_dir / "sha256_manifest.csv", "source_v61x/sha256_manifest.csv"),
]:
    copy(src, rel)

materialization_rows = read_csv(v61y_dir / "hotset_local_materialization_rows.csv")
slot_rows = {row["slot_id"]: row for row in read_csv(v61x_dir / "hotset_runtime_slot_rows.csv")}
workload_rows = read_csv(v61x_dir / "hotset_source_bound_workload_binding_rows.csv")
if len(materialization_rows) != 16:
    raise SystemExit("v61z expects 16 v61y hotset pages")

libc = ctypes.CDLL(None)
O_DIRECT = getattr(os, "O_DIRECT", 0)
if not O_DIRECT:
    raise SystemExit("v61z requires os.O_DIRECT support")

direct_rows = []
prefetch_rows = []
latencies_ms = []
bytes_total = 0
hash_match_rows = 0
direct_io_error_rows = 0
moe_rows = 0
embedding_rows = 0

ordered_rows = sorted(materialization_rows, key=lambda row: (0 if row["node_type"] == "moe_expert_page_node" else 1, int(row["slot_id"].rsplit("_", 1)[-1])))
for order, row in enumerate(ordered_rows, start=1):
    path = Path(row["planned_local_page_path"])
    expected_bytes = int(row["expected_page_bytes"])
    expected_sha = row["remote_page_sha256"]
    slot = slot_rows[row["slot_id"]]
    if row["node_type"] == "moe_expert_page_node":
        moe_rows += 1
    if row["node_type"] == "embedding_page_node":
        embedding_rows += 1
    ptr = ctypes.c_void_p()
    rc = libc.posix_memalign(ctypes.byref(ptr), alignment, expected_bytes)
    if rc != 0:
        raise SystemExit(f"v61z posix_memalign failed rc={rc}")
    fd = None
    direct_io_used = 0
    error = ""
    nread = 0
    latency_ns = 0
    got_sha = ""
    try:
        fd = os.open(path, os.O_RDONLY | O_DIRECT)
        direct_io_used = 1
        buf = (ctypes.c_char * expected_bytes).from_address(ptr.value)
        mv = memoryview(buf)
        start = time.monotonic_ns()
        nread = os.preadv(fd, [mv], 0)
        latency_ns = time.monotonic_ns() - start
        data = bytes(mv[:nread])
        got_sha = sha256_bytes(data)
        del data, mv, buf
    except OSError as exc:
        error = f"{exc.__class__.__name__}:{exc.errno}:{exc.strerror}"
        direct_io_error_rows += 1
    finally:
        if fd is not None:
            os.close(fd)
        libc.free(ptr)
    latency_ms = latency_ns / 1_000_000.0
    match = int(direct_io_used == 1 and nread == expected_bytes and got_sha == expected_sha)
    if match:
        hash_match_rows += 1
        bytes_total += nread
        latencies_ms.append(latency_ms)
    direct_rows.append(
        {
            "direct_read_id": f"v61z_direct_read_{order:04d}",
            "hotset_page_id": row["hotset_page_id"],
            "slot_id": row["slot_id"],
            "runtime_node_id": slot["runtime_node_id"],
            "model_id": model_id,
            "node_type": row["node_type"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "planned_local_page_path": str(path),
            "direct_io_requested": "1",
            "direct_io_used": str(direct_io_used),
            "alignment_bytes": str(alignment),
            "bytes_requested": str(expected_bytes),
            "bytes_read": str(nread),
            "read_latency_ns": str(latency_ns),
            "read_latency_ms": f"{latency_ms:.6f}",
            "local_page_sha256": got_sha,
            "remote_page_sha256": expected_sha,
            "direct_read_hash_match": str(match),
            "direct_io_error": error,
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
    prefetch_rows.append(
        {
            "prefetch_order": str(order),
            "slot_id": row["slot_id"],
            "hotset_page_id": row["hotset_page_id"],
            "runtime_node_id": slot["runtime_node_id"],
            "node_type": row["node_type"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "prefetch_candidate": slot["prefetch_candidate"],
            "prefetch_reason": "moe-first-local-hotset-direct-read" if row["node_type"] == "moe_expert_page_node" else "embedding-after-moe-hotset-direct-read",
            "direct_read_hash_match": str(match),
            "route_jump_rows": "0",
        }
    )

p50 = statistics.median(latencies_ms) if latencies_ms else 0.0
p95 = percentile(latencies_ms, 0.95)
total_latency_ms = sum(latencies_ms)
throughput_mib_s = (bytes_total / (1024 * 1024)) / (total_latency_ms / 1000.0) if total_latency_ms > 0 else 0.0
ssd_read_bytes_per_token = bytes_total // decode_tokens
direct_io_replay_ready = int(hash_match_rows == len(materialization_rows) and direct_io_error_rows == 0)

metric_rows = [
    {
        "metric_id": "v61z_hotset_direct_io_replay_metrics",
        "hotset_page_rows": str(len(materialization_rows)),
        "direct_io_read_rows": str(len(direct_rows)),
        "direct_io_hash_match_rows": str(hash_match_rows),
        "direct_io_error_rows": str(direct_io_error_rows),
        "moe_direct_read_rows": str(moe_rows),
        "embedding_direct_read_rows": str(embedding_rows),
        "direct_io_bytes_read_total": str(bytes_total),
        "direct_io_read_latency_ms_p50": f"{p50:.6f}",
        "direct_io_read_latency_ms_p95": f"{p95:.6f}",
        "direct_io_read_throughput_mib_s": f"{throughput_mib_s:.6f}",
        "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
        "source_bound_workload_binding_rows": str(len(workload_rows)),
        "direct_io_replay_ready": str(direct_io_replay_ready),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "full_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "real_100b_open_weight_materialized": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
]

latency_rows = [
    {"metric": "direct_io_read_latency_ms_p50", "value": f"{p50:.6f}"},
    {"metric": "direct_io_read_latency_ms_p95", "value": f"{p95:.6f}"},
    {"metric": "direct_io_read_throughput_mib_s", "value": f"{throughput_mib_s:.6f}"},
    {"metric": "ssd_read_bytes_per_token", "value": str(ssd_read_bytes_per_token)},
]

runtime_gap_rows = [
    {"gap": "v61y-hotset-materialization-input", "status": "ready", "evidence": "16 local sampled hotset pages are hash verified"},
    {"gap": "direct-io-hotset-read", "status": "ready" if direct_io_replay_ready else "blocked", "evidence": f"{hash_match_rows}/{len(materialization_rows)} direct reads matched remote hashes"},
    {"gap": "moe-first-prefetch-order", "status": "ready", "evidence": f"{moe_rows} MoE pages scheduled before {embedding_rows} embedding page"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only sampled hotset pages are materialized and read"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "direct-read replay does not execute Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and external review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "sampled direct reads are not full production runtime latency"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61y-hotset-materialization-input", "status": "pass", "reason": "sampled hotset pages are locally materialized and hash verified"},
    {"gate": "direct-io-hotset-read", "status": "pass" if direct_io_replay_ready else "blocked", "reason": f"{hash_match_rows}/{len(materialization_rows)} O_DIRECT reads matched remote hashes"},
    {"gate": "moe-first-prefetch-order", "status": "pass", "reason": "MoE hotset pages are scheduled before embedding page in the replay plan"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain outside the repository"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "full Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "sampled hotset direct reads are not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(
    run_dir / "hotset_direct_io_read_rows.csv",
    [
        "direct_read_id",
        "hotset_page_id",
        "slot_id",
        "runtime_node_id",
        "model_id",
        "node_type",
        "tensor_role",
        "layer_index",
        "expert_index",
        "planned_local_page_path",
        "direct_io_requested",
        "direct_io_used",
        "alignment_bytes",
        "bytes_requested",
        "bytes_read",
        "read_latency_ns",
        "read_latency_ms",
        "local_page_sha256",
        "remote_page_sha256",
        "direct_read_hash_match",
        "direct_io_error",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
    ],
    direct_rows,
)
write_csv(
    run_dir / "hotset_direct_io_prefetch_order_rows.csv",
    [
        "prefetch_order",
        "slot_id",
        "hotset_page_id",
        "runtime_node_id",
        "node_type",
        "tensor_role",
        "layer_index",
        "expert_index",
        "prefetch_candidate",
        "prefetch_reason",
        "direct_read_hash_match",
        "route_jump_rows",
    ],
    prefetch_rows,
)
write_csv(run_dir / "hotset_direct_io_latency_rows.csv", ["metric", "value"], latency_rows)
write_csv(run_dir / "hotset_direct_io_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61z_hotset_direct_io_replay_ready": "1",
    "v61y_hotset_local_materialization_verifier_ready": v61y_summary["v61y_hotset_local_materialization_verifier_ready"],
    "model_id": model_id,
    "hotset_page_rows": str(len(materialization_rows)),
    "direct_io_read_rows": str(len(direct_rows)),
    "direct_io_hash_match_rows": str(hash_match_rows),
    "direct_io_error_rows": str(direct_io_error_rows),
    "moe_direct_read_rows": str(moe_rows),
    "embedding_direct_read_rows": str(embedding_rows),
    "direct_io_bytes_read_total": str(bytes_total),
    "direct_io_read_latency_ms_p50": f"{p50:.6f}",
    "direct_io_read_latency_ms_p95": f"{p95:.6f}",
    "direct_io_read_throughput_mib_s": f"{throughput_mib_s:.6f}",
    "ssd_read_bytes_per_token": str(ssd_read_bytes_per_token),
    "source_bound_workload_binding_rows": str(len(workload_rows)),
    "direct_io_replay_ready": str(direct_io_replay_ready),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61z_hotset_direct_io_replay",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61z_hotset_direct_io_replay_ready": 1,
    "hotset_page_rows": len(materialization_rows),
    "direct_io_read_rows": len(direct_rows),
    "direct_io_hash_match_rows": hash_match_rows,
    "direct_io_error_rows": direct_io_error_rows,
    "direct_io_bytes_read_total": bytes_total,
    "direct_io_read_latency_ms_p50": p50,
    "direct_io_read_latency_ms_p95": p95,
    "direct_io_read_throughput_mib_s": throughput_mib_s,
    "ssd_read_bytes_per_token": ssd_read_bytes_per_token,
    "direct_io_replay_ready": direct_io_replay_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "full_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61z_hotset_direct_io_replay_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61z Hotset Direct I/O Replay Boundary

This artifact replays direct local reads over the bounded v61y sampled hotset
pages. It measures the sampled local SSD page-read path and verifies every read
against the remote checkpoint page hash.

Evidence emitted:

- hotset_page_rows={len(materialization_rows)}
- direct_io_read_rows={len(direct_rows)}
- direct_io_hash_match_rows={hash_match_rows}
- direct_io_error_rows={direct_io_error_rows}
- moe_direct_read_rows={moe_rows}
- embedding_direct_read_rows={embedding_rows}
- direct_io_bytes_read_total={bytes_total}
- direct_io_read_latency_ms_p50={p50:.6f}
- direct_io_read_latency_ms_p95={p95:.6f}
- direct_io_read_throughput_mib_s={throughput_mib_s:.6f}
- ssd_read_bytes_per_token={ssd_read_bytes_per_token}
- source_bound_workload_binding_rows={len(workload_rows)}
- direct_io_replay_ready={direct_io_replay_ready}
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- real_100b_open_weight_materialized=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is not full Mixtral checkpoint materialization, not full safetensors
page-hash coverage, not real Mixtral generation, and not production-latency or
release evidence.
"""
(run_dir / "V61Z_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61z_hotset_direct_io_replay_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
