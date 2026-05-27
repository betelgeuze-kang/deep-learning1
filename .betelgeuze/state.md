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
  selection.
- h10-e teacher-label contract passed: correct, wrong, near-miss,
  missing-query, abstain, and grounded-span label classes are covered, while
  external teacher-label collection and distillation training remain blocked.
- h10-f local teacher-label collection harness passed:
  `teacher_label_collection_ready=1`, `label_source=local-teacher-harness`;
  external teacher labels and distillation training remain blocked.
- h10-g local teacher-distillation learner passed:
  `teacher_distillation_training_ready=1`, `teacher_learner_id=distilled-rule-v1`;
  external teacher-label ingestion remains blocked.
- h10-h external teacher-label ingestion schema passed:
  `teacher_external_schema_ready=1`, `teacher_external_label_source_ready=0`;
  distillation remains diagnostic-only until a real external source is ready.
- h10-i supplied external teacher-label import passed:
  fixture CSV raises `teacher_external_label_source_ready=1`,
  `teacher_external_labels_ready=1`, while real source evidence is still
  missing and distillation remains blocked.
- h10-j teacher external-label source verifier passed:
  local source/export/identity/policy/license hash-chain mechanics can verify,
  but any local `file://` source remains non-real; `real_teacher_source_verified=0`,
  `distillation_ready=0`, and `default_promotion=0` remain until non-fixture
  source evidence exists.
- h10-k local learned chunk-quality scorer passed:
  `linear-contrastive-chunk-v1` separates reward from negative actions on h10-f
  local teacher labels, rejects mixed label-source provenance, and feeds scorer
  readiness into the distillation gate while keeping `external_label_source_ready=0`,
  `distillation_ready=0`, and `default_promotion=0`.
- h10-l source-verified learned chunk-quality scorer gate passed:
  source-verified scorer readiness now requires supplied non-local feature
  labels, teacher-ID linkage to h10-j source evidence, row-level binding to
  external teacher-label rows by `source_uri`/`provenance_hash`, and real
  teacher-source verification. Local labels, relabeled local feature rows,
  external-label row mismatches, malformed feature CSVs, and local source
  fixtures remain diagnostic-only with
  `source_verified_learned_chunk_scorer_ready=0`.
- h10-m remote teacher-source acquisition gate passed:
  default/no-env blocks before acquisition evidence, local `file://` packages
  are classified as local/placeholder, and HTTPS non-local packages can pass
  URI/hash/acquisition/review contract readiness; h10-m alone does not verify
  fetched source content.
- h10-n remote teacher-source content verifier passed:
  supplied local download/cache files can be bound back to the h10-m HTTPS
  URI/hash manifest and sha256-verified across source/export/identity/policy/
  license/review artifacts, while keeping `real_teacher_source_verified=0`
  until h10-o fetch-attestation and runtime fetcher evidence exist above it.
- h10-o remote teacher-source live-fetch attestation contract passed:
  artifact-level fetch-attestation rows can be bound back to h10-n content and
  verified against HTTPS attestation URIs, cached attestation hashes, fetch
  metadata, independent attestor flags, and non-fixture declarations, while
  keeping `real_teacher_source_verified=0` until a runner-owned runtime fetcher
  exists.
- h7-b promotion gate passed and blocks default promotion.
- h8/v08 benchmark readiness gate passed by deferring external comparison until
  promotion is allowed.
- v08-b external benchmark adapter schema passed for RULER, LongBench,
  codebase retrieval, and real document QA:
  `benchmark_adapter_ready=1`, `benchmark_families=4`, while source/result
  evidence remains blocked.
- v08-c external benchmark evidence-ingestion schema passed for dataset,
  license, baseline, result, evaluator, and provenance evidence:
  `benchmark_evidence_schema_ready=1`, while source/result evidence remains
  blocked.
- v08-d external benchmark evidence import gate passed: a supplied
  `V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV` can raise benchmark source/result
  readiness to `1`, while the default run remains pending.
- v08-e external benchmark comparison gate passed: supplied evidence can produce
  baseline-vs-route-memory deltas, while publishable comparison remains blocked
  before promotion.
