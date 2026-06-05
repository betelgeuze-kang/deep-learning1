#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
AUDIT_DIR="$RESULTS_DIR/v42_codebase_auditor_200query/audit_001"
RETURN_DIR="$AUDIT_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v42_codebase_auditor_200query_summary.csv"
DECISION_CSV="$RESULTS_DIR/v42_codebase_auditor_200query_decision.csv"

"$ROOT_DIR/experiments/run_v42_codebase_auditor_200query.sh" >/dev/null

python3 - "$AUDIT_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

audit_dir = Path(sys.argv[1])
return_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])

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
    raise SystemExit(f"expected one v42 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v42_codebase_auditor_200query_ready",
    "privacy_review_ready",
    "resource_envelope_ready",
    "v18_closed_corpus_poc_actual_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v42 {field}: expected 1, got {summary.get(field)}")
for field in ["query_rows", "poc_result_rows", "audit_trail_rows", "wrong_answer_guard_pass_rows", "citation_accuracy_pass_rows", "abstain_behavior_pass_rows", "audit_trail_bound_rows"]:
    if summary.get(field) != "200":
        raise SystemExit(f"v42 {field}: expected 200, got {summary.get(field)}")
if int(summary.get("abstain_rows", "0")) < 20:
    raise SystemExit("v42 should include at least 20 abstain rows")
if int(summary.get("source_files", "0")) < 40:
    raise SystemExit("v42 should bind at least 40 source files")
if int(summary.get("acceptance_rows", "0")) < 8:
    raise SystemExit("v42 should include acceptance review rows")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v42 should keep review/release blocked")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v42-codebase-auditor-200query",
    "query-count",
    "citations",
    "abstain",
    "audit-trail",
    "privacy-resource-acceptance",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v42 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v42 should leave release blocked")

required_files = [
    "V42_CODEBASE_AUDITOR_BOUNDARY.md",
    "auditor_rows.csv",
    "v42_codebase_auditor_manifest.json",
    "sha256_manifest.csv",
    "source_manifests/codebase_auditor_source_rows.csv",
    "evidence/v18_commercial_auditor_summary.csv",
    "evidence/v18_commercial_auditor_decision.csv",
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
    path = audit_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v42 missing artifact: {rel}")

manifest = json.loads((audit_dir / "v42_codebase_auditor_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v42_codebase_auditor_200query_ready") != 1:
    raise SystemExit("v42 manifest should be ready")
if manifest.get("query_rows") != 200 or manifest.get("poc_result_rows") != 200:
    raise SystemExit("v42 manifest should record 200 query/result rows")
if manifest.get("audit_trail_rows") < 200:
    raise SystemExit("v42 manifest should record an audit trail for every query")
if manifest.get("v18_closed_corpus_poc_actual_ready") != 1:
    raise SystemExit("v42 manifest should record v18 commercial readiness")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v42 manifest should keep review/release blocked")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
corpus = json.loads((return_dir / "corpus_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 200:
    raise SystemExit("v42 domain should be codebase_qa with 200 queries")
if corpus.get("closed_corpus_ready") != 1:
    raise SystemExit("v42 corpus should be closed-corpus ready")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v42 privacy/resource should be ready")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 200 or len(poc_rows) != 200 or len(audit_rows) != 200:
    raise SystemExit("v42 query/result/audit rows should all be 200")
if len({row["query_id"] for row in query_rows}) != 200:
    raise SystemExit("v42 query IDs should be unique")
if len([row for row in query_rows if row["expected_behavior"] == "abstain"]) < 20:
    raise SystemExit("v42 query set should include abstain rows")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v42 result rows should pass {field}")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v42 audit trail rows should pass")
if len(acceptance_rows) < 8 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v42 acceptance rows should pass")
if not any("Abstain:" in row["answer"] for row in poc_rows):
    raise SystemExit("v42 should include explicit abstain answers")

auditor_rows = read_csv(audit_dir / "auditor_rows.csv")
if len(auditor_rows) != 1:
    raise SystemExit("v42 should write one auditor row")
if auditor_rows[0].get("success_message") != "local-repository codebase QA works with citations, abstentions, and audit trail":
    raise SystemExit("v42 success message mismatch")

with (audit_dir / "evidence" / "v18_commercial_auditor_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v42 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v42 copied v18 summary should keep release blocked")

boundary = (audit_dir / "V42_CODEBASE_AUDITOR_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "First buyer-visible industrial demo",
    "200 local repository QA/audit result rows",
    "Source citations",
    "Abstain rows",
    "Audit trail rows",
    "Not production-ready product",
]:
    if snippet not in boundary:
        raise SystemExit(f"v42 boundary missing: {snippet}")

with (audit_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v42 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(audit_dir / rel):
        raise SystemExit(f"v42 sha mismatch for {rel}")
PY

echo "v42 Codebase Auditor 200-query smoke passed"
