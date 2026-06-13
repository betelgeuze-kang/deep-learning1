#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bt_ubuntu1_actual_generation_result_intake"
RUN_ID="${V61BT_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V61BT_GENERATION_RESULT_DIR:-}"
PREREQUISITE_BINDING_DIR="${V61BT_PREREQUISITE_BINDING_DIR:-}"

if [[ "${V61BT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bt_ubuntu1_actual_generation_result_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bs_ubuntu1_post_receipt_verification_result_intake.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" "$PREREQUISITE_BINDING_DIR" <<'PY'
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
binding_arg = sys.argv[6].strip()
results = root / "results"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
binding_dir = Path(binding_arg).expanduser().resolve() if binding_arg else None
model_id = "mistralai/Mixtral-8x22B-v0.1"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")

CSV_ARTIFACT_FIELDS = {
    "real_model_generation_answer_rows.csv": [
        "generation_id",
        "review_query_packet_id",
        "query_id",
        "source_span_id",
        "model_id",
        "checkpoint_root",
        "answer_text_sha256",
        "generation_status",
        "abstain_decision",
        "fallback_used",
        "latency_row_id",
        "run_transcript_sha256",
    ],
    "real_model_generation_citation_rows.csv": [
        "generation_id",
        "query_id",
        "citation_id",
        "source_span_id",
        "source_file_sha256",
        "citation_verified",
    ],
    "real_model_generation_abstain_fallback_rows.csv": [
        "generation_id",
        "query_id",
        "expected_behavior",
        "abstain_expected",
        "abstain_observed",
        "fallback_used",
        "fallback_reason",
    ],
    "real_model_generation_latency_rows.csv": [
        "generation_id",
        "query_id",
        "prompt_tokens",
        "output_tokens",
        "prefill_ms",
        "decode_ms",
        "total_ms",
        "tokens_per_second",
    ],
}
JSON_ARTIFACT_FIELDS = {
    "real_model_generation_acceptance_summary.json": [
        "generation_protocol_version",
        "acceptance_decision",
        "expected_generation_rows",
        "accepted_answer_rows",
        "answer_rows_sha256",
        "accepted_citation_rows",
        "citation_rows_sha256",
        "accepted_latency_rows",
        "latency_rows_sha256",
    ]
}
ALL_ARTIFACTS = list(CSV_ARTIFACT_FIELDS) + list(JSON_ARTIFACT_FIELDS)


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


def read_csv_artifact(name):
    if supplied_dir is None:
        return [], [], False, ""
    path = supplied_dir / name
    if not path.is_file():
        return [], [], False, ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or [], True, sha256(path)


def read_json_artifact(name):
    if supplied_dir is None:
        return {}, False, ""
    path = supplied_dir / name
    if not path.is_file():
        return {}, False, ""
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    return data, True, sha256(path)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v61bs_dir = results / "v61bs_ubuntu1_post_receipt_verification_result_intake" / "intake_001"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v61bs_summary_path = results / "v61bs_ubuntu1_post_receipt_verification_result_intake_summary.csv"
v53r_summary_path = results / "v53r_complete_source_review_packet_summary.csv"
v61bs_summary = read_csv(v61bs_summary_path)[0]
v53r_summary = read_csv(v53r_summary_path)[0]
if v61bs_summary.get("v61bs_ubuntu1_post_receipt_verification_result_intake_ready") != "1":
    raise SystemExit("v61bt requires v61bs_ubuntu1_post_receipt_verification_result_intake_ready=1")
if v53r_summary.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61bt requires v53r_complete_source_review_packet_ready=1")

for src, rel in [
    (v61bs_summary_path, "source_v61bs/v61bs_ubuntu1_post_receipt_verification_result_intake_summary.csv"),
    (results / "v61bs_ubuntu1_post_receipt_verification_result_intake_decision.csv", "source_v61bs/v61bs_ubuntu1_post_receipt_verification_result_intake_decision.csv"),
    (v61bs_dir / "post_receipt_verification_result_status_rows.csv", "source_v61bs/post_receipt_verification_result_status_rows.csv"),
    (v61bs_dir / "post_receipt_verification_result_metric_rows.csv", "source_v61bs/post_receipt_verification_result_metric_rows.csv"),
    (v61bs_dir / "post_receipt_verification_promotion_requirement_rows.csv", "source_v61bs/post_receipt_verification_promotion_requirement_rows.csv"),
    (v61bs_dir / "runtime_gap_rows.csv", "source_v61bs/runtime_gap_rows.csv"),
    (v61bs_dir / "sha256_manifest.csv", "source_v61bs/sha256_manifest.csv"),
    (v53r_summary_path, "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_dir / "review_query_packet_rows.csv", "source_v53r/review_query_packet_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
]:
    copy(src, rel)

query_rows = read_csv(v53r_dir / "review_query_packet_rows.csv")
if len(query_rows) != 1000:
    raise SystemExit("v61bt expects 1000 v53r review query packet rows")
expected_query_ids = {row["query_id"] for row in query_rows}
expected_review_packet_ids = {row["review_query_packet_id"] for row in query_rows}
query_by_id = {row["query_id"]: row for row in query_rows}

target_root = v61bs_summary["target_root_path"]
expected_generation_rows = int(v61bs_summary["complete_source_query_rows"])
generation_admission_ready = int(v61bs_summary["generation_admission_result_ready"])
full_hash_ready = int(v61bs_summary["full_safetensors_page_hash_binding_ready"])
materialization_ready = int(v61bs_summary["local_checkpoint_materialization_ready"])
review_return_ready = int(v61bs_summary["complete_source_review_return_ready"])
post_receipt_verification_result_intake_ready = int(v61bs_summary["post_receipt_verification_result_intake_ready"])
prerequisite_binding_dir_supplied = int(binding_dir is not None)
prerequisite_binding_dir_exists = int(binding_dir is not None and binding_dir.is_dir())
prerequisite_binding_ready = 0
prerequisite_binding_source = "v61bs-default"
prerequisite_binding_reason = "not-supplied"

if binding_dir is not None:
    if not binding_dir.is_dir():
        prerequisite_binding_reason = "binding-dir-not-found"
    else:
        binding_sources = {
            "v61ck": binding_dir / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
            "v61cs": binding_dir / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
            "v61dd": binding_dir / "v61dd_review_return_generation_refresh_bridge_summary.csv",
        }
        missing_binding_sources = [name for name, path in binding_sources.items() if not path.is_file()]
        if missing_binding_sources:
            prerequisite_binding_reason = "missing-binding-sources:" + ";".join(missing_binding_sources)
        else:
            for name, path in binding_sources.items():
                copy(path, f"source_prerequisite_binding/{path.name}")
            binding_v61ck = read_csv(binding_sources["v61ck"])[0]
            binding_v61cs = read_csv(binding_sources["v61cs"])[0]
            binding_v61dd = read_csv(binding_sources["v61dd"])[0]
            binding_materialization_ready = int(binding_v61ck.get("full_checkpoint_materialization_ready", "0") == "1")
            binding_full_hash_ready = int(
                binding_v61ck.get("completed_full_safetensors_page_hash_coverage_ready", "0") == "1"
                and binding_v61ck.get("full_safetensors_page_hash_binding_ready", "0") == "1"
            )
            binding_review_ready = int(
                binding_v61dd.get("review_return_ready", "0") == "1"
                and binding_v61dd.get("v61_review_unblock_ready", "0") == "1"
                and binding_v61cs.get("complete_source_review_return_ready", "0") == "1"
            )
            binding_admission_ready = int(
                binding_v61cs.get("generation_execution_admission_ready", "0") == "1"
                and binding_v61cs.get("generation_execution_admitted_rows", "0")
                == binding_v61cs.get("generation_execution_admission_rows", "")
                and binding_v61cs.get("generation_execution_admission_rows", "0") == str(expected_generation_rows)
            )
            binding_target_root = binding_v61ck.get("target_root_path", "")
            binding_model_match = int(
                binding_v61ck.get("model_id") == model_id
                and binding_v61cs.get("model_id") == model_id
                and binding_v61dd.get("model_id") == model_id
            )
            binding_target_match = int(binding_target_root == target_root)
            prerequisite_binding_ready = int(
                binding_model_match
                and binding_target_match
                and binding_materialization_ready
                and binding_full_hash_ready
                and binding_review_ready
                and binding_admission_ready
            )
            prerequisite_binding_source = "v61ck/v61cs/v61dd"
            prerequisite_binding_reason = (
                "ready"
                if prerequisite_binding_ready
                else (
                    f"model_match={binding_model_match}; target_match={binding_target_match}; "
                    f"materialization={binding_materialization_ready}; full_hash={binding_full_hash_ready}; "
                    f"review={binding_review_ready}; admission={binding_admission_ready}"
                )
            )
            if prerequisite_binding_ready:
                materialization_ready = binding_materialization_ready
                full_hash_ready = binding_full_hash_ready
                review_return_ready = binding_review_ready
                generation_admission_ready = binding_admission_ready

generation_prerequisites_ready = int(
    generation_admission_ready and full_hash_ready and materialization_ready and review_return_ready
)
generation_prerequisite_state = (
    f"materialization={materialization_ready}; full_hash={full_hash_ready}; "
    f"review={review_return_ready}; admission={generation_admission_ready}; "
    f"binding={prerequisite_binding_ready}; binding_reason={prerequisite_binding_reason}"
)

required_field_rows = []
for artifact, fields in {**CSV_ARTIFACT_FIELDS, **JSON_ARTIFACT_FIELDS}.items():
    for field in fields:
        required_field_rows.append(
            {
                "result_artifact": artifact,
                "field_name": field,
                "requirement_status": "required",
                "purpose": "validate actual source-bound Mixtral generation result intake",
            }
        )
write_csv(run_dir / "actual_generation_result_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": "real_model_generation_answer_rows.csv",
        "example_payload": "one row per v53r query with answer_text_sha256 and transcript hash",
    },
    {
        "result_artifact": "real_model_generation_citation_rows.csv",
        "example_payload": "one source citation row per v53r query, source hash verified",
    },
    {
        "result_artifact": "real_model_generation_abstain_fallback_rows.csv",
        "example_payload": "one abstain/fallback policy row per v53r query",
    },
    {
        "result_artifact": "real_model_generation_latency_rows.csv",
        "example_payload": "one prefill/decode latency row per v53r query",
    },
    {
        "result_artifact": "real_model_generation_acceptance_summary.json",
        "example_payload": "artifact hashes and accepted row counts for the generation packet",
    },
]
write_csv(run_dir / "actual_generation_result_template_rows.csv", list(template_rows[0].keys()), template_rows)

artifact_status_rows = []
csv_rows_by_artifact = {}
artifact_sha = {}
supplied_artifacts = 0
accepted_artifacts = 0
invalid_artifacts = 0

for artifact, required_fields in CSV_ARTIFACT_FIELDS.items():
    rows, fields, supplied, digest = read_csv_artifact(artifact)
    csv_rows_by_artifact[artifact] = rows
    artifact_sha[artifact] = digest
    if supplied:
        supplied_artifacts += 1
        supplied_copy = run_dir / "supplied_actual_generation_results" / artifact
        supplied_copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(supplied_dir / artifact, supplied_copy)
    missing_fields = [field for field in required_fields if field not in fields]
    reasons = []
    if not supplied:
        reasons.append("result-artifact-not-supplied")
    elif missing_fields:
        reasons.append("missing-fields:" + ";".join(missing_fields))
    elif len(rows) != expected_generation_rows:
        reasons.append(f"row-count-mismatch:{len(rows)}")
    else:
        row_query_ids = {row.get("query_id", "") for row in rows}
        if row_query_ids != expected_query_ids:
            reasons.append("query-id-set-mismatch")
        if artifact == "real_model_generation_answer_rows.csv":
            row_packet_ids = {row.get("review_query_packet_id", "") for row in rows}
            if row_packet_ids != expected_review_packet_ids:
                reasons.append("review-query-packet-id-set-mismatch")
            if any(row.get("model_id") != model_id for row in rows):
                reasons.append("model-id-mismatch")
            if any(row.get("checkpoint_root") != target_root for row in rows):
                reasons.append("checkpoint-root-mismatch")
            if any(row.get("generation_status") not in {"generated", "abstained", "fallback"} for row in rows):
                reasons.append("generation-status-invalid")
            if any(not SHA_RE.match(row.get("answer_text_sha256", "")) for row in rows):
                reasons.append("answer-text-sha256-invalid")
            if any(not SHA_RE.match(row.get("run_transcript_sha256", "")) for row in rows):
                reasons.append("run-transcript-sha256-invalid")
        if artifact == "real_model_generation_citation_rows.csv":
            if any(row.get("citation_verified") != "1" for row in rows):
                reasons.append("citation-not-verified")
        if artifact == "real_model_generation_latency_rows.csv":
            for row in rows:
                try:
                    if float(row.get("total_ms", "0")) <= 0 or float(row.get("tokens_per_second", "0")) <= 0:
                        reasons.append("latency-non-positive")
                        break
                except ValueError:
                    reasons.append("latency-not-numeric")
                    break
    if supplied and not generation_prerequisites_ready:
        reasons.append("generation-prerequisites-not-ready:" + generation_prerequisite_state)
    accepted = int(not reasons)
    accepted_artifacts += accepted
    invalid_artifacts += int(supplied and not accepted)
    artifact_status_rows.append(
        {
            "result_artifact": artifact,
            "result_supplied": str(int(supplied)),
            "result_accepted": str(accepted),
            "result_status": "accepted" if accepted else "deferred-with-reason-final",
            "reason": "" if accepted else ";".join(reasons),
            "sha256": digest,
            "checkpoint_payload_bytes_downloaded_by_v61bt": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

acceptance_data, acceptance_supplied, acceptance_sha = read_json_artifact("real_model_generation_acceptance_summary.json")
if acceptance_supplied:
    supplied_artifacts += 1
    supplied_copy = run_dir / "supplied_actual_generation_results" / "real_model_generation_acceptance_summary.json"
    supplied_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(supplied_dir / "real_model_generation_acceptance_summary.json", supplied_copy)
json_missing = [field for field in JSON_ARTIFACT_FIELDS["real_model_generation_acceptance_summary.json"] if field not in acceptance_data]
json_reasons = []
if not acceptance_supplied:
    json_reasons.append("result-artifact-not-supplied")
elif json_missing:
    json_reasons.append("missing-fields:" + ";".join(json_missing))
else:
    if acceptance_data.get("acceptance_decision") != "accepted":
        json_reasons.append("acceptance-decision-not-accepted")
    for key in ["expected_generation_rows", "accepted_answer_rows", "accepted_citation_rows", "accepted_latency_rows"]:
        if str(acceptance_data.get(key)) != str(expected_generation_rows):
            json_reasons.append(f"{key}-mismatch")
    for key, artifact in [
        ("answer_rows_sha256", "real_model_generation_answer_rows.csv"),
        ("citation_rows_sha256", "real_model_generation_citation_rows.csv"),
        ("latency_rows_sha256", "real_model_generation_latency_rows.csv"),
    ]:
        if acceptance_data.get(key) != artifact_sha.get(artifact, ""):
            json_reasons.append(f"{key}-mismatch")
if acceptance_supplied and not generation_prerequisites_ready:
    json_reasons.append("generation-prerequisites-not-ready:" + generation_prerequisite_state)
json_accepted = int(not json_reasons)
accepted_artifacts += json_accepted
invalid_artifacts += int(acceptance_supplied and not json_accepted)
artifact_status_rows.append(
    {
        "result_artifact": "real_model_generation_acceptance_summary.json",
        "result_supplied": str(int(acceptance_supplied)),
        "result_accepted": str(json_accepted),
        "result_status": "accepted" if json_accepted else "deferred-with-reason-final",
        "reason": "" if json_accepted else ";".join(json_reasons),
        "sha256": acceptance_sha,
        "checkpoint_payload_bytes_downloaded_by_v61bt": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
)
write_csv(run_dir / "actual_generation_result_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)
validation_rows = [
    {
        "validation_id": row["result_artifact"].replace(".csv", "").replace(".json", ""),
        "status": "pass" if row["result_accepted"] == "1" else "blocked",
        "result_supplied": row["result_supplied"],
        "result_accepted": row["result_accepted"],
        "sha256": row["sha256"],
        "reason": "result artifact accepted" if row["result_accepted"] == "1" else row["reason"],
    }
    for row in artifact_status_rows
]
write_csv(run_dir / "actual_generation_result_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

missing_artifacts = len(ALL_ARTIFACTS) - supplied_artifacts
generation_packet_artifacts_ready = int(accepted_artifacts == len(ALL_ARTIFACTS))
actual_model_generation_ready = int(generation_packet_artifacts_ready and generation_prerequisites_ready)

accepted_answer_rows = expected_generation_rows if generation_packet_artifacts_ready else 0
accepted_citation_rows = expected_generation_rows if generation_packet_artifacts_ready else 0
accepted_latency_rows = expected_generation_rows if generation_packet_artifacts_ready else 0

query_status_rows = []
answer_by_query = {row.get("query_id", ""): row for row in csv_rows_by_artifact.get("real_model_generation_answer_rows.csv", [])}
for index, query in enumerate(query_rows):
    answer = answer_by_query.get(query["query_id"])
    accepted = int(actual_model_generation_ready and answer is not None)
    query_status_rows.append(
        {
            "generation_query_result_id": f"v61bt-query-{index:04d}",
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "owner_repo": query["owner_repo"],
            "source_span_id": query["source_span_id"],
            "source_file_sha256": query["source_file_sha256"],
            "generation_result_supplied": str(int(answer is not None)),
            "generation_result_accepted": str(accepted),
            "generation_status": answer.get("generation_status", "missing") if answer else "missing",
            "actual_model_generation_ready": str(accepted),
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "actual_generation_query_result_rows.csv", list(query_status_rows[0].keys()), query_status_rows)

requirement_rows = [
    {
        "requirement_id": "v61bs-verification-result-input",
        "status": "pass",
        "required_value": "v61bs ready",
        "actual_value": v61bs_summary["v61bs_ubuntu1_post_receipt_verification_result_intake_ready"],
        "reason": "post-receipt verification result intake is bound",
    },
    {
        "requirement_id": "generation-prerequisites-ready",
        "status": "pass" if generation_prerequisites_ready else "blocked",
        "required_value": "materialization, full hash, review return, generation admission",
        "actual_value": generation_prerequisite_state,
        "reason": "real generation results can only be accepted after admission gates pass",
    },
    {
        "requirement_id": "generation-answer-results",
        "status": "pass" if generation_packet_artifacts_ready else "blocked",
        "required_value": str(expected_generation_rows),
        "actual_value": str(accepted_answer_rows),
        "reason": "requires accepted answer/citation/policy/latency artifacts",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "pass" if actual_model_generation_ready else "blocked",
        "required_value": str(expected_generation_rows),
        "actual_value": str(sum(int(row["actual_model_generation_ready"]) for row in query_status_rows)),
        "reason": "source-bound actual Mixtral generation remains gated until prerequisites and result artifacts pass",
    },
    {
        "requirement_id": "production-latency",
        "status": "blocked",
        "required_value": "external production latency benchmark",
        "actual_value": "0",
        "reason": "v61bt is generation result intake, not a production benchmark",
    },
]
write_csv(run_dir / "actual_generation_result_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bt_ubuntu1_actual_generation_result_intake_metrics",
    "model_id": model_id,
    "v61bs_ubuntu1_post_receipt_verification_result_intake_ready": v61bs_summary["v61bs_ubuntu1_post_receipt_verification_result_intake_ready"],
    "post_receipt_verification_result_intake_ready": str(post_receipt_verification_result_intake_ready),
    "prerequisite_binding_dir_supplied": str(prerequisite_binding_dir_supplied),
    "prerequisite_binding_dir_exists": str(prerequisite_binding_dir_exists),
    "prerequisite_binding_ready": str(prerequisite_binding_ready),
    "prerequisite_binding_source": prerequisite_binding_source,
    "prerequisite_binding_reason": prerequisite_binding_reason,
    "generation_result_input_supplied": str(int(supplied_dir is not None)),
    "expected_generation_result_artifacts": str(len(ALL_ARTIFACTS)),
    "supplied_generation_result_artifacts": str(supplied_artifacts),
    "accepted_generation_result_artifacts": str(accepted_artifacts),
    "invalid_generation_result_artifacts": str(invalid_artifacts),
    "missing_generation_result_artifacts": str(missing_artifacts),
    "target_root_path": target_root,
    "expected_generation_rows": str(expected_generation_rows),
    "complete_source_query_rows": str(expected_generation_rows),
    "generation_query_result_rows": str(len(query_status_rows)),
    "generation_query_status_rows": str(len(query_status_rows)),
    "accepted_generation_rows": str(accepted_answer_rows),
    "accepted_answer_rows": str(accepted_answer_rows),
    "accepted_citation_rows": str(accepted_citation_rows),
    "accepted_latency_rows": str(accepted_latency_rows),
    "local_checkpoint_materialization_ready": str(materialization_ready),
    "full_safetensors_page_hash_binding_ready": str(full_hash_ready),
    "complete_source_review_return_ready": str(review_return_ready),
    "generation_admission_result_ready": str(generation_admission_ready),
    "generation_packet_artifacts_ready": str(generation_packet_artifacts_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "source_bound_qa_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bt": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "actual_generation_result_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61bs-verification-result-input", "ready", "v61bs result intake is bound"),
    ("generation-prerequisites", "ready" if generation_prerequisites_ready else "blocked", requirement_rows[1]["actual_value"]),
    ("generation-result-artifacts", "ready" if generation_packet_artifacts_ready else "blocked", f"accepted={accepted_artifacts}/{len(ALL_ARTIFACTS)}"),
    ("actual-model-generation", "ready" if actual_model_generation_ready else "blocked", f"accepted_generation_rows={accepted_answer_rows}/{expected_generation_rows}"),
    ("production-latency", "blocked", "not a decode latency benchmark"),
    ("near-frontier-quality", "blocked", "requires external review and comparison evidence"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bs-verification-result-input", "status": "pass", "reason": "v61bs result intake evidence is bound"},
    {"gate": "result-schema-template", "status": "pass", "reason": "required fields and templates emitted"},
    {"gate": "generation-prerequisites", "status": "pass" if generation_prerequisites_ready else "blocked", "reason": requirement_rows[1]["actual_value"]},
    {"gate": "generation-result-artifacts", "status": "pass" if generation_packet_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={accepted_artifacts}/{len(ALL_ARTIFACTS)}"},
    {"gate": "actual-model-generation", "status": "pass" if actual_model_generation_ready else "blocked", "reason": f"accepted_answer_rows={accepted_answer_rows}/{expected_generation_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bt writes metadata/result hashes only"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a production benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bt Ubuntu-1 Actual Generation Result Intake Boundary

This gate consumes source-bound actual Mixtral generation result artifacts. It
does not execute generation and does not download or commit checkpoint payload
bytes.

Evidence emitted:

- generation_result_input_supplied={int(supplied_dir is not None)}
- expected_generation_result_artifacts={len(ALL_ARTIFACTS)}
- supplied_generation_result_artifacts={supplied_artifacts}
- accepted_generation_result_artifacts={accepted_artifacts}
- missing_generation_result_artifacts={missing_artifacts}
- target_root_path={target_root}
- expected_generation_rows={expected_generation_rows}
- complete_source_query_rows={expected_generation_rows}
- generation_query_result_rows={len(query_status_rows)}
- accepted_generation_rows={accepted_answer_rows}
- accepted_answer_rows={accepted_answer_rows}
- post_receipt_verification_result_intake_ready={post_receipt_verification_result_intake_ready}
- prerequisite_binding_dir_supplied={prerequisite_binding_dir_supplied}
- prerequisite_binding_dir_exists={prerequisite_binding_dir_exists}
- prerequisite_binding_ready={prerequisite_binding_ready}
- prerequisite_binding_source={prerequisite_binding_source}
- prerequisite_binding_reason={prerequisite_binding_reason}
- local_checkpoint_materialization_ready={materialization_ready}
- full_safetensors_page_hash_binding_ready={full_hash_ready}
- complete_source_review_return_ready={review_return_ready}
- generation_admission_result_ready={generation_admission_ready}
- generation_packet_artifacts_ready={generation_packet_artifacts_ready}
- actual_model_generation_ready={actual_model_generation_ready}
- checkpoint_payload_bytes_downloaded_by_v61bt=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: actual generation result intake schema and missing-result
deferral for source-bound Mixtral QA.
Blocked wording: completed actual generation in the default path, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BT_UBUNTU1_ACTUAL_GENERATION_RESULT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bt_ubuntu1_actual_generation_result_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bt_ubuntu1_actual_generation_result_intake_ready": 1,
    "source_v61bs_summary_sha256": sha256(v61bs_summary_path),
    "source_v53r_summary_sha256": sha256(v53r_summary_path),
    "generation_result_input_supplied": int(supplied_dir is not None),
    "prerequisite_binding_dir_supplied": prerequisite_binding_dir_supplied,
    "prerequisite_binding_ready": prerequisite_binding_ready,
    "expected_generation_result_artifacts": len(ALL_ARTIFACTS),
    "accepted_generation_result_artifacts": accepted_artifacts,
    "expected_generation_rows": expected_generation_rows,
    "complete_source_query_rows": expected_generation_rows,
    "generation_query_result_rows": len(query_status_rows),
    "accepted_generation_rows": accepted_answer_rows,
    "accepted_answer_rows": accepted_answer_rows,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bt": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bt_ubuntu1_actual_generation_result_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bt_ubuntu1_actual_generation_result_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
