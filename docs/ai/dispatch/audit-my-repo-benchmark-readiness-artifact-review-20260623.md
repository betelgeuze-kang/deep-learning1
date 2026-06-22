# TASK: audit-my-repo benchmark readiness artifact review

Scope:
- Review the current working-tree changes for the benchmark readiness artifact only.
- Focus files:
  - `scripts/audit_my_repo_benchmark.py`
  - `schemas/local_repo_audit_benchmark_readiness.schema.json`
  - `experiments/test_audit_my_repo_negative_controls.sh`
  - `docs/AUDIT_MY_REPO_ALPHA.md`

Check:
- `benchmark_readiness.json` is emitted before manifest hashing and is included in artifact/schema verification.
- `--verify-existing` recomputes readiness rows from `benchmark_summary.json` and rejects coordinated tampering that updates manifest and sha files.
- Readiness never flips `release_ready`, `public_comparison_claim_ready`, or `real_model_execution_ready`.
- Synthetic benchmark output remains blocked and cannot look like design-partner beta evidence.
- Undersized `real_benchmark` output records real-label basis but keeps beta readiness blocked.

Forbidden:
- Do not merge branches, push, download, run network calls, change benchmark thresholds, or broaden scope beyond this readiness artifact review.

Return only:
- Changed files you inspected.
- Any correctness issues or missing tests.
- Commands run and results.
