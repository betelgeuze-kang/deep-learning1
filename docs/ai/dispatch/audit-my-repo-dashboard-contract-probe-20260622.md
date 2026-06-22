# TASK: audit-my-repo dashboard contract probe

You are Cursor Composer 2.5 through the former OpenCode worker slot. Codex owns final design and acceptance.

Scope: review only these files and do not edit:

- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_dashboard.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Goal: find concrete contract gaps in the new local dashboard artifacts:

- `audit_dashboard.json`
- `AUDIT_DASHBOARD.html`

Check specifically:

- Dashboard artifacts are emitted before `artifact_contract_rows.csv` and `sha256sums.txt`.
- They are included in required artifact verification and schema verification.
- Stale or tampered dashboard JSON/HTML cannot pass verifier after sha updates.
- Dashboard counts are recomputed from `audit_summary.json`, `audit_findings.csv`, and `baseline_diff_summary.json`.
- Readiness flags remain false/0 and automatic accuracy is not claimed.
- Dashboard generation stays deterministic and does not fetch/use network.
- Tests cover product smoke and negative tamper cases.

Allowed cheap verification:

- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py`
- `python3 -m json.tool schemas/local_repo_audit_dashboard.schema.json`
- `bash -n experiments/test_audit_my_repo_product_entrypoint.sh experiments/test_audit_my_repo_negative_controls.sh`

Do not run full `./scripts/ai-verify.sh`.
Do not change files.

Report only:

- Findings with file/line references
- Any command results
- If no findings, say so clearly with residual risk
