#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ay_selected_backend_token_runtime_binding/binding_001"
SUMMARY_CSV="$RESULTS_DIR/v61ay_selected_backend_token_runtime_binding_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ay_selected_backend_token_runtime_binding_decision.csv"

V61AY_REUSE_EXISTING="${V61AY_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ay_selected_backend_token_runtime_binding.sh" >/dev/null

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
    "v61ay_selected_backend_token_runtime_binding_ready": "1",
    "v61ad_kv_weight_token_budget_replay_ready": "1",
    "v61ax_async_io_backend_selection_gate_ready": "1",
    "selected_async_io_backend": "threaded_odirect",
    "selected_backend_ready": "1",
    "selected_backend_queue_depth": "4",
    "selected_backend_hash_match_rows": "15",
    "selected_backend_error_rows": "0",
    "source_bound_query_rows": "37",
    "source_bound_token_budget_rows": "37",
    "kv_context_profile_rows": "5",
    "combined_kv_weight_budget_rows": "185",
    "selected_backend_bound_token_rows": "185",
    "selected_backend_bound_context_rows": "5",
    "full_kv_vram_budget_pass_rows": "74",
    "nvme_eviction_required_rows": "111",
    "host_ram_spill_bytes_total": "0",
    "total_selected_backend_token_ssd_read_bytes": "1551892480",
    "total_selected_backend_weight_plus_new_kv_bytes": "1594327040",
    "total_selected_backend_kv_bytes": "42434560",
    "max_context_tokens": "8192",
    "max_token_direct_io_latency_ms_p95": "3.826760",
    "steady_state_selected_backend_ready": "1",
    "bootstrap_prefetch_admission_ready": "0",
    "actual_io_uring_execution_ready": "0",
    "registered_buffer_prefetch_ready": "0",
    "full_runtime_async_io_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ay": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ay {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "selected_backend_token_runtime_binding_rows.csv",
    "selected_backend_context_runtime_binding_rows.csv",
    "selected_backend_runtime_requirement_rows.csv",
    "selected_backend_runtime_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AY_SELECTED_BACKEND_TOKEN_RUNTIME_BINDING_BOUNDARY.md",
    "v61ay_selected_backend_token_runtime_binding_manifest.json",
    "sha256_manifest.csv",
    "source_v61ad/kv_weight_token_budget_rows.csv",
    "source_v61ax/async_io_backend_selection_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ay artifact: {rel}")

