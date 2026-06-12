#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ba_ubuntu1_activation_handoff_package"
RUN_ID="${V61BA_RUN_ID:-handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ba_ubuntu1_activation_handoff_package_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61az_ubuntu1_warehouse_target_admission.sh" >/dev/null
V61AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shlex
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


v61az_dir = results / "v61az_ubuntu1_warehouse_target_admission" / "admission_001"
v61ah_dir = results / "v61ah_checkpoint_download_backend_fallback_plan" / "plan_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61az_summary = read_csv(results / "v61az_ubuntu1_warehouse_target_admission_summary.csv")[0]
v61ah_summary = read_csv(results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv")[0]
if v61az_summary.get("v61az_ubuntu1_warehouse_target_admission_ready") != "1":
    raise SystemExit("v61ba requires v61az_ubuntu1_warehouse_target_admission_ready=1")
if v61ah_summary.get("v61ah_checkpoint_download_backend_fallback_plan_ready") != "1":
    raise SystemExit("v61ba requires v61ah_checkpoint_download_backend_fallback_plan_ready=1")

for src, rel in [
    (results / "v61az_ubuntu1_warehouse_target_admission_summary.csv", "source_v61az/v61az_ubuntu1_warehouse_target_admission_summary.csv"),
    (results / "v61az_ubuntu1_warehouse_target_admission_decision.csv", "source_v61az/v61az_ubuntu1_warehouse_target_admission_decision.csv"),
    (v61az_dir / "ubuntu1_warehouse_capacity_rows.csv", "source_v61az/ubuntu1_warehouse_capacity_rows.csv"),
    (v61az_dir / "ubuntu1_warehouse_admission_rows.csv", "source_v61az/ubuntu1_warehouse_admission_rows.csv"),
    (v61az_dir / "ubuntu1_warehouse_requirement_rows.csv", "source_v61az/ubuntu1_warehouse_requirement_rows.csv"),
    (v61az_dir / "sha256_manifest.csv", "source_v61az/sha256_manifest.csv"),
    (results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv", "source_v61ah/v61ah_checkpoint_download_backend_fallback_plan_summary.csv"),
    (v61ah_dir / "checkpoint_download_backend_plan_rows.csv", "source_v61ah/checkpoint_download_backend_plan_rows.csv"),
    (v61ah_dir / "sha256_manifest.csv", "source_v61ah/sha256_manifest.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

backend_rows = read_csv(v61ah_dir / "checkpoint_download_backend_plan_rows.csv")
priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(backend_rows) != 59:
    raise SystemExit("v61ba expects 59 backend download rows")
if len(priority_rows) != 59:
    raise SystemExit("v61ba expects 59 priority rows")

priority_by_shard = {row["shard_name"]: row for row in priority_rows}
target_dir = Path(v61az_summary["selected_capacity_target_path"])
selected_capacity_target_id = v61az_summary["selected_capacity_target_id"]
selected_backend_id = v61az_summary["selected_backend_id"]
capacity_target_ready = int(v61az_summary["ubuntu1_full_reserve_capacity_pass"] == "1" and v61az_summary["target_outside_repository"] == "1")
target_parent_write_access_ready = int(v61az_summary["target_parent_write_access_ready"])
operator_write_step_required = int(v61az_summary["operator_write_step_required"])
operator_margin_pass = int(v61az_summary["ubuntu1_operator_margin_pass"])

handoff_rows = []
for row in sorted(backend_rows, key=lambda item: int(item["priority_rank"])):
    shard_name = row["shard_name"]
    priority = priority_by_shard[shard_name]
    target_path = target_dir / shard_name
    quoted_target_dir = shlex.quote(str(target_dir))
    quoted_target_path = shlex.quote(str(target_path))
    quoted_source_url = shlex.quote(row["source_url"])
    download_command = (
        f"mkdir -p {quoted_target_dir} && "
        f"curl -L --fail --retry 5 --continue-at - "
        f"--output {quoted_target_path} {quoted_source_url}"
    )
    verify_command = (
        f"V61T_WAREHOUSE_ROOT={shlex.quote(str(target_dir))} "
        "V61T_REUSE_EXISTING=0 experiments/run_v61t_local_checkpoint_materialization_verifier.sh"
    )
    full_hash_command = (
        f"V61R_WAREHOUSE_ROOT={shlex.quote(str(target_dir))} "
        "V61R_ENABLE_LOCAL_HASH_SWEEP=1 V61R_REUSE_EXISTING=0 "
        "experiments/run_v61r_full_page_hash_sweep_plan.sh"
    )
    generation_command = (
        f"V61AE_WAREHOUSE_ROOT={shlex.quote(str(target_dir))} "
        "V61AE_REUSE_EXISTING=0 experiments/run_v61ae_real_generation_admission_gate.sh"
    )
    handoff_rows.append(
        {
            "priority_rank": row["priority_rank"],
            "model_id": model_id,
            "shard_name": shard_name,
            "priority_class": priority["priority_class"],
            "source_url": row["source_url"],
            "target_path": str(target_path),
            "expected_bytes": row["expected_bytes"],
            "selected_capacity_target_id": selected_capacity_target_id,
            "selected_target_path": str(target_dir),
            "selected_backend_id": selected_backend_id,
            "selected_backend_ready": row["selected_backend_ready"],
            "capacity_target_ready": str(capacity_target_ready),
            "full_reserve_capacity_pass": v61az_summary["ubuntu1_full_reserve_capacity_pass"],
            "operator_margin_pass": str(operator_margin_pass),
            "target_parent_write_access_ready": str(target_parent_write_access_ready),
            "operator_write_step_required": str(operator_write_step_required),
            "dry_run_default": "1",
            "explicit_execute_required": "1",
            "requires_operator_or_escalated_write": "1",
            "handoff_command_ready": "1",
            "activation_execution_ready": "0",
            "blocked_reason": "operator-write-step-required",
            "download_command_preview": download_command,
            "post_download_verify_command": verify_command,
            "post_download_full_page_hash_command": full_hash_command,
            "post_download_generation_admission_command": generation_command,
            "checkpoint_payload_bytes_downloaded_by_v61ba": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

target_path_ubuntu1_rows = sum(str(target_dir) in row["target_path"] for row in handoff_rows)
download_command_ubuntu1_rows = sum(str(target_dir) in row["download_command_preview"] for row in handoff_rows)
verify_command_ubuntu1_rows = sum(str(target_dir) in row["post_download_verify_command"] for row in handoff_rows)
full_hash_command_ubuntu1_rows = sum(str(target_dir) in row["post_download_full_page_hash_command"] for row in handoff_rows)
generation_command_ubuntu1_rows = sum(str(target_dir) in row["post_download_generation_admission_command"] for row in handoff_rows)
stale_tmp_target_command_rows = sum("/tmp/v61aj-warehouse-override" in " ".join(row.values()) for row in handoff_rows)
total_expected_bytes = sum(int(row["expected_bytes"]) for row in handoff_rows)
priority_counts = {}
for row in handoff_rows:
    priority_counts[row["priority_class"]] = priority_counts.get(row["priority_class"], 0) + 1

write_csv(run_dir / "ubuntu1_activation_handoff_command_rows.csv", list(handoff_rows[0].keys()), handoff_rows)

requirement_rows = [
    {"requirement_id": "v61az-ubuntu1-capacity-input", "status": "pass", "actual": v61az_summary["v61az_ubuntu1_warehouse_target_admission_ready"], "required": "1", "reason": "ubuntu-1 target admission evidence is available"},
    {"requirement_id": "v61ah-backend-plan-input", "status": "pass", "actual": v61ah_summary["v61ah_checkpoint_download_backend_fallback_plan_ready"], "required": "1", "reason": "curl-resume backend plan is available"},
    {"requirement_id": "ubuntu1-full-reserve-capacity", "status": "pass" if capacity_target_ready else "blocked", "actual": v61az_summary["ubuntu1_available_bytes_live"], "required": v61az_summary["required_with_reserve_bytes"], "reason": "ubuntu-1 free bytes cover checkpoint plus reserve"},
    {"requirement_id": "operator-margin-capacity", "status": "pass" if operator_margin_pass else "recommended", "actual": v61az_summary["ubuntu1_available_bytes_live"], "required": v61az_summary["recommended_operator_free_bytes"], "reason": "512 GiB operator margin is preferred but not required for handoff"},
    {"requirement_id": "target-bound-command-rewrite", "status": "pass" if stale_tmp_target_command_rows == 0 else "blocked", "actual": str(stale_tmp_target_command_rows), "required": "0", "reason": "handoff commands must not retain stale /tmp warehouse targets"},
    {"requirement_id": "target-parent-write-access", "status": "blocked" if target_parent_write_access_ready == 0 else "pass", "actual": str(target_parent_write_access_ready), "required": "1", "reason": "managed session still requires operator/escalated write step"},
    {"requirement_id": "explicit-download-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "v61ba is a handoff package and does not execute checkpoint downloads"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61ba does not download or commit checkpoint payload bytes"},
]
write_csv(run_dir / "ubuntu1_activation_handoff_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ba_ubuntu1_activation_handoff_package_metrics",
    "model_id": model_id,
    "v61ba_ubuntu1_activation_handoff_package_ready": "1",
    "v61az_ubuntu1_warehouse_target_admission_ready": v61az_summary["v61az_ubuntu1_warehouse_target_admission_ready"],
    "v61ah_checkpoint_download_backend_fallback_plan_ready": v61ah_summary["v61ah_checkpoint_download_backend_fallback_plan_ready"],
    "selected_capacity_target_id": selected_capacity_target_id,
    "selected_target_path": str(target_dir),
    "selected_backend_id": selected_backend_id,
    "selected_backend_ready": v61ah_summary["selected_backend_ready"],
    "ubuntu1_available_bytes_live": v61az_summary["ubuntu1_available_bytes_live"],
    "required_with_reserve_bytes": v61az_summary["required_with_reserve_bytes"],
    "recommended_operator_free_bytes": v61az_summary["recommended_operator_free_bytes"],
    "ubuntu1_full_reserve_capacity_pass": v61az_summary["ubuntu1_full_reserve_capacity_pass"],
    "ubuntu1_operator_margin_pass": v61az_summary["ubuntu1_operator_margin_pass"],
    "target_parent_write_access_ready": str(target_parent_write_access_ready),
    "operator_write_step_required": str(operator_write_step_required),
    "activation_handoff_command_rows": str(len(handoff_rows)),
    "target_path_ubuntu1_rows": str(target_path_ubuntu1_rows),
    "download_command_ubuntu1_rows": str(download_command_ubuntu1_rows),
    "target_bound_verify_command_rows": str(verify_command_ubuntu1_rows),
    "target_bound_full_page_hash_command_rows": str(full_hash_command_ubuntu1_rows),
    "target_bound_generation_recheck_command_rows": str(generation_command_ubuntu1_rows),
    "stale_tmp_target_command_rows": str(stale_tmp_target_command_rows),
    "p0_remote_moe_sampled_rows": str(priority_counts.get("p0_remote_moe_sampled", 0)),
    "p0_embedding_sampled_rows": str(priority_counts.get("p0_embedding_sampled", 0)),
    "p2_checkpoint_backfill_rows": str(priority_counts.get("p2_checkpoint_backfill", 0)),
    "total_expected_checkpoint_bytes": str(total_expected_bytes),
    "activation_handoff_package_ready": "1",
    "activation_execution_ready": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ba": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_activation_handoff_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, [key for key in metric if key != "metric_id"], [{key: value for key, value in metric.items() if key != "metric_id"}])

runtime_gap_rows = [
    ("v61az-ubuntu1-capacity-input", "ready", "ubuntu-1 full-reserve capacity evidence is available"),
    ("v61ah-backend-plan-input", "ready", "curl-resume backend rows are available"),
    ("target-bound-command-rewrite", "ready", "all handoff commands point to ubuntu-1"),
    ("operator-margin-capacity", "ready" if operator_margin_pass else "recommended-gap", "512 GiB operator margin is preferred"),
    ("target-parent-write-access", "blocked" if target_parent_write_access_ready == 0 else "ready", "operator/escalated write step remains required in the managed session"),
    ("explicit-download-execution", "blocked", "v61ba emits handoff rows only"),
    ("local-checkpoint-materialization", "blocked", "checkpoint shards are not materialized"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "handoff package is not a decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in runtime_gap_rows])

decision_rows = [
    {"gate": "v61az-ubuntu1-capacity-input", "status": "pass", "reason": "v61az target admission is ready"},
    {"gate": "v61ah-backend-plan-input", "status": "pass", "reason": "v61ah backend plan is ready"},
    {"gate": "ubuntu1-full-reserve-capacity", "status": "pass" if capacity_target_ready else "blocked", "reason": f"available={v61az_summary['ubuntu1_available_bytes_live']} required={v61az_summary['required_with_reserve_bytes']}"},
    {"gate": "target-bound-command-rewrite", "status": "pass" if stale_tmp_target_command_rows == 0 else "blocked", "reason": f"stale_tmp_target_command_rows={stale_tmp_target_command_rows}"},
    {"gate": "target-parent-write-access", "status": "blocked" if target_parent_write_access_ready == 0 else "pass", "reason": "operator/escalated write step remains required"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "checkpoint payload execution remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "handoff package is not latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ba ubuntu-1 Activation Handoff Package Boundary

This artifact rewrites the checkpoint activation handoff commands to the
ubuntu-1 outside-repository warehouse target. It does not execute downloads and
does not write checkpoint payload bytes.

Evidence emitted:

- selected_capacity_target_id={selected_capacity_target_id}
- selected_target_path={target_dir}
- selected_backend_id={selected_backend_id}
- activation_handoff_command_rows={len(handoff_rows)}
- target_path_ubuntu1_rows={target_path_ubuntu1_rows}
- download_command_ubuntu1_rows={download_command_ubuntu1_rows}
- target_bound_verify_command_rows={verify_command_ubuntu1_rows}
- target_bound_full_page_hash_command_rows={full_hash_command_ubuntu1_rows}
- target_bound_generation_recheck_command_rows={generation_command_ubuntu1_rows}
- stale_tmp_target_command_rows={stale_tmp_target_command_rows}
- target_parent_write_access_ready={target_parent_write_access_ready}
- operator_write_step_required={operator_write_step_required}
- activation_execution_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ba=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 has a target-bound metadata handoff package for all
59 Mixtral checkpoint shards.

Blocked wording: payload download execution, local checkpoint materialization,
full safetensors page-hash coverage, actual Mixtral generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BA_UBUNTU1_ACTIVATION_HANDOFF_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ba_ubuntu1_activation_handoff_package",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ba_ubuntu1_activation_handoff_package_ready": 1,
    "selected_target_path": str(target_dir),
    "activation_handoff_command_rows": len(handoff_rows),
    "target_bound_verify_command_rows": verify_command_ubuntu1_rows,
    "target_bound_full_page_hash_command_rows": full_hash_command_ubuntu1_rows,
    "target_bound_generation_recheck_command_rows": generation_command_ubuntu1_rows,
    "stale_tmp_target_command_rows": stale_tmp_target_command_rows,
    "activation_execution_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ba": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ba_ubuntu1_activation_handoff_package_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61ba_ubuntu1_activation_handoff_package_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
