#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_design_partner_packet.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_design_partner_packet.py"
BACKLOG_TOOL = ROOT / "scripts" / "amr_beta_readiness_backlog.py"


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


def run_backlog(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(BACKLOG_TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def readiness_payload(*, ready: bool) -> dict:
    rows = [
        {
            "gate_id": "real_repo_requirement_met",
            "passed": 1 if ready else 0,
            "observed": "10" if ready else "2",
            "required": "10",
            "blocked_reason": "" if ready else "At least 10 real local repositories",
        }
    ]
    blocked = sum(1 for row in rows if row["passed"] == 0)
    return {
        "schema_version": "local_repo_audit_benchmark_readiness.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "product_readiness_calculated_from_real_labels": 1,
        "design_partner_beta_candidate_ready": 1 if ready else 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "gate_rows": len(rows),
        "passed_gate_rows": len(rows) - blocked,
        "blocked_gate_rows": blocked,
        "rows": rows,
    }


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        blocked_readiness = tmp / "blocked_readiness.json"
        blocked_backlog = tmp / "blocked_backlog.json"
        blocked_packet = tmp / "blocked_packet.json"
        blocked_md = tmp / "blocked_packet.md"
        write_json(blocked_readiness, readiness_payload(ready=False))
        proc = run_backlog("--readiness", str(blocked_readiness), "--out-json", str(blocked_backlog))
        assert proc.returncode == 0, proc.stderr
        proc = run_tool(
            "--readiness",
            str(blocked_readiness),
            "--backlog",
            str(blocked_backlog),
            "--out-json",
            str(blocked_packet),
            "--out-md",
            str(blocked_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(blocked_packet.read_text(encoding="utf-8"))
        assert payload["packet_kind"] == "blocked_beta_candidate"
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert payload["backlog_items"] == 1
        assert "Known Limitations" in blocked_md.read_text(encoding="utf-8")

        ready_readiness = tmp / "ready_readiness.json"
        ready_packet = tmp / "ready_packet.json"
        write_json(ready_readiness, readiness_payload(ready=True))
        proc = run_tool("--readiness", str(ready_readiness), "--out-json", str(ready_packet), "--json")
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(ready_packet.read_text(encoding="utf-8"))
        assert payload["packet_kind"] == "design_partner_beta_candidate"
        assert payload["design_partner_beta_candidate_ready"] == 1
        assert payload["release_ready"] == 0
        assert payload["public_comparison_claim_ready"] == 0
        assert payload["real_model_execution_ready"] == 0
        assert payload["backlog_items"] == 0

        bad_readiness = tmp / "bad_readiness.json"
        bad_packet = tmp / "bad_packet.json"
        bad_payload = readiness_payload(ready=False)
        bad_payload["release_ready"] = 1
        write_json(bad_readiness, bad_payload)
        proc = run_tool("--readiness", str(bad_readiness), "--out-json", str(bad_packet))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta design partner packet smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
