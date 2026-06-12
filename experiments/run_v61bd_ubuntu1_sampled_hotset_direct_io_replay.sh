#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bd_ubuntu1_sampled_hotset_direct_io_replay"
RUN_ID="${V61BD_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bd_ubuntu1_sampled_hotset_direct_io_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bc_ubuntu1_sampled_hotset_materialization.sh" >/dev/null
V61X_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61x_hotset_runtime_replay_manifest.sh" >/dev/null

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
model_id = "mistralai/Mixtral-8x22B-v0.1"
alignment = 4096
decode_tokens = 4
v61bc_dir = results / "v61bc_ubuntu1_sampled_hotset_materialization" / "materialization_001"
v61x_dir = results / "v61x_hotset_runtime_replay_manifest" / "hotset_001"


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


v61bc_summary_path = results / "v61bc_ubuntu1_sampled_hotset_materialization_summary.csv"
v61x_summary_path = results / "v61x_hotset_runtime_replay_manifest_summary.csv"
v61bc_summary = read_csv(v61bc_summary_path)[0]
v61x_summary = read_csv(v61x_summary_path)[0]
if v61bc_summary.get("v61bc_ubuntu1_sampled_hotset_materialization_ready") != "1":
    raise SystemExit("v61bd requires v61bc_ubuntu1_sampled_hotset_materialization_ready=1")
if v61bc_summary.get("ubuntu1_sampled_hotset_materialization_ready") != "1":
    raise SystemExit("v61bd requires ubuntu1_sampled_hotset_materialization_ready=1")
if v61bc_summary.get("ubuntu1_hotset_readback_verify_ready") != "1":
    raise SystemExit("v61bd requires ubuntu1_hotset_readback_verify_ready=1")
if v61x_summary.get("v61x_hotset_runtime_replay_manifest_ready") != "1":
    raise SystemExit("v61bd requires v61x_hotset_runtime_replay_manifest_ready=1")

for src, rel in [
    (v61bc_summary_path, "source_v61bc/v61bc_ubuntu1_sampled_hotset_materialization_summary.csv"),
    (results / "v61bc_ubuntu1_sampled_hotset_materialization_decision.csv", "source_v61bc/v61bc_ubuntu1_sampled_hotset_materialization_decision.csv"),
    (v61bc_dir / "ubuntu1_sampled_hotset_materialization_rows.csv", "source_v61bc/ubuntu1_sampled_hotset_materialization_rows.csv"),
    (v61bc_dir / "ubuntu1_sampled_hotset_readback_rows.csv", "source_v61bc/ubuntu1_sampled_hotset_readback_rows.csv"),
    (v61bc_dir / "ubuntu1_sampled_hotset_metric_rows.csv", "source_v61bc/ubuntu1_sampled_hotset_metric_rows.csv"),
    (v61bc_dir / "sha256_manifest.csv", "source_v61bc/sha256_manifest.csv"),
    (v61x_summary_path, "source_v61x/v61x_hotset_runtime_replay_manifest_summary.csv"),
    (v61x_dir / "hotset_runtime_slot_rows.csv", "source_v61x/hotset_runtime_slot_rows.csv"),
    (v61x_dir / "hotset_source_bound_workload_binding_rows.csv", "source_v61x/hotset_source_bound_workload_binding_rows.csv"),
    (v61x_dir / "sha256_manifest.csv", "source_v61x/sha256_manifest.csv"),
]:
    copy(src, rel)

materialization_rows = read_csv(v61bc_dir / "ubuntu1_sampled_hotset_materialization_rows.csv")
slot_rows = {row["slot_id"]: row for row in read_csv(v61x_dir / "hotset_runtime_slot_rows.csv")}
slot_by_source = {
    row["hotset_materialization_id"]: row["slot_id"]
    for row in read_csv(v61bc_dir / "source_v61y" / "hotset_local_materialization_rows.csv")
}
workload_rows = read_csv(v61x_dir / "hotset_source_bound_workload_binding_rows.csv")
if len(materialization_rows) != 16:
    raise SystemExit("v61bd expects 16 v61bc sampled hotset pages")

