Goal:
Audit the current schema-validation work for source-controlled JSON coverage gaps.

Scope:
- Read only. Do not edit files.
- Inspect tracked JSON files outside results/build/cache trees.
- Inspect `tools/validate_json_schemas.py`, `schemas/*.schema.json`, and `scripts/ai-verify.sh`.
- Check whether canonical contract JSON instances are registered for jsonschema validation.
- Treat `opencode.json` and `experiments/fixtures/**` as non-contract config/fixtures unless evidence says otherwise.

Verification criteria:
- Report whether every source-controlled contract JSON has a schema registry entry.
- Report whether `v56/replay_contract.json` is covered.
- Report whether schema validation is invoked by `./scripts/ai-verify.sh`.
- Report whether negative controls cover missing required property, bad type, additional property, schema contract drift, and registry omission.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, long benchmarks, or remote commands.
- Do not change schema semantics or verifier constants.

Output:
Changed files: none
Checks run:
Core findings:
Unresolved risks:
