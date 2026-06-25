# CI lanes: what runs where

This repo verifies on three lanes. Only GPU work truly needs the self-hosted
runner; the deterministic bulk runs on ephemeral GitHub-hosted runners, so
web-based development does not depend on a local self-hosted runner.

| Lane | Workflow / job | Runner | Triggers | Scope |
|---|---|---|---|---|
| Fast PR gate | `ai-verify.yml` -> `pr-safe-verify` | GitHub-hosted `ubuntu-latest` | pull_request | static verifiers + JSON/schema + Python reference smokes + C++ build smoke |
| Offline suite | `offline-suite.yml` -> `offline-suite` (10-shard matrix) | GitHub-hosted `ubuntu-latest` | pull_request, push to `main`, manual | the deterministic, hardware-free `experiments/test_*.sh` (~272 tests), sharded in parallel |
| GPU / full evidence | `ai-verify.yml` -> `ai-verify.sh` | **self-hosted** | push to `main`, manual | full `./scripts/ai-verify.sh` over accumulated `results/`, incl. GPU/HIP tests |

## What is web-progressable (no self-hosted runner)

- Everything verified by `pr-safe-verify` and `offline-suite`: contracts,
  schemas, verifiers, the staging/preflight tools, and the ~272 deterministic
  experiment tests (no network calls, no accelerators).
- GitHub-hosted runners have internet, so even public-repo fetch experiments can
  run there if needed (they are not part of the default offline suite to keep it
  hermetic and fast).

## What still needs the self-hosted runner

- The 33 GPU/HIP/ROCm/CUDA/NVMe tests (e.g. v09 GPU backend speed gates).
- The full `ai-verify.sh` evidence run that depends on accumulated `results/`.

## Running the offline suite locally

```bash
scripts/run_offline_suite.sh --list           # show selected deterministic tests
scripts/run_offline_suite.sh --shard 1/10      # run one shard
scripts/run_offline_suite.sh                   # run the whole offline suite (slow)
```

A test is excluded from the offline suite when it (or a `run_*.sh` it
references) mentions GPU/accelerator or NVMe hardware. The `offline-suite.yml`
lane runs on pull requests as a **non-required (informational) signal** and on
push to `main`; once shard timing is confirmed it can be promoted to a required
status check on PRs to `main`.
