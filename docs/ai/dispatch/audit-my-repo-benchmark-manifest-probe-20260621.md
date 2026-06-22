# TASK: audit-my-repo benchmark manifest probe

Scope: exploration only. Do not edit files.

Goal: identify the smallest runtime/test slice to make `scripts/audit_my_repo_benchmark.py` emit verifiable benchmark artifact provenance.

Focus:
- `scripts/audit_my_repo_benchmark.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Constraints:
- Do not edit files.
- Do not use network, GPU, downloads, checkpoints, release, push, or merge.
- Do not change readiness thresholds.
- Synthetic smoke must not become `real_benchmark`.

Return only:
- recommended artifact names,
- manifest fields,
- hash-manifest strategy,
- two negative controls to add.
