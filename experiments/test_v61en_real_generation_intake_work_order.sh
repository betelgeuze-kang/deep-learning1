#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61en_real_generation_intake_work_order"
RUN_DIR="$RESULTS_DIR/$PREFIX/work_order_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dual_candidate_work_order_v61en"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_RENDEZVOUS_DIR="$RESULTS_DIR/v61em_generation_intake_dual_preflight_rendezvous/fixture_dual_candidate_v61em"

V61EM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

V61EN_REUSE_EXISTING="${V61EN_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null

V61EN_RUN_ID="fixture_dual_candidate_work_order_v61en" \
V61EN_RENDEZVOUS_RUN_DIR="$FIXTURE_RENDEZVOUS_DIR" \
V61EN_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null

V61EN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null

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
    "v61en_real_generation_intake_work_order_ready": "1",
    "selected_rendezvous_run_dir_supplied": "0",
    "v61em_generation_intake_dual_preflight_rendezvous_ready": "1",
    "selected_generation_result_receiver_preflight_ready": "0",
    "selected_binding_candidate_preflight_ready": "0",
    "selected_non_fixture_binding_source": "0",
    "selected_real_review_return_provenance_asserted": "0",
    "selected_real_prerequisite_binding_ready": "0",
    "dual_candidate_preflight_rendezvous_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "v61bt_intake_handoff_ready": "0",
    "v61de_generation_result_handoff_ready": "0",
    "work_order_rows": "11",
    "ready_work_order_rows": "1",
    "blocked_work_order_rows": "10",
    "command_rows": "7",
    "ready_command_rows": "2",
    "blocker_rows": "6",
    "open_blocker_rows": "6",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61en": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61en {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_intake_work_order_rows.csv",
    "real_generation_intake_command_rows.csv",
    "real_generation_intake_blocker_rows.csv",
    "V61EN_REAL_GENERATION_INTAKE_WORK_ORDER.md",
    "v61en_real_generation_intake_work_order_manifest.json",
    "selected_rendezvous/dual_preflight_rendezvous_stage_rows.csv",
    "selected_rendezvous/dual_preflight_rendezvous_command_rows.csv",
    "selected_rendezvous/dual_preflight_rendezvous_requirement_rows.csv",
    "selected_rendezvous/v61em_generation_intake_dual_preflight_rendezvous_manifest.json",
    "selected_rendezvous/selected_generation_preflight/receiver_preflight_metric_rows.csv",
    "selected_rendezvous/selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv",
    "source_summaries/v61em_generation_intake_dual_preflight_rendezvous_summary.csv",
    "source_summaries/v61ej_real_generation_return_receiver_preflight_summary.csv",
    "source_summaries/v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61en artifact: {rel}")

work_rows = read_csv(run_dir / "real_generation_intake_work_order_rows.csv")
if [row["status"] for row in work_rows] != [
    "ready",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
]:
    raise SystemExit("v61en canonical work-order status sequence mismatch")

commands = read_csv(run_dir / "real_generation_intake_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "0", "0", "0", "0", "0", "1"]:
    raise SystemExit("v61en canonical command readiness mismatch")

fixture_summary = read_csv(fixture_run_dir / "selected_rendezvous/selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv")[0]
if fixture_summary["binding_candidate_preflight_ready"] != "1":
    raise SystemExit("v61en fixture selected binding candidate should be ready")
if fixture_summary["real_prerequisite_binding_ready"] != "0":
    raise SystemExit("v61en fixture selected binding should remain non-real")

fixture_manifest = json.loads((fixture_run_dir / "v61en_real_generation_intake_work_order_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("real_generation_intake_handoff_ready") != 0:
    raise SystemExit("v61en fixture manifest must keep real intake blocked")
if fixture_manifest.get("open_blocker_rows") != 5:
    raise SystemExit("v61en fixture manifest should keep five blockers open")

fixture_global = read_csv(root / "results/v61en_real_generation_intake_work_order_summary.csv")[0]
if fixture_global["selected_rendezvous_run_dir_supplied"] != "0":
    raise SystemExit("v61en did not restore canonical summary after fixture run")

fixture_rows = read_csv(fixture_run_dir / "real_generation_intake_work_order_rows.csv")
if [row["status"] for row in fixture_rows] != [
    "ready",
    "ready",
    "ready",
    "blocked",
    "blocked",
    "blocked",
    "ready",
    "blocked",
    "blocked",
    "blocked",
    "blocked",
]:
    raise SystemExit("v61en fixture work-order status sequence mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["selected-rendezvous-present"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61en selected/repo decisions should pass")
for gate in [
    "selected-generation-preflight",
    "selected-binding-candidate-preflight",
    "non-fixture-binding-source",
    "real-review-return-provenance",
    "real-prerequisite-binding",
    "real-generation-intake-handoff",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61en canonical decision should be blocked: {gate}")

work_order = (run_dir / "V61EN_REAL_GENERATION_INTAKE_WORK_ORDER.md").read_text(encoding="utf-8")
for snippet in [
    "selected_generation_result_receiver_preflight_ready=0",
    "selected_real_prerequisite_binding_ready=0",
    "real_generation_intake_handoff_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in work_order:
        raise SystemExit(f"v61en work order missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61en_real_generation_intake_work_order_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61en_real_generation_intake_work_order_ready") != 1:
    raise SystemExit("v61en manifest readiness mismatch")
if manifest.get("real_generation_intake_handoff_ready") != 0:
    raise SystemExit("v61en canonical manifest must keep real intake blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61en manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61en sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61en produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61en real generation intake work order smoke passed"
