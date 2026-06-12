#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53s_complete_source_review_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53s_complete_source_review_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53s_complete_source_review_return_intake_decision.csv"

V53S_REUSE_EXISTING="${V53S_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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
    "v53s_complete_source_review_return_intake_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "review_return_input_supplied": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "invalid_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "invalid_adjudication_rows": "0",
    "expected_reviewer_assignment_rows": "21",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "invalid_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "invalid_conflict_disclosure_rows": "0",
    "return_artifact_rows": "5",
    "return_validation_rows": "1",
    "human_review_completed": "0",
    "adjudication_completed": "0",
    "reviewer_identity_ready": "0",
    "conflict_disclosure_ready": "0",
    "acceptance_summary_ready": "0",
    "acceptance_summary_error_count": "0",
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53s {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_required_field_rows.csv",
    "review_return_row_template.csv",
    "review_return_validation_rows.csv",
    "review_return_artifact_gate_rows.csv",
    "review_return_metric_rows.csv",
    "V53S_COMPLETE_SOURCE_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    "v53s_complete_source_review_return_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v53r/reviewer_assignment_template_rows.csv",
    "source_v53r/review_return_template_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53s artifact: {rel}")

required_fields = read_csv(run_dir / "review_return_required_field_rows.csv")
templates = read_csv(run_dir / "review_return_row_template.csv")
validation_rows = read_csv(run_dir / "review_return_validation_rows.csv")
artifact_gates = read_csv(run_dir / "review_return_artifact_gate_rows.csv")
metric = read_csv(run_dir / "review_return_metric_rows.csv")[0]
if len(required_fields) != 29:
    raise SystemExit("v53s required field row count mismatch")
if len(templates) != 5 or len(artifact_gates) != 5:
    raise SystemExit("v53s template/artifact row count mismatch")
if len(validation_rows) != 1 or validation_rows[0]["status"] != "blocked":
    raise SystemExit("v53s default validation should record one blocked no-return row")
if any(row["supplied"] != "0" or row["accepted"] != "0" for row in artifact_gates):
    raise SystemExit("v53s default path must not accept return artifacts")
if artifact_gates[0]["return_artifact"] != "human_review_rows.csv":
    raise SystemExit("v53s artifact ordering mismatch")
