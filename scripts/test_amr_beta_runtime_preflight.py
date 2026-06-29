#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_runtime_preflight.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_runtime_preflight.py"


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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
            f"| {case_id} | {repo} | {head} | true | {case_id}@review.invalid | quick | real_benchmark | true | human supplied |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_template(path: Path, case_id: str) -> None:
    path.mkdir()
    row = {
        "case_id": case_id,
        "candidate_label_id": f"{case_id}-0001",
        "template_only": "1",
        "human_labeled": "0",
        "synthetic": "0",
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


def make_label_intake(path: Path, case_id: str, repo: Path, head: str) -> None:
    path.mkdir()
    rows = [
        {
            "case_id": case_id,
            "label_id": f"{case_id}-label-1",
            "repo_path": str(repo),
            "expected_repo_git_head": head,
            "human_labeled": True,
            "synthetic": False,
            "priority": "P1",
            "maintainer_id": "",
            "maintainer_feedback": False,
            "plugin_id": "static",
            "rule_id": "rule",
            "file_path": "README.md",
            "expected_line_start": "1",
            "expected_line_end": "1",
            "expected_span_sha256": "sha256:" + ("b" * 64),
            "expected": "present",
            "expected_abstain": "",
            "source_candidate_label_id": f"{case_id}-0001",
            "source_finding_id": f"{case_id}-finding-1",
            "source_review_queue_id": f"{case_id}-queue-1",
            "source_template_span_sha256": "sha256:" + ("b" * 64),
        }
    ]
    labels = path / "benchmark_labels.jsonl"
    write_jsonl(labels, rows)
    manifest = {
        "schema_version": "local_repo_audit_label_intake_manifest.v1",
        "human_label_rows": 1,
        "label_rows": 1,
        "synthetic_label_rows": 0,
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
        repos = [(f"case-{index:02d}", *create_repo(tmp, index)) for index in range(1, 11)]
        repo_intake = tmp / "repo_intake.md"
        write_repo_intake(repo_intake, repos)
        template_dirs: list[Path] = []
        label_intake_dirs: list[Path] = []
        for case_id, repo, head in repos:
            template_dir = tmp / f"{case_id}_template"
            intake_dir = tmp / f"{case_id}_intake"
            make_template(template_dir, case_id)
            make_label_intake(intake_dir, case_id, repo, head)
            template_dirs.append(template_dir)
            label_intake_dirs.append(intake_dir)
        decisions = tmp / "decisions.jsonl"
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
        feedback = tmp / "feedback.jsonl"
        write_jsonl(
            feedback,
            [
                {
                    "case_id": repos[index][0],
                    "maintainer_id": f"maintainer-{index + 1}",
                    "human_feedback": True,
                    "feedback_text": f"Reviewed {repos[index][0]} candidate labels.",
                }
                for index in range(3)
            ],
        )
        args = [
            "--repo-intake",
            str(repo_intake),
            "--decisions",
            str(decisions),
            "--feedback",
            str(feedback),
            "--min-repos",
            "10",
            "--min-labels",
            "10",
            "--min-maintainers",
            "3",
            "--out-json",
            str(tmp / "preflight.json"),
            "--out-md",
            str(tmp / "preflight.md"),
            "--benchmark-out",
            str(tmp / "audit benchmark"),
            "--json",
        ]
        for template_dir in template_dirs:
            args.extend(["--template-dir", str(template_dir)])
        for intake_dir in label_intake_dirs:
            args.extend(["--label-intake-dir", str(intake_dir)])
        proc = run_tool(*args)
        assert proc.returncode == 1
        assert "label_template --verify-existing failed" in proc.stderr

        args.append("--skip-verify-existing")
        args.append("--overwrite")
        proc = run_tool(*args)
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["ready_to_request_runtime_approval"] == 1
        assert payload["label_template_verify_existing_required"] == 0
        assert payload["label_intake_verify_existing_required"] == 0
        assert payload["benchmark_runtime_approval_required"] == 1
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["valid_repo_rows"] == 10
        assert payload["human_label_rows"] == 10
        assert payload["distinct_countable_maintainer_id_count"] == 3
        benchmark_parts = shlex.split(payload["next_commands"][1])
        assert benchmark_parts[benchmark_parts.index("--out") + 1] == str(tmp / "audit benchmark")
        assert "'" in payload["next_commands"][1]
        assert (tmp / "preflight.json").is_file()
        assert "ready_to_request_runtime_approval: 1" in (tmp / "preflight.md").read_text(encoding="utf-8")

        bad_intake = tmp / "bad_intake"
        make_label_intake(bad_intake, repos[0][0], repos[0][1], "0" * 40)
        bad_args = [
            "--repo-intake",
            str(repo_intake),
            "--decisions",
            str(decisions),
            "--feedback",
            str(feedback),
            "--min-repos",
            "10",
            "--min-labels",
            "10",
            "--min-maintainers",
            "3",
            "--skip-verify-existing",
        ]
        for template_dir in template_dirs:
            bad_args.extend(["--template-dir", str(template_dir)])
        for intake_dir in [bad_intake, *label_intake_dirs[1:]]:
            bad_args.extend(["--label-intake-dir", str(intake_dir)])
        proc = run_tool(*bad_args)
        assert proc.returncode == 1
        assert "expected_repo_git_head does not match repo intake" in proc.stderr

    print("AMR beta runtime preflight smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
