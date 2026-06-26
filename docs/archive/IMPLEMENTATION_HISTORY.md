# Implementation History Archive

This archive preserves the long-form checkpoint history that previously lived in the root READMEs. Canonical current readiness is now tracked in `readiness/typed_ready.json`; the root READMEs intentionally stay short.

## Previous English README

# discrete-local-energy

Deterministic C++17 reference code for a staged discrete local-energy research prototype.

Korean README: [README.ko.md](README.ko.md)

**Artifact boundary:** This is a machine-verifiable research artifact, not a human-reviewed release package.

## v1.0 Architecture Challenge Roadmap

The next public timing target is not a broad v0.3 claim. It is the v1.0 Architecture Challenge: RouteMemory + RouteHint versus 30B-150B-class LLM+RAG baselines on code/doc QA, grounded generation, scaling, and one-command reproducibility.

Roadmap: [docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md](docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md)

SSD-resident MoE runtime direction: [docs/V61_SSD_RESIDENT_MOE_RUNTIME.md](docs/V61_SSD_RESIDENT_MOE_RUNTIME.md). This track is not RAM offload. It stores a hundreds-B to trillions-parameter open-weight model warehouse on NVMe SSD, then uses discrete-node routing, MoE active sparsity, predictive prefetch, and mixed quantization to fit the active execution set into a local PC's VRAM/compute budget. It redirects v52s/v52u/v52v/v52w into the v61 weight-page runtime seed while keeping v52-v60 release/comparison claims separately gated.

Canonical v61 entrypoint surface:

- Full smoke list: [`pipelines/v61.yaml`](pipelines/v61.yaml)
- Per-stage claim boundary: [`v61/one_token_path.json`](v61/one_token_path.json)
- Operator/review-return contract: [`operations/review_return_workflow.json`](operations/review_return_workflow.json)
- Pipeline migration notes: [`docs/PIPELINE_MIGRATION.md`](docs/PIPELINE_MIGRATION.md)
- PR #2 review-slice plan: [`docs/PR2_SPLIT_PLAN.md`](docs/PR2_SPLIT_PLAN.md)

The current v61 evidence is summarized by contracts, not by README stage dumps. The accepted public wording is:

- v61 is an SSD-resident MoE runtime R&D track, not an SSD-resident real model runtime claim.
- Tensor-page reads, dtype/quant probes, and PyTorch matvec parity are bounded evidence only.
- Expert FFN parity, MoE block parity, one-token logits parity, 16-token decode, cold/warm cache metrics, SSD bytes/token, miss/token, TPS, actual generation, production latency, near-frontier quality, public comparison, and release readiness remain blocked until their contract artifacts pass.
- Checkpoint payloads and large generated artifacts remain outside git unless explicitly tracked by an existing artifact contract.

Use these reviewer entrypoints instead of README stage lists:

```bash
tools/verify_artifact.py pr-split pr_slices/pr2.json
tools/verify_artifact.py v61-one-token v61/one_token_path.json \
  --v61aa-summary results/v61aa_hotset_tensor_slice_verifier_summary.csv \
  --v61ab-summary results/v61ab_hotset_tensor_tile_quant_probe_summary.csv
tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json \
  --v53s-summary results/v53s_complete_source_review_return_intake_summary.csv \
  --v58d-summary results/v58d_blind_review_return_intake_summary.csv \
  --v61af-summary results/v61af_checkpoint_warehouse_operator_bundle_summary.csv \
  --v61hv-summary results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv
```

## v0.3 Architecture Preview

Run a local evidence-bound codebase audit preview:

```bash
./scripts/audit_my_repo.sh /path/to/repo --emit-report --emit-lineage --emit-reproduce
./scripts/run_local_scaling_matrix.sh /path/to/repo
```

Showcase bundle:

```bash
./examples/local_codebase_intelligence_box.sh /path/to/repo
```

Verification:

```bash
./experiments/test_v0_3_architecture_preview.sh
./experiments/test_v0_3_completion_audit.sh
```

This preview demonstrates `RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation / abstain / audit trail`. It is not a Transformer replacement, not a frontier local LLM, not a GPU-speedup proof, and not a production release.

Latest completed checkpoint:

- Branch `codex/route-memory-local-energy-policy` is current through the v0.3 Architecture Preview user-facing audit surface, v51 Real-return Evidence Intake measured workload trace, v50 Public Repo Auditor 3-repo evidence run, v49 RULER NIAH 200/500-row scale, v48 Multi-Domain RouteHint Generator evidence, v47 Offline Domain Policy Update, v46 Source-Verified Scorer mainline, v45 LongBench v2 small slice, v44 Tiny Non-Attention Generator Hint smoke, v43 Doc-Code Conflict Detection audit, v42 Codebase Auditor 200-query demo, v41 RULER NIAH 50-row scale, v40 machine-verified research artifact, v39 human review dispatch archive, v38 human review dispatch bundle, v37 human review intake verifier, v36 release-claim audit packet, v35 commercial pilot packet, v34 official benchmark expansion packet, v33 evidence-closure packet, v32 GitHub Actions third-party rerun kit, v31 official RULER NIAH candidate return, v30 commercial codebase QA closed-corpus PoC return, v29 receiver-side return preflight kit, v28 inbound return inbox, v27 external send archive, v26 external send bundle, v25 outbound send manifest, v24 external handoff send/receive/verify packet, v23 official benchmark reconciliation kit, v22 clean-machine execution kit, v21 external review dispatch kit, v20 external return tracker, v19 external submission bundle, v18 supplied external evidence intake verifier, v17 post-v16 externalization handoff, v16 research/commercial split packet, v15 independent reproduction/review mechanics, the v14 runner-owned query/result/evaluator family, v13 real-evidence/source-acquisition family, h10 source-verified scorer gates, v08-at external benchmark official result reconciliation checkpoint, h11-d PC RouteLM diagnostic NLG smoke checkpoint, h9-h diagnostic CPU/HIP/NVMe workload speed evidence gate, h7-c promotion review gate, and v12 paper/release claim audit.
- h10-j is closed as the route-memory teacher-source hash/provenance verifier. It checks teacher source artifact, label export, teacher identity, teacher policy, license, provenance, and sha256 hash-chain mechanics. Default/no-env remains blocked; a supplied external-label CSV can import labels but cannot enable distillation without source evidence; a supplied local source fixture can verify mechanics but stays `real_teacher_source_verified=0`, `distillation_ready=0`, `default_promotion=0`. Any local `file://` URI, including one outside `results/`, cannot become real teacher-source evidence by declaration flags alone.
- h10-k is closed as the latest local learned chunk-quality scorer gate. It trains a deterministic `linear-contrastive-chunk-v1` scorer from the h10-f local teacher-label harness, rewards correct chunk evidence, slashes coherent wrong/noisy/missing features, and separates reward from negative actions in the smoke (`learned_score_gap=3.064325`, `coherent_wrong_negative_rate=1.000000`). Because the labels are still `local-teacher-harness`, it keeps `external_label_source_ready=0`, `distillation_ready=0`, and `default_promotion=0`.
- h10-l is closed as the source-verified learned scorer binding gate. It requires learned chunk-quality feature labels to be supplied, non-local, teacher-ID linked to the source evidence, row-bound to external teacher-label rows via `source_uri` and `provenance_hash`, and backed by h10-j real teacher-source verification before `source_verified_learned_chunk_scorer_ready=1`. Default/local labels, relabeled local labels without row provenance, and mismatched external-label rows remain blocked (`source_verified_feature_labels_ready=0`, `source_verified_learned_chunk_scorer_ready=0`). A supplied local source fixture can link feature labels but still blocks on `real_teacher_source_verified=0`.
- h10-m is closed as the remote teacher-source acquisition contract. Default/no-env remains blocked; local `file://` source packages are classified as local-or-placeholder; HTTPS remote source packages can pass URI/hash/acquisition/review contract readiness, but h10-m alone still stops at `real_teacher_source_verified=0`.
- h10-n is closed as the remote teacher-source content verifier. It binds an HTTPS h10-m acquisition package to supplied local download/cache files and verifies all six source/export/identity/policy/license/review sha256 hashes. A matching cache package can reach `remote_teacher_source_content_ready=1`, but it still keeps `real_teacher_source_verified=0` with `remote-teacher-source-live-fetch-missing` until h10-o fetch-attestation and runtime fetcher evidence are added above it.
- h10-o is closed as the remote teacher-source live-fetch attestation contract. It checks six artifact-level fetch-attestation rows against h10-n content, requires HTTPS attestation URIs, cached attestation hashes, fetch metadata, and independent attestor flags, and can raise `remote_teacher_source_live_fetch_attestation_ready=1`; it still keeps `real_teacher_source_verified=0` with `remote-teacher-source-runtime-fetcher-missing` until a runner-owned live fetch path exists.
- h10-p is closed as the runner-owned runtime-fetcher contract. It can produce a runner-owned offline replay manifest from h10-o fetch-attestation evidence, verify fetcher binary/command/stdout/stderr hashes and downloaded cache hashes, and raise `runner_owned_runtime_fetcher_ready=1`; it still keeps `live_network_fetch_ready=0` and `real_teacher_source_verified=0` until an actual network fetch path replaces replay.
- h10-q is closed as the live-network import evidence gate. It rejects h10-p offline replay as non-network evidence, accepts a provided six-row live-network runtime evidence package up to `remote_teacher_source_live_network_import_ready=1`, and still keeps `real_teacher_source_verified=0` with `remote-teacher-source-real-source-import-missing` until a real source import/review chain is connected.
- h10-r is closed as the real teacher-source import/review chain gate. It consumes h10-q live-network import readiness plus a supplied import/review CSV, requires source/export/identity/policy/license/import-manifest/review/reviewer/conflict/registry HTTPS URI fields, sha256 hash fields, live-import observation, independent/authoritative review flags, registry readiness, real/non-fixture declarations, and zero routing/jump activity. Local `file://` review artifacts block as `real-teacher-source-local-import-artifact`; placeholder authorities block as `real-teacher-source-placeholder-import-artifact`; a non-placeholder review chain can reach `real_teacher_source_import_review_ready=1` but still keeps `real_teacher_source_verified=0` with `real-teacher-source-official-authority-missing`.
- h10-s is closed as the source-verified learned chunk scorer evaluation gate. It consumes h10-l source-verified scorer binding, h10-r import/review readiness, and an optional `V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV` student-only evaluation table. Default/no-env stays blocked at `source-verified-feature-labels-missing`; a supplied source-linked fixture can show `student_only_eval_ready=1`, positive `chunk_exact_delta`, `near_miss_negative_rate=1.000000`, and `metric_improvement_ready=1`, but still keeps `source_verified_learned_chunk_scorer_eval_ready=0` because h10-l/h10-r do not yet have official real teacher-source authority.
- The h10 PM real-label promotion readiness gate is closed as a blocker ledger, not as promotion. It binds h10-s to v53q complete-source symmetric scorer/provenance rows, v53ap A/B/G/H same-query deterministic source-span adapter rows, v53aq sanitized-question-only real-adapter evidence, the v53aq 1000-row same-query internal prebaseline ledger, and v54c grounded-generation guard rows. The ledger now cites v53aq wrong-key/provenance evidence directly: 4000 adapter-trace rows, 4000 evaluator rows, 1000 same-query prebaseline rows, 3916 coherent wrong-key rows overall, and A/B/G/H each with 979 coherent wrong-key rows under scorer/policy traces. It also emits a six-row `h10_real_label_return_contract_rows.csv` that maps coherent wrong-key, chunk exact, near-miss, missing-query abstain, source provenance, and external/human-label criteria to no-fixture approval-required return columns. It keeps `h10_real_label_promotion_ready=0` until accepted external/human label evidence and h10 source-verified eval readiness exist together.
- h7 route-memory closure is current through h7-c. The closure still keeps `default_promotion=0`, `status=diagnostic-only`, `routing_trigger_rate=0`, and `active_jump_rate=0`. The positive chunk-credit and learned scorer results are therefore guarded diagnostic route-memory policies, not default sparse-routing policies.
- v08-aa is closed as the external-benchmark source-acquisition/content boundary. v08-m through v08-w carry source-import from contract, live verifier/review, authoritative review, public registry, live registry query, fetch/cache, live-registry network proof, real verification, and official source authority; v08-x adds the result/leaderboard authority layer; v08-y adds the publication-package layer; v08-z separately requires official benchmark source acquisition packages for RULER, LongBench, codebase retrieval, and real document QA; and v08-aa binds those acquisition URI/hash manifests to supplied source landing, dataset, benchmark-card, split-manifest, license, and metric-spec cache files. Matching cache content can reach `external_benchmark_source_acquisition_content_ready=1`, but still keeps `real_external_benchmark_verified=0` until source import/result/review/publication evidence is connected.
- v08-ab is closed as the first codebase-mini benchmark instrumentation layer over real local repository files. It generates a `codebase-retrieval` artifact package with `source_manifest.json`, `dataset.jsonl`, split/license/metric specs, BM25/symbolic/RouteMemory baselines, result artifacts, and `sha256sums.txt`, then binds it to the h11-c RouteMemory store. The smoke verifies eight local source files, seven query rows, ten artifact hashes, `span_exact=1.000000`, `chunk_exact=1.000000`, `missing_abstain=1.000000`, `wrong_answer_rate=0.000000`, `routing_trigger_rate=0`, and `active_jump_rate=0`, while still keeping `real_external_benchmark_verified=0` because local codebase instrumentation is not an independent external benchmark review/publication chain.
- v08-ac is closed as the first source-content to result-artifact bridge for the codebase-retrieval slice. A supplied bridge can bind v08-aa source acquisition/content rows to the v08-ab codebase-mini artifact directory, verify five result/baseline/dataset/run/evaluator hashes, and reach `codebase_content_result_bridge_ready=1` with route/jump activity at zero. It still keeps `external_benchmark_result_bridge_ready=0` and `real_external_benchmark_verified=0` because only one of four benchmark families is covered and the codebase artifacts are local.
- v08-ad is closed as the all-family external benchmark result bridge contract. Supplied non-local bridge rows for RULER, LongBench, codebase-retrieval, and real-document-qa bind back to v08-aa source-content acquisition IDs, verify the source-content summary hash, require 28 sha256-attested HTTPS result/baseline/dataset/run/evaluator/result-authority/publication URI fields, and can raise `family_result_bridge_review_ready=1` plus `external_benchmark_result_bridge_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because the current rows are supplied mechanics, not independent reproduction or publishable official benchmark evidence.
- v08-ae is closed as the independent reproduction/review contract above v08-ad. Supplied non-local reproduction rows for all four benchmark families bind back to the v08-ad result bridge, verify result artifact and bridge-summary hashes, require 28 sha256-attested HTTPS reproduction/report/run-log/reviewer/conflict/environment/metric fields, and can raise `independent_reproduction_review_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because the current reproduction rows are supplied review mechanics, not official release evidence or externally verifiable benchmark publication.
- v08-af is closed as the official release evidence contract above v08-ae. Supplied release rows for all four benchmark families bind back to the independent reproduction IDs and v08-ae summary hash, require 44 sha256-attested release/reproduction hash fields plus 40 HTTPS release package/manifest/archive/version/license/reproducibility/review/index/authority URI fields, and can raise `official_release_evidence_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because these are supplied release mechanics, not live externally verified release/publication records.
- v08-ag is closed as the live release verification contract above v08-af. Supplied live-verification rows for all four benchmark families bind back to the v08-af release IDs, reproduction IDs, and official release/archive/dataset/authority URI+hash pairs, require 28 sha256-attested HTTPS live verification/report/network-observation/verifier fields, and can raise `official_release_live_verification_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because these are supplied live-verification mechanics, not canonical online confirmation from the runner.
- v08-ah is closed as the canonical online confirmation contract above v08-ag. Supplied confirmation rows for all four benchmark families bind back to the v08-ag live verification reports, network observations, verifier identities, release IDs, and reproduction IDs; require 36 sha256-attested HTTPS live/canonical confirmation, runner-network transcript, TLS, DNS, HTTP-header, and content-digest artifact fields; and can raise `canonical_online_confirmation_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because these are supplied confirmation mechanics, not non-fixture publication/result review records.
- v08-ai is closed as the publication/result review contract above v08-ah. Supplied review rows for all four benchmark families bind back to v08-ah canonical confirmation reports, content-digest manifests, release IDs, and reproduction IDs; require 36 sha256-attested HTTPS review/result/publication/authority fields; require the 28 newly introduced review artifact URIs to be non-placeholder HTTPS; and can raise `publication_result_review_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because these are supplied review mechanics, not live-ingested non-fixture result/publication records or promotion evidence.
- v08-aj is closed as the live publication/result ingestion contract above v08-ai. Supplied ingestion rows for all four benchmark families bind back to v08-ai publication/result review and record URI/hash pairs; require 56 sha256-attested HTTPS ingestion/review URI fields, 40 newly introduced non-placeholder live-ingestion artifact URIs including response-header, content-digest, and TLS certificate-chain records; require runner-owned live-network ingestion and digest-match declarations; and can raise `live_publication_result_ingestion_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because these are supplied ingestion mechanics, not actual non-fixture benchmark publication/result authority evidence or promotion evidence.
- v08-ak is closed as the authority/promotion evidence contract above v08-aj. Supplied authority rows for all four benchmark families bind back to v08-aj live publication/result records and content digests; require 56 sha256-attested HTTPS authority/ingestion URI fields, 40 newly introduced non-placeholder authority artifact URIs including registry, leaderboard, reproducibility package, archive, identity, conflict, promotion trace, and final claim packet records; require independent/official/registry/consistency/limited-claim declarations; and can raise `authority_promotion_evidence_ready=1` with route/jump activity at zero. It still keeps `real_external_benchmark_verified=0` because this is authority/promotion evidence mechanics, not actual independently observed external benchmark run evidence.
- v08-al is closed as the first run/evaluator trace layer above v08-ak and v08-ab. It recomputes the local `codebase-retrieval` dataset/result join from the codebase-mini artifacts, writes runner/evaluator manifests, query trace, evaluator output, recomputed metrics, command receipt, and sha256 manifest, verifies six trace artifact hashes, seven matched query rows, five metric matches, and route/jump zero. This can raise `codebase_run_evaluator_trace_ready=1`, but keeps `external_benchmark_run_evaluator_trace_ready=0` and `real_external_benchmark_verified=0` because coverage is still only one local family with no independent all-family evaluator evidence.
- v08-am is closed as the independent all-family run/evaluator evidence contract above v08-al. Supplied evidence rows for RULER, LongBench, codebase-retrieval, and real-document-qa must provide non-placeholder HTTPS trace/run/evaluator/metric/query/observer/authority artifacts, sha256 hashes, minimum query volume, quality thresholds, proof bindings, independent evaluator declarations, and route/jump zero. The supplied mechanics can raise `external_benchmark_independent_run_evaluator_evidence_ready=1`, but still keep `real_external_benchmark_verified=0` until live replay/final review replaces supplied evidence.
- v08-an is closed as the live replay/final-review contract above v08-am. Supplied review rows for RULER, LongBench, codebase-retrieval, and real-document-qa must bind v08-am evidence to replay/final-review artifact URI/hash pairs, replay query volume, metric thresholds, live replay declarations, independent final-review declarations, fixture declarations, and route/jump zero. The supplied mechanics can raise `external_benchmark_live_replay_final_review_ready=1`, but still keep `real_external_benchmark_verified=0` until public non-fixture verification or direct runner-owned external runs prove it.
- v08-ao is closed as the public non-fixture/direct-run verification contract above v08-an. Supplied verification rows for the same four benchmark families bind v08-an review evidence to 40 non-placeholder HTTPS public/direct-run artifact URIs, 40 sha256 hashes, query volume, metric thresholds, public registry/non-fixture declarations, direct runner-owned run/dataset/evaluator/network declarations, third-party reviewer declarations, fixture declarations, and route/jump zero. This can raise `external_benchmark_public_nonfixture_verification_ready=1`, but keeps `real_external_benchmark_verified=0` until runner-owned live execution/audit proves the receipts rather than supplied mechanics.
- v08-ap is closed as the runner-owned live execution/audit contract above v08-ao. Supplied audit rows for all four benchmark families bind v08-ao verification evidence to 52 non-placeholder HTTPS live execution/audit artifact URIs, 52 sha256 hashes, query volume, metric thresholds, runner-owned execution declarations, live network/dataset fetch declarations, runner-invoked evaluator declarations, replay-disabled declarations, audit log and third-party audit declarations, fixture declarations, and route/jump zero. This can raise `external_benchmark_runner_owned_live_execution_audit_ready=1`, but keeps `real_external_benchmark_verified=0` until independent live rerun confirmation proves the runner-owned audit receipts.
- v08-aq is closed as the independent live rerun confirmation contract above v08-ap. Supplied confirmation rows for all four benchmark families bind v08-ap audit evidence to 60 non-placeholder HTTPS rerun-confirmation artifact URIs, 60 sha256 hashes, rerun query volume, metric thresholds, metric-delta bounds, independent runner/environment declarations, live network/dataset refetch/evaluator rerun declarations, audit receipt reconciliation, metric recomputation, third-party confirmation declarations, fixture declarations, and route/jump zero. This can raise `external_benchmark_independent_live_rerun_confirmation_ready=1`, but keeps `real_external_benchmark_verified=0` until a real non-fixture benchmark run package replaces the supplied confirmation mechanics.
- v08-ar is closed as the real nonfixture run package intake contract above v08-aq. Supplied package rows for all four benchmark families bind v08-aq confirmation evidence to 60 non-placeholder HTTPS run-package artifact URIs, 60 sha256 hashes, packaged query volume, metric thresholds, metric-delta bounds, nonfixture/official benchmark/public archive/raw query/raw output/evaluator container/immutable archive declarations, license/PII/third-party reproducibility reviews, fixture declarations, and route/jump zero. This can raise `external_benchmark_real_nonfixture_run_package_intake_ready=1`, but v08-ar alone still keeps `real_external_benchmark_verified=0`; v08-as now carries the supplied live fetch/authority mechanics above it.
- v08-as is closed as the live package artifact fetch/authority verification contract above v08-ar. Supplied fetch rows bind all 60 family/artifact entries to fetched artifact, fetch receipt, and authority record URI/hash pairs, requiring 180 non-placeholder HTTPS URI fields, 180 sha256 hashes, HTTP-200 checks, content-digest matches, v08-ar package-intake binding, runner-owned live fetch, network/TLS/DNS/HTTP declarations, authority registry/official source authority declarations, fixture declarations, and route/jump zero. This can raise `external_benchmark_live_package_artifact_fetch_authority_ready=1`, but keeps `real_external_benchmark_verified=0` until official result reconciliation replaces supplied fetch/authority mechanics.
- v08-at is closed as the official result reconciliation contract above v08-as. Supplied reconciliation rows bind all four benchmark families to the v08-as fetched official leaderboard, metric report, submission receipt, evaluator config, raw prediction output, and package-registry artifacts by exact URI/hash identity; require 28 non-placeholder HTTPS URI fields, 28 sha256 hashes, package identity matches, metric-delta tolerance checks, query-count matches, evaluator/digest/official-source/leaderboard/runner declarations, fixture declarations, and route/jump zero. This can raise `external_benchmark_official_result_reconciliation_ready=1`, but keeps `real_external_benchmark_verified=0`; the next boundary is a real-run binder/nonfixture runner path, not another v08 layer.
- v13-a is closed as the first real-run binder manifest. It creates or verifies one hash-manifested run directory that bundles h11-c store artifacts, h11-d NLG transcript/result, h9-h workload rows, v08-al run/evaluator traces, h10-s scorer/teacher evidence, and v12 claim-audit input under `results/v13_real_run_binder_manifest*_runs/<run_id>/`. The smoke reaches `real_run_binder_manifest_ready=1` for generated diagnostic inputs and proves corrupted run manifests block, while keeping `actual_nonfixture_run_verified=0`, `real_pc_routelm_nlg_verified=0`, `real_external_benchmark_verified=0`, `real_workload_speed_evidence_ready=0`, `real_release_package_ready=0`, and `gpu_speedup_claim=deferred`.
- v13-b is closed as the RouteLM mmap reader boundary. It opens the v13 run directory's `store/chunk_pages.bin` with an mmap reader, checks `route_index -> page_table -> byte span` windows, matches route keys and chunk offsets, verifies both run-level and store-level sha256 manifests, and proves hash-clean semantic span corruption blocks. The smoke reaches `routelm_mmap_reader_ready=1` on generated diagnostic input while keeping actual nonfixture, real PC RouteLM artifact, real external benchmark, and real release flags at `0`.
- v13-c is closed as the evidence packet ABI. It normalizes the bound run manifest, store files, mmap reader summary, NLG transcript/result, workload row, benchmark trace/evaluator outputs, h10-s scorer evidence, and v12 input into `evidence_packet.csv` plus `claim_matrix_input.csv`, with packet hashes and claim-source references verified. The smoke reaches `evidence_packet_abi_ready=1`, keeps learned chunk ranking blocked, and keeps actual nonfixture, real PC RouteLM artifact/NLG, real external benchmark, real speed, real release, and GPU speedup claims at `0` or `deferred`.
- v13-d is closed as the real NLG transcript binding boundary. It parses `nlg/transcript.jsonl`, checks `nlg/result_summary.json`, replays each transcript row against `store/route_index.bin` and the mmap-readable `store/chunk_pages.bin` span bytes, and writes a hash-manifested `transcript_binding.csv`. The smoke reaches `v13_real_nlg_transcript_ready=1`, blocks hash-clean wrong grounding, and still keeps `real_nlg_transcript_ready=0`, `real_pc_routelm_nlg_verified=0`, real external/release flags at `0`.
- v13-e is closed as the public codebase RouteQA binding boundary. It follows the v13 run's benchmark runner manifest into the local codebase-mini package, verifies trace/package/source hashes, joins seven dataset/result/query/evaluator rows, recomputes metrics, emits `routeqa_rows.csv`, and blocks hash-clean evaluator lies. The smoke reaches `public_codebase_routeqa_ready=1`, while `independent_external_routeqa_verified=0`, `real_external_benchmark_verified=0`, and real release flags remain `0` because this is local codebase instrumentation, not an independent external benchmark.
- v13-f is closed as the resource envelope boundary. It binds `speed/workload.csv` to the v13 run, verifies the workload's NLG/timing/environment artifact hashes, confirms the run NLG result hash matches the workload row, emits `resource_rows.csv`, and blocks hash-clean speedup removal. The smoke reaches `resource_envelope_ready=1`, but `real_workload_speed_evidence_ready=0`, `gpu_speedup_claim=deferred`, and release flags remain blocked until real HIP/NVMe/nonfixture trace evidence exists.
- v13-g is closed as the real evidence promotion gate. It consumes the v13-c/v13-d/v13-e/v13-f bindings plus h10-s, h11-d, h9-h, and v08 run evidence, emits `promotion_rows.csv` for the four named weaknesses, and keeps `real_evidence_promotion_ready=0`, `real_release_package_ready=0` until real external benchmark, source-verified learned scorer, real NLG, real GPU speed, and nonfixture run evidence all bind to the same run.
- v13-h is closed as the same-run real evidence intake gate. It validates a four-row intake package for external benchmark, learned chunk ranking, GPU speedup, and real NLG evidence against the v13-g promotion packet, checks run-id binding, cache hashes, HTTPS source/review/authority URIs, contract flags, and route/jump zero, and keeps `candidate_real_evidence_intake_ready=0`, `real_release_package_ready=0` until live-network verification and regenerated bound-run evidence exist.
- v13-i is closed as the real evidence live-network gate. It consumes v13-h intake evidence plus source/review/authority network receipts, verifies receipt hashes, HTTPS final URIs, HTTP status rows, live-network declarations, and route/jump zero, and keeps `candidate_real_evidence_live_network_ready=0`, `real_release_package_ready=0` unless receipts come from runner-owned runtime live fetches and the bound v13 run is regenerated.
- v13-j is closed as the real evidence rebind gate. It consumes v13-i receipt evidence plus same-run replacement artifacts, verifies receipt-hash replay, rebuilt artifact hashes, claim-matrix hashes, regeneration flags, and route/jump zero, and keeps `candidate_real_evidence_rebind_ready=0`, `real_release_package_ready=0` until runtime live fetch evidence and regenerated promotion rows are present.
- v13-k is closed as the runtime fetch provenance gate. It reopens the v13-i receipt JSONs above v13-j, verifies runtime receipt scope/weakness/kind binding, HTTPS original/final URIs, HTTP status, method, headers, empty error, ordered UTC timestamps, receipt hashes, and route/jump zero, and keeps `runtime_fetch_provenance_ready=0`, `candidate_real_evidence_runtime_ready=0`, and `real_release_package_ready=0` unless the receipts actually come from `runtime-live-fetch`.
- v13-l is closed as the source seed gate. It separates current public source seeds from real claim evidence: the external benchmark row can bind current RULER/LongBench public sources, while learned chunk ranking, GPU speedup, and real NLG remain `project-source-only`; `source_seed_contract_ready=1` can pass, but `candidate_real_evidence_source_seed_ready=0` and release remain blocked until all four rows have official/independent claim evidence plus runtime live fetch receipts.
- v13-m is closed as the source seed live-fetch gate. It consumes the v13-l seed packet and optional runner-owned live receipts, verifies seed packet hashes, receipt file coverage, receipt JSON scope/weakness/kind binding, HTTPS final URIs, HTTP status, methods, headers, empty errors, ordered UTC timestamps, and route/jump zero, but keeps `source_seed_live_fetch_receipt_ready=0`, `candidate_real_evidence_source_live_fetch_ready=0`, and release blocked unless all source/review/authority receipts for all four weakness rows are present and the underlying claim evidence is real.
- v13-n is closed as the external benchmark official source acquisition gate. It consumes v13-m/v13-l source seeds and optionally runs runner-owned acquisition against RULER, LongBench, and the RULER arXiv authority; live full mode can reach `external_benchmark_official_source_acquisition_ready=1` with two repo HEAD receipts and one HTTP authority receipt, but keeps `candidate_external_benchmark_result_ready=0` and `real_release_package_ready=0` until actual benchmark queries/results/evaluator evidence exist.
- v14-a is the first runner-owned query/result/evaluator execution path rather than another evidence gate. `tools/routelm_benchmark_run` materializes `public-codebase-routeqa-v1` queries, copies the v13 source-chain rows into `source/`, can autodiscover sibling `source_seed_live_fetch_rows.csv` and `runtime_fetch_provenance_rows.csv` when only `--source-acquisition` is supplied, can bind or live-fetch official repo HEAD source snapshots into `source/source_snapshot_rows.csv`, can use a fetched source snapshot as the actual query repo via `--repo-from-source-snapshot`, builds an mmap RouteMemory store with `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, and `store_manifest.csv`, hash-binds query materialization in `dataset/dataset_manifest.json`, emits raw predictions plus `predictions/prediction_status.json`, invokes the local evaluator plus `evaluator/evaluator_status.json`, writes `metrics.json`, `routeqa_rows.csv`, `benchmark/benchmark_rows.csv`, `evidence_packet.csv`, `evidence/run_invocation.json`, `evidence/requested_outputs_manifest.json`, `evidence/run_layout_manifest.json`, `evidence/objective_requirements_manifest.json`, source-chain CSV mirrors under `evidence/`, `evidence/execution_chain_manifest.json`, `promotion_rows.csv`, and a run-level `sha256sums.txt` hash manifest under `results/v14_real_query_result_evaluator_runner*_runs/`. The focused smoke covers both built-in and supplied `--queries`; a direct CLI smoke proves source-chain sibling autodiscovery with `source_seed_live_fetch_autodiscovered=1`, `runtime_fetch_provenance_autodiscovered=1`, and `source_chain_autodiscovery_ready=1`; the live snapshot test checks out the v13-n RULER HEAD and runs three RouteQA rows against that official snapshot with `repo_source=runner-owned-source-snapshot`. With `--emit-ruler-synthetic-smoke`, it also writes RULER-compatible NIAH dataset/prediction/evaluator artifacts under `benchmark/ruler_synthetic/`, invokes the official RULER evaluator script, invokes official RULER `scripts/data/prepare.py` for three official NIAH tasks (`niah_single_1`, `niah_multikey_2`, `niah_multikey_3`) and nine generated rows, creates prediction rows by extracting target needles from generated `input` text rather than copying `outputs`, feeds those predictions through `scripts/eval/evaluate.py`, writes `benchmark/ruler_synthetic/official_generator_store/` with `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, and `mmap_read_rows.csv` for mmap verification of the generated inputs, and records `official_generator_benchmark_rows.csv`, `official_generator_metrics.json`, and `official_generator_prediction_provenance.csv` with dataset/prediction/evaluator/metrics/provenance/mmap bindings. With `--emit-longbench-v2-smoke`, it also uses the live `longbench_repo` snapshot, writes six LongBench v2 multiple-choice schema rows, invokes official `result.py`, and records `longbench_v2_benchmark_rows.csv`, `longbench_v2_metrics.json`, and `longbench_v2_manifest.json`; with `--emit-longbench-v2-official-sample`, it fetches 12 canonical LongBench v2 dataset-server rows, evaluates a non-oracle lexical baseline through the same official aggregator, and writes `benchmark/longbench_v2/official_sample_store/` with `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, and `mmap_read_rows.csv` for mmap verification of the official sample rows and baseline predictions. These official-source rows are normalized into run-level `benchmark/external_benchmark_rows.csv`, aggregated into `benchmark/external_benchmark_metrics.json`, hash-bound in `benchmark/external_benchmark_manifest.json`, and row-bound in `benchmark/external_benchmark_execution_chain_manifest.json` from source acquisition through dataset, prediction, evaluator, metrics, provenance, and mmap artifacts; the live smoke reaches `external_benchmark_rows=5`, `external_benchmark_dataset_rows=27`, `external_benchmark_mmap_read_rows=21`, `external_benchmark_mmap_prediction_match_rows=21`, `external_benchmark_mmap_verification_ready_rows=4`, `external_benchmark_execution_chain_ready_rows=5`, `external_benchmark_execution_chain_ready=1`, `external_benchmark_average_score=66.67`, `external_benchmark_metrics_ready=1`, `external_benchmark_manifest_ready=1`, and `runner_owned_external_benchmark_result_ready=1`, `prediction_status_ready=1`, `evaluator_status_ready=1`, `requested_outputs_manifest_ready=1`, `requested_outputs_ready=1`, `run_layout_manifest_ready=1`, `run_layout_ready=1`, `objective_requirements_manifest_ready=1`, `objective_requirements_ready=1`, `source_chain_evidence_mirror_ready=1`, `source_chain_autodiscovery_ready=1`, `execution_chain_manifest_ready=1`, and `run_invocation_ready=1`, `official_ruler_generator_mmap_verification_ready=1`, `official_ruler_generator_mmap_read_rows=9`, `longbench_v2_official_sample_mmap_verification_ready=1`, `longbench_v2_official_sample_mmap_read_rows=12`, `evidence_packet_rows=50` while still keeping `candidate_external_benchmark_result_ready=0`. Because this environment lacks `nltk`, `wonderwords`, `tiktoken`, and NeMo manifest utilities, v14-a supplies run-local dependency shims, runs RULER `prepare.py` from a space-free `/tmp` symlink workspace for compatibility with its internal shell command, and records that in `official_evaluator_status.json` / `official_generator_status.json`; the official generated smoke reaches `official_ruler_generator_ready=1`, `official_ruler_generator_evaluator_ready=1`, `official_ruler_generator_benchmark_ready=1`, `oracle_prediction_used=0`, `extracted_prediction_rows=9`, and average score `77.78` across three official NIAH task rows, while LongBench v2 aggregation reaches `longbench_v2_score=100.00` for the six-row schema smoke and `longbench_v2_official_sample_rows=12`, `longbench_v2_official_sample_score=0.00`, `longbench_v2_official_sample_mmap_prediction_match_rows=12` for the official dataset-server baseline sample. `real_external_benchmark_verified=0` and release still stay blocked because this is runner-owned smoke evidence with run-local shims/synthetic rows, not an independent RULER/LongBench benchmark result.
- v14-a also provides a repo-level `routelm_benchmark_run` wrapper and writes `evidence/reproducibility_manifest.json`, which records a shell-quoted direct runner command plus hashes for the runner, source-acquisition CSV, query file, and autodiscovered source-chain CSVs. `evidence/run_layout_manifest.json` separately verifies the concrete output tree from `source/` through dataset, mmap store, predictions, evaluator, metrics, benchmark, evidence, resource, and promotion artifacts; `evidence/objective_requirements_manifest.json` audits the objective path stage by stage from official source acquisition through promotion rows, and `evidence/official_source_acquisition_rows.csv` mirrors the canonical source CSV so the documented direct command shape works. The direct canonical-query smoke invokes bare `routelm_benchmark_run` through `PATH` and verifies `reproducibility_manifest_ready=1`, `direct_cli_shape_ready=1`, `source_chain_autodiscovery_ready=1`, `requested_outputs_ready=1`, `run_layout_ready=1`, and `objective_requirements_ready=1`.
- v14-b-lite is implemented as the local prediction-lineage proof over v14-a. `tools/routelm_benchmark_run` can emit `predictions/prediction_lineage.jsonl`, `predictions/prediction_source_summary.json`, mmap/candidate traces, RouteMemory prediction evidence rows, a 50-row RouteQA-mini lightweight benchmark, Stage 8.2-L shortcut/corruption negative rows, tiny generator-hint NLG rows under `nlg/` plus grounding evidence, and a CPU-canonical RX 6900XT/32GB/500GB-lite resource envelope. `experiments/test_v14b_lite_prediction_lineage.sh` verifies `prediction_lineage_ready=1`, `no_extractor_prediction_ready=1`, `promoted_prediction_rows == promoted_route_memory_prediction_rows`, `shortcut_negative_suite_ready=1`, `generator_hint_nlg_ready=1`, `resource_envelope_ready=1`, and keeps real external benchmark/release flags blocked.
- v14-c is implemented as the baseline-comparison boundary above v14-b-lite. `experiments/test_v14c_baseline_comparison.sh` compares input extractor, BM25/lexical retrieval, RouteMemory retrieval-only, RouteMemory exact value read, RouteMemory plus proposal hint, and tiny generator-hint NLG on the same 50-row package plus shortcut negatives. It emits `benchmark/baseline_comparison_rows.csv`, `benchmark/baseline_negative_case_rows.csv`, `metrics/baseline_comparison_metrics.json`, `resource/baseline_latency_rows.csv`, and `promotion/baseline_promotion_guard_rows.csv`, verifies `route_memory_safety_dominates_baselines=1`, `input_extractor_baseline_only=1`, and keeps external benchmark/release flags blocked.
- v14-d is implemented as the RouteQA-mini 100/150 row scale boundary above v14-c. `experiments/test_v14d_routeqa_mini_scale.sh` runs `experiments/run_v14d_routeqa_mini_scale.sh` for both target sizes, verifies exact dataset/query/lineage/NLG row counts, keeps the v14-b/v14-c negative-suite, baseline-comparison, resource-envelope, run-layout, objective, and execution-chain contracts green, hash-checks the scale artifacts through each run manifest, and keeps candidate external benchmark plus release flags blocked.
- v14-e is implemented as the RULER NIAH-lite runner-owned smoke above v14-d. `experiments/test_v14e_ruler_niah_lite.sh` emits a RULER-compatible NIAH row, derives its prediction through a RouteMemory mmap store under `benchmark/ruler_synthetic/compatible_niah_store/`, writes compatible benchmark/metrics/provenance rows, normalizes one runner-owned external benchmark row with execution-chain binding, and keeps candidate external benchmark, real external benchmark, and release flags blocked.
- v15-a is implemented as the independent reproduction mechanics package above v14-b/v14-c/v14-d/v14-e. `experiments/test_v15a_independent_reproduction_package.sh` regenerates the v14 boundary outputs, builds `results/v15a_independent_reproduction_package/package_001/` with `REPRODUCE.sh`, expected summary/decision CSVs, frozen query sets, source snapshot rows/manifests, resource envelopes, run sha256 manifests, an artifact manifest, environment manifest, failure modes, and non-claim notes, and keeps candidate external benchmark plus release flags blocked.
- v15-b is implemented as the nonfixture review / independent rerun evidence mechanics above v15-a. `experiments/test_v15b_nonfixture_review_independent_rerun.sh` binds the v15-a package hash, reviewer identity, rerun environment, reproduced command stdout/stderr hashes, expected-vs-rerun summary copies, metric delta rows, and pass/fail review rows under `results/v15b_nonfixture_review_independent_rerun/review_001/`. This is still a runner-owned local review package, so external independent reviewer, candidate external benchmark, real external benchmark, and release flags remain blocked.
- v16 is implemented as the split research/commercial track packet above v15-b. `experiments/test_v16_research_commercial_tracks.sh` builds `results/v16_research_commercial_tracks/packet_001/` with a research publication packet, research evidence matrix, claim boundary matrix, commercial local QA/audit prototype contract, commercial acceptance rows, artifact manifest, and v16 manifest. It marks the research publication track and commercial local QA/audit prototype contract ready while keeping candidate external benchmark, real external benchmark, and release flags blocked.
- v17 is implemented as the post-v16 externalization handoff. `experiments/test_v17_post_v16_externalization_handoff.sh` builds `results/v17_post_v16_externalization_handoff/package_001/` and separates three intake tracks: third-party rerun, official benchmark reconciliation, and commercial closed-corpus local QA/audit PoC. It prepares commands, schemas, required artifact rows, and acceptance criteria while keeping `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, and release flags blocked until real external artifacts are supplied.
- v18 is implemented as the supplied external evidence intake verifier above v17. `experiments/test_v18_external_evidence_intake.sh` proves the default no-evidence path keeps all actual/candidate flags blocked, while `experiments/test_v18_external_evidence_intake_with_fixtures.sh` proves the verifier can accept a synthetic supplied-evidence fixture and raise the corresponding intake flags. Real readiness still requires non-fixture directories supplied through `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and/or `V18_COMMERCIAL_POC_DIR`.
- v19 is implemented as the external submission bundle above v18. `experiments/test_v19_external_submission_bundle.sh` builds `results/v19_external_submission_bundle/bundle_001/` with third-party rerun, official benchmark reconciliation, and commercial local evidence-bound QA/audit submission packets, v18 intake commands, track rows, artifact hashes, and the post-v18 roadmap in `docs/POST_V18_RESEARCH_ROADMAP.md`. It marks only submission readiness while keeping `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, `real_external_benchmark_verified=0`, and `real_release_package_ready=0`.
- v20 is implemented as the external return tracker above v19/v18. `experiments/test_v20_external_return_tracker.sh` builds `results/v20_external_return_tracker/tracker_001/` with per-track required return files, blocker rows, next actions, a tracker manifest, and artifact hashes. It can pass returned directories through `V20_THIRD_PARTY_RERUN_DIR`, `V20_OFFICIAL_BENCHMARK_DIR`, and `V20_COMMERCIAL_POC_DIR` into the v18 verifier, but the default no-return path intentionally keeps the actual rerun, candidate benchmark, commercial PoC, real benchmark, and release flags blocked.
- v21 is implemented as the external review dispatch kit above v20. `experiments/test_v21_external_review_dispatch_kit.sh` builds `results/v21_external_review_dispatch_kit/dispatch_001/` with reviewer-facing requests, a packet index, return directory layout, copied return templates, verification commands, tracker summary, source manifests, and artifact hashes. It makes the three-track handoff portable for external reviewers while still keeping actual rerun, candidate benchmark, commercial PoC, real benchmark, and release flags blocked until non-fixture return directories are supplied.
- v22 is implemented as the clean-machine execution kit above v21. `experiments/test_v22_clean_machine_execution_kit.sh` builds `results/v22_clean_machine_execution_kit/kit_001/` with host/container clean-machine runbooks, a minimal Containerfile, a third-party rerun capture script, reviewer/environment templates, official benchmark and commercial PoC execution notes, verification notes, source manifests, and artifact hashes. The capture script auto-populates v15-b metric delta rows and review rows after a successful rerun and now records a bounded `CAPTURE_TIMEOUT_SECONDS` window plus start/finish diagnostics for hosted clean-machine runs. Reviewer identity and clean-machine independence remain the external fields. It improves the real third-party rerun path but still keeps actual/candidate/release flags blocked until returned non-fixture evidence is verified by v20/v18.
- v23 is implemented as the official benchmark reconciliation kit above v22. `experiments/test_v23_official_benchmark_reconciliation_kit.sh` builds `results/v23_official_benchmark_reconciliation_kit/kit_001/` with an official-slice runbook, return directory layout, evaluator/container contract, no-oracle/no-raw-input-extractor contract, raw prediction and RouteMemory lineage templates, metrics/provenance/reproducibility templates, a return-file preflight script, v20 verification notes, source manifests, and artifact hashes. It improves the candidate external benchmark path while keeping candidate/real/release flags blocked until returned official evidence is verified.
- v24 is implemented as the external handoff send/receive/verify packet above v21/v22/v18. `experiments/test_v24_external_handoff_send_receive_verify.sh` builds `results/v24_external_handoff_send_receive_verify/handoff_001/` with the exact send packet (`v21` dispatch kit plus `v22` clean-machine kit), return inbox expectations, direct `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR` verification commands, handoff rows, blockers, source manifests, and artifact hashes. It is the current operational packet for sending out and receiving back evidence while keeping actual flags blocked until a real return directory is supplied.
- v25 is implemented as the outbound send manifest above v24. `experiments/test_v25_outbound_send_manifest.sh` builds `results/v25_outbound_send_manifest/packet_001/` with a complete sha256 manifest for the outbound `v21` dispatch kit and `v22` clean-machine execution kit, receiver acknowledgement template, return options, direct v18 verification instructions, source manifests, and artifact hashes. It verifies the send packet's integrity while keeping actual/candidate/release flags blocked until a real return directory is supplied.
- v26 is implemented as the single external send bundle above v25. `experiments/test_v26_external_send_bundle.sh` builds `results/v26_external_send_bundle/bundle_001/`, copies the outbound v21 dispatch-kit and v22 clean-machine-kit files into one send directory, writes bundle sha256 manifests, receiver integrity-check instructions, direct v18 return verification notes, source manifests, and artifact hashes. It is the single directory to send outward while actual/candidate/release flags remain blocked until a real return directory is supplied.
- v27 is implemented as the external send archive above v26. `experiments/test_v27_external_send_archive.sh` builds `results/v27_external_send_archive/archive_001/`, packages the v26 send bundle as `archive/v26_external_send_bundle_bundle_001.tar.gz`, writes archive sha256 sums, archive file listing, receiver archive/return verification notes, source manifests, and artifact hashes. It is a transfer-friendly archive for the outbound packet while actual/candidate/release flags remain blocked until a real return directory is supplied and verified by v18.
- v28 is implemented as the inbound return inbox above v27/v18. `experiments/test_v28_inbound_return_inbox.sh` builds `results/v28_inbound_return_inbox/inbox_001/` with standard return locations for third-party rerun, official benchmark, and commercial PoC directories, an inbox manifest, v18 summary mirrors, and a verifier hook. Empty placeholder directories are not passed to v18 as supplied evidence; actual/candidate/release flags stay blocked until returned files are placed in the inbox and pass v18 verification.
- v29 is implemented as the receiver-side return preflight kit above v28. `experiments/test_v29_receiver_return_preflight.sh` builds `results/v29_receiver_return_preflight/preflight_001/` with receiver-facing file completeness checks for third-party rerun, official benchmark, and commercial PoC returns, missing-file rows, default v28 inbox paths, and direct v18 verification instructions. It is a pre-send/pre-verify quality gate only; actual/candidate/release flags remain blocked until non-fixture returned directories pass v18.
- v30 is implemented as the commercial codebase QA closed-corpus PoC return above v29/v18. `experiments/test_v30_commercial_codebase_poc_return.sh` builds `results/v30_commercial_codebase_poc_return/return_001/commercial_return/` with domain/corpus manifests, source-bound query rows, PoC result rows, audit trail, resource envelope, privacy review, and acceptance review. v29 sees the commercial return as complete and v18 verifies `closed_corpus_poc_actual_ready=1`; third-party rerun, official benchmark, real external benchmark, and release flags remain blocked.
- v31 is implemented as the official RULER NIAH candidate return above v30/v18. `experiments/test_v31_official_ruler_niah_candidate_return.sh` builds `results/v31_official_ruler_niah_candidate_return/return_001/official_return/`, live-binds the current `NVIDIA/RULER` HEAD, downloads and hashes upstream `scripts/data/prepare.py`, `scripts/eval/evaluate.py`, and `README.md`, and writes official source/evaluator status, raw predictions, RouteMemory prediction lineage, metrics, provenance, reproducibility, and candidate result rows. v18 verifies `candidate_external_benchmark_result_ready=1` while keeping `independent_rerun_actual_ready=0`, `real_external_benchmark_verified=0`, and `real_release_package_ready=0`.
- v32 is implemented as the GitHub Actions third-party rerun kit above v31/v22/v18. `.github/workflows/third-party-rerun.yml` runs the v22 capture script on `ubuntu-24.04`, fills GitHub-hosted reviewer/environment provenance, verifies the return with v18, and uploads the return directory as an artifact using `actions/upload-artifact@v4`. PR run `27029089994` returned `third-party-rerun-return`; local v18 intake with that artifact plus v31 and v30 verifies `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `closed_corpus_poc_actual_ready=1`, and `real_external_benchmark_verified=1` while keeping `real_release_package_ready=0`.
- v33 is implemented as the evidence-closure packet above v32/v31/v30/v18. `experiments/test_v33_evidence_closure_packet.sh` builds `results/v33_evidence_closure_packet/packet_001/`, reruns v18 against the latest downloaded GitHub Actions third-party return plus v31 and v30, copies the v18 summary/decision, third-party return, official candidate return, and commercial PoC return, writes `sha256_manifest.csv`, `CLAIM_BOUNDARY.md`, `evidence_closure_manifest.json`, and a human-review request/template. The packet verifies `v33_evidence_closure_packet_ready=1` while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v34 is implemented as the official benchmark expansion packet above v33/v31/v18. `experiments/test_v34_official_benchmark_expansion_packet.sh` builds `results/v34_official_benchmark_expansion_packet/packet_001/`, expands the v31 RULER NIAH candidate from 1 to 6 raw prediction rows at the same 4096-token context length, reuses the official source/evaluator snapshot, writes RouteMemory lineage, metrics, candidate rows, `EXPANSION_BOUNDARY.md`, `benchmark_expansion_manifest.json`, and `sha256_manifest.csv`, and reruns v18 with the v34 official return plus v33 third-party/commercial evidence. The packet verifies `v34_official_benchmark_expansion_packet_ready=1`, `candidate_external_benchmark_expansion_ready=1`, and `real_external_benchmark_verified=1` while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v35 is implemented as the commercial pilot packet above v34/v33/v18. `experiments/test_v35_commercial_pilot_packet.sh` builds `results/v35_commercial_pilot_packet/packet_001/`, reuses the v30 commercial return schema for an `internal_docs` buyer-visible workflow, writes five source-cited internal-docs QA rows including one release-claim abstain row, privacy/resource/acceptance reviews, `COMMERCIAL_PILOT_BOUNDARY.md`, `commercial_pilot_manifest.json`, and `sha256_manifest.csv`, and reruns v18 with v33 third-party evidence plus the v34 official expansion and v35 commercial return. The packet verifies `v35_commercial_pilot_packet_ready=1`, `closed_corpus_poc_actual_ready=1`, and `real_external_benchmark_verified=1` while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v36 is implemented as the release-claim audit packet above v33/v34/v35. `experiments/test_v36_release_claim_audit_packet.sh` builds `results/v36_release_claim_audit_packet/packet_001/`, copies v33/v34/v35 evidence manifests and summaries, writes `claim_matrix.csv`, `evidence_input_rows.csv`, `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`, `human_review/HUMAN_REVIEW_REQUEST.md`, `human_review/human_review_template.csv`, `v36_release_claim_audit_manifest.json`, and `sha256_manifest.csv`, and decides the maximum allowed public wording. The audit verifies `v36_release_claim_audit_packet_ready=1`, `maximum_allowed_claim_decided=1`, and `human_review_request_ready=1`; the allowed wording is limited to a local evidence-bound QA/audit architecture with deterministic provenance, source-cited answers, conservative abstention, and externally reproducible evidence packets. It keeps `human_review_completed=0`, `real_release_package_ready=0`, and release-ready product/general LLM replacement/Transformer replacement/frontier long-context/GPU acceleration claims blocked.
- v37 is implemented as the human review intake verifier above v36. `experiments/test_v37_human_review_intake.sh` builds `results/v37_human_review_intake/intake_001/`, copies the v36 human-review request/template, normalizes any returned `human_review_rows.csv`, checks the four required review items, reviewer identity, timestamps, and all-pass status, and writes `human_review_intake_manifest.json`, `normalized_human_review_rows.csv`, `missing_review_rows.csv`, and `sha256_manifest.csv`. The default current run verifies `v37_human_review_intake_ready=1` while keeping `human_review_return_supplied=0`, `human_review_completed=0`, and `real_release_package_ready=0`; the smoke also verifies an isolated fixture pass path without changing the default no-return state.
- v38 is implemented as the human review dispatch bundle above v37/v36. `experiments/test_v38_human_review_dispatch_bundle.sh` builds `results/v38_human_review_dispatch_bundle/bundle_001/`, copies the v36 review request, claim audit, claim matrix, decision rows, evidence-input rows, v36/v37 manifests, and missing-review rows into `review_packet/`, prepares `return/human_review_rows.csv`, writes `verify/VERIFY_RETURN.sh`, `HUMAN_REVIEW_DISPATCH_README.md`, `human_review_dispatch_manifest.json`, and `sha256_manifest.csv`. The bundle verifies `v38_human_review_dispatch_bundle_ready=1`, `return_template_ready=1`, and `verify_script_ready=1` while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v39 is implemented as the human review dispatch archive above v38. `experiments/test_v39_human_review_dispatch_archive.sh` builds `results/v39_human_review_dispatch_archive/archive_001/`, archives the v38 bundle as `archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz`, writes `archive/ARCHIVE_SHA256SUMS.txt`, `archive/ARCHIVE_FILE_LIST.txt`, `SEND_ARCHIVE_README.md`, `artifact_manifest.csv`, `human_review_dispatch_archive_manifest.json`, and `sha256_manifest.csv`. The archive verifies `v39_human_review_dispatch_archive_ready=1`, `archive_sha256_ready=1`, `archive_file_list_ready=1`, and required review/return/verify members present, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v40 is implemented as the machine-verified research artifact above v33-v39. `experiments/test_v40_machine_verified_research_artifact.sh` builds `results/v40_machine_verified_research_artifact/artifact_001/`, copies the v36 claim audit, v37 no-return intake state, v38 dispatch bundle evidence, v39 transfer archive evidence, and v33/v34/v35 support summaries, then writes `MACHINE_VERIFIED_RESEARCH_ARTIFACT.md`, `release_mode_rows.csv`, `allowed_claim_rows.csv`, `blocked_claim_rows.csv`, `machine_verification_rows.csv`, `evidence_index.csv`, `v40_machine_verified_research_artifact_manifest.json`, and `sha256_manifest.csv`. It opens only `automated_research_artifact_ready=1` / `machine_verified_prototype_ready=1` for bounded sharing, while explicitly keeping `human_review_completed=0`, `human_review_required_for_public_release=1`, and `real_release_package_ready=0`.
- v41 is implemented as the RULER NIAH 50-row academic scale-up above v34/v33/v18. `experiments/test_v41_ruler_niah_50row_scale.sh` builds `results/v41_ruler_niah_50row_scale/scale_001/`, runs the v34 expansion engine at 50 rows and 4096 context length, verifies 50 raw prediction rows, 50 RouteMemory lineage rows, official evaluator/source reuse, no-oracle/no-extractor status, and v18 intake, then writes `V41_RULER_NIAH_50ROW_BOUNDARY.md`, `scale_rows.csv`, `v41_ruler_niah_50row_scale_manifest.json`, and `sha256_manifest.csv`. It keeps `human_review_completed=0` and `real_release_package_ready=0`.
- v42 is implemented as the Codebase Auditor 200-query buyer-visible industrial demo above v18. `experiments/test_v42_codebase_auditor_200query.sh` builds `results/v42_codebase_auditor_200query/audit_001/`, binds 200 local repository QA/audit rows to tracked source hashes and line citations, includes at least 20 abstain rows for unsupported readiness/replacement claims, writes guard negative controls for corrupted citations and unsupported direct answers, writes `commercial_return/` with the v18 commercial-return schema, `V42_CODEBASE_AUDITOR_BOUNDARY.md`, `auditor_rows.csv`, `v42_codebase_auditor_manifest.json`, and `sha256_manifest.csv`, and verifies `v42_codebase_auditor_200query_ready=1`, `guard_negative_block_rows=3`, plus `v18_closed_corpus_poc_actual_ready=1`. It keeps `human_review_completed=0` and `real_release_package_ready=0`.
- v43 is implemented as the Doc-Code Conflict Detection audit above v42/v18. `experiments/test_v43_doc_code_conflict_detection.sh` builds `results/v43_doc_code_conflict_detection/detection_001/`, derives implementation facts from v42 readiness evidence, creates a bounded doc-code conflict corpus, detects 8 mismatch rows and preserves 4 consistent rows with doc and implementation source spans, writes `V43_DOC_CODE_CONFLICT_BOUNDARY.md`, `detection_case_rows.csv`, `conflict_rows.csv`, `source_span_rows.csv`, `v43_doc_code_conflict_manifest.json`, and `sha256_manifest.csv`, and verifies the return through v18. It keeps `human_review_completed=0` and `real_release_package_ready=0`.
- v44 is implemented as the Tiny Non-Attention Generator Hint smoke above v43/v18. `experiments/test_v44_tiny_non_attention_generator_hint.sh` builds `results/v44_tiny_non_attention_generator_hint/generator_001/`, creates RouteHint payload rows, generator input rows with zero raw prompt context bytes, grounded transcript rows, and missing-query abstain rows, then verifies a v18 commercial return. It checks `v44_tiny_non_attention_generator_hint_ready=1`, `no_raw_prompt_stuffing_ready=1`, `non_attention_generator_ready=1`, `answer_grounded_rate=1.000000`, `span_citation_accuracy=1.000000`, and `wrong_answer_rate=0.000000`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
- v45 is implemented as the LongBench v2 small slice above v44/v18. `experiments/test_v45_longbench_v2_small_slice.sh` builds `results/v45_longbench_v2_small_slice/slice_001/`, snapshots THUDM/LongBench official source/evaluator files, writes 6 multiple-choice raw prediction rows across 6 LongBench v2 task categories, binds 6 RouteMemory lineage rows with no oracle/no raw-input extractor, and verifies the official return through v18. It opens only `v45_longbench_v2_small_slice_ready=1` / `v18_candidate_external_benchmark_result_ready=1`; `real_external_benchmark_verified=0` and `real_release_package_ready=0` remain blocked.
- v46 is implemented as the Source-Verified Scorer mainline above v45/v18. `experiments/test_v46_source_verified_scorer_mainline.sh` builds `results/v46_source_verified_scorer_mainline/scorer_001/`, creates 12 source-bound label rows from v45 official benchmark evidence, trains a deterministic candidate scorer with no local teacher-harness labels, verifies 6 scorer evaluation rows with `scorer_top1_accuracy=1.000000`, `ranking_improvement_ready=1`, and `wrong_candidate_guard_ready=1`, and passes a v18 commercial-return intake. It keeps `human_review_completed=0` and `real_release_package_ready=0`.
- v47 is implemented as the Offline Domain Policy Update above v46/v18. `experiments/test_v47_offline_domain_policy_update.sh` builds `results/v47_offline_domain_policy_update/policy_001/`, writes 15 offline policy rows over 3 domains and 5 learning targets, binds candidate selection, span read, hint strength, abstain/retry, and verifier decision rows to prior evidence summaries, and verifies the policy audit through v18. It keeps `expert_replacement_claim=0`, `release_ready_claim=0`, `human_review_completed=0`, and `real_release_package_ready=0`.
- v48 is implemented as the first post-v47 evidence-scale generator expansion. `experiments/test_v48_multi_domain_generator_evidence.sh` builds `results/v48_multi_domain_generator_evidence/run_001/` and verifies that the full path `RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation/abstain/audit trail` holds across RULER NIAH, LongBench v2, codebase QA, and internal docs QA. It checks 24 generation rows, 20 transformed answer rows, 4 abstain rows, zero raw context in hints, zero raw prompt stuffing, zero raw span copying, zero direct hint-value echo, perfect grounding/citation, v18 commercial intake, and `real_release_package_ready=0`.
- v49 is implemented as the fixed-context RULER NIAH 200/500-row academic scale-up above v34/v33/v18. `experiments/test_v49_ruler_niah_200_500_scale.sh` builds `results/v49_ruler_niah_200_500_scale/scale_001/`, runs the v34 expansion engine at 200 and 500 rows with the same 4096 context length and fixed architecture, verifies raw prediction/RouteMemory lineage row counts, official evaluator/source reuse, no-oracle/no-extractor status, v18 intake, and release blocking, then writes `V49_RULER_NIAH_200_500_BOUNDARY.md`, `scale_rows.csv`, `v49_ruler_niah_200_500_scale_manifest.json`, and `sha256_manifest.csv`.
- v50 is implemented as the Public Repo Auditor 3-repo evidence run above v42/v43/v18. `experiments/test_v50_public_repo_auditor_3repo.sh` checks out pinned commit SHAs for `pypa/sampleproject`, `psf/requests`, and `pallets/click`, binds requested refs, HEAD SHAs, source hashes, and source spans, verifies 9 audit cases with independent detector outputs across doc-code conflict, deprecated/legacy usage, and config mismatch, verifies `detected_doc_code_conflict_rows=1`, `detected_config_mismatch_rows=1`, and `guard_negative_block_rows=3`, then passes the commercial return through v18 while keeping release readiness blocked.
- v51 is implemented as the Real-return Evidence Intake measured trace above v18/v40. `experiments/test_v51_real_return_evidence_intake.sh` measures CPU SHA-256 batch work and filesystem/NVMe-style reads over tracked source files, writes hash-bound trace artifacts, exposes three cited QA/audit rows through v18, binds the result to the v40 machine-verified artifact, and verifies `v51_real_return_evidence_intake_ready=1`, `measured_workload_trace_bound=1`, `real_return_evidence_axis_count=1`, `cpu_trace_rows=7`, `nvme_trace_rows=7`, and `v18_closed_corpus_poc_actual_ready=1`. External/buyer return and real teacher-source import remain unsupplied, `gpu_speedup_claim=deferred`, and `real_release_package_ready=0`.
- v0.3 Architecture Preview is implemented as a user-facing surface over the existing evidence stack. `scripts/audit_my_repo.sh` emits `AUDIT_REPORT.md`, JSONL/CSV findings, citation spans, RouteMemory lineage, mmap read trace, compact RouteHint rows, grounded generation rows, abstain rows, resource envelope, and `reproduce.sh`. `scripts/run_local_scaling_matrix.sh` emits the one-axis store/top-k/cache/RouteHint/query-count local scaling matrix. `examples/local_codebase_intelligence_box.sh` bundles the audit report, baseline comparison note, local scaling summary, architecture trace, lineage, citations, RouteHints, generations, and hashes. `experiments/test_v0_3_architecture_preview.sh` verifies `v0_3_architecture_preview_ready=1`, `one_command_repo_audit_ready=1`, `local_scaling_matrix_ready=1`, `scaling_axis_count=5`, `scaling_curve_rows=27`, `baseline_war_ready=1`, `baseline_rows=8`, `routehint_generator_mainline_ready=1`, `raw_prompt_context_bytes=0`, `attention_blocks=0`, `transformer_blocks=0`, `oracle_prediction_used=0`, `raw_input_extractor_used=0`, while keeping `gpu_speedup_claim=deferred` and `real_release_package_ready=0`.
- The v41-v51 impact roadmap is closed without adding another internal packaging layer. The next high-leverage stage is real external acceptance or teacher-source authority evidence: external/human or buyer PoC acceptance and actual teacher-source import/review. Keep the claim local evidence-bound QA/audit assistance, not Transformer replacement, frontier local LLM, GPU acceleration, long-context solved, or expert replacement.
- h9-g is closed as the measured GPU speed evidence boundary. CPU remains canonical, HIP remains optional/environment-dependent, and fixture timing evidence keeps `gpu_speedup_claim=deferred`.
- h9-h is closed as the diagnostic CPU/HIP/NVMe workload speed evidence gate above h9-g and h11-d. Generated workload artifacts can verify NLG result, timing, environment hashes, positive CPU/HIP ratio, NVMe read latency, query-to-evidence, query-to-first-token, tokens/sec, SSD/RAM/VRAM metrics, and zero routing/jump activity with `diagnostic_workload_speed_ready=1`, but keep `real_workload_speed_evidence_ready=0` and `gpu_speedup_claim=deferred`.
- h7-c is closed as the promotion review gate above h7-b, h10-r, h10-s, v08-ab, h11-d, and h9-h. It verifies the review contract, external/NLG/wrong-answer thresholds, and zero route/jump activity, but keeps `real_evidence_complete=0`, `promotion_review_ready=0`, and `default_promotion=0` until real teacher-source, source-verified scorer eval, external benchmark, PC RouteLM NLG, and workload-speed evidence all pass.
- v12 is closed as the paper/release claim audit above h7-c, h10-r/h10-s, v08-ab, h11-c/h11-d, and h9-h. It raises `diagnostic_release_package_ready=1` and `diagnostic_claim_level=4`, but keeps `real_release_package_ready=0`, `publishable_claim_level=0`, `release_claim=diagnostic-artifact-package-only`, and blocks Transformer replacement, frontier PC LLM, long-context solved, learned sparse routing, and GPU acceleration claims.
- h11-b is closed as the current PC RouteLM / NLG artifact boundary. The verifier checks generator, route-memory, scorer, decoder, NLG-smoke, benchmark, license, and provenance artifact hashes. A supplied local artifact fixture can verify the chain mechanics with `prototype_artifact_chain_verified=1`, but local `results/` fixture URIs and declaration flags still keep `real_pc_routelm_artifact_verified=0`.
- h11-c is closed as the current NVMe-resident RouteMemory artifact smoke. It creates a deterministic route-memory store bundle with `route_memory_store.bin`, `route_index.bin`, `chunk_pages.bin`, `chunk_offsets.bin`, `chunk_credit.bin`, `page_table.bin`, `manifest.json`, and `sha256sums.txt`, then verifies artifact hashes, route lookup, candidate span reads, and zero routing/jump activity. This can reach `route_memory_artifact_chain_verified=1`, but keeps `real_pc_routelm_artifact_verified=0` and `real_external_benchmark_verified=0`.
- h11-d is closed as a diagnostic small-generator PC RouteLM NLG smoke above the h11-c store. It writes a smoke transcript/result artifact, verifies teacher-off inference, retrieved evidence usage, answer grounding, span citation accuracy, span/chunk exactness, missing abstain, wrong-answer rate, latency/SSD/RAM/VRAM metrics, and zero routing/jump activity. Generated fixtures can reach `pc_routelm_nlg_smoke_ready=1`, but `real_pc_routelm_nlg_verified=0` stays blocked.
- Latest verified command stack: focused v14-a runner-owned query/result/evaluator smoke, live v14-a full run with v13-n source acquisition rows, focused v13-n external benchmark official source acquisition smoke, live v13-n source acquisition full run, focused v13-m source seed live-fetch smoke, focused v13-l source seed smoke, focused v13-k runtime fetch provenance smoke, focused v13-j real evidence rebind gate smoke, focused v13-i real evidence live-network gate smoke, focused v13-h real evidence intake gate smoke, focused v13-g real evidence promotion gate smoke, focused v13-f resource envelope smoke, focused v13-e public codebase RouteQA smoke, focused v13-d real NLG transcript binding smoke, focused v13-c evidence packet ABI smoke, focused v13-b RouteLM mmap reader smoke, focused v13-a real-run binder manifest smoke, focused v08-at official result reconciliation smoke, focused v08-as live package artifact fetch authority smoke, focused v08-ar real nonfixture run package intake smoke, focused v08-aq independent live rerun confirmation smoke, focused v08-ap runner-owned live execution/audit smoke, focused v08-ao public non-fixture verification smoke, focused v08-an live replay/final-review smoke, focused v08-am independent run/evaluator evidence smoke, focused v08-al run/evaluator trace smoke, focused v08-ak authority/promotion evidence smoke, focused v08-aj live publication/result ingestion smoke, focused h10-s source-verified scorer eval, h10-r real teacher-source import/review, h10 source-verified scorer, h10 distillation, focused h7-c promotion review, h7 goal closure through h7-c, v08 source-import/source-acquisition/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation checks, h11-c NVMe RouteMemory store/artifact smokes, h11-d PC RouteLM NLG smoke, h9-h workload speed gate, v12 paper/release claim audit, comparison guard tests, and the h9 quick closure through h7-c/v08-at/h11-d/h9-h/v12/v13-a/v13-b/v13-c/v13-d/v13-e/v13-f/v13-g/v13-h/v13-i/v13-j/v13-k/v13-l/v13-m/v13-n.