for field, value in expected.items():
    if field.startswith("v53s_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53s metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v53r-review-packet-input", "review-return-schema", "default-no-env-deferral"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53s gate should pass: {gate}")
for gate in [
    "human-review-artifacts",
    "adjudication-artifacts",
    "reviewer-identity",
    "conflict-disclosure",
    "acceptance-summary",
    "review-return-ready",
    "quality-comparison-claim",
    "v53-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53s gate should stay blocked: {gate}")

boundary = (run_dir / "V53S_COMPLETE_SOURCE_REVIEW_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "expected_adjudication_rows=1000",
    "accepted_adjudication_rows=0",
    "expected_reviewer_identity_rows=21",
    "expected_conflict_disclosure_rows=210",
    "review_return_input_supplied=0",
    "human_review_completed=0",
    "adjudication_completed=0",
    "review_return_ready=0",
    "quality_comparison_claim_ready=0",
    "v53_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53s boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53s_complete_source_review_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53s_complete_source_review_return_intake_ready") != 1:
    raise SystemExit("v53s manifest readiness mismatch")
if manifest.get("review_return_ready") != 0 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53s manifest boundary mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53s sha256 mismatch: {rel}")
PY

FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v53s_actual_return_fixture.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

python3 - "$RUN_DIR" "$FIXTURE_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_dir = Path(sys.argv[2])
source_dir = run_dir / "source_v53r"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def stable_hash(*parts):
    return "sha256:" + hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


answer_rows = read_csv(source_dir / "review_answer_packet_rows.csv")
queue_rows = read_csv(source_dir / "review_queue_rows.csv")
assignment_rows = read_csv(source_dir / "reviewer_assignment_template_rows.csv")
p0_answer_ids = {row["answer_id"] for row in queue_rows if row["priority_class"] == "p0_answer_or_policy_mismatch"}
owner_repos = sorted({row["owner_repo"] for row in answer_rows})

human_fields = [
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
human_rows = []
for row in answer_rows:
    decision = "needs-adjudication" if row["answer_id"] in p0_answer_ids else "accept"
    human_rows.append(
        {
            "review_answer_packet_id": row["review_answer_packet_id"],
            "answer_id": row["answer_id"],
            "system_id": row["system_id"],
            "query_id": row["query_id"],
            "reviewer_id": f"fixture_reviewer_{row['system_id'].lower()}_primary",
            "review_decision": decision,
            "source_support_verified": "1",
            "citation_verified": "1",
            "policy_verified": "1",
            "review_comment_sha256": stable_hash("human", row["answer_id"]),
        }
    )
write_csv(fixture_dir / "human_review_rows.csv", human_fields, human_rows)

adjudication_fields = [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
]
adjudication_rows = []
for index, row in enumerate(queue_rows, start=1):
    if row["answer_id"] not in p0_answer_ids:
        continue
    adjudication_rows.append(
        {
            "adjudication_id": f"fixture_adjudication_{index:04d}",
            "review_answer_packet_id": row["review_answer_packet_id"],
            "answer_id": row["answer_id"],
            "adjudicator_id": "fixture_adjudicator_001",
            "adjudication_decision": "accept",
            "adjudication_reason_sha256": stable_hash("adjudication", row["answer_id"]),
        }
    )
write_csv(fixture_dir / "adjudication_rows.csv", adjudication_fields, adjudication_rows)

identity_fields = [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
]
identity_rows = []
reviewer_by_assignment = {}
for row in assignment_rows:
    reviewer_id = f"fixture_reviewer_{row['system_id'].lower()}_{row['reviewer_slot_id']}"
    reviewer_by_assignment[row["assignment_id"]] = reviewer_id
    identity_rows.append(
        {
            "assignment_id": row["assignment_id"],
            "reviewer_id": reviewer_id,
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "independence_declared": "1",
            "credential_statement_sha256": stable_hash("identity", row["assignment_id"]),
        }
    )
write_csv(fixture_dir / "reviewer_identity_rows.csv", identity_fields, identity_rows)

conflict_fields = [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
]
conflict_rows = []
for assignment in assignment_rows:
    for owner_repo in owner_repos:
        conflict_rows.append(
            {
                "assignment_id": assignment["assignment_id"],
                "reviewer_id": reviewer_by_assignment[assignment["assignment_id"]],
                "owner_repo": owner_repo,
                "conflict_declared": "0",
                "conflict_statement_sha256": stable_hash("conflict", assignment["assignment_id"], owner_repo),
            }
        )
write_csv(fixture_dir / "reviewer_conflict_rows.csv", conflict_fields, conflict_rows)

acceptance = {
    "review_protocol_version": "v53s",
    "acceptance_decision": "accepted",
    "expected_human_review_rows": len(answer_rows),
    "accepted_human_review_rows": len(answer_rows),
    "human_review_rows_sha256": sha256(fixture_dir / "human_review_rows.csv"),
    "expected_adjudication_rows": len(adjudication_rows),
    "accepted_adjudication_rows": len(adjudication_rows),
    "adjudication_rows_sha256": sha256(fixture_dir / "adjudication_rows.csv"),
    "expected_reviewer_identity_rows": len(identity_rows),
    "accepted_reviewer_identity_rows": len(identity_rows),
    "reviewer_identity_rows_sha256": sha256(fixture_dir / "reviewer_identity_rows.csv"),
    "expected_conflict_disclosure_rows": len(conflict_rows),
    "accepted_conflict_disclosure_rows": len(conflict_rows),
    "reviewer_conflict_rows_sha256": sha256(fixture_dir / "reviewer_conflict_rows.csv"),
}
(fixture_dir / "acceptance_summary.json").write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V53S_REUSE_EXISTING=0 \
V53S_RUN_ID=intake_fixture \
V53S_REVIEW_RETURN_DIR="$FIXTURE_DIR" \
"$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

FIXTURE_RUN_DIR="$RESULTS_DIR/v53s_complete_source_review_return_intake/intake_fixture"
python3 - "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "review_return_input_supplied": "1",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "7000",
    "invalid_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "1000",
    "invalid_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "21",
    "invalid_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "210",
    "invalid_conflict_disclosure_rows": "0",
    "return_validation_rows": "8232",
    "human_review_completed": "1",
    "adjudication_completed": "1",
    "reviewer_identity_ready": "1",
    "conflict_disclosure_ready": "1",
    "acceptance_summary_ready": "1",
    "acceptance_summary_error_count": "0",
    "review_return_ready": "1",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53s fixture {field}: expected {value}, got {summary.get(field)}")

artifact_gates = read_csv(run_dir / "review_return_artifact_gate_rows.csv")
if len(artifact_gates) != 5:
    raise SystemExit("v53s fixture artifact row count mismatch")
if any(row["supplied"] != "1" or row["accepted"] != "1" or row["field_validation_status"] != "pass" for row in artifact_gates):
    raise SystemExit("v53s fixture artifacts should all be supplied and accepted")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "human-review-artifacts",
    "adjudication-artifacts",
    "reviewer-identity",
    "conflict-disclosure",
    "acceptance-summary",
    "review-return-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53s fixture gate should pass: {gate}")
if decisions.get("default-no-env-deferral") != "not-applicable":
    raise SystemExit("v53s fixture should mark default no-env gate not-applicable")
for gate in ["quality-comparison-claim", "v53-ready", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53s fixture gate should stay blocked: {gate}")

manifest = json.loads((run_dir / "v53s_complete_source_review_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("review_return_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53s fixture manifest boundary mismatch")
PY

rm -rf "$FIXTURE_RUN_DIR"
V53S_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

echo "v53s complete-source review return intake smoke passed"
