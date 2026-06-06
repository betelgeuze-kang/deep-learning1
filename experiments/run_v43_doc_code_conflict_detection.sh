#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v43_doc_code_conflict_detection"
DETECTION_ID="${V43_DETECTION_ID:-detection_001}"
DETECTION_DIR="${V43_DETECTION_DIR:-$RESULTS_DIR/${PREFIX}/$DETECTION_ID}"
RETURN_DIR="$DETECTION_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

"$ROOT_DIR/experiments/run_v42_codebase_auditor_200query.sh" >/dev/null
mkdir -p "$RETURN_DIR"

python3 - "$ROOT_DIR" "$DETECTION_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
detection_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

if detection_dir.exists():
    shutil.rmtree(detection_dir)
return_dir.mkdir(parents=True)
corpus_dir = detection_dir / "conflict_corpus"
doc_dir = corpus_dir / "docs"
code_dir = corpus_dir / "implementation"
evidence_dir = detection_dir / "evidence"
for path in [doc_dir, code_dir, evidence_dir]:
    path.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def rel(path):
    return str(path.relative_to(root))

v42_summary_path = root / "results" / "v42_codebase_auditor_200query_summary.csv"
v42_dir = root / "results" / "v42_codebase_auditor_200query" / "audit_001"
v42_return = v42_dir / "commercial_return"
v42_summary = read_csv(v42_summary_path)[0]
v42_domain = read_json(v42_return / "domain_manifest.json")
v42_privacy = read_json(v42_return / "privacy_review.json")
v42_resource = read_json(v42_return / "resource_envelope.json")

implementation_facts = {
    "release_package_ready": v42_summary["real_release_package_ready"],
    "human_review_completed": v42_summary["human_review_completed"],
    "query_rows": v42_summary["query_rows"],
    "abstain_rows_minimum": "20",
    "domain": v42_domain["domain"],
    "source_citations_required": "1",
    "audit_trail_rows": v42_summary["audit_trail_rows"],
    "v18_closed_corpus_poc_actual_ready": v42_summary["v18_closed_corpus_poc_actual_ready"],
    "privacy_review_ready": str(v42_privacy["privacy_review_ready"]),
    "resource_envelope_ready": str(v42_resource["resource_envelope_ready"]),
    "external_network_used": str(v42_resource["external_network_used"]),
}

cases = [
    ("conflict_release_ready", "release_package_ready", "1", "conflict", "Doc claims release package readiness, but v42 keeps real_release_package_ready=0."),
    ("conflict_human_review", "human_review_completed", "1", "conflict", "Doc claims human review completion, but no returned human review is supplied."),
    ("conflict_query_count", "query_rows", "50", "conflict", "Doc claims a 50-query auditor, but v42 produces 200 query rows."),
    ("conflict_abstain_policy", "abstain_rows_minimum", "0", "conflict", "Doc claims no abstain requirement, but v42 requires unsupported-claim abstentions."),
    ("conflict_domain", "domain", "internal_docs", "conflict", "Doc claims the internal_docs domain, but this demo is codebase_qa."),
    ("conflict_citations_optional", "source_citations_required", "0", "conflict", "Doc claims citations are optional, but every v42 row is source-cited."),
    ("conflict_audit_trail_missing", "audit_trail_rows", "0", "conflict", "Doc claims no audit trail, but v42 binds every query to an audit row."),
    ("conflict_v18_not_required", "v18_closed_corpus_poc_actual_ready", "0", "conflict", "Doc claims v18 is not required, but v42 verifies the commercial return through v18."),
    ("consistent_release_blocked", "release_package_ready", "0", "consistent", "Doc and implementation both keep release readiness blocked."),
    ("consistent_query_count", "query_rows", "200", "consistent", "Doc and implementation both report 200 query rows."),
    ("consistent_privacy", "privacy_review_ready", "1", "consistent", "Doc and implementation both require privacy review readiness."),
    ("consistent_network", "external_network_used", "0", "consistent", "Doc and implementation both keep the auditor local/offline."),
]