Current open blockers:

- Real external teacher-label source evidence must pass the h10-j verifier, h10-m acquisition contract, h10-n content-cache verifier, h10-o fetch-attestation contract, h10-p runtime-fetcher contract, h10-q live-network import gate, h10-r import/review chain, and h10-s student-only scorer-evaluation gate. h10-r can verify the import/review contract, but a real teacher-source claim still needs official authority/registry evidence that sets `real_teacher_source_verified=1`; h10-s also needs real, source-bound student-only chunk/span evaluation evidence before the scorer can become a source-verified eval candidate.
- Real external benchmark/source/result/review/publication evidence must now flow through a real-run binder/nonfixture runner path: one execution should populate raw run traces, evaluator output, source/result artifacts, NLG transcript/result, workload/resource rows, scorer/teacher evidence, and v12 claim-matrix input from the same run directory before any external comparison can be published.
- Real HIP-backed CPU/HIP/NVMe workload measurements must replace fixture timing/workload rows before any GPU speedup claim.
- A real non-fixture generator-grounded PC RouteLM/NLG smoke remains future work; h11-d is a diagnostic generated NLG smoke over the h11-c store, not a working product claim.
- Any paper/release claim stronger than diagnostic artifact packaging remains blocked until h7-c and v12 are rerun with real teacher-source, scorer-eval, external-benchmark, PC RouteLM NLG, and workload-speed evidence.

Current headline:

- The project is now best described as a discrete local-energy learner plus a value-bearing route-hint memory research prototype. Through v0.3, the strongest routing conclusion is that long-range information should enter as `candidate value_pos -> value byte read -> proposal hint`, not as remote-neighbor replacement.
- This is not yet learned sparse routing, long-context retrieval solved, wrong-candidate robustness solved, or a Transformer replacement claim. The current live path is the `candidate value_pos -> value byte read -> proposal hint` route-hint path, and jump-neighbor replacement stays no-go/default-off/diagnostic-only.
- Latest route-hint status: h4-5t calibrated the fallback low-channel strength sweet spot, h4-5u showed short fallback TTL/persistence is neutral, h4-5v added route-credit separation instrumentation with only a tiny qacc mitigation, h4-5w is the route-credit ablation diagnostics sweep, h4-5x is the credit × fallback integration ablation, h4-5y is the credit strength/stability calibration sweep, h5-a adds a persistent route-plasticity ledger plus learn/apply warmup gates, h5-b adds source/bucket route-credit responsibility instrumentation, h5-c adds source-credit policy calibration around key-shape fallback `hi_mult=5` / `lo_mult=10`, h5-d adds noisy / learned-like source policy diagnostics across weak `joint-code-key` primary, symbolic `key-shape` fallback, and explicit `noisy-route-code` stress, h5-e adds noisy-source multi-seed / scale stability smoke, h5-f weakens the `route-code-key` identity auxiliary itself, h5-g scales that weak learned-source stress over key/seed arms, h5-h compares fallback-source dependence across `off`, `raw-key`, `key-shape`, and `noisy-route-code`, h5-i calibrates source-credit fallback policy modes, h5-j diagnoses fallback candidate-quality gaps, h5-k calibrates fallback aggregation policy, h5-l adds source/noise-aware fallback aggregation diagnostics, h5-m scales that source/noise-aware aggregation pattern over key/seed smoke arms, h5-n adds source-credit bad-source filter / abstain diagnostics, h5-o adds retry-source replacement after bad-source filtering, h5-p adds source-credit retry-policy calibration, and h5-q passes as source-credit retry-policy tie-break calibration diagnostics / limited mitigation: `noisy-filter` stays at `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`; `policy-source-order`, `policy-keyshape-prior`, and `policy-noisy-penalty/mixed` all recover at `qacc=0.957813`, `fallback_recall=1.000000`, with `retry_noisy_selected=0.000000`; `fixed-keyshape` remains the upper bound at `qacc=0.970313`, `fallback_qacc=1.000000`. NOT learned routing solved, NOT source-credit robustness solved, NOT wrong-candidate/fallback robustness solved.
- h5-r adds source-prior schedule diagnostics for retry tie-breaks via `--route-source-retry-prior-mode none|static|decay|warmup`, `--route-source-retry-prior-decay`, and `--route-source-retry-prior-warmup-epochs`. The smoke keeps noisy retry selection at `0.000000`: source-order recovers through raw-key (`qacc=0.957813`, `retry_raw_selected=0.875000`), while static/decay/warmup key-shape priors recover through key-shape (`qacc=0.957813`, `retry_keyshape_selected=0.875000`). The fixed key-shape reference remains higher (`qacc=0.970313`, `fallback_qacc=1.000000`), so this is prior-schedule calibration / limited mitigation, not learned routing or robustness solved.
- h5-u passes as candidate-quality logdet/channel/quality-score instrumentation, h5-v passes as weak quality source-ranking application diagnostics / neutral-to-slight-regression, h5-w passes as source-quality calibration diagnostics, h5-x passes as proxy weight/sign calibration diagnostics / single-smoke limited mitigation, h5-y passes as channel-sign multi-seed/scale stability diagnostics / weak limited mitigation, h5-z passes as source-normalization instrumentation / neutral diagnostics, h5-aa passes as candidate-level quality diagnostics / actionable split, h5-ab passes as weak bounded candidate-level quality application / limited mitigation, h5-ac passes as candidate-weight composition diagnostics / limited mitigation, h5-ad passes as candidate-only beta/noise scale diagnostics / limited mitigation, h5-ae passes as candidate-weight saturation/cap diagnostics / limited mitigation, h5-af passes as candidate-quality best-setting scale regression diagnostics / limited mitigation, h5-ag passes as candidate-quality over-sharpen boundary diagnostics / limited mitigation, h5-ah passes as high-beta candidate-quality boundary diagnostics / limited mitigation, h5-ai passes as extreme-beta candidate-quality boundary diagnostics / limited mitigation, h5-aj passes as ultra-beta candidate-quality plateau/boundary diagnostics / limited mitigation, h5-ak passes as candidate-quality guardrail selection diagnostics, h5-al passes as candidate-quality safe-default application diagnostics / limited mitigation, h5-am passes as candidate-feature basis calibration diagnostics, h5-an passes as hybrid candidate-basis calibration diagnostics / lower-concentration limited mitigation, h5-ao passes as hybrid candidate-basis guardrail scale diagnostics / lower-concentration limited mitigation, h5-ap passes as hybrid candidate-basis promotion check / safe alternative diagnostics, h5-aq passes as concentration-aware candidate-basis switching diagnostics / safe alternative instrumentation, h5-ar passes as auto-threshold calibration diagnostics / safe alternative instrumentation, h5-as passes as auto-trigger decomposition diagnostics, h5-at passes as auto-trigger policy ablation diagnostics, and h5-au passes as factor-trigger threshold refinement diagnostics. `route_quality_apply=source-ranking` activates a soft bounded source-ranking delta while keeping noisy retry selection at `0.000000`; `route_quality_apply=candidate-weight` applies a bounded relative candidate-weight factor without changing route strength; `route_quality_apply=source-candidate` combines both. In h5-ak (`keys=64,128,256`, seeds `1..5`, noisy source rates `0.10,0.25,0.50`), `beta=8, cap=8` is the safer guardrail setting: aggregate qacc is `0.885747` versus `0.885573` for `beta=12, cap=12`. h5-al then checks the safe setting as a default application arm over `keys=64,128,256`, seeds `1..3`, and noisy rates `0.10,0.25,0.50`: `candidate-default` reaches qacc `0.886429`, versus `proxy-off` `0.646962` and `source-candidate-default` `0.884896`. h5-am adds `--route-quality-candidate-weight-basis base|quality-score`; the quality-score basis is wired but lower than the base default (`feature-margin qacc=0.800000` vs `base-default qacc=0.837630`). h5-an adds `hybrid` basis with `--route-quality-candidate-weight-basis-mix`; h5-ao/h5-ap scale the comparison. h5-aq through h5-au add and dissect `--route-quality-candidate-weight-basis auto` plus concentration thresholds. h5-au shows factor-trigger thresholds are quantized: `5.6/5.8` are broad (`auto_hybrid_rate=0.875304`, `factor_gap=3.241454`, `qacc=0.886328`), `6.0/6.2` are balanced (`auto_hybrid_rate=0.315668`, `factor_gap=3.471377`, `qacc=0.886328`), and `6.4` is base-like (`auto_hybrid_rate=0.000000`, `factor_gap=3.596599`, `qacc=0.886458`). The safe default remains `basis=base`; `hybrid-m0p25` remains the cleaner lower-concentration alternative, and factor-only auto stays diagnostic.

Current calibrated route-quality default:

- Keep `--route-quality-apply candidate-weight` on the value-bearing route-hint path only; do not use quality features to revive jump-neighbor topology replacement.
- Keep `--route-quality-candidate-weight-basis base` as the default. It remains the best qacc default in the latest h5-au threshold refinement (`base-default qacc=0.886458`).
- Use `hybrid-m0p25` as the safer lower-concentration alternative when factor concentration matters: it keeps qacc essentially tied (`0.886545`) while lowering `factor_gap` and `wrong_strength` relative to base.
- Keep factor-only `auto` thresholds diagnostic-only. h5-au shows they explain broad/balanced/base-like concentration regimes, but they do not beat the base default or the `hybrid-m0p25` alternative.
- This is still a controlled route-hint fixture result. It is not learned routing solved, source-credit robustness solved, wrong-candidate robustness solved, fallback robustness solved, or a long-context benchmark claim.

Current stage / next steps:

- Treat the h5 route-quality stack as closed by `experiments/test_v05_route_quality_closure.sh` and the h7 goal closure.
- Treat h10-a through h10-s, h7-b/h7-c, v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at, h11-a/h11-b/h11-c/h11-d, and v12 as the current route-memory policy checkpoint. h10 remains diagnostic/source-gated. v08-b through v08-at now carry external benchmark evidence from adapter/import/comparison through source acquisition, source-acquisition content cache verification, codebase-mini result instrumentation, source-content/result bridge, all-family result bridge mechanics, independent reproduction/review mechanics, official release evidence mechanics, live release verification mechanics, canonical online confirmation mechanics, publication/result review mechanics, live publication/result ingestion mechanics, authority/promotion mechanics, run/evaluator trace mechanics, independent all-family run/evaluator evidence mechanics, live replay/final-review mechanics, public non-fixture/direct-run verification mechanics, runner-owned live execution/audit mechanics, independent live rerun confirmation mechanics, real nonfixture run package intake mechanics, live package artifact fetch/authority mechanics, official result reconciliation mechanics, source-import contract, live verifier, independent live review, authoritative review, public-registry, live-registry-query, live-registry fetch/cache, live-registry network-proof, real-verification, official-authority, result-authority, and publication-package mechanics while still keeping `real_external_benchmark_verified=0` for placeholder, fixture authority, fixture acquisition/content, local codebase-mini instrumentation, supplied bridge/reproduction/release/live-verification/confirmation/review/ingestion/authority mechanics, local runner/evaluator traces without independent all-family evidence, supplied independent all-family evidence, supplied replay/final-review/public direct-run/live-execution-audit/independent-rerun/package-intake/live-fetch-authority/official-result-reconciliation mechanics, or unpublished comparison evidence; h11-a defines the PC RouteLM / NLG prototype readiness contract, h11-b verifies prototype artifact/provenance hash chains while keeping local fixtures non-real, h11-c creates a hash-verified NVMe RouteMemory store smoke for the next codebase benchmark/NLG layers, h11-d adds a diagnostic NLG smoke over that store without making a real product claim, and v12 audits the full stack so only diagnostic artifact packaging is allowed.
- Treat the h6 exact/hash/local-energy span path as symbolic route-memory instrumentation. It proves per-offset value-bearing hints, offset-aware hash candidates, and limited non-`key-shape` span-record scoring under controlled fixtures, not learned chunk retrieval.
- Keep candidate-quality weighting as the strongest route-quality application path so far, with `base` as the default and `hybrid-safe` as the lower-concentration alternative.
- Do not keep increasing route strength or revive topology replacement by default. The current h7-b promotion gate still blocks default promotion, and h7-c now reviews h10-r, h10-s, v08-ab, h11-d, and h9-h together before any promotion claim. h10-a is positive over chunk ranking, h10-b routes it to `weak-hint-with-abstain`, h10-c keeps noisy wrong candidates unselected, h10-d shows raw fallback retry can recover a forced-corrupt primary path (`qacc 0.290000 -> 0.910000`), h10-e covers correct/wrong/near-miss/missing/abstain grounded-span labels, h10-f marks local teacher-label collection ready, h10-g marks local distillation training/eval ready, h10-h marks the external ingestion schema ready, h10-i can import a supplied external teacher-label CSV, h10-j requires real source verification before distillation, h10-k proves only a local learned chunk scorer from local labels, h10-l prevents that local scorer from satisfying a source-verified distillation gate unless row-level external label provenance matches, h10-m allows HTTPS acquisition-package readiness without treating it as fetched real source evidence, h10-n verifies supplied cache hashes, h10-o verifies supplied fetch-attestation mechanics, h10-p verifies runner-owned replay mechanics, h10-q verifies live-network import evidence, h10-r verifies import/review chain mechanics while still blocking official real-source claims, and h10-s adds a student-only chunk/span evaluation gate above the source-verified scorer. Supplied/local fixtures can verify mechanics and eval deltas, but `real_teacher_source_verified=0`, `source_verified_learned_chunk_scorer_ready=0`, `source_verified_learned_chunk_scorer_eval_ready=0`, `real_evidence_complete=0`, `promotion_review_ready=0`, `distillation_ready=0`, and `default_promotion=0` remain in force; external comparison still remains deferred because no real benchmark source/result evidence is ready.
- Real learned/noisy source robustness, chunk-level long-context retrieval, and external long-context baselines remain future work. v08 readiness deliberately defers external benchmark comparison until the promotion gate passes.
- Real PC RouteLM / NLG also remains future work. h11-a can import supplied component evidence for a quantized 3B-14B generator, CPU RAM/NVMe O(n) route memory, GPU candidate scoring, GPU decoder binding, and an NLG smoke URI; h11-b can verify local artifact hash-chain mechanics for those pieces; h11-c creates and verifies a small NVMe-resident RouteMemory store artifact with route lookup and candidate span reads; h11-d generates a diagnostic NLG transcript/result and checks grounding/citation/wrong-answer metrics over that store. The readiness path stays `diagnostic-prototype-only`, the artifact path stays `real_pc_routelm_artifact_verified=0`, and h11-d remains diagnostic until default promotion, real benchmark comparison, real teacher-source distillation, measured GPU speed evidence, and non-fixture generator-grounded NLG evidence exist.
- h5-av now adds that policy-summary layer: the smoke ties qacc between `base-default` and `hybrid-m0p25` at `0.887500`, while `hybrid-m0p25` lowers `factor_gap` from `3.650981` to `3.304388` and receives the diagnostic recommendation `hybrid-m0p25-safe`.
- h5-aw scales the same policy summary across 9 key/noise cells (`keys=64,128,256`, noisy rates `0.10,0.25,0.50`, seeds `1..5`): `hybrid-m0p25` remains qacc-neutral on average (`0.885746 -> 0.885747`), lowers factor gap (`3.607673 -> 3.252902`), lowers wrong strength (`5.852729 -> 5.779043`), and is recommended as `hybrid-m0p25-safe` in all cells.
- h5-ax turns that safe-alternative conclusion into a regression guard: `hybrid-m0p25` must stay within `0.001` qacc of base, lower factor gap, not raise factor max, keep aggregate wrong-strength no-regression, and keep jump-neighbor routing inactive.
- h5-ay adds `--route-quality-candidate-weight-preset none|base-default|hybrid-safe` so the guarded base and hybrid-safe candidate-weight settings can be selected without copying long option blocks. The preset smoke shows exact metric equivalence with explicit settings and keeps `routing_trigger_rate = active_jump_rate = 0.000000`.
- h5-az scales preset adoption over a small key/seed/noise matrix: explicit settings and presets match exactly across 16 rows (`equivalent_rate=1.000000`, all metric deltas `0.000000`), while lookup/read stay populated and jump-neighbor routing remains inactive.
- h5-ba compares the presets directly as experiment arms over the same small key/seed/noise matrix. `hybrid-safe` is recommended in every row: qacc moves `0.863281 -> 0.864258`, factor gap drops `3.440251 -> 3.118539`, factor max drops `6.333333 -> 6.049084`, and jump-neighbor routing remains inactive.
- h5-bb turns the h5-ba preset-policy matrix into a scale guardrail test: summary rows must contain both preset arms, every policy row must recommend `hybrid-safe`, factor gap/max must not regress, aggregate wrong strength must not rise, and `routing_trigger_rate = active_jump_rate = 0.000000`.
- h5-bc adds a closure smoke for the current route-quality stack. It runs shell syntax, `dmv02` build, oracle route-hint, preset equivalence, preset policy smoke, and preset policy scale guardrail together; `--extended` also runs route-code adaptive, preset regression, and candidate-basis guardrail scale checks.
- h6-a opens the route-memory phase with a span-boundary diagnostic. A multi-byte fixture (`HELLO` / `WORLD`) still produces `kv_query_count = route_hint_query_count = 2`, confirming the current stack exposes one first-byte route hint per key, not per span offset. This is explicit boundary instrumentation, not span/chunk routing solved.
- h6-b adds `--route-span-hints 0|1` for exact KV span hints. With `--route-mode hint-kv-exact --route-span-hints 1`, the same `HELLO` / `WORLD` fixture exposes `kv_query_count = route_hint_query_count = 10`, one route hint per value-span offset, while preserving the value-bearing proposal path and keeping jump-neighbor routing inactive.
- h6-c adds exact span scale diagnostics. The smoke compares first-byte and span arms at `key_count=2`, `value_len=5`; route hint query count expands from `2` to `10` under `--route-span-hints 1`, with exact hits/applied hints and jump-neighbor routing inactive.
- h6-d extends span hints to hashed symbolic candidates. With `--route-mode hint-kv-hash --route-span-hints 1`, hash bucket entries retain span offsets and each query offset only compares against same-offset candidates. The smoke exposes `kv_query_count = route_hint_query_count = route_candidate_query_count = 10`, candidate recall/top1 `1.000000`, and keeps `routing_trigger_rate = active_jump_rate = 0.000000`. This is controlled symbolic span-candidate routing, not learned chunk retrieval.
- h6-e adds span hash scale diagnostics. The standard matrix has 8 rows over key count, value length, and hash bits; offset-aware hash candidates keep `qacc_mean = recall_mean = top1_mean = 1.000000`, `collision_rate_mean = 0.000000`, and jump-neighbor routing inactive. This is a span-candidate scale guard, not learned chunk retrieval.
- h6-f adds span ambiguity / collision diagnostics. With `hash_bits=2`, span bucket collision reaches `1.000000`; `K_route=4` drops recall/top1/qacc to `0.500000/0.125000/0.237500`, while `K_route=16` recovers recall to `1.000000` but leaves top1/qacc low at `0.125000/0.293750`. The symbolic `key-shape` scorer recovers `top1=qacc=1.000000`, but the current byte-level candidate-quality preset does not. This is an actionable span-candidate quality split, not learned chunk retrieval solved.
- h6-g adds learned-like span-source stress and span exact-match instrumentation. Clean `route-code-key` span lookup keeps decode/recall/top1 high (`decode=1.000000`, `recall=1.000000`, `top1=1.000000`, `qacc=0.987500`, `span_exact=0.937500`), while weakened route-code identity collapses decode (`0.000000`), creates collisions (`0.750000`), and drops top1/qacc/span-exact (`0.250000/0.606250/0.281250`). Larger `K_route` restores recall to `1.000000` without fixing top1 or span exact-match, and the byte-level candidate-quality preset remains neutral. This is learned-like source stress instrumentation, not learned chunk retrieval solved.
- h6-h adds span-level candidate-quality diagnostics. In weak route-code span stress, `K_route=16` restores all-span recall to `1.000000` but all-span top1 and span exact-match stay at `0.250000`; the byte-level quality preset is neutral, while symbolic `key-shape` recovers all-span top1/span exact-match to `1.000000`. This confirms the next bottleneck is span-level ranking/quality, not recall alone.
- h6-i adds span candidate-quality gap diagnostics. Under weak route-code identity, `K_route=16` restores all-span recall to `1.000000`, but the top candidate is often a coherent wrong key across the whole span (`top_key_consistency=1.000000`, `top_key_correct=0.250000`, `coherent_wrong_top_key=0.750000`). Byte-level `base-default` remains neutral and `hybrid-safe` can be worse in this stress; symbolic `key-shape` restores correct-key share/key entropy/top1 as an upper bound. The next span bottleneck is learned span-record ranking or consistency features, not recall alone.
- h6-j adds `--route-candidate-score span-prefix`, a first non-key-shape span-record ranking probe based only on already-visible query span prefix agreement. It preserves all-span recall but regresses qacc/span exact-match in the smoke (`qacc 0.625000 -> 0.587500`, `span_exact 0.281250 -> 0.218750`) while reducing coherent wrong-key selection (`0.750000 -> 0.593750`). This is useful negative instrumentation: visible prefix consistency alone is not enough to replace symbolic key-shape.
- h6-k adds `--route-candidate-score span-key-support`, a second non-key-shape span-record ranking probe based on candidate keys that appear across multiple offsets in the recovered span candidate set. It preserves all-span recall but is neutral in the current coherent wrong-key stress (`qacc=0.625000`, `span_exact=0.281250`, `coherent_wrong_top_key=0.750000`, unchanged from weak-k16). Same-key support alone is therefore not enough to replace symbolic `key-shape`; a wrong key can also be coherently supported across offsets.
- h6-l adds `--route-candidate-score span-local-energy`, which ranks candidate records by how well their full value span fits the current query span under local energy without route-hint energy. It is the first non-`key-shape` span-record scorer in this series with a limited positive signal: `qacc 0.625000 -> 0.675000`, `span_exact 0.281250 -> 0.406250`, `correct_key_share 0.503125 -> 0.631250`, and `key_entropy 1.238921 -> 0.862081`. It still remains well below symbolic `key-shape`.
- h6-m scales `span-local-energy` over a small key/seed matrix. The limited lift survives on average: `weak_qacc_mean=0.546094`, `local_energy_qacc_mean=0.571875`, `local_energy_qacc_delta_mean=0.025781`; `span_exact_mean` improves `0.273438 -> 0.378906`, while symbolic `key-shape` remains much higher at `qacc_mean=0.984375`, `span_exact_mean=0.921875`.
- h6-n composes `span-local-energy` with h5 candidate-quality presets. `base-default` is neutral on top of local-energy, while `hybrid-safe` improves span-level quality (`span_exact 0.406250 -> 0.593750`, `correct_key_share 0.631250 -> 0.768229`, `key_entropy 0.862081 -> 0.510620`) but lowers byte qacc (`0.675000 -> 0.631250`). This exposes a span exact-match versus byte-qacc policy split.
- h6-o turns that split into an explicit policy artifact. Byte-qacc objective selects `local-energy` (`qacc=0.675000`, `span_exact=0.406250`), while span-exact and balanced objectives select `local-energy-hybrid` (`qacc=0.631250`, `span_exact=0.593750`). The span objective gains `+0.187500` span exact-match while giving back `-0.043750` qacc.
- h6-p scales the h6-o policy artifact over a small key/seed matrix. Byte-qacc selects `local-energy` in every group, while span-exact selects `local-energy-hybrid` in 3/4 groups. The span policy trades mean qacc `-0.033594` for mean span exact-match `+0.062500`; objective split rate is `0.750000`.
- h6-q adds a span-first policy guardrail over h6-p. The strict guardrail accepts the span policy in 1/4 groups, moving qacc `0.571875 -> 0.560937` while improving span exact-match `0.378906 -> 0.425781`; looser guardrails approach the raw span-exact policy. This is guardrail instrumentation, not learned chunk retrieval solved.
- h6-r scales h6-q over weak and harsher learned-like source degradation. In this fixture family, weak degradation keeps objective split but all guardrails reject span-first because qacc loss exceeds the caps; harsher degradation has split in 1/2 groups, and only the looser `span-first-g0p025-cap0p075` guardrail accepts (`qacc_delta=-0.029688`, `span_delta=+0.023438`). This is degradation guardrail instrumentation, not learned source robustness solved.
- h6-s calibrates an adaptive utility guardrail `span_gain - loss_weight*qacc_loss > 0`. `utility-w0p50` accepts weak high-loss splits (`qacc_delta=-0.109375`, `span_delta=+0.062500`), while `utility-w0p75` rejects those and accepts the lower-loss harsher split (`qacc_delta=-0.029688`, `span_delta=+0.023438`). This is adaptive guardrail calibration, not learned source robustness solved.
- h6-t scales the adaptive guardrail smoke over weak/harsher degradation and keeps `utility-w0p75` safe but diagnostic (`bad_accept_rate=0.000000`, no default promotion). h6-u derives chunk-quality diagnostics: smoke `chunk_exact_mean=0.156250`, `coherent_wrong_key_mean=0.828125`, `top1_recall_gap_mean=0.796875`, `keyshape_gap_mean=0.734375`. h6-v/h6-w show source-credit retry can stay noisy-clean but chunk-quality blocks promotion. h6-x/y show plain `span-local-energy` remains better than local transform and route-code similarity probes. h10-a adds `span-chunk-credit` and `span-local-energy-chunk-credit`; in smoke it reaches `qacc=1.000000`, `chunk_exact=1.000000`, `coherent_wrong=0.000000`, and in the 32/64-key scale guard it keeps `chunk_exact=0.960938`, `coherent_wrong=0.000000`, `keyshape_chunk_gap=0.000000`. h10-c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s add joint noisy, fallback/retry, teacher-label contract, local teacher-label collection, local teacher-distillation learner, external ingestion schema, supplied-label import, real teacher-source verification, local learned chunk-quality scorer, row-bound source-verified scorer binding, remote teacher-source acquisition-contract, content-cache verifier, live-fetch attestation, runtime-fetcher, live-network import, real import/review chain, and student-only source-verified scorer eval gates. Default no-env ingestion remains blocked with `teacher_external_label_source_ready=0`; relabeled local rows without provenance and mismatched external label rows are rejected, any local `file://` source fixture remains non-real, h10-r can reach import/review readiness only under supplied non-placeholder review evidence, h10-s can compute positive fixture eval deltas but stays blocked with `source_verified_learned_chunk_scorer_eval_ready=0`, and distillation remains `status=diagnostic-only` with `default_promotion=0`.
- h7-a adds a goal closure smoke. h7-b adds a promotion gate over h6-t/u/v/w/x/y and keeps `default_promotion=0`, `status=diagnostic-only`. h7-c adds the promotion review matrix over h7-b, h10-r, h10-s, v08-ab, h11-d, and h9-h; it keeps `promotion_review_ready=0` and `default_promotion=0` until real evidence exists across every review input.
- v08 adds an external benchmark readiness gate. v08-b through v08-at cover adapter/evidence/import/comparison through official result reconciliation mechanics. These supplied/local mechanics can raise their respective readiness flags, including `external_benchmark_official_result_reconciliation_ready=1`, but still leave `real_external_benchmark_verified=0`. The active path is now v13: a nonfixture runner must bind source/result/evaluator artifacts, raw traces, NLG transcript/result, workload rows, scorer/teacher evidence, and claim-matrix input into one run before external comparison can publish.
- h9-a/h9-b/h9-d/h9-e/h9-f/h9-g/h9-h add an optional ROCm/HIP backend scaffold behind `-DDLE_ENABLE_HIP=ON` and `--backend hip`. CPU remains canonical and default. The first HIP boundaries are bounded route-quality candidate-weight factor parity and diagnostic-only 16x16 proposal-score parity; h9-f runs the parity tool in CPU mode during quick closure and adds a speed-evidence no-claim schema, h9-g verifies timing/environment artifacts, and h9-h binds h9-g plus h11-d into a CPU/HIP/NVMe workload evidence contract. Fixtures keep `gpu_speedup_claim=deferred` unless real HIP/NVMe workload measurements exist. KV parsing, hash/source-credit orchestration, update acceptance, RNG, age/tick/reservoir mutation, and CSV stay on CPU. This is backend/parity/workload-evidence instrumentation, not GPU acceleration proven and not learned routing solved.
- Current verification checkpoint: h6-t/u/v/w/x/y, h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s, h7-b, and h7-c are wired into the h7 goal closure; v08-b through v08-at readiness/instrumentation plus h11-a/h11-b/h11-c/h11-d, h9-h, v12, v13-a, v13-b, v13-c, v13-d, v13-e, v13-f, v13-g, v13-h, v13-i, v13-j, v13-k, v13-l, v13-m, and v13-n are wired into h9 quick closure, and HIP parity remains optional/environment-dependent.

Current status:

- `v0.1` implemented as `dmv01`
- `v0.2-pre` implemented as `dmv02` and treated as the locked baseline
- `v0.2-b` now includes a block-local coupled proposal path, and the default weak-coupling path clears a 5-seed regression on both `counter` and `repeating-text`
- a routing probe path now exists behind `--K-jump` and `--route-source`, including `input-byte` and `joint-code` candidate sources, but it only logs O(1)-candidate diagnostics, does not change graph dynamics, and keeps jump-neighbor replacement no-go/default-off/diagnostic-only
- an experimental `--route-mode jump-neighbors` candidate-ranking slice now exists behind `joint-code`; the current conservative gate removes the fixture regression on the reference runs, and the new `gap_pass` diagnostics show that this happens because triggered nodes still fail the default anchor-gap gate. Reservoir/tick adaptive gating, confidence-aware gating, and confidence-aware acceptance were all tested as default-off slices. The acceptance slice can suppress fixture-side active jumps and recover the sentinel close to baseline under `--route-min-anchor-gap 0.0`, but it still leaves `repeating-text` effectively closed, so it is a guardrail probe rather than a routing win and the whole slice remains experimental
- a default-off `state-code` route-signal probe now exists behind `--route-source state-code` and optional `--route-refresh cycle`; candidate buckets use the current node state while the route anchor stays on learned `joint-code`. On the reference runs this slice is still no-go: `repeating-text` stays probe-equivalent, `cycle` refresh only perturbs the fixture-side guarded jump slightly, and `epoch` refresh collapses back to the baseline/no-op boundary. The route-key diagnostics confirm why: `state-code + cycle` stays almost identical to the learned anchor on all nodes and on triggered nodes (`triggered_key_anchor ~= 0.996` on repeating text and `~= 0.994` on the fixture, last-10 mean), so it is not a meaningfully new routing signal. The diagnostics helper reads every column from `routing_trigger_rate` onward; keep reading these fields as diagnostic output only, not as a routing-success claim
- a diagnostic-only candidate-source compare helper now exists behind `experiments/run_v03_input_byte_jump_compare.sh`; it compares `joint-code`, `input-byte`, and `state-code + cycle` buckets across probe, forced-open `gap0`, and confidence-accepted jump cases on `repeating-text` and the routing fixture. The reference run confirms `input-byte` is a genuinely anchor-different bucket key (`triggered_key_anchor = 0.000` on `repeating-text`, `~= 0.019` on the fixture). In `gap0`, it opens a few jumps but produces no repeat-side lift and hurts the fixture; with positive confidence gain it is structurally suppressed because same-input candidates have the same confidence. Treat it as a candidate-source probe only, not as a routing-success claim
- a diagnostic-only candidate-rejection helper now exists behind `experiments/run_v03_rejection_diagnostics.sh`; it compares `joint-code` and `input-byte` on forced-open `gap0` and confidence-accepted jump-neighbor arms across `repeating-text` and the routing fixture. The helper prints every column from `routing_trigger_rate` onward, including the appended `jump_filter_*` counters. Current readout: fixture `input-gap0` selects many inspected slots but is not neutral, while fixture `input-accept` is dominated by `jump_filter_confidence_gain_rate`; `repeating-text` still barely passes the gate. Treat it as diagnostics only, not as a routing-success claim
- a focused gate/anchor-gap diagnostics helper now exists behind `experiments/run_v03_gate_diagnostics.sh`; it compares `joint-code` and `input-byte` on `repeating-text` and the routing fixture under the default `jump-neighbors` gate, forced-open `gap0`, and the confidence-lowered `c=8.0` gate. Its summary is header-driven, so the appended anchor-gap threshold, quantile, gate-margin, and trigger-reason columns show up automatically. Current readout: `repeating-text` still has near-zero positive anchor-gap mass and no lift, while the fixture opens first under `gap0`; treat it as diagnostic-only and do not read it as a routing win
- an experimental value-bearing route-hint oracle slice now exists behind `--route-mode hint-oracle` and `--lambda-route`; it does not replace local neighbors or alter topology, and instead adds an oracle value-byte bias to proposal energy on parsed `?id=` query positions. This is the first v0.3 slice where long-range signal improves a task metric: fixture query byte accuracy rises from `0.200000` to `1.000000` at `lambda_route = 0.30`, while `repeating-text` remains unchanged because it has no oracle hints. Treat this as `oracle value-bearing route hint works on the fixture`, not as learned or sparse routing
- a follow-up parsed value-candidate route-hint slice now exists behind `--route-mode hint-parsed`; the parser gives the query a matching record value position rather than a direct value byte, and the graph reads the byte at that candidate position. It reproduces the oracle curve on the fixture (`0.20 -> 0.875000`, `0.30/0.50 -> 1.000000`) with `candidate_hit_rate = 1.000000` and mean read distance `126.750000`, while `repeating-text` remains unchanged. Treat this as parsed key/value candidate delivery, not learned routing
- an exact key-value route-hint slice now exists behind `--route-mode hint-kv-exact`; it parses `@KEY=VALUE` records and `?KEY=` queries, uses latest-record-wins lookup, and then reads the matched value position as a proposal hint. On the reference fixture it matches the parsed/oracle curve (`0.20 -> 0.875000`, `0.30/0.50 -> 1.000000`) with `kv_query_hit_rate = 1.000000`, duplicate/missing rates at `0.000000`, and mean read distance `126.750000`; `repeating-text` remains unchanged. Treat this as symbolic exact key-value routing, not learned routing
- the exact KV scale-up helper now probes distance, key count, duplicate, missing, and noisy filler cases via `experiments/run_v03_route_hint_kv_scale.sh`. With `lambda_route = 0.50`, exact lookup stays perfect and distance `64/256/1024/4096` all solve query positions; many-key and noisy fixtures keep `kv_query_hit_rate = 1.000000` but need the `--strong` profile (`lambda_route = 5.0`) to recover `fixture_query_byte_acc = 1.000000`. Treat this as exact retrieval/path validation plus a hint-strength sensitivity finding, not robust learned routing
- a hashed symbolic key candidate slice now exists behind `--route-mode hint-kv-hash`, `--K-route`, and `--route-hash-bits`. It replaces exact string lookup with hash buckets but preserves `candidate value_pos -> value byte read -> proposal hint`; high-bit buckets reproduce exact-KV behavior, while lossy buckets separate top-K recall from rank-1 hint quality (`bits4_kr4` gets recall `1.000000` but top1/query accuracy `0.500000`). `--route-hint-agg vote` now adds multi-candidate nibble voting: it solves a controlled top1-failure smoke (`0.000000 -> 1.000000`) and improves the 32-key lossy sweep (`bits4_kr4: 0.500000 -> 0.700000`, `bits6_kr4: 0.875000 -> 0.956250`). `--route-hint-agg weighted-vote --route-candidate-score value-vote` adds h4-3 scoring diagnostics; it passes a controlled repeated-value collision smoke but is neutral on the default 32-key sweep where bucket values are mostly unique. `--route-candidate-score key-shape` adds h4-4 deterministic symbolic scoring and resolves the current 32-key lossy ambiguity (`bits4_kr4_key_shape` reaches query accuracy `1.000000`), but it uses parsed key-string shape and is not learned routing. `--route-hash-source joint-code-key` adds h4-5b/h4-5c learned-code key-region diagnostics; the one-key smoke passes, but the 32-key sweep is not yet a learned routing win (`bits16_kr4_vote` query accuracy `0.462500`, recall `0.687500`). New representation diagnostics show why: `key_region_joint_decode_acc = 0.093750` and `joint_signature_collision_rate = 0.625000` on `bits16_kr4_vote`. `--route-hash-source route-code-key --route-code-aux 1` adds h4-5d/e/f/g/h/i/j/k/l/m/n/o identity-code, dynamics, corruption, confidence, aggregation-policy, low-confidence subset, low-confidence policy, fallback-source, and projected-delta diagnostics; the 32-key `bits16_kr4_vote` route-code run reaches query accuracy/recall/top1 `1.000000` with route decode `1.000000` and signature collision `0.000000`. Stress shows 32/64 clean keys solve, while 128 keys keep retrieval perfect but query accuracy drops to `0.562500`; h4-5f then shows this is strength/effective-margin limited because `lambda_route = 10.0` recovers 128-key query accuracy to `1.000000`, while cycles and route-target proposal injection do not monotonically fix it. h4-5g adds `--route-strength-mode margin` and recovers the 128-key setting with lower mean route strength (`alpha=1.0`: qacc `0.998438`, mean strength `4.871687`; `alpha=1.5`: qacc `1.000000`, mean strength `6.454238`). h4-5h adds wrong-candidate corruption diagnostics: low-confidence corrupted hints are strength-suppressed, but qacc damage reduction is modest. h4-5i adds confidence calibration: value-support confidence lowers wrong hint strength but does not improve qacc. h4-5j adds `--route-strength-confidence agreement`; scorer agreement gives positive confidence separation and lowers wrong strength, but only limited qacc mitigation. h4-5k adds `--route-hint-agg confidence-gated`: it uses confidence as an aggregation-policy selector, sending low-confidence queries to `vote` and high-confidence queries to `weighted-vote`; the smoke shows a real low/high split and limited qacc mitigation, but wrong-candidate robustness is still not solved. h4-5l adds low-confidence subset diagnostics: preserve-correct low-confidence failures keep top-K recall at `1.000000` but lose top1/value support, while remove-correct lowers recall and points to fallback/abstain. h4-5m adds `--route-lowconf-policy aggregate|none|weak-vote` plus `--route-lowconf-weak-scale`: preserve-correct shows policy leverage (`aggregate qacc = 0.854688`, `none = 0.812500`, `weak-vote = 0.848438`), while remove-correct remains candidate-availability limited (`qacc = 0.804688`, high-confidence recall `0.789062`). h4-5n adds `--route-fallback-source off|raw-key|key-shape`: symbolic key-shape fallback recovers remove-correct candidate availability (`fallback_recall = 1.000000`, `fallback_success = 1.000000`) and improves qacc (`0.804688 -> 0.839062`), but fallback-used qacc remains low (`0.237037`). h4-5o adds `--route-delta-mode target-only|projected` plus pull/push scales; projected C-version stays query-local, rewards only direct target-nibble entry, and penalizes only direct target-nibble exit. Smoke shows `projected 1.0/1.0` matches target-only, `pull=2.0` improves preserve qacc (`0.854688 -> 0.875000`) but does not improve remove-correct fallback qacc (`0.237037`). Treat h4-5m/n/o as instrumentation/actionable split, not robustness solved
- h4-5p smoke passes as fallback-strength diagnostics / limited mitigation:
  target-only key-shape fallback improves qacc `0.839062 -> 0.898437` and
  fallback_qacc `0.237037 -> 0.518518` from multiplier `1.0 -> 10.0`, while
  projected `pull=2.0` is helpful at moderate multipliers but non-monotonic.
  This keeps the finding narrow: fallback-used failures are partly
  strength-limited, but learned routing and wrong-candidate robustness are not
  solved
- h4-5q adds fallback-specific adaptive strength via
  `--route-fallback-strength-mode fixed|margin`; margin mode improves over
  fixed `mult=1.0` with much lower mean strength than fixed `mult=10.0`
  (`alpha=8.0,max=40.0`: qacc `0.873437`, fallback_qacc `0.400000`, mean
  fallback strength `25.902632`), but it does not match fixed strong and is
  still diagnostics / limited mitigation only
- h4-5r adds fallback-used channel-specific strength diagnostics via
  `--route-fallback-hi-strength-mult` and `--route-fallback-lo-strength-mult`.
  The smoke indicates the residual fallback integration bottleneck is more
  low-nibble sensitive: balanced `m=5` reaches fallback_qacc `0.466666`, while
  low-channel boost reaches `0.548148` and high-channel boost falls to
  `0.377778`. This is a narrow fallback-channel diagnostic, not fallback
  robustness solved
- h4-5s adds fallback channel-adaptive strength via
  `--route-fallback-channel-strength-mode margin` with separate high/low
  channel margin alphas and caps. It confirms the adaptive channel path is
  wired: lo-biased margin raises fallback_qacc over balanced margin
  (`0.355555 -> 0.392592`) by increasing low-channel effective strength, but
  fixed lo-boost remains stronger (`fallback_qacc = 0.525926`). Treat this as
  channel-adaptive instrumentation / lower-strength limited mitigation only
