#!/usr/bin/env python3
"""Property 11 - 베타 readiness 체크리스트 집계 보존 (Task 2.5).

Validates: Requirements 5.5, 5.1 / design C5.

기존 `audit_my_repo_benchmark.write_benchmark_readiness_json` /
`readiness_gate_rows`를 변경 없이 호출하여 다음 불변식을 단언한다(합성 입력만 사용,
비승격):

  - gate_rows == passed_gate_rows + blocked_gate_rows == len(rows) == 14
  - 각 행: passed in {0,1}; blocked_reason == "" iff passed == 1
  - passed_gate_rows == 통과 비트 합
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
@given(flags=st.lists(st.sampled_from(["0", "1"]), min_size=len(GATE_IDS), max_size=len(GATE_IDS)),
       basis=st.integers(min_value=0, max_value=1))
def test_checklist_aggregation_balance(flags, basis):
    summary = H.make_summary()
    for gate_id, flag in zip(GATE_IDS, flags):
        summary[gate_id] = flag
    summary["product_readiness_calculated_from_real_labels"] = basis
    summary["design_partner_beta_candidate_ready"] = int(all(f == "1" for f in flags) and basis == 1)

    out = H.results_fixture_dir("p11") / "benchmark_readiness.json"
    bench.write_benchmark_readiness_json(out, summary)
    payload = json.loads(out.read_text(encoding="utf-8"))

    rows = payload["rows"]
    assert payload["gate_rows"] == len(rows) == len(GATE_IDS) == 14
    assert payload["passed_gate_rows"] + payload["blocked_gate_rows"] == payload["gate_rows"]
    passed_count = sum(1 for r in rows if int(r["passed"]) == 1)
    assert payload["passed_gate_rows"] == passed_count
    for r in rows:
        assert int(r["passed"]) in (0, 1)
        if int(r["passed"]) == 1:
            assert r["blocked_reason"] == ""
        else:
            assert r["blocked_reason"] != ""


if __name__ == "__main__":
    test_checklist_aggregation_balance()
    # cleanup non-promoted fixture
    import shutil
    shutil.rmtree(H.RESULTS_DIR / "amr_beta_harness", ignore_errors=True)
    print("Property 11 (checklist aggregation) ok")
