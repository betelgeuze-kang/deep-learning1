#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hp_post_ho_first_real_slice_env_file_capture_handoff"
RUN_ID="${V61HP_RUN_ID:-env_file_capture_handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HP_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HO_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HN_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_HANDOFF="${V61HP_PUBLISH_HANDOFF:-0}"

if [[ "${V61HP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hp_post_ho_first_real_slice_env_file_capture_handoff_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_HANDOFF" <<'V61HP_PY'
import csv
import hashlib
import json
import os
import shlex
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
package_dir = run_dir / "first_real_slice_env_file_capture_handoff"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61hp_post_ho_first_real_slice_env_file_capture_handoff"

FORM_KEYS = [
    ("V61HO_EXTERNAL_RETURN_ATTESTATION", "external_return_attestation", "text>=40"),
    ("V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT", "operator_input_assembly_authority_statement", "text>=40"),
    ("V61HO_REVIEWER_ID", "v53_review_return.reviewer_id", "text>=3"),
    ("V61HO_ADJUDICATOR_ID", "v53_review_return.adjudicator_id", "text>=3"),
    ("V61HO_REVIEW_COMMENT_TEXT", "v53_review_return.review_comment_text", "text>=40"),
    ("V61HO_ADJUDICATION_REASON_TEXT", "v53_review_return.adjudication_reason_text", "text>=40"),
    ("V61HO_CREDENTIAL_STATEMENT_TEXT", "v53_review_return.credential_statement_text", "text>=40"),
    ("V61HO_CONFLICT_STATEMENT_TEXT", "v53_review_return.conflict_statement_text", "text>=40"),
    ("V61HO_REVIEWER_AUTHORITY_STATEMENT", "v53_review_return.reviewer_authority_statement", "text>=40"),
    ("V61HO_GENERATION_ID", "v61_generation_return.generation_id", "text>=3"),
    ("V61HO_CITATION_ID", "v61_generation_return.citation_id", "text>=3"),
    ("V61HO_LATENCY_ROW_ID", "v61_generation_return.latency_row_id", "text>=3"),
    ("V61HO_CHECKPOINT_ROOT", "v61_generation_return.checkpoint_root", "directory with 59 model-*-of-00059.safetensors files"),
    ("V61HO_ANSWER_TEXT", "v61_generation_return.answer_text", "text>=40"),
    ("V61HO_RUN_TRANSCRIPT_TEXT", "v61_generation_return.run_transcript_text", "text>=40"),
    ("V61HO_PROMPT_TOKENS", "v61_generation_return.prompt_tokens", "positive numeric"),
    ("V61HO_OUTPUT_TOKENS", "v61_generation_return.output_tokens", "positive numeric"),
    ("V61HO_PREFILL_MS", "v61_generation_return.prefill_ms", "positive numeric"),
    ("V61HO_DECODE_MS", "v61_generation_return.decode_ms", "positive numeric"),
    ("V61HO_TOTAL_MS", "v61_generation_return.total_ms", "positive numeric"),
    ("V61HO_TOKENS_PER_SECOND", "v61_generation_return.tokens_per_second", "positive numeric"),
    ("V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT", "v61_generation_return.generation_operator_authority_statement", "text>=40"),
]
ACK_KEYS = [
    ("V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT", "authority_statement", "text>=80"),
    ("V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN", "operator_attests_real_external_return", "must be 1/true/yes"),
]
ALL_KEYS = FORM_KEYS + ACK_KEYS


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


def checkpoint_hint(form_dir):
    template = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template" if form_dir else None
    if template is not None and template.is_file():
        try:
            payload = json.loads(template.read_text(encoding="utf-8"))
            value = str(payload.get("v61_generation_return", {}).get("checkpoint_root", "")).strip()
            if value and "REPLACE_WITH" not in value:
                return value
        except Exception:
            return ""
    return ""


def env_value_for(key, hint):
    if key == "V61HO_CHECKPOINT_ROOT" and hint:
        return hint
    if key == "V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN":
        return "false"
    return f"REPLACE_WITH_REAL_{key.removeprefix('V61HO_')}"


def shell_quote(value):
    return shlex.quote(str(value))


env_file_handoff_text = r'''#!/usr/bin/env python3
import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path

FORM_KEYS = [
    "V61HO_EXTERNAL_RETURN_ATTESTATION",
    "V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT",
    "V61HO_REVIEWER_ID",
    "V61HO_ADJUDICATOR_ID",
    "V61HO_REVIEW_COMMENT_TEXT",
    "V61HO_ADJUDICATION_REASON_TEXT",
    "V61HO_CREDENTIAL_STATEMENT_TEXT",
    "V61HO_CONFLICT_STATEMENT_TEXT",
    "V61HO_REVIEWER_AUTHORITY_STATEMENT",
    "V61HO_GENERATION_ID",
    "V61HO_CITATION_ID",
    "V61HO_LATENCY_ROW_ID",
    "V61HO_CHECKPOINT_ROOT",
    "V61HO_ANSWER_TEXT",
    "V61HO_RUN_TRANSCRIPT_TEXT",
    "V61HO_PROMPT_TOKENS",
    "V61HO_OUTPUT_TOKENS",
    "V61HO_PREFILL_MS",
    "V61HO_DECODE_MS",
    "V61HO_TOTAL_MS",
    "V61HO_TOKENS_PER_SECOND",
    "V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT",
]
ACK_KEYS = [
    "V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT",
    "V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN",
]
ALLOWED_KEYS = set(FORM_KEYS + ACK_KEYS)


def parse_env_file(path):
    parsed = {}
    errors = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        if "=" not in line:
            errors.append(f"line {lineno}: expected KEY=VALUE")
            continue
        key, value_text = line.split("=", 1)
        key = key.strip()
        if key not in ALLOWED_KEYS:
            errors.append(f"line {lineno}: unknown key {key}")
            continue
        try:
            tokens = shlex.split(value_text, posix=True)
        except ValueError as exc:
            errors.append(f"line {lineno}: invalid shell quoting: {exc}")
            continue
        if len(tokens) != 1:
            errors.append(f"line {lineno}: value must be one quoted token")
            continue
        parsed[key] = tokens[0]
    return parsed, errors


def run_capture(capture_script, env, overwrite):
    command = [str(capture_script)]
    if overwrite:
        command.append("--overwrite")
    return subprocess.run(command, env=env, text=True)


def main():
    parser = argparse.ArgumentParser(description="Load a restricted env file and run validator-gated first-slice capture.")
    parser.add_argument("env_file")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--capture-ack", action="store_true")
    args = parser.parse_args()
    form_dir = Path(__file__).resolve().parent
    env_file = Path(args.env_file).expanduser().resolve()
    if not env_file.is_file():
        raise SystemExit(f"missing-env-file:{env_file}")
    values_capture = form_dir / "CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py"
    ack_capture = form_dir / "CAPTURE_DUAL_REPLAY_AUTHORITY_ACK_VALUES_FROM_ENV.py"
    if not values_capture.is_file():
        raise SystemExit(f"missing-values-capture-runner:{values_capture}")
    parsed, errors = parse_env_file(env_file)
    missing = [key for key in FORM_KEYS if not parsed.get(key, "").strip()]
    if missing:
        errors.extend(f"missing:{key}" for key in missing)
    if args.capture_ack:
        ack_missing = [key for key in ACK_KEYS if not parsed.get(key, "").strip()]
        errors.extend(f"missing:{key}" for key in ack_missing)
        if not ack_capture.is_file():
            errors.append(f"missing-ack-capture-runner:{ack_capture}")
    if errors:
        for item in errors:
            print(f"env-file-capture-blocked:{item}", file=sys.stderr)
        raise SystemExit(2)
    env = os.environ.copy()
    env.update(parsed)
    values_proc = run_capture(values_capture, env, args.overwrite)
    if values_proc.returncode != 0:
        raise SystemExit(values_proc.returncode)
    if args.capture_ack:
        ack_proc = run_capture(ack_capture, env, args.overwrite)
        if ack_proc.returncode != 0:
            raise SystemExit(ack_proc.returncode)


if __name__ == "__main__":
    main()
'''

shell_runner_text = """#!/usr/bin/env bash
set -euo pipefail
FORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${V61HP_VALUES_ENV_FILE:-$FORM_DIR/FIRST_REAL_SLICE_VALUES.env}"
HANDOFF="$FORM_DIR/CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.py"
ARGS=("$ENV_FILE")
if [[ "${V61HP_OVERWRITE:-0}" == "1" ]]; then
  ARGS+=("--overwrite")
fi
if [[ "${V61HP_CAPTURE_ACK_VALUES:-0}" == "1" ]]; then
  ARGS+=("--capture-ack")
fi
exec "$HANDOFF" "${ARGS[@]}"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
hint = checkpoint_hint(form_dir)
env_rows = [
    {
        "target_file": "external_return_form/FIRST_REAL_SLICE_VALUES.env",
        "env_name": key,
        "field_path": field,
        "requirement": requirement,
        "required_for_form_capture": str(int((key, field, requirement) in FORM_KEYS)),
        "required_for_ack_capture": str(int((key, field, requirement) in ACK_KEYS)),
    }
    for key, field, requirement in ALL_KEYS
]
env_template_lines = [
    "# Copy this file to FIRST_REAL_SLICE_VALUES.env, replace every placeholder with real external values,",
    "# then run RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh.",
    "# The handoff parser accepts only the V61HO_* keys listed below.",
    "",
]
for key, _field, requirement in ALL_KEYS:
    env_template_lines.append(f"# requirement: {requirement}")
    env_template_lines.append(f"export {key}={shell_quote(env_value_for(key, hint))}")
    env_template_lines.append("")
env_template_text = "\n".join(env_template_lines)

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if form_dir is not None:
        if not (form_dir / "CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py").is_file():
            publish_errors.append("values-capture-runner-missing")
    if not publish_errors:
        files = {
            "CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.py": env_file_handoff_text,
            "RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh": shell_runner_text,
            "FIRST_REAL_SLICE_VALUES.env.template": env_template_text,
        }
        for name, text in files.items():
            path = form_dir / name
            path.write_text(text, encoding="utf-8")
            if name.endswith((".py", ".sh")):
                path.chmod(0o755)
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "writes_values_only_after_validator_pass": str(int(name.endswith(".py") or name.endswith(".sh"))),
                "executes_dual_replay": "0",
            })
        rows_path = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_FILE_ROWS.csv"
        write_csv(rows_path, ["target_file", "env_name", "field_path", "requirement", "required_for_form_capture", "required_for_ack_capture"], env_rows)
        readme = form_dir / "FIRST_REAL_SLICE_VALUES_ENV_FILE_README.md"
        readme.write_text(
            "\n".join([
                "# First Real Slice Env File Capture",
                "",
                "Copy `FIRST_REAL_SLICE_VALUES.env.template` to `FIRST_REAL_SLICE_VALUES.env` and replace every placeholder with real external review, generation, latency, and authority values.",
                "The parser accepts only the listed `V61HO_*` keys and then calls the validator-gated v61ho capture runner.",
                "",
                "```bash",
                "cp external_return_form/FIRST_REAL_SLICE_VALUES.env.template external_return_form/FIRST_REAL_SLICE_VALUES.env",
                "V61HP_OVERWRITE=1 external_return_form/RUN_CAPTURE_FIRST_REAL_SLICE_VALUES_FROM_ENV_FILE.sh",
                "external_return_form/VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh",
                "```",
                "",
                "This handoff does not create filled forms, operator inputs, authority ack files, replay outputs, or generation evidence by itself.",
                "",
            ]),
            encoding="utf-8",
        )
        for path in [rows_path, readme]:
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "writes_values_only_after_validator_pass": "0",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "writes_values_only_after_validator_pass": "0", "executes_dual_replay": "0"})

env_rows_path = run_dir / "first_real_slice_values_env_file_rows.csv"
published_rows_path = run_dir / "first_real_slice_env_file_capture_handoff_published_rows.csv"
env_template_path = package_dir / "FIRST_REAL_SLICE_VALUES.env.template"
write_csv(env_rows_path, ["target_file", "env_name", "field_path", "requirement", "required_for_form_capture", "required_for_ack_capture"], env_rows)
write_csv(published_rows_path, list(published_rows[0].keys()), published_rows)
env_template_path.write_text(env_template_text, encoding="utf-8")

form_values = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_values = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
form_values_supplied = int(form_values is not None and form_values.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
ack_values_supplied = int(ack_values is not None and ack_values.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not form_values_supplied:
    next_action = "copy-env-template-fill-real-values-run-capture-handoff"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not ack_values_supplied:
    next_action = "fill-or-capture-dual-replay-authority-ack-values"
elif not authority_ack_exists:
    next_action = "build-dual-replay-authority-ack"
else:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "capture-runner-present", "status": "pass" if form_dir is not None and (form_dir / "CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py").is_file() else "blocked", "evidence": "requires v61ho capture runner"},
    {"gate": "env-file-handoff-published", "status": "pass" if publish_requested and not publish_errors else "blocked", "evidence": f"publish_requested={publish_requested}; errors={';'.join(publish_errors)}"},
    {"gate": "form-values-file", "status": "pass" if form_values_supplied else "blocked", "evidence": str(form_values) if form_values_supplied else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61hp never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; env-file handoff does not run model generation"},
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
    "env_file_rows": len(env_rows),
    "uses_restricted_env_parser": True,
    "writes_values_only_after_validator_pass": True,
    "creates_filled_form": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_values_env_file_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_env_file_capture_handoff_published_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_VALUES.env.template\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF_MANIFEST.json\"",
        "echo \"first real slice env-file capture handoff packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HP_POST_HO_FIRST_REAL_SLICE_ENV_FILE_CAPTURE_HANDOFF_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61hp Boundary",
        "",
        "This step publishes a restricted env-file handoff for first real-slice values.",
        "It accepts only the enumerated V61HO_* keys, then delegates to the existing validator-gated capture runner.",
        "It does not create filled forms, operator inputs, authority ack files, replay outputs, model generation evidence, or checkpoint payload.",
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
packet_files = [env_rows_path, published_rows_path, env_template_path, manifest_path, verify_path, boundary_path, run_dir / f"{prefix}_decision.csv"]
sha_rows = [{"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": str(path.stat().st_size)} for path in packet_files]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    f"{prefix}_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "env_file_handoff_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "env_file_rows": len(env_rows),
    "form_values_supplied": form_values_supplied,
    "filled_form_exists": filled_form_exists,
    "ack_values_supplied": ack_values_supplied,
    "authority_ack_exists": authority_ack_exists,
    "next_real_subset_action": next_action,
    "row_acceptance_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hp": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61hp_post_ho_first_real_slice_env_file_capture_handoff_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HP_PY
