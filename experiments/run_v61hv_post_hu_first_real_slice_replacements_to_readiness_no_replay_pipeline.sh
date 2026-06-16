#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline"
RUN_ID="${V61HV_RUN_ID:-replacements_to_readiness_no_replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HV_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HU_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HQ_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_PIPELINE="${V61HV_PUBLISH_PIPELINE:-0}"
EXECUTE_PIPELINE="${V61HV_EXECUTE_PIPELINE:-0}"

if [[ "${V61HV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PIPELINE" "$EXECUTE_PIPELINE" <<'V61HV_PY'
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
package_dir = run_dir / "first_real_slice_replacements_to_readiness_no_replay_pipeline"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline"

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
replacements = form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv" if form_dir else None
replacement_template = form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template" if form_dir else None
replacement_applier = form_dir / "APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py" if form_dir else None
replacement_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py" if form_dir else None
env_to_readiness = work_root / "RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh" if work_root else None
readiness_audit = work_root / "RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh" if work_root else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_values = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
operator_input_root = work_root / "operator_partial_return" / "operator_input_root" if work_root else None
dual_output_root = work_root / "operator_partial_return" / "output_root" if work_root else None

replacements_exists = int(replacements is not None and replacements.is_file())
replacement_template_exists = int(replacement_template is not None and replacement_template.is_file())
replacement_applier_exists = int(replacement_applier is not None and replacement_applier.is_file())
replacement_validator_exists = int(replacement_validator is not None and replacement_validator.is_file())
env_to_readiness_exists = int(env_to_readiness is not None and env_to_readiness.is_file())
readiness_audit_exists = int(readiness_audit is not None and readiness_audit.is_file())

runner_text = """#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORM_DIR="$WORK_ROOT/external_return_form"
REPLACEMENTS="${V61HV_REPLACEMENTS_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv}"
APPLY="$FORM_DIR/APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
VALIDATE="$FORM_DIR/VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
VALIDATION_REPORT="${V61HV_REPLACEMENTS_REPORT:-$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv}"
NO_REPLAY="$WORK_ROOT/RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh"
if [[ ! -f "$REPLACEMENTS" ]]; then
  echo "missing replacements file: $REPLACEMENTS" >&2
  echo "copy and fill: $FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template" >&2
  exit 2
fi
if [[ ! -x "$APPLY" ]]; then
  echo "missing replacement applier: $APPLY" >&2
  exit 2
fi
if [[ ! -x "$VALIDATE" ]]; then
  echo "missing replacement validator: $VALIDATE" >&2
  exit 2
fi
if [[ ! -x "$NO_REPLAY" ]]; then
  echo "missing no-replay readiness pipeline: $NO_REPLAY" >&2
  exit 2
fi
"$VALIDATE" "$REPLACEMENTS" "$VALIDATION_REPORT"
APPLY_ARGS=("--replacements" "$REPLACEMENTS")
if [[ "${V61HV_OVERWRITE_BACKUP:-1}" == "1" ]]; then
  APPLY_ARGS+=("--overwrite")
fi
"$APPLY" "${APPLY_ARGS[@]}"
V61HQ_OVERWRITE_VALUES="${V61HV_OVERWRITE_VALUES:-1}" \\
V61HQ_CAPTURE_ACK_VALUES="${V61HV_CAPTURE_ACK_VALUES:-1}" \\
V61HQ_EXECUTE_ACK="${V61HV_EXECUTE_ACK:-1}" \\
V61HQ_OVERWRITE_OPERATOR_INPUT="${V61HV_OVERWRITE_OPERATOR_INPUT:-1}" \\
"$NO_REPLAY"
"""

readme_text = "\n".join([
    "# First Real Slice Replacements To Readiness No-Replay Pipeline",
    "",
    "This runner is the shortest no-replay path after real operator values are supplied.",
    "It applies `FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv` transactionally, then runs the existing env-file to readiness pipeline.",
    "",
    "It never sets `V61HG_EXECUTE_DUAL_REPLAY=1`.",
    "",
    "```bash",
    "cp external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv",
    "$EDITOR external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv",
    "./RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh",
    "```",
    "",
])

validator_text = r'''#!/usr/bin/env python3
import argparse
import csv
import sys
from pathlib import Path

PLACEHOLDER_TOKENS = [
    "REPLACE_WITH",
    "TEMPLATE",
    "FIXTURE",
    "SYNTHETIC",
    "PLACEHOLDER",
    "TODO",
]


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def min_length_from_action(action):
    marker = "at least "
    if marker not in action:
        return 0
    tail = action.split(marker, 1)[1]
    number = tail.split(" ", 1)[0]
    try:
        return int(number)
    except ValueError:
        return 0


def classify_replacement(key, source, value):
    value_stripped = value.strip()
    upper_value = value_stripped.upper()
    action = (source.get("required_action") or "").lower()
    if not value_stripped:
        return "blocked", "empty-replacement-value"
    if any(token in upper_value for token in PLACEHOLDER_TOKENS):
        return "blocked", "placeholder-token"
    if "set to true" in action or key.endswith("OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN"):
        if value_stripped.lower() != "true":
            return "blocked", "expected-true"
    if "positive" in action or key.endswith(("_TOKENS", "_MS", "_TOKENS_PER_SECOND")):
        try:
            positive = float(value_stripped) > 0
        except ValueError:
            positive = False
        if not positive:
            return "blocked", "not-positive-number"
    min_len = min_length_from_action(action)
    if min_len and len(value_stripped) < min_len:
        return "blocked", f"too-short-min-{min_len}"
    return "pass", "replacement-value-present-redacted"


def main():
    parser = argparse.ArgumentParser(description="Redacted preflight for first-slice replacement CSV.")
    parser.add_argument("replacements", nargs="?", default="")
    parser.add_argument("report", nargs="?", default="")
    args = parser.parse_args()
    form_dir = Path(__file__).resolve().parent
    replacements = Path(args.replacements).expanduser().resolve() if args.replacements else form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv"
    report = Path(args.report).expanduser().resolve() if args.report else form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv"
    repair_todo = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv"
    rows = []
    if not repair_todo.is_file():
        write_csv(report, ["env_name", "field_path", "status", "evidence", "contains_value"], [{
            "env_name": "",
            "field_path": "",
            "status": "blocked",
            "evidence": "repair-todo-missing",
            "contains_value": "0",
        }])
        raise SystemExit(2)
    repair_rows = [row for row in read_csv(repair_todo) if row.get("current_status") != "pass"]
    required = {row.get("env_name", ""): row for row in repair_rows if row.get("env_name")}
    if not replacements.is_file():
        rows.append({
            "env_name": "",
            "field_path": "",
            "status": "blocked",
            "evidence": "replacements-file-missing",
            "contains_value": "0",
        })
        write_csv(report, ["env_name", "field_path", "status", "evidence", "contains_value"], rows)
        raise SystemExit(2)
    replacement_rows = read_csv(replacements)
    seen = {}
    duplicate_keys = set()
    unknown_keys = set()
    for idx, row in enumerate(replacement_rows, start=2):
        key = (row.get("env_name") or "").strip()
        if not key:
            continue
        if key in seen:
            duplicate_keys.add(key)
        seen[key] = row
        if key not in required:
            unknown_keys.add(key)
    for key, source in required.items():
        row = seen.get(key)
        value = "" if row is None else str(row.get("replacement_value", ""))
        value_stripped = value.strip()
        contains_value = int(bool(value_stripped))
        if row is None:
            status, evidence = "blocked", "missing-required-replacement-row"
        elif key in duplicate_keys:
            status, evidence = "blocked", "duplicate-replacement-row"
        else:
            status, evidence = classify_replacement(key, source, value_stripped)
        rows.append({
            "env_name": key,
            "field_path": source.get("field_path", ""),
            "status": status,
            "evidence": evidence,
            "contains_value": str(contains_value),
        })
    for key in sorted(unknown_keys):
        rows.append({
            "env_name": key,
            "field_path": "",
            "status": "blocked",
            "evidence": "unknown-replacement-key",
            "contains_value": str(int(bool(str(seen[key].get("replacement_value", "")).strip()))),
        })
    write_csv(report, ["env_name", "field_path", "status", "evidence", "contains_value"], rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    print(f"replacement rows checked: {len(rows)}")
    print(f"blocked rows: {len(blocked)}")
    raise SystemExit(0 if not blocked else 2)


if __name__ == "__main__":
    main()
'''

validator_runner_text = """#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLACEMENTS="${V61HV_REPLACEMENTS_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv}"
REPORT="${V61HV_REPLACEMENTS_REPORT:-$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.validation_rows.csv}"
exec "$FORM_DIR/VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py" "$REPLACEMENTS" "$REPORT"
"""

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not replacement_template_exists:
        publish_errors.append("replacement-template-missing")
    if not replacement_applier_exists:
        publish_errors.append("replacement-applier-missing")
    if not env_to_readiness_exists:
        publish_errors.append("env-to-readiness-runner-missing")
    if not publish_errors:
        runner = work_root / "RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh"
        readme = work_root / "FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_README.md"
        validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
        validator_runner = form_dir / "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh"
        runner.write_text(runner_text, encoding="utf-8")
        runner.chmod(0o755)
        readme.write_text(readme_text, encoding="utf-8")
        validator.write_text(validator_text, encoding="utf-8")
        validator.chmod(0o755)
        validator_runner.write_text(validator_runner_text, encoding="utf-8")
        validator_runner.chmod(0o755)
        for path in [runner, readme, validator, validator_runner]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_replacements_to_readiness_published_rows.csv", list(published_rows[0].keys()), published_rows)

step_rows = []
runner_path = work_root / "RUN_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY.sh" if work_root else None
if execute_requested and runner_path is not None and runner_path.is_file():
    env = os.environ.copy()
    env.setdefault("V61HV_OVERWRITE_BACKUP", "1")
    env.setdefault("V61HV_OVERWRITE_VALUES", "1")
    env.setdefault("V61HV_CAPTURE_ACK_VALUES", "1")
    env.setdefault("V61HV_EXECUTE_ACK", "1")
    env.setdefault("V61HV_OVERWRITE_OPERATOR_INPUT", "1")
    row = run_command("01-replacements-to-readiness-no-replay", [str(runner_path)], env=env)
    step_rows.append(row)
else:
    step_rows.append(run_command("01-replacements-to-readiness-no-replay", None))
write_csv(run_dir / "first_real_slice_replacements_to_readiness_step_rows.csv", list(step_rows[0].keys()), step_rows)
replacements_to_readiness_ready = int(any(row["ready"] == "1" for row in step_rows))

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
elif not replacement_template_exists:
    next_action = "publish-replacement-template"
elif not replacements_exists:
    next_action = "fill-first-real-slice-values-replacements-csv"
elif not replacement_applier_exists:
    next_action = "publish-replacement-applier"
elif not env_to_readiness_exists:
    next_action = "publish-env-file-to-readiness-no-replay-runner"
elif not values_file_exists:
    next_action = "run-replacements-to-readiness-no-replay-pipeline"
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
    {"gate": "replacement-template", "status": "pass" if replacement_template_exists else "blocked", "evidence": str(replacement_template) if replacement_template_exists else "missing"},
    {"gate": "replacement-values-file", "status": "pass" if replacements_exists else "blocked", "evidence": str(replacements) if replacements_exists else "missing"},
    {"gate": "replacement-applier", "status": "pass" if replacement_applier_exists else "blocked", "evidence": str(replacement_applier) if replacement_applier_exists else "missing"},
    {"gate": "replacement-validator", "status": "pass" if replacement_validator_exists or (publish_requested and not publish_errors) else "blocked", "evidence": str(replacement_validator) if replacement_validator_exists else "published-with-v61hv" if publish_requested and not publish_errors else "missing"},
    {"gate": "env-to-readiness-no-replay-runner", "status": "pass" if env_to_readiness_exists else "blocked", "evidence": str(env_to_readiness) if env_to_readiness_exists else "missing"},
    {"gate": "published-runner", "status": "pass" if publish_requested and not publish_errors else "blocked", "evidence": f"publish_requested={publish_requested}; errors={';'.join(publish_errors)}"},
    {"gate": "pipeline-execution", "status": "pass" if replacements_to_readiness_ready else "blocked", "evidence": f"execute_requested={execute_requested}; ready={replacements_to_readiness_ready}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "operator-input-root", "status": "pass" if operator_input_files_ready else "blocked", "evidence": f"present={len(operator_present)}/{len(OPERATOR_INPUT_RELS)}"},
    {"gate": "authority-ack", "status": "pass" if ack_file_exists else "blocked", "evidence": str(ack_file) if ack_file_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hv never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until explicit subset dual replay outputs are accepted"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "evidence": "generation_acceptance_closure_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; v61hv does not run model generation"},
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
manifest_path = package_dir / "FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_PIPELINE.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_replacements_to_readiness_published_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_replacements_to_readiness_step_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_MANIFEST.json\"",
        "echo \"first real slice replacements to readiness no-replay pipeline packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HV_POST_HU_FIRST_REAL_SLICE_REPLACEMENTS_TO_READINESS_NO_REPLAY_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hv Boundary",
        "",
        "This step publishes a no-replay pipeline from replacement CSV application to readiness audit.",
        "It delegates transactional env replacement to v61hu and readiness execution to v61hq/v61hm.",
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
    run_dir / "first_real_slice_replacements_to_readiness_published_rows.csv",
    run_dir / "first_real_slice_replacements_to_readiness_step_rows.csv",
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
    "replacements_to_readiness_ready": replacements_to_readiness_ready,
    "replacement_template_exists": replacement_template_exists,
    "replacements_file_exists": replacements_exists,
    "replacement_applier_exists": replacement_applier_exists,
    "replacement_validator_exists": int(replacement_validator_exists or (publish_requested and not publish_errors)),
    "env_to_readiness_runner_exists": env_to_readiness_exists,
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
    "checkpoint_payload_bytes_downloaded_by_v61hv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HV_PY
