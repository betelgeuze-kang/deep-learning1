#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gf_post_ge_dual_partial_return_replay_admission"
RUN_DIR="$RESULTS_DIR/$PREFIX/admission_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/dual_partial_return_replay_admission"

V61GF_REUSE_EXISTING="${V61GF_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh" >/dev/null
"$PACKAGE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = Path(sys.argv[4])


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
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": "1",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": "1",
    "v61ge_post_gd_v61_partial_generation_intake_slice_ready": "1",
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": "1",
    "v53_return_root_supplied": "0",
    "v53_return_root_exists": "0",
    "v53_real_provenance_ready": "0",
    "candidate_answer_review_accepted_rows": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "partial_real_slice_ready": "0",
    "v61_return_root_supplied": "0",
    "v61_return_root_exists": "0",
    "v61_real_provenance_ready": "0",
    "candidate_generation_result_artifacts": "0",
    "candidate_generation_result_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "accepted_answer_rows": "0",
    "accepted_citation_rows": "0",
    "accepted_latency_rows": "0",
    "partial_real_generation_slice_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_result_row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "full_1000_query_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gf": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "10",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "7",
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "required_env_rows": "4",
    "ready_required_env_rows": "0",
    "source_file_rows": "10",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gf {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_partial_return_replay_admission_stage_rows.csv",
    "dual_partial_return_replay_admission_command_rows.csv",
    "dual_partial_return_replay_required_env_rows.csv",
    "dual_partial_return_replay_admission_source_rows.csv",
    "dual_partial_return_replay_admission_package_file_rows.csv",
    "V61GF_POST_GE_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_BOUNDARY.md",
    "v61gf_post_ge_dual_partial_return_replay_admission_manifest.json",
    "v61gf_post_ge_dual_partial_return_replay_admission_summary.csv",
    "v61gf_post_ge_dual_partial_return_replay_admission_decision.csv",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "dual_partial_return_replay_admission/RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh",
    "dual_partial_return_replay_admission/VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh",
    "dual_partial_return_replay_admission/READY_NOW_COMMANDS.sh",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_STAGE_ROWS.csv",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_COMMAND_ROWS.csv",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_REQUIRED_ENV_ROWS.csv",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_MANIFEST.json",
    "dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.md",
    "source_v61gd/v61gd_post_gc_v53_partial_external_return_slice_intake_summary.csv",
    "source_v61ge/v61ge_post_gd_v61_partial_generation_intake_slice_summary.csv",
    "source_v61fv/v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gf artifact: {rel}")

for rel in [
    "DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh",
    "VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gf executable bit missing: {rel}")

stages = read_csv(run_dir / "dual_partial_return_replay_admission_stage_rows.csv")
if len(stages) != 10:
    raise SystemExit("v61gf expected ten stage rows")
if sum(row["status"] == "ready" for row in stages) != 3:
    raise SystemExit("v61gf expected three ready stages by default")
if sum(row["status"] == "blocked" for row in stages) != 7:
    raise SystemExit("v61gf expected seven blocked stages by default")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gd-ready", "source-v61ge-ready", "source-v61fv-entrypoint-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gf expected pass decision: {gate}")
