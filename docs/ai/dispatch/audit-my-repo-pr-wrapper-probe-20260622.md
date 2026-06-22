# TASK: audit-my-repo PR wrapper contract probe

You are Cursor Composer 2.5 through the former OpenCode worker slot. Codex owns final design and acceptance.

Scope: review only these files and do not edit:

- `scripts/audit_my_repo_pr.sh`
- `scripts/audit_my_repo.py` changed-files handling and reproduce command
- `experiments/test_audit_my_repo_product_entrypoint.sh` PR wrapper block
- `scripts/audit_my_repo_package.py`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Goal: find concrete contract gaps for the new local PR/diff wrapper.

Check specifically:

- It must not fetch, push, release, download, or contact the network.
- It must require local `--base-ref` and use local `--head-ref` default safely.
- It must preserve the generated changed-files input so `reproduce.sh` remains valid.
- It must reject explicit `--changed-files-from`.
- It must avoid writing inside the audited repo before the core tool can reject bad `--out`.
- It must not delete or overwrite existing audit results without explicit core-tool behavior.
- Product tests should cover one successful PR-scoped run and user-correctable failures.
- Package manifest and docs should bind the new entrypoint.

Allowed cheap verification:

- `bash -n scripts/audit_my_repo_pr.sh experiments/test_audit_my_repo_product_entrypoint.sh`
- `python3 -m py_compile scripts/audit_my_repo_package.py`

Do not run full `./scripts/ai-verify.sh`.
Do not change files.

Report only:

- Findings with file/line references
- Any command results
- If no findings, say so clearly with residual risk
