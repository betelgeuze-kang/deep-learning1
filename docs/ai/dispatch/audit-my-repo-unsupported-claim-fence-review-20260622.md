# TASK: audit-my-repo unsupported-claim fenced-example review

Review-only slice. Do not edit files.

Goal:
- Review the current changes to `scripts/auditor_plugin_unsupported_claim.py`, `experiments/test_audit_my_repo_negative_controls.sh`, and `docs/AUDIT_MY_REPO_ALPHA.md`.
- Focus on reducing false positives from Markdown fenced examples while preserving real unsupported-claim findings.

Questions:
1. Does the unsupported-claim plugin skip Markdown fenced code/example blocks in `.md` and `.txt` files before matching risky readiness/capability terms?
2. Does it still detect real unsupported claims outside fenced blocks?
3. Do existing negation and claim-boundary exclusions still apply?
4. Does the negative-control fixture cover a fenced example containing `production ready` and `guaranteed` without promoting it to a finding?
5. Does the documentation describe the alpha boundary without claiming full natural-language understanding?

Suggested cheap checks:
- `python3 -m py_compile scripts/auditor_plugin_unsupported_claim.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` smoke with one README that has only negated text plus a fenced positive example, and one README with an actual positive claim outside a fence.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
