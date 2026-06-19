# TASK: v53aq sanitized-question propagation audit

Goal: audit downstream artifacts/tests for stale v53aq leakage-era assumptions after the v53aq runner/test changed to sanitized-question-only selection.

Scope:
- Search only first. Do not edit files unless explicitly needed to produce a minimal patch.
- Candidate paths: `experiments/run_v53t*`, `experiments/test_v53t*`, `experiments/run_v10_h10*`, `experiments/test_v10_h10*`, `experiments/run_v59e*`, `experiments/test_v59e*`, `experiments/run_v60*`, `experiments/test_v60*`, `README.md`, `docs/EXPERIMENTS.md`, relevant v53/v54 docs.
- Look for stale values/claims:
  - `answer_hash_match_rows=3713`, `citation_location_match_rows=3713`, `source_span_id_match_rows=1858`
  - `wrong_answer_rows=287`, `coherent_wrong_key_rows=287`
  - per-system old values `713`, `367`, `1000`, `497` when tied to v53aq metrics
  - `selection_allowed_fields=question`
  - `query-text-only-local-adapter`
  - adapter trace expecting `selection_question_text_used=1`
  - public/performance wording that implies leakage-era quality.
- New v53aq boundary should be:
  - total `answer_hash_match_rows=84`
  - total `citation_location_match_rows=84`
  - total `source_span_id_match_rows=28`
  - total `wrong_answer_rows=3916`
  - total `coherent_wrong_key_rows=3916`
  - per A/B/G/H `answer_hash_match_rows=21`, `source_span_id_match_rows=7`, `wrong_answer_rows=979`, `coherent_wrong_key_rows=979`
  - `selection_allowed_fields=sanitized_question`
  - `selection_sanitized_question_only=1`
  - `source_locator_in_question_removed_rows=4000`

Return only:
- files inspected
- stale matches found, with line references
- whether a patch is recommended
- if you edit, list exact files and verification command/output

Do not run long benchmarks, downloads, network operations, GPU jobs, or mutate external systems.
