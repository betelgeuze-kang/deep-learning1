#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def require(text: str, snippet: str, label: str, errors: list[str]) -> None:
    if snippet not in text:
        add(errors, f"{label} missing snippet: {snippet}")


def block_after(text: str, marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        return ""
    following = text[start + len(marker) :]
    next_top = following.find("\n[a-zA-Z0-9_-]")
    return following if next_top < 0 else following[:next_top]


def verify_ai_verify_workflow(root: Path, errors: list[str]) -> None:
    path = root / ".github" / "workflows" / "ai-verify.yml"
    if not path.is_file():
        add(errors, "missing .github/workflows/ai-verify.yml")
        return
    text = path.read_text(encoding="utf-8")
    for snippet in [
        "name: AI verify",
        "pull_request:",
        "push:\n    branches:\n      - main",
        "workflow_dispatch:",
        "contents: read",
        "concurrency:",
        "cancel-in-progress: true",
        "ai-verify:",
        "name: ai-verify.sh",
        "runs-on: [self-hosted, linux, x64]",
        "timeout-minutes: 30",
        "DLE_VERIFY_ENABLE_HIP: \"OFF\"",
        "AI_VERIFY_JOBS: \"2\"",
        "run: ./scripts/ai-verify.sh",
        # Pull-request code must be verified on an ephemeral GitHub-hosted
        # runner with a credential-free, SHA-pinned checkout, and must never
        # run on the persistent self-hosted runner.
        "pr-safe-verify:",
        "if: github.event_name == 'pull_request'",
        "runs-on: ubuntu-latest",
        "uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
        "persist-credentials: false",
        "fetch-depth: 1",
        "clean: true",
        # pr-safe-verify must run Python reference smokes and a C++ CPU
        # build/execution smoke on the ephemeral runner.
        "tests=(scripts/test_*.py)",
        "python3 \"$test_file\"",
        "cmake --build build",
        "bash experiments/test_v02_causal_next_byte_evaluation.sh",
        # The persistent runner is restricted to trusted main events, and its
        # temporary token-bearing remote URL must be removed even on failure.
        "(github.event_name == 'push' && github.ref == 'refs/heads/main') ||",
        "(github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')",
        "trap cleanup_remote EXIT",
        "cleanup_remote",
        "trap - EXIT",
    ]:
        require(text, snippet, str(path), errors)

    if "if: github.event_name != 'pull_request'" in text:
        add(
            errors,
            f"{path}: self-hosted ai-verify must be restricted to trusted main push/workflow_dispatch events",
        )


def verify_third_party_workflow(root: Path, errors: list[str]) -> None:
    path = root / ".github" / "workflows" / "third-party-rerun.yml"
    if not path.is_file():
        add(errors, "missing .github/workflows/third-party-rerun.yml")
        return
    text = path.read_text(encoding="utf-8")
    on_block = block_after(text, "on:\n")
    if "workflow_dispatch:" not in on_block:
        add(errors, "third-party workflow must be manual workflow_dispatch")
    for forbidden in ["pull_request:", "push:"]:
        if forbidden in on_block:
            add(errors, f"third-party workflow must not run automatically via {forbidden}")
    for snippet in [
        "name: Third-party rerun return",
        "third-party-rerun:",
        "name: third-party-rerun-return-manual",
        "runs-on: [self-hosted, linux, x64]",
        "timeout-minutes: 45",
        "if: ${{ inputs.upload_artifact == 'true' }}",
        "uses: actions/upload-artifact@v4",
        "retention-days: 1",
        "GitHub Actions self-hosted runner; automated reviewer, not a GitHub-hosted clean-room rerun.",
        # The dispatch input must be passed through an environment variable and
        # validated, never interpolated directly into the shell script body.
        "RETURN_ID_INPUT: ${{ inputs.return_id }}",
        "=~ ^[A-Za-z0-9._-]{1,80}$",
        '"$RETURN_ID_INPUT" == *".."*',
    ]:
        require(text, snippet, str(path), errors)
    # Forbid the previous pattern that inlined the untrusted input into the
    # shell script body (command-injection risk).
    if 'RETURN_ID_INPUT="${{' in text:
        add(errors, f"{path}: workflow_dispatch input must not be inlined into the run script; pass it via env and validate")


def verify_offline_suite_workflow(root: Path, errors: list[str]) -> None:
    path = root / ".github" / "workflows" / "offline-suite.yml"
    if not path.is_file():
        add(errors, "missing .github/workflows/offline-suite.yml")
        return
    text = path.read_text(encoding="utf-8")
    # The offline lane must stay fully GitHub-hosted (no self-hosted runner).
    if "[self-hosted" in text:
        add(errors, f"{path}: offline suite must not use a self-hosted runner")
    for snippet in [
        "name: Offline evidence suite",
        "offline-suite:",
        "runs-on: ubuntu-latest",
        "uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
        "persist-credentials: false",
        "matrix:",
        "bash scripts/run_offline_suite.sh --shard",
    ]:
        require(text, snippet, str(path), errors)
    if "run: scripts/run_offline_suite.sh" in text:
        add(errors, f"{path}: offline suite must invoke run_offline_suite.sh through bash for clean checkout compatibility")


def main(argv: list[str]) -> int:
    root = Path(argv[0]).resolve() if argv else Path.cwd()
    errors: list[str] = []
    verify_ai_verify_workflow(root, errors)
    verify_third_party_workflow(root, errors)
    verify_offline_suite_workflow(root, errors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("ci workflow verify ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
