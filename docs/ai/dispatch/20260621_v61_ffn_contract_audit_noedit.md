Goal:
Audit the v61 expert FFN parity contract change for missing provenance, activation, and independent-comparison fields.

Scope:
- Read only. Do not edit files.
- Inspect `v61/one_token_path.json`, `tools/verify_artifact.py`,
  `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`,
  `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`,
  `experiments/test_v61_one_token_path_contract.sh`, and
  `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`.

Verification criteria:
- Confirm `expert-ffn-forward-parity-rows` now requires model revision,
  config hash, tokenizer revision, shard index hash, full manifest hash,
  RMSNorm payload, router payload, residual input/output hashes,
  Transformers expert output hash, independent runtime output hash, and
  W1/W2/W3 payload hashes.
- Confirm the runner emits those columns for both blocked/default rows and
  local fixture rows.
- Confirm negative controls fail if the RMSNorm payload column is removed.
- Confirm the contract still does not claim real model execution or release.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, long benchmarks, or remote commands.
- Do not alter evidence boundaries, seeds, metrics, or readiness semantics.

Output:
Changed files: none
Checks run:
Core findings:
Unresolved risks:
