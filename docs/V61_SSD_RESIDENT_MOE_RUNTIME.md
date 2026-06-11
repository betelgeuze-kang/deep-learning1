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

## Evaluation Ladder

The benchmark ladder should be ordered by runtime risk:

1. Synthetic page store, no model.
2. Tiny transformer shard, deterministic numeric checks.
3. 7B dense page-store execution proxy.
4. 30B dense stress, blocked if not practical.
5. 70B dense stress, blocked if not practical.
6. Small MoE with real expert routing.
7. 100B+ total-parameter MoE active-sparse runtime.
8. Same runtime under code/doc QA workloads.
9. Same runtime under long-context workloads with KV policy.
10. One-command local assistant demo.

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

## Immediate Next Implementation Target

Move from the logical 128B contract fixture to real-model evidence without weakening the boundary:

1. Replace the logical 128B contract fixture with a real open-weight MoE checkpoint shard or a legally redistributable page manifest.
2. Add GPU/ROCm page-dequant-matmul measurements and keep CPU fallback rows for reproducibility.
3. Add a KV-cache residency/eviction policy so long-context claims remain gated by measured rows.
4. Run source-bound code/doc QA workloads through the v61j command and bind answers to citation/abstain/fallback evidence.
5. Keep real 100B materialization, near-frontier quality, production latency, and release claims blocked until external review passes.

## Success Shape

The current v61 runtime prototype can say:

- the model warehouse is SSD-resident
- model weights are not fully RAM-resident
- the active execution set is routed into VRAM
- MoE/page routing is measured
- prefetch reduces stalls
- mixed quantization is bounded by quality gates
- SSD read bytes per token are within a practical local-PC budget

The full local assistant claim additionally requires source-bound tasks with citation, abstain, and fallback evidence over real open-weight model rows.

The correct current claim is:

> v61 is a measured prototype artifact for SSD-resident active-sparse local LLM runtime research. It proves the prepared SSD page-store path and logical 100B+ MoE contract, not real near-frontier open-weight inference.
