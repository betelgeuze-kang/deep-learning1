Goal:
Complete the audit-my-repo baseline comparison slice already started in this worktree.

Scope:
- Finish the local-only `--baseline <verified audit output>` product path.
- Ensure outputs include `baseline_diff_rows.csv`, `baseline_diff_summary.json`, and `BASELINE_DIFF.md`.
- Bind baseline path/hash into `audit_invocation.json`, `audit_manifest.json`, `reproduce.sh`, and the cache key.
- Update verifier coverage so baseline diff rows/summary/dashboard cannot drift from current and baseline findings.
- Update product and negative-control tests for baseline/no-baseline behavior.

File candidates:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_*.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_benchmark.py`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- Report any failures you cannot fix.

Forbidden changes / invariants:
- Do not merge or cherry-pick any branch.
- Do not use network, downloads, GPU, checkpoints, release, push, or remote mutation.
- Keep `release_ready`, `public_comparison_claim_ready`, and `real_model_execution_ready` false/zero.
- Do not change research metrics, seeds, benchmark thresholds, or evidence boundaries.
- Keep changes focused on audit-my-repo baseline diff/product verification.