- h4-5t adds a low-nibble fallback strength grid using the existing
  fallback-channel multipliers. With `hi_mult=5`, the smoke shows a narrow
  sweet spot around `lo_mult=7.5..10` (`fallback_qacc 0.540741..0.548148`) and
  mild degradation by `lo_mult=15` (`0.533333`). This calibrates low-channel
  strength before any TTL/persistence work; it is still diagnostics / limited
  mitigation only
- h4-5u adds fallback persistence / TTL diagnostics via
  `--route-fallback-persist-cycles`. In the current smoke, TTL metrics are
  wired (`ttl=3` gives persist used rate `1.000000` and mean cycles
  `3.000000`), but qacc is neutral or slightly worse (`lo7.5: 0.540741 ->
  0.525926`, `lo10: 0.548148 -> 0.548148`). Treat this as persistence
  instrumentation, not fallback robustness solved
- h4-5v adds value-position route-credit diagnostics via
  `--route-credit-learning`. On preserve-correct corruption, credit separates
  correct and wrong candidates (`credit_gap = 1.110268`) and gives a tiny qacc
  move (`0.845312 -> 0.850000`). Treat this as route-credit separation
  instrumentation / tiny mitigation only, not wrong-candidate robustness solved
  and not learned routing solved. Next route-credit work should ablate score
  weight, reward/slash ratio, decay, clip, value-pos versus query-value edge
  credit, and credit combined with the fallback low-channel strength sweet spot
- h4-5w adds route-credit ablation diagnostics and `--route-credit-mode
  query-value`. The smoke keeps value-pos credit working, wires query-value
  edge credit (`query-value-probe` gap `0.598951`), and shows credit plus
  low-channel fallback can move the fallback subset (`fallback_qacc 0.688889 ->
  0.777778` in the smoke). Treat this as ablation instrumentation / limited
  mitigation only, not robustness solved
- h4-5x adds the credit × fallback integration factorial: true
  `--route-credit-mode off`, `value-pos`, and `query-value` crossed with
  key-shape fallback `hi_mult=5`, `lo_mult=7.5/10/15`, and preserve/remove
  corruption. Smoke shows credit separates candidates while preserve-correct
  qacc stays neutral, and remove-correct qacc moves from `0.912500` to
  `0.925000` at `lo=7.5/10`. This is integration diagnostics / limited
  mitigation only.
- h4-5y adds route-credit strength/stability calibration. The smoke keeps true
  no-credit `off` baselines and diagonal active `value-pos/query-value` cells
  over score weight, slash strength, corruption rate, and low-channel fallback
  multiplier. Off rows remain credit-neutral, active rows produce positive
  gaps, and query-value preserve rows show stronger separation (`0.750000`)
  than comparable value-pos rows (`0.290625` / `0.236364`). Remove-correct rows
  populate fallback diagnostics, but the qacc/fallback_qacc effect remains
  condition-dependent. This is calibration diagnostics / limited mitigation
  only, not wrong-candidate robustness solved.
- h5-a adds a persistent route-plasticity ledger via
  `--route-plasticity-ledger`, plus `--route-credit-learn-after-epoch` and
  `--route-credit-apply-after-epoch` warmup gates. The smoke keeps the same
  value-bearing path, verifies candidate lookup/read distance stays populated,
  and verifies `routing_trigger_rate` / `active_jump_rate` stay `0.000000`.
  Treat this as route-plasticity instrumentation only, not learned routing
  solved and not wrong-candidate robustness solved.
- h5-b adds source/bucket-level route credit via
  `--route-source-credit-learning`. The smoke keeps the value-bearing path
  active and jump-neighbor replacement inactive, then separates remove-correct
  responsibility: source-on remove-correct has source credit size `73`,
  fallback mean `0.300000`, primary mean `0.023438`, source gap `0.276563`,
  primary slashed rate `0.281250`, and fallback rewarded rate `1.000000`.
  qacc is neutral in the smoke, so this is source/bucket responsibility
  instrumentation, not fallback robustness or learned routing solved.
- h5-c adds source-credit policy calibration on remove-correct corruption
  `0.25` with key-shape fallback `hi_mult=5` / `lo_mult=10`. The smoke keeps
  the value-bearing path active, but source-only rows stay qacc-neutral while
  they learn a source gap (`0.276563` without apply, `0.553125` with stronger
  source weighting) and the ledger row only changes persistent state (`ledger
  size 0 -> 59`, `mean_abs_credit = 0.711864`) while qacc stays `0.931250` on
  the ledger rows. This is policy instrumentation, not robustness solved.
- h5-d adds noisy / learned-like source policy diagnostics on remove-correct
  corruption `0.25`. The smoke has two controlled branches: weak
  `joint-code-key` primary with `key-shape` fallback, and explicit
  `noisy-route-code` fallback/source stress with `--route-noisy-source-rate
  1.0`. It keeps `route_hint_candidate_lookup_count` and
  `route_hint_value_read_distance_mean` populated, leaves
  `routing_trigger_rate` / `active_jump_rate` at `0.000000`, gives positive
  source gap for useful key-shape fallback, and gives negative noisy-source
  credit/slash diagnostics for bad noisy candidates. This is source-quality
  separation instrumentation, not robustness solved.
- h5-e adds noisy-source multi-seed / scale stability diagnostics. The smoke
  crosses key counts `32/64`, seeds `1/2`, and noisy rates `0.50/1.00`.
  The weak joint branch keeps positive key-shape fallback source gaps across
  the smoke, while the noisy branch keeps negative noisy-candidate credit and
  nonzero noisy slash diagnostics. Fully noisy rows also get negative source
  gap. This is stability instrumentation, not source-credit robustness solved.
- h5-f adds weaker learned-source stress diagnostics for `route-code-key` via
  `--route-code-key-region-keep-prob` and `--route-code-aux-noise-rate`. The
  smoke crosses key counts `32/64` and seeds `1/2`, comparing clean full
  identity supervision to a weak route-code branch (`keep=0.25`,
  `aux_noise=0.75`). Clean rows keep decode/primary recall/qacc at
  `1.000000`, while weak rows drop route-code decode and primary recall,
  trigger key-shape fallback, and produce positive source-credit gap plus
  primary slash / fallback reward signals. This is weaker learned-source
  instrumentation, not learned routing solved.
- h5-g adds weak learned-source multi-seed / scale stability diagnostics. The
  smoke crosses key counts `64/128`, seeds `1/2`, and clean/mid/weak route-code
  weakening arms, then compares weak fallback-off against weak key-shape
  fallback with source-credit `ranking-strength` plus ledger. Mean smoke
  readout: clean-off keeps qacc/decode/recall `1.000000`; mid-off reaches
  qacc `0.970313`, decode `0.630937`, recall `0.994531`; weak-off drops to
  qacc `0.185938`, decode `0.000000`, recall `0.285938`; weak fallback-ledger
  improves qacc to `0.460156` while fallback_used reaches `0.714063` and
  source gap / slash / reward are populated. This is scale/stability
  instrumentation, not source-credit robustness solved.
- h5-h adds fallback-source dependence / stability diagnostics. The smoke keeps
  the weak route-code source fixed and compares fallback `off`, exact symbolic
  `raw-key`, symbolic `key-shape` with source-credit `ranking-strength`, and
  bad `noisy-route-code`. Mean smoke readout: fallback-off qacc `0.213281`;
  raw-key qacc `0.650000`, fallback_recall `1.000000`; key-shape qacc
  `0.437500`, source_gap `0.299223`; noisy-route-code qacc `0.173437`,
  source_gap `-0.207562`, noisy_mean `-0.201440`, noisy_slash `0.979234`.
  This separates symbolic fallback dependence from bad-source diagnostics; it
  is not learned routing solved.
- h5-i adds source-credit fallback-policy calibration diagnostics. The smoke
  keeps the weak route-code source fixed, then separates `key-shape`
  learn-only, ranking, strength, and ranking-strength apply modes against
  `raw-key` symbolic ceiling and `noisy-route-code` negative control. Mean
  smoke readout: off-control qacc `0.206250`; raw-key qacc `0.661328`,
  fallback_recall `1.000000`; key-shape source_gap `0.299047`, selected
  fallback `0.660209` under ranking, strength mean `1.402324` under strength;
  noisy-route-code source_gap `-0.182191`, noisy_mean `-0.189995`, noisy_slash
  `0.976094`, fallback_recall `0.000000`. This is policy calibration
  instrumentation, not fallback robustness or learned routing solved.
- h5-j adds fallback candidate-quality gap diagnostics. The smoke compares
  `raw-key` and `key-shape` fallbacks under `vote`, `weighted-vote`, and
  source-credit `ranking-strength`. Both fallback sources recover candidates,
  but top1 remains low (`0.031250`, mean rank `2.500000`). Plain vote stays
  weak (`raw` qacc `0.225000`, `key-shape` qacc `0.200000`), while
  weighted-vote raises correct value support and lowers entropy, nearly solving
  both (`raw` qacc `0.942188`, `key-shape` qacc `0.960938`). This says the
  exposed bottleneck is fallback aggregation quality, not fallback recall
  alone.
- h5-k adds fallback aggregation policy calibration. The smoke compares
  `top1`, `vote`, `weighted-vote`, and confidence-gated policies for `raw-key`
  and `key-shape` fallback. Plain vote is the weak policy (`raw` qacc
  `0.328125`, `key-shape` qacc `0.204688`), while top1 and weighted-vote are
  strong in this controlled fallback setting (`top1` qacc `0.906250` for both;
  weighted qacc `0.943750` / `0.956250`). Confidence-gated
  low=`vote`, high=`weighted-vote` inherits the vote weakness, while
  low=`weighted-vote`, high=`weighted-vote` preserves the weighted baseline.
- h5-l adds source/noise-aware fallback aggregation diagnostics. The smoke
  applies weighted aggregation plus source-credit policy to symbolic fallback
  sources and keeps the noisy fallback as a negative control. Raw-key improves
  from vote qacc `0.401563` to source-aware qacc `0.965625`; key-shape improves
  from `0.218750` to `0.964063`. The noisy fallback remains unsolved
  (`fallback_recall=0.000000`) but is detected by negative source/noisy credit
  (`source_gap=-0.140244`, noisy slash `1.000000`) and receives no strength
  amplification (`strength_mean=1.000000`).
- h5-m adds source/noise-aware aggregation scale stability diagnostics. The
  smoke crosses key count `64/128` with seeds `1/2` and compares vote versus
  source-aware weighted aggregation for `raw-key`, `key-shape`, and
  `noisy-route-code` fallback sources. Averaged over the smoke, raw-key improves
  from qacc `0.378516` to `0.925391`, and key-shape improves from `0.275781` to
  `0.932813`; both keep `fallback_recall=1.000000`. The noisy branch remains
  unresolved (`fallback_recall=0.000000`) while keeping negative source/noisy
  credit (`source_gap=-0.268339`, noisy slash `1.000000`) and no strength
  amplification (`strength_mean=1.000000`).
- h5-n adds bad-source filtering / abstain diagnostics. New
  `--route-source-filter-mode negative-credit` drops candidates whose source
  credit is below `--route-source-filter-threshold`. In the smoke, symbolic
  fallbacks stay usable (`raw-filter` qacc `0.951562`, `keyshape-filter` qacc
  `0.965625`), while noisy fallback candidates are heavily filtered
  (`source_filter_filtered=0.935065`, `source_filter_abstain=0.875000`).
  Noisy qacc does not improve (`0.185937 -> 0.100000`), so this is bad-source
  abstention instrumentation, not fallback robustness solved.
- h5-o adds retry-source replacement diagnostics via
  `--route-source-retry-source`. The smoke keeps a bad `noisy-route-code`
  fallback, then adds a symbolic retry source after negative-credit filtering.
  The noisy-filter baseline abstains without recovery (`qacc=0.103125`,
  `fallback_recall=0.000000`, `source_filter_abstain=0.876562`). Adding a
  retry source restores candidate recall and query accuracy (`retry-raw`
  qacc `0.950000`, `fallback_recall=1.000000`; `retry-keyshape` qacc
  `0.962500`, `fallback_recall=1.000000`) while keeping jump-neighbor routing
  inactive. This is retry/replacement instrumentation with symbolic retry
  sources, not learned routing or fallback robustness solved.
- h5-p adds source-credit retry-policy calibration via
  `--route-source-retry-policy source-credit`,
  `--route-source-retry-candidates`, and
  `--route-source-retry-per-source-limit`. The smoke compares fixed retry
  sources with policy-selected retry candidates after noisy-source filtering.
  The noisy-filter baseline abstains without recovery (`qacc=0.103125`,
  `fallback_recall=0.000000`), fixed symbolic retry recovers (`fixed-raw`
  qacc `0.957813`, `fixed-keyshape` qacc `0.970313`), and the source-credit
  mixed policy recovers while avoiding noisy retry selection (`policy-mixed`
  qacc `0.957813`, `retry_noisy_selected=0.000000`). This wires retry-source
  policy selection, but the policy still relies on symbolic retry candidates
  and does not solve learned routing or fallback robustness.
- h5-q adds source-credit retry-policy tie-break calibration via
  `--route-source-retry-tiebreak source-order|source-prior` and
  `--route-source-retry-priorities <csv>`. The smoke keeps the same
  `candidate value_pos -> value byte read -> proposal hint` path and compares
  noisy-filter, policy-source-order, policy-keyshape-prior,
  policy-noisy-penalty/mixed, and fixed-keyshape reference rows. Noisy-filter
  stays at `qacc=0.103125`, `fallback_recall=0.000000`,
  `noisy_slashed=1.000000`, `source_retry_used=0.000000`; policy-source-order
  recovers through raw-key (`qacc=0.957813`, `fallback_recall=1.000000`,
  `retry_raw_selected=0.875000`), while key-shape prior and
  noisy-penalty/mixed switch selection to key-shape
  (`retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`) with
  no qacc regression. The fixed key-shape reference remains higher
  (`qacc=0.970313`, `fallback_qacc=1.000000`), so this is tie-break
  calibration / limited mitigation, not learned routing solved,
  source-credit robustness solved, or wrong-candidate/fallback robustness
  solved.
- h5-r adds source-prior schedule diagnostics on the same retry path via
  `--route-source-retry-prior-mode none|static|decay|warmup`,
  `--route-source-retry-prior-decay`, and
  `--route-source-retry-prior-warmup-epochs`. The smoke compares source-order,
  static key-shape prior, decaying key-shape prior, warmup key-shape prior, and
  fixed key-shape reference rows. The scheduled-prior rows switch retry
  selection to key-shape and avoid noisy retry selection, but still match
  `qacc=0.957813` rather than the fixed key-shape reference `0.970313`; read
  this as source-prior schedule calibration / limited mitigation only.
- h5-s adds source-prior handoff diagnostics on the same retry path. The smoke
  compares source-order, static key-shape prior, warmup-short/long, decay-fast,
  and fixed key-shape reference rows. Short warmup exposes a partial handoff
  (`retry_raw_selected=0.062500`, `retry_keyshape_selected=0.812500`), while
  long warmup/decay/static prior keep key-shape selected
  (`retry_keyshape_selected=0.875000`). Noisy retry remains unused, and qacc
  remains `0.957813`, below fixed key-shape `0.970313`; read this as
  source-prior handoff calibration / limited mitigation only.
- h5-t adds retry-source evidence-quality diagnostics. New CSV metrics expose
  retry-source credit means and reward/slash rates for raw-key, key-shape, and
  noisy retry sources. The smoke keeps the value-bearing path active and
  noisy retry suppressed: source-order rewards raw-key
  (`retry_raw_mean=0.222951`), static/warmup key-shape prior rewards key-shape
  (`retry_keyshape_mean=0.222951`), and noisy retry stays negative
  (`retry_noisy_mean=-0.206811`, `retry_noisy_slashed=1.000000`). This is
  evidence-quality instrumentation only: raw-key and key-shape both receive
  positive credit when selected, so source-credit evidence still does not
  independently rank the better symbolic retry source.
- h5-u passes as candidate-quality logdet/channel/quality-score instrumentation
  with `route_quality_apply=none`. The smoke keeps behavior unchanged
  (`quality-off-source-order` and `quality-on-source-order` both `qacc=0.645313`)
  while exposing candidate-set quality signals. In this diagnostic setup, fixed
  raw-key separates from fixed key-shape (`qacc=0.742187` vs `0.645313`,
  `logdet=-5.818583` vs `-15.330912`, condition `7.050210` vs `52.270703`).
  Read this only as instrumentation, not a learned-routing or robustness win.
- h5-v adds the first weak quality application via `route_quality_apply=source-ranking`.
  It uses a bounded soft delta only; no hard threshold/filter is used and the
  value-bearing route path stays active. The smoke activates the path
  (`route_quality_apply_active=1.000000`, delta `0.227710..0.250000`) and avoids
  noisy retry selection, but qacc is slightly lower than apply-none
  (`0.560938` vs `0.568750`). Read this as calibration diagnostics, not a
  robustness win.
- h5-w adds source-quality calibration diagnostics for that weak apply path.
  The retry-source proxy is now reported per source: raw-key is strongly
  positive (`2.277099`), while key-shape and noisy-route-code are negative
  (`-0.472130`, `-0.513364`). This explains why source-ranking keeps selecting
  raw-key and avoiding noisy retry, but it also shows that the current proxy is
  not qacc-optimal.
- h5-x calibrates proxy signs while keeping source-ranking soft. The
  channel-sign row is the best single smoke (`qacc=0.662500`,
  `selected_raw_qacc=0.720536`) versus proxy-default `qacc=0.560938`. This is
  useful, but still narrow: the next step is multi-seed/scale stability before
  stronger candidate-weight or route-strength application.
- h5-y runs that channel-sign check across the first multi-seed/key smoke.
  With `keys=64,128`, seeds `1..3`, and noisy source rate `0.25`,
  channel-sign has mean qacc `0.636198`, proxy-default has `0.621094`, and
  proxy-off has `0.622656`; noisy selection stays `0.000000`, while raw-key
  remains the selected retry source. Treat this as weak limited mitigation and
  stability diagnostics, not source selection solved.
- h5-z adds `--route-quality-source-normalization none|center|zscore`.
  Center/zscore normalization lowers raw source-ranking pressure while keeping
  the channel-sign qacc unchanged (`0.636198`) and noisy selection at
  `0.000000`; source choice still stays raw-key-centered. This is
  source-normalization instrumentation, not a new robustness win.
- h5-aa adds candidate-level quality diagnostics. In the same standard smoke,
  correct candidate weight stays above wrong candidate weight (`0.396566` vs
  `0.217533`, gap `0.179034` on channel-sign), and the best weighted candidate
  is correct more often than final qacc (`0.838021` vs `0.636198`). This makes
  the next bottleneck candidate-level application / aggregation-to-state
  integration, not source-level normalization alone.
- h5-ab enables weak bounded candidate-level application with
  `--route-quality-apply candidate-weight`. It sharpens existing base weights
  with a clamped relative factor and keeps route strength off. In the standard
  smoke, `candidate-b0p50` reaches qacc `0.725261`, improving over proxy-off
  and source-ranking while leaving `routing_trigger_rate` and
  `active_jump_rate` at `0.000000`.
- h5-ac adds `--route-quality-apply source-candidate`, combining source-ranking
  with candidate-weight. The combined mode is wired and safe, but it does not
  beat candidate-only in the current standard smoke (`source-candidate-b0p50`
  `0.717708` vs `candidate-b0p50` `0.725261`). The next target is
  candidate-only beta/scale stability.
- h5-ad scales the candidate-only beta sweep over `keys=64,128`, seeds `1..3`,
  and noisy source rates `0.10,0.25,0.50`. Within the tested bounded factor
  range, candidate-only qacc keeps improving through `beta=0.75`:
  proxy-off `0.615799`, `b0p25` `0.666580`, `b0p50` `0.722222`, `b0p75`
  `0.775434`. This is still a controlled route-hint fixture result:
  `route_quality_selected_noisy_rate`, `routing_trigger_rate`, and
  `active_jump_rate` all remain `0.000000`.
- h5-ae adds candidate-weight saturation/cap diagnostics and concentration
  metrics (`factor_p90`, `factor_max`, entropy, and top share). In the standard
  sweep, `beta=2.0` with cap `3.0/4.0` is the best tested point
  (`qacc=0.922396`, factor max `2.333333`, top share `0.585550`), while cap
  `2.0` clips that arm and lowers qacc to `0.905729`. The slice finds a cap
  boundary, not an over-sharpening failure.
- h5-af promotes the best h5-ae-style setting into a broader regression sweep
  over `keys=64,128,256`, seeds `1..3`, and noisy source rates `0.25,0.50`.
  The aggregate qacc improves from proxy-off `0.637153` to
  `candidate-b2p00-cap3p0` `0.869965`; the same arm is best in every
  key/noise bucket. `candidate-b2p00-cap2p0` falls to `0.843620`, confirming
  that cap `2.0` is too tight at high beta. `route_quality_selected_noisy_rate`,
  `routing_trigger_rate`, and `active_jump_rate` remain `0.000000`.
- h5-ag extends the high-beta boundary over `keys=128,256`, seeds `1..3`, and
  noisy rates `0.25,0.50`. It does not find an over-sharpen collapse through
  `beta=3.0`; aggregate qacc rises from `b2p00-cap3p0` `0.934896` to
  `b3p00-cap3p0` `0.947331`. Caps `4.0/6.0` match cap `3.0` because the
  observed factor max is already `3.000000`, so cap is no longer the active
  boundary in this range.
- h5-ah extends the same boundary to `beta=4.0/5.0` and caps `4.0/6.0/8.0`.
  It still does not find collapse: aggregate qacc reaches
  `candidate-b5p00-cap6p0` / `cap8p0` `0.952669`. Cap `4.0` is slightly lower
  at `0.950195`, while cap `6.0/8.0` tie because the observed factor max is
  `4.333333`.
- h5-ai extends the same candidate-weight boundary to `beta=6.0/8.0` with
  caps `6.0/8.0/12.0`. It still does not find an over-sharpen collapse:
  aggregate qacc reaches `candidate-b8p00-cap8p0` / `cap12p0` `0.957813`.
  The guard remains intact (`selected_noisy_rate`, `routing_trigger_rate`, and
  `active_jump_rate` all `0.000000`), but concentration keeps rising
  (`factor_max=6.333333`, top share `0.689736`, entropy `1.157891`), so this is
  an extreme-beta boundary diagnostic rather than a robustness claim.
- h5-aj extends the boundary again to `beta=10.0/12.0` with caps
  `10.0/12.0/16.0`. It still does not find an over-sharpen collapse, but it
  does show a practical plateau: `candidate-b12p00-cap12p0` / `cap16p0`
  reaches only `0.958008` versus `candidate-b8p00-cap8p0` `0.957813`, while
  factor max rises to `9.000000` and top share rises to `0.713297`. Treat this
  as ultra-beta plateau/boundary diagnostics, not a reason to change route
  strength or promote robustness claims.
- h5-ak compares the plateau candidates over a broader 5-seed/key/noise
  guardrail: `keys=64,128,256`, seeds `1..5`, noisy rates `0.10/0.25/0.50`.
  `beta=8, cap=8` slightly beats `beta=12, cap=12` on aggregate qacc
  (`0.885747` vs `0.885573`) and has lower concentration and wrong strength.
  The current safe bounded candidate-weight default is therefore
  `beta=8, cap=8`, not the more concentrated `beta=12` arm.
- h5-al fixes that safe setting as a default-application comparison over
  `keys=64,128,256`, seeds `1..3`, and noisy rates `0.10/0.25/0.50`.
  Candidate-weight-only remains the cleanest default: `candidate-default`
  reaches qacc `0.886429`, versus `proxy-off` `0.646962` and
  `source-candidate-default` `0.884896`. Source-ranking composition is wired
  but not promoted; noisy source selection, routing trigger, and active jump
  remain `0.000000`.
- h5-am adds `--route-quality-candidate-weight-basis base|quality-score` and
  compares the h5-al base default against feature-score candidate bases over
  `keys=64,128`, seeds `1..3`, and noisy rates `0.25/0.50`. The feature basis
  is connected and reduces wrong hint strength, but it weakens factor
  separation and qacc: `base-default` reaches `0.837630`, while the best
  feature arm, `feature-margin`, reaches `0.800000`. The default remains
  `candidate-weight-basis=base`.
- h5-an adds `--route-quality-candidate-weight-basis hybrid` and
  `--route-quality-candidate-weight-basis-mix`. The best hybrid arm in the
  standard check is `hybrid-m0p25`: qacc is `0.837760`, essentially matching
  `base-default` (`0.837630`) while reducing candidate factor concentration
  (`factor_gap 2.859539` vs `3.154903`, `factor_max 5.928332` vs `6.333333`).
  This is lower-concentration limited mitigation, not a default promotion.
- h5-ao scales that hybrid comparison over `keys=64,128,256`, seeds `1..3`,
  and noisy rates `0.25/0.50`. `hybrid-m0p25` again preserves qacc
  (`0.886545` vs base `0.886458`) while lowering concentration
  (`factor_gap 3.247608` vs `3.596599`, `factor_max 5.968582` vs
  `6.333333`). The effect is real but tiny, so `basis=base` remains the safe
  default and `hybrid-m0p25` remains a guardrail/ablation arm.
- h5-ap runs the promotion check with `keys=64,128,256`, seeds `1..5`, and
  noisy rates `0.10/0.25/0.50`, comparing only `base-default` and
  `hybrid-m0p25`. The result is an exact qacc tie (`0.885747` each), while
  hybrid lowers concentration and wrong strength. This makes `hybrid-m0p25` a
  safe lower-concentration alternative, but not a default promotion.
- h5-aq adds `--route-quality-candidate-weight-basis auto`,
  `--route-quality-candidate-weight-auto-factor-max`, and
  `--route-quality-candidate-weight-auto-top-share`. The auto policy keeps the
  base basis unless a query's candidate-weight concentration exceeds the
  thresholds, then switches that query to the `hybrid-m0p25` basis. In the
  standard check over `keys=64,128,256`, seeds `1..3`, and noisy rates
  `0.25/0.50`, `auto-f6p0-t0p72` reaches qacc `0.886502`, lowers factor
  gap/max to `3.477531/5.968582`, lowers wrong strength to `6.173549`, and
  uses the hybrid branch on `0.440365` of query summaries. This is
  concentration-aware policy instrumentation, not a default promotion.
- h5-ar extends the same runner with `--auto-threshold` and
  `--auto-threshold-smoke` to sweep concentration thresholds. `f5.8/t0.70`
  turns into always-hybrid, `f6.0/t0.72` and `f6.2/t0.74` are the balanced
  lower-concentration arms, and `f6.4/t0.76` is the most selective arm. The
  latter has the highest tiny qacc (`0.886632`) but does not lower factor max;
  keep `basis=base` as the default and use the threshold sweep diagnostically.
- h5-as adds auto-trigger decomposition metrics:
  `route_quality_candidate_weight_auto_factor_trigger_rate`,
  `route_quality_candidate_weight_auto_top_share_trigger_rate`,
  `route_quality_candidate_weight_auto_factor_max_probe_mean`, and
  `route_quality_candidate_weight_auto_top_share_probe_mean`. These metrics
  explain the h5-ar threshold behavior without changing route behavior:
  `f6.0/t0.72` and `f6.2/t0.74` are identical because the observed trigger
  distribution has no extra mass between those thresholds; `f6.4/t0.76`
  disables factor-triggered hybrid switching and keeps only the top-share
  trigger. This is diagnostics only.
- h5-at adds `--route-quality-candidate-weight-auto-trigger-mode
  any|factor|top-share` and `--auto-trigger` runner arms. `factor` mode
  switches exactly on the factor trigger, `top-share` mode switches exactly on
  the top-share trigger, and `any` preserves the previous behavior. The
  standard sweep shows factor-triggered switching is what lowers concentration,
  while top-share-only is mostly base-like and carries only the tiny qacc edge.
- h5-au adds `--auto-factor-threshold` runner arms for factor-only thresholds
  `5.6/5.8/6.0/6.2/6.4`. The threshold distribution is coarse: `5.6/5.8`
  behave identically, `6.0/6.2` behave identically, and `6.4` disables factor
  switching. This confirms factor-only auto is useful instrumentation, but not
  a default promotion.

## Build

```bash
cmake -S . -B build
cmake --build build -j
```

Optional ROCm/HIP scaffold build:

```bash
cmake -S . -B build-hip -DDLE_ENABLE_HIP=ON
cmake --build build-hip --target dmv02 hip_candidate_weight_parity -j
```

Runtime backend selection is explicit:

```bash
./build/dmv02 --backend cpu ...
./build-hip/dmv02 --backend hip --hip-device 0 ...
```

h9 is scaffold/parity only. It does not move string/KV parsing,
source-credit ledgers, update acceptance, RNG, route strength, or topology onto
GPU.

## Run

`v0.1` logs CSV to stdout by default:

```bash
./build/dmv01 --cycles 100 --N 256 > results/v01_smoke.csv
```

Or write directly to a file:

```bash
./build/dmv01 --cycles 100 --N 256 --csv results/v01_smoke.csv
```

The implemented `v0.1` reference includes:

- bounded-degree ring graph
- color-based block-asynchronous updates
- fixed synthetic per-node `h_table`
- local energy proposals with inertia
- tick gating
- stagnation-triggered Metropolis escape
- reservoir redistribution
- per-cycle CSV diagnostics

`v0.2-pre` supports:

- byte-level next-byte prediction on `counter`, `repeating-text`, or `--input` bytes
- two-channel nibble state initialized from input bytes
- shared field table `H[channel][input_byte][state]`
- local contrastive positive/negative updates
- diagnostics including `field_byte_acc`, `oracle1_acc`, and `field_margin`
- defaults tuned for the first correctness gate: `lambda_v = 0`, `mass_init = 0`

Baseline interpretation:

- `counter` with `lambda_v = 0` is the first locked correctness gate and should succeed strongly.
- Higher `lambda_v` values are expected to hurt `counter`; if they do, that confirms the stage default still needs tuning.
- `repeating-text` should show `field_byte_acc` below `oracle1_acc` but clearly above `byte_acc` during early and mid learning.
- For `v0.2-b`, the default weak-coupling run now lands around `field/joint/byte = 0.687500/0.687500/0.687500` on repeating text and keeps the `counter` gate at `1.000000/1.000000/1.000000`.
- The 5-seed default weak-coupling regression now averages `counter byte/field/joint = 0.999688/1.000000/1.000000` and `repeating-text byte/field/joint = 0.685625/0.681094/0.685703`.
- On the same 5-seed repeating-text regression, default weak coupling lifts `byte_acc` by `+0.177578` on average over the default no-coupling control.
- The tuned `proposal_count = 30` control is still useful when we want to isolate proposal coverage from coupling benefit. In that control setting, no coupling ends around `0.597656/0.597656/0.597656`, while weak coupling ends around `0.687500/0.687500/0.687500`.

Example:

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --lambda-v 0 \
  --csv results/counter_lv0.csv
```

Experiment helpers:

- `experiments/run_v02_counter.sh`
- `experiments/run_v02_ablation.sh`
- `experiments/run_v02_repeating.sh`
- `experiments/run_v02b_tuned.sh`
- `experiments/run_v02b_counter_compare.sh`
- `experiments/run_v02b_repeating_compare.sh`
- `experiments/run_v02b_counter_multiseed_compare.sh`
- `experiments/run_v02b_repeating_multiseed_compare.sh`
- `experiments/run_v03_routing_probe.sh`
- `experiments/run_v03_routing_fixture_compare.sh`
- `experiments/run_v03_state_code_compare.sh`
- `experiments/run_v03_static_routing_compare.sh`
- `experiments/run_v03_gap_gate_ablation.sh`
- `experiments/run_v03_gate_diagnostics.sh`
- `experiments/run_v03_adaptive_gate_ablation.sh`
- `experiments/run_v03_confidence_gate_ablation.sh`
- `experiments/run_v03_confidence_acceptance_ablation.sh`
- `experiments/summarize_v03_routing_slice.sh`
- `experiments/run_v03_input_byte_jump_compare.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `experiments/run_v03_rejection_diagnostics.sh`
- `experiments/run_v03_route_hint_oracle.sh`
- `experiments/run_v03_route_hint_parsed.sh`
- `experiments/run_v03_route_hint_kv_exact.sh`
- `experiments/run_v03_route_hint_kv_hash.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_stress.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/run_v05_route_credit_plasticity.sh`
- `experiments/run_v05_route_source_credit.sh`
- `experiments/run_v05_route_source_credit_policy.sh`
- `experiments/run_v05_route_source_credit_noisy_source.sh`
- `experiments/run_v05_route_source_credit_noisy_scale.sh`
- `experiments/run_v05_route_source_credit_learned_source_stress.sh`
- `experiments/run_v05_route_source_credit_learned_source_scale.sh`
- `experiments/run_v05_route_source_credit_fallback_ablation.sh`
- `experiments/run_v05_route_source_credit_fallback_policy.sh`
- `experiments/run_v05_route_source_credit_fallback_quality.sh`
- `experiments/run_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_scale.sh`
- `experiments/run_v05_route_source_credit_bad_source_filter.sh`
- `experiments/run_v05_route_source_credit_retry_source.sh`
- `experiments/run_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/run_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/run_v05_route_source_credit_retry_policy.sh`
- `experiments/run_v05_route_candidate_quality_logdet.sh`
- `experiments/run_v05_route_quality_application.sh`
- `experiments/run_v05_route_quality_proxy_calibration.sh`
- `experiments/run_v05_route_quality_source_norm.sh`
- `experiments/run_v05_route_quality_candidate_apply.sh`
- `experiments/run_v05_route_quality_candidate_scale.sh`
- `experiments/run_v05_route_quality_candidate_saturation.sh`
- `experiments/run_v05_route_quality_candidate_boundary.sh`
- `experiments/run_v05_route_quality_candidate_high_beta.sh`
- `experiments/run_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/run_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/run_v05_route_quality_candidate_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_default.sh`
- `experiments/run_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_basis_policy.sh`
- `experiments/run_v05_route_quality_candidate_preset_regression.sh`
- `experiments/run_v05_route_quality_candidate_preset_policy.sh`
- `experiments/run_v05_route_quality_candidate_regression.sh`
- `experiments/run_v05_route_quality_candidate_level.sh`
- `experiments/run_v05_route_quality_candidate_composition.sh`
- `experiments/test_v03_route_hint_oracle.sh`
- `experiments/test_v03_route_hint_parsed.sh`
- `experiments/test_v03_route_hint_kv_exact.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/test_v05_route_credit_plasticity.sh`
- `experiments/test_v05_route_source_credit.sh`
- `experiments/test_v05_route_source_credit_policy.sh`
- `experiments/test_v05_route_source_credit_noisy_source.sh`
- `experiments/test_v05_route_source_credit_noisy_scale.sh`
- `experiments/test_v05_route_source_credit_learned_source_stress.sh`
- `experiments/test_v05_route_source_credit_learned_source_scale.sh`
- `experiments/test_v05_route_source_credit_fallback_ablation.sh`
- `experiments/test_v05_route_source_credit_fallback_policy.sh`
- `experiments/test_v05_route_source_credit_fallback_quality.sh`
- `experiments/test_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_scale.sh`
- `experiments/test_v05_route_source_credit_bad_source_filter.sh`
- `experiments/test_v05_route_source_credit_retry_source.sh`
- `experiments/test_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/test_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/test_v05_route_source_credit_retry_policy.sh`
- `experiments/test_v05_route_candidate_quality_logdet.sh`
- `experiments/test_v05_route_quality_application.sh`
- `experiments/test_v05_route_quality_proxy_calibration.sh`
- `experiments/test_v05_route_quality_source_calibration.sh`
- `experiments/test_v05_route_quality_source_norm.sh`
- `experiments/test_v05_route_quality_channel_scale.sh`
- `experiments/test_v05_route_quality_candidate_level.sh`
- `experiments/test_v05_route_quality_candidate_apply.sh`
- `experiments/test_v05_route_quality_candidate_scale.sh`
- `experiments/test_v05_route_quality_candidate_saturation.sh`
- `experiments/test_v05_route_quality_candidate_boundary.sh`
- `experiments/test_v05_route_quality_candidate_high_beta.sh`
- `experiments/test_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/test_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/test_v05_route_quality_candidate_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_default.sh`
- `experiments/test_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_promotion.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy_scale.sh`
- `experiments/test_v05_route_quality_candidate_basis_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_preset.sh`
- `experiments/test_v05_route_quality_candidate_preset_regression.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy_scale.sh`
- `experiments/test_v05_route_quality_closure.sh`
- `experiments/test_v06_route_memory_span_boundary.sh`
- `experiments/test_v06_route_memory_span_exact.sh`
- `experiments/test_v06_route_memory_span_exact_scale.sh`
- `experiments/test_v06_route_memory_span_hash.sh`
- `experiments/test_v06_route_memory_span_hash_scale.sh`
- `experiments/test_v06_route_memory_span_ambiguity.sh`
- `experiments/test_v06_route_memory_span_learned_source.sh`
- `experiments/test_v06_route_memory_span_quality_diagnostics.sh`
- `experiments/test_v06_route_memory_span_candidate_quality_gap.sh`
- `experiments/test_v06_route_memory_span_prefix_ranking.sh`
- `experiments/test_v06_route_memory_span_key_support_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_scale.sh`
- `experiments/test_v06_route_memory_span_local_energy_composition.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy_scale.sh`
- `experiments/test_v07_goal_route_memory_closure.sh`
- `experiments/test_v05_route_quality_candidate_auto_basis.sh`
- `experiments/test_v05_route_quality_candidate_auto_threshold.sh`
- `experiments/test_v05_route_quality_candidate_auto_trigger.sh`
- `experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh`
- `experiments/test_v05_route_quality_candidate_composition.sh`
- `experiments/test_v05_route_quality_candidate_regression.sh`

