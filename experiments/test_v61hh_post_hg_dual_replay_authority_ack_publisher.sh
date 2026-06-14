#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hh_post_hg_dual_replay_authority_ack_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/authority_ack_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/dual_replay_authority_ack_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hh first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61hh checkpoint root"

V61HH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = Path(sys.argv[4])


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
    "v61hh_post_hg_dual_replay_authority_ack_publisher_ready": "1",
    "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready": "1",
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "form_dir_exists": "0",
    "operator_replay_handoff_exists": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "authority_ack_published": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hh default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_replay_authority_ack_source_rows.csv",
    "dual_replay_authority_ack_published_rows.csv",
    "dual_replay_authority_ack_stage_rows.csv",
    "dual_replay_authority_ack_command_rows.csv",
    "dual_replay_authority_ack_package_file_rows.csv",
    "V61HH_POST_HG_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER_BOUNDARY.md",
    "v61hh_post_hg_dual_replay_authority_ack_publisher_manifest.json",
    "v61hh_post_hg_dual_replay_authority_ack_publisher_summary.csv",
    "v61hh_post_hg_dual_replay_authority_ack_publisher_decision.csv",
    "dual_replay_authority_ack_publisher/DUAL_REPLAY_AUTHORITY_ACK_MANIFEST.json",
    "dual_replay_authority_ack_publisher/DUAL_REPLAY_AUTHORITY_ACK_PUBLISHED_ROWS.csv",
    "dual_replay_authority_ack_publisher/DUAL_REPLAY_AUTHORITY_ACK_STAGE_ROWS.csv",
    "dual_replay_authority_ack_publisher/DUAL_REPLAY_AUTHORITY_ACK_COMMAND_ROWS.csv",
    "dual_replay_authority_ack_publisher/VERIFY_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER.sh",
    "source_v61hg/v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_summary.csv",
    "source_v61gp/v61gp_post_go_first_real_slice_dual_replay_executor_summary.csv",
    "source_v61gv/first_real_slice_workspace_missing_item_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hh artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hh artifact: {rel}")
if not os.access(package_dir / "VERIFY_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER.sh", os.X_OK):
    raise SystemExit("v61hh verifier executable bit missing")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hh sha256 mismatch: {rel}")
