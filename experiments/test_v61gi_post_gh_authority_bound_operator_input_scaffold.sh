#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gi_post_gh_authority_bound_operator_input_scaffold"
RUN_DIR="$RESULTS_DIR/$PREFIX/scaffold_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SCAFFOLD_DIR="$RUN_DIR/authority_bound_operator_input_scaffold"
MINIMAL_BUILDER_WITNESS_DIR="${TMPDIR:-/tmp}/v61gi minimal builder witnesses"
MINIMAL_BUILDER_CSV="${TMPDIR:-/tmp}/v61gi_minimal_builder_rows.csv"

V61GI_REUSE_EXISTING="${V61GI_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

"$SCAFFOLD_DIR/VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh" >/dev/null
"$SCAFFOLD_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if env -u V61GI_CONTENT_WITNESS_DIR -u V61GI_MINIMAL_SLICE_ROWS_CSV \
  "$SCAFFOLD_DIR/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py" >/tmp/v61gi_minimal_builder_noenv.out 2>/tmp/v61gi_minimal_builder_noenv.err; then
  echo "v61gi unexpectedly accepted missing env for minimal slice builder" >&2
  exit 1
fi
grep -q "V61GI_CONTENT_WITNESS_DIR" /tmp/v61gi_minimal_builder_noenv.err

rm -rf "$MINIMAL_BUILDER_WITNESS_DIR"
rm -f "$MINIMAL_BUILDER_CSV"
python3 - "$MINIMAL_BUILDER_WITNESS_DIR" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
payloads = {
    "review_comment.txt": "Reviewer accepted source support for the selected answer and recorded accountable review notes.",
    "adjudication_reason.txt": "Adjudicator accepted the selected review row after checking source, citation, and row identity.",
    "credential_statement.txt": "External reviewer credential statement records reviewer identity and scope for this partial return.",
    "conflict_statement.txt": "External reviewer conflict statement records no conflict for the selected repository.",
    "answer_text.txt": "Hash-bound selected answer text retained for the generation result return.",
    "run_transcript.txt": "Hash-bound generation transcript retained for timing, checkpoint, and prompt/result accountability.",
    "source_file.txt": "Hash-bound source file witness retained for the selected citation row.",
}
for name, text in payloads.items():
    (root / name).write_text(text + "\n", encoding="utf-8")
PY

V61GI_CONTENT_WITNESS_DIR="$MINIMAL_BUILDER_WITNESS_DIR" \
V61GI_MINIMAL_SLICE_ROWS_CSV="$MINIMAL_BUILDER_CSV" \
V61GI_REVIEWER_ID="reviewer-builder-alpha" \
V61GI_ADJUDICATOR_ID="adjudicator-builder-alpha" \
V61GI_GENERATION_ID="generation-builder-alpha" \
V61GI_CITATION_ID="citation-builder-alpha" \
V61GI_CHECKPOINT_ROOT="/external/checkpoint/builder-alpha" \
V61GI_LATENCY_ROW_ID="latency-builder-alpha" \
V61GI_PROMPT_TOKENS="128" \
V61GI_OUTPUT_TOKENS="32" \
V61GI_PREFILL_MS="11.5" \
V61GI_DECODE_MS="23.0" \
V61GI_TOTAL_MS="34.5" \
V61GI_TOKENS_PER_SECOND="92.75" \
V61GI_V53_AUTHORITY_STATEMENT="External reviewer authority statement finalized for builder smoke with independent accountability." \
V61GI_V61_AUTHORITY_STATEMENT="External generation operator authority statement finalized for builder smoke with independent accountability." \
V61GI_EXTERNAL_RETURN_ATTESTATION="External return attestation finalized for builder smoke with immutable witness hash binding." \
"$SCAFFOLD_DIR/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py" >/dev/null

python3 - "$MINIMAL_BUILDER_WITNESS_DIR" "$MINIMAL_BUILDER_CSV" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

witness_dir = Path(sys.argv[1])
csv_path = Path(sys.argv[2])
row = next(csv.DictReader(csv_path.open(newline="", encoding="utf-8")))
checks = {
    "review_comment_sha256": ("review_comment.txt", "review_comment_content_path"),
    "adjudication_reason_sha256": ("adjudication_reason.txt", "adjudication_reason_content_path"),
    "credential_statement_sha256": ("credential_statement.txt", "credential_statement_content_path"),
    "conflict_statement_sha256": ("conflict_statement.txt", "conflict_statement_content_path"),
    "answer_text_sha256": ("answer_text.txt", "answer_text_content_path"),
    "run_transcript_sha256": ("run_transcript.txt", "run_transcript_content_path"),
    "source_file_sha256": ("source_file.txt", "source_file_content_path"),
}
for sha_field, (filename, path_field) in checks.items():
    path = witness_dir / filename
    digest = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    if row.get(sha_field) != digest:
        raise SystemExit(f"builder hash mismatch: {sha_field}")
    if Path(row.get(path_field, "")).resolve() != path.resolve():
        raise SystemExit(f"builder path mismatch: {path_field}")
