Goal:
Audit remaining retrieval/model-visible leakage risks for the active PR #2 normalization goal.

Scope:
Read-only audit across docs/, experiments/, tools/, benchmarks/, leakage/, pr_slices/, and pipelines/.

File candidates:
- leakage/retrieval_model_visible.json
- tools/verify_artifact.py
- experiments/run_v1_0_pm_pr_claim_slice_gate.sh
- experiments/test_v1_0_pm_pr_claim_slice_gate.sh
- experiments/run_v53*.sh
- experiments/run_v54*.sh
- docs/PR2_SPLIT_PLAN.md
- docs/PR2_REWRITE_DRAFT.md
- pr_slices/pr2.json
- benchmarks/v53_source_bound_freeze.json

Verification criteria:
- Identify model/retriever-visible surfaces that mention or may pass source span ID, source path, source line, source file hash, direct query/source binding, expected behavior, or expected label.
- Identify whether each risky surface is already covered by leakage/retrieval_model_visible.json and tools/verify_artifact.py leakage checks.
- Identify whether PR2 slice verification commands compare leakage/retrieval_model_visible.json against the replayed PM ledger.
- Keep output short: changed files must be "none"; include only findings with file paths and line numbers where possible, plus a short recommendation.

Forbidden changes / invariants:
- Do not edit files.
- Do not run network, downloads, model generation, GPU/ROCm jobs, checkpoint materialization, or long benchmark sweeps.
- Do not change seeds, splits, metrics, evidence boundaries, acceptance thresholds, or generated results.
