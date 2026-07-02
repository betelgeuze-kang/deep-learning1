#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_readiness_backlog.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import amr_beta_readiness_backlog as readiness_backlog

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_readiness_backlog.py"


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def readiness_payload(*, blocked: bool = True) -> dict:
    rows = [
        {
            "gate_id": "real_repo_requirement_met",
            "passed": 0 if blocked else 1,
            "observed": "2",
            "required": "10",
            "blocked_reason": "At least 10 real local repositories" if blocked else "",
        },
        {
            "gate_id": "overall_precision_requirement_met",
            "passed": 0 if blocked else 1,
            "observed": "0.700000",
            "required": "0.800000",
            "blocked_reason": "Overall precision >= threshold" if blocked else "",
        },
    ]
    blocked_rows = sum(1 for row in rows if int(row["passed"]) == 0)
    return {
        "schema_version": "local_repo_audit_benchmark_readiness.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "product_readiness_calculated_from_real_labels": 1,
        "design_partner_beta_candidate_ready": 0 if blocked else 1,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "gate_rows": len(rows),
        "passed_gate_rows": len(rows) - blocked_rows,
        "blocked_gate_rows": blocked_rows,
        "rows": rows,
    }


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert readiness_backlog.is_forbidden_env_path(Path(".env.secrets") / "readiness.json")
        assert readiness_backlog.is_forbidden_env_path(tmp / ".env.secrets" / "backlog.json")
        assert not readiness_backlog.is_forbidden_env_path(tmp / "backlog.json")
        readiness = tmp / "benchmark_readiness.json"
        out_json = tmp / "backlog.json"
        out_md = tmp / "backlog.md"
        write_json(readiness, readiness_payload(blocked=True))
        proc = run_tool(
            "--readiness",
            str(readiness),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["backlog_items"] == 2
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert payload["backlog"][0]["counts_as_release_ready"] == 0
        assert "Provide at least 10 real local repositories" in out_md.read_text(encoding="utf-8")

        ready = tmp / "ready.json"
        ready_out = tmp / "ready_backlog.json"
        write_json(ready, readiness_payload(blocked=False))
        proc = run_tool("--readiness", str(ready), "--out-json", str(ready_out), "--json")
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(ready_out.read_text(encoding="utf-8"))
        assert payload["backlog_items"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 1
        assert payload["release_ready"] == 0

        bad = tmp / "bad.json"
        bad_out = tmp / "bad_backlog.json"
        bad_payload = readiness_payload(blocked=True)
        bad_payload["release_ready"] = 1
        write_json(bad, bad_payload)
        proc = run_tool("--readiness", str(bad), "--out-json", str(bad_out))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta readiness backlog smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