if row.get("reviewer_id") != "reviewer-builder-alpha":
    raise SystemExit("builder metadata mismatch")
print("v61gi minimal slice builder smoke passed")
PY

if "$SCAFFOLD_DIR/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh" >/tmp/v61gi_minimal_slice_replay_noenv.out 2>/tmp/v61gi_minimal_slice_replay_noenv.err; then
  echo "v61gi unexpectedly accepted missing env for minimal slice replay" >&2
  exit 1
fi
grep -q "V61GI_MINIMAL_SLICE_ROWS_CSV" /tmp/v61gi_minimal_slice_replay_noenv.err

if V61GI_OPERATOR_INPUT_ROOT="$SCAFFOLD_DIR/operator_input_templates" \
  "$SCAFFOLD_DIR/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py" >/tmp/v61gi_template_preflight.out 2>/tmp/v61gi_template_preflight.err; then
  echo "v61gi unexpectedly accepted template input root" >&2
  exit 1
fi
grep -Eq "missing:|placeholder-or-fixture-text|not-final" /tmp/v61gi_template_preflight.err

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SCAFFOLD_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
scaffold_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": "1",
    "v61gh_post_gg_authority_bound_partial_root_workbench_ready": "1",
    "root_artifact_contract_rows": "14",
    "operator_input_required_rows": "12",
    "generated_marker_contract_rows": "2",
    "authority_bound_operator_input_rows": "2",
    "template_file_rows": "13",
    "operator_input_receipt_template_rows": "1",
    "operator_input_minimal_slice_template_rows": "1",
    "operator_input_content_witness_manifest_rows": "7",
    "operator_input_minimal_slice_env_template_ready": "1",
    "operator_input_minimal_slice_builder_ready": "1",
    "operator_input_materializer_ready": "1",
    "operator_input_receipt_builder_ready": "1",
    "template_counts_as_evidence_rows": "0",
    "ready_command_rows": "2",
    "blocked_command_rows": "6",
    "operator_input_root_supplied": "0",
    "operator_input_receipt_ready": "0",
    "operator_input_preflight_ready": "0",
    "assembled_v53_root_ready": "0",
    "assembled_v61_root_ready": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gi": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "source_file_rows": "5",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gi {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "authority_bound_operator_input_required_rows.csv",
    "authority_bound_operator_generated_marker_rows.csv",
    "authority_bound_operator_input_template_file_rows.csv",
    "authority_bound_operator_minimal_slice_template_rows.csv",
    "authority_bound_operator_content_witness_manifest_rows.csv",
    "authority_bound_operator_input_scaffold_command_rows.csv",
    "authority_bound_operator_input_scaffold_source_rows.csv",
    "authority_bound_operator_input_scaffold_package_file_rows.csv",
    "V61GI_POST_GH_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_BOUNDARY.md",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_manifest.json",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "v61gi_post_gh_authority_bound_operator_input_scaffold_decision.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_INPUT_REQUIRED_ROWS.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_GENERATED_MARKER_ROWS.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_INPUT_TEMPLATE_FILE_ROWS.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_MINIMAL_SLICE_TEMPLATE_ROWS.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_CONTENT_WITNESS_MANIFEST_ROWS.csv",
    "authority_bound_operator_input_scaffold/MINIMAL_SLICE_ROWS.csv.template",
    "authority_bound_operator_input_scaffold/MINIMAL_SLICE_ENV_TEMPLATE.sh",
    "authority_bound_operator_input_scaffold/MINIMAL_SLICE_OPERATOR_README.md",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_COMMAND_ROWS.csv",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_MANIFEST.json",
    "authority_bound_operator_input_scaffold/AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.md",
    "authority_bound_operator_input_scaffold/BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py",
    "authority_bound_operator_input_scaffold/MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py",
    "authority_bound_operator_input_scaffold/BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py",
    "authority_bound_operator_input_scaffold/VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py",
    "authority_bound_operator_input_scaffold/RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh",
    "authority_bound_operator_input_scaffold/RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh",
    "authority_bound_operator_input_scaffold/VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh",
    "authority_bound_operator_input_scaffold/READY_NOW_COMMANDS.sh",
    "source_v61gh/v61gh_post_gg_authority_bound_partial_root_workbench_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gi artifact: {rel}")

for rel in [
    "MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py",
    "BUILD_MINIMAL_SLICE_ROWS_FROM_WITNESS_DIR.py",
    "BUILD_OPERATOR_INPUT_RECEIPT_IF_FINAL.py",
    "VERIFY_OPERATOR_INPUT_ROOT_IF_SUPPLIED.py",
    "RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh",
    "RUN_MINIMAL_SLICE_TO_DUAL_REPLAY_IF_FINAL.sh",
    "VERIFY_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD.sh",
    "READY_NOW_COMMANDS.sh",
]:
    if not os.access(scaffold_dir / rel, os.X_OK):
        raise SystemExit(f"v61gi executable bit missing: {rel}")

