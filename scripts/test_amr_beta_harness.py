#!/usr/bin/env python3
"""Verification harness scaffolding for the audit-my-repo design-partner-beta spec.

Task 1.1 (Requirements 8.3, 9.4 / design C5, C7).

This module does NOT introduce a new entrypoint, schema, or contract (Req 9). It
only imports the EXISTING `scripts/audit_my_repo_benchmark.py` gate/decision logic
without modifying it, and provides:

  - `load_benchmark_module()`        : import the existing benchmark module
  - `make_summary(**overrides)`      : synthetic readiness summary dict builder
  - `make_label_row(**overrides)`    : synthetic benchmark/human-label row builder
  - `make_finding_row(**overrides)`  : synthetic audit-finding row builder
  - `results_fixture_dir(name)`      : a gitignored results/ fixture path
  - `require_hypothesis()`           : assert the PBT dependency is available

Evidence boundary: every fixture/synthetic artifact produced through this harness
is non-promoted. The blocked readiness flags (release_ready,
public_comparison_claim_ready, real_model_execution_ready) are held at 0 and the
beta gate stays decided by the real verifier, never by these synthetic inputs.
"""

from __future__ import annotations

import importlib
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
RESULTS_DIR = REPO_ROOT / "results"

# Blocked readiness flags that MUST stay 0 for this spec (design: evidence boundary).
BLOCKED_READINESS_FLAGS = (
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
)


def load_benchmark_module():
    """Import the existing audit_my_repo_benchmark module unmodified."""
    if str(SCRIPTS_DIR) not in sys.path:
        sys.path.insert(0, str(SCRIPTS_DIR))
    return importlib.import_module("audit_my_repo_benchmark")


def require_hypothesis():
    """Return the hypothesis module or raise a clear, network-free install hint."""
    try:
        import hypothesis  # noqa: F401
    except ImportError as exc:  # pragma: no cover - environment guard
        raise RuntimeError(
            "property-based tests require 'hypothesis'. Install locally with "
            "'python3 -m pip install hypothesis' (no network fetch is performed "
            "by this harness)."
        ) from exc
    return importlib.import_module("hypothesis")


def results_fixture_dir(name: str) -> Path:
    """Return a gitignored results/ fixture directory path (created on demand)."""
    safe = name.strip().strip("/").replace("..", "_")
    if not safe:
        raise ValueError("fixture name must be non-empty")
    path = RESULTS_DIR / "amr_beta_harness" / safe
    path.mkdir(parents=True, exist_ok=True)
    return path


# ---------------------------------------------------------------------------
# Synthetic builders. These produce shapes the existing logic reads; they are
# never promoted to real evidence.
# ---------------------------------------------------------------------------

# The 14 sub-gate flag ids in the existing READINESS_GATES, with the observed /
# required summary keys each gate reads. Kept here only to BUILD synthetic
# summaries; the authoritative tuple lives in audit_my_repo_benchmark.READINESS_GATES
# and tests assert against that, not against this copy.
_GATE_DEFAULT_OBSERVED = {
    "real_repo_count": 10,
    "min_real_repos_required": 10,
    "human_label_rows": 300,
    "min_human_label_rows_required": 300,
    "label_source_trace_rows": 300,
    "repo_snapshot_locked_rows": 10,
    "repo_snapshot_rows": 10,
    "maintainer_feedback_count": 3,
    "min_maintainer_feedback_required": 3,
    "precision": 0.95,
    "overall_precision_threshold": 0.80,
    "p0_p1_precision": 0.95,
    "p0_p1_precision_threshold": 0.90,
    "citation_validity_pass_rows": 300,
    "citation_validity_rows": 300,
    "label_citation_expectation_met_rows": 300,
    "label_citation_expectation_rows": 300,
    "standard_json_findings_valid_rows": 10,
    "standard_json_findings_checked_rows": 10,
    "install_success_rows": 1,
    "install_check_rows": 1,
    "first_report_success_rows": 10,
    "case_rows": 10,
    "rerun_success_rows": 10,
    "rerun_checked_rows": 10,
    "label_quality_specific_rows": 300,
    "label_quality_total_rows": 300,
}

