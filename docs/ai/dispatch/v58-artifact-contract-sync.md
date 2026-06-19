# OpenCode Worker Slice

You are OpenCode Minimax M3 acting as an implementation worker for this research repository. Codex owns design, review, evidence-boundary judgment, and final acceptance.

## Goal

Tighten the v58 real blind-eval artifact contract so actual v58 execution cannot pass with review rows detached from responses, missing adjudication rows, missing unseen-split rows, or resource metrics mixed into answer-quality scoring.

## Scope

Update the source-controlled contract, verifier constants, docs, and PM/v59e generated artifact/template lists to add these v58 real blind-eval artifacts:

- `v58-query-split-rows`
- `v58-resource-rows`
- `v58-adjudication-rows`

Also strengthen `v58-human-review-rows` so review rows bind to a specific blind response/system, require reviewer independence/conflict disclosure, and still exclude resource columns.

## File Candidates

- `v58/blind_eval_real.json`
- `docs/V58_REAL_BLIND_EVAL_CONTRACT.md`
- `tools/verify_artifact.py`
- `experiments/run_v1_0_pm_pr_claim_slice_gate.sh`
- `experiments/test_v59e_one_command_pm_foundation_demo.sh`
- `experiments/test_v60_architecture_challenge_release_contract.sh`
- `experiments/test_v1_0_pm_pr_claim_slice_gate.sh`
- relevant README/PR docs only if they have exact v58 artifact counts that must be updated

## Required Artifact Shapes

Use these exact new artifact IDs in the v58 real-blind-eval artifact order:

1. `v58-blind-response-rows`
2. `v58-run-identity-rows`
3. `v58-query-split-rows`
4. `v58-resource-rows`
5. `v58-human-review-rows`
6. `v58-adjudication-rows`
7. `v58d-review-return-intake`
8. `v58-sha256-manifest`

Required columns:

- `v58-query-split-rows`: `query_id`, `repo_id`, `split_name`, `unseen_repository`, `frozen_query_packet_sha256`, `source_manifest_sha256`
- `v58-resource-rows`: `blind_run_id`, `system_blind_id`, `query_id`, `latency_ms`, `peak_memory_mb`, `tokens_per_second`, `resource_sha256`
- strengthened `v58-human-review-rows`: `blind_run_id`, `system_blind_id`, `query_id`, `response_sha256`, `reviewer_id`, `reviewer_blinded`, `reviewer_independent`, `conflict_disclosure_sha256`, `answer_quality_score`, `citation_score`, `source_span_exact`, `unsupported_abstain_score`
- `v58-adjudication-rows`: `blind_run_id`, `system_blind_id`, `query_id`, `response_sha256`, `reviewer_a_id`, `reviewer_b_id`, `disagreement_type`, `adjudicator_id`, `adjudicated_answer_quality_score`, `adjudicated_citation_score`, `adjudicated_source_span_exact`, `adjudicated_unsupported_abstain_score`

## Verification Criteria

- `python3 -m json.tool v58/blind_eval_real.json >/dev/null`
- `python3 -m py_compile tools/verify_artifact.py`
- `tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json`
- `tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json --readiness-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/v58_real_execution_readiness_rows.csv --artifact-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv --template-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv`
- `./scripts/ai-verify.sh`

## Forbidden Changes / Invariants

- Do not claim v58 is actually complete.
- Keep `policy.real_execution_ready=false`.
- Do not fabricate real blind responses, reviews, adjudications, resource metrics, or unseen split evidence.
- Do not run downloads, network fetches, model generation, checkpoint materialization, GPU/ROCm jobs, or remote git operations.
- Do not change seeds, splits, metric definitions, readiness semantics, or acceptance thresholds beyond requiring the new artifact shapes.
- Do not read or print `.env`, `.env.*`, `*.env`, or `*.env.*`.

## Return Format

Return only:

- changed files
- test results
- failing test names
- core diff summary
- blockers
- specific files or diffs needing Codex review
