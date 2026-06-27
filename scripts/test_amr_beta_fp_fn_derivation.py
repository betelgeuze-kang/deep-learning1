#!/usr/bin/env python3
"""Task 7.2 - FP/FN 이슈 목록 도출 헬퍼 + 검증.

Requirements 4.1, 4.2, 4.3, 9.3, 9.4 / design C5, C6.

`benchmark_confusion_rows.csv`(기존 벤치마크 산출물, CONFUSION_FIELDS)에서 거짓 양성/
거짓 음성 행만 추출하여 케이스 식별자·발견 식별자·인용 스팬(파일/라인/sha256)을 포함한
FP/FN 목록을 `results/`(gitignore) 하위에 도출한다. 이는 신규 커밋 엔트리포인트/계약이
아니라 results/ 하 ad-hoc 도출이며(Req 9), 기존 `design-partner-finding-review` 이슈
템플릿 필드(케이스/발견/인용 스팬)와 정합한다.

본 테스트는 합성 confusion CSV로 헬퍼를 구동하고 다음을 단언한다:
  - FP/FN 행만 도출되고 TP/TN은 제외(4.2)
  - 각 항목에 case_id·finding/label id·인용 스팬(file/line/sha256)·outcome 포함(4.3)
  - 출력이 results/ 하위(gitignore)이며 비승격(9.3/9.4)
"""

from __future__ import annotations

import csv
import shutil
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import test_amr_beta_harness as H  # noqa: E402

bench = H.load_benchmark_module()
CONFUSION_FIELDS = bench.CONFUSION_FIELDS

# Output columns aligned to the design-partner-finding-review issue template intent
# (case + finding + cited source span). Derived under results/, never committed.
FP_FN_FIELDS = [
    "case_id",
    "outcome",
    "finding_id",
    "label_id",
    "priority",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
]


def derive_fp_fn(confusion_csv: Path, out_dir: Path) -> Path:
    """Extract only FP/FN rows into results/<...>/fp_fn_issue_list.csv (non-promoted)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "fp_fn_issue_list.csv"
    with confusion_csv.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    derived = []
    for row in rows:
        if row.get("outcome") not in {"FP", "FN"}:
            continue
        derived.append(
            {
                "case_id": row.get("case_id", ""),
                "outcome": row.get("outcome", ""),
                "finding_id": row.get("matched_finding_id", ""),
                "label_id": row.get("label_id", ""),
                "priority": row.get("priority", ""),
                "file_path": row.get("file_path", ""),
                "expected_line_start": row.get("expected_line_start", ""),
                "expected_line_end": row.get("expected_line_end", ""),
                "expected_span_sha256": row.get("expected_span_sha256", ""),
            }
        )
    with out_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FP_FN_FIELDS)
        writer.writeheader()
        writer.writerows(derived)
    return out_path


def _synthetic_confusion(path: Path):
    rows = [
        {**{k: "" for k in CONFUSION_FIELDS}, "case_id": "c1", "label_id": "L1", "matched_finding_id": "F1",
         "file_path": "a.py", "expected_line_start": "1", "expected_line_end": "2",
         "expected_span_sha256": "a" * 64, "priority": "P1", "outcome": "TP", "tp": "1", "fp": "0", "fn": "0", "tn": "0"},
        {**{k: "" for k in CONFUSION_FIELDS}, "case_id": "c1", "label_id": "L2", "matched_finding_id": "F2",
         "file_path": "b.py", "expected_line_start": "5", "expected_line_end": "6",
         "expected_span_sha256": "b" * 64, "priority": "P0", "outcome": "FP", "tp": "0", "fp": "1", "fn": "0", "tn": "0"},
        {**{k: "" for k in CONFUSION_FIELDS}, "case_id": "c2", "label_id": "L3", "matched_finding_id": "",
         "file_path": "c.py", "expected_line_start": "9", "expected_line_end": "9",
         "expected_span_sha256": "c" * 64, "priority": "P1", "outcome": "FN", "tp": "0", "fp": "0", "fn": "1", "tn": "0"},
        {**{k: "" for k in CONFUSION_FIELDS}, "case_id": "c2", "label_id": "L4", "matched_finding_id": "",
         "file_path": "d.py", "expected_line_start": "3", "expected_line_end": "4",
         "expected_span_sha256": "d" * 64, "priority": "P2", "outcome": "TN", "tp": "0", "fp": "0", "fn": "0", "tn": "1"},
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CONFUSION_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def test_fp_fn_derivation():
    base = H.results_fixture_dir("fp_fn")
    try:
        confusion = base / "benchmark_confusion_rows.csv"
        _synthetic_confusion(confusion)
        out_path = derive_fp_fn(confusion, base / "derived")

        assert H.RESULTS_DIR in out_path.parents, "FP/FN list must live under results/ (gitignored)"
        with out_path.open(newline="", encoding="utf-8") as handle:
            derived = list(csv.DictReader(handle))

        # Only FP and FN survive (TP/TN excluded).
        assert len(derived) == 2
        assert {r["outcome"] for r in derived} == {"FP", "FN"}
        for r in derived:
            assert r["case_id"]
            assert r["finding_id"] or r["label_id"]  # finding id (matched) or label id
            assert r["file_path"]
            assert r["expected_line_start"] and r["expected_line_end"]
            assert len(r["expected_span_sha256"]) == 64
    finally:
        shutil.rmtree(H.RESULTS_DIR / "amr_beta_harness", ignore_errors=True)


if __name__ == "__main__":
    test_fp_fn_derivation()
    print("Task 7.2 (FP/FN derivation) ok")
