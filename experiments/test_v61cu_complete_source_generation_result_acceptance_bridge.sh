#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cu_complete_source_generation_result_acceptance_bridge/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cu_complete_source_generation_result_acceptance_bridge_decision.csv"

V61CU_REUSE_EXISTING="${V61CU_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null

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
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "generation_result_acceptance_rows": "1000",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_blocked_rows": "1000",
    "generation_execution_admission_ready": "0",
    "guarded_generation_command_ready": "0",
    "generation_operator_execution_ready": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_result_supplied_rows": "0",
    "generation_result_accepted_rows": "0",
    "answer_accepted_rows": "0",
    "citation_accepted_rows": "0",
    "latency_accepted_rows": "0",
    "admission_blocked_acceptance_rows": "1000",
    "operator_blocked_acceptance_rows": "1000",
    "result_artifact_blocked_acceptance_rows": "1000",
    "answer_blocked_acceptance_rows": "1000",
    "citation_blocked_acceptance_rows": "1000",
    "latency_blocked_acceptance_rows": "1000",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cu summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "complete_source_generation_result_acceptance_rows.csv",
    "complete_source_generation_result_acceptance_requirement_rows.csv",
    "complete_source_generation_result_acceptance_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CU_COMPLETE_SOURCE_GENERATION_RESULT_ACCEPTANCE_BRIDGE_BOUNDARY.md",
    "v61cu_complete_source_generation_result_acceptance_bridge_manifest.json",
    "source_v61cs/complete_source_generation_execution_admission_rows.csv",
    "source_v61ct/complete_source_generation_execution_operator_command_rows.csv",
    "source_v61bt/actual_generation_query_result_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
    "source_v61bt/actual_generation_result_validation_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cu artifact: {rel}")

acceptance_rows = read_csv(run_dir / "complete_source_generation_result_acceptance_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_generation_result_acceptance_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_generation_result_acceptance_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(acceptance_rows) != 1000:
    raise SystemExit("v61cu acceptance row count mismatch")
if any(row["generation_execution_admitted"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu default rows must keep execution admission at zero")
if any(row["generation_result_supplied"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu default rows must have no supplied generation result")
if any(row["generation_result_accepted"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu default rows must accept no generation result")
if any(row["actual_model_generation_ready"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu default rows must keep actual generation blocked")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cu"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in acceptance_rows):
    raise SystemExit("v61cu must not commit checkpoint payload bytes")
if any("generation-execution-admission-blocked" not in row["blocking_reason"] for row in acceptance_rows):
    raise SystemExit("v61cu default blocking reason should include execution admission")
if any("generation-result-artifacts-missing" not in row["blocking_reason"] for row in acceptance_rows):
    raise SystemExit("v61cu default blocking reason should include result artifact missing")

for requirement_id in [
    "v61cs-generation-execution-admission-input",
    "v61ct-generation-operator-bundle-input",
    "v61bt-generation-result-intake-input",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cu requirement should pass: {requirement_id}")
for requirement_id in [
    "complete-source-generation-execution-admission",
    "generation-operator-execution",
    "generation-result-artifact-return",
    "answer-citation-latency-acceptance",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cu requirement should stay blocked: {requirement_id}")

for key, value in expected.items():
    if key.startswith("v61cu_"):
        continue
    if key in metric and metric[key] != value:
        raise SystemExit(f"v61cu metric mismatch for {key}: {metric[key]!r} != {value!r}")

for gate in [
    "v61cs-generation-execution-admission-input",
    "v61ct-generation-operator-bundle-input",
    "v61bt-generation-result-intake-input",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cu gate should pass: {gate}")
for gate in [
    "complete-source-generation-execution-admission",
    "generation-operator-execution",
    "generation-result-artifact-return",
    "answer-citation-latency-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cu gate should stay blocked: {gate}")

for gap in [
    "v61cs-generation-execution-admission-input",
    "v61ct-generation-operator-bundle-input",
    "v61bt-generation-result-intake-input",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cu gap should be ready: {gap}")
for gap in [
    "complete-source-generation-execution-admission",
    "generation-operator-execution",
    "generation-result-artifact-return",
    "answer-citation-latency-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cu gap should stay blocked: {gap}")

boundary = (run_dir / "V61CU_COMPLETE_SOURCE_GENERATION_RESULT_ACCEPTANCE_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "generation_result_acceptance_rows=1000",
    "generation_execution_admitted_rows=0",
    "generation_result_accepted_rows=0",
    "answer_accepted_rows=0",
    "citation_accepted_rows=0",
    "latency_accepted_rows=0",
    "admission_blocked_acceptance_rows=1000",
    "result_artifact_blocked_acceptance_rows=1000",
    "actual_model_generation_ready_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cu=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cu boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cu_complete_source_generation_result_acceptance_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cu_complete_source_generation_result_acceptance_bridge_ready") != 1:
    raise SystemExit("v61cu manifest readiness mismatch")
if manifest.get("generation_result_acceptance_rows") != 1000:
    raise SystemExit("v61cu manifest row count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cu manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61cu") != 0:
    raise SystemExit("v61cu manifest must keep downloaded bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cu produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cu complete-source generation result acceptance bridge smoke passed"
