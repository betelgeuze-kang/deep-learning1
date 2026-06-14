#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hm_post_hl_first_real_slice_readiness_pipeline"
RUN_ID="${V61HM_RUN_ID:-readiness_pipeline_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HM_WORK_ROOT:-${V61HL_WORK_ROOT:-${V61HK_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}"
PUBLISH_PIPELINE="${V61HM_PUBLISH_PIPELINE:-0}"
EXECUTE_FORM="${V61HM_EXECUTE_FORM:-0}"
EXECUTE_OPERATOR_INPUT="${V61HM_EXECUTE_OPERATOR_INPUT:-0}"
EXECUTE_ACK="${V61HM_EXECUTE_ACK:-0}"
RUN_READINESS="${V61HM_RUN_READINESS:-1}"

if [[ "${V61HM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hm_post_hl_first_real_slice_readiness_pipeline_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PIPELINE" "$EXECUTE_FORM" "$EXECUTE_OPERATOR_INPUT" "$EXECUTE_ACK" "$RUN_READINESS" <<'PY'
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
execute_form = int((sys.argv[7].strip() or "0") == "1")
execute_operator_input = int((sys.argv[8].strip() or "0") == "1")
execute_ack = int((sys.argv[9].strip() or "0") == "1")
run_readiness = int((sys.argv[10].strip() or "1") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_readiness_pipeline"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hm_post_hl_first_real_slice_readiness_pipeline"

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
    "operator_content_witness/review_comment.txt",
    "operator_content_witness/adjudication_reason.txt",
    "operator_content_witness/credential_statement.txt",
    "operator_content_witness/conflict_statement.txt",
    "operator_content_witness/answer_text.txt",
    "operator_content_witness/run_transcript.txt",
    "operator_content_witness/source_file.txt",
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


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def run_step(step_id, command, env=None, acceptable_returncodes={0}):
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
        "ready": str(int(proc.returncode in acceptable_returncodes)),
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
    }


work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_values = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
form_values_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py" if form_dir else None
form_handoff = form_dir / "VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_values = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json" if form_dir else None
ack_values_validator = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py" if form_dir else None
ack_handoff = form_dir / "BUILD_VALIDATE_AND_AUDIT_DUAL_REPLAY_AUTHORITY_ACK.sh" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
operator_handoff = work_root / "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh" if work_root else None
readiness_runner = work_root / "RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh" if work_root else None
operator_input_root = work_root / "operator_partial_return" / "operator_input_root" if work_root else None
output_root = work_root / "operator_partial_return" / "output_root" if work_root else None

form_values_supplied = int(form_values is not None and form_values.is_file())
ack_values_supplied = int(ack_values is not None and ack_values.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
ack_file_exists = int(ack_file is not None and ack_file.is_file())
operator_handoff_exists = int(operator_handoff is not None and operator_handoff.is_file())
readiness_runner_exists = int(readiness_runner is not None and readiness_runner.is_file())

published = 0
published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not publish_errors:
        runner = work_root / "RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh"
        readme = work_root / "FIRST_REAL_SLICE_READINESS_PIPELINE_README.md"
        runner.write_text(
            "\n".join([
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                f"ROOT_DIR={shlex.quote(str(root))}",
                "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
                "V61HM_WORK_ROOT=\"$WORK_ROOT\" \\",
                "V61HM_EXECUTE_FORM=\"${V61HM_EXECUTE_FORM:-0}\" \\",
                "V61HM_EXECUTE_OPERATOR_INPUT=\"${V61HM_EXECUTE_OPERATOR_INPUT:-0}\" \\",
                "V61HM_EXECUTE_ACK=\"${V61HM_EXECUTE_ACK:-0}\" \\",
                "V61HM_RUN_READINESS=\"${V61HM_RUN_READINESS:-1}\" \\",
                "\"$ROOT_DIR/experiments/run_v61hm_post_hl_first_real_slice_readiness_pipeline.sh\"",
                "",
            ]),
            encoding="utf-8",
        )
        runner.chmod(0o755)
        readme.write_text(
            "\n".join([
                "# First Real Slice Readiness Pipeline",
                "",
                "Default mode is status/readiness only. It never enables subset dual replay.",
                "After real values are supplied, run phases explicitly:",
                "",
                "```bash",
                "V61HM_EXECUTE_FORM=1 ./RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh",
                "V61HM_EXECUTE_OPERATOR_INPUT=1 ./RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh",
                "V61HM_EXECUTE_ACK=1 ./RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh",
                "./RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
                "```",
                "",
            ]),
            encoding="utf-8",
        )
        published = 1
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
write_csv(run_dir / "first_real_slice_readiness_pipeline_published_rows.csv", list(published_rows[0].keys()), published_rows)

step_rows = []
form_values_validation_ready = 0
if form_values_supplied and form_values_validator is not None and form_values_validator.is_file():
    report = run_dir / "form_values.validation_rows.csv"
    row = run_step("01-form-values-preflight", [str(form_values_validator), str(form_values), str(report)])
    form_values_validation_ready = int(row["ready"] == "1")
    step_rows.append(row)
else:
    step_rows.append(run_step("01-form-values-preflight", None))

if execute_form:
    row = run_step("02-build-validate-materialize-form", [str(form_handoff)] if form_handoff is not None and form_handoff.is_file() else None)
    step_rows.append(row)
else:
    step_rows.append(run_step("02-build-validate-materialize-form", None))

filled_form_exists = int(filled_form is not None and filled_form.is_file())

operator_input_no_replay_ready = 0
if execute_operator_input:
    env = os.environ.copy()
    env.update({
        "V61HG_EXECUTE_DUAL_REPLAY": "0",
        "V61HG_OVERWRITE_OPERATOR_INPUT": os.environ.get("V61HM_OVERWRITE_OPERATOR_INPUT", "1"),
    })
    row = run_step(
        "03-materialize-operator-input-no-replay",
        [str(operator_handoff)] if operator_handoff is not None and operator_handoff.is_file() else None,
        env=env,
        acceptable_returncodes={3},
    )
    operator_input_no_replay_ready = int(row["ready"] == "1")
    step_rows.append(row)
else:
    step_rows.append(run_step("03-materialize-operator-input-no-replay", None))

ack_values_validation_ready = 0
if ack_values_supplied and ack_values_validator is not None and ack_values_validator.is_file():
    report = run_dir / "ack_values.validation_rows.csv"
    row = run_step("04-ack-values-preflight", [str(ack_values_validator), str(ack_values), str(report)])
    ack_values_validation_ready = int(row["ready"] == "1")
    step_rows.append(row)
else:
    step_rows.append(run_step("04-ack-values-preflight", None))

if execute_ack:
    row = run_step("05-build-validate-authority-ack", [str(ack_handoff)] if ack_handoff is not None and ack_handoff.is_file() else None)
    step_rows.append(row)
else:
    step_rows.append(run_step("05-build-validate-authority-ack", None))

ack_file_exists = int(ack_file is not None and ack_file.is_file())

if run_readiness and readiness_runner_exists:
    row = run_step("06-readiness-audit", [str(readiness_runner)])
    step_rows.append(row)
else:
    step_rows.append(run_step("06-readiness-audit", None))

write_csv(run_dir / "first_real_slice_readiness_pipeline_step_rows.csv", list(step_rows[0].keys()), step_rows)

operator_file_rows = []
for rel in OPERATOR_INPUT_RELS:
    path = operator_input_root / rel if operator_input_root else None
    exists = int(path is not None and path.is_file())
    operator_file_rows.append({
        "relative_path": rel,
        "exists": str(exists),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": sha256(path) if exists else "",
    })
write_csv(run_dir / "first_real_slice_readiness_pipeline_operator_input_file_rows.csv", list(operator_file_rows[0].keys()), operator_file_rows)
operator_input_files_ready = int(all(row["exists"] == "1" for row in operator_file_rows))

dual_output_roots_ready = int(
    output_root is not None
    and (output_root / "v53" / "REAL_EXTERNAL_RETURN_PROVENANCE.json").is_file()
    and (output_root / "v61" / "review_return_provenance" / "REAL_REVIEW_RETURN_PROVENANCE.json").is_file()
)

if not work_root_exists:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not form_values_supplied:
    next_action = "create-first-real-slice-external-return-values-json"
elif not form_values_validation_ready:
    next_action = "fix-first-real-slice-external-return-values"
elif not filled_form_exists:
    next_action = "execute-form-build-materialize-phase"
elif not operator_input_files_ready:
    next_action = "execute-operator-input-no-replay-phase"
elif not ack_values_supplied:
    next_action = "create-dual-replay-authority-ack-values-json"
elif not ack_values_validation_ready:
    next_action = "fix-dual-replay-authority-ack-values"
elif not ack_file_exists:
    next_action = "execute-authority-ack-build-phase"
else:
    next_action = "run-real-subset-execution-readiness-audit"

stage_rows = [
    {"stage_id": "01-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "02-form-values", "status": "ready" if form_values_validation_ready else "blocked", "evidence": f"supplied={form_values_supplied}; validation_ready={form_values_validation_ready}"},
    {"stage_id": "03-filled-form", "status": "ready" if filled_form_exists else "blocked", "evidence": f"filled_form_exists={filled_form_exists}"},
    {"stage_id": "04-operator-input-no-replay", "status": "ready" if operator_input_files_ready else "blocked", "evidence": f"operator_input_files_ready={operator_input_files_ready}; no_replay_step_ready={operator_input_no_replay_ready}"},
    {"stage_id": "05-ack-values", "status": "ready" if ack_values_validation_ready else "blocked", "evidence": f"supplied={ack_values_supplied}; validation_ready={ack_values_validation_ready}"},
    {"stage_id": "06-authority-ack", "status": "ready" if ack_file_exists else "blocked", "evidence": f"ack_file_exists={ack_file_exists}"},
    {"stage_id": "07-dual-output-roots", "status": "ready" if dual_output_roots_ready else "blocked", "evidence": f"dual_output_roots_ready={dual_output_roots_ready}"},
    {"stage_id": "08-subset-dual-replay", "status": "blocked", "evidence": "pipeline intentionally never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
]
write_csv(run_dir / "first_real_slice_readiness_pipeline_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_READINESS_PIPELINE_STEP_ROWS.csv", run_dir / "first_real_slice_readiness_pipeline_step_rows.csv"),
    ("FIRST_REAL_SLICE_READINESS_PIPELINE_STAGE_ROWS.csv", run_dir / "first_real_slice_readiness_pipeline_stage_rows.csv"),
    ("FIRST_REAL_SLICE_READINESS_PIPELINE_OPERATOR_INPUT_FILE_ROWS.csv", run_dir / "first_real_slice_readiness_pipeline_operator_input_file_rows.csv"),
    ("FIRST_REAL_SLICE_READINESS_PIPELINE_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_readiness_pipeline_published_rows.csv"),
]:
    (package_dir / rel).write_bytes(src.read_bytes())

summary = {
    "v61hm_post_hl_first_real_slice_readiness_pipeline_ready": "1",
    "work_root_supplied": str(work_root_supplied),
    "work_root_exists": str(work_root_exists),
    "work_root_outside_repo": str(work_root_outside_repo),
    "publish_requested": str(publish_requested),
    "pipeline_published": str(published),
    "form_values_supplied": str(form_values_supplied),
    "form_values_validation_ready": str(form_values_validation_ready),
    "execute_form_requested": str(execute_form),
    "filled_form_exists": str(filled_form_exists),
    "execute_operator_input_requested": str(execute_operator_input),
    "operator_input_files_ready": str(operator_input_files_ready),
    "operator_input_no_replay_ready": str(operator_input_no_replay_ready),
    "ack_values_supplied": str(ack_values_supplied),
    "ack_values_validation_ready": str(ack_values_validation_ready),
    "execute_ack_requested": str(execute_ack),
    "authority_ack_exists": str(ack_file_exists),
    "readiness_audit_requested": str(run_readiness),
    "dual_output_roots_ready": str(dual_output_roots_ready),
    "next_real_subset_action": next_action,
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61hm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "step_rows": str(len(step_rows)),
    "ready_step_rows": str(sum(row["ready"] == "1" for row in step_rows)),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-values", "status": "pass" if form_values_validation_ready else "blocked", "evidence": f"form_values_validation_ready={form_values_validation_ready}"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": f"filled_form_exists={filled_form_exists}"},
    {"gate": "operator-input-no-replay", "status": "pass" if operator_input_files_ready else "blocked", "evidence": f"operator_input_files_ready={operator_input_files_ready}"},
    {"gate": "ack-values", "status": "pass" if ack_values_validation_ready else "blocked", "evidence": f"ack_values_validation_ready={ack_values_validation_ready}"},
    {"gate": "authority-ack", "status": "pass" if ack_file_exists else "blocked", "evidence": f"authority_ack_exists={ack_file_exists}"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "readiness pipeline does not execute dual replay"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "evidence": "generation_acceptance_closure_ready=0"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "claim_boundary": "readiness pipeline only; subset dual replay remains explicit and blocked here",
}
(package_dir / "FIRST_REAL_SLICE_READINESS_PIPELINE_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "VERIFY_FIRST_REAL_SLICE_READINESS_PIPELINE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_READINESS_PIPELINE_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_READINESS_PIPELINE_STEP_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_READINESS_PIPELINE_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_READINESS_PIPELINE_OPERATOR_INPUT_FILE_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_READINESS_PIPELINE.sh").chmod(0o755)
(run_dir / "V61HM_POST_HL_FIRST_REAL_SLICE_READINESS_PIPELINE_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HM First Real Slice Readiness Pipeline",
        "",
        f"- pipeline_published={published}",
        f"- form_values_validation_ready={form_values_validation_ready}",
        f"- filled_form_exists={filled_form_exists}",
        f"- operator_input_files_ready={operator_input_files_ready}",
        f"- ack_values_validation_ready={ack_values_validation_ready}",
        f"- authority_ack_exists={ack_file_exists}",
        f"- next_real_subset_action={next_action}",
        "- subset_dual_replay_executed=0",
        "- row_acceptance_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_rows = []
for path in package_files:
    package_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "executes_dual_replay": "0",
    })
write_csv(run_dir / "first_real_slice_readiness_pipeline_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = str(len(package_rows))
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hm_post_hl_first_real_slice_readiness_pipeline_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
