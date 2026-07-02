#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_discovery_request.py."""
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
TOOL = ROOT / "scripts" / "amr_beta_repo_discovery_request.py"
TOOL_SPEC = importlib.util.spec_from_file_location("amr_beta_repo_discovery_request", TOOL)
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


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert TOOL_MODULE.is_forbidden_env_path(Path(".env.secrets") / "request.json")
        assert TOOL_MODULE.is_forbidden_env_path(tmp / ".env.secrets" / "request.json")
        assert not TOOL_MODULE.is_forbidden_env_path(tmp / "request.json")
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

        out_json = tmp / "request.json"
        out_md = tmp / "request.md"
        out_response_csv = tmp / "response_template.csv"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(out_json),
                "--out-md",
                str(out_md),
                "--out-response-csv",
                str(out_response_csv),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_repo_discovery_request.v1"
        assert payload["candidate_repo_count"] == 3
        assert payload["candidate_repos_with_clean_head"] == 2
        assert payload["candidate_repos_with_path_risk"] == 3
        assert payload["candidate_repos_with_clean_head_and_path_risk"] == 2
        assert payload["candidate_repos_with_clean_head_and_no_path_risk"] == 0
        assert payload["request_row_count"] == 3
        assert payload["response_template_csv"] == str(out_response_csv.resolve())
        assert payload["response_template_recommended_only"] == 0
        assert payload["response_template_row_count"] == 3
        assert payload["writes_response_template_csv"] == 1
        assert payload["recommended_contact_request_rows"] == 2
        assert payload["recommended_contact_request_rows_with_path_risk"] == 2
        assert payload["recommended_contact_request_rows_without_path_risk"] == 0
        assert payload["clean_candidate_shortfall_to_minimum"] == 8
        assert payload["clean_risk_free_candidate_shortfall_to_minimum"] == 10
        assert payload["repo_intake_rows_counted"] == 0
        assert payload["ready_for_repo_intake"] == 0
        assert payload["writes_repo_intake_sheet"] == 0
        assert payload["runs_audit"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert all(row["counts_for_repo_intake"] == 0 for row in payload["request_rows"])
        assert all(row["owner_or_maintainer_contact_required"] == 1 for row in payload["request_rows"])
        assert all(row["real_benchmark_namespace_confirmation_required"] == 1 for row in payload["request_rows"])
        assert out_json.exists()
        assert out_response_csv.exists()
        assert json.loads(out_json.read_text(encoding="utf-8")) == payload
        with out_response_csv.open(newline="", encoding="utf-8") as handle:
            response_rows = list(csv.DictReader(handle))
        assert len(response_rows) == 3
        assert response_rows[0]["suggested_case_id"] == "candidate-01-repo-a"
        assert response_rows[0]["include_for_real_benchmark_intake"] == ""
        assert response_rows[0]["owner_or_maintainer_contact"] == ""
        assert response_rows[0]["real_benchmark_namespace_confirmed"] == ""
        assert response_rows[0]["human_real_repo_source_confirmed"] == ""
        assert response_rows[0]["path_risk_flags"] == "temporary_path"
        assert response_rows[0]["repo_path"] == str(repo_a.resolve())
        assert response_rows[0]["notes"] == "recommended_for_contact_request=1"
        assert response_rows[2]["notes"] == "clean_or_fix_repo_before_intake"
        markdown = out_md.read_text(encoding="utf-8")
        assert "AMR Beta Repo Discovery Request" in markdown
        assert "include_for_real_benchmark_intake" in markdown
        assert "owner_or_maintainer_contact" in markdown
        assert "amr_beta_repo_intake_collect.py" in markdown

        recommended_response_csv = tmp / "response_template_recommended.csv"
        recommended_json = tmp / "request_recommended.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(recommended_json),
                "--out-response-csv",
                str(recommended_response_csv),
                "--response-template-recommended-only",
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        recommended_payload = json.loads(proc.stdout)
        assert recommended_payload["request_row_count"] == 3
        assert recommended_payload["recommended_contact_request_rows"] == 2
        assert recommended_payload["response_template_recommended_only"] == 1
        assert recommended_payload["response_template_row_count"] == 2
        with recommended_response_csv.open(newline="", encoding="utf-8") as handle:
            recommended_rows = list(csv.DictReader(handle))
        assert len(recommended_rows) == 2
        assert [row["suggested_case_id"] for row in recommended_rows] == [
            "candidate-01-repo-a",
            "candidate-02-repo-b",
        ]
        assert all(row["notes"] == "recommended_for_contact_request=1" for row in recommended_rows)
        assert str(repo_dirty.resolve()) not in recommended_response_csv.read_text(encoding="utf-8")

        risk_discovery = tmp / "risk_discovery.json"
        risk_payload = json.loads(discovery.read_text(encoding="utf-8"))
        risk_payload["candidates"][0]["path_risk_flags"] = ["temporary_path", "runner_worktree_path"]
        risk_payload["candidates"][0]["path_risk_flag_count"] = 2
        risk_payload["candidates"][0]["human_real_repo_source_confirmation_required"] = 1
        risk_payload["candidate_repos_with_path_risk"] = 3
        risk_payload["candidate_repos_with_clean_head_and_path_risk"] = 2
        risk_payload["candidate_repos_with_clean_head_and_no_path_risk"] = 0
        risk_payload["clean_risk_free_candidate_shortfall_to_minimum"] = 10
        risk_discovery.write_text(json.dumps(risk_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        risk_request = tmp / "risk_request.json"
        risk_response_csv = tmp / "risk_response_template.csv"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(risk_discovery),
                "--out-json",
                str(risk_request),
                "--out-response-csv",
                str(risk_response_csv),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        risk_request_payload = json.loads(proc.stdout)
        assert "human_real_repo_source_confirmed" in risk_request_payload["human_fields_required"]
        assert risk_request_payload["request_rows"][0]["path_risk_flags"] == [
            "temporary_path",
            "runner_worktree_path",
        ]
        assert risk_request_payload["request_rows"][0]["human_real_repo_source_confirmation_required"] == 1
        assert risk_request_payload["candidate_repos_with_clean_head_and_no_path_risk"] == 0
        assert risk_request_payload["candidate_repos_with_clean_head_and_path_risk"] == 2
        assert risk_request_payload["clean_risk_free_candidate_shortfall_to_minimum"] == 10
        with risk_response_csv.open(newline="", encoding="utf-8") as handle:
            risk_response_rows = list(csv.DictReader(handle))
        assert risk_response_rows[0]["human_real_repo_source_confirmed"] == ""
        assert risk_response_rows[0]["path_risk_flags"] == "temporary_path,runner_worktree_path"

        stale_aggregate_discovery = tmp / "stale_aggregate_discovery.json"
        stale_aggregate_payload = json.loads(discovery.read_text(encoding="utf-8"))
        del stale_aggregate_payload["candidate_repos_with_path_risk"]
        del stale_aggregate_payload["candidate_repos_with_clean_head_and_path_risk"]
        del stale_aggregate_payload["candidate_repos_with_clean_head_and_no_path_risk"]
        del stale_aggregate_payload["clean_risk_free_candidate_shortfall_to_minimum"]
        stale_aggregate_discovery.write_text(
            json.dumps(stale_aggregate_payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(stale_aggregate_discovery),
                "--out-json",
                str(tmp / "stale_aggregate_request.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        assert "candidate_repos_with_path_risk is required" in proc.stderr

        stale_discovery = tmp / "stale_discovery.json"
        stale_payload = json.loads(discovery.read_text(encoding="utf-8"))
        del stale_payload["candidates"][0]["path_risk_flags"]
        del stale_payload["candidates"][0]["path_risk_flag_count"]
        del stale_payload["candidates"][0]["human_real_repo_source_confirmation_required"]
        stale_discovery.write_text(json.dumps(stale_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(stale_discovery),
                "--out-json",
                str(tmp / "stale_request.json"),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        assert "path_risk_flags is required" in proc.stderr
        stale_status = json.loads(proc.stdout)
        assert any("path_risk_flags is required" in error for error in stale_status["errors"])

        missing_response_csv = tmp / "missing_response_csv.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(missing_response_csv),
                "--response-template-recommended-only",
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        missing_payload = json.loads(proc.stdout)
        assert missing_payload["response_template_recommended_only"] == 1
        assert missing_payload["response_template_row_count"] == 0
        assert "--response-template-recommended-only requires --out-response-csv" in proc.stderr

        unsafe_out = repo_a / "request.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(unsafe_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["repo_intake_rows_counted"] == 0
        assert unsafe_payload["writes_repo_intake_sheet"] == 0
        assert "out_json must not be inside target repo" in proc.stderr
        assert not unsafe_out.exists()

        bad_discovery = tmp / "bad_discovery.json"
        bad_payload = json.loads(discovery.read_text(encoding="utf-8"))
        bad_payload["candidates"][0]["counts_for_repo_intake"] = 1
        bad_discovery.write_text(json.dumps(bad_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        bad_out = tmp / "bad_request.json"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(bad_discovery),
                "--out-json",
                str(bad_out),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        assert "repo_discovery: candidates row 1: counts_for_repo_intake must be 0" in proc.stderr
        assert not bad_out.exists()

        unsafe_response_csv = repo_b / "response_template.csv"
        proc = run(
            [
                sys.executable,
                str(TOOL),
                "--repo-discovery",
                str(discovery),
                "--out-json",
                str(tmp / "unsafe_response_template_request.json"),
                "--out-response-csv",
                str(unsafe_response_csv),
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 1
        unsafe_response_payload = json.loads(proc.stdout)
        assert unsafe_response_payload["writes_response_template_csv"] == 0
        assert "out_response_csv must not be inside target repo" in proc.stderr
        assert not unsafe_response_csv.exists()

        assert str(repo_b.resolve()) in markdown

    print("AMR beta repo discovery request smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
