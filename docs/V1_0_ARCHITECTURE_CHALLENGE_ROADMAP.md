# v1.0 Architecture Challenge Roadmap

This roadmap supersedes publishing v0.3 as a broad public claim. v0.3 remains a clone-and-run architecture preview. The public challenge moment should be v1.0, after the repository can compare RouteMemory + RouteHint against 30B-150B-class LLM+RAG systems on code/doc QA with machine-verifiable lineage, citations, abstention, and scaling evidence.

## Public Timing

Do not position v0.3 as a disruptive public result. Position it as an internal preview and evidence surface.

The public target is:

```text
v1.0 Architecture Challenge:
RouteMemory + RouteHint versus 30B-150B-class LLM+RAG baselines
on source-cited code/doc QA, grounded generation, scaling, and one-command reproducibility.
```

The v1.0 claim must stay bounded:

- allowed: local evidence-bound QA/audit architecture, source-cited answers, abstention, deterministic lineage, RouteHint generation, scaling evidence
- blocked until proven: general LLM replacement, Transformer replacement, frontier local LLM, expert replacement, GPU speedup, production release readiness

## PM Execution Order

The current v52-v60/v61 work should be reviewed as small claim-bound slices,
not as one broad draft PR. Keep v61 as a separate R&D option until the v52-v60
v1.0 evidence path is ready.

The machine-readable slice ledger is emitted by
`experiments/run_v1_0_pm_pr_claim_slice_gate.sh`. It writes
`pm_pr_slice_rows.csv`, `pm_pr_merge_gate_rows.csv`, a claim-boundary file, and
a sha256 manifest. Merge readiness is intentionally defined by claim boundary,
replayable artifacts, and false-positive blocker closure rather than by tests
alone.

Recommended review slices:

| Slice | Scope | Merge condition |
| --- | --- | --- |
| `docs/v1-roadmap` | roadmap, claim boundary, release blockers | allowed and blocked claims are explicit |
| `v52-baseline-registry-contract` | A-H baseline registry/schema contract | replayable output schema and symmetric verifier contract exist |
| `v53-public-repo-source-manifest` | pinned 10+ repo source manifest | commits, licenses, source files, and hashes are bound |
| `v53-query-instantiation-1000` | 1000 source-span-bound query rows | every query binds to a pinned source span and control rows are explicit |
| `v53-system-a-b-g-h-measured` | same-query A/B/G/H pre-baseline rows | internal-only comparison wording, no D/E public comparison claim |
| `v54-routehint-generation-contract` | grounded RouteHint generation contract | raw prompt stuffing remains zero and unsupported answers are guarded |
| `v56-ruler-longbench-expanded` | source/evaluator-bound benchmark expansion | official source/evaluator hashes and raw prediction rows are replayable |
| `v58-blind-eval-contract` | blind evaluation contract | identity hiding, symmetric citation verification, and failure rows exist |
| `v59-one-command-demo` | reviewer command and artifact bundle | no private fixture, local state, or manual post-processing is required |
| `v61-ssd-moe-runtime-roadmap` | SSD-resident runtime R&D roadmap | no dense local speed, near-frontier, or release-ready claim is implied |

The PM PR claim-slice gate emits both machine-readable ledgers and ten local
review packet markdown files under `results/v1_0_pm_pr_claim_slice_gate/gate_001/review_packets/`.
Those packets are draft PR-body material only; they do not push, open, merge,
or publish any PR. The same gate also emits six local blocker-closure packets
under `results/v1_0_pm_pr_claim_slice_gate/gate_001/blocker_packets/` for the
approval-required v56 replay, D/E 30B/70B, h10 real-label, v58c/v58d intake artifacts,
v58 blind-eval, and v60 release blockers. The `pm_execution_lock_rows.csv` ledger locks the team to
closing v52-v60/v61 review slices and real evidence blockers, with default
v62/v63 scaffold drift disallowed. The gate also emits 24 no-fixture external
return templates under `return_templates/` so D/E, h10, v58c, v58/v58d, v59e
preflight, v56, and v60 evidence can be supplied in the expected shape without
changing protocols.
The v59e PM foundation one-command bundle refreshes this gate and copies those
review packets, blocker packets, execution locks, and return templates under
`source_pm_pr_claim_slice_gate/` so the PM split is replayable from the same
local bundle while still blocking release and public-comparison claims.

The first execution priority is v53: freeze the complete-source 1000-row
benchmark surface, then close an A/B/G/H same-query deterministic source-span
adapter run over that surface. D/E 30B/70B rows, h10 source-verified scorer promotion, v54
generation, v58 blind eval, and v59 public demo become meaningful only after
that source/query/evaluator foundation is stable. The v53t audit gate now emits
`complete_source_foundation_freeze_rows.csv` as the explicit PM certificate for
that foundation: 10 pinned public repositories, 1000 source-span-bound queries,
10%+ negative/abstain controls, unsupported/missing/doc-code-conflict rows,
direct copied query/span evidence, 4000 direct separate answer/citation/resource
evaluator rows, A/B/G/H same-query deterministic source-span adapter/evaluator rows, replay
hashes, and a closed public-comparison boundary. It also emits
`complete_source_abgh_real_adapter_freeze_rows.csv` to bind the v53aq
sanitized-question-only real-adapter evidence into the same PM freeze packet without
opening public-comparison wording. The h10 PM real-label
readiness gate now makes the scorer-promotion blocker explicit: provenance,
v53ap adapter trace, v53aq sanitized-question-only real-adapter wrong-key/provenance
evidence, missing/abstain, and wrong-answer guard surfaces can be machine-bound,
but promotion remains blocked without accepted external/human label evidence and
h10 source-verified eval readiness.

## Baseline Matrix

Every v1.0 comparison run should emit the same query IDs, source manifests, answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, and sha256 manifest for all baselines.

| ID | System | Required Status |
| --- | --- | --- |
| A | BM25 / lexical | required |
| B | small local RAG | required |
| C | 7B-14B local model + RAG | required |
| D | 30B open-weight LLM + RAG | required |
| E | 70B open-weight LLM + RAG | required |
| F | 100B+ API or hosted model + RAG | optional but preferred |
| G | RouteMemory + RouteHint | required |
| H | RouteMemory + RouteHint + source-verified scorer + domain policy | required |

The challenge is not won by raw answer rate alone. It must score answer accuracy, citation correctness, unsupported-claim abstention, wrong-answer guard behavior, source lineage, replayability, resource envelope, and privacy/locality boundary.

## Exit Criteria

v1.0 can be called an Architecture Challenge release only when all of these are true:

- 30B, 70B, and preferably 100B+ LLM+RAG baselines are present as real rows, not placeholders.
- Public repo code/doc QA covers 10-30 repositories and 1000-3000 query rows.
- RouteHint non-attention generation covers at least 1000 generation rows.
- Local scaling law runs cover store size, top-k, cache budget, RouteHint budget, query count, and repository count.
- RULER/LongBench expanded benchmark evidence is source/evaluator bound.
- Domain expert packs have domain policies, query sets, acceptance rows, and source-cited failure modes.
- Blind evaluation compares G/H against the 30B-150B-class systems without cherry-picking.
- A one-command challenge demo reproduces the public subset and writes a reviewer-ready artifact bundle.
- The claim audit still blocks Transformer replacement, frontier local LLM, GPU speedup, and production release wording unless separate evidence proves them.

## v52: 30B/70B/100B+ LLM+RAG Baseline War

Goal:

- Build the real baseline-war layer against A-H, with D/E required and F preferred.
- Keep all systems on the same source corpus, query set, answer schema, evaluator, citation verifier, and resource manifest.

Implementation objectives:

- Add a baseline registry with model/provider identity, model size class, quantization or API mode, prompt template, retrieval backend, context budget, and cost/resource fields.
- Implement adapters for lexical/BM25, small local RAG, 7B-14B local RAG, 30B RAG, 70B RAG, optional 100B+ hosted/API RAG, RouteMemory + RouteHint, and RouteMemory + RouteHint + scorer/policy.
- Emit per-baseline `answer_rows.csv`, `citation_rows.csv`, `abstain_rows.csv`, `wrong_answer_guard_rows.csv`, `resource_rows.csv`, and `baseline_manifest.json`.
- Add a comparison report that separates answer correctness from citation correctness and unsupported-claim behavior.

Acceptance gates:

- `baseline_system_rows >= 8`
- `required_30b_baseline_ready=1`
- `required_70b_baseline_ready=1`
- `optional_100b_plus_baseline_status in {ready, deferred-with-reason}`
- `same_query_set_all_required_systems=1`
- `same_source_manifest_all_required_systems=1`
- `routehint_no_raw_prompt_stuffing=1`
- `release_ready_claim=0`

Stop rule:

- Do not publish comparison language if D or E is missing, if the LLM baselines use a weaker source corpus than RouteMemory, or if citation verification is not symmetric.
- Do not run implicit public-source refresh for D/E intake; missing v50 seed artifacts must remain a replayable dependency blocker unless `V52D_ALLOW_V50_REFRESH=1` is explicitly approved.
- Do not accept placeholder, fixture, dummy, or test-only D/E model identity, license, or model-artifact hashes as real baseline evidence.

## v53: Public Repo 10-30 Repo, 1000-3000 Query Code/Doc Audit

Goal:

- Move from 3 public repos and preview-scale audit to a credible public code/doc QA benchmark.

Implementation objectives:

- Select 10-30 pinned public repositories with licenses, commit SHAs, language/domain tags, and source manifests.
- Generate 1000-3000 query rows across API behavior, docs, config, deprecations, examples, tests, doc-code conflicts, and unsupported claims.
- Include negative and abstain rows for misleading docs, missing APIs, version mismatch, and ambiguous source evidence.
- Emit repository-level and aggregate audit reports.

Acceptance gates:

- `public_repo_count >= 10`
- `query_rows >= 1000`
- `source_span_bound_rows == query_rows`
- `negative_control_rows >= 10% of query_rows`
- `abstain_policy_verified=1`
- `wrong_answer_guard_verified=1`
- `pinned_commit_manifest_ready=1`

Stop rule:

- Do not count generated queries unless they are traceable to pinned files and independently reproducible from the source manifest.

## v54: RouteHint Non-Attention Generator 1000+ Rows

Goal:

- Promote RouteHint generation from mainline preview to a 1000+ row evidence run.

Implementation objectives:

- Run RouteMemory evidence -> compact RouteHint -> non-attention generator -> grounded answer across codebase QA, internal docs QA, product/manual QA, incident-log QA, RULER, and LongBench-style rows.
- Keep raw context out of the prompt payload. The generator may receive compact hints, source IDs, scores, and citation handles, not stuffed spans.
- Emit grounded generation rows, citation rows, unsupported-claim rows, abstain rows, and generator resource rows.

Acceptance gates:

- `generation_rows >= 1000`
- `attention_blocks=0`
- `transformer_blocks=0`
- `raw_prompt_context_appended_rows=0`
- `proposal_hint_used_rows == generation_rows`
- `citation_accuracy_ready=1`
- `missing_query_abstention_ready=1`

Stop rule:

- Do not call the generator mainline if it answers by copying raw retrieved context into the prompt or if unsupported claims are not explicitly guarded.

## v55: Local Scaling Law Main Run

Goal:

- Replace the preview scaling matrix with a main scaling law over real code/doc workloads.

Implementation objectives:

- Sweep repository count, source bytes, store size, top-k, cache budget, RouteHint budget, query count, and generator rows.
- Record active bytes/query, query-to-evidence latency, query-to-first-token latency, tokens/sec where applicable, CPU time, memory, storage reads, and cache hit rate.
- Fit bounded scaling curves with confidence intervals and failure cases.

Acceptance gates:

- `scaling_axis_count >= 6`
- `scaling_curve_rows >= 100`
- `repo_count_axis_ready=1`
- `store_size_axis_ready=1`
- `query_count_axis_ready=1`
- `resource_envelope_bound=1`
- `claim_boundary_written=1`

Stop rule:

- Do not claim scaling law if the run is only a one-repository local preview or if resource rows are not hash-bound to the same run.

## v56: RULER/LongBench Expanded Benchmark

Goal:

- Expand the official benchmark-facing layer beyond small slices while preserving no-oracle/no-raw-input-extractor lineage.

Implementation objectives:

- Run expanded RULER NIAH and LongBench subsets with official source snapshots, evaluator hashes, split manifests, raw prediction rows, RouteMemory lineage, metrics, and provenance.
- Include LLM+RAG baseline rows from v52 where allowed by the benchmark format.
- Keep source/result bridges ready for independent review.
- Reuse existing seed/contract replay artifacts by default; opt into seed or contract regeneration only after the runtime/resource budget is explicitly approved.

Acceptance gates:

- `ruler_expanded_rows_ready=1`
- `longbench_expanded_rows_ready=1`
- `official_source_hash_bound=1`
- `official_evaluator_hash_bound=1`
- `oracle_prediction_used=0`
- `raw_input_extractor_used=0`
- `real_external_benchmark_verified` remains `0` unless independently returned evidence is supplied.

Stop rule:

- Do not use benchmark score claims without official source/evaluator binding and reproducible raw prediction rows.
- Do not let the v56/v56b smoke path silently regenerate v49/v45/v34/v33 benchmark packets.

## v57: Domain Expert Packs

Goal:

- Turn code/doc QA into domain-specific evidence packs without claiming expert replacement.

Implementation objectives:

- Prepare domain packs for codebase QA, internal docs QA, product/manual QA, incident-log QA, and at least one regulated/compliance-style audit domain.
- Each pack must define domain policy, source admissibility, abstention rules, wrong-answer guards, query templates, acceptance rows, privacy/resource notes, and failure modes.
- Bind each pack to RouteMemory + RouteHint + scorer/policy evidence.

Acceptance gates:

- `domain_pack_rows >= 5`
- `domain_policy_rows_ready=1`
- `acceptance_rows_ready=1`
- `privacy_boundary_ready=1`
- `expert_replacement_claim=0`

Stop rule:

- Do not market domain packs as expert systems. They are evidence-bound assistant/audit packs until human or buyer acceptance returns prove more.

## v58: Blind Eval vs 30B-150B-Class Systems

Goal:

- Run blind evaluation between G/H and the 30B-150B-class LLM+RAG systems.

Implementation objectives:

- Freeze source corpus, query set, system registry, evaluation rubric, random seeds, and answer schema before generation.
- Hide system identity from the evaluator where possible.
- Evaluate correctness, citation support, abstention, unsupported claim behavior, failure explanation quality, replayability, and resource/cost envelope.

Acceptance gates:

- `blind_eval_query_rows >= 500`
- `system_identity_hidden_from_evaluator=1` where evaluator workflow allows it
- `all_required_systems_present=1`
- `citation_verifier_symmetric=1`
- `routehint_advantage_rows_ready=1`
- `failure_case_report_ready=1`

Stop rule:

- Do not use blind-eval claims if query selection happened after seeing model outputs or if the evaluator receives asymmetric evidence.

## v59: One-Command LLM Challenge Demo

Goal:

- Package a public reviewer command that reproduces a bounded subset of v52-v58.

Implementation objectives:

- Add one command that downloads or verifies pinned public sources, builds RouteMemory artifacts, runs required local baselines, runs available model adapters or marks deferred adapters explicitly, executes evaluator checks, and writes a challenge bundle.
- The bundle should include README, source manifest, query set, baseline registry, answer/citation/abstain rows, metrics, resource rows, claim boundary, failure cases, and sha256 manifest.

Acceptance gates:

