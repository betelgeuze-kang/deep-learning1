# Operator Review-Return Workflow Contract

`operations/review_return_workflow.json` keeps review-return and operator
logistics separate from real human review, adjudication, generation acceptance,
and release readiness.

Verify the contract with:

```bash
tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json \
  --v53s-summary results/v53s_complete_source_review_return_intake_summary.csv \
  --v58d-summary results/v58d_blind_review_return_intake_summary.csv \
  --v61af-summary results/v61af_checkpoint_warehouse_operator_bundle_summary.csv \
  --v61hv-summary results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv
```

Each `current_status=pass` requirement must have a non-empty `summary_checks`
list and replayable summary evidence. When explicit summary paths are not
passed, the verifier attempts to load the requirement `evidence_path`; if the
summary evidence is missing, the check fails instead of silently accepting a
summary-only claim.

The verifier pins the exact blocker summary checks for each requirement. A
contract edit cannot promote accepted human review, adjudication, operator
returns, generation, production latency, near-frontier quality, public
comparison, or release readiness by changing an expected `0` to `1`.

Allowed wording:

- review-return intake contracts and templates exist
- operator bundles and dry-run work orders exist
- no-replay operator scaffolding exists

Blocked wording:

- accepted human review
- accepted adjudication
- real blind-eval completion
- real operator return execution
- actual model generation
- release readiness
