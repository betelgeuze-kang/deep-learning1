#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cv_complete_source_runtime_admission_operator_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CV_REUSE_EXISTING="${V61CV_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "real_manifest_runtime_execution_admission_ready": "1",
    "runtime_admission_expansion_packet_rows": "1000",
    "runtime_admission_expansion_required_rows": "1000",
    "runtime_admission_return_artifact_rows": "5",
    "expected_runtime_admission_result_rows": "1000",
    "accepted_runtime_admission_result_rows": "0",
    "operator_bundle_file_rows": "5",
    "operator_command_rows": "5",
    "ready_operator_command_rows": "3",
    "runtime_admission_return_template_rows": "5",
    "guarded_runtime_admission_command_ready": "1",
    "runtime_operator_execution_ready": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cv summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "complete_source_runtime_admission_operator_bundle_file_rows.csv",
    "complete_source_runtime_admission_operator_command_rows.csv",
    "complete_source_runtime_admission_operator_requirement_rows.csv",
    "complete_source_runtime_admission_operator_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CV_COMPLETE_SOURCE_RUNTIME_ADMISSION_OPERATOR_BUNDLE_BOUNDARY.md",
    "v61cv_complete_source_runtime_admission_operator_bundle_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/RUNTIME_ADMISSION_ENV.template",
    "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv",
    "operator_bundle/VERIFY_RUNTIME_ADMISSION_BUNDLE.sh",
    "operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_required_field_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cv artifact: {rel}")

verify_script = run_dir / "operator_bundle/VERIFY_RUNTIME_ADMISSION_BUNDLE.sh"
guard_script = run_dir / "operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh"
if not os.access(verify_script, os.X_OK):
    raise SystemExit("v61cv verify script must be executable")
if not os.access(guard_script, os.X_OK):
    raise SystemExit("v61cv guard script must be executable")
subprocess.run([str(verify_script)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
guard = subprocess.run([str(guard_script)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
if "runtime admission guard prerequisites ready" not in guard.stdout:
    raise SystemExit("v61cv guard should confirm ready prerequisites")

files = read_csv(run_dir / "complete_source_runtime_admission_operator_bundle_file_rows.csv")
commands = read_csv(run_dir / "complete_source_runtime_admission_operator_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_runtime_admission_operator_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_runtime_admission_operator_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
template_rows = read_csv(run_dir / "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv")

if len(files) != 5 or len(commands) != 5 or len(template_rows) != 5:
    raise SystemExit("v61cv file/command/template row count mismatch")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 3:
    raise SystemExit("v61cv ready command count mismatch")
run_command = {row["command_id"]: row for row in commands}["run-complete-source-runtime-admission"]
if run_command["ready_to_run_now"] != "0":
    raise SystemExit("v61cv real runtime execution command must stay external-blocked")

for requirement_id in [
    "v61cq-runtime-admission-expansion-input",
    "v61cr-runtime-admission-return-schema-input",
    "full-checkpoint-materialization",
    "full-page-hash-coverage",
    "source-bound-runtime-seed-admission",
    "operator-bundle-shape",
    "guarded-runtime-admission-command",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cv requirement should pass: {requirement_id}")
for requirement_id in [
    "runtime-admission-return",
    "complete-source-runtime-admission-execution",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cv requirement should stay blocked: {requirement_id}")

for key, value in expected.items():
    if key.startswith("v61cv_"):
        continue
    if key in metric and metric[key] != value:
        raise SystemExit(f"v61cv metric mismatch for {key}: {metric[key]!r} != {value!r}")

for gate in [
    "runtime-admission-expansion-input",
    "runtime-admission-return-schema",
    "operator-bundle-shape",
    "guarded-runtime-admission-command",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cv gate should pass: {gate}")
for gate in [
    "runtime-admission-return",
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cv gate should stay blocked: {gate}")

for gap in [
    "runtime-admission-expansion-input",
    "runtime-admission-return-schema",
    "operator-bundle-shape",
    "guarded-runtime-admission-command",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cv gap should be ready: {gap}")
for gap in [
    "runtime-admission-return",
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cv gap should stay blocked: {gap}")

boundary = (run_dir / "V61CV_COMPLETE_SOURCE_RUNTIME_ADMISSION_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_expansion_packet_rows=1000",
    "runtime_admission_return_artifact_rows=5",
    "expected_runtime_admission_result_rows=1000",
    "accepted_runtime_admission_result_rows=0",
    "operator_bundle_file_rows=5",
    "operator_command_rows=5",
    "guarded_runtime_admission_command_ready=1",
    "complete_source_runtime_admission_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cv=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cv boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cv_complete_source_runtime_admission_operator_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cv_complete_source_runtime_admission_operator_bundle_ready") != 1:
    raise SystemExit("v61cv manifest readiness mismatch")
if manifest.get("guarded_runtime_admission_command_ready") != 1:
    raise SystemExit("v61cv manifest should mark guard prerequisites ready")
if manifest.get("complete_source_runtime_admission_execution_ready") != 0:
    raise SystemExit("v61cv manifest must keep runtime execution blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cv manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cv produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cv complete-source runtime admission operator bundle smoke passed"
