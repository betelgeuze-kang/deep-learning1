#!/usr/bin/env python3
"""Property 13 - 차단 readiness 플래그 0 불변식 (Task 2.6).

Validates: Requirements 6.4, 6.5 / design C5, C7.

기존 `audit_my_repo_benchmark.write_benchmark_readiness_json`를 변경 없이 호출하여,
임의의 summary(베타/basis/게이트 플래그 무관)에 대해 출력 payload의
`release_ready` / `public_comparison_claim_ready` / `real_model_execution_ready`가
항상 정수 0임을 단언한다(증거 경계, 단방향). 합성 입력만 사용하며 비승격이다.
"""

from __future__ import annotations

import json
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


@settings(max_examples=150)
@given(
    flags=st.lists(st.sampled_from(["0", "1"]), min_size=len(GATE_IDS), max_size=len(GATE_IDS)),
    basis=st.integers(min_value=0, max_value=1),
    beta=st.integers(min_value=0, max_value=1),
)
def test_blocked_flags_always_zero(flags, basis, beta):
    summary = H.make_summary()
    for gate_id, flag in zip(GATE_IDS, flags):
        summary[gate_id] = flag
    # Adversarially try to make the writer emit non-zero blocked flags.
    summary["product_readiness_calculated_from_real_labels"] = basis
    summary["design_partner_beta_candidate_ready"] = beta
    summary["release_ready"] = 1
    summary["public_comparison_claim_ready"] = 1
    summary["real_model_execution_ready"] = 1

    out = H.results_fixture_dir("p13") / "benchmark_readiness.json"
    bench.write_benchmark_readiness_json(out, summary)
    payload = json.loads(out.read_text(encoding="utf-8"))

    for key in H.BLOCKED_READINESS_FLAGS:
        assert payload[key] == 0, f"{key} must be 0, got {payload[key]}"
    # beta flag is faithfully carried from the summary (not fabricated by writer).
    assert payload["design_partner_beta_candidate_ready"] == beta
    assert payload["product_readiness_calculated_from_real_labels"] == basis


if __name__ == "__main__":
    test_blocked_flags_always_zero()
    import shutil
    shutil.rmtree(H.RESULTS_DIR / "amr_beta_harness", ignore_errors=True)
    print("Property 13 (blocked flags zero) ok")
