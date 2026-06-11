#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61aj_checkpoint_storage_profile_admission_matrix"
RUN_ID="${V61AJ_RUN_ID:-matrix_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61aj_checkpoint_storage_profile_admission_matrix_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ai_checkpoint_storage_budget_remediation_plan.sh" >/dev/null

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
gib = 1024 ** 3


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


v61ai_dir = results / "v61ai_checkpoint_storage_budget_remediation_plan" / "plan_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61ai_summary = read_csv(results / "v61ai_checkpoint_storage_budget_remediation_plan_summary.csv")[0]
if v61ai_summary.get("v61ai_checkpoint_storage_budget_remediation_plan_ready") != "1":
    raise SystemExit("v61aj requires v61ai_checkpoint_storage_budget_remediation_plan_ready=1")

priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(priority_rows) != 59:
    raise SystemExit("v61aj expects 59 v61w checkpoint shard priority rows")

for src, rel in [
    (results / "v61ai_checkpoint_storage_budget_remediation_plan_summary.csv", "source_v61ai/v61ai_checkpoint_storage_budget_remediation_plan_summary.csv"),
    (results / "v61ai_checkpoint_storage_budget_remediation_plan_decision.csv", "source_v61ai/v61ai_checkpoint_storage_budget_remediation_plan_decision.csv"),
    (v61ai_dir / "checkpoint_storage_budget_remediation_rows.csv", "source_v61ai/checkpoint_storage_budget_remediation_rows.csv"),
    (v61ai_dir / "checkpoint_materialization_batch_rows.csv", "source_v61ai/checkpoint_materialization_batch_rows.csv"),
    (v61ai_dir / "checkpoint_no_reserve_candidate_shard_rows.csv", "source_v61ai/checkpoint_no_reserve_candidate_shard_rows.csv"),
    (v61ai_dir / "checkpoint_storage_budget_metric_rows.csv", "source_v61ai/checkpoint_storage_budget_metric_rows.csv"),
    (v61ai_dir / "sha256_manifest.csv", "source_v61ai/sha256_manifest.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

total_checkpoint_bytes = int(v61ai_summary["total_checkpoint_bytes_required"])
reserve_bytes = int(v61ai_summary["ssd_reserve_bytes"])
required_with_reserve = int(v61ai_summary["required_with_reserve_bytes"])
current_available_bytes = int(v61ai_summary["available_ssd_bytes"])
full_budget_deficit = int(v61ai_summary["full_budget_deficit_bytes"])
raw_checkpoint_deficit = int(v61ai_summary["raw_checkpoint_deficit_bytes"])
selected_backend_id = v61ai_summary["selected_backend_id"]
operator_512gib_free_bytes = 512 * gib
operator_1tib_free_bytes = 1024 * gib


def admitted_for_budget(budget_bytes):
    rows = 0
    total = 0
    for row in sorted(priority_rows, key=lambda item: int(item["priority_rank"])):
        expected = int(row["expected_bytes"])
        if total + expected > budget_bytes:
            break
        total += expected
        rows += 1
    return rows, total


profile_specs = [
    {
        "profile_id": "current-host-reserve-policy",
        "profile_kind": "observed-current-reserve",
        "available_bytes": current_available_bytes,
        "effective_reserve_bytes": reserve_bytes,
        "recommended_action": "free-or-attach-storage-before-download",
    },
    {
        "profile_id": "current-host-no-reserve-diagnostic",
        "profile_kind": "observed-current-diagnostic",
        "available_bytes": current_available_bytes,
        "effective_reserve_bytes": 0,
        "recommended_action": "diagnostic-only-do-not-download",
    },
    {
        "profile_id": "raw-checkpoint-exact-no-reserve",
        "profile_kind": "minimum-unsafe-raw",
        "available_bytes": total_checkpoint_bytes,
        "effective_reserve_bytes": 0,
        "recommended_action": "unsafe-without-reserve-do-not-use-for-full-run",
    },
    {
        "profile_id": "full-checkpoint-exact-with-reserve",
        "profile_kind": "minimum-safe-full",
        "available_bytes": required_with_reserve,
        "effective_reserve_bytes": reserve_bytes,
        "recommended_action": "minimum-safe-full-materialization-profile",
    },
    {
        "profile_id": "operator-512gib-free-profile",
        "profile_kind": "operator-margin",
        "available_bytes": operator_512gib_free_bytes,
        "effective_reserve_bytes": reserve_bytes,
        "recommended_action": "preferred-minimum-operator-profile",
    },
    {
        "profile_id": "operator-1tib-free-profile",
        "profile_kind": "operator-headroom",
        "available_bytes": operator_1tib_free_bytes,
        "effective_reserve_bytes": reserve_bytes,
        "recommended_action": "preferred-headroom-profile",
    },
]

profile_rows = []
for spec in profile_specs:
    available = int(spec["available_bytes"])
    effective_reserve = int(spec["effective_reserve_bytes"])
    usable = max(available - effective_reserve, 0)
    admitted_rows, admitted_bytes = admitted_for_budget(usable)
    admitted_rows_no_reserve, admitted_bytes_no_reserve = admitted_for_budget(available)
    full_by_profile_policy = int(usable >= total_checkpoint_bytes)
    full_without_reserve = int(available >= total_checkpoint_bytes)
    post_full_free = max(available - total_checkpoint_bytes, 0) if full_without_reserve else 0
    reserve_satisfied_after_full = int(post_full_free >= reserve_bytes and full_without_reserve)
    if full_by_profile_policy and effective_reserve == reserve_bytes:
        execution_status = "admit-after-storage-profile"
        blocked_reason = "none"
    elif spec["profile_id"] == "current-host-no-reserve-diagnostic":
        execution_status = "diagnostic-only"
        blocked_reason = "reserve-policy-not-satisfied"
    elif full_without_reserve and reserve_satisfied_after_full == 0:
        execution_status = "blocked-unsafe-without-reserve"
        blocked_reason = "reserve-policy-not-satisfied"
    else:
        execution_status = "blocked-storage-budget"
        blocked_reason = "ssd-budget-deficit"
    profile_rows.append({
        "profile_id": spec["profile_id"],
        "profile_kind": spec["profile_kind"],
        "model_id": model_id,
        "available_bytes": str(available),
        "effective_reserve_bytes": str(effective_reserve),
        "usable_for_checkpoint_bytes": str(usable),
        "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
        "required_with_configured_reserve_bytes": str(required_with_reserve),
        "additional_bytes_from_current": str(max(available - current_available_bytes, 0)),
        "admitted_shard_rows_under_profile_policy": str(admitted_rows),
        "admitted_shard_bytes_under_profile_policy": str(admitted_bytes),
        "admitted_shard_rows_without_reserve": str(admitted_rows_no_reserve),
        "admitted_shard_bytes_without_reserve": str(admitted_bytes_no_reserve),
        "full_checkpoint_admitted_by_profile_policy": str(full_by_profile_policy),
        "full_checkpoint_admitted_without_reserve": str(full_without_reserve),
        "post_full_materialization_free_bytes": str(post_full_free),
        "configured_reserve_satisfied_after_full": str(reserve_satisfied_after_full),
        "selected_backend_id": selected_backend_id,
        "execution_admission_status": execution_status,
        "blocked_reason": blocked_reason,
        "recommended_action": spec["recommended_action"],
        "checkpoint_payload_bytes_downloaded_by_v61aj": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    })

requirement_rows = [
    {
        "requirement_id": "current-host-full-reserve-deficit",
        "status": "blocked",
        "bytes": str(full_budget_deficit),
        "reason": "current host is short of full checkpoint plus configured reserve",
    },
    {
        "requirement_id": "minimum-additional-bytes-for-full-reserve",
        "status": "required",
        "bytes": str(full_budget_deficit),
        "reason": "free or attach this many additional bytes before full materialization admission",
    },
    {
        "requirement_id": "minimum-free-bytes-for-full-reserve",
        "status": "required",
        "bytes": str(required_with_reserve),
        "reason": "minimum free bytes needed for full checkpoint plus reserve",
    },
    {
        "requirement_id": "operator-margin-free-bytes",
        "status": "recommended",
        "bytes": str(operator_512gib_free_bytes),
        "reason": "512 GiB free profile leaves room for full checkpoint, reserve, and operator margin",
    },
]

full_reserve_profile_rows = sum(
    1 for row in profile_rows
    if row["effective_reserve_bytes"] == str(reserve_bytes)
    and row["full_checkpoint_admitted_by_profile_policy"] == "1"
)
full_without_reserve_profile_rows = sum(
    1 for row in profile_rows
    if row["full_checkpoint_admitted_without_reserve"] == "1"
)
first_full_reserve_profile_id = next(
    row["profile_id"] for row in profile_rows
    if row["effective_reserve_bytes"] == str(reserve_bytes)
    and row["full_checkpoint_admitted_by_profile_policy"] == "1"
)
current_reserve_row = next(row for row in profile_rows if row["profile_id"] == "current-host-reserve-policy")
current_no_reserve_row = next(row for row in profile_rows if row["profile_id"] == "current-host-no-reserve-diagnostic")
exact_reserve_row = next(row for row in profile_rows if row["profile_id"] == "full-checkpoint-exact-with-reserve")

metric = {
    "metric_id": "v61aj_checkpoint_storage_profile_admission_matrix_metrics",
    "model_id": model_id,
    "profile_rows": str(len(profile_rows)),
    "full_reserve_profile_rows": str(full_reserve_profile_rows),
    "full_without_reserve_profile_rows": str(full_without_reserve_profile_rows),
    "first_full_reserve_profile_id": first_full_reserve_profile_id,
    "current_available_bytes": str(current_available_bytes),
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
    "ssd_reserve_bytes": str(reserve_bytes),
    "required_with_reserve_bytes": str(required_with_reserve),
    "minimum_additional_bytes_for_full_reserve": str(full_budget_deficit),
    "raw_checkpoint_deficit_bytes": str(raw_checkpoint_deficit),
    "recommended_operator_free_bytes": str(operator_512gib_free_bytes),
    "current_reserve_admitted_shard_rows": current_reserve_row["admitted_shard_rows_under_profile_policy"],
    "current_no_reserve_admitted_shard_rows": current_no_reserve_row["admitted_shard_rows_under_profile_policy"],
    "current_no_reserve_admitted_shard_bytes": current_no_reserve_row["admitted_shard_bytes_under_profile_policy"],
    "exact_reserve_admitted_shard_rows": exact_reserve_row["admitted_shard_rows_under_profile_policy"],
    "selected_backend_id": selected_backend_id,
    "storage_profile_admission_matrix_ready": "1",
    "download_execution_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61aj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_storage_profile_rows.csv", list(profile_rows[0].keys()), profile_rows)
write_csv(run_dir / "checkpoint_storage_profile_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)
write_csv(run_dir / "checkpoint_storage_profile_metric_rows.csv", list(metric.keys()), [metric])

decision_rows = [
    {"gate": "v61ai-storage-budget-input", "status": "pass", "reason": "v61ai storage budget remediation plan is ready"},
    {"gate": "storage-profile-accounting", "status": "pass", "reason": "profile matrix records current, minimum, and operator-margin free-space profiles"},
    {"gate": "minimum-safe-full-profile", "status": "pass", "reason": f"{first_full_reserve_profile_id} admits all 59 shards with configured reserve"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61aj emits metadata only"},
    {"gate": "current-host-full-materialization", "status": "blocked", "reason": f"minimum_additional_bytes_for_full_reserve={full_budget_deficit}"},
    {"gate": "current-host-download-execution", "status": "blocked", "reason": "current host storage profile does not admit full materialization"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "storage profile matrix is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "storage profile matrix is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": "1",
    "v61ai_checkpoint_storage_budget_remediation_plan_ready": v61ai_summary["v61ai_checkpoint_storage_budget_remediation_plan_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61aj Checkpoint Storage Profile Admission Matrix Boundary

This artifact converts the v61ai SSD budget blocker into deterministic storage
profiles. It does not download checkpoint payload bytes.

Evidence emitted:

- profile_rows={len(profile_rows)}
- current_available_bytes={current_available_bytes}
- total_checkpoint_bytes_required={total_checkpoint_bytes}
- ssd_reserve_bytes={reserve_bytes}
- required_with_reserve_bytes={required_with_reserve}
- minimum_additional_bytes_for_full_reserve={full_budget_deficit}
- raw_checkpoint_deficit_bytes={raw_checkpoint_deficit}
- current_reserve_admitted_shard_rows={current_reserve_row['admitted_shard_rows_under_profile_policy']}
- current_no_reserve_admitted_shard_rows={current_no_reserve_row['admitted_shard_rows_under_profile_policy']}
- current_no_reserve_admitted_shard_bytes={current_no_reserve_row['admitted_shard_bytes_under_profile_policy']}
- exact_reserve_admitted_shard_rows={exact_reserve_row['admitted_shard_rows_under_profile_policy']}
- first_full_reserve_profile_id={first_full_reserve_profile_id}
- recommended_operator_free_bytes={operator_512gib_free_bytes}
- storage_profile_admission_matrix_ready=1
- checkpoint_payload_bytes_downloaded_by_v61aj=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- current_host_full_materialization=blocked
- current_host_download_execution=blocked
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AJ_CHECKPOINT_STORAGE_PROFILE_ADMISSION_MATRIX_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61aj_checkpoint_storage_profile_admission_matrix",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": 1,
    "profile_rows": len(profile_rows),
    "first_full_reserve_profile_id": first_full_reserve_profile_id,
    "minimum_additional_bytes_for_full_reserve": full_budget_deficit,
    "recommended_operator_free_bytes": operator_512gib_free_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61aj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61aj_checkpoint_storage_profile_admission_matrix_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61aj_checkpoint_storage_profile_admission_matrix_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
