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
12. `operator-review-return-workflow`
13. `docs-readme-pr2-cleanup`

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
are missing. The v50 artifact schema, row-count floor, replay commands, and
sha256 manifest binding are explicit, but implicit public refresh is forbidden.
v52 baseline wording must follow `baselines/v52_adapter_guard.json`;
System C's 7B-14B local response packet is not a quality claim, and D/E
measured registry admission remains blocked until real pinned evidence validates.
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
Operator/review-return wording must follow
`operations/review_return_workflow.json`; review templates, operator work
orders, dry-run bundles, and fixture mechanics do not imply accepted human
review, adjudication, real generation, or release readiness.
v61 runtime wording must follow `v61/one_token_path.json`; tensor-page,
dtype/quant, and matvec parity evidence do not imply an SSD-resident real model
runtime until one-token logits parity is accepted.
README and PR-body wording must follow the `docs-readme-pr2-cleanup` slice:
reviewers should be pointed to declarative pipeline/contracts instead of a giant
v61 entrypoint dump, and scaffold/runtime-admission evidence must not be promoted
into actual generation, production, comparison, or release claims.

## Title And Body

Recommended title:

```text
Split PR #2 into v1.0 claim-boundary slices
```

Recommended body summary:

```text
This draft PR is not mergeable as one unit. It mixes v50 auditor correctness,
v52 baseline intake, v53/v54 query and generation contracts, v58 blind-eval
protocol, v59 one-command replay, v61 checkpoint/runtime scaffolding,
operator/review-return workflow, and README/documentation cleanup.

Split it into claim-bounded PRs so each reviewer can replay the artifacts
without accepting unrelated scaffold. Merge gates are claim boundary accuracy,
replayable output artifacts, and false-positive blocker closure; tests are
necessary smoke evidence but are not sufficient merge conditions.

v50 artifact schema is now explicit, but auditor correctness remains blocked
until the required row artifacts and sha256 manifest are present and
replay-checkable without implicit public refresh.

Current v61 state: checkpoint identity, page-hash, runtime-admission, and
operator-bundle scaffolds are documented, but actual generation, one-token
logits parity, production latency, near-frontier quality, and release claims
remain blocked.

Typed readiness, retrieval leakage, and D/E 30B/70B real-baseline admission
remain separate blocker surfaces.
```

Full draft: [PR2_REWRITE_DRAFT.md](PR2_REWRITE_DRAFT.md).
