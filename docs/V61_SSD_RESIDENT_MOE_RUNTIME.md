# v61 SSD-Resident MoE Runtime Roadmap

## Goal

v61 reframes the post-v52 direction as an SSD-resident open-weight LLM runtime.

The target is not RAM offload and not dense full-weight streaming. The target is:

> Store hundreds of billions to trillions of open-weight parameters on NVMe SSD, keep only the active execution set in VRAM, and use discrete-node routing, MoE sparsity, predictive prefetch, and mixed quantization to make a local PC feel like a near-frontier local assistant.

This is a runtime research track, not a release claim. It must preserve the existing route invariant:

- value-bearing route hint path only
- candidate value position -> value byte read -> proposal hint
- no jump-neighbor topology promotion
- `routing_trigger_rate = 0`
- `active_jump_rate = 0`

## Claim Boundary

Allowed current claim:

- SSD-resident runtime roadmap for active-sparse local LLM execution.
- NVMe weight-store, page routing, prefetch, and quantization contracts can be measured as research artifacts.
- RouteMemory and RouteHint are being redirected from answer-only evidence toward runtime scheduling evidence.
- Bounded remote checkpoint page hashes can be bound to real tensor/page segments
  and runtime nodes as metadata-only evidence.

Blocked until verified:

- local PC runs a dense hundreds-B model at practical speed
- local PC runs a trillions-parameter dense model
- near-frontier quality equivalence
- GPU speedup claim
- production latency guarantee
- release-ready product claim

## Core Thesis

Dense full forward over an SSD-resident hundreds-B model is the wrong objective.

For a 200B dense model at 4-bit weight precision, the weight file is roughly 100 GB before metadata and cache overhead. Reading all of that per token from a 7 GB/s PCIe 4 NVMe drive would already cost more than 14 seconds per token on I/O alone. PCIe 5 improves the bound but does not change the conclusion.

Therefore, the v61 objective is:

- keep total parameters large on SSD
- keep active parameters per token small
- predict the next active expert/page set before it is needed
- measure `ssd_read_bytes_per_token` as the main runtime budget
- treat SSD misses as first-class model errors, not just storage delays

## What Current Research Is Missing

1. Token-level I/O budget.
   Existing v52s/v52u/v52v work proves a weight-tier direction, but the main success metric is not yet `bytes/token`. v61 must make `ssd_read_bytes_per_token`, `prefetch_miss_ms_per_token`, and `tokens_per_second` first-class outputs.

2. Page and expert routing nodes.
   Existing RouteMemory nodes focus on evidence, spans, and answer grounding. v61 needs nodes for `expert_node`, `tensor_page_node`, `layer_block_node`, `quant_profile_node`, `prefetch_action_node`, and `fallback_node`.

3. Runtime energy objective.
   Local energy must become a runtime score:

   `expected_quality_gain - ssd_read_cost - vram_cache_cost - prefetch_miss_penalty - quantization_risk`

4. NVMe prefetch scheduler.
   `mmap` is not enough. The runtime needs explicit asynchronous reads, aligned pages, queue depth control, VRAM hot cache admission, and fallback when pages arrive late.

5. MoE-first model target.
   Dense 100B+ can be a stress test, but the near-frontier local path must be MoE or another active-sparse architecture. Total parameters may be hundreds-B to trillions, while active parameters per token must stay in a local-PC budget.

6. Page-level mixed quantization.
   Whole-model Q4/Q3 is too blunt. Quantization must be assigned by page, tensor, layer, or expert, with quality-risk metadata bound to the scheduler.

7. KV-cache policy.
   SSD-resident weights do not solve long-context memory pressure. v61 needs a KV cache policy with active VRAM window, compression/eviction, RouteMemory recall, and blocked long-context claims until measured.

## Target Architecture

### Storage Layer

The SSD stores a model warehouse, not a flat monolith:

- aligned 2-16 MB weight pages
- tensor/page metadata
- layer and expert IDs
- quantization type and scale offsets
- checksum per page
- prefetch group ID
- hot/warm/cold frequency labels
- optional compression block metadata

Preferred Linux path:

- phase 1: `mmap` for correctness and artifact continuity
- phase 2: `O_DIRECT` aligned reads
- phase 3: `io_uring` with registered buffers and queue-depth tuning
- phase 4: SPDK or GPUDirect Storage only after the correctness path is stable

### Execution Layer

The execution loop should be structured as:

