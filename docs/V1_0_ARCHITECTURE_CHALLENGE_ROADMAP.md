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

- `experiments/run_v52_llm_rag_baseline_war.sh`
- `experiments/test_v52_llm_rag_baseline_war.sh`
- `experiments/run_v52b_small_local_rag_measured_row.sh`
- `experiments/test_v52b_small_local_rag_measured_row.sh`
- `experiments/run_v52c_7b14b_local_model_rag_evidence_intake.sh`
- `experiments/test_v52c_7b14b_local_model_rag_evidence_intake.sh`
- `experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh`
- `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh`
- `experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`
- `experiments/test_v52e_100b_plus_hosted_llm_rag_optional_intake.sh`
- `experiments/run_v53_public_repo_code_doc_audit.sh`
- `experiments/test_v53_public_repo_code_doc_audit.sh`
- `experiments/run_v53b_public_repo_10_lock.sh`
- `experiments/test_v53b_public_repo_10_lock.sh`
- `experiments/run_v53c_public_repo_canary_source_snapshot.sh`
- `experiments/test_v53c_public_repo_canary_source_snapshot.sh`
- `experiments/run_v54_routehint_generation_1000_contract.sh`
- `experiments/test_v54_routehint_generation_1000_contract.sh`
- `experiments/run_v55_local_scaling_law_main_contract.sh`
- `experiments/test_v55_local_scaling_law_main_contract.sh`
- `experiments/run_v56_ruler_longbench_expanded_contract.sh`
- `experiments/test_v56_ruler_longbench_expanded_contract.sh`
- `experiments/run_v57_domain_expert_packs_contract.sh`
- `experiments/test_v57_domain_expert_packs_contract.sh`
- `experiments/run_v58_blind_eval_contract.sh`
- `experiments/test_v58_blind_eval_contract.sh`
- `examples/v1_0_architecture_challenge_demo.sh`
- `experiments/run_v59_one_command_challenge_demo_contract.sh`
- `experiments/test_v59_one_command_challenge_demo_contract.sh`
- `experiments/run_v60_architecture_challenge_release_contract.sh`
- `experiments/test_v60_architecture_challenge_release_contract.sh`
- `results/v52_llm_rag_baseline_war/baseline_001/` contract artifacts
- `results/v52b_small_local_rag_measured_row/row_001/` measured system-B seed artifacts
- `results/v52c_7b14b_local_model_rag_evidence_intake/intake_001/` system-C evidence-intake artifacts
- `results/v52d_30b70b_llm_rag_evidence_intake/intake_001/` system-D/E evidence-intake artifacts
- `results/v52e_100b_plus_hosted_llm_rag_optional_intake/intake_001/` system-F optional evidence-intake artifacts
- `results/v53_public_repo_code_doc_audit/audit_001/` contract artifacts
- `results/v53b_public_repo_10_lock/lock_001/` live 10-repo target-lock artifacts
- `results/v53c_public_repo_canary_source_snapshot/snapshot_001/` pinned canary source snapshot artifacts
- `results/v54_routehint_generation_1000_contract/contract_001/` contract artifacts
- `results/v55_local_scaling_law_main_contract/contract_001/` contract artifacts
- `results/v56_ruler_longbench_expanded_contract/contract_001/` contract artifacts
- `results/v57_domain_expert_packs_contract/contract_001/` contract artifacts
- `results/v58_blind_eval_contract/contract_001/` contract artifacts
- `results/v59_one_command_challenge_demo_contract/contract_001/` contract artifacts
- `results/v60_architecture_challenge_release_contract/contract_001/` contract artifacts

This scaffold emits the A-H baseline registry, adapter contract rows, symmetric evaluation contract rows, score axes, source-preview copies, and claim boundary. It intentionally keeps `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and `optional_100b_plus_baseline_status=deferred-with-reason`.

The v52b measured-row layer emits the first system-B small-local-RAG answer/citation/retrieval/resource rows over the v50 public-repo seed. It intentionally marks only `v52_absorb_ready=1`; it keeps `v52_ready=0`, `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, and all 30B-150B comparison claims blocked.

The v52c evidence-intake layer emits the system-C 7B-14B local-model-RAG schema, answer template, model identity template, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `supplied_evidence_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked until a real local model evidence directory validates.

The v52d evidence-intake layer emits the system-D/E 30B/70B open-weight LLM+RAG schemas, answer templates, model identity templates, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `required_30b_baseline_ready=0`, `required_70b_baseline_ready=0`, `v52_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked until both real D and E evidence directories validate.

The v52e optional-intake layer emits the system-F 100B+ hosted/API LLM+RAG schema, answer template, model identity template, validation rows, source evidence copies, hash manifest, and claim boundary. Default/no-env execution intentionally keeps `optional_100b_plus_baseline_status=deferred-with-reason`, `optional_100b_plus_baseline_ready=0`, `v52_optional_absorb_ready=0`, `v52_ready=0`, and all 30B-150B comparison claims blocked. F is optional and cannot replace required D/E evidence.

The v53 scaffold emits a 10-repo target registry, 1000-query scale contract, artifact contract rows, v50 seed evidence copies, and claim boundary. It intentionally keeps `v53_ready=0`, `missing_repo_count=7`, and `missing_query_rows=991`.

