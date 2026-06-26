#!/usr/bin/env python3
from __future__ import annotations

import json
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = "betelgeuze-kang/deep-learning1"
EXPECTED_LABELS = [
    "priority:P0",
    "priority:P1",
    "priority:P2",
    "type:architecture",
    "type:evidence",
    "type:security",
    "blocked:external-evidence",
    "blocked:human-review",
    "claim-boundary",
    "web-editable",
    "local-runtime-required",
    "superseded",
]
EXPECTED_ISSUE_BODY_FILES = [
    "docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md",
    "docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md",
    "docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md",
    "docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md",
    "docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md",
]
EXPECTED_PR_COMMENT_FILES = {
    "5": "docs/pm/pr_cleanup_comments/pr5-v50-cleanup-comment.md",
    "10": "docs/pm/pr_cleanup_comments/pr10-v56-cleanup-comment.md",
}
ISSUE_BODY_BY_TITLE = {
    "[P0] v53 frozen benchmark canonicalization": "docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md",
    "[P0] D/E 30B-70B real evidence intake": "docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md",
    "[P1] v54 real free-running generation": "docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md",
    "[P1] v58 blind human review execution": "docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md",
    "[P2] v61 one-token logits parity": "docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md",
}


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def generated_lines(errors: list[str], args: list[str] | None = None) -> list[str]:
    script = ROOT / "scripts" / "print_github_governance_commands.py"
    if not script.is_file():
        add(errors, "missing scripts/print_github_governance_commands.py")
        return []
    command = [sys.executable, str(script)]
    if args:
        command.extend(args)
    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        add(errors, "command generator failed: " + result.stderr.strip())
        return []
    return result.stdout.splitlines()


def load_issue_draft_labels(errors: list[str]) -> dict[str, set[str]]:
    path = ROOT / "docs" / "pm" / "github_issue_drafts.json"
    if not path.is_file():
        add(errors, "missing docs/pm/github_issue_drafts.json")
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add(errors, f"docs/pm/github_issue_drafts.json invalid JSON: {exc}")
        return {}
    if not isinstance(payload, dict) or not isinstance(payload.get("issues"), list):
        add(errors, "docs/pm/github_issue_drafts.json must contain an issues list")
        return {}
    by_title: dict[str, set[str]] = {}
    for issue in payload["issues"]:
        if not isinstance(issue, dict):
            add(errors, f"invalid issue draft row: {issue!r}")
            continue
        title = issue.get("title")
        labels = issue.get("labels")
        if not isinstance(title, str) or not isinstance(labels, list):
            add(errors, f"invalid issue draft fields: {issue!r}")
            continue
        by_title[title] = {str(label) for label in labels}
    if set(by_title) != set(ISSUE_BODY_BY_TITLE):
        add(errors, f"issue draft title set mismatch: {sorted(by_title)}")
    return by_title


def require_option(parts: list[str], option: str, command: str, errors: list[str]) -> str:
    if option not in parts:
        add(errors, f"{command}: missing option {option}")
        return ""
    index = parts.index(option)
    if index + 1 >= len(parts):
        add(errors, f"{command}: option {option} missing value")
        return ""
    return parts[index + 1]


def verify_body_file(path_text: str, expected: set[str], command: str, errors: list[str]) -> None:
    if path_text not in expected:
        add(errors, f"{command}: unexpected body-file {path_text}")
        return
    path = ROOT / path_text
    if not path.is_file():
        add(errors, f"{command}: body-file missing on disk: {path_text}")
        return
    if not path.read_text(encoding="utf-8").strip():
        add(errors, f"{command}: body-file is empty: {path_text}")


def verify_label_command(parts: list[str], seen_labels: set[str], errors: list[str]) -> None:
    command = " ".join(parts[:3])
    if len(parts) < 11:
        add(errors, f"{command}: too few arguments")
        return
    label = parts[3]
    seen_labels.add(label)
    if label not in EXPECTED_LABELS:
        add(errors, f"{command}: unexpected label {label}")
    if require_option(parts, "--repo", command, errors) != REPO:
        add(errors, f"{command}: repo must be {REPO}")
    color = require_option(parts, "--color", command, errors)
    if len(color) != 6 or any(ch not in "0123456789abcdefABCDEF" for ch in color):
        add(errors, f"{command}: color must be 6 hex chars")
    description = require_option(parts, "--description", command, errors)
    if not description:
        add(errors, f"{command}: description must be non-empty")
    if "--force" not in parts:
        add(errors, f"{command}: label command must use --force")


