# Roadmap

## Current Checkpoint

As of h7-a, the project should be read as:

```text
discrete local-energy learner
+ value-bearing route-hint memory
+ candidate-quality guardrails
+ symbolic span route-memory diagnostics
```

The live nonlocal path is still:

```text
candidate value_pos -> value byte read -> proposal hint
```

The no-go path is still:

```text
remote node as neighbor / jump-neighbor replacement
```

Current closure:

- `v0.2-b` local learner baseline is stable.
- `h5-bc` closes the current route-quality smoke suite.
- `h6-a..h6-e` open route-memory span diagnostics and add exact/hash span
  candidate guards.
- `h7-a` adds the `/goal` closure smoke:
  `experiments/test_v07_goal_route_memory_closure.sh`.

Still not solved:

- learned sparse routing
- chunk-level long-context retrieval
- wrong-candidate/fallback robustness
- source-credit robustness
- external benchmark comparison
- Transformer replacement

## Historical Execution Order

Original execution order:

1. `v0.1` implementation
2. `v0.1` smoke test
3. `v0.2-pre` implementation
4. counter dataset with `lambda_v = 0`
5. `lambda_v` ablation
6. repeating-text plus `oracle1` comparison
7. `field_margin -> field_byte_acc -> byte_acc` curve check
8. `v0.2-b` only after diagnostics pass
9. investigate sparse routing only after local code space is meaningful

Status update:

- steps 1-8 are complete and documented.
- step 9 split into two findings: active jump-neighbor replacement remains
  no-go, while value-bearing route hints work under controlled fixtures.
- the current next research boundary is span/chunk candidate quality, not
  topology replacement.

## Positioning

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
