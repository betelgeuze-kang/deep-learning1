#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bj_ubuntu1_prefetch_overlap_admission_gate"
RUN_ID="${V61BJ_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bj_ubuntu1_prefetch_overlap_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61l_gpu_page_dequant_matmul_measurement.sh" >/dev/null
V61BD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh" >/dev/null
V61BI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bi_ubuntu1_hotset_reuse_admission_gate.sh" >/dev/null

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
v61bd_dir = results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay" / "replay_001"
v61bi_dir = results / "v61bi_ubuntu1_hotset_reuse_admission_gate" / "gate_001"

v61l_summary = read_csv(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv")[0]
v61bd_summary = read_csv(results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv")[0]
v61bi_summary = read_csv(results / "v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv")[0]
if v61l_summary.get("v61l_gpu_page_dequant_matmul_measurement_ready") != "1":
    raise SystemExit("v61bj requires v61l_gpu_page_dequant_matmul_measurement_ready=1")
if v61bd_summary.get("v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready") != "1":
    raise SystemExit("v61bj requires v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1")
if v61bi_summary.get("ubuntu1_sampled_hotset_reuse_ready") != "1":
    raise SystemExit("v61bj requires ubuntu1_sampled_hotset_reuse_ready=1")

for src, rel in [
    (results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    (results / "v61l_gpu_page_dequant_matmul_measurement_decision.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_decision.csv"),
    (v61l_dir / "gpu_page_dequant_matmul_rows.csv", "source_v61l/gpu_page_dequant_matmul_rows.csv"),
    (v61l_dir / "runtime_gap_rows.csv", "source_v61l/runtime_gap_rows.csv"),
    (v61l_dir / "sha256_manifest.csv", "source_v61l/sha256_manifest.csv"),
    (results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv", "source_v61bd/v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv"),
    (results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_decision.csv", "source_v61bd/v61bd_ubuntu1_sampled_hotset_direct_io_replay_decision.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_read_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_read_rows.csv"),
    (v61bd_dir / "ubuntu1_hotset_direct_io_metric_rows.csv", "source_v61bd/ubuntu1_hotset_direct_io_metric_rows.csv"),
    (v61bd_dir / "sha256_manifest.csv", "source_v61bd/sha256_manifest.csv"),
    (results / "v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv", "source_v61bi/v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv"),
    (results / "v61bi_ubuntu1_hotset_reuse_admission_gate_decision.csv", "source_v61bi/v61bi_ubuntu1_hotset_reuse_admission_gate_decision.csv"),
    (v61bi_dir / "ubuntu1_hotset_reuse_token_rows.csv", "source_v61bi/ubuntu1_hotset_reuse_token_rows.csv"),
    (v61bi_dir / "ubuntu1_hotset_reuse_window_rows.csv", "source_v61bi/ubuntu1_hotset_reuse_window_rows.csv"),
    (v61bi_dir / "sha256_manifest.csv", "source_v61bi/sha256_manifest.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61bi_dir / "ubuntu1_hotset_reuse_token_rows.csv")
if len(token_rows) != 37:
    raise SystemExit("v61bj expects 37 ubuntu-1 hotset reuse token rows")

gpu_kernel_ms = float(v61l_summary["gpu_kernel_avg_ms"])
read_p95_ms = float(v61bd_summary["direct_io_read_latency_ms_p95"])
read_p50_ms = float(v61bd_summary["direct_io_read_latency_ms_p50"])
page_bytes = int(v61bi_summary["page_bytes"])
token_overlap_rows = []

previous_compute_ms = 0.0
bootstrap_rows = 0
steady_rows = 0
steady_pass_rows = 0
steady_blocked_rows = 0
no_prefetch_required_rows = 0
max_steady_cold_fill_ms = 0.0
min_overlap_slack_ms = None

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
        min_overlap_slack_ms = overlap_slack_ms if min_overlap_slack_ms is None else min(min_overlap_slack_ms, overlap_slack_ms)
    token_overlap_rows.append(
        {
            "ubuntu1_prefetch_token_id": f"v61bj_ubuntu1_prefetch_token_{index:04d}",
            "ubuntu1_reuse_token_id": token["ubuntu1_reuse_token_id"],
            "ubuntu1_token_budget_id": token["ubuntu1_token_budget_id"],
            "workload_binding_id": token["workload_binding_id"],
            "query_id": token["query_id"],
            "query_family": token["query_family"],
            "token_index": str(index),
            "scheduled_page_rows": str(scheduled_pages),
            "cache_miss_page_rows": str(miss_pages),
            "cache_hit_page_rows": str(hit_pages),
            "page_bytes": str(page_bytes),
            "ubuntu1_ssd_read_latency_ms_p50_per_page": fmt(read_p50_ms),
            "ubuntu1_ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
            "ubuntu1_cold_fill_latency_ms_p50": fmt(cold_fill_p50_ms),
            "ubuntu1_cold_fill_latency_ms_p95": fmt(cold_fill_p95_ms),
            "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
            "gpu_page_compute_window_ms": fmt(compute_window_ms),
            "prior_token_compute_overlap_window_ms": fmt(previous_compute_ms),
            "ubuntu1_prefetch_overlap_slack_ms": fmt(overlap_slack_ms),
            "ubuntu1_prefetch_overlap_status": status,
            "ubuntu1_steady_state_prefetch_overlap_ready": str(overlap_ready),
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )
    previous_compute_ms = compute_window_ms

write_csv(run_dir / "ubuntu1_prefetch_overlap_token_rows.csv", list(token_overlap_rows[0].keys()), token_overlap_rows)

uncached_p95_total_ms = int(v61bi_summary["scheduled_hotset_page_read_rows"]) * read_p95_ms
cold_fill_p95_total_ms = int(v61bi_summary["cache_miss_page_rows"]) * read_p95_ms
saved_p95_ms = uncached_p95_total_ms - cold_fill_p95_total_ms
token_compute_window_ms = 4 * gpu_kernel_ms
bootstrap_cold_fill_p95_ms = 4 * read_p95_ms
steady_state_prefetch_overlap_ready = int(steady_rows == 36 and steady_pass_rows == 36 and steady_blocked_rows == 0)
bootstrap_cold_start_ready = 0
ubuntu1_prefetch_overlap_admission_ready = int(steady_state_prefetch_overlap_ready and bootstrap_cold_start_ready)

window_rows = [
    {
        "ubuntu1_prefetch_window_id": "v61bj_ubuntu1_source_bound_37_query_prefetch_window",
        "selected_target_path": v61bi_summary["selected_target_path"],
        "ubuntu1_hotset_root": v61bi_summary["ubuntu1_hotset_root"],
        "source_bound_token_rows": "37",
        "scheduled_hotset_page_read_rows": v61bi_summary["scheduled_hotset_page_read_rows"],
        "unique_hotset_page_rows": v61bi_summary["unique_hotset_page_rows"],
        "bootstrap_cold_start_rows": str(bootstrap_rows),
        "steady_state_token_rows": str(steady_rows),
        "ubuntu1_steady_state_prefetch_overlap_pass_rows": str(steady_pass_rows),
        "ubuntu1_steady_state_prefetch_overlap_blocked_rows": str(steady_blocked_rows),
        "no_prefetch_required_rows": str(no_prefetch_required_rows),
        "ubuntu1_ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
        "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
        "token_page_kernel_compute_window_ms": fmt(token_compute_window_ms),
        "bootstrap_cold_fill_latency_ms_p95": fmt(bootstrap_cold_fill_p95_ms),
        "max_steady_state_cold_fill_latency_ms_p95": fmt(max_steady_cold_fill_ms),
        "min_steady_state_overlap_slack_ms": fmt(min_overlap_slack_ms or 0.0),
        "uncached_p95_read_latency_ms_total": fmt(uncached_p95_total_ms),
        "persistent_hotset_cold_fill_p95_latency_ms_total": fmt(cold_fill_p95_total_ms),
        "persistent_hotset_saved_p95_latency_ms_total": fmt(saved_p95_ms),
        "ubuntu1_steady_state_prefetch_overlap_ready": str(steady_state_prefetch_overlap_ready),
        "bootstrap_cold_start_ready": str(bootstrap_cold_start_ready),
        "ubuntu1_prefetch_overlap_admission_ready": str(ubuntu1_prefetch_overlap_admission_ready),
    }
]
write_csv(run_dir / "ubuntu1_prefetch_overlap_window_rows.csv", list(window_rows[0].keys()), window_rows)

requirement_rows = [
    {"requirement_id": "v61l-gpu-page-kernel-input", "status": "pass", "actual": v61l_summary["gpu_kernel_avg_ms"], "required": ">0", "reason": "GPU page-dequant-matmul timing is bound"},
    {"requirement_id": "v61bd-ubuntu1-direct-io-latency-input", "status": "pass", "actual": v61bd_summary["direct_io_read_latency_ms_p95"], "required": ">0", "reason": "ubuntu-1 direct-I/O p95 latency is bound"},
    {"requirement_id": "v61bi-ubuntu1-hotset-reuse-input", "status": "pass", "actual": v61bi_summary["ubuntu1_sampled_hotset_reuse_ready"], "required": "1", "reason": "ubuntu-1 sampled hotset reuse gate is ready"},
    {"requirement_id": "ubuntu1-steady-state-prefetch-overlap", "status": "pass" if steady_state_prefetch_overlap_ready else "blocked", "actual": str(steady_pass_rows), "required": "36", "reason": "all non-bootstrap ubuntu-1 tokens fit cold-fill p95 inside prior token compute window"},
    {"requirement_id": "bootstrap-cold-start", "status": "blocked", "actual": "0", "required": "1", "reason": "first-token cold fill has no prior compute window"},
    {"requirement_id": "full-ubuntu1-prefetch-overlap-admission", "status": "blocked", "actual": str(ubuntu1_prefetch_overlap_admission_ready), "required": "1", "reason": "steady-state overlap passes but bootstrap and full runtime gates remain open"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61bj emits timing overlap rows only"},
]
write_csv(run_dir / "ubuntu1_prefetch_overlap_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bj_ubuntu1_prefetch_overlap_admission_metrics",
    "model_id": model_id,
    "v61l_gpu_page_dequant_matmul_measurement_ready": v61l_summary["v61l_gpu_page_dequant_matmul_measurement_ready"],
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready": v61bd_summary["v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready"],
    "v61bi_ubuntu1_hotset_reuse_admission_gate_ready": v61bi_summary["v61bi_ubuntu1_hotset_reuse_admission_gate_ready"],
    "selected_target_path": v61bi_summary["selected_target_path"],
    "ubuntu1_hotset_root": v61bi_summary["ubuntu1_hotset_root"],
    "source_bound_token_rows": "37",
    "scheduled_hotset_page_read_rows": v61bi_summary["scheduled_hotset_page_read_rows"],
    "unique_hotset_page_rows": v61bi_summary["unique_hotset_page_rows"],
    "bootstrap_cold_start_rows": str(bootstrap_rows),
    "steady_state_token_rows": str(steady_rows),
    "ubuntu1_steady_state_prefetch_overlap_pass_rows": str(steady_pass_rows),
    "ubuntu1_steady_state_prefetch_overlap_blocked_rows": str(steady_blocked_rows),
    "no_prefetch_required_rows": str(no_prefetch_required_rows),
    "ubuntu1_ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
    "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
    "token_page_kernel_compute_window_ms": fmt(token_compute_window_ms),
    "bootstrap_cold_fill_latency_ms_p95": fmt(bootstrap_cold_fill_p95_ms),
    "max_steady_state_cold_fill_latency_ms_p95": fmt(max_steady_cold_fill_ms),
    "min_steady_state_overlap_slack_ms": fmt(min_overlap_slack_ms or 0.0),
    "uncached_p95_read_latency_ms_total": fmt(uncached_p95_total_ms),
    "persistent_hotset_cold_fill_p95_latency_ms_total": fmt(cold_fill_p95_total_ms),
    "persistent_hotset_saved_p95_latency_ms_total": fmt(saved_p95_ms),
    "ubuntu1_steady_state_prefetch_overlap_ready": str(steady_state_prefetch_overlap_ready),
    "bootstrap_cold_start_ready": str(bootstrap_cold_start_ready),
    "ubuntu1_prefetch_overlap_admission_ready": str(ubuntu1_prefetch_overlap_admission_ready),
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_prefetch_overlap_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61l-gpu-page-kernel-input", "ready", "GPU page-dequant-matmul timing is bound"),
    ("v61bd-ubuntu1-direct-io-latency-input", "ready", "ubuntu-1 direct-I/O p95 latency is bound"),
    ("v61bi-ubuntu1-hotset-reuse-input", "ready", "ubuntu-1 sampled hotset reuse rows are bound"),
    ("ubuntu1-steady-state-prefetch-overlap", "ready" if steady_state_prefetch_overlap_ready else "blocked", f"{steady_pass_rows}/{steady_rows} steady-state tokens pass overlap"),
    ("bootstrap-cold-start", "blocked", "first token cold fill has no prior compute window"),
    ("full-runtime-ubuntu1-hotset-reuse-admission", "blocked", "requires bootstrap/full-runtime gates beyond sampled steady-state overlap"),
    ("full-checkpoint-materialization", "blocked", "only sampled hotset pages are resident on ubuntu-1"),
    ("full-safetensors-page-hash-binding", "blocked", "full 134k+ page hash coverage is not complete"),
    ("real-model-generation", "blocked", "prefetch overlap admission does not execute Mixtral generation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bj_ubuntu1_prefetch_overlap_admission_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61l-gpu-page-kernel-input", "status": "pass", "reason": "GPU page-kernel timing is bound"},
    {"gate": "v61bd-ubuntu1-direct-io-latency-input", "status": "pass", "reason": "ubuntu-1 direct-I/O p95 latency is bound"},
    {"gate": "v61bi-ubuntu1-hotset-reuse-input", "status": "pass", "reason": "ubuntu-1 sampled hotset reuse is bound"},
    {"gate": "ubuntu1-steady-state-prefetch-overlap", "status": "pass" if steady_state_prefetch_overlap_ready else "blocked", "reason": f"ubuntu1_steady_state_prefetch_overlap_pass_rows={steady_pass_rows}/{steady_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived timing rows only"},
    {"gate": "bootstrap-cold-start", "status": "blocked", "reason": "first token has no prior compute overlap window"},
    {"gate": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "blocked", "reason": "sampled steady-state overlap is not full runtime admission"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only sampled hotset pages are resident on ubuntu-1"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full checkpoint page hash sweep remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bj Ubuntu-1 Prefetch Overlap Admission Gate Boundary

This artifact binds v61l GPU page-kernel timing, v61bd ubuntu-1 direct-I/O
latency, and v61bi ubuntu-1 sampled hotset reuse rows into a target-resident
prefetch-overlap ledger. It shows the non-bootstrap sampled tokens can hide
ubuntu-1 cold-fill p95 reads inside the prior token page-kernel compute window,
while keeping cold-start, full checkpoint materialization, full page-hash
coverage, and full runtime admission blocked.

Evidence emitted:

- selected_target_path={v61bi_summary['selected_target_path']}
- source_bound_token_rows=37
- steady_state_token_rows={steady_rows}
- ubuntu1_steady_state_prefetch_overlap_pass_rows={steady_pass_rows}
- ubuntu1_steady_state_prefetch_overlap_blocked_rows={steady_blocked_rows}
- ubuntu1_ssd_read_latency_ms_p95_per_page={fmt(read_p95_ms)}
- gpu_kernel_avg_ms_per_page={fmt(gpu_kernel_ms)}
- token_page_kernel_compute_window_ms={fmt(token_compute_window_ms)}
- bootstrap_cold_fill_latency_ms_p95={fmt(bootstrap_cold_fill_p95_ms)}
- max_steady_state_cold_fill_latency_ms_p95={fmt(max_steady_cold_fill_ms)}
- min_steady_state_overlap_slack_ms={fmt(min_overlap_slack_ms or 0.0)}
- uncached_p95_read_latency_ms_total={fmt(uncached_p95_total_ms)}
- persistent_hotset_cold_fill_p95_latency_ms_total={fmt(cold_fill_p95_total_ms)}
- persistent_hotset_saved_p95_latency_ms_total={fmt(saved_p95_ms)}
- ubuntu1_steady_state_prefetch_overlap_ready={steady_state_prefetch_overlap_ready}
- bootstrap_cold_start_ready=0
- ubuntu1_prefetch_overlap_admission_ready=0
- full_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bj=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 sampled steady-state prefetch-overlap feasibility
over target-resident hotset rows.
Blocked wording: cold-start solved, full checkpoint materialized, full page-hash
coverage, full runtime hotset admission, real Mixtral generation, production
latency, or release readiness.
"""
(run_dir / "V61BJ_UBUNTU1_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bj_ubuntu1_prefetch_overlap_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bj_ubuntu1_prefetch_overlap_admission_gate_ready": 1,
    "source_v61l_summary_sha256": sha256(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    "source_v61bd_summary_sha256": sha256(results / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv"),
    "source_v61bi_summary_sha256": sha256(results / "v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv"),
    "steady_state_token_rows": steady_rows,
    "ubuntu1_steady_state_prefetch_overlap_pass_rows": steady_pass_rows,
    "ubuntu1_steady_state_prefetch_overlap_blocked_rows": steady_blocked_rows,
    "ubuntu1_steady_state_prefetch_overlap_ready": steady_state_prefetch_overlap_ready,
    "bootstrap_cold_start_ready": bootstrap_cold_start_ready,
    "ubuntu1_prefetch_overlap_admission_ready": ubuntu1_prefetch_overlap_admission_ready,
    "full_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61bj_ubuntu1_prefetch_overlap_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bj_ubuntu1_prefetch_overlap_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
