#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gh_post_gg_authority_bound_partial_root_workbench"
RUN_ID="${V61GH_RUN_ID:-workbench_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gh_post_gg_authority_bound_partial_root_workbench_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gg_post_gf_real_authority_binding_guard.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

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
prefix = "v61gh_post_gg_authority_bound_partial_root_workbench"
workbench_dir = run_dir / "authority_bound_partial_root_workbench"
workbench_dir.mkdir(parents=True, exist_ok=True)


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
    "v61gg_summary": results / "v61gg_post_gf_real_authority_binding_guard_summary.csv",
    "v61gg_decision": results / "v61gg_post_gf_real_authority_binding_guard_decision.csv",
    "v61gg_authority_rows": results / "v61gg_post_gf_real_authority_binding_guard" / "guard_001" / "real_authority_binding_guard_rows.csv",
    "v53r_summary": results / "v53r_complete_source_review_packet_summary.csv",
    "v53r_answers": results / "v53r_complete_source_review_packet" / "review_001" / "review_answer_packet_rows.csv",
    "v53r_queue": results / "v53r_complete_source_review_packet" / "review_001" / "review_queue_rows.csv",
    "v53r_assignments": results / "v53r_complete_source_review_packet" / "review_001" / "reviewer_assignment_template_rows.csv",
    "v53r_queries": results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gh source {source_id}: {path}")

source_rows = []
for source_id, path in source_paths.items():
    folder = "source_v61gg" if source_id.startswith("v61gg") else "source_v53r"
    source_rows.append(copy_source(source_id, path, folder))
