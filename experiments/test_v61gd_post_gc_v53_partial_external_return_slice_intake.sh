#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gd_post_gc_v53_partial_external_return_slice_intake"
RUN_DIR="$RESULTS_DIR/$PREFIX/slice_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SLICE_DIR="$RUN_DIR/v53_partial_external_return_slice_intake"

V61GD_REUSE_EXISTING="${V61GD_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gd_post_gc_v53_partial_external_return_slice_intake.sh" >/dev/null

"$SLICE_DIR/VERIFY_V53_PARTIAL_EXTERNAL_RETURN_SLICE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SLICE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
slice_dir = Path(sys.argv[4])


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
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": "1",
    "v61gc_post_gb_dual_return_root_admission_snapshot_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v53_return_root_supplied": "0",
    "v53_return_root_exists": "0",
    "v53_aggregate_review_return_dir_exists": "0",
    "v53_env_real_provenance": "0",
    "v53_marker_supplied": "0",
    "v53_marker_real_provenance": "0",
    "v53_real_provenance_ready": "0",
    "candidate_human_review_rows": "0",
    "candidate_adjudication_rows": "0",
    "candidate_reviewer_identity_rows": "0",
    "candidate_conflict_disclosure_rows": "0",
    "candidate_acceptance_summary_ready": "0",
    "candidate_answer_review_accepted_rows": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "partial_real_slice_ready": "0",
    "full_v53_review_return_ready": "0",
    "v53_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "7",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "5",
    "source_file_rows": "6",
    "payload_like_slice_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gd {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "v53_partial_external_return_slice_validation_rows.csv",
    "v53_partial_external_return_slice_answer_acceptance_rows.csv",
    "v53_partial_external_return_slice_minimum_template_rows.csv",
    "v53_partial_external_return_slice_stage_rows.csv",
    "v53_partial_external_return_slice_supplied_file_rows.csv",
    "v53_partial_external_return_slice_source_rows.csv",
    "v53_partial_external_return_slice_package_file_rows.csv",
    "V61GD_POST_GC_V53_PARTIAL_EXTERNAL_RETURN_SLICE_INTAKE_BOUNDARY.md",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_manifest.json",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_summary.csv",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_decision.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_VALIDATION_ROWS.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_ANSWER_ACCEPTANCE_ROWS.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_MINIMUM_TEMPLATE_ROWS.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_STAGE_ROWS.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_SUPPLIED_FILE_ROWS.csv",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE_MANIFEST.json",
    "v53_partial_external_return_slice_intake/V53_PARTIAL_EXTERNAL_RETURN_SLICE.md",
    "v53_partial_external_return_slice_intake/VERIFY_V53_PARTIAL_EXTERNAL_RETURN_SLICE.sh",
    "source_v61gc/v61gc_post_gb_dual_return_root_admission_snapshot_summary.csv",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gd artifact: {rel}")

if not os.access(slice_dir / "VERIFY_V53_PARTIAL_EXTERNAL_RETURN_SLICE.sh", os.X_OK):
    raise SystemExit("v61gd verifier must be executable")

templates = read_csv(run_dir / "v53_partial_external_return_slice_minimum_template_rows.csv")
if len(templates) != 6:
    raise SystemExit("v61gd expected six minimum template rows")
if not any(row["template_artifact"] == "REAL_EXTERNAL_RETURN_PROVENANCE.json" for row in templates):
    raise SystemExit("v61gd must require a real provenance marker template")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gc-ready", "source-v53r-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gd expected pass decision: {gate}")
