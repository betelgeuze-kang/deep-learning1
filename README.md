# discrete-local-energy

Deterministic C++17 reference code for a staged discrete local-energy research prototype.

Korean README: [README.ko.md](README.ko.md)

**Artifact boundary:** This is a machine-verifiable research artifact, not a human-reviewed release package.

## v1.0 Architecture Challenge Roadmap

The next public timing target is not a broad v0.3 claim. It is the v1.0 Architecture Challenge: RouteMemory + RouteHint versus 30B-150B-class LLM+RAG baselines on code/doc QA, grounded generation, scaling, and one-command reproducibility.

Roadmap: [docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md](docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md)

SSD-resident MoE runtime direction: [docs/V61_SSD_RESIDENT_MOE_RUNTIME.md](docs/V61_SSD_RESIDENT_MOE_RUNTIME.md). This track is not RAM offload. It stores a hundreds-B to trillions-parameter open-weight model warehouse on NVMe SSD, then uses discrete-node routing, MoE active sparsity, predictive prefetch, and mixed quantization to fit the active execution set into a local PC's VRAM/compute budget. It redirects v52s/v52u/v52v/v52w into the v61 weight-page runtime seed while keeping v52-v60 release/comparison claims separately gated.

Current v61 prototype smoke:

```bash
./experiments/test_v61j_one_command_ssd_resident_demo.sh
./experiments/test_v61k_real_model_page_manifest.sh
./experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh
./experiments/test_v61m_kv_cache_residency_eviction_policy.sh
./experiments/test_v61n_source_bound_qa_workload.sh
./experiments/test_v61o_checkpoint_shard_header_probe.sh
./experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh
./experiments/test_v61q_real_checkpoint_page_map.sh
./experiments/test_v61r_full_page_hash_sweep_plan.sh
./experiments/test_v61s_one_command_source_bound_qa_replay.sh
./experiments/test_v61t_local_checkpoint_materialization_verifier.sh
./experiments/test_v61t_local_checkpoint_materialization_verifier_target_override.sh
./experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh
./experiments/test_v61v_remote_page_tensor_binding.sh
./experiments/test_v61w_materialization_admission_resume_plan.sh
./experiments/test_v61x_hotset_runtime_replay_manifest.sh
./experiments/test_v61y_hotset_local_materialization_verifier.sh
./experiments/test_v61z_hotset_direct_io_replay.sh
./experiments/test_v61aa_hotset_tensor_slice_verifier.sh
./experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh
./experiments/test_v61ac_hotset_token_budget_replay.sh
./experiments/test_v61ad_kv_weight_token_budget_replay.sh
./experiments/test_v61ae_real_generation_admission_gate.sh
./experiments/test_v61af_checkpoint_warehouse_operator_bundle.sh
./experiments/test_v61ag_checkpoint_warehouse_execution_preflight.sh
./experiments/test_v61ah_checkpoint_download_backend_fallback_plan.sh
./experiments/test_v61ai_checkpoint_storage_budget_remediation_plan.sh
./experiments/test_v61aj_checkpoint_storage_profile_admission_matrix.sh
./experiments/test_v61ak_checkpoint_warehouse_target_preflight.sh
./experiments/test_v61al_checkpoint_warehouse_activation_gate.sh
./experiments/test_v61al_checkpoint_warehouse_activation_gate_target_override.sh
./experiments/test_v61am_checkpoint_post_activation_verification_gate.sh
./experiments/test_v61am_checkpoint_post_activation_verification_gate_target_override.sh
./experiments/test_v61an_checkpoint_full_page_hash_execution_gate.sh
./experiments/test_v61an_checkpoint_full_page_hash_execution_gate_target_override.sh
```

