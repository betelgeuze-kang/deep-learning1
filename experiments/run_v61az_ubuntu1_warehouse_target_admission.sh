#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61az_ubuntu1_warehouse_target_admission"
RUN_ID="${V61AZ_RUN_ID:-admission_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
UBUNTU1_MOUNT="${V61AZ_UBUNTU1_MOUNT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25}"
UBUNTU1_TARGET="${V61AZ_UBUNTU1_TARGET:-$UBUNTU1_MOUNT/deep_learning_v61_mixtral_8x22b_warehouse}"

if [[ "${V61AZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61az_ubuntu1_warehouse_target_admission_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh" >/dev/null
V61AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null
V61AY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ay_selected_backend_token_runtime_binding.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_MOUNT" "$UBUNTU1_TARGET" <<'PY'
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
ubuntu1_mount = Path(sys.argv[5]).expanduser().resolve()
ubuntu1_target = Path(sys.argv[6]).expanduser().resolve()
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


def findmnt(path):
    proc = subprocess.run(
        ["findmnt", "--target", str(path), "--output", "SOURCE,FSTYPE,LABEL,TARGET", "--noheadings", "--raw"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {"source": "", "fstype": "", "label": "", "target": ""}
    parts = proc.stdout.strip().split()
    return {
        "source": parts[0] if len(parts) > 0 else "",
        "fstype": parts[1] if len(parts) > 1 else "",
        "label": parts[2] if len(parts) > 2 else "",
        "target": parts[3] if len(parts) > 3 else "",
    }


v61aj_dir = results / "v61aj_checkpoint_storage_profile_admission_matrix" / "matrix_001"
v61ak_dir = results / "v61ak_checkpoint_warehouse_target_preflight" / "preflight_001"
v61ay_dir = results / "v61ay_selected_backend_token_runtime_binding" / "binding_001"
v61aj_summary = read_csv(results / "v61aj_checkpoint_storage_profile_admission_matrix_summary.csv")[0]
v61ak_summary = read_csv(results / "v61ak_checkpoint_warehouse_target_preflight_summary.csv")[0]
v61ay_summary = read_csv(results / "v61ay_selected_backend_token_runtime_binding_summary.csv")[0]
if v61aj_summary.get("v61aj_checkpoint_storage_profile_admission_matrix_ready") != "1":
    raise SystemExit("v61az requires v61aj_checkpoint_storage_profile_admission_matrix_ready=1")
if v61ak_summary.get("v61ak_checkpoint_warehouse_target_preflight_ready") != "1":
    raise SystemExit("v61az requires v61ak_checkpoint_warehouse_target_preflight_ready=1")
if v61ay_summary.get("v61ay_selected_backend_token_runtime_binding_ready") != "1":
    raise SystemExit("v61az requires v61ay_selected_backend_token_runtime_binding_ready=1")

for src, rel in [
    (results / "v61aj_checkpoint_storage_profile_admission_matrix_summary.csv", "source_v61aj/v61aj_checkpoint_storage_profile_admission_matrix_summary.csv"),
    (v61aj_dir / "checkpoint_storage_profile_rows.csv", "source_v61aj/checkpoint_storage_profile_rows.csv"),
    (v61aj_dir / "checkpoint_storage_profile_metric_rows.csv", "source_v61aj/checkpoint_storage_profile_metric_rows.csv"),
    (v61aj_dir / "sha256_manifest.csv", "source_v61aj/sha256_manifest.csv"),
    (results / "v61ak_checkpoint_warehouse_target_preflight_summary.csv", "source_v61ak/v61ak_checkpoint_warehouse_target_preflight_summary.csv"),
    (v61ak_dir / "checkpoint_warehouse_target_rows.csv", "source_v61ak/checkpoint_warehouse_target_rows.csv"),
    (v61ak_dir / "checkpoint_warehouse_target_metric_rows.csv", "source_v61ak/checkpoint_warehouse_target_metric_rows.csv"),
    (v61ak_dir / "sha256_manifest.csv", "source_v61ak/sha256_manifest.csv"),
    (results / "v61ay_selected_backend_token_runtime_binding_summary.csv", "source_v61ay/v61ay_selected_backend_token_runtime_binding_summary.csv"),
    (v61ay_dir / "selected_backend_runtime_metric_rows.csv", "source_v61ay/selected_backend_runtime_metric_rows.csv"),
    (v61ay_dir / "sha256_manifest.csv", "source_v61ay/sha256_manifest.csv"),
]:
    copy(src, rel)

required_with_reserve = int(v61aj_summary["required_with_reserve_bytes"])
total_checkpoint_bytes = int(v61aj_summary["total_checkpoint_bytes_required"])
reserve_bytes = int(v61aj_summary["ssd_reserve_bytes"])
recommended_operator_free_bytes = int(v61aj_summary["recommended_operator_free_bytes"])
selected_backend_id = v61aj_summary["selected_backend_id"]

usage = shutil.disk_usage(ubuntu1_mount)
mount_info = findmnt(ubuntu1_mount)
target_parent = ubuntu1_target.parent
mount_exists = int(ubuntu1_mount.exists() and ubuntu1_mount.is_dir())
target_parent_exists = int(target_parent.exists() and target_parent.is_dir())
target_dir_exists = int(ubuntu1_target.exists() and ubuntu1_target.is_dir())
target_parent_write_access_ready = int(os.access(target_parent, os.W_OK))
target_outside_repository = int(not is_relative_to(ubuntu1_target, root))
target_inside_repository = int(not target_outside_repository)
full_reserve_capacity_pass = int(usage.free >= required_with_reserve)
operator_margin_pass = int(usage.free >= recommended_operator_free_bytes)
deficit_to_full_reserve = max(required_with_reserve - usage.free, 0)
deficit_to_operator_margin = max(recommended_operator_free_bytes - usage.free, 0)
capacity_target_ready = int(mount_exists and target_outside_repository and full_reserve_capacity_pass)
activation_target_write_ready = int(capacity_target_ready and target_parent_write_access_ready)
activation_target_ready = int(activation_target_write_ready)
selected_capacity_target_id = "ubuntu-1-full-reserve-capacity" if capacity_target_ready else "none"
selected_activation_target_id = "ubuntu-1-warehouse-target" if activation_target_ready else "none"
write_blocker_reason = "none" if activation_target_write_ready else "sandbox-or-operator-write-access-required"
target_prepare_command_ready = int(mount_exists and target_outside_repository)
operator_write_step_required = int(not activation_target_write_ready)

capacity_rows = [
    {
        "target_id": "ubuntu-1-full-reserve-capacity",
        "model_id": model_id,
        "mount_path": str(ubuntu1_mount),
        "target_path": str(ubuntu1_target),
        "filesystem_source": mount_info["source"],
        "filesystem_fstype": mount_info["fstype"],
        "filesystem_label": mount_info["label"],
        "findmnt_target": mount_info["target"],
        "mount_exists": str(mount_exists),
        "target_dir_exists": str(target_dir_exists),
        "target_parent_exists": str(target_parent_exists),
        "target_parent_write_access_ready": str(target_parent_write_access_ready),
        "target_outside_repository": str(target_outside_repository),
        "target_inside_repository": str(target_inside_repository),
        "filesystem_total_bytes": str(usage.total),
        "filesystem_used_bytes": str(usage.used),
        "filesystem_available_bytes": str(usage.free),
        "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
        "ssd_reserve_bytes": str(reserve_bytes),
        "required_with_reserve_bytes": str(required_with_reserve),
        "recommended_operator_free_bytes": str(recommended_operator_free_bytes),
        "deficit_to_full_reserve_bytes": str(deficit_to_full_reserve),
        "deficit_to_operator_margin_bytes": str(deficit_to_operator_margin),
        "full_reserve_capacity_pass": str(full_reserve_capacity_pass),
        "operator_margin_pass": str(operator_margin_pass),
        "capacity_target_ready": str(capacity_target_ready),
        "activation_target_write_ready": str(activation_target_write_ready),
        "activation_target_ready": str(activation_target_ready),
        "write_blocker_reason": write_blocker_reason,
        "checkpoint_payload_bytes_downloaded_by_v61az": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "ubuntu1_warehouse_capacity_rows.csv", list(capacity_rows[0].keys()), capacity_rows)

admission_rows = [
    {
        "admission_id": "ubuntu1-capacity-target-admission",
        "model_id": model_id,
        "target_id": "ubuntu-1-full-reserve-capacity",
        "target_path": str(ubuntu1_target),
        "selected_capacity_target_id": selected_capacity_target_id,
        "selected_activation_target_id": selected_activation_target_id,
        "capacity_probe_ready": str(mount_exists),
        "full_reserve_capacity_pass": str(full_reserve_capacity_pass),
        "operator_margin_pass": str(operator_margin_pass),
        "target_outside_repository": str(target_outside_repository),
        "target_parent_write_access_ready": str(target_parent_write_access_ready),
        "target_prepare_command_ready": str(target_prepare_command_ready),
        "operator_write_step_required": str(operator_write_step_required),
        "activation_target_ready": str(activation_target_ready),
        "download_execution_ready": "0",
        "local_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "actual_model_generation_ready": "0",
        "reason": "capacity-ready-write-blocked" if capacity_target_ready and not activation_target_ready else write_blocker_reason,
        "checkpoint_payload_bytes_downloaded_by_v61az": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "ubuntu1_warehouse_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

command_rows = [
    {
        "command_id": "prepare-ubuntu1-warehouse-dir",
        "command_kind": "prepare-directory",
        "command": f"mkdir -p {ubuntu1_target}",
        "dry_run_default": "1",
        "requires_operator_or_escalated_write": "1",
        "execution_ready": "0",
        "reason": write_blocker_reason,
    },
    {
        "command_id": "activate-v61ak-target-override",
        "command_kind": "metadata-reprobe",
        "command": f"V61AK_WAREHOUSE_ROOT={ubuntu1_target} V61AK_REUSE_EXISTING=0 ./experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh",
        "dry_run_default": "1",
        "requires_operator_or_escalated_write": "0",
        "execution_ready": "0",
        "reason": "follow-up-after-target-directory-write-ready",
    },
    {
        "command_id": "activate-v61al-target-override",
        "command_kind": "activation-plan",
        "command": f"V61AL_WAREHOUSE_ROOT={ubuntu1_target} V61AL_REUSE_EXISTING=0 ./experiments/run_v61al_checkpoint_warehouse_activation_gate.sh",
        "dry_run_default": "1",
        "requires_operator_or_escalated_write": "0",
        "execution_ready": "0",
        "reason": "follow-up-after-target-directory-write-ready",
    },
]
write_csv(run_dir / "ubuntu1_warehouse_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v61aj-storage-profile-input", "status": "pass", "actual": v61aj_summary["v61aj_checkpoint_storage_profile_admission_matrix_ready"], "required": "1", "reason": "storage requirement evidence is available"},
    {"requirement_id": "ubuntu1-mounted-ext4-target", "status": "pass" if mount_exists and mount_info["fstype"] == "ext4" else "blocked", "actual": mount_info["fstype"], "required": "ext4", "reason": "ubuntu-1 mount must be visible as an ext4 target"},
    {"requirement_id": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "actual": str(target_outside_repository), "required": "1", "reason": "checkpoint payload target must stay outside the repo"},
    {"requirement_id": "full-reserve-capacity", "status": "pass" if full_reserve_capacity_pass else "blocked", "actual": str(usage.free), "required": str(required_with_reserve), "reason": "ubuntu-1 free bytes must cover checkpoint plus reserve"},
    {"requirement_id": "operator-margin-capacity", "status": "recommended" if not operator_margin_pass else "pass", "actual": str(usage.free), "required": str(recommended_operator_free_bytes), "reason": "512 GiB operator margin is preferred but not required for full-reserve capacity"},
    {"requirement_id": "target-parent-write-access", "status": "blocked" if not target_parent_write_access_ready else "pass", "actual": str(target_parent_write_access_ready), "required": "1", "reason": write_blocker_reason},
    {"requirement_id": "activation-target-ready", "status": "blocked" if not activation_target_ready else "pass", "actual": str(activation_target_ready), "required": "1", "reason": "requires capacity plus write-ready target directory"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61az does not download or commit checkpoint payload bytes"},
]
write_csv(run_dir / "ubuntu1_warehouse_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61az_ubuntu1_warehouse_target_admission_metrics",
    "model_id": model_id,
    "v61az_ubuntu1_warehouse_target_admission_ready": "1",
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": v61aj_summary["v61aj_checkpoint_storage_profile_admission_matrix_ready"],
    "v61ak_checkpoint_warehouse_target_preflight_ready": v61ak_summary["v61ak_checkpoint_warehouse_target_preflight_ready"],
    "v61ay_selected_backend_token_runtime_binding_ready": v61ay_summary["v61ay_selected_backend_token_runtime_binding_ready"],
    "ubuntu1_mount_path": str(ubuntu1_mount),
    "ubuntu1_target_path": str(ubuntu1_target),
    "ubuntu1_filesystem_source": mount_info["source"],
    "ubuntu1_filesystem_fstype": mount_info["fstype"],
    "ubuntu1_filesystem_label": mount_info["label"],
    "ubuntu1_capacity_probe_ready": str(mount_exists),
    "ubuntu1_available_bytes_live": str(usage.free),
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes),
    "ssd_reserve_bytes": str(reserve_bytes),
    "required_with_reserve_bytes": str(required_with_reserve),
    "recommended_operator_free_bytes": str(recommended_operator_free_bytes),
    "ubuntu1_deficit_to_full_reserve_bytes": str(deficit_to_full_reserve),
    "ubuntu1_deficit_to_operator_margin_bytes": str(deficit_to_operator_margin),
    "ubuntu1_full_reserve_capacity_pass": str(full_reserve_capacity_pass),
    "ubuntu1_operator_margin_pass": str(operator_margin_pass),
    "target_outside_repository": str(target_outside_repository),
    "target_parent_exists": str(target_parent_exists),
    "target_directory_exists": str(target_dir_exists),
    "target_parent_write_access_ready": str(target_parent_write_access_ready),
    "target_prepare_command_ready": str(target_prepare_command_ready),
    "operator_write_step_required": str(operator_write_step_required),
    "selected_capacity_target_id": selected_capacity_target_id,
    "selected_capacity_target_path": str(ubuntu1_target) if capacity_target_ready else "",
    "selected_activation_target_id": selected_activation_target_id,
    "activation_target_ready": str(activation_target_ready),
    "activation_target_write_blocked_reason": write_blocker_reason,
    "selected_backend_id": selected_backend_id,
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61az": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_warehouse_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61aj-storage-profile-input", "ready", "v61aj storage requirements are bound"),
    ("ubuntu1-full-reserve-capacity", "ready" if full_reserve_capacity_pass else "blocked", f"available={usage.free} required={required_with_reserve}"),
    ("outside-repository-target", "ready" if target_outside_repository else "blocked", str(ubuntu1_target)),
    ("operator-margin-capacity", "ready" if operator_margin_pass else "recommended-gap", f"operator_margin_deficit={deficit_to_operator_margin}"),
    ("target-parent-write-access", "ready" if target_parent_write_access_ready else "blocked", write_blocker_reason),
    ("activation-target-ready", "ready" if activation_target_ready else "blocked", "requires write-ready target directory"),
    ("download-execution", "blocked", "v61az is metadata-only"),
    ("local-checkpoint-materialization", "blocked", "checkpoint shards are not materialized"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "target admission is not production latency evidence"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61aj-storage-profile-input", "status": "pass", "reason": "v61aj storage profile matrix is ready"},
    {"gate": "ubuntu1-full-reserve-capacity", "status": "pass" if full_reserve_capacity_pass else "blocked", "reason": f"available={usage.free} required={required_with_reserve}"},
    {"gate": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "reason": str(ubuntu1_target)},
    {"gate": "target-parent-write-access", "status": "blocked" if not target_parent_write_access_ready else "pass", "reason": write_blocker_reason},
    {"gate": "activation-target-ready", "status": "blocked" if not activation_target_ready else "pass", "reason": "requires write-ready target directory"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "download-execution", "status": "blocked", "reason": "payload execution remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61az ubuntu-1 Warehouse Target Admission Boundary

This artifact records the user-approved ubuntu-1 storage target as a
full-reserve capacity candidate before any checkpoint payload download.

Current target evidence:

- ubuntu1_mount_path={ubuntu1_mount}
- ubuntu1_target_path={ubuntu1_target}
- ubuntu1_filesystem_source={mount_info["source"]}
- ubuntu1_filesystem_fstype={mount_info["fstype"]}
- ubuntu1_filesystem_label={mount_info["label"]}
- ubuntu1_available_bytes_live={usage.free}
- required_with_reserve_bytes={required_with_reserve}
- recommended_operator_free_bytes={recommended_operator_free_bytes}
- ubuntu1_deficit_to_full_reserve_bytes={deficit_to_full_reserve}
- ubuntu1_full_reserve_capacity_pass={full_reserve_capacity_pass}
- ubuntu1_operator_margin_pass={operator_margin_pass}
- target_outside_repository={target_outside_repository}
- target_parent_write_access_ready={target_parent_write_access_ready}
- selected_capacity_target_id={selected_capacity_target_id}
- selected_activation_target_id={selected_activation_target_id}
- activation_target_ready={activation_target_ready}
- checkpoint_payload_bytes_downloaded_by_v61az=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 has enough free capacity for the full checkpoint plus
reserve as an outside-repository warehouse capacity target.

Blocked wording: target directory write readiness, checkpoint payload download,
local checkpoint materialization, full safetensors page-hash coverage, actual
Mixtral generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61AZ_UBUNTU1_WAREHOUSE_TARGET_ADMISSION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61az_ubuntu1_warehouse_target_admission",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61az_ubuntu1_warehouse_target_admission_ready": 1,
    "ubuntu1_mount_path": str(ubuntu1_mount),
    "ubuntu1_target_path": str(ubuntu1_target),
    "ubuntu1_available_bytes_live": usage.free,
    "required_with_reserve_bytes": required_with_reserve,
    "ubuntu1_full_reserve_capacity_pass": full_reserve_capacity_pass,
    "target_parent_write_access_ready": target_parent_write_access_ready,
    "activation_target_ready": activation_target_ready,
    "checkpoint_payload_bytes_downloaded_by_v61az": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61az_ubuntu1_warehouse_target_admission_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61az_ubuntu1_warehouse_target_admission_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
