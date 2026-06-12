#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ax_async_io_backend_selection_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61ax_async_io_backend_selection_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ax_async_io_backend_selection_gate_decision.csv"

V61AX_REUSE_EXISTING="${V61AX_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ax_async_io_backend_selection_gate.sh" >/dev/null

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
    "v61ax_async_io_backend_selection_gate_ready": "1",
    "v61aw_io_uring_registered_buffer_preflight_ready": "1",
    "v61av_async_prefetch_execution_probe_ready": "1",
    "io_uring_registered_buffer_candidate_ready": "0",
    "threaded_odirect_candidate_ready": "1",
    "selected_async_io_backend": "threaded_odirect",
    "selected_backend_ready": "1",
    "selected_backend_queue_depth": "4",
    "selected_backend_hash_match_rows": "15",
    "selected_backend_error_rows": "0",
    "steady_state_selected_backend_ready": "1",
    "bootstrap_prefetch_admission_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffer_prefetch_ready": "0",
    "full_runtime_async_io_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ax": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ax {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "async_io_backend_candidate_rows.csv",
    "async_io_backend_selection_rows.csv",
    "async_io_backend_policy_rows.csv",
    "async_io_backend_requirement_rows.csv",
    "async_io_backend_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AX_ASYNC_IO_BACKEND_SELECTION_GATE_BOUNDARY.md",
    "v61ax_async_io_backend_selection_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61aw/v61aw_io_uring_registered_buffer_preflight_summary.csv",
    "source_v61aw/registered_buffer_preflight_rows.csv",
    "source_v61av/async_prefetch_execution_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ax artifact: {rel}")

candidates = {row["backend_id"]: row for row in read_csv(run_dir / "async_io_backend_candidate_rows.csv")}
selection = read_csv(run_dir / "async_io_backend_selection_rows.csv")[0]
policies = {row["policy_id"]: row for row in read_csv(run_dir / "async_io_backend_policy_rows.csv")}
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "async_io_backend_requirement_rows.csv")}
metric = read_csv(run_dir / "async_io_backend_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if set(candidates) != {"io_uring_registered_buffer", "threaded_odirect"}:
    raise SystemExit("v61ax candidate set mismatch")
if candidates["io_uring_registered_buffer"]["candidate_status"] != "blocked":
    raise SystemExit("v61ax should block io_uring registered-buffer candidate")
if candidates["io_uring_registered_buffer"]["selectable"] != "0":
    raise SystemExit("v61ax io_uring candidate should not be selectable")
if candidates["threaded_odirect"]["candidate_status"] != "ready":
    raise SystemExit("v61ax threaded O_DIRECT candidate should be ready")
if candidates["threaded_odirect"]["selectable"] != "1":
    raise SystemExit("v61ax threaded O_DIRECT candidate should be selectable")
if candidates["threaded_odirect"]["hash_match_rows"] != "15":
    raise SystemExit("v61ax threaded O_DIRECT hash match row mismatch")

if selection["selected_backend_id"] != "threaded_odirect":
    raise SystemExit("v61ax should select threaded O_DIRECT on current host")
if selection["selected_backend_ready"] != "1":
    raise SystemExit("v61ax selected backend should be ready")
if "io_uring_registered_buffer_blocked_by_io_uring_setup_errno_1_EPERM" not in selection["selection_reason"]:
    raise SystemExit("v61ax selection reason should bind EPERM blocker")
if selection["full_runtime_async_io_admission_ready"] != "0":
    raise SystemExit("v61ax must keep full runtime async-I/O admission blocked")

if policies["prefer-io-uring-registered-buffer"]["status"] != "blocked":
    raise SystemExit("v61ax preferred io_uring policy should be blocked")
if policies["fallback-threaded-odirect-when-io-uring-blocked"]["status"] != "pass":
    raise SystemExit("v61ax threaded O_DIRECT fallback policy should pass")
if policies["keep-production-claim-blocked"]["status"] != "blocked":
    raise SystemExit("v61ax production claim policy should remain blocked")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ax metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61aw-preflight-input",
    "v61av-threaded-odirect-input",
    "selected-async-io-backend",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ax requirement should pass: {requirement_id}")
for requirement_id in [
    "io-uring-registered-buffer-preferred-backend",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ax requirement should remain blocked: {requirement_id}")

for gate in [
    "v61aw-io-uring-preflight-input",
    "v61av-threaded-odirect-input",
    "selected-async-io-backend",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ax gate should pass: {gate}")
for gate in [
    "io-uring-registered-buffer-backend",
    "registered-buffer-prefetch",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ax gate should remain blocked: {gate}")

for gap in [
    "v61aw-io-uring-preflight-input",
    "v61av-threaded-odirect-input",
    "selected-threaded-odirect-backend",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ax gap should be ready: {gap}")
for gap in [
    "io-uring-registered-buffer-backend",
    "registered-buffer-prefetch",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ax gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ax_async_io_backend_selection_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ax_async_io_backend_selection_gate_ready") != 1:
    raise SystemExit("v61ax manifest readiness mismatch")
if manifest.get("selected_async_io_backend") != "threaded_odirect":
    raise SystemExit("v61ax manifest selected backend mismatch")
if manifest.get("selected_backend_hash_match_rows") != 15:
    raise SystemExit("v61ax manifest hash rows mismatch")
if manifest.get("io_uring_registered_buffer_candidate_ready") != 0:
    raise SystemExit("v61ax manifest should keep io_uring candidate blocked")
if manifest.get("full_runtime_async_io_admission_ready") != 0:
    raise SystemExit("v61ax manifest must keep full runtime blocked")

boundary = (run_dir / "V61AX_ASYNC_IO_BACKEND_SELECTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_async_io_backend=threaded_odirect",
    "selected_backend_ready=1",
    "selected_backend_queue_depth=4",
    "selected_backend_hash_match_rows=15",
    "io_uring_registered_buffer_candidate_ready=0",
    "actual_io_uring_execution_ready=0",
    "registered_buffer_prefetch_ready=0",
    "threaded_odirect_candidate_ready=1",
    "full_runtime_async_io_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ax=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ax boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ax sha256 mismatch: {rel}")
PY

echo "v61ax async-I/O backend selection gate smoke passed"
