#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gi_post_gh_authority_bound_operator_input_scaffold"
RUN_ID="${V61GI_RUN_ID:-scaffold_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gi_post_gh_authority_bound_operator_input_scaffold_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gh_post_gg_authority_bound_partial_root_workbench.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
prefix = "v61gi_post_gh_authority_bound_operator_input_scaffold"
scaffold_dir = run_dir / "authority_bound_operator_input_scaffold"
template_root = scaffold_dir / "operator_input_templates"
scaffold_dir.mkdir(parents=True, exist_ok=True)
template_root.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def find_one(rows, key, value, label):
    hits = [row for row in rows if row.get(key) == value]
    if len(hits) != 1:
        raise SystemExit(f"expected one {label} where {key}={value}; got {len(hits)}")
    return hits[0]


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


source_paths = {
    "v61gh_summary": results / "v61gh_post_gg_authority_bound_partial_root_workbench_summary.csv",
    "v61gh_decision": results / "v61gh_post_gg_authority_bound_partial_root_workbench_decision.csv",
    "v61gh_contracts": results / "v61gh_post_gg_authority_bound_partial_root_workbench" / "workbench_001" / "authority_bound_partial_root_input_contract_rows.csv",
    "v61gh_selected": results / "v61gh_post_gg_authority_bound_partial_root_workbench" / "workbench_001" / "authority_bound_partial_root_selected_slice_rows.csv",
    "v61gh_commands": results / "v61gh_post_gg_authority_bound_partial_root_workbench" / "workbench_001" / "authority_bound_partial_root_workbench_command_rows.csv",
    "v53m_system_c_answer_rows": results / "v53m_complete_source_system_c_local_model_rag_measured" / "measured_001" / "system_c_answer_rows.csv",
    "v53m_system_c_citation_rows": results / "v53m_complete_source_system_c_local_model_rag_measured" / "measured_001" / "system_c_citation_rows.csv",
    "v53m_system_c_resource_rows": results / "v53m_complete_source_system_c_local_model_rag_measured" / "measured_001" / "system_c_resource_rows.csv",
    "v53i_complete_source_query_rows": results / "v53i_complete_source_query_instantiation" / "instantiate_001" / "complete_source_query_rows.csv",
    "v53i_complete_source_span_rows": results / "v53i_complete_source_query_instantiation" / "instantiate_001" / "complete_source_span_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gi source {source_id}: {path}")

source_rows = [copy_source(source_id, path, "source_v61gh") for source_id, path in source_paths.items()]
write_csv(run_dir / "authority_bound_operator_input_scaffold_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gh = read_csv(source_paths["v61gh_summary"])[0]
if v61gh.get("v61gh_post_gg_authority_bound_partial_root_workbench_ready") != "1":
    raise SystemExit("v61gi requires v61gh ready")

contracts = read_csv(source_paths["v61gh_contracts"])
selected = read_csv(source_paths["v61gh_selected"])
generated_marker_paths = {
    "REAL_EXTERNAL_RETURN_PROVENANCE.json",
    "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json",
}
operator_contracts = [row for row in contracts if row["target_relative_path"] not in generated_marker_paths]
generated_marker_contracts = [row for row in contracts if row["target_relative_path"] in generated_marker_paths]

operator_input_rows = []
for row in operator_contracts:
    final_rel = f"{row['target_root']}/{row['target_relative_path']}"
    template_rel = f"{final_rel}.template"
    operator_input_rows.append({
        "input_id": row["input_id"],
        "target_root": row["target_root"],
        "final_relative_path": final_rel,
        "template_relative_path": template_rel,
        "required": row["required"],
        "minimum_row_count": row["minimum_row_count"],
        "authority_bound": row["authority_bound"],
        "operator_must_replace_template": "1",
    })

receipt_template_rel = "OPERATOR_INPUT_RECEIPT.json.template"
minimal_slice_template_rel = "MINIMAL_SLICE_ROWS.csv.template"
minimal_slice_template_fields = [
    "reviewer_id",
    "adjudicator_id",
    "generation_id",
    "citation_id",
    "model_id",
    "checkpoint_root",
    "latency_row_id",
    "review_comment_sha256",
    "adjudication_reason_sha256",
    "credential_statement_sha256",
    "conflict_statement_sha256",
    "answer_text_sha256",
    "run_transcript_sha256",
    "source_file_sha256",
    "review_comment_content_path",
    "adjudication_reason_content_path",
    "credential_statement_content_path",
    "conflict_statement_content_path",
    "answer_text_content_path",
    "run_transcript_content_path",
    "source_file_content_path",
    "prompt_tokens",
    "output_tokens",
    "prefill_ms",
    "decode_ms",
    "total_ms",
    "tokens_per_second",
    "v53_authority_statement",
    "v61_authority_statement",
    "external_return_attestation",
]
minimal_slice_template_row = {
    "reviewer_id": "REPLACE_WITH_EXTERNAL_REVIEWER_ID",
    "adjudicator_id": "REPLACE_WITH_EXTERNAL_ADJUDICATOR_ID",
    "generation_id": "REPLACE_WITH_REAL_GENERATION_ID",
    "citation_id": "REPLACE_WITH_REAL_CITATION_ID",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_root": "REPLACE_WITH_EXTERNAL_CHECKPOINT_ROOT",
    "latency_row_id": "REPLACE_WITH_REAL_LATENCY_ROW_ID",
    "review_comment_sha256": "sha256:REPLACE_WITH_REVIEW_COMMENT_WITNESS_HASH",
    "adjudication_reason_sha256": "sha256:REPLACE_WITH_ADJUDICATION_REASON_WITNESS_HASH",
    "credential_statement_sha256": "sha256:REPLACE_WITH_CREDENTIAL_STATEMENT_WITNESS_HASH",
    "conflict_statement_sha256": "sha256:REPLACE_WITH_CONFLICT_STATEMENT_WITNESS_HASH",
    "answer_text_sha256": "sha256:REPLACE_WITH_ANSWER_TEXT_WITNESS_HASH",
    "run_transcript_sha256": "sha256:REPLACE_WITH_RUN_TRANSCRIPT_WITNESS_HASH",
    "source_file_sha256": "sha256:REPLACE_WITH_SOURCE_FILE_WITNESS_HASH",
    "review_comment_content_path": "REPLACE_WITH_PATH_TO_REVIEW_COMMENT_WITNESS",
    "adjudication_reason_content_path": "REPLACE_WITH_PATH_TO_ADJUDICATION_REASON_WITNESS",
    "credential_statement_content_path": "REPLACE_WITH_PATH_TO_CREDENTIAL_STATEMENT_WITNESS",
    "conflict_statement_content_path": "REPLACE_WITH_PATH_TO_CONFLICT_STATEMENT_WITNESS",
    "answer_text_content_path": "REPLACE_WITH_PATH_TO_ANSWER_TEXT_WITNESS",
    "run_transcript_content_path": "REPLACE_WITH_PATH_TO_RUN_TRANSCRIPT_WITNESS",
    "source_file_content_path": "REPLACE_WITH_PATH_TO_SOURCE_FILE_WITNESS",
    "prompt_tokens": "REPLACE_WITH_POSITIVE_PROMPT_TOKEN_COUNT",
    "output_tokens": "REPLACE_WITH_POSITIVE_OUTPUT_TOKEN_COUNT",
    "prefill_ms": "REPLACE_WITH_POSITIVE_PREFILL_MS",
    "decode_ms": "REPLACE_WITH_POSITIVE_DECODE_MS",
    "total_ms": "REPLACE_WITH_POSITIVE_TOTAL_MS",
    "tokens_per_second": "REPLACE_WITH_POSITIVE_TOKENS_PER_SECOND",
    "v53_authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_REVIEWER_AUTHORITY_STATEMENT",
    "v61_authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT",
    "external_return_attestation": "REPLACE_WITH_FINAL_EXTERNAL_RETURN_ATTESTATION",
}

generated_marker_rows = []
for row in generated_marker_contracts:
    generated_marker_rows.append({
        "generated_id": row["input_id"],
        "target_root": row["target_root"],
        "generated_relative_path": f"{row['target_root']}/{row['target_relative_path']}",
        "source_authority_file": "v53/operator_attestation/reviewer_authority_statement.txt" if row["target_root"] == "v53" else "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
        "generated_by": "v61gh ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py",
        "operator_supplies_directly": "0",
    })

write_csv(run_dir / "authority_bound_operator_input_required_rows.csv", list(operator_input_rows[0].keys()), operator_input_rows)
write_csv(run_dir / "authority_bound_operator_generated_marker_rows.csv", list(generated_marker_rows[0].keys()), generated_marker_rows)

def write_template(rel, text):
    path = template_root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


v53_selected = next(row for row in selected if row["slice_id"] == "v53-partial-review-slice")
v61_selected = next(row for row in selected if row["slice_id"] == "v61-partial-generation-slice")
selected_answer_row = find_one(read_csv(source_paths["v53m_system_c_answer_rows"]), "answer_id", v53_selected["answer_id"], "selected answer row")
selected_citation_row = find_one(read_csv(source_paths["v53m_system_c_citation_rows"]), "answer_id", v53_selected["answer_id"], "selected citation row")
selected_resource_row = find_one(read_csv(source_paths["v53m_system_c_resource_rows"]), "answer_id", v53_selected["answer_id"], "selected resource row")
selected_query_row = find_one(read_csv(source_paths["v53i_complete_source_query_rows"]), "query_id", v53_selected["query_id"], "selected query row")
selected_span_row = find_one(read_csv(source_paths["v53i_complete_source_span_rows"]), "source_span_id", v53_selected["source_span_id"], "selected source span row")

template_specs = {
    "v53/aggregate_review_return/human_review_rows.csv.template": (
        "review_answer_packet_id,answer_id,system_id,query_id,reviewer_id,review_decision,source_support_verified,citation_verified,policy_verified,review_comment_sha256\n"
        f"{v53_selected['review_answer_packet_id']},{v53_selected['answer_id']},{v53_selected['system_id']},{v53_selected['query_id']},REPLACE_WITH_REVIEWER_ID,accept,1,1,1,sha256:REPLACE_WITH_64_HEX_REVIEW_COMMENT\n"
    ),
    "v53/aggregate_review_return/adjudication_rows.csv.template": (
        "adjudication_id,review_answer_packet_id,answer_id,adjudicator_id,adjudication_decision,adjudication_reason_sha256\n"
        f"REPLACE_WITH_ADJUDICATION_ID,{v53_selected['review_answer_packet_id']},{v53_selected['answer_id']},REPLACE_WITH_ADJUDICATOR_ID,accept,sha256:REPLACE_WITH_64_HEX_REASON\n"
    ),
    "v53/aggregate_review_return/reviewer_identity_rows.csv.template": (
        "assignment_id,reviewer_id,reviewer_slot_id,system_id,review_scope,independence_declared,credential_statement_sha256\n"
        f"{v53_selected['assignment_id']},REPLACE_WITH_REVIEWER_ID,{v53_selected['reviewer_slot_id']},{v53_selected['system_id']},complete-source,1,sha256:REPLACE_WITH_64_HEX_CREDENTIAL\n"
    ),
    "v53/aggregate_review_return/reviewer_conflict_rows.csv.template": (
        "assignment_id,reviewer_id,owner_repo,conflict_declared,conflict_statement_sha256\n"
        f"{v53_selected['assignment_id']},REPLACE_WITH_REVIEWER_ID,{v53_selected['owner_repo']},0,sha256:REPLACE_WITH_64_HEX_CONFLICT_STATEMENT\n"
    ),
    "v53/aggregate_review_return/acceptance_summary.json.template": json.dumps({
        "review_protocol_version": "v61gd-partial-v53-slice",
        "acceptance_decision": "accepted-partial-slice",
        "slice_scope": "partial",
        "accepted_human_review_rows": 1,
        "human_review_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_HUMAN_REVIEW_ROWS",
        "accepted_adjudication_rows": 1,
        "adjudication_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_ADJUDICATION_ROWS",
        "accepted_reviewer_identity_rows": 1,
        "reviewer_identity_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_IDENTITY_ROWS",
        "accepted_conflict_disclosure_rows": 1,
        "reviewer_conflict_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_CONFLICT_ROWS",
    }, indent=2, sort_keys=True) + "\n",
    "v53/operator_attestation/reviewer_authority_statement.txt.template": (
        "Replace this file with the external reviewer/operator authority statement. Do not leave template text in the final file.\n"
    ),
    "v61/generation_result_return/real_model_generation_answer_rows.csv.template": (
        "generation_id,review_query_packet_id,query_id,source_span_id,model_id,checkpoint_root,answer_text_sha256,generation_status,abstain_decision,fallback_used,latency_row_id,run_transcript_sha256\n"
        f"REPLACE_WITH_GENERATION_ID,{v61_selected.get('review_query_packet_id', '')},{v61_selected['query_id']},{v61_selected['source_span_id']},mistralai/Mixtral-8x22B-v0.1,REPLACE_WITH_CHECKPOINT_ROOT,sha256:REPLACE_WITH_64_HEX_ANSWER,generated,0,0,REPLACE_WITH_LATENCY_ROW_ID,sha256:REPLACE_WITH_64_HEX_TRANSCRIPT\n"
    ),
    "v61/generation_result_return/real_model_generation_citation_rows.csv.template": (
        "generation_id,query_id,citation_id,source_span_id,source_file_sha256,citation_verified\n"
        f"REPLACE_WITH_GENERATION_ID,{v61_selected['query_id']},REPLACE_WITH_CITATION_ID,{v61_selected['source_span_id']},sha256:REPLACE_WITH_64_HEX_SOURCE_FILE,1\n"
    ),
    "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv.template": (
        "generation_id,query_id,expected_behavior,abstain_expected,abstain_observed,fallback_used,fallback_reason\n"
        f"REPLACE_WITH_GENERATION_ID,{v61_selected['query_id']},source-bound-answer,0,0,0,\n"
    ),
    "v61/generation_result_return/real_model_generation_latency_rows.csv.template": (
        "generation_id,query_id,prompt_tokens,output_tokens,prefill_ms,decode_ms,total_ms,tokens_per_second\n"
        f"REPLACE_WITH_GENERATION_ID,{v61_selected['query_id']},REPLACE_WITH_PROMPT_TOKENS,REPLACE_WITH_OUTPUT_TOKENS,REPLACE_WITH_PREFILL_MS,REPLACE_WITH_DECODE_MS,REPLACE_WITH_TOTAL_MS,REPLACE_WITH_TOKENS_PER_SECOND\n"
    ),
    "v61/generation_result_return/real_model_generation_acceptance_summary.json.template": json.dumps({
        "generation_protocol_version": "v61ge-partial-generation-slice",
        "acceptance_decision": "accepted-partial-slice",
        "slice_scope": "partial",
        "accepted_answer_rows": 1,
        "answer_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_ANSWER_ROWS",
        "accepted_citation_rows": 1,
        "citation_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_CITATION_ROWS",
        "accepted_abstain_fallback_rows": 1,
        "abstain_fallback_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_ABSTAIN_ROWS",
        "accepted_latency_rows": 1,
        "latency_rows_sha256": "sha256:REPLACE_WITH_HASH_OF_FINAL_LATENCY_ROWS",
    }, indent=2, sort_keys=True) + "\n",
    "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt.template": (
        "Replace this file with the external generation operator authority statement. Do not leave template text in the final file.\n"
    ),
}
template_specs[receipt_template_rel] = json.dumps({
    "receipt_protocol_version": "v61gj-operator-input-receipt-v1",
    "source_class": "REPLACE_WITH_real-authority-bound-partial-return",
    "finalized": True,
    "created_at_utc": "REPLACE_WITH_FINAL_UTC_TIMESTAMP",
    "operator_input_root_id": "REPLACE_WITH_FINAL_OPERATOR_INPUT_ROOT_ID",
    "declared_artifact_count": len(operator_input_rows),
    "selected_slice_ids": {
        "v53": "v53-partial-review-slice",
        "v61": "v61-partial-generation-slice",
    },
    "artifact_hashes": {
        row["final_relative_path"]: "sha256:REPLACE_WITH_HASH_OF_FINAL_FILE"
        for row in operator_input_rows
    },
    "content_witness_files": {
        "review_comment_sha256": "operator_content_witness/review_comment.txt",
        "adjudication_reason_sha256": "operator_content_witness/adjudication_reason.txt",
        "credential_statement_sha256": "operator_content_witness/credential_statement.txt",
        "conflict_statement_sha256": "operator_content_witness/conflict_statement.txt",
        "answer_text_sha256": "operator_content_witness/answer_text.txt",
        "run_transcript_sha256": "operator_content_witness/run_transcript.txt",
        "source_file_sha256": "operator_content_witness/source_file.txt",
    },
    "content_witness_hashes": {
        "review_comment_sha256": "sha256:REPLACE_WITH_HASH_OF_REVIEW_COMMENT_WITNESS",
        "adjudication_reason_sha256": "sha256:REPLACE_WITH_HASH_OF_ADJUDICATION_REASON_WITNESS",
        "credential_statement_sha256": "sha256:REPLACE_WITH_HASH_OF_CREDENTIAL_STATEMENT_WITNESS",
        "conflict_statement_sha256": "sha256:REPLACE_WITH_HASH_OF_CONFLICT_STATEMENT_WITNESS",
        "answer_text_sha256": "sha256:REPLACE_WITH_HASH_OF_ANSWER_TEXT_WITNESS",
        "run_transcript_sha256": "sha256:REPLACE_WITH_HASH_OF_RUN_TRANSCRIPT_WITNESS",
        "source_file_sha256": "sha256:REPLACE_WITH_HASH_OF_SOURCE_FILE_WITNESS",
    },
    "external_return_attestation": "REPLACE_WITH_FINAL_EXTERNAL_RETURN_ATTESTATION",
}, indent=2, sort_keys=True) + "\n"

template_rows = []
for rel, text in template_specs.items():
    path = write_template(rel, text)
    final_rel = rel.removesuffix(".template")
    template_rows.append({
        "template_relative_path": rel,
        "final_relative_path": final_rel,
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "template_only": "1",
        "counts_as_evidence": "0",
    })
write_csv(run_dir / "authority_bound_operator_input_template_file_rows.csv", list(template_rows[0].keys()), template_rows)

minimal_slice_template_path = scaffold_dir / minimal_slice_template_rel
write_csv(minimal_slice_template_path, minimal_slice_template_fields, [minimal_slice_template_row])
minimal_slice_template_rows = [{
    "template_relative_path": minimal_slice_template_rel,
    "bytes": str(minimal_slice_template_path.stat().st_size),
    "sha256": sha256(minimal_slice_template_path),
    "template_only": "1",
    "counts_as_evidence": "0",
    "content_witness_fields": "7",
}]
write_csv(run_dir / "authority_bound_operator_minimal_slice_template_rows.csv", list(minimal_slice_template_rows[0].keys()), minimal_slice_template_rows)

content_witness_manifest_rows = [
    {"witness_id": "review_comment_sha256", "required_filename": "review_comment.txt", "csv_sha_field": "review_comment_sha256", "csv_path_field": "review_comment_content_path", "purpose": "external reviewer source/citation/policy review comment witness"},
    {"witness_id": "adjudication_reason_sha256", "required_filename": "adjudication_reason.txt", "csv_sha_field": "adjudication_reason_sha256", "csv_path_field": "adjudication_reason_content_path", "purpose": "external adjudicator acceptance reason witness"},
    {"witness_id": "credential_statement_sha256", "required_filename": "credential_statement.txt", "csv_sha_field": "credential_statement_sha256", "csv_path_field": "credential_statement_content_path", "purpose": "external reviewer credential/scope witness"},
    {"witness_id": "conflict_statement_sha256", "required_filename": "conflict_statement.txt", "csv_sha_field": "conflict_statement_sha256", "csv_path_field": "conflict_statement_content_path", "purpose": "external reviewer conflict disclosure witness"},
    {"witness_id": "answer_text_sha256", "required_filename": "answer_text.txt", "csv_sha_field": "answer_text_sha256", "csv_path_field": "answer_text_content_path", "purpose": "real generation answer text witness"},
    {"witness_id": "run_transcript_sha256", "required_filename": "run_transcript.txt", "csv_sha_field": "run_transcript_sha256", "csv_path_field": "run_transcript_content_path", "purpose": "real generation run transcript/timing witness"},
    {"witness_id": "source_file_sha256", "required_filename": "source_file.txt", "csv_sha_field": "source_file_sha256", "csv_path_field": "source_file_content_path", "purpose": "real cited source file witness"},
]
write_csv(run_dir / "authority_bound_operator_content_witness_manifest_rows.csv", list(content_witness_manifest_rows[0].keys()), content_witness_manifest_rows)

minimal_slice_context_json = scaffold_dir / "MINIMAL_SLICE_SELECTED_CONTEXT.json"
minimal_slice_context_md = scaffold_dir / "MINIMAL_SLICE_SELECTED_CONTEXT.md"
minimal_slice_context_payload = {
    "context_protocol_version": "v61gi-minimal-slice-selected-context-v1",
    "counts_as_evidence": 0,
    "selected_slice_ids": {
        "v53": "v53-partial-review-slice",
        "v61": "v61-partial-generation-slice",
    },
    "v53_selected_review_slice": v53_selected,
    "v61_selected_generation_slice": v61_selected,
    "required_witness_files": [row["required_filename"] for row in content_witness_manifest_rows],
    "operator_final_command": "RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh",
}
minimal_slice_context_json.write_text(
    json.dumps(minimal_slice_context_payload, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
minimal_slice_context_md.write_text(
    "\n".join([
        "# v61gi Minimal Slice Selected Context",
        "",
        "This context file is an operator guide only. It does not count as external review, adjudication, generation, latency, quality, comparison, or release evidence.",
        "",
        "v53 selected review slice:",
        "",
        f"- slice_id={v53_selected['slice_id']}",
        f"- review_answer_packet_id={v53_selected['review_answer_packet_id']}",
        f"- answer_id={v53_selected['answer_id']}",
        f"- system_id={v53_selected['system_id']}",
        f"- query_id={v53_selected['query_id']}",
        f"- assignment_id={v53_selected['assignment_id']}",
        f"- reviewer_slot_id={v53_selected['reviewer_slot_id']}",
        f"- owner_repo={v53_selected['owner_repo']}",
        "",
        "v61 selected generation slice:",
        "",
        f"- slice_id={v61_selected['slice_id']}",
        f"- query_id={v61_selected['query_id']}",
        f"- source_span_id={v61_selected['source_span_id']}",
        f"- review_query_packet_id={v61_selected.get('review_query_packet_id', '')}",
        "",
        "Required witness filenames:",
        "",
        *[f"- `{row['required_filename']}`: {row['purpose']}" for row in content_witness_manifest_rows],
        "",
        "Final operator command:",
        "",
        "`RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh`",
        "",
    ]),
    encoding="utf-8",
)
minimal_slice_context_rows = [
    {
        "context_file": minimal_slice_context_json.name,
        "bytes": str(minimal_slice_context_json.stat().st_size),
        "sha256": sha256(minimal_slice_context_json),
        "counts_as_evidence": "0",
    },
    {
        "context_file": minimal_slice_context_md.name,
        "bytes": str(minimal_slice_context_md.stat().st_size),
        "sha256": sha256(minimal_slice_context_md),
        "counts_as_evidence": "0",
    },
]
write_csv(run_dir / "authority_bound_operator_minimal_slice_context_rows.csv", list(minimal_slice_context_rows[0].keys()), minimal_slice_context_rows)

review_worksheet_json = scaffold_dir / "MINIMAL_SLICE_REVIEW_WORKSHEET.json"
review_worksheet_md = scaffold_dir / "MINIMAL_SLICE_REVIEW_WORKSHEET.md"
review_worksheet_payload = {
    "worksheet_protocol_version": "v61gi-minimal-slice-review-worksheet-v1",
    "counts_as_evidence": 0,
    "selected_query_row": selected_query_row,
    "selected_source_span_row": selected_span_row,
    "selected_answer_row": selected_answer_row,
    "selected_citation_row": selected_citation_row,
    "selected_resource_row": selected_resource_row,
    "required_witness_files": {
        "review_comment.txt": "external reviewer decision notes over selected answer/citation/source",
        "adjudication_reason.txt": "external adjudicator reason over selected review row",
        "answer_text.txt": "real generation answer text witness for the selected v61 query",
        "source_file.txt": "source file content witness for the selected citation/source span",
    },
}
review_worksheet_json.write_text(
    json.dumps(review_worksheet_payload, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
review_worksheet_md.write_text(
    "\n".join([
        "# v61gi Minimal Slice Review Worksheet",
        "",
        "This worksheet is an operator guide only. It does not count as external review, adjudication, generation, latency, quality, comparison, or release evidence.",
        "",
        "Selected query:",
        "",
        f"- query_id={selected_query_row['query_id']}",
        f"- owner_repo={selected_query_row['owner_repo']}",
        f"- audit_type={selected_query_row['audit_type']}",
        f"- question={selected_query_row['question']}",
        f"- expected_behavior={selected_query_row['expected_behavior']}",
        f"- expected_answer={selected_query_row['expected_answer']}",
        "",
        "Selected source span:",
        "",
        f"- source_span_id={selected_span_row['source_span_id']}",
        f"- path={selected_span_row['path']}",
        f"- line_start={selected_span_row['line_start']}",
        f"- line_end={selected_span_row['line_end']}",
        f"- evidence_text={selected_span_row['evidence_text']}",
        f"- source_file_sha256={selected_span_row['source_file_sha256']}",
        f"- local_relpath={selected_span_row['local_relpath']}",
        "",
        "Selected existing machine answer for external review:",
        "",
        f"- answer_id={selected_answer_row['answer_id']}",
        f"- system_id={selected_answer_row['system_id']}",
        f"- answer_text={selected_answer_row['answer_text']}",
        f"- answer_text_sha256={selected_answer_row['answer_text_sha256']}",
        f"- strict_expected_answer_match={selected_answer_row['strict_expected_answer_match']}",
        "",
        "Selected citation:",
        "",
        f"- citation_id={selected_citation_row['citation_id']}",
        f"- citation_text={selected_citation_row['citation_text']}",
        f"- path={selected_citation_row['path']}",
        f"- line_start={selected_citation_row['line_start']}",
        f"- line_end={selected_citation_row['line_end']}",
        "",
        "Selected resource row:",
        "",
        f"- resource_row_id={selected_resource_row['resource_row_id']}",
        f"- model_name={selected_resource_row['model_name']}",
        f"- latency_ms={selected_resource_row['latency_ms']}",
        f"- external_network_used={selected_resource_row['external_network_used']}",
        "",
        "Write final witness files under `V61GI_CONTENT_WITNESS_DIR`, then run `RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh`.",
        "",
    ]),
    encoding="utf-8",
)
review_worksheet_rows = [
    {
        "worksheet_file": review_worksheet_json.name,
        "bytes": str(review_worksheet_json.stat().st_size),
        "sha256": sha256(review_worksheet_json),
        "counts_as_evidence": "0",
    },
    {
        "worksheet_file": review_worksheet_md.name,
        "bytes": str(review_worksheet_md.stat().st_size),
        "sha256": sha256(review_worksheet_md),
        "counts_as_evidence": "0",
    },
]
write_csv(run_dir / "authority_bound_operator_minimal_slice_review_worksheet_rows.csv", list(review_worksheet_rows[0].keys()), review_worksheet_rows)

env_template = scaffold_dir / "MINIMAL_SLICE_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "# Fill these values with real external operator evidence before running the builder.",
        "export V61GI_CONTENT_WITNESS_DIR=/path/to/content_witness_dir",
        "export V61GI_MINIMAL_SLICE_PRECHECK_CSV=/path/to/MINIMAL_SLICE_PRECHECK_ROWS.csv",
        "export V61GI_MINIMAL_SLICE_ROWS_CSV=/path/to/MINIMAL_SLICE_ROWS.csv",
        "export V61GI_REVIEWER_ID=REPLACE_WITH_EXTERNAL_REVIEWER_ID",
        "export V61GI_ADJUDICATOR_ID=REPLACE_WITH_EXTERNAL_ADJUDICATOR_ID",
        "export V61GI_GENERATION_ID=REPLACE_WITH_REAL_GENERATION_ID",
        "export V61GI_CITATION_ID=REPLACE_WITH_REAL_CITATION_ID",
        "export V61GI_MODEL_ID=mistralai/Mixtral-8x22B-v0.1",
        "export V61GI_CHECKPOINT_ROOT=/path/to/external/checkpoint/root",
        "export V61GI_LATENCY_ROW_ID=REPLACE_WITH_REAL_LATENCY_ROW_ID",
        "export V61GI_PROMPT_TOKENS=REPLACE_WITH_POSITIVE_PROMPT_TOKEN_COUNT",
        "export V61GI_OUTPUT_TOKENS=REPLACE_WITH_POSITIVE_OUTPUT_TOKEN_COUNT",
        "export V61GI_PREFILL_MS=REPLACE_WITH_POSITIVE_PREFILL_MS",
        "export V61GI_DECODE_MS=REPLACE_WITH_POSITIVE_DECODE_MS",
        "export V61GI_TOTAL_MS=REPLACE_WITH_POSITIVE_TOTAL_MS",
        "export V61GI_TOKENS_PER_SECOND=REPLACE_WITH_POSITIVE_TOKENS_PER_SECOND",
        "export V61GI_V53_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_EXTERNAL_REVIEWER_AUTHORITY_STATEMENT'",
        "export V61GI_V61_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_EXTERNAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT'",
        "export V61GI_EXTERNAL_RETURN_ATTESTATION='REPLACE_WITH_FINAL_EXTERNAL_RETURN_ATTESTATION'",
        "export V61GI_OPERATOR_INPUT_ROOT=/path/to/empty_external_operator_input_root",
        "export V61GI_OUTPUT_ROOT=/path/to/external_assembled_output_root",
        "export V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_ASSEMBLY_AUTHORITY_STATEMENT'",
        "",
    ]),
    encoding="utf-8",
)
env_template.chmod(0o755)

operator_readme = scaffold_dir / "MINIMAL_SLICE_OPERATOR_README.md"
operator_readme.write_text(
    "\n".join([
        "# v61gi Minimal Slice Operator Input",
        "",
        "Review `MINIMAL_SLICE_SELECTED_CONTEXT.md` and `MINIMAL_SLICE_REVIEW_WORKSHEET.md` before creating witness files.",
        "",
        "Required witness filenames under `V61GI_CONTENT_WITNESS_DIR`:",
        "",
        "- `review_comment.txt`",
        "- `adjudication_reason.txt`",
        "- `credential_statement.txt`",
        "- `conflict_statement.txt`",
        "- `answer_text.txt`",
        "- `run_transcript.txt`",
        "- `source_file.txt`",
        "",
        "Run order:",
        "",
        "1. Fill `MINIMAL_SLICE_ENV_TEMPLATE.sh` with real external operator values.",
        "2. Run `CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py` to check env and witness readiness without creating evidence rows.",
        "3. Run `RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh` to precheck and hash witness files into a one-row CSV.",
        "4. Run `RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh` with external input/output roots.",
        "",
        "This package is still zero-evidence until those external files are supplied.",
        "",
    ]),
    encoding="utf-8",
)

verifier = scaffold_dir / "VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py"
verifier.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, os, sys",
        "from pathlib import Path",
        "",
        "INPUT_ROOT = Path(os.environ.get('V61GI_OPERATOR_INPUT_ROOT', '')).expanduser()",
        "if not str(INPUT_ROOT) or not INPUT_ROOT.is_dir():",
        "    raise SystemExit('set V61GI_OPERATOR_INPUT_ROOT to a populated operator input root')",
        f"required = {json.dumps(['OPERATOR_INPUT_RECEIPT.json'] + [row['final_relative_path'] for row in operator_input_rows], indent=2)}",
        "errors = []",
        "for rel in required:",
        "    path = INPUT_ROOT / rel",
        "    if not path.is_file():",
        "        errors.append(f'missing:{rel}')",
        "        continue",
        "    if path.name.endswith('.template') or path.stat().st_size == 0:",
        "        errors.append(f'not-final:{rel}')",
        "        continue",
        "    text = path.read_text(encoding='utf-8', errors='replace')",
        "    if 'REPLACE_WITH' in text or 'template' in text.lower() or 'fixture' in text.lower():",
        "        errors.append(f'placeholder-or-fixture-text:{rel}')",
        "if errors:",
        "    raise SystemExit(';'.join(errors))",
        "print('operator input root preflight passed')",
        "",
    ]),
    encoding="utf-8",
)
verifier.chmod(0o755)

