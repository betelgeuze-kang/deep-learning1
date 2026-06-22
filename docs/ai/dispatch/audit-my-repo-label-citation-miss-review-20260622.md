Goal:
Review the benchmark test gap for partial human-label citation inputs and supplied-but-unmet citation expectations.

Scope:
- Read only these files:
  - scripts/audit_my_repo_benchmark.py
  - experiments/test_audit_my_repo_negative_controls.sh
  - schemas/local_repo_audit_benchmark_summary.schema.json
  - schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json
- Do not edit files.

File candidates:
- scripts/audit_my_repo_benchmark.py
- experiments/test_audit_my_repo_negative_controls.sh

Verification criteria:
- Confirm whether malformed partial citation expectation inputs should exit 2.
- Confirm whether a real_benchmark run with a wrong expected_span_sha256 should keep label_citation_expectation_requirement_met=0 and design_partner_beta_candidate_ready=0 while preserving release/public/model readiness false.
- Identify minimal negative-control assertions needed.

Forbidden changes / invariants:
- No edits.
- No network, GPU, checkpoint, dataset, release, push, merge, threshold changes, metric redefinition, or readiness promotion.
- Do not run long tests.

Return only:
- changed files: none
- findings
- suggested assertions
- blockers
