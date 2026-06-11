#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53r_complete_source_review_packet/review_001"
SUMMARY_CSV="$RESULTS_DIR/v53r_complete_source_review_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53r_complete_source_review_packet_decision.csv"

V53R_REUSE_EXISTING="${V53R_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
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


summary = read_csv(summary_csv)[0]
expected = {
    "v53r_complete_source_review_packet_ready": "1",
    "v53_ready": "0",
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "complete_source_query_rows": "1000",
    "core_system_count": "7",
    "core_answer_rows": "7000",
    "review_query_packet_rows": "1000",
    "review_answer_packet_rows": "7000",
    "review_queue_rows": "7000",
    "review_repo_packet_rows": "10",
    "review_system_packet_rows": "7",
    "review_assignment_template_rows": "21",
    "review_return_template_rows": "5",
    "priority_p0_review_rows": "1000",
    "priority_p1_review_rows": "960",
    "priority_p2_review_rows": "5040",
    "answer_citation_resource_rows_ready": "1",
    "symmetric_scorer_policy_rows_ready": "1",
    "review_packet_ready": "1",
    "review_artifacts_ready": "0",
    "human_review_completed": "0",
    "quality_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53r {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53q-symmetric-scorer-policy-input",
    "frozen-complete-source-query-set",
    "core-answer-review-packet",
    "review-queue-coverage",
    "reviewer-return-template",
    "review-packet-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53r gate should pass: {gate}")
for gate in [
    "human-review-artifacts",
    "adjudication-artifacts",
    "quality-comparison-claim",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53r gate should remain blocked: {gate}")

required_files = [
    "review_query_packet_rows.csv",
    "review_answer_packet_rows.csv",
    "review_queue_rows.csv",
    "review_repo_packet_rows.csv",
    "review_system_packet_rows.csv",
    "reviewer_assignment_template_rows.csv",
    "review_return_template_rows.csv",
    "review_acceptance_criteria_rows.csv",
    "review_packet_metric_rows.csv",
    "review_packet_index_rows.csv",
    "REVIEW_PACKET_README.md",
    "V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md",
    "v53r_complete_source_review_packet_manifest.json",
    "sha256_manifest.csv",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "source_v53q/symmetric_scorer_rows.csv",
    "source_v53q/symmetric_domain_policy_rows.csv",
    "source_v53q/source_v53p/supplied_v53j/answer_rows.csv",
    "source_v53q/source_v53p/supplied_v53j/citation_rows.csv",
    "source_v53q/source_v53p/supplied_v53j/resource_rows.csv",
    "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53q/source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53r artifact: {rel}")

query_packets = read_csv(run_dir / "review_query_packet_rows.csv")
answer_packets = read_csv(run_dir / "review_answer_packet_rows.csv")
queue_rows = read_csv(run_dir / "review_queue_rows.csv")
repo_packets = read_csv(run_dir / "review_repo_packet_rows.csv")
system_packets = {row["system_id"]: row for row in read_csv(run_dir / "review_system_packet_rows.csv")}
assignments = read_csv(run_dir / "reviewer_assignment_template_rows.csv")
return_templates = read_csv(run_dir / "review_return_template_rows.csv")
criteria = {row["gate"]: row["status"] for row in read_csv(run_dir / "review_acceptance_criteria_rows.csv")}
metric = read_csv(run_dir / "review_packet_metric_rows.csv")[0]

if len(query_packets) != 1000 or len(answer_packets) != 7000 or len(queue_rows) != 7000:
    raise SystemExit("v53r review packet row counts mismatch")
if len(repo_packets) != 10 or len(system_packets) != 7:
    raise SystemExit("v53r repo/system packet counts mismatch")
if len(assignments) != 21 or len(return_templates) != 5:
    raise SystemExit("v53r assignment/template counts mismatch")

priority_counts = Counter(row["priority_class"] for row in queue_rows)
if priority_counts["p0_answer_or_policy_mismatch"] != 1000:
    raise SystemExit("v53r p0 queue count mismatch")
if priority_counts["p1_negative_abstain_review"] != 960:
    raise SystemExit("v53r p1 queue count mismatch")
if priority_counts["p2_regular_source_review"] != 5040:
    raise SystemExit("v53r p2 queue count mismatch")
if queue_rows[0]["priority_class"] != "p0_answer_or_policy_mismatch":
    raise SystemExit("v53r queue should start with p0 rows")

for row in answer_packets:
    if row["review_artifact_supplied"] != "0" or row["human_review_completed"] != "0":
        raise SystemExit("v53r answer packets should remain pending human review")
    if row["citation_span_match"] != "1" or row["resource_row_bound"] != "1":
        raise SystemExit("v53r answer packet source/resource binding mismatch")
    if row["quality_comparison_claim_ready"] != "0":
        raise SystemExit("v53r answer packet should not claim quality readiness")
for row in query_packets:
    if row["core_answer_rows"] != "7" or row["all_core_systems_scored"] != "1":
        raise SystemExit("v53r query packet core coverage mismatch")
    if row["review_artifact_supplied"] != "0" or row["human_review_completed"] != "0":
        raise SystemExit("v53r query packet should remain pending review")
for row in repo_packets:
    if row["query_rows"] != "100" or row["answer_rows"] != "700":
        raise SystemExit("v53r repo packet coverage mismatch")
for system_id in ["A", "B", "D", "E", "G", "H"]:
    if system_packets[system_id]["p0_queue_rows"] != "0":
        raise SystemExit(f"v53r {system_id} should not have p0 rows")
if system_packets["C"]["p0_queue_rows"] != "1000" or system_packets["C"]["answer_hash_mismatch_rows"] != "1000":
    raise SystemExit("v53r System C p0 coverage mismatch")
for row in assignments:
    if row["assignment_status"] != "pending-human-review" or row["review_artifact_supplied"] != "0":
        raise SystemExit("v53r assignment templates should remain pending")
for row in return_templates:
    if row["requirement_status"] != "required" or row["supplied"] != "0" or row["accepted"] != "0":
        raise SystemExit("v53r return templates should require unsupplied artifacts")

for gate in [
    "v53q-symmetric-scorer-policy-input",
    "frozen-complete-source-query-set",
    "core-answer-review-packet",
    "review-queue-coverage",
    "reviewer-return-template",
]:
    if criteria.get(gate) != "pass":
        raise SystemExit(f"v53r criterion should pass: {gate}")
for gate in ["human-review-artifacts", "adjudication-artifacts", "quality-comparison-claim", "v53-ready"]:
    if criteria.get(gate) != "blocked":
        raise SystemExit(f"v53r criterion should be blocked: {gate}")
if metric["review_packet_ready"] != "1" or metric["review_artifacts_ready"] != "0":
    raise SystemExit("v53r metric readiness mismatch")

manifest = json.loads((run_dir / "v53r_complete_source_review_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53r_complete_source_review_packet_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53r manifest readiness boundary mismatch")
if manifest.get("core_answer_rows") != 7000 or manifest.get("review_artifacts_ready") != 0:
    raise SystemExit("v53r manifest packet boundary mismatch")

boundary = (run_dir / "V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "core_answer_rows=7000",
    "review_queue_rows=7000",
    "priority_p0_review_rows=1000",
    "review_packet_ready=1",
    "review_artifacts_ready=0",
    "human_review_completed=0",
    "v53_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53r boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in sha_rows:
        raise SystemExit(f"v53r sha manifest missing: {rel}")
    if sha_rows[rel] != sha256(run_dir / rel):
        raise SystemExit(f"v53r sha256 mismatch: {rel}")
PY

echo "v53r complete-source review packet smoke passed"
