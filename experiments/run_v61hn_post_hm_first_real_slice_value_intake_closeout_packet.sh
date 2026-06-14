#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hn_post_hm_first_real_slice_value_intake_closeout_packet"
RUN_ID="${V61HN_RUN_ID:-value_intake_closeout_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HN_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HL_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HK_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61GU_WORK_ROOT:-}"; fi
PUBLISH_PACKET="${V61HN_PUBLISH_PACKET:-0}"

if [[ "${V61HN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hn_post_hm_first_real_slice_value_intake_closeout_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PACKET" <<'V61HN_PY'
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
package_dir = run_dir / "first_real_slice_value_intake_closeout_packet"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hn_post_hm_first_real_slice_value_intake_closeout_packet"

FORM_VALUES = "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
FORM_VALUES_TEMPLATE = "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template"
FORM_VALUES_REPORT = "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
FORM_TEMPLATE_REPORT = "template_values.validation_rows.csv"
FORM_VALUES_VALIDATOR = "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
FILLED_FORM = "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
ACK_VALUES = "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json"
ACK_VALUES_TEMPLATE = "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template"
ACK_VALUES_REPORT = "DUAL_REPLAY_AUTHORITY_ACK_VALUES.validation_rows.csv"
ACK_TEMPLATE_REPORT = "template_ack_values.validation_rows.csv"
ACK_VALUES_VALIDATOR = "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py"
ACK_FILE = "DUAL_REPLAY_AUTHORITY_ACK.json"

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


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def run_validator(validator, values, report):
    if not validator.is_file() or not values.is_file():
        return None
    proc = subprocess.run([str(validator), str(values), str(report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (run_dir / f"{report.stem}.stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / f"{report.stem}.stderr.txt").write_text(proc.stderr, encoding="utf-8")
    return proc.returncode


def action_for(target_file, field_path, evidence):
    if target_file == ACK_VALUES:
        if field_path == "authority_statement":
            return "write final external replay authority statement, at least 80 chars, bound to the real filled form"
        return "keep true only after the operator attests the return is real external evidence"
    if field_path in {"values-json", "v53_review_return", "v61_generation_return"}:
        return "fix JSON structure so the validator can inspect this section"
    if field_path.endswith(("prompt_tokens", "output_tokens")):
        return "replace with positive measured token count from the subset run"
    if field_path.endswith(("prefill_ms", "decode_ms", "total_ms", "tokens_per_second")):
        return "replace with positive measured latency/throughput value from the subset run"
    if field_path.endswith(("generation_id", "citation_id", "latency_row_id")):
        return "replace with real generation/citation/latency identifier"
    if "reviewer_id" in field_path or "adjudicator_id" in field_path:
        return "replace with real reviewer/adjudicator identity"
    if any(token in field_path for token in ["review_comment", "adjudication_reason", "credential", "conflict", "authority_statement", "attestation"]):
        return "replace with final human/operator statement meeting the minimum length"
    if field_path.endswith(("answer_text", "run_transcript_text")):
        return "replace with real source-bound answer or run transcript text"
    if "not-positive" in evidence:
        return "replace with a positive measured numeric value"
    return "replace placeholder with real external return value"


work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
operator_input_root = work_root / "operator_partial_return" / "operator_input_root" if work_root else None
dual_output_root = work_root / "operator_partial_return" / "output_root" if work_root else None

form_values = form_dir / FORM_VALUES if form_dir else None
form_values_template = form_dir / FORM_VALUES_TEMPLATE if form_dir else None
form_values_validator = form_dir / FORM_VALUES_VALIDATOR if form_dir else None
form_values_report = form_dir / FORM_VALUES_REPORT if form_dir else None
form_template_report = form_dir / FORM_TEMPLATE_REPORT if form_dir else None
filled_form = form_dir / FILLED_FORM if form_dir else None
ack_values = form_dir / ACK_VALUES if form_dir else None
ack_values_template = form_dir / ACK_VALUES_TEMPLATE if form_dir else None
ack_values_validator = form_dir / ACK_VALUES_VALIDATOR if form_dir else None
ack_values_report = form_dir / ACK_VALUES_REPORT if form_dir else None
ack_template_report = form_dir / ACK_TEMPLATE_REPORT if form_dir else None
ack_file = form_dir / ACK_FILE if form_dir else None

form_values_supplied = int(form_values is not None and form_values.is_file())
ack_values_supplied = int(ack_values is not None and ack_values.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

form_validation_rows = []
ack_validation_rows = []
form_values_validation_ready = 0
ack_values_validation_ready = 0
form_report_source = "missing"
ack_report_source = "missing"

if form_values_supplied:
    local_form_report = run_dir / "form_values.validation_rows.csv"
    code = run_validator(form_values_validator, form_values, local_form_report) if form_values_validator else None
    if code is not None and local_form_report.is_file():
        form_validation_rows = read_csv(local_form_report)
        form_values_validation_ready = int(code == 0)
        form_report_source = "actual-values-validator"
elif form_template_report is not None and form_template_report.is_file():
    form_validation_rows = read_csv(form_template_report)
    form_report_source = "template-validation-rows"

if ack_values_supplied:
    local_ack_report = run_dir / "ack_values.validation_rows.csv"
    code = run_validator(ack_values_validator, ack_values, local_ack_report) if ack_values_validator else None
    if code is not None and local_ack_report.is_file():
        ack_validation_rows = read_csv(local_ack_report)
        ack_values_validation_ready = int(code == 0)
        ack_report_source = "actual-values-validator"
elif ack_template_report is not None and ack_template_report.is_file():
    ack_validation_rows = read_csv(ack_template_report)
    ack_report_source = "template-validation-rows"

missing_rows = []
for row in form_validation_rows:
    if row.get("status") != "pass":
        missing_rows.append({
            "target_file": f"external_return_form/{FORM_VALUES}",
            "field_path": row.get("field_path", ""),
            "current_status": row.get("status", ""),
            "required": row.get("required", "1"),
            "evidence": row.get("evidence", ""),
            "required_action": action_for(FORM_VALUES, row.get("field_path", ""), row.get("evidence", "")),
            "blocks_gate": "external-return-form-validation",
        })
for row in ack_validation_rows:
    if row.get("status") != "pass":
        missing_rows.append({
            "target_file": f"external_return_form/{ACK_VALUES}",
            "field_path": row.get("field_path", ""),
            "current_status": row.get("status", ""),
            "required": row.get("required", "1"),
            "evidence": row.get("evidence", ""),
            "required_action": action_for(ACK_VALUES, row.get("field_path", ""), row.get("evidence", "")),
            "blocks_gate": "dual-replay-authority-ack-validation",
        })
if work_root_supplied and not form_values_supplied:
    missing_rows.insert(0, {
        "target_file": f"external_return_form/{FORM_VALUES}",
        "field_path": "file",
        "current_status": "blocked",
        "required": "1",
        "evidence": "actual-values-file-missing",
        "required_action": f"create {FORM_VALUES} from the live template and replace all placeholder values with real external evidence",
        "blocks_gate": "external-return-form-validation",
    })
if work_root_supplied and not ack_values_supplied:
    missing_rows.append({
        "target_file": f"external_return_form/{ACK_VALUES}",
        "field_path": "file",
        "current_status": "blocked",
        "required": "1",
        "evidence": "actual-ack-values-file-missing",
        "required_action": f"create {ACK_VALUES} from the live template after the filled form exists",
        "blocks_gate": "dual-replay-authority-ack-validation",
    })
if not missing_rows:
    missing_rows.append({
        "target_file": "",
        "field_path": "",
        "current_status": "pass",
        "required": "0",
        "evidence": "no-missing-values-detected",
        "required_action": "continue to materialization/readiness audit",
        "blocks_gate": "",
    })

operator_input_present = []
if operator_input_root is not None and operator_input_root.is_dir():
    operator_input_present = [rel for rel in OPERATOR_INPUT_RELS if (operator_input_root / rel).is_file()]
operator_input_files_ready = int(len(operator_input_present) == len(OPERATOR_INPUT_RELS))
dual_output_roots_ready = int(dual_output_root is not None and dual_output_root.is_dir() and any(dual_output_root.iterdir()))

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not form_values_supplied:
    next_action = "create-first-real-slice-external-return-values-json"
elif not form_values_validation_ready:
    next_action = "fix-first-real-slice-external-return-values"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not operator_input_files_ready:
    next_action = "materialize-no-replay-operator-input-root"
elif not ack_values_supplied:
    next_action = "create-dual-replay-authority-ack-values-json"
elif not ack_values_validation_ready:
    next_action = "fix-dual-replay-authority-ack-values"
elif not authority_ack_exists:
    next_action = "build-and-validate-dual-replay-authority-ack"
elif not dual_output_roots_ready:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"
else:
    next_action = "explicit-subset-dual-replay-eligible-but-not-armed-by-v61hn"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-values-file", "status": "pass" if form_values_supplied else "blocked", "evidence": str(form_values) if form_values_supplied else "missing"},
    {"gate": "form-values-validator", "status": "pass" if form_values_validation_ready else "blocked", "evidence": f"source={form_report_source}; blocked_fields={sum(1 for row in form_validation_rows if row.get('status') != 'pass')}"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "operator-input-root", "status": "pass" if operator_input_files_ready else "blocked", "evidence": f"present={len(operator_input_present)}/{len(OPERATOR_INPUT_RELS)}"},
    {"gate": "ack-values-file", "status": "pass" if ack_values_supplied else "blocked", "evidence": str(ack_values) if ack_values_supplied else "missing"},
    {"gate": "ack-values-validator", "status": "pass" if ack_values_validation_ready else "blocked", "evidence": f"source={ack_report_source}; blocked_fields={sum(1 for row in ack_validation_rows if row.get('status') != 'pass')}"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hn is intake/readiness-only and never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until real subset replay outputs are accepted"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "evidence": "generation_acceptance_closure_ready=0 until accepted real subset rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; no new model generation evidence is created here"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]

commands_md = "\n".join([
    "# First Real Slice Value Intake Closeout",
    "",
    f"Generated: {datetime.now(timezone.utc).isoformat()}",
    f"Workspace: `{work_root}`" if work_root else "Workspace: not supplied",
    "",
    "## Fill Targets",
    "",
    f"- `external_return_form/{FORM_VALUES}`: real review, adjudication, generation, citation, and latency values.",
    f"- `external_return_form/{ACK_VALUES}`: final replay authority statement after the filled form exists.",
    "",
    "## Gate Order",
    "",
    "1. Validate `FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json`.",
    "2. Build and validate `FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json`.",
    "3. Materialize the no-replay operator input root.",
    "4. Validate and build `DUAL_REPLAY_AUTHORITY_ACK.json`.",
    "5. Run the real subset execution readiness audit.",
    "6. Only after that, arm subset dual replay explicitly outside this intake packet.",
    "",
    "## Commands",
    "",
    "```bash",
    "cd \"$(dirname \"$0\")\"/..",
    "external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv",
    "external_return_form/VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh",
    "V61HM_EXECUTE_OPERATOR_INPUT=1 ./RUN_FIRST_REAL_SLICE_READINESS_PIPELINE.sh",
    "external_return_form/BUILD_VALIDATE_AND_AUDIT_DUAL_REPLAY_AUTHORITY_ACK.sh",
    "./RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
    "```",
    "",
    "This packet does not create evidence, does not run generation, and does not arm dual replay.",
    "",
])

missing_csv = run_dir / "first_real_slice_value_intake_missing_rows.csv"
gate_csv = run_dir / "first_real_slice_value_intake_gate_rows.csv"
commands_path = run_dir / "FIRST_REAL_SLICE_VALUE_INTAKE_NEXT_COMMANDS.md"
write_csv(missing_csv, ["target_file", "field_path", "current_status", "required", "evidence", "required_action", "blocks_gate"], missing_rows)
write_csv(gate_csv, ["gate", "status", "evidence"], gate_rows)
commands_path.write_text(commands_md, encoding="utf-8")

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None:
        publish_errors.append("external-return-form-dir-missing")
    elif not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not publish_errors:
        destinations = [
            (missing_csv, form_dir / "FIRST_REAL_SLICE_VALUE_INTAKE_TODO.csv"),
            (gate_csv, form_dir / "FIRST_REAL_SLICE_VALUE_INTAKE_GATE_STATUS.csv"),
            (commands_path, form_dir / "FIRST_REAL_SLICE_VALUE_INTAKE_NEXT_COMMANDS.md"),
        ]
        for src, dst in destinations:
            dst.write_bytes(src.read_bytes())
            published_rows.append({
                "path": str(dst),
                "bytes": str(dst.stat().st_size),
                "sha256": sha256(dst),
                "metadata_only": "1",
                "creates_real_evidence": "0",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "creates_real_evidence": "0", "executes_dual_replay": "0"})

write_csv(run_dir / "first_real_slice_value_intake_published_rows.csv", list(published_rows[0].keys()), published_rows)

packet_files = [missing_csv, gate_csv, commands_path, run_dir / "first_real_slice_value_intake_published_rows.csv"]
manifest = {
    "prefix": prefix,
    "run_id": run_dir.name,
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "work_root": str(work_root) if work_root else "",
    "publish_requested": publish_requested,
    "packet_files": [path.relative_to(run_dir).as_posix() for path in packet_files],
    "next_real_subset_action": next_action,
    "creates_real_evidence": False,
    "executes_dual_replay": False,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_PACKET.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_value_intake_missing_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_value_intake_gate_rows.csv\"",
        "test -s \"$RUN_DIR/FIRST_REAL_SLICE_VALUE_INTAKE_NEXT_COMMANDS.md\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_MANIFEST.json\"",
        "echo \"first real slice value intake closeout packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
packet_files.extend([manifest_path, verify_path])

sha_rows = [{"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": str(path.stat().st_size)} for path in packet_files]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

form_blocked = sum(1 for row in form_validation_rows if row.get("status") != "pass")
ack_blocked = sum(1 for row in ack_validation_rows if row.get("status") != "pass")
missing_required_rows = sum(1 for row in missing_rows if row.get("current_status") != "pass")
published = int(publish_requested and not publish_errors)
ready = 1
summary = {
    f"{prefix}_ready": ready,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "intake_packet_published": published,
    "publish_error_count": len(publish_errors),
    "form_values_supplied": form_values_supplied,
    "form_values_validation_ready": form_values_validation_ready,
    "form_values_blocked_fields": form_blocked,
    "filled_form_exists": filled_form_exists,
    "operator_input_files_ready": operator_input_files_ready,
    "operator_input_file_rows": len(operator_input_present),
    "ack_values_supplied": ack_values_supplied,
    "ack_values_validation_ready": ack_values_validation_ready,
    "ack_values_blocked_fields": ack_blocked,
    "authority_ack_exists": authority_ack_exists,
    "dual_output_roots_ready": dual_output_roots_ready,
    "missing_required_rows": missing_required_rows,
    "next_real_subset_action": next_action,
    "row_acceptance_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hn": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "evidence"], gate_rows)
write_csv(run_dir / f"{prefix}_decision.csv", ["gate", "status", "evidence"], gate_rows)

boundary = "\n".join([
    "# v61hn Boundary",
    "",
    "This packet only closes the value-intake visibility gap for the first real slice.",
    "It publishes missing-value and gate-status artifacts, but it does not create review evidence, generation evidence, latency evidence, authority acks, operator inputs, or replay outputs.",
    "",
    f"- next_real_subset_action: {next_action}",
    f"- missing_required_rows: {missing_required_rows}",
    "- row_acceptance_ready: 0",
    "- generation_acceptance_closure_ready: 0",
    "- actual_model_generation_ready: 0",
    "- checkpoint_payload_bytes_committed_to_repo: 0",
    "",
])
(run_dir / "V61HN_POST_HM_FIRST_REAL_SLICE_VALUE_INTAKE_CLOSEOUT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

print(f"v61hn_post_hm_first_real_slice_value_intake_closeout_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HN_PY