for gate in [
    "v53-real-partial-slice",
    "v61-real-generation-slice",
    "row-acceptance",
    "generation-execution-admission",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gf expected blocked decision: {gate}")

manifest = json.loads((package_dir / "DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("real_return_replay_admission_ready") != 0:
    raise SystemExit("v61gf default package must keep replay admission blocked")

boundary = (run_dir / "V61GF_POST_GE_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gf_post_ge_dual_partial_return_replay_admission_ready=1",
    "real_external_review_return_rows=0",
    "real_adjudication_rows=0",
    "slice_answer_review_accepted_rows=0",
    "real_generation_result_artifacts=0",
    "generation_result_accepted_rows=0",
    "dual_external_return_real_ready=0",
    "real_return_replay_admission_ready=0",
    "generation_acceptance_closure_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gf boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gf sha256 mismatch: {rel}")

print("v61gf default no-root dual partial replay admission smoke passed")
PY

TMP_ROOT="${TMPDIR:-/tmp}/v61gf_candidate_fixture_roots"
rm -rf "$TMP_ROOT"

python3 - "$ROOT_DIR" "$TMP_ROOT" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
tmp_root = Path(sys.argv[2])
v53_root = tmp_root / "v53"
v61_root = tmp_root / "v61"
agg = v53_root / "aggregate_review_return"
gen = v61_root / "generation_result_return"
prov = v61_root / "review_return_provenance"
agg.mkdir(parents=True, exist_ok=True)
gen.mkdir(parents=True, exist_ok=True)
prov.mkdir(parents=True, exist_ok=True)
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
reviewer_id = "fixture_reviewer_v61gf"

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
    "adjudication_id": "fixture_v61gf_adjudication_001",
    "review_answer_packet_id": answer["review_answer_packet_id"],
    "answer_id": answer["answer_id"],
    "adjudicator_id": "fixture_adjudicator_v61gf",
    "adjudication_decision": "accept",
    "adjudication_reason_sha256": sha_text("fixture adjudication reason"),
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
    "credential_statement_sha256": sha_text("fixture credential statement"),
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
    "conflict_statement_sha256": sha_text("fixture conflict clear"),
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
(v53_root / "REAL_EXTERNAL_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-external-return-bundle",
    "source_class": "fixture-candidate-return",
    "reviewer_authority_sha256": sha_text("fixture reviewer authority"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

query = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv")[0]
generation_id = "fixture_v61gf_generation_001"
latency_id = "fixture_v61gf_latency_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
checkpoint_root = "/fixture/rejected/checkpoint/root"

answer_gen_path = gen / "real_model_generation_answer_rows.csv"
write_csv(answer_gen_path, [
    "generation_id",
    "review_query_packet_id",
    "query_id",
    "source_span_id",
    "model_id",
    "checkpoint_root",
    "answer_text_sha256",
    "generation_status",
    "abstain_decision",
    "fallback_used",
    "latency_row_id",
    "run_transcript_sha256",
], [{
    "generation_id": generation_id,
    "review_query_packet_id": query["review_query_packet_id"],
    "query_id": query["query_id"],
    "source_span_id": query["source_span_id"],
    "model_id": model_id,
    "checkpoint_root": checkpoint_root,
    "answer_text_sha256": sha_text("fixture generation answer"),
    "generation_status": "generated",
    "abstain_decision": "0",
    "fallback_used": "0",
    "latency_row_id": latency_id,
    "run_transcript_sha256": sha_text("fixture transcript"),
}])

citation_path = gen / "real_model_generation_citation_rows.csv"
write_csv(citation_path, [
    "generation_id",
    "query_id",
    "citation_id",
    "source_span_id",
    "source_file_sha256",
    "citation_verified",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "citation_id": "fixture_v61gf_citation_001",
    "source_span_id": query["source_span_id"],
    "source_file_sha256": query["source_file_sha256"],
    "citation_verified": "1",
}])

abstain_path = gen / "real_model_generation_abstain_fallback_rows.csv"
write_csv(abstain_path, [
    "generation_id",
    "query_id",
    "expected_behavior",
    "abstain_expected",
    "abstain_observed",
    "fallback_used",
    "fallback_reason",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "expected_behavior": query["expected_behavior"],
    "abstain_expected": "0",
    "abstain_observed": "0",
    "fallback_used": "0",
    "fallback_reason": "",
}])

latency_path = gen / "real_model_generation_latency_rows.csv"
write_csv(latency_path, [
    "generation_id",
    "query_id",
    "prompt_tokens",
    "output_tokens",
    "prefill_ms",
    "decode_ms",
    "total_ms",
    "tokens_per_second",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "prompt_tokens": "128",
    "output_tokens": "32",
    "prefill_ms": "11.0",
    "decode_ms": "22.0",
    "total_ms": "33.0",
    "tokens_per_second": "969.696969",
}])

generation_acceptance = {
    "generation_protocol_version": "v61ge-partial-generation-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_answer_rows": 1,
    "answer_rows_sha256": sha_file(answer_gen_path),
    "accepted_citation_rows": 1,
    "citation_rows_sha256": sha_file(citation_path),
    "accepted_abstain_fallback_rows": 1,
    "abstain_fallback_rows_sha256": sha_file(abstain_path),
    "accepted_latency_rows": 1,
    "latency_rows_sha256": sha_file(latency_path),
}
(gen / "real_model_generation_acceptance_summary.json").write_text(json.dumps(generation_acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(prov / "REAL_REVIEW_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-generation-intake-return-bundle",
    "source_class": "fixture-generation-intake-return",
    "generation_operator_authority_sha256": sha_text("fixture generation operator authority"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GF_RUN_ID="fixture_candidate" \
V61GF_V53_RETURN_ROOT="$TMP_ROOT/v53" \
V61GF_V53_RETURN_PROVENANCE="real-external-return-bundle" \
V61GF_V61_RETURN_ROOT="$TMP_ROOT/v61" \
V61GF_V61_RETURN_PROVENANCE="real-generation-intake-return-bundle" \
V61GF_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/fixture_candidate" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
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
    "v53_return_root_supplied": "1",
    "v53_return_root_exists": "1",
    "v53_real_provenance_ready": "0",
    "candidate_answer_review_accepted_rows": "1",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "partial_real_slice_ready": "0",
    "v61_return_root_supplied": "1",
    "v61_return_root_exists": "1",
    "v61_real_provenance_ready": "0",
    "candidate_generation_result_artifacts": "5",
    "candidate_generation_result_accepted_rows": "1",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "partial_real_generation_slice_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gf fixture candidate {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53-real-partial-slice",
    "v61-real-generation-slice",
    "row-acceptance",
    "generation-execution-admission",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gf fixture candidate must keep real gate blocked: {gate}")

print("v61gf fixture candidate rejection smoke passed")
PY

V61GF_RUN_ID="admission_001" \
V61GF_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh" >/dev/null
