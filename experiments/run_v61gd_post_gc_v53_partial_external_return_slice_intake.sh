#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gd_post_gc_v53_partial_external_return_slice_intake"
RUN_ID="${V61GD_RUN_ID:-slice_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V53_RETURN_ROOT="${V61GD_V53_RETURN_ROOT:-${V61FV_V53_RETURN_BUNDLE_DIR:-}}"
V53_RETURN_PROVENANCE="${V61GD_V53_RETURN_PROVENANCE:-${V61FV_V53_RETURN_PROVENANCE:-unspecified}}"

if [[ "${V61GD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gd_post_gc_v53_partial_external_return_slice_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gc_post_gb_dual_return_root_admission_snapshot.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V53_RETURN_ROOT" "$V53_RETURN_PROVENANCE" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
v53_root_arg = sys.argv[5].strip()
v53_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
prefix = "v61gd_post_gc_v53_partial_external_return_slice_intake"
slice_dir = run_dir / "v53_partial_external_return_slice_intake"
slice_dir.mkdir(parents=True, exist_ok=True)
v53_root = Path(v53_root_arg).expanduser().resolve() if v53_root_arg else None
aggregate_dir = v53_root / "aggregate_review_return" if v53_root else None

REQUIRED_SHA_PREFIX = "sha256:"
REAL_PROVENANCE = "real-external-return-bundle"
PROVENANCE_MARKER = "REAL_EXTERNAL_RETURN_PROVENANCE.json"
DEFAULT_AUTHORITY_REL = "operator_attestation/reviewer_authority_statement.txt"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
HUMAN_FIELDS = [
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
]
ADJUDICATION_FIELDS = [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
]
IDENTITY_FIELDS = [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
]
CONFLICT_FIELDS = [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
]
ACCEPTANCE_FIELDS = [
    "review_protocol_version",
    "acceptance_decision",
    "slice_scope",
    "accepted_human_review_rows",
    "human_review_rows_sha256",
    "accepted_adjudication_rows",
    "adjudication_rows_sha256",
    "accepted_reviewer_identity_rows",
    "reviewer_identity_rows_sha256",
    "accepted_conflict_disclosure_rows",
    "reviewer_conflict_rows_sha256",
]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_csv_with_fields(path):
    if not path or not path.is_file():
        return [], [], ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or [], sha256(path)


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


def status(flag):
    return "pass" if flag else "blocked"


def valid_sha(value):
    return isinstance(value, str) and bool(SHA_RE.match(value))


def safe_relative(base, rel):
    if base is None or not rel:
        return None, "authority-path-missing"
    rel_path = Path(str(rel))
    if rel_path.is_absolute():
        return None, "authority-path-absolute"
    candidate = (base / rel_path).resolve()
    try:
        candidate.relative_to(base.resolve())
    except ValueError:
        return None, "authority-path-escapes-root"
    return candidate, ""


source_paths = {
    "v61gc_summary": results / "v61gc_post_gb_dual_return_root_admission_snapshot_summary.csv",
    "v61gc_root_rows": results / "v61gc_post_gb_dual_return_root_admission_snapshot" / "snapshot_001" / "dual_return_root_admission_snapshot_root_rows.csv",
    "v53r_summary": results / "v53r_complete_source_review_packet_summary.csv",
    "v53r_answers": results / "v53r_complete_source_review_packet" / "review_001" / "review_answer_packet_rows.csv",
    "v53r_queue": results / "v53r_complete_source_review_packet" / "review_001" / "review_queue_rows.csv",
    "v53r_assignments": results / "v53r_complete_source_review_packet" / "review_001" / "reviewer_assignment_template_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gd source {source_id}: {path}")

source_rows = []
for source_id, path in source_paths.items():
    folder = "source_v61gc" if source_id.startswith("v61gc") else "source_v53r"
    source_rows.append(copy_source(source_id, path, folder))
write_csv(run_dir / "v53_partial_external_return_slice_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gc = read_csv(source_paths["v61gc_summary"])[0]
v53r = read_csv(source_paths["v53r_summary"])[0]
if v61gc.get("v61gc_post_gb_dual_return_root_admission_snapshot_ready") != "1":
    raise SystemExit("v61gd requires v61gc ready")
if v53r.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61gd requires v53r ready")

answer_rows = read_csv(source_paths["v53r_answers"])
queue_rows = read_csv(source_paths["v53r_queue"])
assignment_rows = read_csv(source_paths["v53r_assignments"])
answer_by_id = {row["answer_id"]: row for row in answer_rows}
queue_by_answer = {row["answer_id"]: row for row in queue_rows}
assignment_by_id = {row["assignment_id"]: row for row in assignment_rows}
expected_conflict_pairs = {
    (assignment["assignment_id"], answer["owner_repo"])
    for assignment in assignment_rows
    for answer in answer_rows
    if assignment["system_id"] == answer["system_id"]
}

root_supplied = int(v53_root is not None)
root_exists = int(v53_root is not None and v53_root.is_dir())
aggregate_exists = int(aggregate_dir is not None and aggregate_dir.is_dir())
env_real_provenance = int(v53_provenance == REAL_PROVENANCE)

marker_path = v53_root / PROVENANCE_MARKER if v53_root else None
marker_supplied = int(marker_path is not None and marker_path.is_file())
marker_errors = []
marker_payload = {}
marker_sha = ""
marker_authority_path = ""
marker_authority_file_exists = 0
marker_authority_file_sha = ""
marker_authority_file_bytes = 0
if marker_supplied:
    marker_sha = sha256(marker_path)
    try:
        marker_payload = json.loads(marker_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        marker_errors.append("invalid-json")
    if marker_payload.get("provenance") != REAL_PROVENANCE:
        marker_errors.append("provenance-mismatch")
    if str(marker_payload.get("source_class", "")).startswith("fixture"):
        marker_errors.append("fixture-source-class")
    if marker_payload.get("source_class") not in {"external-operator-return", "external-review-return"}:
        marker_errors.append("source-class-not-external")
    expected_authority_sha = marker_payload.get("reviewer_authority_sha256", "")
    if not valid_sha(expected_authority_sha):
        marker_errors.append("reviewer-authority-sha256-missing")
    marker_authority_path = str(marker_payload.get("reviewer_authority_path", marker_payload.get("authority_statement_path", DEFAULT_AUTHORITY_REL)))
    authority_path, authority_error = safe_relative(v53_root, marker_authority_path)
    if authority_error:
        marker_errors.append(authority_error)
    marker_authority_file_exists = int(authority_path is not None and authority_path.is_file())
    if marker_authority_file_exists:
        marker_authority_file_sha = sha256(authority_path)
        marker_authority_file_bytes = authority_path.stat().st_size
        if marker_authority_file_bytes <= 0:
            marker_errors.append("authority-file-empty")
        if valid_sha(expected_authority_sha) and marker_authority_file_sha != expected_authority_sha:
            marker_errors.append("authority-sha-mismatch")
        try:
            authority_text = authority_path.read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            authority_text = ""
            marker_errors.append("authority-file-unreadable")
        if "fixture" in authority_text or "synthetic" in authority_text:
            marker_errors.append("authority-file-fixture-text")
    else:
        marker_errors.append("authority-file-missing")
else:
    marker_errors.append("missing-provenance-marker")
marker_real_provenance = int(marker_supplied and not marker_errors)
real_provenance_ready = int(env_real_provenance and marker_real_provenance)

human_path = aggregate_dir / "human_review_rows.csv" if aggregate_dir else None
adjudication_path = aggregate_dir / "adjudication_rows.csv" if aggregate_dir else None
identity_path = aggregate_dir / "reviewer_identity_rows.csv" if aggregate_dir else None
conflict_path = aggregate_dir / "reviewer_conflict_rows.csv" if aggregate_dir else None
acceptance_path = aggregate_dir / "acceptance_summary.json" if aggregate_dir else None

human_rows, human_fields, human_sha = read_csv_with_fields(human_path)
adjudication_rows, adjudication_fields, adjudication_sha = read_csv_with_fields(adjudication_path)
identity_rows, identity_fields, identity_sha = read_csv_with_fields(identity_path)
conflict_rows, conflict_fields, conflict_sha = read_csv_with_fields(conflict_path)

supplied_file_rows = []
for artifact, expected_rel, path in [
    ("human_review_rows.csv", "aggregate_review_return/human_review_rows.csv", human_path),
    ("adjudication_rows.csv", "aggregate_review_return/adjudication_rows.csv", adjudication_path),
    ("reviewer_identity_rows.csv", "aggregate_review_return/reviewer_identity_rows.csv", identity_path),
    ("reviewer_conflict_rows.csv", "aggregate_review_return/reviewer_conflict_rows.csv", conflict_path),
    ("acceptance_summary.json", "aggregate_review_return/acceptance_summary.json", acceptance_path),
    (PROVENANCE_MARKER, PROVENANCE_MARKER, marker_path),
    ("reviewer_authority_statement", marker_authority_path or DEFAULT_AUTHORITY_REL, authority_path if marker_supplied and 'authority_path' in locals() else None),
]:
    supplied = int(path is not None and path.is_file())
    digest = sha256(path) if supplied else ""
    supplied_file_rows.append({
        "artifact": artifact,
        "expected_relative_path": expected_rel,
        "supplied": str(supplied),
        "bytes": str(path.stat().st_size) if supplied else "0",
        "sha256": digest,
        "metadata_only": "0" if supplied else "1",
    })
write_csv(run_dir / "v53_partial_external_return_slice_supplied_file_rows.csv", list(supplied_file_rows[0].keys()), supplied_file_rows)

validation_rows = []
valid_human_by_answer = {}
if set(HUMAN_FIELDS).issubset(human_fields):
    seen = set()
    for index, row in enumerate(human_rows, 1):
        errors = []
        answer = answer_by_id.get(row.get("answer_id", ""))
        if answer is None:
            errors.append("unknown-answer-id")
        else:
            for field in ["review_answer_packet_id", "system_id", "query_id"]:
                if row.get(field) != answer[field]:
                    errors.append(f"mismatched-{field}")
        if row.get("answer_id") in seen:
            errors.append("duplicate-answer-id")
        if row.get("review_decision") not in {"accept", "reject", "needs-adjudication"}:
            errors.append("invalid-review-decision")
        for field in ["source_support_verified", "citation_verified", "policy_verified"]:
            if row.get(field) not in {"0", "1"}:
                errors.append(f"invalid-{field}")
        if not valid_sha(row.get("review_comment_sha256", "")):
            errors.append("invalid-review-comment-sha256")
        row_status = "pass" if not errors else "blocked"
        if row_status == "pass":
            seen.add(row["answer_id"])
            valid_human_by_answer[row["answer_id"]] = row
        validation_rows.append({
            "validation_id": f"v61gd-human-{index:05d}",
            "artifact": "human_review_rows.csv",
            "row_key": row.get("answer_id", ""),
            "status": row_status,
            "reason": "partial human review row accepted" if row_status == "pass" else ";".join(errors),
        })
elif human_rows:
    validation_rows.append({
        "validation_id": "v61gd-human-fieldset",
        "artifact": "human_review_rows.csv",
        "row_key": "field-set",
        "status": "blocked",
        "reason": "missing-fields:" + ";".join(sorted(set(HUMAN_FIELDS) - set(human_fields))),
    })

valid_adjudication_by_answer = {}
if set(ADJUDICATION_FIELDS).issubset(adjudication_fields):
    seen = set()
    for index, row in enumerate(adjudication_rows, 1):
        errors = []
        queue = queue_by_answer.get(row.get("answer_id", ""))
        if queue is None or queue.get("priority_class") != "p0_answer_or_policy_mismatch":
            errors.append("not-p0-answer-id")
        elif row.get("review_answer_packet_id") != queue["review_answer_packet_id"]:
            errors.append("mismatched-review-answer-packet-id")
        if row.get("answer_id") in seen:
            errors.append("duplicate-adjudication-answer-id")
        if row.get("adjudication_decision") not in {"accept", "reject", "exclude-from-comparison"}:
            errors.append("invalid-adjudication-decision")
        if not valid_sha(row.get("adjudication_reason_sha256", "")):
            errors.append("invalid-adjudication-reason-sha256")
        row_status = "pass" if not errors else "blocked"
        if row_status == "pass":
            seen.add(row["answer_id"])
            valid_adjudication_by_answer[row["answer_id"]] = row
        validation_rows.append({
            "validation_id": f"v61gd-adjudication-{index:05d}",
            "artifact": "adjudication_rows.csv",
            "row_key": row.get("answer_id", ""),
            "status": row_status,
            "reason": "partial adjudication row accepted" if row_status == "pass" else ";".join(errors),
        })
elif adjudication_rows:
    validation_rows.append({
        "validation_id": "v61gd-adjudication-fieldset",
        "artifact": "adjudication_rows.csv",
        "row_key": "field-set",
        "status": "blocked",
        "reason": "missing-fields:" + ";".join(sorted(set(ADJUDICATION_FIELDS) - set(adjudication_fields))),
    })

valid_identity_by_assignment = {}
if set(IDENTITY_FIELDS).issubset(identity_fields):
    seen = set()
    for index, row in enumerate(identity_rows, 1):
        errors = []
        assignment = assignment_by_id.get(row.get("assignment_id", ""))
        if assignment is None:
            errors.append("unknown-assignment-id")
        else:
            for field in ["reviewer_slot_id", "system_id", "review_scope"]:
                if row.get(field) != assignment[field]:
                    errors.append(f"mismatched-{field}")
        if row.get("assignment_id") in seen:
            errors.append("duplicate-assignment-id")
        if row.get("independence_declared") != "1":
            errors.append("independence-not-declared")
        if not valid_sha(row.get("credential_statement_sha256", "")):
            errors.append("invalid-credential-statement-sha256")
        row_status = "pass" if not errors else "blocked"
        if row_status == "pass":
            seen.add(row["assignment_id"])
            valid_identity_by_assignment[row["assignment_id"]] = row
        validation_rows.append({
            "validation_id": f"v61gd-identity-{index:05d}",
            "artifact": "reviewer_identity_rows.csv",
            "row_key": row.get("assignment_id", ""),
            "status": row_status,
            "reason": "partial reviewer identity row accepted" if row_status == "pass" else ";".join(errors),
        })

valid_conflict_pairs = set()
if set(CONFLICT_FIELDS).issubset(conflict_fields):
    seen = set()
    for index, row in enumerate(conflict_rows, 1):
        errors = []
        pair = (row.get("assignment_id", ""), row.get("owner_repo", ""))
        if pair not in expected_conflict_pairs:
            errors.append("unknown-assignment-repo-pair")
        if pair in seen:
            errors.append("duplicate-assignment-repo-pair")
        identity = valid_identity_by_assignment.get(row.get("assignment_id", ""))
        if identity and row.get("reviewer_id") != identity.get("reviewer_id"):
            errors.append("mismatched-reviewer-id")
        if row.get("conflict_declared") != "0":
            errors.append("conflict-not-clear")
        if not valid_sha(row.get("conflict_statement_sha256", "")):
            errors.append("invalid-conflict-statement-sha256")
        row_status = "pass" if not errors else "blocked"
        if row_status == "pass":
            seen.add(pair)
            valid_conflict_pairs.add(pair)
        validation_rows.append({
            "validation_id": f"v61gd-conflict-{index:05d}",
            "artifact": "reviewer_conflict_rows.csv",
            "row_key": f"{row.get('assignment_id', '')}:{row.get('owner_repo', '')}",
            "status": row_status,
            "reason": "partial conflict row accepted" if row_status == "pass" else ";".join(errors),
        })

acceptance_errors = []
if acceptance_path and acceptance_path.is_file():
    try:
        acceptance = json.loads(acceptance_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        acceptance = {}
        acceptance_errors.append("invalid-json")
    for field in ACCEPTANCE_FIELDS:
        if field not in acceptance:
            acceptance_errors.append(f"missing-{field}")
    expected = {
        "review_protocol_version": "v61gd-partial-v53-slice",
        "acceptance_decision": "accepted-partial-slice",
        "slice_scope": "partial",
        "accepted_human_review_rows": len(valid_human_by_answer),
        "human_review_rows_sha256": human_sha,
        "accepted_adjudication_rows": len(valid_adjudication_by_answer),
        "adjudication_rows_sha256": adjudication_sha,
        "accepted_reviewer_identity_rows": len(valid_identity_by_assignment),
        "reviewer_identity_rows_sha256": identity_sha,
        "accepted_conflict_disclosure_rows": len(valid_conflict_pairs),
        "reviewer_conflict_rows_sha256": conflict_sha,
    }
    for field, value in expected.items():
        if field in acceptance and str(acceptance[field]) != str(value):
            acceptance_errors.append(f"mismatched-{field}")
else:
    acceptance_errors.append("missing-acceptance-summary")
slice_acceptance_summary_ready = int(not acceptance_errors)
validation_rows.append({
    "validation_id": "v61gd-partial-slice-acceptance-summary",
    "artifact": "acceptance_summary.json",
    "row_key": "acceptance_summary",
    "status": "pass" if slice_acceptance_summary_ready else "blocked",
    "reason": "partial acceptance summary hash/count binding accepted" if slice_acceptance_summary_ready else ";".join(acceptance_errors),
})

if not validation_rows:
    validation_rows.append({
        "validation_id": "v61gd-default-no-root",
        "artifact": "none",
        "row_key": "none",
        "status": "blocked",
        "reason": "no v53 external return root supplied",
    })
write_csv(run_dir / "v53_partial_external_return_slice_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

candidate_answer_acceptance_rows = []
for answer_id, human in sorted(valid_human_by_answer.items()):
    answer = answer_by_id[answer_id]
    queue = queue_by_answer.get(answer_id)
    p0_required = int(queue is not None and queue.get("priority_class") == "p0_answer_or_policy_mismatch")
    adjudication_ready = int((not p0_required) or answer_id in valid_adjudication_by_answer)
    matching_identities = [
        row for row in valid_identity_by_assignment.values()
        if row["system_id"] == answer["system_id"]
    ]
    identity_ready = int(bool(matching_identities))
    conflict_ready = 0
    if matching_identities:
        conflict_ready = int(any((identity["assignment_id"], answer["owner_repo"]) in valid_conflict_pairs for identity in matching_identities))
    candidate_accepted = int(adjudication_ready and identity_ready and conflict_ready and slice_acceptance_summary_ready)
    real_accepted = int(candidate_accepted and real_provenance_ready)
    candidate_answer_acceptance_rows.append({
        "answer_id": answer_id,
        "review_answer_packet_id": answer["review_answer_packet_id"],
        "system_id": answer["system_id"],
        "query_id": answer["query_id"],
        "owner_repo": answer["owner_repo"],
        "human_review_valid": "1",
        "adjudication_required": str(p0_required),
        "adjudication_ready": str(adjudication_ready),
        "reviewer_identity_ready": str(identity_ready),
        "conflict_disclosure_ready": str(conflict_ready),
        "slice_acceptance_summary_ready": str(slice_acceptance_summary_ready),
        "candidate_answer_review_accepted": str(candidate_accepted),
        "real_external_answer_review_accepted": str(real_accepted),
        "claim_boundary": "subset-scope only; full v53/v1.0 remains blocked",
    })
if not candidate_answer_acceptance_rows:
    candidate_answer_acceptance_rows.append({
        "answer_id": "",
        "review_answer_packet_id": "",
        "system_id": "",
        "query_id": "",
        "owner_repo": "",
        "human_review_valid": "0",
        "adjudication_required": "0",
        "adjudication_ready": "0",
        "reviewer_identity_ready": "0",
        "conflict_disclosure_ready": "0",
        "slice_acceptance_summary_ready": str(slice_acceptance_summary_ready),
        "candidate_answer_review_accepted": "0",
        "real_external_answer_review_accepted": "0",
        "claim_boundary": "no supplied valid partial slice",
    })
write_csv(run_dir / "v53_partial_external_return_slice_answer_acceptance_rows.csv", list(candidate_answer_acceptance_rows[0].keys()), candidate_answer_acceptance_rows)

template_rows = []
first_p0 = next((row for row in queue_rows if row["priority_class"] == "p0_answer_or_policy_mismatch"), queue_rows[0])
first_answer = answer_by_id[first_p0["answer_id"]]
first_assignment = next(row for row in assignment_rows if row["system_id"] == first_answer["system_id"])
template_rows.extend([
    {
        "template_artifact": "aggregate_review_return/human_review_rows.csv",
        "field_hint": ",".join(HUMAN_FIELDS),
        "minimum_slice_note": f"include at least answer_id={first_answer['answer_id']} with real reviewer decision",
    },
    {
        "template_artifact": "aggregate_review_return/adjudication_rows.csv",
        "field_hint": ",".join(ADJUDICATION_FIELDS),
        "minimum_slice_note": f"include adjudication for p0 answer_id={first_answer['answer_id']}",
    },
    {
        "template_artifact": "aggregate_review_return/reviewer_identity_rows.csv",
        "field_hint": ",".join(IDENTITY_FIELDS),
        "minimum_slice_note": f"include assignment_id={first_assignment['assignment_id']}",
    },
    {
        "template_artifact": "aggregate_review_return/reviewer_conflict_rows.csv",
        "field_hint": ",".join(CONFLICT_FIELDS),
        "minimum_slice_note": f"include assignment_id={first_assignment['assignment_id']} and owner_repo={first_answer['owner_repo']}",
    },
    {
        "template_artifact": "aggregate_review_return/acceptance_summary.json",
        "field_hint": ",".join(ACCEPTANCE_FIELDS),
        "minimum_slice_note": "bind exact sha256/counts for the partial slice",
    },
    {
        "template_artifact": PROVENANCE_MARKER,
        "field_hint": "provenance,source_class,reviewer_authority_path,reviewer_authority_sha256",
        "minimum_slice_note": "source_class must be external; authority path must stay inside root and hash-match non-fixture text",
    },
])
write_csv(run_dir / "v53_partial_external_return_slice_minimum_template_rows.csv", list(template_rows[0].keys()), template_rows)

candidate_human = len(valid_human_by_answer)
candidate_adjudication = len(valid_adjudication_by_answer)
candidate_identity = len(valid_identity_by_assignment)
candidate_conflict = len(valid_conflict_pairs)
candidate_answer_accepted = sum(row["candidate_answer_review_accepted"] == "1" for row in candidate_answer_acceptance_rows)
real_external_review_return_rows = candidate_human if real_provenance_ready else 0
real_adjudication_rows = candidate_adjudication if real_provenance_ready else 0
slice_answer_review_accepted_rows = sum(row["real_external_answer_review_accepted"] == "1" for row in candidate_answer_acceptance_rows)
partial_real_slice_ready = int(slice_answer_review_accepted_rows > 0 and real_adjudication_rows > 0)

stage_rows = [
    {"stage_id": "01-v61gc-source", "status": "ready", "evidence": "v61gc root admission snapshot ready"},
    {"stage_id": "02-v53r-source", "status": "ready", "evidence": "v53r complete-source review packet ready"},
    {"stage_id": "03-v53-root-supplied", "status": "ready" if root_exists else "blocked", "evidence": f"root_supplied={root_supplied}; root_exists={root_exists}; aggregate_exists={aggregate_exists}"},
    {"stage_id": "04-real-provenance-marker", "status": "ready" if real_provenance_ready else "blocked", "evidence": f"env_real={env_real_provenance}; marker_real={marker_real_provenance}; errors={';'.join(marker_errors)}"},
    {"stage_id": "05-partial-review-slice", "status": "ready" if partial_real_slice_ready else "blocked", "evidence": f"real_external_review_return_rows={real_external_review_return_rows}; real_adjudication_rows={real_adjudication_rows}; slice_answer_review_accepted_rows={slice_answer_review_accepted_rows}"},
    {"stage_id": "06-full-v53-review-return", "status": "blocked", "evidence": "subset slice does not close full 7000/1000 review return"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "v61gd only handles v53 external review slice"},
]
write_csv(run_dir / "v53_partial_external_return_slice_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("V53_PARTIAL_EXTERNAL_RETURN_SLICE_VALIDATION_ROWS.csv", run_dir / "v53_partial_external_return_slice_validation_rows.csv"),
    ("V53_PARTIAL_EXTERNAL_RETURN_SLICE_ANSWER_ACCEPTANCE_ROWS.csv", run_dir / "v53_partial_external_return_slice_answer_acceptance_rows.csv"),
    ("V53_PARTIAL_EXTERNAL_RETURN_SLICE_MINIMUM_TEMPLATE_ROWS.csv", run_dir / "v53_partial_external_return_slice_minimum_template_rows.csv"),
    ("V53_PARTIAL_EXTERNAL_RETURN_SLICE_STAGE_ROWS.csv", run_dir / "v53_partial_external_return_slice_stage_rows.csv"),
    ("V53_PARTIAL_EXTERNAL_RETURN_SLICE_SUPPLIED_FILE_ROWS.csv", run_dir / "v53_partial_external_return_slice_supplied_file_rows.csv"),
]:
    shutil.copy2(path, slice_dir / rel)

slice_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53_return_root_supplied": root_supplied,
    "v53_return_root_exists": root_exists,
    "v53_real_provenance_ready": real_provenance_ready,
    "candidate_human_review_rows": candidate_human,
    "candidate_adjudication_rows": candidate_adjudication,
    "real_external_review_return_rows": real_external_review_return_rows,
    "real_adjudication_rows": real_adjudication_rows,
    "slice_answer_review_accepted_rows": slice_answer_review_accepted_rows,
    "partial_real_slice_ready": partial_real_slice_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(slice_dir / "V53_PARTIAL_EXTERNAL_RETURN_SLICE_MANIFEST.json").write_text(json.dumps(slice_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(slice_dir / "VERIFY_V53_PARTIAL_EXTERNAL_RETURN_SLICE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_MANIFEST.json\"",
        "test -s \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_VALIDATION_ROWS.csv\"",
        "test -s \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_ANSWER_ACCEPTANCE_ROWS.csv\"",
        "test -s \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_MINIMUM_TEMPLATE_ROWS.csv\"",
        "test -s \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_STAGE_ROWS.csv\"",
        "grep -q 'partial_real_slice_ready' \"$DIR/V53_PARTIAL_EXTERNAL_RETURN_SLICE_MANIFEST.json\"",
        "",
    ]),
    encoding="utf-8",
)
(slice_dir / "VERIFY_V53_PARTIAL_EXTERNAL_RETURN_SLICE.sh").chmod(0o755)
(slice_dir / "V53_PARTIAL_EXTERNAL_RETURN_SLICE.md").write_text(
    "\n".join([
        "# v61gd v53 partial external return slice intake",
        "",
        f"- v53_return_root_supplied={root_supplied}",
        f"- v53_return_root_exists={root_exists}",
        f"- v53_real_provenance_ready={real_provenance_ready}",
        f"- candidate_human_review_rows={candidate_human}",
        f"- candidate_adjudication_rows={candidate_adjudication}",
        f"- real_external_review_return_rows={real_external_review_return_rows}",
        f"- real_adjudication_rows={real_adjudication_rows}",
        f"- slice_answer_review_accepted_rows={slice_answer_review_accepted_rows}",
        "- full_v53_review_return_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "This is subset-scope review return intake only. It does not close the full 7000/1000 review return, v1.0 comparison, actual generation, production latency, near-frontier, or release readiness.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in slice_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "v53_partial_external_return_slice_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": "1",
    "v61gc_post_gb_dual_return_root_admission_snapshot_ready": v61gc["v61gc_post_gb_dual_return_root_admission_snapshot_ready"],
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v53_return_root_supplied": str(root_supplied),
    "v53_return_root_exists": str(root_exists),
    "v53_aggregate_review_return_dir_exists": str(aggregate_exists),
    "v53_env_real_provenance": str(env_real_provenance),
    "v53_marker_supplied": str(marker_supplied),
    "v53_marker_real_provenance": str(marker_real_provenance),
    "v53_marker_authority_file_exists": str(marker_authority_file_exists),
    "v53_marker_authority_file_sha256": marker_authority_file_sha,
    "v53_real_provenance_ready": str(real_provenance_ready),
    "candidate_human_review_rows": str(candidate_human),
    "candidate_adjudication_rows": str(candidate_adjudication),
    "candidate_reviewer_identity_rows": str(candidate_identity),
    "candidate_conflict_disclosure_rows": str(candidate_conflict),
    "candidate_acceptance_summary_ready": str(slice_acceptance_summary_ready),
    "candidate_answer_review_accepted_rows": str(candidate_answer_accepted),
    "real_external_review_return_rows": str(real_external_review_return_rows),
    "real_adjudication_rows": str(real_adjudication_rows),
    "slice_answer_review_accepted_rows": str(slice_answer_review_accepted_rows),
    "partial_real_slice_ready": str(partial_real_slice_ready),
    "full_v53_review_return_ready": "0",
    "v53_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": str(partial_real_slice_ready),
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "validation_rows": str(len(validation_rows)),
    "source_file_rows": str(len(source_rows)),
    "slice_package_file_rows": str(len(package_file_rows)),
    "metadata_only_slice_package_file_rows": str(sum(row["metadata_only"] == "1" for row in package_file_rows)),
    "payload_like_slice_package_file_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gc-ready", "status": "pass", "evidence": "v61gc ready"},
    {"gate": "source-v53r-ready", "status": "pass", "evidence": "v53r ready"},
    {"gate": "v53-root-supplied", "status": status(root_exists), "evidence": f"root_supplied={root_supplied}; root_exists={root_exists}"},
    {"gate": "v53-real-provenance", "status": status(real_provenance_ready), "evidence": f"env_real={env_real_provenance}; marker_real={marker_real_provenance}; errors={';'.join(marker_errors)}"},
    {"gate": "candidate-partial-review-slice", "status": status(candidate_answer_accepted > 0), "evidence": f"candidate_answer_review_accepted_rows={candidate_answer_accepted}"},
    {"gate": "real-external-review-return-slice", "status": status(real_external_review_return_rows > 0), "evidence": f"real_external_review_return_rows={real_external_review_return_rows}"},
    {"gate": "real-adjudication-slice", "status": status(real_adjudication_rows > 0), "evidence": f"real_adjudication_rows={real_adjudication_rows}"},
    {"gate": "subset-answer-review-acceptance", "status": status(slice_answer_review_accepted_rows > 0), "evidence": f"slice_answer_review_accepted_rows={slice_answer_review_accepted_rows}"},
    {"gate": "full-v53-review-return", "status": "blocked", "evidence": "subset slice is not full 7000/1000 review return"},
    {"gate": "dual-root-replay", "status": "blocked", "evidence": "v61gd only opens v53 subset row acceptance, not dual replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GD Post-GC V53 Partial External Return Slice Intake Boundary",
    "",
    f"- v61gd_post_gc_v53_partial_external_return_slice_intake_ready={summary['v61gd_post_gc_v53_partial_external_return_slice_intake_ready']}",
    f"- v53_return_root_supplied={summary['v53_return_root_supplied']}",
    f"- v53_return_root_exists={summary['v53_return_root_exists']}",
    f"- v53_real_provenance_ready={summary['v53_real_provenance_ready']}",
    f"- candidate_human_review_rows={summary['candidate_human_review_rows']}",
    f"- candidate_adjudication_rows={summary['candidate_adjudication_rows']}",
    f"- candidate_answer_review_accepted_rows={summary['candidate_answer_review_accepted_rows']}",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- real_adjudication_rows={summary['real_adjudication_rows']}",
    f"- slice_answer_review_accepted_rows={summary['slice_answer_review_accepted_rows']}",
    f"- partial_real_slice_ready={summary['partial_real_slice_ready']}",
    "- full_v53_review_return_ready=0",
    "- v53_ready=0",
    "- dual_external_return_real_ready=0",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this subset-scope slice is not the full v53 review return, dual-root replay, actual generation, production latency, near-frontier, v1.0 comparison, or release evidence.",
    "",
])
(run_dir / "V61GD_POST_GC_V53_PARTIAL_EXTERNAL_RETURN_SLICE_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "slice_manifest": slice_manifest,
    "checkpoint_payload_bytes_downloaded_by_v61gd": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gd_post_gc_v53_partial_external_return_slice_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
