#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hr_post_hq_first_real_slice_env_file_preflight_gate"
RUN_ID="${V61HR_RUN_ID:-env_file_preflight_gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HR_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HQ_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HP_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_PREFLIGHT="${V61HR_PUBLISH_PREFLIGHT:-0}"
RUN_PREFLIGHT="${V61HR_RUN_PREFLIGHT:-1}"

if [[ "${V61HR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hr_post_hq_first_real_slice_env_file_preflight_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_PREFLIGHT" "$RUN_PREFLIGHT" <<'V61HR_PY'
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
run_preflight = int((sys.argv[7].strip() or "1") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_env_file_preflight_gate"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hr_post_hq_first_real_slice_env_file_preflight_gate"

KEY_ROWS = [
    ("V61HO_EXTERNAL_RETURN_ATTESTATION", "external_return_attestation", "text", 40),
    ("V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT", "operator_input_assembly_authority_statement", "text", 40),
    ("V61HO_REVIEWER_ID", "v53_review_return.reviewer_id", "text", 3),
    ("V61HO_ADJUDICATOR_ID", "v53_review_return.adjudicator_id", "text", 3),
    ("V61HO_REVIEW_COMMENT_TEXT", "v53_review_return.review_comment_text", "text", 40),
    ("V61HO_ADJUDICATION_REASON_TEXT", "v53_review_return.adjudication_reason_text", "text", 40),
    ("V61HO_CREDENTIAL_STATEMENT_TEXT", "v53_review_return.credential_statement_text", "text", 40),
    ("V61HO_CONFLICT_STATEMENT_TEXT", "v53_review_return.conflict_statement_text", "text", 40),
    ("V61HO_REVIEWER_AUTHORITY_STATEMENT", "v53_review_return.reviewer_authority_statement", "text", 40),
    ("V61HO_GENERATION_ID", "v61_generation_return.generation_id", "text", 3),
    ("V61HO_CITATION_ID", "v61_generation_return.citation_id", "text", 3),
    ("V61HO_LATENCY_ROW_ID", "v61_generation_return.latency_row_id", "text", 3),
    ("V61HO_CHECKPOINT_ROOT", "v61_generation_return.checkpoint_root", "checkpoint_root", 59),
    ("V61HO_ANSWER_TEXT", "v61_generation_return.answer_text", "text", 40),
    ("V61HO_RUN_TRANSCRIPT_TEXT", "v61_generation_return.run_transcript_text", "text", 40),
    ("V61HO_PROMPT_TOKENS", "v61_generation_return.prompt_tokens", "positive", 0),
    ("V61HO_OUTPUT_TOKENS", "v61_generation_return.output_tokens", "positive", 0),
    ("V61HO_PREFILL_MS", "v61_generation_return.prefill_ms", "positive", 0),
    ("V61HO_DECODE_MS", "v61_generation_return.decode_ms", "positive", 0),
    ("V61HO_TOTAL_MS", "v61_generation_return.total_ms", "positive", 0),
    ("V61HO_TOKENS_PER_SECOND", "v61_generation_return.tokens_per_second", "positive", 0),
    ("V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT", "v61_generation_return.generation_operator_authority_statement", "text", 40),
    ("V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT", "authority_statement", "text", 80),
    ("V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN", "operator_attests_real_external_return", "bool_true", 1),
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


validator_text = r'''#!/usr/bin/env python3
import argparse
import csv
import shlex
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
KEY_ROWS = [
    ("V61HO_EXTERNAL_RETURN_ATTESTATION", "external_return_attestation", "text", 40),
    ("V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT", "operator_input_assembly_authority_statement", "text", 40),
    ("V61HO_REVIEWER_ID", "v53_review_return.reviewer_id", "text", 3),
    ("V61HO_ADJUDICATOR_ID", "v53_review_return.adjudicator_id", "text", 3),
    ("V61HO_REVIEW_COMMENT_TEXT", "v53_review_return.review_comment_text", "text", 40),
    ("V61HO_ADJUDICATION_REASON_TEXT", "v53_review_return.adjudication_reason_text", "text", 40),
    ("V61HO_CREDENTIAL_STATEMENT_TEXT", "v53_review_return.credential_statement_text", "text", 40),
    ("V61HO_CONFLICT_STATEMENT_TEXT", "v53_review_return.conflict_statement_text", "text", 40),
    ("V61HO_REVIEWER_AUTHORITY_STATEMENT", "v53_review_return.reviewer_authority_statement", "text", 40),
    ("V61HO_GENERATION_ID", "v61_generation_return.generation_id", "text", 3),
    ("V61HO_CITATION_ID", "v61_generation_return.citation_id", "text", 3),
    ("V61HO_LATENCY_ROW_ID", "v61_generation_return.latency_row_id", "text", 3),
    ("V61HO_CHECKPOINT_ROOT", "v61_generation_return.checkpoint_root", "checkpoint_root", 59),
    ("V61HO_ANSWER_TEXT", "v61_generation_return.answer_text", "text", 40),
    ("V61HO_RUN_TRANSCRIPT_TEXT", "v61_generation_return.run_transcript_text", "text", 40),
    ("V61HO_PROMPT_TOKENS", "v61_generation_return.prompt_tokens", "positive", 0),
    ("V61HO_OUTPUT_TOKENS", "v61_generation_return.output_tokens", "positive", 0),
    ("V61HO_PREFILL_MS", "v61_generation_return.prefill_ms", "positive", 0),
    ("V61HO_DECODE_MS", "v61_generation_return.decode_ms", "positive", 0),
    ("V61HO_TOTAL_MS", "v61_generation_return.total_ms", "positive", 0),
    ("V61HO_TOKENS_PER_SECOND", "v61_generation_return.tokens_per_second", "positive", 0),
    ("V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT", "v61_generation_return.generation_operator_authority_statement", "text", 40),
    ("V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT", "authority_statement", "text", 80),
    ("V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN", "operator_attests_real_external_return", "bool_true", 1),
]
ALLOWED = {row[0] for row in KEY_ROWS}


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def parse_env(path):
    parsed = {}
    rows = []
    if not path.is_file():
        rows.append({"env_name": "FIRST_REAL_SLICE_VALUES.env", "field_path": "file", "status": "blocked", "required": "1", "evidence": "env-file-missing"})
        return parsed, rows
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        if "=" not in line:
            rows.append({"env_name": f"line:{lineno}", "field_path": "syntax", "status": "blocked", "required": "1", "evidence": "expected-key-value"})
            continue
        key, value_text = line.split("=", 1)
        key = key.strip()
        if key not in ALLOWED:
            rows.append({"env_name": key or f"line:{lineno}", "field_path": "unknown", "status": "blocked", "required": "1", "evidence": "unknown-key"})
            continue
        try:
            tokens = shlex.split(value_text, posix=True)
        except ValueError as exc:
            rows.append({"env_name": key, "field_path": "syntax", "status": "blocked", "required": "1", "evidence": f"invalid-quoting:{exc}"})
            continue
        if len(tokens) != 1:
            rows.append({"env_name": key, "field_path": "syntax", "status": "blocked", "required": "1", "evidence": "value-must-be-one-token"})
            continue
        parsed[key] = tokens[0]
    return parsed, rows


def validate_value(value, kind, expected):
    if value is None or value == "":
        return "blocked", "missing"
    if has_nonfinal(value):
        return "blocked", "nonfinal-token"
    if kind == "text":
        if len(str(value).strip()) < int(expected):
            return "blocked", f"too-short<{expected}"
        return "pass", "ready"
    if kind == "positive":
        try:
            numeric = float(value)
        except ValueError:
            return "blocked", "not-positive"
        if numeric <= 0:
            return "blocked", "not-positive"
        return "pass", "ready"
    if kind == "checkpoint_root":
        path = Path(value).expanduser()
        shard_rows = len(list(path.glob("model-*-of-00059.safetensors"))) if path.is_dir() else 0
        if path.is_dir() and shard_rows == int(expected):
            return "pass", f"exists=1; safetensors={shard_rows}"
        return "blocked", f"exists={int(path.is_dir())}; safetensors={shard_rows}; expected={expected}"
    if kind == "bool_true":
        if str(value).strip().lower() in {"1", "true", "yes"}:
            return "pass", "true"
        return "blocked", f"expected-true:{value}"
    return "blocked", f"unknown-kind:{kind}"


def main():
    parser = argparse.ArgumentParser(description="Preflight FIRST_REAL_SLICE_VALUES.env without writing values JSON.")
    parser.add_argument("env_file")
    parser.add_argument("report_csv")
    args = parser.parse_args()
    env_path = Path(args.env_file).expanduser().resolve()
    report_path = Path(args.report_csv).expanduser().resolve()
    parsed, rows = parse_env(env_path)
    for key, field_path, kind, expected in KEY_ROWS:
        status, evidence = validate_value(parsed.get(key), kind, expected)
        rows.append({"env_name": key, "field_path": field_path, "status": status, "required": "1", "evidence": evidence})
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["env_name", "field_path", "status", "required", "evidence"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    if blocked:
        print(f"first-real-slice-env-preflight-blocked:{len(blocked)} rows; report={report_path}")
        raise SystemExit(2)
    print(f"first real-slice env preflight ready: {report_path}")


if __name__ == "__main__":
    main()
'''

runner_text = """#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${V61HR_VALUES_ENV_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env}"
REPORT="${V61HR_PREFLIGHT_REPORT:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv}"
VALIDATOR="$FORM_DIR/VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py"
exec "$VALIDATOR" "$ENV_FILE" "$REPORT"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
env_file = form_dir / "FIRST_REAL_SLICE_VALUES.env" if form_dir else None
env_template = form_dir / "FIRST_REAL_SLICE_VALUES.env.template" if form_dir else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not publish_errors:
        validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py"
        runner = form_dir / "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh"
        readme = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_FILE_PREFLIGHT_README.md"
        validator.write_text(validator_text, encoding="utf-8")
        validator.chmod(0o755)
        runner.write_text(runner_text, encoding="utf-8")
        runner.chmod(0o755)
        readme.write_text(
            "\n".join([
                "# First Real Slice Values Env File Preflight",
                "",
                "Run this before capture to check the filled `FIRST_REAL_SLICE_VALUES.env` without writing any JSON values file.",
                "",
                "```bash",
                "external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
                "```",
                "",
                "The gate accepts only the 24 expected `V61HO_*` keys and blocks placeholders, non-positive numeric fields, missing ack attestation, and checkpoint roots without 59 shards.",
                "",
            ]),
            encoding="utf-8",
        )
        for path in [validator, runner, readme]:
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
write_csv(run_dir / "first_real_slice_env_file_preflight_published_rows.csv", list(published_rows[0].keys()), published_rows)

env_file_exists = int(env_file is not None and env_file.is_file())
env_template_exists = int(env_template is not None and env_template.is_file())
values_file_exists = int(values_file is not None and values_file.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

preflight_ready = 0
preflight_blocked_rows = 0
preflight_report = run_dir / "first_real_slice_values_env_file_preflight_rows.csv"
local_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py" if form_dir else None
if run_preflight and env_file_exists and local_validator is not None and local_validator.is_file():
    proc = subprocess.run([str(local_validator), str(env_file), str(preflight_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (run_dir / "env-preflight.stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "env-preflight.stderr.txt").write_text(proc.stderr, encoding="utf-8")
    preflight_ready = int(proc.returncode == 0)
    if preflight_report.is_file():
        with preflight_report.open(newline="", encoding="utf-8") as handle:
            preflight_blocked_rows = sum(1 for row in csv.DictReader(handle) if row["status"] != "pass")
else:
    rows = []
    if not env_file_exists:
        rows.append({"env_name": "FIRST_REAL_SLICE_VALUES.env", "field_path": "file", "status": "blocked", "required": "1", "evidence": "env-file-missing"})
    elif local_validator is None or not local_validator.is_file():
        rows.append({"env_name": "VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py", "field_path": "preflight-validator", "status": "blocked", "required": "1", "evidence": "validator-missing"})
    else:
        rows.append({"env_name": "preflight", "field_path": "execution", "status": "blocked", "required": "1", "evidence": "run-preflight-disabled"})
    write_csv(preflight_report, ["env_name", "field_path", "status", "required", "evidence"], rows)
    preflight_blocked_rows = len(rows)

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not env_file_exists:
    next_action = "fill-first-real-slice-values-env-file"
elif not preflight_ready:
    next_action = "fix-first-real-slice-values-env-file"
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
    {"gate": "env-template", "status": "pass" if env_template_exists else "blocked", "evidence": str(env_template) if env_template_exists else "missing"},
    {"gate": "env-file", "status": "pass" if env_file_exists else "blocked", "evidence": str(env_file) if env_file_exists else "missing"},
    {"gate": "env-file-preflight", "status": "pass" if preflight_ready else "blocked", "evidence": f"blocked_rows={preflight_blocked_rows}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hr never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; env preflight does not run model generation"},
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
    "run_preflight": run_preflight,
    "writes_values": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_env_file_preflight_published_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_values_env_file_preflight_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE_MANIFEST.json\"",
        "echo \"first real slice env-file preflight gate packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HR_POST_HQ_FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hr Boundary",
        "",
        "This step publishes a preflight gate for `FIRST_REAL_SLICE_VALUES.env`.",
        "It never writes values JSON, never materializes forms, never runs replay, and never creates model-generation evidence.",
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
    run_dir / "first_real_slice_env_file_preflight_published_rows.csv",
    preflight_report,
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
    "preflight_gate_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "run_preflight_requested": run_preflight,
    "env_file_exists": env_file_exists,
    "env_template_exists": env_template_exists,
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
    "checkpoint_payload_bytes_downloaded_by_v61hr": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hr_post_hq_first_real_slice_env_file_preflight_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HR_PY
