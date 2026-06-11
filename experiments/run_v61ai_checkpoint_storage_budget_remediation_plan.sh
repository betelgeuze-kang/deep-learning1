#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ai_checkpoint_storage_budget_remediation_plan"
RUN_ID="${V61AI_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ai_checkpoint_storage_budget_remediation_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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


v61ah_dir = results / "v61ah_checkpoint_download_backend_fallback_plan" / "plan_001"
v61p_dir = results / "v61p_local_ssd_checkpoint_residency_preflight" / "preflight_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61ah_summary = read_csv(results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv")[0]
v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
v61w_summary = read_csv(results / "v61w_materialization_admission_resume_plan_summary.csv")[0]

if v61ah_summary.get("v61ah_checkpoint_download_backend_fallback_plan_ready") != "1":
    raise SystemExit("v61ai requires v61ah_checkpoint_download_backend_fallback_plan_ready=1")
if v61p_summary.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != "1":
    raise SystemExit("v61ai requires v61p_local_ssd_checkpoint_residency_preflight_ready=1")
if v61w_summary.get("v61w_materialization_admission_resume_plan_ready") != "1":
    raise SystemExit("v61ai requires v61w_materialization_admission_resume_plan_ready=1")

for src, rel in [
    (results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv", "source_v61ah/v61ah_checkpoint_download_backend_fallback_plan_summary.csv"),
    (results / "v61ah_checkpoint_download_backend_fallback_plan_decision.csv", "source_v61ah/v61ah_checkpoint_download_backend_fallback_plan_decision.csv"),
    (v61ah_dir / "checkpoint_download_backend_candidate_rows.csv", "source_v61ah/checkpoint_download_backend_candidate_rows.csv"),
    (v61ah_dir / "checkpoint_download_backend_plan_rows.csv", "source_v61ah/checkpoint_download_backend_plan_rows.csv"),
    (v61ah_dir / "checkpoint_download_backend_metric_rows.csv", "source_v61ah/checkpoint_download_backend_metric_rows.csv"),
    (v61ah_dir / "sha256_manifest.csv", "source_v61ah/sha256_manifest.csv"),
    (results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    (v61p_dir / "checkpoint_residency_requirement_rows.csv", "source_v61p/checkpoint_residency_requirement_rows.csv"),
    (v61p_dir / "ssd_disk_budget_rows.csv", "source_v61p/ssd_disk_budget_rows.csv"),
    (v61p_dir / "checkpoint_download_plan_rows.csv", "source_v61p/checkpoint_download_plan_rows.csv"),
    (v61p_dir / "local_shard_presence_rows.csv", "source_v61p/local_shard_presence_rows.csv"),
    (v61p_dir / "sha256_manifest.csv", "source_v61p/sha256_manifest.csv"),
    (results / "v61w_materialization_admission_resume_plan_summary.csv", "source_v61w/v61w_materialization_admission_resume_plan_summary.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "materialization_admission_metric_rows.csv", "source_v61w/materialization_admission_metric_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(priority_rows) != 59:
    raise SystemExit("v61ai expects 59 v61w priority rows")

total_checkpoint_bytes = int(v61p_summary["total_checkpoint_bytes_required"])
reserve_bytes = int(v61p_summary["ssd_reserve_bytes"])
required_with_reserve = int(v61p_summary["required_with_reserve_bytes"])
available_bytes = int(v61p_summary["available_ssd_bytes"])
available_after_reserve = max(available_bytes - reserve_bytes, 0)
full_budget_deficit = max(required_with_reserve - available_bytes, 0)
raw_checkpoint_deficit = max(total_checkpoint_bytes - available_bytes, 0)
safe_batch_rows = 0
safe_batch_bytes = 0

candidate_rows = []
cumulative = 0
for row in sorted(priority_rows, key=lambda item: int(item["priority_rank"])):
    expected_bytes = int(row["expected_bytes"])
    if cumulative + expected_bytes > available_bytes:
        break
    cumulative += expected_bytes
    candidate = {
        "priority_rank": row["priority_rank"],
        "model_id": model_id,
        "shard_name": row["shard_name"],
        "priority_class": row["priority_class"],
        "expected_bytes": row["expected_bytes"],
        "cumulative_bytes": str(cumulative),
        "selected_backend_id": v61ah_summary["selected_backend_id"],
        "fits_current_available_without_reserve": "1",
        "admitted_under_reserve_policy": "0",
        "blocked_reason": "reserve-policy-not-satisfied",
        "checkpoint_payload_bytes_downloaded_by_v61ai": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    candidate_rows.append(candidate)

no_reserve_candidate_shard_rows = len(candidate_rows)
no_reserve_candidate_bytes = cumulative

remediation_rows = [
    {
        "remediation_id": "full-checkpoint-with-reserve",
        "status": "blocked",
        "required_bytes": str(required_with_reserve),
        "available_bytes": str(available_bytes),
        "deficit_bytes": str(full_budget_deficit),
        "safe_for_execution": "0",
        "reason": "current SSD budget cannot hold full checkpoint plus reserve",
    },
    {
        "remediation_id": "raw-checkpoint-without-reserve",
        "status": "blocked",
        "required_bytes": str(total_checkpoint_bytes),
        "available_bytes": str(available_bytes),
        "deficit_bytes": str(raw_checkpoint_deficit),
        "safe_for_execution": "0",
        "reason": "raw checkpoint bytes exceed current available SSD bytes and reserve policy would be violated",
    },
    {
        "remediation_id": "current-safe-reserve-batch",
        "status": "blocked",
        "required_bytes": "1",
        "available_bytes": str(available_after_reserve),
        "deficit_bytes": str(1 if available_after_reserve == 0 else 0),
        "safe_for_execution": "0",
        "reason": "current available bytes are below configured reserve, so no safe shard batch is admitted",
    },
    {
        "remediation_id": "diagnostic-no-reserve-top-priority-batch",
        "status": "diagnostic-only",
        "required_bytes": str(no_reserve_candidate_bytes),
        "available_bytes": str(available_bytes),
        "deficit_bytes": "0",
        "safe_for_execution": "0",
        "reason": "top-priority shards fit only if reserve policy is ignored; execution remains blocked",
    },
    {
        "remediation_id": "attach-or-free-additional-storage",
        "status": "required",
        "required_bytes": str(full_budget_deficit),
        "available_bytes": str(available_bytes),
        "deficit_bytes": str(full_budget_deficit),
        "safe_for_execution": "0",
        "reason": "attach or free at least the full budget deficit before full materialization admission",
    },
]

batch_rows = [
    {
        "batch_id": "full-checkpoint-reserve-policy",
        "batch_kind": "full-materialization",
        "shard_rows": "59",
        "batch_checkpoint_bytes": str(total_checkpoint_bytes),
        "reserve_bytes": str(reserve_bytes),
        "required_bytes": str(required_with_reserve),
        "available_bytes": str(available_bytes),
        "admitted_by_policy": "0",
        "blocked_reason": "ssd-budget-deficit",
    },
    {
        "batch_id": "current-safe-reserve-batch",
        "batch_kind": "safe-partial-materialization",
        "shard_rows": str(safe_batch_rows),
        "batch_checkpoint_bytes": str(safe_batch_bytes),
        "reserve_bytes": str(reserve_bytes),
        "required_bytes": str(reserve_bytes + safe_batch_bytes),
        "available_bytes": str(available_bytes),
        "admitted_by_policy": "0",
        "blocked_reason": "available-below-reserve",
    },
    {
        "batch_id": "diagnostic-no-reserve-top-priority-batch",
        "batch_kind": "diagnostic-no-reserve",
        "shard_rows": str(no_reserve_candidate_shard_rows),
        "batch_checkpoint_bytes": str(no_reserve_candidate_bytes),
        "reserve_bytes": "0",
        "required_bytes": str(no_reserve_candidate_bytes),
        "available_bytes": str(available_bytes),
        "admitted_by_policy": "0",
        "blocked_reason": "reserve-policy-not-satisfied",
    },
]

metric = {
    "metric_id": "v61ai_checkpoint_storage_budget_remediation_metrics",
    "model_id": model_id,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
    "ssd_reserve_bytes": str(reserve_bytes),
    "required_with_reserve_bytes": str(required_with_reserve),
    "available_ssd_bytes": str(available_bytes),
    "available_after_reserve_bytes": str(available_after_reserve),
    "full_budget_deficit_bytes": str(full_budget_deficit),
    "raw_checkpoint_deficit_bytes": str(raw_checkpoint_deficit),
    "safe_materialization_batch_rows": str(safe_batch_rows),
    "safe_materialization_batch_bytes": str(safe_batch_bytes),
    "no_reserve_candidate_shard_rows": str(no_reserve_candidate_shard_rows),
    "no_reserve_candidate_bytes": str(no_reserve_candidate_bytes),
    "selected_backend_id": v61ah_summary["selected_backend_id"],
    "download_backend_ready": v61ah_summary["selected_backend_ready"],
    "download_execution_ready": "0",
    "storage_budget_remediation_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "generation_admitted_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ai": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_storage_budget_remediation_rows.csv", list(remediation_rows[0].keys()), remediation_rows)
write_csv(run_dir / "checkpoint_materialization_batch_rows.csv", list(batch_rows[0].keys()), batch_rows)
write_csv(run_dir / "checkpoint_no_reserve_candidate_shard_rows.csv", list(candidate_rows[0].keys()), candidate_rows)
write_csv(run_dir / "checkpoint_storage_budget_metric_rows.csv", list(metric.keys()), [metric])

decision_rows = [
    {"gate": "v61ah-download-backend-input", "status": "pass", "reason": "v61ah backend fallback plan is ready"},
    {"gate": "storage-budget-accounting", "status": "pass", "reason": "current available, required, reserve, and deficit bytes are recorded"},
    {"gate": "diagnostic-no-reserve-candidate-batch", "status": "pass", "reason": "top-priority no-reserve candidate batch is bounded and marked diagnostic-only"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ai emits metadata only"},
    {"gate": "full-checkpoint-storage-budget", "status": "blocked", "reason": f"deficit_bytes={full_budget_deficit}"},
    {"gate": "safe-partial-download-batch", "status": "blocked", "reason": "available bytes are below configured reserve"},
    {"gate": "download-execution", "status": "blocked", "reason": "storage budget remediation is not ready"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "storage budget remediation is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "storage budget remediation is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61ai_checkpoint_storage_budget_remediation_plan_ready": "1",
    "v61ah_checkpoint_download_backend_fallback_plan_ready": v61ah_summary["v61ah_checkpoint_download_backend_fallback_plan_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61ai Checkpoint Storage Budget Remediation Plan Boundary

This artifact quantifies the remaining SSD storage blocker for full Mixtral
checkpoint materialization. It does not download checkpoint payload bytes.

Evidence emitted:

- total_checkpoint_bytes_required={total_checkpoint_bytes}
- ssd_reserve_bytes={reserve_bytes}
- required_with_reserve_bytes={required_with_reserve}
- available_ssd_bytes={available_bytes}
- available_after_reserve_bytes={available_after_reserve}
- full_budget_deficit_bytes={full_budget_deficit}
- raw_checkpoint_deficit_bytes={raw_checkpoint_deficit}
- safe_materialization_batch_rows={safe_batch_rows}
- no_reserve_candidate_shard_rows={no_reserve_candidate_shard_rows}
- no_reserve_candidate_bytes={no_reserve_candidate_bytes}
- selected_backend_id={v61ah_summary['selected_backend_id']}
- storage_budget_remediation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ai=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_checkpoint_storage_budget=blocked
- safe_partial_download_batch=blocked
- download_execution_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AI_CHECKPOINT_STORAGE_BUDGET_REMEDIATION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ai_checkpoint_storage_budget_remediation_plan",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ai_checkpoint_storage_budget_remediation_plan_ready": 1,
    "full_budget_deficit_bytes": full_budget_deficit,
    "safe_materialization_batch_rows": safe_batch_rows,
    "no_reserve_candidate_shard_rows": no_reserve_candidate_shard_rows,
    "storage_budget_remediation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ai": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ai_checkpoint_storage_budget_remediation_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ai_checkpoint_storage_budget_remediation_plan_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
