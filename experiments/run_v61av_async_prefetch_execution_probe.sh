#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61av_async_prefetch_execution_probe"
RUN_ID="${V61AV_RUN_ID:-probe_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61av_async_prefetch_execution_probe_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61au_prefetch_queue_depth_scheduler_gate.sh" >/dev/null
V61Z_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61z_hotset_direct_io_replay.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import concurrent.futures
import csv
import ctypes
import hashlib
import json
import math
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


def fmt(value):
    if math.isfinite(value):
        return f"{value:.6f}"
    return str(value)


v61au_dir = results / "v61au_prefetch_queue_depth_scheduler_gate" / "gate_001"
v61z_dir = results / "v61z_hotset_direct_io_replay" / "replay_001"
v61au_summary = read_csv(results / "v61au_prefetch_queue_depth_scheduler_gate_summary.csv")[0]
v61z_summary = read_csv(results / "v61z_hotset_direct_io_replay_summary.csv")[0]
if v61au_summary.get("v61au_prefetch_queue_depth_scheduler_gate_ready") != "1":
    raise SystemExit("v61av requires v61au_prefetch_queue_depth_scheduler_gate_ready=1")
if v61au_summary.get("steady_state_scheduler_ready") != "1":
    raise SystemExit("v61av requires steady_state_scheduler_ready=1")
if v61z_summary.get("v61z_hotset_direct_io_replay_ready") != "1":
    raise SystemExit("v61av requires v61z_hotset_direct_io_replay_ready=1")

for src, rel in [
    (results / "v61au_prefetch_queue_depth_scheduler_gate_summary.csv", "source_v61au/v61au_prefetch_queue_depth_scheduler_gate_summary.csv"),
    (results / "v61au_prefetch_queue_depth_scheduler_gate_decision.csv", "source_v61au/v61au_prefetch_queue_depth_scheduler_gate_decision.csv"),
    (v61au_dir / "prefetch_scheduler_issue_rows.csv", "source_v61au/prefetch_scheduler_issue_rows.csv"),
    (v61au_dir / "prefetch_scheduler_token_rows.csv", "source_v61au/prefetch_scheduler_token_rows.csv"),
    (v61au_dir / "prefetch_queue_depth_rows.csv", "source_v61au/prefetch_queue_depth_rows.csv"),
    (v61au_dir / "runtime_gap_rows.csv", "source_v61au/runtime_gap_rows.csv"),
    (v61au_dir / "sha256_manifest.csv", "source_v61au/sha256_manifest.csv"),
    (results / "v61z_hotset_direct_io_replay_summary.csv", "source_v61z/v61z_hotset_direct_io_replay_summary.csv"),
    (v61z_dir / "hotset_direct_io_read_rows.csv", "source_v61z/hotset_direct_io_read_rows.csv"),
    (v61z_dir / "hotset_direct_io_metric_rows.csv", "source_v61z/hotset_direct_io_metric_rows.csv"),
    (v61z_dir / "sha256_manifest.csv", "source_v61z/sha256_manifest.csv"),
]:
    copy(src, rel)

issue_rows = read_csv(v61au_dir / "prefetch_scheduler_issue_rows.csv")
direct_rows = read_csv(v61z_dir / "hotset_direct_io_read_rows.csv")
if len(issue_rows) != 15:
    raise SystemExit("v61av expects 15 v61au issue rows")
if len(direct_rows) != 16:
    raise SystemExit("v61av expects 16 v61z direct read rows")

direct_by_node = {row["runtime_node_id"]: row for row in direct_rows}
queue_depth = int(v61au_summary["configured_prefetch_queue_depth"])
O_DIRECT = getattr(os, "O_DIRECT", 0)
if not O_DIRECT:
    raise SystemExit("v61av requires os.O_DIRECT support")
libc = ctypes.CDLL(None)


