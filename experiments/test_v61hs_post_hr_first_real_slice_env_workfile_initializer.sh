#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hs_post_hr_first_real_slice_env_workfile_initializer"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_workfile_initializer_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_workfile_initializer"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hs first real slice workspace"

V61HS_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hs_post_hr_first_real_slice_env_workfile_initializer.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER.sh" >/dev/null

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
    "v61hs_post_hr_first_real_slice_env_workfile_initializer_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "initializer_published": "0",
    "initialize_requested": "0",
    "env_workfile_initialized": "0",
    "env_file_exists_after": "0",
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61hs default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_env_workfile_initializer_published_rows.csv",
    "first_real_slice_values_env_workfile_preflight_rows.csv",
    "first_real_slice_env_workfile_initializer/FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER_MANIFEST.json",
    "first_real_slice_env_workfile_initializer/VERIFY_FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER.sh",
    "V61HS_POST_HR_FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER_BOUNDARY.md",
    "v61hs_post_hr_first_real_slice_env_workfile_initializer_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hs artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hs sha256 mismatch: {rel}")
print("v61hs default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env.template" <<'EOF'
export V61HO_EXTERNAL_RETURN_ATTESTATION=REPLACE_WITH_REAL_EXTERNAL_RETURN_ATTESTATION
export V61HO_REVIEWER_ID=REPLACE_WITH_REAL_REVIEWER_ID
EOF
cat > "$TMP_WORK_ROOT/external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv"
if grep -q 'REPLACE_WITH' "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env"; then
  printf 'env_name,field_path,status,required,evidence\nV61HO_REVIEWER_ID,v53_review_return.reviewer_id,blocked,1,nonfinal-token\n' > "$REPORT"
  exit 2
fi
printf 'env_name,field_path,status,required,evidence\nV61HO_REVIEWER_ID,v53_review_return.reviewer_id,pass,1,ready\n' > "$REPORT"
SH
chmod +x "$TMP_WORK_ROOT/external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh"

V61HS_RUN_ID="publish_only" \
V61HS_WORK_ROOT="$TMP_WORK_ROOT" \
V61HS_PUBLISH_INITIALIZER=1 \
V61HS_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hs_post_hr_first_real_slice_env_workfile_initializer.sh" >/dev/null

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
    "initializer_published": "1",
    "initialize_requested": "0",
    "env_file_exists_after": "0",
    "next_real_subset_action": "initialize-first-real-slice-values-env-workfile",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hs publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
for name in [
    "RUN_INITIALIZE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
    "FIRST_REAL_SLICE_VALUES_ENV_WORKFILE_README.md",
]:
    path = form_dir / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing initializer file: {name}")
if not os.access(form_dir / "RUN_INITIALIZE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh", os.X_OK):
    raise SystemExit("initializer runner is not executable")
syntax = subprocess.run(["bash", "-n", str(form_dir / "RUN_INITIALIZE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh")], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"initializer bash -n failed: {syntax.stderr}")
print("v61hs publish-only smoke passed")
PY

V61HS_RUN_ID="initialize_placeholder" \
V61HS_WORK_ROOT="$TMP_WORK_ROOT" \
V61HS_PUBLISH_INITIALIZER=1 \
V61HS_INITIALIZE_ENV=1 \
V61HS_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hs_post_hr_first_real_slice_env_workfile_initializer.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
work_root = Path(sys.argv[2])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
expected = {
    "env_workfile_initialized": "1",
    "initialize_status": "initialized-from-template",
    "env_file_exists_before": "0",
    "env_file_exists_after": "1",
    "env_file_preflight_ready": "0",
    "env_file_preflight_blocked_rows": "1",
    "form_values_supplied": "0",
    "actual_model_generation_ready": "0",
    "next_real_subset_action": "replace-placeholder-values-in-first-real-slice-env-file",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hs init {key}: expected {value}, got {row.get(key)}")
env_file = work_root / "external_return_form" / "FIRST_REAL_SLICE_VALUES.env"
if not env_file.is_file() or "REPLACE_WITH" not in env_file.read_text(encoding="utf-8"):
    raise SystemExit("env workfile was not initialized from template")
for forbidden in ["FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json", "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "DUAL_REPLAY_AUTHORITY_ACK.json"]:
    if (work_root / "external_return_form" / forbidden).exists():
        raise SystemExit(f"initializer wrote forbidden artifact: {forbidden}")
print("v61hs placeholder initializer smoke passed")
PY

echo "v61hs first real slice env workfile initializer smoke passed"
