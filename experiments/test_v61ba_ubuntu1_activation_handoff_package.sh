#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ba_ubuntu1_activation_handoff_package/handoff_001"
SUMMARY_CSV="$RESULTS_DIR/v61ba_ubuntu1_activation_handoff_package_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ba_ubuntu1_activation_handoff_package_decision.csv"

V61BA_REUSE_EXISTING="${V61BA_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ba_ubuntu1_activation_handoff_package.sh" >/dev/null

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
    "v61ba_ubuntu1_activation_handoff_package_ready": "1",
    "v61az_ubuntu1_warehouse_target_admission_ready": "1",
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "selected_capacity_target_id": "ubuntu-1-full-reserve-capacity",
    "selected_target_path": ubuntu1_target,
    "selected_backend_id": "curl-resume",
    "selected_backend_ready": "1",
    "required_with_reserve_bytes": "315601231712",
    "recommended_operator_free_bytes": "549755813888",
    "ubuntu1_full_reserve_capacity_pass": "1",
    "target_parent_write_access_ready": "0",
    "operator_write_step_required": "1",
    "activation_handoff_command_rows": "59",
    "target_path_ubuntu1_rows": "59",
    "download_command_ubuntu1_rows": "59",
    "target_bound_verify_command_rows": "59",
    "target_bound_full_page_hash_command_rows": "59",
    "target_bound_generation_recheck_command_rows": "59",
    "stale_tmp_target_command_rows": "0",
    "p0_remote_moe_sampled_rows": "15",
    "p0_embedding_sampled_rows": "1",
    "p2_checkpoint_backfill_rows": "43",
    "total_expected_checkpoint_bytes": "281241493344",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ba {field}: expected {value}, got {summary.get(field)}")

available = int(summary["ubuntu1_available_bytes_live"])
required = int(summary["required_with_reserve_bytes"])
operator_margin = int(summary["recommended_operator_free_bytes"])
if available < required:
    raise SystemExit("v61ba ubuntu-1 available bytes should cover full reserve")
if summary["ubuntu1_operator_margin_pass"] != str(int(available >= operator_margin)):
    raise SystemExit("v61ba operator margin pass should match live bytes")

required_files = [
    "ubuntu1_activation_handoff_command_rows.csv",
    "ubuntu1_activation_handoff_requirement_rows.csv",
    "ubuntu1_activation_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BA_UBUNTU1_ACTIVATION_HANDOFF_BOUNDARY.md",
    "v61ba_ubuntu1_activation_handoff_package_manifest.json",
    "sha256_manifest.csv",
    "source_v61az/ubuntu1_warehouse_capacity_rows.csv",
    "source_v61ah/checkpoint_download_backend_plan_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ba artifact: {rel}")

