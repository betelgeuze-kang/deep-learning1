#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_maintainer_feedback_packet.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

import amr_beta_benchmark_input_prepare as benchmark_inputs
import amr_beta_maintainer_feedback_packet as feedback_packet

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_maintainer_feedback_packet.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


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


def write_repo_intake(path: Path, repos: list[tuple[str, Path, str]]) -> None:
    lines = [
        "| case_id | repo_path | expected_repo_git_head | clean_worktree | owner_or_maintainer_contact | audit_mode | namespace | real_benchmark_namespace_confirmed | notes |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for case_id, repo, head in repos:
        lines.append(
            f"| {case_id} | {repo} | {head} | true | {case_id}-maintainer-contact | quick | real_benchmark | true | human supplied |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_label_intake(path: Path, rows: list[dict]) -> None:
    path.mkdir()
    write_jsonl(path / "benchmark_labels.jsonl", rows)


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert feedback_packet.is_forbidden_env_path(Path(".env.secrets") / "feedback.jsonl")
        assert feedback_packet.is_forbidden_env_path(tmp / ".env.secrets" / "feedback_packet")
        assert not feedback_packet.is_forbidden_env_path(tmp / "feedback_packet")
        repos = [(f"case-{index:02d}", *create_repo(tmp, index)) for index in range(1, 4)]
        repo_intake = tmp / "repo_intake.md"
        write_repo_intake(repo_intake, repos)
        label_intake = tmp / "label_intake"
        make_label_intake(
            label_intake,
            [
                {
                    "case_id": case_id,
                    "label_id": f"{case_id}-label",
                    "repo_path": str(repo),
                    "human_labeled": True,
                    "synthetic": False,
                    "expected": "present",
                }
                for case_id, repo, _head in repos
            ],
        )
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        assert "label_intake --verify-existing failed" in proc.stderr

        out_dir = tmp / "feedback_packet"
        out_commands = tmp / "feedback_packet_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--out",
            str(out_dir),
            "--out-commands-sh",
            str(out_commands),
            "--min-repos",
            "3",
            "--skip-verify-existing",
        )
        assert proc.returncode == 0, proc.stderr
        summary = json.loads((out_dir / "maintainer_feedback_progress_summary.json").read_text(encoding="utf-8"))
        assert summary["request_case_rows"] == 3
        assert summary["label_intake_verify_existing_required"] == 0
        assert summary["missing_feedback_case_rows"] == 3
        assert summary["valid_feedback_case_rows"] == 0
        assert summary["countable_valid_feedback_case_rows"] == 0
        assert summary["maintainer_progress_rows"] == []
        assert summary["case_feedback_progress_rows"] == []
        assert summary["raw_feedback_text_emitted"] == 0
        assert summary["creates_benchmark_evidence"] == 0
        assert summary["input_path_guard_passed"] == 1
        assert summary["output_path_guard_passed"] == 1
        assert summary["design_partner_beta_candidate_ready"] == 0
        assert summary["operator_command_count"] == 2
        assert len(summary["operator_commands"]) == 2
        assert summary["operator_commands_script"] == str(out_commands.resolve())
        assert summary["writes_operator_command_script"] == 1
        assert summary["operator_commands_script_sha256"] == sha256_file(out_commands)
        assert summary["operator_commands_script_command_count"] == 2
        assert out_commands.stat().st_mode & 0o111
        script_text = out_commands.read_text(encoding="utf-8")
        assert script_text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n")
        assert "Generated by scripts/amr_beta_maintainer_feedback_packet.py" in script_text
        assert "repo_snapshot_lock_sha256: sha256:" in script_text
        assert "operator_commands_sha256: sha256:" in script_text
        assert "operator_command_count: 2" in script_text
        assert script_text.count("# command ") == 2
        for command in summary["operator_commands"]:
            assert command in script_text
        packet_parts = shlex.split(summary["operator_commands"][0])
        assert packet_parts[0] == "python3"
        assert packet_parts[1] == "scripts/amr_beta_maintainer_feedback_packet.py"
        assert packet_parts[packet_parts.index("--repo-intake") + 1] == str(repo_intake.resolve())
        assert packet_parts[packet_parts.index("--label-intake-dir") + 1] == str(label_intake.resolve())
        assert packet_parts[packet_parts.index("--out") + 1] == str(out_dir.resolve())
        assert "--overwrite" in packet_parts
        verify_parts = shlex.split(summary["operator_commands"][1])
        assert verify_parts[:3] == ["python3", "-m", "json.tool"]
        assert verify_parts[3] == str(out_dir.resolve() / "maintainer_feedback_progress_summary.json")
        packet_text = (out_dir / "maintainer_feedback_request_packet.jsonl").read_text(encoding="utf-8")
        assert "Reviewed case-" not in packet_text

        nested_out = tmp / "feedback_packet_nested_script"
        nested_commands = nested_out / "feedback_packet_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--out",
            str(nested_out),
            "--out-commands-sh",
            str(nested_commands),
            "--min-repos",
            "3",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        nested_payload = json.loads(proc.stdout)
        assert nested_payload["output_path_guard_passed"] == 0
        assert "out_commands_sh must not be inside out" in proc.stderr
        assert not nested_out.exists()
        assert not nested_commands.exists()

        unsafe_out = repos[0][1] / "feedback_packet"
        unsafe_commands = repos[0][1] / "feedback_packet_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--out",
            str(unsafe_out),
            "--out-commands-sh",
            str(unsafe_commands),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["output_path_guard_passed"] == 0
        assert "out must not be inside target repo" in proc.stderr
        assert "out_commands_sh must not be inside target repo" in proc.stderr
        assert not unsafe_out.exists()
        assert not unsafe_commands.exists()

        ignored_label_dir_name = "ignored_label_intake"
        ignored_feedback_name = "ignored_feedback.jsonl"
        (repos[0][1] / ".gitignore").write_text(
            f"{ignored_label_dir_name}/\n{ignored_feedback_name}\n",
            encoding="utf-8",
        )
        assert run(["git", "add", ".gitignore"], cwd=repos[0][1]).returncode == 0
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
                "ignore unsafe feedback inputs",
            ],
            cwd=repos[0][1],
        )
        assert commit.returncode == 0, commit.stderr
        new_head = run(["git", "rev-parse", "HEAD"], cwd=repos[0][1])
        assert new_head.returncode == 0
        repos[0] = (repos[0][0], repos[0][1], new_head.stdout.strip())
        write_repo_intake(repo_intake, repos)

        unsafe_label_intake = repos[0][1] / ignored_label_dir_name
        make_label_intake(
            unsafe_label_intake,
            [
                {
                    "case_id": "case-01",
                    "label_id": "case-01-label",
                    "repo_path": str(repos[0][1]),
                    "human_labeled": True,
                    "synthetic": False,
                    "expected": "present",
                }
            ],
        )
        status = run(["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=repos[0][1])
        assert status.returncode == 0
        assert status.stdout.strip() == ""
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(unsafe_label_intake),
            "--min-repos",
            "3",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_label_payload = json.loads(proc.stdout)
        assert unsafe_label_payload["input_path_guard_passed"] == 0
        assert unsafe_label_payload["output_path_guard_passed"] == 1
        assert "label_intake_dir[1] must not be inside target repo" in proc.stderr

        unsafe_feedback = repos[0][1] / ignored_feedback_name
        write_jsonl(
            unsafe_feedback,
            [
                {
                    "case_id": "case-01",
                    "maintainer_id": "maintainer-unsafe",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-01 from an unsafe in-repo feedback file.",
                }
            ],
        )
        status = run(["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=repos[0][1])
        assert status.returncode == 0
        assert status.stdout.strip() == ""
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--feedback",
            str(unsafe_feedback),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_feedback_payload = json.loads(proc.stdout)
        assert unsafe_feedback_payload["input_path_guard_passed"] == 0
        assert unsafe_feedback_payload["output_path_guard_passed"] == 1
        assert "feedback must not be inside target repo" in proc.stderr
        assert "Reviewed case-01 from an unsafe in-repo feedback file." not in proc.stdout
        assert "Reviewed case-01 from an unsafe in-repo feedback file." not in proc.stderr

        nested_repo_intake = tmp / "nested_repo_intake.md"
        nested_repo_path = repos[0][1] / "nested"
        nested_repo_path.mkdir()
        write_repo_intake(nested_repo_intake, [(repos[0][0], nested_repo_path, repos[0][2]), *repos[1:]])
        proc = run_tool(
            "--repo-intake",
            str(nested_repo_intake),
            "--feedback",
            str(unsafe_feedback),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        nested_payload = json.loads(proc.stdout)
        assert nested_payload["input_path_guard_passed"] == 0
        assert nested_payload["output_path_guard_passed"] == 1
        assert "repo_path must be git worktree root" in proc.stderr
        assert "feedback must not be inside target repo" in proc.stderr
        assert "Reviewed case-01 from an unsafe in-repo feedback file." not in proc.stdout
        assert "Reviewed case-01 from an unsafe in-repo feedback file." not in proc.stderr

        feedback = tmp / "feedback.jsonl"
        feedback_rows = [
            {
                "case_id": case_id,
                "maintainer_id": f"maintainer-{index}",
                "human_feedback": True,
                "feedback_text": f"Reviewed {case_id} source-bound findings.",
                **(
                    {
                        "feedback_text_sha256": "sha256:"
                        + hashlib.sha256(
                            f"Reviewed {case_id} source-bound findings.".encode("utf-8")
                        ).hexdigest()
                    }
                    if index == 1
                    else {}
                ),
            }
            for index, (case_id, _repo, _head) in enumerate(repos, start=1)
        ]
        write_jsonl(feedback, feedback_rows)
        feedback_text = "Reviewed case-01 source-bound findings."
        expected_feedback_sha = "sha256:" + hashlib.sha256(feedback_text.encode("utf-8")).hexdigest()
        expected_feedback_bundle_sha = benchmark_inputs.sha256_json(
            {
                "schema": "amr_beta_feedback_bundle.v1",
                "feedback_sha256": benchmark_inputs.sha256_file(feedback),
                "feedback_digest_fingerprints": benchmark_inputs.feedback_fingerprints(feedback_rows),
            }
        )

        env_feedback = tmp / ".env.maintainer_feedback"
        env_feedback.symlink_to(feedback)
        env_feedback_out = tmp / "env_feedback_packet"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--feedback",
            str(env_feedback),
            "--out",
            str(env_feedback_out),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        env_feedback_payload = json.loads(proc.stdout)
        assert env_feedback_payload["input_path_guard_passed"] == 0
        assert env_feedback_payload["feedback_sha256"] == ""
        assert env_feedback_payload["feedback_bundle_sha256"] == ""
        assert env_feedback_payload["operator_commands"] == []
        assert "feedback must not be .env-like" in proc.stderr
        assert feedback_text not in proc.stdout
        assert feedback_text not in proc.stderr
        assert not env_feedback_out.exists()

        env_out_target = tmp / "env_feedback_out_target"
        env_out = tmp / ".env.maintainer_feedback_packet_out"
        env_out.symlink_to(env_out_target)
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--feedback",
            str(feedback),
            "--out",
            str(env_out),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        env_out_payload = json.loads(proc.stdout)
        assert env_out_payload["output_path_guard_passed"] == 0
        assert env_out_payload["feedback_sha256"] == ""
        assert env_out_payload["feedback_bundle_sha256"] == ""
        assert env_out_payload["operator_commands"] == []
        assert "out must not be .env-like" in proc.stderr
        assert feedback_text not in proc.stdout
        assert feedback_text not in proc.stderr
        assert not env_out_target.exists()

        env_label_intake = tmp / ".env.maintainer_label_intake"
        env_label_intake.symlink_to(label_intake)
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(env_label_intake),
            "--feedback",
            str(feedback),
            "--min-repos",
            "3",
            "--json",
        )
        assert proc.returncode == 1
        env_label_payload = json.loads(proc.stdout)
        assert env_label_payload["input_path_guard_passed"] == 0
        assert env_label_payload["feedback_sha256"] == ""
        assert env_label_payload["feedback_bundle_sha256"] == ""
        assert env_label_payload["operator_commands"] == []
        assert "label_intake_dir[1] must not be .env-like" in proc.stderr
        assert feedback_text not in proc.stdout
        assert feedback_text not in proc.stderr

        feedback_out = tmp / "feedback_packet_with_feedback"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(feedback),
            "--out",
            str(feedback_out),
            "--min-repos",
            "3",
            "--skip-verify-existing",
        )
        assert proc.returncode == 0, proc.stderr
        packet_with_feedback = (feedback_out / "maintainer_feedback_request_packet.jsonl").read_text(
            encoding="utf-8"
        )
        assert expected_feedback_sha in packet_with_feedback
        assert "present_unemitted" not in packet_with_feedback
        assert feedback_text not in packet_with_feedback

        feedback_script = tmp / "feedback_with_feedback_commands.sh"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(feedback),
            "--out",
            str(tmp / "feedback_packet_with_feedback_script"),
            "--out-commands-sh",
            str(feedback_script),
            "--min-repos",
            "3",
            "--skip-verify-existing",
        )
        assert proc.returncode == 0, proc.stderr
        feedback_script_text = feedback_script.read_text(encoding="utf-8")
        assert str(feedback.resolve()) in feedback_script_text
        assert benchmark_inputs.sha256_file(feedback) in feedback_script_text
        assert expected_feedback_bundle_sha in feedback_script_text
        assert feedback_text not in feedback_script_text

        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(feedback),
            "--min-repos",
            "3",
            "--min-maintainers",
            "3",
            "--enforce-min-maintainers",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["maintainer_feedback_requirement_met"] == 1
        assert payload["feedback_counts_for_beta_precheck"] == 1
        assert payload["ready_for_runtime_preflight_feedback"] == 1
        assert payload["feedback_input"] == str(feedback.resolve())
        assert payload["feedback_sha256"] == benchmark_inputs.sha256_file(feedback)
        assert payload["feedback_bundle_sha256"] == expected_feedback_bundle_sha
        assert payload["feedback_digest_fingerprint_rows"] == 3
        assert payload["valid_feedback_text_input_rows"] == 3
        assert payload["valid_feedback_hash_only_rows"] == 0
        assert payload["valid_feedback_digest_rows"] == 3
        assert payload["valid_feedback_case_rows"] == 3
        assert payload["countable_valid_feedback_case_rows"] == 3
        assert payload["maintainer_progress_rows"] == [
            {
                "countable_case_id_count": 1,
                "distinct_case_id_count": 1,
                "maintainer_id": "maintainer-1",
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
            {
                "countable_case_id_count": 1,
                "distinct_case_id_count": 1,
                "maintainer_id": "maintainer-2",
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
            {
                "countable_case_id_count": 1,
                "distinct_case_id_count": 1,
                "maintainer_id": "maintainer-3",
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
        ]
        assert payload["case_feedback_progress_rows"] == [
            {
                "case_id": "case-01",
                "countable_for_beta_precheck": 1,
                "distinct_maintainer_id_count": 1,
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
            {
                "case_id": "case-02",
                "countable_for_beta_precheck": 1,
                "distinct_maintainer_id_count": 1,
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
            {
                "case_id": "case-03",
                "countable_for_beta_precheck": 1,
                "distinct_maintainer_id_count": 1,
                "valid_feedback_digest_rows": 1,
                "valid_feedback_hash_only_rows": 0,
                "valid_feedback_rows": 1,
                "valid_feedback_text_input_rows": 1,
            },
        ]
        assert "Reviewed case-01" not in proc.stdout

        hash_only_feedback = tmp / "hash_only_feedback.jsonl"
        hash_only_text = "Maintainer supplied digest-only feedback for case-01."
        hash_only_rows = [
            {
                "case_id": "case-01",
                "maintainer_id": "maintainer-hash-only",
                "human_feedback": True,
                "feedback_text_sha256": "sha256:"
                + hashlib.sha256(hash_only_text.encode("utf-8")).hexdigest(),
            },
            {
                "case_id": "case-02",
                "maintainer_id": "maintainer-text-2",
                "human_feedback": True,
                "feedback_text": "Reviewed case-02 source-bound findings.",
            },
            {
                "case_id": "case-03",
                "maintainer_id": "maintainer-text-3",
                "human_feedback": True,
                "feedback_text": "Reviewed case-03 source-bound findings.",
            },
        ]
        write_jsonl(hash_only_feedback, hash_only_rows)
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(hash_only_feedback),
            "--min-repos",
            "3",
            "--min-maintainers",
            "3",
            "--enforce-min-maintainers",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        hash_only_payload = json.loads(proc.stdout)
        assert hash_only_payload["valid_feedback_text_input_rows"] == 2
        assert hash_only_payload["valid_feedback_hash_only_rows"] == 1
        assert hash_only_payload["valid_feedback_digest_rows"] == 3
        assert hash_only_payload["maintainer_progress_rows"][0]["maintainer_id"] == "maintainer-hash-only"
        assert hash_only_payload["maintainer_progress_rows"][0]["valid_feedback_hash_only_rows"] == 1
        assert hash_only_payload["case_feedback_progress_rows"][0]["valid_feedback_hash_only_rows"] == 1
        assert hash_only_payload["feedback_sha256"] == benchmark_inputs.sha256_file(hash_only_feedback)
        assert hash_only_payload["feedback_bundle_sha256"] == benchmark_inputs.sha256_json(
            {
                "schema": "amr_beta_feedback_bundle.v1",
                "feedback_sha256": benchmark_inputs.sha256_file(hash_only_feedback),
                "feedback_digest_fingerprints": benchmark_inputs.feedback_fingerprints(hash_only_rows),
            }
        )
        assert hash_only_payload["feedback_digest_fingerprint_rows"] == 3
        assert hash_only_payload["feedback_counts_for_beta_precheck"] == 1
        assert hash_only_text not in proc.stdout

        bad_feedback_sha = tmp / "bad_feedback_sha.jsonl"
        write_jsonl(
            bad_feedback_sha,
            [
                {
                    "case_id": "case-01",
                    "maintainer_id": "maintainer-1",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-01 source-bound findings.",
                    "feedback_text_sha256": "Reviewed case-01 source-bound findings.",
                }
            ],
        )
        bad_feedback_out = tmp / "bad_feedback_packet"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(bad_feedback_sha),
            "--out",
            str(bad_feedback_out),
            "--min-repos",
            "3",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        assert "feedback_text_sha256 must be sha256:<64 hex>" in proc.stderr
        assert "Reviewed case-01 source-bound findings." not in proc.stdout
        assert "Reviewed case-01 source-bound findings." not in proc.stderr
        assert not bad_feedback_out.exists()

        duplicate_feedback_id = tmp / "duplicate_feedback_id.jsonl"
        write_jsonl(
            duplicate_feedback_id,
            [
                {
                    "case_id": "case-01",
                    "maintainer_id": "maintainer-duplicate-1",
                    "feedback_id": "feedback-duplicate",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-01 source-bound findings.",
                },
                {
                    "case_id": "case-02",
                    "maintainer_id": "maintainer-duplicate-2",
                    "feedback_id": "feedback-duplicate",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-02 source-bound findings.",
                },
                {
                    "case_id": "case-03",
                    "maintainer_id": "maintainer-duplicate-3",
                    "feedback_id": "feedback-unique",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-03 source-bound findings.",
                },
            ],
        )
        duplicate_feedback_out = tmp / "duplicate_feedback_packet"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(duplicate_feedback_id),
            "--out",
            str(duplicate_feedback_out),
            "--min-repos",
            "3",
            "--min-maintainers",
            "3",
            "--enforce-min-maintainers",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        assert "duplicate feedback_id" in proc.stderr
        assert "Reviewed case-02 source-bound findings." not in proc.stdout
        assert "Reviewed case-02 source-bound findings." not in proc.stderr
        assert not duplicate_feedback_out.exists()

        default_feedback_id_collision = tmp / "default_feedback_id_collision.jsonl"
        write_jsonl(
            default_feedback_id_collision,
            [
                {
                    "case_id": "case-01",
                    "maintainer_id": "maintainer-default-1",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-01 source-bound findings.",
                },
                {
                    "case_id": "case-02",
                    "maintainer_id": "maintainer-default-2",
                    "feedback_id": "feedback_0001",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-02 source-bound findings.",
                },
                {
                    "case_id": "case-03",
                    "maintainer_id": "maintainer-default-3",
                    "feedback_id": "feedback_unique",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-03 source-bound findings.",
                },
            ],
        )
        default_feedback_id_out = tmp / "default_feedback_id_packet"
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--feedback",
            str(default_feedback_id_collision),
            "--out",
            str(default_feedback_id_out),
            "--min-repos",
            "3",
            "--min-maintainers",
            "3",
            "--enforce-min-maintainers",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        assert "duplicate feedback_id" in proc.stderr
        assert "Reviewed case-02 source-bound findings." not in proc.stdout
        assert "Reviewed case-02 source-bound findings." not in proc.stderr
        assert not default_feedback_id_out.exists()

        synthetic_intake = tmp / "synthetic_label_intake"
        make_label_intake(
            synthetic_intake,
            [
                {
                    "case_id": "case-01",
                    "label_id": "case-01-label",
                    "repo_path": str(repos[0][1]),
                    "human_labeled": True,
                    "synthetic": True,
                    "expected": "present",
                }
            ],
        )
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(synthetic_intake),
            "--feedback",
            str(feedback),
            "--min-repos",
            "3",
            "--min-maintainers",
            "1",
            "--enforce-min-maintainers",
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "case_id is not countable for beta" in proc.stderr

    print("AMR beta maintainer feedback packet smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
