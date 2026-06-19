Goal:
Audit whether PR #2 split normalization is fully machine-bound at the schema/verifier level.

Scope:
No edits. Inspect only:
- schemas/pr_split.schema.json
- pr_slices/pr2.json
- tools/verify_artifact.py PR split verifier paths
- docs/PR2_SPLIT_PLAN.md if needed

File candidates:
- schemas/pr_split.schema.json
- pr_slices/pr2.json
- tools/verify_artifact.py
- docs/PR2_SPLIT_PLAN.md

Verification criteria:
- Identify any mismatch where verify_artifact.py enforces PR #2 split semantics but the JSON schema still permits drift.
- Pay special attention to required slice IDs/order, merge gates, tests-only merge conditions, non-empty artifacts/commands, PR #2 title/body status wording, and current_status values.
- Return only a concise audit summary with recommended schema/verifier changes.

Forbidden changes / invariants:
- Do not edit files.
- Do not change research design, metrics, seeds, splits, thresholds, or evidence boundaries.
- Do not run network/download/model/checkpoint/GPU jobs.
- Do not push or mutate external state.
