#!/usr/bin/env python3
"""Build a read-only AMR beta label-intake command plan.

This consumes verified repo intake, label template directories, and human
decision rows, then writes the exact operator commands for compiling and
verifying per-repo label-intake outputs.

It does not compile labels, does not create benchmark evidence, does not run
real_benchmark, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import sys
from pathlib import Path

import amr_beta_label_packet as label_packet
import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_label_intake_plan.v1"
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
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


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def read_json(path: Path, input_name: str) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def validate_output_paths(paths: dict[str, Path], target_repo_paths: list[str]) -> list[str]:
    errors: list[str] = []
    resolved_by_name = {name: path.expanduser().resolve() for name, path in paths.items()}
    seen_paths: dict[Path, str] = {}
    for name, resolved in resolved_by_name.items():
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen_paths:
            errors.append(f"{name} must not reuse {seen_paths[resolved]} path: {resolved}")
        else:
            seen_paths[resolved] = name
        for raw_repo in target_repo_paths:
            repo_path = Path(raw_repo).expanduser().resolve()
            if resolved == repo_path or is_relative_to(resolved, repo_path):
                errors.append(f"{name} must not be inside target repo: {resolved} (repo: {repo_path})")
    return errors


def output_exists_errors(paths: dict[str, Path], *, overwrite: bool) -> list[str]:
    if overwrite:
        return []
    errors: list[str] = []
    for name, path in paths.items():
        if path.exists():
            errors.append(f"{name} already exists; use --overwrite: {path}")
    return errors


def validate_input_paths(paths: dict[str, Path], target_repo_paths: list[str]) -> list[str]:
    return validate_output_paths(paths, target_repo_paths)


def load_repo_context(path: Path, *, min_repos: int) -> tuple[dict[str, dict[str, str]], dict]:
    raw_rows = repo_intake.read_rows(path)
    errors, summary = repo_intake.validate_rows(raw_rows, min_repos=min_repos)
    if errors:
        raise ValueError("; ".join(errors))
    by_case: dict[str, dict[str, str]] = {}
    for index, row in enumerate(raw_rows, start=1):
        row_errors, normalized = repo_intake.validate_row(row, index)
        if row_errors:
            raise ValueError("; ".join(row_errors))
        case_id = normalized["case_id"]
        by_case[case_id] = {
            "repo_path": str(Path(normalized["repo_path_resolved"]).resolve()),
            "expected_repo_git_head": normalized["expected_repo_git_head"].lower(),
        }
    return by_case, summary


def load_templates(
    raw_dirs: list[str],
    *,
    verify_existing: bool,
) -> tuple[list[dict], list[str], dict[str, Path], dict[str, int], list[dict[str, str]]]:
    rows: list[dict] = []
    errors: list[str] = []
    by_case: dict[str, Path] = {}
    fingerprints: list[dict[str, str]] = []
    case_seen: set[str] = set()
    verify_passed_dirs = 0
    verify_failed_dirs = 0
    for raw_dir in raw_dirs:
        template_dir = Path(raw_dir).expanduser().resolve()
        if verify_existing:
            verify_errors = label_packet.verify_label_template_existing(template_dir)
            if verify_errors:
                verify_failed_dirs += 1
                errors.extend(verify_errors)
            else:
                verify_passed_dirs += 1
        loaded_rows, template_errors, _counts = label_packet.load_template_dir(template_dir)
        template_json = template_dir / "label_template.json"
        template_manifest = template_dir / "label_template_manifest.json"
        fingerprints.append(
            {
                "template_dir": str(template_dir),
                "label_template_json_sha256": sha256_file(template_json),
                "label_template_manifest_sha256": sha256_file(template_manifest)
                if template_manifest.is_file()
                else "",
            }
        )
        rows.extend(loaded_rows)
        errors.extend(template_errors)
        case_ids = sorted({row["case_id"] for row in loaded_rows})
        if len(case_ids) != 1:
            errors.append(f"{template_dir}: template dir must contain exactly one case_id")
            continue
        case_id = case_ids[0]
        if case_id in case_seen:
            errors.append(f"duplicate template case_id: {case_id}")
        case_seen.add(case_id)
        by_case[case_id] = template_dir
    candidate_ids = [row["candidate_label_id"] for row in rows]
    duplicate_ids = sorted({value for value in candidate_ids if candidate_ids.count(value) > 1})
    if duplicate_ids:
        errors.append(f"duplicate template candidate_label_id values: {', '.join(duplicate_ids[:10])}")
    return rows, errors, by_case, {
        "label_template_verify_existing_passed_dirs": verify_passed_dirs,
        "label_template_verify_existing_failed_dirs": verify_failed_dirs,
    }, fingerprints


def decision_map(decisions: list[dict]) -> dict[str, dict]:
    mapped: dict[str, dict] = {}
    for row in decisions:
        candidate_id = str(row.get("candidate_label_id") or "").strip()
        if candidate_id:
            mapped[candidate_id] = row
    return mapped


def validate_compile_boundaries(template_rows: list[dict], decisions_by_id: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    for row in template_rows:
        candidate_id = row["candidate_label_id"]
        decision = decisions_by_id.get(candidate_id)
        if not decision:
            continue
        if str(row.get("synthetic", "0")) != "0":
            errors.append(f"{candidate_id}: template row must be non-synthetic for beta label intake")
        expected = str(decision.get("expected") or decision.get("human_expected") or "").strip().lower()
        if expected == "present":
            if not str(row.get("expected_line_start") or "").strip():
                errors.append(f"{candidate_id}: present decision requires expected_line_start")
            if not str(row.get("expected_line_end") or "").strip():
                errors.append(f"{candidate_id}: present decision requires expected_line_end")
            if not SHA256_RE.fullmatch(str(row.get("expected_span_sha256") or "")):
                errors.append(f"{candidate_id}: present decision requires expected_span_sha256")
    return errors


def validate_label_packet_summary_binding(
    summary: dict,
    *,
    template_fingerprints: list[dict[str, str]],
    decisions_fingerprints: list[dict[str, str]],
    candidate_label_rows: int,
    synthetic_candidate_rows: int,
    non_synthetic_candidate_rows: int,
    decision_rows: int,
    valid_human_label_rows: int,
    non_synthetic_valid_human_label_rows: int,
    missing_candidate_label_count: int,
) -> list[str]:
    errors: list[str] = []
    if summary.get("schema") != "amr_beta_label_packet.v1":
        errors.append("label_packet_summary: schema must be amr_beta_label_packet.v1")
    for key in [
        "candidate_guard_passed",
        "decision_input_guard_passed",
        "output_path_guard_passed",
        "ready_for_label_intake",
    ]:
        if summary.get(key) != 1:
            errors.append(f"label_packet_summary: must set {key}=1")
    expected_counts = {
        "candidate_label_rows": candidate_label_rows,
        "synthetic_candidate_rows": synthetic_candidate_rows,
        "non_synthetic_candidate_rows": non_synthetic_candidate_rows,
        "decision_rows": decision_rows,
        "valid_human_label_rows": valid_human_label_rows,
        "non_synthetic_valid_human_label_rows": non_synthetic_valid_human_label_rows,
        "missing_candidate_label_count": missing_candidate_label_count,
    }
    for key, expected in expected_counts.items():
        if summary.get(key) != expected:
            errors.append(f"label_packet_summary: {key} must match label_intake_plan inputs")

    template_bundle_sha256 = sha256_json(template_fingerprints)
    decisions_bundle_sha256 = sha256_json(decisions_fingerprints)
    if summary.get("label_template_fingerprints") != template_fingerprints:
        errors.append("label_packet_summary: label_template_fingerprints must match label_intake_plan")
    if summary.get("label_template_bundle_sha256") != template_bundle_sha256:
        errors.append("label_packet_summary: label_template_bundle_sha256 must match label_intake_plan")
    if summary.get("decisions_fingerprints") != decisions_fingerprints:
        errors.append("label_packet_summary: decisions_fingerprints must match label_intake_plan")
    if summary.get("decisions_bundle_sha256") != decisions_bundle_sha256:
        errors.append("label_packet_summary: decisions_bundle_sha256 must match label_intake_plan")
    return errors


def build_case_rows(
    *,
    template_by_case: dict[str, Path],
    repo_by_case: dict[str, dict[str, str]],
    decisions_path: Path,
    out_root: Path,
) -> list[dict]:
    rows: list[dict] = []
    for case_id in sorted(template_by_case):
        template_dir = template_by_case[case_id]
        repo_context = repo_by_case[case_id]
        out_dir = out_root / f"{case_id}_label_intake"
        compile_command = command_line(
            [
                "python3",
                "scripts/audit_my_repo_label_intake.py",
                "--template",
                template_dir,
                "--decisions",
                decisions_path,
                "--repo-path",
                repo_context["repo_path"],
                "--expected-repo-git-head",
                repo_context["expected_repo_git_head"],
                "--out",
                out_dir,
            ]
        )
        verify_command = command_line(
            [
                "python3",
                "scripts/audit_my_repo_label_intake.py",
                "--verify-existing",
                out_dir,
            ]
        )
        rows.append(
            {
                "case_id": case_id,
                "template_dir": str(template_dir),
                "repo_path": repo_context["repo_path"],
                "expected_repo_git_head": repo_context["expected_repo_git_head"],
                "label_intake_out": str(out_dir),
                "compile_command": compile_command,
                "verify_command": verify_command,
            }
        )
    return rows


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
        "# AMR Beta Label Intake Plan",
        "",
        f"- ready_for_label_intake_plan: {payload['ready_for_label_intake_plan']}",
        f"- valid_human_label_rows: {payload['valid_human_label_rows']}",
        f"- non_synthetic_valid_human_label_rows: {payload['non_synthetic_valid_human_label_rows']}",
        f"- synthetic_candidate_rows: {payload['synthetic_candidate_rows']}",
        f"- human_labels_remaining_to_minimum: {payload['human_labels_remaining_to_minimum']}",
        f"- min_human_label_rows_required: {payload['min_human_label_rows_required']}",
        f"- repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"- label_template_bundle_sha256: {payload['label_template_bundle_sha256']}",
        f"- label_packet_summary_bound: {payload['label_packet_summary_bound']}",
        f"- label_packet_summary_sha256: {payload['label_packet_summary_sha256']}",
        f"- label_packet_decisions_bundle_sha256: {payload['label_packet_decisions_bundle_sha256']}",
        f"- label_template_verify_existing_required: {payload['label_template_verify_existing_required']}",
        f"- label_template_verify_existing_passed_dirs: {payload['label_template_verify_existing_passed_dirs']}",
        f"- label_template_verify_existing_failed_dirs: {payload['label_template_verify_existing_failed_dirs']}",
        f"- decision_input_guard_passed: {payload['decision_input_guard_passed']}",
        f"- output_path_guard_passed: {payload['output_path_guard_passed']}",
        f"- compiles_labels: {payload['compiles_labels']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_real_benchmark: {payload['runs_real_benchmark']}",
        f"- operator_commands_sha256: {payload['operator_commands_sha256']}",
        f"- writes_operator_command_script: {payload['writes_operator_command_script']}",
        f"- operator_commands_script: {payload['operator_commands_script']}",
        f"- operator_commands_script_sha256: {payload['operator_commands_script_sha256']}",
        f"- operator_commands_script_command_count: {payload['operator_commands_script_command_count']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Per-Case Commands",
        "",
    ]
    for row in payload["per_case"]:
        lines.extend(
            [
                f"### {row['case_id']}",
                "",
                f"1. `{row['compile_command']}`",
                f"2. `{row['verify_command']}`",
                "",
            ]
        )
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def command_script_text(payload: dict) -> str:
    commands = payload["operator_commands"]
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "# Generated by scripts/amr_beta_label_intake_plan.py.",
        "# This script runs the operator commands from a validated label-intake plan.",
        "# It does not prove beta readiness by itself; verify outputs before use.",
        f"# repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"# label_template_bundle_sha256: {payload['label_template_bundle_sha256']}",
        f"# decisions_sha256: {payload['decisions_sha256']}",
        f"# operator_commands_sha256: {payload['operator_commands_sha256']}",
        f"# operator_command_count: {len(commands)}",
        "",
    ]
    for index, command in enumerate(commands, start=1):
        lines.extend([f"# command {index}", command, ""])
    return "\n".join(lines).rstrip() + "\n"


def write_command_script(path: Path, payload: dict, overwrite: bool) -> str:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like operator command script output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"operator command script already exists; use --overwrite: {path}")
    text = command_script_text(payload)
    path.write_text(text, encoding="utf-8")
    path.chmod(0o755)
    return sha256_text(text)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", required=True, help="Filled repo-intake Markdown or CSV.")
    parser.add_argument("--template-dir", action="append", required=True, help="Label template dir; repeatable.")
    parser.add_argument("--decisions", required=True, help="Human decision JSON/JSONL file.")
    parser.add_argument(
        "--label-packet-summary",
        default="",
        help="Required reviewer_progress_summary.json to bind this plan to reviewed candidate coverage.",
    )
    parser.add_argument("--out-root", default="results/amr_beta_label_intake_work")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--min-labels", type=int, default=label_packet.MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument("--out-json", required=True, help="Label-intake plan JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown plan output.")
    parser.add_argument(
        "--out-commands-sh",
        default="",
        help="Optional executable shell script containing the validated operator commands.",
    )
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument(
        "--skip-verify-existing",
        action="store_true",
        help="Testing only: skip audit_my_repo_label_template.py --verify-existing checks.",
    )
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        repo_intake_path = Path(args.repo_intake).expanduser().resolve()
        decisions_path = Path(args.decisions).expanduser().resolve()
        label_packet_summary_path = (
            Path(args.label_packet_summary).expanduser().resolve()
            if args.label_packet_summary
            else None
        )
        out_root = Path(args.out_root).expanduser().resolve()
        path_checks: list[tuple[Path, str]] = [
            (repo_intake_path, "repo intake"),
            (decisions_path, "decisions"),
            (out_root, "output root"),
        ]
        if label_packet_summary_path:
            path_checks.append((label_packet_summary_path, "label packet summary"))
        for path, label in path_checks:
            if is_forbidden_env_path(path):
                raise ValueError(f"refusing .env-like {label} path")
        if not decisions_path.is_file():
            raise ValueError(f"--decisions is not a file: {decisions_path}")
        if label_packet_summary_path and not label_packet_summary_path.is_file():
            raise ValueError(f"--label-packet-summary is not a file: {label_packet_summary_path}")

        repo_by_case, repo_summary = load_repo_context(repo_intake_path, min_repos=args.min_repos)
        target_repo_paths = sorted({context["repo_path"] for context in repo_by_case.values()})
        input_paths = {"decisions": decisions_path}
        if label_packet_summary_path:
            input_paths["label_packet_summary"] = label_packet_summary_path
        input_path_errors = validate_input_paths(input_paths, target_repo_paths)
        output_paths = {
            "out_root": out_root,
            "out_json": Path(args.out_json).expanduser().resolve(),
        }
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        if args.out_commands_sh:
            output_paths["out_commands_sh"] = Path(args.out_commands_sh).expanduser().resolve()
        output_path_errors = validate_output_paths(
            output_paths,
            target_repo_paths,
        )
        write_file_paths = {
            name: path
            for name, path in output_paths.items()
            if name in {"out_json", "out_md", "out_commands_sh"}
        }
        output_path_errors.extend(output_exists_errors(write_file_paths, overwrite=args.overwrite))
        template_rows, template_errors, template_by_case, verify_counts, template_fingerprints = load_templates(
            args.template_dir,
            verify_existing=not args.skip_verify_existing,
        )
        template_case_ids = set(template_by_case)
        repo_case_ids = set(repo_by_case)
        errors = [*template_errors, *input_path_errors, *output_path_errors]
        if not label_packet_summary_path:
            errors.append("--label-packet-summary is required")
        missing_repo_cases = sorted(template_case_ids - repo_case_ids)
        if missing_repo_cases:
            errors.append("template case_id values missing from repo intake: " + ", ".join(missing_repo_cases[:20]))
        missing_template_cases = sorted(repo_case_ids - template_case_ids)
        if missing_template_cases:
            errors.append("repo intake case_id values missing from templates: " + ", ".join(missing_template_cases[:20]))

        decisions = [] if input_path_errors else label_packet.read_json_or_jsonl(decisions_path, "decisions")
        decisions_fingerprints = (
            [
                {
                    "decisions": str(decisions_path),
                    "decisions_sha256": sha256_file(decisions_path),
                }
            ]
            if not input_path_errors
            else []
        )
        known_candidate_ids = {row["candidate_label_id"] for row in template_rows}
        (
            decision_errors,
            valid_decision_ids,
            valid_human_label_rows,
            _valid_decision_rows,
        ) = label_packet.validate_decisions(decisions, known_candidate_ids)
        non_synthetic_candidate_ids = {
            row["candidate_label_id"]
            for row in template_rows
            if str(row.get("synthetic", "0")) != "1"
        }
        synthetic_candidate_rows = sum(
            1 for row in template_rows if str(row.get("synthetic", "0")) == "1"
        )
        non_synthetic_valid_human_label_rows = len(valid_decision_ids & non_synthetic_candidate_ids)
        errors.extend(decision_errors)
        missing_ids = sorted(known_candidate_ids - valid_decision_ids)
        if missing_ids:
            errors.append(f"missing candidate_label_id decisions: {', '.join(missing_ids[:20])}")
        if non_synthetic_valid_human_label_rows < args.min_labels:
            errors.append(
                "non_synthetic_valid_human_label_rows "
                f"{non_synthetic_valid_human_label_rows} below required minimum {args.min_labels}"
            )
        errors.extend(validate_compile_boundaries(template_rows, decision_map(decisions)))
        label_template_bundle_sha256 = sha256_json(template_fingerprints)
        label_packet_summary: dict = {}
        if label_packet_summary_path and not input_path_errors:
            label_packet_summary = read_json(label_packet_summary_path, "label packet summary")
            errors.extend(
                validate_label_packet_summary_binding(
                    label_packet_summary,
                    template_fingerprints=template_fingerprints,
                    decisions_fingerprints=decisions_fingerprints,
                    candidate_label_rows=len(template_rows),
                    synthetic_candidate_rows=synthetic_candidate_rows,
                    non_synthetic_candidate_rows=len(non_synthetic_candidate_ids),
                    decision_rows=len(decisions),
                    valid_human_label_rows=valid_human_label_rows,
                    non_synthetic_valid_human_label_rows=non_synthetic_valid_human_label_rows,
                    missing_candidate_label_count=len(missing_ids),
                )
            )

        if errors:
            if args.json:
                print(json.dumps({"schema": SCHEMA, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1

        per_case = build_case_rows(
            template_by_case=template_by_case,
            repo_by_case=repo_by_case,
            decisions_path=decisions_path,
            out_root=out_root,
        )
        operator_commands: list[str] = []
        for row in per_case:
            operator_commands.extend([row["compile_command"], row["verify_command"]])
        payload = {
            "schema": SCHEMA,
            "repo_intake": str(repo_intake_path),
            "repo_intake_sha256": sha256_file(repo_intake_path),
            "repo_snapshot_lock_sha256": repo_summary.get("repo_snapshot_lock_sha256", ""),
            "decisions": str(decisions_path),
            "decisions_sha256": sha256_file(decisions_path),
            "label_packet_summary": str(label_packet_summary_path) if label_packet_summary_path else "",
            "label_packet_summary_sha256": sha256_file(label_packet_summary_path)
            if label_packet_summary_path
            else "",
            "label_packet_summary_bound": int(label_packet_summary_path is not None),
            "label_packet_decisions_fingerprints": label_packet_summary.get(
                "decisions_fingerprints",
                [],
            ),
            "label_packet_decisions_bundle_sha256": label_packet_summary.get(
                "decisions_bundle_sha256",
                "",
            ),
            "label_packet_template_bundle_sha256": label_packet_summary.get(
                "label_template_bundle_sha256",
                "",
            ),
            "out_root": str(out_root),
            "template_dir_count": len(args.template_dir),
            "label_template_fingerprints": template_fingerprints,
            "label_template_json_sha256s": [
                row["label_template_json_sha256"] for row in template_fingerprints
            ],
            "label_template_manifest_sha256s": [
                row["label_template_manifest_sha256"]
                for row in template_fingerprints
                if row["label_template_manifest_sha256"]
            ],
            "label_template_bundle_sha256": label_template_bundle_sha256,
            "label_template_verify_existing_required": int(not args.skip_verify_existing),
            "label_template_verify_existing_passed_dirs": verify_counts[
                "label_template_verify_existing_passed_dirs"
            ],
            "label_template_verify_existing_failed_dirs": verify_counts[
                "label_template_verify_existing_failed_dirs"
            ],
            "case_count": len(per_case),
            "candidate_label_rows": len(template_rows),
            "synthetic_candidate_rows": synthetic_candidate_rows,
            "non_synthetic_candidate_rows": len(non_synthetic_candidate_ids),
            "decision_rows": len(decisions),
            "valid_human_label_rows": valid_human_label_rows,
            "non_synthetic_valid_human_label_rows": non_synthetic_valid_human_label_rows,
            "human_label_requirement_met": int(non_synthetic_valid_human_label_rows >= args.min_labels),
            "human_labels_remaining_to_minimum": max(
                0,
                args.min_labels - non_synthetic_valid_human_label_rows,
            ),
            "min_real_repos_required": int(repo_summary.get("min_real_repos_required", args.min_repos)),
            "min_human_label_rows_required": args.min_labels,
            "ready_for_label_intake_plan": 1,
            "decision_input_guard_passed": int(not input_path_errors),
            "output_path_guard_passed": int(not output_path_errors),
            "compiles_labels": 0,
            "writes_label_intake_outputs": 0,
            "creates_benchmark_evidence": 0,
            "runs_real_benchmark": 0,
            "operator_command_count": len(operator_commands),
            "operator_commands_sha256": sha256_json(operator_commands),
            "writes_operator_command_script": 0,
            "operator_commands_script": "",
            "operator_commands_script_sha256": "",
            "operator_commands_script_command_count": 0,
            "per_case": per_case,
            "operator_commands": operator_commands,
            **BLOCKED_FLAGS,
            "errors": [],
        }
        if args.out_commands_sh:
            command_script_path = Path(args.out_commands_sh).expanduser().resolve()
            payload["writes_operator_command_script"] = 1
            payload["operator_commands_script"] = str(command_script_path)
            payload["operator_commands_script_command_count"] = len(operator_commands)
            payload["operator_commands_script_sha256"] = write_command_script(
                command_script_path,
                payload,
                args.overwrite,
            )
        write_json(Path(args.out_json).expanduser().resolve(), payload, args.overwrite)
        if args.out_md:
            write_markdown(Path(args.out_md).expanduser().resolve(), payload, args.overwrite)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            print(f"label_intake_plan: ok valid_human_label_rows={valid_human_label_rows}")
        return 0
    except Exception as exc:
        print(f"label_intake_plan: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
