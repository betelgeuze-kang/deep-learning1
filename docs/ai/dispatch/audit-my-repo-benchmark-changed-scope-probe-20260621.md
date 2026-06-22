# TASK: audit-my-repo benchmark changed-file scope probe

Scope: exploration only. Do not edit files.

Goal: inspect the current worktree and identify the smallest safe implementation path for letting `scripts/audit_my_repo_benchmark.py` evaluate a case using audit-my-repo's `--changed-files-from` option.

Focus files:
- `scripts/audit_my_repo_benchmark.py`
- `scripts/audit_my_repo.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Constraints:
- Do not edit files.
- Do not run network, GPU, downloads, checkpoint operations, release, push, merge, or long benchmark sweeps.
- Do not change readiness thresholds or claim release readiness.
- Keep synthetic smoke out of `real_benchmark`.

Return only:
- exact functions/sections to update,
- the label field shape you recommend,
- 2-3 tests that should prove it,
- any risk around rerun/cache semantics.
