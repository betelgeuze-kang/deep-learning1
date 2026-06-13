#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ev_return_bundle_downstream_replay_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/replay_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_downstream_replay_v61ev"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_BUNDLE_DIR="$RESULTS_DIR/v61et_real_generation_intake_return_bundle_preflight/fixture_return_bundle_input"

V61EU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null

V61EV_REUSE_EXISTING="${V61EV_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ev_return_bundle_downstream_replay_gate.sh" >/dev/null

V61EV_RUN_ID="fixture_downstream_replay_v61ev" \
V61EV_RETURN_BUNDLE_DIR="$FIXTURE_BUNDLE_DIR" \
V61EV_RETURN_BUNDLE_PROVENANCE="fixture-v61et-return-bundle" \
V61EV_RECEIPT_PROVENANCE="fixture-v61er-dispatch-receipt" \
V61EV_BINDING_PROVENANCE="fixture-v61et-review-return" \
V61EV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ev_return_bundle_downstream_replay_gate.sh" >/dev/null

V61EV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ev_return_bundle_downstream_replay_gate.sh" >/dev/null

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
    "v61ev_return_bundle_downstream_replay_gate_ready": "1",
    "return_bundle_dir_supplied": "0",
    "selected_fanout_candidate_preflight_ready": "0",
    "selected_fanout_real_preflight_ready": "0",
    "selected_dual_candidate_preflight_rendezvous_ready": "0",
    "selected_real_rendezvous_handoff_ready": "0",
    "selected_ready_work_order_rows": "1",
    "selected_real_work_order_handoff_ready": "0",
    "selected_receipt_to_intake_handoff_ready": "0",
    "downstream_replay_candidate_ready": "0",
    "downstream_replay_real_ready": "0",
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ev": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ev {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_bundle_downstream_replay_stage_rows.csv",
    "return_bundle_downstream_replay_requirement_rows.csv",
    "return_bundle_downstream_replay_command_rows.csv",
    "V61EV_RETURN_BUNDLE_DOWNSTREAM_REPLAY_BOUNDARY.md",
    "v61ev_return_bundle_downstream_replay_gate_manifest.json",
    "selected_v61eu/return_bundle_fanout_stage_rows.csv",
    "selected_v61em/dual_preflight_rendezvous_stage_rows.csv",
    "selected_v61en/real_generation_intake_work_order_rows.csv",
    "selected_v61es/dispatch_receipt_to_generation_intake_stage_rows.csv",
    "source_summaries/v61eu_real_generation_intake_return_bundle_fanout_gate_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ev artifact: {rel}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "return_bundle_downstream_replay_requirement_rows.csv")}
for req in ["fanout-candidate-preflight", "fanout-real-preflight", "dual-candidate-rendezvous", "real-rendezvous-handoff", "work-order-progress", "real-work-order-handoff", "receipt-to-intake-handoff", "actual-generation"]:
    if requirements[req] != "blocked":
        raise SystemExit(f"v61ev canonical requirement should be blocked: {req}")

fixture_summary = read_csv(fixture_run_dir / "return_bundle_downstream_replay_stage_rows.csv")
fixture_stages = {row["stage_id"]: row["ready"] for row in fixture_summary}
for stage in ["01-return-bundle-fanout-candidate", "03-dual-preflight-rendezvous", "05-work-order-progress"]:
    if fixture_stages[stage] != "1":
        raise SystemExit(f"v61ev fixture stage should pass: {stage}")
for stage in ["02-return-bundle-fanout-real", "04-real-rendezvous-handoff", "06-real-work-order-handoff", "07-receipt-to-intake-handoff", "08-actual-generation"]:
    if fixture_stages[stage] != "0":
        raise SystemExit(f"v61ev fixture stage should stay blocked: {stage}")

fixture_manifest = json.loads((fixture_run_dir / "v61ev_return_bundle_downstream_replay_gate_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("downstream_replay_candidate_ready") != 1:
    raise SystemExit("v61ev fixture downstream candidate replay should be ready")
if fixture_manifest.get("downstream_replay_real_ready") != 0:
    raise SystemExit("v61ev fixture downstream real replay must stay blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61ev repo payload decision should pass")
for gate in ["downstream-candidate-replay", "downstream-real-replay", "receipt-to-intake-handoff", "downstream-row-acceptance", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ev canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EV_RETURN_BUNDLE_DOWNSTREAM_REPLAY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_bundle_dir_supplied=0",
    "downstream_replay_candidate_ready=0",
    "downstream_replay_real_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ev boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ev_return_bundle_downstream_replay_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ev_return_bundle_downstream_replay_gate_ready") != 1:
    raise SystemExit("v61ev manifest readiness mismatch")
if manifest.get("downstream_replay_real_ready") != 0:
    raise SystemExit("v61ev canonical manifest must keep real replay blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ev manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ev sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ev produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ev return bundle downstream replay gate smoke passed"
