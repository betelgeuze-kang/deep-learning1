#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61du_return_bundle_acceptance_delta_ledger"
RUN_DIR="$RESULTS_DIR/$PREFIX/delta_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DU_REUSE_EXISTING="${V61DU_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61du_return_bundle_acceptance_delta_ledger.sh" >/dev/null

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
    "v61du_return_bundle_acceptance_delta_ledger_ready": "1",
    "v61dt_return_bundle_closure_replay_gate_ready": "1",
    "source_gate_rows": "3",
    "delta_stage_rows": "15",
    "ready_delta_stage_rows": "4",
    "blocked_delta_stage_rows": "11",
    "closed_delta_stage_rows": "4",
    "open_delta_stage_rows": "11",
    "delta_family_rows": "10",
    "closed_delta_family_rows": "1",
    "open_delta_family_rows": "9",
    "delta_command_rows": "9",
    "ready_delta_command_rows": "4",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "schema_preflight_missing_artifact_rows": "81",
    "full_preflight_missing_artifact_rows": "81",
    "missing_payload_rows": "17483",
    "missing_dispatch_receipt_rows": "21",
    "missing_review_chunk_artifact_rows": "50",
    "missing_answer_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_generation_execution_rows": "1000",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "schema_acceptance_ready": "0",
    "return_acceptance_replay_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61du": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61du {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_bundle_acceptance_delta_stage_rows.csv",
    "return_bundle_acceptance_delta_family_rows.csv",
    "return_bundle_acceptance_delta_command_rows.csv",
    "return_bundle_acceptance_delta_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DU_RETURN_BUNDLE_ACCEPTANCE_DELTA_LEDGER_BOUNDARY.md",
    "v61du_return_bundle_acceptance_delta_ledger_manifest.json",
    "source_v61dt/v61dt_return_bundle_closure_replay_gate_summary.csv",
    "source_v61dr/return_bundle_schema_preflight_family_rows.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61du artifact: {rel}")

stage_rows = read_csv(run_dir / "return_bundle_acceptance_delta_stage_rows.csv")
family_rows = {row["delta_family"]: row for row in read_csv(run_dir / "return_bundle_acceptance_delta_family_rows.csv")}
command_rows = read_csv(run_dir / "return_bundle_acceptance_delta_command_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(stage_rows) != 15:
    raise SystemExit("v61du expected 15 delta stages")
closed_stage_ids = [row["closure_stage_id"] for row in stage_rows if row["delta_closed"] == "1"]
if closed_stage_ids != [
    "02-schema-preflight-surface",
    "04-schema-acceptance-handoff-audited",
    "05-acceptance-replay-surface",
    "11-full-shard-runtime-closed",
]:
    raise SystemExit(f"v61du closed stage mismatch: {closed_stage_ids}")
if set(family_rows) != {
    "bundle-logistics",
    "dispatch-receipt-json",
    "review-chunk-return-csv",
    "aggregate-review-return-artifacts",
    "aggregate-review-return-rows",
    "generation-result-return-artifacts",
    "generation-execution-admission",
    "generation-result-accepted-rows",
    "full-shard-runtime",
    "actual-generation",
}:
    raise SystemExit("v61du family set mismatch")
if family_rows["full-shard-runtime"]["delta_closed"] != "1":
    raise SystemExit("v61du full-shard runtime should be the only closed family")
if family_rows["aggregate-review-return-rows"]["missing_count"] != "8000":
    raise SystemExit("v61du aggregate review row delta mismatch")
if [row["ready_to_run_now"] for row in command_rows[:5]] != ["1", "1", "1", "1", "0"]:
    raise SystemExit("v61du command readiness prefix mismatch")

for gate in ["02-schema-preflight-surface", "04-schema-acceptance-handoff-audited", "05-acceptance-replay-surface", "11-full-shard-runtime-closed", "delta-ledger-ready", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61du expected pass gate: {gate}")
for gate in ["01-return-bundle-supplied", "03-schema-preflight-pass", "payload-acceptance", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61du expected blocked gate: {gate}")
if gaps.get("03-schema-preflight-pass") != "open":
    raise SystemExit("v61du schema preflight gap must stay open")

boundary = (run_dir / "V61DU_RETURN_BUNDLE_ACCEPTANCE_DELTA_LEDGER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "delta_stage_rows=15",
    "closed_delta_stage_rows=4",
    "open_delta_stage_rows=11",
    "schema_preflight_missing_artifact_rows=81",
    "full_preflight_missing_artifact_rows=81",
    "missing_payload_rows=17483",
    "missing_answer_review_rows=7000",
    "missing_adjudication_rows=1000",
    "missing_generation_execution_rows=1000",
    "missing_generation_result_rows=1000",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61du boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61du_return_bundle_acceptance_delta_ledger_manifest.json").read_text(encoding="utf-8"))
if manifest.get("open_delta_stage_rows") != 11:
    raise SystemExit("v61du manifest open stage mismatch")
if manifest.get("missing_payload_rows") != 17483:
    raise SystemExit("v61du manifest missing payload mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61du manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61du sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61du produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61du return bundle acceptance delta ledger smoke passed"
