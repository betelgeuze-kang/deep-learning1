#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_discovery_response.py."""
from __future__ import annotations

import csv
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DISCOVER = ROOT / "scripts" / "amr_beta_repo_intake_discover.py"
REQUEST = ROOT / "scripts" / "amr_beta_repo_discovery_request.py"
TOOL = ROOT / "scripts" / "amr_beta_repo_discovery_response.py"
TOOL_SPEC = importlib.util.spec_from_file_location("amr_beta_repo_discovery_response", TOOL)
assert TOOL_SPEC and TOOL_SPEC.loader
TOOL_MODULE = importlib.util.module_from_spec(TOOL_SPEC)
TOOL_SPEC.loader.exec_module(TOOL_MODULE)


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def create_repo(root: Path, name: str) -> Path:
    repo = root / name
    repo.mkdir()
    assert run(["git", "init", "-q"], cwd=repo).returncode == 0
    (repo / "README.md").write_text(f"# {name}\n", encoding="utf-8")
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
    return repo


def git_head(repo: Path) -> str:
    proc = run(["git", "rev-parse", "HEAD"], cwd=repo)
    assert proc.returncode == 0, proc.stderr
    return proc.stdout.strip()


def write_response(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "suggested_case_id",
        "include_for_real_benchmark_intake",
        "owner_or_maintainer_contact",
        "real_benchmark_namespace_confirmed",
        "human_real_repo_source_confirmed",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert TOOL_MODULE.is_forbidden_env_path(Path(".env.secrets") / "response.csv")
        assert TOOL_MODULE.is_forbidden_env_path(tmp / ".env.secrets" / "response.csv")
        assert not TOOL_MODULE.is_forbidden_env_path(tmp / "response.csv")
        repo_a = create_repo(tmp, "repo-a")
        repo_b = create_repo(tmp, "repo-b")
        repo_dirty = create_repo(tmp, "repo-dirty")
        (repo_dirty / "UNTRACKED.txt").write_text("dirty\n", encoding="utf-8")

        discovery = tmp / "discovery.json"
        discover = run(
            [
                sys.executable,
                str(DISCOVER),
                "--root",
                str(tmp),
                "--out-json",
                str(discovery),
                "--json",
            ],
            cwd=ROOT,
        )
        assert discover.returncode == 0, discover.stderr

        request_json = tmp / "request.json"
        request_md = tmp / "request.md"
        request = run(
            [
                sys.executable,
                str(REQUEST),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(request_json),
                "--out-md",
                str(request_md),
                "--json",
            ],
            cwd=ROOT,
        )
        assert request.returncode == 0, request.stderr

        response = tmp / "response.csv"
        write_response(
            response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-01-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                },
                {
                    "suggested_case_id": "candidate-02-repo-b",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-02-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                },
                {
                    "suggested_case_id": "candidate-03-repo-dirty",
                    "include_for_real_benchmark_intake": "false",
                    "owner_or_maintainer_contact": "",
                    "real_benchmark_namespace_confirmed": "false",
                },
            ],
        )
        out_json = tmp / "response_status.json"
        out_md = tmp / "response_status.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(response),
                "--collector-out",
                str(tmp / "repo_intake.md"),
                "--min-repos",
                "2",
                "--out-json",
                str(out_json),
                "--out-md",
                str(out_md),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_repo_discovery_response.v1"
        assert payload["selected_response_rows"] == 2
        assert payload["valid_selected_response_rows"] == 2
        assert payload["ready_for_repo_intake_collect_command"] == 1
        assert payload["repo_intake_rows_counted"] == 0
        assert payload["ready_for_repo_intake"] == 0
        assert payload["writes_repo_intake_sheet"] == 0
        assert payload["runs_audit"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["human_required_cells_remaining"] == 0
        assert payload["request_response_template_recommended_only"] == 0
        assert payload["request_response_template_row_count"] == 0
        completion = payload["response_completion"]
        assert completion["recommended_request_rows"] == 2
        assert completion["selected_truthy_response_rows"] == 2
        assert completion["unselected_response_rows"] == 1
        assert completion["blank_include_response_rows"] == 0
        assert completion["selected_missing_or_invalid_contact_rows"] == 0
        assert completion["selected_missing_namespace_confirmation_rows"] == 0
        assert completion["selected_missing_source_confirmation_rows"] == 0
        assert completion["selected_current_repo_preflight_passed_rows"] == 2
        assert completion["selected_current_repo_preflight_failed_rows"] == 0
        assert completion["selected_current_repo_head_mismatch_rows"] == 0
        assert completion["selected_current_repo_dirty_rows"] == 0
        assert completion["selected_current_repo_missing_or_not_git_rows"] == 0
        assert completion["selected_current_repo_root_mismatch_rows"] == 0
        assert completion["selected_response_rows_remaining_to_minimum"] == 0
        assert "<contact-for-candidate-01-repo-a>" in payload["collector_command_redacted"]
        assert "maintainer-01-contact" not in proc.stdout
        assert "maintainer-01-contact" not in out_json.read_text(encoding="utf-8")
        assert "maintainer-01-contact" not in out_md.read_text(encoding="utf-8")
        assert payload["selected_rows"][0]["owner_or_maintainer_contact_sha256"].startswith("sha256:")
        first_selected = payload["selected_rows"][0]
        assert first_selected["current_repo_git_preflight_passed"] == 1
        assert first_selected["current_repo_git_worktree_confirmed"] == 1
        assert first_selected["current_repo_git_root"] == str(repo_a.resolve())
        assert first_selected["current_repo_git_head"] == git_head(repo_a)
        assert first_selected["current_repo_head_matches_request"] == 1
        assert first_selected["current_repo_clean_worktree"] == 1
        assert str(repo_a.resolve()) in payload["collector_command_redacted"]
        assert "selected_current_repo_preflight_passed_rows" in out_md.read_text(encoding="utf-8")
        assert not (tmp / "repo_intake.md").exists()

        raw_env_request_symlink = tmp / ".env.discovery_response_request"
        raw_env_request_symlink.symlink_to(request_json)
        raw_env_request_out = tmp / "raw_env_request_response_status.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(raw_env_request_symlink),
                "--response",
                str(response),
                "--min-repos",
                "1",
                "--out-json",
                str(raw_env_request_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        raw_env_request_payload = json.loads(proc.stdout)
        assert raw_env_request_payload["ready_for_repo_intake_collect_command"] == 0
        assert "refusing .env-like repo discovery request path" in proc.stderr
        assert not raw_env_request_out.exists()

        raw_env_response_symlink = tmp / ".env.discovery_response_input"
        raw_env_response_symlink.symlink_to(response)
        raw_env_response_out = tmp / "raw_env_response_status.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(raw_env_response_symlink),
                "--min-repos",
                "1",
                "--out-json",
                str(raw_env_response_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        raw_env_response_payload = json.loads(proc.stdout)
        assert raw_env_response_payload["ready_for_repo_intake_collect_command"] == 0
        assert "response must not be .env-like" in proc.stderr
        assert "refusing to read .env-like response path" in proc.stderr
        assert not raw_env_response_out.exists()

        raw_env_collector_target = tmp / "raw_env_collector_target.md"
        raw_env_collector_symlink = tmp / ".env.discovery_response_collector"
        raw_env_collector_symlink.symlink_to(raw_env_collector_target)
        raw_env_collector_out = tmp / "raw_env_collector_response_status.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(response),
                "--collector-out",
                str(raw_env_collector_symlink),
                "--min-repos",
                "1",
                "--out-json",
                str(raw_env_collector_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        raw_env_collector_payload = json.loads(proc.stdout)
        assert raw_env_collector_payload["ready_for_repo_intake_collect_command"] == 0
        assert "collector_out must not be .env-like" in proc.stderr
        assert not raw_env_collector_out.exists()
        assert not raw_env_collector_target.exists()

        raw_env_out_target = tmp / "raw_env_discovery_response_target.json"
        raw_env_out_symlink = tmp / ".env.discovery_response_out"
        raw_env_out_symlink.symlink_to(raw_env_out_target)
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(response),
                "--min-repos",
                "1",
                "--out-json",
                str(raw_env_out_symlink),
                "--overwrite",
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        raw_env_out_payload = json.loads(proc.stdout)
        assert raw_env_out_payload["ready_for_repo_intake_collect_command"] == 0
        assert "out_json must not be .env-like" in proc.stderr
        assert not raw_env_out_target.exists()

        risk_request_json = tmp / "risk_request.json"
        risk_request_payload = json.loads(request_json.read_text(encoding="utf-8"))
        risk_request_payload["request_rows"][0]["path_risk_flags"] = ["runner_worktree_path"]
        risk_request_payload["request_rows"][0]["path_risk_flag_count"] = 1
        risk_request_payload["request_rows"][0]["human_real_repo_source_confirmation_required"] = 1
        risk_request_json.write_text(
            json.dumps(risk_request_payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        risk_missing_response = tmp / "risk_missing_response.csv"
        write_response(
            risk_missing_response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-01-contact",
                    "real_benchmark_namespace_confirmed": "true",
                }
            ],
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(risk_request_json),
                "--response",
                str(risk_missing_response),
                "--min-repos",
                "1",
                "--out-json",
                str(tmp / "risk_missing_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        risk_missing_payload = json.loads(proc.stdout)
        assert risk_missing_payload["ready_for_repo_intake_collect_command"] == 0
        assert risk_missing_payload["human_required_cells_remaining"] == 1
        assert (
            risk_missing_payload["response_completion"]["selected_missing_source_confirmation_rows"]
            == 1
        )
        assert "human_real_repo_source_confirmed must be true" in proc.stderr

        risk_confirmed_response = tmp / "risk_confirmed_response.csv"
        write_response(
            risk_confirmed_response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-01-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                }
            ],
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(risk_request_json),
                "--response",
                str(risk_confirmed_response),
                "--min-repos",
                "1",
                "--out-json",
                str(tmp / "risk_confirmed_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        risk_confirmed_payload = json.loads(proc.stdout)
        assert risk_confirmed_payload["ready_for_repo_intake_collect_command"] == 1
        assert risk_confirmed_payload["human_required_cells_remaining"] == 0
        assert risk_confirmed_payload["selected_rows"][0]["human_real_repo_source_confirmed"] == 1

        blank_response = tmp / "blank_response.csv"
        write_response(
            blank_response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "",
                    "owner_or_maintainer_contact": "",
                    "real_benchmark_namespace_confirmed": "",
                },
                {
                    "suggested_case_id": "candidate-02-repo-b",
                    "include_for_real_benchmark_intake": "",
                    "owner_or_maintainer_contact": "",
                    "real_benchmark_namespace_confirmed": "",
                },
                {
                    "suggested_case_id": "candidate-03-repo-dirty",
                    "include_for_real_benchmark_intake": "",
                    "owner_or_maintainer_contact": "",
                    "real_benchmark_namespace_confirmed": "",
                },
            ],
        )
        blank_out_json = tmp / "blank_response_status.json"
        blank_out_md = tmp / "blank_response_status.md"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(blank_response),
                "--min-repos",
                "2",
                "--out-json",
                str(blank_out_json),
                "--out-md",
                str(blank_out_md),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        blank_payload = json.loads(proc.stdout)
        assert blank_payload["ready_for_repo_intake_collect_command"] == 0
        assert blank_payload["selected_response_rows"] == 0
        assert blank_payload["request_response_template_recommended_only"] == 0
        assert blank_payload["request_response_template_row_count"] == 0
        assert blank_payload["human_required_cells_remaining"] == 3
        blank_completion = blank_payload["response_completion"]
        assert blank_completion["response_row_count"] == 3
        assert blank_completion["selected_truthy_response_rows"] == 0
        assert blank_completion["unselected_response_rows"] == 3
        assert blank_completion["blank_include_response_rows"] == 3
        assert blank_completion["selected_response_rows_remaining_to_minimum"] == 2
        assert "human_required_cells_remaining" in blank_out_md.read_text(encoding="utf-8")
        assert "request_response_template_row_count: 0" in blank_out_md.read_text(encoding="utf-8")

        recommended_request_json = tmp / "recommended_request.json"
        recommended_response_template = tmp / "recommended_response_template.csv"
        recommended_request = run(
            [
                sys.executable,
                str(REQUEST),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(recommended_request_json),
                "--out-response-csv",
                str(recommended_response_template),
                "--response-template-recommended-only",
                "--json",
            ],
            cwd=ROOT,
        )
        assert recommended_request.returncode == 0, recommended_request.stderr
        recommended_proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(recommended_request_json),
                "--response",
                str(recommended_response_template),
                "--min-repos",
                "2",
                "--out-json",
                str(tmp / "recommended_blank_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert recommended_proc.returncode == 0, recommended_proc.stderr
        recommended_payload = json.loads(recommended_proc.stdout)
        assert recommended_payload["request_response_template_recommended_only"] == 1
        assert recommended_payload["request_response_template_row_count"] == 2
        assert recommended_payload["response_row_count"] == 2
        recommended_completion = recommended_payload["response_completion"]
        assert recommended_completion["request_row_count"] == 3
        assert recommended_completion["recommended_request_rows"] == 2
        assert recommended_completion["blank_include_response_rows"] == 2
        assert recommended_completion["human_required_cells_remaining"] == 2

        malformed_request_json = tmp / "malformed_request.json"
        malformed_payload = json.loads(recommended_request_json.read_text(encoding="utf-8"))
        malformed_payload["response_template_row_count"] = "two"
        malformed_request_json.write_text(
            json.dumps(malformed_payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        malformed_proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(malformed_request_json),
                "--response",
                str(recommended_response_template),
                "--min-repos",
                "2",
                "--out-json",
                str(tmp / "malformed_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert malformed_proc.returncode == 1
        assert "repo_discovery_request: response_template_row_count must be an integer >= 0" in malformed_proc.stderr
        assert "Traceback" not in malformed_proc.stderr
        malformed_status = json.loads(malformed_proc.stdout)
        assert (
            "repo_discovery_request: response_template_row_count must be an integer >= 0"
            in malformed_status["errors"]
        )
        assert not (tmp / "malformed_response_status.json").exists()

        dirty_response = tmp / "dirty_response.csv"
        write_response(
            dirty_response,
            [
                {
                    "suggested_case_id": "candidate-03-repo-dirty",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-03-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                }
            ],
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(dirty_response),
                "--min-repos",
                "1",
                "--out-json",
                str(tmp / "dirty_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        assert "selected candidate is not clean/head-ready" in proc.stderr

        placeholder_response = tmp / "placeholder_response.csv"
        write_response(
            placeholder_response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "EXAMPLE-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                }
            ],
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(placeholder_response),
                "--min-repos",
                "1",
                "--out-json",
                str(tmp / "placeholder_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        placeholder_payload = json.loads(proc.stdout)
        assert placeholder_payload["human_required_cells_remaining"] == 1
        assert (
            placeholder_payload["response_completion"]["selected_missing_or_invalid_contact_rows"]
            == 1
        )
        assert "owner_or_maintainer_contact must be human-supplied" in proc.stderr

        unsafe_response = repo_a / "response.csv"
        write_response(
            unsafe_response,
            [
                {
                    "suggested_case_id": "candidate-01-repo-a",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-01-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                }
            ],
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(unsafe_response),
                "--min-repos",
                "1",
                "--out-json",
                str(tmp / "unsafe_response_status.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        assert "response must not be inside target repo" in proc.stderr

        drift_response = tmp / "drift_response.csv"
        (repo_b / "DRIFT.txt").write_text("dirty after request\n", encoding="utf-8")
        write_response(
            drift_response,
            [
                {
                    "suggested_case_id": "candidate-02-repo-b",
                    "include_for_real_benchmark_intake": "true",
                    "owner_or_maintainer_contact": "maintainer-02-contact",
                    "real_benchmark_namespace_confirmed": "true",
                    "human_real_repo_source_confirmed": "true",
                }
            ],
        )
        drift_out_json = tmp / "drift_response_status.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--request-json",
                str(request_json),
                "--response",
                str(drift_response),
                "--min-repos",
                "1",
                "--out-json",
                str(drift_out_json),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        drift_payload = json.loads(proc.stdout)
        assert drift_payload["ready_for_repo_intake_collect_command"] == 0
        assert drift_payload["valid_selected_response_rows"] == 0
        assert (
            drift_payload["response_completion"]["selected_current_repo_preflight_failed_rows"]
            == 1
        )
        assert drift_payload["response_completion"]["selected_current_repo_dirty_rows"] == 1
        assert drift_payload["selected_rows"][0]["current_repo_git_preflight_passed"] == 0
        assert drift_payload["selected_rows"][0]["current_repo_clean_worktree"] == 0
        assert "current git status must be clean" in proc.stderr
        assert not drift_out_json.exists()

    print("AMR beta repo discovery response smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