- v08-f external benchmark real-evidence gate passed: default evidence remains
  real-evidence blocked, and the supplied placeholder fixture is explicitly not
  counted as real benchmark evidence.
- v08-g external benchmark artifact verifier gate passed: local `file://`
  artifact hashes can be verified, while real external benchmark verification
  remains blocked by missing benchmark authenticity/evaluator evidence.
- v08-h external benchmark authenticity/evaluator gate passed: supplied local
  fixture can verify benchmark identity, canonical URI, evaluator hash, and
  metric contract evidence while real benchmark verification remains blocked by
  missing execution/evaluator-output evidence.
- v08-i external benchmark execution/evaluator-output gate passed: supplied
  local fixture can verify evaluator output/run-log hashes and metric output
  while real benchmark verification remains blocked by missing independent
  external attestation.
- v08-j external benchmark attestation gate passed: supplied local fixture can
  verify attestation artifact hashes plus attested execution hashes/metrics,
  while fixture attestors keep `real_external_benchmark_verified=0` until real
  independent external verification exists.
- v08-k external benchmark attestor identity gate passed: supplied local fixture
  can verify attestor identity, registry, conflict disclosure, and independence
  provenance artifacts, while real benchmark verification remains blocked by
  final external review.
- v08-l external benchmark final review gate passed: supplied local fixture can
  verify report/reviewer hashes plus source/provenance, execution, metric,
  attestation, identity, and conflict-disclosure linkage, while real benchmark
  verification remains blocked until real non-fixture source review evidence
  exists.
- h9-f backend boundary passed as CPU-canonical executable parity
  instrumentation: CPU parity tool reports `max_abs_delta=0`,
  `proposal_max_abs_delta=0`, `cpu_best=70`, `backend_best=70`, and speed
  evidence remains no-claim with `gpu_speedup_claim=deferred`. HIP runtime
  parity remains optional and environment dependent.
- h9-g measured speed gate passed: timing/environment artifact hashes and
  positive speedup ratios can be verified from a supplied CSV, but fixture
  measurements remain no-claim with `gpu_speedup_claim=deferred` until real
  HIP-backed measurement source evidence exists.
- h11-a PC RouteLM / NLG prototype readiness gate passed: default run is
  contract-schema-ready but component-blocked; supplied component fixture can
  reach diagnostic prototype readiness while real prototype/publish remains
  blocked by promotion, benchmark, and speed-evidence gates.
- h11-b PC RouteLM / NLG artifact verifier passed: supplied local artifacts can
  verify generator, route-memory, scorer, decoder, NLG-smoke, benchmark,
  license, and provenance hash chains, but local fixtures remain non-real with
  `real_pc_routelm_artifact_verified=0`.

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

