# OpenCode Worker Slice: v53/v54 Query Evaluation Contract Audit

Goal:
Audit whether the v53 source-bound benchmark and v54 grounded generation contracts enforce source-span binding, negative/abstain/doc-code controls, separate answer/citation/resource evaluation, and no raw prompt stuffing.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `benchmarks/v53_source_bound_freeze.json`
- `schemas/v53_source_benchmark.schema.json`
- `leakage/retrieval_model_visible.json`
- `tools/verify_artifact.py`
- `experiments/run_v53i_complete_source_query_instantiation.sh`
- `experiments/test_v53i_complete_source_query_instantiation.sh`
- `experiments/run_v54c_complete_source_grounded_generation_1000.sh`
- `experiments/test_v54c_complete_source_grounded_generation_1000.sh`
- `pr_slices/pr2.json`
- `docs/PR2_SPLIT_PLAN.md`

Verification criteria:
- Identify contract gaps for v53 query rows, source-span binding, unsupported/missing/doc-code controls.
- Identify contract gaps for answer/citation/resource evaluator separation.
- Identify v54 output artifact shape gaps for answer/citation/unsupported/abstain/resource/wrong-answer guard rows and sha256 sums.
- Identify verifier gaps where raw prompt stuffing or evaluator-only fields could pass.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, or long benchmark runs.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, leakage controls, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete contract/verifier gaps
- Suggested exact fields or checks
- Blockers
