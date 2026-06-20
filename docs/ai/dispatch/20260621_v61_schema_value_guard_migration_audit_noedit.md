Goal:
Audit the v61 schema metadata migration for artifact value checks and runtime readiness guards.

Scope:
Read only. Do not edit files. Inspect:
- schemas/v61_one_token_path.schema.json
- tools/verify_artifact.py
- tools/validate_json_schemas.py
- experiments/test_p0_schema_validation_negative_controls.sh
- experiments/test_v61_one_token_path_contract.sh
- v61/one_token_path.json

Verification criteria:
- `artifact_value_checks`, `real_model_execution_pass_milestones`, and `blocked_runtime_forbidden_ready_fields` are declared in schema `x-contract`.
- `tools/verify_artifact.py` derives those values from `V61_SCHEMA_CONTRACT` and does not retain a duplicate hard-coded Python copy of the migrated lists/maps.
- `tools/validate_json_schemas.py` validates the new `x-contract` metadata for known artifact ids, known required columns, unique milestone references, and string values.
- Negative controls cover malformed `artifact_value_checks` metadata.
- Existing claim boundaries remain unchanged: no fixture row is promoted to real model execution, logits parity, decode parity, release readiness, or SSD-resident runtime readiness.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, checkpoint materialization, full benchmark sweeps, or remote writes.
- Do not change milestone status, acceptance thresholds, metric definitions, seeds, data splits, artifact paths, or evidence semantics.

Return only:
Changed files: none
Checks run:
Core findings:
Risks/blockers:
