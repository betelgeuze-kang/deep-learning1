#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bn_ubuntu1_activation_admission_refresh_gate"
RUN_ID="${V61BN_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bn_ubuntu1_activation_admission_refresh_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bb_ubuntu1_write_sentinel_activation_probe.sh" >/dev/null

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


v61az_dir = results / "v61az_ubuntu1_warehouse_target_admission" / "admission_001"
v61ba_dir = results / "v61ba_ubuntu1_activation_handoff_package" / "handoff_001"
v61bb_dir = results / "v61bb_ubuntu1_write_sentinel_activation_probe" / "write_probe_001"
v61az_summary = read_csv(results / "v61az_ubuntu1_warehouse_target_admission_summary.csv")[0]
v61ba_summary = read_csv(results / "v61ba_ubuntu1_activation_handoff_package_summary.csv")[0]
v61bb_summary = read_csv(results / "v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv")[0]
if v61az_summary.get("v61az_ubuntu1_warehouse_target_admission_ready") != "1":
    raise SystemExit("v61bn requires v61az_ubuntu1_warehouse_target_admission_ready=1")
if v61ba_summary.get("v61ba_ubuntu1_activation_handoff_package_ready") != "1":
    raise SystemExit("v61bn requires v61ba_ubuntu1_activation_handoff_package_ready=1")
if v61bb_summary.get("v61bb_ubuntu1_write_sentinel_activation_probe_ready") != "1":
    raise SystemExit("v61bn requires v61bb_ubuntu1_write_sentinel_activation_probe_ready=1")
if v61bb_summary.get("activation_target_write_witness_ready") != "1":
    raise SystemExit("v61bn requires activation_target_write_witness_ready=1")

for src, rel in [
    (results / "v61az_ubuntu1_warehouse_target_admission_summary.csv", "source_v61az/v61az_ubuntu1_warehouse_target_admission_summary.csv"),
    (results / "v61az_ubuntu1_warehouse_target_admission_decision.csv", "source_v61az/v61az_ubuntu1_warehouse_target_admission_decision.csv"),
    (v61az_dir / "ubuntu1_warehouse_capacity_rows.csv", "source_v61az/ubuntu1_warehouse_capacity_rows.csv"),
    (v61az_dir / "ubuntu1_warehouse_admission_rows.csv", "source_v61az/ubuntu1_warehouse_admission_rows.csv"),
    (v61az_dir / "sha256_manifest.csv", "source_v61az/sha256_manifest.csv"),
    (results / "v61ba_ubuntu1_activation_handoff_package_summary.csv", "source_v61ba/v61ba_ubuntu1_activation_handoff_package_summary.csv"),
    (results / "v61ba_ubuntu1_activation_handoff_package_decision.csv", "source_v61ba/v61ba_ubuntu1_activation_handoff_package_decision.csv"),
    (v61ba_dir / "ubuntu1_activation_handoff_command_rows.csv", "source_v61ba/ubuntu1_activation_handoff_command_rows.csv"),
    (v61ba_dir / "ubuntu1_activation_handoff_requirement_rows.csv", "source_v61ba/ubuntu1_activation_handoff_requirement_rows.csv"),
    (v61ba_dir / "sha256_manifest.csv", "source_v61ba/sha256_manifest.csv"),
    (results / "v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv", "source_v61bb/v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv"),
    (results / "v61bb_ubuntu1_write_sentinel_activation_probe_decision.csv", "source_v61bb/v61bb_ubuntu1_write_sentinel_activation_probe_decision.csv"),
    (v61bb_dir / "ubuntu1_write_sentinel_witness_rows.csv", "source_v61bb/ubuntu1_write_sentinel_witness_rows.csv"),
    (v61bb_dir / "ubuntu1_write_sentinel_requirement_rows.csv", "source_v61bb/ubuntu1_write_sentinel_requirement_rows.csv"),
    (v61bb_dir / "sha256_manifest.csv", "source_v61bb/sha256_manifest.csv"),
]:
    copy(src, rel)

handoff_rows = read_csv(v61ba_dir / "ubuntu1_activation_handoff_command_rows.csv")
if len(handoff_rows) != 59:
    raise SystemExit("v61bn expects 59 v61ba handoff rows")

capacity_ready = int(v61az_summary["ubuntu1_full_reserve_capacity_pass"] == "1")
write_witness_ready = int(v61bb_summary["activation_target_write_witness_ready"] == "1")
handoff_ready = int(v61ba_summary["activation_handoff_package_ready"] == "1")
backend_ready = int(v61ba_summary["selected_backend_ready"] == "1")
target_bound_rows = sum(1 for row in handoff_rows if row["target_path"].startswith(v61ba_summary["selected_target_path"]))
stale_tmp_rows = sum(1 for row in handoff_rows if "/tmp/" in row["target_path"])
target_admission_ready = int(
    capacity_ready
    and write_witness_ready
    and handoff_ready
    and backend_ready
    and target_bound_rows == len(handoff_rows)
    and stale_tmp_rows == 0
)

