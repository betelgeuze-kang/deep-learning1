# TASK: audit-my-repo JS template parser gap probe

Goal:
Assess the smallest product-code slice for improving `audit-my-repo` JavaScript/TypeScript deprecated API detection around template literals.

Scope:
- Inspect `scripts/auditor_plugin_deprecated_api.py`.
- Inspect existing parser tests in `experiments/test_audit_my_repo_negative_controls.sh`.
- Focus on whether executable template interpolation such as `` `${eval(input)}` `` is currently masked as a string and missed.

Please do:
- Do not make code changes unless the fix is tiny and clearly safe.
- Prefer reporting the exact gap, expected behavior, and narrow test cases.
- If you do change files, keep it limited to the deprecated API parser and negative-control fixture.

Forbidden changes / invariants:
- No network, GPU, checkpoint, release, push, or merge.
- Do not change readiness thresholds or promote fixture/synthetic evidence.
- Do not broaden unsupported-claim semantics.
- Keep release_ready, public_comparison_claim_ready, and real_model_execution_ready false/0.

Verification criteria:
- `python3 -m py_compile scripts/auditor_plugin_deprecated_api.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- Any narrower direct parser smoke you run should be local only.

Report:
- Changed files, if any.
- Tests run and result.
- Whether template interpolation is a real false negative today.
- Residual risks.
