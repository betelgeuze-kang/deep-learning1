#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hl_post_hk_dual_replay_authority_ack_fill_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/ack_fill_packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/dual_replay_authority_ack_fill_packet"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hl first real slice workspace"

V61HL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hl_post_hk_dual_replay_authority_ack_fill_packet.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET.sh" >/dev/null

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
    "v61hl_post_hk_dual_replay_authority_ack_fill_packet_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "ack_template_exists": "0",
    "ack_validator_exists": "0",
    "filled_form_exists": "0",
    "publish_requested": "0",
    "ack_fill_packet_published": "0",
    "authority_ack_values_supplied": "0",
    "authority_ack_validation_ready": "0",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hl default {field}: expected {value}, got {summary.get(field)}")
required = [
    "dual_replay_authority_ack_fill_packet_published_rows.csv",
    "dual_replay_authority_ack_fill_packet_stage_rows.csv",
    "dual_replay_authority_ack_fill_packet_command_rows.csv",
    "dual_replay_authority_ack_fill_packet_package_file_rows.csv",
    "V61HL_POST_HK_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_BOUNDARY.md",
    "v61hl_post_hk_dual_replay_authority_ack_fill_packet_summary.csv",
    "v61hl_post_hk_dual_replay_authority_ack_fill_packet_decision.csv",
    "dual_replay_authority_ack_fill_packet/DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template",
    "dual_replay_authority_ack_fill_packet/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py",
    "dual_replay_authority_ack_fill_packet/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_STAGE_ROWS.csv",
    "dual_replay_authority_ack_fill_packet/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_COMMAND_ROWS.csv",
    "dual_replay_authority_ack_fill_packet/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_MANIFEST.json",
    "dual_replay_authority_ack_fill_packet/VERIFY_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET.sh",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hl artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hl artifact: {rel}")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hl sha256 mismatch: {rel}")
print("v61hl default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json.template" <<'JSON'
{
  "ack_protocol_version": "v61hh-dual-replay-authority-ack-v1",
  "authority_ack": "REPLACE_WITH_operator-confirmed-real-external-review-and-generation-return",
  "authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_REPLAY_AUTHORITY_STATEMENT_80_CHARS_MIN",
  "filled_form_relative_path": "external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json",
  "filled_form_sha256": "sha256:REPLACE_WITH_FILLED_FORM_HASH",
  "finalized": false,
  "operator_attests_real_external_return": false,
  "operator_input_root_relative_path": "operator_partial_return/operator_input_root",
  "output_root_relative_path": "operator_partial_return/output_root",
  "replay_scope": "first-real-slice-subset"
}
JSON
cat > "$TMP_WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit("ack validator should not run before values/form preflight in smoke")
PY
chmod +x "$TMP_WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py"

V61HL_RUN_ID="publish_only" \
V61HL_WORK_ROOT="$TMP_WORK_ROOT" \
V61HL_PUBLISH_PACKET=1 \
V61HL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hl_post_hk_dual_replay_authority_ack_fill_packet.sh" >/dev/null

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
    "ack_template_exists": "1",
    "ack_validator_exists": "1",
    "filled_form_exists": "0",
    "publish_requested": "1",
    "publish_admitted": "1",
    "ack_fill_packet_published": "1",
    "authority_ack_values_supplied": "0",
    "authority_ack_validation_ready": "0",
    "actual_model_generation_ready": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hl publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
values_validator = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py"
builder = form_dir / "BUILD_DUAL_REPLAY_AUTHORITY_ACK_FROM_VALUES.py"
handoff = form_dir / "BUILD_VALIDATE_AND_AUDIT_DUAL_REPLAY_AUTHORITY_ACK.sh"
values_template = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template"
for path in [values_validator, builder, handoff, values_template]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published ack fill-packet file: {path}")
for path in [values_validator, builder, handoff]:
    if not os.access(path, os.X_OK):
        raise SystemExit(f"published executable bit missing: {path}")
syntax = subprocess.run(["bash", "-n", str(handoff)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"handoff bash -n failed: {syntax.stderr}")
preflight_report = form_dir / "placeholder_ack_values.validation_rows.csv"
preflight = subprocess.run([str(values_validator), str(values_template), str(preflight_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if preflight.returncode == 0:
    raise SystemExit("ack values validator should reject template placeholders")
if not preflight_report.is_file() or preflight_report.stat().st_size == 0:
    raise SystemExit("ack values validator did not write a field report")
builder_proc = subprocess.run([str(builder), str(values_template), "--overwrite"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if builder_proc.returncode == 0:
    raise SystemExit("ack builder should reject placeholder values before writing ack")
if "dual-replay-authority-ack-values-blocked" not in builder_proc.stderr and "dual-replay-authority-ack-values-blocked" not in builder_proc.stdout:
    raise SystemExit(f"ack builder failed for wrong reason: stdout={builder_proc.stdout} stderr={builder_proc.stderr}")
if (form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json").exists():
    raise SystemExit("ack builder wrote ack despite placeholder rejection")
print("v61hl publish-only and placeholder rejection smoke passed")
PY

echo "v61hl dual replay authority ack fill packet smoke passed"