receipt_builder = scaffold_dir / "BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py"
receipt_builder.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import hashlib, json, os, sys",
        "from datetime import datetime, timezone",
        "from pathlib import Path",
        "",
        "INPUT_ROOT = Path(os.environ.get('V61GI_OPERATOR_INPUT_ROOT', '')).expanduser()",
        "SOURCE_CLASS = os.environ.get('V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS', '').strip()",
        "ATTESTATION = os.environ.get('V61GI_OPERATOR_INPUT_RECEIPT_ATTESTATION', '').strip()",
        "ASSEMBLY_AUTHORITY = os.environ.get('V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY', 'preflight-only').strip()",
        "ASSEMBLY_AUTHORITY_STATEMENT = os.environ.get('V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT', '').strip()",
        "ROOT_ID = os.environ.get('V61GI_OPERATOR_INPUT_ROOT_ID', '').strip()",
        "OVERWRITE = os.environ.get('V61GI_OPERATOR_INPUT_RECEIPT_OVERWRITE', '0') == '1'",
        "ALLOWED_SOURCE_CLASSES = {'real-authority-bound-partial-return', 'real-external-review-and-generation-return'}",
        "NONFINAL_TOKENS = ['replace_with', 'template', 'fixture', 'synthetic', 'dry run', 'sample', 'example']",
        f"required = {json.dumps([row['final_relative_path'] for row in operator_input_rows], indent=2)}",
        "WITNESS_RELS = {",
        "    'review_comment_sha256': 'operator_content_witness/review_comment.txt',",
        "    'adjudication_reason_sha256': 'operator_content_witness/adjudication_reason.txt',",
        "    'credential_statement_sha256': 'operator_content_witness/credential_statement.txt',",
        "    'conflict_statement_sha256': 'operator_content_witness/conflict_statement.txt',",
        "    'answer_text_sha256': 'operator_content_witness/answer_text.txt',",
        "    'run_transcript_sha256': 'operator_content_witness/run_transcript.txt',",
        "    'source_file_sha256': 'operator_content_witness/source_file.txt',",
        "}",
        "",
        "def sha256(path):",
        "    h = hashlib.sha256()",
        "    with path.open('rb') as handle:",
        "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "            h.update(chunk)",
        "    return 'sha256:' + h.hexdigest()",
        "",
        "def has_nonfinal_text(value):",
        "    lowered = value.lower()",
        "    return any(token in lowered for token in NONFINAL_TOKENS)",
        "",
        "errors = []",
        "if not str(INPUT_ROOT) or not INPUT_ROOT.is_dir():",
        "    errors.append('input-root-missing')",
        "if SOURCE_CLASS not in ALLOWED_SOURCE_CLASSES:",
        "    errors.append('source-class-not-accepted')",
        "if len(ATTESTATION) < 40:",
        "    errors.append('external-return-attestation-too-short')",
        "if has_nonfinal_text(SOURCE_CLASS) or has_nonfinal_text(ATTESTATION) or has_nonfinal_text(ROOT_ID):",
        "    errors.append('receipt-nonfinal-text')",
        "if ASSEMBLY_AUTHORITY == 'operator-final-real-return' and len(ASSEMBLY_AUTHORITY_STATEMENT) < 40:",
        "    errors.append('assembly-authority-statement-too-short')",
        "if has_nonfinal_text(ASSEMBLY_AUTHORITY) or has_nonfinal_text(ASSEMBLY_AUTHORITY_STATEMENT):",
        "    errors.append('assembly-authority-nonfinal-text')",
        "if errors:",
        "    raise SystemExit(';'.join(errors))",
        "",
        "artifact_hashes = {}",
        "for rel in required:",
        "    path = INPUT_ROOT / rel",
        "    if not path.is_file():",
        "        errors.append(f'missing:{rel}')",
        "        continue",
        "    if path.name.endswith('.template') or path.stat().st_size == 0:",
        "        errors.append(f'not-final:{rel}')",
        "        continue",
        "    text = path.read_text(encoding='utf-8', errors='replace')",
        "    lowered = text.lower()",
        "    if 'REPLACE_WITH' in text or 'template' in lowered or 'fixture' in lowered:",
        "        errors.append(f'placeholder-or-fixture-text:{rel}')",
        "        continue",
        "    artifact_hashes[rel] = sha256(path)",
        "content_witness_hashes = {}",
        "content_witness_files = {}",
        "for witness_id, rel in WITNESS_RELS.items():",
        "    path = INPUT_ROOT / rel",
        "    if not path.is_file():",
        "        if ASSEMBLY_AUTHORITY == 'operator-final-real-return':",
        "            errors.append(f'missing-content-witness:{witness_id}')",
        "        continue",
        "    if path.stat().st_size == 0:",
        "        errors.append(f'empty-content-witness:{witness_id}')",
        "        continue",
        "    content_witness_files[witness_id] = rel",
        "    content_witness_hashes[witness_id] = sha256(path)",
        "if errors:",
        "    raise SystemExit(';'.join(errors))",
        "",
        "receipt_path = INPUT_ROOT / 'OPERATOR_INPUT_RECEIPT.json'",
        "if receipt_path.exists() and not OVERWRITE:",
        "    raise SystemExit('receipt-exists:set V61GI_OPERATOR_INPUT_RECEIPT_OVERWRITE=1 to replace')",
        "payload = {",
        "    'receipt_protocol_version': 'v61gj-operator-input-receipt-v1',",
        "    'source_class': SOURCE_CLASS,",
        "    'finalized': True,",
        "    'created_at_utc': datetime.now(timezone.utc).isoformat(),",
        "    'operator_input_root_id': ROOT_ID or INPUT_ROOT.name,",
        "    'declared_artifact_count': len(required),",
        "    'selected_slice_ids': {",
        "        'v53': 'v53-partial-review-slice',",
        "        'v61': 'v61-partial-generation-slice',",
        "    },",
        "    'artifact_hashes': artifact_hashes,",
        "    'content_witness_files': content_witness_files,",
        "    'content_witness_hashes': content_witness_hashes,",
        "    'external_return_attestation': ATTESTATION,",
        "    'assembly_authority': ASSEMBLY_AUTHORITY,",
        "    'assembly_authority_statement': ASSEMBLY_AUTHORITY_STATEMENT,",
        "}",
        "receipt_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "print(f'wrote {receipt_path}')",
        "",
    ]),
    encoding="utf-8",
)
receipt_builder.chmod(0o755)

