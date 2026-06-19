Goal:
Propagate the new v53aq A/B/G/H internal pre-baseline per-system contract artifact through the existing v53t, PM PR slice, v59e one-command demo, v60 release gate, and public docs so reviewers can replay the contract boundary from the top-level gates.

Scope:
- Start from the current local WIP in:
  - experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh
  - experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh
- Wire the new artifact `abgh_internal_prebaseline_contract_rows.csv` into downstream copy, hash, required-file, and smoke-test surfaces where v53aq same-query evidence is already copied.
- Update docs only where they already describe v53aq/v53t/PM/v59e/v60 A/B/G/H same-query evidence.

File candidates:
- experiments/run_v53t_complete_source_audit_readiness_gate.sh
- experiments/test_v53t_complete_source_audit_readiness_gate.sh
- experiments/run_v1_0_pm_pr_claim_slice_gate.sh
- experiments/test_v1_0_pm_pr_claim_slice_gate.sh
- experiments/run_v59e_one_command_pm_foundation_demo.sh
- experiments/test_v59e_one_command_pm_foundation_demo.sh
- experiments/run_v60_architecture_challenge_release_contract.sh
- experiments/test_v60_architecture_challenge_release_contract.sh
- README.md
- docs/EXPERIMENTS.md
- docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md

Verification criteria:
- Run lightweight syntax checks for edited shell scripts.
- Run any directly affected smoke tests you edit when feasible.
- Do not run GPU/ROCm jobs, downloads, model generation, network operations, or full benchmark sweeps.
- Preserve evidence boundaries:
  - This is internal v1.0 pre-baseline evidence only.
  - `public_comparison_claim_ready` remains `0`.
  - `public_real_system_performance_claim_ready` remains `0`.
  - D/E 30B/70B replacement or public comparison claims remain blocked.

Forbidden changes / invariants:
- Do not edit or revert unrelated dirty files:
  - .betelgeuze/trace.jsonl
  - AGENTS.md
  - docs/ai/profiles/deep-learning-research.md
  - docs/ai/prompts/cursor_worker_slice.md
  - docs/ai/prompts/deep_learning_research_goal_start.md
  - docs/ai/prompts/opencode_worker_slice.md
- Do not commit, push, merge, publish, open PRs, or mutate external systems.
- Do not add v62/v63 scope.
- Do not silently change seeds, data splits, metric definitions, baseline criteria, or acceptance thresholds.

Return:
- Changed files.
- Tests/checks run and pass/fail.
- Core diff summary.
- Any unresolved blockers or files that need Codex review.
