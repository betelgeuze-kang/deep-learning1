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
- `v0.3 Architecture Preview` provides the first clone-and-run user surface over the existing evidence stack: `scripts/audit_my_repo.sh`, `scripts/run_routehint_generator_mainline.sh`, `examples/local_codebase_intelligence_box.sh`, and `experiments/test_v0_3_architecture_preview.sh` emit a source-bound Markdown audit report, JSONL/CSV machine artifacts, compact RouteHint rows, grounded generation rows, citations, abstentions, 8-way baseline comparison binding, architecture trace, reproduce script, and sha256 manifest.
- Current verified state after PR run `27029089994` plus v33-v51 and v0.3 preview: `v0_3_architecture_preview_ready=1`, `one_command_repo_audit_ready=1`, `baseline_war_ready=1`, `baseline_rows=8`, `routehint_generator_mainline_ready=1`, `local_codebase_intelligence_box_ready=1`, `raw_prompt_context_bytes=0`, `attention_blocks=0`, `transformer_blocks=0`, `oracle_prediction_used=0`, `raw_input_extractor_used=0`, `v51_real_return_evidence_intake_ready=1`, `measured_workload_trace_bound=1`, `real_return_evidence_axis_count=1`, `cpu_trace_rows=7`, `nvme_trace_rows=7`, `non_fixture_workload_trace_rows=1`, `v50_public_repo_auditor_3repo_ready=1`, `v49_ruler_niah_200_500_scale_ready=1`, `v48_multi_domain_generator_evidence_ready=1`, `v47_offline_domain_policy_update_ready=1`, `v46_source_verified_scorer_mainline_ready=1`, `v45_longbench_v2_small_slice_ready=1`, `v44_tiny_non_attention_generator_hint_ready=1`, `v43_doc_code_conflict_detection_ready=1`, `v42_codebase_auditor_200query_ready=1`, `v41_ruler_niah_50row_scale_ready=1`, `v40_machine_verified_research_artifact_ready=1`, `real_external_benchmark_verified=1`, `v18_closed_corpus_poc_actual_ready=1`, `machine_verification_ready=1`, `automated_research_artifact_ready=1`, `machine_verified_prototype_ready=1`, `public_repo_refs_pinned=1`, `public_repo_detected_doc_code_conflict_rows=1`, `public_repo_detected_config_mismatch_rows=1`, `hint_value_transformed_rows=20`, `answer_equals_hint_value_rows=0`, `raw_span_text_copied_rows=0`, `guard_negative_block_rows=3`, `no_raw_prompt_stuffing_ready=1`, `non_attention_generator_ready=1`, `privacy_review_ready=1`, and `resource_envelope_ready=1`, but `external_or_buyer_return_supplied=0`, `real_teacher_source_import_candidate_supplied=0`, `human_review_return_supplied=0`, `human_review_completed=0`, `human_review_required_for_public_release=1`, `gpu_speedup_claim=deferred`, and `real_release_package_ready=0` remain blocked until external acceptance/review and teacher-source authority evidence are supplied.

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
- `v52` External acceptance / teacher-source authority intake. Next. Goal: replace the remaining unsupplied axes with an external human/buyer acceptance return or a real teacher-source import/review authority package. Success message: at least one non-local acceptance or teacher-source authority return verifies through the existing v18/v40/v51 ladder without opening release-ready wording prematurely.

Impact thesis:

- The highest-impact path is not to claim non-Transformer LLM replacement. The stronger claim is a small local machine that extends no-oracle/no-extractor RouteMemory prediction lineage across official benchmarks and real codebase/internal-document QA while binding every answer to citation, abstention, mmap evidence, and audit trail.
- The decisive follow-up is a small non-attention generator that produces grounded answers from RouteMemory proposal hints without raw context stuffing. If v41-v43 grow evidence scale and industrial PoC strength, then v44 can move the project from a well-verified QA prototype toward an alternative local intelligence system path.

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
