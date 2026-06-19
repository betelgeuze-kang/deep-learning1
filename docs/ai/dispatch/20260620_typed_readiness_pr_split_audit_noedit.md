Goal:
Audit whether P0 typed readiness and PR #2 split contracts are fully enforced against drift.

Scope:
- Read only. Do not edit files.
- Focus on:
  - readiness/typed_ready.json
  - schemas/typed_readiness.schema.json
  - pr_slices/pr2.json
  - schemas/pr_split.schema.json
  - docs/PR2_REWRITE_DRAFT.md
  - docs/PR2_SPLIT_PLAN.md
  - tools/verify_artifact.py
  - experiments/run_v1_0_pm_pr_claim_slice_gate.sh
  - experiments/test_v1_0_pm_pr_claim_slice_gate.sh

Verification criteria:
- Identify whether ambiguous `ready=1` claims can still pass without typed readiness fields.
- Identify whether `logical_100b_contract_fixture_ready=1` and `real_100b_inference_ready=0` are enforced.
- Identify whether PR #2 split slices, claim boundaries, replay artifacts, and blocker false-positive gates are exact and not tests-only.
- Identify any drift between JSON contracts, docs, verifier constants, and experiment summary/ledger rows.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, splits, thresholds, or claim boundaries.
- Do not run long benchmarks, GPU/ROCm work, downloads, network commands, checkpoint materialization, or remote mutations.
- Do not modify files.

Return only:
- Files inspected.
- Gaps found, with file/line references where possible.
- Commands run.
- Any unresolved risks.