write_csv(run_dir / "authority_bound_partial_root_workbench_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gg = read_csv(source_paths["v61gg_summary"])[0]
v53r = read_csv(source_paths["v53r_summary"])[0]
if v61gg.get("v61gg_post_gf_real_authority_binding_guard_ready") != "1":
    raise SystemExit("v61gh requires v61gg ready")
if v53r.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61gh requires v53r ready")

answer_rows = read_csv(source_paths["v53r_answers"])
queue_rows = read_csv(source_paths["v53r_queue"])
assignment_rows = read_csv(source_paths["v53r_assignments"])
query_rows = read_csv(source_paths["v53r_queries"])
answer_by_id = {row["answer_id"]: row for row in answer_rows}
first_queue = next((row for row in queue_rows if row.get("priority_class") == "p0_answer_or_policy_mismatch"), queue_rows[0])
first_answer = answer_by_id[first_queue["answer_id"]]
first_assignment = next(row for row in assignment_rows if row["system_id"] == first_answer["system_id"])
first_query = query_rows[0]

selected_rows = [
    {
        "slice_id": "v53-partial-review-slice",
        "selected_artifact_family": "v53 external return",
        "review_answer_packet_id": first_answer["review_answer_packet_id"],
        "answer_id": first_answer["answer_id"],
        "system_id": first_answer["system_id"],
        "query_id": first_answer["query_id"],
        "source_span_id": first_answer.get("source_span_id", ""),
        "owner_repo": first_answer["owner_repo"],
        "assignment_id": first_assignment["assignment_id"],
        "reviewer_slot_id": first_assignment["reviewer_slot_id"],
        "minimum_required_rows": "human_review_rows=1;adjudication_rows=1;reviewer_identity_rows=1;reviewer_conflict_rows=1",
    },
    {
        "slice_id": "v61-partial-generation-slice",
        "selected_artifact_family": "v61 generation-intake return",
        "review_answer_packet_id": "",
        "answer_id": "",
        "system_id": "",
        "query_id": first_query["query_id"],
        "source_span_id": first_query["source_span_id"],
        "owner_repo": first_query.get("owner_repo", ""),
        "assignment_id": "",
        "reviewer_slot_id": "",
        "minimum_required_rows": "answer=1;citation=1;abstain_fallback=1;latency=1;acceptance_summary=1",
    },
]
write_csv(run_dir / "authority_bound_partial_root_selected_slice_rows.csv", list(selected_rows[0].keys()), selected_rows)

input_contract_rows = [
    {"input_id": "01-v53-human-review-rows", "target_root": "v53", "target_relative_path": "aggregate_review_return/human_review_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "02-v53-adjudication-rows", "target_root": "v53", "target_relative_path": "aggregate_review_return/adjudication_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "03-v53-reviewer-identity-rows", "target_root": "v53", "target_relative_path": "aggregate_review_return/reviewer_identity_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "04-v53-reviewer-conflict-rows", "target_root": "v53", "target_relative_path": "aggregate_review_return/reviewer_conflict_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "05-v53-acceptance-summary", "target_root": "v53", "target_relative_path": "aggregate_review_return/acceptance_summary.json", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "06-v53-authority-statement", "target_root": "v53", "target_relative_path": "operator_attestation/reviewer_authority_statement.txt", "required": "1", "minimum_row_count": "1", "authority_bound": "1"},
    {"input_id": "07-v53-provenance-marker", "target_root": "v53", "target_relative_path": "REAL_EXTERNAL_RETURN_PROVENANCE.json", "required": "1", "minimum_row_count": "1", "authority_bound": "1"},
    {"input_id": "08-v61-answer-rows", "target_root": "v61", "target_relative_path": "generation_result_return/real_model_generation_answer_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "09-v61-citation-rows", "target_root": "v61", "target_relative_path": "generation_result_return/real_model_generation_citation_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "10-v61-abstain-fallback-rows", "target_root": "v61", "target_relative_path": "generation_result_return/real_model_generation_abstain_fallback_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "11-v61-latency-rows", "target_root": "v61", "target_relative_path": "generation_result_return/real_model_generation_latency_rows.csv", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "12-v61-acceptance-summary", "target_root": "v61", "target_relative_path": "generation_result_return/real_model_generation_acceptance_summary.json", "required": "1", "minimum_row_count": "1", "authority_bound": "0"},
    {"input_id": "13-v61-authority-statement", "target_root": "v61", "target_relative_path": "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt", "required": "1", "minimum_row_count": "1", "authority_bound": "1"},
    {"input_id": "14-v61-provenance-marker", "target_root": "v61", "target_relative_path": "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json", "required": "1", "minimum_row_count": "1", "authority_bound": "1"},
]
write_csv(run_dir / "authority_bound_partial_root_input_contract_rows.csv", list(input_contract_rows[0].keys()), input_contract_rows)

command_rows = [
    {"command_id": "01-verify-workbench", "ready_to_run_now": "1", "command": "results/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_workbench/VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh", "purpose": "verify metadata-only workbench"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_workbench/READY_NOW_COMMANDS.sh", "purpose": "print operator assembly commands"},
    {"command_id": "03-assemble-roots-from-supplied-files", "ready_to_run_now": "0", "command": "V61GH_INPUT_ROOT=<operator-input-root> V61GH_OUTPUT_ROOT=<external-output-root> results/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_workbench/ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py", "purpose": "copy supplied files, bind authority statement hashes into provenance markers, and run v61gg"},
]
write_csv(run_dir / "authority_bound_partial_root_workbench_command_rows.csv", list(command_rows[0].keys()), command_rows)

assembler = workbench_dir / "ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py"
assembler.write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv, hashlib, json, os, shutil, subprocess, sys",
        "from pathlib import Path",
        "",
        f"ROOT_DIR = Path({str(root)!r})",
        "INPUT_ROOT = Path(os.environ.get('V61GH_INPUT_ROOT', '')).expanduser()",
        "OUTPUT_ROOT = Path(os.environ.get('V61GH_OUTPUT_ROOT', '')).expanduser()",
        "if not str(INPUT_ROOT) or not INPUT_ROOT.is_dir():",
        "    raise SystemExit('set V61GH_INPUT_ROOT to the operator-supplied input root')",
        "if not str(OUTPUT_ROOT):",
        "    raise SystemExit('set V61GH_OUTPUT_ROOT to the external output root')",
        "",
        "def sha256(path):",
        "    h = hashlib.sha256()",
        "    with path.open('rb') as handle:",
        "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "            h.update(chunk)",
        "    return 'sha256:' + h.hexdigest()",
        "",
        "def copy_required(src_rel, dst_rel):",
        "    src = INPUT_ROOT / src_rel",
        "    dst = OUTPUT_ROOT / dst_rel",
        "    if not src.is_file() or src.stat().st_size == 0:",
        "        raise SystemExit(f'missing required operator file: {src_rel}')",
        "    dst.parent.mkdir(parents=True, exist_ok=True)",
        "    shutil.copy2(src, dst)",
        "    return dst",
        "",
        "v53_map = {",
        "    'v53/aggregate_review_return/human_review_rows.csv': 'v53/aggregate_review_return/human_review_rows.csv',",
        "    'v53/aggregate_review_return/adjudication_rows.csv': 'v53/aggregate_review_return/adjudication_rows.csv',",
        "    'v53/aggregate_review_return/reviewer_identity_rows.csv': 'v53/aggregate_review_return/reviewer_identity_rows.csv',",
        "    'v53/aggregate_review_return/reviewer_conflict_rows.csv': 'v53/aggregate_review_return/reviewer_conflict_rows.csv',",
        "    'v53/aggregate_review_return/acceptance_summary.json': 'v53/aggregate_review_return/acceptance_summary.json',",
        "    'v53/operator_attestation/reviewer_authority_statement.txt': 'v53/operator_attestation/reviewer_authority_statement.txt',",
        "}",
        "v61_map = {",
        "    'v61/generation_result_return/real_model_generation_answer_rows.csv': 'v61/generation_result_return/real_model_generation_answer_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_citation_rows.csv': 'v61/generation_result_return/real_model_generation_citation_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv': 'v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_latency_rows.csv': 'v61/generation_result_return/real_model_generation_latency_rows.csv',",
        "    'v61/generation_result_return/real_model_generation_acceptance_summary.json': 'v61/generation_result_return/real_model_generation_acceptance_summary.json',",
        "    'v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt': 'v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt',",
        "}",
        "for src_rel, dst_rel in {**v53_map, **v61_map}.items():",
        "    copy_required(src_rel, dst_rel)",
        "",
        "v53_auth = OUTPUT_ROOT / 'v53/operator_attestation/reviewer_authority_statement.txt'",
        "v61_auth = OUTPUT_ROOT / 'v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt'",
        "v53_marker = {",
        "    'provenance': 'real-external-return-bundle',",
        "    'source_class': 'external-operator-return',",
        "    'reviewer_authority_path': 'operator_attestation/reviewer_authority_statement.txt',",
        "    'reviewer_authority_sha256': sha256(v53_auth),",
        "}",
        "v61_marker = {",
        "    'provenance': 'real-generation-intake-return-bundle',",
        "    'source_class': 'external-generation-intake-return',",
        "    'generation_operator_authority_path': 'review_return_provenance/operator_attestation/generation_operator_authority_statement.txt',",
        "    'generation_operator_authority_sha256': sha256(v61_auth),",
        "}",
        "(OUTPUT_ROOT / 'v53/REAL_EXTERNAL_RETURN_PROVENANCE.json').write_text(json.dumps(v53_marker, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "(OUTPUT_ROOT / 'v61/review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json').write_text(json.dumps(v61_marker, indent=2, sort_keys=True) + '\\n', encoding='utf-8')",
        "env = os.environ.copy()",
        "env.update({",
        "    'V61GG_RUN_ID': 'operator_authority_bound_partial_root',",
        "    'V61GG_V53_RETURN_ROOT': str((OUTPUT_ROOT / 'v53').resolve()),",
        "    'V61GG_V53_RETURN_PROVENANCE': 'real-external-return-bundle',",
        "    'V61GG_V61_RETURN_ROOT': str((OUTPUT_ROOT / 'v61').resolve()),",
        "    'V61GG_V61_RETURN_PROVENANCE': 'real-generation-intake-return-bundle',",
        "    'V61GG_REUSE_EXISTING': '0',",
        "})",
        "subprocess.run([str(ROOT_DIR / 'experiments/run_v61gg_post_gf_real_authority_binding_guard.sh')], check=True, env=env)",
        "print('assembled authority-bound partial roots under', OUTPUT_ROOT)",
        "",
    ]),
    encoding="utf-8",
)
assembler.chmod(0o755)

