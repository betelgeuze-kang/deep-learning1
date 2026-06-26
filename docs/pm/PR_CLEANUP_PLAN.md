# PR Cleanup Plan

This plan records the read-only GitHub state checked on 2026-06-25 and keeps
external tracker mutation out of local verification.

## PR #5

- URL: https://github.com/betelgeuze-kang/deep-learning1/pull/5
- Title: Draft: harden v50 auditor correctness replay contract
- State observed: open
- Draft flag observed: false
- Head branch: `pr2-slice-v50-auditor-correctness`
- Base branch: `main`
- Files reported by GitHub:
  - `audits/v50_public_repo_auditor_correctness.json`
  - `docs/V50_AUDITOR_CORRECTNESS_CONTRACT.md`
  - `experiments/run_v50_public_repo_auditor_3repo.sh`
  - `experiments/test_v50_public_repo_auditor_3repo.sh`
  - `schemas/v50_auditor_correctness.schema.json`

Recommended action: A plus B.

Merge or rebase only the durable v50 contract/schema/test changes that remain
needed on `main`, then convert missing public-fetch artifacts and external
auditor correctness evidence into an evidence blocker issue. Do not merge any
claim that implies real auditor correctness readiness until pinned public fetch
artifacts and sha256-bound rows are replayable.

## PR #10

- URL: https://github.com/betelgeuze-kang/deep-learning1/pull/10
- Title: Draft: keep v56 expanded benchmark replay blocked
- State observed: open
- Draft flag observed: true
- Head branch: `pr2-slice-v56-ruler-longbench-expanded`
- Base branch: `main`
- Files reported by GitHub:
  - `experiments/run_v56_ruler_longbench_expanded_contract.sh`
  - `experiments/run_v56b_ruler_longbench_expanded_scale.sh`
  - `experiments/test_v56_ruler_longbench_expanded_contract.sh`
  - `experiments/test_v56b_ruler_longbench_expanded_scale.sh`
  - `v56/replay_contract.json`

Recommended action: A plus B.

Merge or rebase only the durable v56 replay contract and fail-closed tests that
remain useful on `main`, then track official source/evaluator hashes, raw
prediction/result rows, replay manifests, and independent verification as an
evidence blocker issue. Keep expanded benchmark readiness and leaderboard claims
blocked until real replay artifacts exist.

## Local Observations

- `audits/v50_public_repo_auditor_correctness.json` is not present on current
  local `main`.
- `v56/replay_contract.json` is not present on current local `main`.
- Open issue list returned no visible open issues in the read-only check.
- `gh pr list` returned `HTTP 401: Bad credentials`; do not rely on it for a
  complete PR inventory until GitHub authentication is repaired.

## External Mutation Boundary

Do not close, label, merge, or comment on PRs without explicit human approval.
Do not create GitHub issues automatically without explicit human approval.
If the owner chooses the superseded-close path, apply the prepared
`superseded` label before closing the PR.
The exact superseded-close command block is recorded in
`docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md` and verified by
`tools/verify_pr_cleanup_disposition_commands.py`.