def verify_issue_command(
    parts: list[str],
    seen_issue_titles: set[str],
    seen_body_files: set[str],
    issue_draft_labels: dict[str, set[str]],
    errors: list[str],
) -> None:
    command = " ".join(parts[:3])
    if require_option(parts, "--repo", command, errors) != REPO:
        add(errors, f"{command}: repo must be {REPO}")
    title = require_option(parts, "--title", command, errors)
    if not title.startswith("[P"):
        add(errors, f"{command}: issue title should be priority-prefixed")
    seen_issue_titles.add(title)
    expected_body_file = ISSUE_BODY_BY_TITLE.get(title)
    if expected_body_file is None:
        add(errors, f"{command}: unexpected issue title {title}")
    labels = require_option(parts, "--label", command, errors)
    if not labels:
        add(errors, f"{command}: labels must be non-empty")
    observed_labels = {label.strip() for label in labels.split(",") if label.strip()}
    expected_labels = issue_draft_labels.get(title, set())
    if observed_labels != expected_labels:
        add(
            errors,
            f"{command}: labels for {title!r} must match draft; got {sorted(observed_labels)} expected {sorted(expected_labels)}",
        )
    unexpected_labels = observed_labels - set(EXPECTED_LABELS)
    if unexpected_labels:
        add(errors, f"{command}: issue command uses unknown labels: {sorted(unexpected_labels)}")
    body_file = require_option(parts, "--body-file", command, errors)
    if expected_body_file is not None and body_file != expected_body_file:
        add(errors, f"{command}: body-file for {title!r} must be {expected_body_file}")
    verify_body_file(body_file, set(EXPECTED_ISSUE_BODY_FILES), command, errors)
    seen_body_files.add(body_file)
    for forbidden_option in ["--web", "--assignee", "--milestone"]:
        if forbidden_option in parts:
            add(errors, f"{command}: forbidden option {forbidden_option}")


def verify_pr_comment_command(parts: list[str], seen_prs: set[str], errors: list[str]) -> None:
    command = " ".join(parts[:3])
    if len(parts) < 7:
        add(errors, f"{command}: too few arguments")
        return
    number = parts[3]
    if number not in EXPECTED_PR_COMMENT_FILES:
        add(errors, f"{command}: unexpected PR number {number}")
    seen_prs.add(number)
    if require_option(parts, "--repo", command, errors) != REPO:
        add(errors, f"{command}: repo must be {REPO}")
    body_file = require_option(parts, "--body-file", command, errors)
    expected = {EXPECTED_PR_COMMENT_FILES[number]} if number in EXPECTED_PR_COMMENT_FILES else set()
    verify_body_file(body_file, expected, command, errors)
    for forbidden_option in ["--edit-last", "--delete-last", "--web"]:
        if forbidden_option in parts:
            add(errors, f"{command}: forbidden option {forbidden_option}")


def check_section(section: str, expected: str, line: str, errors: list[str]) -> None:
    if section != expected:
        add(errors, f"{line}: command must appear under {expected}, got {section or 'no batch'}")


