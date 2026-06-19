#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v58d_blind_review_return_intake"
RUN_ID="${V58D_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REVIEW_DIR="${V58D_BLIND_REVIEW_RETURN_DIR:-}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

USE_EXISTING_V58C="${V58D_USE_EXISTING_V58C:-0}"
if [[ "${V58D_ALLOW_V58C_REBUILD:-0}" == "1" ]]; then
  V58C_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v58c_blind_response_evidence_intake.sh" >/dev/null
  USE_EXISTING_V58C=1
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REVIEW_DIR" "$USE_EXISTING_V58C" <<'PY'
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
review_dir_arg = sys.argv[5]
use_existing_v58c = sys.argv[6] == "1"
results = root / "results"
v58c_dir = results / "v58c_blind_response_evidence_intake" / "intake_001"
v58b_dir = results / "v58b_blind_eval_candidate_500" / "candidate_001"
v58c_summary_path = results / "v58c_blind_response_evidence_intake_summary.csv"

REQUIRED_SYSTEMS = {"D", "E", "G", "H"}
OPTIONAL_SYSTEMS = {"F"}
PM_ACTUAL_REQUIRED_SYSTEMS = ["A", "B", "C", "D", "E", "G", "H"]
DECISIONS = {"correct", "incorrect", "abstain-correct", "abstain-incorrect", "unsupported-claim", "invalid-citation"}
FORBIDDEN_REVIEW_FIELDS = {"source_system_id", "source_system_name", "model_or_architecture_id", "run_identity"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def is_sha256(value):
    return isinstance(value, str) and value.startswith("sha256:") and len(value) == 71


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader), list(reader.fieldnames or [])


def first_row(path):
    rows, _ = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}")
    return rows[0]


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key, default="0"):
    return int(float(row.get(key, default) or default))


v58c_required_artifacts = [
    "blind_response_required_field_rows.csv",
    "blind_response_row_template.csv",
    "run_identity_template_rows.csv",
    "blind_response_validation_rows.csv",
    "blind_response_intake_gate_rows.csv",
    "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md",
    "v58c_blind_response_evidence_intake_manifest.json",
    "sha256_manifest.csv",
]
v58b_required_artifacts = [
    "blind_query_freeze_rows.csv",
    "sealed_answer_key_rows.csv",
    "blind_response_template_rows.csv",
    "blind_reviewer_packet_template_rows.csv",
    "blind_adjudication_template_rows.csv",
    "blind_evidence_budget_rows.csv",
    "sealed_identity_key_rows.csv",
    "sha256_manifest.csv",
]
v58c_available = int(
    use_existing_v58c
    and v58c_summary_path.is_file()
    and all((v58c_dir / relpath).is_file() and (v58c_dir / relpath).stat().st_size > 0 for relpath in v58c_required_artifacts)
    and all((v58b_dir / relpath).is_file() and (v58b_dir / relpath).stat().st_size > 0 for relpath in v58b_required_artifacts)
)

dependency_rows = [
    {
        "dependency": "v58c-response-intake",
        "status": "pass" if v58c_available else "blocked",
        "reason": "v58c response intake artifact explicitly included" if v58c_available else "v58c artifact not explicitly included; refusing implicit v58/v57/v56 seed rebuild",
    },
    {
        "dependency": "v58b-blind-query-freeze",
        "status": "pass" if v58c_available else "blocked",
        "reason": "v58b query-freeze source copied through v58c" if v58c_available else "v58b source artifacts are not consumed unless v58c is explicitly included",
    },
]
write_csv(run_dir / "v58d_blind_review_dependency_rows.csv", ["dependency", "status", "reason"], dependency_rows)

if v58c_available:
    v58c = first_row(v58c_summary_path)
    for relpath in v58c_required_artifacts:
        copy(v58c_dir / relpath, f"source_v58c/{relpath}")
    copy(v58c_summary_path, "source_v58c/v58c_blind_response_evidence_intake_summary.csv")
    for relpath in v58b_required_artifacts:
        copy(v58b_dir / relpath, f"source_v58b/{relpath}")
    response_templates, _ = read_csv(v58c_dir / "blind_response_row_template.csv")
else:
    v58c = {
        "v58c_blind_response_evidence_intake_ready": "0",
        "required_blind_response_ready": "0",
        "blind_response_absorb_ready": "0",
    }
    response_templates = []

