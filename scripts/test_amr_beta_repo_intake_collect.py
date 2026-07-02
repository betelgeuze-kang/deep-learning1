#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_intake_collect.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_repo_intake_collect.py"
VALIDATOR = ROOT / "scripts" / "amr_beta_repo_intake_validate.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def load_json_prefix(text: str) -> dict:
    payload, _ = json.JSONDecoder().raw_decode(text)
    return payload


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


def collect_cmd(repos: list[tuple[Path, str]], out: Path, *extra: str) -> list[str]:
    cmd = [sys.executable, str(TOOL)]
    for index, (repo, _head) in enumerate(repos, start=1):
        cmd.extend(["--repo", str(repo), "--contact", f"maintainer-{index:02d}-contact"])
    cmd.extend(["--confirm-real-benchmark-namespace", "--out", str(out), "--json", *extra])
    return cmd


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        repos = [create_repo(tmp, index) for index in range(10)]

        intake = tmp / "repo_intake.md"
        proc = run(collect_cmd(repos, intake), cwd=ROOT)
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_repo_intake_collect.v1"
        assert payload["ready_for_repo_intake_sheet"] == 1
        assert payload["writes_repo_intake_sheet"] == 1
        assert payload["valid_repo_rows"] == 10
        assert payload["repo_snapshot_lock_row_count"] == 10
        assert payload["generated_intake"] == str(intake.resolve())
        assert payload["generated_intake_sha256"].startswith("sha256:")
        assert payload["runs_audit"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert "maintainer-01-contact" not in proc.stdout
        assert intake.exists()

        validate = run([sys.executable, str(VALIDATOR), str(intake), "--json"], cwd=ROOT)
        assert validate.returncode == 0, validate.stderr
        validate_payload = load_json_prefix(validate.stdout)
        assert validate_payload["ready_for_real_benchmark_audit"] == 1
        assert validate_payload["valid_repo_rows"] == 10
        assert validate_payload["repo_snapshot_lock_row_count"] == 10
        assert validate_payload["creates_benchmark_evidence"] == 0
        assert "maintainer-01-contact" not in validate.stdout

        csv_intake = tmp / "repo_intake.csv"
        proc = run(collect_cmd(repos, csv_intake, "--format", "csv"), cwd=ROOT)
        assert proc.returncode == 0, proc.stderr
        assert csv_intake.exists()
        validate_csv = run([sys.executable, str(VALIDATOR), str(csv_intake)], cwd=ROOT)
        assert validate_csv.returncode == 0, validate_csv.stderr

        missing_contact = tmp / "missing_contact.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo",
                str(repos[0][0]),
                "--out",
                str(missing_contact),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 2
        assert not missing_contact.exists()

        missing_namespace_confirmation = tmp / "missing_namespace_confirmation.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo",
                str(repos[0][0]),
                "--contact",
                "maintainer-01-contact",
                "--out",
                str(missing_namespace_confirmation),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        missing_namespace_payload = json.loads(proc.stdout)
        assert missing_namespace_payload["ready_for_repo_intake_sheet"] == 0
        assert "--confirm-real-benchmark-namespace is required" in proc.stderr
        assert not missing_namespace_confirmation.exists()

        dirty_out = tmp / "dirty_intake.md"
        (repos[0][0] / "UNTRACKED.txt").write_text("dirty\n", encoding="utf-8")
        proc = run(collect_cmd(repos, dirty_out), cwd=ROOT)
        assert proc.returncode == 1
        dirty_payload = json.loads(proc.stdout)
        assert dirty_payload["ready_for_repo_intake_sheet"] == 0
        assert dirty_payload["writes_repo_intake_sheet"] == 0
        assert any("repo_dirty" in error for error in dirty_payload["errors"])
        assert not dirty_out.exists()
        (repos[0][0] / "UNTRACKED.txt").unlink()

        unsafe_out = repos[0][0] / "repo_intake.md"
        proc = run(collect_cmd(repos, unsafe_out), cwd=ROOT)
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["ready_for_repo_intake_sheet"] == 0
        assert unsafe_payload["writes_repo_intake_sheet"] == 0
        assert "out must not be inside target repo" in proc.stderr
        assert not unsafe_out.exists()

        raw_env_out_target = tmp / "raw_env_intake_target.md"
        raw_env_out_symlink = tmp / ".env.repo_intake_collect_out"
        raw_env_out_symlink.symlink_to(raw_env_out_target)
        proc = run(collect_cmd(repos, raw_env_out_symlink, "--overwrite"), cwd=ROOT)
        assert proc.returncode == 1
        raw_env_payload = json.loads(proc.stdout)
        assert raw_env_payload["ready_for_repo_intake_sheet"] == 0
        assert raw_env_payload["writes_repo_intake_sheet"] == 0
        assert "out must not be .env-like" in proc.stderr
        assert not raw_env_out_target.exists()

        nested = repos[0][0] / "nested"
        nested.mkdir()
        unsafe_subdir_out = repos[0][0] / "subdir_repo_intake.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo",
                str(nested),
                "--contact",
                "maintainer-01-contact",
                "--confirm-real-benchmark-namespace",
                "--out",
                str(unsafe_subdir_out),
                "--json",
                "--min-repos",
                "1",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        unsafe_subdir_payload = json.loads(proc.stdout)
        assert unsafe_subdir_payload["ready_for_repo_intake_sheet"] == 0
        assert unsafe_subdir_payload["writes_repo_intake_sheet"] == 0
        assert "repo_path must be git worktree root" in proc.stderr
        assert "out must not be inside target repo" in proc.stderr
        assert not unsafe_subdir_out.exists()

    print("AMR beta repo intake collect smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
