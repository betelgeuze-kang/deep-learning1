#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53d_canary_source_query_seed_100"
RUN_ID="${V53D_RUN_ID:-query_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v53c_public_repo_canary_source_snapshot.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53c_dir = results / "v53c_public_repo_canary_source_snapshot" / "snapshot_001"
v53c_summary = list(csv.DictReader((results / "v53c_public_repo_canary_source_snapshot_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def clean_line(line):
    return re.sub(r"\s+", " ", line.strip())


def classify_source_span(path, evidence, line_no):
    lower = path.lower()
    name = lower.rsplit("/", 1)[-1]
    text = evidence.lower()
    if name in {"pyproject.toml", "setup.cfg", "setup.py", "tox.ini"}:
        if any(token in text for token in ["deprecated", "legacy", "compat", "old", "backward"]):
            return "deprecation_legacy_usage"
        if any(token in text for token in ["dependency", "dependencies", "requires", "python", "version", "classifier"]):
            return "config_mismatch"
        if line_no % 3 == 0:
            return "doc_code_conflict"
        return "config_mismatch"
    if "readme" in name or lower.startswith("docs/"):
        if any(token in text for token in ["example", "usage", "install", "quickstart", "tutorial"]):
            return "examples_tests_alignment"
        if any(token in text for token in ["api", "function", "class", "method", "request", "response"]):
            return "api_behavior"
        if line_no % 4 == 0:
            return "doc_code_conflict"
        return "docs_truthfulness"
    if lower.startswith("tests/"):
        return "examples_tests_alignment"
    if lower.endswith(".py"):
        return "api_behavior"
    return "doc_code_conflict"


def question_for(audit_type, owner_repo, path, line_no, evidence):
    if audit_type == "config_mismatch":
        return f"In {owner_repo}, does the configuration evidence at {path}:{line_no} create a version or metadata mismatch?"
    if audit_type == "docs_truthfulness":
        return f"In {owner_repo}, what claim is supported by the documentation evidence at {path}:{line_no}?"
    if audit_type == "examples_tests_alignment":
        return f"In {owner_repo}, what behavior is exercised by the test/example evidence at {path}:{line_no}?"
    if audit_type == "api_behavior":
        return f"In {owner_repo}, what code behavior is evidenced at {path}:{line_no}?"
    return f"In {owner_repo}, what source fact is supported by {path}:{line_no}?"


def candidate_spans(snapshot_row):
    local_path = v53c_dir / snapshot_row["local_relpath"]
    try:
        text = local_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return []
    rows = []
    for idx, line in enumerate(text.splitlines(), start=1):
        evidence = clean_line(line)
        if len(evidence) < 18:
            continue
        if evidence.startswith(("#", "//", "/*", "*")) and len(evidence) < 28:
            continue
        if len(evidence) > 220:
            evidence = evidence[:220]
        rows.append((idx, evidence))
    return rows


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

snapshot_rows = read_csv(v53c_dir / "public_repo_canary_source_snapshot_rows.csv")
by_repo = {}
for row in snapshot_rows:
    by_repo.setdefault(row["owner_repo"], []).append(row)

query_rows = []
span_rows = []
family_counts = {}
target_per_repo = 10
query_index = 1

for owner_repo in sorted(by_repo):
    repo_candidates = []
    for snapshot in sorted(by_repo[owner_repo], key=lambda row: (row["path"], row["local_relpath"])):
        for line_no, evidence in candidate_spans(snapshot):
            audit_type = classify_source_span(snapshot["path"], evidence, line_no)
            repo_candidates.append((audit_type, snapshot, line_no, evidence))
    if not repo_candidates:
        continue
    selected = []
    cursor = 0
    while len(selected) < target_per_repo:
        selected.append(repo_candidates[cursor % len(repo_candidates)])
        cursor += max(1, len(repo_candidates) // target_per_repo)
        if cursor > len(repo_candidates) * 4 and len(selected) < target_per_repo:
            cursor = len(selected)
    for local_idx, (audit_type, snapshot, line_no, evidence) in enumerate(selected[:target_per_repo], start=1):
        query_id = f"v53d_{query_index:04d}"
        span_id = f"{query_id}_span_001"
        family_counts[audit_type] = family_counts.get(audit_type, 0) + 1
        question = question_for(audit_type, owner_repo, snapshot["path"], line_no, evidence)
        expected_answer = f"Evidence at {snapshot['path']}:{line_no} supports: {evidence}"
        query_rows.append(
            {
                "query_id": query_id,
                "repo_id": snapshot["repo_id"],
                "owner_repo": owner_repo,
                "head_sha": snapshot["head_sha"],
                "audit_type": audit_type,
                "question": question,
                "expected_answer": expected_answer,
                "expected_answer_sha256": sha256_text(expected_answer),
                "source_span_id": span_id,
                "source_path": snapshot["path"],
                "source_line_start": line_no,
                "source_line_end": line_no,
                "source_file_sha256": snapshot["content_sha256"],
                "source_snapshot_scope": "canary",
                "negative_or_abstain": int(audit_type in {"unsupported_claim_abstain", "ambiguous_source_abstain"}),
            }
        )
        span_rows.append(
            {
                "source_span_id": span_id,
                "query_id": query_id,
                "repo_id": snapshot["repo_id"],
                "owner_repo": owner_repo,
                "head_sha": snapshot["head_sha"],
                "path": snapshot["path"],
                "line_start": line_no,
                "line_end": line_no,
                "evidence_text": evidence,
                "evidence_text_sha256": sha256_text(evidence),
                "source_file_sha256": snapshot["content_sha256"],
                "local_relpath": snapshot["local_relpath"],
            }
        )
        query_index += 1

write_csv(run_dir / "canary_query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "canary_source_span_rows.csv", list(span_rows[0].keys()), span_rows)

family_rows = []
target_family_rows = {
    "doc_code_conflict": 140,
    "deprecation_legacy_usage": 140,
    "config_mismatch": 140,
    "api_behavior": 160,
    "docs_truthfulness": 160,
    "examples_tests_alignment": 100,
    "unsupported_claim_abstain": 100,
    "ambiguous_source_abstain": 60,
}
for family, target in target_family_rows.items():
    seed = family_counts.get(family, 0)
    family_rows.append(
        {
            "audit_type": family,
            "target_query_rows": target,
            "v53d_seed_rows": seed,
            "missing_query_rows": max(0, target - seed),
            "status": "seeded" if seed else "missing-family-seed",
        }
    )
write_csv(run_dir / "canary_query_family_rows.csv", list(family_rows[0].keys()), family_rows)

repo_query_counts = {}
for row in query_rows:
    repo_query_counts[row["owner_repo"]] = repo_query_counts.get(row["owner_repo"], 0) + 1
repo_rows = [
    {
        "owner_repo": owner_repo,
        "query_rows": count,
        "target_seed_rows": target_per_repo,
        "status": "seeded" if count >= target_per_repo else "under-seeded",
    }
    for owner_repo, count in sorted(repo_query_counts.items())
]
write_csv(run_dir / "canary_query_repo_rows.csv", list(repo_rows[0].keys()), repo_rows)

query_rows_count = len(query_rows)
source_span_rows = len(span_rows)
repo_count = len(repo_query_counts)
target_query_rows = 1000
missing_query_rows = max(0, target_query_rows - query_rows_count)
v53d_query_seed_ready = int(query_rows_count >= 100 and source_span_rows == query_rows_count and repo_count == 10)

summary = {
    "v53d_canary_query_seed_ready": v53d_query_seed_ready,
    "v53_ready": 0,
    "query_rows": query_rows_count,
    "source_span_rows": source_span_rows,
    "repo_count": repo_count,
    "query_rows_per_repo": target_per_repo,
    "target_query_rows_min": target_query_rows,
    "missing_query_rows": missing_query_rows,
    "family_seed_count": sum(1 for row in family_rows if int(row["v53d_seed_rows"]) > 0),
    "negative_abstain_seed_rows": sum(int(row["v53d_seed_rows"]) for row in family_rows if row["audit_type"] in {"unsupported_claim_abstain", "ambiguous_source_abstain"}),
    "v53c_canary_source_snapshot_ready": int(v53c_summary.get("v53c_canary_source_snapshot_ready", "0")),
    "full_source_snapshot_missing_repo_count": int(v53c_summary.get("full_source_snapshot_missing_repo_count", "0")),
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("canary-query-seed", "pass" if v53d_query_seed_ready else "blocked", f"query_rows={query_rows_count}; repo_count={repo_count}"),
    ("source-span-binding", "pass" if source_span_rows == query_rows_count else "blocked", f"source_span_rows={source_span_rows}"),
    ("v53c-source-input", "pass" if summary["v53c_canary_source_snapshot_ready"] else "blocked", "uses v53c canary source snapshots"),
    ("query-count-target", "blocked", f"need >=1000 query rows; have {query_rows_count}; missing {missing_query_rows}"),
    ("negative-abstain-target", "blocked", "negative/abstain query families are still not seeded from canary source"),
    ("full-source-snapshot-scale", "blocked", f"full snapshots still missing for {summary['full_source_snapshot_missing_repo_count']} repos"),
    ("answer-citation-resource-rows", "blocked", "A-H answer/citation/resource rows are not generated by query seeds"),
    ("v53-full-public-repo-audit", "blocked", "100 canary query seeds are not the full 1000-query audit"),
    ("real-release-package", "blocked", "v53d query seed is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md").write_text(
    "# v53d Canary Source Query Seed Boundary\n\n"
    "This is a 100-row source-span-bound query seed over v53c canary source files, not the completed v53 1000-query audit.\n\n"
    f"- query_rows={query_rows_count}\n"
    f"- source_span_rows={source_span_rows}\n"
    f"- repo_count={repo_count}\n"
    f"- missing_query_rows={missing_query_rows}\n\n"
    "Still blocked:\n\n"
    "- complete source snapshots for all locked repositories\n"
    "- source-span-bound query generation up to at least 1000 rows\n"
    "- negative/abstain query families\n"
    "- answer/citation/resource rows for A-H systems\n"
    "- review artifacts\n\n"
    "Do not publish v53 safety/grounding superiority claims from 100 canary query seeds alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53d-canary-source-query-seed-100",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53d_canary_query_seed_ready": v53d_query_seed_ready,
    "v53_ready": 0,
    "query_rows": query_rows_count,
    "source_span_rows": source_span_rows,
    "repo_count": repo_count,
    "missing_query_rows": missing_query_rows,
    "v53c_summary_sha256": sha256(results / "v53c_public_repo_canary_source_snapshot_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53d_canary_source_query_seed_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "canary_query_rows.csv",
    "canary_source_span_rows.csv",
    "canary_query_family_rows.csv",
    "canary_query_repo_rows.csv",
    "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "v53d_canary_source_query_seed_manifest.json",
    "source_v53c/public_repo_canary_source_snapshot_rows.csv",
    "source_v53c/public_repo_canary_status_rows.csv",
    "source_v53c/public_repo_canary_fetch_error_rows.csv",
    "source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
    "source_v53c/sha256_manifest.csv",
    "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53d_canary_source_query_seed_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
