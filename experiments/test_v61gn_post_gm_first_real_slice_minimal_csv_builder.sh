#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gn_post_gm_first_real_slice_minimal_csv_builder"
RUN_DIR="$RESULTS_DIR/$PREFIX/builder_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_minimal_csv_builder"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61gn ready witness dir"
BUILD_ROOT="${TMPDIR:-/tmp}/v61gn build ready roots"
NOEXEC_ROOT="${TMPDIR:-/tmp}/v61gn noexec ready roots"

V61GN_REUSE_EXISTING="${V61GN_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh" >/dev/null
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
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_ready": "1",
    "v61gm_post_gl_first_real_slice_env_preflight_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "contains_real_external_evidence": "0",
    "env_path_preflight_ready": "0",
    "v61gi_minimal_slice_precheck_ready": "0",
    "build_admitted": "0",
    "build_requested": "0",
    "build_executed": "0",
    "build_exit_code": "not-run",
    "minimal_slice_csv_supplied": "0",
    "minimal_slice_csv_exists": "0",
    "minimal_slice_csv_row_count": "0",
    "minimal_slice_csv_ready": "0",
    "first_real_slice_closure_ready": "0",
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
    "stage_rows": "7",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "6",
    "payload_like_package_file_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gn {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_minimal_csv_builder_source_rows.csv",
    "first_real_slice_minimal_csv_status_rows.csv",
    "first_real_slice_minimal_csv_stage_rows.csv",
    "first_real_slice_minimal_csv_command_rows.csv",
    "first_real_slice_minimal_csv_builder_package_file_rows.csv",
    "V61GN_POST_GM_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER_BOUNDARY.md",
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_manifest.json",
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_summary.csv",
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_decision.csv",
    "minimal_slice_build_stdout.txt",
    "minimal_slice_build_stderr.txt",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_MINIMAL_CSV_STATUS_ROWS.csv",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_MINIMAL_CSV_STAGE_ROWS.csv",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_MINIMAL_CSV_COMMAND_ROWS.csv",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_ENV_PATH_ROWS.csv",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_ENV_VALUE_ROWS.csv",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "first_real_slice_minimal_csv_builder/MINIMAL_SLICE_ROWS.csv.template",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER_MANIFEST.json",
    "first_real_slice_minimal_csv_builder/FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.md",
    "first_real_slice_minimal_csv_builder/CHECK_MINIMAL_CSV_READY.py",
    "first_real_slice_minimal_csv_builder/VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh",
    "first_real_slice_minimal_csv_builder/READY_NOW_COMMANDS.sh",
    "source_v61gm/v61gm_post_gl_first_real_slice_env_preflight_summary.csv",
    "source_v61gi/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61gn artifact: {rel}")
    if rel not in {"minimal_slice_build_stdout.txt"} and path.stat().st_size == 0:
        raise SystemExit(f"empty v61gn artifact: {rel}")

for rel in [
    "CHECK_MINIMAL_CSV_READY.py",
    "VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gn executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("source-v61gm-ready") != "pass" or decisions.get("zero-repo-checkpoint-payload") != "pass":
    raise SystemExit("v61gn expected source and zero-payload gates to pass")
for gate in [
    "env-path-preflight",
    "minimal-csv-build-requested",
    "minimal-csv-build-executed",
    "minimal-csv-ready",
    "first-real-slice-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gn expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_MINIMAL_CSV_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gn default checker must fail without CSV")
if "minimal slice CSV remains blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61gn checker did not explain default block: {checker.stdout} {checker.stderr}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gn sha256 mismatch: {rel}")

