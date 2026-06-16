#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53i_complete_source_query_instantiation/instantiate_001"
SUMMARY_CSV="$RESULTS_DIR/v53i_complete_source_query_instantiation_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53i_complete_source_query_instantiation_decision.csv"

V53I_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53i_complete_source_query_instantiation.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
results = run_dir.parents[1]
v53h_dir = results / "v53h_complete_source_content_snapshot" / "snapshot_001"

TARGET_FAMILY_ROWS = {
    "doc_code_conflict": 140,
    "deprecation_legacy_usage": 140,
    "config_mismatch": 140,
    "api_behavior": 160,
    "docs_truthfulness": 160,
    "examples_tests_alignment": 100,
    "unsupported_claim_abstain": 100,
    "ambiguous_source_abstain": 30,
    "missing_api_abstain": 30,
}
NEGATIVE_FAMILIES = {"unsupported_claim_abstain", "ambiguous_source_abstain", "missing_api_abstain"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def clean_line(line):
    return re.sub(r"\s+", " ", line.strip())


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v53i summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53i_complete_source_query_instantiation_ready": "1",
    "v53h_complete_source_content_snapshot_ready": "1",
    "v53g_complete_source_manifest_ready": "1",
    "v53_ready": "0",
    "complete_source_content_snapshot_ready": "1",
    "complete_source_query_rows_ready": "1",
    "complete_source_query_rows": "1000",
    "complete_source_span_rows": "1000",
    "supported_source_span_bound_rows": "840",
    "negative_abstain_rows": "160",
    "unsupported_control_rows": "100",
    "ambiguous_control_rows": "30",
    "missing_specific_abstain_rows": "30",
    "doc_code_conflict_rows": "140",
    "repo_count": "10",
    "family_count": "9",
    "target_query_rows_min": "1000",
    "missing_query_rows": "0",
    "query_eligible_content_rows": "11260",
    "source_file_rows": "3160",
    "doc_file_rows": "3973",
    "config_file_rows": "342",
    "test_file_rows": "3791",
    "ah_answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53i {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53h-complete-source-content-input",
    "complete-source-query-instantiation",
    "source-span-binding",
    "family-budget-targets",
    "negative-abstain-target",
    "repo-coverage",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53i gate should pass: {gate}")
for gate in [
    "supplied-a-h-answer-rows",
    "citation-resource-coverage",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53i gate should remain blocked: {gate}")

required_files = [
    "complete_source_query_rows.csv",
    "complete_source_span_rows.csv",
    "complete_source_query_family_rows.csv",
    "complete_source_control_family_rows.csv",
    "complete_source_query_repo_rows.csv",
    "complete_source_query_gap_rows.csv",
    "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md",
    "v53i_complete_source_query_instantiation_manifest.json",
    "sha256_manifest.csv",
    "source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v53h/complete_source_content_repo_rows.csv",
    "source_v53h/complete_source_content_gap_rows.csv",
    "source_v53h/V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md",
    "source_v53h/v53h_complete_source_content_snapshot_manifest.json",
    "source_v53h/sha256_manifest.csv",
    "source_v53h/v53h_complete_source_content_snapshot_summary.csv",
    "source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53i artifact: {rel}")

queries = read_csv(run_dir / "complete_source_query_rows.csv")
spans = read_csv(run_dir / "complete_source_span_rows.csv")
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53i should write 1000 query rows and 1000 source span rows")
if len({row["query_id"] for row in queries}) != 1000:
    raise SystemExit("v53i query IDs should be unique")
if {row["source_span_id"] for row in queries} != {row["source_span_id"] for row in spans}:
    raise SystemExit("v53i query/source span IDs should match")
if len({row["owner_repo"] for row in queries}) != 10:
    raise SystemExit("v53i query rows should cover ten repos")
if set(row["audit_type"] for row in queries) != set(TARGET_FAMILY_ROWS):
    raise SystemExit("v53i should cover all target query families")
if any(row["source_snapshot_scope"] != "complete-source-content" for row in queries):
    raise SystemExit("v53i query rows should bind to complete-source content scope")
if any(row["scale_scope"] != "v53i-complete-source-1000" for row in queries):
    raise SystemExit("v53i scale scope mismatch")
if any(row["source_span_required"] != "1" for row in queries):
    raise SystemExit("v53i should require a source span for every query")
if any(not re.fullmatch(r"[0-9a-f]{40}", row["head_sha"]) for row in queries):
    raise SystemExit("v53i query rows should bind to pinned HEAD SHA")

family_rows = read_csv(run_dir / "complete_source_query_family_rows.csv")
if len(family_rows) != 9:
    raise SystemExit("v53i should write nine family rows")
for row in family_rows:
    family = row["audit_type"]
    if int(row["target_query_rows"]) != TARGET_FAMILY_ROWS[family]:
        raise SystemExit(f"v53i family target mismatch: {family}")
    if int(row["complete_source_query_rows"]) != TARGET_FAMILY_ROWS[family]:
        raise SystemExit(f"v53i family count mismatch: {family}")
    if row["status"] != "instantiated":
        raise SystemExit(f"v53i family should be instantiated: {family}")
    if row["negative_or_abstain_family"] != str(int(family in NEGATIVE_FAMILIES)):
        raise SystemExit(f"v53i family negative flag mismatch: {family}")
if sum(int(row["complete_source_query_rows"]) for row in family_rows) != 1000:
    raise SystemExit("v53i family rows should sum to 1000")

negative = [row for row in queries if row["negative_or_abstain"] == "1"]
supported = [row for row in queries if row["negative_or_abstain"] == "0"]
if len(negative) != 160 or len(supported) != 840:
    raise SystemExit("v53i negative/supported split mismatch")
if any(row["expected_behavior"] != "abstain" or not row["expected_answer"].startswith("ABSTAIN:") for row in negative):
    raise SystemExit("v53i negative rows should require abstention")
if any(row["expected_behavior"] != "answer-with-citation" for row in supported):
    raise SystemExit("v53i supported rows should expect cited answers")
missing_specific = [row for row in negative if row["audit_type"] == "missing_api_abstain"]
if len(missing_specific) != 30:
    raise SystemExit("v53i should include 30 missing-specific abstain rows")
if any("v53i_missing_api_" not in row["question"] for row in missing_specific):
    raise SystemExit("v53i missing-specific rows should name the missing API control")

control_rows = {row["control_family"]: row for row in read_csv(run_dir / "complete_source_control_family_rows.csv")}
expected_controls = {
    "unsupported_claim_abstain": ("100", "present"),
    "ambiguous_source_abstain": ("30", "present"),
    "missing_api_abstain": ("30", "present"),
    "doc_code_conflict": ("140", "present"),
}
if set(control_rows) != set(expected_controls):
    raise SystemExit("v53i control family rows mismatch")
for control_family, (rows, status) in expected_controls.items():
    if control_rows[control_family]["query_rows"] != rows or control_rows[control_family]["status"] != status:
        raise SystemExit(f"v53i control family mismatch: {control_family}")

repo_rows = read_csv(run_dir / "complete_source_query_repo_rows.csv")
if len(repo_rows) != 10 or any(int(row["complete_source_query_rows"]) <= 0 for row in repo_rows):
    raise SystemExit("v53i should cover all ten repos")
if sum(int(row["complete_source_query_rows"]) for row in repo_rows) != 1000:
    raise SystemExit("v53i repo query rows should sum to 1000")

content_rows = {
    (row["owner_repo"], row["path"], row["content_sha256"]): row
    for row in read_csv(run_dir / "source_v53h/complete_source_content_snapshot_rows.csv")
}
span_by_id = {row["source_span_id"]: row for row in spans}
for query in queries:
    span = span_by_id[query["source_span_id"]]
    if query["query_id"] != span["query_id"]:
        raise SystemExit("v53i span/query ID mismatch")
    if query["owner_repo"] != span["owner_repo"] or query["source_path"] != span["path"]:
        raise SystemExit("v53i query/span source mismatch")
    if query["source_file_sha256"] != span["source_file_sha256"]:
        raise SystemExit("v53i query/span file hash mismatch")
    if query["source_git_blob_sha"] != span["git_blob_sha"]:
        raise SystemExit("v53i query/span git blob mismatch")
    if query["expected_answer_sha256"] != sha256_text(query["expected_answer"]):
        raise SystemExit("v53i expected answer hash mismatch")
    key = (query["owner_repo"], query["source_path"], query["source_file_sha256"])
    source = content_rows.get(key)
    if source is None:
        raise SystemExit("v53i span does not bind to v53h content row")
    if source["git_blob_sha"] != span["git_blob_sha"]:
        raise SystemExit("v53i source git blob mismatch")
    source_path = v53h_dir / span["local_relpath"]
    if not source_path.is_file():
        raise SystemExit(f"v53i missing v53h content file: {span['local_relpath']}")
    lines = source_path.read_text(encoding="utf-8", errors="replace").splitlines()
    line_no = int(span["line_start"])
    if line_no < 1 or line_no > max(1, len(lines)):
        raise SystemExit("v53i span line is outside source file")
    if lines:
        expected_evidence = clean_line(lines[line_no - 1])[:240]
        if span["evidence_text"] != expected_evidence:
            raise SystemExit("v53i evidence text should match the pinned v53h line")
    if span["evidence_text_sha256"] != sha256_text(span["evidence_text"]):
        raise SystemExit("v53i evidence text hash mismatch")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "complete_source_query_gap_rows.csv")}