for gate in [
    "v53-root-supplied",
    "v53-real-provenance",
    "candidate-partial-review-slice",
    "real-external-review-return-slice",
    "real-adjudication-slice",
    "subset-answer-review-acceptance",
    "full-v53-review-return",
    "dual-root-replay",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gd expected blocked decision: {gate}")

manifest = json.loads((slice_dir / "V53_PARTIAL_EXTERNAL_RETURN_SLICE_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("partial_real_slice_ready") != 0:
    raise SystemExit("v61gd default manifest must keep partial real slice blocked")
if manifest.get("real_external_review_return_rows") != 0:
    raise SystemExit("v61gd default manifest must not claim real review return rows")

boundary = (run_dir / "V61GD_POST_GC_V53_PARTIAL_EXTERNAL_RETURN_SLICE_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready=1",
    "real_external_review_return_rows=0",
    "real_adjudication_rows=0",
    "slice_answer_review_accepted_rows=0",
    "partial_real_slice_ready=0",
    "full_v53_review_return_ready=0",
    "dual_external_return_real_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gd boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gd sha256 mismatch: {rel}")

print("v61gd default no-root slice intake smoke passed")
PY

TMP_ROOT="${TMPDIR:-/tmp}/v61gd_candidate_fixture_root"
rm -rf "$TMP_ROOT"

python3 - "$ROOT_DIR" "$TMP_ROOT" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
tmp_root = Path(sys.argv[2])
agg = tmp_root / "aggregate_review_return"
agg.mkdir(parents=True, exist_ok=True)
results = root / "results"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


answers = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_answer_packet_rows.csv")
queue = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_queue_rows.csv")
assignments = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "reviewer_assignment_template_rows.csv")
first_queue = next(row for row in queue if row["priority_class"] == "p0_answer_or_policy_mismatch")
answer = next(row for row in answers if row["answer_id"] == first_queue["answer_id"])
assignment = next(row for row in assignments if row["system_id"] == answer["system_id"])
reviewer_id = "fixture_reviewer_v61gd"

human_path = agg / "human_review_rows.csv"
write_csv(human_path, [
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
], [{
    "review_answer_packet_id": answer["review_answer_packet_id"],
    "answer_id": answer["answer_id"],
    "system_id": answer["system_id"],
    "query_id": answer["query_id"],
    "reviewer_id": reviewer_id,
    "review_decision": "accept",
    "source_support_verified": "1",
    "citation_verified": "1",
    "policy_verified": "1",
    "review_comment_sha256": sha_text("fixture partial review comment"),
}])

adjudication_path = agg / "adjudication_rows.csv"
write_csv(adjudication_path, [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
], [{
    "adjudication_id": "fixture_v61gd_adjudication_001",
    "review_answer_packet_id": answer["review_answer_packet_id"],
    "answer_id": answer["answer_id"],
    "adjudicator_id": "fixture_adjudicator_v61gd",
    "adjudication_decision": "accept",
    "adjudication_reason_sha256": sha_text("fixture partial adjudication reason"),
}])

identity_path = agg / "reviewer_identity_rows.csv"
write_csv(identity_path, [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
], [{
    "assignment_id": assignment["assignment_id"],
    "reviewer_id": reviewer_id,
    "reviewer_slot_id": assignment["reviewer_slot_id"],
    "system_id": assignment["system_id"],
    "review_scope": assignment["review_scope"],
    "independence_declared": "1",
    "credential_statement_sha256": sha_text("fixture reviewer credential"),
}])

conflict_path = agg / "reviewer_conflict_rows.csv"
write_csv(conflict_path, [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
], [{
    "assignment_id": assignment["assignment_id"],
    "reviewer_id": reviewer_id,
    "owner_repo": answer["owner_repo"],
    "conflict_declared": "0",
    "conflict_statement_sha256": sha_text("fixture no conflict statement"),
}])

acceptance = {
    "review_protocol_version": "v61gd-partial-v53-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_human_review_rows": 1,
    "human_review_rows_sha256": sha_file(human_path),
    "accepted_adjudication_rows": 1,
    "adjudication_rows_sha256": sha_file(adjudication_path),
    "accepted_reviewer_identity_rows": 1,
    "reviewer_identity_rows_sha256": sha_file(identity_path),
    "accepted_conflict_disclosure_rows": 1,
    "reviewer_conflict_rows_sha256": sha_file(conflict_path),
}
(agg / "acceptance_summary.json").write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(tmp_root / "REAL_EXTERNAL_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-external-return-bundle",
    "source_class": "external-review-return",
    "reviewer_authority_path": "operator_attestation/missing_reviewer_authority_statement.txt",
    "reviewer_authority_sha256": sha_text("fixture authority is intentionally rejected"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GD_RUN_ID="fixture_candidate" \
V61GD_V53_RETURN_ROOT="$TMP_ROOT" \
V61GD_V53_RETURN_PROVENANCE="real-external-return-bundle" \
V61GD_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gd_post_gc_v53_partial_external_return_slice_intake.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/fixture_candidate" "$RESULTS_DIR/${PREFIX}_summary.csv" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53_return_root_supplied": "1",
    "v53_return_root_exists": "1",
    "v53_aggregate_review_return_dir_exists": "1",
    "v53_env_real_provenance": "1",
    "v53_marker_supplied": "1",
    "v53_marker_real_provenance": "0",
    "v53_real_provenance_ready": "0",
    "candidate_human_review_rows": "1",
    "candidate_adjudication_rows": "1",
    "candidate_reviewer_identity_rows": "1",
    "candidate_conflict_disclosure_rows": "1",
    "candidate_acceptance_summary_ready": "1",
    "candidate_answer_review_accepted_rows": "1",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "partial_real_slice_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gd fixture candidate {field}: expected {value}, got {summary.get(field)}")

decision_rows = {row["gate"]: row for row in read_csv(run_dir / "v61gd_post_gc_v53_partial_external_return_slice_intake_decision.csv")}
if decision_rows["candidate-partial-review-slice"]["status"] != "pass":
    raise SystemExit("v61gd fixture candidate should pass candidate slice mechanics")
for gate in ["v53-real-provenance", "real-external-review-return-slice", "real-adjudication-slice", "subset-answer-review-acceptance"]:
    if decision_rows[gate]["status"] != "blocked":
        raise SystemExit(f"v61gd fixture candidate must keep real gate blocked: {gate}")
if "authority-file-missing" not in decision_rows["v53-real-provenance"]["evidence"]:
    raise SystemExit("v61gd fixture candidate must reject external marker without authority file evidence")

print("v61gd fixture candidate rejection smoke passed")
PY

V61GD_RUN_ID="slice_001" \
V61GD_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gd_post_gc_v53_partial_external_return_slice_intake.sh" >/dev/null
