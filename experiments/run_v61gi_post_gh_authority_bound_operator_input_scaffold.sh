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

materializer = scaffold_dir / "MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py"
materializer.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, hashlib, json, os, sys",
        "from datetime import datetime, timezone",
        "from pathlib import Path",
        "",
        "INPUT_CSV = Path(os.environ.get('V61GI_MINIMAL_SLICE_ROWS_CSV', '')).expanduser()",
        "OUTPUT_ROOT = Path(os.environ.get('V61GI_OPERATOR_INPUT_ROOT', '')).expanduser()",
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
        "def write_csv_file(rel, fieldnames, rows):",
        "    path = OUTPUT_ROOT / rel",
        "    path.parent.mkdir(parents=True, exist_ok=True)",
        "    with path.open('w', newline='', encoding='utf-8') as handle:",
        "        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator='\\n')",
        "        writer.writeheader()",
        "        writer.writerows(rows)",
        "    return path",
        "",
        "if not str(INPUT_CSV) or not INPUT_CSV.is_file():",
        "    raise SystemExit('set V61GI_MINIMAL_SLICE_ROWS_CSV to a one-row CSV')",
        "if not str(OUTPUT_ROOT):",
        "    raise SystemExit('set V61GI_OPERATOR_INPUT_ROOT to the output root')",
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

(scaffold_dir / "VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_INPUT_REQUIRED_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_GENERATED_MARKER_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_OPERATOR_INPUT_TEMPLATE_FILE_ROWS.csv\"",
        "test -x \"$DIR/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py\"",
        "test -x \"$DIR/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py\"",
        "test -x \"$DIR/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py\"",
        "test -x \"$DIR/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh\"",
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
        "echo 'From a one-row minimal slice CSV: V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py'",
        "echo 'After final files exist: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS=real-authority-bound-partial-return V61GI_OPERATOR_INPUT_RECEIPT_ATTESTATION=<final-attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py'",
        "echo 'Assembly authority, only after real external finalization: V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY=operator-final-real-return V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=<final-assembly-authority-statement>'",
        "echo 'After OPERATOR_INPUT_RECEIPT.json exists: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py'",
        "echo 'Then: V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<external-output-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh'",
        "",
    ]),
    encoding="utf-8",
)
(scaffold_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

for rel, src in [
    ("AUTHORITY_BOUND_OPERATOR_INPUT_REQUIRED_ROWS.csv", run_dir / "authority_bound_operator_input_required_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_GENERATED_MARKER_ROWS.csv", run_dir / "authority_bound_operator_generated_marker_rows.csv"),
    ("AUTHORITY_BOUND_OPERATOR_INPUT_TEMPLATE_FILE_ROWS.csv", run_dir / "authority_bound_operator_input_template_file_rows.csv"),
]:
    shutil.copy2(src, scaffold_dir / rel)

command_rows = [
    {"command_id": "01-verify-scaffold", "ready_to_run_now": "1", "command": "results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh", "purpose": "verify metadata-only operator input scaffold"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/READY_NOW_COMMANDS.sh", "purpose": "print final input preflight and assembly commands"},
    {"command_id": "03-materialize-minimal-slice", "ready_to_run_now": "0", "command": "V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py", "purpose": "materialize final files and receipt from one accepted subset row"},
    {"command_id": "04-build-operator-input-receipt", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS=real-authority-bound-partial-return V61GI_OPERATOR_INPUT_RECEIPT_ATTESTATION=<final-attestation> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py", "purpose": "hash-bind final operator files into OPERATOR_INPUT_RECEIPT.json; assembly authority must be explicit"},
    {"command_id": "05-preflight-final-operator-input", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py", "purpose": "requires final non-template operator files and receipt"},
    {"command_id": "06-run-v61gh-assembly", "ready_to_run_now": "0", "command": "V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<external-output-root> results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh", "purpose": "assemble roots and rerun v61gg outside the repo"},
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
