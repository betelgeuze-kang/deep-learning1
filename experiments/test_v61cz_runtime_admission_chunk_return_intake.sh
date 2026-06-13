#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cz_runtime_admission_chunk_return_intake"
RUN_DIR="$RESULTS_DIR/$PREFIX/intake_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61CZ_REUSE_EXISTING="${V61CZ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61cz_runtime_admission_chunk_return_intake.sh" >/dev/null

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
    "v61cz_runtime_admission_chunk_return_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cy_runtime_admission_chunk_execution_queue_ready": "1",
    "runtime_admission_chunk_rows": "20",
    "runtime_admission_chunk_manifest_rows": "1000",
    "runtime_admission_chunk_return_artifact_rows": "81",
    "runtime_admission_aggregate_return_artifact_rows": "5",
    "chunk_return_dir_supplied": "0",
    "chunk_return_dir_exists": "0",
    "supplied_chunk_return_artifacts": "0",
    "accepted_chunk_return_artifacts": "0",
    "missing_chunk_return_artifacts": "81",
    "invalid_chunk_return_artifacts": "0",
    "accepted_chunk_return_rows": "0",
    "accepted_runtime_admission_chunk_rows": "0",
    "missing_runtime_admission_chunk_rows": "20",
    "global_runtime_identity_return_ready": "0",
    "aggregate_runtime_return_merge_ready_rows": "0",
    "aggregate_runtime_return_merge_ready": "0",
    "runtime_admission_accepted_rows": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61cz summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "runtime_admission_chunk_return_artifact_status_rows.csv",
    "runtime_admission_chunk_return_status_rows.csv",
    "runtime_admission_aggregate_return_merge_rows.csv",
    "runtime_admission_chunk_return_requirement_rows.csv",
    "runtime_admission_chunk_return_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_INTAKE_BOUNDARY.md",
    "v61cz_runtime_admission_chunk_return_intake_manifest.json",
    "source_v61cy/runtime_admission_execution_chunk_rows.csv",
    "source_v61cy/runtime_admission_chunk_manifest_rows.csv",
    "source_v61cy/runtime_admission_chunk_return_artifact_rows.csv",
    "source_v61cy/runtime_admission_aggregate_return_artifact_rows.csv",
    "source_v61cy/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cz artifact: {rel}")

artifact_rows = read_csv(run_dir / "runtime_admission_chunk_return_artifact_status_rows.csv")
chunk_rows = read_csv(run_dir / "runtime_admission_chunk_return_status_rows.csv")
aggregate_rows = read_csv(run_dir / "runtime_admission_aggregate_return_merge_rows.csv")
requirement_rows = {row["requirement_id"]: row for row in read_csv(run_dir / "runtime_admission_chunk_return_requirement_rows.csv")}
metric_rows = read_csv(run_dir / "runtime_admission_chunk_return_metric_rows.csv")
decision_rows = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(artifact_rows) != 81:
    raise SystemExit("v61cz expected 81 artifact status rows")
if len(chunk_rows) != 20:
    raise SystemExit("v61cz expected 20 chunk status rows")
if len(aggregate_rows) != 5:
    raise SystemExit("v61cz expected five aggregate merge rows")
if len(metric_rows) != 1:
    raise SystemExit("v61cz expected one metric row")
if any(row["current_status"] != "missing" for row in artifact_rows):
    raise SystemExit("v61cz default artifact statuses must be missing")
if any(row["chunk_return_ready"] != "0" for row in chunk_rows):
    raise SystemExit("v61cz default chunk returns must not be ready")
if any(row["merge_ready"] != "0" for row in aggregate_rows):
    raise SystemExit("v61cz default aggregate merge must not be ready")

for requirement_id in [
    "v61cy-runtime-admission-chunk-queue-input",
    "manifest-only-no-repo-payload",
]:
    if requirement_rows[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cz requirement should pass: {requirement_id}")
for requirement_id in [
    "chunk-return-directory-supplied",
    "chunk-return-directory-exists",
    "chunk-return-artifacts",
    "runtime-admission-chunk-returns",
    "global-runtime-identity-return",
    "aggregate-runtime-return-merge",
]:
    if requirement_rows[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cz requirement should stay blocked: {requirement_id}")

for gate in [
    "runtime-admission-chunk-queue-input",
    "manifest-only-no-repo-payload",
]:
    if decision_rows.get(gate) != "pass":
        raise SystemExit(f"v61cz gate should pass: {gate}")
for gate in [
    "chunk-return-directory",
    "chunk-return-artifacts",
    "runtime-admission-chunk-returns",
    "aggregate-runtime-return-merge",
    "complete-source-runtime-admission-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decision_rows.get(gate) != "blocked":
        raise SystemExit(f"v61cz gate should stay blocked: {gate}")

boundary = (run_dir / "V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_chunk_rows=20",
    "runtime_admission_chunk_manifest_rows=1000",
    "runtime_admission_chunk_return_artifact_rows=81",
    "runtime_admission_aggregate_return_artifact_rows=5",
    "chunk_return_dir_supplied=0",
    "chunk_return_dir_exists=0",
    "supplied_chunk_return_artifacts=0",
    "accepted_chunk_return_artifacts=0",
    "missing_chunk_return_artifacts=81",
    "invalid_chunk_return_artifacts=0",
    "accepted_runtime_admission_chunk_rows=0",
    "missing_runtime_admission_chunk_rows=20",
    "global_runtime_identity_return_ready=0",
    "aggregate_runtime_return_merge_ready_rows=0",
    "aggregate_runtime_return_merge_ready=0",
    "runtime_admission_accepted_rows=0",
    "complete_source_runtime_admission_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cz=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cz boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cz_runtime_admission_chunk_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cz_runtime_admission_chunk_return_intake_ready") != 1:
    raise SystemExit("v61cz manifest readiness mismatch")
if manifest.get("accepted_chunk_return_artifacts") != 0:
    raise SystemExit("v61cz manifest must keep accepted artifacts at zero")
if manifest.get("aggregate_runtime_return_merge_ready") != 0:
    raise SystemExit("v61cz manifest must keep merge blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cz manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cz manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cz produced checkpoint payload files" >&2
  exit 1
fi

echo "v61cz runtime admission chunk return intake smoke passed"