h10-c/h10-d/h10-e/h10-f/h10-g/h10-h/h10-i/h10-j/h10-k/h10-l joint source/distillation smoke:
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
  teacher_label_contract_ready = 1
  teacher_label_collection_ready = 1
  learned_chunk_scorer_ready = 1
  learned_chunk_score_gap = 3.064325
  learned_chunk_coherent_wrong_negative_rate = 1.000000
  learned_chunk_correct_reward_rate = 1.000000
  learned_chunk_negative_action_rate = 1.000000
  learned_chunk_scorer_id = linear-contrastive-chunk-v1
  learned_chunk_scorer_source = local-teacher-harness
  source_verified_feature_labels_ready = 0
  source_verified_learned_chunk_scorer_ready = 0
  source_verified_feature_source_link_ready = 0
  source_verified_feature_label_source = local-teacher-harness
  source_verified_feature_csv_provided = 0
  source_verified_scorer_reason = source-verified-feature-labels-missing
  teacher_external_schema_ready = 1
  teacher_external_label_source_ready = 0
  teacher_external_labels_ready = 0
  teacher_external_label_source = external-teacher-pending
  teacher_distillation_training_ready = 1
  teacher_distillation_eval_ready = 1
  teacher_distillation_action_accuracy = 1.000000
  teacher_learner_id = distilled-rule-v1
  teacher_grounded_span_coverage = 1.000000
  teacher_label_source = local-teacher-harness
  teacher_correct_labels = 2
  teacher_wrong_labels = 1
  teacher_near_miss_labels = 1
  teacher_missing_query_labels = 1
  teacher_abstain_labels = 1
  distillation_ready = 0
  reason = teacher-external-label-source-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-k learned chunk-quality scorer smoke:
  label_source = local-teacher-harness
  learner_id = linear-contrastive-chunk-v1
  feature_count = 9
  reward_rows = 2
  negative_rows = 4
  wrong_rows = 1
  near_miss_rows = 1
  missing_query_rows = 1
  abstain_rows = 1
  coherent_wrong_rows = 2
  reward_score_mean = 2.266878
  negative_score_mean = -2.266878
  reward_score_min = 1.951978
  negative_score_max = -1.112347
  learned_score_gap = 3.064325
  correct_reward_rate = 1.000000
  negative_action_rate = 1.000000
  coherent_wrong_negative_rate = 1.000000
  slash_negative_rate = 1.000000
  abstain_negative_rate = 1.000000
  weak_negative_rate = 1.000000
  direction_ready = 1
  separation_ready = 1
  learned_chunk_scorer_ready = 1
  external_label_source_ready = 0
  default_promotion = 0
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-l source-verified learned chunk scorer default smoke:
  feature_csv_provided = 0
  feature_rows = 6
  feature_teacher_rows = 1
  matched_feature_teacher_rows = 0
  feature_has_binding_fields = 0
  feature_bound_rows = 0
  matched_feature_label_rows = 0
  external_label_rows = 0
  feature_external_label_link_ready = 0
  feature_label_source = local-teacher-harness
  feature_source_link_ready = 0
  learned_chunk_scorer_ready = 1
  learned_score_gap = 3.064325
  source_verified_feature_labels_ready = 0
  teacher_source_chain_verified = 0
  real_teacher_source_verified = 0
  source_verified_learned_chunk_scorer_ready = 0
  default_promotion = 0
  status = diagnostic-only
  reason = source-verified-feature-labels-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-l supplied local source-linked feature fixture:
  feature_csv_provided = 1
  feature_rows = 6
  feature_has_binding_fields = 1
  feature_bound_rows = 6
  matched_feature_label_rows = 6
  external_label_rows = 6
  feature_external_label_link_ready = 1
  feature_label_source = provided-external-feature-csv
  feature_source_link_ready = 1
  source_verified_feature_labels_ready = 1
  teacher_source_chain_verified = 1
  real_teacher_source_verified = 0
  source_verified_learned_chunk_scorer_ready = 0
  reason = teacher-real-external-label-source-missing

h10-l negative bypass guards:
  relabeled_local_rows_without_source_uri_provenance = blocked
  mismatched_external_label_row_bindings = blocked
  malformed_feature_label_csv = rejected
  outside_results_local_file_real_declaration = blocked
  canonical_h10k_summary_not_overwritten = 1

h10-m remote teacher-source acquisition default smoke:
  acquisition_rows = 0
  remote_teacher_source_acquisition_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-acquisition-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-m supplied local acquisition fixture:
  acquisition_rows = 1
  required_uri_fields = 6
  local_uri_fields = 6
  remote_uri_scheme_ready = 0
  hash_manifest_ready = 1
  remote_teacher_source_acquisition_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-local-or-placeholder

h10-m supplied HTTPS acquisition package:
  acquisition_rows = 1
  required_uri_fields = 6
  https_remote_uri_fields = 6
  remote_uri_scheme_ready = 1
  hash_manifest_ready = 1
  remote_teacher_source_acquisition_ready = 1
  real_teacher_source_verified = 0
  action = remote-teacher-source-fetcher-missing

h10-n remote teacher-source content default smoke:
  remote_teacher_source_acquisition_ready = 0
  remote_teacher_source_content_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-acquisition-not-ready

h10-n supplied HTTPS acquisition without content:
  remote_teacher_source_acquisition_ready = 1
  content_rows = 0
  remote_teacher_source_content_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-content-missing

h10-n supplied matching cache content:
  content_rows = 1
  matched_teacher_rows = 1
  remote_uri_match_rows = 1
  hash_manifest_match_rows = 1
  required_content_fields = 6
  content_hash_verified_fields = 6
  remote_teacher_source_content_ready = 1
  real_teacher_source_verified = 0
  action = remote-teacher-source-live-fetch-missing

