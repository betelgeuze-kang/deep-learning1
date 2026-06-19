Goal:
Find one small, high-value remaining PM gate gap that moves the active objective forward without adding new scaffold.

Scope:
- Inspect docs/PR2_SPLIT_PLAN.md, docs/PR2_REWRITE_DRAFT.md, pr_slices/pr2.json.
- Inspect PM/v58/v59/v60/v61 gate scripts and tests under experiments/.
- Inspect current contract JSONs under baselines/, v58/, v61/ if relevant.

Verification criteria:
- Report exactly 1-3 candidate gaps.
- For each candidate, name the authoritative files and the specific invariant that is missing or weak.
- Prefer gaps that can be fixed with a small contract/test/docs patch and cheap smoke tests.

Forbidden changes / invariants:
- Do not edit files.
- Do not run network, downloads, checkpoint materialization, model generation, long GPU/ROCm jobs, or full benchmark sweeps.
- Do not propose new v62/v63 scaffolding.
- Do not change metric definitions, seeds, splits, acceptance thresholds, or evidence boundaries.
- Do not weaken any blocker, fixture, blind-eval, leakage, or typed-readiness guard.