- `one_command_challenge_demo_ready=1`
- `clean_machine_runbook_ready=1`
- `deferred_external_model_rows_explicit=1`
- `sha256_manifest_ready=1`
- `claim_audit_ready=1`

Stop rule:

- Do not make v1.0 public if the challenge requires undocumented local state, private fixtures, or manual post-processing.

## v60: v1.0 Architecture Challenge Release

Goal:

- Release the Architecture Challenge package with bounded, verifiable claims.

Implementation objectives:

- Freeze the v1.0 artifact directory.
- Run completion audit across v52-v59.
- Produce a public README, Korean README update, claim matrix, reviewer guide, reproduction guide, and release notes.
- Include explicit blocked-claim rows and remaining evidence gaps.

Acceptance gates:

- `v52_ready=1`
- `v53_ready=1`
- `v54_ready=1`
- `v55_ready=1`
- `v56_ready=1`
- `v57_ready=1`
- `v58_ready=1`
- `v59_ready=1`
- `v1_0_architecture_challenge_ready=1`
- `real_release_package_ready` only becomes `1` if the human/release-review ladder is also satisfied.

Stop rule:

- If the 30B/70B baselines, 1000+ generation rows, 10+ public repos, blind eval, or one-command demo are missing, the result remains a pre-v1.0 research artifact.

## Current v52-v60 Scaffold

Implemented now:

- `experiments/run_v1_0_pm_pr_claim_slice_gate.sh`
- `experiments/test_v1_0_pm_pr_claim_slice_gate.sh`
- `experiments/run_v52_llm_rag_baseline_war.sh`
- `experiments/test_v52_llm_rag_baseline_war.sh`
- `experiments/run_v52b_small_local_rag_measured_row.sh`
- `experiments/test_v52b_small_local_rag_measured_row.sh`
- `experiments/run_v52f_small_local_rag_measured_100.sh`
- `experiments/test_v52f_small_local_rag_measured_100.sh`
- `experiments/run_v52g_small_local_rag_measured_300.sh`
- `experiments/test_v52g_small_local_rag_measured_300.sh`
- `experiments/run_v52h_small_local_rag_measured_1000.sh`
- `experiments/test_v52h_small_local_rag_measured_1000.sh`
- `experiments/run_v52i_abgh_same_query_measured_1000.sh`
- `experiments/test_v52i_abgh_same_query_measured_1000.sh`
- `experiments/run_v52j_measured_registry_absorb.sh`
- `experiments/test_v52j_measured_registry_absorb.sh`
- `experiments/run_v52c_7b14b_local_model_rag_evidence_intake.sh`
- `experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh`
- `experiments/run_v52k_7b14b_local_model_rag_measured_seed.sh`
- `experiments/test_v52k_7b14b_local_model_rag_measured_seed.sh`
- `experiments/run_v52l_7b14b_local_model_rag_v53e_1000.sh`
- `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh`
- `experiments/run_v52m_measured_registry_c_absorb.sh`
- `experiments/test_v52m_measured_registry_c_absorb.sh`
- `experiments/run_v52n_30b_open_weight_llm_rag_measured_seed.sh`
- `experiments/test_v52n_30b_open_weight_llm_rag_measured_seed.sh`
- `experiments/run_v52o_70b_open_weight_llm_rag_measured_seed.sh`
- `experiments/test_v52o_70b_open_weight_llm_rag_measured_seed.sh`
- `experiments/run_v52p_30b_open_weight_llm_rag_v53e_1000.sh`
- `experiments/test_v52p_30b_open_weight_llm_rag_v53e_1000.sh`
- `experiments/run_v52q_70b_open_weight_llm_rag_v53e_1000.sh`
- `experiments/test_v52q_70b_open_weight_llm_rag_v53e_1000.sh`
- `experiments/run_v52r_measured_registry_de_absorb.sh`
- `experiments/test_v52r_measured_registry_de_absorb.sh`
- `experiments/run_v52s_local_llm_weight_tier_contract.sh`
- `experiments/test_v52s_local_llm_weight_tier_contract.sh`
- `experiments/run_v52u_local_llm_weight_tier_mmap_reader.sh`
- `experiments/test_v52u_local_llm_weight_tier_mmap_reader.sh`
- `experiments/run_v52t_de_local_measured_deferral.sh`
- `experiments/test_v52t_de_local_measured_deferral.sh`
- `experiments/run_v52v_local_llm_weight_tier_rocm_decode_bind.sh`
- `experiments/test_v52v_local_llm_weight_tier_rocm_decode_bind.sh`
- `scripts/ollama_rocm_env.sh`
- `scripts/ensure_rocm_device_libs.sh`
- `experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh`
- `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh`
- `experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`
- `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`
- `experiments/run_v52y_f_optional_final_policy.sh`
- `experiments/test_v52y_f_optional_final_policy.sh`
- `experiments/run_v53_public_repo_code_doc_audit.sh`
- `experiments/test_v53_public_repo_code_doc_audit.sh`
- `experiments/run_v53b_public_repo_10_lock.sh`
- `experiments/test_v53b_public_repo_10_lock.sh`
- `experiments/run_v53c_public_repo_canary_source_snapshot.sh`
- `experiments/test_v53c_public_repo_canary_source_snapshot.sh`
- `experiments/run_v53d_canary_source_query_seed_100.sh`
- `experiments/test_v53d_canary_source_query_seed_100.sh`
- `experiments/run_v53e_canary_query_scale_1000.sh`
- `experiments/test_v53e_canary_query_scale_1000.sh`
- `experiments/run_v53f_ah_answer_citation_resource_intake.sh`
- `experiments/test_v53f_ah_answer_citation_resource_intake.sh`
- `experiments/run_v53g_complete_source_manifest.sh`
- `experiments/test_v53g_complete_source_manifest.sh`
- `experiments/run_v53h_complete_source_content_snapshot.sh`
- `experiments/test_v53h_complete_source_content_snapshot.sh`
- `experiments/run_v53i_complete_source_query_instantiation.sh`
- `experiments/test_v53i_complete_source_query_instantiation.sh`
- `experiments/run_v53j_complete_source_ah_answer_citation_resource_intake.sh`
- `experiments/test_v53j_complete_source_ah_answer_citation_resource_intake.sh`
- `experiments/run_v53k_complete_source_system_a_lexical_measured.sh`
- `experiments/test_v53k_complete_source_system_a_lexical_measured.sh`
- `experiments/run_v53l_complete_source_system_b_local_rag_measured.sh`
- `experiments/test_v53l_complete_source_system_b_local_rag_measured.sh`
- `experiments/run_v53m_complete_source_system_c_local_model_rag_measured.sh`
- `experiments/test_v53m_complete_source_system_c_local_model_rag_measured.sh`
- `experiments/run_v53n_complete_source_system_g_routehint_measured.sh`
- `experiments/test_v53n_complete_source_system_g_routehint_measured.sh`
- `experiments/run_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
- `experiments/test_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh`
- `experiments/run_v53ap_complete_source_abgh_same_query_measured.sh`
- `experiments/test_v53ap_complete_source_abgh_same_query_measured.sh`
- `experiments/run_v53p_complete_source_system_de_open_weight_rag_measured.sh`
- `experiments/test_v53p_complete_source_system_de_open_weight_rag_measured.sh`
- `experiments/run_v53q_complete_source_symmetric_scorer_policy.sh`
- `experiments/test_v53q_complete_source_symmetric_scorer_policy.sh`
- `experiments/run_v53r_complete_source_review_packet.sh`
- `experiments/test_v53r_complete_source_review_packet.sh`
- `experiments/run_v53s_complete_source_review_return_intake.sh`
- `experiments/test_v53s_complete_source_review_return_intake.sh`
- `experiments/run_v53t_complete_source_audit_readiness_gate.sh`
- `experiments/test_v53t_complete_source_audit_readiness_gate.sh`
- `experiments/run_v61q_real_checkpoint_page_map.sh`
- `experiments/test_v61q_real_checkpoint_page_map.sh`
- `experiments/run_v61r_full_page_hash_sweep_plan.sh`
- `experiments/test_v61r_full_page_hash_sweep_plan.sh`
- `experiments/test_v61r_full_page_hash_sweep_plan_target_override.sh`
- `experiments/run_v61s_one_command_source_bound_qa_replay.sh`
- `experiments/test_v61s_one_command_source_bound_qa_replay.sh`
- `experiments/run_v61t_local_checkpoint_materialization_verifier.sh`
- `experiments/test_v61t_local_checkpoint_materialization_verifier.sh`
- `experiments/test_v61t_local_checkpoint_materialization_verifier_target_override.sh`
- `experiments/run_v61u_remote_checkpoint_page_hash_sampler.sh`
- `experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh`
- `experiments/run_v61v_remote_page_tensor_binding.sh`
- `experiments/test_v61v_remote_page_tensor_binding.sh`
- `experiments/run_v61w_materialization_admission_resume_plan.sh`
- `experiments/test_v61w_materialization_admission_resume_plan.sh`
- `experiments/test_v61w_materialization_admission_resume_plan_target_override.sh`
- `experiments/run_v61x_hotset_runtime_replay_manifest.sh`
- `experiments/test_v61x_hotset_runtime_replay_manifest.sh`
- `experiments/run_v61y_hotset_local_materialization_verifier.sh`
- `experiments/test_v61y_hotset_local_materialization_verifier.sh`
- `experiments/run_v61z_hotset_direct_io_replay.sh`
- `experiments/test_v61z_hotset_direct_io_replay.sh`
- `experiments/run_v61aa_hotset_tensor_slice_verifier.sh`
- `experiments/test_v61aa_hotset_tensor_slice_verifier.sh`
- `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`
- `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`
- `experiments/run_v61ac_hotset_token_budget_replay.sh`
- `experiments/test_v61ac_hotset_token_budget_replay.sh`
- `experiments/run_v61ad_kv_weight_token_budget_replay.sh`
- `experiments/test_v61ad_kv_weight_token_budget_replay.sh`
- `experiments/run_v61ae_real_generation_admission_gate.sh`
- `experiments/test_v61ae_real_generation_admission_gate.sh`
- `experiments/test_v61ae_real_generation_admission_gate_target_override.sh`
- `experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh`
- `experiments/test_v61af_checkpoint_warehouse_operator_bundle.sh`
- `experiments/test_v61af_checkpoint_warehouse_operator_bundle_target_override.sh`
- `experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh`
- `experiments/test_v61ag_checkpoint_warehouse_execution_preflight.sh`
- `experiments/test_v61ag_checkpoint_warehouse_execution_preflight_target_override.sh`
- `experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh`
- `experiments/test_v61ah_checkpoint_download_backend_fallback_plan.sh`
- `experiments/test_v61ah_checkpoint_download_backend_fallback_plan_target_override.sh`
- `experiments/run_v61ai_checkpoint_storage_budget_remediation_plan.sh`
- `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan.sh`
- `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan_target_override.sh`
- `experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh`
- `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix.sh`
- `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix_target_override.sh`
- `experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh`
- `experiments/test_v61ak_checkpoint_warehouse_target_preflight.sh`
- `experiments/run_v61al_checkpoint_warehouse_activation_gate.sh`
- `experiments/test_v61al_checkpoint_warehouse_activation_gate.sh`
- `experiments/test_v61al_checkpoint_warehouse_activation_gate_target_override.sh`
- `experiments/run_v61am_checkpoint_post_activation_verification_gate.sh`
- `experiments/test_v61am_checkpoint_post_activation_verification_gate.sh`
- `experiments/test_v61am_checkpoint_post_activation_verification_gate_target_override.sh`
- `experiments/run_v61an_checkpoint_full_page_hash_execution_gate.sh`
- `experiments/test_v61an_checkpoint_full_page_hash_execution_gate.sh`
- `experiments/test_v61an_checkpoint_full_page_hash_execution_gate_target_override.sh`
- `experiments/run_v61ao_real_model_page_manifest_coverage_audit.sh`
- `experiments/test_v61ao_real_model_page_manifest_coverage_audit.sh`
- `experiments/run_v61ap_moe_coverage_remote_hash_plan.sh`
- `experiments/test_v61ap_moe_coverage_remote_hash_plan.sh`
- `experiments/run_v61aq_moe_remote_hash_execution_gate.sh`
- `experiments/test_v61aq_moe_remote_hash_execution_gate.sh`
- `experiments/run_v61ar_moe_remote_hash_result_intake.sh`
- `experiments/test_v61ar_moe_remote_hash_result_intake.sh`
- `experiments/run_v61as_hotset_reuse_admission_gate.sh`
- `experiments/test_v61as_hotset_reuse_admission_gate.sh`
- `experiments/run_v61at_prefetch_overlap_admission_gate.sh`
- `experiments/test_v61at_prefetch_overlap_admission_gate.sh`
- `experiments/run_v61au_prefetch_queue_depth_scheduler_gate.sh`
- `experiments/test_v61au_prefetch_queue_depth_scheduler_gate.sh`
- `experiments/run_v61av_async_prefetch_execution_probe.sh`
- `experiments/test_v61av_async_prefetch_execution_probe.sh`
- `experiments/run_v61aw_io_uring_registered_buffer_preflight.sh`
- `experiments/test_v61aw_io_uring_registered_buffer_preflight.sh`
- `experiments/run_v61ax_async_io_backend_selection_gate.sh`
- `experiments/test_v61ax_async_io_backend_selection_gate.sh`
- `experiments/run_v61ay_selected_backend_token_runtime_binding.sh`
- `experiments/test_v61ay_selected_backend_token_runtime_binding.sh`
- `experiments/run_v61az_ubuntu1_warehouse_target_admission.sh`
- `experiments/test_v61az_ubuntu1_warehouse_target_admission.sh`
- `experiments/run_v61ba_ubuntu1_activation_handoff_package.sh`
- `experiments/test_v61ba_ubuntu1_activation_handoff_package.sh`
- `experiments/run_v61bb_ubuntu1_write_sentinel_activation_probe.sh`
- `experiments/test_v61bb_ubuntu1_write_sentinel_activation_probe.sh`
- `experiments/run_v61bc_ubuntu1_sampled_hotset_materialization.sh`
- `experiments/test_v61bc_ubuntu1_sampled_hotset_materialization.sh`
- `experiments/run_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh`
- `experiments/test_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh`
- `experiments/run_v61be_ubuntu1_hotset_tensor_slice_verifier.sh`
- `experiments/test_v61be_ubuntu1_hotset_tensor_slice_verifier.sh`
- `experiments/run_v61bf_ubuntu1_tensor_tile_quant_probe.sh`
- `experiments/test_v61bf_ubuntu1_tensor_tile_quant_probe.sh`
- `experiments/run_v61bg_ubuntu1_token_budget_replay.sh`
- `experiments/test_v61bg_ubuntu1_token_budget_replay.sh`
- `experiments/run_v61bh_ubuntu1_kv_weight_token_budget_replay.sh`
- `experiments/test_v61bh_ubuntu1_kv_weight_token_budget_replay.sh`
- `experiments/run_v61bi_ubuntu1_hotset_reuse_admission_gate.sh`
- `experiments/test_v61bi_ubuntu1_hotset_reuse_admission_gate.sh`
- `experiments/run_v54_routehint_generation_1000_contract.sh`
- `experiments/test_v54_routehint_generation_1000_contract.sh`
- `experiments/run_v54b_routehint_generation_scale_1000.sh`
- `experiments/test_v54b_routehint_generation_scale_1000.sh`
- `experiments/run_v54c_complete_source_grounded_generation_1000.sh`
- `experiments/test_v54c_complete_source_grounded_generation_1000.sh`
- `experiments/run_v55_local_scaling_law_main_contract.sh`
- `experiments/test_v55_local_scaling_law_main_contract.sh`
- `experiments/run_v55b_local_scaling_law_main_120.sh`
- `experiments/test_v55b_local_scaling_law_main_120.sh`
- `experiments/run_v56_ruler_longbench_expanded_contract.sh`
- `experiments/test_v56_ruler_longbench_expanded_contract.sh`
- `experiments/run_v56b_ruler_longbench_expanded_scale.sh`
- `experiments/test_v56b_ruler_longbench_expanded_scale.sh`
- `experiments/run_v57_domain_expert_packs_contract.sh`
- `experiments/test_v57_domain_expert_packs_contract.sh`
- `experiments/run_v57b_domain_expert_pack_candidate_1000.sh`
- `experiments/test_v57b_domain_expert_pack_candidate_1000.sh`
- `experiments/run_v58_blind_eval_contract.sh`
- `experiments/test_v58_blind_eval_contract.sh`
- `experiments/run_v58b_blind_eval_candidate_500.sh`
- `experiments/test_v58b_blind_eval_candidate_500.sh`
- `experiments/run_v58c_blind_response_evidence_intake.sh`
- `experiments/test_v58c_blind_response_evidence_intake.sh`
- `experiments/run_v58d_blind_review_return_intake.sh`
- `experiments/test_v58d_blind_review_return_intake.sh`
- `examples/v1_0_architecture_challenge_demo.sh`
- `experiments/run_v59_one_command_challenge_demo_contract.sh`
- `experiments/test_v59_one_command_challenge_demo_contract.sh`
- `examples/v1_0_architecture_challenge_candidate_demo.sh`
- `experiments/run_v59b_one_command_candidate_demo.sh`
- `experiments/test_v59b_one_command_candidate_demo.sh`
- `examples/v1_0_architecture_challenge_measured_registry_demo.sh`
- `experiments/run_v59c_one_command_measured_registry_demo.sh`
- `experiments/test_v59c_one_command_measured_registry_demo.sh`
- `examples/v1_0_architecture_challenge_pm_foundation_demo.sh`
- `experiments/run_v59e_one_command_pm_foundation_demo.sh`
- `experiments/test_v59e_one_command_pm_foundation_demo.sh`
- `experiments/run_v60_architecture_challenge_release_contract.sh`
- `experiments/test_v60_architecture_challenge_release_contract.sh`
- `experiments/run_v60b_release_preflight_candidate_audit.sh`
- `experiments/test_v60b_release_preflight_candidate_audit.sh`
- `results/v52_llm_rag_baseline_war/baseline_001/` contract artifacts
- `results/v52b_small_local_rag_measured_row/row_001/` measured system-B seed artifacts
- `results/v52f_small_local_rag_measured_100/measured_001/` measured system-B 100-row frozen-query artifacts
- `results/v52g_small_local_rag_measured_300/measured_001/` measured system-B 300-row stratified frozen-query artifacts
- `results/v52h_small_local_rag_measured_1000/measured_001/` measured system-B 1000-row full frozen-query artifacts
- `results/v52i_abgh_same_query_measured_1000/measured_001/` local A/B/G/H same-query measured artifacts
- `results/v52j_measured_registry_absorb/registry_001/` v52 measured registry absorb artifacts
- `results/v52l_7b14b_local_model_rag_v53e_1000/measured_001/` real system-C Ollama v53e 1000-row measured artifacts
- `results/v52m_measured_registry_c_absorb/registry_001/` v52 measured registry with A/B/C/G/H absorb artifacts
- `results/v52n_30b_open_weight_llm_rag_measured_seed/measured_001/` real system-D Ollama v50 9-query measured seed artifacts
- `results/v52o_70b_open_weight_llm_rag_measured_seed/measured_001/` real system-E Ollama v50 9-query measured seed artifacts
- `results/v52p_30b_open_weight_llm_rag_v53e_1000/measured_001/` real system-D Ollama v53e 1000-row measured artifacts
- `results/v52q_70b_open_weight_llm_rag_v53e_1000/measured_001/` real system-E Ollama v53e 1000-row measured artifacts
- `results/v52r_measured_registry_de_absorb/registry_001/` v52 measured registry with A/B/C/D/E/G/H absorb artifacts
- `results/v52s_local_llm_weight_tier_contract/contract_001/` NVMe hot/warm/cold weight shard store contract artifacts
- `results/v52u_local_llm_weight_tier_mmap_reader/reader_001/` tiered weight mmap reader scaffold artifacts
- `results/v52t_de_local_measured_deferral/deferral_001/` D/E local monolithic measured deferral artifacts
- `results/v52v_local_llm_weight_tier_rocm_decode_bind/bind_001/` ROCm HIP kernel bind scaffold artifacts
- `results/v52c_7b14b_local_model_rag_evidence_intake/intake_001/` system-C evidence-intake artifacts
- `results/v52k_7b14b_local_model_rag_measured_seed/measured_001/` real system-C Ollama measured seed artifacts
- `results/v52d_30b70b_llm_rag_evidence_intake/intake_001/` system-D/E evidence-intake artifacts
- `results/v52e_100b_plus_hosted_llm_rag_optional_intake/intake_001/` system-F optional evidence-intake artifacts
- `results/v53_public_repo_code_doc_audit/audit_001/` contract artifacts
- `results/v53b_public_repo_10_lock/lock_001/` live 10-repo target-lock artifacts
- `results/v53c_public_repo_canary_source_snapshot/snapshot_001/` pinned canary source snapshot artifacts
- `results/v53d_canary_source_query_seed_100/query_001/` 100-row source-span-bound canary query seed artifacts
- `results/v53e_canary_query_scale_1000/scale_001/` 1000-row canary-scope source-span-bound query scale artifacts
- `results/v53f_ah_answer_citation_resource_intake/intake_001/` A-H answer/citation/resource intake artifacts
- `results/v53g_complete_source_manifest/manifest_001/` complete-source recursive Git tree manifest artifacts
- `results/v53h_complete_source_content_snapshot/snapshot_001/` complete-source content snapshot artifacts
- `results/v53i_complete_source_query_instantiation/instantiate_001/` complete-source 1000-query/source-span artifacts
- `results/v53j_complete_source_ah_answer_citation_resource_intake/intake_001/` complete-source A-H intake artifacts
- `results/v53k_complete_source_system_a_lexical_measured/measured_001/` complete-source System A lexical measured artifacts
- `results/v53l_complete_source_system_b_local_rag_measured/measured_001/` complete-source System B local-RAG measured artifacts
- `results/v53m_complete_source_system_c_local_model_rag_measured/measured_001/` complete-source System C local-model-RAG measured artifacts
- `results/v53n_complete_source_system_g_routehint_measured/measured_001/` complete-source System G RouteMemory+RouteHint measured artifacts
- `results/v53o_complete_source_system_h_routehint_scorer_policy_measured/measured_001/` complete-source System H RouteMemory+RouteHint+source-verified-scorer+domain-policy measured artifacts
- `results/v53p_complete_source_system_de_open_weight_rag_measured/measured_001/` complete-source System D/E open-weight RAG measured artifacts
- `results/v53q_complete_source_symmetric_scorer_policy/score_001/` complete-source symmetric scorer/policy artifacts
- `results/v53r_complete_source_review_packet/review_001/` complete-source review packet artifacts
- `results/v53s_complete_source_review_return_intake/intake_001/` complete-source review return intake artifacts
- `results/v53t_complete_source_audit_readiness_gate/gate_001/` complete-source audit readiness gate artifacts
- `results/v61q_real_checkpoint_page_map/map_001/` real safetensors-header-derived checkpoint page-map artifacts
- `results/v61r_full_page_hash_sweep_plan/plan_001/` full page-hash sweep plan artifacts
- `results/v61s_one_command_source_bound_qa_replay/replay_001/` one-command source-bound QA replay artifacts
- `results/v61t_local_checkpoint_materialization_verifier/verify_001/` local checkpoint materialization identity verifier artifacts
- `results/v61u_remote_checkpoint_page_hash_sampler/sample_001/` bounded remote checkpoint page-hash sample artifacts
- `results/v61v_remote_page_tensor_binding/binding_001/` remote-hashed page tensor/runtime-node binding artifacts
- `results/v61w_materialization_admission_resume_plan/plan_001/` materialization admission/download-resume plan artifacts
- `results/v61x_hotset_runtime_replay_manifest/hotset_001/` hotset runtime replay manifest artifacts
- `results/v61y_hotset_local_materialization_verifier/verify_001/` sampled hotset local materialization artifacts
- `results/v61z_hotset_direct_io_replay/replay_001/` sampled hotset direct-I/O replay artifacts
- `results/v61aa_hotset_tensor_slice_verifier/verify_001/` sampled hotset tensor-slice verifier artifacts
- `results/v61ab_hotset_tensor_tile_quant_probe/probe_001/` sampled hotset tensor-tile quant probe artifacts
- `results/v61ac_hotset_token_budget_replay/replay_001/` sampled hotset token-budget replay artifacts
- `results/v61ad_kv_weight_token_budget_replay/replay_001/` sampled KV+weight token-budget replay artifacts
- `results/v61ae_real_generation_admission_gate/gate_001/` real generation admission gate artifacts
- `results/v61af_checkpoint_warehouse_operator_bundle/operator_001/` guarded checkpoint warehouse operator bundle artifacts
- `results/v61ag_checkpoint_warehouse_execution_preflight/preflight_001/` checkpoint warehouse execution preflight artifacts
- `results/v61ah_checkpoint_download_backend_fallback_plan/plan_001/` checkpoint download backend fallback plan artifacts
- `results/v61ai_checkpoint_storage_budget_remediation_plan/plan_001/` checkpoint storage budget remediation plan artifacts
- `results/v61aj_checkpoint_storage_profile_admission_matrix/matrix_001/` checkpoint storage profile admission matrix artifacts
- `results/v61ak_checkpoint_warehouse_target_preflight/preflight_001/` checkpoint warehouse target preflight artifacts
- `results/v61al_checkpoint_warehouse_activation_gate/gate_001/` checkpoint warehouse activation gate artifacts
- `results/v61am_checkpoint_post_activation_verification_gate/gate_001/` checkpoint post-activation verification gate artifacts
- `results/v61an_checkpoint_full_page_hash_execution_gate/gate_001/` checkpoint full page-hash execution gate artifacts
- `results/v61ao_real_model_page_manifest_coverage_audit/audit_001/` real model page-manifest coverage audit artifacts
- `results/v61ap_moe_coverage_remote_hash_plan/plan_001/` MoE coverage remote-hash expansion plan artifacts
- `results/v61aq_moe_remote_hash_execution_gate/gate_001/` MoE remote-hash execution gate artifacts
- `results/v61ar_moe_remote_hash_result_intake/intake_001/` MoE remote-hash result intake artifacts
- `results/v61as_hotset_reuse_admission_gate/gate_001/` sampled hotset reuse admission artifacts
- `results/v61at_prefetch_overlap_admission_gate/gate_001/` sampled prefetch-overlap admission artifacts
- `results/v61au_prefetch_queue_depth_scheduler_gate/gate_001/` sampled prefetch queue-depth scheduler artifacts
- `results/v61av_async_prefetch_execution_probe/probe_001/` sampled async prefetch execution artifacts
- `results/v61aw_io_uring_registered_buffer_preflight/preflight_001/` io_uring registered-buffer preflight artifacts
- `results/v61ax_async_io_backend_selection_gate/gate_001/` async-I/O backend selection artifacts
- `results/v61ay_selected_backend_token_runtime_binding/binding_001/` selected-backend token runtime binding artifacts
- `results/v61az_ubuntu1_warehouse_target_admission/admission_001/` ubuntu-1 warehouse target admission artifacts
- `results/v61ba_ubuntu1_activation_handoff_package/handoff_001/` ubuntu-1 activation handoff artifacts
- `results/v61bb_ubuntu1_write_sentinel_activation_probe/write_probe_001/` ubuntu-1 write sentinel activation artifacts
- `results/v61bc_ubuntu1_sampled_hotset_materialization/materialization_001/` ubuntu-1 sampled hotset materialization artifacts
- `results/v61bd_ubuntu1_sampled_hotset_direct_io_replay/replay_001/` ubuntu-1 sampled hotset direct-I/O artifacts
- `results/v61be_ubuntu1_hotset_tensor_slice_verifier/verify_001/` ubuntu-1 sampled hotset tensor-slice artifacts
- `results/v61bf_ubuntu1_tensor_tile_quant_probe/probe_001/` ubuntu-1 sampled hotset tensor-tile quant artifacts
- `results/v61bg_ubuntu1_token_budget_replay/replay_001/` ubuntu-1 sampled hotset token-budget replay artifacts
- `results/v61bh_ubuntu1_kv_weight_token_budget_replay/replay_001/` ubuntu-1 sampled hotset KV+weight token-budget artifacts
- `results/v61bi_ubuntu1_hotset_reuse_admission_gate/gate_001/` ubuntu-1 sampled hotset reuse admission artifacts
- `results/v54_routehint_generation_1000_contract/contract_001/` contract artifacts
- `results/v54b_routehint_generation_scale_1000/scale_001/` 1000-row RouteHint generation scale artifacts
- `results/v54c_complete_source_grounded_generation_1000/generation_001/` 1000-row complete-source grounded generation artifacts
- `results/v55_local_scaling_law_main_contract/contract_001/` contract artifacts
- `results/v55b_local_scaling_law_main_120/main_001/` six-axis / 360-row local scaling-law main artifacts
- `results/v56_ruler_longbench_expanded_contract/contract_001/` contract artifacts
- `results/v56b_ruler_longbench_expanded_scale/scale_001/` 1500-row RULER/LongBench candidate-scale artifacts
- `results/v57_domain_expert_packs_contract/contract_001/` contract artifacts
- `results/v57b_domain_expert_pack_candidate_1000/candidate_001/` 1000-row domain expert pack candidate artifacts
- `results/v58_blind_eval_contract/contract_001/` contract artifacts
- `results/v58b_blind_eval_candidate_500/candidate_001/` 500-row blind query-freeze and reviewer-packet candidate artifacts
- `results/v58c_blind_response_evidence_intake/intake_001/` A/B/C/D/E/F/G/H blind response evidence-intake artifacts
- `results/v58d_blind_review_return_intake/intake_001/` blind review/adjudication return-intake artifacts
- `results/v59_one_command_challenge_demo_contract/contract_001/` contract artifacts
- `results/v59b_one_command_candidate_demo/candidate_001/` one-command candidate/intake-chain replay artifacts
- `results/v59c_one_command_measured_registry_demo/measured_registry_001/` one-command measured-registry replay artifacts
- `results/v59e_one_command_pm_foundation_demo/pm_foundation_001/` one-command PM foundation replay artifacts
- `results/v60_architecture_challenge_release_contract/contract_001/` contract artifacts
- `results/v60b_release_preflight_candidate_audit/preflight_001/` release preflight candidate-audit artifacts

This scaffold emits the A-H baseline registry, adapter contract rows, symmetric evaluation contract rows, score axes, source-preview copies, and claim boundary. It intentionally keeps `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `optional_100b_plus_baseline_status=deferred-with-reason`.