h10-o remote teacher-source live-fetch default smoke:
  remote_teacher_source_content_ready = 0
  remote_teacher_source_live_fetch_attestation_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-content-not-ready

h10-o supplied h10-n content without fetch attestation:
  remote_teacher_source_content_ready = 1
  expected_fetch_artifact_rows = 6
  fetch_attestation_rows = 0
  remote_teacher_source_live_fetch_attestation_ready = 0
  action = remote-teacher-source-fetch-attestation-missing

h10-o supplied local attestation fixture:
  fetch_attestation_rows = 6
  matched_artifact_rows = 6
  content_hash_match_rows = 6
  attestation_uri_remote_rows = 0
  independent_attestor_rows = 0
  remote_teacher_source_live_fetch_attestation_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-independent-attestation-missing

h10-o supplied remote-style attestation package:
  fetch_attestation_rows = 6
  attestation_uri_remote_rows = 6
  attestation_cache_hash_verified_rows = 6
  independent_attestor_rows = 6
  independent_attestation_ready_rows = 6
  remote_teacher_source_live_fetch_attestation_ready = 1
  real_teacher_source_verified = 0
  action = remote-teacher-source-runtime-fetcher-missing

h10-i supplied external-label import fixture:
  external_label_rows = 5
  source_uri_rows = 5
  teacher_id_rows = 5
  confidence_rows = 5
  provenance_rows = 5
  license_rows = 5
  correct_labels = 1
  wrong_labels = 1
  near_miss_labels = 1
  missing_query_labels = 1
  abstain_labels = 1
  teacher_external_label_source_ready = 1
  teacher_external_labels_ready = 1
  teacher_external_label_source = provided-external-csv
  teacher_source_chain_verified = 0
  real_teacher_source_verified = 0
  teacher_source_action = teacher-external-source-evidence-missing
  distillation_ready = 0
  status = diagnostic-only
  reason = teacher-real-external-label-source-missing
  default_promotion = 0
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h10-j supplied local source-verifier fixture:
  external_label_source_ready = 1
  teacher_external_labels_ready = 1
  teacher_source_source = provided-csv
  external_label_rows = 5
  label_teacher_rows = 1
  source_rows = 1
  matched_teacher_rows = 1
  source_hash_verified_rows = 1
  label_export_hash_verified_rows = 1
  teacher_identity_hash_verified_rows = 1
  teacher_policy_hash_verified_rows = 1
  license_hash_verified_rows = 1
  local_fixture_uri_rows = 1
  teacher_source_chain_verified = 1
  real_teacher_source_verified = 0
  action = teacher-real-source-review-missing
  distillation_ready = 0
  reason = teacher-real-external-label-source-missing
  default_promotion = 0
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h7-b/v08:
  default_promotion = 0
  h7 status = diagnostic-only
  benchmark_families = 4
  benchmark_adapter_ready = 1
  benchmark_evidence_schema_ready = 1
  external_benchmark_source_ready = 0
  external_benchmark_result_ready = 0
  external_benchmark_ready = 0
  v08 action = defer-external-comparison

v08-d supplied evidence fixture:
  evidence_source = provided-csv
  external_benchmark_source_ready = 1
  external_benchmark_result_ready = 1
  external_benchmark_ready = 1
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-e supplied comparison fixture:
  evidence_source = provided-csv
  comparison_input_ready = 1
  benchmark_comparison_ready = 1
  publishable_comparison_ready = 0
  route_memory_wins = 0
  route_memory_losses = 4
  route_memory_ties = 0
  action = diagnostic-comparison-only

v08-f supplied placeholder real-evidence gate:
  evidence_source = provided-csv
  external_benchmark_ready = 1
  ready_rows = 4
  real_dataset_uri_rows = 0
  real_result_uri_rows = 0
  source_hash_rows = 0
  provenance_hash_rows = 0
  real_evidence_format_ready = 0
  real_external_benchmark_verified = 0
  action = fixture-evidence-not-real-benchmark

