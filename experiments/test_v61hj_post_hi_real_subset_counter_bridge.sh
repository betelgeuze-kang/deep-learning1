#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hj_post_hi_real_subset_counter_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/counter_bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/real_subset_counter_bridge"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hj first real slice workspace"

V61HJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_REAL_SUBSET_COUNTER_BRIDGE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = Path(sys.argv[4])


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
    "v61hj_post_hi_real_subset_counter_bridge_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "filled_form_supplied": "0",
    "filled_form_validation_ready": "0",
    "authority_ack_supplied": "0",
    "authority_ack_validation_ready": "0",
    "bridge_execute_requested": "0",
    "bridge_execute_admitted": "0",
    "bridge_executed": "0",
    "operator_input_files_ready": "0",
    "dual_output_roots_ready": "0",
    "partial_counter_audit_ready": "0",
    "subset_real_return_counters_opened": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61hj default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_subset_counter_bridge_source_rows.csv",
    "real_subset_counter_bridge_published_rows.csv",
    "real_subset_counter_bridge_root_rows.csv",
    "real_subset_counter_bridge_operator_input_file_rows.csv",
    "real_subset_counter_bridge_counter_rows.csv",
    "real_subset_counter_bridge_stage_rows.csv",
    "real_subset_counter_bridge_command_rows.csv",
    "filled_form.validation_rows.csv",
    "dual_replay_authority_ack.validation_rows.csv",
    "real_subset_counter_bridge_package_file_rows.csv",
    "V61HJ_POST_HI_REAL_SUBSET_COUNTER_BRIDGE_BOUNDARY.md",
    "v61hj_post_hi_real_subset_counter_bridge_manifest.json",
    "v61hj_post_hi_real_subset_counter_bridge_summary.csv",
    "v61hj_post_hi_real_subset_counter_bridge_decision.csv",
    "real_subset_counter_bridge/REAL_SUBSET_COUNTER_BRIDGE_MANIFEST.json",
    "real_subset_counter_bridge/REAL_SUBSET_COUNTER_BRIDGE_COUNTER_ROWS.csv",
    "real_subset_counter_bridge/REAL_SUBSET_COUNTER_BRIDGE_STAGE_ROWS.csv",
    "real_subset_counter_bridge/REAL_SUBSET_COUNTER_BRIDGE_COMMAND_ROWS.csv",
    "real_subset_counter_bridge/FILLED_FORM_VALIDATION_ROWS.csv",
    "real_subset_counter_bridge/DUAL_REPLAY_AUTHORITY_ACK_VALIDATION_ROWS.csv",
    "real_subset_counter_bridge/NEXT_REAL_SUBSET_ACTION.txt",
    "real_subset_counter_bridge/VERIFY_REAL_SUBSET_COUNTER_BRIDGE.sh",
    "real_subset_counter_bridge/CHECK_REAL_SUBSET_COUNTERS_OPENED.py",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61hj artifact: {rel}")
    if rel != "sha256_manifest.csv" and path.stat().st_size == 0:
        raise SystemExit(f"empty v61hj artifact: {rel}")
if not os.access(package_dir / "VERIFY_REAL_SUBSET_COUNTER_BRIDGE.sh", os.X_OK):
    raise SystemExit("v61hj verifier executable bit missing")
if not os.access(package_dir / "CHECK_REAL_SUBSET_COUNTERS_OPENED.py", os.X_OK):
    raise SystemExit("v61hj counter checker executable bit missing")
blocked = subprocess.run([str(package_dir / "CHECK_REAL_SUBSET_COUNTERS_OPENED.py")], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if blocked.returncode == 0:
    raise SystemExit("v61hj counter checker should fail before real counters open")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61hj sha256 mismatch: {rel}")
print("v61hj default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"

V61HJ_RUN_ID="publish_only" \
V61HJ_WORK_ROOT="$TMP_WORK_ROOT" \
V61HJ_PUBLISH_BRIDGE=1 \
V61HJ_EXECUTE_BRIDGE=0 \
V61HJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh" >/dev/null

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
    "publish_bridge_requested": "1",
    "published_bridge": "1",
    "bridge_execute_requested": "0",
    "bridge_executed": "0",
    "filled_form_validation_ready": "0",
    "authority_ack_validation_ready": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "next_real_subset_action": "fill-and-validate-first-real-slice-external-return-form",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hj publish-only {key}: expected {value}, got {row.get(key)}")
runner = work_root / "RUN_REAL_SUBSET_COUNTER_BRIDGE.sh"
readme = work_root / "REAL_SUBSET_COUNTER_BRIDGE_README.md"
if not runner.is_file() or not os.access(runner, os.X_OK):
    raise SystemExit("v61hj published runner missing or not executable")
if not readme.is_file() or readme.stat().st_size == 0:
    raise SystemExit("v61hj bridge readme missing")
syntax = subprocess.run(["bash", "-n", str(runner)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if syntax.returncode != 0:
    raise SystemExit(f"published runner bash -n failed: {syntax.stderr}")
print("v61hj publish-only smoke passed")
PY

echo "v61hj real subset counter bridge smoke passed"
