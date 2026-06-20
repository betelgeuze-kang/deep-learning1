#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53g_complete_source_manifest/manifest_001"
SUMMARY_CSV="$RESULTS_DIR/v53g_complete_source_manifest_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53g_complete_source_manifest_decision.csv"

"$ROOT_DIR/experiments/run_v53g_complete_source_manifest.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
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
    raise SystemExit(f"expected one v53g summary row, got {len(summary_rows)}")
summary = summary_rows[0]

if summary.get("v53g_complete_source_manifest_ready") == "0":
    expected_blocked = {
        "v53_ready": "0",
        "locked_repo_count": "10",
        "complete_manifest_repo_count": "10",
        "complete_tree_manifest_ready_repo_count": "10",
        "tree_truncated_repo_count": "0",
        "v53c_canary_source_snapshot_ready": "0",
        "canary_overlap_file_rows": "0",
        "canary_overlap_binding_ready": "0",
        "target_query_rows_min": "1000",
        "planned_query_rows": "1000",
        "query_budget_rows": "8",
        "query_budget_ready_rows": "8",
        "complete_source_content_snapshot_ready": "0",
        "complete_source_query_rows_ready": "0",
        "ah_answer_citation_resource_rows_ready": "0",
        "review_artifacts_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v53g blocked {field}: expected {value}, got {summary.get(field)}")
    for field, minimum in {
        "included_file_rows": 100,
        "query_eligible_file_rows": 1000,
        "source_file_rows": 1,
        "doc_file_rows": 1,
        "config_file_rows": 1,
    }.items():
        if int(summary.get(field, "0")) < minimum:
            raise SystemExit(f"v53g blocked {field}: expected >= {minimum}, got {summary.get(field)}")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in ["repo-lock-input", "complete-source-tree-manifest", "complete-source-query-budget"]:
        if decisions.get(gate) != "pass":
            raise SystemExit(f"v53g blocked path should keep {gate} pass")
    for gate in [
        "canary-overlap-binding",
        "complete-source-content-materialization",
        "complete-source-query-instantiation",
        "supplied-a-h-answer-rows",
        "human-review-artifacts",
        "v53-full-public-repo-audit",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v53g blocked path should keep {gate} blocked")

    required_files = [
        "complete_source_file_manifest_rows.csv",
        "complete_source_repo_coverage_rows.csv",
        "complete_source_query_budget_rows.csv",
        "complete_source_gap_rows.csv",
        "complete_source_fetch_error_rows.csv",
        "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
        "v53g_complete_source_manifest_manifest.json",
        "sha256_manifest.csv",
        "source_v53b/public_repo_10_lock_rows.csv",
        "source_v53b/public_repo_10_query_plan_rows.csv",
        "source_v53b/V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
        "source_v53b/v53b_public_repo_10_lock_manifest.json",
        "source_v53b/sha256_manifest.csv",
        "source_v53b/v53b_public_repo_10_lock_summary.csv",
        "source_v53c/public_repo_canary_source_snapshot_rows.csv",
        "source_v53c/public_repo_canary_status_rows.csv",
        "source_v53c/public_repo_canary_fetch_error_rows.csv",
        "source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
        "source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
        "source_v53c/sha256_manifest.csv",
        "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
        "source_v53f/ah_system_target_rows.csv",
        "source_v53f/answer_row_required_schema.csv",
        "source_v53f/citation_row_required_schema.csv",
        "source_v53f/resource_row_required_schema.csv",
        "source_v53f/ah_answer_row_template.csv",
        "source_v53f/ah_resource_row_template.csv",
        "source_v53f/ah_supplied_validation_rows.csv",
        "source_v53f/ah_validation_error_rows.csv",
        "source_v53f/V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md",
        "source_v53f/v53f_ah_answer_citation_resource_intake_manifest.json",
        "source_v53f/sha256_manifest.csv",
        "source_v53f/v53f_ah_answer_citation_resource_intake_summary.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v53g blocked artifact: {rel}")
    manifest = json.loads((run_dir / "v53g_complete_source_manifest_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v53g_complete_source_manifest_ready") != 0 or manifest.get("canary_overlap_binding_ready") != 0:
        raise SystemExit("v53g blocked manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v53g blocked sha256 mismatch: {rel}")
    boundary = (run_dir / "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md").read_text(encoding="utf-8")
    for snippet in [
        "v53c_canary_source_snapshot_ready=0",
        "canary_overlap_file_rows=0",
        "canary_overlap_binding_ready=0",
        "Do not publish v53 safety/grounding superiority",
    ]:
        if snippet not in boundary:
            raise SystemExit(f"v53g blocked boundary missing {snippet}")
    sys.exit(0)

expected_exact = {
    "v53g_complete_source_manifest_ready": "1",
    "v53_ready": "0",
    "locked_repo_count": "10",
    "complete_manifest_repo_count": "10",
    "complete_tree_manifest_ready_repo_count": "10",
    "tree_truncated_repo_count": "0",
    "v53c_canary_source_snapshot_ready": "1",
    "canary_overlap_binding_ready": "1",
    "target_query_rows_min": "1000",
    "planned_query_rows": "1000",
    "query_budget_rows": "8",
    "query_budget_ready_rows": "8",
    "complete_source_content_snapshot_ready": "0",
    "complete_source_query_rows_ready": "0",
    "ah_answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected_exact.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53g {field}: expected {value}, got {summary.get(field)}")

minimums = {
    "included_file_rows": 100,
    "query_eligible_file_rows": 1000,
    "source_file_rows": 1,
    "doc_file_rows": 1,
    "config_file_rows": 1,
    "canary_overlap_file_rows": 20,
}
for field, minimum in minimums.items():
    if int(summary.get(field, "0")) < minimum:
        raise SystemExit(f"v53g {field}: expected >= {minimum}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "repo-lock-input",
    "canary-overlap-binding",
    "complete-source-tree-manifest",
    "complete-source-query-budget",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53g gate should pass: {gate}")
for gate in [
    "complete-source-content-materialization",
    "complete-source-query-instantiation",
    "supplied-a-h-answer-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53g gate should remain blocked: {gate}")

required_files = [
    "complete_source_file_manifest_rows.csv",
    "complete_source_repo_coverage_rows.csv",
    "complete_source_query_budget_rows.csv",
    "complete_source_gap_rows.csv",
    "complete_source_fetch_error_rows.csv",
    "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "v53g_complete_source_manifest_manifest.json",
    "sha256_manifest.csv",
    "source_v53b/public_repo_10_lock_rows.csv",
    "source_v53b/public_repo_10_query_plan_rows.csv",
    "source_v53b/v53b_public_repo_10_lock_summary.csv",
    "source_v53c/public_repo_canary_source_snapshot_rows.csv",
    "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
    "source_v53f/ah_system_target_rows.csv",
    "source_v53f/ah_answer_row_template.csv",
    "source_v53f/ah_resource_row_template.csv",
    "source_v53f/ah_validation_error_rows.csv",
    "source_v53f/v53f_ah_answer_citation_resource_intake_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53g artifact: {rel}")

repo_rows = read_csv(run_dir / "complete_source_repo_coverage_rows.csv")
if len(repo_rows) != 10:
    raise SystemExit(f"v53g expected 10 repo coverage rows, got {len(repo_rows)}")
if any(row["complete_source_tree_manifest_ready"] != "1" for row in repo_rows):
    raise SystemExit("v53g every repo should have complete source tree manifest readiness")
if any(row["content_snapshot_ready"] != "0" or row["content_materialized_file_rows"] != "0" for row in repo_rows):
    raise SystemExit("v53g should not claim materialized content snapshots")

file_rows = read_csv(run_dir / "complete_source_file_manifest_rows.csv")
if len(file_rows) != int(summary["included_file_rows"]):
    raise SystemExit("v53g file manifest count mismatch")
if {row["owner_repo"] for row in file_rows} != {row["owner_repo"] for row in repo_rows}:
    raise SystemExit("v53g file manifest should cover every locked repo")
if any(row["content_materialized"] != "0" or row["content_sha256"] != "" for row in file_rows[:200]):
    raise SystemExit("v53g file manifest must remain metadata-only")
categories = Counter(row["source_category"] for row in file_rows)
for category in ["source", "doc", "config"]:
    if categories[category] <= 0:
        raise SystemExit(f"v53g missing category {category}")
if sum(1 for row in file_rows if row["canary_overlap"] == "1") < 20:
    raise SystemExit("v53g should bind back to canary snapshot rows")

budget_rows = read_csv(run_dir / "complete_source_query_budget_rows.csv")
if len(budget_rows) != 8:
    raise SystemExit("v53g should emit eight query budget rows")
if sum(int(row["target_query_rows"]) for row in budget_rows) != 1000:
    raise SystemExit("v53g query budget should sum to 1000")
if {row["status"] for row in budget_rows} != {"budgeted-not-materialized"}:
    raise SystemExit("v53g query budget should not be materialized yet")

gap_rows = {row["gap"]: row["status"] for row in read_csv(run_dir / "complete_source_gap_rows.csv")}
for gap in [
    "complete-source-content-materialization",
    "complete-source-span-extraction",
    "complete-source-1000-query-instantiation",
    "a-h-answer-citation-resource-rows",
    "review-artifacts",
    "v53-ready",
]:
    if gap_rows.get(gap) != "blocked":
        raise SystemExit(f"v53g gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v53g_complete_source_manifest_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53g_complete_source_manifest_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53g manifest readiness boundary mismatch")
if manifest.get("complete_source_content_snapshot_ready") != 0 or manifest.get("complete_source_query_rows_ready") != 0:
    raise SystemExit("v53g manifest should keep content/query blockers")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53g sha256 mismatch: {rel}")

boundary = (run_dir / "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "recursive Git tree source/doc/config/test manifests",
    "not a content-materialized source snapshot",
    "complete_source_content_snapshot_ready=0",
    "complete-source 1000+ query rows",
    "Do not publish v53 safety/grounding superiority",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53g boundary missing {snippet}")
PY

echo "v53g complete-source manifest smoke passed"
