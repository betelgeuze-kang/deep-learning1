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
  keeping `real_teacher_source_verified=0` until runtime-fetcher and
  live-network evidence exist above it.
- h10-p remote teacher-source runtime fetcher contract passed:
  runner-owned offline replay rows can be generated from h10-o attestations and
  bound back to remote/cache/content hashes with fetcher metadata and downloaded
  cache hash verification, reaching `runner_owned_runtime_fetcher_ready=1`
  while keeping `live_network_fetch_ready=0` and
  `real_teacher_source_verified=0` until live network fetch and non-fixture
  source import replace replay.
- h10-q remote teacher-source live-network import gate passed:
  h10-p offline replay is rejected as live-network evidence; supplied
  live-network runtime rows can raise
  `remote_teacher_source_live_network_import_ready=1`, while
  `real_teacher_source_verified=0` remains blocked until real non-fixture
  source import/review evidence is connected.
- h10-r real teacher-source import/review chain gate passed:
  h10-q live-network import readiness can now be bound to source/export/
  identity/policy/license/import-manifest/review/reviewer/conflict/registry
  URI/hash evidence with live-import observation, independent/authoritative
  review flags, registry readiness, real/non-fixture declarations, and zero
  routing/jump activity. Local review artifacts and placeholder authorities are
  blocked; a non-placeholder review chain can reach
  `real_teacher_source_import_review_ready=1`, but
  `real_teacher_source_verified=0` remains blocked until official authority
  evidence exists.
- h10-s source-verified learned chunk scorer evaluation gate passed:
  h10-l source-verified scorer binding, h10-r import/review readiness, and
  source-bound student-only evaluation rows are now separated. Default/no-env
  blocks with `source-verified-feature-labels-missing`; a supplied source-linked
  eval fixture can reach `student_only_eval_ready=1` and
  `metric_improvement_ready=1`, but final
  `source_verified_learned_chunk_scorer_eval_ready=0` remains until official
  real teacher-source authority exists.
- h7-b promotion gate passed and blocks default promotion.
- h7-c promotion review gate passed: it now binds h7-b internal promotion,
  h10-r real teacher-source import/review, h10-s source-verified scorer eval,
  v08-ab codebase-mini benchmark instrumentation, h11-d PC RouteLM NLG smoke,
  and h9-h CPU/HIP/NVMe workload-speed evidence into a single review matrix.
  The review contract and quality thresholds pass with route/jump activity at
  zero, but `real_evidence_complete=0`, `promotion_review_ready=0`, and
  `default_promotion=0` remain blocked until real teacher, scorer, benchmark,
  NLG, and workload-speed evidence all pass.
- v12 paper/release claim audit passed: it packages h7-c, h10-r/h10-s,
  v08-ab, h11-c/h11-d, and h9-h into a release claim matrix. The diagnostic
  artifact package reaches `diagnostic_release_package_ready=1` and
  `diagnostic_claim_level=4`, but `real_release_package_ready=0`,
  `publishable_claim_level=0`, and `release_claim=diagnostic-artifact-package-only`
  keep publishable release and Transformer/frontier-PC/long-context/
  learned-sparse-routing/GPU-acceleration claims blocked.
- v13-a real-run binder manifest passed: it creates or verifies one
  hash-manifested run directory containing h11-c store artifacts, h11-d NLG
  transcript/result, h9-h workload rows, v08-al run/evaluator trace, h10-s
  scorer/teacher evidence, and v12 claim-audit input. Generated diagnostic
  inputs can reach `real_run_binder_manifest_ready=1`, corrupted run-manifest
  hashes block, and `actual_nonfixture_run_verified=0`,
  `real_pc_routelm_nlg_verified=0`, `real_external_benchmark_verified=0`,
  `real_workload_speed_evidence_ready=0`, `real_release_package_ready=0`, and
  `gpu_speedup_claim=deferred` remain explicit.
- v13-b RouteLM mmap reader passed: it consumes the v13-a run directory,
  verifies run-level and store-level sha256 manifests, opens
  `store/chunk_pages.bin` through mmap, validates route-index/page-table byte
  windows, chunk-offset rows, route-key matches, and missing-abstain rows. The
  good diagnostic run reaches `routelm_mmap_reader_ready=1`; run-hash
  corruption and hash-clean semantic span corruption both block; real
  nonfixture, PC RouteLM artifact, external benchmark, and release flags remain
  `0`.
- v13-c evidence packet ABI passed: it normalizes the bound run manifest,
  store/mmap reader evidence, NLG transcript/result, workload row, benchmark
  trace/evaluator outputs, h10-s scorer evidence, and v12 input into
  `evidence_packet.csv` plus `claim_matrix_input.csv`, verifies packet hashes
  and claim-source references, keeps learned ranking blocked, and leaves
  actual nonfixture, real PC RouteLM artifact/NLG, real external benchmark,
  real speed, real release, and GPU speedup claims at `0` or `deferred`.
- v13-d real NLG transcript binding passed: it parses the bound
  `nlg/transcript.jsonl` and `nlg/result_summary.json`, replays each transcript
  row against `store/route_index.bin` and mmap-read `store/chunk_pages.bin`
  span bytes, emits `transcript_binding.csv`, blocks hash-clean wrong
  grounding, and keeps actual nonfixture, real PC RouteLM NLG, real external
  benchmark, and real release flags at `0`.
- v13-e public codebase RouteQA binding passed: it follows the v13 benchmark
  runner manifest into the local codebase-mini package, verifies run/trace/
  package/source hashes, joins seven dataset/result/query/evaluator rows,
  recomputes evaluator metrics, emits `routeqa_rows.csv`, blocks hash-clean
  evaluator corruption, and keeps actual nonfixture, independent external
  RouteQA, real external benchmark, and real release flags at `0`.
- v13-f resource envelope binding passed: it binds `speed/workload.csv` to the
  v13 run, verifies workload NLG/timing/environment artifact hashes, confirms
  the run NLG result hash, emits `resource_rows.csv`, blocks hash-clean
  speedup removal, and keeps actual nonfixture, real workload-speed evidence,
  GPU speedup, and real release flags blocked.
- v13-g real evidence promotion gate passed: it consumes v13-c/v13-d/v13-e/v13-f
  plus h10-s, h11-d, h9-h, and v08 run evidence, emits `promotion_rows.csv`,
  and keeps the four explicit weaknesses plus nonfixture run promotion blocked
  until all real evidence is true in one bound run.
- v13-h real evidence intake gate passed: it consumes v13-g plus an optional
  four-row same-run intake CSV for external benchmark, learned chunk ranking,
  GPU speedup, and real NLG evidence, writes `intake_rows.csv`, verifies cache
  hashes and HTTPS authority-chain shape, and blocks release until live-network
  verification and regenerated bound-run evidence exist.
- v13-i real evidence live-network gate passed: it consumes v13-h intake
  evidence plus same-run source/review/authority receipt rows, writes
  `live_network_rows.csv`, verifies receipt hashes, HTTPS final URIs, HTTP
  status rows, live-network declarations, and route/jump `0`, while supplied
  fixture receipts stay non-promotable until runner-owned runtime live fetches
  and regenerated bound-run evidence exist.
- v13-j real evidence rebind gate passed: it consumes v13-i receipt evidence
  plus same-run replacement artifacts, writes `rebind_rows.csv`, verifies
  receipt-hash replay, rebuilt artifact hashes, claim-matrix hashes,
  regeneration flags, and route/jump `0`, while supplied mechanics stay
  non-promotable until runtime live fetch evidence and regenerated promotion
  rows exist.
- v13-k runtime fetch provenance gate passed: it consumes v13-j plus v13-i
  receipt evidence, writes `runtime_fetch_provenance_rows.csv`, verifies
  receipt JSON scope, weakness/kind binding, HTTPS original/final URIs, HTTP
  status, method, headers, empty error, ordered UTC timestamps, receipt hashes,
  and route/jump `0`, while supplied runtime-style receipts stay
  non-promotable until their source is runner-owned `runtime-live-fetch`.
- v13-l source seed gate passed: it writes `source_seed_rows.csv`, binds current
  RULER/LongBench public source seeds for the external benchmark blocker,
  classifies learned chunk ranking, GPU speedup, and real NLG as
  `project-source-only`, and blocks real release until all four weaknesses have
  official/independent claim evidence plus runtime live fetch receipts.
- v13-m source seed live-fetch gate passed: it consumes the v13-l seed packet and
  optional `runtime_receipts/`, writes `source_seed_live_fetch_rows.csv`, verifies
  receipt scope/weakness/kind binding, HTTPS/status/method/header/timestamp
  provenance, seed packet hashes, and route/jump `0`, while keeping source URL
  availability separate from official/independent claim evidence.
- v13-n external benchmark official source acquisition gate passed: it consumes
  v13-m/v13-l seed packets, writes `official_source_acquisition_rows.csv`, and in
  live full mode can produce runner-owned RULER/LongBench repo HEAD receipts plus
  a RULER arXiv authority receipt. This raises source acquisition only; benchmark
  query/result/evaluator evidence and release remain blocked.
- v14-a runner-owned query/result/evaluator runner passed: `tools/routelm_benchmark_run`
  now materializes public-codebase RouteQA queries, copies v13 source-chain rows
  into `source/`, binds or live-fetches official repo HEAD source snapshots,
  can select a fetched source snapshot as the query repo, builds an mmap store
  with `route_memory_store.bin` and `chunk_offsets`, emits raw predictions, runs
  the local evaluator, writes metrics, RouteQA rows, benchmark rows, evidence
  packet rows, promotion rows, resource rows, and a hash-manifested run
  directory. Built-in and supplied-query smokes pass, and a live RULER snapshot
  run now checks out the v13-n RULER HEAD and emits three RouteQA/benchmark rows
  with `repo_source=runner-owned-source-snapshot` and
  `external_benchmark_family=ruler_repo-official-source-routeqa`. It can also
  emit RULER-compatible NIAH dataset/prediction/evaluator artifacts under
  `benchmark/ruler_synthetic/`, while recording official RULER evaluator
  invocation status separately. Current live smoke reaches
  `ruler_compatible_ready=1`; official evaluator execution uses recorded
  run-local shims for missing `nltk` and NeMo manifest utilities, writes
  `summary-niah_single_1.csv` plus `submission.csv`, and reaches
  `official_ruler_evaluator_ready=1`. It now also invokes official RULER
  `scripts/data/synthetic/niah.py` with run-local `nltk`/`wonderwords`/
  `tiktoken`/NeMo shims, writes
  validation JSONL files for `niah_single_1`, `niah_multikey_2`, and
  `niah_multikey_3`, predicts those nine generated rows by extracting target
  needles from generated `input` text rather than copying `outputs`, writes
  task-specific `official_generator_eval/*.jsonl` files plus `summary.csv`,
  `official_generator_benchmark_rows.csv` and
  `official_generator_metrics.json` plus
  `official_generator_prediction_provenance.csv` with dataset/prediction/
  evaluator/metrics/provenance bindings, and reaches
  `official_ruler_generator_ready=1`,
  `official_ruler_generator_evaluator_ready=1`,
  `official_ruler_generator_benchmark_ready=1`, and average generated-row score
  `77.78` across three official NIAH task rows with `oracle_prediction_used=0`
  and `extracted_prediction_rows=9`. It reaches
  `runner_owned_query_result_evaluator_ready=1`, while
  `candidate_external_benchmark_result_ready=0`,
  `real_external_benchmark_verified=0`, and release remain blocked because this
  is runner-owned source/query/evaluator evidence, not independent RULER/
  LongBench benchmark execution.
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
- v08-l external benchmark final-review real-source guard passed: local
  final-review/reviewer artifacts remain blocked even when a supplied
  final-review CSV declares every row real and non-fixture; real benchmark
  verification remains `0` with action
  `external-benchmark-local-final-review-artifact`.
- v08-l external benchmark remote-review guard passed: HTTPS hash-attested
  final-review/reviewer artifacts can count as non-local review evidence, but
  real benchmark verification remains blocked with action
  `external-benchmark-local-upstream-artifact` if the underlying
  evidence/execution/attestation/identity artifacts are still local fixtures.
- v08 lower-chain remote-artifact path passed: HTTPS hash-attested
  source/result, evaluator output/run-log, attestation, attestor identity,
  registry, and conflict-disclosure artifacts can pass v08-g/i/j/k mechanics
  with local artifact counters at `0`, while real benchmark verification still
  stops before publication with action `external-benchmark-final-review-missing`.
