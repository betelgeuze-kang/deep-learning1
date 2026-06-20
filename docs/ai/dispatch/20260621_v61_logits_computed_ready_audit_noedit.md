Goal:
Audit the v61 one-token logits computed-readiness guard change without editing files.

Scope:
- Confirm `tools/verify_artifact.py` now computes one-token logits parity evidence
  through a shared helper instead of relying on row declarations alone.
- Confirm `real_model_execution_ready=1` in `one-token-logits-parity-rows`
  requires `logits_parity_pass=1` and the same raw evidence checks.
- Confirm negative coverage exists for `real_model_execution_ready=1` without
  `logits_parity_pass=1`.
- Confirm `docs/V61_ONE_TOKEN_PATH_CONTRACT.md` matches the verifier behavior.

File candidates:
- `tools/verify_artifact.py`
- `experiments/test_v61_one_token_path_contract.sh`
- `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`

Verification criteria:
- No edits.
- Report changed files reviewed, any missed edge cases, and recommended tests.

Forbidden changes / invariants:
- Do not change files.
- Do not run network, downloads, checkpoint materialization, GPU/ROCm, or long sweeps.
- Do not change metric definitions, seeds, splits, or readiness thresholds.
