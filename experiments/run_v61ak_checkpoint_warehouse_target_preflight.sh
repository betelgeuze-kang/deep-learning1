#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ak_checkpoint_warehouse_target_preflight"
RUN_ID="${V61AK_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ak_checkpoint_warehouse_target_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "${V61AK_WAREHOUSE_ROOT:-}" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
env_warehouse_root = sys.argv[5].strip()
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


def is_relative_to(path, base):
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def nearest_existing_path(path):
    probe = path
    while not probe.exists() and probe != probe.parent:
        probe = probe.parent
    return probe if probe.exists() else Path("/")


def disk_usage(path):
    try:
        usage = shutil.disk_usage(path)
        return usage.total, usage.used, usage.free, 1
    except OSError:
        return 0, 0, 0, 0


def git_check_ignored(path):
    proc = subprocess.run(
        ["git", "check-ignore", "-q", str(path)],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return int(proc.returncode == 0)


v61aj_dir = results / "v61aj_checkpoint_storage_profile_admission_matrix" / "matrix_001"
v61p_dir = results / "v61p_local_ssd_checkpoint_residency_preflight" / "preflight_001"
v61aj_summary = read_csv(results / "v61aj_checkpoint_storage_profile_admission_matrix_summary.csv")[0]
v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]

if v61aj_summary.get("v61aj_checkpoint_storage_profile_admission_matrix_ready") != "1":
    raise SystemExit("v61ak requires v61aj_checkpoint_storage_profile_admission_matrix_ready=1")
if v61p_summary.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != "1":
    raise SystemExit("v61ak requires v61p_local_ssd_checkpoint_residency_preflight_ready=1")

