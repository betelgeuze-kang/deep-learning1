#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53r_complete_source_review_packet"
RUN_ID="${V53R_RUN_ID:-review_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53R_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53r_complete_source_review_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53q_complete_source_symmetric_scorer_policy.sh" >/dev/null

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
v53q_dir = results / "v53q_complete_source_symmetric_scorer_policy" / "score_001"

CORE_SYSTEMS = ["A", "B", "C", "D", "E", "G", "H"]


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


def priority_for(answer_hash_match, abstain_policy_pass, negative_or_abstain):
    if answer_hash_match == "0" or abstain_policy_pass == "0":
        return "p0_answer_or_policy_mismatch", "hash/policy mismatch requires adjudication"
    if negative_or_abstain == "1":
        return "p1_negative_abstain_review", "negative/abstain query requires explicit source-policy review"
    return "p2_regular_source_review", "regular source/citation/resource spot review"


def priority_order(priority_class):
    if priority_class.startswith("p0_"):
        return 0
    if priority_class.startswith("p1_"):
        return 1
    return 2


v53q_summary = read_csv(results / "v53q_complete_source_symmetric_scorer_policy_summary.csv")[0]
if v53q_summary.get("v53q_complete_source_symmetric_scorer_policy_ready") != "1":
    raise SystemExit("v53r requires v53q_complete_source_symmetric_scorer_policy_ready=1")
if v53q_summary.get("symmetric_scorer_policy_rows_ready") != "1":
    raise SystemExit("v53r requires symmetric_scorer_policy_rows_ready=1")

