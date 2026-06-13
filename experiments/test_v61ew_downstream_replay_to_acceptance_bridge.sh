#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ew_downstream_replay_to_acceptance_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_acceptance_bridge_v61ew"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_REPLAY_DIR="$RESULTS_DIR/v61ev_return_bundle_downstream_replay_gate/fixture_downstream_replay_v61ev"

V61EV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ev_return_bundle_downstream_replay_gate.sh" >/dev/null

V61EW_REUSE_EXISTING="${V61EW_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ew_downstream_replay_to_acceptance_bridge.sh" >/dev/null

V61EW_RUN_ID="fixture_acceptance_bridge_v61ew" \
V61EW_REPLAY_RUN_DIR="$FIXTURE_REPLAY_DIR" \
V61EW_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ew_downstream_replay_to_acceptance_bridge.sh" >/dev/null

V61EW_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ew_downstream_replay_to_acceptance_bridge.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


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
    "v61ew_downstream_replay_to_acceptance_bridge_ready": "1",
    "selected_downstream_replay_candidate_ready": "0",
    "selected_downstream_replay_real_ready": "0",
    "v61bt_result_intake_ready": "0",
    "v61de_post_review_handoff_ready": "0",
    "v61cu_result_acceptance_ready": "0",
    "acceptance_bridge_candidate_ready": "0",
    "acceptance_bridge_real_ready": "0",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ew": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ew {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "downstream_replay_to_acceptance_stage_rows.csv",
    "downstream_replay_to_acceptance_requirement_rows.csv",
    "downstream_replay_to_acceptance_command_rows.csv",
    "V61EW_DOWNSTREAM_REPLAY_TO_ACCEPTANCE_BRIDGE_BOUNDARY.md",
    "v61ew_downstream_replay_to_acceptance_bridge_manifest.json",
    "selected_replay/return_bundle_downstream_replay_stage_rows.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "source_summaries/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ew artifact: {rel}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "downstream_replay_to_acceptance_requirement_rows.csv")}
for req in ["downstream-replay-candidate", "downstream-replay-real", "v61bt-result-intake", "v61de-post-review-handoff", "v61cu-result-acceptance", "acceptance-bridge-candidate", "acceptance-bridge-real", "actual-generation"]:
    if requirements[req] != "blocked":
        raise SystemExit(f"v61ew canonical requirement should be blocked: {req}")

fixture_summary = read_csv(fixture_run_dir / "downstream_replay_to_acceptance_stage_rows.csv")
fixture_stages = {row["stage_id"]: row["ready"] for row in fixture_summary}
for stage in ["01-downstream-replay-candidate", "06-acceptance-bridge-candidate"]:
    if fixture_stages[stage] != "1":
        raise SystemExit(f"v61ew fixture candidate stage should pass: {stage}")
for stage in ["02-downstream-replay-real", "03-v61bt-result-intake", "04-v61de-post-review-handoff", "05-v61cu-result-acceptance", "07-acceptance-bridge-real", "08-actual-generation"]:
    if fixture_stages[stage] != "0":
        raise SystemExit(f"v61ew fixture stage should stay blocked: {stage}")

fixture_manifest = json.loads((fixture_run_dir / "v61ew_downstream_replay_to_acceptance_bridge_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("acceptance_bridge_candidate_ready") != 1:
    raise SystemExit("v61ew fixture acceptance bridge candidate should be ready")
if fixture_manifest.get("acceptance_bridge_real_ready") != 0:
    raise SystemExit("v61ew fixture real acceptance bridge must stay blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61ew repo payload decision should pass")
for gate in ["downstream-replay-candidate", "downstream-replay-real", "v61bt-result-intake", "v61de-post-review-handoff", "v61cu-result-acceptance", "acceptance-bridge-real", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ew canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EW_DOWNSTREAM_REPLAY_TO_ACCEPTANCE_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_downstream_replay_candidate_ready=0",
    "acceptance_bridge_candidate_ready=0",
    "acceptance_bridge_real_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ew boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ew_downstream_replay_to_acceptance_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ew_downstream_replay_to_acceptance_bridge_ready") != 1:
    raise SystemExit("v61ew manifest readiness mismatch")
if manifest.get("acceptance_bridge_real_ready") != 0:
    raise SystemExit("v61ew canonical manifest must keep real acceptance blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ew manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ew sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ew produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ew downstream replay to acceptance bridge smoke passed"
