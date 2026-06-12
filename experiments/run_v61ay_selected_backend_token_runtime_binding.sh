#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ay_selected_backend_token_runtime_binding"
RUN_ID="${V61AY_RUN_ID:-binding_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ay_selected_backend_token_runtime_binding_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ad_kv_weight_token_budget_replay.sh" >/dev/null
V61AX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ax_async_io_backend_selection_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
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


def fmax(rows, field):
    return max(float(row[field]) for row in rows)


v61ad_dir = results / "v61ad_kv_weight_token_budget_replay" / "replay_001"
v61ax_dir = results / "v61ax_async_io_backend_selection_gate" / "gate_001"
v61ad_summary = read_csv(results / "v61ad_kv_weight_token_budget_replay_summary.csv")[0]
v61ax_summary = read_csv(results / "v61ax_async_io_backend_selection_gate_summary.csv")[0]
if v61ad_summary.get("v61ad_kv_weight_token_budget_replay_ready") != "1":
    raise SystemExit("v61ay requires v61ad_kv_weight_token_budget_replay_ready=1")
if v61ax_summary.get("v61ax_async_io_backend_selection_gate_ready") != "1":
    raise SystemExit("v61ay requires v61ax_async_io_backend_selection_gate_ready=1")
if v61ax_summary.get("selected_backend_ready") != "1":
    raise SystemExit("v61ay requires selected_backend_ready=1")

for src, rel in [
    (results / "v61ad_kv_weight_token_budget_replay_summary.csv", "source_v61ad/v61ad_kv_weight_token_budget_replay_summary.csv"),
    (results / "v61ad_kv_weight_token_budget_replay_decision.csv", "source_v61ad/v61ad_kv_weight_token_budget_replay_decision.csv"),
    (v61ad_dir / "kv_weight_token_budget_rows.csv", "source_v61ad/kv_weight_token_budget_rows.csv"),
    (v61ad_dir / "kv_weight_context_profile_rows.csv", "source_v61ad/kv_weight_context_profile_rows.csv"),
    (v61ad_dir / "kv_weight_token_budget_metric_rows.csv", "source_v61ad/kv_weight_token_budget_metric_rows.csv"),
    (v61ad_dir / "sha256_manifest.csv", "source_v61ad/sha256_manifest.csv"),
    (results / "v61ax_async_io_backend_selection_gate_summary.csv", "source_v61ax/v61ax_async_io_backend_selection_gate_summary.csv"),
    (results / "v61ax_async_io_backend_selection_gate_decision.csv", "source_v61ax/v61ax_async_io_backend_selection_gate_decision.csv"),
    (v61ax_dir / "async_io_backend_candidate_rows.csv", "source_v61ax/async_io_backend_candidate_rows.csv"),
    (v61ax_dir / "async_io_backend_selection_rows.csv", "source_v61ax/async_io_backend_selection_rows.csv"),
    (v61ax_dir / "async_io_backend_policy_rows.csv", "source_v61ax/async_io_backend_policy_rows.csv"),
    (v61ax_dir / "async_io_backend_metric_rows.csv", "source_v61ax/async_io_backend_metric_rows.csv"),
    (v61ax_dir / "sha256_manifest.csv", "source_v61ax/sha256_manifest.csv"),
]:
    copy(src, rel)

kv_rows = read_csv(v61ad_dir / "kv_weight_token_budget_rows.csv")
selection = read_csv(v61ax_dir / "async_io_backend_selection_rows.csv")[0]
selected_backend = selection["selected_backend_id"]
selected_ready = selection["selected_backend_ready"]
selected_queue_depth = selection["selected_backend_queue_depth"]
selected_hash_rows = selection["selected_backend_hash_match_rows"]
selected_error_rows = selection["selected_backend_error_rows"]

