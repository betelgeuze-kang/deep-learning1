# TASK: audit-my-repo benchmark labels JSON contract probe

Scope: review the current working tree changes for the benchmark human-label JSON product unit only.

Focus files:
- `scripts/audit_my_repo_benchmark.py`
- `schemas/local_repo_audit_benchmark_labels.schema.json`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Questions to answer:
- Does `benchmark_labels.json` bind scored human-label rows with case, plugin/rule/file, expected value, abstain expectation, maintainer marker, and TP/FP/FN/TN outcome?
- Does `--verify-existing` validate `benchmark_labels.json` against the schema and compare it to `benchmark_labels.csv`?
- Is `benchmark_labels.csv` still recomputed from labels + case audit outputs, so coordinated JSON/CSV tamper is rejected?
- Do tests cover schema validation, JSON/CSV row equivalence, and tampered labels JSON rejection after manifest/sha updates?
- Are there meaningful missing negative controls for this slice?

Constraints:
- Do not merge, push, release, download, or run network/GPU work.
- Do not broaden into unrelated audit product areas.
- Prefer review output only. If you make edits, keep them minimal and explain why.

Verification already run by Codex before this probe:
- `python3 -m py_compile scripts/audit_my_repo_benchmark.py`
- `python3 -m json.tool schemas/local_repo_audit_benchmark_labels.schema.json`
- `bash -n experiments/test_audit_my_repo_negative_controls.sh`
- `./experiments/test_audit_my_repo_negative_controls.sh`

Return only: changed files if any, findings/risks, tests run, and blockers.