v08-f supplied real-format gate:
  evidence_source = provided-csv
  external_benchmark_ready = 1
  ready_rows = 4
  real_dataset_uri_rows = 4
  real_result_uri_rows = 4
  source_hash_rows = 4
  provenance_hash_rows = 4
  real_evidence_format_ready = 1
  real_external_benchmark_verified = 0
  action = real-benchmark-verifier-missing

v08-g local artifact verifier fixture:
  evidence_source = provided-csv
  real_evidence_format_ready = 1
  local_dataset_uri_rows = 4
  local_result_uri_rows = 4
  source_hash_verified_rows = 4
  provenance_hash_verified_rows = 4
  artifact_verifier_ready = 1
  real_external_benchmark_verified = 0
  action = benchmark-authenticity-verifier-missing

v08-h supplied authenticity/evaluator fixture:
  evidence_source = provided-csv
  authenticity_source = provided-csv
  artifact_verifier_ready = 1
  canonical_uri_match_rows = 4
  authenticity_ready_rows = 4
  evaluator_ready_rows = 4
  evaluator_hash_rows = 4
  metric_ready_rows = 4
  benchmark_authenticity_ready = 1
  evaluator_contract_ready = 1
  benchmark_authenticity_verified = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-execution-missing

v08-i supplied execution/evaluator-output fixture:
  evidence_source = provided-csv
  authenticity_source = provided-csv
  execution_source = provided-csv
  benchmark_authenticity_verified = 1
  output_hash_verified_rows = 4
  run_log_hash_verified_rows = 4
  execution_ready_rows = 4
  metric_output_rows = 4
  evaluator_execution_verified = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-attestation-missing

v08-j supplied attestation fixture:
  evidence_source = provided-csv
  authenticity_source = provided-csv
  execution_source = provided-csv
  attestation_source = provided-csv
  benchmark_authenticity_verified = 1
  evaluator_execution_verified = 1
  attestation_artifact_rows = 4
  attestation_hash_verified_rows = 4
  execution_hash_attested_rows = 4
  metric_attested_rows = 4
  independent_attestor_rows = 0
  independent_attestation_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-independent-attestor-missing

v08-k supplied attestor identity fixture:
  attestor_identity_source = provided-csv
  evaluator_execution_verified = 1
  independent_attestation_verified = 1
  identity_rows = 4
  matched_attestation_rows = 4
  identity_hash_verified_rows = 4
  registry_hash_verified_rows = 4
  conflict_disclosure_hash_verified_rows = 4
  independence_basis_rows = 4
  no_declared_conflict_rows = 4
  attestor_identity_verified = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-final-review-missing

v08-l supplied final-review fixture:
  final_review_source = provided-csv
  evaluator_execution_verified = 1
  independent_attestation_verified = 1
  attestor_identity_verified = 1
  review_rows = 4
  matched_attestation_rows = 4
  review_hash_verified_rows = 4
  reviewer_identity_hash_verified_rows = 4
  reviewer_conflict_hash_verified_rows = 4
  critical_hash_match_rows = 4
  metric_match_rows = 4
  review_ready_rows = 4
  review_approved_rows = 4
  real_source_declared_rows = 0
  non_fixture_declared_rows = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-real-source-review-missing

h11-a supplied prototype fixture:
  prototype_contract_schema_ready = 1
  small_generator_adapter_ready = 1
  route_memory_residency_ready = 1
  candidate_scoring_ready = 1
  decoder_binding_ready = 1
  nlg_smoke_ready = 1
  component_evidence_ready = 1
  diagnostic_prototype_ready = 1
  pc_routelm_prototype_ready = 0
  publishable_pc_routelm_ready = 0
  action = diagnostic-prototype-only

