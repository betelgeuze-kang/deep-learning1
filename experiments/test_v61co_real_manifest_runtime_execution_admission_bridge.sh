#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61co_real_manifest_runtime_execution_admission_bridge/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/v61co_real_manifest_runtime_execution_admission_bridge_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61co_real_manifest_runtime_execution_admission_bridge_decision.csv"

V61CO_REUSE_EXISTING="${V61CO_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh" >/dev/null

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
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cj_real_manifest_immediate_target_bridge_ready": "1",
    "v61ci_real_manifest_runtime_substitution_gate_ready": "1",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": "1",
    "v61n_source_bound_qa_workload_ready": "1",
    "v61s_one_command_source_bound_qa_replay_ready": "1",
    "immediate_target_rows": "4",
    "ready_immediate_target_rows": "4",
    "runtime_bridge_rows": "3",
    "ready_runtime_bridge_rows": "3",
    "real_manifest_immediate_target_bridge_ready": "1",
    "logical_fixture_replaced_by_real_manifest_ready": "1",
    "zero_payload_runtime_input_ready": "1",
    "runtime_execution_candidate_rows": "37",
    "runtime_execution_admitted_rows": "0",
    "runtime_execution_blocked_rows": "37",
    "materialization_blocked_runtime_rows": "37",
    "page_hash_admission_blocked_runtime_rows": "37",
    "source_bound_query_rows": "37",
    "source_bound_query_pass_rows": "37",
    "checkpoint_shard_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "1",
    "blocked_checkpoint_materialization_shard_rows": "58",
    "missing_remaining_materialization_return_rows": "58",
    "promotion_missing_materialization_bytes": "276308963480",
    "full_checkpoint_materialization_ready": "0",
    "remaining_page_hash_execution_chunk_rows": "286",
    "admitted_page_hash_execution_chunk_rows": "0",
    "materialization_blocked_page_hash_execution_chunk_rows": "286",
    "blocked_page_hash_rows": "131808",
    "blocked_page_hash_bytes": "276308963480",
    "page_hash_execution_admission_ready": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "0",
    "real_manifest_runtime_execution_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61co": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61co {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_manifest_runtime_execution_admission_rows.csv",
    "real_manifest_runtime_execution_admission_requirement_rows.csv",
    "real_manifest_runtime_execution_admission_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CO_REAL_MANIFEST_RUNTIME_EXECUTION_ADMISSION_BRIDGE_BOUNDARY.md",
    "v61co_real_manifest_runtime_execution_admission_bridge_manifest.json",
    "sha256_manifest.csv",
    "source_v61cj/real_manifest_immediate_target_rows.csv",
    "source_v61cj/real_manifest_runtime_evidence_bridge_rows.csv",
    "source_v61ci/logical_fixture_replacement_contract_rows.csv",
    "source_v61ci/real_manifest_runtime_binding_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_rows.csv",
    "source_v61cn/page_hash_execution_materialization_admission_rows.csv",
    "source_v61n/source_bound_query_rows.csv",
    "source_v61n/source_bound_answer_rows.csv",
    "source_v61n/source_bound_citation_rows.csv",
    "source_v61n/source_bound_resource_rows.csv",
    "source_v61s/source_bound_workload_pass_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61co artifact: {rel}")

admission_rows = read_csv(run_dir / "real_manifest_runtime_execution_admission_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "real_manifest_runtime_execution_admission_requirement_rows.csv")}
metric = read_csv(run_dir / "real_manifest_runtime_execution_admission_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(admission_rows) != 37:
    raise SystemExit("v61co runtime admission row count mismatch")
if any(row["runtime_execution_admitted"] != "0" for row in admission_rows):
    raise SystemExit("v61co must not admit runtime execution rows by default")
if any(row["runtime_execution_admission_status"] != "blocked-full-checkpoint-materialization" for row in admission_rows):
    raise SystemExit("v61co default rows should be materialization-blocked")
if any(row["source_bound_query_pass"] != "1" for row in admission_rows):
    raise SystemExit("v61co source-bound seed rows should all pass before runtime admission")
if any(row["checkpoint_payload_bytes_downloaded_by_v61co"] != "0" for row in admission_rows):
    raise SystemExit("v61co must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in admission_rows):
    raise SystemExit("v61co must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in admission_rows):
    raise SystemExit("v61co route jumps must stay zero")

for requirement_id in [
    "v61cj-real-manifest-immediate-target-bridge-input",
    "v61ci-real-manifest-runtime-substitution-input",
    "v61n-v61s-source-bound-qa-seed",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61co requirement should pass: {requirement_id}")
for requirement_id in [
    "v61cm-full-checkpoint-materialization",
    "v61cn-page-hash-execution-admission",
    "v61cn-completed-full-safetensors-page-hash-coverage",
    "runtime-execution-admission-over-source-bound-qa",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61co requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61co_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61co metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61cj-real-manifest-immediate-target-bridge-input",
    "v61ci-real-manifest-runtime-substitution-input",
    "v61n-v61s-source-bound-qa-seed",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61co gate should pass: {gate}")
for gate in [
    "v61cm-full-checkpoint-materialization",
    "v61cn-page-hash-execution-admission",
    "completed-full-safetensors-page-hash-coverage",
    "real-manifest-runtime-execution-admission",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61co gate should stay blocked: {gate}")

for gap in [
    "v61cj-real-manifest-immediate-target-bridge-input",
    "v61ci-real-manifest-runtime-substitution-input",
    "v61n-v61s-source-bound-qa-seed",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61co gap should be ready: {gap}")
for gap in [
    "v61cm-full-checkpoint-materialization",
    "v61cn-page-hash-execution-admission",
    "completed-full-safetensors-page-hash-coverage",
    "real-manifest-runtime-execution-admission",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61co gap should stay blocked: {gap}")

boundary = (run_dir / "V61CO_REAL_MANIFEST_RUNTIME_EXECUTION_ADMISSION_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_execution_candidate_rows=37",
    "runtime_execution_admitted_rows=0",
    "runtime_execution_blocked_rows=37",
    "materialization_blocked_runtime_rows=37",
    "page_hash_admission_blocked_runtime_rows=37",
    "source_bound_query_pass_rows=37/37",
    "ready_checkpoint_materialization_shard_rows=1",
    "blocked_checkpoint_materialization_shard_rows=58",
    "admitted_page_hash_execution_chunk_rows=0",
    "materialization_blocked_page_hash_execution_chunk_rows=286",
    "blocked_page_hash_rows=131808",
    "blocked_page_hash_bytes=276308963480",
    "real_manifest_runtime_execution_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61co=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61co boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61co_real_manifest_runtime_execution_admission_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61co_real_manifest_runtime_execution_admission_bridge_ready") != 1:
    raise SystemExit("v61co manifest readiness mismatch")
if manifest.get("runtime_execution_candidate_rows") != 37:
    raise SystemExit("v61co manifest candidate row mismatch")
if manifest.get("runtime_execution_admitted_rows") != 0:
    raise SystemExit("v61co manifest should admit no runtime rows")
if manifest.get("real_manifest_runtime_execution_admission_ready") != 0:
    raise SystemExit("v61co manifest should keep runtime admission blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61co manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61co sha256 mismatch: {rel}")
PY

echo "v61co real manifest runtime execution admission bridge smoke passed"
