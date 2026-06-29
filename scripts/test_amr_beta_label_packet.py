#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_label_packet.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_label_packet.py"


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def make_template(path: Path, case_id: str, candidate_ids: list[str], *, blocked: bool = False) -> None:
    path.mkdir()
    rows = []
    for index, candidate_id in enumerate(candidate_ids, start=1):
        rows.append(
            {
                "case_id": case_id,
                "candidate_label_id": candidate_id,
                "template_only": "1",
                "human_labeled": "0",
                "synthetic": "0",
                "source_finding_id": f"finding-{index}",
                "source_review_queue_id": f"queue-{index}",
                "plugin_id": "static",
                "rule_id": "rule",
                "audit_type": "code",
                "severity": "medium",
                "confidence": "medium",
                "suggested_expected": "present",
                "file_path": "src/app.py",
                "expected_line_start": "1",
                "expected_line_end": "1",
                "expected_span_sha256": "sha256:" + ("a" * 64),
                "citation_id": f"citation-{index}",
                "finding_answer": "Candidate finding summary.",
                "span_text_preview": "source preview",
                "release_ready": "1" if blocked else "0",
                "public_comparison_claim_ready": "0",
                "real_model_execution_ready": "0",
                "design_partner_beta_candidate_ready": "0",
            }
        )
    payload = {
        "schema_version": "local_repo_audit_label_template.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "template_only": 1,
        "human_label_rows": 0,
        "candidate_label_rows": len(rows),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
        "rows": rows,
    }
    (path / "label_template.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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
        template_a = tmp / "template_a"
        template_b = tmp / "template_b"
        make_template(template_a, "case-a", ["case-a-0001", "case-a-0002"])
        make_template(template_b, "case-b", ["case-b-0001"])
        decisions = tmp / "decisions.jsonl"
        write_jsonl(
            decisions,
            [
                {"candidate_label_id": "case-a-0001", "human_labeled": True, "expected": "present", "priority": "P1"},
                {"candidate_label_id": "case-b-0001", "human_labeled": True, "expected": "absent", "priority": "P2"},
            ],
        )
        out_dir = tmp / "packet"
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--template-dir",
            str(template_b),
            "--decisions",
            str(decisions),
            "--out",
            str(out_dir),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        summary = json.loads(proc.stdout)
        assert summary["candidate_label_rows"] == 3
        assert summary["valid_human_label_rows"] == 2
        assert summary["missing_candidate_label_count"] == 1
        assert summary["design_partner_beta_candidate_ready"] == 0
        assert (out_dir / "reviewer_candidate_packet.jsonl").is_file()
        assert (out_dir / "reviewer_progress_summary.json").is_file()

        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--template-dir",
            str(template_b),
            "--decisions",
            str(decisions),
            "--require-all-candidates",
        )
        assert proc.returncode == 1
        assert "missing candidate_label_id decisions" in proc.stderr

        bad_decisions = tmp / "bad_decisions.jsonl"
        write_jsonl(
            bad_decisions,
            [
                {"candidate_label_id": "case-a-0001", "human_labeled": True, "expected": "present"},
                {"candidate_label_id": "case-a-0001", "human_labeled": True, "expected": "absent"},
            ],
        )
        proc = run_tool("--template-dir", str(template_a), "--decisions", str(bad_decisions))
        assert proc.returncode == 1
        assert "duplicate candidate_label_id" in proc.stderr

        unknown_decisions = tmp / "unknown_decisions.jsonl"
        write_jsonl(
            unknown_decisions,
            [{"candidate_label_id": "case-z-0001", "human_labeled": True, "expected": "present"}],
        )
        proc = run_tool("--template-dir", str(template_a), "--decisions", str(unknown_decisions))
        assert proc.returncode == 1
        assert "unknown candidate_label_id" in proc.stderr

        example_decisions = tmp / "example_decisions.jsonl"
        write_jsonl(
            example_decisions,
            [{"candidate_label_id": "EXAMPLE-case-0001", "human_labeled": True, "expected": "present"}],
        )
        proc = run_tool("--template-dir", str(template_a), "--decisions", str(example_decisions))
        assert proc.returncode == 1
        assert "candidate_label_id must not be example/placeholder" in proc.stderr

        blocked_template = tmp / "blocked_template"
        make_template(blocked_template, "case-c", ["case-c-0001"], blocked=True)
        proc = run_tool("--template-dir", str(blocked_template))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta label packet smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
