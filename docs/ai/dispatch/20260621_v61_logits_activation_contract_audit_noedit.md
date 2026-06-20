Goal:
Audit the v61 one-token logits parity contract for same-token, same-router-top-k,
and layer activation trace evidence.

Scope:
- Read only. Do not edit files.
- Inspect `schemas/v61_one_token_path.schema.json`, `v61/one_token_path.json`,
  `tools/verify_artifact.py`, `experiments/test_v61_one_token_path_contract.sh`,
  and `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`.

Verification criteria:
- Confirm `one-token-logits-parity-rows` now requires `token_id`,
  `router_top_k`, `layer_activation_trace_sha256`, and
  `layer_activation_trace_rows` in both schema source and JSON instance.
- Confirm `logits_parity_pass=1` is rejected when activation trace hash is
  missing, router top-k is not a positive integer, activation trace row count
  is not positive, or token ID is missing.
- Confirm existing max/mean error and top-k ranking guards remain intact.
- Confirm negative controls cover both column removal and pass-row activation
  trace omission.
- Confirm this does not open one-token logits parity, 16-token decode, real
  model execution, or release claims.

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
