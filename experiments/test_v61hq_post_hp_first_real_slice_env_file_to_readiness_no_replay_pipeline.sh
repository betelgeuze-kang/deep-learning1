#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_file_to_readiness_no_replay_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_file_to_readiness_no_replay_pipeline"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hq first real slice workspace"

V61HQ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_PIPELINE.sh" >/dev/null

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
    "v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "pipeline_published": "0",
    "execute_requested": "0",
    "no_replay_pipeline_ready": "0",
    "env_file_exists": "0",
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
        raise SystemExit(f"v61hq default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_env_file_to_readiness_published_rows.csv",
    "first_real_slice_env_file_to_readiness_step_rows.csv",
    "first_real_slice_env_file_to_readiness_no_replay_pipeline/FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_MANIFEST.json",
    "first_real_slice_env_file_to_readiness_no_replay_pipeline/VERIFY_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_PIPELINE.sh",
    "V61HQ_POST_HP_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_BOUNDARY.md",
    "v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hq artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hq sha256 mismatch: {rel}")
print("v61hq default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -f "${V61HP_VALUES_ENV_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env}"
printf 'captured\n' > "$FORM_DIR/capture.marker"
SH
chmod +x "$TMP_WORK_ROOT/external_return_form/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh"
touch "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env.template"
cat > "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${V61HM_EXECUTE_FORM:-0}" != "1" ]]; then exit 11; fi
if [[ "${V61HM_EXECUTE_OPERATOR_INPUT:-0}" != "1" ]]; then exit 12; fi
if [[ "${V61HG_EXECUTE_DUAL_REPLAY:-0}" == "1" ]]; then exit 13; fi
printf 'readiness\n' > "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/readiness.marker"
SH
chmod +x "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh"
touch "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
chmod +x "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"

V61HQ_RUN_ID="publish_only" \
V61HQ_WORK_ROOT="$TMP_WORK_ROOT" \
V61HQ_PUBLISH_PIPELINE=1 \
V61HQ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline.sh" >/dev/null

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
    "env_file_exists": "0",
    "env_template_exists": "1",
    "env_handoff_exists": "1",
    "readiness_pipeline_exists": "1",
    "next_real_subset_action": "fill-first-real-slice-values-env-file",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hq publish-only {key}: expected {value}, got {row.get(key)}")
runner = work_root / "RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh"
readme = work_root / "FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_README.md"
for path in [runner, readme]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published v61hq file: {path}")
if not os.access(runner, os.X_OK):
    raise SystemExit("published v61hq runner is not executable")
syntax = subprocess.run(["bash", "-n", str(runner)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"published runner bash -n failed: {syntax.stderr}")
print("v61hq publish-only smoke passed")
PY

if "$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hq_missing_env.out 2>/tmp/v61hq_missing_env.err; then
  echo "v61hq runner accepted missing env file" >&2
  exit 1
fi
printf 'V61HO_REVIEWER_ID=reviewer-alpha\n' > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env"
"$TMP_WORK_ROOT/RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh" >/tmp/v61hq_no_replay.out
test -s "$TMP_WORK_ROOT/external_return_form/capture.marker"
test -s "$TMP_WORK_ROOT/readiness.marker"

V61HQ_RUN_ID="execute_stub" \
V61HQ_WORK_ROOT="$TMP_WORK_ROOT" \
V61HQ_PUBLISH_PIPELINE=1 \
V61HQ_EXECUTE_PIPELINE=1 \
V61HQ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path
summary_csv = Path(sys.argv[1])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
if row["execute_requested"] != "1" or row["no_replay_pipeline_ready"] != "1":
    raise SystemExit("v61hq execute stub did not report ready")
if row["row_acceptance_ready"] != "0" or row["actual_model_generation_ready"] != "0":
    raise SystemExit("v61hq execute stub opened forbidden claims")
print("v61hq no-replay execute stub smoke passed")
PY

echo "v61hq first real slice env-file to readiness no-replay pipeline smoke passed"
