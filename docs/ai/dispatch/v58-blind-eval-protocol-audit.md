# OpenCode Worker Slice: v58 Blind Eval Protocol Audit

Goal:
Audit whether the v58 blind-eval contract fail-closes the real execution requirements: A/B/C/D/E/G/H real responses, same corpus/context/retrieval budgets, blind identity, two independent reviewers, disagreement/adjudication, unseen split, source-span exactness, unsupported abstention, and separate latency/memory rows.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `v58/blind_eval_real.json`
- `schemas/v58_blind_eval.schema.json`
- `tools/verify_artifact.py`
- `docs/V58_REAL_BLIND_EVAL_CONTRACT.md`
- `experiments/run_v58c_blind_response_evidence_intake.sh`
- `experiments/test_v58c_blind_response_evidence_intake.sh`
- `experiments/run_v58d_blind_review_return_intake.sh`
- `experiments/test_v58d_blind_review_return_intake.sh`
- `pr_slices/pr2.json`

Verification criteria:
- Identify missing real-response systems or artifact columns.
- Identify missing reviewer/adjudication/disagreement constraints.
- Identify whether latency/memory are separated from answer quality.
- Identify verifier gaps where template/fixture rows could look like blind eval completion.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, long benchmark runs, or human-review fabrication.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, leakage controls, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete contract/verifier gaps
- Suggested exact fields or checks
- Blockers
