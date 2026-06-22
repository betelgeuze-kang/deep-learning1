# TASK: audit-my-repo benchmark overwrite guard review

Scope: review only the benchmark runner output reuse / overwrite guard slice.

Files to inspect:
- `scripts/audit_my_repo_benchmark.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Focus:
- `prepare_benchmark_output_dir`
- `--overwrite` parser flag
- final `verify_benchmark_output(root, out)` call after writing benchmark artifacts
- negative-control cases around `benchmark_no_overwrite_rc`, `benchmark_unrelated_out`, and overwrite rerun of `benchmark_out`

Questions:
1. Does the runner now refuse to write into an existing non-empty benchmark output without `--overwrite`?
2. Does `--overwrite` replace benchmark-managed artifacts without deleting unrelated output-root files?
3. Does the no-overwrite refusal preserve the existing benchmark manifest/results?
4. Does the runner self-verify the published benchmark output before returning success?
5. Are there likely false failures for fresh benchmark outputs or normal `--verify-existing` use?

Verification already run by Codex:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Forbidden changes:
- Do not merge branches, download anything, run network/GPU jobs, release, push, or rewrite unrelated files.
- Do not broaden into package, PR wrapper, or model research work unless directly required by this benchmark overwrite guard slice.

Return only:
- Findings with file/line references
- Test gaps or residual risk
- Suggested minimal patch, if needed
