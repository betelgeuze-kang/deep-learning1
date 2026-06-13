#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cw_complete_source_runtime_admission_acceptance_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CW_REUSE_EXISTING="${V61CW_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
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
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "0",
    "operator_guard_blocked_acceptance_rows": "0",
    "runtime_artifact_blocked_acceptance_rows": "1000",
    "runtime_result_blocked_acceptance_rows": "1000",
    "runtime_page_binding_blocked_acceptance_rows": "1000",
    "runtime_budget_blocked_acceptance_rows": "1000",
    "runtime_identity_blocked_acceptance_rows": "1000",
    "runtime_safety_blocked_acceptance_rows": "1000",
    "guarded_runtime_admission_command_ready": "1",
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
    "checkpoint_payload_bytes_downloaded_by_v61cw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cw summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "complete_source_runtime_admission_acceptance_rows.csv",
    "complete_source_runtime_admission_acceptance_requirement_rows.csv",
    "complete_source_runtime_admission_acceptance_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CW_COMPLETE_SOURCE_RUNTIME_ADMISSION_ACCEPTANCE_BRIDGE_BOUNDARY.md",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_manifest.json",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cv/complete_source_runtime_admission_operator_command_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cw artifact: {rel}")

acceptance_rows = read_csv(run_dir / "complete_source_runtime_admission_acceptance_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_runtime_admission_acceptance_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_runtime_admission_acceptance_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(acceptance_rows) != 1000:
    raise SystemExit("v61cw acceptance row count mismatch")
if any(row["runtime_admission_accepted"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cw default rows must keep runtime admission blocked")
if any("runtime-admission-return-artifacts-missing" not in row["blocking_reason"] for row in acceptance_rows):
    raise SystemExit("v61cw default blocking reason should include missing artifacts")
if any(row["operator_guard_ready"] != "1" for row in acceptance_rows):
    raise SystemExit("v61cw guard should be ready for every acceptance row")

for requirement_id in [
    "v61cq-runtime-admission-expansion-input",
    "v61cv-runtime-admission-operator-input",
    "v61cr-runtime-admission-return-input",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cw requirement should pass: {requirement_id}")
for requirement_id in [
    "runtime-admission-return-artifacts",
    "runtime-admission-result-rows",
    "runtime-page-binding-rows",
    "runtime-budget-rows",
    "runtime-identity-rows",
    "runtime-safety-rows",
    "complete-source-runtime-admission-acceptance",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cw requirement should stay blocked: {requirement_id}")

for key, value in expected.items():
    if key.startswith("v61cw_"):
        continue
    if key in metric and metric[key] != value:
        raise SystemExit(f"v61cw metric mismatch for {key}: {metric[key]!r} != {value!r}")

for gate in [
    "runtime-admission-expansion-input",
    "runtime-admission-operator-input",
    "runtime-admission-return-intake",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cw gate should pass: {gate}")
for gate in [
    "runtime-admission-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cw gate should stay blocked: {gate}")

for gap in [
    "runtime-admission-expansion-input",
    "runtime-admission-operator-input",
    "runtime-admission-return-intake",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cw gap should be ready: {gap}")
for gap in [
    "runtime-admission-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cw gap should stay blocked: {gap}")

boundary = (run_dir / "V61CW_COMPLETE_SOURCE_RUNTIME_ADMISSION_ACCEPTANCE_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_acceptance_rows=1000",
    "runtime_admission_accepted_rows=0",
    "operator_guard_blocked_acceptance_rows=0",
    "runtime_artifact_blocked_acceptance_rows=1000",
    "runtime_result_blocked_acceptance_rows=1000",
    "runtime_page_binding_blocked_acceptance_rows=1000",
    "runtime_budget_blocked_acceptance_rows=1000",
    "runtime_identity_blocked_acceptance_rows=1000",
    "runtime_safety_blocked_acceptance_rows=1000",
    "guarded_runtime_admission_command_ready=1",
    "complete_source_runtime_admission_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cw=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cw boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cw_complete_source_runtime_admission_acceptance_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cw_complete_source_runtime_admission_acceptance_bridge_ready") != 1:
    raise SystemExit("v61cw manifest readiness mismatch")
if manifest.get("runtime_admission_accepted_rows") != 0:
    raise SystemExit("v61cw manifest should keep accepted rows at zero")
if manifest.get("complete_source_runtime_admission_execution_ready") != 0:
    raise SystemExit("v61cw manifest should keep runtime execution blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cw manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cw produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cw complete-source runtime admission acceptance bridge smoke passed"