template_by_response = {row["blind_response_id"]: row for row in response_templates}
required_response_ids = {
    row["blind_response_id"]
    for row in response_templates
    if row["source_system_id"] in REQUIRED_SYSTEMS
}
optional_response_ids = {
    row["blind_response_id"]
    for row in response_templates
    if row["source_system_id"] in OPTIONAL_SYSTEMS
}

schema_rows = [
    ("blind_review_return_rows.csv", "blind_response_id", "must match a v58c blind response id"),
    ("blind_review_return_rows.csv", "blind_eval_id", "must match the frozen blind eval id for the response"),
    ("blind_review_return_rows.csv", "blind_system_id", "blind system id only; source identity fields are forbidden"),
    ("blind_review_return_rows.csv", "reviewer_id", "stable reviewer id; two distinct reviewers are required per required response"),
    ("blind_review_return_rows.csv", "reviewer_blinded", "must be 1"),
    ("blind_review_return_rows.csv", "conflict_disclosed", "0 or 1"),
    ("blind_review_return_rows.csv", "answer_correctness", "0 or 1"),
    ("blind_review_return_rows.csv", "citation_correctness", "0 or 1"),
    ("blind_review_return_rows.csv", "abstain_correctness", "0 or 1"),
    ("blind_review_return_rows.csv", "source_span_exactness", "0 or 1; evaluates cited source span exactly, not just answer text"),
    ("blind_review_return_rows.csv", "unsupported_abstention_correctness", "0 or 1; evaluates unsupported/missing-query abstention separately"),
    ("blind_review_return_rows.csv", "unseen_repository_split_id", "non-empty split id proving the row belongs to the unseen repository split"),
    ("blind_review_return_rows.csv", "latency_memory_excluded_from_quality_score", "must be 1; latency/memory are evaluated outside answer quality"),
    ("blind_review_return_rows.csv", "policy_score", "0 or 1"),
    ("blind_review_return_rows.csv", "review_decision", "normalized blind decision label"),
    ("blind_review_return_rows.csv", "review_sha256", "sha256:<64 hex> over the reviewer return artifact row"),
    ("blind_adjudication_return_rows.csv", "blind_response_id", "must match a required v58c blind response id"),
    ("blind_adjudication_return_rows.csv", "reviewer_a_id", "must reference one reviewer return"),
    ("blind_adjudication_return_rows.csv", "reviewer_b_id", "must reference a distinct reviewer return"),
    ("blind_adjudication_return_rows.csv", "reviewer_a_decision", "normalized blind decision label"),
    ("blind_adjudication_return_rows.csv", "reviewer_b_decision", "normalized blind decision label"),
    ("blind_adjudication_return_rows.csv", "adjudicated_decision", "normalized final blind decision label"),
    ("blind_adjudication_return_rows.csv", "inter_rater_agree", "0 or 1"),
    ("blind_adjudication_return_rows.csv", "adjudicator_id", "stable adjudicator id"),
    ("blind_adjudication_return_rows.csv", "adjudication_sha256", "sha256:<64 hex> over the adjudication row"),
]
write_csv(
    run_dir / "blind_review_required_field_rows.csv",
    ["artifact", "field", "rule"],
    [{"artifact": artifact, "field": field, "rule": rule} for artifact, field, rule in schema_rows],
)

review_template_fields = [
    "blind_review_row_id",
    "blind_response_id",
    "blind_eval_id",
    "blind_system_id",
    "reviewer_slot",
    "reviewer_id",
    "reviewer_blinded",
    "conflict_disclosed",
    "answer_correctness",
    "citation_correctness",
    "abstain_correctness",
    "source_span_exactness",
    "unsupported_abstention_correctness",
    "unseen_repository_split_id",
    "latency_memory_excluded_from_quality_score",
    "policy_score",
    "review_decision",
    "review_sha256",
    "required_for_v58",
]
review_template_rows = []
for row in response_templates:
    for reviewer_slot in ("reviewer_a", "reviewer_b"):
        review_template_rows.append(
            {
                "blind_review_row_id": f"{row['blind_response_id']}_{reviewer_slot}",
                "blind_response_id": row["blind_response_id"],
                "blind_eval_id": row["blind_eval_id"],
                "blind_system_id": row["blind_system_id"],
                "reviewer_slot": reviewer_slot,
                "reviewer_id": "",
                "reviewer_blinded": "",
                "conflict_disclosed": "",
                "answer_correctness": "",
                "citation_correctness": "",
                "abstain_correctness": "",
                "source_span_exactness": "",
                "unsupported_abstention_correctness": "",
                "unseen_repository_split_id": "",
                "latency_memory_excluded_from_quality_score": "",
                "policy_score": "",
                "review_decision": "",
                "review_sha256": "",
                "required_for_v58": 1 if row["blind_response_id"] in required_response_ids else 0,
            }
        )