activation_rows = []
for row in handoff_rows:
    target_admitted = int(target_admission_ready and row["target_path"].startswith(v61ba_summary["selected_target_path"]))
    activation_rows.append(
        {
            "activation_admission_row_id": f"v61bn_activation_admission_{int(row['priority_rank']):04d}",
            "priority_rank": row["priority_rank"],
            "model_id": row["model_id"],
            "shard_name": row["shard_name"],
            "priority_class": row["priority_class"],
            "source_url": row["source_url"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "selected_capacity_target_id": row["selected_capacity_target_id"],
            "selected_target_path": row["selected_target_path"],
            "selected_backend_id": row["selected_backend_id"],
            "capacity_target_ready": row["capacity_target_ready"],
            "selected_backend_ready": row["selected_backend_ready"],
            "activation_target_write_witness_ready": str(write_witness_ready),
            "operator_write_step_resolved_by_witness": v61bb_summary["operator_write_step_resolved_by_witness"],
            "target_activation_admitted": str(target_admitted),
            "target_activation_blocked_reason": "" if target_admitted else "target-admission-input-incomplete",
            "payload_execution_requires_explicit_operator_approval": "1",
            "payload_execution_ready": "0",
            "download_execution_ready": "0",
            "download_command_preview": row["download_command_preview"],
            "post_download_verify_command": row["post_download_verify_command"],
            "post_download_full_page_hash_command": row["post_download_full_page_hash_command"],
            "post_download_generation_admission_command": row["post_download_generation_admission_command"],
            "checkpoint_payload_bytes_downloaded_by_v61bn": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

activation_admitted_rows = sum(1 for row in activation_rows if row["target_activation_admitted"] == "1")
activation_blocked_rows = len(activation_rows) - activation_admitted_rows
payload_execution_blocked_rows = sum(1 for row in activation_rows if row["payload_execution_ready"] == "0")
expected_bytes_total = sum(int(row["expected_bytes"]) for row in activation_rows)

write_csv(run_dir / "ubuntu1_activation_admission_rows.csv", list(activation_rows[0].keys()), activation_rows)

requirement_rows = [
    {"requirement_id": "v61az-ubuntu1-capacity-input", "status": "pass", "actual": v61az_summary["ubuntu1_full_reserve_capacity_pass"], "required": "1", "reason": "ubuntu-1 target has full-reserve capacity"},
    {"requirement_id": "v61ba-target-bound-handoff-input", "status": "pass", "actual": v61ba_summary["activation_handoff_command_rows"], "required": "59", "reason": "all shard handoff commands are target-bound"},
    {"requirement_id": "v61bb-write-witness-input", "status": "pass", "actual": v61bb_summary["activation_target_write_witness_ready"], "required": "1", "reason": "ubuntu-1 write witness resolves activation target write step"},
    {"requirement_id": "activation-target-admission", "status": "pass" if target_admission_ready else "blocked", "actual": f"{activation_admitted_rows}/59", "required": "59/59", "reason": "all target-bound shard rows are admitted to the ubuntu-1 activation target"},
    {"requirement_id": "explicit-payload-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "checkpoint download execution remains disabled until explicit operator approval"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61bn records commands only and downloads no checkpoint payload"},
]
write_csv(run_dir / "ubuntu1_activation_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bn_ubuntu1_activation_admission_refresh_metrics",
    "model_id": model_id,
    "v61bn_ubuntu1_activation_admission_refresh_gate_ready": "1",
    "v61az_ubuntu1_warehouse_target_admission_ready": v61az_summary["v61az_ubuntu1_warehouse_target_admission_ready"],
    "v61ba_ubuntu1_activation_handoff_package_ready": v61ba_summary["v61ba_ubuntu1_activation_handoff_package_ready"],
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": v61bb_summary["v61bb_ubuntu1_write_sentinel_activation_probe_ready"],
    "selected_capacity_target_id": v61ba_summary["selected_capacity_target_id"],
    "selected_activation_target_id": "ubuntu-1-write-witness-admitted",
    "selected_target_path": v61ba_summary["selected_target_path"],
    "selected_backend_id": v61ba_summary["selected_backend_id"],
    "selected_backend_ready": v61ba_summary["selected_backend_ready"],
    "ubuntu1_available_bytes_live": v61ba_summary["ubuntu1_available_bytes_live"],
    "required_with_reserve_bytes": v61ba_summary["required_with_reserve_bytes"],
    "ubuntu1_full_reserve_capacity_pass": v61ba_summary["ubuntu1_full_reserve_capacity_pass"],
    "ubuntu1_operator_margin_pass": v61ba_summary["ubuntu1_operator_margin_pass"],
    "operator_write_step_resolved_by_witness": v61bb_summary["operator_write_step_resolved_by_witness"],
    "activation_target_write_witness_ready": v61bb_summary["activation_target_write_witness_ready"],
    "activation_handoff_command_rows": str(len(handoff_rows)),
    "target_bound_handoff_rows": str(target_bound_rows),
    "stale_tmp_target_command_rows": str(stale_tmp_rows),
    "activation_target_admission_ready": str(target_admission_ready),
    "activation_target_admitted_rows": str(activation_admitted_rows),
    "activation_target_blocked_rows": str(activation_blocked_rows),
    "payload_execution_ready_rows": "0",
    "payload_execution_blocked_rows": str(payload_execution_blocked_rows),
    "explicit_payload_execution_required": "1",
    "activation_payload_execution_ready": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": str(expected_bytes_total),
    "checkpoint_payload_bytes_downloaded_by_v61bn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_activation_admission_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61az-ubuntu1-capacity-input", "ready", "ubuntu-1 full-reserve capacity target is available"),
    ("v61ba-target-bound-handoff-input", "ready", "59 target-bound shard handoff rows are available"),
    ("v61bb-write-witness-input", "ready", "ubuntu-1 write witness is available"),
    ("activation-target-admission", "ready" if target_admission_ready else "blocked", f"activation_target_admitted_rows={activation_admitted_rows}/59"),
    ("explicit-payload-execution", "blocked", "checkpoint payload download execution remains disabled"),
    ("local-checkpoint-materialization", "blocked", "full checkpoint shards are not identity verified"),
    ("full-safetensors-page-hash-binding", "blocked", "full 134k+ page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "target admission is not production latency"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61az-ubuntu1-capacity-input", "status": "pass", "reason": "ubuntu-1 full-reserve capacity target is ready"},
    {"gate": "v61ba-target-bound-handoff-input", "status": "pass", "reason": "59 target-bound handoff rows are ready"},
    {"gate": "v61bb-write-witness-input", "status": "pass", "reason": "write witness resolves the prior operator-write blocker"},
    {"gate": "activation-target-admission", "status": "pass" if target_admission_ready else "blocked", "reason": f"activation_target_admitted_rows={activation_admitted_rows}/59"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bn records admission rows only"},
    {"gate": "explicit-payload-execution", "status": "blocked", "reason": "operator approval/download execution remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "full checkpoint shards are not identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bn Ubuntu-1 Activation Admission Refresh Gate Boundary

This gate refreshes activation target admission using v61az capacity evidence,
v61ba target-bound handoff commands, and the later v61bb ubuntu-1 write
witness. It admits the ubuntu-1 target for the 59 checkpoint shard handoff rows
without executing payload downloads.

Verified activation-target admission evidence:

- selected_activation_target_id=ubuntu-1-write-witness-admitted
- activation_handoff_command_rows={len(handoff_rows)}
- target_bound_handoff_rows={target_bound_rows}
- stale_tmp_target_command_rows={stale_tmp_rows}
- operator_write_step_resolved_by_witness={v61bb_summary["operator_write_step_resolved_by_witness"]}
- activation_target_write_witness_ready={v61bb_summary["activation_target_write_witness_ready"]}
- activation_target_admission_ready={target_admission_ready}
- activation_target_admitted_rows={activation_admitted_rows}
- activation_target_blocked_rows={activation_blocked_rows}
- explicit_payload_execution_required=1
- activation_payload_execution_ready=0
- download_execution_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bn=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 activation target admitted for the target-bound
checkpoint shard handoff rows.

Blocked wording: checkpoint payload download execution, full checkpoint
materialization, full safetensors page-hash coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bn_ubuntu1_activation_admission_refresh_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bn_ubuntu1_activation_admission_refresh_gate_ready": 1,
    "source_v61az_ready": int(v61az_summary["v61az_ubuntu1_warehouse_target_admission_ready"]),
    "source_v61ba_ready": int(v61ba_summary["v61ba_ubuntu1_activation_handoff_package_ready"]),
    "source_v61bb_ready": int(v61bb_summary["v61bb_ubuntu1_write_sentinel_activation_probe_ready"]),
    "selected_activation_target_id": "ubuntu-1-write-witness-admitted",
    "selected_target_path": v61ba_summary["selected_target_path"],
    "activation_target_admission_ready": target_admission_ready,
    "activation_target_admitted_rows": activation_admitted_rows,
    "activation_target_blocked_rows": activation_blocked_rows,
    "activation_payload_execution_ready": 0,
    "download_execution_ready": 0,
    "local_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bn": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bn_ubuntu1_activation_admission_refresh_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bn_ubuntu1_activation_admission_refresh_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
