#!/usr/bin/env python3
"""Task 7.1 - readiness 체크리스트 산출·집계·스키마 검증 드라이버.

Requirements 5.1, 5.2, 5.5, 6.4, 6.5 / design C5, C7.

기존 `audit_my_repo_benchmark.write_benchmark_readiness_json`(변경 없음)으로
`benchmark_readiness.json`을 산출하고, 기존 스키마
`schemas/local_repo_audit_benchmark_readiness.schema.json`로 검증한다(신규 스키마 없음,
Req 9). 통과/차단 두 경우 모두에 대해:

  - 스키마 검증 통과(`tools/validate_json_schemas.py --schema-instance`)
  - gate_rows == passed_gate_rows + blocked_gate_rows, 각 행의 blocked_reason 일관성
  - release_ready/public_comparison_claim_ready/real_model_execution_ready == 0 (const 0)

합성 summary만 사용하며 비승격이다.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import test_amr_beta_harness as H  # noqa: E402

REPO_ROOT = H.REPO_ROOT
SCHEMA = REPO_ROOT / "schemas" / "local_repo_audit_benchmark_readiness.schema.json"
VALIDATOR = REPO_ROOT / "tools" / "validate_json_schemas.py"
BLOCKED_FLAGS = ("release_ready", "public_comparison_claim_ready", "real_model_execution_ready")

bench = H.load_benchmark_module()


def _schema_validate(instance: Path):
    proc = subprocess.run(
        [sys.executable, str(VALIDATOR), "--schema-instance", str(SCHEMA), str(instance)],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, f"schema validation failed for {instance}\n{proc.stdout}\n{proc.stderr}"


def _check(summary: dict, label: str):
    out_dir = H.results_fixture_dir(f"readiness_{label}")
    path = out_dir / "benchmark_readiness.json"
    bench.write_benchmark_readiness_json(path, summary)
    _schema_validate(path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload["rows"]
    assert payload["gate_rows"] == len(rows) == 14
    assert payload["passed_gate_rows"] + payload["blocked_gate_rows"] == payload["gate_rows"]
    for r in rows:
        assert (r["blocked_reason"] == "") == (int(r["passed"]) == 1)
    for key in BLOCKED_FLAGS:
        assert payload[key] == 0


def test_readiness_checklist_schema_and_balance():
    try:
        # All gates passing, real-label basis.
        _check(H.make_summary(gates_pass=True, basis=1), "pass")
        # All gates blocked, no real-label basis (beta stays 0).
        _check(H.make_summary(gates_pass=False, basis=0), "blocked")
        # Mixed: one gate blocked -> beta 0, blocked reason recorded.
        mixed = H.make_summary(gates_pass=True, basis=1)
        mixed["first_report_requirement_met"] = "0"
        mixed["design_partner_beta_candidate_ready"] = 0
        _check(mixed, "mixed")
    finally:
        shutil.rmtree(H.RESULTS_DIR / "amr_beta_harness", ignore_errors=True)


if __name__ == "__main__":
    test_readiness_checklist_schema_and_balance()
    print("Task 7.1 (readiness checklist schema+balance) ok")