print("v61gn default no-build smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$BUILD_ROOT" "$NOEXEC_ROOT"
mkdir -p "$READY_WITNESS_DIR" "$BUILD_ROOT" "$NOEXEC_ROOT"

python3 - "$READY_WITNESS_DIR" <<'PY'
import sys
from pathlib import Path

ready = Path(sys.argv[1])
texts = {
    "review_comment.txt": "External reviewer confirms selected answer support, citation alignment, and policy fitness for this subset.\n",
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

run_builder_env() {
  local run_id="$1"
  local root_dir="$2"
  local execute="$3"
  V61GN_RUN_ID="$run_id" \
  V61GN_EXECUTE_BUILD="$execute" \
  V61GI_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
  V61GI_MINIMAL_SLICE_ROWS_CSV="$root_dir/minimal_slice_rows.csv" \
  V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 \
  V61GI_OPERATOR_INPUT_ROOT="$root_dir/operator_input_root" \
  V61GI_OUTPUT_ROOT="$root_dir/output_root" \
  V61GI_REVIEWER_ID="reviewer_alpha_001" \
  V61GI_ADJUDICATOR_ID="adjudicator_alpha_001" \
  V61GI_GENERATION_ID="generation_alpha_001" \
  V61GI_CITATION_ID="citation_alpha_001" \
  V61GI_CHECKPOINT_ROOT="$root_dir/checkpoint_root" \
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
  V61GN_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh" >/dev/null
}

run_builder_env "build_ready" "$BUILD_ROOT" "1"

python3 - "$RESULTS_DIR/$PREFIX/build_ready" "$SUMMARY_CSV" "$DECISION_CSV" "$BUILD_ROOT/minimal_slice_rows.csv" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
minimal_csv = Path(sys.argv[4])
package_dir = run_dir / "first_real_slice_minimal_csv_builder"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "env_path_preflight_ready": "1",
    "v61gi_minimal_slice_precheck_ready": "1",
    "build_admitted": "1",
    "build_requested": "1",
    "build_executed": "1",
    "build_exit_code": "0",
    "minimal_slice_csv_supplied": "1",
    "minimal_slice_csv_exists": "1",
    "minimal_slice_csv_row_count": "1",
    "minimal_slice_csv_schema_ready": "1",
    "minimal_slice_csv_hash_binding_ready": "1",
    "minimal_slice_csv_witness_path_ready": "1",
    "minimal_slice_csv_nonfinal_free_ready": "1",
    "minimal_slice_csv_numeric_ready": "1",
    "minimal_slice_csv_ready": "1",
    "contains_real_external_evidence": "0",
    "first_real_slice_closure_ready": "0",
    "real_external_review_return_rows": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gn build-ready {field}: expected {value}, got {summary.get(field)}")
if not minimal_csv.is_file() or len(read_csv(minimal_csv)) != 1:
    raise SystemExit("v61gn build-ready expected one generated minimal CSV row")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["env-path-preflight", "minimal-csv-build-requested", "minimal-csv-build-executed", "minimal-csv-ready"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gn build-ready expected pass decision: {gate}")
for gate in ["first-real-slice-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gn build-ready expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_MINIMAL_CSV_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode != 0:
    raise SystemExit(f"v61gn build-ready checker should pass: {checker.stdout} {checker.stderr}")

print("v61gn build-ready minimal CSV smoke passed")
PY

run_builder_env "noexecute_ready" "$NOEXEC_ROOT" "0"

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
    "env_path_preflight_ready": "1",
    "v61gi_minimal_slice_precheck_ready": "1",
    "build_admitted": "1",
    "build_requested": "0",
    "build_executed": "0",
    "minimal_slice_csv_exists": "0",
    "minimal_slice_csv_ready": "0",
    "contains_real_external_evidence": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gn noexecute {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("env-path-preflight") != "pass":
    raise SystemExit("v61gn noexecute should pass env-path preflight")
for gate in ["minimal-csv-build-requested", "minimal-csv-build-executed", "minimal-csv-ready"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gn noexecute expected blocked decision: {gate}")

print("v61gn no-execute ready-state smoke passed")
PY

V61GN_RUN_ID="builder_001" \
V61GN_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh" >/dev/null
