#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gl_post_gk_first_real_slice_witness_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_witness_preflight"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61gl ready witness dir"
NONFINAL_WITNESS_DIR="${TMPDIR:-/tmp}/v61gl nonfinal witness dir"

V61GL_REUSE_EXISTING="${V61GL_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh" >/dev/null
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
    "v61gl_post_gk_first_real_slice_witness_preflight_ready": "1",
    "v61gk_post_gj_first_real_slice_closure_packet_ready": "1",
    "contains_real_external_evidence": "0",
    "witness_dir_supplied": "0",
    "witness_dir_exists": "0",
    "witness_dir_outside_repo": "0",
    "content_witness_rows": "7",
    "ready_content_witness_rows": "0",
    "missing_content_witness_rows": "0",
    "nonfinal_content_witness_rows": "0",
    "content_witness_preflight_ready": "0",
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
    "checkpoint_payload_bytes_downloaded_by_v61gl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gl {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_witness_preflight_source_rows.csv",
    "first_real_slice_witness_preflight_rows.csv",
    "first_real_slice_witness_gap_rows.csv",
    "first_real_slice_witness_stage_rows.csv",
    "first_real_slice_witness_command_rows.csv",
    "first_real_slice_witness_preflight_package_file_rows.csv",
    "V61GL_POST_GK_FIRST_REAL_SLICE_WITNESS_PREFLIGHT_BOUNDARY.md",
    "v61gl_post_gk_first_real_slice_witness_preflight_manifest.json",
    "v61gl_post_gk_first_real_slice_witness_preflight_summary.csv",
    "v61gl_post_gk_first_real_slice_witness_preflight_decision.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_PREFLIGHT_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_GAP_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_STAGE_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_COMMAND_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_PREFLIGHT_MANIFEST.json",
    "first_real_slice_witness_preflight/FIRST_REAL_SLICE_WITNESS_PREFLIGHT.md",
    "first_real_slice_witness_preflight/CHECK_WITNESS_PREFLIGHT_READY.py",
    "first_real_slice_witness_preflight/RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh",
    "first_real_slice_witness_preflight/VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh",
    "first_real_slice_witness_preflight/READY_NOW_COMMANDS.sh",
    "source_v61gk/v61gk_post_gj_first_real_slice_closure_packet_summary.csv",
    "source_v61gk/FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gl artifact: {rel}")

for rel in [
    "FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "CHECK_WITNESS_PREFLIGHT_READY.py",
    "RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh",
    "VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gl executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("source-v61gk-ready") != "pass" or decisions.get("zero-repo-checkpoint-payload") != "pass":
    raise SystemExit("v61gl expected source and zero-payload gates to pass")
for gate in [
    "witness-dir-supplied",
    "witness-dir-outside-repo",
    "content-witness-preflight",
    "first-real-slice-closure",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gl expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_WITNESS_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gl default checker must fail without witness dir")
if "content witness preflight remains blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61gl checker did not explain default block: {checker.stdout} {checker.stderr}")

manifest = json.loads((package_dir / "FIRST_REAL_SLICE_WITNESS_PREFLIGHT_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("content_witness_preflight_ready") != 0 or manifest.get("contains_real_external_evidence") != 0:
    raise SystemExit("v61gl default manifest should be blocked and zero evidence")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gl sha256 mismatch: {rel}")

print("v61gl default no-witness preflight smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$NONFINAL_WITNESS_DIR"
mkdir -p "$READY_WITNESS_DIR" "$NONFINAL_WITNESS_DIR"

python3 - "$READY_WITNESS_DIR" "$NONFINAL_WITNESS_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

ready = Path(sys.argv[1])
nonfinal = Path(sys.argv[2])
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
shutil.copytree(ready, nonfinal, dirs_exist_ok=True)
(nonfinal / "review_comment.txt").write_text("REPLACE_WITH_EXTERNAL_REVIEW_COMMENT\n", encoding="utf-8")
PY

V61GL_RUN_ID="witness_ready" \
V61GL_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
V61GL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/witness_ready" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = run_dir / "first_real_slice_witness_preflight"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "witness_dir_supplied": "1",
    "witness_dir_exists": "1",
    "witness_dir_outside_repo": "1",
    "content_witness_rows": "7",
    "ready_content_witness_rows": "7",
    "missing_content_witness_rows": "0",
    "nonfinal_content_witness_rows": "0",
    "content_witness_preflight_ready": "1",
    "contains_real_external_evidence": "0",
    "first_real_slice_closure_ready": "0",
    "real_external_review_return_rows": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "ready_command_rows": "3",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gl witness-ready {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["witness-dir-supplied", "witness-dir-outside-repo", "content-witness-preflight"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gl witness-ready expected pass decision: {gate}")
for gate in ["first-real-slice-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gl witness-ready expected blocked decision: {gate}")

checker = subprocess.run(
    [str(package_dir / "CHECK_WITNESS_PREFLIGHT_READY.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode != 0:
    raise SystemExit(f"v61gl witness-ready checker should pass: {checker.stdout} {checker.stderr}")

print("v61gl witness-ready preflight smoke passed")
PY

V61GL_RUN_ID="nonfinal_witness_reject" \
V61GL_CONTENT_WITNESS_DIR="$NONFINAL_WITNESS_DIR" \
V61GL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/nonfinal_witness_reject" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
    "witness_dir_supplied": "1",
    "witness_dir_exists": "1",
    "witness_dir_outside_repo": "1",
    "ready_content_witness_rows": "6",
    "missing_content_witness_rows": "0",
    "nonfinal_content_witness_rows": "1",
    "content_witness_preflight_ready": "0",
    "contains_real_external_evidence": "0",
    "first_real_slice_closure_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gl nonfinal {field}: expected {value}, got {summary.get(field)}")

rows = read_csv(run_dir / "first_real_slice_witness_preflight_rows.csv")
review = next(row for row in rows if row["required_filename"] == "review_comment.txt")
if "nonfinal-content-witness:review_comment.txt" not in review.get("errors", ""):
    raise SystemExit(f"v61gl nonfinal should explain rejected witness: {review}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("content-witness-preflight") != "blocked":
    raise SystemExit("v61gl nonfinal content witness must block preflight")

print("v61gl nonfinal witness rejection smoke passed")
PY

V61GL_RUN_ID="preflight_001" \
V61GL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh" >/dev/null