- v08-l/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab remote-full source-import/result-authority/publication/source-acquisition/content-cache/codebase-mini guard passed: fully remote-style
  lower-chain plus final-review fixtures can clear local-artifact counters, and
  supplied contract/verifier/live-review/authority-review/public-registry/live-query/fetch/network-proof/
  real-verification/official-authority fixtures can reach
  `source_import_official_authority_review_ready=1`, but they still keep
  `real_external_benchmark_verified=0` unless official result-authority rows
  also bind the final reviewed result artifacts; supplied result-authority
  fixtures reach `external_benchmark_result_authority_review_ready=1` but block
  with action `external-benchmark-result-authority-fixture-only` until
  non-fixture live registry query plus fetch/cache, network proof, and official
  real-verification plus authority/trust-root records and official
  result-authority/leaderboard records plus non-fixture publication,
  source-acquisition, source-content, and codebase-mini review packages exist.
- v08-m external benchmark source-import contract gate passed: remote-style
  source-import rows can bind lower-chain source/result/execution URIs and
  hashes to non-local import manifest/fetch-log/reviewer artifacts,
  live-network import flags, non-fixture declarations, and independent
  source-import review, reaching `source_import_contract_ready=1` while
  keeping `source_import_verified=0` and
  `real_external_benchmark_verified=0` with action
  `external-benchmark-source-import-real-verifier-missing`.
