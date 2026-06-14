#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hp_post_ho_first_real_slice_env_file_capture_handoff"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_file_capture_handoff_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_file_capture_handoff"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hp first real slice workspace"

V61HP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hp_post_ho_first_real_slice_env_file_capture_handoff.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


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
    "v61hp_post_ho_first_real_slice_env_file_capture_handoff_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "env_file_handoff_published": "0",
    "env_file_rows": "24",
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "ack_values_supplied": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61hp default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_values_env_file_rows.csv",
    "first_real_slice_env_file_capture_handoff_published_rows.csv",
    "first_real_slice_env_file_capture_handoff/FIRST_REAL_SLICE_VALUES.env.template",
    "first_real_slice_env_file_capture_handoff/FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF_MANIFEST.json",
    "first_real_slice_env_file_capture_handoff/VERIFY_FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF.sh",
    "V61HP_POST_HO_FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF_BOUNDARY.md",
    "v61hp_post_ho_first_real_slice_env_file_capture_handoff_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hp artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hp sha256 mismatch: {rel}")
print("v61hp default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
printf '{"form_protocol_version":"v61hd-first-real-slice-external-return-form-v1","locked_context":{"source_file_sha256":"sha256:f1fa7d324478b36ef2f18fe0e835cda7c02851021ccb63531feb3d21d8070052"},"selected_slice_ids":{"v53":"v53-partial-review-slice","v61":"v61-partial-generation-slice"},"v53_review_return":{},"v61_generation_return":{}}\n' > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template"
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("form validator should not run in v61hp env-file capture smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py"
cat > "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("materializer should not run in v61hp env-file capture smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py"

V61HK_RUN_ID="v61hp_form_packet" \
V61HK_WORK_ROOT="$TMP_WORK_ROOT" \
V61HK_PUBLISH_PACKET=1 \
V61HK_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hk_post_hj_first_real_slice_external_return_form_fill_packet.sh" >/dev/null
V61HO_RUN_ID="v61hp_capture_runner" \
V61HO_WORK_ROOT="$TMP_WORK_ROOT" \
V61HO_PUBLISH_CAPTURE=1 \
V61HO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ho_post_hn_first_real_slice_values_capture_runner.sh" >/dev/null
V61HP_RUN_ID="publish_only" \
V61HP_WORK_ROOT="$TMP_WORK_ROOT" \
V61HP_PUBLISH_HANDOFF=1 \
V61HP_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hp_post_ho_first_real_slice_env_file_capture_handoff.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import os
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
work_root = Path(sys.argv[2])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "publish_requested": "1",
    "env_file_handoff_published": "1",
    "form_values_supplied": "0",
    "next_real_subset_action": "copy-env-template-fill-real-values-run-capture-handoff",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hp publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
for name in [
    "CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.py",
    "RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh",
    "FIRST_REAL_SLICE_VALUES.env.template",
    "FIRST_REAL_SLICE_VALUES_ENV_FILE_ROWS.csv",
    "FIRST_REAL_SLICE_VALUES_ENV_FILE_README.md",
]:
    path = form_dir / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing env-file handoff file: {name}")
for name in [
    "CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.py",
    "RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh",
]:
    path = form_dir / name
    if not os.access(path, os.X_OK):
        raise SystemExit(f"handoff executable bit missing: {name}")
    command = ["python3", "-m", "py_compile", str(path)] if name.endswith(".py") else ["bash", "-n", str(path)]
    check = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check.returncode != 0:
        raise SystemExit(f"handoff syntax failed for {name}: {check.stderr}")
print("v61hp publish-only smoke passed")
PY

FORM_DIR="$TMP_WORK_ROOT/external_return_form"
cp "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.template" "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env"
if V61HP_OVERWRITE=1 "$FORM_DIR/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh" >/tmp/v61hp_placeholder.out 2>/tmp/v61hp_placeholder.err; then
  echo "env-file handoff accepted placeholder template" >&2
  exit 1
fi
if [[ -f "$FORM_DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" ]]; then
  echo "env-file handoff wrote values file after placeholder rejection" >&2
  exit 1
fi

CHECKPOINT_ROOT="$TMP_WORK_ROOT/checkpoint_root"
mkdir -p "$CHECKPOINT_ROOT"
python3 - "$CHECKPOINT_ROOT" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for idx in range(1, 60):
    (root / f"model-{idx:05d}-of-00059.safetensors").write_text("not a real checkpoint shard\n", encoding="utf-8")
PY
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env" <<EOF
export V61HO_EXTERNAL_RETURN_ATTESTATION="Operator attests this closed test return is a real reviewed value set."
export V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT="Operator authorizes assembly of this checked one row return into inputs."
export V61HO_REVIEWER_ID="reviewer-alpha"
export V61HO_ADJUDICATOR_ID="adjudicator-alpha"
export V61HO_REVIEW_COMMENT_TEXT="Reviewer confirms the cited source row supports the first slice answer."
export V61HO_ADJUDICATION_REASON_TEXT="Adjudicator accepts the first slice because source and policy checks passed."
export V61HO_CREDENTIAL_STATEMENT_TEXT="Reviewer identity is authorized for this controlled local return path."
export V61HO_CONFLICT_STATEMENT_TEXT="Reviewer declares no conflict for this controlled local return path."
export V61HO_REVIEWER_AUTHORITY_STATEMENT="Reviewer authority is final for this one row controlled local return."
export V61HO_GENERATION_ID="generation-alpha"
export V61HO_CITATION_ID="citation-alpha"
export V61HO_LATENCY_ROW_ID="latency-alpha"
export V61HO_CHECKPOINT_ROOT="$CHECKPOINT_ROOT"
export V61HO_ANSWER_TEXT="The first slice answer is source bound and cites the selected local file."
export V61HO_RUN_TRANSCRIPT_TEXT="Run transcript records the controlled first slice generation return path."
export V61HO_PROMPT_TOKENS="128"
export V61HO_OUTPUT_TOKENS="64"
export V61HO_PREFILL_MS="12.5"
export V61HO_DECODE_MS="25.5"
export V61HO_TOTAL_MS="38.0"
export V61HO_TOKENS_PER_SECOND="1.68"
export V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT="Generation operator authorizes this controlled first slice value return."
export V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT="This optional ack statement is long enough but is not captured unless the ack mode is explicitly requested."
export V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN="true"
EOF
V61HP_OVERWRITE=1 "$FORM_DIR/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh" >/tmp/v61hp_good_env_capture.out

python3 - "$FORM_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path
form_dir = Path(sys.argv[1])
values = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
report = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
if not values.is_file() or not report.is_file():
    raise SystemExit("env-file handoff did not write values and validation report")
payload = json.loads(values.read_text(encoding="utf-8"))
if payload["v61_generation_return"]["output_tokens"] != 64:
    raise SystemExit("output_tokens was not captured as numeric")
with report.open(newline="", encoding="utf-8") as handle:
    blocked = [row for row in csv.DictReader(handle) if row["status"] != "pass"]
if blocked:
    raise SystemExit(f"env-file capture validation has blocked rows: {blocked}")
print("v61hp transactional env-file capture smoke passed")
PY

echo "v61hp first real slice env-file capture handoff smoke passed"
