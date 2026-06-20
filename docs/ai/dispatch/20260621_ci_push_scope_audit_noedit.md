Goal:
Audit the CI push-scope contract change without editing files.

Scope:
- Confirm `.github/workflows/ai-verify.yml` still runs `./scripts/ai-verify.sh`
  for pull requests to main, all push events, and manual dispatch.
- Confirm the push trigger is not branch-limited.
- Confirm `third-party-rerun.yml` remains manual-only and was not widened.
- Confirm `experiments/test_p0_ci_workflow_negative_controls.sh` has a negative
  control for branch-limited ai-verify push triggers.

File candidates:
- `.github/workflows/ai-verify.yml`
- `.github/workflows/third-party-rerun.yml`
- `experiments/test_p0_ci_workflow_negative_controls.sh`
- `scripts/ai-verify.sh`

Verification criteria:
- No edits.
- Report files reviewed, contract gaps, and recommended local tests.

Forbidden changes / invariants:
- Do not change files.
- Do not push, open PRs, edit branch protection, or mutate GitHub settings.
- Do not run network, downloads, GPU/ROCm, or long sweeps.
