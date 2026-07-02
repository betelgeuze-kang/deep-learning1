#!/usr/bin/env python3
"""Build an AMR beta runtime approval request from a green preflight.

This consumes an existing `amr_beta_runtime_preflight.py` JSON output and writes
an approval-request packet for the long real_benchmark step. It does not approve
the run, does not execute benchmark commands, does not create benchmark
evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import sys
from pathlib import Path

SCHEMA = "amr_beta_runtime_approval_request.v1"
PREFLIGHT_SCHEMA = "amr_beta_runtime_preflight.v1"
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
    "feedback_bundle_sha256",
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


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def validate_output_paths(paths: dict[str, Path], benchmark_out: str) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, str] = {}
    benchmark_out_text = str(benchmark_out or "").strip()
    benchmark_out_path = Path(benchmark_out_text).expanduser().resolve() if benchmark_out_text else None
    for name, path in paths.items():
        resolved = path.resolve()
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen:
            errors.append(f"{name} must not reuse {seen[resolved]} path: {resolved}")
        seen[resolved] = name
        if benchmark_out_path is not None and (resolved == benchmark_out_path or is_relative_to(resolved, benchmark_out_path)):
            errors.append(
                f"{name} must not be inside approved benchmark output: {resolved} "
                f"(benchmark_out: {benchmark_out_path})"
            )
    return errors


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


def command_option(command: str, option: str) -> str:
    try:
        parts = shlex.split(command)
    except ValueError:
        return ""
    for index, part in enumerate(parts):
        if part == option and index + 1 < len(parts):
            return parts[index + 1]
    return ""


def int_field(payload: dict, key: str, errors: list[str]) -> int:
    try:
        return int(payload.get(key, -1))
    except (TypeError, ValueError):
        errors.append(f"runtime preflight {key} must be an integer")
        return -1


def validate_verify_existing_counts(preflight: dict) -> list[str]:
    errors: list[str] = []
    for prefix, count_key in [
        ("label_template", "template_dir_count"),
        ("label_intake", "label_intake_dir_count"),
    ]:
        dir_count = int_field(preflight, count_key, errors)
        required = int_field(preflight, f"{prefix}_verify_existing_required", errors)
        passed = int_field(preflight, f"{prefix}_verify_existing_passed_dirs", errors)
        failed = int_field(preflight, f"{prefix}_verify_existing_failed_dirs", errors)
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


def validate_sha_binding_fields(preflight: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_SHA_BINDING_KEYS:
        value = str(preflight.get(key) or "")
        if not SHA256_RE.fullmatch(value):
            errors.append(f"runtime preflight {key} must be a sha256 digest")
    for key, count_key in PREFLIGHT_LIST_BINDING_KEYS:
        expected_count = int_field(preflight, count_key, errors)
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


def validate_path_guard_fields(preflight: dict) -> list[str]:
    errors: list[str] = []
    for key in PREFLIGHT_PATH_GUARD_KEYS:
        if int_field(preflight, key, errors) != 1:
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
        "feedback_bundle_sha256": str(preflight.get("feedback_bundle_sha256") or ""),
        "label_template_bundle_sha256": str(preflight.get("label_template_bundle_sha256") or ""),
        "label_intake_bundle_sha256": str(preflight.get("label_intake_bundle_sha256") or ""),
    }
    if str(preflight.get("preflight_input_bundle_sha256") or "") != sha256_json(input_bundle):
        errors.append("runtime preflight preflight_input_bundle_sha256 does not match input fingerprints")
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
    for key, expected in BLOCKED_FLAGS.items():
        if int(preflight.get(key, 0)) != expected:
            errors.append(f"runtime preflight must keep {key}=0")
    raw_errors = preflight.get("errors", [])
    if raw_errors:
        errors.append("runtime preflight must have no errors")
    commands = preflight.get("next_commands", [])
    if not isinstance(commands, list) or len(commands) < 2:
        errors.append("runtime preflight must contain benchmark preparation and run commands")
    else:
        prep = str(commands[0])
        run = str(commands[1])
        if "amr_beta_benchmark_input_prepare.py" not in prep:
            errors.append("first runtime command must prepare combined benchmark inputs")
        if "audit_my_repo_benchmark.py" not in run:
            errors.append("second runtime command must run audit_my_repo_benchmark.py")
        if "--namespace real_benchmark" not in run or "--confirm-real-benchmark-namespace" not in run:
            errors.append("benchmark command must be real_benchmark namespace confirmed")
    errors.extend(validate_verify_existing_counts(preflight))
    errors.extend(validate_sha_binding_fields(preflight))
    errors.extend(validate_path_guard_fields(preflight))
    errors.extend(validate_fingerprint_bundle_consistency(preflight))
    return errors


def build_packet(preflight: dict, *, preflight_path: Path, operator_note: str) -> dict:
    commands = [str(command) for command in preflight.get("next_commands", [])]
    benchmark_out = command_option(commands[1], "--out") if len(commands) > 1 else ""
    return {
        "schema": SCHEMA,
        "input_preflight": str(preflight_path),
        "input_preflight_sha256": sha256_file(preflight_path),
        "request_kind": "runtime_approval_required",
        "approved_by_human": 0,
        "approval_record_supplied": 0,
        "requires_human_runtime_approval": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "operator_note": operator_note,
        "preflight_ready_to_request_runtime_approval": int(
            preflight.get("ready_to_request_runtime_approval", 0)
        ),
        "valid_repo_rows": int(preflight.get("valid_repo_rows", 0)),
        "human_label_rows": int(preflight.get("human_label_rows", 0)),
        "distinct_countable_maintainer_id_count": int(
            preflight.get("distinct_countable_maintainer_id_count", 0)
        ),
        "label_intake_case_count": int(preflight.get("label_intake_case_count", 0)),
        **{key: int(preflight.get(key, 0)) for key in PREFLIGHT_PATH_GUARD_KEYS},
        **{key: int(preflight.get(key, 0)) for key in VERIFY_EXISTING_COUNTER_KEYS},
        **{key: str(preflight.get(key) or "") for key in PREFLIGHT_SHA_BINDING_KEYS},
        **{
            key: list(preflight.get(key, []))
            for key, _count_key in PREFLIGHT_LIST_BINDING_KEYS
        },
        "runtime_commands": commands,
        "runtime_commands_sha256": sha256_json(commands),
        "benchmark_out": benchmark_out,
        "approval_checklist": [
            "Human operator explicitly approves runtime budget and wall-clock expectation.",
            "Human operator confirms benchmark output directory is acceptable.",
            "Human operator records the preflight, request, and runtime command hashes in an approval record.",
            "Human operator confirms raw repositories, labels, and feedback remain local.",
            "Human operator runs the listed commands; Codex does not run the long benchmark without approval.",
            "After execution, operator verifies benchmark output with --verify-existing.",
        ],
        **BLOCKED_FLAGS,
    }


def write_markdown(path: Path, packet: dict) -> None:
    lines = [
        "# AMR Beta Runtime Approval Request",
        "",
        f"- approved_by_human: {packet['approved_by_human']}",
        f"- requires_human_runtime_approval: {packet['requires_human_runtime_approval']}",
        f"- creates_benchmark_evidence: {packet['creates_benchmark_evidence']}",
        f"- runs_benchmark: {packet['runs_benchmark']}",
        f"- input_path_preflight_passed: {packet['input_path_preflight_passed']}",
        f"- output_path_preflight_passed: {packet['output_path_preflight_passed']}",
        f"- output_path_guard_passed: {packet['output_path_guard_passed']}",
        f"- input_preflight_sha256: {packet['input_preflight_sha256']}",
        f"- preflight_input_bundle_sha256: {packet['preflight_input_bundle_sha256']}",
        f"- repo_snapshot_lock_sha256: {packet['repo_snapshot_lock_sha256']}",
        f"- label_template_bundle_sha256: {packet['label_template_bundle_sha256']}",
        f"- label_intake_bundle_sha256: {packet['label_intake_bundle_sha256']}",
        f"- runtime_commands_sha256: {packet['runtime_commands_sha256']}",
        f"- benchmark_out: {packet['benchmark_out']}",
        f"- label_template_verify_existing_required: {packet['label_template_verify_existing_required']}",
        f"- label_template_verify_existing_passed_dirs: {packet['label_template_verify_existing_passed_dirs']}",
        f"- label_template_verify_existing_failed_dirs: {packet['label_template_verify_existing_failed_dirs']}",
        f"- label_intake_verify_existing_required: {packet['label_intake_verify_existing_required']}",
        f"- label_intake_verify_existing_passed_dirs: {packet['label_intake_verify_existing_passed_dirs']}",
        f"- label_intake_verify_existing_failed_dirs: {packet['label_intake_verify_existing_failed_dirs']}",
        f"- design_partner_beta_candidate_ready: {packet['design_partner_beta_candidate_ready']}",
        f"- release_ready: {packet['release_ready']}",
        f"- public_comparison_claim_ready: {packet['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {packet['real_model_execution_ready']}",
        "",
        "## Runtime Commands",
        "",
    ]
    lines.extend(f"{index}. `{command}`" for index, command in enumerate(packet["runtime_commands"], start=1))
    lines.extend(["", "## Approval Checklist", ""])
    lines.extend(f"- {item}" for item in packet["approval_checklist"])
    if packet["operator_note"]:
        lines.extend(["", "## Operator Note", "", packet["operator_note"]])
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight", required=True, help="JSON output from amr_beta_runtime_preflight.py.")
    parser.add_argument("--out-json", required=True, help="Runtime approval request JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown request output.")
    parser.add_argument("--operator-note", default="", help="Optional non-secret note for the approval request.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        preflight_path = Path(args.preflight).expanduser().resolve()
        preflight = read_json(preflight_path, "runtime preflight")
        errors = validate_preflight(preflight)
        if errors:
            if args.json:
                print(json.dumps({"schema": SCHEMA, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        packet = build_packet(preflight, preflight_path=preflight_path, operator_note=args.operator_note)
        output_paths = {"out_json": Path(args.out_json).expanduser().resolve()}
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        output_errors = validate_output_paths(output_paths, str(packet.get("benchmark_out") or ""))
        packet["output_path_guard_passed"] = int(not output_errors)
        if output_errors:
            if args.json:
                print(json.dumps({**packet, "errors": output_errors}, indent=2, sort_keys=True))
            for error in output_errors:
                print(error, file=sys.stderr)
            return 1
        write_json(output_paths["out_json"], packet, args.overwrite)
        if args.out_md:
            out_md = output_paths["out_md"]
            out_md.parent.mkdir(parents=True, exist_ok=True)
            if out_md.exists() and not args.overwrite:
                raise ValueError(f"output already exists; use --overwrite: {out_md}")
            write_markdown(out_md, packet)
        if args.json:
            print(json.dumps({**packet, "errors": []}, indent=2, sort_keys=True))
        else:
            print("runtime_approval_request: ok approved_by_human=0")
        return 0
    except Exception as exc:
        print(f"runtime_approval_request: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
