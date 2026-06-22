Goal:
Review provenance gaps in the local audit human label-template verifier.

Scope:
- Read only these files:
  - scripts/audit_my_repo_label_template.py
  - experiments/test_audit_my_repo_product_entrypoint.sh
  - schemas/local_repo_audit_label_template.schema.json
  - schemas/local_repo_audit_label_template_manifest.schema.json
- Do not edit files.

File candidates:
- scripts/audit_my_repo_label_template.py
- experiments/test_audit_my_repo_product_entrypoint.sh

Verification criteria:
- Identify manifest fields that should be recomputed by `--verify-existing`, not merely schema-validated.
- Confirm tamper tests should update `label_template_sha256sums.txt` when mutating `label_template_manifest.json` so the verifier must catch semantic/provenance drift.
- Keep label templates template-only: no human label rows, no readiness promotion, no external evidence claims.

Forbidden changes / invariants:
- No edits.
- No network, GPU, checkpoint, dataset, release, push, merge, threshold changes, metric redefinition, or readiness promotion.
- Do not run long tests.

Return only:
- changed files: none
- findings
- suggested verifier checks
- suggested tests
- blockers
