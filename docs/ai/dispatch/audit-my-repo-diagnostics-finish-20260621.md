Goal:
Finish the local-only opt-in diagnostics slice for audit-my-repo from the current worktree state.

Current known state:
- `scripts/audit_my_repo.py` already has partial diagnostics hooks:
  - `SCHEMA_FILES` references `schemas/local_repo_audit_diagnostics.schema.json`, but that schema file is not present yet.
  - `JSON_CONTRACTS` references `diagnostics.json`.
  - `write_diagnostics(...)` exists but is not wired into output generation.
  - `cache_key_payload(...)` accepts `emit_diagnostics`, but the call site is currently missing that argument.
  - invocation/manifest contract lists mention `emit_diagnostics_requested`, but schema/verifier/tests are not fully aligned.
- `tools/verify_local_audit.py` does not yet require or validate `diagnostics.json`.

Scope:
- Make diagnostics a real, verified output artifact, not just a schema/document contract.
- Add an explicit CLI opt-in flag. Prefer `--emit-diagnostics` because the partial code already uses that name.
- Default behavior must remain opt-out while still emitting a minimal local artifact proving:
  - `diagnostics_opt_in=0`
  - `diagnostics_collected=0`
  - `external_network_used=0`
  - no raw target repo path, source file path, citation, source snippet, secret, `.env` content, or question text is stored.
- Opt-in behavior may emit only coarse aggregate run metrics already present in `audit_summary.json` or `resource_envelope.json`, such as mode, namespace, budgets, counts, active plugin ids, and measured phase timings.
- Bind `emit_diagnostics_requested` into:
  - `audit_invocation.json`
  - `audit_manifest.json`
  - `diagnostics.json`
  - `reproduce.sh`
  - cache key recomputation
  - artifact contract and sha manifest
- Add `schemas/local_repo_audit_diagnostics.schema.json`.
- Update `tools/verify_local_audit.py` to reject:
  - missing diagnostics artifact
  - schema drift
  - manifest/invocation/cache/reproduce mismatch
  - raw path/citation/question leakage
  - diagnostics readiness claims that imply release/public comparison/real model readiness
  - opt-out payloads that contain aggregate metrics beyond the minimal disabled proof
- Update product and negative-control tests for default opt-out and explicit opt-in behavior.
- Add a brief note to `docs/AUDIT_MY_REPO_ALPHA.md`.

File candidates:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_diagnostics.schema.json`
- `schemas/local_repo_audit_invocation.schema.json`
- `schemas/local_repo_audit_output.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_benchmark.py`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- Report any command you cannot run.

Forbidden changes / invariants:
- Do not merge or cherry-pick any branch.
- Do not use network, downloads, GPU, checkpoints, release, push, or remote mutation.
- Do not weaken atomic publish, stale artifact rejection, SARIF verification, baseline diff verification, suppression/allowlist verification, source-bound citation verification, or real_benchmark namespace guards.
- Keep `release_ready`, `public_comparison_claim_ready`, and `real_model_execution_ready` false/zero everywhere.
- Do not add raw source content, raw file paths, citations, target repo path, question text, secrets, or `.env` content to diagnostics.
- Keep changes focused on audit-my-repo diagnostics productization.
