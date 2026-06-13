#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_decision.csv"

V61CL_REUSE_EXISTING="${V61CL_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake.sh" >/dev/null

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
source_queue_rows = [row for row in read_csv(run_dir / "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv") if row["shard_name"] != "none"]
source_skip_rows = [row for row in read_csv(run_dir / "source_v61bv/verified_checkpoint_shard_skip_rows.csv") if row["shard_name"] != "none"]
source_chunk_rows = [row for row in read_csv(run_dir / "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv") if row["priority_class"] != "none"]
expected_rows = len(source_queue_rows)
expected_bytes = sum(int(row["remaining_bytes"]) for row in source_queue_rows)
existing_verified_rows = len(source_skip_rows)
existing_verified_bytes = sum(int(row["actual_bytes_present"]) for row in source_skip_rows)
total_required_rows = expected_rows + existing_verified_rows
no_remaining_queue = expected_rows == 0
expected_return_status = "pass" if no_remaining_queue else "blocked"
expected_ready_gap = "ready" if no_remaining_queue else "blocked"
expected_return_schema_ready = "1" if no_remaining_queue else "0"
expected_return_artifact_ready = "1" if no_remaining_queue else "0"
expected_return_intake_ready = "1" if no_remaining_queue else "0"
expected_full_materialization_ready = "1" if no_remaining_queue else "0"

expected_static = {
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "materialization_return_input_supplied": "0",
    "supplied_remaining_materialization_return_rows": "0",
    "accepted_remaining_materialization_return_rows": "0",
    "invalid_remaining_materialization_return_rows": "0",
    "accepted_remaining_materialization_bytes": "0",
    "total_identity_verified_checkpoint_shard_rows": str(existing_verified_rows),
    "return_schema_template_ready": "1",
    "return_schema_ready": expected_return_schema_ready,
    "return_artifact_ready": expected_return_artifact_ready,
    "remaining_materialization_return_intake_ready": expected_return_intake_ready,
    "full_checkpoint_materialization_ready": expected_full_materialization_ready,
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected_static.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cl {field}: expected {value}, got {summary.get(field)}")

expected_dynamic = {
    "expected_remaining_materialization_return_rows": str(expected_rows),
    "missing_remaining_materialization_return_rows": str(expected_rows),
    "expected_remaining_materialization_bytes": str(expected_bytes),
    "missing_remaining_materialization_bytes": str(expected_bytes),
    "existing_verified_checkpoint_shard_rows": str(existing_verified_rows),
    "existing_verified_checkpoint_shard_bytes": str(existing_verified_bytes),
    "total_required_checkpoint_shard_rows": str(total_required_rows),
    "remaining_materialization_chunk_rows": str(len(source_chunk_rows)),
}
for field, value in expected_dynamic.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cl {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "remaining_checkpoint_materialization_return_required_field_rows.csv",
    "remaining_checkpoint_materialization_return_template_rows.csv",
    "remaining_checkpoint_materialization_return_invalid_rows.csv",
    "remaining_checkpoint_materialization_return_queue_status_rows.csv",
    "remaining_checkpoint_materialization_return_chunk_status_rows.csv",
    "existing_checkpoint_materialization_preservation_rows.csv",
    "remaining_checkpoint_materialization_return_validation_rows.csv",
    "remaining_checkpoint_materialization_return_requirement_rows.csv",
    "remaining_checkpoint_materialization_return_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CL_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_RETURN_INTAKE_BOUNDARY.md",
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv",
    "source_v61bv/verified_checkpoint_shard_skip_rows.csv",
    "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cl artifact: {rel}")

required_fields = read_csv(run_dir / "remaining_checkpoint_materialization_return_required_field_rows.csv")
templates = read_csv(run_dir / "remaining_checkpoint_materialization_return_template_rows.csv")
invalid_rows = read_csv(run_dir / "remaining_checkpoint_materialization_return_invalid_rows.csv")
queue_status_rows = read_csv(run_dir / "remaining_checkpoint_materialization_return_queue_status_rows.csv")
chunk_status_rows = read_csv(run_dir / "remaining_checkpoint_materialization_return_chunk_status_rows.csv")
preservation_rows = read_csv(run_dir / "existing_checkpoint_materialization_preservation_rows.csv")
validation_rows = {row["validation_id"]: row for row in read_csv(run_dir / "remaining_checkpoint_materialization_return_validation_rows.csv")}
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "remaining_checkpoint_materialization_return_requirement_rows.csv")}
metric = read_csv(run_dir / "remaining_checkpoint_materialization_return_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(required_fields) != 14 or len(templates) != 2:
    raise SystemExit("v61cl required field/template row count mismatch")
if invalid_rows[0]["status"] != "none":
    raise SystemExit("v61cl default path should not create invalid supplied rows")
if len(queue_status_rows) != expected_rows:
    raise SystemExit("v61cl queue status row count mismatch")
if expected_rows:
    if sum(int(row["missing_return_rows"]) for row in queue_status_rows) != expected_rows:
        raise SystemExit("v61cl queue missing return row sum mismatch")
    if sum(int(row["missing_bytes"]) for row in queue_status_rows) != expected_bytes:
        raise SystemExit("v61cl queue missing byte sum mismatch")
    if any(row["accepted_return_rows"] != "0" or row["invalid_return_rows"] != "0" for row in queue_status_rows):
        raise SystemExit("v61cl default path should accept no return rows")
    if any(row["result_status"] != "deferred-with-reason-final" for row in queue_status_rows):
        raise SystemExit("v61cl default path should final-defer all queue rows")
    if any(row["checkpoint_payload_bytes_downloaded_by_v61cl"] != "0" for row in queue_status_rows):
        raise SystemExit("v61cl must not download checkpoint payload bytes")
    if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in queue_status_rows):
        raise SystemExit("v61cl must not commit checkpoint payload bytes")

