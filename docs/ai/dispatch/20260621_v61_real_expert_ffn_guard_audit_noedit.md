Goal:
Audit the v61 real expert FFN parity guard after Codex changes. Confirm the verifier rejects any real expert FFN pass row unless it binds both original Transformers module output and independent runtime output evidence.

Scope:
No edits. Inspect only the diff and relevant local files:
- tools/verify_artifact.py
- experiments/test_v61_one_token_path_contract.sh
- docs/V61_ONE_TOKEN_PATH_CONTRACT.md
- schemas/v61_one_token_path.schema.json
- v61/one_token_path.json

Verification criteria:
- A fixture-only expert FFN row can remain blocked and may omit original Transformers module output.
- A row with expert_ffn_parity_pass=1 and real_model_execution_ready=1 requires a valid transformers_expert_output_sha256 and independent_runtime_output_sha256.
- The candidate output hash must match the independent runtime output hash.
- The torch reference output hash must match the original Transformers expert output hash.
- Negative controls cover at least the missing Transformers output case.
- Do not run network, downloads, GPU/ROCm, full benchmark sweeps, checkpoint materialization, or remote writes.

Forbidden changes / invariants:
- Do not modify files.
- Do not change milestone status, schemas, acceptance thresholds, seeds, data splits, benchmark protocols, or metric definitions.
- Do not promote fixture evidence to real runtime evidence.

Return only:
Changed files: none
Checks run:
Core findings:
Risks/blockers:
