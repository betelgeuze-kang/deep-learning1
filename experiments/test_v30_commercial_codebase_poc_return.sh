#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v30_commercial_codebase_poc_return/return_001"
RETURN_DIR="$RUN_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v30_commercial_codebase_poc_return_summary.csv"
DECISION_CSV="$RESULTS_DIR/v30_commercial_codebase_poc_return_decision.csv"

"$ROOT_DIR/experiments/run_v30_commercial_codebase_poc_return.sh" >/dev/null
V29_COMMERCIAL_RETURN_DIR="$RETURN_DIR" "$ROOT_DIR/experiments/run_v29_receiver_return_preflight.sh" >/dev/null
V18_COMMERCIAL_POC_DIR="$RETURN_DIR" "$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
return_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results_dir = Path(sys.argv[5])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v30 summary row, got {len(rows)}")
summary = rows[0]
expected = {
    "codebase_poc_return_ready": "1",
    "query_rows": "4",
    "poc_result_rows": "4",
    "audit_rows": "4",
    "acceptance_rows": "6",
    "privacy_review_ready": "1",
    "resource_envelope_ready": "1",
    "wrong_answer_guard_pass_rows": "4",
    "citation_accuracy_pass_rows": "4",
    "abstain_behavior_pass_rows": "4",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v30 {field}: expected {value}, got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["commercial-codebase-poc-return", "privacy-review", "wrong-answer-guard"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v30 gate should pass: {gate}")

required = [
    "domain_manifest.json",
    "corpus_manifest.json",
    "query_set.csv",
    "poc_result_rows.csv",
    "audit_trail.csv",
    "resource_envelope.json",
    "privacy_review.json",
    "acceptance_review.csv",
]
for rel in required:
    path = return_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v30 commercial artifact: {rel}")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
corpus = json.loads((return_dir / "corpus_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("not_fixture") != 1:
    raise SystemExit("v30 domain manifest should be non-fixture codebase_qa")
if corpus.get("closed_corpus_ready") != 1:
    raise SystemExit("v30 corpus should be closed-corpus ready")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v30 privacy/resource review should be ready")

with (return_dir / "poc_result_rows.csv").open(newline="", encoding="utf-8") as handle:
    poc_rows = list(csv.DictReader(handle))
if len(poc_rows) != 4:
    raise SystemExit("v30 should emit four PoC result rows")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v30 result rows should pass {field}")
if not any("general LLM replacement" in row["answer"] or "general language model replacement" in row["citation_text"] for row in poc_rows):
    raise SystemExit("v30 should include the negative/abstain general LLM claim row")

with (return_dir / "acceptance_review.csv").open(newline="", encoding="utf-8") as handle:
    acceptance = list(csv.DictReader(handle))
if len(acceptance) != 6 or any(row["status"] != "pass" for row in acceptance):
    raise SystemExit("v30 acceptance review should have six pass rows")

manifest = json.loads((run_dir / "commercial_codebase_poc_manifest.json").read_text(encoding="utf-8"))
if manifest.get("codebase_poc_return_ready") != 1:
    raise SystemExit("v30 manifest should be ready")

with (run_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifacts = list(csv.DictReader(handle))
by_path = {Path(row["path"]).name: row for row in artifacts}
for rel in required:
    if rel not in by_path:
        raise SystemExit(f"v30 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(return_dir / rel):
        raise SystemExit(f"v30 artifact hash mismatch: {rel}")

with (results_dir / "v29_receiver_return_preflight_summary.csv").open(newline="", encoding="utf-8") as handle:
    v29 = list(csv.DictReader(handle))[0]
if v29.get("return_dirs_detected") != "1" or v29.get("complete_return_dirs") != "1":
    raise SystemExit("v29 should detect the v30 commercial return as complete")

with (results_dir / "v18_external_evidence_intake_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1":
    raise SystemExit("v18 should receive the v30 commercial PoC")
if v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v18 should mark the v30 commercial PoC actual-ready")
if v18.get("independent_rerun_actual_ready") != "0" or v18.get("candidate_external_benchmark_result_ready") != "0":
    raise SystemExit("v30 should not overclaim third-party or official benchmark readiness")
PY

echo "v30 commercial codebase PoC return smoke passed"
