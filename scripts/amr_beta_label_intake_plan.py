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


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


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


def load_templates(raw_dirs: list[str], *, verify_existing: bool) -> tuple[list[dict], list[str], dict[str, Path], dict[str, int]]:
    rows: list[dict] = []
    errors: list[str] = []
    by_case: dict[str, Path] = {}
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
    }


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
        f"- min_human_label_rows_required: {payload['min_human_label_rows_required']}",
        f"- label_template_verify_existing_required: {payload['label_template_verify_existing_required']}",
        f"- label_template_verify_existing_passed_dirs: {payload['label_template_verify_existing_passed_dirs']}",
        f"- label_template_verify_existing_failed_dirs: {payload['label_template_verify_existing_failed_dirs']}",
        f"- compiles_labels: {payload['compiles_labels']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_real_benchmark: {payload['runs_real_benchmark']}",
        f"- operator_commands_sha256: {payload['operator_commands_sha256']}",
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", required=True, help="Filled repo-intake Markdown or CSV.")
    parser.add_argument("--template-dir", action="append", required=True, help="Label template dir; repeatable.")
    parser.add_argument("--decisions", required=True, help="Human decision JSON/JSONL file.")
    parser.add_argument("--out-root", default="results/amr_beta_label_intake_work")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--min-labels", type=int, default=label_packet.MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument("--out-json", required=True, help="Label-intake plan JSON output.")
    parser.add_argument("--out-md", default="", help="Optional Markdown plan output.")
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
        out_root = Path(args.out_root).expanduser().resolve()
        for path, label in [
            (repo_intake_path, "repo intake"),
            (decisions_path, "decisions"),
            (out_root, "output root"),
        ]:
            if is_forbidden_env_path(path):
                raise ValueError(f"refusing .env-like {label} path")
        if not decisions_path.is_file():
            raise ValueError(f"--decisions is not a file: {decisions_path}")

        repo_by_case, repo_summary = load_repo_context(repo_intake_path, min_repos=args.min_repos)
        template_rows, template_errors, template_by_case, verify_counts = load_templates(
            args.template_dir,
            verify_existing=not args.skip_verify_existing,
        )
        template_case_ids = set(template_by_case)
        repo_case_ids = set(repo_by_case)
        errors = [*template_errors]
        missing_repo_cases = sorted(template_case_ids - repo_case_ids)
        if missing_repo_cases:
            errors.append("template case_id values missing from repo intake: " + ", ".join(missing_repo_cases[:20]))
        missing_template_cases = sorted(repo_case_ids - template_case_ids)
        if missing_template_cases:
            errors.append("repo intake case_id values missing from templates: " + ", ".join(missing_template_cases[:20]))

        decisions = label_packet.read_json_or_jsonl(decisions_path, "decisions")
        known_candidate_ids = {row["candidate_label_id"] for row in template_rows}
        decision_errors, valid_decision_ids, valid_human_label_rows = label_packet.validate_decisions(
            decisions,
            known_candidate_ids,
        )
        errors.extend(decision_errors)
        missing_ids = sorted(known_candidate_ids - valid_decision_ids)
        if missing_ids:
            errors.append(f"missing candidate_label_id decisions: {', '.join(missing_ids[:20])}")
        if valid_human_label_rows < args.min_labels:
            errors.append(f"valid_human_label_rows {valid_human_label_rows} below required minimum {args.min_labels}")
        errors.extend(validate_compile_boundaries(template_rows, decision_map(decisions)))

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
            "decisions": str(decisions_path),
            "decisions_sha256": sha256_file(decisions_path),
            "out_root": str(out_root),
            "template_dir_count": len(args.template_dir),
            "label_template_verify_existing_required": int(not args.skip_verify_existing),
            "label_template_verify_existing_passed_dirs": verify_counts[
                "label_template_verify_existing_passed_dirs"
            ],
            "label_template_verify_existing_failed_dirs": verify_counts[
                "label_template_verify_existing_failed_dirs"
            ],
            "case_count": len(per_case),
            "candidate_label_rows": len(template_rows),
            "decision_rows": len(decisions),
            "valid_human_label_rows": valid_human_label_rows,
            "min_real_repos_required": int(repo_summary.get("min_real_repos_required", args.min_repos)),
            "min_human_label_rows_required": args.min_labels,
            "ready_for_label_intake_plan": 1,
            "compiles_labels": 0,
            "writes_label_intake_outputs": 0,
            "creates_benchmark_evidence": 0,
            "runs_real_benchmark": 0,
            "operator_command_count": len(operator_commands),
            "operator_commands_sha256": sha256_json(operator_commands),
            "per_case": per_case,
            "operator_commands": operator_commands,
            **BLOCKED_FLAGS,
            "errors": [],
        }
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
