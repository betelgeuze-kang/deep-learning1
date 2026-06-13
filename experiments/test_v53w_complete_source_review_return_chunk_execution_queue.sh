#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53w_complete_source_review_return_chunk_execution_queue/queue_001"
SUMMARY_CSV="$RESULTS_DIR/v53w_complete_source_review_return_chunk_execution_queue_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53w_complete_source_review_return_chunk_execution_queue_decision.csv"

V53W_REUSE_EXISTING="${V53W_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_CHUNK_QUEUE.sh" >/dev/null

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
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    "review_chunk_rows": "21",
    "ready_review_chunk_dispatch_rows": "21",
    "review_chunk_task_rows": "8000",
    "human_review_chunk_task_rows": "7000",
    "adjudication_chunk_task_rows": "1000",
    "review_chunk_return_artifact_rows": "50",
    "human_review_chunk_artifact_rows": "7",
    "adjudication_chunk_artifact_rows": "1",
    "reviewer_identity_chunk_artifact_rows": "21",
    "reviewer_conflict_chunk_artifact_rows": "21",
    "aggregate_review_return_artifact_rows": "5",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "answer_review_accepted_rows": "0",
    "chunk_dispatch_ready": "1",
    "chunk_return_intake_ready": "0",
    "aggregate_review_return_ready": "0",
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53w {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_chunk_execution_rows.csv",
    "review_return_chunk_task_rows.csv",
    "review_return_chunk_artifact_rows.csv",
    "review_return_aggregate_artifact_rows.csv",
    "review_return_chunk_command_rows.csv",
    "review_return_chunk_requirement_rows.csv",
    "review_return_chunk_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53W_COMPLETE_SOURCE_REVIEW_RETURN_CHUNK_EXECUTION_QUEUE_BOUNDARY.md",
    "v53w_complete_source_review_return_chunk_execution_queue_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_CHUNK_QUEUE.sh",
    "source_v53u/reviewer_workload_chunk_rows.csv",
    "source_v53v/complete_source_review_return_acceptance_rows.csv",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v53s/review_return_required_field_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53w artifact: {rel}")

chunk_rows = read_csv(run_dir / "review_return_chunk_execution_rows.csv")
task_rows = read_csv(run_dir / "review_return_chunk_task_rows.csv")
chunk_artifacts = read_csv(run_dir / "review_return_chunk_artifact_rows.csv")
aggregate_artifacts = read_csv(run_dir / "review_return_aggregate_artifact_rows.csv")
commands = read_csv(run_dir / "review_return_chunk_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "review_return_chunk_requirement_rows.csv")}
metric = read_csv(run_dir / "review_return_chunk_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(chunk_rows) != 21:
    raise SystemExit("v53w chunk row count mismatch")
if len(task_rows) != 8000:
    raise SystemExit("v53w task row count mismatch")
if sum(row["task_type"] == "human-review" for row in task_rows) != 7000:
    raise SystemExit("v53w human review task count mismatch")
if sum(row["task_type"] == "adjudication" for row in task_rows) != 1000:
    raise SystemExit("v53w adjudication task count mismatch")
if len(chunk_artifacts) != 50:
    raise SystemExit("v53w chunk artifact count mismatch")
if len(aggregate_artifacts) != 5:
    raise SystemExit("v53w aggregate artifact count mismatch")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0"]:
    raise SystemExit("v53w command readiness mismatch")
if any(row["chunk_dispatch_ready"] != "1" for row in chunk_rows):
    raise SystemExit("v53w chunk dispatch should be ready")
if any(row["chunk_return_completed"] != "0" for row in chunk_rows):
    raise SystemExit("v53w chunk returns should not be completed by default")
if any(row["artifact_ready"] != "0" for row in chunk_artifacts):
    raise SystemExit("v53w chunk artifacts should not be accepted by default")
if any(row["aggregate_ready"] != "0" for row in aggregate_artifacts):
    raise SystemExit("v53w aggregate artifacts should not be accepted by default")

for field, value in expected.items():
    if field.startswith("v53w_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53w metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53u-operator-bundle-input",
    "v53v-acceptance-bridge-input",
    "review-chunk-dispatch-coverage",
    "chunk-return-artifact-surface",
    "aggregate-v53s-artifact-surface",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53w requirement should pass: {requirement_id}")
if requirements["actual-review-return"]["status"] != "blocked":
    raise SystemExit("v53w actual review return must stay blocked")

for gate in [
    "v53u-operator-bundle-input",
    "v53v-acceptance-bridge-input",
    "review-chunk-dispatch-coverage",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53w gate should pass: {gate}")
for gate in [
    "chunk-return-artifacts",
    "aggregate-review-return-artifacts",
    "answer-review-accepted",
    "v53-ready",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53w gate should stay blocked: {gate}")

if gaps.get("review-chunk-dispatch-coverage") != "ready":
    raise SystemExit("v53w dispatch gap should be ready")
for gap in [
    "chunk-return-artifacts",
    "aggregate-review-return-artifacts",
    "v53s-review-return-ready",
    "v53v-answer-review-accepted",
    "v53-ready",
    "v1.0-comparison-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53w gap should stay blocked: {gap}")

boundary = (run_dir / "V53W_COMPLETE_SOURCE_REVIEW_RETURN_CHUNK_EXECUTION_QUEUE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_chunk_rows=21",
    "ready_review_chunk_dispatch_rows=21",
    "review_chunk_task_rows=8000",
    "human_review_chunk_task_rows=7000",
    "adjudication_chunk_task_rows=1000",
    "review_chunk_return_artifact_rows=50",
    "aggregate_review_return_artifact_rows=5",
    "answer_review_accepted_rows=0",
    "chunk_dispatch_ready=1",
    "review_return_ready=0",
    "v53_ready=0",
    "v1_0_comparison_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53w boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53w_complete_source_review_return_chunk_execution_queue_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53w_complete_source_review_return_chunk_execution_queue_ready") != 1:
    raise SystemExit("v53w manifest readiness mismatch")
if manifest.get("review_chunk_rows") != 21:
    raise SystemExit("v53w manifest chunk count mismatch")
if manifest.get("review_chunk_task_rows") != 8000:
    raise SystemExit("v53w manifest task count mismatch")
if manifest.get("v53_ready") != 0 or manifest.get("v1_0_comparison_ready") != 0:
    raise SystemExit("v53w manifest should keep readiness blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53w sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53w produced checkpoint/model payload-like files" >&2
  exit 1
fi

echo "v53w complete-source review return chunk execution queue smoke passed"
