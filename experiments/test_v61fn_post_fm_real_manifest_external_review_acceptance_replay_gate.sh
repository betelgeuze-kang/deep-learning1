#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/replay_001"
FIXTURE_RETURN_DIR="$RESULTS_DIR/v61fh_post_fg_real_manifest_external_review_return_intake/fixture_intake_v61fh"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_return_candidate_replay_v61fn"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61FM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null

V61FN_REUSE_EXISTING="${V61FN_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null

V61FN_RUN_ID="fixture_return_candidate_replay_v61fn" \
V61FN_RETURN_INTAKE_RUN_DIR="$FIXTURE_RETURN_DIR" \
V61FN_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null

V61FN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null

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
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": "1",
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": "1",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": "1",
    "v61fe_post_fd_real_return_replay_admission_guard_ready": "1",
    "selected_return_source_class": "canonical-no-return",
    "selected_return_artifacts": "6",
    "selected_return_artifacts_preflight_pass": "0",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "dispatch_receipt_candidate_preflight_ready": "0",
    "real_dispatch_receipt_ready": "0",
    "receipt_to_review_return_handoff_ready": "0",
    "acceptance_bridge_refresh_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "stage_rows": "10",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "8",
    "blocker_rows": "7",
    "open_blocker_rows": "7",
    "command_rows": "6",
    "ready_command_rows": "1",
    "blocked_command_rows": "5",
    "checkpoint_payload_bytes_downloaded_by_v61fn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fn {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fm_real_manifest_external_review_acceptance_replay_stage_rows.csv",
    "post_fm_real_manifest_external_review_acceptance_replay_requirement_rows.csv",
    "post_fm_real_manifest_external_review_acceptance_replay_command_rows.csv",
    "post_fm_real_manifest_external_review_acceptance_replay_blocker_rows.csv",
    "post_fm_real_manifest_external_review_acceptance_replay_metric_rows.csv",
    "V61FN_POST_FM_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_REPLAY_GATE_BOUNDARY.md",
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_manifest.json",
    "selected_return_intake/return_artifact_status_rows.csv",
    "selected_return_intake/return_manifest.json",
    "selected_handoff/handoff_metric_rows.csv",
    "source_summaries/v61fm_post_fl_real_manifest_external_review_return_work_order_summary.csv",
    "source_summaries/v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
    "source_summaries/v61fe_post_fd_real_return_replay_admission_guard_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fn artifact: {rel}")

stages = {row["stage_id"]: row["status"] for row in read_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_stage_rows.csv")}
for stage in ["01-work-order-issued", "02-return-intake-selected"]:
    if stages[stage] != "ready":
        raise SystemExit(f"v61fn stage should be ready: {stage}")
for stage in [
    "03-return-candidate-preflight",
    "04-external-review-return-accepted",
    "05-acceptance-bridge-refresh",
    "06-handoff-refresh",
    "07-replay-admission",
    "08-row-acceptance",
    "09-generation-execution",
    "10-actual-generation",
]:
    if stages[stage] != "blocked":
        raise SystemExit(f"v61fn stage should be blocked: {stage}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_requirement_rows.csv")}
for requirement in ["v61fm-work-order", "selected-return-intake", "repo-checkpoint-payload"]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61fn requirement should pass: {requirement}")
for requirement in [
    "return-candidate-preflight",
    "external-review-return",
    "acceptance-bridge-refresh",
    "receipt-to-review-return-handoff",
    "real-return-replay-admission",
    "row-acceptance",
    "actual-generation",
]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61fn requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61fm-work-order", "selected-return-intake", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fn decision should pass: {gate}")
for gate in [
    "return-candidate-preflight",
    "external-review-return",
    "acceptance-bridge-refresh",
    "receipt-to-review-return-handoff",
    "real-return-replay-admission",
    "row-acceptance",
    "actual-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fn decision should be blocked: {gate}")

commands = read_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "0", "0", "0", "0", "0"]:
    raise SystemExit("v61fn canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "post_fm_real_manifest_external_review_acceptance_replay_metric_rows.csv")[0]
fixture_expected = {
    "selected_return_source_class": "candidate-preflight-only",
    "selected_return_artifacts": "6",
    "selected_return_artifacts_preflight_pass": "6",
    "candidate_external_review_return_ready": "1",
    "external_review_return_ready": "0",
    "accepted_review_return_artifacts": "6",
    "missing_review_return_artifacts": "0",
    "receipt_to_review_return_handoff_ready": "0",
    "acceptance_bridge_refresh_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "7",
    "ready_command_rows": "1",
    "blocked_command_rows": "5",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fn fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_stages = {row["stage_id"]: row["status"] for row in read_csv(fixture_run_dir / "post_fm_real_manifest_external_review_acceptance_replay_stage_rows.csv")}
if fixture_stages["03-return-candidate-preflight"] != "ready":
    raise SystemExit("v61fn fixture candidate return stage should be ready")
for stage in [
    "04-external-review-return-accepted",
    "05-acceptance-bridge-refresh",
    "06-handoff-refresh",
    "07-replay-admission",
    "08-row-acceptance",
    "09-generation-execution",
    "10-actual-generation",
]:
    if fixture_stages[stage] != "blocked":
        raise SystemExit(f"v61fn fixture stage should stay blocked: {stage}")

boundary = (run_dir / "V61FN_POST_FM_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_REPLAY_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_return_source_class=canonical-no-return",
    "selected_return_artifacts_preflight_pass=0/6",
    "candidate_external_review_return_ready=0",
    "external_review_return_ready=0",
    "receipt_to_review_return_handoff_ready=0",
    "real_return_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fn boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready") != 1:
    raise SystemExit("v61fn manifest readiness mismatch")
if manifest.get("external_review_return_ready") != 0:
    raise SystemExit("v61fn manifest must keep external review blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fn manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fn manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fn sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fn produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fn post-fm real manifest external review acceptance replay gate smoke passed"
