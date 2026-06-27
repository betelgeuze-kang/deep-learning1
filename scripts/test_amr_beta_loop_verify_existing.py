#!/usr/bin/env python3
"""Task 6.4 - `--verify-existing` 드리프트 거부 통합 테스트.

Requirements 8.3, 8.4 / design C5, C7.

Req 9(기존 재사용, 신규 계약 금지)에 따라 변조-거부 음성 통제를 새로 중복 구현하지 않는다.
대신 기존 음성 통제 통합 테스트 `experiments/test_audit_my_repo_negative_controls.sh`를
구동하고 통과를 단언한다. 이 테스트는 감사/라벨/벤치마크 산출물의 변조·스키마 위반·
재검증 실패 시 `--verify-existing`이 종료 코드 1로 거부함을 end-to-end로 단언한다(게이트
무결성: 인간 라벨 외 수동 편집은 검증을 통과할 수 없음).

느린 통합 실행이므로 PR-safe `scripts/test_*.py` 자동 smoke에서는 기본 skip한다.
명시적으로 `AMR_BETA_RUN_SLOW=1`을 설정하면 실행된다. `AMR_BETA_SKIP_SLOW=1`은
항상 skip을 강제한다.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
NEGATIVE_CONTROLS_TEST = REPO_ROOT / "experiments" / "test_audit_my_repo_negative_controls.sh"
SUCCESS_MARKER = "audit_my_repo negative controls passed"


def test_verify_existing_rejects_drift():
    if os.environ.get("AMR_BETA_SKIP_SLOW") == "1" or os.environ.get("AMR_BETA_RUN_SLOW") != "1":
        print("Task 6.4 skipped (set AMR_BETA_RUN_SLOW=1 to run slow integration)")
        return
    assert NEGATIVE_CONTROLS_TEST.is_file(), f"missing existing test: {NEGATIVE_CONTROLS_TEST}"
    proc = subprocess.run(
        ["bash", str(NEGATIVE_CONTROLS_TEST)],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=1800,
    )
    assert proc.returncode == 0, (
        f"negative controls (verify-existing drift rejection) failed rc={proc.returncode}\n"
        f"--- stdout tail ---\n{proc.stdout[-2000:]}\n--- stderr tail ---\n{proc.stderr[-2000:]}"
    )
    assert SUCCESS_MARKER in proc.stdout, "missing success marker; drift-rejection coverage not confirmed"


if __name__ == "__main__":
    test_verify_existing_rejects_drift()
    print("Task 6.4 (verify-existing drift rejection) ok")
