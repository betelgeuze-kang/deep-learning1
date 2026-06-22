TASK: Review the new audit-my-repo human label template slice only.

Context:
- Current goal is audit-my-repo design-partner beta candidate progress from current main.
- Do not merge branches, push, download, run network work, GPU work, releases, or broad refactors.
- The new slice adds:
  - scripts/audit_my_repo_label_template.py
  - schemas/local_repo_audit_label_template*.schema.json
  - product/negative-control tests for label template generation and tamper rejection
  - docs/package entrypoint references

Review focus:
- Does the label template writer ever delete or overwrite existing user files without --overwrite?
- Can template-only rows be mistaken for human labels or readiness evidence?
- Does self-verification catch tampered JSON/sha/manifest drift?
- Are source/citation bindings adequate for later human labels without making beta/readiness claims?
- Any shell/Python syntax or test-contract bug visible in this slice.

Return only:
- Findings with file/line references
- Any failing command and short output
- Suggested minimal patch, if needed
