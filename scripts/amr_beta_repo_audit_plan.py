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
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def is_exact_int(value: object, expected: int | None = None) -> bool:
    if type(value) is not int:
        return False
    return expected is None or value == expected


def strict_json_equal(left: object, right: object) -> bool:
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        if left.keys() != right.keys():
            return False
        return all(strict_json_equal(left[key], right[key]) for key in left)
    if isinstance(left, list):
        if len(left) != len(right):
            return False
        return all(strict_json_equal(left_item, right_item) for left_item, right_item in zip(left, right))
    return left == right


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def is_resolved_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def validate_artifact_root(
    artifact_root: Path,
    rows: list[dict[str, str]],
    *,
    resolved_artifact_root: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    resolved = resolved_artifact_root or artifact_root.expanduser().resolve()
    for row in rows:
        repo_path = Path(row["repo_path_resolved"]).resolve()
        if resolved == repo_path or is_resolved_relative_to(resolved, repo_path):
            errors.append(
                f"artifact_root must not be inside target repo for case_id {row['case_id']}: {artifact_root}"
            )
    return errors


def output_exists_errors(paths: dict[str, Path], overwrite: bool) -> list[str]:
    if overwrite:
        return []
    errors: list[str] = []
    for name, path in paths.items():
        if path.exists():
            errors.append(f"{name} already exists; use --overwrite: {path}")
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
    snapshot_lock_rows = summary.get("repo_snapshot_lock_rows", [])
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
        "repo_snapshot_lock_row_count": len(snapshot_lock_rows),
        "repo_snapshot_lock_rows": snapshot_lock_rows,
        "repo_intake_local_fingerprint_sha256": summary.get(
            "repo_intake_local_fingerprint_sha256", ""
        ),
        "repo_intake_local_fingerprint_rows": summary.get(
            "repo_intake_local_fingerprint_rows", []
        ),
        "ready_for_real_benchmark_audit_plan": 1,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "input_path_guard_passed": 1,
        "output_path_guard_passed": 1,
        "operator_command_count": len(commands),
        "operator_commands_sha256": sha256_json(commands),
        "writes_operator_command_script": 0,
        "operator_commands_script": "",
        "operator_commands_script_sha256": "",
        "operator_commands_script_command_count": 0,
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
        f"- repo_intake_local_fingerprint_sha256: {payload['repo_intake_local_fingerprint_sha256']}",
        f"- runs_audit: {payload['runs_audit']}",
        f"- runs_label_template_generation: {payload['runs_label_template_generation']}",
        f"- writes_reviewer_packets: {payload['writes_reviewer_packets']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- input_path_guard_passed: {payload['input_path_guard_passed']}",
        f"- output_path_guard_passed: {payload['output_path_guard_passed']}",
        f"- operator_commands_sha256: {payload['operator_commands_sha256']}",
        f"- writes_operator_command_script: {payload['writes_operator_command_script']}",
        f"- operator_commands_script: {payload['operator_commands_script']}",
        f"- operator_commands_script_sha256: {payload['operator_commands_script_sha256']}",
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


def command_script_text(payload: dict) -> str:
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "# Generated by scripts/amr_beta_repo_audit_plan.py.",
        "# This script runs the operator commands from a validated repo audit plan.",
        "# It does not prove beta readiness by itself; verify outputs before use.",
        f"# repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"# repo_intake_local_fingerprint_sha256: {payload['repo_intake_local_fingerprint_sha256']}",
        f"# operator_commands_sha256: {payload['operator_commands_sha256']}",
        f"# operator_command_count: {payload['operator_command_count']}",
        "",
    ]
    for index, command in enumerate(payload["operator_commands"], start=1):
        lines.extend([f"# command {index}", command, ""])
    return "\n".join(lines).rstrip() + "\n"


def write_command_script(path: Path, payload: dict, overwrite: bool) -> str:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like command script output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(command_script_text(payload), encoding="utf-8")
    path.chmod(0o755)
    return sha256_file(path)


def apply_saved_command_script_metadata(
    *,
    payload: dict,
    saved_plan: dict,
    target_repo_paths: list[str],
) -> list[str]:
    errors: list[str] = []
    writes_script = saved_plan.get("writes_operator_command_script", 0)
    if not is_exact_int(writes_script) or writes_script not in {0, 1}:
        errors.append("plan: writes_operator_command_script must be an integer 0 or 1")
        return errors
    if writes_script == 0:
        return errors
    raw_script = str(saved_plan.get("operator_commands_script") or "").strip()
    if not raw_script:
        errors.append("plan: operator_commands_script is required when writes_operator_command_script=1")
        return errors
    raw_script_path = Path(raw_script).expanduser()
    if is_forbidden_env_path(raw_script_path):
        errors.append("plan: operator_commands_script must not be .env-like")
        return errors
    script_path = raw_script_path.resolve()
    script_path_errors = repo_intake.validate_output_paths(
        {"operator_commands_script": raw_script_path},
        target_repo_paths,
        resolved_paths={"operator_commands_script": script_path},
    )
    errors.extend(f"plan: {error}" for error in script_path_errors)
    payload["writes_operator_command_script"] = 1
    payload["operator_commands_script"] = str(script_path)
    payload["operator_commands_script_sha256"] = sha256_text(command_script_text(payload))
    payload["operator_commands_script_command_count"] = payload["operator_command_count"]
    if script_path_errors:
        return errors
    if not script_path.is_file():
        errors.append(f"plan: operator_commands_script must exist: {script_path}")
        return errors
    actual_sha = sha256_file(script_path)
    if actual_sha != payload["operator_commands_script_sha256"]:
        errors.append("plan: operator_commands_script_sha256 must match expected command script")
    return errors