1. Decode state is summarized into a route state.
2. RouteMemory proposes candidate expert/page sets.
3. Local energy scores candidate sets against quality and I/O cost.
4. RouteHint emits a compact prefetch plan.
5. NVMe scheduler reads required pages into staging buffers.
6. VRAM hot cache admits high-value pages.
7. Dequant/matmul kernels consume pages.
8. Late or missing pages trigger fallback, smaller model, or abstain path.
9. Metrics are written per token and per page.

### Cache Layer

VRAM should hold:

- active KV cache window
- router/gating tensors
- embeddings and output head where feasible
- current layer hot pages
- next layer predicted pages
- high-frequency experts
- dequant scratch buffers

SSD should hold:

- cold experts
- rare layer blocks
- low-frequency tensor pages
- alternate quant profiles
- long-tail model warehouse

RAM should not be used as a model-resident tier in this research claim. Small control metadata, pinned transfer buffers, and OS bookkeeping are acceptable, but model weight residency must be accounted separately.

## Required Metrics

Every v61 runtime artifact should emit:

- `ssd_model_bytes_total`
- `ssd_pages_total`
- `ssd_pages_read`
- `ssd_read_bytes_total`
- `ssd_read_bytes_per_token`
- `nvme_read_latency_ms_p50`
- `nvme_read_latency_ms_p95`
- `prefetch_queue_depth`
- `prefetch_hit_rate`
- `prefetch_miss_ms_per_token`
- `vram_hot_cache_bytes`
- `vram_cache_hit_rate`
- `active_parameters_per_token`
- `dequant_ms_per_token`
- `matmul_ms_per_token`
- `tokens_per_second`
- `time_to_first_token_ms`
- `quality_score`
- `abstain_rate`
- `fallback_rate`
- `wrong_route_rate`
- `quant_profile_id`
- `route_jump_rows`

Readiness must require `route_jump_rows=0`.

## Milestones

### v61a SSD Weight Page Store

Build a deterministic page-store writer.

Outputs:

- `weight_page_rows.csv`
- `weight_tensor_rows.csv`
- `weight_expert_rows.csv`
- `quant_profile_rows.csv`
- `page_checksum_rows.csv`
- `V61A_SSD_WEIGHT_PAGE_STORE_BOUNDARY.md`

Pass condition:

- pages are aligned
- checksums verify
- total model bytes and page counts match the manifest
- no claim that the model can decode yet

### v61b Direct I/O Page Reader

Add an SSD page reader that does not depend on RAM residency.

Outputs:

- `direct_io_read_rows.csv`
- `read_latency_rows.csv`
- `read_alignment_rows.csv`
- `page_fault_or_cache_policy_rows.csv`

Pass condition:

- aligned reads succeed
- checksums match
- `ssd_read_bytes_total` is measured
- model weights are not loaded as a full RAM-resident copy

### v61c VRAM Hot Cache

Implement page admission and eviction for a small VRAM cache.

Outputs:

- `vram_cache_rows.csv`
- `cache_admission_rows.csv`
- `cache_eviction_rows.csv`
- `cache_hit_miss_rows.csv`

Pass condition:

- cache size stays under a configured VRAM budget
- repeated hot pages hit
- cold pages evict predictably

### v61d Page Dequant Matmul

Close the broken v52w-style path with correctness first.

Outputs:

- `page_dequant_rows.csv`
- `page_matmul_rows.csv`
- `numeric_check_rows.csv`
- `kernel_transcript_rows.csv`

Pass condition:

- SSD page bytes feed a GPU or CPU matmul probe
- numeric checks pass
- page hashes bind to kernel inputs
- failures are recorded instead of promoted

### v61e Expert Router

Introduce MoE-aware routing.

Outputs:

- `expert_route_candidate_rows.csv`
- `expert_energy_rows.csv`
- `expert_selection_rows.csv`
- `wrong_expert_guard_rows.csv`

Pass condition:

- active expert set is selected without loading all experts
- wrong-route examples are blocked or fall back
- active parameters per token are measured

### v61f Predictive Prefetch

Move from reactive reads to token/layer lookahead.

Outputs:

- `prefetch_plan_rows.csv`
- `prefetch_execution_rows.csv`
- `prefetch_hit_miss_rows.csv`
- `stall_rows.csv`

Pass condition:

- prefetch hit rate improves over no-prefetch baseline
- stall time is measured
- late pages trigger fallback

### v61g Mixed Quantization Planner

Choose quantization by page/tensor/expert.

Outputs:

- `quant_sensitivity_rows.csv`
- `quant_assignment_rows.csv`
- `quant_quality_delta_rows.csv`
- `quant_runtime_delta_rows.csv`

Pass condition:

