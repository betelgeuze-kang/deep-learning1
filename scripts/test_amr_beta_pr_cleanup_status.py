#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_pr_cleanup_status.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_pr_cleanup_status.py"


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_json_prefix(text: str) -> dict:
    payload, _ = json.JSONDecoder().raw_decode(text)
    return payload


def pr_row(
    number: int,
    state: str,
    *,
    head: str,
    merged_at: str = "",
    closed_at: str = "2026-06-29T16:11:01Z",
) -> dict:
    return {
        "number": number,
        "state": state,
        "closed": state in {"CLOSED", "MERGED"},
        "closedAt": closed_at if state in {"CLOSED", "MERGED"} else "",
        "mergedAt": merged_at,
        "headRefName": head,
        "baseRefName": "main",
        "title": f"PR {number}",
        "url": f"https://github.example.test/repo/pull/{number}",
    }


def valid_pr_rows() -> list[dict]:
    rows = [
        pr_row(
            46,
            "MERGED",
            head="codex/amr-beta-human-input-checklist",
            merged_at="2026-06-29T16:14:23Z",
            closed_at="2026-06-29T16:14:24Z",
        )
    ]
    for number, head in [
        (39, "fix/ai-verify-pr-safe-smokes"),
        (40, "chore/local-changeset-governance-sync"),
        (10, "pr2-slice-v56-ruler-longbench-expanded"),
        (5, "pr2-slice-v50-auditor-correctness"),
    ]:
        rows.append(pr_row(number, "CLOSED", head=head))
    return rows


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        pr_state = tmp / "pr_state.json"
        claim_file = tmp / "claim_freeze.md"
        write_json(pr_state, valid_pr_rows())
        claim_file.write_text(
            "\n".join(
                [
                    "design_partner_beta_candidate_ready: 0",
                    "release_ready: 0",
                    "public_comparison_claim_ready: 0",
                    "real_model_execution_ready: 0",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        out_json = tmp / "pr_cleanup_status.json"
        out_md = tmp / "pr_cleanup_status.md"
        proc = run_tool(
            "--pr-state",
            str(pr_state),
            "--claim-file",
            str(claim_file),
            "--require-claim-scan",
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = load_json_prefix(proc.stdout)
        assert payload["schema"] == "amr_beta_pr_cleanup_status.v1"
        assert payload["stage_0_claim_freeze_verified"] == 1
        assert payload["checklist_pr_number"] == 46
        assert payload["checklist_pr_merged"] == 1
        assert payload["stale_pr_numbers"] == [39, 40, 10, 5]
        assert payload["stale_pr_closed_count"] == 4
        assert payload["stale_prs_closed"] == 1
        assert payload["claim_freeze_scan_passed"] == 1
        assert payload["claim_scan_files"][0]["path"] == str(claim_file.resolve())
        assert payload["claim_scan_files"][0]["sha256"].startswith("sha256:")
        assert payload["claim_scan_blocked_promotions"] == 0
        assert payload["output_path_guard_passed"] == 1
        assert payload["runs_github_query"] == 0
        assert payload["runs_github_mutation"] == 0
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert out_json.exists()
        assert out_md.exists()

        jsonl_state = tmp / "pr_state.jsonl"
        jsonl_state.write_text(
            "".join(json.dumps(row, sort_keys=True) + "\n" for row in valid_pr_rows()),
            encoding="utf-8",
        )
        proc = run_tool("--pr-state", str(jsonl_state), "--claim-file", str(claim_file), "--json")
        assert proc.returncode == 0, proc.stderr
        assert load_json_prefix(proc.stdout)["input_pr_state_sha256"].startswith("sha256:")

        missing_stale = tmp / "missing_stale.json"
        write_json(missing_stale, [row for row in valid_pr_rows() if row["number"] != 40])
        missing_out = tmp / "missing_status.json"
        proc = run_tool(
            "--pr-state",
            str(missing_stale),
            "--claim-file",
            str(claim_file),
            "--out-json",
            str(missing_out),
            "--json",
        )
        assert proc.returncode == 1
        assert "stale PR #40 missing from PR state export" in proc.stderr
        assert load_json_prefix(proc.stdout)["stage_0_claim_freeze_verified"] == 0
        assert not missing_out.exists()

        open_stale_rows = valid_pr_rows()
        for row in open_stale_rows:
            if row["number"] == 39:
                row.update({"state": "OPEN", "closed": False, "closedAt": ""})
        open_stale = tmp / "open_stale.json"
        write_json(open_stale, {"pull_requests": open_stale_rows})
        proc = run_tool("--pr-state", str(open_stale), "--claim-file", str(claim_file), "--json")
        assert proc.returncode == 1
        assert "stale PR #39 must be closed without merging" in proc.stderr
        assert "stale PR #39 must not remain open" in proc.stderr

        merged_stale_rows = valid_pr_rows()
        for row in merged_stale_rows:
            if row["number"] == 39:
                row.update(
                    {
                        "state": "MERGED",
                        "closed": True,
                        "closedAt": "2026-06-29T16:11:01Z",
                        "mergedAt": "2026-06-29T16:11:00Z",
                    }
                )
        merged_stale = tmp / "merged_stale.json"
        write_json(merged_stale, merged_stale_rows)
        proc = run_tool("--pr-state", str(merged_stale), "--claim-file", str(claim_file), "--json")
        assert proc.returncode == 1
        assert "stale PR #39 must be closed without merging" in proc.stderr
        assert "stale PR #39 must not be merged" in proc.stderr

        unmerged_checklist_rows = valid_pr_rows()
        for row in unmerged_checklist_rows:
            if row["number"] == 46:
                row.update({"state": "CLOSED", "closed": True, "mergedAt": ""})
        unmerged_checklist = tmp / "unmerged_checklist.json"
        write_json(unmerged_checklist, unmerged_checklist_rows)
        proc = run_tool("--pr-state", str(unmerged_checklist), "--claim-file", str(claim_file), "--json")
        assert proc.returncode == 1
        assert "checklist PR #46 must be merged" in proc.stderr

        promoted_claim = tmp / "promoted_claim.md"
        promoted_key = "release_ready"
        promoted_claim.write_text(f'"{promoted_key}": true\n', encoding="utf-8")
        proc = run_tool(
            "--pr-state",
            str(pr_state),
            "--claim-file",
            str(promoted_claim),
            "--require-claim-scan",
            "--json",
        )
        assert proc.returncode == 1
        assert f"claim freeze violation: {promoted_key}=1" in proc.stderr
        assert load_json_prefix(proc.stdout)["claim_scan_blocked_promotions"] == 1

        promoted_upper_claim = tmp / "promoted_upper_claim.md"
        promoted_upper_key = "design_" "partner_beta_candidate_ready"
        promoted_upper_claim.write_text(f"{promoted_upper_key} = TRUE\n", encoding="utf-8")
        proc = run_tool(
            "--pr-state",
            str(pr_state),
            "--claim-file",
            str(promoted_upper_claim),
            "--require-claim-scan",
            "--json",
        )
        assert proc.returncode == 1
        assert f"claim freeze violation: {promoted_upper_key}" in proc.stderr
        assert "=1" in proc.stderr
        assert load_json_prefix(proc.stdout)["claim_scan_blocked_promotions"] == 1

        collision_before = pr_state.read_text(encoding="utf-8")
        proc = run_tool(
            "--pr-state",
            str(pr_state),
            "--claim-file",
            str(claim_file),
            "--out-json",
            str(pr_state),
            "--overwrite",
            "--json",
        )
        assert proc.returncode == 1
        assert "out_json must not overwrite pr_state" in proc.stderr
        assert load_json_prefix(proc.stdout)["output_path_guard_passed"] == 0
        assert pr_state.read_text(encoding="utf-8") == collision_before

        proc = run_tool("--pr-state", str(pr_state), "--json")
        assert proc.returncode == 1
        assert "at least one --claim-file is required to verify claim freeze" in proc.stderr

    print("AMR beta PR cleanup status smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
