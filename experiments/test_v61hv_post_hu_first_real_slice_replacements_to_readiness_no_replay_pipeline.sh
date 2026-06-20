#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline"
RUN_DIR="$RESULTS_DIR/$PREFIX/replacements_to_readiness_no_replay_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_replacements_to_readiness_no_replay_pipeline"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hv first real slice workspace"

V61HV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_PIPELINE.sh" >/dev/null

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
    "v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "pipeline_published": "0",
    "execute_requested": "0",
    "replacements_to_readiness_ready": "0",
    "replacement_template_exists": "0",
    "replacements_file_exists": "0",
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "operator_input_files_ready": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61hv default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_replacements_to_readiness_published_rows.csv",
    "first_real_slice_replacements_to_readiness_step_rows.csv",
    "first_real_slice_replacements_to_readiness_no_replay_pipeline/FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_MANIFEST.json",
    "first_real_slice_replacements_to_readiness_no_replay_pipeline/VERIFY_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_PIPELINE.sh",
    "V61HV_POST_HU_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_BOUNDARY.md",
    "v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hv artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hv sha256 mismatch: {rel}")
print("v61hv default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
FORM_DIR="$TMP_WORK_ROOT/external_return_form"
touch "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template"
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv" <<'EOF'
env_name,field_path,repair_label,current_status,evidence,required_action,safe_to_publish,contains_value
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,reviewer identity,blocked,nonfinal-token,"replace with real reviewer identity, at least 3 chars",1,0
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,prompt tokens,blocked,nonfinal-token,replace with positive measured prompt token count,1,0
V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN,operator_attests_real_external_return,operator attestation boolean,blocked,expected-true:false,set to true only after the external return values are real and final,1,0
V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT,v61_generation_return.generation_operator_authority_statement,generation operator authority,blocked,nonfinal-token,"replace with final generation operator authority statement, at least 40 chars",1,0
EOF
cat > "$FORM_DIR/APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py" <<'PY'
#!/usr/bin/env python3
import argparse
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--replacements", required=True)
parser.add_argument("--overwrite", action="store_true")
args = parser.parse_args()
replacements = Path(args.replacements)
if not replacements.is_file():
    raise SystemExit(2)
form_dir = Path(__file__).resolve().parent
(form_dir / "apply.marker").write_text(str(replacements) + "\n", encoding="utf-8")
PY
chmod +x "$FORM_DIR/APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
cat > "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${V61HG_EXECUTE_DUAL_REPLAY:-0}" == "1" ]]; then exit 13; fi
printf 'readiness\n' > "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/readiness.marker"
SH
chmod +x "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh"
touch "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
chmod +x "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"

V61HV_RUN_ID="publish_only" \
V61HV_WORK_ROOT="$TMP_WORK_ROOT" \
V61HV_PUBLISH_PIPELINE=1 \
V61HV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline.sh" >/dev/null

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
    "pipeline_published": "1",
    "execute_requested": "0",
    "replacement_template_exists": "1",
    "replacements_file_exists": "0",
    "replacement_applier_exists": "1",
    "replacement_validator_exists": "1",
    "env_to_readiness_runner_exists": "1",
    "next_real_subset_action": "fill-first-real-slice-values-replacements-csv",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hv publish-only {key}: expected {value}, got {row.get(key)}")
runner = work_root / "RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh"
readme = work_root / "FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_README.md"
validator = work_root / "external_return_form" / "VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
validator_runner = work_root / "external_return_form" / "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh"
for path in [runner, readme, validator, validator_runner]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published v61hv file: {path}")
for path in [runner, validator, validator_runner]:
    if not os.access(path, os.X_OK):
        raise SystemExit(f"published v61hv executable bit missing: {path}")
