#!/usr/bin/env python3
"""Build an AMR beta runtime approval request from a green preflight.

This consumes an existing `amr_beta_runtime_preflight.py` JSON output and writes
an approval-request packet for the long real_benchmark step. It does not approve
the run, does not execute benchmark commands, does not create benchmark
evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import json
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
    return errors


def build_packet(preflight: dict, *, preflight_path: Path, operator_note: str) -> dict:
    commands = [str(command) for command in preflight.get("next_commands", [])]
    return {
        "schema": SCHEMA,
        "input_preflight": str(preflight_path),
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
        "runtime_commands": commands,
        "approval_checklist": [
            "Human operator explicitly approves runtime budget and wall-clock expectation.",
            "Human operator confirms benchmark output directory is acceptable.",
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
        write_json(Path(args.out_json).expanduser().resolve(), packet, args.overwrite)
        if args.out_md:
            out_md = Path(args.out_md).expanduser().resolve()
            if is_forbidden_env_path(out_md):
                raise ValueError("refusing .env-like output path")
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
