#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61er_real_generation_intake_dispatch_receipt_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_RECEIPT_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_input"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_preflight_v61er"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61eq_real_generation_intake_dispatch_seal.sh" >/dev/null

V61ER_REUSE_EXISTING="${V61ER_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null

rm -rf "$FIXTURE_RECEIPT_DIR"
mkdir -p "$FIXTURE_RECEIPT_DIR"

python3 - "$ROOT_DIR" "$FIXTURE_RECEIPT_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
receipt_dir = Path(sys.argv[2])
sha_path = root / "results/v61eq_real_generation_intake_dispatch_seal/seal_001/dispatch_bundle/BUNDLE_SHA256SUMS.txt"
h = hashlib.sha256()
with sha_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        h.update(chunk)
payload = {
    "dispatch_bundle_sha256": "sha256:" + h.hexdigest(),
    "operator_identity": "fixture-v61er-operator",
    "sent_at_utc": "2026-06-14T00:00:00+00:00",
    "recipient": "fixture-receiver",
    "receipt_status": "sent",
}
(receipt_dir / "DISPATCH_RECEIPT.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61ER_RUN_ID="fixture_dispatch_receipt_preflight_v61er" \
V61ER_DISPATCH_RECEIPT_DIR="$FIXTURE_RECEIPT_DIR" \
V61ER_RECEIPT_PROVENANCE="fixture-v61er-dispatch-receipt" \
V61ER_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null

V61ER_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


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
    "v61er_real_generation_intake_dispatch_receipt_preflight_ready": "1",
    "v61eq_real_generation_intake_dispatch_seal_ready": "1",
    "receipt_dir_supplied": "0",
    "receipt_dir_exists": "0",
    "selected_receipt_source_class": "none",
    "dispatch_receipt_file_present": "0",
    "dispatch_receipt_json_readable": "0",
    "required_receipt_field_rows": "5",
    "present_receipt_field_rows": "0",
    "dispatch_bundle_sha_match": "0",
    "receipt_status_sent": "0",
    "dispatch_receipt_candidate_preflight_ready": "0",
    "non_fixture_dispatch_receipt": "0",
    "real_dispatch_receipt_provenance_asserted": "0",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61er": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61er {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_intake_dispatch_receipt_file_rows.csv",
    "real_generation_intake_dispatch_receipt_field_check_rows.csv",
    "real_generation_intake_dispatch_receipt_preflight_check_rows.csv",
    "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv",
    "real_generation_intake_dispatch_receipt_command_rows.csv",
    "runtime_gap_rows.csv",
    "V61ER_REAL_GENERATION_INTAKE_DISPATCH_RECEIPT_PREFLIGHT_BOUNDARY.md",
    "v61er_real_generation_intake_dispatch_receipt_preflight_manifest.json",
    "source_v61eq/v61eq_real_generation_intake_dispatch_seal_summary.csv",
    "source_v61eq/real_generation_intake_dispatch_receipt_contract_rows.csv",
    "source_v61eq/DISPATCH_MANIFEST.json",
    "source_v61eq/BUNDLE_SHA256SUMS.txt",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61er artifact: {rel}")

checks = {row["check_id"]: row["status"] for row in read_csv(run_dir / "real_generation_intake_dispatch_receipt_preflight_check_rows.csv")}
for check in [
    "receipt-dir-supplied",
    "dispatch-receipt-file-present",
    "dispatch-receipt-candidate-preflight-ready",
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "real-generation-intake-handoff",
    "actual-model-generation",
]:
    if checks[check] != "blocked":
        raise SystemExit(f"v61er canonical check should be blocked: {check}")

commands = read_csv(run_dir / "real_generation_intake_dispatch_receipt_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0"]:
    raise SystemExit("v61er canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv")[0]
fixture_expected = {
    "receipt_dir_supplied": "1",
    "receipt_dir_exists": "1",
    "selected_receipt_source_class": "fixture-v61er-dispatch-receipt",
    "dispatch_receipt_file_present": "1",
    "dispatch_receipt_json_readable": "1",
    "required_receipt_field_rows": "5",
    "present_receipt_field_rows": "5",
    "dispatch_bundle_sha_match": "1",
    "receipt_status_sent": "1",
    "dispatch_receipt_candidate_preflight_ready": "1",
    "non_fixture_dispatch_receipt": "0",
    "real_dispatch_receipt_provenance_asserted": "0",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61er fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_checks = {row["check_id"]: row["status"] for row in read_csv(fixture_run_dir / "real_generation_intake_dispatch_receipt_preflight_check_rows.csv")}
for check in [
    "receipt-dir-supplied",
    "receipt-dir-exists",
    "dispatch-receipt-file-present",
    "dispatch-receipt-json-readable",
    "required-receipt-fields-present",
    "dispatch-bundle-sha-match",
    "receipt-status-sent",
    "operator-identity-present",
    "recipient-present",
    "sent-at-present",
    "dispatch-receipt-candidate-preflight-ready",
]:
    if fixture_checks[check] != "pass":
        raise SystemExit(f"v61er fixture check should pass: {check}")
for check in [
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "real-generation-intake-handoff",
    "actual-model-generation",
]:
    if fixture_checks[check] != "blocked":
        raise SystemExit(f"v61er fixture check should remain blocked: {check}")

if not (fixture_run_dir / "supplied_dispatch_receipt/DISPATCH_RECEIPT.json").is_file():
    raise SystemExit("v61er fixture receipt was not copied")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["v61eq-dispatch-bundle-ready"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61er source/repo decisions should pass")
for gate in [
    "dispatch-receipt-candidate-preflight",
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "real-generation-intake",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61er canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61ER_REAL_GENERATION_INTAKE_DISPATCH_RECEIPT_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "receipt_dir_supplied=0",
    "dispatch_receipt_candidate_preflight_ready=0",
    "real_dispatch_receipt_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61er boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61er_real_generation_intake_dispatch_receipt_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61er_real_generation_intake_dispatch_receipt_preflight_ready") != 1:
    raise SystemExit("v61er manifest readiness mismatch")
if manifest.get("real_dispatch_receipt_ready") != 0:
    raise SystemExit("v61er canonical manifest must keep real receipt blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61er manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61er sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61er produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61er real generation intake dispatch receipt preflight smoke passed"