bindings = read_csv(run_dir / "selected_backend_token_runtime_binding_rows.csv")
contexts = read_csv(run_dir / "selected_backend_context_runtime_binding_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "selected_backend_runtime_requirement_rows.csv")}
metric = read_csv(run_dir / "selected_backend_runtime_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(bindings) != 185:
    raise SystemExit("v61ay should emit 185 token runtime binding rows")
if len(contexts) != 5:
    raise SystemExit("v61ay should emit 5 context runtime binding rows")
if len({row["query_id"] for row in bindings}) != 37:
    raise SystemExit("v61ay query coverage mismatch")
if len({row["token_budget_id"] for row in bindings}) != 37:
    raise SystemExit("v61ay token budget coverage mismatch")
if any(row["selected_async_io_backend"] != "threaded_odirect" for row in bindings):
    raise SystemExit("v61ay should bind every row to threaded_odirect")
if any(row["selected_backend_token_binding_ready"] != "1" for row in bindings):
    raise SystemExit("v61ay every token row should bind to selected backend")
if any(row["full_runtime_async_io_admission_ready"] != "0" for row in bindings):
    raise SystemExit("v61ay must keep full runtime async-I/O admission blocked")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in bindings):
    raise SystemExit("v61ay must not commit checkpoint payload bytes")
if any(row["actual_model_generation_ready"] != "0" for row in bindings):
    raise SystemExit("v61ay must not claim model generation")
if sum(row["full_kv_vram_budget_pass"] == "1" for row in bindings) != 74:
    raise SystemExit("v61ay full KV VRAM pass row mismatch")
if sum(row["kv_nvme_eviction_required"] == "1" for row in bindings) != 111:
    raise SystemExit("v61ay NVMe eviction row mismatch")
if sum(int(row["host_ram_spill_bytes"]) for row in bindings) != 0:
    raise SystemExit("v61ay host RAM spill should stay zero")

expected_context_rows = {
    "context_512": ("512", "37", "37", "0"),
    "context_1024": ("1024", "37", "37", "0"),
    "context_2048": ("2048", "37", "0", "37"),
    "context_4096": ("4096", "37", "0", "37"),
    "context_8192": ("8192", "37", "0", "37"),
}
for row in contexts:
    expected_context = expected_context_rows.get(row["context_profile_id"])
    if expected_context is None:
        raise SystemExit(f"unexpected v61ay context: {row['context_profile_id']}")
    context_tokens, bound_rows, full_kv_rows, eviction_rows = expected_context
    if row["context_tokens"] != context_tokens:
        raise SystemExit(f"v61ay context token mismatch: {row['context_profile_id']}")
    if row["bound_token_rows"] != bound_rows:
        raise SystemExit(f"v61ay context bound row mismatch: {row['context_profile_id']}")
    if row["full_kv_vram_budget_pass_rows"] != full_kv_rows:
        raise SystemExit(f"v61ay full KV context row mismatch: {row['context_profile_id']}")
    if row["kv_nvme_eviction_required_rows"] != eviction_rows:
        raise SystemExit(f"v61ay eviction context row mismatch: {row['context_profile_id']}")
    if row["context_backend_binding_ready"] != "1":
        raise SystemExit(f"v61ay context should be binding-ready: {row['context_profile_id']}")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ay metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61ad-kv-weight-token-budget-input",
    "v61ax-selected-backend-input",
    "selected-backend-token-binding",
    "host-ram-spill-guard",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ay requirement should pass: {requirement_id}")
for requirement_id in [
    "io-uring-registered-buffer-prefetch",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ay requirement should remain blocked: {requirement_id}")

for gate in [
    "v61ad-kv-weight-token-budget-input",
    "v61ax-selected-backend-input",
    "selected-backend-token-binding",
    "host-ram-spill-guard",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ay gate should pass: {gate}")
for gate in [
    "io-uring-registered-buffer-prefetch",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ay gate should remain blocked: {gate}")

for gap in [
    "v61ad-kv-weight-token-budget-input",
    "v61ax-selected-backend-input",
    "selected-backend-token-binding",
    "selected-backend-context-binding",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ay gap should be ready: {gap}")
for gap in [
    "io-uring-registered-buffer-prefetch",
    "bootstrap-prefetch-admission",
    "full-runtime-async-io-admission",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ay gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ay_selected_backend_token_runtime_binding_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ay_selected_backend_token_runtime_binding_ready") != 1:
    raise SystemExit("v61ay manifest readiness mismatch")
if manifest.get("selected_async_io_backend") != "threaded_odirect":
    raise SystemExit("v61ay manifest selected backend mismatch")
if manifest.get("combined_kv_weight_budget_rows") != 185:
    raise SystemExit("v61ay manifest combined row mismatch")
if manifest.get("selected_backend_bound_token_rows") != 185:
    raise SystemExit("v61ay manifest binding row mismatch")
if manifest.get("full_runtime_async_io_admission_ready") != 0:
    raise SystemExit("v61ay manifest must keep full runtime blocked")

boundary = (run_dir / "V61AY_SELECTED_BACKEND_TOKEN_RUNTIME_BINDING_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_async_io_backend=threaded_odirect",
    "selected_backend_ready=1",
    "selected_backend_queue_depth=4",
    "source_bound_query_rows=37",
    "combined_kv_weight_budget_rows=185",
    "selected_backend_bound_token_rows=185",
    "full_kv_vram_budget_pass_rows=74",
    "nvme_eviction_required_rows=111",
    "host_ram_spill_bytes_total=0",
    "full_runtime_async_io_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ay=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ay boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ay sha256 mismatch: {rel}")
PY

echo "v61ay selected-backend token runtime binding smoke passed"
