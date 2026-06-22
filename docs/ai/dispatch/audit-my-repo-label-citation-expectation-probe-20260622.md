Goal:
Probe the benchmark harness for the narrow product slice "optional human-label citation expectations".

Scope:
- Read only these files:
  - scripts/audit_my_repo_benchmark.py
  - schemas/local_repo_audit_benchmark_labels.schema.json
  - schemas/local_repo_audit_benchmark_evaluation.schema.json
  - schemas/local_repo_audit_benchmark_summary.schema.json
  - experiments/test_audit_my_repo_negative_controls.sh
  - docs/AUDIT_MY_REPO_ALPHA.md
- Do not edit files.

File candidates:
- scripts/audit_my_repo_benchmark.py
- schemas/local_repo_audit_benchmark_labels.schema.json
- schemas/local_repo_audit_benchmark_evaluation.schema.json
- experiments/test_audit_my_repo_negative_controls.sh

Verification criteria:
- Identify the minimal places to add optional label fields such as expected_line_start, expected_line_end, and expected_span_sha256.
- The feature should record whether matched findings satisfy the human-provided citation expectation without changing benchmark thresholds.
- Synthetic smoke must remain synthetic and must not make beta/release readiness true.
- Existing labels without those optional fields must continue to work.

Forbidden changes / invariants:
- No network, GPU, checkpoint, dataset, release, push, merge, threshold changes, metric redefinition, or readiness promotion.
- Do not change product readiness flags to true.
- Return only: suggested changed files, expected row/schema fields, test cases, blockers.
