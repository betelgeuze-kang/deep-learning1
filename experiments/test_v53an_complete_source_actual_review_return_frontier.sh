#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53an_complete_source_actual_review_return_frontier"
RUN_DIR="$RESULTS_DIR/$PREFIX/frontier_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FRONTIER_DIR="$RUN_DIR/actual_review_return_frontier"

V53AN_REUSE_EXISTING="${V53AN_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53an_complete_source_actual_review_return_frontier.sh" >/dev/null

"$FRONTIER_DIR/VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FRONTIER_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
frontier_dir = Path(sys.argv[4])


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
    "v53an_complete_source_actual_review_return_frontier_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v61fz_post_fy_active_goal_status_refresh_ready": "1",
    "active_goal_complete": "0",
    "v52_ready": "1",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "operator_checklist_rows": "81",
    "missing_checklist_rows": "81",
    "preflight_rows": "81",
    "preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "replay_step_rows": "11",
    "ready_replay_step_rows": "2",
    "blocked_replay_step_rows": "9",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "review_return_ready": "0",
    "v53_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53an": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "frontier_requirement_rows": "16",
    "ready_frontier_requirement_rows": "6",
    "blocked_frontier_requirement_rows": "10",
    "frontier_blocker_rows": "10",
    "frontier_action_rows": "6",
    "ready_frontier_action_rows": "2",
    "blocked_frontier_action_rows": "4",
    "frontier_package_file_rows": "7",
    "metadata_only_frontier_package_file_rows": "7",
    "payload_like_frontier_package_file_rows": "0",
    "source_file_rows": "10",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53an {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "actual_review_return_frontier_requirement_rows.csv",
    "actual_review_return_frontier_blocker_rows.csv",
    "actual_review_return_frontier_action_rows.csv",
    "actual_review_return_frontier_metric_rows.csv",
    "actual_review_return_frontier_source_rows.csv",
    "actual_review_return_frontier_package_file_rows.csv",
    "V53AN_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_BOUNDARY.md",
    "v53an_complete_source_actual_review_return_frontier_manifest.json",
    "v53an_complete_source_actual_review_return_frontier_summary.csv",
    "v53an_complete_source_actual_review_return_frontier_decision.csv",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER_REQUIREMENT_ROWS.csv",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER_BLOCKER_ROWS.csv",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER_ACTION_ROWS.csv",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER_METRIC_ROWS.csv",
    "actual_review_return_frontier/ACTUAL_REVIEW_RETURN_FRONTIER.md",
    "actual_review_return_frontier/VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER.sh",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "source_v53am/return_acceptance_replay_step_rows.csv",
    "source_v53am/return_acceptance_replay_command_rows.csv",
    "source_v53ak/v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "source_v53al/external_return_bundle_preflight_rows.csv",
    "source_v61fz/v61fz_post_fy_active_goal_status_refresh_summary.csv",
    "source_v61fz/post_fy_status_requirement_rows.csv",
    "source_v61fz/post_fy_status_blocker_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53an artifact: {rel}")

if not os.access(frontier_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER.sh", os.X_OK):
    raise SystemExit("v53an verifier must be executable")

requirements = read_csv(run_dir / "actual_review_return_frontier_requirement_rows.csv")
if len(requirements) != 16:
    raise SystemExit("v53an expected 16 requirement rows")
if sum(row["status"] == "ready" for row in requirements) != 6:
    raise SystemExit("v53an expected six ready requirements")
if sum(row["status"] == "blocked" for row in requirements) != 10:
    raise SystemExit("v53an expected ten blocked requirements")
for req_id in [
    "01-v52-f-optional-final-policy",
    "02-v53-complete-source-machine-surface",
    "03-v53-return-operator-checklist",
    "04-v53-return-preflight-surface",
    "05-v53am-acceptance-replay-surface",
    "06-v61-runtime-and-handoff-evidence",
]:
    if not any(row["requirement_id"] == req_id and row["status"] == "ready" for row in requirements):
        raise SystemExit(f"v53an missing ready requirement: {req_id}")

blockers = read_csv(run_dir / "actual_review_return_frontier_blocker_rows.csv")
if len(blockers) != 10:
    raise SystemExit("v53an expected ten blocker rows")
for blocker_id in [
    "07-return-bundle-preflight-pass",
    "10-aggregate-human-review-return",
    "11-adjudication-return",
    "12-generation-result-return",
    "15-actual-model-generation",
]:
    if not any(row["blocker_id"] == blocker_id for row in blockers):
        raise SystemExit(f"v53an missing blocker: {blocker_id}")

actions = read_csv(run_dir / "actual_review_return_frontier_action_rows.csv")
if len(actions) != 6:
    raise SystemExit("v53an expected six action rows")
if sum(row["ready_to_run_now"] == "1" for row in actions) != 2:
    raise SystemExit("v53an expected two ready actions")
if sum(row["ready_to_run_now"] == "0" for row in actions) != 4:
    raise SystemExit("v53an expected four blocked actions")
if not any("V53AM_RETURN_BUNDLE_DIR" in row["command"] and row["ready_to_run_now"] == "0" for row in actions):
    raise SystemExit("v53an must keep real return replay blocked")

metrics = read_csv(run_dir / "actual_review_return_frontier_metric_rows.csv")
if len(metrics) != 1:
    raise SystemExit("v53an expected one metric row")
metric = metrics[0]
if metric["active_goal_complete"] != "0" or metric["actual_model_generation_ready"] != "0":
    raise SystemExit("v53an metric must keep goal/generation blocked")
if metric["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v53an metric must keep repo payload zero")

sources = read_csv(run_dir / "actual_review_return_frontier_source_rows.csv")
if len(sources) != 10:
    raise SystemExit("v53an expected ten source rows")
if any(row["metadata_only"] != "1" for row in sources):
    raise SystemExit("v53an source rows must be metadata-only")

package_rows = read_csv(run_dir / "actual_review_return_frontier_package_file_rows.csv")
if len(package_rows) != 7:
    raise SystemExit("v53an expected seven package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v53an package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v53-machine-surface", "return-operator-checklist", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53an expected pass decision: {gate}")
for gate in ["return-preflight-pass", "human-review-return", "adjudication-return", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53an expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v53an_complete_source_actual_review_return_frontier_manifest.json").read_text(encoding="utf-8"))
if manifest.get("active_goal_complete") != 0:
    raise SystemExit("v53an manifest must keep active goal incomplete")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53an manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53an manifest must keep repo payload zero")

frontier_manifest = json.loads((frontier_dir / "ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json").read_text(encoding="utf-8"))
if frontier_manifest.get("frontier_requirement_rows") != 16:
    raise SystemExit("v53an frontier manifest requirement mismatch")
if frontier_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53an frontier manifest must keep generation blocked")

boundary = (run_dir / "V53AN_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v53an_complete_source_actual_review_return_frontier_ready=1",
    "active_goal_complete=0",
    "complete_source_repo_count=10",
    "complete_source_query_rows=1000",
    "core_answer_rows=7000",
    "operator_checklist_rows=81",
    "missing_checklist_rows=81",
    "preflight_pass_rows=0/81",
    "accepted_dispatch_receipt_rows=0/21",
    "accepted_chunk_return_artifact_rows=0/50",
    "answer_review_accepted_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "review_return_ready=0",
    "v53_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53an boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53an sha256 mismatch: {rel}")

print("v53an complete-source actual review return frontier smoke passed")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \) | grep -q .; then
  echo "v53an produced model/checkpoint payload-like files" >&2
  exit 1
fi
