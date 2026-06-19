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

The verifier also loads the required PM ledgers declared by the contract from
their default paths, so the short command still checks that fixture D/E rows
remain out of measured registry and that real D/E acceptance artifacts remain
blocked until present.

To make the checked sidecars explicit, run:

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

Required artifact shape:

- `model-identity`: `system_id`, `baseline_class`, `model_repository`,
  `model_revision`, `parameter_count_b`, `quantization`,
  `model_artifact_sha256`, `open_weight_license_uri`, `runtime`,
  `runtime_version`, `hardware`, `external_api_used`,
  `non_fixture_declared`
- `answer-citation-raw-output`: `system_id`, `query_id`,
  `same_query_set_id`, `prompt_template_sha256`, `context_budget`,
  `retrieval_budget`, `seed`, `raw_answer`, `raw_citation`,
  `raw_output_sha256`, `generation_transcript_sha256`,
  `non_fixture_declared`
- `resource-evaluator-manifest`: `system_id`, `query_id`, `latency_ms`,
  `peak_memory_mb`, `evaluator_version`, `evaluator_artifact_sha256`,
  `same_query_set_id`, `same_source_manifest_sha256`, `answer_rows_sha256`,
  `citation_rows_sha256`, `fixture_rows`, `measured_registry_candidate`

Raw answer/citation output must be preserved separately from evaluator scores.
Resource rows, evaluator identity, non-fixture declaration, and raw generation
transcript hashes must be present before measured-registry admission; fixtures
remain schema tests only.

Until those fields are present for both D and E, A/B/G/H rows remain internal
v1.0 pre-baseline evidence only.
