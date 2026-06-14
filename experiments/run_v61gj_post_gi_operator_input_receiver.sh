#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gj_post_gi_operator_input_receiver"
RUN_ID="${V61GJ_RUN_ID:-receiver_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
OPERATOR_INPUT_ROOT="${V61GJ_OPERATOR_INPUT_ROOT:-${V61GI_OPERATOR_INPUT_ROOT:-}}"
OUTPUT_ROOT="${V61GJ_OUTPUT_ROOT:-${V61GI_OUTPUT_ROOT:-}}"
EXECUTE_ASSEMBLY="${V61GJ_EXECUTE_ASSEMBLY:-0}"

if [[ "${V61GJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gj_post_gi_operator_input_receiver_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$OPERATOR_INPUT_ROOT" "$OUTPUT_ROOT" "$EXECUTE_ASSEMBLY" <<'PY'
import csv
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
operator_input_arg = sys.argv[5].strip()
output_root_arg = sys.argv[6].strip()
execute_assembly = int((sys.argv[7].strip() or "0") == "1")
results = root / "results"
prefix = "v61gj_post_gi_operator_input_receiver"
receiver_dir = run_dir / "operator_input_receiver"
receiver_dir.mkdir(parents=True, exist_ok=True)
operator_input_root = Path(operator_input_arg).expanduser().resolve() if operator_input_arg else None
output_root = Path(output_root_arg).expanduser().resolve() if output_root_arg else None
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CSV_FIELDSETS = {
    "v53/aggregate_review_return/human_review_rows.csv": [
        "review_answer_packet_id", "answer_id", "system_id", "query_id", "reviewer_id",
        "review_decision", "source_support_verified", "citation_verified", "policy_verified",
        "review_comment_sha256",
    ],
    "v53/aggregate_review_return/adjudication_rows.csv": [
        "adjudication_id", "review_answer_packet_id", "answer_id", "adjudicator_id",
        "adjudication_decision", "adjudication_reason_sha256",
    ],
    "v53/aggregate_review_return/reviewer_identity_rows.csv": [
        "assignment_id", "reviewer_id", "reviewer_slot_id", "system_id", "review_scope",
        "independence_declared", "credential_statement_sha256",
    ],
    "v53/aggregate_review_return/reviewer_conflict_rows.csv": [
        "assignment_id", "reviewer_id", "owner_repo", "conflict_declared",
        "conflict_statement_sha256",
    ],
    "v61/generation_result_return/real_model_generation_answer_rows.csv": [
        "generation_id", "review_query_packet_id", "query_id", "source_span_id", "model_id",
        "checkpoint_root", "answer_text_sha256", "generation_status", "abstain_decision",
        "fallback_used", "latency_row_id", "run_transcript_sha256",
    ],
    "v61/generation_result_return/real_model_generation_citation_rows.csv": [
        "generation_id", "query_id", "citation_id", "source_span_id", "source_file_sha256",
        "citation_verified",
    ],
    "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv": [
        "generation_id", "query_id", "expected_behavior", "abstain_expected", "abstain_observed",
        "fallback_used", "fallback_reason",
    ],
    "v61/generation_result_return/real_model_generation_latency_rows.csv": [
        "generation_id", "query_id", "prompt_tokens", "output_tokens", "prefill_ms",
        "decode_ms", "total_ms", "tokens_per_second",
    ],
}
JSON_FIELDSETS = {
    "v53/aggregate_review_return/acceptance_summary.json": [
        "review_protocol_version", "acceptance_decision", "slice_scope",
        "accepted_human_review_rows", "human_review_rows_sha256",
        "accepted_adjudication_rows", "adjudication_rows_sha256",
        "accepted_reviewer_identity_rows", "reviewer_identity_rows_sha256",
        "accepted_conflict_disclosure_rows", "reviewer_conflict_rows_sha256",
    ],
    "v61/generation_result_return/real_model_generation_acceptance_summary.json": [
        "generation_protocol_version", "acceptance_decision", "slice_scope",
        "accepted_answer_rows", "answer_rows_sha256",
        "accepted_citation_rows", "citation_rows_sha256",
        "accepted_abstain_fallback_rows", "abstain_fallback_rows_sha256",
        "accepted_latency_rows", "latency_rows_sha256",
    ],
}
JSON_BINDINGS = {
    "v53/aggregate_review_return/acceptance_summary.json": [
        ("accepted_human_review_rows", "human_review_rows_sha256", "v53/aggregate_review_return/human_review_rows.csv"),
        ("accepted_adjudication_rows", "adjudication_rows_sha256", "v53/aggregate_review_return/adjudication_rows.csv"),
        ("accepted_reviewer_identity_rows", "reviewer_identity_rows_sha256", "v53/aggregate_review_return/reviewer_identity_rows.csv"),
        ("accepted_conflict_disclosure_rows", "reviewer_conflict_rows_sha256", "v53/aggregate_review_return/reviewer_conflict_rows.csv"),
    ],
    "v61/generation_result_return/real_model_generation_acceptance_summary.json": [
        ("accepted_answer_rows", "answer_rows_sha256", "v61/generation_result_return/real_model_generation_answer_rows.csv"),
        ("accepted_citation_rows", "citation_rows_sha256", "v61/generation_result_return/real_model_generation_citation_rows.csv"),
        ("accepted_abstain_fallback_rows", "abstain_fallback_rows_sha256", "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv"),
        ("accepted_latency_rows", "latency_rows_sha256", "v61/generation_result_return/real_model_generation_latency_rows.csv"),
    ],
}
AUTHORITY_STATEMENT_RELS = {
    "v53/operator_attestation/reviewer_authority_statement.txt",
    "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
}
RECEIPT_REL = "OPERATOR_INPUT_RECEIPT.json"
RECEIPT_PROTOCOL_VERSION = "v61gj-operator-input-receipt-v1"
RECEIPT_ALLOWED_SOURCE_CLASSES = {
    "real-authority-bound-partial-return",
    "real-external-review-and-generation-return",
}
RECEIPT_REQUIRED_KEYS = [
    "receipt_protocol_version",
    "source_class",
    "finalized",
    "created_at_utc",
    "operator_input_root_id",
    "declared_artifact_count",
    "selected_slice_ids",
    "artifact_hashes",
    "external_return_attestation",
    "assembly_authority",
    "assembly_authority_statement",
]
RECEIPT_NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


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
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or []


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def count_value(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return -1


def validate_input_schema(operator_root, rel, path, min_rows):
    if path is None or not path.is_file():
        return 0, 0, 0, "missing"
    if rel in CSV_FIELDSETS:
        try:
            rows, fields = read_csv_with_fields(path)
        except (OSError, csv.Error) as exc:
            return 0, 0, 0, f"csv-unreadable:{exc}"
        errors = []
        missing = sorted(set(CSV_FIELDSETS[rel]) - set(fields))
        if missing:
            errors.append("missing-fields:" + ";".join(missing))
        if len(rows) < min_rows:
            errors.append(f"row-count<{min_rows}")
        for field in fields:
            if field.endswith("_sha256") or field in {"answer_text_sha256", "run_transcript_sha256", "source_file_sha256"}:
                for index, row in enumerate(rows, 1):
                    value = row.get(field, "")
                    if value and not SHA_RE.match(value):
                        errors.append(f"invalid-sha:{field}:{index}")
                        break
        return int(not errors), int(len(rows) >= min_rows), 1, ";".join(errors)
    if rel in JSON_FIELDSETS:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            return 0, 0, 0, f"json-unreadable:{exc}"
        errors = []
        missing = sorted(set(JSON_FIELDSETS[rel]) - set(payload))
        if missing:
            errors.append("missing-json-keys:" + ";".join(missing))
        binding_ready = 1
        min_ready = 1
        for count_field, sha_field, csv_rel in JSON_BINDINGS.get(rel, []):
            count = count_value(payload.get(count_field))
            if count < min_rows:
                min_ready = 0
                errors.append(f"{count_field}<%s" % min_rows)
            expected_path = operator_root / csv_rel if operator_root is not None else None
            expected_sha = sha256(expected_path) if expected_path is not None and expected_path.is_file() else ""
            if payload.get(sha_field) != expected_sha:
                binding_ready = 0
                errors.append(f"{sha_field}-mismatch")
        return int(not errors), min_ready, binding_ready, ";".join(errors)
    return 1, int(path.stat().st_size > 0), 1, ""


def validate_authority_statement(rel, text):
    if rel not in AUTHORITY_STATEMENT_RELS:
        return 1, ""
    lowered = text.lower()
    errors = []
    if len(text.strip()) < 40:
        errors.append("authority-statement-too-short")
    nonfinal_tokens = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
    if any(token in lowered for token in nonfinal_tokens):
        errors.append("authority-statement-nonfinal-text")
    return int(not errors), ";".join(errors)


def validate_operator_receipt(operator_root, required_rows, selected_rows):
    path = operator_root / RECEIPT_REL if operator_root is not None else None
    result = {
        "receipt_relative_path": RECEIPT_REL,
        "exists": "0",
        "schema_valid": "0",
        "hash_binding_ready": "0",
        "selected_slice_binding_ready": "0",
        "finality_ready": "0",
        "ready": "0",
        "assembly_authority_ready": "0",
        "bytes": "0",
        "sha256": "",
        "errors": "missing",
    }
    if path is None or not path.is_file():
        return result

    errors = []
    result["exists"] = "1"
    result["bytes"] = str(path.stat().st_size)
    result["sha256"] = sha256(path)
    text = path.read_text(encoding="utf-8", errors="replace")
    lowered = text.lower()
    if any(token in lowered for token in RECEIPT_NONFINAL_TOKENS):
        errors.append("receipt-nonfinal-text")

    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        result["errors"] = f"json-unreadable:{exc}"
        return result
    if not isinstance(payload, dict):
        result["errors"] = "json-not-object"
        return result

    schema_errors = []
    missing = sorted(set(RECEIPT_REQUIRED_KEYS) - set(payload))
    if missing:
        schema_errors.append("missing-json-keys:" + ";".join(missing))
    if payload.get("receipt_protocol_version") != RECEIPT_PROTOCOL_VERSION:
        schema_errors.append("protocol-version-mismatch")
    if payload.get("source_class") not in RECEIPT_ALLOWED_SOURCE_CLASSES:
        schema_errors.append("source-class-not-accepted")
    if payload.get("finalized") is not True:
        schema_errors.append("not-finalized")
    if count_value(payload.get("declared_artifact_count")) != len(required_rows):
        schema_errors.append("declared-artifact-count-mismatch")
    attestation = str(payload.get("external_return_attestation", ""))
    if len(attestation.strip()) < 40:
        schema_errors.append("external-return-attestation-too-short")
    assembly_authority = str(payload.get("assembly_authority", ""))
    assembly_authority_statement = str(payload.get("assembly_authority_statement", ""))
    assembly_authority_ready = 1
    if assembly_authority != "operator-final-real-return":
        assembly_authority_ready = 0
    if assembly_authority == "operator-final-real-return" and len(assembly_authority_statement.strip()) < 40:
        assembly_authority_ready = 0
        schema_errors.append("assembly-authority-statement-too-short")

    selected_slice_ids = payload.get("selected_slice_ids", {})
    selected_ids = {row["slice_id"] for row in selected_rows}
    selected_slice_ready = 1
    if not isinstance(selected_slice_ids, dict):
        selected_slice_ready = 0
        schema_errors.append("selected-slice-ids-not-object")
    else:
        if selected_slice_ids.get("v53") != "v53-partial-review-slice":
            selected_slice_ready = 0
            schema_errors.append("selected-v53-slice-mismatch")
        if selected_slice_ids.get("v61") != "v61-partial-generation-slice":
            selected_slice_ready = 0
            schema_errors.append("selected-v61-slice-mismatch")
        if selected_slice_ids.get("v53") not in selected_ids or selected_slice_ids.get("v61") not in selected_ids:
            selected_slice_ready = 0
            schema_errors.append("selected-slice-id-not-in-workbench")

    artifact_hashes = payload.get("artifact_hashes", {})
    hash_binding_ready = 1
    if not isinstance(artifact_hashes, dict):
        hash_binding_ready = 0
        schema_errors.append("artifact-hashes-not-object")
    else:
        required_rels = [row["final_relative_path"] for row in required_rows]
        missing_hashes = sorted(set(required_rels) - set(artifact_hashes))
        unexpected_hashes = sorted(set(artifact_hashes) - set(required_rels))
        if missing_hashes:
            hash_binding_ready = 0
            schema_errors.append("missing-artifact-hashes:" + ";".join(missing_hashes))
        if unexpected_hashes:
            hash_binding_ready = 0
            schema_errors.append("unexpected-artifact-hashes:" + ";".join(unexpected_hashes))
        for rel in required_rels:
            supplied_hash = artifact_hashes.get(rel, "")
            if supplied_hash and not SHA_RE.match(supplied_hash):
                hash_binding_ready = 0
                schema_errors.append(f"invalid-artifact-hash:{rel}")
                continue
            file_path = operator_root / rel
            if not file_path.is_file():
                hash_binding_ready = 0
                schema_errors.append(f"artifact-file-missing:{rel}")
                continue
            if supplied_hash != sha256(file_path):
                hash_binding_ready = 0
                schema_errors.append(f"artifact-hash-mismatch:{rel}")

    if schema_errors:
        errors.extend(schema_errors)
    result["schema_valid"] = str(int(not schema_errors))
    result["hash_binding_ready"] = str(hash_binding_ready)
    result["selected_slice_binding_ready"] = str(selected_slice_ready)
    result["finality_ready"] = str(int(not any(token in lowered for token in RECEIPT_NONFINAL_TOKENS)))
    result["assembly_authority_ready"] = str(assembly_authority_ready)
    result["ready"] = str(int(
        result["schema_valid"] == "1"
        and result["hash_binding_ready"] == "1"
        and result["selected_slice_binding_ready"] == "1"
        and result["finality_ready"] == "1"
    ))
    result["errors"] = ";".join(errors)
    return result


def read_operator_csv(operator_root, rel):
    path = operator_root / rel if operator_root is not None else None
    if path is None or not path.is_file():
        return [], []
    try:
        return read_csv_with_fields(path)
    except (OSError, csv.Error):
        return [], []


def numeric_positive(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False


def duplicate_values(rows, key):
    seen = set()
    duplicates = set()
    for row in rows:
        value = row.get(key, "")
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return duplicates


def validate_cross_file_consistency(operator_root):
    errors = {}

    def add(rel, message):
        errors.setdefault(rel, []).append(message)

    def has_fields(rel, fields):
        return set(CSV_FIELDSETS.get(rel, [])).issubset(set(fields))

    v53_human_rel = "v53/aggregate_review_return/human_review_rows.csv"
    v53_adjudication_rel = "v53/aggregate_review_return/adjudication_rows.csv"
    v53_identity_rel = "v53/aggregate_review_return/reviewer_identity_rows.csv"
    v53_conflict_rel = "v53/aggregate_review_return/reviewer_conflict_rows.csv"
    human_rows, human_fields = read_operator_csv(operator_root, v53_human_rel)
    adjudication_rows, adjudication_fields = read_operator_csv(operator_root, v53_adjudication_rel)
    identity_rows, identity_fields = read_operator_csv(operator_root, v53_identity_rel)
    conflict_rows, conflict_fields = read_operator_csv(operator_root, v53_conflict_rel)

    human_answer_ids = set()
    human_reviewer_ids = set()
    if has_fields(v53_human_rel, human_fields):
        human_answer_ids = {row.get("answer_id", "") for row in human_rows}
        human_reviewer_ids = {row.get("reviewer_id", "") for row in human_rows}
        if "" in human_answer_ids:
            add(v53_human_rel, "empty-answer-id")
        if "" in human_reviewer_ids:
            add(v53_human_rel, "empty-reviewer-id")
        if duplicate_values(human_rows, "answer_id"):
            add(v53_human_rel, "duplicate-answer-id")
    if has_fields(v53_adjudication_rel, adjudication_fields):
        for row in adjudication_rows:
            if row.get("answer_id", "") not in human_answer_ids:
                add(v53_adjudication_rel, "adjudication-answer-id-not-in-human-review")
                break
        if duplicate_values(adjudication_rows, "answer_id"):
            add(v53_adjudication_rel, "duplicate-adjudication-answer-id")
    identity_reviewers = set()
    identity_assignments = set()
    if has_fields(v53_identity_rel, identity_fields):
        identity_reviewers = {row.get("reviewer_id", "") for row in identity_rows}
        identity_assignments = {row.get("assignment_id", "") for row in identity_rows}
        if not human_reviewer_ids.issubset(identity_reviewers):
            add(v53_identity_rel, "human-reviewer-missing-identity-row")
        if duplicate_values(identity_rows, "assignment_id"):
            add(v53_identity_rel, "duplicate-assignment-id")
    if has_fields(v53_conflict_rel, conflict_fields):
        conflict_assignments = {row.get("assignment_id", "") for row in conflict_rows}
        conflict_reviewers = {row.get("reviewer_id", "") for row in conflict_rows}
        if identity_assignments and not identity_assignments.issubset(conflict_assignments):
            add(v53_conflict_rel, "identity-assignment-missing-conflict-row")
        if identity_reviewers and not conflict_reviewers.issubset(identity_reviewers):
            add(v53_conflict_rel, "conflict-reviewer-missing-identity-row")
        if any(row.get("conflict_declared") != "0" for row in conflict_rows):
            add(v53_conflict_rel, "conflict-not-clear")
        seen_pairs = set()
        for row in conflict_rows:
            pair = (row.get("assignment_id", ""), row.get("owner_repo", ""))
            if pair in seen_pairs:
                add(v53_conflict_rel, "duplicate-assignment-repo-pair")
                break
            seen_pairs.add(pair)

    v61_answer_rel = "v61/generation_result_return/real_model_generation_answer_rows.csv"
    v61_citation_rel = "v61/generation_result_return/real_model_generation_citation_rows.csv"
    v61_abstain_rel = "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv"
    v61_latency_rel = "v61/generation_result_return/real_model_generation_latency_rows.csv"
    answer_rows, answer_fields = read_operator_csv(operator_root, v61_answer_rel)
    answer_by_generation = {}
    if has_fields(v61_answer_rel, answer_fields):
        for row in answer_rows:
            gen_id = row.get("generation_id", "")
            if not gen_id:
                add(v61_answer_rel, "empty-generation-id")
                continue
            if gen_id in answer_by_generation:
                add(v61_answer_rel, "duplicate-generation-id")
            answer_by_generation[gen_id] = row
            if row.get("generation_status") not in {"generated", "abstained", "fallback"}:
                add(v61_answer_rel, "invalid-generation-status")
            if row.get("abstain_decision") not in {"0", "1"}:
                add(v61_answer_rel, "invalid-abstain-decision")
            if row.get("fallback_used") not in {"0", "1"}:
                add(v61_answer_rel, "invalid-fallback-used")

    def validate_v61_sidecar(rel, fields, row_checks):
        rows, actual_fields = read_operator_csv(operator_root, rel)
        if not has_fields(rel, actual_fields):
            return
        sidecar_generations = set()
        for row in rows:
            gen_id = row.get("generation_id", "")
            sidecar_generations.add(gen_id)
            answer = answer_by_generation.get(gen_id)
            if answer is None:
                add(rel, "unknown-generation-id")
            elif row.get("query_id", "") != answer.get("query_id", ""):
                add(rel, "mismatched-query-id")
            for check in row_checks(row):
                add(rel, check)
        missing = sorted(set(answer_by_generation) - sidecar_generations)
        if missing:
            add(rel, "missing-sidecar-for-generation-id")

    validate_v61_sidecar(
        v61_citation_rel,
        CSV_FIELDSETS[v61_citation_rel],
        lambda row: [] if row.get("citation_verified") == "1" else ["citation-not-verified"],
    )
    validate_v61_sidecar(
        v61_abstain_rel,
        CSV_FIELDSETS[v61_abstain_rel],
        lambda row: (
            ([] if row.get("abstain_expected") in {"0", "1"} else ["invalid-abstain-expected"])
            + ([] if row.get("abstain_observed") in {"0", "1"} else ["invalid-abstain-observed"])
            + ([] if row.get("fallback_used") in {"0", "1"} else ["invalid-fallback-used"])
        ),
    )
    validate_v61_sidecar(
        v61_latency_rel,
        CSV_FIELDSETS[v61_latency_rel],
        lambda row: (
            ([] if numeric_positive(row.get("total_ms")) else ["invalid-total-ms"])
            + ([] if numeric_positive(row.get("tokens_per_second")) else ["invalid-tokens-per-second"])
        ),
    )
    return errors


def validate_selected_slice_binding(operator_root, selected_rows):
    errors = {}

    def add(rel, message):
        errors.setdefault(rel, []).append(message)

    def has_fields(rel, fields):
        return set(CSV_FIELDSETS.get(rel, [])).issubset(set(fields))

    selected = {row["slice_id"]: row for row in selected_rows}
    v53 = selected.get("v53-partial-review-slice", {})
    v61 = selected.get("v61-partial-generation-slice", {})

    v53_human_rel = "v53/aggregate_review_return/human_review_rows.csv"
    v53_adjudication_rel = "v53/aggregate_review_return/adjudication_rows.csv"
    v53_identity_rel = "v53/aggregate_review_return/reviewer_identity_rows.csv"
    v53_conflict_rel = "v53/aggregate_review_return/reviewer_conflict_rows.csv"
    human_rows, human_fields = read_operator_csv(operator_root, v53_human_rel)
    adjudication_rows, adjudication_fields = read_operator_csv(operator_root, v53_adjudication_rel)
    identity_rows, identity_fields = read_operator_csv(operator_root, v53_identity_rel)
    conflict_rows, conflict_fields = read_operator_csv(operator_root, v53_conflict_rel)

    if has_fields(v53_human_rel, human_fields):
        for row in human_rows:
            for field in ["review_answer_packet_id", "answer_id", "system_id", "query_id"]:
                if v53.get(field, "") and row.get(field, "") != v53[field]:
                    add(v53_human_rel, f"selected-slice-mismatched-{field}")
    if has_fields(v53_adjudication_rel, adjudication_fields):
        for row in adjudication_rows:
            for field in ["review_answer_packet_id", "answer_id"]:
                if v53.get(field, "") and row.get(field, "") != v53[field]:
                    add(v53_adjudication_rel, f"selected-slice-mismatched-{field}")
    if has_fields(v53_identity_rel, identity_fields):
        for row in identity_rows:
            for field in ["assignment_id", "reviewer_slot_id", "system_id"]:
                if v53.get(field, "") and row.get(field, "") != v53[field]:
                    add(v53_identity_rel, f"selected-slice-mismatched-{field}")
    if has_fields(v53_conflict_rel, conflict_fields):
        for row in conflict_rows:
            for field in ["assignment_id", "owner_repo"]:
                if v53.get(field, "") and row.get(field, "") != v53[field]:
                    add(v53_conflict_rel, f"selected-slice-mismatched-{field}")

    v61_answer_rel = "v61/generation_result_return/real_model_generation_answer_rows.csv"
    v61_citation_rel = "v61/generation_result_return/real_model_generation_citation_rows.csv"
    v61_abstain_rel = "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv"
    v61_latency_rel = "v61/generation_result_return/real_model_generation_latency_rows.csv"
    answer_rows, answer_fields = read_operator_csv(operator_root, v61_answer_rel)
    citation_rows, citation_fields = read_operator_csv(operator_root, v61_citation_rel)
    abstain_rows, abstain_fields = read_operator_csv(operator_root, v61_abstain_rel)
    latency_rows, latency_fields = read_operator_csv(operator_root, v61_latency_rel)

    if has_fields(v61_answer_rel, answer_fields):
        for row in answer_rows:
            for field in ["query_id", "source_span_id"]:
                if v61.get(field, "") and row.get(field, "") != v61[field]:
                    add(v61_answer_rel, f"selected-slice-mismatched-{field}")
    if has_fields(v61_citation_rel, citation_fields):
        for row in citation_rows:
            for field in ["query_id", "source_span_id"]:
                if v61.get(field, "") and row.get(field, "") != v61[field]:
                    add(v61_citation_rel, f"selected-slice-mismatched-{field}")
    for rel, rows, fields in [
        (v61_abstain_rel, abstain_rows, abstain_fields),
        (v61_latency_rel, latency_rows, latency_fields),
    ]:
        if has_fields(rel, fields):
            for row in rows:
                if v61.get("query_id", "") and row.get("query_id", "") != v61["query_id"]:
                    add(rel, "selected-slice-mismatched-query-id")
    return errors


source_paths = {
    "v61gi_summary": results / "v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "v61gi_decision": results / "v61gi_post_gh_authority_bound_operator_input_scaffold_decision.csv",
    "v61gi_required_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_required_rows.csv",
    "v61gi_generated_marker_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_generated_marker_rows.csv",
    "v61gi_command_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_scaffold_command_rows.csv",
    "v61gi_assembly_wrapper": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_scaffold" / "RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh",
    "v61gh_selected_rows": results / "v61gh_post_gg_authority_bound_partial_root_workbench" / "workbench_001" / "authority_bound_partial_root_selected_slice_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gj source {source_id}: {path}")

source_rows = [copy_source(source_id, path, "source_v61gi") for source_id, path in source_paths.items()]
write_csv(run_dir / "operator_input_receiver_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gi = read_csv(source_paths["v61gi_summary"])[0]
if v61gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gj requires v61gi ready")

required_rows = read_csv(source_paths["v61gi_required_rows"])
marker_rows = read_csv(source_paths["v61gi_generated_marker_rows"])
selected_slice_rows = read_csv(source_paths["v61gh_selected_rows"])
operator_root_supplied = int(operator_input_root is not None)
operator_root_exists = int(operator_input_root is not None and operator_input_root.is_dir())
operator_input_root_outside_repo = int(operator_input_root is not None and not is_inside(operator_input_root, root))
output_root_supplied = int(output_root is not None)
output_root_outside_repo = int(output_root is not None and not is_inside(output_root, root))

preflight_rows = []
for row in required_rows:
    rel = row["final_relative_path"]
    path = operator_input_root / rel if operator_root_exists else None
    exists = int(path is not None and path.is_file())
    non_empty = int(exists and path.stat().st_size > 0)
    has_template_suffix = int(exists and path.name.endswith(".template"))
    placeholder_or_fixture = 0
    schema_valid = 0
    minimum_row_count_ready = 0
    hash_binding_ready = 0
    cross_file_consistency_ready = 0
    selected_slice_binding_ready = 0
    authority_statement_ready = 0
    digest = ""
    errors = []
    if not exists:
        errors.append("missing")
    else:
        digest = sha256(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        lowered = text.lower()
        placeholder_or_fixture = int("REPLACE_WITH" in text or "template" in lowered or "fixture" in lowered)
        if not non_empty:
            errors.append("empty")
        if has_template_suffix:
            errors.append("template-suffix")
        if placeholder_or_fixture:
            errors.append("placeholder-or-fixture-text")
        authority_statement_ready, authority_errors = validate_authority_statement(rel, text)
        if authority_errors:
            errors.append(authority_errors)
        schema_valid, minimum_row_count_ready, hash_binding_ready, schema_errors = validate_input_schema(
            operator_input_root,
            rel,
            path,
            int(row.get("minimum_row_count", "1") or "1"),
        )
        if schema_errors:
            errors.append(schema_errors)
    ready = int(exists and non_empty and not has_template_suffix and not placeholder_or_fixture and schema_valid and minimum_row_count_ready and hash_binding_ready)
    preflight_rows.append({
        "input_id": row["input_id"],
        "final_relative_path": rel,
        "required": row["required"],
        "authority_bound": row["authority_bound"],
        "exists": str(exists),
        "non_empty": str(non_empty),
        "has_template_suffix": str(has_template_suffix),
        "placeholder_or_fixture_text": str(placeholder_or_fixture),
        "schema_valid": str(schema_valid),
        "minimum_row_count_ready": str(minimum_row_count_ready),
        "hash_binding_ready": str(hash_binding_ready),
        "cross_file_consistency_ready": str(cross_file_consistency_ready),
        "selected_slice_binding_ready": str(selected_slice_binding_ready),
        "authority_statement_ready": str(authority_statement_ready),
        "ready": str(ready),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": digest,
        "errors": ";".join(errors),
    })

consistency_errors_by_rel = validate_cross_file_consistency(operator_input_root) if operator_root_exists else {}
selected_slice_errors_by_rel = validate_selected_slice_binding(operator_input_root, selected_slice_rows) if operator_root_exists else {}
for row in preflight_rows:
    rel = row["final_relative_path"]
    consistency_errors = consistency_errors_by_rel.get(rel, [])
    selected_slice_errors = selected_slice_errors_by_rel.get(rel, [])
    consistency_ready = int(row["exists"] == "1" and not consistency_errors)
    selected_slice_ready = int(row["exists"] == "1" and not selected_slice_errors)
    row["cross_file_consistency_ready"] = str(consistency_ready)
    row["selected_slice_binding_ready"] = str(selected_slice_ready)
    if consistency_errors:
        row["errors"] = ";".join(filter(None, [row["errors"], "cross-file:" + ";".join(sorted(set(consistency_errors)))]))
    if selected_slice_errors:
        row["errors"] = ";".join(filter(None, [row["errors"], "selected-slice:" + ";".join(sorted(set(selected_slice_errors)))]))
    row["ready"] = str(int(row["ready"] == "1" and consistency_ready and selected_slice_ready and row["authority_statement_ready"] == "1"))
write_csv(run_dir / "operator_input_receiver_preflight_rows.csv", list(preflight_rows[0].keys()), preflight_rows)

receipt_rows = [validate_operator_receipt(operator_input_root, required_rows, selected_slice_rows) if operator_root_exists else {
    "receipt_relative_path": RECEIPT_REL,
    "exists": "0",
    "schema_valid": "0",
    "hash_binding_ready": "0",
    "selected_slice_binding_ready": "0",
    "finality_ready": "0",
    "assembly_authority_ready": "0",
    "ready": "0",
    "bytes": "0",
    "sha256": "",
    "errors": "missing",
}]
write_csv(run_dir / "operator_input_receiver_receipt_rows.csv", list(receipt_rows[0].keys()), receipt_rows)
receipt_row = receipt_rows[0]

present_operator_input_rows = sum(row["exists"] == "1" for row in preflight_rows)
ready_operator_input_rows = sum(row["ready"] == "1" for row in preflight_rows)
schema_valid_rows = sum(row["schema_valid"] == "1" for row in preflight_rows)
minimum_row_count_ready_rows = sum(row["minimum_row_count_ready"] == "1" for row in preflight_rows)
hash_binding_ready_rows = sum(row["hash_binding_ready"] == "1" for row in preflight_rows)
cross_file_consistency_ready_rows = sum(row["cross_file_consistency_ready"] == "1" for row in preflight_rows)
operator_input_schema_ready = int(schema_valid_rows == len(required_rows) and len(required_rows) > 0)
operator_input_minimum_row_count_ready = int(minimum_row_count_ready_rows == len(required_rows) and len(required_rows) > 0)
operator_input_hash_binding_ready = int(hash_binding_ready_rows == len(required_rows) and len(required_rows) > 0)
operator_input_cross_file_consistency_ready = int(cross_file_consistency_ready_rows == len(required_rows) and len(required_rows) > 0)
selected_slice_binding_ready_rows = sum(row["selected_slice_binding_ready"] == "1" for row in preflight_rows)
operator_input_selected_slice_binding_ready = int(selected_slice_binding_ready_rows == len(required_rows) and len(required_rows) > 0)
authority_statement_required_rows = sum(row["authority_bound"] == "1" for row in preflight_rows)
authority_statement_ready_rows = sum(row["authority_bound"] == "1" and row["authority_statement_ready"] == "1" for row in preflight_rows)
operator_input_authority_statement_ready = int(authority_statement_required_rows > 0 and authority_statement_ready_rows == authority_statement_required_rows)
operator_input_receipt_supplied = int(receipt_row["exists"] == "1")
operator_input_receipt_schema_ready = int(receipt_row["schema_valid"] == "1")
operator_input_receipt_hash_binding_ready = int(receipt_row["hash_binding_ready"] == "1")
operator_input_receipt_selected_slice_binding_ready = int(receipt_row["selected_slice_binding_ready"] == "1")
operator_input_receipt_finality_ready = int(receipt_row["finality_ready"] == "1")
operator_input_assembly_authority_ready = int(receipt_row["assembly_authority_ready"] == "1")
operator_input_receipt_ready = int(receipt_row["ready"] == "1")
operator_input_preflight_ready = int(ready_operator_input_rows == len(required_rows) and len(required_rows) > 0 and operator_input_receipt_ready)
assembly_admitted = int(operator_input_preflight_ready and operator_input_assembly_authority_ready and operator_input_root_outside_repo and output_root_supplied and output_root_outside_repo)
assembly_executed = 0
assembly_exit_code = ""
assembly_stdout = ""
assembly_stderr = ""
if execute_assembly and assembly_admitted:
    env = os.environ.copy()
    env.update({
        "V61GI_OPERATOR_INPUT_ROOT": str(operator_input_root),
        "V61GI_OUTPUT_ROOT": str(output_root),
    })
    proc = subprocess.run(
        [str(source_paths["v61gi_assembly_wrapper"])],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assembly_executed = 1
    assembly_exit_code = str(proc.returncode)
    assembly_stdout = proc.stdout
    assembly_stderr = proc.stderr
    (run_dir / "operator_input_receiver_assembly_stdout.txt").write_text(assembly_stdout, encoding="utf-8")
    (run_dir / "operator_input_receiver_assembly_stderr.txt").write_text(assembly_stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61gj assembly failed: {proc.returncode}")

assembled_v53_root_ready = int(output_root is not None and (output_root / "v53" / "REAL_EXTERNAL_RETURN_PROVENANCE.json").is_file())
assembled_v61_root_ready = int(output_root is not None and (output_root / "v61" / "review_return_provenance" / "REAL_REVIEW_RETURN_PROVENANCE.json").is_file())

v61gg_operator_summary = {}
v61gg_summary_path = results / "v61gg_post_gf_real_authority_binding_guard_summary.csv"
if assembly_executed and v61gg_summary_path.is_file():
    v61gg_operator_summary = read_csv(v61gg_summary_path)[0]

v61gf_operator_summary = {}
v61gf_summary_path = results / "v61gf_post_ge_dual_partial_return_replay_admission_summary.csv"
if assembly_executed and v61gf_summary_path.is_file():
    v61gf_operator_summary = read_csv(v61gf_summary_path)[0]

if assembly_executed:
    replay_source_paths = {
        "v61gf_operator_summary": results / "v61gf_post_ge_dual_partial_return_replay_admission_summary.csv",
        "v61gf_operator_decision": results / "v61gf_post_ge_dual_partial_return_replay_admission_decision.csv",
        "v61gf_operator_stage_rows": results / "v61gf_post_ge_dual_partial_return_replay_admission" / "operator_authority_bound_partial_root_gf" / "dual_partial_return_replay_admission_stage_rows.csv",
        "v61gf_operator_command_rows": results / "v61gf_post_ge_dual_partial_return_replay_admission" / "operator_authority_bound_partial_root_gf" / "dual_partial_return_replay_admission_command_rows.csv",
        "v61gg_operator_summary": results / "v61gg_post_gf_real_authority_binding_guard_summary.csv",
        "v61gg_operator_decision": results / "v61gg_post_gf_real_authority_binding_guard_decision.csv",
        "v61gg_operator_authority_rows": results / "v61gg_post_gf_real_authority_binding_guard" / "operator_authority_bound_partial_root" / "real_authority_binding_guard_rows.csv",
        "v61gg_operator_stage_rows": results / "v61gg_post_gf_real_authority_binding_guard" / "operator_authority_bound_partial_root" / "real_authority_binding_guard_stage_rows.csv",
    }
    for source_id, path in replay_source_paths.items():
        if not path.is_file():
            raise SystemExit(f"v61gj assembly executed but replay evidence is missing: {source_id}: {path}")
        source_rows.append(copy_source(source_id, path, "source_operator_replay"))
    write_csv(run_dir / "operator_input_receiver_source_rows.csv", list(source_rows[0].keys()), source_rows)

row_acceptance_ready = as_int(v61gg_operator_summary, "v61gf_row_acceptance_ready") or as_int(v61gf_operator_summary, "row_acceptance_ready")
generation_execution_admission_ready = as_int(v61gg_operator_summary, "v61gf_generation_execution_admission_ready") or as_int(v61gf_operator_summary, "generation_execution_admission_ready")
dual_external_return_real_ready = as_int(v61gg_operator_summary, "v61gf_dual_external_return_real_ready") or as_int(v61gf_operator_summary, "dual_external_return_real_ready")
real_return_replay_admission_ready = as_int(v61gg_operator_summary, "v61gf_real_return_replay_admission_ready") or as_int(v61gf_operator_summary, "real_return_replay_admission_ready")
generation_acceptance_closure_ready = as_int(v61gg_operator_summary, "v61gf_generation_acceptance_closure_ready") or as_int(v61gf_operator_summary, "generation_acceptance_closure_ready")
generation_result_row_acceptance_ready = as_int(v61gf_operator_summary, "generation_result_row_acceptance_ready")
authority_bound_replay_admission_ready = as_int(v61gg_operator_summary, "authority_bound_replay_admission_ready")

real_external_review_return_rows = as_int(v61gf_operator_summary, "real_external_review_return_rows")
real_adjudication_rows = as_int(v61gf_operator_summary, "real_adjudication_rows")
slice_answer_review_accepted_rows = as_int(v61gf_operator_summary, "slice_answer_review_accepted_rows")
partial_real_slice_ready = as_int(v61gf_operator_summary, "partial_real_slice_ready")
real_generation_result_artifacts = as_int(v61gf_operator_summary, "real_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(v61gf_operator_summary, "accepted_generation_result_artifacts")
generation_result_accepted_rows = as_int(v61gf_operator_summary, "generation_result_accepted_rows")
accepted_answer_rows = as_int(v61gf_operator_summary, "accepted_answer_rows")
accepted_citation_rows = as_int(v61gf_operator_summary, "accepted_citation_rows")
accepted_latency_rows = as_int(v61gf_operator_summary, "accepted_latency_rows")
partial_real_generation_slice_ready = as_int(v61gf_operator_summary, "partial_real_generation_slice_ready")

stage_rows = [
    {"stage_id": "01-v61gi-source-ready", "status": "ready", "evidence": "v61gi ready"},
    {"stage_id": "02-operator-input-root-supplied", "status": "ready" if operator_root_supplied else "blocked", "evidence": f"operator_input_root_supplied={operator_root_supplied}"},
    {"stage_id": "03-operator-input-root-exists", "status": "ready" if operator_root_exists else "blocked", "evidence": f"operator_root_exists={operator_root_exists}"},
    {"stage_id": "04-operator-input-root-outside-repo", "status": "ready" if operator_input_root_outside_repo else "blocked", "evidence": f"operator_input_root_outside_repo={operator_input_root_outside_repo}"},
    {"stage_id": "05-operator-input-receipt", "status": "ready" if operator_input_receipt_ready else "blocked", "evidence": f"operator_input_receipt_ready={operator_input_receipt_ready}; hash_binding={operator_input_receipt_hash_binding_ready}"},
    {"stage_id": "06-operator-input-assembly-authority", "status": "ready" if operator_input_assembly_authority_ready else "blocked", "evidence": f"operator_input_assembly_authority_ready={operator_input_assembly_authority_ready}"},
    {"stage_id": "07-final-input-schema", "status": "ready" if operator_input_schema_ready else "blocked", "evidence": f"schema_valid_rows={schema_valid_rows}/{len(required_rows)}"},
    {"stage_id": "08-final-input-minimum-rows", "status": "ready" if operator_input_minimum_row_count_ready else "blocked", "evidence": f"minimum_row_count_ready_rows={minimum_row_count_ready_rows}/{len(required_rows)}"},
    {"stage_id": "09-final-input-hash-binding", "status": "ready" if operator_input_hash_binding_ready else "blocked", "evidence": f"hash_binding_ready_rows={hash_binding_ready_rows}/{len(required_rows)}"},
    {"stage_id": "10-final-input-cross-file-consistency", "status": "ready" if operator_input_cross_file_consistency_ready else "blocked", "evidence": f"cross_file_consistency_ready_rows={cross_file_consistency_ready_rows}/{len(required_rows)}"},
    {"stage_id": "11-final-input-selected-slice-binding", "status": "ready" if operator_input_selected_slice_binding_ready else "blocked", "evidence": f"selected_slice_binding_ready_rows={selected_slice_binding_ready_rows}/{len(required_rows)}"},
    {"stage_id": "12-final-input-authority-statement", "status": "ready" if operator_input_authority_statement_ready else "blocked", "evidence": f"authority_statement_ready_rows={authority_statement_ready_rows}/{authority_statement_required_rows}"},
    {"stage_id": "13-final-input-preflight", "status": "ready" if operator_input_preflight_ready else "blocked", "evidence": f"ready_operator_input_rows={ready_operator_input_rows}/{len(required_rows)}; receipt_ready={operator_input_receipt_ready}"},
    {"stage_id": "14-output-root-outside-repo", "status": "ready" if output_root_outside_repo else "blocked", "evidence": f"output_root_supplied={output_root_supplied}; output_root_outside_repo={output_root_outside_repo}"},
    {"stage_id": "15-assembly-admitted", "status": "ready" if assembly_admitted else "blocked", "evidence": f"assembly_admitted={assembly_admitted}; input_root_outside_repo={operator_input_root_outside_repo}; assembly_authority={operator_input_assembly_authority_ready}"},
    {"stage_id": "16-assembly-executed", "status": "ready" if assembly_executed else "blocked", "evidence": f"assembly_executed={assembly_executed}; exit_code={assembly_exit_code}"},
    {"stage_id": "17-row-acceptance", "status": "ready" if row_acceptance_ready else "blocked", "evidence": f"row_acceptance_ready={row_acceptance_ready}; review_rows={real_external_review_return_rows}; adjudication_rows={real_adjudication_rows}"},
    {"stage_id": "18-dual-external-return-real", "status": "ready" if dual_external_return_real_ready else "blocked", "evidence": f"dual_external_return_real_ready={dual_external_return_real_ready}; generation_artifacts={real_generation_result_artifacts}"},
    {"stage_id": "19-real-return-replay-admission", "status": "ready" if real_return_replay_admission_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}"},
    {"stage_id": "20-generation-acceptance-closure", "status": "ready" if generation_acceptance_closure_ready else "blocked", "evidence": f"generation_acceptance_closure_ready={generation_acceptance_closure_ready}; generation_result_accepted_rows={generation_result_accepted_rows}"},
    {"stage_id": "21-authority-bound-replay-admission", "status": "ready" if authority_bound_replay_admission_ready else "blocked", "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
    {"stage_id": "22-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "operator_input_receiver_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

operator_run_command = "V61GJ_OPERATOR_INPUT_ROOT=<operator-input-root> V61GJ_OUTPUT_ROOT=<external-output-root> V61GJ_EXECUTE_ASSEMBLY=1 ./experiments/run_v61gj_post_gi_operator_input_receiver.sh"
if operator_input_root is not None and output_root is not None:
    operator_run_command = " ".join([
        f"V61GJ_OPERATOR_INPUT_ROOT={shlex.quote(str(operator_input_root))}",
        f"V61GJ_OUTPUT_ROOT={shlex.quote(str(output_root))}",
        "V61GJ_EXECUTE_ASSEMBLY=1",
        "./experiments/run_v61gj_post_gi_operator_input_receiver.sh",
    ])

command_rows = [
    {"command_id": "01-verify-receiver-package", "ready_to_run_now": "1", "command": "results/v61gj_post_gi_operator_input_receiver/receiver_001/operator_input_receiver/VERIFY_OPERATOR_INPUT_RECEIVER.sh", "purpose": "verify metadata-only receiver output"},
    {"command_id": "02-run-with-operator-input", "ready_to_run_now": str(assembly_admitted), "command": operator_run_command, "purpose": "preflight final files and assemble authority-bound roots"},
]
write_csv(run_dir / "operator_input_receiver_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("OPERATOR_INPUT_RECEIVER_RECEIPT_ROWS.csv", run_dir / "operator_input_receiver_receipt_rows.csv"),
    ("OPERATOR_INPUT_RECEIVER_PREFLIGHT_ROWS.csv", run_dir / "operator_input_receiver_preflight_rows.csv"),
    ("OPERATOR_INPUT_RECEIVER_STAGE_ROWS.csv", run_dir / "operator_input_receiver_stage_rows.csv"),
    ("OPERATOR_INPUT_RECEIVER_COMMAND_ROWS.csv", run_dir / "operator_input_receiver_command_rows.csv"),
]:
    shutil.copy2(src, receiver_dir / rel)

(receiver_dir / "VERIFY_OPERATOR_INPUT_RECEIVER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_PREFLIGHT_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_RECEIPT_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_STAGE_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_MANIFEST.json\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in operator input receiver' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(receiver_dir / "VERIFY_OPERATOR_INPUT_RECEIVER.sh").chmod(0o755)

summary = {
    "v61gj_post_gi_operator_input_receiver_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_root_outside_repo": operator_input_root_outside_repo,
    "operator_input_required_rows": len(required_rows),
    "present_operator_input_rows": present_operator_input_rows,
    "ready_operator_input_rows": ready_operator_input_rows,
    "operator_input_receipt_supplied": operator_input_receipt_supplied,
    "operator_input_receipt_schema_ready": operator_input_receipt_schema_ready,
    "operator_input_receipt_hash_binding_ready": operator_input_receipt_hash_binding_ready,
    "operator_input_receipt_selected_slice_binding_ready": operator_input_receipt_selected_slice_binding_ready,
    "operator_input_receipt_finality_ready": operator_input_receipt_finality_ready,
    "operator_input_assembly_authority_ready": operator_input_assembly_authority_ready,
    "operator_input_receipt_ready": operator_input_receipt_ready,
    "schema_valid_rows": schema_valid_rows,
    "operator_input_schema_ready": operator_input_schema_ready,
    "minimum_row_count_ready_rows": minimum_row_count_ready_rows,
    "operator_input_minimum_row_count_ready": operator_input_minimum_row_count_ready,
    "hash_binding_ready_rows": hash_binding_ready_rows,
    "operator_input_hash_binding_ready": operator_input_hash_binding_ready,
    "cross_file_consistency_ready_rows": cross_file_consistency_ready_rows,
    "operator_input_cross_file_consistency_ready": operator_input_cross_file_consistency_ready,
    "selected_slice_binding_ready_rows": selected_slice_binding_ready_rows,
    "operator_input_selected_slice_binding_ready": operator_input_selected_slice_binding_ready,
    "authority_statement_required_rows": authority_statement_required_rows,
    "authority_statement_ready_rows": authority_statement_ready_rows,
    "operator_input_authority_statement_ready": operator_input_authority_statement_ready,
    "operator_input_preflight_ready": operator_input_preflight_ready,
    "generated_marker_contract_rows": len(marker_rows),
    "output_root_supplied": output_root_supplied,
    "output_root_outside_repo": output_root_outside_repo,
    "assembly_admitted": assembly_admitted,
    "assembly_executed": assembly_executed,
    "assembled_v53_root_ready": assembled_v53_root_ready,
    "assembled_v61_root_ready": assembled_v61_root_ready,
    "real_external_review_return_rows": real_external_review_return_rows,
    "real_adjudication_rows": real_adjudication_rows,
    "slice_answer_review_accepted_rows": slice_answer_review_accepted_rows,
    "partial_real_slice_ready": partial_real_slice_ready,
    "real_generation_result_artifacts": real_generation_result_artifacts,
    "accepted_generation_result_artifacts": accepted_generation_result_artifacts,
    "generation_result_accepted_rows": generation_result_accepted_rows,
    "accepted_answer_rows": accepted_answer_rows,
    "accepted_citation_rows": accepted_citation_rows,
    "accepted_latency_rows": accepted_latency_rows,
    "partial_real_generation_slice_ready": partial_real_generation_slice_ready,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_execution_admission_ready": generation_execution_admission_ready,
    "generation_result_row_acceptance_ready": generation_result_row_acceptance_ready,
    "dual_external_return_real_ready": dual_external_return_real_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "authority_bound_replay_admission_ready": authority_bound_replay_admission_ready,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "package_file_rows": 0,
    "metadata_only_package_file_rows": 0,
    "payload_like_package_file_rows": 0,
}

package_files = sorted(path for path in receiver_dir.rglob("*") if path.is_file())
package_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "operator_input_receiver_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = len(package_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "operator-input-root-supplied", "status": "pass" if operator_root_supplied else "blocked", "evidence": f"operator_input_root_supplied={operator_root_supplied}"},
    {"gate": "operator-input-root-outside-repo", "status": "pass" if operator_input_root_outside_repo else "blocked", "evidence": f"operator_input_root_outside_repo={operator_input_root_outside_repo}"},
    {"gate": "operator-input-receipt", "status": "pass" if operator_input_receipt_ready else "blocked", "evidence": f"operator_input_receipt_ready={operator_input_receipt_ready}; hash_binding={operator_input_receipt_hash_binding_ready}; finality={operator_input_receipt_finality_ready}"},
    {"gate": "operator-input-assembly-authority", "status": "pass" if operator_input_assembly_authority_ready else "blocked", "evidence": f"operator_input_assembly_authority_ready={operator_input_assembly_authority_ready}"},
    {"gate": "operator-input-schema", "status": "pass" if operator_input_schema_ready else "blocked", "evidence": f"schema_valid_rows={schema_valid_rows}/{len(required_rows)}"},
    {"gate": "operator-input-minimum-rows", "status": "pass" if operator_input_minimum_row_count_ready else "blocked", "evidence": f"minimum_row_count_ready_rows={minimum_row_count_ready_rows}/{len(required_rows)}"},
    {"gate": "operator-input-hash-binding", "status": "pass" if operator_input_hash_binding_ready else "blocked", "evidence": f"hash_binding_ready_rows={hash_binding_ready_rows}/{len(required_rows)}"},
    {"gate": "operator-input-cross-file-consistency", "status": "pass" if operator_input_cross_file_consistency_ready else "blocked", "evidence": f"cross_file_consistency_ready_rows={cross_file_consistency_ready_rows}/{len(required_rows)}"},
    {"gate": "operator-input-selected-slice-binding", "status": "pass" if operator_input_selected_slice_binding_ready else "blocked", "evidence": f"selected_slice_binding_ready_rows={selected_slice_binding_ready_rows}/{len(required_rows)}"},
    {"gate": "operator-input-authority-statement", "status": "pass" if operator_input_authority_statement_ready else "blocked", "evidence": f"authority_statement_ready_rows={authority_statement_ready_rows}/{authority_statement_required_rows}"},
    {"gate": "operator-input-preflight", "status": "pass" if operator_input_preflight_ready else "blocked", "evidence": f"ready_operator_input_rows={ready_operator_input_rows}/{len(required_rows)}"},
    {"gate": "assembly-admitted", "status": "pass" if assembly_admitted else "blocked", "evidence": f"assembly_admitted={assembly_admitted}"},
    {"gate": "assembly-executed", "status": "pass" if assembly_executed else "blocked", "evidence": f"assembly_executed={assembly_executed}"},
    {"gate": "row-acceptance", "status": "pass" if row_acceptance_ready else "blocked", "evidence": f"row_acceptance_ready={row_acceptance_ready}; review_rows={real_external_review_return_rows}; adjudication_rows={real_adjudication_rows}"},
    {"gate": "dual-external-return-real", "status": "pass" if dual_external_return_real_ready else "blocked", "evidence": f"dual_external_return_real_ready={dual_external_return_real_ready}"},
    {"gate": "real-return-replay-admission", "status": "pass" if real_return_replay_admission_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}"},
    {"gate": "generation-acceptance-closure", "status": "pass" if generation_acceptance_closure_ready else "blocked", "evidence": f"generation_acceptance_closure_ready={generation_acceptance_closure_ready}; generation_result_accepted_rows={generation_result_accepted_rows}"},
    {"gate": "authority-bound-replay-admission", "status": "pass" if authority_bound_replay_admission_ready else "blocked", "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
}
(receiver_dir / "OPERATOR_INPUT_RECEIVER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = "\n".join([
    "# V61GJ Post-GI Operator Input Receiver",
    "",
    "- v61gj_post_gi_operator_input_receiver_ready=1",
    f"- operator_input_root_supplied={operator_root_supplied}",
    f"- operator_input_root_outside_repo={operator_input_root_outside_repo}",
    f"- present_operator_input_rows={present_operator_input_rows}",
    f"- ready_operator_input_rows={ready_operator_input_rows}",
    f"- operator_input_receipt_ready={operator_input_receipt_ready}",
    f"- operator_input_assembly_authority_ready={operator_input_assembly_authority_ready}",
    f"- operator_input_preflight_ready={operator_input_preflight_ready}",
    f"- assembly_admitted={assembly_admitted}",
    f"- assembly_executed={assembly_executed}",
    f"- assembled_v53_root_ready={assembled_v53_root_ready}",
    f"- assembled_v61_root_ready={assembled_v61_root_ready}",
    f"- real_external_review_return_rows={real_external_review_return_rows}",
    f"- real_adjudication_rows={real_adjudication_rows}",
    f"- slice_answer_review_accepted_rows={slice_answer_review_accepted_rows}",
    f"- real_generation_result_artifacts={real_generation_result_artifacts}",
    f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}",
    f"- generation_result_accepted_rows={generation_result_accepted_rows}",
    f"- row_acceptance_ready={row_acceptance_ready}",
    f"- dual_external_return_real_ready={dual_external_return_real_ready}",
    f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
    f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
    f"- authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this receiver can only preflight and optionally assemble supplied operator input files. It does not create review/adjudication/generation evidence by itself and does not claim production latency, near-frontier quality, v1.0 comparison, or release readiness.",
    "",
])
(run_dir / "V61GJ_POST_GI_OPERATOR_INPUT_RECEIVER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gj_post_gi_operator_input_receiver_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
