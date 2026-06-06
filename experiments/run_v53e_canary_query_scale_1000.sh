#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53e_canary_query_scale_1000"
RUN_ID="${V53E_RUN_ID:-scale_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v53d_canary_source_query_seed_100.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53d_dir = results / "v53d_canary_source_query_seed_100" / "query_001"
v53d_summary = list(csv.DictReader((results / "v53d_canary_source_query_seed_100_summary.csv").open(newline="", encoding="utf-8")))[0]

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


def evidence_for(span):
    text = span["evidence_text"].strip()
    return text if len(text) <= 220 else text[:220]


def supported_question(family, seed, variant_id):
    owner_repo = seed["owner_repo"]
    path = seed["source_path"]
    line = seed["source_line_start"]
    if family == "doc_code_conflict":
        return f"[v53e:{variant_id}] In {owner_repo}, what source fact at {path}:{line} should be checked before claiming a doc/code conflict?"
    if family == "deprecation_legacy_usage":
        return f"[v53e:{variant_id}] In {owner_repo}, what does the evidence at {path}:{line} actually support for a deprecation or legacy-usage audit?"
    if family == "config_mismatch":
        return f"[v53e:{variant_id}] In {owner_repo}, what configuration or metadata fact is directly supported at {path}:{line}?"
    if family == "api_behavior":
        return f"[v53e:{variant_id}] In {owner_repo}, what API or code behavior can be grounded to {path}:{line}?"
    if family == "docs_truthfulness":
        return f"[v53e:{variant_id}] In {owner_repo}, what documentation claim is directly grounded by {path}:{line}?"
    return f"[v53e:{variant_id}] In {owner_repo}, what example/test alignment fact is grounded by {path}:{line}?"


def abstain_question(family, seed, variant_id):
    owner_repo = seed["owner_repo"]
    path = seed["source_path"]
    line = seed["source_line_start"]
    if family == "unsupported_claim_abstain":
        return f"[v53e:{variant_id}] Does {owner_repo} prove a broad production-readiness claim from only the canary evidence at {path}:{line}?"
    return f"[v53e:{variant_id}] If {owner_repo} has only the line at {path}:{line}, should the auditor answer a broader ambiguous repository claim?"


def expected_for(family, seed, span, variant_id):
    evidence = evidence_for(span)
    path = seed["source_path"]
    line = seed["source_line_start"]
    if family in NEGATIVE_FAMILIES:
        return (
            f"ABSTAIN: the canary source span at {path}:{line} only supports this local evidence: {evidence}. "
            "It does not prove the broader requested repository-level claim."
        )
    return f"Evidence at {path}:{line} supports this bounded audit fact: {evidence}"


for rel in [
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
]:
    copy(v53d_dir / rel, f"source_v53d/{rel}")
copy(results / "v53d_canary_source_query_seed_100_summary.csv", "source_v53d/v53d_canary_source_query_seed_100_summary.csv")

seed_queries = read_csv(v53d_dir / "canary_query_rows.csv")
seed_spans = {row["source_span_id"]: row for row in read_csv(v53d_dir / "canary_source_span_rows.csv")}
seeds_by_family = defaultdict(list)
seeds_by_repo = defaultdict(list)
for row in seed_queries:
    seeds_by_family[row["audit_type"]].append(row)
    seeds_by_repo[row["owner_repo"]].append(row)

query_rows = []
span_rows = []
query_index = 1
family_variant_counts = Counter()

