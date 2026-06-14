#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ga_post_fz_generation_unblock_runway"
RUN_DIR="$RESULTS_DIR/$PREFIX/runway_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/generation_unblock_runway"

V61GA_REUSE_EXISTING="${V61GA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ga_post_fz_generation_unblock_runway.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_GENERATION_UNBLOCK_RUNWAY.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import json
import os
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
    "v61ga_post_fz_generation_unblock_runway_ready": "1",
    "v61fz_post_fy_active_goal_status_refresh_ready": "1",
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready": "1",
    "active_goal_complete": "0",
    "v52_ready": "1",
    "v53_machine_complete_source_surface_ready": "1",
    "post_full_shard_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "root_pinned_replay_script_ready": "1",
    "successful_v53ao_ready_action_rows": "2",
    "blocked_v53ao_action_rows": "4",
    "missing_external_return_artifacts": "91",
    "missing_human_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "runway_requirement_rows": "18",
    "ready_runway_requirement_rows": "5",
    "blocked_runway_requirement_rows": "13",
    "minimum_batch_rows": "6",
    "blocked_minimum_batch_rows": "6",
    "replay_command_rows": "5",
    "ready_replay_command_rows": "2",
    "blocked_replay_command_rows": "3",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ga": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "blocker_rows": "13",
    "delta_focus_rows": "14",
    "source_file_rows": "9",
    "runway_package_file_rows": "9",
    "metadata_only_runway_package_file_rows": "9",
    "payload_like_runway_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ga {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "generation_unblock_runway_requirement_rows.csv",
    "generation_unblock_runway_blocker_rows.csv",
    "generation_unblock_runway_minimum_batch_rows.csv",
    "generation_unblock_runway_replay_command_rows.csv",
    "generation_unblock_runway_delta_focus_rows.csv",
    "generation_unblock_runway_metric_rows.csv",
    "generation_unblock_runway_source_rows.csv",
    "generation_unblock_runway_package_file_rows.csv",
    "V61GA_POST_FZ_GENERATION_UNBLOCK_RUNWAY_BOUNDARY.md",
    "v61ga_post_fz_generation_unblock_runway_manifest.json",
    "v61ga_post_fz_generation_unblock_runway_summary.csv",
    "v61ga_post_fz_generation_unblock_runway_decision.csv",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_MANIFEST.json",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_REQUIREMENT_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_BLOCKER_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_MINIMUM_BATCH_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_REPLAY_COMMAND_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_DELTA_FOCUS_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY_METRIC_ROWS.CSV",
    "generation_unblock_runway/GENERATION_UNBLOCK_RUNWAY.md",
    "generation_unblock_runway/VERIFY_GENERATION_UNBLOCK_RUNWAY.sh",
    "source_v61fz/v61fz_post_fy_active_goal_status_refresh_summary.csv",
    "source_v61fz/post_fy_status_requirement_rows.csv",
    "source_v61fz/post_fy_status_blocker_rows.csv",
    "source_v61fz/post_fy_status_next_action_rows.csv",
    "source_v61fu/v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "source_v61fu/external_return_closure_frontier_delta_rows.csv",
    "source_v53ao/v53ao_complete_source_actual_review_return_frontier_receipt_summary.csv",
    "source_v53ao/actual_review_return_frontier_receipt_execution_rows.csv",
    "source_v53ao/actual_review_return_frontier_receipt_stage_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ga artifact: {rel}")

if not os.access(package_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY.sh", os.X_OK):
    raise SystemExit("v61ga verifier must be executable")

requirements = read_csv(run_dir / "generation_unblock_runway_requirement_rows.csv")
if len(requirements) != 18:
    raise SystemExit("v61ga expected 18 requirement rows")
if sum(row["status"] == "ready" for row in requirements) != 5:
    raise SystemExit("v61ga expected five ready requirements")
if sum(row["status"] == "blocked" for row in requirements) != 13:
    raise SystemExit("v61ga expected thirteen blocked requirements")
ready_ids = {
    "01-v52-f-optional-final-disposition",
    "02-v53-complete-source-machine-surface",
    "03-v61-full-shard-runtime-evidence",
    "04-v61-root-pinned-replay-script",
    "05-v53ao-frontier-receipt",
}
for row in requirements:
    if row["requirement_id"] in ready_ids and row["status"] != "ready":
        raise SystemExit(f"v61ga expected ready requirement: {row['requirement_id']}")

blockers = read_csv(run_dir / "generation_unblock_runway_blocker_rows.csv")
if len(blockers) != 13:
    raise SystemExit("v61ga expected thirteen blocker rows")
for blocker_id in [
    "06-v53-return-artifact-presence",
    "07-v53-human-review-rows",
    "08-v53-adjudication-rows",
    "10-v61-generation-intake-root",
    "11-v61-generation-result-artifacts",
    "12-v61-generation-result-rows",
    "16-actual-model-generation",
    "18-latency-quality-release",
]:
    if not any(row["blocker_id"] == blocker_id for row in blockers):
        raise SystemExit(f"v61ga missing blocker row: {blocker_id}")

batches = read_csv(run_dir / "generation_unblock_runway_minimum_batch_rows.csv")
if len(batches) != 6:
    raise SystemExit("v61ga expected six minimum batches")
if sum(row["status"] == "blocked" for row in batches) != 6:
    raise SystemExit("v61ga expected all minimum batches blocked")
if not any(row["batch_id"] == "02-v53-review-row-payloads" and row["payload_rows_required"] == "8231" for row in batches):
    raise SystemExit("v61ga missing v53 row payload batch")
if not any(row["batch_id"] == "04-v61-generation-result-rows" and row["payload_rows_required"] == "1000" for row in batches):
    raise SystemExit("v61ga missing v61 generation result row batch")

commands = read_csv(run_dir / "generation_unblock_runway_replay_command_rows.csv")
if len(commands) != 5:
    raise SystemExit("v61ga expected five replay commands")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 2:
    raise SystemExit("v61ga expected two ready replay commands")
if sum(row["ready_to_run_now"] == "0" for row in commands) != 3:
    raise SystemExit("v61ga expected three blocked replay commands")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] and row["ready_to_run_now"] == "0" for row in commands):
    raise SystemExit("v61ga must keep root-pinned replay blocked")

