# Post-v18 Research Roadmap

This roadmap closes the current internal mechanics mode and moves the project into externally checkable evidence. The architecture should keep testing on evidence-bound local QA/audit first, because that surface exposes retrieval, prediction lineage, abstention, citations, and wrong-answer guards without requiring a broad language-generation claim.

Current boundary:

- `v17` provides the handoff package.
- `v18` provides the supplied external evidence intake verifier.
- `v19` provides the external submission bundle.
- `v20` provides the external return tracker and missing-evidence preflight.
- `v21` provides the external review dispatch kit for human reviewers and PoC owners.
- `v22` provides host/container clean-machine execution support and return templates.
- `v23` provides official benchmark reconciliation templates, no-oracle/no-extractor contracts, and preflight checks.
- `v24` provides the current send/receive/verify handoff centered on v21 + v22 outbound packets and direct v18 intake verification.
- `v25` provides the outbound send manifest and receiver acknowledgement template for the v21 + v22 packets.
- `v26` provides the single auditable external send bundle to send outward.
- `v27` provides a transfer-friendly archive of the v26 send bundle.
- `v28` provides the inbound return inbox and v18 verifier hook.
- `v29` provides the receiver-side return preflight kit before returned artifacts are verified by v18.
- `v30` provides the first commercial codebase QA closed-corpus PoC return and v18 verification path.
- `v31` provides the first official RULER NIAH candidate return and v18 verification path.
- `v32` provides the GitHub Actions clean-runner path for the remaining third-party rerun return.
- `v33` provides the frozen evidence-closure packet for the verified v32/v31/v30/v18 intake.
- `v34` provides the first official benchmark expansion packet: RULER NIAH grows from 1 to 6 raw prediction rows at the same 4096-token context length while keeping the official source/evaluator snapshot, no-oracle/no-extractor contract, and RouteMemory lineage.
- `v35` provides the first post-v30 commercial pilot packet: an `internal_docs` buyer-visible workflow using the v30 commercial-return schema, five source-cited QA rows, one release-claim abstain row, and privacy/resource/acceptance review.
- `v36` provides the release-claim audit packet over v33/v34/v35 and decides the maximum allowed public wording while blocking release-ready product and stronger model-replacement claims.
- `v37` provides the human-review intake verifier over v36: it can consume returned `human_review_rows.csv`, validate the four required review items, and set `evidence_set_human_review_accepted=1` only when the returned review passes.
- `v38` provides the human-review dispatch bundle over v37/v36: `review_packet/`, return template, verification script, dispatch manifest, and sha256 manifest for handing the evidence set to an external reviewer.
- `v39` provides the human-review dispatch archive over v38: a tar.gz archive, archive sha256 sums, file list, send README, artifact manifest, and sha256 manifest for transfer.
- `v40` provides the machine-verified research artifact over v33-v39: a bounded public/private preview track with release-mode rows, allowed/blocked claim rows, machine-verification support rows, v33-v39 evidence index, artifact manifest, and sha256 manifest. It opens `automated_research_artifact_ready=1` and `machine_verified_prototype_ready=1` only.
- `v41` provides the RULER NIAH 50-row academic scale-up over v34/v33/v18: 50 raw prediction rows, 50 RouteMemory lineage rows, fixed 4096 context length, official evaluator/source reuse, no-oracle/no-extractor status, v18 intake, and release blocking.
- `v42` provides the Codebase Auditor 200-query buyer-visible industrial demo over v18: 200 source-cited local repository QA/audit rows, 200 audit-trail rows, at least 20 unsupported-claim abstain rows, privacy/resource/acceptance review, v18 commercial-return verification, and release blocking.
- `v43` provides the Doc-Code Conflict Detection audit over v42/v18: a bounded doc-code conflict corpus, 8 detected mismatch rows, 4 preserved consistent rows, doc/implementation source-span binding, v18 commercial-return verification, and release blocking.
- `v44` provides the Tiny Non-Attention Generator Hint smoke over v43/v18: compact RouteHint payloads, zero raw prompt context bytes, zero attention/Transformer blocks, grounded answer transcripts, missing-query abstention, v18 commercial-return verification, and release blocking.
- `v45` provides the LongBench v2 small slice over v44/v18: THUDM/LongBench official source/evaluator snapshot, 6 multiple-choice raw prediction rows across 6 LongBench v2 categories, RouteMemory prediction lineage, v18 official benchmark intake verification, and release blocking.
- `v46` provides the Source-Verified Scorer mainline over v45/v18: 12 labels bound to v45 official benchmark evidence, no local teacher-harness labels, deterministic scorer model, ranking improvement, wrong-candidate guard, v18 commercial-return verification, and release blocking.
- `v47` provides the Offline Domain Policy Update over v46/v18: 15 policy rows across 3 domains and 5 learning targets, offline-only status, candidate selection/span read/hint strength/abstain-retry/verifier-decision binding, v18 commercial-return verification, and release/expert-replacement blocking.
- `v48` provides the Multi-Domain RouteHint Generator evidence run: 24 generation rows across RULER NIAH, LongBench v2, codebase QA, and internal docs QA, with RouteMemory-derived evidence, compact RouteHint, tiny non-attention generation, RouteHint-to-domain-sentence transformation, grounded answer, citation, abstain, audit trail, v18 commercial-return verification, and release blocking.
- `v49` provides the fixed-context RULER NIAH 200/500-row scale-up over v34/v33/v18: 200 and 500 raw prediction rows, matching RouteMemory lineage rows, fixed 4096 context length, fixed architecture/evaluator path, official source/evaluator reuse, no-oracle/no-extractor status, v18 intake, and release blocking.
- `v50` provides the Public Repo Auditor 3-repo evidence run over v42/v43/v18: pinned public repo snapshots for `pypa/sampleproject`, `psf/requests`, and `pallets/click`, 9 audit cases across doc-code conflict, deprecated/legacy usage, and config mismatch, independent detector outputs, source-span binding, guard negative controls, v18 commercial-return verification, and release/upstream-defect claim blocking.
- `v51` provides the Real-return Evidence Intake measured trace over v18/v40: runner-measured CPU SHA-256 batch work and filesystem/NVMe-style read traces over tracked repository source files, three cited QA/audit rows through v18, v40 evidence-ladder binding, explicit no external/buyer return, explicit no real teacher-source import candidate, GPU speedup claim deferral, and release blocking.
- `v0.3 Architecture Preview` provides the first clone-and-run user surface over the existing evidence stack: `scripts/audit_my_repo.sh`, `scripts/run_local_scaling_matrix.sh`, `scripts/run_routehint_generator_mainline.sh`, `examples/local_codebase_intelligence_box.sh`, and `experiments/test_v0_3_architecture_preview.sh` emit a source-bound Markdown audit report, JSONL/CSV machine artifacts, local scaling matrix curves, compact RouteHint rows, grounded generation rows, citations, abstentions, 8-way baseline comparison binding, architecture trace, reproduce script, and sha256 manifest.
- Current verified state after PR run `27029089994` plus v33-v51 and v0.3 preview: `v0_3_architecture_preview_ready=1`, `one_command_repo_audit_ready=1`, `local_scaling_matrix_ready=1`, `scaling_axis_count=5`, `scaling_curve_rows=27`, `baseline_war_ready=1`, `baseline_rows=8`, `routehint_generator_mainline_ready=1`, `local_codebase_intelligence_box_ready=1`, `raw_prompt_context_bytes=0`, `attention_blocks=0`, `transformer_blocks=0`, `oracle_prediction_used=0`, `raw_input_extractor_used=0`, `v51_real_return_evidence_intake_ready=1`, `measured_workload_trace_bound=1`, `real_return_evidence_axis_count=1`, `cpu_trace_rows=7`, `nvme_trace_rows=7`, `non_fixture_workload_trace_rows=1`, `v50_public_repo_auditor_3repo_ready=1`, `v49_ruler_niah_200_500_scale_ready=1`, `v48_multi_domain_generator_evidence_ready=1`, `v47_offline_domain_policy_update_ready=1`, `v46_source_verified_scorer_mainline_ready=1`, `v45_longbench_v2_small_slice_ready=1`, `v44_tiny_non_attention_generator_hint_ready=1`, `v43_doc_code_conflict_detection_ready=1`, `v42_codebase_auditor_200query_ready=1`, `v41_ruler_niah_50row_scale_ready=1`, `v40_machine_verified_research_artifact_ready=1`, `real_external_benchmark_verified=1`, `v18_closed_corpus_poc_actual_ready=1`, `machine_verification_ready=1`, `automated_research_artifact_ready=1`, `machine_verified_prototype_ready=1`, `public_repo_refs_pinned=1`, `public_repo_detected_doc_code_conflict_rows=1`, `public_repo_detected_config_mismatch_rows=1`, `hint_value_transformed_rows=20`, `answer_equals_hint_value_rows=0`, `raw_span_text_copied_rows=0`, `guard_negative_block_rows=3`, `no_raw_prompt_stuffing_ready=1`, `non_attention_generator_ready=1`, `privacy_review_ready=1`, and `resource_envelope_ready=1`, but `external_or_buyer_return_supplied=0`, `real_teacher_source_import_candidate_supplied=0`, `human_review_return_supplied=0`, `human_review_completed=0`, `human_review_required_for_public_release=1`, `gpu_speedup_claim=deferred`, and `real_release_package_ready=0` remain blocked until external acceptance/review and teacher-source authority evidence are supplied.

## Current Handoff

Send:

- `results/v21_external_review_dispatch_kit/dispatch_001/`
- `results/v22_clean_machine_execution_kit/kit_001/`

Receive one or more:

- third-party rerun return directory
- official benchmark return directory
- commercial closed-corpus PoC return directory

Verify directly with v18:

```bash
V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return \
V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return \
V18_COMMERCIAL_POC_DIR=/path/to/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Operational packet:

- `results/v24_external_handoff_send_receive_verify/handoff_001/`

Outbound send manifest:

- `results/v25_outbound_send_manifest/packet_001/outbound/OUTBOUND_FILE_MANIFEST.csv`
- `results/v25_outbound_send_manifest/packet_001/outbound/OUTBOUND_SHA256SUMS.txt`
- `results/v25_outbound_send_manifest/packet_001/receiver/RECEIVER_ACK_TEMPLATE.csv`

Single send bundle:

- `results/v26_external_send_bundle/bundle_001/`

Transfer archive:

- `results/v27_external_send_archive/archive_001/archive/v26_external_send_bundle_bundle_001.tar.gz`
- `results/v27_external_send_archive/archive_001/archive/ARCHIVE_SHA256SUMS.txt`

Inbound return inbox:

- `results/v28_inbound_return_inbox/inbox_001/returns/third_party_return/`
- `results/v28_inbound_return_inbox/inbox_001/returns/official_return/`
- `results/v28_inbound_return_inbox/inbox_001/returns/commercial_return/`

Receiver preflight:

- `results/v29_receiver_return_preflight/preflight_001/receiver/RECEIVER_RETURN_PREFLIGHT.md`
- `results/v29_receiver_return_preflight/preflight_001/receiver/preflight_rows.csv`
- `results/v29_receiver_return_preflight/preflight_001/receiver/missing_file_rows.csv`
- `results/v29_receiver_return_preflight/preflight_001/verify/VERIFY_AFTER_PREFLIGHT.md`

Commercial codebase QA PoC return:

- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/query_set.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/poc_result_rows.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/privacy_review.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/acceptance_review.csv`

Official RULER NIAH candidate return:

- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_source_snapshot.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_evaluator_status.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/raw_predictions.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/prediction_lineage.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/candidate_result_rows.csv`

GitHub Actions third-party rerun kit:

- `.github/workflows/third-party-rerun.yml`
- `results/v32_github_actions_third_party_rerun_kit/kit_001/GITHUB_ACTIONS_THIRD_PARTY_RERUN.md`
- `results/v32_github_actions_third_party_rerun_kit/kit_001/workflow/third-party-rerun.yml`

Receiver-side custom check:

```bash
V29_THIRD_PARTY_RETURN_DIR=/path/to/third_party_return \
V29_OFFICIAL_RETURN_DIR=/path/to/official_return \
V29_COMMERCIAL_RETURN_DIR=/path/to/commercial_return \
experiments/run_v29_receiver_return_preflight.sh
```

Commercial v30 verification:

```bash
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Official v31 plus commercial v30 verification:

```bash
V18_OFFICIAL_BENCHMARK_DIR=results/v31_official_ruler_niah_candidate_return/return_001/official_return \
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

GitHub Actions third-party rerun:

```bash
gh workflow run third-party-rerun.yml -f return_id=github_actions_return_001
gh run list --workflow third-party-rerun.yml --limit 1
gh run watch
mkdir -p results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
gh run download --name third-party-rerun-return --dir results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
```

PR-based GitHub Actions rerun:

```bash
gh pr create --base main --head codex/route-memory-local-energy-policy --draft
gh run list --branch codex/route-memory-local-energy-policy --limit 5
gh run watch
gh run download --name third-party-rerun-return --dir results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
```

GitHub Actions return verification:

```bash
V18_THIRD_PARTY_RERUN_DIR=results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded_run_27029089994/github_actions_third_party_rerun/github_actions_return_27029089994/third_party_return \
V18_OFFICIAL_BENCHMARK_DIR=results/v31_official_ruler_niah_candidate_return/return_001/official_return \
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Verified v18 summary:

```csv
intake_id,third_party_rerun_supplied,independent_rerun_actual_ready,official_benchmark_supplied,candidate_external_benchmark_result_ready,commercial_poc_supplied,closed_corpus_poc_actual_ready,real_external_benchmark_verified,real_release_package_ready,artifact_rows
intake_001,1,1,1,1,1,1,1,0,27
```

## After Current Mode Closes

Mode-closure result:

- The v32 workflow has been committed, pushed, run on GitHub Actions PR run `27029089994`, and its uploaded third-party rerun return artifact has been downloaded.
- v18 has been run with all three current evidence directories: v32 third-party rerun, v31 official RULER candidate, and v30 commercial codebase QA PoC.
- The verified closure flags are `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `closed_corpus_poc_actual_ready=1`, and therefore `real_external_benchmark_verified=1`.
- v33 has frozen those evidence directories into `results/v33_evidence_closure_packet/packet_001/` with v18 summary/decision rows, copied evidence returns, `sha256_manifest.csv`, `CLAIM_BOUNDARY.md`, and a human-review request.
- v34 has expanded the official benchmark slice into `results/v34_official_benchmark_expansion_packet/packet_001/`, with 6 RULER NIAH raw prediction rows, official evaluator/source hashes, RouteMemory lineage, v18 re-verification, `EXPANSION_BOUNDARY.md`, and `sha256_manifest.csv`.
- v35 has expanded the commercial PoC track into `results/v35_commercial_pilot_packet/packet_001/`, with an `internal_docs` commercial pilot packet for one buyer-visible workflow, five source-cited rows, one abstain row, privacy/resource/acceptance review, v18 re-verification, `COMMERCIAL_PILOT_BOUNDARY.md`, and `sha256_manifest.csv`.
- v36 has audited the release claim boundary in `results/v36_release_claim_audit_packet/packet_001/`, with `claim_matrix.csv`, `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`, `human_review/HUMAN_REVIEW_REQUEST.md`, `human_review/human_review_template.csv`, and `sha256_manifest.csv`. It allows only the bounded local evidence-bound QA/audit wording and blocks release-ready product, general LLM replacement, Transformer replacement, frontier long-context solved, GPU acceleration, and full commercial deployment readiness.
- v37 has added `results/v37_human_review_intake/intake_001/` as the review-return intake verifier. It is ready to consume `results/v36_release_claim_audit_packet/packet_001/human_review/human_review_rows.csv`, but the current default run has no returned review rows.
- v38 has added `results/v38_human_review_dispatch_bundle/bundle_001/` as the review dispatch bundle. Send `review_packet/` to the reviewer, have the reviewer fill `return/human_review_rows.csv`, and verify with `verify/VERIFY_RETURN.sh`.
- v39 has added `results/v39_human_review_dispatch_archive/archive_001/` as the transfer archive. Send `archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz` with `ARCHIVE_SHA256SUMS.txt` and `ARCHIVE_FILE_LIST.txt`.
- v40 has added `results/v40_machine_verified_research_artifact/artifact_001/` as the machine-verified research artifact. It can be shared as an automated evidence artifact with the notice: "This artifact is machine-verified and externally reproducible through the v18 evidence-intake path, but it is not a human-reviewed release package." Its `machine_verification_rows.csv` binds the allowed support set to clean-runner rerun evidence, v18 intake verification, RouteMemory prediction lineage, no-oracle/no-extractor status, and closed-corpus PoC preview evidence.
- v41 has added `results/v41_ruler_niah_50row_scale/scale_001/` as the first academic scale-up. It preserves official-evaluator, no-oracle RouteMemory lineage through 50 rows at the same 4096 context length.
- v42 has added `results/v42_codebase_auditor_200query/audit_001/` as the first 200-query buyer-visible codebase auditor demo. It preserves source citations, abstention, wrong-answer guard, audit trail binding, privacy/resource/acceptance review, and v18 commercial-return verification.
- v43 has added `results/v43_doc_code_conflict_detection/detection_001/` as the first doc-code conflict detection audit. It finds bounded documentation/implementation mismatches with supporting source spans, while preserving consistent cases and v18 commercial-return verification.
- v44 has added `results/v44_tiny_non_attention_generator_hint/generator_001/` as the first tiny non-attention RouteHint generator smoke. It generates grounded answers from compact RouteHint payloads without appending retrieved text as raw prompt context.
- v45 has added `results/v45_longbench_v2_small_slice/slice_001/` as the first LongBench v2 small-slice official benchmark family expansion. It snapshots THUDM/LongBench source/evaluator files and verifies 6 lineage-bound multiple-choice rows through v18.
- v46 has added `results/v46_source_verified_scorer_mainline/scorer_001/` as the source-verified scorer mainline smoke. It verifies candidate ranking from source-bound labels rather than local teacher-harness fixture labels.
- v47 has added `results/v47_offline_domain_policy_update/policy_001/` as the offline domain policy update. It binds candidate selection, span read, hint strength, abstain/retry, and verifier-decision policy rows across codebase QA, LongBench v2, and source-verified scorer domains.
- v48 has added `results/v48_multi_domain_generator_evidence/run_001/` as the first post-v47 evidence-scale generator run. It verifies the same RouteHint generation path across RULER, LongBench, codebase QA, and internal docs QA, including answer-row transformation without raw-span copying or direct hint-value echo.
- v49 has added `results/v49_ruler_niah_200_500_scale/scale_001/` as the fixed-context RULER NIAH 200/500-row scale run. It verifies the v34 official expansion engine at 200 and 500 rows with the same 4096 context length, RouteMemory lineage, no-oracle/no-extractor status, and v18 intake.
- v50 has added `results/v50_public_repo_auditor_3repo/audit_001/` as the public repo auditor evidence run. It verifies pinned public repo snapshots across 3 repositories, 3 audit types, independent detector outputs, and guard negative controls.
- v51 has added `results/v51_real_return_evidence_intake/intake_001/` as the measured workload trace evidence run. It binds runner-measured CPU and filesystem/NVMe-style traces into the v18/v40 evidence ladder while keeping external/buyer return, teacher-source import, GPU speedup, human review, and release readiness blocked.
- `real_release_package_ready` remains 0 until external human review accepts the evidence set and any required non-GitHub rerun is completed. Do not promote release language inside the v36 audit step.

Do not keep adding internal packaging layers after v40 unless a real return exposes a concrete verifier gap. The next roadmap should move from mechanics to evidence scale:

- Week 0: done. The current v14-v32 scripts, docs, and `.github/workflows/third-party-rerun.yml` are on the PR branch; GitHub Actions PR run `27029089994` returned the artifact; local v18 verified it together with v31 and v30.
- Week 1: done. `v33` freezes the v18 summary, decision rows, copied third-party return, official candidate return, commercial PoC return, sha256 manifest, and a plain-language claim boundary.
- Week 1-2: run one independent human-review pass over the `v33` packet. The reviewer should check that the GitHub-hosted runner identity is acceptable as third-party/clean-machine evidence or require a non-GitHub human reviewer rerun.
- Week 2-3: done. `v34` expands the v31 official benchmark slice only one axis at a time: more RULER NIAH rows at the same context length before adding LongBench v2 or another task family.
- Week 3-4: done. `v35` runs a second closed-corpus PoC in internal documentation. It keeps the same v30 schema: source spans, citations, abstentions, wrong-answer guard, privacy review, and acceptance review.
- Month 2: done. `v34` builds the official benchmark expansion packet with raw predictions, official evaluator hash, source snapshot, RouteMemory lineage, and metrics for a larger RULER NIAH slice.
- Month 2: done. `v35` builds a commercial pilot packet for one buyer-visible workflow: internal documentation QA. Do not mix all three in one pilot.
- Month 3: done. `v36` builds a release-claim audit packet that consumes v33/v34/v35 and explicitly decides the maximum allowed public claim. Expected claim shape: local evidence-bound QA/audit architecture with deterministic provenance and conservative abstention.
- Month 3: done. `v37` builds the human-review intake verifier for returned `human_review_rows.csv`.
- Month 3: done. `v38` builds the human-review dispatch bundle for the v33/v34/v35/v36 evidence set.
- Month 3: done. `v39` builds the transfer archive for the v38 human-review dispatch bundle.
- Month 3: done. `v40` builds a machine-verified research artifact above v36-v39. It permits bounded public/private preview wording but keeps human-reviewed release and real release package readiness blocked.
- Month 3: done. `v41` builds the RULER NIAH 50-row scale at fixed 4096 context length with official evaluator/source reuse, no-oracle/no-extractor rows, RouteMemory lineage, and v18 verification.
- Month 3: done. `v42` builds the Codebase Auditor 200-query industrial demo with source citations, abstentions, wrong-answer guard, audit trail, privacy/resource/acceptance review, and v18 commercial-return verification.
- Month 3: done. `v43` builds the Doc-Code Conflict Detection audit with 8 bounded mismatch rows, 4 consistent rows, source-span binding, wrong-answer guard, and v18 commercial-return verification.
- Month 3: done. `v44` builds the Tiny Non-Attention Generator Hint smoke with compact RouteHint payloads, zero raw prompt context bytes, grounded answers, missing-query abstention, and v18 commercial-return verification.
- Month 3: done. `v45` builds the LongBench v2 small slice with official source/evaluator snapshot, 6 task categories, RouteMemory lineage, no-oracle/no-extractor status, and v18 official intake verification.
- Month 3: done. `v46` builds the source-verified scorer mainline with v45-bound labels, no local teacher-harness labels, scorer improvement, wrong-candidate guard, and v18 commercial-return verification.
- Month 3: done. `v47` builds the offline domain policy update with 3 domains, 5 learning targets, offline-only policy rows, and expert/release replacement claims blocked.
- Month 3: done. `v48` expands the tiny non-attention generator from smoke to multi-domain answer generation evidence across RULER, LongBench, codebase QA, and internal docs QA, with RouteHint transformation checks.
- Month 3: done. `v49` expands RULER NIAH from the 50-row scale to 200/500 rows at fixed 4096 context length and fixed architecture/evaluator path.
- Month 3: done. `v50` expands the Codebase Auditor from local repository evidence to 3 pinned public repositories with doc-code conflict, deprecated/legacy usage, config mismatch, source citation, audit trail, and guard negative controls.
- Month 3: done. `v51` binds a measured CPU/NVMe-style workload trace into the v18/v40 ladder without opening release-ready or GPU-speedup wording.
- The v41-v51 impact roadmap is closed. Do not add another internal packaging layer unless a real return exposes a verifier gap; the next work should collect external acceptance/teacher-source authority evidence, with human review deferred until release-ready wording becomes necessary.

Expansion discipline:

- Expand only one axis per experiment: more queries, another benchmark family, another domain, another reviewer, or a stricter privacy/audit requirement.
- Keep architecture changes out of benchmark-expansion runs. If the architecture changes, re-run the smallest v31/v30/v32-equivalent closure first.
- Keep all raw predictions and evidence rows before evaluation. No oracle, no raw-input extractor, and no post-hoc answer repair.
- Treat negative and abstain rows as first-class evidence. A pass is not only high answer accuracy; it is also correct refusal when the source does not support an answer.

Post-v40 impact roadmap:

- `v41` RULER NIAH 50-row scale. Done. Goal: first academic scale-up. Success message: official-evaluator, no-oracle RouteMemory lineage is preserved through 50 rows at the same 4096 context length.
- `v42` Codebase Auditor 200-query. Done. Goal: first buyer-visible industrial demo. Success message: local-repository codebase QA works with citations, abstentions, and audit trail.
- `v43` Doc-Code Conflict Detection. Done. Goal: prove audit behavior beyond ordinary QA. Success message: documentation/code mismatches are found with supporting source spans.
- `v44` Tiny Non-Attention Generator Hint. Done. Goal: a small non-attention generator actually uses RouteHint. Success message: grounded answers are generated from proposal hints without appending retrieved text as raw prompt context.
- `v45` LongBench v2 small slice. Done. Goal: expand beyond the RULER benchmark family. Success message: the lineage-bound path applies to another long-document QA family, not only RULER synthetic evidence.
- `v46` Source-Verified Scorer mainline. Done. Goal: promote candidate ranking beyond the local teacher harness. Success message: candidate ranking is trained and verified from source-verified labels rather than fixture labels.
- `v47` Offline domain policy update. Done. Goal: start domain-specialized assistant behavior. Learning targets: candidate selection, span read, hint strength, abstain/retry, and verifier decision. Keep the claim as expert assistance and audit assistance, not expert replacement.
- `v48` Multi-Domain RouteHint Generator evidence. Done. Goal: expand v44 from smoke to multi-domain answer generation. Success message: RouteMemory evidence, compact RouteHint, tiny non-attention generator, RouteHint-to-domain-sentence transformation, grounded answer, citation, abstain, and audit trail hold across RULER, LongBench, codebase QA, and internal docs QA.
- `v49` RULER NIAH 200/500-row scale. Done. Goal: close the next academic scale axis at fixed context and architecture. Success message: official-evaluator, no-oracle RouteMemory lineage is preserved through both 200 and 500 rows at the same 4096 context length.
- `v50` Public Repo Auditor 3 repositories. Done. Goal: move the Codebase Auditor from local repository evidence into actual public repositories. Success message: doc-code conflict, deprecated/legacy usage, and config mismatch detection hold across 3 pinned public repos with source citations, abstentions, wrong-answer guard, guard negative controls, independent detector outputs, and audit trail.
- `v51` Real-return evidence intake. Done. Goal: replace more supplied/mechanical confidence with actual measured evidence. Success message: a runner-measured CPU/NVMe-style workload trace is bound into the v18/v40 evidence ladder without opening release-ready wording.
- `v52` 30B/70B/100B+ LLM+RAG baseline war. Next. Goal: begin the v1.0 Architecture Challenge by comparing A-H systems on the same code/doc QA source corpus, query set, citation verifier, abstention rules, wrong-answer guard, resource envelope, and sha256-bound artifacts. Success message: 30B and 70B LLM+RAG baselines are real rows, 100B+ is ready or explicitly deferred with reason, RouteMemory + RouteHint and RouteMemory + RouteHint + scorer/policy are evaluated symmetrically, and comparison claims remain blocked until the full v52-v60 challenge gates pass.
- `v52` contract scaffold. Started. `experiments/test_v52_llm_rag_baseline_war.sh` now emits the A-H baseline registry and symmetric evaluation contract while intentionally keeping `v52_ready=0`, `required_30b_baseline_ready=0`, and `required_70b_baseline_ready=0`.
- `v52b` small local RAG measured row. Started. `experiments/test_v52b_small_local_rag_measured_row.sh` now emits the first measured system-B answer/citation/retrieval/resource rows over the v50 public-repo seed and marks them `v52_absorb_ready=1`, while intentionally keeping full `v52_ready=0` and the 30B/70B baseline blockers in force.
- `v52f` small local RAG measured 100-row expansion. Started. `experiments/test_v52f_small_local_rag_measured_100.sh` now emits 100 system-B answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, source manifest rows, 300 retrieval rows, copied v53d frozen-query evidence, and hash manifests while intentionally keeping full `v52_ready=0` until A/G/H share the same query IDs/source manifest and real C/D/E evidence directories validate.
- `v52g` small local RAG measured 300-row expansion. Started. `experiments/test_v52g_small_local_rag_measured_300.sh` now emits a stratified 300-row system-B measured subset over v53e, including answer/citation/abstain/wrong-answer/resource rows, 900 retrieval rows, 48 negative/abstain query rows, source manifest rows, copied v53e evidence, and hash manifests. At the v52g layer, B-1000, A/G/H same-query-set rows, C/D/E evidence, full `v52_ready`, and release claims remained blocked.
- `v52h` small local RAG measured 1000-row expansion. Started. `experiments/test_v52h_small_local_rag_measured_1000.sh` now emits the full v53e 1000-query system-B measured set, including answer/citation/abstain/wrong-answer/resource rows, 3000 retrieval rows, 160 negative/abstain query rows, source manifest rows, copied v53e evidence, and hash manifests. This closes the B 9->100->300->1000 measured ladder while intentionally keeping A/G/H same-query-set rows, C/D/E evidence, full `v52_ready`, and release claims blocked.
- `v52i` A/B/G/H same-query measured 1000-row packet. Started. `experiments/test_v52i_abgh_same_query_measured_1000.sh` now emits A/B/G/H over the same full frozen v53e query set and source manifest, including 4000 answer/citation/abstain/wrong-answer/resource rows, 12000 retrieval rows, 2000 G/H RouteHint rows, per-system metrics, copied v53e evidence, and hash manifests. This closes the local A/B/G/H same-query packet while intentionally keeping C/D/E evidence, required 30B/70B baselines, full `v52_ready`, and release claims blocked.
- `v52j` measured registry absorb. Started. `experiments/test_v52j_measured_registry_absorb.sh` now absorbs the v52i A/B/G/H measured packet into a v52 measured baseline registry, marks A/B/G/H as measured over the shared v53e query/source manifest, and keeps C/D/E evidence directories, optional F, full `v52_ready`, and release claims blocked.
- `v52c` 7B-14B local model + RAG evidence intake. Started. `experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh` now emits the system-C evidence schema, answer template, model identity template, validation rows, and stop-rule boundary while intentionally keeping `supplied_evidence_ready=0` and `v52_absorb_ready=0` until a real local model evidence directory is supplied and validates.
- `v52k` 7B-14B local model + RAG measured seed. Started. `experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh` now runs local Ollama `qwen2.5:7b-instruct` over the v50 9-query seed, writes real C answer/citation/resource rows, validates them through v52c with `supplied_evidence_ready=1`, and keeps full C scale, D/E evidence, full v52, and release claims blocked.
- `v52l` 7B-14B local model + RAG v53e 1000-row expansion. Started. `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh` now runs local Ollama `qwen2.5:7b-instruct` over the same frozen v53e 1000-query/source manifest used by v52i A/B/G/H, writes real C answer/citation/retrieval/abstain/wrong-answer/resource/transcript rows, and marks `c_v53e_absorb_ready=1`. It records 0/1000 strict exact-label accuracy, so the current value is row-backed C evidence and schema pressure, not a C performance claim; D/E evidence, full v52, and release claims remain blocked.
- `v52m` measured registry C absorb. Started. `experiments/test_v52m_measured_registry_c_absorb.sh` now absorbs the v52l C measured packet into the v52 measured registry alongside A/B/G/H, records 5000 answer/citation/abstain/guard/resource rows, sets `required_7b14b_baseline_ready=1`, and keeps D/E evidence, `v52_ready=0`, and release/comparison claims blocked.
- `v52n` 30B open-weight LLM+RAG measured seed. Started. `experiments/test_v52n_30b_open_weight_llm_rag_measured_seed.sh` runs local Ollama `qwen2.5:32b-instruct` over the v50 9-query seed, validates through v52d with `d_30b_supplied_evidence_ready=1`, and keeps full D scale, E 70B rows, full v52, and release claims blocked.
- `v52o` 70B open-weight LLM+RAG measured seed. Started. `experiments/test_v52o_70b_open_weight_llm_rag_measured_seed.sh` runs local Ollama `llama3.1:70b-instruct-q2_K` over the v50 9-query seed, validates through v52d with `e_70b_supplied_evidence_ready=1`, and keeps full E scale, D 30B real row, full v52, and release claims blocked.
- `v52p` 30B open-weight LLM+RAG v53e 1000-row expansion. Started. `experiments/test_v52p_30b_open_weight_llm_rag_v53e_1000.sh` runs local Ollama `qwen2.5:32b-instruct` over the same frozen v53e manifest as v52i A/B/G/H, marks `d_v53e_absorb_ready=1`, and keeps E, full v52, and release claims blocked.
- `v52q` 70B open-weight LLM+RAG v53e 1000-row expansion. Started. `experiments/test_v52q_70b_open_weight_llm_rag_v53e_1000.sh` runs local Ollama `llama3.1:70b-instruct-q2_K` over the same frozen v53e manifest, marks `e_v53e_absorb_ready=1`, and keeps D, full v52, and release claims blocked.
- `v52r` measured registry D/E absorb. Started. `experiments/test_v52r_measured_registry_de_absorb.sh` absorbs v52l C plus v52p D and v52q E into the v52 measured registry alongside A/B/G/H, records 7000 answer/citation/abstain/guard/resource rows, sets `required_30b_baseline_ready=1` and `required_70b_baseline_ready=1`, and keeps optional F, `v52_ready=0`, and release/comparison claims blocked.
- `v52y` F optional final policy. Started. `experiments/test_v52y_f_optional_final_policy.sh` records F as `deferred-with-reason-final` when no supplied 100B+ evidence is present, verifies the v52-ready condition matrix after v52r, sets `v52_ready=1` only for the measured-baseline-registry scope, and allows 30B-150B-class wording only with explicit F-final-disposition disclosure while keeping measured 100B+/150B result, v53 complete-source audit, v1.0 comparison, and release claims blocked.
- `v52s` local LLM weight tier contract. Started. `experiments/test_v52s_local_llm_weight_tier_contract.sh` emits an NVMe-mmap hot/warm/cold weight shard store contract aligned with h11-c, marks `nvme_mmap_store_ready=1`, and keeps tiered decode runtime, monolithic Ollama 30B/70B local measured rows, and release claims blocked.
- `v52v` local LLM weight tier ROCm decode bind. Started. `experiments/test_v52v_local_llm_weight_tier_rocm_decode_bind.sh` compiles a HIP axpy probe on gfx1030, binds v52u hot-tier decode rows, marks `rocm_kernel_bind_ready=1`, and keeps full tiered LLM decode runtime, D/E measured rows, and release claims blocked.
- `v52t` D/E local measured deferral. Started. `experiments/test_v52t_de_local_measured_deferral.sh` records explicit `deferred-with-reason` for local monolithic D/E measured rows on 16GB VRAM hosts after aborting v52n, links v52s/v52u/v52v, and keeps required 30B/70B baselines, `v52_ready=0`, and release claims blocked.
- `v52u` local LLM weight tier mmap reader. Started. `experiments/test_v52u_local_llm_weight_tier_mmap_reader.sh` mmap-reads the v52s hot/warm/cold shard store with hash verification and warm-prefetch scaffold rows, marks `weight_tier_mmap_reader_ready=1`, and keeps ROCm decode binding, D/E measured rows, and release claims blocked.
- `v52d` 30B/70B open-weight LLM+RAG evidence intake. Started. `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh` now emits the system-D/E evidence schemas, answer templates, model identity templates, validation rows, and stop-rule boundary while intentionally keeping `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `v52_absorb_ready=0` until both real evidence directories validate.
- `v52e` 100B+ hosted/API LLM+RAG optional intake. Started. `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh` now emits the system-F evidence schema, answer template, hosted/API identity template, validation rows, and stop-rule boundary while intentionally keeping `optional_100b_plus_baseline_status=deferred-with-reason`; F remains optional and cannot replace required D/E rows.
- `v53` contract scaffold. Started. `experiments/test_v53_public_repo_code_doc_audit.sh` now emits the 10-repo / 1000-query scale contract from the v50 3-repo seed while intentionally keeping `v53_ready=0`, `missing_repo_count=7`, and `missing_query_rows=991`.
- `v53b` public repo 10-lock. Started. `experiments/test_v53b_public_repo_10_lock.sh` now resolves live HEAD SHAs for 10 public GitHub repositories and writes the repo lock plus 1000-row query plan, while intentionally keeping `v53_ready=0` until source snapshots, source-span-bound query rows, answers, citations, negative/abstain rows, and review artifacts exist.
- `v53c` public repo canary source snapshot. Started. `experiments/test_v53c_public_repo_canary_source_snapshot.sh` now fetches pinned canary source/doc/config files from all 10 locked repos and records sha256 content rows, while intentionally keeping `v53_ready=0`, `full_source_snapshot_missing_repo_count=7`, and `missing_query_rows=991`.
- `v53d` canary source query seed 100. Started. `experiments/test_v53d_canary_source_query_seed_100.sh` now emits 100 source-span-bound canary query rows across the 10 locked repos, while intentionally keeping `v53_ready=0`, `missing_query_rows=900`, negative/abstain families blocked, and A-H answer/citation/resource rows blocked.
- `v53e` canary query scale 1000. Started. `experiments/test_v53e_canary_query_scale_1000.sh` now emits 1000 canary-scope source-span-bound query rows across the 10 locked repos, including 840 supported rows, 160 negative/abstain rows, and eight query families, while intentionally keeping `v53_ready=0` until complete source snapshots, A-H answer/citation/resource rows, symmetric scorer/policy rows, and review artifacts exist.
- `v53f` A-H answer/citation/resource intake. Started. `experiments/test_v53f_ah_answer_citation_resource_intake.sh` now emits the A-H system target matrix and 8000 answer/resource template rows over the frozen v53e query set, while intentionally keeping `v53_ready=0`, `valid_answer_rows=0`, citation/resource coverage blocked, and review artifacts blocked until real supplied comparison rows exist.
- `v53g` complete source manifest. Started. `experiments/test_v53g_complete_source_manifest.sh` now binds the 10 locked repos to recursive Git tree source/doc/config/test manifests, records 11318 metadata-only manifest rows, 11312 query-eligible rows, at least 20 canary-overlap rows, and an eight-family 1000-query budget, while keeping content materialization, complete-source query rows, A-H answer/citation/resource rows, `v53_ready`, and release claims blocked.
- `v53h` complete source content snapshot. Started. `experiments/test_v53h_complete_source_content_snapshot.sh` materializes the v53g manifest into 11318 content files, 11318 content sha256 rows, 124845122 content bytes, and 11312 query-eligible content rows across all 10 locked repos, while keeping complete-source span extraction, 1000+ complete-source query rows, A-H answer/citation/resource rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53i` complete source query instantiation. Started. `experiments/test_v53i_complete_source_query_instantiation.sh` now instantiates the v53g eight-family 1000-query budget over v53h complete-source content, with 1000 query rows, 1000 line-bound source spans, 840 supported rows, 160 negative/abstain rows, 10 repos, and pinned content-hash evidence binding, while keeping A-H answer/citation/resource rows, symmetric scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53j` complete source A-H answer/citation/resource intake. Started. `experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh` now promotes v53f-style intake onto the v53i complete-source query set, records 7000 A/B/C/D/E/G/H core answer/resource/citation targets, binds F to the v52y final-deferred policy, and keeps supplied core rows, scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53k` complete source System A lexical measured rows. Started. `experiments/test_v53k_complete_source_system_a_lexical_measured.sh` now supplies System A/BM25-compatible answer/citation/resource/retrieval/guard rows for the frozen v53i 1000-query set, records partial `supplied_v53j/` rows, and keeps B/C/D/E/G/H, scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53l` complete source System B local-RAG measured rows. Started. `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh` now supplies System B small-local-RAG answer/citation/resource/retrieval/guard rows for the same frozen v53i 1000-query set, records combined A+B `supplied_v53j/` rows, and keeps C/D/E/G/H, scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53m` complete source System C local-model-RAG measured rows. Started. `experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh` now runs local Ollama `qwen2.5:7b-instruct` over the same frozen v53i 1000-query set, records System C answer/citation/resource/retrieval/abstain/guard/transcript rows plus combined A+B+C `supplied_v53j/` rows, and keeps D/E/G/H, scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53n` complete source System G RouteMemory+RouteHint measured rows. Started. `experiments/test_v53n_complete_source_system_g_routehint_measured.sh` now supplies System G answer/citation/resource/retrieval rows over the same frozen v53i 1000-query set, records 1000 route-memory evidence rows, 1000 compact RouteHint rows, raw prompt context bytes 0, combined A+B+C+G `supplied_v53j/` rows, and keeps D/E/H, symmetric scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53o` complete source System H RouteMemory+RouteHint+source-verified-scorer+domain-policy measured rows. Started. `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh` now supplies System H answer/citation/resource/retrieval rows over the same frozen v53i 1000-query set, records 1000 route-memory evidence rows, 1000 compact RouteHint rows, 1000 source-verified scorer rows, 1000 domain-policy rows, raw prompt context bytes 0, combined A+B+C+G+H `supplied_v53j/` rows, and keeps D/E, symmetric scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53p` complete source System D/E open-weight RAG measured rows. Started. `experiments/test_v53p_complete_source_system_de_open_weight_rag_measured.sh` now supplies 1000 D and 1000 E answer/citation/resource rows over the same frozen v53i 1000-query set, binds v52p/v52q model identity evidence, emits 7000 combined A+B+C+D+E+G+H core `supplied_v53j` rows, and keeps D/E quality comparison, symmetric scorer/policy rows, `v53_ready`, review artifacts, and release claims blocked.
- `v53q` complete source symmetric scorer/policy rows. Started. `experiments/test_v53q_complete_source_symmetric_scorer_policy.sh` now applies the same scorer and domain/abstain policy to all 7000 A/B/C/D/E/G/H rows, records 7000 scorer rows, 7000 policy rows, 6000 answer-hash matches, 1000 preserved C mismatches, and keeps quality comparison, `v53_ready`, review artifacts, and release claims blocked.
- `v53r` complete source review packet. Started. `experiments/test_v53r_complete_source_review_packet.sh` now turns v53q into 1000 query review packets, 7000 answer review packets, 7000 pending review queue rows, 10 repo packets, 7 system packets, reviewer assignment templates, and return templates. It records p0/p1/p2 priority counts of 1000/960/5040 and keeps returned human/source review artifacts, quality comparison, `v53_ready`, and release claims blocked.
- `v53s` complete source review return intake. Started. `experiments/test_v53s_complete_source_review_return_intake.sh` binds v53r to the expected returned-review schema, requiring 7000 human review rows, 1000 adjudication rows, reviewer identity/conflict rows, and an acceptance summary. The default no-env path accepts 0 returned review rows, records `review_return_ready=0`, `quality_comparison_claim_ready=0`, and `v53_ready=0`, and keeps human-reviewed audit, comparison, and release claims blocked.
- `v53t` complete source audit readiness gate. Started. `experiments/test_v53t_complete_source_audit_readiness_gate.sh` binds v52y/v53i/v53q/v53r/v53s into a final audit readiness matrix, records `machine_complete_source_surface_ready=1`, and keeps accepted human review 0/7000, accepted adjudication 0/1000, `review_return_ready=0`, `quality_comparison_claim_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and release claims blocked.
- `v54` contract scaffold. Started. `experiments/test_v54_routehint_generation_1000_contract.sh` now emits the 1000-row RouteHint generation contract from the v48/v54 seed evidence while intentionally keeping `v54_generation_1000_ready=0` and `missing_generation_rows=976`.
- `v54b` RouteHint generation scale 1000. Started. `experiments/test_v54b_routehint_generation_scale_1000.sh` now emits 1000 deterministic local RouteHint generation rows across six domains, including 900 answer rows, 100 abstain rows, 1000 citation rows, and 1000 resource rows, while keeping release and 30B-150B equivalence claims blocked until the rest of v52-v60 is measured and reviewed.
- `v55` contract scaffold. Started. `experiments/test_v55_local_scaling_law_main_contract.sh` now emits the six-axis / 100-row scaling-law contract from the v51 preview curves while intentionally keeping `v55_local_scaling_law_ready=0`, `repo_count_axis_ready=0`, and `missing_scaling_curve_rows=73`.
- `v55b` local scaling law main 120. Started. `experiments/test_v55b_local_scaling_law_main_120.sh` now emits a six-axis / 360-row local scaling-law main run with repo-count axis, confidence intervals, failure cases, fit rows, resource rows, and local source/probe hash binding, while keeping GPU speedup, production latency, release, and 30B-150B equivalence claims blocked.
- `v56` contract scaffold. Started. `experiments/test_v56_ruler_longbench_expanded_contract.sh` now emits the RULER/LongBench expanded benchmark contract from v49/v45 seed evidence while intentionally keeping `v56_ruler_longbench_expanded_ready=0`, `ruler_missing_rows=500`, `longbench_missing_rows=494`, and `llm_rag_baseline_rows_ready=0`.
- `v56b` RULER/LongBench expanded scale. Started. `experiments/test_v56b_ruler_longbench_expanded_scale.sh` now emits 1500 local candidate-scale benchmark-format rows, including 1000 RULER rows, 500 LongBench rows, 1500 lineage/candidate/resource rows, and no oracle/raw-input extractor usage, while keeping LLM+RAG baseline rows, independent external benchmark verification, leaderboard, and release claims blocked.
- `v57` contract scaffold. Started. `experiments/test_v57_domain_expert_packs_contract.sh` now emits the six-pack domain expert contract from v47/v48/v52/v56 seed evidence while intentionally keeping `v57_domain_expert_packs_ready=0`, `missing_eval_rows=950`, `human_expert_review_ready=0`, and `blind_eval_ready=0`.
- `v57b` domain expert pack candidate 1000. Started. `experiments/test_v57b_domain_expert_pack_candidate_1000.sh` now emits 1000 source-span-bound candidate eval rows across six packs, including 900 answer rows, 100 abstain rows, 1000 expert-review template rows, policy/rubric/failure-taxonomy rows, and hash manifests, while intentionally keeping `v57_domain_expert_packs_ready=0`, `human_expert_review_ready=0`, `blind_eval_ready=0`, and expert/release claims blocked.
- `v58` contract scaffold. Started. `experiments/test_v58_blind_eval_contract.sh` now emits the blind-eval contract from v52/v57 seed evidence while intentionally keeping `v58_ready=0`, `missing_blind_eval_rows=500`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, and `human_blind_review_ready=0`.
- `v58b` blind-eval candidate 500. Started. `experiments/test_v58b_blind_eval_candidate_500.sh` now emits 500 frozen source-span-bound blind queries, 2500 D/E/F/G/H response templates, 2500 anonymous reviewer-packet templates, sealed answer/identity keys, same-evidence-budget rows, and adjudication templates, while intentionally keeping `v58_ready=0`, `actual_blind_response_rows=0`, 30B/70B response readiness, human blind review, inter-rater rows, and release claims blocked.
- `v58c` blind response evidence intake. Started. `experiments/test_v58c_blind_response_evidence_intake.sh` now emits the 2500-row D/E/F/G/H blind response schema/template and run-identity template over the v58b frozen query set while intentionally keeping all response readiness, human blind review, inter-rater rows, and release claims blocked until real supplied response rows validate.
- `v59` contract scaffold. Started. `experiments/test_v59_one_command_challenge_demo_contract.sh` now emits the one-command challenge demo contract and `examples/v1_0_architecture_challenge_demo.sh` entrypoint while intentionally keeping `v59_ready=0`, all v52-v58 full-ready rows at zero, and real-row blockers explicit.
- `v59b` one-command candidate demo. Started. `experiments/test_v59b_one_command_candidate_demo.sh` now verifies `examples/v1_0_architecture_challenge_candidate_demo.sh`, which assembles the v52b-v58c candidate/intake chain into one replay bundle while intentionally keeping `v59_ready=0`, real 30B/70B rows, optional 100B+ row/final deferral, complete-source audit, human domain review, human blind review, and release claims blocked.
- `v59c` one-command measured-registry demo. Started. `experiments/test_v59c_one_command_measured_registry_demo.sh` now verifies `examples/v1_0_architecture_challenge_measured_registry_demo.sh`, which promotes the v52m A/B/C/G/H measured registry into the v59 replay path while preserving the local-only claim boundary and keeping D/E, complete-source audit, human review, full v59, and release claims blocked.
- `v60` contract scaffold. Started. `experiments/test_v60_architecture_challenge_release_contract.sh` now emits the release-audit contract, allowed/forbidden claim rows, and release requirement rows while intentionally keeping `v60_ready=0`, all ten release requirements blocked, and `real_release_package_ready=0`.
- `v60b` release preflight candidate audit. Started. `experiments/test_v60b_release_preflight_candidate_audit.sh` now consumes the v59b candidate replay and emits release-preflight requirement rows, claim rows, stage release-audit rows, and decision rows while intentionally keeping `v60_ready=0`, real 30B/70B rows, complete-source audit, human domain review, human blind review, human release review, and release package blocked.
- `v61` SSD-resident MoE runtime prototype. Implemented. `docs/V61_SSD_RESIDENT_MOE_RUNTIME.md` documents the runtime direction, and `experiments/test_v61j_one_command_ssd_resident_demo.sh` now closes v61a-v61j: deterministic 2 MB SSD weight pages, aligned direct I/O page reads, no full-model RAM residency audit rows, RouteHint prefetch/VRAM hot-cache rows, CPU deterministic page-dequant-matmul rows, expert routing, predictive-prefetch stall comparison, mixed quant planning, dense full-stream blocker rows, a logical 128B MoE active-sparse contract, and a one-command SSD-resident demo bundle. It records `ssd_resident_active_sparse_path_proven=1`, `ram_resident_full_model_fallback_rows=0`, `total_parameters=128000000000`, `ssd_read_bytes_per_token_max=8388608`, and `route_jump_rows=0`, while keeping real 100B checkpoint materialization, GPU speedup, dense hundreds-B local-speed, near-frontier quality, production-latency, and release claims blocked.
- `v61k` real-model page manifest. Started. `experiments/test_v61k_real_model_page_manifest.sh` binds the SSD-resident page model to `mistralai/Mixtral-8x22B-v0.1`, records Apache-2.0 source/config/license rows, emits 59 checkpoint-shard manifest rows and 129024 expert tensor page metadata rows, and keeps checkpoint weights out of the repository. It marks `legally_redistributable_page_manifest_ready=1` and `total_parameters_100b_plus=1` while keeping `active_uncached_q4_budget_pass=0`, GPU/KV/source-bound QA, near-frontier, production-latency, and release claims blocked.
- `v61l` GPU page-dequant-matmul measurement. Started. `experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh` measures a real ROCm/HIP page-dequant-matmul kernel over the v61k Mixtral page geometry using one synthetic 2 MiB q4-equivalent page tile. It records positive `gpu_kernel_avg_ms`, positive `gpu_page_dequant_gflops`, positive `gpu_page_bandwidth_gbps`, and `real_checkpoint_weight_bytes_materialized=0`, while keeping safetensors page-hash binding, KV-cache policy, source-bound QA, near-frontier, production-latency, and release claims blocked.
- `v61m` KV-cache residency/eviction policy. Started. `experiments/test_v61m_kv_cache_residency_eviction_policy.sh` computes Mixtral KV geometry from the v61k config and emits deterministic VRAM hot/sink plus NVMe cold-tier eviction rows. It records `kv_bytes_per_token=229376`, `kv_tokens_per_page=9`, `max_context_tokens=8192`, `max_resident_vram_pages=129`, `max_evicted_nvme_pages=782`, `kv_cache_policy_ready=1`, and `host_ram_kv_spill_enabled=0`, while keeping safetensors page-hash binding, source-bound QA, long-context quality, near-frontier, production-latency, and release claims blocked.
- `v61n` source-bound QA workload seed. Started. `experiments/test_v61n_source_bound_qa_workload.sh` binds v61j, v61m, v53g, and the currently materialized v53c canary-overlap files into a source-bound QA packet. It records citation-bound supported answers, one unsupported-claim abstain per repository, 10 repos, and manifest-bound source files, while keeping complete-source A-H QA, real Mixtral generation, safetensors page-hash binding, near-frontier, production-latency, and release claims blocked.
- `v61o` checkpoint shard/header probe. Started. `experiments/test_v61o_checkpoint_shard_header_probe.sh` binds the Mixtral safetensors index, all 59 shard HTTP identities, all safetensors headers, 1739 tensor header rows, and three sampled 2 MiB page hashes without persisting checkpoint payload bytes. It keeps full checkpoint materialization, full safetensors page-hash coverage, local SSD checkpoint residency, real generation, near-frontier, production-latency, and release claims blocked.
- `v61p` local SSD checkpoint residency preflight. Started. `experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh` turns the v61o shard identity table into an outside-repository warehouse plan, disk budget row, 59 shard download-plan rows, and 59 local presence rows while downloading zero checkpoint payload bytes. The current host records 281241493344 checkpoint bytes required, 315601231712 bytes required with reserve, 21337460736 available bytes, and `local_checkpoint_residency_ready=0`.
- `v61q` real checkpoint page map. Started. `experiments/test_v61q_real_checkpoint_page_map.sh` converts the real safetensors header tensor offsets into a metadata-only 2 MiB SSD page map with 1739 checkpoint tensor rows, 134161 unique checkpoint page rows, and 135841 tensor/page segment rows. It keeps checkpoint payload bytes out of the repository and keeps full page-hash coverage, local SSD checkpoint residency, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61r` full page-hash sweep plan. Started. `experiments/test_v61r_full_page_hash_sweep_plan.sh` and `experiments/test_v61r_full_page_hash_sweep_plan_target_override.sh` turn the v61q page map and v61p local shard presence audit into 134161 page-hash task rows, bind 3 sampled remote page-hash probes to 6 overlapping page rows, record 0 verified local page hashes on the current host, and verify that `V61R_WAREHOUSE_ROOT` refreshes v61p shard-presence planning and rewrites local shard paths to the supplied external warehouse root. It keeps local SSD checkpoint residency, completed full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61s` one-command source-bound QA replay. Started. `experiments/test_v61s_one_command_source_bound_qa_replay.sh` exercises `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa`, binds v61j/v61n, records exit code 0, 37/37 source-bound query pass rows, and 10/10 abstain-policy pass rows. It keeps complete-source 1000+ audit completion, real Mixtral generation, full page-hash coverage, near-frontier, production-latency, and release claims blocked.
- `v61t` local checkpoint materialization verifier. Started. `experiments/test_v61t_local_checkpoint_materialization_verifier.sh` refreshes local shard presence, binds the v61q page map and v61r hash plan, and verifies local shard identity using exact byte length, safetensors header hash, and sampled page hash checks. `experiments/test_v61t_local_checkpoint_materialization_verifier_target_override.sh` verifies that `V61T_WAREHOUSE_ROOT` is passed into v61p shard-presence preflight and all materialization target paths. The current host records 0 local existing shards, 0 local identity-verified shards, `local_checkpoint_materialization_ready=0`, and keeps full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61u` remote checkpoint page-hash sampler. Started. `experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh` performs bounded HTTP Range reads for 16 deterministic full-size v61q checkpoint pages, records 16 ready page-hash sample rows, 33554432 remote payload bytes read as hashes only, and keeps local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61v` remote page tensor binding. Started. `experiments/test_v61v_remote_page_tensor_binding.sh` binds the 16 v61u remote-hashed checkpoint pages to v61q tensor segments and runtime nodes, including 15 MoE expert page bindings across 15 layers and all eight expert indices, while keeping local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61w` materialization admission/resume plan. Started. `experiments/test_v61w_materialization_admission_resume_plan.sh` and `experiments/test_v61w_materialization_admission_resume_plan_target_override.sh` bind v61p/v61q/v61t/v61v into 59 checkpoint shard priority rows and 59 download-resume rows, promote 15 remote-hashed MoE expert shards plus one embedding shard ahead of generic backfill, record `download_resume_plan_ready=1`, and verify that `V61W_WAREHOUSE_ROOT` refreshes v61t/v61p materialization planning while preserving target-aware verify/hash commands. It keeps `materialization_admission_ready=0`, local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked on the current SSD budget.
- `v61x` hotset runtime replay manifest. Started. `experiments/test_v61x_hotset_runtime_replay_manifest.sh` binds v61w/v61v/v61s/v61m into 16 planned NVMe hotset page rows, 16 runtime slot rows, and 37 source-bound workload binding rows. It records 15 MoE hotset pages, one embedding hotset page, `hotset_manifest_ready=1`, `source_bound_replay_binding_ready=1`, and zero checkpoint payload bytes downloaded or committed by v61x, while keeping hotset payload materialization, SSD budget admission, local checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61y` hotset local materialization verifier. Started. `experiments/test_v61y_hotset_local_materialization_verifier.sh` materializes the 16 sampled v61x/v61u hotset pages outside the repository, verifies 16 local hash matches and 16 readback hash matches, records 33554432 sampled checkpoint payload bytes persisted outside the repository, and keeps repo checkpoint payload bytes at 0. It marks sampled `hotset_payload_materialization_ready=1` while keeping full checkpoint materialization, SSD budget admission, local full-checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61z` hotset direct-I/O replay. Started. `experiments/test_v61z_hotset_direct_io_replay.sh` reads the 16 local sampled hotset pages through O_DIRECT, verifies 16 direct-read hash matches with zero direct-I/O errors, records 33554432 direct-I/O bytes, `ssd_read_bytes_per_token=8388608`, p50/p95 read latency 0.580768/0.956690 ms, and positive sampled throughput. It keeps full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61aa` hotset tensor slice verifier. Started. `experiments/test_v61aa_hotset_tensor_slice_verifier.sh` interprets the 16 local sampled hotset pages as BF16 tensor segments using real v61v safetensors bindings, records 16 tensor slices, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, and 16 slice/page hash matches. It keeps full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61ab` hotset tensor tile quant probe. Started. `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh` runs bounded dot-tile probes over the sampled BF16 tensor slices, records 128 tensor tile rows, 120 MoE tile rows, 8 embedding tile rows, 524288 BF16 tile values, 128/128 finite baseline/q8/q4 dot rows, and q8/q4 mean absolute dot errors of 0.00113809798/0.0244754219. It keeps full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61ac` hotset token budget replay. Started. `experiments/test_v61ac_hotset_token_budget_replay.sh` binds v61x/v61z/v61ab into 37 source-bound token-budget rows, 148 active page schedule rows, and 1184 tile-binding rows. It records four active page reads per token, 32 active tile probes per token, 131072 BF16 tile values per token, 8388608 SSD read bytes per token, sampled token direct-I/O p50/p95 budgets of 2.323072/3.82676 ms, and keeps full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61ad` KV + weight token budget replay. Started. `experiments/test_v61ad_kv_weight_token_budget_replay.sh` combines the 37 sampled source-bound token-budget rows with five KV context profiles into 185 KV+weight budget rows. It records 185 resident KV policy pass rows, 74 full-KV-in-VRAM pass rows, 111 NVMe cold KV eviction-required rows, zero host RAM spill bytes, 8617984 sampled weight+new-KV bytes per token, and keeps full KV-in-VRAM residency, full checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61ae` real generation admission gate. Started. `experiments/test_v61ae_real_generation_admission_gate.sh` and `experiments/test_v61ae_real_generation_admission_gate_target_override.sh` bind v61ad/v53r/v61r/v61t/v61w into 1000 complete-source real-generation candidate rows. They record 0 admitted rows, 1000 runtime-budget-ready rows, 1000 source-review-blocked rows, 1000 materialization-blocked rows, 1000 page-hash-blocked rows, and verify that `V61AE_WAREHOUSE_ROOT` refreshes v61r/v61t/v61w source evidence over the supplied warehouse root. It keeps actual Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61af` checkpoint warehouse operator bundle. Started. `experiments/test_v61af_checkpoint_warehouse_operator_bundle.sh` and `experiments/test_v61af_checkpoint_warehouse_operator_bundle_target_override.sh` turn v61w/v61t/v61r/v61ae into guarded repo-outside operator scripts, recording 59 download commands, 62 operator command rows, six bundle files, dry-run defaults for downloads and full page hashing, and zero checkpoint payload bytes downloaded or committed by v61af. The target-override smoke verifies that `V61AF_WAREHOUSE_ROOT` propagates through source evidence, `operator_env.template`, guarded scripts, and verify/hash/admission command rows. It keeps SSD-budget admission, local materialization, full page-hash coverage, actual Mixtral generation, near-frontier, production-latency, and release claims blocked.
- `v61ag` checkpoint warehouse execution preflight. Started. `experiments/test_v61ag_checkpoint_warehouse_execution_preflight.sh` and `experiments/test_v61ag_checkpoint_warehouse_execution_preflight_target_override.sh` verify the v61af operator bundle before payload download, recording 4/4 script syntax/executable passes, a one-row dry-run download probe with guard ready, `huggingface_cli_available=0`, `ssd_disk_budget_pass=0`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ag. The target-override smoke verifies that `V61AG_WAREHOUSE_ROOT` refreshes v61af and preserves the supplied external target in copied operator env/scripts and command rows. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked.
- `v61ah` checkpoint download backend fallback plan. Started. `experiments/test_v61ah_checkpoint_download_backend_fallback_plan.sh` and `experiments/test_v61ah_checkpoint_download_backend_fallback_plan_target_override.sh` probe five download backends, select available `curl-resume` over the missing `huggingface-cli`, emit 59 backend download plan rows, verify backend dry-run guard readiness with zero checkpoint payload bytes downloaded or committed by v61ah, and verify that `V61AH_WAREHOUSE_ROOT` propagates into target paths, curl commands, and the guarded backend script. It keeps SSD-budget admission, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked.
- `v61ai` checkpoint storage budget remediation plan. Started. `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan.sh` and `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan_target_override.sh` bind v61ah/v61p/v61w, record `required_with_reserve_bytes=315601231712`, live available SSD bytes, computed full/raw deficits, `safe_materialization_batch_rows=0`, and a bounded diagnostic no-reserve top-priority batch with zero checkpoint payload bytes downloaded or committed by v61ai. The target-override smoke verifies that `V61AI_WAREHOUSE_ROOT` propagates through v61ah/v61p/v61w evidence and target paths. It keeps storage-budget remediation, download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked.
- `v61aj` checkpoint storage profile admission matrix. Started. `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix.sh` and `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix_target_override.sh` evaluate six current/minimum/operator free-space profiles, record current reserve admitted shard rows 0, live current no-reserve diagnostic admitted shard rows/bytes, exact reserve admitted shard rows 59, computed minimum additional bytes, recommended operator free bytes 549755813888, and zero checkpoint payload bytes downloaded or committed by v61aj. The target-override smoke verifies that `V61AJ_WAREHOUSE_ROOT` propagates through v61ai and copied v61w target paths. It keeps current-host download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked.
- `v61ak` checkpoint warehouse target preflight. Started. `experiments/test_v61ak_checkpoint_warehouse_target_preflight.sh` probes current, operator-supplied, and repository-control warehouse targets, records three target rows, repository-local target rejection, live current target free/deficit bytes, `required_with_reserve_bytes=315601231712`, `recommended_operator_free_bytes=549755813888`, and zero checkpoint payload bytes downloaded or committed by v61ak. It keeps current-host target selection, download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked unless an outside-repository target with enough live free space is supplied.
- `v61al` checkpoint warehouse activation gate. Started. `experiments/test_v61al_checkpoint_warehouse_activation_gate.sh` binds v61ak/v61ah/v61w into 59 per-shard activation command rows, records 0 admitted activation rows, 59 blocked activation rows, `activation_package_ready=0`, `selected_target_id=none`, `selected_backend_id=curl-resume`, explicit execution required, and zero checkpoint payload bytes downloaded or committed by v61al. `experiments/test_v61al_checkpoint_warehouse_activation_gate_target_override.sh` verifies that `V61AL_WAREHOUSE_ROOT` forces a fresh v61ak target probe before activation planning. It keeps download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, and release claims blocked.
- `v61am` checkpoint post-activation verification gate. Started. `experiments/test_v61am_checkpoint_post_activation_verification_gate.sh` binds v61al/v61t/v61r into 59 post-activation verification rows, records 0 ready rows, 59 blocked rows, 0 activation-admitted rows, 0 local identity verified shard rows, 0 verified page-hash rows out of 134161 required rows, generation gate ready 0, and zero checkpoint payload bytes downloaded or committed by v61am. `experiments/test_v61am_checkpoint_post_activation_verification_gate_target_override.sh` verifies that `V61AM_WAREHOUSE_ROOT` forces fresh v61al/v61ak target planning. It keeps actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61an` checkpoint full page-hash execution gate. Started. `experiments/test_v61an_checkpoint_full_page_hash_execution_gate.sh` binds v61am/v61t/v61r into 291 resumable execution chunks over 134161 planned page hashes, records 0 hashed chunks, 291 activation-blocked chunks, 0 local page hash verification rows, full page-hash execution ready 0, and zero checkpoint payload bytes downloaded or committed by v61an. `experiments/test_v61an_checkpoint_full_page_hash_execution_gate_target_override.sh` verifies that `V61AN_WAREHOUSE_ROOT` propagates through fresh v61am/v61al/v61ak planning. It keeps full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ao` real model page-manifest coverage audit. Started. `experiments/test_v61ao_real_model_page_manifest_coverage_audit.sh` binds v61q/v61v/v61an into complete metadata coverage over the real Mixtral checkpoint manifest, records 59 shards, 1739 tensors, 134161 checkpoint pages, 135841 tensor/page segments, 1344/1344 layer-expert-MoE tensor coverage rows, 16 remote-hash-bound sample tensor rows, `real_model_page_manifest_coverage_ready=1`, full page-hash coverage ready 0, and zero checkpoint payload bytes downloaded or committed by v61ao. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ap` MoE coverage remote hash plan. Started. `experiments/test_v61ap_moe_coverage_remote_hash_plan.sh` turns v61ao/v61q/v61v into 1344 representative layer-expert-MoE remote hash plan rows, preserves 15 already remote-hash-bound MoE sample rows, plans 1329 remaining representative range hashes, records full MoE remote-hash coverage ready 0 and remote hash expansion execution ready 0, and downloads or commits zero checkpoint payload bytes by v61ap. It keeps executed expansion, full page-hash coverage, local materialization, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61aq` MoE remote hash execution gate. Started. `experiments/test_v61aq_moe_remote_hash_execution_gate.sh` converts the v61ap plan into 1329 guarded curl-range command rows and 21 resumable execution chunks, preserves 15 existing MoE remote hashes, records remote hash execution ready 0 and full MoE remote-hash coverage ready 0, and downloads or commits zero checkpoint payload bytes by v61aq. It keeps executed remote hashing, full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ar` MoE remote hash result intake gate. Started. `experiments/test_v61ar_moe_remote_hash_result_intake.sh` consumes v61aq, defines the hash-only result return schema for 1329 guarded command rows, preserves 15 existing MoE remote hashes, emits 1344 combined coverage rows, records 0 supplied/accepted result rows and 1329 final-deferred missing rows in the default path, and downloads or commits zero checkpoint payload bytes by v61ar. It keeps full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61as` hotset reuse admission gate. Started. `experiments/test_v61as_hotset_reuse_admission_gate.sh` consumes v61ac/v61ad/v61ar and records 148 scheduled sampled MoE page touches collapsing to 15 unique cold-fill pages plus 133 cache-hit rows, `cache_hit_rate=0.898648649`, cold-fill bytes 31457280 versus uncached bytes 310378496, sampled hotset reuse ready 1, full runtime hotset reuse admission ready 0, and zero checkpoint payload bytes downloaded or committed by v61as. It keeps full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61at` prefetch overlap admission gate. Started. `experiments/test_v61at_prefetch_overlap_admission_gate.sh` consumes v61l/v61z/v61as and records 36/36 non-bootstrap sampled token rows passing steady-state prefetch overlap, p95 SSD page-read latency 0.956690 ms fitting inside a 2.053768 ms prior-token GPU page-kernel compute window, minimum steady-state overlap slack 1.097078 ms, `steady_state_prefetch_overlap_ready=1`, bootstrap cold-start ready 0, full runtime admission ready 0, and zero checkpoint payload bytes downloaded or committed by v61at. It keeps bootstrap cold-start, full runtime admission, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61au` prefetch queue-depth scheduler gate. Started. `experiments/test_v61au_prefetch_queue_depth_scheduler_gate.sh` consumes v61at and records 15 sampled cold-fill issue rows, 11 steady-state prefetch issue rows, 11/11 deadline-met rows, configured queue depth 4, max steady-state required queue depth 1, `steady_state_scheduler_ready=1`, bootstrap scheduler ready 0, actual async prefetch execution ready 0, and zero checkpoint payload bytes downloaded or committed by v61au. It keeps bootstrap scheduling, actual async I/O, full runtime admission, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61av` async prefetch execution probe. Started. `experiments/test_v61av_async_prefetch_execution_probe.sh` consumes v61au/v61z and executes 15 sampled prefetch issue reads through a queue-depth 4 threaded O_DIRECT worker pool, recording 15/15 hash matches, zero read errors, 11/11 steady-state hash matches, `actual_async_prefetch_execution_ready=1`, io_uring ready 0, registered buffers ready 0, full runtime admission ready 0, and zero checkpoint payload bytes downloaded or committed by v61av. It keeps bootstrap admission, io_uring, registered-buffer prefetch, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61aw` io_uring registered-buffer preflight. Started. `experiments/test_v61aw_io_uring_registered_buffer_preflight.sh` consumes v61av and records current-host Linux UAPI header ready 1, liburing header ready 0, setup/enter/register syscall numbers 425/426/427, `io_uring_setup_errno_name=EPERM`, setup/enter/register ready 0, registered-buffer prefetch ready 0, threaded O_DIRECT fallback ready 1, and zero checkpoint payload bytes downloaded or committed by v61aw. It keeps actual io_uring execution, registered buffers, full runtime admission, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ax` async-I/O backend selection gate. Started. `experiments/test_v61ax_async_io_backend_selection_gate.sh` consumes v61aw/v61av, records `io_uring_registered_buffer` blocked by `io_uring_setup_errno_1_EPERM`, selects `threaded_odirect` as the current-host sampled prefetch backend with queue depth 4, 15 hash-match rows, zero backend errors, full runtime async-I/O admission ready 0, and zero checkpoint payload bytes downloaded or committed by v61ax. It keeps bootstrap admission, actual io_uring execution, registered buffers, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ay` selected-backend token runtime binding. Started. `experiments/test_v61ay_selected_backend_token_runtime_binding.sh` consumes v61ad/v61ax and binds 185/185 KV+weight token budget rows plus 5/5 context profiles to `threaded_odirect`, recording 37 source-bound query rows, 74 full-KV-in-VRAM pass rows, 111 NVMe eviction-required rows, zero host RAM spill bytes, full runtime async-I/O admission ready 0, and zero checkpoint payload bytes downloaded or committed by v61ay. It keeps actual io_uring execution, registered buffers, full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61az` ubuntu-1 warehouse target admission. Started. `experiments/test_v61az_ubuntu1_warehouse_target_admission.sh` consumes v61aj/v61ak/v61ay and records `/dev/nvme0n1p8` label `ubuntu-1` as an outside-repository full-reserve capacity target for the Mixtral checkpoint, with 410615001088 live free bytes, `required_with_reserve_bytes=315601231712`, full-reserve capacity pass 1, operator-margin pass 0 against `recommended_operator_free_bytes=549755813888`, target write/activation readiness 0 in the current managed session, and zero checkpoint payload bytes downloaded or committed by v61az. It keeps download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61ba` ubuntu-1 activation handoff package. Implemented. `experiments/test_v61ba_ubuntu1_activation_handoff_package.sh` consumes v61az/v61ah/v61w and rewrites all 59 checkpoint shard handoff rows, materialization verifier rows, full page-hash rows, and generation-admission recheck rows to the ubuntu-1 target, recording `stale_tmp_target_command_rows=0`, `activation_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ba. It keeps operator/escalated write, download execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61bb` ubuntu-1 write sentinel activation probe. Implemented. `experiments/test_v61bb_ubuntu1_write_sentinel_activation_probe.sh` consumes v61ba and records a tiny JSON sentinel under the ubuntu-1 target, `ubuntu1_write_witness_ready=1`, `operator_write_step_resolved_by_witness=1`, `activation_target_write_witness_ready=1`, `activation_payload_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61bb. It keeps checkpoint payload execution, local materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61bc` ubuntu-1 sampled hotset materialization. Implemented. `experiments/test_v61bc_ubuntu1_sampled_hotset_materialization.sh` consumes v61bb/v61y and records 16/16 sampled hotset pages under the ubuntu-1 target, 16/16 hash matches, 16/16 readback hash matches, 33554432 sampled checkpoint payload bytes persisted on ubuntu-1, `checkpoint_payload_bytes_downloaded_by_v61bc=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v61bd` ubuntu-1 sampled hotset direct-I/O replay. Implemented. `experiments/test_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh` consumes v61bc/v61x and records 16/16 O_DIRECT reads over ubuntu-1 sampled pages, 16/16 hash matches, 0 direct-I/O errors, 33554432 direct-I/O bytes, p50/p95 read latency 1.102615/1.234314 ms, 1946.456509 MiB/s sampled throughput, `ssd_read_bytes_per_token=8388608`, `checkpoint_payload_bytes_downloaded_by_v61bd=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production-latency, near-frontier, and release claims blocked.
- `v53-v60` Architecture Challenge chain. Planned. Goal: public repo 10-30 repo / 1000-3000 query audit, RouteHint non-attention generator 1000+ rows, local scaling law main run, expanded RULER/LongBench evidence, domain expert packs, blind eval versus 30B-150B-class systems, one-command challenge demo, and v1.0 Architecture Challenge release audit. Detailed implementation objectives and stop rules are in `docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`.

Impact thesis:

- The highest-impact path is not to claim non-Transformer LLM replacement. The stronger claim is a small local machine that extends no-oracle/no-extractor RouteMemory prediction lineage across official benchmarks and real codebase/internal-document QA while binding every answer to citation, abstention, mmap evidence, and audit trail.
- The decisive follow-up is the v1.0 Architecture Challenge chain: real 30B/70B/100B+ LLM+RAG baseline rows, 10-30 public repos, 1000-3000 code/doc QA rows, 1000+ RouteHint generation rows, local scaling law evidence, expanded RULER/LongBench, domain packs, blind eval, and a one-command challenge demo. This is the right public timing target; v0.3 remains a preview.

Paths to avoid:

- Do not call this a Transformer replacement.
- Do not call this a frontier local LLM.
- Do not claim GPU acceleration proven.
- Do not claim long-context solved.
- Do not grow benchmark score while weakening lineage, abstention, or citation evidence.
- Do not regress into RAG-style prompt stuffing.
- Do not add another internal packaging layer unless a real return exposes a concrete verifier gap.

Human review remains optional for now. Reuse v37-v39 only if the project needs to revisit `real_release_package_ready=1`; until then, v40 is sufficient as a machine-verified artifact.

Invariant for all next experiments:

- No oracle.
- No raw-input extractor.
- Keep RouteMemory lineage.
- Keep official evaluator/source hashes.
- Keep abstain and negative rows as first-class evidence.
- Do not claim LLM replacement, Transformer replacement, production readiness, or full commercial deployment readiness.

Research priority:

- Prove citation/lineage correctness, abstention behavior, no-oracle prediction lineage, and independent rerun reproducibility.
- Publish as a bounded evidence-bound QA/audit architecture, not as a general language model replacement.

Commercial priority:

- Package a local-first codebase QA or internal-document QA PoC where privacy, audit trail, citations, and deterministic replay are buyer-visible advantages.
- Use incident-log QA and product-manual QA as the second and third verticals only after codebase QA produces clean acceptance rows.

## Recommended First Attachment

Recommended first attachment: codebase QA.

This is the best research and commercial bridge because every answer can be checked against a source span, mmap read row, RouteMemory prediction lineage row, evaluator row, negative case, citation, and audit trail. It is also a useful commercial wedge: local-first codebase QA, internal documentation QA, product manual QA, and incident-log evidence QA are concrete domains where bounded evidence and abstention matter more than broad conversational fluency.

Avoid positioning this as a Transformer replacement or general LLM replacement. The sharper claim is a local evidence-bound QA/audit system with deterministic memory, external-verifiable provenance, and conservative abstention.

## Phase 1: Third-Party Rerun

Implementation goal:

- Send the v19 third-party submission directory to a non-local reviewer or clean-machine environment.
- Have the reviewer run the exact reproduction command and return the required v18 directory.
- Verify the return with `V18_THIRD_PARTY_RERUN_DIR=/path/to/return experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- reviewer identity and conflict disclosure
- clean-machine or independent environment manifest
- exact command, exit code, stdout hash, stderr hash
- frozen query and source snapshot verification
- metric delta rows within tolerance
- pass/fail review rows