This closes the v61a-v61j SSD-resident active-sparse runtime prototype and adds v61k-v61an real-model page evidence for Mixtral 8x22B: deterministic 2 MB SSD weight pages, aligned direct I/O reads, no full-model RAM residency audit rows, RouteHint prefetch/VRAM hot cache, CPU page-dequant-matmul numeric checks, expert routing, predictive prefetch, mixed quant planning, dense full-stream stress blockers, a logical 128B MoE active-sparse contract, a one-command demo bundle, a legally redistributable real-model page manifest, a ROCm page-dequant-matmul timing row over one 2 MiB q4-equivalent page tile, a KV-cache residency/eviction policy, a source-bound QA workload seed, checkpoint index/shard HTTP/safetensors header plus sampled page-hash probe evidence, an outside-repository local SSD checkpoint residency preflight, a real safetensors-header-derived checkpoint page map, a full page-hash sweep plan, one-command source-bound QA replay, a local checkpoint materialization identity verifier, bounded remote checkpoint page-hash samples, remote-hashed page tensor/runtime-node binding, a materialization admission/resume plan, an NVMe hotset runtime replay manifest, local sampled-hotset page materialization, sampled hotset direct-I/O replay, BF16 tensor-slice verification, bounded BF16/q8/q4 tensor-tile numeric probes, bounded source-bound hotset token-budget replay, KV+weight combined token-budget replay, a real generation admission gate, a guarded checkpoint warehouse operator bundle, a checkpoint warehouse execution preflight, a download backend fallback plan, a storage budget remediation plan, a storage profile admission matrix, a warehouse target preflight, a warehouse activation gate, a post-activation verification gate, and a full page-hash execution gate. The v61p preflight records 59 shard download-plan/presence rows, 281241493344 checkpoint bytes required, 315601231712 bytes required with reserve, and the current 21337460736-byte SSD budget blocker. The v61q page map records 1739 real checkpoint tensor rows, 134161 unique 2 MiB checkpoint page rows, 135841 tensor/page segment rows, and zero checkpoint payload bytes included. The v61r sweep plan records 134161 page-hash task rows, 3 sampled remote page-hash probes, 6 sampled page overlaps, and 0 verified local page hashes on the current host. The v61s replay runs `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa` with exit code 0 and 37/37 source-bound query pass rows. The v61t verifier records 0 local existing shards, 0 header-hash matches, 0 sampled local page-hash matches, and `local_checkpoint_materialization_ready=0`; its target-override smoke verifies that `V61T_WAREHOUSE_ROOT` is passed into the v61p shard-presence preflight. The v61u sampler reads 16 full 2 MiB checkpoint pages by HTTP Range, records 33554432 remote payload bytes read as hashes only, and keeps `full_safetensors_page_hash_binding_ready=0`. The v61v binder maps those 16 remote-hashed pages to 16 tensor/runtime-node rows, including 15 MoE expert page bindings across 15 layers and all 8 expert indices. The v61w planner emits 59 download-resume rows, 16 sampled-priority shard rows, 15 MoE-first shard rows, and `download_resume_plan_ready=1` while keeping `materialization_admission_ready=0` on the current SSD budget. The v61x manifest binds those 16 remote-hashed pages to 16 planned NVMe hotset slots and 37 source-bound replay rows, with `hotset_manifest_ready=1`, `source_bound_replay_binding_ready=1`, and zero checkpoint payload bytes downloaded or committed. The v61y verifier materializes those 16 sampled pages outside the repository, records 33554432 persisted hotset bytes, 16/16 local hash matches, 16/16 local readback hash matches, and zero checkpoint payload bytes committed to the repository. The v61z replay reads those 16 pages with O_DIRECT, records 16/16 direct-read hash matches, 33554432 direct-I/O bytes, p50/p95 read latency 0.580768/0.956690 ms, 2784.734538 MiB/s sampled throughput, and 8388608 SSD read bytes per token. The v61aa verifier interprets those local pages as real BF16 tensor segments, records 16 tensor slices, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, and 16 slice/page hash matches. The v61ab probe runs 128 bounded dot-tile probes over 524288 BF16 values from those sampled slices, including 120 MoE tile probes and 8 embedding tile probes, with 128/128 finite baseline/q8/q4 dot rows and q8/q4 mean absolute dot errors of 0.00113809798/0.0244754219. The v61ac replay binds those hotset pages and numeric tiles to 37 source-bound workload rows, records 37 token-budget rows, 148 active page schedule rows, 1184 tile-binding rows, 8388608 SSD read bytes/token, 131072 BF16 tile values/token, and sampled token direct-I/O p50/p95 budgets of 2.323072/3.82676 ms. The v61ad replay combines those 37 source-bound token-budget rows with five KV context profiles into 185 combined KV+weight budget rows, with 185/185 resident KV policy passes, 74/185 full-KV-in-VRAM passes, 111 rows requiring NVMe cold KV eviction, zero host RAM spill bytes, 229376 KV bytes/token, 8617984 sampled weight+new-KV bytes/token, and max 8192-context KV cold tier of 1639972864 bytes. The v61ae gate binds v61ad/v53r/v61r/v61t/v61w into 1000 real-generation candidate rows, admits 0 rows, records 1000 runtime-budget-ready rows, and keeps all 1000 rows blocked by source review, materialization, and full page-hash gates. The v61af bundle emits 59 guarded download commands, 62 operator command rows, six operator bundle files, dry-run defaults for download and full page hashing, and zero checkpoint payload bytes downloaded by v61af. The v61ag preflight records 62 operator command rows, 59 download commands, 4/4 script syntax/executable passes, one guarded dry-run probe, `huggingface_cli_available=0`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ag. The v61ah backend plan records five backend candidates, three ready backends, selects `curl-resume`, emits 59 curl-resume download plan rows, verifies backend dry-run guard readiness, and keeps zero checkpoint payload bytes downloaded or committed by v61ah. The v61ai storage plan records full-budget deficit 294263770976 bytes, raw-checkpoint deficit 259904032608 bytes, safe materialization batch rows 0, and a diagnostic no-reserve top-priority batch of 4 shards / 19478756392 bytes while keeping it non-admitted by reserve policy. The v61aj storage profile matrix records 6 profile rows, current reserve admitted shard rows 0, current no-reserve diagnostic admitted shard rows 4 / 19478756392 bytes, first full-reserve profile `full-checkpoint-exact-with-reserve`, minimum additional bytes 294263770976, recommended operator free bytes 549755813888, and zero checkpoint payload bytes downloaded or committed by v61aj. The v61ak target preflight records 3 target rows, live current target free/deficit bytes, repository-local target rejection, and zero checkpoint payload bytes downloaded or committed by v61ak. The v61al activation gate records 59 activation command rows, 0 admitted activation rows, 59 blocked activation rows, `selected_target_id=none`, `selected_backend_id=curl-resume`, and zero checkpoint payload bytes downloaded or committed by v61al. It keeps full checkpoint materialization, completed full page-hash coverage, real Mixtral generation over complete-source A-H QA, end-to-end GPU speedup, long-context quality, near-frontier quality, dense hundreds-B local-speed, production-latency, and release claims blocked.

