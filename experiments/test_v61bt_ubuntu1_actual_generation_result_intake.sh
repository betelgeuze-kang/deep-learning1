#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bt_ubuntu1_actual_generation_result_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61BT_REUSE_EXISTING="${V61BT_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

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
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bs_ubuntu1_post_receipt_verification_result_intake_ready": "1",
    "post_receipt_verification_result_intake_ready": "0",
    "generation_result_input_supplied": "0",
    "expected_generation_result_artifacts": "5",
    "supplied_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "invalid_generation_result_artifacts": "0",
    "missing_generation_result_artifacts": "5",
    "target_root_path": ubuntu1_target,
    "expected_generation_rows": "1000",
    "complete_source_query_rows": "1000",
    "generation_query_result_rows": "1000",
    "generation_query_status_rows": "1000",
    "accepted_generation_rows": "0",
    "accepted_answer_rows": "0",
    "accepted_citation_rows": "0",
    "accepted_latency_rows": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "complete_source_review_return_ready": "0",
    "generation_admission_result_ready": "0",
    "generation_packet_artifacts_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bt": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bt {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "actual_generation_result_required_field_rows.csv",
    "actual_generation_result_template_rows.csv",
    "actual_generation_result_status_rows.csv",
    "actual_generation_result_validation_rows.csv",
    "actual_generation_query_result_rows.csv",
    "actual_generation_result_requirement_rows.csv",
    "actual_generation_result_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BT_UBUNTU1_ACTUAL_GENERATION_RESULT_INTAKE_BOUNDARY.md",
    "v61bt_ubuntu1_actual_generation_result_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61bs/post_receipt_verification_result_metric_rows.csv",
    "source_v61bs/post_receipt_verification_promotion_requirement_rows.csv",
    "source_v53r/review_query_packet_rows.csv",
    "source_v53r/review_packet_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bt artifact: {rel}")

required_fields = read_csv(run_dir / "actual_generation_result_required_field_rows.csv")
templates = read_csv(run_dir / "actual_generation_result_template_rows.csv")
status_rows = read_csv(run_dir / "actual_generation_result_status_rows.csv")
validation_rows = read_csv(run_dir / "actual_generation_result_validation_rows.csv")
query_rows = read_csv(run_dir / "actual_generation_query_result_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "actual_generation_result_requirement_rows.csv")}
metric = read_csv(run_dir / "actual_generation_result_metric_rows.csv")[0]

if len(required_fields) != 42:
    raise SystemExit("v61bt required field row count mismatch")
if len(templates) != 5 or len(status_rows) != 5 or len(validation_rows) != 5:
    raise SystemExit("v61bt template/status/validation row count mismatch")
if len(query_rows) != 1000:
    raise SystemExit("v61bt query result row count mismatch")

if any(row["result_supplied"] != "0" for row in status_rows):
    raise SystemExit("v61bt default path should have no supplied generation artifacts")
if any(row["result_accepted"] != "0" for row in status_rows):
    raise SystemExit("v61bt default path should accept no generation artifacts")
if any(row["result_status"] != "deferred-with-reason-final" for row in status_rows):
    raise SystemExit("v61bt default path should final-defer generation artifacts")
if any(row["reason"] != "result-artifact-not-supplied" for row in status_rows):
    raise SystemExit("v61bt default deferral reason mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bt"] != "0" for row in status_rows):
    raise SystemExit("v61bt must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in status_rows):
    raise SystemExit("v61bt must not commit checkpoint payload bytes")
if any(row["status"] != "blocked" for row in validation_rows):
    raise SystemExit("v61bt default validation rows should remain blocked")

if any(row["generation_result_supplied"] != "0" for row in query_rows):
    raise SystemExit("v61bt default query rows should have no supplied generation")
if any(row["generation_result_accepted"] != "0" for row in query_rows):
    raise SystemExit("v61bt default query rows should accept no generation")
if any(row["actual_model_generation_ready"] != "0" for row in query_rows):
    raise SystemExit("v61bt default query rows should keep actual generation blocked")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in query_rows):
    raise SystemExit("v61bt query rows must not commit checkpoint payload bytes")

if requirements["v61bs-verification-result-input"]["status"] != "pass":
    raise SystemExit("v61bt v61bs input should pass")
for requirement_id in [
    "generation-prerequisites-ready",
    "generation-answer-results",
    "actual-model-generation",
    "production-latency",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bt requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61bt_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bt metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61bs-verification-result-input", "result-schema-template", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bt gate should pass: {gate}")
for gate in [
    "generation-prerequisites",
    "generation-result-artifacts",
    "actual-model-generation",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bt gate should stay blocked: {gate}")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
if gaps["v61bs-verification-result-input"] != "ready":
    raise SystemExit("v61bt v61bs gap should be ready")
for gap in [
    "generation-prerequisites",
    "generation-result-artifacts",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bt gap should stay blocked: {gap}")

boundary = (run_dir / "V61BT_UBUNTU1_ACTUAL_GENERATION_RESULT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "generation_result_input_supplied=0",
    "expected_generation_result_artifacts=5",
    "accepted_generation_result_artifacts=0",
    "target_root_path=" + ubuntu1_target,
    "expected_generation_rows=1000",
    "generation_query_result_rows=1000",
    "accepted_generation_rows=0",
    "post_receipt_verification_result_intake_ready=0",
    "local_checkpoint_materialization_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "complete_source_review_return_ready=0",
    "generation_admission_result_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bt=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bt boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bt_ubuntu1_actual_generation_result_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bt_ubuntu1_actual_generation_result_intake_ready") != 1:
    raise SystemExit("v61bt manifest readiness mismatch")
if manifest.get("accepted_generation_result_artifacts") != 0:
    raise SystemExit("v61bt manifest accepted artifact count mismatch")
if manifest.get("complete_source_query_rows") != 1000:
    raise SystemExit("v61bt manifest query count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61bt manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bt") != 0:
    raise SystemExit("v61bt manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bt sha256 mismatch: {rel}")
PY

echo "v61bt ubuntu-1 actual generation result intake smoke passed"
