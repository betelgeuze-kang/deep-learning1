#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53b_public_repo_10_lock"
RUN_ID="${V53B_RUN_ID:-lock_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V50_RUN_DIR="$RESULTS_DIR/v50_public_repo_auditor_3repo/audit_001"
V50_SUMMARY_CSV="$RESULTS_DIR/v50_public_repo_auditor_3repo_summary.csv"
V53B_ALLOW_V50_REFRESH="${V53B_ALLOW_V50_REFRESH:-0}"
V53B_ALLOW_PUBLIC_HEAD_REFRESH="${V53B_ALLOW_PUBLIC_HEAD_REFRESH:-0}"
V50_REFRESH_EXECUTED=0
PUBLIC_HEAD_REFRESH_EXECUTED=0
LOCK_ROWS_SNAPSHOT=""

cleanup() {
  if [ -n "$LOCK_ROWS_SNAPSHOT" ] && [ -f "$LOCK_ROWS_SNAPSHOT" ]; then
    rm -f "$LOCK_ROWS_SNAPSHOT"
  fi
}
trap cleanup EXIT

v50_required_files=(
  "$V50_SUMMARY_CSV"
  "$V50_RUN_DIR/public_repo_source_snapshot_rows.csv"
  "$V50_RUN_DIR/public_repo_audit_case_rows.csv"
  "$V50_RUN_DIR/public_repo_source_span_rows.csv"
  "$V50_RUN_DIR/guard_negative_rows.csv"
  "$V50_RUN_DIR/sha256_manifest.csv"
)

v50_seed_ready=1
for required_file in "${v50_required_files[@]}"; do
  if [ ! -s "$required_file" ]; then
    v50_seed_ready=0
    break
  fi
done

if [ "$v50_seed_ready" != "1" ]; then
  if [ "$V53B_ALLOW_V50_REFRESH" != "1" ]; then
    {
      echo "v53b requires existing v50 public-repo seed artifacts."
      echo "Missing seed evidence is fail-closed by default because v50 refresh performs public git fetches."
      echo "Set V53B_ALLOW_V50_REFRESH=1 only with explicit approval to refresh pinned public sources."
    } >&2
    exit 2
  fi
  "$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null
  V50_REFRESH_EXECUTED=1
fi

for required_file in "${v50_required_files[@]}"; do
  if [ ! -s "$required_file" ]; then
    echo "v53b v50 seed artifact still missing after refresh policy check: $required_file" >&2
    exit 3
  fi
done

if [ "$V53B_ALLOW_PUBLIC_HEAD_REFRESH" = "1" ]; then
  PUBLIC_HEAD_REFRESH_EXECUTED=1
