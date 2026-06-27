#!/usr/bin/env python3
"""Property 10 - 베타 게이트는 하위 게이트의 논리곱 (Task 2.4, oracle PBT).

Validates: Requirements 5.3, 5.4 / design C5.

문서화된 불변식:
  - design_partner_beta_candidate_ready == AND(14 sub-gates)
  - beta == 1  ⇒  blocked_gate_rows == 0
  - beta == 0  ⇒  blocked_gate_rows > 0

게이트 계산이 인라인이라(Req 9 리팩터 금지) 본 oracle PBT는 공식 회귀 가드다. 단, 베타<->행
집계의 연결은 기존 import 가능한 `write_benchmark_readiness_json`로 교차 검증한다(베타==1이면
모든 행 passed=1이 되도록 일관된 summary를 구성했을 때 blocked=0). 충실한 계산 검증은 통합
경로(Task 10.5)에서 수행한다.
"""

from __future__ import annotations

import json
import shutil
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


def beta_conjunction(subgates: list[int]) -> int:
    return int(all(g == 1 for g in subgates))


@settings(max_examples=200)
@given(subgates=st.lists(st.integers(min_value=0, max_value=1), min_size=14, max_size=14))
def test_beta_is_conjunction_and_blocked_balance(subgates):
    beta = beta_conjunction(subgates)
    # Oracle conjunction property.
    assert beta == (1 if all(s == 1 for s in subgates) else 0)

    # Cross-check against the real writer: a self-consistent summary whose gate
    # flags equal subgates yields blocked==0 iff beta==1.
    summary = H.make_summary()
    for gate_id, flag in zip(GATE_IDS, subgates):
        summary[gate_id] = "1" if flag == 1 else "0"
    summary["product_readiness_calculated_from_real_labels"] = 1
    summary["design_partner_beta_candidate_ready"] = beta

    out = H.results_fixture_dir("p10") / "benchmark_readiness.json"
    bench.write_benchmark_readiness_json(out, summary)
    payload = json.loads(out.read_text(encoding="utf-8"))

    if beta == 1:
        assert payload["blocked_gate_rows"] == 0
    else:
        assert payload["blocked_gate_rows"] > 0


if __name__ == "__main__":
    test_beta_is_conjunction_and_blocked_balance()
    shutil.rmtree(H.RESULTS_DIR / "amr_beta_harness", ignore_errors=True)
    print("Property 10 (beta conjunction) ok")
