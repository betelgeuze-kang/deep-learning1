TASK: Review the audit-my-repo benchmark label-intake provenance change.

Scope:
- Inspect `scripts/audit_my_repo_benchmark.py`.
- Inspect `schemas/local_repo_audit_benchmark_manifest.schema.json`.
- Inspect the relevant label-intake benchmark assertions in:
  - `experiments/test_audit_my_repo_product_entrypoint.sh`
  - `experiments/test_audit_my_repo_negative_controls.sh`
  - `docs/AUDIT_MY_REPO_ALPHA.md`
  - `scripts/audit_my_repo_package.py`

Questions:
- Does `--label-intake` verify the intake bundle before consuming `benchmark_labels.jsonl`?
- Does `benchmark_manifest.json` bind label source kind, intake output path, intake manifest sha, and intake sha-manifest sha?
- Does `--verify-existing` reject stale/tampered intake bundle provenance, while direct `--labels` binds empty intake shas?
- Do tests cover both direct-label and label-intake paths without promoting synthetic/template-only labels to real benchmark evidence?

Forbidden:
- Do not merge branches, push, download, run network access, or change research metrics/thresholds.
- Do not broaden the goal or alter readiness gates.

Return only:
- Changed files if any.
- Test commands run and results.
- Findings/blockers with exact file references.
- If no issue, say so clearly.
