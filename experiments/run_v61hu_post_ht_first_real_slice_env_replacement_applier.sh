#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hu_post_ht_first_real_slice_env_replacement_applier"
RUN_ID="${V61HU_RUN_ID:-env_replacement_applier_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HU_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HT_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HS_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_APPLIER="${V61HU_PUBLISH_APPLIER:-0}"
APPLY_REPLACEMENTS="${V61HU_APPLY_REPLACEMENTS:-0}"

if [[ "${V61HU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hu_post_ht_first_real_slice_env_replacement_applier_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_APPLIER" "$APPLY_REPLACEMENTS" <<'V61HU_PY'
import csv
import hashlib
import json
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
work_root_raw = sys.argv[5].strip()
publish_requested = int((sys.argv[6].strip() or "0") == "1")
apply_requested = int((sys.argv[7].strip() or "0") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_env_replacement_applier"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hu_post_ht_first_real_slice_env_replacement_applier"


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


applier_text = r'''#!/usr/bin/env python3
import argparse
import csv
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def parse_env(path):
    values = {}
    key_order = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        if "=" not in line:
            continue
        key, value_text = line.split("=", 1)
        key = key.strip()
        try:
            tokens = shlex.split(value_text, posix=True)
        except ValueError:
            continue
        if len(tokens) != 1:
            continue
        if key not in values:
            key_order.append(key)
        values[key] = tokens[0]
    return values, key_order


def shell_line(key, value):
    return f"export {key}={shlex.quote(str(value))}"


def read_replacements(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    replacements = {}
    errors = []
    for idx, row in enumerate(rows, start=2):
        key = (row.get("env_name") or "").strip()
        if not key:
            errors.append(f"row {idx}: missing env_name")
            continue
        if key in replacements:
            errors.append(f"row {idx}: duplicate env_name {key}")
            continue
        if "replacement_value" not in row:
            errors.append(f"row {idx}: missing replacement_value column")
            continue
        replacements[key] = row.get("replacement_value", "")
    return replacements, errors


def main():
    parser = argparse.ArgumentParser(description="Apply real replacement values to FIRST_REAL_SLICE_VALUES.env transactionally.")
    parser.add_argument("--env-file", default="")
    parser.add_argument("--replacements", default="")
    parser.add_argument("--report", default="")
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    form_dir = Path(__file__).resolve().parent
    env_file = Path(args.env_file).expanduser().resolve() if args.env_file else form_dir / "FIRST_REAL_SLICE_VALUES.env"
    replacements_file = Path(args.replacements).expanduser().resolve() if args.replacements else form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv"
    report = Path(args.report).expanduser().resolve() if args.report else form_dir / "FIRST_REAL_SLICE_VALUES.env.replacement_preflight_rows.csv"
    repair_todo = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv"
    preflight = form_dir / "VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py"
    if not env_file.is_file():
        raise SystemExit(f"missing-env-file:{env_file}")
    if not replacements_file.is_file():
        raise SystemExit(f"missing-replacements-file:{replacements_file}")
    if not repair_todo.is_file():
        raise SystemExit(f"missing-repair-todo:{repair_todo}")
    if not preflight.is_file():
        raise SystemExit(f"missing-preflight-validator:{preflight}")
    repair_rows = []
    with repair_todo.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row.get("current_status") != "pass":
                repair_rows.append(row)
    required_keys = [row["env_name"] for row in repair_rows if row.get("env_name")]
    replacements, errors = read_replacements(replacements_file)
    unknown = sorted(set(replacements) - set(required_keys))
    missing = [key for key in required_keys if key not in replacements or replacements.get(key, "") == ""]
    errors.extend(f"unknown replacement key: {key}" for key in unknown)
    errors.extend(f"missing replacement key: {key}" for key in missing)
    if errors:
        for item in errors:
            print(f"replacement-apply-blocked:{item}", file=sys.stderr)
        raise SystemExit(2)
    current, key_order = parse_env(env_file)
    for key in required_keys:
        if key not in current:
            key_order.append(key)
        current[key] = replacements[key]
    tmp = env_file.with_suffix(env_file.suffix + ".candidate")
    tmp.write_text("\n".join(shell_line(key, current[key]) for key in key_order) + "\n", encoding="utf-8")
    proc = subprocess.run([str(preflight), str(tmp), str(report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    backup = env_file.with_suffix(env_file.suffix + ".bak")
    if backup.exists() and not args.overwrite:
        tmp.unlink(missing_ok=True)
        raise SystemExit(f"backup-exists-use-overwrite:{backup}")
    shutil.copyfile(env_file, backup)
    shutil.move(str(tmp), str(env_file))
    print(f"replacement apply ready: {env_file}")
    print(f"preflight report: {report}")


if __name__ == "__main__":
    main()
'''

runner_text = """#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLIER="$FORM_DIR/APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
ARGS=()
if [[ "${V61HU_OVERWRITE_BACKUP:-0}" == "1" ]]; then
  ARGS+=("--overwrite")
fi
exec "$APPLIER" "${ARGS[@]}"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
env_file = form_dir / "FIRST_REAL_SLICE_VALUES.env" if form_dir else None
repair_todo = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv" if form_dir else None
replacements = form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv" if form_dir else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None

repair_rows = read_csv(repair_todo) if repair_todo is not None and repair_todo.is_file() else []
replacement_template_rows = []
for row in repair_rows:
    if row.get("current_status") == "pass":
        continue
    replacement_template_rows.append({
        "env_name": row.get("env_name", ""),
        "field_path": row.get("field_path", ""),
        "replacement_value": "",
        "required_action": row.get("required_action", ""),
    })
if not replacement_template_rows:
    replacement_template_rows.append({"env_name": "", "field_path": "", "replacement_value": "", "required_action": "no repair rows"})

replacement_template = run_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template"
write_csv(replacement_template, ["env_name", "field_path", "replacement_value", "required_action"], replacement_template_rows)

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if env_file is None or not env_file.is_file():
        publish_errors.append("env-file-missing")
    if repair_todo is None or not repair_todo.is_file():
        publish_errors.append("repair-todo-missing")
    if not publish_errors:
        applier = form_dir / "APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
        runner = form_dir / "RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh"
        template_dst = form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template"
        readme = form_dir / "FIRST_REAL_SLICE_VALUES_REPLACEMENTS_README.md"
        applier.write_text(applier_text, encoding="utf-8")
        applier.chmod(0o755)
        runner.write_text(runner_text, encoding="utf-8")
        runner.chmod(0o755)
        template_dst.write_bytes(replacement_template.read_bytes())
        readme.write_text(
            "\n".join([
                "# First Real Slice Values Replacements",
                "",
                "Copy the template to `FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv`, fill `replacement_value` for every row, then apply it transactionally.",
                "The applier writes a candidate env file, runs the existing env preflight, and only then replaces `FIRST_REAL_SLICE_VALUES.env`.",
                "",
                "```bash",
                "cp external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv",
                "$EDITOR external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv",
                "external_return_form/RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh",
                "```",
                "",
                "This applier does not write values JSON, materialize forms, build acks, run replay, or create generation evidence.",
                "",
            ]),
            encoding="utf-8",
        )
        for path in [applier, runner, template_dst, readme]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "contains_values": "0",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "contains_values": "0", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_values_replacement_applier_published_rows.csv", list(published_rows[0].keys()), published_rows)

apply_ready = 0
apply_exit_code = "not-run"
apply_blocked_rows = 0
if apply_requested and form_dir is not None:
    applier = form_dir / "APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py"
    if applier.is_file():
        proc = subprocess.run([str(applier)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (run_dir / "replacement-apply.stdout.txt").write_text(proc.stdout, encoding="utf-8")
        (run_dir / "replacement-apply.stderr.txt").write_text(proc.stderr, encoding="utf-8")
        apply_exit_code = str(proc.returncode)
        apply_ready = int(proc.returncode == 0)
        report = form_dir / "FIRST_REAL_SLICE_VALUES.env.replacement_preflight_rows.csv"
        if report.is_file():
            with report.open(newline="", encoding="utf-8") as handle:
                apply_blocked_rows = sum(1 for row in csv.DictReader(handle) if row.get("status") != "pass")
    else:
        apply_exit_code = "applier-missing"

env_file_exists = int(env_file is not None and env_file.is_file())
repair_todo_exists = int(repair_todo is not None and repair_todo.is_file())
replacements_exists = int(replacements is not None and replacements.is_file())
values_file_exists = int(values_file is not None and values_file.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not replacements_exists:
    next_action = "fill-first-real-slice-values-replacements-csv"
elif not apply_ready:
    next_action = "apply-first-real-slice-values-replacements"
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
    {"gate": "env-file", "status": "pass" if env_file_exists else "blocked", "evidence": str(env_file) if env_file_exists else "missing"},
    {"gate": "repair-todo", "status": "pass" if repair_todo_exists else "blocked", "evidence": str(repair_todo) if repair_todo_exists else "missing"},
    {"gate": "replacements-file", "status": "pass" if replacements_exists else "blocked", "evidence": str(replacements) if replacements_exists else "missing"},
    {"gate": "replacement-apply", "status": "pass" if apply_ready else "blocked", "evidence": f"apply_requested={apply_requested}; exit={apply_exit_code}; blocked_rows={apply_blocked_rows}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hu never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; replacement applier does not run generation"},
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
    "apply_requested": apply_requested,
    "contains_values": False,
    "writes_values_json": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template\"",
        "test -s \"$RUN_DIR/first_real_slice_values_replacement_applier_published_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER_MANIFEST.json\"",
        "echo \"first real slice env replacement applier packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HU_POST_HT_FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hu Boundary",
        "",
        "This step publishes a transactional env replacement applier.",
        "It does not include replacement values in generated reports and does not write values JSON, forms, acks, replay outputs, or generation evidence.",
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
    replacement_template,
    run_dir / "first_real_slice_values_replacement_applier_published_rows.csv",
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
    "replacement_applier_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "replacement_template_rows": len(replacement_template_rows),
    "replacement_template_contains_values": 0,
    "apply_requested": apply_requested,
    "replacement_apply_ready": apply_ready,
    "replacement_apply_exit_code": apply_exit_code,
    "replacement_apply_blocked_rows": apply_blocked_rows,
    "env_file_exists": env_file_exists,
    "repair_todo_exists": repair_todo_exists,
    "replacements_file_exists": replacements_exists,
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
    "checkpoint_payload_bytes_downloaded_by_v61hu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hu_post_ht_first_real_slice_env_replacement_applier_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HU_PY