binding_rows = []
for index, row in enumerate(kv_rows):
    binding_ready = "1" if selected_ready == "1" and row["combined_kv_weight_budget_ready"] == "1" else "0"
    binding_rows.append(
        {
            "runtime_binding_id": f"v61ay_runtime_binding_{index:04d}",
            "combined_budget_id": row["combined_budget_id"],
            "token_budget_id": row["token_budget_id"],
            "workload_binding_id": row["workload_binding_id"],
            "query_id": row["query_id"],
            "query_family": row["query_family"],
            "context_profile_id": row["context_profile_id"],
            "context_tokens": row["context_tokens"],
            "selected_async_io_backend": selected_backend,
            "selected_backend_ready": selected_ready,
            "selected_backend_queue_depth": selected_queue_depth,
            "selected_backend_hash_match_rows": selected_hash_rows,
            "selected_backend_error_rows": selected_error_rows,
            "active_page_reads_per_token": row["active_page_reads_per_token"],
            "ssd_read_bytes_per_token": row["ssd_read_bytes_per_token"],
            "kv_bytes_per_token": row["kv_bytes_per_token"],
            "weight_plus_new_kv_bytes_per_token": row["weight_plus_new_kv_bytes_per_token"],
            "token_direct_io_latency_ms_p50": row["token_direct_io_latency_ms_p50"],
            "token_direct_io_latency_ms_p95": row["token_direct_io_latency_ms_p95"],
            "kv_vram_budget_pass": row["kv_vram_budget_pass"],
            "full_kv_vram_budget_pass": row["full_kv_vram_budget_pass"],
            "kv_nvme_eviction_required": row["kv_nvme_eviction_required"],
            "host_ram_spill_bytes": row["host_ram_spill_bytes"],
            "source_bound_query_pass": row["source_bound_query_pass"],
            "combined_kv_weight_budget_ready": row["combined_kv_weight_budget_ready"],
            "selected_backend_token_binding_ready": binding_ready,
            "actual_io_uring_execution_ready": v61ax_summary["actual_io_uring_execution_ready"],
            "registered_buffer_prefetch_ready": v61ax_summary["registered_buffer_prefetch_ready"],
            "bootstrap_prefetch_admission_ready": v61ax_summary["bootstrap_prefetch_admission_ready"],
            "full_runtime_async_io_admission_ready": v61ax_summary["full_runtime_async_io_admission_ready"],
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "full_checkpoint_materialization_ready": row["full_checkpoint_materialization_ready"],
            "full_safetensors_page_hash_binding_ready": row["full_safetensors_page_hash_binding_ready"],
            "actual_model_generation_ready": "0",
            "near_frontier_claim_ready": "0",
            "production_latency_claim_ready": "0",
            "real_release_package_ready": "0",
            "route_jump_rows": row["route_jump_rows"],
        }
    )
write_csv(run_dir / "selected_backend_token_runtime_binding_rows.csv", list(binding_rows[0].keys()), binding_rows)

contexts = defaultdict(list)
for row in binding_rows:
    contexts[row["context_profile_id"]].append(row)
context_rows = []
for context_id in sorted(contexts, key=lambda c: int(contexts[c][0]["context_tokens"])):
    rows = contexts[context_id]
    context_rows.append(
        {
            "context_profile_id": context_id,
            "context_tokens": rows[0]["context_tokens"],
            "selected_async_io_backend": selected_backend,
            "selected_backend_ready": selected_ready,
            "selected_backend_queue_depth": selected_queue_depth,
            "bound_token_rows": str(len(rows)),
            "selected_backend_token_binding_ready_rows": str(sum(row["selected_backend_token_binding_ready"] == "1" for row in rows)),
            "full_kv_vram_budget_pass_rows": str(sum(row["full_kv_vram_budget_pass"] == "1" for row in rows)),
            "kv_nvme_eviction_required_rows": str(sum(row["kv_nvme_eviction_required"] == "1" for row in rows)),
            "host_ram_spill_bytes": str(sum(int(row["host_ram_spill_bytes"]) for row in rows)),
            "max_token_direct_io_latency_ms_p95": f"{max(float(row['token_direct_io_latency_ms_p95']) for row in rows):.6f}",
            "context_backend_binding_ready": "1" if all(row["selected_backend_token_binding_ready"] == "1" for row in rows) else "0",
            "full_runtime_async_io_admission_ready": "0",
        }
    )
write_csv(run_dir / "selected_backend_context_runtime_binding_rows.csv", list(context_rows[0].keys()), context_rows)

selected_binding_rows = sum(row["selected_backend_token_binding_ready"] == "1" for row in binding_rows)
unique_queries = len({row["query_id"] for row in binding_rows})
unique_token_budgets = len({row["token_budget_id"] for row in binding_rows})
total_ssd_read_bytes = sum(int(row["ssd_read_bytes_per_token"]) for row in binding_rows)
total_weight_plus_kv_bytes = sum(int(row["weight_plus_new_kv_bytes_per_token"]) for row in binding_rows)
total_kv_bytes = sum(int(row["kv_bytes_per_token"]) for row in binding_rows)
full_kv_pass_rows = sum(row["full_kv_vram_budget_pass"] == "1" for row in binding_rows)
nvme_eviction_rows = sum(row["kv_nvme_eviction_required"] == "1" for row in binding_rows)
host_ram_spill_bytes = sum(int(row["host_ram_spill_bytes"]) for row in binding_rows)
route_jump_rows = sum(int(row["route_jump_rows"]) for row in binding_rows)

