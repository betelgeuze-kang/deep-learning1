#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61at_prefetch_overlap_admission_gate"
RUN_ID="${V61AT_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61at_prefetch_overlap_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61l_gpu_page_dequant_matmul_measurement.sh" >/dev/null
V61Z_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61z_hotset_direct_io_replay.sh" >/dev/null
V61AS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61as_hotset_reuse_admission_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
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


v61l_dir = results / "v61l_gpu_page_dequant_matmul_measurement" / "gpu_001"
v61z_dir = results / "v61z_hotset_direct_io_replay" / "replay_001"
v61as_dir = results / "v61as_hotset_reuse_admission_gate" / "gate_001"

v61l_summary = read_csv(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv")[0]
v61z_summary = read_csv(results / "v61z_hotset_direct_io_replay_summary.csv")[0]
v61as_summary = read_csv(results / "v61as_hotset_reuse_admission_gate_summary.csv")[0]
if v61l_summary.get("v61l_gpu_page_dequant_matmul_measurement_ready") != "1":
    raise SystemExit("v61at requires v61l_gpu_page_dequant_matmul_measurement_ready=1")
if v61z_summary.get("v61z_hotset_direct_io_replay_ready") != "1":
    raise SystemExit("v61at requires v61z_hotset_direct_io_replay_ready=1")
if v61as_summary.get("sampled_hotset_reuse_ready") != "1":
    raise SystemExit("v61at requires sampled_hotset_reuse_ready=1")

for src, rel in [
    (results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    (results / "v61l_gpu_page_dequant_matmul_measurement_decision.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_decision.csv"),
    (v61l_dir / "gpu_page_dequant_matmul_rows.csv", "source_v61l/gpu_page_dequant_matmul_rows.csv"),
    (v61l_dir / "runtime_gap_rows.csv", "source_v61l/runtime_gap_rows.csv"),
    (v61l_dir / "sha256_manifest.csv", "source_v61l/sha256_manifest.csv"),
    (results / "v61z_hotset_direct_io_replay_summary.csv", "source_v61z/v61z_hotset_direct_io_replay_summary.csv"),
    (results / "v61z_hotset_direct_io_replay_decision.csv", "source_v61z/v61z_hotset_direct_io_replay_decision.csv"),
    (v61z_dir / "hotset_direct_io_read_rows.csv", "source_v61z/hotset_direct_io_read_rows.csv"),
    (v61z_dir / "hotset_direct_io_metric_rows.csv", "source_v61z/hotset_direct_io_metric_rows.csv"),
    (v61z_dir / "sha256_manifest.csv", "source_v61z/sha256_manifest.csv"),
    (results / "v61as_hotset_reuse_admission_gate_summary.csv", "source_v61as/v61as_hotset_reuse_admission_gate_summary.csv"),
    (results / "v61as_hotset_reuse_admission_gate_decision.csv", "source_v61as/v61as_hotset_reuse_admission_gate_decision.csv"),
    (v61as_dir / "hotset_reuse_token_rows.csv", "source_v61as/hotset_reuse_token_rows.csv"),
    (v61as_dir / "hotset_reuse_window_rows.csv", "source_v61as/hotset_reuse_window_rows.csv"),
    (v61as_dir / "sha256_manifest.csv", "source_v61as/sha256_manifest.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61as_dir / "hotset_reuse_token_rows.csv")
expected_token_rows = int(v61as_summary["source_bound_token_budget_rows"])
if len(token_rows) != expected_token_rows:
    raise SystemExit(f"v61at expects {expected_token_rows} hotset reuse token rows")

gpu_kernel_ms = float(v61l_summary["gpu_kernel_avg_ms"])
read_p95_ms = float(v61z_summary["direct_io_read_latency_ms_p95"])
read_p50_ms = float(v61z_summary["direct_io_read_latency_ms_p50"])
page_bytes = int(v61as_summary["page_bytes"])
token_overlap_rows = []

previous_compute_ms = 0.0
bootstrap_rows = 0
steady_rows = 0
steady_pass_rows = 0
steady_blocked_rows = 0
no_prefetch_required_rows = 0
max_steady_cold_fill_ms = 0.0
max_overlap_slack_ms = None

for index, token in enumerate(token_rows):
    scheduled_pages = int(token["scheduled_page_rows"])
    miss_pages = int(token["cache_miss_page_rows"])
    hit_pages = int(token["cache_hit_page_rows"])
    cold_fill_p95_ms = miss_pages * read_p95_ms
    cold_fill_p50_ms = miss_pages * read_p50_ms
    compute_window_ms = scheduled_pages * gpu_kernel_ms
    if index == 0:
        status = "bootstrap-cold-start-blocked"
        overlap_ready = 0
        bootstrap_rows += 1
        overlap_slack_ms = -cold_fill_p95_ms
    elif miss_pages == 0:
        status = "no-prefetch-required"
        overlap_ready = 1
        steady_rows += 1
        steady_pass_rows += 1
        no_prefetch_required_rows += 1
        overlap_slack_ms = previous_compute_ms
    elif cold_fill_p95_ms <= previous_compute_ms:
        status = "prefetch-overlap-pass"
        overlap_ready = 1
        steady_rows += 1
        steady_pass_rows += 1
        overlap_slack_ms = previous_compute_ms - cold_fill_p95_ms
    else:
        status = "prefetch-overlap-blocked"
        overlap_ready = 0
        steady_rows += 1
        steady_blocked_rows += 1
        overlap_slack_ms = previous_compute_ms - cold_fill_p95_ms
    if index > 0:
        max_steady_cold_fill_ms = max(max_steady_cold_fill_ms, cold_fill_p95_ms)
        max_overlap_slack_ms = overlap_slack_ms if max_overlap_slack_ms is None else min(max_overlap_slack_ms, overlap_slack_ms)
    token_overlap_rows.append(
        {
            "prefetch_token_id": f"v61at_prefetch_token_{index:04d}",
            "reuse_token_id": token["reuse_token_id"],
            "token_budget_id": token["token_budget_id"],
            "workload_binding_id": token["workload_binding_id"],
            "query_id": token["query_id"],
            "query_family": token["query_family"],
            "token_index": str(index),
            "scheduled_page_rows": str(scheduled_pages),
            "cache_miss_page_rows": str(miss_pages),
            "cache_hit_page_rows": str(hit_pages),
            "page_bytes": str(page_bytes),
            "ssd_read_latency_ms_p50_per_page": fmt(read_p50_ms),
            "ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
            "cold_fill_latency_ms_p50": fmt(cold_fill_p50_ms),
            "cold_fill_latency_ms_p95": fmt(cold_fill_p95_ms),
            "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
            "gpu_page_compute_window_ms": fmt(compute_window_ms),
            "prior_token_compute_overlap_window_ms": fmt(previous_compute_ms),
            "prefetch_overlap_slack_ms": fmt(overlap_slack_ms),
            "prefetch_overlap_status": status,
            "steady_state_prefetch_overlap_ready": str(overlap_ready),
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )
    previous_compute_ms = compute_window_ms

write_csv(run_dir / "prefetch_overlap_token_rows.csv", list(token_overlap_rows[0].keys()), token_overlap_rows)

uncached_p95_total_ms = int(v61as_summary["scheduled_hotset_page_read_rows"]) * read_p95_ms
cold_fill_p95_total_ms = int(v61as_summary["cache_miss_page_rows"]) * read_p95_ms
saved_p95_ms = uncached_p95_total_ms - cold_fill_p95_total_ms
token_compute_window_ms = 4 * gpu_kernel_ms
bootstrap_cold_fill_p95_ms = 4 * read_p95_ms
expected_steady_rows = max(0, len(token_rows) - 1)
steady_state_prefetch_overlap_ready = int(steady_rows == expected_steady_rows and steady_pass_rows == expected_steady_rows and steady_blocked_rows == 0)
bootstrap_cold_start_ready = 0
prefetch_overlap_admission_ready = int(steady_state_prefetch_overlap_ready and bootstrap_cold_start_ready)

window_rows = [
    {
        "prefetch_window_id": f"v61at_source_bound_{len(token_rows)}_query_prefetch_window",
        "source_bound_token_rows": str(len(token_rows)),
        "scheduled_hotset_page_read_rows": v61as_summary["scheduled_hotset_page_read_rows"],
        "unique_hotset_page_rows": v61as_summary["unique_hotset_page_rows"],
        "bootstrap_cold_start_rows": str(bootstrap_rows),
        "steady_state_token_rows": str(steady_rows),
        "steady_state_prefetch_overlap_pass_rows": str(steady_pass_rows),
        "steady_state_prefetch_overlap_blocked_rows": str(steady_blocked_rows),
        "no_prefetch_required_rows": str(no_prefetch_required_rows),
        "ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
        "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
        "token_page_kernel_compute_window_ms": fmt(token_compute_window_ms),
        "bootstrap_cold_fill_latency_ms_p95": fmt(bootstrap_cold_fill_p95_ms),
        "max_steady_state_cold_fill_latency_ms_p95": fmt(max_steady_cold_fill_ms),
        "min_steady_state_overlap_slack_ms": fmt(max_overlap_slack_ms or 0.0),
        "uncached_p95_read_latency_ms_total": fmt(uncached_p95_total_ms),
        "persistent_hotset_cold_fill_p95_latency_ms_total": fmt(cold_fill_p95_total_ms),
        "persistent_hotset_saved_p95_latency_ms_total": fmt(saved_p95_ms),
        "steady_state_prefetch_overlap_ready": str(steady_state_prefetch_overlap_ready),
        "bootstrap_cold_start_ready": str(bootstrap_cold_start_ready),
        "prefetch_overlap_admission_ready": str(prefetch_overlap_admission_ready),
    }
]
write_csv(run_dir / "prefetch_overlap_window_rows.csv", list(window_rows[0].keys()), window_rows)

requirement_rows = [
    {"requirement_id": "v61l-gpu-page-kernel-input", "status": "pass", "actual": v61l_summary["gpu_kernel_avg_ms"], "required": ">0", "reason": "GPU page-kernel timing is bound"},
    {"requirement_id": "v61z-direct-io-latency-input", "status": "pass", "actual": v61z_summary["direct_io_read_latency_ms_p95"], "required": ">0", "reason": "direct-I/O p95 latency is bound"},
    {"requirement_id": "v61as-hotset-reuse-input", "status": "pass", "actual": v61as_summary["sampled_hotset_reuse_ready"], "required": "1", "reason": "sampled hotset reuse gate is ready"},
    {"requirement_id": "steady-state-prefetch-overlap", "status": "pass" if steady_state_prefetch_overlap_ready else "blocked", "actual": str(steady_pass_rows), "required": str(expected_steady_rows), "reason": "all non-bootstrap tokens fit cold-fill p95 inside prior token compute window"},
    {"requirement_id": "bootstrap-cold-start", "status": "blocked", "actual": "0", "required": "1", "reason": "first-token cold fill has no prior compute window"},
    {"requirement_id": "full-prefetch-overlap-admission", "status": "blocked", "actual": str(prefetch_overlap_admission_ready), "required": "1", "reason": "steady-state overlap passes but bootstrap and full runtime gates remain open"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61at emits timing overlap rows only"},
]
write_csv(run_dir / "prefetch_overlap_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61at_prefetch_overlap_admission_metrics",
    "model_id": model_id,
    "v61l_gpu_page_dequant_matmul_measurement_ready": v61l_summary["v61l_gpu_page_dequant_matmul_measurement_ready"],
    "v61z_hotset_direct_io_replay_ready": v61z_summary["v61z_hotset_direct_io_replay_ready"],
    "v61as_hotset_reuse_admission_gate_ready": v61as_summary["v61as_hotset_reuse_admission_gate_ready"],
    "source_bound_token_rows": str(len(token_rows)),
    "scheduled_hotset_page_read_rows": v61as_summary["scheduled_hotset_page_read_rows"],
    "unique_hotset_page_rows": v61as_summary["unique_hotset_page_rows"],
    "bootstrap_cold_start_rows": str(bootstrap_rows),
    "steady_state_token_rows": str(steady_rows),
    "steady_state_prefetch_overlap_pass_rows": str(steady_pass_rows),
    "steady_state_prefetch_overlap_blocked_rows": str(steady_blocked_rows),
    "no_prefetch_required_rows": str(no_prefetch_required_rows),
    "ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
    "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
    "token_page_kernel_compute_window_ms": fmt(token_compute_window_ms),
    "bootstrap_cold_fill_latency_ms_p95": fmt(bootstrap_cold_fill_p95_ms),
    "max_steady_state_cold_fill_latency_ms_p95": fmt(max_steady_cold_fill_ms),
    "min_steady_state_overlap_slack_ms": fmt(max_overlap_slack_ms or 0.0),
    "uncached_p95_read_latency_ms_total": fmt(uncached_p95_total_ms),
    "persistent_hotset_cold_fill_p95_latency_ms_total": fmt(cold_fill_p95_total_ms),
    "persistent_hotset_saved_p95_latency_ms_total": fmt(saved_p95_ms),
    "steady_state_prefetch_overlap_ready": str(steady_state_prefetch_overlap_ready),
    "bootstrap_cold_start_ready": str(bootstrap_cold_start_ready),
    "prefetch_overlap_admission_ready": str(prefetch_overlap_admission_ready),
    "full_runtime_hotset_reuse_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61at": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "prefetch_overlap_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61l-gpu-page-kernel-input", "ready", "GPU page-dequant-matmul timing is bound"),
    ("v61z-direct-io-latency-input", "ready", "direct-I/O p95 latency is bound"),
    ("v61as-hotset-reuse-input", "ready", "sampled hotset reuse rows are bound"),
    ("steady-state-prefetch-overlap", "ready" if steady_state_prefetch_overlap_ready else "blocked", f"{steady_pass_rows}/{steady_rows} steady-state tokens pass overlap"),
    ("bootstrap-cold-start", "blocked", "first token cold fill has no prior compute window"),
    ("full-runtime-hotset-reuse-admission", "blocked", "requires bootstrap/full-runtime gates beyond sampled steady-state overlap"),
    ("real-model-generation", "blocked", "prefetch overlap admission does not execute Mixtral generation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61at_prefetch_overlap_admission_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61l-gpu-page-kernel-input", "status": "pass", "reason": "GPU page-kernel timing is bound"},
    {"gate": "v61z-direct-io-latency-input", "status": "pass", "reason": "direct-I/O p95 latency is bound"},
    {"gate": "v61as-hotset-reuse-input", "status": "pass", "reason": "sampled hotset reuse is bound"},
    {"gate": "steady-state-prefetch-overlap", "status": "pass" if steady_state_prefetch_overlap_ready else "blocked", "reason": f"steady_state_prefetch_overlap_pass_rows={steady_pass_rows}/{steady_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived timing rows only"},
    {"gate": "bootstrap-cold-start", "status": "blocked", "reason": "first token has no prior compute overlap window"},
    {"gate": "full-runtime-hotset-reuse-admission", "status": "blocked", "reason": "sampled steady-state overlap is not full runtime admission"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61at Prefetch Overlap Admission Gate Boundary

This artifact binds v61l GPU page-kernel timing, v61z direct-I/O latency, and
v61as sampled hotset reuse rows into a sampled prefetch-overlap ledger. It shows
the non-bootstrap sampled tokens can hide cold-fill p95 reads inside the prior
token page-kernel compute window, while keeping cold-start and full runtime
admission blocked.

Evidence emitted:

- source_bound_token_rows={len(token_rows)}
- steady_state_token_rows={steady_rows}
- steady_state_prefetch_overlap_pass_rows={steady_pass_rows}
- steady_state_prefetch_overlap_blocked_rows={steady_blocked_rows}
- ssd_read_latency_ms_p95_per_page={fmt(read_p95_ms)}
- gpu_kernel_avg_ms_per_page={fmt(gpu_kernel_ms)}
- token_page_kernel_compute_window_ms={fmt(token_compute_window_ms)}
- bootstrap_cold_fill_latency_ms_p95={fmt(bootstrap_cold_fill_p95_ms)}
- max_steady_state_cold_fill_latency_ms_p95={fmt(max_steady_cold_fill_ms)}
- min_steady_state_overlap_slack_ms={fmt(max_overlap_slack_ms or 0.0)}
- uncached_p95_read_latency_ms_total={fmt(uncached_p95_total_ms)}
- persistent_hotset_cold_fill_p95_latency_ms_total={fmt(cold_fill_p95_total_ms)}
- persistent_hotset_saved_p95_latency_ms_total={fmt(saved_p95_ms)}
- steady_state_prefetch_overlap_ready={steady_state_prefetch_overlap_ready}
- bootstrap_cold_start_ready=0
- prefetch_overlap_admission_ready=0
- checkpoint_payload_bytes_downloaded_by_v61at=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: sampled steady-state prefetch-overlap feasibility over
source-bound hotset rows.
Blocked wording: cold-start solved, full runtime hotset admission, real Mixtral
generation, production latency, or release readiness.
"""
(run_dir / "V61AT_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61at_prefetch_overlap_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61at_prefetch_overlap_admission_gate_ready": 1,
    "source_v61l_summary_sha256": sha256(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    "source_v61z_summary_sha256": sha256(results / "v61z_hotset_direct_io_replay_summary.csv"),
    "source_v61as_summary_sha256": sha256(results / "v61as_hotset_reuse_admission_gate_summary.csv"),
    "steady_state_token_rows": steady_rows,
    "steady_state_prefetch_overlap_pass_rows": steady_pass_rows,
    "steady_state_prefetch_overlap_blocked_rows": steady_blocked_rows,
    "steady_state_prefetch_overlap_ready": steady_state_prefetch_overlap_ready,
    "bootstrap_cold_start_ready": bootstrap_cold_start_ready,
    "prefetch_overlap_admission_ready": prefetch_overlap_admission_ready,
    "checkpoint_payload_bytes_downloaded_by_v61at": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61at_prefetch_overlap_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61at_prefetch_overlap_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
