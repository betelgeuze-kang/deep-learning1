# Retrieval Leakage Guard

Retriever and model-visible inputs must not receive evaluator-only source
locators or expected labels. The source-controlled contract is
`leakage/retrieval_model_visible.json`.

Allowed system surface:

```text
natural language question + searchable corpus
```

Forbidden model/retriever inputs:

- source span ID
- source path
- source line
- source file hash
- query ID and direct source row binding
- expected behavior
- expected label

Verify the contract with:

```bash
tools/verify_artifact.py leakage leakage/retrieval_model_visible.json
```

When generated evidence exists, compare it against the PM ledger with:

```bash
tools/verify_artifact.py leakage leakage/retrieval_model_visible.json \
  --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv
```

Current stage expectations:

- v53aq adapter selection sees only `sanitized_question`.
- v54c model-visible generation input sees only `sanitized_question,opaque_routehint`.
- evaluator-only fields stay available for scoring, not for retrieval or generation.
