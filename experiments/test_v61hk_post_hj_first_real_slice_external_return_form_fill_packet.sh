#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hk_post_hj_first_real_slice_external_return_form_fill_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/fill_packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_external_return_form_fill_packet"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hk first real slice workspace"

V61HK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hk_post_hj_first_real_slice_external_return_form_fill_packet.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET.sh" >/dev/null

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
    "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "form_template_exists": "0",
    "form_validator_exists": "0",
    "publish_requested": "0",
    "fill_packet_published": "0",
    "real_external_values_supplied": "0",
    "external_return_form_validation_ready": "0",
    "workspace_gap_preflight_ready": "0",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hk default {field}: expected {value}, got {summary.get(field)}")
required = [
    "first_real_slice_external_return_form_required_value_rows.csv",
    "first_real_slice_external_return_form_fill_packet_published_rows.csv",
    "first_real_slice_external_return_form_fill_packet_stage_rows.csv",
    "first_real_slice_external_return_form_fill_packet_command_rows.csv",
    "first_real_slice_external_return_form_fill_packet_package_file_rows.csv",
    "V61HK_POST_HJ_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_BOUNDARY.md",
    "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_summary.csv",
    "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_decision.csv",
    "first_real_slice_external_return_form_fill_packet/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template",
    "first_real_slice_external_return_form_fill_packet/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py",
    "first_real_slice_external_return_form_fill_packet/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_REQUIRED_VALUE_ROWS.csv",
    "first_real_slice_external_return_form_fill_packet/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_STAGE_ROWS.csv",
    "first_real_slice_external_return_form_fill_packet/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_COMMAND_ROWS.csv",
    "first_real_slice_external_return_form_fill_packet/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_MANIFEST.json",
    "first_real_slice_external_return_form_fill_packet/VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET.sh",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hk artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hk artifact: {rel}")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hk sha256 mismatch: {rel}")
print("v61hk default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
printf '{"form_protocol_version":"v61hd-first-real-slice-external-return-form-v1","locked_context":{"source_file_sha256":"sha256:f1fa7d324478b36ef2f18fe0e835cda7c02851021ccb63531feb3d21d8070052"},"selected_slice_ids":{"v53":"v53-partial-review-slice","v61":"v61-partial-generation-slice"},"v53_review_return":{},"v61_generation_return":{}}\n' > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template"
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("validator should not run for placeholder rejection smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py"
cat > "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("materializer should not run in v61hk publish-only smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py"

V61HK_RUN_ID="publish_only" \
V61HK_WORK_ROOT="$TMP_WORK_ROOT" \
V61HK_PUBLISH_PACKET=1 \
V61HK_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hk_post_hj_first_real_slice_external_return_form_fill_packet.sh" >/dev/null

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
    "form_template_exists": "1",
    "form_validator_exists": "1",
    "publish_requested": "1",
    "publish_admitted": "1",
    "fill_packet_published": "1",
    "real_external_values_supplied": "0",
    "external_return_form_validation_ready": "0",
    "actual_model_generation_ready": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hk publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
builder = form_dir / "BUILD_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FROM_VALUES.py"
values_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
handoff = form_dir / "VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh"
values_template = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template"
worksheet = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_WORKSHEET.md"
for path in [builder, values_validator, handoff, values_template, worksheet]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published fill-packet file: {path}")
for path in [builder, values_validator, handoff]:
    if not os.access(path, os.X_OK):
        raise SystemExit(f"published executable bit missing: {path}")
syntax = subprocess.run(["bash", "-n", str(handoff)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"handoff bash -n failed: {syntax.stderr}")
preflight_report = form_dir / "placeholder_values.validation_rows.csv"
preflight = subprocess.run([str(values_validator), str(values_template), str(preflight_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if preflight.returncode == 0:
    raise SystemExit("values validator should reject template placeholders")
if not preflight_report.is_file() or preflight_report.stat().st_size == 0:
    raise SystemExit("values validator did not write a field report")
placeholder = subprocess.run([str(builder), str(values_template), "--overwrite"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if placeholder.returncode == 0:
    raise SystemExit("builder should reject values template placeholders")
if "external-return-values-blocked" not in placeholder.stderr and "external-return-values-blocked" not in placeholder.stdout:
    raise SystemExit(f"builder failed for wrong reason: stdout={placeholder.stdout} stderr={placeholder.stderr}")
if (form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json").exists():
    raise SystemExit("builder wrote filled form despite placeholder rejection")
print("v61hk publish-only and placeholder rejection smoke passed")
PY

echo "v61hk first real slice external return form fill packet smoke passed"
