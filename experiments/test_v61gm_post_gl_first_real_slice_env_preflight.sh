#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gm_post_gl_first_real_slice_env_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_preflight"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61gm ready witness dir"
ENV_READY_ROOT="${TMPDIR:-/tmp}/v61gm env ready roots"
NONFINAL_ROOT="${TMPDIR:-/tmp}/v61gm nonfinal env roots"

V61GM_REUSE_EXISTING="${V61GM_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gm_post_gl_first_real_slice_env_preflight.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh" >/dev/null
"$PACKAGE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import json
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
    "v61gm_post_gl_first_real_slice_env_preflight_ready": "1",
    "v61gl_post_gk_first_real_slice_witness_preflight_ready": "1",
    "v61gk_post_gj_first_real_slice_closure_packet_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "contains_real_external_evidence": "0",
    "content_witness_preflight_ready": "0",
    "path_rows": "4",
    "ready_path_rows": "0",
    "value_env_rows": "16",
    "ready_value_env_rows": "0",
    "env_path_preflight_ready": "0",
    "v61gi_minimal_slice_precheck_ready": "0",
    "v61gi_minimal_slice_precheck_exit_code": "not-run",
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
    "checkpoint_payload_bytes_downloaded_by_v61gm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gm {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_env_preflight_source_rows.csv",
    "first_real_slice_env_path_rows.csv",
    "first_real_slice_env_value_rows.csv",
    "first_real_slice_env_stage_rows.csv",
    "first_real_slice_env_command_rows.csv",
    "first_real_slice_env_preflight_package_file_rows.csv",
    "V61GM_POST_GL_FIRST_REAL_SLICE_ENV_PREFLIGHT_BOUNDARY.md",
    "v61gm_post_gl_first_real_slice_env_preflight_manifest.json",
    "v61gm_post_gl_first_real_slice_env_preflight_summary.csv",
    "v61gm_post_gl_first_real_slice_env_preflight_decision.csv",
    "v61gi_minimal_slice_precheck_stdout.csv",
    "v61gi_minimal_slice_precheck_stderr.txt",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_PATH_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_VALUE_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_STAGE_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_COMMAND_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_WITNESS_PREFLIGHT_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_PREFLIGHT_MANIFEST.json",
    "first_real_slice_env_preflight/FIRST_REAL_SLICE_ENV_PREFLIGHT.md",
    "first_real_slice_env_preflight/CHECK_ENV_PREFLIGHT_READY.py",
    "first_real_slice_env_preflight/RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh",
    "first_real_slice_env_preflight/VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh",
    "first_real_slice_env_preflight/READY_NOW_COMMANDS.sh",
    "source_v61gl/v61gl_post_gk_first_real_slice_witness_preflight_summary.csv",
    "source_v61gk/v61gk_post_gj_first_real_slice_closure_packet_summary.csv",
    "source_v61gi/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61gm artifact: {rel}")
    if rel != "v61gi_minimal_slice_precheck_stdout.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61gm artifact: {rel}")

for rel in [
    "CHECK_ENV_PREFLIGHT_READY.py",
    "RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh",
    "VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gm executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("source-v61gl-ready") != "pass" or decisions.get("zero-repo-checkpoint-payload") != "pass":
    raise SystemExit("v61gm expected source and zero-payload gates to pass")
for gate in [
    "content-witness-preflight",
    "final-paths",
    "final-env-values",
    "v61gi-minimal-slice-precheck",
    "first-real-slice-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gm expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_ENV_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gm default checker must fail without env")
if "first real slice env preflight remains blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61gm checker did not explain default block: {checker.stdout} {checker.stderr}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gm sha256 mismatch: {rel}")

print("v61gm default no-env preflight smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$ENV_READY_ROOT" "$NONFINAL_ROOT"
mkdir -p "$READY_WITNESS_DIR" "$ENV_READY_ROOT" "$NONFINAL_ROOT"

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

run_env_ready() {
  local run_id="$1"
  local root_dir="$2"
  local reviewer_id="$3"
  V61GM_RUN_ID="$run_id" \
  V61GI_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
  V61GI_MINIMAL_SLICE_ROWS_CSV="$root_dir/minimal slice rows.csv" \
  V61GI_OPERATOR_INPUT_ROOT="$root_dir/operator input root" \
  V61GI_OUTPUT_ROOT="$root_dir/output root" \
  V61GI_REVIEWER_ID="$reviewer_id" \
  V61GI_ADJUDICATOR_ID="adjudicator_alpha_001" \
  V61GI_GENERATION_ID="generation_alpha_001" \
  V61GI_CITATION_ID="citation_alpha_001" \
  V61GI_CHECKPOINT_ROOT="$root_dir/checkpoint root" \
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
  V61GM_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61gm_post_gl_first_real_slice_env_preflight.sh" >/dev/null
}

run_env_ready "env_ready" "$ENV_READY_ROOT" "reviewer_alpha_001"

python3 - "$RESULTS_DIR/$PREFIX/env_ready" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = run_dir / "first_real_slice_env_preflight"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "content_witness_preflight_ready": "1",
    "path_rows": "4",
    "ready_path_rows": "4",
    "value_env_rows": "16",
    "ready_value_env_rows": "16",
    "env_path_preflight_ready": "1",
    "v61gi_minimal_slice_precheck_ready": "1",
    "v61gi_minimal_slice_precheck_exit_code": "0",
    "contains_real_external_evidence": "0",
    "first_real_slice_closure_ready": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "generation_result_accepted_rows": "0",
    "real_return_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_command_rows": "3",
    "ready_stage_rows": "5",
    "blocked_stage_rows": "2",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gm env-ready {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["content-witness-preflight", "final-paths", "final-env-values", "v61gi-minimal-slice-precheck"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gm env-ready expected pass decision: {gate}")
for gate in ["first-real-slice-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gm env-ready expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_ENV_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode != 0:
    raise SystemExit(f"v61gm env-ready checker should pass: {checker.stdout} {checker.stderr}")

print("v61gm env-ready preflight smoke passed")
PY

run_env_ready "nonfinal_env_reject" "$NONFINAL_ROOT" "REPLACE_WITH_EXTERNAL_REVIEWER_ID"

python3 - "$RESULTS_DIR/$PREFIX/nonfinal_env_reject" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
    "content_witness_preflight_ready": "1",
    "ready_path_rows": "4",
    "value_env_rows": "16",
    "ready_value_env_rows": "15",
    "env_path_preflight_ready": "0",
    "v61gi_minimal_slice_precheck_ready": "0",
    "v61gi_minimal_slice_precheck_exit_code": "not-run",
    "contains_real_external_evidence": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gm nonfinal {field}: expected {value}, got {summary.get(field)}")

value_rows = read_csv(run_dir / "first_real_slice_env_value_rows.csv")
reviewer = next(row for row in value_rows if row["env_var"] == "V61GI_REVIEWER_ID")
if "nonfinal-env:V61GI_REVIEWER_ID" not in reviewer.get("errors", ""):
    raise SystemExit(f"v61gm nonfinal env should explain rejected env: {reviewer}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("final-env-values") != "blocked" or decisions.get("v61gi-minimal-slice-precheck") != "blocked":
    raise SystemExit("v61gm nonfinal env must block env/precheck gates")

print("v61gm nonfinal env rejection smoke passed")
PY

V61GM_RUN_ID="preflight_001" \
V61GM_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gm_post_gl_first_real_slice_env_preflight.sh" >/dev/null
