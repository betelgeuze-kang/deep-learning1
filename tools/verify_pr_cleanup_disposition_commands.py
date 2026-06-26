#!/usr/bin/env python3
from __future__ import annotations

import shlex
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = "betelgeuze-kang/deep-learning1"
DOC = ROOT / "docs" / "pm" / "PR_CLEANUP_DISPOSITION_COMMANDS.md"
EXPECTED_COMMANDS = [
    ["gh", "pr", "edit", "5", "--repo", REPO, "--add-label", "superseded"],
    ["gh", "pr", "close", "5", "--repo", REPO],
    ["gh", "pr", "edit", "10", "--repo", REPO, "--add-label", "superseded"],
    ["gh", "pr", "close", "10", "--repo", REPO],
]


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def extract_gh_commands(errors: list[str]) -> list[list[str]]:
    if not DOC.is_file():
        add(errors, f"missing {DOC.relative_to(ROOT)}")
        return []
    text = DOC.read_text(encoding="utf-8")
    for snippet in [
        "## Batch E: Superseded-Close PR Disposition",
        "This file belongs only to Batch E",
        "Approval for labels, issues, or",
        "PR cleanup comments does not approve these close commands.",
        "The expected Batch E postcondition",
        "pr_cleanup_disposition_pending` is empty",
    ]:
        if snippet not in text:
            add(errors, f"{DOC.relative_to(ROOT)} missing snippet: {snippet}")
    commands: list[list[str]] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line.startswith("gh "):
            continue
        try:
            commands.append(shlex.split(line))
        except ValueError as exc:
            add(errors, f"invalid shell command {line!r}: {exc}")
    return commands


def verify_commands(commands: list[list[str]], errors: list[str]) -> None:
    if commands != EXPECTED_COMMANDS:
        add(errors, f"PR cleanup disposition commands drifted: {commands!r}")
        return
    for parts in commands:
        if parts[:3] not in (["gh", "pr", "edit"], ["gh", "pr", "close"]):
            add(errors, f"unexpected command family: {parts!r}")
        if parts[3] not in {"5", "10"}:
            add(errors, f"unexpected PR number: {parts!r}")
        if "--repo" not in parts:
            add(errors, f"missing --repo: {parts!r}")
        if parts[parts.index("--repo") + 1] != REPO:
            add(errors, f"repo mismatch: {parts!r}")
        forbidden = {"--delete-branch", "--admin", "--auto", "--merge", "--rebase", "--squash"}
        present_forbidden = forbidden.intersection(parts)
        if present_forbidden:
            add(errors, f"forbidden option in disposition command: {sorted(present_forbidden)}")
        if parts[:3] == ["gh", "pr", "edit"]:
            if parts[-2:] != ["--add-label", "superseded"]:
                add(errors, f"PR edit command must only add superseded label: {parts!r}")


def main(argv: list[str]) -> int:
    if argv:
        print("usage: tools/verify_pr_cleanup_disposition_commands.py", file=sys.stderr)
        return 2
    errors: list[str] = []
    commands = extract_gh_commands(errors)
    verify_commands(commands, errors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("pr cleanup disposition commands verify ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