h11-b supplied local artifact fixture:
  prototype_source = provided-csv
  artifact_source = provided-csv
  prototype_rows = 1
  artifact_rows = 1
  matched_prototype_rows = 1
  generator_hash_verified_rows = 1
  route_memory_hash_verified_rows = 1
  candidate_scorer_hash_verified_rows = 1
  decoder_binding_hash_verified_rows = 1
  nlg_smoke_hash_verified_rows = 1
  benchmark_result_hash_verified_rows = 1
  license_hash_verified_rows = 1
  provenance_hash_verified_rows = 1
  ready_rows = 1
  local_fixture_uri_rows = 1
  real_prototype_declared_rows = 1
  non_fixture_declared_rows = 1
  prototype_artifact_chain_verified = 1
  real_pc_routelm_artifact_verified = 0
  action = pc-routelm-real-artifact-review-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h9-g supplied measured-speed fixture:
  measurement_source = provided-csv
  timing_artifact_hash_verified_rows = 1
  environment_hash_verified_rows = 1
  timing_ready_rows = 1
  real_hip_measurement_rows = 0
  speedup_positive_rows = 1
  measured_speed_evidence_ready = 0
  speed_evidence_ready = 0
  gpu_speedup_claim = deferred
  median_speedup = 1.250000
  action = real-hip-measurement-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000
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
- h10-e focused gates passed: `bash
  experiments/test_v10_teacher_label_contract.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-e closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, `bash
  experiments/test_v09_gpu_backend_closure.sh`, with v08 still deferred.
- h10-f focused gates passed: `bash
  experiments/test_v10_teacher_label_collection_harness.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-f closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, `bash
  experiments/test_v09_gpu_backend_closure.sh`, with v08 still deferred.
- h10-g focused gates passed: `bash
  experiments/test_v10_teacher_distillation_learner.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-g h7 closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, with v08 still deferred.
- h10-g backend wrapper verification passed: `bash
  experiments/test_v09_gpu_backend_closure.sh`, with HIP runtime parity still
  optional.
- h10-h focused gates passed: `bash
  experiments/test_v10_teacher_external_label_ingestion.sh`, `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-h h7 closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, with v08 still deferred.
- h10-h backend wrapper verification passed: `bash
  experiments/test_v09_gpu_backend_closure.sh`, with HIP runtime parity still
  optional.
- h10-i focused gates passed: `bash
  experiments/test_v10_teacher_external_label_ingestion.sh`, `bash
  experiments/test_v10_teacher_external_label_import.sh`, and `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-j focused gates passed: `bash
  experiments/test_v10_teacher_external_label_source_verifier.sh`, `bash
  experiments/test_v10_teacher_external_label_source_import.sh`, `bash
  experiments/test_v10_teacher_external_label_import.sh`, and `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-j h7 closure and backend wrapper verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh` and `bash
  experiments/test_v09_gpu_backend_closure.sh`, confirming h10-j source
  verification inside the h7 route-memory closure and h9 quick closure.
- h10-k focused gates passed: `bash
  experiments/test_v10_learned_chunk_quality_scorer.sh` and `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-k h7 closure verification passed: `bash
  experiments/test_v07_goal_route_memory_closure.sh`, confirming the learned
  chunk-quality scorer inside the route-memory closure with default promotion
  still blocked.
- h10-k backend wrapper verification passed: `bash
  experiments/test_v09_gpu_backend_closure.sh`, confirming h10-k through h7
  plus v08/h11/h9 quick closure with HIP runtime parity still optional.
- h10-l focused gates passed after row/provenance hardening: `bash
  experiments/test_v10_source_verified_learned_chunk_scorer_gate.sh`, `bash
  experiments/test_v10_teacher_external_label_source_import.sh`, `bash
  experiments/test_v10_teacher_external_label_source_verifier.sh`, and `bash
  experiments/test_v10_chunk_credit_distillation_gate.sh`. h10-l is wired into
  `experiments/test_v07_goal_route_memory_closure.sh`, and final wrapper
  verification passed through `bash experiments/test_v09_gpu_backend_closure.sh`
  with h7 goal closure included.
- h10-m focused gate passed: `bash
  experiments/test_v10_remote_teacher_source_acquisition_gate.sh`; it is wired
  into `experiments/test_v07_goal_route_memory_closure.sh`.
- h10-n focused gate passed: `bash
  experiments/test_v10_remote_teacher_source_content_verifier.sh`; it is wired
  into `experiments/test_v07_goal_route_memory_closure.sh`.
- h10-o focused gate passed: `bash
  experiments/test_v10_remote_teacher_source_live_fetch_attestation.sh`; it is
  wired into `experiments/test_v07_goal_route_memory_closure.sh`.
