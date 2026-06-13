#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dv_return_bundle_operator_work_order"
RUN_DIR="$RESULTS_DIR/$PREFIX/work_order_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DV_REUSE_EXISTING="${V61DV_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dv_return_bundle_operator_work_order.sh" >/dev/null

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
    "v61dv_return_bundle_operator_work_order_ready": "1",
    "v61du_return_bundle_acceptance_delta_ledger_ready": "1",
    "source_gate_rows": "3",
    "work_order_stage_rows": "9",
    "ready_work_order_stage_rows": "4",
    "blocked_work_order_stage_rows": "5",
    "artifact_work_order_rows": "81",
    "ready_artifact_work_order_rows": "76",
    "blocked_artifact_work_order_rows": "5",
    "row_work_order_rows": "11",
    "open_row_work_order_rows": "11",
    "work_order_command_rows": "9",
    "ready_work_order_command_rows": "4",
    "dispatch_receipt_artifact_work_order_rows": "21",
    "review_chunk_artifact_work_order_rows": "50",
    "aggregate_review_artifact_work_order_rows": "5",
    "generation_result_artifact_work_order_rows": "5",
    "missing_payload_rows": "17483",
    "missing_answer_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_generation_execution_rows": "1000",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "schema_acceptance_ready": "0",
    "return_acceptance_replay_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dv {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_bundle_operator_work_order_stage_rows.csv",
    "return_bundle_operator_artifact_work_order_rows.csv",
    "return_bundle_operator_row_work_order_rows.csv",
    "return_bundle_operator_work_order_command_rows.csv",
    "return_bundle_operator_work_order_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DV_RETURN_BUNDLE_OPERATOR_WORK_ORDER_BOUNDARY.md",
    "v61dv_return_bundle_operator_work_order_manifest.json",
    "source_v61du/v61du_return_bundle_acceptance_delta_ledger_summary.csv",
    "source_v61dq/return_schema_remediation_artifact_rows.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dv artifact: {rel}")

stage_rows = read_csv(run_dir / "return_bundle_operator_work_order_stage_rows.csv")
artifact_rows = read_csv(run_dir / "return_bundle_operator_artifact_work_order_rows.csv")
row_rows = read_csv(run_dir / "return_bundle_operator_row_work_order_rows.csv")
command_rows = read_csv(run_dir / "return_bundle_operator_work_order_command_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if [row["work_order_id"] for row in stage_rows[:4]] != [
    "01-create-return-bundle-root",
    "02-dispatch-receipts",
    "03-review-chunk-returns",
    "04-aggregate-review-return",
]:
    raise SystemExit("v61dv stage order prefix mismatch")
if [row["ready_to_execute_now"] for row in stage_rows] != ["1", "1", "1", "1", "0", "0", "0", "0", "0"]:
    raise SystemExit("v61dv stage readiness mismatch")
if len(artifact_rows) != 81:
    raise SystemExit("v61dv expected 81 artifact rows")
if sum(row["ready_to_prepare_now"] == "1" for row in artifact_rows) != 76:
    raise SystemExit("v61dv expected 76 ready artifact rows")
if sum(row["schema_family"] == "generation-result-return" and row["ready_to_prepare_now"] == "0" for row in artifact_rows) != 5:
    raise SystemExit("v61dv generation result artifacts should be blocked")
if len(row_rows) != 11:
    raise SystemExit("v61dv row work-order count mismatch")
if [row["ready_to_run_now"] for row in command_rows[:5]] != ["1", "1", "1", "1", "0"]:
    raise SystemExit("v61dv command readiness prefix mismatch")

for gate in ["01-create-return-bundle-root", "02-dispatch-receipts", "03-review-chunk-returns", "04-aggregate-review-return", "operator-work-order-ready", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dv expected pass gate: {gate}")
for gate in ["05-schema-and-full-preflight", "08-generation-result-return", "generation-result-work", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dv expected blocked gate: {gate}")
if gaps.get("09-actual-generation-ready") != "blocked":
    raise SystemExit("v61dv actual-generation gap must remain blocked")

boundary = (run_dir / "V61DV_RETURN_BUNDLE_OPERATOR_WORK_ORDER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "work_order_stage_rows=9",
    "ready_work_order_stage_rows=4",
    "artifact_work_order_rows=81",
    "ready_artifact_work_order_rows=76",
    "blocked_artifact_work_order_rows=5",
    "row_work_order_rows=11",
    "missing_payload_rows=17483",
    "missing_answer_review_rows=7000",
    "missing_adjudication_rows=1000",
    "missing_generation_execution_rows=1000",
    "missing_generation_result_artifacts=5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dv boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dv_return_bundle_operator_work_order_manifest.json").read_text(encoding="utf-8"))
if manifest.get("artifact_work_order_rows") != 81:
    raise SystemExit("v61dv manifest artifact count mismatch")
if manifest.get("ready_artifact_work_order_rows") != 76:
    raise SystemExit("v61dv manifest ready artifact count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dv manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dv sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dv produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dv return bundle operator work order smoke passed"
