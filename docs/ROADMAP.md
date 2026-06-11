# Roadmap

## Current Checkpoint

As of v14-a plus v13-n/v13-m/v13-l/v13-k/v13-j/v13-i/v13-h/v13-g/v13-f/v13-e/v13-d/v13-c/v13-b/v13-a, h10-s, v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at, h11-a/h11-b/h11-c/h11-d, h9-h, h7-c, v12, and the h7/h9 quick closures, the project should be read as:

```text
discrete local-energy learner
+ value-bearing route-hint memory
+ candidate-quality guardrails
+ symbolic span route-memory diagnostics
+ local learned chunk-quality scorer diagnostics
+ source-verified learned scorer binding diagnostics
+ remote teacher-source acquisition contract
+ remote teacher-source content-cache verification contract
+ remote teacher-source live-fetch attestation contract
+ remote teacher-source runner-owned runtime fetcher contract
+ remote teacher-source live-network import evidence gate
+ real teacher-source import/review chain gate
+ source-verified learned scorer student-only eval gate
+ external benchmark final-review local-artifact bypass guard
+ external benchmark non-local review / local-upstream guard
+ external benchmark lower-chain HTTPS hash-attested artifact path
+ external benchmark source-import hard blocker
+ external benchmark source-import contract verifier
+ external benchmark source-import runner-owned verifier replay contract
+ external benchmark source-import live-verifier evidence gate
+ external benchmark source-import independent live-review gate
+ external benchmark source-import authoritative-review gate
+ external benchmark source-import public-registry gate
+ external benchmark source-import live-registry-query gate
+ external benchmark source-import live-registry fetch/cache gate
+ external benchmark source-import live-registry network-proof gate
+ external benchmark source-import real-verification gate
+ external benchmark source-import official-authority gate
+ external benchmark result-authority / leaderboard gate
+ external benchmark publication package / reproducibility gate
+ external benchmark source-acquisition / intake gate
+ external benchmark source-acquisition content-cache verifier
+ external benchmark codebase-mini local result instrumentation
+ external benchmark source-content/result bridge for codebase-retrieval
+ external benchmark all-family result bridge mechanics
+ external benchmark independent reproduction/review mechanics
+ external benchmark official release evidence mechanics
+ external benchmark live release verification mechanics
+ external benchmark canonical online confirmation mechanics
+ external benchmark publication/result review mechanics
+ external benchmark live publication/result ingestion mechanics
+ external benchmark authority/promotion evidence mechanics
+ external benchmark local run/evaluator trace mechanics
+ external benchmark independent all-family run/evaluator evidence mechanics
+ external benchmark live replay/final-review mechanics
+ external benchmark public non-fixture/direct-run verification mechanics
+ external benchmark runner-owned live execution/audit mechanics
+ external benchmark independent live rerun confirmation mechanics
+ external benchmark real nonfixture run package intake mechanics
+ external benchmark live package artifact fetch/authority mechanics
+ PC RouteLM / NLG prototype readiness and artifact verification contracts
+ NVMe-resident RouteMemory store artifact smoke
+ PC RouteLM diagnostic small-generator NLG smoke
+ CPU/HIP/NVMe workload-speed evidence gate
+ promotion review gate across teacher/scorer/benchmark/NLG/speed evidence
+ paper/release claim audit and forbidden-claim blocker
+ real-run binder manifest for one evidence-bound run directory
+ RouteLM mmap reader ABI over that run directory's store
+ evidence packet ABI feeding v12-style claim-matrix input
+ NLG transcript binding against route-memory span bytes
+ public codebase RouteQA binding against local codebase-mini trace rows
+ resource envelope binding for workload/timing/storage/memory rows
+ real evidence promotion audit across benchmark/scorer/NLG/speed blockers
+ real evidence intake contract for same-run replacement packages
+ real evidence live-network receipt gate for same-run replacement packages
+ real evidence rebind gate for same-run replacement artifacts
+ runtime fetch provenance gate for runner-owned receipt JSONs
+ source seed gate separating public source seeds from claim evidence
+ source seed live-fetch gate separating source availability from claim evidence
+ external benchmark official source acquisition gate
+ runner-owned query/result/evaluator execution path
+ optional HIP backend scaffold / parity instrumentation
```

Last completed checkpoint:

- h10-j closes the teacher external-label source verifier for the current
  route-memory path. Local source/export/identity/policy/license/provenance
  hash-chain mechanics pass, but local fixtures remain non-real and do not
  unlock distillation.
- h10-k closes the local learned chunk-quality scorer gate. The
  `linear-contrastive-chunk-v1` scorer separates reward from negative chunk
  actions on h10-f local teacher labels, but stays local-only with external
  source and promotion blocked.
- h10-l closes the source-verified learned scorer binding gate. Local learned
  scorer readiness no longer counts as source-verified distillation readiness
  unless supplied feature labels are non-local, teacher-ID linked, row-bound to
  external teacher-label rows by `source_uri` plus `provenance_hash`, and backed
  by real h10-j source verification.
- h10-m closes the remote teacher-source acquisition contract. HTTPS non-local
  source packages can pass URI/hash/acquisition/review readiness, while local
  packages are rejected and h10-m alone does not verify fetched source content.
- h10-n closes the remote teacher-source content verifier. Supplied local
  download/cache files can be bound back to the h10-m HTTPS URI/hash manifest
  and sha256-verified, while real source verification remains blocked until
  h10-o fetch-attestation and runtime fetcher evidence exist above it.
- h10-o closes the remote teacher-source live-fetch attestation contract.
  Artifact-level fetch rows can be bound back to h10-n content, verified against
  HTTPS attestation URIs and independent attestor flags, while real source
  verification remains blocked until runtime-fetcher and live-network evidence
  exist above it.
- h10-p closes the remote teacher-source runner-owned runtime fetcher contract.
  Offline replay rows can be generated by the runner and bound back to h10-o
  attestation rows with fetcher metadata and cache hash verification, while
  real source verification remains blocked until live network fetch and
  non-fixture source import replace replay.
- h10-q closes the remote teacher-source live-network import evidence gate.
  Offline replay is rejected as live-network evidence; supplied live-network
  runtime rows can reach `remote_teacher_source_live_network_import_ready=1`,
  while `real_teacher_source_verified=0` remains blocked until real
  non-fixture source import/review exists.
- h10-r closes the real teacher-source import/review chain gate. It requires
  h10-q live-network import readiness plus non-local source/export/identity/
  policy/license/import-manifest/review/reviewer/conflict/registry URI and
  hash evidence, live-import observation, independent/authoritative review
  flags, registry readiness, real/non-fixture declarations, and zero
  routing/jump activity. Local review artifacts and placeholder authorities
  are blocked; a non-placeholder import/review chain can reach
  `real_teacher_source_import_review_ready=1`, but
  `real_teacher_source_verified=0` remains blocked until official authority
  evidence exists.
- h10-s closes the source-verified learned scorer student-only evaluation gate.
  It consumes h10-l source-verified scorer binding, h10-r import/review
  readiness, and optional source-bound student-only chunk/span eval rows. A
  supplied eval fixture can pass metric deltas with `student_only_eval_ready=1`,
  but `source_verified_learned_chunk_scorer_eval_ready=0` remains until h10-l
  and h10-r have official real teacher-source authority.
- h7 quick closure is current through h7-c and keeps default promotion blocked.
- v12 closes the paper/release claim audit above h7-c, h10-r/h10-s, v08-ab,
  h11-c/h11-d, and h9-h. It can raise
  `diagnostic_release_package_ready=1` and `diagnostic_claim_level=4`, but
  keeps `real_release_package_ready=0`, `publishable_claim_level=0`, and
  `release_claim=diagnostic-artifact-package-only` while blocking Transformer
  replacement, frontier PC LLM, long-context solved, learned sparse routing,
  and GPU acceleration claims.
- v13-a closes the first real-run binder manifest. It packages h11-c store
  artifacts, h11-d NLG transcript/result, h9-h workload rows, v08-al
  run/evaluator trace, h10-s scorer/teacher evidence, and v12 claim-audit input
  into a single hash-manifested run directory. Generated diagnostic input can
  reach `real_run_binder_manifest_ready=1`, but actual nonfixture run, real PC
  RouteLM NLG, real external benchmark, real workload-speed evidence, real
  release package, and GPU speedup claims remain blocked.
- v13-b closes the RouteLM mmap reader ABI above v13-a. It opens
  `store/chunk_pages.bin` through mmap, verifies route-index/page-table byte
  windows, chunk offsets, route-key matches, and missing-abstain rows, and
  blocks hash-clean semantic span corruption. It is readable RouteMemory store
  instrumentation, not real PC RouteLM artifact evidence.
- v13-c closes the evidence packet ABI above v13-a/v13-b. It emits
  `evidence_packet.csv`, `claim_matrix_input.csv`, `packet_manifest.json`, and
  packet hashes for the bound run manifest, store/mmap reader, NLG,
  workload/resource, benchmark trace/evaluator, h10-s scorer, and v12 inputs.
  The packet and claim-source references pass, while learned chunk ranking and
  all real/nonfixture release claims remain blocked.
- v13-d closes the NLG transcript binding boundary above v13-a/v13-b/v13-c. It
  parses the bound transcript/result, checks transcript rows against route-index
  entries and mmap-read span bytes, emits `transcript_binding.csv`, and blocks
  hash-clean wrong grounding. It is grounded transcript instrumentation, not
  real PC RouteLM NLG proof until a nonfixture generator run exists.
- v13-e closes the public codebase RouteQA binding boundary above v13-a through
  v13-d. It binds the local codebase-mini package referenced by the run's
  benchmark manifest to the runner/evaluator trace, recomputes the seven-row
  metric table, emits `routeqa_rows.csv`, and blocks hash-clean evaluator
  corruption. It is local RouteQA instrumentation, not independent external
  benchmark proof.
- v13-f closes the resource envelope boundary above v13-a through v13-e. It
  binds the run workload CSV to NLG/timing/environment hashes, confirms the run
  NLG result hash, emits `resource_rows.csv`, and blocks hash-clean removal of
  the diagnostic speedup. It is workload/resource instrumentation, not GPU
  acceleration proof until real HIP/NVMe/nonfixture measurements exist.
- v13-g closes the real evidence promotion gate above v13-a through v13-f. It
  audits the four named weaknesses together, emits `promotion_rows.csv`, and
  keeps release promotion blocked until real external benchmark, learned chunk
  ranking, real NLG, real GPU speed, and nonfixture run evidence all bind to
  the same v13 run.
- v13-h closes the same-run real evidence intake gate above v13-g. It validates
  the four-row replacement package for external benchmark, learned chunk
  ranking, GPU speedup, and real NLG evidence, including run binding, cache
  hashes, HTTPS authority-chain shape, contract flags, and route/jump zero,
  while still blocking release until live-network verification and regenerated
  bound-run evidence exist.
- v13-i closes the real evidence live-network gate above v13-h. It validates
  same-run source/review/authority network receipts, receipt hashes, HTTPS final
  URIs, HTTP status rows, live-network declarations, and route/jump zero, while
  still blocking release until receipts are produced by runner-owned runtime
  live fetches and regenerated bound-run evidence exists.
- v13-j closes the real evidence rebind gate above v13-i. It validates
  receipt-hash replay into same-run replacement artifacts and claim-matrix
  rows, rebuilt artifact hashes, regeneration flags, and route/jump zero, while
  still blocking release until runtime live fetch evidence and regenerated
  promotion rows exist.
- v13-k closes the runtime fetch provenance gate above v13-j. It validates
  v13-i receipt JSON scope, weakness/kind binding, HTTPS original/final URIs,
  HTTP status, method, headers, empty error, ordered UTC timestamps, receipt
  hashes, and route/jump zero, while still blocking release unless the receipt
  source is runner-owned `runtime-live-fetch`.
- v13-l closes the source seed gate above v13-k. It records current public
  source seeds for the external benchmark blocker, explicitly classifies
  learned chunk ranking, GPU speedup, and real NLG as `project-source-only`,
  and blocks release until all four weaknesses have official/independent claim
  evidence and runtime live fetch receipts.
- v13-m closes the source seed live-fetch gate above v13-l. It validates optional
  runner-owned source seed receipts without turning reachable source URLs into
  claim evidence; release remains blocked until all four weaknesses have complete
  source/review/authority receipts and real official/independent claim rows.
- v13-n closes the external benchmark official source acquisition gate above
  v13-m/v13-l. It can produce runner-owned RULER/LongBench repo HEAD receipts
  and a RULER arXiv authority receipt, but it remains source acquisition only;
  external benchmark result/evaluator readiness and release stay blocked.
