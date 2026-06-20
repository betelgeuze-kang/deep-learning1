Goal:
Audit the v61 one-token logits parity contract change for missing max/mean error
and top-k ranking evidence.

Scope:
- Read only. Do not edit files.
- Inspect `v61/one_token_path.json`, `tools/verify_artifact.py`,
  `experiments/test_v61_one_token_path_contract.sh`, and
  `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`.

Verification criteria:
- Confirm `one-token-logits-parity-rows` requires `mean_abs_delta`,
  `top_k_token_count`, `candidate_top_k_token_ids`,
  `reference_top_k_token_ids`, and `top_k_token_ranking_match`.
- Confirm `logits_parity_pass=1` is rejected unless top-1 matches,
  top-k ranking matches, and both max/mean absolute logit error are finite
  and within tolerance.
- Confirm negative controls fail when the mean-error or top-k ranking columns
  are removed.
- Confirm the contract still leaves one-token logits parity blocked and does
  not claim real model execution, 16-token decode readiness, or release.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, long benchmarks, or remote commands.
- Do not alter evidence boundaries, seeds, metrics, readiness semantics, or
  artifact paths.

Output:
Changed files: none
Checks run:
Core findings:
Unresolved risks:
