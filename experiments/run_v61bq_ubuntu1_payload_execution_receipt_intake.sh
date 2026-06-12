#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bq_ubuntu1_payload_execution_receipt_intake"
RUN_ID="${V61BQ_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V61BQ_PAYLOAD_EXECUTION_RECEIPT_DIR:-}"

if [[ "${V61BQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bq_ubuntu1_payload_execution_receipt_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bp_ubuntu1_payload_execution_launch_bundle.sh" >/dev/null

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
v61bp_dir = results / "v61bp_ubuntu1_payload_execution_launch_bundle" / "bundle_001"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
model_id = "mistralai/Mixtral-8x22B-v0.1"

RESULT_FILE = "ubuntu1_payload_execution_receipt_rows.csv"
REQUIRED_RESULT_FIELDS = [
    "launch_command_id",
    "priority_rank",
    "shard_name",
    "target_path",
    "expected_bytes",
    "actual_bytes",
    "local_file_exists",
    "size_match",
    "download_exit_code",
    "download_status",
    "execution_transcript_sha256",
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


v61bp_summary_path = results / "v61bp_ubuntu1_payload_execution_launch_bundle_summary.csv"
v61bp_decision_path = results / "v61bp_ubuntu1_payload_execution_launch_bundle_decision.csv"
v61bp_summary = read_csv(v61bp_summary_path)[0]
if v61bp_summary.get("v61bp_ubuntu1_payload_execution_launch_bundle_ready") != "1":
    raise SystemExit("v61bq requires v61bp_ubuntu1_payload_execution_launch_bundle_ready=1")
if v61bp_summary.get("launch_command_rows") != "59":
    raise SystemExit("v61bq requires 59 launch command rows")
if v61bp_summary.get("dry_run_guard_ready") != "1":
    raise SystemExit("v61bq requires dry_run_guard_ready=1")

for src, rel in [
    (v61bp_summary_path, "source_v61bp/v61bp_ubuntu1_payload_execution_launch_bundle_summary.csv"),
    (v61bp_decision_path, "source_v61bp/v61bp_ubuntu1_payload_execution_launch_bundle_decision.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_launch_command_rows.csv", "source_v61bp/ubuntu1_payload_execution_launch_command_rows.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_chunk_launch_rows.csv", "source_v61bp/ubuntu1_payload_execution_chunk_launch_rows.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_approval_rows.csv", "source_v61bp/ubuntu1_payload_execution_approval_rows.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_launch_requirement_rows.csv", "source_v61bp/ubuntu1_payload_execution_launch_requirement_rows.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_launch_metric_rows.csv", "source_v61bp/ubuntu1_payload_execution_launch_metric_rows.csv"),
    (v61bp_dir / "runtime_gap_rows.csv", "source_v61bp/runtime_gap_rows.csv"),
    (v61bp_dir / "V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md", "source_v61bp/V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md"),
    (v61bp_dir / "v61bp_ubuntu1_payload_execution_launch_bundle_manifest.json", "source_v61bp/v61bp_ubuntu1_payload_execution_launch_bundle_manifest.json"),
    (v61bp_dir / "sha256_manifest.csv", "source_v61bp/sha256_manifest.csv"),
]:
    copy(src, rel)

launch_rows = read_csv(v61bp_dir / "ubuntu1_payload_execution_launch_command_rows.csv")
chunk_rows = read_csv(v61bp_dir / "ubuntu1_payload_execution_chunk_launch_rows.csv")
if len(launch_rows) != 59:
    raise SystemExit("v61bq expects 59 v61bp launch rows")
if len(chunk_rows) != 3:
    raise SystemExit("v61bq expects 3 v61bp chunk rows")

required_field_rows = [
    {
        "result_artifact": RESULT_FILE,
        "field_name": field,
        "requirement_status": "required",
        "purpose": "bind payload execution receipt back to the reviewed v61bp launch command row",
    }
    for field in REQUIRED_RESULT_FIELDS
]
write_csv(run_dir / "ubuntu1_payload_execution_receipt_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = []
for row in launch_rows[:1]:
    template_rows.append(
        {
            "result_artifact": RESULT_FILE,
            "example_row_id": "payload_execution_receipt_example",
            "example_payload": ",".join(
                [
                    row["launch_command_id"],
                    row["priority_rank"],
                    row["shard_name"],
                    row["target_path"],
                    row["expected_bytes"],
                    row["expected_bytes"],
                    "1",
                    "1",
                    "0",
                    "download-complete",
                    "sha256:" + "0" * 64,
                ]
            ),
        }
    )
template_rows.append(
    {
        "result_artifact": "acceptance_note",
        "example_row_id": "acceptance_note_example",
        "example_payload": "Receipts must describe local ubuntu-1 files; checkpoint payload bytes remain outside the repository.",
    }
)
write_csv(run_dir / "ubuntu1_payload_execution_receipt_template_rows.csv", list(template_rows[0].keys()), template_rows)

live_presence_rows = []
live_existing_rows = 0
live_size_match_rows = 0
for row in launch_rows:
    path = Path(row["target_path"])
    exists = path.is_file()
    actual_bytes = path.stat().st_size if exists else 0
    expected_bytes = int(row["expected_bytes"])
    size_match = int(exists and actual_bytes == expected_bytes)
    live_existing_rows += int(exists)
    live_size_match_rows += size_match
    live_presence_rows.append(
        {
            "live_presence_row_id": f"v61bq-live-presence-{int(row['priority_rank']):04d}",
            "launch_command_id": row["launch_command_id"],
            "priority_rank": row["priority_rank"],
            "shard_name": row["shard_name"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "actual_bytes": str(actual_bytes),
            "local_file_exists": str(int(exists)),
            "size_match": str(size_match),
            "live_presence_status": "size-match" if size_match else ("size-mismatch" if exists else "missing-local-shard"),
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_live_presence_rows.csv", list(live_presence_rows[0].keys()), live_presence_rows)

supplied_rows, supplied_fields, supplied, supplied_sha = read_supplied_results()
if supplied:
    supplied_copy = run_dir / "supplied_payload_execution_receipts" / RESULT_FILE
    supplied_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(supplied_dir / RESULT_FILE, supplied_copy)

missing_fields = [field for field in REQUIRED_RESULT_FIELDS if field not in supplied_fields]
launch_by_id = {row["launch_command_id"]: row for row in launch_rows}
live_by_id = {row["launch_command_id"]: row for row in live_presence_rows}
accepted_by_launch = {}
invalid_rows = []
seen_ids = set()
for index, row in enumerate(supplied_rows):
    reasons = []
    launch_id = row.get("launch_command_id", "")
    launch = launch_by_id.get(launch_id)
    live = live_by_id.get(launch_id)
    if not launch:
        reasons.append("unknown-launch-command-id")
    elif launch_id in seen_ids:
        reasons.append("duplicate-launch-command-id")
    else:
        for field in ["priority_rank", "shard_name", "target_path", "expected_bytes"]:
            if row.get(field, "") != launch[field]:
                reasons.append(f"{field}-mismatch")
        if row.get("download_exit_code", "") != "0":
            reasons.append("download-exit-code-not-zero")
        if row.get("download_status", "") != "download-complete":
            reasons.append("download-status-not-complete")
        if row.get("local_file_exists", "") != "1":
            reasons.append("receipt-local-file-exists-not-1")
        if row.get("size_match", "") != "1":
            reasons.append("receipt-size-match-not-1")
        if row.get("actual_bytes", "") != launch["expected_bytes"]:
            reasons.append("actual-bytes-mismatch")
        transcript = row.get("execution_transcript_sha256", "")
        if transcript and not SHA_RE.match(transcript):
            reasons.append("execution-transcript-sha256-invalid")
        if not live or live["local_file_exists"] != "1":
            reasons.append("live-local-file-missing")
        elif live["size_match"] != "1":
            reasons.append("live-size-mismatch")
    seen_ids.add(launch_id)
    if reasons:
        invalid_rows.append(
            {
                "row_index": str(index),
                "launch_command_id": launch_id,
                "shard_name": row.get("shard_name", ""),
                "status": "invalid",
                "reason": ";".join(reasons),
            }
        )
    else:
        accepted_by_launch[launch_id] = row

write_csv(
    run_dir / "ubuntu1_payload_execution_receipt_invalid_rows.csv",
    ["row_index", "launch_command_id", "shard_name", "status", "reason"],
    invalid_rows or [{"row_index": "", "launch_command_id": "", "shard_name": "", "status": "none", "reason": "no invalid supplied rows"}],
)

receipt_rows = []
for row in launch_rows:
    receipt = accepted_by_launch.get(row["launch_command_id"])
    live = live_by_id[row["launch_command_id"]]
    accepted = int(receipt is not None)
    receipt_rows.append(
        {
            "receipt_status_row_id": f"v61bq-receipt-status-{int(row['priority_rank']):04d}",
            "launch_command_id": row["launch_command_id"],
            "priority_rank": row["priority_rank"],
            "model_id": row["model_id"],
            "shard_name": row["shard_name"],
            "priority_class": row["priority_class"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "live_actual_bytes": live["actual_bytes"],
            "live_local_file_exists": live["local_file_exists"],
            "live_size_match": live["size_match"],
            "receipt_supplied": "1" if supplied else "0",
            "receipt_accepted": str(accepted),
            "receipt_status": "accepted" if accepted else "deferred-with-reason-final",
            "deferred_reason": "" if accepted else "payload-execution-receipt-not-supplied",
            "download_execution_ready": str(accepted),
            "local_checkpoint_materialization_candidate": str(accepted),
            "checkpoint_payload_bytes_downloaded_by_v61bq": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_receipt_status_rows.csv", list(receipt_rows[0].keys()), receipt_rows)

accepted_receipt_rows = len(accepted_by_launch)
invalid_receipt_rows = len([row for row in invalid_rows if row["status"] == "invalid"])
missing_receipt_rows = len(launch_rows) - accepted_receipt_rows
result_schema_ready = supplied and not missing_fields
result_artifact_ready = (
    supplied
    and result_schema_ready
    and accepted_receipt_rows == len(launch_rows)
    and invalid_receipt_rows == 0
)
payload_execution_receipt_intake_ready = int(result_artifact_ready)
download_execution_ready = int(result_artifact_ready and live_size_match_rows == len(launch_rows))

validation_rows = [
    {
        "validation_id": "payload-execution-receipt-input",
        "status": "pass" if supplied else "blocked",
        "expected_rows": str(len(launch_rows)),
        "actual_rows": str(len(supplied_rows)),
        "accepted_rows": str(accepted_receipt_rows),
        "invalid_rows": str(invalid_receipt_rows),
        "missing_rows": str(missing_receipt_rows),
        "sha256": supplied_sha,
        "reason": "supplied payload execution receipt rows validated" if supplied else "V61BQ_PAYLOAD_EXECUTION_RECEIPT_DIR not supplied",
    },
    {
        "validation_id": "payload-execution-receipt-schema",
        "status": "pass" if result_schema_ready else "blocked",
        "expected_rows": str(len(REQUIRED_RESULT_FIELDS)),
        "actual_rows": str(len(supplied_fields)),
        "accepted_rows": "1" if result_schema_ready else "0",
        "invalid_rows": "0" if not missing_fields else str(len(missing_fields)),
        "missing_rows": str(len(missing_fields)),
        "sha256": supplied_sha,
        "reason": "all required fields supplied" if result_schema_ready else ("missing supplied artifact" if not supplied else "missing fields: " + ";".join(missing_fields)),
    },
    {
        "validation_id": "live-ubuntu1-file-presence",
        "status": "pass" if live_size_match_rows == len(launch_rows) else "blocked",
        "expected_rows": str(len(launch_rows)),
        "actual_rows": str(live_existing_rows),
        "accepted_rows": str(live_size_match_rows),
        "invalid_rows": str(len(launch_rows) - live_size_match_rows),
        "missing_rows": str(len(launch_rows) - live_existing_rows),
        "sha256": "",
        "reason": f"{live_size_match_rows}/{len(launch_rows)} live ubuntu-1 shard files match expected bytes",
    },
    {
        "validation_id": "final-deferred-default",
        "status": "pass" if not supplied else "not-applicable",
        "expected_rows": str(len(launch_rows)),
        "actual_rows": "0" if not supplied else str(len(supplied_rows)),
        "accepted_rows": "0" if not supplied else str(accepted_receipt_rows),
        "invalid_rows": "0",
        "missing_rows": str(missing_receipt_rows),
        "sha256": "",
        "reason": "payload execution receipts are explicitly deferred with reason in the default path" if not supplied else "supplied receipt path active",
    },
]
write_csv(run_dir / "ubuntu1_payload_execution_receipt_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

metric = {
    "metric_id": "v61bq_ubuntu1_payload_execution_receipt_metrics",
    "model_id": model_id,
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": v61bp_summary["v61bp_ubuntu1_payload_execution_launch_bundle_ready"],
    "payload_execution_receipt_input_supplied": str(int(supplied)),
    "expected_payload_execution_receipt_rows": str(len(launch_rows)),
    "supplied_payload_execution_receipt_rows": str(len(supplied_rows)),
    "accepted_payload_execution_receipt_rows": str(accepted_receipt_rows),
    "invalid_payload_execution_receipt_rows": str(invalid_receipt_rows),
    "missing_payload_execution_receipt_rows": str(missing_receipt_rows),
    "live_existing_shard_rows": str(live_existing_rows),
    "live_size_match_shard_rows": str(live_size_match_rows),
    "result_schema_ready": str(int(result_schema_ready)),
    "result_artifact_ready": str(int(result_artifact_ready)),
    "payload_execution_receipt_intake_ready": str(payload_execution_receipt_intake_ready),
    "download_execution_ready": str(download_execution_ready),
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": v61bp_summary["total_expected_checkpoint_bytes"],
    "checkpoint_payload_bytes_downloaded_by_v61bq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_payload_execution_receipt_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61bp-launch-bundle-input", "ready", "v61bp launch rows and dry-run guard are bound"),
    ("payload-execution-receipt-schema", "ready" if result_schema_ready else "blocked", "receipt artifact schema must be supplied"),
    ("payload-execution-receipt-artifact", "ready" if result_artifact_ready else "blocked", f"{accepted_receipt_rows}/{len(launch_rows)} receipt rows accepted"),
    ("live-ubuntu1-file-presence", "ready" if live_size_match_rows == len(launch_rows) else "blocked", f"{live_size_match_rows}/{len(launch_rows)} live shard files match expected bytes"),
    ("download-execution", "ready" if download_execution_ready else "blocked", "payload receipts plus live file presence must prove execution"),
    ("local-checkpoint-materialization", "blocked", "v61t identity verification must pass after receipts"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "not an end-to-end decode latency benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bp-launch-bundle-input", "status": "pass", "reason": "v61bp launch bundle is bound"},
    {"gate": "receipt-intake-schema-template", "status": "pass", "reason": "required field rows and templates emitted"},
    {"gate": "live-presence-probe", "status": "pass", "reason": "non-invasive live file stat rows emitted"},
    {"gate": "default-no-env-deferral", "status": "pass" if not supplied else "not-applicable", "reason": "payload receipts are final-deferred unless supplied"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "receipt metadata only"},
    {"gate": "payload-execution-receipt-artifacts", "status": "pass" if result_artifact_ready else "blocked", "reason": f"accepted_payload_execution_receipt_rows={accepted_receipt_rows}/{len(launch_rows)}"},
    {"gate": "download-execution", "status": "pass" if download_execution_ready else "blocked", "reason": f"live_size_match_shard_rows={live_size_match_rows}/{len(launch_rows)}"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "requires v61t identity verification"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "requires full page-hash sweep"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real generation is still gated"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bq Ubuntu-1 Payload Execution Receipt Intake Boundary

This gate consumes v61bp launch rows and defines the receipt surface for
actual ubuntu-1 checkpoint payload execution. It also records non-invasive live
file presence/size rows for the target paths. It does not execute downloads and
does not read checkpoint payload bytes.

Evidence emitted:

- expected_payload_execution_receipt_rows={len(launch_rows)}
- supplied_payload_execution_receipt_rows={len(supplied_rows)}
- accepted_payload_execution_receipt_rows={accepted_receipt_rows}
- invalid_payload_execution_receipt_rows={invalid_receipt_rows}
- missing_payload_execution_receipt_rows={missing_receipt_rows}
- live_existing_shard_rows={live_existing_rows}
- live_size_match_shard_rows={live_size_match_rows}
- payload_execution_receipt_input_supplied={int(supplied)}
- payload_execution_receipt_intake_ready={payload_execution_receipt_intake_ready}
- download_execution_ready={download_execution_ready}
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bq=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: receipt-intake gate for an explicitly approved ubuntu-1
checkpoint payload execution run.
Blocked wording: checkpoint payload download execution in the default path,
completed full checkpoint materialization, full safetensors page-hash coverage,
actual Mixtral generation, production latency, near-frontier quality, or
release readiness.
"""
(run_dir / "V61BQ_UBUNTU1_PAYLOAD_EXECUTION_RECEIPT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bq_ubuntu1_payload_execution_receipt_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": 1,
    "source_v61bp_summary_sha256": sha256(v61bp_summary_path),
    "payload_execution_receipt_input_supplied": int(supplied),
    "expected_payload_execution_receipt_rows": len(launch_rows),
    "accepted_payload_execution_receipt_rows": accepted_receipt_rows,
    "invalid_payload_execution_receipt_rows": invalid_receipt_rows,
    "missing_payload_execution_receipt_rows": missing_receipt_rows,
    "live_existing_shard_rows": live_existing_rows,
    "live_size_match_shard_rows": live_size_match_rows,
    "payload_execution_receipt_intake_ready": payload_execution_receipt_intake_ready,
    "download_execution_ready": download_execution_ready,
    "local_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61bq_ubuntu1_payload_execution_receipt_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bq_ubuntu1_payload_execution_receipt_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
