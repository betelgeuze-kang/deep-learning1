#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ex_generation_acceptance_closure_work_order"
RUN_DIR="$RESULTS_DIR/$PREFIX/work_order_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_acceptance_closure_v61ex"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_BRIDGE_DIR="$RESULTS_DIR/v61ew_downstream_replay_to_acceptance_bridge/fixture_acceptance_bridge_v61ew"

V61EW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ew_downstream_replay_to_acceptance_bridge.sh" >/dev/null

V61EX_REUSE_EXISTING="${V61EX_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh" >/dev/null

V61EX_RUN_ID="fixture_acceptance_closure_v61ex" \
V61EX_ACCEPTANCE_BRIDGE_RUN_DIR="$FIXTURE_BRIDGE_DIR" \
V61EX_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh" >/dev/null

V61EX_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh" >/dev/null

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
    "v61ex_generation_acceptance_closure_work_order_ready": "1",
    "selected_acceptance_bridge_candidate_ready": "0",
    "selected_acceptance_bridge_real_ready": "0",
    "selected_downstream_replay_real_ready": "0",
    "v61bt_result_intake_ready": "0",
    "v61de_post_review_handoff_ready": "0",
    "v61cu_result_acceptance_ready": "0",
    "ready_work_order_rows": "2",
    "open_blocker_rows": "11",
    "closure_command_rows": "8",
    "ready_closure_command_rows": "1",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ex": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ex {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "generation_acceptance_closure_work_order_rows.csv",
    "generation_acceptance_closure_blocker_rows.csv",
    "generation_acceptance_closure_command_rows.csv",
    "V61EX_GENERATION_ACCEPTANCE_CLOSURE_WORK_ORDER_BOUNDARY.md",
    "v61ex_generation_acceptance_closure_work_order_manifest.json",
    "selected_acceptance_bridge/downstream_replay_to_acceptance_stage_rows.csv",
    "selected_acceptance_bridge/v61ew_downstream_replay_to_acceptance_bridge_manifest.json",
    "source_summaries/v61ew_downstream_replay_to_acceptance_bridge_summary.csv",
    "source_summaries/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_summaries/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "source_summaries/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "source_summaries/v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ex artifact: {rel}")

work_rows = {row["work_item_id"]: row for row in read_csv(run_dir / "generation_acceptance_closure_work_order_rows.csv")}
for item_id in ["01-selected-v61ew-bridge", "08-v61ct-operator-bundle"]:
    if work_rows[item_id]["ready"] != "1":
        raise SystemExit(f"v61ex canonical work row should be ready: {item_id}")
for item_id in [
    "02-bridge-candidate",
    "03-bridge-real",
    "04-v61bt-prerequisite-binding",
    "05-v61bt-result-artifacts",
    "06-v61bt-result-rows",
    "07-v61de-review-return",
    "09-v61de-generation-execution",
    "10-v61de-result-artifacts",
    "11-v61cu-generation-admission",
    "12-v61cu-result-rows",
    "13-actual-generation-claim",
]:
    if work_rows[item_id]["ready"] != "0":
        raise SystemExit(f"v61ex canonical work row should stay blocked: {item_id}")

blockers = read_csv(run_dir / "generation_acceptance_closure_blocker_rows.csv")
if len(blockers) != 11:
    raise SystemExit(f"v61ex canonical blocker row count mismatch: {len(blockers)}")

fixture_work_rows = {row["work_item_id"]: row for row in read_csv(fixture_run_dir / "generation_acceptance_closure_work_order_rows.csv")}
for item_id in ["01-selected-v61ew-bridge", "02-bridge-candidate", "08-v61ct-operator-bundle"]:
    if fixture_work_rows[item_id]["ready"] != "1":
        raise SystemExit(f"v61ex fixture work row should be ready: {item_id}")
for item_id in [
    "03-bridge-real",
    "04-v61bt-prerequisite-binding",
    "05-v61bt-result-artifacts",
    "06-v61bt-result-rows",
    "07-v61de-review-return",
    "09-v61de-generation-execution",
    "10-v61de-result-artifacts",
    "11-v61cu-generation-admission",
    "12-v61cu-result-rows",
    "13-actual-generation-claim",
]:
    if fixture_work_rows[item_id]["ready"] != "0":
        raise SystemExit(f"v61ex fixture work row should stay blocked: {item_id}")

fixture_manifest = json.loads((fixture_run_dir / "v61ex_generation_acceptance_closure_work_order_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("selected_acceptance_bridge_candidate_ready") != 1:
    raise SystemExit("v61ex fixture bridge candidate should be ready")
if fixture_manifest.get("generation_acceptance_closure_ready") != 0:
    raise SystemExit("v61ex fixture closure must stay blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["work-order-shape"] != "pass":
    raise SystemExit("v61ex work-order-shape decision should pass")
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61ex repo payload decision should pass")
for gate in [
    "bridge-candidate",
    "bridge-real",
    "v61bt-result-intake",
    "v61de-post-review-handoff",
    "v61cu-result-acceptance",
    "generation-acceptance-closure",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ex canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EX_GENERATION_ACCEPTANCE_CLOSURE_WORK_ORDER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_acceptance_bridge_candidate_ready=0",
    "generation_acceptance_closure_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ex boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ex_generation_acceptance_closure_work_order_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ex_generation_acceptance_closure_work_order_ready") != 1:
    raise SystemExit("v61ex manifest readiness mismatch")
if manifest.get("ready_work_order_rows") != 2:
    raise SystemExit("v61ex canonical ready work rows mismatch")
if manifest.get("open_blocker_rows") != 11:
    raise SystemExit("v61ex canonical open blockers mismatch")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ex manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ex sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ex produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ex generation acceptance closure work order smoke passed"
