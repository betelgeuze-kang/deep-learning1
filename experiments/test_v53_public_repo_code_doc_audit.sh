#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001"
SUMMARY_CSV="$RESULTS_DIR/v53_public_repo_code_doc_audit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53_public_repo_code_doc_audit_decision.csv"

"$ROOT_DIR/experiments/run_v53_public_repo_code_doc_audit.sh" >/dev/null

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
    raise SystemExit(f"expected one v53 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53_public_repo_code_doc_audit_contract_ready": "1",
    "v53_ready": "0",
    "target_repo_count_min": "10",
    "target_query_rows_min": "1000",
    "current_seed_repo_count": "3",
    "current_seed_query_rows": "9",
    "missing_repo_count": "7",
    "missing_query_rows": "991",
    "guard_negative_rows": "3",
    "negative_control_target_rows": "100",
    "pinned_commit_manifest_ready": "1",
    "abstain_policy_contract_ready": "1",
    "wrong_answer_guard_contract_ready": "1",
    "v50_seed_reused": "1",
    "v50_public_refresh_allowed": "0",
    "v50_public_refresh_executed": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("source_span_bound_rows", "0")) < int(summary.get("current_seed_query_rows", "0")):
    raise SystemExit("v53 seed source spans should cover seed query rows")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v53-public-repo-audit-contract", "v50-seed-refresh-policy", "v50-seed-evidence", "source-span-binding", "pinned-commit-manifest"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53 gate should pass: {gate}")
for gate in ["repo-count-target", "query-count-target", "negative-control-target", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53 gate should remain blocked: {gate}")

required_files = [
    "target_repo_rows.csv",
    "query_scale_contract_rows.csv",
    "artifact_contract_rows.csv",
    "V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md",
    "v53_public_repo_code_doc_audit_manifest.json",
    "sha256_manifest.csv",
    "source_v50/public_repo_source_snapshot_rows.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/guard_negative_rows.csv",
    "source_v50/V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md",
    "source_v50/v50_public_repo_auditor_manifest.json",
    "source_v50/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53 artifact: {rel}")

repo_rows = read_csv(run_dir / "target_repo_rows.csv")
if len(repo_rows) != 10:
    raise SystemExit("v53 target repo rows should cover 10 minimum slots")
if sum(1 for row in repo_rows if row["status"] == "seed-ready-from-v50") != 3:
    raise SystemExit("v53 should seed exactly three repos from v50")
if sum(1 for row in repo_rows if row["status"] == "missing-for-v53") != 7:
    raise SystemExit("v53 should keep seven repo slots missing")
if any(row["pinned_ref_ready"] != "1" for row in repo_rows if row["status"] == "seed-ready-from-v50"):
    raise SystemExit("v53 seed repo rows should keep pinned refs ready")

query_rows = read_csv(run_dir / "query_scale_contract_rows.csv")
if sum(int(row["target_query_rows"]) for row in query_rows) != 1000:
    raise SystemExit("v53 query scale target should sum to 1000")
if sum(int(row["existing_seed_rows"]) for row in query_rows) != 9:
    raise SystemExit("v53 existing seed query rows should sum to 9")
if sum(int(row["missing_query_rows"]) for row in query_rows) != 991:
    raise SystemExit("v53 missing query rows should sum to 991")
if not any(row["negative_or_abstain_required"] == "1" for row in query_rows):
    raise SystemExit("v53 query contract should include negative/abstain rows")

artifact_contract = {row["artifact"] for row in read_csv(run_dir / "artifact_contract_rows.csv")}
for artifact in ["pinned_repo_manifest", "source_snapshot_rows", "query_set", "answer_rows", "citation_rows", "abstain_rows", "guard_negative_rows", "audit_report", "resource_rows", "sha256_manifest"]:
    if artifact not in artifact_contract:
        raise SystemExit(f"v53 artifact contract missing {artifact}")

manifest = json.loads((run_dir / "v53_public_repo_code_doc_audit_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53_public_repo_code_doc_audit_contract_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53 manifest readiness boundary mismatch")
if manifest.get("missing_repo_count") != 7 or manifest.get("missing_query_rows") != 991:
    raise SystemExit("v53 manifest missing-count mismatch")
for field, value in {
    "v50_seed_reused": 1,
    "v50_public_refresh_allowed": 0,
    "v50_public_refresh_executed": 0,
}.items():
    if manifest.get(field) != value:
        raise SystemExit(f"v53 manifest {field} mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53 sha256 mismatch: {rel}")

boundary = (run_dir / "V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed 10-30 repo / 1000-3000 query audit",
    "missing_repo_count=7",
    "missing_query_rows=991",
    "existing v50 seed artifacts are reused by default",
    "Do not publish v53 safety/grounding superiority claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53 boundary missing {snippet}")
PY

echo "v53 public repo code/doc audit contract smoke passed"
