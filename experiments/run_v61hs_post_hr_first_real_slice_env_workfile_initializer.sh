#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hs_post_hr_first_real_slice_env_workfile_initializer"
RUN_ID="${V61HS_RUN_ID:-env_workfile_initializer_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HS_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HR_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HQ_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_INITIALIZER="${V61HS_PUBLISH_INITIALIZER:-0}"
INITIALIZE_ENV="${V61HS_INITIALIZE_ENV:-0}"

if [[ "${V61HS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hs_post_hr_first_real_slice_env_workfile_initializer_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_INITIALIZER" "$INITIALIZE_ENV" <<'V61HS_PY'
import csv
import hashlib
import json
import shutil
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
initialize_requested = int((sys.argv[7].strip() or "0") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_env_workfile_initializer"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hs_post_hr_first_real_slice_env_workfile_initializer"


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


initializer_text = """#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${V61HS_VALUES_ENV_TEMPLATE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.template}"
ENV_FILE="${V61HS_VALUES_ENV_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env}"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "missing env template: $TEMPLATE" >&2
  exit 2
fi
if [[ -e "$ENV_FILE" && "${V61HS_OVERWRITE_ENV:-0}" != "1" ]]; then
  echo "env workfile already exists: $ENV_FILE" >&2
  echo "set V61HS_OVERWRITE_ENV=1 only if you intend to reset the workfile" >&2
  exit 3
fi
cp "$TEMPLATE" "$ENV_FILE"
chmod 600 "$ENV_FILE" 2>/dev/null || true
echo "first real-slice env workfile initialized: $ENV_FILE"
echo "edit the placeholders, then run: $FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
env_template = form_dir / "FIRST_REAL_SLICE_VALUES.env.template" if form_dir else None
env_file = form_dir / "FIRST_REAL_SLICE_VALUES.env" if form_dir else None
preflight_runner = form_dir / "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh" if form_dir else None
preflight_report = form_dir / "FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv" if form_dir else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None

env_exists_before = int(env_file is not None and env_file.is_file())
template_exists = int(env_template is not None and env_template.is_file())
preflight_runner_exists = int(preflight_runner is not None and preflight_runner.is_file())

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not template_exists:
        publish_errors.append("env-template-missing")
    if not publish_errors:
        runner = form_dir / "RUN_INITIALIZE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh"
        readme = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_WORKFILE_README.md"
        runner.write_text(initializer_text, encoding="utf-8")
        runner.chmod(0o755)
        readme.write_text(
            "\n".join([
                "# First Real Slice Values Env Workfile",
                "",
                "Run the initializer once to create the editable `FIRST_REAL_SLICE_VALUES.env` workfile from the template.",
                "The initialized file still contains placeholders and must fail preflight until real external values are entered.",
                "",
                "```bash",
                "external_return_form/RUN_INITIALIZE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
                "$EDITOR external_return_form/FIRST_REAL_SLICE_VALUES.env",
                "external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
                "```",
                "",
                "This initializer does not create values JSON, filled forms, authority acks, replay outputs, or generation evidence.",
                "",
            ]),
            encoding="utf-8",
        )
        for path in [runner, readme]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "writes_values": "0",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "writes_values": "0", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_env_workfile_initializer_published_rows.csv", list(published_rows[0].keys()), published_rows)

initialized = 0
initialize_status = "not-requested"
if initialize_requested:
    if form_dir is None or not form_dir.is_dir():
        initialize_status = "external-return-form-dir-missing"
    elif env_template is None or not env_template.is_file():
        initialize_status = "env-template-missing"
    elif env_file is not None and env_file.exists():
        initialize_status = "env-workfile-exists"
    else:
        shutil.copyfile(env_template, env_file)
        try:
            env_file.chmod(0o600)
        except OSError:
            pass
        initialized = 1
        initialize_status = "initialized-from-template"

env_exists_after = int(env_file is not None and env_file.is_file())

preflight_ready = 0
preflight_blocked_rows = 0
local_report = run_dir / "first_real_slice_values_env_workfile_preflight_rows.csv"
if env_exists_after and preflight_runner_exists:
    proc = subprocess.run([str(preflight_runner)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (run_dir / "workfile-preflight.stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "workfile-preflight.stderr.txt").write_text(proc.stderr, encoding="utf-8")
    preflight_ready = int(proc.returncode == 0)
    if preflight_report is not None and preflight_report.is_file():
        shutil.copyfile(preflight_report, local_report)
    if local_report.is_file():
        with local_report.open(newline="", encoding="utf-8") as handle:
            preflight_blocked_rows = sum(1 for row in csv.DictReader(handle) if row["status"] != "pass")
else:
    rows = []
    if not env_exists_after:
        rows.append({"env_name": "FIRST_REAL_SLICE_VALUES.env", "field_path": "file", "status": "blocked", "required": "1", "evidence": "env-file-missing"})
    elif not preflight_runner_exists:
        rows.append({"env_name": "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh", "field_path": "preflight-runner", "status": "blocked", "required": "1", "evidence": "preflight-runner-missing"})
    write_csv(local_report, ["env_name", "field_path", "status", "required", "evidence"], rows)
    preflight_blocked_rows = len(rows)

values_file_exists = int(values_file is not None and values_file.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not env_exists_after:
    next_action = "initialize-first-real-slice-values-env-workfile"
elif not preflight_ready:
    next_action = "replace-placeholder-values-in-first-real-slice-env-file"
elif not values_file_exists:
    next_action = "run-env-file-capture-handoff"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not authority_ack_exists:
    next_action = "build-dual-replay-authority-ack"
else:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "env-template", "status": "pass" if template_exists else "blocked", "evidence": str(env_template) if template_exists else "missing"},
    {"gate": "env-workfile", "status": "pass" if env_exists_after else "blocked", "evidence": str(env_file) if env_exists_after else "missing"},
    {"gate": "env-workfile-preflight", "status": "pass" if preflight_ready else "blocked", "evidence": f"blocked_rows={preflight_blocked_rows}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hs never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; env initializer does not run model generation"},
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
    "initialize_requested": initialize_requested,
    "initialize_status": initialize_status,
    "writes_values": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_env_workfile_initializer_published_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_values_env_workfile_preflight_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER_MANIFEST.json\"",
        "echo \"first real slice env workfile initializer packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HS_POST_HR_FIRST_REAL_SLICE_ENV_WORKFILE_INITIALIZER_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hs Boundary",
        "",
        "This step initializes the editable env workfile from the template.",
        "The initialized workfile still contains placeholders and is expected to fail preflight until real external values are entered.",
        "It does not write values JSON, materialize forms, build acks, run replay, or create model-generation evidence.",
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
    run_dir / "first_real_slice_env_workfile_initializer_published_rows.csv",
    local_report,
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
    "initializer_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "initialize_requested": initialize_requested,
    "env_workfile_initialized": initialized,
    "initialize_status": initialize_status,
    "env_template_exists": template_exists,
    "env_file_exists_before": env_exists_before,
    "env_file_exists_after": env_exists_after,
    "env_file_preflight_ready": preflight_ready,
    "env_file_preflight_blocked_rows": preflight_blocked_rows,
    "form_values_supplied": values_file_exists,
    "filled_form_exists": filled_form_exists,
    "authority_ack_exists": authority_ack_exists,
    "next_real_subset_action": next_action,
    "row_acceptance_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hs_post_hr_first_real_slice_env_workfile_initializer_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HS_PY
