# Betelgeuze Harness State

## Current Thread

- Mode: Deep with lightweight durable state and recursive improvement loop.
- Risk: R2/R3, multi-file experiment/docs/closure changes with behavior diagnostics.
- Route invariant: value-bearing route hint path only, `candidate value_pos -> value byte read -> proposal hint`.
- No-go invariant: no jump-neighbor topology promotion; `routing_trigger_rate = active_jump_rate = 0`.

## Latest Completed Point

- h6-t adaptive guardrail scale smoke passed over weak/harsher degradation.
- h6-u chunk-quality diagnostics passed, deriving chunk exact, per-offset
  consistency, coherent wrong-key, and top1/recall gap from the span policy
  artifact.
- h6-v/h6-w wrong-candidate/fallback robustness gates passed as
  diagnostic-only: source-credit retry can stay noisy-clean, but chunk-quality
  is not ready for promotion.
- h6-x chunk-local scorer diagnostics passed: prefix, worst-offset, and margin
  transforms do not beat plain `span-local-energy`.
- h7-b promotion gate passed and blocks default promotion.
- h8/v08 benchmark readiness gate passed by deferring external comparison until
  promotion is allowed.
- h9-e extended backend boundary passed as CPU-canonical/static parity
  instrumentation; HIP runtime parity remains optional and environment
  dependent.

## Key Metrics

```text
h6-p source policy standard:
  groups = 4
  objectives_differ_rate = 0.750000
  qacc_policy_local_energy_rate = 1.000000
  span_policy_hybrid_rate = 0.750000
  qacc_policy_qacc_mean = 0.571875
  qacc_policy_span_exact_mean = 0.378906
  span_policy_qacc_mean = 0.538281
  span_policy_span_exact_mean = 0.441406
  span_policy_qacc_delta_vs_qacc_policy_mean = -0.033594
  span_policy_span_exact_delta_vs_qacc_policy_mean = 0.062500

h6-q strict guardrail standard:
  groups = 4
  span_accept_rate = 0.250000
  selected_hybrid_rate = 0.250000
  qacc_mean = 0.560937
  span_exact_mean = 0.425781
  qacc_delta_vs_qacc_policy_mean = -0.010938
  span_exact_delta_vs_qacc_policy_mean = 0.046875

h6-r degradation standard:
  weak strict span_accept_rate = 0.000000
  weak strict qacc_mean = 0.517187
  weak strict span_exact_mean = 0.289062
  weak objective_split_rate = 1.000000
  harsher strict span_accept_rate = 0.000000
  harsher span-first-g0p025-cap0p075 span_accept_rate = 0.500000
  harsher span-first-g0p025-cap0p075 qacc_delta = -0.029688
  harsher span-first-g0p025-cap0p075 span_delta = 0.023438

h6-s adaptive guardrail standard:
  weak utility-w0p50 span_accept_rate = 1.000000
  weak utility-w0p50 qacc_delta = -0.109375
  weak utility-w0p50 span_delta = 0.062500
  weak utility-w0p75 span_accept_rate = 0.000000
  harsher utility-w0p75 span_accept_rate = 0.500000
  harsher utility-w0p75 qacc_delta = -0.029688
  harsher utility-w0p75 span_delta = 0.023438

h6-t adaptive scale smoke:
  all utility-w0p75 bad_accept_rate = 0.000000
  all utility-w0p75 span_accept_rate = 0.000000
  all utility-w0p75 top1_recall_gap = 0.796875
  all utility-w0p75 coherent_wrong_top_key = 0.828125

h6-u/h6-v/h6-w chunk and robustness smoke:
  chunk_exact_mean = 0.156250
  keyshape_gap_mean = 0.734375
  chunk_ready = 0
  source_arm = policy-source-order
  source_qacc = 0.957813
  source_retry_noisy_selected = 0.000000
  recommendation = diagnostic-only

h6-x chunk-local scorer smoke:
  best_non_keyshape_scorer = span-local-energy
  local_energy_qacc = 0.700000
  local_energy_chunk_exact = 0.531250
  local_energy_coherent_wrong = 0.468750
  local_energy_prefix_qacc_delta = -0.006250
  local_energy_prefix_chunk_delta = -0.031250
  local_margin_chunk_exact = 0.531250
  keyshape_chunk_gap = 0.468750
  routing_trigger_rate_mean = 0.000000
  active_jump_rate_mean = 0.000000

h7-b/v08:
  default_promotion = 0
  h7 status = diagnostic-only
  v08 action = defer-external-comparison
```

## Verification

- Final verification after h6-t/u/v/w/x, h7-b, h9-e, and v08 wiring passed:
  `bash -n experiments/*.sh`, `bash experiments/test_v07_goal_route_memory_closure.sh`,
  `bash experiments/test_v09_gpu_backend_closure.sh`, and `git diff --check`.

## Open Boundary

- NOT learned chunk retrieval solved.
- NOT wrong-candidate/fallback robustness solved.
- NOT long-context retrieval solved.
- Current gate explicitly blocks default promotion and external comparison.
- Next research should improve chunk-level ranking so coherent wrong-key and
  top1/recall gaps shrink without using symbolic `key-shape` as the policy.
- Active next loop: move beyond simple local scalar record scoring. Prefix,
  worst-offset, and margin transforms did not shrink the coherent wrong-key gap
  beyond plain `span-local-energy`.
