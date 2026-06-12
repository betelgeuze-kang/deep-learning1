#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ao_real_model_page_manifest_coverage_audit/audit_001"
SUMMARY_CSV="$RESULTS_DIR/v61ao_real_model_page_manifest_coverage_audit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ao_real_model_page_manifest_coverage_audit_decision.csv"

V61AO_REUSE_EXISTING="${V61AO_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ao_real_model_page_manifest_coverage_audit.sh" >/dev/null

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
    "v61ao_real_model_page_manifest_coverage_audit_ready": "1",
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61v_remote_page_tensor_binding_ready": "1",
    "v61an_checkpoint_full_page_hash_execution_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "checkpoint_tensor_rows": "1739",
    "checkpoint_unique_page_rows": "134161",
    "checkpoint_page_segment_rows": "135841",
    "checkpoint_payload_pages": "134161",
    "checkpoint_full_payload_pages": "134102",
    "checkpoint_partial_payload_pages": "59",
    "mapped_tensor_payload_bytes": "281241268224",
    "total_checkpoint_bytes_required": "281241493344",
    "header_and_metadata_bytes": "225120",
    "tensor_role_coverage_rows": "8",
    "moe_layer_expert_tensor_coverage_rows": "1344",
    "moe_layer_expert_tensor_coverage_ready_rows": "1344",
    "covered_moe_layer_indices": "56",
    "covered_moe_expert_indices": "8",
    "covered_moe_tensor_roles": "3",
    "remote_page_hash_sample_rows": "16",
    "remote_hash_bound_tensor_rows": "16",
    "remote_hash_bound_moe_rows": "15",
    "real_model_page_manifest_coverage_ready": "1",
    "required_page_hash_rows": "134161",
    "local_full_page_hash_verified_rows": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ao": "0",
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
        raise SystemExit(f"v61ao {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_tensor_role_coverage_rows.csv",
    "moe_layer_expert_tensor_coverage_rows.csv",
    "checkpoint_manifest_shard_audit_rows.csv",
    "real_model_page_manifest_coverage_requirement_rows.csv",
    "real_model_page_manifest_coverage_metric_rows.csv",
    "V61AO_REAL_MODEL_PAGE_MANIFEST_COVERAGE_AUDIT_BOUNDARY.md",
    "v61ao_real_model_page_manifest_coverage_audit_manifest.json",
    "sha256_manifest.csv",
    "source_v61q/checkpoint_tensor_page_span_rows.csv",
    "source_v61q/checkpoint_page_segment_rows.csv",
    "source_v61q/checkpoint_unique_page_rows.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
    "source_v61v/source_v61u/remote_page_hash_sample_rows.csv",
    "source_v61an/checkpoint_full_page_hash_execution_requirement_rows.csv",
    "source_v61an/checkpoint_full_page_hash_execution_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ao artifact: {rel}")

role_rows = {row["tensor_role"]: row for row in read_csv(run_dir / "checkpoint_tensor_role_coverage_rows.csv")}
matrix_rows = read_csv(run_dir / "moe_layer_expert_tensor_coverage_rows.csv")
shard_rows = read_csv(run_dir / "checkpoint_manifest_shard_audit_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "real_model_page_manifest_coverage_requirement_rows.csv")}
metric = read_csv(run_dir / "real_model_page_manifest_coverage_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

expected_roles = {
    "attention": ("224", "4928"),
    "embedding": ("1", "188"),
    "layernorm": ("113", "113"),
    "lm_head": ("1", "188"),
    "moe_w1": ("448", "43456"),
    "moe_w2": ("448", "43456"),
    "moe_w3": ("448", "43456"),
    "router_gate": ("56", "56"),
}
for role, (tensor_rows, segment_rows) in expected_roles.items():
    row = role_rows.get(role)
    if row is None:
        raise SystemExit(f"v61ao missing role coverage: {role}")
    if row["checkpoint_tensor_rows"] != tensor_rows or row["checkpoint_page_segment_rows"] != segment_rows:
        raise SystemExit(f"v61ao role {role} row counts mismatch: {row}")
    if row["role_manifest_coverage_ready"] != "1" or row["weight_bytes_included"] != "0":
        raise SystemExit(f"v61ao role {role} should be coverage-ready metadata only")

if len(matrix_rows) != 1344:
    raise SystemExit("v61ao MoE matrix row count mismatch")
if any(row["moe_matrix_cell_ready"] != "1" for row in matrix_rows):
    raise SystemExit("v61ao all MoE layer/expert/tensor cells should be ready")
if any(row["weight_bytes_included"] != "0" for row in matrix_rows):
    raise SystemExit("v61ao MoE matrix must stay metadata-only")
layers = {row["layer_index"] for row in matrix_rows}
experts = {row["expert_index"] for row in matrix_rows}
roles = {row["tensor_role"] for row in matrix_rows}
if len(layers) != 56 or len(experts) != 8 or roles != {"moe_w1", "moe_w2", "moe_w3"}:
    raise SystemExit("v61ao MoE matrix coverage axes mismatch")

if len(shard_rows) != 59:
    raise SystemExit("v61ao shard audit rows mismatch")
if any(row["payload_coverage_ready"] != "1" or row["weight_bytes_included"] != "0" for row in shard_rows):
    raise SystemExit("v61ao shard audit should be payload-covered metadata only")
if sum(int(row["remote_hash_sample_rows"]) for row in shard_rows) != 16:
    raise SystemExit("v61ao remote sample shard distribution mismatch")

for requirement_id in [
    "real-checkpoint-page-map-input",
    "complete-moe-layer-expert-tensor-coverage",
    "remote-hashed-sample-binding",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ao requirement should pass: {requirement_id}")
for requirement_id in ["full-safetensors-page-hash-binding", "real-model-generation"]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ao requirement should remain blocked: {requirement_id}")

for gate in [
    "v61q-real-checkpoint-page-map-input",
    "v61v-remote-page-tensor-binding-input",
    "v61an-full-page-hash-execution-gate-input",
    "real-model-page-manifest-coverage",
    "remote-hashed-sample-binding",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ao gate should pass: {gate}")
for gate in [
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ao gate should stay blocked: {gate}")

for field, value in expected.items():
    if field.startswith("v61ao_") or field.startswith("v61q_") or field.startswith("v61v_") or field.startswith("v61an_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ao metric {field}: expected {value}, got {metric[field]}")

manifest = json.loads((run_dir / "v61ao_real_model_page_manifest_coverage_audit_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ao_real_model_page_manifest_coverage_audit_ready") != 1:
    raise SystemExit("v61ao manifest readiness mismatch")
if manifest.get("moe_layer_expert_tensor_coverage_ready_rows") != 1344:
    raise SystemExit("v61ao manifest MoE matrix readiness mismatch")
if manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61ao manifest should keep full page-hash coverage blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ao") != 0:
    raise SystemExit("v61ao must not download checkpoint payload bytes")

boundary = (run_dir / "V61AO_REAL_MODEL_PAGE_MANIFEST_COVERAGE_AUDIT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real Mixtral checkpoint page manifest",
    "moe_layer_expert_tensor_coverage_rows=1344",
    "moe_layer_expert_tensor_coverage_ready_rows=1344",
    "remote_hash_bound_tensor_rows=16",
    "real_model_page_manifest_coverage_ready=1",
    "full_safetensors_page_hash_binding_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ao=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ao boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ao sha256 mismatch: {rel}")
PY

echo "v61ao real model page manifest coverage audit smoke passed"
