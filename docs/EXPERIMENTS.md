# Experiments

## Current Stage

The current checkpoint is h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s plus h7-b/h7-c,
v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation/readiness,
v08 lower-chain remote-artifact path plus v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at real-source/remote-review/remote-full source-import/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation guards, h11-a prototype readiness/import, h11-b
artifact verification/import, h11-c NVMe RouteMemory store/artifact smokes, h11-d PC RouteLM NLG smoke,
h9-h workload-speed gate, v12 paper/release claim audit, v13-a real-run
binder manifest, v13-b RouteLM mmap reader, v13-c evidence packet ABI,
v13-d real NLG transcript binding, v13-e public codebase RouteQA binding,
v13-f resource envelope binding, v13-g real evidence promotion gate,
v13-h real evidence intake gate, v13-i real evidence live-network gate,
v13-j real evidence rebind gate, v13-k runtime fetch provenance gate,
v13-l source seed gate, v13-m source seed live-fetch gate, v13-n external
benchmark official source acquisition gate in quick closure, plus v14-a
runner-owned query/result/evaluator execution:

```text
h6-p: span-local-energy policy-scale diagnostics pass.
h6-q: span-first policy guardrail diagnostics pass.
h6-r: span-first guardrail degradation diagnostics pass.
h6-s: adaptive guardrail calibration diagnostics pass.
h6-t: adaptive guardrail scale diagnostics pass as safe diagnostic-only.
h6-u: chunk-quality diagnostics pass and expose coherent wrong-key/top1 gaps.
h6-v/h6-w: wrong-candidate/fallback robustness gates pass diagnostic-only.
h6-x: chunk-local scorer diagnostics keep plain span-local-energy as best current non-key-shape scorer.
h6-y: chunk-code similarity diagnostics show learned route-code signature collision is too high to improve chunk ranking.
h10-a: teacher-free chunk-credit ranker smoke breaks the coherent wrong-key mode in the controlled fixture.
h10-b: chunk-credit abstain policy routes positive chunk credit to weak-hint/abstain, not default promotion.
h10-c: joint noisy/distillation gate keeps promotion blocked while proving injected noisy candidates are not selected.
h10-d: fallback/retry exercise forces primary-candidate corruption and shows raw retry can recover without noisy selection.
h10-e: teacher-label contract covers correct/wrong/near-miss/missing/abstain grounded-span labels, while external collection/training remains blocked.
h10-f: local teacher-label collection harness passes, while external labels/training remains blocked.
h10-g: local distilled-rule learner fits the h10-f labels, while external label ingestion remains blocked.
h10-h: external teacher-label ingestion schema passes, while default external source remains blocked.
h10-i: supplied external teacher-label CSV import passes, but distillation remains blocked until h10-j verifies a real teacher source.
h10-j: teacher external-label source verification passes for local hash/provenance mechanics while keeping real teacher-source verification blocked.
h10-k: local learned chunk-quality scorer passes on h10-f labels, while external source and default promotion remain blocked.
h10-l: row/provenance-bound source-verified learned scorer binding passes, while local/default labels remain blocked from satisfying source-verified distillation.
h10-m: remote teacher-source acquisition contract passes for HTTPS evidence packages.
h10-n: remote teacher-source content verifier passes for supplied cache files bound to the HTTPS acquisition manifest, while live remote fetch verification remains blocked.
h10-o: remote teacher-source live-fetch attestation contract passes for supplied artifact-level attestations, while live network fetch remains blocked.
h10-p: runner-owned runtime fetcher replay contract passes for h10-o attestations, while live network fetch and real source verification remain blocked.
h10-q: live-network runtime evidence import gate passes for provided live-network rows, while real source import remains blocked.
h10-r: real teacher-source import/review chain gate passes contract/guard tests, while official authority and real source verification remain blocked.
h10-s: source-verified learned scorer student-only eval gate passes metric/guard tests, while final scorer eval readiness remains blocked until official real teacher-source authority exists.
h7-b: promotion gate blocks default route-memory promotion.
h7-c: promotion review gate binds h7-b, h10-r, h10-s, v08-ab, h11-d, and h9-h, passes review/threshold guardrails, and still blocks default promotion until real evidence exists across every input.
v13-a: real-run binder manifest packages h11-c store artifacts, h11-d NLG transcript/result, h9-h workload rows, v08-al run/evaluator trace, h10-s scorer/teacher evidence, and v12 claim-audit input into one hash-manifested run directory; the smoke passes for generated diagnostic inputs and corrupted hashes block, while actual nonfixture run, real PC RouteLM NLG, real external benchmark, real workload-speed evidence, real release package, and GPU speedup claims remain blocked.
v13-b: RouteLM mmap reader opens the v13 run store with mmap, checks route-index/page-table byte windows, validates chunk offsets and route-key matches, and blocks both hash mismatches and hash-clean span semantic corruption while keeping real artifact/external/release claims blocked.
v13-c: evidence packet ABI normalizes the bound run manifest, store/mmap reader evidence, NLG transcript/result, workload row, benchmark trace/evaluator outputs, h10-s scorer evidence, and v12 input into packet rows plus a claim-matrix input; packet hashes and claim-source references pass, while learned ranking and all real/nonfixture claims remain blocked.
v13-d: real NLG transcript binding parses the bound transcript/result, replays every transcript row against route-index rows and mmap-read chunk span bytes, emits `transcript_binding.csv`, and blocks hash-clean wrong grounding while real PC RouteLM NLG remains blocked until a nonfixture generator run exists.
v13-e: public codebase RouteQA binding follows the v13 run benchmark manifest into the local codebase-mini package, verifies trace/package/source hashes, joins seven dataset/result/query/evaluator rows, recomputes metrics, emits `routeqa_rows.csv`, and blocks hash-clean evaluator corruption while keeping independent external benchmark evidence blocked.
v13-f: resource envelope binding verifies the run-bound workload CSV, NLG/timing/environment artifact hashes, run NLG hash match, CPU/HIP/NVMe/query/token/RAM/VRAM metric envelope, and hash-clean speedup removal while keeping real workload-speed and GPU speedup claims blocked.
v13-g: real evidence promotion gate consumes v13-c/v13-d/v13-e/v13-f plus h10-s/h11-d/h9-h/v08 run evidence and keeps promotion blocked until real external benchmark, source-verified learned scorer, real NLG, real GPU speed, and nonfixture run evidence are all true in the same bound run.
v13-h: real evidence intake gate validates the same-run four-row package that must replace the v13-g blockers, including run-id binding, cache hashes, HTTPS source/review/authority URIs, contract flags, and route/jump zero, while keeping real release blocked until live-network verification and regenerated bound-run evidence exist.
v13-i: real evidence live-network gate validates source/review/authority receipt hashes, HTTPS final URIs, HTTP status rows, live-network declarations, and route/jump zero above v13-h, while keeping real release blocked until the receipts come from runner-owned runtime live fetches and the bound run is regenerated.
v13-j: real evidence rebind gate validates receipt-hash replay into same-run replacement artifacts and claim-matrix rows above v13-i, while keeping real release blocked until runtime live fetch evidence and regenerated promotion rows exist.
v13-k: runtime fetch provenance gate reopens v13-i receipt JSON above v13-j, verifies runtime receipt scope/weakness/kind binding, HTTPS original/final URIs, HTTP status, method, headers, empty error, ordered UTC timestamps, receipt hashes, and route/jump zero, while keeping real release blocked unless the receipt source is `runtime-live-fetch`.
v13-l: source seed gate separates public source seeds from claim evidence, allowing the external-benchmark row to bind current RULER/LongBench public sources while keeping learned chunk ranking, GPU speedup, and real NLG blocked as `project-source-only`.
v13-m: source seed live-fetch gate consumes the v13-l seed packet and optional runtime receipts, validates receipt scope/weakness/kind binding, HTTPS/status/method/header/timestamp provenance, and route/jump zero, while keeping release blocked unless all source/review/authority receipts and underlying claim evidence are complete.
v13-n: external benchmark official source acquisition gate consumes v13-m/v13-l source seeds and optionally performs runner-owned acquisition of RULER, LongBench, and RULER arXiv authority metadata, while keeping benchmark results and release blocked until query/result/evaluator evidence exists.
v14-a: runner-owned query/result/evaluator runner materializes public-codebase RouteQA queries, includes the canonical query file at `benchmarks/public-codebase-routeqa-v1/queries.jsonl`, copies or autodiscovers v13 source-chain rows, binds or live-fetches official repo HEAD source snapshots, can use a runner-owned snapshot as the query repo, builds an mmap store with `route_memory_store.bin`, `route_index.bin`, `chunk_offsets`, and `store_manifest.csv`, hash-binds query materialization in `dataset/dataset_manifest.json`, emits raw predictions plus `predictions/prediction_status.json`, runs the evaluator plus `evaluator/evaluator_status.json`, writes metrics/routeqa/benchmark/evidence/promotion rows and `evidence/run_invocation.json` plus `evidence/requested_outputs_manifest.json`, `evidence/run_layout_manifest.json`, `evidence/objective_requirements_manifest.json`, source-chain CSV mirrors under `evidence/`, and `evidence/execution_chain_manifest.json`, optionally emits RULER-compatible NIAH dataset/prediction/evaluator artifacts plus official evaluator invocation status, invokes official RULER `scripts/data/prepare.py` for three official NIAH tasks and nine generated rows, mmap-verifies those generated inputs through `benchmark/ruler_synthetic/official_generator_store/`, can also run a LongBench v2 multiple-choice official-source smoke through `result.py`, can fetch 12 canonical LongBench v2 dataset-server rows for a non-oracle baseline sample, normalizes those rows into run-level `benchmark/external_benchmark_rows.csv`, aggregates `benchmark/external_benchmark_metrics.json`, hash-binds `benchmark/external_benchmark_manifest.json`, row-binds `benchmark/external_benchmark_execution_chain_manifest.json`, and keeps real external benchmark/release blocked because the current live RULER/LongBench evidence is runner-owned smoke/sample execution rather than independent RULER/LongBench benchmark execution.
v14-b-lite: prediction-lineage proof over v14-a is implemented and covered by `experiments/test_v14b_lite_prediction_lineage.sh`. The runner emits prediction lineage/source summary artifacts, mmap/candidate traces, RouteMemory prediction evidence rows, a 50-row RouteQA-mini lightweight benchmark, Stage 8.2-L shortcut/corruption negative rows, tiny generator-hint NLG rows under `nlg/` plus grounding evidence, explicit `query/`, `mmap/`, and `prediction/` alias artifacts for the Stage 10-Lite output tree, and a CPU-canonical RX 6900XT/32GB/500GB-lite resource envelope. The smoke proves `prediction_lineage_ready=1`, `no_extractor_prediction_ready=1`, `promoted_prediction_rows == promoted_route_memory_prediction_rows`, `shortcut_negative_suite_ready=1`, `hash_clean_wrong_span_block=1`, `corrupted_route_index_block=1`, `corrupted_chunk_offsets_block=1`, `generator_hint_nlg_ready=1`, `resource_envelope_ready=1`, `run_layout_ready=1`, `objective_requirements_ready=1`, and `execution_chain_manifest_ready=1`, while keeping real external benchmark and release flags blocked.
v14-c: baseline-comparison boundary over v14-b-lite is implemented and covered by `experiments/test_v14c_baseline_comparison.sh`. The runner compares input extractor, BM25/lexical retrieval, RouteMemory retrieval-only, RouteMemory exact value read, RouteMemory plus proposal hint, and tiny generator-hint NLG on the same 50-row RouteQA-mini package plus shortcut negatives, emits `benchmark/baseline_comparison_rows.csv`, `benchmark/baseline_negative_case_rows.csv`, `metrics/baseline_comparison_metrics.json`, `resource/baseline_latency_rows.csv`, and `promotion/baseline_promotion_guard_rows.csv`, proves `baseline_comparison_ready=1`, `route_memory_safety_dominates_baselines=1`, `input_extractor_baseline_only=1`, and `baseline_promotion_guard_ready=1`, while keeping real external benchmark and release flags blocked.
v14-d: RouteQA-mini 100/150 row scale boundary over v14-c is implemented and covered by `experiments/test_v14d_routeqa_mini_scale.sh`. The scale runner executes 100-row and 150-row CPU/mmap runs with prediction lineage, generator-hint NLG, shortcut negatives, baseline comparison, and resource envelope enabled; aggregates `results/v14d_routeqa_mini_scale_summary.csv` and `results/v14d_routeqa_mini_scale_decision.csv`; verifies exact query/lineage/NLG/grounding row counts for both target sizes, six baseline comparison rows, 66 baseline negative-case rows, manifest-bound artifacts, zero route/jump rates, run-layout/objective/execution-chain readiness, and blocked candidate external benchmark/release flags.
v14-e: RULER NIAH-lite runner-owned smoke over v14-d is implemented and covered by `experiments/test_v14e_ruler_niah_lite.sh`. The runner emits RULER-compatible NIAH-lite dataset/prediction/evaluator rows, derives the answer through `benchmark/ruler_synthetic/compatible_niah_store/` mmap reads, writes `ruler_compatible_benchmark_rows.csv`, `ruler_compatible_metrics.json`, and `ruler_compatible_prediction_provenance.csv`, normalizes one ready runner-owned external benchmark row with external execution-chain binding, proves `runner_owned_external_benchmark_result_ready=1`, and keeps candidate external benchmark, real external benchmark, and release flags blocked.
v15-a: independent reproduction mechanics package over v14-b/v14-c/v14-d/v14-e is implemented and covered by `experiments/test_v15a_independent_reproduction_package.sh`. The package runner regenerates the v14 boundary outputs, assembles `results/v15a_independent_reproduction_package/package_001/`, writes `REPRODUCE.sh`, expected summary/decision CSVs, frozen query sets, source snapshot rows/manifests, resource envelopes, run sha256 manifests, `artifact_manifest.csv`, `environment_manifest.json`, `docs/FAILURE_MODES.md`, and `docs/WHAT_THIS_DOES_NOT_CLAIM.md`, verifies package/stage readiness and artifact hashes, and keeps candidate external benchmark, real external benchmark, and release flags blocked.
v15-b: nonfixture review / independent rerun evidence mechanics over v15-a is implemented and covered by `experiments/test_v15b_nonfixture_review_independent_rerun.sh`. The review runner regenerates v15-a, executes the package `REPRODUCE.sh`, captures command stdout/stderr hashes, binds reviewer identity and rerun environment, records v15-a package hashes, copies expected and rerun summaries, emits `metric_deltas/metric_delta_rows.csv`, `review/review_rows.csv`, `artifact_manifest.csv`, and `review_manifest.json`, proves `nonfixture_review_package_ready=1` and `independent_rerun_mechanics_ready=1`, and keeps external independent reviewer, candidate external benchmark, real external benchmark, and release flags blocked.
v16: research publication track plus commercial local QA/audit prototype contract over v15-b is implemented and covered by `experiments/test_v16_research_commercial_tracks.sh`. The packet runner assembles `results/v16_research_commercial_tracks/packet_001/`, copies v14-b/v14-c/v14-d/v14-e/v15-a/v15-b summary inputs, emits `research_publication_packet.md`, `research_evidence_matrix.csv`, `claim_boundary_matrix.csv`, `commercial_local_qa_audit_contract.md`, `commercial_acceptance_rows.csv`, `artifact_manifest.csv`, and `v16_manifest.json`, proves `research_publication_track_ready=1`, `commercial_local_qa_audit_prototype_ready=1`, and `claim_boundaries_ready=1`, while keeping candidate external benchmark, real external benchmark, and release flags blocked.
v17: post-v16 externalization handoff over v16 is implemented and covered by `experiments/test_v17_post_v16_externalization_handoff.sh`. The handoff runner assembles `results/v17_post_v16_externalization_handoff/package_001/`, copies v15-a/v15-b/v16 baseline inputs, prepares `third_party_rerun/EXTERNAL_REPRODUCE.sh`, external rerun required-artifact and manifest templates, official benchmark reconciliation requirements and candidate-result template, commercial local PoC domain intake and acceptance criteria, plus a handoff artifact manifest. It proves `third_party_rerun_handoff_ready=1`, `official_benchmark_reconciliation_intake_ready=1`, and `commercial_local_poc_intake_ready=1`, while keeping `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, real benchmark, and release flags blocked.
v18: supplied external evidence intake verifier over v17 is implemented and covered by `experiments/test_v18_external_evidence_intake.sh` and `experiments/test_v18_external_evidence_intake_with_fixtures.sh`. The default verifier run emits `results/v18_external_evidence_intake/intake_001/track_intake_rows.csv`, `intake_manifest.json`, and `artifact_manifest.csv` while keeping third-party rerun, official benchmark, commercial PoC, real external benchmark, and release flags blocked when no external directories are supplied. The fixture smoke proves the same verifier can accept synthetic directories for `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR`; those fixture flags are test-only and do not constitute real external readiness.
v19: external submission bundle over v18 is implemented and covered by `experiments/test_v19_external_submission_bundle.sh`. The runner assembles `results/v19_external_submission_bundle/bundle_001/`, copies v17/v18 source manifests, prepares third-party clean-machine rerun submission files, official benchmark slice requirements, commercial local evidence-bound QA/audit PoC intake files, v18 intake commands, `track_rows.csv`, `submission_manifest.json`, `artifact_manifest.csv`, and `docs/POST_V18_RESEARCH_ROADMAP.md`. It proves `submission_bundle_ready=1`, `third_party_submission_ready=1`, `official_benchmark_submission_ready=1`, and `commercial_poc_submission_ready=1`, while keeping `independent_rerun_actual_ready=0`, `candidate_external_benchmark_result_ready=0`, `closed_corpus_poc_actual_ready=0`, real benchmark, and release flags blocked.
v20: external return tracker over v19/v18 is implemented and covered by `experiments/test_v20_external_return_tracker.sh`. The runner assembles `results/v20_external_return_tracker/tracker_001/`, reruns the v19 submission bundle, forwards optional returned directories through `V20_THIRD_PARTY_RERUN_DIR`, `V20_OFFICIAL_BENCHMARK_DIR`, and `V20_COMMERCIAL_POC_DIR` into the v18 verifier, and writes `return_requirement_rows.csv`, `blocker_rows.csv`, `next_action_rows.csv`, `RETURN_TRACKER.md`, `return_tracker_manifest.json`, and `artifact_manifest.csv`. The default no-return path proves the tracker is ready while keeping all actual/candidate/release flags blocked and making the missing external return directories explicit.
v21: external review dispatch kit over v20 is implemented and covered by `experiments/test_v21_external_review_dispatch_kit.sh`. The runner assembles `results/v21_external_review_dispatch_kit/dispatch_001/`, reruns the v20 tracker, copies v19/v20 source manifests and return templates, writes reviewer-facing third-party rerun, official benchmark, and commercial local QA/audit request files, a reviewer packet index, return directory layout, tracker summary, `verification/VERIFY_RETURN_COMMANDS.sh`, `dispatch_manifest.json`, and `artifact_manifest.csv`. It proves the dispatch packet is ready for external reviewers while keeping actual rerun, candidate benchmark, commercial PoC, real benchmark, and release flags blocked.
v22: clean-machine execution kit over v21 is implemented and covered by `experiments/test_v22_clean_machine_execution_kit.sh`. The runner assembles `results/v22_clean_machine_execution_kit/kit_001/`, reruns the v21 dispatch kit, writes host/container clean-machine runbooks, a minimal `Containerfile.clean-machine`, `CAPTURE_THIRD_PARTY_RERUN.sh`, reviewer and environment templates, official benchmark and commercial PoC return manifest templates, execution notes, verification notes, `clean_machine_execution_manifest.json`, and `artifact_manifest.csv`. The capture script copies v15-b metric delta rows and review rows into the returned directory when the rerun succeeds, and hosted clean-machine runs now record a bounded `CAPTURE_TIMEOUT_SECONDS` window plus start/finish diagnostics. The remaining third-party actual blockers are reviewer identity and clean-machine independence rather than missing metric/review files. It improves the real third-party rerun path while keeping independent rerun, candidate benchmark, closed-corpus PoC, real benchmark, and release flags blocked until non-fixture returns are supplied.
v23: official benchmark reconciliation kit over v22 is implemented and covered by `experiments/test_v23_official_benchmark_reconciliation_kit.sh`. The runner assembles `results/v23_official_benchmark_reconciliation_kit/kit_001/`, reruns the v22 kit, writes an official-slice reconciliation runbook, return directory layout, evaluator/container contract, no-oracle/no-raw-input-extractor contract, raw prediction and RouteMemory-derived prediction-lineage templates, metrics/provenance/reproducibility templates, `verification/CHECK_OFFICIAL_RETURN_FILES.sh`, `verification/VERIFY_WITH_V20.md`, `official_benchmark_reconciliation_manifest.json`, and `artifact_manifest.csv`. It improves the candidate external benchmark path while keeping candidate benchmark, real benchmark, and release flags blocked until returned official evidence is supplied.
v24: external handoff send/receive/verify packet over v21/v22/v18 is implemented and covered by `experiments/test_v24_external_handoff_send_receive_verify.sh`. The runner assembles `results/v24_external_handoff_send_receive_verify/handoff_001/`, reruns the v22 kit and v18 intake, writes the exact send packet path for v21 dispatch plus v22 clean-machine execution kit, return inbox expectations for third-party, official benchmark, and commercial PoC returns, direct v18 verification commands using `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR`, `handoff_rows.csv`, `CURRENT_BLOCKERS.md`, `handoff_manifest.json`, and `artifact_manifest.csv`. It is the current operational handoff packet while keeping all actual/candidate/release flags blocked until a real return directory is supplied.
v25: outbound send manifest over v24 is implemented and covered by `experiments/test_v25_outbound_send_manifest.sh`. The runner assembles `results/v25_outbound_send_manifest/packet_001/`, reruns v24, writes `outbound/OUTBOUND_FILE_MANIFEST.csv`, `outbound/OUTBOUND_SHA256SUMS.txt`, outbound send instructions for the v21 dispatch kit plus v22 clean-machine kit, receiver acknowledgement template, return options, direct v18 verification instructions, source manifests, `outbound_send_manifest.json`, and `artifact_manifest.csv`. It verifies outbound send packet integrity while keeping all actual/candidate/release flags blocked until a real return directory is supplied.
v26: external send bundle over v25 is implemented and covered by `experiments/test_v26_external_send_bundle.sh`. The runner assembles `results/v26_external_send_bundle/bundle_001/`, reruns v25, copies every outbound v21 dispatch-kit and v22 clean-machine-kit file into `send_bundle/`, writes `send_bundle/BUNDLE_FILE_MANIFEST.csv`, `send_bundle/BUNDLE_SHA256SUMS.txt`, `SEND_BUNDLE_README.md`, direct v18 return verification notes, source manifests, `send_bundle_manifest.json`, and `artifact_manifest.csv`. It creates one auditable directory to send outward while keeping all actual/candidate/release flags blocked until a real return directory is supplied.
v27: external send archive over v26 is implemented and covered by `experiments/test_v27_external_send_archive.sh`. The runner assembles `results/v27_external_send_archive/archive_001/`, reruns v26, creates `archive/v26_external_send_bundle_bundle_001.tar.gz`, writes `archive/ARCHIVE_SHA256SUMS.txt`, `archive/ARCHIVE_FILE_LIST.txt`, `SEND_ARCHIVE_README.md`, direct v18 return verification notes, source manifests, `send_archive_manifest.json`, and `artifact_manifest.csv`. It creates a transfer-friendly archive for the outbound packet while keeping all actual/candidate/release flags blocked until a real return directory is supplied.
v28: inbound return inbox over v27/v18 is implemented and covered by `experiments/test_v28_inbound_return_inbox.sh`. The runner assembles `results/v28_inbound_return_inbox/inbox_001/`, creates standard inbox paths for `third_party_return`, `official_return`, and `commercial_return`, writes `inbox_rows.csv`, `INBOUND_RETURN_INBOX.md`, `verify/VERIFY_INBOX_WITH_V18.sh`, mirrors the latest v18 intake manifest and summary, and writes `inbound_return_inbox_manifest.json` plus `artifact_manifest.csv`. Empty placeholder directories are not passed to v18 as supplied evidence; all actual/candidate/release flags stay blocked until real returned files are present and v18 verifies them.
v29: receiver-side return preflight over v28 is implemented and covered by `experiments/test_v29_receiver_return_preflight.sh`. The runner assembles `results/v29_receiver_return_preflight/preflight_001/`, reruns v28, checks default or supplied receiver return directories through `V29_THIRD_PARTY_RETURN_DIR`, `V29_OFFICIAL_RETURN_DIR`, and `V29_COMMERCIAL_RETURN_DIR`, writes `receiver/preflight_rows.csv`, `receiver/missing_file_rows.csv`, `receiver/RECEIVER_RETURN_PREFLIGHT.md`, `verify/VERIFY_AFTER_PREFLIGHT.md`, source manifests, `receiver_return_preflight_manifest.json`, and `artifact_manifest.csv`. It makes missing returned files explicit before v18 verification while keeping all actual/candidate/release flags blocked until non-fixture returned directories pass v18.
v30: commercial codebase QA closed-corpus PoC return over v29/v18 is implemented and covered by `experiments/test_v30_commercial_codebase_poc_return.sh`. The runner assembles `results/v30_commercial_codebase_poc_return/return_001/commercial_return/`, binds four source-cited repository QA rows to current worktree hashes, writes domain and corpus manifests, `query_set.csv`, `poc_result_rows.csv`, `audit_trail.csv`, `resource_envelope.json`, `privacy_review.json`, `acceptance_review.csv`, source manifests, `commercial_codebase_poc_manifest.json`, and artifact hashes. The smoke verifies that v29 sees the commercial return as complete and v18 raises `closed_corpus_poc_actual_ready=1`, while keeping third-party rerun, official benchmark, real external benchmark, and release flags blocked.
v31: official RULER NIAH candidate return over v30/v18 is implemented and covered by `experiments/test_v31_official_ruler_niah_candidate_return.sh`. The runner assembles `results/v31_official_ruler_niah_candidate_return/return_001/official_return/`, live-binds the current `NVIDIA/RULER` HEAD, downloads and hashes upstream `scripts/data/prepare.py`, `scripts/eval/evaluate.py`, and `README.md`, writes `official_source_snapshot.json`, `official_evaluator_status.json`, `raw_predictions.jsonl`, `prediction_lineage.jsonl`, `metrics.json`, `provenance_manifest.json`, `reproducibility_package_manifest.json`, `candidate_result_rows.csv`, and artifact manifests. The smoke verifies v29 official-return completeness and v18/v20 readiness with `candidate_external_benchmark_result_ready=1` plus v30 `closed_corpus_poc_actual_ready=1`, while keeping third-party rerun, real external benchmark, and release flags blocked.
v32: GitHub Actions third-party rerun kit over v31/v22/v18 is implemented and covered by `experiments/test_v32_github_actions_third_party_rerun_kit.sh`. The kit adds `.github/workflows/third-party-rerun.yml`, which runs the v22 capture script on a GitHub-hosted `ubuntu-24.04` runner, fills reviewer/environment provenance, invokes v18 against the generated return directory, and uploads the return artifact with `actions/upload-artifact@v4`. The runner assembles `results/v32_github_actions_third_party_rerun_kit/kit_001/` with workflow copy, run/download/verify instructions, manifest, and artifact hashes. PR run `27029089994` returned the GitHub Actions artifact; local v18 intake with that v32 return plus v31 and v30 verifies `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `closed_corpus_poc_actual_ready=1`, and `real_external_benchmark_verified=1` while release readiness remains blocked.
v33: evidence-closure packet over v32/v31/v30/v18 is implemented and covered by `experiments/test_v33_evidence_closure_packet.sh`. The runner assembles `results/v33_evidence_closure_packet/packet_001/`, reruns v18 against the latest downloaded GitHub Actions third-party return plus the v31 official candidate return and v30 commercial PoC return, copies the v18 summary/decision/intake files plus the three evidence return directories, writes `CLAIM_BOUNDARY.md`, `human_review/HUMAN_REVIEW_REQUEST.md`, `human_review/human_review_template.csv`, `evidence_closure_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v33_evidence_closure_packet_ready=1`, `real_external_benchmark_verified=1`, `human_review_completed=0`, and `real_release_package_ready=0`.
v34: official benchmark expansion packet over v33/v31/v18 is implemented and covered by `experiments/test_v34_official_benchmark_expansion_packet.sh`. The runner assembles `results/v34_official_benchmark_expansion_packet/packet_001/`, expands the v31 official RULER NIAH candidate from 1 to 6 raw prediction rows at the same 4096-token context length, reuses the official source snapshot and evaluator digest, writes RouteMemory lineage, expansion metrics, candidate result rows, `EXPANSION_BOUNDARY.md`, `benchmark_expansion_manifest.json`, and `sha256_manifest.csv`, then reruns v18 with the v34 official return plus the v33 third-party/commercial evidence. The smoke verifies `v34_official_benchmark_expansion_packet_ready=1`, `candidate_external_benchmark_expansion_ready=1`, `real_external_benchmark_verified=1`, `oracle_prediction_used=0`, and `raw_input_extractor_used=0`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v35: commercial pilot packet over v34/v33/v18 is implemented and covered by `experiments/test_v35_commercial_pilot_packet.sh`. The runner assembles `results/v35_commercial_pilot_packet/packet_001/`, reuses the v30 commercial-return schema for an `internal_docs` buyer-visible workflow, writes five source-cited internal-docs QA rows including one release-claim abstain row, privacy/resource/acceptance reviews, `COMMERCIAL_PILOT_BOUNDARY.md`, `commercial_pilot_manifest.json`, and `sha256_manifest.csv`, then reruns v18 with v33 third-party evidence, the v34 official expansion return, and the v35 commercial pilot return. The smoke verifies `v35_commercial_pilot_packet_ready=1`, `closed_corpus_poc_actual_ready=1`, `real_external_benchmark_verified=1`, and a supported `internal_docs` domain while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v36: release-claim audit packet over v33/v34/v35 is implemented and covered by `experiments/test_v36_release_claim_audit_packet.sh`. The runner assembles `results/v36_release_claim_audit_packet/packet_001/`, copies v33/v34/v35 evidence manifests, summaries, decisions, and claim boundaries, writes `claim_matrix.csv`, `evidence_input_rows.csv`, `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`, `human_review/HUMAN_REVIEW_REQUEST.md`, `human_review/human_review_template.csv`, `v36_release_claim_audit_manifest.json`, and `sha256_manifest.csv`, and decides the maximum allowed public claim. The smoke verifies `v36_release_claim_audit_packet_ready=1`, `evidence_inputs_ready=1`, `maximum_allowed_claim_decided=1`, and `human_review_request_ready=1`; the allowed claim is bounded to local evidence-bound QA/audit with deterministic provenance, source-cited answers, conservative abstention, and externally reproducible evidence packets, while `human_review_completed=0`, `real_release_package_ready=0`, release-ready product, general LLM replacement, Transformer replacement, frontier long-context solved, and GPU acceleration claims remain blocked.
v37: human review intake verifier over v36 is implemented and covered by `experiments/test_v37_human_review_intake.sh`. The runner assembles `results/v37_human_review_intake/intake_001/`, copies the v36 human-review request/template, consumes an optional returned `human_review_rows.csv`, normalizes the four required review items, checks reviewer identity, timestamps, and all-pass status, writes `human_review_intake_manifest.json`, `normalized_human_review_rows.csv`, `missing_review_rows.csv`, and `sha256_manifest.csv`, and keeps release readiness separate. The default current run verifies `v37_human_review_intake_ready=1` while keeping `human_review_return_supplied=0`, `human_review_completed=0`, and `real_release_package_ready=0`; the smoke also exercises an isolated fixture pass path that can set `evidence_set_human_review_accepted=1` without changing the default no-return summary.
v38: human review dispatch bundle over v37/v36 is implemented and covered by `experiments/test_v38_human_review_dispatch_bundle.sh`. The runner assembles `results/v38_human_review_dispatch_bundle/bundle_001/`, copies the v36 review request, release audit, claim matrix, decision rows, evidence-input rows, v36/v37 manifests, and missing-review rows into `review_packet/`, prepares `return/human_review_rows.csv`, writes `verify/VERIFY_RETURN.sh`, `HUMAN_REVIEW_DISPATCH_README.md`, `dispatch_rows.csv`, `human_review_dispatch_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v38_human_review_dispatch_bundle_ready=1`, `return_template_ready=1`, and `verify_script_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v39: human review dispatch archive over v38 is implemented and covered by `experiments/test_v39_human_review_dispatch_archive.sh`. The runner assembles `results/v39_human_review_dispatch_archive/archive_001/`, archives the v38 bundle as `archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz`, writes `archive/ARCHIVE_SHA256SUMS.txt`, `archive/ARCHIVE_FILE_LIST.txt`, `SEND_ARCHIVE_README.md`, `artifact_manifest.csv`, `human_review_dispatch_archive_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v39_human_review_dispatch_archive_ready=1`, `archive_sha256_ready=1`, `archive_file_list_ready=1`, and required review/return/verify archive members present while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v40: machine-verified research artifact over v33-v39 is implemented and covered by `experiments/test_v40_machine_verified_research_artifact.sh`. The runner assembles `results/v40_machine_verified_research_artifact/artifact_001/`, copies the v36 release-claim audit, v37 no-return human-review intake state, v38 dispatch bundle evidence, v39 transfer archive evidence, and v33/v34/v35 support summaries, then writes `MACHINE_VERIFIED_RESEARCH_ARTIFACT.md`, `release_mode_rows.csv`, `allowed_claim_rows.csv`, `blocked_claim_rows.csv`, `machine_verification_rows.csv`, `evidence_index.csv`, `v40_machine_verified_research_artifact_manifest.json`, `artifact_manifest.csv`, and `sha256_manifest.csv`. The smoke verifies `v40_machine_verified_research_artifact_ready=1`, `automated_research_artifact_ready=1`, `machine_verified_prototype_ready=1`, and `machine_verification_ready=1` for the clean-runner, v18 intake, RouteMemory-lineage, no-oracle/no-extractor, and closed-corpus PoC support set, while explicitly keeping `human_review_completed=0`, `human_review_required_for_public_release=1`, and `real_release_package_ready=0`; human-reviewed release, production readiness, Transformer/general LLM replacement, frontier long-context, GPU acceleration, and full commercial deployment claims remain blocked.
v41: RULER NIAH 50-row scale over v34/v33/v18 is implemented and covered by `experiments/test_v41_ruler_niah_50row_scale.sh`. The runner assembles `results/v41_ruler_niah_50row_scale/scale_001/`, runs the v34 expansion engine with 50 rows at the fixed 4096 context length, preserves official evaluator/source reuse, writes `V41_RULER_NIAH_50ROW_BOUNDARY.md`, `scale_rows.csv`, `v41_ruler_niah_50row_scale_manifest.json`, and `sha256_manifest.csv`, and verifies 50 raw predictions, 50 RouteMemory lineage rows, no-oracle/no-raw-input-extractor status, v18 intake, and release blocking. The smoke verifies `v41_ruler_niah_50row_scale_ready=1`, `row_count_ready=1`, `same_context_length=1`, `route_memory_prediction_lineage_ready=1`, `no_oracle_no_extractor_ready=1`, and `v18_verified=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v42: Codebase Auditor 200-query over v18 is implemented and covered by `experiments/test_v42_codebase_auditor_200query.sh`. The runner assembles `results/v42_codebase_auditor_200query/audit_001/`, selects tracked repository source files, writes 200 source-cited local codebase QA/audit query rows, 200 PoC result rows, 200 audit-trail rows, at least 20 abstain rows for unsupported readiness/replacement claims, guard negative rows for corrupted citations and unsupported direct answers, and the v18 commercial-return files under `commercial_return/`. It writes `V42_CODEBASE_AUDITOR_BOUNDARY.md`, `auditor_rows.csv`, `guard_negative_rows.csv`, `source_manifests/codebase_auditor_source_rows.csv`, `v42_codebase_auditor_manifest.json`, and `sha256_manifest.csv`, then verifies the return through v18. The smoke verifies `v42_codebase_auditor_200query_ready=1`, `query_rows=200`, `poc_result_rows=200`, `wrong_answer_guard_pass_rows=200`, `citation_accuracy_pass_rows=200`, `abstain_behavior_pass_rows=200`, `audit_trail_bound_rows=200`, `guard_negative_rows=3`, `guard_negative_block_rows=3`, `privacy_review_ready=1`, `resource_envelope_ready=1`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v43: Doc-Code Conflict Detection over v42/v18 is implemented and covered by `experiments/test_v43_doc_code_conflict_detection.sh`. The runner assembles `results/v43_doc_code_conflict_detection/detection_001/`, derives implementation facts from v42 readiness evidence, creates a bounded doc-code conflict corpus, writes `detection_case_rows.csv`, `conflict_rows.csv`, `source_span_rows.csv`, `V43_DOC_CODE_CONFLICT_BOUNDARY.md`, `v43_doc_code_conflict_manifest.json`, and `sha256_manifest.csv`, then verifies the detector return through v18. The smoke verifies `v43_doc_code_conflict_detection_ready=1`, `conflict_rows=8`, `consistent_rows=4`, `total_cases=12`, `correct_rows=12`, `supporting_source_spans_ready=1`, `conflict_detection_precision_ready=1`, `conflict_detection_recall_ready=1`, `wrong_answer_guard_pass_rows=12`, `citation_accuracy_pass_rows=12`, `audit_trail_rows=12`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`. The boundary limits the result to the bounded v43 audit corpus and does not claim unresolved production defects across the full repository.
v44: Tiny Non-Attention Generator Hint over v43/v18 is implemented and covered by `experiments/test_v44_tiny_non_attention_generator_hint.sh`. The runner assembles `results/v44_tiny_non_attention_generator_hint/generator_001/`, writes RouteHint payload rows, generator input rows with `attention_layers=0`, `transformer_blocks=0`, `raw_prompt_context_appended=0`, and `raw_prompt_context_bytes=0`, grounded transcript rows, missing-query abstain rows, `V44_TINY_GENERATOR_HINT_BOUNDARY.md`, `v44_tiny_generator_manifest.json`, and `sha256_manifest.csv`, then verifies the return through v18. The smoke verifies `v44_tiny_non_attention_generator_hint_ready=1`, `generator_rows=10`, `grounded_answer_rows=10`, `abstain_rows=2`, `route_hint_used_rows=10`, `raw_prompt_context_appended_rows=0`, `no_raw_prompt_stuffing_ready=1`, `non_attention_generator_ready=1`, `answer_grounded_rate=1.000000`, `span_citation_accuracy=1.000000`, `wrong_answer_rate=0.000000`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v45: LongBench v2 small slice over v44/v18 is implemented and covered by `experiments/test_v45_longbench_v2_small_slice.sh`. The runner assembles `results/v45_longbench_v2_small_slice/slice_001/`, snapshots THUDM/LongBench official source/evaluator files, writes `official_return/` with 6 LongBench-v2 multiple-choice raw prediction rows across 6 task categories, 6 RouteMemory prediction-lineage rows, `official_source_snapshot.json`, `official_evaluator_status.json`, `metrics.json`, `provenance_manifest.json`, `reproducibility_package_manifest.json`, and `candidate_result_rows.csv`, then verifies the official return through v18. The smoke verifies `v45_longbench_v2_small_slice_ready=1`, `official_source_snapshot_ready=1`, `official_evaluator_ready=1`, `raw_prediction_rows=6`, `prediction_lineage_rows=6`, `task_categories=6`, `route_memory_prediction_lineage_ready=1`, `oracle_prediction_used=0`, `raw_input_extractor_used=0`, and `v18_candidate_external_benchmark_result_ready=1`, while keeping `real_external_benchmark_verified=0`, `human_review_completed=0`, and `real_release_package_ready=0`.
v46: Source-Verified Scorer mainline over v45/v18 is implemented and covered by `experiments/test_v46_source_verified_scorer_mainline.sh`. The runner assembles `results/v46_source_verified_scorer_mainline/scorer_001/`, writes 12 source-bound label rows from v45 official benchmark evidence, `source_verified_scorer_model.json`, `scorer_eval_rows.csv`, `V46_SOURCE_VERIFIED_SCORER_BOUNDARY.md`, `v46_source_verified_scorer_manifest.json`, and `sha256_manifest.csv`, then verifies a commercial return through v18. The smoke verifies `v46_source_verified_scorer_mainline_ready=1`, `source_verified_label_rows=12`, `source_bound_label_rows=12`, `local_teacher_harness_labels_used=0`, `scorer_model_ready=1`, `eval_query_rows=6`, `baseline_top1_accuracy=0.000000`, `scorer_top1_accuracy=1.000000`, `ranking_improvement_ready=1`, `wrong_candidate_guard_rate=1.000000`, `wrong_candidate_guard_ready=1`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v47: Offline Domain Policy Update over v46/v18 is implemented and covered by `experiments/test_v47_offline_domain_policy_update.sh`. The runner assembles `results/v47_offline_domain_policy_update/policy_001/`, writes `policy_source_rows.csv`, `offline_domain_policy_rows.csv`, `offline_domain_policy.json`, `V47_OFFLINE_DOMAIN_POLICY_BOUNDARY.md`, `v47_offline_domain_policy_manifest.json`, and `sha256_manifest.csv`, then verifies a commercial return through v18. The smoke verifies `v47_offline_domain_policy_update_ready=1`, `policy_rows=15`, `domain_count=3`, `learning_target_count=5`, `candidate_selection_rows=3`, `span_read_rows=3`, `hint_strength_rows=3`, `abstain_retry_rows=3`, `verifier_decision_rows=3`, `offline_only=1`, `external_network_used=0`, `expert_replacement_claim=0`, `release_ready_claim=0`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v48: Multi-Domain RouteHint Generator evidence is implemented and covered by `experiments/test_v48_multi_domain_generator_evidence.sh`. The runner assembles `results/v48_multi_domain_generator_evidence/run_001/`, writes `route_memory_evidence_rows.csv`, `compact_route_hint_rows.csv`, `tiny_generator_input_rows.csv`, `grounded_generation_rows.csv`, `V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md`, `v48_multi_domain_generator_manifest.json`, and `sha256_manifest.csv`, then verifies a commercial return through v18. The smoke verifies `v48_multi_domain_generator_evidence_ready=1`, `domain_count=4`, `generation_rows=24`, `abstain_rows=4`, `route_memory_evidence_rows=24`, `route_hint_used_rows=24`, `hint_value_transformed_rows=20`, `answer_equals_hint_value_rows=0`, `raw_span_text_copied_rows=0`, `grounded_answer_rows=24`, `citation_rows=24`, `audit_trail_rows=24`, `raw_context_in_hint_rows=0`, `raw_prompt_context_appended_rows=0`, `answer_grounded_rate=1.000000`, `span_citation_accuracy=1.000000`, `wrong_answer_rate=0.000000`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `real_release_package_ready=0`. It is an evidence-scale generation expansion, not an internal packaging layer.
v49: RULER NIAH 200/500-row scale is implemented and covered by `experiments/test_v49_ruler_niah_200_500_scale.sh`. The runner assembles `results/v49_ruler_niah_200_500_scale/scale_001/`, runs the v34 official benchmark expansion engine twice at fixed 4096 context length for 200 and 500 rows, writes copied v34 summaries/decisions/manifests, `scale_rows.csv`, `V49_RULER_NIAH_200_500_BOUNDARY.md`, `v49_ruler_niah_200_500_scale_manifest.json`, and `sha256_manifest.csv`, and verifies both expanded official returns through v18. The smoke verifies `v49_ruler_niah_200_500_scale_ready=1`, `target_200_ready=1`, `target_500_ready=1`, `rows_200=200`, `rows_500=500`, `lineage_rows_200=200`, `lineage_rows_500=500`, `context_length_fixed=1`, `architecture_fixed=1`, `official_evaluator_ready=1`, `route_memory_prediction_lineage_ready=1`, `no_oracle_no_extractor_ready=1`, and `v18_verified=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.
v50: Public Repo Auditor 3-repo evidence is implemented and covered by `experiments/test_v50_public_repo_auditor_3repo.sh`. The runner assembles `results/v50_public_repo_auditor_3repo/audit_001/`, checks out pinned commit SHAs for `pypa/sampleproject`, `psf/requests`, and `pallets/click`, binds public repo URLs, requested refs, HEAD SHAs, source hashes, source spans, independent detector outputs, and guard negative controls, writes `public_repo_source_snapshot_rows.csv`, `public_repo_audit_case_rows.csv`, `public_repo_source_span_rows.csv`, `guard_negative_rows.csv`, `V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md`, `v50_public_repo_auditor_manifest.json`, and `sha256_manifest.csv`, then verifies the public-repo auditor commercial return through v18. The smoke verifies `v50_public_repo_auditor_3repo_ready=1`, `repo_count=3`, `repo_refs_pinned=1`, `audit_case_rows=9`, `audit_type_count=3`, `doc_code_conflict_rows=3`, `deprecated_usage_rows=3`, `config_mismatch_rows=3`, `detected_doc_code_conflict_rows=1`, `detected_config_mismatch_rows=1`, `guard_negative_rows=3`, `guard_negative_block_rows=3`, `source_span_rows=18`, `public_repo_snapshot_ready=1`, and `v18_closed_corpus_poc_actual_ready=1`, while keeping `human_review_completed=0` and `real_release_package_ready=0`.

v51: Real-return Evidence Intake measured trace is implemented and covered by `experiments/test_v51_real_return_evidence_intake.sh`. The runner assembles `results/v51_real_return_evidence_intake/intake_001/`, measures CPU SHA-256 batch work and filesystem/NVMe-style reads over tracked repository source files, writes `measured_workload_trace/source_manifest.csv`, `environment.json`, `cpu_trace_rows.csv`, `nvme_trace_rows.csv`, and `workload_trace_rows.csv`, exposes three cited QA/audit rows through the v18 commercial-return schema, copies v18/v40 evidence summaries, writes `V51_REAL_RETURN_EVIDENCE_BOUNDARY.md`, `v51_real_return_evidence_manifest.json`, `measured_trace_artifact_rows.csv`, and `sha256_manifest.csv`, and keeps release language blocked. The smoke verifies `v51_real_return_evidence_intake_ready=1`, `measured_workload_trace_bound=1`, `real_return_evidence_axis_count=1`, `source_files>=12`, `cpu_trace_rows=7`, `nvme_trace_rows=7`, `non_fixture_workload_trace_rows=1`, `v18_closed_corpus_poc_actual_ready=1`, and `v40_machine_verified_research_artifact_ready=1`, while keeping `external_or_buyer_return_supplied=0`, `real_teacher_source_import_candidate_supplied=0`, `gpu_speedup_claim=deferred`, `human_review_completed=0`, and `real_release_package_ready=0`.

v0.3 Architecture Preview is implemented and covered by `experiments/test_v0_3_architecture_preview.sh`. `scripts/audit_my_repo.sh` turns a target repository into a local evidence-bound audit bundle with `AUDIT_REPORT.md`, JSONL/CSV findings, citation spans, RouteMemory lineage, mmap read trace, compact RouteHint rows, grounded generation rows, abstain rows, unsupported-claim rows, resource envelope, reproduce script, and sha256 manifest. `scripts/run_local_scaling_matrix.sh` emits the one-axis local scaling matrix with store-size, top-k, cache-budget, RouteHint-budget, and query-count curves plus active-byte, latency, resource, claim-boundary, and hash artifacts. `scripts/run_routehint_generator_mainline.sh` promotes the compact RouteHint/tiny non-attention generator path to a mainline preview wrapper. `examples/local_codebase_intelligence_box.sh` assembles `README_RESULT.md`, `AUDIT_REPORT.md`, `BASELINE_COMPARISON.md`, `LOCAL_SCALING_SUMMARY.md`, `ARCHITECTURE_TRACE.md`, lineage/citation/RouteHint/generation/abstain/resource artifacts, `reproduce.sh`, and `sha256sums.txt`. `experiments/run_v0_3_architecture_preview.sh` binds that user-facing bundle to the local scaling matrix and existing v14c baseline comparison artifacts, and emits an 8-row preview baseline overlay covering ripgrep literal search, BM25, small RAG boundary, tiny generator-only, RouteMemory retrieval-only, RouteMemory exact value-read, RouteMemory + compact RouteHint, and RouteMemory + scorer/offline policy. The smoke verifies `v0_3_architecture_preview_ready=1`, `one_command_repo_audit_ready=1`, `local_scaling_matrix_ready=1`, `scaling_axis_count=5`, `scaling_curve_rows=27`, `baseline_war_ready=1`, `baseline_rows=8`, `routehint_generator_mainline_ready=1`, `local_codebase_intelligence_box_ready=1`, `raw_prompt_context_bytes=0`, `attention_blocks=0`, `transformer_blocks=0`, `oracle_prediction_used=0`, and `raw_input_extractor_used=0`, while keeping `gpu_speedup_claim=deferred` and `real_release_package_ready=0`.

v52: LLM+RAG baseline war contract scaffold is implemented and covered by `experiments/test_v52_llm_rag_baseline_war.sh`. The runner assembles `results/v52_llm_rag_baseline_war/baseline_001/`, reruns the v0.3 architecture preview, writes an A-H `baseline_registry.csv`, shared `evaluation_contract_rows.csv`, `adapter_contract_rows.csv`, `score_axis_rows.csv`, copied source-preview artifacts, `V52_BASELINE_WAR_BOUNDARY.md`, `v52_llm_rag_baseline_war_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52_baseline_war_contract_ready=1`, `baseline_system_rows=8`, symmetric query/source/citation/abstain/wrong-answer/resource contract readiness, RouteHint no-raw-prompt-stuffing, and release blocking, while keeping `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `optional_100b_plus_baseline_status=deferred-with-reason` until real LLM+RAG rows are supplied.

v52b: Small local RAG measured row is implemented and covered by `experiments/test_v52b_small_local_rag_measured_row.sh`. The runner assembles `results/v52b_small_local_rag_measured_row/row_001/`, reruns the v50 public-repo seed, writes `small_local_rag_answer_rows.csv`, `small_local_rag_citation_rows.csv`, `small_local_rag_retrieval_rows.csv`, `small_local_rag_resource_rows.csv`, copied v50 source evidence, `V52B_SMALL_LOCAL_RAG_BOUNDARY.md`, `v52b_small_local_rag_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52b_small_local_rag_measured_row_ready=1`, `system_id=B`, nine measured answer rows, 18 citation rows, nonzero raw prompt context bytes, local/no-external-model execution, v50 seed binding, and `v52_absorb_ready=1`, while keeping `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `real_release_package_ready=0`.

v52f: Small local RAG measured 100-row expansion is implemented and covered by `experiments/test_v52f_small_local_rag_measured_100.sh`. The runner assembles `results/v52f_small_local_rag_measured_100/measured_001/`, reuses or reruns the v53d frozen canary query set, writes `source_manifest_rows.csv`, `small_local_rag_answer_rows.csv`, `small_local_rag_citation_rows.csv`, `small_local_rag_retrieval_rows.csv`, `small_local_rag_abstain_rows.csv`, `small_local_rag_wrong_answer_guard_rows.csv`, `small_local_rag_resource_rows.csv`, copied v53d source/query artifacts, `V52F_SMALL_LOCAL_RAG_100_BOUNDARY.md`, `v52f_small_local_rag_measured_100_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52f_small_local_rag_measured_100_ready=1`, `system_id=B`, 100 frozen query rows, 100 answer/citation/abstain/wrong-answer/resource rows, 300 retrieval rows, source manifest coverage, local/no-external-model execution, v53d query-set binding, and `v52_absorb_ready=1`, while keeping `v52_ready=0`, D/E evidence blockers, and release/comparison claims blocked until A/G/H and C/D/E are supplied over symmetric evidence.

v52g: Small local RAG measured 300-row expansion is implemented and covered by `experiments/test_v52g_small_local_rag_measured_300.sh`. The runner assembles `results/v52g_small_local_rag_measured_300/measured_001/`, reuses or reruns the v53e 1000-row canary query scale, freezes a stratified 300-row subset with 48 negative/abstain queries, writes `frozen_query_rows.csv`, `frozen_source_span_rows.csv`, `source_manifest_rows.csv`, `small_local_rag_answer_rows.csv`, `small_local_rag_citation_rows.csv`, `small_local_rag_retrieval_rows.csv`, `small_local_rag_abstain_rows.csv`, `small_local_rag_wrong_answer_guard_rows.csv`, `small_local_rag_resource_rows.csv`, copied v53e source/query artifacts, `V52G_SMALL_LOCAL_RAG_300_BOUNDARY.md`, `v52g_small_local_rag_measured_300_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52g_small_local_rag_measured_300_ready=1`, `system_id=B`, 300 frozen query/source rows, 300 answer/citation/abstain/wrong-answer/resource rows, 900 retrieval rows, source manifest coverage, negative/abstain preservation, local/no-external-model execution, v53e query-set binding, and `v52_absorb_ready=1`; at the v52g layer, B-1000, A/G/H same-query-set, C/D/E evidence, full v52, and release claims remained blocked.

v52h: Small local RAG measured 1000-row expansion is implemented and covered by `experiments/test_v52h_small_local_rag_measured_1000.sh`. The runner assembles `results/v52h_small_local_rag_measured_1000/measured_001/`, reuses or reruns the full v53e 1000-row canary query scale, writes `frozen_query_rows.csv`, `frozen_source_span_rows.csv`, `source_manifest_rows.csv`, `small_local_rag_answer_rows.csv`, `small_local_rag_citation_rows.csv`, `small_local_rag_retrieval_rows.csv`, `small_local_rag_abstain_rows.csv`, `small_local_rag_wrong_answer_guard_rows.csv`, `small_local_rag_resource_rows.csv`, copied v53e source/query artifacts, `V52H_SMALL_LOCAL_RAG_1000_BOUNDARY.md`, `v52h_small_local_rag_measured_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52h_small_local_rag_measured_1000_ready=1`, `system_id=B`, 1000 frozen query/source rows, 1000 answer/citation/abstain/wrong-answer/resource rows, 3000 retrieval rows, 160 negative/abstain rows, source manifest coverage, local/no-external-model execution, v53e full query-set binding, `v52-b-1000=pass`, and `v52_absorb_ready=1`, while keeping A/G/H same-query-set, C/D/E evidence, full v52, and release claims blocked.

v52i: A/B/G/H same-query measured 1000-row packet is implemented and covered by `experiments/test_v52i_abgh_same_query_measured_1000.sh`. The runner assembles `results/v52i_abgh_same_query_measured_1000/measured_001/`, reuses or reruns the full v53e 1000-row canary query scale, writes shared `frozen_query_rows.csv`, `frozen_source_span_rows.csv`, `source_manifest_rows.csv`, `abgh_system_rows.csv`, `abgh_answer_rows.csv`, `abgh_citation_rows.csv`, `abgh_retrieval_rows.csv`, `abgh_abstain_rows.csv`, `abgh_wrong_answer_guard_rows.csv`, `abgh_resource_rows.csv`, `routehint_rows.csv`, `abgh_system_metric_rows.csv`, copied v53e evidence, `V52I_ABGH_SAME_QUERY_BOUNDARY.md`, `v52i_abgh_same_query_measured_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52i_abgh_same_query_measured_1000_ready=1`, eight local systems A/B/G/H, 1000 shared query rows, 4000 answer/citation/abstain/wrong-answer/resource rows, 12000 retrieval rows, 2000 G/H RouteHint rows with raw context appending disabled, same query/source manifest coverage, local/no-external-model execution, and local v52 absorb readiness, while keeping C/D/E evidence, 30B/70B baselines, full v52, and release claims blocked.

v52j: Measured registry absorb is implemented and covered by `experiments/test_v52j_measured_registry_absorb.sh`. The runner assembles `results/v52j_measured_registry_absorb/registry_001/`, consumes v52i plus the C/D/E/F intake summaries, writes `measured_baseline_registry.csv`, `measured_artifact_absorb_rows.csv`, copied v52i evidence, C/D/E/F blocker summaries, `V52J_MEASURED_REGISTRY_BOUNDARY.md`, `v52j_measured_registry_absorb_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52j_measured_registry_absorb_ready=1`, A/B/G/H measured over the shared v53e query/source manifest, 4000 answer/citation/abstain/wrong-answer/resource rows absorbed, 2000 RouteHint rows absorbed, C/D/E missing evidence directories, F deferred, `v52_ready=0`, and release/comparison claims blocked.

v52c: 7B-14B local model + RAG evidence intake is implemented and covered by `experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh`. The runner assembles `results/v52c_7b14b_local_model_rag_evidence_intake/intake_001/`, reruns the v50 public-repo seed, writes `local_model_rag_required_field_rows.csv`, `local_model_rag_answer_template.csv`, `model_identity_template.json`, `local_model_rag_validation_rows.csv`, copied v50 source evidence, `V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md`, `v52c_7b14b_local_model_rag_manifest.json`, and `sha256_manifest.csv`. The smoke verifies the C evidence-intake schema, nine answer-template rows, local/no-network model identity template, hash manifest, and no-env stop rule, while keeping `supplied_evidence_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `real_release_package_ready=0` until a real 7B-14B local-model-RAG evidence directory is supplied and validates.

v52k: 7B-14B local model + RAG measured seed is implemented and covered by `experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh`. The runner uses local Ollama `qwen2.5:7b-instruct`, generates real baseline-C responses for the v50 9-query public-repo seed, writes `c_local_model_rag_evidence/model_identity.json`, `local_model_rag_answer_rows.csv`, `local_model_rag_citation_rows.csv`, `local_model_rag_resource_rows.csv`, `ollama_generation_transcript_rows.csv`, copied v52c validated evidence, `V52K_7B14B_LOCAL_MODEL_RAG_MEASURED_SEED_BOUNDARY.md`, `v52k_7b14b_local_model_rag_measured_seed_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52k_7b14b_local_model_rag_measured_seed_ready=1`, 9 answer rows, 18 source-span-bound citation rows, 9 resource rows, local/no-network execution, `supplied_evidence_ready=1`, `v52c_absorb_ready=1`, and 6/9 measured label accuracy, while keeping full C scale, D/E 30B/70B rows, full v52, and release claims blocked.

v52m: measured registry C absorb is implemented and covered by `experiments/test_v52m_measured_registry_c_absorb.sh`. The runner absorbs the v52i A/B/G/H measured packet plus the v52l C measured packet into an updated v52 measured registry, writes `measured_baseline_registry.csv`, `measured_artifact_absorb_rows.csv`, copied v52i/v52l evidence, `V52M_MEASURED_REGISTRY_C_ABSORB_BOUNDARY.md`, `v52m_measured_registry_c_absorb_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52m_measured_registry_c_absorb_ready=1`, five local measured systems A/B/C/G/H, 5000 answer/citation/abstain/guard/resource rows, `required_7b14b_baseline_ready=1`, and `c_strict_exact_label_accuracy=0.000000`, while keeping D/E 30B/70B rows, `v52_ready=0`, and release/comparison claims blocked.

v52n: 30B open-weight LLM+RAG measured seed is implemented and covered by `experiments/test_v52n_30b_open_weight_llm_rag_measured_seed.sh`. The runner uses local Ollama `qwen2.5:32b-instruct`, generates real baseline-D responses for the v50 9-query public-repo seed, writes `d_llm_rag_evidence/model_identity.json`, `llm_rag_answer_rows.csv`, `llm_rag_citation_rows.csv`, `llm_rag_resource_rows.csv`, `ollama_generation_transcript_rows.csv`, copied v52d validated evidence, `V52N_30B_OPEN_WEIGHT_LLM_RAG_MEASURED_SEED_BOUNDARY.md`, `v52n_30b_open_weight_llm_rag_measured_seed_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52n_30b_open_weight_llm_rag_measured_seed_ready=1`, 9 answer rows, 18 source-span-bound citation rows, 9 resource rows, local/no-network execution, `d_30b_supplied_evidence_ready=1`, and `v52d_absorb_ready=1`, while keeping full D scale, E 70B rows, full v52, and release claims blocked.

v52o: 70B open-weight LLM+RAG measured seed is implemented and covered by `experiments/test_v52o_70b_open_weight_llm_rag_measured_seed.sh`. The runner uses local Ollama `llama3.1:70b-instruct-q2_K`, generates real baseline-E responses for the v50 9-query public-repo seed, writes `e_llm_rag_evidence/…`, copied v52d validated evidence, `V52O_70B_OPEN_WEIGHT_LLM_RAG_MEASURED_SEED_BOUNDARY.md`, `v52o_70b_open_weight_llm_rag_measured_seed_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52o_70b_open_weight_llm_rag_measured_seed_ready=1`, 9 answer rows, 18 citation rows, 9 resource rows, local/no-external-API execution, `e_70b_supplied_evidence_ready=1`, and `v52d_absorb_ready=1`, while keeping full E scale, D 30B real row, full v52, and release claims blocked.

v52p: 30B open-weight LLM+RAG v53e 1000-row expansion is implemented and covered by `experiments/test_v52p_30b_open_weight_llm_rag_v53e_1000.sh`. The runner uses local Ollama `qwen2.5:32b-instruct` over the same frozen v53e 1000-query/source manifest used by v52i A/B/G/H, writes `d_answer_rows.csv`, `d_citation_rows.csv`, `d_retrieval_rows.csv`, `d_abstain_rows.csv`, `d_wrong_answer_guard_rows.csv`, `d_resource_rows.csv`, `ollama_generation_transcript_rows.csv`, `d_system_metric_rows.csv`, copied v53e evidence, `V52P_30B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md`, `v52p_30b_open_weight_llm_rag_v53e_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52p_30b_open_weight_llm_rag_v53e_1000_ready=1`, 1000 answer/citation/retrieval/abstain/wrong-answer/resource/transcript rows, same query/source manifest as v52i A/B/G/H, local/no-network execution, and `d_v53e_absorb_ready=1`. It records strict exact-label accuracy without turning that into a D quality claim; E 70B rows, full v52, and release claims remain blocked.

v52q: 70B open-weight LLM+RAG v53e 1000-row expansion is implemented and covered by `experiments/test_v52q_70b_open_weight_llm_rag_v53e_1000.sh`. Same as v52p but for system E with `llama3.1:70b-instruct-q2_K`, `e_*` row prefixes, and `e_v53e_absorb_ready=1`. D 30B rows, full v52, and release claims remain blocked.

v52s: local LLM weight tier contract is implemented and covered by `experiments/test_v52s_local_llm_weight_tier_contract.sh`. The runner emits an NVMe-mmap weight shard store (hot/warm/cold tiers, page table, prefetch trace, host profile) aligned with the h11-c RouteMemory store pattern via `experiments/run_v52s_local_llm_weight_tier_contract.sh`. The smoke verifies `v52s_local_llm_weight_tier_contract_ready=1` and `nvme_mmap_store_ready=1` while keeping `weight_tier_runtime_ready=0`, monolithic Ollama 30B/70B local measured rows, D/E absorb, `v52_ready=0`, and release claims blocked.

v52u: local LLM weight tier mmap reader is implemented and covered by `experiments/test_v52u_local_llm_weight_tier_mmap_reader.sh`. The runner mmap-opens the v52s hot/warm/cold weight shard store, verifies page headers and hashes, and emits mmap/decode scaffold rows following the v13-b reader ABI shape via `experiments/run_v52u_local_llm_weight_tier_mmap_reader.sh`. The smoke verifies `weight_tier_mmap_reader_ready=1` while keeping `weight_tier_runtime_ready=0`, ROCm kernel binding, D/E measured rows, `v52_ready=0`, and release claims blocked.

v52t: D/E local measured deferral is implemented and covered by `experiments/test_v52t_de_local_measured_deferral.sh`. The runner records explicit `deferred-with-reason` for local monolithic Ollama D/E measured rows on 16GB VRAM hosts, links v52s/v52u/v52v, and logs the aborted v52n attempt via `experiments/run_v52t_de_local_measured_deferral.sh`. The smoke verifies `v52t_de_local_measured_deferral_ready=1`, `weight_tier_mmap_reader_ready=1`, and `rocm_kernel_bind_ready=1` while keeping required 30B/70B baselines, `v52_ready=0`, and release claims blocked.

v52v: local LLM weight tier ROCm decode bind is implemented and covered by `experiments/test_v52v_local_llm_weight_tier_rocm_decode_bind.sh`. The runner sources `scripts/ollama_rocm_env.sh`, bootstraps HIP device libs when needed, compiles `experiments/assets/v52v_tier_hot_shard_axpy_probe.hip`, binds vram-hot decode scaffold rows from v52u, and records toolchain/env/bind artifacts via `experiments/run_v52v_local_llm_weight_tier_rocm_decode_bind.sh`. The smoke verifies `rocm_kernel_bind_ready=1` while keeping `weight_tier_runtime_ready=0`, monolithic Ollama D/E measured rows, `v52_ready=0`, and release claims blocked.

v61a-v61j: SSD-resident MoE active-sparse runtime prototype is implemented and covered by `experiments/test_v61j_one_command_ssd_resident_demo.sh`. The chain writes deterministic 2 MB SSD weight pages in `results/v61a_ssd_weight_page_store/store_001/`, aligned direct-I/O page reads in `results/v61b_direct_io_page_reader/reader_001/`, RouteHint prefetch and VRAM hot-cache rows in `results/v61c_vram_hot_cache/cache_001/`, CPU page-dequant-matmul numeric checks in `results/v61d_page_dequant_matmul/matmul_001/`, expert routing rows in `results/v61e_expert_router/router_001/`, predictive-prefetch stall comparison rows in `results/v61f_predictive_prefetch/prefetch_001/`, mixed quant sensitivity/assignment rows in `results/v61g_mixed_quant_planner/quant_001/`, dense full-stream stress blocker rows in `results/v61h_dense_stress_harness/dense_001/`, a logical 128B MoE active-sparse contract in `results/v61i_100b_moe_active_sparse_run/moe_001/`, and a one-command bundle in `results/v61j_one_command_ssd_resident_demo/demo_001/`. The smoke verifies all v61a-v61j ready flags, `ssd_resident_active_sparse_path_proven=1`, `ram_resident_full_model_fallback_rows=0`, `prefetch_hit_rate=0.333333` for the v61f lookahead fixture, `stall_improvement_ms_total=6.000000`, `total_parameters=128000000000`, `ssd_read_bytes_per_token_max=8388608`, and `route_jump_rows=0`. It keeps `real_100b_open_weight_materialized=0`, `near_frontier_claim_ready=0`, dense hundreds-B local-speed, GPU speedup, and release claims blocked.

v61k: real-model page manifest is implemented and covered by `experiments/test_v61k_real_model_page_manifest.sh`. The runner binds v61 to `mistralai/Mixtral-8x22B-v0.1`, records Apache-2.0 model/source/config rows, writes 59 checkpoint-shard manifest rows, enumerates 129024 expert tensor page metadata rows at 2 MiB page size, writes license redistribution rows that include no checkpoint weights, and emits runtime gap rows. The smoke verifies `v61k_real_model_page_manifest_ready=1`, `total_parameters_100b_plus=1`, `legally_redistributable_page_manifest_ready=1`, `real_checkpoint_weight_bytes_materialized=0`, `active_uncached_q4_bytes_per_token_estimate=16911433728`, `active_uncached_q4_budget_pass=0`, and `near_frontier_claim_ready=0`, while keeping GPU page-dequant-matmul, KV-cache policy, source-bound QA, production-latency, and release claims blocked.

v61l: GPU page-dequant-matmul measurement is implemented and covered by `experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh`. The runner consumes the v61k Mixtral 8x22B page manifest, compiles `experiments/assets/v61l_gpu_page_dequant_matmul_probe.hip` with an explicit `gfx1030` offload target, executes the probe from an ASCII `/tmp` path to avoid ROCm code-object loading issues in non-ASCII workspace paths, and writes `gpu_page_dequant_matmul_rows.csv`, manifest binding rows, ROCm env/toolchain/device rows, runtime gap rows, boundary, manifest, and hash rows. The smoke verifies `v61l_gpu_page_dequant_matmul_measurement_ready=1`, one 2 MiB q4-equivalent page tile, `tile_m=1024`, `tile_k=4096`, positive `gpu_kernel_avg_ms`, positive `gpu_page_dequant_gflops`, positive `gpu_page_bandwidth_gbps`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping safetensors page-hash binding, KV-cache policy, source-bound QA, near-frontier quality, production-latency, and release claims blocked.

v61m: KV-cache residency/eviction policy is implemented and covered by `experiments/test_v61m_kv_cache_residency_eviction_policy.sh`. The runner consumes the v61k Mixtral 8x22B page manifest and v61l GPU page-kernel evidence, computes KV geometry from the real model config, and writes `kv_cache_geometry_rows.csv`, `kv_residency_policy_rows.csv`, `kv_budget_profile_rows.csv`, `kv_eviction_trace_rows.csv`, `kv_eviction_event_rows.csv`, runtime gap rows, boundary, manifest, source copies, and hash rows. The smoke verifies `kv_bytes_per_token=229376`, `kv_tokens_per_page=9`, `hot_window_tokens=1024`, `sink_tokens=128`, `vram_kv_budget_bytes=402653184`, `max_context_tokens=8192`, `max_resident_vram_pages=129`, `max_evicted_nvme_pages=782`, `kv_cache_policy_ready=1`, `host_ram_kv_spill_enabled=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping safetensors page-hash binding, source-bound QA, long-context quality, near-frontier quality, production-latency, and release claims blocked.

v61n: source-bound QA workload seed is implemented and covered by `experiments/test_v61n_source_bound_qa_workload.sh`. The runner consumes v61j one-command runtime evidence, v61m KV policy evidence, v53g complete-source manifest metadata, and the currently materialized v53c canary-overlap source files. It writes source manifest binding rows, source-bound query/answer/citation/abstain/resource rows, runtime binding rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies at least 20 materialized source rows, 10 bound repositories, one repo-level abstain per repository, supported answer rows equal to materialized source rows, citation/resource rows equal to total query rows, `source_bound_qa_workload_ready=1`, `actual_model_generation_ready=0`, `complete_source_1000_query_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping complete-source A-H QA, real Mixtral generation, safetensors page-hash binding, near-frontier quality, production-latency, and release claims blocked.

v61o: checkpoint shard/header probe is implemented and covered by `experiments/test_v61o_checkpoint_shard_header_probe.sh`. The runner consumes v61k, fetches the Hugging Face `model.safetensors.index.json`, HEAD-probes all 59 checkpoint shards, range-reads every safetensors header, parses 1739 tensor header rows, and range-hashes three sampled first 2 MiB payload pages without persisting payload bytes. The smoke verifies `checkpoint_shard_http_identity_rows=59`, `safetensors_header_probe_rows=59`, `safetensors_header_tensor_rows` matching the index tensor map, `sampled_page_hash_probe_rows=3`, `sampled_page_payload_bytes_read=6291456`, `checkpoint_weight_bytes_persisted=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping full checkpoint materialization, full safetensors page-hash coverage, local SSD checkpoint residency, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61p: local SSD checkpoint residency preflight is implemented and covered by `experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh`. The runner consumes v61o, writes an outside-repository warehouse probe, SSD disk budget row, checkpoint residency requirement rows, 59 shard download-plan rows, 59 local shard presence rows, runtime gap rows, boundary, manifest, copied v61o evidence, and hash rows without downloading checkpoint payload bytes. The smoke verifies `v61p_local_ssd_checkpoint_residency_preflight_ready=1`, `checkpoint_shard_rows=59`, `total_checkpoint_bytes_required=281241493344`, `required_with_reserve_bytes=315601231712`, `available_ssd_bytes=391102590976` on the current host, `checkpoint_payload_bytes_downloaded_by_v61p=0`, `checkpoint_payload_bytes_committed_to_repo=0`, `real_checkpoint_weight_bytes_materialized=0`, `real_100b_open_weight_materialized=0`, and `local_checkpoint_residency_ready=0`, while keeping full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61q: real checkpoint page map is implemented and covered by `experiments/test_v61q_real_checkpoint_page_map.sh`. The runner consumes v61o, converts the real safetensors header tensor offsets into a metadata-only 2 MiB checkpoint page map, and writes `checkpoint_tensor_page_span_rows.csv`, `checkpoint_page_segment_rows.csv`, `checkpoint_unique_page_rows.csv`, `checkpoint_shard_page_summary_rows.csv`, `checkpoint_page_map_metric_rows.csv`, runtime gap rows, boundary, manifest, copied v61o evidence, and hash rows without downloading or redistributing checkpoint payload bytes. The smoke verifies `v61q_real_checkpoint_page_map_ready=1`, 59 checkpoint shards, 1739 real checkpoint tensor rows, 134161 unique checkpoint page rows, 135841 tensor/page segment rows, 281241268224 mapped tensor payload bytes, 281241493344 total checkpoint bytes, `checkpoint_page_map_weight_bytes_included=0`, `checkpoint_weight_bytes_persisted=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping full page-hash coverage, local SSD checkpoint residency, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61r: full page-hash sweep plan is implemented and covered by `experiments/test_v61r_full_page_hash_sweep_plan.sh` plus `experiments/test_v61r_full_page_hash_sweep_plan_target_override.sh`. The runner consumes v61q and v61p, writes `page_hash_sweep_plan_rows.csv`, `local_page_hash_verification_rows.csv`, `sampled_remote_page_hash_binding_rows.csv`, `shard_page_hash_sweep_status_rows.csv`, `page_hash_sweep_metric_rows.csv`, runtime gap rows, boundary, manifest, copied v61q/v61p evidence, and hash rows without downloading checkpoint shards or committing checkpoint payload bytes. The smoke verifies `v61r_full_page_hash_sweep_plan_ready=1`, 134161 page-hash task rows, 0 local resident page rows, 134161 blocked-missing-local-shard page rows, 0 verified page hashes on the current host, 3 sampled remote page-hash probe rows, 6 sampled page-overlap rows, `full_safetensors_page_hash_binding_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`; the target-override smoke verifies that `V61R_WAREHOUSE_ROOT` forces fresh v61p shard-presence planning and rewrites page-hash local shard paths to the supplied external warehouse root, while keeping local SSD checkpoint residency, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61s: one-command source-bound QA replay is implemented and covered by `experiments/test_v61s_one_command_source_bound_qa_replay.sh`. The runner exercises `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa`, binds v61j and v61n evidence, and writes `one_command_replay_rows.csv`, `source_bound_workload_pass_rows.csv`, runtime gap rows, boundary, manifest, copied v61j/v61n evidence, stdout/stderr captures, entrypoint copy, and hash rows. The smoke verifies `v61s_one_command_source_bound_qa_replay_ready=1`, `one_command_exit_code=0`, `one_command_source_bound_qa_pass=1`, 37 source-bound query rows, 37 source-bound query pass rows, 37 citation/resource rows, 10 abstain rows, 10 abstain-policy pass rows, `actual_model_generation_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping complete-source 1000+ audit completion, real Mixtral generation, full page-hash coverage, near-frontier quality, production-latency, and release claims blocked.

v61t: local checkpoint materialization verifier is implemented and covered by `experiments/test_v61t_local_checkpoint_materialization_verifier.sh` plus `experiments/test_v61t_local_checkpoint_materialization_verifier_target_override.sh`. The runner refreshes v61p, binds v61q and v61r, and writes `local_checkpoint_materialization_rows.csv`, `sampled_local_page_hash_verification_rows.csv`, `local_checkpoint_materialization_metric_rows.csv`, materialization gap rows, boundary, manifest, copied v61p/v61q/v61r/v61o evidence, and hash rows. It verifies local shards only when exact byte length, safetensors header hash, and sampled page hash checks pass; the current ubuntu-1 override records 59 local existing shards, 59 header-hash matches, 59 identity-verified shards, `local_identity_verified_bytes=281241493344`, `local_checkpoint_materialization_ready=1`, `full_safetensors_page_hash_binding_ready=0` at verifier scope, and `real_checkpoint_weight_bytes_materialized=281241493344`. The target-override smoke verifies that `V61T_WAREHOUSE_ROOT` is passed through to the v61p shard-presence preflight and all materialization target paths, while keeping real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61u: remote checkpoint page-hash sampler is implemented and covered by `experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh`. The runner consumes the v61q page map and v61t materialization verifier, selects 16 deterministic full-size checkpoint pages, performs bounded HTTP Range reads against the real Mixtral checkpoint source, and writes `remote_page_hash_sample_plan_rows.csv`, `remote_page_hash_sample_rows.csv`, `remote_page_hash_page_map_overlap_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied v61q/v61t/v61o evidence, and hash rows. The smoke verifies 16 remote page-hash sample rows, 16 ready rows, 33554432 remote payload bytes read as hashes only, at least eight sampled shards, `checkpoint_payload_bytes_persisted=0`, `checkpoint_payload_bytes_committed_to_repo=0`, `full_safetensors_page_hash_binding_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61v: remote page tensor binding is implemented and covered by `experiments/test_v61v_remote_page_tensor_binding.sh`. The runner consumes v61u and binds each remote-hashed sampled checkpoint page to selected v61q tensor/page segment rows, runtime-node rows, tensor-role summary rows, and coverage rows. The smoke verifies 16 remote sample tensor bindings, 16 runtime nodes, 15 MoE expert page bindings, one embedding binding, 15 unique layer indices, all eight expert indices, role counts of embedding=1, moe_w1=5, moe_w2=4, and moe_w3=6, `remote_sample_tensor_binding_ready=1`, `full_safetensors_page_hash_binding_ready=0`, `local_checkpoint_materialization_ready=0`, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full page-hash coverage, local checkpoint materialization, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61w: materialization admission/resume plan is implemented and covered by `experiments/test_v61w_materialization_admission_resume_plan.sh` plus `experiments/test_v61w_materialization_admission_resume_plan_target_override.sh`. The runner consumes v61p/v61q/v61t/v61v, writes `checkpoint_shard_priority_rows.csv`, `checkpoint_download_resume_plan_rows.csv`, `materialization_admission_rows.csv`, `materialization_stage_rows.csv`, runtime gap rows, metric rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 checkpoint shard priority rows, 59 download-resume rows, 16 sampled-priority shard rows, 15 MoE-first priority shard rows, one embedding-priority shard row, `download_resume_plan_ready=1`, `moe_first_priority_plan_ready=1`, `materialization_admission_ready=0`, `local_checkpoint_materialization_ready=0`, and `checkpoint_payload_bytes_committed_to_repo=0`; the target-override smoke verifies that `V61W_WAREHOUSE_ROOT` forces fresh v61t/v61p materialization planning and preserves `V61T_WAREHOUSE_ROOT`/`V61R_WAREHOUSE_ROOT` in post-download verification commands, while keeping SSD budget admission, full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61x: hotset runtime replay manifest is implemented and covered by `experiments/test_v61x_hotset_runtime_replay_manifest.sh`. The runner consumes v61w/v61v/v61s/v61m, writes `hotset_runtime_page_rows.csv`, `hotset_runtime_slot_rows.csv`, `hotset_source_bound_workload_binding_rows.csv`, runtime replay metrics, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16 remote-hashed hotset page rows, 16 planned NVMe hotset slot rows, 37 source-bound workload binding rows, 15 MoE hotset pages, one embedding hotset page, 16 remote-hash-bound rows, `hotset_manifest_ready=1`, `source_bound_replay_binding_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61x=0`, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping hotset payload materialization, SSD budget admission, local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61y: hotset local materialization verifier is implemented and covered by `experiments/test_v61y_hotset_local_materialization_verifier.sh`. The runner consumes v61x/v61u, writes `hotset_local_materialization_rows.csv`, `hotset_local_readback_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16 local sampled hotset pages, 16 local hash matches, 16 local readback hash matches, 15 MoE hotset pages, one embedding hotset page, 33554432 sampled checkpoint payload bytes persisted outside the repository, `hotset_payload_materialization_ready=1`, `hotset_readback_verify_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full checkpoint materialization, SSD budget admission, local full-checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61z: hotset direct-I/O replay is implemented and covered by `experiments/test_v61z_hotset_direct_io_replay.sh`. The runner consumes v61y, reads the 16 local sampled hotset pages through O_DIRECT, writes `hotset_direct_io_read_rows.csv`, `hotset_direct_io_prefetch_order_rows.csv`, latency/metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16 direct-I/O read rows, 16 direct-read hash matches, zero direct-I/O errors, 15 MoE direct-read rows, one embedding direct-read row, 33554432 direct-I/O bytes, `ssd_read_bytes_per_token=8388608`, p50/p95 read latency 0.580768/0.956690 ms, positive sampled throughput, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61aa: hotset tensor slice verifier is implemented and covered by `experiments/test_v61aa_hotset_tensor_slice_verifier.sh`. The runner consumes v61z/v61v/v61y, interprets the 16 local sampled hotset pages as BF16 tensor segments using the real safetensors tensor/page bindings, and writes `hotset_tensor_slice_stat_rows.csv`, `hotset_tensor_slice_sample_value_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16 tensor slice rows, 15 MoE tensor slice rows, one embedding tensor slice row, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, 16 slice/page hash matches, `bf16_tensor_slice_stats_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61ab: hotset tensor tile quant probe is implemented and covered by `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`. The runner consumes v61aa, runs bounded dot-tile probes over the sampled real-checkpoint BF16 tensor slices, and writes `hotset_tensor_tile_probe_rows.csv`, `hotset_tensor_tile_sample_trace_rows.csv`, quant metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 128 tensor tile probe rows, 120 MoE tile rows, 8 embedding tile rows, 524288 BF16 tile values, 384 sample trace rows, 128/128 finite baseline/q8/q4 dot rows, 128/128 finite q8/q4 error rows, q8/q4 mean absolute dot errors of 0.00113809798/0.0244754219, `q8_quant_probe_ready=1`, `q4_quant_probe_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61ac: hotset token budget replay is implemented and covered by `experiments/test_v61ac_hotset_token_budget_replay.sh`. The runner consumes v61x/v61z/v61ab, binds the 37 source-bound workload rows to sampled direct-I/O page schedules and sampled BF16/q8/q4 numeric tile probes, and writes `hotset_token_budget_rows.csv`, `hotset_token_budget_page_schedule_rows.csv`, `hotset_token_budget_tile_binding_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 token-budget rows, 148 active page schedule rows, 1184 tile-binding rows, 37/37 finite token-budget rows, 1184/1184 finite tile-binding rows, four active page reads per token, 32 active tile probes per token, 131072 BF16 tile values per token, 8388608 SSD read bytes per token, sampled token direct-I/O p50/p95 budgets of 2.323072/3.82676 ms, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61ad: KV + weight token budget replay is implemented and covered by `experiments/test_v61ad_kv_weight_token_budget_replay.sh`. The runner consumes v61ac and v61m, combines the 37 source-bound sampled hotset token-budget rows with five KV-cache context profiles, and writes `kv_weight_context_profile_rows.csv`, `kv_weight_token_budget_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 185 combined KV+weight budget rows, 185/185 combined ready rows, 185/185 resident KV VRAM policy pass rows, 74/185 full-KV-in-VRAM pass rows, 111 NVMe cold KV eviction-required rows, zero host RAM spill bytes, 229376 KV bytes/token, 8388608 SSD read bytes/token, 8617984 sampled weight+new-KV bytes/token, max 8192 context, max resident KV VRAM bytes 270532608, max evicted NVMe KV bytes 1639972864, and `checkpoint_payload_bytes_committed_to_repo=0`, while keeping full KV-in-VRAM residency, full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier quality, production-latency, and release claims blocked.

v61ae: real generation admission gate is implemented and covered by `experiments/test_v61ae_real_generation_admission_gate.sh` plus `experiments/test_v61ae_real_generation_admission_gate_target_override.sh`. The runner consumes v61ad/v53r/v61r/v61t/v61w, binds complete-source review packets to sampled runtime budgets and materialization/page-hash state, and writes `real_generation_candidate_rows.csv`, `real_generation_admission_requirement_rows.csv`, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 1000 real-generation candidate rows, 0 admitted generation rows, 1000 runtime-budget-ready rows, 1000 source-review-blocked rows, 1000 materialization-blocked rows, 1000 page-hash-blocked rows, 0 local identity-verified shards, 0 full page-hash verified rows, `materialization_admission_ready=0`, `local_checkpoint_materialization_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and `checkpoint_payload_bytes_committed_to_repo=0`; the target-override smoke verifies that `V61AE_WAREHOUSE_ROOT` forces fresh v61r/v61t/v61w source evidence over the supplied warehouse root before candidate admission, while keeping actual model generation, near-frontier quality, production-latency, and release claims blocked.

v61af: checkpoint warehouse operator bundle is implemented and covered by `experiments/test_v61af_checkpoint_warehouse_operator_bundle.sh` plus `experiments/test_v61af_checkpoint_warehouse_operator_bundle_target_override.sh`. The runner consumes v61w/v61t/v61r/v61ae, emits a guarded `operator_bundle/` with dry-run download, materialization verification, full page-hash sweep, and generation-admission recheck scripts, and writes operator command rows, stage rows, metric rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 guarded download commands, 62 operator command rows, six operator bundle files, `download_dry_run_default=1`, `full_hash_dry_run_default=1`, `planned_remaining_bytes=281241493344`, source-bound available SSD bytes copied from v61p, `materialization_admission_ready=0`, `local_checkpoint_materialization_ready=0`, `full_safetensors_page_hash_binding_ready=0`, `generation_admitted_rows=0`, and zero checkpoint payload bytes downloaded or committed by v61af; the target-override smoke verifies that `V61AF_WAREHOUSE_ROOT` propagates through v61w/v61t/v61r/v61ae and into `operator_env.template`, guarded scripts, and verify/hash/admission command rows, while keeping download execution, real model generation, near-frontier quality, production-latency, and release claims blocked.

v61ag: checkpoint warehouse execution preflight is implemented and covered by `experiments/test_v61ag_checkpoint_warehouse_execution_preflight.sh` plus `experiments/test_v61ag_checkpoint_warehouse_execution_preflight_target_override.sh`. The runner consumes v61af, syntax-checks the copied operator scripts, executes a one-row dry-run download probe, and writes environment rows, script probe rows, dry-run probe rows, execution gate rows, metric rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 62 operator command rows, 59 download commands, four script probe rows, 4/4 bash syntax pass rows, 4/4 executable rows, one dry-run probe with exit code 0, `download_dry_run_guard_ready=1`, `warehouse_outside_repo=1`, `operator_bundle_ignored_by_git=1`, `huggingface_cli_available=0`, `ssd_disk_budget_pass=0`, `download_execution_ready=0`, `operator_execution_preflight_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ag. The target-override smoke verifies that `V61AG_WAREHOUSE_ROOT` forces fresh v61af bundle evidence and preserves the supplied external target in copied operator env/scripts and download command rows, while keeping local materialization, full page-hash coverage, real model generation, production-latency, and release claims blocked.

v61ah: checkpoint download backend fallback plan is implemented and covered by `experiments/test_v61ah_checkpoint_download_backend_fallback_plan.sh` plus `experiments/test_v61ah_checkpoint_download_backend_fallback_plan_target_override.sh`. The runner consumes v61ag, probes available download backends without network payload transfer, selects the available `curl-resume` backend over the missing `huggingface-cli`, and writes backend candidate rows, backend plan rows, dry-run rows, metric rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies five backend candidates, three ready backends, `selected_backend_id=curl-resume`, 59 curl-resume download plan rows, one backend dry-run probe with exit code 0, `download_backend_dry_run_guard_ready=1`, `huggingface_cli_available=0`, `python_huggingface_hub_available=1`, `curl_available=1`, `wget_available=1`, `ssd_disk_budget_pass=0`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ah. The target-override smoke verifies that `V61AH_WAREHOUSE_ROOT` propagates through v61ag/v61af and into backend target paths, curl commands, and the guarded backend script, while keeping local materialization, full page-hash coverage, real model generation, production-latency, and release claims blocked.

v61ai: checkpoint storage budget remediation plan is implemented and covered by `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan.sh` plus `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan_target_override.sh`. The runner consumes v61ah/v61p/v61w, quantifies the current SSD budget blocker, and writes `checkpoint_storage_budget_remediation_rows.csv`, `checkpoint_materialization_batch_rows.csv`, `checkpoint_no_reserve_candidate_shard_rows.csv`, `checkpoint_storage_budget_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `required_with_reserve_bytes=315601231712`, live available SSD bytes copied from v61p, computed full/raw deficits, `safe_materialization_batch_rows=0`, a bounded diagnostic no-reserve top-priority batch, `selected_backend_id=curl-resume`, `download_backend_ready=1`, `download_execution_ready=0`, `storage_budget_remediation_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ai. The target-override smoke verifies that `V61AI_WAREHOUSE_ROOT` propagates through v61ah/v61p/v61w evidence and target paths, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, and release claims blocked.

v61aj: checkpoint storage profile admission matrix is implemented and covered by `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix.sh` plus `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix_target_override.sh`. The runner consumes v61ai/v61w, evaluates current, no-reserve diagnostic, exact raw, exact reserve, 512 GiB, and 1 TiB free-space profiles, and writes `checkpoint_storage_profile_rows.csv`, `checkpoint_storage_profile_requirement_rows.csv`, `checkpoint_storage_profile_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The smoke verifies six profile rows, three full-reserve-admitting profiles, four full-without-reserve profiles, first full-reserve profile `full-checkpoint-exact-with-reserve`, current reserve admitted shard rows 0, live current no-reserve diagnostic admitted shard rows/bytes, exact reserve admitted shard rows 59, computed minimum additional bytes, recommended operator free bytes 549755813888, and zero checkpoint payload bytes downloaded or committed by v61aj. The target-override smoke verifies that `V61AJ_WAREHOUSE_ROOT` propagates through v61ai and copied v61w target paths, while keeping current-host download execution, local materialization, full page-hash coverage, real model generation, production-latency, and release claims blocked.

v61ak: checkpoint warehouse target preflight is implemented and covered by `experiments/test_v61ak_checkpoint_warehouse_target_preflight.sh`. The runner consumes v61aj/v61p, probes candidate warehouse targets without creating checkpoint payloads, and writes `checkpoint_warehouse_target_rows.csv`, `checkpoint_warehouse_target_requirement_rows.csv`, `checkpoint_warehouse_target_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The smoke verifies three target rows, live current target free bytes, repository-local target rejection, `required_with_reserve_bytes=315601231712`, `recommended_operator_free_bytes=549755813888`, `selected_backend_id=curl-resume`, `warehouse_target_preflight_ready=1`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ak, while keeping target selection on the current host, local materialization, full page-hash coverage, real model generation, production-latency, and release claims blocked unless an outside-repository target with enough live free space is supplied.

v61al: checkpoint warehouse activation gate is implemented and covered by `experiments/test_v61al_checkpoint_warehouse_activation_gate.sh` plus `experiments/test_v61al_checkpoint_warehouse_activation_gate_target_override.sh`. The runner consumes v61ak/v61ah/v61w, binds the selected backend and target-preflight state into 59 per-shard activation command rows, and writes `checkpoint_warehouse_activation_command_rows.csv`, `checkpoint_warehouse_activation_gate_rows.csv`, `checkpoint_warehouse_activation_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The default smoke verifies 59 activation command rows, 0 admitted activation rows, 59 blocked activation rows, `activation_package_ready=0`, `selected_target_id=none`, `selected_backend_id=curl-resume`, `backend_ready=1`, explicit execution required, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61al. The target-override smoke verifies that `V61AL_WAREHOUSE_ROOT` bypasses stale reuse and forces a fresh v61ak target probe before activation planning, while keeping explicit payload execution blocked.

v61am: checkpoint post-activation verification gate is implemented and covered by `experiments/test_v61am_checkpoint_post_activation_verification_gate.sh` plus `experiments/test_v61am_checkpoint_post_activation_verification_gate_target_override.sh`. The runner consumes v61al/v61t/v61r, binds activation rows to local materialization and full page-hash sweep readiness, and writes `checkpoint_post_activation_verification_rows.csv`, `checkpoint_post_activation_requirement_rows.csv`, `checkpoint_post_activation_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The default smoke verifies 59 post-activation verification rows, 0 ready rows, 59 blocked rows, 0 activation-admitted rows, 0 local identity verified shard rows, 0 verified page-hash rows out of 134161 required rows, `post_activation_verification_gate_ready=0`, `generation_gate_ready_after_post_activation=0`, and zero checkpoint payload bytes downloaded or committed by v61am. The target-override smoke verifies that `V61AM_WAREHOUSE_ROOT` forces fresh v61al/v61ak target planning before post-activation verification.

v61an: checkpoint full page-hash execution gate is implemented and covered by `experiments/test_v61an_checkpoint_full_page_hash_execution_gate.sh` plus `experiments/test_v61an_checkpoint_full_page_hash_execution_gate_target_override.sh`. The runner consumes v61am/v61t/v61r, turns the 134161-page full hash plan into 291 resumable execution chunks, and writes `checkpoint_full_page_hash_execution_chunk_rows.csv`, `local_full_page_hash_verification_rows.csv`, `checkpoint_full_page_hash_execution_requirement_rows.csv`, `checkpoint_full_page_hash_execution_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The default smoke verifies 291 execution chunks, 0 hashed chunks, 291 activation-blocked chunks, 0 local page hash verification rows, `full_page_hash_execution_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61an. The target-override smoke verifies that `V61AN_WAREHOUSE_ROOT` propagates through fresh v61am/v61al/v61ak planning before full page-hash scheduling, while keeping actual model generation, production-latency, near-frontier, and release claims blocked.

v61ao: real model page manifest coverage audit is implemented and covered by `experiments/test_v61ao_real_model_page_manifest_coverage_audit.sh`. The runner consumes v61q/v61v/v61an, audits the real Mixtral checkpoint manifest as metadata-only coverage, and writes `checkpoint_tensor_role_coverage_rows.csv`, `moe_layer_expert_tensor_coverage_rows.csv`, `checkpoint_manifest_shard_audit_rows.csv`, `real_model_page_manifest_coverage_requirement_rows.csv`, `real_model_page_manifest_coverage_metric_rows.csv`, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 shards, 1739 tensors, 134161 unique checkpoint pages, 135841 tensor/page segments, 1344/1344 layer-expert-MoE tensor coverage rows, 16 remote-hash-bound sample tensor rows, `real_model_page_manifest_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ao, while keeping local materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61ap: MoE coverage remote hash plan is implemented and covered by `experiments/test_v61ap_moe_coverage_remote_hash_plan.sh`. The runner consumes v61ao/v61q/v61v, emits one representative remote hash plan row per Mixtral layer/expert/w1-w2-w3 cell, and writes `moe_coverage_remote_hash_plan_rows.csv`, `moe_coverage_existing_remote_hash_rows.csv`, `moe_coverage_remote_hash_role_rows.csv`, `moe_coverage_remote_hash_shard_rows.csv`, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 1344 MoE remote hash plan rows, 15 already remote-hash-bound MoE sample rows preserved from v61v, 1329 planned representative range hashes, 2818572288 planned remote hash bytes, `full_moe_coverage_remote_hash_ready=0`, `remote_hash_expansion_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ap, while keeping executed expansion, full page-hash coverage, local materialization, real model generation, production-latency, near-frontier, and release claims blocked.

v61aq: MoE remote hash execution gate is implemented and covered by `experiments/test_v61aq_moe_remote_hash_execution_gate.sh`. The runner consumes v61ap, converts the representative MoE remote hash plan into guarded curl-range command rows plus resumable chunks, preserves existing v61v hashes, and writes command rows, existing hash rows, chunk rows, role rows, requirement rows, metric rows, runtime gap rows, a dry-run operator script, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 1329 guarded command rows, 15 preserved existing remote hashes, 21 execution chunks, `remote_hash_execution_ready=0`, `full_moe_coverage_remote_hash_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61aq, while keeping executed remote hashing, full MoE remote-hash coverage, full page-hash coverage, local materialization, real model generation, production-latency, near-frontier, and release claims blocked.

v61ar: MoE remote hash result intake gate is implemented and covered by `experiments/test_v61ar_moe_remote_hash_result_intake.sh`. The runner consumes v61aq, defines the hash-only result return schema for the 1329 guarded command rows, preserves 15 existing v61v hashes, emits 1344 combined coverage rows, and writes required field rows, templates, validation rows, invalid-row diagnostics, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The default smoke verifies 1329 expected result rows, 0 supplied/accepted result rows, 1329 final-deferred missing rows, 15 verified existing rows, `remote_hash_result_intake_ready=0`, `full_moe_coverage_remote_hash_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ar, while keeping full MoE coverage, full page-hash coverage, local materialization, real model generation, production-latency, near-frontier, and release claims blocked.

v61as: hotset reuse admission gate is implemented and covered by `experiments/test_v61as_hotset_reuse_admission_gate.sh`. The runner consumes v61ac/v61ad/v61ar, turns the sampled source-bound token-budget page schedule into a persistent-hotset reuse ledger, and writes page rows, token rows, window rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 source-bound token rows, 148 scheduled sampled MoE page touches, 15 unique cold-fill pages, 133 cache-hit rows, `cache_hit_rate=0.898648649`, `persistent_hotset_cold_fill_bytes=31457280`, `persistent_hotset_saved_bytes=278921216`, `sampled_hotset_reuse_ready=1`, `full_runtime_hotset_reuse_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61as, while keeping full MoE coverage, full page-hash coverage, local materialization, real model generation, production-latency, near-frontier, and release claims blocked.

v61at: prefetch overlap admission gate is implemented and covered by `experiments/test_v61at_prefetch_overlap_admission_gate.sh`. The runner consumes v61l/v61z/v61as, binds GPU page-kernel timing, sampled direct-I/O p95 latency, and persistent-hotset reuse rows into a steady-state overlap ledger, and writes token rows, window rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 36 steady-state non-bootstrap token rows, 36/36 steady-state prefetch-overlap pass rows, zero steady-state blocked rows, 25 no-prefetch-required rows, p95 SSD page-read latency 0.956690 ms, prior-token GPU page-kernel compute window 2.053768 ms, minimum steady-state overlap slack 1.097078 ms, `steady_state_prefetch_overlap_ready=1`, `bootstrap_cold_start_ready=0`, `prefetch_overlap_admission_ready=0`, `full_runtime_hotset_reuse_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61at, while keeping bootstrap cold-start, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61au: prefetch queue-depth scheduler gate is implemented and covered by `experiments/test_v61au_prefetch_queue_depth_scheduler_gate.sh`. The runner consumes v61at, turns sampled steady-state overlap into queue-depth/deadline scheduler rows, and writes scheduler token rows, prefetch issue rows, queue-depth rows, deadline requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 token rows, 15 cold-fill issue rows, 11 steady-state prefetch issue rows, 11/11 steady-state deadline-met rows, 25 no-prefetch-required rows, configured queue depth 4, max steady-state required queue depth 1, `steady_state_scheduler_ready=1`, `bootstrap_scheduler_ready=0`, `prefetch_scheduler_admission_ready=0`, `actual_async_prefetch_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61au, while keeping bootstrap scheduling, actual async I/O, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61av: async prefetch execution probe is implemented and covered by `experiments/test_v61av_async_prefetch_execution_probe.sh`. The runner consumes v61au/v61z, executes the sampled prefetch issue rows through a queue-depth 4 threaded O_DIRECT worker pool, and writes async execution rows, batch rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 15 sampled issue rows, 15 executed rows, 15/15 hash matches, zero async prefetch errors, 11/11 steady-state hash matches, four bootstrap read hash matches, four queue-depth batches, `actual_async_prefetch_execution_ready=1`, `actual_io_uring_execution_ready=0`, `registered_buffers_ready=0`, `prefetch_scheduler_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61av, while keeping bootstrap admission, io_uring, registered buffers, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61aw: io_uring registered-buffer preflight is implemented and covered by `experiments/test_v61aw_io_uring_registered_buffer_preflight.sh`. The runner consumes v61av, probes raw `io_uring_setup` with a valid params structure, records current-host Linux UAPI header ready 1, liburing header ready 0, setup/enter/register syscall numbers 425/426/427, `io_uring_setup_errno_name=EPERM`, setup/enter/register ready 0, registered-buffer prefetch ready 0, and threaded O_DIRECT fallback ready 1. It writes capability rows, setup probe rows, registered-buffer preflight rows, requirement rows, fallback binding rows, metric rows, runtime gap rows, boundary, manifest, copied v61av source evidence, and hash rows, while keeping actual io_uring execution, registered buffers, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61ax: async-I/O backend selection gate is implemented and covered by `experiments/test_v61ax_async_io_backend_selection_gate.sh`. The runner consumes v61aw/v61av, lists `io_uring_registered_buffer` and `threaded_odirect` backend candidates, records the preferred io_uring registered-buffer candidate blocked by `io_uring_setup_errno_1_EPERM`, selects `threaded_odirect` as the current-host backend, and writes candidate rows, selection rows, policy rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies selected backend ready 1, queue depth 4, 15 hash-match rows, zero backend errors, `full_runtime_async_io_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ax, while keeping bootstrap admission, actual io_uring execution, registered buffers, real model generation, production-latency, near-frontier, and release claims blocked.

v61ay: selected-backend token runtime binding is implemented and covered by `experiments/test_v61ay_selected_backend_token_runtime_binding.sh`. The runner consumes v61ad/v61ax, binds every combined KV+weight token budget row to the selected `threaded_odirect` backend, and writes token binding rows, context binding rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 185/185 selected-backend token binding rows, 5/5 context bindings, 37 source-bound query rows, 74 full-KV-in-VRAM pass rows, 111 NVMe eviction-required rows, zero host RAM spill bytes, `full_runtime_async_io_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ay, while keeping actual io_uring execution, registered buffers, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61az: ubuntu-1 warehouse target admission is implemented and covered by `experiments/test_v61az_ubuntu1_warehouse_target_admission.sh`. The runner consumes v61aj/v61ak/v61ay, probes `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25` label `ubuntu-1` as an outside-repository Mixtral checkpoint warehouse capacity target, and writes capacity rows, admission rows, operator command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `/dev/nvme0n1p8` ext4 label `ubuntu-1`, 410615001088 live free bytes, `required_with_reserve_bytes=315601231712`, full-reserve capacity pass 1, operator-margin pass 0 against `recommended_operator_free_bytes=549755813888`, target write/activation readiness 0 in the current managed session, and zero checkpoint payload bytes downloaded or committed by v61az, while keeping download execution, local materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61ba: ubuntu-1 activation handoff package is implemented and covered by `experiments/test_v61ba_ubuntu1_activation_handoff_package.sh`. The runner consumes v61az/v61ah/v61w, rewrites the 59 Mixtral checkpoint shard handoff rows to the ubuntu-1 warehouse target, and writes handoff command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59/59 target-bound shard handoff commands, 59 target-bound materialization verifier commands, 59 target-bound full page-hash commands, 59 target-bound generation-admission recheck commands, `stale_tmp_target_command_rows=0`, p0 sampled MoE rows 15, p0 embedding rows 1, p2 backfill rows 43, `total_expected_checkpoint_bytes=281241493344`, and zero checkpoint payload bytes downloaded or committed by v61ba, while keeping operator/escalated write, download execution, local materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bb: ubuntu-1 write sentinel activation probe is implemented and covered by `experiments/test_v61bb_ubuntu1_write_sentinel_activation_probe.sh`. The runner consumes v61ba, writes or observes a tiny JSON sentinel under the ubuntu-1 warehouse target, and writes sentinel witness rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `sentinel_exists=1`, `sentinel_json_valid=1`, `sentinel_target_path_match=1`, `sentinel_no_payload_claim=1`, `ubuntu1_write_witness_ready=1`, `operator_write_step_resolved_by_witness=1`, `activation_target_write_witness_ready=1`, 59 target-bound handoff rows, `activation_payload_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61bb, while keeping download execution, local materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bc: ubuntu-1 sampled hotset materialization is implemented and covered by `experiments/test_v61bc_ubuntu1_sampled_hotset_materialization.sh`. The runner consumes v61bb/v61y, copies only the 16 already verified sampled hotset pages under the ubuntu-1 warehouse target, and writes materialization rows, readback rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16/16 ubuntu-1 sampled pages present, 16/16 hash matches, 16/16 readback hash matches, 15 MoE pages plus 1 embedding page, 33554432 sampled checkpoint payload bytes persisted on ubuntu-1, `checkpoint_payload_bytes_downloaded_by_v61bc=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bd: ubuntu-1 sampled hotset direct-I/O replay is implemented and covered by `experiments/test_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh`. The runner consumes v61bc/v61x, reads the 16 ubuntu-1 sampled hotset pages through O_DIRECT, and writes direct-I/O read rows, prefetch-order rows, latency rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16/16 O_DIRECT reads, 16/16 hash matches, 0 direct-I/O errors, 15 MoE direct reads plus 1 embedding direct read, 33554432 direct-I/O bytes, p50/p95 read latency 1.102615/1.234314 ms, 1946.456509 MiB/s sampled throughput, `ssd_read_bytes_per_token=8388608`, `checkpoint_payload_bytes_downloaded_by_v61bd=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61be: ubuntu-1 hotset tensor-slice verifier is implemented and covered by `experiments/test_v61be_ubuntu1_hotset_tensor_slice_verifier.sh`. The runner consumes v61bd/v61v, interprets the 16 ubuntu-1 resident sampled hotset pages as real BF16 tensor segments, and writes tensor-slice rows, sampled BF16 value rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 16 tensor slices, 15 MoE slices plus 1 embedding slice, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, 16 ubuntu-1 page hash matches, 16 direct-read hash matches, `checkpoint_payload_bytes_downloaded_by_v61be=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bf: ubuntu-1 tensor-tile quant probe is implemented and covered by `experiments/test_v61bf_ubuntu1_tensor_tile_quant_probe.sh`. The runner consumes v61be, runs bounded BF16/q8/q4 dot-tile probes over the ubuntu-1 resident tensor slices, and writes tile probe rows, sample trace rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 128 tile probes, 120 MoE tile probes plus 8 embedding tile probes, 524288 BF16 tile values, 128/128 finite baseline/q8/q4 dot rows, 128 finite q8/q4 error rows, q8/q4 mean absolute dot errors of 0.00113809798/0.0244754219, 16 ubuntu-1 page hash matches, 16 direct-read hash matches, `checkpoint_payload_bytes_downloaded_by_v61bf=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bg: ubuntu-1 token-budget replay is implemented and covered by `experiments/test_v61bg_ubuntu1_token_budget_replay.sh`. The runner consumes v61x/v61bd/v61bf, binds the 37 source-bound workload rows to ubuntu-1 direct-I/O page schedules and resident BF16/q8/q4 tile probes, and writes token-budget rows, page schedule rows, tile-binding rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 token-budget rows, 148 scheduled page reads, 1184 tile-binding rows, 37/37 finite token budgets, 1184/1184 finite tile bindings, 8388608 SSD read bytes/token, 131072 BF16 tile values/token, p50/p95 token direct-I/O budgets 4.289692/5.237824 ms, q8/q4 mean error budgets 0.0364191354/0.783213501 per token, `checkpoint_payload_bytes_downloaded_by_v61bg=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bh: ubuntu-1 KV+weight token-budget replay is implemented and covered by `experiments/test_v61bh_ubuntu1_kv_weight_token_budget_replay.sh`. The runner consumes v61bg/v61m, binds the 37 ubuntu-1 token-budget rows to five KV context profiles, and writes context-profile rows, combined KV+weight budget rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 185 combined KV+weight budget rows, 185/185 ready rows, 185 resident KV policy pass rows, 74 full-KV-in-VRAM pass rows, 111 NVMe cold KV eviction-required rows, zero host RAM spill bytes, 229376 KV bytes/token, 8617984 weight+new-KV bytes/token, max 8192-context KV cold tier 1639972864 bytes, `checkpoint_payload_bytes_downloaded_by_v61bh=0`, and zero checkpoint payload bytes committed to the repo, while keeping full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bi: ubuntu-1 hotset reuse admission gate is implemented and covered by `experiments/test_v61bi_ubuntu1_hotset_reuse_admission_gate.sh`. The runner consumes v61bg/v61bh/v61ar, turns the ubuntu-1 source-bound token-budget page schedule into a persistent-hotset reuse ledger, and writes page rows, token rows, window rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 source-bound token rows, 148 scheduled ubuntu-1 page reads, 15 unique cold-fill pages, 133 cache-hit rows, `cache_hit_rate=0.898648649`, `persistent_hotset_cold_fill_bytes=31457280`, `persistent_hotset_saved_bytes=278921216`, `ubuntu1_sampled_hotset_reuse_ready=1`, `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bi=0`, and zero checkpoint payload bytes committed to the repo, while keeping full MoE coverage, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bj: ubuntu-1 prefetch overlap admission gate is implemented and covered by `experiments/test_v61bj_ubuntu1_prefetch_overlap_admission_gate.sh`. The runner consumes v61l/v61bd/v61bi, binds target-specific ubuntu-1 O_DIRECT page latency to the ubuntu-1 persistent-hotset reuse ledger, and writes token overlap rows, window rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 source-bound token rows, 36/36 non-bootstrap steady-state overlap pass rows, 11 actual prefetch rows plus 25 no-prefetch-required rows, page p95 read latency 1.309456 ms inside the prior-token GPU page-kernel window 2.053768 ms, minimum steady-state slack 0.744312 ms, `checkpoint_payload_bytes_downloaded_by_v61bj=0`, and zero checkpoint payload bytes committed to the repo, while keeping bootstrap cold-start, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bk: ubuntu-1 prefetch queue-depth scheduler gate is implemented and covered by `experiments/test_v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate.sh`. The runner consumes v61bj/v61bi/v61bd, turns the ubuntu-1 overlap rows into queue-depth/deadline scheduler rows, and writes scheduler token rows, prefetch issue rows, queue-depth rows, deadline requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 token rows, 15 cold-fill issue rows, 11 steady-state prefetch issue rows, 11/11 steady-state deadline-met rows, 25 no-prefetch-required rows, configured queue depth 4, max steady-state required queue depth 1, `ubuntu1_steady_state_scheduler_ready=1`, `bootstrap_scheduler_ready=0`, `ubuntu1_prefetch_scheduler_admission_ready=0`, `actual_async_prefetch_execution_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bk=0`, and zero checkpoint payload bytes committed to the repo, while keeping bootstrap scheduling, actual async/io_uring execution, registered buffers, full checkpoint materialization, full page-hash coverage, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61bl: ubuntu-1 async prefetch execution probe is implemented and covered by `experiments/test_v61bl_ubuntu1_async_prefetch_execution_probe.sh`. The runner consumes v61bk/v61bi/v61bd, executes the ubuntu-1 sampled prefetch issue rows through a queue-depth 4 threaded O_DIRECT worker pool, and writes async execution rows, batch rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 15 sampled issue rows, 15 executed rows, 15/15 hash matches, zero async prefetch errors, 11/11 steady-state hash matches, four bootstrap read hash matches, four queue-depth batches, `actual_async_prefetch_execution_ready=1`, `actual_io_uring_execution_ready=0`, `registered_buffers_ready=0`, `ubuntu1_prefetch_scheduler_admission_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bl=0`, and zero checkpoint payload bytes committed to the repo, while keeping bootstrap admission, io_uring, registered buffers, full checkpoint materialization, full page-hash coverage, full runtime admission, real model generation, production-latency, near-frontier, and release claims blocked.

v61bm: ubuntu-1 bootstrap cold-start admission gate is implemented and covered by `experiments/test_v61bm_ubuntu1_bootstrap_cold_start_admission_gate.sh`. The runner consumes v61bl/v61bk, separates token-0 bootstrap from steady-state prefetch, and writes bootstrap cold-start page rows, batch rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies four bootstrap page rows, 4/4 bootstrap hash matches, zero bootstrap async errors, 8388608 bootstrap cold-start bytes read, a 9.918070 ms bootstrap batch inside the configured 100 ms startup budget, `bootstrap_cold_start_admission_ready=1`, `bootstrap_prefetch_admission_ready=0`, `ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61bm=0`, and zero checkpoint payload bytes committed to the repo, while keeping bootstrap prefetch overlap, io_uring, registered buffers, full runtime admission, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bn: ubuntu-1 activation admission refresh gate is implemented and covered by `experiments/test_v61bn_ubuntu1_activation_admission_refresh_gate.sh`. The runner consumes v61az/v61ba/v61bb, refreshes activation target admission using the later ubuntu-1 write witness, and writes activation admission rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `selected_activation_target_id=ubuntu-1-write-witness-admitted`, 59/59 target-bound handoff rows, 59/59 activation target admitted rows, zero stale `/tmp` target rows, 59 payload execution blocked rows, `activation_target_admission_ready=1`, `activation_payload_execution_ready=0`, `download_execution_ready=0`, `local_checkpoint_materialization_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bn=0`, and zero checkpoint payload bytes committed to the repo, while keeping explicit payload execution, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bo: ubuntu-1 payload execution readiness gate is implemented and covered by `experiments/test_v61bo_ubuntu1_payload_execution_readiness_gate.sh`. The runner consumes v61bn, separates target-bound payload execution preflight from payload execution itself, and writes payload readiness rows, priority chunk rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `payload_execution_preflight_ready=1`, 59/59 target-bound resumable curl download rows, 59 post-download verification/hash/generation-admission command rows, three priority execution chunks, `payload_execution_ready_rows=0`, `download_execution_ready=0`, `local_checkpoint_materialization_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bo=0`, and zero checkpoint payload bytes committed to the repo, while keeping explicit payload execution, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bp: ubuntu-1 payload execution launch bundle is implemented and covered by `experiments/test_v61bp_ubuntu1_payload_execution_launch_bundle.sh`. The runner consumes v61bo, emits a dry-run-first operator bundle with the 59 payload launch rows, three priority chunk launch rows, queue CSV, execution approval rows, post-download materialization/hash/generation recheck scripts, script probes, dry-run probe rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `payload_execution_preflight_ready=1`, 59 launch command rows, three priority chunk launch rows, seven operator bundle files, four script syntax/executable pass rows, `dry_run_guard_ready=1`, `approval_required_rows=2`, `approval_supplied_rows=0`, `payload_execution_launch_ready=0`, `download_execution_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bp=0`, and zero checkpoint payload bytes committed to the repo, while keeping explicit payload execution approval, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bq: ubuntu-1 payload execution receipt intake is implemented and covered by `experiments/test_v61bq_ubuntu1_payload_execution_receipt_intake.sh`. The runner consumes v61bp, defines the receipt schema for an approved ubuntu-1 payload execution run, records non-invasive live file presence/size rows for all 59 target shards, and writes required field rows, templates, validation rows, invalid-row diagnostics, receipt status rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 expected receipt rows, 0 supplied/accepted receipts in the default path, 59 final-deferred missing rows, live target counts matching the source presence rows, currently 12 live existing shard rows and 12 live size-match rows after twelve external ubuntu-1 shards, `payload_execution_receipt_intake_ready=0`, `download_execution_ready=0`, `local_checkpoint_materialization_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bq=0`, and zero checkpoint payload bytes committed to the repo, while keeping receipt-backed payload execution, full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61br: ubuntu-1 post-receipt materialization promotion gate is implemented and covered by `experiments/test_v61br_ubuntu1_post_receipt_materialization_promotion_gate.sh`. The runner consumes v61bq/v61r/v53t, binds the single outside-repository ubuntu-1 target root, rejects stale `/tmp` target promotion, emits post-receipt v61t/v61an/v61ae verification command rows, and writes requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 expected receipt rows, 0 accepted receipts, 59 missing receipts, live target counts matching v61bq, currently 12 live existing shards and 12 live size-match shards, `receipt_backed_materialization_input_ready=0`, `identity_verification_execution_ready=0`, `required_page_hash_rows=134161`, `verified_page_hash_rows=0`, `complete_source_review_return_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61br=0`, and zero checkpoint payload bytes committed to the repo, while keeping receipt-backed full checkpoint materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bs: ubuntu-1 post-receipt verification result intake is implemented and covered by `experiments/test_v61bs_ubuntu1_post_receipt_verification_result_intake.sh`. The runner consumes v61br, defines required returned-summary schemas for the post-receipt v61t/v61an/v61ae commands, supports `V61BS_VERIFICATION_RESULT_DIR`, and writes required field rows, templates, status rows, validation rows, promotion requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies three expected result artifacts, 0 supplied/accepted artifacts in the default path, three missing artifacts, `identity_verification_result_ready=0`, `local_checkpoint_materialization_ready=0`, `required_page_hash_rows=134161`, `verified_page_hash_rows_from_result=0`, `full_page_hash_result_ready=0`, `complete_source_review_return_ready=0`, `generation_admission_result_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bs=0`, and zero checkpoint payload bytes committed to the repo, while keeping full materialization, full page-hash coverage, real model generation, production-latency, near-frontier, and release claims blocked.

v61bt: ubuntu-1 actual generation result intake is implemented and covered by `experiments/test_v61bt_ubuntu1_actual_generation_result_intake.sh`. The runner consumes v61bs and v53r, defines required source-bound Mixtral answer/citation/abstain-fallback/latency/acceptance result schemas, supports `V61BT_GENERATION_RESULT_DIR`, and writes required field rows, templates, status rows, validation rows, 1000 query result rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies five expected result artifacts, 0 supplied/accepted artifacts in the default path, five missing artifacts, `expected_generation_rows=1000`, `generation_query_result_rows=1000`, `accepted_generation_rows=0`, `post_receipt_verification_result_intake_ready=0`, `actual_model_generation_ready=0`, `source_bound_qa_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bt=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual model generation, production-latency, near-frontier, and release claims blocked.

v61bu: ubuntu-1 checkpoint materialization witness is implemented and covered by `experiments/test_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh`. The runner consumes v61bq and v61t, copies the live target presence and local materialization verifier evidence, and writes witness rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke now verifies all 59 checkpoint shards as live, size-matched, safetensors-header-matched, and identity-verified, `local_identity_verified_bytes=281241493344`, `remaining_identity_unverified_shard_rows=0`, `partial_checkpoint_materialization_witness_ready=1`, `full_checkpoint_materialization_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61bu=0`, `observed_external_checkpoint_payload_bytes=281241493344`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61bv: ubuntu-1 remaining checkpoint materialization queue is implemented and covered by `experiments/test_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh`. The runner consumes v61bp and v61bu, skips already identity-verified shards, and now records a closed remaining queue: 59 verified/skip shards, 0 remaining queue rows, 0 remaining priority chunks, `remaining_unverified_bytes=0`, `local_identity_verified_bytes=281241493344`, `remaining_queue_ready=1`, `dry_run_guard_ready=1`, `full_checkpoint_materialization_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bv=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61bw: ubuntu-1 page-hash witness is implemented and covered by `experiments/test_v61bw_ubuntu1_partial_page_hash_witness.sh`. The runner consumes v61bu and v61q, reads every page of all 59 identity-verified ubuntu-1 shards, and writes page-hash witness rows, shard status rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 checkpoint shard rows, 134161 total checkpoint page rows, 59 identity-verified local shards, `local_identity_verified_bytes=281241493344`, `identity_shard_page_rows=134161`, `identity_shard_page_bytes=281241493344`, `page_hash_witness_rows=134161`, `page_hash_witness_bytes=281241493344`, `partial_full_shard_page_hash_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bw=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61bx: ubuntu-1 page-hash coverage ledger is implemented and covered by `experiments/test_v61bx_ubuntu1_page_hash_coverage_ledger.sh`. The runner consumes v61bw, v61bv, and v61q, promotes the page-hash witness into a 59-shard full-checkpoint coverage ledger, and writes ledger rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 checkpoint shard rows, 134161 total checkpoint page rows, 59 verified page-hash shards, `verified_page_hash_rows=134161`, `verified_page_hash_bytes=281241493344`, `remaining_page_hash_shard_rows=0`, `remaining_page_hash_rows=0`, `remaining_page_hash_bytes=0`, `remaining_materialization_queue_rows=0`, `partial_page_hash_coverage_ledger_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bx=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61by: ubuntu-1 remaining page-hash execution plan is implemented and covered by `experiments/test_v61by_ubuntu1_remaining_page_hash_execution_plan.sh`. The runner consumes v61bx and v61bv, skips page-hashed shards, emits remaining-only guarded page-hash execution chunks, and writes chunk rows, skip rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 checkpoint shard rows, 134161 total checkpoint page rows, `verified_page_hash_rows=134161`, `skipped_verified_page_hash_rows=134161`, `remaining_page_hash_rows=0`, `remaining_page_hash_bytes=0`, `remaining_page_hash_execution_chunk_size_pages=512`, `remaining_page_hash_execution_chunk_rows=0`, `remaining_page_hash_execution_plan_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61by=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61bz: ubuntu-1 remaining page-hash operator bundle is implemented and covered by `experiments/test_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh`. The runner consumes v61by, mirrors the remaining page-hash chunks and verified skip rows into a dry-run-first operator bundle, and writes operator scripts, env template, result schema rows, requirement rows, metric rows, dry-run probe rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `v61by_ubuntu1_remaining_page_hash_execution_plan_ready=1`, `verified_page_hash_rows=134161`, `skipped_verified_page_hash_rows=134161`, `remaining_page_hash_rows=0`, `remaining_page_hash_bytes=0`, `remaining_page_hash_execution_chunk_rows=0`, `operator_bundle_file_rows=7`, `script_probe_rows=2`, `script_bash_syntax_pass_rows=2`, `dry_run_guard_ready=1`, `remaining_page_hash_operator_bundle_ready=1`, `page_hash_execution_ready=0`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61bz=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61ca: ubuntu-1 remaining page-hash result intake is implemented and covered by `experiments/test_v61ca_ubuntu1_remaining_page_hash_result_intake.sh`. The runner consumes v61bz, defines the hash-only result schema for `remaining_page_hash_result_rows.csv`, preserves existing verified page-hash rows, records the empty-remaining result path when no result artifact is needed, and writes required field rows, template rows, validation rows, invalid rows, chunk status rows, preservation rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready=1`, `page_hash_result_input_supplied=0`, `expected_remaining_page_hash_result_rows=0`, `accepted_remaining_page_hash_result_rows=0`, `missing_remaining_page_hash_result_rows=0`, `existing_verified_page_hash_rows=134161`, `total_required_page_hash_rows=134161`, `total_verified_page_hash_rows=134161`, `remaining_page_hash_execution_chunk_rows=0`, `remaining_page_hash_result_intake_ready=1`, `completed_full_safetensors_page_hash_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ca=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cb: ubuntu-1 full page-hash coverage promotion gate is implemented and covered by `experiments/test_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh`. The runner consumes v61ca, aggregates the result intake into shard-level promotion rows, and promotes the full 59-shard page-hash coverage. The smoke verifies `v61ca_ubuntu1_remaining_page_hash_result_intake_ready=1`, `checkpoint_shard_rows=59`, `ready_full_page_hash_shard_rows=59`, `blocked_full_page_hash_shard_rows=0`, `existing_verified_page_hash_shard_rows=59`, `remaining_page_hash_shard_rows=0`, `accepted_remaining_page_hash_result_rows=0`, `missing_remaining_page_hash_result_rows=0`, `existing_verified_page_hash_rows=134161`, `total_required_page_hash_rows=134161`, `total_verified_page_hash_rows=134161`, `full_page_hash_coverage_promotion_ready=1`, `completed_full_safetensors_page_hash_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cb=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cc: ubuntu-1 page-hash generation admission bridge is implemented and covered by `experiments/test_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh`. The runner consumes v61cb page-hash promotion, v53t complete-source audit readiness, and v61bt actual generation result intake schema, then emits 1000 complete-source generation admission bridge rows. The smoke verifies `v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready=1`, `v53t_complete_source_audit_readiness_gate_ready=1`, `v61bt_ubuntu1_actual_generation_result_intake_ready=1`, `complete_source_query_rows=1000`, `generation_admission_bridge_rows=1000`, `machine_complete_source_surface_ready=1`, `complete_source_review_return_ready=0`, `full_safetensors_page_hash_binding_ready=1`, `total_verified_page_hash_rows=134161`, `total_required_page_hash_rows=134161`, `generation_execution_admitted_rows=0`, `page_hash_blocked_rows=0`, `review_return_blocked_rows=1000`, `generation_result_artifact_blocked_rows=1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cc=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source review return, actual generation, production-latency, near-frontier, and release claims blocked.

v61cd: ubuntu-1 generation unblocker closure bundle is implemented and covered by `experiments/test_v61cd_ubuntu1_generation_unblocker_closure_bundle.sh`. The runner consumes v61cc, v61ca, v53s, and v61bt, then emits three ordered closure phases, 11 required return artifact rows, seven operator command rows, an operator README, a return manifest template, and a shape verification script. The smoke verifies `v61cc_ubuntu1_page_hash_generation_admission_bridge_ready=1`, `closure_phase_rows=3`, `return_artifact_rows=11`, `operator_command_rows=7`, `page_hash_return_required_rows=0`, `page_hash_return_accepted_rows=0`, `total_verified_page_hash_rows=134161`, `page_hash_closure_ready=1`, `human_review_required_rows=7000`, `human_review_accepted_rows=0`, `adjudication_required_rows=1000`, `adjudication_accepted_rows=0`, `generation_result_required_artifacts=5`, `generation_result_accepted_artifacts=0`, `generation_execution_admitted_rows=0`, `generation_unblocker_closure_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cd=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source review return, actual generation, production-latency, near-frontier, and release claims blocked.

v61ce: ubuntu-1 generation closure return intake is implemented and covered by `experiments/test_v61ce_ubuntu1_generation_closure_return_intake.sh`. The runner consumes v61cd, v61cb, v53t, v61bt, and v61cc, then rechecks page-hash closure, complete-source review return, and actual generation result return as three closure gates plus 1000 generation closure admission rows. The smoke verifies `v61cd_ubuntu1_generation_unblocker_closure_bundle_ready=1`, `closure_gate_rows=3`, `generation_closure_admission_rows=1000`, `page_hash_return_required_rows=0`, `page_hash_return_accepted_rows=0`, `total_required_page_hash_rows=134161`, `total_verified_page_hash_rows=134161`, `page_hash_closure_ready=1`, `human_review_required_rows=7000`, `human_review_accepted_rows=0`, `adjudication_required_rows=1000`, `adjudication_accepted_rows=0`, `generation_result_required_artifacts=5`, `generation_result_accepted_artifacts=0`, `accepted_generation_rows=0`, `generation_closure_return_intake_ready=0`, `generation_execution_admitted_rows=0`, `page_hash_blocked_rows=0`, `review_return_blocked_rows=1000`, `generation_result_artifact_blocked_rows=1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ce=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source review return, actual generation, production-latency, near-frontier, and release claims blocked.

v61cf: ubuntu-1 source-bound generation execution packet is implemented and covered by `experiments/test_v61cf_ubuntu1_source_bound_generation_execution_packet.sh`. The runner consumes v61ce, v53r, and v61bt, then emits 1000 source-bound generation execution packet rows, four prompt contract rows, five return artifact rows, six operator command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `v61ce_ubuntu1_generation_closure_return_intake_ready=1`, `execution_packet_rows=1000`, `prompt_manifest_rows=4`, `return_manifest_rows=5`, `operator_command_rows=6`, `complete_source_query_rows=1000`, `expected_generation_result_artifacts=5`, `page_hash_closure_ready=1`, `review_return_closure_ready=0`, `generation_result_closure_ready=0`, `generation_closure_return_intake_ready=0`, `generation_execution_admission_ready=0`, `generation_execution_ready=0`, `generation_execution_admitted_rows=0`, `blocked_execution_rows=1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cf=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source review return, generation result return, actual generation, production-latency, near-frontier, and release claims blocked.

v61cg: ubuntu-1 source-bound generation operator bundle is implemented and covered by `experiments/test_v61cg_ubuntu1_source_bound_generation_operator_bundle.sh`. The runner consumes v61cf, then emits four operator bundle files, four bundle command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied v61cf evidence, hash rows, and an executable `operator_bundle/VERIFY_EXECUTION_PACKET.sh` verifier. The smoke verifies `v61cf_ubuntu1_source_bound_generation_execution_packet_ready=1`, `execution_packet_rows=1000`, `prompt_manifest_rows=4`, `return_manifest_rows=5`, `carried_operator_command_rows=6`, `bundle_operator_command_rows=4`, `total_operator_command_rows=10`, `operator_bundle_file_rows=4`, `page_hash_closure_ready=1`, `review_return_closure_ready=0`, `generation_result_closure_ready=0`, `operator_bundle_handoff_ready=1`, `generation_execution_ready=0`, `blocked_execution_rows=1000`, `generation_operator_execution_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cg=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source review return, generation result return, actual generation, production-latency, near-frontier, and release claims blocked.

v61ch: real-model page manifest release index is implemented and covered by `experiments/test_v61ch_real_model_page_manifest_release_index.sh`. The runner consumes v61ao, v61cb, and v61cg, then emits a zero-payload `release_index/` with `MANIFEST_INDEX.csv`, shard audit rows, tensor-role coverage rows, 1344-row MoE layer/expert/tensor coverage rows, page-hash status rows, generation handoff status rows, a zero-payload boundary, import checklist, executable `VERIFY_RELEASE_INDEX.sh`, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `redistributable_manifest_index_ready=1`, 8 source artifact rows, 10 release index files, 59 shards, 134161 manifest pages, 135841 tensor/page segment rows, 1344/1344 MoE coverage rows, 134161/134161 verified page hashes, 0 remaining page hashes, `completed_full_safetensors_page_hash_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `operator_bundle_handoff_ready=1`, `generation_operator_execution_ready=0`, `actual_model_generation_ready=0`, `redistributed_checkpoint_payload_bytes=0`, `checkpoint_payload_bytes_downloaded_by_v61ch=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61ci: real manifest runtime substitution gate is implemented and covered by `experiments/test_v61ci_real_manifest_runtime_substitution_gate.sh`. The runner consumes v61j, v61k, and v61ch, then maps the logical SSD-resident fixture surfaces onto the real Mixtral zero-payload manifest/index through four logical-fixture replacement contract rows and five runtime substitution binding rows. It writes replacement contract rows, runtime binding rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `logical_fixture_replaced_by_real_manifest_ready=1`, `zero_payload_runtime_input_ready=1`, 134161 manifest pages, 135841 tensor/page segment rows, 1344/1344 MoE coverage rows, 134161/134161 verified page hashes, 0 remaining page hashes, `completed_full_safetensors_page_hash_coverage_ready=1`, `runtime_execution_admission_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ci=0`, and zero checkpoint payload bytes committed to the repo, while keeping real runtime execution, actual generation, production-latency, near-frontier, and release claims blocked.

v61cj: real manifest immediate target bridge is implemented and covered by `experiments/test_v61cj_real_manifest_immediate_target_bridge.sh`. The runner consumes v61ci, v61l, v61m, v61s, and v61n source rows, then binds the four immediate v61 real-model targets into `real_manifest_immediate_target_rows.csv` and `real_manifest_runtime_evidence_bridge_rows.csv`. The smoke verifies 4/4 ready immediate target rows, 3/3 ready runtime bridge rows, `real_manifest_immediate_target_bridge_ready=1`, `logical_fixture_replaced_by_real_manifest_ready=1`, ROCm page-kernel timing `gpu_kernel_avg_ms=0.513442`, `kv_cache_policy_ready=1`, source-bound command pass 37/37, `complete_source_1000_query_ready=0`, `completed_full_safetensors_page_hash_coverage_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cj=0`, and zero repo payload bytes, while keeping complete-source 1000-query generation, production-latency, near-frontier, and release claims blocked.

v61ck: real generation unblocker operator matrix is implemented and covered by `experiments/test_v61ck_real_generation_unblocker_operator_matrix.sh`. The runner consumes v61cj, v61bv, v61bz, v61ca, v61cb, v61cm, v61cn, v61co, v61cq, v61cr, v61cv, v61cw, v53u, v53v, v61bt, and v61cg, then emits a nine-row unblocker matrix, nine-row operator execution order, claim boundary rows, operator matrix files, requirement/metric/boundary/manifest/hash rows, and copied source evidence. After the v61dc/v61cw refresh, the smoke verifies 9/9 ready operator surfaces, 0 remaining checkpoint materialization queue rows, 59 checkpoint materialization promotion rows with 59 ready shards and 0 blocked shards, 0 remaining page-hash execution admission rows, 37 runtime execution admission candidate rows with 37 admitted, 1000 complete-source runtime admission expansion rows, 1000/1000 complete-source runtime admission acceptance rows, 0 missing runtime admission return artifacts, 0 missing materialization/page-hash bytes, 0 remaining page-hash rows, v53v 7000-row per-answer review-return acceptance with 0 answer-review accepted rows, 0/7000 human review rows, 0/1000 adjudication rows, 0/21 reviewer identity rows, 0/210 conflict disclosure rows, acceptance summary 0, 5 generation result artifacts with 0 accepted, `generation_unblocker_operator_matrix_ready=1`, `full_checkpoint_materialization_ready=1`, `completed_full_safetensors_page_hash_coverage_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ck=0`, and zero repo payload bytes, while keeping review return, actual generation, production-latency, near-frontier, and release claims blocked.

v61cl: ubuntu-1 remaining checkpoint materialization return intake is implemented and covered by `experiments/test_v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake.sh`. The runner consumes v61bv, defines the metadata-only return schema for remaining shard materialization receipts, preserves all 59 identity-verified shards, and writes required-field rows, template rows, invalid-row diagnostics, queue/chunk status rows, preservation rows, validation/requirement/metric/runtime-gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 0 expected/missing return rows, 0 expected/missing materialization bytes, 59 existing identity-verified shards, 0 remaining chunks, `remaining_materialization_return_intake_ready=1`, `full_checkpoint_materialization_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61cl=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cm: ubuntu-1 full checkpoint materialization promotion gate is implemented and covered by `experiments/test_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh`. The runner consumes v61cl, aggregates accepted materialization returns and existing identity-verified shard evidence into 59 shard-level promotion rows, and writes promotion rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 59 checkpoint shard rows, 59 ready identity-verified shards, 0 blocked remaining shards, 0 expected/missing materialization return rows, 0 expected/missing materialization bytes, `total_identity_verified_checkpoint_shard_rows=59`, `full_checkpoint_materialization_ready=1`, `promotion_identity_verified_bytes=281241493344`, `checkpoint_payload_bytes_downloaded_by_v61cm=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cn: ubuntu-1 page-hash execution materialization admission gate is implemented and covered by `experiments/test_v61cn_ubuntu1_page_hash_execution_materialization_admission_gate.sh`. The runner consumes v61bz and v61cm, binds remaining page-hash execution chunks to full-checkpoint materialization promotion rows, and writes admission rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 0 remaining page-hash execution chunks, 0 admitted chunks, 0 materialization-blocked chunks, 0 blocked page-hash rows, 0 blocked page-hash bytes, `page_hash_execution_admission_ready=1`, `completed_full_safetensors_page_hash_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61cn=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61co: real manifest runtime execution admission bridge is implemented and covered by `experiments/test_v61co_real_manifest_runtime_execution_admission_bridge.sh`. The runner consumes v61cj, v61ci, v61cm, v61cn, v61n, and v61s, then maps the 37 source-bound QA seed rows onto the real-manifest runtime prerequisites. It writes runtime execution admission rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 37 runtime execution candidate rows, 37 admitted rows, 0 blocked runtime rows, 37/37 source-bound query pass rows, 59 ready checkpoint shards, 0 blocked checkpoint shards, 0 remaining page-hash execution chunks, 0 blocked page-hash rows, 0 blocked page-hash bytes, `real_manifest_runtime_execution_admission_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61co=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source runtime admission return, actual generation, production-latency, near-frontier, and release claims blocked.

v61cp: complete-source runtime admission coverage gate is implemented and covered by `experiments/test_v61cp_complete_source_runtime_admission_coverage_gate.sh`. The runner consumes v61co, v61cf, and v61cc, then maps every 1000-row complete-source generation packet row against the 37-row real-manifest seed runtime admission bridge. It writes complete-source runtime admission coverage rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 1000 complete-source query rows, 37 seed runtime candidate rows, 37/37 seed query pass rows, direct query overlap 0/1000, 1000 seed-uncovered complete-source rows, 0 complete-source runtime admitted rows, `complete_source_runtime_admission_coverage_ready=0`, `real_manifest_runtime_execution_admission_ready=1`, 0 page-hash-blocked rows, 1000 review-return-blocked rows, 1000 generation-result-artifact-blocked rows, `checkpoint_payload_bytes_downloaded_by_v61cp=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source real-model generation, production-latency, near-frontier, and release claims blocked.

v61cq: complete-source runtime admission expansion packet is implemented and covered by `experiments/test_v61cq_complete_source_runtime_admission_expansion_packet.sh`. The runner consumes v61cp, v61cf, and v61cc, then converts the 0/1000 direct-overlap coverage gap into 1000 explicit runtime-admission expansion rows over the complete-source generation packet. It writes expansion rows, operator command rows, return manifest rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies 1000 complete-source query rows, 1000 runtime admission expansion packet rows, 1000 required new runtime admission rows, five operator command rows, five return artifact rows, `runtime_admission_expansion_packet_ready=1`, `runtime_admission_expansion_execution_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cq=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source runtime execution, actual generation, production-latency, near-frontier, and release claims blocked.

v61cr: complete-source runtime admission return intake is implemented and covered by `experiments/test_v61cr_complete_source_runtime_admission_return_intake.sh`. The runner consumes v61cq, defines the five-artifact return surface for complete-source runtime admission, and records the default no-return path as missing/default-deferred. The separate v61dc smoke supplies the five local return artifacts and refreshes v61cr to 5/5 accepted artifacts, 1000/1000 accepted runtime admission rows, `complete_source_runtime_admission_execution_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cr=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cv: complete-source runtime admission operator bundle is implemented and covered by `experiments/test_v61cv_complete_source_runtime_admission_operator_bundle.sh`. The runner consumes v61cq, v61cr, v61cm, v61cb, and v61co, then emits a dry-run-first runtime admission operator bundle with five bundle files, five command rows, five return-template rows, requirement/metric/runtime-gap rows, boundary, manifest, copied source evidence, and hash rows. After v61dc refresh it inherits `complete_source_runtime_admission_execution_ready=1`, while keeping `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cv=0`, and zero checkpoint payload bytes committed to the repo.

v61cw: complete-source runtime admission acceptance bridge is implemented and covered by `experiments/test_v61cw_complete_source_runtime_admission_acceptance_bridge.sh`. The runner consumes v61cq, v61cv, and v61cr, then emits a 1000-row per-query runtime admission acceptance ledger plus requirement, metric, runtime-gap, boundary, manifest, copied source evidence, and hash rows. After v61dc refresh the smoke path verifies `runtime_admission_acceptance_rows=1000`, `runtime_admission_accepted_rows=1000`, zero runtime artifact/result/page-binding/budget/identity/safety blocked acceptance rows, `guarded_runtime_admission_command_ready=1`, `complete_source_runtime_admission_execution_ready=1`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cw=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cs: complete-source generation execution admission gate is implemented and covered by `experiments/test_v61cs_complete_source_generation_execution_admission_gate.sh`. The runner consumes v61ck, v61cw, v61cf, and v61bt, then emits 1000 complete-source generation execution admission rows plus requirement, metric, runtime-gap, boundary, manifest, copied source evidence, and hash rows. After v61dc refresh the smoke verifies `v61cw_complete_source_runtime_admission_acceptance_bridge_ready=1`, 1000 admission rows, zero admitted execution rows, 0 materialization-blocked rows, 0 page-hash-blocked rows, 0 runtime-admission-blocked rows, 1000 review-return-blocked rows, 1000 generation-result-artifact-blocked rows, ready operator handoff, ready execution packet, zero actual generation-ready rows, `checkpoint_payload_bytes_downloaded_by_v61cs=0`, and zero checkpoint payload bytes committed to the repo, while keeping complete-source generation execution admission, actual generation, production-latency, near-frontier, and release claims blocked.

v61ct: complete-source generation execution operator bundle is implemented and covered by `experiments/test_v61ct_complete_source_generation_execution_operator_bundle.sh`. The runner consumes v61cs and v61bt, then emits a dry-run-first operator bundle over the final generation execution admission surface with bundle files, command rows, requirement/metric/runtime-gap rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `v61cs_complete_source_generation_execution_admission_gate_ready=1`, `v61bt_ubuntu1_actual_generation_result_intake_ready=1`, 1000 admission rows, zero admitted execution rows, five operator bundle files, five operator command rows, three currently runnable metadata/refresh commands, five generation result return template rows, `guarded_generation_command_ready=0`, `generation_operator_execution_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ct=0`, and zero checkpoint payload bytes committed to the repo, while keeping real generation execution, result return, production-latency, near-frontier, and release claims blocked.

v61cu: complete-source generation result acceptance bridge is implemented and covered by `experiments/test_v61cu_complete_source_generation_result_acceptance_bridge.sh`. The runner consumes v61cs, v61ct, and v61bt, then emits 1000 final acceptance rows over execution admission, guarded operator execution, and returned generation result intake. The smoke verifies `v61cs_complete_source_generation_execution_admission_gate_ready=1`, `v61ct_complete_source_generation_execution_operator_bundle_ready=1`, `v61bt_ubuntu1_actual_generation_result_intake_ready=1`, 1000 acceptance rows, zero admitted execution rows, zero accepted generation rows, zero accepted answer/citation/latency rows, 1000 admission-blocked acceptance rows, 1000 result-artifact-blocked acceptance rows, `actual_model_generation_ready_rows=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cu=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, and release claims blocked.

v61cx: post-full-shard actual generation closure queue is implemented and covered by `experiments/test_v61cx_post_full_shard_actual_generation_closure_queue.sh`. The runner consumes v61cm, v61cb, v61cv, v61cw, v53u, v53v, v61ct, and v61cu, then emits five post-full-shard closure rows and three next-action rows. After v61dc refresh the smoke verifies full checkpoint materialization, full safetensors page-hash coverage, and runtime admission acceptance are closed, `closure_queue_rows=5`, `closed_closure_rows=3`, `blocked_closure_rows=2`, `next_action_rows=3`, `ready_next_action_rows=2`, 59/59 identity-verified checkpoint shards, 134161/134161 verified page hashes, `runtime_admission_accepted_rows=1000/1000`, `answer_review_accepted_rows=0/7000`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cx=0`, and zero checkpoint payload bytes committed to the repo, while keeping review return, generation result acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v61cy: runtime admission chunk execution queue is implemented and covered by `experiments/test_v61cy_runtime_admission_chunk_execution_queue.sh`. The runner consumes v61cq, v61cv, v61cw, and v61cx, splits the 1000-row complete-source runtime admission expansion packet into 20 chunks of 50 rows, and emits chunk rows, a 1000-row chunk manifest, 81 chunk return artifact rows, five aggregate return artifact rows, operator command rows, bundle scripts/templates, metric rows, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `runtime_admission_chunk_rows=20`, `runtime_admission_chunk_manifest_rows=1000`, `runtime_admission_chunk_return_artifact_rows=81`, `runtime_admission_aggregate_return_artifact_rows=5`, `ready_runtime_admission_chunk_dispatch_rows=20`, `completed_runtime_admission_chunk_rows=0`, `accepted_runtime_admission_chunk_return_rows=0`, `chunk_dispatch_ready=1`, `chunk_merge_ready=0`, `aggregate_runtime_return_ready=0`, `runtime_admission_accepted_rows=0`, `complete_source_runtime_admission_execution_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cy=0`, and zero checkpoint payload bytes committed to the repo, while keeping runtime admission acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v61cz: runtime admission chunk return intake is implemented and covered by `experiments/test_v61cz_runtime_admission_chunk_return_intake.sh`. The runner consumes v61cy, optionally reads `V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_DIR`, validates the 81 expected chunk return artifacts by row count, and computes whether they can be merged into the five aggregate v61cr return artifacts. The default no-return smoke verifies `runtime_admission_chunk_rows=20`, `runtime_admission_chunk_return_artifact_rows=81`, `runtime_admission_aggregate_return_artifact_rows=5`, `chunk_return_dir_supplied=0`, `supplied_chunk_return_artifacts=0`, `accepted_chunk_return_artifacts=0`, `missing_chunk_return_artifacts=81`, `accepted_runtime_admission_chunk_rows=0`, `missing_runtime_admission_chunk_rows=20`, `global_runtime_identity_return_ready=0`, `aggregate_runtime_return_merge_ready=0`, `complete_source_runtime_admission_execution_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61cz=0`, and zero checkpoint payload bytes committed to the repo, while keeping aggregate runtime return merge, runtime admission acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v61da: runtime admission aggregate return handoff gate is implemented and covered by `experiments/test_v61da_runtime_admission_aggregate_return_handoff_gate.sh`. The runner consumes v61cz, v61cr, and v61cw, then emits five aggregate handoff rows, command/file rows, a verifier-backed handoff package, metric rows, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `runtime_admission_chunk_rows=20`, `accepted_runtime_admission_chunk_rows=0`, five aggregate runtime return artifacts, `aggregate_runtime_return_merge_ready_rows=0`, `handoff_artifact_rows=5`, `handoff_ready_rows=0`, `aggregate_runtime_return_handoff_ready=0`, `handoff_command_rows=4`, `ready_handoff_command_rows=1`, `runtime_admission_accepted_rows=0`, `complete_source_runtime_admission_execution_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61da=0`, and zero checkpoint payload bytes committed to the repo, while keeping aggregate handoff, runtime admission acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v61db: runtime admission acceptance refresh gate is implemented and covered by `experiments/test_v61db_runtime_admission_acceptance_refresh_gate.sh`. The runner consumes v61da, v61cr, v61cw, and v61cs, then emits four refresh-stage rows and four refresh command rows that bind aggregate handoff, aggregate intake, per-query runtime acceptance, and generation admission refresh. After v61dc refresh the smoke verifies `refresh_stage_rows=4`, `ready_refresh_stage_rows=2`, `blocked_refresh_stage_rows=2`, `ready_refresh_command_rows=3`, `handoff_ready_rows=0`, `accepted_runtime_admission_return_artifacts=5/5`, `runtime_admission_accepted_rows=1000/1000`, `generation_execution_admitted_rows=0/1000`, `runtime_admission_blocked_generation_rows=0`, `runtime_admission_acceptance_refresh_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61db=0`, and zero checkpoint payload bytes committed to the repo, while keeping generation admission, actual generation, production-latency, near-frontier, and release claims blocked.

v61dc: complete-source runtime admission local return materializer is implemented and covered by `experiments/test_v61dc_complete_source_runtime_admission_local_return_materializer.sh`. The runner consumes v61cq, v61cm, v61cb, and v61t, writes the five v61cr return artifacts with 1000 runtime result rows, 1000 page-binding rows, 1000 budget rows, 59 shard identity rows, and 1000 citation/abstain/fallback safety rows, then refreshes v61cr/v61cv/v61cw/v61cs. The smoke verifies v61cr accepts 5/5 artifacts and 1000/1000 runtime rows, v61cw accepts 1000/1000 per-query runtime admission rows, v61cs drops `runtime_admission_blocked_generation_rows` to 0 while keeping `generation_execution_admitted_rows=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dc=0`, and zero checkpoint payload bytes committed to the repo.

v61dd: review-return generation refresh bridge is implemented and covered by `experiments/test_v61dd_review_return_generation_refresh_bridge.sh`. The runner refreshes v53y, materializes and re-intakes v61dc runtime admission returns, refreshes v61cr/v61cv/v61cw/v61ck/v61cs/v61ct/v61cu/v61cx, and emits a six-stage bridge from full-shard closure to actual-generation readiness. The smoke verifies `refresh_stage_rows=6`, `ready_refresh_stage_rows=2`, `blocked_refresh_stage_rows=4`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000/1000`, `complete_source_runtime_admission_execution_ready=1`, `answer_review_accepted_rows=0/7000`, `generation_execution_admitted_rows=0/1000`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dd=0`, and zero checkpoint payload bytes committed to the repo, while keeping review return, generation execution, generation result acceptance, production-latency, near-frontier, and release claims blocked.

v53z: complete-source review-return to v61 handoff bridge is implemented and covered by `experiments/test_v53z_complete_source_review_return_v61_handoff_bridge.sh`. The runner refreshes v53w, optionally intakes chunk returns through v53x, optionally refreshes aggregate review returns through v53y, then refreshes v61dd so accepted review returns can propagate into the post-full-shard actual-generation blocker chain. The default no-return smoke verifies `handoff_stage_rows=7`, `ready_handoff_stage_rows=3`, `blocked_handoff_stage_rows=4`, `ready_handoff_command_rows=2`, `ready_review_chunk_dispatch_rows=21/21`, `review_chunk_return_artifact_rows=50`, `accepted_chunk_return_artifact_rows=0`, `aggregate_review_return_artifact_rows=5`, `accepted_aggregate_review_return_artifact_rows=0`, `answer_review_accepted_rows=0/7000`, `v61_review_unblock_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v53z=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual review return, v53 readiness, v1.0 comparison readiness, v61 actual generation, latency, near-frontier, and release claims blocked.

v53aa: complete-source review chunk work packet is implemented and covered by `experiments/test_v53aa_complete_source_review_chunk_work_packet.sh`. The runner consumes the v53w chunk execution queue and v53u templates, then emits reviewer-facing `operator_packet/chunks/<chunk>/` directories with per-chunk task rows, required return artifact rows, README files, aggregate return artifact targets, review templates, a verifier, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `review_chunk_rows=21`, `ready_review_chunk_dispatch_rows=21/21`, `review_chunk_task_rows=8000`, `human_review_chunk_task_rows=7000`, `adjudication_chunk_task_rows=1000`, `review_chunk_return_artifact_rows=50`, `aggregate_review_return_artifact_rows=5`, `operator_chunk_packet_rows=21`, `ready_operator_chunk_packet_rows=21`, `operator_packet_file_rows=72`, `ready_operator_packet_file_rows=72`, `answer_review_accepted_rows=0/7000`, `review_return_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual review return, v53 readiness, v1.0 comparison readiness, and release claims blocked.

v53ab: complete-source review dispatch receipt packet is implemented and covered by `experiments/test_v53ab_complete_source_review_dispatch_receipt_packet.sh`. The runner refreshes v61df and v53aa, embeds the v53aa work packet into `operator_dispatch/review_work_packet/`, and emits dispatch chunk rows, dispatch receipt templates, aggregate return handoff rows, refresh command rows, packet file rows, requirement rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `dispatch_chunk_rows=21`, `ready_dispatch_chunk_rows=21`, `dispatch_task_rows=8000`, `dispatch_return_artifact_rows=50`, `aggregate_review_return_artifact_rows=5`, `dispatch_receipt_template_rows=21`, `accepted_dispatch_receipt_rows=0`, `dispatch_command_rows=5`, `ready_dispatch_command_rows=3`, `dispatch_package_file_rows=8`, `ready_dispatch_package_file_rows=8`, `embedded_work_packet_file_rows=72`, `ready_embedded_work_packet_file_rows=72`, `answer_review_accepted_rows=0/7000`, `actual_model_generation_ready=0`, and zero checkpoint payload bytes committed to the repo, while keeping dispatch receipts, actual review return, v53 readiness, v61 actual generation, and release claims blocked.

v53ac: complete-source review dispatch archive is implemented and covered by `experiments/test_v53ac_complete_source_review_dispatch_archive.sh`. The runner refreshes v53ab, archives `operator_dispatch/` into `archive/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz`, writes `ARCHIVE_FILE_LIST.txt`, `ARCHIVE_SHA256SUMS.txt`, send instructions, archive member rows, artifact rows, requirement rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `archive_ready=1`, `archive_sha256_ready=1`, `archive_file_list_ready=1`, `send_readme_ready=1`, 78 archive member files, nine required archive member patterns present, zero payload-like archive members, `dispatch_chunk_rows=21`, `dispatch_task_rows=8000`, `dispatch_return_artifact_rows=50`, `dispatch_receipt_template_rows=21`, `accepted_dispatch_receipt_rows=0/21`, `answer_review_accepted_rows=0/7000`, `v53_ready=0`, `actual_model_generation_ready=0`, and zero checkpoint payload bytes committed to the repo, while keeping dispatch receipts, actual review return, v53 readiness, v61 actual generation, and release claims blocked.

v53ad: complete-source review dispatch receipt intake is implemented and covered by `experiments/test_v53ad_complete_source_review_dispatch_receipt_intake.sh`. The runner consumes v53ac and optionally validates `V53AD_DISPATCH_RECEIPT_DIR` receipt JSON files against the 21 review chunk IDs, archive SHA fields, and reviewer/coordinator IDs. The default no-receipt smoke verifies `dispatch_receipt_template_rows=21`, `receipt_dir_supplied=0`, `supplied_dispatch_receipt_rows=0`, `accepted_dispatch_receipt_rows=0`, `missing_dispatch_receipt_rows=21`, `invalid_dispatch_receipt_rows=0`, `dispatch_receipt_intake_ready=0`, `dispatch_archive_ready=1`, `archive_sha256_ready=1`, `payload_like_archive_member_rows=0`, `answer_review_accepted_rows=0/7000`, `review_return_ready=0`, `v53_ready=0`, `actual_model_generation_ready=0`, and zero checkpoint payload bytes committed to the repo, while keeping dispatch receipt completion, actual review return, v53 readiness, v61 actual generation, and release claims blocked.

v53ae: complete-source review return generation rendezvous gate is implemented and covered by `experiments/test_v53ae_complete_source_review_return_generation_rendezvous_gate.sh`. The runner consumes v53ad, v53z, v61de, and v61cx, supports `V53AE_DISPATCH_RECEIPT_DIR`, `V53AE_REVIEW_CHUNK_RETURN_DIR`, `V53AE_REVIEW_RETURN_DIR`, and `V53AE_GENERATION_RESULT_DIR`, and emits a nine-stage return-to-generation rendezvous gate, next-action rows, command rows, requirement rows, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `rendezvous_stage_rows=9`, `ready_rendezvous_stage_rows=3`, `blocked_rendezvous_stage_rows=6`, `next_action_rows=5`, `ready_next_action_rows=2`, `accepted_dispatch_receipt_rows=0/21`, `accepted_chunk_return_artifact_rows=0/50`, `answer_review_accepted_rows=0/7000`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v53ae=0`, and zero checkpoint payload bytes committed to the repo, while keeping review return, generation execution, generation result acceptance, production-latency, near-frontier, and release claims blocked.

v53af: external return inbox scaffold is implemented and covered by `experiments/test_v53af_external_return_inbox_scaffold.sh`. The runner consumes v53ae and v61df, creates a zero-evidence `return_inbox/` with `.template` files for dispatch receipts, review chunk returns, aggregate review returns, and generation result returns, and emits template rows, required artifact index rows, file rows, requirement rows, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `required_return_artifact_rows=81`, `dispatch_receipt_template_files=21`, `review_chunk_return_template_files=50`, `aggregate_review_return_template_files=5`, `generation_result_template_files=5`, `return_inbox_file_rows=84`, `template_files_accepted_by_default=0`, `answer_review_accepted_rows=0`, `generation_execution_admitted_rows=0`, `accepted_generation_result_artifacts=0`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53af=0`, and zero checkpoint payload bytes committed to the repo, while keeping all returned-review, generation-result, actual-generation, production-latency, near-frontier, and release claims blocked.

v53ag: external return inbox archive is implemented and covered by `experiments/test_v53ag_external_return_inbox_archive.sh`. The runner consumes v53af, archives `return_inbox/` into `archive/v53af_external_return_inbox_scaffold_001.tar.gz`, writes `ARCHIVE_FILE_LIST.txt`, `ARCHIVE_SHA256SUMS.txt`, send instructions, archive member rows, artifact rows, requirement rows, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `archive_ready=1`, `archive_sha256_ready=1`, `archive_file_list_ready=1`, `send_readme_ready=1`, `archive_member_files=84`, `template_archive_member_rows=82`, `return_artifact_template_archive_member_rows=81`, `required_members_present=1`, `payload_like_archive_member_rows=0`, `final_evidence_named_archive_member_rows=0`, `answer_review_accepted_rows=0`, `generation_execution_admitted_rows=0`, `accepted_generation_result_artifacts=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v53ag=0`, and zero checkpoint payload bytes committed to the repo, while keeping all returned-review, generation-result, actual-generation, production-latency, near-frontier, and release claims blocked.

v53ah: complete-source external review send bundle is implemented and covered by `experiments/test_v53ah_complete_source_external_review_send_bundle.sh`. The runner consumes v53ac and v53ag, copies the review dispatch archive and template-only return inbox archive into one `send_bundle/`, writes `BUNDLE_FILE_LIST.txt`, `BUNDLE_SHA256SUMS.txt`, a send README, an executable verifier, bundle file rows, nested archive member rows, artifact rows, requirement rows, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `send_bundle_ready=1`, `send_bundle_archive_files=2`, dispatch archive members 78, return inbox archive members 84, `return_artifact_template_archive_member_rows=81`, `payload_like_bundle_file_rows=0`, `nested_payload_like_archive_member_rows=0`, `return_inbox_final_evidence_named_archive_member_rows=0`, `accepted_dispatch_receipt_rows=0/21`, `answer_review_accepted_rows=0/7000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53ah=0`, and zero checkpoint payload bytes committed to the repo, while keeping dispatch receipts, returned review, generation execution, generation result acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v53ai: complete-source external return bundle intake is implemented and covered by `experiments/test_v53ai_complete_source_external_return_bundle_intake.sh`. The runner consumes v53ah, v53ae, and the v53af required artifact index; optionally maps `V53AI_RETURN_BUNDLE_DIR` into dispatch receipt, review chunk return, aggregate review return, and generation result return directories; refreshes v53ae with supplied paths; and emits return artifact mapping rows, family rows, requirement rows, metric rows, runtime gaps, receive instructions, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies four return families, `required_return_artifact_rows=81`, `supplied_return_artifact_rows=0`, `missing_return_artifact_rows=81`, `accepted_by_v53ai_rows=0`, `return_bundle_mapping_ready=1`, `all_return_artifacts_present=0`, `send_bundle_ready=1`, `rendezvous_stage_rows=9`, `ready_rendezvous_stage_rows=3`, `answer_review_accepted_rows=0/7000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53ai=0`, and zero checkpoint payload bytes committed to the repo, while keeping returned review, generation execution, generation result acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v53aj: complete-source return closure dashboard is implemented and covered by `experiments/test_v53aj_complete_source_return_closure_dashboard.sh`. The runner consumes v53ai, v53ae, v53v, and v61de, then emits a 12-item closure dashboard, next-action rows, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `closure_item_rows=12`, `ready_closure_item_rows=3`, `blocked_closure_item_rows=9`, `next_action_rows=5`, `ready_next_action_rows=1`, `send_bundle_ready=1`, `return_bundle_mapping_ready=1`, `required_return_artifact_rows=81`, `supplied_return_artifact_rows=0`, `missing_return_artifact_rows=81`, `accepted_by_v53ai_rows=0`, `accepted_dispatch_receipt_rows=0/21`, `accepted_chunk_return_artifact_rows=0/50`, `answer_review_accepted_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `v53_ready=0`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53aj=0`, and zero checkpoint payload bytes committed to the repo, while keeping returned review, generation execution, generation result acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v53ak: complete-source external return operator checklist is implemented and covered by `experiments/test_v53ak_complete_source_external_return_operator_checklist.sh`. The runner consumes v53aj and v53ai, then emits one checklist row per required return artifact, family checklist rows, closure checklist rows, requirement rows, metric rows, runtime gaps, operator instructions, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `operator_checklist_ready=1`, `checklist_rows=81`, `dispatch_receipt_checklist_rows=21`, `review_chunk_return_checklist_rows=50`, `aggregate_review_return_checklist_rows=5`, `generation_result_return_checklist_rows=5`, `supplied_checklist_rows=0`, `missing_checklist_rows=81`, `template_named_supplied_rows=0`, `accepted_by_v53ak_rows=0`, `closure_checklist_rows=9`, `family_checklist_rows=4`, `ready_closure_item_rows=3`, `blocked_closure_item_rows=9`, `answer_review_accepted_rows=0`, `generation_execution_admitted_rows=0`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53ak=0`, and zero checkpoint payload bytes committed to the repo, while keeping all returned-evidence, generation, latency, near-frontier, and release claims blocked.

v53al: complete-source external return bundle preflight is implemented and covered by `experiments/test_v53al_complete_source_external_return_bundle_preflight.sh`. The runner consumes v53ak, optionally checks `V53AL_RETURN_BUNDLE_DIR`, emits one preflight row per required final artifact, family preflight rows, requirement rows, metric rows, runtime gaps, a receiver README, an executable verifier, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `preflight_surface_ready=1`, `return_bundle_preflight_pass=0`, `preflight_rows=81`, `preflight_pass_rows=0`, `preflight_file_exists_rows=0`, `preflight_missing_rows=81`, `preflight_non_empty_rows=0`, `preflight_template_named_rows=0`, `accepted_by_v53al_rows=0`, `family_preflight_rows=4`, `verifier_script_ready=1`, `operator_checklist_ready=1`, `answer_review_accepted_rows=0`, `generation_execution_admitted_rows=0`, `actual_model_generation_ready=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53al=0`, and zero checkpoint payload bytes committed to the repo, while keeping downstream review/generation acceptance, actual generation, production-latency, near-frontier, and release claims blocked.

v53am: complete-source return acceptance replay is implemented and covered by `experiments/test_v53am_complete_source_return_acceptance_replay.sh`. The runner consumes v53al and then replays the downstream return chain in order: v53ad dispatch receipt intake, v53x chunk return intake, v53y aggregate review refresh, v53z handoff, v61bt generation result intake, v61de post-review generation handoff, and v53ae rendezvous. The default no-return smoke verifies `replay_step_rows=11`, `ready_replay_step_rows=2`, `blocked_replay_step_rows=9`, `replay_command_rows=7`, `ready_replay_command_rows=1`, `return_bundle_preflight_pass=0`, `accepted_dispatch_receipt_rows=0/21`, `accepted_chunk_return_artifact_rows=0/50`, `answer_review_accepted_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `accepted_by_v53am_rows=0`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `checkpoint_payload_bytes_downloaded_by_v53am=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated critical-only supplied fixture and verifies `preflight_pass_rows=10/81`, `return_bundle_preflight_pass=0`, dispatch/chunk/review/generation acceptance rows still at 0, and actual generation blocked, while restoring the canonical no-return summary afterward.

v61de: post-review generation result handoff bridge is implemented and covered by `experiments/test_v61de_post_review_generation_result_handoff_bridge.sh`. The runner refreshes v53z, v61ct, optionally v61bt with `V61DE_GENERATION_RESULT_DIR`, v61cu, and v61dd, then emits an eight-stage post-review bridge from accepted review return to guarded generation execution, result artifact intake, final query-level acceptance, and actual-generation readiness. The default no-return smoke verifies `handoff_stage_rows=8`, `ready_handoff_stage_rows=3`, `blocked_handoff_stage_rows=5`, `ready_handoff_command_rows=2`, `full_shard_prerequisites_closed=1`, `runtime_admission_accepted_rows=1000`, `answer_review_accepted_rows=0/7000`, `generation_execution_admitted_rows=0/1000`, `guarded_generation_command_ready=0`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61de=0`, and zero checkpoint payload bytes committed to the repo, while keeping review return, generation execution, generation result acceptance, production-latency, near-frontier, and release claims blocked.

v61df: external review/generation return operator packet is implemented and covered by `experiments/test_v61df_external_review_generation_return_operator_packet.sh`. The runner refreshes v53z and v61de, consumes v53u/v53w/v53z/v61ct/v61de, and emits a single zero-payload operator packet with review templates, generation result templates, required artifact lists, command ordering, a packet verifier, metric rows, runtime gaps, boundary, manifest, copied source evidence, and hash rows. The smoke verifies `operator_stage_rows=7`, `ready_operator_stage_rows=3`, `blocked_operator_stage_rows=4`, `operator_command_rows=6`, `ready_operator_command_rows=3`, `operator_packet_file_rows=8`, `ready_operator_packet_file_rows=8`, `review_return_required_artifacts=5`, `generation_result_required_artifacts=5`, `review_chunk_rows=21`, `review_chunk_task_rows=8000`, `answer_review_accepted_rows=0/7000`, `runtime_admission_accepted_rows=1000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61df=0`, and zero checkpoint payload bytes committed to the repo, while keeping review return, generation execution, generation result acceptance, production-latency, near-frontier, and release claims blocked.

v61dg: post-full-shard runtime evidence promotion gate is implemented and covered by `experiments/test_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh`. The runner consumes v61cj/v61l/v61m/v61s/v61cm/v61cb/v61cx/v61cw/v61cs and promotes the positive runtime-evidence boundary after full-shard closure without accepting generation. The smoke verifies `evidence_rows=16`, `ready_evidence_rows=9`, `blocked_evidence_rows=7`, `post_full_shard_runtime_evidence_ready=1`, 59/59 checkpoint shards, 134161/134161 page hashes, ROCm page-kernel average `0.513442` ms, KV policy ready with host RAM spill disabled, source-bound QA pass 37/37, complete-source runtime admission 1000/1000, `generation_execution_admitted_rows=0/1000`, `answer_review_accepted_rows=0/7000`, `accepted_generation_result_artifacts=0/5`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dg=0`, and zero checkpoint payload bytes committed to the repo, while keeping generation execution, returned generation acceptance, production-latency, near-frontier, and release claims blocked.

v61dh: post-full-shard claim audit gate is implemented and covered by `experiments/test_v61dh_post_full_shard_claim_audit_gate.sh`. The runner consumes v52y, v53t, and v61dg, then freezes the allowed/blocked claim posture without adding review, generation, or release evidence. The smoke verifies `claim_rows=15`, `allowed_claim_rows=7`, `blocked_claim_rows=8`, `claim_invariant_rows=6`, `claim_invariant_pass_rows=6`, `v52_ready=1`, `f_optional_final_disposition=deferred-with-reason-final`, `comparison_30b_150b_wording_status=allowed-with-disclosure`, `v53_machine_complete_source_surface_ready=1`, `accepted_human_review_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `v53_ready=0`, `v61_post_full_shard_runtime_evidence_ready=1`, `ready_evidence_rows=9`, `blocked_evidence_rows=7`, `generation_execution_admitted_rows=0/1000`, `actual_model_generation_ready=0`, `v1_0_comparison_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dh=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, production-latency, near-frontier, v1.0 comparison, and release claims blocked.

v61di: post-claim generation unblock audit gate is implemented and covered by `experiments/test_v61di_post_claim_generation_unblock_audit_gate.sh`. The runner consumes v61dh, v53am, and v61df, then audits the exact returned-evidence ladder that remains after full-shard/runtime/claim closure. The smoke verifies `unblock_stage_rows=12`, `ready_unblock_stage_rows=6`, `blocked_unblock_stage_rows=6`, `unblock_command_rows=9`, `ready_unblock_command_rows=2`, `claim_audit_ready=1`, `return_acceptance_replay_ready=1`, `return_acceptance_replay_closed=0`, `operator_packet_file_rows=8/8`, `return_bundle_preflight_pass=0`, `accepted_human_review_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `runtime_admission_accepted_rows=1000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `v1_0_comparison_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61di=0`, and zero checkpoint payload bytes committed to the repo, while keeping actual generation, v1.0 comparison, production-latency, near-frontier, and release claims blocked.

v61dj: post-claim return evidence contract gate is implemented and covered by `experiments/test_v61dj_post_claim_return_evidence_contract_gate.sh`. The runner consumes v61di, v61df, and v53al, then turns the remaining returned-evidence blockers into a machine-readable contract. The smoke verifies `return_contract_blocker_rows=6`, `unsatisfied_return_contract_blocker_rows=6`, `return_artifact_contract_rows=10`, `satisfied_return_artifact_contract_rows=0`, `unsatisfied_return_artifact_contract_rows=10`, `return_artifact_family_rows=2`, `return_contract_command_rows=5`, `ready_return_contract_command_rows=2`, `return_bundle_preflight_pass=0`, `preflight_pass_rows=0/81`, `review_return_expected_rows=8232`, `review_return_accepted_rows=0`, `generation_result_expected_rows=4001`, `generation_result_accepted_contract_rows=0`, `generation_execution_admitted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dj=0`, and zero checkpoint payload bytes committed to the repo, while keeping returned review evidence, generation result evidence, actual generation, v1.0 comparison, production-latency, near-frontier, and release claims blocked.

v61dk: return contract final bundle crosswalk gate is implemented and covered by `experiments/test_v61dk_return_contract_final_bundle_crosswalk_gate.sh`. The runner consumes v61dj, v53ak, and v53al, then maps the 10 critical return contract artifacts onto the 81-artifact final return bundle checklist and preflight rows. The smoke verifies `contract_artifact_rows=10`, `crosswalk_rows=10`, `mapped_crosswalk_rows=10`, `unmapped_crosswalk_rows=0`, `family_crosswalk_rows=2`, `contract_preflight_pass_rows=0`, `contract_preflight_missing_rows=10`, `full_preflight_rows=81`, `full_preflight_pass_rows=0`, `full_preflight_missing_rows=81`, `return_bundle_preflight_pass=0`, `operator_checklist_rows=81`, `aggregate_review_crosswalk_rows=5`, `generation_result_crosswalk_rows=5`, `review_return_expected_rows=8232`, `generation_result_expected_rows=4001`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dk=0`, and zero checkpoint payload bytes committed to the repo, while keeping final return bundle acceptance, actual generation, v1.0 comparison, production-latency, near-frontier, and release claims blocked.

v61dl: critical return contract preflight gate is implemented and covered by `experiments/test_v61dl_critical_return_contract_preflight_gate.sh`. The runner consumes v61dk and optionally `V61DL_RETURN_BUNDLE_DIR`, then emits a reusable `VERIFY_CRITICAL_RETURN_CONTRACT.sh` for the 10 critical return paths. The default no-return smoke verifies `critical_artifact_rows=10`, `critical_preflight_pass_rows=0`, `critical_preflight_missing_rows=10`, `critical_preflight_non_empty_rows=0`, `critical_preflight_ready=0`, `return_bundle_dir_supplied=0`, `return_bundle_dir_exists=0`, `critical_family_rows=2`, `critical_command_rows=3`, `ready_critical_command_rows=2`, `full_preflight_rows=81`, `return_bundle_preflight_pass=0`, `review_return_expected_rows=8232`, `generation_result_expected_rows=4001`, `generation_execution_admitted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dl=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated supplied-return fixture that passes all 10 critical artifacts, verifies the executable verifier, keeps full 81-artifact preflight and actual generation blocked, and restores the canonical no-return summary afterward.

v61dm: critical return acceptance bridge gate is implemented and covered by `experiments/test_v61dm_critical_return_acceptance_bridge_gate.sh`. The runner consumes v61dl and v53am, then bridges the 10 critical return artifacts to the 81-artifact/full row-level acceptance replay. The default no-return smoke verifies `bridge_step_rows=11`, `ready_bridge_step_rows=2`, `blocked_bridge_step_rows=9`, `critical_preflight_pass_rows=0/10`, `full_preflight_pass_rows=0/81`, `return_bundle_preflight_pass=0`, `accepted_dispatch_receipt_rows=0/21`, `accepted_chunk_return_artifact_rows=0/50`, `answer_review_accepted_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `generation_execution_admitted_rows=0/1000`, `accepted_generation_result_artifacts=0/5`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `acceptance_bridge_closed=0`, `checkpoint_payload_bytes_downloaded_by_v61dm=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated critical-only supplied fixture that reaches `critical_preflight_pass_rows=10/10` and `full_preflight_pass_rows=10/81` while keeping dispatch/chunk/review/generation acceptance rows at 0 and actual generation blocked.

v61dn: residual return completion gate is implemented and covered by `experiments/test_v61dn_residual_return_completion_gate.sh`. The runner consumes v61dm and v53ak, subtracts the 10 v61dk/v61dl critical artifacts from the 81-artifact final return checklist, and emits the remaining 71-artifact completion queue. The default no-return smoke verifies `completion_stage_rows=7`, `ready_completion_stage_rows=2`, `blocked_completion_stage_rows=5`, `full_return_artifact_rows=81`, `critical_artifact_rows=10`, `residual_artifact_rows=71`, `dispatch_receipt_residual_rows=21`, `review_chunk_residual_rows=50`, `residual_preflight_pass_rows=0/71`, `critical_preflight_pass_rows=0/10`, `full_preflight_pass_rows=0/81`, `answer_review_accepted_rows=0/7000`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dn=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated critical-only fixture that keeps residual rows at 0/71 while critical rows reach 10/10.

v61do: full return preflight acceptance boundary gate is implemented and covered by `experiments/test_v61do_full_return_preflight_acceptance_boundary_gate.sh`. The runner consumes v61dn, v53al, and v53am, then separates 81-artifact presence preflight from row-level returned-evidence acceptance. The default no-return smoke verifies `boundary_stage_rows=9`, `ready_boundary_stage_rows=0`, `blocked_boundary_stage_rows=9`, `critical_preflight_pass_rows=0/10`, `residual_preflight_pass_rows=0/71`, `full_preflight_pass_rows=0/81`, `return_bundle_preflight_pass=0`, `answer_review_accepted_rows=0/7000`, `accepted_adjudication_rows=0/1000`, `generation_result_accepted_rows=0/1000`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61do=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated full-preflight-only fixture where all 81 files pass preflight, while dispatch/chunk/review/generation row acceptance remains 0 and actual generation stays blocked.

v61dp: return schema acceptance blocker gate is implemented and covered by `experiments/test_v61dp_return_schema_acceptance_blocker_gate.sh`. The runner consumes v61do and v53am, then groups the post-preflight blockers into dispatch receipt JSON, review chunk CSV, aggregate review return, and generation result return families. The default no-return smoke verifies `schema_family_rows=4`, `ready_schema_family_rows=0`, `expected_schema_artifact_rows=81`, `supplied_schema_artifact_rows=0`, `accepted_schema_artifact_rows=0`, `missing_schema_artifact_rows=81`, `expected_payload_rows=17483`, `accepted_payload_rows=0`, and `actual_model_generation_ready=0`. The full-preflight-only fixture verifies `full_preflight_pass_rows=81/81`, `supplied_schema_artifact_rows=31`, `accepted_schema_artifact_rows=0`, `missing_schema_artifact_rows=50`, `invalid_schema_artifact_rows=31`, `accepted_payload_rows=0/17483`, and actual generation blocked.

v61dq: return schema remediation packet gate is implemented and covered by `experiments/test_v61dq_return_schema_remediation_packet_gate.sh`. The runner consumes v61dp and the authoritative v53/v61 return schema sources, then emits an operator remediation packet with dispatch receipt JSON, review chunk CSV, aggregate review return, and generation result return templates. The smoke verifies `remediation_packet_ready=1`, `remediation_family_rows=4`, `remediation_artifact_rows=81`, `template_file_rows=11`, `remediation_command_rows=4`, `ready_remediation_command_rows=3`, `expected_schema_artifact_rows=81`, `accepted_schema_artifact_rows=0`, `expected_payload_rows=17483`, `accepted_payload_rows=0`, `schema_acceptance_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dq=0`, and zero checkpoint payload bytes committed to the repo.

v61dr: return bundle schema preflight gate is implemented and covered by `experiments/test_v61dr_return_bundle_schema_preflight_gate.sh`. The runner consumes v61dq and optionally `V61DR_RETURN_BUNDLE_DIR`, then validates all 81 final return artifacts for presence, non-empty payloads, CSV headers, JSON required fields, and artifact row counts before downstream intake. The default no-return smoke verifies `schema_preflight_artifact_rows=81`, `schema_preflight_pass_rows=0`, `schema_preflight_missing_rows=81`, `schema_preflight_pass=0`, `expected_artifact_row_instances=20485`, `observed_artifact_row_instances=0`, `expected_payload_rows=17483`, `accepted_payload_rows=0`, `schema_acceptance_ready=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61dr=0`, and zero checkpoint payload bytes committed to the repo. The smoke also runs an isolated full-schema fixture that reaches `schema_preflight_pass_rows=81/81` and exercises the generated verifier while restoring the canonical no-return summary.

v61ds: schema preflight acceptance handoff gate is implemented and covered by `experiments/test_v61ds_schema_preflight_acceptance_handoff_gate.sh`. The runner consumes v61dr and v53am, copies their source summaries/decisions, and emits a 12-stage handoff audit from returned-bundle schema preflight to dispatch/chunk/review/generation acceptance. The smoke verifies `v61ds_schema_preflight_acceptance_handoff_gate_ready=1`, `source_gate_rows=2`, `handoff_stage_rows=12`, `ready_handoff_stage_rows=2`, `blocked_handoff_stage_rows=10`, `handoff_command_rows=12`, `ready_handoff_command_rows=4`, `schema_preflight_pass_rows=0`, `accepted_payload_rows=0`, `schema_acceptance_ready=0`, `return_acceptance_replay_closed=0`, `actual_model_generation_ready=0`, `checkpoint_payload_bytes_downloaded_by_v61ds=0`, and zero checkpoint payload bytes committed to the repo.

v52r: measured registry D/E absorb is implemented and covered by `experiments/test_v52r_measured_registry_de_absorb.sh`. The runner absorbs the v52i A/B/G/H measured packet plus the v52l C and v52p/v52q D/E measured packets into an updated v52 measured registry, writes `measured_baseline_registry.csv`, `measured_artifact_absorb_rows.csv`, copied v52i/v52l/v52p/v52q evidence, `V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md`, `v52r_measured_registry_de_absorb_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52r_measured_registry_de_absorb_ready=1`, seven local measured systems A/B/C/D/E/G/H, 7000 answer/citation/abstain/guard/resource rows, `required_30b_baseline_ready=1`, `required_70b_baseline_ready=1`, and strict exact-label accuracy fields for C/D/E without quality claims, while keeping optional F, `v52_ready=0`, and release/comparison claims blocked.

v52y: F optional final policy is implemented and covered by `experiments/test_v52y_f_optional_final_policy.sh`. The runner consumes v52r and v52e, writes `f_optional_final_rows.csv`, `v52_ready_condition_rows.csv`, `comparison_wording_rows.csv`, boundary, manifest, and hash rows. In the default no-env path it records `f_optional_final_disposition=deferred-with-reason-final`, keeps `optional_100b_plus_baseline_ready=0`, verifies all eight v52-ready condition rows, sets `v52_ready=1` for `measured-baseline-registry-with-f-final-disposition`, and marks `comparison_30b_150b_wording_status=allowed-with-disclosure`. It blocks measured 100B+/150B hosted baseline result, v53 complete-source audit, v1.0 comparison readiness, and release claims.

v52l: 7B-14B local model + RAG v53e 1000-row expansion is implemented and covered by `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh`. The runner uses local Ollama `qwen2.5:7b-instruct`, generates baseline-C responses for the full frozen v53e 1000-query/source-span set, writes shared `frozen_query_rows.csv`, `frozen_source_span_rows.csv`, `source_manifest_rows.csv`, `model_identity.json`, `c_answer_rows.csv`, `c_citation_rows.csv`, `c_retrieval_rows.csv`, `c_abstain_rows.csv`, `c_wrong_answer_guard_rows.csv`, `c_resource_rows.csv`, `ollama_generation_transcript_rows.csv`, `c_system_metric_rows.csv`, copied v53e evidence, `V52L_7B14B_LOCAL_MODEL_RAG_V53E_BOUNDARY.md`, `v52l_7b14b_local_model_rag_v53e_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v52l_7b14b_local_model_rag_v53e_1000_ready=1`, 1000 answer/citation/retrieval/abstain/wrong-answer/resource/transcript rows, same query/source manifest as v52i A/B/G/H, local/no-network execution, and `c_v53e_absorb_ready=1`. The run records 0/1000 strict exact-label accuracy, so it is a measured C response packet and schema pressure test, not a C quality claim; D/E 30B/70B rows, full v52, and release claims remain blocked.

v52d: 30B/70B open-weight LLM+RAG evidence intake is implemented and covered by `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh`. The runner assembles `results/v52d_30b70b_llm_rag_evidence_intake/intake_001/`, reruns the v50 public-repo seed, writes `llm_rag_required_field_rows.csv`, `llm_rag_answer_template.csv`, `model_identity_templates.json`, `llm_rag_validation_rows.csv`, copied v50 source evidence, `V52D_30B70B_LLM_RAG_BOUNDARY.md`, `v52d_30b70b_llm_rag_manifest.json`, and `sha256_manifest.csv`. The smoke verifies the D/E evidence-intake schema, 18 answer-template rows, 30B and 70B model identity templates, open-weight/no-external-API requirements, hash manifest, and no-env stop rule, while keeping `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, and `real_release_package_ready=0` until real D and E evidence directories are both supplied and validate.

v52e: 100B+ hosted/API LLM+RAG optional intake is implemented and covered by `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`. The runner assembles `results/v52e_100b_plus_hosted_llm_rag_optional_intake/intake_001/`, reruns the v50 public-repo seed, writes `hosted_llm_rag_required_field_rows.csv`, `hosted_llm_rag_answer_template.csv`, `model_identity_template.json`, `hosted_llm_rag_validation_rows.csv`, copied v50 source evidence, `V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md`, `v52e_100b_plus_hosted_llm_rag_manifest.json`, and `sha256_manifest.csv`. The smoke verifies the F optional evidence-intake schema, nine answer-template rows, hosted/API identity template, credential-redaction and public-reporting policy requirements, hash manifest, and no-env defer rule, while keeping `optional_100b_plus_baseline_status=deferred-with-reason`, `optional_100b_plus_baseline_ready=0`, `v52_optional_absorb_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, `v52_ready=0`, and `real_release_package_ready=0`. F is optional and cannot replace the required D/E rows.

v53: Public repo code/doc audit contract scaffold is implemented and covered by `experiments/test_v53_public_repo_code_doc_audit.sh`. The runner assembles `results/v53_public_repo_code_doc_audit/audit_001/`, reruns the v50 3-repo seed, writes `target_repo_rows.csv`, `query_scale_contract_rows.csv`, `artifact_contract_rows.csv`, copied v50 source evidence, `V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md`, `v53_public_repo_code_doc_audit_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53_public_repo_code_doc_audit_contract_ready=1`, target minimums of 10 repos and 1000 queries, seed evidence of 3 repos and 9 audit cases, pinned commit/source-span contract readiness, and release blocking, while keeping `v53_ready=0`, `missing_repo_count=7`, `missing_query_rows=991`, and the negative-control scale target blocked until the full public repo audit is supplied.

v53b: Public repo 10-lock is implemented and covered by `experiments/test_v53b_public_repo_10_lock.sh`. The runner assembles `results/v53b_public_repo_10_lock/lock_001/`, reruns the v50 public-repo seed, resolves live `git ls-remote --symref` HEAD SHAs for 10 public GitHub repositories, writes `public_repo_10_lock_rows.csv`, `public_repo_10_query_plan_rows.csv`, copied v50 source evidence, `V53B_PUBLIC_REPO_10_LOCK_BOUNDARY.md`, `v53b_public_repo_10_lock_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53b_public_repo_10_lock_ready=1`, 10 pinned repo HEAD SHAs, 3 v50 seed repos, 7 new source snapshots required, a 1000-row query plan with 9 seed rows and 991 missing rows, and release blocking, while keeping `v53_ready=0` until source snapshots, source-span-bound query rows, answers, citations, negative/abstain rows, and review artifacts are supplied.

v53c: Public repo canary source snapshot is implemented and covered by `experiments/test_v53c_public_repo_canary_source_snapshot.sh`. The runner assembles `results/v53c_public_repo_canary_source_snapshot/snapshot_001/`, reruns the v53b 10-repo lock, fetches pinned canary source/doc/config files from the locked GitHub HEAD SHAs, writes `public_repo_canary_source_snapshot_rows.csv`, `public_repo_canary_status_rows.csv`, `public_repo_canary_fetch_error_rows.csv`, copied v53b lock evidence, `V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md`, `v53c_public_repo_canary_source_snapshot_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53c_canary_source_snapshot_ready=1`, 10 canary-covered repos, at least 20 sha256-bound canary source files, v53b lock binding, and release blocking, while keeping `v53_ready=0`, `full_source_snapshot_missing_repo_count=7`, and `missing_query_rows=991` until full source snapshots and the 1000-row audit evidence exist.

v53d: Canary source query seed 100 is implemented and covered by `experiments/test_v53d_canary_source_query_seed_100.sh`. The runner assembles `results/v53d_canary_source_query_seed_100/query_001/`, reruns v53c, derives 100 source-span-bound canary query rows across the 10 locked repositories, writes `canary_query_rows.csv`, `canary_source_span_rows.csv`, `canary_query_family_rows.csv`, `canary_query_repo_rows.csv`, copied v53c evidence, `V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md`, `v53d_canary_source_query_seed_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53d_canary_query_seed_ready=1`, 100 query rows, 100 matching source-span rows, 10 repos, 10 query rows per repo, source file/content hash binding back to v53c canary snapshots, and release blocking, while keeping `v53_ready=0`, `missing_query_rows=900`, negative/abstain family coverage blocked, A-H answer/citation/resource rows blocked, and full v51 blocked.

v53e: Canary query scale 1000 is implemented and covered by `experiments/test_v53e_canary_query_scale_1000.sh`. The runner assembles `results/v53e_canary_query_scale_1000/scale_001/`, reruns v53d, scales the canary query seed to 1000 source-span-bound query rows across the 10 locked repositories, writes `scaled_canary_query_rows.csv`, `scaled_canary_source_span_rows.csv`, `scaled_canary_query_family_rows.csv`, `scaled_canary_query_repo_rows.csv`, copied v53d/v53c evidence, `V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md`, `v53e_canary_query_scale_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53e_canary_query_scale_ready=1`, 1000 query rows, 1000 matching source-span rows, 840 supported rows, 160 negative/abstain rows, eight query families, 10 repos, v53d parent binding, expected-answer hashes, and release blocking, while keeping `v53_ready=0`, full source snapshot scale blocked, A-H answer/citation/resource rows blocked, review artifacts blocked, and full v51 blocked.

v53f: A-H answer/citation/resource intake is implemented and covered by `experiments/test_v53f_ah_answer_citation_resource_intake.sh`. The runner assembles `results/v53f_ah_answer_citation_resource_intake/intake_001/`, reruns v53e, writes `ah_system_target_rows.csv`, required answer/citation/resource schemas, `ah_answer_row_template.csv`, `ah_resource_row_template.csv`, supplied validation rows, copied v53e evidence, `V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md`, `v53f_ah_answer_citation_resource_intake_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53f_ah_answer_citation_resource_intake_ready=1`, 1000 frozen query rows, eight target systems A-H, seven required core systems, 8000 target answer/resource rows, required schemas, hash manifests, and release blocking, while keeping `v53_ready=0`, `valid_answer_rows=0`, supplied A-H rows blocked, citation/resource coverage blocked, full source snapshot scale blocked, review artifacts blocked, and full v51 blocked.

v53g: Complete source manifest is implemented and covered by `experiments/test_v53g_complete_source_manifest.sh`. The runner assembles `results/v53g_complete_source_manifest/manifest_001/`, reruns v53f, fetches recursive Git tree metadata for the 10 locked repositories, writes `complete_source_file_manifest_rows.csv`, `complete_source_repo_coverage_rows.csv`, `complete_source_query_budget_rows.csv`, `complete_source_gap_rows.csv`, copied v53b/v53c/v53f evidence, `V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md`, `v53g_complete_source_manifest_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v53g_complete_source_manifest_ready=1`, 10 complete tree manifest-ready repos, 11318 source/doc/config/test manifest rows, 11312 query-eligible file rows, at least 20 canary-overlap rows, and an eight-family 1000-query budget, while keeping `v53_ready=0`, content materialization, complete-source query rows, A-H answer/citation/resource rows, review artifacts, and release claims blocked.

v53h: Complete source content snapshot is implemented and covered by `experiments/test_v53h_complete_source_content_snapshot.sh`. The runner consumes v53g, reads the pinned Git blobs from the local v53g git cache, materializes the complete source/doc/config/test content snapshot for all 10 locked repositories, and writes `complete_source_content_snapshot_rows.csv`, `complete_source_content_repo_rows.csv`, `complete_source_content_gap_rows.csv`, boundary, manifest, copied v53g evidence, content files, and hash rows. The smoke verifies `v53h_complete_source_content_snapshot_ready=1`, 10 content-ready repos, 11318 materialized content files, 11318 content sha256 rows, 124845122 content bytes, 11312 query-eligible content rows, and `complete_source_content_snapshot_ready=1`, while keeping complete-source span extraction, 1000+ complete-source query rows, A-H answer/citation/resource rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53i: Complete source query instantiation is implemented and covered by `experiments/test_v53i_complete_source_query_instantiation.sh`. The runner consumes v53h, applies the v53g eight-family 1000-query budget to line-level spans from the materialized complete-source content snapshot, and writes `complete_source_query_rows.csv`, `complete_source_span_rows.csv`, `complete_source_query_family_rows.csv`, `complete_source_query_repo_rows.csv`, `complete_source_query_gap_rows.csv`, copied v53h/v53g evidence, boundary, manifest, and hash rows. The smoke verifies `v53i_complete_source_query_instantiation_ready=1`, 1000 complete-source query rows, 1000 matching source-span rows, 840 supported rows, 160 negative/abstain rows, eight families, 10 repos, content hash and pinned-line evidence binding back to v53h, while keeping A-H answer/citation/resource rows, symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53j: Complete source A-H answer/citation/resource intake is implemented and covered by `experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh`. The runner consumes v53i and v52y, writes complete-source A-H system targets, answer/citation/resource schemas, 7000 A/B/C/D/E/G/H core answer/resource templates, an optional-F final-policy row, supplied validation rows, copied v53i/v52y evidence, boundary, manifest, and hash rows. The smoke verifies `v53j_complete_source_ah_intake_ready=1`, 1000 complete-source query rows, 1000 source-span rows, seven required core systems, 7000 core answer/resource/citation targets, F `deferred-with-reason-final`, and release blocking, while keeping supplied core answer/citation/resource rows, symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53k: Complete source System A lexical measured rows are implemented and covered by `experiments/test_v53k_complete_source_system_a_lexical_measured.sh`. The runner consumes v53j, writes System A answer/citation/resource/retrieval/guard/metric rows over the frozen v53i 1000-query set, emits a partial `supplied_v53j/` directory, partial v53j validation rows, boundary, manifest, copied v53j/v53i evidence, and hash rows. The smoke verifies `v53k_complete_source_system_a_lexical_ready=1`, 1000 System A answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 guard rows, v53j-compatible supplied rows, and `remaining_core_systems=B/C/D/E/G/H`, while keeping symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53l: Complete source System B local-RAG measured rows are implemented and covered by `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh`. The runner consumes v53k, writes System B answer/citation/resource/retrieval/guard/metric rows over the same frozen v53i 1000-query set, emits combined A+B `supplied_v53j/` rows, partial validation rows, boundary, manifest, copied v53k/v53j/v53i evidence, and hash rows. The smoke verifies `v53l_complete_source_system_b_local_rag_ready=1`, 1000 System B answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 guard rows, 2000 combined A+B answer/citation/resource rows, and `remaining_core_systems=C/D/E/G/H`, while keeping symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53m: Complete source System C local-model-RAG measured rows are implemented and covered by `experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh`. The runner consumes v53l, runs local Ollama `qwen2.5:7b-instruct` over the same frozen v53i 1000-query set, writes System C answer/citation/resource/retrieval/abstain/guard/transcript/metric rows, emits combined A+B+C `supplied_v53j/` rows, partial validation rows, boundary, manifest, copied v53l/v53k/v53j/v53i evidence, and hash rows. The smoke verifies `v53m_complete_source_system_c_local_model_rag_ready=1`, 1000 System C answer rows, 1000 citation rows, 1000 resource rows, 1000 transcript rows, 3000 combined A+B+C answer/citation/resource rows, `c_strict_expected_answer_match_rows=0`, `c_wrong_answer_rows=961`, and `remaining_core_systems=D/E/G/H`, while keeping symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53n: Complete source System G RouteMemory+RouteHint measured rows are implemented and covered by `experiments/test_v53n_complete_source_system_g_routehint_measured.sh`. The runner consumes v53m, writes System G answer/citation/resource/retrieval/guard/metric rows over the same frozen v53i 1000-query set, emits route-memory evidence rows, compact RouteHint rows, scorer-policy preview rows, combined A+B+C+G `supplied_v53j/` rows, partial validation rows, boundary, manifest, copied v53m/v53l/v53k/v53j/v53i evidence, and hash rows. The smoke verifies `v53n_complete_source_system_g_routehint_ready=1`, 1000 System G answer rows, 1000 citation rows, 1000 resource rows, 1000 route-memory evidence rows, 1000 compact RouteHint rows, `g_raw_prompt_context_bytes=0`, 4000 combined A+B+C+G answer/citation/resource rows, and `remaining_core_systems=D/E/H`, while keeping symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53o: Complete source System H RouteMemory+RouteHint+source-verified-scorer+domain-policy measured rows are implemented and covered by `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`. The runner consumes v53n, writes System H answer/citation/resource/retrieval/guard/metric rows over the same frozen v53i 1000-query set, emits route-memory evidence rows, compact RouteHint rows, source-verified scorer rows, domain-policy rows, combined A+B+C+G+H `supplied_v53j/` rows, partial validation rows, boundary, manifest, copied v53n/v53m/v53l/v53k/v53j/v53i evidence, and hash rows. The smoke verifies `v53o_complete_source_system_h_routehint_scorer_policy_ready=1`, 1000 System H answer rows, 1000 citation rows, 1000 resource rows, 1000 source-verified scorer rows, 1000 domain-policy rows, `h_raw_prompt_context_bytes=0`, 5000 combined A+B+C+G+H answer/citation/resource rows, and `remaining_core_systems=D/E`, while keeping symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53p: Complete source System D/E open-weight RAG measured rows are implemented and covered by `experiments/test_v53p_complete_source_system_de_open_weight_rag_measured.sh`. The runner consumes v53o and binds v52p/v52q D/E model identity evidence, writes System D and E answer/citation/resource/retrieval/abstain/guard/transcript/metric rows over the same frozen v53i 1000-query set, emits model-identity rows, combined A+B+C+D+E+G+H `supplied_v53j/` rows, partial validation rows, boundary, manifest, copied v53o/v52p/v52q evidence, and hash rows. The smoke verifies `v53p_complete_source_system_de_open_weight_rag_ready=1`, 1000 D answer/citation/resource rows, 1000 E answer/citation/resource rows, 160 D and 160 E negative/abstain rows, 7000 combined core answer/citation/resource rows, `required_core_systems_ready=1`, and `answer_citation_resource_rows_ready=1`, while keeping D/E quality comparison claims, symmetric scorer/policy rows, review artifacts, `v53_ready=0`, and release claims blocked.

v53q: Complete source symmetric scorer/policy rows are implemented and covered by `experiments/test_v53q_complete_source_symmetric_scorer_policy.sh`. The runner consumes v53p, applies the same source-verification scorer and domain/abstain policy rules to every A/B/C/D/E/G/H answer row over the frozen v53i 1000-query set, and writes `symmetric_scorer_rows.csv`, `symmetric_domain_policy_rows.csv`, system/query/policy summary rows, validation rows, boundary, manifest, copied v53p evidence, and hash rows. The smoke verifies `v53q_complete_source_symmetric_scorer_policy_ready=1`, 7000 scorer rows, 7000 policy rows, 1000 query metric rows, 6000 answer-hash match rows, 1000 preserved C mismatch rows, 7000 source/resource-bound rows, and `symmetric_scorer_policy_rows_ready=1`, while keeping quality comparison claims, review artifacts, `v53_ready=0`, and release claims blocked.

v53r: Complete source review packet is implemented and covered by `experiments/test_v53r_complete_source_review_packet.sh`. The runner consumes v53q, writes `review_query_packet_rows.csv`, `review_answer_packet_rows.csv`, `review_queue_rows.csv`, repo/system packet rows, reviewer assignment templates, review return templates, acceptance criteria, metric rows, boundary, manifest, copied v53q evidence, and hash rows. The smoke verifies `v53r_complete_source_review_packet_ready=1`, 1000 query review packets, 7000 answer review packets, 7000 pending review queue rows, 10 repo packets, 7 system packets, 21 reviewer assignment template rows, 5 review return template rows, p0/p1/p2 priority counts of 1000/960/5040, and `review_packet_ready=1`, while keeping returned human/source review artifacts, quality comparison claims, `v53_ready=0`, and release claims blocked.

v53s: Complete source review return intake is implemented and covered by `experiments/test_v53s_complete_source_review_return_intake.sh`. The runner consumes v53r, writes `review_return_required_field_rows.csv`, `review_return_row_template.csv`, `review_return_validation_rows.csv`, `review_return_artifact_gate_rows.csv`, `review_return_metric_rows.csv`, boundary, manifest, copied v53r evidence, and hash rows. In the default no-env path it verifies the returned-review schema, expects 7000 human review rows, 1000 adjudication rows, reviewer identity/conflict rows, and an acceptance summary, but accepts 0 returned review rows, records `review_return_ready=0`, `quality_comparison_claim_ready=0`, and `v53_ready=0`, while keeping human-reviewed audit, comparison, and release claims blocked.

v53t: Complete source audit readiness gate is implemented and covered by `experiments/test_v53t_complete_source_audit_readiness_gate.sh`. The runner consumes v52y/v53i/v53q/v53r/v53s, copies the relevant source summaries, writes complete-source audit requirement, claim, metric, boundary, manifest, and hash rows, and records `machine_complete_source_surface_ready=1`. It keeps accepted human review rows at 0/7000, accepted adjudication rows at 0/1000, `review_return_ready=0`, `quality_comparison_claim_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and release claims blocked.

v53u: Complete source review return operator bundle is implemented and covered by `experiments/test_v53u_complete_source_review_return_operator_bundle.sh`. The runner consumes v53r and v53s, copies the review packet and return schema evidence, emits 21 reviewer workload chunk rows, five expected return artifact rows, eight operator bundle files, four operator command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, and hash rows. The smoke verifies 7000 review answer rows, 7000 review queue rows, 21/21 ready reviewer workload chunks, chunk totals of 7000 human review rows, 1000 adjudication rows, 21 reviewer identity rows, and 210 conflict disclosure rows, `review_return_operator_bundle_handoff_ready=1`, `review_return_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and no fake review rows in the bundle, while keeping actual returned human/source review artifacts, comparison, and release claims blocked.

v53v: Complete source review return acceptance bridge is implemented and covered by `experiments/test_v53v_complete_source_review_return_acceptance_bridge.sh`. The runner consumes v53r/v53s/v53t/v53u and emits a 7000-row per-answer acceptance ledger over human review, adjudication, reviewer identity, conflict disclosure, and acceptance-summary readiness. The smoke verifies `machine_complete_source_surface_ready=1`, 7000 acceptance rows, zero accepted answer-review rows, zero accepted human-review rows, 1000 adjudication-required rows, zero accepted adjudication rows, 6000 non-p0 rows with adjudication already satisfied, `review_return_ready=0`, `quality_comparison_claim_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and no model/checkpoint payload-like files, while keeping actual returned human/source review artifacts, comparison, and release claims blocked.

v53w: Complete source review return chunk execution queue is implemented and covered by `experiments/test_v53w_complete_source_review_return_chunk_execution_queue.sh`. The runner consumes v53u/v53v, copies the reviewer workload and acceptance evidence, maps the 7000 human review tasks plus 1000 adjudication tasks into 21 dispatch-ready reviewer chunks, and emits 50 chunk return artifact rows plus five aggregate v53s artifact rows, command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, and hash rows. The smoke verifies 21 review chunks, 21 ready dispatch chunks, 8000 task rows, 7000 human-review tasks, 1000 adjudication tasks, seven human-review chunk artifacts, one adjudication chunk artifact, 21 identity artifacts, 21 conflict artifacts, five aggregate return artifacts, `chunk_dispatch_ready=1`, `review_return_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and no model/checkpoint payload-like files, while keeping actual chunk returns, aggregate review return, comparison, and release claims blocked.

v53x: Complete source review chunk return intake is implemented and covered by `experiments/test_v53x_complete_source_review_chunk_return_intake.sh`. The runner consumes v53w, validates supplied `chunks/<review_chunk_id>/...` CSV artifacts plus the five aggregate v53s artifacts when a return directory is provided, and emits chunk artifact status rows, per-chunk status rows, aggregate artifact status rows, command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, and hash rows. The default no-return smoke verifies 21 review chunks, 50 missing chunk return artifacts, five missing aggregate artifacts, `ready_review_chunk_return_rows=0`, `chunk_return_intake_ready=0`, `aggregate_review_return_ready=0`, `v53s_refresh_ready=0`, `review_return_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and no model/checkpoint payload-like files, while keeping real returned review evidence, comparison, and release claims blocked.

v53y: Complete source review return refresh gate is implemented and covered by `experiments/test_v53y_complete_source_review_return_refresh_gate.sh`. The runner optionally accepts `V53Y_REVIEW_RETURN_DIR`, refreshes v53s/v53t/v53v/v53w/v53x against that return directory, and emits refresh stage rows, command rows, requirement rows, metric rows, runtime gap rows, boundary, manifest, copied source evidence, and hash rows. The default no-return smoke verifies `machine_complete_source_surface_ready=1`, five refresh stages with one ready and four blocked, three command rows with only the shape verifier ready, 21 review chunks, 50 chunk return artifacts with 0 accepted, five aggregate artifacts with 0 accepted, `v53s_refresh_ready=0`, `expected_human_review_rows=7000`, `accepted_human_review_rows=0`, `expected_adjudication_rows=1000`, `accepted_adjudication_rows=0`, `answer_review_accepted_rows=0`, `v61_review_unblock_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and no model/checkpoint payload-like files, while keeping real returned review evidence, v61 generation review-unblock, comparison, and release claims blocked.

v54: RouteHint generation 1000-row contract scaffold is implemented and covered by `experiments/test_v54_routehint_generation_1000_contract.sh`. The runner assembles `results/v54_routehint_generation_1000_contract/contract_001/`, reruns the v48 multi-domain generator evidence and v54 mainline preview, writes `domain_generation_target_rows.csv`, `generation_invariant_rows.csv`, `artifact_contract_rows.csv`, copied v48/v54 source evidence, `V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md`, `v54_routehint_generation_1000_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v54_generation_1000_contract_ready=1`, target 1000 generation rows, seed evidence of 24 v48 rows and 4 v54 mainline rows, no attention blocks, no Transformer blocks, no raw prompt context appended, proposal-hint usage, abstention readiness, and release blocking, while keeping `v54_generation_1000_ready=0` and `missing_generation_rows=976` until the full generation main run is supplied.

v54b: RouteHint generation scale 1000 is implemented and covered by `experiments/test_v54b_routehint_generation_scale_1000.sh`. The runner assembles `results/v54b_routehint_generation_scale_1000/scale_001/`, reruns the v54 contract, writes 1000 deterministic local RouteHint generation rows across six domains, `query_rows.csv`, `route_memory_evidence_rows.csv`, `compact_route_hint_rows.csv`, `generator_input_rows.csv`, `grounded_generation_rows.csv`, `citation_rows.csv`, `abstain_rows.csv`, `unsupported_claim_rows.csv`, `resource_rows.csv`, `domain_generation_rows.csv`, `generation_metrics.json`, copied v54 contract evidence, `V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md`, `v54b_routehint_generation_scale_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v54b_routehint_generation_scale_ready=1`, `v54_generation_1000_ready=1`, 1000 generation rows, six domains, 900 answer rows, 100 abstain rows, 1000 RouteMemory evidence rows, 1000 compact RouteHint rows, 1000 citation/resource rows, zero attention/Transformer/raw-prompt-context rows, zero wrong-answer rows, and release blocking.

v55: Local scaling law main-run contract scaffold is implemented and covered by `experiments/test_v55_local_scaling_law_main_contract.sh`. The runner assembles `results/v55_local_scaling_law_main_contract/contract_001/`, reruns the v51 local scaling matrix, writes `scaling_axis_target_rows.csv`, `scaling_fit_contract_rows.csv`, `scaling_invariant_rows.csv`, copied v51 source curves, `V55_LOCAL_SCALING_LAW_BOUNDARY.md`, `v55_local_scaling_law_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v55_local_scaling_law_contract_ready=1`, target 6 axes and 100 curve rows, seed evidence of 5 axes and 27 curve rows, resource-envelope/claim-boundary readiness, no-oracle/no-extractor/RouteMemory-lineage invariants, and release/GPU claim blocking, while keeping `v55_local_scaling_law_ready=0`, `repo_count_axis_ready=0`, `missing_scaling_curve_rows=73`, `confidence_interval_ready=0`, and `failure_case_rows_ready=0` until the full scaling law main run is supplied.

v55b: Local scaling law main 120 is implemented and covered by `experiments/test_v55b_local_scaling_law_main_120.sh`. The runner assembles `results/v55b_local_scaling_law_main_120/main_001/`, reruns the v55 contract, writes local source/probe evidence, `scaling_curve_rows.csv`, `scaling_axis_rows.csv`, `confidence_interval_rows.csv`, `failure_case_rows.csv`, `resource_rows.csv`, `scaling_fit_rows.csv`, `resource_envelope.json`, copied v55 contract evidence, `V55B_LOCAL_SCALING_LAW_MAIN_BOUNDARY.md`, `v55b_local_scaling_law_main_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v55b_local_scaling_law_main_ready=1`, `v55_local_scaling_law_ready=1`, six axes, 360 curve rows, 60 repo-count rows, 120 confidence-interval rows, failure-case rows, 360 resource rows, six fit rows, local source/probe hash binding, no-oracle/no-extractor/RouteMemory-lineage invariants, no GPU/raw prompt context, and release/GPU/30B-150B claim blocking.

v56: RULER/LongBench expanded benchmark contract scaffold is implemented and covered by `experiments/test_v56_ruler_longbench_expanded_contract.sh`. The runner assembles `results/v56_ruler_longbench_expanded_contract/contract_001/`, reruns the v49 RULER 200/500 scale and v45 LongBench v2 small slice, writes `benchmark_family_target_rows.csv`, `expanded_benchmark_artifact_contract_rows.csv`, `benchmark_invariant_rows.csv`, copied v49/v45 source evidence, `V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md`, `v56_ruler_longbench_expanded_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v56_ruler_longbench_expanded_contract_ready=1`, official source/evaluator binding, no-oracle/no-raw-input-extractor invariants, RouteMemory lineage, seed evidence of 500 RULER rows and 6 LongBench rows, and release blocking, while keeping `v56_ruler_longbench_expanded_ready=0`, `ruler_missing_rows=500`, `longbench_missing_rows=494`, `llm_rag_baseline_rows_ready=0`, and `real_external_benchmark_verified=0` until the expanded benchmark main run is supplied.

v56b: RULER/LongBench expanded scale is implemented and covered by `experiments/test_v56b_ruler_longbench_expanded_scale.sh`. The runner assembles `results/v56b_ruler_longbench_expanded_scale/scale_001/`, reruns the v56 contract, writes `expanded_prediction_rows.csv`, `prediction_lineage_rows.csv`, `candidate_result_rows.csv`, `benchmark_resource_rows.csv`, `benchmark_family_rows.csv`, `expanded_benchmark_metrics.json`, copied v56 contract evidence, `V56B_RULER_LONGBENCH_EXPANDED_SCALE_BOUNDARY.md`, `v56b_ruler_longbench_expanded_scale_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v56b_ruler_longbench_expanded_scale_ready=1`, `v56_ruler_longbench_expanded_ready=1`, 1500 prediction rows, 1000 RULER rows, 500 LongBench rows, 1500 lineage/candidate/resource rows, official source/evaluator hash binding, no oracle, no raw-input extractor, and release blocking, while keeping `llm_rag_baseline_rows_ready=0` and `real_external_benchmark_verified=0`.

v1.0 Architecture Challenge is the planned next public target, not a completed experiment. The detailed roadmap is `docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`: v52 30B/70B/100B+ LLM+RAG baseline war, v53 public repo 10-30 repo / 1000-3000 query code/doc audit, v54 RouteHint non-attention generator 1000+ rows, v55 local scaling law main run, v56 RULER/LongBench expanded benchmark, v57 domain expert packs, v58 blind eval versus 30B-150B-class systems, v59 one-command LLM challenge demo, and v60 v1.0 Architecture Challenge Release. Until those gates pass, v0.3 remains a local architecture preview rather than a broad public performance claim.

v57: Domain expert packs contract scaffold is implemented and covered by `experiments/test_v57_domain_expert_packs_contract.sh`. The runner assembles `results/v57_domain_expert_packs_contract/contract_001/`, reruns v47 offline domain policy, v48 multi-domain generation, v52 baseline war, and v56 expanded benchmark seed evidence, writes `domain_pack_target_rows.csv`, `expert_review_contract_rows.csv`, `domain_policy_gate_rows.csv`, copied v47/v48/v52/v56 source evidence, `V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md`, `v57_domain_expert_packs_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v57_domain_expert_packs_contract_ready=1`, six domain packs, 1000 target eval rows, 50 seed eval rows, policy/generation/baseline/benchmark seed readiness, expert review artifact contracts, and release blocking, while keeping `v57_domain_expert_packs_ready=0`, `missing_eval_rows=950`, `human_expert_review_ready=0`, `blind_eval_ready=0`, `expert_replacement_claim=0`, and `real_release_package_ready=0` until human-reviewed domain pack rows are supplied.

v57b: Domain expert pack candidate scale is implemented and covered by `experiments/test_v57b_domain_expert_pack_candidate_1000.sh`. The runner assembles `results/v57b_domain_expert_pack_candidate_1000/candidate_001/`, reruns the v57 contract, writes `domain_pack_eval_rows.csv`, `domain_pack_source_span_rows.csv`, `domain_pack_candidate_summary_rows.csv`, `domain_pack_policy_rows.csv`, `domain_pack_rubric_rows.csv`, `domain_pack_failure_taxonomy_rows.csv`, `expert_review_template_rows.csv`, copied v57 contract evidence, `V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md`, `v57b_domain_expert_pack_candidate_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v57b_domain_expert_pack_candidate_ready=1`, six packs, 1000 candidate eval rows, 1000 source-span rows, 900 answer rows, 100 abstain rows, 1000 expert-review template rows, policy/rubric/failure-taxonomy coverage, source hash binding, and release blocking, while keeping `v57_domain_expert_packs_ready=0`, `human_expert_review_ready=0`, `blind_eval_ready=0`, `expert_replacement_claim=0`, and `real_release_package_ready=0` until human-reviewed expert evidence is supplied.

v58: Blind evaluation contract scaffold is implemented and covered by `experiments/test_v58_blind_eval_contract.sh`. The runner assembles `results/v58_blind_eval_contract/contract_001/`, reruns v57, writes `blind_system_mapping_rows.csv`, `blind_eval_query_contract_rows.csv`, `blind_evaluator_contract_rows.csv`, `blind_eval_gate_rows.csv`, copied v52/v57 source evidence, `V58_BLIND_EVAL_BOUNDARY.md`, `v58_blind_eval_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v58_blind_eval_contract_ready=1`, five blind systems over D-H, 500 target blind-eval rows, query-freeze/pre-output-selection/symmetric-evidence contracts, sealed identity requirements, and release blocking, while keeping `v58_ready=0`, `missing_blind_eval_rows=500`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, `human_blind_review_ready=0`, and `inter_rater_rows_ready=0` until real blind response and review rows are supplied.

v58b: Blind-eval candidate freeze is implemented and covered by `experiments/test_v58b_blind_eval_candidate_500.sh`. The runner assembles `results/v58b_blind_eval_candidate_500/candidate_001/`, reruns the v58 contract and v57b candidate pack, writes `blind_query_freeze_rows.csv`, `sealed_answer_key_rows.csv`, `blind_response_template_rows.csv`, `blind_reviewer_packet_template_rows.csv`, `blind_adjudication_template_rows.csv`, `blind_evidence_budget_rows.csv`, `sealed_identity_key_rows.csv`, `blind_domain_summary_rows.csv`, `blind_scoring_rubric_rows.csv`, copied v58/v57b source evidence, `V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md`, `v58b_blind_eval_candidate_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v58b_blind_eval_candidate_ready=1`, 500 frozen queries, exact six-domain distribution, 2500 D/E/F/G/H response templates, 2500 anonymous reviewer-packet templates, sealed answer/identity keys, same evidence budgets, source hash binding, and release blocking, while keeping `v58_ready=0`, `actual_blind_response_rows=0`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, `human_blind_review_ready=0`, `inter_rater_rows_ready=0`, and `real_release_package_ready=0`.

v58c: Blind response evidence intake is implemented and covered by `experiments/test_v58c_blind_response_evidence_intake.sh`. The runner assembles `results/v58c_blind_response_evidence_intake/intake_001/`, consumes the v58b frozen query/response template, writes `blind_response_required_field_rows.csv`, `blind_response_row_template.csv`, `run_identity_template_rows.csv`, `blind_response_validation_rows.csv`, `blind_response_intake_gate_rows.csv`, copied v58b source evidence, `V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md`, `v58c_blind_response_evidence_intake_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v58c_blind_response_evidence_intake_ready=1`, 2500 expected response rows, D/E/G/H required-response gates, optional F defer gate, no fake responses, and no-env blocking, while keeping `v58_ready=0`, `required_blind_response_ready=0`, `human_blind_review_ready=0`, `inter_rater_rows_ready=0`, and `real_release_package_ready=0`.

v59: One-command challenge demo contract scaffold is implemented and covered by `experiments/test_v59_one_command_challenge_demo_contract.sh`. The repository entrypoint `examples/v1_0_architecture_challenge_demo.sh` runs `experiments/run_v59_one_command_challenge_demo_contract.sh`, which assembles `results/v59_one_command_challenge_demo_contract/contract_001/`, reruns v53/v54/v55/v58, copies v52-v58 contract artifacts and summaries, writes `challenge_stage_contract_rows.csv`, `one_command_demo_rows.csv`, `one_command_demo_gate_rows.csv`, `challenge_demo.sh`, `README_RESULT.md`, `V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md`, `v59_one_command_challenge_demo_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v59_one_command_challenge_demo_contract_ready=1`, seven v52-v58 contract-ready stage rows, one-command entrypoint readiness, offline/no-external-model contract boundary, and release blocking, while keeping `v59_ready=0`, all v52-v58 full-ready rows at zero, and all real-row blockers explicit until the complete challenge demo evidence is supplied.

v59b: One-command candidate/intake-chain demo is implemented and covered by `experiments/test_v59b_one_command_candidate_demo.sh`. The repository entrypoint `examples/v1_0_architecture_challenge_candidate_demo.sh` runs `experiments/run_v59b_one_command_candidate_demo.sh`, which assembles `results/v59b_one_command_candidate_demo/candidate_001/`, replays or reuses v52b-v58c candidate/intake artifacts, writes `candidate_stage_replay_rows.csv`, `candidate_one_command_rows.csv`, `candidate_demo_gate_rows.csv`, `candidate_demo.sh`, `README_RESULT.md`, `V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md`, `v59b_one_command_candidate_demo_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v59b_one_command_candidate_demo_ready=1`, 12 candidate stage rows, one-command candidate entrypoint readiness, copied candidate artifacts, hash binding, and release blocking, while keeping `v59_ready=0`, real 30B/70B rows, optional 100B+ row/final deferral, complete-source audit, human domain review, human blind review, and release evidence blocked.

v59c: One-command measured-registry demo is implemented and covered by `experiments/test_v59c_one_command_measured_registry_demo.sh`. The repository entrypoint `examples/v1_0_architecture_challenge_measured_registry_demo.sh` runs `experiments/run_v59c_one_command_measured_registry_demo.sh`, which assembles `results/v59c_one_command_measured_registry_demo/measured_registry_001/`, replays or reuses v52j plus v53e-v58c artifacts, writes `measured_registry_stage_replay_rows.csv`, `measured_registry_one_command_rows.csv`, `measured_registry_demo_gate_rows.csv`, `measured_registry_demo.sh`, `README_RESULT.md`, `V59C_ONE_COMMAND_MEASURED_REGISTRY_BOUNDARY.md`, `v59c_one_command_measured_registry_demo_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v59c_one_command_measured_registry_demo_ready=1`, nine stage rows, v52j measured-registry absorption, A/B/G/H over the shared 1000-query v53e source manifest, 4000 answer/citation/abstain/wrong-answer/resource rows, 2000 RouteHint rows, copied hash-bound measured artifacts, and release blocking, while keeping `v59_ready=0`, C/D/E evidence, complete-source audit, human domain review, human blind review, full challenge demo, and release evidence blocked.

v60: Architecture Challenge release-audit contract scaffold is implemented and covered by `experiments/test_v60_architecture_challenge_release_contract.sh`. The runner assembles `results/v60_architecture_challenge_release_contract/contract_001/`, reruns v59, copies the v59 one-command bundle, writes `release_requirement_rows.csv`, `allowed_claim_rows.csv`, `forbidden_claim_rows.csv`, `release_decision_rows.csv`, `V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md`, `v60_architecture_challenge_release_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v60_release_contract_ready=1`, ten blocked release requirements, two limited allowed claims, eight forbidden claims, v59 contract input readiness, and release blocking, while keeping `v60_ready=0`, `real_release_package_ready=0`, and all v1.0 comparison/release claims blocked until real measured rows and human/release review evidence are supplied.

v60b: Release preflight candidate audit is implemented and covered by `experiments/test_v60b_release_preflight_candidate_audit.sh`. The runner assembles `results/v60b_release_preflight_candidate_audit/preflight_001/`, consumes the v59b one-command candidate replay, writes `release_preflight_requirement_rows.csv`, `release_preflight_claim_rows.csv`, `stage_release_audit_rows.csv`, `release_preflight_decision_rows.csv`, copied v59b source evidence, `V60B_RELEASE_PREFLIGHT_CANDIDATE_AUDIT_BOUNDARY.md`, `v60b_release_preflight_candidate_audit_manifest.json`, and `sha256_manifest.csv`. The smoke verifies `v60b_release_preflight_candidate_audit_ready=1`, 11 release-preflight requirements, three candidate-only ready surfaces, eight blocked release requirements, limited candidate-chain wording, forbidden release/comparison/superiority/expert/production claims, and hash binding, while keeping `v60_ready=0`, real 30B/70B rows, complete-source audit, human domain review, human blind review, human release review, and release package blocked.

v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at: external benchmark adapter/evidence
schemas pass, a supplied evidence CSV can be imported and compared against
baselines, while placeholder evidence is blocked from counting as real
benchmark evidence, local artifact hashes and authenticity/evaluator contracts
plus execution/evaluator-output artifacts can be verified, local/fixture
attestations and final-review artifacts remain diagnostic, and publishable
comparison is deferred until real independent verification exists; local
final-review artifacts cannot become real benchmark evidence by declaration
flag rewrite alone, HTTPS hash-attested review artifacts still cannot publish
if lower-chain benchmark artifacts are local fixtures, and the lower-chain
evidence/execution/attestation/identity gates can now exercise HTTPS
hash-attested non-local artifact mechanics without making a final-review or
publish claim; a fully remote-style lower-chain plus final-review package now
reaches `source_import_live_registry_network_proof_ready=1` when supplied with
the v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa fixture chain plus the v08-ab local codebase-mini package,
v08-ac single-family content/result bridge, v08-ad all-family bridge mechanics,
v08-ae independent reproduction/review mechanics, v08-af official release
evidence mechanics, v08-ag live release verification mechanics, v08-ah
canonical online confirmation mechanics, v08-ai publication/result review
mechanics, v08-aj live publication/result ingestion mechanics, and v08-ak
authority/promotion evidence mechanics, v08-al local codebase run/evaluator
trace mechanics, v08-am supplied independent all-family run/evaluator evidence
mechanics, v08-an supplied live replay/final-review mechanics, v08-ao
supplied public non-fixture/direct-run verification mechanics, v08-ap
supplied runner-owned live execution/audit mechanics, v08-aq supplied
independent live rerun confirmation mechanics, v08-ar supplied real
nonfixture run package intake mechanics, v08-as supplied live package
artifact fetch/authority mechanics, and v08-at supplied official result
reconciliation mechanics, but it
still blocks at `real_external_benchmark_verified=0` because supplied publication
and release packages remain mechanics-only or comparison remains unpublished. v08-m now validates the source-import contract around that
blocker: remote-style source import rows can match source/result/execution
URIs and hashes, carry non-local import manifest/fetch-log/reviewer artifacts,
and reach `source_import_contract_ready=1`, while still keeping
`source_import_verified=0`. v08-n now adds the runner-owned source-import
verifier/fetch-evidence contract: replay verifier rows can bind back to every
v08-m source-import row, import manifest, fetch log, reviewer identity, and
benchmark artifact URI with verifier binary/stdout/stderr hash evidence, but
offline replay still blocks at
`external-benchmark-source-import-live-verifier-missing`.
v08-o then separates replay from live verifier evidence: supplied live-style
verifier rows can raise `source_import_live_verifier_ready=1`, but
`source_import_verified=0` remains blocked with
`external-benchmark-source-import-independent-live-review-missing`.
v08-p adds the independent live-review layer above v08-o. Supplied non-local,
hash-attested live-review rows can bind to verifier run IDs, verifier artifact
hashes, and import manifest/fetch-log hashes, reaching
`source_import_independent_live_review_ready=1`, but
`source_import_verified=0` remains blocked with
`external-benchmark-source-import-authoritative-live-review-missing`.
v08-q adds the authoritative source-import review layer above v08-p. Supplied
non-local, hash-attested authority rows can bind source-import IDs, verifier
run IDs, live-review IDs, live-review report hashes, reviewer identity,
reviewer registry, conflict disclosure, and verifier artifact hashes, reaching
`source_import_authoritative_review_ready=1`, but `source_import_verified=0`
and `real_external_benchmark_verified=0` remain blocked with
`external-benchmark-source-import-real-public-registry-missing` until real
public registry/source-import authority evidence exists.
v08-r adds the public-registry/source-import authority layer above v08-q.
Supplied non-local, hash-attested registry rows can bind source-import IDs,
verifier run IDs, live-review IDs, authority-review IDs, authority hashes,
verifier hashes, registry entry artifacts, operator identity, and provenance,
reaching `source_import_public_registry_ready=1`, but
`source_import_verified=0` remains blocked with
`external-benchmark-source-import-live-registry-query-missing` until a
runner-owned live registry query/fetch path exists.
v08-s adds the live-registry-query layer above v08-r. Runner-owned replay rows
can satisfy query-runner mechanics while still blocking network evidence, and
supplied live-style query rows can bind registry response hashes back to the
public-registry rows and reach `source_import_live_registry_query_ready=1`, but
`source_import_verified=0` remains blocked with
`external-benchmark-source-import-live-registry-query-fixture-only`.
v08-t adds the live-registry fetch/cache layer above v08-s. Runner-owned replay
rows can bind live-query rows to local response-cache artifacts and verify
fetcher/cache hashes while still blocking network proof, and supplied
live-style fetch rows can reach `source_import_live_registry_fetch_ready=1`,
but `source_import_verified=0` remains blocked with
`external-benchmark-source-import-live-registry-fetch-fixture-only`.
v08-u adds the live-registry network-proof layer above v08-t. Runner-owned
replay proof rows bind fetch/cache rows to proof metadata, request/header/TLS/
DNS/nonce hashes, tool hashes, and cache/body hashes while remaining non-live;
supplied live-style proof rows can reach
`source_import_live_registry_network_proof_ready=1`, but
`source_import_verified=0` remains blocked with
`external-benchmark-source-import-live-registry-network-proof-fixture-only`.
v08-v adds the real source-import verification layer above v08-u. Supplied
verification rows can bind network-proof rows to verification reports,
verifier identities, proof transcripts, and verified cache hashes, reaching
`source_import_real_verification_review_ready=1`; placeholder domains such as
`example.invalid` still keep `source_import_verified=0` with
`external-benchmark-source-import-real-verification-placeholder-domain`.
v08-w adds the official authority/trust-root layer above v08-v. Supplied
authority rows can bind verification rows to authority artifacts, benchmark
source/license artifacts, verification-report hashes, authority domains, and
trust-root review flags, reaching
`source_import_official_authority_review_ready=1`; fixture authority rows still
keep `source_import_verified=0` with
`external-benchmark-source-import-official-authority-fixture-only`.
v08-x adds the official result-authority/leaderboard layer above final review.
Supplied result-authority rows can bind benchmark result rows to official
leaderboard artifacts, result records, metric/protocol artifacts, submitter
identity, final reviewed result URIs, provenance hashes, evaluator-output
hashes, run-log hashes, and metric values, reaching
`external_benchmark_result_authority_review_ready=1`; fixture result-authority
rows still keep `real_external_benchmark_verified=0` with
`external-benchmark-result-authority-fixture-only`.
v08-y adds the publication-package/reproducibility layer above result
authority. Supplied publication rows can bind official leaderboard/result rows
and comparison deltas/verdicts to publication package, report, comparison table,
reproducibility bundle, release license, conflict disclosure, and publication
review artifacts, reaching `external_benchmark_publication_review_ready=1`;
fixture publication rows still keep `real_external_benchmark_verified=0` with
`external-benchmark-publication-fixture-only`, and non-fixture publication rows
still block with `external-benchmark-publication-comparison-not-publishable`
until comparison publication is allowed.
v08-z adds the source-acquisition/intake layer for official benchmark sources.
Supplied acquisition rows can bind the four adapter families to official
source landing, dataset, benchmark-card, split-manifest, license, and
metric-spec URI/hash packages, reaching
`external_benchmark_source_acquisition_review_ready=1`; fixture acquisition
rows still keep `external_benchmark_source_acquisition_ready=0` with
`external-benchmark-source-acquisition-fixture-only`, and non-fixture
acquisition packages can reach `external_benchmark_source_acquisition_ready=1`
while still keeping `real_external_benchmark_verified=0` until source
import/content/result/review/publication evidence is connected.
v08-aa adds the source-acquisition content-cache verifier above v08-z. Supplied
content rows must bind back to acquisition IDs, match all official source
landing/dataset/card/split/license/metric URIs and sha256 hashes, and verify
24 local cache files across the four benchmark families. Matching cache content
can reach `external_benchmark_source_acquisition_content_ready=1`, but still
keeps `real_external_benchmark_verified=0` until imported benchmark content,
result authority, review, and publication evidence are connected.
v08-ab adds codebase-mini benchmark instrumentation above h11-c. It generates a
local `codebase-retrieval` package from real repository source files, writes
source/dataset/split/license/metric manifests plus BM25, symbolic upper-bound,
RouteMemory student, result, summary, and sha256 artifacts, and requires the
h11-c RouteMemory store hash chain. The smoke can reach
`codebase_mini_source_ready=1`, `benchmark_result_artifact_verified=1`, and
`baseline_comparison_ready=1` with `span_exact=1.000000`,
`chunk_exact=1.000000`, `missing_abstain=1.000000`, and
`wrong_answer_rate=0.000000`, but keeps `real_external_benchmark_verified=0`
because the package is local instrumentation, not an independent external
benchmark review/publication chain. v08-ac then binds that codebase-mini result
package to v08-aa source content as a single-family bridge with
`codebase_content_result_bridge_ready=1`, while
`external_benchmark_result_bridge_ready=0` remains blocked until the other
benchmark families have non-local result bridges.
v08-ad then requires all four benchmark families to have supplied non-local
result bridge rows bound to the v08-aa source-content acquisition IDs. It
attests 28 HTTPS result/baseline/dataset/run/evaluator/result-authority/
publication URI/hash fields, passes independent bridge-review mechanics, and
can reach `family_result_bridge_review_ready=1` plus
`external_benchmark_result_bridge_ready=1`, but still keeps
`real_external_benchmark_verified=0` until independent reproduction, real
review, and publication evidence replace supplied mechanics.
v08-ae then requires supplied non-local independent reproduction/review rows
for all four benchmark families above v08-ad. It verifies result artifact
binding, bridge-summary hashes, independent runner/reviewer/conflict flags,
and 28 HTTPS reproduction/report/run-log/reviewer/conflict/environment/metric
URI/hash fields, reaching `independent_reproduction_review_ready=1` while
still keeping `real_external_benchmark_verified=0`. v08-af then binds supplied
official release rows back to those reproduction IDs and can reach
`official_release_evidence_ready=1`, while real benchmark verification remains
blocked until live release verification and externally verifiable benchmark
publication evidence exist. v08-ag then binds supplied live-verification rows
back to v08-af release IDs, reproduction IDs, and official release/archive/
dataset/authority URI+hash pairs, reaching
`official_release_live_verification_ready=1` while still keeping
`real_external_benchmark_verified=0` until canonical online confirmation
replaces supplied mechanics. v08-ah then binds supplied canonical confirmation
rows back to v08-ag live reports, network observations, verifier identities,
release IDs, and reproduction IDs, reaching
`canonical_online_confirmation_ready=1` while still keeping
`real_external_benchmark_verified=0` until non-fixture publication/result
review replaces supplied mechanics. v08-ai then binds supplied publication/
result review rows back to v08-ah canonical confirmation reports and
content-digest manifests, reaching `publication_result_review_ready=1` while
still keeping `real_external_benchmark_verified=0` until live ingestion
evidence replaces supplied review mechanics. v08-aj then binds supplied live
publication/result ingestion rows back to the v08-ai review and record
URI/hash pairs, reaching `live_publication_result_ingestion_ready=1` while
still keeping `real_external_benchmark_verified=0` until authority/promotion
evidence replaces supplied ingestion mechanics. v08-ak then binds supplied
authority/promotion rows back to v08-aj live records and content digests,
reaching `authority_promotion_evidence_ready=1` while still keeping
`real_external_benchmark_verified=0` until actual independently observed
benchmark run/evaluator evidence replaces supplied authority mechanics.
v08-al then recomputes the local codebase-mini dataset/result join into a
runner-owned evaluator trace, reaching `codebase_run_evaluator_trace_ready=1`
while keeping `external_benchmark_run_evaluator_trace_ready=0` and
`real_external_benchmark_verified=0` until independent all-family run/evaluator
evidence replaces the local codebase trace.
v08-am then consumes supplied independent all-family run/evaluator evidence rows
for RULER, LongBench, codebase-retrieval, and real-document-qa. The rows must
provide non-placeholder HTTPS trace/run/evaluator/metric/query/observer/authority
artifacts, sha256 hashes, query volume, quality thresholds, proof bindings,
independent evaluator declarations, and route/jump zero. The supplied mechanics
can raise `external_benchmark_independent_run_evaluator_evidence_ready=1`, but
keeps `real_external_benchmark_verified=0` until live replay/final review
replaces supplied evidence.
v08-an then consumes supplied live replay/final-review rows for the same four
families. The rows must bind v08-am evidence to replay/final-review artifact
URI/hash pairs, replay query volume, metric thresholds, live replay
declarations, final-review declarations, fixture declarations, and route/jump
zero. The supplied mechanics can raise
`external_benchmark_live_replay_final_review_ready=1`, but still keeps
`real_external_benchmark_verified=0` until public non-fixture verification or
direct runner-owned external benchmark runs replace the supplied package.
v08-ao then consumes supplied public non-fixture/direct-run verification rows
for the same four families. The rows must bind v08-an final-review evidence to
40 non-placeholder HTTPS public/direct-run artifact URIs, 40 sha256 hashes,
query volume, metric thresholds, public registry/non-fixture declarations,
direct runner-owned run/dataset/evaluator/network declarations, third-party
reviewer declarations, fixture declarations, and route/jump zero. The supplied
mechanics can raise
`external_benchmark_public_nonfixture_verification_ready=1`, but still keeps
`real_external_benchmark_verified=0` until runner-owned live execution/audit
proves the public direct-run receipts instead of merely supplying them.
v08-ap then consumes supplied runner-owned live execution/audit rows for the
same four families. The rows must bind v08-ao public verification evidence to
52 non-placeholder HTTPS live execution/audit artifact URIs, 52 sha256 hashes,
query volume, metric thresholds, runner-owned execution declarations, live
network/dataset fetch declarations, runner-invoked evaluator declarations,
replay-disabled declarations, audit log and third-party audit declarations,
fixture declarations, and route/jump zero. The supplied mechanics can raise
`external_benchmark_runner_owned_live_execution_audit_ready=1`, but still keeps
`real_external_benchmark_verified=0` until independent live rerun confirmation
proves the runner-owned audit receipts.
v08-aq then consumes supplied independent live rerun confirmation rows for the
same four families. The rows must bind v08-ap runner-owned audit evidence to
60 non-placeholder HTTPS rerun-confirmation artifact URIs, 60 sha256 hashes,
rerun query volume, metric thresholds, metric-delta bounds, independent runner
and environment declarations, live network/dataset refetch/evaluator rerun
declarations, audit receipt reconciliation, metric recomputation, third-party
confirmation declarations, fixture declarations, and route/jump zero. The
supplied mechanics can raise
`external_benchmark_independent_live_rerun_confirmation_ready=1`, but still
keeps `real_external_benchmark_verified=0` until a real non-fixture benchmark
run package replaces the supplied confirmation mechanics.
v08-ar then consumes supplied real nonfixture run package rows for the same
four families. The rows must bind v08-aq confirmation evidence to
non-placeholder HTTPS run-package manifests, raw query sets, raw prediction
outputs, evaluator container digests/configs, metric reports, submission
receipts, public archives, official leaderboard entries, license/PII/
third-party reproducibility reviews, package signatures, timestamp-authority
records, and package-registry entries, each with sha256 attestation. The
supplied mechanics can raise
`external_benchmark_real_nonfixture_run_package_intake_ready=1`, but still
keeps `real_external_benchmark_verified=0` until live package artifact fetch
and authority verification replace supplied package mechanics.
v08-as then consumes supplied live package artifact fetch/authority rows for
the same four families and all 15 package artifact types. The rows must bind
v08-ar package intake to fetched artifact, fetch receipt, and authority record
URI/hash pairs; require HTTP-200 checks, content-digest matches, runner-owned
live fetch declarations, network/TLS/DNS/HTTP proof declarations, authority
registry and official source authority declarations, fixture declarations, and
route/jump zero. The supplied mechanics can raise
`external_benchmark_live_package_artifact_fetch_authority_ready=1`, but still
keeps `real_external_benchmark_verified=0` until official result
reconciliation replaces supplied fetch/authority mechanics.
v08-at then consumes supplied official result reconciliation rows for the same
four families. The rows must bind v08-as fetched official leaderboard, metric
report, submission receipt, evaluator config, raw prediction output, and
package-registry artifacts by exact URI/hash identity; require package identity
matches, metric-delta tolerance checks, query-count matches, evaluator/digest/
official-source/leaderboard/runner declarations, fixture declarations, and
route/jump zero. The supplied mechanics can raise
`external_benchmark_official_result_reconciliation_ready=1`, but still keeps
`real_external_benchmark_verified=0`. The active transition is now v13
real-run binding: a nonfixture runner must populate raw traces, evaluator
outputs, source/result artifacts, NLG transcript/result, workload/resource
rows, scorer/teacher evidence, and v12 claim-matrix input from one execution
before any stronger comparison or release claim.
h11-a: PC RouteLM / NLG prototype contract passes; supplied component evidence
can reach diagnostic prototype readiness, while real prototype/publish stays
blocked by promotion, teacher-source, benchmark, GPU speed, and artifact gates.
h11-b: PC RouteLM artifact verifier passes; local generator/route-memory/scorer/decoder/NLG/benchmark/license/provenance artifact chains can be hash-verified, while local fixtures still cannot become real prototype evidence.
h11-c: NVMe RouteMemory store artifact smoke passes; a deterministic store bundle can be generated, hash-verified, route-looked-up, and span-read while real PC RouteLM and external benchmark claims remain blocked.
h11-d: PC RouteLM diagnostic NLG smoke passes; generated transcript/result artifacts verify teacher-off inference, retrieved evidence use, grounding, span citation, span/chunk exactness, missing abstain, wrong-answer rate, latency/storage/memory metrics, and zero routing/jump activity while `real_pc_routelm_nlg_verified=0` remains blocked.
h9-f/h9-g/h9-h: quick GPU-backend boundary runs CPU numeric parity, verifies timing/environment artifact contracts, binds h9-g plus h11-d into a CPU/HIP/NVMe workload-speed evidence gate, and keeps speedup claims deferred unless real HIP/NVMe workload measurements exist; HIP parity remains optional.
v12: paper/release claim audit passes as diagnostic artifact packaging only; publishable release, Transformer replacement, frontier PC LLM, long-context solved, learned sparse routing, and GPU acceleration claims remain blocked.
```

Latest completed verification:

```bash
bash -n experiments/*.sh
git diff --check
bash experiments/test_v10_teacher_external_label_source_verifier.sh
bash experiments/test_v10_teacher_external_label_source_import.sh
bash experiments/test_v10_teacher_external_label_import.sh
bash experiments/test_v10_learned_chunk_quality_scorer.sh
bash experiments/test_v10_source_verified_learned_chunk_scorer_gate.sh
bash experiments/test_v10_remote_teacher_source_acquisition_gate.sh
bash experiments/test_v10_remote_teacher_source_content_verifier.sh
bash experiments/test_v10_remote_teacher_source_live_fetch_attestation.sh
bash experiments/test_v10_remote_teacher_source_runtime_fetcher.sh
bash experiments/test_v10_remote_teacher_source_live_network_import_gate.sh
bash experiments/test_v10_real_teacher_source_import_review.sh
bash experiments/test_v10_chunk_credit_distillation_gate.sh
bash experiments/test_v08_external_benchmark_final_review_gate.sh
bash experiments/test_v08_external_benchmark_final_review_import.sh
bash experiments/test_v08_external_benchmark_final_review_real_source_guard.sh
bash experiments/test_v08_external_benchmark_final_review_remote_review_guard.sh
bash experiments/test_v08_external_benchmark_final_review_remote_full_guard.sh
bash experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh
bash experiments/test_v08_external_benchmark_source_import_gate.sh
bash experiments/test_v08_external_benchmark_source_import_remote_contract.sh
bash experiments/test_v08_external_benchmark_source_import_verifier_gate.sh
bash experiments/test_v08_external_benchmark_source_import_live_verifier_gate.sh
bash experiments/test_v08_external_benchmark_source_import_live_review_gate.sh
bash experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh
bash experiments/test_v08_external_benchmark_source_import_public_registry_gate.sh
bash experiments/test_v08_external_benchmark_source_import_live_registry_query_gate.sh
bash experiments/test_v08_external_benchmark_source_import_live_registry_fetcher.sh
bash experiments/test_v08_external_benchmark_source_import_live_registry_network_proof.sh
bash experiments/test_v08_external_benchmark_source_import_real_verification_gate.sh
bash experiments/test_v08_external_benchmark_source_import_official_authority_gate.sh
bash experiments/test_v08_external_benchmark_result_authority_gate.sh
bash experiments/test_v08_external_benchmark_publication_gate.sh
bash experiments/test_v08_external_benchmark_source_acquisition_gate.sh
bash experiments/test_v08_external_benchmark_source_acquisition_content_verifier.sh
bash experiments/test_v08_external_benchmark_codebase_mini.sh
bash experiments/test_v08_external_benchmark_content_result_bridge.sh
bash experiments/test_v08_external_benchmark_family_result_bridge.sh
bash experiments/test_v08_external_benchmark_independent_reproduction_review.sh
bash experiments/test_v08_external_benchmark_official_release_evidence.sh
bash experiments/test_v08_external_benchmark_live_release_verification.sh
bash experiments/test_v08_external_benchmark_canonical_online_confirmation.sh
bash experiments/test_v08_external_benchmark_publication_result_review.sh
bash experiments/test_v08_external_benchmark_live_publication_result_ingestion.sh
bash experiments/test_v08_external_benchmark_authority_promotion_evidence.sh
bash experiments/test_v08_external_benchmark_run_evaluator_trace.sh
bash experiments/test_v08_external_benchmark_independent_run_evaluator_evidence.sh
bash experiments/test_v08_external_benchmark_live_replay_final_review.sh
bash experiments/test_v08_external_benchmark_public_nonfixture_verification.sh
bash experiments/test_v08_external_benchmark_runner_owned_live_execution_audit.sh
bash experiments/test_v08_external_benchmark_independent_live_rerun_confirmation.sh
bash experiments/test_v08_external_benchmark_real_nonfixture_run_package.sh
bash experiments/test_v08_external_benchmark_live_package_artifact_fetch_authority.sh
bash experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh
bash experiments/test_v11_pc_routelm_prototype_artifact_import.sh
bash experiments/test_v11_pc_routelm_prototype_readiness.sh
bash experiments/test_v11_pc_routelm_prototype_import.sh
bash experiments/test_v11_nvme_route_memory_store.sh
bash experiments/test_v11_nvme_route_memory_artifact.sh
bash experiments/test_v11_pc_routelm_nlg_smoke.sh
bash experiments/test_v09_gpu_backend_real_workload_speed_gate.sh
bash experiments/test_v07_route_memory_promotion_review_gate.sh
bash experiments/test_v12_paper_release_claim_audit.sh
bash experiments/test_v07_goal_route_memory_closure.sh
bash experiments/test_v09_gpu_backend_closure.sh
```

Latest completed status:

- h10-s is the latest route-memory learned-scorer evaluation boundary. The
  lower teacher-source chain lets an HTTPS
  remote acquisition package pass URI/hash/acquisition/review contract checks,
  verifies supplied local download/cache content against that hash manifest,
  then verifies artifact-level fetch-attestation rows with HTTPS attestation
  URIs and independent attestor flags, and finally lets a runner-owned offline
  replay manifest bind runtime fetch rows back to those attestations. h10-q
  rejects that replay as non-network evidence and accepts only provided
  live-network runtime rows up to `remote_teacher_source_live_network_import_ready=1`.
  h10-r then binds that live import to import/review/registry evidence and can
  reach `real_teacher_source_import_review_ready=1`, but real teacher-source
  claims remain blocked until official authority sets
  `real_teacher_source_verified=1`. h10-s sits above that boundary: supplied
  source-linked eval rows can pass student-only chunk/span metric checks, but
  `source_verified_learned_chunk_scorer_eval_ready=0` remains until h10-l and
  h10-r have official real teacher-source authority.
- h10-l remains the route-memory learned-scorer/source binding gate. It keeps
  local learned scorer readiness separate from source-verified learned scorer
  readiness, so distillation cannot pass on a local scorer plus unrelated real
  source evidence, relabeled local feature rows, or mismatched external-label
  rows.
- h7 route-memory closure includes h10-s and still blocks default promotion.
- v12 is the current paper/release claim audit boundary. The diagnostic
  package can be assembled from h7-c, h10-r/h10-s, v08-ab, h11-c/h11-d, and
  h9-h, but publishable release readiness remains blocked until every real
  evidence input passes.
- v08-at is the current external benchmark official result reconciliation
  boundary above the v08-as live package artifact fetch/authority boundary, the
  v08-ar real nonfixture run package intake boundary, the
  v08-aq independent live rerun confirmation boundary, the
  v08-ap runner-owned live execution/audit boundary, the
  v08-ao public non-fixture/direct-run verification boundary,
  v08-an live replay/final-review boundary, v08-am independent all-family
  run/evaluator evidence, v08-ad all-family bridge, v08-ac single-family
  bridge, and v08-ab codebase-mini instrumentation layer; v08-l remains the
  lower final-review evidence layer. Final-review, supplied public/direct-run
  verification, supplied live execution/audit, and supplied independent rerun
  confirmation plus supplied real nonfixture run package intake, live
  package artifact fetch/authority, and official result reconciliation
  mechanics pass,
  but fixture/local review and supplied direct-run/audit/rerun/package receipts remain
  non-publishable with
  `real_external_benchmark_verified=0`. The real-source guard now also blocks
  local `file://` final-review artifacts even when real/non-fixture declaration
  flags are rewritten to pass, and the remote-review guard blocks HTTPS
  hash-attested final-review rows if evidence/execution/attestation/identity
  artifacts underneath are still local fixtures. The lower-chain remote-artifact
  path now verifies HTTPS hash-attested source/result, evaluator output/run-log,
  attestation, attestor identity, registry, and conflict-disclosure artifacts
  through v08-k while still stopping at `external-benchmark-final-review-missing`.
  The remote-full source-import guard combines non-local lower-chain artifacts
  with non-local final-review artifacts and now carries the source-import,
  publication, acquisition, content-cache, codebase-mini, content/result bridge,
  family result bridge, independent reproduction, release, confirmation,
  ingestion, authority, run/evaluator, replay/review, public verification,
  audit, independent rerun, package-intake, live-fetch/authority, and
  official-result-reconciliation blockers forward through v08-at: a fully supplied
  contract/verifier/live-review/authority-review/public-registry/live-query/
  fetch/network-proof/official-authority/result-authority/publication/acquisition/content/codebase-mini/bridge/family-bridge/reproduction
  fixture can reach publication, acquisition, content-cache, codebase-mini, and
  supplied all-family replay/final-review plus public non-fixture/direct-run
  verification, runner-owned live execution/audit, independent live rerun
  confirmation, real nonfixture run package intake, live package artifact
  fetch/authority readiness, and official result reconciliation readiness, but still
  blocks publication at
  `real_external_benchmark_verified=0`.
- v13-a is the current real-run binder boundary. It writes or verifies a single
  run directory with store, NLG, benchmark trace, speed, evidence, run manifest,
  and `sha256sums.txt`, then feeds the evidence packet shape toward the later
  nonfixture runner and v12 real-input adapter. This is the pivot from supplied
  rows toward `real run -> raw trace -> evaluator -> evidence rows -> claim
  matrix input`, not another v08 layer.
- v13-b is the current RouteLM mmap reader boundary. It consumes that run
  directory, independently mmap-reads `store/chunk_pages.bin`, and verifies the
  reader ABI across route index, page table, chunk offsets, and missing-abstain
  rows before any nonfixture runner is allowed to treat the store as readable
  RouteMemory evidence.
- v13-c is the current evidence packet ABI boundary. It converts the bound run
  manifest, store/mmap reader evidence, NLG transcript/result, workload row,
  benchmark trace/evaluator outputs, h10-s scorer evidence, and v12 input into
  `evidence_packet.csv` plus `claim_matrix_input.csv`, verifies packet hashes
  and claim-source references, and keeps learned-ranking plus all real evidence
  claims blocked.
- v13-d is the NLG transcript binding boundary. It parses
  `nlg/transcript.jsonl` and `nlg/result_summary.json`, replays each transcript
  row against the route index and mmap-read chunk span bytes, writes
  `transcript_binding.csv`, and blocks hash-clean wrong grounding while keeping
  real PC RouteLM NLG blocked until a nonfixture generator run exists.
- v13-e is the public codebase RouteQA binding boundary. It binds the
  v13 benchmark trace to the local codebase-mini package, recomputes the
  RouteQA evaluator metrics, writes `routeqa_rows.csv`, and keeps real external
  benchmark claims blocked until independent non-local benchmark evidence
  replaces the local package.
- v13-f is the resource envelope binding boundary. It binds
  `speed/workload.csv` to the same v13 run, verifies workload artifact hashes
  and metric rows, writes `resource_rows.csv`, and keeps GPU speedup blocked
  until real HIP/NVMe/nonfixture product or benchmark traces replace the
  fixture envelope.
- v13-g is the real evidence promotion boundary. It audits the same
  bound run across v13-c/v13-d/v13-e/v13-f plus h10-s, h11-d, h9-h, and v08
  evidence, emits `promotion_rows.csv`, and keeps release promotion blocked
  until external benchmark, learned chunk ranking, real NLG, GPU speedup, and
  nonfixture-run evidence are all real and source-bound together.
- v13-h is the real evidence intake boundary. It consumes v13-g and an
  optional same-run intake CSV for external benchmark, learned chunk ranking,
  GPU speedup, and real NLG evidence, emits `intake_rows.csv`, verifies cache
  hashes and HTTPS authority-chain shape, and keeps real release blocked until
  the intake is live-network verified and rebound through the v13 run.
- v13-i is the real evidence live-network boundary. It consumes v13-h
  intake evidence plus same-run source/review/authority network receipts, emits
  `live_network_rows.csv`, verifies receipt hashes, HTTPS final URIs, HTTP
  status rows, live-network declarations, and route/jump zero, and keeps real
  release blocked until receipts are produced by runner-owned runtime live
  fetches and rebound through the v13 run.
- v13-j is the current real evidence rebind boundary. It consumes v13-i
  receipt evidence plus same-run replacement artifacts, emits `rebind_rows.csv`,
  verifies receipt-hash replay, rebuilt artifact hashes, claim-matrix hashes,
  regeneration flags, and route/jump zero, and keeps real release blocked until
  runtime live fetch evidence and regenerated promotion rows exist.
- v13-k is the current runtime fetch provenance boundary. It consumes v13-j and
  the v13-i live receipt packet, emits `runtime_fetch_provenance_rows.csv`,
  verifies receipt JSON scope, weakness/kind binding, HTTPS original/final
  URIs, HTTP status, method, headers, empty error, ordered UTC timestamps,
  receipt hashes, and route/jump zero, and keeps real release blocked until the
  same receipts are produced by runner-owned `runtime-live-fetch`.
- v13-l is the current source seed boundary. It emits `source_seed_rows.csv`,
  binds current RULER/LongBench public source seeds for the external benchmark
  blocker, classifies learned chunk ranking, GPU speedup, and real NLG as
  `project-source-only`, and keeps real release blocked until all four rows
  have official/independent claim evidence plus runtime live fetch receipts.
- v13-m is the current source seed live-fetch boundary. It consumes v13-l
  `source_seed_rows.csv` plus optional `runtime_receipts/`, emits
  `source_seed_live_fetch_rows.csv`, verifies receipt provenance shape and
  packet hashes, and still blocks real release unless all four weaknesses have
  complete source/review/authority receipts and real claim evidence.
- v13-n is the current external benchmark official source acquisition boundary.
  It consumes v13-m/v13-l seed packets, emits
  `official_source_acquisition_rows.csv`, optionally writes runner-owned
  `git ls-remote HEAD` and HTTP HEAD receipts for RULER, LongBench, and the
  RULER arXiv authority, and still blocks benchmark-result readiness and release
  until real query/result/evaluator evidence exists.
- v14-a is the current runner execution boundary, not another receipt gate.
  `tools/routelm_benchmark_run` produces a bound run directory with
  `source/`, `dataset/`, `store/`, `predictions/`, `evaluator/`, `metrics/`,
  `routeqa/`, `benchmark/`, `resource/`, `evidence/`, and `promotion/`
  artifacts, including copied v13 source-chain rows, `route_memory_store.bin`,
  `chunk_offsets`, `source_snapshot_rows.csv`, and `benchmark_rows.csv`. The
  smoke reaches `runner_owned_query_result_evaluator_ready=1` for both built-in
  and supplied query files, and the live snapshot test runs RouteQA rows against
  the checked-out v13-n RULER HEAD with `repo_source=runner-owned-source-snapshot`.
  The RULER-compatible synthetic smoke writes `niah_dataset.jsonl`,
  `niah_single_1.jsonl`, `ruler_evaluator_rows.csv`, and
  `official_evaluator_status.json`; current official evaluator execution runs
  with recorded run-local shims for missing `nltk` and NeMo manifest utilities,
  producing `summary-niah_single_1.csv` and `submission.csv`. The same smoke
  now invokes official RULER `scripts/data/prepare.py` with run-local
  `nltk`/`wonderwords`/`tiktoken`/NeMo shims and a space-free `/tmp` symlink
  workspace for its internal shell command, writes
  validation JSONL files for `niah_single_1`, `niah_multikey_2`, and
  `niah_multikey_3`, predicts those rows through task-specific
  `official_generator_eval/*.jsonl` files with `oracle_prediction_used=0`,
  evaluates them through `official_generator_eval/summary.csv` at average score
  77.78, and
  records `official_generator_benchmark_rows.csv`,
  `official_generator_metrics.json`, and
  `official_generator_prediction_provenance.csv` with dataset/prediction/
  evaluator/metrics/provenance binding fields, then normalizes those task rows
  into run-level `benchmark/external_benchmark_rows.csv`. The live LongBench
  path also fetches 12 canonical `zai-org/LongBench-v2` dataset-server rows,
  predicts them with a non-oracle lexical-overlap baseline, and runs the same
  official `result.py` aggregator over both the runner-owned schema smoke and
  the official sample file. The summary can now report
  `external_benchmark_rows=5`,
  `external_benchmark_ready_rows=5`,
  `external_benchmark_dataset_rows=27`,
  `external_benchmark_average_score=66.67`,
  `external_benchmark_metrics_ready=1`,
  `external_benchmark_manifest_ready=1`, and
  `runner_owned_external_benchmark_result_ready=1`, `prediction_status_ready=1`,
  `evaluator_status_ready=1`, `execution_chain_manifest_ready=1`, and
  `run_invocation_ready=1`, `official_ruler_generator_mmap_verification_ready=1`,
  `official_ruler_generator_mmap_read_rows=9`,
  `longbench_v2_official_sample_mmap_verification_ready=1`,
  `longbench_v2_official_sample_mmap_read_rows=12`,
  `external_benchmark_mmap_read_rows=21`,
  `external_benchmark_mmap_prediction_match_rows=21`,
  `external_benchmark_mmap_verification_ready_rows=4`,
  `external_benchmark_execution_chain_ready_rows=5`,
  `external_benchmark_execution_chain_ready=1`, and
  `requested_outputs_manifest_ready=1`, `requested_outputs_ready=1`,
  `source_chain_autodiscovery_ready=1`,
  `source_seed_live_fetch_autodiscovered=1`,
  `runtime_fetch_provenance_autodiscovered=1`, and
  `reproducibility_manifest_ready=1`, `direct_cli_shape_ready=1`, and
  `run_layout_manifest_ready=1`, `run_layout_ready=1`,
  `objective_requirements_manifest_ready=1`, `objective_requirements_ready=1`,
  `source_chain_evidence_mirror_ready=1`, and
  `evidence_packet_rows=50` while keeping
  `candidate_external_benchmark_result_ready=0`; tests also cross-check
  execution-chain artifact hashes against `sha256sums.txt`.
  The fourth row is a LongBench v2 official-source multiple-choice smoke over
  the live `longbench_repo` snapshot, and the fifth row is the 12-row official
  dataset-server sample baseline. It writes
  `benchmark/longbench_v2/longbench_v2_benchmark_rows.csv`,
  `benchmark/longbench_v2/longbench_v2_metrics.json`, and
  `benchmark/longbench_v2/longbench_v2_manifest.json`, then invokes official
  `result.py` and records `longbench_v2_score=100.00`,
  `longbench_v2_official_sample_rows=12`, and
  `longbench_v2_official_sample_score=0.00`; the official sample rows are also
  mmap-verified through `benchmark/longbench_v2/official_sample_store/` with
  `longbench_v2_official_sample_mmap_prediction_match_rows=12`. The external
  benchmark rows are also re-bound per row in
  `benchmark/external_benchmark_execution_chain_manifest.json` from source
  acquisition through dataset, prediction, evaluator, metrics, provenance, and
  mmap artifacts. Requested `--emit-*` output flags are recorded in
  `evidence/requested_outputs_manifest.json` and verified against the emitted
  artifacts. The concrete run output tree is separately bound in
  `evidence/run_layout_manifest.json`, covering `source/`, dataset, mmap store,
  predictions, evaluator, metrics, benchmark, evidence, resource, and promotion
  artifacts. `evidence/objective_requirements_manifest.json` audits the explicit
  objective stages from official source acquisition through promotion rows; `evidence/official_source_acquisition_rows.csv` mirrors the canonical source acquisition CSV for the documented direct command shape. The repo-level `routelm_benchmark_run` wrapper is exercised
  through `PATH`, and `evidence/reproducibility_manifest.json` records a
  shell-quoted direct runner command plus hashes for the runner,
  source-acquisition CSV, query file, and autodiscovered source-chain CSVs.
  It still keeps
  `candidate_external_benchmark_result_ready=0` until this runner-owned source
  execution is replaced or reviewed as independent external benchmark
  query/result/evaluator evidence.
- v08-m is the external benchmark source-import contract boundary. It
  verifies provided source-import rows against lower-chain source/result and
  execution URIs/hashes, import manifest/fetch-log/reviewer hash attestations,
  live-network import flags, non-fixture declarations, and independent
  source-import review. The remote-style fixture reaches
  `source_import_contract_ready=1`, but `source_import_verified=0` remains with
  `external-benchmark-source-import-real-verifier-missing`.
- v08-n is the external benchmark source-import verifier boundary. It
  can generate runner-owned replay verifier rows from the v08-m source-import
  contract, bind them back to source-import IDs, manifest/fetch-log/reviewer
  hashes, benchmark artifact URIs, and verifier binary/stdout/stderr hashes,
  and reach `source_import_verifier_ready=1`. It still keeps
  `live_network_source_import_verified=0`, `source_import_verified=0`, and
  `real_external_benchmark_verified=0` because replay is not live
  source-import verification.
- v08-o is the external benchmark source-import live-verifier boundary.
  It accepts only live-style verifier evidence above v08-n by requiring live
  verifier rows, no offline replay rows, real declarations, and non-fixture
  declarations. Such a package can reach
  `source_import_live_verifier_ready=1`, but still keeps
  `source_import_verified=0` and `real_external_benchmark_verified=0` until
  independent live review is present.
- v08-p is the external benchmark source-import live-review boundary.
  It binds non-local, hash-attested independent review rows to verifier run
  IDs, verifier artifact hashes, and source-import manifest/fetch-log hashes.
  The supplied fixture can reach
  `source_import_independent_live_review_ready=1`, but still keeps
  `source_import_verified=0` and `real_external_benchmark_verified=0` until
  v08-q authoritative review and real public registry/source-import authority
  evidence replace the supplied review package.
- v08-q is the external benchmark source-import authoritative-review
  boundary. It binds non-local, hash-attested authority review rows to
  source-import IDs, verifier run IDs, live-review IDs, live-review hashes,
  verifier hashes, reviewer identity, reviewer registry, and conflict
  disclosure evidence. The supplied fixture can reach
  `source_import_authoritative_review_ready=1`, but still keeps
  `source_import_verified=0` and `real_external_benchmark_verified=0` until
  real public registry/source-import authority evidence replaces the fixture.
- v08-r is the external benchmark source-import public-registry
  boundary. It binds non-local, hash-attested registry rows to source-import
  IDs, verifier run IDs, live-review IDs, authority-review IDs, authority
  hashes, verifier hashes, registry entry artifacts, operator identity, and
  provenance. The supplied fixture can reach
  `source_import_public_registry_ready=1`, but still keeps
  `source_import_verified=0` and `real_external_benchmark_verified=0` until a
  runner-owned live registry query/fetch path replaces supplied registry rows.
- v08-u is the latest external benchmark source-import live-registry
  network-proof boundary. v08-s query rows can reach
  `source_import_live_registry_query_ready=1`; v08-t verifies runner-owned
  fetcher metadata plus local registry response-cache hashes; and v08-u binds
  those fetch rows to network-proof metadata, request/header/TLS/DNS/nonce
  hashes, runner/tool hashes, and cache/body hash checks. Replay remains
  non-network evidence, while supplied live-style proof rows can reach
  `source_import_live_registry_network_proof_ready=1` but still keep
  `source_import_verified=0` and `real_external_benchmark_verified=0` as
  `external-benchmark-source-import-live-registry-network-proof-fixture-only`.
- The later external benchmark chain continues through v08-as. v08-v binds
  v08-u network-proof rows to verification records,
  verification reports, verifier identity artifacts, proof transcripts, and
  verified cache hashes. Supplied placeholder-domain rows can exercise the
  review mechanics up to `source_import_real_verification_review_ready=1`, but
  they still keep `source_import_verified=0` and
  `real_external_benchmark_verified=0` as
  `external-benchmark-source-import-real-verification-placeholder-domain`.
  v08-w then requires official authority/trust-root rows above non-placeholder
  verification evidence; supplied fixture authority rows can reach
  `source_import_official_authority_review_ready=1`, but keep
  `source_import_verified=0` as
  `external-benchmark-source-import-official-authority-fixture-only`.
  v08-x then requires official result-authority/leaderboard rows above final
  review; supplied fixture result-authority rows can reach
  `external_benchmark_result_authority_review_ready=1`, but keep
  `real_external_benchmark_verified=0` as
  `external-benchmark-result-authority-fixture-only`. v08-y then requires a
  publication/reproducibility/license package above result authority; supplied
  fixture publication rows can reach
  `external_benchmark_publication_review_ready=1`, but keep
  `real_external_benchmark_verified=0`.
  v08-z then requires an official source-acquisition package above the adapter
  manifest: source landing, dataset, benchmark card, split manifest, license,
  and metric spec URIs must be HTTPS, host-matched to non-placeholder official
  domains, sha256-attested, independently reviewed, and tied to non-local
  acquisition tooling. Fixture acquisition packages stay review-only, and even
  non-fixture acquisition packages keep `real_external_benchmark_verified=0`
  until imported content and result/review/publication evidence exist.
  v08-aa then verifies supplied local cache files against that official
  acquisition manifest: all six source artifacts per benchmark family must
  match the acquisition URIs and sha256 hashes, with independent content-review
  flags and zero route/jump activity. Matching cache content reaches
  `external_benchmark_source_acquisition_content_ready=1`, but still keeps
  `real_external_benchmark_verified=0`.
  v08-ab then generates a local codebase-mini package from real repository
  files, verifies source provenance, baseline/result artifacts, artifact hashes,
  and h11-c RouteMemory store linkage, and can reach
  `benchmark_result_artifact_verified=1` plus `baseline_comparison_ready=1`.
  This is still local instrumentation, so
  `real_external_benchmark_verified=0` remains.
  v08-ac then binds the v08-aa source acquisition/content row for
  codebase-retrieval to the v08-ab result package and verifies result,
  baseline, dataset, run-manifest, and evaluator hashes. It can reach
  `codebase_content_result_bridge_ready=1`, but it still leaves
  `external_benchmark_result_bridge_ready=0` and
  `real_external_benchmark_verified=0` because family coverage is only 1/4 and
  the result artifacts are local.
  v08-ad then requires supplied non-local result bridge rows for RULER,
  LongBench, codebase-retrieval, and real-document-qa. It can reach
  `family_result_bridge_review_ready=1` and
  `external_benchmark_result_bridge_ready=1`, but still keeps
  `real_external_benchmark_verified=0` because supplied bridge rows are not
  independent reproduction or official publishable benchmark evidence.
  v08-ae then binds supplied non-local independent reproduction/review rows to
  the v08-ad bridge. It can reach
  `independent_reproduction_review_ready=1`, but still keeps
  `real_external_benchmark_verified=0`. v08-af then binds supplied official
  release evidence to those reproduction rows and can reach
  `official_release_evidence_ready=1`. v08-ag then binds supplied live-release
  verification rows back to v08-af release IDs, reproduction IDs, and official
  release/archive/dataset/authority URI+hash pairs, reaching
  `official_release_live_verification_ready=1`. v08-ah then binds supplied
  canonical confirmation rows back to v08-ag live reports, network
  observations, verifier identities, release IDs, and reproduction IDs,
  reaching `canonical_online_confirmation_ready=1`. v08-ai then binds supplied
  publication/result review rows back to v08-ah canonical confirmation reports
  and content-digest manifests, reaching `publication_result_review_ready=1`,
  then v08-aj binds supplied live publication/result ingestion rows back to the
  v08-ai review and record URI/hash pairs, reaching
  `live_publication_result_ingestion_ready=1`, then v08-ak binds supplied
  authority/promotion rows back to v08-aj live records and content digests,
  reaching `authority_promotion_evidence_ready=1`, but still keeps real
  benchmark verification blocked until actual independently observed benchmark
  run/evaluator evidence replaces supplied authority mechanics. v08-al then
  recomputes the local codebase-mini dataset/result join into a runner-owned
  evaluator trace, reaching `codebase_run_evaluator_trace_ready=1` while
  coverage remains 1/4. v08-am can bind supplied independent all-family
  run/evaluator evidence rows and raise
  `external_benchmark_independent_run_evaluator_evidence_ready=1`. v08-an can
  bind supplied all-family live replay/final-review rows to that evidence and
  raise `external_benchmark_live_replay_final_review_ready=1`, but still keeps
  `real_external_benchmark_verified=0`; v08-ao can bind supplied public
  non-fixture/direct-run verification rows to v08-an and raise
  `external_benchmark_public_nonfixture_verification_ready=1`, but still keeps
  `real_external_benchmark_verified=0`; v08-ap can bind supplied runner-owned
  live execution/audit rows to v08-ao and raise
  `external_benchmark_runner_owned_live_execution_audit_ready=1`, but still
  keeps `real_external_benchmark_verified=0`; v08-aq can bind supplied
  independent live rerun confirmation rows to v08-ap and raise
  `external_benchmark_independent_live_rerun_confirmation_ready=1`, but still
  keeps `real_external_benchmark_verified=0`; v08-ar can bind supplied real
  nonfixture run package rows to v08-aq and raise
  `external_benchmark_real_nonfixture_run_package_intake_ready=1`, but still
  keeps `real_external_benchmark_verified=0`; v08-as can bind supplied live
  package artifact fetch/authority rows to v08-ar and raise
  `external_benchmark_live_package_artifact_fetch_authority_ready=1`, but still
  keeps `real_external_benchmark_verified=0`; v08-at can bind supplied
  official result reconciliation rows to v08-as and raise
  `external_benchmark_official_result_reconciliation_ready=1`, but still
  keeps `real_external_benchmark_verified=0` until v13 binds a real nonfixture
  run directory with raw traces, evaluator output, source/result artifacts, and
  claim-matrix input.
- h9-h is the latest backend/speed evidence boundary; measured-speed mechanics
  and CPU/HIP/NVMe workload-speed artifact mechanics pass, but fixture timing
  and generated workload rows remain no-claim with `gpu_speedup_claim=deferred`.
- h11-d is the latest PC RouteLM / NLG boundary; component evidence, local
  artifact-chain mechanics, a small NVMe-resident RouteMemory store smoke, and
  a diagnostic generated NLG transcript/result can be exercised, but real
  prototype/publish remains blocked with `real_pc_routelm_artifact_verified=0`
  and `real_pc_routelm_nlg_verified=0` for local/generated fixtures.

Read the current route-memory result as an objective split, not a solved
retrieval policy:

```text
byte-qacc objective -> local-energy
span-exact objective -> local-energy-hybrid in most tested groups
```

The next h10/v08-style experiment should replace h10-r supplied import/review
fixtures with official authority/registry evidence, replace the local h10-k/h10-l labels with real external teacher-label
feature labels and h10-s source-bound student-only eval rows through the h10-j/h10-l/h10-r/h10-s source-verification contracts, real benchmark
source/result evidence through the
v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at
import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review path,
with non-local lower-chain and final-review artifacts plus non-fixture live registry query/fetch/network-proof/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority
official-result-reconciliation evidence, non-fixture h9-h measured CPU/HIP/NVMe workload speed, and measured PC RouteLM/NLG prototype evidence through h11-a/h11-b/h11-c/h11-d before any
promotion claim or external benchmark comparison.

`NEXT_IMPLEMENTATION_ROADMAP_v2.md` is treated as a real-evidence transition
map rather than a request for more fixture gates. Its immediate h11-c/v08-ab/
h10-r/h10-s/h11-d/h9-h/h7-c/paper phases are already represented in this
repository as diagnostic or supplied-evidence contracts through v12, v08-at,
v13-a, v13-b, v13-c, v13-d, v13-e, v13-f, v13-g, v13-h, v13-i, v13-j, v13-k, v13-l, v13-m, v13-n, and v14-a; the next experiment family must replace those rows with actual
non-fixture teacher, benchmark, speed, and PC RouteLM/NLG evidence from one
bound run.

## h6 Span-first Guardrail

h6-q consumes the h6-p policy artifact and tests span-first selection as a
guarded policy rather than a universal preset.

```bash
experiments/run_v06_route_memory_span_first_guardrail.sh
experiments/test_v06_route_memory_span_first_guardrail.sh
```

Reference standard aggregate:

```text
qacc-default:
  qacc_mean = 0.571875
  span_exact_mean = 0.378906

strict-g0p050-cap0p050:
  span_accept_rate = 0.250000
  qacc_mean = 0.560937
  span_exact_mean = 0.425781
  qacc_delta_vs_qacc_policy_mean = -0.010938
  span_exact_delta_vs_qacc_policy_mean = 0.046875

span-first-g0p025-cap0p075:
  span_accept_rate = 0.750000
  qacc_mean = 0.538281
  span_exact_mean = 0.441406
```

Expected:

- strict guardrail accepts the span policy only for high span gain with bounded qacc loss
- looser guardrails approach the raw span-exact policy
- `routing_trigger_rate = active_jump_rate = 0`
- this is policy guardrail instrumentation, not chunk retrieval solved

## h6 Span-first Guardrail Degradation

h6-r scales the h6-q guardrail over weak and harsher learned-like source
degradation.

```bash
experiments/run_v06_route_memory_span_first_guardrail_degradation.sh
experiments/test_v06_route_memory_span_first_guardrail_degradation.sh
```

Reference standard aggregate:

```text
weak:
  objective_split_rate = 1.000000
  strict span_accept_rate = 0.000000
  strict qacc_mean = 0.517187
  strict span_exact_mean = 0.289062

harsher:
  objective_split_rate = 0.500000
  strict span_accept_rate = 0.000000
  span-first-g0p025-cap0p075 span_accept_rate = 0.500000
  span-first-g0p025-cap0p075 qacc_delta = -0.029688
  span-first-g0p025-cap0p075 span_delta = +0.023438
```

Expected:

- weak degradation can keep the objective split while rejecting span-first under the qacc-loss caps
- harsher degradation can collapse the split in some groups and admit only looser guardrails in others
- `routing_trigger_rate = active_jump_rate = 0`
- this is degradation guardrail instrumentation, not learned source robustness solved

## h6 Adaptive Guardrail Calibration

h6-s calibrates a utility-style span-first guardrail over the h6-r degradation
matrix:

```bash
experiments/run_v06_route_memory_span_adaptive_guardrail.sh
experiments/test_v06_route_memory_span_adaptive_guardrail.sh
```

Decision rule:

```text
accept span policy when span_gain - loss_weight * qacc_loss > 0
```

Reference standard aggregate:

```text
weak utility-w0p50:
  span_accept_rate = 1.000000
  qacc_delta = -0.109375
  span_delta = +0.062500

weak utility-w0p75:
  span_accept_rate = 0.000000

harsher utility-w0p75:
  span_accept_rate = 0.500000
  qacc_delta = -0.029688
  span_delta = +0.023438

harsher utility-w1p00:
  span_accept_rate = 0.000000
```

Expected:

- `utility-w0p50` is too permissive under weak high-loss splits
- `utility-w0p75` rejects weak high-loss splits and accepts the lower-loss harsher split
- `utility-w1p00` is conservative and rejects the tested split
- `routing_trigger_rate = active_jump_rate = 0`
- this is adaptive guardrail calibration, not learned source robustness solved

## h6-t Adaptive Guardrail Scale

h6-t scales the `utility-w0p75` guardrail as a diagnostic before any default
promotion.

```bash
experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh
experiments/test_v06_route_memory_span_adaptive_guardrail_scale.sh
```

Smoke aggregate:

```text
all utility-w0p75:
  groups = 2
  span_accept_rate = 0.000000
  bad_accept_rate = 0.000000
  top1_recall_gap_mean = 0.796875
  coherent_wrong_top_key_mean = 0.828125
```

Expected:

- `utility-w0p75` must not accept excessive qacc-loss splits
- byte qacc and span/chunk exactness stay separate objectives
- `routing_trigger_rate = active_jump_rate = 0`
- this is scale guardrail instrumentation, not promotion

## h6-u Chunk-quality Diagnostics

h6-u treats the value span as the current chunk unit and derives chunk-quality
readouts from h6-t:

```bash
experiments/run_v06_route_memory_chunk_quality_diagnostics.sh
experiments/test_v06_route_memory_chunk_quality_diagnostics.sh
```

Smoke aggregate:

```text
all utility-w0p75:
  chunk_exact_mean = 0.156250
  coherent_wrong_key_mean = 0.828125
  top1_recall_gap_mean = 0.796875
  keyshape_gap_mean = 0.734375
```

Expected:

- chunk exact-match, per-offset consistency, coherent wrong-key, and top1/recall
  gap are reported separately
- symbolic `key-shape` remains an upper-bound diagnostic, not the policy
- the current chunk-quality result is not ready for promotion

## h6-v/h6-w Wrong-candidate Robustness Gates

h6-v combines h6-u chunk-quality with h5 source-credit retry; h6-w separates
default promotion from weak-hint/abstain behavior.

```bash
experiments/run_v06_route_memory_wrong_candidate_robustness.sh
experiments/test_v06_route_memory_wrong_candidate_robustness.sh
experiments/run_v06_route_memory_abstain_retry_guardrail.sh
experiments/test_v06_route_memory_abstain_retry_guardrail.sh
```

Smoke result:

```text
chunk_ready = 0
source_arm = policy-source-order
source_qacc = 0.957813
source_retry_noisy_selected = 0.000000
combined_ready = 0
guardrail_action = abstain-or-weak-hint
```

Expected:

- noisy source/retry selection stays zero
- source-credit retry can be safe while chunk-quality still blocks promotion
- default route-memory promotion stays off

## h6-x Chunk-local Scorer Diagnostics

h6-x compares simple non-key-shape transforms over the chunk-local record score:
visible-prefix composition, worst-offset local energy, mean local margin, and
worst-offset local margin.

```bash
experiments/run_v06_route_memory_chunk_local_energy_prefix.sh
experiments/test_v06_route_memory_chunk_local_scorers.sh
```

Smoke aggregate:

```text
best_non_keyshape_scorer = span-local-energy
local_energy_qacc = 0.700000
local_energy_chunk_exact = 0.531250
local_energy_coherent_wrong = 0.468750
local_energy_prefix_chunk_delta = -0.031250
local_margin_chunk_exact = 0.531250
keyshape_chunk_gap = 0.468750
```

Expected:

- `span-local-energy` remains the best current non-key-shape record scorer
- prefix/worst/margin variants are diagnostic-only unless they beat chunk exact
  without qacc leakage or coherent-wrong regression
- symbolic `key-shape` remains an upper-bound diagnostic
- `routing_trigger_rate = active_jump_rate = 0`

## h6-y Chunk-code Similarity Diagnostics

h6-y compares learned route-code signature similarity against plain local-energy
chunk ranking.

```bash
experiments/run_v06_route_memory_chunk_code_similarity.sh
experiments/test_v06_route_memory_chunk_code_similarity.sh
```

Smoke aggregate:

```text
best_non_keyshape_scorer = span-local-energy
local_energy_qacc = 0.706250
local_energy_chunk_exact = 0.531250
route_code_qacc = 0.587500
route_code_chunk_exact = 0.281250
local_energy_route_code_chunk_exact = 0.531250
route_signature_collision_mean = 0.750000
keyshape_chunk_gap = 0.406250
```

Expected:

- learned route-code signature scoring remains diagnostic-only unless it beats
  plain `span-local-energy` without qacc leakage
- high route signature collision explains why direct code similarity is not yet
  a replacement for symbolic `key-shape`
- `routing_trigger_rate = active_jump_rate = 0`

## h10-a Teacher-free Chunk Ranker

h10-a turns the existing route-credit reward/slash loop into a chunk-ranking
signal by averaging candidate credit over the full candidate record span.
The scorer does not use symbolic `key-shape`; it reorders candidates with
`span-chunk-credit` or combines that signal with local energy via
`span-local-energy-chunk-credit`.

```bash
experiments/run_v10_teacher_free_chunk_ranker.sh
experiments/test_v10_teacher_free_chunk_ranker.sh
experiments/test_v10_teacher_free_chunk_ranker_scale.sh
```

Smoke aggregate:

```text
best_non_keyshape_scorer = span-chunk-credit
local_energy_qacc = 0.700000
local_energy_chunk_exact = 0.562500
chunk_credit_qacc = 1.000000
chunk_credit_chunk_exact = 1.000000
chunk_credit_coherent_wrong = 0.000000
route_credit_gap_mean = 0.800000
chunk_credit_gap_mean = 0.800000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Expected:

- chunk credit must improve qacc/chunk exact over plain `span-local-energy`
- coherent wrong-key must fall rather than merely preserving recall
- credit gap and credit top1 metrics must show correct/wrong separation
- this is a first positive chunk-ranker smoke, not default promotion until it
  scales across degradation/noisy/fallback regimes

Standard scale aggregate over 32/64-key arms:

```text
groups = 2
chunk_credit_qacc = 0.992188
chunk_credit_chunk_exact = 0.960938
chunk_credit_coherent_wrong = 0.000000
local_energy_qacc = 0.512500
local_energy_chunk_exact = 0.351562
route_credit_gap_mean = 0.799219
chunk_credit_top1_mean = 1.000000
keyshape_chunk_gap = 0.000000
```

## h10-b Chunk-credit Abstain Policy

h10-b keeps the positive chunk-credit result from becoming a default promotion
too early. The gate treats chunk credit as ready in the controlled fixture, but
requires joint fallback/retry and distillation evidence before promotion.

```bash
experiments/run_v10_chunk_credit_abstain_policy.sh
experiments/test_v10_chunk_credit_abstain_policy.sh
```

Smoke policy:

```text
guardrail_action = weak-hint-with-abstain
default_promotion = 0
diagnostic_only = 1
weak_hint_or_abstain = 1
chunk_credit_ready = 1
source_safe = 1
joint_chunk_source_ready = 0
joint_noisy_used = 1.000000
joint_fallback_retry_exercised = 0
distillation_ready = 0
combined_ready = 0
noisy_selection_clean = 1
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Expected:

- chunk-credit readiness alone is not enough for default promotion
- noisy-clean evidence stays visible, but fallback/retry and distillation stay
  blocked until they are actually exercised on the chunk-credit path
- uncertain cases route to weak-hint/abstain

## h10-c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r Joint Source, Fallback, and Teacher Gates

h10-c adds the first joint source/noisy matrix above the teacher-free chunk
ranker and a separate distillation gate. h10-d adds the missing forced
fallback/retry exercise by clearing the correct primary candidates and requiring
the retry path to recover from raw-key evidence without selecting noisy sources.
h10-e adds the teacher-label contract for distillation labels. h10-f adds the
local teacher-label collection harness. h10-g fits a local distilled-rule
learner over those labels. h10-h defines the external teacher-label ingestion
schema. h10-i adds a supplied external teacher-label CSV import path. h10-j adds
a source-verifier layer over source artifact, label export, teacher identity,
teacher policy, license, provenance, and hash evidence. h10-k adds a local
learned chunk-quality scorer over the h10-f label features and feeds it into
the distillation gate. h10-l adds the missing binding check: learned scorer
readiness only counts for source-verified distillation when supplied feature
labels are non-local, teacher-ID linked to the source evidence, row-bound to
external teacher-label rows by `source_uri` and `provenance_hash`, and backed by
real h10-j teacher-source verification. h10-m adds the remote acquisition
contract above that source gap: local `file://` packages are rejected as
local/placeholder, and HTTPS packages can become acquisition-ready but still
need h10-n content-cache verification, h10-o fetch-attestation, h10-p
runtime-fetcher replay, h10-q live-network import evidence, and h10-r
import/review evidence before a real source claim. The
default result is deliberately
diagnostic-only: noisy wrong candidates are not selected, fallback/retry is now
exercised, local collection is ready, local distillation training/eval is ready,
local learned chunk scoring is ready, and external ingestion schema is ready,
but no default external teacher-label source exists. A supplied label fixture
can mark labels ready, and a supplied local source fixture can verify the chain
mechanics, but both remain blocked before real teacher-source verification.

```bash
experiments/run_v10_chunk_credit_source_robustness.sh
experiments/test_v10_chunk_credit_source_robustness.sh
experiments/run_v10_chunk_credit_fallback_retry_exercise.sh
experiments/test_v10_chunk_credit_fallback_retry_exercise.sh
experiments/run_v10_teacher_label_contract.sh
experiments/test_v10_teacher_label_contract.sh
experiments/run_v10_teacher_label_collection_harness.sh
experiments/test_v10_teacher_label_collection_harness.sh
experiments/run_v10_teacher_distillation_learner.sh
experiments/test_v10_teacher_distillation_learner.sh
experiments/run_v10_teacher_external_label_ingestion.sh
experiments/test_v10_teacher_external_label_ingestion.sh
experiments/test_v10_teacher_external_label_import.sh
experiments/run_v10_teacher_external_label_source_verifier.sh
experiments/test_v10_teacher_external_label_source_verifier.sh
experiments/test_v10_teacher_external_label_source_import.sh
experiments/run_v10_learned_chunk_quality_scorer.sh
experiments/test_v10_learned_chunk_quality_scorer.sh
experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh
experiments/test_v10_source_verified_learned_chunk_scorer_gate.sh
experiments/run_v10_remote_teacher_source_acquisition_gate.sh
experiments/test_v10_remote_teacher_source_acquisition_gate.sh
experiments/run_v10_remote_teacher_source_content_verifier.sh
experiments/test_v10_remote_teacher_source_content_verifier.sh
experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh
experiments/test_v10_remote_teacher_source_live_fetch_attestation.sh
experiments/run_v10_remote_teacher_source_runtime_fetcher.sh
experiments/test_v10_remote_teacher_source_runtime_fetcher.sh
experiments/run_v10_remote_teacher_source_live_network_import_gate.sh
experiments/test_v10_remote_teacher_source_live_network_import_gate.sh
experiments/run_v10_chunk_credit_distillation_gate.sh
experiments/test_v10_chunk_credit_distillation_gate.sh
```

Smoke summary:

```text
best_joint_arm = chunk-credit-source-order
fallback_exercise_arm = raw-retry
chunk_credit_ready = 1
joint_chunk_ready = 1
joint_source_safe = 1
noisy_clean = 1
joint_noisy_used = 1.000000
noisy_selected = 0.000000
fallback_retry_exercised = 1
fallback_exercise_ready = 1
fallback_qacc_delta_vs_corrupt = 0.620000
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
source_verified_scorer_reason = source-verified-feature-labels-missing
teacher_external_schema_ready = 1
teacher_external_label_source_ready = 0
teacher_external_labels_ready = 0
teacher_external_label_source = external-teacher-pending
teacher_external_source_evidence = pending-fixture
teacher_source_chain_verified = 0
real_teacher_source_verified = 0
teacher_source_action = teacher-external-label-source-missing
teacher_distillation_training_ready = 1
teacher_distillation_eval_ready = 1
teacher_distillation_action_accuracy = 1.000000
teacher_learner_id = distilled-rule-v1
teacher_grounded_span_coverage = 1.000000
teacher_label_source = local-teacher-harness
distillation_ready = 0
reason = teacher-external-label-source-missing
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Supplied external-label fixture:

```text
external_label_source_ready = 1
teacher_external_labels_ready = 1
label_source = provided-external-csv
ingestion_mode = provided-csv
external_label_rows = 5
correct_labels = 1
wrong_labels = 1
near_miss_labels = 1
missing_query_labels = 1
abstain_labels = 1
teacher_source_chain_verified = 0
real_teacher_source_verified = 0
teacher_source_action = teacher-external-source-evidence-missing
distillation_ready = 0
status = diagnostic-only
reason = teacher-real-external-label-source-missing
default_promotion = 0
```

Supplied local source-verifier fixture:

```text
external_label_source_ready = 1
teacher_external_labels_ready = 1
teacher_source_source = provided-csv
external_label_rows = 5
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
```

Expected:

- injected noisy candidates must be present and not selected
- chunk-credit must remain stronger than the local-energy baseline
- fallback/retry must be forced by corrupting the primary candidates and must
  recover through non-noisy raw retry evidence
- teacher-label contract must cover correct, wrong, near-miss, missing, and
  abstain labels over grounded spans
- local teacher-label collection must pass without claiming external labels
- local teacher-distillation training/eval must pass without claiming external
  labels
- local learned chunk scoring must separate reward from negative actions
  without claiming external source evidence
- source-verified learned scoring must require supplied non-local feature
  labels linked to h10-j teacher-source evidence and row-bound to external
  teacher-label rows by `source_uri` plus `provenance_hash`
- relabeled local rows, external-label row mismatches, malformed feature CSV
  rows, and local `file://` evidence outside `results/` must not unlock the
  source-verified scorer
- remote teacher-source acquisition must require HTTPS non-local URI fields,
  sha256 hash manifests, acquisition metadata, and review evidence
- local `file://` acquisition packages must block as local/placeholder, while
  HTTPS packages must still stop before real source verification until h10-n
  content-cache verification, h10-o fetch-attestation, h10-p runtime-fetcher
  replay, h10-q live-network import evidence, h10-r import/review evidence,
  and official authority evidence exist
- default external teacher-label ingestion schema must pass without claiming a
  source
- supplied external labels must make the labels ready without enabling
  distillation or default promotion
- supplied local source fixtures may verify chain/hash mechanics, but remain
  non-real until `real_teacher_source_verified=1`
- default distillation remains blocked until real external-label source evidence
  exists

## h10-k Learned Chunk-quality Scorer

h10-k is the first local learned chunk-quality scorer gate above the teacher
label harness. It trains a deterministic linear contrastive scorer from h10-f
labels using chunk score, chunk gap, normalized span overlap, chunk top1,
coherent-wrong, noisy-source, missing-query, missing-candidate, and near-miss
features. The learned scorer is deliberately local-only: it can be ready as a
diagnostic component, but it does not turn local teacher labels into real
external source evidence or default promotion.

```bash
experiments/run_v10_learned_chunk_quality_scorer.sh
experiments/test_v10_learned_chunk_quality_scorer.sh
```

Smoke summary:

```text
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
```

Expected:

- correct chunk evidence must receive positive feature direction
- coherent wrong, noisy, missing, and near-miss risk must score negative
- reward rows must stay above zero score and negative rows below zero score
- mixed label-source CSVs are rejected so scorer provenance is not silently
  overwritten
- local scorer readiness is consumed by the distillation gate, but real
  distillation still requires h10-j real source verification

## h10-l Source-verified Learned Chunk Scorer

h10-l closes the binding gap between h10-k and h10-j. A local h10-k scorer can
separate correct and wrong chunks, and h10-j can verify teacher-source chain
mechanics, but those two facts are not enough unless the learned scorer was
trained/evaluated on feature labels tied to the same verified teacher source.
h10-l requires supplied feature labels, a non-local `label_source`, matching
teacher IDs between feature labels and source evidence, exact row binding
between feature labels and external teacher-label rows by
`teacher_id/query_key/candidate_key/teacher_label/source_uri/provenance_hash`,
source-chain verification, and real teacher-source verification before
`source_verified_learned_chunk_scorer_ready=1`.

```bash
experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh
experiments/test_v10_source_verified_learned_chunk_scorer_gate.sh
```

Default smoke summary:

```text
feature_csv_provided = 0
feature_has_binding_fields = 0
feature_bound_rows = 0
matched_feature_label_rows = 0
external_label_rows = 0
feature_external_label_link_ready = 0
feature_label_source = local-teacher-harness
feature_source_link_ready = 0
learned_chunk_scorer_ready = 1
source_verified_feature_labels_ready = 0
source_verified_learned_chunk_scorer_ready = 0
status = diagnostic-only
reason = source-verified-feature-labels-missing
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Supplied local fixture behavior:

```text
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
```

Expected:

- local h10-k labels must not satisfy source-verified learned scoring
- supplied feature labels must be teacher-ID linked to source evidence and
  row-bound to external teacher-label rows by `source_uri` plus
  `provenance_hash`
- simply relabeling h10-f local rows as external is rejected
- external-label row mismatches and malformed feature CSV rows are rejected
- local `file://` evidence outside `results/` is still local fixture evidence
  and cannot become real by declaration flags alone
- local fixture source chains may verify mechanics but remain non-real
- distillation now requires `source_verified_learned_chunk_scorer_ready=1`,
  not just local `learned_chunk_scorer_ready=1`

## h10-m Remote Teacher-source Acquisition

h10-m opens the remote teacher-source acquisition contract without pretending
that remote source content has already been fetched and verified. It is a
preflight gate for the next real external teacher-label source step: all
teacher source, label export, identity, policy, license, and review URIs must
be HTTPS non-local URIs, all hashes must be `sha256:<64 hex>`, acquisition
metadata must be non-fixture, and review evidence must be ready. Even when that
contract is satisfied, the gate keeps `real_teacher_source_verified=0` with
`remote-teacher-source-fetcher-missing`.

```bash
experiments/run_v10_remote_teacher_source_acquisition_gate.sh
experiments/test_v10_remote_teacher_source_acquisition_gate.sh
```

Default smoke summary:

```text
acquisition_rows = 0
remote_teacher_source_acquisition_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-acquisition-missing
```

Supplied local fixture behavior:

```text
acquisition_rows = 1
required_uri_fields = 6
local_uri_fields = 6
remote_uri_scheme_ready = 0
hash_manifest_ready = 1
remote_teacher_source_acquisition_ready = 0
action = remote-teacher-source-local-or-placeholder
```

Supplied HTTPS acquisition package behavior:

```text
acquisition_rows = 1
required_uri_fields = 6
https_remote_uri_fields = 6
remote_uri_scheme_ready = 1
hash_manifest_ready = 1
remote_teacher_source_acquisition_ready = 1
real_teacher_source_verified = 0
action = remote-teacher-source-fetcher-missing
```

Expected:

- local/placeholder/insecure/missing URIs must not pass the remote acquisition
  contract
- malformed acquisition CSV rows are rejected
- HTTPS package readiness is not a real teacher-source claim
- h10-n/h10-o/h10-p/h10-q/h10-r provide content-cache verification,
  fetch-attestation, runtime-fetcher replay, live-network import evidence, and
  import/review contracts; official authority evidence is still required
  before a real teacher-source claim

## h10-n Remote Teacher-source Content Verification

h10-n adds the content-cache verifier above h10-m. It consumes the HTTPS
remote acquisition manifest and an optional
`V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV`. The content CSV must bind every
teacher source, label export, identity, policy, license, and review URI back to
the h10-m remote URI/hash manifest, then provide local `file://` download/cache
files whose sha256 hashes match the remote hashes. This closes the hash/content
mechanics without claiming that a live remote fetch has happened in this
sandbox.

```bash
experiments/run_v10_remote_teacher_source_content_verifier.sh
experiments/test_v10_remote_teacher_source_content_verifier.sh
```

Default smoke summary:

```text
remote_teacher_source_acquisition_ready = 0
remote_teacher_source_content_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-acquisition-not-ready
```

Supplied HTTPS acquisition without content:

```text
remote_teacher_source_acquisition_ready = 1
content_rows = 0
remote_teacher_source_content_ready = 0
action = remote-teacher-source-content-missing
```

Supplied matching cache content:

```text
content_rows = 1
remote_uri_match_rows = 1
hash_manifest_match_rows = 1
required_content_fields = 6
content_hash_verified_fields = 6
remote_teacher_source_content_ready = 1
real_teacher_source_verified = 0
action = remote-teacher-source-live-fetch-missing
```

Expected:

- content rows must match h10-m teacher IDs, remote URIs, and sha256 hashes
- cache URIs must be local files whose content hashes match the remote hash
  manifest
- malformed content CSV rows and hash/URI mismatches are rejected or blocked
- cache verification is not a real teacher-source claim until h10-o
  fetch-attestation and runtime fetcher evidence exist above it

## h10-o Remote Teacher-source Live-fetch Attestation

h10-o adds an artifact-level fetch-attestation contract above h10-n. It
consumes the same h10-m acquisition and h10-n content CSVs plus an optional
`V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV`. The fetch-attestation CSV
must contain one row for each source, label export, identity, policy, license,
and review artifact. Each row is matched back to the h10-n remote URI, cache
URI, and content hash, then checked for fetch metadata, HTTPS attestation URI,
cached attestation hash, independent attestor identity, and explicit non-fixture
declaration. This closes the fetch-attestation evidence mechanics without yet
claiming that the repository itself performed the live fetch.

```bash
experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh
experiments/test_v10_remote_teacher_source_live_fetch_attestation.sh
```

Default smoke summary:

```text
remote_teacher_source_content_ready = 0
remote_teacher_source_live_fetch_attestation_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-content-not-ready
```

Supplied h10-n content without fetch attestation:

```text
remote_teacher_source_content_ready = 1
expected_fetch_artifact_rows = 6
fetch_attestation_rows = 0
action = remote-teacher-source-fetch-attestation-missing
```

Supplied local attestation fixture:

```text
fetch_attestation_rows = 6
matched_artifact_rows = 6
content_hash_match_rows = 6
attestation_uri_remote_rows = 0
independent_attestor_rows = 0
remote_teacher_source_live_fetch_attestation_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-independent-attestation-missing
```

Supplied remote-style attestation package:

```text
fetch_attestation_rows = 6
attestation_uri_remote_rows = 6
attestation_cache_hash_verified_rows = 6
independent_attestor_rows = 6
independent_attestation_ready_rows = 6
remote_teacher_source_live_fetch_attestation_ready = 1
real_teacher_source_verified = 0
action = remote-teacher-source-runtime-fetcher-missing
```

Expected:

- fetch-attestation rows must match h10-n teacher IDs, artifact kinds, remote
  URIs, cache URIs, and sha256 content hashes
- local-only attestation artifacts do not count as independent remote
  attestation
- malformed fetch-attestation CSV rows and attested hash mismatches are
  rejected or blocked
- the attestation contract is not a real teacher-source claim until a
  runner-owned live remote fetch path exists

## h10-p Remote Teacher-source Runtime Fetcher

h10-p adds a runner-owned runtime fetcher contract above h10-o. It consumes the
same h10-m acquisition, h10-n content, and h10-o fetch-attestation CSVs plus an
optional `V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV`. In replay mode
(`V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_REPLAY=1`), the runner writes its own
runtime fetch manifest from h10-o attestation rows, records fetcher binary and
command hashes, binds each runtime fetch row back to the attested remote URI,
cache URI, and content hash, and verifies downloaded cache hashes. This closes
the runner-owned fetcher mechanics while still refusing to treat offline replay
as a live network fetch or real teacher source.

```bash
experiments/run_v10_remote_teacher_source_runtime_fetcher.sh
experiments/test_v10_remote_teacher_source_runtime_fetcher.sh
```

Default smoke summary:

```text
remote_teacher_source_live_fetch_attestation_ready = 0
runner_owned_runtime_fetcher_ready = 0
live_network_fetch_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-fetch-attestation-not-ready
```

Supplied h10-o-ready evidence without runtime fetch rows:

```text
remote_teacher_source_live_fetch_attestation_ready = 1
expected_runtime_artifact_rows = 6
runtime_fetch_rows = 0
runner_owned_runtime_fetcher_ready = 0
action = remote-teacher-source-runtime-fetch-missing
```

Runner-owned offline replay:

```text
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
```

Expected:

- runtime fetch rows must match h10-o teacher IDs, artifact kinds, remote URIs,
  cache URIs, and content hashes
- download cache hashes must verify against the h10-o attested content hashes
- malformed runtime CSV rows, artifact mismatches, and bad download hashes are
  rejected or blocked
- runner-owned offline replay is a fetcher contract check, not a real network
  fetch or real teacher-source claim

## h10-q Remote Teacher-source Live-network Import

h10-q adds the live-network import gate above h10-p. It consumes the h10-p
runtime fetcher summary plus either h10-p replay evidence or a supplied
`V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV`. Replay proves the runner-owned
runtime fetcher path, but h10-q refuses to count replay as live-network
evidence. A supplied runtime CSV must be all network fetch rows, all real
runtime declarations, all non-fixture declarations, and still row-complete
against the six expected remote teacher-source artifacts.

```bash
experiments/run_v10_remote_teacher_source_live_network_import_gate.sh
experiments/test_v10_remote_teacher_source_live_network_import_gate.sh
```

Default smoke summary:

```text
runner_owned_runtime_fetcher_ready = 0
live_network_fetch_ready = 0
remote_teacher_source_live_network_import_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-fetch-attestation-not-ready
```

Runner-owned offline replay:

```text
runtime_fetch_source = runner-owned-replay
runtime_fetch_rows = 6
network_fetch_rows = 0
offline_replay_rows = 6
runner_owned_runtime_fetcher_ready = 1
live_network_fetch_ready = 0
remote_teacher_source_live_network_import_ready = 0
real_teacher_source_verified = 0
action = remote-teacher-source-live-network-fetch-missing
```

Supplied live-network runtime evidence:

```text
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
```

Expected:

- replay never counts as live-network evidence
- all six runtime rows must be live-network, real-declared, non-fixture rows
- live-network import readiness is not a real teacher-source claim until real
  non-fixture source import/review evidence is connected

## h10-r Real Teacher-source Import/review Chain

h10-r adds the import/review chain above h10-q. It consumes h10-q live-network
import readiness and a supplied `V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV`.
The review row must bind back to the acquisition teacher/source, carry HTTPS
URI and sha256 hash evidence for source/export/identity/policy/license plus
import manifest, review report, reviewer identity, conflict disclosure, and
source registry artifacts, and mark live-import observation, independent
review, authoritative review, registry entry readiness, real source
declaration, non-fixture declaration, and zero routing/jump activity.

```bash
experiments/run_v10_real_teacher_source_import_review.sh
experiments/test_v10_real_teacher_source_import_review.sh
```

Default smoke summary:

```text
remote_teacher_source_live_network_import_ready = 0
review_rows = 0
teacher_source_import_review_contract_ready = 0
real_teacher_source_import_review_ready = 0
real_teacher_source_verified = 0
action = real-teacher-source-live-network-import-missing
```

Supplied guarded cases:

```text
local review artifact:
  local_review_uri_fields = 5
  teacher_source_import_review_contract_ready = 0
  action = real-teacher-source-local-import-artifact

placeholder HTTPS authority:
  remote_review_uri_fields = 10
  placeholder_review_uri_fields = 5
  teacher_source_import_review_contract_ready = 1
  real_teacher_source_import_review_ready = 0
  action = real-teacher-source-placeholder-import-artifact

non-placeholder review chain:
  teacher_source_import_review_contract_ready = 1
  real_teacher_source_import_review_ready = 1
  real_teacher_source_verified = 0
  action = real-teacher-source-official-authority-missing
```

Expected:

- local review/import artifacts never become real by declaration-flag rewrite
- placeholder or reserved authorities can exercise mechanics but cannot become
  real teacher-source evidence
- non-placeholder import/review readiness is still not a final real
  teacher-source claim until official authority/registry evidence verifies it

## h10-s Source-verified Learned Scorer Evaluation

h10-s adds the student-only evaluation layer above h10-l and h10-r. It consumes
the h10-l source-verified learned scorer binding summary, the h10-r import/review
summary, and an optional
`V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV` with source-bound
student-only evaluation metrics. The eval table reports baseline versus
student-only chunk exact, span exact, wrong-answer rate, missing/abstain rate,
coherent-wrong negative rate, near-miss negative rate, and source/fixture
declaration flags.

```bash
experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh
experiments/test_v10_source_verified_learned_chunk_scorer_eval_gate.sh
```

Default smoke summary:

```text
source_verified_feature_labels_ready = 0
student_only_eval_rows = 0
student_only_eval_ready = 0
source_verified_learned_chunk_scorer_eval_ready = 0
reason = source-verified-feature-labels-missing
```

Supplied guarded fixture:

```text
source_verified_feature_labels_ready = 1
source_verified_learned_chunk_scorer_ready = 0
student_only_eval_ready = 1
chunk_exact_delta > 0
near_miss_negative_rate = 1.000000
metric_improvement_ready = 1
source_verified_learned_chunk_scorer_eval_ready = 0
reason = source-verified-learned-scorer-missing
```

Expected:

- student-only metric improvement is reported separately from source authority
- a good supplied eval fixture can pass metric checks without unlocking
  source-verified scorer eval readiness
- malformed eval CSV rows are rejected
- final scorer eval readiness still requires official real teacher-source
  authority plus zero routing/jump activity

## h7-c Promotion Review Gate

h7-c binds the internal h7-b promotion decision to the real-evidence chain:
h10-r teacher-source import/review, h10-s source-verified scorer eval, v08-ab
codebase-mini benchmark instrumentation, h11-d PC RouteLM NLG smoke, and h9-h
workload-speed evidence.

```bash
experiments/run_v07_route_memory_promotion_review_gate.sh
experiments/test_v07_route_memory_promotion_review_gate.sh
```

Smoke summary:

```text
promotion_review_contract_ready = 1
h7_default_promotion = 0
real_teacher_source_verified = 0
source_verified_learned_chunk_scorer_eval_ready = 0
real_external_benchmark_verified = 0
codebase_mini_source_ready = 1
benchmark_result_artifact_verified = 1
pc_routelm_nlg_smoke_ready = 1
diagnostic_workload_speed_ready = 1
external_thresholds_met = 1
nlg_thresholds_met = 1
wrong_answer_threshold_met = 1
real_evidence_complete = 0
promotion_review_ready = 0
default_promotion = 0
action = promotion-review-real-evidence-missing
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Expected:

- diagnostic thresholds can pass without becoming a real promotion claim
- real teacher, scorer, benchmark, NLG, and workload-speed evidence must all be
  present before `promotion_review_ready=1`
- the jump-neighbor path remains inactive

## v12 Paper/Release Claim Audit

v12 audits the currently closed diagnostic stack before any paper, release, or
strong product claim is made. It consumes h7-c, h10-r/h10-s, v08-ab,
h11-c/h11-d, and h9-h.

```bash
experiments/run_v12_paper_release_claim_audit.sh
experiments/test_v12_paper_release_claim_audit.sh
```

Smoke summary:

```text
diagnostic_release_package_ready = 1
real_release_package_ready = 0
diagnostic_claim_level = 4
publishable_claim_level = 0
release_claim = diagnostic-artifact-package-only
h7c_promotion_review_contract_ready = 1
h7c_real_evidence_complete = 0
h10r_real_teacher_source_verified = 0
h10s_source_verified_eval_ready = 0
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
```

Expected:

- diagnostic artifact packaging can pass without publishable release readiness
- every forbidden strong claim remains blocked
- paper/release promotion requires real teacher-source, source-verified scorer
  eval, external benchmark, PC RouteLM NLG, workload-speed, and h7-c evidence

## h7-b Promotion Gate and v08 Readiness

h7-b aggregates h6-t/u/v/w/x/y into a single promotion gate. h7-c then reviews
h7-b together with the h10-r/h10-s/v08-ab/h11-d/h9-h real-evidence boundary
before any default promotion can be considered. h10-a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s are
wired into the route-memory closure as later chunk-ranking/source/fallback/scorer/content/fetch-attestation/runtime-fetcher/live-network-import/import-review/eval
smokes, but they still do not unlock default promotion without real evidence.
v08 uses the h7-b/h7-c gates to decide whether an external benchmark comparison is ready. v08-b adds the
external benchmark adapter manifest for RULER, LongBench, codebase retrieval,
and real document QA. v08-c adds the evidence-ingestion schema for dataset,
license, baseline, result, evaluator, and provenance evidence. v08-d adds a
`V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV` import path and a positive supplied-CSV
fixture gate. v08-e adds baseline-vs-route-memory comparison deltas. v08-f
separates supplied placeholder evidence from real benchmark evidence by
requiring non-placeholder artifact URIs and `sha256:<64 hex>` provenance
hashes before any real benchmark claim. v08-g adds a local `file://` artifact
hash verifier, but still blocks publishable claims until benchmark authenticity
and evaluator verification exist. v08-h verifies benchmark identity, canonical
URIs, evaluator hash, and metric contract while still blocking actual external
benchmark claims until execution evidence exists. The default path still
validates schema/comparison coverage without claiming source or result evidence.
v08-i verifies evaluator output and run-log artifacts plus metric output, but
still blocks real external benchmark claims until independent external
attestation exists.
v08-j adds that attestation gate: supplied/local attestations can verify their
own artifact hashes and match execution hashes/metrics, but they still keep
`real_external_benchmark_verified=0` until the attestor is independently
verified.
v08-k verifies attestor identity, registry, conflict disclosure, and
independence provenance artifacts. Passing v08-k still keeps
`real_external_benchmark_verified=0`; it means the attestor identity chain is
ready for final review, not that the benchmark claim is publishable.
v08-l verifies final-review reports against source/provenance hashes, execution
hashes, metric values, attestation IDs, reviewer identity, and reviewer conflict
disclosure artifacts. Supplied local review fixtures can pass the mechanical
checks, but they still keep `real_external_benchmark_verified=0` unless real
non-fixture source review evidence and a source-import verification path exist.
v08-m adds that source-import contract path without treating a synthetic
remote-style fixture as real verification.
v08-n adds the runner-owned verifier/fetch-evidence replay layer above v08-m,
and still refuses to treat replay as live source-import verification.
v08-o adds the live-verifier evidence separation layer above v08-n, and still
refuses to treat live-style evidence as independently reviewed source-import
verification.
v08-p adds the independent live-review layer above v08-o, and still refuses to
treat supplied live-review mechanics as authoritative source-import
verification.
v08-q adds the authoritative-review layer above v08-p, and still refuses to
treat supplied authority-review mechanics as real public registry-backed
source-import verification.
v08-r adds the public-registry layer above v08-q, and still refuses to treat
supplied registry rows as runner-owned live registry query verification.
v08-s adds the live-registry-query layer above v08-r, and still refuses to
treat supplied live-style query rows as real source-import verification.

```bash
experiments/run_v07_route_memory_promotion_gate.sh
experiments/test_v07_route_memory_promotion_gate.sh
experiments/run_v07_route_memory_promotion_review_gate.sh
experiments/test_v07_route_memory_promotion_review_gate.sh
experiments/run_v08_external_benchmark_adapter.sh
experiments/test_v08_external_benchmark_adapter.sh
experiments/run_v08_external_benchmark_evidence_ingestion.sh
experiments/test_v08_external_benchmark_evidence_ingestion.sh
experiments/test_v08_external_benchmark_evidence_import.sh
experiments/run_v08_external_benchmark_comparison_gate.sh
experiments/test_v08_external_benchmark_comparison_gate.sh
experiments/test_v08_external_benchmark_comparison_import.sh
experiments/run_v08_external_benchmark_real_evidence_gate.sh
experiments/test_v08_external_benchmark_real_evidence_gate.sh
experiments/test_v08_external_benchmark_real_evidence_placeholder.sh
experiments/test_v08_external_benchmark_real_evidence_format.sh
experiments/run_v08_external_benchmark_artifact_verifier.sh
experiments/test_v08_external_benchmark_artifact_verifier.sh
experiments/test_v08_external_benchmark_artifact_verifier_local.sh
experiments/run_v08_external_benchmark_authenticity_gate.sh
experiments/test_v08_external_benchmark_authenticity_gate.sh
experiments/test_v08_external_benchmark_authenticity_import.sh
experiments/run_v08_external_benchmark_execution_gate.sh
experiments/test_v08_external_benchmark_execution_gate.sh
experiments/test_v08_external_benchmark_execution_import.sh
experiments/run_v08_external_benchmark_attestation_gate.sh
experiments/test_v08_external_benchmark_attestation_gate.sh
experiments/test_v08_external_benchmark_attestation_import.sh
experiments/run_v08_external_benchmark_attestor_identity_gate.sh
experiments/test_v08_external_benchmark_attestor_identity_gate.sh
experiments/test_v08_external_benchmark_attestor_identity_import.sh
experiments/run_v08_external_benchmark_final_review_gate.sh
experiments/test_v08_external_benchmark_final_review_gate.sh
experiments/test_v08_external_benchmark_final_review_import.sh
experiments/test_v08_external_benchmark_final_review_real_source_guard.sh
experiments/test_v08_external_benchmark_final_review_remote_review_guard.sh
experiments/test_v08_external_benchmark_final_review_remote_full_guard.sh
experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh
experiments/run_v08_external_benchmark_source_import_gate.sh
experiments/test_v08_external_benchmark_source_import_gate.sh
experiments/test_v08_external_benchmark_source_import_remote_contract.sh
experiments/run_v08_external_benchmark_source_import_verifier_gate.sh
experiments/test_v08_external_benchmark_source_import_verifier_gate.sh
experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh
experiments/test_v08_external_benchmark_source_import_live_verifier_gate.sh
experiments/run_v08_external_benchmark_source_import_live_review_gate.sh
experiments/test_v08_external_benchmark_source_import_live_review_gate.sh
experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh
experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh
experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh
experiments/test_v08_external_benchmark_source_import_public_registry_gate.sh
experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh
experiments/test_v08_external_benchmark_source_import_live_registry_query_gate.sh
experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh
experiments/test_v08_external_benchmark_source_import_live_registry_fetcher.sh
experiments/run_v08_external_benchmark_run_evaluator_trace.sh
experiments/test_v08_external_benchmark_run_evaluator_trace.sh
experiments/run_v08_external_benchmark_independent_run_evaluator_evidence.sh
experiments/test_v08_external_benchmark_independent_run_evaluator_evidence.sh
experiments/run_v08_external_benchmark_readiness.sh
experiments/test_v08_external_benchmark_readiness.sh
```

Smoke result:

```text
h7-b:
  chunk_local_safe = 1
  chunk_local_best_scorer = span-local-energy
  chunk_code_safe = 1
  chunk_code_best_scorer = span-local-energy
  default_promotion = 0
  status = diagnostic-only

v08:
  benchmark_families = 4
  benchmark_adapter_ready = 1
  benchmark_evidence_schema_ready = 1
  external_benchmark_source_ready = 0
  external_benchmark_result_ready = 0
  external_benchmark_ready = 0
  action = defer-external-comparison

v08-d supplied CSV fixture:
  evidence_source = provided-csv
  external_benchmark_source_ready = 1
  external_benchmark_result_ready = 1
  external_benchmark_ready = 1

v08-e supplied CSV comparison fixture:
  comparison_input_ready = 1
  benchmark_comparison_ready = 1
  publishable_comparison_ready = 0
  final_review_verified = 0
  real_external_benchmark_verified = 0
  route_memory_losses = 4
  action = diagnostic-comparison-only

v08-f default real-evidence gate:
  real_evidence_format_ready = 0
  real_external_benchmark_verified = 0
  action = external-benchmark-real-evidence-missing

v08-f supplied placeholder fixture:
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

v08-f supplied real-format fixture:
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

v08-g default artifact verifier:
  real_evidence_format_ready = 0
  artifact_verifier_ready = 0
  real_external_benchmark_verified = 0
  action = real-evidence-format-missing

v08-g local file artifact fixture:
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

v08-i supplied execution fixture:
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
  import_manifest_uri_match_rows = 4
  import_manifest_hash_match_rows = 4
  import_fetch_log_uri_match_rows = 4
  import_fetch_log_hash_match_rows = 4
  reviewer_identity_uri_match_rows = 4
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
  registry_metadata_rows = 4
  local_registry_artifact_rows = 0
  nonlocal_registry_artifact_rows = 16
  official_public_registry_rows = 4
  registry_entry_approved_rows = 4
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
  matched_codebase_family_rows = 1
  acquisition_id_match_rows = 1
  content_summary_hash_verified_rows = 1
  artifact_dir_match_rows = 1
  required_bridge_hash_fields = 5
  bridge_hash_verified_fields = 5
  source_content_bound_rows = 1
  result_artifact_bound_rows = 1
  baseline_bound_rows = 1
  dataset_bound_rows = 1
  independent_bridge_review_rows = 1
  declared_real_bridge_rows = 1
  non_fixture_declared_rows = 1
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
  external_benchmark_result_bridge_ready = 0
  real_external_benchmark_verified = 0
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
```

Expected:

- no route-memory policy is promoted by default before chunk-quality is ready
- external benchmark adapter/evidence schemas pass before source/result evidence exists
- supplied evidence CSV import can raise source/result readiness when all
  evidence fields are populated
- supplied evidence CSV comparison can compute baseline deltas while staying
  unpublished before promotion
- supplied placeholder evidence is rejected as real benchmark evidence until
  artifact URIs, provenance hashes, and a verifier exist; real-format evidence
  still blocks publishable claims until the verifier exists
- local file artifact hashes can be verified without treating synthetic local
  fixtures as authentic external benchmarks
- authenticity/evaluator contracts can pass without treating synthetic local
  fixtures as executed external benchmarks
- execution/evaluator-output artifacts can pass, and local/fixture
  attestations can match those artifacts, without treating synthetic local
  fixtures as independently verified external benchmarks
- attestor identity/provenance artifacts can pass without treating the whole
  external benchmark claim as publishable
- final-review artifacts can pass mechanical hash/metric/provenance checks
  without treating fixture/local review as a real publishable external benchmark
- local final-review artifacts must not become publishable external benchmark
  evidence by rewriting real/non-fixture declaration flags
- HTTPS hash-attested final-review artifacts can count as non-local review
  evidence, but not while lower-chain evidence/execution/attestation/identity
  artifacts are still local fixtures
- fully remote-style lower-chain and final-review artifacts still cannot become
  publishable without explicit real source-import verification
- source-import contract mechanics can pass without turning a remote-style
  fixture into a verified external benchmark
- runner-owned source-import verifier replay mechanics can pass without
  treating offline replay as live source-import verification
- live-style source-import verifier evidence can pass without treating it as
  independently reviewed source-import verification
- independent source-import live-review mechanics can pass without treating a
  supplied review package as authoritative source-import verification
- live-registry fetch/cache mechanics can pass without treating supplied fetch
  rows as real network proof
- live-registry network-proof mechanics can pass without treating supplied
  proof rows as real source-import verification
- real-verification mechanics can pass review/hash checks without treating
  placeholder verification registries as real source-import verification
- official-authority mechanics can pass review/hash/domain checks without
  treating fixture authority/trust-root rows as real source-import verification
- result-authority mechanics can pass review/hash/domain checks without
  treating fixture leaderboard/result-authority rows as real external benchmark
  verification
- publication-package mechanics can pass binding/hash/domain checks without
  treating fixture publication/reproducibility packages or unpublished
  comparisons as real external benchmark publication
- source-acquisition mechanics can pass official URI/hash/domain/review checks
  without treating acquisition metadata alone as imported or verified external
  benchmark results
- source-acquisition content-cache mechanics can pass URI/hash/cache checks
  without treating local cache verification alone as a real external benchmark
  result or publication claim
- codebase-mini mechanics can pass on real local repository files, baseline
  artifacts, result artifacts, and h11-c RouteMemory store linkage without
  treating local instrumentation as an independent external benchmark claim
- source-content/result bridge mechanics can bind v08-aa content to v08-ab
  codebase-mini results, while all-family result-bridge mechanics can require
  four non-local bridge rows and 28 sha256-attested HTTPS result fields without
  treating supplied bridge rows as real external benchmark verification
- independent reproduction/review mechanics can bind all four benchmark-family
  result bridges to supplied non-local reproduction rows and 28 sha256-attested
  HTTPS reproduction fields without treating those rows as official release
  evidence or real external benchmark verification
- local run/evaluator trace mechanics can verify a runner-owned codebase-mini
  trace, and supplied independent all-family run/evaluator evidence mechanics can
  pass URI/hash/metric/declaration guards, without treating supplied rows as live
  replayed or final-reviewed external benchmark proof
- supplied live replay/final-review mechanics can bind replay/review artifacts,
  replay query volume, metric thresholds, declarations, and route/jump zero
  while still leaving real external benchmark verification blocked until public
  non-fixture verification or direct runner-owned external runs exist
- supplied public non-fixture/direct-run verification mechanics can bind public
  artifact registries, direct-run receipts, reviewer attestations, metric
  thresholds, declarations, and route/jump zero without treating supplied
  receipts as runner-owned live execution/audit proof
- supplied runner-owned live execution/audit mechanics can bind live execution
  manifests, command receipts, network traces, dataset fetch receipts, evaluator
  outputs, metric recomputation, environment attestations, audit reports, and
  route/jump zero without treating supplied audit receipts as independent live
  rerun confirmation
- supplied independent live rerun confirmation mechanics can bind rerun
  manifests, command receipts, network traces, dataset refetch receipts,
  evaluator re-invocation, metric diffs, receipt reconciliation, environment,
  observer, third-party, timestamp, and registry evidence with route/jump zero
  without treating supplied confirmation as a real non-fixture benchmark run
  package
- supplied real nonfixture run package intake mechanics can bind run package
  manifests, raw query sets, raw prediction outputs, evaluator container
  digests/configs, metric reports, submission receipts, public archives,
  official leaderboard entries, license/PII/repro review, package signatures,
  timestamp authority, registry evidence, and route/jump zero without treating
  supplied package intake as live verified external benchmark proof
- supplied live package artifact fetch/authority mechanics can bind fetched
  artifacts, fetch receipts, authority records, HTTP status, content-digest
  match declarations, runner-owned live fetch declarations, network/TLS/DNS
  proof, authority declarations, timestamp evidence, and route/jump zero
  without treating supplied fetch/authority rows as official reconciled
  external benchmark results
- external benchmark comparison is deferred rather than overclaimed
- `routing_trigger_rate = active_jump_rate = 0`

## h11-a PC RouteLM Prototype Readiness

h11-a opens the PC RouteLM / NLG prototype boundary without claiming that a
real prototype exists. The contract requires supplied evidence for:

- a quantized 3B-14B small generator adapter
- CPU RAM or NVMe resident O(n) route memory
- GPU candidate scoring
- GPU decoder binding
- an NLG smoke result URI
- license and provenance evidence

```bash
experiments/run_v11_pc_routelm_prototype_readiness.sh
experiments/test_v11_pc_routelm_prototype_readiness.sh
experiments/test_v11_pc_routelm_prototype_import.sh
```

Default result:

```text
prototype_contract_schema_ready = 1
component_evidence_ready = 0
nlg_smoke_ready = 0
pc_routelm_prototype_ready = 0
publishable_pc_routelm_ready = 0
action = pc-routelm-components-missing
```

Supplied component fixture:

```text
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
```

Expected:

- supplied component evidence can exercise the prototype contract
- real PC RouteLM remains blocked until default promotion, real teacher-source
  distillation, external benchmark comparison, measured GPU speed evidence, and
  non-fixture artifact evidence exist
- `routing_trigger_rate = active_jump_rate = 0`

## h11-b PC RouteLM Prototype Artifact Verification

h11-b adds an artifact/provenance verifier above the h11-a component contract.
It checks artifact URIs and sha256 hashes for:

- generator model artifact
- route-memory store artifact
- candidate scorer artifact
- decoder binding artifact
- NLG smoke transcript/result
- benchmark result artifact
- license and provenance artifacts

```bash
experiments/run_v11_pc_routelm_prototype_artifact_verifier.sh
experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh
experiments/test_v11_pc_routelm_prototype_artifact_import.sh
```

Default result:

```text
prototype_rows = 0
artifact_rows = 0
prototype_artifact_chain_verified = 0
real_pc_routelm_artifact_verified = 0
action = pc-routelm-components-missing
```

Supplied local artifact fixture:

```text
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
prototype_artifact_chain_verified = 1
real_pc_routelm_artifact_verified = 0
action = pc-routelm-real-artifact-review-missing
```

Expected:

- supplied local artifacts can verify the h11-b hash-chain mechanics
- a local `results/` fixture cannot become real PC RouteLM evidence by setting
  `real_prototype_declared=1` or `fixture_or_synthetic_declared=0`
- the h11-a readiness summary now includes
  `prototype_artifact_chain_verified`, `real_pc_routelm_artifact_verified`, and
  `prototype_artifact_action`
- real PC RouteLM remains blocked until non-fixture artifact evidence, default
  promotion, teacher-source distillation, external benchmark verification, and
  measured GPU speed evidence all exist
- `routing_trigger_rate = active_jump_rate = 0`

## h11-c NVMe RouteMemory Store Artifact Smoke

h11-c creates a small concrete RouteMemory store artifact without claiming a
working PC RouteLM product. It treats NVMe as cold route-memory/chunk storage
and keeps RAM/VRAM roles as metadata and hot-candidate layers.

```bash
experiments/run_v11_nvme_route_memory_store.sh
experiments/test_v11_nvme_route_memory_store.sh
experiments/test_v11_nvme_route_memory_artifact.sh
```

Generated store files:

```text
route_memory_store.bin
route_index.bin
chunk_pages.bin
chunk_offsets.bin
chunk_credit.bin
page_table.bin
manifest.json
sha256sums.txt
```

Generated store smoke:

```text
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
```

Corrupted artifact guard:

```text
artifact_source = provided-dir
hash_verified_files = 6
route_memory_artifact_chain_verified = 0
action = nvme-route-memory-artifact-hash-mismatch
```

Expected:

- the RouteMemory store bundle can be hash-verified and byte-read by offset
- missing queries abstain rather than selecting a wrong chunk
- a corrupted store file blocks artifact-chain verification
- h11-c remains store instrumentation, not a real PC RouteLM/NLG or external
  benchmark claim
- `routing_trigger_rate = active_jump_rate = 0`

## h11-d PC RouteLM Diagnostic NLG Smoke

h11-d adds the first generator-facing diagnostic smoke above the h11-c
RouteMemory store. It writes a generated transcript/result artifact and checks
that an answer uses retrieved evidence without enabling a real product claim.

```bash
experiments/run_v11_pc_routelm_nlg_smoke.sh
experiments/test_v11_pc_routelm_nlg_smoke.sh
```

Generated NLG smoke:

```text
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
```

Guard coverage:

- bad grounding or wrong-answer rows block the NLG smoke readiness path
- malformed NLG CSV row widths are rejected
- generated fixtures cannot become real PC RouteLM/NLG evidence
- real NLG remains blocked until non-fixture generator artifacts, transcript/
  result evidence, teacher-source, benchmark, speed, and promotion gates all
  pass

## v0.2-pre Locked Baseline

The current baseline is `dmv02` with `v0.2-pre` behavior locked. `v0.2-b` now adds coupling plus a block-local coupled proposal path, so the default weak-coupling run is no longer expected to fail the `counter` gate.

## h9 ROCm/HIP Backend Scaffold

h9 adds an optional backend boundary for ROCm/HIP without changing the CPU
reference path. `DLE_ENABLE_HIP` is off by default, `--backend cpu` is the
default runtime backend, and the first HIP targets are the route-quality
candidate-weight factor parity kernel plus a diagnostic-only 16x16
proposal-score parity kernel.

CPU-only checks:

```bash
experiments/test_v09_gpu_backend_cpu_smoke.sh
experiments/test_v09_gpu_backend_nohip_error.sh
experiments/test_v09_gpu_backend_extended_boundary.sh
experiments/test_v09_gpu_backend_speed_evidence.sh
experiments/test_v09_gpu_backend_measured_speed_gate.sh
experiments/test_v09_gpu_backend_measured_speed_import.sh
experiments/test_v09_gpu_backend_real_workload_speed_gate.sh
```

h9-h workload-speed smoke:

```text
workload_source = generated-fixture
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
median_speedup = 1.500000
diagnostic_workload_speed_ready = 1
real_workload_speed_evidence_ready = 0
gpu_speedup_claim = deferred
action = real-workload-speed-evidence-missing
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Optional HIP check:

```bash
experiments/test_v09_gpu_backend_candidate_weight_parity.sh
```

Closure:

```bash
experiments/test_v09_gpu_backend_closure.sh
experiments/test_v09_gpu_backend_closure.sh --extended
```

Expected:

- CPU builds remain unchanged.
- CPU-only `--backend hip` fails clearly with a `DLE_ENABLE_HIP=ON` message.
- CPU quick closure executes candidate-weight and proposal-score numeric parity
  through the parity tool, not only static grep checks.
- GPU speedup claims remain deferred until measured CPU/HIP/NVMe workload rows
  are backed by real HIP/NVMe measurement source evidence; local fixture timing
  and generated workload artifacts remain diagnostic-only.
- HIP parity skips cleanly when ROCm/HIP is unavailable or incomplete.
- When HIP is available, candidate-weight factors and diagnostic proposal
  scores match CPU within `1e-5`.
- `routing_trigger_rate = 0` and `active_jump_rate = 0` remain closed.
- This is backend/parity instrumentation, not GPU acceleration proven and not learned routing solved.

## h6 Span Ambiguity

h6-f intentionally lowers hash bits to create offset-aware span-candidate
collisions.

```bash
experiments/run_v06_route_memory_span_ambiguity.sh
experiments/test_v06_route_memory_span_ambiguity.sh
```

Expected:

- high-bit hash control remains collision-free and exact
- low-bit hash buckets produce collision and top1/qacc degradation
- larger `K_route` can recover recall without fixing top1
- symbolic `key-shape` resolves the controlled ambiguity
- current byte-level candidate-quality preset does not solve span ambiguity
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Learned-like Span Source

h6-g weakens the route-code span source after making learned/source fallback
paths span-offset aware.

```bash
experiments/run_v06_route_memory_span_learned_source.sh
experiments/test_v06_route_memory_span_learned_source.sh
```

Expected:

- clean `route-code-key` span lookup keeps decode/recall/top1 high
- weak route-code identity lowers decode and creates learned-source collisions
- larger `K_route` can recover recall without fixing top1
- span exact-match diagnostics expose that byte qacc can hide full-span failure
- byte-level candidate-quality preset remains neutral in this stress
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-level Candidate Quality

h6-h compares span-level recall, top1, exact-match, and selected-key consistency
under clean and weak route-code span sources.

```bash
experiments/run_v06_route_memory_span_quality_diagnostics.sh
experiments/test_v06_route_memory_span_quality_diagnostics.sh
```

Expected:

- clean route-code span source keeps all-span recall/top1/exact-match high
- weak route-code source separates recall from all-span top1 and exact-match
- larger `K_route` can recover all-span recall without fixing all-span top1
- byte-level candidate-quality preset is neutral in this span stress
- symbolic `key-shape` exposes the upper bound for span-level ranking
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span Candidate-quality Gap

h6-i adds span record/key quality metrics to explain why recall-restored weak
span candidates still fail.

```bash
experiments/run_v06_route_memory_span_candidate_quality_gap.sh
experiments/test_v06_route_memory_span_candidate_quality_gap.sh
```

Expected:

- weak route-code `K_route=16` restores all-span recall but leaves top1 and
  span exact-match low
- top-key consistency can be high while top-key correctness is low, exposing
  coherent wrong-key span selection
- byte-level `base-default` remains neutral and `hybrid-safe` is not promoted
  for this stress
- symbolic `key-shape` stays an upper-bound span record-ranking diagnostic
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-prefix Ranking

h6-j adds a first non-key-shape span-record ranking probe.

```bash
experiments/run_v06_route_memory_span_prefix_ranking.sh
experiments/test_v06_route_memory_span_prefix_ranking.sh
```

Expected:

- `--route-candidate-score span-prefix` is accepted and keeps all-span recall
  populated
- span-prefix may reduce coherent wrong-key selection, but it is not promoted
  unless qacc/span exact-match also improve
- symbolic `key-shape` remains an upper-bound diagnostic
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-key-support Ranking

h6-k adds a second non-key-shape span-record ranking probe.

```bash
experiments/run_v06_route_memory_span_key_support_ranking.sh
experiments/test_v06_route_memory_span_key_support_ranking.sh
```

Expected:

- `--route-candidate-score span-key-support` is accepted and keeps all-span
  recall populated
- cross-offset candidate-key support is measured through the existing span
  candidate-quality metrics
- span-key-support may be neutral when a coherent wrong key has broad support
  across offsets
- symbolic `key-shape` remains an upper-bound diagnostic
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-local-energy Ranking

h6-l adds the first non-`key-shape` span-record ranking probe that uses the
existing local energy as a record-quality signal.

```bash
experiments/run_v06_route_memory_span_local_energy_ranking.sh
experiments/test_v06_route_memory_span_local_energy_ranking.sh
```

Expected:

- `--route-candidate-score span-local-energy` is accepted and keeps all-span
  recall populated
- span-local-energy improves qacc/span exact-match over the weak route-code
  baseline in the smoke, while remaining below symbolic `key-shape`
- candidate-key entropy and coherent wrong-key metrics explain how much of the
  span-ranking gap remains
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-local-energy Scale

h6-m checks whether the h6-l local-energy record-ranking signal survives a
small key/seed matrix.

```bash
experiments/run_v06_route_memory_span_local_energy_scale.sh
experiments/test_v06_route_memory_span_local_energy_scale.sh
```

Expected:

- weak, `span-local-energy`, and symbolic `key-shape` arms are present
- `span-local-energy` keeps all-span recall populated
- `span-local-energy` qacc/span exact-match are not below the weak baseline in
  the smoke
- standard mode reports mean qacc/span-exact/top1/key-quality deltas
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-local-energy Composition

h6-n compares span-local-energy record ranking with the existing h5
candidate-quality presets.

```bash
experiments/run_v06_route_memory_span_local_energy_composition.sh
experiments/test_v06_route_memory_span_local_energy_composition.sh
```

Expected:

- weak, local-energy, local-energy+base, local-energy+hybrid, and key-shape
  arms are present
- all arms keep all-span recall populated
- local-energy remains no worse than weak in the smoke
- h5 presets are treated as composition diagnostics, not promotion defaults
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-local-energy Policy

h6-o turns the h6-n qacc/span-exact tradeoff into an explicit policy
calibration artifact.

```bash
experiments/run_v06_route_memory_span_local_energy_policy.sh
experiments/test_v06_route_memory_span_local_energy_policy.sh
```

Expected:

- byte-qacc, span-exact, and balanced objective rows are present
- byte-qacc selects `local-energy`
- span-exact selects `local-energy-hybrid`
- span-exact improves span exact-match while trading off byte qacc
- `routing_trigger_rate = active_jump_rate = 0`

## h6 Span-local-energy Policy Scale

h6-p scales the h6-o policy split over a small key/seed matrix.

```bash
experiments/run_v06_route_memory_span_local_energy_policy_scale.sh
experiments/test_v06_route_memory_span_local_energy_policy_scale.sh
```

Expected:

- byte-qacc, span-exact, and balanced objective rows are emitted for each group
- byte-qacc consistently selects `local-energy` in the smoke
- span-exact selects `local-energy-hybrid` in the smoke
- standard mode reports objective-difference rates and mean qacc/span-exact
  tradeoffs
- `routing_trigger_rate = active_jump_rate = 0`

## Staged Flow 1-5

1. Run the counter baseline.

```bash
./experiments/run_v02_counter.sh
```

Expected: `counter` with `lambda_v = 0` succeeds strongly.

2. Run the counter ablation.

```bash
./experiments/run_v02_ablation.sh
```

Expected: higher `lambda_v` hurts `counter`; that confirms the baseline is already doing the right thing.

3. Run the repeating-text baseline.

```bash
./experiments/run_v02_repeating.sh
```

Expected: `field_byte_acc` stays below `oracle1_acc` but clearly above `byte_acc` during early and mid learning.

4. Run the tuned `v0.2-b` helper.

```bash
./experiments/run_v02b_tuned.sh
```

Expected: the tuned helper still gives a clean isolation control, but it is no longer the only way to keep `counter` healthy.

5. Read the control-vs-coupling comparison.

```bash
./experiments/run_v02b_counter_compare.sh
./experiments/run_v02b_repeating_compare.sh
```

Expected:

- default weak coupling now keeps `counter` at `field_byte_acc = 1.000000`, `joint_byte_acc = 1.000000`, `byte_acc = 1.000000`
- tuned no-coupling repeating text ends at `0.597656 / 0.597656 / 0.597656`
- tuned weak-coupling repeating text ends at `0.687500 / 0.687500 / 0.687500`

6. Run the 5-seed default-path regression before moving the stage boundary.

```bash
./experiments/run_v02b_counter_multiseed_compare.sh
./experiments/run_v02b_repeating_multiseed_compare.sh
```

Expected:

- `counter` weak coupling stays on the exactness plateau across seeds, with average last-10 `byte_acc` near `1.0`
- `repeating-text` weak coupling stays around `0.686` on average and beats the default no-coupling control across all five seeds
- `proposal_count = 30` remains a control for isolation, not the main `v0.2-b` gate

7. Probe the routing path without changing dynamics.

```bash
./experiments/run_v03_routing_probe.sh
./experiments/run_v03_routing_fixture_compare.sh
```

Expected:

- `byte_acc`, `field_byte_acc`, and `joint_byte_acc` stay unchanged between probe off/on
- routing columns stay at zero when routing is off
- with `--route-source input-byte` or `--route-source joint-code` and `--K-jump 2`, routing columns become nonzero and show O(1)-candidate coverage only
- do not read this probe as a sparse-routing win; it is diagnostics for a later chunk/token stage

8. Run the experimental static routing slice separately from the probe.

```bash
./experiments/run_v03_static_routing_compare.sh
./experiments/summarize_v03_routing_slice.sh
./experiments/run_v03_gap_gate_ablation.sh
./experiments/run_v03_adaptive_gate_ablation.sh
./experiments/run_v03_confidence_gate_ablation.sh
./experiments/run_v03_confidence_acceptance_ablation.sh
./experiments/run_v03_gate_diagnostics.sh
```

Watch for:

- `probe` mode stays prediction-neutral
- `jump-neighbors` may stay probe-equivalent under a conservative gate, or it may show nonzero active usage under a candidate-ranking slice
- either way, keep it default-off and experimental
- do not promote it unless the fixture sentinel stays neutral and the `repeating-text` signal is still worth carrying forward
- if scored top-K candidate ranking still leaves active usage at zero, treat the gate rather than the table ordering as the next bottleneck
- if `route-min-anchor-gap 0.0` opens the fixture faster than `repeating-text`, treat that as a diagnostic red flag, not as progress
- if reservoir/tick adaptive lowering also opens the fixture earlier than `repeating-text`, treat that as a no-go for the current gate family, not as a tuning opportunity
- if confidence-aware lowering still leaves `repeating-text` closed while the fixture starts regressing, treat confidence as a useful diagnostic signal but not yet a viable gate family
- if confidence-aware acceptance only pushes `active_jump_rate` back down on the fixture while leaving `repeating-text` unchanged, treat it as a guardrail rather than a routing win
- `run_v03_gate_diagnostics.sh` is the companion when you want the anchor-gap distribution itself; it compares `joint-code` and `input-byte` on both datasets under the default `jump-neighbors` gate, forced-open `gap0`, and the confidence-lowered `c=8.0` gate, and it is header-driven so anchor-gap thresholds, p50/p90/p99, gate margins, state-anchor hamming, trigger reasons, and later routing counters surface automatically
- treat it as diagnostic-only; if only the anchor-gap and filter counters move, that is still not a routing win
- `--route-min-anchor-gap 0.0` is only there to open the acceptance slice enough to observe whether `--route-accept-confidence-gain` changes anything; do not promote it as a default tuning path

9. Run the `state-code` route-signal probe and the candidate-source compare as diagnostic comparisons only.

```bash
./experiments/run_v03_route_key_diagnostics.sh
./experiments/run_v03_input_byte_jump_compare.sh
```

Expected:

- compare `joint-code` and default-off `state-code` on both `repeating-text` and the routing fixture
- read `state-code` as a bucket-key experiment only: the route anchor still comes from learned `joint-code`
- watch both `cycle` and `epoch` refresh on the guarded-jump arm
- treat the helper as diagnostic-only; the current CSV schema already includes the route-key / state-anchor diagnostics block, and the helper prints every column from `routing_trigger_rate` onward, so any triggered-only route-key diagnostics columns show up alongside the prediction metrics
- compare `joint-code`, `input-byte`, and `state-code + cycle` candidate buckets under probe, forced-open `gap0`, and confidence-accepted jump cases with the new helper; it is candidate-source probing only, not a routing-success claim
- if `state-code + cycle` only nudges candidate counts or fixture-side active usage while `repeating-text` stays unchanged, treat it as no-go for the current route-signal family
- if `state-code + epoch` collapses back to the off/probe boundary, treat that as confirmation that refresh, not the key itself, was the only moving part
- current reference readout: `state-code + cycle` has last-10 `route_key_anchor_match_rate ~= 0.996` on `repeating-text` and `~= 0.993` on the fixture, so the candidate key is nearly the same as the learned anchor
- current triggered-only readout says the same thing on the nodes that can actually use jumps: `triggered_route_key_anchor_match_rate ~= 0.996` on `repeating-text` and `~= 0.994` on the fixture
- current epoch-refresh readout: `route_key_anchor_match_rate` falls near zero and active routing stays off, so epoch state keys are stale rather than useful
- current candidate-source readout: `input-byte` is anchor-different as intended (`triggered_route_key_anchor_match_rate = 0.000` on `repeating-text`, `~= 0.019` on the fixture)
- current `input-byte gap0` readout: active jumps appear (`0.001172` on `repeating-text`, `0.022656` on the fixture), but `repeating-text` stays probe-equivalent while fixture `field_byte_acc` and `joint_byte_acc` drop, so this fails the repeat-lift/fixture-neutrality bar
- current `input-byte accept` readout: `active_jump_rate = 0.000` is expected under positive `route-accept-confidence-gain`, because same-input candidates have the same confidence; read this as an acceptance-predicate sanity check, not as the empirical no-go by itself
- no-go criterion for this slice: if an anchor-different bucket key only helps after forced opening, and forced opening moves the fixture before repeat-side lift appears, do not try to promote the key source; inspect candidate rejection/filter reasons with `experiments/run_v03_rejection_diagnostics.sh` before adding another candidate generator

10. Inspect candidate rejection/filter reasons as a follow-up diagnostic only.

```bash
./experiments/run_v03_rejection_diagnostics.sh
```

Expected:

- compare `joint-code` and `input-byte` under forced-open `gap0` and confidence-accepted jump-neighbor arms on both `repeating-text` and the routing fixture
- treat the helper as diagnostic-only; it prints every column from `routing_trigger_rate` onward, so any candidate-slot or reject/filter counters already present in the CSV schema are surfaced automatically
- use it to explain why a slice stays closed or why the fixture opens first; do not treat it as a routing win
- read `mean_jump_filter_candidates` over gate-passed triggered nodes; read `jump_filter_*_rate` fields as slot-level first-terminal reasons; read `jump_filter_underfilled_rate` as the node-level rate where fewer than `K-jump` candidates survive all filters
- current `fixture-input-gap0` readout: `jump_filter_selected_rate = 0.442083`, `jump_filter_anchor_gap_rate = 0.245495`, `jump_filter_local_replacement_rate = 0.121191`, and `jump_filter_underfilled_rate = 0.710330`
- current `fixture-input-accept` readout: `jump_filter_confidence_gain_rate = 0.556284`, `jump_filter_selected_rate = 0.000000`, and `jump_filter_underfilled_rate = 1.000000`
- current `repeating-text` readout: `route_gap_pass_rate = 0.001562` and `mean_jump_filter_candidates = 0.400000`, so the candidate-filter evidence is sparse there; this reinforces that the gate remains the first bottleneck

11. Run the value-bearing route-hint oracle slice.

```bash
./experiments/test_v03_route_hint_oracle.sh
./experiments/run_v03_route_hint_oracle.sh
```

Expected:

- treat this as the next semantic route-signal slice, not as another jump-neighbor gate
- `hint-oracle` must keep local neighbors intact and only add an oracle value-byte bias to proposal energy
- fixture query metrics are the primary gate; whole-file `byte_acc` is secondary because query positions are sparse
- current readout: `fixture-lr0p20` reaches `fixture_query_byte_acc = 0.875000`, and `fixture-lr0p30` / `fixture-lr0p50` move `fixture_query_byte_acc` and `route_hint_value_match_rate` to `1.000000`, while `fixture-off` is `0.200000`
- current no-regression check: `repeating-text` has `route_hint_query_count = 0.000000` and stays at `byte/field/joint = 0.687500/0.683594/0.687500` for all tested `lambda_route`
- decision: `v0.3-h1 oracle route hint` is `PASS`
- do not call this learned routing or sparse routing solved; the next stage is parsed key/value candidate delivery, then exact key lookup, then learned key/value hint discovery

12. Run the parsed value-candidate route-hint slice.

```bash
./experiments/test_v03_route_hint_parsed.sh
./experiments/run_v03_route_hint_parsed.sh
```

Expected:

- treat this as `v0.3-h2`, not learned routing
- parser should provide the matched record value position, and the graph should read the value byte from that candidate position
- watch `route_hint_candidate_lookup_count`, `route_hint_candidate_hit_rate`, and `route_hint_value_read_distance_mean`
- current readout: candidate hit rate is `1.000000`, mean value-read distance is `126.750000`, and `fixture_query_byte_acc` reaches `1.000000` at `lambda_route = 0.30/0.50`
- `repeating-text` remains unchanged with `route_hint_query_count = 0.000000`

13. Run the exact key-value route-hint slice.

```bash
./experiments/test_v03_route_hint_kv_exact.sh
./experiments/run_v03_route_hint_kv_exact.sh
```

Expected:

- treat this as `v0.3-h3`, not learned routing
- parser should build exact `KEY -> value_pos` records and resolve `?KEY=` queries with latest-record-wins semantics
- watch `kv_record_count`, `kv_query_count`, `kv_query_hit_rate`, `kv_duplicate_key_rate`, and `kv_missing_key_rate`
- current reference readout: `kv_query_hit_rate = 1.000000`, duplicate/missing rates are `0.000000`, mean value-read distance is `126.750000`, and `fixture_query_byte_acc = 1.000000` at `lambda_route = 0.30/0.50`
- smoke coverage includes one duplicate key and one missing key to verify the diagnostic counters
- `repeating-text` remains unchanged with `kv_query_count = 0.000000`

14. Run the exact key-value scale-up slice.

```bash
./experiments/test_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh --strong
```

Expected:

- treat this as `v0.3-h3a`, still symbolic exact KV routing and not learned routing
- default profile uses `lambda_route = 0.50`; `--strong` uses `lambda_route = 5.0`
  to separate candidate lookup failures from hint-strength/dynamics-margin limits
- distance sweep through `4096` should keep `kv_query_hit_rate = 1.000000` and
  `fixture_query_byte_acc = 1.000000`
- duplicate-key smoke should show latest-record-wins behavior with
  `kv_duplicate_key_rate > 0` and solved query accuracy
- missing-key smoke should show `kv_missing_key_rate > 0` and
  `route_hint_applied_rate = 0.000000`
- current default readout: distance `64/256/1024/4096` all solve query positions;
  `keys_k16`, `keys_k64`, and `noisy_mixed` keep exact hit rate at `1.000000` but
  do not saturate query accuracy at `lambda_route = 0.50`
- current strong readout: `keys_k64` and `noisy_mixed` recover to
  `fixture_query_byte_acc = 1.000000`, so those default failures are currently
  interpreted as hint-strength/dynamics-margin limits rather than exact lookup
  failures

15. Run the hashed key candidate route-hint slice.

```bash
./experiments/test_v03_route_hint_kv_hash.sh
./experiments/test_v03_route_hint_kv_hash_vote.sh
./experiments/test_v03_route_hint_kv_hash_weighted.sh
./experiments/test_v03_route_hint_kv_hash_key_shape.sh
./experiments/test_v03_route_hint_kv_hash_joint_code.sh
./experiments/test_v03_route_hint_kv_hash_route_code.sh
./experiments/test_v03_route_hint_kv_hash_route_code_stress.sh
./experiments/run_v03_route_hint_kv_hash.sh
./experiments/run_v03_route_hint_kv_hash_joint_code.sh
./experiments/run_v03_route_hint_kv_hash_route_code.sh
./experiments/run_v03_route_hint_kv_hash_route_code_stress.sh
```

Expected:

- treat this as `v0.3-h4-1`, still symbolic key hashing and not learned routing
- `hint-kv-hash` keeps the same route-hint path:
  `candidate value_pos -> value byte read -> proposal hint`
- watch `route_candidate_recall_rate`, `route_candidate_top1_rate`,
  `route_candidate_rank_mean`, `route_bucket_load_mean`,
  `route_bucket_load_max`, and `route_bucket_collision_rate`
- current default readout on a 32-key records-block/queries-block fixture:
  `bits8` and `bits16` have recall/top1/query accuracy all at `1.000000`
- current lossy readout: `bits4_kr4` recovers top-K recall to `1.000000`, but
  top-1 stays `0.500000` and query accuracy stays `0.500000`; this means the
  next bottleneck is ranking or multi-candidate hint aggregation, not whether a
  correct value_pos exists somewhere in the bucket
- `--route-hint-agg top1` is the h4-1 baseline; `--route-hint-agg vote` is the
  h4-2 multi-candidate aggregation slice
- watch `route_hint_vote_candidate_count_mean` and
  `route_hint_vote_margin_mean` when using `vote`
- current controlled vote smoke: top1 aggregation fails with
  `query_byte_acc = 0.000000`, while vote aggregation recovers the same fixture
  to `query_byte_acc = 1.000000`
- current standard vote readout: `bits4_kr4` improves from `0.500000` to
  `0.700000`, and `bits6_kr4` improves from `0.875000` to `0.956250`; this is a
  mitigation, not a complete collision/ranking solution
- `--route-hint-agg weighted-vote` with `--route-candidate-score value-vote` is
  the h4-3 scoring instrumentation slice
- watch `route_hint_correct_value_vote_share_mean`,
  `route_hint_vote_entropy_mean`, and `route_hint_unique_values_mean`
- current weighted smoke: `value-vote` reaches `query_byte_acc = 1.000000`,
  `correct_value_vote_share = 0.900000`, and `unique_values = 2.000000`
- current standard weighted readout: `bits4_kr4_weighted_value` stays at
  `0.700000`, and `bits6_kr4_weighted_value` stays at `0.956250`; this means
  value-frequency scoring is neutral on the default 32-key sweep because most
  collided buckets do not contain repeated value bytes
- `--route-candidate-score key-shape` is the h4-4 deterministic symbolic
  scoring baseline; it ranks hash-bucket candidates by key length, digit count,
  common prefix, and common suffix before top1 selection
- current key-shape smoke: insertion baseline has `recall = 1.000000` but
  `top1 = 0.000000` and `query_byte_acc = 0.000000`; key-shape promotes the
  correct candidate to `top1 = 1.000000` and recovers `query_byte_acc = 1.000000`
- current standard key-shape readout: `bits4_kr1_key_shape`,
  `bits4_kr4_key_shape`, and `bits6_kr4_key_shape` all reach
  `query_byte_acc = 1.000000`; this is a symbolic deterministic scoring
  baseline, not learned routing
- `--route-hash-source joint-code-key` is the h4-5b learned-code key-region
  diagnostic; it hashes each parsed key byte through the current learned
  `best_joint_byte()` code and rebuilds buckets in `GraphV02::begin_epoch`
- current joint-code smoke reaches `query_byte_acc = 1.000000`, which verifies
  the route-hint plumbing
- current 32-key joint-code readout is not yet a learned routing win:
  `bits4_kr4_vote` reaches `query_byte_acc = 0.500000` with
  `recall = 0.675000`, while `bits16_kr4_vote` reaches
  `query_byte_acc = 0.462500` with `recall = 0.687500`; this exposes a learned
  representation/bucket ambiguity gap relative to raw-key and key-shape
- h4-5c representation diagnostics are appended as
  `key_region_count`, `key_region_joint_decode_acc`, `raw_key_unique_count`,
  `joint_key_unique_count`, `joint_signature_collision_rate`, and
  `joint_vs_raw_candidate_overlap_rate`
- current 32-key representation readout: `bits16_kr4_vote` has
  `key_region_joint_decode_acc = 0.093750`, `raw_key_unique_count = 32.000000`,
  `joint_key_unique_count = 12.000000`, and
  `joint_signature_collision_rate = 0.625000`; this supports the interpretation
  that current next-byte joint code does not preserve key identity strongly
- `--route-hash-source route-code-key` with `--route-code-aux 1` is the h4-5d
  route identity auxiliary slice; it trains a separate route field toward input
  identity on key-region bytes before hashing the route-code key sequence
- route-code diagnostics are appended as `key_region_route_decode_acc`,
  `route_key_unique_count`, `route_signature_collision_rate`, and
  `route_vs_raw_candidate_overlap_rate`
- current 32-key route-code readout: `bits16_kr4_vote` reaches
  `query_byte_acc = 1.000000`, `recall = 1.000000`, `top1 = 1.000000`,
  `key_region_route_decode_acc = 1.000000`, `route_key_unique_count = 32.000000`,
  and `route_signature_collision_rate = 0.000000`; this is an explicit identity
  auxiliary baseline, not general learned semantic routing
- h4-5e route-code stress writes
  `results/v03_route_hint_kv_hash_route_code_stress_summary.csv`
- current stress readout: 32/64 keys at `bits16,K=4,eta=0.25` solve with
  `query_byte_acc = 1.000000`, while 128 keys keep
  `recall = 1.000000`, `top1 = 1.000000`, and route collision `0.000000` but
  drop to `query_byte_acc = 0.562500`; interpret this as a downstream
  dynamics/hint-strength/relaxation limit, not candidate retrieval failure
- current low-bit route-code readout mirrors sparse hash behavior:
  `bits4,K=4` has `recall = 1.000000` but `top1 = 0.500000` and
  `query_byte_acc = 0.693750`; `bits6,K=4` improves to
  `query_byte_acc = 0.943750`
- h4-5f route-code dynamics margin smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_dynamics.sh
```

- h4-5f standard dynamics sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh
```

- h4-5f writes
  `results/v03_route_hint_kv_hash_route_code_dynamics_summary.csv` with
  `fixture_query_hi_acc`, `fixture_query_lo_acc`,
  `query_route_hint_margin_mean`,
  `query_local_margin_against_route_mean`, and
  `query_effective_route_margin_mean`
- current 128-key dynamics readout: retrieval remains solved
  (`recall = 1.000000`, `top1 = 1.000000`,
  `key_region_route_decode_acc = 1.000000`) across the sweep; increasing
  `lambda_route` from `0.5 -> 10.0` moves query byte accuracy
  `0.198438 -> 1.000000` and effective margin `-6.808821 -> 5.491514`
- cycles and route-target proposal injection do not monotonically recover the
  128-key setting, so this slice points primarily to hint strength/effective
  margin rather than candidate retrieval or proposal coverage
- h4-5g adaptive route strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh
```

- h4-5g standard adaptive sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh
```

- h4-5g writes
  `results/v03_route_hint_kv_hash_route_code_adaptive_summary.csv`
- current 128-key adaptive readout: fixed low `lambda_route = 0.5` stays weak
  (`query_byte_acc = 0.173437`), fixed strong `lambda_route = 10.0` solves
  (`1.000000`), and margin mode recovers with lower mean strength:
  `alpha = 1.0` reaches `query_byte_acc = 0.998438` with
  `route_strength_mean = 4.871687`; `alpha = 1.5` reaches `1.000000` with
  `route_strength_mean = 6.454238`
- interpret h4-5g as a calibrated route-hint strength diagnostic under correct
  candidates, not as learned/noisy routing robustness
- h4-5h wrong-candidate corruption smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_corruption.sh
```

- h4-5h standard corruption sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh
```

- h4-5h writes
  `results/v03_route_hint_kv_hash_route_code_corruption_summary.csv`
- current corruption readout: with corruption `0.25`, keep-confidence adaptive
  gets `query_byte_acc = 0.648438`, `damage = 0.351562`, and
  `wrong_hint_strength_mean = 6.178977`; low-confidence corrupted hints with
  `route_min_confidence = 0.5` suppress wrong strength to `0.000000` and reach
  `query_byte_acc = 0.662500`
- interpret h4-5h as confidence guardrail instrumentation: wrong hint strength
  can be suppressed when wrong candidates are low-confidence, but damage
  reduction is modest and wrong-candidate robustness is not solved
- h4-5i candidate/value confidence calibration smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_confidence.sh
```

- h4-5i standard confidence sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh
```

- h4-5i writes
  `results/v03_route_hint_kv_hash_route_code_confidence_summary.csv`
- current confidence readout: under corruption `0.25` with correct fallback
  preserved, candidate route weight gives `candidate_conf_gap = 0.000000`;
  value-support confidence gives `value_conf_gap = 0.429167` and lowers
  `wrong_hint_strength_mean` from `5.874975` to `3.596367`
- value-support confidence does not improve qacc here
  (`0.853125 -> 0.837500`), so h4-5i is confidence calibration
  instrumentation, not wrong-candidate robustness
- h4-5j scorer-agreement confidence smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh
```

- h4-5j standard scorer-agreement sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh
```

- h4-5j writes
  `results/v03_route_hint_kv_hash_route_code_agreement_summary.csv`
- current scorer-agreement readout: under corruption `0.25` with correct
  fallback preserved, agreement confidence gives `route_agreement_conf_gap =
  0.458020`, lowers `wrong_hint_strength_mean` from `6.308168` to `3.775402`,
  and gives qacc `0.843750` versus unscaled `0.842188`
- power `2.0` suppresses wrong strength further (`2.423250`) but also lowers
  qacc (`0.832812`), so h4-5j is scorer-agreement confidence
  instrumentation with only limited mitigation
- h4-5k confidence-gated aggregation smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh
```

- h4-5k standard confidence-gated aggregation sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh
```

- h4-5k writes
  `results/v03_route_hint_kv_hash_route_code_gated_agg_summary.csv`
- current h4-5k readout: under preserve-correct corruption `0.25`,
  `confidence-gated` uses both policies (`vote_rate = 0.187500`,
  `weighted_rate = 0.812500`) and splits query quality
  (`lowconf_qacc = 0.250000`, `highconf_qacc = 0.990385`)
- h4-5k qacc is a limited mitigation in this setting:
  `corrupt-gated-agg = 0.851563` versus unscaled `0.850000`,
  value-support `0.831250`, and agreement-strength scaling `0.834375`
- wrong hint strength is not reliably reduced (`5.806380` vs unscaled
  `5.286897`), so h4-5k is aggregation-policy instrumentation, not
  wrong-candidate robustness solved
- h4-5l low-confidence diagnostics smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh
```

- h4-5l standard low-confidence diagnostics sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh
```

- h4-5l writes
  `results/v03_route_hint_kv_hash_route_code_lowconf_diagnostics_summary.csv`
- current h4-5l readout separates preserve-correct and remove-correct failure
  modes under corruption `0.25`
- preserve-correct low-confidence failures keep the correct candidate in top-K
  (`lowconf_candidate_recall = 1.000000`) but lose rank/aggregation quality
  (`lowconf_top1 = 0.000000`, `correct_value_vote_share = 0.500000`,
  `vote_entropy = 1.000000`)
- remove-correct drops candidate recall (`lowconf_candidate_recall = 0.000000`,
  `highconf_candidate_recall = 0.789062`), so that branch needs fallback or
  abstain behavior rather than another aggregation tweak
- h4-5l is diagnostics/actionable split only; it does not change route behavior
  and does not solve wrong-candidate robustness
- `repeating-text` has no KV queries and remains unchanged in the hash smoke

- h4-5m low-confidence policy split smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
```

- h4-5m standard low-confidence policy sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh --full
```

- h4-5m writes
  `results/v03_route_hint_kv_hash_route_code_lowconf_policy_summary.csv`
- h4-5m compares `aggregate`, `none`, and `weak-vote` under the same
  confidence-gated routing setup as h4-5k/h4-5l, with policy-specific clean
  baselines for `damage_vs_clean`
- current h4-5m smoke readout at corruption `0.25`: preserve-correct aggregate
  reaches `qacc = 0.854688` with `lowconf_candidate_recall = 1.000000` and
  `lowconf_top1 = 0.000000`; preserve-correct `none` drops to
  `qacc = 0.812500`, while `weak-vote` stays close at `qacc = 0.848438`
- remove-correct rows stay at `qacc = 0.804688` with high-confidence candidate
  recall `0.789062`; this is candidate availability / fallback territory, not
  an aggregation-policy fix
- h4-5m passes as low-confidence policy instrumentation/actionable split only:
  preserve-correct points to aggregation/ranking, remove-correct points to
  abstain, fallback, or redundant candidate sources

- h4-5n fallback source smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh
```

- h4-5n standard fallback source sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh --full
```

- h4-5n writes
  `results/v03_route_hint_kv_hash_route_code_fallback_source_summary.csv`
- h4-5n compares `--route-fallback-source off`, `key-shape`, and in
  standard/full mode `raw-key`; fallback is a diagnostic secondary candidate
  source and must not be described as learned routing
- current h4-5n smoke readout at corruption `0.25`: preserve-correct keeps
  fallback unused and unchanged (`qacc = 0.854688`), while remove-correct
  `key-shape` improves `qacc = 0.804688 -> 0.839062`
- key-shape fallback recovers candidate availability in remove-correct
  (`fallback_used_rate = 0.210938`, `fallback_recall = 1.000000`,
  `fallback_success_rate = 1.000000`), but fallback-used qacc remains low
  (`0.237037`), so this is fallback instrumentation / limited mitigation, not
  robustness solved

- h4-5o projected route-hint delta smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh
```

- h4-5o standard projected delta sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh --full
```

- h4-5o writes
  `results/v03_route_hint_kv_hash_route_code_projected_delta_summary.csv`
- h4-5o compares `--route-delta-mode target-only` with `projected`, plus
  `--route-pull-scale` / `--route-push-scale`; projected C-version only rewards
  direct transitions into the routed target nibble and penalizes direct
  transitions away from it
- current h4-5o smoke readout at corruption `0.25`: `projected 1.0/1.0`
  matches `target-only`; `projected pull=2.0 push=1.0` improves preserve-correct
  qacc (`0.854688 -> 0.875000`) but does not improve remove-correct
  key-shape fallback qacc (`0.237037 -> 0.237037`)
- h4-5o passes as projected-delta instrumentation / limited mitigation only:
  it verifies the local query-node route-delta hook and fallback subset metrics,
  but it does not solve fallback integration or wrong-candidate robustness

- h4-5p fallback hint strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh
```

- h4-5p standard fallback hint strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh --full
```

- h4-5p writes
  `results/v03_route_hint_kv_hash_route_code_fallback_strength_summary.csv`
- h4-5p compares `--route-fallback-strength-mult` on remove-correct
  key-shape fallback, with target-only and projected `pull=2.0` baselines when
  cheap; this is diagnostics-only and should be read as a bottleneck probe,
  not as a new robustness claim
- h4-5p smoke decision: `PASS` as fallback-strength diagnostics / limited
  mitigation. Target-only key-shape fallback improves from qacc `0.839062` and
  fallback_qacc `0.237037` at `mult=1.0` to qacc `0.898437` and fallback_qacc
  `0.518518` at `mult=10.0`. Projected `pull=2.0` improves at moderate
  multipliers but is less monotonic (`mult=5.0` qacc `0.868750`,
  fallback_qacc `0.377777`; `mult=10.0` qacc `0.846875`,
  fallback_qacc `0.274074`). This shows fallback-used failures are partly
  strength / hint-integration limited, but it is still not learned routing or
  wrong-candidate robustness solved.

- h4-5q fallback adaptive strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh
```

- h4-5q standard fallback adaptive strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh --full
```

- h4-5q writes
  `results/v03_route_hint_kv_hash_route_code_fallback_adaptive_summary.csv`
- h4-5q adds `--route-fallback-strength-mode fixed|margin`,
  `--route-fallback-lambda-base`, `--route-fallback-lambda-max`, and
  `--route-fallback-margin-alpha`, plus fallback subset strength distribution
  columns
- h4-5q smoke decision: `PASS` as fallback-adaptive diagnostics /
  lower-strength limited mitigation. Fixed `mult=10.0` remains stronger
  (`fallback_qacc=0.518518`, mean strength `55.376972`), while margin
  `alpha=8.0`, max `40.0` improves over fixed `mult=1.0` with lower mean
  strength (`fallback_qacc=0.400000`, mean strength `25.902632`). This does
  not solve fallback robustness; next probe is fallback persistence / TTL.

- h4-5r fallback channel-specific strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh
```

- h4-5r standard fallback channel-specific strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh --full
```

- h4-5r writes
  `results/v03_route_hint_kv_hash_route_code_fallback_channel_summary.csv`
- h4-5r adds `--route-fallback-hi-strength-mult` and
  `--route-fallback-lo-strength-mult`, plus
  `route_fallback_hi_effective_strength_mean` and
  `route_fallback_lo_effective_strength_mean`
- h4-5r smoke decision: `PASS` as fallback-channel diagnostics / limited
  mitigation. Balanced fallback `mult=5` reaches qacc `0.887500` and
  fallback_qacc `0.466666`; low-channel boost reaches qacc `0.904687` and
  fallback_qacc `0.548148`; high-channel boost falls to qacc `0.868750` and
  fallback_qacc `0.377778`. This suggests the residual fallback-used
  integration bottleneck is more low-nibble sensitive, but it still uses
  symbolic key-shape fallback and hand-set channel multipliers.

- h4-5s fallback channel-adaptive strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh
```

- h4-5s standard fallback channel-adaptive strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh --full
```

- h4-5s writes
  `results/v03_route_hint_kv_hash_route_code_fallback_channel_adaptive_summary.csv`
- h4-5s adds `--route-fallback-channel-strength-mode fixed|margin`,
  `--route-fallback-hi-margin-alpha`, `--route-fallback-lo-margin-alpha`,
  `--route-fallback-hi-lambda-max`, and `--route-fallback-lo-lambda-max`, plus
  channel-local margin diagnostics
- h4-5s smoke decision: `PASS` as fallback channel-adaptive instrumentation /
  lower-strength limited mitigation. Margin-balanced reaches qacc `0.864062`
  and fallback_qacc `0.355555`; lo-biased margin reaches qacc `0.871875` and
  fallback_qacc `0.392592` by increasing low-channel effective strength
  (`16.427150 -> 23.382717`). Fixed lo-boost remains stronger
  (`fallback_qacc = 0.525926`), so this is not fallback robustness solved.

- h4-5t low-nibble fallback strength grid smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh
```

- h4-5t standard low-nibble fallback strength grid:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh --full
```

- h4-5t writes
  `results/v03_route_hint_kv_hash_route_code_fallback_low_grid_summary.csv`
- h4-5t keeps `route_fallback_hi_strength_mult = 5.0` and sweeps the low
  channel multiplier; it uses the existing h4-5r channel-strength options and
  does not add new C++ behavior
- h4-5t smoke decision: `PASS` as low-channel strength calibration /
  limited mitigation. The current smoke peaks around `lo_mult=10.0`:
  `lo5 fallback_qacc=0.400000`, `lo7.5=0.540741`, `lo10=0.548148`,
  `lo15=0.533333`. This supports the low-nibble bottleneck interpretation and
  suggests the next TTL/persistence probe should compare against the
  `lo_mult=7.5..10` sweet spot.

- h4-5u fallback persistence / TTL smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh
```

- h4-5u standard fallback persistence / TTL sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh --full
```

- h4-5u writes
  `results/v03_route_hint_kv_hash_route_code_fallback_persistence_summary.csv`
- h4-5u adds `--route-fallback-persist-cycles`, plus
  `route_fallback_persist_used_rate` and
  `route_fallback_persist_cycles_mean`
- h4-5u smoke decision: `PASS` as fallback persistence instrumentation /
  neutral diagnostics. Persistence accounting is wired (`ttl=3` reports
  used rate `1.000000` and mean cycles `3.000000`), but the current policy
  does not improve the calibrated low-channel baselines:
  `lo7.5 ttl0 -> ttl3` fallback_qacc `0.540741 -> 0.525926`, and
  `lo10 ttl0 -> ttl3` remains `0.548148 -> 0.548148`. This suggests the
  current short TTL update-priority hook is not the missing lever for
  fallback robustness.

- h4-5v route-credit smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh
```

- h4-5v standard route-credit run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh --full
```

- h4-5v writes
  `results/v03_route_hint_kv_hash_route_code_route_credit_summary.csv`
- h4-5v adds value-position credit options:
  `--route-credit-learning`, `--route-credit-score-weight`,
  `--route-credit-eta-reward`, `--route-credit-eta-slash`,
  `--route-credit-decay`, and `--route-credit-clip`
- h4-5v smoke decision: `PASS` as route-credit separation instrumentation /
  tiny mitigation. Preserve-correct corruption with credit learning produces
  a positive credit separation (`correct_mean=0.313938`,
  `wrong_mean=-0.796331`, `gap=1.110268`) and a small qacc move
  (`0.845312 -> 0.850000`). This validates the credit ledger and weighting
  path but does not solve wrong-candidate robustness.
- h4-5v interpretation: route credit can learn a candidate-quality signal, but
  the current effect on query accuracy is small. The remaining bottleneck is
  likely a combination of credit strength, credit granularity, and fallback
  hint integration dynamics.
- h4-5w route-credit ablation smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh
```

- h4-5w standard route-credit ablation run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh --full
```

- h4-5w writes
  `results/v03_route_hint_kv_hash_route_code_route_credit_ablation_summary.csv`
- h4-5w is route-credit ablation diagnostics only: it sweeps value-pos credit
  knobs, compares fallback low-channel strength combinations, and keeps a
  query-value probe wired into the smoke; do not read it as robustness solved
  or learned routing solved
- h4-5w smoke decision: `PASS` as route-credit ablation instrumentation /
  limited mitigation. The smoke keeps value-pos credit active
  (`value-pos-strong-slash` gap `0.618182`), wires query-value edge credit
  (`query-value-probe` gap `0.598951`), and shows credit plus low-channel
  fallback can move the fallback subset (`fallback-lo7p5-off` fallback_qacc
  `0.688889`, `fallback-lo10-on` fallback_qacc `0.777778`). This is not
  wrong-candidate robustness solved and not learned routing solved.
- h4-5x credit × fallback factorial smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
```

- h4-5x standard credit × fallback factorial run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
./experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh --full
```

- h4-5x writes
  `results/v03_route_hint_kv_hash_route_code_credit_fallback_factorial_summary.csv`
- h4-5x crosses true `--route-credit-mode off`, `value-pos`, and
  `query-value` with key-shape fallback `hi_mult=5`, low-channel multipliers
  `7.5/10/15`, and both preserve-correct and remove-correct corruption rows
- h4-5x smoke decision: `PASS` as credit × fallback integration diagnostics /
  limited mitigation. Preserve-correct qacc stays neutral (`0.862500`) while
  credit separates candidates (`value-pos gap 0.463636`, `query-value gap
  0.750000`). In remove-correct rows, credit lifts qacc from `0.912500` to
  `0.925000` at `lo=7.5/10` and fallback_qacc from `0.688889` to `0.733334`;
  `lo=15` remains weaker (`off qacc 0.906250`, credit-on qacc 0.918750,
  fallback_qacc 0.711111). This is not wrong-candidate robustness solved and
  not learned routing solved.
- h4-5y route-credit calibration smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_credit_calibration.sh
```

- h4-5y standard route-credit calibration run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh
./experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh --full
```

- h4-5y writes
  `results/v03_route_hint_kv_hash_route_code_credit_calibration_summary.csv`
- h4-5y calibrates active `value-pos` versus `query-value` credit around
  key-shape fallback with `hi_mult=5`, `lo_mult=7.5/10`, score weight,
  slash strength, corruption rate, and preserve/remove rows; smoke also keeps
  true `off` baselines
- h4-5y smoke decision: `PASS` as route-credit strength/stability
  calibration diagnostics and limited mitigation. Off baselines remain
  credit-neutral. Active credit rows all produce positive gaps. Query-value
  preserve rows show larger separation (`gap=0.750000`) than comparable
  value-pos rows (`0.290625` or `0.236364` in the smoke). Remove rows populate
  fallback metrics; examples include `value-pos remove lo10 sw1 slash0.20
  cr0.25` with qacc `0.925000`, gap `0.642326`, fallback_qacc `0.733334`,
  and `query-value remove lo7.5 sw2 slash0.10 cr0.25` with qacc `0.925000`,
  gap `0.450000`, fallback_qacc `0.733334`. This is calibration only, not
  wrong-candidate robustness solved.
- h5-a route-plasticity smoke:

```bash
./experiments/test_v05_route_credit_plasticity.sh
```

- h5-a standard route-plasticity run:

```bash
./experiments/run_v05_route_credit_plasticity.sh
./experiments/run_v05_route_credit_plasticity.sh --full
```

- h5-a writes `results/v05_route_credit_plasticity_summary.csv`
- h5-a adds a persistent `--route-plasticity-ledger` plus
  `--route-credit-learn-after-epoch` / `--route-credit-apply-after-epoch`
  warmup gates. The smoke uses the h4-5y query-value credit carry-forward cell
  with key-shape fallback `hi_mult=5`, `lo_mult=10`.
- h5-a smoke decision: `PASS` as route-plasticity ledger instrumentation.
  Ledger rows populate `route_plasticity_ledger_size` and
  `route_plasticity_ledger_mean_abs_credit`, while learn/apply gates separate
  accumulated credit from when it affects weighted candidate votes. The smoke
  also asserts `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`, preserving the value-bearing path and not
  reviving jump-neighbor replacement. This is not learned routing solved and
  not wrong-candidate robustness solved.
- h5-b source/bucket route-credit smoke:

```bash
./experiments/test_v05_route_source_credit.sh
```

- h5-b standard source/bucket route-credit run:

```bash
./experiments/run_v05_route_source_credit.sh
./experiments/run_v05_route_source_credit.sh --full
```

- h5-b writes `results/v05_route_source_credit_summary.csv`
- h5-b adds disabled-by-default source/bucket credit knobs:
  `--route-source-credit-learning`,
  `--route-source-credit-score-weight`,
  `--route-source-credit-eta-reward`,
  `--route-source-credit-eta-slash`,
  `--route-source-credit-decay`, and
  `--route-source-credit-clip`
- h5-b smoke decision: `PASS` as source/bucket route-credit
  instrumentation / responsibility signal. In remove-correct corruption,
  source-on keeps the value-bearing lookup/read path populated and separates
  source responsibility: source credit size `73.000000`, primary mean
  `0.023438`, fallback mean `0.300000`, gap `0.276563`, primary slashed rate
  `0.281250`, and fallback rewarded rate `1.000000`. The smoke also verifies
  `routing_trigger_rate = 0.000000` and `active_jump_rate = 0.000000`. qacc is
  neutral in this smoke, so this is not fallback robustness solved and not
  learned routing solved.
- h5-c source-credit policy smoke:

```bash
./experiments/test_v05_route_source_credit_policy.sh
```

- h5-c standard source-credit policy run:

```bash
./experiments/run_v05_route_source_credit_policy.sh
./experiments/run_v05_route_source_credit_policy.sh --full
```

- h5-c writes `results/v05_route_source_credit_policy_summary.csv`
- h5-c adds `--route-source-credit-learning`,
  `--route-source-credit-score-weight`,
  `--route-source-credit-eta-reward`,
  `--route-source-credit-eta-slash`, and the persistent
  `--route-plasticity-ledger` carry-forward cell. The smoke keeps remove-correct
  corruption at `0.25` with key-shape fallback `hi_mult=5`, `lo_mult=10`.
- h5-c smoke decision: `PASS` as source-credit policy calibration
  instrumentation / neutral diagnostics. Learn-only creates a source gap
  (`0.276563`) without applying it; source ranking keeps the same gap but
  turns on `source_apply_active = 1.000000`; source ranking+strength doubles
  the gap to `0.553125`; and the persistent-ledger row only changes persistent
  state (`ledger_size = 0 -> 59`, `mean_abs_credit = 0.711864`) while qacc
  stays `0.931250` on the ledger rows. This is policy calibration, not
  robustness solved.
- h5-d noisy-source policy smoke:

```bash
./experiments/test_v05_route_source_credit_noisy_source.sh
```

- h5-d standard noisy-source policy run:

```bash
./experiments/run_v05_route_source_credit_noisy_source.sh
./experiments/run_v05_route_source_credit_noisy_source.sh --full
```

- h5-d writes `results/v05_route_source_credit_noisy_source_summary.csv`
- h5-d keeps remove-correct corruption at `0.25` and probes two source-quality
  branches: weak `joint-code-key` primary with symbolic `key-shape` fallback,
  and explicit `noisy-route-code` fallback/source stress with
  `--route-noisy-source-rate 1.0`.
- h5-d smoke decision: `PASS` as noisy / learned-like source policy
  diagnostics. The smoke keeps `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`. The weak joint branch learns a positive
  source gap for useful key-shape fallback, while the explicit noisy branch
  learns a negative source gap and populates
  `route_source_credit_noisy_mean < 0` plus nonzero noisy slash diagnostics.
  This is source-quality separation instrumentation, not robustness solved.
- h5-e noisy-source scale smoke:

```bash
./experiments/test_v05_route_source_credit_noisy_scale.sh
```

- h5-e standard noisy-source scale run:

```bash
./experiments/run_v05_route_source_credit_noisy_scale.sh
./experiments/run_v05_route_source_credit_noisy_scale.sh --full
```

- h5-e writes `results/v05_route_source_credit_noisy_scale_summary.csv`
- h5-e smoke crosses key counts `32/64`, seeds `1/2`, and noisy rates
  `0.50/1.00`. Standard mode uses key counts `64/128`, seeds `1..3`, and
  noisy rates `0.25/0.50`; full mode expands to key counts `64/128/256`,
  seeds `1..5`, and noisy rates `0.10/0.25/0.50/1.00`.
- h5-e smoke decision: `PASS` as noisy-source multi-seed / scale stability
  instrumentation. The weak `joint-code-key` primary plus `key-shape`
  fallback branch keeps positive fallback source gaps across the smoke. The
  explicit `noisy-route-code` branch keeps negative noisy-candidate credit and
  nonzero noisy slash diagnostics across key counts and seeds. At
  `noise=1.0`, source gap is also negative; at mixed `noise=0.5`, source gap
  can be positive because the source still contains correct fallback support,
  so the noisy-candidate credit/slash metrics are the sharper signal. This is
  stability instrumentation, not source-credit robustness solved.
- h5-f learned-source stress smoke:

```bash
./experiments/test_v05_route_source_credit_learned_source_stress.sh
```

- h5-f standard learned-source stress run:

```bash
./experiments/run_v05_route_source_credit_learned_source_stress.sh
./experiments/run_v05_route_source_credit_learned_source_stress.sh --full
```

- h5-f writes
  `results/v05_route_source_credit_learned_source_stress_summary.csv`
- h5-f adds `--route-code-key-region-keep-prob` and
  `--route-code-aux-noise-rate` as default-off route-code identity weakening
  controls. They apply only to the route-code identity auxiliary update, so
  key signature readout still reads the learned route field rather than
  directly corrupting the route key.
- h5-f smoke crosses key counts `32/64`, seeds `1/2`, and two branches:
  clean full route-code identity supervision and weak learned-source stress
  (`keep=0.25`, `aux_noise=0.75`). Clean rows keep route decode, primary
  recall, and qacc at `1.000000`. Weak rows lower route-code decode and
  primary recall, trigger key-shape fallback, and populate positive
  source-credit gap, primary slash, and fallback reward diagnostics.
- h5-f smoke decision: `PASS` as weaker learned-source stress
  instrumentation. This is source-quality detection under controlled route-code
  identity weakening, not learned routing solved and not source-credit
  robustness solved.
- h5-g weak learned-source scale smoke:

```bash
./experiments/test_v05_route_source_credit_learned_source_scale.sh
```

- h5-g standard weak learned-source scale run:

```bash
./experiments/run_v05_route_source_credit_learned_source_scale.sh
./experiments/run_v05_route_source_credit_learned_source_scale.sh --full
```

- h5-g writes
  `results/v05_route_source_credit_learned_source_scale_summary.csv`
- h5-g smoke crosses key counts `64/128`, seeds `1/2`, and four arms:
  `clean-off`, `mid-off`, `weak-off`, and `weak-fallback-ledger`.
- h5-g uses clean route-code identity (`keep=1.0`, `aux_noise=0.0`), mid
  weakening (`keep=0.5`, `aux_noise=0.25`), and weak learned-source stress
  (`keep=0.25`, `aux_noise=0.75`).
- h5-g smoke decision: `PASS` as weak learned-source multi-seed / scale
  stability diagnostics. Mean smoke readout:

```text
clean-off:
  qacc=1.000000, decode=1.000000, primary_recall=1.000000
mid-off:
  qacc=0.970313, decode=0.630937, primary_recall=0.994531
weak-off:
  qacc=0.185938, decode=0.000000, primary_recall=0.285938
weak-fallback-ledger:
  qacc=0.460156, decode=0.000000, primary_recall=0.285938,
  fallback_used=0.714063, source_gap=0.305619,
  primary_slash=0.467693, fallback_reward=1.000000
```

Interpretation:
source weakening produces a stable degradation curve over the small key/seed
smoke, and key-shape fallback plus source-credit ledger partially mitigates
the weak-source damage while populating responsibility signals. This remains
controlled scale/stability instrumentation with symbolic fallback, not learned
routing solved and not source-credit robustness solved.
- h5-h fallback-source ablation smoke:

```bash
./experiments/test_v05_route_source_credit_fallback_ablation.sh
```

- h5-h standard fallback-source ablation run:

```bash
./experiments/run_v05_route_source_credit_fallback_ablation.sh
./experiments/run_v05_route_source_credit_fallback_ablation.sh --full
```

- h5-h writes
  `results/v05_route_source_credit_fallback_ablation_summary.csv`
- h5-h smoke keeps the weak route-code source fixed (`keep=0.25`,
  `aux_noise=0.75`) and crosses key counts `64/128`, seeds `1/2`, and
  fallback sources `off`, `raw-key`, `key-shape`, and `noisy-route-code`.
- h5-h smoke decision: `PASS` as fallback-source dependence / stability
  diagnostics. Mean smoke readout:

```text
fallback-off:
  qacc=0.213281, primary_recall=0.316406, fallback_used=0.000000
fallback-raw-key:
  qacc=0.650000, fallback_used=0.683594, fallback_recall=1.000000
fallback-key-shape:
  qacc=0.437500, fallback_used=0.683594, fallback_recall=1.000000,
  source_gap=0.299223
fallback-noisy-route-code:
  qacc=0.173437, fallback_used=0.683594, fallback_recall=0.000000,
  source_gap=-0.207562, noisy_mean=-0.201440, noisy_slash=0.979234
```

Interpretation:
`raw-key` and `key-shape` are symbolic fallback controls, with `key-shape`
remaining the symbolic upper-bound source-credit branch. `noisy-route-code`
acts as a bad fallback stress and gets negative source/noisy credit. This
separates fallback-source dependence from learned-source quality, but it is not
learned routing solved and not source-credit robustness solved.

## h5-i Source-credit Fallback Policy Calibration Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_policy.sh
```

The h5-i smoke keeps the weak route-code source from h5-g/h5-h fixed and
compares source-credit fallback policy modes:

- key counts `64/128`
- seeds `1/2`
- `off-control`
- `raw-key-ceiling`
- `key-shape-learn-only`
- `key-shape-ranking`
- `key-shape-strength`
- `key-shape-ranking-strength`
- `noisy-learn-only`
- `noisy-ranking-strength`

Average smoke readout:

```text
off-control:
  qacc=0.206250, primary_recall=0.309375, fallback_recall=0.000000

raw-key-ceiling:
  qacc=0.661328, fallback_recall=1.000000, fallback_qacc=0.689142

key-shape-learn-only:
  qacc=0.473437, fallback_recall=1.000000, source_gap=0.299047

key-shape-ranking:
  qacc=0.473437, selected_fallback=0.660209, strength_mean=1.000000

key-shape-strength:
  qacc=0.473437, selected_fallback=0.000000, strength_mean=1.402324

key-shape-ranking-strength:
  qacc=0.473437, selected_fallback=0.660209, strength_mean=1.402324

noisy-learn-only:
  qacc=0.170703, fallback_recall=0.000000, source_gap=-0.182191,
  noisy_mean=-0.189995, noisy_slashed=0.976094

noisy-ranking-strength:
  qacc=0.170703, fallback_recall=0.000000, source_gap=-0.182191,
  selected_fallback=0.363317, strength_mean=1.000000,
  noisy_mean=-0.189995, noisy_slashed=0.976094
```

Decision:
`h5-i` passes as source-credit fallback-policy calibration diagnostics, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

Interpretation:
`key-shape` source credit produces a positive source gap and the apply modes
are wired separately: ranking changes selected-fallback diagnostics, strength
raises route-source strength, and ranking-strength combines both. However,
qacc remains neutral across these key-shape policy modes. `noisy-route-code`
is correctly treated as a bad fallback stress: it gets negative noisy/source
credit and high noisy slash, does not recover fallback recall, and strength
does not increase beyond `1.0`. `raw-key` remains a symbolic ceiling. This is
policy calibration instrumentation on the value-bearing route-hint path, not
learned routing solved.

## h5-j Fallback Candidate-quality Gap Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_quality.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_quality.sh
```

The h5-j smoke fixes the weak route-code source and compares `raw-key` and
`key-shape` fallback candidate quality under `vote`, `weighted-vote`, and
source-credit `ranking-strength`.

Reference smoke readout:

```text
raw-vote-off:
  qacc=0.225000, fallback_qacc=0.198214,
  correct_vote_share=0.296354, entropy=1.868280

keyshape-vote-off:
  qacc=0.200000, fallback_qacc=0.167857,
  correct_vote_share=0.287760, entropy=1.881561

raw-weighted-off:
  qacc=0.942188, fallback_qacc=0.996429,
  correct_vote_share=0.789853, entropy=0.958879

keyshape-weighted-off:
  qacc=0.960938, fallback_qacc=1.000000,
  correct_vote_share=0.842201, entropy=0.766750

raw-weighted-policy:
  qacc=0.943750, fallback_qacc=1.000000,
  source_gap=0.325494, selected_fallback=0.875000

keyshape-weighted-policy:
  qacc=0.960938, fallback_qacc=1.000000,
  source_gap=0.325494, selected_fallback=0.875000
```

Both fallback sources keep low top1 (`candidate_top1=0.031250`) and mean rank
`2.500000`, so the smoke does not support a top1-solved interpretation.
Instead, weighted-vote raises correct-value support and lowers entropy enough
to rescue both sources. The immediate bottleneck is fallback aggregation
quality, not fallback recall alone.

Decision:
`h5-j` passes as fallback candidate-quality gap diagnostics, but it does not
solve learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

## h5-k Fallback Aggregation Policy Calibration Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_aggregation.sh
```

The h5-k smoke keeps the weak route-code source fixed and compares fallback
aggregation policies for `raw-key` and `key-shape` fallback:

- `top1`
- `vote`
- `weighted-vote`
- confidence-gated low=`vote`, high=`weighted-vote`
- confidence-gated low=`weighted-vote`, high=`weighted-vote`

Reference smoke readout:

```text
raw-key:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.328125, fallback_qacc=0.312500
  weighted qacc=0.943750, fallback_qacc=0.987500
  gated vote/weighted qacc=0.739062, vote_rate=0.317188
  gated weighted/weighted qacc=0.943750

key-shape:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.204688, fallback_qacc=0.166071
  weighted qacc=0.956250, fallback_qacc=0.996429
  gated vote/weighted qacc=0.443750, vote_rate=0.678125
  gated weighted/weighted qacc=0.956250
```

Interpretation:
plain unweighted vote is the weak policy in this fallback setting. Top1 and
weighted-vote are strong controlled baselines. Confidence-gated aggregation is
only as good as the low-confidence policy: low=`vote` inherits the vote
failure, while low=`weighted-vote` preserves the weighted-vote baseline. This
is aggregation-policy calibration, not fallback robustness or learned routing
solved.

## h5-l Source/noise-aware Fallback Aggregation Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_aggregation.sh
```

The h5-l smoke keeps the weak route-code source fixed and compares symbolic
fallback sources against an explicit noisy fallback negative control. Symbolic
fallback arms use weighted aggregation and source-credit policy; noisy arms
verify that a bad fallback source is detected but not solved.

Reference smoke readout:

```text
raw-key:
  vote qacc=0.401563, fallback_qacc=0.391071
  source-aware qacc=0.965625, fallback_qacc=1.000000,
  correct_vote_share=0.872579, entropy=0.646051,
  source_gap=0.355541, strength_mean=1.544219

key-shape:
  vote qacc=0.218750, fallback_qacc=0.176786
  source-aware qacc=0.964063, fallback_qacc=1.000000,
  correct_vote_share=0.852162, entropy=0.734797,
  source_gap=0.355541, strength_mean=1.544219

noisy-route-code:
  vote qacc=0.059375, fallback_recall=0.000000
  source-aware qacc=0.189062, fallback_recall=0.000000,
  source_gap=-0.140244, noisy_mean=-0.197850,
  noisy_slashed=1.000000, noisy_selected=0.000000,
  strength_mean=1.000000
```

Decision:
`h5-l` passes as source/noise-aware fallback aggregation diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

Interpretation:
weighted/source-aware aggregation is a strong integration policy for symbolic
fallback sources in this controlled setting. A noisy fallback source is still
not recoverable by aggregation, but it is assigned negative source/noisy credit
and is not strength-amplified. This confirms that good-source aggregation and
bad-source detection are separable mechanisms.

## h5-m Source/noise-aware Aggregation Scale Stability Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_scale.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_scale.sh
```

The h5-m smoke extends h5-l over key count and seed arms. It crosses
`key_count=64/128` with `seed=1/2` and compares plain vote with source-aware
weighted aggregation for `raw-key`, `key-shape`, and `noisy-route-code`
fallback sources.

Reference smoke averages:

```text
raw-key:
  vote qacc=0.378516, fallback_qacc=0.297216
  source-aware qacc=0.925391, fallback_qacc=0.996875,
  correct_vote_share=0.860390, entropy=0.641214,
  source_gap=0.314231, strength_mean=1.439082

key-shape:
  vote qacc=0.275781, fallback_qacc=0.115804
  source-aware qacc=0.932813, fallback_qacc=1.000000,
  correct_vote_share=0.848875, entropy=0.696635,
  source_gap=0.314231, strength_mean=1.439082

noisy-route-code:
  vote qacc=0.099219, fallback_recall=0.000000
  source-aware qacc=0.317969, fallback_recall=0.000000,
  source_gap=-0.268339, noisy_mean=-0.231653,
  noisy_slashed=1.000000, strength_mean=1.000000
```

Decision:
`h5-m` passes as source/noise-aware aggregation scale stability diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

Interpretation:
the h5-l pattern is not a single-smoke artifact. Source-aware weighted
aggregation repeatedly improves symbolic fallback integration over broad vote
across the tested key/seed smoke arms. The noisy fallback branch remains
unresolved, but it is consistently down-signaled by negative source/noisy
credit and is not strength-amplified. The next bottleneck is bad-source
abstention/filtering or replacing the noisy candidate source, not stronger
aggregation alone.

## h5-n Bad-source Filter / Abstain Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_bad_source_filter.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_bad_source_filter.sh
```

The h5-n smoke adds source-credit filtering:

```bash
--route-source-filter-mode negative-credit
--route-source-filter-threshold <float>
```

The filter removes candidates whose source credit falls below the threshold.
This is tested as a bad-source abstention diagnostic on top of the same
value-bearing route-hint path.

Reference smoke readout:

```text
symbolic fallback:
  raw-filter qacc=0.951562, fallback_recall=1.000000,
  source_gap=0.328890, source_filter_abstain=0.000000

  keyshape-filter qacc=0.965625, fallback_recall=1.000000,
  source_gap=0.328890, source_filter_abstain=0.000000

noisy fallback:
  noisy-unfiltered qacc=0.185937, source_gap=-0.116147,
  noisy_mean=-0.177831, noisy_slashed=0.974458

  noisy-filter qacc=0.100000, fallback_recall=0.000000,
  source_filter_filtered=0.935065, source_filter_abstain=0.875000,
  strength_mean=1.000000
```

Decision:
`h5-n` passes as bad-source filtering / abstention instrumentation, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

Interpretation:
negative source credit can now be used to remove candidates from bad/noisy
sources instead of merely down-weighting them. This preserves the symbolic
fallback path in the smoke and exposes high filter/abstain rates for the noisy
fallback. However, filtering bad candidates does not recover missing correct
candidates: noisy fallback qacc decreases rather than improves. The next
bottleneck is a replacement/fallback source or source-quality retry policy,
not stronger filtering alone.

## h5-o Retry-source Replacement Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_source.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_source.sh
```

The h5-o smoke adds a secondary retry source:

```bash
--route-source-retry-source off|raw-key|key-shape|joint-code-key|noisy-route-code
```

The retry source is inserted into the same value-bearing candidate path:

```text
candidate value_pos -> value byte read -> proposal hint
```

It does not activate jump-neighbor replacement. The goal is narrow: after
negative-credit filtering removes a bad/noisy source, can a secondary source
restore candidate availability and query accuracy?

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  source_filter_filtered=0.937013,
  source_filter_abstain=0.876562,
  source_retry_used=0.000000

retry-raw:
  qacc=0.950000, fallback_recall=1.000000,
  fallback_qacc=0.991071,
  source_filter_abstain=0.003125,
  source_retry_used=0.875000,
  source_retry_success=0.875000

retry-keyshape:
  qacc=0.962500, fallback_recall=1.000000,
  fallback_qacc=1.000000,
  source_filter_abstain=0.003125,
  source_retry_used=0.875000,
  source_retry_success=0.875000
```

Decision:
`h5-o` passes as retry-source replacement instrumentation and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

Interpretation:
h5-n showed that filtering can suppress bad/noisy candidates but cannot recover
missing correct candidates. h5-o shows the complementary mechanism: once bad
source candidates are filtered, a secondary symbolic retry source can restore
candidate recall and qacc. This is still a controlled diagnostic because the
successful retry sources are symbolic `raw-key` / `key-shape` upper bounds.
The next bottleneck is making retry-source selection less symbolic and more
credit/policy driven.

## h5-p Source-credit Retry-policy Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_policy.sh
```

The h5-p smoke adds policy-selected retry candidates:

```bash
--route-source-retry-policy fixed|source-credit
--route-source-retry-candidates raw-key,key-shape,noisy-route-code
--route-source-retry-per-source-limit 1
```

The route path remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  source_filter_abstain=0.878125

fixed-raw:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000

policy-mixed:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

policy-raw-noisy:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000
```

Decision:
`h5-p` passes as source-credit retry-policy calibration instrumentation and
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

Interpretation:
h5-p moves beyond a single fixed retry source. The source-credit retry policy
can insert retry candidates from a candidate source list and avoid selecting
the bad/noisy retry source in the smoke. However, the mixed policy currently
falls back to the raw-key retry under equal initial source credit and does not
beat the fixed key-shape symbolic upper bound. The result is policy-selection
plumbing and calibration, not learned retry-source selection solved.

## h5-q Source-credit Retry-policy Tie-break Calibration

`h5-q` passes as source-credit retry-policy tie-break calibration diagnostics
/ limited mitigation on top of `h5-p`. It keeps the same value-bearing route
path and tests whether source-order or source-prior should win when retry
sources are available.

The slice adds:

```bash
--route-source-retry-tiebreak source-order|source-prior
--route-source-retry-priorities <csv>
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_tiebreak.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_tiebreak.sh
```

The smoke keeps the same value-bearing route path:

```text
candidate value_pos -> value byte read -> proposal hint
```

and compares these rows:

```text
noisy-filter
policy-source-order
policy-keyshape-prior
policy-noisy-penalty/mixed
fixed-keyshape
```

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  noisy_slashed=1.000000, source_retry_used=0.000000

policy-source-order:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

policy-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

policy-noisy-penalty/mixed:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  fallback_qacc=1.000000
```

Decision:
`h5-q` passes as source-credit retry-policy tie-break calibration diagnostics /
limited mitigation, but it is not learned routing solved, not source-credit
robustness solved, and not wrong-candidate/fallback robustness solved.

Interpretation:
the new tie-break layer makes source-order versus source-prior explicit for the
retry path. It can route around the noisy retry and preserve the symbolic
retry-source path, but the fixed key-shape reference remains the upper bound.
That makes h5-q a calibration/guardrail result, not a new routing capability.

## h5-r Source-prior Schedule / Retry Tie-break Calibration

`h5-r` passes as source-prior schedule calibration diagnostics / limited
mitigation on top of `h5-q`. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```bash
--route-source-retry-prior-mode none|static|decay|warmup
--route-source-retry-prior-decay <float>
--route-source-retry-prior-warmup-epochs <int>
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_prior_schedule.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_prior_schedule.sh
```

The smoke keeps the same value-bearing route path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Reference smoke readout:

```text
source-order:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

static-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

decay-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

warmup-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  fallback_qacc=1.000000
```

Interpretation:
the source-prior schedule layer can make the source-order/static/decay/warmup
choice explicit and steer the retry policy away from noisy retry candidates.
However, the scheduled-prior rows still do not reach the fixed key-shape
symbolic reference. This remains calibration / limited mitigation, not learned
source selection solved.

## h5-s Source-prior Handoff Diagnostics

`h5-s` passes as source-prior handoff calibration diagnostics / limited
mitigation on top of `h5-r`. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice keeps the same value-bearing retry path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_prior_handoff.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_prior_handoff.sh
```

Reference smoke readout:

```text
source-order:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

static-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

warmup-short:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.062500,
  retry_keyshape_selected=0.812500,
  retry_noisy_selected=0.000000

warmup-long:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

decay-fast:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  fallback_qacc=1.000000
```

Interpretation:
the handoff instrumentation is wired. Short warmup partially relaxes the
key-shape prior and allows a small raw-key retry selection rate, while long
warmup, static prior, and fast decay keep key-shape selected and still avoid
the noisy retry source. However, all scheduled-prior rows remain at
`qacc=0.957813`, below the fixed key-shape reference. This is evidence that
source-prior scheduling is controllable, but source-credit evidence still does
not independently close the symbolic key-shape upper-bound gap.

## h5-t Retry-source Evidence-quality Diagnostics

`h5-t` passes as retry-source evidence-quality instrumentation, but it does not
solve learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice adds retry-source credit readouts:

```text
route_source_retry_raw_mean
route_source_retry_keyshape_mean
route_source_retry_noisy_mean
route_source_retry_raw_rewarded_rate
route_source_retry_keyshape_rewarded_rate
route_source_retry_noisy_slashed_rate
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_evidence_quality.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_evidence_quality.sh
```

Reference smoke readout:

```text
source-order:
  qacc=0.960937, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_raw_mean=0.222951,
  retry_keyshape_mean=0.000000,
  retry_noisy_mean=-0.206811

static-keyshape-prior:
  qacc=0.960937, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_raw_mean=0.000000,
  retry_keyshape_mean=0.222951,
  retry_noisy_mean=-0.206811

warmup-keyshape-prior:
  qacc=0.960937, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_keyshape_mean=0.222951,
  retry_noisy_mean=-0.206811

raw-quality-evidence:
  retry_raw_mean=0.222951,
  retry_raw_rewarded=1.000000,
  retry_noisy_slashed=1.000000

keyshape-quality-evidence:
  retry_keyshape_mean=0.222951,
  retry_keyshape_rewarded=1.000000,
  retry_noisy_slashed=1.000000
```

Interpretation:
the retry-source evidence ledger is now visible. It reliably assigns positive
credit to the selected non-noisy retry source and negative/slash signal to the
noisy source. However, raw-key and key-shape receive the same positive credit
when each is the selected clean retry source. Therefore source-credit evidence
currently detects bad/noisy retry sources, but it does not independently rank
raw-key versus key-shape or close the symbolic source-selection problem.

## h5-u Candidate-quality Diagnostics Decision

`h5-u` passes as candidate-quality logdet/channel/quality-score
instrumentation. It does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds metric-only candidate-quality diagnostics behind
`route_quality_apply=none`. The smoke verifies that instrumentation does not
change behavior: `quality-off-source-order` and `quality-on-source-order` both
produce `qacc=0.645313`, with `route_hint_candidate_lookup_count=128`,
positive value-read distance, and `routing_trigger_rate=active_jump_rate=0`.

The diagnostics separate candidate-set quality in the fixed-source arms:

```text
fixed-raw:
  qacc = 0.742187
  route_quality_logdet_mean = -5.818573
  route_quality_condition_mean = 7.050210
  route_quality_score_mean = 2.016223

fixed-keyshape:
  qacc = 0.645313
  route_quality_logdet_mean = -15.330912
  route_quality_condition_mean = 52.270703
  route_quality_score_mean = 0.852792
```

Interpretation:
candidate recall and retry source credit are not enough. The fallback/retry
candidate set has measurable internal quality: value-only Gram logdet,
condition proxy, channel margin imbalance, and continuous quality score expose
the raw-key versus key-shape difference in this smoke. These metrics remain
diagnostic-only and must not be used as hard filters.

## h5-v Weak Quality Application Decision

`h5-v` passes as weak quality source-ranking application diagnostics and
neutral-to-slight-regression. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice is the first behavior-changing use of the h5-u quality diagnostics,
but it stays deliberately soft: `route_quality_apply=source-ranking` adds a
bounded source-ranking delta only. It does not hard-filter candidates and does
not change route strength.

Reference smoke:

```text
apply-none-source-order:
  qacc = 0.568750
  route_quality_apply_active = 0.000000

source-ranking-b0p10:
  qacc = 0.560938
  route_quality_apply_active = 1.000000
  route_quality_source_ranking_delta_mean = 0.227710
  route_quality_selected_raw_rate = 0.850000
  route_quality_selected_noisy_rate = 0.000000

source-ranking-b0p25:
  qacc = 0.560938
  route_quality_apply_active = 1.000000
  route_quality_source_ranking_delta_mean = 0.250000
  route_quality_selected_raw_rate = 0.850000
  route_quality_selected_noisy_rate = 0.000000
```

Interpretation:
quality source-ranking is wired and keeps the value-bearing route path active,
but it does not improve qacc in this smoke. The next step should be calibration
of the quality proxy/sign and source-specific evidence before trying
`candidate-weight` or `strength`.

## h5-w Source-quality Calibration Decision

`h5-w` passes as source-quality calibration diagnostics, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice extends the h5-v summary with source-specific quality proxy, soft
delta, and selected-source qacc columns:

```text
apply-none-source-order:
  qacc = 0.568750
  raw_proxy = 2.277099
  keyshape_proxy = -0.472130
  noisy_proxy = -0.513364
  selected_raw_qacc = 0.611905

source-ranking-b0p10:
  qacc = 0.560938
  raw_delta = 0.227710
  keyshape_delta = -0.047213
  noisy_delta = -0.051336
  selected_raw_qacc = 0.600298
  selected_noisy = 0.000000

source-ranking-b0p25:
  qacc = 0.560938
  raw_delta = 0.250000
  keyshape_delta = -0.118032
  noisy_delta = -0.128341
```

Interpretation:
the current quality proxy strongly prefers raw-key over key-shape/noisy and
therefore explains why source-ranking keeps selecting raw-key while avoiding
the noisy retry source. However, the resulting qacc is neutral-to-slightly
worse than apply-none. This identifies proxy calibration, not application
strength, as the next bottleneck. The next step is h5-x proxy weight/sign
calibration before trying stronger candidate-weight or route-strength
applications.

## h5-x Proxy Weight/Sign Calibration Decision

`h5-x` passes as proxy weight/sign calibration diagnostics and single-smoke
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice keeps `route_quality_apply=source-ranking` fixed and sweeps proxy
term signs. It continues to preserve the value-bearing route path and keeps
`routing_trigger_rate=active_jump_rate=0`.

Reference smoke:

```text
proxy-default:
  qacc = 0.560938
  raw_proxy = 2.277099
  keyshape_proxy = -0.472130
  noisy_proxy = -0.513364

logdet-sign-flip:
  qacc = 0.567187
  raw_proxy = 1.722901
  keyshape_proxy = -1.084626
  noisy_proxy = -1.118645

channel-sign-flip:
  qacc = 0.662500
  raw_proxy = 2.277099
  keyshape_proxy = -0.412249
  noisy_proxy = -0.381355
  selected_raw_qacc = 0.720536
```

Interpretation:
the channel term sign is a real calibration handle in this smoke. The best
row improves qacc without selecting the noisy retry source, but the selected
source remains raw-key. Therefore this is not learned source selection solved;
it is a single-smoke indication that the quality proxy can change the retained
candidate tail / weighted-vote mixture enough to affect qacc. Next: run
multi-seed/scale stability for the channel-sign calibration before trying
candidate-weight or route-strength application.

## h5-y Channel-sign Multi-seed / Scale Stability Decision

`h5-y` passes as channel-sign calibration multi-seed/scale diagnostics and
weak limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice compares three arms while keeping the value-bearing route path
unchanged:

```text
proxy-off:
  route_quality_apply = none

proxy-default:
  route_quality_apply = source-ranking
  channel_weight = +0.1

proxy-channel-sign:
  route_quality_apply = source-ranking
  channel_weight = -0.1
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656

proxy-default:
  qacc_mean = 0.621094
  selected_raw_rate_mean = 0.753385
  selected_noisy_rate_mean = 0.000000

proxy-channel-sign:
  qacc_mean = 0.636198
  selected_raw_rate_mean = 0.753385
  selected_noisy_rate_mean = 0.000000
  selected_raw_qacc_mean = 0.672334
```

Interpretation:
the channel-sign calibration from h5-x is not only a single-row artifact in
this first scale smoke: it remains better than proxy-default and proxy-off on
mean qacc while continuing to avoid noisy retry. However, source selection
does not move toward key-shape; it remains raw-key-centered. Therefore h5-y is
stability diagnostics and weak limited mitigation, not source selection solved.

Next:
test source-specific normalization or candidate-level quality application
before using stronger route-strength modulation.

## h5-z Source-normalization Decision

`h5-z` passes as source-normalization instrumentation and neutral diagnostics,
but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
--route-quality-source-normalization none|center|zscore
--route-quality-source-norm-eps <float>
```

The existing raw proxy metrics are preserved, and new normalized-proxy metrics
show the score actually used by the source-ranking delta:

```text
route_quality_retry_raw_norm_proxy_mean
route_quality_retry_keyshape_norm_proxy_mean
route_quality_retry_noisy_norm_proxy_mean
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656

channel-sign-none:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 2.277099
  delta_mean = 0.227710
  selected_raw_rate_mean = 0.753385
  selected_noisy_rate_mean = 0.000000

channel-sign-center:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 1.104578
  delta_mean = 0.110458
  selected_raw_rate_mean = 0.753385

channel-sign-zscore:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 0.873139
  delta_mean = 0.087314
  selected_raw_rate_mean = 0.753385
```

Interpretation:
source normalization successfully reduces raw-key ranking pressure without
reintroducing noisy retry and without regressing qacc relative to channel-sign.
However, it does not change the selected source: the policy remains raw-key
centered. Therefore the remaining bottleneck is not only source-level proxy
scale. The next slice should test candidate-level quality diagnostics or
candidate-level application while keeping strength modulation off.

## h5-aa Candidate-level Quality Diagnostics Decision

`h5-aa` passes as candidate-level quality diagnostics and an actionable split,
but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds candidate-level quality metrics without changing route behavior:

```text
route_quality_candidate_weight_correct_mean
route_quality_candidate_weight_wrong_mean
route_quality_candidate_weight_gap
route_quality_candidate_best_correct_rate
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656
  candidate_weight_correct = 0.398027
  candidate_weight_wrong = 0.217518
  candidate_weight_gap = 0.180509
  candidate_best_correct_rate = 0.838021

channel-sign-none:
  qacc_mean = 0.636198
  candidate_weight_correct = 0.396566
  candidate_weight_wrong = 0.217533
  candidate_weight_gap = 0.179034
  candidate_best_correct_rate = 0.838021

channel-sign-center/zscore:
  qacc_mean = 0.636198
  candidate_weight_gap = 0.179034
  candidate_best_correct_rate = 0.838021
```

Interpretation:
the candidate-level weight signal separates correct from wrong candidates, and
the best weighted candidate is correct more often than final qacc. This points
away from source-level normalization as the main remaining bottleneck and
toward candidate-level application, aggregation, or hint-integration dynamics.
The next slice should test a weak bounded candidate-level quality application
while keeping route-strength modulation off.

## h5-ab Weak Candidate-level Quality Application Decision

`h5-ab` passes as weak bounded candidate-level quality application diagnostics
and limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice enables `--route-quality-apply candidate-weight` with a bounded
relative-weight factor:

```text
factor = clamp(
  1 + beta * (base_weight / mean_base_weight - 1),
  min_factor,
  max_factor
)
```

It keeps the route-strength path off and preserves:

```text
candidate value_pos -> value byte read -> proposal hint
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656

source-ranking:
  qacc_mean = 0.636198

candidate-b0p10:
  qacc_mean = 0.635156
  factor_gap = 0.052627
  candidate_weight_gap = 0.193792

candidate-b0p25:
  qacc_mean = 0.663542
  factor_gap = 0.131568
  candidate_weight_gap = 0.212711

candidate-b0p50:
  qacc_mean = 0.725261
  factor_gap = 0.263136
  candidate_weight_gap = 0.241817
```

Interpretation:
bounded candidate-level sharpening turns the candidate correctness signal from
h5-aa into a real qacc lift in this smoke. The effect is still controlled and
does not solve robustness: qacc remains below `candidate_best_correct_rate =
0.838021`, and the result still depends on controlled route-hint fixtures. The
next slice should test scale stability and source-ranking composition before
any route-strength modulation.

## h5-ac Candidate-weight Composition Decision

`h5-ac` passes as candidate-weight scale/composition diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
--route-quality-apply source-candidate
```

This combined mode applies both source-ranking and candidate-weight quality
paths, without changing route strength or topology.

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off qacc_mean              = 0.622656
source-ranking qacc_mean         = 0.636198
candidate-b0p25 qacc_mean        = 0.663542
candidate-b0p50 qacc_mean        = 0.725261
source-candidate-b0p25 qacc_mean = 0.667708
source-candidate-b0p50 qacc_mean = 0.717708
```

Interpretation:
candidate-only application remains the strongest current quality path. The
combined source-candidate mode is wired and safe, but it does not improve over
candidate-b0p50 in this smoke. This suggests the immediate next target is
candidate-only beta/scale stability, not stronger source-ranking composition or
route-strength modulation.

## h5-ad Candidate-only Beta / Noise Scale Decision

`h5-ad` passes as candidate-only beta/noise scale diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds `experiments/run_v05_route_quality_candidate_scale.sh` and
`experiments/test_v05_route_quality_candidate_scale.sh`. It keeps
`route_quality_apply=candidate-weight`, does not change route strength, and
preserves the value-bearing route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Standard sweep:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.10, 0.25, 0.50

proxy-off qacc_mean        = 0.615799
candidate-b0p25 qacc_mean  = 0.666580
candidate-b0p50 qacc_mean  = 0.722222
candidate-b0p75 qacc_mean  = 0.775434
```

The candidate-weight separation also scales with beta:

```text
candidate-b0p25 factor_gap = 0.132544
candidate-b0p50 factor_gap = 0.265089
candidate-b0p75 factor_gap = 0.397633
```

Safety guards:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
candidate-only quality weighting is not merely a single-noise smoke artifact in
this controlled setting. `beta=0.75` is the best tested point and does not yet
show over-sharpening. This remains limited mitigation, not learned routing or
robustness solved. The next step should find the saturation/cap boundary before
using quality scores for route-strength modulation.

## h5-ae Candidate-weight Saturation / Cap Decision

`h5-ae` passes as candidate-weight saturation/cap diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds candidate-weight concentration metrics:

```text
route_quality_candidate_weight_factor_p90
route_quality_candidate_weight_factor_max
route_quality_candidate_weight_entropy_mean
route_quality_candidate_weight_top_share_mean
```

and the runner/test pair:

```text
experiments/run_v05_route_quality_candidate_saturation.sh
experiments/test_v05_route_quality_candidate_saturation.sh
```

Standard sweep:

```text
keys = 128
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta = 0.75, 1.00, 1.25, 1.50, 2.00
cap = 2.0, 3.0, 4.0
```

Readout:

```text
b0p75-cap2/3/4 qacc = 0.867188
b1p00-cap2/3/4 qacc = 0.884896
b1p25-cap2/3/4 qacc = 0.899219
b1p50-cap2/3/4 qacc = 0.913542

b2p00-cap2 qacc     = 0.905729
b2p00-cap3/4 qacc   = 0.922396
b2p00-cap3/4 f_max  = 2.333333
b2p00-cap3/4 top_share = 0.585550
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
within this controlled sweep, candidate-weight sharpening remains beneficial
through `beta=2.0` when the cap is not too tight. The first boundary observed
is not over-sharpening but clipping: cap `2.0` suppresses the best `beta=2.0`
setting relative to cap `3.0/4.0`. This is still limited mitigation in
route-hint fixtures, not learned routing or robustness solved.

## h5-af Candidate-quality Regression / Scale Decision

`h5-af` passes as candidate-quality best-setting scale regression diagnostics
and limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds the runner/test pair:

```text
experiments/run_v05_route_quality_candidate_regression.sh
experiments/test_v05_route_quality_candidate_regression.sh
```

Standard sweep:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
arms = proxy-off, b0.75/cap2, b1.5/cap2, b2.0/cap2, b2.0/cap3
```

Readout:

```text
proxy-off qacc_mean              = 0.637153
candidate-b0p75-cap2 qacc_mean   = 0.800478
candidate-b1p50-cap2 qacc_mean   = 0.854948
candidate-b2p00-cap2 qacc_mean   = 0.843620
candidate-b2p00-cap3 qacc_mean   = 0.869965
```

`candidate-b2p00-cap3` is the best tested arm in every key/noise bucket:

```text
k64  n0.25 qacc = 0.741667
k64  n0.50 qacc = 0.738542
k128 n0.25 qacc = 0.925000
k128 n0.50 qacc = 0.919792
k256 n0.25 qacc = 0.958073
k256 n0.50 qacc = 0.936719
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the h5-ae best-setting pattern is not just a 128-key saturation artifact in
this standard regression sweep. `beta=2.0, cap=3.0` remains the strongest
candidate-quality setting tested across key count and noisy-source rate, while
cap `2.0` still clips useful separation at high beta. This is limited
mitigation inside controlled route-hint fixtures, not learned routing or
robustness solved.

## h5-ag Candidate-quality Over-sharpen Boundary Decision

`h5-ag` passes as candidate-quality over-sharpen boundary diagnostics and
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_boundary.sh
experiments/test_v05_route_quality_candidate_boundary.sh
```

Standard sweep:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta/cap = 2.0/3.0, 2.5/3.0, 2.5/4.0, 3.0/3.0, 3.0/4.0, 3.0/6.0
```

Readout:

```text
candidate-b2p00-cap3 qacc_mean     = 0.934896
candidate-b2p50-cap3/4 qacc_mean   = 0.942448
candidate-b3p00-cap3/4/6 qacc_mean = 0.947331

candidate-b3p00-cap3/4/6:
  factor_max = 3.000000
  top_share = 0.615203
  entropy = 1.389753
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the tested range still does not expose over-sharpen collapse. `beta=3.0`
continues to improve qacc over the h5-af `beta=2.0` baseline, and caps
`3.0/4.0/6.0` are identical because the quality factor max reaches only
`3.000000`. This is limited mitigation inside controlled route-hint fixtures,
not learned routing or robustness solved.

## h5-ah High-beta Candidate-quality Boundary Decision

`h5-ah` passes as high-beta candidate-quality boundary diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_high_beta.sh
experiments/test_v05_route_quality_candidate_high_beta.sh
```

Standard sweep:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta/cap = 3.0/3.0, 4.0/4.0, 4.0/6.0, 5.0/4.0, 5.0/6.0, 5.0/8.0
```

Readout:

```text
candidate-b3p00-cap3 qacc_mean   = 0.947331
candidate-b4p00-cap4/6 qacc_mean = 0.950781
candidate-b5p00-cap4 qacc_mean   = 0.950195
candidate-b5p00-cap6/8 qacc_mean = 0.952669

candidate-b5p00-cap6/8:
  factor_max = 4.333333
  top_share = 0.656368
  entropy = 1.269519
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the high-beta sweep still does not find over-sharpen collapse. `beta=5.0`
with cap `6.0/8.0` is the best tested setting, while cap `4.0` slightly clips
the same beta. This remains bounded candidate weighting inside controlled
route-hint fixtures, not learned routing or robustness solved.

## h5-ai Extreme-beta Candidate-quality Boundary Decision

`h5-ai` passes as extreme-beta candidate-quality boundary diagnostics and
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_extreme_beta.sh
experiments/test_v05_route_quality_candidate_extreme_beta.sh
```

Standard sweep:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta/cap = 5.0/6.0, 6.0/6.0, 6.0/8.0, 6.0/12.0,
           8.0/8.0, 8.0/12.0
```

Readout:

```text
candidate-b5p00-cap6 qacc_mean       = 0.952669
candidate-b6p00-cap6/8/12 qacc_mean  = 0.956250
candidate-b8p00-cap8/12 qacc_mean    = 0.957813

candidate-b8p00-cap8/12:
  factor_max = 6.333333
  top_share = 0.689736
  entropy = 1.157891
  wrong_strength = 7.690873
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the extreme-beta sweep still does not find over-sharpen collapse. `beta=8.0`
with cap `8.0/12.0` is the best tested setting, while cap `12.0` does not
improve over cap `8.0` because the observed factor max is already `6.333333`.
Concentration and wrong hint strength rise, so this is a boundary diagnostic
and limited mitigation, not learned routing or robustness solved.

## h5-aj Ultra-beta Candidate-quality Plateau Decision

`h5-aj` passes as ultra-beta candidate-quality plateau/boundary diagnostics
and limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_ultra_beta.sh
experiments/test_v05_route_quality_candidate_ultra_beta.sh
```

Standard sweep:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta/cap = 8.0/8.0, 10.0/10.0, 10.0/12.0,
           12.0/12.0, 12.0/16.0
```

Readout:

```text
candidate-b8p00-cap8 qacc_mean       = 0.957813
candidate-b10p00-cap10/12 qacc_mean  = 0.957813
candidate-b12p00-cap12/16 qacc_mean  = 0.958008

candidate-b12p00-cap12/16:
  factor_max = 9.000000
  top_share = 0.713297
  entropy = 1.069426
  wrong_strength = 7.697217
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the ultra-beta sweep still does not find over-sharpen collapse through
`beta=12.0`, but the curve is effectively plateaued. The `beta=12.0` arm
improves aggregate qacc by only `0.000195` over `beta=8.0`, while
concentration continues to rise. This is bounded candidate-weight
plateau/boundary diagnostics, not learned routing or robustness solved.

## h5-ak Candidate-quality Guardrail Selection Decision

`h5-ak` passes as candidate-quality guardrail selection diagnostics, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_guardrail.sh
experiments/test_v05_route_quality_candidate_guardrail.sh
```

Standard guardrail:

```text
keys = 64, 128, 256
seeds = 1..5
noisy_source_rate = 0.10, 0.25, 0.50
beta/cap = 8.0/8.0, 12.0/12.0
```

Readout:

```text
candidate-b8p00-cap8:
  qacc_mean = 0.885747
  qacc_std = 0.110010
  factor_max = 6.333333
  top_share = 0.718199
  entropy = 1.064693
  wrong_strength = 5.852729

candidate-b12p00-cap12:
  qacc_mean = 0.885573
  qacc_std = 0.109432
  factor_max = 9.000000
  top_share = 0.741223
  entropy = 0.979652
  wrong_strength = 5.951053
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the 5-seed/key/noise guardrail selects `beta=8.0, cap=8.0` as the safer
bounded candidate-weight setting. It slightly beats `beta=12.0, cap=12.0` on
aggregate qacc and has lower concentration and wrong hint strength. This is a
guardrail selection result, not learned routing or robustness solved.

## h5-al Candidate-quality Safe-default Application Decision

`h5-al` passes as candidate-quality safe-default application diagnostics and
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_default.sh
experiments/test_v05_route_quality_candidate_default.sh
```

Standard comparison:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.10, 0.25, 0.50
arms = proxy-off, candidate-default, source-candidate-default
```

Readout:

```text
proxy-off qacc_mean                 = 0.646962
candidate-default qacc_mean         = 0.886429
source-candidate-default qacc_mean  = 0.884896

candidate-default:
  factor_max = 6.333333
  top_share = 0.720014
  entropy = 1.057869
  wrong_strength = 6.224125
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`route_quality_apply=candidate-weight` with `beta=8.0, cap=8.0` is the current
safe default quality-application arm. Combining source-ranking with
candidate-weight is wired, but it does not beat candidate-only in this default
check, so source-candidate is not promoted.

## h5-am Candidate-feature Basis Calibration Decision

`h5-am` passes as candidate-feature basis calibration diagnostics, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds:

```text
--route-quality-candidate-weight-basis base|quality-score
experiments/run_v05_route_quality_candidate_feature_calibration.sh
experiments/test_v05_route_quality_candidate_feature_calibration.sh
```

Standard comparison:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, feature-default, feature-value, feature-share, feature-margin
```

Readout:

```text
base-default qacc_mean     = 0.837630
feature-default qacc_mean  = 0.791146
feature-value qacc_mean    = 0.791146
feature-share qacc_mean    = 0.791276
feature-margin qacc_mean   = 0.800000

base-default:
  factor_gap = 3.154903
  factor_max = 6.333333
  quality_score_gap = 1.107729
  wrong_strength = 4.837817

feature-default:
  factor_gap = 0.608342
  factor_max = 3.574677
  wrong_strength = 4.364212
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the new `quality-score` candidate-weight basis is connected and safe, but it
does not beat the existing base-weight sharpening default. Feature-score bases
lower wrong hint strength but also reduce candidate factor separation and qacc.
Keep `candidate-weight-basis=base` as the default.

## h5-an Hybrid Candidate-basis Calibration Decision

`h5-an` passes as hybrid candidate-basis calibration diagnostics and
lower-concentration limited mitigation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
--route-quality-candidate-weight-basis base|quality-score|hybrid
--route-quality-candidate-weight-basis-mix
experiments/run_v05_route_quality_candidate_hybrid_basis.sh
experiments/test_v05_route_quality_candidate_hybrid_basis.sh
```

Standard comparison:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, feature-margin, hybrid-m0p10, hybrid-m0p25,
       hybrid-m0p50, hybrid-m0p75
```

Readout:

```text
base-default qacc_mean     = 0.837630
feature-margin qacc_mean   = 0.800000
hybrid-m0p10 qacc_mean     = 0.837500
hybrid-m0p25 qacc_mean     = 0.837760
hybrid-m0p50 qacc_mean     = 0.837630
hybrid-m0p75 qacc_mean     = 0.835938

base-default:
  factor_gap = 3.154903
  factor_max = 6.333333
  wrong_strength = 4.837817

hybrid-m0p25:
  factor_gap = 2.859539
  factor_max = 5.928332
  wrong_strength = 4.779110
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
hybrid basis can reduce candidate-weight concentration while preserving the
base qacc in this controlled sweep. The effect is small, so the safe default
remains `candidate-weight-basis=base`; `hybrid-m0p25` is a useful
lower-concentration diagnostic arm, not a robustness solution.

## h5-ao Hybrid Candidate-basis Guardrail Scale Decision

`h5-ao` passes as hybrid candidate-basis guardrail scale diagnostics and
lower-concentration limited mitigation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh
experiments/test_v05_route_quality_candidate_hybrid_guardrail.sh
```

Standard comparison:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, hybrid-m0p10, hybrid-m0p25, hybrid-m0p50
```

Readout:

```text
base-default qacc_mean   = 0.886458
hybrid-m0p10 qacc_mean   = 0.886372
hybrid-m0p25 qacc_mean   = 0.886545
hybrid-m0p50 qacc_mean   = 0.884071

base-default:
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

hybrid-m0p25:
  factor_gap = 3.247608
  factor_max = 5.968582
  wrong_strength = 6.162082
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`hybrid-m0p25` preserves qacc while reducing candidate concentration across the
guardrail scale. The effect is small, so this is not a default promotion or a
robustness solution. Keep `basis=base` as the safe default and use
`hybrid-m0p25` as a lower-concentration ablation arm.

## h5-ap Hybrid Candidate-basis Promotion Check Decision

`h5-ap` passes as hybrid candidate-basis promotion-check diagnostics and
safe-alternative instrumentation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The existing h5-ao runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --promotion
experiments/test_v05_route_quality_candidate_hybrid_promotion.sh
```

Promotion-check comparison:

```text
keys = 64, 128, 256
seeds = 1..5
noisy_source_rate = 0.10, 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, hybrid-m0p25
```

Readout:

```text
base-default qacc_mean   = 0.885747
hybrid-m0p25 qacc_mean   = 0.885747

base-default:
  factor_gap = 3.607673
  factor_max = 6.333333
  wrong_strength = 5.852729

hybrid-m0p25:
  factor_gap = 3.252903
  factor_max = 5.954676
  wrong_strength = 5.779043
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`hybrid-m0p25` is a safe lower-concentration alternative to the base default,
but the qacc result is an exact tie rather than a lift. Do not promote it as
the default yet; keep it available for concentration-aware ablations.

## h5-aq Concentration-aware Candidate-basis Switching Decision

`h5-aq` passes as concentration-aware candidate-basis switching diagnostics
and safe-alternative instrumentation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The h5-ao guardrail runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto
experiments/test_v05_route_quality_candidate_auto_basis.sh
```

The slice adds:

```text
--route-quality-candidate-weight-basis auto
--route-quality-candidate-weight-auto-factor-max
--route-quality-candidate-weight-auto-top-share
route_quality_candidate_weight_auto_hybrid_rate
```

Policy:
use the base candidate-weight basis by default, but switch a query summary to
the `hybrid-m0p25` basis when the base candidate weights are too concentrated.
This keeps the behavior on the existing value-bearing route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Reference scale check:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, hybrid-m0p25, auto-f6p0-t0p72
```

Readout:

```text
base-default qacc_mean       = 0.886458
hybrid-m0p25 qacc_mean       = 0.886545
auto-f6p0-t0p72 qacc_mean    = 0.886502

base-default:
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

hybrid-m0p25:
  factor_gap = 3.247608
  factor_max = 5.968582
  wrong_strength = 6.162082

auto-f6p0-t0p72:
  factor_gap = 3.477531
  factor_max = 5.968582
  auto_hybrid_rate = 0.440365
  wrong_strength = 6.173549
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`auto-f6p0-t0p72` is wired and safe. It preserves qacc while reducing
candidate-weight concentration and wrong hint strength relative to the base
default, but it does not beat the always-hybrid arm. The default remains
`candidate-weight-basis=base`; `auto` is a diagnostic policy arm for
concentration-aware switching and threshold tuning.

## h5-ar Auto-threshold Calibration Decision

`h5-ar` passes as auto-threshold calibration diagnostics and safe-alternative
instrumentation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The h5-ao guardrail runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-threshold
experiments/test_v05_route_quality_candidate_auto_threshold.sh
```

Reference threshold sweep:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, hybrid-m0p25,
       auto-f5p8-t0p70, auto-f6p0-t0p72,
       auto-f6p2-t0p74, auto-f6p4-t0p76
```

Readout:

```text
base-default:
  qacc = 0.886458
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

hybrid-m0p25:
  qacc = 0.886545
  factor_gap = 3.247608
  factor_max = 5.968582
  wrong_strength = 6.162082

auto-f5p8-t0p70:
  qacc = 0.886545
  auto_hybrid_rate = 1.000000

auto-f6p0-t0p72:
  qacc = 0.886502
  factor_gap = 3.477531
  factor_max = 5.968582
  auto_hybrid_rate = 0.440365
  wrong_strength = 6.173549

auto-f6p2-t0p74:
  qacc = 0.886502
  factor_gap = 3.477531
  factor_max = 5.968582
  auto_hybrid_rate = 0.440365
  wrong_strength = 6.173549

auto-f6p4-t0p76:
  qacc = 0.886632
  factor_gap = 3.602753
  factor_max = 6.333333
  auto_hybrid_rate = 0.124696
  wrong_strength = 6.208443
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`auto-f5p8-t0p70` is too broad and degenerates into always-hybrid.
`auto-f6p0-t0p72` and `auto-f6p2-t0p74` are the balanced lower-concentration
thresholds. `auto-f6p4-t0p76` is more selective and has the best tiny qacc, but
it gives up most concentration relief. Keep `basis=base` as the default and use
the auto-threshold arms as diagnostic alternatives.

## h5-as Auto-trigger Decomposition Decision

`h5-as` passes as auto-trigger decomposition diagnostics, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The auto-threshold test now emits trigger breakdown columns:

```text
route_quality_candidate_weight_auto_factor_trigger_rate
route_quality_candidate_weight_auto_top_share_trigger_rate
route_quality_candidate_weight_auto_factor_max_probe_mean
route_quality_candidate_weight_auto_top_share_probe_mean
```

These columns explain why the balanced h5-ar thresholds collapse into identical
rows and why the narrow arm becomes mostly base-like.

Reference readout:

```text
base-default:
  qacc = 0.886458
  factor_gap = 3.596599
  factor_max = 6.333333

hybrid-m0p25:
  qacc = 0.886545
  factor_gap = 3.247608
  factor_max = 5.968582

auto-f5p8-t0p70:
  qacc = 0.886545
  auto_hybrid_rate = 1.000000
  factor_trigger_rate = 0.875304
  top_share_trigger_rate = 0.684332

auto-f6p0-t0p72:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_trigger_rate = 0.315668
  top_share_trigger_rate = 0.124696

auto-f6p2-t0p74:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_trigger_rate = 0.315668
  top_share_trigger_rate = 0.124696

auto-f6p4-t0p76:
  qacc = 0.886632
  auto_hybrid_rate = 0.124696
  factor_trigger_rate = 0.000000
  top_share_trigger_rate = 0.124696
```

Interpretation:
`f6.0/t0.72` and `f6.2/t0.74` are identical because the observed trigger
distribution has no additional factor/top-share mass between those thresholds.
`f6.4/t0.76` disables the factor trigger entirely and keeps only the top-share
trigger, so it gives up most concentration relief while preserving a tiny qacc
edge. This keeps the auto arm as diagnostic instrumentation. The safe default
remains `candidate-weight-basis=base`.

## h5-at Auto-trigger Policy Ablation Decision

`h5-at` passes as auto-trigger policy ablation diagnostics, but it does not
solve learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The runner now supports:

```text
--route-quality-candidate-weight-auto-trigger-mode any|factor|top-share
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-trigger
experiments/test_v05_route_quality_candidate_auto_trigger.sh
```

`any` preserves the previous behavior. `factor` switches to the hybrid basis
only when the factor concentration trigger fires. `top-share` switches only
when the top-share concentration trigger fires.

Reference readout:

```text
base-default:
  qacc = 0.886458
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

hybrid-m0p25:
  qacc = 0.886545
  factor_gap = 3.247608
  factor_max = 5.968582
  wrong_strength = 6.162082

auto-any-f6p0-t0p72:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_trigger_rate = 0.315668
  top_share_trigger_rate = 0.124696
  factor_gap = 3.477531
  factor_max = 5.968582
  wrong_strength = 6.173549

auto-factor-f6p0:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582
  wrong_strength = 6.199233

auto-top-t0p72:
  qacc = 0.886632
  auto_hybrid_rate = 0.124696
  factor_gap = 3.602753
  factor_max = 6.333333
  wrong_strength = 6.208443

auto-any-f6p4-t0p76:
  qacc = 0.886632
  auto_hybrid_rate = 0.124696
  factor_gap = 3.602753
  factor_max = 6.333333
  wrong_strength = 6.208443
```

Interpretation:
factor-triggered switching is responsible for the useful concentration relief.
Top-share-only switching preserves the tiny qacc edge but behaves like the base
basis for factor concentration. Combined `any` remains the better balanced auto
diagnostic arm. Keep the production/default path at `candidate-weight-basis=base`;
use `hybrid-m0p25` and `auto-any-f6p0-t0p72` as safe lower-concentration
diagnostic alternatives.

## h5-au Factor-trigger Threshold Refinement Decision

`h5-au` passes as factor-trigger threshold refinement diagnostics, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-factor-threshold
experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh
```

Reference readout:

```text
base-default:
  qacc = 0.886458
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

hybrid-m0p25:
  qacc = 0.886545
  factor_gap = 3.247608
  factor_max = 5.968582
  wrong_strength = 6.162082

factor-f5p6:
  qacc = 0.886328
  auto_hybrid_rate = 0.875304
  factor_gap = 3.241454
  factor_max = 5.968582
  wrong_strength = 6.181858

factor-f5p8:
  qacc = 0.886328
  auto_hybrid_rate = 0.875304
  factor_gap = 3.241454
  factor_max = 5.968582
  wrong_strength = 6.181858

factor-f6p0:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582
  wrong_strength = 6.199233

factor-f6p2:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582
  wrong_strength = 6.199233

factor-f6p4:
  qacc = 0.886458
  auto_hybrid_rate = 0.000000
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653
```

Interpretation:
factor-only thresholds are coarse in this fixture. `5.6/5.8` are broad and
behave almost like always-hybrid for concentration. `6.0/6.2` are the balanced
factor-only thresholds. `6.4` disables factor switching and collapses to the
base default. Factor-only auto is useful for explaining concentration relief,
but it does not outperform `hybrid-m0p25` or the base default on qacc. Keep
`basis=base` as the default and treat factor-only thresholding as diagnostics.

## h5-av Candidate-basis Policy Diagnostics Decision

`h5-av` passes as candidate-basis policy diagnostics / safe-alternative
instrumentation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds a policy-summary layer on top of the existing base-vs-hybrid
promotion runner:

```text
experiments/run_v05_route_quality_candidate_basis_policy.sh
experiments/test_v05_route_quality_candidate_basis_policy.sh
```

It does not change route behavior. It reuses the existing value-bearing path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Reference smoke:

```text
key_count = 128
noisy_source_rate = 0.25

base-default:
  qacc = 0.887500
  factor_gap = 3.650981
  factor_max = 6.333333
  wrong_strength = 5.471811

hybrid-m0p25:
  qacc = 0.887500
  factor_gap = 3.304388
  factor_max = 6.049084
  wrong_strength = 5.471811

policy recommendation:
  hybrid-m0p25-safe
```

Interpretation:
in the smoke, `hybrid-m0p25` preserves qacc while lowering candidate-weight
factor concentration. This supports keeping `basis=base` as the default and
using `hybrid-m0p25` as a safe lower-concentration alternative. The new policy
CSV is diagnostic-only; it summarizes when hybrid is safe under a qacc tolerance
and lower factor concentration, rather than promoting automatic switching.

## h5-aw Candidate-basis Policy Scale Decision

`h5-aw` passes as candidate-basis policy scale diagnostics /
lower-concentration limited mitigation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The scale check reuses the full base-vs-hybrid promotion summary over:

```text
keys = 64, 128, 256
seeds = 1..5
noisy_source_rate = 0.10, 0.25, 0.50
```

It adds:

```text
experiments/test_v05_route_quality_candidate_basis_policy_scale.sh
```

Aggregate readout:

```text
rows = 9
base_qacc_mean = 0.885746
hybrid_qacc_mean = 0.885747
qacc_delta_mean = 0.000000

base_factor_gap_mean = 3.607673
hybrid_factor_gap_mean = 3.252902
factor_gap_delta_mean = -0.354770

base_wrong_strength_mean = 5.852729
hybrid_wrong_strength_mean = 5.779043
wrong_strength_delta_mean = -0.073686

hybrid_recommended_rate = 1.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
across the tested key/noise cells, `hybrid-m0p25` is qacc-neutral on average
and consistently lowers factor concentration. The policy summary recommends
`hybrid-m0p25-safe` in all nine cells. This strengthens the previous conclusion:
keep `basis=base` as the simplest default, but treat `hybrid-m0p25` as the
preferred lower-concentration alternative when factor concentration matters.
This still remains controlled route-hint fixture diagnostics, not learned
routing or robustness solved.

## h5-ax Candidate-basis Guardrail Decision

`h5-ax` passes as candidate-basis guardrail diagnostics /
safe-alternative regression protection, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/test_v05_route_quality_candidate_basis_guardrail.sh
experiments/test_v05_route_quality_candidate_basis_guardrail.sh --scale
```

The guardrail formalizes the h5-aw decision. It requires:

```text
hybrid qacc >= base qacc - 0.001
hybrid factor_gap < base factor_gap in every checked cell
hybrid factor_max <= base factor_max in every checked cell
aggregate wrong_strength_delta <= 0.001
hybrid_recommended_rate = 1.0
routing_trigger_rate = 0.0
active_jump_rate = 0.0
```

Interpretation:
`hybrid-m0p25` remains a safe lower-concentration alternative only while it
passes the qacc tolerance and concentration guardrails. This does not promote
`hybrid` as the default. The default remains `candidate-weight-basis=base`, and
the guard protects the documented safe-alternative claim from future
candidate-quality changes.

## h5-ay Candidate-weight Preset Decision

`h5-ay` passes as candidate-weight preset plumbing / usability guardrail, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds a shorthand CLI option:

```text
--route-quality-candidate-weight-preset none|base-default|hybrid-safe
```

Preset semantics:

```text
base-default:
  route_quality_apply = candidate-weight
  candidate_weight_beta = 8.0
  candidate_weight_min/max = 0.5/8.0
  candidate_weight_basis = base

hybrid-safe:
  same bounded candidate-weight setting
  candidate_weight_basis = hybrid
  candidate_weight_basis_mix = 0.25
```

The preset only configures candidate-quality weighting. It does not change the
route source, route mode, aggregation mode, fallback source, route strength, or
graph topology. Explicit CLI overrides can still be supplied after selecting a
preset.

Verification:

```text
experiments/test_v05_route_quality_candidate_preset.sh
```

Reference smoke:

```text
explicit-base:
  qacc = 0.625000
  factor_gap = 1.205750
  factor_max = 6.333333

preset-base:
  qacc = 0.625000
  factor_gap = 1.205750
  factor_max = 6.333333

explicit-hybrid:
  qacc = 0.625000
  factor_gap = 1.093769
  factor_max = 5.839506

preset-hybrid:
  qacc = 0.625000
  factor_gap = 1.093769
  factor_max = 5.839506
```

Interpretation:
the presets exactly reproduce the explicit h5-ax candidate-weight settings in
the smoke and keep `routing_trigger_rate = active_jump_rate = 0.0`. This is a
usability and regression-safety layer for the existing route-hint path, not a
new routing mechanism.

## h5-az Candidate-weight Preset Regression Matrix Decision

`h5-az` passes as candidate-weight preset adoption regression diagnostics, but
it does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_preset_regression.sh
experiments/test_v05_route_quality_candidate_preset_regression.sh
```

The runner compares explicit long-form candidate-weight settings against the
new presets over a small key/seed/noise matrix:

```text
keys = 64, 128
seeds = 1, 2
noisy_source_rate = 0.25, 0.50
basis = base, hybrid
```

Aggregate readout:

```text
rows = 16
equivalent_rate = 1.000000
qacc_delta_mean = 0.000000
factor_gap_delta_mean = 0.000000
factor_max_delta_mean = 0.000000
quality_score_gap_delta_mean = 0.000000
wrong_strength_delta_mean = 0.000000
lookup_count_mean = 96.000000
read_distance_mean = 956.410156
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
the preset interface is equivalent to explicit settings across the tested
matrix. It is now safe to use `base-default` and `hybrid-safe` presets in future
route-quality experiments without changing behavior. This remains a usability
and regression-safety finding; `base` remains the default and `hybrid-safe`
remains a guarded lower-concentration alternative.

## h5-ba Candidate-weight Preset Policy Decision

`h5-ba` passes as candidate-weight preset policy diagnostics / lower-
concentration limited mitigation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_preset_policy.sh
experiments/test_v05_route_quality_candidate_preset_policy.sh
```

Unlike h5-az, this runner does not compare explicit long-form options against
presets. It treats the presets themselves as the experiment arms:

```text
base-default
hybrid-safe
```

Standard matrix:

```text
keys = 64, 128
seeds = 1, 2
noisy_source_rate = 0.25, 0.50
```

Aggregate readout:

```text
rows = 8
base_qacc_mean = 0.863281
hybrid_qacc_mean = 0.864258
qacc_delta_mean = 0.000977
base_factor_gap_mean = 3.440251
hybrid_factor_gap_mean = 3.118539
factor_gap_delta_mean = -0.321711
base_factor_max_mean = 6.333333
hybrid_factor_max_mean = 6.049084
factor_max_delta_mean = -0.284249
wrong_strength_delta_mean = 0.000000
lookup_count_mean = 96.000000
read_distance_mean = 956.410156
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
hybrid_recommended_rate = 1.000000
```

Interpretation:
the preset interface now reproduces the h5-aw lower-concentration policy
conclusion directly. `base-default` remains the default preset, while
`hybrid-safe` remains a guarded lower-concentration alternative that lowers
factor concentration without qacc regression in the tested matrix. The live
route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

## h5-bb Candidate-weight Preset Policy Scale Guardrail Decision

`h5-bb` passes as candidate-weight preset policy scale guardrail diagnostics,
but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/test_v05_route_quality_candidate_preset_policy_scale.sh
```

The test guards the h5-ba standard matrix. It requires:

```text
summary rows = 16
policy rows = 8
base-default rows = 8
hybrid-safe rows = 8
hybrid qacc delta >= -0.001 in every policy row
hybrid factor_gap_delta < 0 in every policy row
hybrid factor_max_delta <= 0 in every policy row
aggregate wrong_strength_delta_mean <= 0.001
hybrid_recommended_rate = 1.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
h5-bb turns the h5-ba preset-only policy comparison into a reusable regression
guard. It is still a controlled candidate-weight preset guard on the
value-bearing route-hint path, not a learned routing or robustness claim.

## h5-bc Route-quality Closure Smoke Decision

`h5-bc` passes as route-quality closure instrumentation. It does not solve
learned routing, source-credit robustness, wrong-candidate robustness, fallback
robustness, or long-context retrieval.

The slice adds:

```text
experiments/test_v05_route_quality_closure.sh
```

The default closure smoke runs:

```text
bash -n experiments/*.sh
cmake --build build --target dmv02 -j2
experiments/test_v03_route_hint_oracle.sh
experiments/test_v05_route_quality_candidate_preset.sh
experiments/test_v05_route_quality_candidate_preset_policy.sh
RUN_SOURCE=0 experiments/test_v05_route_quality_candidate_preset_policy_scale.sh
```

`--extended` additionally runs:

```text
experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh
experiments/test_v05_route_quality_candidate_preset_regression.sh
RUN_SOURCE=0 experiments/test_v05_route_quality_candidate_basis_guardrail.sh --scale
```

Interpretation:
h5-bc is a release-style safety net for the current route-quality stack. It
checks that the value-bearing route-hint path remains live, candidate-weight
presets remain equivalent/policy-guarded, and jump-neighbor routing remains
inactive. It adds no new route behavior.

## h6-a Route-memory Span Boundary Decision

`h6-a` passes as route-memory span-boundary instrumentation. It does not solve
span routing, chunk routing, learned routing, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
docs/V06_ROUTE_MEMORY.md
experiments/test_v06_route_memory_span_boundary.sh
```

The fixture contains multi-byte values:

```text
@37000=HELLO;
@37001=WORLD;
?37000=HELLO.
?37001=WORLD.
```

Reference check:

```text
kv_record_count = 2
kv_query_count = 2
route_hint_query_count = 2
kv_query_hit_rate = 1.000000
route_hint_applied_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the current h5 route-memory stack is first-byte value memory. Multi-byte values
can appear in the fixture, but the active parser exposes one route hint per
key, not one route hint per value-span offset. h6 starts from this explicit
boundary and should extend span metadata without reviving jump-neighbor
replacement.

## h6-b Exact Span Parser Decision

`h6-b` passes as exact span parser instrumentation and first exact-span
mitigation. It does not solve chunk routing, learned routing, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-span-hints 0|1
experiments/test_v06_route_memory_span_exact.sh
```

Default behavior remains unchanged with `--route-span-hints 0`. When enabled
with exact KV routing:

```text
--route-mode hint-kv-exact
--route-span-hints 1
```

the parser expands each matched multi-byte value into one route hint per value
offset. On the `HELLO` / `WORLD` fixture:

```text
kv_record_count = 2
kv_query_count = 10
route_hint_query_count = 10
kv_query_hit_rate = 1.000000
route_hint_applied_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h6-b is the first span-memory mechanism, but it is still exact symbolic KV
routing. It preserves the same value-bearing path and does not revive
jump-neighbor replacement.

## h6-c Exact Span Scale Decision

`h6-c` passes as exact span scale diagnostics. It does not solve hashed span
retrieval, chunk routing, learned routing, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_exact_scale.sh
experiments/test_v06_route_memory_span_exact_scale.sh
```

The runner compares `--route-span-hints 0` against `--route-span-hints 1` over
exact symbolic KV fixtures with variable key count and value length.

Smoke readout:

```text
key_count = 2
value_len = 5
first_byte_query_count_mean = 2
span_query_count_mean = 10
span_expected_match_rate = 1.000000
span_hit_rate_mean = 1.000000
span_applied_rate_mean = 1.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Standard scale readout:

```text
rows = 8
first_byte_rows = 4
span_rows = 4
first_byte_qacc_mean = 1.000000
span_qacc_mean = 1.000000
first_byte_query_count_mean = 3.000000
span_query_count_mean = 12.000000
span_expected_match_rate = 1.000000
span_hit_rate_mean = 1.000000
span_applied_rate_mean = 1.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
the exact span parser scales beyond one fixture and keeps the same
value-bearing route-hint mechanism. This remains symbolic exact span routing,
not learned chunk retrieval.

## h6-d Span Hash Candidate Decision

`h6-d` passes as span hash candidate instrumentation and controlled symbolic
span-candidate mitigation. It does not solve chunk routing, learned routing,
source-credit robustness, wrong-candidate robustness, fallback robustness, or
long-context retrieval.

The slice adds:

```text
experiments/test_v06_route_memory_span_hash.sh
```

When `--route-mode hint-kv-hash --route-span-hints 1` is enabled, hash bucket
records retain value-span offsets and each query span offset performs a hashed
candidate lookup against matching-offset records only.

Smoke readout:

```text
kv_record_count = 2
kv_query_count = 10
route_hint_query_count = 10
route_candidate_query_count = 10
kv_query_hit_rate = 1.000000
route_hint_applied_rate = 1.000000
route_candidate_recall_rate = 1.000000
route_candidate_top1_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
span hash candidates move h6 beyond exact span lookup while preserving the
same value-bearing proposal path. The no-collision smoke verifies per-offset
candidate recall/top1, but this is still controlled symbolic span routing, not
learned chunk retrieval.

## h6-e Span Hash Scale Decision

`h6-e` passes as span hash scale diagnostics. It does not solve chunk routing,
learned routing, source-credit robustness, wrong-candidate robustness, fallback
robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_hash_scale.sh
experiments/test_v06_route_memory_span_hash_scale.sh
```

The runner scales h6-d over key count, value length, and hash-bit settings while
recording span-level candidate recall/top1, bucket load, collision rate, qacc,
and jump-neighbor inactivity.

Standard scale readout:

```text
rows = 8
qacc_mean = 1.000000
query_count_mean = 12.000000
expected_match_rate = 1.000000
hit_rate_mean = 1.000000
applied_rate_mean = 1.000000
recall_mean = 1.000000
top1_mean = 1.000000
bucket_load_mean = 1.000000
collision_rate_mean = 0.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
offset-aware hash candidates now scale over a small symbolic span matrix while
preserving the same value-bearing proposal path. This is a span-candidate scale
guard, not learned chunk retrieval.

## h6-g Learned-like Span-source Stress Decision

`h6-g` passes as learned-like span-source stress instrumentation. It does not
solve learned chunk retrieval, source-credit robustness, wrong-candidate
robustness, fallback robustness, or long-context retrieval.

The slice makes learned/source fallback route paths span-offset aware and adds:

```text
experiments/run_v06_route_memory_span_learned_source.sh
experiments/test_v06_route_memory_span_learned_source.sh
```

Reference smoke:

```text
clean-route-code-span:
  qacc = 0.987500
  span_exact = 0.937500
  route_decode = 1.000000
  recall = 1.000000
  top1 = 1.000000

weak-route-code-k4:
  qacc = 0.606250
  span_exact = 0.281250
  route_decode = 0.000000
  recall = 0.843750
  top1 = 0.250000
  route_collision = 0.750000

weak-route-code-k16:
  qacc = 0.637500
  span_exact = 0.375000
  recall = 1.000000
  top1 = 0.250000

weak-route-code-quality:
  qacc = 0.637500
  span_exact = 0.375000
  recall = 1.000000
  top1 = 0.250000
```

Interpretation:
clean route-code identity supports span-offset route hints. Weakened
route-code identity creates a learned-like span-source failure: decode
collapses, collisions appear, and top1/qacc/span exact-match degrade.
Increasing `K_route` recovers recall but not top1 or span exact-match, and the
current byte-level candidate-quality preset is neutral. This is an actionable
learned-like source split, not learned chunk retrieval solved.

## h6-h Span-level Candidate-quality Diagnostics Decision

`h6-h` passes as span-level candidate-quality diagnostics and actionable split.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_quality_diagnostics.sh
experiments/test_v06_route_memory_span_quality_diagnostics.sh
```

Reference smoke:

```text
weak-k16:
  qacc = 0.556250
  span_exact = 0.250000
  all_recall = 1.000000
  all_top1 = 0.250000

weak-quality:
  qacc = 0.556250
  span_exact = 0.250000
  all_recall = 1.000000
  all_top1 = 0.250000

weak-keyshape:
  qacc = 1.000000
  span_exact = 1.000000
  all_recall = 1.000000
  all_top1 = 1.000000
```

Interpretation:
span recall is not span quality. The weak route-code source can recover
all-span recall at larger `K_route`, but all-span top1 and span exact-match
remain low. The current byte-level candidate-quality preset is neutral, while
symbolic `key-shape` recovers the upper bound. The next step should test
learned span-level ranking/consistency features.

## h6-i Span Candidate-quality Gap Decision

`h6-i` passes as span candidate-quality gap diagnostics and actionable split.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_candidate_quality_gap.sh
experiments/test_v06_route_memory_span_candidate_quality_gap.sh
```

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  correct_key_share = 0.503125
  unique_key_count = 2.750000
  key_entropy = 1.238921
  top_key_consistency = 1.000000
  top_key_correct = 0.250000
  coherent_wrong_top_key = 0.750000

weak-base-default:
  qacc = 0.625000
  span_exact = 0.281250

weak-hybrid-safe:
  qacc = 0.368750
  span_exact = 0.250000

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
  correct_key_share = 1.000000
  key_entropy = 0.000000
```

Interpretation:
span recall is not span record quality. Under weak route-code identity, all
offsets often select a coherent but wrong key: top-key consistency stays high,
but top-key correctness is low. Existing byte-level candidate-quality presets
do not fix this, so the next route-memory work should add learned
span-record-ranking or consistency features. Symbolic key-shape remains an
upper-bound diagnostic, not learned chunk retrieval.

## h6-j Span-prefix Ranking Decision

`h6-j` passes as span-prefix ranking diagnostics and negative/limited
instrumentation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-candidate-score span-prefix
experiments/run_v06_route_memory_span_prefix_ranking.sh
experiments/test_v06_route_memory_span_prefix_ranking.sh
```

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-span-prefix:
  qacc = 0.587500
  span_exact = 0.218750
  all_recall = 1.000000
  all_top1 = 0.218750
  coherent_wrong_top_key = 0.593750

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
the visible-prefix scorer is wired and keeps route topology closed, but it is
not strong enough to replace symbolic key-shape. It reduces coherent wrong-key
selection somewhat while hurting qacc/span exact-match in this smoke. The next
span step needs a stronger learned record-ranking signal.

## h6-k Span-key-support Ranking Decision

`h6-k` passes as span-key-support ranking diagnostics and neutral
instrumentation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-candidate-score span-key-support
experiments/run_v06_route_memory_span_key_support_ranking.sh
experiments/test_v06_route_memory_span_key_support_ranking.sh
```

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-span-key-support:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
span-key-support is wired and preserves all-span recall, but it is neutral in
this smoke. A coherent wrong key can be supported across offsets just as
strongly as the correct key, so same-key support alone is not enough to replace
symbolic key-shape. The next span step needs learned record-quality evidence
that separates correct-key support from coherent wrong-key support.

## h6-l Span-local-energy Ranking Decision

`h6-l` passes as span-local-energy ranking diagnostics and limited mitigation.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
--route-candidate-score span-local-energy
experiments/run_v06_route_memory_span_local_energy_ranking.sh
experiments/test_v06_route_memory_span_local_energy_ranking.sh
```

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  correct_key_share = 0.503125
  key_entropy = 1.238921
  coherent_wrong_top_key = 0.750000

weak-span-local-energy:
  qacc = 0.675000
  span_exact = 0.406250
  all_recall = 1.000000
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081
  coherent_wrong_top_key = 0.593750

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
unlike visible-prefix and same-key-support probes, local-energy span ranking
produces a limited but real lift in the weak route-code span stress. It is
still not enough to replace symbolic key-shape, but it identifies local
dynamics compatibility as the first useful non-symbolic record-quality signal
for h6 span memory.

## h6-m Span-local-energy Scale Decision

`h6-m` passes as span-local-energy scale/stability diagnostics and limited
mitigation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_scale.sh
experiments/test_v06_route_memory_span_local_energy_scale.sh
```

Reference standard aggregate:

```text
rows = 12
groups = 4
weak_qacc_mean = 0.546094
local_energy_qacc_mean = 0.571875
keyshape_qacc_mean = 0.984375
local_energy_qacc_delta_mean = 0.025781

weak_span_exact_mean = 0.273438
local_energy_span_exact_mean = 0.378906
keyshape_span_exact_mean = 0.921875
local_energy_span_exact_delta_mean = 0.105469

weak_all_recall_mean = 0.992188
local_energy_all_recall_mean = 0.992188
weak_all_top1_mean = 0.277344
local_energy_all_top1_mean = 0.382812

weak_correct_key_share_mean = 0.492722
local_energy_correct_key_share_mean = 0.565547
weak_key_entropy_mean = 1.406354
local_energy_key_entropy_mean = 1.200587
weak_coherent_wrong_mean = 0.722656
local_energy_coherent_wrong_mean = 0.617188
```

Interpretation:
local-energy span ranking keeps the h6-l lift across a small key/seed matrix.
It improves span exact-match more than byte qacc, which is the right direction
for route-memory work. It remains a limited mitigation because symbolic
`key-shape` is still much stronger and the effect weakens as key count rises.

## h6-n Span-local-energy Composition Decision

`h6-n` passes as span-local-energy / candidate-quality composition diagnostics
and mixed limited mitigation. It does not solve learned chunk retrieval,
source-credit robustness, wrong-candidate robustness, fallback robustness, or
long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_composition.sh
experiments/test_v06_route_memory_span_local_energy_composition.sh
```

Reference smoke:

```text
weak:
  qacc = 0.625000
  span_exact = 0.281250
  all_top1 = 0.250000
  correct_key_share = 0.503125
  key_entropy = 1.238921

local-energy:
  qacc = 0.675000
  span_exact = 0.406250
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081

local-energy-base:
  qacc = 0.675000
  span_exact = 0.406250
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081

local-energy-hybrid:
  qacc = 0.631250
  span_exact = 0.593750
  all_top1 = 0.593750
  correct_key_share = 0.768229
  key_entropy = 0.510620
```

Interpretation:
`hybrid-safe` combined with local-energy ranking improves span-level record
quality but lowers byte qacc relative to local-energy alone. h6-n therefore
marks a span-objective calibration split: span exact-match and byte qacc should
be reported separately rather than compressed into a single pass/fail.

## h6-o Span-local-energy Policy Calibration Decision

`h6-o` passes as span-local-energy policy calibration diagnostics. It does not
solve learned chunk retrieval, source-credit robustness, wrong-candidate
robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_policy.sh
experiments/test_v06_route_memory_span_local_energy_policy.sh
```

Reference smoke policy:

```text
byte-qacc:
  selected = local-energy
  qacc = 0.675000
  span_exact = 0.406250

span-exact:
  selected = local-energy-hybrid
  qacc = 0.631250
  span_exact = 0.593750

balanced:
  selected = local-energy-hybrid
  qacc = 0.631250
  span_exact = 0.593750
```

Interpretation:
policy calibration makes the h6-n tradeoff explicit. A byte-qacc objective and
a span-exact objective select different local-energy policies. The span-exact
policy gains `+0.187500` span exact-match over the byte-qacc policy while
giving back `-0.043750` qacc. Future span-memory diagnostics should therefore
name which objective is being optimized.

## h6-p Span-local-energy Policy Scale Decision

`h6-p` passes as span-local-energy policy-scale diagnostics. It does not solve
learned chunk retrieval, source-credit robustness, wrong-candidate robustness,
fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_policy_scale.sh
experiments/test_v06_route_memory_span_local_energy_policy_scale.sh
```

Reference standard aggregate:

```text
rows = 20
groups = 4
objectives_differ_rate = 0.750000
qacc_policy_local_energy_rate = 1.000000
span_policy_hybrid_rate = 0.750000
balanced_policy_hybrid_rate = 0.500000

qacc_policy_qacc_mean = 0.571875
qacc_policy_span_exact_mean = 0.378906
span_policy_qacc_mean = 0.538281
span_policy_span_exact_mean = 0.441406
span_policy_qacc_delta_vs_qacc_policy_mean = -0.033594
span_policy_span_exact_delta_vs_qacc_policy_mean = 0.062500
```

Interpretation:
the h6-o policy split survives across the small key/seed matrix. It is not
absolute: one group has the same qacc/span policy, and the balanced objective
only selects hybrid in half the groups. The stable takeaway is narrower and
useful: qacc-optimized and span-optimized policy selection must be reported as
separate axes for future route-memory work.

## h6-q Span-first Guardrail Decision

`h6-q` passes as span-first policy guardrail diagnostics. It does not solve
learned chunk retrieval, learned source robustness, wrong-candidate robustness,
fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_first_guardrail.sh
experiments/test_v06_route_memory_span_first_guardrail.sh
```

Reference standard aggregate:

```text
qacc-default:
  span_accept_rate = 0.000000
  qacc_mean = 0.571875
  span_exact_mean = 0.378906

strict-g0p050-cap0p050:
  span_accept_rate = 0.250000
  selected_hybrid_rate = 0.250000
  qacc_mean = 0.560937
  span_exact_mean = 0.425781
  qacc_delta_vs_qacc_policy_mean = -0.010938
  span_exact_delta_vs_qacc_policy_mean = 0.046875

balanced-g0p025-cap0p050:
  span_accept_rate = 0.500000
  qacc_mean = 0.553125
  span_exact_mean = 0.433594

span-first-g0p025-cap0p075:
  span_accept_rate = 0.750000
  qacc_mean = 0.538281
  span_exact_mean = 0.441406
```

Interpretation:
strict span-first selection catches the high-gain span-policy cell while
rejecting the small-gain cells and the larger qacc-loss cell. This recovers
most of the span-exact improvement from h6-p with much smaller qacc loss, but
the result is still a controlled guardrail over symbolic span fixtures.

## h6-r Span-first Guardrail Degradation Decision

`h6-r` passes as span-first policy guardrail degradation diagnostics. It does
not solve learned chunk retrieval, learned source robustness,
wrong-candidate/fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_first_guardrail_degradation.sh
experiments/test_v06_route_memory_span_first_guardrail_degradation.sh
```

Reference standard aggregate:

```text
weak:
  objective_split_rate = 1.000000
  strict span_accept_rate = 0.000000
  strict qacc_mean = 0.517187
  strict span_exact_mean = 0.289062

harsher:
  objective_split_rate = 0.500000
  strict span_accept_rate = 0.000000
  span-first-g0p025-cap0p075 span_accept_rate = 0.500000
  span-first-g0p025-cap0p075 qacc_delta = -0.029688
  span-first-g0p025-cap0p075 span_delta = 0.023438
```

Interpretation:
h6-r shows fixed guardrail thresholds are regime-sensitive. Weak degradation
keeps the objective split but the qacc loss is too large for all configured
caps. Harsher degradation collapses the split in one group and allows only the
looser span-first guardrail in the other. The next policy slice should calibrate
or adapt thresholds rather than promoting a single fixed guardrail.

## h6-s Adaptive Guardrail Calibration Decision

`h6-s` passes as adaptive guardrail calibration diagnostics. It does not solve
learned chunk retrieval, learned source robustness, wrong-candidate/fallback
robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_adaptive_guardrail.sh
experiments/test_v06_route_memory_span_adaptive_guardrail.sh
```

Reference standard aggregate:

```text
weak utility-w0p50:
  span_accept_rate = 1.000000
  qacc_delta = -0.109375
  span_delta = 0.062500

weak utility-w0p75:
  span_accept_rate = 0.000000

harsher utility-w0p75:
  span_accept_rate = 0.500000
  qacc_delta = -0.029688
  span_delta = 0.023438

harsher utility-w1p00:
  span_accept_rate = 0.000000
```

Interpretation:
utility calibration separates high-loss span gains from lower-loss span gains
better than a single fixed cap in this controlled matrix. `utility-w0p50` is
too permissive; `utility-w1p00` is too conservative; `utility-w0p75` is the
current diagnostic candidate for the next scale check.

## h7-a Route-memory Goal Closure Decision

`h7-a` passes as route-memory goal closure instrumentation. It does not solve
learned sparse routing, source-credit robustness, wrong-candidate robustness,
fallback robustness, chunk-level retrieval, long-context retrieval, or
Transformer replacement.

The slice adds:

```text
experiments/test_v07_goal_route_memory_closure.sh
```

The quick closure runs shell syntax checks, the `dmv02` build, h5 route-quality
closure, and every h6 span boundary/exact/hash/ambiguity/learned-source/quality
candidate-quality-gap/prefix-ranking/key-support/local-energy/local-energy-scale/local-energy-composition/local-energy-policy/local-energy-policy-scale/span-first-guardrail/span-first-guardrail-degradation/adaptive-guardrail
smoke. The optional `--extended` mode additionally runs the extended h5 closure
plus the matching standard h6 span runners.

Interpretation:
h7 closes the current route-quality plus route-memory scaffold as a tested
research prototype boundary. The live nonlocal path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

and jump-neighbor replacement remains inactive/default-off.
