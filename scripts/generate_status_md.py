#!/usr/bin/env python3
"""Regenerate docs/STATUS.md from readiness/typed_ready.json.

Keeps the human-readable status mirror in sync with the machine source of truth.
Run this after editing readiness/typed_ready.json and diff docs/STATUS.md to
confirm the expected change.

Usage:
    python3 scripts/generate_status_md.py           # overwrite docs/STATUS.md
    python3 scripts/generate_status_md.py --check   # exit 1 if out of date
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPED_READY = ROOT / "readiness" / "typed_ready.json"
STATUS_MD = ROOT / "docs" / "STATUS.md"


def generate() -> str:
    data = json.loads(TYPED_READY.read_text(encoding="utf-8"))
    cols = data["policy"]["typed_fields"]
    rows = data["rows"]

    def mark(v: bool) -> str:
        return "ready" if v else "\u2014"

    lines: list[str] = []
    lines.append("# Central Readiness Status\n")
    lines.append("")
    lines.append("This is the human-readable mirror of the machine-enforced typed readiness contract.\n")
    lines.append("")
    lines.append("- Source of truth: [`readiness/typed_ready.json`](../readiness/typed_ready.json)")
    lines.append("- Enforced by: `tools/verify_artifact.py typed-readiness readiness/typed_ready.json` (run from `./scripts/ai-verify.sh`)")
    lines.append("- Schema: [`schemas/typed_readiness.schema.json`](../schemas/typed_readiness.schema.json)")
    lines.append("")
    lines.append("Each scope advances along a typed ladder. Only the typed flags below are claimable; bare `vXX_ready` wording is forbidden (`ready_wording_policy: typed-ready-only`). `ready` means the typed flag is `true`; `\u2014` means it is still `false` (blocked) and must not be claimed.\n")
    lines.append("")
    lines.append("Ladder order: `contract_ready -> fixture_execution_ready -> real_model_execution_ready -> heldout_metric_ready -> human_review_ready -> independent_reproduction_ready -> release_ready`.\n")
    lines.append("")
    lines.append("## Scope status\n")
    lines.append("")

    hdr = ["scope_id"] + cols + ["evidence_path"]
    lines.append("| " + " | ".join(hdr) + " |")
    lines.append("|" + "|".join(["---"] * len(hdr)) + "|")
    for r in rows:
        cells = [r["scope_id"]] + [mark(r[c]) for c in cols] + [f'`{r["evidence_path"]}`']
        lines.append("| " + " | ".join(cells) + " |")

    lines.append("")
    lines.append("## v53 / v54 scope separation\n")
    lines.append("")
    lines.append("`v53` and `v54` are tracked as separate scopes, not one combined `v53-v54-query-evaluation-pipeline` row.\n")
    lines.append("")
    lines.append("- `v53-benchmark-foundation` is `contract_ready` and `fixture_execution_ready`. It mirrors `benchmarks/v53_source_bound_freeze.json` (`machine_foundation_freeze_ready: true`, 7/7 requirements `pass`). Real-model execution, heldout metric, human review, independent reproduction, and release remain blocked.")
    lines.append("- `v54-free-running-generation` is `contract_ready` only. `fixture_execution_ready` is `false` because `v54/free_running_generation_evidence_intake_contract.json` reports `present_required_artifact_count: 0` of `required_artifact_count: 7`. No generation fixtures exist yet, so fixture execution must not be claimed.\n")
    lines.append("")
    lines.append("When `v54` fixtures are produced and the intake contract reports the required artifacts present, flip `v54-free-running-generation.fixture_execution_ready` to `true` in `readiness/typed_ready.json`, update the matching expectation in `tools/verify_artifact.py`, and rerun `./scripts/ai-verify.sh`.")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    expected = generate()
    if "--check" in sys.argv:
        if not STATUS_MD.is_file():
            print("docs/STATUS.md does not exist", file=sys.stderr)
            return 1
        actual = STATUS_MD.read_text(encoding="utf-8")
        if actual.strip() != expected.strip():
            print("docs/STATUS.md is out of date with readiness/typed_ready.json", file=sys.stderr)
            print("run: python3 scripts/generate_status_md.py", file=sys.stderr)
            return 1
        print("docs/STATUS.md is up to date")
        return 0
    STATUS_MD.write_text(expected, encoding="utf-8")
    print(f"wrote {STATUS_MD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
