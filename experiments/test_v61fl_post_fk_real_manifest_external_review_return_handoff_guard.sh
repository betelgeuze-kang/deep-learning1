#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fl_post_fk_real_manifest_external_review_return_handoff_guard"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
FIXTURE_DISPATCH_DIR="$RESULTS_DIR/v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate/fixture_dispatch_receipt_preflight_v61fk"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_handoff_v61fl"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61FK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null

V61FL_REUSE_EXISTING="${V61FL_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null

V61FL_RUN_ID="fixture_dispatch_receipt_handoff_v61fl" \
V61FL_DISPATCH_RUN_DIR="$FIXTURE_DISPATCH_DIR" \
V61FL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null

V61FL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null

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
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": "1",
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "selected_dispatch_source_class": "none",
    "dispatch_archive_ready": "1",
    "dispatch_archive_member_files": "23",
    "dispatch_receipt_candidate_preflight_ready": "0",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "review_return_intake_contract_ready": "1",
    "required_review_return_artifacts": "6",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "receipt_to_review_return_handoff_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "stage_rows": "9",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "7",
    "blocker_rows": "10",
    "open_blocker_rows": "10",
    "command_rows": "5",
    "ready_command_rows": "2",
    "blocked_command_rows": "3",
    "checkpoint_payload_bytes_downloaded_by_v61fl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fl {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv",
    "post_fk_real_manifest_external_review_return_handoff_requirement_rows.csv",
    "post_fk_real_manifest_external_review_return_handoff_blocker_rows.csv",
    "post_fk_real_manifest_external_review_return_handoff_command_rows.csv",
    "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61FL_POST_FK_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_HANDOFF_GUARD_BOUNDARY.md",
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_manifest.json",
    "selected_dispatch/dispatch_metric_rows.csv",
    "selected_dispatch/dispatch_check_rows.csv",
    "selected_review_return/review_return_artifact_status_rows.csv",
    "selected_review_return/review_return_acceptance_rows.csv",
    "source_summaries/v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_summary.csv",
    "source_summaries/v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
    "source_summaries/v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
    "source_v61fi/post_fh_real_manifest_external_review_acceptance_bridge_rows.csv",
    "source_v61fi/post_fh_real_manifest_external_review_acceptance_blocker_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fl artifact: {rel}")

stages = {row["stage_id"]: row for row in read_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv")}
for stage_id in ["01-dispatch-archive", "04-review-return-intake-contract"]:
    if stages[stage_id]["status"] != "ready":
        raise SystemExit(f"v61fl canonical stage should be ready: {stage_id}")
for stage_id in [
    "02-dispatch-receipt-candidate",
    "03-real-dispatch-receipt",
    "05-review-return-candidate",
    "06-external-review-return-accepted",
    "07-receipt-to-review-return-handoff",
    "08-replay-row-acceptance",
    "09-actual-generation",
]:
    if stages[stage_id]["status"] != "blocked":
        raise SystemExit(f"v61fl canonical stage should be blocked: {stage_id}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_requirement_rows.csv")}
for requirement in ["v61fk-dispatch-archive", "v61fh-review-return-intake-contract", "repo-checkpoint-payload"]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61fl requirement should pass: {requirement}")
for requirement in [
    "dispatch-receipt-candidate",
    "real-dispatch-receipt",
    "external-review-return",
    "receipt-to-review-return-handoff",
    "replay-row-acceptance",
    "actual-generation",
]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61fl requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61fk-dispatch-archive", "v61fh-review-return-intake-contract", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fl decision should pass: {gate}")
for gate in [
    "dispatch-receipt-candidate",
    "real-dispatch-receipt",
    "external-review-return",
    "receipt-to-review-return-handoff",
    "replay-row-acceptance",
    "actual-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fl decision should be blocked: {gate}")

commands = read_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "0"]:
    raise SystemExit("v61fl canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv")[0]
fixture_expected = {
    "selected_dispatch_source_class": "fixture-v61fk-dispatch-receipt",
    "dispatch_archive_ready": "1",
    "dispatch_receipt_candidate_preflight_ready": "1",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "receipt_to_review_return_handoff_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "6",
    "ready_command_rows": "2",
    "blocked_command_rows": "3",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fl fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_stages = {row["stage_id"]: row for row in read_csv(fixture_run_dir / "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv")}
if fixture_stages["02-dispatch-receipt-candidate"]["status"] != "ready":
    raise SystemExit("v61fl fixture receipt candidate stage should be ready")
for stage_id in [
    "03-real-dispatch-receipt",
    "05-review-return-candidate",
    "06-external-review-return-accepted",
    "07-receipt-to-review-return-handoff",
    "08-replay-row-acceptance",
    "09-actual-generation",
]:
    if fixture_stages[stage_id]["status"] != "blocked":
        raise SystemExit(f"v61fl fixture stage should stay blocked: {stage_id}")

boundary = (run_dir / "V61FL_POST_FK_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_HANDOFF_GUARD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "dispatch_archive_ready=1",
    "real_dispatch_receipt_ready=0",
    "review_return_intake_contract_ready=1",
    "accepted_review_return_artifacts=0/6",
    "external_review_return_ready=0",
    "receipt_to_review_return_handoff_ready=0",
    "real_return_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fl boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready") != 1:
    raise SystemExit("v61fl manifest readiness mismatch")
if manifest.get("receipt_to_review_return_handoff_ready") != 0:
    raise SystemExit("v61fl canonical manifest must keep handoff blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fl manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fl manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fl sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fl produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fl post-fk real manifest external review return handoff guard smoke passed"