def recompute_plan_payload(plan_path: Path, saved_plan: dict) -> tuple[dict, list[str]]:
    errors: list[str] = []
    raw_intake = str(saved_plan.get("repo_intake") or "").strip()
    if not raw_intake:
        return {}, ["plan: repo_intake must be present"]
    raw_artifact_root = str(saved_plan.get("artifact_root") or "").strip()
    if not raw_artifact_root:
        return {}, ["plan: artifact_root must be present"]
    raw_intake_path = Path(raw_intake).expanduser()
    raw_artifact_root_path = Path(raw_artifact_root).expanduser()
    if is_forbidden_env_path(raw_intake_path):
        return {}, ["plan: refusing .env-like repo intake path"]
    if is_forbidden_env_path(raw_artifact_root_path):
        return {}, ["plan: refusing .env-like artifact root path"]
    intake_path = raw_intake_path.resolve()
    artifact_root = raw_artifact_root_path.resolve()
    if is_forbidden_env_path(intake_path):
        return {}, ["plan: refusing .env-like repo intake path"]
    if is_forbidden_env_path(artifact_root):
        return {}, ["plan: refusing .env-like artifact root path"]
    min_repos = saved_plan.get("min_real_repos_required", repo_intake.MIN_REAL_REPOS_FOR_BETA)
    if not is_exact_int(min_repos):
        errors.append("plan: min_real_repos_required must be an integer")
        min_repos = repo_intake.MIN_REAL_REPOS_FOR_BETA
    elif min_repos < repo_intake.MIN_REAL_REPOS_FOR_BETA:
        errors.append(f"plan: min_real_repos_required must be at least {repo_intake.MIN_REAL_REPOS_FOR_BETA}")
        min_repos = repo_intake.MIN_REAL_REPOS_FOR_BETA
    try:
        raw_rows = repo_intake.read_rows(intake_path)
        row_errors, summary = repo_intake.validate_rows(raw_rows, min_repos=min_repos)
        if row_errors:
            return {}, [*errors, *row_errors]
        rows = normalized_valid_rows(raw_rows)
        target_repo_paths = sorted({row["repo_path_resolved"] for row in rows if row.get("repo_path_resolved")})
        input_path_errors = repo_intake.validate_input_path(
            raw_intake_path,
            target_repo_paths,
            resolved_path=intake_path,
        )
        output_path_errors = repo_intake.validate_output_paths(
            {"verify_existing_plan": plan_path},
            target_repo_paths,
            resolved_paths={"verify_existing_plan": plan_path},
        )
        artifact_root_errors = validate_artifact_root(
            raw_artifact_root_path,
            rows,
            resolved_artifact_root=artifact_root,
        )
        path_errors = [*input_path_errors, *output_path_errors, *artifact_root_errors]
        payload = build_payload(
            intake_path=intake_path,
            rows=rows,
            summary=summary,
            artifact_root=artifact_root,
        )
        payload["input_path_guard_passed"] = int(not input_path_errors)
        payload["output_path_guard_passed"] = int(not output_path_errors)
        payload["errors"] = path_errors
        script_errors = apply_saved_command_script_metadata(
            payload=payload,
            saved_plan=saved_plan,
            target_repo_paths=target_repo_paths,
        )
        return payload, [*errors, *path_errors, *script_errors]
    except Exception as exc:
        return {}, [*errors, f"plan: recompute error: {exc}"]


