# Roadmap

## Current Checkpoint

As of h9-a/h9-b and h6-k, the project should be read as:

```text
discrete local-energy learner
+ value-bearing route-hint memory
+ candidate-quality guardrails
+ symbolic span route-memory diagnostics
+ optional HIP backend scaffold / parity instrumentation
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
- `h6-f` adds span collision / ambiguity diagnostics and shows that recall
  recovery alone is not enough when top1 remains wrong.
- `h6-g` adds learned-like span-source stress and shows that weakened route-code
  identity collapses decode/top1/span exact-match even when larger `K_route`
  recovers recall.
- `h6-h` adds span-level candidate-quality diagnostics and shows that
  all-span recall can recover while all-span top1/exact-match remain low.
- `h6-i` adds span candidate-quality gap diagnostics and shows that weak
  learned-like span sources can select a coherent wrong key across the whole
  span: record-level ranking/consistency is now the next span bottleneck.
- `h6-j` adds a first non-key-shape span-prefix ranking probe and shows that
  visible prefix consistency alone is not enough to replace symbolic key-shape.
- `h6-k` adds a span-key-support ranking probe and shows that cross-offset key
  support alone can be neutral when a wrong key is coherently supported.
- `h6-l` adds a span-local-energy ranking probe and shows the first limited
  non-key-shape lift on weak route-code span stress.
- `h6-m` scales the span-local-energy probe over a small key/seed matrix and
  keeps a limited positive mean lift while remaining below symbolic key-shape.
- `h6-n` composes span-local-energy with h5 candidate-quality presets and
  exposes a span-exact-match versus byte-qacc policy tradeoff.
- `h6-o` turns that tradeoff into an explicit policy artifact: byte-qacc
  selects local-energy, while span-exact selects local-energy-hybrid.
- `h6-p` scales the policy artifact over key/seed and shows the objective split
  survives on average, though not in every group.
- `h7-a` adds the `/goal` closure smoke:
  `experiments/test_v07_goal_route_memory_closure.sh`.
- `h9-a/h9-b` add optional ROCm/HIP backend scaffolding:
  `experiments/test_v09_gpu_backend_closure.sh`.

Still not solved:

- learned sparse routing
- chunk-level long-context retrieval
- wrong-candidate/fallback robustness
- source-credit robustness
- external benchmark comparison
- GPU acceleration proven
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
- GPU work starts as backend/parity instrumentation only. CPU remains
  canonical until a complete ROCm/HIP install proves fixture parity.

## Positioning

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