for gap in ["complete-source-query-instantiation", "line-level-source-span-binding"]:
    if gaps.get(gap) != "pass":
        raise SystemExit(f"v53i gap should pass: {gap}")
for gap in [
    "a-h-answer-citation-resource-rows",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-ready",
    "real-release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53i gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v53i_complete_source_query_instantiation_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53i_complete_source_query_instantiation_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53i manifest readiness boundary mismatch")
if manifest.get("complete_source_query_rows") != 1000 or manifest.get("negative_abstain_rows") != 160:
    raise SystemExit("v53i manifest count mismatch")
if manifest.get("missing_specific_abstain_rows") != 30 or manifest.get("unsupported_control_rows") != 100:
    raise SystemExit("v53i manifest control family mismatch")
if manifest.get("target_family_rows") != TARGET_FAMILY_ROWS:
    raise SystemExit("v53i manifest family target mismatch")
if manifest.get("ah_answer_citation_resource_rows_ready") != 0:
    raise SystemExit("v53i should keep A-H rows blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53i sha256 mismatch: {rel}")

boundary = (run_dir / "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000-query budget",
    "complete_source_query_rows=1000",
    "negative_abstain_rows=160",
    "missing_specific_abstain_rows=30",
    "ah_answer_citation_resource_rows_ready=0",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53i boundary missing {snippet}")
PY

echo "v53i complete-source query instantiation smoke passed"