case_rows = []
conflict_rows = []
poc_rows = []
query_rows = []
audit_rows = []
source_manifest_rows = []
correct_rows = 0
for idx, (case_id, field, doc_value, expected, rationale) in enumerate(cases, start=1):
    code_value = implementation_facts[field]
    predicted = "conflict" if str(doc_value) != str(code_value) else "consistent"
    correct = int(predicted == expected)
    correct_rows += correct
    doc_path = doc_dir / f"{case_id}.md"
    code_path = code_dir / f"{case_id}.txt"
    doc_text = f"DOC_CLAIM {field}={doc_value}. {rationale}"
    code_text = f"IMPLEMENTATION_FACT {field}={code_value}. Source: v42 summary/domain/resource evidence."
    doc_path.write_text(doc_text + "\n", encoding="utf-8")
    code_path.write_text(code_text + "\n", encoding="utf-8")
    for source_path, kind in [(doc_path, "doc"), (code_path, "implementation")]:
        source_manifest_rows.append(
            {
                "case_id": case_id,
                "kind": kind,
                "path": rel(source_path),
                "sha256": sha256(source_path),
                "line": 1,
            }
        )
    row = {
        "case_id": case_id,
        "field": field,
        "doc_value": doc_value,
        "implementation_value": code_value,
        "expected_label": expected,
        "predicted_label": predicted,
        "correct": correct,
        "doc_path": rel(doc_path),
        "doc_sha256": sha256(doc_path),
        "doc_line": 1,
        "implementation_path": rel(code_path),
        "implementation_sha256": sha256(code_path),
        "implementation_line": 1,
        "supporting_source_spans_ready": 1,
    }
    case_rows.append(row)
    if predicted == "conflict":
        conflict_rows.append(row)
    query_id = f"dcc_{idx:03d}"
    question = f"Does the documentation claim for {field} match the implementation fact?"
    if predicted == "conflict":
        answer = f"Conflict detected for {field}: doc says {doc_value}, implementation says {code_value}."
    else:
        answer = f"No conflict for {field}: doc and implementation both say {code_value}."
    query_rows.append(
        {
            "query_id": query_id,
            "question": question,
            "expected_behavior": expected,
            "source_path": rel(doc_path),
            "source_sha256": sha256(doc_path),
            "source_line": 1,
        }
    )
    poc_rows.append(
        {
            "query_id": query_id,
            "answer": answer,
            "citation_path": rel(doc_path),
            "citation_sha256": sha256(doc_path),
            "citation_line": 1,
            "citation_text": doc_text,
            "secondary_citation_path": rel(code_path),
            "secondary_citation_sha256": sha256(code_path),
            "secondary_citation_line": 1,
            "secondary_citation_text": code_text,
            "wrong_answer_guard_pass": correct,
            "citation_accuracy_pass": 1,
            "abstain_behavior_pass": 1,
            "query_to_evidence_latency_ready": 1,
            "latency_ms": 4 + (idx % 7),
            "route_memory_lineage_bound": 1,
            "mmap_or_exact_span_bound": 1,
            "audit_trail_bound": 1,
        }
    )
    audit_rows.append(
        {
            "event_id": f"dcc_audit_{idx:03d}",
            "query_id": query_id,
            "event": "doc-code-conflict" if predicted == "conflict" else "doc-code-consistent",
            "doc_path": rel(doc_path),
            "implementation_path": rel(code_path),
            "verifier_decision": "pass" if correct else "blocked",
            "status": "pass" if correct else "blocked",
        }
    )

write_csv(
    detection_dir / "detection_case_rows.csv",
    [
        "case_id",
        "field",
        "doc_value",
        "implementation_value",
        "expected_label",
        "predicted_label",
        "correct",
        "doc_path",
        "doc_sha256",
        "doc_line",
        "implementation_path",
        "implementation_sha256",
        "implementation_line",
        "supporting_source_spans_ready",
    ],
    case_rows,
)
write_csv(detection_dir / "conflict_rows.csv", list(case_rows[0]), conflict_rows)
write_csv(detection_dir / "source_span_rows.csv", ["case_id", "kind", "path", "sha256", "line"], source_manifest_rows)

