#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53u_complete_source_review_return_operator_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v53u_complete_source_review_return_operator_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53u_complete_source_review_return_operator_bundle_decision.csv"

V53U_REUSE_EXISTING="${V53U_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_REVIEW_RETURN_BUNDLE.sh" >/dev/null

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
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "review_packet_ready": "1",
    "review_return_ready": "0",
    "review_answer_packet_rows": "7000",
    "review_queue_rows": "7000",
    "reviewer_assignment_rows": "21",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "reviewer_workload_chunk_rows": "21",
    "ready_reviewer_workload_chunk_rows": "21",
    "chunk_expected_human_review_rows": "7000",
    "chunk_expected_adjudication_rows": "1000",
    "chunk_expected_reviewer_identity_rows": "21",
    "chunk_expected_conflict_disclosure_rows": "210",
    "return_artifact_template_rows": "5",
    "operator_bundle_file_rows": "8",
    "operator_command_rows": "4",
    "review_return_operator_bundle_handoff_ready": "1",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53u {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "reviewer_workload_chunk_rows.csv",
    "review_return_expected_artifact_rows.csv",
    "review_return_operator_bundle_file_rows.csv",
    "review_return_operator_command_rows.csv",
    "review_return_operator_requirement_rows.csv",
    "review_return_operator_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53U_COMPLETE_SOURCE_REVIEW_RETURN_OPERATOR_BUNDLE_BOUNDARY.md",
    "v53u_complete_source_review_return_operator_bundle_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/RETURN_INTAKE_COMMANDS.md",
    "operator_bundle/HUMAN_REVIEW_ROWS_TEMPLATE.csv",
    "operator_bundle/ADJUDICATION_ROWS_TEMPLATE.csv",
    "operator_bundle/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv",
    "operator_bundle/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv",
    "operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json",
    "operator_bundle/VERIFY_REVIEW_RETURN_BUNDLE.sh",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v53r/reviewer_assignment_template_rows.csv",
    "source_v53s/review_return_required_field_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53u artifact: {rel}")

chunks = read_csv(run_dir / "reviewer_workload_chunk_rows.csv")
artifacts = read_csv(run_dir / "review_return_expected_artifact_rows.csv")
files = read_csv(run_dir / "review_return_operator_bundle_file_rows.csv")
commands = read_csv(run_dir / "review_return_operator_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_operator_requirement_rows.csv")}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
metric = read_csv(run_dir / "review_return_operator_metric_rows.csv")[0]

if len(chunks) != 21 or len(artifacts) != 5 or len(files) != 8 or len(commands) != 4:
    raise SystemExit("v53u row count mismatch")
if any(row["chunk_ready"] != "1" for row in chunks):
    raise SystemExit("v53u all reviewer chunks should be ready")
if sum(int(row["expected_human_review_rows"]) for row in chunks) != 7000:
    raise SystemExit("v53u chunk human review total mismatch")
if sum(int(row["expected_adjudication_rows"]) for row in chunks) != 1000:
    raise SystemExit("v53u chunk adjudication total mismatch")
if sum(int(row["expected_reviewer_identity_rows"]) for row in chunks) != 21:
    raise SystemExit("v53u chunk identity total mismatch")
if sum(int(row["expected_conflict_disclosure_rows"]) for row in chunks) != 210:
    raise SystemExit("v53u chunk conflict total mismatch")
if any(row["artifact_ready"] != "0" for row in artifacts):
    raise SystemExit("v53u return artifacts should remain external/pending")
if any(row["fake_review_rows_included"] != "0" for row in files):
    raise SystemExit("v53u bundle must not include fake review rows")

for field, value in expected.items():
    if field.startswith("v53u_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53u metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53r-review-packet-input",
    "v53s-return-intake-schema",
    "reviewer-workload-chunking",
    "reviewer-identity-conflict-return",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53u requirement should pass: {requirement_id}")
if requirements["actual-human-review-return"]["status"] != "blocked":
    raise SystemExit("v53u actual human review return must stay blocked")

for gate in [
    "v53r-review-packet-input",
    "v53s-return-intake-schema",
    "operator-bundle-shape",
    "zero-fake-review-rows",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53u gate should pass: {gate}")
for gate in [
    "human-review-return",
    "adjudication-return",
    "reviewer-identity-return",
    "conflict-disclosure-return",
    "v53-ready",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53u gate should stay blocked: {gate}")

if gaps.get("review-return-operator-bundle") != "ready":
    raise SystemExit("v53u operator bundle gap should be ready")
for gap in ["human-review-return", "adjudication-return", "v53-ready", "v1.0-comparison-ready"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53u gap should stay blocked: {gap}")

boundary = (run_dir / "V53U_COMPLETE_SOURCE_REVIEW_RETURN_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_answer_packet_rows=7000",
    "review_queue_rows=7000",
    "reviewer_workload_chunk_rows=21",
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "expected_adjudication_rows=1000",
    "accepted_adjudication_rows=0",
    "operator_bundle_file_rows=8",
    "operator_command_rows=4",
    "review_return_operator_bundle_handoff_ready=1",
    "review_return_ready=0",
    "v53_ready=0",
    "v1_0_comparison_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53u boundary missing snippet: {snippet}")

acceptance_template = json.loads((run_dir / "operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json").read_text(encoding="utf-8"))
if acceptance_template.get("expected_human_review_rows") != 7000:
    raise SystemExit("v53u acceptance template expected human rows mismatch")
if acceptance_template.get("expected_adjudication_rows") != 1000:
    raise SystemExit("v53u acceptance template expected adjudication rows mismatch")

manifest = json.loads((run_dir / "v53u_complete_source_review_return_operator_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53u_complete_source_review_return_operator_bundle_ready") != 1:
    raise SystemExit("v53u manifest readiness mismatch")
if manifest.get("review_return_ready") != 0 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53u manifest should keep v53 blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53u sha256 mismatch: {rel}")
PY

echo "v53u complete-source review return operator bundle smoke passed"