Key docs:

- [Master Prompt](DISCRETE_MANIFOLD_MASTER_CODEX_PROMPT.md)
- [Architecture Plan](docs/DISCRETE_MANIFOLD_ARCHITECTURE_PLAN_A_TO_Z.md)
- [v0.1 Design](docs/DESIGN_V01.md)
- [v0.2-pre Design](docs/DESIGN_V02_PRE.md)
- [v0.2-b Results](docs/V02B_RESULTS.md)
- [v0.2-b Decision Boundary](docs/V02B_DECISION_BOUNDARY.md)
- [v0.2-b 5-Seed Protocol](docs/V02B_MULTI_SEED_PROTOCOL.md)
- [v0.3 Routing Probe](docs/V03_ROUTING_PROBE.md)
- [v0.3 Static Routing Slice](docs/V03_STATIC_ROUTING.md)
- [v0.3 Route-Hint Oracle](docs/V03_ROUTE_HINT_ORACLE.md)
- [v0.6 / h6 Route Memory](docs/V06_ROUTE_MEMORY.md)
- [v0.7 / h7 Goal Closure](docs/V07_GOAL.md)
- [h9 ROCm/HIP Backend Scaffold](docs/V09_GPU_BACKEND.md)
- [Roadmap](docs/ROADMAP.md)

## Previous Korean README

# discrete-local-energy 한국어 README

[English README](README.md)

이 저장소는 단계적으로 확장 중인 deterministic C++17 이산 local-energy 연구 프로토타입입니다.

**아티팩트 경계:** 이 패키지는 휴먼 리뷰를 거친 릴리스가 아니라, 자동 검증 가능한 연구 아티팩트입니다.

## v1.0 Architecture Challenge 로드맵

다음 공개 타이밍은 v0.3의 넓은 공개 주장이 아니라 v1.0 Architecture Challenge입니다. 목표는 RouteMemory + RouteHint를 30B-150B급 LLM+RAG baseline과 code/doc QA, grounded generation, scaling, one-command reproducibility에서 정면 비교하는 것입니다.

로드맵: [docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md](docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md)

SSD-resident MoE runtime 구현 방향: [docs/V61_SSD_RESIDENT_MOE_RUNTIME.md](docs/V61_SSD_RESIDENT_MOE_RUNTIME.md). 이 트랙은 RAM offload가 아니라 NVMe SSD에 수백B-수T급 open-weight 모델 warehouse를 두고, 이산노드 라우팅 + MoE active sparsity + predictive prefetch + mixed quantization으로 로컬 PC의 활성 계산/VRAM 예산 안에 넣는 연구 방향입니다. v52s/v52u/v52v/v52w 계열을 v61의 weight-page runtime seed로 재정렬하며, v52-v60 release/comparison claim은 계속 별도 gate로 둡니다.

공식 v61 entrypoint 표면:

- 전체 smoke 목록: [`pipelines/v61.yaml`](pipelines/v61.yaml)
- 단계별 claim boundary: [`v61/one_token_path.json`](v61/one_token_path.json)
- operator/review-return contract: [`operations/review_return_workflow.json`](operations/review_return_workflow.json)
- pipeline migration 메모: [`docs/PIPELINE_MIGRATION.md`](docs/PIPELINE_MIGRATION.md)
- PR #2 review-slice 계획: [`docs/PR2_SPLIT_PLAN.md`](docs/PR2_SPLIT_PLAN.md)

현재 v61 증거는 README의 긴 stage 나열이 아니라 contract로 요약합니다. 허용되는 공개 문구는 다음입니다.

- v61은 SSD-resident MoE runtime R&D 트랙이며, SSD-resident real model runtime claim이 아닙니다.
- tensor-page read, dtype/quant probe, PyTorch matvec parity는 제한된 증거일 뿐입니다.
- expert FFN parity, MoE block parity, one-token logits parity, 16-token decode, cold/warm cache metric, SSD bytes/token, miss/token, TPS, actual generation, production latency, near-frontier quality, public comparison, release readiness는 contract artifact가 통과하기 전까지 blocked입니다.
- checkpoint payload와 큰 generated artifact는 기존 artifact contract가 명시적으로 추적하지 않는 한 git 밖에 둡니다.

README stage 목록 대신 다음 reviewer entrypoint를 사용합니다.

```bash
tools/verify_artifact.py pr-split pr_slices/pr2.json
tools/verify_artifact.py v61-one-token v61/one_token_path.json \
  --v61aa-summary results/v61aa_hotset_tensor_slice_verifier_summary.csv \
  --v61ab-summary results/v61ab_hotset_tensor_tile_quant_probe_summary.csv
tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json \
  --v53s-summary results/v53s_complete_source_review_return_intake_summary.csv \
  --v58d-summary results/v58d_blind_review_return_intake_summary.csv \
  --v61af-summary results/v61af_checkpoint_warehouse_operator_bundle_summary.csv \
  --v61hv-summary results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv
```

## v0.3 Architecture Preview

로컬 evidence-bound codebase audit preview를 실행합니다.

```bash
./scripts/audit_my_repo.sh /path/to/repo --emit-report --emit-lineage --emit-reproduce
./scripts/run_local_scaling_matrix.sh /path/to/repo
```

공개용 showcase bundle:

```bash
./examples/local_codebase_intelligence_box.sh /path/to/repo
```

검증:

```bash
./experiments/test_v0_3_architecture_preview.sh
./experiments/test_v0_3_completion_audit.sh
```

이 preview는 `RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation / abstain / audit trail` 경로를 보여줍니다. Transformer 대체, frontier local LLM, GPU speedup proof, production release 주장은 아닙니다.

## 최신 완료 체크포인트

- 현재 브랜치 `codex/route-memory-local-energy-policy`는 v0.3 Architecture Preview 사용자-facing audit surface, v51 Real-return Evidence Intake measured workload trace, v50 Public Repo Auditor 3-repo evidence run, v49 RULER NIAH 200/500-row scale, v48 Multi-Domain RouteHint Generator evidence, v47 Offline Domain Policy Update, v46 Source-Verified Scorer mainline, v45 LongBench v2 small slice, v44 Tiny Non-Attention Generator Hint smoke, v43 Doc-Code Conflict Detection audit, v42 Codebase Auditor 200-query demo, v41 RULER NIAH 50-row scale, v40 machine-verified research artifact, v39 human review dispatch archive, v38 human review dispatch bundle, v37 human review intake verifier, v36 release-claim audit packet, v35 commercial pilot packet, v34 official benchmark expansion packet, v33 evidence-closure packet, v32 GitHub Actions third-party rerun kit, v31 official RULER NIAH candidate return, v30 commercial codebase QA closed-corpus PoC return, v29 receiver-side return preflight kit, v28 inbound return inbox, v27 external send archive, v26 external send bundle, v25 outbound send manifest, v24 external handoff send/receive/verify packet, v23 official benchmark reconciliation kit, v22 clean-machine execution kit, v21 external review dispatch kit, v20 external return tracker, v19 external submission bundle, v18 supplied external evidence intake verifier, v17 post-v16 externalization handoff, v16 research/commercial split packet, v15 independent reproduction/review mechanics, v14 runner-owned query/result/evaluator 계열, v13 real-evidence/source-acquisition 계열, h10 source-verified scorer gate, v08-at external benchmark official result reconciliation checkpoint, h11-d PC RouteLM diagnostic NLG smoke checkpoint, h9-h diagnostic CPU/HIP/NVMe workload speed evidence gate, h7-c promotion review gate, v12 paper/release claim audit까지 최신입니다.
- h10-j가 route-memory teacher-source hash/provenance verifier로 닫혔습니다. 새 verifier는 teacher source artifact, label export, teacher identity, teacher policy, license, provenance, sha256 hash chain을 검사합니다. 기본 no-env 실행은 여전히 blocked이고, supplied external-label CSV는 label import까지만 통과하며 source evidence 없이는 distillation을 열 수 없습니다. supplied local source fixture는 chain mechanics를 검증하지만 `real_teacher_source_verified=0`, `distillation_ready=0`, `default_promotion=0`을 유지합니다. `results/` 밖을 포함한 모든 local `file://` URI는 declaration flag만 바꿔도 real teacher-source evidence가 되지 않도록 막았습니다.
- h10-k가 최신 local learned chunk-quality scorer gate로 닫혔습니다. h10-f local teacher-label harness에서 deterministic `linear-contrastive-chunk-v1` scorer를 맞추고, correct chunk evidence는 보상하고 coherent wrong/noisy/missing feature는 slash합니다. Smoke에서는 reward와 negative action을 분리합니다(`learned_score_gap=3.064325`, `coherent_wrong_negative_rate=1.000000`). 하지만 label source가 여전히 `local-teacher-harness`이므로 `external_label_source_ready=0`, `distillation_ready=0`, `default_promotion=0`입니다.
- h10-l이 source-verified learned scorer binding gate로 닫혔습니다. learned chunk-quality feature label이 supplied/non-local이고, teacher_id가 source evidence와 연결되며, external teacher-label row와 `source_uri`/`provenance_hash` 단위로 row-bound 되어 있고, h10-j real teacher-source verification을 통과해야 `source_verified_learned_chunk_scorer_ready=1`이 됩니다. 기본/local label, provenance 없이 relabel한 local row, external-label row mismatch는 계속 blocked입니다(`source_verified_feature_labels_ready=0`, `source_verified_learned_chunk_scorer_ready=0`). supplied local source fixture는 feature label을 연결할 수 있지만 `real_teacher_source_verified=0`에서 막힙니다.
- h10-m이 remote teacher-source acquisition contract로 닫혔습니다. 기본 no-env는 blocked이고, local `file://` source package는 local-or-placeholder로 분류됩니다. HTTPS remote source package는 URI/hash/acquisition/review contract readiness까지 통과할 수 있지만, h10-m 단독으로는 `real_teacher_source_verified=0`에서 멈춥니다.
- h10-n이 remote teacher-source content verifier로 닫혔습니다. HTTPS h10-m acquisition package를 supplied local download/cache 파일과 묶고 source/export/identity/policy/license/review 6개 sha256 hash를 모두 검증합니다. matching cache package는 `remote_teacher_source_content_ready=1`까지 갈 수 있지만, 그 위에 h10-o fetch-attestation과 runtime fetcher evidence가 붙기 전까지 `real_teacher_source_verified=0`, action `remote-teacher-source-live-fetch-missing`을 유지합니다.
- h10-o가 remote teacher-source live-fetch attestation contract로 닫혔습니다. h10-n content와 artifact-level fetch-attestation row 6개를 대조하고, HTTPS attestation URI, attestation cache hash, fetch metadata, independent attestor flag를 요구합니다. Remote-style package는 `remote_teacher_source_live_fetch_attestation_ready=1`까지 갈 수 있지만, runner-owned live fetch path 전까지 `real_teacher_source_verified=0`, action `remote-teacher-source-runtime-fetcher-missing`을 유지합니다.
- h10-p가 runner-owned runtime-fetcher contract로 닫혔습니다. h10-o fetch-attestation evidence에서 runner-owned offline replay manifest를 만들고 fetcher binary/command/stdout/stderr hash와 downloaded cache hash를 검증해 `runner_owned_runtime_fetcher_ready=1`까지 갈 수 있습니다. 하지만 실제 network fetch가 replay를 대체하기 전까지 `live_network_fetch_ready=0`, `real_teacher_source_verified=0`, action `remote-teacher-source-live-network-fetch-missing`을 유지합니다.
- h10-q가 live-network import evidence gate로 닫혔습니다. h10-p offline replay는 network evidence가 아니라고 거절하고, supplied six-row live-network runtime evidence package만 `remote_teacher_source_live_network_import_ready=1`까지 올립니다. 그래도 real source import/review chain이 붙기 전까지 `real_teacher_source_verified=0`, action `remote-teacher-source-real-source-import-missing`을 유지합니다.
- h10-r이 real teacher-source import/review chain gate로 닫혔습니다. h10-q live-network import readiness 위에서 supplied import/review CSV를 소비하고, source/export/identity/policy/license/import-manifest/review/reviewer/conflict/registry HTTPS URI, sha256 hash, live-import observation, independent/authoritative review flag, registry readiness, real/non-fixture declaration, routing/jump 0을 요구합니다. Local `file://` review artifact는 `real-teacher-source-local-import-artifact`로 막고, placeholder authority는 `real-teacher-source-placeholder-import-artifact`로 막습니다. Non-placeholder review chain은 `real_teacher_source_import_review_ready=1`까지 갈 수 있지만, official authority가 없으므로 `real_teacher_source_verified=0`, action `real-teacher-source-official-authority-missing`을 유지합니다.
- h10-s가 source-verified learned chunk scorer evaluation gate로 닫혔습니다. h10-l source-verified scorer binding, h10-r import/review readiness, 그리고 선택적 `V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV` student-only 평가표를 묶습니다. 기본 no-env는 `source-verified-feature-labels-missing`에서 막히고, supplied source-linked fixture는 `student_only_eval_ready=1`, positive `chunk_exact_delta`, `near_miss_negative_rate=1.000000`, `metric_improvement_ready=1`까지 계산하지만 h10-l/h10-r이 official real teacher-source authority를 갖지 못했으므로 `source_verified_learned_chunk_scorer_eval_ready=0`을 유지합니다.
- h7 route-memory closure는 h7-c까지 포함한 최신 상태입니다. 여전히 `default_promotion=0`, `status=diagnostic-only`, `routing_trigger_rate=0`, `active_jump_rate=0`입니다. 즉 chunk-credit와 learned scorer의 positive result는 guarded diagnostic route-memory policy이지 default sparse-routing policy가 아닙니다.
- v08-aa는 external-benchmark source-acquisition/content boundary로 닫혔습니다. v08-m부터 v08-w까지는 source-import contract, live verifier/review, authoritative review, public registry, live registry query, fetch/cache, live-registry network proof, real verification, official source authority를 연결하고, v08-x는 result/leaderboard authority layer, v08-y는 publication-package layer입니다. v08-z는 RULER, LongBench, codebase retrieval, real document QA의 official source acquisition package를 요구하고, v08-aa는 그 acquisition URI/hash manifest를 supplied source landing, dataset, benchmark card, split manifest, license, metric spec cache file과 바인딩합니다. Matching cache content는 `external_benchmark_source_acquisition_content_ready=1`까지 갈 수 있지만 source import/result/review/publication chain이 연결되기 전까지 `real_external_benchmark_verified=0`입니다.
- v08-ab는 첫 codebase-mini benchmark instrumentation layer로 닫혔습니다. 실제 local repository file 4개를 `codebase-retrieval` artifact package로 묶고, `source_manifest.json`, `dataset.jsonl`, split/license/metric spec, BM25/symbolic/RouteMemory baseline, result artifact, `sha256sums.txt`를 생성한 뒤 h11-c RouteMemory store와 연결합니다. Smoke는 query 7개, artifact hash 10개, `span_exact=1.000000`, `chunk_exact=1.000000`, `missing_abstain=1.000000`, `wrong_answer_rate=0.000000`, `routing_trigger_rate=0`, `active_jump_rate=0`을 확인합니다. 단 local codebase instrumentation은 independent external benchmark review/publication chain이 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ac는 codebase-retrieval slice의 source-content to result-artifact bridge로 닫혔습니다. Supplied bridge는 v08-aa source acquisition/content row와 v08-ab codebase-mini artifact directory를 묶고 result/baseline/dataset/run/evaluator hash 5개를 검증해 `codebase_content_result_bridge_ready=1`까지 갈 수 있습니다. 그래도 benchmark family coverage가 1/4이고 codebase artifact가 local이므로 `external_benchmark_result_bridge_ready=0`, `real_external_benchmark_verified=0`을 유지합니다.
- v08-ad는 all-family external benchmark result bridge contract로 닫혔습니다. RULER, LongBench, codebase-retrieval, real-document-qa의 supplied non-local bridge row가 v08-aa source-content acquisition ID로 되묶이고, source-content summary hash를 확인하며, result/baseline/dataset/run/evaluator/result-authority/publication URI 28개가 모두 HTTPS와 sha256 attestation을 갖는지 검증해 `family_result_bridge_review_ready=1`, `external_benchmark_result_bridge_ready=1`까지 올릴 수 있습니다. 그래도 현재 row는 supplied mechanics이지 independent reproduction 또는 publishable official benchmark evidence가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ae는 v08-ad 위의 independent reproduction/review contract로 닫혔습니다. 네 benchmark family의 supplied non-local reproduction row가 v08-ad result bridge로 되묶이고, result artifact와 bridge-summary hash를 검증하며, reproduction/report/run-log/reviewer/conflict/environment/metric URI 28개가 모두 HTTPS와 sha256 attestation을 갖는지 확인해 `independent_reproduction_review_ready=1`까지 올릴 수 있습니다. 그래도 현재 reproduction row는 supplied review mechanics이지 official release evidence나 externally verifiable benchmark publication이 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-af는 v08-ae 위의 official release evidence contract로 닫혔습니다. 네 benchmark family의 supplied release row가 independent reproduction ID와 v08-ae summary hash로 되묶이고, release/reproduction hash field 44개와 release package/manifest/archive/version/license/reproducibility/review/index/authority HTTPS URI 40개를 검증해 `official_release_evidence_ready=1`까지 올릴 수 있습니다. 그래도 현재 release row는 supplied mechanics이지 live externally verified release/publication record가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ag는 v08-af 위의 live release verification contract로 닫혔습니다. 네 benchmark family의 supplied live-verification row가 v08-af release ID, reproduction ID, official release/archive/dataset/authority URI+hash pair로 되묶이고, live verification/report/network-observation/verifier HTTPS URI와 sha256 hash field 28개를 검증해 `official_release_live_verification_ready=1`까지 올릴 수 있습니다. 그래도 현재 row는 supplied live-verification mechanics이지 runner가 직접 확인한 canonical online confirmation이 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ah는 v08-ag 위의 canonical online confirmation contract로 닫혔습니다. 네 benchmark family의 supplied confirmation row가 v08-ag live verification report, network observation, verifier identity, release ID, reproduction ID로 되묶이고, live/canonical confirmation, runner-network transcript, TLS, DNS, HTTP-header, content-digest HTTPS URI와 sha256 hash field 36개를 검증해 `canonical_online_confirmation_ready=1`까지 올릴 수 있습니다. 그래도 현재 row는 supplied confirmation mechanics이지 non-fixture publication/result review record가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ai는 v08-ah 위의 publication/result review contract로 닫혔습니다. 네 benchmark family의 supplied review row가 v08-ah canonical confirmation report, content-digest manifest, release ID, reproduction ID로 되묶이고, review/result/publication/authority HTTPS URI와 sha256 hash field 36개를 검증하며, 새로 들어온 review artifact URI 28개는 non-placeholder HTTPS여야 합니다. 이 경계는 `publication_result_review_ready=1`까지 올릴 수 있지만 live-ingested non-fixture result/publication record나 promotion evidence가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-aj는 v08-ai 위의 live publication/result ingestion contract로 닫혔습니다. 네 benchmark family의 supplied ingestion row가 v08-ai publication/result review 및 record URI/hash pair로 되묶이고, ingestion/review URI/hash field 52개와 response-header, content-digest, TLS certificate-chain을 포함한 새 live-ingestion artifact URI 40개를 검증하며, runner-owned live-network ingestion 및 digest-match declaration을 요구합니다. 이 경계는 `live_publication_result_ingestion_ready=1`까지 올릴 수 있지만 실제 non-fixture benchmark publication/result authority evidence나 promotion evidence가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ak는 v08-aj 위의 authority/promotion evidence contract로 닫혔습니다. 네 benchmark family의 supplied authority row가 v08-aj live publication/result record와 content digest로 되묶이고, authority/ingestion URI/hash field 52개와 registry, leaderboard, reproducibility package, archive, identity, conflict, promotion trace, final claim packet을 포함한 새 authority artifact URI 40개를 검증하며, independent/official/registry/consistency/limited-claim declaration을 요구합니다. 이 경계는 `authority_promotion_evidence_ready=1`까지 올릴 수 있지만 실제 독립 관측된 external benchmark run/evaluator evidence가 아니므로 `real_external_benchmark_verified=0`을 유지합니다.
- v08-al는 v08-ak와 v08-ab 위의 첫 run/evaluator trace layer로 닫혔습니다. codebase-mini artifact의 local `codebase-retrieval` dataset/result를 다시 조인해 runner/evaluator manifest, query trace, evaluator output, recomputed metrics, command receipt, sha256 manifest를 만들고, trace artifact hash 6개, query row 7개, metric match 5개, routing/jump 0을 검증합니다. 이 경계는 `codebase_run_evaluator_trace_ready=1`까지 올릴 수 있지만 coverage가 local codebase family 1/4이고 independent all-family evaluator evidence가 없으므로 `external_benchmark_run_evaluator_trace_ready=0`, `real_external_benchmark_verified=0`을 유지합니다.
- v08-am는 v08-al 위의 independent all-family run/evaluator evidence contract로 닫혔습니다. RULER, LongBench, codebase-retrieval, real-document-qa 네 family의 supplied evidence row가 non-placeholder HTTPS trace/run/evaluator/metric/query/observer/authority artifact, sha256 hash, 최소 query volume, quality threshold, proof binding, independent evaluator declaration, routing/jump 0을 갖는지 검증합니다. 이 mechanics는 `external_benchmark_independent_run_evaluator_evidence_ready=1`까지 올릴 수 있지만 live replay/final review가 supplied evidence를 대체하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-an은 v08-am 위의 live replay/final-review contract로 닫혔습니다. 네 benchmark family의 supplied review row가 v08-am evidence와 replay/final-review artifact URI/hash, replay query volume, metric threshold, live replay declaration, independent final-review declaration, fixture declaration, routing/jump 0을 묶습니다. 이 mechanics는 `external_benchmark_live_replay_final_review_ready=1`까지 올릴 수 있지만 public non-fixture verification 또는 runner-owned direct external run이 증명되기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ao는 v08-an 위의 public non-fixture/direct-run verification contract로 닫혔습니다. 같은 네 benchmark family의 supplied verification row가 v08-an review evidence를 40개 non-placeholder HTTPS public/direct-run artifact URI, 40개 sha256 hash, query volume, metric threshold, public registry/non-fixture declaration, direct runner-owned run/dataset/evaluator/network declaration, third-party reviewer declaration, fixture declaration, routing/jump 0과 묶습니다. 이 mechanics는 `external_benchmark_public_nonfixture_verification_ready=1`까지 올릴 수 있지만 runner-owned live execution/audit가 receipt를 실제로 증명하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ap는 v08-ao 위의 runner-owned live execution/audit contract로 닫혔습니다. 네 benchmark family의 supplied audit row가 v08-ao verification evidence를 52개 non-placeholder HTTPS live execution/audit artifact URI, 52개 sha256 hash, query volume, metric threshold, runner-owned execution declaration, live network/dataset fetch declaration, runner-invoked evaluator declaration, replay-disabled declaration, audit log 및 third-party audit declaration, fixture declaration, routing/jump 0과 묶습니다. 이 mechanics는 `external_benchmark_runner_owned_live_execution_audit_ready=1`까지 올릴 수 있지만 independent live rerun confirmation이 runner-owned audit receipt를 증명하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-aq는 v08-ap 위의 independent live rerun confirmation contract로 닫혔습니다. 네 benchmark family의 supplied confirmation row가 v08-ap audit evidence를 60개 non-placeholder HTTPS rerun-confirmation artifact URI, 60개 sha256 hash, rerun query volume, metric threshold, metric-delta bound, independent runner/environment declaration, live network/dataset refetch/evaluator rerun declaration, audit receipt reconciliation, metric recomputation, third-party confirmation declaration, fixture declaration, routing/jump 0과 묶습니다. 이 mechanics는 `external_benchmark_independent_live_rerun_confirmation_ready=1`까지 올릴 수 있지만 supplied confirmation mechanics를 real non-fixture benchmark run package로 대체하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-ar는 v08-aq 위의 real nonfixture run package intake contract로 닫혔습니다. 네 benchmark family의 supplied package row가 v08-aq confirmation evidence를 60개 non-placeholder HTTPS run-package artifact URI, 60개 sha256 hash, packaged query volume, metric threshold, metric-delta bound, nonfixture/official benchmark/public archive/raw query/raw output/evaluator container/immutable archive declaration, license/PII/third-party reproducibility review, fixture declaration, routing/jump 0과 묶습니다. 이 mechanics는 `external_benchmark_real_nonfixture_run_package_intake_ready=1`까지 올릴 수 있지만 live package artifact fetch와 authority verification이 supplied package mechanics를 대체하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-as는 v08-ar 위의 live package artifact fetch/authority verification contract로 닫혔습니다. 네 benchmark family의 60개 family/artifact entry가 fetched artifact, fetch receipt, authority record URI/hash pair와 묶이고, 180개 non-placeholder HTTPS URI, 180개 sha256 hash, HTTP-200 check, content-digest match, v08-ar package-intake binding, runner-owned live fetch, network/TLS/DNS/HTTP declaration, authority registry/official source authority declaration, fixture declaration, routing/jump 0을 요구합니다. 이 mechanics는 `external_benchmark_live_package_artifact_fetch_authority_ready=1`까지 올릴 수 있지만 official result reconciliation이 supplied fetch/authority mechanics를 대체하기 전까지 `real_external_benchmark_verified=0`을 유지합니다.
- v08-at는 v08-as 위의 official result reconciliation contract로 닫혔습니다. 네 benchmark family의 supplied reconciliation row가 v08-as에서 fetch된 official leaderboard, metric report, submission receipt, evaluator config, raw prediction output, package-registry artifact를 URI/hash identity로 직접 대조하고, 28개 non-placeholder HTTPS URI, 28개 sha256 hash, package identity match, metric-delta tolerance, query-count match, evaluator/digest/official-source/leaderboard/runner declaration, fixture declaration, routing/jump 0을 요구합니다. 이 mechanics는 `external_benchmark_official_result_reconciliation_ready=1`까지 올릴 수 있지만 `real_external_benchmark_verified=0`을 유지합니다. 다음 경계는 새 v08 layer가 아니라 real-run binder / nonfixture runner입니다.
- v13-a는 첫 real-run binder manifest로 닫혔습니다. 하나의 hash-manifested run directory가 h11-c store artifacts, h11-d NLG transcript/result, h9-h workload rows, v08-al run/evaluator trace, h10-s scorer/teacher evidence, v12 claim-audit input을 `results/v13_real_run_binder_manifest*_runs/<run_id>/` 아래에 묶습니다. Smoke는 generated diagnostic input에서 `real_run_binder_manifest_ready=1`을 확인하고 corrupted run manifest가 block되는지도 검증하지만, `actual_nonfixture_run_verified=0`, `real_pc_routelm_nlg_verified=0`, `real_external_benchmark_verified=0`, `real_workload_speed_evidence_ready=0`, `real_release_package_ready=0`, `gpu_speedup_claim=deferred`를 유지합니다.
- v13-b는 RouteLM mmap reader boundary로 닫혔습니다. v13 run directory의 `store/chunk_pages.bin`을 mmap reader로 열고 `route_index -> page_table -> byte span` window, route key, chunk offset, run/store sha256 manifest를 검증합니다. Hash는 맞지만 expected span 의미가 틀린 corruption도 block합니다. Smoke는 generated diagnostic input에서 `routelm_mmap_reader_ready=1`을 확인하지만 actual nonfixture, real PC RouteLM artifact, real external benchmark, real release flag는 모두 `0`입니다.
- v13-c는 evidence packet ABI로 닫혔습니다. Bound run manifest, store file, mmap reader summary, NLG transcript/result, workload row, benchmark trace/evaluator output, h10-s scorer evidence, v12 input을 `evidence_packet.csv`와 `claim_matrix_input.csv`로 정규화하고 packet hash 및 claim-source reference를 검증합니다. Smoke는 `evidence_packet_abi_ready=1`까지 확인하지만 learned chunk ranking은 block으로 남기고 actual nonfixture, real PC RouteLM artifact/NLG, real external benchmark, real speed, real release, GPU speedup claim은 계속 `0` 또는 `deferred`입니다.
- v13-d는 real NLG transcript binding boundary로 닫혔습니다. `nlg/transcript.jsonl`과 `nlg/result_summary.json`을 파싱하고 각 transcript row를 `store/route_index.bin` 및 mmap-readable `store/chunk_pages.bin` span byte와 다시 대조해 hash-manifested `transcript_binding.csv`를 만듭니다. Smoke는 `v13_real_nlg_transcript_ready=1`까지 확인하고 hash-clean wrong grounding도 block하지만 `real_nlg_transcript_ready=0`, `real_pc_routelm_nlg_verified=0`, real external/release flag는 계속 `0`입니다.
- v13-e는 public codebase RouteQA binding boundary로 닫혔습니다. v13 run의 benchmark runner manifest를 따라 local codebase-mini package를 열고 trace/package/source hash, dataset/result/query/evaluator row 7개, metric recompute를 검증해 `routeqa_rows.csv`를 만듭니다. Smoke는 `public_codebase_routeqa_ready=1`까지 확인하고 hash-clean evaluator lie도 막지만, 이 경계는 local codebase instrumentation이므로 `independent_external_routeqa_verified=0`, `real_external_benchmark_verified=0`, real release flag는 계속 `0`입니다.
- v13-f는 resource envelope boundary로 닫혔습니다. `speed/workload.csv`를 v13 run에 묶고 workload의 NLG/timing/environment artifact hash, run NLG result hash, CPU/HIP/NVMe/query/token/RAM/VRAM metric envelope를 검증해 `resource_rows.csv`를 만듭니다. Smoke는 `resource_envelope_ready=1`까지 확인하고 hash-clean speedup 제거를 막지만, real HIP/NVMe/nonfixture trace가 없으므로 `real_workload_speed_evidence_ready=0`, `gpu_speedup_claim=deferred`, real release flag는 계속 blocked입니다.
- v13-g는 real evidence promotion gate로 닫혔습니다. v13-c/v13-d/v13-e/v13-f binding과 h10-s/h11-d/h9-h/v08 run evidence를 함께 소비해 네 가지 약점에 대한 `promotion_rows.csv`를 만들고, real external benchmark, source-verified learned scorer, real NLG, real GPU speed, nonfixture run evidence가 같은 run에 묶일 때까지 `real_evidence_promotion_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-h는 same-run real evidence intake gate로 닫혔습니다. external benchmark, learned chunk ranking, GPU speedup, real NLG 네 row짜리 intake package를 v13-g promotion packet에 맞춰 검증하고, run-id binding, cache hash, HTTPS source/review/authority URI, contract flag, routing/jump 0을 확인합니다. Live-network verification과 regenerated bound-run evidence가 없으므로 `candidate_real_evidence_intake_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-i는 real evidence live-network gate로 닫혔습니다. v13-h intake evidence 위에서 source/review/authority network receipt를 소비하고, receipt hash, HTTPS final URI, HTTP status, live-network declaration, routing/jump 0을 검증합니다. Supplied fixture receipt는 계약만 검증하며, runner-owned runtime live fetch와 regenerated bound run이 없으면 `candidate_real_evidence_live_network_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-j는 real evidence rebind gate로 닫혔습니다. v13-i receipt evidence와 same-run replacement artifact를 소비해 receipt-hash replay, rebuilt artifact hash, claim-matrix hash, regeneration flag, routing/jump 0을 검증합니다. Runtime live fetch evidence와 regenerated promotion row가 없으면 `candidate_real_evidence_rebind_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-k는 runtime fetch provenance gate로 닫혔습니다. v13-j 위에서 v13-i receipt JSON을 다시 열어 runtime receipt scope/weakness/kind binding, HTTPS original/final URI, HTTP status, method, headers, empty error, UTC timestamp order, receipt hash, routing/jump 0을 검증합니다. Receipt JSON 모양이 맞아도 `runtime-live-fetch` 출처가 아니면 `runtime_fetch_provenance_ready=0`, `candidate_real_evidence_runtime_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-l은 source seed gate로 닫혔습니다. 현재 public source seed와 real claim evidence를 분리합니다. External benchmark row는 RULER/LongBench 공개 출처 seed를 묶을 수 있지만 learned chunk ranking, GPU speedup, real NLG는 `project-source-only`로 남습니다. 따라서 `source_seed_contract_ready=1`은 가능하지만 네 row 모두 official/independent claim evidence와 runtime live fetch receipt를 갖기 전까지 `candidate_real_evidence_source_seed_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-m은 source seed live-fetch gate로 닫혔습니다. v13-l seed packet과 선택적 runner-owned live receipt를 소비해 seed packet hash, receipt file coverage, receipt JSON scope/weakness/kind binding, HTTPS final URI, HTTP status, method, headers, empty error, UTC timestamp order, routing/jump 0을 검증합니다. 하지만 네 weakness row의 source/review/authority receipt가 모두 있고 underlying claim evidence가 real일 때까지 `source_seed_live_fetch_receipt_ready=0`, `candidate_real_evidence_source_live_fetch_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v13-n은 external benchmark official source acquisition gate로 닫혔습니다. v13-m/v13-l source seed를 소비하고, 선택적 live full mode에서 RULER, LongBench, RULER arXiv authority를 runner-owned 방식으로 취득합니다. Live full은 repo HEAD receipt 2개와 HTTP authority receipt 1개로 `external_benchmark_official_source_acquisition_ready=1`까지 갈 수 있지만, 실제 benchmark query/result/evaluator evidence가 없으므로 `candidate_external_benchmark_result_ready=0`, `real_release_package_ready=0`을 유지합니다.
- v14-a는 추가 evidence gate가 아니라 첫 runner-owned query/result/evaluator 실행 경로입니다. `tools/routelm_benchmark_run`이 `public-codebase-routeqa-v1` query를 materialize하고, v13 source-chain row를 `source/`에 복사하고, `--source-acquisition`만 주어진 경우 sibling `source_seed_live_fetch_rows.csv`와 `runtime_fetch_provenance_rows.csv`를 자동 발견할 수 있으며, official repo HEAD source snapshot을 `source/source_snapshot_rows.csv`에 바인딩하거나 live-fetch할 수 있고, `--repo-from-source-snapshot`으로 fetched snapshot 자체를 query repo로 사용할 수 있습니다. 실행기는 `route_memory_store.bin`/`route_index.bin`/`chunk_offsets`/`store_manifest.csv`가 포함된 mmap RouteMemory store, `dataset/dataset_manifest.json`, raw prediction/`predictions/prediction_status.json`/evaluator output/`evaluator/evaluator_status.json`/`metrics.json`/`routeqa_rows.csv`/`benchmark/benchmark_rows.csv`/`evidence_packet.csv`/`evidence/run_invocation.json`/`evidence/requested_outputs_manifest.json`/`evidence/run_layout_manifest.json`/`evidence/objective_requirements_manifest.json`, `evidence/official_source_acquisition_rows.csv` 등 evidence source-chain CSV mirror, `evidence/execution_chain_manifest.json`, `promotion_rows.csv`/run-level `sha256sums.txt` hash manifest를 `results/v14_real_query_result_evaluator_runner*_runs/` 아래에 씁니다. Focused smoke는 built-in query와 supplied `--queries`를 모두 확인하고, direct CLI smoke는 `source_seed_live_fetch_autodiscovered=1`, `runtime_fetch_provenance_autodiscovered=1`, `source_chain_autodiscovery_ready=1`을 확인하며, live snapshot test는 v13-n RULER HEAD를 checkout한 뒤 그 official snapshot 위에서 세 개 RouteQA row를 실행해 `repo_source=runner-owned-source-snapshot`을 남깁니다. `--emit-ruler-synthetic-smoke`는 RULER-compatible NIAH artifact와 official RULER evaluator/`scripts/data/prepare.py` 실행을 남기고, `--emit-longbench-v2-smoke`는 live `longbench_repo` snapshot 위에서 LongBench v2 multiple-choice schema row 6개와 official `result.py` aggregation을 남기고, `--emit-longbench-v2-official-sample`은 canonical LongBench v2 dataset-server row 12개를 fetch해 non-oracle lexical baseline을 같은 official aggregator로 평가한 뒤 `benchmark/longbench_v2/official_sample_store/` 아래 `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, `mmap_read_rows.csv`로 official sample row와 baseline prediction을 mmap 검증합니다. RULER generated row도 `benchmark/ruler_synthetic/official_generator_store/` 아래 `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, `mmap_read_rows.csv`를 통해 mmap 검증을 받습니다. 이 official-source row들은 run-level `benchmark/external_benchmark_rows.csv`로 정규화되고 `benchmark/external_benchmark_metrics.json`으로 집계되며 `benchmark/external_benchmark_manifest.json`에 sha256으로 묶이고, `benchmark/external_benchmark_execution_chain_manifest.json`에서 source acquisition부터 dataset, prediction, evaluator, metrics, provenance, mmap artifact까지 row별로 다시 묶입니다. Live smoke는 `external_benchmark_rows=5`, `external_benchmark_dataset_rows=27`, `external_benchmark_mmap_read_rows=21`, `external_benchmark_mmap_prediction_match_rows=21`, `external_benchmark_mmap_verification_ready_rows=4`, `external_benchmark_execution_chain_ready_rows=5`, `external_benchmark_execution_chain_ready=1`, `external_benchmark_average_score=66.67`, `external_benchmark_metrics_ready=1`, `external_benchmark_manifest_ready=1`, `runner_owned_external_benchmark_result_ready=1`, `prediction_status_ready=1`, `evaluator_status_ready=1`, `requested_outputs_manifest_ready=1`, `requested_outputs_ready=1`, `run_layout_manifest_ready=1`, `run_layout_ready=1`, `objective_requirements_manifest_ready=1`, `objective_requirements_ready=1`, `source_chain_evidence_mirror_ready=1`, `source_chain_autodiscovery_ready=1`, `execution_chain_manifest_ready=1`, `run_invocation_ready=1`, `official_ruler_generator_mmap_verification_ready=1`, `official_ruler_generator_mmap_read_rows=9`, `longbench_v2_official_sample_mmap_verification_ready=1`, `longbench_v2_official_sample_mmap_read_rows=12`, `evidence_packet_rows=50`까지 확인하지만 `candidate_external_benchmark_result_ready=0`은 유지합니다. 현재 환경에 없는 `nltk`, `wonderwords`, `tiktoken`, NeMo manifest utility는 run-local dependency shim으로 제공하고, RULER `prepare.py` 내부 shell command의 공백 경로 문제를 피하려고 `/tmp` 아래 공백 없는 symlink workspace에서 실행합니다. RULER generated smoke는 `oracle_prediction_used=0`, `extracted_prediction_rows=9`, 평균 score `77.78`까지 도달하고, LongBench v2 aggregation은 6-row schema smoke에서 `longbench_v2_score=100.00`까지, official dataset-server baseline sample에서 `longbench_v2_official_sample_rows=12`, `longbench_v2_official_sample_score=0.00`, `longbench_v2_official_sample_mmap_prediction_match_rows=12`까지 도달합니다. 그래도 run-local shim/synthetic row를 쓰는 runner-owned evidence이지 independent RULER/LongBench benchmark result가 아니므로 `real_external_benchmark_verified=0`, release blocked를 유지합니다.
- v14-a는 repo-level `routelm_benchmark_run` wrapper와 `evidence/reproducibility_manifest.json`도 제공합니다. 여기에는 shell-quoted direct runner command와 runner, source-acquisition CSV, query file, 자동 발견된 source-chain CSV hash가 기록됩니다. `evidence/run_layout_manifest.json`은 `source/`부터 dataset, mmap store, prediction, evaluator, metrics, benchmark, evidence, resource, promotion artifact까지 실제 output tree를 따로 검증하고, `evidence/objective_requirements_manifest.json`은 official source acquisition부터 promotion rows까지 objective 경로를 단계별로 감사하고, `evidence/official_source_acquisition_rows.csv` mirror로 문서화된 직접 실행 명령 모양을 지원합니다. Direct canonical-query smoke는 bare `routelm_benchmark_run`을 `PATH`로 호출하고 `reproducibility_manifest_ready=1`, `direct_cli_shape_ready=1`, `source_chain_autodiscovery_ready=1`, `requested_outputs_ready=1`, `run_layout_ready=1`, `objective_requirements_ready=1`을 검증합니다.
- v14-b-lite는 v14-a 위의 local prediction-lineage proof로 구현됐습니다. `tools/routelm_benchmark_run`은 `predictions/prediction_lineage.jsonl`, `predictions/prediction_source_summary.json`, mmap/candidate trace, RouteMemory prediction evidence row, 50-row RouteQA-mini lightweight benchmark, Stage 8.2-L shortcut/corruption negative row, `nlg/` 아래 tiny generator-hint NLG row와 grounding evidence, CPU-canonical RX 6900XT/32GB/500GB-lite resource envelope를 낼 수 있습니다. `experiments/test_v14b_lite_prediction_lineage.sh`는 `prediction_lineage_ready=1`, `no_extractor_prediction_ready=1`, `promoted_prediction_rows == promoted_route_memory_prediction_rows`, `shortcut_negative_suite_ready=1`, `generator_hint_nlg_ready=1`, `resource_envelope_ready=1`을 검증하고 real external benchmark/release flag는 계속 blocked로 둡니다.
- v14-c는 v14-b-lite 위의 baseline-comparison boundary로 구현됐습니다. `experiments/test_v14c_baseline_comparison.sh`는 같은 50-row package와 shortcut negative 위에서 input extractor, BM25/lexical retrieval, RouteMemory retrieval-only, RouteMemory exact value read, RouteMemory plus proposal hint, tiny generator-hint NLG를 비교합니다. `benchmark/baseline_comparison_rows.csv`, `benchmark/baseline_negative_case_rows.csv`, `metrics/baseline_comparison_metrics.json`, `resource/baseline_latency_rows.csv`, `promotion/baseline_promotion_guard_rows.csv`를 내고 `route_memory_safety_dominates_baselines=1`, `input_extractor_baseline_only=1`을 검증하며 external benchmark/release flag는 계속 blocked로 둡니다.
- v14-d는 v14-c 위의 RouteQA-mini 100/150 row scale boundary로 구현됐습니다. `experiments/test_v14d_routeqa_mini_scale.sh`는 `experiments/run_v14d_routeqa_mini_scale.sh`로 두 target size를 모두 실행하고, dataset/query/lineage/NLG row count가 정확히 늘어나는지, v14-b/v14-c의 negative-suite, baseline-comparison, resource-envelope, run-layout, objective, execution-chain contract가 모두 유지되는지, 각 run manifest가 scale artifact를 hash-bind하는지 검증하며 candidate external benchmark와 release flag는 계속 blocked로 둡니다.
- v14-e는 v14-d 위의 RULER NIAH-lite runner-owned smoke로 구현됐습니다. `experiments/test_v14e_ruler_niah_lite.sh`는 RULER-compatible NIAH row를 만들고, `benchmark/ruler_synthetic/compatible_niah_store/` 아래 RouteMemory mmap store에서 prediction을 읽어 compatible benchmark/metrics/provenance row로 묶은 뒤, runner-owned external benchmark row 1개와 execution-chain binding을 검증합니다. Candidate external benchmark, real external benchmark, release flag는 계속 blocked로 둡니다.
- v15-a는 v14-b/v14-c/v14-d/v14-e 위의 independent reproduction mechanics package로 구현됐습니다. `experiments/test_v15a_independent_reproduction_package.sh`는 v14 boundary output을 재생성하고, `results/v15a_independent_reproduction_package/package_001/` 아래 `REPRODUCE.sh`, expected summary/decision CSV, frozen query set, source snapshot row/manifest, resource envelope, run sha256 manifest, artifact manifest, environment manifest, failure mode, non-claim note를 묶으며 candidate external benchmark와 release flag는 계속 blocked로 둡니다.
- v15-b는 v15-a 위의 nonfixture review / independent rerun evidence mechanics로 구현됐습니다. `experiments/test_v15b_nonfixture_review_independent_rerun.sh`는 v15-a package hash, reviewer identity, rerun environment, reproduce command stdout/stderr hash, expected-vs-rerun summary copy, metric delta row, pass/fail review row를 `results/v15b_nonfixture_review_independent_rerun/review_001/` 아래에 묶습니다. 아직 runner-owned local review package이므로 external independent reviewer, candidate external benchmark, real external benchmark, release flag는 계속 blocked입니다.
- v16은 v15-b 위의 research/commercial split track packet으로 구현됐습니다. `experiments/test_v16_research_commercial_tracks.sh`는 `results/v16_research_commercial_tracks/packet_001/` 아래 research publication packet, research evidence matrix, claim boundary matrix, commercial local QA/audit prototype contract, commercial acceptance row, artifact manifest, v16 manifest를 묶습니다. Research publication track과 commercial local QA/audit prototype contract는 ready로 올리지만 candidate external benchmark, real external benchmark, release flag는 계속 blocked입니다.
- v17은 post-v16 externalization handoff로 구현됐습니다. `experiments/test_v17_post_v16_externalization_handoff.sh`는 `results/v17_post_v16_externalization_handoff/package_001/` 아래 third-party rerun, official benchmark reconciliation, commercial closed-corpus local QA/audit PoC 세 intake track을 분리하고 command, schema, required artifact row, acceptance criteria를 준비합니다. 실제 외부 artifact가 들어오기 전까지 `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, release flag는 계속 blocked입니다.
- v18은 v17 위의 supplied external evidence intake verifier로 구현됐습니다. `experiments/test_v18_external_evidence_intake.sh`는 외부 증거가 없을 때 모든 actual/candidate flag가 blocked로 남는 기본 경로를 검증하고, `experiments/test_v18_external_evidence_intake_with_fixtures.sh`는 synthetic supplied-evidence fixture를 넣었을 때 verifier가 해당 intake flag를 올릴 수 있음을 검증합니다. 실제 readiness는 `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, `V18_COMMERCIAL_POC_DIR`로 non-fixture directory가 들어와야만 의미가 있습니다.
- v19는 v18 위의 external submission bundle로 구현됐습니다. `experiments/test_v19_external_submission_bundle.sh`는 `results/v19_external_submission_bundle/bundle_001/` 아래 third-party rerun, official benchmark reconciliation, commercial local evidence-bound QA/audit 제출 packet, v18 intake command, track row, artifact hash, `docs/POST_V18_RESEARCH_ROADMAP.md` 로드맵을 묶습니다. 제출 준비 flag만 올리고 `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, `real_external_benchmark_verified=0`, `real_release_package_ready=0`은 계속 blocked로 둡니다.
- v20은 v19/v18 위의 external return tracker로 구현됐습니다. `experiments/test_v20_external_return_tracker.sh`는 `results/v20_external_return_tracker/tracker_001/` 아래 track별 required return file, blocker row, next action, tracker manifest, artifact hash를 묶습니다. `V20_THIRD_PARTY_RERUN_DIR`, `V20_OFFICIAL_BENCHMARK_DIR`, `V20_COMMERCIAL_POC_DIR`로 반환 디렉터리를 v18 verifier에 넘길 수 있지만, 기본 no-return 경로에서는 actual rerun, candidate benchmark, commercial PoC, real benchmark, release flag를 의도적으로 blocked로 유지합니다.
- v21은 v20 위의 external review dispatch kit로 구현됐습니다. `experiments/test_v21_external_review_dispatch_kit.sh`는 `results/v21_external_review_dispatch_kit/dispatch_001/` 아래 reviewer-facing request, packet index, return directory layout, return template copy, verification command, tracker summary, source manifest, artifact hash를 묶습니다. 세 갈래 handoff를 외부 리뷰어에게 보낼 수 있는 형태로 만들지만, non-fixture return directory가 들어오기 전까지 actual rerun, candidate benchmark, commercial PoC, real benchmark, release flag는 계속 blocked입니다.
- v22는 v21 위의 clean-machine execution kit로 구현됐습니다. `experiments/test_v22_clean_machine_execution_kit.sh`는 `results/v22_clean_machine_execution_kit/kit_001/` 아래 host/container clean-machine runbook, 최소 Containerfile, third-party rerun capture script, reviewer/environment template, official benchmark와 commercial PoC execution note, verification note, source manifest, artifact hash를 묶습니다. Capture script는 성공한 rerun 뒤 v15-b metric delta row와 review row를 자동으로 채우고, hosted clean-machine run을 위해 bounded `CAPTURE_TIMEOUT_SECONDS`와 start/finish diagnostic도 기록합니다. reviewer identity와 clean-machine independence는 외부 reviewer가 채워야 하는 필드로 남습니다. 실제 제3자 재실행 경로를 더 실행 가능하게 만들지만, v20/v18이 반환된 non-fixture evidence를 검증하기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v23은 v22 위의 official benchmark reconciliation kit로 구현됐습니다. `experiments/test_v23_official_benchmark_reconciliation_kit.sh`는 `results/v23_official_benchmark_reconciliation_kit/kit_001/` 아래 official-slice runbook, return directory layout, evaluator/container contract, no-oracle/no-raw-input-extractor contract, raw prediction과 RouteMemory lineage template, metrics/provenance/reproducibility template, return-file preflight script, v20 verification note, source manifest, artifact hash를 묶습니다. Candidate external benchmark 경로를 더 명확하게 만들지만, returned official evidence가 검증되기 전까지 candidate/real/release flag는 계속 blocked입니다.
- v24는 v21/v22/v18 위의 external handoff send/receive/verify packet으로 구현됐습니다. `experiments/test_v24_external_handoff_send_receive_verify.sh`는 `results/v24_external_handoff_send_receive_verify/handoff_001/` 아래 보낼 packet(`v21` dispatch kit + `v22` clean-machine kit), return inbox expectation, 직접 `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, `V18_COMMERCIAL_POC_DIR` 검증 command, handoff row, blocker, source manifest, artifact hash를 묶습니다. 실제 return directory가 들어오기 전까지 actual flag는 계속 blocked입니다.
- v25는 v24 위의 outbound send manifest로 구현됐습니다. `experiments/test_v25_outbound_send_manifest.sh`는 `results/v25_outbound_send_manifest/packet_001/` 아래 outbound `v21` dispatch kit와 `v22` clean-machine execution kit 전체 sha256 manifest, receiver acknowledgement template, return option, 직접 v18 verification instruction, source manifest, artifact hash를 묶습니다. 보낼 packet의 무결성을 검증하지만 실제 return directory가 들어오기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v26은 v25 위의 single external send bundle로 구현됐습니다. `experiments/test_v26_external_send_bundle.sh`는 `results/v26_external_send_bundle/bundle_001/` 아래 outbound v21 dispatch-kit와 v22 clean-machine-kit 파일을 하나의 send directory로 복사하고, bundle sha256 manifest, receiver integrity-check instruction, 직접 v18 return verification note, source manifest, artifact hash를 묶습니다. 외부로 보낼 단일 directory이며 실제 return directory가 들어오기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v27은 v26 위의 external send archive로 구현됐습니다. `experiments/test_v27_external_send_archive.sh`는 `results/v27_external_send_archive/archive_001/` 아래 v26 send bundle을 `archive/v26_external_send_bundle_bundle_001.tar.gz`로 묶고, archive sha256 sum, archive file listing, receiver archive/return verification note, source manifest, artifact hash를 남깁니다. 전송하기 쉬운 archive일 뿐이며 실제 return directory가 v18로 검증되기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v28은 v27/v18 위의 inbound return inbox로 구현됐습니다. `experiments/test_v28_inbound_return_inbox.sh`는 `results/v28_inbound_return_inbox/inbox_001/` 아래 third-party rerun, official benchmark, commercial PoC 반환 디렉터리 표준 위치, inbox manifest, v18 summary mirror, verifier hook을 묶습니다. 빈 placeholder directory는 supplied evidence로 v18에 넘기지 않으며, 실제 반환 파일이 들어와 v18 검증을 통과하기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v29는 v28 위의 receiver-side return preflight kit로 구현됐습니다. `experiments/test_v29_receiver_return_preflight.sh`는 `results/v29_receiver_return_preflight/preflight_001/` 아래 third-party rerun, official benchmark, commercial PoC 반환물의 필수 파일 completeness check, missing-file row, 기본 v28 inbox 경로, 직접 v18 검증 안내를 묶습니다. 이는 반환 전 사전점검 gate일 뿐이며, non-fixture return directory가 v18을 통과하기 전까지 actual/candidate/release flag는 계속 blocked입니다.
- v30은 v29/v18 위의 commercial codebase QA closed-corpus PoC return으로 구현됐습니다. `experiments/test_v30_commercial_codebase_poc_return.sh`는 `results/v30_commercial_codebase_poc_return/return_001/commercial_return/` 아래 domain/corpus manifest, source-bound query row, PoC result row, audit trail, resource envelope, privacy review, acceptance review를 묶습니다. v29는 commercial return을 complete로 보고 v18은 `closed_corpus_poc_actual_ready=1`을 검증합니다. Third-party rerun, official benchmark, real external benchmark, release flag는 계속 blocked입니다.
- v31은 v30/v18 위의 official RULER NIAH candidate return으로 구현됐습니다. `experiments/test_v31_official_ruler_niah_candidate_return.sh`는 `results/v31_official_ruler_niah_candidate_return/return_001/official_return/` 아래 현재 `NVIDIA/RULER` HEAD, upstream `scripts/data/prepare.py`, `scripts/eval/evaluate.py`, `README.md` hash, official source/evaluator status, raw prediction, RouteMemory prediction lineage, metrics, provenance, reproducibility, candidate result row를 묶습니다. v18은 `candidate_external_benchmark_result_ready=1`을 검증하며, `independent_rerun_actual_ready=0`, `real_external_benchmark_verified=0`, `real_release_package_ready=0`은 계속 blocked입니다.
- v32는 v31/v22/v18 위의 GitHub Actions third-party rerun kit로 구현됐습니다. `.github/workflows/third-party-rerun.yml`은 `ubuntu-24.04` GitHub-hosted runner에서 v22 capture script를 실행하고 GitHub Actions reviewer/environment provenance를 채운 뒤 v18로 검증하고 `actions/upload-artifact@v4`로 return directory를 업로드합니다. PR run `27029089994`의 `third-party-rerun-return` artifact를 내려받아 v31, v30과 함께 로컬 v18 intake에 넣었고, `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `closed_corpus_poc_actual_ready=1`, `real_external_benchmark_verified=1`을 검증했습니다. `real_release_package_ready=0`은 별도 release audit 전까지 유지합니다.
- v33은 v32/v31/v30/v18 위의 evidence-closure packet으로 구현됐습니다. `experiments/test_v33_evidence_closure_packet.sh`는 `results/v33_evidence_closure_packet/packet_001/` 아래 최신 GitHub Actions third-party return, v31 official candidate return, v30 commercial PoC return, v18 summary/decision을 복사하고 `sha256_manifest.csv`, `CLAIM_BOUNDARY.md`, `evidence_closure_manifest.json`, human-review 요청/템플릿을 묶습니다. Packet은 `v33_evidence_closure_packet_ready=1`을 검증하지만 `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v34는 v33/v31/v18 위의 official benchmark expansion packet으로 구현됐습니다. `experiments/test_v34_official_benchmark_expansion_packet.sh`는 `results/v34_official_benchmark_expansion_packet/packet_001/` 아래 v31 RULER NIAH candidate를 같은 4096-token context length에서 1개 raw prediction row에서 6개 row로 확장하고, official source/evaluator snapshot, RouteMemory lineage, metrics, candidate row, `EXPANSION_BOUNDARY.md`, `benchmark_expansion_manifest.json`, `sha256_manifest.csv`를 묶은 뒤 v34 official return과 v33 third-party/commercial evidence로 v18을 다시 검증합니다. Packet은 `v34_official_benchmark_expansion_packet_ready=1`, `candidate_external_benchmark_expansion_ready=1`, `real_external_benchmark_verified=1`을 확인하지만 `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v35는 v34/v33/v18 위의 commercial pilot packet으로 구현됐습니다. `experiments/test_v35_commercial_pilot_packet.sh`는 `results/v35_commercial_pilot_packet/packet_001/` 아래 v30 commercial return schema를 `internal_docs` buyer-visible workflow에 재사용하고, source-cited internal-docs QA row 5개와 release-claim abstain row 1개, privacy/resource/acceptance review, `COMMERCIAL_PILOT_BOUNDARY.md`, `commercial_pilot_manifest.json`, `sha256_manifest.csv`를 묶은 뒤 v33 third-party evidence, v34 official expansion, v35 commercial return으로 v18을 다시 검증합니다. Packet은 `v35_commercial_pilot_packet_ready=1`, `closed_corpus_poc_actual_ready=1`, `real_external_benchmark_verified=1`을 확인하지만 `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v36은 v33/v34/v35 위의 release-claim audit packet으로 구현됐습니다. `experiments/test_v36_release_claim_audit_packet.sh`는 `results/v36_release_claim_audit_packet/packet_001/` 아래 v33/v34/v35 evidence manifest와 summary를 복사하고, `claim_matrix.csv`, `evidence_input_rows.csv`, `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`, `human_review/HUMAN_REVIEW_REQUEST.md`, `human_review/human_review_template.csv`, `v36_release_claim_audit_manifest.json`, `sha256_manifest.csv`를 묶어 최대 허용 public wording을 결정합니다. Audit은 `v36_release_claim_audit_packet_ready=1`, `maximum_allowed_claim_decided=1`, `human_review_request_ready=1`을 확인하고, 허용 문구를 deterministic provenance, source-cited answer, conservative abstention, externally reproducible evidence packet을 가진 local evidence-bound QA/audit architecture로 제한합니다. `human_review_completed=0`, `real_release_package_ready=0`은 유지하며 release-ready product/general LLM replacement/Transformer replacement/frontier long-context/GPU acceleration claim은 계속 막습니다.
- v37은 v36 위의 human review intake verifier로 구현됐습니다. `experiments/test_v37_human_review_intake.sh`는 `results/v37_human_review_intake/intake_001/` 아래 v36 human-review 요청/템플릿을 복사하고, 반환된 `human_review_rows.csv`가 있으면 네 필수 review item, reviewer identity, timestamp, all-pass status를 정규화/검증해 `human_review_intake_manifest.json`, `normalized_human_review_rows.csv`, `missing_review_rows.csv`, `sha256_manifest.csv`를 씁니다. 현재 기본 실행은 `v37_human_review_intake_ready=1`을 확인하지만 `human_review_return_supplied=0`, `human_review_completed=0`, `real_release_package_ready=0`을 유지합니다. Smoke는 별도 fixture pass 경로도 검증하되 기본 no-return 상태를 바꾸지 않습니다.
- v38은 v37/v36 위의 human review dispatch bundle로 구현됐습니다. `experiments/test_v38_human_review_dispatch_bundle.sh`는 `results/v38_human_review_dispatch_bundle/bundle_001/` 아래 v36 review request, claim audit, claim matrix, decision rows, evidence-input rows, v36/v37 manifest, missing-review rows를 `review_packet/`에 복사하고, `return/human_review_rows.csv`, `verify/VERIFY_RETURN.sh`, `HUMAN_REVIEW_DISPATCH_README.md`, `human_review_dispatch_manifest.json`, `sha256_manifest.csv`를 준비합니다. Bundle은 `v38_human_review_dispatch_bundle_ready=1`, `return_template_ready=1`, `verify_script_ready=1`을 확인하지만 `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v39는 v38 위의 human review dispatch archive로 구현됐습니다. `experiments/test_v39_human_review_dispatch_archive.sh`는 `results/v39_human_review_dispatch_archive/archive_001/` 아래 v38 bundle을 `archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz`로 묶고, `archive/ARCHIVE_SHA256SUMS.txt`, `archive/ARCHIVE_FILE_LIST.txt`, `SEND_ARCHIVE_README.md`, `artifact_manifest.csv`, `human_review_dispatch_archive_manifest.json`, `sha256_manifest.csv`를 씁니다. Archive는 `v39_human_review_dispatch_archive_ready=1`, `archive_sha256_ready=1`, `archive_file_list_ready=1`, required review/return/verify member 존재를 확인하지만 `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v40은 v33-v39 위의 machine-verified research artifact로 구현됐습니다. `experiments/test_v40_machine_verified_research_artifact.sh`는 `results/v40_machine_verified_research_artifact/artifact_001/` 아래 v36 claim audit, v37 no-return intake 상태, v38 dispatch bundle evidence, v39 transfer archive evidence, v33/v34/v35 support summary를 복사하고, `MACHINE_VERIFIED_RESEARCH_ARTIFACT.md`, `release_mode_rows.csv`, `allowed_claim_rows.csv`, `blocked_claim_rows.csv`, `machine_verification_rows.csv`, `evidence_index.csv`, `v40_machine_verified_research_artifact_manifest.json`, `sha256_manifest.csv`를 씁니다. 여기서 여는 것은 `automated_research_artifact_ready=1` / `machine_verified_prototype_ready=1`뿐이며, `human_review_completed=0`, `human_review_required_for_public_release=1`, `real_release_package_ready=0`은 명시적으로 유지합니다.
- v41은 v34/v33/v18 위의 RULER NIAH 50-row 학계용 scale-up으로 구현됐습니다. `experiments/test_v41_ruler_niah_50row_scale.sh`는 `results/v41_ruler_niah_50row_scale/scale_001/` 아래 v34 expansion engine을 50 rows, 4096 context length로 실행하고, raw prediction row 50개, RouteMemory lineage row 50개, official evaluator/source reuse, no-oracle/no-extractor, v18 intake를 검증한 뒤 `V41_RULER_NIAH_50ROW_BOUNDARY.md`, `scale_rows.csv`, `v41_ruler_niah_50row_scale_manifest.json`, `sha256_manifest.csv`를 씁니다. `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v42는 v18 위의 Codebase Auditor 200-query 구매자 가시 산업 데모로 구현됐습니다. `experiments/test_v42_codebase_auditor_200query.sh`는 `results/v42_codebase_auditor_200query/audit_001/` 아래 tracked source hash와 line citation에 묶인 local repository QA/audit row 200개를 만들고, unsupported readiness/replacement claim에 대한 abstain row를 20개 이상 포함하며, v18 commercial-return schema의 `commercial_return/`, `V42_CODEBASE_AUDITOR_BOUNDARY.md`, `auditor_rows.csv`, `v42_codebase_auditor_manifest.json`, `sha256_manifest.csv`를 씁니다. Smoke는 `v42_codebase_auditor_200query_ready=1`과 `v18_closed_corpus_poc_actual_ready=1`을 검증하고, `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v43은 v42/v18 위의 Doc-Code Conflict Detection audit로 구현됐습니다. `experiments/test_v43_doc_code_conflict_detection.sh`는 `results/v43_doc_code_conflict_detection/detection_001/` 아래 v42 readiness evidence에서 implementation fact를 만들고, bounded doc-code conflict corpus에서 mismatch row 8개와 consistent row 4개를 doc/implementation source span과 함께 검증하며, `V43_DOC_CODE_CONFLICT_BOUNDARY.md`, `detection_case_rows.csv`, `conflict_rows.csv`, `source_span_rows.csv`, `v43_doc_code_conflict_manifest.json`, `sha256_manifest.csv`를 씁니다. Smoke는 v18 commercial-return verification도 통과시키며, `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v44는 v43/v18 위의 Tiny Non-Attention Generator Hint smoke로 구현됐습니다. `experiments/test_v44_tiny_non_attention_generator_hint.sh`는 `results/v44_tiny_non_attention_generator_hint/generator_001/` 아래 RouteHint payload row, raw prompt context byte가 0인 generator input row, grounded transcript row, missing-query abstain row를 만들고 v18 commercial return으로 검증합니다. Smoke는 `v44_tiny_non_attention_generator_hint_ready=1`, `no_raw_prompt_stuffing_ready=1`, `non_attention_generator_ready=1`, `answer_grounded_rate=1.000000`, `span_citation_accuracy=1.000000`, `wrong_answer_rate=0.000000`을 확인하며, `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v45는 v44/v18 위의 LongBench v2 small slice로 구현됐습니다. `experiments/test_v45_longbench_v2_small_slice.sh`는 `results/v45_longbench_v2_small_slice/slice_001/` 아래 THUDM/LongBench official source/evaluator file을 snapshot하고, LongBench v2 task category 6개에 걸친 multiple-choice raw prediction row 6개와 no-oracle/no-raw-input-extractor RouteMemory lineage row 6개를 만든 뒤 v18 official return으로 검증합니다. 여는 것은 `v45_longbench_v2_small_slice_ready=1` / `v18_candidate_external_benchmark_result_ready=1`뿐이며, `real_external_benchmark_verified=0`, `real_release_package_ready=0`은 유지합니다.
- v46은 v45/v18 위의 Source-Verified Scorer mainline으로 구현됐습니다. `experiments/test_v46_source_verified_scorer_mainline.sh`는 `results/v46_source_verified_scorer_mainline/scorer_001/` 아래 v45 official benchmark evidence에서 source-bound label row 12개를 만들고, local teacher-harness label 없이 deterministic candidate scorer를 학습/검증하며, scorer eval row 6개에서 `scorer_top1_accuracy=1.000000`, `ranking_improvement_ready=1`, `wrong_candidate_guard_ready=1`을 확인하고 v18 commercial-return intake를 통과합니다. `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v47은 v46/v18 위의 Offline Domain Policy Update로 구현됐습니다. `experiments/test_v47_offline_domain_policy_update.sh`는 `results/v47_offline_domain_policy_update/policy_001/` 아래 3개 도메인과 5개 learning target에 대한 offline policy row 15개를 만들고, candidate selection, span read, hint strength, abstain/retry, verifier decision row를 이전 evidence summary에 바인딩한 뒤 v18로 policy audit을 검증합니다. `expert_replacement_claim=0`, `release_ready_claim=0`, `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v48은 v47 이후 첫 evidence-scale generator 확장으로 구현됐습니다. `experiments/test_v48_multi_domain_generator_evidence.sh`는 `results/v48_multi_domain_generator_evidence/run_001/` 아래 `RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation/abstain/audit trail` 경로가 RULER NIAH, LongBench v2, codebase QA, internal docs QA에서 동시에 유지되는지 검증합니다. 24 generation row, abstain row 4개, hint raw context 0, raw prompt stuffing 0, grounding/citation 1.0, v18 commercial intake, `real_release_package_ready=0`을 확인합니다.
- v49는 v34/v33/v18 위의 fixed-context RULER NIAH 200/500-row 학계용 scale-up으로 구현됐습니다. `experiments/test_v49_ruler_niah_200_500_scale.sh`는 `results/v49_ruler_niah_200_500_scale/scale_001/` 아래 v34 expansion engine을 200 rows와 500 rows로 각각 실행하되 4096 context length와 architecture를 고정하고, raw prediction/RouteMemory lineage row count, official evaluator/source reuse, no-oracle/no-extractor, v18 intake, release blocking을 검증한 뒤 `V49_RULER_NIAH_200_500_BOUNDARY.md`, `scale_rows.csv`, `v49_ruler_niah_200_500_scale_manifest.json`, `sha256_manifest.csv`를 씁니다.
- v50은 v42/v43/v18 위의 Public Repo Auditor 3-repo evidence run으로 구현됐습니다. `experiments/test_v50_public_repo_auditor_3repo.sh`는 `pypa/sampleproject`, `psf/requests`, `pallets/click`를 pinned commit SHA로 checkout하고 requested ref/HEAD SHA/source hash/source span을 묶은 뒤 doc-code conflict, deprecated/legacy usage, config mismatch 3개 audit type에 걸친 9개 case를 독립 detector output으로 검증하고 v18 commercial return을 통과시킵니다. `human_review_completed=0`, `real_release_package_ready=0`은 유지합니다.
- v51은 v18/v40 위의 Real-return Evidence Intake measured trace로 구현됐습니다. `experiments/test_v51_real_return_evidence_intake.sh`는 tracked source file 위에서 CPU SHA-256 batch와 filesystem/NVMe-style read trace를 실제 측정하고, hash-bound trace artifact를 만들고, 세 개 cited QA/audit row를 v18로 검증하며, v40 machine-verified artifact ladder에 묶습니다. `v51_real_return_evidence_intake_ready=1`, `measured_workload_trace_bound=1`, `cpu_trace_rows=7`, `nvme_trace_rows=7`을 확인하지만 외부/구매자 return과 real teacher-source import는 아직 supplied가 아니고, `gpu_speedup_claim=deferred`, `real_release_package_ready=0`을 유지합니다.
- v0.3 Architecture Preview는 기존 evidence stack 위의 사용자-facing surface로 구현됐습니다. `scripts/audit_my_repo.sh`는 `AUDIT_REPORT.md`, JSONL/CSV finding, citation span, RouteMemory lineage, mmap read trace, compact RouteHint row, grounded generation row, abstain row, resource envelope, `reproduce.sh`를 냅니다. `scripts/run_local_scaling_matrix.sh`는 store/top-k/cache/RouteHint/query-count one-axis local scaling matrix를 냅니다. `examples/local_codebase_intelligence_box.sh`는 audit report, baseline comparison note, local scaling summary, architecture trace, lineage, citation, RouteHint, generation, hash manifest를 묶습니다. `experiments/test_v0_3_architecture_preview.sh`는 `v0_3_architecture_preview_ready=1`, `one_command_repo_audit_ready=1`, `local_scaling_matrix_ready=1`, `scaling_axis_count=5`, `scaling_curve_rows=27`, `baseline_war_ready=1`, `baseline_rows=8`, `routehint_generator_mainline_ready=1`, `raw_prompt_context_bytes=0`, `attention_blocks=0`, `transformer_blocks=0`, `oracle_prediction_used=0`, `raw_input_extractor_used=0`을 확인하며 `gpu_speedup_claim=deferred`, `real_release_package_ready=0`은 유지합니다.
- v41-v51 파급력 로드맵은 닫혔고, 추가 internal packaging layer 없이 evidence-scale/use-surface와 measured workload trace 단계를 완료했습니다. 다음 고파급 단계는 real external acceptance 또는 teacher-source authority evidence입니다: 외부/휴먼 또는 구매자 PoC acceptance와 실제 teacher-source import/review. Claim은 계속 local evidence-bound QA/audit assistance로 두고 Transformer replacement, frontier local LLM, GPU acceleration proven, long-context solved, expert replacement는 피합니다.
- 이 모드가 닫힌 뒤의 로드맵은 내부 mechanics 추가가 아니라 evidence review입니다. v40 machine-verified research artifact까지 닫혔으므로, human-reviewed release가 필요하면 `results/v39_human_review_dispatch_archive/archive_001/archive/`의 archive를 외부 리뷰어에게 보내고 returned `human_review_rows.csv`를 v37로 검증해야 합니다. 자세한 계획은 `docs/POST_V18_RESEARCH_ROADMAP.md`에 정리되어 있습니다.
- h9-g는 measured GPU speed evidence boundary로 닫혔습니다. CPU가 canonical이고, HIP는 optional/environment-dependent입니다. fixture timing evidence는 계속 `gpu_speedup_claim=deferred`를 유지합니다.
- h9-h는 h9-g와 h11-d 위의 diagnostic CPU/HIP/NVMe workload speed evidence gate로 닫혔습니다. Generated workload artifact는 NLG result, timing, environment hash, positive CPU/HIP ratio, NVMe read latency, query-to-evidence, query-to-first-token, tokens/sec, SSD/RAM/VRAM metric, routing/jump 0을 검증해 `diagnostic_workload_speed_ready=1`까지 갈 수 있지만 `real_workload_speed_evidence_ready=0`, `gpu_speedup_claim=deferred`를 유지합니다.
- h7-c는 h7-b, h10-r, h10-s, v08-ab, h11-d, h9-h 위의 promotion review gate로 닫혔습니다. Review contract, external/NLG/wrong-answer threshold, routing/jump 0은 통과하지만 real teacher-source, source-verified scorer eval, external benchmark, PC RouteLM NLG, workload-speed evidence가 모두 real로 닫히기 전까지 `real_evidence_complete=0`, `promotion_review_ready=0`, `default_promotion=0`을 유지합니다.
- v12는 h7-c, h10-r/h10-s, v08-ab, h11-c/h11-d, h9-h 위의 paper/release claim audit로 닫혔습니다. `diagnostic_release_package_ready=1`, `diagnostic_claim_level=4`까지는 올리지만 `real_release_package_ready=0`, `publishable_claim_level=0`, `release_claim=diagnostic-artifact-package-only`를 유지하고 Transformer replacement, frontier PC LLM, long-context solved, learned sparse routing, GPU acceleration claim을 모두 막습니다.
- h11-b가 현재 PC RouteLM / NLG artifact boundary입니다. 새 verifier는 generator, route-memory, scorer, decoder, NLG-smoke, benchmark, license, provenance artifact hash를 검사합니다. supplied local artifact fixture는 `prototype_artifact_chain_verified=1`로 chain mechanics를 검증하지만, `results/` 아래 local fixture URI와 declaration flag만으로는 `real_pc_routelm_artifact_verified=0`을 넘지 못합니다.
- h11-c가 현재 NVMe-resident RouteMemory artifact smoke입니다. `route_memory_store.bin`, `route_index.bin`, `chunk_pages.bin`, `chunk_offsets.bin`, `chunk_credit.bin`, `page_table.bin`, `manifest.json`, `sha256sums.txt` 묶음을 만들고 artifact hash, route lookup, candidate span read, routing/jump 0을 검증합니다. 이 경계는 `route_memory_artifact_chain_verified=1`까지 올릴 수 있지만 `real_pc_routelm_artifact_verified=0`, `real_external_benchmark_verified=0`은 유지합니다.
- h11-d가 diagnostic small-generator PC RouteLM NLG smoke로 닫혔습니다. h11-c store 위에서 smoke transcript/result artifact를 만들고 teacher-off inference, retrieved evidence usage, answer grounding, span citation accuracy, span/chunk exactness, missing abstain, wrong-answer rate, latency/SSD/RAM/VRAM metric, routing/jump 0을 검증합니다. Generated fixture는 `pc_routelm_nlg_smoke_ready=1`까지 갈 수 있지만 `real_pc_routelm_nlg_verified=0`은 유지합니다.
- 최신 검증 스택은 v14-a runner-owned query/result/evaluator focused test, v13-n live source acquisition row를 복사한 v14-a full run, v13-n external benchmark official source acquisition focused test, v13-n live source acquisition full run, v13-m source seed live-fetch focused test, v13-l source seed focused test, v13-k runtime fetch provenance focused test, v13-j real evidence rebind gate focused test, v13-i real evidence live-network gate focused test, v13-h real evidence intake gate focused test, v13-g real evidence promotion gate focused test, v13-f resource envelope focused test, v13-e public codebase RouteQA focused test, v13-d real NLG transcript binding focused test, v13-c evidence packet ABI focused test, v13-b RouteLM mmap reader focused test, v13-a real-run binder manifest focused test, v08-at official result reconciliation focused test, v08-as live package artifact fetch authority smoke, v08-ar real nonfixture run package intake smoke, v08-aq independent live rerun confirmation smoke, v08-ap runner-owned live execution/audit smoke, v08-ao public non-fixture verification smoke, v08-an live replay/final-review smoke, v08-am independent run/evaluator evidence smoke, v08-al run/evaluator trace smoke, v08-ak authority/promotion evidence smoke, v08-aj live publication/result ingestion smoke, h10-s source-verified scorer eval, h10-r real teacher-source import/review, h10 source-verified scorer, h10 distillation, h7-c promotion review, h7 goal closure, h11-c NVMe RouteMemory store/artifact smoke, h11-d PC RouteLM NLG smoke, h9-h workload speed gate, v12 paper/release claim audit, 그리고 v13-n까지 포함한 h9 quick closure입니다.

## 현재 열린 blocker

- Real external teacher-label source evidence가 h10-j verifier, h10-m acquisition contract, h10-n content-cache verifier, h10-o fetch-attestation contract, h10-p runtime-fetcher contract, h10-q live-network import gate, h10-r import/review chain, h10-s student-only scorer-evaluation gate를 통과해야 합니다. h10-r은 import/review contract를 검증하지만, real teacher-source claim에는 `real_teacher_source_verified=1`을 세우는 official authority/registry evidence가 추가로 필요합니다. h10-s도 scorer를 source-verified eval candidate로 올리려면 real/source-bound student-only chunk/span 평가 evidence가 필요합니다.
- Real external benchmark/source/result/review/publication evidence는 이제 real-run binder / nonfixture runner 경로로 들어와야 합니다. 하나의 실행이 raw run trace, evaluator output, source/result artifact, NLG transcript/result, workload/resource row, scorer/teacher evidence, v12 claim-matrix input을 같은 run directory에 채우기 전에는 external comparison을 publish할 수 없습니다.
- Real HIP-backed CPU/HIP/NVMe workload measurement가 fixture timing/workload row를 대체해야 GPU speedup claim을 할 수 있습니다.
- Real non-fixture generator-grounded PC RouteLM/NLG smoke는 아직 future work입니다. h11-d는 h11-c store 위의 diagnostic generated NLG smoke이지 working product claim이 아닙니다.
- Diagnostic artifact packaging보다 강한 paper/release claim은 h7-c와 v12를 real teacher-source, scorer eval, external benchmark, PC RouteLM NLG, workload-speed evidence로 다시 통과시키기 전까지 막혀 있습니다.

## 현재 한 줄 요약

현재 프로젝트는 **이산 local-energy learner + value-bearing route-hint memory** 연구 프로토타입으로 보는 것이 가장 정확합니다. v0.3에서 가장 강하게 확인된 결론은 장거리 정보가 `remote node as neighbor`로 들어오면 안 되고, `candidate value_pos -> value byte read -> proposal hint` 형태로 들어와야 한다는 점입니다.

아직 다음을 주장하는 단계는 아닙니다.

- learned sparse routing solved
- long-context retrieval solved
- wrong-candidate robustness solved
- Transformer replacement

현재 live path는 `candidate value_pos -> value byte read -> proposal hint` 경로이며, candidate discovery, identity preservation, hint strength, confidence, fallback, route credit을 분리해서 계측하는 단계입니다.

- h5-u는 candidate-quality logdet/channel/quality-score instrumentation으로 PASS했고, h5-v는 weak quality source-ranking application diagnostics / neutral-to-slight-regression으로 PASS했으며, h5-w는 source-quality calibration diagnostics로 PASS했고, h5-x는 proxy weight/sign calibration diagnostics / single-smoke limited mitigation으로 PASS했으며, h5-y는 channel-sign multi-seed/scale stability diagnostics / weak limited mitigation으로 PASS했고, h5-z는 source-normalization instrumentation / neutral diagnostics로 PASS했으며, h5-aa는 candidate-level quality diagnostics / actionable split으로 PASS했고, h5-ab는 weak bounded candidate-level quality application / limited mitigation으로 PASS했으며, h5-ac는 candidate-weight composition diagnostics / limited mitigation으로 PASS했고, h5-ad는 candidate-only beta/noise scale diagnostics / limited mitigation으로 PASS했으며, h5-ae는 candidate-weight saturation/cap diagnostics / limited mitigation으로 PASS했고, h5-af는 candidate-quality best-setting scale regression diagnostics / limited mitigation으로 PASS했으며, h5-ag는 candidate-quality over-sharpen boundary diagnostics / limited mitigation으로 PASS했고, h5-ah는 high-beta candidate-quality boundary diagnostics / limited mitigation으로 PASS했으며, h5-ai는 extreme-beta candidate-quality boundary diagnostics / limited mitigation으로 PASS했고, h5-aj는 ultra-beta candidate-quality plateau/boundary diagnostics / limited mitigation으로 PASS했으며, h5-ak는 candidate-quality guardrail selection diagnostics로 PASS했고, h5-al은 candidate-quality safe-default application diagnostics / limited mitigation으로 PASS했으며, h5-am은 candidate-feature basis calibration diagnostics로 PASS했고, h5-an은 hybrid candidate-basis calibration diagnostics / lower-concentration limited mitigation으로 PASS했으며, h5-ao는 hybrid candidate-basis guardrail scale diagnostics / lower-concentration limited mitigation으로 PASS했고, h5-ap는 hybrid candidate-basis promotion check / safe alternative diagnostics로 PASS했으며, h5-aq는 concentration-aware candidate-basis switching diagnostics / safe alternative instrumentation으로 PASS했고, h5-ar는 auto-threshold calibration diagnostics / safe alternative instrumentation으로 PASS했으며, h5-as는 auto-trigger decomposition diagnostics로 PASS했고, h5-at는 auto-trigger policy ablation diagnostics로 PASS했으며, h5-au는 factor-trigger threshold refinement diagnostics로 PASS했습니다. `route_quality_apply=source-ranking`은 soft bounded delta만 쓰며 noisy retry 선택은 `0.000000`으로 유지됩니다. `route_quality_apply=candidate-weight`는 route strength를 바꾸지 않고 후보 weight만 clamped relative factor로 약하게 sharpen합니다. `route_quality_apply=source-candidate`는 source-ranking과 candidate-weight를 같이 켭니다. h5-ak standard sweep(`keys=64,128,256`, seeds `1..5`, noisy source rates `0.10,0.25,0.50`)에서는 `beta=8, cap=8`이 더 안전한 guardrail 설정입니다. h5-al은 이 설정을 default arm으로 확인했고, `candidate-default` qacc는 `0.886429`, `proxy-off`는 `0.646962`, `source-candidate-default`는 `0.884896`입니다. h5-am은 `--route-quality-candidate-weight-basis base|quality-score`를 추가했고, feature-score basis는 연결됐지만 `base-default qacc=0.837630`보다 낮습니다(`feature-margin qacc=0.800000`). h5-an/h5-ao/h5-ap는 `hybrid` basis와 `--route-quality-candidate-weight-basis-mix`를 추가/확장했고, h5-aq부터 h5-au까지는 `--route-quality-candidate-weight-basis auto`와 concentration threshold 옵션을 추가/분해했습니다. h5-au에서 factor threshold는 거칠게 양자화됩니다. `5.6/5.8`은 같은 broad arm입니다(`auto_hybrid_rate=0.875304`, `factor_gap=3.241454`, `qacc=0.886328`). `6.0/6.2`는 같은 balanced arm입니다(`auto_hybrid_rate=0.315668`, `factor_gap=3.471377`, `qacc=0.886328`). `6.4`는 factor switching이 꺼져 base-like입니다(`auto_hybrid_rate=0.000000`, `factor_gap=3.596599`, `qacc=0.886458`). noisy source 선택, routing trigger, active jump는 계속 `0.000000`입니다. 따라서 이는 controlled route-hint fixture 내부의 bounded candidate-weight default/basis calibration이지 learned routing이나 robustness solved가 아닙니다.

## 현재 권장 기본 해석

- 기본 경로는 계속 `candidate value_pos -> value byte read -> proposal hint`입니다. quality proxy, source credit, candidate weight는 이 경로 위에서만 사용하며, `jump-neighbor` topology replacement는 부활시키지 않습니다.
- 현재 candidate-quality 기본값은 `--route-quality-apply candidate-weight`와 `--route-quality-candidate-weight-basis base`입니다. h5-au 기준 `base-default qacc=0.886458`로 여전히 가장 단순하고 안전한 기본값입니다.
- concentration을 낮춰야 할 때는 `hybrid-m0p25`를 안전한 대안으로 봅니다. qacc는 사실상 동률(`0.886545`)이고, factor concentration과 wrong strength를 base보다 낮춥니다.
- factor-only `auto` threshold는 diagnostic-only입니다. h5-au는 `5.6/5.8`, `6.0/6.2`, `6.4` threshold가 broad / balanced / base-like regime을 설명한다는 점을 보여줬지만, base default나 `hybrid-m0p25`를 성능 기준으로 넘지는 못했습니다.
- 따라서 현재 상태는 candidate-quality weighting과 basis calibration의 controlled fixture 성과입니다. learned routing solved, source-credit robustness solved, wrong-candidate robustness solved, fallback robustness solved, long-context retrieval solved로 주장하면 안 됩니다.
- 현재 route-memory checkpoint는 h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s, h7-b/h7-c, v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at, h11-a/h11-b/h11-c/h11-d, v12입니다. h10은 여전히 diagnostic/source-gated이고, v08-b부터 v08-at까지는 external benchmark evidence를 adapter/import/comparison에서 source acquisition, source-acquisition content cache verification, codebase-mini result instrumentation, source-content/result bridge, all-family result bridge mechanics, independent reproduction/review mechanics, official release evidence mechanics, live release verification mechanics, canonical online confirmation mechanics, publication/result review mechanics, live publication/result ingestion mechanics, authority/promotion mechanics, run/evaluator trace mechanics, independent all-family run/evaluator evidence mechanics, live replay/final-review mechanics, public non-fixture/direct-run verification mechanics, runner-owned live execution/audit mechanics, independent live rerun confirmation mechanics, real nonfixture run package intake mechanics, live package artifact fetch/authority mechanics, official result reconciliation mechanics, source-import contract, live verifier, independent live review, authoritative review, public-registry, live-registry-query, live-registry fetch/cache, live-registry network-proof, real-verification, official-authority, result-authority, publication-package mechanics까지 밀어 올리지만 placeholder, fixture authority, fixture acquisition/content, local codebase-mini instrumentation, 실제 독립 관측 benchmark run evidence 없는 supplied bridge/reproduction/release/live-verification/confirmation/review/ingestion/authority mechanics, independent all-family evidence 없는 local runner/evaluator trace, supplied independent all-family/replay/final-review/public direct-run/live-execution-audit/independent-rerun/package-intake/live-fetch-authority/official-result-reconciliation mechanics, unpublished comparison evidence에서는 `real_external_benchmark_verified=0`을 유지합니다. h11-a는 PC RouteLM / NLG prototype readiness contract를 열며, h11-b는 prototype artifact/provenance hash chain을 검증하되 local fixture를 real prototype으로 올리지 않고, h11-c는 다음 codebase benchmark/NLG layer가 쓸 수 있는 hash-verified NVMe RouteMemory store smoke를 만들며, h11-d는 그 store 위에 diagnostic NLG smoke를 붙이지만 real product claim은 하지 않습니다. v12는 이 전체 스택을 감사해 diagnostic artifact packaging만 허용합니다.
- h7-b promotion gate는 여전히 `default_promotion=0`, `status=diagnostic-only`이고, h7-c는 h10-r/h10-s/v08-ab/h11-d/h9-h를 함께 review해도 `promotion_review_ready=0`, `default_promotion=0`을 유지합니다. h10-a smoke는 `qacc=1.000000`, `chunk_exact=1.000000`, `coherent_wrong=0.000000`, `chunk_credit_gap=0.800000`까지 올라가고, 32/64-key scale guard에서도 `chunk_exact=0.960938`, `coherent_wrong=0.000000`, `keyshape_chunk_gap=0.000000`을 유지합니다. h10-b는 이 상태를 바로 promotion하지 않고 `weak-hint-with-abstain`으로 라우팅합니다. h10-c joint noisy gate는 `noisy_used=1.000000`, `noisy_selected=0.000000`을 유지하고, h10-d fallback exercise는 `raw-retry`로 `qacc 0.290000 -> 0.910000`, `fallback_retry_exercised=1`, `retry_noisy_selected=0.000000`을 확인합니다. h10-e/f/g/h/i/j/k/l/m/n/o/p/q/r/s는 contract, local collection, local learner, external ingestion schema, supplied-label import, teacher source verifier, learned chunk-quality scorer, row-bound source-verified scorer binding, remote acquisition contract, content-cache verifier, fetch-attestation contract, runtime-fetcher contract, live-network import contract, import/review chain contract, student-only source-verified scorer eval gate를 통과시킵니다. 기본 no-env 실행에서는 여전히 `distillation_ready=0`, reason `teacher-external-label-source-missing`이고, provenance 없이 relabel한 local row와 external-label row mismatch는 blocked입니다. supplied local source fixture는 chain mechanics와 positive eval delta를 검증하지만 `real_teacher_source_verified=0`, `source_verified_learned_chunk_scorer_eval_ready=0`이며, h10-r import/review readiness도 official authority 전에는 real source verified로 승격하지 않습니다. 그래서 `real_evidence_complete=0`, `default_promotion=0`은 유지됩니다.
- v08 external benchmark readiness는 promotion gate가 열릴 때까지 외부 benchmark comparison을 defer합니다. v08-b부터 v08-at까지는 adapter/evidence/import/comparison부터 official result reconciliation mechanics까지 readiness flag를 올릴 수 있지만 `real_external_benchmark_verified=0`을 유지합니다. 이제 active path는 v13입니다. Nonfixture runner가 source/result/evaluator artifact, raw trace, NLG transcript/result, workload row, scorer/teacher evidence, claim-matrix input을 하나의 run directory에 묶기 전에는 external comparison publish를 막습니다. h9-e는 CPU-canonical quick boundary에서 candidate-weight/proposal-score parity scaffold가 유지되는지 확인하며, HIP parity는 환경 의존 optional extended check입니다.
- h11-a는 quantized 3B-14B generator, CPU RAM/NVMe O(n) route memory, GPU candidate scoring, GPU decoder binding, NLG smoke URI를 supplied component evidence로 받을 수 있게 하고, h11-b는 그 구성요소의 local artifact hash-chain mechanics를 검증합니다. h11-c는 작은 NVMe-resident RouteMemory store artifact를 만들고 route lookup/candidate span read를 검증하며, h11-d는 그 store 위에서 diagnostic NLG transcript/result와 grounding/citation/wrong-answer metric을 확인합니다. 하지만 local/generated fixture는 `real_pc_routelm_artifact_verified=0`/`real_pc_routelm_nlg_verified=0`을 유지하고, default promotion, real benchmark comparison, real teacher-source distillation, measured GPU speed evidence, non-fixture generator-grounded NLG evidence가 없으면 `diagnostic-prototype-only`/diagnostic smoke입니다. 즉 real PC RouteLM / NLG solved는 아닙니다.
- h5-av는 이 결론을 key/noise cell별 policy CSV로 읽기 쉽게 만든 slice입니다. Smoke에서는 `base-default`와 `hybrid-m0p25` qacc가 `0.887500`으로 같고, `hybrid-m0p25`가 factor gap을 `3.650981 -> 3.304388`로 낮춰 `hybrid-m0p25-safe` 추천을 받습니다.
- h5-aw는 같은 policy summary를 9개 key/noise cell(`keys=64,128,256`, noisy rates `0.10,0.25,0.50`, seeds `1..5`)로 확장했습니다. 평균 qacc는 `0.885746 -> 0.885747`로 동률이고, factor gap은 `3.607673 -> 3.252902`, wrong strength는 `5.852729 -> 5.779043`으로 내려가며, 모든 cell에서 `hybrid-m0p25-safe` 추천이 나옵니다.
- h5-ax는 이 safe-alternative 결론을 regression guard로 고정합니다. `hybrid-m0p25`는 base 대비 qacc `0.001` 이내, factor gap 감소, factor max no-increase, aggregate wrong-strength no-regression, jump-neighbor 비활성 조건을 계속 통과해야 합니다.
- h5-ay는 `--route-quality-candidate-weight-preset none|base-default|hybrid-safe`를 추가해 긴 candidate-weight 옵션 묶음을 안전하게 줄입니다. Preset smoke에서 explicit 설정과 preset 설정이 metric 단위로 일치했고, `routing_trigger_rate = active_jump_rate = 0.000000`을 유지합니다.
- h5-az는 preset adoption을 작은 key/seed/noise matrix로 확장했습니다. 16개 row에서 explicit 설정과 preset 설정이 완전히 일치합니다(`equivalent_rate=1.000000`, 모든 metric delta `0.000000`). lookup/read는 살아 있고 jump-neighbor routing은 계속 비활성입니다.
- h5-ba는 preset 자체를 실험 arm으로 직접 비교합니다. 같은 작은 key/seed/noise matrix에서 `hybrid-safe`가 모든 row에서 추천됩니다. qacc는 `0.863281 -> 0.864258`, factor gap은 `3.440251 -> 3.118539`, factor max는 `6.333333 -> 6.049084`로 내려가며 jump-neighbor routing은 계속 비활성입니다.
- h5-bb는 h5-ba preset-policy matrix를 scale guardrail test로 고정합니다. 두 preset arm이 모두 있어야 하고, 모든 policy row가 `hybrid-safe`를 추천해야 하며, factor gap/max와 aggregate wrong strength가 악화되지 않고 `routing_trigger_rate = active_jump_rate = 0.000000`을 유지해야 합니다.
- h5-bc는 현재 route-quality stack을 닫는 closure smoke입니다. shell syntax, `dmv02` build, oracle route-hint, preset equivalence, preset policy smoke, preset policy scale guardrail을 한 번에 확인합니다. `--extended`는 route-code adaptive, preset regression, candidate-basis guardrail scale까지 추가로 확인합니다.
- h6-a는 route-memory phase를 여는 span-boundary diagnostic입니다. multi-byte fixture(`HELLO` / `WORLD`)에서도 현재 stack은 `kv_query_count = route_hint_query_count = 2`로 key당 첫 value byte 하나만 route hint로 노출합니다. 이는 span/chunk routing solved가 아니라 h6의 시작 경계를 명시하는 instrumentation입니다.
- h6-b는 exact KV용 `--route-span-hints 0|1`을 추가합니다. `--route-mode hint-kv-exact --route-span-hints 1`에서 같은 `HELLO` / `WORLD` fixture는 `kv_query_count = route_hint_query_count = 10`으로 확장되어 value-span offset마다 route hint를 가집니다. 경로는 여전히 value-bearing proposal hint이고 jump-neighbor routing은 비활성입니다.
- h6-c는 exact span scale diagnostics를 추가합니다. Smoke는 `key_count=2`, `value_len=5`에서 first-byte arm과 span arm을 비교하며, `--route-span-hints 1`에서 route hint query count가 `2 -> 10`으로 확장되고 exact hit/apply와 jump-neighbor 비활성을 유지합니다.
- h6-d는 hashed symbolic candidate에도 span hint를 확장합니다. `--route-mode hint-kv-hash --route-span-hints 1`에서 hash bucket entry가 span offset을 보존하고 query offset마다 같은 offset candidate만 비교합니다. Smoke는 `kv_query_count = route_hint_query_count = route_candidate_query_count = 10`, candidate recall/top1 `1.000000`, `routing_trigger_rate = active_jump_rate = 0.000000`을 확인합니다. 이는 controlled symbolic span-candidate routing이지 learned chunk retrieval은 아닙니다.
- h6-e는 span hash scale diagnostics를 추가합니다. 표준 matrix는 key count, value length, hash bits를 교차한 8개 row이며, offset-aware hash candidate가 `qacc_mean = recall_mean = top1_mean = 1.000000`, `collision_rate_mean = 0.000000`, jump-neighbor 비활성을 유지합니다. 이는 span-candidate scale guard이지 learned chunk retrieval은 아닙니다.
- h6-f는 span ambiguity / collision diagnostics를 추가합니다. `hash_bits=2`에서는 span bucket collision이 `1.000000`이 되고, `K_route=4`는 recall/top1/qacc가 `0.500000/0.125000/0.237500`으로 내려갑니다. `K_route=16`은 recall을 `1.000000`으로 회복하지만 top1/qacc는 `0.125000/0.293750`에 머뭅니다. Symbolic `key-shape` scorer는 `top1=qacc=1.000000`으로 회복하지만 현재 byte-level candidate-quality preset은 이 span ambiguity를 고치지 못합니다. 이는 actionable span-candidate quality split이지 learned chunk retrieval solved가 아닙니다.
- h6-g는 learned-like span-source stress와 span exact-match instrumentation을 추가합니다. Clean `route-code-key` span lookup은 decode/recall/top1을 높게 유지합니다(`decode=1.000000`, `recall=1.000000`, `top1=1.000000`, `qacc=0.987500`, `span_exact=0.937500`). 반면 약화된 route-code identity는 decode가 붕괴하고(`0.000000`), collision이 생기며(`0.750000`), top1/qacc/span-exact가 `0.250000/0.606250/0.281250`으로 떨어집니다. `K_route`를 키우면 recall은 `1.000000`으로 회복되지만 top1과 span exact-match는 고쳐지지 않고, byte-level candidate-quality preset도 중립입니다. 이는 learned-like source stress instrumentation이지 learned chunk retrieval solved가 아닙니다.
- h6-h는 span-level candidate-quality diagnostics를 추가합니다. Weak route-code span stress에서 `K_route=16`은 all-span recall을 `1.000000`으로 회복하지만 all-span top1과 span exact-match는 `0.250000`에 머뭅니다. Byte-level quality preset은 중립이고, symbolic `key-shape`는 all-span top1/span exact-match를 `1.000000`으로 회복합니다. 즉 다음 병목은 recall이 아니라 span-level ranking/quality입니다.
- h6-i는 span candidate-quality gap diagnostics를 추가합니다. 약화된 route-code identity에서 `K_route=16`은 all-span recall을 `1.000000`으로 회복하지만, span 전체가 같은 오답 key를 일관되게 고르는 패턴이 나타납니다(`top_key_consistency=1.000000`, `top_key_correct=0.250000`, `coherent_wrong_top_key=0.750000`). Byte-level `base-default`는 중립이고 `hybrid-safe`는 이 stress에서 더 나쁠 수 있으며, symbolic `key-shape`는 correct-key share/key entropy/top1을 upper bound로 회복합니다. 다음 병목은 recall이 아니라 learned span-record ranking / consistency feature입니다.
- h6-j는 `--route-candidate-score span-prefix`를 추가합니다. 이는 key-shape를 쓰지 않고 이미 보이는 query span prefix와 candidate record prefix의 일치만 보는 첫 span-record ranking probe입니다. Smoke에서는 all-span recall은 유지하지만 qacc/span exact-match는 낮아집니다(`qacc 0.625000 -> 0.587500`, `span_exact 0.281250 -> 0.218750`). coherent wrong-key selection은 줄지만(`0.750000 -> 0.593750`), visible prefix consistency만으로 symbolic key-shape를 대체하기에는 부족합니다.
- h6-k는 `--route-candidate-score span-key-support`를 추가합니다. 이는 recovered span candidate set 안에서 여러 offset에 걸쳐 등장하는 candidate key를 우선하는 두 번째 non-key-shape span-record ranking probe입니다. 현재 coherent wrong-key stress에서는 all-span recall을 유지하지만 중립입니다(`qacc=0.625000`, `span_exact=0.281250`, `coherent_wrong_top_key=0.750000`, weak-k16과 동일). 즉 오답 key도 offset 전체에서 일관되게 지지될 수 있으므로 same-key support만으로 symbolic `key-shape`를 대체하기에는 부족합니다.
- h6-l은 `--route-candidate-score span-local-energy`를 추가합니다. 이는 route-hint energy를 제외한 현재 local energy 아래에서 candidate record의 전체 value span이 query span에 얼마나 맞는지로 record를 정렬합니다. 이 계열에서 처음으로 non-`key-shape` span-record scorer가 제한적 개선을 냈습니다: `qacc 0.625000 -> 0.675000`, `span_exact 0.281250 -> 0.406250`, `correct_key_share 0.503125 -> 0.631250`, `key_entropy 1.238921 -> 0.862081`. 그래도 symbolic `key-shape` 상한과는 아직 거리가 큽니다.
- h6-m은 `span-local-energy`를 작은 key/seed matrix로 확장합니다. 제한적 개선은 평균에서도 유지됩니다: `weak_qacc_mean=0.546094`, `local_energy_qacc_mean=0.571875`, `local_energy_qacc_delta_mean=0.025781`; `span_exact_mean`은 `0.273438 -> 0.378906`으로 개선되지만, symbolic `key-shape`는 여전히 `qacc_mean=0.984375`, `span_exact_mean=0.921875`로 훨씬 높습니다.
- h6-n은 `span-local-energy`와 h5 candidate-quality preset을 조합합니다. `base-default`는 local-energy 위에서 중립이고, `hybrid-safe`는 span-level 품질을 올립니다(`span_exact 0.406250 -> 0.593750`, `correct_key_share 0.631250 -> 0.768229`, `key_entropy 0.862081 -> 0.510620`). 하지만 byte qacc는 낮춥니다(`0.675000 -> 0.631250`). 즉 span exact-match와 byte qacc가 선호하는 policy가 갈릴 수 있습니다.
- h6-o는 이 분리를 명시적 policy artifact로 고정합니다. Byte-qacc objective는 `local-energy`를 선택합니다(`qacc=0.675000`, `span_exact=0.406250`). Span-exact와 balanced objective는 `local-energy-hybrid`를 선택합니다(`qacc=0.631250`, `span_exact=0.593750`). Span objective는 span exact-match를 `+0.187500` 올리는 대신 qacc를 `-0.043750` 낮춥니다.
- h6-p는 h6-o policy artifact를 작은 key/seed matrix로 확장합니다. Byte-qacc는 모든 group에서 `local-energy`를 선택하고, span-exact는 4개 중 3개 group에서 `local-energy-hybrid`를 선택합니다. Span policy는 평균 qacc `-0.033594`를 내주고 평균 span exact-match `+0.062500`을 얻습니다. Objective split rate는 `0.750000`입니다.
- h6-q는 h6-p 위에 span-first policy guardrail을 추가합니다. Strict guardrail은 4개 group 중 1개에서 span policy를 받아들이며, qacc는 `0.571875 -> 0.560937`로 제한적으로 내리고 span exact-match는 `0.378906 -> 0.425781`로 올립니다. 더 느슨한 guardrail은 raw span-exact policy에 가까워집니다. 이는 guardrail instrumentation이지 learned chunk retrieval solved가 아닙니다.
- h6-r은 h6-q를 weak/harsher learned-like source degradation으로 확장합니다. 이 fixture family에서 weak degradation은 objective split을 유지하지만 qacc loss가 cap보다 커 모든 guardrail이 span-first를 거절합니다. Harsher degradation은 2개 group 중 1개에서 split이 남고, 더 느슨한 `span-first-g0p025-cap0p075`만 받아들입니다(`qacc_delta=-0.029688`, `span_delta=+0.023438`). 이는 degradation guardrail instrumentation이지 learned source robustness solved가 아닙니다.
- h6-s는 `span_gain - loss_weight*qacc_loss > 0` adaptive utility guardrail을 calibration합니다. `utility-w0p50`은 weak high-loss split까지 받아들여 span exact-match를 올리지만 qacc를 크게 내줍니다(`qacc_delta=-0.109375`, `span_delta=+0.062500`). `utility-w0p75`는 weak high-loss split을 거절하고 lower-loss harsher split만 받아들입니다(`qacc_delta=-0.029688`, `span_delta=+0.023438`). 이는 adaptive guardrail calibration이지 learned source robustness solved가 아닙니다.
- h6-t/h6-u/h6-v/h6-w는 이 정책을 promotion gate로 끌고 갑니다. Smoke 기준 h6-t의 `utility-w0p75`는 `bad_accept_rate=0.000000`으로 안전하지만 promotion하지 않습니다. h6-u chunk readout은 `chunk_exact_mean=0.156250`, `coherent_wrong_key_mean=0.828125`, `top1_recall_gap_mean=0.796875`, `keyshape_gap_mean=0.734375`로 아직 chunk-quality가 부족함을 보여줍니다. h6-x는 plain `span-local-energy`가 local 변형보다 낫고, h6-y는 route-code signature collision 때문에 direct code scoring이 후퇴함을 보여줍니다. h10-a는 `span-chunk-credit`/`span-local-energy-chunk-credit`로 첫 positive chunk-ranker smoke를 냈고, h10-c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s는 noisy wrong-candidate, forced fallback/retry, teacher label contract, local teacher-label collection, local teacher-distillation learner, external ingestion schema, supplied-label import, teacher source verifier, learned chunk-quality scorer, row-bound source-verified scorer binding, remote acquisition contract, content-cache verifier, fetch-attestation contract, runtime-fetcher contract, live-network import contract, import/review chain, source-verified student-only scorer eval을 분리해 계측합니다. 기본 실행의 distillation blocker는 여전히 external label source이고, supplied/local fixture와 eval delta는 promotion이 아니라 diagnostic candidate까지만 올립니다.
- h7-a는 goal closure smoke를 추가했고, h7-b는 h6-t/u/v/w/x/y promotion gate를 추가합니다. h7-c는 h7-b, h10-r, h10-s, v08-ab, h11-d, h9-h를 하나의 promotion review matrix로 묶습니다. 현재 h7-b 결과는 `default_promotion=0`, `status=diagnostic-only`이고, h7-c도 `promotion_review_ready=0`, `default_promotion=0`입니다. h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q는 closure에 추가된 route-memory policy/source-acquisition/content/fetch-attestation/runtime-fetcher/live-network-import smoke이지, 아직 learned routing이나 long-context retrieval solved 선언은 아닙니다.
- v08은 external benchmark readiness gate입니다. v08-b adapter schema, v08-c evidence schema, v08-d supplied-CSV import path, v08-e comparison gate, v08-f real-evidence gate, v08-g artifact verifier, v08-h authenticity/evaluator gate, v08-i execution gate, v08-j independent attestation gate, v08-k attestor identity gate, v08-l final review gate는 RULER/LongBench/codebase retrieval/real document QA 4개 family를 덮지만, 기본 실행은 source/result evidence가 없어 `external_benchmark_ready=0`, `action=defer-external-comparison`으로 통과합니다. v08-f에서 placeholder fixture는 real benchmark evidence로 인정되지 않고, v08-g/h/i/j/k/l에서 local hash/authenticity/execution/attestation/identity/final-review fixture도 real source review evidence 없이는 publishable benchmark가 아닙니다. v08-l real-source guard는 local final-review artifact가 declaration flag rewrite만으로 real benchmark가 되는 우회를 막고, remote-review guard는 non-local review evidence만 바꾼 채 lower-chain이 local fixture인 경우를 막습니다.
- h9-a/h9-b/h9-d/h9-e/h9-f/h9-g/h9-h는 `-DDLE_ENABLE_HIP=ON`과 `--backend hip` 뒤에 optional ROCm/HIP backend scaffold를 추가합니다. CPU가 여전히 canonical/default입니다. 첫 HIP 경계는 bounded route-quality candidate-weight factor parity와 diagnostic-only 16x16 proposal-score parity이며, h9-f는 quick closure에서 parity tool을 CPU mode로 실제 실행하고 speed evidence schema를 no-claim으로 고정합니다. h9-g는 timing/environment artifact hash와 speedup 값을 검증하고, h9-h는 h9-g와 h11-d를 CPU/HIP/NVMe workload evidence contract로 묶습니다. Real HIP/NVMe workload measurement가 없으면 `gpu_speedup_claim=deferred`를 유지합니다. HIP runtime parity는 optional입니다. KV parsing, hash/source-credit orchestration, update acceptance, RNG, age/tick/reservoir mutation, CSV는 CPU에 남습니다. 이는 backend/parity/workload-evidence instrumentation이지 GPU acceleration proven이나 learned routing solved가 아닙니다.
- 현재 검증 checkpoint는 h6-t/u/v/w/x/y, h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s, h7-b, h7-c가 h7 goal closure에 포함되어 있고, v08-b부터 v08-at readiness/instrumentation과 h11-a/h11-b/h11-c/h11-d, h9-h, v12, v13-a, v13-b, v13-c, v13-d, v13-e, v13-f, v13-g, v13-h, v13-i, v13-j, v13-k, v13-l, v13-m, v13-n이 h9 quick closure에 연결되어 있습니다. HIP parity는 optional extended check로 남아 있습니다.

## 현재 상태

- `v0.1`: `dmv01`로 구현된 discrete local-energy dynamics 기준 구현입니다.
- `v0.2-pre`: `dmv02`로 구현된 shared field `H[channel][input_byte][state]` 기반 byte-level contrastive learning baseline입니다.
- `v0.2-b`: block-local coupled proposal과 `B[x, high, low]` coupling을 포함합니다. 기본 weak-coupling path는 `counter`와 `repeating-text` 5-seed regression을 통과했습니다.
- `v0.3 static routing`: `jump-neighbors`, confidence gate/acceptance, `state-code`, `input-byte` route source 계열은 diagnostic/default-off입니다. 현재 결론은 routing success가 아니라 **jump-neighbor replacement no-go/default-off/diagnostic-only**입니다.
- `v0.3 route-hint`: 살아남은 장거리 경로입니다. 핵심 경로는 `candidate value_pos -> value byte read -> proposal hint`입니다.
- 최신 route-hint 상태: h4-5t는 fallback low-channel strength sweet spot을 보정했고, h4-5u는 짧은 fallback TTL/persistence가 현재 조건에서 neutral임을 보였고, h4-5v는 route-credit separation instrumentation을 추가했으며, h4-5w는 route-credit ablation diagnostics이고, h4-5x는 credit × fallback integration ablation이며, h4-5y는 credit strength/stability calibration이고, h5-a는 persistent route-plasticity ledger와 learn/apply warmup gate이며, h5-b는 source/bucket route-credit responsibility instrumentation이고, h5-c는 key-shape fallback `hi_mult=5` / `lo_mult=10` 주변의 source-credit policy calibration이며, h5-d는 weak `joint-code-key` primary, symbolic `key-shape` fallback, explicit `noisy-route-code` stress를 비교하는 noisy / learned-like source policy diagnostics이고, h5-e는 noisy-source multi-seed / scale stability smoke이며, h5-f는 `route-code-key` identity auxiliary 자체를 약하게 만드는 learned-source stress이고, h5-g는 이 weak learned-source stress를 key/seed 축으로 확장하며, h5-h는 fallback `off`, `raw-key`, `key-shape`, `noisy-route-code` 의존성을 비교하고, h5-i는 source-credit fallback policy mode를 보정하며, h5-j는 fallback candidate-quality gap을 진단하고, h5-k는 fallback aggregation policy를 보정하며, h5-l은 source/noise-aware fallback aggregation diagnostics를 추가했고, h5-m은 그 source/noise-aware aggregation 패턴을 key/seed smoke로 확장하며, h5-n은 source-credit bad-source filter / abstain diagnostics를 추가하고, h5-o는 bad-source filtering 이후 retry-source replacement diagnostics를 추가하며, h5-p는 source-credit retry-policy calibration을 추가하고, h5-q는 `PASS as source-credit retry-policy tie-break calibration diagnostics / limited mitigation`입니다. `noisy-filter`는 `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`; `policy-source-order`는 `qacc=0.957813`, `fallback_recall=1.000000`, `retry_raw_selected=0.875000`; `policy-keyshape-prior`와 `policy-noisy-penalty/mixed`는 `retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`으로 회복했고, `fixed-keyshape`는 `qacc=0.970313`, `fallback_qacc=1.000000`의 상한입니다. NOT learned routing solved, NOT source-credit robustness solved, NOT wrong-candidate/fallback robustness solved.
- h5-r은 retry tie-break용 source-prior schedule diagnostics를 추가했습니다. 새 옵션은 `--route-source-retry-prior-mode none|static|decay|warmup`, `--route-source-retry-prior-decay`, `--route-source-retry-prior-warmup-epochs`입니다. Smoke에서 source-order는 raw-key로 회복합니다 (`qacc=0.957813`, `retry_raw_selected=0.875000`), static/decay/warmup key-shape prior는 key-shape를 선택합니다 (`qacc=0.957813`, `retry_keyshape_selected=0.875000`), noisy retry 선택은 계속 `0.000000`입니다. fixed key-shape reference는 여전히 더 높습니다 (`qacc=0.970313`, `fallback_qacc=1.000000`). 이는 source-prior schedule calibration / limited mitigation이지 learned routing solved나 robustness solved가 아닙니다.

- h5-s: source-prior handoff diagnostics를 추가했습니다. 같은 `candidate value_pos -> value byte read -> proposal hint` 경로에서 source-order, static key-shape prior, warmup-short/long, decay-fast, fixed key-shape reference를 비교합니다. Short warmup은 일부 handoff를 드러냅니다 (`retry_raw_selected=0.062500`, `retry_keyshape_selected=0.812500`). Long warmup/decay/static prior는 key-shape 선택을 유지하고 (`retry_keyshape_selected=0.875000`), noisy retry는 계속 선택되지 않습니다. qacc는 `0.957813`로 fixed key-shape `0.970313`보다 낮으므로 source-prior handoff calibration / limited mitigation으로만 읽어야 합니다.
- h5-t: retry-source evidence-quality diagnostics를 추가했습니다. 새 CSV metric은 raw-key, key-shape, noisy retry source의 source-credit mean과 reward/slash rate를 분리합니다. Smoke에서 source-order는 raw-key를 reward합니다 (`retry_raw_mean=0.222951`), static/warmup key-shape prior는 key-shape를 reward합니다 (`retry_keyshape_mean=0.222951`), noisy retry는 음수로 남습니다 (`retry_noisy_mean=-0.206811`, `retry_noisy_slashed=1.000000`). 이는 evidence-quality instrumentation이지 source-credit ranking solved가 아닙니다. raw-key와 key-shape는 선택되면 둘 다 positive credit을 받기 때문에, source-credit evidence만으로 더 좋은 symbolic retry source를 독립적으로 고르는 단계는 아직 아닙니다.
- h5-u는 candidate-quality logdet/channel/quality-score instrumentation을 추가했습니다. `route_quality_apply=none`에서 `quality-off-source-order`와 `quality-on-source-order`가 모두 `qacc=0.645313`이라 행동 변경 없이 계측만 된 것이 확인됐고, fixed raw-key와 fixed key-shape는 `qacc=0.742187` vs `0.645313`, `logdet=-5.818573` vs `-15.330912`, condition `7.050210` vs `52.270703`으로 분리됩니다. 이는 instrumentation이지 learned routing이나 robustness win이 아닙니다.
- h5-v는 첫 약한 quality 적용입니다. `route_quality_apply=source-ranking`에서 `route_quality_apply_active=1.000000`, delta `0.227710..0.250000`이 관측되고 noisy retry 선택은 `0.000000`으로 유지됩니다. 그러나 qacc는 apply-none `0.568750`에서 `0.560938`로 소폭 낮아졌으므로 weak application calibration diagnostics이지 robustness win이 아닙니다.
- h5-w는 이 약한 적용 경로의 source-quality calibration diagnostics입니다. source별 proxy/delta/qacc를 분리해 보니 raw-key proxy는 강하게 양수 (`2.277099`)이고 key-shape/noisy는 음수 (`-0.472130`, `-0.513364`)입니다. 즉 source-ranking이 raw-key를 고르고 noisy를 피하는 이유는 설명되지만, 그 선택이 qacc 개선으로 이어지지는 않습니다.
- h5-x는 proxy sign을 보정했습니다. channel-sign row가 단일 smoke에서 가장 좋았습니다 (`qacc=0.662500`, `selected_raw_qacc=0.720536`)이며 proxy-default `qacc=0.560938`보다 높습니다. h5-y는 이 channel-sign을 multi-seed/key smoke로 확장했고, 평균 qacc는 channel-sign `0.636198`, proxy-default `0.621094`, proxy-off `0.622656`입니다. h5-z는 `--route-quality-source-normalization none|center|zscore`를 추가했고, 정규화가 raw delta를 낮추는 것은 확인했지만 source 선택은 여전히 raw-key 중심입니다. h5-aa는 후보 단위 weight에 이미 correct/wrong 분리 신호가 있음을 확인했고, h5-ab는 그 신호를 후보 weight에 약하게 반영하면 qacc가 실제로 오른다는 것을 확인했습니다. h5-ac에서는 source-ranking 조합이 candidate-only를 넘지 못했습니다. h5-ad에서는 candidate-only beta를 noise/key/seed 축으로 확장했고, h5-ae에서는 `beta=2.0, cap=3.0/4.0`까지는 over-sharpen 신호 없이 qacc가 계속 상승했습니다. h5-af에서는 `keys=64,128,256`까지 확장해 `b2p00-cap3`이 평균 qacc `0.869965`로 가장 안정적인 regression setting임을 확인했습니다. h5-ag에서는 `beta=3.0`까지도 over-sharpen collapse가 나오지 않았고, h5-ah에서는 `beta=5.0, cap=6/8`까지 qacc가 `0.952669`로 더 올랐습니다. h5-ai에서는 `beta=8.0, cap=8/12`까지 qacc가 `0.957813`로 더 올라갔고, h5-aj에서는 `beta=12.0, cap=12/16`이 `0.958008`로 아주 약간 더 높지만 concentration 비용이 큽니다. h5-ak 5-seed guardrail에서는 `beta=8, cap=8`이 더 안전한 설정으로 정리됐고, h5-al에서는 이 설정을 candidate-weight-only default로 확인했습니다. h5-am에서는 feature-score basis가 현재 base-weight default를 대체하지 못함을 확인했습니다. h5-an/h5-ao/h5-ap에서는 hybrid basis가 base qacc를 유지하면서 concentration을 낮출 수 있음을 확인했고, h5-aq/h5-ar에서는 concentration-aware auto switching이 base qacc를 유지하면서 threshold별 concentration tradeoff를 드러냈습니다. h5-as는 auto trigger를 factor와 top-share로 분해했고, h5-at는 factor/top/any trigger policy를 비교했으며, h5-au는 factor-only threshold를 더 촘촘히 보정했습니다. 현재 결론은 `basis=base`가 기본값이고, `hybrid-m0p25`가 lower-concentration safe alternative이며, factor-only auto는 threshold regime을 설명하는 diagnostic이라는 것입니다.

## 중요한 아키텍처 결론

### 1. Remote node as neighbor: NO-GO

`jump-neighbors` 계열은 active long-distance edge를 만들 수는 있었지만 fixture regression 또는 no-op 경계로 갔습니다. 현재 문서와 실험에서는 이 경로를 promotion 대상이 아니라 diagnostic/default-off branch로 유지합니다.

### 2. Remote value as proposal hint: WORKS

route-hint 계열은 다음 경로를 유지합니다.

```text
candidate value_pos
-> value byte read
-> proposal hint
```

oracle, parsed value-position, exact KV, hashed candidate, route-code identity, fallback source까지 이 경로가 이어졌습니다.

### 3. Prediction code와 route identity code는 다릅니다

`joint-code-key`는 plumbing은 통과했지만 key identity를 충분히 보존하지 못했습니다.

```text
key_region_joint_decode_acc = 0.093750
joint_signature_collision_rate = 0.625000
```

별도 route-code identity auxiliary를 넣으면 32-key route-code run에서 query accuracy/recall/top1이 `1.000000`까지 회복됩니다. 현재 결론은 **prediction joint-code is not a routing identity-code**입니다.

### 4. Retrieval과 state convergence는 별도 병목입니다

128-key stress에서는 candidate retrieval, top1, route decode가 모두 `1.000000`이어도 query accuracy가 낮아질 수 있었습니다. `lambda_route`와 margin-adaptive strength가 이를 회복했기 때문에, 후보 찾기와 value를 state로 밀어 넣는 dynamics margin은 별도 문제입니다.

### 5. Low-confidence failure는 둘로 나뉩니다

```text
preserve-correct:
  정답 후보는 있음 -> ranking / aggregation 문제

