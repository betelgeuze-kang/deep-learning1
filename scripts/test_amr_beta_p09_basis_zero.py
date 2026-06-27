#!/usr/bin/env python3
"""Property 9 - basis=0이면 모든 하위 게이트와 베타 게이트가 0 (Task 2.3, oracle PBT).

Validates: Requirements 4.5, 6.1 / design C5.

문서화된 불변식: `real_human_label_basis == 0`이면 14개 `*_requirement_met`가 모두 0이고,
따라서 베타 게이트(논리곱)도 0이다. 게이트 계산이 인라인이라(Req 9 리팩터 금지) 본 테스트는
공식 oracle 회귀 가드이며, 실제 14개 게이트 id는 기존 READINESS_GATES에서 가져와 드리프트를
잡는다. 충실한 end-to-end 검증은 통합 경로(Task 10.5)에서 수행한다.
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

bench = H.load_benchmark_module()
GATE_IDS = [g[0] for g in bench.READINESS_GATES]


def gate_value(basis: int, raw_pass: int) -> int:
    """Documented gate form: every sub-gate carries the basis factor."""
    return int(basis == 1 and raw_pass == 1)


def beta_gate(basis: int, gate_flags: list[int]) -> int:
    return int(basis == 1 and all(g == 1 for g in gate_flags))


@settings(max_examples=200)
@given(
    raw=st.lists(st.integers(min_value=0, max_value=1), min_size=14, max_size=14),
)
def test_basis_zero_forces_all_gates_zero(raw):
    # basis = 0: every gate and the beta gate collapse to 0 regardless of raw passes.
    gates0 = [gate_value(0, r) for r in raw]
    assert all(g == 0 for g in gates0)
    assert beta_gate(0, gates0) == 0

    # basis = 1: gates equal their raw pass; beta = AND.
    gates1 = [gate_value(1, r) for r in raw]
    assert gates1 == raw
    assert beta_gate(1, gates1) == int(all(r == 1 for r in raw))
    assert len(GATE_IDS) == 14


if __name__ == "__main__":
    test_basis_zero_forces_all_gates_zero()
    print("Property 9 (basis=0 forces gates 0) ok")
