#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gk_post_gj_first_real_slice_closure_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKET_DIR="$RUN_DIR/first_real_slice_closure_packet"

V61GK_REUSE_EXISTING="${V61GK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gk_post_gj_first_real_slice_closure_packet.sh" >/dev/null

"$PACKET_DIR/VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh" >/dev/null
"$PACKET_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKET_DIR" <<'PY'
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
packet_dir = Path(sys.argv[4])


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
    "v61gk_post_gj_first_real_slice_closure_packet_ready": "1",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": "1",
    "v61gj_post_gi_operator_input_receiver_ready": "1",
    "contains_real_external_evidence": "0",
    "required_artifact_rows": "13",
    "content_witness_rows": "7",
    "target_counter_rows": "15",
    "first_real_slice_closure_ready": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_ready": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "command_rows": "6",
    "ready_command_rows": "2",
    "blocked_command_rows": "4",
    "stage_rows": "7",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "4",
    "payload_like_package_file_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gk {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_closure_packet_source_rows.csv",
    "first_real_slice_required_artifact_rows.csv",
    "first_real_slice_content_witness_rows.csv",
    "first_real_slice_target_counter_rows.csv",
    "first_real_slice_command_rows.csv",
    "first_real_slice_stage_rows.csv",
    "first_real_slice_closure_packet_file_rows.csv",
    "V61GK_POST_GJ_FIRST_REAL_SLICE_CLOSURE_PACKET_BOUNDARY.md",
    "v61gk_post_gj_first_real_slice_closure_packet_manifest.json",
    "v61gk_post_gj_first_real_slice_closure_packet_summary.csv",
    "v61gk_post_gj_first_real_slice_closure_packet_decision.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_COMMAND_ROWS.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_STAGE_ROWS.csv",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_CLOSURE_PACKET_MANIFEST.json",
    "first_real_slice_closure_packet/FIRST_REAL_SLICE_CLOSURE_PACKET.md",
    "first_real_slice_closure_packet/MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "first_real_slice_closure_packet/MINIMAL_SLICE_SELECTED_CONTEXT.json",
    "first_real_slice_closure_packet/MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "first_real_slice_closure_packet/MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "first_real_slice_closure_packet/MINIMAL_SLICE_ROWS.csv.template",
    "first_real_slice_closure_packet/AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv",
    "first_real_slice_closure_packet/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh",
    "first_real_slice_closure_packet/CHECK_FIRST_REAL_SLICE_COUNTERS.py",
    "first_real_slice_closure_packet/VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh",
    "first_real_slice_closure_packet/READY_NOW_COMMANDS.sh",
    "source_gate_summaries/v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "source_gate_summaries/v61gf_post_ge_dual_partial_return_replay_admission_summary.csv",
    "source_gate_summaries/v61gj_post_gi_operator_input_receiver_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gk artifact: {rel}")

for rel in [
    "FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh",
    "CHECK_FIRST_REAL_SLICE_COUNTERS.py",
    "VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(packet_dir / rel, os.X_OK):
        raise SystemExit(f"v61gk executable bit missing: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gi-ready", "source-v61gf-ready", "source-v61gj-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gk expected pass decision: {gate}")
for gate in ["first-real-slice-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gk expected blocked decision: {gate}")

target_rows = read_csv(run_dir / "first_real_slice_target_counter_rows.csv")
if len(target_rows) != 15:
    raise SystemExit("v61gk expected 15 target counter rows")
ready_by_counter = {row["counter"]: row["ready"] for row in target_rows}
if ready_by_counter.get("actual_model_generation_ready") != "1":
    raise SystemExit("v61gk actual_model_generation_ready row documents the current full-generation blocker as 0")
blocked_targets = [row for row in target_rows if row["counter"] != "actual_model_generation_ready" and row["ready"] != "1"]
if len(blocked_targets) != 14:
    raise SystemExit(f"v61gk expected 14 blocked subset target rows, got {len(blocked_targets)}")

witness_rows = read_csv(run_dir / "first_real_slice_content_witness_rows.csv")
if len(witness_rows) != 7 or any(row["nonfinal_content_rejected"] != "1" for row in witness_rows):
    raise SystemExit("v61gk witness rows must all require nonfinal-content rejection")

command_rows = read_csv(run_dir / "first_real_slice_command_rows.csv")
if sum(row["ready_to_run_now"] == "1" for row in command_rows) != 2:
    raise SystemExit("v61gk should expose only verify/print commands before external evidence")

checker = subprocess.run(
    [str(packet_dir / "CHECK_FIRST_REAL_SLICE_COUNTERS.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if checker.returncode == 0:
    raise SystemExit("v61gk counter checker must fail before real external rows are supplied")
if "first real slice counters remain blocked" not in (checker.stdout + checker.stderr):
    raise SystemExit(f"v61gk checker did not explain blocked counters: {checker.stdout} {checker.stderr}")

manifest = json.loads((packet_dir / "FIRST_REAL_SLICE_CLOSURE_PACKET_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("contains_real_external_evidence") != 0:
    raise SystemExit("v61gk packet must remain zero real evidence")
if manifest.get("first_real_slice_closure_ready") != 0:
    raise SystemExit("v61gk default packet must keep first slice closure blocked")

boundary = (run_dir / "V61GK_POST_GJ_FIRST_REAL_SLICE_CLOSURE_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gk_post_gj_first_real_slice_closure_packet_ready=1",
    "contains_real_external_evidence=0",
    "real_external_review_return_rows=0",
    "real_adjudication_rows=0",
    "generation_result_accepted_rows=0",
    "dual_external_return_real_ready=0",
    "real_return_replay_admission_ready=0",
    "generation_acceptance_closure_ready=0",
    "actual_model_generation_ready=0",
    "does not supply or fabricate external review",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gk boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gk sha256 mismatch: {rel}")

print("v61gk first real slice closure packet smoke passed")
PY