- high-sensitivity pages stay high precision
- cold/low-sensitivity pages can move lower precision
- quality and I/O tradeoff is measured

### v61h Dense Stress Harness

Use 30B/70B dense models as stress targets, not as the final architecture.

Outputs:

- `dense_stress_read_rows.csv`
- `dense_stress_decode_proxy_rows.csv`
- `dense_blocker_rows.csv`

Pass condition:

- dense full-stream cost is measured
- blocker is explicit when practical speed is not reachable
- no dense hundreds-B local speed claim is opened

### v61i 100B+ MoE Active-Sparse Run

First real target for the intended architecture.

Outputs:

- `moe_model_identity_rows.csv`
- `moe_expert_page_rows.csv`
- `moe_active_parameter_rows.csv`
- `moe_decode_metric_rows.csv`
- `moe_quality_rows.csv`

Pass condition:

- total parameters are 100B+
- active parameters per token are bounded
- SSD read bytes per token are bounded
- practical decode speed is measured
- release and near-frontier claims remain blocked until external review

### v61j One-Command SSD-Resident Demo

Bundle the runtime into a reproducible local command.

Outputs:

- one command entrypoint
- runtime summary CSV
- SSD/VRAM budget report
- RouteMemory/RouteHint schedule trace
- quality and fallback report
- claim boundary

Pass condition:

- the command runs from a clean local checkout with a prepared SSD model store
- it proves the SSD-resident active-sparse path
- it does not silently fall back to RAM-resident full-model inference

### v61k Real-Model Page Manifest

Replace the logical-only 128B fixture with a legally redistributable page
manifest bound to a real open-weight MoE model identity.

Outputs:

- `real_model_identity_rows.csv`
- `real_model_source_rows.csv`
- `real_model_config_rows.csv`
- `license_redistribution_rows.csv`
- `checkpoint_shard_manifest_rows.csv`
- `tensor_page_manifest_rows.csv`
- `expert_page_budget_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- real public MoE model identity, config, license, and source URLs are recorded
- page manifest contains metadata only and no checkpoint weights
- total-parameter direction is 100B+
- uncached active path budget blocker is explicit
- real checkpoint materialization, GPU speedup, KV-cache, source-bound QA,
  near-frontier, production-latency, and release claims remain blocked

### v61l GPU Page Dequant Matmul Measurement

Measure a ROCm/HIP page kernel over the v61k real-model page geometry.

Outputs:

- `gpu_page_dequant_matmul_rows.csv`
- `real_model_manifest_binding_rows.csv`
- `rocm_toolchain_rows.csv`
- `rocm_device_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61k Mixtral page manifest is bound
- one 2 MiB q4-equivalent page tile is measured by a real ROCm/HIP kernel
- numeric checks pass
- the payload is disclosed as synthetic q4 page geometry
- real checkpoint materialization, safetensors page hash binding, KV-cache,
  source-bound QA, near-frontier, production-latency, and release claims remain
  blocked

### v61m KV Cache Residency Eviction Policy

Bind the Mixtral KV-cache geometry to a deterministic residency/eviction policy.

Outputs:

- `kv_cache_geometry_rows.csv`
- `kv_residency_policy_rows.csv`
- `kv_budget_profile_rows.csv`
- `kv_eviction_trace_rows.csv`
- `kv_eviction_event_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61k Mixtral config and v61l page-kernel evidence are bound
- KV bytes per token and KV tokens per 2 MiB page are computed from the model
  config
- VRAM hot/sink window fits the configured KV budget
- older KV pages spill to an NVMe cold tier with `host_ram_spill_bytes=0`
- real checkpoint materialization, safetensors page hash binding,
  source-bound QA, long-context quality, near-frontier, production-latency, and
  release claims remain blocked

### v61n Source-Bound QA Workload Seed

Bind the runtime evidence chain to a source-bound code/doc QA workload seed.

Outputs:

- `source_manifest_binding_rows.csv`
- `source_bound_query_rows.csv`
- `source_bound_answer_rows.csv`
- `source_bound_citation_rows.csv`
- `source_bound_abstain_rows.csv`
- `source_bound_resource_rows.csv`
- `runtime_binding_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61j one-command runtime evidence is bound
- v61m KV-cache policy evidence is bound
- v53g complete-source manifest is bound
- materialized v53c canary-overlap files provide the cited source bytes
- supported answers have citation rows and unsupported runtime claims abstain
- complete-source A-H QA rows, real Mixtral generation, safetensors page hash
  binding, near-frontier, production-latency, and release claims remain blocked

### v61o Checkpoint Shard Header Probe

Strengthen the real-model checkpoint binding without downloading full weights.

