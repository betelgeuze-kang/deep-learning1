#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61aw_io_uring_registered_buffer_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v61aw_io_uring_registered_buffer_preflight_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61aw_io_uring_registered_buffer_preflight_decision.csv"

V61AW_REUSE_EXISTING="${V61AW_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61aw_io_uring_registered_buffer_preflight.sh" >/dev/null

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
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61aw_io_uring_registered_buffer_preflight_ready": "1",
    "v61av_async_prefetch_execution_probe_ready": "1",
    "v61av_actual_async_prefetch_execution_ready": "1",
    "linux_io_uring_header_ready": "1",
    "liburing_header_ready": "0",
    "io_uring_setup_syscall_number": "425",
    "io_uring_enter_syscall_number": "426",
    "io_uring_register_syscall_number": "427",
    "io_uring_setup_errno": "1",
    "io_uring_setup_errno_name": "EPERM",
    "io_uring_setup_ready": "0",
    "io_uring_enter_ready": "0",
    "io_uring_register_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffers_ready": "0",
    "registered_buffer_prefetch_ready": "0",
    "threaded_odirect_fallback_ready": "1",
    "io_uring_blocker_reason": "io_uring_setup_errno_1_EPERM",
    "checkpoint_payload_bytes_downloaded_by_v61aw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61aw {field}: expected {value}, got {summary.get(field)}")
if not summary.get("kernel_release"):
    raise SystemExit("v61aw kernel_release must be present")

required_files = [
    "io_uring_capability_rows.csv",
    "io_uring_setup_probe_rows.csv",
    "registered_buffer_preflight_rows.csv",
    "io_uring_requirement_rows.csv",
    "io_uring_fallback_binding_rows.csv",
    "io_uring_preflight_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AW_IO_URING_REGISTERED_BUFFER_PREFLIGHT_BOUNDARY.md",
    "v61aw_io_uring_registered_buffer_preflight_manifest.json",
    "sha256_manifest.csv",
    "source_v61av/async_prefetch_execution_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61aw artifact: {rel}")

capability = read_csv(run_dir / "io_uring_capability_rows.csv")[0]
setup = read_csv(run_dir / "io_uring_setup_probe_rows.csv")[0]
registered_buffer = read_csv(run_dir / "registered_buffer_preflight_rows.csv")[0]
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "io_uring_requirement_rows.csv")}
fallback = read_csv(run_dir / "io_uring_fallback_binding_rows.csv")[0]
metric = read_csv(run_dir / "io_uring_preflight_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if capability["linux_io_uring_header_ready"] != "1":
    raise SystemExit("v61aw linux io_uring header should be present")
if capability["liburing_header_ready"] != "0":
    raise SystemExit("v61aw liburing header should be absent on current host")
if setup["setup_errno_name"] != "EPERM" or setup["io_uring_setup_ready"] != "0":
    raise SystemExit("v61aw should record EPERM setup blocker on current host")
if registered_buffer["registered_buffer_prefetch_ready"] != "0":
    raise SystemExit("v61aw must keep registered-buffer prefetch blocked")
if registered_buffer["blocker_reason"] != "requires-successful-io-uring-setup":
    raise SystemExit("v61aw registered-buffer blocker should bind to io_uring setup")
if fallback["actual_async_prefetch_execution_ready"] != "1":
    raise SystemExit("v61aw fallback should bind v61av ready state")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61aw metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61av-threaded-odirect-fallback-input",
    "linux-io-uring-header",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61aw requirement should pass: {requirement_id}")
for requirement_id in [
    "liburing-header",
    "io-uring-setup-syscall",
    "registered-buffer-prefetch",
    "actual-io-uring-prefetch-execution",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61aw requirement should remain blocked: {requirement_id}")

for gate in [
    "v61av-threaded-odirect-fallback-input",
    "linux-io-uring-header",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61aw gate should pass: {gate}")
for gate in [
    "liburing-header",
    "io-uring-setup-syscall",
    "registered-buffer-prefetch",
    "actual-io-uring-prefetch-execution",
    "full-runtime-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61aw gate should remain blocked: {gate}")

for gap in [
    "v61av-threaded-odirect-fallback-input",
    "linux-io-uring-header",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61aw gap should be ready: {gap}")
for gap in [
    "liburing-header",
    "io-uring-setup-syscall",
    "registered-buffer-prefetch",
    "actual-io-uring-prefetch-execution",
    "full-runtime-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61aw gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61aw_io_uring_registered_buffer_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61aw_io_uring_registered_buffer_preflight_ready") != 1:
    raise SystemExit("v61aw manifest readiness mismatch")
if manifest.get("io_uring_setup_errno_name") != "EPERM":
    raise SystemExit("v61aw manifest EPERM mismatch")
if manifest.get("actual_io_uring_execution_ready") != 0:
    raise SystemExit("v61aw manifest must keep io_uring blocked")
if manifest.get("threaded_odirect_fallback_ready") != 1:
    raise SystemExit("v61aw manifest fallback mismatch")

boundary = (run_dir / "V61AW_IO_URING_REGISTERED_BUFFER_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "linux_io_uring_header_ready=1",
    "liburing_header_ready=0",
    "io_uring_setup_errno=1",
    "io_uring_setup_errno_name=EPERM",
    "io_uring_setup_ready=0",
    "io_uring_enter_ready=0",
    "io_uring_register_ready=0",
    "actual_io_uring_execution_ready=0",
    "registered_buffers_ready=0",
    "registered_buffer_prefetch_ready=0",
    "threaded_odirect_fallback_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61aw=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61aw boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61aw sha256 mismatch: {rel}")
PY

echo "v61aw io_uring registered-buffer preflight smoke passed"
