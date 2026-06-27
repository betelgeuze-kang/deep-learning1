#!/usr/bin/env python3
"""Task 6.3 - real_benchmark 네임스페이스 확인 가드 통합 테스트.

Requirements 7.1, 7.2, 7.3 / design C5.

기존 `scripts/audit_my_repo_benchmark.py`를 변경 없이 subprocess로 호출하여 실제
인라인 네임스페이스 가드를 검증한다:

  - `--namespace real_benchmark`를 `--confirm-real-benchmark-namespace` 없이 사용 →
    종료 코드 2, 표준오류에 확인 플래그 필요 메시지, 출력 디렉터리에 벤치마크 산출물 미기록.
  - `--confirm-real-benchmark-namespace`를 real_benchmark 외 네임스페이스와 사용 →
    종료 코드 2.

모든 입력은 합성/픽스처이며 비승격이다(real_benchmark 채널에 아무것도 기록되지 않음).
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
BENCH = SCRIPTS_DIR / "audit_my_repo_benchmark.py"

BENCHMARK_OUTPUT_MARKERS = (
    "benchmark_manifest.json",
    "benchmark_readiness.json",
    "benchmark_labels.jsonl",
)


def _run(args, out_dir):
    return subprocess.run(
        [sys.executable, str(BENCH), *args],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )


def _no_benchmark_artifacts(out_dir: Path) -> bool:
    if not out_dir.exists():
        return True
    return not any((out_dir / marker).exists() for marker in BENCHMARK_OUTPUT_MARKERS)


def test_real_benchmark_without_confirm_rejected():
    with tempfile.TemporaryDirectory() as td:
        labels = Path(td) / "labels.jsonl"
        labels.write_text("", encoding="utf-8")  # presence only; guard fires first
        out_dir = Path(td) / "out"
        proc = _run(
            ["--namespace", "real_benchmark", "--labels", str(labels), "--out", str(out_dir)],
            out_dir,
        )
        assert proc.returncode == 2, f"expected exit 2, got {proc.returncode}\n{proc.stderr}"
        assert "requires --confirm-real-benchmark-namespace" in proc.stderr, proc.stderr
        assert _no_benchmark_artifacts(out_dir), "no benchmark artifacts may be written on rejection"


def test_confirm_flag_without_real_benchmark_rejected():
    with tempfile.TemporaryDirectory() as td:
        labels = Path(td) / "labels.jsonl"
        labels.write_text("", encoding="utf-8")
        out_dir = Path(td) / "out"
        proc = _run(
            [
                "--namespace", "synthetic",
                "--confirm-real-benchmark-namespace",
                "--labels", str(labels),
                "--out", str(out_dir),
            ],
            out_dir,
        )
        assert proc.returncode == 2, f"expected exit 2, got {proc.returncode}\n{proc.stderr}"
        assert "only valid with --namespace real_benchmark" in proc.stderr, proc.stderr
        assert _no_benchmark_artifacts(out_dir)


if __name__ == "__main__":
    test_real_benchmark_without_confirm_rejected()
    test_confirm_flag_without_real_benchmark_rejected()
    print("Task 6.3 (namespace guard) ok")