if len(chunk_status_rows) != len(source_chunk_rows):
    raise SystemExit("v61cl chunk status row count mismatch")
if expected_rows:
    if sum(int(row["planned_materialization_return_rows"]) for row in chunk_status_rows) != expected_rows:
        raise SystemExit("v61cl chunk planned return row sum mismatch")
    if sum(int(row["missing_materialization_return_rows"]) for row in chunk_status_rows) != expected_rows:
        raise SystemExit("v61cl chunk missing return row sum mismatch")
    if sum(int(row["planned_remaining_bytes"]) for row in chunk_status_rows) != expected_bytes:
        raise SystemExit("v61cl chunk planned byte sum mismatch")
    if sum(int(row["missing_remaining_bytes"]) for row in chunk_status_rows) != expected_bytes:
        raise SystemExit("v61cl chunk missing byte sum mismatch")
    if any(row["result_status"] != "deferred-with-reason-final" for row in chunk_status_rows):
        raise SystemExit("v61cl default path should final-defer all chunks")

if len(preservation_rows) != existing_verified_rows:
    raise SystemExit("v61cl preservation row count mismatch")
if sum(int(row["identity_verified_bytes"]) for row in preservation_rows) != existing_verified_bytes:
    raise SystemExit("v61cl preservation byte sum mismatch")
if any(row["preservation_status"] != "preserved-existing-v61bv-identity-verified-shard" for row in preservation_rows):
    raise SystemExit("v61cl preservation status mismatch")

if validation_rows["remaining-materialization-return-input"]["status"] != expected_return_status:
    raise SystemExit("v61cl return input status mismatch")
if validation_rows["remaining-materialization-return-schema"]["status"] != expected_return_status:
    raise SystemExit("v61cl return schema status mismatch")
if validation_rows["remaining-materialization-return-completeness"]["status"] != expected_return_status:
    raise SystemExit("v61cl completeness status mismatch")
