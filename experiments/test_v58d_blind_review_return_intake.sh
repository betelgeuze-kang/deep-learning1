#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v58d_blind_review_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v58d_blind_review_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v58d_blind_review_return_intake_decision.csv"

V58D_REUSE_EXISTING="${V58D_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v58d_blind_review_return_intake.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v58d summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v58d_blind_review_return_intake_ready": "1",
    "v58_ready": "0",
    "v58c_artifact_available": "0",
    "v58d_dependency_blocker_ready": "1",
    "v58c_blind_response_evidence_intake_ready": "0",
    "v58c_required_blind_response_ready": "0",
    "v58c_blind_response_absorb_ready": "0",
    "expected_blind_response_rows": "0",
    "required_blind_response_rows": "0",
    "optional_blind_response_rows": "0",
    "expected_required_review_rows": "0",
    "expected_required_adjudication_rows": "0",
    "review_dir_supplied": "0",
    "supplied_review_rows": "0",
    "supplied_adjudication_rows": "0",
    "validation_error_rows": "1",
    "required_blind_review_ready": "0",
    "required_adjudication_ready": "0",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "blind_eval_score_rows": "0",
    "routehint_advantage_rows_ready": "0",
    "failure_case_report_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v58d {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["review-return-intake-contract"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v58d gate should pass: {gate}")
for gate in [
    "v58c-response-intake-input",
    "required-blind-response-ready",
    "human-blind-review-return",
    "adjudication-return",
    "inter-rater-rows",
    "routehint-advantage-rows",
    "failure-case-report",
    "v58-full-blind-eval",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v58d gate should remain blocked: {gate}")

required_files = [
    "blind_review_required_field_rows.csv",
    "blind_review_return_template_rows.csv",
    "blind_adjudication_return_template_rows.csv",
    "blind_review_validation_rows.csv",
    "blind_review_intake_gate_rows.csv",
    "blind_eval_score_rows.csv",
    "blind_failure_case_report_rows.csv",
    "v58d_blind_review_dependency_rows.csv",
    "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    "v58d_blind_review_return_intake_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v58d artifact: {rel}")

schema_rows = read_csv(run_dir / "blind_review_required_field_rows.csv")
for field in ["blind_response_id", "reviewer_blinded", "review_decision", "adjudicated_decision", "inter_rater_agree"]:
    if not any(row["field"] == field for row in schema_rows):
        raise SystemExit(f"v58d schema missing {field}")

review_templates = read_csv(run_dir / "blind_review_return_template_rows.csv")
if len(review_templates) != 0:
    raise SystemExit("v58d default path should not fabricate review templates without v58c")
review_header = (run_dir / "blind_review_return_template_rows.csv").read_text(encoding="utf-8").splitlines()[0].split(",")
for forbidden in ["source_system_id", "source_system_name", "model_or_architecture_id"]:
    if forbidden in review_header:
        raise SystemExit(f"v58d review template schema should not reveal {forbidden}")

adjudication_templates = read_csv(run_dir / "blind_adjudication_return_template_rows.csv")
if len(adjudication_templates) != 0:
    raise SystemExit("v58d default path should not fabricate adjudication templates without v58c")
adjudication_header = (run_dir / "blind_adjudication_return_template_rows.csv").read_text(encoding="utf-8").splitlines()[0].split(",")
for forbidden in ["source_system_id", "source_system_name", "model_or_architecture_id"]:
    if forbidden in adjudication_header:
        raise SystemExit(f"v58d adjudication template schema should not reveal {forbidden}")

validation = read_csv(run_dir / "blind_review_validation_rows.csv")
if {"check": "review-dir", "status": "blocked", "reason": "V58D_BLIND_REVIEW_RETURN_DIR not supplied"} not in validation:
    raise SystemExit("v58d no-env validation should block on missing review dir")
if not any(row["reason"] == "blind-response-absorb-not-ready:1" for row in validation):
    raise SystemExit("v58d should record that response intake is not ready")

dependency_rows = read_csv(run_dir / "v58d_blind_review_dependency_rows.csv")
if not any(row["dependency"] == "v58c-response-intake" and row["status"] == "blocked" for row in dependency_rows):
    raise SystemExit("v58d should record blocked v58c dependency by default")

score_rows = read_csv(run_dir / "blind_eval_score_rows.csv")
if score_rows:
    raise SystemExit("v58d default path should not fabricate blind score rows")
failure_rows = read_csv(run_dir / "blind_failure_case_report_rows.csv")
if failure_rows:
    raise SystemExit("v58d default path should not fabricate failure report rows")

manifest = json.loads((run_dir / "v58d_blind_review_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v58d_blind_review_return_intake_ready") != 1 or manifest.get("v58_ready") != 0:
    raise SystemExit("v58d manifest readiness mismatch")
if manifest.get("v58c_artifact_available") != 0 or manifest.get("v58d_dependency_blocker_ready") != 1:
    raise SystemExit("v58d manifest should record explicit v58c dependency blocking")
if manifest.get("expected_required_review_rows") != 0 or manifest.get("expected_required_adjudication_rows") != 0:
    raise SystemExit("v58d manifest should not invent required row counts without v58c")
if manifest.get("human_blind_review_ready") != 0 or manifest.get("routehint_advantage_rows_ready") != 0:
    raise SystemExit("v58d manifest should keep human review and advantage rows blocked by default")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v58d sha256 mismatch: {rel}")

boundary = (run_dir / "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "human blind-review and adjudication return surface",
    "v58c_artifact_available=0",
    "expected_required_review_rows=0",
    "expected_required_adjudication_rows=0",
    "Reviewer return rows must not contain source system identity fields",
    "Do not publish blind-eval wins",
]:
    if snippet not in boundary:
        raise SystemExit(f"v58d boundary missing {snippet}")
PY

echo "v58d blind review return intake smoke passed"
