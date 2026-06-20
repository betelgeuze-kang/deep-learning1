#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53h_complete_source_content_snapshot"
RUN_ID="${V53H_RUN_ID:-snapshot_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53H_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53h_complete_source_content_snapshot_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v53g_complete_source_manifest_summary.csv" \
  || ! -s "$RESULTS_DIR/v53g_complete_source_manifest/manifest_001/complete_source_file_manifest_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53g_complete_source_manifest.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53g_dir = results / "v53g_complete_source_manifest" / "manifest_001"
git_cache_root = results / "_v53g_git_tree_cache"


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def safe_relpath(repo_id, path):
    posix = PurePosixPath(path)
    if posix.is_absolute() or any(part in {"", ".", ".."} for part in posix.parts):
        raise SystemExit(f"unsafe source path: {path}")
    return Path("content_snapshot") / repo_id / Path(*posix.parts)


def ensure_git_cache(owner_repo, head_sha):
    cache_dir = git_cache_root / owner_repo.replace("/", "__")
    ref = f"refs/v53g/{head_sha}"
    if not cache_dir.exists():
        cache_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "--bare", "-q", str(cache_dir)], check=True, capture_output=True, text=True)
        subprocess.run(
            ["git", "-C", str(cache_dir), "remote", "add", "origin", f"https://github.com/{owner_repo}.git"],
            check=True,
            capture_output=True,
            text=True,
        )
    ref_check = subprocess.run(
        ["git", "-C", str(cache_dir), "rev-parse", "--verify", ref],
        capture_output=True,
        text=True,
    )
    if ref_check.returncode != 0:
        subprocess.run(
            ["git", "-C", str(cache_dir), "fetch", "--depth=1", "origin", f"{head_sha}:{ref}"],
            check=True,
            capture_output=True,
            text=True,
            timeout=180,
        )
    return cache_dir


def batch_read_blobs(cache_dir, rows):
    proc = subprocess.run(
        ["git", "-C", str(cache_dir), "cat-file", "--batch"],
        input=("".join(row["git_blob_sha"] + "\n" for row in rows)).encode("ascii"),
        capture_output=True,
        check=True,
    )
    blobs = {}
    cursor = 0
    for row in rows:
        newline = proc.stdout.find(b"\n", cursor)
        if newline < 0:
            raise SystemExit("git cat-file ended early")
        header = proc.stdout[cursor:newline]
        cursor = newline + 1
        parts = header.decode("utf-8", errors="replace").strip().split()
        if len(parts) != 3 or parts[1] != "blob":
            raise SystemExit(f"unexpected git cat-file header for {row['path']}: {header!r}")
        size = int(parts[2])
        data = proc.stdout[cursor:cursor + size]
        cursor += size
        trailing = proc.stdout[cursor:cursor + 1]
        cursor += 1
        if trailing != b"\n":
            raise SystemExit(f"unexpected git cat-file separator for {row['path']}")
        blobs[row["git_blob_sha"]] = data
    return blobs


v53g_summary = read_csv(results / "v53g_complete_source_manifest_summary.csv")[0]
if v53g_summary.get("v53g_complete_source_manifest_ready") != "1":
    raise SystemExit("v53h requires v53g_complete_source_manifest_ready=1")

for rel in [
    "complete_source_file_manifest_rows.csv",
    "complete_source_repo_coverage_rows.csv",
    "complete_source_query_budget_rows.csv",
    "complete_source_gap_rows.csv",
    "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "v53g_complete_source_manifest_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53g_dir / rel, f"source_v53g/{rel}")
copy(results / "v53g_complete_source_manifest_summary.csv", "source_v53g/v53g_complete_source_manifest_summary.csv")

file_manifest_rows = read_csv(v53g_dir / "complete_source_file_manifest_rows.csv")
repo_manifest_rows = read_csv(v53g_dir / "complete_source_repo_coverage_rows.csv")
rows_by_repo = defaultdict(list)
for row in file_manifest_rows:
    rows_by_repo[row["owner_repo"]].append(row)

content_rows = []
repo_rows = []
content_artifact_rels = []
content_bytes_total = 0
decode_error_rows = 0
category_counts = Counter()

