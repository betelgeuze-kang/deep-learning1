# TASK: audit-my-repo benchmark allowlist scoring review

Context:
- Active goal: move `audit-my-repo` toward design-partner beta candidate.
- Scope is local audit product only. No network/GPU/checkpoint/release/push/merge work.
- The product docs say suppressed findings remain in audit artifacts but benchmark scoring ignores them as active positives.

Codex change to review:
- `scripts/audit_my_repo_benchmark.py`
  - Case labels may now include `allowlist` or `suppression_file`.
  - The path is normalized relative to the labels file, `.env`-like paths are rejected, conflicting values inside one case are rejected.
  - `run_audit()` forwards the case allowlist to `audit_my_repo.sh --allowlist`.
  - `verify_benchmark_output()` now compares `benchmark_findings.csv/json` against unsuppressed case audit findings only, matching `evaluate_case()`.
- `experiments/test_audit_my_repo_negative_controls.sh`
  - Adds an integration fixture where a deprecated finding is suppressed by a case allowlist.
  - Asserts the case audit still emits the suppressed finding and `suppressed_findings.csv`.
  - Asserts benchmark scoring treats an `expected: absent` label as `TN`, with no TP/FP/FN and no unmatched suppressed FP.
  - Asserts `benchmark_findings.csv` contains only active unsuppressed findings.

Please do:
- Inspect the diff for this slice.
- Run a narrow verification if useful.
- If you find a real defect, make the smallest fix.
- Otherwise leave code unchanged and report acceptance.

Watch for:
- Readiness flags and beta thresholds must not change.
- Suppressed findings must remain in the per-case audit artifacts.
- Suppressed findings must not count as active benchmark positives.
- Do not broaden benchmark evidence or promote synthetic/fixture data.

Report:
- Changed files, if any.
- Tests run and result.
- Residual risks.