def read_direct_issue(task):
    issue = task["issue"]
    source = task["source"]
    expected_bytes = int(issue["page_bytes"])
    expected_sha = source["remote_page_sha256"]
    path = Path(source["planned_local_page_path"])
    ptr = ctypes.c_void_p()
    rc = libc.posix_memalign(ctypes.byref(ptr), alignment, expected_bytes)
    if rc != 0:
        raise RuntimeError(f"posix_memalign failed rc={rc}")
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
    finally:
        if fd is not None:
            os.close(fd)
        libc.free(ptr)
    return {
        "prefetch_issue_id": issue["prefetch_issue_id"],
        "scheduler_token_id": issue["scheduler_token_id"],
        "runtime_node_id": issue["runtime_node_id"],
        "tensor_role": issue["tensor_role"],
        "layer_index": issue["layer_index"],
        "expert_index": issue["expert_index"],
        "target_token_index": issue["target_token_index"],
        "issue_token_index": issue["issue_token_index"],
        "source_scheduler_status": issue["prefetch_issue_status"],
        "source_deadline_slack_ms": issue["deadline_slack_ms"],
        "planned_local_page_path": str(path),
        "direct_io_requested": "1",
        "direct_io_used": str(direct_io_used),
        "alignment_bytes": str(alignment),
        "bytes_requested": str(expected_bytes),
        "bytes_read": str(nread),
        "read_latency_ns": str(latency_ns),
        "read_latency_ms": fmt(latency_ns / 1_000_000.0),
        "local_page_sha256": got_sha,
        "remote_page_sha256": expected_sha,
        "async_prefetch_hash_match": str(int(direct_io_used == 1 and nread == expected_bytes and got_sha == expected_sha)),
        "async_prefetch_error": error,
        "actual_async_prefetch_execution_ready": "1" if direct_io_used == 1 and nread == expected_bytes and got_sha == expected_sha else "0",
        "actual_io_uring_execution_ready": "0",
        "registered_buffers_ready": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
        "production_latency_claim_ready": "0",
        "route_jump_rows": "0",
    }


tasks = []
for issue in issue_rows:
    source = direct_by_node.get(issue["runtime_node_id"])
    if not source:
        raise SystemExit(f"missing v61z direct row for runtime node {issue['runtime_node_id']}")
    tasks.append({"issue": issue, "source": source})

execution_rows = []
batch_rows = []
wall_start = time.monotonic_ns()
for batch_index, start_index in enumerate(range(0, len(tasks), queue_depth)):
    batch_tasks = tasks[start_index : start_index + queue_depth]
    batch_start = time.monotonic_ns()
    with concurrent.futures.ThreadPoolExecutor(max_workers=queue_depth) as executor:
        futures = [executor.submit(read_direct_issue, task) for task in batch_tasks]
        for future in concurrent.futures.as_completed(futures):
            execution_rows.append(future.result())
    batch_end = time.monotonic_ns()
    batch_rows.append(
        {
            "prefetch_batch_id": f"v61av_prefetch_batch_{batch_index:04d}",
            "configured_prefetch_queue_depth": str(queue_depth),
            "submitted_issue_rows": str(len(batch_tasks)),
            "batch_start_wall_ns": str(batch_start - wall_start),
            "batch_end_wall_ns": str(batch_end - wall_start),
            "batch_elapsed_ms": fmt((batch_end - batch_start) / 1_000_000.0),
            "batch_actual_async_execution_ready": "1",
            "actual_io_uring_execution_ready": "0",
            "registered_buffers_ready": "0",
        }
    )

execution_rows.sort(key=lambda row: row["prefetch_issue_id"])

latencies = [float(row["read_latency_ms"]) for row in execution_rows if row["async_prefetch_hash_match"] == "1"]
hash_match_rows = sum(1 for row in execution_rows if row["async_prefetch_hash_match"] == "1")
error_rows = sum(1 for row in execution_rows if row["async_prefetch_error"])
executed_rows = sum(1 for row in execution_rows if row["direct_io_used"] == "1")
steady_rows = [row for row in execution_rows if row["source_scheduler_status"] == "scheduled-before-deadline"]
bootstrap_rows = [row for row in execution_rows if row["source_scheduler_status"] == "bootstrap-blocked-no-prior-window"]
steady_hash_rows = sum(1 for row in steady_rows if row["async_prefetch_hash_match"] == "1")
bootstrap_hash_rows = sum(1 for row in bootstrap_rows if row["async_prefetch_hash_match"] == "1")
bytes_total = sum(int(row["bytes_read"]) for row in execution_rows if row["async_prefetch_hash_match"] == "1")
actual_async_ready = int(hash_match_rows == len(execution_rows) and error_rows == 0)

