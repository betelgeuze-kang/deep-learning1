#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gu_post_gt_first_real_slice_operator_workspace_initializer"
RUN_ID="${V61GU_RUN_ID:-workspace_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GU_WORK_ROOT:-}"
INITIALIZE_WORKSPACE="${V61GU_INITIALIZE_WORKSPACE:-0}"

if [[ "${V61GU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gu_post_gt_first_real_slice_operator_workspace_initializer_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null
V61GT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gt_post_gs_ack_packet_to_replay_handoff.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$WORK_ROOT" "$INITIALIZE_WORKSPACE" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
work_root_raw = sys.argv[6].strip()
initialize_workspace = int((sys.argv[7].strip() or "0") == "1")
results = root / "results"
prefix = "v61gu_post_gt_first_real_slice_operator_workspace_initializer"
package_dir = run_dir / "first_real_slice_operator_workspace_initializer"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GT_PREFIX = "v61gt_post_gs_ack_packet_to_replay_handoff"
WITNESS_FILES = [
    "review_comment.txt",
    "adjudication_reason.txt",
    "credential_statement.txt",
    "conflict_statement.txt",
    "answer_text.txt",
    "run_transcript.txt",
    "source_file.txt",
]


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


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
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_decision": results / f"{GI_PREFIX}_decision.csv",
    "v61gi_command_rows": results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold_command_rows.csv",
    "v61gi_witness_manifest": results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_content_witness_manifest_rows.csv",
    "v61gt_summary": results / f"{GT_PREFIX}_summary.csv",
    "v61gt_decision": results / f"{GT_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gu source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gi" if label.startswith("v61gi") else "source_v61gt"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_operator_workspace_source_rows.csv", list(source_rows[0].keys()), source_rows)

gi = read_csv(source_paths["v61gi_summary"])[0]
gt = read_csv(source_paths["v61gt_summary"])[0]
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gu requires v61gi ready")
if gt.get("v61gt_post_gs_ack_packet_to_replay_handoff_ready") != "1":
    raise SystemExit("v61gu requires v61gt ready")

work_root_supplied = int(work_root is not None)
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
workspace_admitted = int(initialize_workspace and work_root_supplied and work_root_outside_repo)
workspace_initialized = 0
workspace_errors = []
workspace_file_rows = []

def add_workspace_file(path, metadata_only="1", payload_like="0"):
    workspace_file_rows.append({
        "path": path.relative_to(work_root).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": metadata_only,
        "payload_like": payload_like,
    })


if initialize_workspace and not work_root_supplied:
    workspace_errors.append("missing-work-root")
if work_root_supplied and not work_root_outside_repo:
    workspace_errors.append("work-root-inside-repo")

if workspace_admitted:
    dirs = {
        "final_content_witness": work_root / "final_content_witness",
        "content_witness_templates": work_root / "content_witness_templates",
        "minimal_slice": work_root / "minimal_slice",
        "operator_input_root": work_root / "operator_roots" / "operator_input_root",
        "output_root": work_root / "operator_roots" / "output_root",
        "authority": work_root / "authority",
        "logs": work_root / "logs",
    }
    for path in dirs.values():
        path.mkdir(parents=True, exist_ok=True)
    for filename in WITNESS_FILES:
        template_path = dirs["content_witness_templates"] / f"{filename}.template"
        template_path.write_text(
            "\n".join([
                f"# {filename}",
                "Replace this template outside the repo with final external content.",
                "Do not copy this template file to final_content_witness without replacing all text.",
                "",
            ]),
            encoding="utf-8",
        )
        add_workspace_file(template_path)

    env_template = work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh"
    env_template.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            f"export V61GI_CONTENT_WITNESS_DIR={shlex.quote(str(dirs['final_content_witness']))}",
            f"export V61GI_MINIMAL_SLICE_ROWS_CSV={shlex.quote(str(dirs['minimal_slice'] / 'minimal_slice_rows.csv'))}",
            f"export V61GI_OPERATOR_INPUT_ROOT={shlex.quote(str(dirs['operator_input_root']))}",
            f"export V61GI_OUTPUT_ROOT={shlex.quote(str(dirs['output_root']))}",
            "export V61GI_REVIEWER_ID=REPLACE_WITH_FINAL_REVIEWER_ID",
            "export V61GI_ADJUDICATOR_ID=REPLACE_WITH_FINAL_ADJUDICATOR_ID",
            "export V61GI_GENERATION_ID=REPLACE_WITH_FINAL_GENERATION_ID",
            "export V61GI_CITATION_ID=REPLACE_WITH_FINAL_CITATION_ID",
            "export V61GI_CHECKPOINT_ROOT=REPLACE_WITH_FINAL_CHECKPOINT_ROOT",
            "export V61GI_LATENCY_ROW_ID=REPLACE_WITH_FINAL_LATENCY_ROW_ID",
            "export V61GI_PROMPT_TOKENS=REPLACE_WITH_FINAL_PROMPT_TOKENS",
            "export V61GI_OUTPUT_TOKENS=REPLACE_WITH_FINAL_OUTPUT_TOKENS",
            "export V61GI_PREFILL_MS=REPLACE_WITH_FINAL_PREFILL_MS",
            "export V61GI_DECODE_MS=REPLACE_WITH_FINAL_DECODE_MS",
            "export V61GI_TOTAL_MS=REPLACE_WITH_FINAL_TOTAL_MS",
            "export V61GI_TOKENS_PER_SECOND=REPLACE_WITH_FINAL_TOKENS_PER_SECOND",
            "export V61GI_V53_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_EXTERNAL_REVIEWER_AUTHORITY_STATEMENT'",
            "export V61GI_V61_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_EXTERNAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT'",
            "export V61GI_EXTERNAL_RETURN_ATTESTATION='REPLACE_WITH_FINAL_EXTERNAL_RETURN_ATTESTATION'",
            "export V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT='REPLACE_WITH_FINAL_OPERATOR_ASSEMBLY_AUTHORITY_STATEMENT'",
            "",
        ]),
        encoding="utf-8",
    )
    env_template.chmod(0o755)
    add_workspace_file(env_template)

    runner = work_root / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh"
    runner.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            f"DEFAULT_WITNESS_DIR={shlex.quote(str(dirs['final_content_witness']))}",
            f"DEFAULT_MINIMAL_SLICE={shlex.quote(str(dirs['minimal_slice'] / 'minimal_slice_rows.csv'))}",
            f"DEFAULT_OPERATOR_INPUT_ROOT={shlex.quote(str(dirs['operator_input_root']))}",
            f"DEFAULT_OUTPUT_ROOT={shlex.quote(str(dirs['output_root']))}",
            "export V61GI_CONTENT_WITNESS_DIR=\"${V61GI_CONTENT_WITNESS_DIR:-$DEFAULT_WITNESS_DIR}\"",
            "export V61GI_MINIMAL_SLICE_ROWS_CSV=\"${V61GI_MINIMAL_SLICE_ROWS_CSV:-$DEFAULT_MINIMAL_SLICE}\"",
            "export V61GI_OPERATOR_INPUT_ROOT=\"${V61GI_OPERATOR_INPUT_ROOT:-$DEFAULT_OPERATOR_INPUT_ROOT}\"",
            "export V61GI_OUTPUT_ROOT=\"${V61GI_OUTPUT_ROOT:-$DEFAULT_OUTPUT_ROOT}\"",
            ": \"${V61GI_REVIEWER_ID:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace reviewer id}\"",
            ": \"${V61GI_ADJUDICATOR_ID:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace adjudicator id}\"",
            ": \"${V61GI_GENERATION_ID:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace generation id}\"",
            ": \"${V61GI_CITATION_ID:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace citation id}\"",
            ": \"${V61GI_CHECKPOINT_ROOT:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace checkpoint root}\"",
            ": \"${V61GI_LATENCY_ROW_ID:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace latency row id}\"",
            ": \"${V61GI_PROMPT_TOKENS:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace prompt tokens}\"",
            ": \"${V61GI_OUTPUT_TOKENS:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace output tokens}\"",
            ": \"${V61GI_PREFILL_MS:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace prefill ms}\"",
            ": \"${V61GI_DECODE_MS:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace decode ms}\"",
            ": \"${V61GI_TOTAL_MS:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace total ms}\"",
            ": \"${V61GI_TOKENS_PER_SECOND:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace tokens per second}\"",
            ": \"${V61GI_V53_AUTHORITY_STATEMENT:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace review authority statement}\"",
            ": \"${V61GI_V61_AUTHORITY_STATEMENT:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace generation authority statement}\"",
            ": \"${V61GI_EXTERNAL_RETURN_ATTESTATION:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace return attestation}\"",
            ": \"${V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT:?source FIRST_REAL_SLICE_ENV_TEMPLATE.sh and replace assembly authority statement}\"",
            "\"$ROOT_DIR/results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/RUN_WITNESS_DIR_TO_DUAL_REPLAY_IF_FINAL.sh\"",
            "",
        ]),
        encoding="utf-8",
    )
    runner.chmod(0o755)
    add_workspace_file(runner)

    verifier = work_root / "VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh"
    verifier.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -d \"$DIR/final_content_witness\"",
            "test -d \"$DIR/content_witness_templates\"",
            "test -d \"$DIR/minimal_slice\"",
            "test -d \"$DIR/operator_roots/operator_input_root\"",
            "test -d \"$DIR/operator_roots/output_root\"",
            "test -x \"$DIR/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh\"",
            "test -x \"$DIR/FIRST_REAL_SLICE_ENV_TEMPLATE.sh\"",
            "for name in review_comment.txt adjudication_reason.txt credential_statement.txt conflict_statement.txt answer_text.txt run_transcript.txt source_file.txt; do",
            "  test -s \"$DIR/content_witness_templates/$name.template\"",
            "done",
            "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
            "  echo 'payload-like file in first real slice workspace' >&2",
            "  exit 1",
            "fi",
            "",
        ]),
        encoding="utf-8",
    )
    verifier.chmod(0o755)
    add_workspace_file(verifier)

    readme = work_root / "FIRST_REAL_SLICE_OPERATOR_STEPS.md"
    readme.write_text(
        "\n".join([
            "# First Real Slice Operator Workspace",
            "",
            "1. Replace the seven files under `final_content_witness/` with final external content.",
            "2. Source `FIRST_REAL_SLICE_ENV_TEMPLATE.sh` and replace every `REPLACE_WITH_*` value.",
            "3. Run `VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh`.",
            "4. Run `RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh` only after the witness files and env values are final.",
            "",
            "This workspace is not evidence by itself. The v61gi/v61gj/v61gg gates must accept the generated roots before any real counter can be counted.",
            "",
        ]),
        encoding="utf-8",
    )
    add_workspace_file(readme)
    workspace_initialized = 1

if workspace_file_rows:
    write_csv(run_dir / "first_real_slice_external_workspace_file_rows.csv", list(workspace_file_rows[0].keys()), workspace_file_rows)
else:
    write_csv(run_dir / "first_real_slice_external_workspace_file_rows.csv", ["path", "bytes", "sha256", "metadata_only", "payload_like"], [])

final_witness_rows = []
final_witness_ready = 0
if work_root is not None:
    witness_dir = work_root / "final_content_witness"
    for filename in WITNESS_FILES:
        path = witness_dir / filename
        exists = int(path.is_file())
        final_witness_rows.append({
            "witness_file": filename,
            "expected_path": str(path),
            "exists": str(exists),
            "bytes": str(path.stat().st_size) if exists else "0",
            "sha256": sha256(path) if exists else "",
            "accepted_as_real_evidence": "0",
        })
    final_witness_ready = int(all(row["exists"] == "1" and int(row["bytes"]) > 0 for row in final_witness_rows))
else:
    for filename in WITNESS_FILES:
        final_witness_rows.append({
            "witness_file": filename,
            "expected_path": "",
            "exists": "0",
            "bytes": "0",
            "sha256": "",
            "accepted_as_real_evidence": "0",
        })
write_csv(run_dir / "first_real_slice_final_witness_rows.csv", list(final_witness_rows[0].keys()), final_witness_rows)

