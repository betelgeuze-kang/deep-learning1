#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_intake_discover.py."""
from __future__ import annotations

import json
import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_repo_intake_discover.py"
DISCOVER_SPEC = importlib.util.spec_from_file_location("amr_beta_repo_intake_discover", TOOL)
assert DISCOVER_SPEC and DISCOVER_SPEC.loader
DISCOVER_MODULE = importlib.util.module_from_spec(DISCOVER_SPEC)
DISCOVER_SPEC.loader.exec_module(DISCOVER_MODULE)


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def create_repo(root: Path, name: str) -> tuple[Path, str]:
    repo = root / name
    repo.mkdir()
    assert run(["git", "init", "-q"], cwd=repo).returncode == 0
    (repo / "README.md").write_text(f"# {name}\n", encoding="utf-8")
    assert run(["git", "add", "README.md"], cwd=repo).returncode == 0
    commit = run(
        [
            "git",
            "-c",
            "user.name=AMR Test",
            "-c",
            "user.email=amr-test@example.invalid",
            "commit",
            "-q",
            "-m",
            "init",
        ],
        cwd=repo,
    )
    assert commit.returncode == 0, commit.stderr
    head = run(["git", "rev-parse", "HEAD"], cwd=repo)
    assert head.returncode == 0
    return repo, head.stdout.strip()


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert "current_artifact_repo" in DISCOVER_MODULE.path_risk_flags(ROOT / "nested-artifact-repo")

        repo_a, head_a = create_repo(tmp, "repo-a")
        repo_b, head_b = create_repo(tmp, "repo-b")
        repo_dirty, _head_dirty = create_repo(tmp, "repo-dirty")
        (repo_dirty / "UNTRACKED.txt").write_text("dirty\n", encoding="utf-8")
        repo_status_bad, head_status_bad = create_repo(tmp, "repo-status-bad")
        (repo_status_bad / ".git" / "index").write_bytes(b"bad index")
        nested_parent = repo_b / "vendor"
        nested_parent.mkdir()
        nested_repo, head_nested = create_repo(nested_parent, "nested-repo")
        (tmp / "not-a-repo").mkdir()

        out_json = tmp / "discovery.json"
        out_md = tmp / "discovery.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(tmp),
                "--out-json",
                str(out_json),
                "--out-md",
                str(out_md),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_repo_intake_discover.v1"
        assert payload["candidate_repo_count"] == 5
        assert payload["candidate_repos_with_clean_head"] == 2
        assert payload["candidate_repos_with_path_risk"] == 0
        assert payload["candidate_repos_with_clean_head_and_path_risk"] == 0
        assert payload["candidate_repos_with_clean_head_and_no_path_risk"] == 2
        assert payload["clean_risk_free_candidate_shortfall_to_minimum"] == 8
        assert payload["repo_intake_rows_counted"] == 0
        assert payload["ready_for_repo_intake"] == 0
        assert payload["candidate_rows_cannot_count_without_human_contact"] == 1
        assert payload["runs_audit"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert out_json.exists()
        assert out_md.exists()
        written = json.loads(out_json.read_text(encoding="utf-8"))
        assert written == payload
        by_repo = {row["repo_path"]: row for row in payload["candidates"]}
        assert by_repo[str(repo_a.resolve())]["actual_repo_git_head"] == head_a.lower()
        assert by_repo[str(repo_b.resolve())]["actual_repo_git_head"] == head_b.lower()
        assert by_repo[str(nested_repo.resolve())]["actual_repo_git_head"] == head_nested.lower()
        assert by_repo[str(repo_status_bad.resolve())]["actual_repo_git_head"] == head_status_bad.lower()
        assert by_repo[str(repo_a.resolve())]["counts_for_repo_intake"] == 0
        assert by_repo[str(repo_a.resolve())]["owner_or_maintainer_contact_required"] == 1
        assert by_repo[str(repo_dirty.resolve())]["clean_worktree_actual"] == 0
        assert by_repo[str(repo_status_bad.resolve())]["clean_worktree_actual"] is None
        assert by_repo[str(repo_status_bad.resolve())]["repo_status_readable"] == 0
        assert "status_unreadable" in by_repo[str(repo_status_bad.resolve())]["blockers_before_counting"]
        assert "dirty_or_unknown_worktree" in by_repo[str(repo_dirty.resolve())]["blockers_before_counting"]
        assert "dirty_or_unknown_worktree" in by_repo[str(repo_status_bad.resolve())]["blockers_before_counting"]
        assert "human_owner_or_maintainer_contact_required" in by_repo[str(repo_a.resolve())]["blockers_before_counting"]
        assert "AMR Beta Repo Discovery Candidates" in out_md.read_text(encoding="utf-8")

        runner_parent = tmp / "actions-runner" / "_work" / "demo"
        runner_parent.mkdir(parents=True)
        runner_repo, _head_runner = create_repo(runner_parent, "demo")
        risk_out = tmp / "risk_discovery.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(tmp),
                "--out-json",
                str(risk_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        risk_payload = json.loads(proc.stdout)
        assert risk_payload["candidate_repos_with_path_risk"] == 1
        assert risk_payload["candidate_repos_with_clean_head_and_path_risk"] == 1
        assert risk_payload["candidate_repos_with_clean_head_and_no_path_risk"] == 2
        risk_by_repo = {row["repo_path"]: row for row in risk_payload["candidates"]}
        runner_row = risk_by_repo[str(runner_repo.resolve())]
        assert "runner_worktree_path" in runner_row["path_risk_flags"]
        assert runner_row["path_risk_flag_count"] == 1
        assert runner_row["human_real_repo_source_confirmation_required"] == 1
        assert "human_real_repo_source_confirmation_required" in runner_row["blockers_before_counting"]

        hidden_parent = tmp / ".codex" / "plugins"
        hidden_parent.mkdir(parents=True)
        hidden_repo, _head_hidden = create_repo(hidden_parent, "plugin-repo")
        hidden_out = tmp / "hidden_discovery.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(tmp),
                "--include-hidden",
                "--out-json",
                str(hidden_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        hidden_payload = json.loads(proc.stdout)
        hidden_by_repo = {row["repo_path"]: row for row in hidden_payload["candidates"]}
        hidden_row = hidden_by_repo[str(hidden_repo.resolve())]
        assert "hidden_path" in hidden_row["path_risk_flags"]
        assert "codex_internal_path" in hidden_row["path_risk_flags"]

        nested = repo_a / "nested" / "deeper"
        nested.mkdir(parents=True)
        nested_out = tmp / "nested_discovery.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(nested),
                "--out-json",
                str(nested_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        nested_payload = json.loads(proc.stdout)
        assert nested_payload["candidate_repo_count"] == 1
        assert nested_payload["candidates"][0]["repo_path"] == str(repo_a.resolve())
        assert nested_payload["candidates"][0]["repo_git_worktree_confirmed"] == 1

        unsafe_out = repo_a / "discovery.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(tmp),
                "--out-json",
                str(unsafe_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["ready_for_repo_intake"] == 0
        assert "out_json must not be inside target repo" in proc.stderr
        assert "out_json must not be inside a git worktree" in proc.stderr
        assert not unsafe_out.exists()

        skipped_parent = tmp / "skipped" / "deep"
        skipped_parent.mkdir(parents=True)
        skipped_repo, _head_skipped = create_repo(skipped_parent, "repo-skipped-by-depth")
        skipped_unsafe_out = skipped_repo / "discovery.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(tmp),
                "--max-depth",
                "0",
                "--out-json",
                str(skipped_unsafe_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        skipped_payload = json.loads(proc.stdout)
        assert skipped_payload["candidate_repo_count"] == 0
        assert "out_json must not be inside a git worktree" in proc.stderr
        assert not skipped_unsafe_out.exists()

        missing = tmp / "missing"
        proc = run([sys.executable, str(TOOL), "--root", str(missing), "--json"], cwd=ROOT)
        assert proc.returncode == 1
        missing_payload = json.loads(proc.stdout)
        assert missing_payload["candidate_repo_count"] == 0
        assert "--root must be an existing directory" in proc.stderr

    print("AMR beta repo intake discovery smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
