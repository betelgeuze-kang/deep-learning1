# OpenCode Worker Slice: Review-Return Workflow Contract Audit

Goal:
Audit whether `operations/review_return_workflow.json` and its verifier fail-close operator/review-return claims until real human review, adjudication, operator input files, and release/generation evidence are actually supplied and accepted.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `operations/review_return_workflow.json`
- `schemas/review_return_workflow.schema.json`
- `tools/verify_artifact.py`
- `docs/REVIEW_RETURN_WORKFLOW_CONTRACT.md`
- `pr_slices/pr2.json`
- `results/v53s_complete_source_review_return_intake_summary.csv`
- `results/v58d_blind_review_return_intake_summary.csv`
- `results/v61af_checkpoint_warehouse_operator_bundle_summary.csv`
- `results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv`

Verification criteria:
- Identify missing policy fields for accepted human review, adjudication, operator input files, generation, production latency, and release readiness.
- Identify requirement rows that can be flipped to ready/pass without replayable accepted artifacts.
- Identify schema or verifier gaps where summary-only evidence could be promoted into human-reviewed, operator-executed, generation, or release claims.
- Identify PR slice gaps for `operator-review-return-workflow`.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, long benchmark runs, remote writes, or checkpoint payload writes.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete contract/verifier gaps
- Suggested exact fields or checks
- Blockers
