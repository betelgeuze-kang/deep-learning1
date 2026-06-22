TASK: Review verify-existing schema validation and stale staging cleanup.

Goal:
- Confirm package and first-report smoke `--verify-existing` paths schema-validate their JSON artifacts.
- Confirm successful audit publish removes the public `.staging` directory.
- Confirm `tools/verify_local_audit.py` rejects a stale public `.staging` directory.

Scope:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `scripts/audit_my_repo_package.py`
- `scripts/audit_my_repo_first_report_smoke.py`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_package.py scripts/audit_my_repo_first_report_smoke.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`

Forbidden changes / invariants:
- Do not run network downloads, GPU/checkpoint work, release, push, merge, or external benchmark sweeps.
- Do not change metric thresholds or readiness flags.
- `release_ready`, `public_comparison_claim_ready`, `real_model_execution_ready`, package upload flags, and fixture-only boundaries must stay false.

Return only:
- Changed files reviewed
- Test results
- Blockers or correctness risks
- Specific diff hunks Codex should inspect
