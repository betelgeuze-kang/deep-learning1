#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gj_post_gi_operator_input_receiver"
RUN_DIR="$RESULTS_DIR/$PREFIX/receiver_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIVER_DIR="$RUN_DIR/operator_input_receiver"
TEMPLATE_ROOT="$RESULTS_DIR/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/operator_input_templates"
INVALID_SCHEMA_ROOT="${TMPDIR:-/tmp}/v61gj invalid schema input"
INVALID_CONSISTENCY_ROOT="${TMPDIR:-/tmp}/v61gj invalid consistency input"
INVALID_SELECTED_ROOT="${TMPDIR:-/tmp}/v61gj invalid selected slice input"
INVALID_AUTHORITY_ROOT="${TMPDIR:-/tmp}/v61gj invalid authority input"

V61GJ_REUSE_EXISTING="${V61GJ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

"$RECEIVER_DIR/VERIFY_OPERATOR_INPUT_RECEIVER.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIVER_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
receiver_dir = Path(sys.argv[4])


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
    "v61gj_post_gi_operator_input_receiver_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "operator_input_root_supplied": "0",
    "operator_input_root_exists": "0",
    "operator_input_required_rows": "12",
    "present_operator_input_rows": "0",
    "ready_operator_input_rows": "0",
    "schema_valid_rows": "0",
    "operator_input_schema_ready": "0",
    "minimum_row_count_ready_rows": "0",
    "operator_input_minimum_row_count_ready": "0",
    "hash_binding_ready_rows": "0",
    "operator_input_hash_binding_ready": "0",
    "cross_file_consistency_ready_rows": "0",
    "operator_input_cross_file_consistency_ready": "0",
    "selected_slice_binding_ready_rows": "0",
    "operator_input_selected_slice_binding_ready": "0",
    "authority_statement_required_rows": "2",
    "authority_statement_ready_rows": "0",
    "operator_input_authority_statement_ready": "0",
    "operator_input_preflight_ready": "0",
    "generated_marker_contract_rows": "2",
    "output_root_supplied": "0",
    "output_root_outside_repo": "0",
    "assembly_admitted": "0",
    "assembly_executed": "0",
    "assembled_v53_root_ready": "0",
    "assembled_v61_root_ready": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "partial_real_slice_ready": "0",
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
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "19",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "18",
    "source_file_rows": "7",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "operator_input_receiver_preflight_rows.csv",
    "operator_input_receiver_stage_rows.csv",
    "operator_input_receiver_command_rows.csv",
    "operator_input_receiver_package_file_rows.csv",
    "operator_input_receiver_source_rows.csv",
    "V61GJ_POST_GI_OPERATOR_INPUT_RECEIVER_BOUNDARY.md",
    "v61gj_post_gi_operator_input_receiver_manifest.json",
    "v61gj_post_gi_operator_input_receiver_summary.csv",
    "v61gj_post_gi_operator_input_receiver_decision.csv",
    "operator_input_receiver/OPERATOR_INPUT_RECEIVER_PREFLIGHT_ROWS.csv",
    "operator_input_receiver/OPERATOR_INPUT_RECEIVER_STAGE_ROWS.csv",
    "operator_input_receiver/OPERATOR_INPUT_RECEIVER_COMMAND_ROWS.csv",
    "operator_input_receiver/OPERATOR_INPUT_RECEIVER_MANIFEST.json",
    "operator_input_receiver/VERIFY_OPERATOR_INPUT_RECEIVER.sh",
    "source_v61gi/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gj artifact: {rel}")

if not os.access(receiver_dir / "VERIFY_OPERATOR_INPUT_RECEIVER.sh", os.X_OK):
    raise SystemExit("v61gj verifier must be executable")

preflight_rows = read_csv(run_dir / "operator_input_receiver_preflight_rows.csv")
if len(preflight_rows) != 12:
    raise SystemExit("v61gj expected 12 preflight rows")
if any(row["ready"] != "0" for row in preflight_rows):
    raise SystemExit("v61gj default preflight rows must all be blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gi-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gj expected pass decision: {gate}")
