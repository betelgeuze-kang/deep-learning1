#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dz_review_return_chunk_submission_runway"
RUN_DIR="$RESULTS_DIR/$PREFIX/runway_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DZ_REUSE_EXISTING="${V61DZ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dz_review_return_chunk_submission_runway.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61dz summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61dz_review_return_chunk_submission_runway_ready": "1",
    "v61dy_active_goal_critical_path_runway_ready": "1",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    "submission_phase_rows": "6",
    "ready_submission_phase_rows": "3",
    "blocked_submission_phase_rows": "3",
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
    "submission_artifact_family_rows": "4",
    "submission_task_family_rows": "2",
    "submission_command_rows": "4",
    "ready_submission_command_rows": "2",
    "blocked_submission_command_rows": "2",
    "submission_invariant_rows": "6",
    "submission_invariant_pass_rows": "6",
    "submission_file_rows": "9",
    "metadata_only_submission_file_rows": "9",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "review_return_ready": "0",
    "v53_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dz {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_submission_chunk_manifest_rows.csv",
    "review_return_submission_artifact_family_rows.csv",
    "review_return_submission_task_family_rows.csv",
    "review_return_submission_phase_rows.csv",
    "review_return_submission_command_rows.csv",
    "review_return_submission_invariant_rows.csv",
    "review_return_submission_file_rows.csv",
    "review_return_submission_runway/REVIEW_RETURN_CHUNK_MANIFEST.csv",
    "review_return_submission_runway/REVIEW_RETURN_ARTIFACT_FAMILIES.csv",
    "review_return_submission_runway/REVIEW_RETURN_TASK_FAMILIES.csv",
    "review_return_submission_runway/REVIEW_RETURN_SUBMISSION_PHASES.csv",
    "review_return_submission_runway/REVIEW_RETURN_COMMANDS.csv",
    "review_return_submission_runway/REVIEW_RETURN_INVARIANTS.csv",
    "review_return_submission_runway/REVIEW_RETURN_SUBMISSION_README.md",
    "review_return_submission_runway/READY_REVIEW_CHUNK_COMMANDS.sh",
    "review_return_submission_runway/SUBMISSION_MANIFEST.json",
    "v61dz_review_return_chunk_submission_runway_manifest.json",
    "source_v61dy/v61dy_active_goal_critical_path_runway_summary.csv",
    "source_v61dy/critical_path_next_action_rows.csv",
    "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "source_v53w/review_return_chunk_execution_rows.csv",
    "source_v53w/review_return_chunk_task_rows.csv",
    "source_v53w/review_return_chunk_artifact_rows.csv",
    "source_v53w/review_return_chunk_command_rows.csv",
    "source_v53w/VERIFY_CHUNK_QUEUE.sh",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dz artifact: {rel}")

chunks = read_csv(run_dir / "review_return_submission_chunk_manifest_rows.csv")
if len(chunks) != 21:
    raise SystemExit("v61dz expected 21 chunk manifest rows")
if sum(row["submission_status"] == "ready-to-dispatch" for row in chunks) != 21:
    raise SystemExit("v61dz expected all 21 chunks ready to dispatch")
if sum(int(row["expected_human_review_rows"]) for row in chunks) != 7000:
    raise SystemExit("v61dz human review row total mismatch")
if sum(int(row["expected_adjudication_rows"]) for row in chunks) != 1000:
    raise SystemExit("v61dz adjudication row total mismatch")
if sum(int(row["expected_reviewer_identity_rows"]) for row in chunks) != 21:
    raise SystemExit("v61dz identity row total mismatch")
if sum(int(row["expected_conflict_disclosure_rows"]) for row in chunks) != 210:
    raise SystemExit("v61dz conflict row total mismatch")

families = {row["artifact_family"]: row for row in read_csv(run_dir / "review_return_submission_artifact_family_rows.csv")}
expected_families = {
    "adjudication_rows.csv": ("1", "1000", "0"),
    "human_review_rows.csv": ("7", "7000", "0"),
    "reviewer_conflict_rows.csv": ("21", "210", "0"),
    "reviewer_identity_rows.csv": ("21", "21", "0"),
}
for family, (artifacts, expected_rows, accepted_rows) in expected_families.items():
    row = families.get(family)
    if not row:
        raise SystemExit(f"missing v61dz artifact family: {family}")
    if (row["chunk_artifact_rows"], row["expected_rows"], row["accepted_rows"]) != (artifacts, expected_rows, accepted_rows):
        raise SystemExit(f"v61dz artifact family mismatch: {family}: {row}")

task_families = {row["task_type"]: row for row in read_csv(run_dir / "review_return_submission_task_family_rows.csv")}
if task_families["human-review"]["task_rows"] != "7000":
    raise SystemExit("v61dz human task family mismatch")
if task_families["adjudication"]["task_rows"] != "1000":
    raise SystemExit("v61dz adjudication task family mismatch")

phases = read_csv(run_dir / "review_return_submission_phase_rows.csv")
if [row["phase_id"] for row in phases] != [
    "01-bind-review-first-runway",
    "02-bind-review-chunk-queue",
    "03-dispatch-review-chunks",
    "04-collect-50-chunk-artifacts",
    "05-merge-aggregate-v53s-return",
    "06-refresh-generation-unblock-chain",
]:
    raise SystemExit("v61dz phase order mismatch")
if sum(row["status"] == "ready" for row in phases) != 3:
    raise SystemExit("v61dz expected three ready phases")
if phases[-1]["status"] != "blocked" or "generation remains blocked" not in phases[-1]["evidence"]:
    raise SystemExit("v61dz final phase must keep generation blocked")

commands = read_csv(run_dir / "review_return_submission_command_rows.csv")
if len(commands) != 4:
    raise SystemExit("v61dz expected four command rows")
if sum(row["status"] == "ready" for row in commands) != 2:
    raise SystemExit("v61dz expected two ready commands")
if commands[-1]["status"] != "blocked":
    raise SystemExit("v61dz refresh command should stay blocked")

invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "review_return_submission_invariant_rows.csv")}
for invariant_id in [
    "v61dy-review-first-runway-ready",
    "v53w-review-chunk-dispatch-ready",
    "review-task-counts-preserved",
    "chunk-artifact-counts-preserved",
    "review-return-blocks-generation",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61dz invariant should pass: {invariant_id}")

submission_files = read_csv(run_dir / "review_return_submission_file_rows.csv")
if len(submission_files) != 9:
    raise SystemExit("v61dz expected nine submission files")
if any(row["payload_class"] != "metadata-only" for row in submission_files):
    raise SystemExit("v61dz submission files must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "review-return-chunk-submission-runway",
    "review-chunk-dispatch-ready",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dz decision should pass: {gate}")
for gate in [
    "review-chunk-return-accepted",
    "aggregate-v53s-review-return",
    "generation-execution-admitted",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dz decision should stay blocked: {gate}")

readme = (run_dir / "review_return_submission_runway/REVIEW_RETURN_SUBMISSION_README.md").read_text(encoding="utf-8")
for snippet in [
    "metadata-only",
    "without creating human review decisions",
    "review_chunk_rows=21",
    "ready_review_chunk_dispatch_rows=21",
    "human_review_chunk_task_rows=7000",
    "adjudication_chunk_task_rows=1000",
    "review_chunk_return_artifact_rows=50",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "actual_model_generation_ready=0",
]:
    if snippet not in readme:
        raise SystemExit(f"v61dz readme missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dz_review_return_chunk_submission_runway_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dz_review_return_chunk_submission_runway_ready") != 1:
    raise SystemExit("v61dz manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dz manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dz manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dz sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dz produced model/checkpoint payload-like files" >&2
  exit 1
fi

"$RUN_DIR/review_return_submission_runway/READY_REVIEW_CHUNK_COMMANDS.sh" >/dev/null

echo "v61dz review return chunk submission runway smoke passed"
