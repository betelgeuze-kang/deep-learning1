#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fz_post_fy_active_goal_status_refresh"
RUN_DIR="$RESULTS_DIR/$PREFIX/refresh_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REFRESH_DIR="$RUN_DIR/post_fy_active_goal_status_refresh"

V61FY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fy_post_fx_operator_handoff_receipt.sh" >/dev/null

V61FZ_REUSE_EXISTING="${V61FZ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fz_post_fy_active_goal_status_refresh.sh" >/dev/null

"$REFRESH_DIR/VERIFY_POST_FY_STATUS_REFRESH.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REFRESH_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
refresh_dir = Path(sys.argv[4])


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
    "v61fz_post_fy_active_goal_status_refresh_ready": "1",
    "v61fy_post_fx_operator_handoff_receipt_ready": "1",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": "1",
    "v61fu_post_ft_external_return_closure_frontier_ready": "1",
    "v61ft_active_goal_completion_audit_ready": "1",
    "active_goal_complete": "0",
    "v52_ready": "1",
    "f_optional_final_disposition_ready": "1",
    "comparison_wording_claim_ready": "1",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "post_full_shard_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "root_pinned_replay_script_ready": "1",
    "ready_handoff_action_rows": "4",
    "successful_ready_handoff_action_rows": "4",
    "blocked_handoff_action_execution_attempt_rows": "0",
    "guard_probe_rows": "2",
    "passed_guard_probe_rows": "2",
    "missing_external_return_artifacts": "91",
    "missing_human_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "requirement_rows": "18",
    "ready_requirement_rows": "6",
    "blocked_requirement_rows": "12",
    "blocker_rows": "12",
    "next_action_rows": "6",
    "ready_next_action_rows": "1",
    "blocked_next_action_rows": "5",
    "status_package_file_rows": "7",
    "metadata_only_status_package_file_rows": "7",
    "payload_like_status_package_file_rows": "0",
    "source_file_rows": "11",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fz {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fy_status_requirement_rows.csv",
    "post_fy_status_blocker_rows.csv",
    "post_fy_status_next_action_rows.csv",
    "post_fy_status_metric_rows.csv",
    "post_fy_status_source_rows.csv",
    "post_fy_status_package_file_rows.csv",
    "V61FZ_POST_FY_ACTIVE_GOAL_STATUS_REFRESH_BOUNDARY.md",
    "v61fz_post_fy_active_goal_status_refresh_manifest.json",
    "v61fz_post_fy_active_goal_status_refresh_summary.csv",
    "v61fz_post_fy_active_goal_status_refresh_decision.csv",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_MANIFEST.json",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_REQUIREMENT_ROWS.csv",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_BLOCKER_ROWS.csv",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_NEXT_ACTION_ROWS.csv",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_METRIC_ROWS.csv",
    "post_fy_active_goal_status_refresh/POST_FY_STATUS_REFRESH.md",
    "post_fy_active_goal_status_refresh/VERIFY_POST_FY_STATUS_REFRESH.sh",
    "source_v61ft/v61ft_active_goal_completion_audit_summary.csv",
    "source_v61ft/active_goal_completion_requirement_rows.csv",
    "source_v61fu/v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "source_v61fu/external_return_closure_frontier_delta_rows.csv",
    "source_v61fx/v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "source_v61fx/dual_return_operator_handoff_root_contract_rows.csv",
    "source_v61fy/v61fy_post_fx_operator_handoff_receipt_summary.csv",
    "source_v61fy/operator_handoff_receipt_execution_rows.csv",
    "source_v61fy/operator_handoff_guard_probe_rows.csv",
    "source_v61fy/operator_handoff_receipt_stage_rows.csv",
    "source_v61fy/OPERATOR_HANDOFF_RECEIPT_MANIFEST.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fz artifact: {rel}")

if not os.access(refresh_dir / "VERIFY_POST_FY_STATUS_REFRESH.sh", os.X_OK):
    raise SystemExit("v61fz verifier must be executable")

requirements = read_csv(run_dir / "post_fy_status_requirement_rows.csv")
if len(requirements) != 18:
    raise SystemExit("v61fz expected 18 requirement rows")
if sum(row["status"] == "ready" for row in requirements) != 7:
    raise SystemExit("v61fz expected seven ready requirements")
if sum(row["status"] == "blocked" for row in requirements) != 11:
    raise SystemExit("v61fz expected eleven blocked requirements")