The v53b repo-lock layer resolves live HEAD SHAs for 10 public GitHub repositories, writes the 10-repo lock table and 1000-row query plan, and copies the v50 seed evidence. It intentionally keeps `v53_ready=0` because the seven newly locked repositories still need source snapshots and the audit still needs source-span-bound query rows, A-H answer/citation/resource rows, negative/abstain rows, and review artifacts.

The v53c canary source snapshot layer fetches pinned source/doc/config canary files from all 10 locked repositories and records sha256 content rows. It intentionally keeps `v53_ready=0`, `full_source_snapshot_missing_repo_count=7`, and `missing_query_rows=991` because canary files are not complete source snapshots and do not provide the 1000-row audit, A-H answer/citation/resource rows, negative/abstain rows, or review artifacts.

The v54 scaffold emits a 1000-row RouteHint generation target, six domain targets, no-attention/no-raw-context invariants, artifact contract rows, v48/v54 seed evidence copies, and claim boundary. It intentionally keeps `v54_generation_1000_ready=0` and `missing_generation_rows=976`.

The v55 scaffold emits a six-axis / 100-row scaling-law target, fit contract rows, no-oracle/no-extractor/RouteMemory-lineage invariants, v51 seed curve copies, and claim boundary. It intentionally keeps `v55_local_scaling_law_ready=0`, `repo_count_axis_ready=0`, and `missing_scaling_curve_rows=73`.

The v56 scaffold emits RULER and LongBench expanded benchmark targets, official source/evaluator artifact contracts, no-oracle/no-extractor/RouteMemory-lineage invariants, v49/v45 seed evidence copies, and claim boundary. It intentionally keeps `v56_ruler_longbench_expanded_ready=0`, `ruler_missing_rows=500`, `longbench_missing_rows=494`, and `llm_rag_baseline_rows_ready=0`.

The v57 scaffold emits six domain-pack targets, expert-review artifact contracts, domain policy gates, v47/v48/v52/v56 seed evidence copies, and claim boundary. It intentionally keeps `v57_domain_expert_packs_ready=0`, `missing_eval_rows=950`, `human_expert_review_ready=0`, `blind_eval_ready=0`, and `expert_replacement_claim=0`.

The v58 scaffold emits D-H blind-system mapping, 500-row blind query-freeze targets, blind evaluator artifact contracts, sealed identity and symmetric-evidence gates, v52/v57 seed evidence copies, and claim boundary. It intentionally keeps `v58_ready=0`, `missing_blind_eval_rows=500`, `required_30b_blind_response_ready=0`, `required_70b_blind_response_ready=0`, `human_blind_review_ready=0`, and `inter_rater_rows_ready=0`.

The v59 scaffold emits a repository one-command entrypoint, v52-v58 contract bundle, stage/gate rows, replay command, README_RESULT, hash manifest, and claim boundary. It intentionally keeps `v59_ready=0`, all v52-v58 full-ready stage rows at zero, and the real 30B/70B, public repo scale, generation, scaling, expanded benchmark, domain pack, blind-eval, and release blockers explicit.

The v60 scaffold emits release requirement rows, allowed claim rows, forbidden claim rows, release decision rows, v59 source bundle copies, hash manifest, and claim boundary. It intentionally keeps `v60_ready=0`, all ten release requirements blocked, `real_release_package_ready=0`, and all v1.0 comparison/release claims blocked until real measured rows and human/release review evidence exist.

## Immediate Next PR Target

The next implementation PR should extend v52-v60 from contract scaffold to measured and reviewed rows:

1. Absorb and scale the measured B small-local-RAG row beyond the current 9-row v50 seed.
2. Supply and validate a real 7B-14B local model + RAG evidence directory for C.
3. Supply and validate real 30B and 70B open-weight LLM+RAG evidence directories for D and E.
4. Supply and validate a 100B+ hosted/API row for F when credentials and policy allow it, or keep it explicitly deferred with reason.
5. Expand v53c canary snapshots into complete source snapshots for the seven newly locked repositories.
6. Expand code/doc query coverage from 9 to at least 1000 source-span-bound rows.
7. Expand RouteHint generation from 24 seed rows to at least 1000 grounded rows.
8. Expand scaling from 5 preview axes / 27 rows to 6 main axes / at least 100 rows, including repo_count, confidence intervals, and failure cases.
9. Expand RULER to at least 1000 official-source/evaluator-bound rows and LongBench to at least 500 rows, with v52 baseline rows where benchmark format allows.
10. Fill the six domain expert packs with human-reviewed gold query sets, rubrics, failure taxonomy, blind review forms, policy diffs, privacy review, and reproducibility manifests.
11. Run the 500+ row blind evaluation with sealed system identity, frozen pre-output query selection, symmetric evidence budgets, human blind review, and inter-rater/adjudication rows.
12. Turn the v59 command from contract bundle into a challenge demo by replaying the real v52-v58 measured rows and writing a reviewer-ready artifact bundle.
13. Supply human/release review evidence and a real release artifact package only after v52-v59 real rows exist.
14. Keep comparison claims blocked until D/E are real, the citation verifier is symmetric, v53 reaches the repo/query scale target, v54 reaches the 1000-row generation target, v55 reaches the scaling-law main target, v56 reaches expanded benchmark scale, v57 has human-reviewed domain pack rows, v58 has real blind-eval rows, v59 replays those rows through one command, and v60 release requirements pass.

This completes the v52-v60 contract scaffold chain without weakening the claim boundary. It does not complete the v1.0 Architecture Challenge itself.