- v14-a opens the runner-owned query/result/evaluator execution path. It
  materializes public-codebase RouteQA queries, copies v13 source-chain rows,
  binds or live-fetches official repo HEAD source snapshots, can select a
  runner-owned source snapshot as the query repo, builds an mmap store with
  `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, and
  `store_manifest.csv`, hash-binds query materialization in
  `dataset/dataset_manifest.json`, emits raw predictions plus `predictions/prediction_status.json`, runs
  the evaluator plus `evaluator/evaluator_status.json`, and writes
  metrics/routeqa/benchmark/evidence/promotion rows plus
  `evidence/run_invocation.json`, `evidence/run_layout_manifest.json`, and
  `evidence/execution_chain_manifest.json` in one run directory, with run-layout
  and execution-chain hashes cross-checked against
  `sha256sums.txt`. A live RULER snapshot RouteQA run now proves the source snapshot
  can feed dataset/query/evaluator artifacts. A RULER-compatible NIAH smoke can
  also emit benchmark-shaped dataset/prediction/evaluator files, invoke the
  official RULER evaluator, invoke official RULER `scripts/data/prepare.py` for
  three official NIAH task rows and nine generated rows, feed those rows back
  through the official evaluator using input-extracted predictions rather than
  copied oracle outputs, mmap-verify the generated inputs through
  `benchmark/ruler_synthetic/official_generator_store/`, record generated benchmark/metrics/provenance binding
  rows, normalize them into run-level `benchmark/external_benchmark_rows.csv`,
  aggregate `benchmark/external_benchmark_metrics.json`, and hash-bind
  `benchmark/external_benchmark_manifest.json`. It can also run a LongBench v2
  multiple-choice official-source smoke through the live `longbench_repo`
  snapshot and official `result.py`, and can fetch 12 canonical LongBench v2
  dataset-server rows for a non-oracle baseline sample, mmap-verify those
  official sample rows through `benchmark/longbench_v2/official_sample_store/`,
  and add two LongBench rows to the same run-level external benchmark surface.
  The current live smoke has `external_benchmark_mmap_read_rows=21`,
  `external_benchmark_mmap_prediction_match_rows=21`,
  `external_benchmark_mmap_verification_ready_rows=4`,
  `external_benchmark_execution_chain_ready_rows=5`,
  `external_benchmark_execution_chain_ready=1`,
  `requested_outputs_manifest_ready=1`, `requested_outputs_ready=1`,
  `source_chain_autodiscovery_ready=1`,
  `reproducibility_manifest_ready=1`, `direct_cli_shape_ready=1`, and
  `run_layout_manifest_ready=1`, `run_layout_ready=1`,
  `objective_requirements_manifest_ready=1`, `objective_requirements_ready=1`,
  `source_chain_evidence_mirror_ready=1`, and
  `evidence_packet_rows=50`.
  This still remains runner-owned source execution, not independent
  RULER/LongBench benchmark proof.
- v08-l closes the final-review mechanics layer for external benchmarks while
  keeping real benchmark verification blocked until non-fixture source/review
  evidence exists. The real-source guard also prevents local final-review
  artifacts from becoming publishable benchmark evidence by declaration-flag
  rewrite alone, and the remote-review guard blocks HTTPS hash-attested reviews
  when lower-chain artifacts are still local fixtures. The lower-chain
  remote-artifact path now lets HTTPS hash-attested source/result, execution,
  attestation, and attestor identity artifacts pass mechanics through v08-k
  while still blocking publish until final review exists. The remote-full
  source-import guard now combines non-local lower-chain and final-review
  mechanics and carries the source-import/publication chain through v08-y. A supplied
  contract/verifier/live-review/authority-review/public-registry/live-query/
  fetch/network-proof/real-verification/official-authority fixture can reach
  `source_import_official_authority_review_ready=1`, but still blocks at
  `source_import_verified=0` with
  `external-benchmark-source-import-official-authority-fixture-only` until
  non-fixture live registry query plus fetch/cache, network proof, official
  real-verification records, official authority/trust-root records, and
  official result-authority/leaderboard records exist. v08-x now adds a final
  result-authority layer above final review so upstream verification is
  downgraded unless benchmark result rows are also bound to official leaderboard
  evidence. v08-y adds the publication-package layer above result authority,
  binding the official results and comparison rows to report, reproducibility,
  license, conflict-disclosure, and publication-review artifacts while keeping
  fixture or unpublished comparison packages non-publishable.
- v08-z closes the external benchmark source-acquisition/intake mechanics layer.
  Supplied acquisition rows must match the four adapter families, use
  non-placeholder official domains, provide HTTPS source landing/dataset/card/
  split/license/metric URIs on those domains, carry sha256 hash attestations,
  identify a non-local acquisition method/tool, and include independent source
  review plus zero routing/jump activity. Fixture acquisition packages can reach
  `external_benchmark_source_acquisition_review_ready=1`, and non-fixture
  packages can reach `external_benchmark_source_acquisition_ready=1`, but
  acquisition alone still keeps `real_external_benchmark_verified=0` until the
  imported content, result, review, and publication chain is verified.
- v08-aa closes the source-acquisition content-cache verifier layer. Supplied
  cache rows must bind back to each v08-z acquisition ID, match all official
  source landing/dataset/card/split/license/metric URIs and sha256 hashes, and
  verify 24 local cache files across the four benchmark families. Matching
  cache content can reach
  `external_benchmark_source_acquisition_content_ready=1`, but cache
  verification alone still keeps `real_external_benchmark_verified=0` until
  source import, result authority, review, and publication evidence are
  connected.
- v08-ab closes the first codebase-mini benchmark instrumentation layer.
  Generated local packages bind real repository source files to source,
  dataset, split, license, metric, baseline, result, and sha256 artifacts, then
  require h11-c RouteMemory store linkage. The smoke can reach
  `codebase_mini_source_ready=1`, `benchmark_result_artifact_verified=1`, and
  `baseline_comparison_ready=1`, but local instrumentation keeps
  `real_external_benchmark_verified=0` until independent external review and
  publication evidence exist.
- v08-ac closes the first source-content/result bridge layer for the
  codebase-retrieval slice. Supplied bridge rows can bind v08-aa acquisition
  content to the v08-ab codebase-mini result artifacts and verify five
  result/baseline/dataset/run/evaluator hashes, reaching
  `codebase_content_result_bridge_ready=1`; the full external result bridge
  stays blocked with `external_benchmark_result_bridge_ready=0` because only
  one of four benchmark families is covered and the artifacts remain local.
- v08-ad closes the all-family result bridge mechanics layer. Supplied
  non-local rows for RULER, LongBench, codebase-retrieval, and real-document-qa
  can bind back to v08-aa source-content acquisition IDs, attest 28 HTTPS
  result/baseline/dataset/run/evaluator/result-authority/publication URI/hash
  fields, and reach `family_result_bridge_review_ready=1` plus
  `external_benchmark_result_bridge_ready=1`; `real_external_benchmark_verified=0`
  still remains because supplied bridge mechanics are not independent
  reproduction or official publishable benchmark evidence.
- v08-ae closes the independent reproduction/review mechanics layer. Supplied
  non-local rows for all four benchmark families bind back to the v08-ad result
  bridge, verify result artifact plus bridge-summary hashes, attest 28 HTTPS
  reproduction/report/run-log/reviewer/conflict/environment/metric URI/hash
  fields, and reach `independent_reproduction_review_ready=1`; real benchmark
  verification still stays blocked until official release and externally
  verifiable publication evidence replace supplied review mechanics.
- v08-af closes the official release evidence mechanics layer. Supplied
  release rows for all four benchmark families bind back to the v08-ae
  reproduction IDs and summary hash, attest 44 release/reproduction hash fields
  plus 40 HTTPS release package/manifest/archive/version/license/
  reproducibility/review/index/authority URI fields, and reach
  `official_release_evidence_ready=1`; real benchmark verification still stays
  blocked until those supplied release mechanics are replaced by live,
  externally verifiable release/publication records.
- v08-ag closes the live release verification mechanics layer. Supplied
  live-verification rows for all four benchmark families bind back to v08-af
  release IDs, reproduction IDs, and official release/archive/dataset/authority
  URI+hash pairs, attest 28 HTTPS live verification/report/network-observation/
  verifier URI/hash fields, and reach
  `official_release_live_verification_ready=1`; real benchmark verification
  still stays blocked until canonical online confirmation and externally
  verifiable publication evidence replace supplied mechanics.
- v08-ah closes the canonical online confirmation mechanics layer. Supplied
  confirmation rows for all four benchmark families bind back to v08-ag live
  verification reports, network observations, verifier identities, release
  IDs, and reproduction IDs, attest 36 HTTPS live/canonical confirmation,
  runner-network transcript, TLS, DNS, HTTP-header, and content-digest URI/hash
  fields, and reach `canonical_online_confirmation_ready=1`; real benchmark
  verification still stays blocked until non-fixture publication/result review
  evidence replaces supplied mechanics.
- v08-ai closes the publication/result review mechanics layer. Supplied review
  rows for all four benchmark families bind back to v08-ah canonical
  confirmation reports, content-digest manifests, release IDs, and reproduction
  IDs, attest 36 HTTPS review/result/publication/authority URI/hash fields,
  require 28 newly introduced review artifact URIs to be non-placeholder HTTPS,
  and reach `publication_result_review_ready=1`; real benchmark verification
  still stays blocked until live-ingested non-fixture result/publication records
  and promotion evidence replace supplied mechanics.
- v08-aj closes the live publication/result ingestion mechanics layer. Supplied
  ingestion rows for all four benchmark families bind back to v08-ai
  publication/result review and record URI/hash pairs, attest 56 HTTPS
  ingestion/review URI/hash fields, require 40 newly introduced live-ingestion
  artifact URIs to be non-placeholder HTTPS, include response-header,
  content-digest, and TLS certificate-chain evidence, and reach
  `live_publication_result_ingestion_ready=1`; real benchmark verification
  still stays blocked until actual non-fixture authority/promotion evidence
  replaces supplied ingestion mechanics.
- v08-ak closes the authority/promotion evidence mechanics layer. Supplied
  authority rows for all four benchmark families bind back to v08-aj live
  publication/result records and content digests, attest 56 HTTPS
  authority/ingestion URI/hash fields, require 40 newly introduced authority
  artifact URIs to be non-placeholder HTTPS, include registry, leaderboard,
  reproducibility package, archive, identity, conflict, promotion trace, and
  final claim packet evidence, and reach
  `authority_promotion_evidence_ready=1`; real benchmark verification still
  stays blocked until real independently observed external benchmark run and
  evaluator evidence replaces supplied authority mechanics.
- v08-m closes the first source-import contract verifier layer. A remote-style
  fixture can bind source/result/execution URIs and hashes to non-local import
  manifest/fetch-log/reviewer artifacts, live-network import flags,
  non-fixture declarations, and independent source-import review, reaching
  `source_import_contract_ready=1`; it still keeps
  `source_import_verified=0` and `real_external_benchmark_verified=0`.
- v08-n closes the runner-owned source-import verifier replay layer. Replay
  rows can bind back to v08-m source-import IDs, import manifest/fetch-log/
  reviewer hashes, benchmark artifact URIs, and verifier binary/stdout/stderr
  hashes, reaching `source_import_verifier_ready=1`; it still keeps
  `live_network_source_import_verified=0`, `source_import_verified=0`, and
  `real_external_benchmark_verified=0` because replay is not live source-import
  verification.
- v08-o closes the live source-import verifier evidence layer. Supplied
  live-style verifier rows can clear the replay blocker and reach
  `source_import_live_verifier_ready=1`, but they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` until
  independent live review is present.
- v08-p closes the source-import independent live-review mechanics layer.
  Supplied non-local, hash-attested review rows can bind to verifier run IDs,
  verifier artifact hashes, and source-import manifest/fetch-log hashes,
  reaching `source_import_independent_live_review_ready=1`, but they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` until
  the v08-q authoritative-review and real public registry/source-import
  authority evidence layers exist.
- v08-q closes the source-import authoritative-review mechanics layer.
  Supplied non-local, hash-attested authority-review rows can bind
  source-import IDs, verifier run IDs, live-review IDs, live-review report
  hashes, verifier hashes, reviewer identity, reviewer registry, and conflict
  disclosure evidence, reaching `source_import_authoritative_review_ready=1`,
  but they still keep `source_import_verified=0` and
  `real_external_benchmark_verified=0` until real public registry/source-import
  authority evidence exists.
- v08-r closes the source-import public-registry mechanics layer. Supplied
  non-local, hash-attested registry rows can bind source-import IDs, verifier
  run IDs, live-review IDs, authority-review IDs, authority hashes, verifier
  hashes, registry entry artifacts, operator identity, and provenance, reaching
  `source_import_public_registry_ready=1`, but they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` until a
  runner-owned live registry query/fetch path exists.
- v08-s closes the source-import live-registry-query mechanics layer. Runner-owned
  replay rows can verify query-runner mechanics while still blocking live
  network evidence, and supplied live-style query rows can bind fetched registry
  response hashes back to v08-r registry rows, reaching
  `source_import_live_registry_query_ready=1`; they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` because
  supplied query rows are fixture-only.
- v08-t closes the source-import live-registry fetch/cache mechanics layer.
  Runner-owned replay rows can verify fetcher metadata and local response-cache
  hashes while still blocking network proof, and supplied live-style fetch rows
  can reach `source_import_live_registry_fetch_ready=1`; they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` because
  supplied fetch rows are fixture-only.
- v08-u closes the source-import live-registry network-proof mechanics layer.
  Runner-owned replay proof rows can verify proof metadata, request/header/TLS/
  DNS/nonce hashes, runner/tool hashes, and cache/body hash binding while still
  blocking live network proof. Supplied live-style proof rows can reach
  `source_import_live_registry_network_proof_ready=1`; they still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` because
  supplied proof rows are fixture-only.
- v08-v closes the source-import real-verification mechanics layer. Supplied
  verification rows can bind network-proof rows to verification reports,
  verifier identity artifacts, proof transcripts, and verified cache hashes,
  reaching `source_import_real_verification_review_ready=1`; placeholder
  domains still keep `source_import_verified=0` and
  `real_external_benchmark_verified=0`.
- h9-g closes the measured-speed evidence contract and h9-h closes the
  CPU/HIP/NVMe workload-speed evidence contract while keeping GPU speedup
  claims deferred until real HIP/NVMe workload measurements exist.
- h7-c closes the promotion review contract above h7-b, h10-r, h10-s,
  v08-ab, h11-d, and h9-h. It passes the review contract, quality thresholds,
  and zero route/jump guardrail, but keeps `real_evidence_complete=0`,
  `promotion_review_ready=0`, and `default_promotion=0` until real teacher,
  scorer, benchmark, NLG, and workload-speed evidence all pass.
- h11-a closes the PC RouteLM / NLG readiness contract, h11-b closes the
  artifact/provenance verification mechanics, h11-c closes the
  NVMe-resident RouteMemory store smoke, and h11-d closes the diagnostic
  small-generator NLG smoke while keeping real prototype and publish claims
  blocked.

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
  Supplied local fixtures can verify the chain mechanics, but any local
  `file://` evidence, including outside `results/`, keeps
  `real_teacher_source_verified=0` and `distillation_ready=0`.
- `h10-k` adds a learned chunk-quality scorer over local teacher-label
  features. The smoke separates reward from negative actions
  (`learned_score_gap=3.064325`, `coherent_wrong_negative_rate=1.000000`) and
  feeds that readiness into the distillation gate, but keeps
  `external_label_source_ready=0`, `distillation_ready=0`, and
  `default_promotion=0`.
