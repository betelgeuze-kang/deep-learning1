#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_benchmark_input_prepare.py."""
from __future__ import annotations

import hashlib
import json
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
        out_labels = tmp / "combined" / "combined_benchmark_labels.jsonl"
        summary = tmp / "combined" / "summary.json"
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
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["ready_for_runtime_approved_real_benchmark"] == 1
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert out_labels.is_file()
        assert summary.is_file()
        assert len([line for line in out_labels.read_text(encoding="utf-8").splitlines() if line.strip()]) == 2

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
        )
        assert proc.returncode == 1
        assert "synthetic labels cannot feed AMR beta benchmark input" in proc.stderr

    print("AMR beta benchmark input prepare smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
