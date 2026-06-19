# PR #2 Rewrite Draft

## Title

Split PR #2 into v1.0 claim-boundary slices

## Body

This draft PR is not mergeable as one unit. It mixes v50 auditor correctness,
v52 baseline intake, v53/v54 query and generation contracts, v58 blind-eval
protocol, v59 one-command replay, v61 checkpoint/runtime scaffolding,
operator/review-return workflow, and README/documentation cleanup.

Split it into claim-bounded PRs so each reviewer can replay the artifacts
without accepting unrelated scaffold. Merge gates are claim boundary accuracy,
replayable output artifacts, and false-positive blocker closure. Tests are
necessary smoke evidence but are not sufficient merge conditions.

v50 artifact schema is now explicit, but auditor correctness remains blocked
until the required source snapshot, audit case, source span, guard negative,
commercial return, and sha256 manifest rows are present and replay-checkable
without implicit public refresh.

Required review slices:

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

Current v61 state: `mixtral-ssd-tensor-page-read-rows`, tensor dtype/quant
rows, and `torch-matvec-parity-rows` are replay-bound, but real expert FFN
forward parity, MoE block forward parity, one-token logits parity, actual
generation, production latency, near-frontier quality, and release claims remain
blocked until a replay artifact contains `real_model_execution_ready=1`. The
v61 runtime policy currently has `required_before_ssd_resident_runtime_claim_count=6`,
`passed_before_ssd_resident_runtime_claim_count=3`, and
`blocked_before_ssd_resident_runtime_claim_count=3`: real expert FFN, MoE block,
and one-token logits parity.

Typed readiness is mandatory. Bare `ready=1` does not imply
`real_model_execution_ready`, `heldout_metric_ready`, `human_review_ready`,
`independent_reproduction_ready`, or `release_ready`.

Retrieval leakage remains forbidden. Model/retriever input is natural-language
question plus searchable corpus only; source spans, paths, lines, hashes,
query/source direct bindings, expected behavior, and expected labels are
evaluator-only.

D/E 30B/70B fixture rows remain schema-test evidence only until model revision,
quantization, hashes, runtime, prompt/context/retrieval budgets, hardware, seed,
raw answer/citation outputs, and evaluator version are accepted. The D/E
measured-registry exclusion ledger and acceptance blocker ledger are required
replay artifacts for the v52 slice; the exclusion ledger must show
`required_real_evidence_field_count=11`, `missing_real_evidence_field_count=11`,
and `all_required_real_evidence_missing=1` for both D and E.

v58 remains a protocol/intake surface, not a completed blind eval. Response and
resource rows must carry `latency_memory_excluded_from_quality_score=1`, while
A/B/C/D/E/G/H real responses, two blinded reviewers, adjudication, unseen split,
source-span exactness, and unsupported abstention are still required.

v53 source-bound benchmark checks are exact: repo counts, 1000 query/span rows,
negative controls, evaluator separation, A/B/G/H same-query evidence,
sanitized-question-only adapter selection, and v1 exit criteria must all replay.

The source-controlled split contract is `pr_slices/pr2.json`.