def verify_existing_plan(path: Path) -> tuple[dict, list[str]]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        return {}, ["plan: refusing .env-like plan path"]
    if not path.is_file():
        return {}, [f"plan: missing plan JSON: {path}"]
    try:
        saved_plan = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        return {}, [f"plan: parse error: {exc}"]
    if not isinstance(saved_plan, dict):
        return {}, ["plan: plan JSON must be an object"]
    if saved_plan.get("schema") != SCHEMA:
        errors.append(f"plan: schema must be {SCHEMA}")
    for key in [
        "runs_audit",
        "runs_label_template_generation",
        "writes_reviewer_packets",
        "creates_benchmark_evidence",
    ]:
        if not is_exact_int(saved_plan.get(key), 0):
            errors.append(f"plan: must keep {key}=0")
    for key, expected in BLOCKED_FLAGS.items():
        if not is_exact_int(saved_plan.get(key), expected):
            errors.append(f"plan: must keep {key}={expected}")
    if not is_exact_int(saved_plan.get("ready_for_real_benchmark_audit_plan"), 1):
        errors.append("plan: ready_for_real_benchmark_audit_plan must be integer 1")
    recomputed, recompute_errors = recompute_plan_payload(path, saved_plan)
    errors.extend(recompute_errors)
    if not recomputed:
        return saved_plan, errors
    if set(saved_plan.keys()) != set(recomputed.keys()):
        errors.append("plan: key set must match current repo intake and command plan")
    for key in sorted(set(saved_plan) | set(recomputed)):
        if not strict_json_equal(saved_plan.get(key), recomputed.get(key)):
            errors.append(f"plan: {key} must match current repo intake and command plan")
    return saved_plan, errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", default="", help="Filled repo-intake Markdown or CSV.")
    parser.add_argument("--artifact-root", default="results/amr_beta_repo_audit_work")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--out-json", default="", help="Repo audit plan JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown plan output.")
    parser.add_argument("--out-commands-sh", default="", help="Optional shell handoff script for operator commands.")
    parser.add_argument("--verify-existing", default="", help="Verify an existing repo audit plan JSON.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.verify_existing:
            raw_plan_path = Path(args.verify_existing).expanduser()
            if is_forbidden_env_path(raw_plan_path):
                plan_path = raw_plan_path.absolute()
                plan, verify_errors = {}, ["plan: refusing .env-like plan path"]
            else:
                plan_path = raw_plan_path.resolve()
                plan, verify_errors = verify_existing_plan(plan_path)
            plan_sha256 = ""
            plan_payload_sha256 = ""
            if plan and not is_forbidden_env_path(plan_path):
                plan_sha256 = sha256_file(plan_path)
                plan_payload_sha256 = sha256_json(plan)
            payload = {
                "schema": "amr_beta_repo_audit_plan_verify_existing.v1",
                "verify_existing": str(plan_path),
                "verify_existing_passed": int(not verify_errors),
                "plan_sha256": plan_sha256,
                "plan_payload_sha256": plan_payload_sha256,
                "runs_audit": 0,
                "runs_label_template_generation": 0,
                "writes_reviewer_packets": 0,
                "creates_benchmark_evidence": 0,
                "design_partner_beta_candidate_ready": 0,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
                "errors": verify_errors,
            }
            if args.json:
                print(json.dumps(payload, indent=2, sort_keys=True))
            if verify_errors:
                for error in verify_errors:
                    print(error, file=sys.stderr)
                return 1
            if not args.json:
                print("repo_audit_plan_verify: ok")
            return 0
        if not args.repo_intake:
            raise ValueError("--repo-intake is required unless --verify-existing is used")
        if not args.out_json:
            raise ValueError("--out-json is required unless --verify-existing is used")
        raw_intake_path = Path(args.repo_intake).expanduser()
        raw_artifact_root = Path(args.artifact_root).expanduser()
        if is_forbidden_env_path(raw_intake_path):
            raise ValueError("refusing .env-like repo intake path")
        if is_forbidden_env_path(raw_artifact_root):
            raise ValueError("refusing .env-like artifact root path")
        intake_path = raw_intake_path.resolve()
        artifact_root = raw_artifact_root.resolve()
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
        raw_output_paths = {"out_json": Path(args.out_json).expanduser()}
        if args.out_md:
            raw_output_paths["out_md"] = Path(args.out_md).expanduser()
        if args.out_commands_sh:
            raw_output_paths["out_commands_sh"] = Path(args.out_commands_sh).expanduser()
        input_path_errors = repo_intake.validate_input_path(
            raw_intake_path,
            target_repo_paths,
            resolved_path=intake_path,
        )
        output_paths = repo_intake.resolve_path_map(raw_output_paths)
        output_path_errors = repo_intake.validate_output_paths(
            raw_output_paths,
            target_repo_paths,
            resolved_paths=output_paths,
        )
        artifact_root_errors = validate_artifact_root(
            raw_artifact_root,
            rows,
            resolved_artifact_root=artifact_root,
        )
        existing_output_errors = [] if output_path_errors else output_exists_errors(output_paths, args.overwrite)
        path_errors = [*input_path_errors, *output_path_errors, *existing_output_errors]
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
        if args.out_commands_sh:
            script_path = output_paths["out_commands_sh"]
            script_sha = write_command_script(script_path, payload, args.overwrite)
            payload["writes_operator_command_script"] = 1
            payload["operator_commands_script"] = str(script_path)
            payload["operator_commands_script_sha256"] = script_sha
            payload["operator_commands_script_command_count"] = payload["operator_command_count"]
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
