# v58 Real Blind Evaluation Contract

v58 is not complete until real, non-fixture blind responses and human blind
review/adjudication evidence are accepted. The source-controlled contract is
`v58/blind_eval_real.json`.

Verify the contract with:

```bash
tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json
```

When the PM sidecar exists, compare the contract against the generated blocker
ledgers:

```bash
tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json \
  --readiness-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/v58_real_execution_readiness_rows.csv \
  --artifact-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv \
  --template-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv
```

Required systems:

```text
A/B/C/D/E/G/H
```

Required real-execution evidence:

- actual responses over the same frozen query set
- same corpus, context budget, and retrieval budget
- blind identity preservation
- at least two independent blind reviewers
- disagreement and adjudication rows
- unseen repository split
- source-span exactness scored separately
- unsupported/missing abstention scoring
- latency and memory evaluated separately from answer quality

Required artifact shape:

- `v58-blind-response-rows`: `blind_run_id`, `system_blind_id`,
  `query_id`, `answer_text`, `citation_text`, `response_sha256`
- `v58-run-identity-rows`: `blind_run_id`, `system_id`,
  `system_blind_id`, `corpus_id`, `context_budget`, `retrieval_budget`,
  `prompt_template_sha256`
- `v58-human-review-rows`: `blind_run_id`, `query_id`, `reviewer_id`,
  `reviewer_blinded`, `answer_quality_score`, `citation_score`,
  `source_span_exact`, `unsupported_abstain_score`
- `v58d-review-return-intake`: `review_dir`, `accepted_blind_review_rows`,
  `accepted_adjudication_rows`, `inter_rater_rows`, `review_return_ready`
- `v58-sha256-manifest`: `artifact_path`, `sha256`, `bytes`

Human review rows intentionally exclude latency and memory fields. Resource
measurements are accepted through response/resource artifacts and evaluated
separately from answer quality.

Fixtures, templates, or tests-only checks do not close v58.