def verify_generated_output(lines: list[str], issue_draft_labels: dict[str, set[str]], expected_batches: list[str], errors: list[str]) -> None:
    required_by_batch = {
        "B": [
            "# Batch B: labels",
            "# Approval required: create/update labels only.",
            "# Postcondition: required_labels_missing is empty after snapshot refresh.",
        ],
        "C": [
            "# Batch C: evidence blocker issues",
            "# Approval required: create the five evidence blocker issues only.",
            "# Postcondition: expected issue titles and body anchors appear after snapshot refresh.",
        ],
        "D": [
            "# Batch D: PR cleanup comments",
            "# Approval required: comment on PR #5 and PR #10 only.",
            "# Postcondition: cleanup comment anchors appear after snapshot refresh.",
            "# This is not final PR cleanup disposition.",
        ],
    }
    for batch in expected_batches:
        for comment in required_by_batch[batch]:
            if comment not in lines:
                add(errors, f"generated command output missing comment: {comment}")

    seen_labels: set[str] = set()
    seen_issue_titles: set[str] = set()
    seen_issue_body_files: set[str] = set()
    seen_prs: set[str] = set()
    command_count = 0
    current_batch = ""
    observed_batch_order: list[str] = []
    batch_header_by_letter = {
        "B": "# Batch B: labels",
        "C": "# Batch C: evidence blocker issues",
        "D": "# Batch D: PR cleanup comments",
    }
    expected_batch_headers = [batch_header_by_letter[batch] for batch in expected_batches]
    for raw_line in lines:
        line = raw_line.strip()
        if line in set(batch_header_by_letter.values()):
            current_batch = line
            observed_batch_order.append(line)
            continue
        if not line or line.startswith("#"):
            continue
        parts = shlex.split(line)
        command_count += 1
        if parts[:3] == ["gh", "label", "create"]:
            check_section(current_batch, "# Batch B: labels", line, errors)
            verify_label_command(parts, seen_labels, errors)
        elif parts[:3] == ["gh", "issue", "create"]:
            check_section(current_batch, "# Batch C: evidence blocker issues", line, errors)
            verify_issue_command(parts, seen_issue_titles, seen_issue_body_files, issue_draft_labels, errors)
        elif parts[:3] == ["gh", "pr", "comment"]:
            check_section(current_batch, "# Batch D: PR cleanup comments", line, errors)
            verify_pr_comment_command(parts, seen_prs, errors)
        else:
            add(errors, f"unexpected generated command: {line}")

    if observed_batch_order != expected_batch_headers:
        add(errors, f"generated command batch order mismatch: {observed_batch_order!r}")

    expected_command_count = 0
    if "B" in expected_batches:
        expected_command_count += len(EXPECTED_LABELS)
        if seen_labels != set(EXPECTED_LABELS):
            add(errors, f"label command set mismatch: {sorted(seen_labels)}")
    elif seen_labels:
        add(errors, f"label commands appeared in unexpected batch output: {sorted(seen_labels)}")
    if "C" in expected_batches:
        expected_command_count += len(EXPECTED_ISSUE_BODY_FILES)
        if seen_issue_body_files != set(EXPECTED_ISSUE_BODY_FILES):
            add(errors, f"issue body-file command set mismatch: {sorted(seen_issue_body_files)}")
        if seen_issue_titles != set(ISSUE_BODY_BY_TITLE):
            add(errors, f"issue title command set mismatch: {sorted(seen_issue_titles)}")
    elif seen_issue_body_files or seen_issue_titles:
        add(errors, "issue commands appeared in unexpected batch output")
    if "D" in expected_batches:
        expected_command_count += len(EXPECTED_PR_COMMENT_FILES)
        if seen_prs != set(EXPECTED_PR_COMMENT_FILES):
            add(errors, f"PR comment command set mismatch: {sorted(seen_prs)}")
    elif seen_prs:
        add(errors, f"PR comment commands appeared in unexpected batch output: {sorted(seen_prs)}")
    if command_count != expected_command_count:
        add(errors, f"unexpected command count: {command_count}")


def main(argv: list[str]) -> int:
    if argv:
        print("usage: tools/verify_github_governance_commands.py", file=sys.stderr)
        return 2
    errors: list[str] = []
    lines = generated_lines(errors)
    required_comments = [
        "# Generated GitHub governance commands",
        "# Batches B, C, and D require separate explicit approval.",
        "# This generator does not print PR close, merge, rebase, settings, or license commands.",
        "# Batch B: labels",
        "# Approval required: create/update labels only.",
        "# Postcondition: required_labels_missing is empty after snapshot refresh.",
        "# Batch C: evidence blocker issues",
        "# Approval required: create the five evidence blocker issues only.",
        "# Postcondition: expected issue titles and body anchors appear after snapshot refresh.",
        "# Batch D: PR cleanup comments",
        "# Approval required: comment on PR #5 and PR #10 only.",
        "# Postcondition: cleanup comment anchors appear after snapshot refresh.",
        "# This is not final PR cleanup disposition.",
    ]
    for comment in required_comments:
        if comment not in lines:
            add(errors, f"generated command output missing comment: {comment}")
    issue_draft_labels = load_issue_draft_labels(errors)
    verify_generated_output(lines, issue_draft_labels, ["B", "C", "D"], errors)
    for batch in ["B", "C", "D"]:
        batch_lines = generated_lines(errors, ["--batch", batch])
        expected_header = f"# Generated GitHub governance commands for Batch {batch}"
        if expected_header not in batch_lines:
            add(errors, f"batch {batch} output missing header: {expected_header}")
        if "# This batch requires explicit human approval." not in batch_lines:
            add(errors, f"batch {batch} output missing explicit approval warning")
        verify_generated_output(batch_lines, issue_draft_labels, [batch], errors)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("github governance commands verify ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
