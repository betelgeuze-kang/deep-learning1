Goal:
Audit whether the v58 blind-eval contract enforces the P1 real-execution requirements without letting fixture/intake rows become measured claims.

Scope:
- Read only. Do not edit files.
- Focus on:
  - v58/blind_eval_real.json
  - docs/V58_REAL_BLIND_EVAL_CONTRACT.md
  - tools/verify_artifact.py
  - experiments/run_v58c_blind_response_evidence_intake.sh
  - experiments/test_v58c_blind_response_evidence_intake.sh
  - experiments/run_v58d_blind_review_return_intake.sh
  - experiments/test_v58d_blind_review_return_intake.sh
  - experiments/run_v1_0_pm_pr_claim_slice_gate.sh
  - experiments/test_v1_0_pm_pr_claim_slice_gate.sh

Verification criteria:
- Identify whether A/B/C/D/E/G/H actual response requirements are explicit.
- Identify whether same corpus/context budget, blind identity, unseen split, source-span exactness, unsupported abstention, and latency/memory separation are enforced.
- Identify whether at least 2 independent reviewers, disagreement, and adjudication are required.
- Identify whether v58c/v58d intake or fixture rows can be misread as completed real blind eval.
- Identify drift between JSON contract, docs, verifier constants, and PM gate ledgers.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, splits, thresholds, or claim boundaries.
- Do not run long benchmarks, GPU/ROCm work, downloads, network commands, checkpoint materialization, model generation, or remote mutations.
- Do not modify files.

Return only:
- Files inspected.
- Gaps found, with file/line references where possible.
- Commands run.
- Any unresolved risks.
