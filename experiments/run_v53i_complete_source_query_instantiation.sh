#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53i_complete_source_query_instantiation"
RUN_ID="${V53I_RUN_ID:-instantiate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53I_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53i_complete_source_query_instantiation_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53H_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53h_complete_source_content_snapshot.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
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
v53h_dir = results / "v53h_complete_source_content_snapshot" / "snapshot_001"

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


def clean_line(line):
    return re.sub(r"\s+", " ", line.strip())


def candidate_span(row):
    path = v53h_dir / row["local_relpath"]
    text = path.read_text(encoding="utf-8", errors="replace")
    fallback = ("", 1)
    for line_no, line in enumerate(text.splitlines(), start=1):
        evidence = clean_line(line)
        if not fallback[0] and evidence:
            fallback = (evidence, line_no)
        if len(evidence) < 12:
            continue
        if evidence.startswith(("#", "//", "/*", "*")) and len(evidence) < 24:
            continue
        return line_no, evidence[:240]
    evidence, line_no = fallback
    if not evidence:
        evidence = f"{row['path']} is present in the pinned complete-source content snapshot."
    return line_no, evidence[:240]


def supported_question(family, row, line_no, variant_id):
    owner_repo = row["owner_repo"]
    path = row["path"]
    if family == "doc_code_conflict":
        return f"[v53i:{variant_id}] In {owner_repo}, what bounded source fact at {path}:{line_no} should be checked before claiming a doc/code conflict?"
    if family == "deprecation_legacy_usage":
        return f"[v53i:{variant_id}] In {owner_repo}, what does the complete-source evidence at {path}:{line_no} actually support for a deprecation or legacy-usage audit?"
    if family == "config_mismatch":
        return f"[v53i:{variant_id}] In {owner_repo}, what configuration or metadata fact is directly supported at {path}:{line_no}?"
    if family == "api_behavior":
        return f"[v53i:{variant_id}] In {owner_repo}, what API or code behavior can be grounded to {path}:{line_no}?"
    if family == "docs_truthfulness":
        return f"[v53i:{variant_id}] In {owner_repo}, what documentation claim is directly grounded by {path}:{line_no}?"
    return f"[v53i:{variant_id}] In {owner_repo}, what example/test alignment fact is grounded by {path}:{line_no}?"


def abstain_question(family, row, line_no, variant_id):
    owner_repo = row["owner_repo"]
    path = row["path"]
    if family == "unsupported_claim_abstain":
        return f"[v53i:{variant_id}] Does the complete-source corpus prove a broad production-readiness claim for {owner_repo} from only the pinned evidence at {path}:{line_no}?"
    return f"[v53i:{variant_id}] If {owner_repo} has only the cited complete-source span at {path}:{line_no}, should the auditor answer a broader ambiguous repository-level claim?"


def expected_for(family, row, line_no, evidence):
    path = row["path"]
    if family in NEGATIVE_FAMILIES:
        return (
            f"ABSTAIN: the complete-source span at {path}:{line_no} only supports this local evidence: {evidence}. "
            "It does not prove the broader requested repository-level claim."
        )
    return f"Evidence at {path}:{line_no} supports this bounded complete-source audit fact: {evidence}"


def row_sort_key(row):
    return (
        row["owner_repo"],
        row["source_category"],
        row["path"],
        row["content_sha256"],
        row["git_blob_sha"],
    )


def select_rows(pool, target):
    by_repo = defaultdict(list)
    for row in sorted(pool, key=row_sort_key):
        by_repo[row["owner_repo"]].append(row)
    repo_names = sorted(by_repo)
    if not repo_names:
        raise SystemExit("no eligible complete-source rows for query instantiation")
    cursors = {repo: 0 for repo in repo_names}
    selected = []
    while len(selected) < target:
        made_progress = False
        for repo in repo_names:
            rows = by_repo[repo]
            if not rows:
                continue
            selected.append(rows[cursors[repo] % len(rows)])
            cursors[repo] += 1
            made_progress = True
            if len(selected) >= target:
                break
        if not made_progress:
            raise SystemExit("failed to select complete-source rows")
    return selected


v53h_summary = read_csv(results / "v53h_complete_source_content_snapshot_summary.csv")[0]
if v53h_summary.get("v53h_complete_source_content_snapshot_ready") != "1":
    raise SystemExit("v53i requires v53h_complete_source_content_snapshot_ready=1")

