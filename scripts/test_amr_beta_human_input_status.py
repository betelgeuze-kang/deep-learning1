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


def make_template(path: Path, rows: list[dict]) -> None:
    path.mkdir()
    (path / "label_template.json").write_text(
        json.dumps({"rows": rows}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


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
        repo_001 = tmp / "repo-001"
        repo_002 = tmp / "repo-002"
        repo_001.mkdir()
        repo_002.mkdir()
        repo_intake.write_text(
            "| case_id | repo_path |\n"
            "|---|---|\n"
            f"| case-001 | {repo_001} |\n"
            f"| case-002 | {repo_002} |\n",
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
                    "maintainer_id": "maintainer.alpha+repo@review.invalid",
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
        assert '"non_synthetic_valid_human_label_rows": 2' in proc.stdout
        assert '"remaining_human_label_rows": 0' in proc.stdout
        assert '"remaining_distinct_maintainer_ids": 0' in proc.stdout
        assert '"compiles_labels": 0' in proc.stdout
        assert '"creates_benchmark_evidence": 0' in proc.stdout

        status_json = tmp / "human_input_status.json"
        status_md = tmp / "human_input_status.md"
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
            "--out-json",
            str(status_json),
            "--out-md",
            str(status_md),
        )
        assert proc.returncode == 0, proc.stderr
        status = json.loads(status_json.read_text(encoding="utf-8"))
        assert status["ready_for_real_benchmark_inputs"] == 1
        assert status["valid_human_label_rows"] == 2
        assert status["non_synthetic_valid_human_label_rows"] == 2
        assert status["synthetic_or_unverified_human_label_rows"] == 0
        assert status["human_label_progress_percent"] == 100.0
        assert status["maintainer_feedback_progress_percent"] == 100.0
        assert status["valid_feedback_text_input_rows"] == 2
        assert status["valid_feedback_hash_only_rows"] == 0
        assert status["valid_feedback_digest_rows"] == 2
        assert status["compiles_labels"] == 0
        assert status["creates_benchmark_evidence"] == 0
        assert status["output_path_guard_passed"] == 1
        assert "Reviewed finding quality" not in status_json.read_text(encoding="utf-8")
        assert "Reviewed finding quality" not in status_md.read_text(encoding="utf-8")
        assert "valid_feedback_text_input_rows: 2" in status_md.read_text(encoding="utf-8")
        assert "valid_feedback_hash_only_rows: 0" in status_md.read_text(encoding="utf-8")
        assert "valid_feedback_digest_rows: 2" in status_md.read_text(encoding="utf-8")
        assert "output_path_guard_passed: 1" in status_md.read_text(encoding="utf-8")

        template = tmp / "label_template"
        make_template(
            template,
            [
                {
                    "case_id": "case-001",
                    "candidate_label_id": "case-001-0001",
                    "synthetic": "0",
                },
                {
                    "case_id": "case-002",
                    "candidate_label_id": "case-002-0001",
                    "synthetic": "1",
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
            "--template-dir",
            str(template),
            "--min-labels",
            "2",
            "--min-maintainers",
            "2",
            "--json",
        )
        assert proc.returncode == 1
        synthetic_payload = json.loads(proc.stdout)
        assert synthetic_payload["valid_human_label_rows"] == 2
        assert synthetic_payload["non_synthetic_valid_human_label_rows"] == 1
        assert synthetic_payload["synthetic_or_unverified_human_label_rows"] == 1
        assert synthetic_payload["remaining_human_label_rows"] == 1
        assert synthetic_payload["human_label_requirement_met"] == 0
        assert synthetic_payload["template_non_synthetic_candidate_rows"] == 1
        assert synthetic_payload["template_synthetic_or_unverified_candidate_rows"] == 1
        assert "non_synthetic_valid_human_label_rows 1 below required minimum 2" in proc.stderr

        unsafe_status_json = repo_001 / "human_input_status.json"
        unsafe_status_md = repo_002 / "human_input_status.md"
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
            "--out-json",
            str(unsafe_status_json),
            "--out-md",
            str(unsafe_status_md),
            "--json",
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["output_path_guard_passed"] == 0
        assert "out_json must not be inside target repo" in proc.stderr
        assert "out_md must not be inside target repo" in proc.stderr
        assert not unsafe_status_json.exists()
        assert not unsafe_status_md.exists()

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
        assert proc.returncode == 1
        assert "label_intake --verify-existing failed" in proc.stderr

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
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        assert '"feedback_counts_for_beta_precheck": 1' in proc.stdout
        assert '"distinct_countable_maintainer_id_count": 2' in proc.stdout
        assert '"label_intake_verify_existing_required": 0' in proc.stdout

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
            "--skip-verify-existing",
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
            "--out-json",
            str(tmp / "bad_human_input_status.json"),
        )
        assert proc.returncode == 1
        assert "candidate_label_id must not be example/placeholder" in proc.stderr
        bad_status = json.loads((tmp / "bad_human_input_status.json").read_text(encoding="utf-8"))
        assert bad_status["ready_for_real_benchmark_inputs"] == 0
        assert bad_status["errors"]

        unsafe_decisions = tmp / "unsafe_decisions.jsonl"
        write_jsonl(
            unsafe_decisions,
            [
                {
                    "candidate_label_id": "../case-001-0001",
                    "human_labeled": True,
                    "expected": "present",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(unsafe_decisions),
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
        assert "candidate_label_id must be a safe identifier" in proc.stderr

        bad_optional_decision_ids = tmp / "bad_optional_decision_ids.jsonl"
        write_jsonl(
            bad_optional_decision_ids,
            [
                {
                    "candidate_label_id": "case-001-0001",
                    "label_id": "EXAMPLE-label",
                    "reviewer_id": "reviewer alpha",
                    "human_labeled": True,
                    "expected": "present",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(bad_optional_decision_ids),
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
        assert "label_id must not be example/placeholder" in proc.stderr
        assert "reviewer_id must be a safe identifier" in proc.stderr

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

        bad_feedback_id = tmp / "bad_feedback_id.jsonl"
        write_jsonl(
            bad_feedback_id,
            [
                {
                    "case_id": "case-001",
                    "maintainer_id": "maintainer-gamma",
                    "feedback_id": "../feedback",
                    "human_feedback": True,
                    "feedback_text": "Reviewed the real local case.",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(bad_feedback_id),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "1",
        )
        assert proc.returncode == 1
        assert "feedback_id must be a safe identifier" in proc.stderr

        bad_feedback_sha = tmp / "bad_feedback_sha.jsonl"
        write_jsonl(
            bad_feedback_sha,
            [
                {
                    "case_id": "case-001",
                    "maintainer_id": "maintainer-gamma",
                    "human_feedback": True,
                    "feedback_text": "Reviewed the real local case.",
                    "feedback_text_sha256": "Reviewed the real local case.",
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(bad_feedback_sha),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "1",
        )
        assert proc.returncode == 1
        assert "feedback_text_sha256 must be sha256:<64 hex>" in proc.stderr
        assert "Reviewed the real local case." not in proc.stdout
        assert "Reviewed the real local case." not in proc.stderr

        mismatched_feedback_sha = tmp / "mismatched_feedback_sha.jsonl"
        write_jsonl(
            mismatched_feedback_sha,
            [
                {
                    "case_id": "case-001",
                    "maintainer_id": "maintainer-gamma",
                    "human_feedback": True,
                    "feedback_text": "Reviewed the real local case.",
                    "feedback_text_sha256": "sha256:" + ("0" * 64),
                }
            ],
        )
        proc = run_tool(
            "--decisions",
            str(decisions),
            "--feedback",
            str(mismatched_feedback_sha),
            "--repo-intake",
            str(repo_intake),
            "--min-labels",
            "2",
            "--min-maintainers",
            "1",
        )
        assert proc.returncode == 1
        assert "feedback_text_sha256 must match feedback_text" in proc.stderr
        assert "Reviewed the real local case." not in proc.stdout
        assert "Reviewed the real local case." not in proc.stderr

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
