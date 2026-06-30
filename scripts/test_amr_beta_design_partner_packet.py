#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_design_partner_packet.py."""
from __future__ import annotations

import hashlib
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


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


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


def operator_status_payload(
    *,
    readiness: Path,
    ready: bool,
    backlog: Path | None = None,
) -> dict:
    artifacts = {
        "runtime_preflight": {
            "path": "/tmp/amr-runtime-preflight.json",
            "sha256": "sha256:" + ("1" * 64),
            "schema": "amr_beta_runtime_preflight.v1",
        },
        "runtime_approval_request": {
            "path": "/tmp/amr-runtime-approval-request.json",
            "sha256": "sha256:" + ("2" * 64),
            "schema": "amr_beta_runtime_approval_request.v1",
        },
        "runtime_approval_status": {
            "path": "/tmp/amr-runtime-approval-status.json",
            "sha256": "sha256:" + ("3" * 64),
            "schema": "amr_beta_runtime_approval_status.v1",
        },
        "benchmark_readiness": {
            "path": str(readiness.resolve()),
            "sha256": sha256_file(readiness),
            "schema": "local_repo_audit_benchmark_readiness.v1",
        },
    }
    if backlog:
        artifacts["readiness_backlog"] = {
            "path": str(backlog.resolve()),
            "sha256": sha256_file(backlog),
            "schema": "amr_beta_readiness_backlog.v1",
        }
    return {
        "schema": "amr_beta_operator_status.v1",
        "current_stage": (
            "stage_5_beta_candidate_or_hardening"
            if ready
            else "stage_4_real_benchmark_verified"
        ),
        "artifacts": artifacts,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "design_partner_beta_candidate_ready": 1 if ready else 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "errors": [],
    }


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        blocked_readiness = tmp / "blocked_readiness.json"
        blocked_backlog = tmp / "blocked_backlog.json"
        blocked_status = tmp / "blocked_operator_status.json"
        blocked_packet = tmp / "blocked_packet.json"
        blocked_md = tmp / "blocked_packet.md"
        write_json(blocked_readiness, readiness_payload(ready=False))
        proc = run_backlog("--readiness", str(blocked_readiness), "--out-json", str(blocked_backlog))
        assert proc.returncode == 0, proc.stderr
        write_json(
            blocked_status,
            operator_status_payload(readiness=blocked_readiness, backlog=blocked_backlog, ready=False),
        )
        proc = run_tool(
            "--readiness",
            str(blocked_readiness),
            "--backlog",
            str(blocked_backlog),
            "--operator-status",
            str(blocked_status),
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
        ready_status = tmp / "ready_operator_status.json"
        ready_packet = tmp / "ready_packet.json"
        write_json(ready_readiness, readiness_payload(ready=True))
        write_json(ready_status, operator_status_payload(readiness=ready_readiness, ready=True))
        proc = run_tool(
            "--readiness",
            str(ready_readiness),
            "--operator-status",
            str(ready_status),
            "--out-json",
            str(ready_packet),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(ready_packet.read_text(encoding="utf-8"))
        assert payload["packet_kind"] == "design_partner_beta_candidate"
        assert payload["design_partner_beta_candidate_ready"] == 1
        assert payload["input_operator_status"] == str(ready_status.resolve())
        assert payload["input_operator_status_sha256"] == sha256_file(ready_status)
        assert payload["release_ready"] == 0
        assert payload["public_comparison_claim_ready"] == 0
        assert payload["real_model_execution_ready"] == 0
        assert payload["backlog_items"] == 0

        missing_backlog_packet = tmp / "missing_backlog_packet.json"
        proc = run_tool(
            "--readiness",
            str(blocked_readiness),
            "--operator-status",
            str(blocked_status),
            "--out-json",
            str(missing_backlog_packet),
        )
        assert proc.returncode == 1
        assert "requires a readiness backlog artifact" in proc.stderr

        stale_status = tmp / "stale_operator_status.json"
        stale_payload = operator_status_payload(readiness=blocked_readiness, backlog=blocked_backlog, ready=False)
        stale_payload["artifacts"]["benchmark_readiness"]["sha256"] = "sha256:" + ("0" * 64)
        write_json(stale_status, stale_payload)
        proc = run_tool(
            "--readiness",
            str(blocked_readiness),
            "--backlog",
            str(blocked_backlog),
            "--operator-status",
            str(stale_status),
            "--out-json",
            str(tmp / "stale_status_packet.json"),
        )
        assert proc.returncode == 1
        assert "benchmark_readiness sha256 must match" in proc.stderr

        stale_backlog = tmp / "stale_backlog.json"
        stale_backlog_payload = json.loads(blocked_backlog.read_text(encoding="utf-8"))
        stale_backlog_payload["backlog"][0]["gate_id"] = "wrong_gate"
        write_json(stale_backlog, stale_backlog_payload)
        write_json(
            tmp / "stale_backlog_status.json",
            operator_status_payload(
                readiness=blocked_readiness,
                backlog=stale_backlog,
                ready=False,
            ),
        )
        proc = run_tool(
            "--readiness",
            str(blocked_readiness),
            "--backlog",
            str(stale_backlog),
            "--operator-status",
            str(tmp / "stale_backlog_status.json"),
            "--out-json",
            str(tmp / "stale_backlog_packet.json"),
        )
        assert proc.returncode == 1
        assert "backlog JSON does not match" in proc.stderr

        bad_readiness = tmp / "bad_readiness.json"
        bad_packet = tmp / "bad_packet.json"
        bad_payload = readiness_payload(ready=False)
        bad_payload["release_ready"] = 1
        write_json(bad_readiness, bad_payload)
        proc = run_tool(
            "--readiness",
            str(bad_readiness),
            "--operator-status",
            str(blocked_status),
            "--out-json",
            str(bad_packet),
        )
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta design partner packet smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
