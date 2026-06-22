TASK: Review the audit-my-repo dashboard artifact slice.

Context:
- Work from the current main/worktree only.
- Do not merge, cherry-pick, push, release, download, or run network/GPU/checkpoint work.
- This slice should add deterministic diffable dashboard artifacts to local audit bundles without weakening existing artifact verification.

Scope to inspect:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_dashboard.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Check specifically:
- Every audit run emits both `audit_dashboard.json` and `AUDIT_DASHBOARD.html`.
- Dashboard JSON binds manifest run/cache identity, summary review counts, baseline diff counts, links, top findings, and blocked readiness flags.
- Dashboard HTML is deterministic companion output with run/cache/readiness metadata and top-finding rows.
- `verify_local_audit.py` rejects stale/tampered dashboard JSON or HTML even if sha manifests are updated.
- Existing atomic publish, quick/full, budget, parser-boundary, benchmark, package, PR wrapper, diagnostics, SARIF, and standard JSON behavior remains intact.

Verification already run by Codex before dispatch:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_package.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`
- `git diff --check`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only:
- blocking issues, if any
- test commands you ran
- files inspected
- concise diff-risk summary
