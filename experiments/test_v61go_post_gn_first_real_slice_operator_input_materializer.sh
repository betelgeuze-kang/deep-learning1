#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61go_post_gn_first_real_slice_operator_input_materializer"
RUN_DIR="$RESULTS_DIR/$PREFIX/materialize_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_operator_input_materializer"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61go ready witness dir"
MATERIALIZE_ROOT="${TMPDIR:-/tmp}/v61go materialize ready roots"

V61GO_REUSE_EXISTING="${V61GO_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh" >/dev/null
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
    "v61go_post_gn_first_real_slice_operator_input_materializer_ready": "1",
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "contains_real_external_evidence": "0",
    "minimal_slice_csv_ready": "0",
    "operator_input_root_supplied": "0",
    "operator_input_root_exists": "0",
    "operator_input_root_outside_repo": "0",
    "materialize_admitted": "0",
    "materialize_requested": "0",
    "materialize_executed": "0",
    "materialize_exit_code": "not-run",
    "final_operator_input_files_ready": "0",
    "receiver_preflight_executed": "0",
    "receiver_preflight_exit_code": "not-run",
    "ready_operator_input_rows": "0",
    "operator_input_receipt_ready": "0",
    "operator_input_preflight_ready": "0",
    "assembly_admitted": "0",
    "assembly_executed": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "stage_rows": "8",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "7",
    "source_file_rows": "5",
    "payload_like_package_file_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61go": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61go default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_operator_input_materializer_source_rows.csv",
    "first_real_slice_operator_input_file_rows.csv",
    "first_real_slice_operator_input_stage_rows.csv",
    "first_real_slice_operator_input_command_rows.csv",
    "first_real_slice_operator_input_materializer_package_file_rows.csv",
    "V61GO_POST_GN_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER_BOUNDARY.md",
    "v61go_post_gn_first_real_slice_operator_input_materializer_manifest.json",
    "v61go_post_gn_first_real_slice_operator_input_materializer_summary.csv",
    "v61go_post_gn_first_real_slice_operator_input_materializer_decision.csv",
    "operator_input_materialize_stdout.txt",
    "operator_input_materialize_stderr.txt",
    "v61gj_receiver_preflight_stdout.txt",
    "v61gj_receiver_preflight_stderr.txt",
    "first_real_slice_operator_input_materializer/FIRST_REAL_SLICE_OPERATOR_INPUT_FILE_ROWS.csv",
    "first_real_slice_operator_input_materializer/FIRST_REAL_SLICE_OPERATOR_INPUT_STAGE_ROWS.csv",
    "first_real_slice_operator_input_materializer/FIRST_REAL_SLICE_OPERATOR_INPUT_COMMAND_ROWS.csv",
    "first_real_slice_operator_input_materializer/FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER_MANIFEST.json",
    "first_real_slice_operator_input_materializer/FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.md",
    "first_real_slice_operator_input_materializer/CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py",
    "first_real_slice_operator_input_materializer/VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh",
    "first_real_slice_operator_input_materializer/READY_NOW_COMMANDS.sh",
    "source_v61gn/v61gn_post_gm_first_real_slice_minimal_csv_builder_summary.csv",
    "source_v61gn/v61gn_post_gm_first_real_slice_minimal_csv_builder_decision.csv",
    "source_v61gn/first_real_slice_minimal_csv_status_rows.csv",
    "source_v61gi/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "source_v61gi/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61go artifact: {rel}")
    if rel not in {"operator_input_materialize_stdout.txt", "v61gj_receiver_preflight_stdout.txt"} and path.stat().st_size == 0:
        raise SystemExit(f"empty v61go artifact: {rel}")

for rel in [
    "CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py",
    "VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61go executable bit missing: {rel}")

file_rows = read_csv(run_dir / "first_real_slice_operator_input_file_rows.csv")
if len(file_rows) != 20:
    raise SystemExit(f"v61go default expected 20 final/witness file rows, got {len(file_rows)}")
if any(row.get("exists") != "0" for row in file_rows):
    raise SystemExit("v61go default should not see final operator input files")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("source-v61gn-ready") != "pass" or decisions.get("zero-repo-checkpoint-payload") != "pass":
    raise SystemExit("v61go expected source and zero-payload gates to pass")