write_csv(run_dir / "blind_review_return_template_rows.csv", review_template_fields, review_template_rows)

adjudication_template_fields = [
    "blind_response_id",
    "blind_eval_id",
    "blind_system_id",
    "reviewer_a_id",
    "reviewer_b_id",
    "reviewer_a_decision",
    "reviewer_b_decision",
    "adjudicated_decision",
    "inter_rater_agree",
    "adjudicator_id",
    "adjudication_sha256",
    "required_for_v58",
]
adjudication_template_rows = []
for row in response_templates:
    adjudication_template_rows.append(
        {
            "blind_response_id": row["blind_response_id"],
            "blind_eval_id": row["blind_eval_id"],
            "blind_system_id": row["blind_system_id"],
            "reviewer_a_id": "",
            "reviewer_b_id": "",
            "reviewer_a_decision": "",
            "reviewer_b_decision": "",
            "adjudicated_decision": "",
            "inter_rater_agree": "",
            "adjudicator_id": "",
            "adjudication_sha256": "",
            "required_for_v58": 1 if row["blind_response_id"] in required_response_ids else 0,
        }
    )
write_csv(run_dir / "blind_adjudication_return_template_rows.csv", adjudication_template_fields, adjudication_template_rows)
write_csv(
    run_dir / "blind_eval_score_rows.csv",
    ["blind_response_id", "blind_eval_id", "blind_system_id", "source_system_id", "adjudicated_decision", "answer_credit", "citation_credit", "abstain_credit"],
    [],
)
write_csv(
    run_dir / "blind_failure_case_report_rows.csv",
    ["blind_response_id", "blind_eval_id", "blind_system_id", "source_system_id", "failure_type", "adjudicated_decision"],
    [],
)

validation_rows = []
review_rows = []
review_fields = []
adjudication_rows = []
adjudication_fields = []
review_dir = Path(review_dir_arg) if review_dir_arg else None
if not review_dir or not review_dir.is_dir():
    validation_rows.append({"check": "review-dir", "status": "blocked", "reason": "V58D_BLIND_REVIEW_RETURN_DIR not supplied"})
else:
    review_path = review_dir / "blind_review_return_rows.csv"
    adjudication_path = review_dir / "blind_adjudication_return_rows.csv"
    for name, path in [("blind-review-file", review_path), ("blind-adjudication-file", adjudication_path)]:
        if path.is_file() and path.stat().st_size > 0:
            copy(path, f"supplied_review/{path.name}")
            validation_rows.append({"check": name, "status": "pass", "reason": "present"})
        else:
            validation_rows.append({"check": name, "status": "fail", "reason": "missing-or-empty"})
    if review_path.is_file() and review_path.stat().st_size > 0:
        review_rows, review_fields = read_csv(review_path)
    if adjudication_path.is_file() and adjudication_path.stat().st_size > 0:
        adjudication_rows, adjudication_fields = read_csv(adjudication_path)

errors = []
if as_int(v58c, "required_blind_response_ready") != 1:
    errors.append("blind-response-absorb-not-ready")

if review_fields and FORBIDDEN_REVIEW_FIELDS.intersection(review_fields):
    errors.append("review-return-identity-leak-field")
if adjudication_fields and FORBIDDEN_REVIEW_FIELDS.intersection(adjudication_fields):
    errors.append("adjudication-return-identity-leak-field")

reviews_by_response = defaultdict(list)
for row in review_rows:
    response_id = row.get("blind_response_id", "")
    if response_id not in template_by_response:
        errors.append("review-extra-response-id")
        continue
    template = template_by_response[response_id]
    if row.get("blind_eval_id", "") != template["blind_eval_id"]:
        errors.append("review-blind-eval-id-mismatch")
    if row.get("blind_system_id", "") != template["blind_system_id"]:
        errors.append("review-blind-system-id-mismatch")
    if row.get("reviewer_blinded", "") != "1":
        errors.append("reviewer-not-blinded")
    if row.get("conflict_disclosed", "") not in {"0", "1"}:
        errors.append("conflict-disclosed-not-binary")
    for field in [
        "answer_correctness",
        "citation_correctness",
        "abstain_correctness",
        "source_span_exactness",
        "unsupported_abstention_correctness",
        "policy_score",
    ]:
        if row.get(field, "") not in {"0", "1"}:
            errors.append(f"{field}-not-binary")
    if not row.get("unseen_repository_split_id", ""):
        errors.append("unseen-repository-split-id-missing")
    if row.get("latency_memory_excluded_from_quality_score", "") != "1":
        errors.append("latency-memory-not-separated-from-quality")
    if row.get("review_decision", "") not in DECISIONS:
        errors.append("review-decision-invalid")
    if not row.get("reviewer_id", ""):
        errors.append("reviewer-id-missing")
    if not is_sha256(row.get("review_sha256", "")):
        errors.append("review-sha256-invalid")
    reviews_by_response[response_id].append(row)

