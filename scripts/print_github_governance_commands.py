#!/usr/bin/env python3
from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = "betelgeuze-kang/deep-learning1"


def q(value: str) -> str:
    return shlex.quote(value)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def emit_label_commands() -> None:
    labels = load_json_from_yaml_like(ROOT / ".github" / "labels.yml")
    print("# Batch B: labels")
    print("# Approval required: create/update labels only.")
    print("# Postcondition: required_labels_missing is empty after snapshot refresh.")
    for label in labels:
        name = label["name"]
        color = label["color"]
        description = label["description"]
        print(
            "gh label create "
            f"{q(name)} --repo {q(REPO)} --color {q(color)} "
            f"--description {q(description)} --force"
        )
    print()


def load_json_from_yaml_like(path: Path) -> list[dict[str, str]]:
    labels: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("- name: "):
            if current:
                labels.append(current)
            current = {"name": line.removeprefix("- name: ").strip()}
        elif line.startswith("  color: "):
            current["color"] = line.removeprefix("  color: ").strip()
        elif line.startswith("  description: "):
            current["description"] = line.removeprefix("  description: ").strip()
    if current:
        labels.append(current)
    for label in labels:
        for key in ["name", "color", "description"]:
            if key not in label:
                raise SystemExit(f"{path}: label missing {key}: {label}")
    return labels


def emit_issue_commands() -> None:
    drafts = load_json(ROOT / "docs" / "pm" / "github_issue_drafts.json")
    if not isinstance(drafts, dict) or not isinstance(drafts.get("issues"), list):
        raise SystemExit("docs/pm/github_issue_drafts.json has no issues array")
    body_by_title = {
        "[P0] v53 frozen benchmark canonicalization": ROOT / "docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md",
        "[P0] D/E 30B-70B real evidence intake": ROOT / "docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md",
        "[P1] v54 real free-running generation": ROOT / "docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md",
        "[P1] v58 blind human review execution": ROOT / "docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md",
        "[P2] v61 one-token logits parity": ROOT / "docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md",
    }
    print("# Batch C: evidence blocker issues")
    print("# Approval required: create the five evidence blocker issues only.")
    print("# Postcondition: expected issue titles and body anchors appear after snapshot refresh.")
    for issue in drafts["issues"]:
        if not isinstance(issue, dict):
            raise SystemExit(f"invalid issue draft: {issue!r}")
        title = issue.get("title")
        labels = issue.get("labels")
        if not isinstance(title, str) or not isinstance(labels, list):
            raise SystemExit(f"invalid issue draft fields: {issue!r}")
        body_path = body_by_title.get(title)
        if body_path is None:
            raise SystemExit(f"missing body path for issue title: {title}")
        label_arg = ",".join(str(label) for label in labels)
        print(
            "gh issue create "
            f"--repo {q(REPO)} --title {q(title)} "
            f"--label {q(label_arg)} --body-file {q(rel(body_path))}"
        )
    print()


def emit_pr_comment_commands() -> None:
    comments = [
        (5, ROOT / "docs/pm/pr_cleanup_comments/pr5-v50-cleanup-comment.md"),
        (10, ROOT / "docs/pm/pr_cleanup_comments/pr10-v56-cleanup-comment.md"),
    ]
    print("# Batch D: PR cleanup comments")
    print("# Approval required: comment on PR #5 and PR #10 only.")
    print("# Postcondition: cleanup comment anchors appear after snapshot refresh.")
    print("# This is not final PR cleanup disposition.")
    for number, body_path in comments:
        print(
            "gh pr comment "
            f"{number} --repo {q(REPO)} --body-file {q(rel(body_path))}"
        )
    print()


def main(argv: list[str]) -> int:
    batch = ""
    if argv:
        if len(argv) != 2 or argv[0] != "--batch" or argv[1] not in {"B", "C", "D"}:
            print("usage: scripts/print_github_governance_commands.py [--batch B|C|D]", file=sys.stderr)
            return 2
        batch = argv[1]
    if not batch:
        print("# Generated GitHub governance commands")
        print("# Review before running. These commands mutate GitHub state.")
        print("# Batches B, C, and D require separate explicit approval.")
        print("# This generator does not print PR close, merge, rebase, settings, or license commands.")
        print()
        emit_label_commands()
        emit_issue_commands()
        emit_pr_comment_commands()
        return 0

    print(f"# Generated GitHub governance commands for Batch {batch}")
    print("# Review before running. These commands mutate GitHub state.")
    print("# This batch requires explicit human approval.")
    print("# This generator does not print PR close, merge, rebase, settings, or license commands.")
    print()
    if batch == "B":
        emit_label_commands()
    elif batch == "C":
        emit_issue_commands()
    elif batch == "D":
        emit_pr_comment_commands()
    else:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
