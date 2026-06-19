Goal:
Audit why v58 requires A/B/C/D/E/G/H actual responses while the current v58b/v58c template chain only admits D/E/F/G/H.

Scope:
- Read only. Do not edit files.
- Focus on:
  - experiments/run_v58b_blind_eval_candidate_500.sh
  - experiments/test_v58b_blind_eval_candidate_500.sh
  - experiments/run_v58c_blind_response_evidence_intake.sh
  - experiments/test_v58c_blind_response_evidence_intake.sh
  - experiments/run_v58d_blind_review_return_intake.sh
  - experiments/test_v58d_blind_review_return_intake.sh
  - docs/V58_REAL_BLIND_EVAL_CONTRACT.md
  - v58/blind_eval_real.json

Verification criteria:
- Identify the exact constants/loops that omit A/B/C templates.
- Identify expected summary, manifest, and test count changes if v58b emits A/B/C/D/E/G/H instead of D/E/F/G/H.
- Identify whether optional F should remain as optional/non-required or be removed from v58b template output.
- Identify downstream v58d review/adjudication count implications.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, splits, thresholds, or claim boundaries.
- Do not run long benchmarks, GPU/ROCm work, downloads, network commands, checkpoint materialization, model generation, or remote mutations.
- Do not modify files.

Return only:
- Files inspected.
- Gaps found, with file/line references where possible.
- Proposed minimal edit set.
- Commands run.
- Any unresolved risks.