for response_id in required_response_ids:
    rows = reviews_by_response.get(response_id, [])
    reviewer_ids = {row.get("reviewer_id", "") for row in rows}
    if len(rows) != 2:
        errors.append("required-review-count-not-two")
    if len(reviewer_ids) != 2:
        errors.append("required-reviewer-not-distinct")

adjudication_by_response = {}
for row in adjudication_rows:
    response_id = row.get("blind_response_id", "")
    if response_id not in template_by_response:
        errors.append("adjudication-extra-response-id")
        continue
    if response_id in adjudication_by_response:
        errors.append("duplicate-adjudication-response-id")
    adjudication_by_response[response_id] = row
    template = template_by_response[response_id]
    if row.get("blind_eval_id", "") != template["blind_eval_id"]:
        errors.append("adjudication-blind-eval-id-mismatch")
    if row.get("blind_system_id", "") != template["blind_system_id"]:
        errors.append("adjudication-blind-system-id-mismatch")
    if row.get("reviewer_a_id", "") == row.get("reviewer_b_id", ""):
        errors.append("adjudication-reviewers-not-distinct")
    for field in ["reviewer_a_decision", "reviewer_b_decision", "adjudicated_decision"]:
        if row.get(field, "") not in DECISIONS:
            errors.append(f"{field}-invalid")
    if row.get("inter_rater_agree", "") not in {"0", "1"}:
        errors.append("inter-rater-agree-not-binary")
    if not row.get("adjudicator_id", ""):
        errors.append("adjudicator-id-missing")
    if not is_sha256(row.get("adjudication_sha256", "")):
        errors.append("adjudication-sha256-invalid")

for response_id in required_response_ids:
    if response_id not in adjudication_by_response:
        errors.append("required-adjudication-missing")

template_counts = Counter(row.get("source_system_id", "") for row in response_templates)
review_counts = Counter()
review_exact_span_counts = Counter()
review_unsupported_abstention_counts = Counter()
review_unseen_split_counts = Counter()
review_latency_memory_separate_counts = Counter()
reviewers_by_system_response = defaultdict(lambda: defaultdict(set))
for row in review_rows:
    template = template_by_response.get(row.get("blind_response_id", ""))
    if not template:
        continue
    system_id = template.get("source_system_id", "")
    response_id = row.get("blind_response_id", "")
    review_counts[system_id] += 1
    reviewers_by_system_response[system_id][response_id].add(row.get("reviewer_id", ""))
    if row.get("source_span_exactness", "") in {"0", "1"}:
        review_exact_span_counts[system_id] += 1
    if row.get("unsupported_abstention_correctness", "") in {"0", "1"}:
        review_unsupported_abstention_counts[system_id] += 1
    if row.get("unseen_repository_split_id", ""):
        review_unseen_split_counts[system_id] += 1
    if row.get("latency_memory_excluded_from_quality_score", "") == "1":
        review_latency_memory_separate_counts[system_id] += 1
adjudication_counts = Counter()
for row in adjudication_rows:
    template = template_by_response.get(row.get("blind_response_id", ""))
    if template:
        adjudication_counts[template.get("source_system_id", "")] += 1

