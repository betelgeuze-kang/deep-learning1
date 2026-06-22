# TASK: audit-my-repo first-report smoke cleanup review

Review-only slice. Do not edit files.

Goal:
- Review first-report smoke cleanup changes in `scripts/audit_my_repo_first_report_smoke.py`, `experiments/test_audit_my_repo_product_entrypoint.sh`, `experiments/test_audit_my_repo_negative_controls.sh`, and `docs/AUDIT_MY_REPO_ALPHA.md`.
- Focus on whether failed self-verification leaves no managed smoke artifacts in a user-specified `--out` directory while successful runs still verify.

Questions:
1. Does a failed user-specified first-report run remove `first_report_smoke.json`, `audit_out/`, and `fixture_repo/`?
2. Does a successful user-specified first-report run still keep those managed artifacts and pass `--verify-existing`?
3. Does the auto-temp path still clean up unless `--keep` is passed?
4. Are existing non-empty `--out` directories still refused before writes?
5. Do product and negative-control tests assert cleanup after `AUDIT_MY_REPO_FIRST_REPORT_TAMPER_BEFORE_VERIFY=1`?

Suggested cheap checks:
- `python3 -m py_compile scripts/audit_my_repo_first_report_smoke.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` smoke for success and tampered self-verification failure.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