- `h10-l` binds learned scorer readiness to source-verified feature labels.
  Default/local labels keep `source_verified_feature_labels_ready=0`; relabeled
  local rows without row provenance and mismatched external-label rows are
  rejected. Supplied local fixtures can link feature labels and verify
  source-chain mechanics, but still keep
  `source_verified_learned_chunk_scorer_ready=0` until
  `real_teacher_source_verified=1`.
- `h10-m` adds the remote teacher-source acquisition contract. Default/no-env
  blocks before acquisition evidence; local `file://` packages block as
  local/placeholder; HTTPS packages can pass acquisition readiness but still
  keep `real_teacher_source_verified=0` with
  `remote-teacher-source-fetcher-missing`.
- `h10-n` adds the remote teacher-source content verifier. It binds supplied
  local cache files to the h10-m HTTPS acquisition URI/hash manifest and
  verifies source/export/identity/policy/license/review sha256 hashes, but
  keeps `real_teacher_source_verified=0` with
  `remote-teacher-source-live-fetch-missing` until live remote fetch/attestation
  evidence exists.
- `h10-o` adds the remote teacher-source live-fetch attestation contract. It
  binds six artifact-level fetch rows to h10-n content, requires fetch metadata,
  HTTPS attestation URIs, cached attestation hashes, independent attestor flags,
  and non-fixture declarations, but keeps `real_teacher_source_verified=0` with
  `remote-teacher-source-runtime-fetcher-missing` until a runner-owned live
  fetcher exists.
- `h10-p` adds the remote teacher-source runtime fetcher contract. It lets the
  runner generate an offline replay manifest from h10-o attestations, verifies
  fetcher binary/command/stdout/stderr hashes and downloaded cache hashes, and
  can raise `runner_owned_runtime_fetcher_ready=1`, but keeps
  `live_network_fetch_ready=0` and `real_teacher_source_verified=0` until live
  network fetch and non-fixture source import replace replay.
- `h10-q` adds the remote teacher-source live-network import gate. It rejects
  h10-p offline replay as live-network evidence, accepts only supplied rows
  that are all network fetches, real-declared, non-fixture, and runner-owned,
  and can raise `remote_teacher_source_live_network_import_ready=1` while still
  keeping `real_teacher_source_verified=0` until real source import/review
  evidence exists.
- `h10-r` adds the real teacher-source import/review chain gate. It binds h10-q
  live-network import readiness to source/export/identity/policy/license/
  import-manifest/review/reviewer/conflict/registry URI/hash evidence, blocks
  local review artifacts and placeholder authorities, and can raise
  `real_teacher_source_import_review_ready=1` for a non-placeholder review
  chain while still keeping `real_teacher_source_verified=0` until official
  authority evidence exists.
- `h10-s` adds the source-verified learned scorer student-only evaluation gate.
  It requires h10-l source-verified scorer readiness, h10-r import/review
  readiness, source-bound real student-only eval rows, positive chunk/span
  metric deltas, wrong-answer non-regression, near-miss/missing abstain
  readiness, and zero routing/jump activity before the learned scorer can be
  treated as an eval candidate.
- `h7-a` adds the `/goal` closure smoke:
  `experiments/test_v07_goal_route_memory_closure.sh`.
- `h7-b` adds the route-memory promotion gate and keeps default promotion
  blocked.
- `h7-c` adds the promotion review matrix across h7-b, h10-r, h10-s, v08-ab,
  h11-d, and h9-h, keeping promotion blocked until every input is backed by
  real non-fixture evidence.
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
  remains non-publishable without real source review evidence. Its real-source
  guard now blocks local `file://` final-review/reviewer artifacts even when
  the supplied review CSV declares them real and non-fixture. The remote-review
  guard also lets HTTPS hash-attested review artifacts pass the review hash
  layer while still blocking publication if evidence, execution, attestation,
  or identity artifacts underneath are local fixtures. The lower-chain remote
  artifact path now verifies HTTPS hash-attested source/result, execution,
  attestation, and identity artifacts through v08-k, but still stops before
  publication until a final review is supplied and real source evidence exists.
  A fully remote-style package now reaches local-upstream counters of `0`, and
  with v08-s/v08-t/v08-u/v08-v live-query/fetch/network-proof rows it can reach
  `source_import_live_registry_network_proof_ready=1`; it still remains
  blocked at `source_import_verified=0` until non-fixture live registry query,
  fetch/cache proof, and network proof replace the remote-style mechanics.
- `v08-m` adds the explicit source-import contract verifier. It validates
  provided source-import rows against lower-chain artifact URI/hash evidence,
  import manifest/fetch-log/reviewer hash attestations, live-network import
  declarations, and independent source-import review, but still blocks real
  verification with `external-benchmark-source-import-real-verifier-missing`.
- `v08-n` adds the explicit source-import verifier/fetch-evidence contract.
  The runner-owned replay path can generate verifier rows from v08-m rows and
  verify local replay binary/stdout/stderr hashes while binding every row back
  to the source-import manifest, fetch log, reviewer identity, and benchmark
  artifacts. Replay reaches `source_import_verifier_ready=1` but blocks with
  `external-benchmark-source-import-live-verifier-missing`.
- `v08-o` adds the live-verifier evidence gate. It accepts only live-style
  verifier rows above v08-n with no offline replay rows plus real/non-fixture
  declarations, reaching `source_import_live_verifier_ready=1` while blocking
  final verification with
  `external-benchmark-source-import-independent-live-review-missing`.
- `v08-p` adds the independent live-review evidence gate. It accepts only
  non-local, hash-attested review rows above v08-o that match source-import IDs,
  verifier run IDs, verifier artifact hashes, and import manifest/fetch-log
  hashes, reaching `source_import_independent_live_review_ready=1` while still
  blocking final verification with
  `external-benchmark-source-import-authoritative-live-review-missing`.
- `v08-q` adds the authoritative source-import review gate. It accepts only
  non-local, hash-attested authority-review rows above v08-p that match
  source-import IDs, verifier run IDs, live-review IDs, live-review hashes,
  verifier hashes, reviewer identity, reviewer registry, and conflict
  disclosure evidence, reaching `source_import_authoritative_review_ready=1`
  while still blocking final verification with
  `external-benchmark-source-import-real-public-registry-missing`.
- `v08-r` adds the public-registry source-import gate. It accepts only
  non-local, hash-attested registry rows above v08-q that match source-import
  IDs, verifier run IDs, live-review IDs, authority-review IDs, authority
  hashes, verifier hashes, registry entry artifacts, operator identity, and
  provenance, reaching `source_import_public_registry_ready=1` while still
  blocking final verification with
  `external-benchmark-source-import-live-registry-query-missing`.
- `v08-s` adds the live-registry-query source-import gate. It accepts query rows
  above v08-r that match source-import IDs, authority-review IDs, registry
  entry IDs, registry URIs, and fetched registry response hashes. Runner-owned
  replay proves query-runner mechanics but not live network evidence; supplied
  live-style query rows can reach `source_import_live_registry_query_ready=1`
  while still blocking final verification with
  `external-benchmark-source-import-live-registry-query-fixture-only`.
- `v08-t` adds the live-registry fetch/cache source-import gate. It accepts
  fetch rows above v08-s that match source-import IDs, live query IDs, registry
  response URIs, and response-cache hashes. Runner-owned replay proves fetcher
  and cache-hash mechanics but not network proof; supplied live-style fetch rows
  can reach `source_import_live_registry_fetch_ready=1` while still blocking
  final verification with
  `external-benchmark-source-import-live-registry-fetch-fixture-only`.
- `v08-u` adds the live-registry network-proof source-import gate. It accepts
  proof rows above v08-t that match source-import IDs, live query IDs, fetcher
  run IDs, registry/cache URIs, cache hashes, proof metadata, and network
  request/header/TLS/DNS/nonce hashes. Runner-owned replay proves proof
  mechanics but not live network fetch; supplied live-style proof rows can
  reach `source_import_live_registry_network_proof_ready=1` while still
  blocking final verification with
  `external-benchmark-source-import-live-registry-network-proof-fixture-only`.
- `v08-v` adds the real-verification source-import gate. It accepts
  verification rows above v08-u that match source-import IDs, network proof IDs,
  verified cache hashes, verification reports, verifier identity artifacts, and
  proof transcripts. Placeholder/example domains can exercise the review
  mechanics, but they block final verification with
  `external-benchmark-source-import-real-verification-placeholder-domain`.
- `v08-w` adds the official-authority source-import gate. It accepts authority
  rows above v08-v that match source-import IDs, network-proof IDs,
  verification record IDs, verification report hashes, authority artifacts,
  authority domains, benchmark source/license artifacts, and trust-root review
  flags. Supplied fixture rows can exercise the review mechanics up to
  `source_import_official_authority_review_ready=1`, but they keep
  `source_import_verified=0` with
  `external-benchmark-source-import-official-authority-fixture-only`.
- `v08-x` adds the external benchmark result-authority gate. It binds final
  review outputs to official result-authority/leaderboard rows, result URIs,
  provenance hashes, evaluator-output hashes, run-log hashes, metric values,
  metric/protocol artifacts, submitter identity, and result-review flags.
  Supplied fixture rows can exercise the mechanics up to
  `external_benchmark_result_authority_review_ready=1`, but they keep
  `real_external_benchmark_verified=0` with
  `external-benchmark-result-authority-fixture-only`.
- `v08-y` adds the external benchmark publication-package gate. It binds
  official result-authority rows and comparison outputs to publication package,
  report, comparison table, reproducibility bundle, license, conflict
  disclosure, and publication-review artifacts. Supplied fixture rows can
  exercise the mechanics up to `external_benchmark_publication_review_ready=1`,
  but they keep `real_external_benchmark_verified=0` with
  `external-benchmark-publication-fixture-only`; non-fixture publication rows
  still block with `external-benchmark-publication-comparison-not-publishable`
  until the comparison is publishable.
- `v08-z` adds the external benchmark source-acquisition/intake gate. It checks
  official source landing, dataset, benchmark-card, split-manifest, license,
  and metric-spec URI/hash packages for RULER, LongBench, codebase retrieval,
  and real document QA. It can mark non-fixture acquisition packages ready, but
  still refuses to turn acquisition metadata alone into verified benchmark
  results.
- `v08-aa` adds the source-acquisition content-cache verifier. It verifies that
  supplied local cache files match the v08-z official acquisition manifest
  hashes for all six source artifacts per benchmark family, while still
  blocking real external benchmark verification until imported results and
  review/publication evidence exist.
- `v08-ab` adds the codebase-mini benchmark package. It creates a local
  `codebase-retrieval` dataset from real repo files, verifies source
  provenance, baseline/result artifacts, and h11-c RouteMemory-store linkage,
  and keeps the result instrumentation-only until independent non-fixture
  benchmark review/publication evidence is present.
- `v08-ac` adds the source-content/result bridge for codebase-retrieval. It
  binds source-acquisition content-cache evidence to codebase-mini result
  artifacts and exposes the remaining gap: RULER, LongBench, and real document
  QA still need non-local result bridge rows before an external comparison can
  advance.
- `v08-ad` adds the all-family result bridge contract. It requires non-local
  result bridge rows for RULER, LongBench, codebase retrieval, and real document
  QA, source-content summary hash binding, 28 sha256-attested HTTPS result
  fields, independent bridge review flags, and zero route/jump activity. It can
  advance result-bridge mechanics, but not a real external benchmark claim.
- `v08-ae` adds the independent reproduction/review contract. It requires
  all-family reproduction rows above v08-ad, result artifact binding, bridge
  summary hash verification, independent runner/reviewer/conflict checks,
  28 sha256-attested HTTPS reproduction fields, and zero route/jump activity.
  It can advance review mechanics, but not a real benchmark claim.
- `v08-af` adds the official release evidence contract. It binds all-family
  release rows back to v08-ae reproduction IDs and the v08-ae summary hash,
  requires 44 sha256-attested release/reproduction hashes plus 40 HTTPS release
  artifact URIs, and can raise `official_release_evidence_ready=1`; it still
  keeps `real_external_benchmark_verified=0` until live release verification
  and externally verifiable publication evidence replace supplied mechanics.
- `v08-ag` adds the live release verification contract. It binds all-family
  live-verification rows back to v08-af release IDs, reproduction IDs, and the
  official release/archive/dataset/authority URI+hash pairs, requires 28
  sha256-attested HTTPS live-verification artifact fields plus independent
  verifier/live-network/stable-release declarations, and can raise
  `official_release_live_verification_ready=1`; it still keeps
  `real_external_benchmark_verified=0` until canonical online confirmation and
  publishable external evidence replace supplied mechanics.
- `v08-ah` adds the canonical online confirmation contract. It binds all-family
  confirmation rows back to v08-ag live reports, network observations, verifier
  identities, release IDs, and reproduction IDs, requires 36 sha256-attested
  HTTPS confirmation/proof fields plus runner-owned/authority/online-fetch/
  digest-match declarations, and can raise `canonical_online_confirmation_ready=1`;
  it still keeps `real_external_benchmark_verified=0` until non-fixture
  publication/result review evidence replaces supplied mechanics.
- `v08-ai` adds the publication/result review contract. It binds all-family
  review rows back to v08-ah canonical confirmation reports and content-digest
  manifests, requires 36 sha256-attested HTTPS review/result/publication/
  authority fields plus independent publication/result observation
  declarations, requires the newly introduced review URIs to be non-placeholder,
  and can raise `publication_result_review_ready=1`; it still keeps
  `real_external_benchmark_verified=0` until live-ingested non-fixture
  publication/result records and promotion evidence replace supplied mechanics.
- `v08-aj` adds the live publication/result ingestion contract. It binds
  all-family ingestion rows back to v08-ai publication/result review and record
  URI/hash pairs, requires 56 sha256-attested HTTPS ingestion/review fields,
  40 newly introduced non-placeholder live-ingestion artifact URIs, and
  runner-owned live-network ingestion plus digest-match declarations. It can
  raise `live_publication_result_ingestion_ready=1`, but keeps
  `real_external_benchmark_verified=0` until actual non-fixture authority and
  promotion evidence replace supplied ingestion mechanics.