The v52b measured-row layer emits the first system-B small-local-RAG answer/citation/retrieval/resource rows over the v50 public-repo seed. It intentionally marks only `v52_absorb_ready=1`; it keeps `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and all 30B-150B comparison claims blocked.

The v52f measured-row layer expands system B to 100 rows over the frozen v53d query set. It emits source manifest rows, answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, retrieval rows, copied v53d query/source evidence, and a sha256 manifest. It intentionally marks only the B-100 layer absorb-ready; it keeps `v52_ready=0` and all 30B-150B comparison claims blocked until A/G/H run on the same query IDs and source manifest and C/D/E evidence directories validate.

The v52g measured-row layer expands system B to 300 rows over a stratified frozen subset of the v53e 1000-row canary query scale. It emits frozen query/source rows, source manifest rows, answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, retrieval rows, copied v53e query/source evidence, and a sha256 manifest. It intentionally marks only the B-300 layer absorb-ready; at the v52g layer, B-1000, A/G/H same-query-set rows, C/D/E evidence directories, `v52_ready=0`, and all 30B-150B comparison claims remained blocked.

The v52h measured-row layer expands system B to 1000 rows over the full frozen v53e canary query scale. It emits frozen query/source rows, source manifest rows, answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, retrieval rows, copied v53e query/source evidence, and a sha256 manifest. It closes the B 9->100->300->1000 measured ladder while intentionally keeping A/G/H same-query-set rows, C/D/E evidence directories, `v52_ready=0`, and all 30B-150B comparison claims blocked.

The v52i measured-row layer runs A/B/G/H over the same full frozen v53e canary query set and source manifest. It emits shared frozen query/source rows, source manifest rows, local system rows, answer rows, citation rows, abstain rows, wrong-answer guard rows, resource rows, retrieval rows, G/H RouteHint rows, per-system metrics, copied v53e evidence, and a sha256 manifest. It closes the local A/B/G/H same-query packet while intentionally keeping C/D/E evidence directories, required 30B/70B baselines, `v52_ready=0`, and all 30B-150B comparison claims blocked.

The v52j measured-registry layer absorbs the v52i A/B/G/H measured packet into a v52 baseline registry. It marks A/B/G/H as measured over the shared v53e query/source manifest, copies the measured artifacts, records C/D/E/F blockers, and intentionally keeps C/D/E evidence directories, required 30B/70B baselines, `v52_ready=0`, and all 30B-150B comparison claims blocked.

The v52c evidence-intake layer emits the system-C 7B-14B local-model-RAG schema, answer template, model identity template, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `supplied_evidence_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked until a real local model evidence directory validates.

The v52k measured-seed layer runs local Ollama `qwen2.5:7b-instruct` as baseline C over the v50 9-query public-repo seed, writes real answer/citation/resource rows, and validates the supplied evidence directory through v52c with `supplied_evidence_ready=1` and `v52c_absorb_ready=1`. It records 9 answer rows, 18 citation rows, 9 resource rows, and 6/9 measured label accuracy while intentionally keeping C-over-v53e scale, D/E 30B/70B rows, `v52_ready=0`, and all release/comparison claims blocked.

The v52l measured-scale layer runs local Ollama `qwen2.5:7b-instruct` as baseline C over the same frozen v53e 1000-query/source manifest used by v52i A/B/G/H. It records 1000 C answer rows, 1000 citation rows, 1000 retrieval rows, 1000 abstain rows, 1000 wrong-answer guard rows, 1000 resource rows, 1000 raw Ollama transcript rows, model identity, and sha256 manifests with `same_query_set_as_v52i_abgh=1`, `same_source_manifest_as_v52i_abgh=1`, and `c_v53e_absorb_ready=1`. It records 0/1000 strict exact-label accuracy, so it is a real C response packet and schema pressure test rather than a C quality claim; D/E 30B/70B rows, full registry re-absorb, `v52_ready=0`, and all release/comparison claims remained blocked at the v52l layer.

The v52m measured-registry layer absorbs the v52i A/B/G/H measured packet plus the v52l C measured packet into an updated v52 measured registry. It marks A/B/C/G/H as measured over the shared v53e query/source manifest, copies the v52i and v52l artifacts, records 5000 answer/citation/abstain/guard/resource rows, sets `required_7b14b_baseline_ready=1`, and records `c_strict_exact_label_accuracy=0.000000` without turning that into a C performance claim. It intentionally keeps D/E evidence directories, required 30B/70B baselines, `v52_ready=0`, and all 30B-150B comparison claims blocked.

The v52n measured-seed layer runs local Ollama `qwen2.5:32b-instruct` as baseline D over the v50 9-query public-repo seed, writes real answer/citation/resource rows, and validates the supplied evidence directory through v52d with `d_30b_supplied_evidence_ready=1`. It records 9 answer rows, 18 citation rows, and 9 resource rows while intentionally keeping D-over-v53e scale, E 70B rows, `v52_ready=0`, and all release/comparison claims blocked.

The v52o measured-seed layer runs local Ollama `llama3.1:70b-instruct-q2_K` as baseline E over the v50 9-query public-repo seed, writes real answer/citation/resource rows, and validates through v52d with `e_70b_supplied_evidence_ready=1`. It records 9 answer rows, 18 citation rows, and 9 resource rows while intentionally keeping E-over-v53e scale, D 30B real row, `v52_ready=0`, and all release/comparison claims blocked.

The v52p measured-scale layer runs local Ollama `qwen2.5:32b-instruct` as baseline D over the same frozen v53e 1000-query/source manifest used by v52i A/B/G/H. It records 1000 D answer/citation/retrieval/abstain/wrong-answer/resource/transcript rows with `same_query_set_as_v52i_abgh=1`, `same_source_manifest_as_v52i_abgh=1`, and `d_v53e_absorb_ready=1`. Strict exact-label accuracy is recorded without turning it into a D quality claim; E 70B rows, full registry re-absorb, `v52_ready=0`, and all release/comparison claims remain blocked at the v52p layer.

The v52q measured-scale layer runs local Ollama `llama3.1:70b-instruct-q2_K` as baseline E over the same frozen v53e manifest with `e_v53e_absorb_ready=1`. D 30B rows, full registry re-absorb, `v52_ready=0`, and all release/comparison claims remain blocked at the v52q layer.

The v52s weight-tier contract layer emits an NVMe-mmap hot/warm/cold weight shard store aligned with the h11-c RouteMemory store pattern. It marks `nvme_mmap_store_ready=1` while keeping tiered decode runtime, monolithic Ollama D/E measured rows, and release claims blocked.

The v52u mmap-reader layer mmap-opens the v52s shard store, verifies page headers and hashes, and emits hot/warm/cold read traces plus a warm-prefetch decode scaffold following the v13-b reader ABI shape. It marks `weight_tier_mmap_reader_ready=1` while keeping ROCm kernel binding, D/E measured rows, and release claims blocked.

The v52v ROCm bind layer sources `scripts/ollama_rocm_env.sh`, compiles a diagnostic HIP axpy probe, and binds v52u vram-hot decode scaffold rows while keeping full tiered LLM decode runtime blocked.

The v52t deferral layer records explicit `deferred-with-reason` status for local monolithic Ollama D/E measured rows on 16GB VRAM hosts and links the v52s/v52u/v52v replacement path while keeping required 30B/70B baselines blocked.

The v52r measured-registry layer absorbs the v52i A/B/G/H measured packet plus the v52l C and v52p/v52q D/E artifact packets into an updated v52 measured registry. It marks A/B/C/D/E/G/H as artifact-backed over the shared v53e query/source manifest, copies v52i/v52l/v52p/v52q artifacts, records 7000 answer/citation/abstain/guard/resource rows when the source packets exist, and records C/D/E strict exact-label accuracy fields without quality claims. It intentionally keeps `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, optional F handling, `v52_ready=0`, and all 30B-150B comparison claims blocked; missing source packets produce a dependency blocker rather than a false-positive ready row.

The v52d evidence-intake layer emits the system-D/E 30B/70B open-weight LLM+RAG schemas, answer templates, model identity templates, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked until both real D and E evidence directories validate.

The v52e optional-intake layer emits the system-F 100B+ hosted/API LLM+RAG schema, answer template, model identity template, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `optional_100b_plus_baseline_status=deferred-with-reason`, `optional_100b_plus_baseline_ready=0`, `v52_optional_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked. F is optional and cannot replace required D/E evidence.

The v52y F-final policy layer consumes v52r and v52e, records F as either supplied-ready or explicit final-deferred-with-reason, and defines the `v52_ready` condition matrix. In the default path it marks `f_optional_final_disposition=deferred-with-reason-final`, keeps `optional_100b_plus_baseline_ready=0`, keeps `v52_ready=0`, and sets 30B-150B-class wording to `blocked` until D/E PM/release baseline readiness is accepted. It still blocks measured 100B+/150B result wording, v53 complete-source audit, v1.0 comparison readiness, and release claims.

The v53 scaffold emits a 10-repo target registry, 1000-query scale contract, artifact contract rows, v50 seed evidence copies, and claim boundary. It intentionally keeps `v53_ready=0`, `missing_repo_count=7`, and `missing_query_rows=991`.

The v53b repo-lock layer resolves live HEAD SHAs for 10 public GitHub repositories, writes the 10-repo lock table and 1000-row query plan, and copies the v50 seed evidence. It intentionally keeps `v53_ready=0` because the seven newly locked repositories still need source snapshots and the audit still needs source-span-bound query rows, A-H answer/citation/resource rows, negative/abstain rows, and review artifacts.

The v53c canary source snapshot layer fetches pinned source/doc/config canary files from all 10 locked repositories and records sha256 content rows. It intentionally keeps `v53_ready=0`, `full_source_snapshot_missing_repo_count=7`, and `missing_query_rows=991` because canary files are not complete source snapshots and do not provide the 1000-row audit, A-H answer/citation/resource rows, negative/abstain rows, or review artifacts.

The v53d query-seed layer derives 100 source-span-bound canary query rows from the v53c source files, with 10 rows per locked repository and matching source-span rows. It intentionally keeps `v53_ready=0`, `missing_query_rows=900`, negative/abstain family coverage blocked, and A-H answer/citation/resource rows blocked.

The v53e query-scale layer expands the v53d seeds to 1000 canary-scope source-span-bound query rows across the 10 locked repositories, with 840 supported rows, 160 negative/abstain rows, and eight query families. It intentionally keeps `v53_ready=0` because canary-scale query mechanics are not complete-source audit evidence and do not provide A-H answer/citation/resource rows, symmetric scorer/policy rows, or review artifacts.

The v53f intake layer defines the A-H answer/citation/resource evidence surface over the frozen v53e 1000-query canary set. It writes the A-H system target matrix, required schemas, and 8000 answer/resource template rows, while intentionally keeping `v53_ready=0`, `valid_answer_rows=0`, and citation/resource coverage blocked until real supplied comparison rows, complete source snapshots, scorer/policy rows, and review artifacts exist.

The v53g complete-source manifest layer binds the 10 locked repositories to recursive Git tree source/doc/config/test manifests. It records 11318 metadata-only file manifest rows, 11312 query-eligible rows, at least 20 canary-overlap rows, and an eight-family 1000-query budget. It intentionally keeps `v53_ready=0`, `complete_source_content_snapshot_ready=0`, `complete_source_query_rows_ready=0`, and A-H answer/citation/resource rows blocked, because this is the complete-source manifest prerequisite rather than materialized complete-source audit evidence.

The v53h complete-source content snapshot layer materializes the v53g manifest from pinned Git blobs. It records 11318 content files, 11318 content sha256 rows, 124845122 content bytes, 11312 query-eligible content rows, and 10 content-ready repositories. It marks `complete_source_content_snapshot_ready=1` while intentionally keeping `v53_ready=0`, complete-source span extraction, complete-source 1000+ query rows, A-H answer/citation/resource rows, review artifacts, and release claims blocked.

The v53i complete-source query instantiation layer applies the v53g 1000-query budget to line-level spans from the v53h materialized content snapshot and makes the missing-API abstain control explicit. It records 1000 complete-source query rows, 1000 matching source-span rows, 840 supported rows, 160 negative/abstain rows, 30 missing-specific abstain rows, 140 doc-code conflict rows, nine families, and 10-repo coverage. It marks `complete_source_query_rows_ready=1` while intentionally keeping `v53_ready=0`, A-H answer/citation/resource rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53j complete-source A-H intake layer promotes the v53f answer/citation/resource evidence surface onto the v53i complete-source query set. It records 7000 A/B/C/D/E/G/H core answer/resource/citation targets, binds optional F to the v52y `deferred-with-reason-final` policy, and emits validation templates over the same 1000 complete-source query IDs. It intentionally keeps `v53_ready=0`, supplied core answer/citation/resource rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53k complete-source System A lexical measured layer supplies A/BM25-compatible answer/citation/resource rows over the frozen v53i 1000-query set and mirrors them into a partial `supplied_v53j/` directory. It records 1000 answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 wrong-answer guard rows, and metric rows for System A only. It carries the expected-answer oracle replay disclosure (`answer_source=v53i_expected_answer_oracle_replay`, `execution_mode=expected-answer-oracle-replay`, `expected_answer_oracle_replay=1`, `expected_answer_oracle_replay_rows=1000`, `actual_adapter_execution_ready=0`, `real_system_performance_claim_ready=0`) on summary, metric, manifest, answer, resource, and boundary rows, plus the `oracle-replay-disclosed` decision row, so v53k is a row-contract replay packet and not actual BM25 adapter performance evidence. It intentionally keeps `v53_ready=0`, B/C/D/E/G/H rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53l complete-source System B local-RAG measured layer supplies B/small-local-RAG answer/citation/resource rows over the same frozen v53i 1000-query set and mirrors combined A+B rows into a partial `supplied_v53j/` directory. It records 1000 System B answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 wrong-answer guard rows, and 2000 combined A+B answer/citation/resource rows. It carries the expected-answer oracle replay disclosure (`answer_source=v53i_expected_answer_oracle_replay`, `execution_mode=expected-answer-oracle-replay`, `expected_answer_oracle_replay=1`, `expected_answer_oracle_replay_rows=1000`, `actual_adapter_execution_ready=0`, `real_system_performance_claim_ready=0`) on summary, metric, manifest, answer, resource, and boundary rows, plus the `oracle-replay-disclosed` decision row, so v53l is a row-contract replay packet and not actual small-local-RAG adapter performance evidence. It intentionally keeps `v53_ready=0`, C/D/E/G/H rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53m complete-source System C local-model-RAG measured layer runs local Ollama `qwen2.5:7b-instruct` over the same frozen v53i 1000-query set and mirrors combined A+B+C rows into a partial `supplied_v53j/` directory. It records 1000 System C answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 abstain rows, 1000 wrong-answer guard rows, 1000 transcripts, and 3000 combined A+B+C answer/citation/resource rows. It records 0/1000 strict exact-answer matches and 961 wrong-answer guard rows, so it is real response/schema evidence rather than a C quality claim. It intentionally keeps `v53_ready=0`, D/E/G/H rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53n complete-source System G RouteMemory+RouteHint measured layer supplies G answer/citation/resource rows over the same frozen v53i 1000-query set and mirrors combined A+B+C+G rows into a partial `supplied_v53j/` directory. It records 1000 System G answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 route-memory evidence rows, 1000 compact RouteHint rows, raw prompt context bytes 0, and 4000 combined A+B+C+G answer/citation/resource rows. It carries the expected-answer oracle replay disclosure (`answer_source=v53i_expected_answer_oracle_replay`, `execution_mode=expected-answer-oracle-replay`, `expected_answer_oracle_replay=1`, `expected_answer_oracle_replay_rows=1000`, `actual_adapter_execution_ready=0`, `real_system_performance_claim_ready=0`) on summary, metric, manifest, answer, resource, and boundary rows, plus the `oracle-replay-disclosed` decision row, so v53n is a row-contract replay packet and not actual RouteMemory/RouteHint adapter performance evidence. It intentionally keeps `v53_ready=0`, D/E/H rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53o complete-source System H RouteMemory+RouteHint+source-verified-scorer+domain-policy measured layer supplies H answer/citation/resource rows over the same frozen v53i 1000-query set and mirrors combined A+B+C+G+H rows into a partial `supplied_v53j/` directory. It records 1000 System H answer rows, 1000 citation rows, 1000 resource rows, 1000 retrieval rows, 1000 route-memory evidence rows, 1000 compact RouteHint rows, 1000 source-verified scorer rows, 1000 domain-policy rows, raw prompt context bytes 0, and 5000 combined A+B+C+G+H answer/citation/resource rows. It carries the expected-answer oracle replay disclosure (`answer_source=v53i_expected_answer_oracle_replay`, `execution_mode=expected-answer-oracle-replay`, `expected_answer_oracle_replay=1`, `expected_answer_oracle_replay_rows=1000`, `actual_adapter_execution_ready=0`, `real_system_performance_claim_ready=0`) on summary, metric, manifest, answer, resource, and boundary rows, plus the `oracle-replay-disclosed` decision row, so v53o is a row-contract replay packet and not actual RouteMemory/RouteHint/scorer/policy adapter performance evidence. It intentionally keeps `v53_ready=0`, D/E rows, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53ap complete-source A/B/G/H same-query measured layer closes the PM pre-baseline deterministic source-span adapter run over the frozen v53i 1000-query set without waiting for D/E. It records 4000 answer rows generated from selected source spans rather than copied expected answers, 4000 citation rows, 4000 retrieval rows, 4000 evaluator rows, 4000 system-distinct adapter trace rows, 4000 abstain rows, 4000 wrong-answer guard rows, 4000 resource rows, 2000 G/H RouteHint rows, the shared source/query hashes, `same_evaluator_contract_all_local_systems=1`, `same_resource_contract_all_local_systems=1`, `internal_v1_0_pre_baseline_run=1`, `expected_answer_oracle_replay=0`, `deterministic_source_span_adapter_execution=1`, `deterministic_source_span_adapter_rows=4000`, `system_distinct_adapter_trace_ready=1`, `actual_adapter_execution_ready=1`, and `real_system_performance_claim_ready=0`. It intentionally keeps real system performance, public comparison wording, required 30B/70B baselines, `v53_ready`, and release claims blocked.