for path in [runner, validator_runner]:
    syntax = subprocess.run(["bash", "-n", str(path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if syntax.returncode != 0:
        raise SystemExit(f"published runner bash -n failed: {path}: {syntax.stderr}")
syntax = subprocess.run(["python3", "-m", "py_compile", str(validator)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"published validator py_compile failed: {syntax.stderr}")
print("v61hv publish-only smoke passed")
PY

if "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hv_missing_replacements.out 2>/tmp/v61hv_missing_replacements.err; then
  echo "v61hv runner accepted missing replacements file" >&2
  exit 1
fi
if "$FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh" >/tmp/v61hv_missing_replacements_validate.out 2>/tmp/v61hv_missing_replacements_validate.err; then
  echo "v61hv replacement validator accepted missing replacements file" >&2
  exit 1
fi
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv" <<'EOF'
env_name,field_path,replacement_value,required_action
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,ab,replace with real reviewer identity
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,0,replace with positive measured prompt token count
V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN,operator_attests_real_external_return,false,set to true only after real values
V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT,v61_generation_return.generation_operator_authority_statement,too short,replace with final generation operator authority statement
EOF
if "$FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh" >/tmp/v61hv_validate_bad.out 2>/tmp/v61hv_validate_bad.err; then
  echo "v61hv replacement validator accepted invalid typed replacements" >&2
  exit 1
fi
grep -F "too-short-min-3" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null
grep -F "not-positive-number" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null
grep -F "expected-true" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null
grep -F "too-short-min-40" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null
rm -f "$FORM_DIR/apply.marker" "$TMP_WORK_ROOT/readiness.marker"
if "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hv_bad_runner.out 2>/tmp/v61hv_bad_runner.err; then
  echo "v61hv runner accepted invalid typed replacements" >&2
  exit 1
fi
if [[ -e "$FORM_DIR/apply.marker" || -e "$TMP_WORK_ROOT/readiness.marker" ]]; then
  echo "v61hv runner continued after failed replacement preflight" >&2
  exit 1
fi
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv" <<'EOF'
env_name,field_path,replacement_value,required_action
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,reviewer-alpha,replace with real reviewer identity
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,128,replace with positive measured prompt token count
V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN,operator_attests_real_external_return,true,set to true only after real values
V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT,v61_generation_return.generation_operator_authority_statement,Final generation operator authority statement for this real external return.,replace with final generation operator authority statement
EOF
"$FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh" >/tmp/v61hv_validate_default.out
grep -F "replacement-value-present-redacted" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null
if grep -F "reviewer-alpha" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv" >/dev/null; then
  echo "v61hv replacement validator leaked replacement value" >&2
  exit 1
fi
"$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hv_no_replay.out
test -s "$FORM_DIR/apply.marker"
test -s "$TMP_WORK_ROOT/readiness.marker"

ALT_REPLACEMENTS="$TMP_WORK_ROOT/alternate_replacements.csv"
cat > "$ALT_REPLACEMENTS" <<'EOF'
env_name,field_path,replacement_value,required_action
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,reviewer-beta,replace with real reviewer identity
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,256,replace with positive measured prompt token count
V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN,operator_attests_real_external_return,true,set to true only after real values
V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT,v61_generation_return.generation_operator_authority_statement,Alternate final generation operator authority statement for this return.,replace with final generation operator authority statement
EOF
rm -f "$FORM_DIR/apply.marker" "$TMP_WORK_ROOT/readiness.marker"
V61HV_REPLACEMENTS_FILE="$ALT_REPLACEMENTS" \
"$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hv_custom_replacements.out
grep -F "$ALT_REPLACEMENTS" "$FORM_DIR/apply.marker" >/dev/null
test -s "$TMP_WORK_ROOT/readiness.marker"

V61HV_RUN_ID="execute_stub" \
V61HV_WORK_ROOT="$TMP_WORK_ROOT" \
V61HV_PUBLISH_PIPELINE=1 \
V61HV_EXECUTE_PIPELINE=1 \
V61HV_REPLACEMENTS_FILE="$ALT_REPLACEMENTS" \
V61HV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path
summary_csv = Path(sys.argv[1])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
if row["execute_requested"] != "1" or row["replacements_to_readiness_ready"] != "1":
    raise SystemExit("v61hv execute stub did not report ready")
if row["row_acceptance_ready"] != "0" or row["actual_model_generation_ready"] != "0":
    raise SystemExit("v61hv execute stub opened forbidden claims")
print("v61hv no-replay execute stub smoke passed")
PY

echo "v61hv first real slice replacements to readiness no-replay pipeline smoke passed"