- `v08-ak` adds the authority/promotion evidence contract. It binds all-family
  authority rows back to v08-aj live publication/result records and content
  digests, requires 56 sha256-attested HTTPS authority/ingestion fields, 40
  newly introduced non-placeholder authority artifact URIs, and independent/
  official/registry/consistency/limited-claim declarations. It can raise
  `authority_promotion_evidence_ready=1`, but keeps
  `real_external_benchmark_verified=0` until actual independently observed
  benchmark run/evaluator evidence replaces supplied authority mechanics.
- `v08-al` adds the first run/evaluator trace contract above v08-ak and
  v08-ab. It recomputes the local codebase-mini dataset/result join into
  runner/evaluator manifests, query trace, evaluator output, metrics, command
  receipt, and hash manifest artifacts. It can raise
  `codebase_run_evaluator_trace_ready=1`, but keeps
  `external_benchmark_run_evaluator_trace_ready=0` and
  `real_external_benchmark_verified=0` until independent all-family
  run/evaluator evidence exists.
- `v08-am` adds the independent all-family run/evaluator evidence contract above
  v08-al. Supplied rows for RULER, LongBench, codebase-retrieval, and
  real-document-qa must carry non-placeholder HTTPS trace/run/evaluator/metric/
  query/observer/authority artifacts, sha256 hashes, query volume, quality
  thresholds, proof bindings, independent evaluator declarations, and
  route/jump zero. It can raise
  `external_benchmark_independent_run_evaluator_evidence_ready=1`, but keeps
  `real_external_benchmark_verified=0` until live replay/final review replaces
  supplied evidence.
- `v08-an` adds the live replay/final-review contract above v08-am. Supplied
  rows for all four benchmark families bind v08-am evidence to replay and
  final-review artifact URI/hash pairs, replay query volume, metric thresholds,
  live replay declarations, independent final-review declarations, fixture
  declarations, and route/jump zero. It can raise
  `external_benchmark_live_replay_final_review_ready=1`, but keeps
  `real_external_benchmark_verified=0` until public non-fixture verification or
  direct runner-owned external benchmark runs replace supplied mechanics.
- `v08-ao` adds the public non-fixture/direct-run verification contract above
  v08-an. Supplied rows for all four benchmark families bind v08-an review
  evidence to 40 non-placeholder HTTPS public/direct-run artifact URIs, 40
  sha256 hashes, query volume, metric thresholds, public registry/non-fixture
  declarations, direct runner-owned run/dataset/evaluator/network declarations,
  third-party reviewer declarations, fixture declarations, and route/jump zero.
  It can raise `external_benchmark_public_nonfixture_verification_ready=1`, but
  keeps `real_external_benchmark_verified=0` until runner-owned live
  execution/audit proves the public direct-run receipts.
- `v08-ap` adds the runner-owned live execution/audit contract above v08-ao.
  Supplied rows for all four benchmark families bind v08-ao verification
  evidence to 52 non-placeholder HTTPS live execution/audit artifact URIs, 52
  sha256 hashes, query volume, metric thresholds, runner-owned execution
  declarations, live network/dataset fetch declarations, runner-invoked
  evaluator declarations, replay-disabled declarations, audit log and
  third-party audit declarations, fixture declarations, and route/jump zero. It
  can raise `external_benchmark_runner_owned_live_execution_audit_ready=1`, but
  keeps `real_external_benchmark_verified=0` until independent live rerun
  confirmation proves the runner-owned audit receipts.
- `v08-aq` adds the independent live rerun confirmation contract above v08-ap.
  Supplied rows for all four benchmark families bind v08-ap audit evidence to
  60 non-placeholder HTTPS rerun-confirmation artifact URIs, 60 sha256 hashes,
  rerun query volume, metric thresholds, metric-delta bounds, independent
  runner/environment declarations, live network/dataset refetch/evaluator rerun
  declarations, audit receipt reconciliation, metric recomputation,
  third-party confirmation declarations, fixture declarations, and route/jump
  zero. It can raise
  `external_benchmark_independent_live_rerun_confirmation_ready=1`, but keeps
  `real_external_benchmark_verified=0` until a real non-fixture benchmark run
  package replaces supplied confirmation mechanics.
- `v08-ar` adds the real nonfixture run package intake contract above v08-aq.
  Supplied rows for all four benchmark families bind v08-aq confirmation
  evidence to 60 non-placeholder HTTPS run-package artifact URIs, 60 sha256
  hashes, packaged query volume, metric thresholds, metric-delta bounds,
  nonfixture/official benchmark/public archive/raw query/raw output/evaluator
  container/immutable archive declarations, license/PII/third-party
  reproducibility reviews, fixture declarations, and route/jump zero. It can
  raise `external_benchmark_real_nonfixture_run_package_intake_ready=1`, but
  keeps `real_external_benchmark_verified=0` until live package artifact fetch
  and authority verification replace supplied package mechanics.
- `v08-as` adds the live package artifact fetch/authority contract above
  v08-ar. Supplied rows cover all 60 family/artifact entries, binding each to
  fetched artifact, fetch receipt, and authority record URI/hash pairs. They
  require 180 non-placeholder HTTPS URI fields, 180 sha256 hashes, HTTP-200
  checks, content-digest matches, v08-ar package-intake binding, runner-owned
  live fetch declarations, network/TLS/DNS/HTTP declarations, authority
  registry/official source authority declarations, fixture declarations, and
  route/jump zero. It can raise
  `external_benchmark_live_package_artifact_fetch_authority_ready=1`, but keeps
  `real_external_benchmark_verified=0` until official result reconciliation
  replaces supplied fetch/authority mechanics.
- `v08-at` adds the official result reconciliation contract above v08-as.
  Supplied rows for all four benchmark families bind v08-as fetched official
  leaderboard, metric report, submission receipt, evaluator config, raw
  prediction output, and package-registry artifacts by exact URI/hash identity.
  They require 28 non-placeholder HTTPS URI fields, 28 sha256 hashes, package
  identity matches, metric-delta tolerance checks, query-count matches,
  evaluator/digest/official-source/leaderboard/runner declarations, fixture
  declarations, and route/jump zero. It can raise
  `external_benchmark_official_result_reconciliation_ready=1`, but keeps
  `real_external_benchmark_verified=0`; the next step is v13 real-run binding,
  not another v08 layer.
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
- `h11-c` adds the NVMe-resident RouteMemory store artifact smoke. It creates
  and verifies a small store bundle (`route_memory_store.bin`,
  `route_index.bin`, `chunk_pages.bin`, `chunk_offsets.bin`,
  `chunk_credit.bin`, `page_table.bin`, `manifest.json`, `sha256sums.txt`),
  then checks route lookup, candidate span reads, hash-chain integrity, and
  `routing_trigger_rate = active_jump_rate = 0`. The smoke can raise
  `route_memory_artifact_chain_verified=1`, but it keeps
  `real_pc_routelm_artifact_verified=0` and
  `real_external_benchmark_verified=0`.
- `h11-d` adds the diagnostic PC RouteLM small-generator NLG smoke above the
  h11-c store. It writes a generated transcript/result artifact, verifies
  teacher-off inference, retrieved evidence use, grounding, span citation,
  span/chunk exactness, missing abstain, wrong-answer rate, latency/SSD/RAM/
  VRAM metrics, and zero route/jump activity. The smoke can raise
  `pc_routelm_nlg_smoke_ready=1`, but keeps
  `real_pc_routelm_nlg_verified=0`.
- `h9-a/h9-b/h9-d/h9-e/h9-f/h9-g/h9-h` add optional ROCm/HIP backend
  scaffolding plus measured-speed and workload-speed evidence contracts:
  `experiments/test_v09_gpu_backend_closure.sh`.
- `v12-a` adds the paper/release claim audit over the currently verified stack.
  It is a release-packaging diagnostic, not a publishable paper/product claim.
- `v13-a` adds the real-run binder manifest above h11-c/h11-d/h9-h/v08-al/h10-s/v12.
  It verifies one run directory shape and hash manifest for generated
  diagnostic inputs while keeping all real/nonfixture and GPU speedup claims
  blocked.
- `v13-b` adds the RouteLM mmap reader above v13-a. It proves the bound store
  can be opened and queried through the reader ABI, while still blocking real
  artifact/external/release claims.
- `v13-c` adds the evidence packet ABI above v13-a/v13-b. It produces a
  hash-manifested packet and v12-style claim-matrix input from the bound run
  evidence, while keeping learned-ranking and real/nonfixture claims blocked.
- `v13-d` adds the NLG transcript binding ABI above v13-a/v13-b/v13-c. It
  validates transcript/result rows against route-memory span bytes and keeps
  real PC RouteLM NLG blocked until nonfixture generator evidence exists.
- `v13-e` adds the public codebase RouteQA binding ABI above v13-a/v13-b/v13-c/v13-d.
  It validates the local codebase-mini trace/result/evaluator rows while
  keeping independent external benchmark evidence blocked.
- `v13-f` adds the resource envelope ABI above v13-a/v13-b/v13-c/v13-d/v13-e.
  It validates workload/timing/storage/memory rows while keeping real workload
  speed evidence and GPU speedup claims blocked.
- `v13-g` adds the real evidence promotion gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f.
  It validates that the diagnostic bindings are intact, then blocks release
  promotion until the four real-evidence weaknesses are solved together.
- `v13-h` adds the real evidence intake gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g.
  It validates the same-run package shape required to replace the four blockers
  while keeping release blocked until live verification and regenerated run
  bindings exist.
- `v13-i` adds the real evidence live-network gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h.
  It validates same-run source/review/authority receipt hashes and live-network
  receipt status while keeping release blocked until runtime fetch and
  regenerated run bindings exist.
- `v13-j` adds the real evidence rebind gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i.
  It validates receipt-hash replay into same-run replacement artifacts and
  claim-matrix rows while keeping release blocked until runtime fetch and
  regenerated promotion rows exist.
- `v13-k` adds the runtime fetch provenance gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j.
  It validates runner-owned receipt JSON provenance while keeping release
  blocked until the v13-i source is `runtime-live-fetch`.
- `v13-l` adds the source seed gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j/v13-k.
  It binds current RULER/LongBench public source seeds without allowing
  project-source-only rows to become claim evidence.
- `v13-m` adds the source seed live-fetch gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j/v13-k/v13-l.
  It verifies optional runtime receipts for those seeds while keeping source
  availability separate from real claim evidence.
- `v13-n` adds the external benchmark official source acquisition gate above v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j/v13-k/v13-l/v13-m.
  It verifies runner-owned acquisition of public benchmark source metadata while
  keeping benchmark result/evaluator evidence blocked.
- `v14-a` adds `tools/routelm_benchmark_run`, a runner-owned execution CLI that
  produces source, dataset, store, raw prediction, evaluator, metrics, RouteQA,
  benchmark, resource, evidence, and promotion artifacts in one run directory.
  It now includes `source_snapshot_rows.csv` and optional live git fetch of the
  official RULER/LongBench HEAD SHAs from v13-n source acquisition receipts,
  plus `--repo-from-source-snapshot` so a fetched official snapshot can become
  the repo used for query materialization and evaluator output. It also has an
  optional RULER-compatible synthetic smoke that writes NIAH-format prediction
  artifacts, an official evaluator status record, official generator output
  rows for three official NIAH tasks, a multi-task official evaluator summary,
  and generated benchmark/metrics/provenance binding rows.
- `v14-b-lite` is closed as a local prediction-lineage proof, not a new
  external benchmark/release claim. The runner can emit prediction lineage and
  source summary artifacts, mmap/candidate traces, RouteMemory prediction
  evidence rows, a 50-row RouteQA-mini lightweight benchmark, Stage 8.2-L
  shortcut/corruption negative rows, tiny generator-hint NLG rows under `nlg/`
  plus grounding evidence, explicit `query/`, `mmap/`, and `prediction/` alias
  artifacts for the Stage 10-Lite output tree, and a CPU-canonical
  RX 6900XT/32GB/500GB-lite resource envelope. The smoke verifies
  `prediction_lineage_ready=1`, `no_extractor_prediction_ready=1`,
  `promoted_prediction_rows == promoted_route_memory_prediction_rows`,
  `shortcut_negative_suite_ready=1`, `hash_clean_wrong_span_block=1`,
  `corrupted_route_index_block=1`, `corrupted_chunk_offsets_block=1`,
  `generator_hint_nlg_ready=1`, `resource_envelope_ready=1`,
  `run_layout_ready=1`, `objective_requirements_ready=1`, and
  `execution_chain_manifest_ready=1`, while keeping real external
  benchmark/release flags blocked. The detailed goal and artifact contract live
  in [V14B_LITE_PREDICTION_LINEAGE_GOAL.md](V14B_LITE_PREDICTION_LINEAGE_GOAL.md).
- Current verification has h6-t/u/v/w/x/y, h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s, h7-b, h7-c,
  v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation/readiness,
  the v08 lower-chain remote-artifact path and v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at real-source/remote-review/remote-full source-import/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation guards, h11-a prototype
  readiness/import, h11-b artifact verifier/import, h11-c NVMe RouteMemory
  store/artifact smokes, h11-d PC RouteLM NLG smoke, h9-h, v12, v13-a, v13-b,
  v13-c, v13-d, v13-e, v13-f, v13-g, v13-h, v13-i, v13-j, v13-k, v13-l, v13-m, and v13-n included in and passing quick closure paths through
  h7-c/v08-at/h11-d/h9-h/v12/v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j/v13-k/v13-l/v13-m/v13-n.
  HIP parity remains optional and environment-dependent.

Post Stage 10-Lite roadmap:

- Keep `v14-b-lite` frozen as the local proof baseline. It is the smallest
  reproducible claim that a RouteMemory mmap value-byte path can produce
  promoted predictions with no oracle, no raw-input extractor, shortcut
  negatives blocked, generator-hint grounding recorded, and source/dataset/
  query/store/mmap/prediction/evaluator/metrics/evidence/promotion/resource
  artifacts hash-bound in one run directory. This remains a local proof and
  must not set `candidate_external_benchmark_result_ready`,
  `real_external_benchmark_verified`, or `real_release_package_ready`.
