#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53e_canary_query_scale_1000/scale_001"
SUMMARY_CSV="$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53e_canary_query_scale_1000_decision.csv"

"$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh" >/dev/null

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

TARGET_FAMILY_ROWS = {
    "doc_code_conflict": 140,
    "deprecation_legacy_usage": 140,
    "config_mismatch": 140,
    "api_behavior": 160,
    "docs_truthfulness": 160,
    "examples_tests_alignment": 100,
    "unsupported_claim_abstain": 100,
    "ambiguous_source_abstain": 60,
}
NEGATIVE_FAMILIES = {"unsupported_claim_abstain", "ambiguous_source_abstain"}


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
    raise SystemExit(f"expected one v53e summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v53e_canary_query_scale_ready") == "0":
    expected_blocked = {
        "v53_ready": "0",
        "query_rows": "0",
        "source_span_rows": "0",
        "supported_source_span_bound_rows": "0",
        "negative_abstain_rows": "0",
        "repo_count": "0",
        "family_count": "0",
        "target_query_rows_min": "1000",
        "missing_query_rows": "1000",
        "v53d_canary_query_seed_ready": "0",
        "answer_citation_resource_rows_ready": "0",
        "review_artifacts_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v53e blocked {field}: expected {value}, got {summary.get(field)}")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in [
        "canary-query-scale",
        "query-count-target",
        "source-span-binding",
        "negative-abstain-target",
        "v53d-query-seed-input",
        "full-source-snapshot-scale",
        "answer-citation-resource-rows",
        "human-review-artifacts",
        "v53-full-public-repo-audit",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v53e blocked path should keep {gate} blocked")

    required_files = [
        "scaled_canary_query_rows.csv",
        "scaled_canary_source_span_rows.csv",
        "scaled_canary_query_family_rows.csv",
        "scaled_canary_query_repo_rows.csv",
        "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
        "v53e_canary_query_scale_1000_manifest.json",
        "sha256_manifest.csv",
        "source_v53d/canary_query_rows.csv",
        "source_v53d/canary_source_span_rows.csv",
        "source_v53d/canary_query_family_rows.csv",
        "source_v53d/canary_query_repo_rows.csv",
        "source_v53d/V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
        "source_v53d/v53d_canary_source_query_seed_manifest.json",
        "source_v53d/sha256_manifest.csv",
        "source_v53d/v53d_canary_source_query_seed_100_summary.csv",
        "source_v53d/source_v53c/public_repo_canary_source_snapshot_rows.csv",
        "source_v53d/source_v53c/public_repo_canary_status_rows.csv",
        "source_v53d/source_v53c/public_repo_canary_fetch_error_rows.csv",
        "source_v53d/source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
        "source_v53d/source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
        "source_v53d/source_v53c/sha256_manifest.csv",
        "source_v53d/source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v53e blocked artifact: {rel}")
    if read_csv(run_dir / "scaled_canary_query_rows.csv") or read_csv(run_dir / "scaled_canary_source_span_rows.csv"):
        raise SystemExit("v53e blocked path should not fabricate scaled query/span rows")
    if read_csv(run_dir / "scaled_canary_query_repo_rows.csv"):
        raise SystemExit("v53e blocked path should not fabricate repo rows")
    family_rows = read_csv(run_dir / "scaled_canary_query_family_rows.csv")
    if len(family_rows) != 8 or any(row["scaled_query_rows"] != "0" for row in family_rows):
        raise SystemExit("v53e blocked path should write eight zero scaled family rows")
    manifest = json.loads((run_dir / "v53e_canary_query_scale_1000_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v53e_canary_query_scale_ready") != 0 or manifest.get("query_rows") != 0:
        raise SystemExit("v53e blocked manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v53e blocked sha256 mismatch: {rel}")
    boundary = (run_dir / "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md").read_text(encoding="utf-8")
    for snippet in ["query_rows=0", "source_span_rows=0", "negative_abstain_rows=0", "missing_query_rows=1000"]:
        if snippet not in boundary:
            raise SystemExit(f"v53e blocked boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v53e_canary_query_scale_ready": "1",
    "v53_ready": "0",
    "query_rows": "1000",
    "source_span_rows": "1000",
    "supported_source_span_bound_rows": "840",
    "negative_abstain_rows": "160",
    "repo_count": "10",
    "family_count": "8",
    "target_query_rows_min": "1000",
    "missing_query_rows": "0",
    "v53d_canary_query_seed_ready": "1",
    "full_source_snapshot_missing_repo_count": "7",
    "answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53e {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "canary-query-scale",
    "query-count-target",
    "source-span-binding",
    "negative-abstain-target",
    "v53d-query-seed-input",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53e gate should pass: {gate}")
for gate in [
    "full-source-snapshot-scale",
    "answer-citation-resource-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53e gate should remain blocked: {gate}")

required_files = [
    "scaled_canary_query_rows.csv",
    "scaled_canary_source_span_rows.csv",
    "scaled_canary_query_family_rows.csv",
    "scaled_canary_query_repo_rows.csv",
    "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "v53e_canary_query_scale_1000_manifest.json",
    "sha256_manifest.csv",
    "source_v53d/canary_query_rows.csv",
    "source_v53d/canary_source_span_rows.csv",
    "source_v53d/canary_query_family_rows.csv",
    "source_v53d/canary_query_repo_rows.csv",
    "source_v53d/V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "source_v53d/v53d_canary_source_query_seed_manifest.json",
    "source_v53d/sha256_manifest.csv",
    "source_v53d/v53d_canary_source_query_seed_100_summary.csv",
    "source_v53d/source_v53c/public_repo_canary_source_snapshot_rows.csv",
    "source_v53d/source_v53c/public_repo_canary_status_rows.csv",
    "source_v53d/source_v53c/public_repo_canary_fetch_error_rows.csv",
    "source_v53d/source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "source_v53d/source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
    "source_v53d/source_v53c/sha256_manifest.csv",
    "source_v53d/source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53e artifact: {rel}")

queries = read_csv(run_dir / "scaled_canary_query_rows.csv")
spans = read_csv(run_dir / "scaled_canary_source_span_rows.csv")
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53e should write 1000 query rows and 1000 source span rows")
if len({row["query_id"] for row in queries}) != 1000:
    raise SystemExit("v53e query IDs should be unique")
if {row["source_span_id"] for row in queries} != {row["source_span_id"] for row in spans}:
    raise SystemExit("v53e query/source span IDs should match")
if len({row["owner_repo"] for row in queries}) != 10:
    raise SystemExit("v53e query rows should cover ten repos")
if set(row["audit_type"] for row in queries) != set(TARGET_FAMILY_ROWS):
    raise SystemExit("v53e should cover all target query families")
if any(row["source_snapshot_scope"] != "canary" for row in queries):
    raise SystemExit("v53e query rows should bind to canary scope")
if any(row["scale_scope"] != "v53e-canary-1000" for row in queries):
    raise SystemExit("v53e scale scope mismatch")
if any(row["source_span_required"] != "1" for row in queries):
    raise SystemExit("v53e should require a source span for every query")
if any(not re.fullmatch(r"[0-9a-f]{40}", row["head_sha"]) for row in queries):
    raise SystemExit("v53e query rows should bind to pinned HEAD SHA")

family_rows = read_csv(run_dir / "scaled_canary_query_family_rows.csv")
if len(family_rows) != 8:
    raise SystemExit("v53e should write eight family rows")
for row in family_rows:
    family = row["audit_type"]
    if int(row["target_query_rows"]) != TARGET_FAMILY_ROWS[family]:
        raise SystemExit(f"v53e family target mismatch: {family}")
    if int(row["scaled_query_rows"]) != TARGET_FAMILY_ROWS[family]:
        raise SystemExit(f"v53e family scaled count mismatch: {family}")
    if row["status"] != "scaled":
        raise SystemExit(f"v53e family should be scaled: {family}")
    if row["negative_or_abstain_family"] != str(int(family in NEGATIVE_FAMILIES)):
        raise SystemExit(f"v53e family negative flag mismatch: {family}")
if sum(int(row["scaled_query_rows"]) for row in family_rows) != 1000:
    raise SystemExit("v53e family rows should sum to 1000")

negative = [row for row in queries if row["negative_or_abstain"] == "1"]
supported = [row for row in queries if row["negative_or_abstain"] == "0"]
if len(negative) != 160 or len(supported) != 840:
    raise SystemExit("v53e negative/supported split mismatch")
if any(row["expected_behavior"] != "abstain" or not row["expected_answer"].startswith("ABSTAIN:") for row in negative):
    raise SystemExit("v53e negative rows should require abstention")
if any(row["expected_behavior"] != "answer-with-citation" for row in supported):
    raise SystemExit("v53e supported rows should expect cited answers")

repo_rows = read_csv(run_dir / "scaled_canary_query_repo_rows.csv")
if len(repo_rows) != 10 or any(int(row["scaled_query_rows"]) <= 0 for row in repo_rows):
    raise SystemExit("v53e should cover all ten repos")

seed_queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53d/canary_query_rows.csv")}
seed_spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53d/canary_source_span_rows.csv")}
span_by_id = {row["source_span_id"]: row for row in spans}
for query in queries:
    if query["parent_query_id"] not in seed_queries:
        raise SystemExit("v53e query parent does not bind to v53d seed")
    if query["parent_source_span_id"] not in seed_spans:
        raise SystemExit("v53e query parent span does not bind to v53d seed")
    span = span_by_id[query["source_span_id"]]
    parent = seed_spans[query["parent_source_span_id"]]
    if query["query_id"] != span["query_id"]:
        raise SystemExit("v53e span/query ID mismatch")
    if query["owner_repo"] != span["owner_repo"] or query["source_path"] != span["path"]:
        raise SystemExit("v53e query/span source mismatch")
    if query["source_file_sha256"] != span["source_file_sha256"]:
        raise SystemExit("v53e query/span file hash mismatch")
    if span["parent_source_span_id"] != parent["source_span_id"]:
        raise SystemExit("v53e span parent mismatch")
    if span["evidence_text_sha256"] != parent["evidence_text_sha256"]:
        raise SystemExit("v53e parent evidence hash mismatch")
    if query["expected_answer_sha256"] != sha256_text(query["expected_answer"]):
        raise SystemExit("v53e expected answer hash mismatch")

manifest = json.loads((run_dir / "v53e_canary_query_scale_1000_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53e_canary_query_scale_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53e manifest readiness boundary mismatch")
if manifest.get("query_rows") != 1000 or manifest.get("negative_abstain_rows") != 160:
    raise SystemExit("v53e manifest count mismatch")
if manifest.get("target_family_rows") != TARGET_FAMILY_ROWS:
    raise SystemExit("v53e manifest family target mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53e sha256 mismatch: {rel}")

boundary = (run_dir / "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000 source-span-bound query rows",
    "query_rows=1000",
    "negative_abstain_rows=160",
    "not the completed v53 public-repo code/doc audit",
    "Do not publish v53 safety/grounding superiority claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53e boundary missing {snippet}")
PY

echo "v53e canary query scale 1000 smoke passed"
