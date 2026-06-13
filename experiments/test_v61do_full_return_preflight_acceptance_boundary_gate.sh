#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61do_full_return_preflight_acceptance_boundary_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/boundary_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DO_REUSE_EXISTING="${V61DO_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v61do_full_return_preflight_acceptance_boundary_gate_ready": "1",
    "v61dn_residual_return_completion_gate_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "source_gate_rows": "3",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "boundary_stage_rows": "9",
    "ready_boundary_stage_rows": "0",
    "blocked_boundary_stage_rows": "9",
    "boundary_command_rows": "3",
    "ready_boundary_command_rows": "2",
    "critical_preflight_pass_rows": "0",
    "critical_artifact_rows": "10",
    "critical_preflight_ready": "0",
    "residual_preflight_pass_rows": "0",
    "residual_artifact_rows": "71",
    "residual_completion_ready": "0",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "preflight_only_gap_detected": "0",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "review_return_ready": "0",
    "v53_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "actual_model_generation_ready": "0",
    "acceptance_boundary_closed": "0",
    "checkpoint_payload_bytes_downloaded_by_v61do": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61do {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "full_return_preflight_acceptance_boundary_stage_rows.csv",
    "full_return_preflight_acceptance_boundary_command_rows.csv",
    "full_return_preflight_acceptance_boundary_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DO_FULL_RETURN_PREFLIGHT_ACCEPTANCE_BOUNDARY_GATE.md",
    "v61do_full_return_preflight_acceptance_boundary_gate_manifest.json",
    "source_v61dn/v61dn_residual_return_completion_gate_summary.csv",
    "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61do artifact: {rel}")

stages = read_csv(run_dir / "full_return_preflight_acceptance_boundary_stage_rows.csv")
if len(stages) != 9 or any(row["status"] != "blocked" for row in stages):
    raise SystemExit("v61do default stages should all be blocked")
commands = read_csv(run_dir / "full_return_preflight_acceptance_boundary_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0"]:
    raise SystemExit("v61do default command readiness mismatch")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["preflight-is-not-acceptance", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61do decision should pass: {gate}")
for gate in [row["stage_id"] for row in stages]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61do default gate should be blocked: {gate}")

boundary = (run_dir / "V61DO_FULL_RETURN_PREFLIGHT_ACCEPTANCE_BOUNDARY_GATE.md").read_text(encoding="utf-8")
for snippet in [
    "boundary_stage_rows=9",
    "ready_boundary_stage_rows=0",
    "blocked_boundary_stage_rows=9",
    "critical_preflight_pass_rows=0/10",
    "residual_preflight_pass_rows=0/71",
    "full_preflight_pass_rows=0/81",
    "preflight_only_gap_detected=0",
    "answer_review_accepted_rows=0/7000",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61do=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61do boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61do_full_return_preflight_acceptance_boundary_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61do_full_return_preflight_acceptance_boundary_gate_ready") != 1:
    raise SystemExit("v61do manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61do manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61do sha256 mismatch: {rel}")
PY

FULL_PREFLIGHT_BUNDLE_DIR="$(mktemp -d /tmp/v61do_full_preflight_bundle.XXXXXX)"
trap 'rm -rf "$FULL_PREFLIGHT_BUNDLE_DIR"' EXIT
python3 - "$ROOT_DIR" "$FULL_PREFLIGHT_BUNDLE_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle = Path(sys.argv[2])
checklist = root / "results/v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv"
with checklist.open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        rel = row["final_return_bundle_relative_path"]
        path = bundle / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix == ".json":
            path.write_text(json.dumps({"synthetic_full_preflight_only": True}) + "\n", encoding="utf-8")
        else:
            path.write_text("synthetic_full_preflight_only\n", encoding="utf-8")
PY

SUPPLIED_RUN_ID="boundary_full_preflight_only_smoke"
SUPPLIED_RUN_DIR="$RESULTS_DIR/$PREFIX/$SUPPLIED_RUN_ID"
V61DO_RUN_ID="$SUPPLIED_RUN_ID" \
V61DO_RETURN_BUNDLE_DIR="$FULL_PREFLIGHT_BUNDLE_DIR" \
V61DO_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null

python3 - "$SUPPLIED_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "return_bundle_dir_supplied": "1",
    "return_bundle_dir_exists": "1",
    "boundary_stage_rows": "9",
    "ready_boundary_stage_rows": "3",
    "blocked_boundary_stage_rows": "6",
    "critical_preflight_pass_rows": "10",
    "critical_preflight_ready": "1",
    "residual_preflight_pass_rows": "71",
    "residual_completion_ready": "1",
    "full_preflight_pass_rows": "81",
    "return_bundle_preflight_pass": "1",
    "preflight_only_gap_detected": "1",
    "accepted_dispatch_receipt_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "answer_review_accepted_rows": "0",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "acceptance_boundary_closed": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61do full-preflight {field}: expected {value}, got {summary.get(field)}")

stages = {row["stage_id"]: row for row in read_csv(run_dir / "full_return_preflight_acceptance_boundary_stage_rows.csv")}
ready_stage_ids = {stage_id for stage_id, row in stages.items() if row["status"] == "ready"}
if ready_stage_ids != {"01-critical-preflight", "02-residual-completion", "03-full-return-preflight"}:
    raise SystemExit(f"v61do full-preflight ready ids mismatch: {ready_stage_ids}")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["01-critical-preflight", "02-residual-completion", "03-full-return-preflight", "preflight-is-not-acceptance", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61do full-preflight decision should pass: {gate}")
for gate in [
    "04-dispatch-receipt-acceptance",
    "05-review-chunk-acceptance",
    "06-review-row-acceptance",
    "07-generation-execution",
    "08-generation-result-acceptance",
    "09-actual-generation-ready",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61do full-preflight decision should stay blocked: {gate}")
boundary = (run_dir / "V61DO_FULL_RETURN_PREFLIGHT_ACCEPTANCE_BOUNDARY_GATE.md").read_text(encoding="utf-8")
for snippet in [
    "ready_boundary_stage_rows=3",
    "blocked_boundary_stage_rows=6",
    "critical_preflight_pass_rows=10/10",
    "residual_preflight_pass_rows=71/71",
    "full_preflight_pass_rows=81/81",
    "return_bundle_preflight_pass=1",
    "preflight_only_gap_detected=1",
    "answer_review_accepted_rows=0/7000",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61do full-preflight boundary missing snippet: {snippet}")
manifest = json.loads((run_dir / "v61do_full_return_preflight_acceptance_boundary_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("preflight_only_gap_detected") != 1:
    raise SystemExit("v61do full-preflight manifest should detect preflight-only gap")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61do full-preflight manifest must keep generation blocked")
PY

# Restore canonical no-return summaries for upstream and this gate.
V61DL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dl_critical_return_contract_preflight_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null
V61DN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null
V61DO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null

if find "$RUN_DIR" "$SUPPLIED_RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61do produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61do full return preflight acceptance boundary gate smoke passed"
