# D/E 30B/70B Baseline Admission

D/E fixture or schema-test rows must not enter measured registry or public
comparison rows. Real D/E baseline admission requires open-weight evidence,
raw answer/citation output, resource rows, and exact runtime provenance over the
same frozen query/source/evaluator surface.

The source-controlled contract is `baselines/de_30b70b_real.json`.

Verify the contract with:

```bash
tools/verify_artifact.py baseline-admission baselines/de_30b70b_real.json
```

When the PM sidecar exists, compare it against the measured-registry exclusion
ledger:

```bash
tools/verify_artifact.py baseline-admission baselines/de_30b70b_real.json \
  --measured-registry-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/de_measured_registry_exclusion_rows.csv \
  --acceptance-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/de_30b70b_acceptance_evidence_rows.csv
```

Required real evidence fields:

- model repository and exact revision
- quantization
- model artifact hash
- runtime
- prompt template
- context budget
- retrieval budget
- hardware
- seed
- raw answer/citation output
- evaluator version

Until those fields are present for both D and E, A/B/G/H rows remain internal
v1.0 pre-baseline evidence only.