(workbench_dir / "VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -x \"$DIR/ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py\"",
        "test -x \"$DIR/VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh\"",
        "test -s \"$DIR/AUTHORITY_BOUND_PARTIAL_ROOT_INPUT_CONTRACT_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_PARTIAL_ROOT_SELECTED_SLICE_ROWS.csv\"",
        "test -s \"$DIR/AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_MANIFEST.json\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gh workbench package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(workbench_dir / "VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh").chmod(0o755)

(workbench_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gh ready-now command verifies the metadata-only workbench.'",
        "echo 'results/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_workbench/VERIFY_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.sh'",
        "echo 'After external operator files exist: V61GH_INPUT_ROOT=<operator-input-root> V61GH_OUTPUT_ROOT=<external-output-root> results/v61gh_post_gg_authority_bound_partial_root_workbench/workbench_001/authority_bound_partial_root_workbench/ASSEMBLE_AUTHORITY_BOUND_PARTIAL_ROOTS_IF_SUPPLIED.py'",
        "",
    ]),
    encoding="utf-8",
)
(workbench_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

for rel, src in [
    ("AUTHORITY_BOUND_PARTIAL_ROOT_INPUT_CONTRACT_ROWS.csv", run_dir / "authority_bound_partial_root_input_contract_rows.csv"),
    ("AUTHORITY_BOUND_PARTIAL_ROOT_SELECTED_SLICE_ROWS.csv", run_dir / "authority_bound_partial_root_selected_slice_rows.csv"),
    ("AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_COMMAND_ROWS.csv", run_dir / "authority_bound_partial_root_workbench_command_rows.csv"),
]:
    shutil.copy2(src, workbench_dir / rel)

summary = {
    "v61gh_post_gg_authority_bound_partial_root_workbench_ready": 1,
    "v61gg_post_gf_real_authority_binding_guard_ready": 1,
    "v53r_complete_source_review_packet_ready": 1,
    "selected_v53_answer_rows": 1,
    "selected_v61_query_rows": 1,
    "input_contract_rows": len(input_contract_rows),
    "authority_bound_input_contract_rows": sum(row["authority_bound"] == "1" for row in input_contract_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
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
    "checkpoint_payload_bytes_downloaded_by_v61gh": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "source_file_rows": len(source_rows),
    "package_file_rows": 0,
    "metadata_only_package_file_rows": 0,
    "payload_like_package_file_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "selected_rows": selected_rows,
    "input_contract_rows": input_contract_rows,
}
(workbench_dir / "AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(workbench_dir / "AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH.md").write_text(
    "\n".join([
        "# v61gh authority-bound partial root workbench",
        "",
        f"- selected_v53_answer_rows={summary['selected_v53_answer_rows']}",
        f"- selected_v61_query_rows={summary['selected_v61_query_rows']}",
        f"- input_contract_rows={summary['input_contract_rows']}",
        f"- authority_bound_input_contract_rows={summary['authority_bound_input_contract_rows']}",
        "- assembled_v53_root_ready=0",
        "- assembled_v61_root_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "This package does not create real review or generation evidence. It defines the exact operator files required to assemble authority-bound partial roots outside the repository.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in workbench_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "authority_bound_partial_root_workbench_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = len(package_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gg-ready", "status": "pass", "evidence": "v61gg ready"},
    {"gate": "source-v53r-ready", "status": "pass", "evidence": "v53r ready"},
    {"gate": "workbench-package", "status": "pass", "evidence": f"package_file_rows={summary['package_file_rows']}"},
    {"gate": "operator-inputs-supplied", "status": "blocked", "evidence": "operator files are not supplied by the canonical workbench run"},
    {"gate": "assembled-authority-bound-roots", "status": "blocked", "evidence": "assembled_v53_root_ready=0; assembled_v61_root_ready=0"},
    {"gate": "authority-bound-replay-admission", "status": "blocked", "evidence": "authority_bound_replay_admission_ready=0"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GH Post-GG Authority-Bound Partial Root Workbench",
    "",
    "- v61gh_post_gg_authority_bound_partial_root_workbench_ready=1",
    f"- selected_v53_answer_rows={summary['selected_v53_answer_rows']}",
    f"- selected_v61_query_rows={summary['selected_v61_query_rows']}",
    f"- input_contract_rows={summary['input_contract_rows']}",
    f"- authority_bound_input_contract_rows={summary['authority_bound_input_contract_rows']}",
    "- assembled_v53_root_ready=0",
    "- assembled_v61_root_ready=0",
    "- real_external_review_return_rows=0",
    "- real_generation_result_artifacts=0",
    "- authority_bound_replay_admission_ready=0",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this workbench is an operator assembly surface, not real evidence. It does not claim review/adjudication rows, generation result artifacts, replay admission, production latency, near-frontier quality, v1.0 comparison, or release readiness until external operator files are supplied and accepted.",
    "",
])
(run_dir / "V61GH_POST_GG_AUTHORITY_BOUND_PARTIAL_ROOT_WORKBENCH_BOUNDARY.md").write_text(boundary, encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps({
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gh_post_gg_authority_bound_partial_root_workbench_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
