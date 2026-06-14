#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61at_prefetch_overlap_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61at_prefetch_overlap_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61at_prefetch_overlap_admission_gate_decision.csv"

V61AT_REUSE_EXISTING="${V61AT_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61at_prefetch_overlap_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def fmt(value):
    if math.isfinite(value):
        return f"{value:.6f}"
    return str(value)


summary = read_csv(summary_csv)[0]
source_v61l_summary = read_csv(run_dir / "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv")[0]
source_v61z_summary = read_csv(run_dir / "source_v61z/v61z_hotset_direct_io_replay_summary.csv")[0]
source_v61as_summary = read_csv(run_dir / "source_v61as/v61as_hotset_reuse_admission_gate_summary.csv")[0]
source_v61as_tokens = read_csv(run_dir / "source_v61as/hotset_reuse_token_rows.csv")
source_bound_token_rows = len(source_v61as_tokens)
scheduled_hotset_page_read_rows = int(source_v61as_summary["scheduled_hotset_page_read_rows"])
unique_hotset_page_rows = int(source_v61as_summary["unique_hotset_page_rows"])
read_p95_ms = float(source_v61z_summary["direct_io_read_latency_ms_p95"])
gpu_kernel_ms = float(source_v61l_summary["gpu_kernel_avg_ms"])
bootstrap_rows = 1
steady_rows = max(0, source_bound_token_rows - bootstrap_rows)
steady_pass_rows = 0
steady_blocked_rows = 0
no_prefetch_required_rows = 0
max_steady_cold_fill_ms = 0.0
min_overlap_slack_ms = None
previous_compute_ms = 0.0
for index, token in enumerate(source_v61as_tokens):
    scheduled_pages = int(token["scheduled_page_rows"])
    miss_pages = int(token["cache_miss_page_rows"])
    cold_fill_p95_ms = miss_pages * read_p95_ms
    compute_window_ms = scheduled_pages * gpu_kernel_ms
    if index > 0:
        max_steady_cold_fill_ms = max(max_steady_cold_fill_ms, cold_fill_p95_ms)
        if miss_pages == 0:
            steady_pass_rows += 1
            no_prefetch_required_rows += 1
            overlap_slack_ms = previous_compute_ms
        elif cold_fill_p95_ms <= previous_compute_ms:
            steady_pass_rows += 1
            overlap_slack_ms = previous_compute_ms - cold_fill_p95_ms
        else:
            steady_blocked_rows += 1
            overlap_slack_ms = previous_compute_ms - cold_fill_p95_ms
        min_overlap_slack_ms = overlap_slack_ms if min_overlap_slack_ms is None else min(min_overlap_slack_ms, overlap_slack_ms)
    previous_compute_ms = compute_window_ms