for src, rel in [
    (results / "v53q_complete_source_symmetric_scorer_policy_summary.csv", "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv"),
    (results / "v53q_complete_source_symmetric_scorer_policy_decision.csv", "source_v53q/v53q_complete_source_symmetric_scorer_policy_decision.csv"),
    (v53q_dir / "symmetric_scorer_rows.csv", "source_v53q/symmetric_scorer_rows.csv"),
    (v53q_dir / "symmetric_domain_policy_rows.csv", "source_v53q/symmetric_domain_policy_rows.csv"),
    (v53q_dir / "symmetric_system_metric_rows.csv", "source_v53q/symmetric_system_metric_rows.csv"),
    (v53q_dir / "symmetric_query_metric_rows.csv", "source_v53q/symmetric_query_metric_rows.csv"),
    (v53q_dir / "symmetric_policy_summary_rows.csv", "source_v53q/symmetric_policy_summary_rows.csv"),
    (v53q_dir / "symmetric_scorer_policy_validation_rows.csv", "source_v53q/symmetric_scorer_policy_validation_rows.csv"),
    (v53q_dir / "V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md", "source_v53q/V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md"),
    (v53q_dir / "v53q_complete_source_symmetric_scorer_policy_manifest.json", "source_v53q/v53q_complete_source_symmetric_scorer_policy_manifest.json"),
    (v53q_dir / "sha256_manifest.csv", "source_v53q/sha256_manifest.csv"),
    (v53q_dir / "source_v53p/supplied_v53j/answer_rows.csv", "source_v53q/source_v53p/supplied_v53j/answer_rows.csv"),
    (v53q_dir / "source_v53p/supplied_v53j/citation_rows.csv", "source_v53q/source_v53p/supplied_v53j/citation_rows.csv"),
    (v53q_dir / "source_v53p/supplied_v53j/resource_rows.csv", "source_v53q/source_v53p/supplied_v53j/resource_rows.csv"),
    (
        v53q_dir / "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
        "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    ),
    (
        v53q_dir / "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
        "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    ),
]:
    copy(src, rel)

answer_rows = read_csv(v53q_dir / "source_v53p/supplied_v53j/answer_rows.csv")
citation_rows = read_csv(v53q_dir / "source_v53p/supplied_v53j/citation_rows.csv")
resource_rows = read_csv(v53q_dir / "source_v53p/supplied_v53j/resource_rows.csv")
scorer_rows = read_csv(v53q_dir / "symmetric_scorer_rows.csv")
policy_rows = read_csv(v53q_dir / "symmetric_domain_policy_rows.csv")
system_metric_rows = read_csv(v53q_dir / "symmetric_system_metric_rows.csv")
query_metric_rows = read_csv(v53q_dir / "symmetric_query_metric_rows.csv")
query_rows = read_csv(v53q_dir / "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")
span_rows = read_csv(v53q_dir / "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")

if len(answer_rows) != 7000 or len(citation_rows) != 7000 or len(resource_rows) != 7000:
    raise SystemExit("v53r requires 7000 answer/citation/resource rows")
if len(scorer_rows) != 7000 or len(policy_rows) != 7000:
    raise SystemExit("v53r requires 7000 scorer/policy rows")
if len(query_rows) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v53r requires the frozen v53i 1000-query set")

query_by_id = {row["query_id"]: row for row in query_rows}
span_by_id = {row["source_span_id"]: row for row in span_rows}
citation_by_answer = {row["answer_id"]: row for row in citation_rows}
resource_by_answer = {row["answer_id"]: row for row in resource_rows}
scorer_by_answer = {row["answer_id"]: row for row in scorer_rows}
policy_by_answer = {row["answer_id"]: row for row in policy_rows}

answers_by_query = defaultdict(list)
answers_by_repo = defaultdict(list)
answers_by_system = defaultdict(list)
for row in answer_rows:
    answers_by_query[row["query_id"]].append(row)
    answers_by_repo[row["owner_repo"]].append(row)
    answers_by_system[row["system_id"]].append(row)

query_packets = []
for query in query_rows:
    qid = query["query_id"]
    span = span_by_id[query["source_span_id"]]
    qmetric = next(row for row in query_metric_rows if row["query_id"] == qid)
    query_packets.append(
        {
            "review_query_packet_id": f"v53r_query_packet_{qid}",
            "query_id": qid,
            "owner_repo": query["owner_repo"],
            "head_sha": query["head_sha"],
            "audit_type": query["audit_type"],
            "expected_behavior": query["expected_behavior"],
            "negative_or_abstain": query["negative_or_abstain"],
            "question_sha256": sha256_text(query["question"]),
            "expected_answer_sha256": query["expected_answer_sha256"],
            "source_span_id": query["source_span_id"],
            "source_path": query["source_path"],
            "source_line_start": query["source_line_start"],
            "source_line_end": query["source_line_end"],
            "source_file_sha256": query["source_file_sha256"],
            "evidence_text_sha256": span["evidence_text_sha256"],
            "core_answer_rows": str(len(answers_by_query[qid])),
            "answer_hash_match_rows": qmetric["answer_hash_match_rows"],
            "citation_span_match_rows": qmetric["citation_span_match_rows"],
            "resource_row_bound_rows": qmetric["resource_row_bound_rows"],
            "abstain_policy_pass_rows": qmetric["abstain_policy_pass_rows"],
            "all_core_systems_scored": qmetric["all_core_systems_scored"],
            "human_review_required": "1",
            "review_artifact_supplied": "0",
            "human_review_completed": "0",
        }
    )

answer_packets = []
queue_unranked = []
priority_counts = Counter()
for row in answer_rows:
    answer_id = row["answer_id"]
    query = query_by_id[row["query_id"]]
    citation = citation_by_answer[answer_id]
    resource = resource_by_answer[answer_id]
    scorer = scorer_by_answer[answer_id]
    policy = policy_by_answer[answer_id]
    priority_class, priority_reason = priority_for(
        scorer["answer_hash_match"],
        policy["abstain_policy_pass"],
        query["negative_or_abstain"],
    )
    priority_counts[priority_class] += 1
    packet_id = f"v53r_answer_packet_{answer_id}"
    answer_packets.append(
        {
            "review_answer_packet_id": packet_id,
            "answer_id": answer_id,
            "system_id": row["system_id"],
            "query_id": row["query_id"],
            "owner_repo": row["owner_repo"],
            "audit_type": row["audit_type"],
            "source_span_id": row["source_span_id"],
            "answer_text_sha256": row["answer_text_sha256"],
            "expected_answer_sha256": scorer["expected_answer_sha256"],
            "answer_hash_match": scorer["answer_hash_match"],
            "expected_behavior": scorer["expected_behavior"],
            "predicted_behavior": scorer["predicted_behavior"],
            "predicted_behavior_match": scorer["predicted_behavior_match"],
            "abstained": scorer["abstained"],
            "citation_id": citation["citation_id"],
            "citation_span_match": scorer["citation_span_match"],
            "citation_text_hash_match": scorer["citation_text_hash_match"],
            "source_file_hash_match": scorer["source_file_hash_match"],
            "resource_row_id": resource["resource_row_id"],
            "resource_row_bound": scorer["resource_row_bound"],
            "domain_policy": policy["domain_policy"],
            "abstain_policy_pass": policy["abstain_policy_pass"],
            "source_verified_score": scorer["source_verified_score"],
            "symmetric_total_score": scorer["symmetric_total_score"],
            "priority_class": priority_class,
            "priority_reason": priority_reason,
            "review_artifact_supplied": "0",
            "human_review_completed": "0",
            "quality_comparison_claim_ready": "0",
        }
    )
    queue_unranked.append(
        {
            "review_queue_id": f"v53r_queue_{answer_id}",
            "review_answer_packet_id": packet_id,
            "answer_id": answer_id,
            "system_id": row["system_id"],
            "query_id": row["query_id"],
            "owner_repo": row["owner_repo"],
            "priority_class": priority_class,
            "priority_reason": priority_reason,
            "review_task": "answer-source-policy-adjudication",
            "required_reviewer_count": "2" if priority_class.startswith("p0_") else "1",
            "review_artifact_supplied": "0",
            "queue_status": "pending-human-review",
        }
    )

write_csv(run_dir / "review_query_packet_rows.csv", list(query_packets[0].keys()), query_packets)
write_csv(run_dir / "review_answer_packet_rows.csv", list(answer_packets[0].keys()), answer_packets)

queue_rows = []
for rank, row in enumerate(
    sorted(queue_unranked, key=lambda item: (priority_order(item["priority_class"]), item["query_id"], item["system_id"])),
    start=1,
):
    ranked = {"review_priority_rank": str(rank), **row}
    queue_rows.append(ranked)
write_csv(run_dir / "review_queue_rows.csv", list(queue_rows[0].keys()), queue_rows)

repo_packets = []
for repo in sorted(answers_by_repo):
    repo_queries = [row for row in query_rows if row["owner_repo"] == repo]
    repo_answers = answers_by_repo[repo]
    repo_queue = [row for row in queue_rows if row["owner_repo"] == repo]
    repo_packets.append(
        {
            "review_repo_packet_id": f"v53r_repo_packet_{repo.replace('/', '_')}",
            "owner_repo": repo,
            "query_rows": str(len(repo_queries)),
            "answer_rows": str(len(repo_answers)),
            "queue_rows": str(len(repo_queue)),
            "p0_queue_rows": str(sum(1 for row in repo_queue if row["priority_class"].startswith("p0_"))),
            "negative_or_abstain_query_rows": str(sum(1 for row in repo_queries if row["negative_or_abstain"] == "1")),
            "human_review_required": "1",
            "review_artifact_supplied": "0",
        }
    )
write_csv(run_dir / "review_repo_packet_rows.csv", list(repo_packets[0].keys()), repo_packets)

system_packets = []
for metric in system_metric_rows:
    system_id = metric["system_id"]
    system_queue = [row for row in queue_rows if row["system_id"] == system_id]
    system_packets.append(
        {
            "review_system_packet_id": f"v53r_system_packet_{system_id}",
            "system_id": system_id,
            "answer_rows": metric["answer_rows"],
            "answer_hash_match_rows": metric["answer_hash_match_rows"],
            "answer_hash_mismatch_rows": metric["answer_hash_mismatch_rows"],
            "abstain_policy_pass_rows": metric["abstain_policy_pass_rows"],
            "citation_span_match_rows": metric["citation_span_match_rows"],
            "resource_row_bound_rows": metric["resource_row_bound_rows"],
            "queue_rows": str(len(system_queue)),
            "p0_queue_rows": str(sum(1 for row in system_queue if row["priority_class"].startswith("p0_"))),
            "avg_symmetric_total_score": metric["avg_symmetric_total_score"],
            "human_review_required": "1",
            "review_artifact_supplied": "0",
            "quality_comparison_claim_ready": "0",
        }
    )
write_csv(run_dir / "review_system_packet_rows.csv", list(system_packets[0].keys()), system_packets)

assignment_rows = []
reviewer_slots = [
    ("reviewer_slot_1", "primary-source-review"),
    ("reviewer_slot_2", "secondary-adjudication-review"),
    ("reviewer_slot_3", "conflict-and-policy-review"),
]
for system_id in CORE_SYSTEMS:
    for reviewer_slot, scope in reviewer_slots:
        assignment_rows.append(
            {
                "assignment_id": f"v53r_assignment_{system_id}_{reviewer_slot}",
                "reviewer_slot_id": reviewer_slot,
                "review_scope": scope,
                "system_id": system_id,
                "assigned_answer_rows": str(len(answers_by_system[system_id])),
                "assigned_query_rows": "1000",
                "reviewer_identity_supplied": "0",
                "review_artifact_supplied": "0",
                "assignment_status": "pending-human-review",
            }
        )
write_csv(run_dir / "reviewer_assignment_template_rows.csv", list(assignment_rows[0].keys()), assignment_rows)

return_template_rows = [
    ("human_review_rows.csv", "required", "per-answer human source/policy judgments"),
    ("adjudication_rows.csv", "required", "p0 mismatch and policy-conflict adjudication rows"),
    ("reviewer_identity_rows.csv", "required", "reviewer identity and independence declarations"),
    ("reviewer_conflict_rows.csv", "required", "conflict disclosure rows"),
    ("acceptance_summary.json", "required", "review acceptance summary with artifact hashes"),
]
write_csv(
    run_dir / "review_return_template_rows.csv",
    ["return_artifact", "requirement_status", "purpose", "supplied", "accepted"],
    [
        {
            "return_artifact": artifact,
            "requirement_status": status,
            "purpose": purpose,
            "supplied": "0",
            "accepted": "0",
        }
        for artifact, status, purpose in return_template_rows
    ],
)

acceptance_rows = [
    ("v53q-symmetric-scorer-policy-input", "pass", "v53q scorer/policy packet is bound"),
    ("frozen-complete-source-query-set", "pass", "1000 v53i complete-source query rows are bound"),
    ("core-answer-review-packet", "pass", "7000 A/B/C/D/E/G/H answer review packets are present"),
    ("review-queue-coverage", "pass", "every answer packet has a pending review queue row"),
    ("reviewer-return-template", "pass", "required return artifact templates are emitted"),
    ("human-review-artifacts", "blocked", "returned human review artifacts are not supplied"),
    ("adjudication-artifacts", "blocked", "returned adjudication artifacts are not supplied"),
    ("quality-comparison-claim", "blocked", "review packet preparation is not a quality comparison"),
    ("v53-ready", "blocked", "review artifacts and release evidence are still required"),
]
write_csv(
    run_dir / "review_acceptance_criteria_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in acceptance_rows],
)

metric_rows = [
    {
        "complete_source_query_rows": str(len(query_packets)),
        "core_answer_rows": str(len(answer_packets)),
        "review_queue_rows": str(len(queue_rows)),
        "review_repo_packet_rows": str(len(repo_packets)),
        "review_system_packet_rows": str(len(system_packets)),
        "review_assignment_template_rows": str(len(assignment_rows)),
        "review_return_template_rows": str(len(return_template_rows)),
        "priority_p0_review_rows": str(priority_counts["p0_answer_or_policy_mismatch"]),
        "priority_p1_review_rows": str(priority_counts["p1_negative_abstain_review"]),
        "priority_p2_review_rows": str(priority_counts["p2_regular_source_review"]),
        "review_packet_ready": "1",
        "review_artifacts_ready": "0",
        "human_review_completed": "0",
        "quality_comparison_claim_ready": "0",
    }
]
write_csv(run_dir / "review_packet_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

(run_dir / "REVIEW_PACKET_README.md").write_text(
    "# v53r Complete Source Review Packet\n\n"
    "This packet prepares the v53q complete-source scorer/policy evidence for human review. "
    "It does not contain returned human review judgments and does not open a quality, comparison, or release claim.\n\n"
    "Review flow:\n\n"
    "1. Use `review_query_packet_rows.csv` and `review_answer_packet_rows.csv` as the frozen review surface.\n"
    "2. Work through `review_queue_rows.csv` in priority order.\n"
    "3. Return the artifacts listed in `review_return_template_rows.csv`.\n"
    "4. Re-run the future review-intake verifier before any `v53_ready` or comparison claim is considered.\n",
    encoding="utf-8",
)

review_packet_ready = int(
    len(query_packets) == 1000
    and len(answer_packets) == 7000
    and len(queue_rows) == 7000
    and len(repo_packets) == 10
    and len(system_packets) == 7
)
summary = {
    "v53r_complete_source_review_packet_ready": str(review_packet_ready),
    "v53_ready": "0",
    "v53q_complete_source_symmetric_scorer_policy_ready": v53q_summary["v53q_complete_source_symmetric_scorer_policy_ready"],
    "complete_source_query_rows": str(len(query_packets)),
    "core_system_count": str(len(CORE_SYSTEMS)),
    "core_answer_rows": str(len(answer_packets)),
    "review_query_packet_rows": str(len(query_packets)),
    "review_answer_packet_rows": str(len(answer_packets)),
    "review_queue_rows": str(len(queue_rows)),
    "review_repo_packet_rows": str(len(repo_packets)),
    "review_system_packet_rows": str(len(system_packets)),
    "review_assignment_template_rows": str(len(assignment_rows)),
    "review_return_template_rows": str(len(return_template_rows)),
    "priority_p0_review_rows": str(priority_counts["p0_answer_or_policy_mismatch"]),
    "priority_p1_review_rows": str(priority_counts["p1_negative_abstain_review"]),
    "priority_p2_review_rows": str(priority_counts["p2_regular_source_review"]),
    "answer_citation_resource_rows_ready": v53q_summary["answer_citation_resource_rows_ready"],
    "symmetric_scorer_policy_rows_ready": v53q_summary["symmetric_scorer_policy_rows_ready"],
    "review_packet_ready": str(review_packet_ready),
    "review_artifacts_ready": "0",
    "human_review_completed": "0",
    "quality_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53q-symmetric-scorer-policy-input", "pass", "v53q complete-source scorer/policy packet is bound"),
    ("frozen-complete-source-query-set", "pass", "1000 frozen v53i queries are included"),
    ("core-answer-review-packet", "pass" if len(answer_packets) == 7000 else "blocked", f"review_answer_packet_rows={len(answer_packets)}"),
    ("review-queue-coverage", "pass" if len(queue_rows) == len(answer_packets) else "blocked", f"review_queue_rows={len(queue_rows)}"),
    ("reviewer-return-template", "pass", f"review_return_template_rows={len(return_template_rows)}"),
    ("review-packet-ready", "pass" if review_packet_ready else "blocked", "query, answer, repo, system, and queue packets are present"),
    ("human-review-artifacts", "blocked", "returned human/source review artifacts are not supplied"),
    ("adjudication-artifacts", "blocked", "returned adjudication artifacts are not supplied"),
    ("quality-comparison-claim", "blocked", "review packet preparation is not a reviewed quality result"),
    ("v53-full-public-repo-audit", "blocked", "review return artifacts are still required"),
    ("real-release-package", "blocked", "v53r is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md").write_text(
    "# v53r Complete Source Review Packet Boundary\n\n"
    "This layer turns the v53q complete-source scorer/policy evidence into a frozen review packet. "
    "It prepares query, answer, repository, system, priority-queue, assignment-template, and return-template rows for human review. "
    "It does not supply or accept returned human review evidence.\n\n"
    f"- complete_source_query_rows={len(query_packets)}\n"
    f"- core_answer_rows={len(answer_packets)}\n"
    f"- review_query_packet_rows={len(query_packets)}\n"
    f"- review_answer_packet_rows={len(answer_packets)}\n"
    f"- review_queue_rows={len(queue_rows)}\n"
    f"- priority_p0_review_rows={priority_counts['p0_answer_or_policy_mismatch']}\n"
    f"- priority_p1_review_rows={priority_counts['p1_negative_abstain_review']}\n"
    f"- priority_p2_review_rows={priority_counts['p2_regular_source_review']}\n"
    f"- review_packet_ready={review_packet_ready}\n"
    "- review_artifacts_ready=0\n"
    "- human_review_completed=0\n"
    "- quality_comparison_claim_ready=0\n"
    "- v53_ready=0\n\n"
    "Allowed wording: complete-source review packet and pending human/source review queue. "
    "Blocked wording: human-reviewed result, quality comparison, v53 full audit readiness, v1.0 comparison readiness, production readiness, or release readiness.\n",
    encoding="utf-8",
)

artifact_rels = [
    "review_query_packet_rows.csv",
    "review_answer_packet_rows.csv",
    "review_queue_rows.csv",
    "review_repo_packet_rows.csv",
    "review_system_packet_rows.csv",
    "reviewer_assignment_template_rows.csv",
    "review_return_template_rows.csv",
    "review_acceptance_criteria_rows.csv",
    "review_packet_metric_rows.csv",
    "REVIEW_PACKET_README.md",
    "V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md",
    "v53r_complete_source_review_packet_manifest.json",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_decision.csv",
    "source_v53q/symmetric_scorer_rows.csv",
    "source_v53q/symmetric_domain_policy_rows.csv",
    "source_v53q/symmetric_system_metric_rows.csv",
    "source_v53q/symmetric_query_metric_rows.csv",
    "source_v53q/symmetric_policy_summary_rows.csv",
    "source_v53q/symmetric_scorer_policy_validation_rows.csv",
    "source_v53q/V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_manifest.json",
    "source_v53q/sha256_manifest.csv",
    "source_v53q/source_v53p/supplied_v53j/answer_rows.csv",
    "source_v53q/source_v53p/supplied_v53j/citation_rows.csv",
    "source_v53q/source_v53p/supplied_v53j/resource_rows.csv",
    "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]

manifest = {
    "manifest_scope": "v53r-complete-source-review-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53r_complete_source_review_packet_ready": review_packet_ready,
    "v53_ready": 0,
    "v53q_summary_sha256": sha256(results / "v53q_complete_source_symmetric_scorer_policy_summary.csv"),
    "complete_source_query_rows": len(query_packets),
    "core_systems": CORE_SYSTEMS,
    "core_answer_rows": len(answer_packets),
    "review_queue_rows": len(queue_rows),
    "priority_p0_review_rows": priority_counts["p0_answer_or_policy_mismatch"],
    "priority_p1_review_rows": priority_counts["p1_negative_abstain_review"],
    "priority_p2_review_rows": priority_counts["p2_regular_source_review"],
    "review_packet_ready": review_packet_ready,
    "review_artifacts_ready": 0,
    "human_review_completed": 0,
    "quality_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53r_complete_source_review_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

index_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    index_rows.append(
        {
            "packet_artifact": rel,
            "sha256": sha256(path),
            "bytes": str(path.stat().st_size),
            "review_packet_artifact": "1",
            "human_review_return_artifact": "0",
        }
    )
write_csv(run_dir / "review_packet_index_rows.csv", list(index_rows[0].keys()), index_rows)

artifact_rels_with_index = artifact_rels + ["review_packet_index_rows.csv"]
artifact_rows = []
for rel in artifact_rels_with_index:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53r_complete_source_review_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
