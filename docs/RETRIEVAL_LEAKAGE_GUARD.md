# Retrieval Leakage Guard

Retriever and model-visible inputs must not receive evaluator-only source
locators or expected labels. The source-controlled contract is
`leakage/retrieval_model_visible.json`.

Allowed system surface:

```text
natural language question + searchable corpus
```

The only model/retriever-visible field names allowed by policy are:

- `sanitized_question`
- `opaque_routehint`

Each model/retriever stage must use a subset of that policy allowlist. Non-model
source-bound replay surfaces must declare `allowed_model_visible_fields=["none"]`.
Every forbidden surface must also set `pm_ledger_required=true`; generated PM
evidence must carry the matching `pm_ledger_required=1` row so a source-only
contract cannot silently replace the review ledger.

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

- v53ap source-span replay is a source-bound non-model adapter surface; it has
  no model/retriever-visible input surface and cannot support public comparison
  or performance claims.
  It may report `actual_adapter_execution_ready=1` for deterministic
  source-bound replay, but must keep `allowed_model_visible_fields=["none"]`,
  `real_system_performance_claim_ready=0`, and
  `public_comparison_claim_ready=0`.
- v53aq adapter selection sees only `sanitized_question`, and its
  `selection_forbidden_fields` summary must cover every forbidden alias in this
  contract.
- v54c model-visible generation input sees only `sanitized_question,opaque_routehint`.
- evaluator-only fields stay available for scoring, not for retrieval or generation.

Common aliases for direct source binding are forbidden as well, including
`span_id`, `source_span_row_id`, `source_file_path`, `file_path`, `repo_path`,
`parsed_path`, bare `line`, `start_line`, `end_line`, `parsed_line`,
bare `sha256`, `source_sha256`, `file_sha256`, `case_id`, `source_case_id`,
`source_row_id`,
`source_query_id`, `query_source_id`, `source_binding_id`,
`expected_citation`, `expected_output`, `gold_answer`, `gold_citation`,
`gold_label`, and `target_label`.
