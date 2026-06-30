#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_maintainer_feedback_packet.py."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

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


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
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
        proc = run_tool(
            "--repo-intake",
            str(repo_intake),
            "--label-intake-dir",
            str(label_intake),
            "--out",
            str(out_dir),
            "--min-repos",
            "3",
            "--skip-verify-existing",
        )
        assert proc.returncode == 0, proc.stderr
        summary = json.loads((out_dir / "maintainer_feedback_progress_summary.json").read_text(encoding="utf-8"))
        assert summary["request_case_rows"] == 3
        assert summary["label_intake_verify_existing_required"] == 0
        assert summary["missing_feedback_case_rows"] == 3
        assert summary["raw_feedback_text_emitted"] == 0
        assert summary["creates_benchmark_evidence"] == 0
        assert summary["design_partner_beta_candidate_ready"] == 0
        packet_text = (out_dir / "maintainer_feedback_request_packet.jsonl").read_text(encoding="utf-8")
        assert "Reviewed case-" not in packet_text

        feedback = tmp / "feedback.jsonl"
        write_jsonl(
            feedback,
            [
                {
                    "case_id": case_id,
                    "maintainer_id": f"maintainer-{index}",
                    "human_feedback": True,
                    "feedback_text": f"Reviewed {case_id} source-bound findings.",
                }
                for index, (case_id, _repo, _head) in enumerate(repos, start=1)
            ],
        )
        feedback_text = "Reviewed case-01 source-bound findings."
        expected_feedback_sha = "sha256:" + hashlib.sha256(feedback_text.encode("utf-8")).hexdigest()
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
        assert "Reviewed case-01" not in proc.stdout

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