The v61ai storage-budget summary also pins `required_with_reserve_bytes=315601231712`, `available_ssd_bytes=21337460736`, `full_budget_deficit_bytes=294263770976`, `raw_checkpoint_deficit_bytes=259904032608`, `safe_materialization_batch_rows=0`, diagnostic no-reserve top-priority batch `4` shards / `19478756392` bytes, and checkpoint payload download/commit `0` bytes by v61ai.
The v61aj storage-profile matrix pins `profile_rows=6`, `current_reserve_admitted_shard_rows=0`, `current_no_reserve_admitted_shard_rows=4`, `exact_reserve_admitted_shard_rows=59`, `minimum_additional_bytes_for_full_reserve=294263770976`, and `recommended_operator_free_bytes=549755813888`.
The v61ak warehouse-target preflight pins `target_rows=3`, repository-local checkpoint payload rejection, live current-target free/deficit rows, and checkpoint payload download/commit `0` bytes by v61ak.
The v61al warehouse-activation gate pins `activation_command_rows=59`, `activation_admitted_rows=0`, `activation_blocked_rows=59`, `selected_target_id=none`, `selected_backend_id=curl-resume`, and checkpoint payload download/commit `0` bytes by v61al. Its target-override smoke verifies that `V61AL_WAREHOUSE_ROOT` forces a fresh v61ak target probe before activation planning.
The v61am post-activation verification gate pins `post_activation_verification_rows=59`, `post_activation_verification_ready_rows=0`, `post_activation_verification_blocked_rows=59`, activation admitted rows `0`, local identity verified shard rows `0`, verified page hash rows `0/134161`, generation gate ready `0`, and checkpoint payload download/commit `0` bytes by v61am. Its target-override smoke verifies that `V61AM_WAREHOUSE_ROOT` forces fresh v61al/v61ak planning.
The v61an full page-hash execution gate pins `required_page_hash_rows=134161`, `planned_page_hash_rows=134161`, `execution_chunk_rows=291`, `hashed_chunk_rows=0`, `blocked_activation_chunk_rows=291`, full page-hash execution ready `0`, and checkpoint payload download/commit `0` bytes by v61an. Its target-override smoke verifies that `V61AN_WAREHOUSE_ROOT` propagates through v61am/v61al/v61ak before full page-hash scheduling.

Required v1.0 stages:

- v52: 30B/70B/100B+ LLM+RAG baseline war
- v53: public repo 10-30 repo, 1000-3000 query code/doc audit
- v54: RouteHint non-attention generator 1000+ rows
- v55: local scaling law main run
- v56: RULER/LongBench expanded benchmark
- v57: domain expert packs
- v58: blind eval vs 30B-150B-class systems
- v59: one-command LLM challenge demo
- v60: v1.0 Architecture Challenge Release

v0.3 remains a local architecture preview and claim-bound evidence surface.

