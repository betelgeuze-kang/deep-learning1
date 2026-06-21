#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ge_post_gd_v61_partial_generation_intake_slice"
RUN_ID="${V61GE_RUN_ID:-slice_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V61_RETURN_ROOT="${V61GE_V61_RETURN_ROOT:-${V61FV_V61_RETURN_BUNDLE_DIR:-}}"
V61_RETURN_PROVENANCE="${V61GE_V61_RETURN_PROVENANCE:-${V61FV_V61_RETURN_PROVENANCE:-unspecified}}"

if [[ "${V61GE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ge_post_gd_v61_partial_generation_intake_slice_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gd_post_gc_v53_partial_external_return_slice_intake.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V61_RETURN_ROOT" "$V61_RETURN_PROVENANCE" <<'PY'
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
v61_root_arg = sys.argv[5].strip()
v61_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
prefix = "v61ge_post_gd_v61_partial_generation_intake_slice"
slice_dir = run_dir / "v61_partial_generation_intake_slice"
slice_dir.mkdir(parents=True, exist_ok=True)
v61_root = Path(v61_root_arg).expanduser().resolve() if v61_root_arg else None
generation_dir = v61_root / "generation_result_return" if v61_root else None
provenance_dir = v61_root / "review_return_provenance" if v61_root else None

REAL_PROVENANCE = "real-generation-intake-return-bundle"
PROVENANCE_MARKER = "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json"
DEFAULT_AUTHORITY_REL = "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt"
MODEL_ID = "mistralai/Mixtral-8x22B-v0.1"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CSV_FIELDS = {
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
JSON_ARTIFACT = "real_model_generation_acceptance_summary.json"
ACCEPTANCE_FIELDS = [
    "generation_protocol_version",
    "acceptance_decision",
    "slice_scope",
    "accepted_answer_rows",
    "answer_rows_sha256",
    "accepted_citation_rows",
    "citation_rows_sha256",
    "accepted_abstain_fallback_rows",
    "abstain_fallback_rows_sha256",
    "accepted_latency_rows",
    "latency_rows_sha256",
]
ALL_ARTIFACTS = list(CSV_FIELDS) + [JSON_ARTIFACT]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_csv_with_fields(path):
    if not path or not path.is_file():
        return [], [], ""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or [], sha256(path)


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


def status(flag):
    return "pass" if flag else "blocked"


def valid_sha(value):
    return isinstance(value, str) and bool(SHA_RE.match(value))


def safe_relative(base, rel):
    if base is None or not rel:
        return None, "authority-path-missing"
    rel_path = Path(str(rel))
    if rel_path.is_absolute():
        return None, "authority-path-absolute"
    candidate = (base / rel_path).resolve()
    try:
        candidate.relative_to(base.resolve())
    except ValueError:
        return None, "authority-path-escapes-root"
    return candidate, ""


def numeric_positive(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False


source_paths = {
    "v61gd_summary": results / "v61gd_post_gc_v53_partial_external_return_slice_intake_summary.csv",
    "v61gd_decision": results / "v61gd_post_gc_v53_partial_external_return_slice_intake_decision.csv",
    "v53r_summary": results / "v53r_complete_source_review_packet_summary.csv",
    "v53r_queries": results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ge source {source_id}: {path}")

source_rows = []
for source_id, path in source_paths.items():
    folder = "source_v61gd" if source_id.startswith("v61gd") else "source_v53r"
    source_rows.append(copy_source(source_id, path, folder))
write_csv(run_dir / "v61_partial_generation_intake_slice_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gd = read_csv(source_paths["v61gd_summary"])[0]
v53r = read_csv(source_paths["v53r_summary"])[0]
if v61gd.get("v61gd_post_gc_v53_partial_external_return_slice_intake_ready") != "1":
    raise SystemExit("v61ge requires v61gd ready")
if v53r.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61ge requires v53r ready")

query_rows = read_csv(source_paths["v53r_queries"])
query_by_id = {row["query_id"]: row for row in query_rows}
packet_by_id = {row["review_query_packet_id"]: row for row in query_rows}

root_supplied = int(v61_root is not None)
root_exists = int(v61_root is not None and v61_root.is_dir())
generation_dir_exists = int(generation_dir is not None and generation_dir.is_dir())
env_real_provenance = int(v61_provenance == REAL_PROVENANCE)
marker_path = provenance_dir / "REAL_REVIEW_RETURN_PROVENANCE.json" if provenance_dir else None
marker_supplied = int(marker_path is not None and marker_path.is_file())
marker_errors = []
marker_payload = {}
marker_sha = ""
marker_authority_path = ""
marker_authority_file_exists = 0
marker_authority_file_sha = ""
marker_authority_file_bytes = 0
if marker_supplied:
    marker_sha = sha256(marker_path)
    try:
        marker_payload = json.loads(marker_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        marker_errors.append("invalid-json")
    provenance_value = marker_payload.get("provenance") or marker_payload.get("provenance_class")
    if provenance_value != REAL_PROVENANCE:
        marker_errors.append("provenance-mismatch")
    source_class = marker_payload.get("source_class") or marker_payload.get("provenance_class", "")
    if str(source_class).startswith("fixture"):
        marker_errors.append("fixture-source-class")
    if source_class not in {"external-generation-intake-return", "external-operator-return", REAL_PROVENANCE}:
        marker_errors.append("source-class-not-external-generation-intake")
    expected_authority_sha = marker_payload.get("generation_operator_authority_sha256", marker_payload.get("reviewer_authority_sha256", ""))
    if not valid_sha(expected_authority_sha):
        marker_errors.append("operator-authority-sha256-missing")
    marker_authority_path = str(
        marker_payload.get(
            "generation_operator_authority_path",
            marker_payload.get("reviewer_authority_path", marker_payload.get("authority_statement_path", DEFAULT_AUTHORITY_REL)),
        )
    )
    authority_path, authority_error = safe_relative(v61_root, marker_authority_path)
    if authority_error:
        marker_errors.append(authority_error)
    marker_authority_file_exists = int(authority_path is not None and authority_path.is_file())
    if marker_authority_file_exists:
        marker_authority_file_sha = sha256(authority_path)
        marker_authority_file_bytes = authority_path.stat().st_size
        if marker_authority_file_bytes <= 0:
            marker_errors.append("authority-file-empty")
        if valid_sha(expected_authority_sha) and marker_authority_file_sha != expected_authority_sha:
            marker_errors.append("authority-sha-mismatch")
        try:
            authority_text = authority_path.read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            authority_text = ""
            marker_errors.append("authority-file-unreadable")
        if "fixture" in authority_text or "synthetic" in authority_text:
            marker_errors.append("authority-file-fixture-text")
    else:
        marker_errors.append("authority-file-missing")
else:
    marker_errors.append("missing-provenance-marker")
marker_real_provenance = int(marker_supplied and not marker_errors)
real_provenance_ready = int(env_real_provenance and marker_real_provenance)

artifact_rows = {}
artifact_fields = {}
artifact_sha = {}
supplied_file_rows = []
for artifact in ALL_ARTIFACTS:
    path = generation_dir / artifact if generation_dir else None
    supplied = int(path is not None and path.is_file())
    if artifact in CSV_FIELDS:
        rows, fields, digest = read_csv_with_fields(path)
        artifact_rows[artifact] = rows
        artifact_fields[artifact] = fields
        artifact_sha[artifact] = digest
    else:
        digest = sha256(path) if supplied else ""
        artifact_sha[artifact] = digest
    supplied_file_rows.append({
        "artifact": artifact,
        "expected_relative_path": f"generation_result_return/{artifact}",
        "supplied": str(supplied),
        "bytes": str(path.stat().st_size) if supplied else "0",
        "sha256": digest,
        "metadata_only": "0" if supplied else "1",
    })
supplied_file_rows.append({
    "artifact": "REAL_REVIEW_RETURN_PROVENANCE.json",
    "expected_relative_path": PROVENANCE_MARKER,
    "supplied": str(marker_supplied),
    "bytes": str(marker_path.stat().st_size) if marker_supplied else "0",
    "sha256": marker_sha,
    "metadata_only": "0" if marker_supplied else "1",
})
authority_supplied = int(marker_supplied and 'authority_path' in locals() and authority_path is not None and authority_path.is_file())
supplied_file_rows.append({
    "artifact": "generation_operator_authority_statement",
    "expected_relative_path": marker_authority_path or DEFAULT_AUTHORITY_REL,
    "supplied": str(authority_supplied),
    "bytes": str(authority_path.stat().st_size) if authority_supplied else "0",
    "sha256": marker_authority_file_sha,
    "metadata_only": "0" if authority_supplied else "1",
})
write_csv(run_dir / "v61_partial_generation_intake_slice_supplied_file_rows.csv", list(supplied_file_rows[0].keys()), supplied_file_rows)

validation_rows = []
accepted_artifact = {}

answer_rows = artifact_rows.get("real_model_generation_answer_rows.csv", [])
answer_by_generation = {}
answer_query_ids = set()
answer_errors = []
answer_required = set(CSV_FIELDS["real_model_generation_answer_rows.csv"])
if answer_rows and not answer_required.issubset(set(artifact_fields.get("real_model_generation_answer_rows.csv", []))):
    answer_errors.append("missing-fields:" + ";".join(sorted(answer_required - set(artifact_fields.get("real_model_generation_answer_rows.csv", [])))))
for index, row in enumerate(answer_rows, 1):
    errors = []
    query = query_by_id.get(row.get("query_id", ""))
    packet = packet_by_id.get(row.get("review_query_packet_id", ""))
    if query is None:
        errors.append("unknown-query-id")
    if packet is None or packet.get("query_id") != row.get("query_id"):
        errors.append("mismatched-review-query-packet-id")
    if query and row.get("source_span_id") != query.get("source_span_id"):
        errors.append("mismatched-source-span-id")
    if row.get("model_id") != MODEL_ID:
        errors.append("model-id-mismatch")
    if not row.get("checkpoint_root"):
        errors.append("checkpoint-root-empty")
    if row.get("generation_status") not in {"generated", "abstained", "fallback"}:
        errors.append("invalid-generation-status")
    for field in ["answer_text_sha256", "run_transcript_sha256"]:
        if not valid_sha(row.get(field, "")):
            errors.append(f"invalid-{field}")
    if row.get("generation_id") in answer_by_generation:
        errors.append("duplicate-generation-id")
    row_status = "pass" if not errors and not answer_errors else "blocked"
    if row_status == "pass":
        answer_by_generation[row["generation_id"]] = row
        answer_query_ids.add(row["query_id"])
    validation_rows.append({
        "validation_id": f"v61ge-answer-{index:05d}",
        "artifact": "real_model_generation_answer_rows.csv",
        "row_key": row.get("generation_id", ""),
        "status": row_status,
        "reason": "partial answer row accepted" if row_status == "pass" else ";".join(answer_errors + errors),
    })

def validate_sidecar(artifact, required_fields, row_validator):
    rows = artifact_rows.get(artifact, [])
    fields = set(artifact_fields.get(artifact, []))
    errors = []
    if rows and not set(required_fields).issubset(fields):
        errors.append("missing-fields:" + ";".join(sorted(set(required_fields) - fields)))
    accepted = {}
    query_ids = set()
    for index, row in enumerate(rows, 1):
        row_errors = list(errors)
        gen = answer_by_generation.get(row.get("generation_id", ""))
        if gen is None:
            row_errors.append("unknown-generation-id")
        elif row.get("query_id") != gen.get("query_id"):
            row_errors.append("mismatched-query-id")
        row_errors.extend(row_validator(row))
        row_status = "pass" if not row_errors else "blocked"
        if row_status == "pass":
            accepted[row["generation_id"]] = row
            query_ids.add(row["query_id"])
        validation_rows.append({
            "validation_id": f"v61ge-{artifact.replace('.csv', '').replace('_', '-')}-{index:05d}",
            "artifact": artifact,
            "row_key": row.get("generation_id", ""),
            "status": row_status,
            "reason": f"partial {artifact} row accepted" if row_status == "pass" else ";".join(row_errors),
        })
    return accepted, query_ids

accepted_citations, citation_query_ids = validate_sidecar(
    "real_model_generation_citation_rows.csv",
    CSV_FIELDS["real_model_generation_citation_rows.csv"],
    lambda row: (
        ([] if row.get("citation_verified") == "1" else ["citation-not-verified"])
        + ([] if valid_sha(row.get("source_file_sha256", "")) else ["invalid-source-file-sha256"])
    ),
)
accepted_abstain, abstain_query_ids = validate_sidecar(
    "real_model_generation_abstain_fallback_rows.csv",
    CSV_FIELDS["real_model_generation_abstain_fallback_rows.csv"],
    lambda row: (
        ([] if row.get("abstain_expected") in {"0", "1"} else ["invalid-abstain-expected"])
        + ([] if row.get("abstain_observed") in {"0", "1"} else ["invalid-abstain-observed"])
        + ([] if row.get("fallback_used") in {"0", "1"} else ["invalid-fallback-used"])
    ),
)
accepted_latency, latency_query_ids = validate_sidecar(
    "real_model_generation_latency_rows.csv",
    CSV_FIELDS["real_model_generation_latency_rows.csv"],
    lambda row: (
        ([] if numeric_positive(row.get("total_ms")) else ["invalid-total-ms"])
        + ([] if numeric_positive(row.get("tokens_per_second")) else ["invalid-tokens-per-second"])
    ),
)

candidate_query_ids = answer_query_ids & citation_query_ids & abstain_query_ids & latency_query_ids
candidate_answer_rows = len(answer_query_ids)
candidate_citation_rows = len(citation_query_ids)
candidate_abstain_rows = len(abstain_query_ids)
candidate_latency_rows = len(latency_query_ids)

accepted_artifact["real_model_generation_answer_rows.csv"] = int(candidate_answer_rows > 0 and candidate_query_ids == answer_query_ids)
accepted_artifact["real_model_generation_citation_rows.csv"] = int(candidate_citation_rows > 0 and candidate_query_ids == answer_query_ids)
accepted_artifact["real_model_generation_abstain_fallback_rows.csv"] = int(candidate_abstain_rows > 0 and candidate_query_ids == answer_query_ids)
accepted_artifact["real_model_generation_latency_rows.csv"] = int(candidate_latency_rows > 0 and candidate_query_ids == answer_query_ids)

acceptance_errors = []
acceptance_data = {}
acceptance_path = generation_dir / JSON_ARTIFACT if generation_dir else None
if acceptance_path and acceptance_path.is_file():
    try:
        acceptance_data = json.loads(acceptance_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        acceptance_errors.append("invalid-json")
    for field in ACCEPTANCE_FIELDS:
        if field not in acceptance_data:
            acceptance_errors.append(f"missing-{field}")
    expected_values = {
        "generation_protocol_version": "v61ge-partial-generation-slice",
        "acceptance_decision": "accepted-partial-slice",
        "slice_scope": "partial",
        "accepted_answer_rows": candidate_answer_rows,
        "answer_rows_sha256": artifact_sha.get("real_model_generation_answer_rows.csv", ""),
        "accepted_citation_rows": candidate_citation_rows,
        "citation_rows_sha256": artifact_sha.get("real_model_generation_citation_rows.csv", ""),
        "accepted_abstain_fallback_rows": candidate_abstain_rows,
        "abstain_fallback_rows_sha256": artifact_sha.get("real_model_generation_abstain_fallback_rows.csv", ""),
        "accepted_latency_rows": candidate_latency_rows,
        "latency_rows_sha256": artifact_sha.get("real_model_generation_latency_rows.csv", ""),
    }
    for field, value in expected_values.items():
        if field in acceptance_data and str(acceptance_data[field]) != str(value):
            acceptance_errors.append(f"mismatched-{field}")
else:
    acceptance_errors.append("missing-acceptance-summary")
acceptance_summary_ready = int(not acceptance_errors)
accepted_artifact[JSON_ARTIFACT] = acceptance_summary_ready
validation_rows.append({
    "validation_id": "v61ge-partial-generation-acceptance-summary",
    "artifact": JSON_ARTIFACT,
    "row_key": "acceptance_summary",
    "status": "pass" if acceptance_summary_ready else "blocked",
    "reason": "partial generation acceptance summary hash/count binding accepted" if acceptance_summary_ready else ";".join(acceptance_errors),
})

if not validation_rows:
    validation_rows.append({
        "validation_id": "v61ge-default-no-root",
        "artifact": "none",
        "row_key": "none",
        "status": "blocked",
        "reason": "no v61 generation-intake return root supplied",
    })
write_csv(run_dir / "v61_partial_generation_intake_slice_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

candidate_generation_result_artifacts = sum(accepted_artifact.get(artifact, 0) for artifact in ALL_ARTIFACTS)
candidate_generation_result_accepted_rows = len(candidate_query_ids) if candidate_generation_result_artifacts == len(ALL_ARTIFACTS) else 0
real_generation_result_artifacts = candidate_generation_result_artifacts if real_provenance_ready else 0
accepted_generation_result_artifacts = real_generation_result_artifacts
generation_result_accepted_rows = candidate_generation_result_accepted_rows if real_provenance_ready else 0
partial_real_generation_slice_ready = int(
    accepted_generation_result_artifacts > 0
    and generation_result_accepted_rows > 0
    and real_provenance_ready
)

artifact_status_rows = []
for artifact in ALL_ARTIFACTS:
    supplied = next(row for row in supplied_file_rows if row["artifact"] == artifact)["supplied"]
    artifact_status_rows.append({
        "artifact": artifact,
        "candidate_supplied": supplied,
        "candidate_accepted": str(accepted_artifact.get(artifact, 0)),
        "real_accepted": str(accepted_artifact.get(artifact, 0) if real_provenance_ready else 0),
        "sha256": artifact_sha.get(artifact, ""),
        "claim_boundary": "subset-scope generation result intake only",
    })
write_csv(run_dir / "v61_partial_generation_intake_slice_artifact_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)

query_acceptance_rows = []
for generation_id, answer in sorted(answer_by_generation.items()):
    accepted = int(answer["query_id"] in candidate_query_ids)
    query_acceptance_rows.append({
        "generation_id": generation_id,
        "review_query_packet_id": answer["review_query_packet_id"],
        "query_id": answer["query_id"],
        "source_span_id": answer["source_span_id"],
        "candidate_generation_result_accepted": str(accepted),
        "real_generation_result_accepted": str(int(accepted and real_provenance_ready)),
        "claim_boundary": "subset-scope only; full 1000-query generation remains blocked",
    })
if not query_acceptance_rows:
    query_acceptance_rows.append({
        "generation_id": "",
        "review_query_packet_id": "",
        "query_id": "",
        "source_span_id": "",
        "candidate_generation_result_accepted": "0",
        "real_generation_result_accepted": "0",
        "claim_boundary": "no supplied valid partial generation result slice",
    })
write_csv(run_dir / "v61_partial_generation_intake_slice_query_acceptance_rows.csv", list(query_acceptance_rows[0].keys()), query_acceptance_rows)

template_rows = [
    {
        "template_artifact": f"generation_result_return/{artifact}",
        "field_hint": ",".join(CSV_FIELDS.get(artifact, ACCEPTANCE_FIELDS)),
        "minimum_slice_note": "include matching generation_id/query_id subset rows",
    }
    for artifact in ALL_ARTIFACTS
]
template_rows.append({
    "template_artifact": PROVENANCE_MARKER,
    "field_hint": "provenance,source_class,generation_operator_authority_path,generation_operator_authority_sha256",
    "minimum_slice_note": "provenance marker must bind a non-fixture authority file inside the return root by sha256",
})
write_csv(run_dir / "v61_partial_generation_intake_slice_minimum_template_rows.csv", list(template_rows[0].keys()), template_rows)

stage_rows = [
    {"stage_id": "01-v61gd-source", "status": "ready", "evidence": "v61gd partial v53 return slice intake ready"},
    {"stage_id": "02-v53r-source", "status": "ready", "evidence": "v53r complete-source query packet ready"},
    {"stage_id": "03-v61-root-supplied", "status": "ready" if root_exists else "blocked", "evidence": f"root_supplied={root_supplied}; root_exists={root_exists}; generation_dir_exists={generation_dir_exists}"},
    {"stage_id": "04-real-generation-provenance", "status": "ready" if real_provenance_ready else "blocked", "evidence": f"env_real={env_real_provenance}; marker_real={marker_real_provenance}; errors={';'.join(marker_errors)}"},
    {"stage_id": "05-partial-generation-result-slice", "status": "ready" if partial_real_generation_slice_ready else "blocked", "evidence": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}; generation_result_accepted_rows={generation_result_accepted_rows}"},
    {"stage_id": "06-full-1000-generation-result", "status": "blocked", "evidence": "subset slice does not close full 1000-query generation result"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "v61ge accepts returned rows only; it does not execute generation"},
]
write_csv(run_dir / "v61_partial_generation_intake_slice_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_VALIDATION_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_validation_rows.csv"),
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_ARTIFACT_STATUS_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_artifact_status_rows.csv"),
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_QUERY_ACCEPTANCE_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_query_acceptance_rows.csv"),
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_MINIMUM_TEMPLATE_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_minimum_template_rows.csv"),
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_STAGE_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_stage_rows.csv"),
    ("V61_PARTIAL_GENERATION_INTAKE_SLICE_SUPPLIED_FILE_ROWS.csv", run_dir / "v61_partial_generation_intake_slice_supplied_file_rows.csv"),
]:
    shutil.copy2(path, slice_dir / rel)

slice_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61_return_root_supplied": root_supplied,
    "v61_return_root_exists": root_exists,
    "v61_real_provenance_ready": real_provenance_ready,
    "candidate_generation_result_artifacts": candidate_generation_result_artifacts,
    "candidate_generation_result_accepted_rows": candidate_generation_result_accepted_rows,
    "real_generation_result_artifacts": real_generation_result_artifacts,
    "accepted_generation_result_artifacts": accepted_generation_result_artifacts,
    "generation_result_accepted_rows": generation_result_accepted_rows,
    "partial_real_generation_slice_ready": partial_real_generation_slice_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(slice_dir / "V61_PARTIAL_GENERATION_INTAKE_SLICE_MANIFEST.json").write_text(json.dumps(slice_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(slice_dir / "VERIFY_V61_PARTIAL_GENERATION_INTAKE_SLICE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_MANIFEST.json\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_VALIDATION_ROWS.csv\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_ARTIFACT_STATUS_ROWS.csv\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_QUERY_ACCEPTANCE_ROWS.csv\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_MINIMUM_TEMPLATE_ROWS.csv\"",
        "test -s \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_STAGE_ROWS.csv\"",
        "grep -q 'partial_real_generation_slice_ready' \"$DIR/V61_PARTIAL_GENERATION_INTAKE_SLICE_MANIFEST.json\"",
        "",
    ]),
    encoding="utf-8",
)
(slice_dir / "VERIFY_V61_PARTIAL_GENERATION_INTAKE_SLICE.sh").chmod(0o755)
(slice_dir / "V61_PARTIAL_GENERATION_INTAKE_SLICE.md").write_text(
    "\n".join([
        "# v61ge v61 partial generation-intake slice",
        "",
        f"- v61_return_root_supplied={root_supplied}",
        f"- v61_return_root_exists={root_exists}",
        f"- v61_real_provenance_ready={real_provenance_ready}",
        f"- candidate_generation_result_artifacts={candidate_generation_result_artifacts}",
        f"- candidate_generation_result_accepted_rows={candidate_generation_result_accepted_rows}",
        f"- real_generation_result_artifacts={real_generation_result_artifacts}",
        f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}",
        f"- generation_result_accepted_rows={generation_result_accepted_rows}",
        "- actual_model_generation_ready=0",
        "",
        "This is subset-scope generation-result intake only. It does not close full 1000-query generation, actual generation execution, production latency, near-frontier, v1.0 comparison, or release readiness.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in slice_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "v61_partial_generation_intake_slice_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61ge_post_gd_v61_partial_generation_intake_slice_ready": "1",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": v61gd["v61gd_post_gc_v53_partial_external_return_slice_intake_ready"],
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v61_return_root_supplied": str(root_supplied),
    "v61_return_root_exists": str(root_exists),
    "v61_generation_result_return_dir_exists": str(generation_dir_exists),
    "v61_env_real_provenance": str(env_real_provenance),
    "v61_marker_supplied": str(marker_supplied),
    "v61_marker_real_provenance": str(marker_real_provenance),
    "v61_marker_authority_file_exists": str(marker_authority_file_exists),
    "v61_marker_authority_file_sha256": marker_authority_file_sha,
    "v61_real_provenance_ready": str(real_provenance_ready),
    "candidate_generation_result_artifacts": str(candidate_generation_result_artifacts),
    "candidate_answer_rows": str(candidate_answer_rows),
    "candidate_citation_rows": str(candidate_citation_rows),
    "candidate_abstain_fallback_rows": str(candidate_abstain_rows),
    "candidate_latency_rows": str(candidate_latency_rows),
    "candidate_acceptance_summary_ready": str(acceptance_summary_ready),
    "candidate_generation_result_accepted_rows": str(candidate_generation_result_accepted_rows),
    "real_generation_result_artifacts": str(real_generation_result_artifacts),
    "accepted_generation_result_artifacts": str(accepted_generation_result_artifacts),
    "generation_result_accepted_rows": str(generation_result_accepted_rows),
    "accepted_answer_rows": str(generation_result_accepted_rows),
    "accepted_citation_rows": str(generation_result_accepted_rows),
    "accepted_latency_rows": str(generation_result_accepted_rows),
    "partial_real_generation_slice_ready": str(partial_real_generation_slice_ready),
    "generation_execution_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ge": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "validation_rows": str(len(validation_rows)),
    "source_file_rows": str(len(source_rows)),
    "slice_package_file_rows": str(len(package_file_rows)),
    "metadata_only_slice_package_file_rows": str(sum(row["metadata_only"] == "1" for row in package_file_rows)),
    "payload_like_slice_package_file_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gd-ready", "status": "pass", "evidence": "v61gd ready"},
    {"gate": "source-v53r-ready", "status": "pass", "evidence": "v53r ready"},
    {"gate": "v61-root-supplied", "status": status(root_exists), "evidence": f"root_supplied={root_supplied}; root_exists={root_exists}"},
    {"gate": "v61-real-provenance", "status": status(real_provenance_ready), "evidence": f"env_real={env_real_provenance}; marker_real={marker_real_provenance}; errors={';'.join(marker_errors)}"},
    {"gate": "candidate-generation-result-slice", "status": status(candidate_generation_result_accepted_rows > 0), "evidence": f"candidate_generation_result_accepted_rows={candidate_generation_result_accepted_rows}"},
    {"gate": "real-generation-result-artifacts", "status": status(real_generation_result_artifacts > 0), "evidence": f"real_generation_result_artifacts={real_generation_result_artifacts}"},
    {"gate": "accepted-generation-result-artifacts", "status": status(accepted_generation_result_artifacts > 0), "evidence": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}"},
    {"gate": "generation-result-row-acceptance", "status": status(generation_result_accepted_rows > 0), "evidence": f"generation_result_accepted_rows={generation_result_accepted_rows}"},
    {"gate": "full-1000-generation-result", "status": "blocked", "evidence": "subset slice is not full 1000-query generation result"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GE Post-GD V61 Partial Generation Intake Slice Boundary",
    "",
    f"- v61ge_post_gd_v61_partial_generation_intake_slice_ready={summary['v61ge_post_gd_v61_partial_generation_intake_slice_ready']}",
    f"- v61_return_root_supplied={summary['v61_return_root_supplied']}",
    f"- v61_return_root_exists={summary['v61_return_root_exists']}",
    f"- v61_real_provenance_ready={summary['v61_real_provenance_ready']}",
    f"- candidate_generation_result_artifacts={summary['candidate_generation_result_artifacts']}",
    f"- candidate_generation_result_accepted_rows={summary['candidate_generation_result_accepted_rows']}",
    f"- real_generation_result_artifacts={summary['real_generation_result_artifacts']}",
    f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- accepted_answer_rows={summary['accepted_answer_rows']}",
    f"- accepted_citation_rows={summary['accepted_citation_rows']}",
    f"- accepted_latency_rows={summary['accepted_latency_rows']}",
    "- generation_execution_admission_ready=0",
    "- generation_acceptance_closure_ready=0",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this subset-scope slice is not full generation execution, full 1000-query generation result acceptance, actual model generation, production latency, near-frontier, v1.0 comparison, or release evidence.",
    "",
])
(run_dir / "V61GE_POST_GD_V61_PARTIAL_GENERATION_INTAKE_SLICE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "slice_manifest": slice_manifest,
    "checkpoint_payload_bytes_downloaded_by_v61ge": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61ge_post_gd_v61_partial_generation_intake_slice_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
