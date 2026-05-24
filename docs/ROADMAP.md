# Roadmap

## Current Checkpoint

As of h10-d plus the h7 and h9 quick closures, the project should be read as:

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
- `h6-q` adds a span-first policy guardrail: only accept the span-exact policy
  when span exact-match gain clears a floor and byte-qacc loss stays within a
  cap. The strict guardrail recovers most of the span lift with much smaller
  qacc loss than the fully span-first policy.
- `h6-r` scales that guardrail over weak and harsher learned-like source
  degradation. The guardrail is useful as a diagnostic, but the accept/reject
  pattern depends on degradation regime and is not yet a learned robust policy.
- `h6-s` calibrates an adaptive utility guardrail over the same degradation
  matrix: `utility-w0p75` rejects weak high-loss span policies while accepting
  the lower-loss harsher split.
- `h6-t` scales the adaptive guardrail as a diagnostic and keeps
  `utility-w0p75` safe but not promoted in the quick gate.
- `h6-u` adds chunk-quality diagnostics over the value span: chunk exact,
  per-offset consistency, coherent wrong-key, and top1/recall gap.
- `h6-v/h6-w` combine chunk-quality with source-credit retry. Source retry is
  noisy-clean in the smoke, but chunk-quality blocks promotion and routes the
  policy to weak-hint/abstain.
- `h6-x` compares prefix/worst-offset/margin local scorer variants and keeps
  plain `span-local-energy` as the best current non-key-shape chunk scorer.
- `h6-y` compares learned route-code signature similarity and finds direct code
  similarity neutral-to-worse because route signature collision remains high.
- `h10-a` adds the first teacher-free chunk-credit ranker. It averages the
  existing route-credit reward/slash signal over candidate record spans and
  reaches the symbolic key-shape smoke/32-64 key scale upper bound in the
  controlled fixture, while staying off the jump-neighbor path.
- `h10-b` adds the abstain/weak-hint policy layer above chunk credit: chunk
  credit can be ready while default promotion remains blocked by the joint
  chunk/source gate.
- `h10-c` adds the joint noisy/distillation gate. Chunk-credit survives injected
  noisy wrong candidates without selecting them.
- `h10-d` adds the forced fallback/retry exercise. With correct primary
  candidates removed, `raw-retry` recovers the forced-corrupt baseline from
  `qacc=0.290000` to `0.910000`, keeps `retry_noisy_selected=0.000000`, and
  leaves routing/jump inactive. Distillation and default promotion remain
  blocked because the teacher-label contract is missing.
- `h7-a` adds the `/goal` closure smoke:
  `experiments/test_v07_goal_route_memory_closure.sh`.
- `h7-b` adds the route-memory promotion gate and keeps default promotion
  blocked.
- `v08` adds an external benchmark readiness gate that defers comparison until
  promotion passes.
- `h9-a/h9-b/h9-d/h9-e` add optional ROCm/HIP backend scaffolding:
  `experiments/test_v09_gpu_backend_closure.sh`.
- Current verification has h6-t/u/v/w/x/y, h10-a/b/c/d, h7-b, v08 readiness, and
  h9-e included in quick closure paths. HIP parity remains optional and
  environment-dependent.

Current next boundary:

- Define and collect the teacher-label contract for chunk-credit distillation:
  correct, wrong, near-miss, missing, and abstain labels over grounded spans.
  Fallback/retry is now exercised in h10-d, so this is the next blocker before
  any default promotion or external benchmark comparison.
- Any stronger claim must survive those matrices without using symbolic
  `key-shape` as the policy itself.

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
- the current next research boundary is adaptive span/chunk guardrail scaling
  under learned-like ambiguity, not topology replacement.
- GPU work is backend/parity instrumentation only. CPU remains canonical until
  a complete ROCm/HIP install proves fixture parity.

## Positioning

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
