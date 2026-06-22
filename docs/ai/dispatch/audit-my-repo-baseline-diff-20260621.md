# TASK: Finish audit-my-repo baseline diff slice

Goal:
Finish the in-progress `audit-my-repo` baseline comparison feature so it is executable, verifier-checked, and covered by existing product/negative-control tests.

Scope:
- Current branch/worktree only.
- Continue the partial baseline diff implementation already present in:
  - `scripts/audit_my_repo.py`
  - `tools/verify_local_audit.py`
  - `experiments/test_audit_my_repo_product_entrypoint.sh`
  - local repo audit schemas under `schemas/`
  - `docs/AUDIT_MY_REPO_ALPHA.md` if docs need a small usage note
- Add or adjust only focused code/tests needed for:
  - `--baseline <verified audit output dir>`
  - `baseline_diff_rows.csv`
  - `baseline_diff_summary.json`
  - `BASELINE_DIFF.md`
  - manifest/invocation/cache/reproduce binding for baseline path and baseline sha
  - verifier rejection of stale/tampered baseline diff artifacts

File candidates:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `schemas/local_repo_audit_invocation.schema.json`
- `schemas/local_repo_audit_output.schema.json`
- `schemas/local_repo_audit_baseline_diff.schema.json`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Verification criteria:
- `python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_benchmark.py`
- `./experiments/test_audit_my_repo_product_entrypoint.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`
- Do not run long jobs. If full `./scripts/ai-verify.sh` is quick enough, run it; otherwise report that Codex should run it.

Forbidden changes / invariants:
- Do not merge, cherry-pick, push, release, publish, or call external network services.
- Do not download datasets/checkpoints/model weights.
- Do not touch SSD-MoE/v61 research logic except incidental existing verification running.
- Do not change readiness gates to true. `release_ready`, `public_comparison_claim_ready`, and `real_model_execution_ready` must remain false/0.
- Do not weaken atomic publish, stale artifact rejection, source-bound citation verification, SARIF verification, suppression/allowlist verification, or real_benchmark namespace guards.
- Keep changes focused; do not rewrite unrelated product code.

Expected output:
- Changed files summary.
- Test results with exact commands.
- Any blockers or files Codex should inspect closely.
