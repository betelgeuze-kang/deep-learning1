#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53b_public_repo_10_lock/lock_001"
SUMMARY_CSV="$RESULTS_DIR/v53b_public_repo_10_lock_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53b_public_repo_10_lock_decision.csv"

"$ROOT_DIR/experiments/run_v53b_public_repo_10_lock.sh" >/dev/null

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
    raise SystemExit(f"expected one v53b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53b_public_repo_10_lock_ready": "1",
    "v53_ready": "0",
    "target_repo_count_min": "10",
    "locked_repo_count": "10",
    "seed_repo_count": "3",
    "new_locked_repo_count": "7",
    "target_query_rows_min": "1000",
    "planned_query_rows": "1000",
    "seed_query_rows": "9",
    "missing_query_rows": "991",
    "source_snapshot_ready_repo_count": "3",
    "source_snapshot_missing_repo_count": "7",
    "head_sha_ready_rows": "10",
    "failed_head_sha_rows": "0",
    "v50_seed_repo_count": "3",
    "v50_seed_query_rows": "9",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["public-repo-10-lock", "v50-seed-binding"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53b gate should pass: {gate}")
for gate in [
    "source-snapshot-scale",
    "query-count-target",
    "negative-abstain-target",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53b gate should remain blocked: {gate}")

required_files = [
    "public_repo_10_lock_rows.csv",
    "public_repo_10_query_plan_rows.csv",
    "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md",
    "v53b_public_repo_10_lock_manifest.json",
    "sha256_manifest.csv",
    "source_v50/public_repo_source_snapshot_rows.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/guard_negative_rows.csv",
    "source_v50/sha256_manifest.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53b artifact: {rel}")

lock_rows = read_csv(run_dir / "public_repo_10_lock_rows.csv")
if len(lock_rows) != 10:
    raise SystemExit("v53b should lock exactly ten repo rows")
if sum(1 for row in lock_rows if row["seed_from_v50"] == "1") != 3:
    raise SystemExit("v53b should keep three v50 seed repos")
if sum(1 for row in lock_rows if row["new_snapshot_required"] == "1") != 7:
    raise SystemExit("v53b should mark seven new source snapshots required")
for row in lock_rows:
    if row["head_sha_ready"] != "1" or row["resolve_status"] != "pinned":
        raise SystemExit(f"v53b repo did not pin: {row['owner_repo']}")
    if not re.fullmatch(r"[0-9a-f]{40}", row["head_sha"]):
        raise SystemExit(f"v53b invalid head sha for {row['owner_repo']}: {row['head_sha']}")
    if not row["default_branch"]:
        raise SystemExit(f"v53b missing default branch for {row['owner_repo']}")

query_plan = read_csv(run_dir / "public_repo_10_query_plan_rows.csv")
if sum(int(row["target_query_rows"]) for row in query_plan) != 1000:
    raise SystemExit("v53b query plan should sum to 1000")
if sum(int(row["seed_query_rows"]) for row in query_plan) != 9:
    raise SystemExit("v53b query plan seed rows should sum to 9")
if sum(int(row["missing_query_rows"]) for row in query_plan) != 991:
    raise SystemExit("v53b query plan missing rows should sum to 991")
if sum(int(row["requires_negative_or_abstain"]) for row in query_plan) < 2:
    raise SystemExit("v53b should plan negative/abstain query families")

manifest = json.loads((run_dir / "v53b_public_repo_10_lock_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53b_public_repo_10_lock_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53b manifest readiness boundary mismatch")
if manifest.get("locked_repo_count") != 10 or manifest.get("missing_query_rows") != 991:
    raise SystemExit("v53b manifest count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53b sha256 mismatch: {rel}")

boundary = (run_dir / "V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "live public-repo target lock",
    "locked_repo_count=10",
    "missing_query_rows=991",
    "source snapshots for the newly locked repositories",
    "Do not publish v53 safety/grounding superiority claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53b boundary missing {snippet}")
PY

echo "v53b public repo 10-lock smoke passed"
