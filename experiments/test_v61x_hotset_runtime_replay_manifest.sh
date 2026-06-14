#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61x_hotset_runtime_replay_manifest/hotset_001"
SUMMARY_CSV="$RESULTS_DIR/v61x_hotset_runtime_replay_manifest_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61x_hotset_runtime_replay_manifest_decision.csv"

V61X_REUSE_EXISTING="${V61X_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61x_hotset_runtime_replay_manifest.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def inside_repo(path):
    try:
        Path(path).resolve().relative_to(root)
        return 1
    except ValueError:
        return 0


summary = read_csv(summary_csv)[0]
source_v61s_summary = read_csv(run_dir / "source_v61s/v61s_one_command_source_bound_qa_replay_summary.csv")[0]
source_bound_query_rows = source_v61s_summary["source_bound_query_rows"]
expected = {
    "v61x_hotset_runtime_replay_manifest_ready": "1",
    "v61w_materialization_admission_resume_plan_ready": "1",
    "v61v_remote_page_tensor_binding_ready": "1",
    "v61s_one_command_source_bound_qa_replay_ready": "1",
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "hotset_page_rows": "16",
    "hotset_runtime_slot_rows": "16",
    "hotset_workload_binding_rows": source_bound_query_rows,
    "moe_hotset_page_rows": "15",
    "embedding_hotset_page_rows": "1",
    "remote_hash_bound_rows": "16",
    "remote_page_hash_sample_ready_rows": "16",
    "source_bound_query_rows": source_bound_query_rows,
    "source_bound_query_pass_rows": source_bound_query_rows,
    "hotset_manifest_ready": "1",
    "source_bound_replay_binding_ready": "1",
    "hotset_payload_materialization_ready": "0",
    "hotset_runtime_execution_ready": "0",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61x": "0",
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
        raise SystemExit(f"v61x {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "hotset_runtime_page_rows.csv",
    "hotset_runtime_slot_rows.csv",
    "hotset_source_bound_workload_binding_rows.csv",
    "hotset_runtime_replay_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61X_HOTSET_RUNTIME_REPLAY_MANIFEST_BOUNDARY.md",
    "v61x_hotset_runtime_replay_manifest.json",
    "sha256_manifest.csv",
    "source_v61m/kv_residency_policy_rows.csv",
    "source_v61s/source_bound_workload_pass_rows.csv",
    "source_v61u/remote_page_hash_sample_rows.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
    "source_v61v/remote_sample_runtime_node_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61x artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61w-materialization-plan-input",
    "v61v-remote-page-tensor-binding-input",
    "v61m-kv-cache-policy-input",
    "v61s-source-bound-replay-input",
    "nvme-hotset-manifest",
    "source-bound-replay-binding",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61x gate should pass: {gate}")
for gate in [
    "hotset-payload-materialization",
    "ssd-disk-budget-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61x gate should remain blocked: {gate}")

page_rows = read_csv(run_dir / "hotset_runtime_page_rows.csv")
slot_rows = read_csv(run_dir / "hotset_runtime_slot_rows.csv")
workload_rows = read_csv(run_dir / "hotset_source_bound_workload_binding_rows.csv")
metric = read_csv(run_dir / "hotset_runtime_replay_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(page_rows) != 16 or len(slot_rows) != 16 or len(workload_rows) != int(source_bound_query_rows):
    raise SystemExit("v61x artifact row counts mismatch")
if sum(1 for row in page_rows if row["node_type"] == "moe_expert_page_node") != 15:
    raise SystemExit("v61x MoE hotset page count mismatch")
if sum(1 for row in page_rows if row["node_type"] == "embedding_page_node") != 1:
    raise SystemExit("v61x embedding hotset page count mismatch")
if any(row["planned_local_page_path_inside_repository"] != "0" for row in page_rows):
    raise SystemExit("v61x hotset planned paths must be outside the repository")
if any(inside_repo(row["planned_local_page_path"]) for row in page_rows):
    raise SystemExit("v61x hotset planned paths resolve inside repository")
if any(row["remote_hash_bound"] != "1" for row in page_rows):
    raise SystemExit("v61x all hotset pages must be remote-hash bound")
if any(row["remote_page_hash_sample_ready"] != "1" for row in page_rows):
    raise SystemExit("v61x all hotset pages must have ready remote samples")
if any(row["expected_page_bytes"] != "2097152" for row in page_rows):
    raise SystemExit("v61x hotset pages should be 2 MiB")
if any(row["remote_page_bytes_read"] != "2097152" for row in page_rows):
    raise SystemExit("v61x remote sample pages should be full 2 MiB")
if any(row["local_page_payload_materialized"] != "0" for row in page_rows):
    raise SystemExit("v61x must not claim hotset payload materialization")
if any(row["checkpoint_payload_bytes_downloaded_by_v61x"] != "0" for row in page_rows):
    raise SystemExit("v61x must not download checkpoint payload")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in page_rows + slot_rows):
    raise SystemExit("v61x must not commit checkpoint payload")
if any(row["host_ram_kv_spill_enabled"] != "0" for row in page_rows):
    raise SystemExit("v61x must preserve host-RAM KV spill disabled")
if any(row["kv_policy_compatible"] != "1" for row in slot_rows):
    raise SystemExit("v61x slots must be KV-policy compatible")
if any(row["local_resident"] != "0" for row in slot_rows):
    raise SystemExit("v61x slots must not claim local residency")
if any(row["source_bound_query_pass"] != "1" for row in workload_rows):
    raise SystemExit("v61x workload rows must preserve source-bound pass status")
if any(row["hotset_page_rows_bound"] != "16" for row in workload_rows):
    raise SystemExit("v61x workload rows must bind 16 hotset pages")
if any(row["hotset_payload_materialization_ready"] != "0" for row in workload_rows):
    raise SystemExit("v61x workload rows must keep hotset materialization blocked")
if any(row["actual_model_generation_ready"] != "0" for row in workload_rows):
    raise SystemExit("v61x workload rows must keep generation blocked")

if metric["hotset_manifest_ready"] != "1" or metric["source_bound_replay_binding_ready"] != "1":
    raise SystemExit("v61x metric readiness mismatch")
for field in [
    "hotset_payload_materialization_ready",
    "hotset_runtime_execution_ready",
    "materialization_admission_ready",
    "local_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61x metric should keep {field}=0")

for gap in [
    "v61w-materialization-plan-input",
    "v61v-remote-tensor-binding-input",
    "v61m-kv-policy-input",
    "v61s-source-bound-replay-input",
    "nvme-hotset-manifest",
    "source-bound-replay-binding",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61x gap should be ready: {gap}")
for gap in [
    "hotset-payload-materialization",
    "ssd-disk-budget-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61x gap should be blocked: {gap}")

manifest = json.loads((run_dir / "v61x_hotset_runtime_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61x_hotset_runtime_replay_manifest_ready") != 1:
    raise SystemExit("v61x manifest readiness mismatch")
if manifest.get("hotset_page_rows") != 16 or manifest.get("hotset_workload_binding_rows") != int(source_bound_query_rows):
    raise SystemExit("v61x manifest row counts mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61x") != 0:
    raise SystemExit("v61x manifest should record zero v61x payload downloads")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61x manifest should record zero repo payload bytes")
if manifest.get("hotset_payload_materialization_ready") != 0:
    raise SystemExit("v61x manifest should keep hotset materialization blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61x manifest should keep generation blocked")
if manifest.get("hotset_warehouse_inside_repository") != 0:
    raise SystemExit("v61x manifest warehouse should be outside repository")

boundary = (run_dir / "V61X_HOTSET_RUNTIME_REPLAY_MANIFEST_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "hotset_page_rows=16",
    "moe_hotset_page_rows=15",
    "embedding_hotset_page_rows=1",
    f"source_bound_query_pass_rows={source_bound_query_rows}",
    "hotset_manifest_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61x=0",
    "hotset_payload_materialization_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61x boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61x sha256 mismatch: {rel}")
PY

echo "v61x hotset runtime replay manifest smoke passed"