Current v52-v60 scaffold and measured seed layers:

```bash
./experiments/test_v52_llm_rag_baseline_war.sh
./experiments/test_v52b_small_local_rag_measured_row.sh
./experiments/test_v52f_small_local_rag_measured_100.sh
./experiments/test_v52g_small_local_rag_measured_300.sh
./experiments/test_v52h_small_local_rag_measured_1000.sh
./experiments/test_v52i_abgh_same_query_measured_1000.sh
./experiments/test_v52j_measured_registry_absorb.sh
./experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh
./experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh
./experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh
./experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh
./experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh
./experiments/test_v53_public_repo_code_doc_audit.sh
./experiments/test_v53b_public_repo_10_lock.sh
./experiments/test_v53c_public_repo_canary_source_snapshot.sh
./experiments/test_v53d_canary_source_query_seed_100.sh
./experiments/test_v53e_canary_query_scale_1000.sh
./experiments/test_v53f_ah_answer_citation_resource_intake.sh
./experiments/test_v53g_complete_source_manifest.sh
./experiments/test_v53h_complete_source_content_snapshot.sh
./experiments/test_v53i_complete_source_query_instantiation.sh
./experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh
./experiments/test_v53k_complete_source_system_a_lexical_measured.sh
./experiments/test_v53l_complete_source_system_b_local_rag_measured.sh
./experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh
./experiments/test_v53n_complete_source_system_g_routehint_measured.sh
./experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh
./experiments/test_v53p_complete_source_system_de_open_weight_rag_measured.sh
./experiments/test_v53q_complete_source_symmetric_scorer_policy.sh
./experiments/test_v53r_complete_source_review_packet.sh
./experiments/test_v53s_complete_source_review_return_intake.sh
./experiments/test_v53t_complete_source_audit_readiness_gate.sh
./experiments/test_v54_routehint_generation_1000_contract.sh
./experiments/test_v54b_routehint_generation_scale_1000.sh
./experiments/test_v55_local_scaling_law_main_contract.sh
./experiments/test_v55b_local_scaling_law_main_120.sh
./experiments/test_v56_ruler_longbench_expanded_contract.sh
./experiments/test_v56b_ruler_longbench_expanded_scale.sh
./experiments/test_v57_domain_expert_packs_contract.sh
./experiments/test_v57b_domain_expert_pack_candidate_1000.sh
./experiments/test_v58_blind_eval_contract.sh
./experiments/test_v58b_blind_eval_candidate_500.sh
./experiments/test_v58c_blind_response_evidence_intake.sh
./experiments/test_v59_one_command_challenge_demo_contract.sh
./experiments/test_v59b_one_command_candidate_demo.sh
./experiments/test_v59c_one_command_measured_registry_demo.sh
./examples/v1_0_architecture_challenge_demo.sh
./examples/v1_0_architecture_challenge_candidate_demo.sh
./examples/v1_0_architecture_challenge_measured_registry_demo.sh
./experiments/test_v60_architecture_challenge_release_contract.sh
./experiments/test_v60b_release_preflight_candidate_audit.sh
```

These emit the A-H baseline registry, measured B small-local-RAG seed rows up to the full 1000-row frozen v53e query set, a local A/B/G/H same-query measured packet over that same v53e set, a v52 measured-registry absorb layer for those local rows, the C 7B-14B local-model-RAG evidence-intake gate, a real C 7B local-model-RAG measured seed through Ollama, a real C 7B local-model-RAG 1000-row response packet over the shared frozen v53e query/source manifest, the D/E 30B/70B open-weight LLM+RAG evidence-intake gate, the optional F 100B+ hosted/API LLM+RAG intake/defer gate, the v52y F-final policy and `v52_ready` condition matrix, symmetric evaluation contract, v53 repo/query scale contract, a live 10-repo public target lock, pinned canary source snapshots, a 100-row source-span-bound canary query seed, a 1000-row canary-scope query scale with negative/abstain rows, an A-H answer/citation/resource intake matrix over that frozen query set, a v53g complete-source recursive Git tree manifest and 1000-query budget, a v53h complete-source content snapshot with content hashes, a v53i complete-source 1000-query/source-span instantiation layer over v53h, a v53j complete-source A/B/C/D/E/G/H answer/citation/resource intake surface with F bound to the v52y final policy, a v53k System A complete-source lexical measured packet with 1000 answer/citation/resource rows, a v53l System B complete-source small-local-RAG measured packet with combined A+B supplied rows, a v53m real local System C 7B-14B model+RAG complete-source packet with 1000 generated answers and combined A+B+C supplied rows, a v53n System G RouteMemory+RouteHint complete-source packet with 1000 answer/citation/resource rows and combined A+B+C+G supplied rows, a v53o System H RouteMemory+RouteHint+source-verified-scorer+domain-policy complete-source packet with 1000 answer/citation/resource/scorer/policy rows and combined A+B+C+G+H supplied rows, a v53p System D/E open-weight RAG complete-source packet with 2000 D/E answer/citation/resource rows and 7000 combined core supplied rows, a v53q symmetric scorer/policy packet with 7000 scorer rows and 7000 policy rows over all core systems, a v53r complete-source review packet with 7000 pending answer-review queue rows, a v53s review-return intake gate for human/source review and adjudication artifacts, v54 1000-row generation contract, a v54b deterministic local 1000-row RouteHint generation scale run, v55 scaling-law main-run contract, a v55b six-axis / 360-row local scaling-law main run, v56 RULER/LongBench expanded benchmark contract, a v56b 1500-row RULER/LongBench candidate-scale run, v57 domain expert pack contract, a v57b 1000-row source-span-bound domain expert pack candidate set, v58 blind-eval contract, a v58b 500-row blind query-freeze and reviewer-packet candidate set, a v58c D/E/F/G/H blind response evidence-intake gate, v59 one-command challenge demo contract, a v59b one-command candidate/intake-chain replay bundle, a v59c one-command measured-registry replay bundle that promotes v52j A/B/G/H rows into the replay path, v60 release-audit contract, and v60b release preflight candidate audit while keeping full v1.0 comparison/release blocked until human-reviewed domain expert pack rows, 500+ blind-eval rows, the complete challenge demo rows, and human/release review evidence are supplied.

Current measured baseline progress: `experiments/test_v52b_small_local_rag_measured_row.sh` creates `results/v52b_small_local_rag_measured_row/row_001/` with nine measured system-B answer rows, citation rows, retrieval/resource rows, and hash manifests over the v50 public-repo seed. It is absorb-ready for v52, but it is not a 30B-150B comparison and leaves v52 release claims blocked.

Current B-baseline 100-row progress: `experiments/test_v52f_small_local_rag_measured_100.sh` creates `results/v52f_small_local_rag_measured_100/measured_001/` with 100 system-B answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, source manifest rows, retrieval rows, and sha256 manifests over the frozen v53d query set. It is the first controlled B expansion from 9 rows to 100 rows, but full v52 remains blocked until A/G/H are run on the same frozen query set and real C/D/E evidence directories validate.

Current B-baseline 300-row progress: `experiments/test_v52g_small_local_rag_measured_300.sh` creates `results/v52g_small_local_rag_measured_300/measured_001/` with 300 system-B answer/citation/abstain/wrong-answer/resource rows, 900 retrieval rows, source manifest rows, a frozen query/source subset, and sha256 manifests over a stratified v53e 1000-query subset. This is the current B measured frontier, but full v52 remains blocked until B reaches 1000 rows, A/G/H share the same frozen query IDs/source manifest, and real C/D/E evidence directories validate.

Current B-baseline 1000-row progress: `experiments/test_v52h_small_local_rag_measured_1000.sh` creates `results/v52h_small_local_rag_measured_1000/measured_001/` with 1000 system-B answer/citation/abstain/wrong-answer/resource rows, 3000 retrieval rows, source manifest rows, frozen query/source rows, and sha256 manifests over the full frozen v53e query set. This closes the B 9->100->300->1000 measured ladder, but full v52 remains blocked until A/G/H share the same query IDs/source manifest and real C/D/E evidence directories validate.

Current A/B/G/H same-query progress: `experiments/test_v52i_abgh_same_query_measured_1000.sh` creates `results/v52i_abgh_same_query_measured_1000/measured_001/` with A, B, G, and H on the same frozen v53e 1000-query/source manifest. It emits 4000 answer rows, 4000 citation rows, 4000 abstain rows, 4000 wrong-answer guard rows, 4000 resource rows, 12000 retrieval rows, 2000 RouteHint rows for G/H, per-system metrics, and sha256 manifests. This closes the local A/B/G/H same-query packet, but full v52 remains blocked until real C/D/E evidence directories validate.

Current v52 registry progress: `experiments/test_v52j_measured_registry_absorb.sh` creates `results/v52j_measured_registry_absorb/registry_001/` by absorbing the v52i local A/B/G/H measured packet into a v52 measured baseline registry. It marks A/B/G/H measured over the shared v53e query/source manifest and keeps C, D, E, and optional F blocked until real evidence directories validate.