handoff_rows = read_csv(run_dir / "ubuntu1_activation_handoff_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_activation_handoff_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_activation_handoff_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(handoff_rows) != 59:
    raise SystemExit("v61ba should emit 59 handoff command rows")
if [row["priority_rank"] for row in handoff_rows[:4]] != ["1", "2", "3", "4"]:
    raise SystemExit("v61ba priority ordering mismatch")
if any(row["selected_backend_id"] != "curl-resume" for row in handoff_rows):
    raise SystemExit("v61ba selected backend mismatch")
if any(row["selected_backend_ready"] != "1" for row in handoff_rows):
    raise SystemExit("v61ba selected backend should be ready")
if any(row["selected_capacity_target_id"] != "ubuntu-1-full-reserve-capacity" for row in handoff_rows):
    raise SystemExit("v61ba selected capacity target mismatch")
if any(not row["target_path"].startswith(ubuntu1_target + "/") for row in handoff_rows):
    raise SystemExit("v61ba target paths should point to ubuntu-1")
for field in [
    "download_command_preview",
    "post_download_verify_command",
    "post_download_full_page_hash_command",
    "post_download_generation_admission_command",
]:
    if any(ubuntu1_target not in row[field] for row in handoff_rows):
        raise SystemExit(f"v61ba {field} should be target-bound to ubuntu-1")
    if any("/tmp/v61aj-warehouse-override" in row[field] for row in handoff_rows):
        raise SystemExit(f"v61ba {field} should not retain stale tmp target")
if any(row["handoff_command_ready"] != "1" for row in handoff_rows):
    raise SystemExit("v61ba handoff commands should be ready")
if any(row["activation_execution_ready"] != "0" for row in handoff_rows):
    raise SystemExit("v61ba must not mark activation execution ready")
if any(row["dry_run_default"] != "1" for row in handoff_rows):
    raise SystemExit("v61ba handoff commands should default to dry-run")
if any(row["explicit_execute_required"] != "1" for row in handoff_rows):
    raise SystemExit("v61ba handoff commands should require explicit execution")
if any(row["requires_operator_or_escalated_write"] != "1" for row in handoff_rows):
    raise SystemExit("v61ba handoff commands should require operator/escalated write")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ba"] != "0" for row in handoff_rows):
    raise SystemExit("v61ba must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in handoff_rows):
    raise SystemExit("v61ba must not commit checkpoint payload bytes")

for requirement_id in [
    "v61az-ubuntu1-capacity-input",
    "v61ah-backend-plan-input",
    "ubuntu1-full-reserve-capacity",
    "target-bound-command-rewrite",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ba requirement should pass: {requirement_id}")
if requirements["operator-margin-capacity"]["status"] not in {"pass", "recommended"}:
    raise SystemExit("v61ba operator-margin requirement should be pass or recommended")
for requirement_id in ["target-parent-write-access", "explicit-download-execution"]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ba requirement should stay blocked: {requirement_id}")

for gate in [
    "v61az-ubuntu1-capacity-input",
    "v61ah-backend-plan-input",
    "ubuntu1-full-reserve-capacity",
    "target-bound-command-rewrite",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ba gate should pass: {gate}")
for gate in [
    "target-parent-write-access",
    "explicit-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ba gate should remain blocked: {gate}")

for gap in [
    "v61az-ubuntu1-capacity-input",
    "v61ah-backend-plan-input",
    "target-bound-command-rewrite",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ba gap should be ready: {gap}")
if gaps.get("operator-margin-capacity") not in {"ready", "recommended-gap"}:
    raise SystemExit("v61ba operator margin gap should be ready or recommended-gap")
for gap in [
    "target-parent-write-access",
    "explicit-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ba gap should stay blocked: {gap}")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ba metric {field}: expected {value}, got {metric[field]}")

manifest = json.loads((run_dir / "v61ba_ubuntu1_activation_handoff_package_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ba_ubuntu1_activation_handoff_package_ready") != 1:
    raise SystemExit("v61ba manifest readiness mismatch")
if manifest.get("activation_handoff_command_rows") != 59:
    raise SystemExit("v61ba manifest command row mismatch")
if manifest.get("stale_tmp_target_command_rows") != 0:
    raise SystemExit("v61ba manifest stale target mismatch")
if manifest.get("activation_execution_ready") != 0:
    raise SystemExit("v61ba manifest must keep activation execution blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ba") != 0:
    raise SystemExit("v61ba manifest must not download payload bytes")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ba manifest must not commit payload bytes")

boundary = (run_dir / "V61BA_UBUNTU1_ACTIVATION_HANDOFF_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "activation_handoff_command_rows=59",
    "target_bound_verify_command_rows=59",
    "target_bound_full_page_hash_command_rows=59",
    "target_bound_generation_recheck_command_rows=59",
    "stale_tmp_target_command_rows=0",
    "activation_execution_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ba boundary missing snippet: {snippet}")

sha_rows = read_csv(run_dir / "sha256_manifest.csv")
if not sha_rows:
    raise SystemExit("v61ba sha manifest should not be empty")
for row in sha_rows:
    rel = row["path"]
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"v61ba sha manifest points to missing file: {rel}")
    if sha256(path) != row["sha256"]:
        raise SystemExit(f"v61ba sha mismatch: {rel}")

print("v61ba ubuntu-1 activation handoff package smoke passed")
PY
