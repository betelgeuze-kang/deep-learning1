#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO = "betelgeuze-kang/deep-learning1"
REQUIRED_LABELS = [
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
EXPECTED_PRS = {
    5: {
        "title": "Draft: harden v50 auditor correctness replay contract",
        "is_draft": False,
        "head_ref": "pr2-slice-v50-auditor-correctness",
    },
    10: {
        "title": "Draft: keep v56 expanded benchmark replay blocked",
        "is_draft": True,
        "head_ref": "pr2-slice-v56-ruler-longbench-expanded",
    },
}
ISSUE_BODY_ANCHORS = {
    "[P0] v53 frozen benchmark canonicalization": [
        "## Scope",
        "v53 benchmark",
        "## Target Readiness Transition",
        "fixture -> real execution",
        "## Required Artifacts",
        "## Claim Boundary",
        "Blocked claims:",
        "## Verification",
    ],
    "[P0] D/E 30B-70B real evidence intake": [
        "## Scope",
        "D/E baseline",
        "fixture -> real execution",
        "model identity and sha256 manifests",
        "Blocked claims:",
        "30B-150B public comparison wording",
    ],
    "[P1] v54 real free-running generation": [
        "## Scope",
        "v54 generation",
        "fixture -> real execution",
        "real free-running generation output packet",
        "Blocked claims:",
        "actual model generation readiness",
    ],
    "[P1] v58 blind human review execution": [
        "## Scope",
        "v58 blind evaluation",
        "heldout -> human review",
        "human review rows",
        "Blocked claims:",
        "blind human review readiness",
    ],
    "[P2] v61 one-token logits parity": [
        "## Scope",
        "v61 SSD-MoE",
        "fixture -> real execution",
        "one-token logits parity contract output",
        "Blocked claims:",
        "checkpoint payloads must remain out of git",
    ],
}
PR_COMMENT_ANCHORS = {
    5: [
        "PR #5 Cleanup Comment Draft",
        "durable contract/schema/test",
        "external auditor correctness evidence",
        "real auditor correctness readiness",
    ],
    10: [
        "PR #10 Cleanup Comment Draft",
        "durable v56 replay contract",
        "expanded replay evidence",
        "leaderboard, expanded benchmark readiness, or public comparison",
    ],
}


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def load_json(path: Path, errors: list[str]) -> Any:
    if not path.is_file():
        add(errors, f"missing JSON file: {path}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add(errors, f"{path}: invalid JSON: {exc}")
        return None


def label_names(labels: Any) -> set[str]:
    names: set[str] = set()
    if not isinstance(labels, list):
        return names
    for label in labels:
        if isinstance(label, str):
            names.add(label)
        elif isinstance(label, dict) and isinstance(label.get("name"), str):
            names.add(label["name"])
    return names


def enabled_value(payload: dict[str, Any], key: str) -> bool | None:
    value = payload.get(key)
    if isinstance(value, dict):
        enabled = value.get("enabled")
        return enabled if isinstance(enabled, bool) else None
    if isinstance(value, bool):
        return value
    return None


def status_check_names(status_checks: Any) -> set[str]:
    names: set[str] = set()
    if not isinstance(status_checks, dict):
        return names
    contexts = status_checks.get("contexts")
    if isinstance(contexts, list):
        names.update(str(context) for context in contexts if isinstance(context, str))
    checks = status_checks.get("checks")
    if isinstance(checks, list):
        for check in checks:
            if not isinstance(check, dict):
                continue
            for field in ["context", "name"]:
                value = check.get(field)
                if isinstance(value, str):
                    names.add(value)
    return names


def verify_branch_protection_complete(protection: dict[str, Any], errors: list[str]) -> None:
    if protection.get("status") != "available":
        add(errors, "branch protection must be available and configured in complete mode")
        return

    reviews = protection.get("required_pull_request_reviews")
    if not isinstance(reviews, dict):
        add(errors, "branch protection must require pull request reviews in complete mode")
    else:
        review_count = reviews.get("required_approving_review_count")
        if not isinstance(review_count, int) or review_count < 1:
            add(errors, "branch protection must require at least one approving review in complete mode")

    names = status_check_names(protection.get("required_status_checks"))
    if not ({"AI verify", "pr-safe-ai-verify.sh"} & names):
        add(errors, "branch protection must require AI verify status check in complete mode")

    if enabled_value(protection, "required_conversation_resolution") is not True:
        add(errors, "branch protection must require conversation resolution in complete mode")
    if enabled_value(protection, "allow_force_pushes") is not False:
        add(errors, "branch protection must block force pushes in complete mode")
    if enabled_value(protection, "allow_deletions") is not False:
        add(errors, "branch protection must block branch deletion in complete mode")


def expected_issue_drafts(root: Path, errors: list[str]) -> dict[str, set[str]]:
    payload = load_json(root / "docs/pm/github_issue_drafts.json", errors)
    if not isinstance(payload, dict):
        return {}
    issues = payload.get("issues")
    if not isinstance(issues, list):
        add(errors, "docs/pm/github_issue_drafts.json missing issues list")
        return {}
    expected: dict[str, set[str]] = {}
    for issue in issues:
        if not isinstance(issue, dict):
            add(errors, f"invalid issue draft row: {issue!r}")
            continue
        title = issue.get("title")
        labels = issue.get("labels")
        if not isinstance(title, str) or not isinstance(labels, list):
            add(errors, f"invalid issue draft fields: {issue!r}")
            continue
        expected[title] = {str(label) for label in labels}
    return expected


def verify_common(snapshot: Any, settings: Any, errors: list[str]) -> None:
    if not isinstance(snapshot, dict):
        add(errors, "github external state snapshot must be an object")
        return
    if not isinstance(settings, dict):
        add(errors, "github settings snapshot must be an object")
        return
    for label, payload in [
        ("github external state snapshot", snapshot),
        ("github settings snapshot", settings),
    ]:
        if payload.get("repository") != REPO:
            add(errors, f"{label} repository must be {REPO}")
        if payload.get("read_only") is not True:
            add(errors, f"{label} read_only must be true")
        generated_by = payload.get("generated_by")
        if generated_by != "scripts/refresh_github_external_snapshots.py":
            add(errors, f"{label} generated_by mismatch: {generated_by!r}")
        if not payload.get("observed_at"):
            add(errors, f"{label} missing observed_at")
    if snapshot.get("required_labels") != REQUIRED_LABELS:
        add(errors, "github external state snapshot required_labels drifted")

    workflow = settings.get("workflow_permissions", {})
    if not isinstance(workflow, dict):
        add(errors, "workflow_permissions must be an object")
    else:
        if workflow.get("default_workflow_permissions") != "read":
            add(errors, "default GITHUB_TOKEN workflow permission must be read")
        if workflow.get("can_approve_pull_request_reviews") is not False:
            add(errors, "workflow PR approval permission must be false")
    actions = settings.get("actions_permissions", {})
    if not isinstance(actions, dict):
        add(errors, "actions_permissions must be an object")
    else:
        if actions.get("enabled") is not True:
            add(errors, "GitHub Actions must be enabled")
        if "sha_pinning_required" not in actions:
            add(errors, "actions_permissions missing sha_pinning_required")


def verify_expected_prs(
    snapshot: dict[str, Any],
    *,
    require_cleanup_comment: bool,
    require_open: bool,
    errors: list[str],
) -> None:
    prs = snapshot.get("prs")
    if not isinstance(prs, list):
        add(errors, "github external state snapshot prs must be a list")
        return
    by_number = {
        row.get("number"): row
        for row in prs
        if isinstance(row, dict) and isinstance(row.get("number"), int)
    }
    for number, expected in EXPECTED_PRS.items():
        row = by_number.get(number)
        if not row:
            add(errors, f"missing PR #{number} in github external state snapshot")
            continue
        for field, value in expected.items():
            if row.get(field) != value:
                add(errors, f"PR #{number} {field} must be {value!r}")
        if row.get("base_ref") != "main":
            add(errors, f"PR #{number} base_ref must be main")
        if require_open and row.get("state") != "OPEN":
            add(errors, f"PR #{number} state must remain OPEN until separately approved")
        cleanup_present = row.get("cleanup_comment_present")
        if require_cleanup_comment and cleanup_present is not True:
            add(errors, f"PR #{number} cleanup comment must be present")
        if require_cleanup_comment:
            checks = row.get("cleanup_comment_anchor_checks")
            if not isinstance(checks, dict):
                add(errors, f"PR #{number} cleanup_comment_anchor_checks must be an object")
            else:
                for anchor in PR_COMMENT_ANCHORS[number]:
                    if checks.get(anchor) is not True:
                        add(errors, f"PR #{number} cleanup comment missing anchor: {anchor}")
        if not require_cleanup_comment and cleanup_present is not False:
            add(errors, f"PR #{number} cleanup comment should still be absent in pending mode")


def verify_pr_final_dispositions(snapshot: dict[str, Any], errors: list[str]) -> None:
    prs = snapshot.get("prs")
    if not isinstance(prs, list):
        add(errors, "github external state snapshot prs must be a list")
        return
    by_number = {
        row.get("number"): row
        for row in prs
        if isinstance(row, dict) and isinstance(row.get("number"), int)
    }
    for number in EXPECTED_PRS:
        row = by_number.get(number)
        if not row:
            continue
        state = row.get("state")
        if state not in {"CLOSED", "MERGED"}:
            add(errors, f"PR #{number} must be closed or merged in complete mode; got {state!r}")
        if state == "CLOSED" and "superseded" not in label_names(row.get("labels")):
            add(errors, f"PR #{number} closed cleanup must carry superseded label in complete mode")
    pending = snapshot.get("pr_cleanup_disposition_pending")
    if pending not in ([], None):
        add(errors, f"PR cleanup disposition still pending in complete mode: {pending!r}")


def verify_partial_issues(root: Path, snapshot: dict[str, Any], errors: list[str]) -> None:
    expected_issues = expected_issue_drafts(root, errors)
    issues = snapshot.get("open_issues")
    if not isinstance(issues, list):
        add(errors, "open_issues must be a list in partial mode")
        return
    by_title = {
        issue.get("title"): issue
        for issue in issues
        if isinstance(issue, dict) and isinstance(issue.get("title"), str)
    }
    missing_titles = [title for title in ISSUE_BODY_ANCHORS if title not in by_title]
    if snapshot.get("expected_issue_titles_missing") not in (None, missing_titles):
        add(errors, "expected_issue_titles_missing does not match observed partial issues")
    for title, issue in by_title.items():
        if title not in expected_issues:
            continue
        if issue.get("state") != "OPEN":
            add(errors, f"partial-mode expected issue must be open: {title}")
        observed_issue_labels = label_names(issue.get("labels"))
        missing_issue_labels = sorted(expected_issues[title] - observed_issue_labels)
        if missing_issue_labels:
            add(errors, f"{title} missing issue labels in partial mode: {missing_issue_labels}")
        checks = issue.get("body_anchor_checks")
        if not isinstance(checks, dict):
            add(errors, f"{title} body_anchor_checks must be an object in partial mode")
        else:
            for anchor in ISSUE_BODY_ANCHORS[title]:
                if checks.get(anchor) is not True:
                    add(errors, f"{title} missing issue body anchor in partial mode: {anchor}")


def verify_partial_prs(snapshot: dict[str, Any], errors: list[str]) -> None:
    prs = snapshot.get("prs")
    if not isinstance(prs, list):
        add(errors, "github external state snapshot prs must be a list in partial mode")
        return
    pending_numbers: list[int] = []
    by_number = {
        row.get("number"): row
        for row in prs
        if isinstance(row, dict) and isinstance(row.get("number"), int)
    }
    for number, expected in EXPECTED_PRS.items():
        row = by_number.get(number)
        if not row:
            add(errors, f"missing PR #{number} in partial-mode snapshot")
            continue
        for field, value in expected.items():
            if row.get(field) != value:
                add(errors, f"PR #{number} {field} must be {value!r} in partial mode")
        if row.get("base_ref") != "main":
            add(errors, f"PR #{number} base_ref must be main in partial mode")
        state = row.get("state")
        if state == "OPEN":
            pending_numbers.append(number)
        elif state == "CLOSED":
            if "superseded" not in label_names(row.get("labels")):
                add(errors, f"PR #{number} closed cleanup must carry superseded label in partial mode")
        elif state != "MERGED":
            add(errors, f"PR #{number} unexpected state in partial mode: {state!r}")
        if row.get("cleanup_comment_present") is True:
            checks = row.get("cleanup_comment_anchor_checks")
            if not isinstance(checks, dict):
                add(errors, f"PR #{number} cleanup_comment_anchor_checks must be an object in partial mode")
            else:
                for anchor in PR_COMMENT_ANCHORS[number]:
                    if checks.get(anchor) is not True:
                        add(errors, f"PR #{number} cleanup comment missing anchor in partial mode: {anchor}")
    pending = snapshot.get("pr_cleanup_disposition_pending")
    if pending not in (None, pending_numbers):
        add(errors, f"partial-mode PR cleanup pending list mismatch: {pending!r} != {pending_numbers!r}")


def verify_partial_settings(settings: dict[str, Any], errors: list[str]) -> None:
    deltas = settings.get("settings_deltas")
    if not isinstance(deltas, list):
        add(errors, "settings_deltas must be a list in partial mode")
        return
    by_setting = {
        row.get("setting"): row
        for row in deltas
        if isinstance(row, dict) and isinstance(row.get("setting"), str)
    }

    repo = settings.get("repo", {})
    workflow = settings.get("workflow_permissions", {})
    actions = settings.get("actions_permissions", {})
    protection = settings.get("branch_protection", {})
    security = settings.get("security_features", {})
    if not isinstance(repo, dict):
        add(errors, "settings repo must be an object in partial mode")
        repo = {}
    if not isinstance(workflow, dict):
        add(errors, "workflow_permissions must be an object in partial mode")
        workflow = {}
    if not isinstance(actions, dict):
        add(errors, "actions_permissions must be an object in partial mode")
        actions = {}
    if not isinstance(protection, dict):
        add(errors, "branch_protection must be an object in partial mode")
        protection = {}
    if not isinstance(security, dict):
        add(errors, "security_features must be an object in partial mode")
        security = {}

    merge_methods = []
    if repo.get("allow_squash_merge"):
        merge_methods.append("squash")
    if repo.get("allow_merge_commit"):
        merge_methods.append("merge-commit")
    if repo.get("allow_rebase_merge"):
        merge_methods.append("rebase")
    branch_errors: list[str] = []
    verify_branch_protection_complete(protection, branch_errors)
    codeql = security.get("codeql_default_setup", {})
    secret_scanning = security.get("secret_scanning", {})
    dependency_graph = security.get("dependency_graph", {})
    vulnerability_alerts = security.get("vulnerability_alerts", {})
    dependabot_alerts = security.get("dependabot_alerts", {})
    expected_pending = {
        "Automatically delete head branches": repo.get("delete_branch_on_merge") is not True,
        "Default GITHUB_TOKEN permission": workflow.get("default_workflow_permissions") != "read",
        "Require full SHA-pinned Actions": actions.get("sha_pinning_required") is not True,
        "Merge method": merge_methods != ["squash"],
        "Branch protection": bool(branch_errors),
        "CodeQL default setup": not isinstance(codeql, dict) or codeql.get("configured") is not True,
        "Secret scanning": not isinstance(secret_scanning, dict) or secret_scanning.get("enabled") is not True,
        "Dependency graph and Dependabot alerts": not (
            isinstance(dependency_graph, dict)
            and dependency_graph.get("enabled") is True
            and isinstance(vulnerability_alerts, dict)
            and vulnerability_alerts.get("enabled") is True
            and isinstance(dependabot_alerts, dict)
            and dependabot_alerts.get("enabled") is True
        ),
    }
    for setting, expected in expected_pending.items():
        row = by_setting.get(setting)
        if not row:
            add(errors, f"missing settings delta in partial mode: {setting}")
            continue
        action_pending = row.get("action_pending")
        if not isinstance(action_pending, bool):
            add(errors, f"{setting} action_pending must be boolean in partial mode")
            continue
        if action_pending is not expected:
            add(errors, f"{setting} action_pending must be {expected} in partial mode")


def verify_partial(root: Path, snapshot: dict[str, Any], settings: dict[str, Any], errors: list[str]) -> None:
    observed_labels = set(snapshot.get("remote_labels_observed", []))
    missing_labels = [label for label in REQUIRED_LABELS if label not in observed_labels]
    if snapshot.get("required_labels_missing") != missing_labels:
        add(errors, "required_labels_missing does not match observed remote labels in partial mode")
    verify_partial_issues(root, snapshot, errors)
    verify_partial_prs(snapshot, errors)
    verify_partial_settings(settings, errors)


def verify_pending(root: Path, snapshot: dict[str, Any], settings: dict[str, Any], errors: list[str]) -> None:
    del root
    if snapshot.get("external_mutation_still_pending") is not True:
        add(errors, "external_mutation_still_pending must be true in pending mode")
    if snapshot.get("open_issues") != []:
        add(errors, "open_issues must be empty in pending mode")
    if snapshot.get("required_labels_missing") != REQUIRED_LABELS:
        add(errors, "all required labels must be missing in pending mode")
    expected_missing = snapshot.get("expected_issue_titles_missing")
    if expected_missing not in (None, list(ISSUE_BODY_ANCHORS)):
        add(errors, "all expected issue titles should still be missing in pending mode")
    pending_dispositions = snapshot.get("pr_cleanup_disposition_pending")
    if pending_dispositions not in (None, [5, 10]):
        add(errors, "PR cleanup dispositions should still be pending for PR #5 and PR #10 in pending mode")
    verify_expected_prs(snapshot, require_cleanup_comment=False, require_open=True, errors=errors)

    repo = settings.get("repo", {})
    if not isinstance(repo, dict):
        add(errors, "settings repo must be an object")
        return
    if repo.get("delete_branch_on_merge") is not False:
        add(errors, "delete_branch_on_merge should still be false in pending mode")
    deltas = {
        row.get("setting"): row
        for row in settings.get("settings_deltas", [])
        if isinstance(row, dict)
    }
    expected_pending = {
        "Automatically delete head branches": True,
        "Default GITHUB_TOKEN permission": False,
        "Require full SHA-pinned Actions": True,
        "Merge method": True,
        "Branch protection": True,
    }
    for setting, pending in expected_pending.items():
        row = deltas.get(setting)
        if not row:
            add(errors, f"missing settings delta: {setting}")
            continue
        if row.get("action_pending") is not pending:
            add(errors, f"{setting} action_pending must be {pending} in pending mode")


def verify_complete(root: Path, snapshot: dict[str, Any], settings: dict[str, Any], errors: list[str]) -> None:
    expected_issues = expected_issue_drafts(root, errors)
    observed_labels = set(snapshot.get("remote_labels_observed", []))
    missing_labels = [label for label in REQUIRED_LABELS if label not in observed_labels]
    if missing_labels:
        add(errors, f"required labels still missing in complete mode: {missing_labels}")
    if snapshot.get("required_labels_missing") not in ([], missing_labels):
        add(errors, "required_labels_missing does not match observed remote labels")

    issues = snapshot.get("open_issues")
    if not isinstance(issues, list):
        add(errors, "open_issues must be a list in complete mode")
        issues = []
    by_title = {
        issue.get("title"): issue
        for issue in issues
        if isinstance(issue, dict) and isinstance(issue.get("title"), str)
    }
    for title, required_issue_labels in expected_issues.items():
        issue = by_title.get(title)
        if not issue:
            add(errors, f"missing expected GitHub issue in complete mode: {title}")
            continue
        if issue.get("state") != "OPEN":
            add(errors, f"expected issue must be open: {title}")
        observed_issue_labels = label_names(issue.get("labels"))
        missing_issue_labels = sorted(required_issue_labels - observed_issue_labels)
        if missing_issue_labels:
            add(errors, f"{title} missing issue labels: {missing_issue_labels}")
        checks = issue.get("body_anchor_checks")
        if not isinstance(checks, dict):
            add(errors, f"{title} body_anchor_checks must be an object")
        else:
            for anchor in ISSUE_BODY_ANCHORS[title]:
                if checks.get(anchor) is not True:
                    add(errors, f"{title} missing issue body anchor: {anchor}")

    verify_expected_prs(snapshot, require_cleanup_comment=True, require_open=False, errors=errors)
    verify_pr_final_dispositions(snapshot, errors)

    repo = settings.get("repo", {})
    if not isinstance(repo, dict):
        add(errors, "settings repo must be an object")
    else:
        if repo.get("delete_branch_on_merge") is not True:
            add(errors, "delete_branch_on_merge must be true in complete mode")
        merge_methods_enabled = [
            bool(repo.get("allow_squash_merge")),
            bool(repo.get("allow_merge_commit")),
            bool(repo.get("allow_rebase_merge")),
        ]
        if merge_methods_enabled != [True, False, False]:
            add(errors, "complete mode expects only squash merge enabled")

    protection = settings.get("branch_protection", {})
    if not isinstance(protection, dict):
        add(errors, "branch_protection must be an object")
    else:
        verify_branch_protection_complete(protection, errors)

    actions = settings.get("actions_permissions", {})
    if not isinstance(actions, dict):
        add(errors, "actions_permissions must be an object in complete mode")
    elif actions.get("sha_pinning_required") is not True:
        add(errors, "full SHA-pinned Actions must be required in complete mode")

    security = settings.get("security_features")
    if not isinstance(security, dict):
        add(errors, "security_features must be an object in complete mode")
    else:
        codeql = security.get("codeql_default_setup")
        if not isinstance(codeql, dict) or codeql.get("configured") is not True:
            add(errors, "CodeQL default setup must be configured in complete mode")
        secret_scanning = security.get("secret_scanning")
        if not isinstance(secret_scanning, dict) or secret_scanning.get("enabled") is not True:
            add(errors, "secret scanning must be enabled in complete mode")
        dependency_graph = security.get("dependency_graph")
        if not isinstance(dependency_graph, dict) or dependency_graph.get("enabled") is not True:
            add(errors, "dependency graph must be enabled in complete mode")
        vulnerability_alerts = security.get("vulnerability_alerts")
        if not isinstance(vulnerability_alerts, dict) or vulnerability_alerts.get("enabled") is not True:
            add(errors, "vulnerability alerts must be enabled in complete mode")
        dependabot_alerts = security.get("dependabot_alerts")
        if not isinstance(dependabot_alerts, dict) or dependabot_alerts.get("enabled") is not True:
            add(errors, "Dependabot alerts must be enabled in complete mode")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--mode", choices=["pending", "partial", "complete"], required=True)
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    errors: list[str] = []
    snapshot = load_json(root / "docs/pm/github_external_state_snapshot.json", errors)
    settings = load_json(root / "docs/pm/github_settings_external_snapshot.json", errors)
    verify_common(snapshot, settings, errors)
    if isinstance(snapshot, dict) and isinstance(settings, dict):
        if args.mode == "pending":
            verify_pending(root, snapshot, settings, errors)
        elif args.mode == "partial":
            verify_partial(root, snapshot, settings, errors)
        else:
            verify_complete(root, snapshot, settings, errors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"github external state verify ok ({args.mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
