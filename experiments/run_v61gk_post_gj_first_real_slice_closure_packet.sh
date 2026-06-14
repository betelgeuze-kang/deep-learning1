#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gk_post_gj_first_real_slice_closure_packet"
RUN_ID="${V61GK_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gk_post_gj_first_real_slice_closure_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null
V61GF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh" >/dev/null
V61GJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null

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
prefix = "v61gk_post_gj_first_real_slice_closure_packet"
packet_dir = run_dir / "first_real_slice_closure_packet"
packet_dir.mkdir(parents=True, exist_ok=True)

GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GF_PREFIX = "v61gf_post_ge_dual_partial_return_replay_admission"
GJ_PREFIX = "v61gj_post_gi_operator_input_receiver"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"


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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def current_counter(key, gj, gf):
    return as_int(gj, key) or as_int(gf, key)


source_paths = {
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_decision": results / f"{GI_PREFIX}_decision.csv",
    "v61gf_summary": results / f"{GF_PREFIX}_summary.csv",
    "v61gf_decision": results / f"{GF_PREFIX}_decision.csv",
    "v61gj_summary": results / f"{GJ_PREFIX}_summary.csv",
    "v61gj_decision": results / f"{GJ_PREFIX}_decision.csv",
    "minimal_slice_selected_context_md": gi_scaffold / "MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "minimal_slice_selected_context_json": gi_scaffold / "MINIMAL_SLICE_SELECTED_CONTEXT.json",
    "minimal_slice_review_worksheet_md": gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "minimal_slice_review_worksheet_json": gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "minimal_slice_env_template": gi_scaffold / "MINIMAL_SLICE_ENV_TEMPLATE.sh",
    "minimal_slice_rows_template": gi_scaffold / "MINIMAL_SLICE_ROWS.csv.template",
    "content_witness_manifest": gi_scaffold / "AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv",
    "run_witness_dir_final": gi_scaffold / "RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh",
    "run_minimal_slice_final": gi_scaffold / "RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gk source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61g"):
        folder = "source_gate_summaries"
    else:
        folder = "source_operator_scaffold"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_closure_packet_source_rows.csv", list(source_rows[0].keys()), source_rows)

gi = read_csv(source_paths["v61gi_summary"])[0]
gf = read_csv(source_paths["v61gf_summary"])[0]
gj = read_csv(source_paths["v61gj_summary"])[0]
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gk requires v61gi ready")
if gf.get("v61gf_post_ge_dual_partial_return_replay_admission_ready") != "1":
    raise SystemExit("v61gk requires v61gf ready")
if gj.get("v61gj_post_gi_operator_input_receiver_ready") != "1":
    raise SystemExit("v61gk requires v61gj ready")

