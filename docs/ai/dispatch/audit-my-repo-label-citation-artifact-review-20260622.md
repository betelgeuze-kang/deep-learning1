Goal:
Review the implemented benchmark artifact for human-label citation expectations.

Scope:
- Read only these files:
  - scripts/audit_my_repo_benchmark.py
  - schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json
  - experiments/test_audit_my_repo_negative_controls.sh
  - docs/AUDIT_MY_REPO_ALPHA.md
- Do not edit files.

File candidates:
- scripts/audit_my_repo_benchmark.py
- schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json
- experiments/test_audit_my_repo_negative_controls.sh
- docs/AUDIT_MY_REPO_ALPHA.md

Verification criteria:
- Confirm the harness writes and verifies both CSV and JSON artifacts for label citation expectations.
- Confirm labels without expected citation fields remain valid and are recorded as citation_unbound, not failures.
- Confirm readiness flags remain false and synthetic smoke cannot become real_benchmark evidence.
- Confirm schema validation and negative-control coverage include the new artifact.
- Identify any missing tamper/drift tests, schema mismatch, or blocker.

Forbidden changes / invariants:
- No edits.
- No network, GPU, checkpoint, dataset, release, push, merge, threshold changes, metric redefinition, or readiness promotion.
- Do not run long tests.

Return only:
- changed files: none
- findings
- test results if any
- blockers
- specific files or diffs needing Codex review
