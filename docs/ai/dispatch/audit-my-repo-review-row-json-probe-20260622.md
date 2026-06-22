Goal:
Probe the current audit-my-repo artifacts for the narrow product slice "emit schema-validated JSON mirrors for accuracy_rows.csv and citation_correctness_rows.csv".

Scope:
- Read only the relevant current files:
  - scripts/audit_my_repo.py
  - tools/verify_local_audit.py
  - tools/validate_json_schemas.py
  - experiments/test_audit_my_repo_product_entrypoint.sh
  - experiments/test_audit_my_repo_negative_controls.sh
  - docs/AUDIT_MY_REPO_ALPHA.md
- Do not edit files.

File candidates:
- schemas/local_repo_audit_accuracy_rows.schema.json
- schemas/local_repo_audit_citation_correctness_rows.schema.json
- scripts/audit_my_repo.py
- tools/verify_local_audit.py
- experiments/test_audit_my_repo_product_entrypoint.sh
- experiments/test_audit_my_repo_negative_controls.sh

Verification criteria:
- Identify the minimal code/test/schema changes needed so accuracy_rows.json and citation_correctness_rows.json:
  - are emitted next to the CSVs,
  - are listed in artifact contracts and sha manifests,
  - are schema-validated,
  - mirror their CSVs after type normalization,
  - keep automatic_accuracy_claimed=0 and manual review required,
  - are rejected when tampered.

Forbidden changes / invariants:
- No network, GPU, checkpoint, model, dataset, release, push, merge, or benchmark protocol threshold changes.
- Do not change readiness flags; release_ready, public_comparison_claim_ready, and real_model_execution_ready must stay false/0.
- Do not promote synthetic fixtures to real_benchmark.
- Do not claim beta/release readiness.
- Return only: suggested changed files, core contract notes, specific likely tests to update, blockers.
