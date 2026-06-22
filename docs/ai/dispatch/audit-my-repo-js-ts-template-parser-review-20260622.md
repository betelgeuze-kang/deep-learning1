# TASK: audit-my-repo JS/TS template literal parser review

Review-only slice. Do not edit files.

Goal:
- Review the current changes to `scripts/auditor_plugin_deprecated_api.py`, `experiments/test_audit_my_repo_negative_controls.sh`, and `docs/AUDIT_MY_REPO_ALPHA.md`.
- Focus on JavaScript/TypeScript lexical parsing of template literals for deprecated API detection.

Questions:
1. Does the parser still mask comments, quoted strings, regex literals, and template literal text?
2. Does it now preserve executable `${...}` template expressions so `eval(input)` inside a TypeScript template expression can be cited?
3. Do negative controls prevent literal template text such as `` `eval(input)` `` from becoming a finding?
4. Do positive controls assert a source-bound `.ts` citation on the executable template expression line?
5. Are docs aligned with the implementation without overclaiming production parser completeness?

Suggested cheap checks:
- `python3 -m py_compile scripts/auditor_plugin_deprecated_api.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` audit smoke with one `.ts` file containing both literal template text and `${eval(input)}`.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
