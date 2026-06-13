#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61es_dispatch_receipt_to_generation_intake_handoff_guard"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_receipt_guard_v61es"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_RECEIPT_PREFLIGHT_DIR="$RESULTS_DIR/v61er_real_generation_intake_dispatch_receipt_preflight/fixture_dispatch_receipt_preflight_v61er"

V61ER_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null
V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61en_real_generation_intake_work_order.sh" >/dev/null

V61ES_REUSE_EXISTING="${V61ES_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null

V61ES_RUN_ID="fixture_receipt_guard_v61es" \
V61ES_RECEIPT_PREFLIGHT_RUN_DIR="$FIXTURE_RECEIPT_PREFLIGHT_DIR" \
V61ES_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null

V61ES_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null

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
    "v61es_dispatch_receipt_to_generation_intake_handoff_guard_ready": "1",
    "selected_dispatch_receipt_candidate_preflight_ready": "0",
    "selected_real_dispatch_receipt_ready": "0",
    "selected_accepted_dispatch_receipt_rows": "0",
    "selected_dual_candidate_preflight_rendezvous_ready": "0",
    "selected_ready_work_order_rows": "1",
    "selected_open_blocker_rows": "6",
    "selected_real_generation_intake_handoff_ready": "0",
    "receipt_to_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61es": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61es {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dispatch_receipt_to_generation_intake_stage_rows.csv",
    "dispatch_receipt_to_generation_intake_requirement_rows.csv",
    "dispatch_receipt_to_generation_intake_blocker_rows.csv",
    "dispatch_receipt_to_generation_intake_command_rows.csv",
    "V61ES_DISPATCH_RECEIPT_TO_GENERATION_INTAKE_HANDOFF_BOUNDARY.md",
    "v61es_dispatch_receipt_to_generation_intake_handoff_guard_manifest.json",
    "selected_receipt_preflight/receipt_preflight_metric_rows.csv",
    "selected_work_order/work_order_rows.csv",
    "source_summaries/v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv",
    "source_summaries/v61en_real_generation_intake_work_order_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61es artifact: {rel}")

stages = {row["stage_id"]: row["ready"] for row in read_csv(run_dir / "dispatch_receipt_to_generation_intake_stage_rows.csv")}
if stages["01-v61er-receipt-preflight-surface"] != "1" or stages["04-v61en-intake-work-order"] != "1":
    raise SystemExit("v61es source stages should be ready")
for stage in [
    "02-dispatch-receipt-candidate",
    "03-real-dispatch-receipt",
    "05-dual-candidate-generation-intake",
    "06-real-generation-intake-handoff",
    "07-receipt-to-intake-handoff",
    "08-actual-generation",
]:
    if stages[stage] != "0":
        raise SystemExit(f"v61es canonical stage should be blocked: {stage}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "dispatch_receipt_to_generation_intake_requirement_rows.csv")}
for req in ["v61er-preflight-surface", "v61en-work-order", "repo-checkpoint-payload"]:
    if requirements[req] != "pass":
        raise SystemExit(f"v61es requirement should pass: {req}")
for req in ["dispatch-receipt-candidate", "real-dispatch-receipt", "real-generation-intake-handoff", "receipt-to-intake-handoff", "actual-generation"]:
    if requirements[req] != "blocked":
        raise SystemExit(f"v61es requirement should be blocked: {req}")

commands = read_csv(run_dir / "dispatch_receipt_to_generation_intake_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "0"]:
    raise SystemExit("v61es canonical command readiness mismatch")

fixture_summary = read_csv(fixture_run_dir / "sha256_manifest.csv")
if not fixture_summary:
    raise SystemExit("v61es fixture run did not produce hash rows")
fixture_metric = read_csv(fixture_run_dir / "dispatch_receipt_to_generation_intake_stage_rows.csv")
fixture_stages = {row["stage_id"]: row["ready"] for row in fixture_metric}
if fixture_stages["02-dispatch-receipt-candidate"] != "1":
    raise SystemExit("v61es fixture receipt candidate should be ready")
for stage in ["03-real-dispatch-receipt", "06-real-generation-intake-handoff", "07-receipt-to-intake-handoff", "08-actual-generation"]:
    if fixture_stages[stage] != "0":
        raise SystemExit(f"v61es fixture stage should stay blocked: {stage}")
fixture_summary_row = read_csv(fixture_run_dir.parent.parent / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv")[0]
if fixture_summary_row["selected_dispatch_receipt_candidate_preflight_ready"] != "0":
    raise SystemExit("v61es canonical summary was not restored after fixture")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61er-preflight-surface", "v61en-work-order", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61es decision should pass: {gate}")
for gate in ["dispatch-receipt-candidate", "real-dispatch-receipt", "real-generation-intake", "receipt-to-intake-handoff", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61es canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61ES_DISPATCH_RECEIPT_TO_GENERATION_INTAKE_HANDOFF_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_dispatch_receipt_candidate_preflight_ready=0",
    "selected_real_dispatch_receipt_ready=0",
    "receipt_to_intake_handoff_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61es boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61es_dispatch_receipt_to_generation_intake_handoff_guard_ready") != 1:
    raise SystemExit("v61es manifest readiness mismatch")
if manifest.get("receipt_to_intake_handoff_ready") != 0:
    raise SystemExit("v61es manifest must keep handoff blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61es manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61es sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61es produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61es dispatch receipt to generation intake handoff guard smoke passed"