Outputs:

- `checkpoint_index_rows.csv`
- `checkpoint_shard_http_identity_rows.csv`
- `safetensors_header_probe_rows.csv`
- `safetensors_header_tensor_rows.csv`
- `sampled_page_hash_probe_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61k Mixtral page manifest is bound
- Hugging Face safetensors index is hash-bound
- all 59 checkpoint shards have HTTP identity rows
- all safetensors headers are range-read and parsed
- sampled first-page payload hashes are recorded without persisting payload bytes
- full checkpoint materialization, full page-hash coverage, local SSD checkpoint
  residency, real generation, near-frontier, production-latency, and release
  claims remain blocked

### v61p Local SSD Checkpoint Residency Preflight

Turn the v61o shard identity table into an outside-repository SSD warehouse
plan and local presence audit without downloading checkpoint payload bytes.

Outputs:

- `ssd_warehouse_probe_rows.csv`
- `ssd_disk_budget_rows.csv`
- `checkpoint_residency_requirement_rows.csv`
- `checkpoint_download_plan_rows.csv`
- `local_shard_presence_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61o checkpoint shard/header evidence is bound
- the warehouse path is outside the git repository
- all 59 shard download-plan rows are emitted
- disk budget and local shard presence are explicit blockers or passes
- no checkpoint payload bytes are downloaded by the runner or committed to the
  repository
- full page-hash coverage, real generation, near-frontier, production-latency,
  and release claims remain blocked

### v61q Real Checkpoint Page Map

Convert the real safetensors header tensor offsets into a metadata-only 2 MiB
SSD page map for the Mixtral checkpoint.

Outputs:

- `checkpoint_tensor_page_span_rows.csv`
- `checkpoint_page_segment_rows.csv`
- `checkpoint_unique_page_rows.csv`
- `checkpoint_shard_page_summary_rows.csv`
- `checkpoint_page_map_metric_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61o checkpoint index, shard identity, and safetensors header rows are bound
- all 1739 real checkpoint tensor rows are mapped to 2 MiB page spans
- the map records 134161 unique checkpoint pages and 135841 tensor/page
  segments
- the map is metadata-only: no checkpoint payload bytes are redistributed,
  persisted, or committed to the repository
- full page-hash coverage, local SSD checkpoint residency, real generation,
  near-frontier, production-latency, and release claims remain blocked

### v61r Full Page Hash Sweep Plan

Turn the v61q page map and v61p local shard presence audit into a full
safetensors page-hash sweep plan.

Outputs:

- `page_hash_sweep_plan_rows.csv`
- `local_page_hash_verification_rows.csv`
- `sampled_remote_page_hash_binding_rows.csv`
- `shard_page_hash_sweep_status_rows.csv`
- `page_hash_sweep_metric_rows.csv`
- `runtime_gap_rows.csv`

Pass condition:

- v61q real checkpoint page map evidence is bound
- v61p outside-repository warehouse and local shard presence evidence is bound
- every v61q checkpoint page has one page-hash task row
- v61o sampled remote page hashes are bound to overlapping v61q page rows
- local page hashes are verified only when shards are resident outside the
  repository and `V61R_ENABLE_LOCAL_HASH_SWEEP=1`
- completed full page-hash coverage, local SSD checkpoint residency, real
  generation, near-frontier, production-latency, and release claims remain
  blocked until every local checkpoint page is hashed

### v61s One-Command Source-Bound QA Replay

Exercise the v61 one-command entrypoint in source-bound QA mode and verify that
the v61n workload passes through the command-level path.

Outputs:

- `one_command_replay_rows.csv`
- `source_bound_workload_pass_rows.csv`
- `runtime_gap_rows.csv`
- `one_command_stdout.txt`
- `one_command_stderr.txt`
- `V61S_ONE_COMMAND_SOURCE_BOUND_QA_REPLAY_BOUNDARY.md`

Pass condition:

- `./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa` exits with code 0
- v61j runtime evidence and v61n source-bound QA rows are bound
- every source-bound query has a citation-supported pass row
- every abstain row has a verified abstain-policy row
- actual model generation, completed full page-hash coverage, complete-source
  1000+ audit completion, near-frontier, production-latency, and release claims
  remain blocked

### v61t Local Checkpoint Materialization Verifier

Promote local SSD shard presence from size-only preflight into identity
verification for any outside-repository checkpoint shards that are already
present on the host.

Outputs:

- `local_checkpoint_materialization_rows.csv`
- `sampled_local_page_hash_verification_rows.csv`
- `local_checkpoint_materialization_metric_rows.csv`
- `materialization_gap_rows.csv`
- `V61T_LOCAL_CHECKPOINT_MATERIALIZATION_VERIFIER_BOUNDARY.md`

Pass condition:

- v61p local shard presence, v61q real checkpoint page map, and v61r full
  page-hash sweep plan evidence are bound
- every shard has an identity-verification row
- a local shard is counted as identity verified only when exact byte length,
  safetensors header hash, and any required sampled page hash match
- no checkpoint payload bytes are downloaded by the runner or committed to the
  repository
- completed checkpoint materialization, full page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked until all 59 shards pass identity verification and every page is
  hashed

### v61u Remote Checkpoint Page Hash Sampler

Expand real checkpoint page-hash evidence without downloading full shards by
performing bounded HTTP Range reads over deterministic v61q full-size checkpoint
pages.

Outputs:

- `remote_page_hash_sample_plan_rows.csv`
- `remote_page_hash_sample_rows.csv`
- `remote_page_hash_page_map_overlap_rows.csv`
- `remote_page_hash_sample_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61U_REMOTE_CHECKPOINT_PAGE_HASH_SAMPLER_BOUNDARY.md`

Pass condition:

- v61q real checkpoint page map and v61t materialization verifier evidence are
  bound
- deterministic full-size v61q checkpoint page rows are selected
- every sampled remote page has an HTTP Range read, byte count, page sha256, and
  page-map overlap row
- checkpoint payload bytes are not persisted or committed to the repository
- full safetensors page-hash coverage, local checkpoint materialization, real
  generation, near-frontier, production-latency, and release claims remain
  blocked because bounded remote samples are not exhaustive coverage

### v61v Remote Page Tensor Binding

Bind bounded remote checkpoint page-hash samples to real safetensors tensor/page
segments and runtime scheduling nodes without claiming local residency or full
page-hash coverage.

Outputs:

- `selected_v61q_page_segment_rows.csv`
- `remote_sample_tensor_binding_rows.csv`
- `remote_sample_runtime_node_rows.csv`
- `remote_sample_tensor_role_summary_rows.csv`
- `remote_sample_tensor_coverage_rows.csv`
- `remote_sample_tensor_binding_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61V_REMOTE_PAGE_TENSOR_BINDING_BOUNDARY.md`

Pass condition:

- v61u remote page-hash sample evidence and v61q checkpoint page-map evidence
  are bound
- every sampled remote page has a tensor/page segment binding and runtime-node
  row
- MoE expert sampled pages include layer and expert indices
- checkpoint payload bytes are not persisted or committed to the repository
- local checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked because the binding covers bounded samples only

## Evaluation Ladder

The benchmark ladder should be ordered by runtime risk:

1. Synthetic page store, no model.
2. Tiny transformer shard, deterministic numeric checks.
3. 7B dense page-store execution proxy.
4. 30B dense stress, blocked if not practical.
5. 70B dense stress, blocked if not practical.
6. Small MoE with real expert routing.
7. 100B+ total-parameter MoE active-sparse runtime.
8. Real open-weight MoE page manifest, no redistributed weights.
9. Checkpoint index/shard/header and sampled page-hash probes.
10. Real safetensors-header-derived checkpoint page map.
11. Full page-hash sweep plan and sampled hash binding.
12. Local SSD checkpoint residency preflight and presence audit.
13. GPU/ROCm page-kernel timing over the real-model page geometry.
14. KV-cache residency/eviction policy over the real-model geometry.
15. Source-bound code/doc QA workload seed over materialized files.
16. One-command source-bound QA replay.
17. Remote-hashed checkpoint page tensor/runtime-node binding.
18. Complete-source 1000+ QA workload with real model generation.
19. Same runtime under long-context workloads with source-bound quality checks.
20. One-command local assistant demo.

## Stop Rules

Stop and keep claims blocked when any of these occur:

- `ssd_read_bytes_per_token` exceeds the configured practical budget
- prefetch misses dominate token latency
- VRAM cache exceeds budget
- full model becomes RAM-resident
- page checksums do not bind to kernel inputs
- quantization changes output beyond accepted quality delta
- wrong expert route produces unguarded answers
- route/jump activity becomes nonzero
- benchmark success depends on external bake rows instead of local SSD runtime

## Relationship To v52-v60

v52-v60 remain the comparison and release-audit chain.

v61 is the implementation track that can make the local-machine story stronger:

- v52s/v52u/v52v become the seed of the v61a-v61d page/runtime correctness layer.
- v52w remains a weak/broken HIP diagnostic path, but v61d now provides the correctness-first replacement through CPU deterministic page-dequant-matmul.
- v52x external bake import should be treated as a fallback evidence intake, not as the main research path.
- v59/v60 may reference the v61j artifact only as an evidence-bound SSD-resident active-sparse prototype; they still must not promote near-frontier, production-latency, or release claims without real-model review.

## Current Implemented Prototype

The v61a-v61j SSD-resident active-sparse prototype is implemented and covered by:

```bash
./experiments/test_v61j_one_command_ssd_resident_demo.sh
```

It emits:

- `results/v61a_ssd_weight_page_store/store_001/`
- `results/v61b_direct_io_page_reader/reader_001/`
- `results/v61c_vram_hot_cache/cache_001/`
- `results/v61d_page_dequant_matmul/matmul_001/`
- `results/v61e_expert_router/router_001/`
- `results/v61f_predictive_prefetch/prefetch_001/`
- `results/v61g_mixed_quant_planner/quant_001/`
- `results/v61h_dense_stress_harness/dense_001/`
- `results/v61i_100b_moe_active_sparse_run/moe_001/`
- `results/v61j_one_command_ssd_resident_demo/demo_001/`

Verified current summary:

- `v61j_one_command_ssd_resident_demo_ready=1`
- all v61a-v61j primary ready flags are `1`
- `ssd_resident_active_sparse_path_proven=1`
- `ssd_resident_runtime_seed_ready=1`
- `no_ram_weight_residency_ready=1`
- `routehint_prefetch_plan_ready=1`
- `tiny_moe_fixture_ready=1`
- `ram_resident_full_model_fallback_rows=0`
- `prefetch_hit_rate=0.333333`
- `stall_improvement_ms_total=6.000000`
- `total_parameters=128000000000`
- `logical_active_parameters_per_token=8000000000`
- `ssd_read_bytes_per_token_max=8388608`
- `route_jump_rows=0`
- `real_100b_open_weight_materialized=0`
- `near_frontier_claim_ready=0`
- `real_release_package_ready=0`

This closes the local SSD-resident active-sparse runtime prototype and one-command artifact chain. It does not materialize a real 100B open-weight checkpoint, does not prove GPU speedup, does not prove near-frontier local inference, and is not a release package.

## Current Real-Model Manifest

The first v61 real-model page manifest step is implemented and covered by:

```bash
./experiments/test_v61k_real_model_page_manifest.sh
```

It emits:

- `results/v61k_real_model_page_manifest/manifest_001/`

Verified current summary:

- `v61k_real_model_page_manifest_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `source_model_license=apache-2.0`
- `published_total_parameter_label=8x22B`
- `published_total_parameters_estimate=176000000000`
- `total_parameters_100b_plus=1`
- `checkpoint_shard_manifest_rows=59`
- `tensor_page_manifest_rows=129024`
- `legally_redistributable_page_manifest_ready=1`
- `real_checkpoint_weight_bytes_materialized=0`
- `real_100b_open_weight_materialized=0`
- `active_uncached_q4_bytes_per_token_estimate=16911433728`
- `ssd_read_budget_bytes_per_token=16777216`
- `active_uncached_q4_budget_pass=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This moves v61 from a logical-only 128B fixture toward real-model evidence by
binding the page manifest to a public MoE model config and license. It also
shows that reading uncached active expert weights per token is still far over
the current SSD budget, so the next runtime work must prove persistent hot
cache, reuse, GPU page-dequant-matmul, and KV residency rather than claiming
practical near-frontier inference.

## Current GPU Page-Kernel Measurement

The first v61 ROCm page-kernel measurement is implemented and covered by:

```bash
./experiments/test_v61l_gpu_page_dequant_matmul_measurement.sh
```

It emits:

- `results/v61l_gpu_page_dequant_matmul_measurement/gpu_001/`

Verified current summary:

- `v61l_gpu_page_dequant_matmul_measurement_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `page_size_bytes=2097152`
- `q4_page_bytes=2097152`
- `tile_m=1024`
- `tile_k=4096`
- `iterations=20`
- positive `gpu_kernel_avg_ms`
- positive `gpu_page_dequant_gflops`
- positive `gpu_page_bandwidth_gbps`
- `max_abs_delta=0.00000000`
- `real_checkpoint_weight_bytes_materialized=0`
- `kv_cache_policy_ready=0`
- `source_bound_qa_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This is allowed to claim only ROCm page-kernel timing over v61k page geometry.
It is not real Mixtral inference speed: the payload is synthetic q4 page
geometry, real safetensors page hashes are not bound, and no source-bound QA
workload consumes the kernel yet.

## Current KV Cache Policy

The first v61 KV-cache residency/eviction policy is implemented and covered by:

```bash
./experiments/test_v61m_kv_cache_residency_eviction_policy.sh
```

It emits:

- `results/v61m_kv_cache_residency_eviction_policy/kv_001/`

Verified current summary:

- `v61m_kv_cache_residency_eviction_policy_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `kv_bytes_per_token=229376`
- `kv_tokens_per_page=9`
- `kv_page_payload_bytes=2064384`
- `hot_window_tokens=1024`
- `sink_tokens=128`
- `vram_kv_budget_bytes=402653184`
- `max_context_tokens=8192`
- `max_total_kv_pages=911`
- `max_resident_vram_pages=129`
- `max_resident_vram_bytes=270532608`
- `max_evicted_nvme_pages=782`
- `max_evicted_nvme_bytes=1639972864`
- `sequence_profile_rows=5`
- `kv_eviction_trace_rows=1766`
- `kv_eviction_event_rows=1208`
- `vram_budget_pass_all_profiles=1`
- `full_kv_vram_budget_pass_all_profiles=0`
- `host_ram_kv_spill_enabled=0`
- `kv_cache_policy_ready=1`
- `source_bound_qa_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This is allowed to claim only a deterministic KV residency/eviction policy over
Mixtral page geometry. It is not long-context quality evidence: source-bound QA,
exact long-context replay, production latency, and release readiness remain
blocked.

## Current Source-Bound QA Workload

The first v61 source-bound QA workload seed is implemented and covered by:

```bash
./experiments/test_v61n_source_bound_qa_workload.sh
```

It emits:

- `results/v61n_source_bound_qa_workload/qa_001/`

Verified current summary:

- `v61n_source_bound_qa_workload_ready=1`
- `source_bound_qa_workload_ready=1`
- `source_bound_query_rows >= materialized_source_file_rows + bound_repo_count`
- `source_bound_supported_answer_rows == materialized_source_file_rows`
- `source_bound_abstain_rows == bound_repo_count`
- `source_bound_citation_rows == source_bound_query_rows`
- `source_bound_resource_rows == source_bound_query_rows`
- `bound_repo_count=10`
- `materialized_source_file_rows >= 20`
- `complete_source_manifest_binding_rows == materialized_source_file_rows`
- `answer_citation_support_pass_rows == source_bound_query_rows`
- `abstain_policy_verified_rows == source_bound_abstain_rows`
- `runtime_binding_ready=1`
- `actual_model_generation_ready=0`
- `complete_source_1000_query_ready=0`
- `complete_source_content_snapshot_ready=0`
- `real_checkpoint_weight_bytes_materialized=0`
- `safetensors_page_hash_binding_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This is allowed to claim only a source-bound QA workload seed over materialized
v53c canary-overlap files that are also bound to the v53g complete-source
manifest. v53i now supplies a complete-source 1000-query/source-span set, but
this v61 seed is still not complete-source A-H QA and it is not real Mixtral
checkpoint generation.

