# TASK: audit-my-repo semantic summary review

Scope: review only. Do not edit files.

Goal:
- Inspect current worktree changes related to `audit_semantic_summary.json`.
- Focus files:
  - `scripts/audit_my_repo.py`
  - `tools/verify_local_audit.py`
  - `scripts/audit_my_repo_benchmark.py`
  - `schemas/local_repo_audit_semantic_summary.schema.json`
  - `experiments/test_audit_my_repo_negative_controls.sh`
  - `experiments/test_audit_my_repo_product_entrypoint.sh`

Questions:
- Does the semantic summary avoid timing/run-id fields and capture stable meaningful result artifacts?
- Does the verifier recompute artifact sha256s and the semantic result sha instead of trusting the JSON?
- Does benchmark rerun consistency now use the core audit semantic result when available?
- Do the tests prove same-input rerun equality and different-question inequality?

Constraints:
- Review only, no edits.
- No network, merge, push, release, or long jobs.

Return only:
- changed files: none expected,
- commands run and results,
- findings or “no blocking findings”,
- minimal patch suggestion if needed.
