#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61he_post_hd_first_real_slice_form_materializer_publisher"
RUN_DIR="$RESULTS_DIR/$PREFIX/form_materializer_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_form_materializer_publisher"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61he first real slice workspace"
TMP_CHECKPOINT_ROOT="${TMPDIR:-/tmp}/v61he checkpoint root"

V61HE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER.sh" >/dev/null

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
    "v61he_post_hd_first_real_slice_form_materializer_publisher_ready": "1",
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "work_root_outside_repo": "0",
    "form_dir_exists": "0",
    "form_validator_exists": "0",
    "publish_requested": "0",
    "publish_admitted": "0",
    "form_materializer_published": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61he default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "first_real_slice_form_materializer_source_rows.csv",
    "first_real_slice_form_materializer_published_rows.csv",
    "first_real_slice_form_materializer_stage_rows.csv",
    "first_real_slice_form_materializer_command_rows.csv",
    "first_real_slice_form_materializer_package_file_rows.csv",
    "V61HE_POST_HD_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER_BOUNDARY.md",
    "v61he_post_hd_first_real_slice_form_materializer_publisher_manifest.json",
    "v61he_post_hd_first_real_slice_form_materializer_publisher_summary.csv",
    "v61he_post_hd_first_real_slice_form_materializer_publisher_decision.csv",
    "first_real_slice_form_materializer_publisher/FIRST_REAL_SLICE_FORM_MATERIALIZER_MANIFEST.json",
    "first_real_slice_form_materializer_publisher/FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHED_ROWS.csv",
    "first_real_slice_form_materializer_publisher/FIRST_REAL_SLICE_FORM_MATERIALIZER_STAGE_ROWS.csv",
    "first_real_slice_form_materializer_publisher/FIRST_REAL_SLICE_FORM_MATERIALIZER_COMMAND_ROWS.csv",
    "first_real_slice_form_materializer_publisher/VERIFY_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER.sh",
    "source_v61hd/v61hd_post_hc_first_real_slice_external_return_form_publisher_summary.csv",
    "source_v61gv/first_real_slice_workspace_missing_item_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    if not (run_dir / rel).is_file():
        raise SystemExit(f"missing v61he artifact: {rel}")
if not os.access(package_dir / "VERIFY_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER.sh", os.X_OK):
    raise SystemExit("v61he verifier executable bit missing")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61he sha256 mismatch: {rel}")
print("v61he default no-publish smoke passed")
PY

rm -rf "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT"
mkdir -p "$TMP_CHECKPOINT_ROOT"
for shard in $(seq 1 59); do
  shard_name="$(printf '%05d' "$shard")"
  printf 'tiny test shard %s\n' "$shard_name" > "$TMP_CHECKPOINT_ROOT/model-${shard_name}-of-00059.safetensors"
done

V61GU_RUN_ID="he_workspace_source" V61GU_INITIALIZE_WORKSPACE=1 V61GU_WORK_ROOT="$TMP_WORK_ROOT" V61GU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null
V61HA_RUN_ID="he_promoted_source_witness" V61HA_WORK_ROOT="$TMP_WORK_ROOT" V61HA_EXECUTE_PROMOTION=1 V61HA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null
V61HB_RUN_ID="he_applied_checkpoint_root" V61HB_WORK_ROOT="$TMP_WORK_ROOT" V61HB_CHECKPOINT_ROOT="$TMP_CHECKPOINT_ROOT" V61HB_APPLY_CHECKPOINT_ROOT=1 V61HB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
V61HC_RUN_ID="he_precheck_runner" V61HC_WORK_ROOT="$TMP_WORK_ROOT" V61HC_PUBLISH_PRECHECK_RUNNER=1 V61HC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
V61HD_RUN_ID="he_external_return_form" V61HD_WORK_ROOT="$TMP_WORK_ROOT" V61HD_PUBLISH_FORM=1 V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
V61HE_RUN_ID="published_form_materializer" V61HE_WORK_ROOT="$TMP_WORK_ROOT" V61HE_PUBLISH_MATERIALIZER=1 V61HE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null

python3 - "$TMP_WORK_ROOT" "$TMP_CHECKPOINT_ROOT" <<'PY'
import json
import sys
from pathlib import Path
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
(form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

"$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" >/tmp/v61he_materializer_stdout.txt
"$TMP_WORK_ROOT/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh" >/tmp/v61he_precheck_stdout.txt
V61GV_RUN_ID="he_after_materializer" V61GV_WORK_ROOT="$TMP_WORK_ROOT" V61GV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$TMP_WORK_ROOT" "$RESULTS_DIR/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv" <<'PY'
import csv
import json
import sys
from pathlib import Path
summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
work_root = Path(sys.argv[3])
gv_summary_csv = Path(sys.argv[4])

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

summary = read_csv(summary_csv)[0]
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "form_dir_exists": "1",
    "form_validator_exists": "1",
    "publish_requested": "1",
    "publish_admitted": "1",
    "form_materializer_published": "1",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "dual_external_return_real_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61he published {field}: expected {value}, got {summary.get(field)}")
manifest = work_root / "external_return_form" / "MATERIALIZED_FIRST_REAL_SLICE_FROM_FORM_MANIFEST.json"
if not manifest.is_file():
    raise SystemExit("v61he materialization manifest missing")
payload = json.loads(manifest.read_text(encoding="utf-8"))
if payload.get("executes_dual_replay") != 0 or payload.get("accepted_as_real_evidence_by_materializer") != 0:
    raise SystemExit("v61he materializer must not claim replay or evidence")
gv = read_csv(gv_summary_csv)[0]
for field, value in {
    "ready_witness_rows": "7",
    "ready_value_env_rows": "16",
    "workspace_gap_preflight_ready": "1",
    "open_gap_rows": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
}.items():
    if gv.get(field) != value:
        raise SystemExit(f"v61gv after v61he {field}: expected {value}, got {gv.get(field)}")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["work-root", "form-validator", "publish-request", "form-materializer-published", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61he expected pass decision: {gate}")
print("v61he published materializer smoke passed")
PY

V61HE_RUN_ID="form_materializer_001" V61HE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null
V61HD_RUN_ID="external_return_form_001" V61HD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
