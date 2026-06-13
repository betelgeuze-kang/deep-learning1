#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ds_schema_preflight_acceptance_handoff_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/handoff_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DS_REUSE_EXISTING="${V61DS_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ds_schema_preflight_acceptance_handoff_gate.sh" >/dev/null

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
    "v61ds_schema_preflight_acceptance_handoff_gate_ready": "1",
    "v61dr_return_bundle_schema_preflight_gate_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "source_gate_rows": "2",
    "handoff_stage_rows": "12",
    "ready_handoff_stage_rows": "2",
    "blocked_handoff_stage_rows": "10",
    "handoff_command_rows": "12",
    "ready_handoff_command_rows": "4",
    "return_bundle_dir_supplied": "0",
    "schema_preflight_artifact_rows": "81",
    "schema_preflight_pass_rows": "0",
    "schema_preflight_pass": "0",
    "schema_family_ready_rows": "0",
    "expected_schema_artifact_rows": "81",
    "expected_artifact_row_instances": "20485",
    "observed_artifact_row_instances": "0",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "accepted_dispatch_receipt_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "answer_review_accepted_rows": "0",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "schema_acceptance_ready": "0",
    "return_acceptance_replay_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ds": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ds {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "schema_preflight_acceptance_handoff_stage_rows.csv",
    "schema_preflight_acceptance_family_handoff_rows.csv",
    "schema_preflight_acceptance_handoff_command_rows.csv",
    "schema_preflight_acceptance_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DS_SCHEMA_PREFLIGHT_ACCEPTANCE_HANDOFF_GATE_BOUNDARY.md",
    "v61ds_schema_preflight_acceptance_handoff_gate_manifest.json",
    "source_v61dr/v61dr_return_bundle_schema_preflight_gate_summary.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ds artifact: {rel}")

stage_rows = read_csv(run_dir / "schema_preflight_acceptance_handoff_stage_rows.csv")
family_rows = {row["schema_family"]: row for row in read_csv(run_dir / "schema_preflight_acceptance_family_handoff_rows.csv")}
command_rows = read_csv(run_dir / "schema_preflight_acceptance_handoff_command_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 12:
    raise SystemExit("v61ds expected 12 handoff stages")
ready_stages = [row["handoff_stage_id"] for row in stage_rows if row["status"] == "ready"]
if ready_stages != ["01-schema-preflight-surface", "08-full-shard-runtime-closed"]:
    raise SystemExit(f"v61ds ready stage mismatch: {ready_stages}")
if set(family_rows) != {"dispatch-receipt-json", "review-chunk-return-csv", "aggregate-review-return", "generation-result-return"}:
    raise SystemExit("v61ds family set mismatch")
if [row["ready_to_run_now"] for row in command_rows[:4]] != ["1", "1", "1", "0"]:
    raise SystemExit("v61ds command readiness prefix mismatch")
if decisions.get("schema-to-acceptance-boundary") != "pass":
    raise SystemExit("v61ds schema-to-acceptance boundary should pass")
for gate in ["03-schema-preflight-pass", "06-aggregate-review-accepted", "12-actual-generation-ready", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ds expected blocked gate: {gate}")

boundary = (run_dir / "V61DS_SCHEMA_PREFLIGHT_ACCEPTANCE_HANDOFF_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "handoff_stage_rows=12",
    "ready_handoff_stage_rows=2",
    "schema_preflight_pass_rows=0/81",
    "expected_payload_rows=17483",
    "accepted_payload_rows=0",
    "schema_acceptance_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ds boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ds_schema_preflight_acceptance_handoff_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("ready_handoff_stage_rows") != 2:
    raise SystemExit("v61ds manifest ready stage mismatch")
if manifest.get("accepted_payload_rows") != 0:
    raise SystemExit("v61ds manifest must not accept payload rows")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ds manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ds sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ds produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ds schema preflight acceptance handoff gate smoke passed"