pm_review_matrix_rows = []
for system_id in PM_ACTUAL_REQUIRED_SYSTEMS:
    expected_response_rows = 500
    expected_review_rows = expected_response_rows * 2
    expected_adjudication_rows = expected_response_rows
    response_template_rows = template_counts.get(system_id, 0)
    supplied_review_rows = review_counts.get(system_id, 0)
    two_reviewer_response_rows = sum(
        1
        for reviewers in reviewers_by_system_response.get(system_id, {}).values()
        if len({reviewer for reviewer in reviewers if reviewer}) >= 2
    )
    supplied_adjudication_rows = adjudication_counts.get(system_id, 0)
    source_span_exactness_rows = review_exact_span_counts.get(system_id, 0)
    unsupported_abstention_rows = review_unsupported_abstention_counts.get(system_id, 0)
    unseen_split_rows = review_unseen_split_counts.get(system_id, 0)
    latency_memory_separate_rows = review_latency_memory_separate_counts.get(system_id, 0)
    template_available = int(response_template_rows == expected_response_rows)
    ready = int(
        template_available == 1
        and supplied_review_rows == expected_review_rows
        and two_reviewer_response_rows == expected_response_rows
        and supplied_adjudication_rows == expected_adjudication_rows
        and source_span_exactness_rows == expected_review_rows
        and unsupported_abstention_rows == expected_review_rows
        and unseen_split_rows == expected_review_rows
        and latency_memory_separate_rows == expected_review_rows
        and not errors
    )
    if not v58c_available:
        blocker = "v58c-response-intake-missing"
    elif response_template_rows != expected_response_rows:
        blocker = "missing-pm-required-response-template-rows"
    elif supplied_review_rows != expected_review_rows:
        blocker = "missing-two-independent-reviewer-rows"
    elif two_reviewer_response_rows != expected_response_rows:
        blocker = "missing-distinct-reviewers-per-response"
    elif supplied_adjudication_rows != expected_adjudication_rows:
        blocker = "missing-disagreement-adjudication-rows"
    elif source_span_exactness_rows != expected_review_rows:
        blocker = "missing-source-span-exactness-review-rows"
    elif unsupported_abstention_rows != expected_review_rows:
        blocker = "missing-unsupported-abstention-review-rows"
    elif unseen_split_rows != expected_review_rows:
        blocker = "missing-unseen-repository-split-evidence"
    elif latency_memory_separate_rows != expected_review_rows:
        blocker = "latency-memory-not-separated-from-answer-quality"
    elif errors:
        blocker = "validation-errors"
    else:
        blocker = ""
    pm_review_matrix_rows.append(
        {
            "source_system_id": system_id,
            "required_for_pm_v58_real_execution": "1",
            "blind_identity_required": "1",
            "same_corpus_required": "1",
            "same_context_budget_required": "1",
            "two_independent_reviewers_required": "1",
            "disagreement_adjudication_required": "1",
            "unseen_repository_split_required": "1",
            "source_span_exactness_required": "1",
            "unsupported_abstention_required": "1",
            "latency_memory_quality_separate_required": "1",
            "expected_blind_response_rows": str(expected_response_rows),
            "response_template_rows": str(response_template_rows),
            "expected_independent_review_rows": str(expected_review_rows),
            "supplied_review_rows": str(supplied_review_rows),
            "two_reviewer_response_rows": str(two_reviewer_response_rows),
            "expected_adjudication_rows": str(expected_adjudication_rows),
            "supplied_adjudication_rows": str(supplied_adjudication_rows),
            "source_span_exactness_review_rows": str(source_span_exactness_rows),
            "unsupported_abstention_review_rows": str(unsupported_abstention_rows),
            "unseen_split_review_rows": str(unseen_split_rows),
            "latency_memory_separate_review_rows": str(latency_memory_separate_rows),
            "actual_blind_review_ready": str(ready),
            "fixture_allowed": "0",
            "tests_only_merge_condition": "0",
            "status": "ready" if ready else "blocked",
            "blocker": blocker,
        }
    )
write_csv(run_dir / "pm_blind_review_actual_execution_matrix_rows.csv", list(pm_review_matrix_rows[0].keys()), pm_review_matrix_rows)
pm_review_actual_ready = int(all(row["actual_blind_review_ready"] == "1" for row in pm_review_matrix_rows))
pm_review_missing_system_rows = sum(1 for row in pm_review_matrix_rows if row["actual_blind_review_ready"] != "1")
pm_review_template_gap_rows = sum(1 for row in pm_review_matrix_rows if row["response_template_rows"] != row["expected_blind_response_rows"])

if errors:
    for error, count in sorted(Counter(errors).items()):
        validation_rows.append({"check": "supplied-review", "status": "fail", "reason": f"{error}:{count}"})

review_coverage_ready = int(
    bool(review_rows)
    and not errors
    and all(len(reviews_by_response.get(response_id, [])) == 2 for response_id in required_response_ids)
)
adjudication_ready = int(
    bool(adjudication_rows)
    and not errors
    and all(response_id in adjudication_by_response for response_id in required_response_ids)
)
human_blind_review_ready = int(review_coverage_ready and adjudication_ready)
inter_rater_rows_ready = human_blind_review_ready

