# v53 Source-Bound Benchmark Freeze Contract

The v1.0 machine foundation benchmark is frozen by
`benchmarks/v53_source_bound_freeze.json`.

Verify the contract with:

```bash
tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json
```

When current summaries and ledgers exist, compare the contract against them:

```bash
tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json \
  --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv \
  --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv \
  --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv \
  --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv \
  --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv
```

Accepted machine-foundation evidence:

- 10 pinned public repositories
- 1000 source-span-bound query rows
- 1000 source-span rows with binding audit pass
- 160 negative/abstain rows, including unsupported, missing-specific, and doc-code conflict controls
- answer/citation/resource evaluator rows separated
- A/B/G/H on the same frozen query hash as an internal pre-baseline run
- sanitized-question-only adapter selection for v53aq

Blocked claims:

- human-reviewed correctness
- public A/B/G/H comparison
- D/E 30B/70B replacement or public baseline comparison
- v53 final release readiness
