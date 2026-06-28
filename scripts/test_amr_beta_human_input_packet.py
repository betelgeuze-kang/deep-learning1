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

REQUIRED_FILES = [PACKET, REPO_INTAKE, LABEL_EXAMPLE, FEEDBACK_TEMPLATE]

# Claim-boundary / threshold phrases the packet must state.
PACKET_REQUIRED_SNIPPETS = [
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
]


def test_packet_files_present():
    missing = [str(p.relative_to(REPO_ROOT)) for p in REQUIRED_FILES if not p.is_file()]
    assert not missing, f"missing human-input packet files: {', '.join(missing)}"


def test_packet_states_claim_boundary_and_thresholds():
    text = PACKET.read_text(encoding="utf-8")
    missing = [s for s in PACKET_REQUIRED_SNIPPETS if s not in text]
    assert not missing, f"packet missing required snippets: {missing}"


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
    # real label/feedback evidence must not be committed.
    tracked = subprocess.run(
        ["git", "ls-files", "docs/templates/", "results/"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    assert tracked.returncode == 0, f"git ls-files failed: {tracked.stderr}"
    for path in tracked.stdout.splitlines():
        p = path.strip()
        if not p:
            continue
        # A non-example label decisions file must not be tracked.
        assert not p.endswith("amr-beta-human-label-decision.jsonl"), (
            f"real human-label decisions file must not be committed: {p}"
        )
        if p.startswith("results/") and "label_intake" in p:
            raise AssertionError(f"real label-intake evidence must not be committed: {p}")


def _run_all():
    test_packet_files_present()
    test_packet_states_claim_boundary_and_thresholds()
    test_label_example_matches_intake_contract_and_is_synthetic()
    test_no_real_human_input_committed()


if __name__ == "__main__":
    _run_all()
    print("AMR beta human-input packet guard ok")