Exit criterion:

- `independent_rerun_actual_ready=1`

Preflight command:

```bash
V20_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/THIRD_PARTY_RERUN_REQUEST.md`

Clean-machine execution kit:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/HOST_CLEAN_MACHINE_RUNBOOK.md`
- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/CONTAINER_CLEAN_MACHINE_RUNBOOK.md`
- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh`

Current local rehearsal:

- `results/local_third_party_rerun_rehearsal/third_party_return/` was produced by the v22 capture script.
- v29 preflight sees this rehearsal return as complete for the third-party rerun track: `return_dirs_detected=1`, `complete_return_dirs=1`.
- v18 still keeps `independent_rerun_actual_ready=0` because this is a local owner-run rehearsal with `external_independent_reviewer=0` and `clean_machine=0`.
- The remaining real third-party task is therefore not file generation; it is obtaining reviewer identity and a true clean-machine or independent environment declaration from outside this local run.

## Phase 2: Official Benchmark Reconciliation

Implementation goal:

- Start with a small official RULER NIAH or LongBench v2 slice.
- Bind official source snapshot, official evaluator/container, raw predictions, metrics, provenance, reproducibility package, and RouteMemory prediction lineage.
- Verify the return with `V18_OFFICIAL_BENCHMARK_DIR=/path/to/official experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- official source snapshot
- official evaluator or container digest
- raw predictions before evaluation
- no oracle prediction path
- no raw-input extractor prediction path
- RouteMemory-derived prediction lineage
- metrics and provenance manifest
- candidate result rows

