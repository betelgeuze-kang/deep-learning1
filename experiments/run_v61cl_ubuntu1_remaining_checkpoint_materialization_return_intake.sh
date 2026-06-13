#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake"
RUN_ID="${V61CL_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
DEFAULT_RETURN_DIR="$RESULTS_DIR/v61bv_ubuntu1_remaining_checkpoint_materialization_queue/queue_001/operator_bundle/materialization_return_results"
SUPPLIED_DIR="${V61CL_MATERIALIZATION_RETURN_DIR:-}"

if [[ -z "$SUPPLIED_DIR" && -f "$DEFAULT_RETURN_DIR/remaining_checkpoint_materialization_return_rows.csv" ]]; then
  SUPPLIED_DIR="$DEFAULT_RETURN_DIR"
fi

if [[ "${V61CL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
supplied_arg = sys.argv[5].strip()
results = root / "results"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
v61bv_dir = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue" / "queue_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"

RETURN_FILE = "remaining_checkpoint_materialization_return_rows.csv"
REQUIRED_RETURN_FIELDS = [
    "remaining_queue_row_id",
    "resumed_priority_rank",
    "model_id",
    "shard_name",
    "target_path",
    "expected_bytes",
    "actual_bytes",
    "local_file_exists",
    "size_match",
    "local_header_hash_match",
    "local_identity_verified",
    "download_exit_code",
    "materialization_status",
    "identity_verification_transcript_sha256",
]
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def parse_int(value, field, reasons):
    try:
        return int(value)
    except (TypeError, ValueError):
        reasons.append(f"{field}-not-int")
        return None


def read_supplied_returns():
    if supplied_dir is None:
        return [], [], False, ""
    path = supplied_dir / RETURN_FILE
    if not path.is_file():
        return [], [], False, ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []
    return rows, fields, True, sha256(path)


v61bv_summary_path = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"
v61bv_decision_path = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv"
v61bv_summary = read_csv(v61bv_summary_path)[0]
if v61bv_summary.get("v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready") != "1":
    raise SystemExit("v61cl requires v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1")
remaining_queue_rows_from_summary = int(v61bv_summary.get("remaining_queue_rows", "0"))
if v61bv_summary.get("remaining_queue_ready") != "1" and not (
    remaining_queue_rows_from_summary == 0 and v61bv_summary.get("full_checkpoint_materialization_ready") == "1"
):
    raise SystemExit("v61cl requires v61bv remaining_queue_ready=1 or completed empty remaining queue")

for src, rel in [
    (v61bv_summary_path, "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"),
    (v61bv_decision_path, "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_queue_rows.csv", "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv"),
    (v61bv_dir / "verified_checkpoint_shard_skip_rows.csv", "source_v61bv/verified_checkpoint_shard_skip_rows.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_chunk_rows.csv", "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_requirement_rows.csv", "source_v61bv/remaining_checkpoint_materialization_requirement_rows.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_metric_rows.csv", "source_v61bv/remaining_checkpoint_materialization_metric_rows.csv"),
    (v61bv_dir / "runtime_gap_rows.csv", "source_v61bv/runtime_gap_rows.csv"),
    (v61bv_dir / "sha256_manifest.csv", "source_v61bv/sha256_manifest.csv"),
]:
    copy(src, rel)

queue_rows = [row for row in read_csv(v61bv_dir / "remaining_checkpoint_materialization_queue_rows.csv") if row["shard_name"] != "none"]
skip_rows = [row for row in read_csv(v61bv_dir / "verified_checkpoint_shard_skip_rows.csv") if row["shard_name"] != "none"]
chunk_rows = [row for row in read_csv(v61bv_dir / "remaining_checkpoint_materialization_chunk_rows.csv") if row["priority_class"] != "none"]
queue_by_id = {row["remaining_queue_row_id"]: row for row in queue_rows}

required_field_rows = [
    {
        "result_artifact": RETURN_FILE,
        "field_name": field,
        "requirement_status": "required",
        "purpose": "bind returned materialization evidence back to the reviewed v61bv remaining queue row",
    }
    for field in REQUIRED_RETURN_FIELDS
]
write_csv(run_dir / "remaining_checkpoint_materialization_return_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": RETURN_FILE,
        "example_row_id": "remaining_checkpoint_materialization_return_example",
        "example_payload": ",".join(REQUIRED_RETURN_FIELDS),
    },
    {
        "result_artifact": "acceptance_note",
        "example_row_id": "acceptance_note_example",
        "example_payload": "Rows must be metadata receipts; checkpoint payload bytes remain outside the repository.",
    },
]
write_csv(run_dir / "remaining_checkpoint_materialization_return_template_rows.csv", list(template_rows[0].keys()), template_rows)

supplied_rows, supplied_fields, supplied, supplied_sha = read_supplied_returns()
if supplied:
    supplied_copy = run_dir / "supplied_remaining_checkpoint_materialization_returns" / RETURN_FILE
    supplied_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(supplied_dir / RETURN_FILE, supplied_copy)

missing_fields = [field for field in REQUIRED_RETURN_FIELDS if field not in supplied_fields]
accepted_rows = []
invalid_rows = []
seen_queue_ids = set()
status_by_queue = {
    row["remaining_queue_row_id"]: {
        "accepted_return_rows": 0,
        "invalid_return_rows": 0,
        "accepted_bytes": 0,
    }
    for row in queue_rows
}

for index, row in enumerate(supplied_rows):
    reasons = []
    queue_id = row.get("remaining_queue_row_id", "")
    queue = queue_by_id.get(queue_id)
    if missing_fields:
        reasons.append("missing-fields:" + ";".join(missing_fields))
    if not queue:
        reasons.append("unknown-remaining-queue-row-id")
    else:
        for field in ["resumed_priority_rank", "model_id", "shard_name", "target_path", "expected_bytes"]:
            if row.get(field, "") != queue[field]:
                reasons.append(f"{field}-mismatch")
    expected_bytes = parse_int(row.get("expected_bytes", ""), "expected_bytes", reasons)
    actual_bytes = parse_int(row.get("actual_bytes", ""), "actual_bytes", reasons)
    if expected_bytes is not None and actual_bytes is not None and actual_bytes != expected_bytes:
        reasons.append("actual-bytes-not-equal-expected-bytes")
    for field in ["local_file_exists", "size_match", "local_header_hash_match", "local_identity_verified"]:
        if row.get(field, "") != "1":
            reasons.append(f"{field}-not-verified")
    if row.get("download_exit_code", "") != "0":
        reasons.append("download-exit-code-nonzero")
    if row.get("materialization_status", "") != "identity-verified":
        reasons.append("materialization-status-not-identity-verified")
    if not SHA_RE.match(row.get("identity_verification_transcript_sha256", "")):
        reasons.append("identity-verification-transcript-sha256-invalid")
    if queue_id:
        if queue_id in seen_queue_ids:
            reasons.append("duplicate-remaining-queue-row-id")
        seen_queue_ids.add(queue_id)
    if queue:
        target_path = Path(queue["target_path"])
        if not target_path.is_file():
            reasons.append("live-target-file-missing")
        elif actual_bytes is not None and target_path.stat().st_size != actual_bytes:
            reasons.append("live-target-file-size-mismatch")
    if reasons:
        if queue_id in status_by_queue:
            status_by_queue[queue_id]["invalid_return_rows"] += 1
        invalid_rows.append(
            {
                "row_index": str(index),
                "remaining_queue_row_id": queue_id,
                "shard_name": row.get("shard_name", ""),
                "status": "invalid",
                "reason": ";".join(reasons),
            }
        )
    else:
        status_by_queue[queue_id]["accepted_return_rows"] += 1
        status_by_queue[queue_id]["accepted_bytes"] += actual_bytes or 0
        accepted_rows.append(row)

write_csv(
    run_dir / "remaining_checkpoint_materialization_return_invalid_rows.csv",
    ["row_index", "remaining_queue_row_id", "shard_name", "status", "reason"],
    invalid_rows
    or [
        {
            "row_index": "",
            "remaining_queue_row_id": "",
            "shard_name": "",
            "status": "none",
            "reason": "no invalid supplied rows",
        }
    ],
)

expected_remaining_rows = len(queue_rows)
supplied_return_rows = len(supplied_rows)
accepted_return_rows = len(accepted_rows)
invalid_return_rows = len(invalid_rows)
missing_return_rows = max(expected_remaining_rows - accepted_return_rows, 0)
expected_remaining_bytes = sum(int(row["remaining_bytes"]) for row in queue_rows)
accepted_remaining_bytes = sum(int(row["actual_bytes"]) for row in accepted_rows)
missing_remaining_bytes = max(expected_remaining_bytes - accepted_remaining_bytes, 0)
existing_verified_rows = len(skip_rows)
existing_verified_bytes = sum(int(row["actual_bytes_present"]) for row in skip_rows)
total_required_rows = existing_verified_rows + expected_remaining_rows
total_identity_verified_rows = existing_verified_rows + accepted_return_rows
no_remaining_queue = expected_remaining_rows == 0
effective_missing_fields = [] if no_remaining_queue else missing_fields
return_schema_ready = int(no_remaining_queue or (supplied and not effective_missing_fields))
return_artifact_ready = int(
    no_remaining_queue
    or (supplied and return_schema_ready and invalid_return_rows == 0 and accepted_return_rows > 0)
)
remaining_return_intake_ready = int(
    no_remaining_queue
    or (return_artifact_ready and accepted_return_rows == expected_remaining_rows)
)
full_materialization_ready = int(remaining_return_intake_ready and total_identity_verified_rows == total_required_rows)

queue_status_rows = []
queue_status_fields = [
    "remaining_queue_row_id",
    "resumed_priority_rank",
    "model_id",
    "shard_name",
    "priority_class",
    "target_path",
    "expected_bytes",
    "accepted_return_rows",
    "invalid_return_rows",
    "missing_return_rows",
    "accepted_bytes",
    "missing_bytes",
    "result_status",
    "checkpoint_payload_bytes_downloaded_by_v61cl",
    "checkpoint_payload_bytes_committed_to_repo",
    "route_jump_rows",
]
for queue in queue_rows:
    queue_id = queue["remaining_queue_row_id"]
    accepted = status_by_queue[queue_id]["accepted_return_rows"]
    invalid = status_by_queue[queue_id]["invalid_return_rows"]
    accepted_bytes = status_by_queue[queue_id]["accepted_bytes"]
    expected_bytes = int(queue["expected_bytes"])
    missing = 0 if accepted == 1 and invalid == 0 else 1
    if accepted == 1 and invalid == 0:
        status = "complete"
    elif accepted > 0 or invalid > 0:
        status = "partial"
    else:
        status = "deferred-with-reason-final"
    queue_status_rows.append(
        {
            "remaining_queue_row_id": queue_id,
            "resumed_priority_rank": queue["resumed_priority_rank"],
            "model_id": model_id,
            "shard_name": queue["shard_name"],
            "priority_class": queue["priority_class"],
            "target_path": queue["target_path"],
            "expected_bytes": str(expected_bytes),
            "accepted_return_rows": str(accepted),
            "invalid_return_rows": str(invalid),
            "missing_return_rows": str(missing),
            "accepted_bytes": str(accepted_bytes),
            "missing_bytes": str(max(expected_bytes - accepted_bytes, 0)),
            "result_status": status,
            "checkpoint_payload_bytes_downloaded_by_v61cl": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "remaining_checkpoint_materialization_return_queue_status_rows.csv", queue_status_fields, queue_status_rows)

accepted_by_priority = defaultdict(int)
invalid_by_priority = defaultdict(int)
accepted_bytes_by_priority = defaultdict(int)
for row in queue_status_rows:
    priority_class = row["priority_class"]
    accepted_by_priority[priority_class] += int(row["accepted_return_rows"])
    invalid_by_priority[priority_class] += int(row["invalid_return_rows"])
    accepted_bytes_by_priority[priority_class] += int(row["accepted_bytes"])

chunk_status_rows = []
chunk_status_fields = [
    "remaining_chunk_id",
    "priority_class",
    "planned_materialization_return_rows",
    "accepted_materialization_return_rows",
    "invalid_materialization_return_rows",
    "missing_materialization_return_rows",
    "planned_remaining_bytes",
    "accepted_remaining_bytes",
    "missing_remaining_bytes",
    "result_status",
    "checkpoint_payload_bytes_downloaded_by_v61cl",
    "checkpoint_payload_bytes_committed_to_repo",
]
for chunk in chunk_rows:
    priority_class = chunk["priority_class"]
    planned = int(chunk["remaining_queue_rows"])
    planned_bytes = int(chunk["remaining_bytes"])
    accepted = accepted_by_priority[priority_class]
    invalid = invalid_by_priority[priority_class]
    accepted_bytes = accepted_bytes_by_priority[priority_class]
    missing = max(planned - accepted, 0)
    if accepted == planned and invalid == 0:
        status = "complete"
    elif accepted > 0 or invalid > 0:
        status = "partial"
    else:
        status = "deferred-with-reason-final"
    chunk_status_rows.append(
        {
            "remaining_chunk_id": chunk["remaining_chunk_id"],
            "priority_class": priority_class,
            "planned_materialization_return_rows": str(planned),
            "accepted_materialization_return_rows": str(accepted),
            "invalid_materialization_return_rows": str(invalid),
            "missing_materialization_return_rows": str(missing),
            "planned_remaining_bytes": str(planned_bytes),
            "accepted_remaining_bytes": str(accepted_bytes),
            "missing_remaining_bytes": str(max(planned_bytes - accepted_bytes, 0)),
            "result_status": status,
            "checkpoint_payload_bytes_downloaded_by_v61cl": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "remaining_checkpoint_materialization_return_chunk_status_rows.csv", chunk_status_fields, chunk_status_rows)

preservation_rows = []
preservation_fields = [
    "preservation_row_id",
    "model_id",
    "shard_name",
    "target_path",
    "identity_verified_bytes",
    "preservation_status",
    "checkpoint_payload_bytes_downloaded_by_v61cl",
    "checkpoint_payload_bytes_committed_to_repo",
]
for row in skip_rows:
    preservation_rows.append(
        {
            "preservation_row_id": row["skip_row_id"],
            "model_id": model_id,
            "shard_name": row["shard_name"],
            "target_path": row["target_path"],
            "identity_verified_bytes": row["actual_bytes_present"],
            "preservation_status": "preserved-existing-v61bv-identity-verified-shard",
            "checkpoint_payload_bytes_downloaded_by_v61cl": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "existing_checkpoint_materialization_preservation_rows.csv", preservation_fields, preservation_rows)

schema_expected_fields = 0 if no_remaining_queue else len(REQUIRED_RETURN_FIELDS)
schema_supplied_fields = 0 if no_remaining_queue else len(supplied_fields)
schema_missing_fields = 0 if no_remaining_queue else len(effective_missing_fields)

validation_rows = [
    {
        "validation_id": "remaining-materialization-return-input",
        "status": "pass" if supplied or no_remaining_queue else "blocked",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_return_rows),
        "accepted_rows": str(accepted_return_rows),
        "missing_rows": str(missing_return_rows),
        "reason": "no remaining materialization returns required" if no_remaining_queue else ("return artifact supplied" if supplied else "return artifact not supplied"),
    },
    {
        "validation_id": "remaining-materialization-return-schema",
        "status": "pass" if return_schema_ready else "blocked",
        "expected_rows": str(schema_expected_fields),
        "supplied_rows": str(schema_supplied_fields),
        "accepted_rows": str(int(return_schema_ready)),
        "missing_rows": str(schema_missing_fields),
        "reason": "no return schema required for empty remaining queue" if no_remaining_queue else ("all required fields present" if return_schema_ready else "missing supplied artifact or fields"),
    },
    {
        "validation_id": "remaining-materialization-return-completeness",
        "status": "pass" if remaining_return_intake_ready else "blocked",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_return_rows),
        "accepted_rows": str(accepted_return_rows),
        "missing_rows": str(missing_return_rows),
        "reason": "no remaining materialization returns required" if no_remaining_queue else ("all remaining materialization returns accepted" if remaining_return_intake_ready else "remaining materialization returns still missing"),
    },
    {
        "validation_id": "existing-checkpoint-materialization-preservation",
        "status": "pass",
        "expected_rows": str(existing_verified_rows),
        "supplied_rows": str(existing_verified_rows),
        "accepted_rows": str(existing_verified_rows),
        "missing_rows": "0",
        "reason": "existing identity-verified shard rows are preserved",
    },
    {
        "validation_id": "final-deferred-default",
        "status": "pass" if not supplied else "not-applicable",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_return_rows),
        "accepted_rows": str(accepted_return_rows),
        "missing_rows": str(missing_return_rows),
        "reason": "empty remaining queue needs no return rows" if no_remaining_queue else "default path records explicit missing return rows without claiming execution",
    },
]
write_csv(run_dir / "remaining_checkpoint_materialization_return_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

requirement_rows = [
    {
        "requirement_id": "v61bv-remaining-queue-input",
        "status": "pass",
        "required_value": "v61bv ready",
        "actual_value": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
        "reason": "remaining checkpoint materialization queue is bound",
    },
    {
        "requirement_id": "remaining-materialization-return-artifact",
        "status": "pass" if return_artifact_ready else "blocked",
        "required_value": RETURN_FILE,
        "actual_value": "not-required" if no_remaining_queue else str(int(supplied)),
        "reason": "no remaining materialization returns required" if no_remaining_queue else "requires materialization return CSV from v61bv operator execution",
    },
    {
        "requirement_id": "accepted-all-remaining-materialization-returns",
        "status": "pass" if remaining_return_intake_ready else "blocked",
        "required_value": str(expected_remaining_rows),
        "actual_value": str(accepted_return_rows),
        "reason": "no remaining materialization returns required" if no_remaining_queue else "full materialization requires every remaining shard return",
    },
    {
        "requirement_id": "completed-full-checkpoint-materialization",
        "status": "pass" if full_materialization_ready else "blocked",
        "required_value": str(total_required_rows),
        "actual_value": str(total_identity_verified_rows),
        "reason": "existing verified shard plus accepted remaining returns must cover every checkpoint shard",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "intake stores metadata and supplied receipts only",
    },
]
write_csv(run_dir / "remaining_checkpoint_materialization_return_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_metrics",
    "model_id": model_id,
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
    "target_root_path": v61bv_summary["target_root_path"],
    "materialization_return_input_supplied": str(int(supplied)),
    "expected_remaining_materialization_return_rows": str(expected_remaining_rows),
    "supplied_remaining_materialization_return_rows": str(supplied_return_rows),
    "accepted_remaining_materialization_return_rows": str(accepted_return_rows),
    "invalid_remaining_materialization_return_rows": str(invalid_return_rows),
    "missing_remaining_materialization_return_rows": str(missing_return_rows),
    "expected_remaining_materialization_bytes": str(expected_remaining_bytes),
    "accepted_remaining_materialization_bytes": str(accepted_remaining_bytes),
    "missing_remaining_materialization_bytes": str(missing_remaining_bytes),
    "existing_verified_checkpoint_shard_rows": str(existing_verified_rows),
    "existing_verified_checkpoint_shard_bytes": str(existing_verified_bytes),
    "total_required_checkpoint_shard_rows": str(total_required_rows),
    "total_identity_verified_checkpoint_shard_rows": str(total_identity_verified_rows),
    "remaining_materialization_chunk_rows": str(len(chunk_rows)),
    "return_schema_template_ready": "1",
    "return_schema_ready": str(return_schema_ready),
    "return_artifact_ready": str(return_artifact_ready),
    "remaining_materialization_return_intake_ready": str(remaining_return_intake_ready),
    "full_checkpoint_materialization_ready": str(full_materialization_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "remaining_checkpoint_materialization_return_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61bv-remaining-queue-input", "ready", "remaining checkpoint materialization queue is bound"),
    ("remaining-materialization-return-artifact", "ready" if return_artifact_ready else "blocked", f"supplied_remaining_materialization_return_rows={supplied_return_rows}"),
    ("accepted-all-remaining-materialization-returns", "ready" if remaining_return_intake_ready else "blocked", f"accepted_remaining_materialization_return_rows={accepted_return_rows}"),
    ("completed-full-checkpoint-materialization", "ready" if full_materialization_ready else "blocked", f"total_identity_verified_checkpoint_shard_rows={total_identity_verified_rows}"),
    ("full-safetensors-page-hash-binding", "blocked", "not a page-hash runner"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "no production latency run"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bv-remaining-queue-input", "status": "pass", "reason": "v61bv remaining queue is bound"},
    {"gate": "return-schema-template", "status": "pass", "reason": "required return schema is emitted"},
    {"gate": "existing-checkpoint-materialization-preservation", "status": "pass", "reason": f"existing_verified_checkpoint_shard_rows={existing_verified_rows}"},
    {"gate": "default-no-env-deferral", "status": "pass" if not supplied else "not-applicable", "reason": "default path defers missing return rows"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cl writes metadata and return rows only"},
    {"gate": "remaining-materialization-return-artifact", "status": "pass" if return_artifact_ready else "blocked", "reason": "no remaining materialization returns required" if no_remaining_queue else f"supplied_remaining_materialization_return_rows={supplied_return_rows}"},
    {"gate": "accepted-all-remaining-materialization-returns", "status": "pass" if remaining_return_intake_ready else "blocked", "reason": "no remaining materialization returns required" if no_remaining_queue else f"accepted_remaining_materialization_return_rows={accepted_return_rows}"},
    {"gate": "completed-full-checkpoint-materialization", "status": "pass" if full_materialization_ready else "blocked", "reason": f"total_identity_verified_checkpoint_shard_rows={total_identity_verified_rows}"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "not a page-hash runner"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cl Ubuntu-1 Remaining Checkpoint Materialization Return Intake Boundary

This gate ingests metadata-only materialization return rows from the v61bv
remaining checkpoint materialization operator queue. It does not download
checkpoint payload bytes and does not commit checkpoint payload bytes to the
repository.

Evidence emitted:

- materialization_return_input_supplied={int(supplied)}
- expected_remaining_materialization_return_rows={expected_remaining_rows}
- supplied_remaining_materialization_return_rows={supplied_return_rows}
- accepted_remaining_materialization_return_rows={accepted_return_rows}
- invalid_remaining_materialization_return_rows={invalid_return_rows}
- missing_remaining_materialization_return_rows={missing_return_rows}
- expected_remaining_materialization_bytes={expected_remaining_bytes}
- accepted_remaining_materialization_bytes={accepted_remaining_bytes}
- missing_remaining_materialization_bytes={missing_remaining_bytes}
- existing_verified_checkpoint_shard_rows={existing_verified_rows}
- total_required_checkpoint_shard_rows={total_required_rows}
- total_identity_verified_checkpoint_shard_rows={total_identity_verified_rows}
- remaining_materialization_chunk_rows={len(chunk_rows)}
- remaining_materialization_return_intake_ready={remaining_return_intake_ready}
- full_checkpoint_materialization_ready={full_materialization_ready}
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cl=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: remaining checkpoint materialization return intake schema,
default deferral, and completed full checkpoint materialization when no
remaining queue rows exist or accepted return rows cover every remaining shard.
Blocked wording: full safetensors page-hash binding, actual model generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CL_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready": 1,
    "source_v61bv_summary_sha256": sha256(v61bv_summary_path),
    "materialization_return_input_supplied": int(supplied),
    "expected_remaining_materialization_return_rows": expected_remaining_rows,
    "accepted_remaining_materialization_return_rows": accepted_return_rows,
    "missing_remaining_materialization_return_rows": missing_return_rows,
    "expected_remaining_materialization_bytes": expected_remaining_bytes,
    "accepted_remaining_materialization_bytes": accepted_remaining_bytes,
    "missing_remaining_materialization_bytes": missing_remaining_bytes,
    "existing_verified_checkpoint_shard_rows": existing_verified_rows,
    "total_identity_verified_checkpoint_shard_rows": total_identity_verified_rows,
    "full_checkpoint_materialization_ready": full_materialization_ready,
    "checkpoint_payload_bytes_downloaded_by_v61cl": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
if supplied_sha:
    manifest["supplied_return_sha256"] = supplied_sha
(run_dir / "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
