#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53z_complete_source_review_return_v61_handoff_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53Z_REUSE_EXISTING="${V53Z_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_REVIEW_RETURN_V61_HANDOFF.sh" >/dev/null

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
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "chunk_return_dir_supplied": "0",
    "chunk_return_dir_exists": "0",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "v53x_complete_source_review_chunk_return_intake_ready": "1",
    "v53y_complete_source_review_return_refresh_gate_ready": "1",
    "v61dd_review_return_generation_refresh_bridge_ready": "1",
    "handoff_stage_rows": "7",
    "ready_handoff_stage_rows": "3",
    "blocked_handoff_stage_rows": "4",
    "handoff_command_rows": "5",
    "ready_handoff_command_rows": "2",
    "machine_complete_source_surface_ready": "1",
    "review_chunk_rows": "21",
    "ready_review_chunk_dispatch_rows": "21",
    "review_chunk_task_rows": "8000",
    "review_chunk_return_artifact_rows": "50",
    "accepted_chunk_return_artifact_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "answer_review_accepted_rows": "0",
    "review_return_ready": "0",
    "v61_review_unblock_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "complete_source_runtime_admission_execution_ready": "1",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53z": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53z {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_v61_handoff_stage_rows.csv",
    "review_return_v61_handoff_command_rows.csv",
    "review_return_v61_handoff_requirement_rows.csv",
    "review_return_v61_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53Z_COMPLETE_SOURCE_REVIEW_RETURN_V61_HANDOFF_BRIDGE_BOUNDARY.md",
    "v53z_complete_source_review_return_v61_handoff_bridge_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_REVIEW_RETURN_V61_HANDOFF.sh",
    "source_v53w/review_return_chunk_execution_rows.csv",
    "source_v53w/review_return_chunk_artifact_rows.csv",
    "source_v53x/review_return_chunk_artifact_status_rows.csv",
    "source_v53x/review_return_aggregate_artifact_status_rows.csv",
    "source_v53y/complete_source_review_return_refresh_stage_rows.csv",
    "source_v61dd/review_return_generation_refresh_stage_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53z artifact: {rel}")

stage_rows = read_csv(run_dir / "review_return_v61_handoff_stage_rows.csv")
command_rows = read_csv(run_dir / "review_return_v61_handoff_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_v61_handoff_requirement_rows.csv")}
metric = read_csv(run_dir / "review_return_v61_handoff_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 7:
    raise SystemExit("v53z expected seven handoff stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "ready", "ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v53z stage status sequence mismatch")
if len(command_rows) != 5:
    raise SystemExit("v53z expected five handoff command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "0", "0", "0"]:
    raise SystemExit("v53z command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53z_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53z metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "machine-complete-source-surface",
    "review-chunk-dispatch-surface",
    "full-shard-runtime-prerequisites",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53z requirement should pass: {requirement_id}")
for requirement_id in [
    "review-chunk-return-directory",
    "review-chunk-return-accepted",
    "aggregate-review-return-directory",
    "aggregate-review-return-accepted",
    "v61-review-unblock",
    "actual-generation-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53z requirement should stay blocked: {requirement_id}")

for gate in [
    "machine-complete-source-surface",
    "review-chunk-dispatch-surface",
    "full-shard-runtime-prerequisites",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53z decision should pass: {gate}")
for gate in [
    "review-chunk-return-directory",
    "review-chunk-return-accepted",
    "aggregate-review-return-directory",
    "aggregate-review-return-accepted",
    "v61-review-unblock",
    "actual-model-generation",
    "v53-ready",
    "v1.0-comparison-ready",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53z decision should stay blocked: {gate}")

for gap in [
    "machine-complete-source-surface",
    "review-chunk-dispatch-surface",
    "full-shard-runtime-prerequisites",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v53z gap should be ready: {gap}")
for gap in [
    "review-chunk-return-directory",
    "review-chunk-return-accepted",
    "aggregate-review-return-directory",
    "aggregate-review-return-accepted",
    "v61-review-unblock",
    "actual-generation-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53z gap should stay blocked: {gap}")

boundary = (run_dir / "V53Z_COMPLETE_SOURCE_REVIEW_RETURN_V61_HANDOFF_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "chunk_return_dir_supplied=0",
    "review_return_dir_supplied=0",
    "handoff_stage_rows=7",
    "ready_handoff_stage_rows=3",
    "blocked_handoff_stage_rows=4",
    "ready_review_chunk_dispatch_rows=21",
    "accepted_chunk_return_artifact_rows=0",
    "accepted_aggregate_review_return_artifact_rows=0",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "v61_review_unblock_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0",
    "generation_result_accepted_rows=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53z boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53z_complete_source_review_return_v61_handoff_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53z_complete_source_review_return_v61_handoff_bridge_ready") != 1:
    raise SystemExit("v53z manifest readiness mismatch")
if manifest.get("ready_handoff_stage_rows") != 3 or manifest.get("blocked_handoff_stage_rows") != 4:
    raise SystemExit("v53z manifest stage count mismatch")
if manifest.get("answer_review_accepted_rows") != 0:
    raise SystemExit("v53z manifest must not invent review acceptance")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53z manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53z manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53z sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53z produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53z complete-source review return v61 handoff bridge smoke passed"
