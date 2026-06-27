#!/usr/bin/env python3
"""Task 6.1 - 첫 보고서 스모크 통합 드라이버.

Requirements 2.1, 2.2, 2.4 / design C2.

기존 `scripts/audit_my_repo_first_report_smoke.py`를 변경 없이 subprocess로 실행하여
실제 첫 보고서 경로를 검증한다:

  - 스키마 형태의 `first_report_smoke.json` 영수증 생성
  - `within_time_budget == 1` (600초 예산 내), `fixture_only == 1`
  - `design_partner_beta_candidate_ready == 0`, 차단 readiness 플래그 0 (비승격)
  - `external_network_used == 0` (로컬 전용)
  - 영수증에 대한 `--verify-existing` 재검증 통과(드리프트 없음)

실제 600초 초과/실패-정리 경로는 비현실적 장시간 실행이라 여기서 직접 트리거하지 않고,
시간 예산 경계 불변식은 Property 3 (Task 4.1)에서 별도 검증한다. 모든 산출물은 픽스처
전용·비승격이며 `results/`(gitignore) 하위에 둔다.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
SMOKE = SCRIPTS_DIR / "audit_my_repo_first_report_smoke.py"
OUT_DIR = REPO_ROOT / "results" / "amr_beta_first_report_smoke"

BLOCKED_FLAGS = ("release_ready", "public_comparison_claim_ready", "real_model_execution_ready")


def _run(args):
    return subprocess.run(
        [sys.executable, str(SMOKE), *args],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )


def test_first_report_smoke_receipt_invariants():
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    try:
        proc = _run(["--out", str(OUT_DIR)])
        assert proc.returncode == 0, f"smoke failed rc={proc.returncode}\n{proc.stderr}"
        receipt_path = OUT_DIR / "first_report_smoke.json"
        assert receipt_path.is_file(), "missing first_report_smoke.json"
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))

        assert receipt["within_time_budget"] == 1, receipt
        assert receipt["max_wall_ms"] == 600_000, receipt
        assert int(receipt["total_wall_ms"]) <= int(receipt["max_wall_ms"])
        assert receipt["fixture_only"] == 1
        assert receipt["first_report_success"] == 1
        assert receipt["external_network_used"] == 0
        assert receipt["design_partner_beta_candidate_ready"] == 0
        for key in BLOCKED_FLAGS:
            assert receipt.get(key, 0) == 0, f"{key} must be 0"

        # The receipt re-verifies cleanly (no drift).
        verify = _run(["--verify-existing", str(OUT_DIR)])
        assert verify.returncode == 0, f"verify-existing failed\n{verify.stderr}"
    finally:
        shutil.rmtree(OUT_DIR, ignore_errors=True)


if __name__ == "__main__":
    test_first_report_smoke_receipt_invariants()
    print("Task 6.1 (first-report smoke driver) ok")
