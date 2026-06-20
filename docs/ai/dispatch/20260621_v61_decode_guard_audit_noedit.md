Goal:
Audit the v61 sixteen-token decode raw evidence guard change without editing files.

Scope:
- Confirm `tools/verify_artifact.py` computes decode readiness from raw fields:
  upstream logits artifact hash, prompt hash, decode token count, candidate and
  reference token IDs, candidate/reference text hashes, and mismatch count.
- Confirm `real_model_execution_ready=1` in `sixteen-token-decode-rows`
  requires `decode_parity_pass=1` and the same raw evidence checks.
- Confirm negative coverage exists for token mismatch, bad upstream logits hash,
  and `real_model_execution_ready=1` without `decode_parity_pass=1`.
- Confirm `docs/V61_ONE_TOKEN_PATH_CONTRACT.md` matches verifier behavior.

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
