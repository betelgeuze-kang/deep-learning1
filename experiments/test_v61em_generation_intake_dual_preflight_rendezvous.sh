#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61em_generation_intake_dual_preflight_rendezvous"
RUN_DIR="$RESULTS_DIR/$PREFIX/rendezvous_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dual_candidate_v61em"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_GENERATION_PREFLIGHT_DIR="$RESULTS_DIR/v61ej_real_generation_return_receiver_preflight/fixture_preflight_v61ej"
FIXTURE_BINDING_PREFLIGHT_DIR="$RESULTS_DIR/v61el_real_prerequisite_binding_receiver_preflight/fixture_binding_preflight_v61el"

V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

V61EM_REUSE_EXISTING="${V61EM_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

V61EM_RUN_ID="fixture_dual_candidate_v61em" \
V61EM_GENERATION_PREFLIGHT_RUN_DIR="$FIXTURE_GENERATION_PREFLIGHT_DIR" \
V61EM_BINDING_PREFLIGHT_RUN_DIR="$FIXTURE_BINDING_PREFLIGHT_DIR" \
V61EM_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

V61EM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

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
    "v61em_generation_intake_dual_preflight_rendezvous_ready": "1",
    "v61ej_real_generation_return_receiver_preflight_ready": "1",
    "v61el_real_prerequisite_binding_receiver_preflight_ready": "1",
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": "1",
    "selected_generation_preflight_run_dir_supplied": "0",
    "selected_generation_result_receiver_preflight_ready": "0",
    "selected_preflight_pass_generation_result_artifacts": "0",
    "selected_expected_generation_result_artifacts": "5",
    "selected_receiver_preflight_query_pass_rows": "0",
    "selected_receiver_preflight_query_rows": "1000",
    "selected_real_generation_result_artifacts": "0",
    "selected_binding_preflight_run_dir_supplied": "0",
    "selected_binding_candidate_preflight_ready": "0",
    "selected_binding_source_class": "none",
    "selected_non_fixture_binding_source": "0",
    "selected_real_review_return_provenance_asserted": "0",
    "selected_real_prerequisite_binding_ready": "0",
    "dual_candidate_preflight_rendezvous_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "v61bt_intake_handoff_ready": "0",
    "v61de_generation_result_handoff_ready": "0",
    "rendezvous_stage_rows": "7",
    "ready_rendezvous_stage_rows": "1",
    "blocked_rendezvous_stage_rows": "6",
    "rendezvous_command_rows": "5",
    "ready_rendezvous_command_rows": "3",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61em": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61em {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_preflight_rendezvous_stage_rows.csv",
    "dual_preflight_rendezvous_command_rows.csv",
    "dual_preflight_rendezvous_requirement_rows.csv",
    "V61EM_GENERATION_INTAKE_DUAL_PREFLIGHT_RENDEZVOUS_BOUNDARY.md",
    "v61em_generation_intake_dual_preflight_rendezvous_manifest.json",
    "selected_generation_preflight/receiver_preflight_metric_rows.csv",
    "selected_generation_preflight/receiver_preflight_artifact_rows.csv",
    "selected_generation_preflight/receiver_preflight_query_rows.csv",
    "selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv",
    "selected_binding_preflight/prerequisite_binding_file_rows.csv",
    "selected_binding_preflight/prerequisite_binding_field_check_rows.csv",
    "source_summaries/v61ej_real_generation_return_receiver_preflight_summary.csv",
    "source_summaries/v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
    "source_summaries/v61ek_preflight_to_generation_intake_handoff_guard_summary.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61em artifact: {rel}")

stages = read_csv(run_dir / "dual_preflight_rendezvous_stage_rows.csv")
if [row["status"] for row in stages] != ["ready", "blocked", "blocked", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61em canonical stage status sequence mismatch")

commands = read_csv(run_dir / "dual_preflight_rendezvous_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "1"]:
    raise SystemExit("v61em canonical command readiness mismatch")

fixture_summary = read_csv(fixture_run_dir / "source_summaries/v61el_real_prerequisite_binding_receiver_preflight_summary.csv")[0]
if fixture_summary["real_prerequisite_binding_ready"] != "0":
    raise SystemExit("v61em fixture selected run should inherit canonical real binding blocked")

fixture_metric = read_csv(root / "results/v61em_generation_intake_dual_preflight_rendezvous_summary.csv")[0]
if fixture_metric["selected_generation_preflight_run_dir_supplied"] != "0":
    raise SystemExit("v61em did not restore canonical summary after fixture run")

fixture_stage = read_csv(fixture_run_dir / "dual_preflight_rendezvous_stage_rows.csv")
if [row["status"] for row in fixture_stage] != ["ready", "ready", "ready", "blocked", "ready", "blocked", "blocked"]:
    raise SystemExit("v61em fixture stage status sequence mismatch")

fixture_selected_gen = read_csv(fixture_run_dir / "selected_generation_preflight/receiver_preflight_metric_rows.csv")[0]
fixture_selected_bind = read_csv(fixture_run_dir / "selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv")[0]
if fixture_selected_gen["generation_result_receiver_preflight_ready"] != "1":
    raise SystemExit("v61em fixture generation preflight should be ready")
if fixture_selected_bind["binding_candidate_preflight_ready"] != "1":
    raise SystemExit("v61em fixture binding candidate should be ready")
if fixture_selected_bind["real_prerequisite_binding_ready"] != "0":
    raise SystemExit("v61em fixture binding should remain non-real")

fixture_manifest = json.loads((fixture_run_dir / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("dual_candidate_preflight_rendezvous_ready") != 1:
    raise SystemExit("v61em fixture manifest should open dual candidate rendezvous")
if fixture_manifest.get("real_generation_intake_handoff_ready") != 0:
    raise SystemExit("v61em fixture manifest must keep real intake blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["source-gates-ready"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61em source/repo decisions should pass")
for gate in [
    "selected-generation-preflight",
    "selected-binding-candidate-preflight",
    "real-prerequisite-binding",
    "dual-candidate-rendezvous",
    "real-generation-intake-handoff",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61em canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EM_GENERATION_INTAKE_DUAL_PREFLIGHT_RENDEZVOUS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_generation_result_receiver_preflight_ready=0",
    "selected_binding_candidate_preflight_ready=0",
    "selected_real_prerequisite_binding_ready=0",
    "dual_candidate_preflight_rendezvous_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61em boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61em_generation_intake_dual_preflight_rendezvous_ready") != 1:
    raise SystemExit("v61em manifest readiness mismatch")
if manifest.get("real_generation_intake_handoff_ready") != 0:
    raise SystemExit("v61em canonical manifest must keep real intake blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61em manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61em sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61em produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61em generation intake dual preflight rendezvous smoke passed"
