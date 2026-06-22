# TASK: audit-my-repo publish rollback review

Scope: review only. Do not edit files.

Goal:
- Inspect the current worktree changes to `scripts/audit_my_repo.py` and `experiments/test_audit_my_repo_negative_controls.sh`.
- Focus on the new rollback behavior when `publish_atomic()` fails after the `latest` pointer has been swapped.

Questions to answer:
- Does `publish_atomic()` restore the previous `latest` pointer on failures after the swap?
- Does it remove only newly-created compatibility symlinks and the failed newly-created run directory?
- Could it delete an existing user result or leave a stale public artifact?
- Does the negative-control test actually prove rollback of `audit_manifest.json`, `sha256sums.txt`, `latest`, and `runs/`?

Constraints:
- Review only, no edits.
- No network, no merge, no push, no release.
- Use cheap local commands only if useful.

Return only:
- changed files: none expected,
- commands run and results,
- findings or “no blocking findings”,
- any minimal patch suggestion if needed.
