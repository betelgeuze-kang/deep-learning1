#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bn_ubuntu1_activation_admission_refresh_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61bn_ubuntu1_activation_admission_refresh_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bn_ubuntu1_activation_admission_refresh_gate_decision.csv"

V61BN_REUSE_EXISTING="${V61BN_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bn_ubuntu1_activation_admission_refresh_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "v61bn_ubuntu1_activation_admission_refresh_gate_ready": "1",
    "v61az_ubuntu1_warehouse_target_admission_ready": "1",
    "v61ba_ubuntu1_activation_handoff_package_ready": "1",
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": "1",
    "selected_capacity_target_id": "ubuntu-1-full-reserve-capacity",
    "selected_activation_target_id": "ubuntu-1-write-witness-admitted",
    "selected_target_path": ubuntu1_target,
    "selected_backend_id": "curl-resume",
    "selected_backend_ready": "1",
    "ubuntu1_available_bytes_live": "410581364736",
    "required_with_reserve_bytes": "315601231712",
    "ubuntu1_full_reserve_capacity_pass": "1",
    "ubuntu1_operator_margin_pass": "0",
    "operator_write_step_resolved_by_witness": "1",
    "activation_target_write_witness_ready": "1",
    "activation_handoff_command_rows": "59",
    "target_bound_handoff_rows": "59",
    "stale_tmp_target_command_rows": "0",
    "activation_target_admission_ready": "1",
    "activation_target_admitted_rows": "59",
    "activation_target_blocked_rows": "0",
    "payload_execution_ready_rows": "0",
    "payload_execution_blocked_rows": "59",
    "explicit_payload_execution_required": "1",
    "activation_payload_execution_ready": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": "281241493344",
    "checkpoint_payload_bytes_downloaded_by_v61bn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bn {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_activation_admission_rows.csv",
    "ubuntu1_activation_admission_requirement_rows.csv",
    "ubuntu1_activation_admission_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md",
    "v61bn_ubuntu1_activation_admission_refresh_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61az/ubuntu1_warehouse_admission_rows.csv",
    "source_v61ba/ubuntu1_activation_handoff_command_rows.csv",
    "source_v61bb/ubuntu1_write_sentinel_witness_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bn artifact: {rel}")

activation_rows = read_csv(run_dir / "ubuntu1_activation_admission_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_activation_admission_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_activation_admission_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(activation_rows) != 59:
    raise SystemExit("v61bn activation admission row count mismatch")
if any(row["target_activation_admitted"] != "1" for row in activation_rows):
    raise SystemExit("v61bn all target activation rows must be admitted")
if any(row["payload_execution_ready"] != "0" for row in activation_rows):
    raise SystemExit("v61bn must keep payload execution blocked")
if any(row["download_execution_ready"] != "0" for row in activation_rows):
    raise SystemExit("v61bn must not claim download execution")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in activation_rows):
    raise SystemExit("v61bn must not commit checkpoint payload bytes")
if any(not row["target_path"].startswith(ubuntu1_target) for row in activation_rows):
    raise SystemExit("v61bn all target paths must remain under ubuntu-1")
if any("/tmp/" in row["target_path"] for row in activation_rows):
    raise SystemExit("v61bn must not contain stale /tmp target paths")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bn metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61az-ubuntu1-capacity-input",
    "v61ba-target-bound-handoff-input",
    "v61bb-write-witness-input",
    "activation-target-admission",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bn requirement should pass: {requirement_id}")
if requirements["explicit-payload-execution"]["status"] != "blocked":
    raise SystemExit("v61bn explicit payload execution should stay blocked")

for gate in [
    "v61az-ubuntu1-capacity-input",
    "v61ba-target-bound-handoff-input",
    "v61bb-write-witness-input",
    "activation-target-admission",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bn gate should pass: {gate}")
for gate in [
    "explicit-payload-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bn gate should stay blocked: {gate}")

for gap in [
    "v61az-ubuntu1-capacity-input",
    "v61ba-target-bound-handoff-input",
    "v61bb-write-witness-input",
    "activation-target-admission",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bn gap should be ready: {gap}")
for gap in [
    "explicit-payload-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bn gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bn_ubuntu1_activation_admission_refresh_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bn_ubuntu1_activation_admission_refresh_gate_ready") != 1:
    raise SystemExit("v61bn manifest readiness mismatch")
if manifest.get("activation_target_admission_ready") != 1:
    raise SystemExit("v61bn manifest target admission mismatch")
if manifest.get("activation_payload_execution_ready") != 0:
    raise SystemExit("v61bn manifest must keep payload execution blocked")

boundary = (run_dir / "V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_activation_target_id=ubuntu-1-write-witness-admitted",
    "activation_handoff_command_rows=59",
    "target_bound_handoff_rows=59",
    "stale_tmp_target_command_rows=0",
    "operator_write_step_resolved_by_witness=1",
    "activation_target_admission_ready=1",
    "activation_target_admitted_rows=59",
    "explicit_payload_execution_required=1",
    "activation_payload_execution_ready=0",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bn=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bn boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bn sha256 mismatch: {rel}")
PY
