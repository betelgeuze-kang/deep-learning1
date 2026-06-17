#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53_public_repo_code_doc_audit"
RUN_ID="${V53_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V50_RUN_DIR="$RESULTS_DIR/v50_public_repo_auditor_3repo/audit_001"
V50_SUMMARY_CSV="$RESULTS_DIR/v50_public_repo_auditor_3repo_summary.csv"
V53_ALLOW_V50_REFRESH="${V53_ALLOW_V50_REFRESH:-0}"
V50_REFRESH_EXECUTED=0

v50_required_files=(
  "$V50_SUMMARY_CSV"
  "$V50_RUN_DIR/public_repo_source_snapshot_rows.csv"
  "$V50_RUN_DIR/public_repo_audit_case_rows.csv"
  "$V50_RUN_DIR/public_repo_source_span_rows.csv"
  "$V50_RUN_DIR/guard_negative_rows.csv"
  "$V50_RUN_DIR/V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md"
  "$V50_RUN_DIR/v50_public_repo_auditor_manifest.json"
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
  if [ "$V53_ALLOW_V50_REFRESH" != "1" ]; then
    {
      echo "v53 requires existing v50 public-repo seed artifacts."
      echo "Missing seed evidence is fail-closed by default because v50 refresh performs public git fetches."
      echo "Set V53_ALLOW_V50_REFRESH=1 only with explicit approval to refresh pinned public sources."
    } >&2
    exit 2
  fi
  "$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null
  V50_REFRESH_EXECUTED=1
fi

for required_file in "${v50_required_files[@]}"; do
  if [ ! -s "$required_file" ]; then
    echo "v53 v50 seed artifact still missing after refresh policy check: $required_file" >&2
    exit 3
  fi
done

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V53_ALLOW_V50_REFRESH" "$V50_REFRESH_EXECUTED" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
v50_public_refresh_allowed = int(sys.argv[5] == "1")
v50_public_refresh_executed = int(sys.argv[6] == "1")
v50_seed_reused = int(not v50_public_refresh_executed)
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
v50_summary = list(csv.DictReader((results / "v50_public_repo_auditor_3repo_summary.csv").open(newline="", encoding="utf-8")))[0]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

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

for rel in [
    "public_repo_source_snapshot_rows.csv",
    "public_repo_audit_case_rows.csv",
    "public_repo_source_span_rows.csv",
    "guard_negative_rows.csv",
    "V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md",
    "v50_public_repo_auditor_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v50_dir / rel, f"source_v50/{rel}")

source_rows = read_csv(v50_dir / "public_repo_source_snapshot_rows.csv")
case_rows = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
span_rows = read_csv(v50_dir / "public_repo_source_span_rows.csv")
guard_rows = read_csv(v50_dir / "guard_negative_rows.csv")
repo_ids = sorted({row["repo_id"] for row in source_rows})

target_repo_rows = []
for repo_id in repo_ids:
    sample = next(row for row in source_rows if row["repo_id"] == repo_id)
    target_repo_rows.append(
        {
            "repo_slot": str(len(target_repo_rows) + 1),
            "repo_id": repo_id,
            "owner_repo": sample["owner_repo"],
            "repo_url": sample["repo_url"],
            "pinned_ref_ready": "1",
            "source_snapshot_ready": "1",
            "query_rows_ready": str(sum(1 for row in case_rows if row["repo_id"] == repo_id)),
            "status": "seed-ready-from-v50",
            "blocking_reason": "",
        }
    )
for slot in range(len(target_repo_rows) + 1, 11):
    target_repo_rows.append(
        {
            "repo_slot": str(slot),
            "repo_id": f"repo_slot_{slot:02d}",
            "owner_repo": "",
            "repo_url": "",
            "pinned_ref_ready": "0",
            "source_snapshot_ready": "0",
            "query_rows_ready": "0",
            "status": "missing-for-v53",
            "blocking_reason": "additional-public-repo-not-selected-or-pinned",
        }
    )
write_csv(run_dir / "target_repo_rows.csv", list(target_repo_rows[0].keys()), target_repo_rows)

query_type_targets = [
    ("api_behavior", 160),
    ("docs_truthfulness", 160),
    ("config_mismatch", 140),
    ("deprecation_legacy_usage", 140),
    ("doc_code_conflict", 140),
    ("examples_tests_alignment", 100),
    ("unsupported_claim_abstain", 100),
    ("ambiguous_source_abstain", 60),
]
existing_by_type = {}
for row in case_rows:
    audit_type = row["audit_type"]
    if audit_type == "deprecated_usage":
        audit_type = "deprecation_legacy_usage"
    existing_by_type[audit_type] = existing_by_type.get(audit_type, 0) + 1
query_scale_rows = []
for audit_type, target_rows in query_type_targets:
    existing_rows = existing_by_type.get(audit_type, 0)
    query_scale_rows.append(
        {
            "audit_type": audit_type,
            "target_query_rows": target_rows,
            "existing_seed_rows": existing_rows,
            "missing_query_rows": max(0, target_rows - existing_rows),
            "source_span_required": "1",
            "negative_or_abstain_required": "1" if audit_type in {"unsupported_claim_abstain", "ambiguous_source_abstain"} else "0",
            "status": "ready" if existing_rows >= target_rows else "missing-scale",
        }
    )
write_csv(run_dir / "query_scale_contract_rows.csv", list(query_scale_rows[0].keys()), query_scale_rows)

artifact_contract_rows = [
    ("pinned_repo_manifest", "required", "owner/repo, URL, requested ref, HEAD SHA, license and source hash rows"),
    ("source_snapshot_rows", "required", "file-level sha256 and line counts for all admissible source files"),
    ("query_set", "required", "1000-3000 query rows with source-span expectations"),
    ("answer_rows", "required", "per-system answer rows, compatible with v52 baseline registry"),
    ("citation_rows", "required", "answer-support spans and citation correctness"),
    ("abstain_rows", "required", "unsupported and ambiguous query abstentions"),
    ("guard_negative_rows", "required", "wrong-answer and unsupported-claim guards"),
    ("audit_report", "required", "repo-level and aggregate Markdown reports"),
    ("resource_rows", "required", "latency, memory, storage, and locality/cost rows"),
    ("sha256_manifest", "required", "hashes for all emitted artifacts"),
]
write_csv(
    run_dir / "artifact_contract_rows.csv",
    ["artifact", "required_status", "notes"],
    [{"artifact": artifact, "required_status": status, "notes": notes} for artifact, status, notes in artifact_contract_rows],
)

negative_control_target = 100
existing_negative_rows = len(guard_rows)
source_span_bound_rows = len(span_rows)
target_repo_count = 10
target_query_rows = 1000
repo_count = int(v50_summary.get("repo_count", "0"))
query_rows = int(v50_summary.get("audit_case_rows", "0"))
missing_repo_count = max(0, target_repo_count - repo_count)
missing_query_rows = max(0, target_query_rows - query_rows)
v53_ready = int(repo_count >= target_repo_count and query_rows >= target_query_rows)

summary = {
    "v53_public_repo_code_doc_audit_contract_ready": 1,
    "v53_ready": v53_ready,
    "target_repo_count_min": target_repo_count,
    "target_query_rows_min": target_query_rows,
    "current_seed_repo_count": repo_count,
    "current_seed_query_rows": query_rows,
    "missing_repo_count": missing_repo_count,
    "missing_query_rows": missing_query_rows,
    "source_snapshot_rows": int(v50_summary.get("source_snapshot_rows", "0")),
    "source_span_bound_rows": source_span_bound_rows,
    "guard_negative_rows": existing_negative_rows,
    "negative_control_target_rows": negative_control_target,
    "pinned_commit_manifest_ready": int(v50_summary.get("repo_refs_pinned") == "1"),
    "abstain_policy_contract_ready": 1,
    "wrong_answer_guard_contract_ready": 1,
    "v50_seed_reused": v50_seed_reused,
    "v50_public_refresh_allowed": v50_public_refresh_allowed,
    "v50_public_refresh_executed": v50_public_refresh_executed,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53-public-repo-audit-contract", "pass", "target repo/query/artifact contract emitted"),
    ("v50-seed-refresh-policy", "pass", f"seed_reused={v50_seed_reused}; public_refresh_allowed={v50_public_refresh_allowed}; public_refresh_executed={v50_public_refresh_executed}"),
    ("v50-seed-evidence", "pass" if repo_count == 3 and query_rows == 9 else "blocked", f"seed_repo_count={repo_count}; seed_query_rows={query_rows}"),
    ("repo-count-target", "blocked", f"need >=10 repos; have {repo_count}; missing {missing_repo_count}"),
    ("query-count-target", "blocked", f"need >=1000 query rows; have {query_rows}; missing {missing_query_rows}"),
    ("negative-control-target", "blocked", f"need >=100 negative/abstain rows; have {existing_negative_rows}"),
    ("source-span-binding", "pass" if source_span_bound_rows >= query_rows else "blocked", f"source_span_bound_rows={source_span_bound_rows}"),
    ("pinned-commit-manifest", "pass" if summary["pinned_commit_manifest_ready"] else "blocked", "v50 seed refs pinned"),
    ("real-release-package", "blocked", "v53 contract is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md").write_text(
    "# v53 Public Repo Code/Doc Audit Boundary\n\n"
    "This is the v53 scale contract scaffold, not the completed 10-30 repo / 1000-3000 query audit.\n\n"
    "Seed evidence from v50:\n\n"
    f"- repos={repo_count}\n"
    f"- audit_case_rows={query_rows}\n"
    f"- source_span_bound_rows={source_span_bound_rows}\n"
    f"- guard_negative_rows={existing_negative_rows}\n\n"
    "Refresh policy:\n\n"
    f"- v50_seed_reused={v50_seed_reused}\n"
    f"- v50_public_refresh_allowed={v50_public_refresh_allowed}\n"
    f"- v50_public_refresh_executed={v50_public_refresh_executed}\n"
    "- existing v50 seed artifacts are reused by default; public git refresh requires V53_ALLOW_V50_REFRESH=1 and explicit approval\n\n"
    "Still blocked:\n\n"
    f"- missing_repo_count={missing_repo_count}\n"
    f"- missing_query_rows={missing_query_rows}\n"
    "- negative/abstain rows must scale to at least 10% of the 1000-row minimum\n"
    "- all new queries must bind back to pinned public source files and source spans\n\n"
    "Do not publish v53 safety/grounding superiority claims until the full repo and query scale targets pass.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53-public-repo-code-doc-audit-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53_public_repo_code_doc_audit_contract_ready": 1,
    "v53_ready": v53_ready,
    "target_repo_count_min": target_repo_count,
    "target_query_rows_min": target_query_rows,
    "current_seed_repo_count": repo_count,
    "current_seed_query_rows": query_rows,
    "missing_repo_count": missing_repo_count,
    "missing_query_rows": missing_query_rows,
    "v50_seed_reused": v50_seed_reused,
    "v50_public_refresh_allowed": v50_public_refresh_allowed,
    "v50_public_refresh_executed": v50_public_refresh_executed,
    "v50_source_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53_public_repo_code_doc_audit_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "target_repo_rows.csv",
    "query_scale_contract_rows.csv",
    "artifact_contract_rows.csv",
    "V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md",
    "v53_public_repo_code_doc_audit_manifest.json",
    "source_v50/public_repo_source_snapshot_rows.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/guard_negative_rows.csv",
    "source_v50/V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md",
    "source_v50/v50_public_repo_auditor_manifest.json",
    "source_v50/sha256_manifest.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53_public_repo_code_doc_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
