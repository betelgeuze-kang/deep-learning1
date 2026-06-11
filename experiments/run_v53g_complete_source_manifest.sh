#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53g_complete_source_manifest"
RUN_ID="${V53G_RUN_ID:-manifest_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v53f_ah_answer_citation_resource_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53b_dir = results / "v53b_public_repo_10_lock" / "lock_001"
v53c_dir = results / "v53c_public_repo_canary_source_snapshot" / "snapshot_001"
v53f_dir = results / "v53f_ah_answer_citation_resource_intake" / "intake_001"

TARGET_QUERY_ROWS = 1000
QUERY_FAMILIES = [
    ("doc_code_conflict", 140, "source"),
    ("deprecation_legacy_usage", 140, "source"),
    ("config_mismatch", 140, "config"),
    ("api_behavior", 160, "source"),
    ("docs_truthfulness", 160, "doc"),
    ("examples_tests_alignment", 100, "test"),
    ("unsupported_claim_abstain", 100, "mixed"),
    ("ambiguous_source_abstain", 60, "mixed"),
]
INCLUDE_EXTENSIONS = {
    ".py", ".pyi", ".md", ".rst", ".txt", ".toml", ".cfg", ".ini", ".yml", ".yaml",
}
CONFIG_BASENAMES = {
    "pyproject.toml", "setup.cfg", "setup.py", "tox.ini", "mypy.ini", "pytest.ini",
    "requirements.txt", "requirements-dev.txt", "readme.md", "readme.rst", "readme.txt",
}
SKIP_PARTS = {
    ".git", ".github", ".tox", ".mypy_cache", ".pytest_cache", "__pycache__",
    "node_modules", "dist", "build", "site-packages", ".venv", "venv",
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def fetch_json(url):
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "v53g-complete-source-manifest/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.loads(response.read().decode("utf-8"))


def file_extension(path):
    lower = path.lower()
    if lower.endswith(".tar.gz"):
        return ".tar.gz"
    return Path(lower).suffix


def source_category(path):
    lower = path.lower()
    name = lower.rsplit("/", 1)[-1]
    parts = set(lower.split("/")[:-1])
    ext = file_extension(lower)
    if name in CONFIG_BASENAMES or ext in {".toml", ".cfg", ".ini", ".yml", ".yaml"}:
        return "config"
    if lower.startswith(("docs/", "doc/")) or "/docs/" in lower or "/doc/" in lower or ext in {".md", ".rst", ".txt"}:
        return "doc"
    if lower.startswith(("tests/", "test/")) or "/tests/" in lower or "/test/" in lower:
        return "test"
    if ext in {".py", ".pyi"}:
        return "source"
    if "examples" in parts or "example" in parts:
        return "example"
    return "other"


def include_blob(path, size):
    lower = path.lower()
    parts = set(lower.split("/")[:-1])
    if parts & SKIP_PARTS:
        return False
    if size <= 0:
        return False
    ext = file_extension(lower)
    name = lower.rsplit("/", 1)[-1]
    return ext in INCLUDE_EXTENSIONS or name in CONFIG_BASENAMES


def query_eligible(category, size):
    return int(category in {"source", "doc", "config", "test", "example"} and 0 < size <= 500_000)


for rel in [
    "public_repo_10_lock_rows.csv",
    "public_repo_10_query_plan_rows.csv",
    "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "v53b_public_repo_10_lock_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53b_dir / rel, f"source_v53b/{rel}")
copy(results / "v53b_public_repo_10_lock_summary.csv", "source_v53b/v53b_public_repo_10_lock_summary.csv")

for rel in [
    "public_repo_canary_source_snapshot_rows.csv",
    "public_repo_canary_status_rows.csv",
    "public_repo_canary_fetch_error_rows.csv",
    "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "v53c_public_repo_canary_source_snapshot_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53c_dir / rel, f"source_v53c/{rel}")
copy(results / "v53c_public_repo_canary_source_snapshot_summary.csv", "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv")

for rel in [
    "ah_system_target_rows.csv",
    "answer_row_required_schema.csv",
    "citation_row_required_schema.csv",
    "resource_row_required_schema.csv",
    "ah_answer_row_template.csv",
    "ah_resource_row_template.csv",
    "ah_supplied_validation_rows.csv",
    "ah_validation_error_rows.csv",
    "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md",
    "v53f_ah_answer_citation_resource_intake_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53f_dir / rel, f"source_v53f/{rel}")
copy(results / "v53f_ah_answer_citation_resource_intake_summary.csv", "source_v53f/v53f_ah_answer_citation_resource_intake_summary.csv")

lock_rows = read_csv(v53b_dir / "public_repo_10_lock_rows.csv")
canary_rows = read_csv(v53c_dir / "public_repo_canary_source_snapshot_rows.csv")
canary_keys = {(row["owner_repo"], row["path"]) for row in canary_rows}

file_rows = []
repo_rows = []
fetch_error_rows = []

for repo in lock_rows:
    owner_repo = repo["owner_repo"]
    head_sha = repo["head_sha"]
    tree_url = f"https://api.github.com/repos/{owner_repo}/git/trees/{head_sha}?recursive=1"
    tree = []
    tree_truncated = 1
    try:
        payload = fetch_json(tree_url)
        tree = payload.get("tree", [])
        tree_truncated = int(bool(payload.get("truncated")))
    except Exception as exc:
        fetch_error_rows.append(
            {
                "owner_repo": owner_repo,
                "stage": "recursive-tree",
                "reason": str(exc)[:240],
            }
        )

    included = []
    tree_blob_rows = 0
    for item in tree:
        if item.get("type") != "blob":
            continue
        tree_blob_rows += 1
        path = item.get("path", "")
        size = int(item.get("size") or 0)
        if not include_blob(path, size):
            continue
        category = source_category(path)
        ext = file_extension(path)
        canary_overlap = int((owner_repo, path) in canary_keys)
        eligible = query_eligible(category, size)
        row = {
            "repo_slot": repo["repo_slot"],
            "repo_id": repo["repo_id"],
            "owner_repo": owner_repo,
            "repo_url": repo["repo_url"],
            "head_sha": head_sha,
            "default_branch": repo["default_branch"],
            "path": path,
            "git_blob_sha": item.get("sha", ""),
            "bytes": size,
            "file_extension": ext,
            "source_category": category,
            "canary_overlap": canary_overlap,
            "query_eligible": eligible,
            "content_materialized": 0,
            "content_sha256": "",
            "complete_source_manifest_scope": "recursive-git-tree",
            "source_snapshot_scope": "complete-manifest-no-content",
        }
        included.append(row)
        file_rows.append(row)

    counts = Counter(row["source_category"] for row in included)
    eligible_rows = sum(int(row["query_eligible"]) for row in included)
    repo_rows.append(
        {
            "repo_slot": repo["repo_slot"],
            "repo_id": repo["repo_id"],
            "owner_repo": owner_repo,
            "head_sha": head_sha,
            "tree_blob_rows": tree_blob_rows,
            "included_file_rows": len(included),
            "query_eligible_file_rows": eligible_rows,
            "source_file_rows": counts.get("source", 0),
            "doc_file_rows": counts.get("doc", 0),
            "config_file_rows": counts.get("config", 0),
            "test_file_rows": counts.get("test", 0),
            "example_file_rows": counts.get("example", 0),
            "canary_overlap_file_rows": sum(int(row["canary_overlap"]) for row in included),
            "tree_truncated": tree_truncated,
            "complete_source_tree_manifest_ready": int(tree_blob_rows > 0 and len(included) > 0 and tree_truncated == 0),
            "content_materialized_file_rows": 0,
            "content_snapshot_ready": 0,
        }
    )

file_fieldnames = [
    "repo_slot",
    "repo_id",
    "owner_repo",
    "repo_url",
    "head_sha",
    "default_branch",
    "path",
    "git_blob_sha",
    "bytes",
    "file_extension",
    "source_category",
    "canary_overlap",
    "query_eligible",
    "content_materialized",
    "content_sha256",
    "complete_source_manifest_scope",
    "source_snapshot_scope",
]
write_csv(run_dir / "complete_source_file_manifest_rows.csv", file_fieldnames, file_rows)
write_csv(run_dir / "complete_source_repo_coverage_rows.csv", list(repo_rows[0].keys()), repo_rows)
write_csv(run_dir / "complete_source_fetch_error_rows.csv", ["owner_repo", "stage", "reason"], fetch_error_rows)

eligible_by_category = Counter(row["source_category"] for row in file_rows if int(row["query_eligible"]))
query_budget_rows = []
for family, target_rows, preferred_category in QUERY_FAMILIES:
    if preferred_category == "mixed":
        eligible_pool = sum(eligible_by_category.values())
    else:
        eligible_pool = eligible_by_category.get(preferred_category, 0)
    query_budget_rows.append(
        {
            "audit_type": family,
            "target_query_rows": target_rows,
            "preferred_source_category": preferred_category,
            "eligible_file_rows": eligible_pool,
            "complete_source_query_budget_ready": int(eligible_pool > 0),
            "negative_or_abstain_family": int(family in {"unsupported_claim_abstain", "ambiguous_source_abstain"}),
            "query_rows_materialized": 0,
            "status": "budgeted-not-materialized" if eligible_pool > 0 else "blocked-no-eligible-source",
        }
    )
write_csv(run_dir / "complete_source_query_budget_rows.csv", list(query_budget_rows[0].keys()), query_budget_rows)

gap_rows = [
    {
        "gap": "complete-source-content-materialization",
        "status": "blocked",
        "reason": "v53g records Git tree/blob metadata only; file content snapshots and content sha256 rows are not materialized",
    },
    {
        "gap": "complete-source-span-extraction",
        "status": "blocked",
        "reason": "no line-level complete-source spans have been extracted from the full manifest",
    },
    {
        "gap": "complete-source-1000-query-instantiation",
        "status": "blocked",
        "reason": "query budget is planned, but complete-source query rows are not generated here",
    },
    {
        "gap": "a-h-answer-citation-resource-rows",
        "status": "blocked",
        "reason": "v53f intake templates exist, but supplied valid A-H rows over complete-source queries are absent",
    },
    {
        "gap": "review-artifacts",
        "status": "blocked",
        "reason": "human/source review artifacts are not supplied",
    },
    {
        "gap": "v53-ready",
        "status": "blocked",
        "reason": "complete-source manifest is a prerequisite, not the completed v53 audit",
    },
]
write_csv(run_dir / "complete_source_gap_rows.csv", list(gap_rows[0].keys()), gap_rows)

repo_count = len(repo_rows)
manifest_ready_repo_count = sum(int(row["complete_source_tree_manifest_ready"]) for row in repo_rows)
tree_truncated_repo_count = sum(int(row["tree_truncated"]) for row in repo_rows)
included_file_rows = len(file_rows)
query_eligible_file_rows = sum(int(row["query_eligible"]) for row in file_rows)
canary_overlap_file_rows = sum(int(row["canary_overlap"]) for row in file_rows)
planned_query_rows = sum(int(row["target_query_rows"]) for row in query_budget_rows)
query_budget_ready_rows = sum(int(row["complete_source_query_budget_ready"]) for row in query_budget_rows)
category_counts = Counter(row["source_category"] for row in file_rows)
complete_source_manifest_ready = int(
    repo_count >= 10
    and manifest_ready_repo_count >= 10
    and tree_truncated_repo_count == 0
    and included_file_rows >= 100
    and query_eligible_file_rows >= TARGET_QUERY_ROWS
    and canary_overlap_file_rows >= min(20, len(canary_rows))
    and planned_query_rows >= TARGET_QUERY_ROWS
    and query_budget_ready_rows == len(QUERY_FAMILIES)
)

summary = {
    "v53g_complete_source_manifest_ready": complete_source_manifest_ready,
    "v53_ready": 0,
    "locked_repo_count": len(lock_rows),
    "complete_manifest_repo_count": repo_count,
    "complete_tree_manifest_ready_repo_count": manifest_ready_repo_count,
    "tree_truncated_repo_count": tree_truncated_repo_count,
    "fetch_error_rows": len(fetch_error_rows),
    "included_file_rows": included_file_rows,
    "query_eligible_file_rows": query_eligible_file_rows,
    "source_file_rows": category_counts.get("source", 0),
    "doc_file_rows": category_counts.get("doc", 0),
    "config_file_rows": category_counts.get("config", 0),
    "test_file_rows": category_counts.get("test", 0),
    "canary_overlap_file_rows": canary_overlap_file_rows,
    "target_query_rows_min": TARGET_QUERY_ROWS,
    "planned_query_rows": planned_query_rows,
    "query_budget_rows": len(query_budget_rows),
    "query_budget_ready_rows": query_budget_ready_rows,
    "complete_source_content_snapshot_ready": 0,
    "complete_source_query_rows_ready": 0,
    "ah_answer_citation_resource_rows_ready": 0,
    "review_artifacts_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("repo-lock-input", "pass" if len(lock_rows) >= 10 else "blocked", f"locked_repo_count={len(lock_rows)}"),
    ("canary-overlap-binding", "pass" if canary_overlap_file_rows >= min(20, len(canary_rows)) else "blocked", f"canary_overlap_file_rows={canary_overlap_file_rows}"),
    ("complete-source-tree-manifest", "pass" if complete_source_manifest_ready else "blocked", f"repo_count={repo_count}; included_file_rows={included_file_rows}; tree_truncated_repo_count={tree_truncated_repo_count}"),
    ("complete-source-query-budget", "pass" if query_budget_ready_rows == len(QUERY_FAMILIES) and planned_query_rows >= TARGET_QUERY_ROWS else "blocked", f"planned_query_rows={planned_query_rows}; ready_families={query_budget_ready_rows}"),
    ("complete-source-content-materialization", "blocked", "content bytes and content sha256 rows are intentionally not materialized by v53g"),
    ("complete-source-query-instantiation", "blocked", "v53g emits a query budget, not complete-source query rows"),
    ("supplied-a-h-answer-rows", "blocked", "A-H supplied answer/citation/resource rows are still absent"),
    ("human-review-artifacts", "blocked", "human review artifacts are still absent"),
    ("v53-full-public-repo-audit", "blocked", "complete-source manifest is not the completed v53 audit"),
    ("real-release-package", "blocked", "v53g manifest is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md").write_text(
    "# v53g Complete Source Manifest Boundary\n\n"
    "This layer promotes v53 beyond canary snapshots by binding the 10 locked repositories to recursive Git tree source/doc/config/test manifests. "
    "It is a complete source manifest, not a content-materialized source snapshot and not the completed v53 audit.\n\n"
    f"- complete_manifest_repo_count={repo_count}\n"
    f"- complete_tree_manifest_ready_repo_count={manifest_ready_repo_count}\n"
    f"- included_file_rows={included_file_rows}\n"
    f"- query_eligible_file_rows={query_eligible_file_rows}\n"
    f"- planned_query_rows={planned_query_rows}\n"
    f"- canary_overlap_file_rows={canary_overlap_file_rows}\n"
    f"- complete_source_content_snapshot_ready=0\n"
    f"- complete_source_query_rows_ready=0\n"
    f"- ah_answer_citation_resource_rows_ready=0\n\n"
    "Still blocked:\n\n"
    "- materialized complete-source file contents and sha256 rows\n"
    "- line-level complete-source span extraction\n"
    "- complete-source 1000+ query rows\n"
    "- A/B/C/D/E/G/H answer/citation/resource rows over complete-source queries\n"
    "- review artifacts and release evidence\n\n"
    "Do not publish v53 safety/grounding superiority, complete-source audit completion, or v1.0 comparison claims from this manifest alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53g-complete-source-manifest",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53g_complete_source_manifest_ready": complete_source_manifest_ready,
    "v53_ready": 0,
    "complete_manifest_repo_count": repo_count,
    "included_file_rows": included_file_rows,
    "query_eligible_file_rows": query_eligible_file_rows,
    "planned_query_rows": planned_query_rows,
    "complete_source_content_snapshot_ready": 0,
    "complete_source_query_rows_ready": 0,
    "ah_answer_citation_resource_rows_ready": 0,
    "v53b_summary_sha256": sha256(results / "v53b_public_repo_10_lock_summary.csv"),
    "v53c_summary_sha256": sha256(results / "v53c_public_repo_canary_source_snapshot_summary.csv"),
    "v53f_summary_sha256": sha256(results / "v53f_ah_answer_citation_resource_intake_summary.csv"),
    "file_manifest_sha256": sha256_text(json.dumps(
        [
            {
                "owner_repo": row["owner_repo"],
                "head_sha": row["head_sha"],
                "path": row["path"],
                "git_blob_sha": row["git_blob_sha"],
                "bytes": row["bytes"],
            }
            for row in file_rows
        ],
        sort_keys=True,
    )),
    "real_release_package_ready": 0,
}
(run_dir / "v53g_complete_source_manifest_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "complete_source_file_manifest_rows.csv",
    "complete_source_repo_coverage_rows.csv",
    "complete_source_query_budget_rows.csv",
    "complete_source_gap_rows.csv",
    "complete_source_fetch_error_rows.csv",
    "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "v53g_complete_source_manifest_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53g_complete_source_manifest_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
