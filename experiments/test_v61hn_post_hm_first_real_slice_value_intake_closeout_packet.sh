#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hn_post_hm_first_real_slice_value_intake_closeout_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/value_intake_closeout_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_value_intake_closeout_packet"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hn first real slice workspace"

V61HN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hn_post_hm_first_real_slice_value_intake_closeout_packet.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_PACKET.sh" >/dev/null

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
    "v61hn_post_hm_first_real_slice_value_intake_closeout_packet_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "intake_packet_published": "0",
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "operator_input_files_ready": "0",
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
        raise SystemExit(f"v61hn default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_value_intake_missing_rows.csv",
    "first_real_slice_value_intake_gate_rows.csv",
    "FIRST_REAL_SLICE_VALUE_INTAKE_NEXT_COMMANDS.md",
    "first_real_slice_value_intake_published_rows.csv",
    "first_real_slice_value_intake_closeout_packet/FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_MANIFEST.json",
    "first_real_slice_value_intake_closeout_packet/VERIFY_FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_PACKET.sh",
    "sha256_manifest.csv",
]
for rel in required:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hn artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hn artifact: {rel}")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hn sha256 mismatch: {rel}")
print("v61hn default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/template_values.validation_rows.csv" <<'CSV'
field_path,status,required,evidence
values-json,pass,1,json-readable
external_return_attestation,blocked,1,nonfinal-token
v61_generation_return.prompt_tokens,blocked,1,not-positive
CSV
cat > "$TMP_WORK_ROOT/external_return_form/template_ack_values.validation_rows.csv" <<'CSV'
field_path,status,required,evidence
values-json,pass,1,json-readable
authority_statement,blocked,1,len=67; nonfinal=True
CSV

V61HN_RUN_ID="publish_only" \
V61HN_WORK_ROOT="$TMP_WORK_ROOT" \
V61HN_PUBLISH_PACKET=1 \
V61HN_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hn_post_hm_first_real_slice_value_intake_closeout_packet.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
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
    "intake_packet_published": "1",
    "form_values_supplied": "0",
    "form_values_blocked_fields": "2",
    "ack_values_supplied": "0",
    "ack_values_blocked_fields": "1",
    "next_real_subset_action": "create-first-real-slice-external-return-values-json",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hn publish-only {key}: expected {value}, got {row.get(key)}")
for name in [
    "FIRST_REAL_SLICE_VALUE_INTAKE_TODO.csv",
    "FIRST_REAL_SLICE_VALUE_INTAKE_GATE_STATUS.csv",
    "FIRST_REAL_SLICE_VALUE_INTAKE_NEXT_COMMANDS.md",
]:
    path = work_root / "external_return_form" / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing published intake artifact: {name}")
with (work_root / "external_return_form" / "FIRST_REAL_SLICE_VALUE_INTAKE_TODO.csv").open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len([item for item in rows if item["current_status"] == "blocked"]) != 5:
    raise SystemExit("expected five blocked intake rows including missing form/ack files")
print("v61hn publish-only smoke passed")
PY

echo "v61hn first real slice value intake closeout packet smoke passed"