- h9-f focused and wrapper verification passed: `build/hip_candidate_weight_parity
  --backend cpu`, `bash experiments/test_v09_gpu_backend_extended_boundary.sh`,
  `bash experiments/test_v09_gpu_backend_speed_evidence.sh`, and `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h9-g focused verification passed: `bash
  experiments/test_v09_gpu_backend_measured_speed_gate.sh` and `bash
  experiments/test_v09_gpu_backend_measured_speed_import.sh`.
- h11-a focused and wrapper verification passed: `bash
  experiments/test_v11_pc_routelm_prototype_readiness.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_import.sh`, and `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h11-b focused verification passed: `bash
  experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_artifact_import.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_readiness.sh`, and `bash
  experiments/test_v11_pc_routelm_prototype_import.sh`.
- Focused v08-b verification passed: `bash -n experiments/*.sh`, `bash
  experiments/test_v08_external_benchmark_adapter.sh`, `bash
  experiments/test_v08_external_benchmark_readiness.sh`, and `git diff
  --check`.
- Focused v08-c verification passed: `bash
  experiments/test_v08_external_benchmark_evidence_ingestion.sh` and `bash
  experiments/test_v08_external_benchmark_readiness.sh`.
- Focused v08-d verification passed: `bash
  experiments/test_v08_external_benchmark_evidence_import.sh`.
- Focused v08-e verification passed: `bash
  experiments/test_v08_external_benchmark_comparison_gate.sh` and `bash
  experiments/test_v08_external_benchmark_comparison_import.sh`.
- Focused v08-f verification passed: `bash
  experiments/test_v08_external_benchmark_real_evidence_gate.sh`, `bash
  experiments/test_v08_external_benchmark_real_evidence_placeholder.sh`, and
  `bash experiments/test_v08_external_benchmark_real_evidence_format.sh`.
- Focused v08-g verification passed: `bash
  experiments/test_v08_external_benchmark_artifact_verifier.sh` and `bash
  experiments/test_v08_external_benchmark_artifact_verifier_local.sh`.
- Focused v08-h verification passed: `bash
  experiments/test_v08_external_benchmark_authenticity_gate.sh` and `bash
  experiments/test_v08_external_benchmark_authenticity_import.sh`.
- Focused v08-i verification passed: `bash
  experiments/test_v08_external_benchmark_execution_gate.sh` and `bash
  experiments/test_v08_external_benchmark_execution_import.sh`.
- Focused v08-j verification passed: `bash
  experiments/test_v08_external_benchmark_attestation_gate.sh` and `bash
  experiments/test_v08_external_benchmark_attestation_import.sh`.
- Focused v08-k verification passed: `bash
  experiments/test_v08_external_benchmark_attestor_identity_gate.sh` and `bash
  experiments/test_v08_external_benchmark_attestor_identity_import.sh`.
- Focused v08-l verification passed: `bash
  experiments/test_v08_external_benchmark_final_review_gate.sh` and `bash
  experiments/test_v08_external_benchmark_final_review_import.sh`.
- v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l backend wrapper verification passed: `bash
  experiments/test_v09_gpu_backend_closure.sh`, confirming h7 plus v08
  adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/readiness
  in h9 quick closure.

## Open Boundary

- NOT scaled learned chunk retrieval solved.
- NOT teacher-distilled chunk retrieval solved.
- NOT wrong-candidate/fallback robustness solved beyond the h10-d forced smoke.
- NOT long-context retrieval solved.
- Current gate explicitly blocks default promotion, external comparison, and
  publishable PC RouteLM / NLG prototype claims.
- Active next loop: replace the h10-o attestation-contract fixture with a
  runner-owned live remote fetcher and connect a real external teacher-label
  source through the h10-j/h10-l source-verification
  contracts, connect real RULER/LongBench/codebase/doc-QA source and result
  evidence through the v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l
  import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review
  path, replace fixture final-review rows with real non-fixture review evidence, replace h9-g fixture timing
  with real HIP-backed measured GPU speed evidence,
  then replace the h11-a/h11-b fixtures with a real local PC RouteLM prototype
  smoke and non-fixture artifact/provenance evidence.
