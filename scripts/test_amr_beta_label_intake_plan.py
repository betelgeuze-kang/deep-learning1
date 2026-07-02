#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_label_intake_plan.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_label_intake_plan.py"
PACKET_TOOL = ROOT / "scripts" / "amr_beta_label_packet.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def create_repo(root: Path, index: int) -> tuple[Path, str]:
    repo = root / f"repo {index:02d}"
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


def write_intake(path: Path, repos: list[tuple[str, Path, str]]) -> None:
    lines = [
        "| case_id | repo_path | expected_repo_git_head | clean_worktree | owner_or_maintainer_contact | audit_mode | namespace | real_benchmark_namespace_confirmed | notes |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for case_id, repo, head in repos:
        lines.append(
            f"| {case_id} | {repo} | {head} | true | {case_id}-maintainer-contact | quick | real_benchmark | true | human supplied |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_template(path: Path, case_id: str, *, synthetic: str = "0") -> None:
    path.mkdir()
    row = {
        "case_id": case_id,
        "candidate_label_id": f"{case_id}-0001",
        "template_only": "1",
        "human_labeled": "0",
        "synthetic": synthetic,
        "source_finding_id": f"{case_id}-finding-1",
        "source_review_queue_id": f"{case_id}-queue-1",
        "plugin_id": "static",
        "rule_id": "rule",
        "audit_type": "code",
        "severity": "medium",
        "confidence": "medium",
        "suggested_expected": "present",
        "file_path": "README.md",
        "expected_line_start": "1",
        "expected_line_end": "1",
        "expected_span_sha256": "sha256:" + ("b" * 64),
        "citation_id": f"{case_id}-citation-1",
        "finding_answer": "Candidate finding summary.",
        "span_text_preview": "# repo",
        "release_ready": "0",
        "public_comparison_claim_ready": "0",
        "real_model_execution_ready": "0",
        "design_partner_beta_candidate_ready": "0",
    }
    payload = {
        "schema_version": "local_repo_audit_label_template.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "template_only": 1,
        "human_label_rows": 0,
        "candidate_label_rows": 1,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
        "rows": [row],
    }
    write_json(path / "label_template.json", payload)


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def run_packet_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(PACKET_TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        repos = [(f"case-{index:02d}", *create_repo(tmp, index)) for index in range(1, 11)]
        intake = tmp / "repo intake.md"
        write_intake(intake, repos)
        template_dirs: list[Path] = []
        for case_id, _repo, _head in repos:
            template_dir = tmp / f"{case_id} template"
            make_template(template_dir, case_id)
            template_dirs.append(template_dir)
        decisions = tmp / "human decisions.jsonl"
        write_jsonl(
            decisions,
            [
                {
                    "candidate_label_id": f"{case_id}-0001",
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                }
                for case_id, _repo, _head in repos
            ],
        )
        packet_args = [
            "--decisions",
            str(decisions),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            packet_args.extend(["--template-dir", str(template_dir)])
        packet_proc = run_packet_tool(*packet_args)
        assert packet_proc.returncode == 0, packet_proc.stderr
        label_packet_summary = tmp / "label_packet_summary.json"
        label_packet_summary.write_text(packet_proc.stdout, encoding="utf-8")
        label_packet_payload = json.loads(packet_proc.stdout)
        out_root = tmp / "label intake outputs"
        out_json = tmp / "label_intake_plan.json"
        out_md = tmp / "label_intake_plan.md"
        out_commands = tmp / "label_intake_commands.sh"
        unverified_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "unverified_plan.json"),
            "--json",
        ]
        for template_dir in template_dirs:
            unverified_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*unverified_args)
        assert proc.returncode == 1
        unverified, _ = json.JSONDecoder().raw_decode(proc.stdout.lstrip())
        assert unverified["errors"]
        assert "label_template --verify-existing failed" in proc.stderr
        assert not (tmp / "unverified_plan.json").exists()

        args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--out-root",
            str(out_root),
            "--min-labels",
            "10",
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--out-commands-sh",
            str(out_commands),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*args)
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["schema"] == "amr_beta_label_intake_plan.v1"
        assert payload["repo_intake_sha256"] == sha256_file(intake)
        assert payload["repo_snapshot_lock_sha256"].startswith("sha256:")
        assert payload["decisions_sha256"] == sha256_file(decisions)
        assert payload["label_packet_summary"] == str(label_packet_summary.resolve())
        assert payload["label_packet_summary_sha256"] == sha256_file(label_packet_summary)
        assert payload["label_packet_summary_bound"] == 1
        assert payload["label_packet_decisions_fingerprints"] == label_packet_payload["decisions_fingerprints"]
        assert payload["label_packet_decisions_bundle_sha256"] == label_packet_payload["decisions_bundle_sha256"]
        assert payload["label_packet_template_bundle_sha256"] == label_packet_payload["label_template_bundle_sha256"]
        assert payload["label_template_json_sha256s"] == [
            sha256_file(template_dir / "label_template.json") for template_dir in template_dirs
        ]
        assert payload["label_template_manifest_sha256s"] == []
        assert payload["label_template_bundle_sha256"] == sha256_json(payload["label_template_fingerprints"])
        assert payload["label_template_verify_existing_required"] == 0
        assert payload["label_template_verify_existing_passed_dirs"] == 0
        assert payload["case_count"] == 10
        assert payload["candidate_label_rows"] == 10
        assert payload["synthetic_candidate_rows"] == 0
        assert payload["non_synthetic_candidate_rows"] == 10
        assert payload["valid_human_label_rows"] == 10
        assert payload["non_synthetic_valid_human_label_rows"] == 10
        assert payload["human_label_requirement_met"] == 1
        assert payload["human_labels_remaining_to_minimum"] == 0
        assert payload["ready_for_label_intake_plan"] == 1
        assert payload["decision_input_guard_passed"] == 1
        assert payload["output_path_guard_passed"] == 1
        assert payload["compiles_labels"] == 0
        assert payload["writes_label_intake_outputs"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["runs_real_benchmark"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert payload["operator_command_count"] == 20
        assert payload["writes_operator_command_script"] == 1
        assert payload["operator_commands_script"] == str(out_commands.resolve())
        assert payload["operator_commands_script_sha256"] == sha256_file(out_commands)
        assert payload["operator_commands_script_command_count"] == 20
        assert out_commands.stat().st_mode & 0o111
        command_script = out_commands.read_text(encoding="utf-8")
        assert command_script.startswith("#!/usr/bin/env bash\nset -euo pipefail\n")
        assert "Generated by scripts/amr_beta_label_intake_plan.py" in command_script
        assert "repo_snapshot_lock_sha256: sha256:" in command_script
        assert "label_template_bundle_sha256: sha256:" in command_script
        assert f"decisions_sha256: {sha256_file(decisions)}" in command_script
        assert f"operator_commands_sha256: {payload['operator_commands_sha256']}" in command_script
        assert "operator_command_count: 20" in command_script
        assert command_script.count("# command ") == 20
        for command in payload["operator_commands"]:
            assert command in command_script
        first = payload["per_case"][0]
        compile_parts = shlex.split(first["compile_command"])
        assert compile_parts[0] == "python3"
        assert compile_parts[1] == "scripts/audit_my_repo_label_intake.py"
        assert compile_parts[compile_parts.index("--template") + 1] == str(template_dirs[0])
        assert compile_parts[compile_parts.index("--decisions") + 1] == str(decisions)
        assert compile_parts[compile_parts.index("--repo-path") + 1] == str(repos[0][1])
        assert compile_parts[compile_parts.index("--expected-repo-git-head") + 1] == repos[0][2].lower()
        assert compile_parts[compile_parts.index("--out") + 1] == str(out_root / "case-01_label_intake")
        assert "'" in first["compile_command"]
        verify_parts = shlex.split(first["verify_command"])
        assert verify_parts[1] == "scripts/audit_my_repo_label_intake.py"
        assert verify_parts[verify_parts.index("--verify-existing") + 1] == str(out_root / "case-01_label_intake")
        markdown = out_md.read_text(encoding="utf-8")
        assert "ready_for_label_intake_plan: 1" in markdown
        assert "non_synthetic_valid_human_label_rows: 10" in markdown
        assert "synthetic_candidate_rows: 0" in markdown
        assert "human_labels_remaining_to_minimum: 0" in markdown
        assert "decision_input_guard_passed: 1" in markdown
        assert "output_path_guard_passed: 1" in markdown
        assert "compiles_labels: 0" in markdown
        assert "repo_snapshot_lock_sha256: sha256:" in markdown
        assert "label_template_bundle_sha256: sha256:" in markdown
        assert "label_packet_summary_bound: 1" in markdown
        assert "label_packet_decisions_bundle_sha256: sha256:" in markdown
        assert "writes_operator_command_script: 1" in markdown
        assert f"operator_commands_script: {out_commands.resolve()}" in markdown
        assert "operator_commands_script_sha256: sha256:" in markdown
        assert "operator_commands_script_command_count: 20" in markdown

        stale_label_packet_summary = tmp / "stale_label_packet_summary.json"
        stale_label_packet_payload = dict(label_packet_payload)
        stale_label_packet_payload["decisions_bundle_sha256"] = "sha256:" + ("9" * 64)
        write_json(stale_label_packet_summary, stale_label_packet_payload)
        stale_packet_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(stale_label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "stale_packet_plan.json"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            stale_packet_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*stale_packet_args)
        assert proc.returncode == 1
        assert "label_packet_summary: decisions_bundle_sha256 must match label_intake_plan" in proc.stderr
        assert not (tmp / "stale_packet_plan.json").exists()

        unsafe_output_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--out-root",
            str(repos[0][1] / "label_intake_outputs"),
            "--min-labels",
            "10",
            "--out-json",
            str(repos[1][1] / "label_intake_plan.json"),
            "--out-md",
            str(repos[2][1] / "label_intake_plan.md"),
            "--out-commands-sh",
            str(repos[3][1] / "label_intake_commands.sh"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            unsafe_output_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*unsafe_output_args)
        assert proc.returncode == 1
        assert "out_root must not be inside target repo" in proc.stderr
        assert "out_json must not be inside target repo" in proc.stderr
        assert "out_md must not be inside target repo" in proc.stderr
        assert "out_commands_sh must not be inside target repo" in proc.stderr
        assert not (repos[0][1] / "label_intake_outputs").exists()
        assert not (repos[1][1] / "label_intake_plan.json").exists()
        assert not (repos[2][1] / "label_intake_plan.md").exists()
        assert not (repos[3][1] / "label_intake_commands.sh").exists()

        env_intake = tmp / ".env.label_intake_repo_intake"
        env_intake.symlink_to(intake)
        env_intake_plan = tmp / "env_intake_plan.json"
        env_intake_args = [
            "--repo-intake",
            str(env_intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_intake_plan),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_intake_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_intake_args)
        assert proc.returncode == 1
        assert "refusing .env-like repo intake path" in proc.stderr
        assert not env_intake_plan.exists()

        env_decisions = tmp / ".env.label_intake_decisions"
        env_decisions.symlink_to(decisions)
        env_decisions_plan = tmp / "env_decisions_plan.json"
        env_decisions_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(env_decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_decisions_plan),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_decisions_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_decisions_args)
        assert proc.returncode == 1
        assert "refusing .env-like decisions path" in proc.stderr
        assert "case-01-0001" not in proc.stdout
        assert "case-01-0001" not in proc.stderr
        assert not env_decisions_plan.exists()

        env_component_dir = tmp / ".env.secrets"
        env_component_dir.mkdir()
        env_component_decisions = env_component_dir / "decisions.jsonl"
        env_component_decisions.symlink_to(decisions)
        env_component_decisions_plan = tmp / "env_component_decisions_plan.json"
        env_component_decisions_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(env_component_decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_component_decisions_plan),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_component_decisions_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_component_decisions_args)
        assert proc.returncode == 1
        assert "refusing .env-like decisions path" in proc.stderr
        assert "case-01-0001" not in proc.stdout
        assert "case-01-0001" not in proc.stderr
        assert not env_component_decisions_plan.exists()

        env_summary = tmp / ".env.label_packet_summary"
        env_summary.symlink_to(label_packet_summary)
        env_summary_plan = tmp / "env_summary_plan.json"
        env_summary_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(env_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_summary_plan),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_summary_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_summary_args)
        assert proc.returncode == 1
        assert "refusing .env-like label packet summary path" in proc.stderr
        assert not env_summary_plan.exists()

        env_template = tmp / ".env.label_template_dir"
        env_template.symlink_to(template_dirs[0])
        env_template_plan = tmp / "env_template_plan.json"
        env_template_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--template-dir",
            str(env_template),
            "--min-labels",
            "10",
            "--out-json",
            str(env_template_plan),
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs[1:]:
            env_template_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_template_args)
        assert proc.returncode == 1
        assert "template_dir[1] must not be .env-like" in proc.stderr
        assert not env_template_plan.exists()

        env_out_target = repos[0][1] / "env_label_intake_plan_target.json"
        env_out = tmp / ".env.label_intake_plan_out"
        env_out.symlink_to(env_out_target)
        env_out_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_out),
            "--overwrite",
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_out_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_out_args)
        assert proc.returncode == 1
        env_out_payload = json.loads(proc.stdout)
        assert env_out_payload["errors"].count("out_json must not be .env-like") == 1
        assert proc.stderr.count("out_json must not be .env-like") == 1
        assert "inside target repo" not in proc.stderr
        assert env_out_target.name not in proc.stdout
        assert env_out_target.name not in proc.stderr
        assert not env_out_target.exists()

        env_component_out = env_component_dir / "plan.json"
        env_component_out_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_component_out),
            "--overwrite",
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_component_out_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_component_out_args)
        assert proc.returncode == 1
        env_component_out_payload = json.loads(proc.stdout)
        assert env_component_out_payload["errors"].count("out_json must not be .env-like") == 1
        assert proc.stderr.count("out_json must not be .env-like") == 1
        assert not env_component_out.exists()

        env_commands_target = repos[0][1] / "env_label_intake_commands.sh"
        env_commands = tmp / ".env.label_intake_commands"
        env_commands.symlink_to(env_commands_target)
        env_commands_plan = tmp / "env_commands_plan.json"
        env_commands_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--label-packet-summary",
            str(label_packet_summary),
            "--min-labels",
            "10",
            "--out-json",
            str(env_commands_plan),
            "--out-commands-sh",
            str(env_commands),
            "--overwrite",
            "--skip-verify-existing",
            "--json",
        ]
        for template_dir in template_dirs:
            env_commands_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*env_commands_args)
        assert proc.returncode == 1
        env_commands_payload = json.loads(proc.stdout)
        assert env_commands_payload["errors"].count("out_commands_sh must not be .env-like") == 1
        assert proc.stderr.count("out_commands_sh must not be .env-like") == 1
        assert "inside target repo" not in proc.stderr
        assert env_commands_target.name not in proc.stdout
        assert env_commands_target.name not in proc.stderr
        assert not env_commands_target.exists()
        assert not env_commands_plan.exists()

        missing_decisions = tmp / "missing decisions.jsonl"
        write_jsonl(
            missing_decisions,
            [
                {
                    "candidate_label_id": f"{case_id}-0001",
                    "human_labeled": True,
                    "expected": "present",
                }
                for case_id, _repo, _head in repos[:9]
            ],
        )
        bad_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(missing_decisions),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "missing_plan.json"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            bad_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*bad_args)
        assert proc.returncode == 1
        assert "missing candidate_label_id decisions" in proc.stderr
        assert not (tmp / "missing_plan.json").exists()

        bad_optional_decision_ids = tmp / "bad optional decision ids.jsonl"
        write_jsonl(
            bad_optional_decision_ids,
            [
                {
                    "candidate_label_id": f"{case_id}-0001",
                    "label_id": "EXAMPLE-label" if index == 0 else f"{case_id}-0001",
                    "reviewer_id": "reviewer alpha" if index == 0 else "reviewer-alpha",
                    "human_labeled": True,
                    "expected": "present",
                }
                for index, (case_id, _repo, _head) in enumerate(repos)
            ],
        )
        bad_optional_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(bad_optional_decision_ids),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "bad_optional_plan.json"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            bad_optional_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*bad_optional_args)
        assert proc.returncode == 1
        assert "label_id must not be example/placeholder" in proc.stderr
        assert "reviewer_id must be a safe identifier" in proc.stderr
        assert not (tmp / "bad_optional_plan.json").exists()

        duplicate_label_id_decisions = tmp / "duplicate label id decisions.jsonl"
        write_jsonl(
            duplicate_label_id_decisions,
            [
                {
                    "candidate_label_id": f"{case_id}-0001",
                    "label_id": "shared-label" if index < 2 else f"{case_id}-0001",
                    "human_labeled": True,
                    "expected": "present",
                }
                for index, (case_id, _repo, _head) in enumerate(repos)
            ],
        )
        duplicate_label_id_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(duplicate_label_id_decisions),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "duplicate_label_id_plan.json"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            duplicate_label_id_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*duplicate_label_id_args)
        assert proc.returncode == 1
        assert "duplicate label_id" in proc.stderr
        assert not (tmp / "duplicate_label_id_plan.json").exists()

        synthetic_template = tmp / "case-01 synthetic template"
        make_template(synthetic_template, "case-01", synthetic="1")
        synthetic_args = [
            "--repo-intake",
            str(intake),
            "--decisions",
            str(decisions),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "synthetic_plan.json"),
            "--skip-verify-existing",
            "--template-dir",
            str(synthetic_template),
        ]
        for template_dir in template_dirs[1:]:
            synthetic_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*synthetic_args)
        assert proc.returncode == 1
        assert "non_synthetic_valid_human_label_rows 9 below required minimum 10" in proc.stderr
        assert "must be non-synthetic" in proc.stderr

        unsafe_decisions = repos[0][1] / "human_decisions_inside_repo.jsonl"
        write_jsonl(
            unsafe_decisions,
            [
                {
                    "candidate_label_id": f"{case_id}-0001",
                    "human_labeled": True,
                    "expected": "present",
                    "priority": "P1",
                }
                for case_id, _repo, _head in repos
            ],
        )
        assert run(["git", "add", unsafe_decisions.name], cwd=repos[0][1]).returncode == 0
        unsafe_commit = run(
            [
                "git",
                "-c",
                "user.name=AMR Test",
                "-c",
                "user.email=amr-test@example.invalid",
                "commit",
                "-q",
                "-m",
                "add human decisions",
            ],
            cwd=repos[0][1],
        )
        assert unsafe_commit.returncode == 0, unsafe_commit.stderr
        unsafe_head = run(["git", "rev-parse", "HEAD"], cwd=repos[0][1])
        assert unsafe_head.returncode == 0
        unsafe_repos = [
            (case_id, repo, unsafe_head.stdout.strip() if index == 0 else head)
            for index, (case_id, repo, head) in enumerate(repos)
        ]
        unsafe_intake = tmp / "unsafe decisions repo intake.md"
        write_intake(unsafe_intake, unsafe_repos)
        unsafe_decision_args = [
            "--repo-intake",
            str(unsafe_intake),
            "--decisions",
            str(unsafe_decisions),
            "--min-labels",
            "10",
            "--out-json",
            str(tmp / "unsafe_decisions_plan.json"),
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            unsafe_decision_args.extend(["--template-dir", str(template_dir)])
        proc = run_tool(*unsafe_decision_args)
        assert proc.returncode == 1
        assert "decisions must not be inside target repo" in proc.stderr
        assert not (tmp / "unsafe_decisions_plan.json").exists()

    print("AMR beta label intake plan smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