- `v14-c` is closed as the baseline-comparison boundary. It compares input
  extractor, BM25/lexical retrieval, RouteMemory retrieval-only, RouteMemory
  exact value read, RouteMemory plus proposal hint, and tiny generator-hint NLG
  on the same 50-row RouteQA-mini package plus shortcut negatives. The runner
  emits
  `benchmark/baseline_comparison_rows.csv`,
  `benchmark/baseline_negative_case_rows.csv`,
  `metrics/baseline_comparison_metrics.json`,
  `resource/baseline_latency_rows.csv`, and
  `promotion/baseline_promotion_guard_rows.csv`. The focused smoke verifies
  six baselines, 66 baseline/negative-case rows,
  `route_memory_safety_dominates_baselines=1`,
  `input_extractor_baseline_only=1`,
  `baseline_promotion_guard_ready=1`, and keeps real external
  benchmark/release flags blocked.
- `v14-d` is closed as the local scale boundary above v14-c. The scale runner
  executes 100-row and 150-row public-codebase RouteQA-mini runs while keeping
  CPU canonical, HIP optional, run directories below the local budget, route
  and jump rates at zero, and all v14-b-lite/v14-c lineage, negative-suite,
  NLG-grounding, baseline-comparison, resource-envelope, run-layout,
  objective, and execution-chain contracts intact. This is still runner-owned
  lightweight benchmark evidence, not independent external benchmark
  verification.
- `v14-e` is closed as a RULER NIAH-lite runner-owned external-source smoke.
  It keeps the scale small with a RULER-compatible NIAH row plus a 100-row
  RouteQA-mini local context, derives the NIAH prediction through a dedicated
  RouteMemory mmap store, writes compatible benchmark/metrics/provenance rows,
  normalizes one ready runner-owned external benchmark row, and reaches
  `runner_owned_external_benchmark_result_ready=1` while real/candidate
  benchmark and release flags remain blocked.
- `v15-a` is closed as the independent reproduction mechanics package around
  the v14-b/v14-c/v14-d/v14-e outputs. It provides one-command reproduction,
  expected summary/decision CSVs, frozen query sets, source snapshot
  rows/manifests, resource envelopes, run sha256 manifests, package artifact
  and environment manifests, failure-mode documentation, and explicit "what
  this does not claim" notes. This is a replay package for runner-owned
  evidence, not independent benchmark verification by itself.
- `v15-b` is closed as local nonfixture review / independent rerun mechanics
  above v15-a. It binds the v15-a package hash, reviewer identity, rerun
  environment, reproduced command stdout/stderr hashes, expected-vs-rerun
  summary copies, metric deltas, and pass/fail review rows. This is still a
  runner-owned local review package; external independent reviewer, candidate
  benchmark, real benchmark, and release flags remain blocked until a real
  third-party/non-local rerun is supplied.
- `v16` is closed as two explicit tracks. The research track is a
  publication-style packet that binds hypothesis, method, RouteMemory lineage,
  shortcut-resistance, baseline/scale/NIAH-lite results, reproducibility,
  review/rerun evidence, limitations, and claim boundaries. The commercial
  track is a local codebase QA/audit prototype contract with evidence-bound
  answers, citation requirements, abstention behavior, local-first privacy
  assumptions, user-facing failure modes, and blocked unsupported product
  claims. It is not a release or external benchmark verification package.
- Defer large generators and GPU speed claims. The generator track should first
  harden `nlg/` grounding, unsupported-claim detection, and abstain behavior;
  only then test a tiny non-attention or quantized generator. HIP on RX 6900XT
  remains a parity/diagnostic path until CPU/HIP result hashes or tolerance
  bounds, kernel/fallback rows, and real timing evidence are bound to the same
  run package.
- Recommended attachment after `v14-d` is evidence-bound local codebase QA and
  audit. Research-wise, this gives the cleanest test surface for RouteMemory
  lineage, no-extractor prediction, shortcut resistance, abstention, and
  benchmark comparability because every answer can be tied to a source span,
  mmap trace, evaluator row, and negative case. Commercially, the same surface
  maps to a local-first code review / documentation QA / compliance-audit
  prototype, but it should remain a prototype until v15 independent
  reproduction and nonfixture review evidence exist.

Current next boundary:

- `v17` is closed as a post-v16 externalization handoff, not actual external
  validation. It separates three tracks: third-party rerun, official benchmark
  reconciliation, and commercial closed-corpus local QA/audit PoC. The package
  prepares commands, schemas, required artifact rows, manifest templates, and
  acceptance criteria while keeping `independent_rerun_actual_ready=0`,
  `candidate_external_benchmark_result_ready=0`,
  `closed_corpus_poc_actual_ready=0`, real benchmark, and release flags blocked.
