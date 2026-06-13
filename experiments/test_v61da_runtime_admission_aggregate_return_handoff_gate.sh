#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61da_runtime_admission_aggregate_return_handoff_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DA_REUSE_EXISTING="${V61DA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61da_runtime_admission_aggregate_return_handoff_gate.sh" >/dev/null

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
    "v61da_runtime_admission_aggregate_return_handoff_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cz_runtime_admission_chunk_return_intake_ready": "1",
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "runtime_admission_chunk_rows": "20",
    "accepted_runtime_admission_chunk_rows": "0",
    "runtime_admission_aggregate_return_artifact_rows": "5",
    "aggregate_runtime_return_merge_ready_rows": "0",
    "aggregate_runtime_return_merge_ready": "0",
    "handoff_artifact_rows": "5",
    "handoff_ready_rows": "0",
    "aggregate_runtime_return_handoff_ready": "0",
    "handoff_command_rows": "4",
    "ready_handoff_command_rows": "1",
    "handoff_file_rows": "4",
    "runtime_admission_accepted_rows": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61da": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61da summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "runtime_admission_aggregate_return_handoff_rows.csv",
    "runtime_admission_aggregate_return_handoff_command_rows.csv",
    "runtime_admission_aggregate_return_handoff_file_rows.csv",
    "runtime_admission_aggregate_return_handoff_metric_rows.csv",
    "V61DA_RUNTIME_ADMISSION_AGGREGATE_RETURN_HANDOFF_GATE_BOUNDARY.md",
    "v61da_runtime_admission_aggregate_return_handoff_gate_manifest.json",
    "aggregate_return_handoff/README.md",
    "aggregate_return_handoff/RUNTIME_ADMISSION_RETURN_ENV.template",
    "aggregate_return_handoff/EXPECTED_RUNTIME_ADMISSION_RETURN_FILES.csv",
    "aggregate_return_handoff/VERIFY_AGGREGATE_RUNTIME_RETURN.sh",
    "source_v61cz/runtime_admission_aggregate_return_merge_rows.csv",
    "source_v61cr/complete_source_runtime_admission_return_template_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61da artifact: {rel}")

handoff_rows = read_csv(run_dir / "runtime_admission_aggregate_return_handoff_rows.csv")
command_rows = read_csv(run_dir / "runtime_admission_aggregate_return_handoff_command_rows.csv")
file_rows = read_csv(run_dir / "runtime_admission_aggregate_return_handoff_file_rows.csv")
metric_rows = read_csv(run_dir / "runtime_admission_aggregate_return_handoff_metric_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(handoff_rows) != 5:
    raise SystemExit("v61da expected five handoff rows")
if len(command_rows) != 4:
    raise SystemExit("v61da expected four command rows")
if len(file_rows) != 4:
    raise SystemExit("v61da expected four file rows")
if len(metric_rows) != 1:
    raise SystemExit("v61da expected one metric row")
if any(row["handoff_ready"] != "0" for row in handoff_rows):
    raise SystemExit("v61da default handoff rows must stay blocked")
if sum(1 for row in command_rows if row["ready_to_run_now"] == "1") != 1:
    raise SystemExit("v61da should expose one ready verifier command by default")

for gate in [
    "runtime-admission-chunk-return-input",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61da expected {gate} pass, got {decisions.get(gate)!r}")
for gate in [
    "aggregate-runtime-return-merge",
    "aggregate-runtime-return-handoff",
    "complete-source-runtime-admission-acceptance",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61da expected {gate} blocked, got {decisions.get(gate)!r}")

boundary = (run_dir / "V61DA_RUNTIME_ADMISSION_AGGREGATE_RETURN_HANDOFF_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_chunk_rows=20",
    "accepted_runtime_admission_chunk_rows=0",
    "runtime_admission_aggregate_return_artifact_rows=5",
    "aggregate_runtime_return_merge_ready_rows=0",
    "aggregate_runtime_return_merge_ready=0",
    "handoff_artifact_rows=5",
    "handoff_ready_rows=0",
    "aggregate_runtime_return_handoff_ready=0",
    "handoff_command_rows=4",
    "ready_handoff_command_rows=1",
    "runtime_admission_accepted_rows=0",
    "complete_source_runtime_admission_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61da=0",
    "wording: completed runtime admission",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61da boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61da_runtime_admission_aggregate_return_handoff_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61da_runtime_admission_aggregate_return_handoff_gate_ready") != 1:
    raise SystemExit("v61da manifest readiness mismatch")
if manifest.get("aggregate_runtime_return_handoff_ready") != 0:
    raise SystemExit("v61da manifest must keep handoff blocked")
if manifest.get("complete_source_runtime_admission_execution_ready") != 0:
    raise SystemExit("v61da manifest must keep runtime admission blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61da manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61da manifest must keep repo payload bytes at zero")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61da produced checkpoint payload files" >&2
  exit 1
fi

echo "v61da runtime admission aggregate return handoff gate smoke passed"
