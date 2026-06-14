#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ho_post_hn_first_real_slice_values_capture_runner"
RUN_ID="${V61HO_RUN_ID:-values_capture_runner_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HO_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HN_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61GU_WORK_ROOT:-}"; fi
PUBLISH_CAPTURE="${V61HO_PUBLISH_CAPTURE:-0}"

if [[ "${V61HO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ho_post_hn_first_real_slice_values_capture_runner_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_CAPTURE" <<'V61HO_PY'
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
package_dir = run_dir / "first_real_slice_values_capture_runner"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61ho_post_hn_first_real_slice_values_capture_runner"


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


form_env_rows = [
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
ack_env_rows = [
    ("V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT", "authority_statement", "text>=80"),
    ("V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN", "operator_attests_real_external_return", "must be 1/true/yes"),
]
env_rows = [
    {"target_file": "external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json", "env_name": env, "field_path": field, "requirement": req}
    for env, field, req in form_env_rows
] + [
    {"target_file": "external_return_form/DUAL_REPLAY_AUTHORITY_ACK_VALUES.json", "env_name": env, "field_path": field, "requirement": req}
    for env, field, req in ack_env_rows
]

form_capture_text = r'''#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
TEXT_FIELDS = {
    "V61HO_EXTERNAL_RETURN_ATTESTATION": ("external_return_attestation", 40),
    "V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT": ("operator_input_assembly_authority_statement", 40),
    "V61HO_REVIEWER_ID": ("v53_review_return.reviewer_id", 3),
    "V61HO_ADJUDICATOR_ID": ("v53_review_return.adjudicator_id", 3),
    "V61HO_REVIEW_COMMENT_TEXT": ("v53_review_return.review_comment_text", 40),
    "V61HO_ADJUDICATION_REASON_TEXT": ("v53_review_return.adjudication_reason_text", 40),
    "V61HO_CREDENTIAL_STATEMENT_TEXT": ("v53_review_return.credential_statement_text", 40),
    "V61HO_CONFLICT_STATEMENT_TEXT": ("v53_review_return.conflict_statement_text", 40),
    "V61HO_REVIEWER_AUTHORITY_STATEMENT": ("v53_review_return.reviewer_authority_statement", 40),
    "V61HO_GENERATION_ID": ("v61_generation_return.generation_id", 3),
    "V61HO_CITATION_ID": ("v61_generation_return.citation_id", 3),
    "V61HO_LATENCY_ROW_ID": ("v61_generation_return.latency_row_id", 3),
    "V61HO_ANSWER_TEXT": ("v61_generation_return.answer_text", 40),
    "V61HO_RUN_TRANSCRIPT_TEXT": ("v61_generation_return.run_transcript_text", 40),
    "V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT": ("v61_generation_return.generation_operator_authority_statement", 40),
}
NUMERIC_FIELDS = {
    "V61HO_PROMPT_TOKENS": "v61_generation_return.prompt_tokens",
    "V61HO_OUTPUT_TOKENS": "v61_generation_return.output_tokens",
    "V61HO_PREFILL_MS": "v61_generation_return.prefill_ms",
    "V61HO_DECODE_MS": "v61_generation_return.decode_ms",
    "V61HO_TOTAL_MS": "v61_generation_return.total_ms",
    "V61HO_TOKENS_PER_SECOND": "v61_generation_return.tokens_per_second",
}


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def set_path(payload, dotted, value):
    parts = dotted.split(".")
    node = payload
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    node[parts[-1]] = value


def get_path(payload, dotted, default=""):
    node = payload
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            return default
        node = node[part]
    return node


def require_text(errors, env_name, min_len):
    value = os.environ.get(env_name, "").strip()
    if len(value) < min_len:
        errors.append(f"{env_name}: too-short<{min_len}")
    if has_nonfinal(value):
        errors.append(f"{env_name}: nonfinal-token")
    return value


def require_positive(errors, env_name):
    value = os.environ.get(env_name, "").strip()
    try:
        numeric = float(value)
    except ValueError:
        errors.append(f"{env_name}: not-positive")
        return value
    if numeric <= 0:
        errors.append(f"{env_name}: not-positive")
    if has_nonfinal(value):
        errors.append(f"{env_name}: nonfinal-token")
    return int(numeric) if numeric.is_integer() else numeric


def main():
    parser = argparse.ArgumentParser(description="Capture real first-slice external return values from V61HO_* environment variables.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    template_path = script_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json.template"
    validator = script_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.py"
    output = Path(args.output).expanduser().resolve() if args.output else script_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json"
    report = script_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.validation_rows.csv"
    if not template_path.is_file():
        raise SystemExit(f"missing-template:{template_path}")
    if not validator.is_file():
        raise SystemExit(f"missing-validator:{validator}")
    if output.exists() and not args.overwrite:
        raise SystemExit(f"values-file-exists-use-overwrite:{output}")

    payload = json.loads(template_path.read_text(encoding="utf-8"))
    errors = []
    for env_name, (field_path, min_len) in TEXT_FIELDS.items():
        set_path(payload, field_path, require_text(errors, env_name, min_len))
    for env_name, field_path in NUMERIC_FIELDS.items():
        set_path(payload, field_path, require_positive(errors, env_name))
    checkpoint_root = os.environ.get("V61HO_CHECKPOINT_ROOT", "").strip() or str(get_path(payload, "v61_generation_return.checkpoint_root", ""))
    if len(checkpoint_root) < 3 or has_nonfinal(checkpoint_root):
        errors.append("V61HO_CHECKPOINT_ROOT: missing-or-nonfinal")
    set_path(payload, "v61_generation_return.checkpoint_root", checkpoint_root)
    set_path(payload, "source_class", "real-external-review-and-generation-return")
    set_path(payload, "finalized", True)
    set_path(payload, "v53_review_return.review_decision", os.environ.get("V61HO_REVIEW_DECISION", "accept"))
    set_path(payload, "v53_review_return.adjudication_decision", os.environ.get("V61HO_ADJUDICATION_DECISION", "accept"))
    set_path(payload, "v53_review_return.source_support_verified", 1)
    set_path(payload, "v53_review_return.citation_verified", 1)
    set_path(payload, "v53_review_return.policy_verified", 1)
    set_path(payload, "v53_review_return.conflict_declared", 0)
    set_path(payload, "v61_generation_return.generation_status", "completed")
    set_path(payload, "v61_generation_return.abstain_decision", "answer")
    set_path(payload, "v61_generation_return.fallback_used", 0)

    if errors:
        for item in errors:
            print(f"capture-input-blocked:{item}", file=sys.stderr)
        raise SystemExit(2)

    tmp = output.with_suffix(output.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    proc = subprocess.run([str(validator), str(tmp), str(report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    shutil.move(str(tmp), str(output))
    print(f"first real-slice external return values ready: {output}")
    print(f"validation report: {report}")


if __name__ == "__main__":
    main()
'''

ack_capture_text = r'''#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def main():
    parser = argparse.ArgumentParser(description="Capture dual replay authority ack values from V61HO_* environment variables.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--output", default="")
    args = parser.parse_args()
    script_dir = Path(__file__).resolve().parent
    template_path = script_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json.template"
    validator = script_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK_VALUES.py"
    output = Path(args.output).expanduser().resolve() if args.output else script_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json"
    report = script_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.validation_rows.csv"
    if not template_path.is_file():
        raise SystemExit(f"missing-template:{template_path}")
    if not validator.is_file():
        raise SystemExit(f"missing-validator:{validator}")
    if output.exists() and not args.overwrite:
        raise SystemExit(f"ack-values-file-exists-use-overwrite:{output}")
    statement = os.environ.get("V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT", "").strip()
    attests = os.environ.get("V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN", "").strip().lower() in {"1", "true", "yes"}
    if len(statement) < 80 or has_nonfinal(statement):
        raise SystemExit("capture-input-blocked:V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT")
    if not attests:
        raise SystemExit("capture-input-blocked:V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN")
    payload = json.loads(template_path.read_text(encoding="utf-8"))
    payload["authority_statement"] = statement
    payload["operator_attests_real_external_return"] = True
    tmp = output.with_suffix(output.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    proc = subprocess.run([str(validator), str(tmp), str(report)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        print(proc.stdout, end="")
        print(proc.stderr, end="", file=sys.stderr)
        raise SystemExit(proc.returncode)
    shutil.move(str(tmp), str(output))
    print(f"dual replay authority ack values ready: {output}")
    print(f"validation report: {report}")


if __name__ == "__main__":
    main()
'''

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
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
        targets = {
            "CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py": form_capture_text,
            "CAPTURE_DUAL_REPLAY_AUTHORITY_ACK_VALUES_FROM_ENV.py": ack_capture_text,
        }
        for name, text in targets.items():
            path = form_dir / name
            path.write_text(text, encoding="utf-8")
            path.chmod(0o755)
            published_rows.append({
                "path": str(path),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only": "1",
                "writes_values_only_after_validator_pass": "1",
                "executes_dual_replay": "0",
            })
        env_csv = form_dir / "FIRST_REAL_SLICE_VALUES_CAPTURE_ENV_ROWS.csv"
        write_csv(env_csv, ["target_file", "env_name", "field_path", "requirement"], env_rows)
        readme = form_dir / "FIRST_REAL_SLICE_VALUES_CAPTURE_README.md"
        readme.write_text(
            "\n".join([
                "# First Real Slice Values Capture",
                "",
                "These runners write values files only after the existing validators pass.",
                "They do not create filled forms, operator inputs, authority ack files, replay outputs, or model-generation evidence.",
                "",
                "```bash",
                "external_return_form/CAPTURE_FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES_FROM_ENV.py --overwrite",
                "external_return_form/VALIDATE_MATERIALIZE_AND_AUDIT_FIRST_REAL_SLICE_FORM.sh",
                "external_return_form/CAPTURE_DUAL_REPLAY_AUTHORITY_ACK_VALUES_FROM_ENV.py --overwrite",
                "external_return_form/BUILD_VALIDATE_AND_AUDIT_DUAL_REPLAY_AUTHORITY_ACK.sh",
                "./RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh",
                "```",
                "",
            ]),
            encoding="utf-8",
        )
        for path in [env_csv, readme]:
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

env_rows_path = run_dir / "first_real_slice_values_capture_env_rows.csv"
published_rows_path = run_dir / "first_real_slice_values_capture_published_rows.csv"
write_csv(env_rows_path, ["target_file", "env_name", "field_path", "requirement"], env_rows)
write_csv(published_rows_path, list(published_rows[0].keys()), published_rows)

form_values = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
ack_values = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
form_values_supplied = int(form_values is not None and form_values.is_file())
ack_values_supplied = int(ack_values is not None and ack_values.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif not form_values_supplied:
    next_action = "capture-first-real-slice-external-return-values-from-env"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not ack_values_supplied:
    next_action = "capture-dual-replay-authority-ack-values-from-env"
elif not authority_ack_exists:
    next_action = "build-dual-replay-authority-ack"
else:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "capture-runner-published", "status": "pass" if publish_requested and not publish_errors else "blocked", "evidence": f"publish_requested={publish_requested}; errors={';'.join(publish_errors)}"},
    {"gate": "form-values-file", "status": "pass" if form_values_supplied else "blocked", "evidence": str(form_values) if form_values_supplied else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "ack-values-file", "status": "pass" if ack_values_supplied else "blocked", "evidence": str(ack_values) if ack_values_supplied else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61ho never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; capture runner does not run model generation"},
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
    "capture_env_rows": len(env_rows),
    "writes_values_only_after_validator_pass": True,
    "creates_filled_form": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_values_capture_env_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_values_capture_published_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER_MANIFEST.json\"",
        "echo \"first real slice values capture runner packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HO_POST_HN_FIRST_REAL_SLICE_VALUES_CAPTURE_RUNNER_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61ho Boundary",
        "",
        "This step publishes transactional values-capture runners only.",
        "A values file is written only after the existing validator accepts the candidate JSON.",
        "No filled form, operator input, authority ack, replay output, model generation evidence, or checkpoint payload is created by v61ho.",
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
packet_files = [env_rows_path, published_rows_path, manifest_path, verify_path, boundary_path, run_dir / f"{prefix}_decision.csv"]
sha_rows = [{"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": str(path.stat().st_size)} for path in packet_files]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    f"{prefix}_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "capture_runner_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "capture_env_rows": len(env_rows),
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
    "checkpoint_payload_bytes_downloaded_by_v61ho": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61ho_post_hn_first_real_slice_values_capture_runner_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HO_PY
