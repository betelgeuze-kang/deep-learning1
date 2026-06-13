#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cs_complete_source_generation_execution_admission_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CS_REUSE_EXISTING="${V61CS_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61ck_real_generation_unblocker_operator_matrix_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "complete_source_query_rows": "1000",
    "full_checkpoint_materialization_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "complete_source_runtime_admission_execution_ready": "0",
    "complete_source_review_return_ready": "0",
    "generation_operator_bundle_handoff_ready": "1",
    "generation_execution_packet_ready": "1",
    "generation_result_artifacts_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_blocked_rows": "1000",
    "materialization_blocked_generation_rows": "0",
    "page_hash_blocked_generation_rows": "0",
    "runtime_admission_blocked_generation_rows": "1000",
    "review_return_blocked_generation_rows": "1000",
    "operator_handoff_blocked_generation_rows": "0",
    "generation_result_artifact_blocked_rows": "1000",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "0",
    "runtime_artifact_blocked_acceptance_rows": "1000",
    "runtime_result_blocked_acceptance_rows": "1000",
    "runtime_page_binding_blocked_acceptance_rows": "1000",
    "runtime_budget_blocked_acceptance_rows": "1000",
    "runtime_identity_blocked_acceptance_rows": "1000",
    "runtime_safety_blocked_acceptance_rows": "1000",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

admission_rows = read_csv(run_dir / "complete_source_generation_execution_admission_rows.csv")
requirement_rows = read_csv(run_dir / "complete_source_generation_execution_admission_requirement_rows.csv")
metric_rows = read_csv(run_dir / "complete_source_generation_execution_admission_metric_rows.csv")
runtime_gap_rows = read_csv(run_dir / "runtime_gap_rows.csv")
decision_rows = read_csv(decision_csv)

if len(admission_rows) != 1000:
    raise SystemExit("v61cs expected 1000 admission rows")
if len(metric_rows) != 1:
    raise SystemExit("v61cs expected one metric row")
if not requirement_rows or not runtime_gap_rows or not decision_rows:
    raise SystemExit("v61cs expected requirement/gap/decision rows")
if any(row["generation_execution_admitted"] != "0" for row in admission_rows):
    raise SystemExit("v61cs must keep all generation execution rows blocked by default")
if any(row["actual_model_generation_ready"] != "0" for row in admission_rows):
    raise SystemExit("v61cs must not claim actual model generation")

required_files = [
    "source_v61ck/real_generation_unblocker_matrix_rows.csv",
    "source_v61ck/real_generation_operator_execution_order_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_requirement_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_requirement_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_metric_rows.csv",
    "source_v61cf/source_bound_generation_execution_packet_rows.csv",
    "source_v61cf/source_bound_generation_prompt_manifest_rows.csv",
    "source_v61cf/source_bound_generation_return_manifest_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    if not (run_dir / rel).is_file():
        raise SystemExit(f"missing required v61cs file: {rel}")

decisions = {row["gate"]: row["status"] for row in decision_rows}
for gate in [
    "complete-source-runtime-admission-execution",
    "complete-source-review-return",
    "actual-generation-result-artifacts",
    "complete-source-generation-execution-admission",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cs expected {gate} blocked, got {decisions.get(gate)!r}")
for gate in [
    "v61ck-operator-matrix-input",
    "v61cr-runtime-admission-return-input",
    "v61cw-runtime-admission-acceptance-input",
    "v61cf-generation-execution-packet-input",
    "full-checkpoint-materialization",
    "completed-full-safetensors-page-hash-coverage",
    "generation-operator-handoff",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cs expected {gate} pass, got {decisions.get(gate)!r}")

boundary = (run_dir / "V61CS_COMPLETE_SOURCE_GENERATION_EXECUTION_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "generation_execution_admission_rows=1000",
    "generation_execution_admitted_rows=0",
    "runtime_admission_blocked_generation_rows=1000",
    "runtime_admission_acceptance_rows=1000",
    "runtime_admission_accepted_rows=0",
    "runtime_artifact_blocked_acceptance_rows=1000",
    "runtime_result_blocked_acceptance_rows=1000",
    "runtime_page_binding_blocked_acceptance_rows=1000",
    "runtime_budget_blocked_acceptance_rows=1000",
    "runtime_identity_blocked_acceptance_rows=1000",
    "runtime_safety_blocked_acceptance_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cs=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"missing boundary snippet: {snippet}")

manifest = json.loads((run_dir / "v61cs_complete_source_generation_execution_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cs_complete_source_generation_execution_admission_gate_ready") != 1:
    raise SystemExit("v61cs manifest ready mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cs manifest must not claim actual generation")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cs produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cs complete-source generation execution admission gate smoke passed"
