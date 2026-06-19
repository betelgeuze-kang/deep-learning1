# PR #2 Split Plan

Draft PR #2 must not merge as one review unit. It mixes roadmap text,
v52-v60/v61 scaffold, measured rows, runtime work, and README updates, which
makes claim review and replay validation too broad for one reviewer pass.

The source-controlled split contract is `pr_slices/pr2.json`. Verify it with:

```bash
tools/verify_artifact.py pr-split pr_slices/pr2.json
```

## Required Slices

1. `docs/v1-roadmap`
2. `v50-auditor-correctness`
3. `v52-baseline-registry-contract`
4. `v53-public-repo-source-manifest`
5. `v53-query-instantiation-1000`
6. `v53-system-a-b-g-h-measured`
7. `v54-routehint-generation-contract`
8. `v56-ruler-longbench-expanded`
9. `v58-blind-eval-contract`
10. `v59-one-command-demo`
11. `v61-ssd-moe-runtime-roadmap`

## Merge Policy

Every slice must pass all three merge gates:

- `claim-boundary`
- `replay-artifact`
- `blocker-false-positive`

Tests are useful smoke evidence, but tests-only merge conditions are forbidden.
Each slice must keep allowed claims, blocked claims, and evidence paths explicit.
Ready wording must follow `readiness/typed_ready.json`; bare `ready=1` fields
must not imply real model execution, human review, heldout metrics, independent
reproduction, or release readiness.
v50 auditor wording must follow `audits/v50_public_repo_auditor_correctness.json`;
summary `ready=1` is not mergeable auditor correctness while replay artifacts
are missing, and implicit public refresh is forbidden.
Retriever and model-visible input wording must follow
`leakage/retrieval_model_visible.json`; source locators, direct query/source
bindings, expected behavior, and expected labels are evaluator-only.
D/E baseline wording must follow `baselines/de_30b70b_real.json`; fixture or
schema-test D/E rows cannot enter measured registry or public comparison rows.
v53 benchmark wording must follow `benchmarks/v53_source_bound_freeze.json`;
the 1000-row machine-foundation freeze does not imply human-reviewed quality,
D/E baseline completion, public comparison, or release readiness.
v58 blind-eval wording must follow `v58/blind_eval_real.json`; templates and
intake contracts do not imply real blind-eval completion.
v61 runtime wording must follow `v61/one_token_path.json`; tensor-page,
dtype/quant, and matvec parity evidence do not imply an SSD-resident real model
runtime until one-token logits parity is accepted.

## Title And Body

Recommended title:

```text
Split v1.0 research artifact into claim-bounded review slices
```

Recommended body summary:

```text
This draft PR is not mergeable as one unit. Split by claim boundary so each
reviewer can replay the artifacts without accepting unrelated scaffold. Merge
gates are claim boundary accuracy, replayable output artifacts, and
false-positive blocker closure. Tests are necessary smoke evidence but are not
sufficient merge conditions.
```
