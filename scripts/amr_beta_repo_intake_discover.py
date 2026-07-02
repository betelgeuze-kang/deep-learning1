#!/usr/bin/env python3
"""Discover local git repos as AMR beta repo-intake candidates.

This is a read-only pre-intake helper for blocker 9.1. It finds local git
worktree roots under human-supplied scan roots and reports whether each
candidate has a readable HEAD and clean status. Discovery output is only a
candidate triage artifact: it does not supply maintainer contact, does not
confirm the real_benchmark namespace for a human owner, does not run audits,
does not create benchmark evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_repo_intake_discover.v1"
MIN_REAL_REPOS_FOR_BETA = repo_intake.MIN_REAL_REPOS_FOR_BETA
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
SKIP_DIR_NAMES = {
    ".cache",
    ".git",
    ".hg",
    ".mypy_cache",
    ".pytest_cache",
    ".svn",
    ".tox",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "env",
    "node_modules",
    "results",
    "venv",
}
SAFE_ID_CHARS = re.compile(r"[^A-Za-z0-9_.-]+")
PROJECT_ROOT = Path(__file__).resolve().parent.parent


def git_text(repo: Path, args: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def is_hidden_path(path: Path, root: Path) -> bool:
    try:
        relative = path.resolve().relative_to(root.resolve())
    except ValueError:
        relative = path
    return any(part.startswith(".") and part != ".git" for part in relative.parts)


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def is_git_marker(path: Path) -> bool:
    marker = path / ".git"
    return marker.is_dir() or marker.is_file()


def git_root_for(path: Path) -> Path | None:
    code, inside, _ = git_text(path, ["rev-parse", "--is-inside-work-tree"])
    if code != 0 or inside.strip() != "true":
        return None
    root_code, root, _ = git_text(path, ["rev-parse", "--show-toplevel"])
    if root_code != 0 or not root.strip():
        return None
    return Path(root.strip()).expanduser().resolve()


def suggest_case_id(index: int, repo_root: Path) -> str:
    stem = SAFE_ID_CHARS.sub("-", repo_root.name.strip()).strip(".-")
    if not stem or not repo_intake.SAFE_CASE_ID.fullmatch(stem):
        stem = "repo"
    return f"candidate-{index:02d}-{stem[:64]}"


def candidate_blockers(row: dict[str, object]) -> list[str]:
    blockers: list[str] = []
    if int(row["repo_git_worktree_confirmed"]) != 1:
        blockers.append("git_worktree_unconfirmed")
    if int(row["repo_head_readable"]) != 1:
        blockers.append("head_unreadable")
    if int(row["repo_status_readable"]) != 1:
        blockers.append("status_unreadable")
    if row.get("clean_worktree_actual") != 1:
        blockers.append("dirty_or_unknown_worktree")
    blockers.append("human_owner_or_maintainer_contact_required")
    blockers.append("filled_intake_namespace_confirmation_required")
    if row.get("path_risk_flags"):
        blockers.append("human_real_repo_source_confirmation_required")
    return blockers


def configured_temp_roots() -> tuple[Path, ...]:
    roots: list[Path] = []
    seen: set[str] = set()
    candidates = [
        tempfile.gettempdir(),
        os.environ.get("TMPDIR"),
        os.environ.get("TEMP"),
        os.environ.get("TMP"),
        "/tmp",
        "/var/tmp",
    ]
    for raw in candidates:
        if not raw:
            continue
        path = Path(raw).expanduser()
        if not path.is_absolute():
            continue
        key = str(path.resolve())
        if key in seen:
            continue
        seen.add(key)
        roots.append(path)
    return tuple(roots)


def has_pytest_temp_layout(parts: list[str]) -> bool:
    return any(
        part.startswith("pytest-of-")
        or re.fullmatch(r"pytest-\d+", part) is not None
        or part == "pytest-current"
        for part in parts
    )


def path_risk_flags(repo_root: Path) -> list[str]:
    flags: list[str] = []
    parts = repo_root.parts
    lowered = [part.lower() for part in parts]
    is_temp_path = any(is_relative_to(repo_root, temp_root) for temp_root in configured_temp_roots())
    if is_temp_path:
        flags.append("temporary_path")
    if is_temp_path and has_pytest_temp_layout(lowered):
        flags.append("pytest_temp_path")
    if any(part.startswith(".") for part in parts):
        flags.append("hidden_path")
    if ".codex" in lowered:
        flags.append("codex_internal_path")
    if ".config" in lowered:
        flags.append("config_internal_path")
    if "_work" in lowered or any("runner" in part for part in lowered):
        flags.append("runner_worktree_path")
    if repo_root == PROJECT_ROOT or PROJECT_ROOT in repo_root.parents:
        flags.append("current_artifact_repo")
    return flags


def inspect_repo(repo_root: Path, index: int) -> dict[str, object]:
    root = repo_root.expanduser().resolve()
    row: dict[str, object] = {
        "candidate_index": index,
        "suggested_case_id": suggest_case_id(index, root),
        "repo_path": str(root),
        "repo_git_root": str(root),
        "repo_git_worktree_confirmed": 0,
        "repo_head_readable": 0,
        "repo_status_readable": 0,
        "actual_repo_git_head": "",
        "clean_worktree_actual": None,
        "owner_or_maintainer_contact_present": 0,
        "owner_or_maintainer_contact_required": 1,
        "suggested_audit_mode": "quick",
        "suggested_namespace": "real_benchmark",
        "real_benchmark_namespace_confirmation_required": 1,
        "path_risk_flags": path_risk_flags(root),
        "path_risk_flag_count": 0,
        "human_real_repo_source_confirmation_required": 0,
        "ready_for_intake_after_human_contact": 0,
        "counts_for_repo_intake": 0,
    }
    row["path_risk_flag_count"] = len(row["path_risk_flags"])
    row["human_real_repo_source_confirmation_required"] = int(bool(row["path_risk_flags"]))
    git_root = git_root_for(root)
    if git_root == root:
        row["repo_git_worktree_confirmed"] = 1

    head_code, head, _ = git_text(root, ["rev-parse", "HEAD"])
    if head_code == 0 and head.strip():
        row["repo_head_readable"] = 1
        row["actual_repo_git_head"] = head.strip().lower()

    status_code, status, _ = git_text(root, ["status", "--porcelain=v1", "--untracked-files=all"])
    if status_code == 0:
        row["repo_status_readable"] = 1
        row["clean_worktree_actual"] = int(not status.strip())

    row["ready_for_intake_after_human_contact"] = int(
        row["repo_git_worktree_confirmed"] == 1
        and row["repo_head_readable"] == 1
        and row["repo_status_readable"] == 1
        and row["clean_worktree_actual"] == 1
    )
    row["blockers_before_counting"] = candidate_blockers(row)
    return row


def prune_dirs(dirnames: list[str], *, include_hidden: bool) -> None:
    kept: list[str] = []
    for name in dirnames:
        if name in SKIP_DIR_NAMES:
            continue
        if not include_hidden and name.startswith("."):
            continue
        kept.append(name)
    dirnames[:] = kept


def discover_repos(roots: list[Path], *, max_depth: int, include_hidden: bool, max_candidates: int) -> list[Path]:
    discovered: dict[str, Path] = {}
    for raw_root in roots:
        root = raw_root.expanduser().resolve()
        if is_forbidden_env_path(root) or not root.exists() or not root.is_dir():
            continue

        root_git = git_root_for(root)
        if root_git is not None and (include_hidden or not is_hidden_path(root_git, root_git.parent)):
            discovered[str(root_git)] = root_git
            if len(discovered) >= max_candidates:
                break

        for dirpath, dirnames, _filenames in os.walk(root):
            current = Path(dirpath).resolve()
            if is_forbidden_env_path(current):
                dirnames[:] = []
                continue
            try:
                depth = len(current.relative_to(root).parts)
            except ValueError:
                depth = max_depth + 1
            if depth > max_depth:
                dirnames[:] = []
                continue
            if is_git_marker(current):
                git_root = git_root_for(current)
                if git_root is not None:
                    discovered[str(git_root)] = git_root
            prune_dirs(dirnames, include_hidden=include_hidden)
            if len(discovered) >= max_candidates:
                break
        if len(discovered) >= max_candidates:
            break
    return sorted(discovered.values(), key=lambda path: str(path))


def output_exists_errors(
    raw_paths: dict[str, Path],
    resolved_paths: dict[str, Path],
    overwrite: bool,
) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, str] = {}
    for name, raw_path in raw_paths.items():
        if is_forbidden_env_path(raw_path):
            errors.append(f"{name} must not be .env-like")
        resolved = resolved_paths[name]
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen:
            errors.append(f"{name} must not reuse {seen[resolved]} path: {resolved}")
        seen[resolved] = name
        if resolved.exists() and not overwrite:
            errors.append(f"{name} already exists; use --overwrite: {resolved}")
        tmp_path = resolved.with_name(resolved.name + ".tmp")
        if tmp_path.exists():
            errors.append(f"{name} temporary output already exists: {tmp_path}")
    return errors


def nearest_existing_dir(path: Path) -> Path | None:
    current = path.resolve().parent
    while not current.exists() and current != current.parent:
        current = current.parent
    if current.exists() and current.is_dir():
        return current
    return None


def output_git_worktree_errors(paths: dict[str, Path]) -> list[str]:
    errors: list[str] = []
    for name, path in paths.items():
        resolved = path.resolve()
        parent = nearest_existing_dir(resolved)
        if parent is None:
            continue
        git_root = git_root_for(parent)
        if git_root is not None and (resolved == git_root or is_relative_to(resolved, git_root)):
            errors.append(f"{name} must not be inside a git worktree: {resolved} (repo: {git_root})")
    return errors


def build_payload(args: argparse.Namespace, candidates: list[dict[str, object]], errors: list[str]) -> dict[str, object]:
    ready_after_contact = sum(int(row["ready_for_intake_after_human_contact"]) for row in candidates)
    path_risk_count = sum(int(bool(row.get("path_risk_flags"))) for row in candidates)
    ready_with_path_risk = sum(
        int(row["ready_for_intake_after_human_contact"] and bool(row.get("path_risk_flags")))
        for row in candidates
    )
    ready_without_path_risk = ready_after_contact - ready_with_path_risk
    return {
        "schema": SCHEMA,
        "scan_roots": [str(Path(root).expanduser().resolve()) for root in args.root],
        "max_depth": args.max_depth,
        "include_hidden": int(args.include_hidden),
        "candidate_repo_count": len(candidates),
        "candidate_repos_with_clean_head": ready_after_contact,
        "candidate_repos_with_path_risk": path_risk_count,
        "candidate_repos_with_clean_head_and_path_risk": ready_with_path_risk,
        "candidate_repos_with_clean_head_and_no_path_risk": ready_without_path_risk,
        "clean_risk_free_candidate_shortfall_to_minimum": max(
            0,
            MIN_REAL_REPOS_FOR_BETA - ready_without_path_risk,
        ),
        "min_real_repos_required": MIN_REAL_REPOS_FOR_BETA,
        "repo_intake_rows_counted": 0,
        "ready_for_repo_intake": 0,
        "candidate_rows_cannot_count_without_human_contact": 1,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "candidates": candidates,
        **BLOCKED_FLAGS,
        "errors": errors,
    }


def markdown_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def write_json(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp_path.replace(path)


def write_markdown(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Repo Discovery Candidates",
        "",
        f"- ready_for_repo_intake: {payload['ready_for_repo_intake']}",
        f"- candidate_repo_count: {payload['candidate_repo_count']}",
        f"- candidate_repos_with_clean_head: {payload['candidate_repos_with_clean_head']}",
        f"- candidate_repos_with_clean_head_and_no_path_risk: {payload['candidate_repos_with_clean_head_and_no_path_risk']}",
        f"- candidate_repos_with_clean_head_and_path_risk: {payload['candidate_repos_with_clean_head_and_path_risk']}",
        f"- candidate_repos_with_path_risk: {payload['candidate_repos_with_path_risk']}",
        f"- clean_risk_free_candidate_shortfall_to_minimum: {payload['clean_risk_free_candidate_shortfall_to_minimum']}",
        f"- repo_intake_rows_counted: {payload['repo_intake_rows_counted']}",
        f"- candidate_rows_cannot_count_without_human_contact: {payload['candidate_rows_cannot_count_without_human_contact']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Candidates",
        "",
        "| idx | suggested_case_id | clean | head_readable | status_readable | counts | risk_flags | repo_path | blockers |",
        "|---:|---|---:|---:|---:|---:|---|---|---|",
    ]
    for row in payload["candidates"]:
        blockers = ",".join(str(item) for item in row["blockers_before_counting"])
        lines.append(
            "| {idx} | {case_id} | {clean} | {head} | {status} | {counts} | {risk_flags} | {repo} | {blockers} |".format(
                idx=row["candidate_index"],
                case_id=markdown_cell(row["suggested_case_id"]),
                clean=markdown_cell(row["clean_worktree_actual"]),
                head=row["repo_head_readable"],
                status=row["repo_status_readable"],
                counts=row["counts_for_repo_intake"],
                risk_flags=markdown_cell(",".join(str(flag) for flag in row.get("path_risk_flags", []))),
                repo=markdown_cell(row["repo_path"]),
                blockers=markdown_cell(blockers),
            )
        )
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    tmp_path.replace(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", action="append", required=True, help="Directory tree to scan for local git repos.")
    parser.add_argument("--max-depth", type=int, default=4, help="Maximum directory depth to scan under each root.")
    parser.add_argument("--max-candidates", type=int, default=100, help="Stop after this many unique repo roots.")
    parser.add_argument("--include-hidden", action="store_true", help="Scan hidden directories under each root.")
    parser.add_argument("--out-json", default="", help="Optional candidate discovery JSON output.")
    parser.add_argument("--out-md", default="", help="Optional candidate discovery Markdown output.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true", help="Print candidate discovery JSON to stdout.")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    errors: list[str] = []
    if args.max_depth < 0:
        errors.append("--max-depth must be non-negative")
    if args.max_candidates <= 0:
        errors.append("--max-candidates must be positive")
    raw_roots = [Path(root).expanduser() for root in args.root]
    roots: list[Path] = []
    for root in raw_roots:
        resolved = root.resolve()
        if is_forbidden_env_path(root) or is_forbidden_env_path(resolved):
            errors.append(f"--root must not be .env-like: {resolved}")
        elif not resolved.exists() or not resolved.is_dir():
            errors.append(f"--root must be an existing directory: {resolved}")
        roots.append(resolved)

    repo_roots: list[Path] = []
    candidates: list[dict[str, object]] = []
    if not errors:
        repo_roots = discover_repos(
            roots,
            max_depth=args.max_depth,
            include_hidden=args.include_hidden,
            max_candidates=args.max_candidates,
        )
        candidates = [inspect_repo(repo, index) for index, repo in enumerate(repo_roots, start=1)]

    raw_output_paths: dict[str, Path] = {}
    if args.out_json:
        raw_output_paths["out_json"] = Path(args.out_json).expanduser()
    if args.out_md:
        raw_output_paths["out_md"] = Path(args.out_md).expanduser()
    resolved_output_paths = {name: path.resolve() for name, path in raw_output_paths.items()}
    errors.extend(repo_intake.validate_output_paths(resolved_output_paths, [str(path) for path in repo_roots]))
    errors.extend(output_git_worktree_errors(resolved_output_paths))
    errors.extend(output_exists_errors(raw_output_paths, resolved_output_paths, args.overwrite))

    payload = build_payload(args, candidates, errors)
    if not errors:
        try:
            if args.out_json:
                write_json(resolved_output_paths["out_json"], payload, args.overwrite)
            if args.out_md:
                write_markdown(resolved_output_paths["out_md"], payload, args.overwrite)
        except Exception as exc:
            errors.append(str(exc))
            payload["errors"] = errors

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    if not args.json:
        print(
            "repo_intake_discover: ok "
            f"candidate_repo_count={payload['candidate_repo_count']} "
            f"candidate_repos_with_clean_head={payload['candidate_repos_with_clean_head']} "
            "repo_intake_rows_counted=0"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
