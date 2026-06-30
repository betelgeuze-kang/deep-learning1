#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_intake_validate.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_repo_intake_validate.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def create_repo(root: Path, index: int) -> tuple[Path, str]:
    repo = root / f"repo-{index:02d}"
    repo.mkdir()
    assert run(["git", "init", "-q"], cwd=repo).returncode == 0
    (repo / "README.md").write_text(f"# repo {index}\n", encoding="utf-8")
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


def write_intake(path: Path, repos: list[tuple[Path, str]], *, case_prefix: str = "case") -> None:
    lines = [
        "| case_id | repo_path | expected_repo_git_head | clean_worktree | owner_or_maintainer_contact | audit_mode | namespace | real_benchmark_namespace_confirmed | notes |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for index, (repo, head) in enumerate(repos, start=1):
        lines.append(
            f"| {case_prefix}-{index:02d} | {repo} | {head} | true | maintainer-{index:02d}-contact | quick | real_benchmark | true | human supplied |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_tool(path: Path, *extra: str) -> subprocess.CompletedProcess:
    return run([sys.executable, str(TOOL), str(path), *extra], cwd=ROOT)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        repos = [create_repo(tmp, index) for index in range(10)]

        intake = tmp / "repo_intake.md"
        write_intake(intake, repos)
        proc = run_tool(intake)
        assert proc.returncode == 0, proc.stderr
        assert "repo_intake_validate: ok" in proc.stdout

        proc = run_tool(intake, "--json")
        assert proc.returncode == 0, proc.stderr
        assert '"ready_for_real_benchmark_audit": 1' in proc.stdout
        assert '"design_partner_beta_candidate_ready": 0' in proc.stdout
        assert '"owner_or_maintainer_contact_present": 1' in proc.stdout
        assert '"input_intake_sha256": "sha256:' in proc.stdout
        assert '"repo_snapshot_lock_sha256": "sha256:' in proc.stdout
        assert '"runs_audit": 0' in proc.stdout
        assert '"creates_benchmark_evidence": 0' in proc.stdout
        assert "maintainer-01-contact" not in proc.stdout

        status_json = tmp / "repo_intake_status.json"
        status_md = tmp / "repo_intake_status.md"
        proc = run_tool(intake, "--out-json", str(status_json), "--out-md", str(status_md))
        assert proc.returncode == 0, proc.stderr
        status = json.loads(status_json.read_text(encoding="utf-8"))
        assert status["ready_for_real_benchmark_audit"] == 1
        assert status["input_intake"] == str(intake.resolve())
        assert status["input_intake_sha256"].startswith("sha256:")
        assert status["valid_repo_rows"] == 10
        assert status["runs_audit"] == 0
        assert status["creates_benchmark_evidence"] == 0
        assert status["repo_snapshot_lock_sha256"].startswith("sha256:")
        assert len(status["row_statuses"]) == 10
        assert status["row_statuses"][0]["clean_worktree_actual"] == 1
        assert status["row_statuses"][0]["owner_or_maintainer_contact_present"] == 1
        assert "maintainer-01-contact" not in status_json.read_text(encoding="utf-8")
        status_md_text = status_md.read_text(encoding="utf-8")
        assert "AMR Beta Repo Intake Status" in status_md_text
        assert "input_intake_sha256: sha256:" in status_md_text
        assert "creates_benchmark_evidence: 0" in status_md_text

        dirty = tmp / "dirty.md"
        write_intake(dirty, repos)
        (repos[0][0] / "UNTRACKED.txt").write_text("dirty\n", encoding="utf-8")
        dirty_status_json = tmp / "dirty_repo_intake_status.json"
        proc = run_tool(dirty, "--out-json", str(dirty_status_json))
        assert proc.returncode == 1
        assert "repo_dirty" in proc.stderr
        dirty_status = json.loads(dirty_status_json.read_text(encoding="utf-8"))
        assert dirty_status["ready_for_real_benchmark_audit"] == 0
        assert dirty_status["repo_snapshot_lock_sha256"].startswith("sha256:")
        assert dirty_status["row_statuses"][0]["valid"] == 0
        assert dirty_status["row_statuses"][0]["clean_worktree_actual"] == 0
        assert any("repo_dirty" in error for error in dirty_status["row_statuses"][0]["errors"])
        (repos[0][0] / "UNTRACKED.txt").unlink()

        example = tmp / "example.md"
        write_intake(example, repos, case_prefix="EXAMPLE")
        proc = run_tool(example)
        assert proc.returncode == 1
        assert "case_id must not be example/placeholder" in proc.stderr

        mismatch = tmp / "mismatch.md"
        bad_rows = [(repo, "0" * 40) if index == 0 else (repo, head) for index, (repo, head) in enumerate(repos)]
        write_intake(mismatch, bad_rows)
        proc = run_tool(mismatch)
        assert proc.returncode == 1
        assert "expected_repo_git_head mismatch" in proc.stderr

        invalid_contact = tmp / "invalid_contact.md"
        write_intake(invalid_contact, repos)
        invalid_contact.write_text(
            invalid_contact.read_text(encoding="utf-8").replace(
                "maintainer-01-contact", "maintainer-01@review.invalid"
            ),
            encoding="utf-8",
        )
        proc = run_tool(invalid_contact)
        assert proc.returncode == 1
        assert "owner_or_maintainer_contact must be human-supplied" in proc.stderr

        placeholder_notes = tmp / "placeholder_notes.md"
        write_intake(placeholder_notes, repos)
        placeholder_notes.write_text(
            placeholder_notes.read_text(encoding="utf-8").replace(
                "human supplied", "synthetic fixture placeholder", 1
            ),
            encoding="utf-8",
        )
        proc = run_tool(placeholder_notes)
        assert proc.returncode == 1
        assert "notes must not mark the row as example/placeholder/synthetic/fixture" in proc.stderr

        negated_notes = tmp / "negated_notes.md"
        write_intake(negated_notes, repos)
        negated_notes.write_text(
            negated_notes.read_text(encoding="utf-8").replace(
                "human supplied", "confirmed not synthetic and not a fixture", 1
            ),
            encoding="utf-8",
        )
        proc = run_tool(negated_notes)
        assert proc.returncode == 0, proc.stderr

        synthetic_flag_csv = tmp / "synthetic_flag.csv"
        lines = [
            "case_id,repo_path,expected_repo_git_head,clean_worktree,owner_or_maintainer_contact,audit_mode,namespace,real_benchmark_namespace_confirmed,synthetic,notes",
        ]
        for index, (repo, head) in enumerate(repos, start=1):
            synthetic = "true" if index == 1 else "false"
            lines.append(
                f"case-{index:02d},{repo},{head},true,maintainer-{index:02d}-contact,quick,real_benchmark,true,{synthetic},human supplied"
            )
        synthetic_flag_csv.write_text("\n".join(lines) + "\n", encoding="utf-8")
        proc = run_tool(synthetic_flag_csv)
        assert proc.returncode == 1
        assert "synthetic must not be true for real repo intake" in proc.stderr

        test_fixture_flag_csv = tmp / "test_fixture_flag.csv"
        lines = [
            "case_id,repo_path,expected_repo_git_head,clean_worktree,owner_or_maintainer_contact,audit_mode,namespace,real_benchmark_namespace_confirmed,test_fixture,notes",
        ]
        for index, (repo, head) in enumerate(repos, start=1):
            test_fixture = "true" if index == 1 else "false"
            lines.append(
                f"case-{index:02d},{repo},{head},true,maintainer-{index:02d}-contact,quick,real_benchmark,true,{test_fixture},human supplied"
            )
        test_fixture_flag_csv.write_text("\n".join(lines) + "\n", encoding="utf-8")
        proc = run_tool(test_fixture_flag_csv)
        assert proc.returncode == 1
        assert "test_fixture must not be true for real repo intake" in proc.stderr

        source_type_csv = tmp / "source_type.csv"
        lines = [
            "case_id,repo_path,expected_repo_git_head,clean_worktree,owner_or_maintainer_contact,audit_mode,namespace,real_benchmark_namespace_confirmed,source_type,notes",
        ]
        for index, (repo, head) in enumerate(repos, start=1):
            source_type = "synthetic" if index == 1 else "real"
            lines.append(
                f"case-{index:02d},{repo},{head},true,maintainer-{index:02d}-contact,quick,real_benchmark,true,{source_type},human supplied"
            )
        source_type_csv.write_text("\n".join(lines) + "\n", encoding="utf-8")
        proc = run_tool(source_type_csv)
        assert proc.returncode == 1
        assert "optional metadata source_type must not mark the row as example/placeholder/synthetic/fixture" in proc.stderr

        small = tmp / "small.md"
        write_intake(small, repos[:9])
        proc = run_tool(small)
        assert proc.returncode == 1
        assert "below required minimum 10" in proc.stderr

    print("AMR beta repo intake validator smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
