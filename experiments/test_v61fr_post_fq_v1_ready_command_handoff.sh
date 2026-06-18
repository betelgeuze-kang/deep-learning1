#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fr_post_fq_v1_ready_command_handoff"
RUN_DIR="$RESULTS_DIR/$PREFIX/handoff_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
HANDOFF_DIR="$RUN_DIR/post_fq_v1_ready_command_handoff"

V61FQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fq_post_fp_v1_comparison_readiness_refresh.sh" >/dev/null

V61FR_REUSE_EXISTING="${V61FR_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fr_post_fq_v1_ready_command_handoff.sh" >/dev/null

"$HANDOFF_DIR/VERIFY_HANDOFF.sh" >/dev/null
"$HANDOFF_DIR/READY_NOW_COMMANDS.sh" >/tmp/v61fr_ready_now_commands.out

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "/tmp/v61fr_ready_now_commands.out" <<'PY'
import csv
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ready_out = Path(sys.argv[4])
handoff_dir = run_dir / "post_fq_v1_ready_command_handoff"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61fr_post_fq_v1_ready_command_handoff_ready": "1",
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": "1",
    "v53ah_complete_source_external_review_send_bundle_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": "1",
    "v52_ready": "0",
    "comparison_wording_claim_ready": "0",
    "v53_machine_complete_source_surface_ready": "1",
    "full_shard_prerequisites_closed": "1",
    "send_bundle_ready": "1",
    "send_bundle_archive_files": "2",
    "return_artifact_template_archive_member_rows": "81",
    "accepted_dispatch_receipt_rows": "0",
    "return_bundle_preflight_pass": "0",
    "preflight_pass_rows": "0",
    "preflight_rows": "81",
    "replay_entrypoint_ready": "1",
    "replay_entrypoint_admitted": "0",
    "external_review_return_ready": "0",
    "v1_0_comparison_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fr": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "handoff_stage_rows": "7",
    "ready_handoff_stage_rows": "3",
    "blocked_handoff_stage_rows": "4",
    "handoff_command_rows": "8",
    "ready_handoff_command_rows": "4",
    "blocked_handoff_command_rows": "4",
    "required_external_input_rows": "5",
    "present_external_input_rows": "0",
    "missing_external_input_rows": "5",
    "handoff_package_file_rows": "7",
    "metadata_only_handoff_package_file_rows": "7",
    "payload_like_handoff_package_file_rows": "0",
    "source_summary_file_rows": "8",
    "source_artifact_file_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fr {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fq_v1_ready_command_handoff_stage_rows.csv",
    "post_fq_v1_ready_command_handoff_command_rows.csv",
    "post_fq_v1_ready_command_handoff_external_input_rows.csv",
    "post_fq_v1_ready_command_handoff_metric_rows.csv",
    "post_fq_v1_ready_command_handoff_file_rows.csv",
    "V61FR_POST_FQ_V1_READY_COMMAND_HANDOFF_BOUNDARY.md",
    "v61fr_post_fq_v1_ready_command_handoff_manifest.json",
    "v61fr_post_fq_v1_ready_command_handoff_summary.csv",
    "v61fr_post_fq_v1_ready_command_handoff_decision.csv",
    "post_fq_v1_ready_command_handoff/HANDOFF_MANIFEST.json",
    "post_fq_v1_ready_command_handoff/HANDOFF_STAGE_ROWS.csv",
    "post_fq_v1_ready_command_handoff/HANDOFF_COMMAND_ROWS.csv",
    "post_fq_v1_ready_command_handoff/REQUIRED_EXTERNAL_INPUT_ROWS.csv",
    "post_fq_v1_ready_command_handoff/READY_NOW_COMMANDS.sh",
    "post_fq_v1_ready_command_handoff/VERIFY_HANDOFF.sh",
    "post_fq_v1_ready_command_handoff/V1_READY_COMMAND_HANDOFF.md",
    "source_summaries/v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "source_summaries/v53ah_complete_source_external_review_send_bundle_summary.csv",
    "source_summaries/v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "source_summaries/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_summary.csv",
    "source_artifacts/v61fq_readiness_rows.csv",
    "source_artifacts/v61fq_next_action_rows.csv",
    "source_artifacts/v53ah_send_bundle_file_rows.csv",
    "source_artifacts/v53ah_send_bundle_requirement_rows.csv",
    "source_artifacts/v53al_preflight_rows.csv",
    "source_artifacts/v61fo_entrypoint_command_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fr artifact: {rel}")

