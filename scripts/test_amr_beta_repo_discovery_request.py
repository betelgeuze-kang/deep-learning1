#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_repo_discovery_request.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DISCOVER = ROOT / "scripts" / "amr_beta_repo_intake_discover.py"
TOOL = ROOT / "scripts" / "amr_beta_repo_discovery_request.py"


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
                "--json",
            ],
            cwd=ROOT,
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_repo_discovery_request.v1"
        assert payload["candidate_repo_count"] == 3
        assert payload["candidate_repos_with_clean_head"] == 2
        assert payload["request_row_count"] == 3
        assert payload["recommended_contact_request_rows"] == 2
        assert payload["clean_candidate_shortfall_to_minimum"] == 8
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
        assert json.loads(out_json.read_text(encoding="utf-8")) == payload
        markdown = out_md.read_text(encoding="utf-8")
        assert "AMR Beta Repo Discovery Request" in markdown
        assert "owner_or_maintainer_contact" in markdown
        assert "amr_beta_repo_intake_collect.py" in markdown

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

        assert str(repo_b.resolve()) in markdown

    print("AMR beta repo discovery request smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
