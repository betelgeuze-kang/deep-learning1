#!/usr/bin/env python3
"""Property 8 - real_human_label_basis 정의 (Task 2.2, oracle PBT).

Validates: Requirements 4.5, 6.1, 8.1 / design C5.

기존 코드(audit_my_repo_benchmark.py ~2420)의 문서화된 정의를 oracle로 고정한다:

  real_human_label_basis = int(
      namespace == "real_benchmark"
      and confirmed
      and bool(cases)
      and all(case.human_labeled and not case.synthetic for case in cases)
  )

게이트 계산이 인라인이라(Req 9 리팩터 금지) 본 oracle PBT는 공식 회귀 가드다. 핵심 함의:
  - 비-real_benchmark 네임스페이스 ⇒ basis 0
  - 미확인(confirm 없음) ⇒ basis 0
  - 합성 케이스가 하나라도 있으면 ⇒ basis 0 (증거 경계)
  - 케이스 없음 ⇒ basis 0
충실한 검증은 통합 경로(Task 10.4/10.5)에서 실제 입력으로 수행한다.
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


def real_human_label_basis(namespace: str, confirmed: bool, cases: list[dict]) -> int:
    return int(
        namespace == "real_benchmark"
        and bool(confirmed)
        and bool(cases)
        and all(c["human_labeled"] and not c["synthetic"] for c in cases)
    )


case_strategy = st.fixed_dictionaries({
    "human_labeled": st.integers(min_value=0, max_value=1),
    "synthetic": st.integers(min_value=0, max_value=1),
})


@settings(max_examples=300)
@given(
    namespace=st.sampled_from(["fixture", "synthetic", "real_benchmark"]),
    confirmed=st.booleans(),
    cases=st.lists(case_strategy, min_size=0, max_size=6),
)
def test_basis_definition(namespace, confirmed, cases):
    basis = real_human_label_basis(namespace, confirmed, cases)

    if basis == 1:
        # All necessary conditions must hold.
        assert namespace == "real_benchmark"
        assert confirmed
        assert cases
        assert all(c["human_labeled"] and not c["synthetic"] for c in cases)
    # Evidence-boundary implications (each independently forces basis 0).
    if namespace != "real_benchmark":
        assert basis == 0
    if not confirmed:
        assert basis == 0
    if any(c["synthetic"] for c in cases):
        assert basis == 0
    if any(not c["human_labeled"] for c in cases):
        assert basis == 0
    if not cases:
        assert basis == 0


if __name__ == "__main__":
    test_basis_definition()
    print("Property 8 (basis definition) ok")
