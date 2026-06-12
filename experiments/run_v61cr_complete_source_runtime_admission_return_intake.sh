#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cr_complete_source_runtime_admission_return_intake"
RUN_ID="${V61CR_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
DEFAULT_RESULT_DIR="$RESULTS_DIR/v61cq_complete_source_runtime_admission_expansion_packet/packet_001/runtime_admission_return_results"
SUPPLIED_DIR="${V61CR_RUNTIME_ADMISSION_RETURN_DIR:-}"

if [[ -z "$SUPPLIED_DIR" && -f "$DEFAULT_RESULT_DIR/complete_source_runtime_admission_result_rows.csv" ]]; then
  SUPPLIED_DIR="$DEFAULT_RESULT_DIR"
fi

if [[ "${V61CR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cr_complete_source_runtime_admission_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cq_complete_source_runtime_admission_expansion_packet.sh" >/dev/null

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
v61cq_dir = results / "v61cq_complete_source_runtime_admission_expansion_packet" / "packet_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")

ARTIFACT_FIELDS = {
    "complete_source_runtime_admission_result_rows.csv": [
        "expansion_row_id",
        "query_id",
        "review_query_packet_id",
        "generation_execution_packet_id",
        "model_id",
        "checkpoint_root",
        "runtime_execution_admitted",
        "runtime_admission_status",
        "runtime_admission_transcript_sha256",
    ],
    "complete_source_runtime_page_binding_rows.csv": [
        "query_id",
        "model_id",
        "bound_page_count",
        "bound_page_manifest_sha256",
        "page_binding_verified",
    ],
    "complete_source_runtime_budget_rows.csv": [
        "query_id",
        "prompt_tokens",
        "expected_decode_tokens",
        "ssd_read_bytes",
        "kv_cache_bytes",
        "runtime_budget_verified",
    ],
    "complete_source_runtime_identity_rows.csv": [
        "shard_name",
        "local_file_exists",
        "size_match",
        "local_header_hash_match",
        "local_identity_verified",
        "identity_verification_transcript_sha256",
    ],
    "complete_source_runtime_abstain_fallback_rows.csv": [
        "query_id",
        "expected_behavior",
        "citation_policy_ready",
        "abstain_policy_ready",
        "fallback_policy_ready",
        "runtime_safety_verified",
    ],
}
ARTIFACT_EXPECTED_ROWS = {
    "complete_source_runtime_identity_rows.csv": 59,
}


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


def read_supplied_artifact(name):
    if supplied_dir is None:
        return [], [], False, ""
    path = supplied_dir / name
    if not path.is_file():
        return [], [], False, ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []
    return rows, fields, True, sha256(path)


def is_positive_int(value):
    try:
        return int(value) >= 0
    except (TypeError, ValueError):
        return False


v61cq_summary_path = results / "v61cq_complete_source_runtime_admission_expansion_packet_summary.csv"
v61cq_decision_path = results / "v61cq_complete_source_runtime_admission_expansion_packet_decision.csv"
v61cq_summary = read_csv(v61cq_summary_path)[0]
if v61cq_summary.get("v61cq_complete_source_runtime_admission_expansion_packet_ready") != "1":
    raise SystemExit("v61cr requires v61cq_complete_source_runtime_admission_expansion_packet_ready=1")

for src, rel in [
    (v61cq_summary_path, "source_v61cq/v61cq_complete_source_runtime_admission_expansion_packet_summary.csv"),
    (v61cq_decision_path, "source_v61cq/v61cq_complete_source_runtime_admission_expansion_packet_decision.csv"),
    (v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv", "source_v61cq/complete_source_runtime_admission_expansion_rows.csv"),
    (v61cq_dir / "complete_source_runtime_admission_operator_command_rows.csv", "source_v61cq/complete_source_runtime_admission_operator_command_rows.csv"),
    (v61cq_dir / "complete_source_runtime_admission_return_manifest_rows.csv", "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv"),
    (v61cq_dir / "complete_source_runtime_admission_expansion_metric_rows.csv", "source_v61cq/complete_source_runtime_admission_expansion_metric_rows.csv"),
    (v61cq_dir / "runtime_gap_rows.csv", "source_v61cq/runtime_gap_rows.csv"),
    (v61cq_dir / "sha256_manifest.csv", "source_v61cq/sha256_manifest.csv"),
]:
    copy(src, rel)

expansion_rows = read_csv(v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv")
return_manifest_rows = read_csv(v61cq_dir / "complete_source_runtime_admission_return_manifest_rows.csv")
query_ids = {row["query_id"] for row in expansion_rows}
expansion_by_id = {row["expansion_row_id"]: row for row in expansion_rows}
expected_query_rows = len(expansion_rows)

required_field_rows = []
for artifact, fields in ARTIFACT_FIELDS.items():
    for field in fields:
        required_field_rows.append(
            {
                "result_artifact": artifact,
                "field_name": field,
                "requirement_status": "required",
                "purpose": "validate complete-source runtime admission execution return intake",
            }
        )
write_csv(run_dir / "complete_source_runtime_admission_return_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": artifact,
        "example_payload": ",".join(fields),
    }
    for artifact, fields in ARTIFACT_FIELDS.items()
]
write_csv(run_dir / "complete_source_runtime_admission_return_template_rows.csv", list(template_rows[0].keys()), template_rows)

artifact_status_rows = []
invalid_rows = []
accepted_artifacts = 0
supplied_artifacts = 0
accepted_runtime_admission_result_rows = 0
invalid_runtime_admission_result_rows = 0
accepted_page_binding_rows = 0
accepted_budget_rows = 0
accepted_identity_rows = 0
accepted_abstain_fallback_rows = 0

for artifact, required_fields in ARTIFACT_FIELDS.items():
    expected_rows = ARTIFACT_EXPECTED_ROWS.get(artifact, expected_query_rows)
    rows, fields, supplied, digest = read_supplied_artifact(artifact)
    if supplied:
        supplied_artifacts += 1
        supplied_copy = run_dir / "supplied_complete_source_runtime_admission_returns" / artifact
        supplied_copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(supplied_dir / artifact, supplied_copy)
    missing_fields = [field for field in required_fields if field not in fields]
    reasons = []
    if not supplied:
        reasons.append("result-artifact-not-supplied")
    if missing_fields:
        reasons.append("missing-fields:" + ";".join(missing_fields))
    if supplied and len(rows) != expected_rows:
        reasons.append(f"row-count-mismatch:{len(rows)}/{expected_rows}")

    row_invalid_count = 0
    seen = set()
    for index, row in enumerate(rows):
        row_reasons = []
        if artifact == "complete_source_runtime_admission_result_rows.csv":
            expansion = expansion_by_id.get(row.get("expansion_row_id", ""))
            if expansion is None:
                row_reasons.append("unknown-expansion-row-id")
            else:
                for field in ["query_id", "review_query_packet_id", "generation_execution_packet_id", "model_id", "checkpoint_root"]:
                    if row.get(field, "") != expansion[field]:
                        row_reasons.append(f"{field}-mismatch")
            if row.get("runtime_execution_admitted", "") != "1":
                row_reasons.append("runtime-execution-not-admitted")
            if row.get("runtime_admission_status", "") != "admitted":
                row_reasons.append("runtime-admission-status-not-admitted")
            if not SHA_RE.match(row.get("runtime_admission_transcript_sha256", "")):
                row_reasons.append("runtime-admission-transcript-sha256-invalid")
            key = row.get("expansion_row_id", "")
        elif artifact == "complete_source_runtime_page_binding_rows.csv":
            if row.get("query_id", "") not in query_ids:
                row_reasons.append("unknown-query-id")
            if row.get("model_id", "") != model_id:
                row_reasons.append("model-id-mismatch")
            if not is_positive_int(row.get("bound_page_count", "")) or int(row.get("bound_page_count", "0")) <= 0:
                row_reasons.append("bound-page-count-not-positive")
            if not SHA_RE.match(row.get("bound_page_manifest_sha256", "")):
                row_reasons.append("bound-page-manifest-sha256-invalid")
            if row.get("page_binding_verified", "") != "1":
                row_reasons.append("page-binding-not-verified")
            key = row.get("query_id", "")
        elif artifact == "complete_source_runtime_budget_rows.csv":
            if row.get("query_id", "") not in query_ids:
                row_reasons.append("unknown-query-id")
            for field in ["prompt_tokens", "expected_decode_tokens", "ssd_read_bytes", "kv_cache_bytes"]:
                if not is_positive_int(row.get(field, "")):
                    row_reasons.append(f"{field}-not-nonnegative-int")
            if row.get("runtime_budget_verified", "") != "1":
                row_reasons.append("runtime-budget-not-verified")
            key = row.get("query_id", "")
        elif artifact == "complete_source_runtime_identity_rows.csv":
            for field in ["local_file_exists", "size_match", "local_header_hash_match", "local_identity_verified"]:
                if row.get(field, "") != "1":
                    row_reasons.append(f"{field}-not-verified")
            if not SHA_RE.match(row.get("identity_verification_transcript_sha256", "")):
                row_reasons.append("identity-verification-transcript-sha256-invalid")
            key = row.get("shard_name", "")
        else:
            if row.get("query_id", "") not in query_ids:
                row_reasons.append("unknown-query-id")
            for field in ["citation_policy_ready", "abstain_policy_ready", "fallback_policy_ready", "runtime_safety_verified"]:
                if row.get(field, "") != "1":
                    row_reasons.append(f"{field}-not-ready")
            key = row.get("query_id", "")
        if key in seen:
            row_reasons.append("duplicate-row-key")
        seen.add(key)
        if row_reasons:
            row_invalid_count += 1
            invalid_rows.append(
                {
                    "result_artifact": artifact,
                    "row_index": str(index),
                    "row_key": key,
                    "status": "invalid",
                    "reason": ";".join(row_reasons),
                }
            )
    if row_invalid_count:
        reasons.append(f"invalid-row-count:{row_invalid_count}")
    accepted = int(supplied and not reasons)
    if accepted:
        accepted_artifacts += 1
        if artifact == "complete_source_runtime_admission_result_rows.csv":
            accepted_runtime_admission_result_rows = len(rows)
        elif artifact == "complete_source_runtime_page_binding_rows.csv":
            accepted_page_binding_rows = len(rows)
        elif artifact == "complete_source_runtime_budget_rows.csv":
            accepted_budget_rows = len(rows)
        elif artifact == "complete_source_runtime_identity_rows.csv":
            accepted_identity_rows = len(rows)
        else:
            accepted_abstain_fallback_rows = len(rows)
    artifact_status_rows.append(
        {
            "result_artifact": artifact,
            "required_rows": str(expected_rows),
            "supplied": "1" if supplied else "0",
            "supplied_rows": str(len(rows)),
            "accepted": str(accepted),
            "accepted_rows": str(len(rows) if accepted else 0),
            "artifact_sha256": digest,
            "status": "accepted" if accepted else "missing" if not supplied else "invalid",
            "reason": "accepted" if accepted else ";".join(reasons),
        }
    )

write_csv(run_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)
write_csv(
    run_dir / "complete_source_runtime_admission_return_invalid_rows.csv",
    ["result_artifact", "row_index", "row_key", "status", "reason"],
    invalid_rows
    or [
        {
            "result_artifact": "",
            "row_index": "",
            "row_key": "",
            "status": "none",
            "reason": "no invalid supplied rows",
        }
    ],
)

expected_runtime_admission_return_artifacts = len(ARTIFACT_FIELDS)
missing_runtime_admission_return_artifacts = expected_runtime_admission_return_artifacts - accepted_artifacts
missing_runtime_admission_result_rows = max(expected_query_rows - accepted_runtime_admission_result_rows, 0)
missing_page_binding_rows = max(expected_query_rows - accepted_page_binding_rows, 0)
missing_budget_rows = max(expected_query_rows - accepted_budget_rows, 0)
missing_identity_rows = max(59 - accepted_identity_rows, 0)
missing_abstain_fallback_rows = max(expected_query_rows - accepted_abstain_fallback_rows, 0)
runtime_admission_return_artifact_ready = int(accepted_artifacts == expected_runtime_admission_return_artifacts)
runtime_admission_result_rows_ready = int(accepted_runtime_admission_result_rows == expected_query_rows)
runtime_page_binding_ready = int(accepted_page_binding_rows == expected_query_rows)
runtime_budget_ready = int(accepted_budget_rows == expected_query_rows)
runtime_identity_ready = int(accepted_identity_rows == 59)
runtime_safety_ready = int(accepted_abstain_fallback_rows == expected_query_rows)
runtime_admission_execution_ready = int(
    runtime_admission_return_artifact_ready
    and runtime_admission_result_rows_ready
    and runtime_page_binding_ready
    and runtime_budget_ready
    and runtime_identity_ready
    and runtime_safety_ready
)

requirement_rows = [
    {"requirement_id": "v61cq-runtime-admission-expansion-packet-input", "status": "pass", "required_value": "1", "actual_value": v61cq_summary["v61cq_complete_source_runtime_admission_expansion_packet_ready"], "reason": "v61cq expansion packet is bound"},
    {"requirement_id": "runtime-admission-return-artifacts", "status": "pass" if runtime_admission_return_artifact_ready else "blocked", "required_value": str(expected_runtime_admission_return_artifacts), "actual_value": str(accepted_artifacts), "reason": "all five runtime admission return artifacts must validate"},
    {"requirement_id": "runtime-admission-result-rows", "status": "pass" if runtime_admission_result_rows_ready else "blocked", "required_value": str(expected_query_rows), "actual_value": str(accepted_runtime_admission_result_rows), "reason": "all complete-source runtime admission result rows must be admitted"},
    {"requirement_id": "runtime-page-binding-rows", "status": "pass" if runtime_page_binding_ready else "blocked", "required_value": str(expected_query_rows), "actual_value": str(accepted_page_binding_rows), "reason": "all complete-source rows need verified runtime page binding"},
    {"requirement_id": "runtime-budget-rows", "status": "pass" if runtime_budget_ready else "blocked", "required_value": str(expected_query_rows), "actual_value": str(accepted_budget_rows), "reason": "all complete-source rows need runtime budget evidence"},
    {"requirement_id": "runtime-identity-rows", "status": "pass" if runtime_identity_ready else "blocked", "required_value": "59", "actual_value": str(accepted_identity_rows), "reason": "all checkpoint shards need identity verification return rows"},
    {"requirement_id": "runtime-safety-rows", "status": "pass" if runtime_safety_ready else "blocked", "required_value": str(expected_query_rows), "actual_value": str(accepted_abstain_fallback_rows), "reason": "citation/abstain/fallback safety rows are required"},
    {"requirement_id": "complete-source-runtime-admission-execution", "status": "pass" if runtime_admission_execution_ready else "blocked", "required_value": str(expected_query_rows), "actual_value": str(accepted_runtime_admission_result_rows), "reason": "runtime execution admission remains blocked until all return evidence validates"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cr writes metadata and return intake rows only"},
]
write_csv(run_dir / "complete_source_runtime_admission_return_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cr_complete_source_runtime_admission_return_intake_metrics",
    "model_id": model_id,
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": v61cq_summary["v61cq_complete_source_runtime_admission_expansion_packet_ready"],
    "complete_source_query_rows": str(expected_query_rows),
    "runtime_admission_expansion_packet_rows": v61cq_summary["runtime_admission_expansion_packet_rows"],
    "runtime_admission_expansion_required_rows": v61cq_summary["runtime_admission_expansion_required_rows"],
    "expected_runtime_admission_return_artifacts": str(expected_runtime_admission_return_artifacts),
    "supplied_runtime_admission_return_artifacts": str(supplied_artifacts),
    "accepted_runtime_admission_return_artifacts": str(accepted_artifacts),
    "missing_runtime_admission_return_artifacts": str(missing_runtime_admission_return_artifacts),
    "expected_runtime_admission_result_rows": str(expected_query_rows),
    "accepted_runtime_admission_result_rows": str(accepted_runtime_admission_result_rows),
    "invalid_runtime_admission_result_rows": str(invalid_runtime_admission_result_rows),
    "missing_runtime_admission_result_rows": str(missing_runtime_admission_result_rows),
    "accepted_runtime_page_binding_rows": str(accepted_page_binding_rows),
    "missing_runtime_page_binding_rows": str(missing_page_binding_rows),
    "accepted_runtime_budget_rows": str(accepted_budget_rows),
    "missing_runtime_budget_rows": str(missing_budget_rows),
    "accepted_runtime_identity_rows": str(accepted_identity_rows),
    "missing_runtime_identity_rows": str(missing_identity_rows),
    "accepted_runtime_abstain_fallback_rows": str(accepted_abstain_fallback_rows),
    "missing_runtime_abstain_fallback_rows": str(missing_abstain_fallback_rows),
    "runtime_admission_return_artifact_ready": str(runtime_admission_return_artifact_ready),
    "runtime_admission_result_rows_ready": str(runtime_admission_result_rows_ready),
    "runtime_page_binding_ready": str(runtime_page_binding_ready),
    "runtime_budget_ready": str(runtime_budget_ready),
    "runtime_identity_ready": str(runtime_identity_ready),
    "runtime_safety_ready": str(runtime_safety_ready),
    "complete_source_runtime_admission_execution_ready": str(runtime_admission_execution_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cr": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_runtime_admission_return_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cr_complete_source_runtime_admission_return_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61cq-runtime-admission-expansion-packet-input", "status": "ready", "reason": "v61cq expansion packet is bound"},
    {"gap": "runtime-admission-return-artifacts", "status": "ready" if runtime_admission_return_artifact_ready else "blocked", "reason": f"accepted_runtime_admission_return_artifacts={accepted_artifacts}/{expected_runtime_admission_return_artifacts}"},
    {"gap": "runtime-admission-result-rows", "status": "ready" if runtime_admission_result_rows_ready else "blocked", "reason": f"accepted_runtime_admission_result_rows={accepted_runtime_admission_result_rows}/{expected_query_rows}"},
    {"gap": "complete-source-runtime-admission-execution", "status": "ready" if runtime_admission_execution_ready else "blocked", "reason": f"complete_source_runtime_admission_execution_ready={runtime_admission_execution_ready}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "complete-source runtime admission execution is not ready"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61cq-runtime-admission-expansion-packet-input", "status": "pass", "reason": "v61cq expansion packet is ready"},
    {"gate": "runtime-admission-return-artifacts", "status": "pass" if runtime_admission_return_artifact_ready else "blocked", "reason": f"accepted_runtime_admission_return_artifacts={accepted_artifacts}/{expected_runtime_admission_return_artifacts}"},
    {"gate": "runtime-admission-result-rows", "status": "pass" if runtime_admission_result_rows_ready else "blocked", "reason": f"accepted_runtime_admission_result_rows={accepted_runtime_admission_result_rows}/{expected_query_rows}"},
    {"gate": "runtime-page-binding-rows", "status": "pass" if runtime_page_binding_ready else "blocked", "reason": f"accepted_runtime_page_binding_rows={accepted_page_binding_rows}/{expected_query_rows}"},
    {"gate": "runtime-budget-rows", "status": "pass" if runtime_budget_ready else "blocked", "reason": f"accepted_runtime_budget_rows={accepted_budget_rows}/{expected_query_rows}"},
    {"gate": "runtime-identity-rows", "status": "pass" if runtime_identity_ready else "blocked", "reason": f"accepted_runtime_identity_rows={accepted_identity_rows}/59"},
    {"gate": "runtime-safety-rows", "status": "pass" if runtime_safety_ready else "blocked", "reason": f"accepted_runtime_abstain_fallback_rows={accepted_abstain_fallback_rows}/{expected_query_rows}"},
    {"gate": "complete-source-runtime-admission-execution", "status": "pass" if runtime_admission_execution_ready else "blocked", "reason": f"complete_source_runtime_admission_execution_ready={runtime_admission_execution_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cr writes metadata and return intake rows only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cr Complete-Source Runtime Admission Return Intake Boundary

This artifact defines and validates the return side of the v61cq complete-source
runtime admission expansion packet. It does not claim runtime execution by
default; it keeps all runtime admission returns missing until supplied evidence
validates against the 1000-row expansion packet and 59-shard identity surface.

Evidence emitted:

- complete_source_query_rows={expected_query_rows}
- runtime_admission_expansion_packet_rows={v61cq_summary["runtime_admission_expansion_packet_rows"]}
- expected_runtime_admission_return_artifacts={expected_runtime_admission_return_artifacts}
- supplied_runtime_admission_return_artifacts={supplied_artifacts}
- accepted_runtime_admission_return_artifacts={accepted_artifacts}
- missing_runtime_admission_return_artifacts={missing_runtime_admission_return_artifacts}
- expected_runtime_admission_result_rows={expected_query_rows}
- accepted_runtime_admission_result_rows={accepted_runtime_admission_result_rows}
- missing_runtime_admission_result_rows={missing_runtime_admission_result_rows}
- accepted_runtime_page_binding_rows={accepted_page_binding_rows}
- accepted_runtime_budget_rows={accepted_budget_rows}
- accepted_runtime_identity_rows={accepted_identity_rows}
- accepted_runtime_abstain_fallback_rows={accepted_abstain_fallback_rows}
- runtime_admission_return_artifact_ready={runtime_admission_return_artifact_ready}
- complete_source_runtime_admission_execution_ready={runtime_admission_execution_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cr=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source runtime admission return intake over the
v61cq expansion packet. Blocked wording: completed runtime admission execution,
actual Mixtral generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61CR_COMPLETE_SOURCE_RUNTIME_ADMISSION_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cr_complete_source_runtime_admission_return_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cr_complete_source_runtime_admission_return_intake_ready": 1,
    "v61cq_summary_sha256": sha256(v61cq_summary_path),
    "complete_source_query_rows": expected_query_rows,
    "accepted_runtime_admission_return_artifacts": accepted_artifacts,
    "accepted_runtime_admission_result_rows": accepted_runtime_admission_result_rows,
    "complete_source_runtime_admission_execution_ready": runtime_admission_execution_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cr": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cr_complete_source_runtime_admission_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cr_complete_source_runtime_admission_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
