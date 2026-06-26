#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def read(root: Path, rel: str, errors: list[str]) -> str:
    path = root / rel
    if not path.is_file():
        add(errors, f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(text: str, snippet: str, label: str, errors: list[str]) -> None:
    if snippet not in text:
        add(errors, f"{label} missing snippet: {snippet}")


def forbid(text: str, snippet: str, label: str, errors: list[str]) -> None:
    if snippet in text:
        add(errors, f"{label} forbidden snippet present: {snippet}")


def require_all(text: str, snippets: list[str], label: str, errors: list[str]) -> None:
    for snippet in snippets:
        require(text, snippet, label, errors)


def github_external_state_mode(errors: list[str]) -> str:
    mode = os.environ.get("DLE_GITHUB_EXTERNAL_STATE_MODE", "pending")
    if mode not in {"pending", "partial", "complete"}:
        add(errors, f"DLE_GITHUB_EXTERNAL_STATE_MODE must be pending, partial, or complete, got {mode!r}")
        return "pending"
    return mode


def verify_readmes(root: Path, errors: list[str]) -> None:
    for rel, readiness_heading, works_heading, blockers_heading in [
        ("README.md", "## Current Readiness", "## What Works Now", "## Next Blockers"),
        ("README.ko.md", "## 현재 Readiness", "## 현재 실제로 동작하는 것", "## 다음 Blocker"),
    ]:
        text = read(root, rel, errors)
        if not text:
            continue
        line_count = len(text.splitlines())
        if line_count > 140:
            add(errors, f"{rel} should stay dashboard-sized; got {line_count} lines")
        require_all(
            text,
            [
                readiness_heading,
                works_heading,
                blockers_heading,
                "readiness/typed_ready.json",
                "docs/archive/IMPLEMENTATION_HISTORY.md",
                "v53 benchmark foundation",
                "v54 generation",
                "D/E 30B-70B baselines",
                "v58 blind evaluation",
                "v61 SSD-MoE",
            ],
            rel,
            errors,
        )
        for snippet in [
            "Latest completed checkpoint",
            "## 최신 완료 체크포인트",
            "codex/route-memory-local-energy-policy",
            "v53-v54-query-evaluation-pipeline",
        ]:
            forbid(text, snippet, rel, errors)

    archive = read(root, "docs/archive/IMPLEMENTATION_HISTORY.md", errors)
    if archive:
        require_all(
            archive,
            [
                "# Implementation History Archive",
                "Previous English README",
                "Previous Korean README",
            ],
            "docs/archive/IMPLEMENTATION_HISTORY.md",
            errors,
        )


def verify_templates(root: Path, errors: list[str]) -> None:
    pr_template = read(root, ".github/pull_request_template.md", errors)
    require_all(
        pr_template,
        [
            "## Scope",
            "Slice ID:",
            "## Readiness transition",
            "contract_ready",
            "fixture_execution_ready",
            "real_model_execution_ready",
            "heldout_metric_ready",
            "human_review_ready",
            "independent_reproduction_ready",
            "release_ready",
            "## Claim boundary",
            "Allowed claim:",
            "Blocked claims:",
            "## Evidence",
            "Artifact hashes:",
            "## Leakage and fixture checks",
            "No evaluator-only field is model-visible",
            "Missing external evidence remains fail-closed",
            "README and Korean README synchronized",
            "Central readiness ledger synchronized",
        ],
        ".github/pull_request_template.md",
        errors,
    )

    issue_template = read(root, ".github/ISSUE_TEMPLATE/evidence-blocker.yml", errors)
    require_all(
        issue_template,
        [
            "name: Evidence blocker",
            "labels:",
            "type:evidence",
            "id: scope",
            "v53 benchmark",
            "D/E baseline",
            "v54 generation",
            "v58 blind evaluation",
            "v61 SSD-MoE",
            "id: readiness",
            "contract -> fixture",
            "fixture -> real execution",
            "real execution -> heldout",
            "heldout -> human review",
            "human review -> independent reproduction",
            "independent reproduction -> release",
            "id: evidence",
            "Required artifacts",
        ],
        ".github/ISSUE_TEMPLATE/evidence-blocker.yml",
        errors,
    )

    codeowners = read(root, ".github/CODEOWNERS", errors)
    require_all(
        codeowners,
        [
            "* @betelgeuze-kang",
            "/.github/workflows/ @betelgeuze-kang",
            "/readiness/ @betelgeuze-kang",
            "/schemas/ @betelgeuze-kang",
            "/benchmarks/ @betelgeuze-kang",
            "/baselines/ @betelgeuze-kang",
            "/v54/ @betelgeuze-kang",
            "/v58/ @betelgeuze-kang",
            "/v61/ @betelgeuze-kang",
            "/docs/*CLAIM* @betelgeuze-kang",
        ],
        ".github/CODEOWNERS",
        errors,
    )


def verify_policy_docs(root: Path, errors: list[str]) -> None:
    contributing = read(root, "CONTRIBUTING.md", errors)
    require_all(
        contributing,
        [
            "# Contribution Policy",
            "One claim-bound slice per PR.",
            "Fixture evidence presented as real evidence",
            "Evaluator-only fields exposed to model input",
            "Readiness promotion without artifact paths",
            "Generated results committed without an artifact contract",
            "./scripts/ai-verify.sh",
            "Relevant `tools/verify_artifact.py` command",
            "README/readiness synchronization",
        ],
        "CONTRIBUTING.md",
        errors,
    )

    security = read(root, "SECURITY.md", errors)
    require_all(
        security,
        [
            "# Security Policy",
            "GitHub Actions command injection",
            "Credential exposure",
            "Path traversal in artifact intake",
            "Malicious artifact archive extraction",
            "Model-input leakage of evaluator-only fields",
            "Hash/provenance bypass",
            "Do not open public issues for credential or runner compromise.",
        ],
        "SECURITY.md",
        errors,
    )

    license_text = read(root, "LICENSE", errors)
    require_all(
        license_text,
        [
            "License is not yet granted for public reuse.",
            "remain all rights reserved",
            "source code",
            "benchmark metadata",
            "generated artifacts and result packets",
            "external model, dataset, and dependency materials",
        ],
        "LICENSE",
        errors,
    )


def verify_orchestration_docs(root: Path, errors: list[str]) -> None:
    kiro_prompt = read(root, "docs/ai/prompts/kiro_opus_prompt_architect.md", errors)
    require_all(
        kiro_prompt,
        [
            "Kiro Opus 4.8 Prompt Architect Template",
            "Manual-use boundary",
            "does not currently have a verified headless Kiro Opus 4.8 worker wrapper",
            "Paste this template into the Kiro IDE",
            "Do not imply that Codex automatically invoked Kiro",
            "Source: Kiro Opus 4.8 prompt architect draft",
            "preserve the Kiro design notes",
            "cite the reason the Kiro draft was skipped",
            "Do not edit code, docs, schemas, scripts, results, or generated artifacts.",
        ],
        "docs/ai/prompts/kiro_opus_prompt_architect.md",
        errors,
    )

    goal_start = read(root, "docs/ai/prompts/deep_learning_research_goal_start.md", errors)
    require_all(
        goal_start,
        [
            "Kiro Opus 4.8 prompt design",
            "Kiro is currently manual rather than a headless worker",
            "does not expose a verified stdout",
            "prompt-response interface",
            "preserve its `Kiro design notes` block",
            "record why the slice did not need prompt-architect review",
            "Dispatch notes should remain traceable",
        ],
        "docs/ai/prompts/deep_learning_research_goal_start.md",
        errors,
    )

    playbook = read(root, "docs/ai/GOAL-LOOP-PLAYBOOK.md", errors)
    require_all(
        playbook,
        [
            "Kiro Opus 4.8: prompt architecture",
            "Kiro is currently a manual IDE-assisted prompt-architect step",
            "does not provide a verified",
            "headless Opus 4.8 worker interface",
            "paste `docs/ai/prompts/kiro_opus_prompt_architect.md` into Kiro",
            "preserve the `Kiro design notes` block",
            "record the skip reason",
            "Codex-owned design decision",
        ],
        "docs/ai/GOAL-LOOP-PLAYBOOK.md",
        errors,
    )


def verify_backlog_and_labels(root: Path, errors: list[str]) -> None:
    external_state_mode = github_external_state_mode(errors)
    labels = [
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
    labels_yml = read(root, ".github/labels.yml", errors)
    for label in labels:
        require(labels_yml, f"name: {label}", ".github/labels.yml", errors)

    backlog = read(root, "docs/pm/EVIDENCE_BACKLOG.md", errors)
    require_all(
        backlog,
        [
            "# Evidence Backlog",
            "Canonical readiness remains `readiness/typed_ready.json`",
            "v53 frozen benchmark canonicalization",
            "D/E 30B-70B real evidence intake",
            "v54 real free-running generation",
            "v58 blind human review execution",
            "v61 one-token logits parity",
            "PR #5",
            "v50 auditor correctness replay contract",
            "PR #10",
            "v56 RULER/LongBench expanded replay blocker",
            "Require pull request before merging",
            "Require `AI verify` status checks",
            "Default `GITHUB_TOKEN` permission to read-only",
            "Enable CodeQL default setup",
            "Enable secret scanning",
            "Prefer one merge mode",
        ]
        + labels,
        "docs/pm/EVIDENCE_BACKLOG.md",
        errors,
    )

    issue_drafts_text = read(root, "docs/pm/github_issue_drafts.json", errors)
    if issue_drafts_text:
        try:
            issue_drafts = json.loads(issue_drafts_text)
        except json.JSONDecodeError as exc:
            add(errors, f"docs/pm/github_issue_drafts.json invalid JSON: {exc}")
            issue_drafts = {}
        expected_titles = [
            "[P0] v53 frozen benchmark canonicalization",
            "[P0] D/E 30B-70B real evidence intake",
            "[P1] v54 real free-running generation",
            "[P1] v58 blind human review execution",
            "[P2] v61 one-token logits parity",
        ]
        issues = issue_drafts.get("issues", []) if isinstance(issue_drafts, dict) else []
        by_title = {
            issue.get("title"): issue
            for issue in issues
            if isinstance(issue, dict) and isinstance(issue.get("title"), str)
        }
        if len(issues) != 5:
            add(errors, f"docs/pm/github_issue_drafts.json should contain 5 issues, got {len(issues)}")
        for title in expected_titles:
            issue = by_title.get(title)
            if not issue:
                add(errors, f"docs/pm/github_issue_drafts.json missing issue: {title}")
                continue
            issue_labels = issue.get("labels", [])
            for field in ["scope", "target_readiness_transition", "required_artifacts", "blocked_claims"]:
                if not issue.get(field):
                    add(errors, f"{title} missing non-empty field: {field}")
            if "claim-boundary" not in issue_labels:
                add(errors, f"{title} missing claim-boundary label")
        all_issue_labels = {
            label
            for issue in issues
            if isinstance(issue, dict)
            for label in issue.get("labels", [])
            if isinstance(label, str)
        }
        for required_label in ["priority:P0", "priority:P1", "priority:P2", "type:evidence", "claim-boundary"]:
            if required_label not in all_issue_labels:
                add(errors, f"docs/pm/github_issue_drafts.json missing label use: {required_label}")

    issue_body_specs = [
        (
            "docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md",
            "[P0] v53 frozen benchmark canonicalization",
            "v53 benchmark",
            "fixture -> real execution",
            "benchmarks/v53_source_bound_freeze.json",
        ),
        (
            "docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md",
            "[P0] D/E 30B-70B real evidence intake",
            "D/E baseline",
            "fixture -> real execution",
            "30B-150B public comparison wording",
        ),
        (
            "docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md",
            "[P1] v54 real free-running generation",
            "v54 generation",
            "fixture -> real execution",
            "actual model generation readiness",
        ),
        (
            "docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md",
            "[P1] v58 blind human review execution",
            "v58 blind evaluation",
            "heldout -> human review",
            "human review rows",
        ),
        (
            "docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md",
            "[P2] v61 one-token logits parity",
            "v61 SSD-MoE",
            "fixture -> real execution",
            "checkpoint payloads must remain out of git",
        ),
    ]
    for rel, title, scope, transition, anchor in issue_body_specs:
        text = read(root, rel, errors)
        require_all(
            text,
            [
                f"# {title}",
                "## Scope",
                scope,
                "## Target Readiness Transition",
                transition,
                "## Required Artifacts",
                "## Claim Boundary",
                "Allowed claim:",
                "Blocked claims:",
                "## Verification",
                "./scripts/ai-verify.sh",
                anchor,
            ],
            rel,
            errors,
        )

    pr_comment_specs = [
        (
            "docs/pm/pr_cleanup_comments/pr5-v50-cleanup-comment.md",
            "# PR #5 Cleanup Comment Draft",
            "durable contract/schema/test",
            "external auditor correctness evidence",
            "real auditor correctness readiness",
        ),
        (
            "docs/pm/pr_cleanup_comments/pr10-v56-cleanup-comment.md",
            "# PR #10 Cleanup Comment Draft",
            "durable v56 replay contract",
            "expanded replay evidence",
            "leaderboard, expanded benchmark readiness, or public comparison",
        ),
    ]
    for rel, title, durable_anchor, evidence_anchor, forbidden_claim_anchor in pr_comment_specs:
        text = read(root, rel, errors)
        require_all(
            text,
            [
                title,
                "This PR should not remain a long-lived blocker-only PR.",
                "Rebase or cherry-pick only the still-needed durable",
                durable_anchor,
                evidence_anchor,
                "evidence blocker issue",
                "Close this PR after the durable contract slice",
                forbidden_claim_anchor,
            ],
            rel,
            errors,
        )

    pr_cleanup = read(root, "docs/pm/PR_CLEANUP_PLAN.md", errors)
    require_all(
        pr_cleanup,
        [
            "# PR Cleanup Plan",
            "PR #5",
            "Draft: harden v50 auditor correctness replay contract",
            "pr2-slice-v50-auditor-correctness",
            "audits/v50_public_repo_auditor_correctness.json",
            "Recommended action: A plus B.",
            "PR #10",
            "Draft: keep v56 expanded benchmark replay blocked",
            "pr2-slice-v56-ruler-longbench-expanded",
            "v56/replay_contract.json",
            "External Mutation Boundary",
            "Do not close, label, merge, or comment on PRs without explicit human approval.",
            "Do not create GitHub issues automatically without explicit human approval.",
            "PR_CLEANUP_DISPOSITION_COMMANDS.md",
            "verify_pr_cleanup_disposition_commands.py",
        ],
        "docs/pm/PR_CLEANUP_PLAN.md",
        errors,
    )

    disposition_commands = read(root, "docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md", errors)
    require_all(
        disposition_commands,
        [
            "# PR Cleanup Disposition Commands",
            "human-approved phase only",
            "## Batch E: Superseded-Close PR Disposition",
            "This file belongs only to Batch E",
            "PR cleanup comments does not approve these close commands.",
            "Superseded-Close Path",
            "gh pr edit 5 --repo betelgeuze-kang/deep-learning1 --add-label superseded",
            "gh pr close 5 --repo betelgeuze-kang/deep-learning1",
            "gh pr edit 10 --repo betelgeuze-kang/deep-learning1 --add-label superseded",
            "gh pr close 10 --repo betelgeuze-kang/deep-learning1",
            "No pre-approved merge command is generated here.",
            "closed cleanup PRs carry the `superseded` label",
            "The expected Batch E postcondition",
            "pr_cleanup_disposition_pending` is empty",
        ],
        "docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md",
        errors,
    )

    settings_text = read(root, "docs/pm/github_settings_checklist.json", errors)
    if settings_text:
        try:
            settings = json.loads(settings_text)
        except json.JSONDecodeError as exc:
            add(errors, f"docs/pm/github_settings_checklist.json invalid JSON: {exc}")
            settings = {}
        required_settings = [
            "Require pull request before merging",
            "Require status checks",
            "Require conversation resolution",
            "Block force pushes",
            "Block branch deletion",
            "Automatically delete head branches",
            "Default GITHUB_TOKEN permission",
            "Require full SHA-pinned Actions",
            "CodeQL default setup",
            "Secret scanning",
            "Dependency graph and Dependabot alerts",
            "Merge method",
        ]
        rows = settings.get("manual_settings_required", []) if isinstance(settings, dict) else []
        by_setting = {
            row.get("setting"): row
            for row in rows
            if isinstance(row, dict) and isinstance(row.get("setting"), str)
        }
        if len(rows) != len(required_settings):
            add(
                errors,
                "docs/pm/github_settings_checklist.json should contain "
                f"{len(required_settings)} settings, got {len(rows)}",
            )
        for setting in required_settings:
            row = by_setting.get(setting)
            if not row:
                add(errors, f"docs/pm/github_settings_checklist.json missing setting: {setting}")
                continue
            for field in ["recommended", "reason"]:
                if not row.get(field):
                    add(errors, f"{setting} missing non-empty field: {field}")

    local_pr_draft = read(root, "docs/pm/LOCAL_CHANGESET_PR_DRAFT.md", errors)
    require_all(
        local_pr_draft,
        [
            "# Local Changeset PR Draft",
            "## Scope",
            "Readiness transition:",
            "## Claim boundary",
            "Allowed claim:",
            "Blocked claims:",
            "## Evidence",
            "GitHub Actions security",
            "## Verification",
            "python3 scripts/refresh_github_external_snapshots.py",
            "python3 tools/verify_github_governance_commands.py",
            "./scripts/ai-verify.sh",
            "python3 tools/verify_github_external_state.py --mode partial .",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh",
            "tools/verify_repo_governance.py",
            "tools/verify_ci_workflows.py",
            "readiness/typed_ready.json",
            "docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md",
            "docs/pm/pasted_goal_completion_audit.json",
            "## External pending",
        ],
        "docs/pm/LOCAL_CHANGESET_PR_DRAFT.md",
        errors,
    )

    approval_packet = read(root, "docs/pm/EXTERNAL_MUTATION_APPROVAL_PACKET.md", errors)
    require_all(
        approval_packet,
        [
            "# External Mutation Approval Packet",
            "No external commands have been executed",
            "explicit human approval",
            "python3 scripts/refresh_github_external_snapshots.py",
            "python3 tools/verify_github_governance_commands.py",
            "python3 tools/verify_pr_cleanup_disposition_commands.py",
            "python3 scripts/print_github_governance_commands.py",
            "python3 scripts/print_github_governance_commands.py --batch B",
            "python3 scripts/print_github_governance_commands.py --batch C",
            "python3 scripts/print_github_governance_commands.py --batch D",
            "## Approval batches",
            "Do not treat approval for one",
            "| A | Read-only refresh and local verification only |",
            "| B | Create/update labels with `gh label create` |",
            "| C | Create the five evidence blocker issues with `gh issue create` |",
            "| D | Comment on PR #5 and PR #10 with `gh pr comment` |",
            "| E | If separately approved, apply only the superseded-close PR disposition packet |",
            "| F | Change GitHub repository settings manually |",
            "| G | Replace `LICENSE` with a public reuse license only if the owner chooses one |",
            "| H | Final verification and audit update only |",
            "Batch D is not PR cleanup completion by itself.",
            "requires Batch E or another explicitly approved final disposition",
            "generated issue titles,",
            "Batch B",
            "Batch C",
            "Batch D",
            "require separate explicit approval",
            "gh label create",
            "gh issue create",
            "gh pr comment 5",
            "gh pr comment 10",
            "GitHub Settings",
            "branch protection with required",
            "`AI verify`/PR-safe status check",
            "conversation",
            "force-push blocking",
            "branch-deletion blocking",
            "full SHA-pinned Actions",
            "CodeQL",
            "Dependabot alerts",
            "public license",
            "./scripts/ai-verify.sh",
            "python3 tools/verify_github_external_state.py --mode partial .",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh",
            "Complete mode is expected to fail before those mutations are applied.",
            "docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md",
            "docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md",
            "docs/pm/pasted_goal_completion_audit.json",
        ],
        "docs/pm/EXTERNAL_MUTATION_APPROVAL_PACKET.md",
        errors,
    )

    mutation_runbook = read(root, "docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md", errors)
    require_all(
        mutation_runbook,
        [
            "# GitHub External Mutation Runbook",
            "It does not grant approval by",
            "itself. Do not run any mutating command",
            "## 0. Preflight",
            "python3 scripts/refresh_github_external_snapshots.py",
            "python3 tools/verify_github_governance_commands.py",
            "python3 tools/verify_pr_cleanup_disposition_commands.py",
            "python3 tools/verify_repo_governance.py .",
            "python3 tools/verify_github_external_state.py --mode pending .",
            "./scripts/ai-verify.sh",
            "complete` is expected to fail before approved",
            "## 1. Labels",
            "gh label create",
            "required_labels_missing",
            "## 2. Evidence Blocker Issues",
            "[P0] v53 frozen benchmark canonicalization",
            "[P0] D/E 30B-70B real evidence intake",
            "[P1] v54 real free-running generation",
            "[P1] v58 blind human review execution",
            "[P2] v61 one-token logits parity",
            "exactly the labels declared for that issue",
            "issue body still contains the required scope",
            "## 3. PR #5 and PR #10 Cleanup Comments",
            "gh pr comment 5",
            "gh pr comment 10",
            "cleanup comment anchors are present",
            "closed or merged",
            "pr_cleanup_disposition_pending",
            "not merge either PR merely because the cleanup comment was posted.",
            "cleanup comment was posted.",
            "PR_CLEANUP_DISPOSITION_COMMANDS.md",
            "## 4. GitHub Settings",
            "Upgrade to GitHub Pro or make this repository public",
            "## 5. License Decision",
            "## 6. Post-Mutation Verification",
            "After any approved external mutation batch, refresh the read-only snapshots",
            "For a partial batch",
            "--mode partial",
            "reviewed intermediate states",
            "security features, or",
            "python3 tools/verify_github_external_state.py --mode partial .",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh",
            "Only after the final approved batch has completed every external requirement",
            "python3 tools/verify_github_external_state.py --mode complete .",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh",
            "Do not mark the pasted goal complete unless every",
            "requirement is proven complete",
        ],
        "docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md",
        errors,
    )

    snapshot_script = root / "scripts" / "refresh_github_external_snapshots.py"
    if not snapshot_script.is_file():
        add(errors, "missing required file: scripts/refresh_github_external_snapshots.py")
    else:
        snapshot_script_text = snapshot_script.read_text(encoding="utf-8")
        require_all(
            snapshot_script_text,
            [
                "read_only",
                "generated_by",
                '"issue"',
                '"list"',
                "repos/{REPO}/labels?per_page=100",
                "pr",
                "view",
                "actions/permissions/workflow",
                "actions/permissions",
                "read_actions_permissions",
                "sha_pinning_required",
                "branches/main/protection",
            "github_external_state_snapshot.json",
            "github_settings_external_snapshot.json",
            "expected_issue_titles_missing",
            "pr_cleanup_disposition_pending",
            "code-scanning/default-setup",
            "vulnerability-alerts",
            "dependabot/alerts?per_page=1",
            "security_features",
        ],
        "scripts/refresh_github_external_snapshots.py",
        errors,
        )

    external_state_verifier = root / "tools" / "verify_github_external_state.py"
    if not external_state_verifier.is_file():
        add(errors, "missing required file: tools/verify_github_external_state.py")
    else:
        verifier_text = external_state_verifier.read_text(encoding="utf-8")
        require_all(
            verifier_text,
            [
                "--mode",
                "pending",
                "partial",
                "complete",
                "required_labels_missing",
                "body_anchor_checks",
                "cleanup_comment_present",
                "cleanup_comment_anchor_checks",
                "pr_cleanup_disposition_pending",
                "closed or merged in complete mode",
                "closed cleanup must carry superseded label",
                "delete_branch_on_merge",
                "actions_permissions must be an object",
                "full SHA-pinned Actions must be required",
                "branch protection must be available",
                "branch protection must require pull request reviews",
                "branch protection must require AI verify status check",
                "branch protection must require conversation resolution",
                "branch protection must block force pushes",
                "branch protection must block branch deletion",
                "security_features must be an object",
                "CodeQL default setup must be configured",
                "secret scanning must be enabled",
                "dependency graph must be enabled",
                "Dependabot alerts must be enabled",
                "github external state verify ok",
            ],
            "tools/verify_github_external_state.py",
            errors,
        )
        try:
            result = subprocess.run(
                [sys.executable, str(external_state_verifier), "--mode", external_state_mode, str(root)],
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            add(errors, f"failed to run tools/verify_github_external_state.py: {exc}")
        else:
            if result.returncode != 0:
                add(
                    errors,
                    f"tools/verify_github_external_state.py --mode {external_state_mode} failed: "
                    + result.stderr.strip(),
                )

    external_state_test = root / "tools" / "test_github_external_state_verifier.py"
    if not external_state_test.is_file():
        add(errors, "missing required file: tools/test_github_external_state_verifier.py")
    else:
        test_text = external_state_test.read_text(encoding="utf-8")
        require_all(
            test_text,
            [
                "pending fixture",
                "partial labels fixture",
                "complete fixture",
                "pending fixture in complete mode",
                "partial labels fixture in complete mode",
                "partial fixture with mismatched settings delta",
                "complete fixture missing issue body anchor",
                "complete fixture with open cleanup PR",
                "complete fixture with unlabeled closed cleanup PR",
                "complete fixture with CodeQL disabled",
                "github external state verifier fixture tests ok",
            ],
            "tools/test_github_external_state_verifier.py",
            errors,
        )
        try:
            result = subprocess.run(
                [sys.executable, str(external_state_test)],
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            add(errors, f"failed to run tools/test_github_external_state_verifier.py: {exc}")
        else:
            if result.returncode != 0:
                add(
                    errors,
                    "tools/test_github_external_state_verifier.py failed: "
                    + result.stderr.strip(),
                )

    command_script = root / "scripts" / "print_github_governance_commands.py"
    if not command_script.is_file():
        add(errors, "missing required file: scripts/print_github_governance_commands.py")
    else:
        try:
            result = subprocess.run(
                [sys.executable, str(command_script)],
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            add(errors, f"failed to run scripts/print_github_governance_commands.py: {exc}")
        else:
            if result.returncode != 0:
                add(
                    errors,
                    "scripts/print_github_governance_commands.py failed: "
                    + result.stderr.strip(),
                )
            output = result.stdout
            require_all(
                output,
                [
                    "# Generated GitHub governance commands",
                    "Review before running. These commands mutate GitHub state.",
                    "gh label create",
                    "priority:P0",
                    "type:evidence",
                    "gh issue create",
                    "--body-file docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md",
                    "--body-file docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md",
                    "--body-file docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md",
                    "--body-file docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md",
                    "--body-file docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md",
                    "gh pr comment 5",
                    "--body-file docs/pm/pr_cleanup_comments/pr5-v50-cleanup-comment.md",
                    "gh pr comment 10",
                    "--body-file docs/pm/pr_cleanup_comments/pr10-v56-cleanup-comment.md",
                ],
                "scripts/print_github_governance_commands.py output",
                errors,
            )

    command_verifier = root / "tools" / "verify_github_governance_commands.py"
    if not command_verifier.is_file():
        add(errors, "missing required file: tools/verify_github_governance_commands.py")
    else:
        command_verifier_text = command_verifier.read_text(encoding="utf-8")
        require_all(
            command_verifier_text,
            [
                '["gh", "label", "create"]',
                '["gh", "issue", "create"]',
                '["gh", "pr", "comment"]',
                "EXPECTED_LABELS",
                "ISSUE_BODY_BY_TITLE",
                "load_issue_draft_labels",
                "EXPECTED_ISSUE_BODY_FILES",
                "EXPECTED_PR_COMMENT_FILES",
                "labels for",
                "must match draft",
                "issue title command set mismatch",
                "unexpected generated command",
                "github governance commands verify ok",
            ],
            "tools/verify_github_governance_commands.py",
            errors,
        )
        try:
            result = subprocess.run(
                [sys.executable, str(command_verifier)],
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            add(errors, f"failed to run tools/verify_github_governance_commands.py: {exc}")
        else:
            if result.returncode != 0:
                add(
                    errors,
                    "tools/verify_github_governance_commands.py failed: "
                    + result.stderr.strip(),
                )

    disposition_verifier = root / "tools" / "verify_pr_cleanup_disposition_commands.py"
    if not disposition_verifier.is_file():
        add(errors, "missing required file: tools/verify_pr_cleanup_disposition_commands.py")
    else:
        verifier_text = disposition_verifier.read_text(encoding="utf-8")
        require_all(
            verifier_text,
            [
                "EXPECTED_COMMANDS",
                '["gh", "pr", "edit", "5"',
                '["gh", "pr", "close", "5"',
                '["gh", "pr", "edit", "10"',
                '["gh", "pr", "close", "10"',
                "forbidden option",
                "pr cleanup disposition commands verify ok",
            ],
            "tools/verify_pr_cleanup_disposition_commands.py",
            errors,
        )
        try:
            result = subprocess.run(
                [sys.executable, str(disposition_verifier)],
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            add(errors, f"failed to run tools/verify_pr_cleanup_disposition_commands.py: {exc}")
        else:
            if result.returncode != 0:
                add(
                    errors,
                    "tools/verify_pr_cleanup_disposition_commands.py failed: "
                    + result.stderr.strip(),
                )

    snapshot_text = read(root, "docs/pm/github_external_state_snapshot.json", errors)
    if snapshot_text:
        try:
            snapshot = json.loads(snapshot_text)
        except json.JSONDecodeError as exc:
            add(errors, f"docs/pm/github_external_state_snapshot.json invalid JSON: {exc}")
            snapshot = {}
        if isinstance(snapshot, dict):
            if snapshot.get("repository") != "betelgeuze-kang/deep-learning1":
                add(errors, "github external snapshot repository mismatch")
            if snapshot.get("read_only") is not True:
                add(errors, "github external snapshot must be read_only=true")
            required_labels = [
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
            if snapshot.get("required_labels") != required_labels:
                add(errors, "github external snapshot required_labels drifted")
            if external_state_mode == "pending":
                if snapshot.get("external_mutation_still_pending") is not True:
                    add(errors, "github external snapshot must keep external_mutation_still_pending=true")
                if snapshot.get("open_issues") != []:
                    add(errors, "github external snapshot should record no visible open issues")
                if snapshot.get("required_labels_missing") != required_labels:
                    add(errors, "github external snapshot must show all required labels missing")
                expected_missing_titles = [
                    "[P0] v53 frozen benchmark canonicalization",
                    "[P0] D/E 30B-70B real evidence intake",
                    "[P1] v54 real free-running generation",
                    "[P1] v58 blind human review execution",
                    "[P2] v61 one-token logits parity",
                ]
                if snapshot.get("expected_issue_titles_missing") not in (None, expected_missing_titles):
                    add(errors, "github external snapshot must show all expected issue titles missing in pending mode")
                if snapshot.get("pr_cleanup_disposition_pending") not in (None, [5, 10]):
                    add(errors, "github external snapshot must show PR #5/#10 cleanup dispositions pending")
            observed_labels = snapshot.get("remote_labels_observed", [])
            for default_label in ["bug", "documentation", "enhancement", "wontfix"]:
                if default_label not in observed_labels:
                    add(errors, f"github external snapshot missing observed default label: {default_label}")
            prs = snapshot.get("prs", [])
            by_pr = {
                row.get("number"): row
                for row in prs
                if isinstance(row, dict) and isinstance(row.get("number"), int)
            }
            for number, title, is_draft, head_ref in [
                (5, "Draft: harden v50 auditor correctness replay contract", False, "pr2-slice-v50-auditor-correctness"),
                (10, "Draft: keep v56 expanded benchmark replay blocked", True, "pr2-slice-v56-ruler-longbench-expanded"),
            ]:
                row = by_pr.get(number)
                if not row:
                    add(errors, f"github external snapshot missing PR #{number}")
                    continue
                expected = {
                    "title": title,
                    "is_draft": is_draft,
                    "mergeable": "MERGEABLE",
                    "head_ref": head_ref,
                    "base_ref": "main",
                }
                if external_state_mode == "pending":
                    expected["state"] = "OPEN"
                    expected["labels"] = []
                for field, value in expected.items():
                    if row.get(field) != value:
                        add(errors, f"github external snapshot PR #{number} {field} must be {value!r}")
            notes = snapshot.get("gh_cli_notes", [])
            for note in [
                "gh issue list returned an empty open issue array",
                "gh pr view 5 and gh pr view 10 succeeded",
                "gh label list is unavailable in installed gh 2.4.0, so labels were read with gh api repos/:owner/:repo/labels",
            ]:
                if note not in notes:
                    add(errors, f"github external snapshot missing note: {note}")

    settings_snapshot_text = read(root, "docs/pm/github_settings_external_snapshot.json", errors)
    if settings_snapshot_text:
        try:
            settings_snapshot = json.loads(settings_snapshot_text)
        except json.JSONDecodeError as exc:
            add(errors, f"docs/pm/github_settings_external_snapshot.json invalid JSON: {exc}")
            settings_snapshot = {}
        if isinstance(settings_snapshot, dict):
            if settings_snapshot.get("repository") != "betelgeuze-kang/deep-learning1":
                add(errors, "github settings snapshot repository mismatch")
            if settings_snapshot.get("read_only") is not True:
                add(errors, "github settings snapshot must be read_only=true")
            repo = settings_snapshot.get("repo", {})
            if isinstance(repo, dict):
                expected_repo = {
                    "private": True,
                    "default_branch": "main",
                    "has_issues": True,
                    "allow_auto_merge": False,
                }
                if external_state_mode == "pending":
                    expected_repo.update(
                        {
                            "allow_squash_merge": True,
                            "allow_merge_commit": True,
                            "allow_rebase_merge": True,
                            "delete_branch_on_merge": False,
                        }
                    )
                for field, value in expected_repo.items():
                    if repo.get(field) != value:
                        add(errors, f"github settings snapshot repo.{field} must be {value!r}")
            else:
                add(errors, "github settings snapshot repo must be an object")
            workflow = settings_snapshot.get("workflow_permissions", {})
            if isinstance(workflow, dict):
                if workflow.get("default_workflow_permissions") != "read":
                    add(errors, "github settings snapshot workflow token default must be read")
                if workflow.get("can_approve_pull_request_reviews") is not False:
                    add(errors, "github settings snapshot workflow PR approval must be false")
            else:
                add(errors, "github settings snapshot workflow_permissions must be an object")
            actions = settings_snapshot.get("actions_permissions", {})
            if isinstance(actions, dict):
                if actions.get("enabled") is not True:
                    add(errors, "github settings snapshot Actions must be enabled")
                if "sha_pinning_required" not in actions:
                    add(errors, "github settings snapshot missing sha_pinning_required")
                if external_state_mode == "pending" and actions.get("sha_pinning_required") is not False:
                    add(errors, "github settings snapshot sha_pinning_required must be false in pending mode")
            else:
                add(errors, "github settings snapshot actions_permissions must be an object")
            protection = settings_snapshot.get("branch_protection", {})
            if isinstance(protection, dict):
                if external_state_mode == "pending":
                    if protection.get("status") != "unavailable":
                        add(errors, "github settings snapshot branch protection status must be unavailable")
                    if protection.get("http_status") != 403:
                        add(errors, "github settings snapshot branch protection http_status must be 403")
                    if "Upgrade to GitHub Pro" not in str(protection.get("reason", "")):
                        add(errors, "github settings snapshot branch protection reason missing plan limit")
            else:
                add(errors, "github settings snapshot branch_protection must be an object")
            if external_state_mode == "pending":
                deltas = settings_snapshot.get("settings_deltas", [])
                by_setting = {
                    row.get("setting"): row
                    for row in deltas
                    if isinstance(row, dict) and isinstance(row.get("setting"), str)
                }
                expected_deltas = {
                    "Automatically delete head branches": True,
                    "Default GITHUB_TOKEN permission": False,
                    "Require full SHA-pinned Actions": True,
                    "Merge method": True,
                    "Branch protection": True,
                    "CodeQL default setup": True,
                    "Secret scanning": True,
                    "Dependency graph and Dependabot alerts": True,
                }
                for setting, action_pending in expected_deltas.items():
                    row = by_setting.get(setting)
                    if not row:
                        add(errors, f"github settings snapshot missing delta: {setting}")
                        continue
                    if row.get("action_pending") is not action_pending:
                        add(errors, f"github settings snapshot {setting} action_pending must be {action_pending}")
                security_features = settings_snapshot.get("security_features")
                if not isinstance(security_features, dict):
                    add(errors, "github settings snapshot missing security_features")
                else:
                    required_security = [
                        "codeql_default_setup",
                        "secret_scanning",
                        "dependency_graph",
                        "vulnerability_alerts",
                        "dependabot_alerts",
                    ]
                    for key in required_security:
                        if key not in security_features:
                            add(errors, f"github settings snapshot missing security feature: {key}")

    audit_text = read(root, "docs/pm/pasted_goal_completion_audit.json", errors)
    if audit_text:
        try:
            audit = json.loads(audit_text)
        except json.JSONDecodeError as exc:
            add(errors, f"docs/pm/pasted_goal_completion_audit.json invalid JSON: {exc}")
            audit = {}
        expected_state = "local_artifacts_verified_external_mutation_pending"
        if external_state_mode == "pending":
            if isinstance(audit, dict) and audit.get("completion_state") != expected_state:
                add(
                    errors,
                    "docs/pm/pasted_goal_completion_audit.json completion_state "
                    f"must be {expected_state}",
                )
        complete_mode_blockers = (
            audit.get("latest_read_only_complete_mode_blockers", []) if isinstance(audit, dict) else []
        )
        required_complete_mode_blockers = [
            "Required GitHub labels are still missing.",
            "The five evidence blocker issues are still missing.",
            "PR #5 and PR #10 cleanup comments are still missing.",
            "PR #5 and PR #10 are still open, so final PR cleanup disposition remains pending.",
            "GitHub settings still require delete-head-branch, squash-only merge policy, branch protection, full SHA-pinned Actions, CodeQL, secret scanning, dependency graph, vulnerability alerts, and Dependabot alerts evidence.",
        ]
        for blocker in required_complete_mode_blockers:
            if blocker not in complete_mode_blockers:
                add(errors, f"completion audit missing latest complete-mode blocker: {blocker}")
        required_verification = [
            "python3 scripts/refresh_github_external_snapshots.py",
            "python3 tools/verify_github_governance_commands.py",
            "python3 tools/verify_pr_cleanup_disposition_commands.py",
            "python3 tools/verify_repo_governance.py .",
            "python3 tools/verify_github_external_state.py --mode pending .",
            "python3 tools/verify_github_external_state.py --mode partial . after partial approved external mutations and refreshed snapshots",
            "tools/verify_ci_workflows.py .",
            "tools/verify_artifact.py typed-readiness readiness/typed_ready.json --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv",
            "./scripts/ai-verify.sh",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh after partial approved external mutations and refreshed snapshots",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh after approved external mutations and refreshed snapshots",
        ]
        verification = audit.get("canonical_verification", []) if isinstance(audit, dict) else []
        for command in required_verification:
            if command not in verification:
                add(errors, f"completion audit missing canonical verification: {command}")
        requirements = audit.get("requirements", []) if isinstance(audit, dict) else []
        by_id = {
            row.get("id"): row
            for row in requirements
            if isinstance(row, dict) and isinstance(row.get("id"), int)
        }
        if len(requirements) != 8:
            add(errors, f"completion audit should contain 8 requirements, got {len(requirements)}")
        expected_status = {
            1: ("local_complete_verified", False),
            2: ("local_complete_verified", False),
            3: ("local_artifacts_verified_external_issue_creation_pending", True),
            4: ("local_complete_verified", False),
            5: ("local_complete_verified", False),
            6: ("local_boundary_complete_public_license_decision_pending", True),
            7: ("local_plan_verified_external_pr_disposition_pending", True),
            8: ("local_checklist_verified_external_settings_pending", True),
        }
        status_items = expected_status.items() if external_state_mode == "pending" else []
        for req_id, (status, external_required) in status_items:
            row = by_id.get(req_id)
            if not row:
                add(errors, f"completion audit missing requirement id {req_id}")
                continue
            if row.get("status") != status:
                add(errors, f"completion audit requirement {req_id} status must be {status}")
            if row.get("external_action_required") is not external_required:
                add(
                    errors,
                    "completion audit requirement "
                    f"{req_id} external_action_required must be {external_required}",
                )
            for field in ["requirement", "evidence", "verification"]:
                if not row.get(field):
                    add(errors, f"completion audit requirement {req_id} missing non-empty {field}")
            if external_required and not row.get("external_action"):
                add(errors, f"completion audit requirement {req_id} missing external_action")
            if req_id == 7:
                action = str(row.get("external_action", ""))
                for snippet in [
                    "comment on PR #5/#10",
                    "only pre-verified disposition command packet is the superseded-close path",
                    "merge or rebase requires separate review and approval",
                    "not merely commented",
                ]:
                    if snippet not in action:
                        add(errors, f"completion audit requirement 7 external_action missing: {snippet}")

    audit_md = read(root, "docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md", errors)
    require_all(
        audit_md,
        [
            "# Pasted Goal Completion Audit",
            "Overall state: local artifacts verified; external GitHub mutation remains",
            "Sync central readiness and split v53/v54 readiness rows",
            "GitHub issue creation pending",
            "public license decision pending",
            "external PR disposition pending",
            "pr_cleanup_disposition_pending",
            "external settings pending",
            "Do not create GitHub issues, mutate labels, comment on PRs, close PRs, merge",
            "scripts/refresh_github_external_snapshots.py",
            "tools/verify_github_governance_commands.py",
            "tools/verify_github_external_state.py",
            "python3 tools/verify_github_external_state.py --mode partial .",
            "DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh",
            "Latest Read-Only External State",
            "complete mode",
            "Required GitHub labels are still missing.",
            "The five evidence blocker issues are still missing.",
            "PR #5 and PR #10 cleanup comments are still missing.",
            "PR #5 and PR #10 are still open",
            "GitHub settings still require delete-head-branch",
            "scripts/print_github_governance_commands.py",
            "docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md",
            "docs/pm/github_settings_checklist.json",
        ],
        "docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md",
        errors,
    )


def main(argv: list[str]) -> int:
    root = Path(argv[0]).resolve() if argv else Path.cwd()
    errors: list[str] = []
    verify_readmes(root, errors)
    verify_templates(root, errors)
    verify_policy_docs(root, errors)
    verify_orchestration_docs(root, errors)
    verify_backlog_and_labels(root, errors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("repo governance verify ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