minimal_slice_precheck = scaffold_dir / "CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py"
minimal_slice_precheck.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, hashlib, os, sys",
        "from pathlib import Path",
        "",
        "NONFINAL_TOKENS = ['replace_with', 'template', 'fixture', 'synthetic', 'dry run', 'sample', 'example']",
        "WITNESSES = {",
        "    'review_comment_sha256': ('review_comment.txt', 'review_comment_content_path'),",
        "    'adjudication_reason_sha256': ('adjudication_reason.txt', 'adjudication_reason_content_path'),",
        "    'credential_statement_sha256': ('credential_statement.txt', 'credential_statement_content_path'),",
        "    'conflict_statement_sha256': ('conflict_statement.txt', 'conflict_statement_content_path'),",
        "    'answer_text_sha256': ('answer_text.txt', 'answer_text_content_path'),",
        "    'run_transcript_sha256': ('run_transcript.txt', 'run_transcript_content_path'),",
        "    'source_file_sha256': ('source_file.txt', 'source_file_content_path'),",
        "}",
        "ENV_FIELDS = {",
        "    'reviewer_id': 'V61GI_REVIEWER_ID',",
        "    'adjudicator_id': 'V61GI_ADJUDICATOR_ID',",
        "    'generation_id': 'V61GI_GENERATION_ID',",
        "    'citation_id': 'V61GI_CITATION_ID',",
        "    'checkpoint_root': 'V61GI_CHECKPOINT_ROOT',",
        "    'latency_row_id': 'V61GI_LATENCY_ROW_ID',",
        "    'prompt_tokens': 'V61GI_PROMPT_TOKENS',",
        "    'output_tokens': 'V61GI_OUTPUT_TOKENS',",
        "    'prefill_ms': 'V61GI_PREFILL_MS',",
        "    'decode_ms': 'V61GI_DECODE_MS',",
        "    'total_ms': 'V61GI_TOTAL_MS',",
        "    'tokens_per_second': 'V61GI_TOKENS_PER_SECOND',",
        "    'v53_authority_statement': 'V61GI_V53_AUTHORITY_STATEMENT',",
        "    'v61_authority_statement': 'V61GI_V61_AUTHORITY_STATEMENT',",
        "    'external_return_attestation': 'V61GI_EXTERNAL_RETURN_ATTESTATION',",
        "}",
        "NUMERIC_ENV = {",
        "    'V61GI_PROMPT_TOKENS',",
        "    'V61GI_OUTPUT_TOKENS',",
        "    'V61GI_PREFILL_MS',",
        "    'V61GI_DECODE_MS',",
        "    'V61GI_TOTAL_MS',",
        "    'V61GI_TOKENS_PER_SECOND',",
        "}",
        "MIN_LENGTH_ENV = {",
        "    'V61GI_V53_AUTHORITY_STATEMENT': 40,",
        "    'V61GI_V61_AUTHORITY_STATEMENT': 40,",
        "    'V61GI_EXTERNAL_RETURN_ATTESTATION': 40,",
        "}",
        "FIELDNAMES = ['check_id', 'status', 'evidence']",
        "",
        "def sha256(path):",
        "    h = hashlib.sha256()",
        "    with path.open('rb') as handle:",
        "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "            h.update(chunk)",
        "    return 'sha256:' + h.hexdigest()",
        "",
        "def has_nonfinal_text(value):",
        "    lowered = str(value).lower()",
        "    return any(token in lowered for token in NONFINAL_TOKENS)",
        "",
        "rows = []",
        "values = {}",
        "",
        "def add(check_id, status, evidence):",
        "    rows.append({'check_id': check_id, 'status': status, 'evidence': evidence})",
        "",
        "def env_value(env_name):",
        "    return os.environ.get(env_name, '').strip()",
        "",
        "witness_dir_raw = env_value('V61GI_CONTENT_WITNESS_DIR')",
        "witness_dir = None",
        "if not witness_dir_raw:",
        "    add('content-witness-dir', 'blocked', 'missing-env:V61GI_CONTENT_WITNESS_DIR')",
        "else:",
        "    witness_dir = Path(witness_dir_raw).expanduser()",
        "    if not witness_dir.is_dir():",
        "        add('content-witness-dir', 'blocked', 'missing-dir:V61GI_CONTENT_WITNESS_DIR')",
        "        witness_dir = None",
        "    else:",
        "        add('content-witness-dir', 'pass', f'path={witness_dir.resolve()}')",
        "",
        "output_csv_raw = env_value('V61GI_MINIMAL_SLICE_ROWS_CSV')",
        "if not output_csv_raw:",
        "    add('minimal-slice-output-csv', 'blocked', 'missing-env:V61GI_MINIMAL_SLICE_ROWS_CSV')",
        "else:",
        "    output_csv = Path(output_csv_raw).expanduser()",
        "    if output_csv.exists() and os.environ.get('V61GI_MINIMAL_SLICE_ROWS_OVERWRITE', '0') != '1':",
        "        add('minimal-slice-output-csv', 'blocked', 'minimal-slice-csv-exists:set V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 to replace')",
        "    else:",
        "        add('minimal-slice-output-csv', 'pass', f'path={output_csv}')",
        "",
        "model_id = os.environ.get('V61GI_MODEL_ID', 'mistralai/Mixtral-8x22B-v0.1').strip()",
        "if not model_id:",
        "    add('model-id', 'blocked', 'missing-env:V61GI_MODEL_ID')",
        "elif has_nonfinal_text(model_id):",
        "    add('model-id', 'blocked', 'nonfinal-env:V61GI_MODEL_ID')",
        "else:",
        "    add('model-id', 'pass', f'model_id={model_id}')",
        "",
        "for field_name, env_name in ENV_FIELDS.items():",
        "    value = env_value(env_name)",
        "    values[env_name] = value",
        "    if not value:",
        "        add(f'env:{env_name}', 'blocked', f'missing-env:{env_name}')",
        "        continue",
        "    if has_nonfinal_text(value):",
        "        add(f'env:{env_name}', 'blocked', f'nonfinal-env:{env_name}')",
        "        continue",
        "    min_len = MIN_LENGTH_ENV.get(env_name, 1)",
        "    if len(value) < min_len:",
        "        add(f'env:{env_name}', 'blocked', f'too-short-env:{env_name}')",
        "        continue",
        "    if env_name in NUMERIC_ENV:",
        "        try:",
        "            numeric = float(value)",
        "        except ValueError:",
        "            add(f'env:{env_name}', 'blocked', f'invalid-positive-number:{env_name}')",
        "            continue",
        "        if numeric <= 0:",
        "            add(f'env:{env_name}', 'blocked', f'invalid-positive-number:{env_name}')",
        "            continue",
        "    add(f'env:{env_name}', 'pass', f'{field_name}=supplied')",
        "",
        "if witness_dir is not None:",
        "    for sha_field, (filename, path_field) in WITNESSES.items():",
        "        path = witness_dir / filename",
        "        if not path.is_file():",
        "            add(f'witness:{filename}', 'blocked', f'missing-content-witness:{filename}')",
        "            continue",
        "        if path.stat().st_size == 0:",
        "            add(f'witness:{filename}', 'blocked', f'empty-content-witness:{filename}')",
        "            continue",
        "        add(f'witness:{filename}', 'pass', f'{sha_field}={sha256(path)};{path_field}={path.resolve()}')",
        "else:",
        "    for sha_field, (filename, path_field) in WITNESSES.items():",
        "        add(f'witness:{filename}', 'blocked', f'missing-content-witness-dir:{filename}')",
        "",
        "def write_rows(handle):",
        "    writer = csv.DictWriter(handle, fieldnames=FIELDNAMES, lineterminator='\\n')",
        "    writer.writeheader()",
        "    writer.writerows(rows)",
        "",
        "report_csv_raw = env_value('V61GI_MINIMAL_SLICE_PRECHECK_CSV')",
        "if report_csv_raw:",
        "    report_csv = Path(report_csv_raw).expanduser()",
        "    report_csv.parent.mkdir(parents=True, exist_ok=True)",
        "    with report_csv.open('w', newline='', encoding='utf-8') as handle:",
        "        write_rows(handle)",
        "write_rows(sys.stdout)",
        "blocked = [row for row in rows if row['status'] != 'pass']",
        "if blocked:",
        "    raise SystemExit('minimal-slice-precheck-blocked:' + ';'.join(row['evidence'] for row in blocked))",
        "",
    ]),
    encoding="utf-8",
)
minimal_slice_precheck.chmod(0o755)

