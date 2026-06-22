# TASK: audit-my-repo first-report self-verify review

Scope: review only the first-report smoke self-verification slice.

Files to inspect:
- `scripts/audit_my_repo_first_report_smoke.py`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`

Focus:
- receipt write path in `audit_my_repo_first_report_smoke.py`
- `verify_receipt(root, work_dir)` call before returning success
- internal negative-control hook `AUDIT_MY_REPO_FIRST_REPORT_TAMPER_BEFORE_VERIFY`
- test cases named `first_report_self_verify_tamper`

Questions:
1. Does the first-report smoke now self-verify the receipt and audit output before returning success?
2. Does receipt drift before self-verify force exit 1 rather than a successful smoke?
3. Does the normal first-report path still leave a schema-valid receipt and verified audit output?
4. Are readiness flags and offline boundaries still enforced by the self-verifier?
5. Is the env hook acceptably isolated to tests, with no default behavior change?

Verification already run by Codex:
- `python3 -m py_compile scripts/audit_my_repo_first_report_smoke.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Forbidden changes:
- Do not merge branches, download anything, run network/GPU jobs, release, push, or rewrite unrelated files.
- Do not broaden into package, benchmark, or model research work unless directly required by this first-report self-verify slice.

Return only:
- Findings with file/line references
- Test gaps or residual risk
- Suggested minimal patch, if needed
