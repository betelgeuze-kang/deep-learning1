#!/usr/bin/env python3
"""Guard for the AMR beta human-input collection packet.

This is a GUARD, not a generator or a promotion step. It is PR-safe (read-only,
no network, creates/mutates nothing under results/).

It verifies that the human-input packet (docs + templates) is present and
internally consistent with the EXISTING tools, that it keeps the beta readiness
claim blocked, and that no real human-input evidence is committed (only the
clearly-synthetic *.example placeholders).
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

PACKET = REPO_ROOT / "docs" / "AMR_BETA_HUMAN_INPUT_PACKET.md"
REPO_INTAKE = REPO_ROOT / "docs" / "templates" / "amr-beta-repo-intake.md"
LABEL_EXAMPLE = REPO_ROOT / "docs" / "templates" / "amr-beta-human-label-decision.jsonl.example"
FEEDBACK_TEMPLATE = REPO_ROOT / "docs" / "templates" / "amr-beta-maintainer-feedback.md"
LABEL_INTAKE = REPO_ROOT / "scripts" / "audit_my_repo_label_intake.py"
BENCHMARK = REPO_ROOT / "scripts" / "audit_my_repo_benchmark.py"
REPO_INTAKE_VALIDATOR = REPO_ROOT / "scripts" / "amr_beta_repo_intake_validate.py"
REPO_AUDIT_PLAN = REPO_ROOT / "scripts" / "amr_beta_repo_audit_plan.py"
HUMAN_INPUT_STATUS = REPO_ROOT / "scripts" / "amr_beta_human_input_status.py"
MAINTAINER_FEEDBACK_PACKET = REPO_ROOT / "scripts" / "amr_beta_maintainer_feedback_packet.py"
LABEL_PACKET = REPO_ROOT / "scripts" / "amr_beta_label_packet.py"
LABEL_INTAKE_PLAN = REPO_ROOT / "scripts" / "amr_beta_label_intake_plan.py"
BENCHMARK_INPUT_PREPARE = REPO_ROOT / "scripts" / "amr_beta_benchmark_input_prepare.py"
RUNTIME_PREFLIGHT = REPO_ROOT / "scripts" / "amr_beta_runtime_preflight.py"
RUNTIME_APPROVAL_REQUEST = REPO_ROOT / "scripts" / "amr_beta_runtime_approval_request.py"
RUNTIME_APPROVAL_STATUS = REPO_ROOT / "scripts" / "amr_beta_runtime_approval_status.py"
OPERATOR_STATUS = REPO_ROOT / "scripts" / "amr_beta_operator_status.py"
READINESS_BACKLOG = REPO_ROOT / "scripts" / "amr_beta_readiness_backlog.py"
DESIGN_PARTNER_PACKET = REPO_ROOT / "scripts" / "amr_beta_design_partner_packet.py"
HARDENING_ANALYZE = REPO_ROOT / "scripts" / "amr_beta_hardening_analyze.py"

REQUIRED_FILES = [
    PACKET,
    REPO_INTAKE,
    LABEL_EXAMPLE,
    FEEDBACK_TEMPLATE,
    REPO_INTAKE_VALIDATOR,
    REPO_AUDIT_PLAN,
    HUMAN_INPUT_STATUS,
    MAINTAINER_FEEDBACK_PACKET,
    LABEL_PACKET,
    LABEL_INTAKE_PLAN,
    BENCHMARK_INPUT_PREPARE,
    RUNTIME_PREFLIGHT,
    RUNTIME_APPROVAL_REQUEST,
    RUNTIME_APPROVAL_STATUS,
    OPERATOR_STATUS,
    READINESS_BACKLOG,
    DESIGN_PARTNER_PACKET,
    HARDENING_ANALYZE,
]

# Claim-boundary / threshold phrases the packet must state.
PACKET_REQUIRED_SNIPPETS = [
    "Operator checklist for 9.1-9.3",
    "design_partner_beta_candidate_ready",
    "remains **blocked (0)**",
    "Templates only.",
    "MIN_REAL_REPOS_FOR_BETA=10",
    "MIN_HUMAN_LABELS_FOR_BETA=300",
    "MIN_MAINTAINER_FEEDBACK_FOR_BETA=3",
    "real_benchmark",
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "Concatenate only verified `benchmark_labels.jsonl` outputs",
    "human owner supplied and verified against local disk",
    "python3 scripts/amr_beta_repo_intake_validate.py",
    "results/amr_beta_repo_intake_status.json",
    "current repo git preflight",
    "selected_current_repo_preflight_failed_rows",
    "input_intake_sha256",
    "repo_snapshot_lock_sha256",
    "repo_intake_local_fingerprint_sha256",
    "runs_audit=0",
    "python3 scripts/amr_beta_repo_audit_plan.py",
    "runs_audit=0",
    "creates_benchmark_evidence=0",
    "python3 scripts/amr_beta_human_input_status.py",
    "python3 scripts/amr_beta_maintainer_feedback_packet.py",
    "maintainer_progress_rows",
    "case_feedback_progress_rows",
    "python3 scripts/amr_beta_label_packet.py",
    "audit_my_repo_label_template.py --verify-existing",
    "python3 scripts/amr_beta_label_intake_plan.py",
    "compiles_labels=0",
    "label_template_bundle_sha256",
    "--label-packet-summary",
    "label_packet_summary_sha256",
    "label_packet_decisions_bundle_sha256",
    "python3 scripts/amr_beta_benchmark_input_prepare.py",
    "audit_my_repo_label_intake.py --verify-existing",
    "python3 scripts/amr_beta_runtime_preflight.py",
    "preflight_input_bundle_sha256",
    "label_intake_bundle_sha256",
    "python3 scripts/amr_beta_runtime_approval_request.py",
    "reject missing, skipped, failed, or inconsistent",
    "label_template_manifest_sha256s",
    "label_intake_manifest_sha256s",
    "python3 scripts/amr_beta_runtime_approval_status.py",
    "python3 scripts/amr_beta_operator_status.py",
    "results/amr_beta_human_input_status.json",
    "--human-input-status",
    "current local operator stage",
    "preflight -> approval request -> approval status",
    "operator status also checks",
    "approved `benchmark_out`",
    "amr_beta_runtime_approval_record.v1",
    "codex_runtime_permission_granted_by_this_packet=0",
    "python3 scripts/amr_beta_readiness_backlog.py",
    "python3 scripts/amr_beta_design_partner_packet.py",
    "--operator-status",
    "blocked readiness without a backlog",
    "python3 scripts/amr_beta_hardening_analyze.py",
    "--per-case-out-root",
    "--label-intake-dir",
    "reviewer_id",
    "safe, non-placeholder",
    "reviewer progress summary",
    "distinct_reviewer_id_count",
    "valid_human_label_rows_missing_reviewer_id",
    "does not make them\nhuman-supplied inputs",
    "counts_for_beta=0",
]

REPO_INTAKE_REQUIRED_SNIPPETS = [
    "clean_worktree",
    "owner_or_maintainer_contact",
    "namespace",
    "real_benchmark_namespace_confirmed",
    "git status --porcelain",
    "git rev-parse HEAD",
    "python3 scripts/amr_beta_repo_intake_validate.py",
    "example does not count toward the threshold",
    "leave any `EXAMPLE-*` value",
    "`*.invalid`",
    "creates_benchmark_evidence=0",
]

FEEDBACK_TEMPLATE_REQUIRED_SNIPPETS = [
    "case_id",
    "maintainer_id",
    "feedback_text",
    "feedback_text_sha256",
    "feedback_text_sha256_status",
    "human_feedback",
    "synthetic",
    "counts_for_beta",
    "duplicate `feedback_id` values are",
    "SYNTHETIC EXAMPLE",
]

LABEL_INTAKE_CONTRACT_SNIPPETS = [
    "must not be marked template_only",
    "must include human_labeled=true",
    "expected must be present or absent",
    "requires a source-bound citation span",
]

BENCHMARK_CONTRACT_SNIPPETS = [
    "MIN_REAL_REPOS_FOR_BETA = 10",
    "MIN_HUMAN_LABELS_FOR_BETA = 300",
    "MIN_MAINTAINER_FEEDBACK_FOR_BETA = 3",
    "--namespace real_benchmark requires --confirm-real-benchmark-namespace",
    "synthetic cases cannot be evaluated in the real_benchmark namespace",
    "feedback row {idx} missing maintainer_id",
    "must include feedback_text or a sha256 feedback_text_sha256",
]


def test_packet_files_present():
    missing = [str(p.relative_to(REPO_ROOT)) for p in REQUIRED_FILES if not p.is_file()]
    assert not missing, f"missing human-input packet files: {', '.join(missing)}"


def test_packet_states_claim_boundary_and_thresholds():
    text = PACKET.read_text(encoding="utf-8")
    missing = [s for s in PACKET_REQUIRED_SNIPPETS if s not in text]
    assert not missing, f"packet missing required snippets: {missing}"


def test_repo_intake_template_is_operator_ready():
    text = REPO_INTAKE.read_text(encoding="utf-8")
    missing = [s for s in REPO_INTAKE_REQUIRED_SNIPPETS if s not in text]
    assert not missing, f"repo intake template missing required snippets: {missing}"


def test_feedback_template_matches_benchmark_contract_and_is_placeholder():
    text = FEEDBACK_TEMPLATE.read_text(encoding="utf-8")
    missing = [s for s in FEEDBACK_TEMPLATE_REQUIRED_SNIPPETS if s not in text]
    assert not missing, f"feedback template missing required snippets: {missing}"


def test_packet_matches_existing_tool_contracts():
    label_intake = LABEL_INTAKE.read_text(encoding="utf-8")
    missing = [s for s in LABEL_INTAKE_CONTRACT_SNIPPETS if s not in label_intake]
    assert not missing, f"label intake contract snippets missing: {missing}"

    benchmark = BENCHMARK.read_text(encoding="utf-8")
    missing = [s for s in BENCHMARK_CONTRACT_SNIPPETS if s not in benchmark]
    assert not missing, f"benchmark contract snippets missing: {missing}"


def test_label_example_matches_intake_contract_and_is_synthetic():
    lines = [ln for ln in LABEL_EXAMPLE.read_text(encoding="utf-8").splitlines() if ln.strip()]
    assert lines, "label decision example must contain at least one row"
    seen = set()
    for i, ln in enumerate(lines, 1):
        row = json.loads(ln)
        # Mirrors scripts/audit_my_repo_label_intake.py normalize_decisions().
        clid = str(row.get("candidate_label_id") or "").strip()
        assert clid, f"example row {i}: candidate_label_id required"
        assert clid not in seen, f"example row {i}: duplicate candidate_label_id {clid}"
        seen.add(clid)
        assert not row.get("template_only"), f"example row {i}: decision must not be template_only"
        assert bool(row.get("human_labeled") or row.get("human_reviewed")), (
            f"example row {i}: human_labeled=true required"
        )
        expected = str(row.get("expected") or row.get("human_expected") or "").strip().lower()
        assert expected in {"present", "absent"}, (
            f"example row {i}: expected must be present or absent, got {expected!r}"
        )
        priority = str(row.get("priority") or "").strip().upper()
        assert priority in {"", "P0", "P1", "P2", "P3"}, f"example row {i}: invalid priority {priority}"
        # Must be clearly synthetic so it can never be mistaken for real evidence.
        assert "EXAMPLE" in clid.upper(), f"example row {i}: candidate_label_id must be marked EXAMPLE"


def test_no_real_human_input_committed():
    # Only the *.example label file may be tracked; a real decisions JSONL or any
    # real label/feedback/benchmark evidence must not be committed.
    tracked = subprocess.run(
        ["git", "ls-files", "docs/templates/", "results/"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    assert tracked.returncode == 0, f"git ls-files failed: {tracked.stderr}"
    # Real human-input / benchmark evidence basenames that must never be tracked.
    forbidden_basenames = {
        "amr-beta-human-label-decision.jsonl",  # non-example real decisions
        "benchmark_labels.jsonl",
        "benchmark_labels.json",
        "benchmark_readiness.json",
        "benchmark_maintainer_feedback.json",
        "benchmark_maintainer_feedback.csv",
    }
    # results/ path substrings that indicate committed real evidence.
    forbidden_results_substrings = ("label_intake", "audit_benchmark")
    for path in tracked.stdout.splitlines():
        p = path.strip()
        if not p:
            continue
        base = p.rsplit("/", 1)[-1]
        assert base not in forbidden_basenames, (
            f"real human-input/benchmark evidence must not be committed: {p}"
        )
        if p.startswith("results/") and any(s in p for s in forbidden_results_substrings):
            raise AssertionError(f"real benchmark/label evidence must not be committed: {p}")


def _run_all():
    test_packet_files_present()
    test_packet_states_claim_boundary_and_thresholds()
    test_repo_intake_template_is_operator_ready()
    test_feedback_template_matches_benchmark_contract_and_is_placeholder()
    test_packet_matches_existing_tool_contracts()
    test_label_example_matches_intake_contract_and_is_synthetic()
    test_no_real_human_input_committed()


if __name__ == "__main__":
    _run_all()
    print("AMR beta human-input packet guard ok")
