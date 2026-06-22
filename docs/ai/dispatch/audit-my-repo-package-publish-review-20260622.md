# TASK: audit-my-repo package publish hardening review

Review-only slice. Do not edit files.

Goal:
- Check the current diff for `scripts/audit_my_repo_package.py`, `experiments/test_audit_my_repo_negative_controls.sh`, and `docs/AUDIT_MY_REPO_ALPHA.md`.
- Focus on whether package artifact publishing now avoids exposing failed/stale package outputs while preserving unrelated user files.

Scope:
- Current main working tree only.
- Do not merge, cherry-pick, push, download, or run network commands.
- Do not run long benchmarks or GPU work.

Review questions:
1. Does `audit_my_repo_package.py` self-verify staged package artifacts before publishing and verify the final output after publish?
2. Does the verifier reject stale package-managed artifacts outside `package_sha256s.txt` without rejecting unrelated files such as `sentinel.txt`?
3. Are readiness flags still pinned false and tamper detection still enforced?
4. Do the new negative controls exercise stale verification, stale pre-publish refusal, and self-verification failure?
5. Are there any likely regressions in exit-code behavior or overwrite behavior?

Suggested cheap checks:
- `python3 -m py_compile scripts/audit_my_repo_package.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optionally run a tiny package create/verify smoke in `/tmp`.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
