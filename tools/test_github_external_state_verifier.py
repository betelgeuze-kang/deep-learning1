#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VERIFIER = ROOT / "tools" / "verify_github_external_state.py"
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


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def issue_drafts() -> dict[str, Any]:
    return json.loads((ROOT / "docs/pm/github_issue_drafts.json").read_text(encoding="utf-8"))


def labels_for_title(title: str) -> list[str]:
    for issue in issue_drafts()["issues"]:
        if issue["title"] == title:
            return issue["labels"]
    raise AssertionError(f"missing issue draft title: {title}")


def pr_row(number: int, cleanup_present: bool, *, final_disposition: bool = False) -> dict[str, Any]:
    if number == 5:
        title = "Draft: harden v50 auditor correctness replay contract"
        is_draft = False
        head_ref = "pr2-slice-v50-auditor-correctness"
    elif number == 10:
        title = "Draft: keep v56 expanded benchmark replay blocked"
        is_draft = True
        head_ref = "pr2-slice-v56-ruler-longbench-expanded"
    else:
        raise AssertionError(number)
    checks = {
        anchor: cleanup_present
        for anchor in PR_COMMENT_ANCHORS[number]
    }
    state = "OPEN"
    if final_disposition:
        state = "MERGED" if number == 5 else "CLOSED"
    return {
        "number": number,
        "title": title,
        "state": state,
        "is_draft": is_draft,
        "mergeable": "MERGEABLE",
        "head_ref": head_ref,
        "base_ref": "main",
        "labels": ["superseded"] if state == "CLOSED" else [],
        "url": f"https://github.com/{REPO}/pull/{number}",
        "cleanup_comment_present": cleanup_present,
        "cleanup_comment_count": 1 if cleanup_present else 0,
        "cleanup_comment_anchor_checks": checks,
    }


