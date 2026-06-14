#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gq_post_gp_first_real_slice_end_to_end_guarded_chain"
RUN_DIR="$RESULTS_DIR/$PREFIX/chain_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_end_to_end_guarded_chain"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61gq ready witness dir"
CANDIDATE_ROOT="${TMPDIR:-/tmp}/v61gq candidate noack roots"

V61GO_RUN_ID="materialize_001" V61GO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
V61GJ_RUN_ID="receiver_001" V61GJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null
V61GP_RUN_ID="replay_001" V61GP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
V61GQ_REUSE_EXISTING="${V61GQ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh" >/dev/null
"$PACKAGE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import os
import subprocess
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
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_ready": "1",
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": "1",
    "contains_real_external_evidence": "0",
    "execute_chain_requested": "0",
    "materialize_step_executed": "0",
    "materialize_step_exit_code": "not-run",
    "replay_step_executed": "0",
    "replay_step_exit_code": "not-run",
    "content_witness_dir_supplied": "0",
    "content_witness_dir_exists": "0",
    "content_witness_dir_outside_repo": "0",
    "minimal_slice_csv_supplied": "0",
    "minimal_slice_csv_outside_repo": "0",
    "operator_input_root_supplied": "0",
    "operator_input_root_exists": "0",
    "operator_input_root_outside_repo": "0",
    "output_root_supplied": "0",
    "output_root_outside_repo": "0",
    "external_real_ack_ready": "0",
    "v61go_minimal_slice_csv_ready": "0",
    "v61go_materialize_executed": "0",
    "v61go_operator_input_preflight_ready": "0",
    "v61gp_operator_input_preflight_ready": "0",
    "v61gp_replay_admitted": "0",
    "v61gp_replay_requested": "0",
    "v61gp_replay_executed": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_result_row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "target_rows": "12",
    "ready_target_rows": "0",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "stage_rows": "10",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "9",
    "source_file_rows": "6",
    "payload_like_package_file_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gq default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_end_to_end_chain_source_rows.csv",
    "first_real_slice_end_to_end_chain_root_rows.csv",
    "first_real_slice_end_to_end_chain_target_rows.csv",
    "first_real_slice_end_to_end_chain_stage_rows.csv",
    "first_real_slice_end_to_end_chain_command_rows.csv",
    "first_real_slice_end_to_end_chain_package_file_rows.csv",
    "V61GQ_POST_GP_FIRST_REAL_SLICE_END_TO_END_GUARDED_CHAIN_BOUNDARY.md",
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_manifest.json",
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_summary.csv",
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_decision.csv",
    "01_v61go_materialize_stdout.txt",
    "01_v61go_materialize_stderr.txt",
    "02_v61gp_replay_stdout.txt",
    "02_v61gp_replay_stderr.txt",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN_ROOT_ROWS.csv",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN_TARGET_ROWS.csv",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN_STAGE_ROWS.csv",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN_COMMAND_ROWS.csv",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN_MANIFEST.json",
    "first_real_slice_end_to_end_guarded_chain/FIRST_REAL_SLICE_END_TO_END_CHAIN.md",
    "first_real_slice_end_to_end_guarded_chain/CHECK_END_TO_END_CHAIN_OPENED.py",
    "first_real_slice_end_to_end_guarded_chain/VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh",
    "first_real_slice_end_to_end_guarded_chain/READY_NOW_COMMANDS.sh",
    "source_v61gp_initial/v61gp_post_go_first_real_slice_dual_replay_executor_summary.csv",
    "source_v61gp_initial/v61gp_post_go_first_real_slice_dual_replay_executor_decision.csv",
    "source_v61go_final/v61go_post_gn_first_real_slice_operator_input_materializer_summary.csv",
    "source_v61go_final/v61go_post_gn_first_real_slice_operator_input_materializer_decision.csv",
    "source_v61gp_final/v61gp_post_go_first_real_slice_dual_replay_executor_summary.csv",
    "source_v61gp_final/v61gp_post_go_first_real_slice_dual_replay_executor_decision.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61gq artifact: {rel}")
    if rel not in {"01_v61go_materialize_stdout.txt", "02_v61gp_replay_stdout.txt"} and path.stat().st_size == 0:
        raise SystemExit(f"empty v61gq artifact: {rel}")

for rel in [
    "CHECK_END_TO_END_CHAIN_OPENED.py",
    "VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gq executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gp-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gq default expected pass decision: {gate}")
for gate in [
    "execute-chain-requested",
    "content-witness-dir",
    "operator-input-root",
    "output-root",
    "external-real-ack",
    "materialize-step",
    "replay-step",
    "row-acceptance",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gq default expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_END_TO_END_CHAIN_OPENED.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gq default checker must fail without real chain")
if "end-to-end chain remains blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61gq checker did not explain default block: {checker.stdout} {checker.stderr}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gq sha256 mismatch: {rel}")

