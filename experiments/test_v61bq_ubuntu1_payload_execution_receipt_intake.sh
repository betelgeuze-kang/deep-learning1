#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bq_ubuntu1_payload_execution_receipt_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61bq_ubuntu1_payload_execution_receipt_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bq_ubuntu1_payload_execution_receipt_intake_decision.csv"

V61BQ_REUSE_EXISTING="${V61BQ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bq_ubuntu1_payload_execution_receipt_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": "1",
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "payload_execution_receipt_input_supplied": "0",
    "expected_payload_execution_receipt_rows": "59",
    "supplied_payload_execution_receipt_rows": "0",
    "accepted_payload_execution_receipt_rows": "0",
    "invalid_payload_execution_receipt_rows": "0",
    "missing_payload_execution_receipt_rows": "59",
    "result_schema_ready": "0",
    "result_artifact_ready": "0",
    "payload_execution_receipt_intake_ready": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": "281241493344",
    "checkpoint_payload_bytes_downloaded_by_v61bq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bq {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_payload_execution_receipt_required_field_rows.csv",
    "ubuntu1_payload_execution_receipt_template_rows.csv",
    "ubuntu1_payload_execution_live_presence_rows.csv",
    "ubuntu1_payload_execution_receipt_validation_rows.csv",
    "ubuntu1_payload_execution_receipt_invalid_rows.csv",
    "ubuntu1_payload_execution_receipt_status_rows.csv",
    "ubuntu1_payload_execution_receipt_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BQ_UBUNTU1_PAYLOAD_EXECUTION_RECEIPT_INTAKE_BOUNDARY.md",
    "v61bq_ubuntu1_payload_execution_receipt_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61bp/ubuntu1_payload_execution_launch_command_rows.csv",
    "source_v61bp/ubuntu1_payload_execution_chunk_launch_rows.csv",
    "source_v61bp/ubuntu1_payload_execution_approval_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bq artifact: {rel}")

