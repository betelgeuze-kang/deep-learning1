#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53t_complete_source_audit_readiness_gate"
RUN_ID="${V53T_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53T_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" && -s "$RUN_DIR/complete_source_pm_freeze_check_rows.csv" && -s "$RUN_DIR/complete_source_foundation_freeze_rows.csv" && -s "$RUN_DIR/source_v53ap/abgh_system_metric_rows.csv" ]] && grep -q 'missing_specific_control_rows=30' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'abgh_same_query_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_machine_freeze_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md"; then
  echo "v53t_complete_source_audit_readiness_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
V53AP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ap_complete_source_abgh_same_query_measured.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


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


summary_paths = {
    "v52y": results / "v52y_f_optional_final_policy_summary.csv",
    "v53i": results / "v53i_complete_source_query_instantiation_summary.csv",
    "v53ap": results / "v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "v53q": results / "v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "v53r": results / "v53r_complete_source_review_packet_summary.csv",
    "v53s": results / "v53s_complete_source_review_return_intake_summary.csv",
}
decision_paths = {
    "v52y": results / "v52y_f_optional_final_policy_decision.csv",
    "v53q": results / "v53q_complete_source_symmetric_scorer_policy_decision.csv",
    "v53r": results / "v53r_complete_source_review_packet_decision.csv",
    "v53s": results / "v53s_complete_source_review_return_intake_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for key, field in [
    ("v52y", "v52y_f_optional_final_policy_ready"),
    ("v53i", "v53i_complete_source_query_instantiation_ready"),
    ("v53ap", "v53ap_complete_source_abgh_same_query_measured_ready"),
    ("v53q", "v53q_complete_source_symmetric_scorer_policy_ready"),
    ("v53r", "v53r_complete_source_review_packet_ready"),
    ("v53s", "v53s_complete_source_review_return_intake_ready"),
]:
    if summaries[key].get(field) != "1":
        raise SystemExit(f"v53t requires {field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

v53i_dir = results / "v53i_complete_source_query_instantiation" / "instantiate_001"
v53ap_dir = results / "v53ap_complete_source_abgh_same_query_measured" / "measured_001"
v53q_dir = results / "v53q_complete_source_symmetric_scorer_policy" / "score_001"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
for src, rel in [
    (v53i_dir / "complete_source_query_family_rows.csv", "source_v53i/complete_source_query_family_rows.csv"),
    (v53i_dir / "complete_source_control_family_rows.csv", "source_v53i/complete_source_control_family_rows.csv"),
    (v53i_dir / "complete_source_query_repo_rows.csv", "source_v53i/complete_source_query_repo_rows.csv"),
    (v53ap_dir / "abgh_system_metric_rows.csv", "source_v53ap/abgh_system_metric_rows.csv"),
    (v53ap_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md", "source_v53ap/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md"),
    (v53q_dir / "symmetric_system_metric_rows.csv", "source_v53q/symmetric_system_metric_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53s_dir / "review_return_metric_rows.csv", "source_v53s/review_return_metric_rows.csv"),
    (v53s_dir / "review_return_artifact_gate_rows.csv", "source_v53s/review_return_artifact_gate_rows.csv"),
    (v53s_dir / "review_return_required_field_rows.csv", "source_v53s/review_return_required_field_rows.csv"),
]:
    copy(src, rel)

v52y = summaries["v52y"]
v53i = summaries["v53i"]
v53ap = summaries["v53ap"]
v53q = summaries["v53q"]
v53r = summaries["v53r"]
v53s = summaries["v53s"]

v53i_family_rows = read_csv(v53i_dir / "complete_source_query_family_rows.csv")
v53ap_system_metric_rows = read_csv(v53ap_dir / "abgh_system_metric_rows.csv")
family_query_rows = {
    row["audit_type"]: int(row["complete_source_query_rows"])
    for row in v53i_family_rows
}
system_metric_by_id = {row["system_id"]: row for row in v53ap_system_metric_rows}
unsupported_control_rows = family_query_rows.get("unsupported_claim_abstain", 0)
ambiguous_control_rows = family_query_rows.get("ambiguous_source_abstain", 0)
missing_specific_control_rows = sum(
    count for family, count in family_query_rows.items() if "missing" in family
)
doc_code_conflict_rows = family_query_rows.get("doc_code_conflict", 0)
current_v53i_query_rows_sha256 = sha256(v53i_dir / "complete_source_query_rows.csv")
v53ap_query_rows_sha256 = v53ap["source_query_rows_sha256"]
same_complete_source_query_hash = int(current_v53i_query_rows_sha256 == v53ap_query_rows_sha256)
abgh_systems = ("A", "B", "G", "H")
abgh_same_query_ready = int(
    same_complete_source_query_hash
    and
    all(
        system_metric_by_id.get(system_id, {}).get("answer_rows") == "1000"
        and (
            system_metric_by_id.get(system_id, {}).get("citation_span_match_rows") == "1000"
            or system_metric_by_id.get(system_id, {}).get("citation_correct_rows") == "1000"
        )
        and (
            system_metric_by_id.get(system_id, {}).get("resource_row_bound_rows") == "1000"
            or system_metric_by_id.get(system_id, {}).get("resource_rows") == "1000"
        )
        for system_id in abgh_systems
    )
)

requirements = [
    {
        "requirement_id": "f-optional-final-disposition",
        "status": "pass" if v52y["f_optional_final_disposition_ready"] == "1" else "blocked",
        "required_value": "supplied-ready-or-deferred-with-reason-final",
        "actual_value": v52y["f_optional_final_disposition"],
        "reason": "F optional 100B+ baseline must be supplied or explicitly final-deferred",
    },
    {
        "requirement_id": "complete-source-content-and-query-surface",
        "status": "pass" if v53i["complete_source_query_rows_ready"] == "1" and v53i["repo_count"] == "10" else "blocked",
        "required_value": "10 repos / 1000 queries / 1000 spans",
        "actual_value": f"{v53i['repo_count']} repos / {v53i['complete_source_query_rows']} queries / {v53i['complete_source_span_rows']} spans",
        "reason": "complete source snapshot and query/span surface must meet the v1.0 minimum",
    },
    {
        "requirement_id": "core-a-b-c-d-e-g-h-answer-citation-resource",
        "status": "pass" if v53q["answer_citation_resource_rows_ready"] == "1" and v53q["core_answer_rows"] == "7000" else "blocked",
        "required_value": "7000 core A/B/C/D/E/G/H answer/citation/resource rows",
        "actual_value": v53q["core_answer_rows"],
        "reason": "all seven required core systems must supply rows over the same complete-source query set",
    },
    {
        "requirement_id": "symmetric-scorer-policy-surface",
        "status": "pass" if v53q["symmetric_scorer_policy_rows_ready"] == "1" else "blocked",
        "required_value": "7000 scorer rows and 7000 policy rows",
        "actual_value": f"{v53q['symmetric_scorer_rows']} scorer / {v53q['symmetric_policy_rows']} policy",
        "reason": "all core systems must be evaluated under the same source/policy rules",
    },
    {
        "requirement_id": "review-packet-ready",
        "status": "pass" if v53r["review_packet_ready"] == "1" else "blocked",
        "required_value": "1000 query packets / 7000 answer packets / 7000 queue rows",
        "actual_value": f"{v53r['review_query_packet_rows']} query / {v53r['review_answer_packet_rows']} answer / {v53r['review_queue_rows']} queue",
        "reason": "human review surface must be frozen before external review return",
    },
    {
        "requirement_id": "human-review-return-accepted",
        "status": "pass" if v53s["human_review_completed"] == "1" else "blocked",
        "required_value": v53s["expected_human_review_rows"],
        "actual_value": v53s["accepted_human_review_rows"],
        "reason": "all answer packets require accepted human/source review rows",
    },
    {
        "requirement_id": "adjudication-return-accepted",
        "status": "pass" if v53s["adjudication_completed"] == "1" else "blocked",
        "required_value": v53s["expected_adjudication_rows"],
        "actual_value": v53s["accepted_adjudication_rows"],
        "reason": "all p0 mismatch/policy-conflict rows require adjudication",
    },
    {
        "requirement_id": "reviewer-identity-conflict-ready",
        "status": "pass" if v53s["reviewer_identity_ready"] == "1" and v53s["conflict_disclosure_ready"] == "1" else "blocked",
        "required_value": "reviewer identity and conflict disclosures accepted",
        "actual_value": f"identity={v53s['accepted_reviewer_identity_rows']}; conflict={v53s['accepted_conflict_disclosure_rows']}",
        "reason": "human review must include reviewer independence and conflict evidence",
    },
    {
        "requirement_id": "quality-comparison-claim-ready",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "1" else "blocked",
        "required_value": "1",
        "actual_value": v53s["quality_comparison_claim_ready"],
        "reason": "comparison wording waits for accepted review returns and final audit",
    },
    {
        "requirement_id": "release-package-ready",
        "status": "pass" if v53s["real_release_package_ready"] == "1" else "blocked",
        "required_value": "1",
        "actual_value": v53s["real_release_package_ready"],
        "reason": "v53t is not a release artifact package",
    },
]
write_csv(run_dir / "complete_source_audit_readiness_requirement_rows.csv", list(requirements[0].keys()), requirements)

machine_ready_ids = [
    "f-optional-final-disposition",
    "complete-source-content-and-query-surface",
    "core-a-b-c-d-e-g-h-answer-citation-resource",
    "symmetric-scorer-policy-surface",
    "review-packet-ready",
]
machine_complete_source_surface_ready = int(all(row["status"] == "pass" for row in requirements if row["requirement_id"] in machine_ready_ids))
review_return_ready = int(v53s["review_return_ready"])
v53_ready = int(machine_complete_source_surface_ready and review_return_ready and v53s["quality_comparison_claim_ready"] == "1")

pm_freeze_checks = [
    {
        "check_id": "pinned-public-repo-manifest",
        "status": "pass" if v53i["repo_count"] == "10" else "blocked",
        "required_value": ">=10 pinned public repos",
        "actual_value": v53i["repo_count"],
        "reason": "v53 foundation requires the public repo source manifest to be pinned before comparisons",
    },
    {
        "check_id": "source-span-bound-1000",
        "status": "pass" if v53i["complete_source_query_rows"] == "1000" and v53i["complete_source_span_rows"] == "1000" else "blocked",
        "required_value": "1000 query rows and 1000 bound source spans",
        "actual_value": f"{v53i['complete_source_query_rows']} query / {v53i['complete_source_span_rows']} span",
        "reason": "every benchmark query must bind to a pinned source span",
    },
    {
        "check_id": "negative-abstain-control-10pct",
        "status": "pass" if int(v53i["negative_abstain_rows"]) >= 100 else "blocked",
        "required_value": ">=100 negative/abstain rows",
        "actual_value": v53i["negative_abstain_rows"],
        "reason": "negative and abstain controls must be at least 10% of the 1000-row corpus",
    },
    {
        "check_id": "unsupported-claim-control",
        "status": "pass" if unsupported_control_rows > 0 else "blocked",
        "required_value": ">=1 unsupported claim abstain row",
        "actual_value": str(unsupported_control_rows),
        "reason": "unsupported claim controls must be visible as their own row family",
    },
    {
        "check_id": "missing-specific-abstain-control",
        "status": "pass" if missing_specific_control_rows > 0 else "blocked",
        "required_value": ">=1 explicit missing/missing-api abstain row family",
        "actual_value": str(missing_specific_control_rows),
        "reason": "current negative rows cover unsupported and ambiguous claims, but do not name a missing-specific control family",
    },
    {
        "check_id": "doc-code-conflict-control",
        "status": "pass" if doc_code_conflict_rows > 0 else "blocked",
        "required_value": ">=1 doc-code conflict row",
        "actual_value": str(doc_code_conflict_rows),
        "reason": "doc/code conflict rows must be explicit before v53 freeze",
    },
    {
        "check_id": "answer-citation-separate-eval",
        "status": "pass" if v53q["symmetric_scorer_policy_rows_ready"] == "1" else "blocked",
        "required_value": "answer and citation evaluated as separate bound rows",
        "actual_value": f"answer_hash_match_rows={v53q['answer_hash_match_rows']}; citation_span_match_rows={v53q['citation_span_match_rows']}",
        "reason": "the evaluator must separate answer correctness from citation/source correctness",
    },
    {
        "check_id": "abgh-same-query-v53i",
        "status": "pass" if abgh_same_query_ready else "blocked",
        "required_value": "A/B/G/H each have 1000 answer/citation/resource rows over the current v53i query hash",
        "actual_value": "; ".join(
            f"{system_id}:{system_metric_by_id.get(system_id, {}).get('answer_rows', '0')}"
            for system_id in abgh_systems
        ) + f"; same_query_hash={same_complete_source_query_hash}",
        "reason": "A/B/G/H must use the same complete-source query set before public D/E comparison wording",
    },
    {
        "check_id": "replayable-artifact-chain",
        "status": "pass",
        "required_value": "sha256 manifests copied for v52y/v53i/v53q/v53r/v53s",
        "actual_value": "present",
        "reason": "output artifacts must be replayable and hash-bound",
    },
    {
        "check_id": "blocker-false-positive-closed",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "0" and v53s["real_release_package_ready"] == "0" else "blocked",
        "required_value": "comparison/release blockers remain closed",
        "actual_value": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}; real_release_package_ready={v53s['real_release_package_ready']}",
        "reason": "merge conditions must not turn missing review evidence into a false-positive ready state",
    },
]
write_csv(run_dir / "complete_source_pm_freeze_check_rows.csv", list(pm_freeze_checks[0].keys()), pm_freeze_checks)
pm_freeze_pass_rows = sum(1 for row in pm_freeze_checks if row["status"] == "pass")
pm_freeze_blocked_rows = sum(1 for row in pm_freeze_checks if row["status"] == "blocked")
pm_v53_freeze_ready = int(pm_freeze_blocked_rows == 0)

foundation_freeze_rows = [
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "pinned-public-repo-manifest",
        "status": "pass" if v53i["repo_count"] == "10" else "blocked",
        "required_value": "10 pinned public repositories",
        "actual_value": v53i["repo_count"],
        "evidence_path": "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
        "claim_boundary": "Allows 10-repo public source manifest wording only; does not imply release readiness",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "source-span-bound-query-surface",
        "status": "pass" if v53i["complete_source_query_rows"] == "1000" and v53i["complete_source_span_rows"] == "1000" else "blocked",
        "required_value": "1000 source-span-bound query rows",
        "actual_value": f"{v53i['complete_source_query_rows']} query / {v53i['complete_source_span_rows']} span",
        "evidence_path": "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
        "claim_boundary": "Allows complete-source benchmark surface wording; every query remains source-span-bound",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "negative-abstain-control-share",
        "status": "pass" if int(v53i["negative_abstain_rows"]) >= 100 else "blocked",
        "required_value": ">=10% negative/abstain control rows",
        "actual_value": v53i["negative_abstain_rows"],
        "evidence_path": "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
        "claim_boundary": "Allows abstain-control coverage wording; does not imply model quality improvement",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "unsupported-claim-control",
        "status": "pass" if unsupported_control_rows == 100 else "blocked",
        "required_value": "100 unsupported claim abstain rows",
        "actual_value": str(unsupported_control_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows unsupported-control wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "missing-specific-abstain-control",
        "status": "pass" if missing_specific_control_rows == 30 else "blocked",
        "required_value": "30 missing-specific abstain rows",
        "actual_value": str(missing_specific_control_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows missing-specific abstain wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "doc-code-conflict-control",
        "status": "pass" if doc_code_conflict_rows == 140 else "blocked",
        "required_value": "140 doc-code conflict rows",
        "actual_value": str(doc_code_conflict_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows doc-code conflict coverage wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "answer-citation-separated-evaluator",
        "status": "pass" if v53q["symmetric_scorer_policy_rows_ready"] == "1" else "blocked",
        "required_value": "separate answer and citation/source evaluation rows",
        "actual_value": f"answer_hash_match_rows={v53q['answer_hash_match_rows']}; citation_span_match_rows={v53q['citation_span_match_rows']}",
        "evidence_path": "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv",
        "claim_boundary": "Allows evaluator-contract wording; does not allow human-reviewed correctness wording",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "abgh-same-query-measured-run",
        "status": "pass" if abgh_same_query_ready else "blocked",
        "required_value": "A/B/G/H measured over the same v53i query hash",
        "actual_value": "; ".join(
            f"{system_id}:{system_metric_by_id.get(system_id, {}).get('answer_rows', '0')}"
            for system_id in abgh_systems
        ) + f"; same_query_hash={same_complete_source_query_hash}",
        "evidence_path": "source_v53ap/abgh_system_metric_rows.csv",
        "claim_boundary": "Allows internal v1.0 pre-baseline A/B/G/H wording; public comparison remains blocked",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "replayable-artifact-chain",
        "status": "pass",
        "required_value": "hash-bound output artifacts and copied source summaries",
        "actual_value": "sha256_manifest.csv emitted",
        "evidence_path": "sha256_manifest.csv",
        "claim_boundary": "Allows replayable artifact wording for the emitted local run packet",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "public-comparison-boundary-closed",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "0" and v53s["real_release_package_ready"] == "0" else "blocked",
        "required_value": "quality/release claims blocked until D/E, human review, and release evidence exist",
        "actual_value": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}; real_release_package_ready={v53s['real_release_package_ready']}",
        "evidence_path": "source_v53s/v53s_complete_source_review_return_intake_summary.csv",
        "claim_boundary": "Explicitly forbids public comparison, v53-ready, and release-ready wording",
    },
]
write_csv(
    run_dir / "complete_source_foundation_freeze_rows.csv",
    list(foundation_freeze_rows[0].keys()),
    foundation_freeze_rows,
)
foundation_freeze_pass_rows = sum(1 for row in foundation_freeze_rows if row["status"] == "pass")
foundation_freeze_blocked_rows = sum(1 for row in foundation_freeze_rows if row["status"] == "blocked")
foundation_machine_freeze_ready = int(foundation_freeze_blocked_rows == 0)

claim_rows = [
    {
        "claim_id": "complete-source-machine-surface",
        "status": "allowed-limited" if machine_complete_source_surface_ready else "blocked",
        "reason": "10-repo complete-source query/scoring/review packet surface is machine-prepared, not human-reviewed",
    },
    {
        "claim_id": "human-reviewed-complete-source-audit",
        "status": "blocked",
        "reason": f"review_return_ready={review_return_ready}",
    },
    {
        "claim_id": "30b-150b-quality-comparison",
        "status": "blocked",
        "reason": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}",
    },
    {
        "claim_id": "v53-ready",
        "status": "blocked",
        "reason": f"v53_ready={v53_ready}",
    },
    {
        "claim_id": "pm-v53-freeze",
        "status": "allowed-limited" if pm_v53_freeze_ready else "blocked",
        "reason": f"pm_v53_freeze_ready={pm_v53_freeze_ready}; pm_freeze_blocked_rows={pm_freeze_blocked_rows}",
    },
    {
        "claim_id": "release-ready",
        "status": "blocked",
        "reason": "real_release_package_ready=0",
    },
]
write_csv(run_dir / "complete_source_audit_claim_rows.csv", list(claim_rows[0].keys()), claim_rows)

metric = {
    "metric_id": "v53t_complete_source_audit_readiness_gate_metrics",
    "v52y_f_optional_final_policy_ready": v52y["v52y_f_optional_final_policy_ready"],
    "f_optional_final_disposition": v52y["f_optional_final_disposition"],
    "v53i_complete_source_query_instantiation_ready": v53i["v53i_complete_source_query_instantiation_ready"],
    "v53q_complete_source_symmetric_scorer_policy_ready": v53q["v53q_complete_source_symmetric_scorer_policy_ready"],
    "v53ap_complete_source_abgh_same_query_measured_ready": v53ap["v53ap_complete_source_abgh_same_query_measured_ready"],
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "complete_source_repo_count": v53i["repo_count"],
    "complete_source_query_rows": v53i["complete_source_query_rows"],
    "complete_source_span_rows": v53i["complete_source_span_rows"],
    "core_system_count": v53q["core_system_count"],
    "core_answer_rows": v53q["core_answer_rows"],
    "symmetric_scorer_rows": v53q["symmetric_scorer_rows"],
    "symmetric_policy_rows": v53q["symmetric_policy_rows"],
    "review_packet_ready": v53r["review_packet_ready"],
    "expected_human_review_rows": v53s["expected_human_review_rows"],
    "accepted_human_review_rows": v53s["accepted_human_review_rows"],
    "expected_adjudication_rows": v53s["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53s["accepted_adjudication_rows"],
    "machine_complete_source_surface_ready": str(machine_complete_source_surface_ready),
    "review_return_ready": str(review_return_ready),
    "human_review_completed": v53s["human_review_completed"],
    "adjudication_completed": v53s["adjudication_completed"],
    "quality_comparison_claim_ready": "0",
    "v53_ready": str(v53_ready),
    "pm_v53_freeze_ready": str(pm_v53_freeze_ready),
    "pm_freeze_check_rows": str(len(pm_freeze_checks)),
    "pm_freeze_pass_rows": str(pm_freeze_pass_rows),
    "pm_freeze_blocked_rows": str(pm_freeze_blocked_rows),
    "foundation_freeze_certificate_rows": str(len(foundation_freeze_rows)),
    "foundation_freeze_pass_rows": str(foundation_freeze_pass_rows),
    "foundation_freeze_blocked_rows": str(foundation_freeze_blocked_rows),
    "foundation_machine_freeze_ready": str(foundation_machine_freeze_ready),
    "unsupported_control_rows": str(unsupported_control_rows),
    "ambiguous_control_rows": str(ambiguous_control_rows),
    "missing_specific_control_rows": str(missing_specific_control_rows),
    "doc_code_conflict_rows": str(doc_code_conflict_rows),
    "same_complete_source_query_hash": str(same_complete_source_query_hash),
    "current_v53i_query_rows_sha256": current_v53i_query_rows_sha256,
    "v53ap_query_rows_sha256": v53ap_query_rows_sha256,
    "abgh_same_query_ready": str(abgh_same_query_ready),
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(run_dir / "complete_source_audit_readiness_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52y-f-final-policy-input", "status": "pass", "reason": f"f_optional_final_disposition={v52y['f_optional_final_disposition']}"},
    {"gate": "v53i-complete-source-query-input", "status": "pass", "reason": f"complete_source_query_rows={v53i['complete_source_query_rows']}"},
    {"gate": "v53ap-abgh-same-query-input", "status": "pass" if abgh_same_query_ready else "blocked", "reason": f"abgh_same_query_ready={abgh_same_query_ready}; same_complete_source_query_hash={same_complete_source_query_hash}"},
    {"gate": "v53q-core-scorer-policy-input", "status": "pass", "reason": f"core_answer_rows={v53q['core_answer_rows']}"},
    {"gate": "v53r-review-packet-input", "status": "pass", "reason": f"review_packet_ready={v53r['review_packet_ready']}"},
    {"gate": "machine-complete-source-surface", "status": "pass" if machine_complete_source_surface_ready else "blocked", "reason": f"machine_complete_source_surface_ready={machine_complete_source_surface_ready}"},
    {"gate": "v53s-review-return-input", "status": "blocked" if review_return_ready == 0 else "pass", "reason": f"review_return_ready={review_return_ready}"},
    {"gate": "human-reviewed-audit", "status": "blocked", "reason": f"accepted_human_review_rows={v53s['accepted_human_review_rows']}/{v53s['expected_human_review_rows']}"},
    {"gate": "quality-comparison-claim", "status": "blocked", "reason": "quality comparison waits for accepted review return and final audit"},
    {"gate": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53_ready}"},
    {"gate": "pm-v53-freeze", "status": "pass" if pm_v53_freeze_ready else "blocked", "reason": f"pm_freeze_blocked_rows={pm_freeze_blocked_rows}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v53t is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53t Complete Source Audit Readiness Gate Boundary

This layer audits whether the v53 complete-source path is ready for a v1.0
comparison claim. It confirms the machine-prepared surface and keeps human
review, comparison, v53 readiness, and release claims blocked until real
returned review artifacts are accepted.

Evidence emitted:

- f_optional_final_disposition={v52y['f_optional_final_disposition']}
- complete_source_repo_count={v53i['repo_count']}
- complete_source_query_rows={v53i['complete_source_query_rows']}
- core_answer_rows={v53q['core_answer_rows']}
- symmetric_scorer_rows={v53q['symmetric_scorer_rows']}
- review_packet_ready={v53r['review_packet_ready']}
- expected_human_review_rows={v53s['expected_human_review_rows']}
- accepted_human_review_rows={v53s['accepted_human_review_rows']}
- expected_adjudication_rows={v53s['expected_adjudication_rows']}
- accepted_adjudication_rows={v53s['accepted_adjudication_rows']}
- machine_complete_source_surface_ready={machine_complete_source_surface_ready}
- review_return_ready={review_return_ready}
- quality_comparison_claim_ready=0
- v53_ready={v53_ready}
- pm_v53_freeze_ready={pm_v53_freeze_ready}
- pm_freeze_check_rows={len(pm_freeze_checks)}
- pm_freeze_blocked_rows={pm_freeze_blocked_rows}
- foundation_freeze_certificate_rows={len(foundation_freeze_rows)}
- foundation_machine_freeze_ready={foundation_machine_freeze_ready}
- unsupported_control_rows={unsupported_control_rows}
- missing_specific_control_rows={missing_specific_control_rows}
- doc_code_conflict_rows={doc_code_conflict_rows}
- same_complete_source_query_hash={same_complete_source_query_hash}
- abgh_same_query_ready={abgh_same_query_ready}
- v1_0_comparison_ready=0
- real_release_package_ready=0

Allowed wording: machine-prepared PM-freeze complete-source benchmark surface
over 10 locked repositories, 1000 source-span-bound queries, explicit
unsupported/missing/doc-code-conflict controls, and internal A/B/G/H
same-query pre-baseline rows.

Blocked wording: human-reviewed complete-source audit, 30B-150B quality
comparison, v53 readiness, v1.0 comparison readiness, production readiness, or
release readiness.
"""
(run_dir / "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53t-complete-source-audit-readiness-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53t_complete_source_audit_readiness_gate_ready": 1,
    "v52y_summary_sha256": sha256(summary_paths["v52y"]),
    "v53ap_summary_sha256": sha256(summary_paths["v53ap"]),
    "v53s_summary_sha256": sha256(summary_paths["v53s"]),
    "machine_complete_source_surface_ready": machine_complete_source_surface_ready,
    "review_return_ready": review_return_ready,
    "quality_comparison_claim_ready": 0,
    "v53_ready": v53_ready,
    "pm_v53_freeze_ready": pm_v53_freeze_ready,
    "pm_freeze_blocked_rows": pm_freeze_blocked_rows,
    "foundation_freeze_certificate_rows": len(foundation_freeze_rows),
    "foundation_freeze_blocked_rows": foundation_freeze_blocked_rows,
    "foundation_machine_freeze_ready": foundation_machine_freeze_ready,
    "missing_specific_control_rows": missing_specific_control_rows,
    "same_complete_source_query_hash": same_complete_source_query_hash,
    "current_v53i_query_rows_sha256": current_v53i_query_rows_sha256,
    "v53ap_query_rows_sha256": v53ap_query_rows_sha256,
    "abgh_same_query_ready": abgh_same_query_ready,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53t_complete_source_audit_readiness_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53t_complete_source_audit_readiness_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