Exit criterion:

- `candidate_external_benchmark_result_ready=1` is achieved for the first RULER NIAH candidate return in v31.

Preflight command:

```bash
V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/OFFICIAL_BENCHMARK_REQUEST.md`

Execution notes:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/OFFICIAL_BENCHMARK_EXECUTION_NOTES.md`

Official benchmark reconciliation kit:

- `results/v23_official_benchmark_reconciliation_kit/kit_001/official_benchmark/OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md`
- `results/v23_official_benchmark_reconciliation_kit/kit_001/official_benchmark/NO_ORACLE_NO_EXTRACTOR_CONTRACT.md`
- `results/v23_official_benchmark_reconciliation_kit/kit_001/verification/CHECK_OFFICIAL_RETURN_FILES.sh`

v31 verified return:

- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_source_snapshot.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_evaluator_status.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/raw_predictions.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/prediction_lineage.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/metrics.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/provenance_manifest.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/reproducibility_package_manifest.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/candidate_result_rows.csv`

v31 verification result:

- `official_benchmark_supplied=1`
- `candidate_external_benchmark_result_ready=1`
- `commercial_poc_supplied=1`
- `closed_corpus_poc_actual_ready=1`
- `independent_rerun_actual_ready=0`
- `real_external_benchmark_verified=0`
- `real_release_package_ready=0`

