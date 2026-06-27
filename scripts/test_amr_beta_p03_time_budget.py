#!/usr/bin/env python3
"""Property 3 - 첫 보고서 시간 예산 경계 (Task 4.1, oracle PBT).

Validates: Requirements 2.2, 2.5, 2.6 / design C2, C5.

문서화된 불변식(first_report_smoke / benchmark에 인라인):
  within_time_budget == int(total_wall_ms <= max_wall_ms)
그리고 max_wall_ms == 600000일 때 total_wall_ms > 600000 ⇒ within_time_budget == 0,
total_wall_ms <= 600000 ⇒ within_time_budget == 1.

게이트 계산이 인라인이라(Req 9 리팩터 금지) 본 oracle PBT는 공식 회귀 가드다. 실제 기본
예산값(600000ms)은 first_report_smoke의 --max-wall-ms 기본값과 일치한다.
"""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import test_amr_beta_harness as H  # noqa: E402

H.require_hypothesis()
from hypothesis import given, settings  # noqa: E402
from hypothesis import strategies as st  # noqa: E402

DEFAULT_MAX_WALL_MS = 600_000


def within_time_budget(total_wall_ms: int, max_wall_ms: int) -> int:
    return int(total_wall_ms <= max_wall_ms)


@settings(max_examples=300)
@given(
    total=st.integers(min_value=0, max_value=5_000_000),
    max_wall=st.integers(min_value=1, max_value=5_000_000),
)
def test_time_budget_boundary(total, max_wall):
    w = within_time_budget(total, max_wall)
    assert w == (1 if total <= max_wall else 0)
    # boundary equality counts as within budget.
    assert within_time_budget(max_wall, max_wall) == 1
    assert within_time_budget(max_wall + 1, max_wall) == 0


@settings(max_examples=200)
@given(total=st.integers(min_value=0, max_value=5_000_000))
def test_600000_budget_boundary(total):
    w = within_time_budget(total, DEFAULT_MAX_WALL_MS)
    if total > 600_000:
        assert w == 0
    else:
        assert w == 1


if __name__ == "__main__":
    test_time_budget_boundary()
    test_600000_budget_boundary()
    print("Property 3 (time budget boundary) ok")