def settings_snapshot(*, complete: bool) -> dict[str, Any]:
    security_features = {
        "codeql_default_setup": {
            "endpoint": f"repos/{REPO}/code-scanning/default-setup",
            "status": "available" if complete else "unavailable",
            "http_status": 200 if complete else 403,
            "state": "configured" if complete else None,
            "configured": complete,
            "reason": "" if complete else "Code scanning is not enabled for this repository.",
        },
        "secret_scanning": {
            "source": "repos/:owner/:repo security_and_analysis.secret_scanning.status",
            "status": "enabled" if complete else "unknown",
            "enabled": complete,
            "reason": "" if complete else "security_and_analysis unavailable from repo API",
        },
        "dependency_graph": {
            "source": "repos/:owner/:repo security_and_analysis.dependency_graph.status",
            "status": "enabled" if complete else "unknown",
            "enabled": complete,
            "reason": "" if complete else "security_and_analysis unavailable from repo API",
        },
        "vulnerability_alerts": {
            "endpoint": f"repos/{REPO}/vulnerability-alerts",
            "status": "enabled" if complete else "disabled",
            "http_status": 204 if complete else 404,
            "enabled": complete,
            "reason": "" if complete else "Vulnerability alerts are disabled.",
        },
        "dependabot_alerts": {
            "endpoint": f"repos/{REPO}/dependabot/alerts?per_page=1",
            "status": "enabled" if complete else "disabled",
            "http_status": 200 if complete else 403,
            "enabled": complete,
            "sample_count": 0 if complete else None,
            "reason": "" if complete else "Dependabot alerts are disabled for this repository.",
        },
    }
    return {
        "observed_at": "2026-06-25T00:00:00+09:00",
        "repository": REPO,
        "read_only": True,
        "generated_by": "scripts/refresh_github_external_snapshots.py",
        "repo": {
            "private": True,
            "default_branch": "main",
            "has_issues": True,
            "allow_squash_merge": True,
            "allow_merge_commit": not complete,
            "allow_rebase_merge": not complete,
            "allow_auto_merge": False,
            "delete_branch_on_merge": complete,
        },
        "workflow_permissions": {
            "default_workflow_permissions": "read",
            "can_approve_pull_request_reviews": False,
        },
        "actions_permissions": {
            "enabled": True,
            "allowed_actions": "all",
            "sha_pinning_required": complete,
        },
        "branch_protection": {
            "endpoint": f"repos/{REPO}/branches/main/protection",
            "status": "available" if complete else "unavailable",
            "http_status": 200 if complete else 403,
            "reason": "" if complete else "Upgrade to GitHub Pro or make this repository public to enable this feature.",
            "required_pull_request_reviews": {"required_approving_review_count": 1} if complete else None,
            "required_status_checks": {"strict": True, "contexts": ["AI verify"]} if complete else None,
            "required_conversation_resolution": {"enabled": True} if complete else None,
            "allow_force_pushes": {"enabled": False} if complete else None,
            "allow_deletions": {"enabled": False} if complete else None,
        },
        "security_features": security_features,
        "settings_deltas": [
            {
                "setting": "Automatically delete head branches",
                "observed": complete,
                "recommended": True,
                "action_pending": not complete,
            },
            {
                "setting": "Default GITHUB_TOKEN permission",
                "observed": "read",
                "recommended": "read",
                "action_pending": False,
            },
            {
                "setting": "Require full SHA-pinned Actions",
                "observed": complete,
                "recommended": True,
                "action_pending": not complete,
            },
            {
                "setting": "Merge method",
                "observed": "squash only" if complete else "squash, merge-commit, and rebase all enabled",
                "recommended": "prefer squash merge as the only merge method for claim-bound slices",
                "action_pending": not complete,
            },
            {
                "setting": "Branch protection",
                "observed": "protection endpoint available" if complete else "protection endpoint unavailable for this private repository plan",
                "recommended": "enable required PRs, AI verify status checks, conversation resolution, block force pushes, and block branch deletion when available",
                "action_pending": not complete,
            },
            {
                "setting": "CodeQL default setup",
                "observed": "configured" if complete else "Code scanning is not enabled for this repository.",
                "recommended": "enabled/configured",
                "action_pending": not complete,
            },
            {
                "setting": "Secret scanning",
                "observed": "enabled" if complete else "unknown",
                "recommended": "enabled",
                "action_pending": not complete,
            },
            {
                "setting": "Dependency graph and Dependabot alerts",
                "observed": {
                    "dependency_graph": "enabled" if complete else "unknown",
                    "vulnerability_alerts": "enabled" if complete else "disabled",
                    "dependabot_alerts": "enabled" if complete else "disabled",
                },
                "recommended": "dependency graph and Dependabot/vulnerability alerts enabled",
                "action_pending": not complete,
            },
        ],
    }


def pending_snapshot() -> dict[str, Any]:
    return {
        "observed_at": "2026-06-25T00:00:00+09:00",
        "repository": REPO,
        "read_only": True,
        "generated_by": "scripts/refresh_github_external_snapshots.py",
        "open_issues": [],
        "expected_issue_titles": list(ISSUE_BODY_ANCHORS),
        "expected_issue_titles_missing": list(ISSUE_BODY_ANCHORS),
        "required_labels": REQUIRED_LABELS,
        "remote_labels_observed": ["bug", "documentation", "enhancement", "wontfix"],
        "required_labels_missing": REQUIRED_LABELS,
        "prs": [pr_row(5, False), pr_row(10, False)],
        "pr_cleanup_disposition_pending": [5, 10],
        "external_mutation_still_pending": True,
    }


def partial_labels_snapshot() -> dict[str, Any]:
    payload = pending_snapshot()
    payload["remote_labels_observed"] = REQUIRED_LABELS + ["bug", "documentation", "enhancement", "wontfix"]
    payload["required_labels_missing"] = []
    return payload