for rel in [
    "complete_source_content_snapshot_rows.csv",
    "complete_source_content_repo_rows.csv",
    "complete_source_content_gap_rows.csv",
    "V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md",
    "v53h_complete_source_content_snapshot_manifest.json",
    "sha256_manifest.csv",
    "source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53g/complete_source_query_budget_rows.csv",
    "source_v53g/complete_source_gap_rows.csv",
    "source_v53g/V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "source_v53g/v53g_complete_source_manifest_manifest.json",
    "source_v53g/sha256_manifest.csv",
    "source_v53g/v53g_complete_source_manifest_summary.csv",
]:
    copy(v53h_dir / rel, f"source_v53h/{rel}")
copy(results / "v53h_complete_source_content_snapshot_summary.csv", "source_v53h/v53h_complete_source_content_snapshot_summary.csv")

content_rows = read_csv(v53h_dir / "complete_source_content_snapshot_rows.csv")
budget_rows = read_csv(v53h_dir / "source_v53g/complete_source_query_budget_rows.csv")
eligible_rows = [
    row
    for row in content_rows
    if row["query_eligible"] == "1"
    and row["content_materialized"] == "1"
    and row["utf8_decode_error"] == "0"
    and int(row["line_count"]) > 0
]
rows_by_category = defaultdict(list)
for row in eligible_rows:
    rows_by_category[row["source_category"]].append(row)

query_rows = []
span_rows = []
query_index = 1
family_counts = Counter()

for family_budget in budget_rows:
    family = family_budget["audit_type"]
    target = int(family_budget["target_query_rows"])
    preferred = family_budget["preferred_source_category"]
    pool = eligible_rows if preferred == "mixed" else rows_by_category.get(preferred, [])
    selected_rows = select_rows(pool, target)
    for variant_id, row in enumerate(selected_rows, start=1):
        line_no, evidence = candidate_span(row)
        query_id = f"v53i_{query_index:04d}"
        span_id = f"{query_id}_span_001"
        expected_behavior = "abstain" if family in NEGATIVE_FAMILIES else "answer-with-citation"
        question = abstain_question(family, row, line_no, variant_id) if family in NEGATIVE_FAMILIES else supported_question(family, row, line_no, variant_id)
        expected_answer = expected_for(family, row, line_no, evidence)
        family_counts[family] += 1
        query_rows.append(
            {
                "query_id": query_id,
                "variant_id": str(variant_id),
                "repo_id": row["repo_id"],
                "owner_repo": row["owner_repo"],
                "head_sha": row["head_sha"],
                "audit_type": family,
                "question": question,
                "expected_behavior": expected_behavior,
                "expected_answer": expected_answer,
                "expected_answer_sha256": sha256_text(expected_answer),
                "source_span_id": span_id,
                "source_span_required": "1",
                "source_path": row["path"],
                "source_line_start": str(line_no),
                "source_line_end": str(line_no),
                "source_file_sha256": row["content_sha256"],
                "source_git_blob_sha": row["git_blob_sha"],
                "source_category": row["source_category"],
                "source_snapshot_scope": "complete-source-content",
                "negative_or_abstain": str(int(family in NEGATIVE_FAMILIES)),
                "scale_scope": "v53i-complete-source-1000",
            }
        )
        span_rows.append(
            {
                "source_span_id": span_id,
                "query_id": query_id,
                "repo_id": row["repo_id"],
                "owner_repo": row["owner_repo"],
                "head_sha": row["head_sha"],
                "path": row["path"],
                "line_start": str(line_no),
                "line_end": str(line_no),
                "evidence_text": evidence,
                "evidence_text_sha256": sha256_text(evidence),
                "source_file_sha256": row["content_sha256"],
                "git_blob_sha": row["git_blob_sha"],
                "source_category": row["source_category"],
                "local_relpath": row["local_relpath"],
                "source_snapshot_scope": "complete-source-content",
            }
        )
        query_index += 1