for family, target in TARGET_FAMILY_ROWS.items():
    family_seeds = seeds_by_family.get(family) or seed_queries
    for local_idx in range(target):
        seed = family_seeds[local_idx % len(family_seeds)]
        source_span = seed_spans[seed["source_span_id"]]
        query_id = f"v53e_{query_index:04d}"
        span_id = f"{query_id}_span_001"
        variant_id = local_idx + 1
        family_variant_counts[family] += 1
        expected_behavior = "abstain" if family in NEGATIVE_FAMILIES else "answer-with-citation"
        question = abstain_question(family, seed, variant_id) if family in NEGATIVE_FAMILIES else supported_question(family, seed, variant_id)
        expected_answer = expected_for(family, seed, source_span, variant_id)
        query_rows.append(
            {
                "query_id": query_id,
                "parent_query_id": seed["query_id"],
                "variant_id": variant_id,
                "repo_id": seed["repo_id"],
                "owner_repo": seed["owner_repo"],
                "head_sha": seed["head_sha"],
                "audit_type": family,
                "question": question,
                "expected_behavior": expected_behavior,
                "expected_answer": expected_answer,
                "expected_answer_sha256": sha256_text(expected_answer),
                "source_span_id": span_id,
                "parent_source_span_id": seed["source_span_id"],
                "source_span_required": 1,
                "source_path": seed["source_path"],
                "source_line_start": seed["source_line_start"],
                "source_line_end": seed["source_line_end"],
                "source_file_sha256": seed["source_file_sha256"],
                "source_snapshot_scope": "canary",
                "negative_or_abstain": int(family in NEGATIVE_FAMILIES),
                "scale_scope": "v53e-canary-1000",
            }
        )
        span_rows.append(
            {
                "source_span_id": span_id,
                "query_id": query_id,
                "parent_source_span_id": source_span["source_span_id"],
                "parent_query_id": source_span["query_id"],
                "repo_id": source_span["repo_id"],
                "owner_repo": source_span["owner_repo"],
                "head_sha": source_span["head_sha"],
                "path": source_span["path"],
                "line_start": source_span["line_start"],
                "line_end": source_span["line_end"],
                "evidence_text": source_span["evidence_text"],
                "evidence_text_sha256": source_span["evidence_text_sha256"],
                "source_file_sha256": source_span["source_file_sha256"],
                "local_relpath": source_span["local_relpath"],
                "source_snapshot_scope": "canary",
            }
        )
        query_index += 1