required_artifact_rows = [
    {"artifact_family": "v53-partial-root", "relative_path": "aggregate_review_return/human_review_rows.csv", "required_for": "real_external_review_return_rows>0", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "one valid human review row over the selected answer", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v53-partial-root", "relative_path": "aggregate_review_return/adjudication_rows.csv", "required_for": "real_adjudication_rows>0", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "one valid adjudication row for the selected p0 answer", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v53-partial-root", "relative_path": "aggregate_review_return/reviewer_identity_rows.csv", "required_for": "reviewer identity binding", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "one identity row matching the selected assignment", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v53-partial-root", "relative_path": "aggregate_review_return/reviewer_conflict_rows.csv", "required_for": "conflict disclosure binding", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "one no-conflict row for selected assignment/repo", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v53-partial-root", "relative_path": "aggregate_review_return/acceptance_summary.json", "required_for": "hash/count binding", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "bind exact row counts and sha256 values", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v53-partial-root", "relative_path": "REAL_EXTERNAL_RETURN_PROVENANCE.json", "required_for": "real provenance", "source_gate": "v61gd/v61gf", "minimum_slice_requirement": "provenance=real-external-return-bundle with non-fixture source_class", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "generation_result_return/real_model_generation_answer_rows.csv", "required_for": "accepted_answer_rows>0", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "one source-bound generation answer row", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "generation_result_return/real_model_generation_citation_rows.csv", "required_for": "accepted_citation_rows>0", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "one verified citation row for same generation/query", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "generation_result_return/real_model_generation_abstain_fallback_rows.csv", "required_for": "abstain/fallback binding", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "one abstain/fallback row for same generation/query", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "generation_result_return/real_model_generation_latency_rows.csv", "required_for": "accepted_latency_rows>0", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "one positive latency row for same generation/query", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "generation_result_return/real_model_generation_acceptance_summary.json", "required_for": "accepted_generation_result_artifacts>0", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "bind exact generation result counts and sha256 values", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "v61-generation-root", "relative_path": "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json", "required_for": "real generation provenance", "source_gate": "v61ge/v61gf", "minimum_slice_requirement": "provenance=real-generation-intake-return-bundle with non-fixture source_class", "status": "external-required", "evidence_boundary": "not included in this packet"},
    {"artifact_family": "operator-input-root", "relative_path": "OPERATOR_INPUT_RECEIPT.json", "required_for": "v61gj assembly admission", "source_gate": "v61gj", "minimum_slice_requirement": "finalized receipt hash-bound to all 12 final files and content witnesses", "status": "generated-only-after-external-input", "evidence_boundary": "template only in source scaffold"},
]
write_csv(run_dir / "first_real_slice_required_artifact_rows.csv", list(required_artifact_rows[0].keys()), required_artifact_rows)

witness_rows = [
    {"witness_id": "review_comment_sha256", "relative_path": "operator_content_witness/review_comment.txt", "required_for": "v53 human review row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "adjudication_reason_sha256", "relative_path": "operator_content_witness/adjudication_reason.txt", "required_for": "v53 adjudication row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "credential_statement_sha256", "relative_path": "operator_content_witness/credential_statement.txt", "required_for": "reviewer identity row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "conflict_statement_sha256", "relative_path": "operator_content_witness/conflict_statement.txt", "required_for": "reviewer conflict row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "answer_text_sha256", "relative_path": "operator_content_witness/answer_text.txt", "required_for": "v61 answer row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "run_transcript_sha256", "relative_path": "operator_content_witness/run_transcript.txt", "required_for": "v61 answer/provenance row", "status": "external-required", "nonfinal_content_rejected": "1"},
    {"witness_id": "source_file_sha256", "relative_path": "operator_content_witness/source_file.txt", "required_for": "v61 citation row", "status": "external-required", "nonfinal_content_rejected": "1"},
]
write_csv(run_dir / "first_real_slice_content_witness_rows.csv", list(witness_rows[0].keys()), witness_rows)

target_defs = [
    ("real_external_review_return_rows", ">0", current_counter("real_external_review_return_rows", gj, gf)),
    ("real_adjudication_rows", ">0", current_counter("real_adjudication_rows", gj, gf)),
    ("slice_answer_review_accepted_rows", ">0", current_counter("slice_answer_review_accepted_rows", gj, gf)),
    ("real_generation_result_artifacts", ">0", current_counter("real_generation_result_artifacts", gj, gf)),
    ("accepted_generation_result_artifacts", ">0", current_counter("accepted_generation_result_artifacts", gj, gf)),
    ("generation_result_accepted_rows", ">0", current_counter("generation_result_accepted_rows", gj, gf)),
    ("accepted_answer_rows", ">0", current_counter("accepted_answer_rows", gj, gf)),
    ("accepted_citation_rows", ">0", current_counter("accepted_citation_rows", gj, gf)),
    ("accepted_latency_rows", ">0", current_counter("accepted_latency_rows", gj, gf)),
    ("row_acceptance_ready", "1", current_counter("row_acceptance_ready", gj, gf)),
    ("generation_execution_admission_ready", "1", current_counter("generation_execution_admission_ready", gj, gf)),
    ("dual_external_return_real_ready", "1", current_counter("dual_external_return_real_ready", gj, gf)),
    ("real_return_replay_admission_ready", "1", current_counter("real_return_replay_admission_ready", gj, gf)),
    ("generation_acceptance_closure_ready", "1", current_counter("generation_acceptance_closure_ready", gj, gf)),
    ("actual_model_generation_ready", "0-until-full-generation", current_counter("actual_model_generation_ready", gj, gf)),
]
target_counter_rows = []
for counter, required, observed in target_defs:
    if required == ">0":
        ready = int(observed > 0)
    elif required == "1":
        ready = int(observed == 1)
    else:
        ready = int(observed == 0)
    target_counter_rows.append({
        "counter": counter,
        "required_value": required,
        "observed_value": str(observed),
        "ready": str(ready),
        "claim_boundary": "subset closure target" if counter != "actual_model_generation_ready" else "full actual generation remains out of scope for this packet",
    })
write_csv(run_dir / "first_real_slice_target_counter_rows.csv", list(target_counter_rows[0].keys()), target_counter_rows)

first_real_slice_closure_ready = int(all(row["ready"] == "1" for row in target_counter_rows if row["counter"] != "actual_model_generation_ready"))

command_rows = [
    {"command_id": "01-verify-packet", "ready_to_run_now": "1", "command": "results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh", "purpose": "verify this zero-payload closure packet"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/READY_NOW_COMMANDS.sh", "purpose": "show context and finalization commands"},
    {"command_id": "03-fill-witness-dir", "ready_to_run_now": "0", "command": "create final files listed in FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv under a repo-external witness dir", "purpose": "human/operator writes real review, adjudication, generation, transcript, and source witness content"},
    {"command_id": "04-run-first-real-slice-from-witness-dir", "ready_to_run_now": str(first_real_slice_closure_ready), "command": "source FIRST_REAL_SLICE_ENV_TEMPLATE.sh && RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh", "purpose": "build minimal slice, materialize final input, assemble roots, and assert subset replay counters"},
    {"command_id": "05-run-direct-dual-root-replay", "ready_to_run_now": "0", "command": "V61GF_V53_RETURN_ROOT=<external-output-root>/v53 V61GF_V53_RETURN_PROVENANCE=real-external-return-bundle V61GF_V61_RETURN_ROOT=<external-output-root>/v61 V61GF_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh", "purpose": "replay both assembled roots directly through v61gf"},
    {"command_id": "06-check-target-counters", "ready_to_run_now": str(first_real_slice_closure_ready), "command": "results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/CHECK_FIRST_REAL_SLICE_COUNTERS.py", "purpose": "assert the subset target counters are open"},
]
write_csv(run_dir / "first_real_slice_command_rows.csv", list(command_rows[0].keys()), command_rows)

stage_rows = [
    {"stage_id": "01-v61gi-scaffold-source", "status": "ready", "evidence": "v61gi scaffold ready"},
    {"stage_id": "02-v61gf-dual-replay-source", "status": "ready", "evidence": "v61gf replay admission ready as a gate"},
    {"stage_id": "03-v61gj-receiver-source", "status": "ready", "evidence": "v61gj receiver ready as final operator input path"},
    {"stage_id": "04-first-real-v53-slice", "status": "ready" if current_counter("real_external_review_return_rows", gj, gf) > 0 else "blocked", "evidence": f"real_external_review_return_rows={current_counter('real_external_review_return_rows', gj, gf)}"},
    {"stage_id": "05-first-real-v61-generation-slice", "status": "ready" if current_counter("generation_result_accepted_rows", gj, gf) > 0 else "blocked", "evidence": f"generation_result_accepted_rows={current_counter('generation_result_accepted_rows', gj, gf)}"},
    {"stage_id": "06-dual-root-replay-open", "status": "ready" if current_counter("real_return_replay_admission_ready", gj, gf) == 1 else "blocked", "evidence": f"real_return_replay_admission_ready={current_counter('real_return_replay_admission_ready', gj, gf)}"},
    {"stage_id": "07-actual-generation-full-claim", "status": "blocked", "evidence": "subset first slice does not prove full actual generation"},
]
write_csv(run_dir / "first_real_slice_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, src in [
    ("MINIMAL_SLICE_SELECTED_CONTEXT.md", source_paths["minimal_slice_selected_context_md"]),
    ("MINIMAL_SLICE_SELECTED_CONTEXT.json", source_paths["minimal_slice_selected_context_json"]),
    ("MINIMAL_SLICE_REVIEW_WORKSHEET.md", source_paths["minimal_slice_review_worksheet_md"]),
    ("MINIMAL_SLICE_REVIEW_WORKSHEET.json", source_paths["minimal_slice_review_worksheet_json"]),
    ("MINIMAL_SLICE_ENV_TEMPLATE.sh", source_paths["minimal_slice_env_template"]),
    ("MINIMAL_SLICE_ROWS.csv.template", source_paths["minimal_slice_rows_template"]),
    ("AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv", source_paths["content_witness_manifest"]),
    ("FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv", run_dir / "first_real_slice_required_artifact_rows.csv"),
    ("FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv", run_dir / "first_real_slice_content_witness_rows.csv"),
    ("FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv", run_dir / "first_real_slice_target_counter_rows.csv"),
    ("FIRST_REAL_SLICE_COMMAND_ROWS.csv", run_dir / "first_real_slice_command_rows.csv"),
    ("FIRST_REAL_SLICE_STAGE_ROWS.csv", run_dir / "first_real_slice_stage_rows.csv"),
]:
    shutil.copy2(src, packet_dir / rel)

(packet_dir / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "export V61GI_CONTENT_WITNESS_DIR=/external/path/to/final_content_witness_dir",
        "export V61GI_MINIMAL_SLICE_ROWS_CSV=/external/path/to/first_real_slice_rows.csv",
        "export V61GI_OPERATOR_INPUT_ROOT=/external/path/to/first_real_operator_input_root",
        "export V61GI_OUTPUT_ROOT=/external/path/to/first_real_dual_root_output",
        "export V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT='Final external operator authority for the first real subset slice, binding review, adjudication, generation, citation, latency, and witness evidence.'",
        "export V61GI_REVIEWER_ID=replace_with_external_reviewer_id",
        "export V61GI_ADJUDICATOR_ID=replace_with_external_adjudicator_id",
        "export V61GI_GENERATION_ID=replace_with_external_generation_id",
        "export V61GI_CITATION_ID=replace_with_external_citation_id",
        "export V61GI_CHECKPOINT_ROOT=/external/path/to/checkpoint/root",
        "export V61GI_LATENCY_ROW_ID=replace_with_latency_row_id",
        "export V61GI_PROMPT_TOKENS=replace_with_prompt_tokens",
        "export V61GI_OUTPUT_TOKENS=replace_with_output_tokens",
        "export V61GI_PREFILL_MS=replace_with_prefill_ms",
        "export V61GI_DECODE_MS=replace_with_decode_ms",
        "export V61GI_TOTAL_MS=replace_with_total_ms",
        "export V61GI_TOKENS_PER_SECOND=replace_with_tokens_per_second",
        "export V61GI_V53_AUTHORITY_STATEMENT='Final external reviewer authority statement for the first real subset slice.'",
        "export V61GI_V61_AUTHORITY_STATEMENT='Final external generation operator authority statement for the first real subset slice.'",
        "export V61GI_EXTERNAL_RETURN_ATTESTATION='Final external return attestation for the first real subset slice with immutable hash binding to supplied artifacts.'",
        "",
    ]),
    encoding="utf-8",
)
(packet_dir / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh").chmod(0o755)

(packet_dir / "CHECK_FIRST_REAL_SLICE_COUNTERS.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "import sys",
        "from pathlib import Path",
        "",
        f"ROOT = Path({str(root)!r})",
        f"GJ_SUMMARY = ROOT / 'results' / '{GJ_PREFIX}_summary.csv'",
        f"GF_SUMMARY = ROOT / 'results' / '{GF_PREFIX}_summary.csv'",
        "",
        "def read_one(path):",
        "    with path.open(newline='', encoding='utf-8') as handle:",
        "        return next(csv.DictReader(handle))",
        "",
        "def as_int(row, key):",
        "    try:",
        "        return int(row.get(key, '0') or '0')",
        "    except ValueError:",
        "        return 0",
        "",
        "gj = read_one(GJ_SUMMARY)",
        "gf = read_one(GF_SUMMARY)",
        "def current(key):",
        "    return as_int(gj, key) or as_int(gf, key)",
        "",
        "requirements = {",
        "    'real_external_review_return_rows': lambda v: v > 0,",
        "    'real_adjudication_rows': lambda v: v > 0,",
        "    'slice_answer_review_accepted_rows': lambda v: v > 0,",
        "    'real_generation_result_artifacts': lambda v: v > 0,",
        "    'accepted_generation_result_artifacts': lambda v: v > 0,",
        "    'generation_result_accepted_rows': lambda v: v > 0,",
        "    'accepted_answer_rows': lambda v: v > 0,",
        "    'accepted_citation_rows': lambda v: v > 0,",
        "    'accepted_latency_rows': lambda v: v > 0,",
        "    'row_acceptance_ready': lambda v: v == 1,",
        "    'generation_execution_admission_ready': lambda v: v == 1,",
        "    'dual_external_return_real_ready': lambda v: v == 1,",
        "    'real_return_replay_admission_ready': lambda v: v == 1,",
        "    'generation_acceptance_closure_ready': lambda v: v == 1,",
        "}",
        "missing = []",
        "for key, pred in requirements.items():",
        "    value = current(key)",
        "    if not pred(value):",
        "        missing.append(f'{key}={value}')",
        "if missing:",
        "    raise SystemExit('first real slice counters remain blocked: ' + '; '.join(missing))",
        "print('first real slice closure counters ready')",
        "",
    ]),
    encoding="utf-8",
)
(packet_dir / "CHECK_FIRST_REAL_SLICE_COUNTERS.py").chmod(0o755)

