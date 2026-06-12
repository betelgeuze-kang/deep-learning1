#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61av_async_prefetch_execution_probe/probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61av_async_prefetch_execution_probe_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61av_async_prefetch_execution_probe_decision.csv"

V61AV_REUSE_EXISTING="${V61AV_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61av_async_prefetch_execution_probe.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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


summary = read_csv(summary_csv)[0]
expected_exact = {
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61av_async_prefetch_execution_probe_ready": "1",
    "v61au_prefetch_queue_depth_scheduler_gate_ready": "1",
    "v61z_hotset_direct_io_replay_ready": "1",
    "configured_prefetch_queue_depth": "4",
    "prefetch_issue_rows": "15",
    "executed_prefetch_issue_rows": "15",
    "async_prefetch_hash_match_rows": "15",
    "async_prefetch_error_rows": "0",
    "steady_state_prefetch_issue_rows": "11",
    "steady_state_async_prefetch_hash_match_rows": "11",
    "bootstrap_prefetch_issue_rows": "4",
    "bootstrap_async_prefetch_hash_match_rows": "4",
    "async_prefetch_batch_rows": "4",
    "max_submitted_batch_size": "4",
    "async_prefetch_bytes_read_total": "31457280",
    "actual_async_prefetch_execution_ready": "1",
    "steady_state_actual_async_prefetch_ready": "1",
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
for field, value in expected_exact.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61av {field}: expected {value}, got {summary.get(field)}")

for numeric_field in [
    "async_prefetch_read_latency_ms_p50",
    "async_prefetch_read_latency_ms_p95",
    "async_prefetch_batch_elapsed_ms_total",
    "async_prefetch_effective_throughput_mib_s",
]:
    if float(summary[numeric_field]) <= 0:
        raise SystemExit(f"v61av {numeric_field} must be positive")

required_files = [
    "async_prefetch_execution_rows.csv",
    "async_prefetch_batch_rows.csv",
    "async_prefetch_requirement_rows.csv",
    "async_prefetch_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AV_ASYNC_PREFETCH_EXECUTION_PROBE_BOUNDARY.md",
    "v61av_async_prefetch_execution_probe_manifest.json",
    "sha256_manifest.csv",
    "source_v61au/prefetch_scheduler_issue_rows.csv",
    "source_v61z/hotset_direct_io_read_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61av artifact: {rel}")

execution_rows = read_csv(run_dir / "async_prefetch_execution_rows.csv")
batch_rows = read_csv(run_dir / "async_prefetch_batch_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "async_prefetch_requirement_rows.csv")}
metric = read_csv(run_dir / "async_prefetch_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(execution_rows) != 15 or len(batch_rows) != 4:
    raise SystemExit("v61av row count mismatch")
if sum(1 for row in execution_rows if row["source_scheduler_status"] == "scheduled-before-deadline") != 11:
    raise SystemExit("v61av steady-state execution row count mismatch")
if sum(1 for row in execution_rows if row["source_scheduler_status"] == "bootstrap-blocked-no-prior-window") != 4:
    raise SystemExit("v61av bootstrap execution row count mismatch")
if any(row["async_prefetch_hash_match"] != "1" for row in execution_rows):
    raise SystemExit("v61av all async prefetch rows must hash-match")
if any(row["actual_async_prefetch_execution_ready"] != "1" for row in execution_rows):
    raise SystemExit("v61av all async prefetch rows must mark execution ready")
if any(row["actual_io_uring_execution_ready"] != "0" for row in execution_rows):
    raise SystemExit("v61av must not claim io_uring execution")
if any(row["registered_buffers_ready"] != "0" for row in execution_rows):
    raise SystemExit("v61av must not claim registered buffers")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in execution_rows):
    raise SystemExit("v61av must not commit checkpoint payload bytes")
if max(int(row["submitted_issue_rows"]) for row in batch_rows) != 4:
    raise SystemExit("v61av should submit max batch size 4")

for field, value in expected_exact.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61av metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61au-scheduler-input",
    "v61z-local-page-input",
    "actual-threaded-async-prefetch-execution",
    "steady-state-async-prefetch-execution",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61av requirement should pass: {requirement_id}")
for requirement_id in [
    "bootstrap-prefetch-admission",
    "io-uring-execution",
    "registered-buffer-prefetch",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61av requirement should stay blocked: {requirement_id}")

for gate in [
    "v61au-scheduler-input",
    "v61z-local-page-input",
    "actual-threaded-async-prefetch-execution",
    "steady-state-async-prefetch-execution",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61av gate should pass: {gate}")
for gate in [
    "bootstrap-prefetch-admission",
    "io-uring-execution",
    "registered-buffer-prefetch",
    "full-runtime-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61av gate should remain blocked: {gate}")

for gap in [
    "v61au-scheduler-input",
    "v61z-local-page-input",
    "actual-threaded-async-prefetch-execution",
    "steady-state-async-prefetch-execution",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61av gap should be ready: {gap}")
for gap in [
    "bootstrap-prefetch-admission",
    "io-uring-execution",
    "registered-buffer-prefetch",
    "full-runtime-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61av gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61av_async_prefetch_execution_probe_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61av_async_prefetch_execution_probe_ready") != 1:
    raise SystemExit("v61av manifest readiness mismatch")
if manifest.get("actual_async_prefetch_execution_ready") != 1:
    raise SystemExit("v61av manifest async readiness mismatch")
if manifest.get("actual_io_uring_execution_ready") != 0:
    raise SystemExit("v61av manifest must keep io_uring blocked")
if manifest.get("prefetch_scheduler_admission_ready") != 0:
    raise SystemExit("v61av manifest should keep full admission blocked")

boundary = (run_dir / "V61AV_ASYNC_PREFETCH_EXECUTION_PROBE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "prefetch_issue_rows=15",
    "executed_prefetch_issue_rows=15",
    "async_prefetch_hash_match_rows=15",
    "steady_state_async_prefetch_hash_match_rows=11",
    "actual_async_prefetch_execution_ready=1",
    "actual_io_uring_execution_ready=0",
    "registered_buffers_ready=0",
    "bootstrap_prefetch_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61av=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61av boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61av sha256 mismatch: {rel}")
PY

echo "v61av async prefetch execution probe smoke passed"
