#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger"
RUN_DIR="$RESULTS_DIR/$PREFIX/ledger_001"
FIXTURE_ENTRYPOINT_DIR="$RESULTS_DIR/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/fixture_return_entrypoint_v61fo"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_entrypoint_v61fp"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
CLOSURE_DIR="$RUN_DIR/post_fo_full_shard_to_real_review_replay_closure_ledger"

V61FO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null

V61FP_REUSE_EXISTING="${V61FP_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger.sh" >/dev/null

"$CLOSURE_DIR/VERIFY_CLOSURE_LEDGER.sh" >/dev/null

V61FP_RUN_ID="fixture_entrypoint_v61fp" \
V61FP_ENTRYPOINT_RUN_DIR="$FIXTURE_ENTRYPOINT_DIR" \
V61FP_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger.sh" >/dev/null

V61FP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
closure_dir = run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready": "1",
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": "1",
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": "1",
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": "1",
    "v61fe_post_fd_real_return_replay_admission_guard_ready": "1",
    "selected_entrypoint_source_class": "canonical-no-return-root",
    "selected_review_return_dir_supplied": "0",
    "selected_review_return_dir_exists": "0",
    "selected_review_return_provenance": "unspecified",
    "real_review_return_provenance_asserted": "0",
    "fixture_return_provenance": "0",
    "full_shard_prerequisites_closed": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "post_full_shard_runtime_evidence_ready": "1",
    "runtime_execution_admitted_rows": "37",
    "runtime_admission_accepted_rows": "1000",
    "replay_entrypoint_ready": "1",
    "replay_entrypoint_admitted": "0",
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "ledger_rows": "16",
    "closed_ledger_rows": "7",
    "blocked_ledger_rows": "9",
    "blocker_rows": "9",
    "open_blocker_rows": "9",
    "next_action_rows": "6",
    "ready_next_action_rows": "2",
    "blocked_next_action_rows": "4",
    "closure_package_file_rows": "6",
    "metadata_only_closure_package_file_rows": "6",
    "payload_like_closure_package_file_rows": "0",
    "source_summary_file_rows": "12",
    "selected_entrypoint_file_rows": "3",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fp {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv",
    "post_fo_full_shard_to_real_review_replay_closure_blocker_rows.csv",
    "post_fo_full_shard_to_real_review_replay_next_action_rows.csv",
    "post_fo_full_shard_to_real_review_replay_closure_metric_rows.csv",
    "post_fo_full_shard_to_real_review_replay_closure_file_rows.csv",
    "V61FP_POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER_BOUNDARY.md",
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_manifest.json",
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_summary.csv",
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_decision.csv",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/CLOSURE_LEDGER_MANIFEST.json",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/CLOSURE_LEDGER_ROWS.csv",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/CLOSURE_BLOCKER_ROWS.csv",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/NEXT_ACTION_ROWS.csv",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER.md",
    "post_fo_full_shard_to_real_review_replay_closure_ledger/VERIFY_CLOSURE_LEDGER.sh",
    "selected_v61fo_entrypoint/entrypoint_metric_rows.csv",
    "selected_v61fo_entrypoint/entrypoint_stage_rows.csv",
    "selected_v61fo_entrypoint/entrypoint_manifest.json",
    "source_summaries/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_summary.csv",
    "source_summaries/v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv",
    "source_summaries/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "source_summaries/v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_summary.csv",
    "source_summaries/v61fm_post_fl_real_manifest_external_review_return_work_order_summary.csv",
    "source_summaries/v61fe_post_fd_real_return_replay_admission_guard_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fp artifact: {rel}")

if not os.access(closure_dir / "VERIFY_CLOSURE_LEDGER.sh", os.X_OK):
    raise SystemExit("v61fp verifier must be executable")

