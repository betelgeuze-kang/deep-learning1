#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53c_public_repo_canary_source_snapshot/snapshot_001"
SUMMARY_CSV="$RESULTS_DIR/v53c_public_repo_canary_source_snapshot_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53c_public_repo_canary_source_snapshot_decision.csv"

"$ROOT_DIR/experiments/run_v53c_public_repo_canary_source_snapshot.sh" >/dev/null

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
    raise SystemExit(f"expected one v53c summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v53c_canary_source_snapshot_ready") == "0":
    if summary.get("v53_ready") != "0" or summary.get("locked_repo_count") != "10":
        raise SystemExit("v53c blocked path should preserve repo-lock and v53 boundary")
    if summary.get("canary_repo_count") != "0" or summary.get("canary_file_rows") != "0":
        raise SystemExit("v53c blocked path should not fabricate canary source rows")
    if int(summary.get("fetch_error_rows", "0")) <= 0:
        raise SystemExit("v53c blocked path should record fetch errors")
    if summary.get("missing_query_rows") != "991" or summary.get("real_release_package_ready") != "0":
        raise SystemExit("v53c blocked path summary mismatch")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    if decisions.get("repo-lock-input") != "pass":
        raise SystemExit("v53c blocked path should keep repo-lock-input pass")
    for gate in [
        "canary-source-snapshot",
        "full-source-snapshot-scale",
        "query-count-target",
        "answer-citation-resource-rows",
        "v53-full-public-repo-audit",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v53c blocked path should keep {gate} blocked")

    required_files = [
        "public_repo_canary_source_snapshot_rows.csv",
        "public_repo_canary_status_rows.csv",
        "public_repo_canary_fetch_error_rows.csv",
        "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
        "v53c_public_repo_canary_source_snapshot_manifest.json",
        "sha256_manifest.csv",
        "source_v53b/public_repo_10_lock_rows.csv",
        "source_v53b/public_repo_10_query_plan_rows.csv",
        "source_v53b/V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
        "source_v53b/v53b_public_repo_10_lock_manifest.json",
        "source_v53b/sha256_manifest.csv",
        "source_v53b/v53b_public_repo_10_lock_summary.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v53c blocked artifact: {rel}")
    status_rows = read_csv(run_dir / "public_repo_canary_status_rows.csv")
    if len(status_rows) != 10 or any(row["canary_source_snapshot_ready"] != "0" for row in status_rows):
        raise SystemExit("v53c blocked path should write ten blocked repo status rows")
    snapshot_rows = read_csv(run_dir / "public_repo_canary_source_snapshot_rows.csv")
    if snapshot_rows:
        raise SystemExit("v53c blocked path should not write canary snapshot rows")
    fetch_rows = read_csv(run_dir / "public_repo_canary_fetch_error_rows.csv")
    if len(fetch_rows) != int(summary["fetch_error_rows"]):
        raise SystemExit("v53c blocked path fetch error count mismatch")
    manifest = json.loads((run_dir / "v53c_public_repo_canary_source_snapshot_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v53c_canary_source_snapshot_ready") != 0 or manifest.get("v53_ready") != 0:
        raise SystemExit("v53c blocked path manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v53c blocked sha256 mismatch: {rel}")
    boundary = (run_dir / "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md").read_text(encoding="utf-8")
    for snippet in ["canary_repo_count=0", "canary_file_rows=0", "missing_query_rows=991", "Do not publish v53 safety/grounding superiority claims"]:
        if snippet not in boundary:
            raise SystemExit(f"v53c blocked boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v53c_canary_source_snapshot_ready": "1",
    "v53_ready": "0",
    "locked_repo_count": "10",
    "canary_repo_count": "10",
    "full_source_snapshot_ready_repo_count": "3",
    "full_source_snapshot_missing_repo_count": "7",
    "seed_query_rows": "9",
    "missing_query_rows": "991",
    "target_query_rows_min": "1000",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53c {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("canary_file_rows", "0")) < 20:
    raise SystemExit("v53c should fetch at least 20 canary source files")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["canary-source-snapshot", "repo-lock-input"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53c gate should pass: {gate}")
for gate in [
    "full-source-snapshot-scale",
    "query-count-target",
    "answer-citation-resource-rows",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53c gate should remain blocked: {gate}")

required_files = [
    "public_repo_canary_source_snapshot_rows.csv",
    "public_repo_canary_status_rows.csv",
    "public_repo_canary_fetch_error_rows.csv",
    "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "v53c_public_repo_canary_source_snapshot_manifest.json",
    "sha256_manifest.csv",
    "source_v53b/public_repo_10_lock_rows.csv",
    "source_v53b/public_repo_10_query_plan_rows.csv",
    "source_v53b/V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "source_v53b/v53b_public_repo_10_lock_manifest.json",
    "source_v53b/sha256_manifest.csv",
    "source_v53b/v53b_public_repo_10_lock_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53c artifact: {rel}")

status_rows = read_csv(run_dir / "public_repo_canary_status_rows.csv")
if len(status_rows) != 10:
    raise SystemExit("v53c should write ten repo status rows")
if any(row["canary_source_snapshot_ready"] != "1" for row in status_rows):
    raise SystemExit("v53c should fetch at least one canary file for every repo")
if sum(1 for row in status_rows if row["full_source_snapshot_ready"] == "1") != 3:
    raise SystemExit("v53c should preserve three v50 full snapshot-ready repos")
if sum(1 for row in status_rows if row["full_source_snapshot_ready"] == "0") != 7:
    raise SystemExit("v53c should keep seven full snapshots missing")

snapshot_rows = read_csv(run_dir / "public_repo_canary_source_snapshot_rows.csv")
if len(snapshot_rows) != int(summary["canary_file_rows"]):
    raise SystemExit("v53c canary file row count mismatch")
if len({row["owner_repo"] for row in snapshot_rows}) != 10:
    raise SystemExit("v53c snapshot rows should cover ten repos")
for row in snapshot_rows:
    if row["snapshot_scope"] != "canary":
        raise SystemExit("v53c snapshot scope should be canary")
    if not re.fullmatch(r"[0-9a-f]{40}", row["head_sha"]):
        raise SystemExit(f"v53c invalid head sha: {row['owner_repo']}")
    if not row["content_sha256"].startswith("sha256:"):
        raise SystemExit(f"v53c missing content sha256: {row['owner_repo']} {row['path']}")
    local_path = run_dir / row["local_relpath"]
    if not local_path.is_file() or local_path.stat().st_size != int(row["bytes"]):
        raise SystemExit(f"v53c local canary file mismatch: {row['local_relpath']}")
    if sha256(local_path) != row["content_sha256"]:
        raise SystemExit(f"v53c content sha mismatch: {row['local_relpath']}")

manifest = json.loads((run_dir / "v53c_public_repo_canary_source_snapshot_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53c_canary_source_snapshot_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53c manifest readiness boundary mismatch")
if manifest.get("canary_repo_count") != 10 or manifest.get("missing_query_rows") != 991:
    raise SystemExit("v53c manifest count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53c sha256 mismatch: {rel}")
for row in snapshot_rows:
    if sha_rows.get(row["local_relpath"]) != row["content_sha256"]:
        raise SystemExit(f"v53c sha manifest missing canary content: {row['local_relpath']}")

boundary = (run_dir / "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "pinned canary source snapshot",
    "canary_repo_count=10",
    "missing_query_rows=991",
    "full source snapshots for all newly locked repositories",
    "Do not publish v53 safety/grounding superiority claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53c boundary missing {snippet}")
PY

echo "v53c public repo canary source snapshot smoke passed"
