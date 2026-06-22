# TASK: audit-my-repo stale artifact layout review

Scope: review only the product slice that hardens local audit output verification against manifest-outside stale artifacts.

Files to inspect:
- `tools/verify_local_audit.py`
- `experiments/test_audit_my_repo_negative_controls.sh`

Focus lines/patterns:
- `verify_bundle_artifact_set`
- `verify_artifact_publish_layout`
- call to `verify_artifact_publish_layout(...)` inside `verify_local_audit`
- negative-control cases around `stale_bundle_artifact.txt`, `stale_audit_link.txt`, and regular-file replacement of `AUDIT_REPORT.md`

Questions to answer:
1. Does the verifier now reject manifest-outside artifacts inside the versioned run bundle that `latest` exposes?
2. Does it reject top-level audit symlinks outside the manifest and stale regular files in compatibility artifact slots?
3. Does it preserve the existing contract that unrelated user files in the output root are not deleted or automatically failed?
4. Are there false failures for staging directories, published roots, or direct `runs/<run_id>` verification?
5. Are the tests meaningful and unlikely to pass if this protection regresses?

Verification already run by Codex:
- `python3 -m py_compile tools/verify_local_audit.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`

Forbidden changes:
- Do not merge branches, download anything, run network/GPU jobs, release, push, or rewrite unrelated files.
- Do not broaden into benchmark/product packaging work unless directly required by this stale-artifact slice.

Return only:
- Findings with file/line references
- Test gaps or residual risk
- Suggested minimal patch, if needed
