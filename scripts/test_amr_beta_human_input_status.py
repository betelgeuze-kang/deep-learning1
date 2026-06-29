#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_human_input_status.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_human_input_status.py"


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


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
        decisions = tmp / "decisions.jsonl"
        feedback = tmp / "feedback.jsonl"
        repo_intake = tmp / "repo_intake.md"
        repo_intake.write_text(
            "| case_id | repo_path |\n"
            "|---|---|\n"
            "| case-001 | /tmp/repo-001 |\n"
            "| case-002 | /tmp/repo-002 |\n",
            encoding="utf-8",
        )
        write_jsonl(
            decisions,
            [
                {
                    "candidate_label_id": "case-001-0001",
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                },
                {
                    "candidate_label_id": "case-002-0001",
                    "human_labeled": True,
                    "expected": "absent",
                    "priority": "P2",
                },
            ],
        )
        write_jsonl(
            feedback,
            [
                {
                    "case_id": "case-001",
                    "maintainer_id": "maintainer-alpha",
                    "human_feedback": True,
                    "feedback_text": "Reviewed finding quality on local repo.",
                },
                {
                    "case_id": "case-002",
                    "maintainer_id": "maintainer-beta",
                    "human_feedback": True,
                    "feedback_text": "Confirmed the candidate labels are human reviewed.",
                },
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(feedback),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "2",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        assert '"ready_for_real_benchmark_inputs": 1' in proc.stdout
        assert '"design_partner_beta_candidate_ready": 0' in proc.stdout

        label_intake = tmp / "label_intake"
        make_label_intake(
            label_intake,
            [
                {
                    "case_id": "case-001",
                    "label_id": "case-001-label",
                    "repo_path": "/tmp/repo-001",
                    "human_labeled": True,
                    "synthetic": False,
                    "expected": "present",
                },
                {
                    "case_id": "case-002",
                    "label_id": "case-002-label",
                    "repo_path": "/tmp/repo-002",
                    "human_labeled": True,
                    "synthetic": False,
                    "expected": "absent",
                },
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(feedback),
            "--label-intake-dir",
            str(label_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "2",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        assert '"feedback_counts_for_beta_precheck": 1' in proc.stdout
        assert '"distinct_countable_maintainer_id_count": 2' in proc.stdout

        synthetic_label_intake = tmp / "synthetic_label_intake"
        make_label_intake(
            synthetic_label_intake,
            [
                {
                    "case_id": "case-001",
                    "label_id": "case-001-label",
                    "repo_path": "/tmp/repo-001",
                    "human_labeled": True,
                    "synthetic": True,
                    "expected": "present",
                },
                {
                    "case_id": "case-002",
                    "label_id": "case-002-label",
                    "repo_path": "/tmp/repo-002",
                    "human_labeled": True,
                    "synthetic": False,
                    "expected": "absent",
                },
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(feedback),
            "--label-intake-dir",
            str(synthetic_label_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "2",
        )
        assert proc.returncode == 1
        assert "case_id is not countable for beta" in proc.stderr

        bad_decisions = tmp / "bad_decisions.jsonl"
        write_jsonl(
            bad_decisions,
            [
                {
                    "candidate_label_id": "EXAMPLE-case-0001",
                    "human_labeled": True,
                    "expected": "present",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(bad_decisions),
            "--feedback",
            str(feedback),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "1",
            "--min-maintainers",
            "2",
        )
        assert proc.returncode == 1
        assert "candidate_label_id must not be example/placeholder" in proc.stderr

        bad_feedback = tmp / "bad_feedback.jsonl"
        write_jsonl(
            bad_feedback,
            [
                {
                    "case_id": "case-001",
                    "maintainer_id": "EXAMPLE-maintainer",
                    "human_feedback": True,
                    "feedback_text": "placeholder",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(bad_feedback),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "1",
        )
        assert proc.returncode == 1
        assert "maintainer_id must not be example/placeholder" in proc.stderr

        unknown_feedback = tmp / "unknown_feedback.jsonl"
        write_jsonl(
            unknown_feedback,
            [
                {
                    "case_id": "case-999",
                    "maintainer_id": "maintainer-gamma",
                    "human_feedback": True,
                    "feedback_text": "Real feedback row bound to wrong case.",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(unknown_feedback),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "1",
        )
        assert proc.returncode == 1
        assert "unknown case_id" in proc.stderr

    print("AMR beta human input status smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
