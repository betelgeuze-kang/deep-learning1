#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cy_runtime_admission_chunk_execution_queue"
RUN_DIR="$RESULTS_DIR/$PREFIX/queue_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CY_REUSE_EXISTING="${V61CY_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cy_runtime_admission_chunk_execution_queue.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_RUNTIME_ADMISSION_CHUNK_QUEUE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61cy_runtime_admission_chunk_execution_queue_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    "runtime_admission_expansion_rows": "1000",
    "runtime_admission_chunk_size": "50",
    "runtime_admission_chunk_rows": "20",
    "runtime_admission_chunk_manifest_rows": "1000",
    "runtime_admission_chunk_return_artifact_rows": "81",
    "runtime_admission_aggregate_return_artifact_rows": "5",
    "runtime_admission_chunk_operator_command_rows": "4",
    "ready_runtime_admission_chunk_dispatch_rows": "20",
    "completed_runtime_admission_chunk_rows": "0",
    "accepted_runtime_admission_chunk_return_rows": "0",
    "ready_operator_command_rows": "2",
    "full_shard_prerequisites_closed": "1",
    "guarded_runtime_admission_command_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "chunk_dispatch_ready": "1",
    "chunk_merge_ready": "0",
    "aggregate_runtime_return_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cy": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cy summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "runtime_admission_execution_chunk_rows.csv",
    "runtime_admission_chunk_manifest_rows.csv",
    "runtime_admission_chunk_return_artifact_rows.csv",
    "runtime_admission_aggregate_return_artifact_rows.csv",
    "runtime_admission_chunk_operator_command_rows.csv",
    "runtime_admission_chunk_execution_metric_rows.csv",
    "V61CY_RUNTIME_ADMISSION_CHUNK_EXECUTION_QUEUE_BOUNDARY.md",
    "v61cy_runtime_admission_chunk_execution_queue_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/RUNTIME_ADMISSION_CHUNK_ENV.template",
    "operator_bundle/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv",
    "operator_bundle/VERIFY_RUNTIME_ADMISSION_CHUNK_QUEUE.sh",
    "operator_bundle/MERGE_RUNTIME_ADMISSION_CHUNKS.sh",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cv/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "source_v61cx/post_full_shard_generation_next_action_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cy artifact: {rel}")

chunk_rows = read_csv(run_dir / "runtime_admission_execution_chunk_rows.csv")
manifest_rows = read_csv(run_dir / "runtime_admission_chunk_manifest_rows.csv")
chunk_artifacts = read_csv(run_dir / "runtime_admission_chunk_return_artifact_rows.csv")
aggregate_rows = read_csv(run_dir / "runtime_admission_aggregate_return_artifact_rows.csv")
command_rows = read_csv(run_dir / "runtime_admission_chunk_operator_command_rows.csv")
metric_rows = read_csv(run_dir / "runtime_admission_chunk_execution_metric_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(chunk_rows) != 20:
    raise SystemExit("v61cy expected 20 chunk rows")
if len(manifest_rows) != 1000:
    raise SystemExit("v61cy expected 1000 manifest rows")
if len(chunk_artifacts) != 81:
    raise SystemExit("v61cy expected 81 chunk artifact rows")
if len(aggregate_rows) != 5:
    raise SystemExit("v61cy expected five aggregate return rows")
if len(command_rows) != 4 or len(metric_rows) != 1:
    raise SystemExit("v61cy expected four commands and one metric row")
if any(row["chunk_dispatch_ready"] != "1" for row in chunk_rows):
    raise SystemExit("v61cy all chunks should be dispatch-ready")
if any(row["chunk_execution_completed"] != "0" for row in chunk_rows):
    raise SystemExit("v61cy chunks must not be marked executed")
if sum(1 for row in chunk_artifacts if row["artifact_scope"] == "global-once") != 1:
    raise SystemExit("v61cy expected one global identity artifact row")
if sum(1 for row in chunk_artifacts if row["artifact_scope"] == "per-query-chunk") != 80:
    raise SystemExit("v61cy expected 80 per-query chunk artifact rows")

for gate in [
    "runtime-admission-expansion-input",
    "runtime-admission-operator-input",
    "post-full-shard-closure-input",
    "runtime-admission-chunk-dispatch",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cy expected {gate} pass, got {decisions.get(gate)!r}")
for gate in [
    "runtime-admission-chunk-return",
    "runtime-admission-aggregate-return",
    "complete-source-runtime-admission-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cy expected {gate} blocked, got {decisions.get(gate)!r}")

boundary = (run_dir / "V61CY_RUNTIME_ADMISSION_CHUNK_EXECUTION_QUEUE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_expansion_rows=1000",
    "runtime_admission_chunk_size=50",
    "runtime_admission_chunk_rows=20",
    "runtime_admission_chunk_manifest_rows=1000",
    "runtime_admission_chunk_return_artifact_rows=81",
    "runtime_admission_aggregate_return_artifact_rows=5",
    "ready_runtime_admission_chunk_dispatch_rows=20",
    "completed_runtime_admission_chunk_rows=0",
    "accepted_runtime_admission_chunk_return_rows=0",
    "full_shard_prerequisites_closed=1",
    "guarded_runtime_admission_command_ready=1",
    "runtime_admission_accepted_rows=0",
    "complete_source_runtime_admission_execution_ready=0",
    "chunk_dispatch_ready=1",
    "chunk_merge_ready=0",
    "aggregate_runtime_return_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cy=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cy boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cy_runtime_admission_chunk_execution_queue_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cy_runtime_admission_chunk_execution_queue_ready") != 1:
    raise SystemExit("v61cy manifest readiness mismatch")
if manifest.get("runtime_admission_chunk_rows") != 20:
    raise SystemExit("v61cy manifest chunk row mismatch")
if manifest.get("chunk_dispatch_ready") != 1:
    raise SystemExit("v61cy manifest should mark chunk dispatch ready")
if manifest.get("complete_source_runtime_admission_execution_ready") != 0:
    raise SystemExit("v61cy manifest must keep runtime admission blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cy manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cy manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cy produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cy runtime admission chunk execution queue smoke passed"