The v53aq complete-source A/B/G/H real-adapter measured layer closes the PM requirement that A/B/G/H run without expected-answer or source-span oracle selection. It reuses the frozen v53i 1000-query set, allows adapter selection to read only the sanitized natural-language `sanitized_question` field through a runtime allowlist guard, and keeps `query_id`, `expected_answer`, `expected_answer_sha256`, `source_span_id`, `source_path`, and source-line fields evaluator-only. It records 4000 answer/citation/retrieval/evaluator/adapter-trace/resource rows, 2000 G/H RouteMemory rows, 2000 G/H RouteHint rows, `selection_question_text_only=1`, `selection_sanitized_question_only=1`, `source_locator_in_question_removed_rows=4000`, `selection_runtime_guard_passed_rows=4000`, `selection_oracle_field_used=0`, `source_span_oracle_selection_used=0`, `expected_answer_oracle_replay=0`, `deterministic_source_span_adapter_execution=0`, `real_adapter_execution_ready=1`, `internal_real_adapter_metric_claim_ready=1`, `public_real_system_performance_claim_ready=0`, 76 answer-hash matches, 3924 coherent wrong-key rows, and `public_comparison_claim_ready=0`. It also writes a four-row per-system internal pre-baseline contract ledger (`abgh_internal_prebaseline_contract_rows.csv`) that pins each A/B/G/H run to the same `v53i_complete_source_1000` query set and source span hash, the same `v53aq-query-text-only-answer-citation-resource-v1` evaluator contract, the same resource row binding, the expected G/H RouteHint presence, the expected H scorer/policy presence, and per-system answer-hash and citation-location counts while keeping `internal_real_adapter_metric_claim_ready=1` and `public_real_system_performance_claim_ready=0`; `internal_prebaseline_contract_rows=4`, `internal_prebaseline_contract_ready_rows=4`, and `internal_prebaseline_contract_ready=1` are recorded in the manifest and the v53aq boundary. It is internal v1.0 pre-baseline evidence, not a D/E replacement, public system-performance claim, or public comparison claim.

The v53p complete-source System D/E open-weight RAG measured layer supplies D and E answer/citation/resource rows over the same frozen v53i 1000-query set and mirrors combined A+B+C+D+E+G+H rows into a partial `supplied_v53j/` directory. It binds v52p/v52q D/E model identity evidence, records 1000 D answer rows, 1000 E answer rows, 2000 D/E citation rows, 2000 D/E resource rows, 160 D and 160 E abstain rows, and 7000 combined core answer/citation/resource rows. It intentionally keeps `v53_ready=0`, D/E quality comparison claims, symmetric scorer/policy rows, review artifacts, and release claims blocked.

The v53q complete-source symmetric scorer/policy layer applies the same source-verification scorer and domain/abstain policy checks to all A/B/C/D/E/G/H rows over the frozen v53i 1000-query set. It records 7000 scorer rows, 7000 policy rows, 1000 query metric rows, 6000 answer-hash match rows, 1000 preserved C mismatch rows, 7000 source/resource-bound rows, and `symmetric_scorer_policy_rows_ready=1`. It intentionally keeps `v53_ready=0`, quality comparison claims, review artifacts, and release claims blocked.

The v53r complete-source review packet layer prepares the frozen v53i/v53q evidence for review without claiming review completion. It records 1000 query review packets, 7000 answer review packets, 7000 pending review queue rows, 10 repo packets, 7 system packets, reviewer assignment templates, review return templates, acceptance criteria, and p0/p1/p2 priority counts of 1000/960/5040. It marks `review_packet_ready=1` while intentionally keeping returned human/source review artifacts, adjudication artifacts, quality comparison claims, `v53_ready`, and release claims blocked.

The v53s complete-source review return intake layer binds v53r to the expected external returned-review artifacts without fabricating review judgments. It records `expected_human_review_rows=7000`, `expected_adjudication_rows=1000`, `expected_reviewer_assignment_rows=21`, accepted human/adjudication rows 0 in the default path, `review_return_ready=0`, `quality_comparison_claim_ready=0`, and `v53_ready=0`, while keeping human-reviewed audit, comparison, and release claims blocked.

The v53t complete-source audit readiness gate binds v52y/v53i/v53ap/v53aq/v53q/v53r/v53s into one readiness matrix. It records `machine_complete_source_surface_ready=1` for the complete-source query/scoring/review-packet surface, `pm_v53_freeze_ready=1` for the source-bound 1000-row plus A/B/G/H same-query PM gate, `foundation_direct_evidence_ready=1` for copied direct query/span and v53ap deterministic A/B/G/H evaluator evidence, and `foundation_real_adapter_evidence_ready=1` for copied v53aq sanitized-question-only real-adapter evidence. The v53aq certificate rows preserve `selection_question_text_only=1`, `selection_sanitized_question_only=1`, `source_locator_in_question_removed_rows=4000`, `selection_runtime_guard_passed_rows=4000`, `selection_oracle_field_used=0`, `v53aq_real_adapter_execution_ready=1`, `v53aq_internal_real_adapter_metric_claim_ready=1`, `v53aq_public_real_system_performance_claim_ready=0`, 76 answer-hash matches, 3924 coherent wrong-key rows, and `public_comparison_claim_ready=0`. The v53t sidecar also carries the four-row v53aq per-system internal pre-baseline contract ledger (`foundation_real_adapter_internal_contract_rows=4`, `foundation_real_adapter_internal_contract_ready_rows=4`, `foundation_real_adapter_internal_contract_ready=1`) and copies the same contract rows forward so reviewers can replay the per-system contract from the v53t boundary without re-running v53aq. It preserves `v52y_dependency_blocker_ready=1` when the upstream v52/F optional chain is blocked, without letting that optional-disposition blocker prevent the v53 machine foundation freeze. It also records `v53ap_expected_answer_oracle_replay=0`, `v53ap_deterministic_source_span_adapter_execution=1`, `v53ap_actual_adapter_execution_ready=1`, accepted human review rows 0/7000, accepted adjudication rows 0/1000, `review_return_ready=0`, `quality_comparison_claim_ready=0`, `v53_ready=0`, `v1_0_comparison_ready=0`, and `real_release_package_ready=0`.

The v54 scaffold emits a 1000-row RouteHint generation target, six domain targets, no-attention/no-raw-context invariants, artifact contract rows, v48/v54 seed evidence copies, and claim boundary. It intentionally keeps `v54_generation_1000_ready=0` and `missing_generation_rows=976`.

The v54b scale layer emits 1000 deterministic local RouteHint generation rows across six domains, with RouteMemory evidence rows, compact RouteHint rows, generator input rows, grounded generation rows, citation rows, abstain rows, unsupported-claim rows, resource rows, and hash manifests. It marks `v54_generation_1000_ready=1` with `attention_blocks=0`, `transformer_blocks=0`, `raw_prompt_context_appended_rows=0`, and `wrong_answer_rows=0`, while keeping release and 30B-150B equivalence claims blocked.

The v54c complete-source grounded generation layer replays the v54 1000-row generation target over the frozen v53i complete-source query/source-span benchmark and the v53ap A/B/G/H deterministic source-span adapter surface when the ignored `results/v54c_complete_source_grounded_generation_1000/` packet is present. The source-controlled clean-checkout contract lists the required `answer_rows.csv`, `citation_rows.csv`, `unsupported_claim_rows.csv`, `abstain_rows.csv`, `generator_resource_rows.csv`, `wrong_answer_guard_rows.csv`, compact RouteHint and generator-input rows, sha256 manifest, and `sha256sums.txt`, but keeps `deterministic_source_span_generation_fixture_ready=0` and all ten required artifact ids missing until the packet is replayed or explicitly supplied. Historical local v54c packets may record source-span-derived fixture output with v53ap H-adapter-trace provenance, no raw prompt context, no model-visible source locators, and zero real-model/human/release readiness, but the tracked contract must not promote those ignored local files into public generation or release claims.

The v55 scaffold emits a six-axis / 100-row scaling-law target, fit contract rows, no-oracle/no-extractor/RouteMemory-lineage invariants, v51 seed curve copies, and claim boundary. It intentionally keeps `v55_local_scaling_law_ready=0`, `repo_count_axis_ready=0`, and `missing_scaling_curve_rows=73`.

The v55b main-run layer emits six scaling axes, 360 curve rows, 60 repo-count rows, 120 confidence-interval rows, failure-case rows, resource rows, fit rows, local source/probe hash binding, and claim boundary. It marks `v55_local_scaling_law_ready=1` while keeping GPU speedup, production latency, release, and 30B-150B equivalence claims blocked.

The v56 scaffold emits RULER and LongBench expanded benchmark targets, official source/evaluator artifact contracts, no-oracle/no-extractor/RouteMemory-lineage invariants, v49/v45 seed evidence copies, and claim boundary. It intentionally keeps `v56_ruler_longbench_expanded_ready=0`, `ruler_missing_rows=500`, `longbench_missing_rows=494`, and `llm_rag_baseline_rows_ready=0`.

The v56b scale layer emits 1500 benchmark-format prediction rows, 1000 RULER rows, 500 LongBench rows, 1500 lineage/candidate/resource rows, official source/evaluator hash binding, and no oracle/raw-input extractor usage. It marks `v56_ruler_longbench_expanded_ready=1` for local candidate-scale row count while keeping `llm_rag_baseline_rows_ready=0`, `real_external_benchmark_verified=0`, leaderboard claims, and release claims blocked.

The v57 scaffold emits six domain-pack targets, expert-review artifact contracts, domain policy gates, v47/v48/v52/v56 seed evidence copies, and claim boundary. It intentionally keeps `v57_domain_expert_packs_ready=0`, `missing_eval_rows=950`, `human_expert_review_ready=0`, `blind_eval_ready=0`, and `expert_replacement_claim=0`.

The v57b candidate layer emits 1000 source-span-bound candidate eval rows across six domain packs, with 900 answer rows, 100 abstain rows, 1000 source-span rows, 1000 expert-review template rows, policy/rubric/failure-taxonomy rows, copied v57 contract evidence, hash manifest, and claim boundary. It marks only `v57b_domain_expert_pack_candidate_ready=1`; it keeps `v57_domain_expert_packs_ready=0`, `human_expert_review_ready=0`, `blind_eval_ready=0`, `expert_replacement_claim=0`, and `real_release_package_ready=0`.

The v58 scaffold emits D-H blind-system mapping, 500-row blind query-freeze targets, blind evaluator artifact contracts, sealed identity and symmetric-evidence gates, v52/v57 seed evidence copies, and claim boundary. It intentionally keeps `v58_ready=0`, `missing_blind_eval_rows=500`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, `human_blind_review_ready=0`, and `inter_rater_rows_ready=0`.

The v58b candidate layer emits 500 frozen source-span-bound blind queries, 4000 A/B/C/D/E/F/G/H response templates, 4000 anonymous reviewer-packet templates, sealed answer and identity keys, same-evidence-budget rows, adjudication templates, copied v58/v57b source evidence, hash manifest, and claim boundary. It marks only `v58b_blind_eval_candidate_ready=1`; it keeps `v58_ready=0`, `actual_blind_response_rows=0`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, `human_blind_review_ready=0`, `inter_rater_rows_ready=0`, and `real_release_package_ready=0`.

The v58c intake layer emits the A/B/C/D/E/F/G/H blind response schema, 4000-row response template, run-identity template, validation rows, gate rows, copied v58b source evidence, hash manifest, and claim boundary. It marks only `v58c_blind_response_evidence_intake_ready=1`; it keeps `v58_ready=0`, required blind response readiness, optional F readiness, human blind review, inter-rater rows, full blind-eval, and release claims blocked until real supplied response rows validate.

The v58d review-return intake layer emits the blind review/adjudication return schema, review/adjudication templates when v58c is explicitly included, validation rows, gate rows, score/failure-case output surfaces, dependency rows, hash manifest, and claim boundary. By default it refuses implicit v58c/v58b/v56 seed rebuild, marks only `v58d_blind_review_return_intake_ready=1` with `v58d_dependency_blocker_ready=1`, and keeps required review/adjudication readiness, human blind review, inter-rater rows, RouteHint advantage rows, failure-case report, full blind-eval, and release claims blocked until real response plus reviewer/adjudication returns validate.

The v59 scaffold emits a repository one-command entrypoint, v52-v58 contract bundle, stage/gate rows, replay command, README_RESULT, hash manifest, and claim boundary. It intentionally keeps `v59_ready=0`, all v52-v58 full-ready stage rows at zero, and the real 30B/70B, public repo scale, generation, scaling, expanded benchmark, domain pack, blind-eval, and release blockers explicit.

The v59b candidate layer emits a repository one-command candidate entrypoint, v52b-v58c candidate/intake bundle, stage/gate rows, replay command, README_RESULT, hash manifest, and claim boundary. It marks only `v59b_one_command_candidate_demo_ready=1`; it keeps `v59_ready=0`, real 30B/70B rows, optional 100B+ row/final deferral, complete-source audit, human domain review, human blind review, full challenge demo, and release claims blocked.

