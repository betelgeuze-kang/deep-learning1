# TASK: audit-my-repo package rollback publish review

Review-only slice. Do not edit files.

Goal:
- Review the package publish rollback logic added after the previous review.
- Focus only on `scripts/audit_my_repo_package.py`, the package section of `experiments/test_audit_my_repo_negative_controls.sh`, and the Local Alpha Package paragraph in `docs/AUDIT_MY_REPO_ALPHA.md`.

Questions:
1. If publishing fresh package artifacts fails after one managed file is replaced, does the writer remove partial managed files and clean staging/backup dirs?
2. If `--overwrite` publishing fails after one managed file is replaced, does the writer restore the previous managed artifacts and leave the package verifiable?
3. Does stale `.package_backup.*` or `.package_staging.*` layout get rejected by `--verify-existing`?
4. Are unrelated files still allowed and preserved?
5. Are exit codes still sensible: verifier failures `1`, user/publish errors `2`, package self-verification failure `1`?

Cheap checks:
- `python3 -m py_compile scripts/audit_my_repo_package.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` package rollback smoke using `AUDIT_MY_REPO_PACKAGE_FAIL_AFTER_PUBLISH_COUNT=1`.

Return only:
- Reviewed files.
- Commands run and results.
- Findings with file/line references, if any.
- Residual risk or "no blocking findings".
