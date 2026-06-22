# TASK: audit-my-repo benchmark evaluation JSON contract probe

Scope: review the current working tree changes for the benchmark evaluation JSON product unit only.

Focus files:
- `scripts/audit_my_repo_benchmark.py`
- `schemas/local_repo_audit_benchmark_evaluation.schema.json`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Questions to answer:
- Does `benchmark_evaluation.json` bind TP/FP/FN, precision/recall, P0/P1 metrics, abstain correctness, citation validity, and row-level confusion/citation/abstain evidence?
- Does `--verify-existing` compare `benchmark_evaluation.json` against the CSV artifacts and `benchmark_summary.json`, rather than trusting manifest hashes alone?
- Does the schema keep release/public/model readiness claims false?
- Do tests cover schema validation, CSV/JSON row equivalence, and tampered evaluation JSON rejection after manifest/sha updates?
- Are there meaningful missing negative controls for this slice?

Constraints:
- Do not merge, push, release, download, or run network/GPU work.
- Do not broaden into unrelated audit product areas.
- Prefer review output only. If you make edits, keep them minimal and explain why.

Verification already run by Codex before this probe:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `python3 -m json.tool schemas/local_repo_audit_benchmark_evaluation.schema.json`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only: changed files if any, findings/risks, tests run, and blockers.
