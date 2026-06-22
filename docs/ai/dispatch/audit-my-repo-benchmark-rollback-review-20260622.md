# TASK: audit-my-repo benchmark rollback review

Review-only slice. Do not edit files.

Goal:
- Review benchmark output rollback changes in `scripts/audit_my_repo_benchmark.py`, the benchmark section of `experiments/test_audit_my_repo_negative_controls.sh`, and the benchmark paragraph in `docs/AUDIT_MY_REPO_ALPHA.md`.
- Focus on whether failed benchmark runs leave final output unchanged and do not expose stale/partial managed artifacts.

Questions:
1. Does `--overwrite` move existing benchmark-managed artifacts to a backup before running, and restore them if the benchmark fails after case runs?
2. Does a fresh failed run remove partial managed artifacts such as `case_runs`, `benchmark_manifest.json`, and `benchmark_summary.json`?
3. Are unrelated output-root files still preserved/refused before any benchmark-managed writes?
4. Does success still commit the new benchmark output and clean backup directories?
5. Do tests cover fresh failure and overwrite rollback using `AUDIT_MY_REPO_BENCHMARK_FAIL_AFTER_CASES=1`?

Suggested cheap checks:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` benchmark smoke with one local repo and one label, covering fresh failure and overwrite failure.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
