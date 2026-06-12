#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ca_ubuntu1_remaining_page_hash_result_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CA_REUSE_EXISTING="${V61CA_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh" >/dev/null

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
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": "1",
    "target_root_path": ubuntu1_target,
    "page_hash_result_input_supplied": "0",
    "expected_remaining_page_hash_result_rows": "131808",
    "supplied_remaining_page_hash_result_rows": "0",
    "accepted_remaining_page_hash_result_rows": "0",
    "invalid_remaining_page_hash_result_rows": "0",
    "missing_remaining_page_hash_result_rows": "131808",
    "existing_verified_page_hash_rows": "2353",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "2353",
    "remaining_page_hash_execution_chunk_rows": "286",
    "result_schema_ready": "0",
    "result_artifact_ready": "0",
    "remaining_page_hash_result_intake_ready": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ca": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ca {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "remaining_page_hash_result_required_field_rows.csv",
    "remaining_page_hash_result_template_rows.csv",
    "remaining_page_hash_result_validation_rows.csv",
    "remaining_page_hash_result_invalid_rows.csv",
    "remaining_page_hash_result_chunk_status_rows.csv",
    "existing_page_hash_preservation_rows.csv",
    "remaining_page_hash_result_requirement_rows.csv",
    "remaining_page_hash_result_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CA_UBUNTU1_REMAINING_PAGE_HASH_RESULT_INTAKE_BOUNDARY.md",
    "v61ca_ubuntu1_remaining_page_hash_result_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61bz/remaining_page_hash_execution_chunk_rows.csv",
    "source_v61bz/verified_page_hash_skip_rows.csv",
    "source_v61bz/remaining_page_hash_result_schema_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ca artifact: {rel}")

required_fields = read_csv(run_dir / "remaining_page_hash_result_required_field_rows.csv")
templates = read_csv(run_dir / "remaining_page_hash_result_template_rows.csv")
validation_rows = {row["validation_id"]: row for row in read_csv(run_dir / "remaining_page_hash_result_validation_rows.csv")}
invalid_rows = read_csv(run_dir / "remaining_page_hash_result_invalid_rows.csv")
chunk_status_rows = read_csv(run_dir / "remaining_page_hash_result_chunk_status_rows.csv")
preservation_rows = read_csv(run_dir / "existing_page_hash_preservation_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "remaining_page_hash_result_requirement_rows.csv")}
metric = read_csv(run_dir / "remaining_page_hash_result_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(required_fields) != 10 or len(templates) != 2:
    raise SystemExit("v61ca required field/template row count mismatch")
if invalid_rows[0]["status"] != "none":
    raise SystemExit("v61ca default path should not create invalid supplied rows")
if len(chunk_status_rows) != 286:
    raise SystemExit("v61ca chunk status row count mismatch")
if sum(int(row["planned_page_hash_rows"]) for row in chunk_status_rows) != 131808:
    raise SystemExit("v61ca planned remaining page hash row sum mismatch")
if sum(int(row["missing_page_hash_rows"]) for row in chunk_status_rows) != 131808:
    raise SystemExit("v61ca missing remaining page hash row sum mismatch")
if any(row["accepted_page_hash_rows"] != "0" or row["invalid_page_hash_rows"] != "0" for row in chunk_status_rows):
    raise SystemExit("v61ca default path should accept no result rows")
if any(row["result_status"] != "deferred-with-reason-final" for row in chunk_status_rows):
    raise SystemExit("v61ca default path should final-defer all chunks")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ca"] != "0" for row in chunk_status_rows):
    raise SystemExit("v61ca must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in chunk_status_rows):
    raise SystemExit("v61ca must not commit checkpoint payload bytes")

if len(preservation_rows) != 1:
    raise SystemExit("v61ca should preserve one existing verified shard row")
if preservation_rows[0]["verified_page_hash_rows"] != "2353":
    raise SystemExit("v61ca existing page hash preservation row mismatch")
if preservation_rows[0]["preservation_status"] != "preserved-existing-v61bw-page-hash-witness":
    raise SystemExit("v61ca preservation status mismatch")

if validation_rows["remaining-page-hash-result-input"]["status"] != "blocked":
    raise SystemExit("v61ca result input should be blocked without supplied rows")
if validation_rows["remaining-page-hash-result-schema"]["status"] != "blocked":
    raise SystemExit("v61ca result schema should be blocked without supplied rows")
if validation_rows["remaining-page-hash-result-completeness"]["status"] != "blocked":
    raise SystemExit("v61ca completeness should be blocked without supplied rows")
if validation_rows["existing-page-hash-preservation"]["status"] != "pass":
    raise SystemExit("v61ca existing page hash preservation should pass")
if validation_rows["final-deferred-default"]["status"] != "pass":
    raise SystemExit("v61ca default deferral should pass")
if validation_rows["final-deferred-default"]["missing_rows"] != "131808":
    raise SystemExit("v61ca default deferral should record all missing result rows")

for requirement_id in ["v61bz-operator-bundle-input", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ca requirement should pass: {requirement_id}")
for requirement_id in [
    "remaining-page-hash-result-artifact",
    "accepted-all-remaining-page-hash-results",
    "completed-full-safetensors-page-hash-coverage",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ca requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61ca_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ca metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61bz-operator-bundle-input",
    "result-schema-template",
    "existing-page-hash-preservation",
    "default-no-env-deferral",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ca gate should pass: {gate}")
for gate in [
    "remaining-page-hash-result-artifact",
    "accepted-all-remaining-page-hash-results",
    "completed-full-safetensors-page-hash-coverage",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ca gate should stay blocked: {gate}")

if gaps["v61bz-operator-bundle-input"] != "ready":
    raise SystemExit("v61ca v61bz input gap should be ready")
for gap in [
    "remaining-page-hash-result-artifact",
    "accepted-all-remaining-page-hash-results",
    "completed-full-safetensors-page-hash-coverage",
    "actual-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ca gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ca_ubuntu1_remaining_page_hash_result_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ca_ubuntu1_remaining_page_hash_result_intake_ready") != 1:
    raise SystemExit("v61ca manifest readiness mismatch")
if manifest.get("accepted_remaining_page_hash_result_rows") != 0:
    raise SystemExit("v61ca manifest accepted result count mismatch")
if manifest.get("missing_remaining_page_hash_result_rows") != 131808:
    raise SystemExit("v61ca manifest missing result count mismatch")
if manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61ca manifest should keep full coverage blocked")

boundary = (run_dir / "V61CA_UBUNTU1_REMAINING_PAGE_HASH_RESULT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "page_hash_result_input_supplied=0",
    "expected_remaining_page_hash_result_rows=131808",
    "accepted_remaining_page_hash_result_rows=0",
    "missing_remaining_page_hash_result_rows=131808",
    "existing_verified_page_hash_rows=2353",
    "total_required_page_hash_rows=134161",
    "total_verified_page_hash_rows=2353",
    "remaining_page_hash_result_intake_ready=0",
    "completed_full_safetensors_page_hash_coverage_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ca=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ca boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ca sha256 mismatch: {rel}")
PY

echo "v61ca ubuntu-1 remaining page-hash result intake smoke passed"