input_rows = read_csv(run_dir / "authority_bound_operator_input_required_rows.csv")
marker_rows = read_csv(run_dir / "authority_bound_operator_generated_marker_rows.csv")
template_rows = read_csv(run_dir / "authority_bound_operator_input_template_file_rows.csv")
minimal_slice_template_rows = read_csv(run_dir / "authority_bound_operator_minimal_slice_template_rows.csv")
content_witness_manifest_rows = read_csv(run_dir / "authority_bound_operator_content_witness_manifest_rows.csv")
if len(input_rows) != 12:
    raise SystemExit("v61gi expected 12 operator input rows")
if len(marker_rows) != 2:
    raise SystemExit("v61gi expected two generated marker rows")
if len(template_rows) != 13:
    raise SystemExit("v61gi expected 13 template rows")
if not any(row["final_relative_path"] == "OPERATOR_INPUT_RECEIPT.json" for row in template_rows):
    raise SystemExit("v61gi expected receipt template row")
if any(row["counts_as_evidence"] != "0" for row in template_rows):
    raise SystemExit("v61gi templates must not count as evidence")
if any(not row["template_relative_path"].endswith(".template") for row in template_rows):
    raise SystemExit("v61gi template paths must use .template suffix")
if len(minimal_slice_template_rows) != 1:
    raise SystemExit("v61gi expected one minimal slice template row")
if len(content_witness_manifest_rows) != 7:
    raise SystemExit("v61gi expected seven content witness manifest rows")
if {row["required_filename"] for row in content_witness_manifest_rows} != {
    "review_comment.txt",
    "adjudication_reason.txt",
    "credential_statement.txt",
    "conflict_statement.txt",
    "answer_text.txt",
    "run_transcript.txt",
    "source_file.txt",
}:
    raise SystemExit("v61gi content witness manifest filenames mismatch")
minimal_template_csv = read_csv(scaffold_dir / "MINIMAL_SLICE_ROWS.csv.template")
if len(minimal_template_csv) != 1:
    raise SystemExit("v61gi expected one placeholder row in minimal slice template")
for field in [
    "review_comment_content_path",
    "adjudication_reason_content_path",
    "credential_statement_content_path",
    "conflict_statement_content_path",
    "answer_text_content_path",
    "run_transcript_content_path",
    "source_file_content_path",
]:
    if field not in minimal_template_csv[0]:
        raise SystemExit(f"v61gi minimal slice template missing content witness field: {field}")
if any(row["operator_supplies_directly"] != "0" for row in marker_rows):
    raise SystemExit("v61gi provenance markers must be generated by assembly, not direct operator input")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
env_template = (scaffold_dir / "MINIMAL_SLICE_ENV_TEMPLATE.sh").read_text(encoding="utf-8")
for snippet in ["V61GI_CONTENT_WITNESS_DIR", "V61GI_MINIMAL_SLICE_ROWS_CSV", "V61GI_OPERATOR_INPUT_ROOT", "V61GI_OUTPUT_ROOT"]:
    if snippet not in env_template:
        raise SystemExit(f"v61gi env template missing snippet: {snippet}")

for gate in ["source-v61gh-ready", "operator-input-scaffold", "operator-input-minimal-slice-template", "operator-input-content-witness-manifest", "operator-input-minimal-slice-env-template", "operator-input-minimal-slice-builder", "operator-input-materializer", "operator-input-receipt-builder", "templates-count-as-evidence", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gi expected pass decision: {gate}")
for gate in [
    "operator-input-root-supplied",
    "operator-input-receipt",
    "operator-input-preflight",
    "assembled-authority-bound-roots",
    "authority-bound-replay-admission",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gi expected blocked decision: {gate}")

manifest = json.loads((scaffold_dir / "AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_MANIFEST.json").read_text(encoding="utf-8"))
if manifest["summary"].get("template_counts_as_evidence_rows") != 0:
    raise SystemExit("v61gi manifest must keep templates non-evidence")

boundary = (run_dir / "V61GI_POST_GH_AUTHORITY_BOUND_OPERATOR_INPUT_SCAFFOLD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready=1",
    "operator_input_required_rows=12",
    "generated_marker_contract_rows=2",
    "template_file_rows=13",
    "operator_input_receipt_template_rows=1",
    "operator_input_minimal_slice_template_rows=1",
    "operator_input_content_witness_manifest_rows=7",
    "operator_input_minimal_slice_env_template_ready=1",
    "operator_input_minimal_slice_builder_ready=1",
    "operator_input_materializer_ready=1",
    "operator_input_receipt_builder_ready=1",
    "template_counts_as_evidence_rows=0",
    "operator_input_receipt_ready=0",
    "operator_input_preflight_ready=0",
    "assembled_v53_root_ready=0",
    "assembled_v61_root_ready=0",
    "real_external_review_return_rows=0",
    "real_generation_result_artifacts=0",
    "authority_bound_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gi boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gi sha256 mismatch: {rel}")

print("v61gi authority-bound operator input scaffold smoke passed")
PY
