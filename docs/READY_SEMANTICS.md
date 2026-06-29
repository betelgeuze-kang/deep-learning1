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

`readiness/typed_ready.json` also owns the complete ambiguous-ready denylist.
Every misleading flag in that list must have at least one typed replacement row,
and every row's `misleading_ready_flag` must be in the list:

- `100b_moe_run_ready`
- `h10_real_label_promotion_ready`
- `pr2_ready`
- `review_return_ready`
- `v53_ready`
- `v58_ready`
- `v59_ready`
- `v60_ready`
- `v61i_100b_moe_active_sparse_run_ready`

Adding a new bare `*_ready` claim boundary requires adding it to
`policy.ambiguous_ready_flags` and adding a row that spells out all seven typed
readiness fields.

When the PM ledger exists, compare the source-controlled contract against the
generated rows with:

```bash
tools/verify_artifact.py typed-readiness readiness/typed_ready.json \
  --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv
```

For v61, the required wording is:

- `logical_100b_contract_fixture_ready=1`
- `v61i_logical_100b_contract_fixture_ready=1`
- `real_100b_inference_ready=0`

Do not use `100b_moe_run_ready=1` or
`v61i_100b_moe_active_sparse_run_ready=1` as a real inference, quality,
release, or near-frontier claim.

All source-controlled typed readiness rows must also appear in the PM ledger
when `--pm-ledger` is supplied. Source-only skip exceptions are not allowed for
PR #2 normalization, because those exceptions let ambiguous `ready=1` wording
drift away from the replayed claim-boundary artifact.

## PM ready semantic rows (generated/local ledger)

`results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv` is a
generated/local ledger. It is gitignored and is **not** a source of truth.

Source of truth:

- `readiness/typed_ready.json`
- `tools/verify_artifact.py typed-readiness`

When the PM ledger is present locally, it must mirror `typed_ready.json`
(replacement_flag, scope_id, misleading_ready_flag, and the seven readiness
booleans). Retired names must not appear:

- `v53_benchmark_foundation_frozen` (retired; now `v53_benchmark_foundation_contract_ready`)
- `v54_free_running_fixture_ready` (retired; now `v54_minimal_real_model_heldout_ready`)

### Known stale symptom and cleanup

A stale local ledger from before the typed-ready scope rename can fail
`./scripts/ai-verify.sh` even though the tracked source is correct. The observed
stale symptom was:

- v53 replacement flag used the old `..._frozen` name
- v54 replacement flag used the old `..._fixture_ready` name
- v54 `misleading_ready_flag` said `v53_ready` (should be `v54_ready`)
- v54 readiness booleans must mirror the current minimal real-model smoke row
  (`fixture_execution_ready=1`, `real_model_execution_ready=1`,
  `heldout_metric_ready=1`, release-facing flags still `0`)

Cleanup procedure (local only; the ledger stays gitignored and is not committed):

1. Correct the stale rows in
   `results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv` so
   that each row mirrors `readiness/typed_ready.json`. Do not delete the whole
   `gate_001/` directory — it also holds the required D/E ledgers
   (`de_measured_registry_exclusion_rows.csv`, `de_30b70b_acceptance_evidence_rows.csv`).
2. Re-run the mirror check:
   ```bash
   tools/verify_artifact.py typed-readiness readiness/typed_ready.json \
     --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv
   ```
3. Re-run `./scripts/ai-verify.sh`.

### Drift guard

`scripts/test_typed_readiness_pm_ledger_drift.py` is a PR-safe guard (it does not
generate or mutate any evidence). It fails if a retired typed-ready name appears
in tracked source, and — when the local PM ledger is present — verifies it
mirrors `readiness/typed_ready.json` and contains no retired name. If the ledger
is absent (clean CI checkout), the ledger check is skipped.
