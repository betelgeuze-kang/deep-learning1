#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_pr_cleanup_export_plan.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_pr_cleanup_export_plan.py"


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
        out_sh = tmp / "amr_beta_pr_cleanup_export.sh"
        out_json = tmp / "amr_beta_pr_cleanup_export_plan.json"
        pr_state = tmp / "amr_beta_pr_cleanup_state.jsonl"
        status_json = tmp / "amr_beta_pr_cleanup_status.json"
        status_md = tmp / "amr_beta_pr_cleanup_status.md"

        proc = run_tool(
            "--out-sh",
            str(out_sh),
            "--out-json",
            str(out_json),
            "--pr-state-out",
            str(pr_state),
            "--status-json-out",
            str(status_json),
            "--status-md-out",
            str(status_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(proc.stdout)
        assert payload["schema"] == "amr_beta_pr_cleanup_export_plan.v1"
        assert payload["ready_for_pr_cleanup_export_handoff"] == 1
        assert payload["writes_export_script"] == 1
        assert payload["writes_export_plan_json"] == 1
        assert payload["out_json"] == str(out_json.resolve())
        assert payload["out_sh_sha256"].startswith("sha256:")
        assert payload["export_pr_count"] == 5
        assert payload["checklist_pr"] == 46
        assert payload["stale_prs"] == [39, 40, 10, 5]
        assert payload["claim_file_count"] == 3
        assert payload["runs_github_query"] == 0
        assert payload["runs_github_mutation"] == 0
        assert payload["runs_git_push"] == 0
        assert payload["closes_pull_requests"] == 0
        assert payload["merges_pull_requests"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["generated_script_runs_github_query"] == 1
        assert payload["generated_script_runs_github_mutation"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert out_sh.exists()
        assert out_json.exists()
        saved_payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert saved_payload["schema"] == payload["schema"]
        assert saved_payload["out_sh_sha256"] == payload["out_sh_sha256"]
        assert out_sh.stat().st_mode & 0o111

        text = out_sh.read_text(encoding="utf-8")
        assert text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n")
        for number in [46, 39, 40, 10, 5]:
            assert f"gh pr view {number} --json " in text
        assert "number,state,title,url,closed,mergedAt,closedAt,headRefName,baseRefName" in text
        assert "scripts/amr_beta_pr_cleanup_status.py" in text
        assert "--require-claim-scan" in text
        assert str(pr_state) in text
        assert str(status_json) in text
        assert str(status_md) in text
        for claim_file in [
            ROOT / "README.md",
            ROOT / "README.ko.md",
            ROOT / "docs" / "AMR_BETA_HUMAN_INPUT_PACKET.md",
        ]:
            assert str(claim_file.resolve()) in text
        forbidden = [
            "gh pr close",
            "gh pr merge",
            "gh pr create",
            "git push",
            "git merge",
            "git reset",
        ]
        for needle in forbidden:
            assert needle not in text

        original = out_sh.read_text(encoding="utf-8")
        proc = run_tool("--out-sh", str(out_sh), "--json")
        assert proc.returncode == 1
        assert "out_sh already exists; use --overwrite" in proc.stderr
        assert out_sh.read_text(encoding="utf-8") == original

        json_collision = tmp / "json_collision.sh"
        proc = run_tool("--out-sh", str(json_collision), "--out-json", str(out_json), "--json")
        assert proc.returncode == 1
        assert "out_json already exists; use --overwrite" in proc.stderr
        assert not json_collision.exists()

        existing_state = tmp / "existing_state.jsonl"
        existing_state.write_text("source artifact\n", encoding="utf-8")
        existing_state_script = tmp / "existing_state.sh"
        proc = run_tool(
            "--out-sh",
            str(existing_state_script),
            "--pr-state-out",
            str(existing_state),
            "--json",
        )
        assert proc.returncode == 1
        assert "pr_state_out already exists; use --overwrite" in proc.stderr
        assert not existing_state_script.exists()

        claim_collision = tmp / "claim_collision.sh"
        proc = run_tool(
            "--out-sh",
            str(claim_collision),
            "--pr-state-out",
            str(ROOT / "README.md"),
            "--json",
        )
        assert proc.returncode == 1
        assert "pr_state_out must not collide with claim_file" in proc.stderr
        assert not claim_collision.exists()

        duplicate = tmp / "duplicate_pr.sh"
        proc = run_tool("--out-sh", str(duplicate), "--stale-pr", "46", "--json")
        assert proc.returncode == 1
        assert "duplicate PR number in export plan: 46" in proc.stderr
        assert not duplicate.exists()

        env_like = tmp / ".env.pr_cleanup_export"
        proc = run_tool("--out-sh", str(env_like), "--json")
        assert proc.returncode == 1
        assert "out_sh must not be .env-like" in proc.stderr
        assert not env_like.exists()

    print("AMR beta PR cleanup export plan smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
