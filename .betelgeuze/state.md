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
- h6-y chunk-code similarity diagnostics passed: direct learned route-code
  signature scoring is neutral-to-worse under high signature collision.
- h10-a teacher-free chunk-credit ranker smoke and standard scale passed:
  span-level route-credit reward/slash can select the correct record without
  symbolic `key-shape` in the controlled fixture.
- h10-b chunk-credit abstain policy smoke passed: chunk credit can be ready
  while default promotion remains blocked by the joint chunk/source gate.
- h10-c joint/noisy/distillation gate passed as diagnostic-only: chunk-credit
  survives injected noisy candidates without selecting them.
- h10-d fallback/retry exercise passed: forced primary-candidate corruption
  drives the retry path, raw retry recovers the corrupt baseline without noisy
  selection, and distillation now blocks on the missing teacher-label contract.
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

h6-y chunk-code similarity smoke:
  best_non_keyshape_scorer = span-local-energy
  local_energy_qacc = 0.706250
  local_energy_chunk_exact = 0.531250
  local_energy_coherent_wrong = 0.468750
  route_code_qacc = 0.587500
  route_code_chunk_exact = 0.281250
  local_energy_route_code_chunk_exact = 0.531250
  route_signature_collision_mean = 0.750000
  keyshape_chunk_gap = 0.406250
  routing_trigger_rate_mean = 0.000000
  active_jump_rate_mean = 0.000000

h10-a teacher-free chunk ranker smoke:
  best_non_keyshape_scorer = span-chunk-credit
  local_energy_qacc = 0.700000
  local_energy_chunk_exact = 0.562500
  local_energy_coherent_wrong = 0.437500
  chunk_credit_qacc = 1.000000
  chunk_credit_chunk_exact = 1.000000
  chunk_credit_coherent_wrong = 0.000000
  route_credit_gap_mean = 0.800000
  route_credit_top1_mean = 1.000000
  chunk_credit_gap_mean = 0.800000
  chunk_credit_top1_mean = 1.000000
  routing_trigger_rate_mean = 0.000000
  active_jump_rate_mean = 0.000000

h10-a teacher-free chunk ranker scale:
  groups = 2
  chunk_credit_qacc = 0.992188
  chunk_credit_chunk_exact = 0.960938
  chunk_credit_coherent_wrong = 0.000000
  local_energy_qacc = 0.512500
  local_energy_chunk_exact = 0.351562
  best_qacc_delta_vs_local_energy = 0.479688
  best_chunk_delta_vs_local_energy = 0.609375
  route_credit_gap_mean = 0.799219
  chunk_credit_top1_mean = 1.000000
  keyshape_chunk_gap = 0.000000
  routing_trigger_rate_mean = 0.000000
  active_jump_rate_mean = 0.000000

h10-b chunk-credit abstain policy smoke:
  guardrail_action = weak-hint-with-abstain
  default_promotion = 0
  diagnostic_only = 1
  weak_hint_or_abstain = 1
  chunk_credit_ready = 1
  source_safe = 1
  joint_chunk_source_ready = 0
  combined_ready = 0
  noisy_selection_clean = 1
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-c/h10-d joint source/distillation smoke:
  best_joint_arm = chunk-credit-source-order
  fallback_exercise_arm = raw-retry
  joint_chunk_ready = 1
  joint_source_safe = 1
  noisy_clean = 1
  joint_noisy_used = 1.000000
  noisy_selected = 0.000000
  fallback_baseline_qacc = 0.290000
  fallback_best_qacc = 0.910000
  fallback_qacc_delta_vs_corrupt = 0.620000
  fallback_retry_exercised = 1
  fallback_exercise_ready = 1
  fallback_retry_raw_selected = 1.000000
  fallback_retry_noisy_selected = 0.000000
  joint_chunk_source_ready = 0
  teacher_label_contract_ready = 0
  distillation_ready = 0
  reason = teacher-label-contract-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h7-b/v08:
  default_promotion = 0
  h7 status = diagnostic-only
  v08 action = defer-external-comparison
```

## Verification

- Final verification after h6-t/u/v/w/x, h7-b, h9-e, and v08 wiring passed:
  `bash -n experiments/*.sh`, `bash experiments/test_v07_goal_route_memory_closure.sh`,
  `bash experiments/test_v09_gpu_backend_closure.sh`, and `git diff --check`.
- Focused h6-y verification passed: `cmake --build build --target dmv02 -j2`,
  `bash experiments/test_v06_route_memory_chunk_code_similarity.sh`, and
  `bash experiments/test_v07_route_memory_promotion_gate.sh`.
- Focused h10-a verification passed: `bash -n
  experiments/run_v10_teacher_free_chunk_ranker.sh`, `bash -n
  experiments/test_v10_teacher_free_chunk_ranker.sh`, and `bash
  experiments/test_v10_teacher_free_chunk_ranker.sh`.
- Closure verification after wiring h10-a passed: `bash -n experiments/*.sh`,
  `bash experiments/test_v07_goal_route_memory_closure.sh`, and
  `git diff --check`.
- Full quick verification with backend wrapper passed after h10-a wiring:
  `bash experiments/test_v09_gpu_backend_closure.sh`.
- h10-a scale guard passed: `bash
  experiments/test_v10_teacher_free_chunk_ranker_scale.sh`.
- h10-b abstain policy smoke passed: `bash
  experiments/test_v10_chunk_credit_abstain_policy.sh`.
- h10-c joint robustness and distillation gates passed: `bash
  experiments/test_v10_chunk_credit_source_robustness.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-c closure wiring passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h10-d focused gates passed: `bash
  experiments/test_v10_chunk_credit_fallback_retry_exercise.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-d closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, `bash
  experiments/test_v09_gpu_backend_closure.sh`, with v08 still deferred.

## Open Boundary

- NOT scaled learned chunk retrieval solved.
- NOT teacher-distilled chunk retrieval solved.
- NOT wrong-candidate/fallback robustness solved beyond the h10-d forced smoke.
- NOT long-context retrieval solved.
- Current gate explicitly blocks default promotion and external comparison.
- Active next loop: define the h10-e teacher-label contract for chunk-credit
  distillation, then revisit external benchmark readiness and h11 PC RouteLM
  prototype design.
