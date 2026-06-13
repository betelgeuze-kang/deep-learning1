#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cc_ubuntu1_page_hash_generation_admission_bridge/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CC_REUSE_EXISTING="${V61CC_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = sys.argv[4]


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
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "target_root_path": ubuntu1_target,
    "complete_source_query_rows": "1000",
    "generation_admission_bridge_rows": "1000",
    "machine_complete_source_surface_ready": "1",
    "complete_source_review_return_ready": "0",
    "full_page_hash_coverage_promotion_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "checkpoint_shard_rows": "59",
    "ready_full_page_hash_shard_rows": "59",
    "blocked_full_page_hash_shard_rows": "0",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "missing_remaining_page_hash_result_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "generation_result_schema_ready": "1",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_packet_artifacts_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_execution_admitted_rows": "0",
    "page_hash_blocked_rows": "0",
    "review_return_blocked_rows": "1000",
    "generation_result_artifact_blocked_rows": "1000",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cc {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "page_hash_generation_admission_bridge_rows.csv",
    "page_hash_generation_admission_requirement_rows.csv",
    "page_hash_generation_admission_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CC_UBUNTU1_PAGE_HASH_GENERATION_ADMISSION_BRIDGE_BOUNDARY.md",
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_manifest.json",
    "sha256_manifest.csv",
    "source_v61cb/full_page_hash_coverage_promotion_rows.csv",
    "source_v61cb/full_page_hash_coverage_promotion_requirement_rows.csv",
    "source_v53t/complete_source_audit_readiness_requirement_rows.csv",
    "source_v53t/complete_source_audit_claim_rows.csv",
    "source_v61bt/actual_generation_query_result_rows.csv",
    "source_v61bt/actual_generation_result_template_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cc artifact: {rel}")

bridge_rows = read_csv(run_dir / "page_hash_generation_admission_bridge_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "page_hash_generation_admission_requirement_rows.csv")}
metric = read_csv(run_dir / "page_hash_generation_admission_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(bridge_rows) != 1000:
    raise SystemExit("v61cc bridge row count mismatch")
if sum(int(row["generation_execution_admitted"]) for row in bridge_rows) != 0:
    raise SystemExit("v61cc should admit no generation execution by default")
if sum(int(row["page_hash_blocked"]) for row in bridge_rows) != 0:
    raise SystemExit("v61cc page hash blocker row count mismatch")
if sum(int(row["review_return_blocked"]) for row in bridge_rows) != 1000:
    raise SystemExit("v61cc review blocker row count mismatch")
if sum(int(row["generation_result_artifact_blocked"]) for row in bridge_rows) != 1000:
    raise SystemExit("v61cc generation artifact blocker row count mismatch")
if sum(int(row["actual_model_generation_ready"]) for row in bridge_rows) != 0:
    raise SystemExit("v61cc must keep actual generation blocked")
if any(row["machine_complete_source_surface_ready"] != "1" for row in bridge_rows):
    raise SystemExit("v61cc complete-source surface should be ready for every row")
if any(row["full_safetensors_page_hash_binding_ready"] != "1" for row in bridge_rows):
    raise SystemExit("v61cc full page hash binding should be ready")
if any(row["complete_source_review_return_ready"] != "0" for row in bridge_rows):
    raise SystemExit("v61cc review return should remain blocked")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cc"] != "0" for row in bridge_rows):
    raise SystemExit("v61cc must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in bridge_rows):
    raise SystemExit("v61cc must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in bridge_rows):
    raise SystemExit("v61cc must keep route jumps at zero")

for requirement_id in [
    "v61cb-page-hash-promotion-input",
    "v53t-complete-source-audit-input",
    "v61bt-generation-result-schema-input",
    "completed-full-safetensors-page-hash-coverage",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cc requirement should pass: {requirement_id}")
for requirement_id in [
    "complete-source-review-return",
    "generation-execution-admission",
    "actual-generation-result-artifacts",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cc requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cc_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cc metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61cb-page-hash-promotion-input",
    "v53t-complete-source-audit-input",
    "v61bt-generation-result-schema-input",
    "completed-full-safetensors-page-hash-coverage",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cc gate should pass: {gate}")
for gate in [
    "complete-source-review-return",
    "generation-execution-admission",
    "actual-generation-result-artifacts",
    "actual-model-generation",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cc gate should stay blocked: {gate}")

for gap in [
    "v61cb-page-hash-promotion-input",
    "v53t-complete-source-audit-input",
    "v61bt-generation-result-schema-input",
    "completed-full-safetensors-page-hash-coverage",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cc gap should be ready: {gap}")
for gap in [
    "complete-source-review-return",
    "generation-execution-admission",
    "actual-generation-result-artifacts",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cc gap should stay blocked: {gap}")

boundary = (run_dir / "V61CC_UBUNTU1_PAGE_HASH_GENERATION_ADMISSION_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "generation_admission_bridge_rows=1000",
    "machine_complete_source_surface_ready=1",
    "complete_source_review_return_ready=0",
    "full_safetensors_page_hash_binding_ready=1",
    "total_verified_page_hash_rows=134161",
    "total_required_page_hash_rows=134161",
    "generation_execution_admission_ready=0",
    "generation_execution_admitted_rows=0",
    "page_hash_blocked_rows=0",
    "review_return_blocked_rows=1000",
    "generation_result_artifact_blocked_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cc=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cc boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cc_ubuntu1_page_hash_generation_admission_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cc_ubuntu1_page_hash_generation_admission_bridge_ready") != 1:
    raise SystemExit("v61cc manifest readiness mismatch")
if manifest.get("generation_admission_bridge_rows") != 1000:
    raise SystemExit("v61cc manifest row count mismatch")
if manifest.get("generation_execution_admitted_rows") != 0:
    raise SystemExit("v61cc manifest should admit no rows")
if manifest.get("total_verified_page_hash_rows") != 134161:
    raise SystemExit("v61cc manifest verified page hash mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cc manifest should keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61cc") != 0:
    raise SystemExit("v61cc manifest must keep downloaded bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cc manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cc sha256 mismatch: {rel}")
PY

echo "v61cc ubuntu-1 page-hash generation admission bridge smoke passed"
