#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_runtime_approval_status.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_runtime_approval_status.py"


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[str]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def preflight_payload(commands: list[str]) -> dict:
    return {
        "schema": "amr_beta_runtime_preflight.v1",
        "ready_to_request_runtime_approval": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "valid_repo_rows": 10,
        "human_label_rows": 300,
        "distinct_countable_maintainer_id_count": 3,
        "label_intake_case_count": 10,
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "next_commands": commands,
        "errors": [],
    }


def request_payload(preflight: Path, commands: list[str], benchmark_out: Path) -> dict:
    return {
        "schema": "amr_beta_runtime_approval_request.v1",
        "input_preflight": str(preflight.resolve()),
        "input_preflight_sha256": sha256_file(preflight),
        "request_kind": "runtime_approval_required",
        "approved_by_human": 0,
        "approval_record_supplied": 0,
        "requires_human_runtime_approval": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "runtime_commands": commands,
        "runtime_commands_sha256": sha256_json(commands),
        "benchmark_out": str(benchmark_out.resolve()),
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }


def record_payload(preflight: Path, request: Path, commands: list[str], benchmark_out: Path) -> dict:
    return {
        "schema": "amr_beta_runtime_approval_record.v1",
        "approval_scope": "amr_beta_real_benchmark_runtime",
        "approved_by_human": True,
        "approval_record_supplied": True,
        "approver_id": "human-owner-1",
        "approved_at_utc": "2026-06-30T00:00:00Z",
        "approved_runtime_budget_minutes": 90,
        "approved_preflight_sha256": sha256_file(preflight),
        "approved_request_sha256": sha256_file(request),
        "approved_runtime_commands_sha256": sha256_json(commands),
        "approved_benchmark_out": str(benchmark_out.resolve()),
        "raw_repositories_labels_feedback_remain_local": True,
        "no_external_publication_or_release_claim": True,
        "creates_benchmark_evidence": False,
        "runs_benchmark": False,
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }


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
        labels = tmp / "combined labels.jsonl"
        feedback = tmp / "feedback rows.jsonl"
        summary = tmp / "combined summary.json"
        benchmark_out = tmp / "audit benchmark"
        commands = [
            command_line(
                [
                    "python3",
                    "scripts/amr_beta_benchmark_input_prepare.py",
                    "--label-intake-dir",
                    tmp / "repo one intake",
                    "--out-labels",
                    labels,
                    "--summary",
                    summary,
                    "--feedback",
                    feedback,
                ]
            ),
            command_line(
                [
                    "python3",
                    "scripts/audit_my_repo_benchmark.py",
                    "--labels",
                    labels,
                    "--feedback",
                    feedback,
                    "--namespace",
                    "real_benchmark",
                    "--confirm-real-benchmark-namespace",
                    "--mode",
                    "full",
                    "--out",
                    benchmark_out,
                ]
            ),
        ]
        preflight = tmp / "preflight.json"
        write_json(preflight, preflight_payload(commands))
        request = tmp / "approval_request.json"
        write_json(request, request_payload(preflight, commands, benchmark_out))
        record = tmp / "approval_record.json"
        write_json(record, record_payload(preflight, request, commands, benchmark_out))
        out_json = tmp / "approval_status.json"
        out_md = tmp / "approval_status.md"

        proc = run_tool(
            "--preflight",
            str(preflight),
            "--request",
            str(request),
            "--approval-record",
            str(record),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["approved_by_human"] == 1
        assert payload["approval_record_supplied"] == 1
        assert payload["human_runtime_approval_record_verified"] == 1
        assert payload["ready_for_human_operator_benchmark_run"] == 1
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["runs_benchmark"] == 0
        assert payload["codex_runtime_permission_granted_by_this_packet"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert payload["benchmark_out"] == str(benchmark_out)
        assert payload["runtime_commands_sha256"] == sha256_json(commands)
        markdown = out_md.read_text(encoding="utf-8")
        assert "human_runtime_approval_record_verified: 1" in markdown
        assert "runs_benchmark: 0" in markdown

        approved_request = tmp / "approved_request.json"
        bad_request = request_payload(preflight, commands, benchmark_out)
        bad_request["approved_by_human"] = 1
        write_json(approved_request, bad_request)
        proc = run_tool(
            "--preflight",
            str(preflight),
            "--request",
            str(approved_request),
            "--approval-record",
            str(record),
            "--out-json",
            str(tmp / "bad_status.json"),
        )
        assert proc.returncode == 1
        assert "must not already approve" in proc.stderr

        stale_record = tmp / "stale_record.json"
        bad_record = record_payload(preflight, request, commands, benchmark_out)
        bad_record["approved_request_sha256"] = "sha256:" + ("0" * 64)
        write_json(stale_record, bad_record)
        proc = run_tool(
            "--preflight",
            str(preflight),
            "--request",
            str(request),
            "--approval-record",
            str(stale_record),
            "--out-json",
            str(tmp / "stale_status.json"),
        )
        assert proc.returncode == 1
        assert "approved_request_sha256" in proc.stderr

        agent_record = tmp / "agent_record.json"
        bad_record = record_payload(preflight, request, commands, benchmark_out)
        bad_record["approver_id"] = "codex"
        write_json(agent_record, bad_record)
        proc = run_tool(
            "--preflight",
            str(preflight),
            "--request",
            str(request),
            "--approval-record",
            str(agent_record),
            "--out-json",
            str(tmp / "agent_status.json"),
        )
        assert proc.returncode == 1
        assert "non-placeholder human approver_id" in proc.stderr

    print("AMR beta runtime approval status smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