minimal_slice_builder = scaffold_dir / "BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py"
minimal_slice_builder.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, hashlib, os, sys",
        "from pathlib import Path",
        "",
        "WITNESS_DIR_RAW = os.environ.get('V61GI_CONTENT_WITNESS_DIR', '').strip()",
        "OUTPUT_CSV_RAW = os.environ.get('V61GI_MINIMAL_SLICE_ROWS_CSV', '').strip()",
        "OVERWRITE = os.environ.get('V61GI_MINIMAL_SLICE_ROWS_OVERWRITE', '0') == '1'",
        "NONFINAL_TOKENS = ['replace_with', 'template', 'fixture', 'synthetic', 'dry run', 'sample', 'example']",
        f"FIELDNAMES = {json.dumps(minimal_slice_template_fields, indent=2)}",
        "WITNESSES = {",
        "    'review_comment_sha256': ('review_comment.txt', 'review_comment_content_path'),",
        "    'adjudication_reason_sha256': ('adjudication_reason.txt', 'adjudication_reason_content_path'),",
        "    'credential_statement_sha256': ('credential_statement.txt', 'credential_statement_content_path'),",
        "    'conflict_statement_sha256': ('conflict_statement.txt', 'conflict_statement_content_path'),",
        "    'answer_text_sha256': ('answer_text.txt', 'answer_text_content_path'),",
        "    'run_transcript_sha256': ('run_transcript.txt', 'run_transcript_content_path'),",
        "    'source_file_sha256': ('source_file.txt', 'source_file_content_path'),",
        "}",
        "ENV_FIELDS = {",
        "    'reviewer_id': 'V61GI_REVIEWER_ID',",
        "    'adjudicator_id': 'V61GI_ADJUDICATOR_ID',",
        "    'generation_id': 'V61GI_GENERATION_ID',",
        "    'citation_id': 'V61GI_CITATION_ID',",
        "    'checkpoint_root': 'V61GI_CHECKPOINT_ROOT',",
        "    'latency_row_id': 'V61GI_LATENCY_ROW_ID',",
        "    'prompt_tokens': 'V61GI_PROMPT_TOKENS',",
        "    'output_tokens': 'V61GI_OUTPUT_TOKENS',",
        "    'prefill_ms': 'V61GI_PREFILL_MS',",
        "    'decode_ms': 'V61GI_DECODE_MS',",
        "    'total_ms': 'V61GI_TOTAL_MS',",
        "    'tokens_per_second': 'V61GI_TOKENS_PER_SECOND',",
        "    'v53_authority_statement': 'V61GI_V53_AUTHORITY_STATEMENT',",
        "    'v61_authority_statement': 'V61GI_V61_AUTHORITY_STATEMENT',",
        "    'external_return_attestation': 'V61GI_EXTERNAL_RETURN_ATTESTATION',",
        "}",
        "",
        "def sha256(path):",
        "    h = hashlib.sha256()",
        "    with path.open('rb') as handle:",
        "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "            h.update(chunk)",
        "    return 'sha256:' + h.hexdigest()",
        "",
        "def has_nonfinal_text(value):",
        "    lowered = str(value).lower()",
        "    return any(token in lowered for token in NONFINAL_TOKENS)",
        "",
        "def require_env(env_name, field_name):",
        "    value = os.environ.get(env_name, '').strip()",
        "    if not value:",
        "        raise SystemExit(f'missing-env:{env_name}')",
        "    if has_nonfinal_text(value):",
        "        raise SystemExit(f'nonfinal-env:{env_name}')",
        "    return value",
        "",
        "def require_positive_number(value, field_name):",
        "    try:",
        "        if float(value) <= 0:",
        "            raise ValueError",
        "    except ValueError:",
        "        raise SystemExit(f'invalid-positive-number:{field_name}')",
        "",
        "if not WITNESS_DIR_RAW:",
        "    raise SystemExit('set V61GI_CONTENT_WITNESS_DIR to a directory with witness files')",
        "if not OUTPUT_CSV_RAW:",
        "    raise SystemExit('set V61GI_MINIMAL_SLICE_ROWS_CSV to the output CSV path')",
        "WITNESS_DIR = Path(WITNESS_DIR_RAW).expanduser()",
        "OUTPUT_CSV = Path(OUTPUT_CSV_RAW).expanduser()",
        "if not WITNESS_DIR.is_dir():",
        "    raise SystemExit('set V61GI_CONTENT_WITNESS_DIR to a directory with witness files')",
        "if OUTPUT_CSV.exists() and not OVERWRITE:",
        "    raise SystemExit('minimal-slice-csv-exists:set V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 to replace')",
        "",
        "row = {'model_id': os.environ.get('V61GI_MODEL_ID', 'mistralai/Mixtral-8x22B-v0.1').strip()}",
        "if not row['model_id'] or has_nonfinal_text(row['model_id']):",
        "    raise SystemExit('invalid-model-id')",
        "for field_name, env_name in ENV_FIELDS.items():",
        "    row[field_name] = require_env(env_name, field_name)",
        "for field_name in ['prompt_tokens', 'output_tokens', 'prefill_ms', 'decode_ms', 'total_ms', 'tokens_per_second']:",
        "    require_positive_number(row[field_name], field_name)",
        "if len(row['v53_authority_statement']) < 40 or len(row['v61_authority_statement']) < 40:",
        "    raise SystemExit('authority-statement-too-short')",
        "if len(row['external_return_attestation']) < 40:",
        "    raise SystemExit('external-return-attestation-too-short')",
        "",
        "for sha_field, (filename, path_field) in WITNESSES.items():",
        "    path = WITNESS_DIR / filename",
        "    if not path.is_file():",
        "        raise SystemExit(f'missing-content-witness:{filename}')",
        "    if path.stat().st_size == 0:",
        "        raise SystemExit(f'empty-content-witness:{filename}')",
        "    row[sha_field] = sha256(path)",
        "    row[path_field] = str(path.resolve())",
        "",
        "OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)",
        "with OUTPUT_CSV.open('w', newline='', encoding='utf-8') as handle:",
        "    writer = csv.DictWriter(handle, fieldnames=FIELDNAMES, lineterminator='\\n')",
        "    writer.writeheader()",
        "    writer.writerow(row)",
        "print(f'wrote {OUTPUT_CSV}')",
        "",
    ]),
    encoding="utf-8",
)
minimal_slice_builder.chmod(0o755)