if validation_rows["existing-checkpoint-materialization-preservation"]["status"] != "pass":
    raise SystemExit("v61cl existing materialization preservation should pass")
if validation_rows["final-deferred-default"]["status"] != "pass":
    raise SystemExit("v61cl default deferral should pass")
if validation_rows["final-deferred-default"]["missing_rows"] != str(expected_rows):
    raise SystemExit("v61cl default deferral should record all missing return rows")

for requirement_id in ["v61bv-remaining-queue-input", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cl requirement should pass: {requirement_id}")
for requirement_id in ["remaining-materialization-return-artifact", "accepted-all-remaining-materialization-returns"]:
    if requirements[requirement_id]["status"] != expected_return_status:
        raise SystemExit(f"v61cl requirement status mismatch: {requirement_id}")
if requirements["completed-full-checkpoint-materialization"]["status"] != ("pass" if no_remaining_queue else "blocked"):
    raise SystemExit("v61cl completed full materialization requirement status mismatch")

for field, value in {**expected_static, **expected_dynamic}.items():
    if field.startswith("v61cl_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cl metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61bv-remaining-queue-input",
    "return-schema-template",
    "existing-checkpoint-materialization-preservation",
    "default-no-env-deferral",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cl gate should pass: {gate}")
for gate in ["remaining-materialization-return-artifact", "accepted-all-remaining-materialization-returns"]:
    if decisions.get(gate) != expected_return_status:
        raise SystemExit(f"v61cl gate status mismatch: {gate}")
if decisions.get("completed-full-checkpoint-materialization") != ("pass" if no_remaining_queue else "blocked"):
    raise SystemExit("v61cl completed full materialization gate status mismatch")
for gate in ["full-safetensors-page-hash-binding", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cl gate should stay blocked: {gate}")

if gaps["v61bv-remaining-queue-input"] != "ready":
    raise SystemExit("v61cl v61bv input gap should be ready")
for gap in ["remaining-materialization-return-artifact", "accepted-all-remaining-materialization-returns"]:
    if gaps.get(gap) != expected_ready_gap:
        raise SystemExit(f"v61cl gap status mismatch: {gap}")
if gaps.get("completed-full-checkpoint-materialization") != expected_ready_gap:
    raise SystemExit("v61cl completed full materialization gap status mismatch")
for gap in ["full-safetensors-page-hash-binding", "actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cl gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready") != 1:
    raise SystemExit("v61cl manifest readiness mismatch")
if manifest.get("accepted_remaining_materialization_return_rows") != 0:
    raise SystemExit("v61cl manifest accepted return count mismatch")
if manifest.get("missing_remaining_materialization_return_rows") != expected_rows:
    raise SystemExit("v61cl manifest missing return count mismatch")
if manifest.get("full_checkpoint_materialization_ready") != int(no_remaining_queue):
    raise SystemExit("v61cl manifest full materialization readiness mismatch")

boundary = (run_dir / "V61CL_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "materialization_return_input_supplied=0",
    f"expected_remaining_materialization_return_rows={expected_rows}",
    "accepted_remaining_materialization_return_rows=0",
    f"missing_remaining_materialization_return_rows={expected_rows}",
    f"expected_remaining_materialization_bytes={expected_bytes}",
    f"missing_remaining_materialization_bytes={expected_bytes}",
    f"existing_verified_checkpoint_shard_rows={existing_verified_rows}",
    f"total_required_checkpoint_shard_rows={total_required_rows}",
    f"total_identity_verified_checkpoint_shard_rows={existing_verified_rows}",
    f"remaining_materialization_return_intake_ready={int(no_remaining_queue)}",
    f"full_checkpoint_materialization_ready={int(no_remaining_queue)}",
    "checkpoint_payload_bytes_downloaded_by_v61cl=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cl boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cl sha256 mismatch: {rel}")
PY

echo "v61cl ubuntu-1 remaining checkpoint materialization return intake smoke passed"
