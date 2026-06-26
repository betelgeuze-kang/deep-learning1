#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
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
PR_NUMBERS = [5, 10]
EXPECTED_ISSUE_TITLES = [
    "[P0] v53 frozen benchmark canonicalization",
    "[P0] D/E 30B-70B real evidence intake",
    "[P1] v54 real free-running generation",
    "[P1] v58 blind human review execution",
    "[P2] v61 one-token logits parity",
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


def now_local() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def run_gh(args: list[str], *, expect_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["gh", *args],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if expect_success and result.returncode != 0:
        raise SystemExit(
            "gh command failed: "
            + " ".join(["gh", *args])
            + "\n"
            + result.stderr.strip()
        )
    return result


def run_gh_json(args: list[str]) -> Any:
    result = run_gh(args)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"gh command did not return JSON: {' '.join(['gh', *args])}: {exc}") from exc


def read_open_issues() -> list[dict[str, Any]]:
    issues = run_gh_json(
        [
            "issue",
            "list",
            "--repo",
            REPO,
            "--state",
            "open",
            "--json",
            "number,title,state,labels",
            "--limit",
            "100",
        ]
    )
    if not isinstance(issues, list):
        raise SystemExit("gh issue list returned non-list JSON")
    normalized: list[dict[str, Any]] = []
    for issue in issues:
        if not isinstance(issue, dict):
            raise SystemExit(f"unexpected issue row: {issue!r}")
        title = issue.get("title")
        number = issue.get("number")
        body_anchors = {}
        if isinstance(title, str) and isinstance(number, int) and title in ISSUE_BODY_ANCHORS:
            body = read_issue_body(number)
            body_anchors = {
                anchor: anchor in body
                for anchor in ISSUE_BODY_ANCHORS[title]
            }
        row = dict(issue)
        row["body_anchor_checks"] = body_anchors
        normalized.append(row)
    return normalized


def read_issue_body(number: int) -> str:
    issue = run_gh_json(
        [
            "issue",
            "view",
            str(number),
            "--repo",
            REPO,
            "--json",
            "body",
        ]
    )
    if not isinstance(issue, dict):
        raise SystemExit(f"gh issue view {number} returned non-object JSON")
    body = issue.get("body")
    if not isinstance(body, str):
        return ""
    return body


def read_labels() -> list[str]:
    labels = run_gh_json(["api", f"repos/{REPO}/labels?per_page=100"])
    if not isinstance(labels, list):
        raise SystemExit("gh label API returned non-list JSON")
    names: list[str] = []
    for label in labels:
        if not isinstance(label, dict) or not isinstance(label.get("name"), str):
            raise SystemExit(f"unexpected label row: {label!r}")
        names.append(label["name"])
    return names


def read_pr(number: int) -> dict[str, Any]:
    row = run_gh_json(
        [
            "pr",
            "view",
            str(number),
            "--repo",
            REPO,
            "--json",
            "number,title,state,isDraft,mergeable,headRefName,baseRefName,labels,url",
        ]
    )
    if not isinstance(row, dict):
        raise SystemExit(f"gh pr view {number} returned non-object JSON")
    labels = row.get("labels", [])
    label_names = [
        label.get("name")
        for label in labels
        if isinstance(label, dict) and isinstance(label.get("name"), str)
    ]
    comments = read_pr_cleanup_comments(number)
    return {
        "number": row.get("number"),
        "title": row.get("title"),
        "state": row.get("state"),
        "is_draft": row.get("isDraft"),
        "mergeable": row.get("mergeable"),
        "head_ref": row.get("headRefName"),
        "base_ref": row.get("baseRefName"),
        "labels": label_names,
        "url": row.get("url"),
        "cleanup_comment_present": comments["cleanup_comment_present"],
        "cleanup_comment_count": comments["cleanup_comment_count"],
        "cleanup_comment_anchor_checks": comments["cleanup_comment_anchor_checks"],
    }


def read_pr_cleanup_comments(number: int) -> dict[str, Any]:
    comments = run_gh_json(["api", f"repos/{REPO}/issues/{number}/comments?per_page=100"])
    if not isinstance(comments, list):
        raise SystemExit(f"PR #{number} comments API returned non-list JSON")
    expected_anchor = f"PR #{number} Cleanup Comment Draft"
    required_anchors = PR_COMMENT_ANCHORS[number]
    matched = 0
    anchor_checks = {anchor: False for anchor in required_anchors}
    for comment in comments:
        if not isinstance(comment, dict):
            continue
        body = comment.get("body")
        if not isinstance(body, str) or expected_anchor not in body:
            continue
        matched += 1
        for anchor in required_anchors:
            if anchor in body:
                anchor_checks[anchor] = True
    return {
        "cleanup_comment_present": matched > 0,
        "cleanup_comment_count": matched,
        "cleanup_comment_anchor_checks": anchor_checks,
    }


def read_repo_settings() -> dict[str, Any]:
    repo = run_gh_json(["api", f"repos/{REPO}"])
    if not isinstance(repo, dict):
        raise SystemExit("repo API returned non-object JSON")
    return {
        "private": repo.get("private"),
        "default_branch": repo.get("default_branch"),
        "has_issues": repo.get("has_issues"),
        "allow_squash_merge": repo.get("allow_squash_merge"),
        "allow_merge_commit": repo.get("allow_merge_commit"),
        "allow_rebase_merge": repo.get("allow_rebase_merge"),
        "allow_auto_merge": repo.get("allow_auto_merge"),
        "delete_branch_on_merge": repo.get("delete_branch_on_merge"),
        "has_vulnerability_alerts": repo.get("has_vulnerability_alerts"),
        "security_and_analysis": repo.get("security_and_analysis"),
    }


def read_workflow_permissions() -> dict[str, Any]:
    workflow = run_gh_json(["api", f"repos/{REPO}/actions/permissions/workflow"])
    if not isinstance(workflow, dict):
        raise SystemExit("workflow permissions API returned non-object JSON")
    return {
        "default_workflow_permissions": workflow.get("default_workflow_permissions"),
        "can_approve_pull_request_reviews": workflow.get("can_approve_pull_request_reviews"),
    }


def read_actions_permissions() -> dict[str, Any]:
    actions = run_gh_json(["api", f"repos/{REPO}/actions/permissions"])
    if not isinstance(actions, dict):
        raise SystemExit("actions permissions API returned non-object JSON")
    return {
        "enabled": actions.get("enabled"),
        "allowed_actions": actions.get("allowed_actions"),
        "sha_pinning_required": actions.get("sha_pinning_required"),
    }


def read_branch_protection() -> dict[str, Any]:
    endpoint = f"repos/{REPO}/branches/main/protection"
    result = run_gh(["api", endpoint], expect_success=False)
    if result.returncode != 0:
        message = result.stderr.strip()
        http_status: int | None = None
        if result.stdout.strip():
            try:
                payload = json.loads(result.stdout)
            except json.JSONDecodeError:
                payload = {}
            if isinstance(payload, dict):
                message = str(payload.get("message") or message)
                try:
                    http_status = int(str(payload.get("status")))
                except (TypeError, ValueError):
                    http_status = None
        return {
            "endpoint": endpoint,
            "status": "unavailable",
            "http_status": http_status,
            "reason": message,
            "required_pull_request_reviews": None,
            "required_status_checks": None,
            "required_conversation_resolution": None,
            "allow_force_pushes": None,
            "allow_deletions": None,
        }
    payload = json.loads(result.stdout)
    if not isinstance(payload, dict):
        raise SystemExit("branch protection API returned non-object JSON")
    return {
        "endpoint": endpoint,
        "status": "available",
        "http_status": 200,
        "reason": "",
        "required_pull_request_reviews": payload.get("required_pull_request_reviews"),
        "required_status_checks": payload.get("required_status_checks"),
        "required_conversation_resolution": payload.get("required_conversation_resolution"),
        "allow_force_pushes": payload.get("allow_force_pushes"),
        "allow_deletions": payload.get("allow_deletions"),
    }


def parse_gh_error_payload(result: subprocess.CompletedProcess[str]) -> dict[str, Any]:
    text = result.stdout.strip()
    if not text:
        text = result.stderr.strip()
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return {"message": text, "status": None}
    if not isinstance(payload, dict):
        return {"message": text, "status": None}
    return payload


def parse_status(value: Any) -> int | None:
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return None


def read_codeql_default_setup() -> dict[str, Any]:
    endpoint = f"repos/{REPO}/code-scanning/default-setup"
    result = run_gh(["api", endpoint], expect_success=False)
    if result.returncode == 0:
        payload = json.loads(result.stdout)
        if not isinstance(payload, dict):
            raise SystemExit("code scanning default setup API returned non-object JSON")
        state = payload.get("state")
        return {
            "endpoint": endpoint,
            "status": "available",
            "http_status": 200,
            "state": state,
            "configured": state == "configured",
            "reason": "",
        }
    payload = parse_gh_error_payload(result)
    return {
        "endpoint": endpoint,
        "status": "unavailable",
        "http_status": parse_status(payload.get("status")),
        "state": None,
        "configured": False,
        "reason": str(payload.get("message") or result.stderr.strip()),
    }


def read_vulnerability_alerts() -> dict[str, Any]:
    endpoint = f"repos/{REPO}/vulnerability-alerts"
    result = run_gh(["api", endpoint], expect_success=False)
    if result.returncode == 0:
        return {
            "endpoint": endpoint,
            "status": "enabled",
            "http_status": 204,
            "enabled": True,
            "reason": "",
        }
    payload = parse_gh_error_payload(result)
    message = str(payload.get("message") or result.stderr.strip())
    return {
        "endpoint": endpoint,
        "status": "disabled" if "disabled" in message.lower() else "unavailable",
        "http_status": parse_status(payload.get("status")),
        "enabled": False,
        "reason": message,
    }


def read_dependabot_alerts() -> dict[str, Any]:
    endpoint = f"repos/{REPO}/dependabot/alerts?per_page=1"
    result = run_gh(["api", endpoint], expect_success=False)
    if result.returncode == 0:
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"dependabot alerts API returned invalid JSON: {exc}") from exc
        if not isinstance(payload, list):
            raise SystemExit("dependabot alerts API returned non-list JSON")
        return {
            "endpoint": endpoint,
            "status": "enabled",
            "http_status": 200,
            "enabled": True,
            "sample_count": len(payload),
            "reason": "",
        }
    payload = parse_gh_error_payload(result)
    message = str(payload.get("message") or result.stderr.strip())
    return {
        "endpoint": endpoint,
        "status": "disabled" if "disabled" in message.lower() else "unavailable",
        "http_status": parse_status(payload.get("status")),
        "enabled": False,
        "sample_count": None,
        "reason": message,
    }


