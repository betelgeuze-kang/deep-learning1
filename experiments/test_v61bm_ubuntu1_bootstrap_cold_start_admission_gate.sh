#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bm_ubuntu1_bootstrap_cold_start_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61bm_ubuntu1_bootstrap_cold_start_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bm_ubuntu1_bootstrap_cold_start_admission_gate_decision.csv"

V61BM_REUSE_EXISTING="${V61BM_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bm_ubuntu1_bootstrap_cold_start_admission_gate.sh" >/dev/null

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
expected_exact = {
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_ready": "1",
    "v61bl_ubuntu1_async_prefetch_execution_probe_ready": "1",
    "v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready": "1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "configured_prefetch_queue_depth": "4",
    "configured_bootstrap_cold_start_budget_ms": "100.000000",
    "bootstrap_prefetch_issue_rows": "4",
    "bootstrap_cold_start_admitted_rows": "4",
    "bootstrap_async_prefetch_hash_match_rows": "4",
    "bootstrap_async_prefetch_error_rows": "0",
    "bootstrap_cold_start_bytes_read_total": "8388608",
    "ubuntu1_steady_state_prefetch_issue_rows": "11",
    "ubuntu1_steady_state_async_prefetch_hash_match_rows": "11",
    "actual_async_prefetch_execution_ready": "1",
    "bootstrap_cold_start_admission_ready": "1",
    "bootstrap_prefetch_admission_ready": "0",
    "ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready": "1",
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
for field, value in expected_exact.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bm {field}: expected {value}, got {summary.get(field)}")

for numeric_field in [
    "ubuntu1_target_available_bytes",
    "bootstrap_cold_start_read_latency_ms_sum",
    "bootstrap_cold_start_read_latency_ms_max",
    "bootstrap_cold_start_batch_elapsed_ms",
    "bootstrap_cold_start_budget_headroom_ms",
]:
    if float(summary[numeric_field]) <= 0:
        raise SystemExit(f"v61bm {numeric_field} must be positive")
if float(summary["bootstrap_cold_start_batch_elapsed_ms"]) > float(summary["configured_bootstrap_cold_start_budget_ms"]):
    raise SystemExit("v61bm bootstrap cold-start batch must fit configured budget")

required_files = [
    "ubuntu1_bootstrap_cold_start_page_rows.csv",
    "ubuntu1_bootstrap_cold_start_batch_rows.csv",
    "ubuntu1_bootstrap_cold_start_requirement_rows.csv",
    "ubuntu1_bootstrap_cold_start_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BM_UBUNTU1_BOOTSTRAP_COLD_START_ADMISSION_GATE_BOUNDARY.md",
    "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bl/ubuntu1_async_prefetch_execution_rows.csv",
    "source_v61bl/ubuntu1_async_prefetch_batch_rows.csv",
    "source_v61bk/ubuntu1_prefetch_scheduler_issue_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bm artifact: {rel}")

page_rows = read_csv(run_dir / "ubuntu1_bootstrap_cold_start_page_rows.csv")
batch_rows = read_csv(run_dir / "ubuntu1_bootstrap_cold_start_batch_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_bootstrap_cold_start_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_bootstrap_cold_start_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(page_rows) != 4 or len(batch_rows) != 1:
    raise SystemExit("v61bm row count mismatch")
if any(row["ubuntu1_async_prefetch_hash_match"] != "1" for row in page_rows):
    raise SystemExit("v61bm all bootstrap page rows must hash-match")
if any(row["bootstrap_cold_start_admission_ready"] != "1" for row in page_rows):
    raise SystemExit("v61bm all bootstrap rows must be cold-start admitted")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in page_rows):
    raise SystemExit("v61bm must not commit checkpoint payload bytes")

for field, value in expected_exact.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bm metric {field}: expected {value}, got {metric[field]}")
    if field in batch_rows[0] and batch_rows[0][field] != value:
        raise SystemExit(f"v61bm batch {field}: expected {value}, got {batch_rows[0][field]}")

for requirement_id in [
    "v61bl-ubuntu1-async-prefetch-input",
    "bootstrap-direct-read-evidence",
    "bootstrap-cold-start-budget",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bm requirement should pass: {requirement_id}")
for requirement_id in [
    "bootstrap-prefetch-overlap",
    "full-runtime-ubuntu1-hotset-reuse-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bm requirement should stay blocked: {requirement_id}")

for gate in [
    "v61bl-ubuntu1-async-prefetch-input",
    "bootstrap-direct-read-evidence",
    "bootstrap-cold-start-admission",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bm gate should pass: {gate}")
for gate in [
    "bootstrap-prefetch-overlap",
    "io-uring-execution",
    "registered-buffer-prefetch",
    "full-runtime-ubuntu1-hotset-reuse-admission",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bm gate should stay blocked: {gate}")

for gap in [
    "v61bl-ubuntu1-async-prefetch-input",
    "bootstrap-direct-read-evidence",
    "bootstrap-cold-start-admission",
    "ubuntu1-bootstrap-plus-steady-state-sampled-admission",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bm gap should be ready: {gap}")
for gap in [
    "bootstrap-prefetch-overlap",
    "io-uring-execution",
    "registered-buffer-prefetch",
    "full-runtime-ubuntu1-hotset-reuse-admission",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bm gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bm_ubuntu1_bootstrap_cold_start_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bm_ubuntu1_bootstrap_cold_start_admission_gate_ready") != 1:
    raise SystemExit("v61bm manifest readiness mismatch")
if manifest.get("bootstrap_cold_start_admission_ready") != 1:
    raise SystemExit("v61bm manifest cold-start readiness mismatch")
if manifest.get("bootstrap_prefetch_admission_ready") != 0:
    raise SystemExit("v61bm manifest must not claim bootstrap prefetch")
if manifest.get("full_checkpoint_materialization_ready") != 0:
    raise SystemExit("v61bm manifest should keep full materialization blocked")

boundary = (run_dir / "V61BM_UBUNTU1_BOOTSTRAP_COLD_START_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "bootstrap_prefetch_issue_rows=4",
    "bootstrap_async_prefetch_hash_match_rows=4",
    "bootstrap_cold_start_bytes_read_total=8388608",
    "configured_bootstrap_cold_start_budget_ms=100.000000",
    "bootstrap_cold_start_admission_ready=1",
    "bootstrap_prefetch_admission_ready=0",
    "ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready=1",
    "actual_io_uring_execution_ready=0",
    "registered_buffers_ready=0",
    "full_checkpoint_materialization_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bm=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bm boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bm sha256 mismatch: {rel}")
PY
