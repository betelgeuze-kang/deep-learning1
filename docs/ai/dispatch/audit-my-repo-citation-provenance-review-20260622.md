# TASK: audit-my-repo citation/rule provenance review

Scope: review only. Do not edit files.

Goal:
- Inspect the current worktree changes in `tools/verify_local_audit.py` and `experiments/test_audit_my_repo_negative_controls.sh`.
- Focus on the new checks for:
  - finding `plugin_rule_ids` duplicate/unknown/multi-language provenance,
  - orphan or unknown `citation_spans.csv` rows not referenced by `audit_findings.csv`,
  - negative-control coverage for those cases.

Questions to answer:
- Could the new verifier reject valid current `audit-my-repo` outputs?
- Could a stale/orphan citation span or multi-plugin language drift still pass?
- Are the new tests too weak because they only trigger unrelated verifier errors?

Constraints:
- Do not merge, push, download, use network, or run long jobs.
- Do not change benchmark protocols, readiness thresholds, or claim boundaries.
- Prefer quick local commands only if useful.

Return only:
- changed files: none expected,
- test commands run and results,
- findings or “no blocking findings”,
- any suggested minimal patch if needed.
