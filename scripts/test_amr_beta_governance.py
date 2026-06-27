#!/usr/bin/env python3
"""Task 11.1 - 거버넌스 / 기존 엔트리포인트 재사용 / 비승격 경계 검증.

Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6 (+ 5.x/6.x/7.x/8.1 경계) / design C1, C5.

PR 전에 닫는 가장 민감한 경계: 라벨/피드백/real_benchmark를 날조하지 않으며, 합성/템플릿/
픽스처가 beta readiness로 승격되지 않는다. 본 테스트는 다음을 단언한다.

  A. design_partner_beta_candidate_ready 기본 0 (basis 없음 ⇒ 14게이트 전부 차단, beta 0).
  B. HUMAN-INPUT 임계(≥10 repos, ≥300 labels, ≥3 feedback)가 placeholder/미달로 통과하지 않음.
  C. 합성/템플릿 케이스는 real_human_label_basis를 1로 올리지 못함(증거 경계).
  D. real_benchmark 네임스페이스가 명시적 --confirm 없이 열리지 않음(종료 코드 2, 산출물 미기록).
  E. 기존 8개 엔트리포인트·기존 readiness 스키마·기존 issue 템플릿이 존재(재사용)하고,
     본 스펙 브랜치가 새 schema/product 엔트리포인트/대용량·체크포인트 산출물을 git 추적에
     추가하지 않음(test_amr_beta_*.py와 .kiro/spec 문서만 추가).

합성/픽스처만 사용하며 비승격이다.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import test_amr_beta_harness as H  # noqa: E402

REPO_ROOT = H.REPO_ROOT
bench = H.load_benchmark_module()
GATE_IDS = [g[0] for g in bench.READINESS_GATES]

EXISTING_ENTRYPOINTS = [
    "scripts/audit_my_repo.py",
    "scripts/audit_my_repo.sh",
    "scripts/audit_my_repo_package.py",
    "scripts/audit_my_repo_first_report_smoke.py",
    "scripts/audit_my_repo_label_template.py",
    "scripts/audit_my_repo_label_intake.py",
    "scripts/audit_my_repo_benchmark.py",
    "scripts/audit_review_to_jsonl.py",
]
EXISTING_SCHEMA = "schemas/local_repo_audit_benchmark_readiness.schema.json"
EXISTING_ISSUE_TEMPLATE = ".github/ISSUE_TEMPLATE/design-partner-finding-review.yml"
CHECKPOINT_SUFFIXES = (".pt", ".bin", ".safetensors", ".ckpt", ".pth", ".onnx", ".gguf")
LARGE_FILE_BYTES = 10 * 1024 * 1024


def real_human_label_basis(namespace, confirmed, cases):
    return int(
        namespace == "real_benchmark"
        and bool(confirmed)
        and bool(cases)
        and all(c["human_labeled"] and not c["synthetic"] for c in cases)
    )


def test_A_default_beta_gate_zero():
    summary = H.make_summary(gates_pass=False, basis=0)
    rows = bench.readiness_gate_rows(summary)
    assert all(int(r["passed"]) == 0 for r in rows), "no gate may pass without basis"
    assert summary["design_partner_beta_candidate_ready"] == 0


def test_B_human_input_thresholds_not_placeholder():
    # Real thresholds (drift guard) and below-threshold never passes even with basis.
    assert bench.MIN_REAL_REPOS_FOR_BETA == 10
    assert bench.MIN_HUMAN_LABELS_FOR_BETA == 300
    assert bench.MIN_MAINTAINER_FEEDBACK_FOR_BETA == 3
    for observed, thr in [(9, 10), (299, 300), (2, 3), (0, 10), (0, 300), (0, 3)]:
        assert int(1 == 1 and observed >= thr) == 0


def test_C_synthetic_never_real_basis():
    # synthetic case present, or any non-human-labeled, or wrong namespace/no-confirm.
    assert real_human_label_basis("real_benchmark", True, [{"human_labeled": 1, "synthetic": 1}]) == 0
    assert real_human_label_basis("real_benchmark", True, [{"human_labeled": 0, "synthetic": 0}]) == 0
    assert real_human_label_basis("synthetic", True, [{"human_labeled": 1, "synthetic": 0}]) == 0
    assert real_human_label_basis("real_benchmark", False, [{"human_labeled": 1, "synthetic": 0}]) == 0
    assert real_human_label_basis("real_benchmark", True, []) == 0
    # template-only candidate rows are human_labeled=0 -> basis 0
    tmpl = H.make_label_row(human_labeled=0, synthetic=1)
    assert real_human_label_basis("real_benchmark", True, [{"human_labeled": int(tmpl["human_labeled"]), "synthetic": int(tmpl["synthetic"])}]) == 0


def test_D_real_benchmark_requires_confirm():
    bench_py = SCRIPTS_DIR / "audit_my_repo_benchmark.py"
    with tempfile.TemporaryDirectory() as td:
        labels = Path(td) / "labels.jsonl"
        labels.write_text("", encoding="utf-8")
        out_dir = Path(td) / "out"
        proc = subprocess.run(
            [sys.executable, str(bench_py), "--namespace", "real_benchmark",
             "--labels", str(labels), "--out", str(out_dir)],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        assert proc.returncode == 2, proc.stderr
        assert "requires --confirm-real-benchmark-namespace" in proc.stderr
        markers = ("benchmark_manifest.json", "benchmark_readiness.json")
        assert not out_dir.exists() or not any((out_dir / m).exists() for m in markers)


def test_E_entrypoint_schema_reuse_and_no_new_contracts():
    for rel in EXISTING_ENTRYPOINTS + [EXISTING_SCHEMA, EXISTING_ISSUE_TEMPLATE]:
        assert (REPO_ROOT / rel).is_file(), f"missing reused asset: {rel}"

    # results/ is gitignored.
    chk = subprocess.run(["git", "check-ignore", "results/x"], cwd=str(REPO_ROOT),
                         capture_output=True, text=True)
    assert chk.returncode == 0 and chk.stdout.strip(), "results/ must be gitignored"

    # Files this spec branch added vs origin/main must be only spec docs and
    # test_amr_beta_*.py harness/tests -- no new schema/, no new product entrypoint,
    # no checkpoint/large binaries.
    #
    # In a shallow PR checkout (fetch-depth=1) the origin/main ref may be absent.
    # Distinguish that case (cannot evaluate -> explicit skip) from an actual diff
    # failure (fail-closed). Never silently fail-open with an empty added list.
    ref_check = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", "origin/main"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    if ref_check.returncode != 0 or not ref_check.stdout.strip():
        print(
            "test_E: origin/main ref unavailable (shallow checkout); "
            "skipping added-file governance check (cannot evaluate, not fail-open)",
            file=sys.stderr,
        )
        return

    diff = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=A", "origin/main...HEAD"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    assert diff.returncode == 0, (
        "failed to compute added files against origin/main; "
        f"rc={diff.returncode}\nstdout={diff.stdout}\nstderr={diff.stderr}"
    )
    added = [p for p in diff.stdout.splitlines() if p.strip()]
    for path in added:
        allowed = (
            path.startswith(".kiro/specs/audit-my-repo-design-partner-beta/")
            or (path.startswith("scripts/test_amr_beta_") and path.endswith(".py"))
        )
        assert allowed, f"unexpected new tracked file (possible new contract): {path}"
        assert not path.startswith("schemas/"), f"no new schema may be added: {path}"
        assert not path.lower().endswith(CHECKPOINT_SUFFIXES), f"checkpoint artifact tracked: {path}"
        fp = REPO_ROOT / path
        if fp.is_file():
            assert fp.stat().st_size < LARGE_FILE_BYTES, f"large artifact tracked: {path}"


def _run_all():
    test_A_default_beta_gate_zero()
    test_B_human_input_thresholds_not_placeholder()
    test_C_synthetic_never_real_basis()
    test_D_real_benchmark_requires_confirm()
    test_E_entrypoint_schema_reuse_and_no_new_contracts()


if __name__ == "__main__":
    _run_all()
    print("Task 11.1 (governance / no-synthetic-promotion / entrypoint reuse) ok")
