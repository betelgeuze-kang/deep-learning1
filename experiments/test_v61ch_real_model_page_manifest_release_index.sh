#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ch_real_model_page_manifest_release_index/index_001"
SUMMARY_CSV="$RESULTS_DIR/v61ch_real_model_page_manifest_release_index_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ch_real_model_page_manifest_release_index_decision.csv"

V61CH_REUSE_EXISTING="${V61CH_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ch_real_model_page_manifest_release_index.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
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
    "v61ch_real_model_page_manifest_release_index_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61ao_real_model_page_manifest_coverage_audit_ready": "1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": "1",
    "checkpoint_shard_rows": "59",
    "checkpoint_tensor_rows": "1739",
    "checkpoint_unique_page_rows": "134161",
    "checkpoint_page_segment_rows": "135841",
    "moe_layer_expert_tensor_coverage_rows": "1344",
    "moe_layer_expert_tensor_coverage_ready_rows": "1344",
    "remote_hash_bound_tensor_rows": "16",
    "remote_hash_bound_moe_rows": "15",
    "source_artifact_rows": "8",
    "release_index_file_rows": "10",
    "redistributable_manifest_index_ready": "1",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "remaining_page_hash_rows": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "operator_bundle_handoff_ready": "1",
    "generation_operator_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "redistributed_checkpoint_payload_bytes": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ch": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ch {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "page_manifest_release_index_source_artifact_rows.csv",
    "page_manifest_release_index_file_rows.csv",
    "page_manifest_release_index_requirement_rows.csv",
    "page_manifest_release_index_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CH_REAL_MODEL_PAGE_MANIFEST_RELEASE_INDEX_BOUNDARY.md",
    "v61ch_real_model_page_manifest_release_index_manifest.json",
    "release_index/README.md",
    "release_index/MANIFEST_INDEX.csv",
    "release_index/checkpoint_manifest_shard_audit_rows.csv",
    "release_index/checkpoint_tensor_role_coverage_rows.csv",
    "release_index/moe_layer_expert_tensor_coverage_rows.csv",
    "release_index/page_hash_coverage_status_rows.csv",
    "release_index/generation_handoff_status_rows.csv",
    "release_index/ZERO_PAYLOAD_BOUNDARY.md",
    "release_index/IMPORT_CHECKLIST.md",
    "release_index/VERIFY_RELEASE_INDEX.sh",
    "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_summary.csv",
    "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv",
    "source_v61cg/v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ch artifact: {rel}")

verify_script = run_dir / "release_index/VERIFY_RELEASE_INDEX.sh"
if not os.access(verify_script, os.X_OK):
    raise SystemExit("v61ch verify script must be executable")
subprocess.run([str(verify_script)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

source_rows = read_csv(run_dir / "page_manifest_release_index_source_artifact_rows.csv")
file_rows = read_csv(run_dir / "page_manifest_release_index_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "page_manifest_release_index_requirement_rows.csv")}
metric = read_csv(run_dir / "page_manifest_release_index_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(source_rows) != 8:
    raise SystemExit("v61ch source artifact row count mismatch")
if len(file_rows) != 10:
    raise SystemExit("v61ch release file row count mismatch")
if sum(1 for row in source_rows if row["included_in_release_index"] == "1") != 3:
    raise SystemExit("v61ch included source artifact count mismatch")
if any(row["contains_checkpoint_payload_bytes"] != "0" for row in source_rows):
    raise SystemExit("v61ch source artifact rows must be zero-payload")
if any(row["contains_checkpoint_payload_bytes"] != "0" for row in file_rows):
    raise SystemExit("v61ch release file rows must be zero-payload")
if {row["release_file"] for row in file_rows} != {
    "release_index/README.md",
    "release_index/MANIFEST_INDEX.csv",
    "release_index/checkpoint_manifest_shard_audit_rows.csv",
    "release_index/checkpoint_tensor_role_coverage_rows.csv",
    "release_index/moe_layer_expert_tensor_coverage_rows.csv",
    "release_index/page_hash_coverage_status_rows.csv",
    "release_index/generation_handoff_status_rows.csv",
    "release_index/ZERO_PAYLOAD_BOUNDARY.md",
    "release_index/IMPORT_CHECKLIST.md",
    "release_index/VERIFY_RELEASE_INDEX.sh",
}:
    raise SystemExit("v61ch release file set mismatch")

for requirement_id in [
    "v61ao-real-model-page-manifest-coverage-input",
    "v61cb-page-hash-coverage-status-input",
    "v61cg-generation-handoff-status-input",
    "completed-full-safetensors-page-hash-coverage",
    "zero-payload-redistributable-index",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ch requirement should pass: {requirement_id}")
for requirement_id in [
    "real-model-generation",
    "real-release-package",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ch requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61ch_") or field.startswith("v61ao_") or field.startswith("v61cb_") or field.startswith("v61cg_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ch metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61ao-real-model-page-manifest-coverage-input",
    "v61cb-page-hash-coverage-status-input",
    "v61cg-generation-handoff-status-input",
    "completed-full-safetensors-page-hash-coverage",
    "zero-payload-page-manifest-release-index",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ch gate should pass: {gate}")
for gate in [
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ch gate should stay blocked: {gate}")

for gap in [
    "v61ao-real-model-page-manifest-coverage-input",
    "v61cb-page-hash-coverage-status-input",
    "v61cg-generation-handoff-status-input",
    "completed-full-safetensors-page-hash-coverage",
    "zero-payload-page-manifest-release-index",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ch gap should be ready: {gap}")
for gap in [
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ch gap should stay blocked: {gap}")

boundary = (run_dir / "V61CH_REAL_MODEL_PAGE_MANIFEST_RELEASE_INDEX_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "zero-payload release index",
    "checkpoint_unique_page_rows=134161",
    "checkpoint_page_segment_rows=135841",
    "moe_layer_expert_tensor_coverage_rows=1344",
    "source_artifact_rows=8",
    "release_index_file_rows=10",
    "redistributable_manifest_index_ready=1",
    "total_verified_page_hash_rows=134161",
    "remaining_page_hash_rows=0",
    "actual_model_generation_ready=0",
    "redistributed_checkpoint_payload_bytes=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ch boundary missing snippet: {snippet}")

release_boundary = (run_dir / "release_index/ZERO_PAYLOAD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [".safetensors", "raw checkpoint payload slices", "redistributes no checkpoint bytes"]:
    if snippet not in release_boundary:
        raise SystemExit(f"v61ch zero-payload boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ch_real_model_page_manifest_release_index_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ch_real_model_page_manifest_release_index_ready") != 1:
    raise SystemExit("v61ch manifest readiness mismatch")
if manifest.get("checkpoint_unique_page_rows") != 134161:
    raise SystemExit("v61ch manifest page count mismatch")
if manifest.get("source_artifact_rows") != 8:
    raise SystemExit("v61ch manifest source row count mismatch")
if manifest.get("release_index_file_rows") != 10:
    raise SystemExit("v61ch manifest file row count mismatch")
if manifest.get("redistributable_manifest_index_ready") != 1:
    raise SystemExit("v61ch manifest redistributable index mismatch")
if manifest.get("total_verified_page_hash_rows") != 134161:
    raise SystemExit("v61ch manifest verified page hash count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ch manifest should keep generation blocked")
if manifest.get("redistributed_checkpoint_payload_bytes") != 0:
    raise SystemExit("v61ch manifest must keep redistributed payload bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ch manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ch sha256 mismatch: {rel}")
PY

echo "v61ch real model page manifest release index smoke passed"
