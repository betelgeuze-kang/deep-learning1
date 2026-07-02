#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_label_packet.py."""
from __future__ import annotations

import json
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_label_packet.py"
AUDIT_TOOL = ROOT / "scripts" / "audit_my_repo.py"
TEMPLATE_TOOL = ROOT / "scripts" / "audit_my_repo_label_template.py"


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def run_checked(args: list[str]) -> subprocess.CompletedProcess:
    proc = subprocess.run(
        args,
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    return proc


def make_audit_target_repo(path: Path, package_name: str) -> None:
    (path / "docs").mkdir(parents=True)
    (path / "README.md").write_text(
        "# Audit Target\n\nThis local audit target is not production ready without evidence.\n",
        encoding="utf-8",
    )
    (path / "module.py").write_text(
        "def answer():\n    return \"ok\"\n",
        encoding="utf-8",
    )
    (path / "docs" / "evidence.md").write_text(
        "# Evidence Notes\n\nThis local evidence note is a citation target, not release proof.\n",
        encoding="utf-8",
    )
    (path / "pyproject.toml").write_text(
        f"[project]\nname = \"{package_name}\"\nrequires-python = \">=3.10\"\n",
        encoding="utf-8",
    )
    run_checked(["git", "-C", str(path), "init", "-q"])
    run_checked(["git", "-C", str(path), "add", "."])
    run_checked(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.email=audit@example.invalid",
            "-c",
            "user.name=Audit Commit",
            "commit",
            "-q",
            "-m",
            "init",
        ]
    )


