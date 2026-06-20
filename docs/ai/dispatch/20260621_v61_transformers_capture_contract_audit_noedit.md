Goal:
Audit the v61 expert FFN Transformers capture contract change without editing files.

Scope:
- Check schema/instance/header consistency for `expert-ffn-forward-parity-rows`.
- Check verifier real-ready guards now require original Transformers capture backend,
  module path, capture artifact hash, original output hash, and independent runtime hash.
- Check fixture-only v61ab rows keep all Transformers capture/output fields empty.

File candidates:
- `schemas/v61_one_token_path.schema.json`
- `v61/one_token_path.json`
- `tools/verify_artifact.py`
- `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`
- `experiments/test_v61_one_token_path_contract.sh`
- `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`
- `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`

Verification criteria:
- No edits.
- Report changed files reviewed, any missing contract synchronization, and any tests
  that should be run before acceptance.

Forbidden changes / invariants:
- Do not change files.
- Do not run network, downloads, checkpoint materialization, GPU/ROCm, or long sweeps.
- Do not change metric definitions, seeds, splits, or readiness thresholds.