stage_rows = [
    {"stage_id": "01-v61gi-source", "status": "ready", "evidence": "v61gi scaffold ready"},
    {"stage_id": "02-v61gt-source", "status": "ready", "evidence": "v61gt handoff ready"},
    {"stage_id": "03-external-work-root", "status": "ready" if work_root_supplied and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "04-workspace-initialized", "status": "ready" if workspace_initialized else "blocked", "evidence": f"initialize_requested={initialize_workspace}; errors={';'.join(workspace_errors)}"},
    {"stage_id": "05-final-witness-files", "status": "ready" if final_witness_ready else "blocked", "evidence": f"final_witness_ready={final_witness_ready}; accepted_as_real_evidence=0"},
    {"stage_id": "06-minimal-slice-dual-replay", "status": "blocked", "evidence": "initializer never executes final replay"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_operator_workspace_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-package", "ready_to_run_now": "1", "command": "results/v61gu_post_gt_first_real_slice_operator_workspace_initializer/workspace_001/first_real_slice_operator_workspace_initializer/VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh", "purpose": "verify metadata package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gu_post_gt_first_real_slice_operator_workspace_initializer/workspace_001/first_real_slice_operator_workspace_initializer/READY_NOW_COMMANDS.sh", "purpose": "print external workspace commands"},
    {"command_id": "03-verify-external-workspace", "ready_to_run_now": str(workspace_initialized), "command": "V61GU_WORK_ROOT=<external-work-root> <external-work-root>/VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh", "purpose": "verify initialized external workspace layout"},
    {"command_id": "04-run-first-real-slice", "ready_to_run_now": "0", "command": "source <external-work-root>/FIRST_REAL_SLICE_ENV_TEMPLATE.sh && <external-work-root>/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh", "purpose": "run only after final external witness files and env values are filled"},
]
write_csv(run_dir / "first_real_slice_operator_workspace_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_OPERATOR_WORKSPACE_STAGE_ROWS.csv", run_dir / "first_real_slice_operator_workspace_stage_rows.csv"),
    ("FIRST_REAL_SLICE_OPERATOR_WORKSPACE_COMMAND_ROWS.csv", run_dir / "first_real_slice_operator_workspace_command_rows.csv"),
    ("FIRST_REAL_SLICE_FINAL_WITNESS_ROWS.csv", run_dir / "first_real_slice_final_witness_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_WORKSPACE_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FINAL_WITNESS_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gu package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'Initialize a repo-external first-real-slice workspace:'",
        "echo 'V61GU_INITIALIZE_WORKSPACE=1 V61GU_WORK_ROOT=<external-work-root> ./experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh'",
        "echo 'After initialization, fill <external-work-root>/final_content_witness and replace env values in FIRST_REAL_SLICE_ENV_TEMPLATE.sh.'",
        "echo 'Then run <external-work-root>/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh only after external finalization.'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gt_post_gs_ack_packet_to_replay_handoff_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_outside_repo": work_root_outside_repo,
    "workspace_initialize_requested": initialize_workspace,
    "workspace_initialized": workspace_initialized,
    "workspace_file_rows": len(workspace_file_rows),
    "template_witness_file_rows": len(WITNESS_FILES) if workspace_initialized else 0,
    "final_witness_file_rows": len(final_witness_rows),
    "final_witness_ready_rows": sum(row["exists"] == "1" and int(row["bytes"]) > 0 for row in final_witness_rows),
    "final_witness_accepted_as_real_evidence_rows": 0,
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "row_acceptance_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "payload_like_package_file_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "workspace_root": str(work_root) if work_root is not None else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_OPERATOR_WORKSPACE_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_operator_workspace_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "source-v61gt-ready", "status": "pass", "evidence": "v61gt ready"},
    {"gate": "external-work-root", "status": "pass" if work_root_supplied and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; outside_repo={work_root_outside_repo}"},
    {"gate": "workspace-initialized", "status": "pass" if workspace_initialized else "blocked", "evidence": f"workspace_initialized={workspace_initialized}; errors={';'.join(workspace_errors)}"},
    {"gate": "final-witness-files", "status": "blocked", "evidence": f"final_witness_ready={final_witness_ready}; initializer accepts no real evidence"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "initializer never executes final replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GU_POST_GT_FIRST_REAL_SLICE_OPERATOR_WORKSPACE_INITIALIZER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GU Post-GT First Real Slice Operator Workspace Initializer",
        "",
        "- v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready=1",
        f"- workspace_initialized={workspace_initialized}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this initializes the external operator workspace only. It does not count templates, directories, or witness placeholders as real external review/generation evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gu_post_gt_first_real_slice_operator_workspace_initializer_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
