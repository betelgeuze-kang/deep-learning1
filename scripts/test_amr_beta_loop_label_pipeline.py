#!/usr/bin/env python3
"""Task 6.2 - template -> intake -> benchmark 합성 파이프라인 통합 드라이버.

Requirements 3.1, 3.2, 3.3, 3.5, 6.1, 6.2, 6.3 / design C3, C4, C5.

Req 9(기존 재사용, 신규 계약 금지)에 따라 본 드라이버는 합성 파이프라인을 새로 중복
구현하지 않는다. 대신 이미 audit -> label_template -> label_intake -> benchmark
전체 경로(--label-intake, --namespace synthetic, --mode quick)와 스키마 검증,
synthetic 비승격(product readiness 0, design_partner_beta_candidate_ready 0,
release/public/real-model 0), 인테이크/매니페스트 sha 결합, overwrite 가드를
end-to-end로 단언하는 기존 통합 테스트
`experiments/test_audit_my_repo_product_entrypoint.sh`를 구동하고 통과를 단언한다.

느린 통합 실행이므로 PR-safe `scripts/test_*.py` 자동 smoke에서는 기본 skip한다.
명시적으로 `AMR_BETA_RUN_SLOW=1`을 설정하면 실행된다. `AMR_BETA_SKIP_SLOW=1`은
항상 skip을 강제한다. 모든 산출물은 스크립트 자체 임시 디렉터리에 생성되며 비승격이다.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
ENTRYPOINT_TEST = REPO_ROOT / "experiments" / "test_audit_my_repo_product_entrypoint.sh"
SUCCESS_MARKER = "audit_my_repo product entrypoint smoke passed"


def test_synthetic_label_pipeline_integration():
    if os.environ.get("AMR_BETA_SKIP_SLOW") == "1" or os.environ.get("AMR_BETA_RUN_SLOW") != "1":
        print("Task 6.2 skipped (set AMR_BETA_RUN_SLOW=1 to run slow integration)")
        return
    assert ENTRYPOINT_TEST.is_file(), f"missing existing integration test: {ENTRYPOINT_TEST}"
    proc = subprocess.run(
        ["bash", str(ENTRYPOINT_TEST)],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=1800,
    )
    assert proc.returncode == 0, (
        f"product entrypoint pipeline test failed rc={proc.returncode}\n"
        f"--- stdout tail ---\n{proc.stdout[-2000:]}\n--- stderr tail ---\n{proc.stderr[-2000:]}"
    )
    assert SUCCESS_MARKER in proc.stdout, "missing success marker; pipeline coverage not confirmed"


if __name__ == "__main__":
    test_synthetic_label_pipeline_integration()
    print("Task 6.2 (synthetic label pipeline integration) ok")