- `v18` is closed as the supplied external evidence intake verifier above v17.
  With no supplied directories it keeps all actual/candidate flags blocked.
  With supplied non-fixture directories it can verify third-party rerun,
  official benchmark reconciliation, and commercial closed-corpus PoC evidence
  through `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and
  `V18_COMMERCIAL_POC_DIR`. The included fixture smoke proves verifier logic
  only; it is not real external evidence.
- `v19` is closed as the external submission bundle above v18, not as external
  validation. It packages third-party rerun submission/runbook files, official
  benchmark slice requirements, commercial local evidence-bound QA/audit PoC
  intake files, v18 return commands, track rows, artifact hashes, and
  `docs/POST_V18_RESEARCH_ROADMAP.md`. It marks only submission readiness and
  keeps `independent_rerun_actual_ready=0`,
  `candidate_external_benchmark_result_ready=0`,
  `closed_corpus_poc_actual_ready=0`, real benchmark, and release flags blocked.
- `v20` is closed as the external return tracker above v19/v18. It turns the
  three externalization tracks into explicit required-return rows, blocker rows,
  and next-action rows, and forwards optional `V20_THIRD_PARTY_RERUN_DIR`,
  `V20_OFFICIAL_BENCHMARK_DIR`, and `V20_COMMERCIAL_POC_DIR` directories into
  the v18 verifier. The default no-return path is intentionally blocked for all
  actual/candidate/release flags, but the remaining evidence gaps are now
  machine-readable.
- `v21` is closed as the external review dispatch kit above v20. It packages
  reviewer-facing requests for the third-party rerun, official benchmark
  reconciliation, and commercial local QA/audit PoC tracks, a packet index,
  return directory layout, verification command script, copied return templates,
  tracker summary, source manifests, and artifact hashes. It is the handoff
  packet to send outward, not evidence that the external review has already
  happened.
- `v22` is closed as the clean-machine execution kit above v21. It adds host
  and container clean-machine runbooks, a minimal container recipe, a
  third-party rerun capture script, reviewer/environment templates, official
  benchmark and commercial PoC return templates, execution notes, verification
  notes, manifests, and artifact hashes. The capture script now auto-populates
  v15-b metric delta rows and review rows after a successful rerun, leaving
  reviewer identity and true clean-machine independence as the remaining
  external fields. This reduces ambiguity for the real third-party rerun path
  but does not substitute for an actual returned independent review directory.
- `v23` is closed as the official benchmark reconciliation kit above v22. It
  adds an official-slice runbook, return directory layout, evaluator/container
  contract, no-oracle/no-raw-input-extractor contract, raw prediction template,
  RouteMemory-derived prediction-lineage template, metrics/provenance/
  reproducibility templates, a return-file preflight script, v20 verification
  notes, manifests, and artifact hashes. This reduces ambiguity for the real
  RULER/LongBench reconciliation path but does not substitute for returned
  official benchmark evidence.
- `v24` is closed as the current external send/receive/verify handoff above
  v21/v22/v18. It explicitly says what to send (`v21` dispatch kit plus `v22`
  clean-machine execution kit), what to receive (third-party rerun, official
  benchmark, or commercial closed-corpus PoC return directory), and how to
  verify with direct `V18_THIRD_PARTY_RERUN_DIR`,
  `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR` commands. This is
  the operational packet for the updated objective; it still cannot move actual
  flags without returned external directories.
- `v25` is closed as the outbound send manifest above v24. It hash-manifests
  all outbound `v21` dispatch-kit and `v22` clean-machine execution-kit files,
  provides receiver acknowledgement, return-option, and direct v18 verification
  instructions, and records artifact hashes. This makes the send step auditable
  but still does not replace a returned external directory.
- `v26` is closed as the single external send bundle above v25. It copies all
  outbound `v21` and `v22` files into one `send_bundle/`, writes bundle file and
  sha256 manifests, receiver integrity-check instructions, direct v18 return
  verification notes, source manifests, and artifact hashes. This is the current
  directory to send outward; it still does not replace a returned external
  directory.
- `v27` is closed as the external send archive above v26. It packages the v26
  send bundle into a transfer-friendly `tar.gz`, writes archive sha256 sums,
  archive listing, receiver archive/return verification notes, source manifests,
  and artifact hashes. This makes outbound transfer easier; it still does not
  replace returned external evidence.
- `v28` is closed as the inbound return inbox above v27/v18. It creates standard
  return locations for third-party rerun, official benchmark, and commercial
  closed-corpus PoC directories, mirrors the latest v18 intake result, and
  invokes v18 only for non-empty return directories. Empty placeholder inboxes
  are not promoted into supplied evidence.
- `v29` is closed as the receiver-side return preflight kit above v28. It checks
  default v28 inbox paths or supplied `V29_*_RETURN_DIR` paths for required
  third-party rerun, official benchmark, and commercial PoC return files, writes
  missing-file rows and v18 verification instructions, and remains a preflight
  gate only. It does not promote actual/candidate/release readiness.
- `v30` is closed as the commercial codebase QA closed-corpus PoC return above
  v29/v18. It generates a repository-only commercial return directory with
  source-bound query rows, exact source hashes, PoC result rows, audit trail,
  resource envelope, privacy review, acceptance review, and artifact hashes.
  v29 sees the commercial return as complete and v18 verifies
  `closed_corpus_poc_actual_ready=1`. This closes the first commercial PoC
  evidence loop while leaving third-party rerun, official benchmark, real
  external benchmark, and release readiness blocked.
- `v31` is closed as the official RULER NIAH candidate return above v30/v18. It
  live-binds the current `NVIDIA/RULER` HEAD, hashes upstream `prepare.py`,
  `evaluate.py`, and README source files, and returns official source,
  evaluator, raw prediction, RouteMemory lineage, metrics, provenance,
  reproducibility, and candidate rows. v18 verifies
  `candidate_external_benchmark_result_ready=1`, and v20 can track official
  candidate plus commercial PoC returns together. Real external benchmark and
  release remain blocked until third-party rerun evidence arrives.
- `v32` is closed as the GitHub Actions third-party rerun kit above v31/v22/v18.
  It adds a workflow that runs the v22 capture script on a GitHub-hosted
  `ubuntu-24.04` runner, fills reviewer/environment provenance, invokes v18, and
  uploads the return artifact. PR run `27029089994` completed successfully,
  downloaded `third-party-rerun-return`, and local v18 intake verified that
  artifact together with the v31 official RULER candidate and v30 commercial
  codebase QA PoC. The verified closure flags are
  `independent_rerun_actual_ready=1`,
  `candidate_external_benchmark_result_ready=1`,
  `closed_corpus_poc_actual_ready=1`, and
  `real_external_benchmark_verified=1`; `real_release_package_ready=0` remains
  blocked until a separate release audit packet.
- `v33` is closed as the evidence-closure packet above v32/v31/v30/v18. It
  reruns v18 against the latest downloaded GitHub Actions third-party return,
  v31 official candidate return, and v30 commercial PoC return, copies those
  evidence directories plus v18 summary/decision rows into one packet, hashes 59
  packet files, and writes an explicit claim boundary plus human-review request.
  It verifies `v33_evidence_closure_packet_ready=1` while keeping
  `human_review_completed=0` and `real_release_package_ready=0`.
- `v34` is closed as the official benchmark expansion packet above
  v33/v31/v18. It expands the v31 RULER NIAH candidate along one axis only:
  raw prediction rows increase from 1 to 6 while benchmark family, task family,
  context length, official source snapshot, and evaluator digest stay fixed. It
  writes raw predictions, RouteMemory lineage, expansion metrics, candidate
  result rows, `EXPANSION_BOUNDARY.md`, `benchmark_expansion_manifest.json`,
  and `sha256_manifest.csv`, then reruns v18 with the v34 official return plus
  v33 third-party/commercial evidence. It verifies
  `v34_official_benchmark_expansion_packet_ready=1`,
  `candidate_external_benchmark_expansion_ready=1`, and
  `real_external_benchmark_verified=1` while keeping
  `human_review_completed=0` and `real_release_package_ready=0`.
- `v35` is closed as the commercial pilot packet above v34/v33/v18. It reuses
  the v30 commercial-return schema for one buyer-visible workflow,
  `internal_docs`, and writes five source-cited internal-document QA rows,
  including one release-claim abstain row, plus privacy/resource/acceptance
  reviews, `COMMERCIAL_PILOT_BOUNDARY.md`, `commercial_pilot_manifest.json`,
  and `sha256_manifest.csv`. It reruns v18 with v33 third-party evidence, the
  v34 official expansion return, and the v35 commercial pilot return. It
  verifies `v35_commercial_pilot_packet_ready=1`,
  `closed_corpus_poc_actual_ready=1`, and
  `real_external_benchmark_verified=1` while keeping
  `human_review_completed=0` and `real_release_package_ready=0`.
- `v36` is closed as the release-claim audit packet above v33/v34/v35. It
  copies evidence manifests, summaries, decisions, and claim boundaries from
  v33/v34/v35, writes `claim_matrix.csv`, `evidence_input_rows.csv`,
  `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`,
  `human_review/HUMAN_REVIEW_REQUEST.md`,
  `human_review/human_review_template.csv`,
  `v36_release_claim_audit_manifest.json`, and `sha256_manifest.csv`, and
  decides the maximum allowed public wording. It verifies
  `v36_release_claim_audit_packet_ready=1`, `evidence_inputs_ready=1`,
  `maximum_allowed_claim_decided=1`, and `human_review_request_ready=1`; the
  maximum allowed wording is bounded to
  local evidence-bound QA/audit with deterministic provenance, source-cited
  answers, conservative abstention, and externally reproducible evidence
  packets. It keeps `human_review_completed=0` and
  `real_release_package_ready=0`, with release-ready product and stronger model
  replacement claims blocked.
- `v37` is closed as the human review intake verifier above v36. It copies the
  v36 human-review request/template, consumes an optional returned
  `human_review_rows.csv`, normalizes the four required review items, checks
  reviewer identity, timestamps, and all-pass status, and writes
  `human_review_intake_manifest.json`, `normalized_human_review_rows.csv`,
  `missing_review_rows.csv`, and `sha256_manifest.csv`. The default current run
  verifies `v37_human_review_intake_ready=1` while keeping
  `human_review_return_supplied=0`, `human_review_completed=0`, and
  `real_release_package_ready=0`; an isolated fixture pass path verifies that a
  complete review return can set `evidence_set_human_review_accepted=1` without
  making release readiness automatic.
- `v38` is closed as the human review dispatch bundle above v37/v36. It copies
  the v36 review request, release audit, claim matrix, decision rows,
  evidence-input rows, v36/v37 manifests, and missing-review rows into
  `review_packet/`, prepares `return/human_review_rows.csv`, writes
  `verify/VERIFY_RETURN.sh`, `HUMAN_REVIEW_DISPATCH_README.md`,
  `dispatch_rows.csv`, `human_review_dispatch_manifest.json`, and
  `sha256_manifest.csv`. It verifies
  `v38_human_review_dispatch_bundle_ready=1`, `return_template_ready=1`, and
  `verify_script_ready=1`, while keeping `human_review_completed=0` and
  `real_release_package_ready=0`.
- `v39` is closed as the human review dispatch archive above v38. It archives
  the v38 bundle as
  `archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz`, writes
  `archive/ARCHIVE_SHA256SUMS.txt`, `archive/ARCHIVE_FILE_LIST.txt`,
  `SEND_ARCHIVE_README.md`, `artifact_manifest.csv`,
  `human_review_dispatch_archive_manifest.json`, and `sha256_manifest.csv`. It
  verifies `v39_human_review_dispatch_archive_ready=1`,
  `archive_sha256_ready=1`, `archive_file_list_ready=1`, and required
  review/return/verify archive members present while keeping
  `human_review_completed=0` and `real_release_package_ready=0`.
- `v40` is closed as the machine-verified research artifact above v33-v39. It
  copies the v36 release-claim audit, the v37 no-return human-review intake
  state, the v38 dispatch bundle evidence, the v39 transfer archive evidence,
  and the v33/v34/v35 support summaries, then writes
  `MACHINE_VERIFIED_RESEARCH_ARTIFACT.md`, `release_mode_rows.csv`,
  `allowed_claim_rows.csv`, `blocked_claim_rows.csv`,
  `machine_verification_rows.csv`, `evidence_index.csv`,
  `v40_machine_verified_research_artifact_manifest.json`, and
  `sha256_manifest.csv`. It verifies
  `v40_machine_verified_research_artifact_ready=1`,
  `automated_research_artifact_ready=1`, and
  `machine_verified_prototype_ready=1`, plus
  `machine_verification_ready=1` for clean-runner, v18 intake,
  RouteMemory-lineage, no-oracle/no-extractor, and closed-corpus PoC support,
  while keeping
  `human_review_completed=0`, `human_review_required_for_public_release=1`, and
  `real_release_package_ready=0`.
- `v41` is closed as the RULER NIAH 50-row academic scale-up above v34/v33/v18.
  It runs the v34 expansion engine at 50 rows and fixed 4096 context length,
  verifies 50 raw prediction rows, 50 RouteMemory lineage rows, official
  evaluator/source reuse, no-oracle/no-extractor status, and v18 intake, while
  keeping `human_review_completed=0` and `real_release_package_ready=0`.
- `v42` is closed as the Codebase Auditor 200-query buyer-visible industrial
  demo above v18. It writes a `codebase_qa` commercial return with 200
  source-cited repository QA/audit rows, 200 audit-trail rows, at least 20
  abstain rows for unsupported readiness/replacement claims, privacy/resource
  review, acceptance review, and v18 verification, while keeping
  `human_review_completed=0` and `real_release_package_ready=0`.
- `v43` is closed as the Doc-Code Conflict Detection audit above v42/v18. It
  derives implementation facts from v42 evidence, checks a bounded doc-code
  conflict corpus, finds 8 mismatch rows while preserving 4 consistent rows,
  binds every decision to documentation and implementation source spans, and
  verifies the return through v18, while keeping `human_review_completed=0` and
  `real_release_package_ready=0`.
- `v44` is closed as the Tiny Non-Attention Generator Hint smoke above v43/v18.
  It uses compact RouteHint payloads with a finite-state/template generator,
  records zero attention layers, zero transformer blocks, and zero raw prompt
  context bytes, verifies grounded answers plus missing-query abstention through
  v18, and keeps `human_review_completed=0` and
  `real_release_package_ready=0`.
- `v45` is closed as the LongBench v2 small slice above v44/v18. It snapshots
  THUDM/LongBench official source/evaluator files, writes 6 multiple-choice raw
  prediction rows across 6 LongBench v2 task categories with RouteMemory
  lineage, verifies the official return through v18, and keeps
  `real_external_benchmark_verified=0` plus `real_release_package_ready=0`.
- `v46` is closed as the Source-Verified Scorer mainline above v45/v18. It
  trains and verifies a deterministic candidate scorer from 12 labels bound to
  v45 official benchmark evidence, uses no local teacher-harness labels, and
  verifies ranking improvement plus wrong-candidate guard through v18, while
  keeping `real_release_package_ready=0`.
- `v47` is closed as the Offline Domain Policy Update above v46/v18. It writes
  15 offline policy rows across 3 domains and 5 learning targets: candidate
  selection, span read, hint strength, abstain/retry, and verifier decision.
  It keeps `expert_replacement_claim=0`, `release_ready_claim=0`, and
  `real_release_package_ready=0`.
- `v48` is closed as the first post-v47 evidence-scale generator expansion. It
  verifies that `RouteMemory evidence -> compact RouteHint -> tiny
  non-attention generator -> grounded answer -> citation/abstain/audit trail`
  holds across RULER NIAH, LongBench v2, codebase QA, and internal docs QA with
  zero raw context in hints, zero raw prompt stuffing, zero raw span copying,
  zero direct hint-value echo, and 20 answer-row RouteHint transformations.
- `v49` is closed as the fixed-context RULER NIAH 200/500-row scale above
  v34/v33/v18. It verifies 200 and 500 raw prediction rows, matching
  RouteMemory lineage rows, official evaluator/source reuse, no-oracle/
  no-extractor status, fixed 4096 context length, fixed architecture, and v18
  intake while keeping release readiness blocked.
- `v50` is closed as the Public Repo Auditor 3-repo evidence run above
  v42/v43/v18. It checks out pinned commit SHAs for `pypa/sampleproject`,
  `psf/requests`, and `pallets/click`, binds requested refs, HEAD SHAs/source
  hashes, verifies 9 audit cases with independent detector outputs across
  doc-code conflict, deprecated/legacy usage, and config mismatch, verifies
  guard negative controls, and passes the commercial return through v18 while
  keeping release readiness blocked.
- `v51` is closed as the Real-return Evidence Intake measured trace above
  v18/v40. It measures CPU SHA-256 batch work and filesystem/NVMe-style reads
  over tracked repository source files, hash-binds the trace artifacts, exposes
  three cited QA/audit rows through v18, binds the result to the v40
  machine-verified artifact ladder, and keeps external/buyer return,
  teacher-source import, GPU speedup, human review, and release readiness
  blocked.
- `v0.3 Architecture Preview` is closed as the first clone-and-run public
  preview surface. `scripts/audit_my_repo.sh` emits a Markdown audit report,
  JSONL/CSV machine artifacts, citation spans, RouteMemory lineage, mmap read
  trace, compact RouteHint rows, grounded generation rows, abstentions,
  resource envelope, reproduce script, and hash manifest. `scripts/run_local_scaling_matrix.sh`
  adds the one-axis store/top-k/cache/RouteHint/query-count scaling matrix. The
  showcase command `examples/local_codebase_intelligence_box.sh` bundles the
  audit report, baseline note, local scaling note, architecture trace,
  lineage/citation/RouteHint/generation artifacts, and hashes. The smoke
  verifies the one-command audit, local scaling matrix, 8-way baseline-war
  binding, RouteHint generator mainline, no raw prompt stuffing, no
  attention/Transformer blocks, no oracle, and no raw-input extractor, while
  keeping release and GPU-speedup claims blocked.
- The v41-v51 impact roadmap is closed. The next public timing target is
  `v1.0 Architecture Challenge`, not a broad v0.3 claim. The new chain is
  v52 30B/70B/100B+ LLM+RAG baseline war, v53 public repo 10-30 repo /
  1000-3000 query code/doc audit, v54 RouteHint non-attention generator
  1000+ rows, v55 local scaling law main run, v56 RULER/LongBench expanded
  benchmark, v57 domain expert packs, v58 blind eval versus 30B-150B-class
  systems, v59 one-command challenge demo, and v60 v1.0 Architecture Challenge
  Release. See `docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`.
- `v52` is started as a baseline-war contract scaffold. `experiments/test_v52_llm_rag_baseline_war.sh`
  emits the A-H registry, adapter contracts, symmetric evaluation axes, copied
  v0.3 source-preview artifacts, and claim boundary, but keeps full v52 blocked
  until real 30B and 70B LLM+RAG rows exist.
- `v52b` adds the first measured small local RAG row for system B.
  `experiments/test_v52b_small_local_rag_measured_row.sh` emits nine measured
  answer rows plus citation/retrieval/resource rows over the v50 public-repo
  seed, marks the row `v52_absorb_ready=1`, and still keeps full v52 blocked
  until C/D/E real baseline rows exist.
- `v52f` expands system B from the 9-row seed to a 100-row measured run.
  `experiments/test_v52f_small_local_rag_measured_100.sh` emits 100 answer
  rows plus citation, abstain, wrong-answer guard, resource, source-manifest,
  and 300 retrieval rows over the frozen v53d query IDs. It marks the B-100
  layer `v52_absorb_ready=1`, but keeps full v52 blocked until A/G/H are run
  over the same frozen query set and real C/D/E evidence directories validate.
- `v52g` expands system B from 100 rows to a stratified 300-row measured run.
  `experiments/test_v52g_small_local_rag_measured_300.sh` emits 300 answer
  rows plus citation, abstain, wrong-answer guard, resource, source-manifest,
  frozen query/source subset, and 900 retrieval rows over v53e, including 48
  negative/abstain query rows. It marks the B-300 layer `v52_absorb_ready=1`,
  while that layer still kept B-1000, A/G/H same-query-set rows, C/D/E
  evidence, and full v52 blocked.
- `v52h` expands system B to the full 1000-row measured run over v53e.
  `experiments/test_v52h_small_local_rag_measured_1000.sh` emits 1000 answer
  rows plus citation, abstain, wrong-answer guard, resource, source-manifest,
  frozen query/source rows, and 3000 retrieval rows, including 160
  negative/abstain query rows. It closes the B 9->100->300->1000 ladder while
  keeping A/G/H same-query-set rows, C/D/E evidence, and full v52 blocked.
- `v52i` adds the local A/B/G/H same-query measured packet.
  `experiments/test_v52i_abgh_same_query_measured_1000.sh` emits A, B, G,
  and H over the same full frozen v53e query set and source manifest, with
  4000 answer/citation/abstain/wrong-answer/resource rows, 12000 retrieval
  rows, 2000 G/H RouteHint rows, and per-system metrics. It closes the local
  same-query packet while keeping C/D/E evidence, 30B/70B baselines, and full
  v52 blocked.
- `v52j` absorbs the local measured packet into the v52 registry.
  `experiments/test_v52j_measured_registry_absorb.sh` writes a measured
  baseline registry where A/B/G/H are row-backed over v53e, copies the v52i
  artifacts, and keeps C/D/E/F blockers explicit. It moves v52 beyond local
  measured rows sitting beside the contract, but full v52 still requires real
  C/D/E evidence directories.
- `v52c` adds the 7B-14B local model + RAG evidence-intake gate for system C.
  `experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh` emits the
  required evidence schema, answer/model templates, validation rows, and hash
  manifest, and still keeps C blocked until a real local-model-RAG evidence
  directory validates.
- `v52k` adds a real 7B local model + RAG measured seed for system C.
  `experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh` runs local
  Ollama `qwen2.5:7b-instruct` over the v50 9-query seed, writes answer,
  citation, resource, transcript, and model-identity rows, and validates them
  through v52c. It keeps C-over-v53e scale, D/E, full v52, and release claims
  blocked.
- `v52l` expands system C to the shared v53e 1000-query set.
  `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh` runs local
  Ollama `qwen2.5:7b-instruct` over the same frozen query/source manifest used
  by v52i A/B/G/H, emits 1000 answer, citation, retrieval, abstain,
  wrong-answer guard, resource, and transcript rows, and marks
  `c_v53e_absorb_ready=1`. It records 0/1000 strict exact-label accuracy, so it
  is a real C response/schema pressure packet rather than a C quality claim;
  D/E, full v52, and release claims stay blocked.
- `v52m` re-absorbs the v52l C measured packet into the v52 measured registry.
  `experiments/test_v52m_measured_registry_c_absorb.sh` promotes A/B/C/G/H over
  the shared v53e 1000-query/source manifest, copies v52i and v52l artifacts,
  records 5000 answer/citation/abstain/guard/resource rows, sets
  `required_7b14b_baseline_ready=1`, and records
  `c_strict_exact_label_accuracy=0.000000` without turning that into a C quality
  claim. D/E, full v52, and release claims stay blocked.
- `v52n` supplies the 30B open-weight LLM+RAG measured seed for system D.
  `experiments/test_v52n_30b_open_weight_llm_rag_measured_seed.sh` runs local
  Ollama `qwen2.5:32b-instruct` over the v50 9-query seed, validates through
  v52d with `d_30b_supplied_evidence_ready=1`, and keeps full D scale, E 70B
  rows, full v52, and release claims blocked.
- `v52o` supplies the 70B open-weight LLM+RAG measured seed for system E.
  `experiments/test_v52o_70b_open_weight_llm_rag_measured_seed.sh` runs local
  Ollama `llama3.1:70b-instruct-q2_K` over the v50 9-query seed, validates
  through v52d with `e_70b_supplied_evidence_ready=1`, and keeps full E scale,
  D 30B real row, full v52, and release claims blocked.
- `v52p` expands D to the full frozen v53e 1000-query/source manifest.
  `experiments/test_v52p_30b_open_weight_llm_rag_v53e_1000.sh` emits 1000 D
  answer/citation/retrieval/abstain/wrong-answer/resource/transcript rows and
  marks `d_v53e_absorb_ready=1` without turning strict exact-label accuracy
  into a D quality claim; E, full v52, and release claims stay blocked.
- `v52q` expands E to the same v53e 1000-row set with
  `experiments/test_v52q_70b_open_weight_llm_rag_v53e_1000.sh`, marks
  `e_v53e_absorb_ready=1`, and keeps D, full v52, and release claims blocked.
- `v52r` re-absorbs the v52p/v52q D/E measured packets into the v52 measured
  registry. `experiments/test_v52r_measured_registry_de_absorb.sh` promotes
  A/B/C/D/E/G/H over the shared v53e manifest, copies v52i/v52l/v52p/v52q
  artifacts, records 7000 answer/citation/abstain/guard/resource rows, sets
  `required_30b_baseline_ready=1` and `required_70b_baseline_ready=1`, and
  keeps optional F, full v52, and release claims blocked.
- `v52y` resolves F optional handling after v52r.
  `experiments/test_v52y_f_optional_final_policy.sh` records F as
  `deferred-with-reason-final` by default, verifies the v52 ready-condition
  matrix, and sets `v52_ready=1` for the measured-baseline-registry scope while
  keeping measured 100B+/150B result wording, v53 complete-source audit, v1.0
  comparison, and release claims blocked.
- `v52s` emits the NVMe hot/warm/cold weight shard store contract aligned with
  h11-c. `experiments/test_v52s_local_llm_weight_tier_contract.sh` marks
  `nvme_mmap_store_ready=1` while keeping tiered decode runtime blocked.
- `v52u` mmap-reads the v52s shard store with hash verification and warm-prefetch
  scaffold rows following the v13-b reader ABI.
  `experiments/test_v52u_local_llm_weight_tier_mmap_reader.sh` marks
  `weight_tier_mmap_reader_ready=1` while keeping ROCm decode binding blocked.
- `v52v` binds a diagnostic ROCm HIP kernel scaffold to v52u hot-tier decode
  steps. `experiments/test_v52v_local_llm_weight_tier_rocm_decode_bind.sh` marks
  `rocm_kernel_bind_ready=1` while keeping full tiered LLM decode runtime blocked.
- `v52t` records explicit `deferred-with-reason` for local monolithic D/E measured
  rows on 16GB VRAM hosts and links v52s/v52u/v52v.
- `v52d` adds the 30B/70B open-weight LLM+RAG evidence-intake gate for systems
  D and E. `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh` emits the
  required D/E evidence schemas, answer/model templates, validation rows, and
  hash manifest, and still keeps v52 blocked until both real D and E evidence
  directories validate.
- `v52e` adds the optional 100B+ hosted/API LLM+RAG evidence-intake/defer gate
  for system F. `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`
  emits the required F schema, answer/model templates, validation rows, and
  hash manifest, while keeping the optional row `deferred-with-reason` until a
  real hosted/API evidence directory validates.
- `v53` is started as a public repo code/doc audit contract scaffold.
  `experiments/test_v53_public_repo_code_doc_audit.sh` emits the 10-repo /
  1000-query scale contract from the v50 3-repo seed, and keeps full v53
  blocked with `missing_repo_count=7` and `missing_query_rows=991`.
- `v53b` adds a live public repo 10-lock layer.
  `experiments/test_v53b_public_repo_10_lock.sh` resolves HEAD SHAs for 10
  public GitHub repositories and writes the 1000-row query plan, but keeps full
  v53 blocked until source snapshots, source-span-bound query rows,
  answer/citation/resource rows, negative/abstain rows, and review artifacts
  exist.
- `v53c` adds pinned canary source snapshots for the 10 locked public repos.
  `experiments/test_v53c_public_repo_canary_source_snapshot.sh` fetches
  source/doc/config canary files from the locked HEAD SHAs and records sha256
  content rows, but keeps full v53 blocked until complete source snapshots and
  the 1000-row audit evidence exist.
- `v53d` adds a 100-row source-span-bound canary query seed.
  `experiments/test_v53d_canary_source_query_seed_100.sh` derives 10 query rows
  per locked repo from v53c canary source files and records matching source
  span rows, but keeps full v53 blocked with `missing_query_rows=900`,
  negative/abstain families missing, and A-H answer/citation/resource rows
  missing.
- `v53e` adds a 1000-row canary-scope query scale layer.
  `experiments/test_v53e_canary_query_scale_1000.sh` scales the v53d seeds to
  1000 source-span-bound query rows across the 10 locked repos, including 840
  supported rows, 160 negative/abstain rows, and eight query families, but
  keeps full v53 blocked until complete source snapshots, A-H
  answer/citation/resource rows, symmetric scorer/policy rows, and review
  artifacts exist.
- `v53f` adds the A-H answer/citation/resource intake layer.
  `experiments/test_v53f_ah_answer_citation_resource_intake.sh` emits the A-H
  system target matrix, required answer/citation/resource schemas, and 8000
  answer/resource template rows over the frozen v53e query set, but keeps full
  v53 blocked with `valid_answer_rows=0` until real supplied comparison rows,
  source citation coverage, resource measurements, complete source snapshots,
  and review artifacts exist.
- `v53g` adds the complete-source manifest layer.
  `experiments/test_v53g_complete_source_manifest.sh` binds the 10 locked repos
  to recursive Git tree source/doc/config/test manifests, records 11318
  metadata-only manifest rows, 11312 query-eligible rows, at least 20
  canary-overlap rows, and an eight-family 1000-query budget. It marks
  `v53g_complete_source_manifest_ready=1` while keeping content materialization,
  complete-source query rows, A-H answer/citation/resource rows, `v53_ready`,
  and release claims blocked.
- `v53h` adds the complete-source content snapshot layer.
  `experiments/test_v53h_complete_source_content_snapshot.sh` materializes the
  v53g manifest into 11318 content files, 11318 content sha256 rows,
  124845122 content bytes, and 11312 query-eligible content rows across all 10
  locked repos. It marks `complete_source_content_snapshot_ready=1` while
  keeping complete-source span extraction, 1000+ complete-source query rows,
  A-H answer/citation/resource rows, `v53_ready`, review artifacts, and release
  claims blocked.
- `v53i` adds the complete-source query instantiation layer.
  `experiments/test_v53i_complete_source_query_instantiation.sh` applies the
  v53g eight-family 1000-query budget to line-level spans from v53h content,
  records 1000 complete-source query rows, 1000 source-span rows, 840 supported
  rows, 160 negative/abstain rows, eight families, and 10-repo coverage. It
  marks `complete_source_query_rows_ready=1` while keeping A-H
  answer/citation/resource rows, symmetric scorer/policy rows, `v53_ready`,
  review artifacts, and release claims blocked.
- `v53j` adds the complete-source A-H intake layer.
  `experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh`
  promotes the v53f intake surface onto the v53i complete-source query set,
  records seven required core systems, 7000 A/B/C/D/E/G/H answer/resource/
  citation targets, and binds optional F to the v52y final-deferred policy. It
  keeps supplied core rows, symmetric scorer/policy rows, `v53_ready`, review
  artifacts, and release claims blocked.
- `v53k` adds complete-source System A lexical measured rows.
  `experiments/test_v53k_complete_source_system_a_lexical_measured.sh` consumes
  v53j and supplies System A/BM25-compatible answer/citation/resource rows over
  the frozen v53i 1000-query set, with retrieval, guard, metric, partial
  `supplied_v53j/`, boundary, manifest, and hash rows. It keeps B/C/D/E/G/H,
  symmetric scorer/policy rows, `v53_ready`, review artifacts, and release
  claims blocked.
- `v53l` adds complete-source System B local-RAG measured rows.
  `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh`
  consumes v53k and supplies System B answer/citation/resource rows over the
  same frozen v53i 1000-query set. It emits combined A+B `supplied_v53j/` rows
  with 2000 answers, 2000 citations, and 2000 resources, while keeping C/D/E/G/H,
  symmetric scorer/policy rows, `v53_ready`, review artifacts, and release
  claims blocked.
- `v53m` adds complete-source System C local-model-RAG measured rows.
  `experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh`
  runs local Ollama `qwen2.5:7b-instruct` over the same frozen v53i 1000-query
  set and emits System C answer/citation/resource/retrieval/abstain/guard/
  transcript rows. It emits combined A+B+C `supplied_v53j/` rows with 3000
  answers, 3000 citations, and 3000 resources, while recording 0/1000 strict
  exact-answer matches and keeping D/E/G/H, symmetric scorer/policy rows,
  `v53_ready`, review artifacts, and release claims blocked.
- `v53n` adds complete-source System G RouteMemory+RouteHint measured rows.
  `experiments/test_v53n_complete_source_system_g_routehint_measured.sh`
  consumes v53m and emits System G answer/citation/resource/retrieval rows,
  1000 route-memory evidence rows, 1000 compact RouteHint rows, and raw prompt
  context bytes 0 over the same frozen v53i 1000-query set. It emits combined
  A+B+C+G `supplied_v53j/` rows with 4000 answers, 4000 citations, and 4000
  resources, while keeping D/E/H, symmetric scorer/policy rows, `v53_ready`,
  review artifacts, and release claims blocked.
- `v53o` adds complete-source System H RouteMemory+RouteHint+source-verified
  scorer+domain-policy measured rows.
  `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
  consumes v53n and emits System H answer/citation/resource/retrieval rows,
  1000 route-memory evidence rows, 1000 compact RouteHint rows, 1000
  source-verified scorer rows, 1000 domain-policy rows, and raw prompt context
  bytes 0 over the same frozen v53i 1000-query set. It emits combined
  A+B+C+G+H `supplied_v53j/` rows with 5000 answers, 5000 citations, and 5000
  resources, while keeping D/E, symmetric scorer/policy rows, `v53_ready`,
  review artifacts, and release claims blocked.