Current C-baseline progress: `experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh` runs local Ollama `qwen2.5:7b-instruct` as baseline C over the v50 9-query public-repo seed, writes a real supplied evidence directory, and validates it through v52c. `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh` then expands C to the shared frozen v53e 1000-query/source manifest, emitting 1000 answer rows, 1000 citation rows, 1000 retrieval rows, 1000 abstain rows, 1000 wrong-answer guard rows, 1000 resource rows, 1000 Ollama transcript rows, model identity, and sha256 manifests. The v52l run is local/no-network and has 0/1000 strict exact-label accuracy, so it is evidence of a real C response packet and schema pressure test, not a C quality claim. Full v52 remains blocked until D/E real 30B/70B evidence directories validate.

Current D/E-baseline intake progress: `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh` creates `results/v52d_30b70b_llm_rag_evidence_intake/intake_001/` with required schemas, answer templates, model identity templates, validation rows, and hash manifest for future 30B and 70B open-weight LLM+RAG runs. Default/no-env execution remains blocked until both real D and E evidence directories validate.

Current F-baseline optional progress: `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh` creates `results/v52e_100b_plus_hosted_llm_rag_optional_intake/intake_001/` with required schema, answer template, hosted/API model identity template, validation rows, and hash manifest for a future 100B+ hosted/API LLM+RAG run. `experiments/test_v52y_f_optional_final_policy.sh` then records F as `deferred-with-reason-final` in the default no-env path, sets `v52_ready=1` only for the measured baseline registry scope, and allows 30B-150B-class wording only with disclosure that D/E are measured while optional F is final-deferred. It still blocks measured 100B+/150B result, v1.0 comparison, and release claims.

Current v53 repo-scale progress: `experiments/test_v53b_public_repo_10_lock.sh` creates `results/v53b_public_repo_10_lock/lock_001/` by resolving live HEAD SHAs for 10 public GitHub repositories. This satisfies the repo target-lock layer, but v53 remains blocked until source snapshots for the seven newly locked repos and at least 1000 source-span-bound query rows exist.

Current v53 source-snapshot progress: `experiments/test_v53c_public_repo_canary_source_snapshot.sh` creates `results/v53c_public_repo_canary_source_snapshot/snapshot_001/` by fetching pinned canary source/doc/config files from all 10 locked repositories and recording sha256 content rows. This starts source acquisition for the new repos, but full v53 remains blocked until complete source snapshots, 1000 source-span-bound queries, A-H answer/citation/resource rows, and review artifacts exist.

Current v53 query-seed progress: `experiments/test_v53d_canary_source_query_seed_100.sh` creates `results/v53d_canary_source_query_seed_100/query_001/` with 100 source-span-bound canary query rows over the 10 locked repositories. It raises the seed from 9 to 100 rows, but full v53 remains blocked until at least 1000 query rows, negative/abstain families, A-H answer/citation/resource rows, and review artifacts exist.

Current v53 query-scale progress: `experiments/test_v53e_canary_query_scale_1000.sh` creates `results/v53e_canary_query_scale_1000/scale_001/` with 1000 canary-scope source-span-bound query rows, 840 supported rows, 160 negative/abstain rows, eight query families, and coverage across the 10 locked repositories. This closes the canary query-count mechanics, but full v53 remains blocked until complete source snapshots, A-H answer/citation/resource rows, symmetric scorer/policy rows, and review artifacts exist.

Current v53 A-H intake progress: `experiments/test_v53f_ah_answer_citation_resource_intake.sh` creates `results/v53f_ah_answer_citation_resource_intake/intake_001/` with A-H system targets, required answer/citation/resource schemas, and 8000 answer/resource template rows over the frozen v53e query set. This closes the comparison evidence intake surface, but full v53 remains blocked because supplied valid answer/citation/resource rows, complete source snapshots, scorer/policy rows, and review artifacts are still missing.

