#!/usr/bin/env python3
"""Smoke tests for scripts/audit_my_repo_label_intake.py decision normalization."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from audit_my_repo_label_intake import normalize_decisions, verify_label_intake_dir
from audit_my_repo_label_template import verify_template_dir

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "audit_my_repo_label_intake.py"
TEMPLATE_TOOL = ROOT / "scripts" / "audit_my_repo_label_template.py"


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def run_template_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TEMPLATE_TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def expect_value_error(rows: list[dict], expected: str) -> None:
    try:
        normalize_decisions(rows)
    except ValueError as exc:
        assert expected in str(exc), str(exc)
    else:
        raise AssertionError(f"expected ValueError containing {expected!r}")


def test_decision_normalization() -> None:
    valid = normalize_decisions(
        [
            {
                "candidate_label_id": "case-001-0001",
                "label_id": "case-001-label",
                "human_labeled": True,
                "expected": "present",
                "priority": "P1",
                "reviewer_id": "reviewer-one",
                "maintainer_id": "maintainer.alpha+repo@review.invalid",
                "maintainer_feedback": True,
            }
        ]
    )
    assert valid[0]["candidate_label_id"] == "case-001-0001"
    assert valid[0]["label_id"] == "case-001-label"
    assert valid[0]["reviewer_id_sha256"].startswith("sha256:")
    assert valid[0]["maintainer_id"] == "maintainer.alpha+repo@review.invalid"
    assert valid[0]["maintainer_feedback"] == 1

    expect_value_error(
        [{"candidate_label_id": "EXAMPLE-case-0001", "human_labeled": True, "expected": "present"}],
        "candidate_label_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "label_id": "EXAMPLE-label",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "label_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "label_id": "shared-label",
                "human_labeled": True,
                "expected": "present",
            },
            {
                "candidate_label_id": "case-001-0002",
                "label_id": "shared-label",
                "human_labeled": True,
                "expected": "absent",
            },
        ],
        "duplicate decision label_id",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "reviewer_id": "reviewer alpha",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "reviewer_id must be a safe identifier",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "reviewer_id": "EXAMPLE-reviewer",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "reviewer_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "maintainer_id": "maintainer alpha",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "maintainer_id must be a safe identifier",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "maintainer_id": "EXAMPLE-maintainer",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "maintainer_id must not be example/placeholder",
    )


def test_rejects_output_inside_target_repo_before_writing() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        target_repo = tmp / "target repo"
        target_repo.mkdir()
        audit_output = tmp / "audit_output"
        audit_output.mkdir()
        write_json(
            audit_output / "audit_manifest.json",
            {
                "cache_key": "a" * 64,
                "target_repo": str(target_repo),
            },
        )
        template_dir = tmp / "label_template"
        template_dir.mkdir()
        write_json(
            template_dir / "label_template_manifest.json",
            {
                "input_audit_output": str(audit_output),
            },
        )
        decisions = tmp / "decisions.jsonl"
        decisions.write_text(
            json.dumps(
                {
                    "candidate_label_id": "case-001-0001",
                    "human_labeled": True,
                    "expected": "present",
                },
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        out_dir = target_repo / "label_intake"
        proc = run_tool(
            "--template",
            str(template_dir),
            "--decisions",
            str(decisions),
            "--out",
            str(out_dir),
        )
        assert proc.returncode == 2, proc.stderr
        assert "refusing --out inside target repo" in proc.stderr
        assert not out_dir.exists()
        assert not any("label_intake_staging" in child.name for child in target_repo.iterdir())


def test_rejects_decisions_inside_target_repo_before_writing() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        target_repo = tmp / "target repo"
        target_repo.mkdir()
        audit_output = tmp / "audit_output"
        audit_output.mkdir()
        write_json(
            audit_output / "audit_manifest.json",
            {
                "cache_key": "a" * 64,
                "target_repo": str(target_repo),
            },
        )
        template_dir = tmp / "label_template"
        template_dir.mkdir()
        write_json(
            template_dir / "label_template_manifest.json",
            {
                "input_audit_output": str(audit_output),
            },
        )
        decisions = target_repo / "decisions.jsonl"
        decisions.write_text(
            json.dumps(
                {
                    "candidate_label_id": "case-001-0001",
                    "human_labeled": True,
                    "expected": "present",
                },
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        out_dir = tmp / "label_intake"
        proc = run_tool(
            "--template",
            str(template_dir),
            "--decisions",
            str(decisions),
            "--out",
            str(out_dir),
        )
        assert proc.returncode == 2, proc.stderr
        assert "refusing --decisions inside target repo" in proc.stderr
        assert not out_dir.exists()
        assert not any("label_intake_staging" in child.name for child in tmp.iterdir())


def test_generation_rejects_raw_env_like_symlinks_before_reading_or_writing() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        target_repo = tmp / "target repo"
        target_repo.mkdir()
        audit_output = tmp / "audit_output"
        audit_output.mkdir()
        write_json(
            audit_output / "audit_manifest.json",
            {
                "cache_key": "a" * 64,
                "target_repo": str(target_repo),
            },
        )
        template_dir = tmp / "label_template"
        template_dir.mkdir()
        write_json(
            template_dir / "label_template_manifest.json",
            {
                "input_audit_output": str(audit_output),
            },
        )
        decisions = tmp / "decisions.jsonl"
        decisions_text = (
            json.dumps(
                {
                    "candidate_label_id": "case-001-0001",
                    "human_labeled": True,
                    "expected": "present",
                },
                sort_keys=True,
            )
            + "\n"
        )
        decisions.write_text(decisions_text, encoding="utf-8")

        env_template = tmp / ".env.label_template_input"
        env_template.symlink_to(template_dir)
        proc = run_tool(
            "--template",
            str(env_template),
            "--decisions",
            str(decisions),
            "--out",
            str(tmp / "label_intake_from_env_template"),
        )
        assert proc.returncode == 2
        assert "refusing .env-like template path" in proc.stderr
        assert "case-001-0001" not in proc.stderr
        assert not any("label_intake_staging" in child.name for child in tmp.iterdir())

        env_decisions = tmp / ".env.label_decisions"
        env_decisions.symlink_to(decisions)
        proc = run_tool(
            "--template",
            str(template_dir),
            "--decisions",
            str(env_decisions),
            "--out",
            str(tmp / "label_intake_from_env_decisions"),
        )
        assert proc.returncode == 2
        assert "refusing to read .env-like decisions file" in proc.stderr
        assert "case-001-0001" not in proc.stderr
        assert not any("label_intake_staging" in child.name for child in tmp.iterdir())

        env_out_target = tmp / "label_intake_target"
        env_out = tmp / ".env.label_intake_out"
        env_out.symlink_to(env_out_target)
        proc = run_tool(
            "--template",
            str(template_dir),
            "--decisions",
            str(decisions),
            "--out",
            str(env_out),
        )
        assert proc.returncode == 2
        assert "refusing .env-like output directory" in proc.stderr
        assert not env_out_target.exists()
        assert not any("label_intake_staging" in child.name for child in tmp.iterdir())


def test_verify_existing_rejects_env_like_symlinks_before_reading() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        template_target = tmp / "label_template_target"
        template_target.mkdir()
        template_link = tmp / ".env.label_template"
        template_link.symlink_to(template_target)
        proc = run_template_tool("--verify-existing", str(template_link))
        assert proc.returncode == 2
        assert "refusing .env-like label template path" in proc.stderr

        intake_target = tmp / "label_intake_target"
        intake_target.mkdir()
        intake_link = tmp / ".env.label_intake"
        intake_link.symlink_to(intake_target)
        proc = run_tool("--verify-existing", str(intake_link))
        assert proc.returncode == 2
        assert "refusing .env-like label intake path" in proc.stderr


def test_internal_staging_env_like_names_are_not_rejected_by_verify_helpers() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        template_staging = tmp / ".env.label_template_staging.abc"
        template_staging.mkdir()
        errors = verify_template_dir(template_staging, enforce_env_path_guard=False)
        assert "refusing .env-like label template path" not in errors
        assert any("missing label template artifact" in error for error in errors)
        assert verify_template_dir(template_staging) == ["refusing .env-like label template path"]

        intake_staging = tmp / ".env.label_intake_staging.abc"
        intake_staging.mkdir()
        errors = verify_label_intake_dir(intake_staging, enforce_env_path_guard=False)
        assert "refusing .env-like label intake path" not in errors
        assert any("missing label intake artifact" in error for error in errors)
        assert verify_label_intake_dir(intake_staging) == ["refusing .env-like label intake path"]


def main() -> int:
    test_decision_normalization()
    test_rejects_output_inside_target_repo_before_writing()
    test_rejects_decisions_inside_target_repo_before_writing()
    test_generation_rejects_raw_env_like_symlinks_before_reading_or_writing()
    test_verify_existing_rejects_env_like_symlinks_before_reading()
    test_internal_staging_env_like_names_are_not_rejected_by_verify_helpers()
    print("audit_my_repo_label_intake decision normalization smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