- v08-n external benchmark source-import verifier gate passed: runner-owned
  replay verifier rows can bind back to v08-m source-import IDs, import
  manifest/fetch-log/reviewer hashes, benchmark artifact URIs, and verifier
  binary/stdout/stderr hashes, reaching `source_import_verifier_ready=1` while
  keeping `live_network_source_import_verified=0`,
  `source_import_verified=0`, and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-live-verifier-missing`.
- v08-o external benchmark live source-import verifier gate passed: supplied
  live-style verifier rows can clear the replay blocker with
  `live_network_verifier_rows=4`, `offline_replay_rows=0`, real declarations,
  and non-fixture declarations, reaching `source_import_live_verifier_ready=1`
  while keeping `source_import_verified=0` and
  `real_external_benchmark_verified=0` with action
  `external-benchmark-source-import-independent-live-review-missing`.
- v08-p external benchmark source-import live-review gate passed: supplied
  non-local, hash-attested live-review rows can bind back to live verifier run
  IDs, verifier artifact hashes, and import manifest/fetch-log hashes, reaching
  `source_import_independent_live_review_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-authoritative-live-review-missing`.
- v08-q external benchmark source-import authoritative-review gate passed:
  supplied non-local, hash-attested authority-review rows can bind source-import
  IDs, verifier run IDs, live-review IDs, live-review report hashes, verifier
  hashes, reviewer identity, reviewer registry, and conflict-disclosure
  evidence, reaching `source_import_authoritative_review_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-real-public-registry-missing`.
- v08-r external benchmark source-import public-registry gate passed: supplied
  non-local, hash-attested registry rows can bind source-import IDs, verifier
  run IDs, live-review IDs, authority-review IDs, authority hashes, verifier
  hashes, registry entry/operator/provenance evidence, and approval flags,
  reaching `source_import_public_registry_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-live-registry-query-missing`.
- v08-s external benchmark source-import live-registry-query gate passed:
  runner-owned replay rows can verify query-runner mechanics while still
  blocking live network evidence, and supplied live-style query rows can bind
  registry response hashes back to public-registry rows, reaching
  `source_import_live_registry_query_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-live-registry-query-fixture-only`.
- v08-t external benchmark source-import live-registry fetch/cache gate passed:
  runner-owned replay rows can verify fetcher metadata and local response-cache
  hashes while still blocking network proof, and supplied live-style fetch rows
  can bind live-query rows to cache hashes, reaching
  `source_import_live_registry_fetch_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-live-registry-fetch-fixture-only`.
- v08-u external benchmark source-import live-registry network-proof gate
  passed: runner-owned replay proof rows can verify proof metadata, tool hashes,
  request/header/TLS/DNS/nonce hashes, and cache/body hash binding while still
  blocking live network proof; supplied live-style proof rows can reach
  `source_import_live_registry_network_proof_ready=1` while keeping
  `source_import_verified=0` and `real_external_benchmark_verified=0` with
  action `external-benchmark-source-import-live-registry-network-proof-fixture-only`.
- v08-v external benchmark source-import real-verification gate passed:
  supplied verification rows can bind network-proof rows to verification
  reports, verifier identity artifacts, proof transcripts, and verified cache
  hashes, reaching `source_import_real_verification_review_ready=1`; placeholder
  verification domains still keep `source_import_verified=0` and
  `real_external_benchmark_verified=0` with action
  `external-benchmark-source-import-real-verification-placeholder-domain`.
- v08-w external benchmark source-import official-authority gate passed:
  supplied authority rows can bind v08-v verification rows to official
  authority artifacts, benchmark source/license artifacts, verification-report
  hashes, authority domains, and trust-root review flags, reaching
  `source_import_official_authority_review_ready=1`; fixture authority rows
  still keep `source_import_verified=0` and
  `real_external_benchmark_verified=0` with action
  `external-benchmark-source-import-official-authority-fixture-only`.
- v08-x external benchmark result-authority gate passed: supplied
  result-authority rows can bind final-reviewed benchmark result URIs,
  provenance hashes, evaluator-output hashes, run-log hashes, metric values,
  official leaderboard/result artifacts, metric/protocol artifacts, submitter
  identity, authority domains, and result-review flags, reaching
  `external_benchmark_result_authority_review_ready=1`; fixture result-authority
  rows still keep `real_external_benchmark_verified=0` with action
  `external-benchmark-result-authority-fixture-only`.
- v08-y external benchmark publication-package gate passed: supplied
  publication rows can bind official result-authority rows and comparison
  deltas/verdicts to publication package, report, comparison table,
  reproducibility bundle, release license, conflict disclosure, and publication
  review artifacts, reaching `external_benchmark_publication_review_ready=1`;
  fixture publication rows still keep `real_external_benchmark_verified=0`
  with action `external-benchmark-publication-fixture-only`, and non-fixture
  publication rows still block with
  `external-benchmark-publication-comparison-not-publishable` while comparison
  remains unpublished.
- v08-z external benchmark source-acquisition gate passed: supplied acquisition
  rows can bind the four adapter families to official source landing, dataset,
  benchmark-card, split-manifest, license, and metric-spec URI/hash packages,
  reaching `external_benchmark_source_acquisition_review_ready=1`; fixture
  acquisition rows still keep `external_benchmark_source_acquisition_ready=0`
  with action `external-benchmark-source-acquisition-fixture-only`, and
  non-fixture acquisition packages can reach
  `external_benchmark_source_acquisition_ready=1` while still keeping
  `real_external_benchmark_verified=0` until source import/content/result/
  review/publication evidence is connected.
- v08-aa external benchmark source-acquisition content verifier passed:
  supplied content rows can bind the four v08-z acquisition families to source
  landing, dataset, benchmark-card, split-manifest, license, and metric-spec
  cache files, verify all 24 sha256 cache hashes, and reach
  `external_benchmark_source_acquisition_content_ready=1`; bad cache/hash
  manifests block, and cache verification still keeps
  `real_external_benchmark_verified=0` until source import/result/review/
  publication evidence is connected.
- v08-ab external benchmark codebase-mini instrumentation passed:
  generated local `codebase-retrieval` packages bind four real repository
  source files to source/dataset/split/license/metric manifests, three
  baseline artifacts, two result artifacts, ten sha256 artifact checks, and the
  h11-c RouteMemory store hash chain. The smoke reaches
  `codebase_mini_source_ready=1`, `benchmark_result_artifact_verified=1`,
  `baseline_comparison_ready=1`, `span_exact=1.000000`,
  `chunk_exact=1.000000`, `missing_abstain=1.000000`, and
  `wrong_answer_rate=0.000000`; corrupted dataset hashes block with
  `codebase-mini-artifact-hash-mismatch`, and local instrumentation still keeps
  `real_external_benchmark_verified=0`.
- v08-ac external benchmark content/result bridge passed:
  supplied bridge rows can bind v08-aa source acquisition/content to the
  v08-ab codebase-mini result package, verify five
  result/baseline/dataset/run/evaluator hashes, and reach
  `codebase_content_result_bridge_ready=1` with route/jump activity at zero.
  The full external result bridge remains blocked with
  `external_benchmark_result_bridge_ready=0` and
  `real_external_benchmark_verified=0` because coverage is only one of four
  benchmark families and the result artifacts are local.
- v08-ad external benchmark family result bridge passed:
  supplied non-local rows for RULER, LongBench, codebase-retrieval, and
  real-document-qa can bind back to v08-aa source-content acquisition IDs,
  verify the source-content summary hash, require 28 sha256-attested HTTPS
  result/baseline/dataset/run/evaluator/result-authority/publication fields,
  and reach `family_result_bridge_review_ready=1` plus
  `external_benchmark_result_bridge_ready=1` with route/jump activity at zero.
  `real_external_benchmark_verified=0` remains because supplied bridge rows are
  not independent reproduction, real review, or publishable benchmark evidence.
- v08-ae external benchmark independent reproduction/review passed:
  supplied non-local rows for all four benchmark families can bind back to the
  v08-ad result bridge, verify result artifact plus bridge-summary hashes,
  require 28 sha256-attested HTTPS reproduction/report/run-log/reviewer/
  conflict/environment/metric fields, and reach
  `independent_reproduction_review_ready=1` with route/jump activity at zero.
  `real_external_benchmark_verified=0` remains because supplied reproduction
  rows are not official release evidence or externally verifiable benchmark
  publication.
- v08-af external benchmark official release evidence passed: supplied
  release rows for all four benchmark families can bind back to the v08-ae
  independent reproduction IDs and summary hash, require 44 sha256-attested
  release/reproduction hash fields plus 40 HTTPS release
  package/manifest/archive/version/license/reproducibility/review/index/
  authority URI fields, and reach `official_release_evidence_ready=1` with
  route/jump activity at zero. `real_external_benchmark_verified=0` remains
  because supplied release rows are not live externally verified
  release/publication records.
- v08-ag external benchmark live release verification passed: supplied
  live-verification rows for all four benchmark families can bind back to the
  v08-af release IDs, reproduction IDs, and official release/archive/dataset/
  authority URI+hash pairs, require 28 sha256-attested HTTPS live verification/
  report/network-observation/verifier fields, and reach
  `official_release_live_verification_ready=1` with route/jump activity at
  zero. `real_external_benchmark_verified=0` remains because supplied
  live-verification rows are not canonical online confirmation from the runner.
- v08-ah external benchmark canonical online confirmation passed: supplied
  confirmation rows for all four benchmark families can bind back to the
  v08-ag live verification reports, network observations, verifier identities,
  release IDs, and reproduction IDs, require 36 sha256-attested HTTPS
  live/canonical confirmation, runner-network transcript, TLS, DNS,
  HTTP-header, and content-digest artifact fields, and reach
  `canonical_online_confirmation_ready=1` with route/jump activity at zero.
  `real_external_benchmark_verified=0` remains because supplied confirmation
  rows are not non-fixture publication/result review records.
- v08-ai external benchmark publication/result review passed: supplied review
  rows for all four benchmark families can bind back to v08-ah canonical
  confirmation reports, content-digest manifests, release IDs, and
  reproduction IDs, require 36 sha256-attested HTTPS review/result/publication/
  authority fields, require 28 newly introduced review artifact URIs to be
  non-placeholder HTTPS, and reach `publication_result_review_ready=1` with
  route/jump activity at zero. `real_external_benchmark_verified=0` remains
  because supplied review rows are not live-ingested non-fixture result/
  publication records or promotion evidence.
- v08-aj external benchmark live publication/result ingestion passed: supplied
  ingestion rows for all four benchmark families can bind back to v08-ai
  publication/result review and record URI/hash pairs, require 56
  sha256-attested HTTPS ingestion/review URI fields, require 40 newly
  introduced live-ingestion artifact URIs to be non-placeholder HTTPS, include
  response-header, content-digest, and TLS certificate-chain evidence, and
  reach `live_publication_result_ingestion_ready=1` with route/jump activity at
  zero. `real_external_benchmark_verified=0` remains because supplied ingestion
  rows are not actual non-fixture benchmark authority/promotion evidence.
- v08-ak external benchmark authority/promotion evidence passed: supplied
  authority rows for all four benchmark families can bind back to v08-aj live
  publication/result records and content digests, require 56 sha256-attested
  HTTPS authority/ingestion URI fields, require 40 newly introduced authority
  artifact URIs to be non-placeholder HTTPS, include registry, leaderboard,
  reproducibility package, archive, identity, conflict disclosure, promotion
  trace, and final claim packet evidence, and reach
  `authority_promotion_evidence_ready=1` with route/jump activity at zero.
  `real_external_benchmark_verified=0` remains because supplied authority rows
  are not actual independently observed external benchmark run/evaluator
  evidence.
- v08-al external benchmark run/evaluator trace passed: the local
  codebase-mini `codebase-retrieval` dataset/result join can be recomputed into
  runner/evaluator manifests, query trace, evaluator output, metrics, command
  receipt, and hash manifest artifacts, verifying 6 trace hashes, 7 matched
  query rows, 5 metric matches, and route/jump activity at zero. It reaches
  `codebase_run_evaluator_trace_ready=1`, but
  `external_benchmark_run_evaluator_trace_ready=0` and
  `real_external_benchmark_verified=0` remain because coverage is still one
  local family and independent all-family evaluator evidence is absent.
- v08-am external benchmark independent all-family run/evaluator evidence passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa evidence
  rows verify 28 non-placeholder HTTPS trace/run/evaluator/metric/query/
  observer/authority artifact URIs, 28 sha256 hashes, query volume, quality
  thresholds, proof bindings, independent evaluator declarations, and route/jump
  activity at zero. It reaches
  `external_benchmark_independent_run_evaluator_evidence_ready=1`, but
  `real_external_benchmark_verified=0` remains until live replay/final review
  replaces supplied evidence.
- v08-an external benchmark live replay/final-review evidence passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa review
  rows bind v08-am evidence to replay/final-review artifact URI/hash pairs,
  replay query volume, metric thresholds, live replay declarations,
  independent final-review declarations, fixture declarations, and route/jump
  activity at zero. It reaches
  `external_benchmark_live_replay_final_review_ready=1`, but
  `real_external_benchmark_verified=0` remains until public non-fixture
  verification or direct runner-owned external benchmark runs replace supplied
  mechanics.
- v08-ao external benchmark public non-fixture/direct-run verification passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa
  verification rows bind v08-an review evidence to 40 non-placeholder HTTPS
  public/direct-run artifact URIs, 40 sha256 hashes, query volume, metric
  thresholds, public registry/non-fixture declarations, direct runner-owned
  run/dataset/evaluator/network declarations, third-party reviewer
  declarations, fixture declarations, and route/jump activity at zero. It
  reaches `external_benchmark_public_nonfixture_verification_ready=1`, but
  `real_external_benchmark_verified=0` remains until runner-owned live
  execution/audit proves the public direct-run receipts.
- v08-ap external benchmark runner-owned live execution/audit passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa audit rows
  bind v08-ao verification evidence to 52 non-placeholder HTTPS live
  execution/audit artifact URIs, 52 sha256 hashes, query volume, metric
  thresholds, runner-owned execution declarations, live network/dataset fetch
  declarations, runner-invoked evaluator declarations, replay-disabled
  declarations, audit log and third-party audit declarations, fixture
  declarations, and route/jump activity at zero. It reaches
  `external_benchmark_runner_owned_live_execution_audit_ready=1`, but
  `real_external_benchmark_verified=0` remains until independent live rerun
  confirmation proves the runner-owned audit receipts.
- v08-aq external benchmark independent live rerun confirmation passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa
  confirmation rows bind v08-ap audit evidence to 60 non-placeholder HTTPS
  rerun-confirmation artifact URIs, 60 sha256 hashes, rerun query volume,
  metric thresholds, metric-delta bounds, independent runner/environment
  declarations, live network/dataset refetch/evaluator rerun declarations,
  audit receipt reconciliation, metric recomputation, third-party confirmation
  declarations, fixture declarations, and route/jump activity at zero. It
  reaches `external_benchmark_independent_live_rerun_confirmation_ready=1`, but
  `real_external_benchmark_verified=0` remains until a real non-fixture
  benchmark run package replaces supplied confirmation mechanics.
- v08-ar external benchmark real nonfixture run package intake passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa package
  rows bind v08-aq confirmation evidence to 60 non-placeholder HTTPS
  run-package artifact URIs, 60 sha256 hashes, packaged query volume, metric
  thresholds, metric-delta bounds, nonfixture/official benchmark/public
  archive/raw query/raw output/evaluator container/immutable archive
  declarations, license/PII/third-party reproducibility reviews, fixture
  declarations, and route/jump activity at zero. It reaches
  `external_benchmark_real_nonfixture_run_package_intake_ready=1`, but
  `real_external_benchmark_verified=0` remains until live package artifact fetch
  and authority verification replace supplied package mechanics.
- v08-as external benchmark live package artifact fetch/authority passed:
  supplied RULER, LongBench, codebase-retrieval, and real-document-qa fetch rows
  cover all 60 family/artifact entries and bind each to fetched artifact, fetch
  receipt, and authority record URI/hash pairs. The good fixture verifies 180
  non-placeholder HTTPS URI fields, 180 sha256 hashes, HTTP-200 checks,
  content-digest matches, v08-ar package-intake binding, runner-owned live
  fetch declarations, network/TLS/DNS/HTTP declarations, authority registry and
  official source authority declarations, fixture declarations, and route/jump
  activity at zero. It reaches
  `external_benchmark_live_package_artifact_fetch_authority_ready=1`, but
  `real_external_benchmark_verified=0` remains until official result
  reconciliation replaces supplied fetch/authority mechanics.
- v08-at external benchmark official result reconciliation passed: supplied
  RULER, LongBench, codebase-retrieval, and real-document-qa reconciliation
  rows bind v08-as fetched official leaderboard, metric report, submission
  receipt, evaluator config, raw prediction output, and package-registry
  artifacts by exact URI/hash identity. The good fixture verifies 28
  non-placeholder HTTPS URI fields, 28 sha256 hashes, package identity matches,
  metric-delta tolerance, query-count matches, evaluator/digest/official-source/
  leaderboard/runner declarations, fixture declarations, and route/jump
  activity at zero. It reaches
  `external_benchmark_official_result_reconciliation_ready=1`, but
  `real_external_benchmark_verified=0`; the next transition is the v13
  real-run binder/nonfixture runner path, not another v08 supplied-evidence
  layer.
- `NEXT_IMPLEMENTATION_ROADMAP_v2.md` has been reconciled with the current
  state: its h11-c, v08-ab, h10-r, h10-s, h11-d, h9-h, h7-c, and
  paper/package phases are implemented here as diagnostic or supplied-evidence
  contracts through v12 plus v08-at, v13-a, v13-b, v13-c, v13-d, v13-e, v13-f, v13-g, v13-h, v13-i, v13-j, v13-k, v13-l, v13-m, v13-n, and the v14-a runner path. The active transition remains replacing
  supplied rows with real teacher, external benchmark, speed, and PC RouteLM/NLG
  evidence from one bound nonfixture run.
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
- h11-c NVMe RouteMemory store artifact smoke passed: generated store bundles
  verify route-memory/index/chunk/page-table/manifest/sha256 artifacts, route
  lookup, candidate span reads, missing abstain, and zero route/jump activity
  with `route_memory_artifact_chain_verified=1`; corrupted store files block
  with `nvme-route-memory-artifact-hash-mismatch`, and real PC RouteLM plus
  external benchmark claims remain blocked.
- h11-d PC RouteLM diagnostic NLG smoke passed: generated transcript/result
  artifacts verify teacher-off inference, retrieved evidence usage, answer
  grounding, span citation accuracy, span/chunk exactness, missing abstain,
  wrong-answer rate, latency/storage/memory metrics, and zero route/jump
  activity with `pc_routelm_nlg_smoke_ready=1`, while generated fixtures keep
  `real_pc_routelm_nlg_verified=0`.
- h9-h CPU/HIP/NVMe workload speed evidence gate passed: generated workload
  artifacts bind the h9-g measured-speed schema to the h11-d NLG result,
  verify NLG/timing/environment hashes, positive CPU/HIP ratio, NVMe read,
  query, token, storage, and memory metrics, and zero route/jump activity with
  `diagnostic_workload_speed_ready=1`, while generated fixture rows keep
  `real_workload_speed_evidence_ready=0` and
  `gpu_speedup_claim=deferred`; bad timing hashes and malformed CSV rows block.

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

h10-p remote teacher-source runtime fetcher default smoke:
  remote_teacher_source_live_fetch_attestation_ready = 0
  runner_owned_runtime_fetcher_ready = 0
  live_network_fetch_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-fetch-attestation-not-ready

h10-p h10-o-ready evidence without runtime fetch rows:
  remote_teacher_source_live_fetch_attestation_ready = 1
  expected_runtime_artifact_rows = 6
  runtime_fetch_rows = 0
  runner_owned_runtime_fetcher_ready = 0
  action = remote-teacher-source-runtime-fetch-missing

h10-p runner-owned offline replay:
  runtime_fetch_source = runner-owned-replay
  runtime_fetch_rows = 6
  download_cache_hash_verified_rows = 6
  fetcher_metadata_rows = 6
  runner_owned_fetch_rows = 6
  offline_replay_rows = 6
  network_fetch_rows = 0
  runner_owned_runtime_fetcher_ready = 1
  live_network_fetch_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-live-network-fetch-missing

h10-q remote teacher-source live-network import default smoke:
  runner_owned_runtime_fetcher_ready = 0
  live_network_fetch_ready = 0
  remote_teacher_source_live_network_import_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-fetch-attestation-not-ready

h10-q runner-owned offline replay:
  runtime_fetch_source = runner-owned-replay
  runtime_fetch_rows = 6
  network_fetch_rows = 0
  offline_replay_rows = 6
  runner_owned_runtime_fetcher_ready = 1
  live_network_fetch_ready = 0
  remote_teacher_source_live_network_import_ready = 0
  real_teacher_source_verified = 0
  action = remote-teacher-source-live-network-fetch-missing

h10-q supplied live-network runtime evidence:
  runtime_fetch_source = provided-csv
  runtime_fetch_rows = 6
  network_fetch_rows = 6
  offline_replay_rows = 0
  declared_real_rows = 6
  non_fixture_declared_rows = 6
  runner_owned_runtime_fetcher_ready = 1
  live_network_fetch_ready = 1
  remote_teacher_source_live_network_import_ready = 1
  real_teacher_source_verified = 0
  action = remote-teacher-source-real-source-import-missing

h10-r real teacher-source import/review default smoke:
  remote_teacher_source_live_network_import_ready = 0
  review_rows = 0
  teacher_source_import_review_contract_ready = 0
  real_teacher_source_import_review_ready = 0
  real_teacher_source_verified = 0
  action = real-teacher-source-live-network-import-missing

h10-r local review artifact guard:
  remote_teacher_source_live_network_import_ready = 1
  review_rows = 1
  matched_teacher_rows = 1
  local_review_uri_fields = 5
  sha256_review_hash_fields = 10
  teacher_source_import_review_contract_ready = 0
  real_teacher_source_verified = 0
  action = real-teacher-source-local-import-artifact

h10-r placeholder authority guard:
  required_review_uri_fields = 10
  remote_review_uri_fields = 10
  placeholder_review_uri_fields = 5
  teacher_source_import_review_contract_ready = 1
  real_teacher_source_import_review_ready = 0
  real_teacher_source_verified = 0
  action = real-teacher-source-placeholder-import-artifact

h10-r non-placeholder import/review chain:
  teacher_source_import_review_contract_ready = 1
  real_teacher_source_import_review_ready = 1
  real_teacher_source_verified = 0
  action = real-teacher-source-official-authority-missing

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

h7-c promotion review smoke:
  promotion_review_contract_ready = 1
  h7_default_promotion = 0
  real_teacher_source_verified = 0
  source_verified_learned_chunk_scorer_eval_ready = 0
  real_external_benchmark_verified = 0
  codebase_mini_source_ready = 1
  benchmark_result_artifact_verified = 1
  baseline_comparison_ready = 1
  external_thresholds_met = 1
  real_pc_routelm_nlg_verified = 0
  pc_routelm_nlg_smoke_ready = 1
  nlg_thresholds_met = 1
  real_workload_speed_evidence_ready = 0
  diagnostic_workload_speed_ready = 1
  gpu_speedup_claim = deferred
  wrong_answer_threshold_met = 1
  real_evidence_complete = 0
  promotion_review_ready = 0
  default_promotion = 0
  action = promotion-review-real-evidence-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v12 paper/release claim audit smoke:
  diagnostic_release_package_ready = 1
  real_release_package_ready = 0
  diagnostic_claim_level = 4
  publishable_claim_level = 0
  release_claim = diagnostic-artifact-package-only
  h7c_promotion_review_contract_ready = 1
  h7c_real_evidence_complete = 0
  h10r_real_teacher_source_verified = 0
  h10s_source_verified_eval_ready = 0
  v08ab_codebase_mini_source_ready = 1
  v08ab_benchmark_result_artifact_verified = 1
  v08ab_real_external_benchmark_verified = 0
  h11c_route_memory_artifact_chain_verified = 1
  h11d_pc_routelm_nlg_smoke_ready = 1
  h11d_real_pc_routelm_nlg_verified = 0
  h9h_diagnostic_workload_speed_ready = 1
  h9h_real_workload_speed_evidence_ready = 0
  h9h_gpu_speedup_claim = deferred
  forbidden_transformer_replacement_claim = blocked
  forbidden_frontier_pc_llm_claim = blocked
  forbidden_long_context_solved_claim = blocked
  forbidden_learned_sparse_routing_claim = blocked
  forbidden_gpu_acceleration_claim = blocked
  action = release-package-real-evidence-missing
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

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
  local_final_review_artifact_rows = 4
  nonlocal_final_review_artifact_rows = 0
  reviewer_identity_hash_verified_rows = 4
  local_reviewer_identity_rows = 4
  nonlocal_reviewer_identity_rows = 0
  reviewer_conflict_hash_verified_rows = 4
  local_reviewer_conflict_rows = 4
  nonlocal_reviewer_conflict_rows = 0
  local_upstream_artifact_rows = 32
  critical_hash_match_rows = 4
  metric_match_rows = 4
  review_ready_rows = 4
  review_approved_rows = 4
  real_source_declared_rows = 0
  non_fixture_declared_rows = 0
  source_import_verified = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-real-source-review-missing

v08-l local final-review real-source guard:
  final_review_source = provided-csv
  review_rows = 4
  review_hash_verified_rows = 4
  local_final_review_artifact_rows = 4
  nonlocal_final_review_artifact_rows = 0
  local_reviewer_identity_rows = 4
  nonlocal_reviewer_identity_rows = 0
  local_reviewer_conflict_rows = 4
  nonlocal_reviewer_conflict_rows = 0
  local_upstream_artifact_rows = 32
  real_source_declared_rows = 4
  non_fixture_declared_rows = 4
  source_import_verified = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-local-final-review-artifact

v08-l non-local final-review remote-review guard:
  final_review_source = provided-csv
  review_rows = 4
  review_hash_verified_rows = 4
  local_final_review_artifact_rows = 0
  nonlocal_final_review_artifact_rows = 4
  local_reviewer_identity_rows = 0
  nonlocal_reviewer_identity_rows = 4
  local_reviewer_conflict_rows = 0
  nonlocal_reviewer_conflict_rows = 4
  local_upstream_evidence_artifact_rows = 8
  local_upstream_execution_artifact_rows = 8
  local_upstream_attestation_artifact_rows = 4
  local_upstream_identity_artifact_rows = 12
  local_upstream_artifact_rows = 32
  real_source_declared_rows = 4
  non_fixture_declared_rows = 4
  source_import_verified = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-local-upstream-artifact

v08-l/v08-s fully remote-style source-import guard:
  final_review_source = provided-csv
  review_rows = 4
  review_artifact_rows = 4
  review_hash_verified_rows = 4
  local_final_review_artifact_rows = 0
  nonlocal_final_review_artifact_rows = 4
  local_reviewer_identity_rows = 0
  nonlocal_reviewer_identity_rows = 4
  local_reviewer_conflict_rows = 0
  nonlocal_reviewer_conflict_rows = 4
  local_upstream_artifact_rows = 0
  real_source_declared_rows = 4
  non_fixture_declared_rows = 4
  source_import_independent_live_review_ready = 1
  source_import_authoritative_review_ready = 1
  source_import_public_registry_ready = 1
  source_import_live_registry_query_ready = 1
  source_import_verified = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-query-fixture-only

v08-m remote-style source-import contract fixture:
  source_import_source = provided-csv
  attestor_identity_verified = 1
  source_import_rows = 4
  artifact_uri_match_rows = 4
  critical_hash_match_rows = 4
  import_ready_rows = 4
  import_artifact_rows = 12
  import_hash_verified_rows = 12
  local_import_artifact_rows = 0
  nonlocal_import_artifact_rows = 12
  live_network_import_rows = 4
  offline_replay_rows = 0
  real_source_import_declared_rows = 4
  non_fixture_declared_rows = 4
  independent_import_reviewed_rows = 4
  source_import_contract_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-real-verifier-missing

v08-n runner-owned source-import verifier replay fixture:
  source_import_verifier_source = runner-owned-replay
  expected_verifier_rows = 4
  expected_verifier_artifacts = 12
  source_import_verifier_rows = 4
  matched_source_import_rows = 4
  source_import_id_match_rows = 4
  import_manifest_hash_match_rows = 4
  import_fetch_log_hash_match_rows = 4
  reviewer_identity_hash_match_rows = 4
  benchmark_artifact_uri_match_rows = 4
  verifier_artifact_rows = 12
  verifier_hash_verified_rows = 12
  local_verifier_artifact_rows = 12
  nonlocal_verifier_artifact_rows = 0
  runner_owned_verifier_rows = 4
  source_import_verifier_ready = 1
  live_network_source_import_verified = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-verifier-missing

v08-o supplied live-style source-import verifier fixture:
  source_import_verifier_source = provided-csv
  expected_verifier_rows = 4
  source_import_verifier_rows = 4
  live_network_verifier_rows = 4
  offline_replay_rows = 0
  declared_real_verifier_rows = 4
  non_fixture_declared_rows = 4
  source_import_verifier_ready = 1
  source_import_live_verifier_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-independent-live-review-missing

v08-p supplied source-import live-review fixture:
  live_review_source = provided-csv
  review_rows = 4
  matched_verifier_rows = 4
  source_import_id_match_rows = 4
  verifier_run_id_match_rows = 4
  verifier_hash_match_rows = 4
  import_hash_match_rows = 4
  local_live_review_artifact_rows = 0
  nonlocal_live_review_artifact_rows = 12
  source_import_independent_live_review_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-authoritative-live-review-missing

v08-q supplied source-import authoritative-review fixture:
  authority_review_source = provided-csv
  authority_review_rows = 4
  matched_live_review_rows = 4
  source_import_id_match_rows = 4
  verifier_run_id_match_rows = 4
  live_review_id_match_rows = 4
  live_review_hash_match_rows = 4
  verifier_hash_match_rows = 4
  authority_metadata_rows = 4
  local_authority_artifact_rows = 0
  nonlocal_authority_artifact_rows = 16
  independent_authority_rows = 4
  authority_review_approved_rows = 4
  source_import_authoritative_review_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-real-public-registry-missing

v08-r supplied source-import public-registry fixture:
  public_registry_source = provided-csv
  public_registry_rows = 4
  matched_authority_review_rows = 4
  source_import_id_match_rows = 4
  verifier_run_id_match_rows = 4
  live_review_id_match_rows = 4
  authority_review_id_match_rows = 4
  authority_review_hash_match_rows = 4
  verifier_hash_match_rows = 4
  local_registry_artifact_rows = 0
  nonlocal_registry_artifact_rows = 16
  registry_approved_rows = 4
  source_import_public_registry_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-query-missing

v08-s runner-owned source-import live-registry-query replay fixture:
  live_registry_query_source = runner-owned-replay
  registry_query_rows = 4
  matched_public_registry_rows = 4
  query_tool_hash_verified_rows = 4
  query_output_hash_match_rows = 4
  runner_owned_registry_query_ready = 1
  network_query_rows = 0
  offline_replay_rows = 4
  source_import_live_registry_query_ready = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-network-fetch-missing

v08-s supplied live-style source-import live-registry-query fixture:
  live_registry_query_source = provided-csv
  registry_query_rows = 4
  matched_public_registry_rows = 4
  query_tool_hash_verified_rows = 4
  query_output_hash_match_rows = 4
  runner_owned_registry_query_ready = 1
  network_query_rows = 4
  offline_replay_rows = 0
  source_import_live_registry_query_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-query-fixture-only

v08-t runner-owned source-import live-registry fetch replay fixture:
  live_registry_fetch_source = runner-owned-replay
  fetch_rows = 4
  matched_query_rows = 4
  cache_hash_match_rows = 4
  registry_cache_hash_verified_rows = 4
  registry_entry_cache_hash_verified_rows = 4
  source_import_live_registry_fetcher_ready = 1
  network_fetch_rows = 0
  offline_replay_rows = 4
  source_import_live_registry_fetch_ready = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-network-fetch-proof-missing

v08-t supplied live-style source-import live-registry fetch fixture:
  live_registry_fetch_source = provided-csv
  fetch_rows = 4
  matched_query_rows = 4
  cache_hash_match_rows = 4
  registry_cache_hash_verified_rows = 4
  registry_entry_cache_hash_verified_rows = 4
  source_import_live_registry_fetcher_ready = 1
  network_fetch_rows = 4
  offline_replay_rows = 0
  source_import_live_registry_fetch_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-fetch-fixture-only

v08-u runner-owned source-import live-registry network-proof replay fixture:
  live_registry_network_proof_source = runner-owned-replay
  network_proof_rows = 4
  matched_fetch_rows = 4
  body_hash_match_rows = 4
  registry_cache_hash_verified_rows = 4
  registry_entry_cache_hash_verified_rows = 4
  source_import_live_registry_network_proof_runner_ready = 1
  network_fetch_rows = 0
  offline_replay_rows = 4
  source_import_live_registry_network_proof_ready = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-network-proof-nonlive

v08-u supplied live-style source-import live-registry network-proof fixture:
  live_registry_network_proof_source = provided-csv
  network_proof_rows = 4
  matched_fetch_rows = 4
  body_hash_match_rows = 4
  registry_cache_hash_verified_rows = 4
  registry_entry_cache_hash_verified_rows = 4
  source_import_live_registry_network_proof_runner_ready = 1
  network_fetch_rows = 4
  offline_replay_rows = 0
  source_import_live_registry_network_proof_ready = 1
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-live-registry-network-proof-fixture-only

v08-v supplied placeholder-domain source-import real verification fixture:
  source_import_real_verification_source = provided-csv
  real_verification_rows = 4
  matched_proof_rows = 4
  hash_match_rows = 4
  artifact_metadata_rows = 4
  nonplaceholder_artifact_rows = 0
  hash_attestation_rows = 4
  official_external_registry_rows = 4
  independent_verifier_rows = 4
  live_network_observed_rows = 4
  source_import_real_verification_review_ready = 1
  source_import_real_verification_ready = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-real-verification-placeholder-domain

v08-w supplied fixture source-import official authority fixture:
  source_import_official_authority_source = provided-csv
  official_authority_rows = 4
  matched_verification_rows = 4
  verification_report_hash_match_rows = 4
  authority_artifact_rows = 4
  nonplaceholder_authority_artifact_rows = 4
  authority_hash_attestation_rows = 4
  authority_domain_match_rows = 4
  canonical_benchmark_rows = 4
  official_trust_root_rows = 4
  independent_authority_review_rows = 4
  live_authority_observed_rows = 4
  source_import_official_authority_review_ready = 1
  source_import_official_authority_ready = 0
  source_import_verified = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-import-official-authority-fixture-only

v08-x supplied fixture result authority fixture:
  external_benchmark_result_authority_source = provided-csv
  result_authority_rows = 4
  matched_evidence_rows = 4
  matched_execution_rows = 4
  result_uri_match_rows = 4
  provenance_hash_match_rows = 4
  evaluator_output_hash_match_rows = 4
  run_log_hash_match_rows = 4
  metric_value_match_rows = 4
  result_authority_artifact_rows = 4
  nonplaceholder_result_authority_artifact_rows = 4
  result_authority_hash_attestation_rows = 4
  result_authority_domain_match_rows = 4
  official_leaderboard_rows = 4
  official_metric_rows = 4
  independent_result_review_rows = 4
  live_result_observed_rows = 4
  external_benchmark_result_authority_review_ready = 1
  external_benchmark_result_authority_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-result-authority-fixture-only

v08-y supplied fixture publication package fixture:
  external_benchmark_publication_source = provided-csv
  benchmark_comparison_ready = 1
  publishable_comparison_ready = 0
  publication_rows = 4
  matched_result_authority_rows = 4
  matched_comparison_rows = 4
  leaderboard_match_rows = 4
  result_record_match_rows = 4
  metric_definition_match_rows = 4
  evaluation_protocol_match_rows = 4
  comparison_delta_match_rows = 4
  comparison_verdict_match_rows = 4
  publication_artifact_rows = 4
  nonplaceholder_publication_artifact_rows = 4
  publication_hash_attestation_rows = 4
  publication_domain_match_rows = 4
  reproducibility_bundle_rows = 4
  independent_publication_review_rows = 4
  live_publication_observed_rows = 4
  declared_real_publication_rows = 4
  non_fixture_declared_rows = 0
  external_benchmark_publication_review_ready = 1
  external_benchmark_publication_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-publication-fixture-only

v08-z supplied fixture source acquisition fixture:
  external_benchmark_source_acquisition_source = provided-csv
  acquisition_rows = 4
  matched_adapter_rows = 4
  nonplaceholder_domain_rows = 4
  remote_uri_rows = 4
  hash_attestation_rows = 4
  acquisition_method_rows = 4
  live_acquisition_observed_rows = 4
  independent_source_review_rows = 4
  declared_real_source_rows = 4
  non_fixture_declared_rows = 0
  external_benchmark_source_acquisition_review_ready = 1
  external_benchmark_source_acquisition_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-acquisition-fixture-only

v08-z supplied non-fixture source acquisition package:
  external_benchmark_source_acquisition_review_ready = 1
  external_benchmark_source_acquisition_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-source-acquisition-ready-await-import

v08-aa supplied source acquisition content cache fixture:
  source_acquisition_ready = 1
  source_acquisition_content_source = provided-csv
  content_rows = 4
  matched_acquisition_rows = 4
  acquisition_id_match_rows = 4
  remote_uri_match_rows = 4
  hash_manifest_match_rows = 4
  required_content_fields = 24
  cache_uri_fields = 24
  content_hash_verified_fields = 24
  fetch_manifest_ready_rows = 4
  content_cache_ready_rows = 4
  independent_content_review_rows = 4
  declared_real_content_rows = 4
  non_fixture_declared_rows = 4
  external_benchmark_source_acquisition_content_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-source-acquisition-content-ready-await-import

v08-aa supplied bad-hash source acquisition content fixture:
  hash_manifest_match_rows = 3
  content_hash_verified_fields = 23
  external_benchmark_source_acquisition_content_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-source-acquisition-content-hash-manifest-mismatch

v08-ab generated codebase-mini package:
  benchmark_scope = route-memory-v08ab
  benchmark_family = codebase-retrieval
  artifact_source = generated-local-codebase
  source_manifest_ready = 1
  dataset_ready = 1
  split_manifest_ready = 1
  license_ready = 1
  metric_spec_ready = 1
  baseline_artifact_rows = 3
  result_artifact_rows = 2
  artifact_hash_manifest_entries = 10
  artifact_hash_verified_files = 10
  source_file_rows = 4
  source_hash_verified_rows = 4
  dataset_rows = 7
  present_queries = 5
  missing_queries = 1
  near_miss_queries = 1
  multi_hop_queries = 1
  route_memory_artifact_chain_verified = 1
  codebase_mini_source_ready = 1
  benchmark_result_artifact_verified = 1
  baseline_comparison_ready = 1
  real_codebase_declared = 1
  external_source_rows = 0
  local_source_rows = 4
  span_exact = 1.000000
  chunk_exact = 1.000000
  missing_abstain = 1.000000
  near_miss_false_positive = 0.000000
  wrong_answer_rate = 0.000000
  duplicate_latest_rate = 0.000000
  ssd_bytes_per_query > 0
  real_external_benchmark_verified = 0
  action = codebase-mini-result-ready-await-review

v08-ab bad-hash codebase-mini guard:
  artifact_source = provided-dir
  artifact_hash_manifest_entries = 10
  artifact_hash_verified_files = 9
  codebase_mini_source_ready = 1
  benchmark_result_artifact_verified = 0
  baseline_comparison_ready = 0
  real_external_benchmark_verified = 0
  action = codebase-mini-artifact-hash-mismatch

v08-ac supplied content/result bridge:
  source_content_ready = 1
  source_content_rows = 4
  codebase_mini_source_ready = 1
  codebase_result_artifact_verified = 1
  codebase_baseline_comparison_ready = 1
  bridge_rows = 1
  acquisition_id_match_rows = 1
  bridge_hash_verified_fields = 5
  source_content_bound_rows = 1
  result_artifact_bound_rows = 1
  baseline_bound_rows = 1
  dataset_bound_rows = 1
  independent_bridge_review_rows = 1
  local_artifact_uri_fields = 5
  bridge_family_coverage = 1
  expected_external_families = 4
  codebase_content_result_bridge_ready = 1
  external_benchmark_result_bridge_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-content-result-bridge-ready-await-external-family-results

v08-ac bad-hash content/result bridge guard:
  bridge_hash_verified_fields = 4
  codebase_content_result_bridge_ready = 0
  action = external-benchmark-content-result-bridge-hash-mismatch

v08-ad supplied all-family result bridge:
  source_content_ready = 1
  source_content_rows = 4
  source_content_family_rows = 4
  bridge_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  acquisition_id_match_rows = 4
  content_summary_hash_verified_rows = 4
  required_result_hash_fields = 28
  result_hash_attested_fields = 28
  nonlocal_result_uri_fields = 28
  local_result_uri_fields = 0
  bridge_family_coverage = 4
  expected_external_families = 4
  family_result_bridge_review_ready = 1
  external_benchmark_result_bridge_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-family-result-bridge-ready-await-independent-reproduction

v08-ad bad-hash/local-result guards:
  bad_hash_action = external-benchmark-family-result-bridge-hash-attestation-missing
  local_result_action = external-benchmark-family-result-bridge-local-result-artifact-uri
  family_result_bridge_review_ready = 0
  real_external_benchmark_verified = 0

v08-ae supplied independent reproduction/review:
  family_result_bridge_review_ready = 1
  external_benchmark_result_bridge_ready = 1
  result_bridge_rows = 4
  bridge_family_rows = 4
  reproduction_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  acquisition_id_match_rows = 4
  result_artifact_match_rows = 4
  result_bridge_summary_hash_verified_rows = 4
  required_reproduction_hash_fields = 28
  reproduction_hash_attested_fields = 28
  nonlocal_reproduction_uri_fields = 28
  local_reproduction_uri_fields = 0
  independent_reproduction_review_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-independent-reproduction-ready-await-official-release-evidence

v08-ae bad-hash/local-reproduction guards:
  bad_hash_action = external-benchmark-independent-reproduction-hash-attestation-missing
  local_reproduction_action = external-benchmark-independent-reproduction-local-artifact-uri
  independent_reproduction_review_ready = 0
  real_external_benchmark_verified = 0

v08-af supplied official release evidence:
  independent_reproduction_review_ready = 1
  reproduction_family_rows = 4
  release_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_reproduction_family_rows = 4
  reproduction_id_match_rows = 4
  independent_reproduction_summary_hash_verified_rows = 4
  required_release_hash_fields = 44
  release_hash_attested_fields = 44
  required_release_uri_fields = 40
  nonlocal_release_uri_fields = 40
  local_release_uri_fields = 0
  official_release_evidence_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-official-release-evidence-ready-await-live-release-verification

v08-af bad-hash/local-release/reproduction-mismatch guards:
  bad_hash_action = external-benchmark-official-release-hash-attestation-missing
  local_release_action = external-benchmark-official-release-local-artifact-uri
  reproduction_mismatch_action = external-benchmark-official-release-reproduction-mismatch
  official_release_evidence_ready = 0
  real_external_benchmark_verified = 0

v08-ag supplied live release verification:
  official_release_evidence_ready = 1
  release_family_rows = 4
  live_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_release_family_rows = 4
  reproduction_id_match_rows = 4
  release_id_match_rows = 4
  official_release_match_rows = 4
  public_archive_match_rows = 4
  dataset_version_match_rows = 4
  release_authority_match_rows = 4
  required_live_hash_fields = 28
  live_hash_attested_fields = 28
  required_live_uri_fields = 28
  nonlocal_live_uri_fields = 28
  local_live_uri_fields = 0
  live_network_observed_rows = 4
  independent_verifier_declared_rows = 4
  stable_release_observed_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  official_release_live_verification_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-live-release-verification-ready-await-canonical-online-confirmation

v08-ag bad-hash/local-live/release-mismatch/fixture guards:
  bad_hash_action = external-benchmark-live-release-hash-attestation-missing
  local_live_action = external-benchmark-live-release-local-artifact-uri
  release_mismatch_action = external-benchmark-live-release-binding-mismatch
  fixture_only_action = external-benchmark-live-release-declaration-missing
  official_release_live_verification_ready = 0
  real_external_benchmark_verified = 0

v08-ah supplied canonical online confirmation:
  official_release_live_verification_ready = 1
  live_family_rows = 4
  confirmation_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_live_family_rows = 4
  reproduction_id_match_rows = 4
  release_id_match_rows = 4
  live_report_match_rows = 4
  network_observation_match_rows = 4
  verifier_identity_match_rows = 4
  required_confirmation_hash_fields = 36
  confirmation_hash_attested_fields = 36
  required_confirmation_uri_fields = 36
  nonlocal_confirmation_uri_fields = 36
  local_confirmation_uri_fields = 0
  runner_owned_confirmation_declared_rows = 4
  canonical_authority_observed_rows = 4
  online_fetch_declared_rows = 4
  content_digest_match_declared_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  canonical_online_confirmation_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-canonical-online-confirmation-ready-await-nonfixture-publication-result-review

v08-ah bad-hash/local-confirmation/release-mismatch/fixture guards:
  bad_hash_action = external-benchmark-canonical-online-confirmation-hash-attestation-missing
  local_confirmation_action = external-benchmark-canonical-online-confirmation-local-artifact-uri
  release_mismatch_action = external-benchmark-canonical-online-confirmation-binding-mismatch
  fixture_only_action = external-benchmark-canonical-online-confirmation-declaration-missing
  canonical_online_confirmation_ready = 0
  real_external_benchmark_verified = 0

v08-ai supplied publication/result review:
  canonical_online_confirmation_ready = 1
  canonical_family_rows = 4
  review_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_canonical_family_rows = 4
  reproduction_id_match_rows = 4
  release_id_match_rows = 4
  canonical_confirmation_match_rows = 4
  content_digest_match_rows = 4
  required_review_hash_fields = 36
  review_hash_attested_fields = 36
  required_review_uri_fields = 36
  nonlocal_review_uri_fields = 36
  local_review_uri_fields = 0
  required_new_review_uri_fields = 28
  nonplaceholder_new_review_uri_fields = 28
  placeholder_new_review_uri_fields = 0
  canonical_confirmation_bound_rows = 4
  content_digest_manifest_bound_rows = 4
  publication_review_bound_rows = 4
  result_review_bound_rows = 4
  publication_record_bound_rows = 4
  result_record_bound_rows = 4
  reviewer_identity_bound_rows = 4
  publication_authority_bound_rows = 4
  result_authority_bound_rows = 4
  independent_review_declared_rows = 4
  publication_observed_declared_rows = 4
  result_observed_declared_rows = 4
  canonical_result_match_declared_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  publication_result_review_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-publication-result-review-ready-await-live-ingestion-promotion-evidence

v08-ai bad-hash/local-review/placeholder-review/release-mismatch/fixture guards:
  bad_hash_action = external-benchmark-publication-result-review-hash-attestation-missing
  local_review_action = external-benchmark-publication-result-review-local-artifact-uri
  placeholder_review_action = external-benchmark-publication-result-review-placeholder-artifact-uri
  release_mismatch_action = external-benchmark-publication-result-review-binding-mismatch
  fixture_only_action = external-benchmark-publication-result-review-declaration-missing
  publication_result_review_ready = 0
  real_external_benchmark_verified = 0

v08-aj supplied live publication/result ingestion:
  publication_result_review_ready = 1
  review_family_rows = 4
  ingestion_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_review_family_rows = 4
  reproduction_id_match_rows = 4
  release_id_match_rows = 4
  publication_review_match_rows = 4
  result_review_match_rows = 4
  publication_record_match_rows = 4
  result_record_match_rows = 4
  required_ingestion_hash_fields = 56
  ingestion_hash_attested_fields = 56
  required_ingestion_uri_fields = 56
  nonlocal_ingestion_uri_fields = 56
  local_ingestion_uri_fields = 0
  required_new_ingestion_uri_fields = 40
  nonplaceholder_new_ingestion_uri_fields = 40
  placeholder_new_ingestion_uri_fields = 0
  publication_review_bound_rows = 4
  result_review_bound_rows = 4
  publication_record_bound_rows = 4
  result_record_bound_rows = 4
  live_publication_record_bound_rows = 4
  live_result_record_bound_rows = 4
  publication_ingest_transcript_bound_rows = 4
  result_ingest_transcript_bound_rows = 4
  publication_response_header_bound_rows = 4
  result_response_header_bound_rows = 4
  publication_content_digest_bound_rows = 4
  result_content_digest_bound_rows = 4
  publication_tls_certificate_chain_bound_rows = 4
  result_tls_certificate_chain_bound_rows = 4
  runner_owned_ingestion_declared_rows = 4
  live_network_ingestion_declared_rows = 4
  publication_record_digest_match_declared_rows = 4
  result_record_digest_match_declared_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  live_publication_result_ingestion_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-live-publication-result-ingestion-ready-await-promotion-authority-evidence

v08-aj bad-hash/local-ingestion/placeholder-ingestion/release-mismatch/fixture guards:
  bad_hash_action = external-benchmark-live-publication-result-ingestion-hash-attestation-missing
  local_ingestion_action = external-benchmark-live-publication-result-ingestion-local-artifact-uri
  placeholder_ingestion_action = external-benchmark-live-publication-result-ingestion-placeholder-artifact-uri
  release_mismatch_action = external-benchmark-live-publication-result-ingestion-binding-mismatch
  fixture_only_action = external-benchmark-live-publication-result-ingestion-declaration-missing
  live_publication_result_ingestion_ready = 0
  real_external_benchmark_verified = 0

v08-ak supplied authority/promotion evidence:
  live_publication_result_ingestion_ready = 1
  ingestion_family_rows = 4
  authority_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  matched_ingestion_family_rows = 4
  reproduction_id_match_rows = 4
  release_id_match_rows = 4
  live_publication_record_match_rows = 4
  live_result_record_match_rows = 4
  publication_content_digest_match_rows = 4
  result_content_digest_match_rows = 4
  required_authority_hash_fields = 56
  authority_hash_attested_fields = 56
  required_authority_uri_fields = 56
  nonlocal_authority_uri_fields = 56
  local_authority_uri_fields = 0
  required_new_authority_uri_fields = 40
  nonplaceholder_new_authority_uri_fields = 40
  placeholder_new_authority_uri_fields = 0
  live_publication_record_bound_rows = 4
  live_result_record_bound_rows = 4
  publication_content_digest_bound_rows = 4
  result_content_digest_bound_rows = 4
  authority_decision_bound_rows = 4
  promotion_review_bound_rows = 4
  benchmark_registry_entry_bound_rows = 4
  leaderboard_entry_bound_rows = 4
  reproducibility_package_bound_rows = 4
  artifact_archive_bound_rows = 4
  authority_identity_bound_rows = 4
  authority_conflict_disclosure_bound_rows = 4
  promotion_trace_bound_rows = 4
  final_claim_packet_bound_rows = 4
  independent_authority_declared_rows = 4
  official_result_authority_declared_rows = 4
  benchmark_owner_registry_declared_rows = 4
  publication_result_consistent_declared_rows = 4
  claim_scope_limited_declared_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  authority_promotion_evidence_ready = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-authority-promotion-evidence-ready-await-real-external-benchmark-run-evidence

v08-ak bad-hash/local-authority/placeholder-authority/release-mismatch/fixture guards:
  bad_hash_action = external-benchmark-authority-promotion-evidence-hash-attestation-missing
  local_authority_action = external-benchmark-authority-promotion-evidence-local-artifact-uri
  placeholder_authority_action = external-benchmark-authority-promotion-evidence-placeholder-artifact-uri
  release_mismatch_action = external-benchmark-authority-promotion-evidence-binding-mismatch
  fixture_only_action = external-benchmark-authority-promotion-evidence-declaration-missing
  authority_promotion_evidence_ready = 0
  real_external_benchmark_verified = 0

v08-al local codebase run/evaluator trace:
  authority_promotion_evidence_ready = 1
  codebase_mini_source_ready = 1
  benchmark_result_artifact_verified = 1
  baseline_comparison_ready = 1
  trace_artifact_files = 6
  trace_hash_manifest_entries = 6
  trace_hash_verified_files = 6
  dataset_rows = 7
  result_rows = 7
  query_trace_rows = 7
  evaluator_output_rows = 7
  matched_query_rows = 7
  dataset_bound_rows = 7
  result_bound_rows = 7
  runner_owned_evaluator_rows = 7
  independent_evaluator_rows = 0
  metric_rows = 5
  span_exact = 1.000000
  chunk_exact = 1.000000
  missing_abstain = 1.000000
  near_miss_false_positive = 0.000000
  wrong_answer_rate = 0.000000
  metrics_match_rows = 5
  codebase_run_evaluator_trace_ready = 1
  external_family_coverage = 1
  expected_external_families = 4
  external_benchmark_run_evaluator_trace_ready = 0
  real_external_benchmark_verified = 0
  action = codebase-run-evaluator-trace-ready-await-independent-all-family-run-evidence

v08-al bad-hash/query-binding/metric guards:
  bad_hash_action = external-benchmark-run-evaluator-trace-hash-mismatch
  bad_query_action = external-benchmark-run-evaluator-trace-query-binding-mismatch
  bad_metric_action = external-benchmark-run-evaluator-trace-metric-mismatch
  codebase_run_evaluator_trace_ready = 0
  real_external_benchmark_verified = 0

v08-am supplied independent all-family run/evaluator evidence:
  upstream_codebase_run_evaluator_trace_ready = 1
  upstream_authority_promotion_evidence_ready = 1
  evidence_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_evidence_uri_fields = 28
  nonlocal_evidence_uri_fields = 28
  local_evidence_uri_fields = 0
  nonplaceholder_evidence_uri_fields = 28
  required_evidence_hash_fields = 28
  evidence_hash_attested_fields = 28
  total_query_rows = 256
  min_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  trace_bound_rows = 4
  evaluator_bound_rows = 4
  metrics_bound_rows = 4
  authority_bound_rows = 4
  independent_evaluator_declared_rows = 4
  official_metric_declared_rows = 4
  all_queries_bound_declared_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_independent_run_evaluator_evidence_ready = 1
  real_external_benchmark_verified = 0
  action = independent-run-evaluator-evidence-ready-await-live-replay-or-final-review
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-am bad coverage/placeholder/metric/declaration/jump guards:
  bad_coverage_action = external-benchmark-independent-run-evaluator-evidence-coverage-incomplete
  bad_placeholder_action = external-benchmark-independent-run-evaluator-evidence-placeholder-artifact-uri
  bad_metric_action = external-benchmark-independent-run-evaluator-evidence-quality-threshold-missing
  bad_declaration_action = external-benchmark-independent-run-evaluator-evidence-declaration-missing
  bad_jump_action = external-benchmark-independent-run-evaluator-evidence-jump-guardrail-violated
  external_benchmark_independent_run_evaluator_evidence_ready = 0
  real_external_benchmark_verified = 0

v08-an supplied live replay/final review mechanics:
  upstream_independent_run_evaluator_evidence_ready = 1
  upstream_real_external = 0
  review_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_replay_review_uri_fields = 32
  nonlocal_replay_review_uri_fields = 32
  local_replay_review_uri_fields = 0
  nonplaceholder_replay_review_uri_fields = 32
  required_replay_review_hash_fields = 32
  replay_review_hash_attested_fields = 32
  total_replayed_query_rows = 256
  min_replayed_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  v08am_evidence_bound_rows = 4
  all_queries_replayed_rows = 4
  metrics_recomputed_rows = 4
  live_replay_declared_rows = 4
  runner_owned_replay_declared_rows = 4
  network_observed_declared_rows = 4
  final_review_approved_rows = 4
  independent_final_reviewer_declared_rows = 4
  public_registry_bound_rows = 4
  non_fixture_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_live_replay_final_review_ready = 1
  real_external_benchmark_verified = 0
  action = live-replay-final-review-ready-await-public-nonfixture-verification
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-an bad coverage/placeholder/metric/binding/replay-declaration/review-declaration/jump guards:
  bad_coverage_action = external-benchmark-live-replay-final-review-coverage-incomplete
  bad_placeholder_action = external-benchmark-live-replay-final-review-placeholder-artifact-uri
  bad_metric_action = external-benchmark-live-replay-final-review-quality-threshold-missing
  bad_binding_action = external-benchmark-live-replay-final-review-binding-missing
  bad_replay_declaration_action = external-benchmark-live-replay-final-review-replay-declaration-missing
  bad_review_declaration_action = external-benchmark-live-replay-final-review-review-declaration-missing
  bad_jump_action = external-benchmark-live-replay-final-review-jump-guardrail-violated
  external_benchmark_live_replay_final_review_ready = 0
  real_external_benchmark_verified = 0

v08-ao supplied public non-fixture/direct-run verification mechanics:
  upstream_live_replay_final_review_ready = 1
  upstream_real_external = 0
  verification_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_public_verification_uri_fields = 40
  nonlocal_public_verification_uri_fields = 40
  local_public_verification_uri_fields = 0
  nonplaceholder_public_verification_uri_fields = 40
  required_public_verification_hash_fields = 40
  public_verification_hash_attested_fields = 40
  total_verified_query_rows = 256
  min_verified_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  v08an_review_bound_rows = 4
  public_nonfixture_verification_declared_rows = 4
  public_artifact_registry_declared_rows = 4
  direct_runner_owned_run_declared_rows = 4
  direct_external_dataset_declared_rows = 4
  direct_evaluator_execution_declared_rows = 4
  live_network_fetch_declared_rows = 4
  third_party_reviewer_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_public_nonfixture_verification_ready = 1
  real_external_benchmark_verified = 0
  action = public-nonfixture-verification-ready-await-runner-owned-live-execution-audit
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-ao bad coverage/placeholder/metric/binding/public-declaration/direct-declaration/jump guards:
  bad_coverage_action = external-benchmark-public-nonfixture-verification-coverage-incomplete
  bad_placeholder_action = external-benchmark-public-nonfixture-verification-placeholder-artifact-uri
  bad_metric_action = external-benchmark-public-nonfixture-verification-quality-threshold-missing
  bad_binding_action = external-benchmark-public-nonfixture-verification-binding-missing
  bad_public_declaration_action = external-benchmark-public-nonfixture-verification-public-declaration-missing
  bad_direct_declaration_action = external-benchmark-public-nonfixture-verification-direct-run-declaration-missing
  bad_jump_action = external-benchmark-public-nonfixture-verification-jump-guardrail-violated
  external_benchmark_public_nonfixture_verification_ready = 0
  real_external_benchmark_verified = 0

v08-ap supplied runner-owned live execution/audit mechanics:
  upstream_public_nonfixture_verification_ready = 1
  upstream_real_external = 0
  audit_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_live_execution_audit_uri_fields = 52
  nonlocal_live_execution_audit_uri_fields = 52
  local_live_execution_audit_uri_fields = 0
  nonplaceholder_live_execution_audit_uri_fields = 52
  required_live_execution_audit_hash_fields = 52
  live_execution_audit_hash_attested_fields = 52
  total_executed_query_rows = 256
  min_executed_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  v08ao_verification_bound_rows = 4
  runner_owned_execution_declared_rows = 4
  live_network_execution_declared_rows = 4
  external_dataset_live_fetch_declared_rows = 4
  evaluator_invoked_by_runner_declared_rows = 4
  replay_disabled_declared_rows = 4
  audit_log_complete_declared_rows = 4
  third_party_audit_review_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_runner_owned_live_execution_audit_ready = 1
  real_external_benchmark_verified = 0
  action = runner-owned-live-execution-audit-ready-await-independent-live-rerun-confirmation
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-ap bad coverage/placeholder/metric/binding/runner-declaration/live-declaration/audit-declaration/jump guards:
  bad_coverage_action = external-benchmark-runner-owned-live-execution-audit-coverage-incomplete
  bad_placeholder_action = external-benchmark-runner-owned-live-execution-audit-placeholder-artifact-uri
  bad_metric_action = external-benchmark-runner-owned-live-execution-audit-quality-threshold-missing
  bad_binding_action = external-benchmark-runner-owned-live-execution-audit-binding-missing
  bad_runner_declaration_action = external-benchmark-runner-owned-live-execution-audit-runner-declaration-missing
  bad_live_declaration_action = external-benchmark-runner-owned-live-execution-audit-live-execution-declaration-missing
  bad_audit_declaration_action = external-benchmark-runner-owned-live-execution-audit-audit-declaration-missing
  bad_jump_action = external-benchmark-runner-owned-live-execution-audit-jump-guardrail-violated
  external_benchmark_runner_owned_live_execution_audit_ready = 0
  real_external_benchmark_verified = 0

v08-aq supplied independent live rerun confirmation mechanics:
  upstream_runner_owned_live_execution_audit_ready = 1
  upstream_real_external = 0
  confirmation_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_live_rerun_confirmation_uri_fields = 60
  nonlocal_live_rerun_confirmation_uri_fields = 60
  local_live_rerun_confirmation_uri_fields = 0
  nonplaceholder_live_rerun_confirmation_uri_fields = 60
  required_live_rerun_confirmation_hash_fields = 60
  live_rerun_confirmation_hash_attested_fields = 60
  total_rerun_query_rows = 256
  min_rerun_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  metric_delta_pass_rows = 4
  v08ap_audit_bound_rows = 4
  independent_runner_declared_rows = 4
  independent_environment_declared_rows = 4
  live_network_rerun_declared_rows = 4
  external_dataset_refetch_declared_rows = 4
  evaluator_reinvoked_declared_rows = 4
  audit_receipt_reconciled_declared_rows = 4
  metric_recomputed_declared_rows = 4
  third_party_confirmation_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_independent_live_rerun_confirmation_ready = 1
  real_external_benchmark_verified = 0
  action = independent-live-rerun-confirmation-ready-await-real-nonfixture-benchmark-run-package
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-aq bad coverage/placeholder/metric/delta/binding/independent-declaration/live-declaration/reconciliation-declaration/jump guards:
  bad_coverage_action = external-benchmark-independent-live-rerun-confirmation-coverage-incomplete
  bad_placeholder_action = external-benchmark-independent-live-rerun-confirmation-placeholder-artifact-uri
  bad_metric_action = external-benchmark-independent-live-rerun-confirmation-quality-threshold-missing
  bad_delta_action = external-benchmark-independent-live-rerun-confirmation-metric-delta-too-large
  bad_binding_action = external-benchmark-independent-live-rerun-confirmation-binding-missing
  bad_independent_declaration_action = external-benchmark-independent-live-rerun-confirmation-independent-declaration-missing
  bad_live_declaration_action = external-benchmark-independent-live-rerun-confirmation-live-rerun-declaration-missing
  bad_reconciliation_declaration_action = external-benchmark-independent-live-rerun-confirmation-reconciliation-declaration-missing
  bad_jump_action = external-benchmark-independent-live-rerun-confirmation-jump-guardrail-violated
  external_benchmark_independent_live_rerun_confirmation_ready = 0
  real_external_benchmark_verified = 0

v08-ar supplied real nonfixture run package intake mechanics:
  upstream_independent_live_rerun_confirmation_ready = 1
  upstream_real_external = 0
  package_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_run_package_uri_fields = 60
  nonlocal_run_package_uri_fields = 60
  local_run_package_uri_fields = 0
  nonplaceholder_run_package_uri_fields = 60
  required_run_package_hash_fields = 60
  run_package_hash_attested_fields = 60
  total_packaged_query_rows = 256
  min_packaged_query_rows_pass_rows = 4
  metric_threshold_pass_rows = 4
  metric_delta_pass_rows = 4
  v08aq_confirmation_bound_rows = 4
  run_package_nonfixture_declared_rows = 4
  official_benchmark_declared_rows = 4
  public_archive_declared_rows = 4
  raw_query_set_declared_rows = 4
  raw_prediction_output_declared_rows = 4
  evaluator_container_declared_rows = 4
  immutable_archive_declared_rows = 4
  license_review_declared_rows = 4
  pii_review_declared_rows = 4
  third_party_reproducibility_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_real_nonfixture_run_package_intake_ready = 1
  real_external_benchmark_verified = 0
  action = real-nonfixture-run-package-intake-ready-await-live-package-artifact-fetch
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-ar bad coverage/placeholder/metric/delta/binding/package-declaration/review-declaration/jump guards:
  bad_coverage_action = external-benchmark-real-nonfixture-run-package-coverage-incomplete
  bad_placeholder_action = external-benchmark-real-nonfixture-run-package-placeholder-artifact-uri
  bad_metric_action = external-benchmark-real-nonfixture-run-package-quality-threshold-missing
  bad_delta_action = external-benchmark-real-nonfixture-run-package-metric-delta-too-large
  bad_binding_action = external-benchmark-real-nonfixture-run-package-binding-missing
  bad_package_declaration_action = external-benchmark-real-nonfixture-run-package-package-declaration-missing
  bad_review_declaration_action = external-benchmark-real-nonfixture-run-package-review-declaration-missing
  bad_jump_action = external-benchmark-real-nonfixture-run-package-jump-guardrail-violated
  external_benchmark_real_nonfixture_run_package_intake_ready = 0
  real_external_benchmark_verified = 0

v08-as supplied live package artifact fetch/authority mechanics:
  upstream_real_nonfixture_run_package_intake_ready = 1
  upstream_real_external = 0
  fetch_rows = 60
  expected_artifact_rows = 60
  expected_family_rows = 60
  unexpected_artifact_type_rows = 0
  duplicate_artifact_rows = 0
  family_coverage = 4
  expected_external_families = 4
  artifact_type_coverage = 60
  expected_artifact_types_per_family = 15
  required_live_fetch_uri_fields = 180
  nonlocal_live_fetch_uri_fields = 180
  local_live_fetch_uri_fields = 0
  nonplaceholder_live_fetch_uri_fields = 180
  required_live_fetch_hash_fields = 180
  live_fetch_hash_attested_fields = 180
  http_status_pass_rows = 60
  content_digest_match_declared_rows = 60
  v08ar_package_intake_bound_rows = 60
  runner_owned_live_fetch_declared_rows = 60
  network_fetch_transcript_declared_rows = 60
  tls_certificate_verified_declared_rows = 60
  dns_resolution_verified_declared_rows = 60
  http_status_verified_declared_rows = 60
  authority_registry_verified_declared_rows = 60
  official_source_authority_verified_declared_rows = 60
  fixture_free_rows = 60
  timestamp_rows = 60
  external_benchmark_live_package_artifact_fetch_authority_ready = 1
  real_external_benchmark_verified = 0
  action = live-package-artifact-fetch-authority-ready-await-official-result-reconciliation
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-as bad coverage/placeholder/status/digest/binding/runner/network/authority/jump guards:
  bad_coverage_action = external-benchmark-live-package-artifact-fetch-coverage-incomplete
  bad_placeholder_action = external-benchmark-live-package-artifact-fetch-placeholder-artifact-uri
  bad_status_action = external-benchmark-live-package-artifact-fetch-http-status-missing
  bad_digest_action = external-benchmark-live-package-artifact-fetch-content-digest-mismatch
  bad_binding_action = external-benchmark-live-package-artifact-fetch-binding-missing
  bad_runner_declaration_action = external-benchmark-live-package-artifact-fetch-runner-declaration-missing
  bad_network_declaration_action = external-benchmark-live-package-artifact-fetch-network-proof-missing
  bad_authority_declaration_action = external-benchmark-live-package-artifact-fetch-authority-verification-missing
  bad_jump_action = external-benchmark-live-package-artifact-fetch-jump-guardrail-violated
  external_benchmark_live_package_artifact_fetch_authority_ready = 0
  real_external_benchmark_verified = 0

v08-at supplied official result reconciliation mechanics:
  upstream_live_package_artifact_fetch_authority_ready = 1
  upstream_real_external = 0
  fetch_artifact_rows_seen = 24
  reconciliation_rows = 4
  expected_reconciliation_rows = 4
  expected_family_rows = 4
  duplicate_family_rows = 0
  family_coverage = 4
  expected_external_families = 4
  required_reconciliation_uri_fields = 28
  nonlocal_reconciliation_uri_fields = 28
  local_reconciliation_uri_fields = 0
  nonplaceholder_reconciliation_uri_fields = 28
  required_reconciliation_hash_fields = 28
  reconciliation_hash_attested_fields = 28
  v08as_live_fetch_authority_bound_rows = 4
  package_identity_match_rows = 4
  artifact_binding_declared_rows = 4
  fetch_artifact_identity_match_rows = 4
  metric_delta_within_tolerance_rows = 4
  query_count_exact_match_rows = 4
  query_count_match_declared_rows = 4
  evaluator_identity_match_declared_rows = 4
  result_digest_match_declared_rows = 4
  official_source_observed_declared_rows = 4
  public_leaderboard_observed_declared_rows = 4
  runner_owned_reconciliation_declared_rows = 4
  fixture_free_rows = 4
  timestamp_rows = 4
  external_benchmark_official_result_reconciliation_ready = 1
  real_external_benchmark_verified = 0
  action = official-result-reconciliation-ready-await-public-real-external-claim
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

v08-at bad coverage/hash/placeholder/package/artifact/metric/query/declaration/official-source/runner/jump guards:
  bad_coverage_action = external-benchmark-official-result-reconciliation-coverage-incomplete
  bad_hash_action = external-benchmark-official-result-reconciliation-hash-attestation-missing
  bad_placeholder_action = external-benchmark-official-result-reconciliation-placeholder-artifact-uri
  bad_package_action = external-benchmark-official-result-reconciliation-package-identity-mismatch
  bad_artifact_binding_action = external-benchmark-official-result-reconciliation-artifact-binding-missing
  bad_artifact_identity_action = external-benchmark-official-result-reconciliation-artifact-identity-mismatch
  bad_metric_action = external-benchmark-official-result-reconciliation-metric-mismatch
  bad_query_action = external-benchmark-official-result-reconciliation-query-count-mismatch
  bad_declaration_action = external-benchmark-official-result-reconciliation-evaluator-or-digest-declaration-missing
  bad_official_source_action = external-benchmark-official-result-reconciliation-official-source-missing
  bad_runner_action = external-benchmark-official-result-reconciliation-runner-declaration-missing
  bad_jump_action = external-benchmark-official-result-reconciliation-jump-guardrail-violated
  external_benchmark_official_result_reconciliation_ready = 0
  real_external_benchmark_verified = 0

v08 lower-chain remote-artifact fixture:
  evidence_source = provided-csv
  dataset_artifact_rows = 4
  local_dataset_uri_rows = 0
  nonlocal_dataset_uri_rows = 4
  result_artifact_rows = 4
  local_result_uri_rows = 0
  nonlocal_result_uri_rows = 4
  artifact_verifier_ready = 1
  execution_source = provided-csv
  local_output_artifact_rows = 0
  nonlocal_output_artifact_rows = 4
  local_run_log_artifact_rows = 0
  nonlocal_run_log_artifact_rows = 4
  evaluator_execution_verified = 1
  attestation_source = provided-csv
  local_attestation_artifact_rows = 0
  nonlocal_attestation_artifact_rows = 4
  independent_attestation_verified = 1
  attestor_identity_source = provided-csv
  local_identity_artifact_rows = 0
  nonlocal_identity_artifact_rows = 4
  local_registry_artifact_rows = 0
  nonlocal_registry_artifact_rows = 4
  local_conflict_disclosure_rows = 0
  nonlocal_conflict_disclosure_rows = 4
  attestor_identity_verified = 1
  real_external_benchmark_verified = 0
  action = external-benchmark-final-review-missing

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

h11-c generated NVMe RouteMemory store smoke:
  artifact_source = generated-fixture
  artifact_files_found = 7
  hash_manifest_entries = 7
  hash_verified_files = 7
  route_memory_store_size_bytes > 0
  route_memory_chunk_count = 3
  route_memory_index_rows = 3
  route_lookup_works = 1
  candidate_span_read_works = 1
  span_exact = 1.000000
  chunk_exact = 1.000000
  missing_abstain = 1.000000
  wrong_answer_rate = 0.000000
  route_memory_artifact_chain_verified = 1
  real_pc_routelm_artifact_verified = 0
  real_external_benchmark_verified = 0
  action = nvme-route-memory-artifact-ready
  routing_trigger_rate = 0.000000
  active_jump_rate = 0.000000

h11-c corrupted NVMe RouteMemory artifact guard:
  artifact_source = provided-dir
  hash_verified_files = 6
  route_memory_artifact_chain_verified = 0
  action = nvme-route-memory-artifact-hash-mismatch

h11-d generated PC RouteLM NLG smoke:
  nlg_source = generated-fixture
  nlg_rows = 3
  diagnostic_artifact_ready = 1
  teacher_off_inference = 1
  retrieved_evidence_used = 1
  evidence_binding_ready = 1
  nlg_quality_ready = 1
  answer_grounded_rate = 1.000000
  span_citation_accuracy = 1.000000
  span_exact = 1.000000
  chunk_exact = 1.000000
  missing_abstain = 1.000000
  wrong_answer_rate = 0.000000
  pc_routelm_nlg_smoke_ready = 1
  real_pc_routelm_nlg_verified = 0
  action = diagnostic-nlg-smoke-ready
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

h9-h generated CPU/HIP/NVMe workload speed smoke:
  workload_source = generated-fixture
  workload_rows = 1
  pc_routelm_nlg_smoke_ready = 1
  real_pc_routelm_nlg_verified = 0
  h9_measured_speed_evidence_ready = 0
  h9_speed_evidence_ready = 0
  workload_artifact_rows = 1
  nlg_result_hash_verified_rows = 1
  timing_artifact_hash_verified_rows = 1
  environment_hash_verified_rows = 1
  metrics_positive_rows = 1
  speedup_positive_rows = 1
  cpu_median_ms = 12.000000
  hip_median_ms = 8.000000
  median_speedup = 1.500000
  nvme_read_median_ms = 0.180000
  query_to_evidence_ms = 0.420000
  query_to_first_token_ms = 4.000000
  tokens_per_second_after_retrieval = 48.666667
  diagnostic_workload_speed_ready = 1
  real_workload_speed_evidence_ready = 0
  gpu_speedup_claim = deferred
  action = real-workload-speed-evidence-missing
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
- h10-p focused gate passed: `bash
  experiments/test_v10_remote_teacher_source_runtime_fetcher.sh`; it is wired
  into `experiments/test_v07_goal_route_memory_closure.sh`.
- h10-q focused gate passed: `bash
  experiments/test_v10_remote_teacher_source_live_network_import_gate.sh`; it is
  wired into `experiments/test_v07_goal_route_memory_closure.sh`.
- h10-r focused gate passed: `bash
  experiments/test_v10_real_teacher_source_import_review.sh`; it is wired into
  `experiments/test_v07_goal_route_memory_closure.sh` and consumed by
  `experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h10-s focused gate passed: `bash
  experiments/test_v10_source_verified_learned_chunk_scorer_eval_gate.sh`; it
  is wired into `experiments/test_v07_goal_route_memory_closure.sh` and
  consumed by `experiments/test_v10_chunk_credit_distillation_gate.sh`.
