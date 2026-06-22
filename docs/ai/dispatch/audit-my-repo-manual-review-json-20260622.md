# TASK: audit-my-repo manual review queue JSON contract

Goal:
Add a schema-validated JSON artifact for the existing `manual_review_queue.csv` so the alpha product remains human-review-queue centered and machine-readable.

Scope:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `tools/validate_json_schemas.py` if schema registration is needed
- `schemas/local_repo_audit_manual_review_queue.schema.json` or similar
- product/negative tests only as needed

Expected behavior:
- Audit runs still emit `manual_review_queue.csv`.
- Add `manual_review_queue.json` with schema version, tool version, claim boundary, readiness flags false/0, row count, and rows matching the CSV exactly.
- The verifier must reject JSON/CSV drift, schema drift, missing artifact sha binding, or any auto-promoted/manual-review-disabled row.
- No automatic accuracy, release, public comparison, or real model readiness claims.

Forbidden changes / invariants:
- No network, GPU, checkpoint, release, push, or merge.
- Do not change beta/readiness thresholds.
- Do not promote fixture/synthetic evidence.
- Do not remove the existing CSV.

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh experiments/test_audit_my_repo_product_entrypoint.sh`
- Run a focused product/negative test if practical.

Report:
- Changed files.
- Tests run and result.
- Residual risks.