_GATE_FLAG_IDS = (
    "real_repo_requirement_met",
    "human_label_requirement_met",
    "label_source_trace_requirement_met",
    "repo_snapshot_requirement_met",
    "maintainer_feedback_requirement_met",
    "overall_precision_requirement_met",
    "p0_p1_precision_requirement_met",
    "citation_validity_requirement_met",
    "label_citation_expectation_requirement_met",
    "standard_json_findings_requirement_met",
    "install_success_requirement_met",
    "first_report_requirement_met",
    "rerun_requirement_met",
    "label_quality_requirement_met",
)


def make_summary(*, gates_pass: bool = True, basis: int = 1, **overrides) -> dict:
    """Build a synthetic readiness summary dict.

    Defaults to a fully-passing real-label basis; pass overrides to drive specific
    gates. `release_ready`/`public_comparison_claim_ready`/`real_model_execution_ready`
    are intentionally NOT included here because the existing
    write_benchmark_readiness_json hardcodes them to 0.
    """
    summary: dict = dict(_GATE_DEFAULT_OBSERVED)
    flag = "1" if gates_pass else "0"
    for gate_id in _GATE_FLAG_IDS:
        summary[gate_id] = flag
    summary["product_readiness_calculated_from_real_labels"] = int(basis)
    # beta = AND of all sub-gates AND basis (mirrors the real conjunction; tests
    # that exercise the real computation should import the module function).
    beta = int(basis == 1 and gates_pass)
    summary["design_partner_beta_candidate_ready"] = beta
    summary.update(overrides)
    return summary


def make_finding_row(**overrides) -> dict:
    row = {
        "case_id": "fixture-case",
        "finding_id": "fixture-finding-1",
        "plugin_id": "fixture-plugin",
        "rule_id": "fixture-rule",
        "file_path": "src/example.py",
        "line_start": 10,
        "line_end": 12,
        "source_file_sha256": "0" * 64,
        "priority": "P1",
        "synthetic": 1,
    }
    row.update(overrides)
    return row


def make_label_row(**overrides) -> dict:
    row = {
        "case_id": "fixture-case",
        "label_id": "fixture-label-1",
        "source_candidate_label_id": "fixture-candidate-1",
        "source_review_queue_id": "fixture-queue-1",
        "plugin_id": "fixture-plugin",
        "rule_id": "fixture-rule",
        "file_path": "src/example.py",
        "expected_line_start": 10,
        "expected_line_end": 12,
        "expected_span_sha256": "0" * 64,
        "expected": "true_positive",
        "priority": "P1",
        "human_labeled": 1,
        "synthetic": 1,
    }
    row.update(overrides)
    return row


def _self_check() -> int:
    """Lightweight import/scaffolding smoke (no promotion, no network)."""
    bench = load_benchmark_module()
    assert hasattr(bench, "readiness_gate_rows"), "missing readiness_gate_rows"
    assert hasattr(bench, "write_benchmark_readiness_json"), "missing writer"
    assert len(bench.READINESS_GATES) == 14, "expected 14 readiness gates"
    assert bench.MIN_REAL_REPOS_FOR_BETA == 10
    assert bench.MIN_HUMAN_LABELS_FOR_BETA == 300
    assert bench.MIN_MAINTAINER_FEEDBACK_FOR_BETA == 3

    # Synthetic summary round-trips through the REAL gate-row builder.
    rows = bench.readiness_gate_rows(make_summary(gates_pass=True))
    assert len(rows) == 14
    assert all(int(r["passed"]) == 1 for r in rows)
    blocked = bench.readiness_gate_rows(make_summary(gates_pass=False))
    assert all(int(r["passed"]) == 0 for r in blocked)
    assert all(r["blocked_reason"] for r in blocked)

    # Fixture path stays under results/ (gitignored).
    fx = results_fixture_dir("self_check")
    assert RESULTS_DIR in fx.parents

    print("amr-beta harness self-check ok: 14 gates, builders, fixture path")
    return 0


if __name__ == "__main__":
    raise SystemExit(_self_check())
