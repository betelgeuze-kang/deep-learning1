# TASK: audit-my-repo first-report receipt verifier probe

Scope: review the current working tree changes for the first-report smoke receipt product unit only.

Focus files:
- `scripts/audit_my_repo_first_report_smoke.py`
- `schemas/local_repo_audit_first_report_smoke.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`
- `scripts/audit_my_repo_package.py`

Questions to answer:
- Does `first_report_smoke.json` now bind the generated audit manifest, summary, and report by sha256?
- Does `--verify-existing` re-run local audit verification and reject tampered receipt artifact hashes?
- Is the ten-minute first-report evidence still fixture-only and blocked from beta/release/public/model readiness claims?
- Is offline behavior enforced through `external_network_used == 0` in schema, success calculation, and verifier?
- Are there meaningful missing negative controls for this slice?

Constraints:
- Do not merge, push, release, download, or run network/GPU work.
- Do not broaden into unrelated benchmark/audit product areas.
- Prefer review output only. If you make edits, keep them minimal and explain why.

Verification already run by Codex before this probe:
- `python3 -m py_compile scripts/audit_my_repo_first_report_smoke.py scripts/audit_my_repo_package.py`
- `python3 -m json.tool schemas/local_repo_audit_first_report_smoke.schema.json`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`
- first-report smoke create/schema/verify-existing one-off
- `./experiments/test_audit_my_repo_product_entrypoint.sh`

Return only: changed files if any, findings/risks, tests run, and blockers.