Current v53 complete-source progress: `experiments/test_v53g_complete_source_manifest.sh` creates `results/v53g_complete_source_manifest/manifest_001/` with recursive Git tree metadata for the 10 locked repositories. `experiments/test_v53h_complete_source_content_snapshot.sh` materializes that manifest into `results/v53h_complete_source_content_snapshot/snapshot_001/` with 11318 content rows, 11318 content hashes, 124845122 content bytes, and 11312 query-eligible content rows. `experiments/test_v53i_complete_source_query_instantiation.sh` then creates `results/v53i_complete_source_query_instantiation/instantiate_001/` with 1000 complete-source query rows, 1000 line-bound source spans, 840 supported rows, 160 negative/abstain rows, eight families, and 10-repo coverage. `experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh` adds the complete-source A/B/C/D/E/G/H intake surface with 7000 core answer/resource/citation targets and F final-deferred by v52y. `experiments/test_v53k_complete_source_system_a_lexical_measured.sh` supplies the System A lexical/BM25-compatible packet for that frozen complete-source set, with 1000 answer/citation/resource rows. `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh` adds System B small-local-RAG rows over the same frozen set and emits combined A+B rows. `experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh` runs local Ollama `qwen2.5:7b-instruct` as System C over the same frozen set, emitting 1000 answer/citation/resource/retrieval/abstain/guard/transcript rows and combined A+B+C rows. `experiments/test_v53n_complete_source_system_g_routehint_measured.sh` adds System G RouteMemory+RouteHint rows with 1000 answer/citation/resource rows, 1000 route-memory evidence rows, 1000 compact RouteHint rows, raw prompt context bytes 0, and combined A+B+C+G `supplied_v53j/` rows: 4000 answers, 4000 citations, and 4000 resources. `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh` adds System H RouteMemory+RouteHint+source-verified-scorer+domain-policy rows with 1000 answer/citation/resource rows, 1000 source-verified scorer rows, 1000 domain-policy rows, raw prompt context bytes 0, and combined A+B+C+G+H `supplied_v53j/` rows: 5000 answers, 5000 citations, and 5000 resources. `experiments/test_v53p_complete_source_system_de_open_weight_rag_measured.sh` adds System D/E complete-source open-weight RAG rows, binds v52p/v52q model identity evidence, records 1000 D and 1000 E answer/citation/resource rows, and emits combined A+B+C+D+E+G+H `supplied_v53j/` rows: 7000 answers, 7000 citations, and 7000 resources. `experiments/test_v53q_complete_source_symmetric_scorer_policy.sh` applies the same scorer/policy rules to all 7000 core rows, records 6000 answer-hash matches and 1000 C mismatches, and marks `symmetric_scorer_policy_rows_ready=1` while keeping `quality_comparison_claim_ready=0`. `experiments/test_v53r_complete_source_review_packet.sh` then prepares 1000 query review packets, 7000 answer review packets, 7000 pending review queue rows, 10 repo packets, 7 system packets, and reviewer return templates; it marks `review_packet_ready=1`. `experiments/test_v53s_complete_source_review_return_intake.sh` adds the returned-review intake gate, expecting 7000 human review rows, 1000 adjudication rows, reviewer identity/conflict rows, and an acceptance summary; the default path records 0 accepted review rows, `review_return_ready=0`, `quality_comparison_claim_ready=0`, and `v53_ready=0`. Returned human/source review artifacts, quality comparison, and release claims are still blocked.

Current v53 audit-readiness progress: `experiments/test_v53t_complete_source_audit_readiness_gate.sh` creates `results/v53t_complete_source_audit_readiness_gate/gate_001/` and records `machine_complete_source_surface_ready=1` over the v52y/v53i/v53q/v53r/v53s chain, while keeping accepted human review at 0/7000, adjudication at 0/1000, `review_return_ready=0`, `quality_comparison_claim_ready=0`, and `v53_ready=0`.

Current v54 generation-scale progress: `experiments/test_v54b_routehint_generation_scale_1000.sh` creates `results/v54b_routehint_generation_scale_1000/scale_001/` with 1000 deterministic local RouteHint generation rows across six domains, 900 answer rows, 100 abstain rows, 1000 citation rows, 1000 resource rows, and zero attention/Transformer/raw-prompt-context rows. This closes the v54 1000-row machine-verified generation target, but v1.0 remains blocked until v52/v53/v55-v60 measured and reviewed rows exist.

Current v55 scaling-law progress: `experiments/test_v55b_local_scaling_law_main_120.sh` creates `results/v55b_local_scaling_law_main_120/main_001/` with six scaling axes, 360 curve rows, 60 repo-count rows, 120 confidence-interval rows, failure-case rows, resource rows, and local source/probe hash binding. This closes the v55 machine-verified local scaling-law main-run target, while keeping GPU speedup, production latency guarantee, 30B-150B equivalence, and release claims blocked.

Current v56 benchmark-scale progress: `experiments/test_v56b_ruler_longbench_expanded_scale.sh` creates `results/v56b_ruler_longbench_expanded_scale/scale_001/` with 1500 RULER/LongBench-format prediction rows, 1000 RULER rows, 500 LongBench rows, 1500 lineage/candidate/resource rows, and no oracle/raw-input extractor usage. This closes the v56 row-count target as local candidate-scale evidence, while keeping external benchmark, leaderboard, v52 LLM+RAG baseline-row, and release claims blocked.

