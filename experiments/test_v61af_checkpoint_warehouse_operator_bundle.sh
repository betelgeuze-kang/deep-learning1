#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61af_checkpoint_warehouse_operator_bundle/operator_001"
SUMMARY_CSV="$RESULTS_DIR/v61af_checkpoint_warehouse_operator_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61af_checkpoint_warehouse_operator_bundle_decision.csv"

V61AF_REUSE_EXISTING="${V61AF_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import subprocess
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
    "v61af_checkpoint_warehouse_operator_bundle_ready": "1",
    "v61w_materialization_admission_resume_plan_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v61ae_real_generation_admission_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "download_command_rows": "59",
    "operator_command_rows": "62",
    "operator_bundle_file_rows": "6",
    "sampled_priority_shard_rows": "16",
    "moe_priority_shard_rows": "15",
    "embedding_priority_shard_rows": "1",
    "planned_remaining_bytes": "281241493344",
    "required_with_reserve_bytes": "315601231712",
    "ssd_disk_budget_pass": "0",
    "ssd_warehouse_outside_repo": "1",
    "warehouse_root_override_supplied": "0",
    "download_dry_run_default": "1",
    "full_hash_dry_run_default": "1",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "generation_candidate_rows": "1000",
    "generation_admitted_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61af": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61af {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_warehouse_operator_command_rows.csv",
    "checkpoint_warehouse_operator_stage_rows.csv",
    "checkpoint_warehouse_operator_metric_rows.csv",
    "operator_bundle/README.md",
    "operator_bundle/operator_env.template",
    "operator_bundle/download_priority_queue.sh",
    "operator_bundle/verify_materialization.sh",
    "operator_bundle/run_full_page_hash_sweep.sh",
    "operator_bundle/recheck_real_generation_admission.sh",
    "V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md",
    "v61af_checkpoint_warehouse_operator_bundle_manifest.json",
    "sha256_manifest.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61w/checkpoint_download_resume_plan_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
    "source_v61r/page_hash_sweep_metric_rows.csv",
    "source_v61ae/real_generation_admission_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61af artifact: {rel}")

for rel in [
    "operator_bundle/download_priority_queue.sh",
    "operator_bundle/verify_materialization.sh",
    "operator_bundle/run_full_page_hash_sweep.sh",
    "operator_bundle/recheck_real_generation_admission.sh",
]:
    subprocess.run(["bash", "-n", str(run_dir / rel)], check=True)

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61w-materialization-plan-input",
    "v61t-materialization-verifier-input",
    "v61r-page-hash-sweep-input",
    "v61ae-generation-admission-input",
    "operator-bundle-files",
    "download-dry-run-default",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61af gate should pass: {gate}")
for gate in [
    "ssd-disk-budget-admission",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61af gate should stay blocked: {gate}")

command_rows = read_csv(run_dir / "checkpoint_warehouse_operator_command_rows.csv")
stage_rows = {row["stage"]: row["status"] for row in read_csv(run_dir / "checkpoint_warehouse_operator_stage_rows.csv")}
metric = read_csv(run_dir / "checkpoint_warehouse_operator_metric_rows.csv")[0]
source_v61p_summary = read_csv(run_dir / "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]

if summary["available_ssd_bytes"] != source_v61p_summary["available_ssd_bytes"]:
    raise SystemExit("v61af available_ssd_bytes should match copied v61p summary")
if metric["available_ssd_bytes"] != summary["available_ssd_bytes"]:
    raise SystemExit("v61af metric available_ssd_bytes should match summary")

if len(command_rows) != 62:
    raise SystemExit("v61af operator command row count mismatch")
download_rows = [row for row in command_rows if row["command_type"] == "download-resume"]
if len(download_rows) != 59:
    raise SystemExit("v61af download command row count mismatch")
if sum(1 for row in command_rows if row["requires_explicit_execute"] == "1") != 60:
    raise SystemExit("v61af explicit execute guard count mismatch")
if any(row["writes_inside_repository"] != "0" for row in command_rows):
    raise SystemExit("v61af operator commands must not write payloads inside the repository")
if any(row["checkpoint_payload_bytes_downloaded_by_v61af"] != "0" for row in command_rows):
    raise SystemExit("v61af must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in command_rows):
    raise SystemExit("v61af must not commit checkpoint payload bytes")
if download_rows[0]["stage"] != "download-priority-shard" or download_rows[0]["priority_rank"] != "1":
    raise SystemExit("v61af first download row priority mismatch")

for stage in [
    "v61w-materialization-plan-input",
    "operator-bundle-files",
    "download-dry-run-default",
]:
    if stage_rows.get(stage) != "ready":
        raise SystemExit(f"v61af stage should be ready: {stage}")
for stage in [
    "download-execution",
    "post-download-identity-verify",
    "full-page-hash-sweep",
    "real-generation-admission-recheck",
    "release-package",
]:
    if stage_rows.get(stage) != "blocked":
        raise SystemExit(f"v61af stage should stay blocked: {stage}")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61af metric {field}: expected {value}, got {metric[field]}")

download_script = (run_dir / "operator_bundle/download_priority_queue.sh").read_text(encoding="utf-8")
full_hash_script = (run_dir / "operator_bundle/run_full_page_hash_sweep.sh").read_text(encoding="utf-8")
operator_env = (run_dir / "operator_bundle/operator_env.template").read_text(encoding="utf-8")
operator_readme = (run_dir / "operator_bundle/README.md").read_text(encoding="utf-8")
boundary = (run_dir / "V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "V61AF_EXECUTE_DOWNLOAD",
    "dry-run",
    "huggingface-cli download",
]:
    if snippet not in download_script:
        raise SystemExit(f"v61af download script missing snippet: {snippet}")
for snippet in [
    "V61AF_EXECUTE_FULL_HASH",
    "dry-run",
    "V61R_ENABLE_LOCAL_HASH_SWEEP=1",
]:
    if snippet not in full_hash_script:
        raise SystemExit(f"v61af full hash script missing snippet: {snippet}")
for snippet in [
    "V61AF_WAREHOUSE_ROOT",
    "V61T_WAREHOUSE_ROOT",
    "V61R_WAREHOUSE_ROOT",
    "V61AE_WAREHOUSE_ROOT",
]:
    if snippet not in operator_env:
        raise SystemExit(f"v61af operator env missing snippet: {snippet}")
for snippet in [
    "download_command_rows=59",
    "warehouse_root_override_supplied=0",
    "generation_admitted_rows=0",
    "checkpoint_payload_bytes_downloaded_by_v61af=0",
]:
    if snippet not in operator_readme:
        raise SystemExit(f"v61af operator README missing snippet: {snippet}")
for snippet in [
    "operator_command_rows=62",
    "download_dry_run_default=1",
    "full_hash_dry_run_default=1",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61af boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61af_checkpoint_warehouse_operator_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61af_checkpoint_warehouse_operator_bundle_ready") != 1:
    raise SystemExit("v61af manifest readiness mismatch")
if manifest.get("operator_command_rows") != 62 or manifest.get("download_command_rows") != 59:
    raise SystemExit("v61af manifest command row mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61af") != 0:
    raise SystemExit("v61af manifest must keep downloaded payload bytes at zero")
if manifest.get("warehouse_root_override_supplied") != 0:
    raise SystemExit("v61af manifest should record no default warehouse override")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61af sha256 mismatch: {rel}")
PY

echo "v61af checkpoint warehouse operator bundle smoke passed"
