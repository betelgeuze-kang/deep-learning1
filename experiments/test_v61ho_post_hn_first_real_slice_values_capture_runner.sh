#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ho_post_hn_first_real_slice_values_capture_runner"
RUN_DIR="$RESULTS_DIR/$PREFIX/values_capture_runner_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_values_capture_runner"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61ho first real slice workspace"

V61HO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ho_post_hn_first_real_slice_values_capture_runner.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER.sh" >/dev/null

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
    "v61ho_post_hn_first_real_slice_values_capture_runner_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "capture_runner_published": "0",
    "capture_env_rows": "24",
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
        raise SystemExit(f"v61ho default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_values_capture_env_rows.csv",
    "first_real_slice_values_capture_published_rows.csv",
    "first_real_slice_values_capture_runner/FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER_MANIFEST.json",
    "first_real_slice_values_capture_runner/VERIFY_FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER.sh",
    "V61HO_POST_HN_FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER_BOUNDARY.md",
    "v61ho_post_hn_first_real_slice_values_capture_runner_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61ho artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61ho sha256 mismatch: {rel}")
print("v61ho default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
printf '{"form_protocol_version":"v61hd-first-real-slice-external-return-form-v1","locked_context":{"source_file_sha256":"sha256:f1fa7d324478b36ef2f18fe0e835cda7c02851021ccb63531feb3d21d8070052"},"selected_slice_ids":{"v53":"v53-partial-review-slice","v61":"v61-partial-generation-slice"},"v53_review_return":{},"v61_generation_return":{}}\n' > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template"
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("form validator should not run in v61ho capture smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py"
cat > "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("materializer should not run in v61ho capture smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py"
V61HK_RUN_ID="v61ho_form_packet" \
V61HK_WORK_ROOT="$TMP_WORK_ROOT" \
V61HK_PUBLISH_PACKET=1 \
V61HK_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hk_post_hj_first_real_slice_external_return_form_fill_packet.sh" >/dev/null

CHECKPOINT_ROOT="$TMP_WORK_ROOT/checkpoint_root"
mkdir -p "$CHECKPOINT_ROOT"
python3 - "$CHECKPOINT_ROOT" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for idx in range(1, 60):
    (root / f"model-{idx:05d}-of-00059.safetensors").write_text("not a real checkpoint shard\n", encoding="utf-8")
PY

V61HO_RUN_ID="publish_only" \
V61HO_WORK_ROOT="$TMP_WORK_ROOT" \
V61HO_PUBLISH_CAPTURE=1 \
V61HO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ho_post_hn_first_real_slice_values_capture_runner.sh" >/dev/null

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
    "capture_runner_published": "1",
    "form_values_supplied": "0",
    "next_real_subset_action": "capture-first-real-slice-external-return-values-from-env",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61ho publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
runner = form_dir / "CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py"
ack_runner = form_dir / "CAPTURE_DUAL_REPLAY_AUTHORITY_ACK_VALUES_FROM_ENV.py"
env_rows = form_dir / "FIRST_REAL_SLICE_VALUES_CAPTURE_ENV_ROWS.csv"
readme = form_dir / "FIRST_REAL_SLICE_VALUES_CAPTURE_README.md"
for path in [runner, ack_runner, env_rows, readme]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published capture file: {path}")
for path in [runner, ack_runner]:
    if not os.access(path, os.X_OK):
        raise SystemExit(f"published capture runner not executable: {path}")
    syntax = subprocess.run(["python3", "-m", "py_compile", str(path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if syntax.returncode != 0:
        raise SystemExit(f"capture runner py_compile failed: {path}: {syntax.stderr}")
print("v61ho publish-only smoke passed")
PY

FORM_RUNNER="$TMP_WORK_ROOT/external_return_form/CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py"
if V61HO_EXTERNAL_RETURN_ATTESTATION="REPLACE_WITH_BAD_VALUE" "$FORM_RUNNER" --overwrite >/tmp/v61ho_bad_capture.out 2>/tmp/v61ho_bad_capture.err; then
  echo "capture runner accepted placeholder input" >&2
  exit 1
fi
if [[ -f "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" ]]; then
  echo "capture runner wrote values file after placeholder rejection" >&2
  exit 1
fi

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
"$FORM_RUNNER" --overwrite >/tmp/v61ho_good_capture.out

python3 - "$TMP_WORK_ROOT" <<'PY'
import csv
import json
import sys
from pathlib import Path
form_dir = Path(sys.argv[1]) / "external_return_form"
values = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
report = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
if not values.is_file() or not report.is_file():
    raise SystemExit("capture runner did not write values and validation report")
payload = json.loads(values.read_text(encoding="utf-8"))
if payload["v61_generation_return"]["prompt_tokens"] != 128:
    raise SystemExit("prompt_tokens was not captured as numeric")
with report.open(newline="", encoding="utf-8") as handle:
    blocked = [row for row in csv.DictReader(handle) if row["status"] != "pass"]
if blocked:
    raise SystemExit(f"capture validation has blocked rows: {blocked}")
print("v61ho transactional values capture smoke passed")
PY

echo "v61ho first real slice values capture runner smoke passed"
