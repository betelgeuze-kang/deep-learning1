#!/usr/bin/env python3
"""Validate AMR beta repository-intake sheets without creating evidence.

This is a read-only operator guard for blocker 9.1. It validates a filled
Markdown table or CSV before any audit/label/benchmark artifacts are created.
It does not run audit-my-repo, does not create benchmark evidence, and does
not promote readiness.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

MIN_REAL_REPOS_FOR_BETA = 10
SAFE_CASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
GIT_OBJECT_RE = re.compile(r"^([0-9a-f]{40}|[0-9a-f]{64})$")
TRUTHY = {"1", "true", "yes", "y"}
PLACEHOLDER_RE = re.compile(
    r"(^$|example|placeholder|replace|todo|<git rev-parse head>|/abs/path/to/repo)",
    re.IGNORECASE,
)
CONTACT_PLACEHOLDER_RE = re.compile(
    r"(^$|example|placeholder|replace|todo|synthetic|fixture|\.invalid\b)",
    re.IGNORECASE,
)
FORBIDDEN_METADATA_NAME_RE = re.compile(
    r"(^|_)(example|fixture|placeholder|sample|synthetic|template_only)($|_)",
    re.IGNORECASE,
)
FORBIDDEN_METADATA_VALUE_RE = re.compile(
    r"\b(example|fixture|placeholder|replace|sample|synthetic|template[-_ ]?only|todo)\b",
    re.IGNORECASE,
)
NEGATED_METADATA_MARKER_RE = re.compile(
    r"\b(?:not|no|non)\s+(?:an?\s+)?(?:example|fixture|placeholder|sample|synthetic|template[-_ ]?only)\b"
    r"|\bnon[-_ ](?:example|fixture|placeholder|sample|synthetic)\b"
    r"|\b(?:is[-_ ]?)?(?:example|fixture|placeholder|sample|synthetic|template[-_ ]?only)\s*[:=]\s*(?:0|false|no)\b",
    re.IGNORECASE,
)

REQUIRED_COLUMNS = [
    "case_id",
    "repo_path",
    "expected_repo_git_head",
    "clean_worktree",
    "owner_or_maintainer_contact",
    "audit_mode",
    "namespace",
    "real_benchmark_namespace_confirmed",
]

ALIASES = {
    "repo_id": "case_id",
    "local_path": "repo_path",
    "path": "repo_path",
    "head": "expected_repo_git_head",
    "git_head": "expected_repo_git_head",
    "expected_head": "expected_repo_git_head",
    "owner_maintainer_contact": "owner_or_maintainer_contact",
    "maintainer_contact": "owner_or_maintainer_contact",
    "owner_contact": "owner_or_maintainer_contact",
    "audit_mode_quick_full": "audit_mode",
    "real_benchmark_confirmed": "real_benchmark_namespace_confirmed",
    "confirm_real_benchmark_namespace": "real_benchmark_namespace_confirmed",
}


def normalize_header(value: str) -> str:
    text = re.sub(r"\([^)]*\)", "", value.strip().lower())
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return ALIASES.get(text, text)


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def validate_output_paths(paths: dict[str, Path], target_repo_paths: list[str]) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, str] = {}
    for name, path in paths.items():
        resolved = path.resolve()
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen:
            errors.append(f"{name} must not reuse {seen[resolved]} path: {resolved}")
        seen[resolved] = name
        for raw_repo in target_repo_paths:
            repo_path = Path(str(raw_repo)).expanduser().resolve()
            if resolved == repo_path or is_relative_to(resolved, repo_path):
                errors.append(f"{name} must not be inside target repo: {resolved} (repo: {repo_path})")
    return errors


def validate_input_path(intake_path: Path, target_repo_paths: list[str]) -> list[str]:
    errors: list[str] = []
    resolved = intake_path.resolve()
    if is_forbidden_env_path(resolved):
        errors.append("input_intake must not be .env-like")
    for raw_repo in target_repo_paths:
        repo_path = Path(str(raw_repo)).expanduser().resolve()
        if resolved == repo_path or is_relative_to(resolved, repo_path):
            errors.append(f"input_intake must not be inside target repo: {resolved} (repo: {repo_path})")
    return errors


def good_operator_value(value: str) -> bool:
    return not PLACEHOLDER_RE.search(str(value).strip())


def good_contact_value(value: str) -> bool:
    return not CONTACT_PLACEHOLDER_RE.search(str(value).strip())


def marks_forbidden_metadata_value(value: str) -> bool:
    text = str(value).strip()
    if not text:
        return False
    cleaned = NEGATED_METADATA_MARKER_RE.sub("", text)
    return bool(FORBIDDEN_METADATA_VALUE_RE.search(cleaned))


def truthy(value: str) -> bool:
    return str(value).strip().lower() in TRUTHY


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def read_markdown_table(path: Path) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    rows: list[dict[str, str]] = []
    header: list[str] | None = None
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            if header and rows:
                break
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if not cells:
            continue
        if all(set(cell.replace(":", "").strip()) <= {"-"} for cell in cells):
            continue
        normalized = [normalize_header(cell) for cell in cells]
        if header is None:
            if "case_id" in normalized and "repo_path" in normalized:
                header = normalized
            continue
        row = {column: cells[index] if index < len(cells) else "" for index, column in enumerate(header)}
        rows.append(row)
    return rows


def read_csv_table(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = []
        for raw in reader:
            row = {normalize_header(key or ""): str(value or "").strip() for key, value in raw.items()}
            rows.append(row)
        return rows


def read_rows(path: Path) -> list[dict[str, str]]:
    if is_forbidden_env_path(path):
        raise ValueError("refusing to read .env-like intake file")
    text = path.read_text(encoding="utf-8")
    first_nonempty = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if first_nonempty.startswith("|"):
        return read_markdown_table(path)
    return read_csv_table(path)


def git_text(repo: Path, args: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def row_status(index: int, normalized: dict[str, str], row_errors: list[str]) -> dict[str, object]:
    actual_head = normalized.get("actual_repo_git_head", "")
    clean_actual: int | None
    if any("repo_dirty" in error for error in row_errors):
        clean_actual = 0
    elif normalized.get("repo_status_readable") == "1" and actual_head:
        clean_actual = 1
    else:
        clean_actual = None
    return {
        "row_index": index,
        "case_id": normalized.get("case_id", ""),
        "repo_path": normalized.get("repo_path", ""),
        "repo_path_resolved": normalized.get("repo_path_resolved", ""),
        "repo_git_root": normalized.get("repo_git_root", ""),
        "expected_repo_git_head": normalized.get("expected_repo_git_head", "").lower(),
        "actual_repo_git_head": actual_head.lower(),
        "repo_git_worktree_confirmed": int(normalized.get("repo_git_worktree_confirmed", "0") == "1"),
        "repo_head_readable": int(normalized.get("repo_head_readable", "0") == "1"),
        "repo_status_readable": int(normalized.get("repo_status_readable", "0") == "1"),
        "repo_head_pinned": int(normalized.get("repo_head_pinned", "0") == "1"),
        "clean_worktree_declared": int(truthy(normalized.get("clean_worktree", ""))),
        "clean_worktree_actual": clean_actual,
        "owner_or_maintainer_contact_present": int(bool(normalized.get("owner_or_maintainer_contact", ""))),
        "audit_mode": normalized.get("audit_mode", "").lower(),
        "namespace": normalized.get("namespace", ""),
        "real_benchmark_namespace_confirmed": int(
            truthy(normalized.get("real_benchmark_namespace_confirmed", ""))
        ),
        "valid": int(not row_errors),
        "errors": row_errors,
    }


def snapshot_lock_rows(row_statuses: list[dict[str, object]]) -> list[dict[str, object]]:
    lock_rows: list[dict[str, object]] = []
    for status in row_statuses:
        lock_rows.append(
            {
                "row_index": status["row_index"],
                "case_id": status["case_id"],
                "repo_path_resolved": status["repo_path_resolved"],
                "repo_git_root": status["repo_git_root"],
                "expected_repo_git_head": status["expected_repo_git_head"],
                "actual_repo_git_head": status["actual_repo_git_head"],
                "repo_git_worktree_confirmed": status["repo_git_worktree_confirmed"],
                "repo_head_readable": status["repo_head_readable"],
                "repo_status_readable": status["repo_status_readable"],
                "repo_head_pinned": status["repo_head_pinned"],
                "clean_worktree_declared": status["clean_worktree_declared"],
                "clean_worktree_actual": status["clean_worktree_actual"],
                "owner_or_maintainer_contact_present": status[
                    "owner_or_maintainer_contact_present"
                ],
                "audit_mode": status["audit_mode"],
                "namespace": status["namespace"],
                "real_benchmark_namespace_confirmed": status[
                    "real_benchmark_namespace_confirmed"
                ],
                "valid": status["valid"],
            }
        )
    return lock_rows


def target_repo_paths_from_statuses(row_statuses: list[dict[str, object]]) -> list[str]:
    paths: set[str] = set()
    for status in row_statuses:
        for key in ["repo_path_resolved", "repo_git_root"]:
            value = str(status.get(key) or "").strip()
            if value:
                paths.add(value)
    return sorted(paths)


def validate_row(row: dict[str, str], index: int) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    normalized = {column: str(row.get(column, "")).strip() for column in REQUIRED_COLUMNS}
    normalized.update(
        {
            "repo_git_worktree_confirmed": "0",
            "repo_head_readable": "0",
            "repo_status_readable": "0",
            "repo_head_pinned": "0",
        }
    )
    for column in REQUIRED_COLUMNS:
        if not normalized[column]:
            errors.append(f"row {index}: missing {column}")

    case_id = normalized["case_id"]
    if case_id and not SAFE_CASE_ID.fullmatch(case_id):
        errors.append(f"row {index}: case_id must be a safe identifier")
    if case_id and not good_operator_value(case_id):
        errors.append(f"row {index}: case_id must not be example/placeholder")

    contact = normalized["owner_or_maintainer_contact"]
    if contact and (not good_operator_value(contact) or not good_contact_value(contact)):
        errors.append(f"row {index}: owner_or_maintainer_contact must be human-supplied")

    for column, raw_value in row.items():
        if column in REQUIRED_COLUMNS:
            continue
        value = str(raw_value).strip()
        if not value:
            continue
        if FORBIDDEN_METADATA_NAME_RE.search(column) and truthy(value):
            errors.append(f"row {index}: {column} must not be true for real repo intake")
        if marks_forbidden_metadata_value(value):
            errors.append(
                f"row {index}: optional metadata {column} must not mark the row "
                "as example/placeholder/synthetic/fixture"
            )

    audit_mode = normalized["audit_mode"].lower()
    if audit_mode and audit_mode not in {"quick", "full"}:
        errors.append(f"row {index}: audit_mode must be quick or full")

    namespace = normalized["namespace"]
    if namespace != "real_benchmark":
        errors.append(f"row {index}: namespace must be real_benchmark")
    if not truthy(normalized["real_benchmark_namespace_confirmed"]):
        errors.append(f"row {index}: real_benchmark_namespace_confirmed must be true")
    if not truthy(normalized["clean_worktree"]):
        errors.append(f"row {index}: clean_worktree must be true")

    expected_head = normalized["expected_repo_git_head"].lower()
    if expected_head and not GIT_OBJECT_RE.fullmatch(expected_head):
        errors.append(f"row {index}: expected_repo_git_head must be a full git object id")

    raw_repo = normalized["repo_path"]
    repo = Path(raw_repo).expanduser()
    if raw_repo and not good_operator_value(raw_repo):
        errors.append(f"row {index}: repo_path must not be example/placeholder")
    if raw_repo and not repo.is_absolute():
        errors.append(f"row {index}: repo_path must be absolute")
    repo = repo.resolve()
    if is_forbidden_env_path(repo):
        errors.append(f"row {index}: repo_path must not be .env-like")
    if raw_repo and not repo.is_dir():
        errors.append(f"row {index}: repo_path is not a directory: {repo}")
        return errors, {**normalized, "repo_path_resolved": str(repo)}

    if raw_repo and repo.is_dir():
        code, inside, _ = git_text(repo, ["rev-parse", "--is-inside-work-tree"])
        if code != 0 or inside.strip() != "true":
            errors.append(f"row {index}: repo_path is not a git worktree")
        else:
            normalized["repo_git_worktree_confirmed"] = "1"
            root_code, root, _ = git_text(repo, ["rev-parse", "--show-toplevel"])
            if root_code != 0 or not root.strip():
                errors.append(f"row {index}: unable to read git worktree root")
            else:
                repo_git_root = str(Path(root.strip()).expanduser().resolve())
                normalized["repo_git_root"] = repo_git_root
                if str(repo) != repo_git_root:
                    errors.append(f"row {index}: repo_path must be git worktree root")
            head_code, head, _ = git_text(repo, ["rev-parse", "HEAD"])
            actual_head = head.strip().lower()
            if head_code != 0 or not actual_head:
                errors.append(f"row {index}: unable to read git HEAD")
            else:
                normalized["repo_head_readable"] = "1"
                normalized["actual_repo_git_head"] = actual_head
                if expected_head and actual_head == expected_head:
                    normalized["repo_head_pinned"] = "1"
                elif expected_head:
                    errors.append(f"row {index}: expected_repo_git_head mismatch")

            status_code, status, _ = git_text(repo, ["status", "--porcelain=v1", "--untracked-files=all"])
            if status_code != 0:
                errors.append(f"row {index}: unable to read git status")
            else:
                normalized["repo_status_readable"] = "1"
                if status.strip():
                    errors.append(f"row {index}: repo_dirty")
    normalized["repo_path_resolved"] = str(repo)
    return errors, normalized


def validate_rows(rows: list[dict[str, str]], *, min_repos: int) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    seen_cases: set[str] = set()
    seen_repos: set[str] = set()
    seen_git_roots: set[str] = set()
    valid_rows = 0
    row_statuses: list[dict[str, object]] = []
    for index, row in enumerate(rows, start=1):
        row_errors, normalized = validate_row(row, index)
        case_id = normalized.get("case_id", "")
        repo_path = normalized.get("repo_path_resolved", "")
        repo_git_root = normalized.get("repo_git_root", "")
        if case_id:
            if case_id in seen_cases:
                row_errors.append(f"row {index}: duplicate case_id")
            seen_cases.add(case_id)
        if repo_path:
            if repo_path in seen_repos:
                row_errors.append(f"row {index}: duplicate repo_path")
            seen_repos.add(repo_path)
        if repo_git_root:
            if repo_git_root in seen_git_roots:
                row_errors.append(f"row {index}: duplicate repo_git_root")
            seen_git_roots.add(repo_git_root)
        if row_errors:
            errors.extend(row_errors)
        else:
            valid_rows += 1
        row_statuses.append(row_status(index, normalized, row_errors))
    if valid_rows < min_repos:
        errors.append(f"valid_repo_rows {valid_rows} below required minimum {min_repos}")
    lock_rows = snapshot_lock_rows(row_statuses)
    summary = {
        "schema": "amr_beta_repo_intake_validate.v1",
        "total_rows": len(rows),
        "valid_repo_rows": valid_rows,
        "min_real_repos_required": min_repos,
        "ready_for_real_benchmark_audit": int(not errors),
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "repo_snapshot_lock_row_count": len(lock_rows),
        "repo_snapshot_lock_rows": lock_rows,
        "repo_snapshot_lock_sha256": sha256_json(lock_rows),
        "row_statuses": row_statuses,
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    return errors, summary


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like JSON output path")
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
        "# AMR Beta Repo Intake Status",
        "",
        f"- ready_for_real_benchmark_audit: {payload['ready_for_real_benchmark_audit']}",
        f"- input_intake_sha256: {payload['input_intake_sha256']}",
        f"- valid_repo_rows: {payload['valid_repo_rows']}",
        f"- min_real_repos_required: {payload['min_real_repos_required']}",
        f"- repo_snapshot_lock_row_count: {payload['repo_snapshot_lock_row_count']}",
        f"- repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"- runs_audit: {payload['runs_audit']}",
        f"- runs_label_template_generation: {payload['runs_label_template_generation']}",
        f"- writes_reviewer_packets: {payload['writes_reviewer_packets']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- input_path_guard_passed: {payload['input_path_guard_passed']}",
        f"- output_path_guard_passed: {payload['output_path_guard_passed']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Rows",
        "",
        "| row | case_id | valid | clean_actual | expected_head | actual_head | errors |",
        "|---|---|---:|---:|---|---|---|",
    ]
    for status in payload["row_statuses"]:
        errors = "; ".join(str(error) for error in status["errors"])
        lines.append(
            "| {row_index} | {case_id} | {valid} | {clean_worktree_actual} | {expected} | {actual} | {errors} |".format(
                row_index=status["row_index"],
                case_id=status["case_id"],
                valid=status["valid"],
                clean_worktree_actual=status["clean_worktree_actual"],
                expected=status["expected_repo_git_head"],
                actual=status["actual_repo_git_head"],
                errors=errors,
            )
        )
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("intake", help="Filled Markdown or CSV repository-intake sheet.")
    parser.add_argument("--min-repos", type=int, default=MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--out-json", default="", help="Optional read-only status JSON output.")
    parser.add_argument("--out-md", default="", help="Optional read-only status Markdown output.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true", help="Print machine-readable summary JSON.")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    path = Path(args.intake).expanduser().resolve()
    try:
        rows = read_rows(path)
        row_errors, summary = validate_rows(rows, min_repos=args.min_repos)
        target_repo_paths = target_repo_paths_from_statuses(summary["row_statuses"])
        output_paths = {}
        if args.out_json:
            output_paths["out_json"] = Path(args.out_json).expanduser().resolve()
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        input_path_errors = validate_input_path(path, target_repo_paths)
        output_path_errors = validate_output_paths(output_paths, target_repo_paths)
        path_errors = [*input_path_errors, *output_path_errors]
        errors = [*row_errors, *path_errors]
        if path_errors:
            summary["ready_for_real_benchmark_audit"] = 0
        payload = {
            **summary,
            "input_intake": str(path),
            "input_intake_sha256": sha256_file(path),
            "input_path_guard_passed": int(not input_path_errors),
            "output_path_guard_passed": int(not output_path_errors),
            "errors": errors,
        }
        if args.out_json and not path_errors:
            write_json(output_paths["out_json"], payload, args.overwrite)
        if args.out_md and not path_errors:
            write_markdown(output_paths["out_md"], payload, args.overwrite)
    except Exception as exc:
        print(f"repo_intake_validate: error: {exc}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(
        "repo_intake_validate: ok "
        f"valid_repo_rows={summary['valid_repo_rows']} "
        f"min_real_repos_required={summary['min_real_repos_required']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
