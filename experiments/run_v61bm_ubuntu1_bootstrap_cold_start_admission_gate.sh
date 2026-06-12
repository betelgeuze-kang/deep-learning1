#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bm_ubuntu1_bootstrap_cold_start_admission_gate"
RUN_ID="${V61BM_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bl_ubuntu1_async_prefetch_execution_probe.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "${V61BM_BOOTSTRAP_COLD_START_BUDGET_MS:-100.0}" <<'PY'
import csv
import hashlib
import json
import math
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
configured_budget_ms = float(sys.argv[5])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def fmt(value):
    if math.isfinite(value):
        return f"{value:.6f}"
    return str(value)


def available_bytes(path):
    stat = os.statvfs(path)
    return stat.f_bavail * stat.f_frsize


v61bl_dir = results / "v61bl_ubuntu1_async_prefetch_execution_probe" / "probe_001"
v61bk_dir = results / "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate" / "gate_001"
v61bl_summary = read_csv(results / "v61bl_ubuntu1_async_prefetch_execution_probe_summary.csv")[0]
v61bk_summary = read_csv(results / "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_summary.csv")[0]
if v61bl_summary.get("v61bl_ubuntu1_async_prefetch_execution_probe_ready") != "1":
    raise SystemExit("v61bm requires v61bl_ubuntu1_async_prefetch_execution_probe_ready=1")
if v61bl_summary.get("actual_async_prefetch_execution_ready") != "1":
    raise SystemExit("v61bm requires v61bl actual_async_prefetch_execution_ready=1")
if v61bk_summary.get("v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready") != "1":
    raise SystemExit("v61bm requires v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready=1")

for src, rel in [
    (results / "v61bl_ubuntu1_async_prefetch_execution_probe_summary.csv", "source_v61bl/v61bl_ubuntu1_async_prefetch_execution_probe_summary.csv"),
    (results / "v61bl_ubuntu1_async_prefetch_execution_probe_decision.csv", "source_v61bl/v61bl_ubuntu1_async_prefetch_execution_probe_decision.csv"),
    (v61bl_dir / "ubuntu1_async_prefetch_execution_rows.csv", "source_v61bl/ubuntu1_async_prefetch_execution_rows.csv"),
    (v61bl_dir / "ubuntu1_async_prefetch_batch_rows.csv", "source_v61bl/ubuntu1_async_prefetch_batch_rows.csv"),
    (v61bl_dir / "runtime_gap_rows.csv", "source_v61bl/runtime_gap_rows.csv"),
    (v61bl_dir / "sha256_manifest.csv", "source_v61bl/sha256_manifest.csv"),
    (results / "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_summary.csv", "source_v61bk/v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_summary.csv"),
    (v61bk_dir / "ubuntu1_prefetch_scheduler_issue_rows.csv", "source_v61bk/ubuntu1_prefetch_scheduler_issue_rows.csv"),
    (v61bk_dir / "ubuntu1_prefetch_scheduler_token_rows.csv", "source_v61bk/ubuntu1_prefetch_scheduler_token_rows.csv"),
    (v61bk_dir / "sha256_manifest.csv", "source_v61bk/sha256_manifest.csv"),
]:
    copy(src, rel)

execution_rows = read_csv(v61bl_dir / "ubuntu1_async_prefetch_execution_rows.csv")
batch_rows = read_csv(v61bl_dir / "ubuntu1_async_prefetch_batch_rows.csv")
if len(execution_rows) != 15:
    raise SystemExit("v61bm expects 15 v61bl execution rows")
if len(batch_rows) != 4:
    raise SystemExit("v61bm expects 4 v61bl batch rows")

bootstrap_rows = [
    row for row in execution_rows
    if row["source_ubuntu1_prefetch_issue_status"] == "bootstrap-blocked-no-prior-window"
]
steady_rows = [
    row for row in execution_rows
    if row["source_ubuntu1_prefetch_issue_status"] == "scheduled-before-deadline"
]
bootstrap_batch = next((row for row in batch_rows if row["ubuntu1_async_prefetch_batch_id"].endswith("_0000")), None)
if bootstrap_batch is None:
    raise SystemExit("v61bm requires v61bl bootstrap batch 0000")

