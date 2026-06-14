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
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "9",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "8",
    "source_file_rows": "6",
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
    "operator-input-preflight",
    "assembly-admitted",
    "assembly-executed",
    "authority-bound-replay-admission",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj expected blocked decision: {gate}")

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
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gj template reject {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("operator-input-root-supplied") != "pass":
    raise SystemExit("v61gj template reject should see supplied root")
for gate in ["operator-input-preflight", "assembly-admitted", "assembly-executed", "authority-bound-replay-admission"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gj template reject must keep gate blocked: {gate}")

print("v61gj template tree rejection smoke passed")
PY

V61GJ_RUN_ID="receiver_001" \
V61GJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null
