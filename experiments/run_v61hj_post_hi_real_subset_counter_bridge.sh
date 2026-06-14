#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hj_post_hi_real_subset_counter_bridge"
RUN_ID="${V61HJ_RUN_ID:-counter_bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HJ_WORK_ROOT:-${V61HI_WORK_ROOT:-${V61HH_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}"
EXECUTE_BRIDGE="${V61HJ_EXECUTE_BRIDGE:-0}"
RUN_PARTIAL_AUDIT="${V61HJ_RUN_PARTIAL_AUDIT:-1}"
PUBLISH_BRIDGE="${V61HJ_PUBLISH_BRIDGE:-0}"

if [[ "${V61HJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hj_post_hi_real_subset_counter_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$WORK_ROOT" "$EXECUTE_BRIDGE" "$RUN_PARTIAL_AUDIT" "$PUBLISH_BRIDGE" <<'PY'
import csv
import hashlib
import json
import os
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
run_id = sys.argv[5]
work_root_raw = sys.argv[6].strip()
execute_bridge = int((sys.argv[7].strip() or "0") == "1")
run_partial_audit_requested = int((sys.argv[8].strip() or "1") == "1")
publish_bridge_requested = int((sys.argv[9].strip() or "0") == "1")
results = root / "results"
prefix = "v61hj_post_hi_real_subset_counter_bridge"
package_dir = run_dir / "real_subset_counter_bridge"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GF_PREFIX = "v61gf_post_ge_dual_partial_return_replay_admission"
GJ_PREFIX = "v61gj_post_gi_operator_input_receiver"
HI_PREFIX = "v61hi_post_hh_real_subset_execution_readiness_audit"
HH_PREFIX = "v61hh_post_hg_dual_replay_authority_ack_publisher"
HG_PREFIX = "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"

FINAL_OPERATOR_INPUT_RELS = [
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

COUNTER_KEYS = [
    "real_external_review_return_rows",
    "real_adjudication_rows",
    "slice_answer_review_accepted_rows",
    "row_acceptance_ready",
    "generation_execution_admission_ready",
    "real_generation_result_artifacts",
    "accepted_generation_result_artifacts",
    "generation_result_accepted_rows",
    "accepted_answer_rows",
    "accepted_citation_rows",
    "accepted_latency_rows",
    "generation_result_row_acceptance_ready",
    "dual_external_return_real_ready",
    "real_return_replay_admission_ready",
    "generation_acceptance_closure_ready",
    "actual_model_generation_ready",
    "production_latency_claim_ready",
    "near_frontier_claim_ready",
    "v1_0_comparison_ready",
    "real_release_package_ready",
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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except (TypeError, ValueError):
        return 0


def status(flag):
    return "pass" if flag else "blocked"


def copy_optional_source(source_id, src, folder, rows):
    if not src.is_file():
        rows.append({
            "source_id": source_id,
            "path": str(src),
            "present": "0",
            "bytes": "0",
            "sha256": "",
            "metadata_only": "1",
        })
        return
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    rows.append({
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "present": "1",
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    })


def run_validator(label, command, report_path):
    stdout_path = run_dir / f"{label}.stdout.txt"
    stderr_path = run_dir / f"{label}.stderr.txt"
    if not command:
        report_path.write_text("check_id,status,evidence\nvalidator,blocked,missing\n", encoding="utf-8")
        stdout_path.write_text("", encoding="utf-8")
        stderr_path.write_text("validator-or-input-missing\n", encoding="utf-8")
        return 0, "not-run"
    proc = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_path.write_text(proc.stdout, encoding="utf-8")
    stderr_path.write_text(proc.stderr, encoding="utf-8")
    return int(proc.returncode == 0), str(proc.returncode)


source_rows = []
optional_sources = {
    "v61hi_summary": results / f"{HI_PREFIX}_summary.csv",
    "v61hi_decision": results / f"{HI_PREFIX}_decision.csv",
    "v61hh_summary": results / f"{HH_PREFIX}_summary.csv",
    "v61hg_summary": results / f"{HG_PREFIX}_summary.csv",
    "v61gp_summary": results / f"{GP_PREFIX}_summary.csv",
    "v61gj_summary": results / f"{GJ_PREFIX}_summary.csv",
    "v61gf_summary": results / f"{GF_PREFIX}_summary.csv",
}
for source_id, path in optional_sources.items():
    copy_optional_source(source_id, path, "optional_sources", source_rows)
write_csv(run_dir / "real_subset_counter_bridge_source_rows.csv", list(source_rows[0].keys()), source_rows)

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_path = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_path = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
form_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" if form_dir else None
ack_validator = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py" if form_dir else None
bridge_wrapper = work_root / "RUN_OPERATOR_REPLAY_WITH_AUTHORITY_ACK_FILE.sh" if work_root else None
operator_handoff = work_root / "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh" if work_root else None
operator_work_root = work_root / "operator_partial_return" if work_root else None
operator_input_root = operator_work_root / "operator_input_root" if operator_work_root else None
output_root = operator_work_root / "output_root" if operator_work_root else None
v53_root = output_root / "v53" if output_root else None
v61_root = output_root / "v61" if output_root else None

form_supplied = int(form_path is not None and form_path.is_file())
ack_supplied = int(ack_path is not None and ack_path.is_file())
form_validation_report = run_dir / "filled_form.validation_rows.csv"
ack_validation_report = run_dir / "dual_replay_authority_ack.validation_rows.csv"
form_command = None
if form_supplied and form_validator is not None and form_validator.is_file():
    form_command = [str(form_validator), str(form_path), str(form_validation_report)]
form_validation_ready, form_validation_exit_code = run_validator("filled_form.validation", form_command, form_validation_report)

ack_command = None
if ack_supplied and form_supplied and ack_validator is not None and ack_validator.is_file():
    ack_command = [str(ack_validator), str(ack_path), str(form_path), str(ack_validation_report)]
ack_validation_ready, ack_validation_exit_code = run_validator("dual_replay_authority_ack.validation", ack_command, ack_validation_report)

published_bridge = 0
publish_errors = []
published_rows = []
if publish_bridge_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not publish_errors:
        runner = work_root / "RUN_REAL_SUBSET_COUNTER_BRIDGE.sh"
        readme = work_root / "REAL_SUBSET_COUNTER_BRIDGE_README.md"
        runner.write_text(
            "\n".join([
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                f"ROOT_DIR={shlex.quote(str(root))}",
                "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
                "V61HJ_WORK_ROOT=\"$WORK_ROOT\" \\",
                "V61HJ_EXECUTE_BRIDGE=\"${V61HJ_EXECUTE_BRIDGE:-0}\" \\",
                "V61HJ_RUN_PARTIAL_AUDIT=\"${V61HJ_RUN_PARTIAL_AUDIT:-1}\" \\",
                "\"$ROOT_DIR/experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh\"",
                "",
            ]),
            encoding="utf-8",
        )
        runner.chmod(0o755)
        readme.write_text(
            "\n".join([
                "# Real Subset Counter Bridge",
                "",
                "This runner audits the first real slice workspace and can optionally execute the guarded dual-root replay.",
                "Default execution is read-only with respect to replay: set `V61HJ_EXECUTE_BRIDGE=1` only after the filled form and authority ack are final.",
                "The bridge counts only what v61gd/v61ge/v61gf accept from the assembled output roots.",
                "",
            ]),
            encoding="utf-8",
        )
        published_bridge = 1
        for path in [runner, readme]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "executes_replay_by_default": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_replay_by_default": "0"})
write_csv(run_dir / "real_subset_counter_bridge_published_rows.csv", list(published_rows[0].keys()), published_rows)

bridge_execute_admitted = int(
    execute_bridge
    and work_root_exists
    and work_root_outside_repo
    and form_validation_ready
    and ack_validation_ready
    and bridge_wrapper is not None
    and bridge_wrapper.is_file()
    and os.access(bridge_wrapper, os.X_OK)
)
bridge_executed = 0
bridge_exit_code = "not-run"
bridge_blockers = []
if execute_bridge and not bridge_execute_admitted:
    if not work_root_exists:
        bridge_blockers.append("work-root-missing")
    if not work_root_outside_repo:
        bridge_blockers.append("work-root-inside-repo-or-missing")
    if not form_validation_ready:
        bridge_blockers.append("filled-form-validation-blocked")
    if not ack_validation_ready:
        bridge_blockers.append("authority-ack-validation-blocked")
    if bridge_wrapper is None or not bridge_wrapper.is_file():
        bridge_blockers.append("authority-ack-wrapper-missing")
    elif not os.access(bridge_wrapper, os.X_OK):
        bridge_blockers.append("authority-ack-wrapper-not-executable")

bridge_stdout = run_dir / "real_subset_counter_bridge.execute_stdout.txt"
bridge_stderr = run_dir / "real_subset_counter_bridge.execute_stderr.txt"
if bridge_execute_admitted:
    env = os.environ.copy()
    env.setdefault("V61HG_OVERWRITE_OPERATOR_INPUT", os.environ.get("V61HJ_OVERWRITE_OPERATOR_INPUT", "0"))
    proc = subprocess.run([str(bridge_wrapper)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    bridge_executed = 1
    bridge_exit_code = str(proc.returncode)
    bridge_stdout.write_text(proc.stdout, encoding="utf-8")
    bridge_stderr.write_text(proc.stderr, encoding="utf-8")
else:
    bridge_stdout.write_text("", encoding="utf-8")
    bridge_stderr.write_text(("bridge-not-executed:" + ";".join(bridge_blockers) + "\n") if bridge_blockers else "bridge-not-requested\n", encoding="utf-8")

operator_file_rows = []
for rel in FINAL_OPERATOR_INPUT_RELS:
    path = operator_input_root / rel if operator_input_root else None
    exists = int(path is not None and path.is_file())
    operator_file_rows.append({
        "relative_path": rel,
        "exists": str(exists),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": sha256(path) if exists else "",
    })
write_csv(run_dir / "real_subset_counter_bridge_operator_input_file_rows.csv", list(operator_file_rows[0].keys()), operator_file_rows)
operator_input_files_ready = int(all(row["exists"] == "1" for row in operator_file_rows))

v53_marker = v53_root / "REAL_EXTERNAL_RETURN_PROVENANCE.json" if v53_root else None
v61_marker = v61_root / "review_return_provenance" / "REAL_REVIEW_RETURN_PROVENANCE.json" if v61_root else None
root_rows = []
for root_id, path, marker in [
    ("work_root", work_root, None),
    ("operator_input_root", operator_input_root, None),
    ("output_root", output_root, None),
    ("v53_external_return_root", v53_root, v53_marker),
    ("v61_generation_intake_return_root", v61_root, v61_marker),
]:
    exists = int(path is not None and path.is_dir())
    marker_ready = int(marker is not None and marker.is_file())
    root_rows.append({
        "root_id": root_id,
        "path": str(path) if path else "",
        "exists": str(exists),
        "outside_repo": str(int(path is not None and not is_inside(path, root))),
        "marker_path": str(marker) if marker else "",
        "marker_ready": str(marker_ready),
    })
write_csv(run_dir / "real_subset_counter_bridge_root_rows.csv", list(root_rows[0].keys()), root_rows)
dual_output_roots_ready = int(v53_marker is not None and v53_marker.is_file() and v61_marker is not None and v61_marker.is_file())

partial_audit_executed = 0
partial_audit_exit_code = "not-run"
partial_audit_ready = 0
partial_stdout = run_dir / "real_subset_counter_bridge.partial_audit_stdout.txt"
partial_stderr = run_dir / "real_subset_counter_bridge.partial_audit_stderr.txt"
gf_summary = {}
if dual_output_roots_ready and run_partial_audit_requested:
    env = os.environ.copy()
    env.update({
        "V61GF_RUN_ID": f"{run_id}_gf_counter_audit",
        "V61GF_V53_RETURN_ROOT": str(v53_root),
        "V61GF_V53_RETURN_PROVENANCE": "real-external-return-bundle",
        "V61GF_V61_RETURN_ROOT": str(v61_root),
        "V61GF_V61_RETURN_PROVENANCE": "real-generation-intake-return-bundle",
        "V61GF_REUSE_EXISTING": "0",
    })
    proc = subprocess.run(
        [str(root / "experiments" / "run_v61gf_post_ge_dual_partial_return_replay_admission.sh")],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    partial_audit_executed = 1
    partial_audit_exit_code = str(proc.returncode)
    partial_stdout.write_text(proc.stdout, encoding="utf-8")
    partial_stderr.write_text(proc.stderr, encoding="utf-8")
    if proc.returncode == 0 and (results / f"{GF_PREFIX}_summary.csv").is_file():
        gf_summary = read_csv(results / f"{GF_PREFIX}_summary.csv")[0]
        partial_audit_ready = int(gf_summary.get("v61gf_post_ge_dual_partial_return_replay_admission_ready") == "1")
        for label, path in {
            "v61gf_counter_summary": results / f"{GF_PREFIX}_summary.csv",
            "v61gf_counter_decision": results / f"{GF_PREFIX}_decision.csv",
            "v61gf_counter_stage_rows": results / GF_PREFIX / f"{run_id}_gf_counter_audit" / "dual_partial_return_replay_admission_stage_rows.csv",
            "v61gf_counter_command_rows": results / GF_PREFIX / f"{run_id}_gf_counter_audit" / "dual_partial_return_replay_admission_command_rows.csv",
        }.items():
            copy_optional_source(label, path, "counter_audit_sources", source_rows)
        write_csv(run_dir / "real_subset_counter_bridge_source_rows.csv", list(source_rows[0].keys()), source_rows)
else:
    partial_stdout.write_text("", encoding="utf-8")
    partial_stderr.write_text("partial-audit-not-run\n", encoding="utf-8")

counters = {key: 0 for key in COUNTER_KEYS}
for key in COUNTER_KEYS:
    counters[key] = as_int(gf_summary, key)
counters["actual_model_generation_ready"] = 0
counters["production_latency_claim_ready"] = 0
counters["near_frontier_claim_ready"] = 0
counters["v1_0_comparison_ready"] = 0
counters["real_release_package_ready"] = 0

counter_rows = []
for key in COUNTER_KEYS:
    target = "greater-than-zero" if key not in {
        "actual_model_generation_ready",
        "production_latency_claim_ready",
        "near_frontier_claim_ready",
        "v1_0_comparison_ready",
        "real_release_package_ready",
    } else "remains-blocked-in-subset"
    counter_rows.append({
        "counter": key,
        "value": str(counters[key]),
        "target": target,
        "status": "ready" if counters[key] > 0 and target == "greater-than-zero" else ("blocked" if target == "greater-than-zero" else "deferred"),
        "evidence": "v61gf counter audit" if partial_audit_ready else "no accepted dual-root counter audit yet",
    })
write_csv(run_dir / "real_subset_counter_bridge_counter_rows.csv", list(counter_rows[0].keys()), counter_rows)

subset_counters_opened = int(
    counters["real_external_review_return_rows"] > 0
    and counters["real_adjudication_rows"] > 0
    and counters["slice_answer_review_accepted_rows"] > 0
    and counters["real_generation_result_artifacts"] > 0
    and counters["accepted_generation_result_artifacts"] > 0
    and counters["generation_result_accepted_rows"] > 0
    and counters["dual_external_return_real_ready"] > 0
    and counters["real_return_replay_admission_ready"] > 0
    and counters["generation_acceptance_closure_ready"] > 0
)

if not work_root_exists:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not form_validation_ready:
    next_action = "fill-and-validate-first-real-slice-external-return-form"
elif not ack_validation_ready:
    next_action = "fill-and-validate-dual-replay-authority-ack"
elif not execute_bridge and not dual_output_roots_ready:
    next_action = "run-real-subset-counter-bridge-with-execute-flag"
elif execute_bridge and bridge_executed and bridge_exit_code != "0":
    next_action = "inspect-authority-ack-wrapper-execution-stderr"
elif not operator_input_files_ready:
    next_action = "materialize-operator-input-root-from-filled-form"
elif not dual_output_roots_ready:
    next_action = "run-guarded-dual-root-replay-with-authority-ack"
elif not partial_audit_ready:
    next_action = "run-v61gf-dual-partial-return-counter-audit"
elif subset_counters_opened:
    next_action = "subset-real-return-counters-opened"
else:
    next_action = "inspect-v61gf-partial-intake-validation-rows"

stage_rows = [
    {"stage_id": "01-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "02-filled-form", "status": "ready" if form_validation_ready else "blocked", "evidence": f"supplied={form_supplied}; exit_code={form_validation_exit_code}"},
    {"stage_id": "03-authority-ack", "status": "ready" if ack_validation_ready else "blocked", "evidence": f"supplied={ack_supplied}; exit_code={ack_validation_exit_code}"},
    {"stage_id": "04-bridge-published", "status": "ready" if published_bridge else ("blocked" if publish_bridge_requested else "deferred"), "evidence": f"publish_requested={publish_bridge_requested}; errors={';'.join(publish_errors)}"},
    {"stage_id": "05-bridge-execute-admitted", "status": "ready" if bridge_execute_admitted else "blocked", "evidence": f"execute_requested={execute_bridge}; blockers={';'.join(bridge_blockers)}"},
    {"stage_id": "06-bridge-executed", "status": "ready" if bridge_executed and bridge_exit_code == "0" else "blocked", "evidence": f"bridge_executed={bridge_executed}; exit_code={bridge_exit_code}"},
    {"stage_id": "07-operator-input-files", "status": "ready" if operator_input_files_ready else "blocked", "evidence": f"operator_input_files_ready={operator_input_files_ready}"},
    {"stage_id": "08-dual-output-roots", "status": "ready" if dual_output_roots_ready else "blocked", "evidence": f"dual_output_roots_ready={dual_output_roots_ready}"},
    {"stage_id": "09-v61gf-counter-audit", "status": "ready" if partial_audit_ready else "blocked", "evidence": f"partial_audit_executed={partial_audit_executed}; exit_code={partial_audit_exit_code}"},
    {"stage_id": "10-subset-real-counters-opened", "status": "ready" if subset_counters_opened else "blocked", "evidence": f"next_action={next_action}"},
    {"stage_id": "11-actual-model-generation", "status": "blocked", "evidence": "subset return/replay counters do not prove actual_model_generation_ready"},
]
write_csv(run_dir / "real_subset_counter_bridge_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-publish-bridge", "ready_to_run_now": str(int(work_root_exists and work_root_outside_repo)), "command": "V61HJ_PUBLISH_BRIDGE=1 ./experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh", "purpose": "publish workspace-local bridge runner"},
    {"command_id": "02-readiness-only", "ready_to_run_now": "1", "command": "V61HJ_EXECUTE_BRIDGE=0 ./experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh", "purpose": "audit current form/ack/root/counter state without executing replay"},
    {"command_id": "03-execute-guarded-bridge", "ready_to_run_now": str(int(form_validation_ready and ack_validation_ready)), "command": "V61HJ_EXECUTE_BRIDGE=1 ./experiments/run_v61hj_post_hi_real_subset_counter_bridge.sh", "purpose": "run authority-ack wrapper and v61gf counter audit"},
    {"command_id": "04-check-counters-opened", "ready_to_run_now": str(subset_counters_opened), "command": "results/v61hj_post_hi_real_subset_counter_bridge/counter_bridge_001/real_subset_counter_bridge/CHECK_REAL_SUBSET_COUNTERS_OPENED.py", "purpose": "assert requested subset counters are greater than zero"},
]
write_csv(run_dir / "real_subset_counter_bridge_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("REAL_SUBSET_COUNTER_BRIDGE_SOURCE_ROWS.csv", run_dir / "real_subset_counter_bridge_source_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_PUBLISHED_ROWS.csv", run_dir / "real_subset_counter_bridge_published_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_ROOT_ROWS.csv", run_dir / "real_subset_counter_bridge_root_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_OPERATOR_INPUT_FILE_ROWS.csv", run_dir / "real_subset_counter_bridge_operator_input_file_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_COUNTER_ROWS.csv", run_dir / "real_subset_counter_bridge_counter_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_STAGE_ROWS.csv", run_dir / "real_subset_counter_bridge_stage_rows.csv"),
    ("REAL_SUBSET_COUNTER_BRIDGE_COMMAND_ROWS.csv", run_dir / "real_subset_counter_bridge_command_rows.csv"),
    ("FILLED_FORM_VALIDATION_ROWS.csv", form_validation_report),
    ("DUAL_REPLAY_AUTHORITY_ACK_VALIDATION_ROWS.csv", ack_validation_report),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "NEXT_REAL_SUBSET_ACTION.txt").write_text(next_action + "\n", encoding="utf-8")
(package_dir / "CHECK_REAL_SUBSET_COUNTERS_OPENED.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        "with SUMMARY.open(newline='', encoding='utf-8') as handle:",
        "    row = next(csv.DictReader(handle))",
        "required_positive = [",
        "    'real_external_review_return_rows',",
        "    'real_adjudication_rows',",
        "    'slice_answer_review_accepted_rows',",
        "    'real_generation_result_artifacts',",
        "    'accepted_generation_result_artifacts',",
        "    'generation_result_accepted_rows',",
        "    'dual_external_return_real_ready',",
        "    'real_return_replay_admission_ready',",
        "    'generation_acceptance_closure_ready',",
        "]",
        "missing = [key for key in required_positive if int(row.get(key, '0') or '0') <= 0]",
        "if missing:",
        "    raise SystemExit('subset real counters not opened: ' + ','.join(missing))",
        "print('subset real counters opened')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_REAL_SUBSET_COUNTERS_OPENED.py").chmod(0o755)

summary = {
    "v61hj_post_hi_real_subset_counter_bridge_ready": "1",
    "work_root_supplied": str(work_root_supplied),
    "work_root_exists": str(work_root_exists),
    "work_root_outside_repo": str(work_root_outside_repo),
    "filled_form_supplied": str(form_supplied),
    "filled_form_validation_ready": str(form_validation_ready),
    "filled_form_validation_exit_code": form_validation_exit_code,
    "authority_ack_supplied": str(ack_supplied),
    "authority_ack_validation_ready": str(ack_validation_ready),
    "authority_ack_validation_exit_code": ack_validation_exit_code,
    "publish_bridge_requested": str(publish_bridge_requested),
    "published_bridge": str(published_bridge),
    "bridge_execute_requested": str(execute_bridge),
    "bridge_execute_admitted": str(bridge_execute_admitted),
    "bridge_executed": str(bridge_executed),
    "bridge_exit_code": bridge_exit_code,
    "operator_input_files_ready": str(operator_input_files_ready),
    "dual_output_roots_ready": str(dual_output_roots_ready),
    "partial_counter_audit_requested": str(run_partial_audit_requested),
    "partial_counter_audit_executed": str(partial_audit_executed),
    "partial_counter_audit_exit_code": partial_audit_exit_code,
    "partial_counter_audit_ready": str(partial_audit_ready),
    "subset_real_return_counters_opened": str(subset_counters_opened),
    "next_real_subset_action": next_action,
    "checkpoint_payload_bytes_downloaded_by_v61hj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "source_file_rows": str(len(source_rows)),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
}
for key in COUNTER_KEYS:
    summary[key] = str(counters[key])
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "work-root", "status": status(work_root_exists and work_root_outside_repo), "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "filled-form-validation", "status": status(form_validation_ready), "evidence": f"filled_form_validation_ready={form_validation_ready}"},
    {"gate": "authority-ack-validation", "status": status(ack_validation_ready), "evidence": f"authority_ack_validation_ready={ack_validation_ready}"},
    {"gate": "bridge-execute-admission", "status": status(bridge_execute_admitted), "evidence": f"bridge_execute_admitted={bridge_execute_admitted}; blockers={';'.join(bridge_blockers)}"},
    {"gate": "bridge-executed", "status": status(bridge_executed and bridge_exit_code == '0'), "evidence": f"bridge_executed={bridge_executed}; exit_code={bridge_exit_code}"},
    {"gate": "dual-output-roots", "status": status(dual_output_roots_ready), "evidence": f"dual_output_roots_ready={dual_output_roots_ready}"},
    {"gate": "v61gf-counter-audit", "status": status(partial_audit_ready), "evidence": f"partial_counter_audit_ready={partial_audit_ready}"},
    {"gate": "real-external-review-return", "status": status(counters["real_external_review_return_rows"] > 0), "evidence": f"real_external_review_return_rows={counters['real_external_review_return_rows']}"},
    {"gate": "review-row-acceptance", "status": status(counters["row_acceptance_ready"] > 0), "evidence": f"row_acceptance_ready={counters['row_acceptance_ready']}"},
    {"gate": "generation-result-artifact-acceptance", "status": status(counters["generation_result_accepted_rows"] > 0), "evidence": f"generation_result_accepted_rows={counters['generation_result_accepted_rows']}"},
    {"gate": "dual-root-replay-admission", "status": status(counters["real_return_replay_admission_ready"] > 0), "evidence": f"real_return_replay_admission_ready={counters['real_return_replay_admission_ready']}"},
    {"gate": "generation-acceptance-closure", "status": status(counters["generation_acceptance_closure_ready"] > 0), "evidence": f"generation_acceptance_closure_ready={counters['generation_acceptance_closure_ready']}"},
    {"gate": "actual-model-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "production-latency", "status": "blocked", "evidence": "production_latency_claim_ready=0"},
    {"gate": "near-frontier-quality", "status": "blocked", "evidence": "near_frontier_claim_ready=0"},
    {"gate": "v1.0-comparison", "status": "blocked", "evidence": "v1_0_comparison_ready=0"},
    {"gate": "release-readiness", "status": "blocked", "evidence": "real_release_package_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

package_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "next_real_subset_action": next_action,
    "claim_boundary": "subset counter bridge only; not actual model generation, production latency, near-frontier quality, v1.0 comparison, or release readiness",
}
(package_dir / "REAL_SUBSET_COUNTER_BRIDGE_MANIFEST.json").write_text(json.dumps(package_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "VERIFY_REAL_SUBSET_COUNTER_BRIDGE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/REAL_SUBSET_COUNTER_BRIDGE_MANIFEST.json\"",
        "test -s \"$DIR/REAL_SUBSET_COUNTER_BRIDGE_STAGE_ROWS.csv\"",
        "test -s \"$DIR/REAL_SUBSET_COUNTER_BRIDGE_COUNTER_ROWS.csv\"",
        "test -s \"$DIR/REAL_SUBSET_COUNTER_BRIDGE_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/NEXT_REAL_SUBSET_ACTION.txt\"",
        "test -x \"$DIR/CHECK_REAL_SUBSET_COUNTERS_OPENED.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hj package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_REAL_SUBSET_COUNTER_BRIDGE.sh").chmod(0o755)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "real_subset_counter_bridge_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = str(len(package_file_rows))
summary["metadata_only_package_file_rows"] = str(sum(row["metadata_only"] == "1" for row in package_file_rows))
summary["payload_like_package_file_rows"] = str(sum(row["payload_like"] == "1" for row in package_file_rows))
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

boundary = "\n".join([
    "# V61HJ Post-HI Real Subset Counter Bridge",
    "",
    "- v61hj_post_hi_real_subset_counter_bridge_ready=1",
    f"- work_root_exists={work_root_exists}",
    f"- filled_form_validation_ready={form_validation_ready}",
    f"- authority_ack_validation_ready={ack_validation_ready}",
    f"- bridge_execute_requested={execute_bridge}",
    f"- bridge_executed={bridge_executed}",
    f"- dual_output_roots_ready={dual_output_roots_ready}",
    f"- partial_counter_audit_ready={partial_audit_ready}",
    f"- subset_real_return_counters_opened={subset_counters_opened}",
    f"- real_external_review_return_rows={counters['real_external_review_return_rows']}",
    f"- real_adjudication_rows={counters['real_adjudication_rows']}",
    f"- slice_answer_review_accepted_rows={counters['slice_answer_review_accepted_rows']}",
    f"- real_generation_result_artifacts={counters['real_generation_result_artifacts']}",
    f"- accepted_generation_result_artifacts={counters['accepted_generation_result_artifacts']}",
    f"- generation_result_accepted_rows={counters['generation_result_accepted_rows']}",
    f"- real_return_replay_admission_ready={counters['real_return_replay_admission_ready']}",
    "- actual_model_generation_ready=0",
    "- production_latency_claim_ready=0",
    "- near_frontier_claim_ready=0",
    "- v1_0_comparison_ready=0",
    "- real_release_package_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    f"- next_real_subset_action={next_action}",
    "",
    "This bridge opens only subset-scope return/replay counters when real filled form, authority ack, assembled output roots, and v61gf acceptance all agree.",
    "",
])
(run_dir / "V61HJ_POST_HI_REAL_SUBSET_COUNTER_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "counters": counters,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hj_post_hi_real_subset_counter_bridge_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