for rel in [
    "post_fq_v1_ready_command_handoff/READY_NOW_COMMANDS.sh",
    "post_fq_v1_ready_command_handoff/VERIFY_HANDOFF.sh",
]:
    if not os.access(run_dir / rel, os.X_OK):
        raise SystemExit(f"v61fr executable bit missing: {rel}")

stages = read_csv(run_dir / "post_fq_v1_ready_command_handoff_stage_rows.csv")
if len(stages) != 7:
    raise SystemExit("v61fr expected seven stage rows")
if sum(row["status"] == "ready" for row in stages) != 3:
    raise SystemExit("v61fr expected three ready stages")
if sum(row["status"] == "blocked" for row in stages) != 4:
    raise SystemExit("v61fr expected four blocked stages")
for stage_id in [
    "01-v61fq-refresh-ready",
    "02-v53-send-bundle-ready",
    "03-ready-command-handoff-package",
]:
    row = next(row for row in stages if row["stage_id"] == stage_id)
    if row["status"] != "ready":
        raise SystemExit(f"v61fr stage should be ready: {stage_id}")
for stage_id in [
    "04-v53-return-bundle-preflight",
    "05-v61-real-review-return",
    "06-generation-result-acceptance",
    "07-v1-comparison-ready",
]:
    row = next(row for row in stages if row["stage_id"] == stage_id)
    if row["status"] != "blocked":
        raise SystemExit(f"v61fr stage should be blocked: {stage_id}")

commands = read_csv(run_dir / "post_fq_v1_ready_command_handoff_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "1", "1", "0", "0", "0", "0"]:
    raise SystemExit("v61fr command readiness mismatch")

external_inputs = read_csv(run_dir / "post_fq_v1_ready_command_handoff_external_input_rows.csv")
if len(external_inputs) != 5:
    raise SystemExit("v61fr expected five external input rows")
if any(row["present"] != "0" for row in external_inputs):
    raise SystemExit("v61fr canonical path must not mark external input present")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61fq-refresh", "v53-send-bundle", "local-ready-commands", "zero-repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fr decision should pass: {gate}")
for gate in [
    "required-external-inputs",
    "v53-return-preflight",
    "v61-real-review-return",
    "v1-comparison",
    "actual-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fr decision should be blocked: {gate}")

ready_text = ready_out.read_text(encoding="utf-8")
for snippet in [
    "Ready local verification commands",
    "VERIFY_HANDOFF.sh",
    "test_v61fq_post_fp_v1_comparison_readiness_refresh.sh",
    "VERIFY_SEND_BUNDLE.sh",
    "Blocked until external inputs exist",
    "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle",
    "V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return",
]:
    if snippet not in ready_text:
        raise SystemExit(f"v61fr ready-now output missing snippet: {snippet}")

boundary = (run_dir / "V61FR_POST_FQ_V1_READY_COMMAND_HANDOFF_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fr_post_fq_v1_ready_command_handoff_ready=1",
    "send_bundle_ready=1",
    "return_artifact_template_archive_member_rows=81",
    "v52_ready=0",
    "comparison_wording_claim_ready=0",
    "v53_machine_complete_source_surface_ready=1",
    "full_shard_prerequisites_closed=1",
    "return_bundle_preflight_pass=0",
    "external_review_return_ready=0",
    "v1_0_comparison_ready=0",
    "actual_model_generation_ready=0",
    "handoff_stage_rows=7",
    "ready_handoff_stage_rows=3",
    "blocked_handoff_stage_rows=4",
    "handoff_command_rows=8",
    "ready_handoff_command_rows=4",
    "blocked_handoff_command_rows=4",
    "required_external_input_rows=5",
    "missing_external_input_rows=5",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fr boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fr_post_fq_v1_ready_command_handoff_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fr_post_fq_v1_ready_command_handoff_ready") != 1:
    raise SystemExit("v61fr manifest readiness mismatch")
if manifest.get("ready_handoff_command_rows") != 4:
    raise SystemExit("v61fr manifest command readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fr manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fr manifest must keep repo checkpoint payload zero")

print("v61fr post-v61fq ready command handoff test passed")
PY
