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
        "reviewer_id",
        "reviewer_slot_id",
        "independence_declared",
        "credential_statement_sha256",
    ],
    "reviewer_conflict_rows.csv": [
        "reviewer_id",
        "owner_repo",
        "conflict_declared",
        "conflict_statement_sha256",
    ],
}
ALLOWED_REVIEW_DECISIONS = {"accept", "reject", "needs-adjudication"}
ALLOWED_ADJUDICATION_DECISIONS = {"accept", "reject", "exclude-from-comparison"}


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
answer_ids = {row["answer_id"] for row in review_answer_rows}
p0_answer_ids = {row["answer_id"] for row in review_queue_rows if row["priority_class"] == "p0_answer_or_policy_mismatch"}
expected_human_review_rows = len(review_answer_rows)
expected_adjudication_rows = len(p0_answer_ids)
expected_assignment_rows = len(assignment_rows)

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
        "example_payload": "reviewer_id,reviewer_slot_id,independence_declared,credential_statement_sha256",
    },
    {
        "return_artifact": "reviewer_conflict_rows.csv",
        "example_row_id": "conflict_example",
        "example_payload": "reviewer_id,owner_repo,conflict_declared,conflict_statement_sha256",
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
        if row["answer_id"] not in answer_ids:
            errors.append("unknown-answer-id")
        if row["review_decision"] not in ALLOWED_REVIEW_DECISIONS:
            errors.append("invalid-review-decision")
        for field in ["source_support_verified", "citation_verified", "policy_verified"]:
            if row[field] not in {"0", "1"}:
                errors.append(f"invalid-{field}")
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
        if row["answer_id"] not in p0_answer_ids:
            errors.append("not-p0-answer-id")
        if row["adjudication_decision"] not in ALLOWED_ADJUDICATION_DECISIONS:
            errors.append("invalid-adjudication-decision")
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

accepted_identity_rows = 0
if identity_supplied and not [field for field in FIELD_REQUIREMENTS["reviewer_identity_rows.csv"] if field not in identity_fields]:
    accepted_identity_rows = sum(1 for row in identity_rows if row["independence_declared"] == "1")
accepted_conflict_rows = 0
if conflict_supplied and not [field for field in FIELD_REQUIREMENTS["reviewer_conflict_rows.csv"] if field not in conflict_fields]:
    accepted_conflict_rows = len(conflict_rows)

human_review_completed = int(human_valid_rows >= expected_human_review_rows and len(reviewed_answer_ids) >= expected_human_review_rows)
adjudication_completed = int(adjudication_valid_rows >= expected_adjudication_rows and p0_answer_ids.issubset(adjudicated_answer_ids))
reviewer_identity_ready = int(accepted_identity_rows >= 3)
conflict_disclosure_ready = int(accepted_conflict_rows >= 10)
acceptance_summary_ready = int(acceptance_supplied)
review_return_ready = int(
    human_review_completed
    and adjudication_completed
    and reviewer_identity_ready
    and conflict_disclosure_ready
    and acceptance_summary_ready
)

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
    "accepted_reviewer_identity_rows": str(accepted_identity_rows),
    "accepted_conflict_disclosure_rows": str(accepted_conflict_rows),
    "return_artifact_rows": str(len(artifact_gate_rows)),
    "return_validation_rows": str(len(validation_rows)),
    "human_review_completed": str(human_review_completed),
    "adjudication_completed": str(adjudication_completed),
    "reviewer_identity_ready": str(reviewer_identity_ready),
    "conflict_disclosure_ready": str(conflict_disclosure_ready),
    "acceptance_summary_ready": str(acceptance_summary_ready),
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
    {"gate": "reviewer-identity", "status": "pass" if reviewer_identity_ready else "blocked", "reason": f"accepted_reviewer_identity_rows={accepted_identity_rows}"},
    {"gate": "conflict-disclosure", "status": "pass" if conflict_disclosure_ready else "blocked", "reason": f"accepted_conflict_disclosure_rows={accepted_conflict_rows}"},
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
- accepted_reviewer_identity_rows={accepted_identity_rows}
- accepted_conflict_disclosure_rows={accepted_conflict_rows}
- review_return_input_supplied={int(supplied_any)}
- human_review_completed={human_review_completed}
- adjudication_completed={adjudication_completed}
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
    "human_review_completed": human_review_completed,
    "adjudication_completed": adjudication_completed,
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