for gate in [
    "operator-input-root-supplied",
    "operator-input-schema",
    "operator-input-minimum-rows",
    "operator-input-hash-binding",
    "operator-input-cross-file-consistency",
    "operator-input-selected-slice-binding",
    "operator-input-authority-statement",
    "operator-input-preflight",
    "assembly-admitted",
    "assembly-executed",
    "row-acceptance",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
    "authority-bound-replay-admission",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj expected blocked decision: {gate}")

command_rows = {row["command_id"]: row for row in read_csv(run_dir / "operator_input_receiver_command_rows.csv")}
if command_rows["01-verify-receiver-package"]["ready_to_run_now"] != "1":
    raise SystemExit("v61gj verifier command must be ready")
if command_rows["02-run-with-operator-input"]["ready_to_run_now"] != "0":
    raise SystemExit("v61gj operator-input command must stay blocked without final input")

boundary = (run_dir / "V61GJ_POST_GI_OPERATOR_INPUT_RECEIVER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gj_post_gi_operator_input_receiver_ready=1",
    "operator_input_root_supplied=0",
    "present_operator_input_rows=0",
    "ready_operator_input_rows=0",
    "operator_input_preflight_ready=0",
    "assembly_admitted=0",
    "assembly_executed=0",
    "assembled_v53_root_ready=0",
    "assembled_v61_root_ready=0",
    "real_external_review_return_rows=0",
    "real_adjudication_rows=0",
    "slice_answer_review_accepted_rows=0",
    "real_generation_result_artifacts=0",
    "accepted_generation_result_artifacts=0",
    "generation_result_accepted_rows=0",
    "row_acceptance_ready=0",
    "dual_external_return_real_ready=0",
    "real_return_replay_admission_ready=0",
    "generation_acceptance_closure_ready=0",
    "authority_bound_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gj boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gj sha256 mismatch: {rel}")

print("v61gj default no-input receiver smoke passed")
PY

V61GJ_RUN_ID="template_reject" \
V61GJ_OPERATOR_INPUT_ROOT="$TEMPLATE_ROOT" \
V61GJ_OUTPUT_ROOT="${TMPDIR:-/tmp}/v61gj_template_reject_output" \
V61GJ_EXECUTE_ASSEMBLY=1 \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "operator_input_root_supplied": "1",
    "operator_input_root_exists": "1",
    "present_operator_input_rows": "0",
    "ready_operator_input_rows": "0",
    "operator_input_preflight_ready": "0",
    "output_root_supplied": "1",
    "output_root_outside_repo": "1",
    "assembly_admitted": "0",
    "assembly_executed": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gj template reject {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("operator-input-root-supplied") != "pass":
    raise SystemExit("v61gj template reject should see supplied root")
for gate in [
    "operator-input-preflight",
    "assembly-admitted",
    "assembly-executed",
    "row-acceptance",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
    "authority-bound-replay-admission",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj template reject must keep gate blocked: {gate}")

command_rows = {row["command_id"]: row for row in read_csv(Path(sys.argv[1]).parent / "v61gj_post_gi_operator_input_receiver" / "template_reject" / "operator_input_receiver_command_rows.csv")}
if command_rows["02-run-with-operator-input"]["ready_to_run_now"] != "0":
    raise SystemExit("v61gj template reject command must stay blocked")

print("v61gj template tree rejection smoke passed")
PY

rm -rf "$INVALID_SCHEMA_ROOT"
python3 - "$RESULTS_DIR/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_required_rows.csv" "$INVALID_SCHEMA_ROOT" <<'PY'
import csv
import sys
from pathlib import Path

required_csv = Path(sys.argv[1])
root = Path(sys.argv[2])

with required_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

for row in rows:
    path = root / row["final_relative_path"]
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == ".json":
        path.write_text("{}\n", encoding="utf-8")
    elif path.suffix == ".txt":
        path.write_text("Final external authority statement for schema rejection dry run.\n", encoding="utf-8")
    else:
        path.write_text("not,the,required,fields\nvalue,value,value,value\n", encoding="utf-8")
PY

V61GJ_RUN_ID="invalid_schema_reject" \
V61GJ_OPERATOR_INPUT_ROOT="$INVALID_SCHEMA_ROOT" \
V61GJ_OUTPUT_ROOT="${TMPDIR:-/tmp}/v61gj invalid schema reject output" \
V61GJ_EXECUTE_ASSEMBLY=1 \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/invalid_schema_reject/operator_input_receiver_preflight_rows.csv" "$RESULTS_DIR/$PREFIX/invalid_schema_reject/operator_input_receiver_command_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
preflight_csv = Path(sys.argv[3])
command_csv = Path(sys.argv[4])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("operator_input_root_supplied") != "1":
    raise SystemExit("v61gj invalid schema should see supplied root")
if summary.get("present_operator_input_rows") != "12":
    raise SystemExit(f"v61gj invalid schema expected all files present, got {summary.get('present_operator_input_rows')}")
if summary.get("operator_input_preflight_ready") != "0":
    raise SystemExit("v61gj invalid schema must not pass preflight")
if summary.get("assembly_admitted") != "0" or summary.get("assembly_executed") != "0":
    raise SystemExit("v61gj invalid schema must not admit or execute assembly")

rows = read_csv(preflight_csv)
schema_blocked = [row for row in rows if row.get("schema_valid") == "0" and row.get("exists") == "1"]
if len(schema_blocked) < 10:
    raise SystemExit(f"v61gj invalid schema expected most supplied files schema-blocked, got {len(schema_blocked)}")
if not any("missing-fields" in row.get("errors", "") or "missing-json-keys" in row.get("errors", "") for row in schema_blocked):
    raise SystemExit("v61gj invalid schema rows should report field/key errors")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("operator-input-root-supplied") != "pass":
    raise SystemExit("v61gj invalid schema should pass supplied-root gate")
for gate in ["operator-input-preflight", "assembly-admitted", "assembly-executed"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj invalid schema must keep gate blocked: {gate}")

command_rows = {row["command_id"]: row for row in read_csv(command_csv)}
operator_command = command_rows["02-run-with-operator-input"]["command"]
if "v61gj invalid schema input" in operator_command and "'" not in operator_command:
    raise SystemExit("v61gj invalid schema command should quote paths with spaces")
if command_rows["02-run-with-operator-input"]["ready_to_run_now"] != "0":
    raise SystemExit("v61gj invalid schema command must stay blocked")

print("v61gj invalid final schema rejection smoke passed")
PY

rm -rf "$INVALID_CONSISTENCY_ROOT"
python3 - "$INVALID_CONSISTENCY_ROOT" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
valid_sha = "sha256:" + ("a" * 64)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(rel, fieldnames, rows):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path


human = write_csv(
    "v53/aggregate_review_return/human_review_rows.csv",
    ["review_answer_packet_id", "answer_id", "system_id", "query_id", "reviewer_id", "review_decision", "source_support_verified", "citation_verified", "policy_verified", "review_comment_sha256"],
    [{"review_answer_packet_id": "packet-1", "answer_id": "answer-1", "system_id": "system-1", "query_id": "query-1", "reviewer_id": "reviewer-1", "review_decision": "accept", "source_support_verified": "1", "citation_verified": "1", "policy_verified": "1", "review_comment_sha256": valid_sha}],
)
adjudication = write_csv(
    "v53/aggregate_review_return/adjudication_rows.csv",
    ["adjudication_id", "review_answer_packet_id", "answer_id", "adjudicator_id", "adjudication_decision", "adjudication_reason_sha256"],
    [{"adjudication_id": "adj-1", "review_answer_packet_id": "packet-1", "answer_id": "answer-missing", "adjudicator_id": "adjudicator-1", "adjudication_decision": "accept", "adjudication_reason_sha256": valid_sha}],
)
identity = write_csv(
    "v53/aggregate_review_return/reviewer_identity_rows.csv",
    ["assignment_id", "reviewer_id", "reviewer_slot_id", "system_id", "review_scope", "independence_declared", "credential_statement_sha256"],
    [{"assignment_id": "assignment-1", "reviewer_id": "reviewer-1", "reviewer_slot_id": "slot-1", "system_id": "system-1", "review_scope": "complete-source", "independence_declared": "1", "credential_statement_sha256": valid_sha}],
)
conflict = write_csv(
    "v53/aggregate_review_return/reviewer_conflict_rows.csv",
    ["assignment_id", "reviewer_id", "owner_repo", "conflict_declared", "conflict_statement_sha256"],
    [{"assignment_id": "assignment-1", "reviewer_id": "reviewer-1", "owner_repo": "owner/repo", "conflict_declared": "0", "conflict_statement_sha256": valid_sha}],
)
v53_summary = {
    "review_protocol_version": "v61gd-partial-v53-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_human_review_rows": 1,
    "human_review_rows_sha256": sha256(human),
    "accepted_adjudication_rows": 1,
    "adjudication_rows_sha256": sha256(adjudication),
    "accepted_reviewer_identity_rows": 1,
    "reviewer_identity_rows_sha256": sha256(identity),
    "accepted_conflict_disclosure_rows": 1,
    "reviewer_conflict_rows_sha256": sha256(conflict),
}
(root / "v53/aggregate_review_return/acceptance_summary.json").write_text(json.dumps(v53_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(root / "v53/operator_attestation").mkdir(parents=True, exist_ok=True)
(root / "v53/operator_attestation/reviewer_authority_statement.txt").write_text("External reviewer authority statement for partial return.\n", encoding="utf-8")

answer = write_csv(
    "v61/generation_result_return/real_model_generation_answer_rows.csv",
    ["generation_id", "review_query_packet_id", "query_id", "source_span_id", "model_id", "checkpoint_root", "answer_text_sha256", "generation_status", "abstain_decision", "fallback_used", "latency_row_id", "run_transcript_sha256"],
    [{"generation_id": "gen-1", "review_query_packet_id": "review-query-packet-1", "query_id": "query-1", "source_span_id": "span-1", "model_id": "mistralai/Mixtral-8x22B-v0.1", "checkpoint_root": "/external/checkpoint", "answer_text_sha256": valid_sha, "generation_status": "generated", "abstain_decision": "0", "fallback_used": "0", "latency_row_id": "latency-1", "run_transcript_sha256": valid_sha}],
)
citation = write_csv(
    "v61/generation_result_return/real_model_generation_citation_rows.csv",
    ["generation_id", "query_id", "citation_id", "source_span_id", "source_file_sha256", "citation_verified"],
    [{"generation_id": "gen-missing", "query_id": "query-1", "citation_id": "citation-1", "source_span_id": "span-1", "source_file_sha256": valid_sha, "citation_verified": "1"}],
)
abstain = write_csv(
    "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv",
    ["generation_id", "query_id", "expected_behavior", "abstain_expected", "abstain_observed", "fallback_used", "fallback_reason"],
    [{"generation_id": "gen-1", "query_id": "query-1", "expected_behavior": "source-bound-answer", "abstain_expected": "0", "abstain_observed": "0", "fallback_used": "0", "fallback_reason": ""}],
)
latency = write_csv(
    "v61/generation_result_return/real_model_generation_latency_rows.csv",
    ["generation_id", "query_id", "prompt_tokens", "output_tokens", "prefill_ms", "decode_ms", "total_ms", "tokens_per_second"],
    [{"generation_id": "gen-1", "query_id": "query-1", "prompt_tokens": "128", "output_tokens": "32", "prefill_ms": "10.0", "decode_ms": "20.0", "total_ms": "30.0", "tokens_per_second": "100.0"}],
)
v61_summary = {
    "generation_protocol_version": "v61ge-partial-generation-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_answer_rows": 1,
    "answer_rows_sha256": sha256(answer),
    "accepted_citation_rows": 1,
    "citation_rows_sha256": sha256(citation),
    "accepted_abstain_fallback_rows": 1,
    "abstain_fallback_rows_sha256": sha256(abstain),
    "accepted_latency_rows": 1,
    "latency_rows_sha256": sha256(latency),
}
(root / "v61/generation_result_return/real_model_generation_acceptance_summary.json").write_text(json.dumps(v61_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(root / "v61/review_return_provenance/operator_attestation").mkdir(parents=True, exist_ok=True)
(root / "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt").write_text("External generation operator authority statement for partial return.\n", encoding="utf-8")
PY

V61GJ_RUN_ID="invalid_consistency_reject" \
V61GJ_OPERATOR_INPUT_ROOT="$INVALID_CONSISTENCY_ROOT" \
V61GJ_OUTPUT_ROOT="${TMPDIR:-/tmp}/v61gj invalid consistency reject output" \
V61GJ_EXECUTE_ASSEMBLY=1 \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/invalid_consistency_reject/operator_input_receiver_preflight_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
preflight_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("operator_input_root_supplied") != "1":
    raise SystemExit("v61gj invalid consistency should see supplied root")
if summary.get("present_operator_input_rows") != "12":
    raise SystemExit("v61gj invalid consistency expected all files present")
if summary.get("operator_input_preflight_ready") != "0":
    raise SystemExit("v61gj invalid consistency must not pass preflight")
if summary.get("operator_input_cross_file_consistency_ready") != "0":
    raise SystemExit("v61gj invalid consistency must not pass cross-file consistency")
if summary.get("assembly_admitted") != "0" or summary.get("assembly_executed") != "0":
    raise SystemExit("v61gj invalid consistency must not admit or execute assembly")

rows = read_csv(preflight_csv)
if any(row.get("schema_valid") != "1" or row.get("hash_binding_ready") != "1" for row in rows):
    raise SystemExit("v61gj invalid consistency fixture should pass schema/hash checks")
consistency_blocked = [row for row in rows if row.get("cross_file_consistency_ready") == "0" and row.get("exists") == "1"]
if len(consistency_blocked) < 2:
    raise SystemExit(f"v61gj invalid consistency expected cross-file blocked rows, got {len(consistency_blocked)}")
if not any("cross-file:" in row.get("errors", "") for row in consistency_blocked):
    raise SystemExit("v61gj invalid consistency rows should report cross-file errors")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["operator-input-preflight", "assembly-admitted", "assembly-executed"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj invalid consistency must keep gate blocked: {gate}")

print("v61gj invalid cross-file consistency rejection smoke passed")
PY

rm -rf "$INVALID_SELECTED_ROOT"
python3 - "$INVALID_CONSISTENCY_ROOT" "$INVALID_SELECTED_ROOT" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
shutil.copytree(source, target)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def rewrite_csv(path, update):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []
    for row in rows:
        update(row)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


adjudication = target / "v53/aggregate_review_return/adjudication_rows.csv"
rewrite_csv(adjudication, lambda row: row.update({"answer_id": "answer-1"}))
v53_summary_path = target / "v53/aggregate_review_return/acceptance_summary.json"
v53_summary = json.loads(v53_summary_path.read_text(encoding="utf-8"))
v53_summary["adjudication_rows_sha256"] = sha256(adjudication)
v53_summary_path.write_text(json.dumps(v53_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

citation = target / "v61/generation_result_return/real_model_generation_citation_rows.csv"
rewrite_csv(citation, lambda row: row.update({"generation_id": "gen-1"}))
v61_summary_path = target / "v61/generation_result_return/real_model_generation_acceptance_summary.json"
v61_summary = json.loads(v61_summary_path.read_text(encoding="utf-8"))
v61_summary["citation_rows_sha256"] = sha256(citation)
v61_summary_path.write_text(json.dumps(v61_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GJ_RUN_ID="invalid_selected_slice_reject" \
V61GJ_OPERATOR_INPUT_ROOT="$INVALID_SELECTED_ROOT" \
V61GJ_OUTPUT_ROOT="${TMPDIR:-/tmp}/v61gj invalid selected slice reject output" \
V61GJ_EXECUTE_ASSEMBLY=1 \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/invalid_selected_slice_reject/operator_input_receiver_preflight_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
preflight_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("present_operator_input_rows") != "12":
    raise SystemExit("v61gj invalid selected-slice expected all files present")
if summary.get("operator_input_cross_file_consistency_ready") != "1":
    raise SystemExit("v61gj invalid selected-slice fixture should pass cross-file consistency")
if summary.get("operator_input_selected_slice_binding_ready") != "0":
    raise SystemExit("v61gj invalid selected-slice must not pass selected-slice binding")
if summary.get("operator_input_preflight_ready") != "0":
    raise SystemExit("v61gj invalid selected-slice must not pass preflight")
if summary.get("assembly_admitted") != "0" or summary.get("assembly_executed") != "0":
    raise SystemExit("v61gj invalid selected-slice must not admit or execute assembly")

rows = read_csv(preflight_csv)
if any(row.get("schema_valid") != "1" or row.get("hash_binding_ready") != "1" or row.get("cross_file_consistency_ready") != "1" for row in rows):
    raise SystemExit("v61gj invalid selected-slice fixture should pass schema/hash/cross-file checks")
selected_blocked = [row for row in rows if row.get("selected_slice_binding_ready") == "0" and row.get("exists") == "1"]
if len(selected_blocked) < 2:
    raise SystemExit(f"v61gj invalid selected-slice expected selected-slice blocked rows, got {len(selected_blocked)}")
if not any("selected-slice:" in row.get("errors", "") for row in selected_blocked):
    raise SystemExit("v61gj invalid selected-slice rows should report selected-slice errors")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["operator-input-preflight", "assembly-admitted", "assembly-executed"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj invalid selected-slice must keep gate blocked: {gate}")

print("v61gj invalid selected-slice binding rejection smoke passed")
PY

rm -rf "$INVALID_AUTHORITY_ROOT"
python3 - "$RESULTS_DIR/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_selected_slice_rows.csv" "$INVALID_SELECTED_ROOT" "$INVALID_AUTHORITY_ROOT" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

selected_csv = Path(sys.argv[1])
source = Path(sys.argv[2])
target = Path(sys.argv[3])
shutil.copytree(source, target)

with selected_csv.open(newline="", encoding="utf-8") as handle:
    selected = {row["slice_id"]: row for row in csv.DictReader(handle)}
v53 = selected["v53-partial-review-slice"]
v61 = selected["v61-partial-generation-slice"]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def rewrite_csv(path, update):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []
    for row in rows:
        update(row)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


human = target / "v53/aggregate_review_return/human_review_rows.csv"
rewrite_csv(human, lambda row: row.update({
    "review_answer_packet_id": v53["review_answer_packet_id"],
    "answer_id": v53["answer_id"],
    "system_id": v53["system_id"],
    "query_id": v53["query_id"],
    "reviewer_id": "reviewer-valid-slice",
}))
adjudication = target / "v53/aggregate_review_return/adjudication_rows.csv"
rewrite_csv(adjudication, lambda row: row.update({
    "review_answer_packet_id": v53["review_answer_packet_id"],
    "answer_id": v53["answer_id"],
}))
identity = target / "v53/aggregate_review_return/reviewer_identity_rows.csv"
rewrite_csv(identity, lambda row: row.update({
    "assignment_id": v53["assignment_id"],
    "reviewer_id": "reviewer-valid-slice",
    "reviewer_slot_id": v53["reviewer_slot_id"],
    "system_id": v53["system_id"],
}))
conflict = target / "v53/aggregate_review_return/reviewer_conflict_rows.csv"
rewrite_csv(conflict, lambda row: row.update({
    "assignment_id": v53["assignment_id"],
    "reviewer_id": "reviewer-valid-slice",
    "owner_repo": v53["owner_repo"],
}))
v53_summary_path = target / "v53/aggregate_review_return/acceptance_summary.json"
v53_summary = json.loads(v53_summary_path.read_text(encoding="utf-8"))
v53_summary.update({
    "human_review_rows_sha256": sha256(human),
    "adjudication_rows_sha256": sha256(adjudication),
    "reviewer_identity_rows_sha256": sha256(identity),
    "reviewer_conflict_rows_sha256": sha256(conflict),
})
v53_summary_path.write_text(json.dumps(v53_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

answer = target / "v61/generation_result_return/real_model_generation_answer_rows.csv"
rewrite_csv(answer, lambda row: row.update({
    "generation_id": "gen-valid-slice",
    "query_id": v61["query_id"],
    "source_span_id": v61["source_span_id"],
}))
citation = target / "v61/generation_result_return/real_model_generation_citation_rows.csv"
rewrite_csv(citation, lambda row: row.update({
    "generation_id": "gen-valid-slice",
    "query_id": v61["query_id"],
    "source_span_id": v61["source_span_id"],
}))
abstain = target / "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv"
rewrite_csv(abstain, lambda row: row.update({
    "generation_id": "gen-valid-slice",
    "query_id": v61["query_id"],
}))
latency = target / "v61/generation_result_return/real_model_generation_latency_rows.csv"
rewrite_csv(latency, lambda row: row.update({
    "generation_id": "gen-valid-slice",
    "query_id": v61["query_id"],
}))
v61_summary_path = target / "v61/generation_result_return/real_model_generation_acceptance_summary.json"
v61_summary = json.loads(v61_summary_path.read_text(encoding="utf-8"))
v61_summary.update({
    "answer_rows_sha256": sha256(answer),
    "citation_rows_sha256": sha256(citation),
    "abstain_fallback_rows_sha256": sha256(abstain),
    "latency_rows_sha256": sha256(latency),
})
v61_summary_path.write_text(json.dumps(v61_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(target / "v53/operator_attestation/reviewer_authority_statement.txt").write_text("ok\n", encoding="utf-8")
(target / "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt").write_text("ok\n", encoding="utf-8")
PY

V61GJ_RUN_ID="invalid_authority_statement_reject" \
V61GJ_OPERATOR_INPUT_ROOT="$INVALID_AUTHORITY_ROOT" \
V61GJ_OUTPUT_ROOT="${TMPDIR:-/tmp}/v61gj invalid authority reject output" \
V61GJ_EXECUTE_ASSEMBLY=0 \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/invalid_authority_statement_reject/operator_input_receiver_preflight_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
preflight_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("present_operator_input_rows") != "12":
    raise SystemExit("v61gj invalid authority expected all files present")
if summary.get("operator_input_cross_file_consistency_ready") != "1":
    raise SystemExit("v61gj invalid authority should pass cross-file consistency")
if summary.get("operator_input_selected_slice_binding_ready") != "1":
    raise SystemExit("v61gj invalid authority should pass selected-slice binding")
if summary.get("operator_input_authority_statement_ready") != "0":
    raise SystemExit("v61gj invalid authority must not pass authority statement preflight")
if summary.get("operator_input_preflight_ready") != "0":
    raise SystemExit("v61gj invalid authority must not pass preflight")
if summary.get("assembly_admitted") != "0" or summary.get("assembly_executed") != "0":
    raise SystemExit("v61gj invalid authority must not admit or execute assembly")

rows = read_csv(preflight_csv)
if any(row.get("schema_valid") != "1" or row.get("hash_binding_ready") != "1" or row.get("cross_file_consistency_ready") != "1" or row.get("selected_slice_binding_ready") != "1" for row in rows):
    raise SystemExit("v61gj invalid authority fixture should pass schema/hash/cross-file/selected-slice checks")
authority_blocked = [row for row in rows if row.get("authority_bound") == "1" and row.get("authority_statement_ready") == "0"]
if len(authority_blocked) != 2:
    raise SystemExit(f"v61gj invalid authority expected two authority rows blocked, got {len(authority_blocked)}")
if not all("authority-statement-too-short" in row.get("errors", "") for row in authority_blocked):
    raise SystemExit("v61gj invalid authority rows should report too-short authority statement")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["operator-input-preflight", "assembly-admitted", "assembly-executed"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj invalid authority must keep gate blocked: {gate}")

print("v61gj invalid authority statement rejection smoke passed")
PY

V61GJ_RUN_ID="receiver_001" \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null