## Current Checkpoint Shard Header Probe

The first v61 checkpoint shard/header probe is implemented and covered by:

```bash
./experiments/test_v61o_checkpoint_shard_header_probe.sh
```

It emits:

- `results/v61o_checkpoint_shard_header_probe/probe_001/`

Verified current summary:

- `v61o_checkpoint_shard_header_probe_ready=1`
- `checkpoint_index_ready=1`
- `checkpoint_index_weight_map_tensor_rows=1739`
- `checkpoint_shard_http_identity_rows=59`
- `safetensors_header_probe_rows=59`
- `safetensors_header_probe_ready_rows=59`
- `safetensors_header_tensor_rows=1739`
- `sampled_page_hash_probe_rows=3`
- `sampled_page_payload_bytes_read=6291456`
- `sampled_safetensors_page_hash_binding_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_weight_bytes_persisted=0`
- `real_checkpoint_weight_bytes_materialized=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This is allowed to claim checkpoint index, shard HTTP identity, safetensors
header, and sampled page-hash probe evidence. It is not full checkpoint
residency, full page-hash coverage, or real Mixtral generation.

### v61p Local SSD Checkpoint Residency Preflight

The local SSD checkpoint residency preflight is implemented and covered by:

```bash
./experiments/test_v61p_local_ssd_checkpoint_residency_preflight.sh
```

It emits:

- `results/v61p_local_ssd_checkpoint_residency_preflight/preflight_001/`

Verified current summary:

- `v61p_local_ssd_checkpoint_residency_preflight_ready=1`
- `checkpoint_shard_rows=59`
- `total_checkpoint_bytes_required=281241493344`
- `ssd_reserve_bytes=34359738368`
- `required_with_reserve_bytes=315601231712`
- `available_ssd_bytes=21337460736`
- `ssd_disk_budget_pass=0`
- `ssd_warehouse_path=/home/betelgeuze/.cache/deep_learning_v61p_mixtral_8x22b_warehouse`
- `ssd_warehouse_outside_repo=1`
- `checkpoint_download_plan_rows=59`
- `local_shard_presence_rows=59`
- `local_complete_shard_rows=0`
- `local_checkpoint_residency_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61p=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `real_checkpoint_weight_bytes_materialized=0`
- `real_100b_open_weight_materialized=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

This is allowed to claim an outside-repository checkpoint warehouse plan, disk
budget audit, and local shard presence audit. It is not completed checkpoint
residency until the outside-repository SSD warehouse contains all 59 shards and
enough free-space reserve remains; it is also not full page-hash coverage or
real Mixtral generation.

## Immediate Next Implementation Target

Move from the real-model page manifest into measured real-model runtime evidence
without weakening the boundary:

1. Add optional local checkpoint shard/header intake for the v61k manifest, still
   without committing weight bytes.
2. Closed as v61l seed: add GPU/ROCm page-dequant-matmul measurements over the v61k page geometry while keeping real checkpoint weights blocked.
3. Closed as v61m seed: add a KV-cache residency/eviction policy so long-context claims remain gated by measured rows.
4. Closed as v61n seed: run a source-bound code/doc QA workload through the v61 evidence chain and bind answers to citation/abstain/resource evidence.
5. Closed as v61o seed: add checkpoint index, safetensors header, and sampled page-hash probe intake without persisting checkpoint payload bytes.
6. Closed as v61p preflight: add an outside-repository local SSD checkpoint residency plan, disk budget audit, and shard presence audit without downloading checkpoint payload bytes.
7. Closed as v61t verifier: promote v61p size/presence rows into local shard identity verification using safetensors header hashes and sampled page hashes, while keeping materialization blocked on the current host.
8. Closed as v61u sampler: expand sampled page-hash evidence with bounded remote full-page range hashes while keeping full page-hash coverage blocked.
9. Closed as v61v binder: bind remote-hashed sampled pages to real tensor/page segments and runtime nodes while keeping full coverage and local materialization blocked.
10. Promote identity-verified local shards into full safetensors page-hash coverage.
11. Promote the v53i complete-source query set into A-H QA and real model generation only after checkpoint/page hash binding exists.
12. Keep real 100B materialization, near-frontier quality, production latency, and release claims blocked until external review passes.

## Success Shape

The current v61 runtime prototype can say:

- the prepared page-store path is SSD-resident for deterministic fixture pages
- the real Mixtral checkpoint has an outside-repository SSD residency preflight,
  but not completed local shard residency on the current host
- model weights are not fully RAM-resident
- the active execution set is routed into VRAM
- MoE/page routing is measured
- prefetch reduces stalls
- mixed quantization is bounded by quality gates
- SSD read bytes per token are within a practical local-PC budget
- KV cache residency/eviction has a deterministic VRAM hot plus NVMe cold policy
- source-bound QA has a citation/abstain workload seed over materialized files
- checkpoint shard identity, safetensors headers, and sampled page hashes are bound
- checkpoint residency currently requires 315601231712 bytes with reserve and is
  blocked by the current 21337460736-byte SSD budget
- local checkpoint materialization has an identity verifier, but the current
  host has 0 local existing shards and 0 identity-verified shards
- bounded remote page-hash sampling has read 16 full 2 MiB checkpoint pages and
  stored hashes only, not payload bytes or full coverage
- those 16 remote-hashed pages are bound to 16 real tensor/runtime-node rows,
  including 15 MoE expert page bindings across 15 layers and all eight expert
  indices

The full local assistant claim additionally requires source-bound tasks with citation, abstain, and fallback evidence over real open-weight model rows.

The correct current claim is:

> v61 is a measured prototype artifact for SSD-resident active-sparse local LLM runtime research. It proves the prepared SSD page-store path, logical 100B+ MoE contract, real-model redistributable page manifest, checkpoint identity/header/sample-page binding, local SSD residency preflight, local checkpoint materialization identity verification mechanics, bounded remote checkpoint page-hash samples, and remote-hashed page tensor/runtime-node bindings, not completed real-checkpoint residency, full safetensors page-hash coverage, or real near-frontier open-weight inference.
