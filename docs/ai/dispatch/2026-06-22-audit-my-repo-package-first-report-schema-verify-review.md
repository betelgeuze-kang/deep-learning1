TASK: Review package and first-report smoke schema validation in verify-existing paths.

Goal:
- Confirm `scripts/audit_my_repo_package.py --verify-existing` schema-validates `package_manifest.json`.
- Confirm `scripts/audit_my_repo_first_report_smoke.py --verify-existing` schema-validates `first_report_smoke.json`.
- Confirm negative/product tests reject schema-invalid tampering through the product verifier paths.

Scope:
- `scripts/audit_my_repo_package.py`
- `scripts/audit_my_repo_first_report_smoke.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo_package.py scripts/audit_my_repo_first_report_smoke.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh experiments/test_audit_my_repo_product_entrypoint.sh`

Forbidden changes / invariants:
- Do not run network downloads, GPU/checkpoint work, release, push, merge, or external benchmark sweeps.
- Do not alter readiness flags or beta gate thresholds.
- `release_ready`, `public_comparison_claim_ready`, `real_model_execution_ready`, package upload, and fixture-only boundaries must remain false.

Return only:
- Changed files reviewed
- Test results
- Blockers or correctness risks
- Specific diff hunks Codex should inspect