(scaffold_dir / "RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "PRECHECK_CSV=\"${V61GI_MINIMAL_SLICE_PRECHECK_CSV:-}\"",
        "if [[ -z \"$PRECHECK_CSV\" && -n \"${V61GI_MINIMAL_SLICE_ROWS_CSV:-}\" ]]; then",
        "  PRECHECK_CSV=\"${V61GI_MINIMAL_SLICE_ROWS_CSV}.precheck.csv\"",
        "fi",
        "if [[ -n \"$PRECHECK_CSV\" ]]; then",
        "  export V61GI_MINIMAL_SLICE_PRECHECK_CSV=\"$PRECHECK_CSV\"",
        "fi",
        "\"$DIR/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py\" >/dev/null",
        "\"$DIR/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py\"",
        "if [[ -n \"$PRECHECK_CSV\" ]]; then",
        "  echo \"minimal slice precheck report: $PRECHECK_CSV\"",
        "fi",
        "echo \"minimal slice CSV: $V61GI_MINIMAL_SLICE_ROWS_CSV\"",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh").chmod(0o755)

materializer = scaffold_dir / "MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py"
materializer.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, hashlib, json, os, sys",
        "from datetime import datetime, timezone",
        "from pathlib import Path",
        "",
        "INPUT_CSV_RAW = os.environ.get('V61GI_MINIMAL_SLICE_ROWS_CSV', '').strip()",
        "OUTPUT_ROOT_RAW = os.environ.get('V61GI_OPERATOR_INPUT_ROOT', '').strip()",
        "SOURCE_CLASS = os.environ.get('V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS', 'real-authority-bound-partial-return').strip()",
        "ASSEMBLY_AUTHORITY = os.environ.get('V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY', 'preflight-only').strip()",
        "ASSEMBLY_AUTHORITY_STATEMENT = os.environ.get('V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT', '').strip()",
        "ROOT_ID = os.environ.get('V61GI_OPERATOR_INPUT_ROOT_ID', '').strip()",
        "ALLOWED_SOURCE_CLASSES = {'real-authority-bound-partial-return', 'real-external-review-and-generation-return'}",
        "NONFINAL_TOKENS = ['replace_with', 'template', 'fixture', 'synthetic', 'dry run', 'sample', 'example']",
        f"v53 = {json.dumps(v53_selected, sort_keys=True)}",
        f"v61 = {json.dumps(v61_selected, sort_keys=True)}",
        "",
        "REQUIRED_FIELDS = [",
        "    'reviewer_id', 'adjudicator_id', 'generation_id', 'citation_id',",
        "    'model_id', 'checkpoint_root', 'latency_row_id',",
        "    'review_comment_sha256', 'adjudication_reason_sha256',",
        "    'credential_statement_sha256', 'conflict_statement_sha256',",
        "    'answer_text_sha256', 'run_transcript_sha256', 'source_file_sha256',",
        "    'prompt_tokens', 'output_tokens', 'prefill_ms', 'decode_ms', 'total_ms', 'tokens_per_second',",
        "    'v53_authority_statement', 'v61_authority_statement', 'external_return_attestation',",
        "]",
        "SHA_FIELDS = [",
        "    'review_comment_sha256', 'adjudication_reason_sha256', 'credential_statement_sha256',",
        "    'conflict_statement_sha256', 'answer_text_sha256', 'run_transcript_sha256', 'source_file_sha256',",
        "]",
        "WITNESS_PATH_FIELDS = {",
        "    'review_comment_sha256': 'review_comment_content_path',",
        "    'adjudication_reason_sha256': 'adjudication_reason_content_path',",
        "    'credential_statement_sha256': 'credential_statement_content_path',",
        "    'conflict_statement_sha256': 'conflict_statement_content_path',",
        "    'answer_text_sha256': 'answer_text_content_path',",
        "    'run_transcript_sha256': 'run_transcript_content_path',",
        "    'source_file_sha256': 'source_file_content_path',",
        "}",
        "WITNESS_RELS = {",
        "    'review_comment_sha256': 'operator_content_witness/review_comment.txt',",
        "    'adjudication_reason_sha256': 'operator_content_witness/adjudication_reason.txt',",
        "    'credential_statement_sha256': 'operator_content_witness/credential_statement.txt',",
        "    'conflict_statement_sha256': 'operator_content_witness/conflict_statement.txt',",
        "    'answer_text_sha256': 'operator_content_witness/answer_text.txt',",
        "    'run_transcript_sha256': 'operator_content_witness/run_transcript.txt',",
        "    'source_file_sha256': 'operator_content_witness/source_file.txt',",
        "}",
        "FINAL_RELS = [",
        "    'v53/aggregate_review_return/human_review_rows.csv',",
        "    'v53/aggregate_review_return/adjudication_rows.csv',",
        "    'v53/aggregate_review_return/reviewer_identity_rows.csv',",
        "    'v53/aggregate_review_return/reviewer_conflict_rows.csv',",
        "    'v53/aggregate_review_return/acceptance_summary.json',",
        "    'v53/operator_attestation/reviewer_authority_statement.txt',",
        "    'v61/generation_result_return/real_model_generation_answer_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_citation_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_latency_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_acceptance_summary.json',",
        "    'v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt',",
        "]",
        "",
        "def sha256(path):",
        "    h = hashlib.sha256()",
        "    with path.open('rb') as handle:",
        "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "            h.update(chunk)",
        "    return 'sha256:' + h.hexdigest()",
        "",
        "def has_nonfinal_text(value):",
        "    lowered = str(value).lower()",
        "    return any(token in lowered for token in NONFINAL_TOKENS)",
        "",
        "def require_text(row, key):",
        "    value = (row.get(key, '') or '').strip()",
        "    if not value:",
        "        raise SystemExit(f'missing-field:{key}')",
        "    if has_nonfinal_text(value):",
        "        raise SystemExit(f'nonfinal-field:{key}')",
        "    return value",
        "",
        "def require_sha(row, key):",
        "    value = require_text(row, key)",
        "    if not (value.startswith('sha256:') and len(value) == 71 and all(c in '0123456789abcdef' for c in value[7:])):",
        "        raise SystemExit(f'invalid-sha:{key}')",
        "    return value",
        "",
        "def require_positive_number(row, key):",
        "    value = require_text(row, key)",
        "    try:",
        "        if float(value) <= 0:",
        "            raise ValueError",
        "    except ValueError:",
        "        raise SystemExit(f'invalid-positive-number:{key}')",
        "    return value",
        "",
        "def require_witness_file(row, sha_key):",
        "    path_key = WITNESS_PATH_FIELDS[sha_key]",
        "    raw_path = (row.get(path_key, '') or '').strip()",
        "    if not raw_path:",
        "        raise SystemExit(f'missing-field:{path_key}')",
        "    path = Path(raw_path).expanduser()",
        "    if not path.is_file():",
        "        raise SystemExit(f'missing-content-witness:{path_key}')",
        "    if path.stat().st_size == 0:",
        "        raise SystemExit(f'empty-content-witness:{path_key}')",
        "    expected_hash = require_sha(row, sha_key)",
        "    actual_hash = sha256(path)",
        "    if actual_hash != expected_hash:",
        "        raise SystemExit(f'content-witness-hash-mismatch:{sha_key}')",
        "    return path",
        "",
        "def write_csv_file(rel, fieldnames, rows):",
        "    path = OUTPUT_ROOT / rel",
        "    path.parent.mkdir(parents=True, exist_ok=True)",
        "    with path.open('w', newline='', encoding='utf-8') as handle:",
        "        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator='\\n')",
        "        writer.writeheader()",
        "        writer.writerows(rows)",
        "    return path",
        "",
        "if not INPUT_CSV_RAW:",
        "    raise SystemExit('set V61GI_MINIMAL_SLICE_ROWS_CSV to a one-row CSV')",
        "if not OUTPUT_ROOT_RAW:",
        "    raise SystemExit('set V61GI_OPERATOR_INPUT_ROOT to the output root')",
        "INPUT_CSV = Path(INPUT_CSV_RAW).expanduser()",
        "OUTPUT_ROOT = Path(OUTPUT_ROOT_RAW).expanduser()",
        "if not INPUT_CSV.is_file():",
        "    raise SystemExit('set V61GI_MINIMAL_SLICE_ROWS_CSV to a one-row CSV')",
        "if SOURCE_CLASS not in ALLOWED_SOURCE_CLASSES:",
        "    raise SystemExit('source-class-not-accepted')",
        "if has_nonfinal_text(ASSEMBLY_AUTHORITY) or has_nonfinal_text(ASSEMBLY_AUTHORITY_STATEMENT):",
        "    raise SystemExit('assembly-authority-nonfinal-text')",
        "if ASSEMBLY_AUTHORITY == 'operator-final-real-return' and len(ASSEMBLY_AUTHORITY_STATEMENT) < 40:",
        "    raise SystemExit('assembly-authority-statement-too-short')",
        "with INPUT_CSV.open(newline='', encoding='utf-8') as handle:",
        "    rows = list(csv.DictReader(handle))",
        "if len(rows) != 1:",
        "    raise SystemExit(f'minimal-slice-row-count:{len(rows)}')",
        "row = rows[0]",
        "missing = sorted(set(REQUIRED_FIELDS) - set(row))",
        "if missing:",
        "    raise SystemExit('missing-fields:' + ';'.join(missing))",
        "if OUTPUT_ROOT.exists() and any(OUTPUT_ROOT.iterdir()):",
        "    raise SystemExit('output-root-not-empty')",
        "OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)",
        "",
        "reviewer_id = require_text(row, 'reviewer_id')",
        "adjudicator_id = require_text(row, 'adjudicator_id')",
        "generation_id = require_text(row, 'generation_id')",
        "citation_id = require_text(row, 'citation_id')",
        "model_id = require_text(row, 'model_id')",
        "checkpoint_root = require_text(row, 'checkpoint_root')",
        "latency_row_id = require_text(row, 'latency_row_id')",
        "external_return_attestation = require_text(row, 'external_return_attestation')",
        "if len(external_return_attestation) < 40:",
        "    raise SystemExit('external-return-attestation-too-short')",
        "v53_authority_statement = require_text(row, 'v53_authority_statement')",
        "v61_authority_statement = require_text(row, 'v61_authority_statement')",
        "if len(v53_authority_statement) < 40 or len(v61_authority_statement) < 40:",
        "    raise SystemExit('authority-statement-too-short')",
        "for key in SHA_FIELDS:",
        "    require_sha(row, key)",
        "content_witness_sources = {}",
        "if ASSEMBLY_AUTHORITY == 'operator-final-real-return':",
        "    for key in SHA_FIELDS:",
        "        content_witness_sources[key] = require_witness_file(row, key)",
        "for key in ['prompt_tokens', 'output_tokens', 'prefill_ms', 'decode_ms', 'total_ms', 'tokens_per_second']:",
        "    require_positive_number(row, key)",
        "",
        "human = write_csv_file(",
        "    'v53/aggregate_review_return/human_review_rows.csv',",
        "    ['review_answer_packet_id', 'answer_id', 'system_id', 'query_id', 'reviewer_id', 'review_decision', 'source_support_verified', 'citation_verified', 'policy_verified', 'review_comment_sha256'],",
        "    [{'review_answer_packet_id': v53['review_answer_packet_id'], 'answer_id': v53['answer_id'], 'system_id': v53['system_id'], 'query_id': v53['query_id'], 'reviewer_id': reviewer_id, 'review_decision': 'accept', 'source_support_verified': '1', 'citation_verified': '1', 'policy_verified': '1', 'review_comment_sha256': row['review_comment_sha256']}],",
        ")",
        "adjudication = write_csv_file(",
        "    'v53/aggregate_review_return/adjudication_rows.csv',",
        "    ['adjudication_id', 'review_answer_packet_id', 'answer_id', 'adjudicator_id', 'adjudication_decision', 'adjudication_reason_sha256'],",
        "    [{'adjudication_id': 'adjudication-' + v53['answer_id'], 'review_answer_packet_id': v53['review_answer_packet_id'], 'answer_id': v53['answer_id'], 'adjudicator_id': adjudicator_id, 'adjudication_decision': 'accept', 'adjudication_reason_sha256': row['adjudication_reason_sha256']}],",
        ")",
        "identity = write_csv_file(",
        "    'v53/aggregate_review_return/reviewer_identity_rows.csv',",
        "    ['assignment_id', 'reviewer_id', 'reviewer_slot_id', 'system_id', 'review_scope', 'independence_declared', 'credential_statement_sha256'],",
        "    [{'assignment_id': v53['assignment_id'], 'reviewer_id': reviewer_id, 'reviewer_slot_id': v53['reviewer_slot_id'], 'system_id': v53['system_id'], 'review_scope': 'complete-source', 'independence_declared': '1', 'credential_statement_sha256': row['credential_statement_sha256']}],",
        ")",
        "conflict = write_csv_file(",
        "    'v53/aggregate_review_return/reviewer_conflict_rows.csv',",
        "    ['assignment_id', 'reviewer_id', 'owner_repo', 'conflict_declared', 'conflict_statement_sha256'],",
        "    [{'assignment_id': v53['assignment_id'], 'reviewer_id': reviewer_id, 'owner_repo': v53['owner_repo'], 'conflict_declared': '0', 'conflict_statement_sha256': row['conflict_statement_sha256']}],",
        ")",
        "(OUTPUT_ROOT / 'v53/operator_attestation').mkdir(parents=True, exist_ok=True)",
        "(OUTPUT_ROOT / 'v53/operator_attestation/reviewer_authority_statement.txt').write_text(v53_authority_statement + '\\n', encoding='utf-8')",
        "v53_summary = {",
        "    'review_protocol_version': 'v61gd-partial-v53-slice',",
        "    'acceptance_decision': 'accepted-partial-slice',",
        "    'slice_scope': 'partial',",
        "    'accepted_human_review_rows': 1, 'human_review_rows_sha256': sha256(human),",
        "    'accepted_adjudication_rows': 1, 'adjudication_rows_sha256': sha256(adjudication),",
        "    'accepted_reviewer_identity_rows': 1, 'reviewer_identity_rows_sha256': sha256(identity),",
        "    'accepted_conflict_disclosure_rows': 1, 'reviewer_conflict_rows_sha256': sha256(conflict),",
        "}",
        "(OUTPUT_ROOT / 'v53/aggregate_review_return/acceptance_summary.json').write_text(json.dumps(v53_summary, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "",
        "answer = write_csv_file(",
        "    'v61/generation_result_return/real_model_generation_answer_rows.csv',",
        "    ['generation_id', 'review_query_packet_id', 'query_id', 'source_span_id', 'model_id', 'checkpoint_root', 'answer_text_sha256', 'generation_status', 'abstain_decision', 'fallback_used', 'latency_row_id', 'run_transcript_sha256'],",
        "    [{'generation_id': generation_id, 'review_query_packet_id': v61.get('review_query_packet_id', ''), 'query_id': v61['query_id'], 'source_span_id': v61['source_span_id'], 'model_id': model_id, 'checkpoint_root': checkpoint_root, 'answer_text_sha256': row['answer_text_sha256'], 'generation_status': 'generated', 'abstain_decision': '0', 'fallback_used': '0', 'latency_row_id': latency_row_id, 'run_transcript_sha256': row['run_transcript_sha256']}],",
        ")",
        "citation = write_csv_file(",
        "    'v61/generation_result_return/real_model_generation_citation_rows.csv',",
        "    ['generation_id', 'query_id', 'citation_id', 'source_span_id', 'source_file_sha256', 'citation_verified'],",
        "    [{'generation_id': generation_id, 'query_id': v61['query_id'], 'citation_id': citation_id, 'source_span_id': v61['source_span_id'], 'source_file_sha256': row['source_file_sha256'], 'citation_verified': '1'}],",
        ")",
        "abstain = write_csv_file(",
        "    'v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv',",
        "    ['generation_id', 'query_id', 'expected_behavior', 'abstain_expected', 'abstain_observed', 'fallback_used', 'fallback_reason'],",
        "    [{'generation_id': generation_id, 'query_id': v61['query_id'], 'expected_behavior': 'source-bound-answer', 'abstain_expected': '0', 'abstain_observed': '0', 'fallback_used': '0', 'fallback_reason': ''}],",
        ")",
        "latency = write_csv_file(",
        "    'v61/generation_result_return/real_model_generation_latency_rows.csv',",
        "    ['generation_id', 'query_id', 'prompt_tokens', 'output_tokens', 'prefill_ms', 'decode_ms', 'total_ms', 'tokens_per_second'],",
        "    [{'generation_id': generation_id, 'query_id': v61['query_id'], 'prompt_tokens': row['prompt_tokens'], 'output_tokens': row['output_tokens'], 'prefill_ms': row['prefill_ms'], 'decode_ms': row['decode_ms'], 'total_ms': row['total_ms'], 'tokens_per_second': row['tokens_per_second']}],",
        ")",
        "(OUTPUT_ROOT / 'v61/review_return_provenance/operator_attestation').mkdir(parents=True, exist_ok=True)",
        "(OUTPUT_ROOT / 'v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt').write_text(v61_authority_statement + '\\n', encoding='utf-8')",
        "v61_summary = {",
        "    'generation_protocol_version': 'v61ge-partial-generation-slice',",
        "    'acceptance_decision': 'accepted-partial-slice',",
        "    'slice_scope': 'partial',",
        "    'accepted_answer_rows': 1, 'answer_rows_sha256': sha256(answer),",
        "    'accepted_citation_rows': 1, 'citation_rows_sha256': sha256(citation),",
        "    'accepted_abstain_fallback_rows': 1, 'abstain_fallback_rows_sha256': sha256(abstain),",
        "    'accepted_latency_rows': 1, 'latency_rows_sha256': sha256(latency),",
        "}",
        "(OUTPUT_ROOT / 'v61/generation_result_return/real_model_generation_acceptance_summary.json').write_text(json.dumps(v61_summary, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "",
        "content_witness_hashes = {}",
        "content_witness_files = {}",
        "for key, source_path in content_witness_sources.items():",
        "    rel = WITNESS_RELS[key]",
        "    dst = OUTPUT_ROOT / rel",
        "    dst.parent.mkdir(parents=True, exist_ok=True)",
        "    data = source_path.read_bytes()",
        "    dst.write_bytes(data)",
        "    content_witness_files[key] = rel",
        "    content_witness_hashes[key] = sha256(dst)",
        "artifact_hashes = {rel: sha256(OUTPUT_ROOT / rel) for rel in FINAL_RELS}",
        "receipt = {",
        "    'receipt_protocol_version': 'v61gj-operator-input-receipt-v1',",
        "    'source_class': SOURCE_CLASS,",
        "    'finalized': True,",
        "    'created_at_utc': datetime.now(timezone.utc).isoformat(),",
        "    'operator_input_root_id': ROOT_ID or OUTPUT_ROOT.name,",
        "    'declared_artifact_count': len(FINAL_RELS),",
        "    'selected_slice_ids': {'v53': 'v53-partial-review-slice', 'v61': 'v61-partial-generation-slice'},",
        "    'artifact_hashes': artifact_hashes,",
        "    'content_witness_files': content_witness_files,",
        "    'content_witness_hashes': content_witness_hashes,",
        "    'external_return_attestation': external_return_attestation,",
        "    'assembly_authority': ASSEMBLY_AUTHORITY,",
        "    'assembly_authority_statement': ASSEMBLY_AUTHORITY_STATEMENT,",
        "}",
        "(OUTPUT_ROOT / 'OPERATOR_INPUT_RECEIPT.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "print(f'materialized {OUTPUT_ROOT}')",
        "",
    ]),
    encoding="utf-8",
)
materializer.chmod(0o755)