def make_verified_template(tmp: Path, case_id: str) -> tuple[Path, list[str]]:
    repo = tmp / f"{case_id}_repo"
    audit_out = tmp / f"{case_id}_audit"
    template_out = tmp / f"{case_id}_template"
    repo.mkdir()
    make_audit_target_repo(repo, case_id.replace("_", "-"))
    run_checked(
        [
            sys.executable,
            str(AUDIT_TOOL),
            str(repo),
            "--mode",
            "quick",
            "--max-files",
            "20",
            "--max-total-bytes",
            "200000",
            "--max-file-bytes",
            "50000",
            "--max-findings",
            "20",
            "--out",
            str(audit_out),
            "--namespace",
            "synthetic",
            "--generator",
            "routehint-tiny",
            "--question",
            "Does this repo prove production readiness?",
        ]
    )
    run_checked(
        [
            sys.executable,
            str(TEMPLATE_TOOL),
            "--audit-output",
            str(audit_out),
            "--out",
            str(template_out),
            "--case-id",
            case_id,
        ]
    )
    run_checked([sys.executable, str(TEMPLATE_TOOL), "--verify-existing", str(template_out)])
    payload = json.loads((template_out / "label_template.json").read_text(encoding="utf-8"))
    candidate_ids = [str(row["candidate_label_id"]) for row in payload["rows"]]
    assert candidate_ids
    return template_out, candidate_ids


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
                {
                    "candidate_label_id": "case-a-0001",
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                    "reviewer_id": "reviewer-a",
                },
                {
                    "candidate_label_id": "case-b-0001",
                    "human_labeled": True,
                    "expected": "absent",
                    "priority": "P2",
                    "reviewer_id": "reviewer-b",
                },
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
        assert summary["non_synthetic_candidate_rows"] == 3
        assert summary["label_template_json_sha256s"] == [
            sha256_file(template_a / "label_template.json"),
            sha256_file(template_b / "label_template.json"),
        ]
        assert summary["label_template_manifest_sha256s"] == []
        assert summary["label_template_bundle_sha256"] == sha256_json(summary["label_template_fingerprints"])
        assert summary["decisions_fingerprints"] == [
            {
                "decisions": str(decisions.resolve()),
                "decisions_sha256": sha256_file(decisions),
            }
        ]
        assert summary["decisions_sha256s"] == [sha256_file(decisions)]
        assert summary["decisions_bundle_sha256"] == sha256_json(summary["decisions_fingerprints"])
        assert summary["valid_human_label_rows"] == 2
        assert summary["non_synthetic_valid_human_label_rows"] == 2
        assert summary["valid_human_label_rows_with_reviewer_id"] == 2
        assert summary["valid_human_label_rows_missing_reviewer_id"] == 0
        assert summary["distinct_reviewer_id_count"] == 2
        assert summary["reviewer_progress_rows"] == [
            {
                "non_synthetic_valid_human_label_rows": 1,
                "reviewer_id": "reviewer-a",
                "valid_human_label_rows": 1,
            },
            {
                "non_synthetic_valid_human_label_rows": 1,
                "reviewer_id": "reviewer-b",
                "valid_human_label_rows": 1,
            },
        ]
        assert summary["missing_candidate_label_count"] == 1
        assert summary["human_labels_remaining_to_minimum"] == 298
        assert summary["cases_ready_for_label_intake"] == 1
        assert summary["cases_blocked_for_label_intake"] == 1
        assert summary["ready_for_label_intake"] == 0
        assert summary["case_progress_rows"] == [
            {
                "all_candidates_reviewed": 0,
                "candidate_label_rows": 2,
                "case_id": "case-a",
                "missing_candidate_label_count": 1,
                "non_synthetic_candidate_rows": 2,
                "non_synthetic_valid_human_label_rows": 1,
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
                "non_synthetic_candidate_rows": 1,
                "non_synthetic_valid_human_label_rows": 1,
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

        env_template = tmp / ".env.label_packet_template"
        env_template.symlink_to(template_a)
        proc = run_tool(
            "--template-dir",
            str(env_template),
            "--decisions",
            str(decisions),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        env_template_summary = json.loads(proc.stdout)
        assert env_template_summary["candidate_guard_passed"] == 0
        assert env_template_summary["decision_rows"] == 0
        assert env_template_summary["decisions_sha256s"] == []
        assert "refusing .env-like label template path" in proc.stderr

        env_decisions = tmp / ".env.label_packet_decisions"
        env_decisions.symlink_to(decisions)
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(env_decisions),
            "--out",
            str(tmp / "packet_from_env_decisions"),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        env_decisions_summary = json.loads(proc.stdout)
        assert env_decisions_summary["decision_input_guard_passed"] == 0
        assert env_decisions_summary["decision_rows"] == 0
        assert env_decisions_summary["decisions_sha256s"] == []
        assert "decisions_1 must not be .env-like" in proc.stderr
        assert not (tmp / "packet_from_env_decisions").exists()

        env_out_target = tmp / "packet_env_out_target"
        env_out = tmp / ".env.label_packet_out"
        env_out.symlink_to(env_out_target)
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(decisions),
            "--out",
            str(env_out),
            "--skip-verify-existing",
            "--json",
        )
        assert proc.returncode == 1
        env_out_summary = json.loads(proc.stdout)
        assert env_out_summary["output_path_guard_passed"] == 0
        assert env_out_summary["decision_rows"] == 0
        assert env_out_summary["decisions_sha256s"] == []
        assert "out must not be .env-like" in proc.stderr
        assert not env_out_target.exists()

        proc = run_tool("--verify-existing", str(out_dir), "--json")
        assert proc.returncode == 1
        skipped_verify = json.loads(proc.stdout)
        assert skipped_verify["verify_existing_passed"] == 0
        assert "label_template_verify_existing_required must be 1" in proc.stderr

        env_packet_verify = tmp / ".env.label_packet_verify"
        env_packet_verify.symlink_to(out_dir)
        proc = run_tool("--verify-existing", str(env_packet_verify), "--json")
        assert proc.returncode == 1
        env_packet_verify_payload = json.loads(proc.stdout)
        assert env_packet_verify_payload["verify_existing_passed"] == 0
        assert env_packet_verify_payload["packet_summary_sha256"] == ""
        assert "refusing .env-like packet path" in proc.stderr

        verified_template_a, verified_ids_a = make_verified_template(tmp, "verified_case_a")
        verified_template_b, verified_ids_b = make_verified_template(tmp, "verified_case_b")
        verified_decisions = tmp / "verified_decisions.jsonl"
        write_jsonl(
            verified_decisions,
            [
                {
                    "candidate_label_id": verified_ids_a[0],
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                    "reviewer_id": "reviewer-a",
                },
                {
                    "candidate_label_id": verified_ids_b[0],
                    "human_labeled": True,
                    "expected": "absent",
                    "priority": "P2",
                    "reviewer_id": "reviewer-b",
                },
            ],
        )
        verified_out = tmp / "verified_packet"
        proc = run_tool(
            "--template-dir",
            str(verified_template_a),
            "--template-dir",
            str(verified_template_b),
            "--decisions",
            str(verified_decisions),
            "--out",
            str(verified_out),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        verified_summary_payload = json.loads(proc.stdout)
        assert verified_summary_payload["label_template_verify_existing_required"] == 1
        assert verified_summary_payload["label_template_verify_existing_failed_dirs"] == 0
        assert verified_summary_payload["label_template_verify_existing_passed_dirs"] == 2
        assert verified_summary_payload["valid_human_label_rows"] == 2
        assert verified_summary_payload["missing_candidate_label_count"] >= 1

        proc = run_tool("--verify-existing", str(verified_out), "--json")
        assert proc.returncode == 0, proc.stderr
        verify_summary = json.loads(proc.stdout)
        assert verify_summary["schema"] == "amr_beta_label_packet_verify_existing.v1"
        assert verify_summary["verify_existing_passed"] == 1
        assert verify_summary["creates_benchmark_evidence"] == 0
        assert verify_summary["design_partner_beta_candidate_ready"] == 0
        assert verify_summary["packet_summary_sha256"].startswith("sha256:")

        tampered_out = tmp / "tampered_packet"
        tampered_out.mkdir()
        for child in verified_out.iterdir():
            (tampered_out / child.name).write_text(child.read_text(encoding="utf-8"), encoding="utf-8")
        tampered_summary_path = tampered_out / "reviewer_progress_summary.json"
        tampered_summary = json.loads(tampered_summary_path.read_text(encoding="utf-8"))
        tampered_summary["candidate_label_rows"] = 99
        tampered_summary_path.write_text(
            json.dumps(tampered_summary, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        proc = run_tool("--verify-existing", str(tampered_out), "--json")
        assert proc.returncode == 1
        tampered_verify = json.loads(proc.stdout)
        assert tampered_verify["verify_existing_passed"] == 0
        assert "candidate_label_rows must match reviewer packet artifacts" in proc.stderr

        tampered_missing_out = tmp / "tampered_missing_packet"
        tampered_missing_out.mkdir()
        for child in verified_out.iterdir():
            (tampered_missing_out / child.name).write_text(child.read_text(encoding="utf-8"), encoding="utf-8")
        (tampered_missing_out / "reviewer_missing_candidates.jsonl").write_text("", encoding="utf-8")
        proc = run_tool("--verify-existing", str(tampered_missing_out), "--json")
        assert proc.returncode == 1
        assert "reviewer_missing_candidates must match current decision files" in proc.stderr

        tampered_rows_out = tmp / "tampered_rows_packet"
        tampered_rows_out.mkdir()
        for child in verified_out.iterdir():
            (tampered_rows_out / child.name).write_text(child.read_text(encoding="utf-8"), encoding="utf-8")
        packet_rows = [
            json.loads(line)
            for line in (tampered_rows_out / "reviewer_candidate_packet.jsonl").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        packet_rows[0]["candidate_label_id"] = "tampered-candidate-0001"
        write_jsonl(tampered_rows_out / "reviewer_candidate_packet.jsonl", packet_rows)
        proc = run_tool("--verify-existing", str(tampered_rows_out), "--json")
        assert proc.returncode == 1
        assert "reviewer_candidate_packet must match recorded label templates" in proc.stderr

        original_template_text = (verified_template_a / "label_template.json").read_text(encoding="utf-8")
        tampered_template_payload = json.loads(original_template_text)
        tampered_template_payload["rows"][0]["finding_answer"] = "tampered answer"
        (verified_template_a / "label_template.json").write_text(
            json.dumps(tampered_template_payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        proc = run_tool("--verify-existing", str(verified_out), "--json")
        assert proc.returncode == 1
        assert "label_template --verify-existing failed" in proc.stderr
        (verified_template_a / "label_template.json").write_text(original_template_text, encoding="utf-8")

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
        assert index["reviewer_progress_rows"] == summary["reviewer_progress_rows"]
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
        assert case_a_summary["label_template_bundle_sha256"].startswith("sha256:")
        assert case_a_summary["decisions_bundle_sha256"] == summary["decisions_bundle_sha256"]
        assert case_a_summary["candidate_guard_passed"] == 1
        assert case_b_summary["candidate_label_rows"] == 1
        assert case_b_summary["valid_human_label_rows"] == 1
        assert case_b_summary["ready_for_label_intake"] == 1
        assert case_b_summary["label_template_bundle_sha256"].startswith("sha256:")
        assert case_b_summary["decisions_bundle_sha256"] == summary["decisions_bundle_sha256"]
        missing_a = (per_case_root / "case-a" / "reviewer_missing_candidates.jsonl").read_text(encoding="utf-8")
        assert "case-a-0002" in missing_a
        proc = run_tool("--verify-existing", str(per_case_root), "--json")
        assert proc.returncode == 1
        skipped_per_case_verify = json.loads(proc.stdout)
        assert skipped_per_case_verify["verify_existing_passed"] == 0
        assert "label_template_verify_existing_required must be 1" in proc.stderr

        verified_per_case_root = tmp / "verified_per_case_packets"
        proc = run_tool(
            "--template-dir",
            str(verified_template_a),
            "--template-dir",
            str(verified_template_b),
            "--decisions",
            str(verified_decisions),
            "--per-case-out-root",
            str(verified_per_case_root),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        proc = run_tool("--verify-existing", str(verified_per_case_root), "--json")
        assert proc.returncode == 0, proc.stderr
        per_case_verify = json.loads(proc.stdout)
        assert per_case_verify["verify_existing_passed"] == 1
        assert per_case_verify["creates_benchmark_evidence"] == 0

        index_path = verified_per_case_root / "reviewer_packet_index.json"
        bad_index = json.loads(index_path.read_text(encoding="utf-8"))
        bad_index["candidate_label_rows"] = 99
        index_path.write_text(json.dumps(bad_index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        proc = run_tool("--verify-existing", str(verified_per_case_root), "--json")
        assert proc.returncode == 1
        assert "candidate_label_rows must match reviewer packet artifacts" in proc.stderr

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
        assert synthetic_summary["valid_human_label_rows_missing_reviewer_id"] == 1
        assert synthetic_summary["distinct_reviewer_id_count"] == 0
        assert synthetic_summary["human_labels_remaining_to_minimum"] == 300
        assert synthetic_summary["cases_ready_for_label_intake"] == 0
        assert synthetic_summary["cases_blocked_for_label_intake"] == 1
        assert synthetic_summary["ready_for_label_intake"] == 0
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

        duplicate_label_id_decisions = tmp / "duplicate_label_id_decisions.jsonl"
        write_jsonl(
            duplicate_label_id_decisions,
            [
                {
                    "candidate_label_id": "case-a-0001",
                    "label_id": "case-a-shared-label",
                    "human_labeled": True,
                    "expected": "present",
                },
                {
                    "candidate_label_id": "case-a-0002",
                    "label_id": "case-a-shared-label",
                    "human_labeled": True,
                    "expected": "absent",
                },
            ],
        )
        proc = run_tool(
            "--template-dir",
            str(template_a),
            "--decisions",
            str(duplicate_label_id_decisions),
            "--skip-verify-existing",
        )
        assert proc.returncode == 1
        assert "duplicate label_id" in proc.stderr

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
