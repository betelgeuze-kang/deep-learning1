#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hk_post_hj_first_real_slice_external_return_form_fill_packet"
RUN_ID="${V61HK_RUN_ID:-fill_packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HK_WORK_ROOT:-${V61HJ_WORK_ROOT:-${V61HI_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}"
PUBLISH_PACKET="${V61HK_PUBLISH_PACKET:-0}"

if [[ "${V61HK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_dir: $RUN_DIR"
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
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_external_return_form_fill_packet"
package_dir.mkdir(parents=True, exist_ok=True)

VALUES_FILENAME = "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
VALUES_TEMPLATE_FILENAME = "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template"
VALUES_VALIDATOR_FILENAME = "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
BUILDER_FILENAME = "BUILD_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FROM_VALUES.py"
HANDOFF_FILENAME = "VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh"


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


def json_template_payload(checkpoint_hint):
    return {
        "source_class": "real-external-review-and-generation-return",
        "finalized": True,
        "v53_review_return": {
            "reviewer_id": "REPLACE_WITH_REAL_REVIEWER_ID",
            "adjudicator_id": "REPLACE_WITH_REAL_ADJUDICATOR_ID",
            "review_decision": "accept",
            "adjudication_decision": "accept",
            "source_support_verified": 1,
            "citation_verified": 1,
            "policy_verified": 1,
            "conflict_declared": 0,
            "review_comment_text": "REPLACE_WITH_REAL_REVIEW_COMMENT_40_CHARS_MIN",
            "adjudication_reason_text": "REPLACE_WITH_REAL_ADJUDICATION_REASON_40_CHARS_MIN",
            "credential_statement_text": "REPLACE_WITH_REAL_REVIEWER_CREDENTIAL_STATEMENT_40_CHARS_MIN",
            "conflict_statement_text": "REPLACE_WITH_REAL_CONFLICT_STATEMENT_40_CHARS_MIN",
            "reviewer_authority_statement": "REPLACE_WITH_REAL_REVIEWER_AUTHORITY_STATEMENT_40_CHARS_MIN",
        },
        "v61_generation_return": {
            "generation_id": "REPLACE_WITH_REAL_GENERATION_ID",
            "citation_id": "REPLACE_WITH_REAL_CITATION_ID",
            "latency_row_id": "REPLACE_WITH_REAL_LATENCY_ROW_ID",
            "model_id": "mistralai/Mixtral-8x22B-v0.1",
            "checkpoint_root": checkpoint_hint or "REPLACE_WITH_REAL_59_SHARD_CHECKPOINT_ROOT",
            "generation_status": "completed",
            "abstain_decision": "answer",
            "fallback_used": 0,
            "answer_text": "REPLACE_WITH_REAL_GENERATION_ANSWER_TEXT_40_CHARS_MIN",
            "run_transcript_text": "REPLACE_WITH_REAL_RUN_TRANSCRIPT_TEXT_40_CHARS_MIN",
            "prompt_tokens": "REPLACE_WITH_POSITIVE_PROMPT_TOKENS",
            "output_tokens": "REPLACE_WITH_POSITIVE_OUTPUT_TOKENS",
            "prefill_ms": "REPLACE_WITH_POSITIVE_PREFILL_MS",
            "decode_ms": "REPLACE_WITH_POSITIVE_DECODE_MS",
            "total_ms": "REPLACE_WITH_POSITIVE_TOTAL_MS",
            "tokens_per_second": "REPLACE_WITH_POSITIVE_TOKENS_PER_SECOND",
            "generation_operator_authority_statement": "REPLACE_WITH_REAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT_40_CHARS_MIN",
        },
        "external_return_attestation": "REPLACE_WITH_REAL_EXTERNAL_RETURN_ATTESTATION_40_CHARS_MIN",
        "operator_input_assembly_authority_statement": "REPLACE_WITH_REAL_OPERATOR_ASSEMBLY_AUTHORITY_STATEMENT_40_CHARS_MIN",
    }


def extract_checkpoint_hint(env_path):
    if not env_path.is_file():
        return ""
    for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("export V61GI_CHECKPOINT_ROOT="):
            value = line.split("=", 1)[1].strip().strip("'").strip('"')
            if "REPLACE_WITH" not in value:
                return value
    return ""


values_validator_text = r'''#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
EXPECTED_SOURCE_CLASS = "real-external-review-and-generation-return"
EXPECTED_MODEL_ID = "mistralai/Mixtral-8x22B-v0.1"
REQUIRED_V53 = {
    "reviewer_id": ("text", 3),
    "adjudicator_id": ("text", 3),
    "review_decision": ("enum", {"accept"}),
    "adjudication_decision": ("enum", {"accept"}),
    "source_support_verified": ("exact", 1),
    "citation_verified": ("exact", 1),
    "policy_verified": ("exact", 1),
    "conflict_declared": ("exact", 0),
    "review_comment_text": ("text", 40),
    "adjudication_reason_text": ("text", 40),
    "credential_statement_text": ("text", 40),
    "conflict_statement_text": ("text", 40),
    "reviewer_authority_statement": ("text", 40),
}
REQUIRED_V61 = {
    "generation_id": ("text", 3),
    "citation_id": ("text", 3),
    "latency_row_id": ("text", 3),
    "model_id": ("enum", {EXPECTED_MODEL_ID}),
    "checkpoint_root": ("checkpoint_root", 59),
    "generation_status": ("enum", {"completed", "generated"}),
    "abstain_decision": ("enum", {"answer"}),
    "fallback_used": ("exact", 0),
    "answer_text": ("text", 40),
    "run_transcript_text": ("text", 40),
    "prompt_tokens": ("positive", None),
    "output_tokens": ("positive", None),
    "prefill_ms": ("positive", None),
    "decode_ms": ("positive", None),
    "total_ms": ("positive", None),
    "tokens_per_second": ("positive", None),
    "generation_operator_authority_statement": ("text", 40),
}
REQUIRED_TOP = {
    "source_class": ("enum", {EXPECTED_SOURCE_CLASS}),
    "finalized": ("exact", True),
    "external_return_attestation": ("text", 40),
    "operator_input_assembly_authority_statement": ("text", 40),
}


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def positive(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False


def add(rows, path, status, evidence, required="1"):
    rows.append({
        "field_path": path,
        "status": status,
        "required": required,
        "evidence": evidence,
    })


def validate_value(value, rule):
    kind, expected = rule
    if kind == "text":
        if not isinstance(value, str):
            return False, "not-text"
        if len(value.strip()) < int(expected):
            return False, f"too-short<{expected}"
        if has_nonfinal(value):
            return False, "nonfinal-token"
        return True, "ready"
    if kind == "enum":
        if value in expected and not has_nonfinal(value):
            return True, "ready"
        return False, f"expected-one-of:{','.join(map(str, sorted(expected)))}"
    if kind == "exact":
        if value == expected:
            return True, "ready"
        return False, f"expected:{expected!r}"
    if kind == "positive":
        if positive(value):
            return True, "ready"
        return False, "not-positive"
    if kind == "checkpoint_root":
        if not isinstance(value, str) or has_nonfinal(value):
            return False, "checkpoint-root-nonfinal-or-not-text"
        path = Path(value).expanduser()
        shard_rows = len(list(path.glob("model-*-of-00059.safetensors"))) if path.is_dir() else 0
        if path.is_dir() and shard_rows == int(expected):
            return True, f"exists=1; safetensors={shard_rows}"
        return False, f"exists={int(path.is_dir())}; safetensors={shard_rows}; expected={expected}"
    return False, f"unknown-rule:{kind}"


def validate_section(rows, payload, section_name, rules):
    section = payload.get(section_name, {})
    if not isinstance(section, dict):
        add(rows, section_name, "blocked", "missing-or-not-object")
        section = {}
    else:
        add(rows, section_name, "pass", "object")
    for key, rule in rules.items():
        if key not in section:
            add(rows, f"{section_name}.{key}", "blocked", "missing")
            continue
        ok, evidence = validate_value(section[key], rule)
        add(rows, f"{section_name}.{key}", "pass" if ok else "blocked", evidence)


def main():
    values_path = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path("FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json").resolve()
    report_path = Path(sys.argv[2]).expanduser().resolve() if len(sys.argv) > 2 else values_path.with_suffix(".validation_rows.csv")
    rows = []
    try:
        payload = json.loads(values_path.read_text(encoding="utf-8"))
    except Exception as exc:
        payload = {}
        add(rows, "values-json", "blocked", f"json-unreadable:{exc}")
    else:
        if isinstance(payload, dict):
            add(rows, "values-json", "pass", "json-readable")
        else:
            add(rows, "values-json", "blocked", "json-not-object")
            payload = {}
    for key, rule in REQUIRED_TOP.items():
        if key not in payload:
            add(rows, key, "blocked", "missing")
            continue
        ok, evidence = validate_value(payload[key], rule)
        add(rows, key, "pass" if ok else "blocked", evidence)
    validate_section(rows, payload, "v53_review_return", REQUIRED_V53)
    validate_section(rows, payload, "v61_generation_return", REQUIRED_V61)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["field_path", "status", "required", "evidence"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    if blocked:
        print(f"external-return-values-blocked:{len(blocked)} fields; report={report_path}", file=sys.stderr)
        raise SystemExit(2)
    print(f"external-return-values-ready; report={report_path}")


if __name__ == "__main__":
    main()
'''


builder_text = r'''#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
from pathlib import Path

REQUIRED_TOP = ["source_class", "finalized", "v53_review_return", "v61_generation_return", "external_return_attestation", "operator_input_assembly_authority_statement"]
REQUIRED_V53 = [
    "reviewer_id",
    "adjudicator_id",
    "review_decision",
    "adjudication_decision",
    "source_support_verified",
    "citation_verified",
    "policy_verified",
    "conflict_declared",
    "review_comment_text",
    "adjudication_reason_text",
    "credential_statement_text",
    "conflict_statement_text",
    "reviewer_authority_statement",
]
REQUIRED_V61 = [
    "generation_id",
    "citation_id",
    "latency_row_id",
    "model_id",
    "checkpoint_root",
    "generation_status",
    "abstain_decision",
    "fallback_used",
    "answer_text",
    "run_transcript_text",
    "prompt_tokens",
    "output_tokens",
    "prefill_ms",
    "decode_ms",
    "total_ms",
    "tokens_per_second",
    "generation_operator_authority_statement",
]
NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def require_keys(payload, keys, label):
    missing = [key for key in keys if key not in payload]
    if missing:
        raise SystemExit(f"{label}-missing-keys:" + ";".join(missing))


def reject_nonfinal(obj, label):
    if isinstance(obj, dict):
        for key, value in obj.items():
            reject_nonfinal(value, f"{label}.{key}")
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            reject_nonfinal(value, f"{label}[{index}]")
    elif isinstance(obj, str) and has_nonfinal(obj):
        raise SystemExit(f"nonfinal-value:{label}")


def main():
    script_dir = Path(__file__).resolve().parent
    work_root = script_dir.parent
    values_path = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else script_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
    template_path = work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template"
    form_path = work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
    validator = work_root / "external_return_form" / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py"
    values_validator = work_root / "external_return_form" / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
    values_report = work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
    report = work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.validation_rows.csv"
    if not template_path.is_file():
        raise SystemExit(f"missing-form-template:{template_path}")
    if not validator.is_file():
        raise SystemExit(f"missing-form-validator:{validator}")
    if not values_validator.is_file():
        raise SystemExit(f"missing-values-validator:{values_validator}")
    if not values_path.is_file():
        raise SystemExit(f"missing-values-file:{values_path}")
    values_proc = subprocess.run([str(values_validator), str(values_path), str(values_report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if values_proc.returncode != 0:
        print(values_proc.stdout, end="")
        print(values_proc.stderr, end="", file=sys.stderr)
        raise SystemExit(values_proc.returncode)
    template = load_json(template_path)
    values = load_json(values_path)
    require_keys(values, REQUIRED_TOP, "values")
    if not isinstance(values["v53_review_return"], dict) or not isinstance(values["v61_generation_return"], dict):
        raise SystemExit("values-v53-v61-must-be-objects")
    require_keys(values["v53_review_return"], REQUIRED_V53, "values.v53_review_return")
    require_keys(values["v61_generation_return"], REQUIRED_V61, "values.v61_generation_return")
    reject_nonfinal(values, "values")

    filled = dict(template)
    filled["source_class"] = values["source_class"]
    filled["finalized"] = values["finalized"]
    filled["external_return_attestation"] = values["external_return_attestation"]
    filled["operator_input_assembly_authority_statement"] = values["operator_input_assembly_authority_statement"]
    filled["v53_review_return"] = dict(template.get("v53_review_return", {}))
    filled["v53_review_return"].update(values["v53_review_return"])
    filled["v61_generation_return"] = dict(template.get("v61_generation_return", {}))
    filled["v61_generation_return"].update(values["v61_generation_return"])

    if form_path.exists() and not (len(sys.argv) > 2 and sys.argv[2] == "--overwrite"):
        raise SystemExit(f"filled-form-exists-use-overwrite:{form_path}")
    tmp_path = form_path.with_suffix(".json.tmp")
    tmp_path.write_text(json.dumps(filled, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    proc = subprocess.run([str(validator), str(tmp_path), str(report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    shutil.move(str(tmp_path), str(form_path))
    print(f"filled external return form ready: {form_path}")
    print(f"validation report: {report}")


if __name__ == "__main__":
    main()
'''

handoff_text = """#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES_FILE="${V61HK_VALUES_FILE:-$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json}"
VALUES_VALIDATOR="$WORK_ROOT/external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
BUILDER="$WORK_ROOT/external_return_form/BUILD_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FROM_VALUES.py"
MATERIALIZER="$WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py"
READINESS="$WORK_ROOT/RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
if [[ -x "$VALUES_VALIDATOR" ]]; then
  "$VALUES_VALIDATOR" "$VALUES_FILE" "$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
fi
if [[ ! -x "$BUILDER" ]]; then
  echo "missing builder: $BUILDER" >&2
  exit 2
fi
"$BUILDER" "$VALUES_FILE" "${V61HK_BUILDER_OVERWRITE_FLAG:---overwrite}"
if [[ ! -x "$MATERIALIZER" ]]; then
  echo "missing materializer: $MATERIALIZER" >&2
  exit 2
fi
V61HE_OVERWRITE_FINAL_WITNESS="${V61HK_OVERWRITE_FINAL_WITNESS:-1}" "$MATERIALIZER" "$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
if [[ -x "$WORK_ROOT/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh" ]]; then
  "$WORK_ROOT/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh"
fi
if [[ -x "$READINESS" ]]; then
  "$READINESS"
fi
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_dir_exists = int(form_dir is not None and form_dir.is_dir())
template_path = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template" if form_dir else None
validator_path = form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" if form_dir else None
materializer_path = form_dir / "MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" if form_dir else None
template_exists = int(template_path is not None and template_path.is_file())
validator_exists = int(validator_path is not None and validator_path.is_file())
materializer_exists = int(materializer_path is not None and materializer_path.is_file())
checkpoint_hint = extract_checkpoint_hint(work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh") if work_root else ""
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo and form_dir_exists and template_exists and validator_exists)
publish_errors = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not form_dir_exists:
        publish_errors.append("external-return-form-dir-missing")
    if not template_exists:
        publish_errors.append("form-template-missing")
    if not validator_exists:
        publish_errors.append("form-validator-missing")

published_rows = []
published = 0
values_template_payload = json_template_payload(checkpoint_hint)
worksheet_rows = [
    {
        "section": "v53_review_return",
        "field": "reviewer_id",
        "minimum": "3 chars",
        "real_value_required": "1",
        "evidence_note": "real external reviewer identity; do not use a placeholder",
    },
    {
        "section": "v53_review_return",
        "field": "adjudicator_id",
        "minimum": "3 chars",
        "real_value_required": "1",
        "evidence_note": "real external adjudicator identity",
    },
    {
        "section": "v53_review_return",
        "field": "review_comment_text",
        "minimum": "40 chars",
        "real_value_required": "1",
        "evidence_note": "human/source review comment for django/__init__.py:1",
    },
    {
        "section": "v53_review_return",
        "field": "adjudication_reason_text",
        "minimum": "40 chars",
        "real_value_required": "1",
        "evidence_note": "adjudication reason for accepting/rejecting the reviewed row",
    },
    {
        "section": "v53_review_return",
        "field": "credential_statement_text",
        "minimum": "40 chars",
        "real_value_required": "1",
        "evidence_note": "reviewer credential/authority statement",
    },
    {
        "section": "v53_review_return",
        "field": "conflict_statement_text",
        "minimum": "40 chars",
        "real_value_required": "1",
        "evidence_note": "conflict disclosure; conflict_declared must remain 0 to pass",
    },
    {
        "section": "v53_review_return",
        "field": "reviewer_authority_statement",
        "minimum": "40 chars",
        "real_value_required": "1",
        "evidence_note": "final external review authority statement",
    },
    {
        "section": "v61_generation_return",
        "field": "generation_id/citation_id/latency_row_id",
        "minimum": "3 chars each",
        "real_value_required": "1",
        "evidence_note": "real generation/result identifiers",
    },
    {
        "section": "v61_generation_return",
        "field": "checkpoint_root",
        "minimum": "existing directory with 59 safetensors shards",
        "real_value_required": "1",
        "evidence_note": "live checkpoint root; template is prefilled with current hint if available",
    },
    {
        "section": "v61_generation_return",
        "field": "answer_text/run_transcript_text/generation_operator_authority_statement",
        "minimum": "40 chars each",
        "real_value_required": "1",
        "evidence_note": "source-bound answer, run transcript, and generation operator authority",
    },
    {
        "section": "v61_generation_return",
        "field": "prompt/output/prefill/decode/total/tokens_per_second",
        "minimum": "positive numeric",
        "real_value_required": "1",
        "evidence_note": "real measured latency/token values for the subset run",
    },
    {
        "section": "top",
        "field": "external_return_attestation/operator_input_assembly_authority_statement",
        "minimum": "40 chars each",
        "real_value_required": "1",
        "evidence_note": "final return attestation and operator assembly authority",
    },
]
write_csv(run_dir / "first_real_slice_external_return_form_required_value_rows.csv", list(worksheet_rows[0].keys()), worksheet_rows)

if publish_admitted:
    values_template = form_dir / VALUES_TEMPLATE_FILENAME
    values_validator = form_dir / VALUES_VALIDATOR_FILENAME
    builder = form_dir / BUILDER_FILENAME
    handoff = form_dir / HANDOFF_FILENAME
    worksheet_csv = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_REQUIRED_VALUE_ROWS.csv"
    worksheet_md = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_WORKSHEET.md"
    values_template.write_text(json.dumps(values_template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    values_validator.write_text(values_validator_text, encoding="utf-8")
    values_validator.chmod(0o755)
    builder.write_text(builder_text, encoding="utf-8")
    builder.chmod(0o755)
    handoff.write_text(handoff_text, encoding="utf-8")
    handoff.chmod(0o755)
    write_csv(worksheet_csv, list(worksheet_rows[0].keys()), worksheet_rows)
    worksheet_md.write_text(
        "\n".join([
            "# First Real Slice External Return Form Fill Worksheet",
            "",
            "Copy `FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template` to `FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json` and replace every `REPLACE_WITH_*` value with real external return data.",
            "Do not use fixture, synthetic, sample, dry-run, template, or placeholder text. The builder rejects those tokens before writing the filled form.",
            "",
            "Locked source context:",
            "- query_id: v53i_0001",
            "- source: django/__init__.py:1",
            "- evidence: from django.utils.version import get_version",
            "- expected answer behavior: answer with citation",
            "",
            "After values are final:",
            "",
            "```bash",
            "external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json",
            "external_return_form/BUILD_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FROM_VALUES.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json --overwrite",
            "external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json",
            "./RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
            "```",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [values_template, values_validator, builder, handoff, worksheet_csv, worksheet_md]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "real_evidence": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "real_evidence": "0"})
write_csv(run_dir / "first_real_slice_external_return_form_fill_packet_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "02-form-template", "status": "ready" if template_exists else "blocked", "evidence": f"template_exists={template_exists}"},
    {"stage_id": "03-form-validator", "status": "ready" if validator_exists else "blocked", "evidence": f"validator_exists={validator_exists}"},
    {"stage_id": "04-materializer", "status": "ready" if materializer_exists else "blocked", "evidence": f"materializer_exists={materializer_exists}"},
    {"stage_id": "05-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "06-fill-packet-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "07-real-values-supplied", "status": "blocked", "evidence": "requires operator-filled FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"},
    {"stage_id": "08-form-validation-pass", "status": "blocked", "evidence": "requires builder output and validator pass"},
    {"stage_id": "09-materialization", "status": "blocked", "evidence": "requires validated filled form"},
    {"stage_id": "10-readiness-audit", "status": "blocked", "evidence": "requires materialized witness/env and later authority ack"},
]
write_csv(run_dir / "first_real_slice_external_return_form_fill_packet_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-publish-fill-packet", "ready_to_run_now": str(int(work_root_exists and work_root_outside_repo and template_exists and validator_exists)), "command": "V61HK_PUBLISH_PACKET=1 ./experiments/run_v61hk_post_hj_first_real_slice_external_return_form_fill_packet.sh", "purpose": "publish values template, builder, worksheet, and handoff"},
    {"command_id": "02-preflight-values", "ready_to_run_now": str(published), "command": f"external_return_form/{VALUES_VALIDATOR_FILENAME} external_return_form/{VALUES_FILENAME}", "purpose": "show all missing/nonfinal/invalid real external return values"},
    {"command_id": "03-build-filled-form", "ready_to_run_now": str(published), "command": f"external_return_form/{BUILDER_FILENAME} external_return_form/{VALUES_FILENAME} --overwrite", "purpose": "write FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json only after value precheck and validator pass"},
    {"command_id": "04-validate-materialize-audit", "ready_to_run_now": str(published), "command": f"external_return_form/{HANDOFF_FILENAME}", "purpose": "build, validate, materialize witness/env, and run readiness audit"},
]
write_csv(run_dir / "first_real_slice_external_return_form_fill_packet_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_REQUIRED_VALUE_ROWS.csv", run_dir / "first_real_slice_external_return_form_required_value_rows.csv"),
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_external_return_form_fill_packet_published_rows.csv"),
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_STAGE_ROWS.csv", run_dir / "first_real_slice_external_return_form_fill_packet_stage_rows.csv"),
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_COMMAND_ROWS.csv", run_dir / "first_real_slice_external_return_form_fill_packet_command_rows.csv"),
]:
    target = package_dir / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(src.read_bytes())

(package_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template").write_text(json.dumps(values_template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / VALUES_VALIDATOR_FILENAME).write_text(values_validator_text, encoding="utf-8")
(package_dir / VALUES_VALIDATOR_FILENAME).chmod(0o755)
(package_dir / "VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template\"",
        "test -x \"$DIR/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_REQUIRED_VALUE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_MANIFEST.json\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET.sh").chmod(0o755)

summary = {
    "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_ready": "1",
    "work_root_supplied": str(work_root_supplied),
    "work_root_exists": str(work_root_exists),
    "work_root_outside_repo": str(work_root_outside_repo),
    "form_dir_exists": str(form_dir_exists),
    "form_template_exists": str(template_exists),
    "form_validator_exists": str(validator_exists),
    "form_materializer_exists": str(materializer_exists),
    "checkpoint_root_hint_supplied": str(int(bool(checkpoint_hint))),
    "publish_requested": str(publish_requested),
    "publish_admitted": str(publish_admitted),
    "fill_packet_published": str(published),
    "required_value_rows": str(len(worksheet_rows)),
    "real_external_values_supplied": "0",
    "external_return_form_validation_ready": "0",
    "workspace_gap_preflight_ready": "0",
    "authority_ack_validation_ready": "0",
    "real_external_review_return_rows": "0",
    "real_adjudication_rows": "0",
    "slice_answer_review_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61hk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-template", "status": "pass" if template_exists else "blocked", "evidence": f"template_exists={template_exists}"},
    {"gate": "form-validator", "status": "pass" if validator_exists else "blocked", "evidence": f"validator_exists={validator_exists}"},
    {"gate": "fill-packet-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "real-values-supplied", "status": "blocked", "evidence": "operator-filled values file required"},
    {"gate": "external-return-form-validation", "status": "blocked", "evidence": "validator pass requires real values"},
    {"gate": "workspace-gap-preflight", "status": "blocked", "evidence": "materializer must run after validator pass"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "dual replay and v61gf counter audit not run"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": "v61hk_post_hj_first_real_slice_external_return_form_fill_packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "claim_boundary": "fill packet only; no real evidence accepted and no replay executed",
}
(package_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61HK_POST_HJ_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_FILL_PACKET_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HK First Real Slice External Return Form Fill Packet",
        "",
        f"- fill_packet_published={published}",
        f"- required_value_rows={len(worksheet_rows)}",
        "- real_external_values_supplied=0",
        "- external_return_form_validation_ready=0",
        "- workspace_gap_preflight_ready=0",
        "- row_acceptance_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "This packet exists to capture actual external values; it intentionally does not invent or accept them.",
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
write_csv(run_dir / "first_real_slice_external_return_form_fill_packet_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = str(len(package_rows))
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / "v61hk_post_hj_first_real_slice_external_return_form_fill_packet_summary.csv", list(summary.keys()), [summary])

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hk_post_hj_first_real_slice_external_return_form_fill_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