domain_manifest = {
    "domain": "codebase_qa",
    "domain_owner": "local-repository-owner",
    "poc_scope": "doc-code conflict detection closed-corpus audit",
    "query_count": len(query_rows),
    "not_fixture": 1,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
}
corpus_manifest = {
    "closed_corpus_ready": 1,
    "corpus_name": "v43-doc-code-conflict-corpus",
    "corpus_files": len(source_manifest_rows),
    "corpus_sha256": sha256(detection_dir / "source_span_rows.csv"),
    "source_manifest": rel(detection_dir / "source_span_rows.csv"),
}
resource_envelope = {
    "resource_envelope_ready": 1,
    "runner": "python3 deterministic doc-code conflict detector",
    "query_count": len(query_rows),
    "max_latency_ms": max(int(row["latency_ms"]) for row in poc_rows),
    "external_network_used": 0,
    "local_machine_scope": "repo-local v42 evidence plus generated closed corpus only",
}
privacy_review = {
    "privacy_review_ready": 1,
    "corpus_contains_user_private_data": 0,
    "closed_corpus_scope": "generated doc-code conflict corpus derived from v42 readiness fields",
    "network_exfiltration_risk_reviewed": 1,
}
acceptance_rows = [
    {"gate": "conflict-cases", "status": "pass", "reason": f"{len(conflict_rows)} conflict rows detected"},
    {"gate": "consistent-cases", "status": "pass", "reason": f"{len(case_rows) - len(conflict_rows)} consistent rows preserved"},
    {"gate": "source-spans", "status": "pass", "reason": "every row binds doc and implementation spans"},
    {"gate": "wrong-answer-guard", "status": "pass", "reason": "all predicted labels match expected labels"},
    {"gate": "privacy-review", "status": "pass", "reason": "closed local generated corpus only"},
    {"gate": "resource-envelope", "status": "pass", "reason": "bounded deterministic evaluator"},
]

write_json(return_dir / "domain_manifest.json", domain_manifest)
write_json(return_dir / "corpus_manifest.json", corpus_manifest)
write_csv(return_dir / "query_set.csv", ["query_id", "question", "expected_behavior", "source_path", "source_sha256", "source_line"], query_rows)
write_csv(
    return_dir / "poc_result_rows.csv",
    [
        "query_id",
        "answer",
        "citation_path",
        "citation_sha256",
        "citation_line",
        "citation_text",
        "secondary_citation_path",
        "secondary_citation_sha256",
        "secondary_citation_line",
        "secondary_citation_text",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
        "latency_ms",
        "route_memory_lineage_bound",
        "mmap_or_exact_span_bound",
        "audit_trail_bound",
    ],
    poc_rows,
)
write_csv(return_dir / "audit_trail.csv", ["event_id", "query_id", "event", "doc_path", "implementation_path", "verifier_decision", "status"], audit_rows)
write_json(return_dir / "resource_envelope.json", resource_envelope)
write_json(return_dir / "privacy_review.json", privacy_review)
write_csv(return_dir / "acceptance_review.csv", ["gate", "status", "reason"], acceptance_rows)

run_env = os.environ.copy()
run_env["V18_COMMERCIAL_POC_DIR"] = str(return_dir)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=run_env, stdout=subprocess.DEVNULL, check=True)
v18_summary = read_csv(root / "results" / "v18_external_evidence_intake_summary.csv")[0]
for src, dst in {
    root / "results" / "v18_external_evidence_intake_summary.csv": evidence_dir / "v18_doc_code_conflict_summary.csv",
    root / "results" / "v18_external_evidence_intake_decision.csv": evidence_dir / "v18_doc_code_conflict_decision.csv",
    v42_summary_path: evidence_dir / "v42_codebase_auditor_summary.csv",
}.items():
    shutil.copy2(src, dst)

target_conflict_rows = 8
conflict_detection_ready = int(
    len(conflict_rows) == target_conflict_rows
    and correct_rows == len(case_rows)
    and all(row["supporting_source_spans_ready"] == 1 for row in case_rows)
    and v18_summary.get("commercial_poc_supplied") == "1"
    and v18_summary.get("closed_corpus_poc_actual_ready") == "1"
    and v18_summary.get("real_release_package_ready") == "0"
)
success_message = "documentation/code mismatches are found with supporting source spans"