- h7 goal route-memory closure passed after h7-c wiring: `bash
  experiments/test_v07_goal_route_memory_closure.sh`.
- h7-c focused verification passed: `bash
  experiments/test_v07_route_memory_promotion_review_gate.sh`; it is wired into
  `bash experiments/test_v07_goal_route_memory_closure.sh`.
- v12 focused verification passed: `bash
  experiments/test_v12_paper_release_claim_audit.sh`; it is wired into `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h9 quick GPU/backend closure passed after h7-c wiring: `bash
  experiments/test_v09_gpu_backend_closure.sh`, covering h10-s through h7 plus
  h7-c, v08-ab, h11-d, h9-h, and v12.
- h9-f focused and wrapper verification passed: `build/hip_candidate_weight_parity
  --backend cpu`, `bash experiments/test_v09_gpu_backend_extended_boundary.sh`,
  `bash experiments/test_v09_gpu_backend_speed_evidence.sh`, and `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h9-g focused verification passed: `bash
  experiments/test_v09_gpu_backend_measured_speed_gate.sh` and `bash
  experiments/test_v09_gpu_backend_measured_speed_import.sh`.
- h9-h focused verification passed: `bash
  experiments/test_v09_gpu_backend_real_workload_speed_gate.sh`; it is wired
  into `bash experiments/test_v09_gpu_backend_closure.sh`.
