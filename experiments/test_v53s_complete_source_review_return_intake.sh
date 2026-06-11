#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53s_complete_source_review_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53s_complete_source_review_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53s_complete_source_review_return_intake_decision.csv"

V53S_REUSE_EXISTING="${V53S_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

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
    "v53s_complete_source_review_return_intake_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "review_return_input_supplied": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "invalid_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "invalid_adjudication_rows": "0",
    "expected_reviewer_assignment_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "accepted_conflict_disclosure_rows": "0",
    "return_artifact_rows": "5",
    "return_validation_rows": "1",
    "human_review_completed": "0",
    "adjudication_completed": "0",
    "reviewer_identity_ready": "0",
    "conflict_disclosure_ready": "0",
    "acceptance_summary_ready": "0",
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53s {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_required_field_rows.csv",
    "review_return_row_template.csv",
    "review_return_validation_rows.csv",
    "review_return_artifact_gate_rows.csv",
    "review_return_metric_rows.csv",
    "V53S_COMPLETE_SOURCE_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    "v53s_complete_source_review_return_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v53r/reviewer_assignment_template_rows.csv",
    "source_v53r/review_return_template_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53s artifact: {rel}")

required_fields = read_csv(run_dir / "review_return_required_field_rows.csv")
templates = read_csv(run_dir / "review_return_row_template.csv")
validation_rows = read_csv(run_dir / "review_return_validation_rows.csv")
artifact_gates = read_csv(run_dir / "review_return_artifact_gate_rows.csv")
metric = read_csv(run_dir / "review_return_metric_rows.csv")[0]
if len(required_fields) != 25:
    raise SystemExit("v53s required field row count mismatch")
if len(templates) != 5 or len(artifact_gates) != 5:
    raise SystemExit("v53s template/artifact row count mismatch")
if len(validation_rows) != 1 or validation_rows[0]["status"] != "blocked":
    raise SystemExit("v53s default validation should record one blocked no-return row")
if any(row["supplied"] != "0" or row["accepted"] != "0" for row in artifact_gates):
    raise SystemExit("v53s default path must not accept return artifacts")
if artifact_gates[0]["return_artifact"] != "human_review_rows.csv":
    raise SystemExit("v53s artifact ordering mismatch")
for field, value in expected.items():
    if field.startswith("v53s_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53s metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v53r-review-packet-input", "review-return-schema", "default-no-env-deferral"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53s gate should pass: {gate}")
for gate in [
    "human-review-artifacts",
    "adjudication-artifacts",
    "reviewer-identity",
    "conflict-disclosure",
    "review-return-ready",
    "quality-comparison-claim",
    "v53-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53s gate should stay blocked: {gate}")

boundary = (run_dir / "V53S_COMPLETE_SOURCE_REVIEW_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "expected_adjudication_rows=1000",
    "accepted_adjudication_rows=0",
    "review_return_input_supplied=0",
    "human_review_completed=0",
    "adjudication_completed=0",
    "review_return_ready=0",
    "quality_comparison_claim_ready=0",
    "v53_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53s boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53s_complete_source_review_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53s_complete_source_review_return_intake_ready") != 1:
    raise SystemExit("v53s manifest readiness mismatch")
if manifest.get("review_return_ready") != 0 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53s manifest boundary mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53s sha256 mismatch: {rel}")
PY

echo "v53s complete-source review return intake smoke passed"
