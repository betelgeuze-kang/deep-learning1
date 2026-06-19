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
System C's 7B-14B local response packet now declares required answer, citation,
resource, transcript, and sha256 manifest row artifacts, but it is not a
quality claim. D/E measured registry admission remains blocked until real
pinned evidence validates.
Retriever and model-visible input wording must follow
`leakage/retrieval_model_visible.json`; source locators, direct query/source
bindings, expected behavior, and expected labels are evaluator-only.
D/E baseline wording must follow `baselines/de_30b70b_real.json`; fixture or
schema-test D/E rows cannot enter measured registry or public comparison rows.
The v52 slice must include the measured-registry exclusion ledger and acceptance
blocker ledger as replay artifacts, not optional sidecars. The exclusion ledger
must exact-count `required_real_evidence_field_count=11`,
`missing_real_evidence_field_count=11`, and
`all_required_real_evidence_missing=1` for both D and E before admission remains
blocked. The acceptance blocker ledger must keep model identity, raw
answer/citation output, and resource/evaluator manifests as separate blocker
rows for both D and E.
v53 benchmark wording must follow `benchmarks/v53_source_bound_freeze.json`;
the 1000-row machine-foundation freeze does not imply human-reviewed quality,
D/E baseline completion, public comparison, or release readiness. The v53
verifier pins exact summary checks for repo counts, 1000 query/span rows,
negative controls, answer/citation/resource evaluator separation, A/B/G/H
same-query evidence, sanitized-question-only adapter selection, and the v1 exit
ledger.
v54 grounded-generation wording must follow `v54/grounded_generation_contract.json`;
the recommended answer, citation, unsupported-claim, abstain, resource, guard,
and sha256 outputs are replay artifacts, while raw prompt stuffing, real model
generation, human-reviewed quality, public comparison, and release claims remain
blocked.
v58 blind-eval wording must follow `v58/blind_eval_real.json`; A/B/C/D/E/G/H
real responses require 500 rows per system, not just 3500 total rows. Two
independent blinded reviewers from distinct reviewer pools, independent
adjudication, unseen split, source-span exactness, unsupported abstention, and
latency/memory separation are required, while templates and intake contracts do
not imply real blind-eval completion. Blind response text must not reveal
model/run identity tokens, and reviewer/adjudicator independence fields must be
present in the external return templates.
Response/resource intake rows must carry
`latency_memory_excluded_from_quality_score=1` so latency and memory cannot be
folded into answer quality.
Operator/review-return wording must follow
`operations/review_return_workflow.json`; review templates, operator work
orders, dry-run bundles, and fixture mechanics do not imply accepted human
review, adjudication, real generation, or release readiness.
v61 runtime wording must follow `v61/one_token_path.json`;
`mixtral-ssd-tensor-page-read-rows`, tensor dtype/quant rows, and
`torch-matvec-parity-rows` are replay-bound, but real expert FFN forward parity,
MoE block forward parity, one-token logits parity, actual generation,
production latency, near-frontier quality, and release claims remain blocked
until a replay artifact contains `real_model_execution_ready=1`. The runtime
claim policy must keep `required_before_ssd_resident_runtime_claim_count=6`,
`passed_before_ssd_resident_runtime_claim_count=3`, and
`blocked_before_ssd_resident_runtime_claim_count=3`, with
`blocked_before_ssd_resident_runtime_claim` listing real expert FFN, MoE block,
and one-token logits parity.
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

Current v61 state: `mixtral-ssd-tensor-page-read-rows`, tensor dtype/quant
rows, and `torch-matvec-parity-rows` are replay-bound, but real expert FFN
forward parity, MoE block forward parity, one-token logits parity, actual
generation, production latency, near-frontier quality, and release claims remain
blocked until a replay artifact contains `real_model_execution_ready=1`. The
v61 runtime policy currently has 6 pre-runtime-claim milestones, 3 passed, and
3 blocked: real expert FFN, MoE block, and one-token logits parity.

Typed readiness, retrieval leakage, and D/E 30B/70B real-baseline admission
remain separate blocker surfaces.
```

Full draft: [PR2_REWRITE_DRAFT.md](PR2_REWRITE_DRAFT.md).
