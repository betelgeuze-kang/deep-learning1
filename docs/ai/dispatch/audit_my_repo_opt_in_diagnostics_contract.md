Goal:
Add local-only opt-in diagnostic data support to audit-my-repo as a focused productization slice.

Scope:
- Add a CLI flag such as `--emit-diagnostics` with default opt-out behavior.
- Always keep diagnostics local; do not send, upload, or mutate anything outside the audit output bundle.
- Emit a machine-verifiable diagnostics artifact, preferably `diagnostics.json`, as part of the bundle.
- When diagnostics are not opted in, the artifact must prove `diagnostics_opt_in=0`, `diagnostics_collected=0`, `external_network_used=0`, and must not include raw target paths, source file paths, citations, or question text.
- When diagnostics are opted in, the artifact may include coarse run metrics already present in summary/resource envelope, such as mode, namespace, budgets, source/finding counts, phase timings, active plugin ids, and install/first-report success indicators. It still must not include raw source snippets, source file paths, citations, or question text.
- Bind the diagnostics opt-in flag into `audit_invocation.json`, `audit_manifest.json`, `reproduce.sh`, and the cache key.
- Add or update JSON schema coverage for diagnostics if needed.
- Update `tools/verify_local_audit.py` to reject diagnostics drift, raw path/citation/question leakage, readiness claims, and reproduce/cache/invocation/manifest mismatches.
- Update product and negative-control tests for both default opt-out and explicit opt-in behavior.
- Add a small usage note to `docs/AUDIT_MY_REPO_ALPHA.md`.

File candidates:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_*.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_benchmark.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- Report any commands you cannot run.

Forbidden changes / invariants:
- Do not merge or cherry-pick any branch.
- Do not use network, downloads, GPU, checkpoints, release, push, or remote mutation.
- Keep `release_ready`, `public_comparison_claim_ready`, and `real_model_execution_ready` false/zero.
- Do not weaken atomic publish, stale artifact rejection, source-bound citation verification, SARIF verification, baseline diff verification, suppression/allowlist verification, or real_benchmark namespace guards.
- Do not include raw source content, raw file paths, citations, secrets, `.env` content, or question text in diagnostics.
- Keep changes focused on audit-my-repo diagnostics productization.