(packet_dir / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"ROOT_DIR={shlex.quote(str(root))}",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        ": \"${V61GI_CONTENT_WITNESS_DIR:?set V61GI_CONTENT_WITNESS_DIR to final witness files}\"",
        ": \"${V61GI_MINIMAL_SLICE_ROWS_CSV:?set V61GI_MINIMAL_SLICE_ROWS_CSV to external csv output path}\"",
        ": \"${V61GI_OPERATOR_INPUT_ROOT:?set V61GI_OPERATOR_INPUT_ROOT to repo-external operator input root}\"",
        ": \"${V61GI_OUTPUT_ROOT:?set V61GI_OUTPUT_ROOT to repo-external output root}\"",
        ": \"${V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT:?set final assembly authority statement}\"",
        "\"$ROOT_DIR/results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh\"",
        "\"$DIR/CHECK_FIRST_REAL_SLICE_COUNTERS.py\"",
        "",
    ]),
    encoding="utf-8",
)
(packet_dir / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh").chmod(0o755)

(packet_dir / "VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_STAGE_ROWS.csv\"",
        "test -s \"$DIR/MINIMAL_SLICE_SELECTED_CONTEXT.md\"",
        "test -s \"$DIR/MINIMAL_SLICE_REVIEW_WORKSHEET.md\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CLOSURE_PACKET_MANIFEST.json\"",
        "test -x \"$DIR/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh\"",
        "test -x \"$DIR/CHECK_FIRST_REAL_SLICE_COUNTERS.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gk packet' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(packet_dir / "VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh").chmod(0o755)

(packet_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gk ready-now commands verify and inspect the first real slice closure packet.'",
        "echo 'results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/VERIFY_FIRST_REAL_SLICE_CLOSURE_PACKET.sh'",
        "echo 'Selected context: results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/MINIMAL_SLICE_SELECTED_CONTEXT.md'",
        "echo 'Review worksheet: results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/MINIMAL_SLICE_REVIEW_WORKSHEET.md'",
        "echo 'Witness rows: results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv'",
        "echo 'After external finalization: source FIRST_REAL_SLICE_ENV_TEMPLATE.sh && RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh'",
        "",
    ]),
    encoding="utf-8",
)
(packet_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

packet_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "subset_scope_only": 1,
    "contains_real_external_evidence": 0,
    "first_real_slice_closure_ready": first_real_slice_closure_ready,
    "target_counter_rows": len(target_counter_rows),
    "ready_target_counter_rows": sum(row["ready"] == "1" for row in target_counter_rows),
    "required_artifact_rows": len(required_artifact_rows),
    "content_witness_rows": len(witness_rows),
    "actual_model_generation_ready": current_counter("actual_model_generation_ready", gj, gf),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(packet_dir / "FIRST_REAL_SLICE_CLOSURE_PACKET_MANIFEST.json").write_text(json.dumps(packet_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(packet_dir / "FIRST_REAL_SLICE_CLOSURE_PACKET.md").write_text(
    "\n".join([
        "# v61gk first real slice closure packet",
        "",
        f"- contains_real_external_evidence=0",
        f"- first_real_slice_closure_ready={first_real_slice_closure_ready}",
        f"- ready_target_counter_rows={packet_manifest['ready_target_counter_rows']}/{len(target_counter_rows)}",
        f"- required_artifact_rows={len(required_artifact_rows)}",
        f"- content_witness_rows={len(witness_rows)}",
        "- actual_model_generation_ready remains a full-generation blocker.",
        "",
        "This packet is the zero-payload handoff for the first real subset slice. It packages context, worksheet, witness requirements, target counters, and final guarded commands without claiming that real external review or generation evidence has been supplied.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in packet_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "first_real_slice_closure_packet_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61gk_post_gj_first_real_slice_closure_packet_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": 1,
    "v61gj_post_gi_operator_input_receiver_ready": 1,
    "contains_real_external_evidence": 0,
    "required_artifact_rows": len(required_artifact_rows),
    "content_witness_rows": len(witness_rows),
    "target_counter_rows": len(target_counter_rows),
    "ready_target_counter_rows": sum(row["ready"] == "1" for row in target_counter_rows),
    "first_real_slice_closure_ready": first_real_slice_closure_ready,
    "real_external_review_return_rows": current_counter("real_external_review_return_rows", gj, gf),
    "real_adjudication_rows": current_counter("real_adjudication_rows", gj, gf),
    "slice_answer_review_accepted_rows": current_counter("slice_answer_review_accepted_rows", gj, gf),
    "real_generation_result_artifacts": current_counter("real_generation_result_artifacts", gj, gf),
    "accepted_generation_result_artifacts": current_counter("accepted_generation_result_artifacts", gj, gf),
    "generation_result_accepted_rows": current_counter("generation_result_accepted_rows", gj, gf),
    "row_acceptance_ready": current_counter("row_acceptance_ready", gj, gf),
    "generation_execution_admission_ready": current_counter("generation_execution_admission_ready", gj, gf),
    "dual_external_return_real_ready": current_counter("dual_external_return_real_ready", gj, gf),
    "real_return_replay_admission_ready": current_counter("real_return_replay_admission_ready", gj, gf),
    "generation_acceptance_closure_ready": current_counter("generation_acceptance_closure_ready", gj, gf),
    "actual_model_generation_ready": current_counter("actual_model_generation_ready", gj, gf),
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "package_file_rows": len(package_file_rows),
    "metadata_only_package_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_package_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gk": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "source-v61gf-ready", "status": "pass", "evidence": "v61gf ready"},
    {"gate": "source-v61gj-ready", "status": "pass", "evidence": "v61gj ready"},
    {"gate": "first-real-slice-closure", "status": "pass" if first_real_slice_closure_ready else "blocked", "evidence": f"ready_target_counter_rows={summary['ready_target_counter_rows']}/{len(target_counter_rows)}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={summary['actual_model_generation_ready']}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GK Post-GJ First Real Slice Closure Packet",
    "",
    "- v61gk_post_gj_first_real_slice_closure_packet_ready=1",
    "- contains_real_external_evidence=0",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- real_adjudication_rows={summary['real_adjudication_rows']}",
    f"- slice_answer_review_accepted_rows={summary['slice_answer_review_accepted_rows']}",
    f"- real_generation_result_artifacts={summary['real_generation_result_artifacts']}",
    f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- dual_external_return_real_ready={summary['dual_external_return_real_ready']}",
    f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
    f"- generation_acceptance_closure_ready={summary['generation_acceptance_closure_ready']}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This packet is a first-real-slice handoff only. It does not supply or fabricate external review, adjudication, model generation, production latency, near-frontier quality, v1.0 comparison, or release evidence.",
    "",
])
(run_dir / "V61GK_POST_GJ_FIRST_REAL_SLICE_CLOSURE_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gk": 0,
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

print(f"v61gk_post_gj_first_real_slice_closure_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
