#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53h_complete_source_content_snapshot/snapshot_001"
SUMMARY_CSV="$RESULTS_DIR/v53h_complete_source_content_snapshot_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53h_complete_source_content_snapshot_decision.csv"

V53H_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53h_complete_source_content_snapshot.sh" >/dev/null

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
    raise SystemExit(f"expected one v53h summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53h_complete_source_content_snapshot_ready": "1",
    "v53g_complete_source_manifest_ready": "1",
    "v53_ready": "0",
    "complete_manifest_repo_count": "10",
    "content_snapshot_ready_repo_count": "10",
    "content_materialized_file_rows": "11318",
    "content_sha256_rows": "11318",
    "content_bytes_materialized": "124845122",
    "query_eligible_content_rows": "11312",
    "source_file_rows": "3160",
    "doc_file_rows": "4026",
    "config_file_rows": "342",
    "test_file_rows": "3790",
    "canary_overlap_file_rows": "27",
    "complete_source_content_snapshot_ready": "1",
    "complete_source_query_rows_ready": "0",
    "ah_answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53h {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53g-complete-source-manifest-input",
    "git-blob-content-materialization",
    "content-sha256-binding",
    "repo-content-coverage",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53h gate should pass: {gate}")
for gate in [
    "complete-source-span-extraction",
    "complete-source-1000-query-instantiation",
    "supplied-a-h-answer-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53h gate should remain blocked: {gate}")

required_files = [
    "complete_source_content_snapshot_rows.csv",
    "complete_source_content_repo_rows.csv",
    "complete_source_content_gap_rows.csv",
    "V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md",
    "v53h_complete_source_content_snapshot_manifest.json",
    "sha256_manifest.csv",
    "source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53g/v53g_complete_source_manifest_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53h artifact: {rel}")

content_rows = read_csv(run_dir / "complete_source_content_snapshot_rows.csv")
if len(content_rows) != int(summary["content_materialized_file_rows"]):
    raise SystemExit("v53h content row count mismatch")
if sum(int(row["bytes"]) for row in content_rows) != int(summary["content_bytes_materialized"]):
    raise SystemExit("v53h content bytes mismatch")
if sum(1 for row in content_rows if row["query_eligible"] == "1") != int(summary["query_eligible_content_rows"]):
    raise SystemExit("v53h query-eligible content row count mismatch")
categories = Counter(row["source_category"] for row in content_rows)
for field, category in [
    ("source_file_rows", "source"),
    ("doc_file_rows", "doc"),
    ("config_file_rows", "config"),
    ("test_file_rows", "test"),
]:
    if categories[category] != int(summary[field]):
        raise SystemExit(f"v53h category count mismatch: {category}")
if any(row["content_materialized"] != "1" for row in content_rows[:200]):
    raise SystemExit("v53h content rows should be materialized")

repo_rows = read_csv(run_dir / "complete_source_content_repo_rows.csv")
if len(repo_rows) != 10:
    raise SystemExit("v53h should emit 10 repo content rows")
if any(row["content_snapshot_ready"] != "1" for row in repo_rows):
    raise SystemExit("v53h every repo should have content snapshot readiness")
if sum(int(row["content_materialized_file_rows"]) for row in repo_rows) != len(content_rows):
    raise SystemExit("v53h repo content row totals mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53h sha256 mismatch: {rel}")

sample_indexes = sorted({0, 1, 2, len(content_rows) // 2, len(content_rows) - 3, len(content_rows) - 2, len(content_rows) - 1})
for index in sample_indexes:
    row = content_rows[index]
    path = run_dir / row["local_relpath"]
    if not path.is_file():
        raise SystemExit(f"v53h missing content file: {row['local_relpath']}")
    if sha256(path) != row["content_sha256"]:
        raise SystemExit(f"v53h content file hash mismatch: {row['local_relpath']}")
    if sha_rows.get(row["local_relpath"]) != row["content_sha256"]:
        raise SystemExit(f"v53h sha manifest content mismatch: {row['local_relpath']}")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "complete_source_content_gap_rows.csv")}
for gap in [
    "complete-source-span-extraction",
    "complete-source-1000-query-instantiation",
    "a-h-answer-citation-resource-rows",
    "human-review-artifacts",
    "v53-ready",
    "real-release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53h gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v53h_complete_source_content_snapshot_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53h_complete_source_content_snapshot_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53h manifest readiness boundary mismatch")
if manifest.get("complete_source_query_rows_ready") != 0 or manifest.get("ah_answer_citation_resource_rows_ready") != 0:
    raise SystemExit("v53h should keep query/A-H blockers")

boundary = (run_dir / "V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete-source content snapshot prerequisite",
    "content_materialized_file_rows=11318",
    "complete_source_query_rows_ready=0",
    "A/B/C/D/E/G/H answer/citation/resource rows",
    "Do not publish complete-source audit completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53h boundary missing {snippet}")
PY

echo "v53h complete-source content snapshot smoke passed"
