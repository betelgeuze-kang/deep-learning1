#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dw_return_bundle_operator_handoff_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BUNDLE_DIR="$RUN_DIR/handoff_bundle"

V61DW_REUSE_EXISTING="${V61DW_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dw_return_bundle_operator_handoff_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BUNDLE_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
bundle_dir = Path(sys.argv[4])


def sha256_file(path):
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
    "v61dw_return_bundle_operator_handoff_bundle_ready": "1",
    "v61dv_return_bundle_operator_work_order_ready": "1",
    "source_gate_rows": "1",
    "handoff_stage_rows": "5",
    "ready_handoff_stage_rows": "3",
    "blocked_handoff_stage_rows": "2",
    "validation_rows": "3",
    "ready_validation_rows": "2",
    "work_order_stage_rows": "9",
    "ready_work_order_stage_rows": "4",
    "artifact_work_order_rows": "81",
    "ready_artifact_work_order_rows": "76",
    "blocked_artifact_work_order_rows": "5",
    "missing_payload_rows": "17483",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dw {field}: expected {value}, got {summary.get(field)}")
if summary["handoff_bundle_file_rows"] != summary["metadata_only_bundle_file_rows"]:
    raise SystemExit("v61dw bundle files must all be metadata-only")
if int(summary["handoff_bundle_file_rows"]) < 10:
    raise SystemExit("v61dw expected at least ten bundle files")

required_files = [
    "return_bundle_operator_handoff_bundle_file_rows.csv",
    "return_bundle_operator_handoff_validation_rows.csv",
    "return_bundle_operator_handoff_stage_rows.csv",
    "return_bundle_operator_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DW_RETURN_BUNDLE_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md",
    "v61dw_return_bundle_operator_handoff_bundle_manifest.json",
    "handoff_bundle/RETURN_BUNDLE_WORK_ORDER.md",
    "handoff_bundle/READY_NOW_COMMANDS.sh",
    "handoff_bundle/VERIFY_HANDOFF_BUNDLE.sh",
    "handoff_bundle/BUNDLE_MANIFEST.json",
    "handoff_bundle/BUNDLE_FILE_LIST.txt",
    "handoff_bundle/BUNDLE_SHA256SUMS.txt",
    "handoff_bundle/work_order/RETURN_BUNDLE_STAGE_ROWS.csv",
    "handoff_bundle/work_order/RETURN_BUNDLE_ARTIFACT_ROWS.csv",
    "handoff_bundle/work_order/RETURN_BUNDLE_ROW_DELTAS.csv",
    "handoff_bundle/work_order/RETURN_BUNDLE_COMMAND_ROWS.csv",
    "source_v61dv/v61dv_return_bundle_operator_work_order_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dw artifact: {rel}")

stage_rows = read_csv(run_dir / "return_bundle_operator_handoff_stage_rows.csv")
validation_rows = read_csv(run_dir / "return_bundle_operator_handoff_validation_rows.csv")
file_rows = read_csv(run_dir / "return_bundle_operator_handoff_bundle_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if [row["status"] for row in stage_rows] != ["ready", "ready", "ready", "blocked", "blocked"]:
    raise SystemExit("v61dw handoff stage posture mismatch")
if [row["ready_to_run_now"] for row in validation_rows] != ["1", "1", "0"]:
    raise SystemExit("v61dw validation readiness mismatch")
if any(row["payload_class"] != "metadata-only" for row in file_rows):
    raise SystemExit("v61dw found non-metadata bundle file")
for gate in ["01-work-order-source", "02-bundle-metadata", "03-bundle-verifier", "operator-handoff-bundle-ready", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dw expected pass gate: {gate}")
for gate in ["04-return-evidence", "05-actual-generation", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dw expected blocked gate: {gate}")
if gaps.get("05-actual-generation") != "blocked":
    raise SystemExit("v61dw actual-generation gap must remain blocked")

bundle_manifest = json.loads((bundle_dir / "BUNDLE_MANIFEST.json").read_text(encoding="utf-8"))
if bundle_manifest.get("artifact_work_order_rows") != 81:
    raise SystemExit("v61dw bundle manifest artifact count mismatch")
if bundle_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dw bundle manifest must keep generation blocked")

boundary = (run_dir / "V61DW_RETURN_BUNDLE_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "handoff_stage_rows=5",
    "ready_handoff_stage_rows=3",
    "blocked_handoff_stage_rows=2",
    "artifact_work_order_rows=81",
    "ready_artifact_work_order_rows=76",
    "blocked_artifact_work_order_rows=5",
    "missing_payload_rows=17483",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dw boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256_file(run_dir / rel):
        raise SystemExit(f"v61dw sha256 mismatch: {rel}")
PY

"$BUNDLE_DIR/VERIFY_HANDOFF_BUNDLE.sh" >/dev/null
"$BUNDLE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dw produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dw return bundle operator handoff bundle smoke passed"
