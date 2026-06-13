#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint"
RUN_DIR="$RESULTS_DIR/$PREFIX/entrypoint_001"
FIXTURE_RETURN_DIR="$RESULTS_DIR/v61fh_post_fg_real_manifest_external_review_return_intake/fixture_review_return"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_return_entrypoint_v61fo"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ENTRYPOINT_DIR="$RUN_DIR/real_manifest_external_review_return_replay_entrypoint"

V61FN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null

V61FO_REUSE_EXISTING="${V61FO_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null

"$ENTRYPOINT_DIR/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.sh" >/dev/null

if "$ENTRYPOINT_DIR/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh" >/tmp/v61fo_should_not_run.out 2>/tmp/v61fo_should_not_run.err; then
  echo "v61fo guarded entrypoint unexpectedly ran without env" >&2
  exit 1
fi

V61FO_RUN_ID="fixture_return_entrypoint_v61fo" \
V61FO_REVIEW_RETURN_DIR="$FIXTURE_RETURN_DIR" \
V61FO_REVIEW_RETURN_PROVENANCE="fixture-v61fo-review-return" \
V61FO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null

V61FO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
entrypoint_dir = run_dir / "real_manifest_external_review_return_replay_entrypoint"


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
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": "1",
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": "1",
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": "1",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "review_return_provenance": "unspecified",
    "real_review_return_provenance_asserted": "0",
    "fixture_return_provenance": "0",
    "replay_entrypoint_ready": "1",
    "replay_entrypoint_admitted": "0",
    "required_env_rows": "2",
    "entrypoint_env_rows": "5",
    "entrypoint_file_rows": "5",
    "metadata_only_entrypoint_file_rows": "5",
    "payload_like_entrypoint_file_rows": "0",
    "stage_rows": "8",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "6",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fo {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fn_real_manifest_external_review_return_replay_entrypoint_env_rows.csv",
    "post_fn_real_manifest_external_review_return_replay_entrypoint_command_rows.csv",
    "post_fn_real_manifest_external_review_return_replay_entrypoint_stage_rows.csv",
    "post_fn_real_manifest_external_review_return_replay_entrypoint_requirement_rows.csv",
    "post_fn_real_manifest_external_review_return_replay_entrypoint_file_rows.csv",
    "post_fn_real_manifest_external_review_return_replay_entrypoint_metric_rows.csv",
    "V61FO_POST_FN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md",
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_manifest.json",
    "real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh",
    "real_manifest_external_review_return_replay_entrypoint/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.sh",
    "real_manifest_external_review_return_replay_entrypoint/REPLAY_ENTRYPOINT_ENV.template",
    "real_manifest_external_review_return_replay_entrypoint/REPLAY_ENTRYPOINT_MANIFEST.json",
    "real_manifest_external_review_return_replay_entrypoint/REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.md",
    "source_summaries/v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_summary.csv",
    "source_artifacts/v61fn_stage_rows.csv",
    "source_artifacts/v61fm_work_order_rows.csv",
    "source_artifacts/v61fh_required_artifacts.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fo artifact: {rel}")

if not os.access(entrypoint_dir / "RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", os.X_OK):
    raise SystemExit("v61fo guarded entrypoint must be executable")
if not os.access(entrypoint_dir / "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.sh", os.X_OK):
    raise SystemExit("v61fo verifier must be executable")

env_rows = read_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_env_rows.csv")
if len(env_rows) != 5:
    raise SystemExit("v61fo expected five env rows")
if sum(row["required"] == "1" for row in env_rows) != 2:
    raise SystemExit("v61fo expected two required env rows")

stages = {row["stage_id"]: row["status"] for row in read_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_stage_rows.csv")}
for stage in ["01-entrypoint-package", "02-work-order-ready"]:
    if stages[stage] != "ready":
        raise SystemExit(f"v61fo stage should be ready: {stage}")
for stage in [
    "03-review-return-dir-supplied",
    "04-review-return-dir-exists",
    "05-real-review-return-provenance",
    "06-entrypoint-admitted",
    "07-accepted-external-review",
    "08-actual-generation",
]:
    if stages[stage] != "blocked":
        raise SystemExit(f"v61fo stage should be blocked: {stage}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_requirement_rows.csv")}
for requirement in ["v61fn-replay-gate", "entrypoint-script", "repo-checkpoint-payload"]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61fo requirement should pass: {requirement}")
for requirement in [
    "review-return-dir-supplied",
    "review-return-dir-exists",
    "real-review-return-provenance",
    "replay-entrypoint-admitted",
    "external-review-return",
    "actual-generation",
]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61fo requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61fn-replay-gate", "entrypoint-script", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fo decision should pass: {gate}")
for gate in [
    "review-return-dir-supplied",
    "review-return-dir-exists",
    "real-review-return-provenance",
    "replay-entrypoint-admitted",
    "external-review-return",
    "actual-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fo decision should be blocked: {gate}")

commands = read_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0"]:
    raise SystemExit("v61fo canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_metric_rows.csv")[0]
fixture_expected = {
    "review_return_dir_supplied": "1",
    "review_return_dir_exists": "1",
    "review_return_provenance": "fixture-v61fo-review-return",
    "real_review_return_provenance_asserted": "0",
    "fixture_return_provenance": "1",
    "replay_entrypoint_admitted": "0",
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fo fixture {field}: expected {value}, got {fixture_metric.get(field)}")

boundary = (run_dir / "V61FO_POST_FN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "replay_entrypoint_ready=1",
    "review_return_dir_supplied=0",
    "real_review_return_provenance_asserted=0",
    "replay_entrypoint_admitted=0",
    "entrypoint_file_rows=5",
    "external_review_return_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fo boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready") != 1:
    raise SystemExit("v61fo manifest readiness mismatch")
if manifest.get("replay_entrypoint_admitted") != 0:
    raise SystemExit("v61fo canonical manifest must keep entrypoint not admitted")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fo manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fo manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fo sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fo produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fo post-fn real manifest external review return replay entrypoint smoke passed"