- h11-a focused and wrapper verification passed: `bash
  experiments/test_v11_pc_routelm_prototype_readiness.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_import.sh`, and `bash
  experiments/test_v09_gpu_backend_closure.sh`.
- h11-b focused verification passed: `bash
  experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_artifact_import.sh`, `bash
  experiments/test_v11_pc_routelm_prototype_readiness.sh`, and `bash
  experiments/test_v11_pc_routelm_prototype_import.sh`.
- h11-c focused verification passed: `bash
  experiments/test_v11_nvme_route_memory_store.sh` and `bash
  experiments/test_v11_nvme_route_memory_artifact.sh`.
- h11-d focused verification passed: `bash
  experiments/test_v11_pc_routelm_nlg_smoke.sh`; it is wired into `bash
  experiments/test_v09_gpu_backend_closure.sh`.
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
- Focused v08-l real-source guard verification passed: `bash
  experiments/test_v08_external_benchmark_final_review_real_source_guard.sh`.
- Focused v08-l remote-review guard verification passed: `bash
  experiments/test_v08_external_benchmark_final_review_remote_review_guard.sh`.
- Focused v08-l remote-full source-import guard verification passed: `bash
  experiments/test_v08_external_benchmark_final_review_remote_full_guard.sh`.
- Focused v08-m source-import contract verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_gate.sh` and `bash
  experiments/test_v08_external_benchmark_source_import_remote_contract.sh`.
- Focused v08-n source-import verifier verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_verifier_gate.sh`.
- Focused v08-o live source-import verifier verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_live_verifier_gate.sh`.
- Focused v08-p source-import live-review verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_live_review_gate.sh`.
- Focused v08-q source-import authoritative-review verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh`.
- Focused v08-r source-import public-registry verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_public_registry_gate.sh`.
- Focused v08-s source-import live-registry-query verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_live_registry_query_gate.sh`.
- Focused v08-t source-import live-registry fetch/cache verification passed: `bash
  experiments/test_v08_external_benchmark_source_import_live_registry_fetcher.sh`.
- Focused v08-u source-import live-registry network-proof verification passed:
  `bash experiments/test_v08_external_benchmark_source_import_live_registry_network_proof.sh`.
- Focused v08-v source-import real-verification verification passed:
  `bash experiments/test_v08_external_benchmark_source_import_real_verification_gate.sh`.
- Focused v08-w source-import official-authority verification passed:
  `bash experiments/test_v08_external_benchmark_source_import_official_authority_gate.sh`.
- Focused v08-x external benchmark result-authority verification passed:
  `bash experiments/test_v08_external_benchmark_result_authority_gate.sh`.
- Focused v08-y external benchmark publication-package verification passed:
  `bash experiments/test_v08_external_benchmark_publication_gate.sh`.
- Focused v08-z external benchmark source-acquisition verification passed:
  `bash experiments/test_v08_external_benchmark_source_acquisition_gate.sh`.
- Focused v08-aa external benchmark source-acquisition content verifier passed:
  `bash experiments/test_v08_external_benchmark_source_acquisition_content_verifier.sh`.
- Focused v08-ab external benchmark codebase-mini instrumentation passed:
  `bash experiments/test_v08_external_benchmark_codebase_mini.sh`.
- Focused v08-ac external benchmark content/result bridge passed:
  `bash experiments/test_v08_external_benchmark_content_result_bridge.sh`.
- Focused v08-ad external benchmark family result bridge passed:
  `bash experiments/test_v08_external_benchmark_family_result_bridge.sh`.
- Focused v08-ae external benchmark independent reproduction/review passed:
  `bash experiments/test_v08_external_benchmark_independent_reproduction_review.sh`.
- Focused v08-af external benchmark official release evidence passed:
  `bash experiments/test_v08_external_benchmark_official_release_evidence.sh`.
- Focused v08-ag external benchmark live release verification passed:
  `bash experiments/test_v08_external_benchmark_live_release_verification.sh`.
- Focused v08-ah external benchmark canonical online confirmation passed:
  `bash experiments/test_v08_external_benchmark_canonical_online_confirmation.sh`.
- Focused v08-ai external benchmark publication/result review passed:
  `bash experiments/test_v08_external_benchmark_publication_result_review.sh`.
- Focused v08-aj external benchmark live publication/result ingestion passed:
  `bash experiments/test_v08_external_benchmark_live_publication_result_ingestion.sh`.
- Focused v08-ak external benchmark authority/promotion evidence passed:
  `bash experiments/test_v08_external_benchmark_authority_promotion_evidence.sh`.
- Focused v08-al external benchmark run/evaluator trace passed:
  `bash experiments/test_v08_external_benchmark_run_evaluator_trace.sh`.
- Focused v08-am external benchmark independent run/evaluator evidence passed:
  `bash experiments/test_v08_external_benchmark_independent_run_evaluator_evidence.sh`.
- Focused v08-an external benchmark live replay/final-review passed:
  `bash experiments/test_v08_external_benchmark_live_replay_final_review.sh`.
- Focused v08-ao external benchmark public non-fixture verification passed:
  `bash experiments/test_v08_external_benchmark_public_nonfixture_verification.sh`.
- Focused v08-ap external benchmark runner-owned live execution/audit passed:
  `bash experiments/test_v08_external_benchmark_runner_owned_live_execution_audit.sh`.
- Focused v08-aq external benchmark independent live rerun confirmation passed:
  `bash experiments/test_v08_external_benchmark_independent_live_rerun_confirmation.sh`.
- Focused v08-ar external benchmark real nonfixture run package intake passed:
  `bash experiments/test_v08_external_benchmark_real_nonfixture_run_package.sh`.
- Focused v08-as external benchmark live package artifact fetch/authority passed:
  `bash experiments/test_v08_external_benchmark_live_package_artifact_fetch_authority.sh`.
- Focused v08-at external benchmark official result reconciliation passed:
  `bash experiments/test_v08_external_benchmark_official_result_reconciliation.sh`.
- Focused v08 lower-chain remote-artifact verification passed: `bash
  experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh`.
- v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at plus h11-d backend wrapper verification passed through `bash
  experiments/test_v09_gpu_backend_closure.sh`, confirming h7 plus v08
  adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation/readiness
  and the v08 lower-chain remote-artifact plus v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at real-source/remote-review/remote-full
  source-import/result-authority/publication/source-acquisition/content-cache/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation guards plus h11-a/h11-b/h11-c/h11-d, h9-h, and v12 in h9 quick closure.

## Open Boundary

- NOT scaled learned chunk retrieval solved.
- NOT teacher-distilled chunk retrieval solved.
- NOT wrong-candidate/fallback robustness solved beyond the h10-d forced smoke.
- NOT long-context retrieval solved.
- Current gate explicitly blocks default promotion, external comparison, and
  publishable PC RouteLM / NLG prototype or paper/release claims.
- Active next loop: replace the h10-r supplied import/review fixtures with
  official authority/registry evidence that can set
  `real_teacher_source_verified=1`, then connect a real external teacher-label
  source plus source-bound h10-s student-only scorer eval rows through the
  h10-j/h10-l/h10-r/h10-s source-verification contracts, connect
  real RULER/LongBench/codebase/doc-QA source and result
	  evidence through the v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at
	  import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority
  path, replace fixture/local lower-chain and final-review rows with non-local
  non-fixture evidence plus real public registry/source-import authority review
  and non-fixture live registry query plus fetch/cache, network proof, and
  official real-verification plus authority/trust-root records and official
  result-authority/leaderboard records plus non-fixture publication,
  source-acquisition/content, codebase-mini review packages, non-local
  content/result bridge rows for all benchmark families, independent
  reproduction/review evidence, official release evidence, live release
  verification, canonical online confirmation, publication/result review,
	  live-ingested non-fixture result records, public non-fixture live
	  replay/final-review verification, runner-owned live execution/audit,
	  independent live rerun confirmation, live package artifact fetch,
	  authority verification, official result reconciliation, and public real
	  external claim evidence for the real non-fixture benchmark run package,
  replace h9-g/h9-h fixture timing and generated workload rows
  with real HIP/NVMe workload speed evidence,
  then replace the h11-a/h11-b/h11-c/h11-d fixtures with a real local PC RouteLM
  prototype smoke and non-fixture artifact/provenance/NLG evidence, then rerun
  h7-c and v12 before any claim stronger than diagnostic artifact packaging.
