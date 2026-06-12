#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61az_ubuntu1_warehouse_target_admission/admission_001"
SUMMARY_CSV="$RESULTS_DIR/v61az_ubuntu1_warehouse_target_admission_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61az_ubuntu1_warehouse_target_admission_decision.csv"

V61AZ_REUSE_EXISTING="${V61AZ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61az_ubuntu1_warehouse_target_admission.sh" >/dev/null

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
    "v61az_ubuntu1_warehouse_target_admission_ready": "1",
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": "1",
    "v61ak_checkpoint_warehouse_target_preflight_ready": "1",
    "v61ay_selected_backend_token_runtime_binding_ready": "1",
    "ubuntu1_mount_path": "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25",
    "ubuntu1_target_path": "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse",
    "ubuntu1_filesystem_source": "/dev/nvme0n1p8",
    "ubuntu1_filesystem_fstype": "ext4",
    "ubuntu1_filesystem_label": "ubuntu-1",
    "ubuntu1_capacity_probe_ready": "1",
    "total_checkpoint_bytes_required": "281241493344",
    "ssd_reserve_bytes": "34359738368",
    "required_with_reserve_bytes": "315601231712",
    "recommended_operator_free_bytes": "549755813888",
    "ubuntu1_deficit_to_full_reserve_bytes": "0",
    "ubuntu1_full_reserve_capacity_pass": "1",
    "target_outside_repository": "1",
    "target_parent_exists": "1",
    "target_parent_write_access_ready": "0",
    "target_prepare_command_ready": "1",
    "operator_write_step_required": "1",
    "selected_capacity_target_id": "ubuntu-1-full-reserve-capacity",
    "selected_capacity_target_path": "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse",
    "selected_activation_target_id": "none",
    "activation_target_ready": "0",
    "activation_target_write_blocked_reason": "sandbox-or-operator-write-access-required",
    "selected_backend_id": "curl-resume",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61az {field}: expected {value}, got {summary.get(field)}")

available = int(summary["ubuntu1_available_bytes_live"])
required = int(summary["required_with_reserve_bytes"])
operator_margin = int(summary["recommended_operator_free_bytes"])
operator_deficit = int(summary["ubuntu1_deficit_to_operator_margin_bytes"])
if available < required:
    raise SystemExit("v61az ubuntu-1 available bytes should cover full reserve")
if operator_deficit != max(operator_margin - available, 0):
    raise SystemExit("v61az operator margin deficit should match live bytes")
if summary["ubuntu1_operator_margin_pass"] != str(int(available >= operator_margin)):
    raise SystemExit("v61az operator margin pass should match live bytes")

required_files = [
    "ubuntu1_warehouse_capacity_rows.csv",
    "ubuntu1_warehouse_admission_rows.csv",
    "ubuntu1_warehouse_operator_command_rows.csv",
    "ubuntu1_warehouse_requirement_rows.csv",
    "ubuntu1_warehouse_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AZ_UBUNTU1_WAREHOUSE_TARGET_ADMISSION_BOUNDARY.md",
    "v61az_ubuntu1_warehouse_target_admission_manifest.json",
    "sha256_manifest.csv",
    "source_v61aj/checkpoint_storage_profile_rows.csv",
    "source_v61ak/checkpoint_warehouse_target_rows.csv",
    "source_v61ay/selected_backend_runtime_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61az artifact: {rel}")

capacity = read_csv(run_dir / "ubuntu1_warehouse_capacity_rows.csv")
admission = read_csv(run_dir / "ubuntu1_warehouse_admission_rows.csv")
commands = {row["command_id"]: row for row in read_csv(run_dir / "ubuntu1_warehouse_operator_command_rows.csv")}
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_warehouse_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_warehouse_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(capacity) != 1:
    raise SystemExit("v61az should emit one ubuntu-1 capacity row")
if len(admission) != 1:
    raise SystemExit("v61az should emit one ubuntu-1 admission row")
