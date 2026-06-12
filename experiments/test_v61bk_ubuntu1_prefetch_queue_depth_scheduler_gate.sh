#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_decision.csv"

V61BK_REUSE_EXISTING="${V61BK_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"
ubuntu1_hotset_root = ubuntu1_target + "/.v61_sampled_hotset_pages"


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
expected = {
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready": "1",
    "v61bj_ubuntu1_prefetch_overlap_admission_gate_ready": "1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "source_bound_token_rows": "37",
    "total_cold_fill_page_rows": "15",
    "bootstrap_cold_fill_page_rows": "4",
    "ubuntu1_steady_state_prefetch_issue_rows": "11",
    "ubuntu1_steady_state_deadline_met_rows": "11",
    "ubuntu1_steady_state_deadline_miss_rows": "0",
    "no_prefetch_required_rows": "25",
    "configured_prefetch_queue_depth": "4",
    "max_steady_state_required_queue_depth": "1",
    "max_bootstrap_required_queue_depth": "4",
    "steady_state_queue_depth_headroom": "3",
    "bootstrap_queue_depth_headroom": "0",
    "ubuntu1_ssd_read_latency_ms_p95_per_page": "1.309456",
    "prior_token_compute_window_ms": "2.053768",
    "min_deadline_slack_ms": "0.744312",
    "ubuntu1_steady_state_scheduler_ready": "1",
    "bootstrap_scheduler_ready": "0",
    "ubuntu1_prefetch_scheduler_admission_ready": "0",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bk {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_prefetch_scheduler_token_rows.csv",
    "ubuntu1_prefetch_scheduler_issue_rows.csv",
    "ubuntu1_prefetch_queue_depth_rows.csv",
    "ubuntu1_prefetch_deadline_requirement_rows.csv",
    "ubuntu1_prefetch_scheduler_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BK_UBUNTU1_PREFETCH_QUEUE_DEPTH_SCHEDULER_GATE_BOUNDARY.md",
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bj/ubuntu1_prefetch_overlap_token_rows.csv",
    "source_v61bi/ubuntu1_hotset_reuse_page_rows.csv",
    "source_v61bd/ubuntu1_hotset_direct_io_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bk artifact: {rel}")

token_rows = read_csv(run_dir / "ubuntu1_prefetch_scheduler_token_rows.csv")
issue_rows = read_csv(run_dir / "ubuntu1_prefetch_scheduler_issue_rows.csv")
queue_rows = read_csv(run_dir / "ubuntu1_prefetch_queue_depth_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_prefetch_deadline_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_prefetch_scheduler_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(token_rows) != 37 or len(issue_rows) != 15 or len(queue_rows) != 1:
    raise SystemExit("v61bk row count mismatch")
if sum(1 for row in token_rows if row["scheduler_status"] == "bootstrap-blocked-no-prior-window") != 1:
    raise SystemExit("v61bk should keep exactly one bootstrap token blocked")
if sum(1 for row in token_rows if row["scheduler_status"] == "scheduled-before-deadline") != 11:
    raise SystemExit("v61bk should schedule 11 steady-state token rows")
if sum(1 for row in token_rows if row["scheduler_status"] == "no-prefetch-required") != 25:
    raise SystemExit("v61bk should record 25 no-prefetch-required token rows")
if sum(1 for row in issue_rows if row["ubuntu1_prefetch_issue_status"] == "scheduled-before-deadline") != 11:
    raise SystemExit("v61bk should schedule 11 issue rows before deadline")
if sum(1 for row in issue_rows if row["ubuntu1_prefetch_issue_status"] == "bootstrap-blocked-no-prior-window") != 4:
    raise SystemExit("v61bk should keep 4 bootstrap issue rows blocked")
if any(row["actual_async_prefetch_execution_ready"] != "0" for row in issue_rows):
    raise SystemExit("v61bk must not claim actual async execution")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in issue_rows):
    raise SystemExit("v61bk must not commit checkpoint payload bytes")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bk metric {field}: expected {value}, got {metric[field]}")
    if field in queue_rows[0] and queue_rows[0][field] != value:
        raise SystemExit(f"v61bk queue row {field}: expected {value}, got {queue_rows[0][field]}")

for requirement_id in [
    "v61bj-ubuntu1-prefetch-overlap-input",
    "ubuntu1-steady-state-queue-depth",
    "ubuntu1-steady-state-deadline",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bk requirement should pass: {requirement_id}")
for requirement_id in [
    "bootstrap-prefetch-scheduler",
    "actual-async-prefetch-execution",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bk requirement should remain blocked: {requirement_id}")

for gate in [
    "v61bj-ubuntu1-prefetch-overlap-input",
    "ubuntu1-steady-state-queue-depth",
    "ubuntu1-steady-state-deadline",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bk gate should pass: {gate}")
for gate in [
    "bootstrap-prefetch-scheduler",
    "actual-async-prefetch-execution",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "full-runtime-ubuntu1-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bk gate should remain blocked: {gate}")

for gap in [
    "v61bj-ubuntu1-prefetch-overlap-input",
    "ubuntu1-steady-state-queue-depth",
    "ubuntu1-steady-state-deadline",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bk gap should be ready: {gap}")
for gap in [
    "bootstrap-prefetch-scheduler",
    "actual-async-prefetch-execution",
    "registered-buffer-prefetch",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "full-runtime-ubuntu1-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bk gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready") != 1:
    raise SystemExit("v61bk manifest readiness mismatch")
if manifest.get("ubuntu1_steady_state_prefetch_issue_rows") != 11:
    raise SystemExit("v61bk manifest steady issue mismatch")
if manifest.get("ubuntu1_prefetch_scheduler_admission_ready") != 0:
    raise SystemExit("v61bk manifest should keep full admission blocked")
if manifest.get("actual_async_prefetch_execution_ready") != 0:
    raise SystemExit("v61bk manifest must keep async execution blocked")
if manifest.get("full_checkpoint_materialization_ready") != 0:
    raise SystemExit("v61bk manifest must keep full materialization blocked")

boundary = (run_dir / "V61BK_UBUNTU1_PREFETCH_QUEUE_DEPTH_SCHEDULER_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "ubuntu1_steady_state_prefetch_issue_rows=11",
    "ubuntu1_steady_state_deadline_met_rows=11",
    "ubuntu1_steady_state_deadline_miss_rows=0",
    "configured_prefetch_queue_depth=4",
    "max_steady_state_required_queue_depth=1",
    "ubuntu1_steady_state_scheduler_ready=1",
    "bootstrap_scheduler_ready=0",
    "actual_async_prefetch_execution_ready=0",
    "actual_io_uring_execution_ready=0",
    "full_checkpoint_materialization_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bk=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bk boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bk sha256 mismatch: {rel}")
PY

echo "v61bk ubuntu-1 prefetch queue-depth scheduler gate smoke passed"
