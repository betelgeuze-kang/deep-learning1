#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ci_real_manifest_runtime_substitution_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61ci_real_manifest_runtime_substitution_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ci_real_manifest_runtime_substitution_gate_decision.csv"

V61CI_REUSE_EXISTING="${V61CI_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ci_real_manifest_runtime_substitution_gate.sh" >/dev/null

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
    "v61ci_real_manifest_runtime_substitution_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61j_one_command_ssd_resident_demo_ready": "1",
    "v61k_real_model_page_manifest_ready": "1",
    "v61ch_real_model_page_manifest_release_index_ready": "1",
    "logical_total_parameters": "128000000000",
    "real_manifest_total_parameters_estimate": "176000000000",
    "real_manifest_100b_plus_ready": "1",
    "logical_fixture_replacement_contract_rows": "4",
    "runtime_substitution_binding_rows": "5",
    "logical_fixture_replaced_by_real_manifest_ready": "1",
    "zero_payload_runtime_input_ready": "1",
    "source_artifact_rows": "8",
    "release_index_file_rows": "10",
    "checkpoint_unique_page_rows": "134161",
    "checkpoint_page_segment_rows": "135841",
    "moe_layer_expert_tensor_coverage_rows": "1344",
    "moe_layer_expert_tensor_coverage_ready_rows": "1344",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "remaining_page_hash_rows": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "real_manifest_uncached_q4_bytes_per_token_estimate": "16911433728",
    "v61j_ssd_read_bytes_per_token_max": "8388608",
    "v61j_ssd_read_budget_pass": "1",
    "runtime_execution_admission_ready": "0",
    "generation_operator_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "redistributed_checkpoint_payload_bytes": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ci": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ci {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "logical_fixture_replacement_contract_rows.csv",
    "real_manifest_runtime_binding_rows.csv",
    "real_manifest_runtime_substitution_requirement_rows.csv",
    "real_manifest_runtime_substitution_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CI_REAL_MANIFEST_RUNTIME_SUBSTITUTION_GATE_BOUNDARY.md",
    "v61ci_real_manifest_runtime_substitution_gate_manifest.json",
    "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv",
    "source_v61j/runtime_summary.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
    "source_v61k/expert_page_budget_rows.csv",
    "source_v61ch/v61ch_real_model_page_manifest_release_index_summary.csv",
    "source_v61ch/release_index/MANIFEST_INDEX.csv",
    "source_v61ch/release_index/page_hash_coverage_status_rows.csv",
    "source_v61ch/release_index/generation_handoff_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ci artifact: {rel}")

contracts = read_csv(run_dir / "logical_fixture_replacement_contract_rows.csv")
bindings = read_csv(run_dir / "real_manifest_runtime_binding_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "real_manifest_runtime_substitution_requirement_rows.csv")}
metric = read_csv(run_dir / "real_manifest_runtime_substitution_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(contracts) != 4:
    raise SystemExit("v61ci logical replacement contract row count mismatch")
if len(bindings) != 5:
    raise SystemExit("v61ci runtime binding row count mismatch")
if any(row["ready"] != "1" for row in contracts):
    raise SystemExit("v61ci all logical fixture replacement contracts should be ready")
if any(row["runtime_substitution_ready"] != "1" for row in bindings):
    raise SystemExit("v61ci all runtime substitution bindings should be ready")
if any(row["runtime_execution_ready"] not in {"0", "1"} for row in bindings):
    raise SystemExit("v61ci runtime binding execution readiness should be numeric")
if any(row["runtime_execution_ready"] != "0" for row in bindings):
    raise SystemExit("v61ci should keep all real runtime execution bindings blocked")

for requirement_id in [
    "v61j-logical-runtime-scaffold-input",
    "v61k-real-100b-manifest-input",
    "v61ch-zero-payload-release-index-input",
    "logical-fixture-replacement-contract",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ci requirement should pass: {requirement_id}")
for requirement_id in [
    "completed-full-safetensors-page-hash-coverage",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ci requirement should pass: {requirement_id}")
for requirement_id in [
    "real-manifest-runtime-execution",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ci requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61ci_") or field.startswith("v61j_") or field.startswith("v61k_") or field.startswith("v61ch_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ci metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61j-logical-runtime-scaffold-input",
    "v61k-real-100b-manifest-input",
    "v61ch-zero-payload-release-index-input",
    "logical-fixture-replacement-contract",
    "zero-payload-runtime-input",
    "completed-full-safetensors-page-hash-coverage",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ci gate should pass: {gate}")
for gate in [
    "real-manifest-runtime-execution",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ci gate should stay blocked: {gate}")

for gap in [
    "v61j-logical-runtime-scaffold-input",
    "v61k-real-100b-manifest-input",
    "v61ch-zero-payload-release-index-input",
    "logical-fixture-replacement-contract",
    "completed-full-safetensors-page-hash-coverage",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ci gap should be ready: {gap}")
for gap in [
    "real-manifest-runtime-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ci gap should stay blocked: {gap}")

boundary = (run_dir / "V61CI_REAL_MANIFEST_RUNTIME_SUBSTITUTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "logical fixture replaced by real zero-payload manifest input",
    "logical_total_parameters=128000000000",
    "real_manifest_total_parameters_estimate=176000000000",
    "logical_fixture_replacement_contract_rows=4",
    "runtime_substitution_binding_rows=5",
    "logical_fixture_replaced_by_real_manifest_ready=1",
    "checkpoint_unique_page_rows=134161",
    "total_verified_page_hash_rows=134161",
    "remaining_page_hash_rows=0",
    "runtime_execution_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ci=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ci boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ci_real_manifest_runtime_substitution_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ci_real_manifest_runtime_substitution_gate_ready") != 1:
    raise SystemExit("v61ci manifest readiness mismatch")
if manifest.get("logical_fixture_replacement_contract_rows") != 4:
    raise SystemExit("v61ci manifest contract row count mismatch")
if manifest.get("runtime_substitution_binding_rows") != 5:
    raise SystemExit("v61ci manifest binding row count mismatch")
if manifest.get("logical_fixture_replaced_by_real_manifest_ready") != 1:
    raise SystemExit("v61ci manifest substitution readiness mismatch")
if manifest.get("runtime_execution_admission_ready") != 0:
    raise SystemExit("v61ci manifest runtime execution should stay blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ci manifest generation should stay blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ci manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ci sha256 mismatch: {rel}")
PY

echo "v61ci real manifest runtime substitution gate smoke passed"