bootstrap_hash_rows = sum(1 for row in bootstrap_rows if row["ubuntu1_async_prefetch_hash_match"] == "1")
bootstrap_error_rows = sum(1 for row in bootstrap_rows if row["ubuntu1_async_prefetch_error"])
bootstrap_bytes = sum(int(row["bytes_read"]) for row in bootstrap_rows if row["ubuntu1_async_prefetch_hash_match"] == "1")
bootstrap_latency_sum = sum(float(row["read_latency_ms"]) for row in bootstrap_rows)
bootstrap_latency_max = max([float(row["read_latency_ms"]) for row in bootstrap_rows], default=0.0)
bootstrap_batch_elapsed_ms = float(bootstrap_batch["batch_elapsed_ms"])
bootstrap_admission_ready = int(
    len(bootstrap_rows) == 4
    and bootstrap_hash_rows == 4
    and bootstrap_error_rows == 0
    and bootstrap_batch_elapsed_ms <= configured_budget_ms
)
steady_hash_rows = sum(1 for row in steady_rows if row["ubuntu1_async_prefetch_hash_match"] == "1")
target_available_bytes = available_bytes(v61bl_summary["selected_target_path"])

page_rows = []
for index, row in enumerate(bootstrap_rows):
    page_rows.append(
        {
            "ubuntu1_bootstrap_cold_start_page_id": f"v61bm_ubuntu1_bootstrap_page_{index:04d}",
            "ubuntu1_prefetch_issue_id": row["ubuntu1_prefetch_issue_id"],
            "ubuntu1_scheduler_token_id": row["ubuntu1_scheduler_token_id"],
            "runtime_node_id": row["runtime_node_id"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "ubuntu1_page_path": row["ubuntu1_page_path"],
            "bytes_read": row["bytes_read"],
            "read_latency_ms": row["read_latency_ms"],
            "local_page_sha256": row["local_page_sha256"],
            "remote_page_sha256": row["remote_page_sha256"],
            "ubuntu1_async_prefetch_hash_match": row["ubuntu1_async_prefetch_hash_match"],
            "bootstrap_cold_start_admission_status": "admitted-before-token-0" if bootstrap_admission_ready else "blocked",
            "bootstrap_cold_start_admission_ready": str(bootstrap_admission_ready),
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )

batch_admission_rows = [
    {
        "ubuntu1_bootstrap_cold_start_batch_id": "v61bm_ubuntu1_bootstrap_cold_start_batch_0000",
        "source_v61bl_batch_id": bootstrap_batch["ubuntu1_async_prefetch_batch_id"],
        "configured_prefetch_queue_depth": v61bl_summary["configured_prefetch_queue_depth"],
        "submitted_bootstrap_page_rows": str(len(bootstrap_rows)),
        "bootstrap_cold_start_hash_match_rows": str(bootstrap_hash_rows),
        "bootstrap_cold_start_error_rows": str(bootstrap_error_rows),
        "bootstrap_cold_start_bytes_read_total": str(bootstrap_bytes),
        "bootstrap_cold_start_read_latency_ms_sum": fmt(bootstrap_latency_sum),
        "bootstrap_cold_start_read_latency_ms_max": fmt(bootstrap_latency_max),
        "bootstrap_cold_start_batch_elapsed_ms": fmt(bootstrap_batch_elapsed_ms),
        "configured_bootstrap_cold_start_budget_ms": fmt(configured_budget_ms),
        "bootstrap_cold_start_budget_headroom_ms": fmt(configured_budget_ms - bootstrap_batch_elapsed_ms),
        "bootstrap_cold_start_admission_ready": str(bootstrap_admission_ready),
        "bootstrap_prefetch_admission_ready": "0",
        "actual_io_uring_execution_ready": "0",
        "registered_buffers_ready": "0",
    }
]

write_csv(run_dir / "ubuntu1_bootstrap_cold_start_page_rows.csv", list(page_rows[0].keys()), page_rows)
write_csv(run_dir / "ubuntu1_bootstrap_cold_start_batch_rows.csv", list(batch_admission_rows[0].keys()), batch_admission_rows)

requirement_rows = [
    {"requirement_id": "v61bl-ubuntu1-async-prefetch-input", "status": "pass", "actual": v61bl_summary["actual_async_prefetch_execution_ready"], "required": "1", "reason": "v61bl actual threaded O_DIRECT execution rows are bound"},
    {"requirement_id": "bootstrap-direct-read-evidence", "status": "pass" if bootstrap_hash_rows == 4 else "blocked", "actual": f"{bootstrap_hash_rows}/4", "required": "4/4", "reason": "token-0 bootstrap pages must hash-match before cold-start admission"},
    {"requirement_id": "bootstrap-cold-start-budget", "status": "pass" if bootstrap_admission_ready else "blocked", "actual": fmt(bootstrap_batch_elapsed_ms), "required": f"<={fmt(configured_budget_ms)}", "reason": "blocking bootstrap cold-fill batch must fit configured startup budget"},
    {"requirement_id": "bootstrap-prefetch-overlap", "status": "blocked", "actual": "0", "required": "1", "reason": "token 0 still has no prior compute window; v61bm admits blocking cold-fill, not prefetch overlap"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "checkpoint payload bytes remain outside the repository"},
    {"requirement_id": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "blocked", "actual": "0", "required": "1", "reason": "sampled bootstrap cold-start admission is not full runtime admission"},
]
write_csv(run_dir / "ubuntu1_bootstrap_cold_start_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bm_ubuntu1_bootstrap_cold_start_admission_metrics",
    "model_id": model_id,
    "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_ready": "1",
    "v61bl_ubuntu1_async_prefetch_execution_probe_ready": v61bl_summary["v61bl_ubuntu1_async_prefetch_execution_probe_ready"],
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready": v61bk_summary["v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready"],
    "selected_target_path": v61bl_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bl_summary["ubuntu1_hotset_root"],
    "ubuntu1_target_available_bytes": str(target_available_bytes),
    "configured_prefetch_queue_depth": v61bl_summary["configured_prefetch_queue_depth"],
    "configured_bootstrap_cold_start_budget_ms": fmt(configured_budget_ms),
    "bootstrap_prefetch_issue_rows": str(len(bootstrap_rows)),
    "bootstrap_cold_start_admitted_rows": str(len(bootstrap_rows) if bootstrap_admission_ready else 0),
    "bootstrap_async_prefetch_hash_match_rows": str(bootstrap_hash_rows),
    "bootstrap_async_prefetch_error_rows": str(bootstrap_error_rows),
    "bootstrap_cold_start_bytes_read_total": str(bootstrap_bytes),
    "bootstrap_cold_start_read_latency_ms_sum": fmt(bootstrap_latency_sum),
    "bootstrap_cold_start_read_latency_ms_max": fmt(bootstrap_latency_max),
    "bootstrap_cold_start_batch_elapsed_ms": fmt(bootstrap_batch_elapsed_ms),
    "bootstrap_cold_start_budget_headroom_ms": fmt(configured_budget_ms - bootstrap_batch_elapsed_ms),
    "ubuntu1_steady_state_prefetch_issue_rows": str(len(steady_rows)),
    "ubuntu1_steady_state_async_prefetch_hash_match_rows": str(steady_hash_rows),
    "actual_async_prefetch_execution_ready": v61bl_summary["actual_async_prefetch_execution_ready"],
    "bootstrap_cold_start_admission_ready": str(bootstrap_admission_ready),
    "bootstrap_prefetch_admission_ready": "0",
    "ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready": "1" if bootstrap_admission_ready and steady_hash_rows == 11 else "0",
    "ubuntu1_prefetch_scheduler_admission_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffers_ready": "0",
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_bootstrap_cold_start_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61bl-ubuntu1-async-prefetch-input", "ready", "v61bl actual O_DIRECT execution rows are bound"),
    ("bootstrap-direct-read-evidence", "ready" if bootstrap_hash_rows == 4 else "blocked", f"bootstrap hash rows={bootstrap_hash_rows}/4"),
    ("bootstrap-cold-start-admission", "ready" if bootstrap_admission_ready else "blocked", f"batch_elapsed_ms={fmt(bootstrap_batch_elapsed_ms)} budget_ms={fmt(configured_budget_ms)}"),
    ("bootstrap-prefetch-overlap", "blocked", "token 0 has no prior compute window; admitted path is blocking cold-fill"),
    ("ubuntu1-bootstrap-plus-steady-state-sampled-admission", "ready" if bootstrap_admission_ready and steady_hash_rows == 11 else "blocked", "sampled bootstrap cold-fill plus steady-state prefetch reads are hash verified"),
    ("io-uring-execution", "blocked", "v61bm consumes threaded O_DIRECT evidence, not io_uring"),
    ("registered-buffer-prefetch", "blocked", "registered buffers remain unavailable"),
    ("full-runtime-ubuntu1-hotset-reuse-admission", "blocked", "sampled admission is not full runtime admission"),
    ("full-checkpoint-materialization", "blocked", "full checkpoint shards are not materialized"),
    ("full-safetensors-page-hash-binding", "blocked", "full 134k+ page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "startup cold-fill admission is not production latency"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bl-ubuntu1-async-prefetch-input", "status": "pass", "reason": "v61bl actual O_DIRECT execution rows are ready"},
    {"gate": "bootstrap-direct-read-evidence", "status": "pass" if bootstrap_hash_rows == 4 else "blocked", "reason": f"bootstrap_hash_rows={bootstrap_hash_rows}/4"},
    {"gate": "bootstrap-cold-start-admission", "status": "pass" if bootstrap_admission_ready else "blocked", "reason": f"batch_elapsed_ms={fmt(bootstrap_batch_elapsed_ms)} budget_ms={fmt(configured_budget_ms)}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain outside the repository"},
    {"gate": "bootstrap-prefetch-overlap", "status": "blocked", "reason": "token 0 has no prior compute window"},
    {"gate": "io-uring-execution", "status": "blocked", "reason": "threaded O_DIRECT evidence is not io_uring"},
    {"gate": "registered-buffer-prefetch", "status": "blocked", "reason": "registered buffers remain unavailable"},
    {"gate": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "blocked", "reason": "sampled admission is not full runtime admission"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "full checkpoint shards are not materialized"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bm Ubuntu-1 Bootstrap Cold-Start Admission Gate Boundary

This gate consumes v61bl actual threaded O_DIRECT execution evidence and
separates token-0 bootstrap from steady-state prefetch. Token 0 still cannot
be prefetched against a prior compute window, but its four cold-fill pages can
be admitted as a blocking cold-start batch before generation begins.

Verified sampled bootstrap cold-start evidence:

- bootstrap_prefetch_issue_rows={len(bootstrap_rows)}
- bootstrap_async_prefetch_hash_match_rows={bootstrap_hash_rows}
- bootstrap_async_prefetch_error_rows={bootstrap_error_rows}
- bootstrap_cold_start_bytes_read_total={bootstrap_bytes}
- bootstrap_cold_start_batch_elapsed_ms={fmt(bootstrap_batch_elapsed_ms)}
- configured_bootstrap_cold_start_budget_ms={fmt(configured_budget_ms)}
- bootstrap_cold_start_admission_ready={bootstrap_admission_ready}
- bootstrap_prefetch_admission_ready=0
- ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready={metric["ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready"]}
- actual_async_prefetch_execution_ready={v61bl_summary["actual_async_prefetch_execution_ready"]}
- actual_io_uring_execution_ready=0
- registered_buffers_ready=0
- full_runtime_ubuntu1_hotset_reuse_admission_ready=0
- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bm=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: sampled ubuntu-1 bootstrap cold-start admission as a blocking
pre-token-0 cold-fill batch, paired with v61bl steady-state threaded O_DIRECT
prefetch evidence.

Blocked wording: bootstrap prefetch overlap, io_uring execution,
registered-buffer prefetch, full runtime admission, full checkpoint
materialization, full safetensors page-hash coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BM_UBUNTU1_BOOTSTRAP_COLD_START_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bm_ubuntu1_bootstrap_cold_start_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_ready": 1,
    "source_v61bl_ready": int(v61bl_summary["v61bl_ubuntu1_async_prefetch_execution_probe_ready"]),
    "source_v61bk_ready": int(v61bk_summary["v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready"]),
    "selected_target_path": v61bl_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bl_summary["ubuntu1_hotset_root"],
    "configured_bootstrap_cold_start_budget_ms": configured_budget_ms,
    "bootstrap_prefetch_issue_rows": len(bootstrap_rows),
    "bootstrap_cold_start_admitted_rows": len(bootstrap_rows) if bootstrap_admission_ready else 0,
    "bootstrap_async_prefetch_hash_match_rows": bootstrap_hash_rows,
    "bootstrap_async_prefetch_error_rows": bootstrap_error_rows,
    "bootstrap_cold_start_bytes_read_total": bootstrap_bytes,
    "bootstrap_cold_start_batch_elapsed_ms": bootstrap_batch_elapsed_ms,
    "bootstrap_cold_start_admission_ready": bootstrap_admission_ready,
    "bootstrap_prefetch_admission_ready": 0,
    "ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready": int(metric["ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready"]),
    "actual_io_uring_execution_ready": 0,
    "registered_buffers_ready": 0,
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": 0,
    "full_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bm": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
