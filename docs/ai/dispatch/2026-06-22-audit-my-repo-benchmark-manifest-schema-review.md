TASK: Review the audit-my-repo benchmark manifest schema slice without editing files.

Scope:
- Inspect the current working tree changes related to:
  - `tools/validate_json_schemas.py`
  - `schemas/local_repo_audit_benchmark_manifest.schema.json`
  - `schemas/local_repo_audit_benchmark_summary.schema.json`
  - `schemas/local_repo_audit_benchmark_maintainer_feedback.schema.json`
  - `scripts/audit_my_repo_benchmark.py`
  - `experiments/test_audit_my_repo_negative_controls.sh`
- Confirm `benchmark_manifest.json` has a schema-level contract and negative controls validate it.
- Confirm dynamic sha maps (`artifact_sha256s`, `case_run_manifest_sha256s`) are checked by the local validator.
- Confirm readiness flags and synthetic promotion flags remain blocked.

Forbidden:
- Do not edit files.
- Do not run network, GPU, checkpoint, release, push, merge, or destructive commands.
- Do not relax beta thresholds or evidence boundaries.

Verification budget:
- Prefer read-only inspection and cheap syntax checks only if available.
- Do not run long tests.

Return only:
- files reviewed
- checks run and pass/fail
- missing contract bindings or risks
- readiness/claim-boundary status
