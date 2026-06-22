# TASK: audit-my-repo benchmark stale artifact layout review

Scope: review only the benchmark-output stale artifact hardening slice.

Files to inspect:
- `scripts/audit_my_repo_benchmark.py`
- `experiments/test_audit_my_repo_negative_controls.sh`

Focus:
- `verify_benchmark_artifact_layout`
- its call inside `verify_benchmark_output`
- negative-control cases around:
  - `stale_benchmark_artifact.txt`
  - `case_runs/stale_case`
  - `case_runs/fixture_case/latest/stale_case_artifact.txt`

Questions:
1. Does benchmark verification now reject manifest-outside top-level benchmark artifacts?
2. Does it reject case run directories not listed in `benchmark_manifest.json.case_ids`?
3. Does the case bundle stale test correctly target the exposed local-audit bundle, rather than unrelated user-preserved files at the case output root?
4. Does this preserve the local audit contract that unrelated regular files at an audit output root may be preserved?
5. Are there obvious false failures for normal benchmark outputs?

Verification already run by Codex:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Forbidden changes:
- Do not merge branches, download anything, run network/GPU jobs, release, push, or rewrite unrelated files.
- Do not broaden into package, PR wrapper, or model research work unless directly required by this benchmark stale-artifact slice.

Return only:
- Findings with file/line references
- Test gaps or residual risk
- Suggested minimal patch, if needed