libc = ctypes.CDLL(None)
O_DIRECT = getattr(os, "O_DIRECT", 0)
if not O_DIRECT:
    raise SystemExit("v61bd requires os.O_DIRECT support")

direct_rows = []
prefetch_rows = []
latencies_ms = []
bytes_total = 0
hash_match_rows = 0
direct_io_error_rows = 0
moe_rows = 0
embedding_rows = 0

ordered_rows = sorted(
    materialization_rows,
    key=lambda row: (
        0 if row["node_type"] == "moe_expert_page_node" else 1,
        int(row["source_hotset_materialization_id"].rsplit("_", 1)[-1]),
    ),
)
for order, row in enumerate(ordered_rows, start=1):
    path = Path(row["ubuntu1_page_path"])
    expected_bytes = int(row["expected_page_bytes"])
    expected_sha = row["remote_page_sha256"]
    slot_id = slot_by_source[row["source_hotset_materialization_id"]]
    slot = slot_rows[slot_id]
    if row["node_type"] == "moe_expert_page_node":
        moe_rows += 1
    if row["node_type"] == "embedding_page_node":
        embedding_rows += 1
    ptr = ctypes.c_void_p()
    rc = libc.posix_memalign(ctypes.byref(ptr), alignment, expected_bytes)
    if rc != 0:
        raise SystemExit(f"v61bd posix_memalign failed rc={rc}")
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
            "direct_read_id": f"v61bd_ubuntu1_direct_read_{order:04d}",
            "hotset_page_id": row["hotset_page_id"],
            "slot_id": slot_id,
            "runtime_node_id": slot["runtime_node_id"],
            "model_id": model_id,
            "node_type": row["node_type"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "ubuntu1_page_path": str(path),
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
            "checkpoint_payload_bytes_downloaded_by_v61bd": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "full_checkpoint_materialization_ready": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
    prefetch_rows.append(
        {
            "prefetch_order": str(order),
            "slot_id": slot_id,
            "hotset_page_id": row["hotset_page_id"],
            "runtime_node_id": slot["runtime_node_id"],
            "node_type": row["node_type"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "prefetch_candidate": slot["prefetch_candidate"],
            "prefetch_reason": "ubuntu1-moe-first-sampled-hotset-direct-read" if row["node_type"] == "moe_expert_page_node" else "ubuntu1-embedding-after-moe-sampled-hotset-direct-read",
            "direct_read_hash_match": str(match),
            "route_jump_rows": "0",
        }
    )

p50 = statistics.median(latencies_ms) if latencies_ms else 0.0
p95 = percentile(latencies_ms, 0.95)
total_latency_ms = sum(latencies_ms)
throughput_mib_s = (bytes_total / (1024 * 1024)) / (total_latency_ms / 1000.0) if total_latency_ms > 0 else 0.0
ssd_read_bytes_per_token = bytes_total // decode_tokens
ubuntu1_direct_io_replay_ready = int(hash_match_rows == len(materialization_rows) and direct_io_error_rows == 0)

metric = {
    "metric_id": "v61bd_ubuntu1_sampled_hotset_direct_io_replay_metrics",
    "model_id": model_id,
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready": "1",
    "v61bc_ubuntu1_sampled_hotset_materialization_ready": v61bc_summary["v61bc_ubuntu1_sampled_hotset_materialization_ready"],
    "v61x_hotset_runtime_replay_manifest_ready": v61x_summary["v61x_hotset_runtime_replay_manifest_ready"],
    "selected_target_path": v61bc_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bc_summary["ubuntu1_hotset_root"],
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
    "ubuntu1_direct_io_replay_ready": str(ubuntu1_direct_io_replay_ready),
    "checkpoint_payload_bytes_downloaded_by_v61bd": "0",
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
write_csv(run_dir / "ubuntu1_hotset_direct_io_read_rows.csv", list(direct_rows[0].keys()), direct_rows)
write_csv(run_dir / "ubuntu1_hotset_direct_io_prefetch_order_rows.csv", list(prefetch_rows[0].keys()), prefetch_rows)
write_csv(
    run_dir / "ubuntu1_hotset_direct_io_latency_rows.csv",
    ["metric", "value"],
    [
        {"metric": "direct_io_read_latency_ms_p50", "value": f"{p50:.6f}"},
        {"metric": "direct_io_read_latency_ms_p95", "value": f"{p95:.6f}"},
        {"metric": "direct_io_read_throughput_mib_s", "value": f"{throughput_mib_s:.6f}"},
        {"metric": "ssd_read_bytes_per_token", "value": str(ssd_read_bytes_per_token)},
    ],
)
write_csv(run_dir / "ubuntu1_hotset_direct_io_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, [key for key in metric if key != "metric_id"], [{key: value for key, value in metric.items() if key != "metric_id"}])

runtime_gap_rows = [
    ("v61bc-ubuntu1-sampled-hotset-input", "ready", "16 ubuntu-1 sampled hotset pages are hash/readback verified"),
    ("ubuntu1-direct-io-hotset-read", "ready" if ubuntu1_direct_io_replay_ready else "blocked", f"{hash_match_rows}/{len(materialization_rows)} O_DIRECT reads matched remote hashes"),
    ("moe-first-prefetch-order", "ready", f"{moe_rows} MoE pages scheduled before {embedding_rows} embedding page"),
    ("explicit-download-execution", "blocked", "v61bd performs no checkpoint download"),
    ("full-checkpoint-materialization", "blocked", "only bounded sampled hotset pages are materialized and read"),
    ("full-safetensors-page-hash-binding", "blocked", "full checkpoint page-hash coverage remains incomplete"),
    ("actual-model-generation", "blocked", "direct-read replay does not execute Mixtral generation"),
    ("production-latency", "blocked", "sampled direct reads are not full production runtime latency"),
    ("release-package", "blocked", "release requires full materialization, generation, and review"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bc-ubuntu1-sampled-hotset-input", "status": "pass", "reason": "ubuntu-1 sampled hotset pages are materialized and hash verified"},
    {"gate": "ubuntu1-direct-io-hotset-read", "status": "pass" if ubuntu1_direct_io_replay_ready else "blocked", "reason": f"{hash_match_rows}/{len(materialization_rows)} O_DIRECT reads matched remote hashes"},
    {"gate": "moe-first-prefetch-order", "status": "pass", "reason": "MoE hotset pages are scheduled before embedding page in the replay plan"},
    {"gate": "no-network-download-by-v61bd", "status": "pass", "reason": "checkpoint_payload_bytes_downloaded_by_v61bd=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain zero"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "full checkpoint payload download remains disabled"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61bd_ubuntu1_sampled_hotset_direct_io_replay",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready": 1,
    "selected_target_path": v61bc_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bc_summary["ubuntu1_hotset_root"],
    "hotset_page_rows": len(materialization_rows),
    "direct_io_read_rows": len(direct_rows),
    "direct_io_hash_match_rows": hash_match_rows,
    "direct_io_error_rows": direct_io_error_rows,
    "direct_io_bytes_read_total": bytes_total,
    "direct_io_read_latency_ms_p50": p50,
    "direct_io_read_latency_ms_p95": p95,
    "direct_io_read_throughput_mib_s": throughput_mib_s,
    "ssd_read_bytes_per_token": ssd_read_bytes_per_token,
    "ubuntu1_direct_io_replay_ready": ubuntu1_direct_io_replay_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bd": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
}
(run_dir / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

boundary = f"""# v61bd ubuntu-1 Sampled Hotset Direct I/O Replay Boundary

This artifact replays direct reads over the bounded sampled hotset pages that
v61bc materialized under the ubuntu-1 target. It verifies every O_DIRECT read
against the remote checkpoint page hash.

Evidence emitted:

- selected_target_path={v61bc_summary["selected_target_path"]}
- ubuntu1_hotset_root={v61bc_summary["ubuntu1_hotset_root"]}
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
- ubuntu1_direct_io_replay_ready={ubuntu1_direct_io_replay_ready}
- checkpoint_payload_bytes_downloaded_by_v61bd=0
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
(run_dir / "V61BD_UBUNTU1_SAMPLED_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bd_ubuntu1_sampled_hotset_direct_io_replay_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
