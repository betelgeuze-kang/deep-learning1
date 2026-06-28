#!/usr/bin/env python3
"""Guard against PM-ledger / typed-readiness naming drift.

This is a GUARD, not a generator. It creates/mutates nothing under results/.

Context: `results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv`
is a generated/local ledger (gitignored, NOT a source of truth). The source of
truth is `readiness/typed_ready.json` (enforced by
`tools/verify_artifact.py typed-readiness`). A stale local copy once carried
retired typed-ready names (e.g. `v53_benchmark_foundation_frozen`,
`v54_free_running_fixture_ready`) and a v54 misleading-flag typo, which made the
local `./scripts/ai-verify.sh` fail. This guard catches recurrence.

Checks:
  1. No tracked source file contains a retired typed-ready name.
  2. If the local PM ledger is present, it must mirror readiness/typed_ready.json
     (replacement_flag, scope_id, misleading_ready_flag, and the readiness bools)
     and must not contain any retired name or known retired misleading-flag pair.
  3. If the PM ledger is absent (clean CI checkout), skip the ledger check (pass).

PR-safe: no network, no results/ creation, read-only.
"""

from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
TYPED_READY = REPO_ROOT / "readiness" / "typed_ready.json"
PM_LEDGER = REPO_ROOT / "results" / "v1_0_pm_pr_claim_slice_gate" / "gate_001" / "pm_ready_semantic_rows.csv"

# Retired typed-ready replacement names that must never reappear.
RETIRED_READY_FLAGS = {
    "v53_benchmark_foundation_frozen",
    "v54_free_running_fixture_ready",
}
# Known retired (scope_id, misleading_ready_flag) typo pairs.
RETIRED_MISLEADING_FLAGS = {
    ("v54-free-running-generation", "v53_ready"),
}
READINESS_BOOL_FIELDS = [
    "contract_ready",
    "fixture_execution_ready",
    "real_model_execution_ready",
    "heldout_metric_ready",
    "human_review_ready",
    "independent_reproduction_ready",
    "release_ready",
]


def _bool_to_csv(value) -> str:
    return "1" if bool(value) else "0"


def test_retired_names_absent_from_tracked_source():
    # `git grep` only searches tracked files; results/ is gitignored so excluded.
    # This guard script and the docs that document the retired names intentionally
    # mention them, so they are excluded from the offender search.
    proc = subprocess.run(
        [
            "git", "grep", "-I", "-l", "-E", "|".join(sorted(RETIRED_READY_FLAGS)),
            "--", ".",
            ":(exclude)scripts/test_typed_readiness_pm_ledger_drift.py",
            ":(exclude)docs/READY_SEMANTICS.md",
        ],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    # git grep returns 1 when no matches (expected). returncode 0 means matches found.
    if proc.returncode == 0 and proc.stdout.strip():
        offenders = [p for p in proc.stdout.splitlines() if p.strip()]
        raise AssertionError(
            "retired typed-ready names must not appear in tracked source: "
            + ", ".join(offenders)
        )
    if proc.returncode not in (0, 1):
        raise AssertionError(f"git grep failed rc={proc.returncode}: {proc.stderr}")


def test_local_pm_ledger_mirrors_typed_ready_when_present():
    if not PM_LEDGER.is_file():
        print("PM ledger absent (clean checkout); skipping mirror check (pass)")
        return

    typed = json.loads(TYPED_READY.read_text(encoding="utf-8"))
    typed_rows = typed["rows"]
    by_replacement = {r["replacement_flag"]: r for r in typed_rows}

    with PM_LEDGER.open(newline="", encoding="utf-8") as handle:
        ledger_rows = list(csv.DictReader(handle))

    raw = PM_LEDGER.read_text(encoding="utf-8")
    for retired in RETIRED_READY_FLAGS:
        assert retired not in raw, (
            f"{PM_LEDGER} contains retired typed-ready name '{retired}'; "
            "it must mirror readiness/typed_ready.json"
        )

    # No duplicate replacement_flag rows (a duplicate means the ledger no longer
    # mirrors typed_ready.json even if each duplicate validates individually).
    ledger_replacements = [r.get("replacement_flag", "") for r in ledger_rows]
    dupes = sorted({k for k in ledger_replacements if ledger_replacements.count(k) > 1})
    assert not dupes, f"{PM_LEDGER}: duplicate replacement_flag rows: {', '.join(dupes)}"

    # Completeness: every typed_ready row that requires a PM ledger entry must be
    # present (a truncated ledger must not pass).
    ledger_by_replacement = {r.get("replacement_flag", ""): r for r in ledger_rows}
    for expected_row in typed_rows:
        if expected_row.get("pm_ledger_required") is False:
            continue
        rkey = expected_row["replacement_flag"]
        assert rkey in ledger_by_replacement, (
            f"{PM_LEDGER}: missing required typed-ready row replacement_flag={rkey} "
            "(ledger must mirror readiness/typed_ready.json in full)"
        )

    for row in ledger_rows:
        scope = row.get("scope_id", "")
        misleading = row.get("misleading_ready_flag", "")
        assert (scope, misleading) not in RETIRED_MISLEADING_FLAGS, (
            f"{PM_LEDGER}: retired misleading_ready_flag for {scope}: {misleading}"
        )
        replacement = row.get("replacement_flag", "")
        expected = by_replacement.get(replacement)
        assert expected is not None, (
            f"{PM_LEDGER}: replacement_flag '{replacement}' not found in typed_ready.json"
        )
        assert row.get("scope_id") == expected["scope_id"], (
            f"{PM_LEDGER}: scope_id mismatch for {replacement}"
        )
        assert row.get("misleading_ready_flag") == expected["misleading_ready_flag"], (
            f"{PM_LEDGER}: misleading_ready_flag mismatch for {replacement}"
        )
        for field in READINESS_BOOL_FIELDS:
            want = _bool_to_csv(expected[field])
            got = row.get(field)
            assert got == want, (
                f"{PM_LEDGER}: {replacement}.{field} expected {want}, got {got} "
                "(must mirror readiness/typed_ready.json)"
            )


def _run_all():
    test_retired_names_absent_from_tracked_source()
    test_local_pm_ledger_mirrors_typed_ready_when_present()


if __name__ == "__main__":
    _run_all()
    print("typed-readiness PM-ledger drift guard ok")
