#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ak_complete_source_external_return_operator_checklist"
RUN_DIR="$RESULTS_DIR/$PREFIX/checklist_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AK_REUSE_EXISTING="${V53AK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null

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
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "v53aj_complete_source_return_closure_dashboard_ready": "1",
    "v53ai_complete_source_external_return_bundle_intake_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "operator_checklist_ready": "1",
    "checklist_rows": "81",
    "dispatch_receipt_checklist_rows": "21",
    "review_chunk_return_checklist_rows": "50",
    "aggregate_review_return_checklist_rows": "5",
    "generation_result_return_checklist_rows": "5",
    "supplied_checklist_rows": "0",
    "missing_checklist_rows": "81",
    "template_named_supplied_rows": "0",
    "accepted_by_v53ak_rows": "0",
    "closure_checklist_rows": "9",
    "family_checklist_rows": "4",
    "send_bundle_ready": "1",
    "return_bundle_mapping_ready": "1",
    "closure_item_rows": "12",
    "ready_closure_item_rows": "3",
    "blocked_closure_item_rows": "9",
    "answer_review_accepted_rows": "0",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ak": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ak {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_operator_checklist_rows.csv",
    "external_return_operator_closure_checklist_rows.csv",
    "external_return_operator_family_checklist_rows.csv",
    "external_return_operator_checklist_requirement_rows.csv",
    "external_return_operator_checklist_metric_rows.csv",
    "runtime_gap_rows.csv",
    "EXTERNAL_RETURN_OPERATOR_CHECKLIST.md",
    "V53AK_COMPLETE_SOURCE_EXTERNAL_RETURN_OPERATOR_CHECKLIST_BOUNDARY.md",
    "v53ak_complete_source_external_return_operator_checklist_manifest.json",
    "source_v53aj/v53aj_complete_source_return_closure_dashboard_summary.csv",
    "source_v53ai/v53ai_complete_source_external_return_bundle_intake_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ak artifact: {rel}")

checklist_rows = read_csv(run_dir / "external_return_operator_checklist_rows.csv")
closure_rows = read_csv(run_dir / "external_return_operator_closure_checklist_rows.csv")
family_rows = read_csv(run_dir / "external_return_operator_family_checklist_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_operator_checklist_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_operator_checklist_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(checklist_rows) != 81:
    raise SystemExit("v53ak expected 81 checklist rows")
if sum(int(row["artifact_supplied"]) for row in checklist_rows) != 0:
    raise SystemExit("v53ak default smoke should have zero supplied artifacts")
if sum(int(row["accepted_by_v53ak"]) for row in checklist_rows) != 0:
    raise SystemExit("v53ak must not accept evidence")
family_counts = {
    "dispatch-receipt": 21,
    "review-chunk-return": 50,
    "aggregate-review-return": 5,
    "generation-result-return": 5,
}
for family, count in family_counts.items():
    if sum(1 for row in checklist_rows if row["return_family"] == family) != count:
        raise SystemExit(f"v53ak family checklist count mismatch: {family}")
if not all(row["accepted_by_downstream_required"] == "1" for row in checklist_rows):
    raise SystemExit("v53ak should mark all checklist rows as downstream-required")
if len(closure_rows) != 9:
    raise SystemExit("v53ak expected nine closure checklist rows")
if len(family_rows) != 4:
    raise SystemExit("v53ak expected four family checklist rows")
for row in family_rows:
    if row["expected_artifact_rows"] != str(family_counts[row["return_family"]]):
        raise SystemExit(f"v53ak family expected count mismatch: {row['return_family']}")
    if row["supplied_artifact_rows"] != "0":
        raise SystemExit(f"v53ak family should have zero supplied rows by default: {row['return_family']}")

for field, value in expected.items():
    if field.startswith("v53ak_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ak metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53aj-dashboard-input",
    "checklist-row-coverage",
    "template-files-not-accepted",
    "v53ak-does-not-accept-evidence",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ak requirement should pass: {requirement_id}")
for requirement_id in [
    "return-bundle-directory",
    "all-artifacts-supplied",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ak requirement should stay blocked: {requirement_id}")

for gate in [
    "v53aj-dashboard-input",
    "operator-checklist",
    "template-files-not-accepted",
    "v53ak-does-not-accept-evidence",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ak decision should pass: {gate}")
for gate in [
    "return-bundle-directory",
    "all-artifacts-supplied",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ak decision should stay blocked: {gate}")

if gaps.get("operator-checklist") != "ready":
    raise SystemExit("v53ak operator checklist gap should be ready")
for gap in [
    "return-bundle-directory",
    "all-artifacts-supplied",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ak gap should stay blocked: {gap}")

readme = (run_dir / "EXTERNAL_RETURN_OPERATOR_CHECKLIST.md").read_text(encoding="utf-8")
for snippet in [
    "dispatch_receipts/*.json",
    "review_chunk_returns/chunks/",
    "aggregate_review_return/",
    "generation_result_return/",
    "V53AI_RETURN_BUNDLE_DIR=/path/to/final_return_bundle",
]:
    if snippet not in readme:
        raise SystemExit(f"v53ak readme missing: {snippet}")

boundary = (run_dir / "V53AK_COMPLETE_SOURCE_EXTERNAL_RETURN_OPERATOR_CHECKLIST_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "operator_checklist_ready=1",
    "checklist_rows=81",
    "dispatch_receipt_checklist_rows=21",
    "review_chunk_return_checklist_rows=50",
    "aggregate_review_return_checklist_rows=5",
    "generation_result_return_checklist_rows=5",
    "supplied_checklist_rows=0",
    "missing_checklist_rows=81",
    "accepted_by_v53ak_rows=0",
    "ready_closure_item_rows=3",
    "blocked_closure_item_rows=9",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53ak=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ak boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ak_complete_source_external_return_operator_checklist_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ak_complete_source_external_return_operator_checklist_ready") != 1:
    raise SystemExit("v53ak manifest readiness mismatch")
if manifest.get("checklist_rows") != 81:
    raise SystemExit("v53ak manifest checklist count mismatch")
if manifest.get("accepted_by_v53ak_rows") != 0:
    raise SystemExit("v53ak manifest must not accept evidence")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ak manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ak sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ak produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ak complete-source external return operator checklist smoke passed"
