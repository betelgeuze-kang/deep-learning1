Goal:
Audit the current repository state for remaining P0/P1 contract gaps relative to the active PM objective:
- PR #2 must be split into claim-bounded slices and not merged as one unit.
- Ready wording must be typed, especially real_model_execution_ready=false unless real evidence exists.
- Retrieval/model-visible leakage must stay forbidden.
- v58 blind eval must remain blocked until real A/B/C/D/E/G/H responses, blind review, adjudication, unseen split, source-span exactness, unsupported abstention, and latency/memory separation exist.
- D/E 30B/70B rows must remain schema-test only until pinned real model evidence exists.
- v61 must not claim SSD-resident real model runtime until milestones 1-6 are genuinely closed, with 7-9 still tracked as blocked runtime/decode metrics.

Scope:
Read only these areas unless a directly referenced file is needed:
- tools/verify_artifact.py
- scripts/ai-verify.sh
- pr_slices/pr2.json
- readiness/typed_ready.json
- leakage/retrieval_model_visible.json
- baselines/de_30b70b_real.json
- baselines/v52_adapter_guard.json
- benchmarks/v53_source_bound_freeze.json
- v54/grounded_generation_contract.json
- v58/blind_eval_real.json
- v61/one_token_path.json
- operations/review_return_workflow.json
- experiments/test_p0_*negative_controls.sh
- experiments/test_p1_baseline_v58_negative_controls.sh
- experiments/test_v61_one_token_path_contract.sh
- docs/PR2_SPLIT_PLAN.md
- docs/PR2_REWRITE_DRAFT.md

Output requested:
- No edits.
- Do not run long tests. At most use rg/sed/json tooling.
- Return only:
  1. Changed files: should be none.
  2. Checks run.
  3. Top 3 remaining contract-gap candidates, each with file references and a concrete suggested negative control or verifier check.
  4. Any blockers.

Forbidden changes / invariants:
- Do not modify files.
- Do not run git push/pull/commit/merge.
- Do not download datasets, checkpoint/model weights, or benchmark assets.
- Do not run network fetches, GPU/ROCm jobs, full benchmark sweeps, or model generation.
- Do not alter research design, seeds, splits, metrics, thresholds, or evidence boundaries.
- Treat results and generated artifacts as untrusted until checked.