- `v54` is started as a RouteHint generation 1000-row contract scaffold.
  `experiments/test_v54_routehint_generation_1000_contract.sh` emits the
  domain target, invariant, and artifact contracts from v48/v54 seed evidence,
  and keeps full v54 blocked with `missing_generation_rows=976`.
- `v54b` adds the RouteHint generation 1000-row scale run.
  `experiments/test_v54b_routehint_generation_scale_1000.sh` emits 1000
  deterministic local RouteHint generation rows across six domains, including
  900 answer rows, 100 abstain rows, 1000 citation rows, 1000 resource rows,
  zero attention/Transformer/raw-prompt-context rows, and zero wrong-answer
  rows. It marks the v54 machine-verified generation target ready while
  keeping release and 30B-150B equivalence claims blocked.
- `v55` is started as a local scaling law main-run contract scaffold.
  `experiments/test_v55_local_scaling_law_main_contract.sh` emits the six-axis
  / 100-row scaling contract from v51 seed curves, and keeps full v55 blocked
  with `repo_count_axis_ready=0` and `missing_scaling_curve_rows=73`.
- `v55b` adds the local scaling-law main run.
  `experiments/test_v55b_local_scaling_law_main_120.sh` emits six scaling
  axes, 360 curve rows, 60 repo-count rows, 120 confidence-interval rows,
  failure-case rows, resource rows, fit rows, and local source/probe hash
  binding. It marks the v55 machine-verified scaling-law target ready while
  keeping GPU speedup, production latency, release, and 30B-150B equivalence
  claims blocked.
- `v56` is started as a RULER/LongBench expanded benchmark contract scaffold.
  `experiments/test_v56_ruler_longbench_expanded_contract.sh` emits the
  official source/evaluator-bound benchmark contract from v49/v45 seed
  evidence, and keeps full v56 blocked with `ruler_missing_rows=500`,
  `longbench_missing_rows=494`, and `llm_rag_baseline_rows_ready=0`.
- `v56b` adds the expanded RULER/LongBench candidate-scale run.
  `experiments/test_v56b_ruler_longbench_expanded_scale.sh` emits 1500
  benchmark-format prediction rows, 1000 RULER rows, 500 LongBench rows, and
  1500 lineage/candidate/resource rows with no oracle or raw-input extractor.
  It marks the row-count target ready while keeping LLM+RAG baseline rows,
  independent external benchmark verification, leaderboard, and release claims
  blocked.
- `v57` is started as a domain expert packs contract scaffold.
  `experiments/test_v57_domain_expert_packs_contract.sh` emits six domain-pack
  targets, expert-review artifact contracts, and policy gates from
  v47/v48/v52/v56 seed evidence, and keeps full v57 blocked with
  `missing_eval_rows=950`, `human_expert_review_ready=0`, and
  `blind_eval_ready=0`.
- `v57b` adds the domain expert pack candidate-scale set.
  `experiments/test_v57b_domain_expert_pack_candidate_1000.sh` emits 1000
  source-span-bound candidate eval rows across six packs, 900 answer rows,
  100 abstain rows, 1000 expert-review template rows, policy/rubric/failure
  taxonomy rows, and hash manifests. It marks the candidate surface ready while
  keeping human expert review, blind evaluation, expert-replacement, and release
  claims blocked.
- `v58` is started as a blind evaluation contract scaffold.
  `experiments/test_v58_blind_eval_contract.sh` emits D-H blind-system
  mapping, 500-row query-freeze targets, evaluator contracts, and sealed
  identity/symmetric-evidence gates from v52/v57 seed evidence, while keeping
  full v58 blocked with `missing_blind_eval_rows=500`,
  `required_30b_blind_response_ready=0`, and
  `human_blind_review_ready=0`.
- `v58b` adds the blind-eval candidate freeze.
  `experiments/test_v58b_blind_eval_candidate_500.sh` emits 500 frozen
  source-span-bound blind queries, 2500 D/E/F/G/H response templates, 2500
  anonymous reviewer-packet templates, sealed answer/identity keys,
  same-evidence-budget rows, adjudication templates, and hash manifests. It
  marks the pre-output freeze and review-intake surface ready while keeping real
  blind responses, human blind review, inter-rater rows, and release claims
  blocked.
