# TASK: audit-my-repo alpha package manifest review

Scope: read-only review. Do not edit files.

Goal: inspect the new local alpha package slice for audit-my-repo.

Files to inspect:
- `scripts/audit_my_repo_package.py`
- `schemas/local_repo_audit_package_manifest.schema.json`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Review questions:
- Does the package command bind a pinned alpha version, source sha256s, schema sha256s, changelog sha256, and blocked readiness flags?
- Does `--verify-existing` reject stale source hashes, tampered changelog, tampered sha manifest, and readiness flag drift?
- Do tests cover creation, schema validation, overwrite protection, changelog tamper, readiness tamper, and stale source sha tamper?
- Is there any release/upload/network/GPU/checkpoint behavior or claim boundary drift?

Report only:
- Findings with file/line references
- Missing test coverage or blocker
- Whether the slice appears consistent with the current audit-my-repo alpha goal