remove-correct:
  정답 후보가 없음 -> fallback / abstain / secondary source 문제
```

이 구분은 fallback, route-credit, future route plasticity 설계의 기준입니다.

## 최근 h4-5 계열 요약

- h4-5g adaptive strength: 128-key correct-candidate setting에서 fixed strong보다 낮은 평균 strength로 qacc를 거의 회복했습니다.
- h4-5h/i/j: confidence guard, value-support confidence, scorer-agreement confidence는 wrong hint strength를 낮추는 instrumentation으로는 작동하지만 wrong-candidate robustness는 해결하지 못했습니다.
- h4-5k: confidence-gated aggregation은 high/low confidence split을 만들고 limited mitigation을 보였지만 robustness solved는 아닙니다.
- h4-5l/m: low-confidence failure를 preserve-correct aggregation/ranking 문제와 remove-correct candidate availability 문제로 분리했습니다.
- h4-5n: key-shape fallback은 remove-correct candidate availability를 회복했지만 fallback-used qacc는 낮았습니다.
- h4-5o: projected delta는 preserve-correct에 제한적 개선을 보였지만 fallback integration을 해결하지 못했습니다.
- h4-5p: fallback-only strength multiplier가 fallback qacc를 실제로 움직였습니다.
- h4-5q: fallback adaptive strength는 fixed strong보다 낮은 평균 strength로 일부 개선했지만 fixed strong을 대체하지는 못했습니다.
- h4-5r/s/t: fallback-used query는 low nibble 쪽이 더 큰 병목이며, `hi_mult=5`, `lo_mult=7.5..10` 근처에 sweet spot이 있습니다.
- h4-5u: 짧은 fallback persistence / TTL 계측은 정상 연결됐지만 qacc 개선은 neutral입니다.
- h4-5v: value-position route credit은 correct/wrong candidate credit을 분리합니다 (`credit_gap = 1.110268`) 그리고 qacc를 아주 작게 움직입니다 (`0.845312 -> 0.850000`). 이는 route-credit separation instrumentation / tiny mitigation이지 wrong-candidate robustness solved나 learned routing solved가 아닙니다. 다음 route-credit 작업은 score weight, reward/slash 비율, decay, clip, value-pos 대비 query-value edge credit, 그리고 fallback low-channel strength sweet spot과의 조합 ablation입니다.
- h4-5w: route-credit ablation diagnostics와 `--route-credit-mode query-value`를 추가했습니다. Smoke에서 value-pos credit은 유지되고, query-value edge credit도 동작합니다 (`query-value-probe` gap `0.598951`). credit + low-channel fallback 조합은 fallback subset을 움직입니다 (`fallback_qacc 0.688889 -> 0.777778`). 이는 ablation instrumentation / limited mitigation이지 robustness solved가 아닙니다.
- h4-5x: credit × fallback integration factorial을 추가했습니다. true `--route-credit-mode off`, `value-pos`, `query-value`를 key-shape fallback `hi_mult=5`, `lo_mult=7.5/10/15`, preserve/remove corruption과 교차합니다. Smoke에서는 preserve-correct qacc는 중립이지만 credit gap이 생기고, remove-correct qacc가 `lo=7.5/10`에서 `0.912500 -> 0.925000`으로 움직입니다. 이는 integration diagnostics / limited mitigation입니다.
- h4-5y: credit strength/stability calibration을 추가했습니다. Smoke는 active `value-pos/query-value` credit의 score weight와 slash 강도, corruption rate를 대각선 셀로 점검하고 true `off` baseline을 포함합니다. Query-value credit은 preserve rows에서 강한 gap을 유지하고, remove rows는 fallback diagnostics를 채웁니다. 이는 calibration diagnostics / limited mitigation이지 robustness solved가 아닙니다.
- h5-a: `--route-plasticity-ledger` persistent ledger와 `--route-credit-learn-after-epoch` / `--route-credit-apply-after-epoch` warmup gate를 추가했습니다. Smoke는 value-bearing path가 유지되는지, candidate lookup/read distance가 채워지는지, `routing_trigger_rate`와 `active_jump_rate`가 `0.000000`인지 확인합니다. 이는 route-plasticity instrumentation이지 learned routing solved나 wrong-candidate robustness solved가 아닙니다.
- h5-b: `--route-source-credit-learning` source/bucket credit을 추가했습니다. Smoke는 remove-correct에서 fallback source가 primary보다 높은 책임 신호를 얻는지 확인합니다 (`source gap = 0.276563`, fallback mean `0.300000`, primary mean `0.023438`, primary slashed rate `0.281250`, fallback rewarded rate `1.000000`). qacc는 neutral이므로 source/bucket responsibility instrumentation이지 fallback robustness solved나 learned routing solved가 아닙니다.
- h5-c: `--route-source-credit-learning`, `--route-source-credit-score-weight`, `--route-source-credit-eta-reward`, `--route-source-credit-eta-slash`, `--route-plasticity-ledger`를 더해 source-credit policy calibration을 추가했습니다. Smoke는 remove-correct corruption `0.25`와 key-shape fallback `hi_mult=5` / `lo_mult=10`을 고정한 채 learn-only, ranking, ranking+strength, ledger row를 분리합니다. Learn-only는 source gap `0.276563`을 만들지만 적용하지 않고, ranking-strength는 그 gap을 `0.553125`로 키우며, ledger row는 persistent state만 채워서 ledger size `59.000000`, mean abs credit `0.711864`를 보입니다. 이건 policy instrumentation이지 robustness solved가 아닙니다.
- h5-d: remove-correct corruption `0.25`에서 noisy / learned-like source policy diagnostics를 추가했습니다. Smoke는 두 branch를 봅니다. 하나는 weak `joint-code-key` primary와 `key-shape` fallback이고, 다른 하나는 `--route-noisy-source-rate 1.0`의 명시적 `noisy-route-code` stress입니다. `route_hint_candidate_lookup_count > 0`, `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`, `active_jump_rate = 0.000000`를 유지하면서, 유용한 key-shape fallback에는 positive source gap이 생기고 나쁜 noisy candidate에는 negative noisy-source credit/slash가 생기는지 확인합니다. 이는 source-quality separation instrumentation이지 robustness solved가 아닙니다.
- h5-e: noisy-source multi-seed / scale stability diagnostics를 추가했습니다. Smoke는 key count `32/64`, seed `1/2`, noisy rate `0.50/1.00`을 교차합니다. Weak joint branch는 key-shape fallback positive source gap을 유지하고, noisy branch는 negative noisy-candidate credit과 noisy slash diagnostic을 유지합니다. Fully noisy row에서는 source gap도 음수입니다. 이는 stability instrumentation이지 source-credit robustness solved가 아닙니다.
- h5-f: `--route-code-key-region-keep-prob`와 `--route-code-aux-noise-rate`로 `route-code-key` identity auxiliary 자체를 약하게 만드는 learned-source stress diagnostics를 추가했습니다. Smoke는 key count `32/64`, seed `1/2`에서 clean full-supervision branch와 weak branch(`keep=0.25`, `aux_noise=0.75`)를 비교합니다. Clean row는 decode/primary recall/qacc `1.000000`을 유지하고, weak row는 route-code decode와 primary recall이 낮아지며 key-shape fallback, source-credit gap, primary slash / fallback reward signal이 켜집니다. 이는 weaker learned-source instrumentation이지 learned routing solved가 아닙니다.
- h5-g: weak learned-source multi-seed / scale stability diagnostics를 추가했습니다. Smoke는 key count `64/128`, seed `1/2`, clean/mid/weak route-code weakening arm을 교차하고, weak fallback-off와 key-shape fallback + source-credit `ranking-strength` + ledger arm을 비교합니다. 평균 readout은 clean-off qacc/decode/recall `1.000000`, mid-off qacc `0.970313`, decode `0.630937`, recall `0.994531`, weak-off qacc `0.185938`, decode `0.000000`, recall `0.285938`, weak fallback-ledger qacc `0.460156`, fallback_used `0.714063`입니다. source gap/slash/reward도 켜집니다. 이는 scale/stability instrumentation이지 source-credit robustness solved가 아닙니다.
- h5-h: fallback-source dependence / stability diagnostics를 추가했습니다. Smoke는 weak route-code source를 고정하고 fallback `off`, exact symbolic `raw-key`, source-credit `ranking-strength`가 붙은 symbolic `key-shape`, bad `noisy-route-code`를 비교합니다. 평균 readout은 fallback-off qacc `0.213281`, raw-key qacc `0.650000` 및 fallback_recall `1.000000`, key-shape qacc `0.437500` 및 source_gap `0.299223`, noisy-route-code qacc `0.173437`, source_gap `-0.207562`, noisy_mean `-0.201440`, noisy_slash `0.979234`입니다. 이는 symbolic fallback dependence와 bad-source diagnostics를 분리하는 계측이지 learned routing solved가 아닙니다.
- h5-i: source-credit fallback-policy calibration diagnostics를 추가했습니다. Smoke는 weak route-code source를 고정하고 `key-shape` learn-only, ranking, strength, ranking-strength apply mode를 `raw-key` symbolic ceiling 및 `noisy-route-code` negative control과 비교합니다. 평균 readout은 off-control qacc `0.206250`, raw-key qacc `0.661328` 및 fallback_recall `1.000000`, key-shape source_gap `0.299047`, ranking selected_fallback `0.660209`, strength mean `1.402324`, noisy-route-code source_gap `-0.182191`, noisy_mean `-0.189995`, noisy_slash `0.976094`, fallback_recall `0.000000`입니다. 이는 policy calibration instrumentation이지 fallback robustness나 learned routing solved가 아닙니다.
- h5-j: fallback candidate-quality gap diagnostics를 추가했습니다. Smoke는 `raw-key`와 `key-shape` fallback을 `vote`, `weighted-vote`, source-credit `ranking-strength` 조건에서 비교합니다. 두 fallback source 모두 후보는 회복하지만 top1은 낮습니다 (`0.031250`, 평균 rank `2.500000`). Plain vote는 약하고 (`raw` qacc `0.225000`, `key-shape` qacc `0.200000`), weighted-vote는 correct value support를 올리고 entropy를 낮춰 둘 다 거의 풉니다 (`raw` qacc `0.942188`, `key-shape` qacc `0.960938`). 즉 현재 병목은 fallback recall 단독이 아니라 fallback aggregation quality입니다.
- h5-k: fallback aggregation policy calibration을 추가했습니다. Smoke는 `raw-key`와 `key-shape` fallback에서 `top1`, `vote`, `weighted-vote`, confidence-gated policy를 비교합니다. Plain vote는 약한 정책입니다 (`raw` qacc `0.328125`, `key-shape` qacc `0.204688`). 반면 이 controlled fallback 조건에서는 top1과 weighted-vote가 강합니다 (`top1` qacc는 둘 다 `0.906250`, weighted qacc는 `0.943750` / `0.956250`). Confidence-gated low=`vote`, high=`weighted-vote`는 vote 약점을 물려받고, low/high 모두 `weighted-vote`일 때 weighted baseline을 보존합니다.
- h5-l: source/noise-aware fallback aggregation diagnostics를 추가했습니다. Smoke는 symbolic fallback source에는 weighted aggregation + source-credit policy를 적용하고, noisy fallback은 negative control로 유지합니다. Raw-key는 vote qacc `0.401563`에서 source-aware qacc `0.965625`로, key-shape는 `0.218750`에서 `0.964063`으로 올라갑니다. Noisy fallback은 여전히 해결되지 않지만 (`fallback_recall=0.000000`), negative source/noisy credit으로 감지됩니다 (`source_gap=-0.140244`, noisy slash `1.000000`) 그리고 strength amplification은 없습니다 (`strength_mean=1.000000`).
- h5-m: source/noise-aware aggregation scale stability diagnostics를 추가했습니다. Smoke는 key count `64/128`, seed `1/2`를 교차하고 `raw-key`, `key-shape`, `noisy-route-code` fallback에서 vote와 source-aware weighted aggregation을 비교합니다. 평균적으로 raw-key는 qacc `0.378516 -> 0.925391`, key-shape는 `0.275781 -> 0.932813`으로 개선되고 둘 다 `fallback_recall=1.000000`을 유지합니다. Noisy branch는 여전히 해결되지 않지만 (`fallback_recall=0.000000`), negative source/noisy credit으로 감지됩니다 (`source_gap=-0.268339`, noisy slash `1.000000`) 그리고 strength amplification은 없습니다 (`strength_mean=1.000000`).
- h5-n: bad-source filtering / abstain diagnostics를 추가했습니다. 새 `--route-source-filter-mode negative-credit`는 source credit이 `--route-source-filter-threshold`보다 낮은 candidate를 제거합니다. Smoke에서 symbolic fallback은 계속 사용 가능합니다 (`raw-filter` qacc `0.951562`, `keyshape-filter` qacc `0.965625`). 반면 noisy fallback은 강하게 필터링됩니다 (`source_filter_filtered=0.935065`, `source_filter_abstain=0.875000`). 하지만 noisy qacc는 개선되지 않습니다 (`0.185937 -> 0.100000`). 따라서 이는 bad-source abstention instrumentation이지 fallback robustness solved가 아닙니다.
- h5-o: retry-source replacement diagnostics를 추가했습니다. 새 `--route-source-retry-source`는 bad/noisy fallback 후보가 negative-credit filter로 제거된 뒤 secondary source 후보를 같은 value-bearing route-hint path에 넣습니다. Smoke에서 noisy-filter baseline은 회복 없이 abstain합니다 (`qacc=0.103125`, `fallback_recall=0.000000`, `source_filter_abstain=0.876562`). 반면 symbolic retry를 붙이면 recall과 qacc가 회복됩니다 (`retry-raw` qacc `0.950000`, `fallback_recall=1.000000`; `retry-keyshape` qacc `0.962500`, `fallback_recall=1.000000`). 이는 retry/replacement instrumentation이지 learned routing이나 fallback robustness solved가 아닙니다.
- h5-p: source-credit retry-policy calibration을 추가했습니다. 새 `--route-source-retry-policy source-credit`, `--route-source-retry-candidates`, `--route-source-retry-per-source-limit`는 bad/noisy source filtering 이후 여러 retry source 후보를 source-credit 순서로 넣습니다. Smoke에서 noisy-filter baseline은 회복 없이 abstain합니다 (`qacc=0.103125`, `fallback_recall=0.000000`). fixed symbolic retry는 회복합니다 (`fixed-raw` qacc `0.957813`, `fixed-keyshape` qacc `0.970313`). source-credit mixed policy도 noisy retry 선택 없이 회복합니다 (`policy-mixed` qacc `0.957813`, `retry_noisy_selected=0.000000`). 이는 retry policy selection 배관이지 learned routing이나 fallback robustness solved가 아닙니다.
- h5-q: source-credit retry-policy tie-break calibration을 추가했고 `PASS` as source-credit retry-policy tie-break calibration diagnostics / limited mitigation입니다. `noisy-filter`는 `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`이고, `policy-source-order`는 `qacc=0.957813`, `fallback_recall=1.000000`, `retry_raw_selected=0.875000`으로 회복합니다. `policy-keyshape-prior`와 `policy-noisy-penalty/mixed`도 `retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`으로 회복하고, `fixed-keyshape`는 `qacc=0.970313`, `fallback_qacc=1.000000`의 상한입니다. 이는 learned routing solved도, source-credit robustness solved도, wrong-candidate/fallback robustness solved도 아닙니다.
- h5-r: source-prior schedule diagnostics를 추가했습니다. `none/static/decay/warmup` prior mode를 비교하고, 같은 `candidate value_pos -> value byte read -> proposal hint` 경로를 유지합니다. Source-order는 raw-key를 선택하고, static/decay/warmup key-shape prior는 key-shape를 선택하며, noisy retry는 선택하지 않습니다. qacc는 `0.957813`으로 fixed key-shape reference `0.970313` 아래에 머물기 때문에 prior schedule calibration / limited mitigation으로만 읽어야 합니다.

## 빌드

```bash
cmake -S . -B build
cmake --build build -j
```

Optional ROCm/HIP scaffold build:

```bash
cmake -S . -B build-hip -DDLE_ENABLE_HIP=ON
cmake --build build-hip --target dmv02 hip_candidate_weight_parity -j
```

Runtime backend 선택은 명시적입니다.

```bash
./build/dmv02 --backend cpu ...
./build-hip/dmv02 --backend hip --hip-device 0 ...
```

h9는 scaffold/parity 단계입니다. string/KV parsing, source-credit ledger,
update acceptance, RNG, route strength, topology는 GPU로 옮기지 않았습니다.

## 실행 예시

`v0.1`은 기본적으로 CSV를 stdout에 씁니다.

```bash
./build/dmv01 --cycles 100 --N 256 > results/v01_smoke.csv
```

파일로 직접 저장할 수도 있습니다.

```bash
./build/dmv01 --cycles 100 --N 256 --csv results/v01_smoke.csv
```

`v0.2-pre` / `v0.2-b` 예시:

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --lambda-v 0 \
  --csv results/counter_lv0.csv
```