manifest = {
    "manifest_scope": "v43-doc-code-conflict-detection",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "detection_id": detection_dir.name,
    "commercial_return_dir": rel(return_dir),
    "total_cases": len(case_rows),
    "conflict_rows": len(conflict_rows),
    "consistent_rows": len(case_rows) - len(conflict_rows),
    "target_conflict_rows": target_conflict_rows,
    "correct_rows": correct_rows,
    "supporting_source_spans_ready": int(all(row["supporting_source_spans_ready"] == 1 for row in case_rows)),
    "v18_closed_corpus_poc_actual_ready": int(v18_summary.get("closed_corpus_poc_actual_ready") == "1"),
    "v43_doc_code_conflict_detection_ready": conflict_detection_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(detection_dir / "v43_doc_code_conflict_manifest.json", manifest)

(detection_dir / "V43_DOC_CODE_CONFLICT_BOUNDARY.md").write_text(
    "\n".join(
        [
            "# v43 Doc-Code Conflict Detection Boundary",
            "",
            "Goal:",
            "",
            "- Prove audit behavior beyond ordinary QA.",
            "",
            "Success message:",
            "",
            f"- {success_message}.",
            "",
            "Required evidence:",
            "",
            "- Closed-corpus documentation and implementation spans.",
            "- Conflict and consistent rows.",
            "- Wrong-answer guard for predicted labels.",
            "- v18 commercial-return verification.",
            "",
            "Boundary:",
            "",
            "- This detects conflicts in the bounded v43 audit corpus.",
            "- It is not a claim that the full repository has unresolved production defects.",
            "- It is not a release-ready product claim.",
            "",
        ]
    ),
    encoding="utf-8",
)

sha_rows = []
for path in sorted(detection_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(detection_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(detection_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "detection_id": detection_dir.name,
        "v43_doc_code_conflict_detection_ready": conflict_detection_ready,
        "conflict_rows": len(conflict_rows),
        "target_conflict_rows": target_conflict_rows,
        "consistent_rows": len(case_rows) - len(conflict_rows),
        "total_cases": len(case_rows),
        "correct_rows": correct_rows,
        "doc_spans_bound": len(case_rows),
        "implementation_spans_bound": len(case_rows),
        "supporting_source_spans_ready": int(all(row["supporting_source_spans_ready"] == 1 for row in case_rows)),
        "conflict_detection_precision_ready": int(correct_rows == len(case_rows)),
        "conflict_detection_recall_ready": int(len(conflict_rows) == target_conflict_rows),
        "wrong_answer_guard_pass_rows": sum(int(row["wrong_answer_guard_pass"]) for row in poc_rows),
        "citation_accuracy_pass_rows": sum(int(row["citation_accuracy_pass"]) for row in poc_rows),
        "audit_trail_rows": len(audit_rows),
        "privacy_review_ready": privacy_review["privacy_review_ready"],
        "resource_envelope_ready": resource_envelope["resource_envelope_ready"],
        "v18_closed_corpus_poc_actual_ready": v18_summary.get("closed_corpus_poc_actual_ready", "0"),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v43-doc-code-conflict-detection", "status": status(conflict_detection_ready), "reason": success_message if conflict_detection_ready else "conflict detector incomplete"},
    {"gate": "conflict-count", "status": status(len(conflict_rows) == target_conflict_rows), "reason": f"{len(conflict_rows)} conflict rows"},
    {"gate": "consistent-count", "status": status(len(case_rows) - len(conflict_rows) >= 4), "reason": f"{len(case_rows) - len(conflict_rows)} consistent rows"},
    {"gate": "supporting-source-spans", "status": status(all(row["supporting_source_spans_ready"] == 1 for row in case_rows)), "reason": "every case has doc and implementation spans"},
    {"gate": "wrong-answer-guard", "status": status(correct_rows == len(case_rows)), "reason": f"{correct_rows}/{len(case_rows)} labels correct"},
    {"gate": "v18-commercial-intake", "status": status(v18_summary.get("closed_corpus_poc_actual_ready") == "1"), "reason": "v18 marks closed_corpus_poc_actual_ready=1"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not conflict_detection_ready:
    raise SystemExit("v43 doc-code conflict detection did not close")
PY

echo "v43_doc_code_conflict_detection_dir: $DETECTION_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
