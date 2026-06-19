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

The source-controlled policy also pins these fail-closed gates:

- `real_execution_ready=false`
- `human_blind_review_ready=false`
- `inter_rater_rows_ready=false`
- `v58_full_blind_eval_ready=false`
- `release_ready=false`
- `required_real_response_systems=A/B/C/D/E/G/H`
- `required_independent_reviewers_per_response=2`
- `blind_identity_required_until_adjudication=true`
- `adjudication_required_for_disagreement=true`
- `unseen_repository_split_required=true`
- `source_span_exactness_separate_score=true`
- `unsupported_abstention_separate_score=true`
- `latency_memory_quality_separated=true`

Required artifact shape:

- `v58-blind-response-rows`: `blind_run_id`, `system_blind_id`,
  `query_id`, `answer_text`, `citation_text`, `response_sha256`;
  minimum 3500 rows
- `v58-run-identity-rows`: `blind_run_id`, `system_id`,
  `system_blind_id`, `corpus_id`, `context_budget`, `retrieval_budget`,
  `prompt_template_sha256`; minimum 7 rows
- `v58-query-split-rows`: `query_id`, `repo_id`, `split_name`,
  `unseen_repository`, `frozen_query_packet_sha256`,
  `source_manifest_sha256`; minimum 500 rows
- `v58-resource-rows`: `blind_run_id`, `system_blind_id`, `query_id`,
  `latency_ms`, `peak_memory_mb`, `tokens_per_second`, `resource_sha256`;
  minimum 3500 rows
- `v58-human-review-rows`: `blind_run_id`, `system_blind_id`, `query_id`,
  `response_sha256`, `reviewer_id`, `reviewer_blinded`,
  `reviewer_independent`, `conflict_disclosure_sha256`,
  `answer_quality_score`, `citation_score`, `source_span_exact`,
  `unsupported_abstain_score`; minimum 7000 rows
- `v58-adjudication-rows`: `blind_run_id`, `system_blind_id`, `query_id`,
  `response_sha256`, `reviewer_a_id`, `reviewer_b_id`, `disagreement_type`,
  `adjudicator_id`, `adjudicated_answer_quality_score`,
  `adjudicated_citation_score`, `adjudicated_source_span_exact`,
  `adjudicated_unsupported_abstain_score`; minimum 3500 rows
- `v58d-review-return-intake`: `review_dir`, `accepted_blind_review_rows`,
  `accepted_adjudication_rows`, `inter_rater_rows`, `review_return_ready`;
  minimum 1 row
- `v58-sha256-manifest`: `artifact_path`, `sha256`, `bytes`; minimum 10 rows

Human review and adjudication rows intentionally exclude latency and memory
fields. Resource measurements are accepted through the dedicated
`v58-resource-rows` artifact and evaluated separately from answer quality.
Review rows bind to a specific blind response and system_blind_id, declare
reviewer independence, and record a conflict disclosure hash.
Human review and adjudication artifacts validate through
`V58D_BLIND_REVIEW_RETURN_DIR=<REVIEW_RETURN_DIR> ./experiments/test_v58d_blind_review_return_intake.sh`;
they are not accepted through a deferred or tests-only note.

Fixtures, templates, or tests-only checks do not close v58.