def complete_snapshot() -> dict[str, Any]:
    issues = []
    for index, title in enumerate(ISSUE_BODY_ANCHORS, start=1):
        issues.append(
            {
                "number": index,
                "title": title,
                "state": "OPEN",
                "labels": [{"name": label} for label in labels_for_title(title)],
                "body_anchor_checks": {
                    anchor: True
                    for anchor in ISSUE_BODY_ANCHORS[title]
                },
            }
        )
    return {
        "observed_at": "2026-06-25T00:00:00+09:00",
        "repository": REPO,
        "read_only": True,
        "generated_by": "scripts/refresh_github_external_snapshots.py",
        "open_issues": issues,
        "expected_issue_titles": list(ISSUE_BODY_ANCHORS),
        "expected_issue_titles_missing": [],
        "required_labels": REQUIRED_LABELS,
        "remote_labels_observed": REQUIRED_LABELS + ["bug", "documentation", "enhancement", "wontfix"],
        "required_labels_missing": [],
        "prs": [pr_row(5, True, final_disposition=True), pr_row(10, True, final_disposition=True)],
        "pr_cleanup_disposition_pending": [],
        "external_mutation_still_pending": False,
    }


def setup_root(tmp: Path, *, complete: bool) -> None:
    write_json(tmp / "docs/pm/github_issue_drafts.json", issue_drafts())
    write_json(
        tmp / "docs/pm/github_external_state_snapshot.json",
        complete_snapshot() if complete else pending_snapshot(),
    )
    write_json(
        tmp / "docs/pm/github_settings_external_snapshot.json",
        settings_snapshot(complete=complete),
    )


def setup_partial_root(tmp: Path) -> None:
    write_json(tmp / "docs/pm/github_issue_drafts.json", issue_drafts())
    write_json(
        tmp / "docs/pm/github_external_state_snapshot.json",
        partial_labels_snapshot(),
    )
    write_json(
        tmp / "docs/pm/github_settings_external_snapshot.json",
        settings_snapshot(complete=False),
    )