for gate in [
    "minimal-csv-ready",
    "materialize-admitted",
    "materialize-executed",
    "operator-input-preflight",
    "assembly-admitted",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61go expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61go default checker must fail without operator input preflight")
if "operator input preflight remains blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61go checker did not explain default block: {checker.stdout} {checker.stderr}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61go sha256 mismatch: {rel}")

print("v61go default no-materialize smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$MATERIALIZE_ROOT"
mkdir -p "$READY_WITNESS_DIR" "$MATERIALIZE_ROOT"

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

V61GO_RUN_ID="materialize_ready" \
V61GO_EXECUTE_MATERIALIZE=1 \
V61GI_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
V61GI_MINIMAL_SLICE_ROWS_CSV="$MATERIALIZE_ROOT/minimal_slice_rows.csv" \
V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 \
V61GI_OPERATOR_INPUT_ROOT="$MATERIALIZE_ROOT/operator_input_root" \
V61GI_OUTPUT_ROOT="$MATERIALIZE_ROOT/output_root" \
V61GI_REVIEWER_ID="reviewer_alpha_001" \
V61GI_ADJUDICATOR_ID="adjudicator_alpha_001" \
V61GI_GENERATION_ID="generation_alpha_001" \
V61GI_CITATION_ID="citation_alpha_001" \
V61GI_CHECKPOINT_ROOT="$MATERIALIZE_ROOT/checkpoint_root" \
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
V61GO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/materialize_ready" "$SUMMARY_CSV" "$DECISION_CSV" "$MATERIALIZE_ROOT/operator_input_root" <<'PY'
import csv
import json
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
operator_root = Path(sys.argv[4])
package_dir = run_dir / "first_real_slice_operator_input_materializer"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "minimal_slice_csv_ready": "1",
    "operator_input_root_supplied": "1",
    "operator_input_root_exists": "1",
    "operator_input_root_outside_repo": "1",
    "materialize_admitted": "1",
    "materialize_requested": "1",
    "materialize_executed": "1",
    "materialize_exit_code": "0",
    "final_operator_input_files_ready": "1",
    "receiver_preflight_executed": "1",
    "receiver_preflight_exit_code": "0",
    "ready_operator_input_rows": "12",
    "operator_input_receipt_ready": "1",
    "operator_input_preflight_ready": "1",
    "assembly_admitted": "0",
    "assembly_executed": "0",
    "contains_real_external_evidence": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61go": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61go materialize-ready {field}: expected {value}, got {summary.get(field)}")

file_rows = read_csv(run_dir / "first_real_slice_operator_input_file_rows.csv")
if len(file_rows) != 20 or any(row.get("exists") != "1" for row in file_rows):
    raise SystemExit("v61go materialize-ready expected all final and witness files")
if not (operator_root / "OPERATOR_INPUT_RECEIPT.json").is_file():
    raise SystemExit("v61go materialize-ready missing operator receipt")

receipt = json.loads((operator_root / "OPERATOR_INPUT_RECEIPT.json").read_text(encoding="utf-8"))
if receipt.get("source_class") != "real-external-review-and-generation-return":
    raise SystemExit(f"v61go materialize-ready unexpected source class: {receipt.get('source_class')}")
if receipt.get("assembly_authority") != "operator-final-real-return":
    raise SystemExit(f"v61go materialize-ready unexpected assembly authority: {receipt.get('assembly_authority')}")
if len(receipt.get("content_witness_files", {})) != 7:
    raise SystemExit("v61go materialize-ready expected seven content witness files")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "minimal-csv-ready",
    "materialize-admitted",
    "materialize-executed",
    "operator-input-preflight",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61go materialize-ready expected pass decision: {gate}")
for gate in ["assembly-admitted", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61go materialize-ready expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode != 0:
    raise SystemExit(f"v61go materialize-ready checker should pass: {checker.stdout} {checker.stderr}")

print("v61go materialize-ready operator input preflight smoke passed")
PY

V61GO_RUN_ID="materialize_001" \
V61GO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
