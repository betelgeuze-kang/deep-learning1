#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53c_public_repo_canary_source_snapshot"
RUN_ID="${V53C_RUN_ID:-snapshot_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v53b_public_repo_10_lock.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53b_dir = results / "v53b_public_repo_10_lock" / "lock_001"
v53b_summary = list(csv.DictReader((results / "v53b_public_repo_10_lock_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def write_csv(path, fieldnames, rows):
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
    return dst


def fetch_json(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "v53c-canary-source-snapshot"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_bytes(url):
    req = urllib.request.Request(url, headers={"User-Agent": "v53c-canary-source-snapshot"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read()


def safe_rel(owner_repo, path):
    safe_repo = owner_repo.replace("/", "__").replace("-", "_")
    safe_path = path.replace("..", "__").lstrip("/")
    return f"source_canary/{safe_repo}/{safe_path}"


def score_path(path):
    lower = path.lower()
    basename = lower.rsplit("/", 1)[-1]
    if basename in {"pyproject.toml", "setup.cfg", "setup.py", "tox.ini"}:
        return (0, path)
    if basename in {"readme.md", "readme.rst", "readme.txt"}:
        return (1, path)
    if lower.startswith("docs/") and basename in {"index.md", "index.rst", "installation.rst", "quickstart.md", "quickstart.rst"}:
        return (2, path)
    if lower.startswith("tests/") and lower.endswith(".py"):
        return (3, path)
    if lower.endswith(".py") and "/" not in lower:
        return (4, path)
    return (9, path)


def select_canary_files(tree):
    candidates = []
    for item in tree:
        if item.get("type") != "blob":
            continue
        path = item.get("path", "")
        size = int(item.get("size") or 0)
        lower = path.lower()
        basename = lower.rsplit("/", 1)[-1]
        useful = (
            basename in {"pyproject.toml", "setup.cfg", "setup.py", "tox.ini", "readme.md", "readme.rst", "readme.txt"}
            or (lower.startswith("docs/") and lower.endswith((".md", ".rst")))
            or (lower.startswith("tests/") and lower.endswith(".py"))
            or ("/" not in lower and lower.endswith(".py"))
        )
        if useful and 0 < size <= 200_000:
            candidates.append(item)
    selected = []
    seen_kinds = set()
    for item in sorted(candidates, key=lambda row: score_path(row["path"])):
        rank = score_path(item["path"])[0]
        if rank not in seen_kinds or len(selected) < 2:
            selected.append(item)
            seen_kinds.add(rank)
        if len(selected) >= 3:
            break
    return selected


fallback_paths = {
    "pypa/sampleproject": ["pyproject.toml", "README.md", "tests/test_simple.py"],
    "psf/requests": ["pyproject.toml", "README.md", "docs/user/quickstart.md"],
    "pallets/click": ["pyproject.toml", "README.md", "docs/index.rst"],
    "pallets/flask": ["pyproject.toml", "README.md", "docs/index.rst"],
    "fastapi/fastapi": ["pyproject.toml", "README.md", "docs/en/docs/index.md"],
    "django/django": ["README.rst", "pyproject.toml", "docs/intro/tutorial01.txt"],
    "pytest-dev/pytest": ["pyproject.toml", "README.rst", "doc/en/index.rst"],
    "pypa/pip": ["pyproject.toml", "README.rst", "docs/html/index.rst"],
    "python/cpython": ["README.rst", "Doc/README.rst", "Lib/test/test_sys.py"],
    "tiangolo/typer": ["pyproject.toml", "README.md", "docs/index.md"],
}


def fallback_items(owner_repo):
    return [{"path": path, "sha": "", "size": 0} for path in fallback_paths.get(owner_repo, [])]


for rel in [
    "public_repo_10_lock_rows.csv",
    "public_repo_10_query_plan_rows.csv",
    "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "v53b_public_repo_10_lock_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53b_dir / rel, f"source_v53b/{rel}")
copy(results / "v53b_public_repo_10_lock_summary.csv", "source_v53b/v53b_public_repo_10_lock_summary.csv")

lock_rows = read_csv(v53b_dir / "public_repo_10_lock_rows.csv")
snapshot_rows = []
repo_status_rows = []
fetch_error_rows = []

for repo in lock_rows:
    owner_repo = repo["owner_repo"]
    head_sha = repo["head_sha"]
    tree_url = f"https://api.github.com/repos/{owner_repo}/git/trees/{head_sha}?recursive=1"
    try:
        tree_payload = fetch_json(tree_url)
        tree = tree_payload.get("tree", [])
        selected = select_canary_files(tree)
    except Exception as exc:
        selected = fallback_items(owner_repo)
        fetch_error_rows.append({"owner_repo": owner_repo, "stage": "tree", "reason": str(exc)[:240]})
    else:
        if len(selected) < 3:
            seen_paths = {item["path"] for item in selected}
            selected.extend(item for item in fallback_items(owner_repo) if item["path"] not in seen_paths)
            selected = selected[:3]
    fetched = 0
    for item in selected:
        path = item["path"]
        raw_url = f"https://raw.githubusercontent.com/{owner_repo}/{head_sha}/{path}"
        try:
            data = fetch_bytes(raw_url)
        except Exception as exc:
            fetch_error_rows.append({"owner_repo": owner_repo, "stage": f"raw:{path}", "reason": str(exc)[:240]})
            continue
        rel = safe_rel(owner_repo, path)
        dst = run_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
        line_count = data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)
        snapshot_rows.append(
            {
                "repo_slot": repo["repo_slot"],
                "repo_id": repo["repo_id"],
                "owner_repo": owner_repo,
                "repo_url": repo["repo_url"],
                "head_sha": head_sha,
                "default_branch": repo["default_branch"],
                "path": path,
                "git_blob_sha": item.get("sha", ""),
                "bytes": len(data),
                "line_count": line_count,
                "content_sha256": sha256_bytes(data),
                "raw_url": raw_url,
                "local_relpath": rel,
                "snapshot_scope": "canary",
            }
        )
        fetched += 1
    repo_status_rows.append(
        {
            "repo_slot": repo["repo_slot"],
            "repo_id": repo["repo_id"],
            "owner_repo": owner_repo,
            "head_sha": head_sha,
            "canary_source_snapshot_ready": int(fetched > 0),
            "canary_file_rows": fetched,
            "full_source_snapshot_ready": int(repo["seed_from_v50"] == "1"),
            "full_source_snapshot_blocking_reason": "" if repo["seed_from_v50"] == "1" else "full-source-snapshot-not-yet-acquired",
        }
    )

if snapshot_rows:
    write_csv(run_dir / "public_repo_canary_source_snapshot_rows.csv", list(snapshot_rows[0].keys()), snapshot_rows)
else:
    write_csv(
        run_dir / "public_repo_canary_source_snapshot_rows.csv",
        ["repo_slot", "repo_id", "owner_repo", "repo_url", "head_sha", "default_branch", "path", "git_blob_sha", "bytes", "line_count", "content_sha256", "raw_url", "local_relpath", "snapshot_scope"],
        [],
    )
write_csv(run_dir / "public_repo_canary_status_rows.csv", list(repo_status_rows[0].keys()), repo_status_rows)
write_csv(run_dir / "public_repo_canary_fetch_error_rows.csv", ["owner_repo", "stage", "reason"], fetch_error_rows)

canary_repo_count = sum(1 for row in repo_status_rows if int(row["canary_source_snapshot_ready"]))
canary_file_rows = len(snapshot_rows)
full_snapshot_ready_repo_count = sum(1 for row in repo_status_rows if int(row["full_source_snapshot_ready"]))
full_snapshot_missing_repo_count = len(repo_status_rows) - full_snapshot_ready_repo_count
v53c_canary_source_snapshot_ready = int(canary_repo_count >= 10 and canary_file_rows >= 20)

summary = {
    "v53c_canary_source_snapshot_ready": v53c_canary_source_snapshot_ready,
    "v53_ready": 0,
    "locked_repo_count": int(v53b_summary.get("locked_repo_count", "0")),
    "canary_repo_count": canary_repo_count,
    "canary_file_rows": canary_file_rows,
    "fetch_error_rows": len(fetch_error_rows),
    "full_source_snapshot_ready_repo_count": full_snapshot_ready_repo_count,
    "full_source_snapshot_missing_repo_count": full_snapshot_missing_repo_count,
    "seed_query_rows": int(v53b_summary.get("seed_query_rows", "0")),
    "missing_query_rows": int(v53b_summary.get("missing_query_rows", "0")),
    "target_query_rows_min": 1000,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("canary-source-snapshot", "pass" if v53c_canary_source_snapshot_ready else "blocked", f"canary_repo_count={canary_repo_count}; canary_file_rows={canary_file_rows}; fetch_errors={len(fetch_error_rows)}"),
    ("repo-lock-input", "pass" if int(v53b_summary.get("v53b_public_repo_10_lock_ready", "0")) else "blocked", "uses v53b 10-repo lock"),
    ("full-source-snapshot-scale", "blocked", f"full snapshots still missing for {full_snapshot_missing_repo_count} repos"),
    ("query-count-target", "blocked", f"need >=1000 query rows; missing {summary['missing_query_rows']}"),
    ("answer-citation-resource-rows", "blocked", "A-H answer/citation/resource rows are not generated by canary snapshots"),
    ("v53-full-public-repo-audit", "blocked", "canary snapshots are not the full 10-repo / 1000-query audit"),
    ("real-release-package", "blocked", "v53c canary snapshot is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md").write_text(
    "# v53c Public Repo Canary Source Snapshot Boundary\n\n"
    "This is a pinned canary source snapshot over the v53b 10-repo lock, not the completed v53 source corpus.\n\n"
    f"- canary_repo_count={canary_repo_count}\n"
    f"- canary_file_rows={canary_file_rows}\n"
    f"- full_source_snapshot_missing_repo_count={full_snapshot_missing_repo_count}\n"
    f"- missing_query_rows={summary['missing_query_rows']}\n\n"
    "Still blocked:\n\n"
    "- full source snapshots for all newly locked repositories\n"
    "- source-span-bound query generation up to at least 1000 rows\n"
    "- answer/citation/resource rows for A-H systems\n"
    "- negative/abstain rows and review artifacts\n\n"
    "Do not publish v53 safety/grounding superiority claims from canary snapshots alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53c-public-repo-canary-source-snapshot",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53c_canary_source_snapshot_ready": v53c_canary_source_snapshot_ready,
    "v53_ready": 0,
    "canary_repo_count": canary_repo_count,
    "canary_file_rows": canary_file_rows,
    "full_source_snapshot_missing_repo_count": full_snapshot_missing_repo_count,
    "missing_query_rows": summary["missing_query_rows"],
    "v53b_summary_sha256": sha256(results / "v53b_public_repo_10_lock_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53c_public_repo_canary_source_snapshot_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "public_repo_canary_source_snapshot_rows.csv",
    "public_repo_canary_status_rows.csv",
    "public_repo_canary_fetch_error_rows.csv",
    "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "v53c_public_repo_canary_source_snapshot_manifest.json",
    "source_v53b/public_repo_10_lock_rows.csv",
    "source_v53b/public_repo_10_query_plan_rows.csv",
    "source_v53b/V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "source_v53b/v53b_public_repo_10_lock_manifest.json",
    "source_v53b/sha256_manifest.csv",
    "source_v53b/v53b_public_repo_10_lock_summary.csv",
]
artifact_rels.extend(row["local_relpath"] for row in snapshot_rows)
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53c_public_repo_canary_source_snapshot_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
