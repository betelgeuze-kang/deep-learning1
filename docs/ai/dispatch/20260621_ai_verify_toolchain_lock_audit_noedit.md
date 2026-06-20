Goal:
Audit the AI verify toolchain lock contract without editing files.

Scope:
- Confirm `.github/workflows/ai-verify.yml` pins the runner to `ubuntu-24.04`
  while still running `./scripts/ai-verify.sh` on PR, all push events, and
  workflow dispatch.
- Confirm `ci/ai_verify_toolchain.lock.json` records the runner pin, explicit
  empty container digest, disabled HIP/ROCm env, and Python/compiler/CMake
  version command surfaces.
- Confirm `scripts/ai-verify.sh` validates the lock file and workflow runner.
- Confirm `experiments/test_p0_ci_workflow_negative_controls.sh` has negative
  controls for runner drift, branch-limited push drift, and lock runner drift.

File candidates:
- `.github/workflows/ai-verify.yml`
- `ci/ai_verify_toolchain.lock.json`
- `scripts/ai-verify.sh`
- `experiments/test_p0_ci_workflow_negative_controls.sh`

Verification criteria:
- No edits.
- Report files reviewed, contract gaps, and recommended local tests.

Forbidden changes / invariants:
- Do not change files.
- Do not push, open PRs, edit branch protection, or mutate GitHub settings.
- Do not run network, downloads, GPU/ROCm, or long sweeps.
