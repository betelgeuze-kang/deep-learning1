#!/usr/bin/env python3
"""Create a read-only AMR beta repo-intake sheet from local repos.

This helper is for blocker 9.1 operations. It records current local git HEADs
and clean-worktree declarations for human-supplied repositories, writes a
filled intake sheet, and validates it with the repo intake validator.

It does not run audits, does not generate label templates, does not create
benchmark evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_repo_intake_collect.v1"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
REQUIRED_COLUMNS = [
    "case_id",
    "repo_path",
    "expected_repo_git_head",
    "clean_worktree",
    "owner_or_maintainer_contact",
    "audit_mode",
    "namespace",
    "real_benchmark_namespace_confirmed",
    "notes",
]


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git_text(repo: Path, args: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def table_safe(value: object) -> str:
    text = str(value)
    if "\n" in text or "\r" in text:
        raise ValueError("intake table values must be single-line")
    if "|" in text:
        raise ValueError("Markdown intake output cannot contain '|' characters; use --format csv")
    return text


def output_exists_errors(path: Path, overwrite: bool) -> list[str]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        errors.append("out must not be .env-like")
    if path.exists() and not overwrite:
        errors.append(f"out already exists; use --overwrite: {path}")
    tmp_path = path.with_name(path.name + ".tmp")
    if tmp_path.exists():
        errors.append(f"temporary output already exists: {tmp_path}")
    return errors


def generated_case_ids(count: int, prefix: str) -> list[str]:
    width = max(2, len(str(count)))
    return [f"{prefix}-{index:0{width}d}" for index in range(1, count + 1)]


def validate_repeated_count(name: str, values: list[str], expected: int, *, allow_empty: bool = False) -> list[str]:
    if not values and allow_empty:
        return []
    if len(values) != expected:
        return [f"{name} count {len(values)} must match --repo count {expected}"]
    return []


def build_rows(args: argparse.Namespace) -> tuple[list[dict[str, str]], list[str]]:
    errors: list[str] = []
    repo_args = args.repo or []
    if not repo_args:
        errors.append("at least one --repo is required")
        return [], errors
    if not args.confirm_real_benchmark_namespace:
        errors.append("--confirm-real-benchmark-namespace is required")
    errors.extend(validate_repeated_count("--contact", args.contact or [], len(repo_args)))
    errors.extend(validate_repeated_count("--case-id", args.case_id or [], len(repo_args), allow_empty=True))
    if errors:
        return [], errors

    case_ids = args.case_id if args.case_id else generated_case_ids(len(repo_args), args.case_prefix)
    rows: list[dict[str, str]] = []
    for index, (raw_repo, case_id, contact) in enumerate(zip(repo_args, case_ids, args.contact), start=1):
        repo = Path(raw_repo).expanduser().resolve()
        if is_forbidden_env_path(repo):
            errors.append(f"row {index}: repo_path must not be .env-like")
        if not repo_intake.SAFE_CASE_ID.fullmatch(case_id):
            errors.append(f"row {index}: case_id must be a safe identifier")
        if not repo_intake.good_operator_value(case_id):
            errors.append(f"row {index}: case_id must not be example/placeholder")
        if not repo_intake.good_operator_value(contact) or not repo_intake.good_contact_value(contact):
            errors.append(f"row {index}: owner_or_maintainer_contact must be human-supplied")

        actual_head = ""
        clean_worktree = "false"
        if not repo.is_dir():
            errors.append(f"row {index}: repo_path is not a directory: {repo}")
        else:
            code, inside, _ = git_text(repo, ["rev-parse", "--is-inside-work-tree"])
            if code != 0 or inside.strip() != "true":
                errors.append(f"row {index}: repo_path is not a git worktree")
            else:
                head_code, head, _ = git_text(repo, ["rev-parse", "HEAD"])
                if head_code != 0:
                    errors.append(f"row {index}: unable to read git HEAD")
                else:
                    actual_head = head.strip().lower()
                _, status, _ = git_text(repo, ["status", "--porcelain=v1", "--untracked-files=all"])
                clean_worktree = "true" if not status.strip() else "false"

        rows.append(
            {
                "case_id": case_id,
                "repo_path": str(repo),
                "expected_repo_git_head": actual_head,
                "clean_worktree": clean_worktree,
                "owner_or_maintainer_contact": contact,
                "audit_mode": args.audit_mode,
                "namespace": "real_benchmark",
                "real_benchmark_namespace_confirmed": "true",
                "notes": args.notes,
            }
        )
    return rows, errors


def write_markdown(path: Path, rows: list[dict[str, str]]) -> None:
    lines = [
        "| " + " | ".join(REQUIRED_COLUMNS) + " |",
        "|" + "|".join("---" for _ in REQUIRED_COLUMNS) + "|",
    ]
    for row in rows:
        lines.append("| " + " | ".join(table_safe(row.get(column, "")) for column in REQUIRED_COLUMNS) + " |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=REQUIRED_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in REQUIRED_COLUMNS})


def write_rows(path: Path, rows: list[dict[str, str]], fmt: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(path.name + ".tmp")
    if fmt == "csv":
        write_csv(tmp_path, rows)
    else:
        write_markdown(tmp_path, rows)
    parsed_rows = repo_intake.read_rows(tmp_path)
    post_errors, _ = repo_intake.validate_rows(parsed_rows, min_repos=len(rows))
    if post_errors:
        tmp_path.unlink(missing_ok=True)
        raise ValueError("; ".join(post_errors))
    tmp_path.replace(path)


def build_payload(
    *,
    rows: list[dict[str, str]],
    validator_summary: dict[str, object],
    out_path: Path,
    errors: list[str],
    wrote: bool,
    output_sha256: str,
) -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "total_repos_requested": len(rows),
        "valid_repo_rows": int(validator_summary.get("valid_repo_rows", 0)),
        "min_real_repos_required": int(validator_summary.get("min_real_repos_required", 0)),
        "ready_for_repo_intake_sheet": int(not errors),
        "generated_intake": str(out_path) if wrote else "",
        "generated_intake_sha256": output_sha256,
        "writes_repo_intake_sheet": int(wrote),
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "repo_snapshot_lock_row_count": int(validator_summary.get("repo_snapshot_lock_row_count", 0)),
        "repo_snapshot_lock_sha256": validator_summary.get("repo_snapshot_lock_sha256", ""),
        "row_statuses": validator_summary.get("row_statuses", []),
        **BLOCKED_FLAGS,
        "errors": errors,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", action="append", required=True, help="Local repository path; repeat once per repo.")
    parser.add_argument(
        "--contact",
        action="append",
        required=True,
        help="Owner or maintainer contact for the matching --repo; repeat in the same order.",
    )
    parser.add_argument(
        "--case-id",
        action="append",
        default=[],
        help="Optional case id for the matching --repo; repeat in the same order.",
    )
    parser.add_argument("--case-prefix", default="amr-repo", help="Generated case id prefix when --case-id is omitted.")
    parser.add_argument("--audit-mode", choices=["quick", "full"], default="quick")
    parser.add_argument(
        "--confirm-real-benchmark-namespace",
        action="store_true",
        help="Explicitly confirm every emitted row uses namespace=real_benchmark.",
    )
    parser.add_argument("--notes", default="human supplied local repo intake")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--out", required=True, help="Filled intake sheet to write outside target repos.")
    parser.add_argument("--format", choices=["md", "csv"], default="md")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true", help="Print a machine-readable status JSON.")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    raw_out_path = Path(args.out).expanduser()
    out_path = raw_out_path.resolve()
    rows, build_errors = build_rows(args)
    validator_errors: list[str] = []
    summary: dict[str, object] = {
        "valid_repo_rows": 0,
        "min_real_repos_required": args.min_repos,
        "row_statuses": [],
    }
    if rows:
        validator_errors, summary = repo_intake.validate_rows(rows, min_repos=args.min_repos)
    target_repo_paths = repo_intake.target_repo_paths_from_statuses(summary.get("row_statuses", []))
    path_errors = repo_intake.validate_output_paths({"out": out_path}, target_repo_paths)
    output_errors = output_exists_errors(raw_out_path, args.overwrite)
    errors = [*build_errors, *validator_errors, *path_errors, *output_errors]

    wrote = False
    output_sha256 = ""
    if not errors:
        try:
            write_rows(out_path, rows, args.format)
            wrote = True
            output_sha256 = sha256_file(out_path)
        except Exception as exc:
            errors.append(str(exc))
    payload = build_payload(
        rows=rows,
        validator_summary=summary,
        out_path=out_path,
        errors=errors,
        wrote=wrote,
        output_sha256=output_sha256,
    )
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    if not args.json:
        print(
            "repo_intake_collect: ok "
            f"valid_repo_rows={payload['valid_repo_rows']} "
            f"min_real_repos_required={payload['min_real_repos_required']} "
            f"out={out_path}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
