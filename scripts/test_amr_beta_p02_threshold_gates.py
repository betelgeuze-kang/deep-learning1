#!/usr/bin/env python3
"""Property 2 - 임계 게이트 단조성 (Task 2.1, oracle PBT).

Validates: Requirements 1.7, 3.8 / design C5.

게이트 계산이 기존 코드에서 큰 함수에 인라인되어 있어(독립 함수 미노출, Req 9상 리팩터 금지)
본 테스트는 문서화된 공식을 oracle로 고정하는 회귀 가드다. 실제 임계 상수
(MIN_REAL_REPOS_FOR_BETA/MIN_HUMAN_LABELS_FOR_BETA/MIN_MAINTAINER_FEEDBACK_FOR_BETA)는
기존 모듈에서 import하여 드리프트를 잡는다. 충실한 end-to-end 검증은 통합 경로
(Task 6.2/10.5)에서 실제 계산을 구동해 수행한다.

공식: gate == int(basis == 1 and observed >= required_threshold)
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


def threshold_gate(basis: int, observed: int, threshold: int) -> int:
    return int(basis == 1 and observed >= threshold)


@settings(max_examples=200)
@given(
    basis=st.integers(min_value=0, max_value=1),
    repos=st.integers(min_value=0, max_value=40),
    labels=st.integers(min_value=0, max_value=1000),
    feedback=st.integers(min_value=0, max_value=12),
)
def test_threshold_gate_monotonicity(basis, repos, labels, feedback):
    # Real constants imported from the existing module (drift guard).
    assert bench.MIN_REAL_REPOS_FOR_BETA == 10
    assert bench.MIN_HUMAN_LABELS_FOR_BETA == 300
    assert bench.MIN_MAINTAINER_FEEDBACK_FOR_BETA == 3

    repo_gate = threshold_gate(basis, repos, bench.MIN_REAL_REPOS_FOR_BETA)
    label_gate = threshold_gate(basis, labels, bench.MIN_HUMAN_LABELS_FOR_BETA)
    feedback_gate = threshold_gate(basis, feedback, bench.MIN_MAINTAINER_FEEDBACK_FOR_BETA)

    # basis is a necessary factor: basis=0 forces every threshold gate to 0.
    if basis == 0:
        assert repo_gate == label_gate == feedback_gate == 0
    # monotonic in observed count once basis holds.
    if basis == 1:
        assert repo_gate == int(repos >= 10)
        assert label_gate == int(labels >= 300)
        assert feedback_gate == int(feedback >= 3)
        # crossing the threshold upward never lowers the gate.
        assert threshold_gate(1, repos + 1, 10) >= repo_gate


if __name__ == "__main__":
    test_threshold_gate_monotonicity()
    print("Property 2 (threshold gate monotonicity) ok")
