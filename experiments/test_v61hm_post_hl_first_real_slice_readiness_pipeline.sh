#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hm_post_hl_first_real_slice_readiness_pipeline"
RUN_DIR="$RESULTS_DIR/$PREFIX/readiness_pipeline_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_readiness_pipeline"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hm first real slice workspace"

V61HM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hm_post_hl_first_real_slice_readiness_pipeline.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_READINESS_PIPELINE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
package_dir = Path(sys.argv[3])


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
    "v61hm_post_hl_first_real_slice_readiness_pipeline_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "pipeline_published": "0",
    "form_values_supplied": "0",
    "form_values_validation_ready": "0",
    "filled_form_exists": "0",
    "operator_input_files_ready": "0",
    "ack_values_supplied": "0",
    "ack_values_validation_ready": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hm default {field}: expected {value}, got {summary.get(field)}")
required = [
    "first_real_slice_readiness_pipeline_published_rows.csv",
    "first_real_slice_readiness_pipeline_step_rows.csv",
    "first_real_slice_readiness_pipeline_operator_input_file_rows.csv",
    "first_real_slice_readiness_pipeline_stage_rows.csv",
    "first_real_slice_readiness_pipeline_package_file_rows.csv",
    "V61HM_POST_HL_FIRST_REAL_SLICE_READINESS_PIPELINE_BOUNDARY.md",
    "v61hm_post_hl_first_real_slice_readiness_pipeline_summary.csv",
    "v61hm_post_hl_first_real_slice_readiness_pipeline_decision.csv",
    "first_real_slice_readiness_pipeline/FIRST_REAL_SLICE_READINESS_PIPELINE_MANIFEST.json",
    "first_real_slice_readiness_pipeline/FIRST_REAL_SLICE_READINESS_PIPELINE_STEP_ROWS.csv",
    "first_real_slice_readiness_pipeline/FIRST_REAL_SLICE_READINESS_PIPELINE_STAGE_ROWS.csv",
    "first_real_slice_readiness_pipeline/FIRST_REAL_SLICE_READINESS_PIPELINE_OPERATOR_INPUT_FILE_ROWS.csv",
    "first_real_slice_readiness_pipeline/VERIFY_FIRST_REAL_SLICE_READINESS_PIPELINE.sh",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hm artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hm artifact: {rel}")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hm sha256 mismatch: {rel}")
print("v61hm default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("form values missing")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("ack values missing")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py"
touch "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
chmod +x "$TMP_WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"

V61HM_RUN_ID="publish_only" \
V61HM_WORK_ROOT="$TMP_WORK_ROOT" \
V61HM_PUBLISH_PIPELINE=1 \
V61HM_RUN_READINESS=0 \
V61HM_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hm_post_hl_first_real_slice_readiness_pipeline.sh" >/dev/null

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
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "operator_input_files_ready": "0",
    "ack_values_supplied": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "create-first-real-slice-external-return-values-json",
    "actual_model_generation_ready": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hm publish-only {key}: expected {value}, got {row.get(key)}")
runner = work_root / "RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh"
readme = work_root / "FIRST_REAL_SLICE_READINESS_PIPELINE_README.md"
if not runner.is_file() or not os.access(runner, os.X_OK):
    raise SystemExit("published pipeline runner missing or not executable")
if not readme.is_file() or readme.stat().st_size == 0:
    raise SystemExit("published pipeline readme missing")
syntax = subprocess.run(["bash", "-n", str(runner)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"published pipeline bash -n failed: {syntax.stderr}")
print("v61hm publish-only smoke passed")
PY

echo "v61hm first real slice readiness pipeline smoke passed"