for repo in repo_manifest_rows:
    owner_repo = repo["owner_repo"]
    repo_id = repo["repo_id"]
    head_sha = repo["head_sha"]
    rows = rows_by_repo[owner_repo]
    cache_dir = ensure_git_cache(owner_repo, head_sha)
    blobs = batch_read_blobs(cache_dir, rows)
    repo_content_bytes = 0
    repo_query_eligible = 0
    repo_decode_errors = 0
    for row in rows:
        data = blobs[row["git_blob_sha"]]
        expected_size = int(row["bytes"])
        if len(data) != expected_size:
            raise SystemExit(f"blob size mismatch for {owner_repo}:{row['path']}")
        local_relpath = safe_relpath(repo_id, row["path"])
        dst = run_dir / local_relpath
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
        rel = local_relpath.as_posix()
        content_artifact_rels.append(rel)
        content_sha = sha256_bytes(data)
        text = data.decode("utf-8", errors="replace")
        decode_error = int("\ufffd" in text)
        line_count = 0 if not data else text.count("\n") + (0 if text.endswith("\n") else 1)
        repo_content_bytes += len(data)
        content_bytes_total += len(data)
        repo_query_eligible += int(row["query_eligible"])
        repo_decode_errors += decode_error
        decode_error_rows += decode_error
        category_counts[row["source_category"]] += 1
        content_rows.append(
            {
                "repo_slot": row["repo_slot"],
                "repo_id": repo_id,
                "owner_repo": owner_repo,
                "repo_url": row["repo_url"],
                "head_sha": head_sha,
                "path": row["path"],
                "git_blob_sha": row["git_blob_sha"],
                "bytes": str(len(data)),
                "line_count": str(line_count),
                "content_sha256": content_sha,
                "source_category": row["source_category"],
                "query_eligible": row["query_eligible"],
                "canary_overlap": row["canary_overlap"],
                "local_relpath": rel,
                "utf8_decode_error": str(decode_error),
                "content_materialized": "1",
                "source_snapshot_scope": "complete-content-snapshot",
            }
        )
    repo_rows.append(
        {
            "repo_slot": repo["repo_slot"],
            "repo_id": repo_id,
            "owner_repo": owner_repo,
            "head_sha": head_sha,
            "manifest_file_rows": repo["included_file_rows"],
            "content_materialized_file_rows": str(len(rows)),
            "query_eligible_content_rows": str(repo_query_eligible),
            "content_bytes_materialized": str(repo_content_bytes),
            "utf8_decode_error_rows": str(repo_decode_errors),
            "content_snapshot_ready": "1",
        }
    )

write_csv(run_dir / "complete_source_content_snapshot_rows.csv", list(content_rows[0].keys()), content_rows)
write_csv(run_dir / "complete_source_content_repo_rows.csv", list(repo_rows[0].keys()), repo_rows)