for src, rel in [
    (results / "v61aj_checkpoint_storage_profile_admission_matrix_summary.csv", "source_v61aj/v61aj_checkpoint_storage_profile_admission_matrix_summary.csv"),
    (results / "v61aj_checkpoint_storage_profile_admission_matrix_decision.csv", "source_v61aj/v61aj_checkpoint_storage_profile_admission_matrix_decision.csv"),
    (v61aj_dir / "checkpoint_storage_profile_rows.csv", "source_v61aj/checkpoint_storage_profile_rows.csv"),
    (v61aj_dir / "checkpoint_storage_profile_requirement_rows.csv", "source_v61aj/checkpoint_storage_profile_requirement_rows.csv"),
    (v61aj_dir / "checkpoint_storage_profile_metric_rows.csv", "source_v61aj/checkpoint_storage_profile_metric_rows.csv"),
    (v61aj_dir / "sha256_manifest.csv", "source_v61aj/sha256_manifest.csv"),
    (results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    (v61p_dir / "ssd_disk_budget_rows.csv", "source_v61p/ssd_disk_budget_rows.csv"),
    (v61p_dir / "local_shard_presence_rows.csv", "source_v61p/local_shard_presence_rows.csv"),
    (v61p_dir / "sha256_manifest.csv", "source_v61p/sha256_manifest.csv"),
]:
    copy(src, rel)

required_with_reserve = int(v61aj_summary["required_with_reserve_bytes"])
total_checkpoint_bytes = int(v61aj_summary["total_checkpoint_bytes_required"])
reserve_bytes = int(v61aj_summary["ssd_reserve_bytes"])
recommended_operator_free_bytes = int(v61aj_summary["recommended_operator_free_bytes"])
minimum_additional_bytes = int(v61aj_summary["minimum_additional_bytes_for_full_reserve"])
selected_backend_id = v61aj_summary["selected_backend_id"]
default_warehouse_path = Path(v61p_summary["ssd_warehouse_path"]).expanduser()
repo_forbidden_path = root / "results" / "v61ak_forbidden_checkpoint_warehouse"
env_path = Path(env_warehouse_root).expanduser() if env_warehouse_root else None

candidate_specs = [
    {
        "target_id": "current-v61p-warehouse",
        "target_kind": "observed-current-warehouse",
        "path": default_warehouse_path,
        "target_path_supplied": 1,
        "selection_rank": 10,
    },
    {
        "target_id": "env-v61ak-warehouse-root",
        "target_kind": "operator-supplied-warehouse",
        "path": env_path,
        "target_path_supplied": int(env_path is not None),
        "selection_rank": 1,
    },
    {
        "target_id": "repo-local-forbidden-control",
        "target_kind": "repository-control",
        "path": repo_forbidden_path,
        "target_path_supplied": 1,
        "selection_rank": 99,
    },
]

target_rows = []
for spec in candidate_specs:
    supplied = int(spec["target_path_supplied"])
    target_path = spec["path"] if supplied else None
    if target_path is None:
        target_path_text = ""
        probe_path = Path("/")
        parent_exists = 0
        dir_exists = 0
        can_create = 0
        total_bytes = used_bytes = available_bytes = 0
        probe_ready = 0
        outside_repo = 0
        inside_repo = 0
        ignored_or_outside = 0
        admitted = 0
        operator_margin = 0
        deficit = required_with_reserve
        blocked_reason = "target-path-not-supplied"
    else:
        target_path = target_path.resolve()
        target_path_text = str(target_path)
        probe_path = nearest_existing_path(target_path)
        parent = target_path if target_path.exists() and target_path.is_dir() else target_path.parent
        parent_probe = nearest_existing_path(parent)
        parent_exists = int(parent_probe == parent and parent.exists())
        dir_exists = int(target_path.exists() and target_path.is_dir())
        can_create = int(parent.exists() and os.access(parent, os.W_OK))
        total_bytes, used_bytes, available_bytes, probe_ready = disk_usage(probe_path)
        inside_repo = int(is_relative_to(target_path, root))
        outside_repo = int(not inside_repo)
        ignored_or_outside = int(outside_repo or git_check_ignored(target_path))
        admitted = int(outside_repo and probe_ready and can_create and available_bytes >= required_with_reserve)
        operator_margin = int(outside_repo and probe_ready and can_create and available_bytes >= recommended_operator_free_bytes)
        deficit = max(required_with_reserve - available_bytes, 0)
        if inside_repo:
            blocked_reason = "inside-repository-payload-target"
        elif not probe_ready:
            blocked_reason = "filesystem-probe-failed"
        elif not can_create:
            blocked_reason = "target-parent-not-writable"
        elif available_bytes < required_with_reserve:
            blocked_reason = "insufficient-free-bytes"
        else:
            blocked_reason = "none"
    target_rows.append({
        "target_id": spec["target_id"],
        "target_kind": spec["target_kind"],
        "model_id": model_id,
        "target_path": target_path_text,
        "target_path_supplied": str(supplied),
        "probe_path": str(probe_path),
        "probe_ready": str(probe_ready),
        "target_dir_exists": str(dir_exists),
        "target_parent_exists": str(parent_exists),
        "target_parent_writable": str(can_create),
        "inside_repository": str(inside_repo),
        "outside_repository": str(outside_repo),
        "git_ignored_or_outside_repository": str(ignored_or_outside),
        "filesystem_total_bytes": str(total_bytes),
        "filesystem_used_bytes": str(used_bytes),
        "filesystem_available_bytes": str(available_bytes),
        "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
        "ssd_reserve_bytes": str(reserve_bytes),
        "required_with_reserve_bytes": str(required_with_reserve),
        "recommended_operator_free_bytes": str(recommended_operator_free_bytes),
        "deficit_to_full_reserve_bytes": str(deficit),
        "full_reserve_target_admitted": str(admitted),
        "operator_margin_target_admitted": str(operator_margin),
        "selection_rank": str(spec["selection_rank"]),
        "selected_backend_id": selected_backend_id,
        "blocked_reason": blocked_reason,
        "prepare_command": f"mkdir -p {target_path_text}" if supplied and outside_repo else "",
        "download_env_hint": f"V61_WAREHOUSE_ROOT={target_path_text}" if supplied and outside_repo else "",
        "checkpoint_payload_bytes_downloaded_by_v61ak": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    })

admitted_rows = [row for row in target_rows if row["full_reserve_target_admitted"] == "1"]
admitted_rows.sort(key=lambda row: int(row["selection_rank"]))
selected_target = admitted_rows[0] if admitted_rows else None
current_target = next(row for row in target_rows if row["target_id"] == "current-v61p-warehouse")
env_target = next(row for row in target_rows if row["target_id"] == "env-v61ak-warehouse-root")
repo_control = next(row for row in target_rows if row["target_id"] == "repo-local-forbidden-control")

requirement_rows = [
    {
        "requirement_id": "full-reserve-free-bytes",
        "status": "required",
        "bytes": str(required_with_reserve),
        "reason": "minimum free bytes required for full checkpoint plus configured reserve",
    },
    {
        "requirement_id": "operator-margin-free-bytes",
        "status": "recommended",
        "bytes": str(recommended_operator_free_bytes),
        "reason": "preferred operator free-space profile from v61aj",
    },
    {
        "requirement_id": "outside-repository-warehouse",
        "status": "required",
        "bytes": "0",
        "reason": "checkpoint payload targets must stay outside the repository",
    },
    {
        "requirement_id": "current-target-deficit",
        "status": "blocked" if current_target["full_reserve_target_admitted"] == "0" else "pass",
        "bytes": current_target["deficit_to_full_reserve_bytes"],
        "reason": "live filesystem deficit for the current v61p warehouse target",
    },
]

metric = {
    "metric_id": "v61ak_checkpoint_warehouse_target_preflight_metrics",
    "model_id": model_id,
    "target_rows": str(len(target_rows)),
    "admitted_target_rows": str(len(admitted_rows)),
    "selected_target_id": selected_target["target_id"] if selected_target else "none",
    "selected_target_path": selected_target["target_path"] if selected_target else "",
    "env_warehouse_root_supplied": env_target["target_path_supplied"],
    "current_target_available_bytes_live": current_target["filesystem_available_bytes"],
    "current_target_deficit_to_full_reserve_bytes_live": current_target["deficit_to_full_reserve_bytes"],
    "current_target_full_reserve_admitted": current_target["full_reserve_target_admitted"],
    "repo_forbidden_control_blocked": "1" if repo_control["inside_repository"] == "1" and repo_control["full_reserve_target_admitted"] == "0" else "0",
    "required_with_reserve_bytes": str(required_with_reserve),
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
    "ssd_reserve_bytes": str(reserve_bytes),
    "minimum_additional_bytes_for_full_reserve_from_v61aj": str(minimum_additional_bytes),
    "recommended_operator_free_bytes": str(recommended_operator_free_bytes),
    "selected_backend_id": selected_backend_id,
    "warehouse_target_preflight_ready": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ak": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_warehouse_target_rows.csv", list(target_rows[0].keys()), target_rows)
write_csv(run_dir / "checkpoint_warehouse_target_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)
write_csv(run_dir / "checkpoint_warehouse_target_metric_rows.csv", list(metric.keys()), [metric])

selected_status = "pass" if selected_target else "blocked"
selected_reason = (
    f"selected_target_id={selected_target['target_id']}"
    if selected_target
    else f"current_target_deficit_to_full_reserve_bytes_live={current_target['deficit_to_full_reserve_bytes']}"
)
decision_rows = [
    {"gate": "v61aj-storage-profile-input", "status": "pass", "reason": "v61aj storage profile admission matrix is ready"},
    {"gate": "warehouse-target-accounting", "status": "pass", "reason": "candidate target paths, live free bytes, and outside-repository policy are recorded"},
    {"gate": "repository-payload-target-block", "status": "pass", "reason": "repository-local control target is rejected"},
    {"gate": "selected-full-reserve-warehouse-target", "status": selected_status, "reason": selected_reason},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ak emits metadata only"},
    {"gate": "download-execution", "status": "blocked", "reason": "explicit payload execution remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "warehouse target preflight is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "warehouse target preflight is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61ak_checkpoint_warehouse_target_preflight_ready": "1",
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": v61aj_summary["v61aj_checkpoint_storage_profile_admission_matrix_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61ak Checkpoint Warehouse Target Preflight Boundary

This artifact probes checkpoint warehouse target paths before any checkpoint
payload download. It separates v61aj policy requirements from live filesystem
availability.

Evidence emitted:

- target_rows={len(target_rows)}
- admitted_target_rows={len(admitted_rows)}
- selected_target_id={summary['selected_target_id']}
- env_warehouse_root_supplied={env_target['target_path_supplied']}
- current_target_available_bytes_live={current_target['filesystem_available_bytes']}
- current_target_deficit_to_full_reserve_bytes_live={current_target['deficit_to_full_reserve_bytes']}
- current_target_full_reserve_admitted={current_target['full_reserve_target_admitted']}
- repo_forbidden_control_blocked={summary['repo_forbidden_control_blocked']}
- required_with_reserve_bytes={required_with_reserve}
- recommended_operator_free_bytes={recommended_operator_free_bytes}
- warehouse_target_preflight_ready=1
- checkpoint_payload_bytes_downloaded_by_v61ak=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- download_execution_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AK_CHECKPOINT_WAREHOUSE_TARGET_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ak_checkpoint_warehouse_target_preflight",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ak_checkpoint_warehouse_target_preflight_ready": 1,
    "target_rows": len(target_rows),
    "admitted_target_rows": len(admitted_rows),
    "selected_target_id": summary["selected_target_id"],
    "current_target_available_bytes_live": int(current_target["filesystem_available_bytes"]),
    "required_with_reserve_bytes": required_with_reserve,
    "recommended_operator_free_bytes": recommended_operator_free_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61ak": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ak_checkpoint_warehouse_target_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ak_checkpoint_warehouse_target_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
