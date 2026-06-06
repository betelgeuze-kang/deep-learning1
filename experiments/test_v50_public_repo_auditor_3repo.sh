#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
AUDIT_DIR="$RESULTS_DIR/v50_public_repo_auditor_3repo/audit_001"
SUMMARY_CSV="$RESULTS_DIR/v50_public_repo_auditor_3repo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v50_public_repo_auditor_3repo_decision.csv"

"$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null

python3 - "$ROOT_DIR" "$AUDIT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
audit_dir = Path(sys.argv[2])
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
    raise SystemExit(f"expected one v50 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v50_public_repo_auditor_3repo_ready": "1",
    "repo_count": "3",
    "audit_case_rows": "9",
    "audit_type_count": "3",
    "doc_code_conflict_rows": "3",
    "deprecated_usage_rows": "3",
    "config_mismatch_rows": "3",
    "detected_doc_code_conflict_rows": "3",
    "detected_config_mismatch_rows": "1",
    "source_span_rows": "18",
    "wrong_answer_guard_pass_rows": "9",
    "citation_accuracy_pass_rows": "9",
    "audit_trail_bound_rows": "9",
    "public_repo_snapshot_ready": "1",
    "v18_closed_corpus_poc_actual_ready": "1",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v50 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("source_snapshot_rows", "0")) < 9:
    raise SystemExit("v50 should snapshot multiple public repo source files")
if int(summary.get("artifact_rows", "0")) < 30:
    raise SystemExit("v50 should hash public repo auditor artifacts")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v50-public-repo-auditor-3repo",
    "public-repo-count",
    "source-snapshot",
    "doc-code-conflict",
    "deprecated-usage",
    "config-mismatch",
    "source-citation-audit-trail",
    "v18-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v50 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v50 release gate should stay blocked")

required_files = [
    "V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md",
    "public_repo_source_snapshot_rows.csv",
    "public_repo_audit_case_rows.csv",
    "public_repo_source_span_rows.csv",
    "v50_public_repo_auditor_manifest.json",
    "sha256_manifest.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/privacy_review.json",
    "commercial_return/resource_envelope.json",
    "commercial_return/acceptance_review.csv",
    "evidence/v18_public_repo_auditor_summary.csv",
    "evidence/v18_public_repo_auditor_decision.csv",
]
for rel in required_files:
    path = audit_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v50 missing artifact: {rel}")

manifest = json.loads((audit_dir / "v50_public_repo_auditor_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v50_public_repo_auditor_3repo_ready") != 1:
    raise SystemExit("v50 manifest should be ready")
if manifest.get("repo_count") != 3 or manifest.get("audit_case_rows") != 9:
    raise SystemExit("v50 manifest should record 3 repos and 9 audit cases")
if manifest.get("owner_repos") != ["pypa/sampleproject", "psf/requests", "pallets/click"]:
    raise SystemExit("v50 manifest should record the public repos in order")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v50 manifest should keep review/release blocked")

source_rows = read_csv(audit_dir / "public_repo_source_snapshot_rows.csv")
case_rows = read_csv(audit_dir / "public_repo_audit_case_rows.csv")
span_rows = read_csv(audit_dir / "public_repo_source_span_rows.csv")
repos = {row["repo_id"] for row in source_rows}
if repos != {"pypa_sampleproject", "psf_requests", "pallets_click"}:
    raise SystemExit(f"v50 repo set mismatch: {repos}")
if any(row["repo_url"].startswith("file://") for row in source_rows):
    raise SystemExit("v50 public repo source rows should use GitHub URLs, not file:// URLs")
if any(row["public_repo_snapshot"] != "1" for row in source_rows):
    raise SystemExit("v50 source rows should mark public snapshots ready")
for row in source_rows:
    path = root / row["artifact_path"]
    if not path.is_file():
        raise SystemExit(f"v50 source artifact missing: {row['artifact_path']}")
    if row["sha256"] != sha256(path):
        raise SystemExit(f"v50 source sha mismatch: {row['artifact_path']}")
    rel_parts = Path(row["artifact_path"]).parts
    source_idx = rel_parts.index("source_repos")
    repo_root = root.joinpath(*rel_parts[: source_idx + 2])
    actual_head = subprocess.check_output(["git", "-C", str(repo_root), "rev-parse", "HEAD"], text=True).strip()
    if len(row["head_sha"]) != 40 or row["head_sha"] != actual_head:
        raise SystemExit(f"v50 head sha mismatch for {row['repo_id']}")

if len(case_rows) != 9 or len(span_rows) != 18:
    raise SystemExit("v50 should write 9 case rows and 18 source spans")
if {row["audit_type"] for row in case_rows} != {"doc_code_conflict", "deprecated_usage", "config_mismatch"}:
    raise SystemExit("v50 should cover all audit types")
for audit_type in ["doc_code_conflict", "deprecated_usage", "config_mismatch"]:
    if sum(1 for row in case_rows if row["audit_type"] == audit_type) != 3:
        raise SystemExit(f"v50 should write 3 rows for {audit_type}")
if sum(1 for row in case_rows if row["expected_label"] == "conflict") != 3:
    raise SystemExit("v50 should include doc-code conflict rows")
if sum(1 for row in case_rows if row["expected_label"] == "config_mismatch_detected") != 1:
    raise SystemExit("v50 should include one detected config mismatch")
if any(row["correct"] != "1" or row["source_spans_ready"] != "1" or row["not_upstream_defect_claim"] != "1" for row in case_rows):
    raise SystemExit("v50 case rows should be correct, source-bound, and bounded")

poc_rows = read_csv(audit_dir / "commercial_return" / "poc_result_rows.csv")
query_rows = read_csv(audit_dir / "commercial_return" / "query_set.csv")
audit_rows = read_csv(audit_dir / "commercial_return" / "audit_trail.csv")
if len(poc_rows) != 9 or len(query_rows) != 9 or len(audit_rows) != 9:
    raise SystemExit("v50 commercial return should write 9 query/result/audit rows")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v50 result rows should pass {field}")
if any(not row["secondary_citation_path"] for row in poc_rows):
    raise SystemExit("v50 results should include secondary citations")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v50 audit rows should pass")

domain = json.loads((audit_dir / "commercial_return" / "domain_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((audit_dir / "commercial_return" / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((audit_dir / "commercial_return" / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("public_repo_count") != 3:
    raise SystemExit("v50 domain should be codebase_qa over 3 public repos")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v50 privacy/resource should be ready")
if resource.get("external_network_used") != 1:
    raise SystemExit("v50 should record public network clone usage")

v18_summary = read_csv(audit_dir / "evidence" / "v18_public_repo_auditor_summary.csv")[0]
if v18_summary.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v50 copied v18 summary should verify commercial PoC")
if v18_summary.get("real_release_package_ready") != "0":
    raise SystemExit("v50 copied v18 summary should keep release blocked")

boundary = (audit_dir / "V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "pypa/sampleproject",
    "psf/requests",
    "pallets/click",
    "Doc-code conflict",
    "Deprecated or legacy usage",
    "Config mismatch",
    "Not an upstream vulnerability or defect disclosure",
    "Not a human-reviewed release package",
]:
    if snippet not in boundary:
        raise SystemExit(f"v50 boundary missing: {snippet}")

with (audit_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v50 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(audit_dir / rel):
        raise SystemExit(f"v50 sha mismatch for {rel}")
PY

echo "v50 Public Repo Auditor 3-repo smoke passed"