write_csv(run_dir / "async_prefetch_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)
write_csv(run_dir / "async_prefetch_batch_rows.csv", list(batch_rows[0].keys()), batch_rows)

requirement_rows = [
    {"requirement_id": "v61au-scheduler-input", "status": "pass", "actual": v61au_summary["steady_state_scheduler_ready"], "required": "1", "reason": "v61au steady-state scheduler rows are bound"},
    {"requirement_id": "v61z-local-page-input", "status": "pass", "actual": v61z_summary["direct_io_hash_match_rows"], "required": "16", "reason": "v61z local direct-I/O page rows are bound"},
    {"requirement_id": "actual-threaded-async-prefetch-execution", "status": "pass" if actual_async_ready else "blocked", "actual": f"{hash_match_rows}/{len(execution_rows)}", "required": "15/15", "reason": "all queued sampled prefetch reads execute and hash-match"},
    {"requirement_id": "steady-state-async-prefetch-execution", "status": "pass" if steady_hash_rows == 11 else "blocked", "actual": f"{steady_hash_rows}/11", "required": "11/11", "reason": "steady-state issue rows execute successfully"},
    {"requirement_id": "bootstrap-prefetch-admission", "status": "blocked", "actual": "0", "required": "1", "reason": "bootstrap reads can execute, but have no previous compute window"},
    {"requirement_id": "io-uring-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "v61av uses threaded O_DIRECT, not io_uring"},
    {"requirement_id": "registered-buffer-prefetch", "status": "blocked", "actual": "0", "required": "1", "reason": "registered buffers are not allocated by v61av"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "checkpoint payload bytes are read from outside-repository hotset only"},
]
write_csv(run_dir / "async_prefetch_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

p50 = statistics.median(latencies) if latencies else 0.0
p95 = percentile(latencies, 0.95)
total_latency_ms = sum(latencies)
wall_elapsed_ms = sum(float(row["batch_elapsed_ms"]) for row in batch_rows)
throughput_mib_s = (bytes_total / (1024 * 1024)) / (wall_elapsed_ms / 1000.0) if wall_elapsed_ms > 0 else 0.0

metric = {
    "metric_id": "v61av_async_prefetch_execution_metrics",
    "model_id": model_id,
    "v61av_async_prefetch_execution_probe_ready": "1",
    "v61au_prefetch_queue_depth_scheduler_gate_ready": v61au_summary["v61au_prefetch_queue_depth_scheduler_gate_ready"],
    "v61z_hotset_direct_io_replay_ready": v61z_summary["v61z_hotset_direct_io_replay_ready"],
    "configured_prefetch_queue_depth": str(queue_depth),
    "prefetch_issue_rows": str(len(execution_rows)),
    "executed_prefetch_issue_rows": str(executed_rows),
    "async_prefetch_hash_match_rows": str(hash_match_rows),
    "async_prefetch_error_rows": str(error_rows),
    "steady_state_prefetch_issue_rows": str(len(steady_rows)),
    "steady_state_async_prefetch_hash_match_rows": str(steady_hash_rows),
    "bootstrap_prefetch_issue_rows": str(len(bootstrap_rows)),
    "bootstrap_async_prefetch_hash_match_rows": str(bootstrap_hash_rows),
    "async_prefetch_batch_rows": str(len(batch_rows)),
    "max_submitted_batch_size": str(max(int(row["submitted_issue_rows"]) for row in batch_rows)),
    "async_prefetch_bytes_read_total": str(bytes_total),
    "async_prefetch_read_latency_ms_p50": fmt(p50),
    "async_prefetch_read_latency_ms_p95": fmt(p95),
    "async_prefetch_batch_elapsed_ms_total": fmt(wall_elapsed_ms),
    "async_prefetch_effective_throughput_mib_s": fmt(throughput_mib_s),
    "actual_async_prefetch_execution_ready": str(actual_async_ready),
    "steady_state_actual_async_prefetch_ready": "1" if steady_hash_rows == 11 else "0",
    "bootstrap_prefetch_admission_ready": "0",
    "prefetch_scheduler_admission_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffers_ready": "0",
    "full_runtime_hotset_reuse_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61av": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "async_prefetch_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61au-scheduler-input", "ready", "v61au scheduler issue rows are bound"),
    ("v61z-local-page-input", "ready", "v61z local O_DIRECT page rows are bound"),
    ("actual-threaded-async-prefetch-execution", "ready" if actual_async_ready else "blocked", f"async_prefetch_hash_match_rows={hash_match_rows}/{len(execution_rows)}"),
    ("steady-state-async-prefetch-execution", "ready" if steady_hash_rows == 11 else "blocked", f"steady_state_async_prefetch_hash_match_rows={steady_hash_rows}/11"),
    ("bootstrap-prefetch-admission", "blocked", "bootstrap reads execute, but still have no previous compute window"),
    ("io-uring-execution", "blocked", "v61av uses threaded O_DIRECT, not io_uring"),
    ("registered-buffer-prefetch", "blocked", "registered buffers are not allocated by v61av"),
    ("full-runtime-admission", "blocked", "sampled async execution is not full runtime admission"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "sampled threaded prefetch is not production latency"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61au-scheduler-input", "status": "pass", "reason": "v61au scheduler issue rows are ready"},
    {"gate": "v61z-local-page-input", "status": "pass", "reason": "v61z direct-I/O page rows are ready"},
    {"gate": "actual-threaded-async-prefetch-execution", "status": "pass" if actual_async_ready else "blocked", "reason": f"async_prefetch_hash_match_rows={hash_match_rows}/{len(execution_rows)}"},
    {"gate": "steady-state-async-prefetch-execution", "status": "pass" if steady_hash_rows == 11 else "blocked", "reason": f"steady_state_async_prefetch_hash_match_rows={steady_hash_rows}/11"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain outside the repository"},
    {"gate": "bootstrap-prefetch-admission", "status": "blocked", "reason": "bootstrap has no previous compute window"},
    {"gate": "io-uring-execution", "status": "blocked", "reason": "threaded O_DIRECT is not io_uring"},
    {"gate": "registered-buffer-prefetch", "status": "blocked", "reason": "registered buffers are not allocated"},
    {"gate": "full-runtime-admission", "status": "blocked", "reason": "sampled async execution is not full runtime admission"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61av Async Prefetch Execution Probe Boundary

This probe consumes v61au queue-depth scheduler rows and v61z local sampled
hotset page paths, then executes the 15 sampled prefetch issue reads through a
queue-depth {queue_depth} threaded O_DIRECT worker pool.

Verified sampled async execution evidence:

- prefetch_issue_rows={len(execution_rows)}
- executed_prefetch_issue_rows={executed_rows}
- async_prefetch_hash_match_rows={hash_match_rows}
- async_prefetch_error_rows={error_rows}
- steady_state_prefetch_issue_rows={len(steady_rows)}
- steady_state_async_prefetch_hash_match_rows={steady_hash_rows}
- bootstrap_prefetch_issue_rows={len(bootstrap_rows)}
- bootstrap_async_prefetch_hash_match_rows={bootstrap_hash_rows}
- async_prefetch_batch_rows={len(batch_rows)}
- max_submitted_batch_size={max(int(row["submitted_issue_rows"]) for row in batch_rows)}
- actual_async_prefetch_execution_ready={actual_async_ready}
- actual_io_uring_execution_ready=0
- registered_buffers_ready=0
- bootstrap_prefetch_admission_ready=0
- prefetch_scheduler_admission_ready=0
- checkpoint_payload_bytes_downloaded_by_v61av=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: sampled threaded O_DIRECT async prefetch execution over the
v61au issue rows.

Blocked wording: io_uring execution, registered-buffer prefetch, bootstrap
prefetch admission, full runtime admission, actual Mixtral generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61AV_ASYNC_PREFETCH_EXECUTION_PROBE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61av_async_prefetch_execution_probe",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61av_async_prefetch_execution_probe_ready": 1,
    "source_v61au_ready": int(v61au_summary["v61au_prefetch_queue_depth_scheduler_gate_ready"]),
    "source_v61z_ready": int(v61z_summary["v61z_hotset_direct_io_replay_ready"]),
    "configured_prefetch_queue_depth": queue_depth,
    "prefetch_issue_rows": len(execution_rows),
    "executed_prefetch_issue_rows": executed_rows,
    "async_prefetch_hash_match_rows": hash_match_rows,
    "async_prefetch_error_rows": error_rows,
    "steady_state_prefetch_issue_rows": len(steady_rows),
    "steady_state_async_prefetch_hash_match_rows": steady_hash_rows,
    "actual_async_prefetch_execution_ready": actual_async_ready,
    "actual_io_uring_execution_ready": 0,
    "registered_buffers_ready": 0,
    "bootstrap_prefetch_admission_ready": 0,
    "prefetch_scheduler_admission_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61av": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61av_async_prefetch_execution_probe_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61av_async_prefetch_execution_probe_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
