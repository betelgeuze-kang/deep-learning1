#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eg_generation_result_prereq_binding_fixture_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EG_REUSE_EXISTING="${V61EG_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eg_generation_result_prereq_binding_fixture_gate.sh" >/dev/null

"$RUN_DIR/binding_fixture_bundle/VERIFY_V61EG_BINDING_FIXTURE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
root = Path(sys.argv[4])


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
    "v61eg_generation_result_prereq_binding_fixture_gate_ready": "1",
    "fixture_stage_rows": "7",
    "ready_fixture_stage_rows": "6",
    "blocked_fixture_stage_rows": "1",
    "binding_rows": "4",
    "ready_binding_rows": "4",
    "fixture_generation_result_file_rows": "5",
    "fixture_prerequisite_binding_ready": "1",
    "fixture_v61bt_prerequisite_binding_ready": "1",
    "fixture_review_return_ready": "1",
    "fixture_v61_review_unblock_ready": "1",
    "fixture_generation_execution_admitted_rows": "1000",
    "fixture_generation_execution_admission_rows": "1000",
    "fixture_guarded_generation_command_ready": "1",
    "fixture_generation_operator_execution_ready": "1",
    "fixture_expected_generation_result_artifacts": "5",
    "fixture_supplied_generation_result_artifacts": "5",
    "fixture_accepted_generation_result_artifacts": "5",
    "fixture_invalid_generation_result_artifacts": "0",
    "fixture_generation_result_supplied_rows": "1000",
    "fixture_generation_result_accepted_rows": "1000",
    "fixture_actual_model_generation_ready_rows": "1000",
    "fixture_result_acceptance_ready": "1",
    "canonical_default_generation_execution_admitted_rows": "0",
    "canonical_default_generation_result_dir_supplied": "0",
    "canonical_default_prerequisite_binding_dir_supplied": "0",
    "canonical_default_accepted_generation_result_artifacts": "0",
    "canonical_default_generation_result_accepted_rows": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": "7",
    "fixture_invariant_pass_rows": "7",
    "fixture_bundle_file_rows": "6",
    "metadata_only_fixture_bundle_file_rows": "6",
    "checkpoint_payload_bytes_downloaded_by_v61eg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eg {field}: expected {value}, got {summary.get(field)}")

if int(summary["fixture_review_return_file_rows"]) < 55:
    raise SystemExit("v61eg expected review-return fixture files")

required_files = [
    "v61bt_prerequisite_binding_rows.csv",
    "fixture_generation_result_file_rows.csv",
    "fixture_review_return_file_rows.csv",
    "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_v61bt_fixture/actual_generation_result_status_rows.csv",
    "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "source_v61cu_fixture/complete_source_generation_result_acceptance_rows.csv",
    "generation_result_prereq_binding_fixture_stage_rows.csv",
    "generation_result_prereq_binding_fixture_invariant_rows.csv",
    "canonical_restore_rows.csv",
    "binding_fixture_bundle_file_rows.csv",
    "V61EG_GENERATION_RESULT_PREREQ_BINDING_FIXTURE_GATE_BOUNDARY.md",
    "v61eg_generation_result_prereq_binding_fixture_gate_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eg artifact: {rel}")

binding_rows = read_csv(run_dir / "v61bt_prerequisite_binding_rows.csv")
if len(binding_rows) != 4 or any(row["binding_ready"] != "1" for row in binding_rows):
    raise SystemExit("v61eg expected four ready binding rows")

status_rows = read_csv(run_dir / "source_v61bt_fixture/actual_generation_result_status_rows.csv")
if len(status_rows) != 5:
    raise SystemExit("v61eg expected five v61bt status rows")
if any(row["result_supplied"] != "1" or row["result_accepted"] != "1" for row in status_rows):
    raise SystemExit("v61eg expected all supplied fixture results to be accepted")

acceptance_rows = read_csv(run_dir / "source_v61cu_fixture/complete_source_generation_result_acceptance_rows.csv")
if len(acceptance_rows) != 1000:
    raise SystemExit("v61eg expected 1000 fixture acceptance rows")
if any(row["generation_result_accepted"] != "1" for row in acceptance_rows):
    raise SystemExit("v61eg expected all fixture generation result rows accepted")

stages = read_csv(run_dir / "generation_result_prereq_binding_fixture_stage_rows.csv")
if [row["status"] for row in stages] != ["ready", "ready", "ready", "ready", "ready", "ready", "blocked"]:
    raise SystemExit("v61eg stage status sequence mismatch")

invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "generation_result_prereq_binding_fixture_invariant_rows.csv")}
for invariant_id in [
    "binding-ready",
    "fixture-generation-execution-admitted",
    "fixture-result-artifacts-accepted",
    "fixture-generation-result-rows-accepted",
    "canonical-default-restored",
    "fixture-not-real-external-generation",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61eg invariant should pass: {invariant_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "prerequisite-binding",
    "fixture-generation-execution-admitted",
    "fixture-generation-result-artifacts-accepted",
    "fixture-generation-result-rows-accepted",
    "canonical-default-restore",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61eg decision should pass: {gate}")
for gate in ["real-generation-result-artifacts", "actual-model-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61eg decision should stay blocked: {gate}")

boundary = (run_dir / "V61EG_GENERATION_RESULT_PREREQ_BINDING_FIXTURE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "fixture_prerequisite_binding_ready=1",
    "fixture_accepted_generation_result_artifacts=5/5",
    "fixture_generation_result_accepted_rows=1000/1000",
    "real_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61eg boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61eg_generation_result_prereq_binding_fixture_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61eg_generation_result_prereq_binding_fixture_gate_ready") != 1:
    raise SystemExit("v61eg manifest readiness mismatch")
if manifest.get("fixture_accepted_generation_result_artifacts") != 5:
    raise SystemExit("v61eg manifest accepted artifact mismatch")
if manifest.get("fixture_generation_result_accepted_rows") != 1000:
    raise SystemExit("v61eg manifest accepted row mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61eg manifest must keep actual generation blocked")

canonical_default = next(csv.DictReader((root / "results/v61de_post_review_generation_result_handoff_bridge_summary.csv").open(newline="", encoding="utf-8")))
if canonical_default["review_return_dir_supplied"] != "0" or canonical_default["generation_result_dir_supplied"] != "0":
    raise SystemExit("v61eg did not restore canonical v61de summary")
if canonical_default.get("prerequisite_binding_dir_supplied", "0") != "0":
    raise SystemExit("v61eg did not restore canonical binding input")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eg sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eg produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eg generation result prerequisite binding fixture gate smoke passed"
