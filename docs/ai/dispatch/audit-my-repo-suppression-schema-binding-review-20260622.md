# TASK: audit-my-repo suppression schema sha binding review

Context:
- Active goal: make `audit-my-repo` a design-partner beta candidate without network/GPU/checkpoint/release/push/merge work.
- Codex identified a product integrity gap: `local_repo_audit_suppressions.schema.json` affects allowlist input validation but was not part of audit `schema_sha256s`, manifest verification, or cache-key schema binding.
- The OpenCode compatibility wrapper currently routes to Cursor Composer 2.5.

Scope:
- Review only the suppression schema sha binding slice.
- Relevant files:
  - `scripts/audit_my_repo.py`
  - `tools/verify_local_audit.py`
  - `experiments/test_audit_my_repo_negative_controls.sh`
  - `experiments/test_audit_my_repo_product_entrypoint.sh`
  - `schemas/local_repo_audit_suppressions.schema.json`

Expected behavior:
- New audit outputs include `schemas/local_repo_audit_suppressions.schema.json` in `audit_manifest.json.schema_sha256s`.
- Cache key payload includes the same schema map so suppression input-contract changes alter semantic cache identity.
- `tools/verify_local_audit.py` rejects an audit manifest whose schema map omits or mis-hashes that schema, even if `sha256sums.txt` is updated.
- Product/negative-control tests assert the binding.
- Readiness flags remain blocked; do not change benchmark thresholds or evidence boundaries.

Verification already run before delegation:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh experiments/test_audit_my_repo_product_entrypoint.sh`

Please do:
- Inspect the diff and run a narrow command if useful.
- If you find a real issue, make the smallest fix.
- Otherwise leave code unchanged and report acceptance.

Do not:
- Touch SSD-MoE/v61/model/research code.
- Change beta/release readiness logic, metric thresholds, label semantics, seeds, data splits, or benchmark protocols.
- Download anything, use external network, push, merge, release, or run long/GPU jobs.

Report:
- Changed files, if any.
- Tests run and result.
- Any residual risks.
