#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gh_post_gg_authority_bound_partial_root_workbench"
RUN_DIR="$RESULTS_DIR/$PREFIX/workbench_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORKBENCH_DIR="$RUN_DIR/authority_bound_partial_root_workbench"

V61GH_REUSE_EXISTING="${V61GH_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gh_post_gg_authority_bound_partial_root_workbench.sh" >/dev/null

"$WORKBENCH_DIR/VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh" >/dev/null
"$WORKBENCH_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORKBENCH_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
workbench_dir = Path(sys.argv[4])


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
    "v61gh_post_gg_authority_bound_partial_root_workbench_ready": "1",
    "v61gg_post_gf_real_authority_binding_guard_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "selected_v53_answer_rows": "1",
    "selected_v61_query_rows": "1",
    "input_contract_rows": "14",
    "authority_bound_input_contract_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
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
    "checkpoint_payload_bytes_downloaded_by_v61gh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "source_file_rows": "8",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gh {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "authority_bound_partial_root_input_contract_rows.csv",
    "authority_bound_partial_root_selected_slice_rows.csv",
    "authority_bound_partial_root_workbench_command_rows.csv",
    "authority_bound_partial_root_workbench_source_rows.csv",
    "authority_bound_partial_root_workbench_package_file_rows.csv",
    "V61GH_POST_GG_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_BOUNDARY.md",
    "v61gh_post_gg_authority_bound_partial_root_workbench_manifest.json",
    "v61gh_post_gg_authority_bound_partial_root_workbench_summary.csv",
    "v61gh_post_gg_authority_bound_partial_root_workbench_decision.csv",
    "authority_bound_partial_root_workbench/AUTHORITY_BOUND_PARTIAL_ROOT_INPUT_CONTRACT_ROWS.csv",
    "authority_bound_partial_root_workbench/AUTHORITY_BOUND_PARTIAL_ROOT_SELECTED_SLICE_ROWS.csv",
    "authority_bound_partial_root_workbench/AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_COMMAND_ROWS.csv",
    "authority_bound_partial_root_workbench/AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_MANIFEST.json",
    "authority_bound_partial_root_workbench/AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.md",
    "authority_bound_partial_root_workbench/ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py",
    "authority_bound_partial_root_workbench/VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh",
    "authority_bound_partial_root_workbench/READY_NOW_COMMANDS.sh",
    "source_v61gg/v61gg_post_gf_real_authority_binding_guard_summary.csv",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_query_packet_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gh artifact: {rel}")

for rel in [
    "ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py",
    "VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(workbench_dir / rel, os.X_OK):
        raise SystemExit(f"v61gh executable bit missing: {rel}")

contracts = read_csv(run_dir / "authority_bound_partial_root_input_contract_rows.csv")
if len(contracts) != 14:
    raise SystemExit("v61gh expected 14 input contract rows")
for rel in [
    "operator_attestation/reviewer_authority_statement.txt",
    "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
]:
    if not any(row["target_relative_path"] == rel and row["authority_bound"] == "1" for row in contracts):
        raise SystemExit(f"v61gh missing authority-bound contract: {rel}")

selected = read_csv(run_dir / "authority_bound_partial_root_selected_slice_rows.csv")
if len(selected) != 2:
    raise SystemExit("v61gh expected two selected slice rows")
if not selected[0]["answer_id"] or not selected[1]["query_id"]:
    raise SystemExit("v61gh selected slice rows must name a concrete answer and query")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gg-ready", "source-v53r-ready", "workbench-package", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gh expected pass decision: {gate}")
for gate in [
    "operator-inputs-supplied",
    "assembled-authority-bound-roots",
    "authority-bound-replay-admission",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gh expected blocked decision: {gate}")

manifest = json.loads((workbench_dir / "AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_MANIFEST.json").read_text(encoding="utf-8"))
if manifest["summary"].get("assembled_v53_root_ready") != 0:
    raise SystemExit("v61gh default package must not assemble roots")

boundary = (run_dir / "V61GH_POST_GG_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gh_post_gg_authority_bound_partial_root_workbench_ready=1",
    "selected_v53_answer_rows=1",
    "selected_v61_query_rows=1",
    "input_contract_rows=14",
    "authority_bound_input_contract_rows=4",
    "assembled_v53_root_ready=0",
    "assembled_v61_root_ready=0",
    "real_external_review_return_rows=0",
    "real_generation_result_artifacts=0",
    "authority_bound_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gh boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gh sha256 mismatch: {rel}")

print("v61gh authority-bound partial root workbench smoke passed")
PY
