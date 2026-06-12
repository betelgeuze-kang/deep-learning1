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
expected = {
    "v61at_prefetch_overlap_admission_gate_ready": "1",
    "v61l_gpu_page_dequant_matmul_measurement_ready": "1",
    "v61z_hotset_direct_io_replay_ready": "1",
    "v61as_hotset_reuse_admission_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_bound_token_rows": "37",
    "scheduled_hotset_page_read_rows": "148",
    "unique_hotset_page_rows": "15",
    "bootstrap_cold_start_rows": "1",
    "steady_state_token_rows": "36",
    "steady_state_prefetch_overlap_pass_rows": "36",
    "steady_state_prefetch_overlap_blocked_rows": "0",
    "no_prefetch_required_rows": "25",
    "ssd_read_latency_ms_p95_per_page": "0.956690",
    "gpu_kernel_avg_ms_per_page": "0.513442",
    "token_page_kernel_compute_window_ms": "2.053768",
    "bootstrap_cold_fill_latency_ms_p95": "3.826760",
    "max_steady_state_cold_fill_latency_ms_p95": "0.956690",
    "min_steady_state_overlap_slack_ms": "1.097078",
    "uncached_p95_read_latency_ms_total": "141.590120",
    "persistent_hotset_cold_fill_p95_latency_ms_total": "14.350350",
    "persistent_hotset_saved_p95_latency_ms_total": "127.239770",
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

if len(token_rows) != 37 or len(window_rows) != 1:
    raise SystemExit("v61at row count mismatch")
if token_rows[0]["prefetch_overlap_status"] != "bootstrap-cold-start-blocked":
    raise SystemExit("v61at first token should be bootstrap blocked")
if token_rows[0]["steady_state_prefetch_overlap_ready"] != "0":
    raise SystemExit("v61at first token should not be steady-state ready")
if sum(1 for row in token_rows[1:] if row["prefetch_overlap_status"] == "prefetch-overlap-pass") != 11:
    raise SystemExit("v61at should record 11 steady-state prefetch overlap pass rows")
if sum(1 for row in token_rows[1:] if row["prefetch_overlap_status"] == "no-prefetch-required") != 25:
    raise SystemExit("v61at should record 25 no-prefetch-required rows")
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
if manifest.get("steady_state_prefetch_overlap_pass_rows") != 36:
    raise SystemExit("v61at manifest steady-state pass mismatch")
if manifest.get("prefetch_overlap_admission_ready") != 0:
    raise SystemExit("v61at manifest should keep full admission blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61at") != 0:
    raise SystemExit("v61at manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61AT_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "steady_state_token_rows=36",
    "steady_state_prefetch_overlap_pass_rows=36",
    "steady_state_prefetch_overlap_blocked_rows=0",
    "token_page_kernel_compute_window_ms=2.053768",
    "bootstrap_cold_fill_latency_ms_p95=3.826760",
    "min_steady_state_overlap_slack_ms=1.097078",
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
