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
```

The optional extended closure:

```text
experiments/test_v07_goal_route_memory_closure.sh --extended
```

also runs the extended h5 route-quality closure and the standard h6 exact/hash
span scale runners.

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

The next research boundary after h7 should be true chunk-quality diagnostics:
ambiguous span candidate sets, learned-like span sources, and span-level quality
features that explain when a recovered span candidate is actually useful.
