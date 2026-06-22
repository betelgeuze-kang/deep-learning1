# TASK: audit-my-repo allowlist schema validation review

Context:
- Current goal is to move `audit-my-repo` toward design-partner beta candidate without release/push/merge/network/GPU/checkpoint work.
- OpenCode assignments currently route through `./scripts/ai-worker-opencode.sh` to Cursor composer-2.5.
- Codex added schema validation for local suppression/allowlist files so accepted false-positive handling is contract-bound, not only ad hoc JSON parsing.

Scope:
- Review only the suppression/allowlist schema-validation slice.
- Relevant files:
  - `scripts/audit_my_repo.py`
  - `schemas/local_repo_audit_suppressions.schema.json`
  - `experiments/test_audit_my_repo_negative_controls.sh`
  - `docs/AUDIT_MY_REPO_ALPHA.md`
- Check that invalid allowlist shape fails before suppression is applied, valid allowlist still suppresses exactly the intended finding, `.env`-like allowlist paths stay unread, and no readiness flags are promoted.

Verification already run by Codex before delegation:
- `python3 -m py_compile scripts/audit_my_repo.py scripts/audit_my_repo_package.py scripts/audit_my_repo_first_report_smoke.py scripts/audit_my_repo_benchmark.py`
- `python3 tools/validate_json_schemas.py`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`

Please do:
- Inspect the diff and run a narrow verification if useful.
- If you find a real defect, make the smallest code/test fix.
- Otherwise leave code unchanged and report that the slice looks acceptable.

Do not:
- Touch SSD-MoE/v61/model/research code.
- Change benchmark metric definitions, claim boundaries, readiness flags, seeds, data splits, or evidence thresholds.
- Download anything, access external network, push, merge, release, or run GPU/long jobs.

Report back with:
- Changed files, if any.
- Tests run and results.
- Any blockers or residual risks.
