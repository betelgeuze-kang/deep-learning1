#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
DETECTION_DIR="$RESULTS_DIR/v43_doc_code_conflict_detection/detection_001"
RETURN_DIR="$DETECTION_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v43_doc_code_conflict_detection_summary.csv"
DECISION_CSV="$RESULTS_DIR/v43_doc_code_conflict_detection_decision.csv"

"$ROOT_DIR/experiments/run_v43_doc_code_conflict_detection.sh" >/dev/null

python3 - "$ROOT_DIR" "$DETECTION_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
detection_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

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
    raise SystemExit(f"expected one v43 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v43_doc_code_conflict_detection_ready",
    "supporting_source_spans_ready",
    "conflict_detection_precision_ready",
    "conflict_detection_recall_ready",
    "privacy_review_ready",
    "resource_envelope_ready",
    "v18_closed_corpus_poc_actual_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v43 {field}: expected 1, got {summary.get(field)}")
expected_counts = {
    "conflict_rows": "8",
    "target_conflict_rows": "8",
    "consistent_rows": "4",
    "total_cases": "12",
    "correct_rows": "12",
    "doc_spans_bound": "12",
    "implementation_spans_bound": "12",
    "wrong_answer_guard_pass_rows": "12",
    "citation_accuracy_pass_rows": "12",
    "audit_trail_rows": "12",
}
for field, expected in expected_counts.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v43 {field}: expected {expected}, got {summary.get(field)}")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v43 should keep review/release blocked")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v43-doc-code-conflict-detection",
    "conflict-count",
    "consistent-count",
    "supporting-source-spans",
    "wrong-answer-guard",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v43 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v43 should leave release blocked")

required_files = [
    "V43_DOC_CODE_CONFLICT_BOUNDARY.md",
    "detection_case_rows.csv",
    "conflict_rows.csv",
    "source_span_rows.csv",
    "v43_doc_code_conflict_manifest.json",
    "sha256_manifest.csv",
    "evidence/v18_doc_code_conflict_summary.csv",
    "evidence/v18_doc_code_conflict_decision.csv",
    "evidence/v42_codebase_auditor_summary.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/resource_envelope.json",
    "commercial_return/privacy_review.json",
    "commercial_return/acceptance_review.csv",
]
for rel in required_files:
    path = detection_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v43 missing artifact: {rel}")

manifest = json.loads((detection_dir / "v43_doc_code_conflict_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v43_doc_code_conflict_detection_ready") != 1:
    raise SystemExit("v43 manifest should be ready")
if manifest.get("conflict_rows") != 8 or manifest.get("consistent_rows") != 4:
    raise SystemExit("v43 manifest should record 8 conflict and 4 consistent rows")
if manifest.get("supporting_source_spans_ready") != 1:
    raise SystemExit("v43 manifest should bind supporting spans")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v43 manifest should keep review/release blocked")

case_rows = read_csv(detection_dir / "detection_case_rows.csv")
conflict_rows = read_csv(detection_dir / "conflict_rows.csv")
span_rows = read_csv(detection_dir / "source_span_rows.csv")
if len(case_rows) != 12 or len(conflict_rows) != 8 or len(span_rows) != 24:
    raise SystemExit("v43 should write 12 cases, 8 conflicts, and 24 source spans")
if any(row["correct"] != "1" for row in case_rows):
    raise SystemExit("v43 detector labels should all be correct")
if any(row["supporting_source_spans_ready"] != "1" for row in case_rows):
    raise SystemExit("v43 cases should all bind supporting source spans")
for row in case_rows:
    doc_path = root / row["doc_path"]
    impl_path = root / row["implementation_path"]
    if row["doc_sha256"] != sha256(doc_path):
        raise SystemExit(f"v43 doc hash mismatch: {row['case_id']}")
    if row["implementation_sha256"] != sha256(impl_path):
        raise SystemExit(f"v43 implementation hash mismatch: {row['case_id']}")
    if row["predicted_label"] == "conflict" and row["doc_value"] == row["implementation_value"]:
        raise SystemExit(f"v43 false conflict value equality: {row['case_id']}")
    if row["predicted_label"] == "consistent" and row["doc_value"] != row["implementation_value"]:
        raise SystemExit(f"v43 false consistency value mismatch: {row['case_id']}")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
corpus = json.loads((return_dir / "corpus_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 12:
    raise SystemExit("v43 domain should be codebase_qa with 12 queries")
if corpus.get("closed_corpus_ready") != 1:
    raise SystemExit("v43 corpus should be closed-corpus ready")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v43 privacy/resource should be ready")
if resource.get("external_network_used") != 0:
    raise SystemExit("v43 should not use external network")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 12 or len(poc_rows) != 12 or len(audit_rows) != 12:
    raise SystemExit("v43 query/result/audit rows should all be 12")
if len([row for row in poc_rows if row["answer"].startswith("Conflict detected")]) != 8:
    raise SystemExit("v43 should report 8 detected conflicts")
if len([row for row in poc_rows if row["answer"].startswith("No conflict")]) != 4:
    raise SystemExit("v43 should preserve 4 consistent cases")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v43 result rows should pass {field}")
if any(not row["secondary_citation_path"] for row in poc_rows):
    raise SystemExit("v43 result rows should cite implementation spans")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v43 audit trail rows should pass")
if len(acceptance_rows) < 6 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v43 acceptance rows should pass")

with (detection_dir / "evidence" / "v18_doc_code_conflict_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v43 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v43 copied v18 summary should keep release blocked")

boundary = (detection_dir / "V43_DOC_CODE_CONFLICT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Prove audit behavior beyond ordinary QA",
    "documentation/code mismatches are found",
    "bounded v43 audit corpus",
    "not a release-ready product claim",
]:
    if snippet not in boundary:
        raise SystemExit(f"v43 boundary missing: {snippet}")

with (detection_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v43 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(detection_dir / rel):
        raise SystemExit(f"v43 sha mismatch for {rel}")
PY

echo "v43 Doc-Code Conflict Detection smoke passed"
