#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_decision.csv"

V53X_REUSE_EXISTING="${V53X_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_CHUNK_RETURN_INTAKE.sh" >/dev/null

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
    "v53x_complete_source_review_chunk_return_intake_ready": "1",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "return_dir_supplied": "0",
    "return_dir_exists": "0",
    "review_chunk_rows": "21",
    "review_chunk_return_artifact_rows": "50",
    "supplied_chunk_return_artifact_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "missing_chunk_return_artifact_rows": "50",
    "invalid_chunk_return_artifact_rows": "0",
    "ready_review_chunk_return_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "supplied_aggregate_review_return_artifact_rows": "0",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "missing_aggregate_review_return_artifact_rows": "5",
    "invalid_aggregate_review_return_artifact_rows": "0",
    "chunk_return_intake_ready": "0",
    "aggregate_review_return_ready": "0",
    "v53s_refresh_ready": "0",
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53x {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_chunk_artifact_status_rows.csv",
    "review_return_chunk_status_rows.csv",
    "review_return_aggregate_artifact_status_rows.csv",
    "review_return_chunk_intake_command_rows.csv",
    "review_return_chunk_intake_requirement_rows.csv",
    "review_return_chunk_intake_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53X_COMPLETE_SOURCE_REVIEW_CHUNK_RETURN_INTAKE_BOUNDARY.md",
    "v53x_complete_source_review_chunk_return_intake_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_CHUNK_RETURN_INTAKE.sh",
    "source_v53w/review_return_chunk_execution_rows.csv",
    "source_v53w/review_return_chunk_artifact_rows.csv",
    "source_v53w/review_return_aggregate_artifact_rows.csv",
    "source_v53w/review_return_required_field_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53x artifact: {rel}")

chunk_artifact_status = read_csv(run_dir / "review_return_chunk_artifact_status_rows.csv")
chunk_status = read_csv(run_dir / "review_return_chunk_status_rows.csv")
aggregate_status = read_csv(run_dir / "review_return_aggregate_artifact_status_rows.csv")
commands = read_csv(run_dir / "review_return_chunk_intake_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_chunk_intake_requirement_rows.csv")}
metric = read_csv(run_dir / "review_return_chunk_intake_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(chunk_artifact_status) != 50:
    raise SystemExit("v53x expected 50 chunk artifact status rows")
if len(chunk_status) != 21:
    raise SystemExit("v53x expected 21 chunk status rows")
if len(aggregate_status) != 5:
    raise SystemExit("v53x expected five aggregate status rows")
if any(row["current_status"] != "missing" for row in chunk_artifact_status):
    raise SystemExit("v53x default chunk artifact status should be missing")
if any(row["chunk_return_ready"] != "0" for row in chunk_status):
    raise SystemExit("v53x default chunk returns should not be ready")
if any(row["current_status"] != "missing" for row in aggregate_status):
    raise SystemExit("v53x default aggregate artifact status should be missing")
if [row["ready_to_run_now"] for row in commands] != ["1", "0", "0"]:
    raise SystemExit("v53x command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53x_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53x metric {field}: expected {value}, got {metric[field]}")

if requirements["v53w-chunk-queue-input"]["status"] != "pass":
    raise SystemExit("v53x v53w input requirement should pass")
for requirement_id in [
    "return-directory-supplied",
    "chunk-return-artifact-intake",
    "aggregate-review-return-artifact-intake",
    "v53s-refresh-ready",
    "v53-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53x requirement should stay blocked: {requirement_id}")

if decisions["v53w-chunk-queue-input"] != "pass":
    raise SystemExit("v53x input gate should pass")
for gate in [
    "return-directory-supplied",
    "chunk-return-artifacts",
    "aggregate-review-return-artifacts",
    "v53s-refresh-ready",
    "review-return-ready",
    "v53-ready",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53x gate should stay blocked: {gate}")

for gap in [
    "return-directory",
    "chunk-return-artifacts",
    "aggregate-review-return-artifacts",
    "v53s-refresh",
    "review-return-ready",
    "v53-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53x gap should stay blocked: {gap}")

boundary = (run_dir / "V53X_COMPLETE_SOURCE_REVIEW_CHUNK_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_dir_supplied=0",
    "review_chunk_rows=21",
    "review_chunk_return_artifact_rows=50",
    "missing_chunk_return_artifact_rows=50",
    "aggregate_review_return_artifact_rows=5",
    "chunk_return_intake_ready=0",
    "v53s_refresh_ready=0",
    "review_return_ready=0",
    "v53_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53x boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53x_complete_source_review_chunk_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53x_complete_source_review_chunk_return_intake_ready") != 1:
    raise SystemExit("v53x manifest readiness mismatch")
if manifest.get("review_chunk_rows") != 21:
    raise SystemExit("v53x manifest chunk count mismatch")
if manifest.get("accepted_chunk_return_artifact_rows") != 0:
    raise SystemExit("v53x manifest accepted chunk artifacts should be zero")
if manifest.get("review_return_ready") != 0 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53x manifest should keep readiness blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53x sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53x produced checkpoint/model payload-like files" >&2
  exit 1
fi

echo "v53x complete-source review chunk return intake smoke passed"
