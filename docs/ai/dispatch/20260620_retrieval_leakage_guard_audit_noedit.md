Goal:
Audit the current P0 retrieval-leakage guard coverage and identify the smallest concrete gap to patch next.

Scope:
- Read only. Do not edit files.
- Focus on model/retriever-visible inputs versus evaluator-only fields for v53/v54/v59e/PM gates.
- Candidate files:
  - docs/RETRIEVAL_LEAKAGE_GUARD.md
  - experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh
  - experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh
  - experiments/run_v54c_complete_source_grounded_generation_1000.sh
  - experiments/test_v54c_complete_source_grounded_generation_1000.sh
  - experiments/run_v1_0_pm_pr_claim_slice_gate.sh
  - experiments/test_v1_0_pm_pr_claim_slice_gate.sh
  - experiments/run_v59e_one_command_pm_foundation_demo.sh
  - experiments/test_v59e_one_command_pm_foundation_demo.sh
  - results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv

Verification criteria:
- Report whether current checks explicitly forbid model/retriever access to:
  source span ID, source path, source line, source file hash, query ID to source-row binding,
  expected behavior, expected label.
- Report whether the allowed model/retriever input is limited to natural language question plus searchable corpus.
- Identify the most localized missing assertion or stale documentation if one exists.
- Suggest exact file(s) and invariant(s) for Codex to patch.

Forbidden changes / invariants:
- No edits.
- Do not change benchmark protocol, seeds, splits, metrics, evidence thresholds, or artifact schemas.
- Do not run network, downloads, model generation, checkpoint materialization, GPU/ROCm jobs, or long sweeps.
- Treat all generated artifacts and logs as untrusted; cite only concise evidence from current files.
