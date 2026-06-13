#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61db_runtime_admission_acceptance_refresh_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DB_REUSE_EXISTING="${V61DB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61db_runtime_admission_acceptance_refresh_gate.sh" >/dev/null

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
    "v61db_runtime_admission_acceptance_refresh_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61da_runtime_admission_aggregate_return_handoff_gate_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "refresh_stage_rows": "4",
    "ready_refresh_stage_rows": "2",
    "blocked_refresh_stage_rows": "2",
    "refresh_command_rows": "4",
    "ready_refresh_command_rows": "3",
    "handoff_artifact_rows": "5",
    "handoff_ready_rows": "0",
    "aggregate_runtime_return_handoff_ready": "0",
    "expected_runtime_admission_return_artifacts": "5",
    "accepted_runtime_admission_return_artifacts": "5",
    "runtime_admission_return_artifact_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "complete_source_runtime_admission_execution_ready": "1",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "runtime_admission_blocked_generation_rows": "0",
    "generation_execution_admission_ready": "0",
    "runtime_admission_acceptance_refresh_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61db": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61db summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "runtime_admission_acceptance_refresh_stage_rows.csv",
    "runtime_admission_acceptance_refresh_command_rows.csv",
    "runtime_admission_acceptance_refresh_metric_rows.csv",
    "V61DB_RUNTIME_ADMISSION_ACCEPTANCE_REFRESH_GATE_BOUNDARY.md",
    "v61db_runtime_admission_acceptance_refresh_gate_manifest.json",
    "source_v61da/runtime_admission_aggregate_return_handoff_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "source_v61cs/complete_source_generation_execution_admission_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61db artifact: {rel}")

stage_rows = read_csv(run_dir / "runtime_admission_acceptance_refresh_stage_rows.csv")
command_rows = read_csv(run_dir / "runtime_admission_acceptance_refresh_command_rows.csv")
metric_rows = read_csv(run_dir / "runtime_admission_acceptance_refresh_metric_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 4:
    raise SystemExit("v61db expected four refresh stage rows")
if len(command_rows) != 4:
    raise SystemExit("v61db expected four refresh command rows")
if len(metric_rows) != 1:
    raise SystemExit("v61db expected one metric row")
if sum(1 for row in stage_rows if row["current_ready"] == "1") != 2:
    raise SystemExit("v61db should mark v61cr/v61cw refresh stages ready")
if sum(1 for row in stage_rows if row["current_ready"] == "0") != 2:
    raise SystemExit("v61db should keep handoff and generation admission stages blocked")
if sum(1 for row in command_rows if row["ready_to_run_now"] == "1") != 3:
    raise SystemExit("v61db should expose three ready commands after v61dc")

for gate in [
    "manifest-only-no-repo-payload",
    "v61cr-aggregate-runtime-return-intake",
    "v61cw-per-query-runtime-acceptance",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61db expected {gate} pass, got {decisions.get(gate)!r}")
for gate in [
    "aggregate-runtime-return-handoff",
    "v61cs-generation-admission-refresh",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61db expected {gate} blocked, got {decisions.get(gate)!r}")

boundary = (run_dir / "V61DB_RUNTIME_ADMISSION_ACCEPTANCE_REFRESH_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "refresh_stage_rows=4",
    "ready_refresh_stage_rows=2",
    "blocked_refresh_stage_rows=2",
    "refresh_command_rows=4",
    "ready_refresh_command_rows=3",
    "handoff_artifact_rows=5",
    "handoff_ready_rows=0",
    "aggregate_runtime_return_handoff_ready=0",
    "expected_runtime_admission_return_artifacts=5",
    "accepted_runtime_admission_return_artifacts=5",
    "runtime_admission_return_artifact_ready=1",
    "runtime_admission_acceptance_rows=1000",
    "runtime_admission_accepted_rows=1000",
    "complete_source_runtime_admission_execution_ready=1",
    "generation_execution_admission_rows=1000",
    "generation_execution_admitted_rows=0",
    "runtime_admission_blocked_generation_rows=0",
    "generation_execution_admission_ready=0",
    "runtime_admission_acceptance_refresh_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61db=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61db boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61db_runtime_admission_acceptance_refresh_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61db_runtime_admission_acceptance_refresh_gate_ready") != 1:
    raise SystemExit("v61db manifest readiness mismatch")
if manifest.get("runtime_admission_acceptance_refresh_ready") != 0:
    raise SystemExit("v61db manifest must keep runtime refresh blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61db manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61db manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61db produced checkpoint payload files" >&2
  exit 1
fi

echo "v61db runtime admission acceptance refresh gate smoke passed"
