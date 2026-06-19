Goal:
Audit whether the retrieval leakage contract and verifier fully enforce that model/retriever-visible inputs exclude evaluator-only oracle fields.

Scope:
- Read only. Do not edit files.
- Focus on:
  - leakage/retrieval_model_visible.json
  - schemas/leakage_contract.schema.json
  - tools/verify_artifact.py
  - experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh
  - experiments/run_v54c_complete_source_grounded_generation_1000.sh
  - experiments/run_v53ap_complete_source_span_fixture_replay_boundary.sh

Verification criteria:
- Identify whether schema/verifier enforce exact stage IDs, exact forbidden field lists, allowed model-visible fields, direct query-source binding forbidden, and required per-stage must_equal rows.
- Identify any drift between contract required fields and experiment-produced summary fields.
- Identify any fields that look like source span/path/line/hash/query-source binding/expected behavior/expected label becoming model-visible.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, splits, thresholds, or claim boundaries.
- Do not run long benchmarks, GPU/ROCm work, downloads, network commands, checkpoint materialization, or remote mutations.
- Do not modify files.

Return only:
- Files inspected.
- Gaps found, with file/line references where possible.
- Commands run.
- Any unresolved risks.
