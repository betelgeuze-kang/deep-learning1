#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ct_complete_source_generation_execution_operator_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CT_REUSE_EXISTING="${V61CT_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null

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
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_blocked_rows": "1000",
    "generation_execution_admission_ready": "0",
    "operator_bundle_file_rows": "5",
    "operator_command_rows": "5",
    "ready_operator_command_rows": "3",
    "generation_result_return_template_rows": "5",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "guarded_generation_command_ready": "0",
    "generation_operator_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ct": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "complete_source_generation_execution_operator_bundle_file_rows.csv",
    "complete_source_generation_execution_operator_command_rows.csv",
    "complete_source_generation_execution_operator_requirement_rows.csv",
    "complete_source_generation_execution_operator_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CT_COMPLETE_SOURCE_GENERATION_EXECUTION_OPERATOR_BUNDLE_BOUNDARY.md",
    "v61ct_complete_source_generation_execution_operator_bundle_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/GENERATION_EXECUTION_ENV.template",
    "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv",
    "operator_bundle/VERIFY_GENERATION_EXECUTION_BUNDLE.sh",
    "operator_bundle/RUN_GENERATION_GUARD.sh",
    "source_v61cs/complete_source_generation_execution_admission_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ct artifact: {rel}")

verify_script = run_dir / "operator_bundle/VERIFY_GENERATION_EXECUTION_BUNDLE.sh"
guard_script = run_dir / "operator_bundle/RUN_GENERATION_GUARD.sh"
if not os.access(verify_script, os.X_OK):
    raise SystemExit("v61ct verify script must be executable")
if not os.access(guard_script, os.X_OK):
    raise SystemExit("v61ct guard script must be executable")
subprocess.run([str(verify_script)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
guard_result = subprocess.run([str(guard_script)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
if guard_result.returncode == 0:
    raise SystemExit("v61ct guard must refuse execution while admitted rows are 0/1000")
if "generation execution remains blocked" not in (guard_result.stderr + guard_result.stdout):
    raise SystemExit("v61ct guard should explain blocked admission")

file_rows = read_csv(run_dir / "complete_source_generation_execution_operator_bundle_file_rows.csv")
command_rows = read_csv(run_dir / "complete_source_generation_execution_operator_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_generation_execution_operator_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_generation_execution_operator_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
template_rows = read_csv(run_dir / "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv")

if len(file_rows) != 5:
    raise SystemExit("v61ct bundle file row count mismatch")
if len(command_rows) != 5:
    raise SystemExit("v61ct operator command row count mismatch")
if len(template_rows) != 5:
    raise SystemExit("v61ct generation result return template row count mismatch")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in file_rows):
    raise SystemExit("v61ct must keep repo payload bytes at zero")
if sum(row["ready_to_run_now"] == "1" for row in command_rows) != 3:
    raise SystemExit("v61ct ready command count mismatch")
run_commands = {row["command_id"]: row for row in command_rows}
if run_commands["run-real-model-generation"]["ready_to_run_now"] != "0":
    raise SystemExit("v61ct real generation command must stay blocked")

for requirement_id in [
    "v61cs-generation-execution-admission-input",
    "v61bt-generation-result-intake-input",
    "operator-bundle-shape",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ct requirement should pass: {requirement_id}")
for requirement_id in [
    "generation-execution-admission",
    "generation-result-return",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ct requirement should stay blocked: {requirement_id}")

for key, value in expected.items():
    if key in metric and metric[key] != value:
        raise SystemExit(f"metric mismatch for {key}: {metric[key]!r} != {value!r}")

for gate in [
    "v61cs-generation-execution-admission-input",
    "v61bt-generation-result-intake-input",
    "operator-bundle-shape",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ct gate should pass: {gate}")
for gate in [
    "generation-execution-admission",
    "generation-result-return",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ct gate should stay blocked: {gate}")

for gap in ["v61cs-generation-execution-admission-input", "operator-bundle-shape"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ct gap should be ready: {gap}")
for gap in [
    "generation-execution-admission",
    "generation-result-return",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ct gap should stay blocked: {gap}")

boundary = (run_dir / "V61CT_COMPLETE_SOURCE_GENERATION_EXECUTION_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "generation_execution_admission_rows=1000",
    "generation_execution_admitted_rows=0",
    "operator_bundle_file_rows=5",
    "operator_command_rows=5",
    "guarded_generation_command_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ct=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ct boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ct_complete_source_generation_execution_operator_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ct_complete_source_generation_execution_operator_bundle_ready") != 1:
    raise SystemExit("v61ct manifest readiness mismatch")
if manifest.get("guarded_generation_command_ready") != 0:
    raise SystemExit("v61ct manifest must keep guarded command blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ct manifest must keep actual generation blocked")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ct produced checkpoint payload files" >&2
  exit 1
fi

echo "v61ct complete-source generation execution operator bundle smoke passed"
