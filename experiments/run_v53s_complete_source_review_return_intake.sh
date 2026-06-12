#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53s_complete_source_review_return_intake"
RUN_ID="${V53S_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V53S_REVIEW_RETURN_DIR:-}"

if [[ "${V53S_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53s_complete_source_review_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
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
supplied_arg = sys.argv[5]
results = root / "results"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None

RETURN_ARTIFACTS = [
    ("human_review_rows.csv", "required", "per-answer source/policy review judgments"),
    ("adjudication_rows.csv", "required", "p0 mismatch and policy-conflict adjudication decisions"),
    ("reviewer_identity_rows.csv", "required", "reviewer identity and independence declarations"),
    ("reviewer_conflict_rows.csv", "required", "reviewer conflict disclosure rows"),
    ("acceptance_summary.json", "required", "review acceptance summary with artifact hashes"),
]
FIELD_REQUIREMENTS = {
    "human_review_rows.csv": [
        "review_answer_packet_id",
        "answer_id",
        "system_id",
        "query_id",
        "reviewer_id",
        "review_decision",
        "source_support_verified",
        "citation_verified",
        "policy_verified",
        "review_comment_sha256",
    ],
    "adjudication_rows.csv": [
        "adjudication_id",
        "review_answer_packet_id",
        "answer_id",
        "adjudicator_id",
        "adjudication_decision",
        "adjudication_reason_sha256",
    ],
    "reviewer_identity_rows.csv": [
        "assignment_id",
        "reviewer_id",
        "reviewer_slot_id",
        "system_id",
        "review_scope",
        "independence_declared",
        "credential_statement_sha256",
    ],
    "reviewer_conflict_rows.csv": [
        "assignment_id",
        "reviewer_id",
        "owner_repo",
        "conflict_declared",
        "conflict_statement_sha256",
    ],
}
ALLOWED_REVIEW_DECISIONS = {"accept", "reject", "needs-adjudication"}
ALLOWED_ADJUDICATION_DECISIONS = {"accept", "reject", "exclude-from-comparison"}
ACCEPTANCE_REQUIRED_FIELDS = [
    "review_protocol_version",
    "acceptance_decision",
    "expected_human_review_rows",
    "accepted_human_review_rows",
    "human_review_rows_sha256",
    "expected_adjudication_rows",
    "accepted_adjudication_rows",
    "adjudication_rows_sha256",
    "expected_reviewer_identity_rows",
    "accepted_reviewer_identity_rows",
    "reviewer_identity_rows_sha256",
    "expected_conflict_disclosure_rows",
    "accepted_conflict_disclosure_rows",
    "reviewer_conflict_rows_sha256",
]


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


def read_supplied_csv(name):
    if supplied_dir is None:
        return [], [], False, ""
    path = supplied_dir / name
    if not path.is_file():
        return [], [], False, ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader), reader.fieldnames or [], True, sha256(path)


v53r_summary = read_csv(results / "v53r_complete_source_review_packet_summary.csv")[0]
if v53r_summary.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v53s requires v53r_complete_source_review_packet_ready=1")
if v53r_summary.get("review_packet_ready") != "1":
    raise SystemExit("v53s requires v53r review_packet_ready=1")

for src, rel in [
    (results / "v53r_complete_source_review_packet_summary.csv", "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (results / "v53r_complete_source_review_packet_decision.csv", "source_v53r/v53r_complete_source_review_packet_decision.csv"),
    (v53r_dir / "review_query_packet_rows.csv", "source_v53r/review_query_packet_rows.csv"),
    (v53r_dir / "review_answer_packet_rows.csv", "source_v53r/review_answer_packet_rows.csv"),
    (v53r_dir / "review_queue_rows.csv", "source_v53r/review_queue_rows.csv"),
    (v53r_dir / "reviewer_assignment_template_rows.csv", "source_v53r/reviewer_assignment_template_rows.csv"),
    (v53r_dir / "review_return_template_rows.csv", "source_v53r/review_return_template_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53r_dir / "review_packet_index_rows.csv", "source_v53r/review_packet_index_rows.csv"),
    (v53r_dir / "V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md", "source_v53r/V53R_COMPLETE_SOURCE_REVIEW_PACKET_BOUNDARY.md"),
    (v53r_dir / "v53r_complete_source_review_packet_manifest.json", "source_v53r/v53r_complete_source_review_packet_manifest.json"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
]:
    copy(src, rel)

review_answer_rows = read_csv(v53r_dir / "review_answer_packet_rows.csv")
review_queue_rows = read_csv(v53r_dir / "review_queue_rows.csv")
assignment_rows = read_csv(v53r_dir / "reviewer_assignment_template_rows.csv")
answer_by_id = {row["answer_id"]: row for row in review_answer_rows}
answer_ids = {row["answer_id"] for row in review_answer_rows}
p0_answer_ids = {row["answer_id"] for row in review_queue_rows if row["priority_class"] == "p0_answer_or_policy_mismatch"}
queue_by_answer_id = {row["answer_id"]: row for row in review_queue_rows if row["answer_id"] in p0_answer_ids}
assignment_by_id = {row["assignment_id"]: row for row in assignment_rows}
owner_repos = sorted({row["owner_repo"] for row in review_answer_rows})
expected_conflict_pairs = {
    (assignment["assignment_id"], owner_repo)
    for assignment in assignment_rows
    for owner_repo in owner_repos
}
expected_human_review_rows = len(review_answer_rows)
expected_adjudication_rows = len(p0_answer_ids)
expected_assignment_rows = len(assignment_rows)
expected_reviewer_identity_rows = expected_assignment_rows
expected_conflict_disclosure_rows = len(expected_conflict_pairs)

required_field_rows = []
for artifact, status, purpose in RETURN_ARTIFACTS:
    fields = FIELD_REQUIREMENTS.get(artifact, [])
    if fields:
        for field in fields:
            required_field_rows.append(
                {
                    "return_artifact": artifact,
                    "field_name": field,
                    "requirement_status": status,
                    "purpose": purpose,
                    "accepted_values": "see-boundary",
                }
            )
    else:
        required_field_rows.append(
            {
                "return_artifact": artifact,
                "field_name": "json_document",
                "requirement_status": status,
                "purpose": purpose,
                "accepted_values": "json object",
            }
        )
write_csv(run_dir / "review_return_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "return_artifact": "human_review_rows.csv",
        "example_row_id": "human_review_example",
        "example_payload": "review_answer_packet_id,answer_id,system_id,query_id,reviewer_id,review_decision,source_support_verified,citation_verified,policy_verified,review_comment_sha256",
    },
    {
        "return_artifact": "adjudication_rows.csv",
        "example_row_id": "adjudication_example",
        "example_payload": "adjudication_id,review_answer_packet_id,answer_id,adjudicator_id,adjudication_decision,adjudication_reason_sha256",
    },
    {
        "return_artifact": "reviewer_identity_rows.csv",
        "example_row_id": "identity_example",
        "example_payload": "assignment_id,reviewer_id,reviewer_slot_id,system_id,review_scope,independence_declared,credential_statement_sha256",
    },
    {
        "return_artifact": "reviewer_conflict_rows.csv",
        "example_row_id": "conflict_example",
        "example_payload": "assignment_id,reviewer_id,owner_repo,conflict_declared,conflict_statement_sha256",
    },
    {
        "return_artifact": "acceptance_summary.json",
        "example_row_id": "acceptance_summary_example",
        "example_payload": '{"review_protocol_version":"v53s","human_review_rows_sha256":"sha256:..."}',
    },
]
write_csv(run_dir / "review_return_row_template.csv", list(template_rows[0].keys()), template_rows)

validation_rows = []
artifact_gate_rows = []
supplied_any = False
human_rows, human_fields, human_supplied, human_sha = read_supplied_csv("human_review_rows.csv")
adjudication_rows, adjudication_fields, adjudication_supplied, adjudication_sha = read_supplied_csv("adjudication_rows.csv")
identity_rows, identity_fields, identity_supplied, identity_sha = read_supplied_csv("reviewer_identity_rows.csv")
conflict_rows, conflict_fields, conflict_supplied, conflict_sha = read_supplied_csv("reviewer_conflict_rows.csv")
acceptance_supplied = supplied_dir is not None and (supplied_dir / "acceptance_summary.json").is_file()
acceptance_sha = sha256(supplied_dir / "acceptance_summary.json") if acceptance_supplied else ""
supplied_any = any([human_supplied, adjudication_supplied, identity_supplied, conflict_supplied, acceptance_supplied])

supplied_map = {
    "human_review_rows.csv": (human_rows, human_fields, human_supplied, human_sha),
    "adjudication_rows.csv": (adjudication_rows, adjudication_fields, adjudication_supplied, adjudication_sha),
    "reviewer_identity_rows.csv": (identity_rows, identity_fields, identity_supplied, identity_sha),
    "reviewer_conflict_rows.csv": (conflict_rows, conflict_fields, conflict_supplied, conflict_sha),
    "acceptance_summary.json": ([], [], acceptance_supplied, acceptance_sha),
}

for artifact, status, purpose in RETURN_ARTIFACTS:
    rows, fields, supplied, artifact_sha = supplied_map[artifact]
    required_fields = FIELD_REQUIREMENTS.get(artifact, [])
    missing_fields = [field for field in required_fields if field not in fields]
    field_status = "pass" if supplied and not missing_fields else "blocked"
    if artifact == "acceptance_summary.json" and supplied:
        try:
            json.loads((supplied_dir / artifact).read_text(encoding="utf-8"))
            field_status = "pass"
            missing_fields = []
        except json.JSONDecodeError:
            field_status = "blocked"
            missing_fields = ["valid_json"]
    artifact_gate_rows.append(
        {
            "return_artifact": artifact,
            "requirement_status": status,
            "supplied": str(int(supplied)),
            "accepted": "0",
            "row_count": str(len(rows)),
            "sha256": artifact_sha,
            "field_validation_status": field_status,
            "missing_fields": ";".join(missing_fields),
            "purpose": purpose,
        }
    )

human_valid_rows = 0
human_invalid_rows = 0
reviewed_answer_ids = set()
if human_supplied and not [field for field in FIELD_REQUIREMENTS["human_review_rows.csv"] if field not in human_fields]:
    for index, row in enumerate(human_rows, start=1):
        errors = []
        expected_answer = answer_by_id.get(row["answer_id"])
        if expected_answer is None:
            errors.append("unknown-answer-id")
        else:
            for field in ["review_answer_packet_id", "system_id", "query_id"]:
                if row[field] != expected_answer[field]:
                    errors.append(f"mismatched-{field}")
        if row["answer_id"] in reviewed_answer_ids:
            errors.append("duplicate-answer-id")
        if row["review_decision"] not in ALLOWED_REVIEW_DECISIONS:
            errors.append("invalid-review-decision")
        for field in ["source_support_verified", "citation_verified", "policy_verified"]:
            if row[field] not in {"0", "1"}:
                errors.append(f"invalid-{field}")
        if not row["review_comment_sha256"].startswith("sha256:"):
            errors.append("invalid-review-comment-sha256")
        status = "pass" if not errors else "blocked"
        human_valid_rows += int(status == "pass")
        human_invalid_rows += int(status != "pass")
        if status == "pass":
            reviewed_answer_ids.add(row["answer_id"])
        validation_rows.append(
            {
                "validation_id": f"v53s_human_review_{index:05d}",
                "return_artifact": "human_review_rows.csv",
                "row_key": row.get("answer_id", ""),
                "status": status,
                "reason": ";".join(errors) if errors else "human review row schema accepted",
            }
        )

adjudication_valid_rows = 0
adjudication_invalid_rows = 0
adjudicated_answer_ids = set()
if adjudication_supplied and not [field for field in FIELD_REQUIREMENTS["adjudication_rows.csv"] if field not in adjudication_fields]:
    for index, row in enumerate(adjudication_rows, start=1):
        errors = []
        expected_queue = queue_by_answer_id.get(row["answer_id"])
        if expected_queue is None:
            errors.append("not-p0-answer-id")
        else:
            if row["review_answer_packet_id"] != expected_queue["review_answer_packet_id"]:
                errors.append("mismatched-review-answer-packet-id")
        if row["answer_id"] in adjudicated_answer_ids:
            errors.append("duplicate-adjudication-answer-id")
        if row["adjudication_decision"] not in ALLOWED_ADJUDICATION_DECISIONS:
            errors.append("invalid-adjudication-decision")
        if not row["adjudication_reason_sha256"].startswith("sha256:"):
            errors.append("invalid-adjudication-reason-sha256")
        status = "pass" if not errors else "blocked"
        adjudication_valid_rows += int(status == "pass")
        adjudication_invalid_rows += int(status != "pass")
        if status == "pass":
            adjudicated_answer_ids.add(row["answer_id"])
        validation_rows.append(
            {
                "validation_id": f"v53s_adjudication_{index:05d}",
                "return_artifact": "adjudication_rows.csv",
                "row_key": row.get("answer_id", ""),
                "status": status,
                "reason": ";".join(errors) if errors else "adjudication row schema accepted",
            }
        )

accepted_identity_rows = 0
identity_valid_rows = 0
identity_invalid_rows = 0
identity_by_assignment = {}
if identity_supplied and not [field for field in FIELD_REQUIREMENTS["reviewer_identity_rows.csv"] if field not in identity_fields]:
    for index, row in enumerate(identity_rows, start=1):
        errors = []
        assignment = assignment_by_id.get(row["assignment_id"])
        if assignment is None:
            errors.append("unknown-assignment-id")
        else:
            for field in ["reviewer_slot_id", "system_id", "review_scope"]:
                if row[field] != assignment[field]:
                    errors.append(f"mismatched-{field}")
        if row["assignment_id"] in identity_by_assignment:
            errors.append("duplicate-assignment-id")
        if row["independence_declared"] != "1":
            errors.append("independence-not-declared")
        if not row["credential_statement_sha256"].startswith("sha256:"):
            errors.append("invalid-credential-statement-sha256")
        status = "pass" if not errors else "blocked"
        identity_valid_rows += int(status == "pass")
        identity_invalid_rows += int(status != "pass")
        if status == "pass":
            identity_by_assignment[row["assignment_id"]] = row["reviewer_id"]
        validation_rows.append(
            {
                "validation_id": f"v53s_reviewer_identity_{index:05d}",
                "return_artifact": "reviewer_identity_rows.csv",
                "row_key": row.get("assignment_id", ""),
                "status": status,
                "reason": ";".join(errors) if errors else "reviewer identity row accepted",
            }
        )
accepted_identity_rows = len(identity_by_assignment)

accepted_conflict_rows = 0
conflict_valid_rows = 0
conflict_invalid_rows = 0
accepted_conflict_pairs = set()
if conflict_supplied and not [field for field in FIELD_REQUIREMENTS["reviewer_conflict_rows.csv"] if field not in conflict_fields]:
    for index, row in enumerate(conflict_rows, start=1):
        errors = []
        pair = (row["assignment_id"], row["owner_repo"])
        if pair not in expected_conflict_pairs:
            errors.append("unknown-assignment-repo-pair")
        if pair in accepted_conflict_pairs:
            errors.append("duplicate-assignment-repo-pair")
        if row["assignment_id"] in identity_by_assignment and row["reviewer_id"] != identity_by_assignment[row["assignment_id"]]:
            errors.append("mismatched-reviewer-id")
        if row["conflict_declared"] not in {"0", "1"}:
            errors.append("invalid-conflict-declared")
        if row["conflict_declared"] == "1":
            errors.append("declared-conflict-requires-reassignment")
        if not row["conflict_statement_sha256"].startswith("sha256:"):
            errors.append("invalid-conflict-statement-sha256")
        status = "pass" if not errors else "blocked"
        conflict_valid_rows += int(status == "pass")
        conflict_invalid_rows += int(status != "pass")
        if status == "pass":
            accepted_conflict_pairs.add(pair)
        validation_rows.append(
            {
                "validation_id": f"v53s_reviewer_conflict_{index:05d}",
                "return_artifact": "reviewer_conflict_rows.csv",
                "row_key": f"{row.get('assignment_id', '')}:{row.get('owner_repo', '')}",
                "status": status,
                "reason": ";".join(errors) if errors else "reviewer conflict row accepted",
            }
        )
accepted_conflict_rows = len(accepted_conflict_pairs)

human_review_completed = int(
    len(human_rows) == expected_human_review_rows
    and human_valid_rows == expected_human_review_rows
    and len(reviewed_answer_ids) == expected_human_review_rows
    and human_invalid_rows == 0
)
adjudication_completed = int(
    len(adjudication_rows) == expected_adjudication_rows
    and adjudication_valid_rows == expected_adjudication_rows
    and p0_answer_ids == adjudicated_answer_ids
    and adjudication_invalid_rows == 0
)
reviewer_identity_ready = int(
    len(identity_rows) == expected_reviewer_identity_rows
    and identity_valid_rows == expected_reviewer_identity_rows
    and accepted_identity_rows == expected_reviewer_identity_rows
    and identity_invalid_rows == 0
)
conflict_disclosure_ready = int(
    len(conflict_rows) == expected_conflict_disclosure_rows
    and conflict_valid_rows == expected_conflict_disclosure_rows
    and accepted_conflict_rows == expected_conflict_disclosure_rows
    and conflict_invalid_rows == 0
)

acceptance_summary_errors = []
if acceptance_supplied:
    try:
        acceptance_summary = json.loads((supplied_dir / "acceptance_summary.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        acceptance_summary = {}
        acceptance_summary_errors.append("invalid-json")
    for field in ACCEPTANCE_REQUIRED_FIELDS:
        if field not in acceptance_summary:
            acceptance_summary_errors.append(f"missing-{field}")
    expected_acceptance_values = {
        "review_protocol_version": "v53s",
        "acceptance_decision": "accepted",
        "expected_human_review_rows": expected_human_review_rows,
        "accepted_human_review_rows": expected_human_review_rows,
        "human_review_rows_sha256": human_sha,
        "expected_adjudication_rows": expected_adjudication_rows,
        "accepted_adjudication_rows": expected_adjudication_rows,
        "adjudication_rows_sha256": adjudication_sha,
        "expected_reviewer_identity_rows": expected_reviewer_identity_rows,
        "accepted_reviewer_identity_rows": expected_reviewer_identity_rows,
        "reviewer_identity_rows_sha256": identity_sha,
        "expected_conflict_disclosure_rows": expected_conflict_disclosure_rows,
        "accepted_conflict_disclosure_rows": expected_conflict_disclosure_rows,
        "reviewer_conflict_rows_sha256": conflict_sha,
    }
    for field, expected_value in expected_acceptance_values.items():
        if field in acceptance_summary and str(acceptance_summary[field]) != str(expected_value):
            acceptance_summary_errors.append(f"mismatched-{field}")
    validation_rows.append(
        {
            "validation_id": "v53s_acceptance_summary",
            "return_artifact": "acceptance_summary.json",
            "row_key": "acceptance_summary",
            "status": "pass" if not acceptance_summary_errors else "blocked",
            "reason": "acceptance summary hash/count binding accepted" if not acceptance_summary_errors else ";".join(acceptance_summary_errors),
        }
    )
acceptance_summary_ready = int(acceptance_supplied and not acceptance_summary_errors)
review_return_ready = int(
    human_review_completed
    and adjudication_completed
    and reviewer_identity_ready
    and conflict_disclosure_ready
    and acceptance_summary_ready
)

accepted_by_artifact = {
    "human_review_rows.csv": human_review_completed,
    "adjudication_rows.csv": adjudication_completed,
    "reviewer_identity_rows.csv": reviewer_identity_ready,
    "reviewer_conflict_rows.csv": conflict_disclosure_ready,
    "acceptance_summary.json": acceptance_summary_ready,
}
for row in artifact_gate_rows:
    row["accepted"] = str(int(accepted_by_artifact[row["return_artifact"]]))
    if row["return_artifact"] == "acceptance_summary.json" and acceptance_supplied:
        row["field_validation_status"] = "pass" if acceptance_summary_ready else "blocked"
        row["missing_fields"] = ";".join(acceptance_summary_errors)

if not validation_rows:
    validation_rows.append(
        {
            "validation_id": "v53s_default_no_return_rows",
            "return_artifact": "none",
            "row_key": "none",
            "status": "blocked",
            "reason": "no external human/source review return directory supplied",
        }
    )
write_csv(run_dir / "review_return_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)
write_csv(run_dir / "review_return_artifact_gate_rows.csv", list(artifact_gate_rows[0].keys()), artifact_gate_rows)

metric = {
    "metric_id": "v53s_complete_source_review_return_intake_metrics",
    "v53r_complete_source_review_packet_ready": v53r_summary["v53r_complete_source_review_packet_ready"],
    "review_return_input_supplied": str(int(supplied_any)),
    "expected_human_review_rows": str(expected_human_review_rows),
    "accepted_human_review_rows": str(human_valid_rows),
    "invalid_human_review_rows": str(human_invalid_rows),
    "expected_adjudication_rows": str(expected_adjudication_rows),
    "accepted_adjudication_rows": str(adjudication_valid_rows),
    "invalid_adjudication_rows": str(adjudication_invalid_rows),
    "expected_reviewer_assignment_rows": str(expected_assignment_rows),
    "expected_reviewer_identity_rows": str(expected_reviewer_identity_rows),
    "accepted_reviewer_identity_rows": str(accepted_identity_rows),
    "invalid_reviewer_identity_rows": str(identity_invalid_rows),
    "expected_conflict_disclosure_rows": str(expected_conflict_disclosure_rows),
    "accepted_conflict_disclosure_rows": str(accepted_conflict_rows),
    "invalid_conflict_disclosure_rows": str(conflict_invalid_rows),
    "return_artifact_rows": str(len(artifact_gate_rows)),
    "return_validation_rows": str(len(validation_rows)),
    "human_review_completed": str(human_review_completed),
    "adjudication_completed": str(adjudication_completed),
    "reviewer_identity_ready": str(reviewer_identity_ready),
    "conflict_disclosure_ready": str(conflict_disclosure_ready),
    "acceptance_summary_ready": str(acceptance_summary_ready),
    "acceptance_summary_error_count": str(len(acceptance_summary_errors)),
    "review_return_ready": str(review_return_ready),
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(run_dir / "review_return_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53s_complete_source_review_return_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53r-review-packet-input", "status": "pass", "reason": "v53r complete-source review packet is bound"},
    {"gate": "review-return-schema", "status": "pass", "reason": f"required_field_rows={len(required_field_rows)}; return_artifacts={len(RETURN_ARTIFACTS)}"},
    {"gate": "default-no-env-deferral", "status": "pass" if not supplied_any else "not-applicable", "reason": "no supplied review directory means no fake review rows are accepted"},
    {"gate": "human-review-artifacts", "status": "pass" if human_review_completed else "blocked", "reason": f"accepted_human_review_rows={human_valid_rows}/{expected_human_review_rows}"},
    {"gate": "adjudication-artifacts", "status": "pass" if adjudication_completed else "blocked", "reason": f"accepted_adjudication_rows={adjudication_valid_rows}/{expected_adjudication_rows}"},
    {"gate": "reviewer-identity", "status": "pass" if reviewer_identity_ready else "blocked", "reason": f"accepted_reviewer_identity_rows={accepted_identity_rows}/{expected_reviewer_identity_rows}"},
    {"gate": "conflict-disclosure", "status": "pass" if conflict_disclosure_ready else "blocked", "reason": f"accepted_conflict_disclosure_rows={accepted_conflict_rows}/{expected_conflict_disclosure_rows}"},
    {"gate": "acceptance-summary", "status": "pass" if acceptance_summary_ready else "blocked", "reason": f"acceptance_summary_ready={acceptance_summary_ready}; error_count={len(acceptance_summary_errors)}"},
    {"gate": "review-return-ready", "status": "pass" if review_return_ready else "blocked", "reason": f"review_return_ready={review_return_ready}"},
    {"gate": "quality-comparison-claim", "status": "blocked", "reason": "review return intake alone does not open comparison wording"},
    {"gate": "v53-ready", "status": "blocked", "reason": "v53 requires accepted review return plus final audit/release gates"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v53s is not a release package"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53s Complete Source Review Return Intake Boundary

This layer binds the frozen v53r complete-source review packet to the expected
external human/source review return artifacts. It validates schema and row IDs
when a return directory is supplied. In the default path it accepts no fake
review judgments and keeps v53 readiness blocked.

Evidence emitted:

- expected_human_review_rows={expected_human_review_rows}
- accepted_human_review_rows={human_valid_rows}
- expected_adjudication_rows={expected_adjudication_rows}
- accepted_adjudication_rows={adjudication_valid_rows}
- expected_reviewer_assignment_rows={expected_assignment_rows}
- expected_reviewer_identity_rows={expected_reviewer_identity_rows}
- accepted_reviewer_identity_rows={accepted_identity_rows}
- expected_conflict_disclosure_rows={expected_conflict_disclosure_rows}
- accepted_conflict_disclosure_rows={accepted_conflict_rows}
- review_return_input_supplied={int(supplied_any)}
- human_review_completed={human_review_completed}
- adjudication_completed={adjudication_completed}
- acceptance_summary_ready={acceptance_summary_ready}
- review_return_ready={review_return_ready}
- quality_comparison_claim_ready=0
- v53_ready=0

Allowed wording: complete-source review return intake schema and pending
human/source review return gate.

Blocked wording: human-reviewed complete-source audit, 30B-150B quality
comparison, v53 readiness, v1.0 comparison readiness, or release readiness.
"""
(run_dir / "V53S_COMPLETE_SOURCE_REVIEW_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53s-complete-source-review-return-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53s_complete_source_review_return_intake_ready": 1,
    "v53r_summary_sha256": sha256(results / "v53r_complete_source_review_packet_summary.csv"),
    "review_return_input_supplied": int(supplied_any),
    "expected_human_review_rows": expected_human_review_rows,
    "accepted_human_review_rows": human_valid_rows,
    "expected_adjudication_rows": expected_adjudication_rows,
    "accepted_adjudication_rows": adjudication_valid_rows,
    "expected_reviewer_assignment_rows": expected_assignment_rows,
    "expected_reviewer_identity_rows": expected_reviewer_identity_rows,
    "accepted_reviewer_identity_rows": accepted_identity_rows,
    "expected_conflict_disclosure_rows": expected_conflict_disclosure_rows,
    "accepted_conflict_disclosure_rows": accepted_conflict_rows,
    "human_review_completed": human_review_completed,
    "adjudication_completed": adjudication_completed,
    "reviewer_identity_ready": reviewer_identity_ready,
    "conflict_disclosure_ready": conflict_disclosure_ready,
    "acceptance_summary_ready": acceptance_summary_ready,
    "review_return_ready": review_return_ready,
    "quality_comparison_claim_ready": 0,
    "v53_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53s_complete_source_review_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53s_complete_source_review_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