capacity_row = capacity[0]
admission_row = admission[0]
for field in [
    "filesystem_source",
    "filesystem_fstype",
    "filesystem_label",
    "target_parent_write_access_ready",
    "target_outside_repository",
    "full_reserve_capacity_pass",
    "activation_target_ready",
    "checkpoint_payload_bytes_downloaded_by_v61az",
    "checkpoint_payload_bytes_committed_to_repo",
]:
    summary_field = {
        "filesystem_source": "ubuntu1_filesystem_source",
        "filesystem_fstype": "ubuntu1_filesystem_fstype",
        "filesystem_label": "ubuntu1_filesystem_label",
        "full_reserve_capacity_pass": "ubuntu1_full_reserve_capacity_pass",
    }.get(field, field)
    if capacity_row[field] != summary[summary_field]:
        raise SystemExit(f"v61az capacity {field} should match summary")

for field in [
    "selected_capacity_target_id",
    "selected_activation_target_id",
    "target_parent_write_access_ready",
    "target_prepare_command_ready",
    "operator_write_step_required",
    "activation_target_ready",
    "download_execution_ready",
    "local_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "checkpoint_payload_bytes_downloaded_by_v61az",
    "checkpoint_payload_bytes_committed_to_repo",
]:
    if admission_row[field] != summary.get(field, admission_row[field]):
        raise SystemExit(f"v61az admission {field} should match summary")

if commands["prepare-ubuntu1-warehouse-dir"]["requires_operator_or_escalated_write"] != "1":
    raise SystemExit("v61az prepare command should require operator or escalated write")
if commands["prepare-ubuntu1-warehouse-dir"]["execution_ready"] != "0":
    raise SystemExit("v61az prepare command must not execute by default")
if commands["activate-v61ak-target-override"]["execution_ready"] != "0":
    raise SystemExit("v61az target override reprobe should stay dry-run")
if commands["activate-v61al-target-override"]["execution_ready"] != "0":
    raise SystemExit("v61az activation reprobe should stay dry-run")

for requirement_id in [
    "v61aj-storage-profile-input",
    "ubuntu1-mounted-ext4-target",
    "outside-repository-target",
    "full-reserve-capacity",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61az requirement should pass: {requirement_id}")
if requirements["operator-margin-capacity"]["status"] not in {"pass", "recommended"}:
    raise SystemExit("v61az operator margin should be pass or recommended")
for requirement_id in [
    "target-parent-write-access",
    "activation-target-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61az requirement should stay blocked: {requirement_id}")

for gate in [
    "v61aj-storage-profile-input",
    "ubuntu1-full-reserve-capacity",
    "outside-repository-target",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61az gate should pass: {gate}")
for gate in [
    "target-parent-write-access",
    "activation-target-ready",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61az gate should remain blocked: {gate}")

for gap in [
    "v61aj-storage-profile-input",
    "ubuntu1-full-reserve-capacity",
    "outside-repository-target",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61az gap should be ready: {gap}")
if gaps.get("operator-margin-capacity") not in {"ready", "recommended-gap"}:
    raise SystemExit("v61az operator margin gap should be ready or recommended-gap")
for gap in [
    "target-parent-write-access",
    "activation-target-ready",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61az gap should remain blocked: {gap}")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61az metric {field}: expected {value}, got {metric[field]}")

manifest = json.loads((run_dir / "v61az_ubuntu1_warehouse_target_admission_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61az_ubuntu1_warehouse_target_admission_ready") != 1:
    raise SystemExit("v61az manifest readiness mismatch")
if manifest.get("ubuntu1_full_reserve_capacity_pass") != 1:
    raise SystemExit("v61az manifest capacity pass mismatch")
if manifest.get("activation_target_ready") != 0:
    raise SystemExit("v61az manifest activation readiness must stay blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61az") != 0:
    raise SystemExit("v61az manifest must not download payload bytes")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61az manifest must not commit payload bytes")

sha_manifest = read_csv(run_dir / "sha256_manifest.csv")
if not sha_manifest:
    raise SystemExit("v61az sha manifest should not be empty")
for row in sha_manifest:
    rel = row["path"]
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"v61az sha manifest points to missing file: {rel}")
    if sha256(path) != row["sha256"]:
        raise SystemExit(f"v61az sha mismatch: {rel}")

print("v61az ubuntu-1 warehouse target admission smoke passed")
PY
