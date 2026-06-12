#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cj_real_manifest_immediate_target_bridge/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/v61cj_real_manifest_immediate_target_bridge_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cj_real_manifest_immediate_target_bridge_decision.csv"

V61CJ_REUSE_EXISTING="${V61CJ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cj_real_manifest_immediate_target_bridge.sh" >/dev/null

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
    "v61cj_real_manifest_immediate_target_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61ci_real_manifest_runtime_substitution_gate_ready": "1",
    "v61l_gpu_page_dequant_matmul_measurement_ready": "1",
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "v61s_one_command_source_bound_qa_replay_ready": "1",
    "immediate_target_rows": "4",
    "ready_immediate_target_rows": "4",
    "runtime_bridge_rows": "3",
    "ready_runtime_bridge_rows": "3",
    "real_manifest_immediate_target_bridge_ready": "1",
    "logical_fixture_replaced_by_real_manifest_ready": "1",
    "zero_payload_runtime_input_ready": "1",
    "gpu_kernel_avg_ms": "0.513442",
    "gpu_page_dequant_gflops": "16.337990",
    "gpu_page_bandwidth_gbps": "4.124385",
    "kv_cache_policy_ready": "1",
    "kv_eviction_trace_ready": "1",
    "source_bound_query_rows": "37",
    "source_bound_query_pass_rows": "37",
    "source_bound_citation_rows": "37",
    "source_bound_abstain_rows": "10",
    "complete_source_1000_query_ready": "0",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "2353",
    "remaining_page_hash_rows": "131808",
    "completed_full_safetensors_page_hash_coverage_ready": "0",
    "runtime_execution_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_manifest_immediate_target_rows.csv",
    "real_manifest_runtime_evidence_bridge_rows.csv",
    "real_manifest_immediate_target_requirement_rows.csv",
    "real_manifest_immediate_target_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CJ_REAL_MANIFEST_IMMEDIATE_TARGET_BRIDGE_BOUNDARY.md",
    "v61cj_real_manifest_immediate_target_bridge_manifest.json",
    "source_v61ci/v61ci_real_manifest_runtime_substitution_gate_summary.csv",
    "source_v61ci/logical_fixture_replacement_contract_rows.csv",
    "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv",
    "source_v61l/gpu_page_dequant_matmul_rows.csv",
    "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv",
    "source_v61m/kv_residency_policy_rows.csv",
    "source_v61s/v61s_one_command_source_bound_qa_replay_summary.csv",
    "source_v61s/source_bound_workload_pass_rows.csv",
    "source_v61n/source_bound_query_rows.csv",
    "source_v61n/source_bound_answer_rows.csv",
    "source_v61n/source_bound_citation_rows.csv",
    "source_v61n/source_bound_abstain_rows.csv",
    "source_v61n/source_bound_resource_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cj artifact: {rel}")

target_rows = read_csv(run_dir / "real_manifest_immediate_target_rows.csv")
bridge_rows = read_csv(run_dir / "real_manifest_runtime_evidence_bridge_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "real_manifest_immediate_target_requirement_rows.csv")}
metric = read_csv(run_dir / "real_manifest_immediate_target_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(target_rows) != 4:
    raise SystemExit("v61cj immediate target row count mismatch")
if len(bridge_rows) != 3:
    raise SystemExit("v61cj bridge row count mismatch")
if any(row["target_ready"] != "1" for row in target_rows):
    raise SystemExit("v61cj all immediate target rows should be ready")
if any(row["bridge_ready"] != "1" for row in bridge_rows):
    raise SystemExit("v61cj all runtime evidence bridge rows should be ready")
if {row["evidence_source"] for row in target_rows} != {"v61ci", "v61l", "v61m", "v61s"}:
    raise SystemExit("v61cj target evidence source set mismatch")

for requirement_id in [
    "real-manifest-fixture-replacement",
    "gpu-rocm-page-kernel-measurement",
    "kv-cache-residency-eviction-policy",
    "v61j-source-bound-qa-command-pass",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cj requirement should pass: {requirement_id}")
for requirement_id in [
    "completed-full-safetensors-page-hash-coverage",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cj requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cj_") or field.startswith("v61ci_") or field.startswith("v61l_") or field.startswith("v61m_") or field.startswith("v61s_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cj metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "real-manifest-fixture-replacement",
    "gpu-rocm-page-kernel-measurement",
    "kv-cache-residency-eviction-policy",
    "v61j-source-bound-qa-command-pass",
    "real-manifest-immediate-target-bridge",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cj gate should pass: {gate}")
for gate in [
    "completed-full-safetensors-page-hash-coverage",
    "complete-source-1000-query",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cj gate should stay blocked: {gate}")

for gap in [
    "real-manifest-fixture-replacement",
    "gpu-rocm-page-kernel-measurement",
    "kv-cache-residency-eviction-policy",
    "v61j-source-bound-qa-command-pass",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cj gap should be ready: {gap}")
for gap in [
    "completed-full-safetensors-page-hash-coverage",
    "complete-source-1000-query",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cj gap should stay blocked: {gap}")

boundary = (run_dir / "V61CJ_REAL_MANIFEST_IMMEDIATE_TARGET_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real-model immediate targets",
    "immediate_target_rows=4",
    "ready_immediate_target_rows=4",
    "runtime_bridge_rows=3",
    "ready_runtime_bridge_rows=3",
    "real_manifest_immediate_target_bridge_ready=1",
    "gpu_kernel_avg_ms=0.513442",
    "kv_cache_policy_ready=1",
    "source_bound_query_pass_rows=37/37",
    "completed_full_safetensors_page_hash_coverage_ready=0",
    "complete_source_1000_query_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cj=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cj boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cj_real_manifest_immediate_target_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cj_real_manifest_immediate_target_bridge_ready") != 1:
    raise SystemExit("v61cj manifest readiness mismatch")
if manifest.get("ready_immediate_target_rows") != 4:
    raise SystemExit("v61cj manifest target readiness mismatch")
if manifest.get("ready_runtime_bridge_rows") != 3:
    raise SystemExit("v61cj manifest bridge readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cj manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cj manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cj sha256 mismatch: {rel}")
PY

echo "v61cj real manifest immediate target bridge smoke passed"