(scaffold_dir / "RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        ": \"${V61GI_OPERATOR_INPUT_ROOT:?set V61GI_OPERATOR_INPUT_ROOT}\"",
        ": \"${V61GI_OUTPUT_ROOT:?set V61GI_OUTPUT_ROOT outside the repository}\"",
        "\"$DIR/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py\"",
        f"V61GH_INPUT_ROOT=\"$V61GI_OPERATOR_INPUT_ROOT\" \\",
        f"V61GH_OUTPUT_ROOT=\"$V61GI_OUTPUT_ROOT\" \\",
        f"{shlex.quote(str(results / 'v61gh_post_gg_authority_bound_partial_root_workbench' / 'workbench_001' / 'authority_bound_partial_root_workbench' / 'ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py'))}",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh").chmod(0o755)

(scaffold_dir / "RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        f"ROOT_DIR={shlex.quote(str(root))}",
        ": \"${V61GI_MINIMAL_SLICE_ROWS_CSV:?set V61GI_MINIMAL_SLICE_ROWS_CSV to the filled one-row CSV}\"",
        ": \"${V61GI_OPERATOR_INPUT_ROOT:?set V61GI_OPERATOR_INPUT_ROOT to an empty external operator input root}\"",
        ": \"${V61GI_OUTPUT_ROOT:?set V61GI_OUTPUT_ROOT to an external assembly output root}\"",
        ": \"${V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT:?set final assembly authority statement}\"",
        "V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS=\"${V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS:-real-external-review-and-generation-return}\" \\",
        "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY=operator-final-real-return \\",
        "V61GI_MINIMAL_SLICE_ROWS_CSV=\"$V61GI_MINIMAL_SLICE_ROWS_CSV\" \\",
        "V61GI_OPERATOR_INPUT_ROOT=\"$V61GI_OPERATOR_INPUT_ROOT\" \\",
        "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=\"$V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT\" \\",
        "\"$DIR/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py\" >/dev/null",
        "V61GJ_RUN_ID=\"${V61GJ_RUN_ID:-operator_minimal_slice_final}\" \\",
        "V61GJ_OPERATOR_INPUT_ROOT=\"$V61GI_OPERATOR_INPUT_ROOT\" \\",
        "V61GJ_OUTPUT_ROOT=\"$V61GI_OUTPUT_ROOT\" \\",
        "V61GJ_EXECUTE_ASSEMBLY=1 \\",
        "V61GJ_REUSE_EXISTING=0 \\",
        "\"$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh\" >/dev/null",
        "python3 - \"$ROOT_DIR/results/v61gj_post_gi_operator_input_receiver_summary.csv\" <<'PY_CHECK'",
        "import csv, sys",
        "with open(sys.argv[1], newline='', encoding='utf-8') as handle:",
        "    row = next(csv.DictReader(handle))",
        "required_ones = [",
        "    'operator_input_receipt_content_witness_ready',",
        "    'operator_input_receipt_ready',",
        "    'operator_input_assembly_authority_ready',",
        "    'operator_input_preflight_ready',",
        "    'assembly_admitted',",
        "    'assembly_executed',",
        "    'row_acceptance_ready',",
        "    'dual_external_return_real_ready',",
        "    'real_return_replay_admission_ready',",
        "    'generation_acceptance_closure_ready',",
        "    'authority_bound_replay_admission_ready',",
        "]",
        "required_positive = [",
        "    'real_external_review_return_rows',",
        "    'real_adjudication_rows',",
        "    'slice_answer_review_accepted_rows',",
        "    'real_generation_result_artifacts',",
        "    'accepted_generation_result_artifacts',",
        "    'generation_result_accepted_rows',",
        "    'accepted_answer_rows',",
        "    'accepted_citation_rows',",
        "    'accepted_latency_rows',",
        "]",
        "errors = []",
        "for key in required_ones:",
        "    if row.get(key) != '1':",
        "        errors.append(f'{key}={row.get(key)}')",
        "for key in required_positive:",
        "    try:",
        "        if int(row.get(key, '0') or '0') <= 0:",
        "            errors.append(f'{key}={row.get(key)}')",
        "    except ValueError:",
        "        errors.append(f'{key}={row.get(key)}')",
        "if errors:",
        "    raise SystemExit('minimal slice dual replay remains blocked: ' + ';'.join(errors))",
        "print('minimal slice dual replay ready')",
        "PY_CHECK",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh").chmod(0o755)

(scaffold_dir / "RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        ": \"${V61GI_CONTENT_WITNESS_DIR:?set V61GI_CONTENT_WITNESS_DIR to final witness files}\"",
        ": \"${V61GI_MINIMAL_SLICE_ROWS_CSV:?set V61GI_MINIMAL_SLICE_ROWS_CSV to the generated one-row CSV path}\"",
        ": \"${V61GI_OPERATOR_INPUT_ROOT:?set V61GI_OPERATOR_INPUT_ROOT to an empty external operator input root}\"",
        ": \"${V61GI_OUTPUT_ROOT:?set V61GI_OUTPUT_ROOT to an external assembly output root}\"",
        ": \"${V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT:?set final assembly authority statement}\"",
        "\"$DIR/RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh\" >/dev/null",
        "\"$DIR/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh\"",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh").chmod(0o755)

(scaffold_dir / "VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_INPUT_REQUIRED_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_GENERATED_MARKER_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_INPUT_TEMPLATE_FILE_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_CONTEXT_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_REVIEW_WORKSHEET_ROWS.csv\"",
        "test -s \"$DIR/MINIMAL_SLICE_ROWS.csv.template\"",
        "test -s \"$DIR/MINIMAL_SLICE_SELECTED_CONTEXT.json\"",
        "test -s \"$DIR/MINIMAL_SLICE_SELECTED_CONTEXT.md\"",
        "test -s \"$DIR/MINIMAL_SLICE_REVIEW_WORKSHEET.json\"",
        "test -s \"$DIR/MINIMAL_SLICE_REVIEW_WORKSHEET.md\"",
        "test -s \"$DIR/MINIMAL_SLICE_ENV_TEMPLATE.sh\"",
        "test -s \"$DIR/MINIMAL_SLICE_OPERATOR_README.md\"",
        "test -x \"$DIR/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py\"",
        "test -x \"$DIR/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py\"",
        "test -x \"$DIR/RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh\"",
        "test -x \"$DIR/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py\"",
        "test -x \"$DIR/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py\"",
        "test -x \"$DIR/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py\"",
        "test -x \"$DIR/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh\"",
        "test -x \"$DIR/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh\"",
        "test -x \"$DIR/RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh\"",
        "if find \"$DIR/operator_input_templates\" -type f ! -name '*.template' | grep -q .; then",
        "  echo 'non-template file found in operator input templates' >&2",
        "  exit 1",
        "fi",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in operator input scaffold' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh").chmod(0o755)

(scaffold_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gi ready-now commands verify the scaffold only; operator input preflight needs final non-template files.'",
        "echo 'results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh'",
        "echo 'Minimal slice CSV template: results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MINIMAL_SLICE_ROWS.csv.template'",
        "echo 'Minimal slice selected context: results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MINIMAL_SLICE_SELECTED_CONTEXT.md'",
        "echo 'Minimal slice review worksheet: results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MINIMAL_SLICE_REVIEW_WORKSHEET.md'",
        "echo 'Minimal slice env template: results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MINIMAL_SLICE_ENV_TEMPLATE.sh'",
        "echo 'Content witness manifest: results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv'",
        "echo 'Precheck witness/env readiness: V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> ... results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py'",
        "echo 'Build CSV from witness directory: V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> ... results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py'",
        "echo 'Precheck and build in one guarded step: V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> ... results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh'",
        "echo 'From a one-row minimal slice CSV with witness paths: V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py'",
        "echo 'After final files exist: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS=real-authority-bound-partial-return V61GI_OPERATOR_INPUT_RECEIPT_ATTESTATION=<final-attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py'",
        "echo 'Assembly authority, only after real external finalization: V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY=operator-final-real-return V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-assembly-authority-statement>'",
        "echo 'Final assembly authority also requires content witness files: review/adjudication/credential/conflict/answer/transcript/source *_content_path fields or operator_content_witness files.'",
        "echo 'After OPERATOR_INPUT_RECEIPT.json exists: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py'",
        "echo 'Then: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<external-output-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh'",
        "echo 'One-command final path: V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<empty-external-operator-root> V61GI_OUTPUT_ROOT=<external-output-root> V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-statement> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh'",
        "echo 'Witness-dir final path: V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<empty-external-operator-root> V61GI_OUTPUT_ROOT=<external-output-root> V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-statement> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh'",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

for rel, src in [
    ("AUTHORITY_BOUND_OPERATOR_INPUT_REQUIRED_ROWS.csv", run_dir / "authority_bound_operator_input_required_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_GENERATED_MARKER_ROWS.csv", run_dir / "authority_bound_operator_generated_marker_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_INPUT_TEMPLATE_FILE_ROWS.csv", run_dir / "authority_bound_operator_input_template_file_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_TEMPLATE_ROWS.csv", run_dir / "authority_bound_operator_minimal_slice_template_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv", run_dir / "authority_bound_operator_content_witness_manifest_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_CONTEXT_ROWS.csv", run_dir / "authority_bound_operator_minimal_slice_context_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_REVIEW_WORKSHEET_ROWS.csv", run_dir / "authority_bound_operator_minimal_slice_review_worksheet_rows.csv"),
]:
    shutil.copy2(src, scaffold_dir / rel)

command_rows = [
    {"command_id": "01-verify-scaffold", "ready_to_run_now": "1", "command": "results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh", "purpose": "verify metadata-only operator input scaffold"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/READY_NOW_COMMANDS.sh", "purpose": "print final input preflight and assembly commands"},
    {"command_id": "03-precheck-minimal-slice-inputs", "ready_to_run_now": "0", "command": "V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> V61GI_ADJUDICATOR_ID=<id> V61GI_GENERATION_ID=<id> V61GI_CITATION_ID=<id> V61GI_CHECKPOINT_ROOT=<root> V61GI_LATENCY_ROW_ID=<id> V61GI_PROMPT_TOKENS=<n> V61GI_OUTPUT_TOKENS=<n> V61GI_PREFILL_MS=<ms> V61GI_DECODE_MS=<ms> V61GI_TOTAL_MS=<ms> V61GI_TOKENS_PER_SECOND=<n> V61GI_V53_AUTHORITY_STATEMENT=<statement> V61GI_V61_AUTHORITY_STATEMENT=<statement> V61GI_EXTERNAL_RETURN_ATTESTATION=<attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py", "purpose": "fail-closed CSV precheck for witness directory and metadata before building the one-row minimal slice"},
    {"command_id": "04-build-minimal-slice-from-witness-dir", "ready_to_run_now": "0", "command": "V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> V61GI_ADJUDICATOR_ID=<id> V61GI_GENERATION_ID=<id> V61GI_CITATION_ID=<id> V61GI_CHECKPOINT_ROOT=<root> V61GI_LATENCY_ROW_ID=<id> V61GI_PROMPT_TOKENS=<n> V61GI_OUTPUT_TOKENS=<n> V61GI_PREFILL_MS=<ms> V61GI_DECODE_MS=<ms> V61GI_TOTAL_MS=<ms> V61GI_TOKENS_PER_SECOND=<n> V61GI_V53_AUTHORITY_STATEMENT=<statement> V61GI_V61_AUTHORITY_STATEMENT=<statement> V61GI_EXTERNAL_RETURN_ATTESTATION=<attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py", "purpose": "hash witness files and write the one-row minimal slice CSV"},
    {"command_id": "05-precheck-and-build-minimal-slice", "ready_to_run_now": "0", "command": "V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_REVIEWER_ID=<id> V61GI_ADJUDICATOR_ID=<id> V61GI_GENERATION_ID=<id> V61GI_CITATION_ID=<id> V61GI_CHECKPOINT_ROOT=<root> V61GI_LATENCY_ROW_ID=<id> V61GI_PROMPT_TOKENS=<n> V61GI_OUTPUT_TOKENS=<n> V61GI_PREFILL_MS=<ms> V61GI_DECODE_MS=<ms> V61GI_TOTAL_MS=<ms> V61GI_TOKENS_PER_SECOND=<n> V61GI_V53_AUTHORITY_STATEMENT=<statement> V61GI_V61_AUTHORITY_STATEMENT=<statement> V61GI_EXTERNAL_RETURN_ATTESTATION=<attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh", "purpose": "run the fail-closed precheck and only then write the one-row minimal slice CSV"},
    {"command_id": "06-materialize-minimal-slice", "ready_to_run_now": "0", "command": "V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py", "purpose": "materialize final files and receipt from one accepted subset row; final assembly authority requires content witness path fields"},
    {"command_id": "07-build-operator-input-receipt", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS=real-authority-bound-partial-return V61GI_OPERATOR_INPUT_RECEIPT_ATTESTATION=<final-attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py", "purpose": "hash-bind final operator files and content witnesses into OPERATOR_INPUT_RECEIPT.json; assembly authority must be explicit"},
    {"command_id": "08-preflight-final-operator-input", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py", "purpose": "requires final non-template operator files and receipt"},
    {"command_id": "09-run-v61gh-assembly", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<external-output-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh", "purpose": "assemble roots and rerun v61gg outside the repo"},
    {"command_id": "10-run-minimal-slice-to-dual-replay", "ready_to_run_now": "0", "command": "V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<empty-external-operator-root> V61GI_OUTPUT_ROOT=<external-output-root> V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-statement> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh", "purpose": "materialize final witness-bound input, run v61gj assembly, and assert subset dual replay counters"},
    {"command_id": "11-run-witness-dir-to-dual-replay", "ready_to_run_now": "0", "command": "V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<empty-external-operator-root> V61GI_OUTPUT_ROOT=<external-output-root> V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-statement> V61GI_REVIEWER_ID=<id> V61GI_ADJUDICATOR_ID=<id> V61GI_GENERATION_ID=<id> V61GI_CITATION_ID=<id> V61GI_CHECKPOINT_ROOT=<root> V61GI_LATENCY_ROW_ID=<id> V61GI_PROMPT_TOKENS=<n> V61GI_OUTPUT_TOKENS=<n> V61GI_PREFILL_MS=<ms> V61GI_DECODE_MS=<ms> V61GI_TOTAL_MS=<ms> V61GI_TOKENS_PER_SECOND=<n> V61GI_V53_AUTHORITY_STATEMENT=<statement> V61GI_V61_AUTHORITY_STATEMENT=<statement> V61GI_EXTERNAL_RETURN_ATTESTATION=<attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh", "purpose": "precheck witness files, build the minimal slice, materialize final input, run v61gj assembly, and assert subset dual replay counters"},
]
write_csv(run_dir / "authority_bound_operator_input_scaffold_command_rows.csv", list(command_rows[0].keys()), command_rows)
shutil.copy2(run_dir / "authority_bound_operator_input_scaffold_command_rows.csv", scaffold_dir / "AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_COMMAND_ROWS.csv")

package_files = sorted(path for path in scaffold_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "authority_bound_operator_input_scaffold_package_file_rows.csv", list(package_rows[0].keys()), package_rows)

summary = {
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gh_post_gg_authority_bound_partial_root_workbench_ready": 1,
    "root_artifact_contract_rows": len(contracts),
    "operator_input_required_rows": len(operator_input_rows),
    "generated_marker_contract_rows": len(generated_marker_rows),
    "authority_bound_operator_input_rows": sum(row["authority_bound"] == "1" for row in operator_input_rows),
    "template_file_rows": len(template_rows),
    "operator_input_receipt_template_rows": 1,
    "operator_input_minimal_slice_template_rows": len(minimal_slice_template_rows),
    "operator_input_content_witness_manifest_rows": len(content_witness_manifest_rows),
    "operator_input_minimal_slice_context_files": len(minimal_slice_context_rows),
    "operator_input_minimal_slice_context_ready": 1,
    "operator_input_minimal_slice_review_worksheet_files": len(review_worksheet_rows),
    "operator_input_minimal_slice_review_worksheet_ready": 1,
    "operator_input_minimal_slice_env_template_ready": 1,
    "operator_input_minimal_slice_precheck_ready": 1,
    "operator_input_minimal_slice_builder_ready": 1,
    "operator_input_minimal_slice_prepare_wrapper_ready": 1,
    "operator_input_witness_dir_final_replay_wrapper_ready": 1,
    "operator_input_materializer_ready": 1,
    "operator_input_receipt_builder_ready": 1,
    "template_counts_as_evidence_rows": sum(row["counts_as_evidence"] == "1" for row in template_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "operator_input_root_supplied": 0,
    "operator_input_receipt_ready": 0,
    "operator_input_preflight_ready": 0,
    "assembled_v53_root_ready": 0,
    "assembled_v61_root_ready": 0,
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gi": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "source_file_rows": len(source_rows),
    "package_file_rows": len(package_rows),
    "metadata_only_package_file_rows": sum(row["metadata_only"] == "1" for row in package_rows),
    "payload_like_package_file_rows": sum(row["payload_like"] == "1" for row in package_rows),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gh-ready", "status": "pass", "evidence": "v61gh ready"},
    {"gate": "operator-input-scaffold", "status": "pass", "evidence": f"template_file_rows={len(template_rows)}"},
    {"gate": "operator-input-minimal-slice-template", "status": "pass", "evidence": f"minimal_slice_template_rows={len(minimal_slice_template_rows)}"},
    {"gate": "operator-input-content-witness-manifest", "status": "pass", "evidence": f"content_witness_manifest_rows={len(content_witness_manifest_rows)}"},
    {"gate": "operator-input-minimal-slice-context", "status": "pass", "evidence": f"operator_input_minimal_slice_context_files={len(minimal_slice_context_rows)}"},
    {"gate": "operator-input-minimal-slice-review-worksheet", "status": "pass", "evidence": f"operator_input_minimal_slice_review_worksheet_files={len(review_worksheet_rows)}"},
    {"gate": "operator-input-minimal-slice-env-template", "status": "pass", "evidence": "operator_input_minimal_slice_env_template_ready=1"},
    {"gate": "operator-input-minimal-slice-precheck", "status": "pass", "evidence": "operator_input_minimal_slice_precheck_ready=1"},
    {"gate": "operator-input-minimal-slice-builder", "status": "pass", "evidence": "operator_input_minimal_slice_builder_ready=1"},
    {"gate": "operator-input-minimal-slice-prepare-wrapper", "status": "pass", "evidence": "operator_input_minimal_slice_prepare_wrapper_ready=1"},
    {"gate": "operator-input-witness-dir-final-replay-wrapper", "status": "pass", "evidence": "operator_input_witness_dir_final_replay_wrapper_ready=1"},
    {"gate": "operator-input-materializer", "status": "pass", "evidence": "operator_input_materializer_ready=1"},
    {"gate": "operator-input-receipt-builder", "status": "pass", "evidence": "operator_input_receipt_builder_ready=1"},
    {"gate": "templates-count-as-evidence", "status": "pass", "evidence": "template_counts_as_evidence_rows=0"},
    {"gate": "operator-input-root-supplied", "status": "blocked", "evidence": "operator_input_root_supplied=0"},
    {"gate": "operator-input-receipt", "status": "blocked", "evidence": "operator_input_receipt_ready=0"},
    {"gate": "operator-input-preflight", "status": "blocked", "evidence": "operator_input_preflight_ready=0"},
    {"gate": "assembled-authority-bound-roots", "status": "blocked", "evidence": "assembled_v53_root_ready=0; assembled_v61_root_ready=0"},
    {"gate": "authority-bound-replay-admission", "status": "blocked", "evidence": "authority_bound_replay_admission_ready=0"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "operator_input_rows": operator_input_rows,
    "generated_marker_rows": generated_marker_rows,
    "decisions": decision_rows,
}
(scaffold_dir / "AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(scaffold_dir / "AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.md").write_text(
    "\n".join([
        "# v61gi authority-bound operator input scaffold",
        "",
        f"- root_artifact_contract_rows={summary['root_artifact_contract_rows']}",
        f"- operator_input_required_rows={summary['operator_input_required_rows']}",
        f"- generated_marker_contract_rows={summary['generated_marker_contract_rows']}",
        f"- template_file_rows={summary['template_file_rows']}",
        f"- operator_input_receipt_template_rows={summary['operator_input_receipt_template_rows']}",
        f"- operator_input_minimal_slice_template_rows={summary['operator_input_minimal_slice_template_rows']}",
        f"- operator_input_content_witness_manifest_rows={summary['operator_input_content_witness_manifest_rows']}",
        f"- operator_input_minimal_slice_context_files={summary['operator_input_minimal_slice_context_files']}",
        "- operator_input_minimal_slice_context_ready=1",
        f"- operator_input_minimal_slice_review_worksheet_files={summary['operator_input_minimal_slice_review_worksheet_files']}",
        "- operator_input_minimal_slice_review_worksheet_ready=1",
        "- operator_input_minimal_slice_env_template_ready=1",
        "- operator_input_minimal_slice_precheck_ready=1",
        "- operator_input_minimal_slice_builder_ready=1",
        "- operator_input_minimal_slice_prepare_wrapper_ready=1",
        "- operator_input_witness_dir_final_replay_wrapper_ready=1",
        "- operator_input_materializer_ready=1",
        "- operator_input_receipt_builder_ready=1",
        "- template_counts_as_evidence_rows=0",
        "- operator_input_receipt_ready=0",
        "- operator_input_preflight_ready=0",
        "- assembled_v53_root_ready=0",
        "- assembled_v61_root_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Templates are scaffolding only. Final operator files must be written without .template suffixes and without placeholder or fixture text before v61gh assembly can run.",
        "",
    ]),
    encoding="utf-8",
)

boundary = "\n".join([
    "# V61GI Post-GH Authority-Bound Operator Input Scaffold",
    "",
    "- v61gi_post_gh_authority_bound_operator_input_scaffold_ready=1",
    f"- operator_input_required_rows={summary['operator_input_required_rows']}",
    f"- generated_marker_contract_rows={summary['generated_marker_contract_rows']}",
    f"- template_file_rows={summary['template_file_rows']}",
    f"- operator_input_receipt_template_rows={summary['operator_input_receipt_template_rows']}",
    f"- operator_input_minimal_slice_template_rows={summary['operator_input_minimal_slice_template_rows']}",
    f"- operator_input_content_witness_manifest_rows={summary['operator_input_content_witness_manifest_rows']}",
    f"- operator_input_minimal_slice_context_files={summary['operator_input_minimal_slice_context_files']}",
    "- operator_input_minimal_slice_context_ready=1",
    f"- operator_input_minimal_slice_review_worksheet_files={summary['operator_input_minimal_slice_review_worksheet_files']}",
    "- operator_input_minimal_slice_review_worksheet_ready=1",
    "- operator_input_minimal_slice_env_template_ready=1",
    "- operator_input_minimal_slice_precheck_ready=1",
    "- operator_input_minimal_slice_builder_ready=1",
    "- operator_input_minimal_slice_prepare_wrapper_ready=1",
    "- operator_input_witness_dir_final_replay_wrapper_ready=1",
    "- operator_input_materializer_ready=1",
    "- operator_input_receipt_builder_ready=1",
    "- template_counts_as_evidence_rows=0",
    "- operator_input_receipt_ready=0",
    "- operator_input_preflight_ready=0",
    "- assembled_v53_root_ready=0",
    "- assembled_v61_root_ready=0",
    "- real_external_review_return_rows=0",
    "- real_generation_result_artifacts=0",
    "- authority_bound_replay_admission_ready=0",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this scaffold does not create external review, adjudication, generation, latency, quality, v1.0 comparison, or release evidence. It only gives the operator a final-file input shape and verifier.",
    "",
])
(run_dir / "V61GI_POST_GH_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_BOUNDARY.md").write_text(boundary, encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gi_post_gh_authority_bound_operator_input_scaffold_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
