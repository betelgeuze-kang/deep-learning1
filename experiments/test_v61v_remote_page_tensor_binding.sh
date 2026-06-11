#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61v_remote_page_tensor_binding/binding_001"
SUMMARY_CSV="$RESULTS_DIR/v61v_remote_page_tensor_binding_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61v_remote_page_tensor_binding_decision.csv"

V61V_REUSE_EXISTING="${V61V_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61v_remote_page_tensor_binding.sh" >/dev/null

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
    "v61v_remote_page_tensor_binding_ready": "1",
    "v61u_remote_checkpoint_page_hash_sampler_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "remote_page_hash_sample_rows": "16",
    "remote_sample_tensor_binding_rows": "16",
    "remote_sample_runtime_node_rows": "16",
    "remote_sample_tensor_role_rows": "4",
    "remote_hash_bound_rows": "16",
    "moe_expert_binding_rows": "15",
    "embedding_binding_rows": "1",
    "unique_layer_indices": "15",
    "unique_expert_indices": "8",
    "remote_sample_tensor_binding_ready": "1",
    "full_safetensors_page_hash_binding_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "checkpoint_payload_bytes_persisted": "0",
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
        raise SystemExit(f"v61v {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "selected_v61q_page_segment_rows.csv",
    "remote_sample_tensor_binding_rows.csv",
    "remote_sample_runtime_node_rows.csv",
    "remote_sample_tensor_role_summary_rows.csv",
    "remote_sample_tensor_coverage_rows.csv",
    "remote_sample_tensor_binding_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61V_REMOTE_PAGE_TENSOR_BINDING_BOUNDARY.md",
    "v61v_remote_page_tensor_binding_manifest.json",
    "sha256_manifest.csv",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_summary.csv",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_decision.csv",
    "source_v61u/remote_page_hash_sample_rows.csv",
    "source_v61u/remote_page_hash_page_map_overlap_rows.csv",
    "source_v61u/remote_page_hash_sample_metric_rows.csv",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_manifest.json",
    "source_v61u/sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_page_map_metric_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61v artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61u-remote-page-hash-sampler-input",
    "remote-sample-tensor-binding",
    "moe-expert-runtime-node-binding",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61v gate should pass: {gate}")
for gate in [
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61v gate should remain blocked: {gate}")

selected_segments = read_csv(run_dir / "selected_v61q_page_segment_rows.csv")
bindings = read_csv(run_dir / "remote_sample_tensor_binding_rows.csv")
nodes = read_csv(run_dir / "remote_sample_runtime_node_rows.csv")
roles = {row["tensor_role"]: row for row in read_csv(run_dir / "remote_sample_tensor_role_summary_rows.csv")}
coverage = {row["coverage_axis"]: row for row in read_csv(run_dir / "remote_sample_tensor_coverage_rows.csv")}
metric = read_csv(run_dir / "remote_sample_tensor_binding_metric_rows.csv")[0]
if len(selected_segments) != 16 or len(bindings) != 16 or len(nodes) != 16:
    raise SystemExit("v61v row counts mismatch")
expected_roles = {
    "embedding": "1",
    "moe_w1": "5",
    "moe_w2": "4",
    "moe_w3": "6",
}
for role, count in expected_roles.items():
    if roles.get(role, {}).get("binding_rows") != count:
        raise SystemExit(f"v61v role {role} expected {count}, got {roles.get(role)}")
if metric["remote_sample_tensor_binding_ready"] != "1" or metric["full_safetensors_page_hash_binding_ready"] != "0":
    raise SystemExit("v61v metric readiness boundary mismatch")
for row in bindings:
    if row["remote_hash_bound"] != "1" or row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61v bindings should be remote-hash-bound metadata only")
    if row["tensor_role"].startswith("moe_"):
        if row["moe_expert_page"] != "1" or row["layer_index"] == "" or row["expert_index"] == "":
            raise SystemExit("v61v MoE bindings should include layer and expert")
    if row["tensor_role"] == "embedding" and row["embedding_page"] != "1":
        raise SystemExit("v61v embedding binding mismatch")
for row in nodes:
    if row["remote_hash_bound"] != "1" or row["local_resident"] != "0" or row["page_hash_full_coverage_ready"] != "0":
        raise SystemExit("v61v runtime nodes should keep local/full-coverage blockers")
    if row["node_type"] == "moe_expert_page_node" and row["prefetch_candidate"] != "1":
        raise SystemExit("v61v MoE runtime nodes should be prefetch candidates")
for axis in ["remote_samples", "tensor_bindings", "moe_expert_bindings", "layer_indices", "expert_indices"]:
    if coverage.get(axis, {}).get("coverage_ready") != "1":
        raise SystemExit(f"v61v coverage axis should be ready: {axis}")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in ["remote-sample-tensor-binding", "moe-expert-runtime-node-binding"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61v gap should be ready: {gap}")
for gap in [
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61v gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61v_remote_page_tensor_binding_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61v_remote_page_tensor_binding_ready") != 1:
    raise SystemExit("v61v manifest readiness mismatch")
if manifest.get("moe_expert_binding_rows") != 15 or manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61v manifest boundary mismatch")

boundary = (run_dir / "V61V_REMOTE_PAGE_TENSOR_BINDING_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "remote_page_hash_sample_rows=16",
    "remote_sample_tensor_binding_rows=16",
    "moe_expert_binding_rows=15",
    "unique_layer_indices=15",
    "unique_expert_indices=8",
    "full_safetensors_page_hash_binding_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61v boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61v sha256 mismatch: {rel}")
PY

echo "v61v remote page tensor binding smoke passed"
