#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hl_post_hk_dual_replay_authority_ack_fill_packet"
RUN_ID="${V61HL_RUN_ID:-ack_fill_packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HL_WORK_ROOT:-${V61HK_WORK_ROOT:-${V61HJ_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}"
PUBLISH_PACKET="${V61HL_PUBLISH_PACKET:-0}"

if [[ "${V61HL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hl_post_hk_dual_replay_authority_ack_fill_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PACKET" <<'PY'
import csv
import hashlib
import json
import os
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
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
prefix = "v61hl_post_hk_dual_replay_authority_ack_fill_packet"
package_dir = run_dir / "dual_replay_authority_ack_fill_packet"
package_dir.mkdir(parents=True, exist_ok=True)

VALUES_FILENAME = "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json"
VALUES_TEMPLATE_FILENAME = "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template"
VALUES_VALIDATOR_FILENAME = "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py"
BUILDER_FILENAME = "BUILD_DUAL_REPLAY_AUTHORITY_ACK_FROM_VALUES.py"
HANDOFF_FILENAME = "BUILD_VALIDATE_AND_AUDIT_DUAL_REPLAY_AUTHORITY_ACK.sh"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"
PROTOCOL = "v61hh-dual-replay-authority-ack-v1"


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


values_template_payload = {
    "authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_REPLAY_AUTHORITY_STATEMENT_80_CHARS_MIN",
    "operator_attests_real_external_return": True,
}

values_validator_text = r'''#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def add(rows, field_path, status, evidence):
    rows.append({"field_path": field_path, "status": status, "required": "1", "evidence": evidence})


def main():
    values_path = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path("DUAL_REPLAY_AUTHORITY_ACK_VALUES.json").resolve()
    report_path = Path(sys.argv[2]).expanduser().resolve() if len(sys.argv) > 2 else values_path.with_suffix(".validation_rows.csv")
    rows = []
    try:
        payload = json.loads(values_path.read_text(encoding="utf-8"))
    except Exception as exc:
        payload = {}
        add(rows, "values-json", "blocked", f"json-unreadable:{exc}")
    else:
        add(rows, "values-json", "pass" if isinstance(payload, dict) else "blocked", "json-readable" if isinstance(payload, dict) else "json-not-object")
        if not isinstance(payload, dict):
            payload = {}
    statement = payload.get("authority_statement", "")
    statement_ready = isinstance(statement, str) and len(statement.strip()) >= 80 and not has_nonfinal(statement)
    add(rows, "authority_statement", "pass" if statement_ready else "blocked", f"len={len(str(statement).strip())}; nonfinal={has_nonfinal(statement)}")
    attests = payload.get("operator_attests_real_external_return")
    add(rows, "operator_attests_real_external_return", "pass" if attests is True else "blocked", str(attests))
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["field_path", "status", "required", "evidence"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    if blocked:
        print(f"dual-replay-authority-ack-values-blocked:{len(blocked)} fields; report={report_path}", file=sys.stderr)
        raise SystemExit(2)
    print(f"dual replay authority ack values ready: {report_path}")


if __name__ == "__main__":
    main()
'''

builder_text = f'''#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROTOCOL = {PROTOCOL!r}
EXPECTED_ACK = {EXPECTED_ACK!r}


def sha256(path):
    import hashlib
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def main():
    script_dir = Path(__file__).resolve().parent
    work_root = script_dir.parent
    values_path = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else script_dir / "{VALUES_FILENAME}"
    ack_template = script_dir / "DUAL_REPLAY_AUTHORITY_ACK.json.template"
    form_path = script_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
    ack_path = script_dir / "DUAL_REPLAY_AUTHORITY_ACK.json"
    values_validator = script_dir / "{VALUES_VALIDATOR_FILENAME}"
    ack_validator = script_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py"
    values_report = script_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.validation_rows.csv"
    ack_report = script_dir / "DUAL_REPLAY_AUTHORITY_ACK.validation_rows.csv"
    if not values_validator.is_file():
        raise SystemExit(f"missing-values-validator:{{values_validator}}")
    proc = subprocess.run([str(values_validator), str(values_path), str(values_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    if not ack_template.is_file():
        raise SystemExit(f"missing-ack-template:{{ack_template}}")
    if not form_path.is_file():
        raise SystemExit(f"missing-filled-form:{{form_path}}")
    if not ack_validator.is_file():
        raise SystemExit(f"missing-ack-validator:{{ack_validator}}")
    values = json.loads(values_path.read_text(encoding="utf-8"))
    payload = json.loads(ack_template.read_text(encoding="utf-8"))
    payload.update({{
        "ack_protocol_version": PROTOCOL,
        "finalized": True,
        "authority_ack": EXPECTED_ACK,
        "authority_statement": values["authority_statement"],
        "operator_attests_real_external_return": values["operator_attests_real_external_return"],
        "filled_form_relative_path": "external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json",
        "filled_form_sha256": sha256(form_path),
        "operator_input_root_relative_path": "operator_partial_return/operator_input_root",
        "output_root_relative_path": "operator_partial_return/output_root",
        "replay_scope": "first-real-slice-subset",
    }})
    if ack_path.exists() and not (len(sys.argv) > 2 and sys.argv[2] == "--overwrite"):
        raise SystemExit(f"authority-ack-exists-use-overwrite:{{ack_path}}")
    tmp_path = ack_path.with_suffix(".json.tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\\n", encoding="utf-8")
    proc = subprocess.run([str(ack_validator), str(tmp_path), str(form_path), str(ack_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    shutil.move(str(tmp_path), str(ack_path))
    print(f"dual replay authority ack ready: {{ack_path}}")
    print(f"validation report: {{ack_report}}")


if __name__ == "__main__":
    main()
'''

handoff_text = f"""#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="$(cd "$(dirname "${{BASH_SOURCE[0]}}")/.." && pwd)"
VALUES_FILE="${{V61HL_VALUES_FILE:-$WORK_ROOT/external_return_form/{VALUES_FILENAME}}}"
BUILDER="$WORK_ROOT/external_return_form/{BUILDER_FILENAME}"
READINESS="$WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
if [[ ! -x "$BUILDER" ]]; then
  echo "missing builder: $BUILDER" >&2
  exit 2
fi
"$BUILDER" "$VALUES_FILE" "${{V61HL_BUILDER_OVERWRITE_FLAG:---overwrite}}"
if [[ -x "$READINESS" ]]; then
  "$READINESS"
fi
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_dir_exists = int(form_dir is not None and form_dir.is_dir())
ack_template_path = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json.template" if form_dir else None
ack_validator_path = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py" if form_dir else None
filled_form_path = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_template_exists = int(ack_template_path is not None and ack_template_path.is_file())
ack_validator_exists = int(ack_validator_path is not None and ack_validator_path.is_file())
filled_form_exists = int(filled_form_path is not None and filled_form_path.is_file())
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo and form_dir_exists and ack_template_exists and ack_validator_exists)
publish_errors = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not form_dir_exists:
        publish_errors.append("external-return-form-dir-missing")
    if not ack_template_exists:
        publish_errors.append("ack-template-missing")
    if not ack_validator_exists:
        publish_errors.append("ack-validator-missing")

published = 0
published_rows = []
if publish_admitted:
    values_template = form_dir / VALUES_TEMPLATE_FILENAME
    values_validator = form_dir / VALUES_VALIDATOR_FILENAME
    builder = form_dir / BUILDER_FILENAME
    handoff = form_dir / HANDOFF_FILENAME
    readme = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_FILL_WORKSHEET.md"
    values_template.write_text(json.dumps(values_template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    values_validator.write_text(values_validator_text, encoding="utf-8")
    values_validator.chmod(0o755)
    builder.write_text(builder_text, encoding="utf-8")
    builder.chmod(0o755)
    handoff.write_text(handoff_text, encoding="utf-8")
    handoff.chmod(0o755)
    readme.write_text(
        "\n".join([
            "# Dual Replay Authority Ack Fill Worksheet",
            "",
            "Copy `DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template` to `DUAL_REPLAY_AUTHORITY_ACK_VALUES.json`.",
            "Replace `authority_statement` with a final external replay authority statement of at least 80 characters.",
            "The builder computes `filled_form_sha256` from `FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json`; it fails if the filled form is missing.",
            "",
            "```bash",
            "external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py external_return_form/DUAL_REPLAY_AUTHORITY_ACK_VALUES.json",
            "external_return_form/BUILD_DUAL_REPLAY_AUTHORITY_ACK_FROM_VALUES.py external_return_form/DUAL_REPLAY_AUTHORITY_ACK_VALUES.json --overwrite",
            "./RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
            "```",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [values_template, values_validator, builder, handoff, readme]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "real_evidence": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "real_evidence": "0"})
write_csv(run_dir / "dual_replay_authority_ack_fill_packet_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "02-ack-template", "status": "ready" if ack_template_exists else "blocked", "evidence": f"ack_template_exists={ack_template_exists}"},
    {"stage_id": "03-ack-validator", "status": "ready" if ack_validator_exists else "blocked", "evidence": f"ack_validator_exists={ack_validator_exists}"},
    {"stage_id": "04-filled-form", "status": "ready" if filled_form_exists else "blocked", "evidence": f"filled_form_exists={filled_form_exists}"},
    {"stage_id": "05-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "06-ack-fill-packet-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "07-ack-values-supplied", "status": "blocked", "evidence": "requires operator-filled DUAL_REPLAY_AUTHORITY_ACK_VALUES.json"},
    {"stage_id": "08-authority-ack-validation", "status": "blocked", "evidence": "requires filled form plus final authority statement"},
    {"stage_id": "09-readiness-audit", "status": "blocked", "evidence": "requires validated authority ack"},
]
write_csv(run_dir / "dual_replay_authority_ack_fill_packet_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-publish-ack-fill-packet", "ready_to_run_now": str(int(work_root_exists and work_root_outside_repo and ack_template_exists and ack_validator_exists)), "command": "V61HL_PUBLISH_PACKET=1 ./experiments/run_v61hl_post_hk_dual_replay_authority_ack_fill_packet.sh", "purpose": "publish ack values template, values validator, builder, and handoff"},
    {"command_id": "02-preflight-ack-values", "ready_to_run_now": str(published), "command": f"external_return_form/{VALUES_VALIDATOR_FILENAME} external_return_form/{VALUES_FILENAME}", "purpose": "show missing/nonfinal authority ack values"},
    {"command_id": "03-build-authority-ack", "ready_to_run_now": str(published), "command": f"external_return_form/{BUILDER_FILENAME} external_return_form/{VALUES_FILENAME} --overwrite", "purpose": "compute filled form sha256, write DUAL_REPLAY_AUTHORITY_ACK.json, and validate it"},
    {"command_id": "04-build-validate-audit", "ready_to_run_now": str(published), "command": f"external_return_form/{HANDOFF_FILENAME}", "purpose": "build ack and rerun readiness audit"},
]
write_csv(run_dir / "dual_replay_authority_ack_fill_packet_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_PUBLISHED_ROWS.csv", run_dir / "dual_replay_authority_ack_fill_packet_published_rows.csv"),
    ("DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_STAGE_ROWS.csv", run_dir / "dual_replay_authority_ack_fill_packet_stage_rows.csv"),
    ("DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_COMMAND_ROWS.csv", run_dir / "dual_replay_authority_ack_fill_packet_command_rows.csv"),
]:
    (package_dir / rel).write_bytes(src.read_bytes())
(package_dir / VALUES_TEMPLATE_FILENAME).write_text(json.dumps(values_template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / VALUES_VALIDATOR_FILENAME).write_text(values_validator_text, encoding="utf-8")
(package_dir / VALUES_VALIDATOR_FILENAME).chmod(0o755)
(package_dir / "VERIFY_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template\"",
        "test -x \"$DIR/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_STAGE_ROWS.csv\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_MANIFEST.json\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET.sh").chmod(0o755)

summary = {
    "v61hl_post_hk_dual_replay_authority_ack_fill_packet_ready": "1",
    "work_root_supplied": str(work_root_supplied),
    "work_root_exists": str(work_root_exists),
    "work_root_outside_repo": str(work_root_outside_repo),
    "form_dir_exists": str(form_dir_exists),
    "ack_template_exists": str(ack_template_exists),
    "ack_validator_exists": str(ack_validator_exists),
    "filled_form_exists": str(filled_form_exists),
    "publish_requested": str(publish_requested),
    "publish_admitted": str(publish_admitted),
    "ack_fill_packet_published": str(published),
    "authority_ack_values_supplied": "0",
    "authority_ack_validation_ready": "0",
    "real_subset_execution_readiness_ready": "0",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61hl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "ack-template", "status": "pass" if ack_template_exists else "blocked", "evidence": f"ack_template_exists={ack_template_exists}"},
    {"gate": "ack-validator", "status": "pass" if ack_validator_exists else "blocked", "evidence": f"ack_validator_exists={ack_validator_exists}"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": f"filled_form_exists={filled_form_exists}"},
    {"gate": "ack-fill-packet-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "authority-ack-values", "status": "blocked", "evidence": "operator-filled authority statement required"},
    {"gate": "authority-ack-validation", "status": "blocked", "evidence": "requires filled form sha binding and final authority statement"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "dual replay not executed"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "claim_boundary": "authority ack fill packet only; no replay and no real evidence accepted",
}
(package_dir / "DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61HL_POST_HK_DUAL_REPLAY_AUTHORITY_ACK_FILL_PACKET_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HL Dual Replay Authority Ack Fill Packet",
        "",
        f"- ack_fill_packet_published={published}",
        f"- filled_form_exists={filled_form_exists}",
        "- authority_ack_values_supplied=0",
        "- authority_ack_validation_ready=0",
        "- row_acceptance_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "This packet computes filled-form sha binding only after a real filled form exists and a final replay authority statement is supplied.",
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
        "real_evidence": "0",
    })
write_csv(run_dir / "dual_replay_authority_ack_fill_packet_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
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

print(f"v61hl_post_hk_dual_replay_authority_ack_fill_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