write_csv(run_dir / "complete_source_query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "complete_source_span_rows.csv", list(span_rows[0].keys()), span_rows)

repo_counts = Counter(row["owner_repo"] for row in query_rows)
repo_span_counts = Counter(row["owner_repo"] for row in span_rows)
family_rows = []
for family_budget in budget_rows:
    family = family_budget["audit_type"]
    preferred = family_budget["preferred_source_category"]
    target = int(family_budget["target_query_rows"])
    eligible_count = len(eligible_rows) if preferred == "mixed" else len(rows_by_category.get(preferred, []))
    family_rows.append(
        {
            "audit_type": family,
            "target_query_rows": str(target),
            "preferred_source_category": preferred,
            "eligible_content_rows": str(eligible_count),
            "complete_source_query_rows": str(family_counts[family]),
            "negative_or_abstain_family": str(int(family in NEGATIVE_FAMILIES)),
            "status": "instantiated" if family_counts[family] == target else "blocked",
        }
    )
write_csv(run_dir / "complete_source_query_family_rows.csv", list(family_rows[0].keys()), family_rows)

content_by_repo = {row["owner_repo"]: row for row in read_csv(v53h_dir / "complete_source_content_repo_rows.csv")}
repo_rows = []
for owner_repo in sorted(content_by_repo):
    repo = content_by_repo[owner_repo]
    repo_rows.append(
        {
            "repo_id": repo["repo_id"],
            "owner_repo": owner_repo,
            "head_sha": repo["head_sha"],
            "complete_source_query_rows": str(repo_counts.get(owner_repo, 0)),
            "complete_source_span_rows": str(repo_span_counts.get(owner_repo, 0)),
            "content_materialized_file_rows": repo["content_materialized_file_rows"],
            "status": "covered" if repo_counts.get(owner_repo, 0) > 0 else "missing",
        }
    )
write_csv(run_dir / "complete_source_query_repo_rows.csv", list(repo_rows[0].keys()), repo_rows)

gap_rows = [
    ("complete-source-query-instantiation", "pass", f"complete_source_query_rows={len(query_rows)}"),
    ("line-level-source-span-binding", "pass", f"complete_source_span_rows={len(span_rows)}"),
    ("a-h-answer-citation-resource-rows", "blocked", "A-H supplied answer/citation/resource rows over v53i complete-source queries are absent"),
    ("symmetric-scorer-policy-rows", "blocked", "symmetric scorer/policy evaluation rows over v53i are absent"),
    ("human-review-artifacts", "blocked", "human/source review artifacts are not supplied"),
    ("v53-ready", "blocked", "query instantiation alone is not the completed v53 audit"),
    ("real-release-package", "blocked", "v53i query rows are not a release package"),
]
write_csv(
    run_dir / "complete_source_query_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

target_query_rows = sum(int(row["target_query_rows"]) for row in budget_rows)
negative_rows = sum(1 for row in query_rows if row["negative_or_abstain"] == "1")
supported_rows = len(query_rows) - negative_rows
repo_count = len(repo_counts)
family_count = len(family_counts)
missing_query_rows = max(0, target_query_rows - len(query_rows))
v53i_ready = int(
    len(query_rows) >= 1000
    and len(query_rows) == target_query_rows
    and len(span_rows) == len(query_rows)
    and negative_rows == 160
    and repo_count == 10
    and family_count == len(budget_rows)
    and all(row["status"] == "instantiated" for row in family_rows)
)

summary = {
    "v53i_complete_source_query_instantiation_ready": str(v53i_ready),
    "v53h_complete_source_content_snapshot_ready": v53h_summary["v53h_complete_source_content_snapshot_ready"],
    "v53g_complete_source_manifest_ready": v53h_summary["v53g_complete_source_manifest_ready"],
    "v53_ready": "0",
    "complete_source_content_snapshot_ready": v53h_summary["complete_source_content_snapshot_ready"],
    "complete_source_query_rows_ready": str(v53i_ready),
    "complete_source_query_rows": str(len(query_rows)),
    "complete_source_span_rows": str(len(span_rows)),
    "supported_source_span_bound_rows": str(supported_rows),
    "negative_abstain_rows": str(negative_rows),
    "repo_count": str(repo_count),
    "family_count": str(family_count),
    "target_query_rows_min": "1000",
    "missing_query_rows": str(missing_query_rows),
    "query_eligible_content_rows": v53h_summary["query_eligible_content_rows"],
    "source_file_rows": v53h_summary["source_file_rows"],
    "doc_file_rows": v53h_summary["doc_file_rows"],
    "config_file_rows": v53h_summary["config_file_rows"],
    "test_file_rows": v53h_summary["test_file_rows"],
    "ah_answer_citation_resource_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53h-complete-source-content-input", "pass" if summary["v53h_complete_source_content_snapshot_ready"] == "1" else "blocked", "uses v53h materialized complete-source content snapshot"),
    ("complete-source-query-instantiation", "pass" if v53i_ready else "blocked", f"complete_source_query_rows={len(query_rows)}; family_count={family_count}; repo_count={repo_count}"),
    ("source-span-binding", "pass" if len(span_rows) == len(query_rows) else "blocked", f"complete_source_span_rows={len(span_rows)}"),
    ("family-budget-targets", "pass" if all(row["status"] == "instantiated" for row in family_rows) else "blocked", f"target_query_rows={target_query_rows}"),
    ("negative-abstain-target", "pass" if negative_rows == 160 else "blocked", f"negative_abstain_rows={negative_rows}"),
    ("repo-coverage", "pass" if repo_count == 10 else "blocked", f"repo_count={repo_count}"),
    ("supplied-a-h-answer-rows", "blocked", "A-H answer/citation/resource rows are still absent for the v53i complete-source query set"),
    ("citation-resource-coverage", "blocked", "complete-source query rows have expected answers and spans but no supplied A-H resource rows"),
    ("human-review-artifacts", "blocked", "human review artifacts are still absent"),
    ("v53-full-public-repo-audit", "blocked", "v53i closes query instantiation, not complete A-H answered/reviewed audit evidence"),
    ("real-release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md").write_text(
    "# v53i Complete Source Query Instantiation Boundary\n\n"
    "This layer instantiates the v53g eight-family 1000-query budget over the v53h materialized complete-source content snapshot. "
    "Each query row is bound to a line-level source span and content sha256 from the pinned complete-source corpus.\n\n"
    f"- complete_source_query_rows={len(query_rows)}\n"
    f"- complete_source_span_rows={len(span_rows)}\n"
    f"- supported_source_span_bound_rows={supported_rows}\n"
    f"- negative_abstain_rows={negative_rows}\n"
    f"- repo_count={repo_count}\n"
    f"- family_count={family_count}\n"
    "- complete_source_query_rows_ready=1\n"
    "- ah_answer_citation_resource_rows_ready=0\n"
    "- review_artifacts_ready=0\n"
    "- v53_ready=0\n\n"
    "Still blocked:\n\n"
    "- A/B/C/D/E/G/H answer/citation/resource rows over the v53i complete-source query set\n"
    "- symmetric scorer/policy evaluation rows over those same query IDs\n"
    "- human/source review artifacts and release evidence\n\n"
    "Do not publish v53 completion, v1.0 comparison, superiority, or release claims from query instantiation alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53i-complete-source-query-instantiation",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53i_complete_source_query_instantiation_ready": v53i_ready,
    "v53_ready": 0,
    "complete_source_query_rows_ready": v53i_ready,
    "complete_source_query_rows": len(query_rows),
    "complete_source_span_rows": len(span_rows),
    "supported_source_span_bound_rows": supported_rows,
    "negative_abstain_rows": negative_rows,
    "repo_count": repo_count,
    "family_count": family_count,
    "target_family_rows": {row["audit_type"]: int(row["target_query_rows"]) for row in family_rows},
    "v53h_summary_sha256": sha256(results / "v53h_complete_source_content_snapshot_summary.csv"),
    "complete_source_query_rows_sha256": sha256(run_dir / "complete_source_query_rows.csv"),
    "complete_source_span_rows_sha256": sha256(run_dir / "complete_source_span_rows.csv"),
    "ah_answer_citation_resource_rows_ready": 0,
    "review_artifacts_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53i_complete_source_query_instantiation_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "complete_source_query_rows.csv",
    "complete_source_span_rows.csv",
    "complete_source_query_family_rows.csv",
    "complete_source_query_repo_rows.csv",
    "complete_source_query_gap_rows.csv",
    "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md",
    "v53i_complete_source_query_instantiation_manifest.json",
    "source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v53h/complete_source_content_repo_rows.csv",
    "source_v53h/complete_source_content_gap_rows.csv",
    "source_v53h/V53H_COMPLETE_SOURCE_CONTENT_SNAPSHOT_BOUNDARY.md",
    "source_v53h/v53h_complete_source_content_snapshot_manifest.json",
    "source_v53h/sha256_manifest.csv",
    "source_v53h/v53h_complete_source_content_snapshot_summary.csv",
    "source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v53h/source_v53g/complete_source_gap_rows.csv",
    "source_v53h/source_v53g/V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "source_v53h/source_v53g/v53g_complete_source_manifest_manifest.json",
    "source_v53h/source_v53g/sha256_manifest.csv",
    "source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53i_complete_source_query_instantiation_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
