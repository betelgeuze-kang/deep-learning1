#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ht_post_hs_first_real_slice_env_repair_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_repair_packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_repair_packet"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61ht first real slice workspace"

V61HT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ht_post_hs_first_real_slice_env_repair_packet.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_REPAIR_PACKET.sh" >/dev/null

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
    "v61ht_post_hs_first_real_slice_env_repair_packet_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "repair_packet_published": "0",
    "env_file_exists": "0",
    "preflight_report_exists": "0",
    "repair_rows_contain_values": "0",
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
        raise SystemExit(f"v61ht default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_env_repair_todo_rows.csv",
    "FIRST_REAL_SLICE_ENV_REPAIR_NEXT_COMMANDS.md",
    "first_real_slice_env_repair_published_rows.csv",
    "first_real_slice_env_repair_packet/FIRST_REAL_SLICE_ENV_REPAIR_PACKET_MANIFEST.json",
    "first_real_slice_env_repair_packet/VERIFY_FIRST_REAL_SLICE_ENV_REPAIR_PACKET.sh",
    "V61HT_POST_HS_FIRST_REAL_SLICE_ENV_REPAIR_PACKET_BOUNDARY.md",
    "v61ht_post_hs_first_real_slice_env_repair_packet_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61ht artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61ht sha256 mismatch: {rel}")
print("v61ht default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv" <<'CSV'
env_name,field_path,status,required,evidence
V61HO_EXTERNAL_RETURN_ATTESTATION,external_return_attestation,blocked,1,nonfinal-token
V61HO_CHECKPOINT_ROOT,v61_generation_return.checkpoint_root,pass,1,exists=1; safetensors=59
V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN,operator_attests_real_external_return,blocked,1,expected-true:false
CSV
touch "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env"

V61HT_RUN_ID="publish_only" \
V61HT_WORK_ROOT="$TMP_WORK_ROOT" \
V61HT_PUBLISH_REPAIR=1 \
V61HT_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ht_post_hs_first_real_slice_env_repair_packet.sh" >/dev/null

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
    "repair_packet_published": "1",
    "env_file_exists": "1",
    "preflight_report_exists": "1",
    "preflight_pass_rows": "1",
    "repair_blocked_rows": "2",
    "repair_rows_contain_values": "0",
    "next_real_subset_action": "repair-first-real-slice-values-env-file",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61ht publish-only {key}: expected {value}, got {row.get(key)}")
todo = work_root / "external_return_form" / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv"
commands = work_root / "external_return_form" / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_NEXT_COMMANDS.md"
if not todo.is_file() or not commands.is_file():
    raise SystemExit("published repair artifacts missing")
with todo.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 2:
    raise SystemExit(f"expected 2 repair rows, got {len(rows)}")
if any(item["contains_value"] != "0" for item in rows):
    raise SystemExit("repair rows claim to contain values")
if not any(item["env_name"] == "V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN" for item in rows):
    raise SystemExit("missing attestation repair row")
print("v61ht publish-only repair smoke passed")
PY

echo "v61ht first real slice env repair packet smoke passed"