print("v61hh default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="hh_workspace_source" V61GU_INITIALIZE_WORKSPACE=1 V61GU_WORK_ROOT="$TMP_WORK_ROOT" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
V61HA_RUN_ID="hh_promoted_source_witness" V61HA_WORK_ROOT="$TMP_WORK_ROOT" V61HA_EXECUTE_PROMOTION=1 V61HA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null
V61HB_RUN_ID="hh_applied_checkpoint_root" V61HB_WORK_ROOT="$TMP_WORK_ROOT" V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" V61HB_APPLY_CHECKPOINT_ROOT=1 V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
V61HC_RUN_ID="hh_precheck_runner" V61HC_WORK_ROOT="$TMP_WORK_ROOT" V61HC_PUBLISH_PRECHECK_RUNNER=1 V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
V61HD_RUN_ID="hh_external_return_form" V61HD_WORK_ROOT="$TMP_WORK_ROOT" V61HD_PUBLISH_FORM=1 V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
V61HE_RUN_ID="hh_form_materializer" V61HE_WORK_ROOT="$TMP_WORK_ROOT" V61HE_PUBLISH_MATERIALIZER=1 V61HE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null
V61HF_RUN_ID="hh_filled_form_handoff" V61HF_WORK_ROOT="$TMP_WORK_ROOT" V61HF_PUBLISH_HANDOFF=1 V61HF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hf_post_he_first_real_slice_filled_form_handoff_publisher.sh" >/dev/null
V61HG_RUN_ID="hh_operator_replay_handoff" V61HG_WORK_ROOT="$TMP_WORK_ROOT" V61HG_PUBLISH_HANDOFF=1 V61HG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
V61HH_RUN_ID="published_authority_ack" V61HH_WORK_ROOT="$TMP_WORK_ROOT" V61HH_PUBLISH_ACK=1 V61HH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null

python3 - "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT" <<'PY'
import json
import sys
from pathlib import Path
import hashlib


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


work_root = Path(sys.argv[1])
checkpoint_root = Path(sys.argv[2])
form_dir = work_root / "external_return_form"
payload = json.loads((form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template").read_text(encoding="utf-8"))
payload["source_class"] = "real-external-review-and-generation-return"
payload["finalized"] = True
payload["v53_review_return"].update({
    "reviewer_id": "external_reviewer_alpha",
    "adjudicator_id": "external_adjudicator_alpha",
    "review_comment_text": "External reviewer confirms the selected answer is source-bound to django/__init__.py line 1 and citation support is sufficient.",
    "adjudication_reason_text": "External adjudicator accepts the reviewed row because the cited source line directly contains the bounded fact.",
    "credential_statement_text": "External reviewer identity and qualification statement for the first real slice validation path.",
    "conflict_statement_text": "External reviewer declares no conflict with the selected repository or generated answer for this slice.",
    "reviewer_authority_statement": "External reviewer authority statement for final first-slice review return materialization.",
})
payload["v61_generation_return"].update({
    "generation_id": "real_generation_alpha",
    "citation_id": "real_generation_alpha_citation_001",
    "checkpoint_root": str(checkpoint_root),
    "answer_text": "The bounded source fact at django/__init__.py:1 is that Django imports get_version from django.utils.version.",
    "run_transcript_text": "External generation transcript records the selected prompt, model path, source citation, answer text, and latency measurements for this first slice.",
    "latency_row_id": "real_latency_alpha",
    "prompt_tokens": "128",
    "output_tokens": "32",
    "prefill_ms": "11.5",
    "decode_ms": "42.25",
    "total_ms": "53.75",
    "tokens_per_second": "595.3",
    "generation_operator_authority_statement": "External generation operator authority statement for final first-slice generation return materialization.",
})
payload["external_return_attestation"] = "External operator attests that this first-slice return is final and independently supplied."
payload["operator_input_assembly_authority_statement"] = "External operator authorizes local materialization of the first-slice return into the guarded operator input root."
form_path = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
form_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
ack = json.loads((form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json.template").read_text(encoding="utf-8"))
ack.update({
    "finalized": True,
    "authority_ack": "operator-confirmed-real-external-review-and-generation-return",
    "authority_statement": "Final external replay authority statement for the first real slice subset, binding filled form hash to operator replay execution.",
    "operator_attests_real_external_return": True,
    "filled_form_sha256": sha256(form_path),
})
(form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json").write_text(json.dumps(ack, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

"$TMP_WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py" \
  "$TMP_WORK_ROOT/external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json" \
  "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" \
  "$TMP_WORK_ROOT/external_return_form/dual_replay_authority_ack.validation_rows.csv" >/tmp/v61hh_ack_stdout.txt

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "form_dir_exists": "1",
    "operator_replay_handoff_exists": "1",
    "publish_requested": "1",
    "publish_admitted": "1",
    "authority_ack_published": "1",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hh published {field}: expected {value}, got {summary.get(field)}")
for rel in [
    "external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json.template",
    "external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py",
    "RUN_OPERATOR_REPLAY_WITH_AUTHORITY_ACK_FILE.sh",
    "external_return_form/DUAL_REPLAY_AUTHORITY_ACK_README.md",
]:
    path = work_root / rel
    if not path.is_file():
        raise SystemExit(f"v61hh missing published file: {rel}")
report = work_root / "external_return_form" / "dual_replay_authority_ack.validation_rows.csv"
rows = read_csv(report)
if not rows or any(row["status"] != "pass" for row in rows):
    raise SystemExit("v61hh expected authority ack validation report to pass")
proc = subprocess.run(
    [
        str(work_root / "external_return_form" / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py"),
        str(work_root / "external_return_form" / "DUAL_REPLAY_AUTHORITY_ACK.json.template"),
        str(work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"),
        str(work_root / "external_return_form" / "template_ack.validation_rows.csv"),
    ],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if proc.returncode == 0:
    raise SystemExit("v61hh template ack validator must fail")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "external-return-form-dir", "operator-replay-handoff", "publish-request", "authority-ack-published", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61hh expected pass decision: {gate}")
print("v61hh published durable authority ack smoke passed")
PY

V61HH_RUN_ID="authority_ack_001" V61HH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null
V61HG_RUN_ID="operator_replay_handoff_001" V61HG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
V61GP_RUN_ID="replay_001" V61GP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
