#!/usr/bin/env python3
"""Build a read-only AMR beta repo audit/template command plan.

This consumes a validated 9.1 repository-intake sheet and writes the exact
operator commands for the next handoff: real_benchmark audits, label template
generation, and reviewer packet generation.

It does not run audits, does not generate label templates, does not create
benchmark evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import sys
from pathlib import Path

import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_repo_audit_plan.v1"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def validate_artifact_root(artifact_root: Path, rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    for row in rows:
        repo_path = Path(row["repo_path_resolved"]).resolve()
        if artifact_root.resolve() == repo_path or is_relative_to(artifact_root, repo_path):
            errors.append(
                f"artifact_root must not be inside target repo for case_id {row['case_id']}: {artifact_root}"
            )
    return errors


def normalized_valid_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    normalized_rows: list[dict[str, str]] = []
    errors: list[str] = []
    for index, row in enumerate(rows, start=1):
        row_errors, normalized = repo_intake.validate_row(row, index)
        if row_errors:
            errors.extend(row_errors)
            continue
        normalized_rows.append(normalized)
    if errors:
        raise ValueError("; ".join(errors))
    return normalized_rows


def build_plan_rows(rows: list[dict[str, str]], artifact_root: Path) -> tuple[list[dict], str]:
    plan_rows: list[dict] = []
    template_dirs: list[str] = []
    for row in rows:
        case_id = row["case_id"]
        repo_path = str(Path(row["repo_path_resolved"]).resolve())
        audit_mode = row["audit_mode"].lower()
        audit_out = artifact_root / f"{case_id}_audit"
        template_out = artifact_root / f"{case_id}_label_template"
        reviewer_out = artifact_root / f"{case_id}_reviewer_packet"
        audit_command = command_line(
            [
                "./scripts/audit_my_repo.sh",
                repo_path,
                "--mode",
                audit_mode,
                "--namespace",
                "real_benchmark",
                "--confirm-real-benchmark-namespace",
                "--out",
                audit_out,
            ]
        )
        audit_verify_command = command_line(
            [
                "./scripts/audit_my_repo.sh",
                "--verify-existing",
                audit_out,
            ]
        )
        template_command = command_line(
            [
                "python3",
                "scripts/audit_my_repo_label_template.py",
                "--audit-output",
                audit_out,
                "--out",
                template_out,
                "--case-id",
                case_id,
            ]
        )
        template_verify_command = command_line(
            [
                "python3",
                "scripts/audit_my_repo_label_template.py",
                "--verify-existing",
                template_out,
            ]
        )
        reviewer_packet_command = command_line(
            [
                "python3",
                "scripts/amr_beta_label_packet.py",
                "--template-dir",
                template_out,
                "--out",
                reviewer_out,
            ]
        )
        template_dirs.append(str(template_out))
        plan_rows.append(
            {
                "case_id": case_id,
                "repo_path": repo_path,
                "expected_repo_git_head": row["expected_repo_git_head"].lower(),
                "actual_repo_git_head": row.get("actual_repo_git_head", "").lower(),
                "owner_or_maintainer_contact_present": 1,
                "audit_mode": audit_mode,
                "namespace": "real_benchmark",
                "real_benchmark_namespace_confirmed": 1,
                "audit_out": str(audit_out),
                "label_template_out": str(template_out),
                "reviewer_packet_out": str(reviewer_out),
                "audit_command": audit_command,
                "audit_verify_command": audit_verify_command,
                "label_template_command": template_command,
                "label_template_verify_command": template_verify_command,
                "reviewer_packet_command": reviewer_packet_command,
            }
        )
    aggregate_parts: list[object] = ["python3", "scripts/amr_beta_label_packet.py"]
    for template_dir in template_dirs:
        aggregate_parts.extend(["--template-dir", template_dir])
    aggregate_parts.extend(["--per-case-out-root", artifact_root / "reviewer_packets"])
    return plan_rows, command_line(aggregate_parts)


def build_payload(*, intake_path: Path, rows: list[dict[str, str]], summary: dict, artifact_root: Path) -> dict:
    plan_rows, aggregate_command = build_plan_rows(rows, artifact_root)
    commands = []
    for row in plan_rows:
        commands.extend(
            [
                row["audit_command"],
                row["audit_verify_command"],
                row["label_template_command"],
                row["label_template_verify_command"],
                row["reviewer_packet_command"],
            ]
        )
    commands.append(aggregate_command)
    return {
        "schema": SCHEMA,
        "repo_intake": str(intake_path),
        "repo_intake_sha256": sha256_file(intake_path),
        "artifact_root": str(artifact_root),
        "total_rows": int(summary.get("total_rows", 0)),
        "valid_repo_rows": int(summary.get("valid_repo_rows", 0)),
        "min_real_repos_required": int(summary.get("min_real_repos_required", 0)),
        "repo_snapshot_lock_sha256": summary.get("repo_snapshot_lock_sha256", ""),
        "ready_for_real_benchmark_audit_plan": 1,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "input_path_guard_passed": 1,
        "output_path_guard_passed": 1,
        "operator_command_count": len(commands),
        "operator_commands_sha256": sha256_json(commands),
        "per_repo": plan_rows,
        "aggregate_reviewer_packet_command": aggregate_command,
        "operator_commands": commands,
        "next_manual_inputs": [
            "Human/operator runs the audit commands if runtime and local repo policy allow.",
            "Human/operator verifies each audit output before generating label templates.",
            "Human reviewers receive only candidate ids from generated reviewer packets.",
            "Human decisions and maintainer feedback are collected separately; Codex does not fabricate them.",
        ],
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
        "# AMR Beta Repo Audit Plan",
        "",
        f"- ready_for_real_benchmark_audit_plan: {payload['ready_for_real_benchmark_audit_plan']}",
        f"- valid_repo_rows: {payload['valid_repo_rows']}",
        f"- repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"- runs_audit: {payload['runs_audit']}",
        f"- runs_label_template_generation: {payload['runs_label_template_generation']}",
        f"- writes_reviewer_packets: {payload['writes_reviewer_packets']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- input_path_guard_passed: {payload['input_path_guard_passed']}",
        f"- output_path_guard_passed: {payload['output_path_guard_passed']}",
        f"- operator_commands_sha256: {payload['operator_commands_sha256']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Per-Repo Commands",
        "",
    ]
    for row in payload["per_repo"]:
        lines.extend(
            [
                f"### {row['case_id']}",
                "",
                f"1. `{row['audit_command']}`",
                f"2. `{row['audit_verify_command']}`",
                f"3. `{row['label_template_command']}`",
                f"4. `{row['label_template_verify_command']}`",
                f"5. `{row['reviewer_packet_command']}`",
                "",
            ]
        )
    lines.extend(
        [
            "## Aggregate Reviewer Packet Command",
            "",
            f"`{payload['aggregate_reviewer_packet_command']}`",
        ]
    )
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", required=True, help="Filled repo-intake Markdown or CSV.")
    parser.add_argument("--artifact-root", default="results/amr_beta_repo_audit_work")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--out-json", required=True, help="Repo audit plan JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown plan output.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        intake_path = Path(args.repo_intake).expanduser().resolve()
        artifact_root = Path(args.artifact_root).expanduser().resolve()
        if is_forbidden_env_path(intake_path):
            raise ValueError("refusing .env-like repo intake path")
        if is_forbidden_env_path(artifact_root):
            raise ValueError("refusing .env-like artifact root path")
        raw_rows = repo_intake.read_rows(intake_path)
        errors, summary = repo_intake.validate_rows(raw_rows, min_repos=args.min_repos)
        if errors:
            if args.json:
                print(json.dumps({"schema": SCHEMA, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        rows = normalized_valid_rows(raw_rows)
        target_repo_paths = sorted({row["repo_path_resolved"] for row in rows if row.get("repo_path_resolved")})
        output_paths = {"out_json": Path(args.out_json).expanduser().resolve()}
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        input_path_errors = repo_intake.validate_input_path(intake_path, target_repo_paths)
        output_path_errors = repo_intake.validate_output_paths(output_paths, target_repo_paths)
        artifact_root_errors = validate_artifact_root(artifact_root, rows)
        path_errors = [*input_path_errors, *output_path_errors]
        plan_errors = [*artifact_root_errors, *path_errors]
        if plan_errors:
            if args.json:
                print(json.dumps({"schema": SCHEMA, "errors": plan_errors}, indent=2, sort_keys=True))
            for error in plan_errors:
                print(error, file=sys.stderr)
            return 1
        payload = build_payload(
            intake_path=intake_path,
            rows=rows,
            summary=summary,
            artifact_root=artifact_root,
        )
        payload["input_path_guard_passed"] = int(not input_path_errors)
        payload["output_path_guard_passed"] = int(not output_path_errors)
        write_json(output_paths["out_json"], payload, args.overwrite)
        if args.out_md:
            write_markdown(output_paths["out_md"], payload, args.overwrite)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            print(f"repo_audit_plan: ok valid_repo_rows={payload['valid_repo_rows']}")
        return 0
    except Exception as exc:
        print(f"repo_audit_plan: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
