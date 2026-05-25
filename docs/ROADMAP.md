# Roadmap

## Current Checkpoint

As of h10-j plus v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l, h11-a/h11-b, and the h7/h9 quick closures, the project should be read as:

```text
discrete local-energy learner
+ value-bearing route-hint memory
+ candidate-quality guardrails
+ symbolic span route-memory diagnostics
+ PC RouteLM / NLG prototype readiness and artifact verification contracts
+ optional HIP backend scaffold / parity instrumentation
```

Last completed checkpoint:

- h10-j closes the teacher external-label source verifier for the current
  route-memory path. Local source/export/identity/policy/license/provenance
  hash-chain mechanics pass, but local fixtures remain non-real and do not
  unlock distillation.
- h7 quick closure is current through h10-j and keeps default promotion blocked.
- v08-l closes the final-review mechanics layer for external benchmarks while
  keeping real benchmark verification blocked until non-fixture source/review
  evidence exists.
- h9-g closes the measured-speed evidence contract while keeping GPU speedup
  claims deferred until real HIP-backed measurements exist.
- h11-a closes the PC RouteLM / NLG readiness contract and h11-b closes the
  artifact/provenance verification mechanics while keeping real prototype and
  publish claims blocked.

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
  leaves routing/jump inactive.
- `h10-e` adds the teacher-label contract. It covers correct, wrong, near-miss,
  missing-query, and abstain labels with grounded candidate spans, but external
  teacher-label collection and distillation training remain blocked.
- `h10-f` adds a local teacher-label collection harness. Collection now passes
  from deterministic local fixture labels (`label_source=local-teacher-harness`)
  while external teacher labels and distillation training remain blocked.
- `h10-g` adds a local distilled-rule learner over the h10-f label artifact.
  Local training/eval now passes (`teacher_distillation_training_ready=1`), but
  external teacher-label ingestion remains blocked.
- `h10-h` adds the external teacher-label ingestion schema contract. The schema
  passes, but `external_label_source_ready=0` keeps distillation diagnostic-only.
- `h10-i` adds a supplied external teacher-label CSV import contract. The
  fixture can mark `teacher_external_label_source_ready=1`,
  `teacher_external_labels_ready=1`, but the distillation gate remains blocked
  until a real teacher source is verified.
- `h10-j` adds teacher source verification over source artifact, label export,
  teacher identity, teacher policy, license, provenance, and hash evidence.
  Supplied local fixtures can verify the chain mechanics, but
  `real_teacher_source_verified=0` and `distillation_ready=0` remain in force.
- `h7-a` adds the `/goal` closure smoke:
  `experiments/test_v07_goal_route_memory_closure.sh`.
- `h7-b` adds the route-memory promotion gate and keeps default promotion
  blocked.
- `v08` adds an external benchmark readiness gate that defers comparison until
  promotion passes.
- `v08-b` adds an external benchmark adapter manifest for RULER, LongBench,
  codebase retrieval, and real document QA. The adapter schema is ready, but
  source/result/baseline/license evidence remains absent, so external
  comparison is still deferred.
- `v08-c` adds the external benchmark evidence-ingestion schema for dataset,
  license, baseline, result, evaluator, and provenance evidence. The schema is
  ready, but source/result evidence remains absent.
- `v08-d` adds a supplied-CSV evidence import path. A complete fixture can raise
  external benchmark source/result readiness, but no real external benchmark
  evidence has been ingested yet.
- `v08-e` adds baseline-vs-route-memory comparison deltas over supplied
  evidence. The supplied fixture is diagnostic-only and unpublished because
  default promotion remains blocked.
- `v08-f` adds a real-evidence boundary above supplied benchmark evidence.
  Existing `external://` placeholder fixtures and nonstandard hashes remain
  blocked as `fixture-evidence-not-real-benchmark`; a real verifier/fetcher is
  still missing.
- `v08-g` adds a local artifact hash verifier for `file://` dataset/result
  artifacts. Hash-verified local fixtures still block as
  `benchmark-authenticity-verifier-missing`, so this is not yet a real external
  benchmark claim.
- `v08-h` adds benchmark authenticity and evaluator contract evidence. Supplied
  local fixtures can pass identity/canonical URI/evaluator hash/metric checks,
  but still block as `external-benchmark-execution-missing`.
- `v08-i` adds evaluator execution/output artifact evidence. Supplied local
  fixtures can pass output/log hash and metric-output checks, but still block
  as `external-benchmark-attestation-missing`.
- `v08-j` adds independent external attestation evidence. Supplied/local
  attestations can match execution hashes and metric values, but fixture
  attestors keep `real_external_benchmark_verified=0`.
- `v08-k` adds attestor identity/provenance evidence. Supplied local identity,
  registry, and conflict-disclosure artifacts can pass, but final benchmark
  review remains blocked.
- `v08-l` adds final external review evidence. Supplied local review artifacts
  can match source/provenance hashes, execution hashes, metrics, attestation
  IDs, reviewer identity, and conflict disclosure, but fixture/local review
  remains non-publishable without real source review evidence.
- `h11-a` opens the PC RouteLM / NLG prototype readiness gate. It can consume
  supplied component evidence for a quantized 3B-14B generator, CPU RAM/NVMe
  O(n) route memory, GPU candidate scoring, GPU decoder binding, and an NLG
  smoke URI. The supplied fixture reaches diagnostic prototype readiness only;
  real prototype/publish remains blocked by promotion, real teacher-source
  distillation, benchmark comparison, GPU speed evidence, and artifact review.
- `h11-b` adds the PC RouteLM artifact/provenance verifier. Supplied local
  fixtures can verify generator, route-memory, scorer, decoder, NLG-smoke,
  benchmark, license, and provenance hashes with
  `prototype_artifact_chain_verified=1`, but local `results/` artifacts and
  declaration flags still keep `real_pc_routelm_artifact_verified=0`.
- `h9-a/h9-b/h9-d/h9-e/h9-f/h9-g` add optional ROCm/HIP backend scaffolding
  plus measured-speed evidence contracts:
  `experiments/test_v09_gpu_backend_closure.sh`.
- Current verification has h6-t/u/v/w/x/y, h10-a/b/c/d/e/f/g/h/i/j, h7-b,
  v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/readiness,
  h11-a prototype readiness/import, h11-b artifact verifier/import, and h9-g
  included in quick closure paths.
  HIP parity remains optional and environment-dependent.

Current next boundary:

- Provide or connect a real external teacher-label source through the h10-j
  source-verification contract. The local contract, local collection harness,
  local distilled-rule learner, external ingestion schema, supplied CSV path,
  and source-chain verifier are now present; the next blocker is real source
  evidence before any
  default promotion or external benchmark comparison.
- Provide or connect real external benchmark sources/results through the
  v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l
  import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review
  path, then replace fixture final-review rows with real non-fixture review
  evidence before any v0.8 comparison claim.
- Provide a real PC RouteLM prototype above the h11-a/h11-b contracts before
  any NLG or personal-PC LLM claim.
- Any stronger claim must survive those matrices without using symbolic
  `key-shape` as the policy itself.

Still not solved:

- learned sparse routing
- chunk-level long-context retrieval
- wrong-candidate/fallback robustness
- source-credit robustness
- external benchmark comparison
- GPU acceleration proven
- real natural language generation / PC RouteLM prototype
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
- the current next research boundary is a real external teacher-label source
  through the h10-j source-verification contract, not topology replacement.
- GPU work is backend/parity instrumentation only. CPU remains canonical until
  a complete ROCm/HIP install proves fixture parity.

## Positioning

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
