#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fa_post_ey_acceptance_closure_execution_queue"
RUN_DIR="$RESULTS_DIR/$PREFIX/queue_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
QUEUE_DIR="$RUN_DIR/execution_queue_bundle"

V61FA_REUSE_EXISTING="${V61FA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fa_post_ey_acceptance_closure_execution_queue.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$QUEUE_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
queue_dir = Path(sys.argv[4])


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
    "v61fa_post_ey_acceptance_closure_execution_queue_ready": "1",
    "v61ez_active_goal_post_ey_status_refresh_ready": "1",
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": "1",
    "queue_phase_rows": "8",
    "ready_queue_phase_rows": "3",
    "blocked_queue_phase_rows": "5",
    "queue_command_rows": "8",
    "ready_queue_command_rows": "2",
    "requirement_rows": "12",
    "ready_requirement_rows": "5",
    "blocked_requirement_rows": "7",
    "invariant_rows": "5",
    "pass_invariant_rows": "5",
    "queue_file_rows": "10",
    "metadata_only_queue_file_rows": "10",
    "acceptance_closure_handoff_bundle_ready": "1",
    "selected_acceptance_bridge_candidate_ready": "0",
    "selected_acceptance_bridge_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fa": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fa {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_ey_acceptance_closure_execution_phase_rows.csv",
    "post_ey_acceptance_closure_execution_command_rows.csv",
    "post_ey_acceptance_closure_execution_requirement_rows.csv",
    "post_ey_acceptance_closure_execution_invariant_rows.csv",
    "post_ey_acceptance_closure_execution_queue_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61FA_POST_EY_ACCEPTANCE_CLOSURE_EXECUTION_QUEUE_BOUNDARY.md",
    "v61fa_post_ey_acceptance_closure_execution_queue_manifest.json",
    "execution_queue_bundle/ACCEPTANCE_CLOSURE_EXECUTION_QUEUE.md",
    "execution_queue_bundle/ACCEPTANCE_CLOSURE_PHASE_ROWS.csv",
    "execution_queue_bundle/ACCEPTANCE_CLOSURE_COMMAND_ROWS.csv",
    "execution_queue_bundle/ACCEPTANCE_CLOSURE_REQUIREMENT_ROWS.csv",
    "execution_queue_bundle/ACCEPTANCE_CLOSURE_INVARIANTS.csv",
    "execution_queue_bundle/READY_NOW_COMMANDS.sh",
    "execution_queue_bundle/VERIFY_QUEUE.sh",
    "execution_queue_bundle/QUEUE_MANIFEST.json",
    "execution_queue_bundle/QUEUE_FILE_LIST.txt",
    "execution_queue_bundle/QUEUE_SHA256SUMS.txt",
    "source_v61ez/post_ey_requirement_rows.csv",
    "source_v61ez/post_ey_claim_boundary_rows.csv",
    "source_v61ez/post_ey_next_action_rows.csv",
    "source_v61ey/BUNDLE_MANIFEST.json",
    "source_v61ey/generation_acceptance_closure_handoff_bundle_file_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fa artifact: {rel}")

phase_rows = read_csv(run_dir / "post_ey_acceptance_closure_execution_phase_rows.csv")
command_rows = read_csv(run_dir / "post_ey_acceptance_closure_execution_command_rows.csv")
requirement_rows = read_csv(run_dir / "post_ey_acceptance_closure_execution_requirement_rows.csv")
invariant_rows = read_csv(run_dir / "post_ey_acceptance_closure_execution_invariant_rows.csv")
file_rows = read_csv(run_dir / "post_ey_acceptance_closure_execution_queue_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if [row["ready"] for row in phase_rows] != ["1", "1", "1", "0", "0", "0", "0", "0"]:
    raise SystemExit("v61fa phase readiness posture mismatch")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "0", "0", "0", "0", "0", "0"]:
    raise SystemExit("v61fa command readiness posture mismatch")
if len(requirement_rows) != 12 or sum(row["ready"] == "1" for row in requirement_rows) != 6:
    raise SystemExit("v61fa requirement posture mismatch")
if any(row["status"] != "pass" for row in invariant_rows):
    raise SystemExit("v61fa invariants should all pass")
if any(row["payload_class"] != "metadata-only" for row in file_rows):
    raise SystemExit("v61fa found non-metadata queue file")

for gate in [
    "execution-queue-shape",
    "source-v61ez-ready",
    "source-v61ey-ready",
    "metadata-only-queue",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fa expected pass gate: {gate}")
for gate in [
    "real-v53-review-return",
    "real-return-bundle-replay",
    "generation-acceptance-closure",
    "actual-model-generation",
    "latency-quality-release",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fa expected blocked gate: {gate}")
for gap in [
    "04-real-v53-review-return",
    "05-real-return-bundle-through-v61et-v61ew",
    "06-close-v61bt-v61de-v61cu-acceptance",
    "08-latency-quality-release-audit",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61fa expected blocked gap: {gap}")

queue_manifest = json.loads((queue_dir / "QUEUE_MANIFEST.json").read_text(encoding="utf-8"))
if queue_manifest.get("queue_phase_rows") != 8:
    raise SystemExit("v61fa queue manifest phase count mismatch")
if queue_manifest.get("ready_queue_command_rows") != 2:
    raise SystemExit("v61fa queue manifest ready command count mismatch")
if queue_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fa queue manifest must keep actual generation blocked")

boundary = (run_dir / "V61FA_POST_EY_ACCEPTANCE_CLOSURE_EXECUTION_QUEUE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "queue_phase_rows=8",
    "ready_queue_phase_rows=3",
    "blocked_queue_phase_rows=5",
    "queue_command_rows=8",
    "ready_queue_command_rows=2",
    "generation_acceptance_closure_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fa boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fa_post_ey_acceptance_closure_execution_queue_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fa_post_ey_acceptance_closure_execution_queue_ready") != 1:
    raise SystemExit("v61fa manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fa manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fa manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fa sha256 mismatch: {rel}")
PY

"$QUEUE_DIR/VERIFY_QUEUE.sh" >/dev/null
"$QUEUE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fa produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fa post-ey acceptance closure execution queue smoke passed"