token_page_kernel_compute_window_ms = 4 * gpu_kernel_ms
bootstrap_cold_fill_latency_ms_p95 = 4 * read_p95_ms
uncached_p95_read_latency_ms_total = scheduled_hotset_page_read_rows * read_p95_ms
persistent_hotset_cold_fill_p95_latency_ms_total = int(source_v61as_summary["cache_miss_page_rows"]) * read_p95_ms
persistent_hotset_saved_p95_latency_ms_total = uncached_p95_read_latency_ms_total - persistent_hotset_cold_fill_p95_latency_ms_total
expected = {
    "v61at_prefetch_overlap_admission_gate_ready": "1",
    "v61l_gpu_page_dequant_matmul_measurement_ready": "1",
    "v61z_hotset_direct_io_replay_ready": "1",
    "v61as_hotset_reuse_admission_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_bound_token_rows": str(source_bound_token_rows),
    "scheduled_hotset_page_read_rows": str(scheduled_hotset_page_read_rows),
    "unique_hotset_page_rows": str(unique_hotset_page_rows),
    "bootstrap_cold_start_rows": str(bootstrap_rows),
    "steady_state_token_rows": str(steady_rows),
    "steady_state_prefetch_overlap_pass_rows": str(steady_pass_rows),
    "steady_state_prefetch_overlap_blocked_rows": str(steady_blocked_rows),
    "no_prefetch_required_rows": str(no_prefetch_required_rows),
    "ssd_read_latency_ms_p95_per_page": fmt(read_p95_ms),
    "gpu_kernel_avg_ms_per_page": fmt(gpu_kernel_ms),
    "token_page_kernel_compute_window_ms": fmt(token_page_kernel_compute_window_ms),
    "bootstrap_cold_fill_latency_ms_p95": fmt(bootstrap_cold_fill_latency_ms_p95),
    "max_steady_state_cold_fill_latency_ms_p95": fmt(max_steady_cold_fill_ms),
    "min_steady_state_overlap_slack_ms": fmt(min_overlap_slack_ms or 0.0),
    "uncached_p95_read_latency_ms_total": fmt(uncached_p95_read_latency_ms_total),
    "persistent_hotset_cold_fill_p95_latency_ms_total": fmt(persistent_hotset_cold_fill_p95_latency_ms_total),
    "persistent_hotset_saved_p95_latency_ms_total": fmt(persistent_hotset_saved_p95_latency_ms_total),
    "steady_state_prefetch_overlap_ready": "1",
    "bootstrap_cold_start_ready": "0",
    "prefetch_overlap_admission_ready": "0",
    "full_runtime_hotset_reuse_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61at": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61at {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "prefetch_overlap_token_rows.csv",
    "prefetch_overlap_window_rows.csv",
    "prefetch_overlap_requirement_rows.csv",
    "prefetch_overlap_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AT_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md",
    "v61at_prefetch_overlap_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61l/gpu_page_dequant_matmul_rows.csv",
    "source_v61z/hotset_direct_io_metric_rows.csv",
    "source_v61as/hotset_reuse_token_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61at artifact: {rel}")

token_rows = read_csv(run_dir / "prefetch_overlap_token_rows.csv")
window_rows = read_csv(run_dir / "prefetch_overlap_window_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "prefetch_overlap_requirement_rows.csv")}
metric = read_csv(run_dir / "prefetch_overlap_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(token_rows) != source_bound_token_rows or len(window_rows) != 1:
    raise SystemExit("v61at row count mismatch")
if token_rows[0]["prefetch_overlap_status"] != "bootstrap-cold-start-blocked":
    raise SystemExit("v61at first token should be bootstrap blocked")
if token_rows[0]["steady_state_prefetch_overlap_ready"] != "0":
    raise SystemExit("v61at first token should not be steady-state ready")
if sum(1 for row in token_rows[1:] if row["prefetch_overlap_status"] == "prefetch-overlap-pass") != steady_pass_rows - no_prefetch_required_rows:
    raise SystemExit("v61at steady-state prefetch overlap pass row count mismatch")
if sum(1 for row in token_rows[1:] if row["prefetch_overlap_status"] == "no-prefetch-required") != no_prefetch_required_rows:
    raise SystemExit("v61at no-prefetch-required row count mismatch")
if any(row["steady_state_prefetch_overlap_ready"] != "1" for row in token_rows[1:]):
    raise SystemExit("v61at all non-bootstrap rows should be steady-state ready")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in token_rows):
    raise SystemExit("v61at must not commit checkpoint payload bytes")
if any(row["actual_model_generation_ready"] != "0" for row in token_rows):
    raise SystemExit("v61at must keep generation blocked")
if any(row["production_latency_claim_ready"] != "0" for row in token_rows):
    raise SystemExit("v61at must keep production latency blocked")

for field, value in expected.items():
    if field.startswith("v61at_") or field.startswith("v61l_") or field.startswith("v61z_") or field.startswith("v61as_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61at metric {field}: expected {value}, got {metric[field]}")
    if field in window_rows[0] and window_rows[0][field] != value:
        raise SystemExit(f"v61at window {field}: expected {value}, got {window_rows[0][field]}")

for requirement_id in [
    "v61l-gpu-page-kernel-input",
    "v61z-direct-io-latency-input",
    "v61as-hotset-reuse-input",
    "steady-state-prefetch-overlap",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61at requirement should pass: {requirement_id}")
for requirement_id in [
    "bootstrap-cold-start",
    "full-prefetch-overlap-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61at requirement should remain blocked: {requirement_id}")

for gate in [
    "v61l-gpu-page-kernel-input",
    "v61z-direct-io-latency-input",
    "v61as-hotset-reuse-input",
    "steady-state-prefetch-overlap",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61at gate should pass: {gate}")
for gate in [
    "bootstrap-cold-start",
    "full-runtime-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61at gate should remain blocked: {gate}")

for gap in [
    "v61l-gpu-page-kernel-input",
    "v61z-direct-io-latency-input",
    "v61as-hotset-reuse-input",
    "steady-state-prefetch-overlap",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61at gap should be ready: {gap}")
for gap in [
    "bootstrap-cold-start",
    "full-runtime-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61at gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61at_prefetch_overlap_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61at_prefetch_overlap_admission_gate_ready") != 1:
    raise SystemExit("v61at manifest readiness mismatch")
if manifest.get("steady_state_prefetch_overlap_pass_rows") != steady_pass_rows:
    raise SystemExit("v61at manifest steady-state pass mismatch")
if manifest.get("prefetch_overlap_admission_ready") != 0:
    raise SystemExit("v61at manifest should keep full admission blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61at") != 0:
    raise SystemExit("v61at manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61AT_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"steady_state_token_rows={steady_rows}",
    f"steady_state_prefetch_overlap_pass_rows={steady_pass_rows}",
    f"steady_state_prefetch_overlap_blocked_rows={steady_blocked_rows}",
    f"token_page_kernel_compute_window_ms={fmt(token_page_kernel_compute_window_ms)}",
    f"bootstrap_cold_fill_latency_ms_p95={fmt(bootstrap_cold_fill_latency_ms_p95)}",
    f"min_steady_state_overlap_slack_ms={fmt(min_overlap_slack_ms or 0.0)}",
    "steady_state_prefetch_overlap_ready=1",
    "bootstrap_cold_start_ready=0",
    "prefetch_overlap_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61at=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61at boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61at sha256 mismatch: {rel}")
PY

echo "v61at prefetch overlap admission gate smoke passed"
