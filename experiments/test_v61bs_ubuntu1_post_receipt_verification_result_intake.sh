#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bs_ubuntu1_post_receipt_verification_result_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61bs_ubuntu1_post_receipt_verification_result_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bs_ubuntu1_post_receipt_verification_result_intake_decision.csv"

V61BS_REUSE_EXISTING="${V61BS_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bs_ubuntu1_post_receipt_verification_result_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "v61bs_ubuntu1_post_receipt_verification_result_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready": "1",
    "verification_result_input_supplied": "0",
    "expected_verification_result_artifacts": "3",
    "supplied_verification_result_artifacts": "0",
    "accepted_verification_result_artifacts": "0",
    "invalid_verification_result_artifacts": "0",
    "missing_verification_result_artifacts": "3",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "identity_verification_result_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "required_page_hash_rows": "134161",
    "verified_page_hash_rows_from_result": "0",
    "full_page_hash_result_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "complete_source_query_rows": "1000",
    "complete_source_review_return_ready": "0",
    "generation_admission_result_ready": "0",
    "post_receipt_verification_result_intake_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bs {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_receipt_verification_result_required_field_rows.csv",
    "post_receipt_verification_result_template_rows.csv",
    "post_receipt_verification_result_status_rows.csv",
    "post_receipt_verification_result_validation_rows.csv",
    "post_receipt_verification_promotion_requirement_rows.csv",
    "post_receipt_verification_result_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BS_UBUNTU1_POST_RECEIPT_VERIFICATION_RESULT_INTAKE_BOUNDARY.md",
    "v61bs_ubuntu1_post_receipt_verification_result_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61br/ubuntu1_post_receipt_verification_command_rows.csv",
    "source_v61br/ubuntu1_post_receipt_materialization_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bs artifact: {rel}")

required_fields = read_csv(run_dir / "post_receipt_verification_result_required_field_rows.csv")
templates = read_csv(run_dir / "post_receipt_verification_result_template_rows.csv")
status_rows = read_csv(run_dir / "post_receipt_verification_result_status_rows.csv")
validation_rows = read_csv(run_dir / "post_receipt_verification_result_validation_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "post_receipt_verification_promotion_requirement_rows.csv")}
metric = read_csv(run_dir / "post_receipt_verification_result_metric_rows.csv")[0]

if len(required_fields) != 30:
    raise SystemExit("v61bs required field row count mismatch")
if len(templates) != 3 or len(status_rows) != 3 or len(validation_rows) != 3:
    raise SystemExit("v61bs template/status/validation row count mismatch")
if any(row["result_supplied"] != "0" for row in status_rows):
    raise SystemExit("v61bs default path should have no supplied result artifacts")
if any(row["result_accepted"] != "0" for row in status_rows):
    raise SystemExit("v61bs default path should accept no result artifacts")
if any(row["result_status"] != "deferred-with-reason-final" for row in status_rows):
    raise SystemExit("v61bs default path should final-defer result artifacts")
if any(row["reason"] != "result-artifact-not-supplied" for row in status_rows):
    raise SystemExit("v61bs default deferral reason mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bs"] != "0" for row in status_rows):
    raise SystemExit("v61bs must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in status_rows):
    raise SystemExit("v61bs must not commit checkpoint payload bytes")

if requirements["v61br-promotion-input"]["status"] != "pass":
    raise SystemExit("v61bs v61br input should pass")
for requirement_id in [
    "v61t-identity-verification-result",
    "v61an-full-page-hash-result",
    "v53t-complete-source-review-return",
    "v61ae-generation-admission-result",
    "actual-generation-result",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bs requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61bs_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bs metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61br-promotion-input", "result-schema-template", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bs gate should pass: {gate}")
for gate in [
    "verification-result-artifacts",
    "identity-verification-result",
    "full-page-hash-result",
    "complete-source-review-return",
    "generation-admission-result",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bs gate should stay blocked: {gate}")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
if gaps["v61br-promotion-input"] != "ready":
    raise SystemExit("v61bs v61br gap should be ready")
for gap in [
    "post-receipt-verification-results",
    "identity-verified-local-shards",
    "full-page-hash-binding",
    "complete-source-review-return",
    "generation-admission",
    "actual-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bs gap should stay blocked: {gap}")

boundary = (run_dir / "V61BS_UBUNTU1_POST_RECEIPT_VERIFICATION_RESULT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "verification_result_input_supplied=0",
    "expected_verification_result_artifacts=3",
    "accepted_verification_result_artifacts=0",
    f"target_root_path={ubuntu1_target}",
    "identity_verification_result_ready=0",
    "required_page_hash_rows=134161",
    "verified_page_hash_rows_from_result=0",
    "complete_source_review_return_ready=0",
    "generation_admission_result_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bs=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bs boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61bs_ubuntu1_post_receipt_verification_result_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bs_ubuntu1_post_receipt_verification_result_intake_ready") != 1:
    raise SystemExit("v61bs manifest readiness mismatch")
if manifest.get("accepted_verification_result_artifacts") != 0:
    raise SystemExit("v61bs manifest accepted result count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61bs manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bs") != 0:
    raise SystemExit("v61bs manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bs sha256 mismatch: {rel}")
PY

echo "v61bs ubuntu-1 post-receipt verification result intake smoke passed"