write_csv(run_dir / "scaled_canary_query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "scaled_canary_source_span_rows.csv", list(span_rows[0].keys()), span_rows)

repo_counts = Counter(row["owner_repo"] for row in query_rows)
family_counts = Counter(row["audit_type"] for row in query_rows)
negative_rows = sum(1 for row in query_rows if int(row["negative_or_abstain"]))
supported_rows = len(query_rows) - negative_rows
seed_family_counts = Counter(row["audit_type"] for row in seed_queries)

family_rows = []
for family, target in TARGET_FAMILY_ROWS.items():
    family_rows.append(
        {
            "audit_type": family,
            "target_query_rows": target,
            "scaled_query_rows": family_counts[family],
            "v53d_seed_rows": seed_family_counts.get(family, 0),
            "seed_source": "same-family" if seed_family_counts.get(family, 0) else "cross-family-canary-source",
            "negative_or_abstain_family": int(family in NEGATIVE_FAMILIES),
            "status": "scaled" if family_counts[family] == target else "blocked",
        }
    )
write_csv(run_dir / "scaled_canary_query_family_rows.csv", list(family_rows[0].keys()), family_rows)

repo_rows = [
    {
        "owner_repo": owner_repo,
        "scaled_query_rows": repo_counts[owner_repo],
        "minimum_expected_rows": 1,
        "status": "covered" if repo_counts[owner_repo] > 0 else "missing",
    }
    for owner_repo in sorted(repo_counts)
]
write_csv(run_dir / "scaled_canary_query_repo_rows.csv", list(repo_rows[0].keys()), repo_rows)

target_query_rows = 1000
query_rows_count = len(query_rows)
source_span_rows = len(span_rows)
repo_count = len(repo_counts)
family_count = len(family_counts)
missing_query_rows = max(0, target_query_rows - query_rows_count)
v53e_ready = int(
    query_rows_count >= target_query_rows
    and source_span_rows == query_rows_count
    and repo_count == 10
    and family_count == len(TARGET_FAMILY_ROWS)
    and negative_rows >= 160
)

summary = {
    "v53e_canary_query_scale_ready": v53e_ready,
    "v53_ready": 0,
    "query_rows": query_rows_count,
    "source_span_rows": source_span_rows,
    "supported_source_span_bound_rows": supported_rows,
    "negative_abstain_rows": negative_rows,
    "repo_count": repo_count,
    "family_count": family_count,
    "target_query_rows_min": target_query_rows,
    "missing_query_rows": missing_query_rows,
    "v53d_canary_query_seed_ready": int(v53d_summary.get("v53d_canary_query_seed_ready", "0")),
    "full_source_snapshot_missing_repo_count": int(v53d_summary.get("full_source_snapshot_missing_repo_count", "0")),
    "answer_citation_resource_rows_ready": 0,
    "review_artifacts_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("canary-query-scale", "pass" if v53e_ready else "blocked", f"query_rows={query_rows_count}; source_span_rows={source_span_rows}; repo_count={repo_count}; family_count={family_count}"),
    ("query-count-target", "pass" if query_rows_count >= target_query_rows else "blocked", f"need >=1000 query rows; have {query_rows_count}; missing {missing_query_rows}"),
    ("source-span-binding", "pass" if source_span_rows == query_rows_count else "blocked", f"source_span_rows={source_span_rows}"),
    ("negative-abstain-target", "pass" if negative_rows >= 160 else "blocked", f"negative_abstain_rows={negative_rows}"),
    ("v53d-query-seed-input", "pass" if summary["v53d_canary_query_seed_ready"] else "blocked", "uses v53d canary query seeds"),
    ("full-source-snapshot-scale", "blocked", f"full snapshots still missing for {summary['full_source_snapshot_missing_repo_count']} repos"),
    ("answer-citation-resource-rows", "blocked", "A-H answer/citation/resource rows are not generated by v53e query scale"),
    ("human-review-artifacts", "blocked", "review artifacts are still absent"),
    ("v53-full-public-repo-audit", "blocked", "1000 canary-scope query rows are not complete source snapshots plus A-H answered audit rows"),
    ("real-release-package", "blocked", "v53e query scale is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md").write_text(
    "# v53e Canary Query Scale 1000 Boundary\n\n"
    "This layer scales v53d canary query seeds to 1000 source-span-bound query rows over the 10 locked repositories.\n"
    "It proves canary-scope query-count mechanics, family distribution, source-span binding, and negative/abstain row generation. "
    "It is not the completed v53 public-repo code/doc audit.\n\n"
    f"- query_rows={query_rows_count}\n"
    f"- source_span_rows={source_span_rows}\n"
    f"- supported_source_span_bound_rows={supported_rows}\n"
    f"- negative_abstain_rows={negative_rows}\n"
    f"- repo_count={repo_count}\n"
    f"- family_count={family_count}\n"
    f"- missing_query_rows={missing_query_rows}\n\n"
    "Still blocked:\n\n"
    "- complete source snapshots for all locked repositories\n"
    "- A-H answer/citation/resource rows over the 1000 queries\n"
    "- symmetric scorer/policy evaluation rows\n"
    "- human or release review artifacts\n\n"
    "Do not publish v53 safety/grounding superiority claims from canary-scope query scale alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53e-canary-query-scale-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53e_canary_query_scale_ready": v53e_ready,
    "v53_ready": 0,
    "query_rows": query_rows_count,
    "source_span_rows": source_span_rows,
    "supported_source_span_bound_rows": supported_rows,
    "negative_abstain_rows": negative_rows,
    "repo_count": repo_count,
    "family_count": family_count,
    "missing_query_rows": missing_query_rows,
    "target_family_rows": TARGET_FAMILY_ROWS,
    "v53d_summary_sha256": sha256(results / "v53d_canary_source_query_seed_100_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53e_canary_query_scale_1000_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "scaled_canary_query_rows.csv",
    "scaled_canary_source_span_rows.csv",
    "scaled_canary_query_family_rows.csv",
    "scaled_canary_query_repo_rows.csv",
    "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "v53e_canary_query_scale_1000_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53e_canary_query_scale_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
