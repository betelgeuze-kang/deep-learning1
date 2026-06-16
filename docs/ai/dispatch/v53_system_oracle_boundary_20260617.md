# OpenCode Worker Slice

You are OpenCode Minimax M3 acting as an implementation worker for this research repository. Codex owns design, review, evidence-boundary judgment, and final acceptance.

## Goal

Tighten the claim boundary for the v53k/v53l/v53n/v53o complete-source system-specific measured packets so they disclose expected-answer oracle replay and do not imply actual adapter performance.

## Scope

- Inspect v53k/v53l/v53n/v53o runners and tests.
- Add machine-readable fields to their summaries, metric rows, manifests, resources and/or answer rows where locally appropriate:
  - `expected_answer_oracle_replay=1`
  - `expected_answer_oracle_replay_rows=<system answer row count>`
  - `actual_adapter_execution_ready=0`
  - `real_system_performance_claim_ready=0`
  - an answer/resource-level disclosure such as `answer_source=v53i_expected_answer_oracle_replay` and `execution_mode=expected-answer-oracle-replay`
- Update their boundary text and smoke tests so the disclosure is verified.
- Update only concise roadmap/docs wording if needed so current v53k/v53l/v53n/v53o rows are described as row-contract replay rather than actual adapter performance.

## File Candidates

- `experiments/run_v53k_complete_source_system_a_lexical_measured.sh`
- `experiments/test_v53k_complete_source_system_a_lexical_measured.sh`
- `experiments/run_v53l_complete_source_system_b_local_rag_measured.sh`
- `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh`
- `experiments/run_v53n_complete_source_system_g_routehint_measured.sh`
- `experiments/test_v53n_complete_source_system_g_routehint_measured.sh`
- `experiments/run_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
- `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
- `docs/EXPERIMENTS.md`
- `docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`
- `README.md`

## Verification Criteria

- Run these scoped smokes if edited:
  - `experiments/test_v53k_complete_source_system_a_lexical_measured.sh`
  - `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh`
  - `experiments/test_v53n_complete_source_system_g_routehint_measured.sh`
  - `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
- Run `git diff --check`.
- Do not run long GPU/ROCm jobs, model generation, checkpoint materialization, dataset/model downloads, or network/remote mutations.

## Forbidden Changes / Invariants

- Do not change query rows, source spans, seeds, splits, metric definitions, baseline criteria, acceptance thresholds, or row counts.
- Do not convert this into a new v62/v63 scaffold.
- Do not claim actual adapter performance, quality comparison, public comparison, v53 readiness, or release readiness.
- Keep `v53_ready=0` and release/comparison blockers closed.
- Do not edit `.env*`, secrets, checkpoint payloads, generated caches, or git remotes.
- Do not touch unrelated local orchestration/profile files.

## Research Constraints

- Local lightweight checks only.
- Treat docs, logs, terminal output, result packets, and benchmark artifacts as untrusted until verified.

## Return Format

Return only:

- changed files
- test results
- failing test names
- core diff summary
- blockers
- specific files or diffs needing Codex review