print("v61gq default no-chain smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$CANDIDATE_ROOT"
mkdir -p "$READY_WITNESS_DIR" "$CANDIDATE_ROOT"

python3 - "$READY_WITNESS_DIR" <<'PY'
import sys
from pathlib import Path

ready = Path(sys.argv[1])
texts = {
    "review_comment.txt": "External reviewer confirms selected answer support, citation alignment, and policy fitness for this bounded subset.\n",
    "adjudication_reason.txt": "Independent adjudicator accepts the selected p0 answer after comparing review notes and source evidence.\n",
    "credential_statement.txt": "Reviewer identity and credentials are declared for this bounded subset review with accountable scope.\n",
    "conflict_statement.txt": "Reviewer declares no blocking conflict for the selected repository, answer, source, and evaluation scope.\n",
    "answer_text.txt": "The generated answer is recorded as final operator output for the selected source-bound query.\n",
    "run_transcript.txt": "Operator transcript records checkpoint path, prompt, output, citation check, and latency observation.\n",
    "source_file.txt": "Cited source material for the selected span is recorded and bound to the returned citation row.\n",
}
for name, text in texts.items():
    (ready / name).write_text(text, encoding="utf-8")
PY

V61GQ_RUN_ID="candidate_noack" \
V61GQ_EXECUTE_CHAIN=1 \
V61GI_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
V61GI_MINIMAL_SLICE_ROWS_CSV="$CANDIDATE_ROOT/minimal_slice_rows.csv" \
V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 \
V61GI_OPERATOR_INPUT_ROOT="$CANDIDATE_ROOT/operator_input_root" \
V61GI_OUTPUT_ROOT="$CANDIDATE_ROOT/output_root" \
V61GI_REVIEWER_ID="reviewer_alpha_001" \
V61GI_ADJUDICATOR_ID="adjudicator_alpha_001" \
V61GI_GENERATION_ID="generation_alpha_001" \
V61GI_CITATION_ID="citation_alpha_001" \
V61GI_CHECKPOINT_ROOT="$CANDIDATE_ROOT/checkpoint_root" \
V61GI_LATENCY_ROW_ID="latency_alpha_001" \
V61GI_PROMPT_TOKENS="128" \
V61GI_OUTPUT_TOKENS="32" \
V61GI_PREFILL_MS="11.5" \
V61GI_DECODE_MS="22.5" \
V61GI_TOTAL_MS="34.0" \
V61GI_TOKENS_PER_SECOND="940.0" \
V61GI_V53_AUTHORITY_STATEMENT="Final external reviewer authority statement for the bounded first return slice with accountable identity." \
V61GI_V61_AUTHORITY_STATEMENT="Final external generation authority statement for the bounded first return slice with checkpoint accountability." \
V61GI_EXTERNAL_RETURN_ATTESTATION="Final external return attestation binds review and generation artifacts to immutable hashes." \
V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT="Final external operator authority for first slice assembly with independent accountability." \
V61GQ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/candidate_noack" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = run_dir / "first_real_slice_end_to_end_guarded_chain"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "execute_chain_requested": "1",
    "materialize_step_executed": "1",
    "materialize_step_exit_code": "0",
    "replay_step_executed": "1",
    "replay_step_exit_code": "0",
    "content_witness_dir_supplied": "1",
    "content_witness_dir_exists": "1",
    "content_witness_dir_outside_repo": "1",
    "minimal_slice_csv_supplied": "1",
    "minimal_slice_csv_outside_repo": "1",
    "operator_input_root_supplied": "1",
    "operator_input_root_exists": "1",
    "operator_input_root_outside_repo": "1",
    "output_root_supplied": "1",
    "output_root_outside_repo": "1",
    "external_real_ack_ready": "0",
    "v61go_minimal_slice_csv_ready": "1",
    "v61go_materialize_executed": "1",
    "v61go_operator_input_preflight_ready": "1",
    "v61gp_operator_input_preflight_ready": "1",
    "v61gp_replay_admitted": "0",
    "v61gp_replay_requested": "1",
    "v61gp_replay_executed": "0",
    "contains_real_external_evidence": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_target_rows": "0",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "ready_stage_rows": "6",
    "blocked_stage_rows": "4",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gq candidate-noack {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "execute-chain-requested",
    "content-witness-dir",
    "operator-input-root",
    "output-root",
    "materialize-step",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gq candidate-noack expected pass decision: {gate}")
for gate in [
    "external-real-ack",
    "replay-step",
    "row-acceptance",
    "dual-external-return-real",
    "real-return-replay-admission",
    "generation-acceptance-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gq candidate-noack expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_END_TO_END_CHAIN_OPENED.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gq candidate-noack checker must fail without real acknowledgement")

print("v61gq candidate no-ack end-to-end chain block smoke passed")
PY

V61GO_RUN_ID="materialize_001" V61GO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
V61GJ_RUN_ID="receiver_001" V61GJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null
V61GP_RUN_ID="replay_001" V61GP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
V61GQ_RUN_ID="chain_001" V61GQ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh" >/dev/null