The v59c measured-registry layer emits a repository one-command measured-registry entrypoint, v52m measured-registry bundle, v53e-v58c candidate-chain copies, stage/gate rows, replay command, README_RESULT, hash manifest, and claim boundary. It marks only `v59c_one_command_measured_registry_demo_ready=1`; it hash-binds A/B/C/G/H over the shared 1000-query v53e source manifest into the v59 replay path while keeping `v59_ready=0`, D/E real evidence rows, optional F handling, complete-source audit, human domain review, human blind review, full challenge demo, and release claims blocked.

The v59e PM foundation layer emits a repository one-command PM entrypoint over the current v53 complete-source PM freeze, v53ap A/B/G/H same-query deterministic source-span adapter/evaluator rows, v53aq sanitized-question-only real-adapter rows and four-row per-system internal pre-baseline contract ledger, v54c grounded-generation output rows, h10 real-label readiness ledger, v58c blind-response-intake and v58d blind-review-return dependency checks, and a v58 blind-eval blocker ledger. It copies the v53ap adapter trace/evaluator rows, the v53aq adapter-selection/evaluator/RouteHint rows plus `abgh_internal_prebaseline_contract_rows.csv`, v53t direct query/span and A/B/G/H evaluator evidence through the PM sidecar, and v54c generator input rows; it copies v58c/v58d evidence only when explicitly included, otherwise emits dependency blockers and refuses implicit v58/v57/v56 seed rebuild or fake review evidence. It now also emits `pm_foundation_replay_preflight_rows.csv` for entrypoint presence, pinned-source snapshot replay, no default network/download, no private fixture, no manual post-processing, no undocumented local state, PM sidecar packaging, blocker closure, and no remote mutation. It marks only `v59e_one_command_pm_foundation_demo_ready=1` with `one_command_replay_preflight_ready=1`, `v53ap_expected_answer_oracle_replay=0`, `v53ap_deterministic_source_span_adapter_execution=1`, `v53ap_real_system_performance_claim_ready=0`, `v53aq_selection_question_text_only=1`, `v53aq_selection_oracle_field_used=0`, `v53aq_real_adapter_execution_ready=1`, `v53aq_internal_real_adapter_metric_claim_ready=1`, `v53aq_public_real_system_performance_claim_ready=0`, `v53aq_internal_prebaseline_contract_rows=4`, `v53aq_internal_prebaseline_contract_ready=1`, `v58c_intake_artifact_available=0`, `v58c_required_blind_response_ready=0`, `v58d_review_artifact_available=0`, and `v58d_human_blind_review_ready=0`; it keeps `v59_ready=0`, h10 real-label promotion, real blind eval, full v59 public demo, v60 release, public real system performance claims, and public comparison wording blocked.

The v60 release gate emits release requirement rows, allowed claim rows, forbidden claim rows, release decision rows, copied v59e PM foundation evidence, PM PR sidecar evidence, direct v53t query/evaluator evidence, direct h10 PM criteria evidence with nested v53aq real-adapter trace/evaluator/metric rows plus the four-row v53aq per-system internal pre-baseline contract rows, v58c/v58d dependency evidence, source summaries, hash manifest, and claim boundary. It intentionally keeps `v60_ready=0` and `real_release_package_ready=0` while distinguishing six current PM-foundation ready requirements from eight still-blocked release requirements: D/E 30B/70B baselines, h10 real external/human labels, v56 replay artifact, v58c blind-response intake artifact, v58d blind-review/adjudication return artifact inside the v58 blocker chain, v58 real blind eval, full v59 public demo, human release review, and release package. The h10 release requirement points at the six-row PM criteria ledger for coherent wrong-key, chunk exact, near-miss, missing-query abstain, source provenance, and external/human label evidence while keeping promotion blocked; the h10 sidecar now also carries the v53aq per-system internal pre-baseline contract rows so the source-provenance binding criterion and the A/B/G/H real-adapter contract boundary can be replayed from the v60 release sidecar without re-running v53aq or v53t. Legacy v59 scaffold evidence is copied only when already present; rebuilding it requires explicit `V60_REBUILD_SOURCE_CHAIN=1`.

The forbidden-claim ledger also blocks public real system performance wording for A/B/G/H real-adapter metrics, which remain internal pre-baseline evidence only.

The v60c release-blocker replay entrypoint packages the next real-evidence intake attempt without executing it by default. It emits required env rows, stage rows, command rows, a metadata-only entrypoint bundle, boundary, manifest, and hash manifest. The guarded replay script requires repo-external D/E 30B/70B evidence, h10 real-label CSV, v56 replay artifacts, v58c/v58 blind-response evidence, human release-review evidence, a release package directory, and the exact `real-v60-release-blocker-evidence` provenance string. No-env, fixture provenance, and repo-internal evidence roots are rejected; `v60_ready` and `real_release_package_ready` remain zero.

The v60b preflight layer consumes the v59b candidate replay and emits release-preflight requirement rows, claim rows, stage release-audit rows, decision rows, copied v59b source evidence, hash manifest, and claim boundary. It marks only `v60b_release_preflight_candidate_audit_ready=1`; it keeps `v60_ready=0`, real 30B/70B rows, complete-source audit, human domain review, human blind review, human release review, release package, and all v1.0 release/comparison/superiority claims blocked.

The v61 SSD-resident MoE runtime direction is documented in `docs/V61_SSD_RESIDENT_MOE_RUNTIME.md`. It is a post-v52 runtime implementation track, not a shortcut through the v1.0 release gates. Its objective is to store hundreds-B to trillions-parameter open-weight model warehouses on NVMe SSD while keeping only the active MoE/page execution set in VRAM, with discrete-node routing, predictive prefetch, VRAM hot cache, page-level mixed quantization, and token-level I/O budgets. v52s/v52u/v52v/v52w become the seed artifacts for this track; v52x external bake remains fallback evidence intake rather than the main research path.

The v61a-v61j SSD-resident active-sparse prototype is implemented and covered by `experiments/test_v61j_one_command_ssd_resident_demo.sh`. It creates deterministic 2 MB SSD weight pages split by layer/expert/page ID, verifies aligned direct I/O reads, records no full-model RAM residency audit rows, emits RouteHint prefetch/VRAM hot-cache rows, runs CPU deterministic page-dequant-matmul numeric checks, selects active experts, compares predictive-prefetch stalls, assigns mixed quant profiles, measures dense full-stream blockers, emits a logical 128B MoE active-sparse contract, and bundles the path behind one command. It marks `ssd_resident_active_sparse_path_proven=1`, `ram_resident_full_model_fallback_rows=0`, `total_parameters=128000000000`, `ssd_read_bytes_per_token_max=8388608`, and `route_jump_rows=0`, while keeping real 100B checkpoint materialization, GPU speedup, dense hundreds-B local-speed, near-frontier quality, and release claims blocked.

The v61k real-model page manifest is implemented and covered by `experiments/test_v61k_real_model_page_manifest.sh`. It binds the page manifest to `mistralai/Mixtral-8x22B-v0.1`, records Apache-2.0 source/config/license rows, emits 59 checkpoint-shard manifest rows, enumerates 129024 2 MiB expert tensor page metadata rows, and keeps checkpoint weights out of the repository. It marks `legally_redistributable_page_manifest_ready=1`, `total_parameters_100b_plus=1`, `real_checkpoint_weight_bytes_materialized=0`, `active_uncached_q4_budget_pass=0`, and `near_frontier_claim_ready=0`; this opens measured work on GPU page-dequant-matmul, KV residency/eviction, and source-bound QA without opening production or release claims.

The v61l GPU page-dequant-matmul measurement is implemented and covered by `experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh`. It consumes the v61k Mixtral page manifest, compiles a HIP probe with an explicit ROCm offload target, runs the probe from an ASCII `/tmp` path, and measures one synthetic 2 MiB q4-equivalent page tile with `tile_m=1024` and `tile_k=4096`. The current smoke records positive `gpu_kernel_avg_ms`, positive `gpu_page_dequant_gflops`, positive `gpu_page_bandwidth_gbps`, and `real_checkpoint_weight_bytes_materialized=0`; it keeps safetensors page-hash binding, KV-cache policy, source-bound QA, near-frontier quality, production latency, and release claims blocked.

The v61m KV-cache residency/eviction policy is implemented and covered by `experiments/test_v61m_kv_cache_residency_eviction_policy.sh`. It computes Mixtral KV geometry from the v61k config, consumes the v61l page-kernel evidence, and emits deterministic VRAM hot/sink plus NVMe cold-tier residency rows. It records `kv_bytes_per_token=229376`, `kv_tokens_per_page=9`, `max_context_tokens=8192`, `max_resident_vram_pages=129`, `max_evicted_nvme_pages=782`, `kv_cache_policy_ready=1`, and `host_ram_kv_spill_enabled=0`; it keeps safetensors page-hash binding, source-bound QA, long-context quality, near-frontier quality, production latency, and release claims blocked.

The v61n source-bound QA workload seed is implemented and covered by `experiments/test_v61n_source_bound_qa_workload.sh`. It binds v61j one-command runtime evidence, v61m KV policy evidence, the v53g complete-source manifest, and the currently materialized v53c canary-overlap files into source-bound query rows. It records citation-bound supported answers, one unsupported-claim abstain per repository, 10 repositories, manifest-bound source files, and `source_bound_qa_workload_ready=1`; it keeps complete-source A-H QA, real Mixtral generation, safetensors page-hash binding, near-frontier quality, production latency, and release claims blocked.

The v61o checkpoint shard/header probe is implemented and covered by `experiments/test_v61o_checkpoint_shard_header_probe.sh`. It fetches the Hugging Face safetensors index, HEAD-probes all 59 checkpoint shards, range-reads every safetensors header, parses 1739 tensor header rows, and hashes three sampled first 2 MiB payload pages while persisting zero checkpoint payload bytes. It keeps full checkpoint materialization, full page-hash coverage, local SSD checkpoint residency, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61p local SSD checkpoint residency preflight is implemented and covered by `experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh`. It consumes v61o and emits an outside-repository warehouse probe, disk budget row, checkpoint residency requirement rows, 59 shard download-plan rows, 59 local shard presence rows, runtime gaps, boundary, manifest, and hash rows without downloading checkpoint payload bytes. The current host records 281241493344 checkpoint bytes required, 315601231712 bytes required with reserve, 21337460736 available bytes, zero locally complete shards, `real_100b_open_weight_materialized=0`, and `local_checkpoint_residency_ready=0`; it keeps full page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61q real checkpoint page map is implemented and covered by `experiments/test_v61q_real_checkpoint_page_map.sh`. It consumes v61o safetensors header tensor offsets and converts them into a metadata-only 2 MiB SSD checkpoint page map. It records 59 checkpoint shards, 1739 real checkpoint tensor rows, 134161 unique checkpoint page rows, 135841 tensor/page segment rows, 281241268224 mapped tensor payload bytes, 281241493344 total checkpoint bytes, `checkpoint_page_map_weight_bytes_included=0`, and `real_checkpoint_weight_bytes_materialized=0`. It strengthens the real-model page manifest from architecture-derived expert pages to actual safetensors offset/page binding while keeping full page-hash coverage, local SSD checkpoint residency, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61r full page-hash sweep plan is implemented and covered by `experiments/test_v61r_full_page_hash_sweep_plan.sh` plus `experiments/test_v61r_full_page_hash_sweep_plan_target_override.sh`. It consumes the v61q page map and v61p local shard presence audit, emits 134161 page-hash task rows, binds 3 sampled remote page-hash probes to 6 overlapping page rows, records 0 verified local page hashes on the current host because no shards are locally resident, and verifies that `V61R_WAREHOUSE_ROOT` refreshes v61p shard-presence planning and rewrites local shard paths to the supplied external warehouse root. It records `full_safetensors_page_hash_binding_ready=0`, `checkpoint_payload_bytes_committed_to_repo=0`, and `real_checkpoint_weight_bytes_materialized=0`; it keeps local SSD checkpoint residency, completed full page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61s one-command source-bound QA replay is implemented and covered by `experiments/test_v61s_one_command_source_bound_qa_replay.sh`. It exercises `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa`, binds v61j and v61n evidence, records exit code 0, 37/37 source-bound query pass rows, 37 citation/resource rows, 10/10 abstain-policy pass rows, `actual_model_generation_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`. It proves command-level replay of the source-bound QA seed through the v61 runtime evidence path while keeping complete-source 1000+ audit completion, real Mixtral generation, full page-hash coverage, near-frontier quality, production latency, and release claims blocked.

