#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61w_materialization_admission_resume_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61w_materialization_admission_resume_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61w_materialization_admission_resume_plan_decision.csv"

V61W_REUSE_EXISTING="${V61W_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null

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
    "v61w_materialization_admission_resume_plan_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61v_remote_page_tensor_binding_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "download_resume_plan_rows": "59",
    "sampled_priority_shard_rows": "16",
    "moe_priority_shard_rows": "15",
    "embedding_priority_shard_rows": "1",
    "remote_sample_tensor_binding_rows": "16",
    "warehouse_root_override_supplied": "0",
    "download_resume_plan_ready": "1",
    "moe_first_priority_plan_ready": "1",
    "materialization_admission_ready": "0",
    "materialization_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61w": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61w {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_shard_priority_rows.csv",
    "checkpoint_download_resume_plan_rows.csv",
    "materialization_admission_rows.csv",
    "materialization_stage_rows.csv",
    "materialization_runtime_gap_rows.csv",
    "materialization_admission_metric_rows.csv",
    "V61W_MATERIALIZATION_ADMISSION_RESUME_PLAN_BOUNDARY.md",
    "v61w_materialization_admission_resume_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/checkpoint_download_plan_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
    "source_v61v/remote_sample_runtime_node_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61w artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61p-local-ssd-residency-preflight-input",
    "v61q-real-checkpoint-page-map-input",
    "v61t-local-materialization-verifier-input",
    "v61v-remote-page-tensor-binding-input",
    "download-resume-plan",
    "moe-first-priority-plan",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61w gate should pass: {gate}")
for gate in [
    "ssd-disk-budget-admission",
    "materialization-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61w gate should remain blocked: {gate}")

priority_rows = read_csv(run_dir / "checkpoint_shard_priority_rows.csv")
resume_rows = read_csv(run_dir / "checkpoint_download_resume_plan_rows.csv")
admission_rows = {row["gate"]: row for row in read_csv(run_dir / "materialization_admission_rows.csv")}
stages = {row["stage"]: row for row in read_csv(run_dir / "materialization_stage_rows.csv")}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "materialization_runtime_gap_rows.csv")}
metric = read_csv(run_dir / "materialization_admission_metric_rows.csv")[0]

if len(priority_rows) != 59 or len(resume_rows) != 59:
    raise SystemExit("v61w shard plan row counts mismatch")
if priority_rows[0]["priority_class"] != "p0_remote_moe_sampled":
    raise SystemExit("v61w should prioritize a remote-hashed MoE shard first")
if sum(1 for row in priority_rows if row["priority_class"] == "p0_remote_moe_sampled") != 15:
    raise SystemExit("v61w MoE priority shard count mismatch")
if sum(1 for row in priority_rows if row["priority_class"] == "p0_embedding_sampled") != 1:
    raise SystemExit("v61w embedding priority shard count mismatch")
if sum(1 for row in priority_rows if int(row["remote_sample_tensor_binding_rows"]) > 0) != 16:
    raise SystemExit("v61w sampled priority shard count mismatch")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in priority_rows):
    raise SystemExit("v61w priority rows must not commit checkpoint payload")
if any(row["checkpoint_payload_bytes_downloaded_by_v61w"] != "0" for row in resume_rows):
    raise SystemExit("v61w resume rows must not download checkpoint payload")
if any(row["writes_inside_repository"] != "0" for row in resume_rows):
    raise SystemExit("v61w resume plan must not target repository payload writes")
if any(row["resume_supported"] != "1" for row in resume_rows):
    raise SystemExit("v61w resume plan should preserve resume support")

for gate in ["download-resume-plan", "moe-first-priority-plan", "manifest-only-no-repo-payload"]:
    if admission_rows.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v61w admission row should pass: {gate}")
for gate in ["ssd-disk-budget", "local-checkpoint-materialization", "full-safetensors-page-hash-binding"]:
    if admission_rows.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v61w admission row should stay blocked: {gate}")

if stages["download-resume-by-priority"]["status"] != "planned":
    raise SystemExit("v61w download stage should be planned")
for stage in [
    "ssd-disk-budget-admission",
    "post-download-size-header-sampled-page-verify",
    "full-safetensors-page-hash-sweep",
    "runtime-node-residency-promote",
    "real-model-source-bound-generation",
    "production-and-release-claims",
]:
    if stages[stage]["status"] != "blocked":
        raise SystemExit(f"v61w stage should be blocked: {stage}")

for gap in ["download-resume-plan", "moe-first-shard-priority"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61w gap should be ready: {gap}")
for gap in [
    "ssd-disk-budget-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61w gap should be blocked: {gap}")

if metric["download_resume_plan_ready"] != "1" or metric["moe_first_priority_plan_ready"] != "1":
    raise SystemExit("v61w metric plan readiness mismatch")
if metric["materialization_admission_ready"] != "0" or metric["materialization_execution_ready"] != "0":
    raise SystemExit("v61w metric should keep materialization blocked")

manifest = json.loads((run_dir / "v61w_materialization_admission_resume_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61w_materialization_admission_resume_plan_ready") != 1:
    raise SystemExit("v61w manifest readiness mismatch")
if manifest.get("download_resume_plan_rows") != 59 or manifest.get("moe_priority_shard_rows") != 15:
    raise SystemExit("v61w manifest row counts mismatch")
if manifest.get("materialization_admission_ready") != 0 or manifest.get("local_checkpoint_materialization_ready") != 0:
    raise SystemExit("v61w manifest should keep materialization blocked")
if manifest.get("warehouse_root_override_supplied") != 0:
    raise SystemExit("v61w manifest should record no default warehouse override")

boundary = (run_dir / "V61W_MATERIALIZATION_ADMISSION_RESUME_PLAN_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "download_resume_plan_rows=59",
    "sampled_priority_shard_rows=16",
    "moe_priority_shard_rows=15",
    "warehouse_root_override_supplied=0",
    "download_resume_plan_ready=1",
    "materialization_admission_ready=0",
    "local_checkpoint_materialization_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61w boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61w sha256 mismatch: {rel}")
PY

echo "v61w materialization admission resume plan smoke passed"