deltas = read_csv(run_dir / "generation_unblock_runway_delta_focus_rows.csv")
if len(deltas) != 14:
    raise SystemExit("v61ga expected 14 delta focus rows")
if sum(row["status"] == "open" for row in deltas) != 14:
    raise SystemExit("v61ga expected all delta focus rows open")

metrics = read_csv(run_dir / "generation_unblock_runway_metric_rows.csv")
if len(metrics) != 1:
    raise SystemExit("v61ga expected one metric row")
metric = metrics[0]
if metric["actual_model_generation_ready"] != "0":
    raise SystemExit("v61ga metric must keep actual generation blocked")
if metric["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61ga metric must keep repo checkpoint payload zero")

sources = read_csv(run_dir / "generation_unblock_runway_source_rows.csv")
if len(sources) != 9:
    raise SystemExit("v61ga expected nine source rows")
if any(row["metadata_only"] != "1" for row in sources):
    raise SystemExit("v61ga source rows must be metadata-only")

package_rows = read_csv(run_dir / "generation_unblock_runway_package_file_rows.csv")
if len(package_rows) != 9:
    raise SystemExit("v61ga expected nine package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61ga package rows must be metadata-only and non-payload")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fz-status-refresh",
    "v53ao-frontier-receipt",
    "real-model-runtime-evidence",
    "zero-repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ga expected pass decision: {gate}")
for gate in [
    "dual-real-return-roots",
    "human-review-return",
    "generation-result-return",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ga expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61ga_post_fz_generation_unblock_runway_manifest.json").read_text(encoding="utf-8"))
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ga manifest must keep repo checkpoint payload zero")
if manifest.get("summary", {}).get("actual_model_generation_ready") != "0":
    raise SystemExit("v61ga manifest must keep actual generation blocked")

package_manifest = json.loads((package_dir / "GENERATION_UNBLOCK_RUNWAY_MANIFEST.json").read_text(encoding="utf-8"))
if package_manifest.get("requirement_rows") != 18:
    raise SystemExit("v61ga package manifest requirement mismatch")
if package_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ga package manifest must keep actual generation blocked")

boundary = (run_dir / "V61GA_POST_FZ_GENERATION_UNBLOCK_RUNWAY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61ga_post_fz_generation_unblock_runway_ready=1",
    "v61fz_post_fy_active_goal_status_refresh_ready=1",
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready=1",
    "v52_ready=1",
    "v53_machine_complete_source_surface_ready=1",
    "post_full_shard_runtime_evidence_ready=1",
    "full_checkpoint_materialization_ready=1",
    "full_safetensors_page_hash_binding_ready=1",
    "runtime_admission_accepted_rows=1000",
    "root_pinned_replay_script_ready=1",
    "successful_v53ao_ready_action_rows=2",
    "blocked_v53ao_action_rows=4",
    "missing_external_return_artifacts=91",
    "missing_human_review_rows=7000",
    "missing_adjudication_rows=1000",
    "missing_generation_result_artifacts=5",
    "missing_generation_result_rows=1000",
    "runway_requirement_rows=18",
    "ready_runway_requirement_rows=5",
    "blocked_runway_requirement_rows=13",
    "minimum_batch_rows=6",
    "blocked_minimum_batch_rows=6",
    "ready_replay_command_rows=2",
    "blocked_replay_command_rows=3",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ga boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel, recorded in sha_rows.items():
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"v61ga sha manifest references missing file: {rel}")
    if sha256(path) != recorded:
        raise SystemExit(f"v61ga sha mismatch: {rel}")

if any(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"} for path in run_dir.rglob("*") if path.is_file()):
    raise SystemExit("v61ga must not emit payload-like files")

print("v61ga post-fz generation unblock runway smoke passed")
PY
