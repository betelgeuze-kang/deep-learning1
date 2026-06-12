#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ca_ubuntu1_remaining_page_hash_result_intake"
RUN_ID="${V61CA_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
DEFAULT_RESULT_DIR="$RESULTS_DIR/v61bz_ubuntu1_remaining_page_hash_operator_bundle/bundle_001/operator_bundle/page_hash_execution_results"
SUPPLIED_DIR="${V61CA_PAGE_HASH_RESULT_DIR:-}"

if [[ -z "$SUPPLIED_DIR" && -f "$DEFAULT_RESULT_DIR/remaining_page_hash_result_rows.csv" ]]; then
  SUPPLIED_DIR="$DEFAULT_RESULT_DIR"
fi

if [[ "${V61CA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ca_ubuntu1_remaining_page_hash_result_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
supplied_arg = sys.argv[5].strip()
results = root / "results"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
v61bz_dir = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle" / "bundle_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"

RESULT_FILE = "remaining_page_hash_result_rows.csv"
REQUIRED_RESULT_FIELDS = [
    "remaining_page_hash_chunk_id",
    "model_id",
    "shard_name",
    "target_path",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_bytes_hashed",
    "local_page_sha256",
    "local_hash_verified",
]
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
PAGE_SIZE = 2 * 1024 * 1024


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


def read_supplied_results():
    if supplied_dir is None:
        return [], [], False, ""
    path = supplied_dir / RESULT_FILE
    if not path.is_file():
        return [], [], False, ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []
    return rows, fields, True, sha256(path)


v61bz_summary_path = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv"
v61bz_decision_path = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv"
v61bz_summary = read_csv(v61bz_summary_path)[0]
if v61bz_summary.get("v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready") != "1":
    raise SystemExit("v61ca requires v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready=1")
if v61bz_summary.get("remaining_page_hash_operator_bundle_ready") != "1":
    raise SystemExit("v61ca requires remaining_page_hash_operator_bundle_ready=1")

for src, rel in [
    (v61bz_summary_path, "source_v61bz/v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv"),
    (v61bz_decision_path, "source_v61bz/v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv"),
    (v61bz_dir / "operator_bundle/remaining_page_hash_execution_chunk_rows.csv", "source_v61bz/remaining_page_hash_execution_chunk_rows.csv"),
    (v61bz_dir / "operator_bundle/verified_page_hash_skip_rows.csv", "source_v61bz/verified_page_hash_skip_rows.csv"),
    (v61bz_dir / "operator_bundle/remaining_page_hash_result_schema_rows.csv", "source_v61bz/remaining_page_hash_result_schema_rows.csv"),
    (v61bz_dir / "remaining_page_hash_operator_metric_rows.csv", "source_v61bz/remaining_page_hash_operator_metric_rows.csv"),
    (v61bz_dir / "runtime_gap_rows.csv", "source_v61bz/runtime_gap_rows.csv"),
    (v61bz_dir / "sha256_manifest.csv", "source_v61bz/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v61bz_dir / "operator_bundle/remaining_page_hash_execution_chunk_rows.csv")
skip_rows = read_csv(v61bz_dir / "operator_bundle/verified_page_hash_skip_rows.csv")
chunk_by_id = {row["remaining_page_hash_chunk_id"]: row for row in chunk_rows}

required_field_rows = [
    {
        "result_artifact": RESULT_FILE,
        "field_name": field,
        "requirement_status": "required",
        "purpose": "bind executed local page hashes back to the reviewed v61bz chunk row",
    }
    for field in REQUIRED_RESULT_FIELDS
]
write_csv(run_dir / "remaining_page_hash_result_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": RESULT_FILE,
        "example_row_id": "remaining_page_hash_result_example",
        "example_payload": ",".join(REQUIRED_RESULT_FIELDS),
    },
    {
        "result_artifact": "acceptance_note",
        "example_row_id": "acceptance_note_example",
        "example_payload": "Rows must be hash-only metadata; checkpoint payload bytes remain outside the repository.",
    },
]
write_csv(run_dir / "remaining_page_hash_result_template_rows.csv", list(template_rows[0].keys()), template_rows)

supplied_rows, supplied_fields, supplied, supplied_sha = read_supplied_results()
if supplied:
    supplied_copy = run_dir / "supplied_remaining_page_hash_results" / RESULT_FILE
    supplied_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(supplied_dir / RESULT_FILE, supplied_copy)

missing_fields = [field for field in REQUIRED_RESULT_FIELDS if field not in supplied_fields]
accepted_rows = []
invalid_rows = []
seen_pages = set()
chunk_status = {
    row["remaining_page_hash_chunk_id"]: {
        "accepted_page_hash_rows": 0,
        "invalid_page_hash_rows": 0,
    }
    for row in chunk_rows
}

for index, row in enumerate(supplied_rows):
    reasons = []
    chunk_id = row.get("remaining_page_hash_chunk_id", "")
    chunk = chunk_by_id.get(chunk_id)
    if missing_fields:
        reasons.append("missing-fields:" + ";".join(missing_fields))
    if not chunk:
        reasons.append("unknown-chunk-id")
    else:
        for field in ["model_id", "shard_name", "target_path"]:
            if row.get(field, "") != chunk[field]:
                reasons.append(f"{field}-mismatch")
    shard_page_index = parse_int(row.get("shard_page_index", ""), "shard_page_index", reasons)
    page_start = parse_int(row.get("page_start_byte", ""), "page_start_byte", reasons)
    page_end = parse_int(row.get("page_end_byte_exclusive", ""), "page_end_byte_exclusive", reasons)
    page_bytes = parse_int(row.get("page_bytes_hashed", ""), "page_bytes_hashed", reasons)
    if chunk and shard_page_index is not None:
        start_index = int(chunk["chunk_page_start_index"])
        end_index = int(chunk["chunk_page_end_index_exclusive"])
        if shard_page_index < start_index or shard_page_index >= end_index:
            reasons.append("shard-page-index-outside-chunk")
    if shard_page_index is not None and page_start is not None:
        if page_start != shard_page_index * PAGE_SIZE:
            reasons.append("page-start-byte-mismatch")
    if page_start is not None and page_end is not None and page_bytes is not None:
        if page_end <= page_start:
            reasons.append("page-end-not-after-start")
        if page_end - page_start != page_bytes:
            reasons.append("page-byte-count-mismatch")
        if page_bytes <= 0 or page_bytes > PAGE_SIZE:
            reasons.append("page-bytes-out-of-range")
    if not SHA_RE.match(row.get("local_page_sha256", "")):
        reasons.append("local-page-sha256-invalid")
    if row.get("local_hash_verified", "") != "1":
        reasons.append("local-hash-not-verified")
    if chunk and shard_page_index is not None:
        page_key = (chunk["shard_name"], shard_page_index)
        if page_key in seen_pages:
            reasons.append("duplicate-shard-page-index")
        seen_pages.add(page_key)
    if reasons:
        if chunk_id in chunk_status:
            chunk_status[chunk_id]["invalid_page_hash_rows"] += 1
        invalid_rows.append(
            {
                "row_index": str(index),
                "remaining_page_hash_chunk_id": chunk_id,
                "shard_name": row.get("shard_name", ""),
                "shard_page_index": row.get("shard_page_index", ""),
                "status": "invalid",
                "reason": ";".join(reasons),
            }
        )
    else:
        chunk_status[chunk_id]["accepted_page_hash_rows"] += 1
        accepted_rows.append(row)

write_csv(
    run_dir / "remaining_page_hash_result_invalid_rows.csv",
    ["row_index", "remaining_page_hash_chunk_id", "shard_name", "shard_page_index", "status", "reason"],
    invalid_rows
    or [
        {
            "row_index": "",
            "remaining_page_hash_chunk_id": "",
            "shard_name": "",
            "shard_page_index": "",
            "status": "none",
            "reason": "no invalid supplied rows",
        }
    ],
)

expected_remaining_rows = int(v61bz_summary["remaining_page_hash_rows"])
existing_verified_rows = int(v61bz_summary["verified_page_hash_rows"])
expected_total_rows = existing_verified_rows + expected_remaining_rows
accepted_result_rows = len(accepted_rows)
invalid_result_rows = len(invalid_rows)
supplied_result_rows = len(supplied_rows)
missing_result_rows = max(expected_remaining_rows - accepted_result_rows, 0)
total_verified_rows = existing_verified_rows + accepted_result_rows
result_schema_ready = int(supplied and not missing_fields)
result_artifact_ready = int(supplied and result_schema_ready and invalid_result_rows == 0 and accepted_result_rows > 0)
remaining_result_intake_ready = int(result_artifact_ready and accepted_result_rows == expected_remaining_rows)
full_coverage_ready = int(remaining_result_intake_ready and total_verified_rows == expected_total_rows)

chunk_status_rows = []
for chunk in chunk_rows:
    chunk_id = chunk["remaining_page_hash_chunk_id"]
    planned = int(chunk["planned_page_hash_rows"])
    accepted = chunk_status[chunk_id]["accepted_page_hash_rows"]
    invalid = chunk_status[chunk_id]["invalid_page_hash_rows"]
    missing = max(planned - accepted, 0)
    if accepted == planned and invalid == 0:
        status = "complete"
    elif accepted > 0 or invalid > 0:
        status = "partial"
    else:
        status = "deferred-with-reason-final"
    chunk_status_rows.append(
        {
            "remaining_page_hash_chunk_id": chunk_id,
            "model_id": model_id,
            "shard_name": chunk["shard_name"],
            "target_path": chunk["target_path"],
            "planned_page_hash_rows": str(planned),
            "accepted_page_hash_rows": str(accepted),
            "invalid_page_hash_rows": str(invalid),
            "missing_page_hash_rows": str(missing),
            "result_status": status,
            "checkpoint_payload_bytes_downloaded_by_v61ca": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "remaining_page_hash_result_chunk_status_rows.csv", list(chunk_status_rows[0].keys()), chunk_status_rows)

preservation_rows = []
for row in skip_rows:
    preservation_rows.append(
        {
            "preservation_row_id": row["skip_page_hash_row_id"],
            "model_id": model_id,
            "shard_name": row["shard_name"],
            "target_path": row["target_path"],
            "verified_page_hash_rows": row["verified_page_hash_rows"],
            "verified_page_hash_bytes": row["verified_page_hash_bytes"],
            "preservation_status": "preserved-existing-v61bw-page-hash-witness",
            "checkpoint_payload_bytes_downloaded_by_v61ca": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "existing_page_hash_preservation_rows.csv", list(preservation_rows[0].keys()), preservation_rows)

validation_rows = [
    {
        "validation_id": "remaining-page-hash-result-input",
        "status": "pass" if supplied else "blocked",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_result_rows),
        "accepted_rows": str(accepted_result_rows),
        "missing_rows": str(missing_result_rows),
        "reason": "result artifact supplied" if supplied else "result artifact not supplied",
    },
    {
        "validation_id": "remaining-page-hash-result-schema",
        "status": "pass" if result_schema_ready else "blocked",
        "expected_rows": str(len(REQUIRED_RESULT_FIELDS)),
        "supplied_rows": str(len(supplied_fields)),
        "accepted_rows": str(int(not missing_fields and supplied)),
        "missing_rows": str(len(missing_fields)),
        "reason": "all required fields present" if result_schema_ready else "missing supplied artifact or fields",
    },
    {
        "validation_id": "remaining-page-hash-result-completeness",
        "status": "pass" if remaining_result_intake_ready else "blocked",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_result_rows),
        "accepted_rows": str(accepted_result_rows),
        "missing_rows": str(missing_result_rows),
        "reason": "all remaining page hashes accepted" if remaining_result_intake_ready else "remaining page hashes still missing",
    },
    {
        "validation_id": "existing-page-hash-preservation",
        "status": "pass",
        "expected_rows": str(existing_verified_rows),
        "supplied_rows": str(existing_verified_rows),
        "accepted_rows": str(existing_verified_rows),
        "missing_rows": "0",
        "reason": "existing verified page-hash witness rows are preserved",
    },
    {
        "validation_id": "final-deferred-default",
        "status": "pass" if not supplied else "not-applicable",
        "expected_rows": str(expected_remaining_rows),
        "supplied_rows": str(supplied_result_rows),
        "accepted_rows": str(accepted_result_rows),
        "missing_rows": str(missing_result_rows),
        "reason": "default path records explicit missing result rows without claiming execution",
    },
]
write_csv(run_dir / "remaining_page_hash_result_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

requirement_rows = [
    {
        "requirement_id": "v61bz-operator-bundle-input",
        "status": "pass",
        "required_value": "v61bz ready",
        "actual_value": v61bz_summary["v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready"],
        "reason": "operator bundle is bound",
    },
    {
        "requirement_id": "remaining-page-hash-result-artifact",
        "status": "pass" if result_artifact_ready else "blocked",
        "required_value": RESULT_FILE,
        "actual_value": str(int(supplied)),
        "reason": "requires hash result CSV from v61bz operator execution",
    },
    {
        "requirement_id": "accepted-all-remaining-page-hash-results",
        "status": "pass" if remaining_result_intake_ready else "blocked",
        "required_value": str(expected_remaining_rows),
        "actual_value": str(accepted_result_rows),
        "reason": "full coverage requires every remaining page hash",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if full_coverage_ready else "blocked",
        "required_value": str(expected_total_rows),
        "actual_value": str(total_verified_rows),
        "reason": "existing verified rows plus accepted remaining rows must cover the full checkpoint",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "intake stores metadata and supplied hashes only",
    },
]
write_csv(run_dir / "remaining_page_hash_result_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ca_ubuntu1_remaining_page_hash_result_intake_metrics",
    "model_id": model_id,
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": v61bz_summary["v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready"],
    "target_root_path": v61bz_summary["target_root_path"],
    "page_hash_result_input_supplied": str(int(supplied)),
    "expected_remaining_page_hash_result_rows": str(expected_remaining_rows),
    "supplied_remaining_page_hash_result_rows": str(supplied_result_rows),
    "accepted_remaining_page_hash_result_rows": str(accepted_result_rows),
    "invalid_remaining_page_hash_result_rows": str(invalid_result_rows),
    "missing_remaining_page_hash_result_rows": str(missing_result_rows),
    "existing_verified_page_hash_rows": str(existing_verified_rows),
    "total_required_page_hash_rows": str(expected_total_rows),
    "total_verified_page_hash_rows": str(total_verified_rows),
    "remaining_page_hash_execution_chunk_rows": str(len(chunk_rows)),
    "result_schema_ready": str(result_schema_ready),
    "result_artifact_ready": str(result_artifact_ready),
    "remaining_page_hash_result_intake_ready": str(remaining_result_intake_ready),
    "completed_full_safetensors_page_hash_coverage_ready": str(full_coverage_ready),
    "full_safetensors_page_hash_binding_ready": str(full_coverage_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ca": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "remaining_page_hash_result_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61bz-operator-bundle-input", "ready", "operator bundle is bound"),
    ("remaining-page-hash-result-artifact", "ready" if result_artifact_ready else "blocked", f"supplied_remaining_page_hash_result_rows={supplied_result_rows}"),
    ("accepted-all-remaining-page-hash-results", "ready" if remaining_result_intake_ready else "blocked", f"accepted_remaining_page_hash_result_rows={accepted_result_rows}"),
    ("completed-full-safetensors-page-hash-coverage", "ready" if full_coverage_ready else "blocked", f"total_verified_page_hash_rows={total_verified_rows}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "no production latency run"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bz-operator-bundle-input", "status": "pass", "reason": "v61bz operator bundle is bound"},
    {"gate": "result-schema-template", "status": "pass", "reason": "required result schema is emitted"},
    {"gate": "existing-page-hash-preservation", "status": "pass", "reason": f"existing_verified_page_hash_rows={existing_verified_rows}"},
    {"gate": "default-no-env-deferral", "status": "pass" if not supplied else "not-applicable", "reason": "default path defers missing result rows"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ca writes metadata and hash rows only"},
    {"gate": "remaining-page-hash-result-artifact", "status": "pass" if result_artifact_ready else "blocked", "reason": f"supplied_remaining_page_hash_result_rows={supplied_result_rows}"},
    {"gate": "accepted-all-remaining-page-hash-results", "status": "pass" if remaining_result_intake_ready else "blocked", "reason": f"accepted_remaining_page_hash_result_rows={accepted_result_rows}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_coverage_ready else "blocked", "reason": f"total_verified_page_hash_rows={total_verified_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ca Ubuntu-1 Remaining Page-Hash Result Intake Boundary

This gate ingests hash-only result rows from the v61bz remaining page-hash
operator bundle. It does not execute page hashing, does not download checkpoint
payload bytes, and does not commit checkpoint payload bytes to the repository.

Evidence emitted:

- page_hash_result_input_supplied={int(supplied)}
- expected_remaining_page_hash_result_rows={expected_remaining_rows}
- supplied_remaining_page_hash_result_rows={supplied_result_rows}
- accepted_remaining_page_hash_result_rows={accepted_result_rows}
- invalid_remaining_page_hash_result_rows={invalid_result_rows}
- missing_remaining_page_hash_result_rows={missing_result_rows}
- existing_verified_page_hash_rows={existing_verified_rows}
- total_required_page_hash_rows={expected_total_rows}
- total_verified_page_hash_rows={total_verified_rows}
- remaining_page_hash_execution_chunk_rows={len(chunk_rows)}
- remaining_page_hash_result_intake_ready={remaining_result_intake_ready}
- completed_full_safetensors_page_hash_coverage_ready={full_coverage_ready}
- full_safetensors_page_hash_binding_ready={full_coverage_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ca=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: remaining page-hash result intake schema and default deferral.
Blocked wording: executed remaining page hashes, completed full safetensors
page-hash coverage, actual model generation, production latency, near-frontier
quality, or release readiness unless accepted result rows cover every remaining
page.
"""
(run_dir / "V61CA_UBUNTU1_REMAINING_PAGE_HASH_RESULT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ca_ubuntu1_remaining_page_hash_result_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": 1,
    "source_v61bz_summary_sha256": sha256(v61bz_summary_path),
    "page_hash_result_input_supplied": int(supplied),
    "expected_remaining_page_hash_result_rows": expected_remaining_rows,
    "accepted_remaining_page_hash_result_rows": accepted_result_rows,
    "missing_remaining_page_hash_result_rows": missing_result_rows,
    "existing_verified_page_hash_rows": existing_verified_rows,
    "total_verified_page_hash_rows": total_verified_rows,
    "full_safetensors_page_hash_binding_ready": full_coverage_ready,
    "checkpoint_payload_bytes_downloaded_by_v61ca": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
if supplied_sha:
    manifest["supplied_result_sha256"] = supplied_sha
(run_dir / "v61ca_ubuntu1_remaining_page_hash_result_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ca_ubuntu1_remaining_page_hash_result_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
