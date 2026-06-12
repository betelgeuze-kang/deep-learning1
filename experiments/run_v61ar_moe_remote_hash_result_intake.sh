#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ar_moe_remote_hash_result_intake"
RUN_ID="${V61AR_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V61AR_REMOTE_HASH_RESULT_DIR:-}"

if [[ "${V61AR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ar_moe_remote_hash_result_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61aq_moe_remote_hash_execution_gate.sh" >/dev/null

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
supplied_arg = sys.argv[5]
results = root / "results"
v61aq_dir = results / "v61aq_moe_remote_hash_execution_gate" / "gate_001"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
model_id = "mistralai/Mixtral-8x22B-v0.1"

RESULT_FILE = "moe_remote_hash_result_rows.csv"
REQUIRED_RESULT_FIELDS = [
    "remote_hash_command_id",
    "remote_hash_plan_id",
    "source_page_id",
    "shard_name",
    "page_start_byte",
    "page_end_byte_exclusive",
    "planned_range_bytes",
    "remote_page_sha256",
    "execution_transcript_sha256",
    "execution_status",
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


v61aq_summary = read_csv(results / "v61aq_moe_remote_hash_execution_gate_summary.csv")[0]
if v61aq_summary.get("v61aq_moe_remote_hash_execution_gate_ready") != "1":
    raise SystemExit("v61ar requires v61aq_moe_remote_hash_execution_gate_ready=1")

for src, rel in [
    (results / "v61aq_moe_remote_hash_execution_gate_summary.csv", "source_v61aq/v61aq_moe_remote_hash_execution_gate_summary.csv"),
    (results / "v61aq_moe_remote_hash_execution_gate_decision.csv", "source_v61aq/v61aq_moe_remote_hash_execution_gate_decision.csv"),
    (v61aq_dir / "moe_remote_hash_execution_command_rows.csv", "source_v61aq/moe_remote_hash_execution_command_rows.csv"),
    (v61aq_dir / "moe_remote_hash_existing_hash_rows.csv", "source_v61aq/moe_remote_hash_existing_hash_rows.csv"),
    (v61aq_dir / "moe_remote_hash_execution_chunk_rows.csv", "source_v61aq/moe_remote_hash_execution_chunk_rows.csv"),
    (v61aq_dir / "moe_remote_hash_execution_requirement_rows.csv", "source_v61aq/moe_remote_hash_execution_requirement_rows.csv"),
    (v61aq_dir / "moe_remote_hash_execution_metric_rows.csv", "source_v61aq/moe_remote_hash_execution_metric_rows.csv"),
    (v61aq_dir / "V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md", "source_v61aq/V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md"),
    (v61aq_dir / "v61aq_moe_remote_hash_execution_gate_manifest.json", "source_v61aq/v61aq_moe_remote_hash_execution_gate_manifest.json"),
    (v61aq_dir / "sha256_manifest.csv", "source_v61aq/sha256_manifest.csv"),
]:
    copy(src, rel)

command_rows = read_csv(v61aq_dir / "moe_remote_hash_execution_command_rows.csv")
existing_rows = read_csv(v61aq_dir / "moe_remote_hash_existing_hash_rows.csv")
chunk_rows = read_csv(v61aq_dir / "moe_remote_hash_execution_chunk_rows.csv")
expected_result_rows = len(command_rows)
required_total_hash_rows = expected_result_rows + len(existing_rows)

required_field_rows = [
    {
        "result_artifact": RESULT_FILE,
        "field_name": field,
        "requirement_status": "required",
        "purpose": "bind executed remote range hash result back to the reviewed v61aq command row",
    }
    for field in REQUIRED_RESULT_FIELDS
]
write_csv(run_dir / "moe_remote_hash_result_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": RESULT_FILE,
        "example_row_id": "remote_hash_result_example",
        "example_payload": ",".join(REQUIRED_RESULT_FIELDS),
    },
    {
        "result_artifact": "acceptance_note",
        "example_row_id": "acceptance_note_example",
        "example_payload": "All rows must be hash-only metadata; checkpoint payload bytes remain outside the repository.",
    },
]
write_csv(run_dir / "moe_remote_hash_result_template_rows.csv", list(template_rows[0].keys()), template_rows)

supplied_rows, supplied_fields, supplied, supplied_sha = read_supplied_results()
if supplied:
    supplied_copy = run_dir / "supplied_remote_hash_results" / RESULT_FILE
    supplied_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(supplied_dir / RESULT_FILE, supplied_copy)

missing_fields = [field for field in REQUIRED_RESULT_FIELDS if field not in supplied_fields]
command_by_id = {row["remote_hash_command_id"]: row for row in command_rows}
accepted_by_plan = {}
invalid_rows = []
duplicate_command_ids = set()
seen_command_ids = set()

for index, row in enumerate(supplied_rows):
    reasons = []
    command_id = row.get("remote_hash_command_id", "")
    command = command_by_id.get(command_id)
    if not command:
        reasons.append("unknown-command-id")
    elif command_id in seen_command_ids:
        duplicate_command_ids.add(command_id)
        reasons.append("duplicate-command-id")
    else:
        for field in [
            "remote_hash_plan_id",
            "source_page_id",
            "shard_name",
            "page_start_byte",
            "page_end_byte_exclusive",
            "planned_range_bytes",
        ]:
            if row.get(field, "") != command[field]:
                reasons.append(f"{field}-mismatch")
        if row.get("execution_status", "") != "hash-verified":
            reasons.append("execution-status-not-hash-verified")
        if not SHA_RE.match(row.get("remote_page_sha256", "")):
            reasons.append("remote-page-sha256-invalid")
        transcript_hash = row.get("execution_transcript_sha256", "")
        if transcript_hash and not SHA_RE.match(transcript_hash):
            reasons.append("execution-transcript-sha256-invalid")
    seen_command_ids.add(command_id)
    if reasons:
        invalid_rows.append(
            {
                "row_index": str(index),
                "remote_hash_command_id": command_id,
                "remote_hash_plan_id": row.get("remote_hash_plan_id", ""),
                "status": "invalid",
                "reason": ";".join(reasons),
            }
        )
    else:
        accepted_by_plan[row["remote_hash_plan_id"]] = row

write_csv(
    run_dir / "moe_remote_hash_result_invalid_rows.csv",
    ["row_index", "remote_hash_command_id", "remote_hash_plan_id", "status", "reason"],
    invalid_rows or [{"row_index": "", "remote_hash_command_id": "", "remote_hash_plan_id": "", "status": "none", "reason": "no invalid supplied rows"}],
)

coverage_rows = []
coverage_index = 0
for row in existing_rows:
    coverage_rows.append(
        {
            "coverage_row_id": f"v61ar_moe_hash_coverage_{coverage_index:04d}",
            "remote_hash_plan_id": row["remote_hash_plan_id"],
            "model_id": model_id,
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "tensor_role": row["tensor_role"],
            "source_page_id": row["source_page_id"],
            "shard_name": row["shard_name"],
            "coverage_source": "existing-v61v-remote-hash",
            "remote_page_sha256": row["remote_page_sha256"],
            "remote_hash_verified": "1",
            "result_status": "already-remote-hash-bound",
            "checkpoint_payload_bytes_downloaded_by_v61ar": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
    coverage_index += 1

for command in command_rows:
    result = accepted_by_plan.get(command["remote_hash_plan_id"])
    coverage_rows.append(
        {
            "coverage_row_id": f"v61ar_moe_hash_coverage_{coverage_index:04d}",
            "remote_hash_plan_id": command["remote_hash_plan_id"],
            "model_id": model_id,
            "layer_index": command["layer_index"],
            "expert_index": command["expert_index"],
            "tensor_role": command["tensor_role"],
            "source_page_id": command["source_page_id"],
            "shard_name": command["shard_name"],
            "coverage_source": "supplied-v61ar-remote-hash-result" if result else "missing-supplied-result",
            "remote_page_sha256": result["remote_page_sha256"] if result else "",
            "remote_hash_verified": "1" if result else "0",
            "result_status": "hash-verified" if result else "deferred-with-reason-final",
            "checkpoint_payload_bytes_downloaded_by_v61ar": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
    coverage_index += 1
write_csv(run_dir / "moe_remote_hash_combined_coverage_rows.csv", list(coverage_rows[0].keys()), coverage_rows)

accepted_result_rows = len(accepted_by_plan)
invalid_result_rows = len([row for row in invalid_rows if row["status"] == "invalid"])
missing_result_rows = expected_result_rows - accepted_result_rows
verified_remote_hash_rows = len(existing_rows) + accepted_result_rows
result_schema_ready = supplied and not missing_fields
result_artifact_ready = (
    supplied
    and result_schema_ready
    and accepted_result_rows == expected_result_rows
    and invalid_result_rows == 0
)
full_moe_coverage_remote_hash_ready = int(verified_remote_hash_rows == required_total_hash_rows)

validation_rows = [
    {
        "validation_id": "remote-hash-result-input",
        "status": "pass" if supplied else "blocked",
        "expected_rows": str(expected_result_rows),
        "actual_rows": str(len(supplied_rows)),
        "accepted_rows": str(accepted_result_rows),
        "invalid_rows": str(invalid_result_rows),
        "missing_rows": str(missing_result_rows),
        "sha256": supplied_sha,
        "reason": "supplied remote hash result rows validated" if supplied else "V61AR_REMOTE_HASH_RESULT_DIR not supplied",
    },
    {
        "validation_id": "remote-hash-result-schema",
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
        "validation_id": "final-deferred-default",
        "status": "pass" if not supplied else "not-applicable",
        "expected_rows": str(expected_result_rows),
        "actual_rows": "0" if not supplied else str(len(supplied_rows)),
        "accepted_rows": "0" if not supplied else str(accepted_result_rows),
        "invalid_rows": "0",
        "missing_rows": str(missing_result_rows),
        "sha256": "",
        "reason": "new remote hash results are explicitly deferred with reason in the default path" if not supplied else "supplied result path active",
    },
]
write_csv(run_dir / "moe_remote_hash_result_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

metric = {
    "metric_id": "v61ar_moe_remote_hash_result_intake_metrics",
    "model_id": model_id,
    "v61aq_moe_remote_hash_execution_gate_ready": v61aq_summary["v61aq_moe_remote_hash_execution_gate_ready"],
    "remote_hash_result_input_supplied": str(int(supplied)),
    "expected_remote_hash_result_rows": str(expected_result_rows),
    "supplied_remote_hash_result_rows": str(len(supplied_rows)),
    "accepted_remote_hash_result_rows": str(accepted_result_rows),
    "invalid_remote_hash_result_rows": str(invalid_result_rows),
    "missing_remote_hash_result_rows": str(missing_result_rows),
    "existing_remote_hash_rows": str(len(existing_rows)),
    "required_moe_remote_hash_rows": str(required_total_hash_rows),
    "verified_remote_hash_rows": str(verified_remote_hash_rows),
    "result_schema_ready": str(int(result_schema_ready)),
    "result_artifact_ready": str(int(result_artifact_ready)),
    "remote_hash_result_intake_ready": str(int(result_artifact_ready)),
    "full_moe_coverage_remote_hash_ready": str(full_moe_coverage_remote_hash_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ar": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "moe_remote_hash_result_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61aq-execution-gate-input", "ready", "v61aq command and chunk plan is bound"),
    ("remote-hash-result-schema", "ready" if result_schema_ready else "blocked", "hash-only result artifact schema must be supplied"),
    ("remote-hash-result-artifact", "ready" if result_artifact_ready else "blocked", f"{accepted_result_rows}/{expected_result_rows} new remote hash result rows accepted"),
    ("existing-remote-hash-preservation", "ready", f"{len(existing_rows)} existing v61v hashes are preserved"),
    ("full-moe-coverage-remote-hash", "ready" if full_moe_coverage_remote_hash_ready else "blocked", f"{verified_remote_hash_rows}/{required_total_hash_rows} representative cells are remotely hash-bound"),
    ("full-safetensors-page-hash-binding", "blocked", "MoE representative coverage is not all checkpoint pages"),
    ("real-model-generation", "blocked", "real Mixtral generation waits for materialization, page-hash, and review gates"),
    ("production-latency", "blocked", "not an end-to-end decode latency benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61ar_moe_remote_hash_result_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61aq-execution-gate-input", "status": "pass", "reason": "v61aq command plan is bound"},
    {"gate": "result-intake-schema-template", "status": "pass", "reason": "required field rows and templates emitted"},
    {"gate": "existing-remote-hash-preservation", "status": "pass", "reason": f"existing_remote_hash_rows={len(existing_rows)}"},
    {"gate": "default-no-env-deferral", "status": "pass" if not supplied else "not-applicable", "reason": "new remote hash result rows are final-deferred unless supplied"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "hash metadata only"},
    {"gate": "remote-hash-result-artifacts", "status": "pass" if result_artifact_ready else "blocked", "reason": f"accepted_remote_hash_result_rows={accepted_result_rows}/{expected_result_rows}"},
    {"gate": "full-moe-coverage-remote-hash", "status": "pass" if full_moe_coverage_remote_hash_ready else "blocked", "reason": f"verified_remote_hash_rows={verified_remote_hash_rows}/{required_total_hash_rows}"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "requires all checkpoint pages"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real generation is still gated"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ar MoE Remote Hash Result Intake Boundary

This artifact closes the post-v61aq handoff: reviewed remote hash commands can
now be returned as hash-only metadata, or explicitly deferred in the default
path. It does not execute network range hashing and does not store checkpoint
payload bytes in the repository.

Evidence emitted:

- expected_remote_hash_result_rows={expected_result_rows}
- supplied_remote_hash_result_rows={len(supplied_rows)}
- accepted_remote_hash_result_rows={accepted_result_rows}
- invalid_remote_hash_result_rows={invalid_result_rows}
- missing_remote_hash_result_rows={missing_result_rows}
- existing_remote_hash_rows={len(existing_rows)}
- required_moe_remote_hash_rows={required_total_hash_rows}
- verified_remote_hash_rows={verified_remote_hash_rows}
- remote_hash_result_input_supplied={int(supplied)}
- remote_hash_result_intake_ready={int(result_artifact_ready)}
- full_moe_coverage_remote_hash_ready={full_moe_coverage_remote_hash_ready}
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ar=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: hash-only result intake gate for the v61aq MoE remote hash
command plan.
Blocked wording: executed remote hash expansion in the default path, full MoE
remote hash coverage without supplied accepted rows, full safetensors page-hash
coverage, local materialization, real Mixtral generation, production latency,
or release readiness.
"""
(run_dir / "V61AR_MOE_REMOTE_HASH_RESULT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ar_moe_remote_hash_result_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ar_moe_remote_hash_result_intake_ready": 1,
    "source_v61aq_summary_sha256": sha256(results / "v61aq_moe_remote_hash_execution_gate_summary.csv"),
    "remote_hash_result_input_supplied": int(supplied),
    "expected_remote_hash_result_rows": expected_result_rows,
    "accepted_remote_hash_result_rows": accepted_result_rows,
    "invalid_remote_hash_result_rows": invalid_result_rows,
    "missing_remote_hash_result_rows": missing_result_rows,
    "existing_remote_hash_rows": len(existing_rows),
    "required_moe_remote_hash_rows": required_total_hash_rows,
    "verified_remote_hash_rows": verified_remote_hash_rows,
    "remote_hash_result_intake_ready": int(result_artifact_ready),
    "full_moe_coverage_remote_hash_ready": full_moe_coverage_remote_hash_ready,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ar": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ar_moe_remote_hash_result_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ar_moe_remote_hash_result_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