The v61t local checkpoint materialization verifier is implemented and covered by `experiments/test_v61t_local_checkpoint_materialization_verifier.sh` plus `experiments/test_v61t_local_checkpoint_materialization_verifier_target_override.sh`. It refreshes v61p local shard presence, binds v61q/v61r, and verifies local outside-repository shards by exact byte length, safetensors header hash, and sampled page hash. The current host records 0 local existing shards, 0 local identity-verified shards, `local_checkpoint_materialization_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and `real_checkpoint_weight_bytes_materialized=0`; the target-override smoke verifies that `V61T_WAREHOUSE_ROOT` is passed into v61p shard-presence preflight and all materialization target paths. It keeps real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61u remote checkpoint page-hash sampler is implemented and covered by `experiments/test_v61u_remote_checkpoint_page_hash_sampler.sh`. It consumes v61q/v61t, performs bounded HTTP Range reads over 16 deterministic full-size v61q checkpoint pages from the real Mixtral checkpoint source, and records 16 ready page-hash sample rows plus 33554432 remote payload bytes read as hashes only. It keeps local checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61v remote page tensor binding is implemented and covered by `experiments/test_v61v_remote_page_tensor_binding.sh`. It consumes v61u and v61q, binds each of the 16 remote-hashed sampled checkpoint pages to real safetensors tensor/page segment rows and runtime scheduling nodes, and records 15 MoE expert page bindings across 15 layers and all eight expert indices plus one embedding binding. It keeps local checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61w materialization admission/resume plan is implemented and covered by `experiments/test_v61w_materialization_admission_resume_plan.sh` plus `experiments/test_v61w_materialization_admission_resume_plan_target_override.sh`. It consumes v61p/v61q/v61t/v61v, emits 59 checkpoint shard priority rows and 59 download-resume rows, promotes 15 remote-hashed MoE expert shards plus one embedding shard ahead of generic backfill, records `download_resume_plan_ready=1` and `moe_first_priority_plan_ready=1`, and verifies that `V61W_WAREHOUSE_ROOT` forces fresh v61t/v61p materialization planning while preserving target-aware verify/hash commands. It keeps `materialization_admission_ready=0`, local checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked on the current SSD budget.

The v61x hotset runtime replay manifest is implemented and covered by `experiments/test_v61x_hotset_runtime_replay_manifest.sh`. It consumes v61w/v61v/v61s/v61m, binds the 16 remote-hashed real checkpoint pages into 16 planned NVMe hotset slots, and attaches those slots to 37 source-bound replay rows. It records 15 MoE hotset pages, one embedding hotset page, `hotset_manifest_ready=1`, `source_bound_replay_binding_ready=1`, `checkpoint_payload_bytes_downloaded_by_v61x=0`, and `checkpoint_payload_bytes_committed_to_repo=0`. It keeps hotset payload materialization, SSD budget admission, local checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61y hotset local materialization verifier is implemented and covered by `experiments/test_v61y_hotset_local_materialization_verifier.sh`. It consumes v61x/v61u, materializes the 16 sampled hotset pages outside the repository, and verifies local/readback hashes against the remote page hashes. It records 33554432 sampled checkpoint payload bytes persisted outside the repository, 16 local page hash matches, 16 readback hash matches, `hotset_payload_materialization_ready=1`, `hotset_readback_verify_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`. It keeps full checkpoint materialization, SSD budget admission, local full-checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61z hotset direct-I/O replay is implemented and covered by `experiments/test_v61z_hotset_direct_io_replay.sh`. It consumes v61y, reads the 16 local sampled hotset pages through O_DIRECT, and verifies every direct read against the remote page hash. It records 16 direct-I/O read rows, 16 direct-read hash matches, zero direct-I/O errors, 33554432 direct-I/O bytes, `ssd_read_bytes_per_token=8388608`, p50/p95 read latency 0.580768/0.956690 ms, and 2784.734538 MiB/s sampled throughput. It keeps full checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61aa hotset tensor slice verifier is implemented and covered by `experiments/test_v61aa_hotset_tensor_slice_verifier.sh`. It consumes v61z/v61v/v61y, interprets the 16 local sampled hotset pages as BF16 tensor segments using real safetensors tensor/page bindings, and records 16 tensor slices, 15 MoE tensor slices, one embedding tensor slice, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, 16 slice/page hash matches, `bf16_tensor_slice_stats_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`. It keeps full checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61ab hotset tensor tile quant probe is implemented and covered by `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`. It consumes v61aa, runs bounded dot-tile probes over the sampled real-checkpoint BF16 tensor slices, and records 128 tensor tile probe rows, 120 MoE tile rows, 8 embedding tile rows, 524288 BF16 tile values, 384 sample trace rows, 128/128 finite baseline/q8/q4 dot rows, 128/128 finite q8/q4 error rows, 128/128 PyTorch CPU matvec parity rows over real-checkpoint BF16 tiles, q8/q4 mean absolute dot errors of 0.00113809798/0.0244754219, `torch_matvec_parity_ready=1`, `q8_quant_probe_ready=1`, `q4_quant_probe_ready=1`, and `checkpoint_payload_bytes_committed_to_repo=0`. It includes an optional local safetensors-root expert FFN parity executor and keeps typed readiness split: fixture execution is tested, but the official run has `expert_ffn_parity_real_model_execution_ready=0` until a real local Mixtral checkpoint root is supplied. It keeps full checkpoint materialization, full safetensors page-hash coverage, real expert FFN parity, MoE block parity, logits parity, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61ac hotset token budget replay is implemented and covered by `experiments/test_v61ac_hotset_token_budget_replay.sh`. It consumes v61x/v61z/v61ab, binds the 37 source-bound workload rows to sampled direct-I/O page schedules and sampled BF16/q8/q4 numeric tile probes, and records 37 token-budget rows, 148 active page schedule rows, 1184 tile-binding rows, 37/37 finite token-budget rows, 1184/1184 finite tile-binding rows, four active page reads per token, 32 active tile probes per token, 131072 BF16 tile values per token, 8388608 SSD read bytes per token, sampled token direct-I/O p50/p95 budgets of 2.323072/3.82676 ms, and `checkpoint_payload_bytes_committed_to_repo=0`. It keeps full checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61ad KV + weight token budget replay is implemented and covered by `experiments/test_v61ad_kv_weight_token_budget_replay.sh`. It consumes v61ac and v61m, combines the 37 source-bound sampled hotset token-budget rows with five KV context profiles, and records 185 combined KV+weight budget rows, 185/185 combined ready rows, 185/185 resident KV VRAM policy pass rows, 74/185 full-KV-in-VRAM pass rows, 111 NVMe cold KV eviction-required rows, zero host RAM spill bytes, 229376 KV bytes/token, 8388608 SSD read bytes/token, 8617984 sampled weight+new-KV bytes/token, max 8192 context, max resident KV VRAM bytes 270532608, max evicted NVMe KV bytes 1639972864, and `checkpoint_payload_bytes_committed_to_repo=0`. It keeps full KV-in-VRAM residency, full checkpoint materialization, full safetensors page-hash coverage, real Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61ae real generation admission gate is implemented and covered by `experiments/test_v61ae_real_generation_admission_gate.sh` plus `experiments/test_v61ae_real_generation_admission_gate_target_override.sh`. It consumes v61ad/v53r/v61r/v61t/v61w, binds complete-source review packets to sampled runtime budgets and materialization/page-hash state, records 1000 real-generation candidate rows, 0 admitted rows, 1000 runtime-budget-ready rows, 1000 source-review-blocked rows, 1000 materialization-blocked rows, 1000 page-hash-blocked rows, 0 local identity-verified shards, 0 full page-hash verified rows, `materialization_admission_ready=0`, `local_checkpoint_materialization_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and `checkpoint_payload_bytes_committed_to_repo=0`, and verifies that `V61AE_WAREHOUSE_ROOT` refreshes v61r/v61t/v61w source evidence over the supplied warehouse root. It keeps actual Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61af checkpoint warehouse operator bundle is implemented and covered by `experiments/test_v61af_checkpoint_warehouse_operator_bundle.sh` plus `experiments/test_v61af_checkpoint_warehouse_operator_bundle_target_override.sh`. It consumes v61w/v61t/v61r/v61ae, emits guarded repo-outside operator scripts for priority shard download, materialization verification, full page hashing, and generation-admission recheck, records 59 download commands, 62 operator command rows, six operator bundle files, `download_dry_run_default=1`, `full_hash_dry_run_default=1`, `planned_remaining_bytes=281241493344`, source-bound available SSD bytes copied from v61p, `materialization_admission_ready=0`, `local_checkpoint_materialization_ready=0`, `full_safetensors_page_hash_binding_ready=0`, `generation_admitted_rows=0`, and zero checkpoint payload bytes downloaded or committed by v61af, and verifies that `V61AF_WAREHOUSE_ROOT` propagates through source evidence, `operator_env.template`, guarded scripts, and verify/hash/admission command rows. It keeps SSD-budget admission, local materialization, full page-hash coverage, actual Mixtral generation, near-frontier quality, production latency, and release claims blocked.

The v61ag checkpoint warehouse execution preflight is implemented and covered by `experiments/test_v61ag_checkpoint_warehouse_execution_preflight.sh` plus `experiments/test_v61ag_checkpoint_warehouse_execution_preflight_target_override.sh`. It consumes v61af, syntax-checks the guarded operator scripts, executes a one-row dry-run download probe, records 62 operator command rows, 59 download commands, 4/4 script syntax pass rows, 4/4 executable rows, `download_dry_run_guard_ready=1`, `warehouse_outside_repo=1`, `operator_bundle_ignored_by_git=1`, `huggingface_cli_available=0`, `ssd_disk_budget_pass=0`, `download_execution_ready=0`, `operator_execution_preflight_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ag, and verifies that `V61AG_WAREHOUSE_ROOT` refreshes v61af and preserves the target in copied operator env/scripts and command rows. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked.

The v61ah checkpoint download backend fallback plan is implemented and covered by `experiments/test_v61ah_checkpoint_download_backend_fallback_plan.sh` plus `experiments/test_v61ah_checkpoint_download_backend_fallback_plan_target_override.sh`. It consumes v61ag, probes five download backend candidates, selects available `curl-resume` over the missing `huggingface-cli`, emits 59 curl-resume checkpoint shard download plan rows, records three ready backends, one backend dry-run probe with exit code 0, `download_backend_dry_run_guard_ready=1`, `python_huggingface_hub_available=1`, `curl_available=1`, `wget_available=1`, `ssd_disk_budget_pass=0`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ah, and verifies that `V61AH_WAREHOUSE_ROOT` propagates into target paths, curl commands, and the guarded backend script. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked.

The v61ai checkpoint storage budget remediation plan is implemented and covered by `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan.sh` plus `experiments/test_v61ai_checkpoint_storage_budget_remediation_plan_target_override.sh`. It consumes v61ah/v61p/v61w, records `required_with_reserve_bytes=315601231712`, live available SSD bytes copied from v61p, computed full/raw deficits, `safe_materialization_batch_rows=0`, a bounded diagnostic no-reserve top-priority batch, `download_backend_ready=1`, `download_execution_ready=0`, `storage_budget_remediation_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ai, and verifies that `V61AI_WAREHOUSE_ROOT` propagates through v61ah/v61p/v61w evidence and target paths. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked.

The v61aj checkpoint storage profile admission matrix is implemented and covered by `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix.sh` plus `experiments/test_v61aj_checkpoint_storage_profile_admission_matrix_target_override.sh`. It consumes v61ai/v61w, records six storage profile rows, three full-reserve-admitting profiles, four full-without-reserve profiles, first full-reserve profile `full-checkpoint-exact-with-reserve`, current reserve admitted shard rows 0, live current no-reserve diagnostic admitted shard rows/bytes, exact reserve admitted shard rows 59, computed minimum additional bytes, recommended operator free bytes 549755813888, and zero checkpoint payload bytes downloaded or committed by v61aj, and verifies that `V61AJ_WAREHOUSE_ROOT` propagates through v61ai and copied v61w target paths. It keeps current-host download execution, local materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked.

The v61ak checkpoint warehouse target preflight is implemented and covered by `experiments/test_v61ak_checkpoint_warehouse_target_preflight.sh`. It consumes v61aj/v61p, probes current, operator-supplied, and repository-control warehouse targets, records three target rows, repository-local target rejection, live current target free/deficit bytes, `required_with_reserve_bytes=315601231712`, `recommended_operator_free_bytes=549755813888`, `warehouse_target_preflight_ready=1`, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ak. It keeps current-host target selection, local materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked unless an outside-repository target with enough live free space is supplied.

