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


def make_template(
    path: Path,
    case_id: str,
    candidate_ids: list[str],
    *,
    blocked: bool = False,
    synthetic: str = "0",
    target_repo: Path | None = None,
) -> None:
    path.mkdir()
    rows = []
    for index, candidate_id in enumerate(candidate_ids, start=1):
        rows.append(
            {
                "case_id": case_id,
                "candidate_label_id": candidate_id,
                "template_only": "1",
                "human_labeled": "0",
                "synthetic": synthetic,
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
    if target_repo is not None:
        audit_output = path / "_source_audit"
        audit_output.mkdir()
        (audit_output / "source_snapshot.json").write_text(
            json.dumps({"target_repo": str(target_repo)}, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        (path / "label_template_manifest.json").write_text(
            json.dumps({"input_audit_output": str(audit_output.resolve())}, indent=2, sort_keys=True) + "\n",
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
        template_a = tmp / "template_a"
        template_b = tmp / "template_b"
        make_template(template_a, "case-a", ["case-a-0001", "case-a-0002"])
        make_template(template_b, "case-b", ["case-b-0001"])
        proc = run_tool("--template-dir", str(template_a), "--template-dir", str(template_b), "--json")
        assert proc.returncode == 1
        unverified = json.loads(proc.stdout)
        assert unverified["label_template_verify_existing_required"] == 1
        assert unverified["label_template_verify_existing_failed_dirs"] == 2
        assert "label_template --verify-existing failed" in proc.stderr

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
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        summary = json.loads(proc.stdout)
        assert summary["label_template_verify_existing_required"] == 0
        assert summary["label_template_verify_existing_passed_dirs"] == 0
        assert summary["candidate_label_rows"] == 3
        assert summary["valid_human_label_rows"] == 2
        assert summary["non_synthetic_valid_human_label_rows"] == 2
        assert summary["missing_candidate_label_count"] == 1
        assert summary["human_labels_remaining_to_minimum"] == 298
        assert summary["cases_ready_for_label_intake"] == 1
        assert summary["cases_blocked_for_label_intake"] == 1
        assert summary["case_progress_rows"] == [
            {
                "all_candidates_reviewed": 0,
                "candidate_label_rows": 2,
                "case_id": "case-a",
                "missing_candidate_label_count": 1,
                "ready_for_label_intake": 0,
                "synthetic_candidate_rows": 0,
                "template_dirs": [str(template_a.resolve())],
                "valid_human_label_rows": 1,
            },
            {
                "all_candidates_reviewed": 1,
                "candidate_label_rows": 1,
                "case_id": "case-b",
                "missing_candidate_label_count": 0,
                "ready_for_label_intake": 1,
                "synthetic_candidate_rows": 0,
                "template_dirs": [str(template_b.resolve())],
                "valid_human_label_rows": 1,
            },
        ]
        assert summary["design_partner_beta_candidate_ready"] == 0
        assert summary["decision_input_guard_passed"] == 1
        assert summary["output_path_guard_passed"] == 1
        assert (out_dir / "reviewer_candidate_packet.jsonl").is_file()
        assert (out_dir / "reviewer_progress_summary.json").is_file()

        per_case_root = tmp / "per_case_packets"
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--template-dir",
            str(template_b),
            "--decisions",
            str(decisions),
            "--per-case-out-root",
            str(per_case_root),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        summary = json.loads(proc.stdout)
        assert "reviewer_packet_index.json" in summary["output_files"]
        assert summary["human_labels_remaining_to_minimum"] == 298
        assert summary["cases_ready_for_label_intake"] == 1
        assert summary["cases_blocked_for_label_intake"] == 1
        index = json.loads((per_case_root / "reviewer_packet_index.json").read_text(encoding="utf-8"))
        assert index["case_packet_count"] == 2
        assert index["design_partner_beta_candidate_ready"] == 0
        assert index["case_progress_rows"] == summary["case_progress_rows"]
        case_a_summary = json.loads(
            (per_case_root / "case-a" / "reviewer_progress_summary.json").read_text(encoding="utf-8")
        )
        case_b_summary = json.loads(
            (per_case_root / "case-b" / "reviewer_progress_summary.json").read_text(encoding="utf-8")
        )
        assert case_a_summary["candidate_label_rows"] == 2
        assert case_a_summary["valid_human_label_rows"] == 1
        assert case_a_summary["missing_candidate_label_count"] == 1
        assert case_a_summary["ready_for_label_intake"] == 0
        assert case_b_summary["candidate_label_rows"] == 1
        assert case_b_summary["valid_human_label_rows"] == 1
        assert case_b_summary["ready_for_label_intake"] == 1
        missing_a = (per_case_root / "case-a" / "reviewer_missing_candidates.jsonl").read_text(encoding="utf-8")
        assert "case-a-0002" in missing_a

        synthetic_template = tmp / "synthetic_template"
        make_template(synthetic_template, "case-synthetic", ["case-synthetic-0001"], synthetic="1")
        synthetic_decisions = tmp / "synthetic_decisions.jsonl"
        write_jsonl(
            synthetic_decisions,
            [
                {
                    "candidate_label_id": "case-synthetic-0001",
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                }
            ],
        )
        proc = run_tool(
            "--template-dir",
            str(synthetic_template),
            "--decisions",
            str(synthetic_decisions),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        synthetic_summary = json.loads(proc.stdout)
        assert synthetic_summary["valid_human_label_rows"] == 1
        assert synthetic_summary["non_synthetic_valid_human_label_rows"] == 0
        assert synthetic_summary["human_labels_remaining_to_minimum"] == 300
        assert synthetic_summary["cases_ready_for_label_intake"] == 0
        assert synthetic_summary["cases_blocked_for_label_intake"] == 1
        assert synthetic_summary["case_progress_rows"][0]["synthetic_candidate_rows"] == 1
        assert synthetic_summary["case_progress_rows"][0]["all_candidates_reviewed"] == 1
        assert synthetic_summary["case_progress_rows"][0]["ready_for_label_intake"] == 0

        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--template-dir",
            str(template_b),
            "--per-case-out-root",
            str(per_case_root),
            "--overwrite",
            "--skip-verify-existing",
        )
        assert proc.returncode == 0, proc.stderr
        bad_root = tmp / "bad_per_case_packets"
        bad_root.mkdir()
        (bad_root / "operator_notes.txt").write_text("do not delete\n", encoding="utf-8")
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--per-case-out-root",
            str(bad_root),
            "--overwrite",
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "refusing to delete unrelated per-case packet entry" in proc.stderr

        target_repo = tmp / "target_repo"
        target_repo.mkdir()
        target_template = tmp / "target_template"
        make_template(target_template, "case-target", ["case-target-0001"], target_repo=target_repo)
        proc = run_tool(
            "--template-dir",
            str(target_template),
            "--out",
            str(target_repo / "reviewer_packet"),
            "--per-case-out-root",
            str(target_repo / "per_case_packets"),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        blocked_summary = json.loads(proc.stdout)
        assert blocked_summary["output_path_guard_passed"] == 0
        assert "out must not be inside target repo" in proc.stderr
        assert "per_case_out_root must not be inside target repo" in proc.stderr
        assert not (target_repo / "reviewer_packet").exists()
        assert not (target_repo / "per_case_packets").exists()

        unsafe_decisions = target_repo / "decisions.jsonl"
        write_jsonl(
            unsafe_decisions,
            [{"candidate_label_id": "case-target-0001", "human_labeled": True, "expected": "present"}],
        )
        safe_packet_out = tmp / "safe_packet_out"
        proc = run_tool(
            "--template-dir",
            str(target_template),
            "--decisions",
            str(unsafe_decisions),
            "--out",
            str(safe_packet_out),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        unsafe_decision_summary = json.loads(proc.stdout)
        assert unsafe_decision_summary["decision_input_guard_passed"] == 0
        assert "decisions_1 must not be inside target repo" in proc.stderr
        assert not safe_packet_out.exists()

        same_output_root = tmp / "same_packet_root"
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--out",
            str(same_output_root),
            "--per-case-out-root",
            str(same_output_root),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        same_summary = json.loads(proc.stdout)
        assert same_summary["output_path_guard_passed"] == 0
        assert "per_case_out_root must not reuse out path" in proc.stderr
        assert not same_output_root.exists()

        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--template-dir",
            str(template_b),
            "--decisions",
            str(decisions),
            "--require-all-candidates",
            "--skip-verify-existing",
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
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(bad_decisions),
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "duplicate candidate_label_id" in proc.stderr

        unknown_decisions = tmp / "unknown_decisions.jsonl"
        write_jsonl(
            unknown_decisions,
            [{"candidate_label_id": "case-z-0001", "human_labeled": True, "expected": "present"}],
        )
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(unknown_decisions),
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "unknown candidate_label_id" in proc.stderr

        example_decisions = tmp / "example_decisions.jsonl"
        write_jsonl(
            example_decisions,
            [{"candidate_label_id": "EXAMPLE-case-0001", "human_labeled": True, "expected": "present"}],
        )
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(example_decisions),
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "candidate_label_id must not be example/placeholder" in proc.stderr

        bad_optional_decision_ids = tmp / "bad_optional_decision_ids.jsonl"
        write_jsonl(
            bad_optional_decision_ids,
            [
                {
                    "candidate_label_id": "case-a-0001",
                    "label_id": "EXAMPLE-label",
                    "reviewer_id": "reviewer alpha",
                    "maintainer_id": "EXAMPLE-maintainer",
                    "human_labeled": True,
                    "expected": "present",
                }
            ],
        )
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(bad_optional_decision_ids),
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "label_id must not be example/placeholder" in proc.stderr
        assert "reviewer_id must be a safe identifier" in proc.stderr
        assert "maintainer_id must not be example/placeholder" in proc.stderr

        blocked_template = tmp / "blocked_template"
        make_template(blocked_template, "case-c", ["case-c-0001"], blocked=True)
        proc = run_tool("--template-dir", str(blocked_template), "--skip-verify-existing")
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta label packet smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