score_rows = []
failure_rows = []
if human_blind_review_ready:
    for response_id in sorted(required_response_ids):
        template = template_by_response[response_id]
        adjudication = adjudication_by_response[response_id]
        decision = adjudication["adjudicated_decision"]
        answer_credit = 1 if decision in {"correct", "abstain-correct"} else 0
        citation_credit = 1 if decision in {"correct", "abstain-correct"} else 0
        abstain_credit = 1 if decision == "abstain-correct" else 0
        score_rows.append(
            {
                "blind_response_id": response_id,
                "blind_eval_id": template["blind_eval_id"],
                "blind_system_id": template["blind_system_id"],
                "source_system_id": template["source_system_id"],
                "adjudicated_decision": decision,
                "answer_credit": answer_credit,
                "citation_credit": citation_credit,
                "abstain_credit": abstain_credit,
            }
        )
        if answer_credit == 0 or citation_credit == 0:
            failure_rows.append(
                {
                    "blind_response_id": response_id,
                    "blind_eval_id": template["blind_eval_id"],
                    "blind_system_id": template["blind_system_id"],
                    "source_system_id": template["source_system_id"],
                    "failure_type": decision,
                    "adjudicated_decision": decision,
                }
            )
    write_csv(run_dir / "blind_eval_score_rows.csv", list(score_rows[0].keys()), score_rows)
    write_csv(
        run_dir / "blind_failure_case_report_rows.csv",
        ["blind_response_id", "blind_eval_id", "blind_system_id", "source_system_id", "failure_type", "adjudicated_decision"],
        failure_rows,
    )

score_rows_ready = int(human_blind_review_ready and len(score_rows) == len(required_response_ids))
routehint_advantage_rows_ready = score_rows_ready
failure_case_report_ready = int(human_blind_review_ready)
v58_full_blind_eval_ready = int(
    as_int(v58c, "required_blind_response_ready") == 1
    and human_blind_review_ready
    and routehint_advantage_rows_ready
    and failure_case_report_ready
)

if not validation_rows:
    validation_rows.append({"check": "supplied-review", "status": "pass", "reason": "required blind review and adjudication rows validate"})
