#!/usr/bin/env python3
"""Validate a human AMR beta runtime approval record.

This is the final read-only gate before the long real_benchmark command. It
checks that a human-supplied approval record is bound to the exact green
preflight, approval request, runtime commands, and benchmark output path.

It does not run the benchmark, does not create benchmark evidence, and does not
promote beta/release/model/public-comparison readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import sys
from pathlib import Path

STATUS_SCHEMA = "amr_beta_runtime_approval_status.v1"
PREFLIGHT_SCHEMA = "amr_beta_runtime_preflight.v1"
REQUEST_SCHEMA = "amr_beta_runtime_approval_request.v1"
RECORD_SCHEMA = "amr_beta_runtime_approval_record.v1"
APPROVAL_SCOPE = "amr_beta_real_benchmark_runtime"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
VERIFY_EXISTING_COUNTER_KEYS = [
    "template_dir_count",
    "label_template_verify_existing_required",
    "label_template_verify_existing_passed_dirs",
    "label_template_verify_existing_failed_dirs",
    "label_intake_dir_count",
    "label_intake_verify_existing_required",
    "label_intake_verify_existing_passed_dirs",
    "label_intake_verify_existing_failed_dirs",
]
PREFLIGHT_SHA_BINDING_KEYS = [
    "repo_intake_sha256",
    "repo_snapshot_lock_sha256",
    "decisions_sha256",
    "feedback_sha256",
    "label_template_bundle_sha256",
    "label_intake_bundle_sha256",
    "preflight_input_bundle_sha256",
]
PREFLIGHT_LIST_BINDING_KEYS = [
    ("label_template_json_sha256s", "template_dir_count"),
    ("label_template_manifest_sha256s", "template_dir_count"),
    ("label_intake_manifest_sha256s", "label_intake_dir_count"),
]
PREFLIGHT_PATH_GUARD_KEYS = [
    "input_path_preflight_passed",
    "output_path_preflight_passed",
]
PLACEHOLDER_APPROVERS = {
    "agent",
    "automation",
    "codex",
    "cursor",
    "example",
    "openai",
    "placeholder",
    "tbd",
    "todo",
}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_json(path: Path, input_name: str) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def truthy(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    return False


def positive_int(value: object) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError):
        return 0
    return result if result > 0 else 0


def command_parts(command: str) -> list[str]:
    try:
        return shlex.split(command)
    except ValueError:
        return []


def command_option(command: str, option: str) -> str:
    parts = command_parts(command)
    for index, part in enumerate(parts):
        if part == option and index + 1 < len(parts):
            return parts[index + 1]
    return ""


def same_path(left: str, right: str) -> bool:
    return str(Path(left).expanduser().resolve()) == str(Path(right).expanduser().resolve())


def placeholder_approver(value: object) -> bool:
    normalized = str(value or "").strip().lower()
    return not normalized or normalized in PLACEHOLDER_APPROVERS or normalized.startswith("example")


def int_field(payload: dict, key: str, errors: list[str], input_name: str) -> int:
    try:
        return int(payload.get(key, -1))
    except (TypeError, ValueError):
        errors.append(f"{input_name} {key} must be an integer")
        return -1


def validate_preflight_verify_existing_counts(preflight: dict) -> list[str]:
    errors: list[str] = []
    for prefix, count_key in [
        ("label_template", "template_dir_count"),
        ("label_intake", "label_intake_dir_count"),
    ]:
        dir_count = int_field(preflight, count_key, errors, "runtime preflight")
        required = int_field(preflight, f"{prefix}_verify_existing_required", errors, "runtime preflight")
        passed = int_field(preflight, f"{prefix}_verify_existing_passed_dirs", errors, "runtime preflight")
        failed = int_field(preflight, f"{prefix}_verify_existing_failed_dirs", errors, "runtime preflight")
        if dir_count <= 0:
            errors.append(f"runtime preflight {count_key} must be positive")
        if required != 1:
            errors.append(f"runtime preflight must set {prefix}_verify_existing_required=1")
        if failed != 0:
            errors.append(f"runtime preflight must set {prefix}_verify_existing_failed_dirs=0")
        if dir_count > 0 and passed != dir_count:
            errors.append(
                f"runtime preflight {prefix}_verify_existing_passed_dirs must equal {count_key}"
            )
    return errors


def validate_preflight_sha_binding_fields(preflight: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_SHA_BINDING_KEYS:
        value = str(preflight.get(key) or "")
        if not SHA256_RE.fullmatch(value):
            errors.append(f"runtime preflight {key} must be a sha256 digest")
    for key, count_key in PREFLIGHT_LIST_BINDING_KEYS:
        expected_count = int_field(preflight, count_key, errors, "runtime preflight")
        values = preflight.get(key)
        if not isinstance(values, list):
            errors.append(f"runtime preflight {key} must be a list")
            continue
        if expected_count > 0 and len(values) != expected_count:
            errors.append(f"runtime preflight {key} length must equal {count_key}")
        for value in values:
            if not SHA256_RE.fullmatch(str(value or "")):
                errors.append(f"runtime preflight {key} contains a non-sha256 digest")
                break
    return errors


def validate_preflight_path_guard_fields(preflight: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_PATH_GUARD_KEYS:
        if int_field(preflight, key, errors, "runtime preflight") != 1:
            errors.append(f"runtime preflight must set {key}=1")
    return errors


def validate_fingerprint_bundle_consistency(preflight: dict) -> list[str]:
    errors: list[str] = []
    template_fingerprints = preflight.get("label_template_fingerprints")
    if not isinstance(template_fingerprints, list):
        errors.append("runtime preflight label_template_fingerprints must be a list")
        template_fingerprints = []
    if len(template_fingerprints) != int(preflight.get("template_dir_count", -1)):
        errors.append("runtime preflight label_template_fingerprints length must equal template_dir_count")
    template_json_sha256s = [
        str(row.get("label_template_json_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict)
    ]
    template_manifest_sha256s = [
        str(row.get("label_template_manifest_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict) and str(row.get("label_template_manifest_sha256") or "")
    ]
    if preflight.get("label_template_json_sha256s") != template_json_sha256s:
        errors.append("runtime preflight label_template_json_sha256s must match label_template_fingerprints")
    if preflight.get("label_template_manifest_sha256s") != template_manifest_sha256s:
        errors.append("runtime preflight label_template_manifest_sha256s must match label_template_fingerprints")
    if str(preflight.get("label_template_bundle_sha256") or "") != sha256_json(template_fingerprints):
        errors.append("runtime preflight label_template_bundle_sha256 does not match label_template_fingerprints")

    label_intake_fingerprints = preflight.get("label_intake_fingerprints")
    if not isinstance(label_intake_fingerprints, list):
        errors.append("runtime preflight label_intake_fingerprints must be a list")
        label_intake_fingerprints = []
    if len(label_intake_fingerprints) != int(preflight.get("label_intake_dir_count", -1)):
        errors.append("runtime preflight label_intake_fingerprints length must equal label_intake_dir_count")
    label_intake_manifest_sha256s = [
        str(row.get("label_intake_manifest_sha256") or "")
        for row in label_intake_fingerprints
        if isinstance(row, dict)
    ]
    if preflight.get("label_intake_manifest_sha256s") != label_intake_manifest_sha256s:
        errors.append("runtime preflight label_intake_manifest_sha256s must match label_intake_fingerprints")
    if str(preflight.get("label_intake_bundle_sha256") or "") != sha256_json(label_intake_fingerprints):
        errors.append("runtime preflight label_intake_bundle_sha256 does not match label_intake_fingerprints")

    input_bundle = {
        "repo_intake_sha256": str(preflight.get("repo_intake_sha256") or ""),
        "repo_snapshot_lock_sha256": str(preflight.get("repo_snapshot_lock_sha256") or ""),
        "decisions_sha256": str(preflight.get("decisions_sha256") or ""),
        "feedback_sha256": str(preflight.get("feedback_sha256") or ""),
        "label_template_bundle_sha256": str(preflight.get("label_template_bundle_sha256") or ""),
        "label_intake_bundle_sha256": str(preflight.get("label_intake_bundle_sha256") or ""),
    }
    if str(preflight.get("preflight_input_bundle_sha256") or "") != sha256_json(input_bundle):
        errors.append("runtime preflight preflight_input_bundle_sha256 does not match input fingerprints")
    return errors


def validate_request_verify_existing_counts(preflight: dict, request: dict) -> list[str]:
    errors: list[str] = []
    for key in VERIFY_EXISTING_COUNTER_KEYS:
        preflight_value = int_field(preflight, key, errors, "runtime preflight")
        request_value = int_field(request, key, errors, "approval request")
        if request_value != preflight_value:
            errors.append(f"approval request {key} must match runtime preflight")
    return errors


def validate_request_sha_binding_fields(preflight: dict, request: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_SHA_BINDING_KEYS:
        preflight_value = str(preflight.get(key) or "")
        request_value = str(request.get(key) or "")
        if request_value != preflight_value:
            errors.append(f"approval request {key} must match runtime preflight")
    for key, _count_key in PREFLIGHT_LIST_BINDING_KEYS:
        if request.get(key) != preflight.get(key):
            errors.append(f"approval request {key} must match runtime preflight")
    return errors


def validate_request_path_guard_fields(preflight: dict, request: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_PATH_GUARD_KEYS:
        preflight_value = int_field(preflight, key, errors, "runtime preflight")
        request_value = int_field(request, key, errors, "approval request")
        if request_value != preflight_value:
            errors.append(f"approval request {key} must match runtime preflight")
        if request_value != 1:
            errors.append(f"approval request must preserve {key}=1")
    if int_field(request, "output_path_guard_passed", errors, "approval request") != 1:
        errors.append("approval request must set output_path_guard_passed=1")
    return errors


def validate_preflight(preflight: dict) -> list[str]:
    errors: list[str] = []
    if preflight.get("schema") != PREFLIGHT_SCHEMA:
        errors.append("runtime preflight has unexpected schema")
    if int(preflight.get("ready_to_request_runtime_approval", 0)) != 1:
        errors.append("runtime preflight must have ready_to_request_runtime_approval=1")
    if int(preflight.get("benchmark_runtime_approval_required", 0)) != 1:
        errors.append("runtime preflight must require benchmark runtime approval")
    if int(preflight.get("creates_benchmark_evidence", 1)) != 0:
        errors.append("runtime preflight must not create benchmark evidence")
    if preflight.get("errors", []):
        errors.append("runtime preflight must have no errors")
    for key, expected in BLOCKED_FLAGS.items():
        if int(preflight.get(key, 0)) != expected:
            errors.append(f"runtime preflight must keep {key}=0")
    commands = preflight.get("next_commands", [])
    if not isinstance(commands, list) or len(commands) < 2:
        errors.append("runtime preflight must contain benchmark preparation and run commands")
    errors.extend(validate_preflight_verify_existing_counts(preflight))
    errors.extend(validate_preflight_sha_binding_fields(preflight))
    errors.extend(validate_preflight_path_guard_fields(preflight))
    errors.extend(validate_fingerprint_bundle_consistency(preflight))
    return errors


def validate_request(
    *,
    preflight: dict,
    request: dict,
    preflight_path: Path,
    request_path: Path,
) -> tuple[list[str], list[str], str]:
    errors: list[str] = []
    if request.get("schema") != REQUEST_SCHEMA:
        errors.append("runtime approval request has unexpected schema")
    if int(request.get("approved_by_human", 1)) != 0:
        errors.append("approval request packet must not already approve the runtime")
    if int(request.get("approval_record_supplied", 1)) != 0:
        errors.append("approval request packet must not claim an approval record is supplied")
    if int(request.get("requires_human_runtime_approval", 0)) != 1:
        errors.append("approval request packet must require human runtime approval")
    if int(request.get("creates_benchmark_evidence", 1)) != 0:
        errors.append("approval request packet must not create benchmark evidence")
    if int(request.get("runs_benchmark", 1)) != 0:
        errors.append("approval request packet must not run the benchmark")
    for key, expected in BLOCKED_FLAGS.items():
        if int(request.get(key, 0)) != expected:
            errors.append(f"approval request packet must keep {key}=0")
    errors.extend(validate_request_verify_existing_counts(preflight, request))
    errors.extend(validate_request_sha_binding_fields(preflight, request))
    errors.extend(validate_request_path_guard_fields(preflight, request))

    request_preflight = str(request.get("input_preflight") or "")
    if not request_preflight or not same_path(request_preflight, str(preflight_path)):
        errors.append("approval request input_preflight must match the supplied preflight path")

    preflight_sha256 = sha256_file(preflight_path)
    request_preflight_sha256 = str(request.get("input_preflight_sha256") or "")
    if request_preflight_sha256 and request_preflight_sha256 != preflight_sha256:
        errors.append("approval request input_preflight_sha256 does not match the supplied preflight")

    preflight_commands = [str(command) for command in preflight.get("next_commands", [])]
    request_commands = request.get("runtime_commands", [])
    if request_commands != preflight_commands:
        errors.append("approval request runtime_commands must match preflight next_commands")
        request_commands = []
    if not isinstance(request_commands, list):
        errors.append("approval request runtime_commands must be a list")
        request_commands = []
    commands = [str(command) for command in request_commands]
    commands_sha256 = sha256_json(commands)
    if str(request.get("runtime_commands_sha256") or commands_sha256) != commands_sha256:
        errors.append("approval request runtime_commands_sha256 does not match runtime_commands")

    benchmark_out = command_option(commands[1], "--out") if len(commands) > 1 else ""
    if not benchmark_out:
        errors.append("approval request benchmark command must include --out")
    request_benchmark_out = str(request.get("benchmark_out") or benchmark_out)
    if benchmark_out and not same_path(request_benchmark_out, benchmark_out):
        errors.append("approval request benchmark_out must match benchmark command --out")

    benchmark_command = commands[1] if len(commands) > 1 else ""
    benchmark_parts = command_parts(benchmark_command)
    if "scripts/audit_my_repo_benchmark.py" not in benchmark_parts:
        errors.append("approval request second runtime command must run audit_my_repo_benchmark.py")
    if command_option(benchmark_command, "--namespace") != "real_benchmark":
        errors.append("approval request benchmark command must use --namespace real_benchmark")
    if "--confirm-real-benchmark-namespace" not in benchmark_parts:
        errors.append("approval request benchmark command must confirm real_benchmark namespace")
    if command_option(benchmark_command, "--mode") != "full":
        errors.append("approval request benchmark command must use --mode full")

    _ = request_path
    return errors, commands, benchmark_out


def validate_record(
    *,
    record: dict,
    preflight_sha256: str,
    request_sha256: str,
    commands_sha256: str,
    benchmark_out: str,
) -> list[str]:
    errors: list[str] = []
    if record.get("schema") != RECORD_SCHEMA:
        errors.append("runtime approval record has unexpected schema")
    if not truthy(record.get("approved_by_human")):
        errors.append("approval record must set approved_by_human=true")
    if not truthy(record.get("approval_record_supplied")):
        errors.append("approval record must set approval_record_supplied=true")
    if str(record.get("approval_scope") or "") != APPROVAL_SCOPE:
        errors.append(f"approval record approval_scope must be {APPROVAL_SCOPE}")
    if placeholder_approver(record.get("approver_id")):
        errors.append("approval record must include a non-placeholder human approver_id")
    if not str(record.get("approved_at_utc") or "").strip().endswith("Z"):
        errors.append("approval record must include approved_at_utc ending in Z")
    if positive_int(record.get("approved_runtime_budget_minutes")) == 0:
        errors.append("approval record must include a positive approved_runtime_budget_minutes")
    if str(record.get("approved_preflight_sha256") or "") != preflight_sha256:
        errors.append("approval record approved_preflight_sha256 does not match the preflight")
    if str(record.get("approved_request_sha256") or "") != request_sha256:
        errors.append("approval record approved_request_sha256 does not match the approval request")
    if str(record.get("approved_runtime_commands_sha256") or "") != commands_sha256:
        errors.append("approval record approved_runtime_commands_sha256 does not match the runtime commands")
    if benchmark_out and not same_path(str(record.get("approved_benchmark_out") or ""), benchmark_out):
        errors.append("approval record approved_benchmark_out does not match benchmark command --out")
    if not truthy(record.get("raw_repositories_labels_feedback_remain_local")):
        errors.append("approval record must confirm raw repositories, labels, and feedback remain local")
    if not truthy(record.get("no_external_publication_or_release_claim")):
        errors.append("approval record must confirm no external publication or release claim")
    if truthy(record.get("creates_benchmark_evidence")):
        errors.append("approval record must not claim that this validation creates benchmark evidence")
    if truthy(record.get("runs_benchmark")):
        errors.append("approval record must not claim that this validation runs the benchmark")
    for key in BLOCKED_FLAGS:
        if truthy(record.get(key)):
            errors.append(f"approval record must keep {key}=0")
    return errors


def build_status(
    *,
    preflight_path: Path,
    request_path: Path,
    record_path: Path,
    request: dict,
    record: dict,
    commands: list[str],
    benchmark_out: str,
) -> dict:
    commands_sha256 = sha256_json(commands)
    return {
        "schema": STATUS_SCHEMA,
        "input_preflight": str(preflight_path),
        "input_preflight_sha256": sha256_file(preflight_path),
        "approval_request": str(request_path),
        "approval_request_sha256": sha256_file(request_path),
        "approval_record": str(record_path),
        "approval_record_sha256": sha256_file(record_path),
        "approval_scope": APPROVAL_SCOPE,
        "approved_by_human": 1,
        "approval_record_supplied": 1,
        "human_runtime_approval_record_verified": 1,
        "ready_for_human_operator_benchmark_run": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "codex_runtime_permission_granted_by_this_packet": 0,
        "approver_id": str(record.get("approver_id") or ""),
        "approved_at_utc": str(record.get("approved_at_utc") or ""),
        "approved_runtime_budget_minutes": positive_int(record.get("approved_runtime_budget_minutes")),
        **{key: int(request.get(key, 0)) for key in PREFLIGHT_PATH_GUARD_KEYS},
        "approval_request_output_path_guard_passed": int(request.get("output_path_guard_passed", 0)),
        **{key: str(request.get(key) or "") for key in PREFLIGHT_SHA_BINDING_KEYS},
        **{
            key: list(request.get(key, []))
            for key, _count_key in PREFLIGHT_LIST_BINDING_KEYS
        },
        "runtime_commands": commands,
        "runtime_commands_sha256": commands_sha256,
        "benchmark_out": benchmark_out,
        **BLOCKED_FLAGS,
        "errors": [],
    }


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Runtime Approval Status",
        "",
        f"- human_runtime_approval_record_verified: {payload['human_runtime_approval_record_verified']}",
        f"- ready_for_human_operator_benchmark_run: {payload['ready_for_human_operator_benchmark_run']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_benchmark: {payload['runs_benchmark']}",
        f"- codex_runtime_permission_granted_by_this_packet: {payload['codex_runtime_permission_granted_by_this_packet']}",
        f"- input_path_preflight_passed: {payload['input_path_preflight_passed']}",
        f"- output_path_preflight_passed: {payload['output_path_preflight_passed']}",
        f"- approval_request_output_path_guard_passed: {payload['approval_request_output_path_guard_passed']}",
        f"- benchmark_out: {payload['benchmark_out']}",
        f"- preflight_input_bundle_sha256: {payload['preflight_input_bundle_sha256']}",
        f"- repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"- label_template_bundle_sha256: {payload['label_template_bundle_sha256']}",
        f"- label_intake_bundle_sha256: {payload['label_intake_bundle_sha256']}",
        f"- runtime_commands_sha256: {payload['runtime_commands_sha256']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Runtime Commands",
        "",
    ]
    lines.extend(f"{index}. `{command}`" for index, command in enumerate(payload["runtime_commands"], start=1))
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight", required=True, help="JSON output from amr_beta_runtime_preflight.py.")
    parser.add_argument("--request", required=True, help="JSON output from amr_beta_runtime_approval_request.py.")
    parser.add_argument("--approval-record", required=True, help="Human-supplied runtime approval record JSON.")
    parser.add_argument("--out-json", required=True, help="Validated approval status JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown status output.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        preflight_path = Path(args.preflight).expanduser().resolve()
        request_path = Path(args.request).expanduser().resolve()
        record_path = Path(args.approval_record).expanduser().resolve()
        preflight = read_json(preflight_path, "runtime preflight")
        request = read_json(request_path, "runtime approval request")
        record = read_json(record_path, "runtime approval record")

        errors = validate_preflight(preflight)
        request_errors, commands, benchmark_out = validate_request(
            preflight=preflight,
            request=request,
            preflight_path=preflight_path,
            request_path=request_path,
        )
        errors.extend(request_errors)
        if not errors:
            errors.extend(
                validate_record(
                    record=record,
                    preflight_sha256=sha256_file(preflight_path),
                    request_sha256=sha256_file(request_path),
                    commands_sha256=sha256_json(commands),
                    benchmark_out=benchmark_out,
                )
            )
        if errors:
            if args.json:
                print(json.dumps({"schema": STATUS_SCHEMA, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1

        status = build_status(
            preflight_path=preflight_path,
            request_path=request_path,
            record_path=record_path,
            request=request,
            record=record,
            commands=commands,
            benchmark_out=benchmark_out,
        )
        write_json(Path(args.out_json).expanduser().resolve(), status, args.overwrite)
        if args.out_md:
            write_markdown(Path(args.out_md).expanduser().resolve(), status, args.overwrite)
        if args.json:
            print(json.dumps(status, indent=2, sort_keys=True))
        else:
            print("runtime_approval_status: ok human_runtime_approval_record_verified=1")
        return 0
    except Exception as exc:
        print(f"runtime_approval_status: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": STATUS_SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
