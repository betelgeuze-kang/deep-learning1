#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ek_preflight_to_generation_intake_handoff_guard"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_preflight_selected_v61ek"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_PREFLIGHT_DIR="$RESULTS_DIR/v61ej_real_generation_return_receiver_preflight/fixture_preflight_v61ej"

V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null

V61EK_REUSE_EXISTING="${V61EK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ek_preflight_to_generation_intake_handoff_guard.sh" >/dev/null

V61EK_RUN_ID="fixture_preflight_selected_v61ek" \
V61EK_PREFLIGHT_RUN_DIR="$FIXTURE_PREFLIGHT_DIR" \
V61EK_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ek_preflight_to_generation_intake_handoff_guard.sh" >/dev/null

V61EK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ek_preflight_to_generation_intake_handoff_guard.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
fixture_run_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])


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
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": "1",
    "v61ej_real_generation_return_receiver_preflight_ready": "1",
    "v61eh_real_generation_result_return_packet_ready": "1",
    "selected_preflight_run_dir_supplied": "0",
    "selected_generation_result_receiver_preflight_ready": "0",
    "selected_preflight_pass_generation_result_artifacts": "0",
    "selected_expected_generation_result_artifacts": "5",
    "selected_receiver_preflight_query_pass_rows": "0",
    "selected_receiver_preflight_query_rows": "1000",
    "real_prerequisite_binding_ready": "0",
    "real_review_return_ready": "0",
    "real_generation_execution_admission_ready": "0",
    "v61bt_intake_handoff_ready": "0",
    "v61de_generation_result_handoff_ready": "0",
    "acceptance_refresh_ready": "0",
    "handoff_stage_rows": "6",
    "ready_handoff_stage_rows": "1",
    "blocked_handoff_stage_rows": "5",
    "handoff_command_rows": "5",
    "ready_handoff_command_rows": "2",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ek": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ek {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "preflight_to_generation_intake_handoff_stage_rows.csv",
    "preflight_to_generation_intake_handoff_command_rows.csv",
    "preflight_to_generation_intake_handoff_requirement_rows.csv",
    "V61EK_PREFLIGHT_TO_GENERATION_INTAKE_HANDOFF_GUARD_BOUNDARY.md",
    "v61ek_preflight_to_generation_intake_handoff_guard_manifest.json",
    "selected_preflight/receiver_preflight_metric_rows.csv",
    "selected_preflight/receiver_preflight_artifact_rows.csv",
    "selected_preflight/receiver_preflight_query_rows.csv",
    "source_summaries/v61ej_real_generation_return_receiver_preflight_summary.csv",
    "source_summaries/v61eh_real_generation_result_return_packet_summary.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ek artifact: {rel}")

stages = read_csv(run_dir / "preflight_to_generation_intake_handoff_stage_rows.csv")
if [row["status"] for row in stages] != ["ready", "blocked", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61ek canonical stage status sequence mismatch")

commands = read_csv(run_dir / "preflight_to_generation_intake_handoff_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "0", "0", "0", "1"]:
    raise SystemExit("v61ek canonical command readiness mismatch")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "preflight_to_generation_intake_handoff_requirement_rows.csv")}
if requirements["v61ej-preflight-input"] != "pass":
    raise SystemExit("v61ek should pass v61ej input")
for requirement_id in [
    "selected-preflight-ready",
    "real-prerequisite-binding",
    "v61bt-intake-handoff-ready",
    "v61de-handoff-ready",
    "actual-model-generation",
]:
    if requirements[requirement_id] != "blocked":
        raise SystemExit(f"v61ek canonical requirement should be blocked: {requirement_id}")

fixture_summary = read_csv(root / "results/v61ek_preflight_to_generation_intake_handoff_guard_summary.csv")[0]
if fixture_summary["selected_preflight_run_dir_supplied"] != "0":
    raise SystemExit("v61ek did not restore canonical summary after fixture selected run")

fixture_metric = read_csv(fixture_run_dir / "source_summaries/v61eh_real_generation_result_return_packet_summary.csv")[0]
if fixture_metric["real_prerequisite_binding_ready"] != "0":
    raise SystemExit("v61ek fixture selected run should still lack real prerequisite binding")

fixture_selected_metric = read_csv(fixture_run_dir / "selected_preflight/receiver_preflight_metric_rows.csv")[0]
if fixture_selected_metric["generation_result_receiver_preflight_ready"] != "1":
    raise SystemExit("v61ek fixture selected preflight should be ready")
fixture_stage = read_csv(fixture_run_dir / "preflight_to_generation_intake_handoff_stage_rows.csv")
if [row["status"] for row in fixture_stage] != ["ready", "ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61ek fixture selected stage status sequence mismatch")
fixture_commands = read_csv(fixture_run_dir / "preflight_to_generation_intake_handoff_command_rows.csv")
if [row["ready_to_run_now"] for row in fixture_commands] != ["1", "0", "0", "0", "1"]:
    raise SystemExit("v61ek fixture selected commands should remain blocked without real binding")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["v61ej-preflight-input"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61ek input/repo decisions should pass")
for gate in [
    "selected-preflight-ready",
    "real-prerequisite-binding",
    "v61bt-intake-handoff",
    "v61de-generation-result-handoff",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ek canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EK_PREFLIGHT_TO_GENERATION_INTAKE_HANDOFF_GUARD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_generation_result_receiver_preflight_ready=0",
    "selected_preflight_pass_generation_result_artifacts=0/5",
    "real_prerequisite_binding_ready=0",
    "v61bt_intake_handoff_ready=0",
    "v61de_generation_result_handoff_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ek boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ek_preflight_to_generation_intake_handoff_guard_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ek_preflight_to_generation_intake_handoff_guard_ready") != 1:
    raise SystemExit("v61ek manifest readiness mismatch")
if manifest.get("v61bt_intake_handoff_ready") != 0:
    raise SystemExit("v61ek manifest must keep v61bt handoff blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ek manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ek manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ek sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ek produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ek preflight to generation intake handoff guard smoke passed"
