#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v58b_blind_eval_candidate_500/candidate_001"
SUMMARY_CSV="$RESULTS_DIR/v58b_blind_eval_candidate_500_summary.csv"
DECISION_CSV="$RESULTS_DIR/v58b_blind_eval_candidate_500_decision.csv"

"$ROOT_DIR/experiments/run_v58b_blind_eval_candidate_500.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
root = Path(sys.argv[4])

DOMAIN_TARGETS = {
    "codebase_qa": 180,
    "internal_docs_qa": 80,
    "ruler_niah": 80,
    "longbench_v2": 80,
    "incident_log_qa": 40,
    "product_manual_qa": 40,
}


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
    raise SystemExit(f"expected one v58b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v58b_dependency_blocker_ready") == "1":
    expected_blocked = {
        "v58b_blind_eval_candidate_ready": "0",
        "v58_ready": "0",
        "missing_dependency_artifact_rows": "7",
        "missing_v57_dependency_artifact_rows": "7",
        "implicit_dependency_rebuild_allowed": "0",
        "dependency_rebuild_approval_required": "1",
        "network_or_download_approval_required": "1",
        "frozen_query_rows": "0",
        "target_blind_eval_rows": "500",
        "blind_system_rows": "0",
        "blind_response_template_rows": "0",
        "actual_blind_response_rows": "0",
        "reviewer_packet_template_rows": "0",
        "sealed_answer_key_rows": "0",
        "sealed_identity_key_ready": "0",
        "query_freeze_ready": "0",
        "pre_output_query_selection_verified": "0",
        "same_evidence_budget_ready": "0",
        "reviewer_packet_anonymous": "0",
        "human_blind_review_ready": "0",
        "inter_rater_rows_ready": "0",
        "required_30b_blind_response_ready": "0",
        "required_70b_blind_response_ready": "0",
        "optional_100b_plus_blind_response_status": "blocked-until-v58b-seed",
        "v58_blind_eval_contract_ready": "0",
        "v57b_domain_expert_pack_candidate_ready": "0",
        "v58_full_blind_eval_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v58b dependency blocker {field}: expected {value}, got {summary.get(field)}")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    if decisions.get("dependency-blocker-artifact") != "pass":
        raise SystemExit("v58b dependency blocker artifact gate should pass")
    for gate in [
        "v58-contract-input",
        "v57b-candidate-input",
        "blind-query-freeze-candidate",
        "source-span-binding",
        "same-evidence-budget",
        "reviewer-packet-anonymization",
        "sealed-identity-key",
        "30b-blind-response-row",
        "70b-blind-response-row",
        "100b-plus-blind-response-row",
        "human-blind-review",
        "v58-full-blind-eval",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v58b dependency blocker should keep {gate} blocked")

    required_files = [
        "v58b_dependency_blocker_rows.csv",
        "v58_dependency_probe_stderr.txt",
        "V58B_BLIND_EVAL_CANDIDATE_DEPENDENCY_BLOCKER.md",
        "v58b_blind_eval_candidate_manifest.json",
        "sha256_manifest.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v58b dependency blocker artifact: {rel}")
    blocker_rows = read_csv(run_dir / "v58b_dependency_blocker_rows.csv")
    if len(blocker_rows) != 7:
        raise SystemExit("v58b dependency blocker should record seven missing v57 artifacts")
    for row in blocker_rows:
        if row["dependency_stage"] != "v57-domain-expert-pack-contract":
            raise SystemExit("v58b dependency blocker should point to v57 domain-pack contract")
        if row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1":
            raise SystemExit("v58b dependency blocker should refuse implicit rebuild and require approval")
        if row["network_or_download_risk"] != "1" or row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
            raise SystemExit("v58b dependency blocker claim boundary mismatch")
        if row["claim_boundary_status"] != "blocked-until-v57-v58-seed-artifact-present":
            raise SystemExit("v58b dependency blocker should keep claim boundary blocked")
    manifest = json.loads((run_dir / "v58b_blind_eval_candidate_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v58b_blind_eval_candidate_ready") != 0 or manifest.get("v58b_dependency_blocker_ready") != 1:
        raise SystemExit("v58b dependency blocker manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v58b dependency blocker sha256 mismatch: {rel}")
    boundary = (run_dir / "V58B_BLIND_EVAL_CANDIDATE_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in [
        "missing_dependency_artifact_rows=7",
        "implicit_dependency_rebuild_allowed=0",
        "frozen_query_rows=0",
        "Blocked wording: v58b candidate artifact ready",
    ]:
        if snippet not in boundary:
            raise SystemExit(f"v58b dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v58b_blind_eval_candidate_ready": "1",
    "v58_ready": "0",
    "frozen_query_rows": "500",
    "target_blind_eval_rows": "500",
    "blind_system_rows": "5",
    "blind_response_template_rows": "2500",
    "actual_blind_response_rows": "0",
    "reviewer_packet_template_rows": "2500",
    "sealed_answer_key_rows": "500",
    "sealed_identity_key_ready": "1",
    "query_freeze_ready": "1",
    "pre_output_query_selection_verified": "1",
    "same_evidence_budget_ready": "1",
    "reviewer_packet_anonymous": "1",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "required_30b_blind_response_ready": "0",
    "required_70b_blind_response_ready": "0",
    "optional_100b_plus_blind_response_status": "deferred-with-reason",
    "v58_blind_eval_contract_ready": "1",
    "v57b_domain_expert_pack_candidate_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v58b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "blind-query-freeze-candidate",
    "source-span-binding",
    "same-evidence-budget",
    "reviewer-packet-anonymization",
    "sealed-identity-key",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v58b gate should pass: {gate}")
for gate in [
    "30b-blind-response-row",
    "70b-blind-response-row",
    "100b-plus-blind-response-row",
    "human-blind-review",
    "v58-full-blind-eval",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v58b gate should remain blocked: {gate}")

required_files = [
    "blind_query_freeze_rows.csv",
    "sealed_answer_key_rows.csv",
    "blind_response_template_rows.csv",
    "blind_reviewer_packet_template_rows.csv",
    "blind_adjudication_template_rows.csv",
    "blind_evidence_budget_rows.csv",
    "sealed_identity_key_rows.csv",
    "blind_domain_summary_rows.csv",
    "blind_scoring_rubric_rows.csv",
    "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md",
    "v58b_blind_eval_candidate_manifest.json",
    "sha256_manifest.csv",
    "source_v58/blind_system_mapping_rows.csv",
    "source_v58/blind_eval_query_contract_rows.csv",
    "source_v58/blind_evaluator_contract_rows.csv",
    "source_v58/blind_eval_gate_rows.csv",
    "source_v58/V58_BLIND_EVAL_BOUNDARY.md",
    "source_v58/v58_blind_eval_manifest.json",
    "source_v58/sha256_manifest.csv",
    "source_v58/v58_blind_eval_contract_summary.csv",
    "source_v57b/domain_pack_eval_rows.csv",
    "source_v57b/domain_pack_source_span_rows.csv",
    "source_v57b/domain_pack_candidate_summary_rows.csv",
    "source_v57b/domain_pack_policy_rows.csv",
    "source_v57b/domain_pack_rubric_rows.csv",
    "source_v57b/domain_pack_failure_taxonomy_rows.csv",
    "source_v57b/expert_review_template_rows.csv",
    "source_v57b/V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md",
    "source_v57b/v57b_domain_expert_pack_candidate_manifest.json",
    "source_v57b/sha256_manifest.csv",
    "source_v57b/v57b_domain_expert_pack_candidate_1000_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v58b artifact: {rel}")

query_rows = read_csv(run_dir / "blind_query_freeze_rows.csv")
answer_key_rows = read_csv(run_dir / "sealed_answer_key_rows.csv")
response_rows = read_csv(run_dir / "blind_response_template_rows.csv")
reviewer_rows = read_csv(run_dir / "blind_reviewer_packet_template_rows.csv")
adjudication_rows = read_csv(run_dir / "blind_adjudication_template_rows.csv")
budget_rows = read_csv(run_dir / "blind_evidence_budget_rows.csv")
identity_rows = read_csv(run_dir / "sealed_identity_key_rows.csv")
if len(query_rows) != 500 or len(answer_key_rows) != 500:
    raise SystemExit("v58b should freeze 500 queries and 500 sealed answer keys")
if len(response_rows) != 2500 or len(reviewer_rows) != 2500 or len(adjudication_rows) != 2500:
    raise SystemExit("v58b should write 2500 response/reviewer/adjudication templates")
counts = Counter(row["domain_pack"] for row in query_rows)
if counts != DOMAIN_TARGETS:
    raise SystemExit(f"v58b domain distribution mismatch: {counts}")
if len({row["blind_eval_id"] for row in query_rows}) != 500:
    raise SystemExit("v58b blind eval IDs should be unique")
if any(row["query_selected_before_outputs"] != "1" or row["system_outputs_observed_before_freeze"] != "0" for row in query_rows):
    raise SystemExit("v58b query freeze should be pre-output")
if any(row["same_evidence_budget_required"] != "1" or row["reviewer_identity_hidden"] != "1" for row in query_rows):
    raise SystemExit("v58b frozen queries should require same budget and hidden reviewer identity")
for row in query_rows:
    if row["question_sha256"] != sha256_text(row["question"]):
        raise SystemExit("v58b question hash mismatch")
    if row["source_file_sha256"] != sha256(root / row["source_span_path"]):
        raise SystemExit("v58b source file hash mismatch")

answer_by_id = {row["blind_eval_id"]: row for row in answer_key_rows}
if set(answer_by_id) != {row["blind_eval_id"] for row in query_rows}:
    raise SystemExit("v58b sealed answer keys should match frozen queries")
if any(row["sealed_from_reviewer_packet"] != "1" for row in answer_key_rows):
    raise SystemExit("v58b answer keys should be sealed from reviewer packet")

systems = {row["blind_system_id"]: row["source_system_id"] for row in identity_rows}
if set(systems.values()) != {"D", "E", "F", "G", "H"}:
    raise SystemExit(f"v58b sealed identity should map D-H, got {systems}")
if any(row["sealed_until_scoring_complete"] != "1" or row["identity_hidden_from_reviewer"] != "1" for row in identity_rows):
    raise SystemExit("v58b sealed identity key should be sealed and hidden")
if len(budget_rows) != 5:
    raise SystemExit("v58b should define one budget per blind system")
if len({row["same_context_budget_bytes"] for row in budget_rows}) != 1:
    raise SystemExit("v58b budgets should use the same context byte cap")
if any(row["source_span_bound_only"] != "1" or row["same_query_set"] != "1" for row in budget_rows):
    raise SystemExit("v58b budgets should be source-span-bound and same-query-set")

if "source_system_id" in reviewer_rows[0]:
    raise SystemExit("v58b reviewer packet must not expose source_system_id")
if any(row["identity_hidden_from_reviewer"] != "1" or row["review_decision"] != "pending-blind-response" for row in reviewer_rows):
    raise SystemExit("v58b reviewer packet should remain anonymous and pending")
if any(row["supplied_response_ready"] != "0" for row in response_rows):
    raise SystemExit("v58b response templates should not claim supplied responses")
if set(row["source_system_id"] for row in response_rows) != {"D", "E", "F", "G", "H"}:
    raise SystemExit("v58b response templates should cover D-H")

manifest = json.loads((run_dir / "v58b_blind_eval_candidate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v58b_blind_eval_candidate_ready") != 1 or manifest.get("v58_ready") != 0:
    raise SystemExit("v58b manifest readiness mismatch")
if manifest.get("domain_counts") != DOMAIN_TARGETS:
    raise SystemExit("v58b manifest domain counts mismatch")
if manifest.get("actual_blind_response_rows") != 0 or manifest.get("human_blind_review_ready") != 0:
    raise SystemExit("v58b manifest should keep response/review rows blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v58b sha256 mismatch: {rel}")

boundary = (run_dir / "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "freezes 500 source-span-bound candidate queries",
    "not the completed blind evaluation versus 30B-150B-class systems",
    "actual_blind_response_rows=0",
    "human_blind_review_ready=0",
    "Do not publish blind-eval wins",
]:
    if snippet not in boundary:
        raise SystemExit(f"v58b boundary missing {snippet}")
PY

echo "v58b blind eval candidate 500 smoke passed"
