TASK: Review the audit-my-repo benchmark verify-existing schema validation slice.

Goal:
- Confirm `scripts/audit_my_repo_benchmark.py --verify-existing` now schema-validates benchmark JSON artifacts, not only the shell test harness.

Scope:
- `scripts/audit_my_repo_benchmark.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`

Forbidden changes / invariants:
- Do not run network downloads, GPU/checkpoint work, release, push, merge, or full external benchmark sweeps.
- Do not alter metric thresholds, beta gate counts, or readiness flags.
- `release_ready`, `public_comparison_claim_ready`, `real_model_execution_ready`, and synthetic promotion flags must remain false.

Return only:
- Changed files reviewed
- Test results
- Blockers or correctness risks
- Specific diff hunks Codex should inspect
