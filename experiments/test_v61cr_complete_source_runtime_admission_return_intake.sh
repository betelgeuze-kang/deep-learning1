#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cr_complete_source_runtime_admission_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61cr_complete_source_runtime_admission_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cr_complete_source_runtime_admission_return_intake_decision.csv"

V61CR_REUSE_EXISTING="${V61CR_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null

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
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "complete_source_query_rows": "1000",
    "runtime_admission_expansion_packet_rows": "1000",
    "runtime_admission_expansion_required_rows": "1000",
    "expected_runtime_admission_return_artifacts": "5",
    "supplied_runtime_admission_return_artifacts": "0",
    "accepted_runtime_admission_return_artifacts": "0",
    "missing_runtime_admission_return_artifacts": "5",
    "expected_runtime_admission_result_rows": "1000",
    "accepted_runtime_admission_result_rows": "0",
    "invalid_runtime_admission_result_rows": "0",
    "missing_runtime_admission_result_rows": "1000",
    "accepted_runtime_page_binding_rows": "0",
    "missing_runtime_page_binding_rows": "1000",
    "accepted_runtime_budget_rows": "0",
    "missing_runtime_budget_rows": "1000",
    "accepted_runtime_identity_rows": "0",
    "missing_runtime_identity_rows": "59",
    "accepted_runtime_abstain_fallback_rows": "0",
    "missing_runtime_abstain_fallback_rows": "1000",
    "runtime_admission_return_artifact_ready": "0",
    "runtime_admission_result_rows_ready": "0",
    "runtime_page_binding_ready": "0",
    "runtime_budget_ready": "0",
    "runtime_identity_ready": "0",
    "runtime_safety_ready": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cr": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cr {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_runtime_admission_return_required_field_rows.csv",
    "complete_source_runtime_admission_return_template_rows.csv",
    "complete_source_runtime_admission_return_artifact_status_rows.csv",
    "complete_source_runtime_admission_return_invalid_rows.csv",
    "complete_source_runtime_admission_return_requirement_rows.csv",
    "complete_source_runtime_admission_return_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CR_COMPLETE_SOURCE_RUNTIME_ADMISSION_RETURN_INTAKE_BOUNDARY.md",
    "v61cr_complete_source_runtime_admission_return_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cq/complete_source_runtime_admission_operator_command_rows.csv",
    "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cr artifact: {rel}")

required_fields = read_csv(run_dir / "complete_source_runtime_admission_return_required_field_rows.csv")
templates = read_csv(run_dir / "complete_source_runtime_admission_return_template_rows.csv")
artifact_status = read_csv(run_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv")
invalid_rows = read_csv(run_dir / "complete_source_runtime_admission_return_invalid_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_runtime_admission_return_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_runtime_admission_return_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(required_fields) != 32:
    raise SystemExit("v61cr required field row count mismatch")
if len(templates) != 5:
    raise SystemExit("v61cr template row count mismatch")
if len(artifact_status) != 5:
    raise SystemExit("v61cr artifact status row count mismatch")
if any(row["supplied"] != "0" or row["accepted"] != "0" or row["status"] != "missing" for row in artifact_status):
    raise SystemExit("v61cr default path should keep all artifacts missing")
if invalid_rows[0]["status"] != "none":
    raise SystemExit("v61cr default path should not create invalid supplied rows")

for requirement_id in ["v61cq-runtime-admission-expansion-packet-input", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cr requirement should pass: {requirement_id}")
for requirement_id in [
    "runtime-admission-return-artifacts",
    "runtime-admission-result-rows",
    "runtime-page-binding-rows",
    "runtime-budget-rows",
    "runtime-identity-rows",
    "runtime-safety-rows",
    "complete-source-runtime-admission-execution",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cr requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cr_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cr metric {field}: expected {value}, got {metric[field]}")

for gate in ["v61cq-runtime-admission-expansion-packet-input", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cr gate should pass: {gate}")
for gate in [
    "runtime-admission-return-artifacts",
    "runtime-admission-result-rows",
    "runtime-page-binding-rows",
    "runtime-budget-rows",
    "runtime-identity-rows",
    "runtime-safety-rows",
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cr gate should stay blocked: {gate}")

if gaps["v61cq-runtime-admission-expansion-packet-input"] != "ready":
    raise SystemExit("v61cr v61cq input gap should be ready")
for gap in [
    "runtime-admission-return-artifacts",
    "runtime-admission-result-rows",
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cr gap should stay blocked: {gap}")

boundary = (run_dir / "V61CR_COMPLETE_SOURCE_RUNTIME_ADMISSION_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "runtime_admission_expansion_packet_rows=1000",
    "expected_runtime_admission_return_artifacts=5",
    "supplied_runtime_admission_return_artifacts=0",
    "accepted_runtime_admission_return_artifacts=0",
    "missing_runtime_admission_return_artifacts=5",
    "expected_runtime_admission_result_rows=1000",
    "accepted_runtime_admission_result_rows=0",
    "missing_runtime_admission_result_rows=1000",
    "accepted_runtime_page_binding_rows=0",
    "accepted_runtime_budget_rows=0",
    "accepted_runtime_identity_rows=0",
    "accepted_runtime_abstain_fallback_rows=0",
    "runtime_admission_return_artifact_ready=0",
    "complete_source_runtime_admission_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cr=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cr boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cr_complete_source_runtime_admission_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cr_complete_source_runtime_admission_return_intake_ready") != 1:
    raise SystemExit("v61cr manifest readiness mismatch")
if manifest.get("accepted_runtime_admission_return_artifacts") != 0:
    raise SystemExit("v61cr manifest accepted artifacts should be zero")
if manifest.get("complete_source_runtime_admission_execution_ready") != 0:
    raise SystemExit("v61cr manifest should keep runtime admission execution blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cr manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cr sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cr must not write checkpoint payload files" >&2
  exit 1
fi

echo "v61cr complete-source runtime admission return intake smoke passed"
