#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fm_post_fl_real_manifest_external_review_return_work_order"
RUN_DIR="$RESULTS_DIR/$PREFIX/work_order_001"
FIXTURE_HANDOFF_DIR="$RESULTS_DIR/v61fl_post_fk_real_manifest_external_review_return_handoff_guard/fixture_dispatch_receipt_handoff_v61fl"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_work_order_v61fm"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_PACKAGE_DIR="$RUN_DIR/real_manifest_external_review_return_work_order"

V61FL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null

V61FM_REUSE_EXISTING="${V61FM_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null

"$WORK_PACKAGE_DIR/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.sh" >/dev/null

V61FM_RUN_ID="fixture_dispatch_receipt_work_order_v61fm" \
V61FM_HANDOFF_RUN_DIR="$FIXTURE_HANDOFF_DIR" \
V61FM_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null

V61FM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null

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
work_package_dir = run_dir / "real_manifest_external_review_return_work_order"


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
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": "1",
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": "1",
    "selected_handoff_dispatch_source_class": "none",
    "dispatch_archive_ready": "1",
    "dispatch_receipt_candidate_preflight_ready": "0",
    "real_dispatch_receipt_ready": "0",
    "required_review_return_artifacts": "6",
    "work_order_rows": "6",
    "immediately_preparable_work_order_rows": "6",
    "accepted_work_order_rows": "0",
    "acceptance_blocked_work_order_rows": "6",
    "field_work_rows": "32",
    "work_package_file_rows": "6",
    "metadata_only_work_package_file_rows": "6",
    "payload_like_work_package_file_rows": "0",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "external_review_return_ready": "0",
    "receipt_to_review_return_handoff_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "stage_rows": "7",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "4",
    "command_rows": "6",
    "ready_command_rows": "2",
    "blocked_command_rows": "4",
    "checkpoint_payload_bytes_downloaded_by_v61fm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fm {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fl_real_manifest_external_review_return_work_order_rows.csv",
    "post_fl_real_manifest_external_review_return_field_work_rows.csv",
    "post_fl_real_manifest_external_review_return_work_order_command_rows.csv",
    "post_fl_real_manifest_external_review_return_work_order_stage_rows.csv",
    "post_fl_real_manifest_external_review_return_work_order_requirement_rows.csv",
    "post_fl_real_manifest_external_review_return_work_order_file_rows.csv",
    "post_fl_real_manifest_external_review_return_work_order_metric_rows.csv",
    "V61FM_POST_FL_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER_BOUNDARY.md",
    "v61fm_post_fl_real_manifest_external_review_return_work_order_manifest.json",
    "real_manifest_external_review_return_work_order/REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.csv",
    "real_manifest_external_review_return_work_order/REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_FIELD_WORK_ROWS.csv",
    "real_manifest_external_review_return_work_order/REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.md",
    "real_manifest_external_review_return_work_order/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.sh",
    "real_manifest_external_review_return_work_order/WORK_ORDER_FILE_LIST.txt",
    "real_manifest_external_review_return_work_order/WORK_ORDER_SHA256SUMS.txt",
    "selected_handoff/handoff_metric_rows.csv",
    "source_v61fh/real_manifest_external_review_required_artifact_rows.csv",
    "source_v61fj/post_fi_real_manifest_external_review_return_template_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fm artifact: {rel}")

if not os.access(work_package_dir / "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.sh", os.X_OK):
    raise SystemExit("v61fm verifier must be executable")

work_rows = read_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_rows.csv")
if len(work_rows) != 6:
    raise SystemExit("v61fm expected six work rows")
if any(row["ready_to_prepare"] != "1" for row in work_rows):
    raise SystemExit("v61fm all work rows should be ready to prepare")
if any(row["accepted_now"] != "0" or row["acceptance_blocked"] != "1" for row in work_rows):
    raise SystemExit("v61fm work rows must stay unaccepted")
if sum(row["blocks_actual_generation"] == "1" for row in work_rows) != 6:
    raise SystemExit("v61fm every work row should block generation")

field_rows = read_csv(run_dir / "post_fl_real_manifest_external_review_return_field_work_rows.csv")
if len(field_rows) != 32:
    raise SystemExit("v61fm expected 32 field rows")

files = read_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_file_rows.csv")
if len(files) != 6:
    raise SystemExit("v61fm expected six work package files")
if any(row["metadata_only_file"] != "1" for row in files):
    raise SystemExit("v61fm files must be metadata-only")
if any(row["payload_like_file"] != "0" for row in files):
    raise SystemExit("v61fm work package includes payload-like file")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_requirement_rows.csv")}
for requirement in [
    "v61fl-handoff-guard",
    "v61fh-review-return-contract",
    "work-order-issued",
    "all-work-ready-to-prepare",
    "repo-checkpoint-payload",
]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61fm requirement should pass: {requirement}")
for requirement in ["accepted-review-return-artifacts", "external-review-return", "actual-generation"]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61fm requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fl-handoff-guard",
    "v61fh-review-return-contract",
    "work-order-issued",
    "all-work-ready-to-prepare",
    "repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fm decision should pass: {gate}")
for gate in ["accepted-review-return-artifacts", "external-review-return", "actual-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fm decision should be blocked: {gate}")

commands = read_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "0", "0"]:
    raise SystemExit("v61fm canonical command readiness mismatch")

stages = {row["stage_id"]: row["status"] for row in read_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_stage_rows.csv")}
for stage in ["01-dispatch-package", "02-return-intake-contract", "03-work-order-issued"]:
    if stages[stage] != "ready":
        raise SystemExit(f"v61fm stage should be ready: {stage}")
for stage in ["04-real-review-return-supplied", "05-review-return-accepted", "06-replay-row-acceptance", "07-actual-generation"]:
    if stages[stage] != "blocked":
        raise SystemExit(f"v61fm stage should be blocked: {stage}")

fixture_metric = read_csv(fixture_run_dir / "post_fl_real_manifest_external_review_return_work_order_metric_rows.csv")[0]
fixture_expected = {
    "selected_handoff_dispatch_source_class": "fixture-v61fk-dispatch-receipt",
    "dispatch_receipt_candidate_preflight_ready": "1",
    "real_dispatch_receipt_ready": "0",
    "work_order_rows": "6",
    "immediately_preparable_work_order_rows": "6",
    "accepted_work_order_rows": "0",
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fm fixture {field}: expected {value}, got {fixture_metric.get(field)}")

boundary = (run_dir / "V61FM_POST_FL_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "work_order_rows=6",
    "immediately_preparable_work_order_rows=6",
    "accepted_work_order_rows=0",
    "acceptance_blocked_work_order_rows=6",
    "field_work_rows=32",
    "accepted_review_return_artifacts=0/6",
    "external_review_return_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fm boundary missing snippet: {snippet}")

readme = (work_package_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.md").read_text(encoding="utf-8")
for snippet in ["six real review-return artifacts", "not accepted review evidence", "actual_model_generation_ready=0"]:
    if snippet not in readme:
        raise SystemExit(f"v61fm readme missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fm_post_fl_real_manifest_external_review_return_work_order_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fm_post_fl_real_manifest_external_review_return_work_order_ready") != 1:
    raise SystemExit("v61fm manifest readiness mismatch")
if manifest.get("accepted_work_order_rows") != 0:
    raise SystemExit("v61fm manifest must keep accepted work rows zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fm manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fm manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fm sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fm produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fm post-fl real manifest external review return work order smoke passed"
