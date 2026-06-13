#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ae_complete_source_review_return_generation_rendezvous_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AE_REUSE_EXISTING="${V53AE_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": "1",
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": "1",
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    "dispatch_receipt_dir_supplied": "0",
    "dispatch_receipt_dir_exists": "0",
    "review_chunk_return_dir_supplied": "0",
    "review_chunk_return_dir_exists": "0",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "generation_result_dir_supplied": "0",
    "generation_result_dir_exists": "0",
    "rendezvous_stage_rows": "9",
    "ready_rendezvous_stage_rows": "3",
    "blocked_rendezvous_stage_rows": "6",
    "next_action_rows": "5",
    "ready_next_action_rows": "2",
    "rendezvous_command_rows": "5",
    "ready_rendezvous_command_rows": "1",
    "dispatch_receipt_template_rows": "21",
    "accepted_dispatch_receipt_rows": "0",
    "review_chunk_rows": "21",
    "ready_review_chunk_dispatch_rows": "21",
    "review_chunk_return_artifact_rows": "50",
    "accepted_chunk_return_artifact_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "review_return_ready": "0",
    "v53_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "full_checkpoint_materialization_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "complete_source_runtime_admission_execution_ready": "1",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ae": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ae {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_generation_rendezvous_stage_rows.csv",
    "review_return_generation_next_action_rows.csv",
    "review_return_generation_rendezvous_command_rows.csv",
    "review_return_generation_rendezvous_requirement_rows.csv",
    "review_return_generation_rendezvous_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AE_COMPLETE_SOURCE_REVIEW_RETURN_GENERATION_RENDEZVOUS_GATE_BOUNDARY.md",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_manifest.json",
    "source_v53ad/complete_source_review_dispatch_receipt_status_rows.csv",
    "source_v53z/review_return_v61_handoff_stage_rows.csv",
    "source_v61de/post_review_generation_result_handoff_stage_rows.csv",
    "source_v61cx/post_full_shard_generation_closure_queue_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ae artifact: {rel}")

stage_rows = read_csv(run_dir / "review_return_generation_rendezvous_stage_rows.csv")
next_action_rows = read_csv(run_dir / "review_return_generation_next_action_rows.csv")
command_rows = read_csv(run_dir / "review_return_generation_rendezvous_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_generation_rendezvous_requirement_rows.csv")}
metric = read_csv(run_dir / "review_return_generation_rendezvous_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(stage_rows) != 9:
    raise SystemExit("v53ae expected nine rendezvous stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "blocked", "ready", "blocked", "blocked", "ready", "blocked", "blocked", "blocked"]:
    raise SystemExit("v53ae stage status sequence mismatch")
if len(next_action_rows) != 5:
    raise SystemExit("v53ae expected five next action rows")
if [row["action_status"] for row in next_action_rows] != ["ready", "ready", "blocked", "blocked", "blocked"]:
    raise SystemExit("v53ae next action status sequence mismatch")
if len(command_rows) != 5:
    raise SystemExit("v53ae expected five command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "0", "0", "0", "0"]:
    raise SystemExit("v53ae command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53ae_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ae metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "dispatch-archive-surface",
    "review-chunk-dispatch-surface",
    "full-shard-runtime-closed",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ae requirement should pass: {requirement_id}")
for requirement_id in [
    "dispatch-receipt-trace",
    "review-chunk-return-accepted",
    "aggregate-review-return-accepted",
    "v61-generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ae requirement should stay blocked: {requirement_id}")

for gate in [
    "dispatch-archive-surface",
    "review-chunk-dispatch-surface",
    "full-shard-runtime-closed",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ae decision should pass: {gate}")
for gate in [
    "dispatch-receipt-trace",
    "review-chunk-return-accepted",
    "aggregate-review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ae decision should stay blocked: {gate}")

for gap in ["dispatch-archive-surface", "full-shard-runtime"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v53ae gap should be ready: {gap}")
for gap in [
    "dispatch-receipt-trace",
    "review-chunk-return",
    "aggregate-review-return",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ae gap should stay blocked: {gap}")

boundary = (run_dir / "V53AE_COMPLETE_SOURCE_REVIEW_RETURN_GENERATION_RENDEZVOUS_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "rendezvous_stage_rows=9",
    "ready_rendezvous_stage_rows=3",
    "blocked_rendezvous_stage_rows=6",
    "next_action_rows=5",
    "ready_next_action_rows=2",
    "dispatch_receipt_template_rows=21",
    "accepted_dispatch_receipt_rows=0",
    "review_chunk_rows=21",
    "accepted_chunk_return_artifact_rows=0",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "expected_adjudication_rows=1000",
    "accepted_adjudication_rows=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "generation_result_accepted_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v53ae=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ae boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ae_complete_source_review_return_generation_rendezvous_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ae_complete_source_review_return_generation_rendezvous_gate_ready") != 1:
    raise SystemExit("v53ae manifest readiness mismatch")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v53ae manifest full-shard closure mismatch")
if manifest.get("answer_review_accepted_rows") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ae manifest must keep review/generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53ae manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ae sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ae produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ae complete-source review return generation rendezvous gate smoke passed"