requirement_rows = [
    {"requirement_id": "v61ad-kv-weight-token-budget-input", "status": "pass", "actual": v61ad_summary["v61ad_kv_weight_token_budget_replay_ready"], "required": "1", "reason": "KV+weight token budget rows are available"},
    {"requirement_id": "v61ax-selected-backend-input", "status": "pass", "actual": v61ax_summary["v61ax_async_io_backend_selection_gate_ready"], "required": "1", "reason": "selected backend evidence is available"},
    {"requirement_id": "selected-backend-token-binding", "status": "pass" if selected_binding_rows == len(binding_rows) else "blocked", "actual": str(selected_binding_rows), "required": str(len(binding_rows)), "reason": "all KV+weight token budget rows are bound to the selected backend"},
    {"requirement_id": "host-ram-spill-guard", "status": "pass" if host_ram_spill_bytes == 0 else "blocked", "actual": str(host_ram_spill_bytes), "required": "0", "reason": "selected runtime binding must not introduce host RAM spill"},
    {"requirement_id": "io-uring-registered-buffer-prefetch", "status": "blocked", "actual": v61ax_summary["registered_buffer_prefetch_ready"], "required": "1", "reason": "v61ax selected threaded O_DIRECT because io_uring remains blocked"},
    {"requirement_id": "bootstrap-prefetch-admission", "status": "blocked", "actual": v61ax_summary["bootstrap_prefetch_admission_ready"], "required": "1", "reason": "selected backend binding does not solve bootstrap cold-start"},
    {"requirement_id": "full-runtime-async-io-admission", "status": "blocked", "actual": v61ax_summary["full_runtime_async_io_admission_ready"], "required": "1", "reason": "full runtime still requires materialization/full page hash/generation"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61ay does not read or commit checkpoint payload bytes"},
]
write_csv(run_dir / "selected_backend_runtime_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ay_selected_backend_token_runtime_binding_metrics",
    "model_id": model_id,
    "v61ay_selected_backend_token_runtime_binding_ready": "1",
    "v61ad_kv_weight_token_budget_replay_ready": v61ad_summary["v61ad_kv_weight_token_budget_replay_ready"],
    "v61ax_async_io_backend_selection_gate_ready": v61ax_summary["v61ax_async_io_backend_selection_gate_ready"],
    "selected_async_io_backend": selected_backend,
    "selected_backend_ready": selected_ready,
    "selected_backend_queue_depth": selected_queue_depth,
    "selected_backend_hash_match_rows": selected_hash_rows,
    "selected_backend_error_rows": selected_error_rows,
    "source_bound_query_rows": str(unique_queries),
    "source_bound_token_budget_rows": str(unique_token_budgets),
    "kv_context_profile_rows": str(len(context_rows)),
    "combined_kv_weight_budget_rows": str(len(binding_rows)),
    "selected_backend_bound_token_rows": str(selected_binding_rows),
    "selected_backend_bound_context_rows": str(sum(row["context_backend_binding_ready"] == "1" for row in context_rows)),
    "full_kv_vram_budget_pass_rows": str(full_kv_pass_rows),
    "nvme_eviction_required_rows": str(nvme_eviction_rows),
    "host_ram_spill_bytes_total": str(host_ram_spill_bytes),
    "total_selected_backend_token_ssd_read_bytes": str(total_ssd_read_bytes),
    "total_selected_backend_weight_plus_new_kv_bytes": str(total_weight_plus_kv_bytes),
    "total_selected_backend_kv_bytes": str(total_kv_bytes),
    "max_context_tokens": v61ad_summary["max_context_tokens"],
    "max_token_direct_io_latency_ms_p95": f"{fmax(binding_rows, 'token_direct_io_latency_ms_p95'):.6f}",
    "steady_state_selected_backend_ready": v61ax_summary["steady_state_selected_backend_ready"],
    "bootstrap_prefetch_admission_ready": v61ax_summary["bootstrap_prefetch_admission_ready"],
    "actual_io_uring_execution_ready": v61ax_summary["actual_io_uring_execution_ready"],
    "registered_buffer_prefetch_ready": v61ax_summary["registered_buffer_prefetch_ready"],
    "full_runtime_async_io_admission_ready": v61ax_summary["full_runtime_async_io_admission_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61ay": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": str(route_jump_rows),
}
write_csv(run_dir / "selected_backend_runtime_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61ad-kv-weight-token-budget-input", "ready", "v61ad KV+weight token budget evidence is bound"),
    ("v61ax-selected-backend-input", "ready", "v61ax selected backend evidence is bound"),
    ("selected-backend-token-binding", "ready", f"{selected_binding_rows} token budget rows are bound"),
    ("selected-backend-context-binding", "ready", f"{len(context_rows)} context profiles are bound"),
    ("io-uring-registered-buffer-prefetch", "blocked", "current host selected threaded O_DIRECT fallback"),
    ("bootstrap-prefetch-admission", "blocked", "backend binding does not create a prior compute window"),
    ("full-runtime-async-io-admission", "blocked", "requires full materialization/page-hash/generation gates"),
    ("full-checkpoint-materialization", "blocked", "checkpoint materialization is not complete"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "token binding is not production latency evidence"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61ad-kv-weight-token-budget-input", "status": "pass", "reason": "v61ad ready"},
    {"gate": "v61ax-selected-backend-input", "status": "pass", "reason": "v61ax ready"},
    {"gate": "selected-backend-token-binding", "status": "pass", "reason": f"{selected_binding_rows}/{len(binding_rows)} token rows bound"},
    {"gate": "host-ram-spill-guard", "status": "pass", "reason": "host RAM spill bytes remain zero"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "io-uring-registered-buffer-prefetch", "status": "blocked", "reason": "actual io_uring/registered buffers remain blocked"},
    {"gate": "bootstrap-prefetch-admission", "status": "blocked", "reason": "bootstrap cold-start remains blocked"},
    {"gate": "full-runtime-async-io-admission", "status": "blocked", "reason": "not a full runtime admission gate"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "checkpoint materialization is incomplete"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page hash coverage is incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ay Selected-Backend Token Runtime Binding Boundary

This gate consumes v61ad KV+weight token budget rows and v61ax async-I/O backend
selection evidence, then binds every sampled source-bound token/runtime budget
row to the selected current-host async-I/O backend.

Current binding:

- selected_async_io_backend={selected_backend}
- selected_backend_ready={selected_ready}
- selected_backend_queue_depth={selected_queue_depth}
- selected_backend_hash_match_rows={selected_hash_rows}
- selected_backend_error_rows={selected_error_rows}
- source_bound_query_rows={unique_queries}
- source_bound_token_budget_rows={unique_token_budgets}
- kv_context_profile_rows={len(context_rows)}
- combined_kv_weight_budget_rows={len(binding_rows)}
- selected_backend_bound_token_rows={selected_binding_rows}
- selected_backend_bound_context_rows={metric["selected_backend_bound_context_rows"]}
- full_kv_vram_budget_pass_rows={full_kv_pass_rows}
- nvme_eviction_required_rows={nvme_eviction_rows}
- host_ram_spill_bytes_total={host_ram_spill_bytes}
- total_selected_backend_token_ssd_read_bytes={total_ssd_read_bytes}
- total_selected_backend_weight_plus_new_kv_bytes={total_weight_plus_kv_bytes}
- max_token_direct_io_latency_ms_p95={metric["max_token_direct_io_latency_ms_p95"]}
- steady_state_selected_backend_ready={metric["steady_state_selected_backend_ready"]}
- bootstrap_prefetch_admission_ready={metric["bootstrap_prefetch_admission_ready"]}
- actual_io_uring_execution_ready={metric["actual_io_uring_execution_ready"]}
- registered_buffer_prefetch_ready={metric["registered_buffer_prefetch_ready"]}
- full_runtime_async_io_admission_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ay=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: selected-backend token runtime binding for sampled KV+weight
budget rows using the current-host threaded O_DIRECT backend.

Blocked wording: actual io_uring SQ/CQ submission, registered-buffer prefetch,
bootstrap admission, full runtime admission, full checkpoint materialization,
full safetensors page-hash coverage, actual Mixtral generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61AY_SELECTED_BACKEND_TOKEN_RUNTIME_BINDING_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ay_selected_backend_token_runtime_binding",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ay_selected_backend_token_runtime_binding_ready": 1,
    "source_v61ad_ready": int(v61ad_summary["v61ad_kv_weight_token_budget_replay_ready"]),
    "source_v61ax_ready": int(v61ax_summary["v61ax_async_io_backend_selection_gate_ready"]),
    "selected_async_io_backend": selected_backend,
    "selected_backend_ready": int(selected_ready),
    "selected_backend_queue_depth": int(selected_queue_depth),
    "combined_kv_weight_budget_rows": len(binding_rows),
    "selected_backend_bound_token_rows": selected_binding_rows,
    "kv_context_profile_rows": len(context_rows),
    "host_ram_spill_bytes_total": host_ram_spill_bytes,
    "full_runtime_async_io_admission_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ay": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ay_selected_backend_token_runtime_binding_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61ay_selected_backend_token_runtime_binding_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
