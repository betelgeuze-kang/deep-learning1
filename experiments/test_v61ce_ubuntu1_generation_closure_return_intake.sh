#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ce_ubuntu1_generation_closure_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61ce_ubuntu1_generation_closure_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ce_ubuntu1_generation_closure_return_intake_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CE_REUSE_EXISTING="${V61CE_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ce_ubuntu1_generation_closure_return_intake.sh" >/dev/null

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
    "v61ce_ubuntu1_generation_closure_return_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_ready": "1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    "target_root_path": ubuntu1_target,
    "closure_gate_rows": "3",
    "generation_closure_admission_rows": "1000",
    "complete_source_query_rows": "1000",
    "generation_admission_bridge_rows": "1000",
    "page_hash_return_required_rows": "0",
    "page_hash_return_accepted_rows": "0",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "human_review_required_rows": "7000",
    "human_review_accepted_rows": "0",
    "adjudication_required_rows": "1000",
    "adjudication_accepted_rows": "0",
    "generation_result_required_artifacts": "5",
    "generation_result_accepted_artifacts": "0",
    "accepted_generation_rows": "0",
    "page_hash_closure_ready": "1",
    "review_return_closure_ready": "0",
    "generation_result_closure_ready": "0",
    "generation_closure_return_intake_ready": "0",
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
    "checkpoint_payload_bytes_downloaded_by_v61ce": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ce {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "generation_closure_return_gate_rows.csv",
    "generation_closure_return_admission_rows.csv",
    "generation_closure_return_requirement_rows.csv",
    "generation_closure_return_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CE_UBUNTU1_GENERATION_CLOSURE_RETURN_INTAKE_BOUNDARY.md",
    "v61ce_ubuntu1_generation_closure_return_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61cd/generation_unblocker_phase_rows.csv",
    "source_v61cc/page_hash_generation_admission_bridge_rows.csv",
    "source_v61cb/full_page_hash_coverage_promotion_rows.csv",
    "source_v53t/complete_source_audit_readiness_metric_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ce artifact: {rel}")

gate_rows = read_csv(run_dir / "generation_closure_return_gate_rows.csv")
admission_rows = read_csv(run_dir / "generation_closure_return_admission_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "generation_closure_return_requirement_rows.csv")}
metric = read_csv(run_dir / "generation_closure_return_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if [row["closure_gate_id"] for row in gate_rows] != [
    "page-hash-coverage-return",
    "complete-source-review-return",
    "actual-generation-result-return",
]:
    raise SystemExit("v61ce closure gate order mismatch")
if gate_rows[0]["closure_ready"] != "1":
    raise SystemExit("v61ce page-hash closure gate should be ready")
if any(row["closure_ready"] != "0" for row in gate_rows[1:]):
    raise SystemExit("v61ce review/generation closure gates should remain blocked")
if len(admission_rows) != 1000:
    raise SystemExit("v61ce admission row count mismatch")
if any(row["generation_execution_admitted"] != "0" for row in admission_rows):
    raise SystemExit("v61ce default admission rows should remain blocked")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in admission_rows):
    raise SystemExit("v61ce must not commit checkpoint payload bytes")
if {row["blocked_reason"] for row in admission_rows} != {
    "complete-source-review-return;actual-generation-result-return"
}:
    raise SystemExit("v61ce blocked reason mismatch")

for requirement_id in ["v61cd-closure-bundle-input", "full-page-hash-coverage-return", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ce requirement should pass: {requirement_id}")
for requirement_id in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "generation-closure-return-intake",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ce requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61ce_") or field.startswith("v61cd_") or field.startswith("v61cb_") or field.startswith("v53t_") or field.startswith("v61bt_") or field.startswith("v61cc_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ce metric {field}: expected {value}, got {metric[field]}")

for gate in ["v61cd-closure-bundle-input", "full-page-hash-coverage-return", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ce gate should pass: {gate}")
for gate in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "generation-closure-return-intake",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ce gate should stay blocked: {gate}")

if gaps["v61cd-closure-bundle-input"] != "ready":
    raise SystemExit("v61ce v61cd input gap should be ready")
if gaps.get("full-page-hash-coverage-return") not in {"ready", "pass"}:
    raise SystemExit("v61ce page-hash coverage gap should be ready")
for gap in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "generation-closure-return-intake",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ce gap should stay blocked: {gap}")

boundary = (run_dir / "V61CE_UBUNTU1_GENERATION_CLOSURE_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "closure_gate_rows=3",
    "generation_closure_admission_rows=1000",
    "total_verified_page_hash_rows=134161",
    "total_required_page_hash_rows=134161",
    "human_review_required_rows=7000",
    "adjudication_required_rows=1000",
    "generation_result_required_artifacts=5",
    "generation_closure_return_intake_ready=0",
    "generation_execution_admitted_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ce=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ce boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ce_ubuntu1_generation_closure_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ce_ubuntu1_generation_closure_return_intake_ready") != 1:
    raise SystemExit("v61ce manifest readiness mismatch")
if manifest.get("closure_gate_rows") != 3:
    raise SystemExit("v61ce manifest gate count mismatch")
if manifest.get("generation_closure_admission_rows") != 1000:
    raise SystemExit("v61ce manifest admission count mismatch")
if manifest.get("generation_closure_return_intake_ready") != 0:
    raise SystemExit("v61ce manifest closure should remain blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ce manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ce") != 0:
    raise SystemExit("v61ce manifest must keep downloaded bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ce manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ce sha256 mismatch: {rel}")
PY

echo "v61ce ubuntu-1 generation closure return intake smoke passed"
