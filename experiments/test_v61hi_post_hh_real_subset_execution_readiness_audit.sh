#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hi_post_hh_real_subset_execution_readiness_audit"
RUN_DIR="$RESULTS_DIR/$PREFIX/readiness_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/real_subset_execution_readiness_audit"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hi first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61hi checkpoint root"

V61HI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh" >/dev/null

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
    "v61hi_post_hh_real_subset_execution_readiness_audit_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "filled_form_supplied": "0",
    "filled_form_validation_ready": "0",
    "authority_ack_supplied": "0",
    "authority_ack_validation_ready": "0",
    "operator_input_files_ready": "0",
    "dual_output_roots_ready": "0",
    "next_real_subset_action": "fill-and-validate-first-real-slice-external-return-form",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_return_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hi default {field}: expected {value}, got {summary.get(field)}")
required_files = [
    "real_subset_execution_readiness_source_rows.csv",
    "real_subset_execution_readiness_rows.csv",
    "real_subset_execution_root_rows.csv",
    "real_subset_operator_input_file_rows.csv",
    "real_subset_execution_readiness_package_file_rows.csv",
    "filled_form.validation_rows.csv",
    "dual_replay_authority_ack.validation_rows.csv",
    "V61HI_POST_HH_REAL_SUBSET_EXECUTION_READINESS_AUDIT_BOUNDARY.md",
    "v61hi_post_hh_real_subset_execution_readiness_audit_manifest.json",
    "v61hi_post_hh_real_subset_execution_readiness_audit_summary.csv",
    "v61hi_post_hh_real_subset_execution_readiness_audit_decision.csv",
    "real_subset_execution_readiness_audit/REAL_SUBSET_EXECUTION_READINESS_MANIFEST.json",
    "real_subset_execution_readiness_audit/REAL_SUBSET_EXECUTION_READINESS_ROWS.csv",
    "real_subset_execution_readiness_audit/REAL_SUBSET_EXECUTION_ROOT_ROWS.csv",
    "real_subset_execution_readiness_audit/REAL_SUBSET_OPERATOR_INPUT_FILE_ROWS.csv",
    "real_subset_execution_readiness_audit/FILLED_FORM_VALIDATION_ROWS.csv",
    "real_subset_execution_readiness_audit/DUAL_REPLAY_AUTHORITY_ACK_VALIDATION_ROWS.csv",
    "real_subset_execution_readiness_audit/VERIFY_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
    "real_subset_execution_readiness_audit/NEXT_REAL_SUBSET_ACTION.txt",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hi artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hi artifact: {rel}")
if not os.access(package_dir / "VERIFY_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh", os.X_OK):
    raise SystemExit("v61hi verifier executable bit missing")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hi sha256 mismatch: {rel}")
print("v61hi default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="hi_workspace_source" V61GU_INITIALIZE_WORKSPACE=1 V61GU_WORK_ROOT="$TMP_WORK_ROOT" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
V61HA_RUN_ID="hi_promoted_source_witness" V61HA_WORK_ROOT="$TMP_WORK_ROOT" V61HA_EXECUTE_PROMOTION=1 V61HA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null
V61HB_RUN_ID="hi_applied_checkpoint_root" V61HB_WORK_ROOT="$TMP_WORK_ROOT" V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" V61HB_APPLY_CHECKPOINT_ROOT=1 V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
V61HC_RUN_ID="hi_precheck_runner" V61HC_WORK_ROOT="$TMP_WORK_ROOT" V61HC_PUBLISH_PRECHECK_RUNNER=1 V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
V61HD_RUN_ID="hi_external_return_form" V61HD_WORK_ROOT="$TMP_WORK_ROOT" V61HD_PUBLISH_FORM=1 V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
V61HE_RUN_ID="hi_form_materializer" V61HE_WORK_ROOT="$TMP_WORK_ROOT" V61HE_PUBLISH_MATERIALIZER=1 V61HE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null
V61HF_RUN_ID="hi_filled_form_handoff" V61HF_WORK_ROOT="$TMP_WORK_ROOT" V61HF_PUBLISH_HANDOFF=1 V61HF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hf_post_he_first_real_slice_filled_form_handoff_publisher.sh" >/dev/null
V61HG_RUN_ID="hi_operator_replay_handoff" V61HG_WORK_ROOT="$TMP_WORK_ROOT" V61HG_PUBLISH_HANDOFF=1 V61HG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
V61HH_RUN_ID="hi_authority_ack" V61HH_WORK_ROOT="$TMP_WORK_ROOT" V61HH_PUBLISH_ACK=1 V61HH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null
V61HI_RUN_ID="published_audit" V61HI_WORK_ROOT="$TMP_WORK_ROOT" V61HI_PUBLISH_AUDIT=1 V61HI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh" >/dev/null

python3 - "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path


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

V61HI_RUN_ID="ready_before_operator_input" V61HI_WORK_ROOT="$TMP_WORK_ROOT" V61HI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh" >/dev/null
python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path
row = next(csv.DictReader(Path(sys.argv[1]).open(newline='', encoding='utf-8')))
expected = {
    "filled_form_validation_ready": "1",
    "authority_ack_validation_ready": "1",
    "operator_input_files_ready": "0",
    "dual_output_roots_ready": "0",
    "next_real_subset_action": "run-filled-form-to-operator-input-no-replay",
    "real_external_review_return_rows": "0",
    "actual_model_generation_ready": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hi before operator input {key}: expected {value}, got {row.get(key)}")
print("v61hi filled form and ack readiness smoke passed")
PY

set +e
V61HG_OVERWRITE_OPERATOR_INPUT=1 "$TMP_WORK_ROOT/RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh" >/tmp/v61hi_handoff_stdout.txt 2>/tmp/v61hi_handoff_stderr.txt
handoff_exit=$?
set -e
if [[ "$handoff_exit" -ne 3 ]]; then
  echo "v61hi expected operator handoff no-replay exit 3, got $handoff_exit" >&2
  cat /tmp/v61hi_handoff_stdout.txt >&2 || true
  cat /tmp/v61hi_handoff_stderr.txt >&2 || true
  exit 1
fi

V61HI_RUN_ID="ready_after_operator_input" V61HI_WORK_ROOT="$TMP_WORK_ROOT" V61HI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh" >/dev/null
python3 - "$SUMMARY_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import sys
from pathlib import Path
row = next(csv.DictReader(Path(sys.argv[1]).open(newline='', encoding='utf-8')))
work_root = Path(sys.argv[2])
expected = {
    "filled_form_validation_ready": "1",
    "authority_ack_validation_ready": "1",
    "operator_input_files_ready": "1",
    "dual_output_roots_ready": "0",
    "next_real_subset_action": "run-operator-replay-with-authority-ack-file",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_return_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hi after operator input {key}: expected {value}, got {row.get(key)}")
if not (work_root / "RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh").is_file():
    raise SystemExit("v61hi published audit runner missing")
print("v61hi operator input readiness smoke passed")
PY

V61HI_RUN_ID="readiness_001" V61HI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh" >/dev/null
V61HH_RUN_ID="authority_ack_001" V61HH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null
V61HG_RUN_ID="operator_replay_handoff_001" V61HG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