else
  if [ ! -s "$RUN_DIR/public_repo_10_lock_rows.csv" ]; then
    {
      echo "v53b requires existing public_repo_10_lock_rows.csv when public HEAD refresh is disabled."
      echo "Public HEAD resolution uses git ls-remote and is fail-closed by default."
      echo "Set V53B_ALLOW_PUBLIC_HEAD_REFRESH=1 only with explicit approval to refresh public HEAD locks."
    } >&2
    exit 4
  fi
  LOCK_ROWS_SNAPSHOT="$(mktemp)"
  cp "$RUN_DIR/public_repo_10_lock_rows.csv" "$LOCK_ROWS_SNAPSHOT"
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V53B_ALLOW_V50_REFRESH" "$V50_REFRESH_EXECUTED" "$V53B_ALLOW_PUBLIC_HEAD_REFRESH" "$PUBLIC_HEAD_REFRESH_EXECUTED" "${LOCK_ROWS_SNAPSHOT:-}" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
v50_public_refresh_allowed = int(sys.argv[5] == "1")
v50_public_refresh_executed = int(sys.argv[6] == "1")
public_head_refresh_allowed = int(sys.argv[7] == "1")
public_head_refresh_executed = int(sys.argv[8] == "1")
lock_rows_snapshot = Path(sys.argv[9]) if sys.argv[9] else None
v50_seed_reused = int(not v50_public_refresh_executed)
public_head_lock_reused = int(not public_head_refresh_executed)
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
v50_summary = list(csv.DictReader((results / "v50_public_repo_auditor_3repo_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def repo_id(owner_repo):
    return owner_repo.replace("/", "_").replace("-", "_").lower()


def resolve_head(owner_repo):
    url = f"https://github.com/{owner_repo}.git"
    proc = subprocess.run(
        ["git", "ls-remote", "--symref", url, "HEAD"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=60,
    )
    if proc.returncode != 0:
        return {
            "repo_url": f"https://github.com/{owner_repo}",
            "requested_ref": "HEAD",
            "head_sha": "",
            "default_branch": "",
            "resolve_status": "failed",
            "resolve_error": proc.stderr.strip().replace("\n", " ")[:240],
        }
    default_branch = ""
    head_sha = ""
    for line in proc.stdout.splitlines():
        if line.startswith("ref:") and line.endswith("\tHEAD"):
            default_branch = line.split()[1].removeprefix("refs/heads/")
        elif line.endswith("\tHEAD"):
            head_sha = line.split("\t", 1)[0]
    status = "pinned" if re.fullmatch(r"[0-9a-f]{40}", head_sha or "") else "failed"
    return {
        "repo_url": f"https://github.com/{owner_repo}",
        "requested_ref": "HEAD",
        "head_sha": head_sha,
        "default_branch": default_branch,
        "resolve_status": status,
        "resolve_error": "" if status == "pinned" else "HEAD sha missing or invalid",
    }


for rel in [
    "public_repo_source_snapshot_rows.csv",
    "public_repo_audit_case_rows.csv",
    "public_repo_source_span_rows.csv",
    "guard_negative_rows.csv",
    "sha256_manifest.csv",
]:
    copy(v50_dir / rel, f"source_v50/{rel}")
copy(results / "v50_public_repo_auditor_3repo_summary.csv", "source_v50/v50_public_repo_auditor_3repo_summary.csv")

v50_cases = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
v50_repos = {row["owner_repo"] for row in v50_cases}
target_repos = [
    "pypa/sampleproject",
    "psf/requests",
    "pallets/click",
    "pallets/flask",
    "fastapi/fastapi",
    "django/django",
    "pytest-dev/pytest",
    "pypa/pip",
    "python/cpython",
    "tiangolo/typer",
]

if public_head_refresh_executed:
    lock_rows = []
    for idx, owner_repo in enumerate(target_repos, start=1):
        resolved = resolve_head(owner_repo)
        seed_query_rows = sum(1 for row in v50_cases if row["owner_repo"] == owner_repo)
        lock_rows.append(
            {
                "repo_slot": idx,
                "repo_id": repo_id(owner_repo),
                "owner_repo": owner_repo,
                "repo_url": resolved["repo_url"],
                "requested_ref": resolved["requested_ref"],
                "default_branch": resolved["default_branch"],
                "head_sha": resolved["head_sha"],
                "head_sha_ready": int(resolved["resolve_status"] == "pinned"),
                "seed_from_v50": int(owner_repo in v50_repos),
                "seed_query_rows": seed_query_rows,
                "source_snapshot_ready": int(owner_repo in v50_repos),
                "new_snapshot_required": int(owner_repo not in v50_repos),
                "resolve_status": resolved["resolve_status"],
                "resolve_error": resolved["resolve_error"],
            }
        )
else:
    if lock_rows_snapshot is None or not lock_rows_snapshot.is_file():
        raise SystemExit("v53b public HEAD lock snapshot missing while refresh is disabled")
    lock_rows = read_csv(lock_rows_snapshot)
    if [row.get("owner_repo") for row in lock_rows] != target_repos:
        raise SystemExit("v53b cached public HEAD lock rows do not match the target repo order")
    for idx, row in enumerate(lock_rows, start=1):
        owner_repo = target_repos[idx - 1]
        row["repo_slot"] = idx
        row["repo_id"] = repo_id(owner_repo)
        row["seed_from_v50"] = int(owner_repo in v50_repos)
        row["seed_query_rows"] = sum(1 for case in v50_cases if case["owner_repo"] == owner_repo)
        row["source_snapshot_ready"] = int(owner_repo in v50_repos)
        row["new_snapshot_required"] = int(owner_repo not in v50_repos)
        if row.get("resolve_status") != "pinned" or not re.fullmatch(r"[0-9a-f]{40}", row.get("head_sha", "")):
            raise SystemExit(f"v53b cached public HEAD lock is not pinned: {owner_repo}")
write_csv(run_dir / "public_repo_10_lock_rows.csv", list(lock_rows[0].keys()), lock_rows)

query_plan_rows = []
query_families = [
    ("doc_code_conflict", 140),
    ("deprecation_legacy_usage", 140),
    ("config_mismatch", 140),
    ("api_behavior", 160),
    ("docs_truthfulness", 160),
    ("examples_tests_alignment", 100),
    ("unsupported_claim_abstain", 100),
    ("ambiguous_source_abstain", 60),
]
for audit_type, target_rows in query_families:
    seed_rows = 0
    for row in v50_cases:
        normalized = row["audit_type"]
        if normalized == "deprecated_usage":
            normalized = "deprecation_legacy_usage"
        if normalized == audit_type:
            seed_rows += 1
    query_plan_rows.append(
        {
            "audit_type": audit_type,
            "target_query_rows": target_rows,
            "seed_query_rows": seed_rows,
            "missing_query_rows": max(0, target_rows - seed_rows),
            "requires_new_source_snapshot": 1,
            "requires_negative_or_abstain": int(audit_type in {"unsupported_claim_abstain", "ambiguous_source_abstain"}),
            "status": "missing-scale",
        }
    )
write_csv(run_dir / "public_repo_10_query_plan_rows.csv", list(query_plan_rows[0].keys()), query_plan_rows)

locked_repo_count = sum(int(row["head_sha_ready"]) for row in lock_rows)
seed_repo_count = sum(int(row["seed_from_v50"]) for row in lock_rows)
new_locked_repo_count = sum(1 for row in lock_rows if int(row["head_sha_ready"]) and not int(row["seed_from_v50"]))
seed_query_rows = sum(int(row["seed_query_rows"]) for row in lock_rows)
target_query_rows = sum(int(row["target_query_rows"]) for row in query_plan_rows)
missing_query_rows = sum(int(row["missing_query_rows"]) for row in query_plan_rows)
v53b_repo_lock_ready = int(locked_repo_count >= 10)

summary = {
    "v53b_public_repo_10_lock_ready": v53b_repo_lock_ready,
    "v53_ready": 0,
    "target_repo_count_min": 10,
    "locked_repo_count": locked_repo_count,
    "seed_repo_count": seed_repo_count,
    "new_locked_repo_count": new_locked_repo_count,
    "target_query_rows_min": 1000,
    "planned_query_rows": target_query_rows,
    "seed_query_rows": seed_query_rows,
    "missing_query_rows": missing_query_rows,
    "source_snapshot_ready_repo_count": seed_repo_count,
    "source_snapshot_missing_repo_count": max(0, locked_repo_count - seed_repo_count),
    "head_sha_ready_rows": locked_repo_count,
    "failed_head_sha_rows": len(lock_rows) - locked_repo_count,
    "v50_seed_repo_count": int(v50_summary.get("repo_count", "0")),
    "v50_seed_query_rows": int(v50_summary.get("audit_case_rows", "0")),
    "v50_seed_reused": v50_seed_reused,
    "v50_public_refresh_allowed": v50_public_refresh_allowed,
    "v50_public_refresh_executed": v50_public_refresh_executed,
    "public_head_lock_reused": public_head_lock_reused,
    "public_head_refresh_allowed": public_head_refresh_allowed,
    "public_head_refresh_executed": public_head_refresh_executed,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("public-repo-10-lock", "pass" if v53b_repo_lock_ready else "blocked", f"locked_repo_count={locked_repo_count}"),
    ("v50-seed-refresh-policy", "pass", f"seed_reused={v50_seed_reused}; public_refresh_allowed={v50_public_refresh_allowed}; public_refresh_executed={v50_public_refresh_executed}"),
    ("public-head-refresh-policy", "pass", f"lock_reused={public_head_lock_reused}; public_head_refresh_allowed={public_head_refresh_allowed}; public_head_refresh_executed={public_head_refresh_executed}"),
    ("v50-seed-binding", "pass" if seed_repo_count == 3 and seed_query_rows == 9 else "blocked", f"seed_repo_count={seed_repo_count}; seed_query_rows={seed_query_rows}"),
    ("source-snapshot-scale", "blocked", f"source snapshots still missing for {summary['source_snapshot_missing_repo_count']} locked repos"),
    ("query-count-target", "blocked", f"need >=1000 query rows; have seed {seed_query_rows}; missing {missing_query_rows}"),
    ("negative-abstain-target", "blocked", "unsupported/ambiguous abstain rows are planned but not generated"),
    ("v53-full-public-repo-audit", "blocked", "repo locks alone are not source snapshots, query rows, answers, citations, or reviews"),
    ("real-release-package", "blocked", "v53b lock is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md").write_text(
    "# v53b Public Repo 10-Lock Boundary\n\n"
    "This is a live public-repo target lock for the v53 scale run, not the completed 10-repo / 1000-query audit.\n\n"
    f"- locked_repo_count={locked_repo_count}\n"
    f"- seed_repo_count={seed_repo_count}\n"
    f"- new_locked_repo_count={new_locked_repo_count}\n"
    f"- seed_query_rows={seed_query_rows}\n"
    f"- missing_query_rows={missing_query_rows}\n\n"
    "Refresh policy:\n\n"
    f"- v50_seed_reused={v50_seed_reused}\n"
    f"- v50_public_refresh_allowed={v50_public_refresh_allowed}\n"
    f"- v50_public_refresh_executed={v50_public_refresh_executed}\n"
    f"- public_head_lock_reused={public_head_lock_reused}\n"
    f"- public_head_refresh_allowed={public_head_refresh_allowed}\n"
    f"- public_head_refresh_executed={public_head_refresh_executed}\n"
    "- cached v50 seed artifacts and cached public HEAD lock rows are reused by default; public refresh requires explicit approval\n\n"
    "Still blocked:\n\n"
    "- source snapshots for the newly locked repositories\n"
    "- source-span-bound query generation up to at least 1000 rows\n"
    "- answer/citation/resource rows for A-H systems\n"
    "- negative/abstain rows and review artifacts\n\n"
    "Do not publish v53 safety/grounding superiority claims from repo locks alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53b-public-repo-10-lock",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53b_public_repo_10_lock_ready": v53b_repo_lock_ready,
    "v53_ready": 0,
    "locked_repo_count": locked_repo_count,
    "seed_repo_count": seed_repo_count,
    "new_locked_repo_count": new_locked_repo_count,
    "seed_query_rows": seed_query_rows,
    "missing_query_rows": missing_query_rows,
    "v50_seed_reused": v50_seed_reused,
    "v50_public_refresh_allowed": v50_public_refresh_allowed,
    "v50_public_refresh_executed": v50_public_refresh_executed,
    "public_head_lock_reused": public_head_lock_reused,
    "public_head_refresh_allowed": public_head_refresh_allowed,
    "public_head_refresh_executed": public_head_refresh_executed,
    "v50_source_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53b_public_repo_10_lock_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "public_repo_10_lock_rows.csv",
    "public_repo_10_query_plan_rows.csv",
    "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "v53b_public_repo_10_lock_manifest.json",
    "source_v50/public_repo_source_snapshot_rows.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/guard_negative_rows.csv",
    "source_v50/sha256_manifest.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53b_public_repo_10_lock_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
