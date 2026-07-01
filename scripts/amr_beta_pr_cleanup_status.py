#!/usr/bin/env python3
"""Validate AMR beta stage-0 PR cleanup and claim-freeze evidence.

This helper consumes an exported GitHub PR state file. It does not call GitHub,
does not close or merge PRs, and does not promote readiness. The intended input
is JSON or JSONL previously exported with `gh pr view ... --json ...`.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SCHEMA = "amr_beta_pr_cleanup_status.v1"
DEFAULT_CHECKLIST_PR = 46
DEFAULT_CHECKLIST_HEAD = "codex/amr-beta-human-input-checklist"
DEFAULT_STALE_PRS = [39, 40, 10, 5]
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
READY_PROMOTION_RE = re.compile(
    r"(?<![A-Za-z0-9_.-])[\"']?("
    r"design_partner_beta_candidate_ready|"
    r"release_ready|"
    r"public_comparison_claim_ready|"
    r"real_model_execution_ready"
    r")[\"']?\s*[:=]\s*(?:[\"']?1[\"']?|true)\b"
)


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def truthy(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    return str(value or "").strip().lower() in {"1", "true", "yes", "y"}


def pr_number(row: dict) -> int | None:
    raw = row.get("number")
    if isinstance(raw, bool):
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def pr_state(row: dict) -> str:
    return str(row.get("state") or "").strip().upper()


def pr_closed(row: dict) -> bool:
    return pr_state(row) in {"CLOSED", "MERGED"} or truthy(row.get("closed"))


def pr_closed_without_merge(row: dict) -> bool:
    return pr_state(row) == "CLOSED" and not bool(str(row.get("mergedAt") or "").strip())


def pr_merged(row: dict) -> bool:
    return pr_state(row) == "MERGED" or bool(str(row.get("mergedAt") or "").strip())


def load_pr_rows(path: Path) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError("refusing to read .env-like PR state path")
    text = path.read_text(encoding="utf-8")
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        rows: list[dict] = []
        for line_number, line in enumerate(text.splitlines(), start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSONL at line {line_number}: {exc}") from exc
            if not isinstance(row, dict):
                raise ValueError(f"PR state JSONL line {line_number} must contain an object")
            rows.append(row)
        return rows

    if isinstance(payload, list):
        rows = payload
    elif isinstance(payload, dict):
        rows = None
        for key in ["pull_requests", "prs", "pr_states", "items", "nodes"]:
            value = payload.get(key)
            if isinstance(value, list):
                rows = value
                break
        if rows is None and "number" in payload:
            rows = [payload]
        if rows is None:
            raise ValueError("PR state JSON object must contain a PR list or a single PR object")
    else:
        raise ValueError("PR state file must contain a JSON list, object, or JSONL objects")

    if not all(isinstance(row, dict) for row in rows):
        raise ValueError("every PR state entry must be an object")
    return rows


def validate_checklist_pr(
    rows_by_number: dict[int, dict],
    *,
    checklist_pr: int,
    checklist_head: str,
    base_branch: str,
) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    row = rows_by_number.get(checklist_pr)
    if row is None:
        return [f"checklist PR #{checklist_pr} missing from PR state export"], {
            "checklist_pr_number": checklist_pr,
            "checklist_pr_merged": 0,
            "checklist_pr_state": "missing",
            "checklist_pr_url": "",
        }

    state = pr_state(row)
    head = str(row.get("headRefName") or "").strip()
    base = str(row.get("baseRefName") or "").strip()
    if not pr_merged(row):
        errors.append(f"checklist PR #{checklist_pr} must be merged")
    if checklist_head and head != checklist_head:
        errors.append(f"checklist PR #{checklist_pr} headRefName must be {checklist_head}")
    if base_branch and base != base_branch:
        errors.append(f"checklist PR #{checklist_pr} baseRefName must be {base_branch}")

    return errors, {
        "checklist_pr_number": checklist_pr,
        "checklist_pr_merged": int(not errors),
        "checklist_pr_state": state,
        "checklist_pr_head": head,
        "checklist_pr_base": base,
        "checklist_pr_url": str(row.get("url") or ""),
        "checklist_pr_merged_at": str(row.get("mergedAt") or ""),
        "checklist_pr_closed_at": str(row.get("closedAt") or ""),
    }


def validate_stale_prs(rows_by_number: dict[int, dict], stale_prs: list[int]) -> tuple[list[str], list[dict]]:
    errors: list[str] = []
    statuses: list[dict] = []
    for number in stale_prs:
        row = rows_by_number.get(number)
        if row is None:
            errors.append(f"stale PR #{number} missing from PR state export")
            statuses.append(
                {
                    "number": number,
                    "state": "missing",
                    "closed": 0,
                    "closed_without_merge": 0,
                    "url": "",
                }
            )
            continue
        state = pr_state(row)
        closed = pr_closed(row)
        closed_without_merge = pr_closed_without_merge(row)
        closed_at = str(row.get("closedAt") or "")
        merged_at = str(row.get("mergedAt") or "")
        if not closed_without_merge:
            errors.append(f"stale PR #{number} must be closed without merging")
        if state == "OPEN":
            errors.append(f"stale PR #{number} must not remain open")
        if pr_merged(row):
            errors.append(f"stale PR #{number} must not be merged")
        if closed and not (closed_at or merged_at):
            errors.append(f"stale PR #{number} must include closedAt or mergedAt")
        statuses.append(
            {
                "number": number,
                "state": state,
                "closed": int(closed),
                "closed_without_merge": int(closed_without_merge),
                "closed_at": closed_at,
                "merged_at": merged_at,
                "head": str(row.get("headRefName") or ""),
                "base": str(row.get("baseRefName") or ""),
                "url": str(row.get("url") or ""),
            }
        )
    return errors, statuses


def scan_claim_files(paths: list[str]) -> tuple[list[str], list[dict], list[dict]]:
    errors: list[str] = []
    hits: list[dict] = []
    claim_files: list[dict] = []
    for raw_path in paths:
        path = Path(raw_path).expanduser().resolve()
        if is_forbidden_env_path(path):
            errors.append(f"claim file must not be .env-like: {path}")
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except Exception as exc:
            errors.append(f"claim file unreadable: {path}: {exc}")
            continue
        claim_files.append({"path": str(path), "sha256": sha256_file(path)})
        for line_number, line in enumerate(lines, start=1):
            match = READY_PROMOTION_RE.search(line)
            if not match:
                continue
            key = match.group(1)
            hits.append({"path": str(path), "line": line_number, "key": key})
            errors.append(f"claim freeze violation: {key}=1 in {path}:{line_number}")
    return errors, hits, claim_files


def validate_output_paths(outputs: dict[str, Path], inputs: dict[str, Path]) -> list[str]:
    errors: list[str] = []
    seen_outputs: dict[Path, str] = {}
    resolved_inputs = {name: path.resolve() for name, path in inputs.items()}
    for name, path in outputs.items():
        resolved = path.resolve()
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen_outputs:
            errors.append(f"{name} must not reuse {seen_outputs[resolved]} path: {resolved}")
        seen_outputs[resolved] = name
        for input_name, input_path in resolved_inputs.items():
            if resolved == input_path:
                errors.append(f"{name} must not overwrite {input_name}: {resolved}")
    return errors


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like JSON output path")
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# AMR Beta PR Cleanup Status",
        "",
        f"- stage_0_claim_freeze_verified: {payload['stage_0_claim_freeze_verified']}",
        f"- checklist_pr_number: {payload['checklist_pr_number']}",
        f"- checklist_pr_merged: {payload['checklist_pr_merged']}",
        f"- stale_prs_closed: {payload['stale_prs_closed']}",
        f"- stale_pr_closed_count: {payload['stale_pr_closed_count']}",
        f"- claim_freeze_scan_passed: {payload['claim_freeze_scan_passed']}",
        f"- claim_scan_file_count: {payload['claim_scan_file_count']}",
        f"- claim_scan_blocked_promotions: {payload['claim_scan_blocked_promotions']}",
        f"- runs_github_mutation: {payload['runs_github_mutation']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Stale PRs",
        "",
        "| number | state | closed | url |",
        "|---:|---|---:|---|",
    ]
    for row in payload["stale_pr_statuses"]:
        lines.append(f"| {row['number']} | {row['state']} | {row['closed']} | {row['url']} |")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pr-state", required=True, help="JSON or JSONL exported PR state.")
    parser.add_argument("--checklist-pr", type=int, default=DEFAULT_CHECKLIST_PR)
    parser.add_argument("--checklist-head", default=DEFAULT_CHECKLIST_HEAD)
    parser.add_argument("--base-branch", default="main")
    parser.add_argument("--stale-pr", action="append", type=int, default=[])
    parser.add_argument("--claim-file", action="append", default=[])
    parser.add_argument("--require-claim-scan", action="store_true")
    parser.add_argument("--out-json", default="")
    parser.add_argument("--out-md", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    pr_state_path = Path(args.pr_state).expanduser().resolve()
    stale_prs = args.stale_pr or DEFAULT_STALE_PRS
    try:
        rows = load_pr_rows(pr_state_path)
        rows_by_number = {number: row for row in rows if (number := pr_number(row)) is not None}
        duplicate_numbers = [number for number in rows_by_number if sum(1 for row in rows if pr_number(row) == number) > 1]
        checklist_errors, checklist_summary = validate_checklist_pr(
            rows_by_number,
            checklist_pr=args.checklist_pr,
            checklist_head=args.checklist_head,
            base_branch=args.base_branch,
        )
        stale_errors, stale_statuses = validate_stale_prs(rows_by_number, stale_prs)
        claim_errors, claim_hits, claim_files = scan_claim_files(args.claim_file)
        errors = [*checklist_errors, *stale_errors, *claim_errors]
        if duplicate_numbers:
            errors.extend(f"duplicate PR #{number} in PR state export" for number in sorted(set(duplicate_numbers)))
        if not args.claim_file:
            errors.append("at least one --claim-file is required to verify claim freeze")
        output_paths = {}
        if args.out_json:
            output_paths["out_json"] = Path(args.out_json).expanduser().resolve()
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        input_paths = {"pr_state": pr_state_path}
        for index, raw_claim_file in enumerate(args.claim_file, start=1):
            input_paths[f"claim_file[{index}]"] = Path(raw_claim_file).expanduser().resolve()
        output_path_errors = validate_output_paths(output_paths, input_paths)
        errors.extend(output_path_errors)

        stale_closed_count = sum(1 for row in stale_statuses if row["closed_without_merge"] == 1)
        summary = {
            "schema": SCHEMA,
            "input_pr_state": str(pr_state_path),
            "input_pr_state_sha256": sha256_file(pr_state_path),
            "pr_state_rows": len(rows),
            **checklist_summary,
            "stale_pr_numbers": stale_prs,
            "stale_pr_closed_count": stale_closed_count,
            "stale_prs_closed": int(stale_closed_count == len(stale_prs) and not stale_errors),
            "stale_pr_statuses": stale_statuses,
            "claim_scan_file_count": len(args.claim_file),
            "claim_scan_files": claim_files,
            "claim_scan_blocked_promotions": len(claim_hits),
            "claim_scan_hits": claim_hits,
            "claim_freeze_scan_passed": int(not claim_errors and bool(args.claim_file)),
            "output_path_guard_passed": int(not output_path_errors),
            "stage_0_claim_freeze_verified": int(not errors),
            "reads_pr_state_export": 1,
            "runs_github_query": 0,
            "runs_github_mutation": 0,
            "runs_git_push": 0,
            "creates_benchmark_evidence": 0,
            **BLOCKED_FLAGS,
            "errors": errors,
        }
        if args.out_json and not errors:
            write_json(Path(args.out_json).expanduser().resolve(), summary, args.overwrite)
        if args.out_md and not errors:
            write_markdown(Path(args.out_md).expanduser().resolve(), summary, args.overwrite)
    except Exception as exc:
        print(f"pr_cleanup_status: error: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(
        "pr_cleanup_status: ok "
        f"checklist_pr={summary['checklist_pr_number']} "
        f"stale_pr_closed_count={summary['stale_pr_closed_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