The v61al checkpoint warehouse activation gate is implemented and covered by `experiments/test_v61al_checkpoint_warehouse_activation_gate.sh` plus `experiments/test_v61al_checkpoint_warehouse_activation_gate_target_override.sh`. It consumes v61ak/v61ah/v61w, emits 59 per-shard activation command rows, and records 0 admitted activation rows, 59 blocked activation rows, `activation_package_ready=0`, `selected_target_id=none`, `selected_backend_id=curl-resume`, `backend_ready=1`, explicit execution required, `download_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61al. The target-override smoke verifies that `V61AL_WAREHOUSE_ROOT` forces a fresh v61ak target probe before activation planning, so an operator-supplied external NVMe path is not masked by stale cached preflight rows. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production latency, and release claims blocked.

The v61am checkpoint post-activation verification gate is implemented and covered by `experiments/test_v61am_checkpoint_post_activation_verification_gate.sh` plus `experiments/test_v61am_checkpoint_post_activation_verification_gate_target_override.sh`. It consumes v61al/v61t/v61r, emits 59 post-activation verification rows, and records 0 ready rows, 59 blocked rows, 0 activation-admitted rows, 0 local identity verified shard rows, 0 verified page-hash rows out of 134161 required rows, `post_activation_verification_gate_ready=0`, `generation_gate_ready_after_post_activation=0`, and zero checkpoint payload bytes downloaded or committed by v61am. The target-override smoke verifies that `V61AM_WAREHOUSE_ROOT` forces fresh v61al/v61ak target planning before verification. It keeps actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61an checkpoint full page-hash execution gate is implemented and covered by `experiments/test_v61an_checkpoint_full_page_hash_execution_gate.sh` plus `experiments/test_v61an_checkpoint_full_page_hash_execution_gate_target_override.sh`. It consumes v61am/v61t/v61r, turns 134161 planned page hashes into 291 resumable execution chunks, and records 0 hashed chunks, 291 activation-blocked chunks, 0 local page hash verification rows, `full_page_hash_execution_ready=0`, `full_safetensors_page_hash_binding_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61an. The target-override smoke verifies that `V61AN_WAREHOUSE_ROOT` propagates through fresh v61am/v61al/v61ak planning before full page-hash scheduling. It keeps full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ao real model page-manifest coverage audit is implemented and covered by `experiments/test_v61ao_real_model_page_manifest_coverage_audit.sh`. It consumes v61q/v61v/v61an, audits the real Mixtral checkpoint manifest as metadata-only coverage, and records 59 shards, 1739 tensors, 134161 unique checkpoint pages, 135841 tensor/page segments, 1344/1344 layer-expert-MoE tensor coverage rows, 16 remote-hash-bound sample tensor rows, `real_model_page_manifest_coverage_ready=1`, `full_safetensors_page_hash_binding_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ao. It keeps local materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ap MoE coverage remote hash plan is implemented and covered by `experiments/test_v61ap_moe_coverage_remote_hash_plan.sh`. It consumes v61ao/v61q/v61v, emits 1344 representative layer-expert-MoE remote hash plan rows, preserves 15 already remote-hash-bound MoE sample rows, plans 1329 remaining representative range hashes, records `full_moe_coverage_remote_hash_ready=0`, `remote_hash_expansion_execution_ready=0`, and keeps zero checkpoint payload bytes downloaded or committed by v61ap. It keeps executed hash expansion, full page-hash coverage, local materialization, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61aq MoE remote hash execution gate is implemented and covered by `experiments/test_v61aq_moe_remote_hash_execution_gate.sh`. It consumes v61ap, emits 1329 guarded curl-range command rows and 21 resumable execution chunks, preserves 15 existing MoE remote hashes, records `remote_hash_execution_ready=0`, `full_moe_coverage_remote_hash_ready=0`, and keeps zero checkpoint payload bytes downloaded or committed by v61aq. It keeps executed remote hashing, full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ar MoE remote hash result intake gate is implemented and covered by `experiments/test_v61ar_moe_remote_hash_result_intake.sh`. It consumes v61aq, defines the hash-only result return schema for 1329 guarded command rows, preserves 15 existing MoE remote hashes, emits 1344 combined coverage rows, records 0 supplied/accepted result rows and 1329 final-deferred missing rows in the default path, and keeps `remote_hash_result_intake_ready=0`, `full_moe_coverage_remote_hash_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ar. It keeps full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61as hotset reuse admission gate is implemented and covered by `experiments/test_v61as_hotset_reuse_admission_gate.sh`. It consumes v61ac/v61ad/v61ar, records 37 source-bound token rows, 148 scheduled sampled MoE page touches, 15 unique cold-fill pages, 133 cache-hit rows, `cache_hit_rate=0.898648649`, `persistent_hotset_cold_fill_bytes=31457280`, `persistent_hotset_saved_bytes=278921216`, and `sampled_hotset_reuse_ready=1`, while keeping `full_runtime_hotset_reuse_admission_ready=0` and zero checkpoint payload bytes downloaded or committed by v61as. It keeps full MoE coverage, full page-hash coverage, local materialization, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61at prefetch overlap admission gate is implemented and covered by `experiments/test_v61at_prefetch_overlap_admission_gate.sh`. It consumes v61l/v61z/v61as, records 36/36 non-bootstrap sampled token rows passing steady-state prefetch overlap, p95 SSD page-read latency 0.956690 ms fitting inside a 2.053768 ms prior-token GPU page-kernel compute window, 25 no-prefetch-required rows, minimum steady-state overlap slack 1.097078 ms, `steady_state_prefetch_overlap_ready=1`, `bootstrap_cold_start_ready=0`, `prefetch_overlap_admission_ready=0`, `full_runtime_hotset_reuse_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61at. It keeps bootstrap cold-start, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61au prefetch queue-depth scheduler gate is implemented and covered by `experiments/test_v61au_prefetch_queue_depth_scheduler_gate.sh`. It consumes v61at, records 37 scheduler token rows, 15 sampled cold-fill issue rows, 11 steady-state prefetch issue rows, 11/11 steady-state deadline-met rows, 25 no-prefetch-required rows, configured queue depth 4, max steady-state required queue depth 1, `steady_state_scheduler_ready=1`, `bootstrap_scheduler_ready=0`, `prefetch_scheduler_admission_ready=0`, `actual_async_prefetch_execution_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61au. It keeps bootstrap scheduling, actual async I/O, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61av async prefetch execution probe is implemented and covered by `experiments/test_v61av_async_prefetch_execution_probe.sh`. It consumes v61au/v61z, executes 15 sampled prefetch issue reads through a queue-depth 4 threaded O_DIRECT worker pool, records 15/15 hash matches, zero async prefetch errors, 11/11 steady-state hash matches, four bootstrap read hash matches, `actual_async_prefetch_execution_ready=1`, `actual_io_uring_execution_ready=0`, `registered_buffers_ready=0`, `prefetch_scheduler_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61av. It keeps bootstrap admission, io_uring, registered buffers, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61aw io_uring registered-buffer preflight is implemented and covered by `experiments/test_v61aw_io_uring_registered_buffer_preflight.sh`. It consumes v61av, records current-host Linux UAPI header ready 1, liburing header ready 0, setup/enter/register syscall numbers 425/426/427, `io_uring_setup_errno_name=EPERM`, setup/enter/register ready 0, registered-buffer prefetch ready 0, threaded O_DIRECT fallback ready 1, and zero checkpoint payload bytes downloaded or committed by v61aw. It keeps actual io_uring execution, registered buffers, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ax async-I/O backend selection gate is implemented and covered by `experiments/test_v61ax_async_io_backend_selection_gate.sh`. It consumes v61aw/v61av, records `io_uring_registered_buffer` blocked by `io_uring_setup_errno_1_EPERM`, selects `threaded_odirect` as the current-host sampled prefetch backend, records queue depth 4, 15 hash-match rows, zero backend errors, `full_runtime_async_io_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ax. It keeps bootstrap admission, actual io_uring execution, registered buffers, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ay selected-backend token runtime binding is implemented and covered by `experiments/test_v61ay_selected_backend_token_runtime_binding.sh`. It consumes v61ad/v61ax, binds 185/185 combined KV+weight token budget rows and 5/5 context profiles to `threaded_odirect`, records 37 source-bound query rows, 74 full-KV-in-VRAM pass rows, 111 NVMe eviction-required rows, zero host RAM spill bytes, `full_runtime_async_io_admission_ready=0`, and zero checkpoint payload bytes downloaded or committed by v61ay. It keeps actual io_uring execution, registered buffers, full checkpoint materialization, full page-hash coverage, full runtime admission, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61az ubuntu-1 warehouse target admission is implemented and covered by `experiments/test_v61az_ubuntu1_warehouse_target_admission.sh`. It consumes v61aj/v61ak/v61ay, records `/dev/nvme0n1p8` label `ubuntu-1` mounted at `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25` as an outside-repository full-reserve capacity target, verifies 410615001088 live free bytes against `required_with_reserve_bytes=315601231712`, keeps operator margin as a recommended gap against `recommended_operator_free_bytes=549755813888`, records target write/activation readiness 0 in the current managed session, and downloads or commits zero checkpoint payload bytes. It keeps download execution, local materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61ba ubuntu-1 activation handoff package is implemented and covered by `experiments/test_v61ba_ubuntu1_activation_handoff_package.sh`. It consumes v61az/v61ah/v61w, rewrites all 59 checkpoint shard handoff rows plus post-download materialization verifier, full page-hash, and generation-admission recheck commands to the ubuntu-1 target, records `stale_tmp_target_command_rows=0`, keeps `activation_execution_ready=0`, and downloads or commits zero checkpoint payload bytes. It keeps operator/escalated write, download execution, local materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bb ubuntu-1 write sentinel activation probe is implemented and covered by `experiments/test_v61bb_ubuntu1_write_sentinel_activation_probe.sh`. It consumes v61ba, writes or observes a tiny JSON sentinel under the ubuntu-1 target, records `ubuntu1_write_witness_ready=1`, `operator_write_step_resolved_by_witness=1`, `activation_target_write_witness_ready=1`, keeps `activation_payload_execution_ready=0`, and downloads or commits zero checkpoint payload bytes. It keeps checkpoint payload execution, local materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bc ubuntu-1 sampled hotset materialization is implemented and covered by `experiments/test_v61bc_ubuntu1_sampled_hotset_materialization.sh`. It consumes v61bb/v61y, copies only the 16 already verified sampled hotset pages under the ubuntu-1 target, records 16/16 page presence, 16/16 hash matches, 16/16 readback hash matches, 33554432 sampled checkpoint payload bytes persisted on ubuntu-1, `checkpoint_payload_bytes_downloaded_by_v61bc=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bd ubuntu-1 sampled hotset direct-I/O replay is implemented and covered by `experiments/test_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh`. It consumes v61bc/v61x, reads the 16 ubuntu-1 sampled hotset pages through O_DIRECT, records 16/16 hash matches, 0 direct-I/O errors, 33554432 direct-I/O bytes, p50/p95 read latency 1.102615/1.234314 ms, 1946.456509 MiB/s sampled throughput, `ssd_read_bytes_per_token=8388608`, `checkpoint_payload_bytes_downloaded_by_v61bd=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61be ubuntu-1 hotset tensor-slice verifier is implemented and covered by `experiments/test_v61be_ubuntu1_hotset_tensor_slice_verifier.sh`. It consumes v61bd/v61v, interprets the 16 ubuntu-1 resident sampled hotset pages as real BF16 tensor segments, records 16 tensor slices, 15 MoE slices plus 1 embedding slice, 33550832 tensor-segment bytes, 65536 sampled BF16 values, 65536 finite values, zero NaN/Inf values, 16 ubuntu-1 page hash matches, 16 direct-read hash matches, `checkpoint_payload_bytes_downloaded_by_v61be=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bf ubuntu-1 tensor-tile quant probe is implemented and covered by `experiments/test_v61bf_ubuntu1_tensor_tile_quant_probe.sh`. It consumes v61be, runs bounded BF16/q8/q4 dot-tile probes over the ubuntu-1 resident tensor slices, records 128 tile probes, 120 MoE tile probes plus 8 embedding tile probes, 524288 BF16 tile values, 128/128 finite baseline/q8/q4 dot rows, q8/q4 mean absolute dot errors 0.00113809798/0.0244754219, 16 ubuntu-1 page hash matches, 16 direct-read hash matches, `checkpoint_payload_bytes_downloaded_by_v61bf=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bg ubuntu-1 token-budget replay is implemented and covered by `experiments/test_v61bg_ubuntu1_token_budget_replay.sh`. It consumes v61x/v61bd/v61bf, binds 37 source-bound workload rows to ubuntu-1 direct-I/O page schedules plus resident BF16/q8/q4 tile probes, records 37 token-budget rows, 148 scheduled page reads, 1184 tile-binding rows, 37/37 finite token budgets, 1184/1184 finite tile bindings, 8388608 SSD read bytes/token, 131072 BF16 tile values/token, p50/p95 token direct-I/O budgets 4.289692/5.237824 ms, q8/q4 mean error budgets 0.0364191354/0.783213501 per token, `checkpoint_payload_bytes_downloaded_by_v61bg=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bh ubuntu-1 KV+weight token-budget replay is implemented and covered by `experiments/test_v61bh_ubuntu1_kv_weight_token_budget_replay.sh`. It consumes v61bg/v61m, combines 37 ubuntu-1 token-budget rows with five KV context profiles, records 185 combined KV+weight budget rows, 185/185 ready rows, 185 resident KV policy pass rows, 74 full-KV-in-VRAM pass rows, 111 NVMe cold KV eviction-required rows, zero host RAM spill bytes, 229376 KV bytes/token, 8617984 weight+new-KV bytes/token, max 8192-context KV cold tier 1639972864 bytes, `checkpoint_payload_bytes_downloaded_by_v61bh=0`, and zero checkpoint payload bytes committed to the repo. It keeps full checkpoint materialization, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

The v61bi ubuntu-1 hotset reuse admission gate is implemented and covered by `experiments/test_v61bi_ubuntu1_hotset_reuse_admission_gate.sh`. It consumes v61bg/v61bh/v61ar, collapses 148 scheduled ubuntu-1 page reads into 15 unique cold-fill pages plus 133 cache-hit rows, records cache hit rate 0.898648649, cold-fill bytes 31457280, saved bytes 278921216, amortized cold-fill bytes/token 850196.756756757, `checkpoint_payload_bytes_downloaded_by_v61bi=0`, and zero checkpoint payload bytes committed to the repo. It keeps full runtime admission, full page-hash coverage, actual Mixtral generation, production latency, near-frontier, and release claims blocked.

## Immediate Next PR Target

The next implementation PR should extend v52-v60 from contract scaffold to measured and reviewed rows:

1. Closed in v59c: promote the v52m measured registry into the v59 replay bundle without weakening its local-only claim boundary.
2. Closed as v52k seed: supply and validate a real 7B-14B local model + RAG evidence directory for C over the v50 9-query seed.
3. Closed as v52l scale: expand C from the v50 seed to the shared v53e 1000-query set, producing real local C response/resource/transcript rows while preserving the no-quality-claim boundary.
4. Closed as v52m absorb: re-absorb the v52l C measured packet into the v52 measured registry alongside A/B/G/H while preserving the no-quality-claim boundary.
5. In progress as v52n/v52o seed: supply and validate real 30B and 70B open-weight LLM+RAG evidence directories for D and E over the v50 9-query seed.
6. In progress as v52s/v52u/v52v/v52t: NVMe weight-tier contract, mmap reader scaffold, ROCm HIP bind, and explicit D/E local deferral; next extend tiered matmul decode (v52w) or external bake, then v52p/q/r and v59c.
7. Closed as v52y default policy: keep F explicitly final-deferred with reason unless supplied evidence validates, and keep `v52_ready=0` plus 30B-150B comparison wording blocked until required D/E PM/release baseline readiness is accepted.
8. Closed as v53g/v53h/v53i/v53j/v53k/v53l/v53m/v53n/v53o/v53p/v53q/v53r/v53s/v53t seeds: expand v53c canary snapshots into a recursive complete-source tree manifest, complete-source content snapshot, 1000-row complete-source query/source-span instantiation, complete-source A/B/C/D/E/G/H intake surface, System A/B/C/G/H local measured rows, System D/E open-weight RAG supplied rows, symmetric scorer/policy rows, a complete-source review packet for the 10 locked repositories, a returned-review intake gate, and a complete-source audit readiness gate.
9. Closed as h10 PM real-label readiness gate: bind h10-s to v53q/v53ap/v53aq/v54c and emit a PM acceptance ledger for coherent wrong-key reduction, chunk exact increase, near-miss slash, missing-query abstain, source provenance binding, v53ap adapter-trace/evaluator provenance, v53aq sanitized-question-only real-adapter wrong-key/provenance plus 1000-row same-query prebaseline evidence and the four-row per-system internal pre-baseline contract rows, and external/human label evidence, while keeping `h10_real_label_promotion_ready=0`; v53ap proves deterministic source-span adapter execution, v53aq supplies internal real-adapter evidence, the v53aq per-system contract ledger pins each A/B/G/H run to the same shared query/evaluator/resource contract, and public comparison remains blocked.
10. Return actual human/source review artifacts, adjudication rows, reviewer identity/conflict rows, and quality-comparison evidence over the frozen v53i/v53r/v53s/v53t complete-source packet.
11. Supply accepted external/human h10 label evidence and h10 source-verified eval rows before promoting h10 as a real-label scorer contribution.
12. Promote the v54c complete-source 1000-row grounded generation run into the v59 replay bundle and release-review packet.
13. Promote the v55b six-axis / 360-row scaling-law main run into the v59 replay bundle and release-review packet, keeping GPU and production latency claims blocked until reviewed.
14. Promote the v56b 1500-row RULER/LongBench candidate-scale run into a symmetric benchmark packet by adding v52 LLM+RAG baseline rows and independent external verification where available.
15. Promote the v57b candidate rows into human-reviewed gold query sets by returning expert decisions, adjudication rows, privacy review, policy diffs, blind review forms, and reproducibility manifests for the six domain packs.
16. Promote the v58c/v58d intake chain into a real 500+ row blind evaluation by supplying valid D/E required responses, optional F response or final deferral, G/H responses, sealed-system scoring, human blind review, and inter-rater/adjudication rows.
17. Promote the v59e PM foundation replay into a full challenge demo by replacing blocker-ledger rows with real v52-v58 measured/reviewed rows, real blind responses, and a reviewer-ready artifact bundle.
18. Promote the v60b preflight into a real release audit only after v52-v59 real measured/reviewed rows exist, then supply human/release review evidence and a real release artifact package.
19. Keep comparison claims blocked until D/E are real, the citation verifier is symmetric, v53 reaches the repo/query scale target, v54 reaches the 1000-row generation target, v55 reaches the scaling-law main target, v56 reaches expanded benchmark scale, v57 has human-reviewed domain pack rows, v58 has real blind-eval rows, v59 replays those rows through one command, and v60 release requirements pass.
20. Closed as v61a-v61j prototype: replace the broken v52w-style page-to-kernel numeric path with a deterministic SSD page-store -> direct I/O reader -> RouteHint prefetch/VRAM cache -> CPU page-dequant-matmul -> expert router -> predictive prefetch -> mixed quant planner -> dense stress blocker -> logical 128B MoE active-sparse contract -> one-command demo chain, including token-level SSD I/O metrics and no-RAM-resident full-model audit rows.
21. Closed as v61k manifest seed: replace the logical-only model reference with a legally redistributable Mixtral 8x22B page manifest, while keeping checkpoint weight materialization and runtime claims blocked.
22. Closed as v61l/v61m/v61n/v61o/v61p/v61q/v61r/v61s/v61t/v61u/v61v/v61w/v61x/v61y/v61z/v61aa/v61ab/v61ac/v61ad/v61ae/v61af/v61ag/v61ah/v61ai/v61aj/v61ak/v61al/v61am/v61an measurement seeds: add GPU/ROCm page-dequant-matmul timing, KV-cache residency/eviction policy, a source-bound QA workload seed, checkpoint index/header/sampled page-hash probes, local SSD checkpoint residency preflight, real safetensors-header-derived checkpoint page mapping, a full page-hash sweep plan, one-command source-bound QA replay, local checkpoint materialization identity verification, bounded remote checkpoint page-hash samples, remote-hashed page tensor/runtime-node binding, materialization admission/download-resume planning, NVMe hotset runtime replay manifest binding, sampled hotset local materialization, sampled hotset direct-I/O read replay, sampled BF16 tensor-slice interpretation, sampled BF16/q8/q4 numeric tile probes, sampled source-bound hotset token-budget replay, sampled KV+weight token-budget replay, sampled real generation admission gate, guarded checkpoint warehouse operator bundle, checkpoint warehouse execution preflight, checkpoint download backend fallback planning, checkpoint storage budget remediation planning, checkpoint storage profile admission matrixing, checkpoint warehouse target preflight, checkpoint warehouse activation gating, checkpoint post-activation verification gating, and checkpoint full page-hash execution gating over the v61k/v53g evidence path, while keeping full checkpoint materialization blocked, host-RAM KV spill disabled, full-KV-in-VRAM blocked for long context, full page-hash coverage blocked, real Mixtral generation blocked, production latency blocked, and complete-source A-H QA blocked. Next v61 runtime steps are satisfying the v61p/v61w/v61ai/v61aj/v61ak/v61al/v61am/v61an SSD/target/activation/post-activation/full-hash budget and full local shard presence requirements outside the repository, completing full safetensors page-hash coverage, and real model generation over source-bound workloads without opening near-frontier or release claims until external review passes.

This completes the v52-v60 contract scaffold chain without weakening the claim boundary. It does not complete the v1.0 Architecture Challenge itself.
