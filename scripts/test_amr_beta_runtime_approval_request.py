#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_runtime_approval_request.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_runtime_approval_request.py"


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def preflight_payload(*, ready: int = 1, release_ready: int = 0) -> dict:
    return {
        "schema": "amr_beta_runtime_preflight.v1",
        "ready_to_request_runtime_approval": ready,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "valid_repo_rows": 10,
        "human_label_rows": 300,
        "distinct_countable_maintainer_id_count": 3,
        "label_intake_case_count": 10,
        "design_partner_beta_candidate_ready": 0,
        "release_ready": release_ready,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "next_commands": [
            "python3 scripts/amr_beta_benchmark_input_prepare.py --label-intake-dir /tmp/intake --out-labels /tmp/labels.jsonl --summary /tmp/summary.json --feedback /tmp/feedback.jsonl",
            "python3 scripts/audit_my_repo_benchmark.py --labels /tmp/labels.jsonl --feedback /tmp/feedback.jsonl --namespace real_benchmark --confirm-real-benchmark-namespace --mode full --out /tmp/audit_benchmark",
        ],
        "errors": [],
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
        preflight = tmp / "preflight.json"
        write_json(preflight, preflight_payload())
        out_json = tmp / "approval_request.json"
        out_md = tmp / "approval_request.md"
        proc = run_tool(
            "--preflight",
            str(preflight),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--operator-note",
            "Runtime budget to be approved by a human operator.",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["approved_by_human"] == 0
        assert payload["approval_record_supplied"] == 0
        assert payload["requires_human_runtime_approval"] == 1
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["runs_benchmark"] == 0
        assert payload["input_preflight_sha256"] == sha256_file(preflight)
        assert payload["runtime_commands_sha256"] == sha256_json(payload["runtime_commands"])
        assert payload["benchmark_out"] == "/tmp/audit_benchmark"
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert "audit_my_repo_benchmark.py" in payload["runtime_commands"][1]
        markdown = out_md.read_text(encoding="utf-8")
        assert "approved_by_human: 0" in markdown
        assert "runtime_commands_sha256" in markdown
        assert "Runtime Commands" in markdown

        blocked_preflight = tmp / "blocked_preflight.json"
        write_json(blocked_preflight, preflight_payload(ready=0))
        proc = run_tool("--preflight", str(blocked_preflight), "--out-json", str(tmp / "blocked.json"))
        assert proc.returncode == 1
        assert "ready_to_request_runtime_approval=1" in proc.stderr

        promoted_preflight = tmp / "promoted_preflight.json"
        write_json(promoted_preflight, preflight_payload(release_ready=1))
        proc = run_tool("--preflight", str(promoted_preflight), "--out-json", str(tmp / "promoted.json"))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta runtime approval request smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
