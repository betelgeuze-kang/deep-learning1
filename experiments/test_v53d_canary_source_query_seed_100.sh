#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53d_canary_source_query_seed_100/query_001"
SUMMARY_CSV="$RESULTS_DIR/v53d_canary_source_query_seed_100_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53d_canary_source_query_seed_100_decision.csv"

"$ROOT_DIR/experiments/run_v53d_canary_source_query_seed_100.sh" >/dev/null

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


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v53d summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v53d_canary_query_seed_ready") == "0":
    expected_blocked = {
        "v53_ready": "0",
        "query_rows": "0",
        "source_span_rows": "0",
        "repo_count": "0",
        "query_rows_per_repo": "10",
        "target_query_rows_min": "1000",
        "missing_query_rows": "1000",
        "v53c_canary_source_snapshot_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v53d blocked {field}: expected {value}, got {summary.get(field)}")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in [
        "canary-query-seed",
        "source-span-binding",
        "v53c-source-input",
        "query-count-target",
        "negative-abstain-target",
        "full-source-snapshot-scale",
        "answer-citation-resource-rows",
        "v53-full-public-repo-audit",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v53d blocked path should keep {gate} blocked")

    required_files = [
        "canary_query_rows.csv",
        "canary_source_span_rows.csv",
        "canary_query_family_rows.csv",
        "canary_query_repo_rows.csv",
        "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
        "v53d_canary_source_query_seed_manifest.json",
        "sha256_manifest.csv",
        "source_v53c/public_repo_canary_source_snapshot_rows.csv",
        "source_v53c/public_repo_canary_status_rows.csv",
        "source_v53c/public_repo_canary_fetch_error_rows.csv",
        "source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
        "source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
        "source_v53c/sha256_manifest.csv",
        "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v53d blocked artifact: {rel}")
    if read_csv(run_dir / "canary_query_rows.csv") or read_csv(run_dir / "canary_source_span_rows.csv"):
        raise SystemExit("v53d blocked path should not fabricate query/span rows")
    if read_csv(run_dir / "canary_query_repo_rows.csv"):
        raise SystemExit("v53d blocked path should not fabricate repo query rows")
    family_rows = read_csv(run_dir / "canary_query_family_rows.csv")
    if len(family_rows) != 8 or any(row["v53d_seed_rows"] != "0" for row in family_rows):
        raise SystemExit("v53d blocked path should write eight zero seed family rows")
    manifest = json.loads((run_dir / "v53d_canary_source_query_seed_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v53d_canary_query_seed_ready") != 0 or manifest.get("query_rows") != 0:
        raise SystemExit("v53d blocked manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v53d blocked sha256 mismatch: {rel}")
    boundary = (run_dir / "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md").read_text(encoding="utf-8")
    for snippet in ["query_rows=0", "source_span_rows=0", "repo_count=0", "missing_query_rows=1000"]:
        if snippet not in boundary:
            raise SystemExit(f"v53d blocked boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v53d_canary_query_seed_ready": "1",
    "v53_ready": "0",
    "query_rows": "100",
    "source_span_rows": "100",
    "repo_count": "10",
    "query_rows_per_repo": "10",
    "target_query_rows_min": "1000",
    "missing_query_rows": "900",
    "v53c_canary_source_snapshot_ready": "1",
    "full_source_snapshot_missing_repo_count": "7",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53d {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("family_seed_count", "0")) < 4:
    raise SystemExit("v53d should seed at least four query families")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["canary-query-seed", "source-span-binding", "v53c-source-input"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53d gate should pass: {gate}")
for gate in [
    "query-count-target",
    "negative-abstain-target",
    "full-source-snapshot-scale",
    "answer-citation-resource-rows",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53d gate should remain blocked: {gate}")

required_files = [
    "canary_query_rows.csv",
    "canary_source_span_rows.csv",
    "canary_query_family_rows.csv",
    "canary_query_repo_rows.csv",
    "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "v53d_canary_source_query_seed_manifest.json",
    "sha256_manifest.csv",
    "source_v53c/public_repo_canary_source_snapshot_rows.csv",
    "source_v53c/public_repo_canary_status_rows.csv",
    "source_v53c/public_repo_canary_fetch_error_rows.csv",
    "source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
    "source_v53c/sha256_manifest.csv",
    "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53d artifact: {rel}")

queries = read_csv(run_dir / "canary_query_rows.csv")
spans = read_csv(run_dir / "canary_source_span_rows.csv")
if len(queries) != 100 or len(spans) != 100:
    raise SystemExit("v53d should write 100 query rows and 100 source span rows")
if len({row["query_id"] for row in queries}) != 100:
    raise SystemExit("v53d query IDs should be unique")
if {row["source_span_id"] for row in queries} != {row["source_span_id"] for row in spans}:
    raise SystemExit("v53d query/source span IDs should match")
if len({row["owner_repo"] for row in queries}) != 10:
    raise SystemExit("v53d query rows should cover ten repos")
if any(row["source_snapshot_scope"] != "canary" for row in queries):
    raise SystemExit("v53d query rows should bind to canary scope")
if any(not re.fullmatch(r"[0-9a-f]{40}", row["head_sha"]) for row in queries):
    raise SystemExit("v53d query rows should bind to pinned HEAD SHA")

repo_rows = read_csv(run_dir / "canary_query_repo_rows.csv")
if len(repo_rows) != 10 or any(row["query_rows"] != "10" for row in repo_rows):
    raise SystemExit("v53d should seed ten query rows per repo")

snapshot_rows = read_csv(run_dir / "source_v53c/public_repo_canary_source_snapshot_rows.csv")
snapshot_hashes = {(row["owner_repo"], row["path"], row["content_sha256"]) for row in snapshot_rows}
span_by_id = {row["source_span_id"]: row for row in spans}
for query in queries:
    span = span_by_id[query["source_span_id"]]
    if query["query_id"] != span["query_id"]:
        raise SystemExit("v53d span/query ID mismatch")
    if query["owner_repo"] != span["owner_repo"] or query["source_path"] != span["path"]:
        raise SystemExit("v53d query/span source mismatch")
    if query["source_file_sha256"] != span["source_file_sha256"]:
        raise SystemExit("v53d query/span file hash mismatch")
    if (span["owner_repo"], span["path"], span["source_file_sha256"]) not in snapshot_hashes:
        raise SystemExit("v53d span does not bind to v53c canary snapshot")
    if query["expected_answer_sha256"] != sha256_text(query["expected_answer"]):
        raise SystemExit("v53d expected answer hash mismatch")
    if span["evidence_text_sha256"] != sha256_text(span["evidence_text"]):
        raise SystemExit("v53d evidence text hash mismatch")

family_rows = read_csv(run_dir / "canary_query_family_rows.csv")
if sum(int(row["v53d_seed_rows"]) for row in family_rows) != 100:
    raise SystemExit("v53d family rows should sum to 100")
if sum(int(row["missing_query_rows"]) for row in family_rows) != 900:
    raise SystemExit("v53d family missing rows should sum to 900")
if not any(row["status"] == "missing-family-seed" for row in family_rows):
    raise SystemExit("v53d should keep at least one family missing to preserve stop rule")

manifest = json.loads((run_dir / "v53d_canary_source_query_seed_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53d_canary_query_seed_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53d manifest readiness boundary mismatch")
if manifest.get("query_rows") != 100 or manifest.get("missing_query_rows") != 900:
    raise SystemExit("v53d manifest count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53d sha256 mismatch: {rel}")

boundary = (run_dir / "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "100-row source-span-bound query seed",
    "query_rows=100",
    "missing_query_rows=900",
    "negative/abstain query families",
    "Do not publish v53 safety/grounding superiority claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53d boundary missing {snippet}")
PY

echo "v53d canary source query seed smoke passed"
