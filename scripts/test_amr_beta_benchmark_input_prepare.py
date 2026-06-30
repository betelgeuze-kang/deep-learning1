#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_benchmark_input_prepare.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_benchmark_input_prepare.py"


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def make_intake(path: Path, case_id: str, repo: Path, *, synthetic: bool = False) -> None:
    path.mkdir()
    rows = [
        {
            "case_id": case_id,
            "label_id": f"{case_id}-label-1",
            "repo_path": str(repo),
            "expected_repo_git_head": "a" * 40,
            "human_labeled": True,
            "synthetic": synthetic,
            "priority": "P1",
            "maintainer_id": "",
            "maintainer_feedback": False,
            "plugin_id": "static",
            "rule_id": "rule",
            "file_path": "src/app.py",
            "expected_line_start": "1",
            "expected_line_end": "1",
            "expected_span_sha256": "sha256:" + ("b" * 64),
            "expected": "present",
            "expected_abstain": "",
            "source_candidate_label_id": f"{case_id}-0001",
            "source_finding_id": "finding-1",
            "source_review_queue_id": "queue-1",
            "source_template_span_sha256": "sha256:" + ("b" * 64),
        }
    ]
    labels = path / "benchmark_labels.jsonl"
    write_jsonl(labels, rows)
    manifest = {
        "schema_version": "local_repo_audit_label_intake_manifest.v1",
        "human_label_rows": len(rows),
        "label_rows": len(rows),
        "synthetic_label_rows": int(synthetic),
        "artifact_sha256s": {"benchmark_labels.jsonl": sha256_file(labels)},
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
    }
    write_json(path / "label_intake_manifest.json", manifest)
    manifest_digest = hashlib.sha256((path / "label_intake_manifest.json").read_bytes()).hexdigest()
    labels_digest = hashlib.sha256(labels.read_bytes()).hexdigest()
    (path / "label_intake_sha256sums.txt").write_text(
        f"{manifest_digest}  label_intake_manifest.json\n{labels_digest}  benchmark_labels.jsonl\n",
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
        repo_a = tmp / "repo_a"
        repo_b = tmp / "repo_b"
        repo_a.mkdir()
        repo_b.mkdir()
        intake_a = tmp / "intake_a"
        intake_b = tmp / "intake_b"
        make_intake(intake_a, "case-a", repo_a)
        make_intake(intake_b, "case-b", repo_b)
        out_labels = tmp / "combined dir" / "combined benchmark labels.jsonl"
        summary = tmp / "combined dir" / "summary.json"
        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--label-intake-dir",
            str(intake_b),
            "--out-labels",
            str(tmp / "unverified.jsonl"),
            "--summary",
            str(tmp / "unverified_summary.json"),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--json",
        )
        assert proc.returncode == 1
        unverified = json.loads(proc.stdout)
        assert unverified["label_intake_verify_existing_required"] == 1
        assert unverified["label_intake_verify_existing_failed_dirs"] == 2
        assert "label_intake --verify-existing failed" in proc.stderr

        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--label-intake-dir",
            str(intake_b),
            "--out-labels",
            str(out_labels),
            "--summary",
            str(summary),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["label_intake_verify_existing_required"] == 0
        assert payload["label_intake_verify_existing_passed_dirs"] == 0
        assert payload["ready_for_runtime_approved_real_benchmark"] == 1
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["benchmark_out"] == str((ROOT / "results" / "audit_benchmark").resolve())
        benchmark_parts = shlex.split(payload["benchmark_command"])
        assert benchmark_parts[benchmark_parts.index("--labels") + 1] == str(out_labels)
        assert benchmark_parts[benchmark_parts.index("--out") + 1] == str((ROOT / "results" / "audit_benchmark").resolve())
        assert "--confirm-real-benchmark-namespace" in benchmark_parts
        assert out_labels.is_file()
        assert summary.is_file()
        assert len([line for line in out_labels.read_text(encoding="utf-8").splitlines() if line.strip()]) == 2

        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--label-intake-dir",
            str(intake_b),
            "--out-labels",
            str(repo_a / "combined_benchmark_labels.jsonl"),
            "--summary",
            str(tmp / "inside_repo_summary.json"),
            "--benchmark-out",
            str(repo_b / "audit_benchmark"),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        blocked_payload = json.loads(proc.stdout)
        assert blocked_payload["ready_for_runtime_approved_real_benchmark"] == 0
        assert "out_labels must not be inside target repo" in proc.stderr
        assert "benchmark_out must not be inside target repo" in proc.stderr
        assert not (repo_a / "combined_benchmark_labels.jsonl").exists()

        unsafe_label_intake = repo_a / "ignored_label_intake"
        make_intake(unsafe_label_intake, "case-a", repo_a)
        unsafe_label_out = tmp / "unsafe_label_combined.jsonl"
        unsafe_label_summary = tmp / "unsafe_label_summary.json"
        proc = run_tool(
            "--label-intake-dir",
            str(unsafe_label_intake),
            "--out-labels",
            str(unsafe_label_out),
            "--summary",
            str(unsafe_label_summary),
            "--min-cases",
            "1",
            "--min-labels",
            "1",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_label_payload = json.loads(proc.stdout)
        assert unsafe_label_payload["ready_for_runtime_approved_real_benchmark"] == 0
        assert unsafe_label_payload["input_path_guard_passed"] == 0
        assert "label_intake_dir[1] must not be inside target repo" in proc.stderr
        assert not unsafe_label_out.exists()
        assert not unsafe_label_summary.exists()

        unsafe_feedback = repo_a / "ignored_feedback.jsonl"
        unsafe_feedback.write_text(
            json.dumps(
                {
                    "case_id": "case-a",
                    "maintainer_id": "maintainer-unsafe",
                    "human_feedback": True,
                    "feedback_text": "Reviewed case-a from unsafe in-repo feedback.",
                },
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        unsafe_feedback_out = tmp / "unsafe_feedback_combined.jsonl"
        unsafe_feedback_summary = tmp / "unsafe_feedback_summary.json"
        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--label-intake-dir",
            str(intake_b),
            "--out-labels",
            str(unsafe_feedback_out),
            "--summary",
            str(unsafe_feedback_summary),
            "--feedback",
            str(unsafe_feedback),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_feedback_payload = json.loads(proc.stdout)
        assert unsafe_feedback_payload["ready_for_runtime_approved_real_benchmark"] == 0
        assert unsafe_feedback_payload["input_path_guard_passed"] == 0
        assert "feedback must not be inside target repo" in proc.stderr
        assert "--feedback" not in unsafe_feedback_payload["benchmark_command"]
        assert "Reviewed case-a from unsafe in-repo feedback." not in proc.stdout
        assert "Reviewed case-a from unsafe in-repo feedback." not in proc.stderr
        assert not unsafe_feedback_out.exists()
        assert not unsafe_feedback_summary.exists()

        same_path = tmp / "same_output.json"
        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--label-intake-dir",
            str(intake_b),
            "--out-labels",
            str(same_path),
            "--summary",
            str(same_path),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "summary must not reuse out_labels path" in proc.stderr
        assert not same_path.exists()

        proc = run_tool(
            "--label-intake-dir",
            str(intake_a),
            "--out-labels",
            str(tmp / "too_small.jsonl"),
            "--summary",
            str(tmp / "too_small_summary.json"),
            "--min-cases",
            "2",
            "--min-labels",
            "2",
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "case_count 1 below required minimum 2" in proc.stderr

        synthetic_intake = tmp / "synthetic_intake"
        make_intake(synthetic_intake, "case-c", repo_a, synthetic=True)
        proc = run_tool(
            "--label-intake-dir",
            str(synthetic_intake),
            "--out-labels",
            str(tmp / "synthetic.jsonl"),
            "--summary",
            str(tmp / "synthetic_summary.json"),
            "--min-cases",
            "1",
            "--min-labels",
            "1",
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "synthetic labels cannot feed AMR beta benchmark input" in proc.stderr

    print("AMR beta benchmark input prepare smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
