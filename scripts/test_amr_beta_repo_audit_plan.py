#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_audit_plan.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_repo_audit_plan.py"
VALIDATOR = ROOT / "scripts" / "amr_beta_repo_intake_validate.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def create_repo(root: Path, index: int) -> tuple[Path, str]:
    repo = root / f"repo {index:02d}"
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
        mode = "full" if index == 10 else "quick"
        lines.append(
            f"| {case_prefix}-{index:02d} | {repo} | {head} | true | maintainer-{index:02d}-contact | {mode} | real_benchmark | true | human supplied |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        repos = [create_repo(tmp, index) for index in range(1, 11)]
        intake = tmp / "repo intake.md"
        write_intake(intake, repos)
        artifact_root = tmp / "audit artifacts"
        out_json = tmp / "repo_audit_plan.json"
        out_md = tmp / "repo_audit_plan.md"
        out_commands = tmp / "repo_audit_plan_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(intake),
            "--artifact-root",
            str(artifact_root),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--out-commands-sh",
            str(out_commands),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        validate = run([sys.executable, str(VALIDATOR), str(intake), "--json"], cwd=ROOT)
        assert validate.returncode == 0, validate.stderr
        intake_status, _ = json.JSONDecoder().raw_decode(validate.stdout.lstrip())
        assert payload["schema"] == "amr_beta_repo_audit_plan.v1"
        assert payload["repo_intake_sha256"] == sha256_file(intake)
        assert payload["valid_repo_rows"] == 10
        assert payload["repo_snapshot_lock_sha256"] == intake_status["repo_snapshot_lock_sha256"]
        assert payload["repo_snapshot_lock_row_count"] == 10
        assert payload["repo_snapshot_lock_rows"] == intake_status["repo_snapshot_lock_rows"]
        assert payload["ready_for_real_benchmark_audit_plan"] == 1
        assert payload["runs_audit"] == 0
        assert payload["runs_label_template_generation"] == 0
        assert payload["writes_reviewer_packets"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["writes_operator_command_script"] == 1
        assert payload["operator_commands_script"] == str(out_commands.resolve())
        assert payload["operator_commands_script_sha256"] == sha256_file(out_commands)
        assert payload["operator_commands_script_command_count"] == 51
        assert payload["input_path_guard_passed"] == 1
        assert payload["output_path_guard_passed"] == 1
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert len(payload["per_repo"]) == 10
        assert payload["operator_command_count"] == 51
        first = payload["per_repo"][0]
        audit_parts = shlex.split(first["audit_command"])
        assert audit_parts[0] == "./scripts/audit_my_repo.sh"
        assert audit_parts[1] == str(repos[0][0])
        assert audit_parts[audit_parts.index("--namespace") + 1] == "real_benchmark"
        assert "--confirm-real-benchmark-namespace" in audit_parts
        assert audit_parts[audit_parts.index("--out") + 1] == str(artifact_root / "case-01_audit")
        assert "'" in first["audit_command"]
        audit_verify_parts = shlex.split(first["audit_verify_command"])
        assert audit_verify_parts == [
            "./scripts/audit_my_repo.sh",
            "--verify-existing",
            str(artifact_root / "case-01_audit"),
        ]
        template_parts = shlex.split(first["label_template_command"])
        assert template_parts[1] == "scripts/audit_my_repo_label_template.py"
        assert template_parts[template_parts.index("--case-id") + 1] == "case-01"
        template_verify_parts = shlex.split(first["label_template_verify_command"])
        assert template_verify_parts == [
            "python3",
            "scripts/audit_my_repo_label_template.py",
            "--verify-existing",
            str(artifact_root / "case-01_label_template"),
        ]
        assert "--per-case-out-root" in shlex.split(payload["aggregate_reviewer_packet_command"])
        markdown = out_md.read_text(encoding="utf-8")
        assert "runs_audit: 0" in markdown
        assert "repo_snapshot_lock_sha256: sha256:" in markdown
        assert "input_path_guard_passed: 1" in markdown
        assert "output_path_guard_passed: 1" in markdown
        assert "writes_operator_command_script: 1" in markdown
        assert "Aggregate Reviewer Packet Command" in markdown
        command_script = out_commands.read_text(encoding="utf-8")
        assert command_script.startswith("#!/usr/bin/env bash\nset -euo pipefail\n")
        assert f"# repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}" in command_script
        assert f"# operator_commands_sha256: {payload['operator_commands_sha256']}" in command_script
        assert "# operator_command_count: 51" in command_script
        assert command_script.count("# command ") == 51
        for command in payload["operator_commands"]:
            assert command in command_script

        dirty = tmp / "dirty.md"
        write_intake(dirty, repos)
        (repos[0][0] / "UNTRACKED.txt").write_text("dirty\n", encoding="utf-8")
        proc = run_tool(
            "--repo-intake",
            str(dirty),
            "--out-json",
            str(tmp / "dirty_plan.json"),
        )
        assert proc.returncode == 1
        assert "repo_dirty" in proc.stderr
        assert not (tmp / "dirty_plan.json").exists()
        (repos[0][0] / "UNTRACKED.txt").unlink()

        unsafe_artifact_root = tmp / "unsafe_artifact.md"
        write_intake(unsafe_artifact_root, repos)
        proc = run_tool(
            "--repo-intake",
            str(unsafe_artifact_root),
            "--artifact-root",
            str(repos[0][0] / "audit_artifacts"),
            "--out-json",
            str(tmp / "unsafe_artifact_plan.json"),
        )
        assert proc.returncode == 1
        assert "artifact_root must not be inside target repo" in proc.stderr
        assert not (tmp / "unsafe_artifact_plan.json").exists()

        unsafe_commands_sh = repos[0][0] / "repo_audit_plan_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(intake),
            "--artifact-root",
            str(artifact_root),
            "--out-json",
            str(tmp / "unsafe_commands_plan.json"),
            "--out-commands-sh",
            str(unsafe_commands_sh),
            "--json",
        )
        assert proc.returncode == 1
        unsafe_commands_payload = json.loads(proc.stdout)
        assert "out_commands_sh must not be inside target repo" in proc.stderr
        assert "out_commands_sh must not be inside target repo" in unsafe_commands_payload["errors"][0]
        assert not unsafe_commands_sh.exists()
        assert not (tmp / "unsafe_commands_plan.json").exists()

        unsafe_out_json = repos[0][0] / "repo_audit_plan.json"
        unsafe_out_md = repos[0][0] / "repo_audit_plan.md"
        proc = run_tool(
            "--repo-intake",
            str(intake),
            "--artifact-root",
            str(artifact_root),
            "--out-json",
            str(unsafe_out_json),
            "--out-md",
            str(unsafe_out_md),
            "--json",
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert "out_json must not be inside target repo" in proc.stderr
        assert "out_md must not be inside target repo" in proc.stderr
        assert "out_json must not be inside target repo" in unsafe_payload["errors"][0]
        assert not unsafe_out_json.exists()
        assert not unsafe_out_md.exists()

        ignored_intake_name = "ignored_repo_audit_intake.md"
        (repos[0][0] / ".gitignore").write_text(f"{ignored_intake_name}\n", encoding="utf-8")
        assert run(["git", "add", ".gitignore"], cwd=repos[0][0]).returncode == 0
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
                "ignore unsafe audit intake sheet",
            ],
            cwd=repos[0][0],
        )
        assert commit.returncode == 0, commit.stderr
        head = run(["git", "rev-parse", "HEAD"], cwd=repos[0][0])
        assert head.returncode == 0
        repos[0] = (repos[0][0], head.stdout.strip())

        unsafe_input = repos[0][0] / ignored_intake_name
        write_intake(unsafe_input, repos)
        status = run(["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=repos[0][0])
        assert status.returncode == 0
        assert status.stdout.strip() == ""
        proc = run_tool(
            "--repo-intake",
            str(unsafe_input),
            "--artifact-root",
            str(artifact_root),
            "--out-json",
            str(tmp / "unsafe_input_plan.json"),
            "--json",
        )
        assert proc.returncode == 1
        assert "input_intake must not be inside target repo" in proc.stderr
        assert not (tmp / "unsafe_input_plan.json").exists()

        example = tmp / "example.md"
        write_intake(example, repos, case_prefix="EXAMPLE")
        proc = run_tool(
            "--repo-intake",
            str(example),
            "--out-json",
            str(tmp / "example_plan.json"),
        )
        assert proc.returncode == 1
        assert "case_id must not be example/placeholder" in proc.stderr

    print("AMR beta repo audit plan smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
