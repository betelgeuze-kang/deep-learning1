#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline"
RUN_ID="${V61HQ_RUN_ID:-env_file_to_readiness_no_replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HQ_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HP_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HO_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_PIPELINE="${V61HQ_PUBLISH_PIPELINE:-0}"
EXECUTE_PIPELINE="${V61HQ_EXECUTE_PIPELINE:-0}"

if [[ "${V61HQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PIPELINE" "$EXECUTE_PIPELINE" <<'V61HQ_PY'
import csv
import hashlib
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
work_root_raw = sys.argv[5].strip()
publish_requested = int((sys.argv[6].strip() or "0") == "1")
execute_requested = int((sys.argv[7].strip() or "0") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_env_file_to_readiness_no_replay_pipeline"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline"

OPERATOR_INPUT_RELS = [
    "v53/aggregate_review_return/human_review_rows.csv",
    "v53/aggregate_review_return/adjudication_rows.csv",
    "v53/aggregate_review_return/reviewer_identity_rows.csv",
    "v53/aggregate_review_return/reviewer_conflict_rows.csv",
    "v53/aggregate_review_return/acceptance_summary.json",
    "v53/operator_attestation/reviewer_authority_statement.txt",
    "v61/generation_result_return/real_model_generation_answer_rows.csv",
    "v61/generation_result_return/real_model_generation_citation_rows.csv",
    "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv",
    "v61/generation_result_return/real_model_generation_latency_rows.csv",
    "v61/generation_result_return/real_model_generation_acceptance_summary.json",
    "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
    "OPERATOR_INPUT_RECEIPT.json",
]


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def run_command(step_id, command, env=None):
    stdout_path = run_dir / f"{step_id}.stdout.txt"
    stderr_path = run_dir / f"{step_id}.stderr.txt"
    if not command:
        stdout_path.write_text("", encoding="utf-8")
        stderr_path.write_text("step-not-run\n", encoding="utf-8")
        return {
            "step_id": step_id,
            "requested": "0",
            "executed": "0",
            "exit_code": "not-run",
            "ready": "0",
            "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
            "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
        }
    proc = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_path.write_text(proc.stdout, encoding="utf-8")
    stderr_path.write_text(proc.stderr, encoding="utf-8")
    return {
        "step_id": step_id,
        "requested": "1",
        "executed": "1",
        "exit_code": str(proc.returncode),
        "ready": str(int(proc.returncode == 0)),
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
    }


work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
env_file = form_dir / "FIRST_REAL_SLICE_VALUES.env" if form_dir else None
env_template = form_dir / "FIRST_REAL_SLICE_VALUES.env.template" if form_dir else None
env_handoff = form_dir / "RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh" if form_dir else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_values = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
readiness_pipeline = work_root / "RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh" if work_root else None
readiness_audit = work_root / "RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh" if work_root else None
operator_input_root = work_root / "operator_partial_return" / "operator_input_root" if work_root else None
dual_output_root = work_root / "operator_partial_return" / "output_root" if work_root else None

env_file_exists = int(env_file is not None and env_file.is_file())
env_template_exists = int(env_template is not None and env_template.is_file())
env_handoff_exists = int(env_handoff is not None and env_handoff.is_file())
readiness_pipeline_exists = int(readiness_pipeline is not None and readiness_pipeline.is_file())
readiness_audit_exists = int(readiness_audit is not None and readiness_audit.is_file())

runner_text = f"""#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
FORM_DIR="$WORK_ROOT/external_return_form"
ENV_FILE="${{V61HQ_VALUES_ENV_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env}}"
CAPTURE="$FORM_DIR/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh"
READINESS="$WORK_ROOT/RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing env file: $ENV_FILE" >&2
  echo "copy and fill: $FORM_DIR/FIRST_REAL_SLICE_VALUES.env.template" >&2
  exit 2
fi
if [[ ! -x "$CAPTURE" ]]; then
  echo "missing capture handoff: $CAPTURE" >&2
  exit 2
fi
if [[ ! -x "$READINESS" ]]; then
  echo "missing readiness pipeline: $READINESS" >&2
  exit 2
fi
V61HP_VALUES_ENV_FILE="$ENV_FILE" \\
V61HP_OVERWRITE="${{V61HQ_OVERWRITE_VALUES:-1}}" \\
V61HP_CAPTURE_ACK_VALUES="${{V61HQ_CAPTURE_ACK_VALUES:-1}}" \\
"$CAPTURE"
V61HM_EXECUTE_FORM=1 \\
V61HM_EXECUTE_OPERATOR_INPUT=1 \\
V61HM_EXECUTE_ACK="${{V61HQ_EXECUTE_ACK:-1}}" \\
V61HM_RUN_READINESS=1 \\
V61HM_OVERWRITE_OPERATOR_INPUT="${{V61HQ_OVERWRITE_OPERATOR_INPUT:-1}}" \\
"$READINESS"
"""

readme_text = "\n".join([
    "# First Real Slice Env File To Readiness No-Replay Pipeline",
    "",
    "This runner consumes `external_return_form/FIRST_REAL_SLICE_VALUES.env` and executes the non-replay path:",
    "",
    "1. validator-gated values capture",
    "2. filled-form validation/materialization",
    "3. no-replay operator-input materialization",
    "4. authority ack build if ack values are captured",
    "5. readiness audit",
    "",
    "It never sets `V61HG_EXECUTE_DUAL_REPLAY=1`.",
    "",
    "```bash",
    "cp external_return_form/FIRST_REAL_SLICE_VALUES.env.template external_return_form/FIRST_REAL_SLICE_VALUES.env",
    "$EDITOR external_return_form/FIRST_REAL_SLICE_VALUES.env",
    "V61HQ_OVERWRITE_VALUES=1 ./RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh",
    "```",
    "",
])

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not env_handoff_exists:
        publish_errors.append("env-file-capture-handoff-missing")
    if not readiness_pipeline_exists:
        publish_errors.append("readiness-pipeline-missing")
    if not publish_errors:
        runner = work_root / "RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh"
        readme = work_root / "FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_README.md"
        runner.write_text(runner_text, encoding="utf-8")
        runner.chmod(0o755)
        readme.write_text(readme_text, encoding="utf-8")
        for path in [runner, readme]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_env_file_to_readiness_published_rows.csv", list(published_rows[0].keys()), published_rows)

step_rows = []
runner_path = work_root / "RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh" if work_root else None
if execute_requested and runner_path is not None and runner_path.is_file():
    env = os.environ.copy()
    env.setdefault("V61HQ_OVERWRITE_VALUES", "1")
    env.setdefault("V61HQ_CAPTURE_ACK_VALUES", "1")
    env.setdefault("V61HQ_EXECUTE_ACK", "1")
    env.setdefault("V61HQ_OVERWRITE_OPERATOR_INPUT", "1")
    row = run_command("01-env-file-to-readiness-no-replay", [str(runner_path)], env=env)
    step_rows.append(row)
else:
    step_rows.append(run_command("01-env-file-to-readiness-no-replay", None))
write_csv(run_dir / "first_real_slice_env_file_to_readiness_step_rows.csv", list(step_rows[0].keys()), step_rows)
no_replay_pipeline_ready = int(any(row["ready"] == "1" for row in step_rows))

values_file_exists = int(values_file is not None and values_file.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
ack_values_exists = int(ack_values is not None and ack_values.is_file())
ack_file_exists = int(ack_file is not None and ack_file.is_file())
operator_present = []
if operator_input_root is not None and operator_input_root.is_dir():
    operator_present = [rel for rel in OPERATOR_INPUT_RELS if (operator_input_root / rel).is_file()]
operator_input_files_ready = int(len(operator_present) == len(OPERATOR_INPUT_RELS))
dual_output_roots_ready = int(dual_output_root is not None and dual_output_root.is_dir() and any(dual_output_root.iterdir()))

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not env_file_exists:
    next_action = "fill-first-real-slice-values-env-file"
elif not values_file_exists:
    next_action = "run-env-file-to-readiness-no-replay-pipeline"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not operator_input_files_ready:
    next_action = "materialize-no-replay-operator-input-root"
elif not ack_values_exists:
    next_action = "capture-dual-replay-authority-ack-values"
elif not ack_file_exists:
    next_action = "build-dual-replay-authority-ack"
else:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "env-file", "status": "pass" if env_file_exists else "blocked", "evidence": str(env_file) if env_file_exists else "missing"},
    {"gate": "env-template", "status": "pass" if env_template_exists else "blocked", "evidence": str(env_template) if env_template_exists else "missing"},
    {"gate": "env-capture-handoff", "status": "pass" if env_handoff_exists else "blocked", "evidence": str(env_handoff) if env_handoff_exists else "missing"},
    {"gate": "readiness-pipeline", "status": "pass" if readiness_pipeline_exists else "blocked", "evidence": str(readiness_pipeline) if readiness_pipeline_exists else "missing"},
    {"gate": "published-runner", "status": "pass" if publish_requested and not publish_errors else "blocked", "evidence": f"publish_requested={publish_requested}; errors={';'.join(publish_errors)}"},
    {"gate": "no-replay-pipeline-execution", "status": "pass" if no_replay_pipeline_ready else "blocked", "evidence": f"execute_requested={execute_requested}; no_replay_pipeline_ready={no_replay_pipeline_ready}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "operator-input-root", "status": "pass" if operator_input_files_ready else "blocked", "evidence": f"present={len(operator_present)}/{len(OPERATOR_INPUT_RELS)}"},
    {"gate": "authority-ack", "status": "pass" if ack_file_exists else "blocked", "evidence": str(ack_file) if ack_file_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hq never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "evidence": "generation_acceptance_closure_ready=0 until accepted generation rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; v61hq does not run model generation"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, ["gate", "status", "evidence"], gate_rows)
write_csv(run_dir / f"{prefix}_decision.csv", ["gate", "status", "evidence"], gate_rows)

manifest = {
    "prefix": prefix,
    "run_id": run_dir.name,
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "work_root": str(work_root) if work_root else "",
    "publish_requested": publish_requested,
    "execute_requested": execute_requested,
    "executes_dual_replay": False,
    "sets_v61hg_execute_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_PIPELINE.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_env_file_to_readiness_published_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_env_file_to_readiness_step_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_MANIFEST.json\"",
        "echo \"first real slice env-file to readiness no-replay pipeline packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HQ_POST_HP_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hq Boundary",
        "",
        "This step publishes a no-replay pipeline from first-slice env file capture to readiness audit.",
        "It delegates values capture to v61hp/v61ho and readiness execution to v61hm.",
        "It never sets `V61HG_EXECUTE_DUAL_REPLAY=1` and does not create model-generation evidence.",
        "",
        f"- next_real_subset_action: {next_action}",
        "- row_acceptance_ready: 0",
        "- generation_acceptance_closure_ready: 0",
        "- actual_model_generation_ready: 0",
        "- checkpoint_payload_bytes_committed_to_repo: 0",
        "",
    ]),
    encoding="utf-8",
)
packet_files = [
    run_dir / "first_real_slice_env_file_to_readiness_published_rows.csv",
    run_dir / "first_real_slice_env_file_to_readiness_step_rows.csv",
    manifest_path,
    verify_path,
    boundary_path,
    run_dir / f"{prefix}_decision.csv",
]
sha_rows = [{"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": str(path.stat().st_size)} for path in packet_files]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    f"{prefix}_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "pipeline_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "execute_requested": execute_requested,
    "no_replay_pipeline_ready": no_replay_pipeline_ready,
    "env_file_exists": env_file_exists,
    "env_template_exists": env_template_exists,
    "env_handoff_exists": env_handoff_exists,
    "readiness_pipeline_exists": readiness_pipeline_exists,
    "readiness_audit_exists": readiness_audit_exists,
    "form_values_supplied": values_file_exists,
    "filled_form_exists": filled_form_exists,
    "operator_input_files_ready": operator_input_files_ready,
    "ack_values_supplied": ack_values_exists,
    "authority_ack_exists": ack_file_exists,
    "dual_output_roots_ready": dual_output_roots_ready,
    "next_real_subset_action": next_action,
    "row_acceptance_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hq_post_hp_first_real_slice_env_file_to_readiness_no_replay_pipeline_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HQ_PY