required_fields = read_csv(run_dir / "ubuntu1_payload_execution_receipt_required_field_rows.csv")
templates = read_csv(run_dir / "ubuntu1_payload_execution_receipt_template_rows.csv")
live_rows = read_csv(run_dir / "ubuntu1_payload_execution_live_presence_rows.csv")
validation_rows = {row["validation_id"]: row for row in read_csv(run_dir / "ubuntu1_payload_execution_receipt_validation_rows.csv")}
invalid_rows = read_csv(run_dir / "ubuntu1_payload_execution_receipt_invalid_rows.csv")
receipt_rows = read_csv(run_dir / "ubuntu1_payload_execution_receipt_status_rows.csv")
metric = read_csv(run_dir / "ubuntu1_payload_execution_receipt_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(required_fields) != 11 or len(templates) != 2:
    raise SystemExit("v61bq required field/template row count mismatch")
if len(live_rows) != 59 or len(receipt_rows) != 59:
    raise SystemExit("v61bq live/receipt row count mismatch")
live_existing_count = sum(1 for row in live_rows if row["local_file_exists"] == "1")
live_size_match_count = sum(1 for row in live_rows if row["size_match"] == "1")
if summary.get("live_existing_shard_rows") != str(live_existing_count):
    raise SystemExit("v61bq summary live existing count must match live rows")
if summary.get("live_size_match_shard_rows") != str(live_size_match_count):
    raise SystemExit("v61bq summary live size-match count must match live rows")
if invalid_rows[0]["status"] != "none":
    raise SystemExit("v61bq default path should not create invalid supplied rows")
for row in live_rows:
    if row["local_file_exists"] == "0" and row["actual_bytes"] != "0":
        raise SystemExit("v61bq missing local files must report zero actual bytes")
    if row["size_match"] == "1" and row["local_file_exists"] != "1":
        raise SystemExit("v61bq size-match rows must also exist locally")
    if row["size_match"] == "1" and row["actual_bytes"] != row["expected_bytes"]:
        raise SystemExit("v61bq size-match rows must match expected bytes")
if any(not row["target_path"].startswith(ubuntu1_target) for row in live_rows):
    raise SystemExit("v61bq live target paths must remain under ubuntu-1")
if any("/tmp/" in row["target_path"] for row in live_rows):
    raise SystemExit("v61bq must not contain stale /tmp target paths")
if any(row["receipt_accepted"] != "0" for row in receipt_rows):
    raise SystemExit("v61bq default path should accept no receipts")
if any(row["receipt_status"] != "deferred-with-reason-final" for row in receipt_rows):
    raise SystemExit("v61bq default path should final-defer missing receipts")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bq"] != "0" for row in receipt_rows):
    raise SystemExit("v61bq must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in receipt_rows):
    raise SystemExit("v61bq must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in receipt_rows):
    raise SystemExit("v61bq must keep route jumps at zero")

if validation_rows["payload-execution-receipt-input"]["status"] != "blocked":
    raise SystemExit("v61bq receipt input should be blocked without supplied rows")
if validation_rows["payload-execution-receipt-schema"]["status"] != "blocked":
    raise SystemExit("v61bq receipt schema should be blocked without supplied rows")
expected_live_presence_status = "pass" if live_size_match_count == 59 else "blocked"
if validation_rows["live-ubuntu1-file-presence"]["status"] != expected_live_presence_status:
    raise SystemExit("v61bq live file presence status mismatch")
if validation_rows["final-deferred-default"]["status"] != "pass":
    raise SystemExit("v61bq default deferral should pass")
if validation_rows["final-deferred-default"]["missing_rows"] != "59":
    raise SystemExit("v61bq default deferral should record all missing receipts")

for field, value in expected.items():
    if field.startswith("v61bq_") or field.startswith("v61bp_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bq metric {field}: expected {value}, got {metric[field]}")
for field, value in {
    "live_existing_shard_rows": str(live_existing_count),
    "live_size_match_shard_rows": str(live_size_match_count),
}.items():
    if metric.get(field) != value:
        raise SystemExit(f"v61bq metric {field}: expected {value}, got {metric.get(field)}")

for gate in [
    "v61bp-launch-bundle-input",
    "receipt-intake-schema-template",
    "live-presence-probe",
    "default-no-env-deferral",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bq gate should pass: {gate}")
for gate in [
    "payload-execution-receipt-artifacts",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bq gate should stay blocked: {gate}")

for gap in ["v61bp-launch-bundle-input"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bq gap should be ready: {gap}")
for gap in [
    "payload-execution-receipt-schema",
    "payload-execution-receipt-artifact",
    "live-ubuntu1-file-presence",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bq gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bq_ubuntu1_payload_execution_receipt_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bq_ubuntu1_payload_execution_receipt_intake_ready") != 1:
    raise SystemExit("v61bq manifest readiness mismatch")
if manifest.get("accepted_payload_execution_receipt_rows") != 0:
    raise SystemExit("v61bq manifest accepted receipt count mismatch")
if manifest.get("missing_payload_execution_receipt_rows") != 59:
    raise SystemExit("v61bq manifest missing receipt count mismatch")
if manifest.get("download_execution_ready") != 0:
    raise SystemExit("v61bq manifest must keep download execution blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bq") != 0:
    raise SystemExit("v61bq manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61BQ_UBUNTU1_PAYLOAD_EXECUTION_RECEIPT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "expected_payload_execution_receipt_rows=59",
    "accepted_payload_execution_receipt_rows=0",
    "missing_payload_execution_receipt_rows=59",
    f"live_existing_shard_rows={live_existing_count}",
    f"live_size_match_shard_rows={live_size_match_count}",
    "payload_execution_receipt_input_supplied=0",
    "payload_execution_receipt_intake_ready=0",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bq=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bq boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bq sha256 mismatch: {rel}")
PY
