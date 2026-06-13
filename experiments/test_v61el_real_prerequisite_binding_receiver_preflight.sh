#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61el_real_prerequisite_binding_receiver_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_binding_preflight_v61el"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_BINDING_DIR="$RESULTS_DIR/v61eg_generation_result_prereq_binding_fixture_gate/gate_001/v61bt_prerequisite_binding"

V61EG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eg_generation_result_prereq_binding_fixture_gate.sh" >/dev/null

V61EL_REUSE_EXISTING="${V61EL_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

V61EL_RUN_ID="fixture_binding_preflight_v61el" \
V61EL_PREREQUISITE_BINDING_DIR="$FIXTURE_BINDING_DIR" \
V61EL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

V61EL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

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
    "v61el_real_prerequisite_binding_receiver_preflight_ready": "1",
    "binding_dir_supplied": "0",
    "binding_dir_exists": "0",
    "selected_binding_source_class": "none",
    "required_binding_source_files": "3",
    "present_binding_source_files": "0",
    "readable_binding_source_files": "0",
    "model_match_rows": "0",
    "target_match": "0",
    "required_ready_check_rows": "10",
    "ready_check_pass_rows": "0",
    "binding_candidate_preflight_ready": "0",
    "non_fixture_binding_source": "0",
    "real_review_return_provenance_asserted": "0",
    "real_prerequisite_binding_ready": "0",
    "v61bt_intake_handoff_ready": "0",
    "v61de_generation_result_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61el": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61el {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "prerequisite_binding_file_rows.csv",
    "prerequisite_binding_field_check_rows.csv",
    "prerequisite_binding_preflight_check_rows.csv",
    "prerequisite_binding_preflight_metric_rows.csv",
    "prerequisite_binding_handoff_command_rows.csv",
    "V61EL_REAL_PREREQUISITE_BINDING_RECEIVER_PREFLIGHT_BOUNDARY.md",
    "v61el_real_prerequisite_binding_receiver_preflight_manifest.json",
    "source_summaries/v61eh_real_generation_result_return_packet_summary.csv",
    "source_summaries/v61ek_preflight_to_generation_intake_handoff_guard_summary.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "source_summaries/v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "source_summaries/v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "source_summaries/v61dd_review_return_generation_refresh_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61el artifact: {rel}")

file_rows = read_csv(run_dir / "prerequisite_binding_file_rows.csv")
if len(file_rows) != 3 or any(row["file_exists"] != "0" for row in file_rows):
    raise SystemExit("v61el canonical file rows should show 0/3 present")

checks = {row["check_id"]: row for row in read_csv(run_dir / "prerequisite_binding_preflight_check_rows.csv")}
if checks["binding-candidate-preflight-ready"]["status"] != "blocked":
    raise SystemExit("v61el canonical candidate preflight should be blocked")
if checks["non-fixture-binding-source"]["status"] != "blocked":
    raise SystemExit("v61el canonical non-fixture check should be blocked")

commands = read_csv(run_dir / "prerequisite_binding_handoff_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "1"]:
    raise SystemExit("v61el canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "prerequisite_binding_preflight_metric_rows.csv")[0]
fixture_expected = {
    "binding_dir_supplied": "1",
    "binding_dir_exists": "1",
    "selected_binding_source_class": "fixture-v61eg-prerequisite-binding",
    "required_binding_source_files": "3",
    "present_binding_source_files": "3",
    "readable_binding_source_files": "3",
    "model_match_rows": "3",
    "target_match": "1",
    "required_ready_check_rows": "10",
    "ready_check_pass_rows": "10",
    "binding_candidate_preflight_ready": "1",
    "non_fixture_binding_source": "0",
    "real_review_return_provenance_asserted": "0",
    "real_prerequisite_binding_ready": "0",
    "v61bt_intake_handoff_ready": "0",
    "v61de_generation_result_handoff_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61el fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_selected = fixture_run_dir / "selected_prerequisite_binding"
for name in [
    "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_review_return_generation_refresh_bridge_summary.csv",
]:
    if not (fixture_selected / name).is_file():
        raise SystemExit(f"v61el fixture did not copy selected binding file: {name}")

fixture_checks = {row["check_id"]: row["status"] for row in read_csv(fixture_run_dir / "prerequisite_binding_preflight_check_rows.csv")}
if fixture_checks["binding-candidate-preflight-ready"] != "pass":
    raise SystemExit("v61el fixture binding candidate should pass preflight")
if fixture_checks["non-fixture-binding-source"] != "blocked":
    raise SystemExit("v61el fixture binding must remain non-real")

restored_summary = read_csv(root / "results/v61el_real_prerequisite_binding_receiver_preflight_summary.csv")[0]
if restored_summary["binding_dir_supplied"] != "0":
    raise SystemExit("v61el did not restore canonical no-binding summary")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["source-gates-ready"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61el source/repo decisions should pass")
for gate in [
    "binding-candidate-preflight",
    "non-fixture-binding-source",
    "real-review-return-provenance",
    "real-prerequisite-binding",
    "v61bt-intake-handoff",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61el canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EL_REAL_PREREQUISITE_BINDING_RECEIVER_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "binding_dir_supplied=0",
    "binding_candidate_preflight_ready=0",
    "real_prerequisite_binding_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61el boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61el_real_prerequisite_binding_receiver_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61el_real_prerequisite_binding_receiver_preflight_ready") != 1:
    raise SystemExit("v61el manifest readiness mismatch")
if manifest.get("real_prerequisite_binding_ready") != 0:
    raise SystemExit("v61el canonical manifest must keep real binding blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61el manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61el sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61el produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61el real prerequisite binding receiver preflight smoke passed"
