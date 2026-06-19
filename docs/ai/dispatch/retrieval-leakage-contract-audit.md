# OpenCode Worker Slice: Retrieval Leakage Contract Audit

Goal:
Audit whether the retrieval/model-visible leakage contract fully enforces that systems only receive natural-language questions plus searchable corpus, while evaluator-only fields stay hidden.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `leakage/retrieval_model_visible.json`
- `schemas/leakage_contract.schema.json`
- `tools/verify_artifact.py`
- `experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh`
- `experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh`
- `docs/RETRIEVAL_LEAKAGE_GUARD.md`
- `pr_slices/pr2.json`

Verification criteria:
- Identify any evaluator-only fields or aliases missing from the source-controlled denylist.
- Identify any model-visible allowed surface fields that are too broad or ambiguous.
- Identify verifier gaps where forbidden source locator/label/path/hash fields could pass.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, or long benchmark runs.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete leakage-contract gaps
- Suggested exact fields or checks
- Blockers
