#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate"
RUN_ID="${V61BK_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bj_ubuntu1_prefetch_overlap_admission_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"
configured_queue_depth = 4


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


def token_index_from_schedule(schedule_id):
    match = re.search(r"v61bg_ubuntu1_schedule_(\d+)_", schedule_id)
    if not match:
        raise SystemExit(f"cannot parse token index from schedule id: {schedule_id}")
    return int(match.group(1))


v61bj_dir = results / "v61bj_ubuntu1_prefetch_overlap_admission_gate" / "gate_001"
v61bi_dir = results / "v61bi_ubuntu1_hotset_reuse_admission_gate" / "gate_001"
v61bd_dir = results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay" / "replay_001"

v61bj_summary = read_csv(results / "v61bj_ubuntu1_prefetch_overlap_admission_gate_summary.csv")[0]
v61bi_summary = read_csv(results / "v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv")[0]
if v61bj_summary.get("v61bj_ubuntu1_prefetch_overlap_admission_gate_ready") != "1":
    raise SystemExit("v61bk requires v61bj_ubuntu1_prefetch_overlap_admission_gate_ready=1")
if v61bj_summary.get("ubuntu1_steady_state_prefetch_overlap_ready") != "1":
    raise SystemExit("v61bk requires ubuntu1_steady_state_prefetch_overlap_ready=1")
if v61bi_summary.get("ubuntu1_sampled_hotset_reuse_ready") != "1":
    raise SystemExit("v61bk requires ubuntu1_sampled_hotset_reuse_ready=1")

