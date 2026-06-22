# TASK: audit-my-repo benchmark repo snapshot contract probe

Scope: review the current working tree changes for the benchmark repo snapshot product unit only.

Focus files:
- `scripts/audit_my_repo_benchmark.py`
- `schemas/local_repo_audit_benchmark_summary.schema.json`
- `schemas/local_repo_audit_benchmark_manifest.schema.json`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Questions to answer:
- Does `benchmark_repo_snapshots.csv` really bind each case to a clean git HEAD/status without emitting raw git status path names?
- Does `--verify-existing` recompute and reject stale or tampered snapshot rows, not just trust sha manifests?
- Does the beta readiness gate require repo snapshot locking for real human-label benchmarks while keeping synthetic readiness false?
- Are there missing tests for malformed expected HEAD, mismatched expected HEAD, tampered snapshot artifact, or real benchmark locked snapshot sub-gate?

Constraints:
- Do not merge, push, download, release, or run network/GPU work.
- Do not broaden into unrelated audit product areas.
- Prefer review output only. If you make edits, keep them minimal and explain exactly why.

Verification already run by Codex before this probe:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `python3 -m json.tool schemas/local_repo_audit_benchmark_summary.schema.json`
- `python3 -m json.tool schemas/local_repo_audit_benchmark_manifest.schema.json`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only: changed files if any, findings/risks, tests run, and blockers.
