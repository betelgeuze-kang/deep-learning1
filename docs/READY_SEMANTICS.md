# Typed Readiness Semantics

The repository must not use a bare `ready=1` style field as a release,
performance, human-review, or real-model claim. Readiness is typed across seven
fields:

```json
{
  "contract_ready": true,
  "fixture_execution_ready": true,
  "real_model_execution_ready": false,
  "heldout_metric_ready": false,
  "human_review_ready": false,
  "independent_reproduction_ready": false,
  "release_ready": false
}
```

The source-controlled contract is `readiness/typed_ready.json`. Verify it with:

```bash
tools/verify_artifact.py typed-readiness readiness/typed_ready.json
```

When the PM ledger exists, compare the source-controlled contract against the
generated rows with:

```bash
tools/verify_artifact.py typed-readiness readiness/typed_ready.json \
  --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv
```

For v61, the required wording is:

- `logical_100b_contract_fixture_ready=1`
- `real_100b_inference_ready=0`

Do not use `100b_moe_run_ready=1` as a real inference, quality, release, or
near-frontier claim.

Rows may set `pm_ledger_required=false` when the typed-readiness boundary is a
source-controlled PR or documentation contract that is not emitted by the
current PM ledger. Those rows are still enforced by
`tools/verify_artifact.py typed-readiness`; they are skipped only for
generated-ledger row matching.

The current source-only rows are:

- `operator_review_return_workflow_contract_ready`
- `pr2_docs_claim_boundary_contract_ready`
