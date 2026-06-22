# TASK: audit-my-repo unsupported-claim inline-code and negation review

Review-only slice. Do not edit files.

Goal:
- Review the follow-up changes after the fenced-example review.
- Focus only on `scripts/auditor_plugin_unsupported_claim.py`, the unsupported-claim fixtures in `experiments/test_audit_my_repo_negative_controls.sh`, and the parser-boundary paragraph in `docs/AUDIT_MY_REPO_ALPHA.md`.

Questions:
1. Does Markdown inline code such as `` `production ready` `` get masked before unsupported-claim matching in `.md`/`.txt` files?
2. Does one-word negation matching avoid substring suppression, so text like `Innovation note: ... production ready` is still detected?
3. Do multi-word negation phrases such as `must not` and `do not` still work?
4. Do tests cover both inline-code false-positive prevention and real claim detection with a word containing `no` before the risky term?
5. Does the documentation stay within deterministic alpha parser boundaries?

Suggested cheap checks:
- `python3 -m py_compile scripts/auditor_plugin_unsupported_claim.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Optional `/tmp` smoke with one inline-code-only README and one `Innovation note` positive README.

Return only:
- Reviewed files.
- Commands run and results.
- Findings, if any, with file/line references.
- Residual risk or "no blocking findings".
