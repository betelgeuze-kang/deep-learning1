# TASK: audit-my-repo standard JSON findings review

Scope: read-only review. Do not edit files.

Goal: inspect the new standard JSON findings output slice for audit-my-repo.

Files to inspect:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_findings.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Review questions:
- Does `audit_findings.json` carry the same finding rows as `audit_findings.jsonl` and preserve plugin/rule/confidence/citation fields?
- Is it included in artifact contracts, sha256 manifests, schema instance validation, verifier required files, and cache/schema sha binding?
- Does the verifier reject metadata/readiness drift and CSV/standard-JSON drift?
- Are release/public-comparison/model-execution flags still blocked?
- Is there any stale artifact or manifest-outside artifact gap introduced by the new output?

Report only:
- Findings with file/line references
- Missing coverage or blocker
- Whether the slice is consistent with the current audit-my-repo beta-candidate goal