Current v57 domain-pack progress: `experiments/test_v57b_domain_expert_pack_candidate_1000.sh` creates `results/v57b_domain_expert_pack_candidate_1000/candidate_001/` with 1000 source-span-bound candidate eval rows across six packs, 900 answer rows, 100 abstain rows, 1000 review-template rows, policy/rubric/failure-taxonomy rows, and hash manifests. This closes the candidate row-count surface, but v57 remains blocked until those rows are returned as human-reviewed expert evidence and then used in v58 blind evaluation.

Current v58 blind-eval progress: `experiments/test_v58b_blind_eval_candidate_500.sh` creates `results/v58b_blind_eval_candidate_500/candidate_001/` with 500 frozen source-span-bound blind queries, 2500 D/E/F/G/H response templates, 2500 anonymous reviewer-packet templates, sealed answer/identity keys, same-evidence-budget rows, adjudication templates, and hash manifests. This closes the pre-output query-freeze and review-intake surface, but v58 remains blocked until real 30B/70B responses, optional 100B+ response or final deferral, human blind review, and inter-rater/adjudication rows are supplied.

Current v58 response-intake progress: `experiments/test_v58c_blind_response_evidence_intake.sh` creates `results/v58c_blind_response_evidence_intake/intake_001/` with a 2500-row blind response template, run-identity template, required field schema, validation rows, gate rows, and hash manifest over the v58b frozen query set. It keeps D/E/G/H/F response readiness blocked until real supplied response rows validate, and still requires human blind review before v58 can close.

Current v59 one-command progress: `experiments/test_v59c_one_command_measured_registry_demo.sh` verifies `examples/v1_0_architecture_challenge_measured_registry_demo.sh`, which assembles `results/v59c_one_command_measured_registry_demo/measured_registry_001/` from the v52j measured registry plus the current v53e-v58c candidate chain. It hash-binds the local A/B/G/H 1000-query measured registry into one-command replay while preserving `v59_ready=0`, C/D/E blockers, complete-source audit blockers, human review blockers, and release blockers.

Current v60 release-preflight progress: `experiments/test_v60b_release_preflight_candidate_audit.sh` creates `results/v60b_release_preflight_candidate_audit/preflight_001/` from the v59b candidate replay. It writes release-preflight requirement rows, claim rows, stage release-audit rows, decision rows, boundary, manifest, and sha256 manifest. This closes candidate-chain release preflight, but v60 remains blocked until the real LLM rows, complete audit rows, human reviews, and release package exist.

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
- h7 route-memory closure is current through h7-c. The closure still keeps `default_promotion=0`, `status=diagnostic-only`, `routing_trigger_rate=0`, and `active_jump_rate=0`. The positive chunk-credit and learned scorer results are therefore guarded diagnostic route-memory policies, not default sparse-routing policies.
- v08-aa is closed as the external-benchmark source-acquisition/content boundary. v08-m through v08-w carry source-import from contract, live verifier/review, authoritative review, public registry, live registry query, fetch/cache, live-registry network proof, real verification, and official source authority; v08-x adds the result/leaderboard authority layer; v08-y adds the publication-package layer; v08-z separately requires official benchmark source acquisition packages for RULER, LongBench, codebase retrieval, and real document QA; and v08-aa binds those acquisition URI/hash manifests to supplied source landing, dataset, benchmark-card, split-manifest, license, and metric-spec cache files. Matching cache content can reach `external_benchmark_source_acquisition_content_ready=1`, but still keeps `real_external_benchmark_verified=0` until source import/result/review/publication evidence is connected.
- v08-ab is closed as the first codebase-mini benchmark instrumentation layer over real local repository files. It generates a `codebase-retrieval` artifact package with `source_manifest.json`, `dataset.jsonl`, split/license/metric specs, BM25/symbolic/RouteMemory baselines, result artifacts, and `sha256sums.txt`, then binds it to the h11-c RouteMemory store. The smoke verifies four local source files, seven query rows, ten artifact hashes, `span_exact=1.000000`, `chunk_exact=1.000000`, `missing_abstain=1.000000`, `wrong_answer_rate=0.000000`, `routing_trigger_rate=0`, and `active_jump_rate=0`, while still keeping `real_external_benchmark_verified=0` because local codebase instrumentation is not an independent external benchmark review/publication chain.
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
  `logdet=-5.818573` vs `-15.330912`, condition `7.050210` vs `52.270703`).
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
