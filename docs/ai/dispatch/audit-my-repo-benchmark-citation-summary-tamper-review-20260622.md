Goal:
Review the minimal negative-control for benchmark summary tampering of label citation expectation readiness.

Scope:
- Read only these files:
  - scripts/audit_my_repo_benchmark.py
  - experiments/test_audit_my_repo_negative_controls.sh
  - schemas/local_repo_audit_benchmark_summary.schema.json
- Do not edit files.

File candidates:
- scripts/audit_my_repo_benchmark.py
- experiments/test_audit_my_repo_negative_controls.sh

Verification criteria:
- Confirm whether `--verify-existing` recomputes `label_citation_expectation_requirement_met` from label quality and citation expectation counts.
- Confirm whether a coordinated tamper that sets `benchmark_summary.json` `label_citation_expectation_requirement_met=1` while the citation expectation artifact has unmet rows should be rejected even if benchmark manifest and sha256 manifest are updated.
- Identify the minimal test insertion point.

Forbidden changes / invariants:
- No edits.
- No network, GPU, checkpoint, dataset, release, push, merge, threshold changes, metric redefinition, or readiness promotion.
- Do not run long tests.

Return only:
- changed files: none
- findings
- suggested insertion point
- blockers
