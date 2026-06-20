Goal:
Audit the v61 artifact column contract migration so schema `x-contract` is the
source for verifier column order.

Scope:
- Read only. Do not edit files.
- Inspect `schemas/v61_one_token_path.schema.json`, `v61/one_token_path.json`,
  `tools/verify_artifact.py`, `tools/validate_json_schemas.py`,
  and `experiments/test_p0_schema_validation_negative_controls.sh`.

Verification criteria:
- Confirm every `x-contract.artifact_contracts` row in the v61 schema declares
  `required_columns`.
- Confirm `tools/verify_artifact.py` derives
  `EXPECTED_V61_REQUIRED_ARTIFACT_COLUMNS` from `V61_ARTIFACT_CONTRACTS` instead
  of a hard-coded Python column dictionary.
- Confirm `tools/validate_json_schemas.py` requires schema `required_columns`
  to be a non-empty unique string list and rejects schema/instance column drift.
- Confirm the negative controls include a v61 schema column drift case for
  `one-token-logits-parity-rows`.
- Confirm claim boundaries are unchanged: this is a contract-source migration,
  not a real model execution, logits parity pass, decode pass, or release claim.

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
