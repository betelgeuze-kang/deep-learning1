# Pipeline Migration Plan

This repository has outgrown one-shell-script-per-gate maintenance. The current v52-v61 surface behaves like a small workflow engine implemented as many shell scripts with embedded Python. The migration target is a declarative pipeline layer that keeps research evidence replayable while reducing copy-forward drift.

## Target Layout

```text
src/          C++ core
runtime/      SSD / GPU / checkpoint runtime
evaluation/   evaluator implementations
benchmarks/   query sets and split definitions
schemas/      versioned JSON schemas
pipelines/    declarative pipeline definitions
tools/        pipeline runner, artifact verifier, manifest builder
artifacts/    small signed summaries only
```

## Migration Rules

- Existing `experiments/run_*.sh` scripts remain the source of truth until their stages are explicitly migrated.
- New pipeline files may call shell stages as adapters, but each adapter must declare inputs, outputs, ready fields, claim boundaries, and blocker semantics.
- Pipeline readiness must distinguish contract, fixture execution, real model execution, heldout metrics, human review, independent reproduction, and release readiness.
- Downstream stages must not infer broad readiness from a copied upstream `ready=1`; they must reference typed fields and artifact hashes.
- Model-visible inputs must be declared separately from evaluator/provenance-only fields.
- Large generated artifacts stay out of git; pipeline manifests should carry hashes and small summaries only.

## First Migration Slice

This slice adds:

- `schemas/pipeline.schema.json`: minimal versioned pipeline contract.
- `pipelines/v52.yaml`, `pipelines/v53.yaml`, `pipelines/v58.yaml`, `pipelines/v61.yaml`: JSON-compatible YAML seed definitions that wrap current shell entrypoints.
- `tools/build_manifest.py`: deterministic sha256 manifest builder.
- `tools/verify_artifact.py`: manifest and pipeline contract verifier.
- `tools/run_pipeline.py`: local dry-run/adapter runner for declared stages.

The seed pipelines are intentionally adapter-based. They are a stable inventory and verification surface, not a claim that the shell workflow has already been removed.

## Current Applied Slice

- `experiments/run_v53j_complete_source_ah_answer_citation_resource_intake.sh`, `experiments/run_v53k_complete_source_system_a_lexical_measured.sh`, and `experiments/run_v53l_complete_source_system_b_local_rag_measured.sh` now import shared CSV/hash/copy helpers from `tools/pipeline_lib.py`.
- `pipelines/v53.yaml` declares the v53i -> v53j -> v53k -> v53l path, with v53k/v53l explicitly bounded as `expected_answer_oracle_replay=1` and `actual_adapter_execution_ready=0`.
- `pipelines/v61.yaml` declares the v61aa tensor-slice verifier before v61ab tile parity, so the v61 runtime path no longer has an implicit missing stage edge.
- `tools/verify_artifact.py pipeline ...` now rejects unknown, self-referential, or forward `requires` edges.
- `pr_slices/pr2.json` and `docs/PR2_SPLIT_PLAN.md` pin the draft PR #2 split contract, title/body rewrite, required claim-boundary slices, and tests-only merge-condition ban.
- `audits/v50_public_repo_auditor_correctness.json` and `docs/V50_AUDITOR_CORRECTNESS_CONTRACT.md` pin the v50 auditor-correctness blocker: summary `ready=1` is not mergeable unless row artifacts and sha256 manifest are replayable, and implicit public refresh is forbidden.
- `readiness/typed_ready.json` and `docs/READY_SEMANTICS.md` pin typed readiness semantics and forbid ambiguous `ready=1` wording from implying real model, review, metric, or release readiness.
- `leakage/retrieval_model_visible.json` and `docs/RETRIEVAL_LEAKAGE_GUARD.md` pin retriever/model-visible leakage rules so source locators, query-source bindings, expected behavior, and expected labels stay evaluator-only.
- `baselines/v52_adapter_guard.json` and `docs/V52_ADAPTER_GUARD_CONTRACT.md` pin the v52 C/7B actual response-packet boundary and D/E measured-registry blockers.
- `baselines/de_30b70b_real.json` and `docs/DE_30B70B_BASELINE_ADMISSION.md` pin D/E real-baseline admission rules and keep fixture/schema D/E rows out of measured registry/public comparison claims.
- `benchmarks/v53_source_bound_freeze.json` and `docs/V53_SOURCE_BENCHMARK_FREEZE_CONTRACT.md` pin the v53 1000-row source-bound benchmark freeze and separate machine foundation readiness from human review, D/E baselines, public comparison, and release readiness.
- `v58/blind_eval_real.json` and `docs/V58_REAL_BLIND_EVAL_CONTRACT.md` pin real blind-eval requirements and keep v58 blocked until non-fixture responses, review, adjudication, score, and resource evidence are accepted.
- `v61/one_token_path.json` and `docs/V61_ONE_TOKEN_PATH_CONTRACT.md` pin the v61 one-token runtime milestone order and prevent tensor/tile parity from being promoted into an SSD-resident real model runtime claim.
- `operations/review_return_workflow.json` and `docs/REVIEW_RETURN_WORKFLOW_CONTRACT.md` pin review-return/operator workflow boundaries so templates, dry-run operator bundles, fixtures, and no-replay scaffolds cannot imply human review, adjudication, generation acceptance, or release readiness.

## Exit Criteria For Replacing Shell Workflow

1. Every active v52-v61 gate has a stage entry with declared inputs, outputs, ready fields, blocker fields, and claim boundary.
2. Common CSV/hash/copy/summary logic is moved into Python library functions.
3. Pipeline runner can replay a selected stage and verify output manifests without relying on undocumented local state.
4. Existing shell scripts become thin compatibility adapters or are retired in small PRs.
5. PRs are split by claim boundary rather than by accumulated scaffold history.
