TASK: Review the local audit benchmark standard JSON findings validity slice.

Context:
- Work from current main/worktree only.
- Do not merge, cherry-pick, push, release, download, or run network/GPU/checkpoint work.
- This slice should make `scripts/audit_my_repo_benchmark.py` record `audit_findings.json` validity as first-class benchmark evidence.

Scope to inspect:
- `scripts/audit_my_repo_benchmark.py`
- `schemas/local_repo_audit_benchmark_summary.schema.json`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Check specifically:
- Per-case `benchmark_run_metrics.csv` records standard JSON findings checked/valid rows and invalid reasons.
- `benchmark_summary.json` exposes checked/valid counts and a real-label-only requirement flag.
- `design_partner_beta_candidate_ready` requires the standard JSON findings requirement but release/public comparison/model flags remain false.
- `--verify-existing` detects drift between case `audit_findings.json`, `audit_findings.csv`, run metrics, and summary.
- Synthetic benchmark output cannot satisfy beta gates, while undersized real benchmark can satisfy the standard JSON sub-gate without becoming beta-ready.

Verification already run by Codex before dispatch:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `git diff --check`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only:
- blocking issues, if any
- test commands you ran
- files inspected
- concise diff-risk summary