write_csv(run_dir / "blind_review_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

summary = {
    "v58d_blind_review_return_intake_ready": "1",
    "v58_ready": str(v58_full_blind_eval_ready),
    "v58c_artifact_available": str(v58c_available),
    "v58d_dependency_blocker_ready": str(int(not v58c_available)),
    "v58c_blind_response_evidence_intake_ready": v58c.get("v58c_blind_response_evidence_intake_ready", "0"),
    "v58c_required_blind_response_ready": v58c.get("required_blind_response_ready", "0"),
    "v58c_blind_response_absorb_ready": v58c.get("blind_response_absorb_ready", "0"),
    "expected_blind_response_rows": str(len(response_templates)),
    "required_blind_response_rows": str(len(required_response_ids)),
    "optional_blind_response_rows": str(len(optional_response_ids)),
    "expected_required_review_rows": str(len(required_response_ids) * 2),
    "expected_required_adjudication_rows": str(len(required_response_ids)),
    "pm_review_required_system_rows": str(len(pm_review_matrix_rows)),
    "pm_review_required_blind_response_rows": "3500",
    "pm_review_required_independent_review_rows": "7000",
    "pm_review_required_adjudication_rows": "3500",
    "pm_review_actual_ready": str(pm_review_actual_ready),
    "pm_review_missing_system_rows": str(pm_review_missing_system_rows),
    "pm_review_template_gap_rows": str(pm_review_template_gap_rows),
    "pm_review_unseen_split_ready": str(pm_review_actual_ready),
    "pm_review_source_span_exactness_ready": str(pm_review_actual_ready),
    "pm_review_unsupported_abstention_ready": str(pm_review_actual_ready),
    "pm_review_latency_memory_separate_ready": str(pm_review_actual_ready),
    "review_dir_supplied": str(int(bool(review_dir_arg))),
    "supplied_review_rows": str(len(review_rows)),
    "supplied_adjudication_rows": str(len(adjudication_rows)),
    "validation_error_rows": str(len(errors)),
    "required_blind_review_ready": str(review_coverage_ready),
    "required_adjudication_ready": str(adjudication_ready),
    "human_blind_review_ready": str(human_blind_review_ready),
    "inter_rater_rows_ready": str(inter_rater_rows_ready),
    "blind_eval_score_rows": str(len(score_rows)),
    "routehint_advantage_rows_ready": str(routehint_advantage_rows_ready),
    "failure_case_report_ready": str(failure_case_report_ready),
    "v58_full_blind_eval_ready": str(v58_full_blind_eval_ready),
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("review-return-intake-contract", "pass", "blind review/adjudication schemas and templates are emitted"),
    ("v58c-response-intake-input", "pass" if v58c_available and v58c.get("v58c_blind_response_evidence_intake_ready") == "1" else "blocked", "v58c response intake contract is present" if v58c_available else "v58c artifact not explicitly included; seed rebuild blocked"),
    ("required-blind-response-ready", "pass" if v58c.get("required_blind_response_ready") == "1" else "blocked", "required D/E/G/H blind responses validate" if v58c.get("required_blind_response_ready") == "1" else "required D/E/G/H blind responses are missing"),
    ("human-blind-review-return", "pass" if review_coverage_ready else "blocked", "two blinded reviewer rows per required response validate" if review_coverage_ready else "human blind review rows are missing or invalid"),
    ("adjudication-return", "pass" if adjudication_ready else "blocked", "adjudication rows validate" if adjudication_ready else "adjudication rows are missing or invalid"),
    ("inter-rater-rows", "pass" if inter_rater_rows_ready else "blocked", "inter-rater/adjudication rows validate" if inter_rater_rows_ready else "inter-rater/adjudication evidence missing"),
    ("pm-required-a-b-c-d-e-g-h-review-rows", "pass" if pm_review_actual_ready else "blocked", "PM-required A/B/C/D/E/G/H blind review matrix validates" if pm_review_actual_ready else "PM-required A/B/C/D/E/G/H blind review matrix is incomplete"),
    ("pm-unseen-repository-split", "pass" if pm_review_actual_ready else "blocked", "unseen repository split evidence validates" if pm_review_actual_ready else "unseen repository split evidence is missing"),
    ("pm-source-span-exactness", "pass" if pm_review_actual_ready else "blocked", "source span exactness review rows validate" if pm_review_actual_ready else "source span exactness review rows are missing"),
    ("pm-unsupported-abstention", "pass" if pm_review_actual_ready else "blocked", "unsupported abstention review rows validate" if pm_review_actual_ready else "unsupported abstention review rows are missing"),
    ("pm-latency-memory-quality-separation", "pass" if pm_review_actual_ready else "blocked", "latency/memory are separated from answer quality" if pm_review_actual_ready else "latency/memory separation from answer quality is not proven"),
    ("routehint-advantage-rows", "pass" if routehint_advantage_rows_ready else "blocked", "blind score rows can be aggregated after review" if routehint_advantage_rows_ready else "blind score rows are not available"),
    ("failure-case-report", "pass" if failure_case_report_ready else "blocked", "failure case report rows are emitted after review" if failure_case_report_ready else "failure case report requires human blind review"),
    ("v58-full-blind-eval", "pass" if v58_full_blind_eval_ready else "blocked", "v58 blind eval is complete" if v58_full_blind_eval_ready else "response, review, adjudication, and score evidence are incomplete"),
    ("real-release-package", "blocked", "v58d intake is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])
write_csv(run_dir / "blind_review_intake_gate_rows.csv", ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md").write_text(
    "# v58d Blind Review Return Intake Boundary\n\n"
    "This layer defines and validates the human blind-review and adjudication return surface for v58. "
    "It is not a completed blind evaluation unless required response, review, adjudication, score, and failure-case rows all validate.\n\n"
    f"- v58c_artifact_available={v58c_available}\n"
    f"- expected_blind_response_rows={len(response_templates)}\n"
    f"- required_blind_response_rows={len(required_response_ids)}\n"
    f"- expected_required_review_rows={len(required_response_ids) * 2}\n"
    f"- expected_required_adjudication_rows={len(required_response_ids)}\n"
    f"- pm_review_required_system_rows={len(pm_review_matrix_rows)}\n"
    "- pm_review_required_blind_response_rows=3500\n"
    "- pm_review_required_independent_review_rows=7000\n"
    "- pm_review_required_adjudication_rows=3500\n"
    f"- pm_review_actual_ready={pm_review_actual_ready}\n"
    f"- pm_review_template_gap_rows={pm_review_template_gap_rows}\n"
    f"- v58c_required_blind_response_ready={v58c.get('required_blind_response_ready', '0')}\n"
    f"- human_blind_review_ready={human_blind_review_ready}\n"
    f"- inter_rater_rows_ready={inter_rater_rows_ready}\n"
    f"- v58_full_blind_eval_ready={v58_full_blind_eval_ready}\n\n"
    "Reviewer return rows must not contain source system identity fields. "
    "System identity is unsealed only after scoring/adjudication rows validate. "
    "PM v58 readiness additionally requires A/B/C/D/E/G/H actual response rows, two independent blinded reviewers per response, adjudication rows, unseen repository split evidence, source-span exactness review, unsupported-abstention review, and latency/memory separation from answer quality.\n\n"
    "Do not publish blind-eval wins, RouteHint advantage, or 30B-150B comparison claims from this intake boundary alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v58d-blind-review-return-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v58d_blind_review_return_intake_ready": 1,
    "v58_ready": v58_full_blind_eval_ready,
    "v58c_artifact_available": v58c_available,
    "v58d_dependency_blocker_ready": int(not v58c_available),
    "expected_blind_response_rows": len(response_templates),
    "required_blind_response_rows": len(required_response_ids),
    "expected_required_review_rows": len(required_response_ids) * 2,
    "expected_required_adjudication_rows": len(required_response_ids),
    "pm_review_required_system_rows": len(pm_review_matrix_rows),
    "pm_review_required_blind_response_rows": 3500,
    "pm_review_required_independent_review_rows": 7000,
    "pm_review_required_adjudication_rows": 3500,
    "pm_review_actual_ready": pm_review_actual_ready,
    "pm_review_missing_system_rows": pm_review_missing_system_rows,
    "pm_review_template_gap_rows": pm_review_template_gap_rows,
    "pm_review_unseen_split_ready": pm_review_actual_ready,
    "pm_review_source_span_exactness_ready": pm_review_actual_ready,
    "pm_review_unsupported_abstention_ready": pm_review_actual_ready,
    "pm_review_latency_memory_separate_ready": pm_review_actual_ready,
    "required_blind_review_ready": review_coverage_ready,
    "required_adjudication_ready": adjudication_ready,
    "human_blind_review_ready": human_blind_review_ready,
    "inter_rater_rows_ready": inter_rater_rows_ready,
    "blind_eval_score_rows": len(score_rows),
    "routehint_advantage_rows_ready": routehint_advantage_rows_ready,
    "failure_case_report_ready": failure_case_report_ready,
    "source_v58c_summary_sha256": sha256(v58c_summary_path) if v58c_available else "",
    "source_v58b_manifest_sha256": sha256(v58b_dir / "v58b_blind_eval_candidate_manifest.json") if v58c_available else "",
    "real_release_package_ready": 0,
}
(run_dir / "v58d_blind_review_return_intake_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "blind_review_required_field_rows.csv",
    "blind_review_return_template_rows.csv",
    "blind_adjudication_return_template_rows.csv",
    "pm_blind_review_actual_execution_matrix_rows.csv",
    "blind_review_validation_rows.csv",
    "blind_review_intake_gate_rows.csv",
    "blind_eval_score_rows.csv",
    "blind_failure_case_report_rows.csv",
    "v58d_blind_review_dependency_rows.csv",
    "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    "v58d_blind_review_return_intake_manifest.json",
]
if v58c_available:
    artifact_rels.extend(
        [
            "source_v58c/v58c_blind_response_evidence_intake_summary.csv",
            "source_v58c/blind_response_row_template.csv",
            "source_v58c/blind_response_validation_rows.csv",
            "source_v58c/blind_response_intake_gate_rows.csv",
            "source_v58c/V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md",
            "source_v58c/v58c_blind_response_evidence_intake_manifest.json",
            "source_v58c/sha256_manifest.csv",
            "source_v58b/blind_query_freeze_rows.csv",
            "source_v58b/sealed_answer_key_rows.csv",
            "source_v58b/blind_reviewer_packet_template_rows.csv",
            "source_v58b/blind_adjudication_template_rows.csv",
            "source_v58b/sealed_identity_key_rows.csv",
            "source_v58b/sha256_manifest.csv",
        ]
    )
if review_rows:
    artifact_rels.append("supplied_review/blind_review_return_rows.csv")
if adjudication_rows:
    artifact_rels.append("supplied_review/blind_adjudication_return_rows.csv")
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v58d_blind_review_return_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