- `v58c` adds the blind response evidence-intake gate.
  `experiments/test_v58c_blind_response_evidence_intake.sh` emits the D/E/F/G/H
  blind response schema, 2500-row response template, run-identity template,
  validation rows, gate rows, and hash manifest over the v58b frozen query set.
  It keeps required response readiness, human blind review, inter-rater rows,
  full v58, and release claims blocked until real supplied response rows
  validate.
- `v59` is started as a one-command challenge demo contract scaffold.
  `examples/v1_0_architecture_challenge_demo.sh` runs the v59 bundle builder,
  which assembles v52-v58 contract artifacts, stage/gate rows, a replay
  command, README_RESULT, and sha256 manifest while keeping full v59 blocked
  with `v59_ready=0` and all v52-v58 full-ready stage rows at zero.
- `v59b` adds the one-command candidate/intake-chain replay.
  `examples/v1_0_architecture_challenge_candidate_demo.sh` runs the v59b
  bundle builder, which assembles v52b-v58c candidate/intake artifacts, stage
  rows, gate rows, README_RESULT, boundary, and sha256 manifest. It marks the
  current candidate replay bundle ready while keeping real LLM rows,
  complete-source audit, human review, full v59, and release claims blocked.
- `v59c` adds the one-command measured-registry replay.
  `examples/v1_0_architecture_challenge_measured_registry_demo.sh` runs the
  v59c bundle builder, which assembles the v52m A/B/C/G/H measured registry plus
  the current v53e-v58c candidate chain, stage rows, gate rows, README_RESULT,
  boundary, and sha256 manifest. It promotes the local 1000-query measured
  registry into replay while keeping D/E real rows, complete-source audit,
  human review, full v59, and release claims blocked.
- `v60` is started as a release-audit contract scaffold.
  `experiments/test_v60_architecture_challenge_release_contract.sh` consumes
  the v59 bundle, emits release requirement rows, allowed/forbidden claim rows,
  and release decision rows, and keeps full v60 blocked with `v60_ready=0`,
  all ten release requirements blocked, and `real_release_package_ready=0`.
- `v60b` adds the release preflight candidate audit.
  `experiments/test_v60b_release_preflight_candidate_audit.sh` consumes the
  v59b one-command candidate replay, emits release-preflight requirements,
  claim rows, stage release-audit rows, decision rows, boundary, and sha256
  manifest. It allows only limited candidate-chain replay wording and keeps v1.0
  release, 30B-150B comparison, QA superiority, expert replacement, production,
  and release-package claims blocked.
- `v61` is implemented as an SSD-resident MoE active-sparse runtime prototype.
  `docs/V61_SSD_RESIDENT_MOE_RUNTIME.md` documents the implementation direction:
  an NVMe SSD model warehouse for hundreds-B to trillions-parameter open-weight
  models, active-sparse MoE/page routing, RouteHint prefetch plans, VRAM hot
  cache, page-level mixed quantization, KV-cache policy, and token-level I/O
  budgets such as `ssd_read_bytes_per_token`. It treats v52s/v52u/v52v/v52w as
  the seed for a real weight-page runtime. `experiments/test_v61j_one_command_ssd_resident_demo.sh`
  now closes v61a-v61j: SSD page store, direct I/O reader, RouteHint prefetch,
  VRAM hot cache, CPU page-dequant-matmul checks, expert routing, predictive
  prefetch, mixed quant planning, dense stress blockers, a logical 128B MoE
  active-sparse contract, and a one-command demo. The summary reaches
  `ssd_resident_active_sparse_path_proven=1`, `ram_resident_full_model_fallback_rows=0`,
  `total_parameters=128000000000`, `ssd_read_bytes_per_token_max=8388608`, and
  `route_jump_rows=0`, while real 100B checkpoint materialization,
  near-frontier quality, dense hundreds-B local-speed, GPU speedup,
  production-latency, and release claims remain blocked.
- `v61k` starts the real-model evidence track.
  `experiments/test_v61k_real_model_page_manifest.sh` binds the v61 page model
  to `mistralai/Mixtral-8x22B-v0.1`, records Apache-2.0 source/config/license
  rows, emits 59 checkpoint-shard manifest rows, enumerates 129024 2 MiB expert
  tensor page metadata rows, and keeps all checkpoint weight bytes out of the
  repository. The summary reaches `legally_redistributable_page_manifest_ready=1`,
  `total_parameters_100b_plus=1`, and `real_checkpoint_weight_bytes_materialized=0`,
  while showing `active_uncached_q4_budget_pass=0`.
- `v61l` adds real ROCm page-kernel timing over the v61k page geometry.
  `experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh` measures one
  synthetic 2 MiB q4-equivalent page tile with `tile_m=1024`, `tile_k=4096`,
  positive `gpu_kernel_avg_ms`, positive `gpu_page_dequant_gflops`, and
  positive `gpu_page_bandwidth_gbps`. It keeps checkpoint weight
  materialization, safetensors page-hash binding, source-bound QA,
  near-frontier quality, production latency, and release claims blocked.
- `v61m` adds KV-cache residency/eviction policy evidence over the v61k Mixtral
  config. `experiments/test_v61m_kv_cache_residency_eviction_policy.sh`
  verifies `kv_bytes_per_token=229376`, `kv_tokens_per_page=9`, a 1024-token
  VRAM hot window plus 128 sink tokens, `max_context_tokens=8192`,
  `max_resident_vram_pages=129`, `max_evicted_nvme_pages=782`,
  `kv_cache_policy_ready=1`, and `host_ram_kv_spill_enabled=0`. It keeps
  safetensors page-hash binding, source-bound QA, long-context quality,
  near-frontier quality, production latency, and release claims blocked.
- `v61n` adds a source-bound QA workload seed over materialized source rows.
  `experiments/test_v61n_source_bound_qa_workload.sh` binds v61j, v61m, v53g,
  and the currently materialized v53c canary-overlap files into source-bound
  query rows, with citation-supported answers, one unsupported-claim abstain per
  repository, 10 repositories, and manifest-bound source files. It keeps
  complete-source A-H QA, real Mixtral generation, safetensors page-hash
  binding, near-frontier quality, production latency, and release claims
  blocked.
- `v61o` strengthens checkpoint identity without full weight residency.
  `experiments/test_v61o_checkpoint_shard_header_probe.sh` fetches the
  safetensors index, HEAD-probes all 59 checkpoint shards, range-reads all shard
  headers, parses 1739 tensor header rows, and hashes three sampled first 2 MiB
  payload pages while persisting zero checkpoint payload bytes. It keeps full
  checkpoint materialization, full page-hash coverage, local SSD checkpoint
  residency, real generation, near-frontier quality, production latency, and
  release claims blocked.
- `v61p` adds local SSD checkpoint residency preflight without downloading
  weights. `experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh`
  consumes v61o, emits an outside-repository warehouse probe, disk budget row,
  checkpoint residency requirements, 59 shard download-plan rows, and 59 local
  shard presence rows. The current host records 281241493344 checkpoint bytes,
  315601231712 bytes required with reserve, 21337460736 available bytes,
  `checkpoint_payload_bytes_downloaded_by_v61p=0`, and
  `local_checkpoint_residency_ready=0`. It keeps full page-hash coverage, real
  generation, near-frontier quality, production latency, and release claims
  blocked.
- `v61q` adds a real safetensors-header-derived checkpoint page map without
  downloading weights. `experiments/test_v61q_real_checkpoint_page_map.sh`
  consumes v61o and maps 1739 real checkpoint tensor offset rows into 134161
  unique 2 MiB checkpoint page rows plus 135841 tensor/page segment rows. It
  records `checkpoint_page_map_weight_bytes_included=0`,
  `checkpoint_weight_bytes_persisted=0`, and keeps full page-hash coverage,
  local SSD checkpoint residency, real Mixtral generation, near-frontier
  quality, production latency, and release claims blocked.
- `v61r` adds a full page-hash sweep plan without downloading weights.
  `experiments/test_v61r_full_page_hash_sweep_plan.sh` consumes v61q and v61p,
  emits 134161 page-hash task rows, binds 3 sampled remote page-hash probes to
  6 overlapping page rows, and records 0 verified local page hashes on the
  current host. It keeps local SSD checkpoint residency, completed full
  page-hash coverage, real Mixtral generation, near-frontier quality,
  production latency, and release claims blocked.
- `v61s` adds one-command source-bound QA replay.
  `experiments/test_v61s_one_command_source_bound_qa_replay.sh` exercises
  `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa`, binds v61j/v61n,
  records exit code 0, 37/37 source-bound query pass rows, and 10/10
  abstain-policy pass rows. It keeps complete-source 1000+ audit completion,
  real Mixtral generation, full page-hash coverage, near-frontier quality,
  production latency, and release claims blocked.
- `v61t` adds local checkpoint materialization identity verification.
  `experiments/test_v61t_local_checkpoint_materialization_verifier.sh` refreshes
  v61p, binds v61q/v61r, and verifies any local outside-repository shards by
  exact byte length, safetensors header hash, and sampled page hash. The current
  host records 0 local existing shards, 0 identity-verified shards,
  `local_checkpoint_materialization_ready=0`, and
  `full_safetensors_page_hash_binding_ready=0`, while keeping real Mixtral
  generation, near-frontier quality, production latency, and release claims
  blocked.
- `v61u` adds bounded remote checkpoint page-hash samples.
  `experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh` consumes v61q
  and v61t, selects 16 deterministic full-size checkpoint pages, and performs
  HTTP Range reads against the real Mixtral checkpoint source while storing only
  hashes and metadata. It records 16 ready remote page-hash sample rows,
  33554432 remote payload bytes read, and
  `full_safetensors_page_hash_binding_ready=0`, while keeping local checkpoint
  materialization, real Mixtral generation, near-frontier quality, production
  latency, and release claims blocked.
- The claim remains local evidence-bound QA/audit assistance until those
  challenge gates pass, not Transformer replacement, frontier local LLM, GPU
  acceleration, long-context solved, or expert replacement.
- The recommended first attachment is codebase QA. It is the cleanest research
  test surface for RouteMemory lineage, no-extractor prediction, citation
  accuracy, abstention, shortcut resistance, and mmap/evaluator auditability;
  commercially it maps to a local-first QA/audit PoC without claiming LLM
  replacement.
- Provide or connect a real external teacher-label source through the h10-j
  source-verification contract and replace h10-k/h10-l local labels with real
  source-backed feature labels that row-match external teacher-label evidence.
  The local contract, local collection harness, local distilled-rule learner,
  local learned chunk scorer, source-verified scorer binding, external ingestion
  schema, supplied CSV path, source-chain verifier, remote acquisition
  contract, content-cache verifier, fetch-attestation contract, and
  runner-owned runtime-fetcher replay contract, live-network import evidence
  gate, and import/review chain gate are now present; the next blocker is
  replacing the supplied import/review fixtures with official authority/
  registry evidence that can set `real_teacher_source_verified=1` before any
  default promotion or external benchmark comparison.
- Provide or connect real external benchmark sources/results through the
  v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at
  import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review
	  path, including public non-fixture verification, runner-owned live
	  execution/audit, independent live rerun confirmation, real nonfixture run package intake, live package artifact fetch/authority, and official result reconciliation, then replace fixture/local lower-chain rows and
	  final-review rows with
  non-local, non-fixture evidence and replace the remote-style v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at
  contract/replay/live-style/review/authority-review/registry/query/fetch/network-proof/real-verification/official-authority/result-authority/publication/acquisition/content/codebase-mini/bridge/family-bridge/reproduction/release/live-verification/canonical-confirmation/publication-result-review/live-ingestion/authority-promotion/run-evaluator/independent-run-evaluator/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-rerun/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation fixtures with
  non-fixture live registry query plus fetch/cache, network proof, real
  verification records, official authority/trust-root records, and official
  result-authority/leaderboard records plus non-fixture publication,
  source-acquisition/content packages, source-content/result bridge rows,
  independent reproduction/review, official release evidence, live release
  verification, canonical online confirmation, publication/result review,
  live-ingested publication/result records, authority/promotion evidence, real
  run/evaluator evidence for RULER, LongBench, codebase retrieval, and real
  document QA, plus live replay/final-review evidence, runner-owned live
  execution/audit, independent live rerun confirmation, live package artifact
  fetch plus authority verification, and official result reconciliation inside
  one v13-style bound nonfixture run package before any v0.8 comparison claim.
- Replace h9-h generated workload fixtures with real measured CPU/HIP/NVMe
  workload speed evidence above h9-g/h11-d, then provide a real PC RouteLM
  prototype above the h11-a/h11-b/h11-c/h11-d contracts before any NLG or
  personal-PC LLM claim.
- Re-run h7-c and v12 after those real evidence rows exist; only then can
  `promotion_review_ready` become a promotion candidate instead of a blocked
  diagnostic review, and only then can a release claim move beyond diagnostic
  artifact packaging.
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
- publishable paper/release claim
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
- `NEXT_IMPLEMENTATION_ROADMAP_v2.md` has now been reconciled against the
  repository state: its h11-c, v08-ab, h10-r, h10-s, h11-d, h9-h, h7-c, and
  paper/package phases are implemented here as diagnostic or supplied-evidence
  contracts through v12 plus v08-at, the v13-a binder manifest, the v13-b mmap
  reader, the v13-c evidence packet ABI, the v13-d NLG transcript binding, and
  the v13-e public codebase RouteQA binding, the v13-f resource envelope,
  the v13-g through v13-n real-evidence/source-acquisition gates, and the
  v14-a runner-owned query/result/evaluator execution path,
  not as real-world proof.
- the current next research boundary is official authority/registry evidence
  for h10-r plus real external teacher-label rows and source-bound student-only
  eval rows through the h10-j/h10-l/h10-r/h10-s source-verification contracts,
  not topology replacement.
- The decisive next loop is real evidence production through a bound
  nonfixture run: non-fixture teacher authority, external benchmark
  source/result/evaluator artifacts, real PC RouteLM/NLG artifact evidence, and
  measured CPU/HIP/NVMe workload traces must replace the current
  diagnostic/supplied rows before promotion.
- GPU work is backend/parity instrumentation only. CPU remains canonical until
  a complete ROCm/HIP install proves fixture parity.

## Positioning

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
