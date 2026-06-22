TASK: Review the audit-my-repo first-report smoke slice.

Context:
- Work from the current main/worktree only.
- Do not merge, cherry-pick, push, release, download, or run network/GPU/checkpoint work.
- This slice should provide executable evidence that a first-time local user can get a verified audit report inside the alpha ten-minute budget.

Scope to inspect:
- `scripts/audit_my_repo_first_report_smoke.py`
- `scripts/audit_my_repo_package.py`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Check specifically:
- The smoke creates only local fixture data and does not use the network.
- It records install/run/verify wall times, exit codes, first report success, time budget status, cache key, run id, and blocked readiness flags.
- It exits 0 only when install, audit, verification, report existence, time budget, and readiness false checks all pass.
- Product smoke executes it and validates the receipt.
- Package manifest binds the new script as a required source and advertises the entrypoint.
- Negative controls cover invalid wall-budget input.

Verification already run by Codex before dispatch:
- `python3 -m py_compile scripts/audit_my_repo_first_report_smoke.py scripts/audit_my_repo_package.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`
- `python3 tools/validate_json_schemas.py`
- `git diff --check`
- `scripts/audit_my_repo_first_report_smoke.py --out <tmp> --max-wall-ms 600000`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only:
- blocking issues, if any
- test commands you ran
- files inspected
- concise diff-risk summary
