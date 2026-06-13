#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ee_post_review_generation_handoff_fixture_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EE_REUSE_EXISTING="${V61EE_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ee_post_review_generation_handoff_fixture_gate.sh" >/dev/null

"$RUN_DIR/post_review_generation_handoff_fixture_bundle/VERIFY_V61EE_FIXTURE_HANDOFF.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge_summary.csv" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
canonical_v61de_summary_csv = Path(sys.argv[4])


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
    "v61ee_post_review_generation_handoff_fixture_gate_ready": "1",
    "v61ed_review_return_refresh_fixture_replay_gate_ready": "1",
    "fixture_stage_rows": "8",
    "ready_fixture_stage_rows": "6",
    "blocked_fixture_stage_rows": "2",
    "fixture_v61de_ready_handoff_stage_rows": "6",
    "fixture_v61de_blocked_handoff_stage_rows": "2",
    "fixture_answer_review_accepted_rows": "7000",
    "fixture_expected_human_review_rows": "7000",
    "fixture_review_return_ready": "1",
    "fixture_v61_review_unblock_ready": "1",
    "fixture_generation_execution_admission_rows": "1000",
    "fixture_generation_execution_admitted_rows": "1000",
    "fixture_generation_execution_blocked_rows": "0",
    "fixture_guarded_generation_command_ready": "1",
    "fixture_generation_operator_execution_ready": "1",
    "fixture_expected_generation_result_artifacts": "5",
    "fixture_accepted_generation_result_artifacts": "0",
    "fixture_generation_result_accepted_rows": "0",
    "fixture_actual_model_generation_ready": "0",
    "canonical_default_ready_handoff_stage_rows": "3",
    "canonical_default_answer_review_accepted_rows": "0",
    "canonical_default_v61_review_unblock_ready": "0",
    "canonical_default_generation_execution_admitted_rows": "0",
    "canonical_default_accepted_generation_result_artifacts": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": "9",
    "fixture_invariant_pass_rows": "9",
    "fixture_bundle_file_rows": "7",
    "metadata_only_fixture_bundle_file_rows": "7",
    "checkpoint_payload_bytes_downloaded_by_v61ee": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ee {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_review_handoff_fixture_review_return_file_rows.csv",
    "post_review_handoff_fixture_canonical_restore_rows.csv",
    "post_review_generation_handoff_fixture_stage_rows.csv",
    "post_review_generation_handoff_fixture_invariant_rows.csv",
    "post_review_generation_handoff_fixture_bundle_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61EE_POST_REVIEW_GENERATION_HANDOFF_FIXTURE_GATE_BOUNDARY.md",
    "v61ee_post_review_generation_handoff_fixture_gate_manifest.json",
    "post_review_generation_handoff_fixture_bundle/README.md",
    "post_review_generation_handoff_fixture_bundle/VERIFY_V61EE_FIXTURE_HANDOFF.sh",
    "post_review_generation_handoff_fixture_bundle/FIXTURE_REVIEW_RETURN_FILE_ROWS.csv",
    "post_review_generation_handoff_fixture_bundle/CANONICAL_RESTORE_ROWS.csv",
    "post_review_generation_handoff_fixture_bundle/FIXTURE_HANDOFF_STAGES.csv",
    "post_review_generation_handoff_fixture_bundle/FIXTURE_HANDOFF_INVARIANTS.csv",
    "post_review_generation_handoff_fixture_bundle/FIXTURE_HANDOFF_MANIFEST.json",
    "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_summary.csv",
    "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "source_v61de_fixture/post_review_generation_result_handoff_stage_rows.csv",
    "source_v53z_fixture/v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "source_v61dd_fixture/v61dd_review_return_generation_refresh_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ee artifact: {rel}")

fixture_files = read_csv(run_dir / "post_review_handoff_fixture_review_return_file_rows.csv")
restore_rows = read_csv(run_dir / "post_review_handoff_fixture_canonical_restore_rows.csv")
stages = read_csv(run_dir / "post_review_generation_handoff_fixture_stage_rows.csv")
invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "post_review_generation_handoff_fixture_invariant_rows.csv")}
bundle_files = read_csv(run_dir / "post_review_generation_handoff_fixture_bundle_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(fixture_files) < 55:
    raise SystemExit("v61ee expected review return fixture files")
if any(row["real_external_review_return"] != "0" for row in fixture_files):
    raise SystemExit("v61ee fixture files must not be real external review evidence")
if restore_rows[0]["status"] != "pass":
    raise SystemExit("v61ee canonical restore should pass")
canonical = read_csv(canonical_v61de_summary_csv)[0]
if canonical["generation_execution_admitted_rows"] != "0" or canonical["answer_review_accepted_rows"] != "0":
    raise SystemExit("v61ee did not leave canonical v61de summary restored")

if sum(row["status"] == "ready" for row in stages) != 6:
    raise SystemExit("v61ee expected six ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61ee expected two blocked stages")

for invariant_id in [
    "v61ed-fixture-ready",
    "fixture-review-return-files-present",
    "fixture-v53z-review-accepted",
    "fixture-v61dd-generation-admission-open",
    "fixture-v61de-handoff-advances",
    "fixture-generation-result-still-missing",
    "canonical-default-restored",
    "fixture-not-real-external-review",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61ee invariant should pass: {invariant_id}")

if len(bundle_files) != 7:
    raise SystemExit("v61ee expected seven bundle files")
if any(row["payload_class"] != "metadata-only" for row in bundle_files):
    raise SystemExit("v61ee bundle files must be metadata-only")

for gate in [
    "v61ed-review-return-fixture",
    "fixture-v61de-post-review-handoff",
    "fixture-generation-execution-admitted",
    "canonical-default-restore",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ee decision should pass: {gate}")
for gate in ["real-review-return", "generation-result-artifacts", "actual-model-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ee decision should stay blocked: {gate}")

for gap in ["fixture-post-review-handoff", "canonical-default-restore"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ee gap should be ready: {gap}")
for gap in ["real-review-return", "generation-result-artifacts", "actual-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ee gap should stay blocked: {gap}")

boundary = (run_dir / "V61EE_POST_REVIEW_GENERATION_HANDOFF_FIXTURE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "fixture_v61de_ready_handoff_stage_rows=6/8",
    "fixture_generation_execution_admitted_rows=1000/1000",
    "fixture_accepted_generation_result_artifacts=0/5",
    "canonical_default_generation_execution_admitted_rows=0",
    "real_external_review_return_rows=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ee boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ee_post_review_generation_handoff_fixture_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ee_post_review_generation_handoff_fixture_gate_ready") != 1:
    raise SystemExit("v61ee manifest readiness mismatch")
if manifest.get("fixture_generation_execution_admitted_rows") != 1000:
    raise SystemExit("v61ee manifest fixture admission mismatch")
if manifest.get("fixture_accepted_generation_result_artifacts") != 0:
    raise SystemExit("v61ee manifest must keep generation result artifacts at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ee manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ee sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ee produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ee post-review generation handoff fixture gate smoke passed"