ledger = read_csv(run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv")
if len(ledger) != 16:
    raise SystemExit("v61fp expected 16 ledger rows")
closed = [row for row in ledger if row["status"] == "closed"]
blocked = [row for row in ledger if row["status"] == "blocked"]
if len(closed) != 7 or len(blocked) != 9:
    raise SystemExit("v61fp ledger closed/blocked counts mismatch")
for ledger_id in [
    "01-real-model-page-manifest",
    "02-full-checkpoint-materialization",
    "03-full-page-hash-coverage",
    "04-post-full-shard-runtime-evidence",
    "05-source-bound-runtime-seed",
    "06-complete-source-runtime-admission",
    "07-replay-entrypoint-package",
]:
    row = next(row for row in ledger if row["ledger_id"] == ledger_id)
    if row["status"] != "closed":
        raise SystemExit(f"v61fp ledger row should be closed: {ledger_id}")
for ledger_id in [
    "08-real-review-return-root-present",
    "09-real-review-return-provenance",
    "10-external-review-return-accepted",
    "11-real-return-replay-admission",
    "12-row-acceptance",
    "13-generation-execution-admission",
    "14-generation-result-acceptance",
    "15-actual-model-generation",
    "16-production-near-frontier-release-claims",
]:
    row = next(row for row in ledger if row["ledger_id"] == ledger_id)
    if row["status"] != "blocked":
        raise SystemExit(f"v61fp ledger row should be blocked: {ledger_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["full-shard-prerequisites", "replay-entrypoint-ready", "zero-repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fp decision should pass: {gate}")
for gate in [
    "real-review-return-root",
    "real-review-return-provenance",
    "external-review-return",
    "real-return-replay-admission",
    "row-acceptance",
    "generation-execution-admission",
    "generation-result-acceptance",
    "actual-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fp decision should be blocked: {gate}")

actions = read_csv(run_dir / "post_fo_full_shard_to_real_review_replay_next_action_rows.csv")
if [row["ready_to_run_now"] for row in actions] != ["1", "1", "0", "0", "0", "0"]:
    raise SystemExit("v61fp canonical next-action readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "post_fo_full_shard_to_real_review_replay_closure_metric_rows.csv")[0]
fixture_expected = {
    "selected_entrypoint_source_class": "fixture-return-root-candidate",
    "selected_review_return_dir_supplied": "1",
    "selected_review_return_dir_exists": "1",
    "selected_review_return_provenance": "fixture-v61fo-review-return",
    "real_review_return_provenance_asserted": "0",
    "fixture_return_provenance": "1",
    "full_shard_prerequisites_closed": "1",
    "replay_entrypoint_ready": "1",
    "replay_entrypoint_admitted": "0",
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fp fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_ledger = read_csv(fixture_run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv")
fixture_root = next(row for row in fixture_ledger if row["ledger_id"] == "08-real-review-return-root-present")
fixture_provenance = next(row for row in fixture_ledger if row["ledger_id"] == "09-real-review-return-provenance")
if fixture_root["status"] != "closed":
    raise SystemExit("v61fp fixture root-present row should close")
if fixture_provenance["status"] != "blocked":
    raise SystemExit("v61fp fixture provenance row must remain blocked")

boundary = (run_dir / "V61FP_POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready=1",
    "selected_entrypoint_source_class=canonical-no-return-root",
    "full_shard_prerequisites_closed=1",
    "full_checkpoint_materialization_ready=1",
    "full_safetensors_page_hash_binding_ready=1",
    "runtime_admission_accepted_rows=1000",
    "replay_entrypoint_admitted=0",
    "real_review_return_provenance_asserted=0",
    "actual_model_generation_ready=0",
    "ledger_rows=16",
    "closed_ledger_rows=7",
    "blocked_ledger_rows=9",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fp boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready") != 1:
    raise SystemExit("v61fp manifest readiness mismatch")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v61fp manifest should close full-shard prerequisites")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fp manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fp manifest must keep repo checkpoint payload zero")

print("v61fp post-v61fo full-shard closure ledger test passed")
PY