gap_rows = [
    ("complete-source-span-extraction", "blocked", "v53h materializes file contents and hashes; line-level source spans are not emitted as separate query-bound rows"),
    ("complete-source-1000-query-instantiation", "blocked", "v53h is the complete-source content snapshot prerequisite, not the 1000+ query audit"),
    ("a-h-answer-citation-resource-rows", "blocked", "A-H supplied answer/citation/resource rows over complete-source queries are still absent"),
    ("human-review-artifacts", "blocked", "human/source review artifacts are not supplied"),
    ("v53-ready", "blocked", "content snapshot alone is not the completed v53 audit"),
    ("real-release-package", "blocked", "v53h content snapshot is not a release package"),
]
write_csv(
    run_dir / "complete_source_content_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

content_snapshot_ready = int(
    len(repo_rows) >= 10
    and all(row["content_snapshot_ready"] == "1" for row in repo_rows)
    and len(content_rows) == int(v53g_summary["included_file_rows"])
    and content_bytes_total > 0
)
summary = {
    "v53h_complete_source_content_snapshot_ready": str(content_snapshot_ready),
    "v53g_complete_source_manifest_ready": v53g_summary["v53g_complete_source_manifest_ready"],
    "v53_ready": "0",
    "complete_manifest_repo_count": v53g_summary["complete_manifest_repo_count"],
    "content_snapshot_ready_repo_count": str(sum(1 for row in repo_rows if row["content_snapshot_ready"] == "1")),
    "content_materialized_file_rows": str(len(content_rows)),
    "content_sha256_rows": str(len(content_rows)),
    "content_bytes_materialized": str(content_bytes_total),
    "query_eligible_content_rows": str(sum(1 for row in content_rows if row["query_eligible"] == "1")),
    "source_file_rows": str(category_counts.get("source", 0)),
    "doc_file_rows": str(category_counts.get("doc", 0)),
    "config_file_rows": str(category_counts.get("config", 0)),
    "test_file_rows": str(category_counts.get("test", 0)),
    "canary_overlap_file_rows": str(sum(1 for row in content_rows if row["canary_overlap"] == "1")),
    "utf8_decode_error_rows": str(decode_error_rows),
    "complete_source_content_snapshot_ready": str(content_snapshot_ready),
    "complete_source_query_rows_ready": "0",
    "ah_answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53g-complete-source-manifest-input", "pass", "v53g complete-source manifest is bound"),
    ("git-blob-content-materialization", "pass", f"content_materialized_file_rows={len(content_rows)}"),
    ("content-sha256-binding", "pass", f"content_sha256_rows={len(content_rows)}"),
    ("repo-content-coverage", "pass", f"content_snapshot_ready_repo_count={summary['content_snapshot_ready_repo_count']}"),
    ("complete-source-span-extraction", "blocked", "line-level source spans are not emitted in v53h"),
    ("complete-source-1000-query-instantiation", "blocked", "complete-source query rows are still absent"),
    ("supplied-a-h-answer-rows", "blocked", "A-H answer/citation/resource rows are still absent"),
    ("human-review-artifacts", "blocked", "human review artifacts are still absent"),
    ("v53-full-public-repo-audit", "blocked", "content snapshot is a prerequisite, not the completed v53 audit"),
    ("real-release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md").write_text(
    "# v53h Complete Source Content Snapshot Boundary\n\n"
    "This layer materializes the v53g recursive Git tree manifest into file content snapshots and content sha256 rows for the 10 locked repositories. "
    "It is the complete-source content snapshot prerequisite, not the completed v53 audit.\n\n"
    f"- content_snapshot_ready_repo_count={summary['content_snapshot_ready_repo_count']}\n"
    f"- content_materialized_file_rows={len(content_rows)}\n"
    f"- content_sha256_rows={len(content_rows)}\n"
    f"- content_bytes_materialized={content_bytes_total}\n"
    f"- query_eligible_content_rows={summary['query_eligible_content_rows']}\n"
    "- complete_source_query_rows_ready=0\n"
    "- ah_answer_citation_resource_rows_ready=0\n"
    "- review_artifacts_ready=0\n"
    "- v53_ready=0\n\n"
    "Still blocked:\n\n"
    "- line-level complete-source span extraction\n"
    "- complete-source 1000+ query rows\n"
    "- A/B/C/D/E/G/H answer/citation/resource rows over complete-source queries\n"
    "- human/source review artifacts and release evidence\n\n"
    "Do not publish complete-source audit completion, v1.0 comparison, or release claims from this snapshot alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53h-complete-source-content-snapshot",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53h_complete_source_content_snapshot_ready": content_snapshot_ready,
    "v53_ready": 0,
    "content_snapshot_ready_repo_count": int(summary["content_snapshot_ready_repo_count"]),
    "content_materialized_file_rows": len(content_rows),
    "content_bytes_materialized": content_bytes_total,
    "query_eligible_content_rows": int(summary["query_eligible_content_rows"]),
    "complete_source_query_rows_ready": 0,
    "ah_answer_citation_resource_rows_ready": 0,
    "v53g_summary_sha256": sha256(results / "v53g_complete_source_manifest_summary.csv"),
    "content_snapshot_rows_sha256": sha256(run_dir / "complete_source_content_snapshot_rows.csv"),
    "content_snapshot_manifest_sha256": sha256_text(json.dumps(
        [
            {
                "owner_repo": row["owner_repo"],
                "head_sha": row["head_sha"],
                "path": row["path"],
                "git_blob_sha": row["git_blob_sha"],
                "content_sha256": row["content_sha256"],
            }
            for row in content_rows
        ],
        sort_keys=True,
    )),
    "real_release_package_ready": 0,
}
(run_dir / "v53h_complete_source_content_snapshot_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "complete_source_content_snapshot_rows.csv",
    "complete_source_content_repo_rows.csv",
    "complete_source_content_gap_rows.csv",
    "V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md",
    "v53h_complete_source_content_snapshot_manifest.json",
    "source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53g/complete_source_query_budget_rows.csv",
    "source_v53g/complete_source_gap_rows.csv",
    "source_v53g/V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "source_v53g/v53g_complete_source_manifest_manifest.json",
    "source_v53g/sha256_manifest.csv",
    "source_v53g/v53g_complete_source_manifest_summary.csv",
]
artifact_rels.extend(content_artifact_rels)
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53h_complete_source_content_snapshot_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