## Baseline 해석

- `counter` with `lambda_v = 0`은 첫 locked correctness gate이며 강하게 성공해야 합니다.
- `repeating-text`는 초기/중기 학습에서 `field_byte_acc`가 `oracle1_acc`보다 낮지만 `byte_acc`보다 분명히 높아야 합니다.
- `v0.2-b` 기본 weak-coupling run은 `repeating-text`에서 대략 `field/joint/byte = 0.687500/0.687500/0.687500` 근처에 도달하고 `counter` gate는 `1.000000/1.000000/1.000000`을 유지합니다.
- 5-seed 기본 weak-coupling regression은 `counter byte/field/joint = 0.999688/1.000000/1.000000`, `repeating-text byte/field/joint = 0.685625/0.681094/0.685703` 평균을 기록합니다.
- 같은 5-seed `repeating-text` regression에서 weak coupling은 no-coupling control 대비 평균 `byte_acc +0.177578` 개선을 보입니다.

## 대표 실험 스크립트

전체 실험 목록은 [README.md](README.md)와 [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md)를 참고하세요. 주요 helper는 아래와 같습니다.

### v0.2 / v0.2-b

- `experiments/run_v02_counter.sh`
- `experiments/run_v02_ablation.sh`
- `experiments/run_v02_repeating.sh`
- `experiments/run_v02b_tuned.sh`
- `experiments/run_v02b_counter_compare.sh`
- `experiments/run_v02b_repeating_compare.sh`
- `experiments/run_v02b_counter_multiseed_compare.sh`
- `experiments/run_v02b_repeating_multiseed_compare.sh`

### v0.3 static routing diagnostics

- `experiments/run_v03_routing_probe.sh`
- `experiments/run_v03_routing_fixture_compare.sh`
- `experiments/run_v03_static_routing_compare.sh`
- `experiments/run_v03_gap_gate_ablation.sh`
- `experiments/run_v03_gate_diagnostics.sh`
- `experiments/run_v03_confidence_gate_ablation.sh`
- `experiments/run_v03_confidence_acceptance_ablation.sh`
- `experiments/run_v03_input_byte_jump_compare.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `experiments/run_v03_rejection_diagnostics.sh`

### v0.3 value-bearing route-hint

- `experiments/run_v03_route_hint_oracle.sh`
- `experiments/run_v03_route_hint_parsed.sh`
- `experiments/run_v03_route_hint_kv_exact.sh`
- `experiments/run_v03_route_hint_kv_hash.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_stress.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/run_v05_route_credit_plasticity.sh`
- `experiments/run_v05_route_source_credit.sh`
- `experiments/run_v05_route_source_credit_policy.sh`
- `experiments/run_v05_route_source_credit_noisy_source.sh`
- `experiments/run_v05_route_source_credit_noisy_scale.sh`
- `experiments/run_v05_route_source_credit_learned_source_stress.sh`
- `experiments/run_v05_route_source_credit_learned_source_scale.sh`
- `experiments/run_v05_route_source_credit_fallback_ablation.sh`
- `experiments/run_v05_route_source_credit_fallback_policy.sh`
- `experiments/run_v05_route_source_credit_fallback_quality.sh`
- `experiments/run_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_scale.sh`
- `experiments/run_v05_route_source_credit_bad_source_filter.sh`
- `experiments/run_v05_route_source_credit_retry_source.sh`
- `experiments/run_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/run_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/run_v05_route_source_credit_retry_policy.sh`
- `experiments/run_v05_route_candidate_quality_logdet.sh`
- `experiments/run_v05_route_quality_application.sh`
- `experiments/run_v05_route_quality_proxy_calibration.sh`
- `experiments/run_v05_route_quality_source_norm.sh`
- `experiments/run_v05_route_quality_candidate_apply.sh`
- `experiments/run_v05_route_quality_candidate_scale.sh`
- `experiments/run_v05_route_quality_candidate_saturation.sh`
- `experiments/run_v05_route_quality_candidate_boundary.sh`
- `experiments/run_v05_route_quality_candidate_high_beta.sh`
- `experiments/run_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/run_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/run_v05_route_quality_candidate_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_default.sh`
- `experiments/run_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_basis_policy.sh`
- `experiments/run_v05_route_quality_candidate_preset_regression.sh`
- `experiments/run_v05_route_quality_candidate_preset_policy.sh`
- `experiments/run_v05_route_quality_candidate_regression.sh`
- `experiments/run_v05_route_quality_candidate_level.sh`
- `experiments/run_v05_route_quality_candidate_composition.sh`

## 대표 smoke test

- `experiments/test_v03_route_hint_oracle.sh`
- `experiments/test_v03_route_hint_parsed.sh`
- `experiments/test_v03_route_hint_kv_exact.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/test_v05_route_credit_plasticity.sh`
- `experiments/test_v05_route_source_credit.sh`
- `experiments/test_v05_route_source_credit_policy.sh`
- `experiments/test_v05_route_source_credit_noisy_source.sh`
- `experiments/test_v05_route_source_credit_noisy_scale.sh`
- `experiments/test_v05_route_source_credit_learned_source_stress.sh`
- `experiments/test_v05_route_source_credit_learned_source_scale.sh`
- `experiments/test_v05_route_source_credit_fallback_ablation.sh`
- `experiments/test_v05_route_source_credit_fallback_policy.sh`
- `experiments/test_v05_route_source_credit_fallback_quality.sh`
- `experiments/test_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_scale.sh`
- `experiments/test_v05_route_source_credit_bad_source_filter.sh`
- `experiments/test_v05_route_source_credit_retry_source.sh`
- `experiments/test_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/test_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/test_v05_route_source_credit_retry_policy.sh`
- `experiments/test_v05_route_candidate_quality_logdet.sh`
- `experiments/test_v05_route_quality_application.sh`
- `experiments/test_v05_route_quality_proxy_calibration.sh`
- `experiments/test_v05_route_quality_source_calibration.sh`
- `experiments/test_v05_route_quality_source_norm.sh`
- `experiments/test_v05_route_quality_channel_scale.sh`
- `experiments/test_v05_route_quality_candidate_level.sh`
- `experiments/test_v05_route_quality_candidate_apply.sh`
- `experiments/test_v05_route_quality_candidate_scale.sh`
- `experiments/test_v05_route_quality_candidate_saturation.sh`
- `experiments/test_v05_route_quality_candidate_boundary.sh`
- `experiments/test_v05_route_quality_candidate_high_beta.sh`
- `experiments/test_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/test_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/test_v05_route_quality_candidate_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_default.sh`
- `experiments/test_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_promotion.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy_scale.sh`
- `experiments/test_v05_route_quality_candidate_basis_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_preset.sh`
- `experiments/test_v05_route_quality_candidate_preset_regression.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy_scale.sh`
- `experiments/test_v05_route_quality_closure.sh`
- `experiments/test_v06_route_memory_span_boundary.sh`
- `experiments/test_v06_route_memory_span_exact.sh`
- `experiments/test_v06_route_memory_span_exact_scale.sh`
- `experiments/test_v06_route_memory_span_hash.sh`
- `experiments/test_v06_route_memory_span_hash_scale.sh`
- `experiments/test_v06_route_memory_span_ambiguity.sh`
- `experiments/test_v06_route_memory_span_learned_source.sh`
- `experiments/test_v06_route_memory_span_quality_diagnostics.sh`
- `experiments/test_v06_route_memory_span_candidate_quality_gap.sh`
- `experiments/test_v06_route_memory_span_prefix_ranking.sh`
- `experiments/test_v06_route_memory_span_key_support_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_scale.sh`
- `experiments/test_v06_route_memory_span_local_energy_composition.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy_scale.sh`
- `experiments/test_v07_goal_route_memory_closure.sh`
- `experiments/test_v05_route_quality_candidate_auto_basis.sh`
- `experiments/test_v05_route_quality_candidate_auto_threshold.sh`
- `experiments/test_v05_route_quality_candidate_auto_trigger.sh`
- `experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh`
- `experiments/test_v05_route_quality_candidate_composition.sh`
- `experiments/test_v05_route_quality_candidate_regression.sh`

## 핵심 문서

- [Master Prompt](DISCRETE_MANIFOLD_MASTER_CODEX_PROMPT.md)
- [Architecture Plan](docs/DISCRETE_MANIFOLD_ARCHITECTURE_PLAN_A_TO_Z.md)
- [v0.1 Design](docs/DESIGN_V01.md)
- [v0.2-pre Design](docs/DESIGN_V02_PRE.md)
- [v0.2-b Results](docs/V02B_RESULTS.md)
- [v0.2-b Decision Boundary](docs/V02B_DECISION_BOUNDARY.md)
- [v0.2-b 5-Seed Protocol](docs/V02B_MULTI_SEED_PROTOCOL.md)
- [v0.3 Routing Probe](docs/V03_ROUTING_PROBE.md)
- [v0.3 Static Routing Slice](docs/V03_STATIC_ROUTING.md)
- [v0.3 Route-Hint Oracle](docs/V03_ROUTE_HINT_ORACLE.md)
- [v0.6 / h6 Route Memory](docs/V06_ROUTE_MEMORY.md)
- [v0.7 / h7 Goal Closure](docs/V07_GOAL.md)
- [h9 ROCm/HIP Backend Scaffold](docs/V09_GPU_BACKEND.md)
- [Roadmap](docs/ROADMAP.md)

## 다음 연구 방향

- h5 route-quality stack은 `experiments/test_v05_route_quality_closure.sh`와 h7 goal closure로 닫힌 checkpoint로 봅니다.
- h6 exact/hash span path는 symbolic route-memory instrumentation입니다. value-span offset별 hint와 offset-aware hash candidate는 검증됐지만, learned chunk retrieval solved는 아닙니다.
- candidate-quality weighting은 현재 가장 강한 route-quality 적용 경로입니다. 기본값은 `base`, concentration을 낮추는 안전 대안은 `hybrid-safe`입니다.
- route strength를 계속 키우거나 topology replacement를 되살리는 방향은 기본값으로 두지 않습니다. 다음 실제 연구 질문은 ambiguous 또는 learned-like span/chunk candidate quality입니다.
- synthetic fixture를 넘어 real long-context / chunk-level task와 외부 baseline 비교로 확장하기 전까지는 Transformer replacement나 long-context retrieval solved claim을 하지 않습니다.
