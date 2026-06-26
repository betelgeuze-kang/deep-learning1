"""Deterministic smoke test for scripts/audit_review_to_jsonl.py.

Run:  python3 scripts/test_audit_review_to_jsonl.py
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "audit_review_to_jsonl.py"


def body(sha, fid, validity, priority, citation, independence, notes="ok"):
    return (
        f"### Repository commit SHA\n\n{sha}\n\n"
        f"### Finding ID\n\n{fid}\n\n"
        f"### Finding validity\n\n{validity}\n\n"
        f"### Priority\n\n{priority}\n\n"
        f"### Citation correctness\n\n{citation}\n\n"
        f"### Expected source span\n\npath/to/file.py:10-20\n\n"
        f"### Reviewer independence\n\n{independence}\n\n"
        f"### Reviewer notes / rationale\n\n{notes}\n"
    )


def run_tool(*args: str):
    return subprocess.run(
        [sys.executable, str(TOOL), *args], cwd=str(ROOT),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)

        # 1. dir of .md bodies -> convert -> validate -> summarize
        issues = tmp / "issues"
        issues.mkdir()
        (issues / "101.md").write_text(body("abc1234", "F-001", "present", "P0", "correct", "external-maintainer"), encoding="utf-8")
        (issues / "102.md").write_text(body("def5678", "F-002", "absent", "P1", "incorrect", "independent-third-party"), encoding="utf-8")
        decisions = tmp / "decisions.jsonl"
        assert run_tool("convert", "--issues", str(issues), "--out", str(decisions)).returncode == 0
        rows = [json.loads(l) for l in decisions.read_text().splitlines() if l.strip()]
        assert len(rows) == 2 and all(r["valid"] for r in rows)
        assert {r["finding_validity"] for r in rows} == {"present", "absent"}
        assert run_tool("validate", "--decisions", str(decisions)).returncode == 0
        summary = json.loads(run_tool("summarize", "--decisions", str(decisions)).stdout)
        assert summary["total_labels"] == 2 and summary["distinct_repos"] == 2
        assert summary["precision"] == 0.5 and summary["citation_validity"] == 0.5
        print("convert(dir) + validate + summarize OK")

        # 2. JSON issues list -> reviewer + issue_ref carried through
        issues_json = tmp / "issues.json"
        issues_json.write_text(json.dumps([
            {"number": 201, "user": {"login": "maintainer-x"}, "created_at": "2026-06-25T00:00:00Z",
             "body": body("aaaaaaa", "F-010", "present", "P0", "correct", "external-maintainer")},
        ]), encoding="utf-8")
        d2 = tmp / "d2.jsonl"
        assert run_tool("convert", "--issues", str(issues_json), "--out", str(d2)).returncode == 0
        row = json.loads(d2.read_text().splitlines()[0])
        assert row["reviewer"] == "maintainer-x" and row["issue_ref"] == "201"
        print("convert(json) carries reviewer/issue_ref OK")

        # 3. invalid value -> convert marks invalid, validate blocks
        bad = tmp / "bad"
        bad.mkdir()
        (bad / "301.md").write_text(body("abc1234", "F-099", "maybe", "P0", "correct", "external-maintainer"), encoding="utf-8")
        d3 = tmp / "d3.jsonl"
        assert run_tool("convert", "--issues", str(bad), "--out", str(d3)).returncode == 0
        assert json.loads(d3.read_text().splitlines()[0])["valid"] is False
        assert run_tool("validate", "--decisions", str(d3)).returncode == 1
        print("invalid finding_validity BLOCKED")

    print("audit review->jsonl smoke OK (normalize/aggregate only; no readiness change)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
