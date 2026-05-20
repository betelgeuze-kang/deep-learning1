# v0.7 / h7 Goal Closure

h7 is a goal-closure checkpoint, not a claim that learned routing or
long-context retrieval is solved.

The closure preserves the core route-memory invariant:

```text
candidate value_pos -> value byte read -> proposal hint
```

and keeps the forbidden path closed:

```text
remote node as neighbor / jump-neighbor replacement
```

## h7-a Route-memory Goal Closure Decision

`h7-a` passes as route-memory goal closure instrumentation. It does not solve
learned sparse routing, source-credit robustness, wrong-candidate robustness,
fallback robustness, chunk-level retrieval, long-context retrieval, or
Transformer replacement.

The slice adds:

```text
experiments/test_v07_goal_route_memory_closure.sh
```

The quick goal closure runs:

```text
bash -n experiments/*.sh
cmake --build build --target dmv02 -j2
experiments/test_v05_route_quality_closure.sh
experiments/test_v06_route_memory_span_boundary.sh
experiments/test_v06_route_memory_span_exact.sh
experiments/test_v06_route_memory_span_exact_scale.sh
experiments/test_v06_route_memory_span_hash.sh
experiments/test_v06_route_memory_span_hash_scale.sh
experiments/test_v06_route_memory_span_ambiguity.sh
experiments/test_v06_route_memory_span_learned_source.sh
experiments/test_v06_route_memory_span_quality_diagnostics.sh
experiments/test_v06_route_memory_span_candidate_quality_gap.sh
experiments/test_v06_route_memory_span_prefix_ranking.sh
experiments/test_v06_route_memory_span_key_support_ranking.sh
experiments/test_v06_route_memory_span_local_energy_ranking.sh
experiments/test_v06_route_memory_span_local_energy_scale.sh
experiments/test_v06_route_memory_span_local_energy_composition.sh
experiments/test_v06_route_memory_span_local_energy_policy.sh
experiments/test_v06_route_memory_span_local_energy_policy_scale.sh
experiments/test_v06_route_memory_span_first_guardrail.sh
experiments/test_v06_route_memory_span_first_guardrail_degradation.sh
experiments/test_v06_route_memory_span_adaptive_guardrail.sh
experiments/test_v06_route_memory_span_adaptive_guardrail_scale.sh
experiments/test_v06_route_memory_chunk_quality_diagnostics.sh
experiments/test_v06_route_memory_chunk_local_scorers.sh
experiments/test_v06_route_memory_wrong_candidate_robustness.sh
experiments/test_v06_route_memory_abstain_retry_guardrail.sh
experiments/test_v07_route_memory_promotion_gate.sh
```

The optional extended closure:

```text
experiments/test_v07_goal_route_memory_closure.sh --extended
```

also runs the extended h5 route-quality closure and the standard h6
exact/hash/ambiguity/learned-source/quality/candidate-quality-gap/prefix-ranking/key-support/local-energy/local-energy-scale/local-energy-composition/local-energy-policy/local-energy-policy-scale/span-first-guardrail/span-first-guardrail-degradation/adaptive-guardrail
span/adaptive-scale/chunk-quality/chunk-local-scorers/wrong-candidate/abstain-retry/promotion-gate
runners.

## Current Closed Scope

The closed scope through h7 is:

```text
local learner:
  v0.2-b weak-coupling baseline remains stable

route-quality:
  h5 candidate-quality preset/policy guardrails are regression-tested

route-memory:
  h6 first-byte boundary is explicit
  exact span hints expand multi-byte values into per-offset proposal hints
  exact span scale diagnostics pass on symbolic fixtures
  hash span candidates preserve per-offset recall/top1 on no-collision smoke
  hash span scale diagnostics pass on a small symbolic matrix
  span ambiguity diagnostics expose collision-induced recall/top1/qacc failure
  learned-like span-source stress exposes route-code identity collapse and
  recall/top1/span-exact separation under weak route-code sources
  span-quality diagnostics expose all-span recall/top1 separation and the
  symbolic key-shape upper bound
  span candidate-quality gap diagnostics show coherent wrong-key span selection
  under weak route-code sources
  span-prefix ranking diagnostics show visible prefix consistency is not enough
  to replace symbolic key-shape
  span-key-support ranking diagnostics show cross-offset key support alone can
  be neutral when the wrong key is coherently supported
  span-local-energy ranking diagnostics show local dynamics compatibility can
  provide a limited non-key-shape span record-quality signal
  span-local-energy scale diagnostics show the limited lift survives a small
  key/seed matrix
  span-local-energy composition diagnostics show span exact-match and byte qacc
  can prefer different candidate-quality presets
  span-local-energy policy diagnostics make the byte-qacc versus span-exact
  objective split explicit
  span-local-energy policy-scale diagnostics show the objective split survives
  across a small key/seed matrix
  span-first guardrail diagnostics recover most of the span-exact lift while
  bounding byte-qacc loss under the h6-p policy artifact
  span-first guardrail degradation diagnostics show fixed guardrail thresholds
  are regime-sensitive under learned-like source degradation
  adaptive guardrail diagnostics calibrate qacc loss versus span gain and select
  utility-w0p75 as the current diagnostic candidate
  adaptive guardrail scale diagnostics keep utility-w0p75 safe but diagnostic
  chunk-quality diagnostics expose coherent wrong-key and top1/recall gaps
  chunk-local scorer diagnostics keep plain span-local-energy as the best
  current non-key-shape scorer
  wrong-candidate/fallback gates keep source retry noisy-clean but block
  combined readiness
  abstain/retry guardrails route the current policy to weak-hint/abstain
  h7-b promotion gate keeps default promotion blocked
```

## Still Open

Do not promote the current state beyond these boundaries:

```text
learned sparse routing solved: no
chunk-level long-context retrieval solved: no
wrong-candidate robustness solved: no
fallback robustness solved: no
source-credit robustness solved: no
external benchmark solved: no
```

The next research boundary after h6-x is stronger chunk-level ranking:
coherent wrong-key and top1/recall gaps must shrink without using symbolic
`key-shape` as the policy. h6-t/u/v/w/x show that adaptive span guardrails,
source-credit retry, and simple local scalar transforms are not enough by
themselves: source retry can be noisy-clean, but chunk-quality still blocks
combined readiness. The current policy therefore stays diagnostic-only and
routes uncertain cases to weak-hint/abstain.

## Current Post-closure h9 GPU Scaffold

h9 starts after this goal closure as optional backend instrumentation. It adds
`DLE_ENABLE_HIP`, `--backend cpu|hip`, a HIP candidate-weight factor parity
kernel, and a diagnostic-only proposal-score parity kernel, but it does not
change the h7 route-memory invariant:

```text
candidate value_pos -> value byte read -> proposal hint
```

and it still keeps jump-neighbor replacement inactive. Treat h9 as backend
scaffold/parity only. The h9 quick closure now verifies CPU default behavior,
CPU-only HIP error handling, and the h7 goal closure. CPU/HIP parity remains an
optional extended check until a complete ROCm/HIP install proves fixture parity.