## Phase 3: Commercial Local QA/Audit PoC

Implementation goal:

- Run a closed-corpus PoC in one of four domains: codebase QA, internal documents, product manuals, or incident logs.
- Prefer codebase QA first because repository files, exact spans, and evaluator rows are easiest to audit.
- Verify the return with `V18_COMMERCIAL_POC_DIR=/path/to/poc experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- domain and corpus manifest
- query set
- per-query evidence, answer, citation, abstention, and wrong-answer-guard rows
- privacy review
- resource envelope
- audit trail
- acceptance review

Exit criterion:

- `closed_corpus_poc_actual_ready=1` is achieved for the repository-only codebase QA PoC in v30.

Preflight command:

```bash
V20_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/COMMERCIAL_POC_REQUEST.md`

Execution notes:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/COMMERCIAL_POC_EXECUTION_NOTES.md`

v30 verified return:

- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/domain_manifest.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/corpus_manifest.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/query_set.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/poc_result_rows.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/audit_trail.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/resource_envelope.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/privacy_review.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/acceptance_review.csv`

v30 verification result:

- `commercial_poc_supplied=1`
- `closed_corpus_poc_actual_ready=1`
- `V20_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return experiments/run_v20_external_return_tracker.sh` also reports `commercial-poc-return=pass`.
- `independent_rerun_actual_ready=0`
- `candidate_external_benchmark_result_ready=0`
- `real_external_benchmark_verified=0`
- `real_release_package_ready=0`

## Phase 4: Release Review

Implementation goal:

- Re-run the v18 intake with all available real external directories.
- Re-run claim audit and release review only after the rerun and official benchmark tracks have real evidence.
- Keep product language narrow: local evidence-bound QA/audit, not replacement of a full LLM stack.

Exit criterion:

- `real_external_benchmark_verified=1` requires independent rerun actual plus official benchmark candidate.
- `real_release_package_ready=1` requires external benchmark evidence, commercial PoC evidence, privacy/reliability review, and release claim audit.

## Stop Rules

- Do not promote fixture evidence into real evidence.
- Do not raise official benchmark claims from runner-owned smoke results.
- Do not claim commercial readiness without closed-corpus privacy and acceptance review.
- Do not pursue GPU speed or broad NLG claims before the evidence-bound QA/audit track has external replay.
- Do not call the architecture a Transformer replacement unless a separate benchmark program proves that claim directly.