for src, rel in [
    (results / "v61bj_ubuntu1_prefetch_overlap_admission_gate_summary.csv", "source_v61bj/v61bj_ubuntu1_prefetch_overlap_admission_gate_summary.csv"),
    (results / "v61bj_ubuntu1_prefetch_overlap_admission_gate_decision.csv", "source_v61bj/v61bj_ubuntu1_prefetch_overlap_admission_gate_decision.csv"),
    (v61bj_dir / "ubuntu1_prefetch_overlap_token_rows.csv", "source_v61bj/ubuntu1_prefetch_overlap_token_rows.csv"),
    (v61bj_dir / "ubuntu1_prefetch_overlap_window_rows.csv", "source_v61bj/ubuntu1_prefetch_overlap_window_rows.csv"),
    (v61bj_dir / "runtime_gap_rows.csv", "source_v61bj/runtime_gap_rows.csv"),
    (v61bj_dir / "sha256_manifest.csv", "source_v61bj/sha256_manifest.csv"),
    (results / "v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv", "source_v61bi/v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv"),
    (v61bi_dir / "ubuntu1_hotset_reuse_page_rows.csv", "source_v61bi/ubuntu1_hotset_reuse_page_rows.csv"),
    (v61bi_dir / "ubuntu1_hotset_reuse_token_rows.csv", "source_v61bi/ubuntu1_hotset_reuse_token_rows.csv"),
    (results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv", "source_v61bd/v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_metric_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_metric_rows.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_read_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_read_rows.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61bj_dir / "ubuntu1_prefetch_overlap_token_rows.csv")
page_rows = read_csv(v61bi_dir / "ubuntu1_hotset_reuse_page_rows.csv")
if len(token_rows) != 37:
    raise SystemExit("v61bk expects 37 v61bj token rows")
if len(page_rows) != 15:
    raise SystemExit("v61bk expects 15 v61bi hotset page rows")

tokens_by_index = {int(row["token_index"]): row for row in token_rows}
pages_by_token = {}
for page in page_rows:
    token_index = token_index_from_schedule(page["first_schedule_id"])
    pages_by_token.setdefault(token_index, []).append(page)

read_p95_ms = float(v61bj_summary["ubuntu1_ssd_read_latency_ms_p95_per_page"])
compute_window_ms = float(v61bj_summary["token_page_kernel_compute_window_ms"])
min_slack = float(v61bj_summary["min_steady_state_overlap_slack_ms"])
page_bytes = int(v61bi_summary["page_bytes"])

scheduler_token_rows = []
issue_rows = []
deadline_rows = []
bootstrap_cold_fill_page_rows = 0
steady_issue_rows = 0
steady_deadline_met_rows = 0
steady_deadline_miss_rows = 0
no_prefetch_required_rows = 0
max_steady_required_depth = 0
max_bootstrap_required_depth = 0

for token_index in range(len(token_rows)):
    token = tokens_by_index[token_index]
    miss_pages = int(token["cache_miss_page_rows"])
    hit_pages = int(token["cache_hit_page_rows"])
    token_pages = pages_by_token.get(token_index, [])
    required_depth = miss_pages if miss_pages > 0 else 0
    if token_index == 0:
        max_bootstrap_required_depth = max(max_bootstrap_required_depth, required_depth)
    else:
        max_steady_required_depth = max(max_steady_required_depth, required_depth)
    if miss_pages == 0:
        no_prefetch_required_rows += 1

    available_window_ms = 0.0 if token_index == 0 else compute_window_ms
    deadline_met = int(token_index > 0 and miss_pages > 0 and required_depth <= configured_queue_depth and read_p95_ms <= available_window_ms)
    queue_depth_pass = int(required_depth <= configured_queue_depth)
    scheduler_status = "no-prefetch-required"
    if token_index == 0 and miss_pages > 0:
        scheduler_status = "bootstrap-blocked-no-prior-window"
        bootstrap_cold_fill_page_rows += miss_pages
    elif miss_pages > 0 and deadline_met:
        scheduler_status = "scheduled-before-deadline"
        steady_issue_rows += miss_pages
        steady_deadline_met_rows += miss_pages
    elif miss_pages > 0:
        scheduler_status = "deadline-miss-blocked"
        steady_issue_rows += miss_pages
        steady_deadline_miss_rows += miss_pages

    scheduler_token_rows.append(
        {
            "ubuntu1_scheduler_token_id": f"v61bk_ubuntu1_scheduler_token_{token_index:04d}",
            "ubuntu1_prefetch_token_id": token["ubuntu1_prefetch_token_id"],
            "ubuntu1_reuse_token_id": token["ubuntu1_reuse_token_id"],
            "token_index": str(token_index),
            "cache_miss_page_rows": str(miss_pages),
            "cache_hit_page_rows": str(hit_pages),
            "prefetch_issue_rows": str(miss_pages if token_index > 0 else 0),
            "configured_prefetch_queue_depth": str(configured_queue_depth),
            "required_prefetch_queue_depth": str(required_depth),
            "available_prefetch_window_ms": fmt(available_window_ms),
            "ubuntu1_ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
            "deadline_met": str(deadline_met),
            "queue_depth_pass": str(queue_depth_pass),
            "scheduler_status": scheduler_status,
            "actual_async_prefetch_execution_ready": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )

    for local_slot, page in enumerate(token_pages):
        issue_ready = int(token_index > 0)
        deadline_ms = token_index * compute_window_ms
        issue_start_ms = (token_index - 1) * compute_window_ms if token_index > 0 else 0.0
        issue_complete_ms = issue_start_ms + read_p95_ms if token_index > 0 else read_p95_ms
        slack_ms = deadline_ms - issue_complete_ms if token_index > 0 else -read_p95_ms
        issue_status = "scheduled-before-deadline" if issue_ready and slack_ms >= 0 else "bootstrap-blocked-no-prior-window"
        issue_rows.append(
            {
                "ubuntu1_prefetch_issue_id": f"v61bk_ubuntu1_prefetch_issue_{len(issue_rows):04d}",
                "ubuntu1_scheduler_token_id": f"v61bk_ubuntu1_scheduler_token_{token_index:04d}",
                "ubuntu1_reuse_page_id": page["ubuntu1_reuse_page_id"],
                "runtime_node_id": page["runtime_node_id"],
                "tensor_role": page["tensor_role"],
                "layer_index": page["layer_index"],
                "expert_index": page["expert_index"],
                "first_schedule_id": page["first_schedule_id"],
                "target_token_index": str(token_index),
                "issue_token_index": str(token_index - 1) if token_index > 0 else "",
                "queue_depth_slot": str((local_slot % configured_queue_depth) + 1) if token_index > 0 else "",
                "page_bytes": str(page_bytes),
                "issue_start_ms": fmt(issue_start_ms),
                "issue_complete_p95_ms": fmt(issue_complete_ms),
                "target_deadline_ms": fmt(deadline_ms),
                "deadline_slack_ms": fmt(slack_ms),
                "deadline_met": "1" if issue_ready and slack_ms >= 0 else "0",
                "ubuntu1_prefetch_issue_status": issue_status,
                "actual_async_prefetch_execution_ready": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "actual_model_generation_ready": "0",
                "production_latency_claim_ready": "0",
                "route_jump_rows": "0",
            }
        )

queue_depth_rows = [
    {
        "queue_depth_profile_id": "v61bk_ubuntu1_sampled_steady_state_qd4",
        "configured_prefetch_queue_depth": str(configured_queue_depth),
        "max_steady_state_required_queue_depth": str(max_steady_required_depth),
        "max_bootstrap_required_queue_depth": str(max_bootstrap_required_depth),
        "steady_state_queue_depth_headroom": str(configured_queue_depth - max_steady_required_depth),
        "bootstrap_queue_depth_headroom": str(configured_queue_depth - max_bootstrap_required_depth),
        "steady_state_queue_depth_admission_ready": "1" if max_steady_required_depth <= configured_queue_depth else "0",
        "bootstrap_queue_depth_admission_ready": "1" if max_bootstrap_required_depth <= configured_queue_depth else "0",
        "queue_depth_control_ready": "1",
        "actual_io_uring_execution_ready": "0",
        "registered_buffers_ready": "0",
    }
]

deadline_rows.extend(
    [
        {
            "requirement_id": "v61bj-ubuntu1-prefetch-overlap-input",
            "status": "pass",
            "actual": v61bj_summary["ubuntu1_steady_state_prefetch_overlap_ready"],
            "required": "1",
            "reason": "ubuntu-1 steady-state overlap evidence is bound",
        },
        {
            "requirement_id": "ubuntu1-steady-state-queue-depth",
            "status": "pass" if max_steady_required_depth <= configured_queue_depth else "blocked",
            "actual": str(max_steady_required_depth),
            "required": f"<={configured_queue_depth}",
            "reason": "configured queue depth covers sampled ubuntu-1 steady-state cold-fill fanout",
        },
        {
            "requirement_id": "ubuntu1-steady-state-deadline",
            "status": "pass" if steady_deadline_miss_rows == 0 and steady_issue_rows == steady_deadline_met_rows else "blocked",
            "actual": f"{steady_deadline_met_rows}/{steady_issue_rows}",
            "required": "all steady-state issue rows",
            "reason": "all ubuntu-1 steady-state cold-fill pages complete before the target-token deadline",
        },
        {
            "requirement_id": "bootstrap-prefetch-scheduler",
            "status": "blocked",
            "actual": "0",
            "required": "1",
            "reason": "first-token cold-fill rows still have no previous compute window",
        },
        {
            "requirement_id": "actual-async-prefetch-execution",
            "status": "blocked",
            "actual": "0",
            "required": "1",
            "reason": "v61bk is a scheduler admission ledger, not async I/O execution",
        },
        {
            "requirement_id": "manifest-only-no-repo-payload",
            "status": "pass",
            "actual": "0",
            "required": "0",
            "reason": "v61bk emits scheduling rows only",
        },
    ]
)

write_csv(run_dir / "ubuntu1_prefetch_scheduler_token_rows.csv", list(scheduler_token_rows[0].keys()), scheduler_token_rows)
write_csv(run_dir / "ubuntu1_prefetch_scheduler_issue_rows.csv", list(issue_rows[0].keys()), issue_rows)
write_csv(run_dir / "ubuntu1_prefetch_queue_depth_rows.csv", list(queue_depth_rows[0].keys()), queue_depth_rows)
write_csv(run_dir / "ubuntu1_prefetch_deadline_requirement_rows.csv", list(deadline_rows[0].keys()), deadline_rows)

steady_scheduler_ready = int(steady_issue_rows == 11 and steady_deadline_met_rows == 11 and steady_deadline_miss_rows == 0 and max_steady_required_depth <= configured_queue_depth)
bootstrap_scheduler_ready = 0
ubuntu1_prefetch_scheduler_admission_ready = int(steady_scheduler_ready and bootstrap_scheduler_ready)

metric = {
    "metric_id": "v61bk_ubuntu1_prefetch_queue_depth_scheduler_metrics",
    "model_id": model_id,
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready": "1",
    "v61bj_ubuntu1_prefetch_overlap_admission_gate_ready": v61bj_summary["v61bj_ubuntu1_prefetch_overlap_admission_gate_ready"],
    "selected_target_path": v61bj_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bj_summary["ubuntu1_hotset_root"],
    "source_bound_token_rows": "37",
    "total_cold_fill_page_rows": str(len(issue_rows)),
    "bootstrap_cold_fill_page_rows": str(bootstrap_cold_fill_page_rows),
    "ubuntu1_steady_state_prefetch_issue_rows": str(steady_issue_rows),
    "ubuntu1_steady_state_deadline_met_rows": str(steady_deadline_met_rows),
    "ubuntu1_steady_state_deadline_miss_rows": str(steady_deadline_miss_rows),
    "no_prefetch_required_rows": str(no_prefetch_required_rows),
    "configured_prefetch_queue_depth": str(configured_queue_depth),
    "max_steady_state_required_queue_depth": str(max_steady_required_depth),
    "max_bootstrap_required_queue_depth": str(max_bootstrap_required_depth),
    "steady_state_queue_depth_headroom": str(configured_queue_depth - max_steady_required_depth),
    "bootstrap_queue_depth_headroom": str(configured_queue_depth - max_bootstrap_required_depth),
    "ubuntu1_ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
    "prior_token_compute_window_ms": fmt(compute_window_ms),
    "min_deadline_slack_ms": fmt(min_slack),
    "ubuntu1_steady_state_scheduler_ready": str(steady_scheduler_ready),
    "bootstrap_scheduler_ready": str(bootstrap_scheduler_ready),
    "ubuntu1_prefetch_scheduler_admission_ready": str(ubuntu1_prefetch_scheduler_admission_ready),
    "queue_depth_control_ready": "1",
    "actual_async_prefetch_execution_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffers_ready": "0",
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_prefetch_scheduler_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61bj-ubuntu1-prefetch-overlap-input", "ready", "v61bj ubuntu-1 steady-state overlap evidence is bound"),
    ("ubuntu1-steady-state-queue-depth", "ready" if max_steady_required_depth <= configured_queue_depth else "blocked", f"max_steady_state_required_queue_depth={max_steady_required_depth}"),
    ("ubuntu1-steady-state-deadline", "ready" if steady_scheduler_ready else "blocked", f"ubuntu1_steady_state_deadline_met_rows={steady_deadline_met_rows}/{steady_issue_rows}"),
    ("bootstrap-prefetch-scheduler", "blocked", "bootstrap cold fill has no previous compute window"),
    ("actual-async-prefetch-execution", "blocked", "io_uring or equivalent async prefetch is not executed by v61bk"),
    ("registered-buffer-prefetch", "blocked", "registered buffers are not allocated by v61bk"),
    ("full-checkpoint-materialization", "blocked", "only sampled hotset pages are resident on ubuntu-1"),
    ("full-safetensors-page-hash-binding", "blocked", "full 134k+ page hash coverage is not complete"),
    ("full-runtime-ubuntu1-hotset-reuse-admission", "blocked", "sampled scheduler admission is not complete runtime admission"),
    ("real-model-generation", "blocked", "scheduler admission does not execute Mixtral generation"),
    ("production-latency", "blocked", "sampled deadline rows are not production latency"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bj-ubuntu1-prefetch-overlap-input", "status": "pass", "reason": "v61bj ubuntu-1 steady-state overlap evidence is ready"},
    {"gate": "ubuntu1-steady-state-queue-depth", "status": "pass" if max_steady_required_depth <= configured_queue_depth else "blocked", "reason": f"max_steady_state_required_queue_depth={max_steady_required_depth}"},
    {"gate": "ubuntu1-steady-state-deadline", "status": "pass" if steady_scheduler_ready else "blocked", "reason": f"ubuntu1_steady_state_deadline_met_rows={steady_deadline_met_rows}/{steady_issue_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "bootstrap-prefetch-scheduler", "status": "blocked", "reason": "bootstrap cold fill has no previous compute window"},
    {"gate": "actual-async-prefetch-execution", "status": "blocked", "reason": "v61bk does not execute async prefetch"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only sampled hotset pages are resident on ubuntu-1"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full checkpoint page hash sweep remains incomplete"},
    {"gate": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "blocked", "reason": "sampled scheduler admission is not full runtime admission"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "sampled scheduler rows are not production latency"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bk Ubuntu-1 Prefetch Queue-Depth Scheduler Gate Boundary

This gate consumes v61bj ubuntu-1 sampled prefetch-overlap evidence and turns
the steady-state cold-fill pages into queue-depth/deadline scheduler rows.

It is an admission ledger, not actual async I/O execution.

Verified sampled scheduler evidence:

- selected_target_path={v61bj_summary['selected_target_path']}
- source_bound_token_rows=37
- total_cold_fill_page_rows={len(issue_rows)}
- bootstrap_cold_fill_page_rows={bootstrap_cold_fill_page_rows}
- ubuntu1_steady_state_prefetch_issue_rows={steady_issue_rows}
- ubuntu1_steady_state_deadline_met_rows={steady_deadline_met_rows}
- ubuntu1_steady_state_deadline_miss_rows={steady_deadline_miss_rows}
- no_prefetch_required_rows={no_prefetch_required_rows}
- configured_prefetch_queue_depth={configured_queue_depth}
- max_steady_state_required_queue_depth={max_steady_required_depth}
- max_bootstrap_required_queue_depth={max_bootstrap_required_depth}
- ubuntu1_ssd_read_latency_ms_p95_per_page={fmt(read_p95_ms)}
- prior_token_compute_window_ms={fmt(compute_window_ms)}
- min_deadline_slack_ms={fmt(min_slack)}
- ubuntu1_steady_state_scheduler_ready={steady_scheduler_ready}
- bootstrap_scheduler_ready={bootstrap_scheduler_ready}
- ubuntu1_prefetch_scheduler_admission_ready={ubuntu1_prefetch_scheduler_admission_ready}
- queue_depth_control_ready=1
- actual_async_prefetch_execution_ready=0
- actual_io_uring_execution_ready=0
- registered_buffers_ready=0
- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bk=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 sampled steady-state queue-depth/deadline scheduler
admission for the v61bj target-resident hotset replay.

Blocked wording: actual async/io_uring prefetch execution, registered-buffer
prefetch, bootstrap cold-start solved, full checkpoint materialization, full
page-hash coverage, full runtime admission, actual Mixtral generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BK_UBUNTU1_PREFETCH_QUEUE_DEPTH_SCHEDULER_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready": 1,
    "source_v61bj_ready": int(v61bj_summary["v61bj_ubuntu1_prefetch_overlap_admission_gate_ready"]),
    "source_bound_token_rows": 37,
    "total_cold_fill_page_rows": len(issue_rows),
    "bootstrap_cold_fill_page_rows": bootstrap_cold_fill_page_rows,
    "ubuntu1_steady_state_prefetch_issue_rows": steady_issue_rows,
    "ubuntu1_steady_state_deadline_met_rows": steady_deadline_met_rows,
    "ubuntu1_steady_state_deadline_miss_rows": steady_deadline_miss_rows,
    "configured_prefetch_queue_depth": configured_queue_depth,
    "max_steady_state_required_queue_depth": max_steady_required_depth,
    "ubuntu1_steady_state_scheduler_ready": steady_scheduler_ready,
    "bootstrap_scheduler_ready": bootstrap_scheduler_ready,
    "ubuntu1_prefetch_scheduler_admission_ready": ubuntu1_prefetch_scheduler_admission_ready,
    "actual_async_prefetch_execution_ready": 0,
    "actual_io_uring_execution_ready": 0,
    "registered_buffers_ready": 0,
    "full_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bk": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
