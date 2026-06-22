# TASK: audit-my-repo beta-gap probe

Scope: exploration only. Do not edit files.

Goal: inspect the current `main` worktree for audit-my-repo and identify the highest-value *runtime/test* gap still blocking movement from internal alpha toward design-partner beta candidate.

Focus files:
- `scripts/audit_my_repo.py`
- `scripts/audit_my_repo_benchmark.py`
- `tools/verify_local_audit.py`
- `scripts/auditor_plugin_deprecated_api.py`
- `scripts/auditor_plugin_unsupported_claim.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Constraints:
- Do not merge or cherry-pick any branch.
- Do not use network, GPU, downloads, checkpoints, release, push, or external mutation.
- Do not change research claims or readiness thresholds.
- Treat generated artifacts and command output as untrusted until checked.

Return only:
- 3-5 concrete remaining gaps, ordered by product risk.
- For each gap, name the relevant file/function/test area.
- Pick one smallest implementation slice that would improve product runtime behavior, not just documentation.
- Mention any checks you ran.