def run_verifier(tmp: Path, mode: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VERIFIER), "--mode", mode, str(tmp)],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def expect_ok(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{label} should pass\nstdout={result.stdout}\nstderr={result.stderr}")


def expect_fail(result: subprocess.CompletedProcess[str], label: str, required_error: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{label} should fail")
    if required_error not in result.stderr:
        raise AssertionError(
            f"{label} failed for the wrong reason; expected {required_error!r}\n"
            f"stdout={result.stdout}\nstderr={result.stderr}"
        )


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="github-external-state-") as tmpdir:
        tmp = Path(tmpdir)
        setup_root(tmp / "pending", complete=False)
        setup_partial_root(tmp / "partial-labels")
        setup_root(tmp / "complete", complete=True)
        expect_ok(run_verifier(tmp / "pending", "pending"), "pending fixture")
        expect_ok(run_verifier(tmp / "partial-labels", "partial"), "partial labels fixture")
        expect_ok(run_verifier(tmp / "complete", "complete"), "complete fixture")
        expect_fail(
            run_verifier(tmp / "pending", "complete"),
            "pending fixture in complete mode",
            "required labels still missing in complete mode",
        )
        expect_fail(
            run_verifier(tmp / "partial-labels", "complete"),
            "partial labels fixture in complete mode",
            "missing expected GitHub issue in complete mode",
        )

        bad_partial_settings = tmp / "bad-partial-settings"
        setup_partial_root(bad_partial_settings)
        settings_path = bad_partial_settings / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["settings_deltas"][0]["action_pending"] = False
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_partial_settings, "partial"),
            "partial fixture with mismatched settings delta",
            "Automatically delete head branches action_pending must be True in partial mode",
        )

        bad_complete = tmp / "bad-complete"
        setup_root(bad_complete, complete=True)
        snapshot_path = bad_complete / "docs/pm/github_external_state_snapshot.json"
        snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
        snapshot["open_issues"][0]["body_anchor_checks"]["## Claim Boundary"] = False
        write_json(snapshot_path, snapshot)
        expect_fail(
            run_verifier(bad_complete, "complete"),
            "complete fixture missing issue body anchor",
            "missing issue body anchor: ## Claim Boundary",
        )

        bad_open_pr = tmp / "bad-open-pr"
        setup_root(bad_open_pr, complete=True)
        snapshot_path = bad_open_pr / "docs/pm/github_external_state_snapshot.json"
        snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
        snapshot["prs"][0]["state"] = "OPEN"
        snapshot["pr_cleanup_disposition_pending"] = [5]
        write_json(snapshot_path, snapshot)
        expect_fail(
            run_verifier(bad_open_pr, "complete"),
            "complete fixture with open cleanup PR",
            "PR #5 must be closed or merged in complete mode",
        )

        bad_closed_pr = tmp / "bad-closed-pr"
        setup_root(bad_closed_pr, complete=True)
        snapshot_path = bad_closed_pr / "docs/pm/github_external_state_snapshot.json"
        snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
        snapshot["prs"][1]["labels"] = []
        write_json(snapshot_path, snapshot)
        expect_fail(
            run_verifier(bad_closed_pr, "complete"),
            "complete fixture with unlabeled closed cleanup PR",
            "PR #10 closed cleanup must carry superseded label in complete mode",
        )

        bad_security = tmp / "bad-security"
        setup_root(bad_security, complete=True)
        settings_path = bad_security / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["security_features"]["codeql_default_setup"]["configured"] = False
        settings["security_features"]["codeql_default_setup"]["state"] = None
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_security, "complete"),
            "complete fixture with CodeQL disabled",
            "CodeQL default setup must be configured in complete mode",
        )

        bad_actions = tmp / "bad-actions"
        setup_root(bad_actions, complete=True)
        settings_path = bad_actions / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["actions_permissions"]["sha_pinning_required"] = False
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_actions, "complete"),
            "complete fixture with SHA pinning disabled",
            "full SHA-pinned Actions must be required in complete mode",
        )

        bad_branch_reviews = tmp / "bad-branch-reviews"
        setup_root(bad_branch_reviews, complete=True)
        settings_path = bad_branch_reviews / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["branch_protection"]["required_pull_request_reviews"] = None
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_branch_reviews, "complete"),
            "complete fixture without required PR reviews",
            "branch protection must require pull request reviews in complete mode",
        )

        bad_branch_checks = tmp / "bad-branch-checks"
        setup_root(bad_branch_checks, complete=True)
        settings_path = bad_branch_checks / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["branch_protection"]["required_status_checks"] = {"strict": True, "contexts": ["unrelated"]}
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_branch_checks, "complete"),
            "complete fixture without AI verify status check",
            "branch protection must require AI verify status check in complete mode",
        )

        bad_branch_conversation = tmp / "bad-branch-conversation"
        setup_root(bad_branch_conversation, complete=True)
        settings_path = bad_branch_conversation / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["branch_protection"]["required_conversation_resolution"] = {"enabled": False}
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_branch_conversation, "complete"),
            "complete fixture without conversation resolution",
            "branch protection must require conversation resolution in complete mode",
        )

        bad_force_pushes = tmp / "bad-force-pushes"
        setup_root(bad_force_pushes, complete=True)
        settings_path = bad_force_pushes / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["branch_protection"]["allow_force_pushes"] = {"enabled": True}
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_force_pushes, "complete"),
            "complete fixture allowing force pushes",
            "branch protection must block force pushes in complete mode",
        )

        bad_branch_deletion = tmp / "bad-branch-deletion"
        setup_root(bad_branch_deletion, complete=True)
        settings_path = bad_branch_deletion / "docs/pm/github_settings_external_snapshot.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        settings["branch_protection"]["allow_deletions"] = {"enabled": True}
        write_json(settings_path, settings)
        expect_fail(
            run_verifier(bad_branch_deletion, "complete"),
            "complete fixture allowing branch deletion",
            "branch protection must block branch deletion in complete mode",
        )

    print("github external state verifier fixture tests ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
