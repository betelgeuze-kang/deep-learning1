#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dq_return_schema_remediation_packet_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DQ_REUSE_EXISTING="${V61DQ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dq_return_schema_remediation_packet_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v61dq_return_schema_remediation_packet_gate_ready": "1",
    "v61dp_return_schema_acceptance_blocker_gate_ready": "1",
    "source_gate_rows": "1",
    "remediation_packet_ready": "1",
    "remediation_family_rows": "4",
    "remediation_artifact_rows": "81",
    "remediation_command_rows": "4",
    "ready_remediation_command_rows": "3",
    "expected_schema_artifact_rows": "81",
    "accepted_schema_artifact_rows": "0",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "schema_acceptance_ready": "0",
    "return_bundle_preflight_pass": "0",
    "preflight_only_gap_detected": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dq {field}: expected {value}, got {summary.get(field)}")
if int(summary["template_file_rows"]) < 10:
    raise SystemExit("v61dq expected at least 10 template/header files")

required_files = [
    "return_schema_remediation_artifact_rows.csv",
    "return_schema_remediation_family_rows.csv",
    "return_schema_remediation_command_rows.csv",
    "return_schema_remediation_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DQ_RETURN_SCHEMA_REMEDIATION_PACKET_GATE_BOUNDARY.md",
    "v61dq_return_schema_remediation_packet_gate_manifest.json",
    "schema_remediation_templates/dispatch_receipt_template.json",
    "source_v61dp/return_schema_acceptance_blocker_family_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dq artifact: {rel}")

artifact_rows = read_csv(run_dir / "return_schema_remediation_artifact_rows.csv")
family_rows = {row["schema_family"]: row for row in read_csv(run_dir / "return_schema_remediation_family_rows.csv")}
command_rows = read_csv(run_dir / "return_schema_remediation_command_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(artifact_rows) != 81:
    raise SystemExit("v61dq expected 81 artifact remediation rows")
if set(family_rows) != {"dispatch-receipt-json", "review-chunk-return-csv", "aggregate-review-return", "generation-result-return"}:
    raise SystemExit("v61dq family set mismatch")
if family_rows["dispatch-receipt-json"]["remediation_artifact_rows"] != "21":
    raise SystemExit("v61dq dispatch remediation count mismatch")
if family_rows["review-chunk-return-csv"]["remediation_artifact_rows"] != "50":
    raise SystemExit("v61dq review chunk remediation count mismatch")
if family_rows["aggregate-review-return"]["remediation_artifact_rows"] != "5":
    raise SystemExit("v61dq aggregate remediation count mismatch")
if family_rows["generation-result-return"]["remediation_artifact_rows"] != "5":
    raise SystemExit("v61dq generation remediation count mismatch")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "1", "0"]:
    raise SystemExit("v61dq command readiness mismatch")
if decisions.get("remediation-packet-surface") != "pass":
    raise SystemExit("v61dq remediation surface should pass")
for gate in ["schema-acceptance", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dq gate should stay blocked: {gate}")

boundary = (run_dir / "V61DQ_RETURN_SCHEMA_REMEDIATION_PACKET_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "remediation_packet_ready=1",
    "remediation_family_rows=4",
    "remediation_artifact_rows=81",
    "expected_schema_artifact_rows=81",
    "accepted_schema_artifact_rows=0",
    "expected_payload_rows=17483",
    "accepted_payload_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61dq=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dq boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dq_return_schema_remediation_packet_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("remediation_artifact_rows") != 81:
    raise SystemExit("v61dq manifest remediation count mismatch")
if manifest.get("accepted_payload_rows") != 0:
    raise SystemExit("v61dq manifest must not accept payload rows")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dq manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dq sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dq produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dq return schema remediation packet gate smoke passed"