def security_status(repo: dict[str, Any], key: str) -> str:
    security = repo.get("security_and_analysis")
    if not isinstance(security, dict):
        return "unknown"
    value = security.get(key)
    if not isinstance(value, dict):
        return "unknown"
    status = value.get("status")
    return str(status) if status is not None else "unknown"


def build_security_features(repo: dict[str, Any]) -> dict[str, Any]:
    codeql = read_codeql_default_setup()
    vulnerability_alerts = read_vulnerability_alerts()
    dependabot_alerts = read_dependabot_alerts()
    dependency_graph_status = security_status(repo, "dependency_graph")
    secret_scanning_status = security_status(repo, "secret_scanning")
    return {
        "codeql_default_setup": codeql,
        "secret_scanning": {
            "source": "repos/:owner/:repo security_and_analysis.secret_scanning.status",
            "status": secret_scanning_status,
            "enabled": secret_scanning_status == "enabled",
            "reason": "security_and_analysis unavailable from repo API"
            if secret_scanning_status == "unknown"
            else "",
        },
        "dependency_graph": {
            "source": "repos/:owner/:repo security_and_analysis.dependency_graph.status",
            "status": dependency_graph_status,
            "enabled": dependency_graph_status == "enabled",
            "reason": "security_and_analysis unavailable from repo API"
            if dependency_graph_status == "unknown"
            else "",
        },
        "vulnerability_alerts": vulnerability_alerts,
        "dependabot_alerts": dependabot_alerts,
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build_external_state_snapshot() -> dict[str, Any]:
    open_issues = read_open_issues()
    labels = read_labels()
    missing_labels = [label for label in REQUIRED_LABELS if label not in labels]
    prs = [read_pr(number) for number in PR_NUMBERS]
    issue_titles = {
        issue.get("title")
        for issue in open_issues
        if isinstance(issue, dict) and isinstance(issue.get("title"), str)
    }
    missing_issue_titles = [
        title
        for title in EXPECTED_ISSUE_TITLES
        if title not in issue_titles
    ]
    pr_cleanup_pending = [
        pr.get("number")
        for pr in prs
        if pr.get("cleanup_comment_present") is not True or pr.get("state") == "OPEN"
    ]
    return {
        "observed_at": now_local(),
        "repository": REPO,
        "read_only": True,
        "generated_by": "scripts/refresh_github_external_snapshots.py",
        "open_issues": open_issues,
        "expected_issue_titles": EXPECTED_ISSUE_TITLES,
        "expected_issue_titles_missing": missing_issue_titles,
        "required_labels": REQUIRED_LABELS,
        "remote_labels_observed": labels,
        "required_labels_missing": missing_labels,
        "prs": prs,
        "pr_cleanup_disposition_pending": pr_cleanup_pending,
        "gh_cli_notes": [
            "gh issue list returned an empty open issue array"
            if not open_issues
            else "gh issue list returned open issues",
            "gh pr view 5 and gh pr view 10 succeeded",
            "gh label list is unavailable in installed gh 2.4.0, so labels were read with gh api repos/:owner/:repo/labels",
        ],
        "external_mutation_still_pending": bool(missing_labels or missing_issue_titles or pr_cleanup_pending),
    }


def build_settings_snapshot() -> dict[str, Any]:
    repo = read_repo_settings()
    workflow = read_workflow_permissions()
    actions = read_actions_permissions()
    protection = read_branch_protection()
    security_features = build_security_features(repo)
    merge_methods = []
    if repo.get("allow_squash_merge"):
        merge_methods.append("squash")
    if repo.get("allow_merge_commit"):
        merge_methods.append("merge-commit")
    if repo.get("allow_rebase_merge"):
        merge_methods.append("rebase")
    branch_pending = protection.get("status") != "available"
    return {
        "observed_at": now_local(),
        "repository": REPO,
        "read_only": True,
        "generated_by": "scripts/refresh_github_external_snapshots.py",
        "repo": repo,
        "workflow_permissions": workflow,
        "actions_permissions": actions,
        "branch_protection": protection,
        "security_features": security_features,
        "settings_deltas": [
            {
                "setting": "Automatically delete head branches",
                "observed": repo.get("delete_branch_on_merge"),
                "recommended": True,
                "action_pending": repo.get("delete_branch_on_merge") is not True,
            },
            {
                "setting": "Default GITHUB_TOKEN permission",
                "observed": workflow.get("default_workflow_permissions"),
                "recommended": "read",
                "action_pending": workflow.get("default_workflow_permissions") != "read",
            },
            {
                "setting": "Require full SHA-pinned Actions",
                "observed": actions.get("sha_pinning_required"),
                "recommended": True,
                "action_pending": actions.get("sha_pinning_required") is not True,
            },
            {
                "setting": "Merge method",
                "observed": ", ".join(merge_methods[:-1]) + ", and " + merge_methods[-1] + " all enabled"
                if len(merge_methods) > 1
                else ", ".join(merge_methods),
                "recommended": "prefer squash merge as the only merge method for claim-bound slices",
                "action_pending": merge_methods != ["squash"],
            },
            {
                "setting": "Branch protection",
                "observed": "protection endpoint unavailable for this private repository plan"
                if protection.get("status") == "unavailable"
                else "protection endpoint available",
                "recommended": "enable required PRs, AI verify status checks, conversation resolution, block force pushes, and block branch deletion when available",
                "action_pending": branch_pending,
            },
            {
                "setting": "CodeQL default setup",
                "observed": security_features["codeql_default_setup"].get("state")
                or security_features["codeql_default_setup"].get("reason"),
                "recommended": "enabled/configured",
                "action_pending": security_features["codeql_default_setup"].get("configured") is not True,
            },
            {
                "setting": "Secret scanning",
                "observed": security_features["secret_scanning"].get("status"),
                "recommended": "enabled",
                "action_pending": security_features["secret_scanning"].get("enabled") is not True,
            },
            {
                "setting": "Dependency graph and Dependabot alerts",
                "observed": {
                    "dependency_graph": security_features["dependency_graph"].get("status"),
                    "vulnerability_alerts": security_features["vulnerability_alerts"].get("status"),
                    "dependabot_alerts": security_features["dependabot_alerts"].get("status"),
                },
                "recommended": "dependency graph and Dependabot/vulnerability alerts enabled",
                "action_pending": not (
                    security_features["dependency_graph"].get("enabled") is True
                    and security_features["vulnerability_alerts"].get("enabled") is True
                    and security_features["dependabot_alerts"].get("enabled") is True
                ),
            },
        ],
    }


def main(argv: list[str]) -> int:
    if argv:
        print("usage: scripts/refresh_github_external_snapshots.py", file=sys.stderr)
        return 2
    write_json(
        ROOT / "docs" / "pm" / "github_external_state_snapshot.json",
        build_external_state_snapshot(),
    )
    write_json(
        ROOT / "docs" / "pm" / "github_settings_external_snapshot.json",
        build_settings_snapshot(),
    )
    print("github external snapshots refreshed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