required_ready = {
    "01-v52-f-optional-final-disposition",
    "02-v52-comparison-wording-disclosure",
    "03-v53-complete-source-machine-surface",
    "07-v61-real-model-runtime-evidence",
    "08-v61-root-pinned-handoff-receipt",
    "09-v61-handoff-ready-actions",
    "10-v61-fail-closed-guard-probes",
}
for row in requirements:
    if row["requirement_id"] in required_ready and row["status"] != "ready":
        raise SystemExit(f"v61fz expected ready requirement: {row['requirement_id']}")

blockers = read_csv(run_dir / "post_fy_status_blocker_rows.csv")
if len(blockers) != 11:
    raise SystemExit("v61fz expected eleven blocker rows")
for blocker_id in [
    "04-v53-human-review-return",
    "05-v53-adjudication-return",
    "11-dual-real-return-roots",
    "16-v61-actual-model-generation",
    "18-latency-quality-release",
]:
    if not any(row["blocker_id"] == blocker_id for row in blockers):
        raise SystemExit(f"v61fz missing blocker row: {blocker_id}")

next_actions = read_csv(run_dir / "post_fy_status_next_action_rows.csv")
if len(next_actions) != 6:
    raise SystemExit("v61fz expected six next actions")
if sum(row["ready_to_run_now"] == "1" for row in next_actions) != 1:
    raise SystemExit("v61fz expected one ready next action")
if sum(row["ready_to_run_now"] == "0" for row in next_actions) != 5:
    raise SystemExit("v61fz expected five blocked next actions")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] and row["ready_to_run_now"] == "0" for row in next_actions):
    raise SystemExit("v61fz must keep dual return replay command blocked")

metrics = read_csv(run_dir / "post_fy_status_metric_rows.csv")
if len(metrics) != 1:
    raise SystemExit("v61fz expected one metric row")
metric = metrics[0]
if metric["active_goal_complete"] != "0" or metric["actual_model_generation_ready"] != "0":
    raise SystemExit("v61fz metric row must keep goal/generation blocked")
if metric["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61fz metric row must keep repo payload zero")

sources = read_csv(run_dir / "post_fy_status_source_rows.csv")
if len(sources) != 11:
    raise SystemExit("v61fz expected 11 source rows")
if any(row["metadata_only"] != "1" for row in sources):
    raise SystemExit("v61fz source rows must be metadata-only")

package_rows = read_csv(run_dir / "post_fy_status_package_file_rows.csv")
if len(package_rows) != 7:
    raise SystemExit("v61fz expected seven package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61fz package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52-f-optional-policy",
    "v53-machine-surface",
    "v61-runtime-evidence",
    "v61fy-root-pinned-handoff-receipt",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fz expected pass decision: {gate}")
for gate in ["external-review-return", "dual-real-return-roots", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fz expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61fz_post_fy_active_goal_status_refresh_manifest.json").read_text(encoding="utf-8"))
if manifest.get("active_goal_complete") != 0:
    raise SystemExit("v61fz manifest must keep active goal incomplete")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fz manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fz manifest must keep repo payload zero")

refresh_manifest = json.loads((refresh_dir / "POST_FY_STATUS_MANIFEST.json").read_text(encoding="utf-8"))
if refresh_manifest.get("requirement_rows") != 18:
    raise SystemExit("v61fz package manifest requirement mismatch")
if refresh_manifest.get("active_goal_complete") != 0:
    raise SystemExit("v61fz package manifest must keep goal incomplete")

boundary = (run_dir / "V61FZ_POST_FY_ACTIVE_GOAL_STATUS_REFRESH_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61fz_post_fy_active_goal_status_refresh_ready=1",
    "active_goal_complete=0",
    "v52_ready=0",
    "v53_machine_complete_source_surface_ready=1",
    "complete_source_repo_count=10",
    "complete_source_query_rows=1000",
    "core_answer_rows=7000",
    "post_full_shard_runtime_evidence_ready=1",
    "root_pinned_replay_script_ready=1",
    "successful_ready_handoff_action_rows=4/4",
    "passed_guard_probe_rows=2/2",
    "missing_external_return_artifacts=91",
    "missing_human_review_rows=7000",
    "missing_adjudication_rows=1000",
    "missing_generation_result_artifacts=5",
    "missing_generation_result_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fz boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fz sha256 mismatch: {rel}")

print("v61fz post-fy active goal status refresh smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v61fz produced model/checkpoint payload-like files" >&2
  exit 1
fi
