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
- `V61R_WAREHOUSE_ROOT` target override forces fresh v61p shard-presence
  planning and rewrites local shard paths to the supplied external warehouse
  root
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

### v61w Materialization Admission Resume Plan

Turn the local checkpoint residency blockers and sampled tensor bindings into a
deterministic materialization admission and download-resume plan without
downloading checkpoint payload bytes.

Outputs:

- `checkpoint_shard_priority_rows.csv`
- `checkpoint_download_resume_plan_rows.csv`
- `materialization_admission_rows.csv`
- `materialization_stage_rows.csv`
- `materialization_runtime_gap_rows.csv`
- `materialization_admission_metric_rows.csv`
- `V61W_MATERIALIZATION_ADMISSION_RESUME_PLAN_BOUNDARY.md`

Pass condition:

- v61p, v61q, v61t, and v61v evidence is bound
- `V61W_WAREHOUSE_ROOT` target override forces fresh v61t/v61p planning and
  preserves target-aware `V61T_WAREHOUSE_ROOT`/`V61R_WAREHOUSE_ROOT`
  post-download commands
- all 59 checkpoint shards have priority and download-resume rows
- remote-hashed MoE expert and embedding sample shards are promoted before
  generic checkpoint backfill shards
- checkpoint payload bytes are not downloaded, persisted, or committed to the
  repository
- SSD budget admission, local checkpoint materialization, full safetensors
  page-hash coverage, real generation, near-frontier, production-latency, and
  release claims remain blocked on the current host

### v61x Hotset Runtime Replay Manifest

Bind the remote-hashed sampled checkpoint pages to deterministic NVMe hotset
slots and to the source-bound replay workload, while still writing no checkpoint
payload bytes.

Outputs:

- `hotset_runtime_page_rows.csv`
- `hotset_runtime_slot_rows.csv`
- `hotset_source_bound_workload_binding_rows.csv`
- `hotset_runtime_replay_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61X_HOTSET_RUNTIME_REPLAY_MANIFEST_BOUNDARY.md`

Pass condition:

- v61w materialization plan, v61v remote page tensor binding, v61m KV policy,
  and v61s source-bound replay evidence are bound
- 16 remote-hashed real checkpoint pages are assigned to planned NVMe hotset
  slots outside the repository
- 15 MoE expert pages and one embedding page are included in the hotset manifest
- 37 source-bound replay rows are bound to the same hotset manifest
- checkpoint payload bytes are not downloaded, persisted, or committed by v61x
- hotset payload materialization, SSD budget admission, local checkpoint
  materialization, full safetensors page-hash coverage, real generation,
  near-frontier, production-latency, and release claims remain blocked

### v61y Hotset Local Materialization Verifier

Materialize only the bounded sampled hotset pages outside the repository and
verify local readback hashes against the remote checkpoint page hashes.

Outputs:

- `hotset_local_materialization_rows.csv`
- `hotset_local_readback_rows.csv`
- `hotset_local_materialization_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61Y_HOTSET_LOCAL_MATERIALIZATION_BOUNDARY.md`

Pass condition:

- v61x hotset manifest and v61u remote page-hash evidence are bound
- all 16 sampled hotset pages exist outside the repository
- all 16 local page hashes match the corresponding remote page hashes
- all 16 local readback hashes match the corresponding remote page hashes
- 33554432 sampled checkpoint payload bytes are persisted outside the repository
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, SSD budget admission, local full-checkpoint
  materialization, full safetensors page-hash coverage, real generation,
  near-frontier, production-latency, and release claims remain blocked

### v61z Hotset Direct I/O Replay

Replay direct local reads over the bounded v61y sampled hotset pages and verify
each O_DIRECT read against the remote checkpoint page hash.

Outputs:

- `hotset_direct_io_read_rows.csv`
- `hotset_direct_io_prefetch_order_rows.csv`
- `hotset_direct_io_latency_rows.csv`
- `hotset_direct_io_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61Z_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md`

Pass condition:

- v61y sampled hotset materialization evidence is bound
- all 16 sampled hotset pages are read through O_DIRECT
- all 16 direct reads match the corresponding remote checkpoint page hashes
- 15 MoE expert pages are scheduled before the embedding page in replay order
- 33554432 direct-I/O bytes are read, with `ssd_read_bytes_per_token=8388608`
- sampled direct-read latency/throughput metrics are recorded
- full checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked

### v61aa Hotset Tensor Slice Verifier

Interpret the sampled local hotset pages as BF16 tensor segments using the real
safetensors tensor/page bindings, without executing model generation.

Outputs:

- `hotset_tensor_slice_stat_rows.csv`
- `hotset_tensor_slice_sample_value_rows.csv`
- `hotset_tensor_slice_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AA_HOTSET_TENSOR_SLICE_BOUNDARY.md`

Pass condition:

- v61z direct-I/O hotset replay and v61v tensor/page binding evidence are bound
- 16 local sampled hotset pages map to 16 real BF16 tensor slices
- the slices cover 15 MoE expert pages and one embedding page
- 33550832 tensor-segment bytes are hash-bound to the sampled local pages
- 65536 sampled BF16 values are finite, with zero sampled NaN/Inf values
- derived tensor-slice stats are recorded without committing checkpoint payload
  bytes to the repository
- full checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked

### v61ab Hotset Tensor Tile Quant Probe

Run bounded numeric dot-tile probes over the sampled real-checkpoint BF16 tensor
slices and compare q8/q4 dequantized dot probes, without executing model
generation.

Outputs:

- `hotset_tensor_tile_probe_rows.csv`
- `hotset_tensor_tile_sample_trace_rows.csv`
- `hotset_tensor_tile_quant_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AB_HOTSET_TENSOR_TILE_QUANT_BOUNDARY.md`

Pass condition:

- v61aa sampled BF16 tensor-slice evidence is bound
- 128 bounded tensor tile probes run over 524288 BF16 values
- the probes cover 120 MoE tile rows and 8 embedding tile rows
- 128/128 baseline dot rows are finite
- 128/128 q8 and q4 dequantized dot rows are finite
- q8/q4 quantized dot error metrics are recorded without committing checkpoint
  payload bytes to the repository
- full checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked

### v61ac Hotset Token Budget Replay

Bind source-bound workload rows to sampled hotset direct-I/O latency and
sampled BF16/q8/q4 numeric tile probes, without executing model generation.

Outputs:

- `hotset_token_budget_rows.csv`
- `hotset_token_budget_page_schedule_rows.csv`
- `hotset_token_budget_tile_binding_rows.csv`
- `hotset_token_budget_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AC_HOTSET_TOKEN_BUDGET_BOUNDARY.md`

Pass condition:

- v61x source-bound replay binding, v61z direct-I/O latency, and v61ab numeric
  tile evidence are bound
- 37 source-bound workload rows map to 37 token-budget rows
- the replay emits 148 active page schedule rows and 1184 tile-binding rows
- each token budget uses four active page reads and 32 active tile probes
- each token budget records 8388608 SSD read bytes and 131072 BF16 tile values
- sampled token direct-I/O p50/p95 budgets are recorded as
  2.323072/3.82676 ms
- full checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked

### v61ad KV + Weight Token Budget Replay

Bind sampled source-bound hotset token-budget rows to the deterministic
KV-cache residency/eviction policy, without executing model generation.

Outputs:

- `kv_weight_context_profile_rows.csv`
- `kv_weight_token_budget_rows.csv`
- `kv_weight_token_budget_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AD_KV_WEIGHT_TOKEN_BUDGET_BOUNDARY.md`

Pass condition:

- v61ac sampled hotset token-budget evidence and v61m KV policy evidence are
  bound
- 37 source-bound token-budget rows combine with five KV context profiles into
  185 KV+weight budget rows
- all 185 combined rows pass the resident VRAM-hot/NVMe-cold KV policy
- full-KV-in-VRAM remains blocked for long context, with only 74/185 combined
  rows passing full KV residency
- 111 combined rows require NVMe cold KV eviction
- host RAM KV spill remains disabled with zero spill bytes
- sampled weight+new-KV bytes per token are recorded as 8617984
- full checkpoint materialization, full safetensors page-hash coverage, real
  generation, near-frontier, production-latency, and release claims remain
  blocked

### v61ae Real Generation Admission Gate

Bind sampled KV+weight runtime budgets, complete-source review packets, and
materialization/page-hash state into a real generation admission gate, without
executing Mixtral generation.

Outputs:

- `real_generation_candidate_rows.csv`
- `real_generation_admission_requirement_rows.csv`
- `real_generation_admission_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AE_REAL_GENERATION_ADMISSION_BOUNDARY.md`

Pass condition:

- v61ad runtime-budget evidence, v53r complete-source review packets, v61r full
  page-hash sweep state, v61t local materialization state, and v61w
  materialization admission state are bound
- `V61AE_WAREHOUSE_ROOT` target override forces fresh v61r/v61t/v61w source
  evidence over the supplied external warehouse root
- 1000 complete-source real-generation candidate rows are emitted
- zero candidate rows are admitted for actual model generation
- all 1000 candidate rows have runtime-budget evidence ready
- all 1000 candidate rows remain blocked by source review, materialization, and
  full safetensors page-hash gates
- checkpoint payload bytes committed to the repository remain zero
- actual model generation, near-frontier quality, production-latency, and
  release claims remain blocked

### v61af Checkpoint Warehouse Operator Bundle

Turn the v61w materialization plan into guarded repo-outside operator scripts
for the real Mixtral checkpoint warehouse, without downloading checkpoint
payload bytes by default.

Outputs:

- `checkpoint_warehouse_operator_command_rows.csv`
- `checkpoint_warehouse_operator_stage_rows.csv`
- `checkpoint_warehouse_operator_metric_rows.csv`
- `operator_bundle/README.md`
- `operator_bundle/download_priority_queue.sh`
- `operator_bundle/verify_materialization.sh`
- `operator_bundle/run_full_page_hash_sweep.sh`
- `operator_bundle/recheck_real_generation_admission.sh`
- `V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md`

Pass condition:

- v61w materialization planning, v61t local materialization state, v61r full
  page-hash sweep state, and v61ae generation admission state are bound
- `V61AF_WAREHOUSE_ROOT` target override propagates through source evidence,
  `operator_env.template`, guarded scripts, and verify/hash/admission command
  rows
- 59 guarded shard download commands are emitted in priority order
- 62 operator command rows and six operator bundle files are emitted
- download execution defaults to dry-run and requires
  `V61AF_EXECUTE_DOWNLOAD=1`
- full page hashing defaults to dry-run and requires
  `V61AF_EXECUTE_FULL_HASH=1`
- checkpoint payload bytes downloaded or committed by v61af remain zero
- SSD-budget admission, local checkpoint materialization, full page-hash
  coverage, actual model generation, near-frontier, production-latency, and
  release claims remain blocked

### v61ag Checkpoint Warehouse Execution Preflight

Verify the guarded v61af operator bundle before any real checkpoint payload
download or full page-hash execution.

Outputs:

- `checkpoint_warehouse_environment_rows.csv`
- `checkpoint_warehouse_operator_script_probe_rows.csv`
- `checkpoint_warehouse_dry_run_probe_rows.csv`
- `checkpoint_warehouse_execution_gate_rows.csv`
- `checkpoint_warehouse_execution_preflight_metric_rows.csv`
- `V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md`

Pass condition:

- v61af operator bundle evidence is bound
- `V61AG_WAREHOUSE_ROOT` target override forces fresh v61af bundle evidence and
  preserves the supplied external warehouse target in copied operator
  env/scripts and download command rows
- all four operator scripts pass `bash -n` and have executable bits set
- a one-row dry-run download probe exits 0 and sees the dry-run guard
- the checkpoint warehouse target is outside the repository
- the operator bundle remains ignored by git
- `download_execution_ready=0` until CLI, SSD budget, outside-repo warehouse,
  and explicit execution gates pass
- checkpoint payload bytes downloaded or committed by v61ag remain zero
- local materialization, full page-hash coverage, actual generation,
  production-latency, and release claims remain blocked

### v61ah Checkpoint Download Backend Fallback Plan

Remove the hard dependency on `huggingface-cli` by probing available checkpoint
download backends and selecting a guarded fallback backend, without downloading
checkpoint payload bytes.

Outputs:

- `checkpoint_download_backend_candidate_rows.csv`
- `checkpoint_download_backend_plan_rows.csv`
- `checkpoint_download_backend_dry_run_rows.csv`
- `checkpoint_download_backend_metric_rows.csv`
- `operator_bundle/download_priority_queue_backend.sh`
- `V61AH_CHECKPOINT_DOWNLOAD_BACKEND_FALLBACK_BOUNDARY.md`

Pass condition:

- v61ag execution preflight evidence is bound
- `V61AH_WAREHOUSE_ROOT` target override propagates through v61ag/v61af and
  into backend target paths, curl commands, and the guarded backend script
- five backend candidates are probed
- an available backend is selected for all 59 checkpoint shard rows
- `curl-resume` is selected when `huggingface-cli` is unavailable
- backend download script defaults to dry-run and requires
  `V61AH_EXECUTE_DOWNLOAD=1`
- backend dry-run guard exits 0 without payload execution
- checkpoint payload bytes downloaded or committed by v61ah remain zero
- SSD-budget admission, local materialization, full page-hash coverage, actual
  generation, production-latency, and release claims remain blocked

### v61ai Checkpoint Storage Budget Remediation Plan

Quantify the remaining SSD storage blocker after the backend fallback is ready,
and emit a bounded remediation plan without downloading checkpoint payload bytes.

Outputs:

- `checkpoint_storage_budget_remediation_rows.csv`
- `checkpoint_materialization_batch_rows.csv`
- `checkpoint_no_reserve_candidate_shard_rows.csv`
- `checkpoint_storage_budget_metric_rows.csv`
- `V61AI_CHECKPOINT_STORAGE_BUDGET_REMEDIATION_BOUNDARY.md`

Pass condition:

- v61ah backend fallback, v61p storage budget, and v61w shard-priority evidence
  are bound
- `V61AI_WAREHOUSE_ROOT` target override propagates through v61ah/v61p/v61w
  evidence and target paths
- `required_with_reserve_bytes=315601231712`
- live `available_ssd_bytes` and computed full/raw budget deficits are recorded
- reserve-safe materialization admits zero shard rows
- the diagnostic no-reserve top-priority batch is bounded by live available
  bytes and remains non-admitted by reserve policy
- checkpoint payload bytes downloaded or committed by v61ai remain zero
- storage-budget remediation, actual materialization, full page-hash coverage,
  actual generation, production-latency, and release claims remain blocked

### v61aj Checkpoint Storage Profile Admission Matrix

Convert the v61ai SSD budget blocker into deterministic current, minimum, and
operator-margin storage profiles that can be checked before any checkpoint
payload download.

Outputs:

- `checkpoint_storage_profile_rows.csv`
- `checkpoint_storage_profile_requirement_rows.csv`
- `checkpoint_storage_profile_metric_rows.csv`
- `V61AJ_CHECKPOINT_STORAGE_PROFILE_ADMISSION_MATRIX_BOUNDARY.md`

Pass condition:

- v61ai storage remediation and v61w shard-priority evidence are bound
- `V61AJ_WAREHOUSE_ROOT` target override propagates through v61ai and copied
  v61w target paths
- six storage profile rows are emitted
- current reserve-policy profile admits zero shard rows
- current no-reserve diagnostic profile records live admitted shard rows/bytes
  but remains diagnostic-only
- `full-checkpoint-exact-with-reserve` admits all 59 shards
- computed `minimum_additional_bytes_for_full_reserve` is recorded
- `recommended_operator_free_bytes=549755813888`
- checkpoint payload bytes downloaded or committed by v61aj remain zero
- current-host download execution, actual materialization, full page-hash
  coverage, actual generation, production-latency, and release claims remain
  blocked

### v61ak Checkpoint Warehouse Target Preflight

Probe live candidate checkpoint warehouse targets before any checkpoint payload
download, separating v61aj policy requirements from current filesystem
availability and repository-safety rules.

Outputs:

- `checkpoint_warehouse_target_rows.csv`
- `checkpoint_warehouse_target_requirement_rows.csv`
- `checkpoint_warehouse_target_metric_rows.csv`
- `V61AK_CHECKPOINT_WAREHOUSE_TARGET_PREFLIGHT_BOUNDARY.md`

Pass condition:

- v61aj storage profile matrix and v61p warehouse evidence are bound
- current, operator-supplied, and repository-control target rows are emitted
- the current target records live free bytes and full-reserve deficit bytes
- repository-local checkpoint payload targets are rejected
- `required_with_reserve_bytes=315601231712`
- `recommended_operator_free_bytes=549755813888`
- checkpoint payload bytes downloaded or committed by v61ak remain zero
- download execution, actual materialization, full page-hash coverage, actual
  generation, production-latency, and release claims remain blocked unless an
  outside-repository target with enough live free space is supplied and explicit
  execution is requested

### v61al Checkpoint Warehouse Activation Gate

Bind the selected backend, warehouse target preflight, and shard priority rows
into a metadata-only activation command package. This is the final operator gate
before any real checkpoint payload download.

Outputs:

- `checkpoint_warehouse_activation_command_rows.csv`
- `checkpoint_warehouse_activation_gate_rows.csv`
- `checkpoint_warehouse_activation_metric_rows.csv`
- `V61AL_CHECKPOINT_WAREHOUSE_ACTIVATION_GATE_BOUNDARY.md`

Pass condition:

- v61ak target preflight, v61ah backend fallback, and v61w shard priority rows
  are bound
- 59 activation command rows are emitted
- `selected_backend_id=curl-resume`
- `backend_ready=1`
- activation rows default to dry-run and require explicit execution
- current host records `activation_admitted_rows=0` and
  `activation_blocked_rows=59` because `selected_target_id=none`
- checkpoint payload bytes downloaded or committed by v61al remain zero
- download execution, actual materialization, full page-hash coverage, actual
  generation, production-latency, and release claims remain blocked

### v61am Checkpoint Post-Activation Verification Gate

Bind the activation gate, local checkpoint materialization identity verifier,
and full page-hash sweep plan into a post-activation verification gate. This is
the first gate after an activation package exists, and it prevents generation or
release claims until local identity and full page hashes are complete.

Outputs:

- `checkpoint_post_activation_verification_rows.csv`
- `checkpoint_post_activation_requirement_rows.csv`
- `checkpoint_post_activation_metric_rows.csv`
- `V61AM_CHECKPOINT_POST_ACTIVATION_VERIFICATION_GATE_BOUNDARY.md`

Pass condition:

- v61al activation rows, v61t local materialization rows, and v61r full
  page-hash sweep rows are bound
- 59 post-activation verification rows are emitted
- current host records `activation_admitted_rows=0`,
  `local_identity_verified_shard_rows=0`, `verified_page_hash_rows=0`, and
  `required_page_hash_rows=134161`
- `post_activation_verification_gate_ready=0`
- `generation_gate_ready_after_post_activation=0`
- checkpoint payload bytes downloaded or committed by v61am remain zero
- actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61an Checkpoint Full Page Hash Execution Gate

Turn the v61r full page-hash plan into resumable execution chunks and bind those
chunks to v61am activation state plus v61t local identity state. This is the
execution handoff before full safetensors page-hash coverage can be claimed.

Outputs:

- `checkpoint_full_page_hash_execution_chunk_rows.csv`
- `local_full_page_hash_verification_rows.csv`
- `checkpoint_full_page_hash_execution_requirement_rows.csv`
- `checkpoint_full_page_hash_execution_metric_rows.csv`
- `V61AN_CHECKPOINT_FULL_PAGE_HASH_EXECUTION_GATE_BOUNDARY.md`

Pass condition:

- v61am post-activation rows, v61t local materialization rows, and v61r full
  page-hash plan rows are bound
- 134161 planned page hashes are scheduled into 291 execution chunks
- current host records `hashed_chunk_rows=0`,
  `blocked_activation_chunk_rows=291`, and
  `local_full_page_hash_verified_rows=0`
- `full_page_hash_execution_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- checkpoint payload bytes downloaded or committed by v61an remain zero
- full page-hash coverage, actual generation, production-latency,
  near-frontier, and release claims remain blocked

### v61ao Real Model Page Manifest Coverage Audit

Audit the v61q real checkpoint page map as a complete metadata coverage object
and bind it to v61v remote-hashed tensor samples plus v61an full page-hash
execution gating. This is the real-model page-manifest coverage checkpoint
before any full local payload materialization or real generation claim.

Outputs:

- `checkpoint_tensor_role_coverage_rows.csv`
- `moe_layer_expert_tensor_coverage_rows.csv`
- `checkpoint_manifest_shard_audit_rows.csv`
- `real_model_page_manifest_coverage_requirement_rows.csv`
- `real_model_page_manifest_coverage_metric_rows.csv`
- `V61AO_REAL_MODEL_PAGE_MANIFEST_COVERAGE_AUDIT_BOUNDARY.md`

Pass condition:

- v61q checkpoint page-map rows, v61v remote tensor bindings, and v61an full
  page-hash execution gate rows are bound
- 59 shards, 1739 tensors, 134161 checkpoint pages, and 135841 tensor/page
  segments are audited as metadata-only manifest coverage
- all 1344 layer/expert/MoE tensor coverage cells are ready across 56 layers,
  8 experts, and w1/w2/w3 expert tensor roles
- 16 remote-hash-bound sample tensor rows remain bound, including 15 MoE rows
- `real_model_page_manifest_coverage_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- checkpoint payload bytes downloaded or committed by v61ao remain zero
- local materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61ap MoE Coverage Remote Hash Plan

Turn the v61ao complete metadata coverage audit into a deterministic remote hash
expansion plan for one representative checkpoint page per Mixtral MoE
layer/expert/tensor cell. This preserves already remote-hashed v61v sample
cells while planning the remaining cells without fetching new payload bytes.

Outputs:

- `moe_coverage_remote_hash_plan_rows.csv`
- `moe_coverage_existing_remote_hash_rows.csv`
- `moe_coverage_remote_hash_role_rows.csv`
- `moe_coverage_remote_hash_shard_rows.csv`
- `moe_coverage_remote_hash_requirement_rows.csv`
- `moe_coverage_remote_hash_metric_rows.csv`
- `V61AP_MOE_COVERAGE_REMOTE_HASH_PLAN_BOUNDARY.md`

Pass condition:

- v61ao real-model page manifest coverage is bound
- all 1344 layer/expert/MoE tensor cells have a deterministic representative
  2 MiB remote hash plan row
- 15 existing v61v MoE remote-hash-bound sample rows are preserved
- 1329 remaining representative range hashes are planned but not executed
- `full_moe_coverage_remote_hash_ready=0`
- `remote_hash_expansion_execution_ready=0`
- checkpoint payload bytes downloaded or committed by v61ap remain zero
- executed remote hash expansion, full safetensors page-hash coverage, local
  materialization, actual generation, production-latency, near-frontier, and
  release claims remain blocked

### v61aq MoE Remote Hash Execution Gate

Convert the v61ap MoE representative remote hash plan into guarded curl-range
command rows and resumable execution chunks. This is an execution gate, not a
network execution step: it preserves existing v61v hashes and keeps new remote
range hashing disabled by default.

Outputs:

- `moe_remote_hash_execution_command_rows.csv`
- `moe_remote_hash_existing_hash_rows.csv`
- `moe_remote_hash_execution_chunk_rows.csv`
- `moe_remote_hash_execution_role_rows.csv`
- `moe_remote_hash_execution_requirement_rows.csv`
- `moe_remote_hash_execution_metric_rows.csv`
- `V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md`

Pass condition:

- v61ap 1344-row MoE remote hash plan is bound
- 1329 guarded curl-range command rows are emitted for not-yet-hashed cells
- 15 existing v61v MoE remote hashes are preserved
- 1344 representative rows are scheduled into 21 execution chunks
- `remote_hash_execution_ready=0`
- `full_moe_coverage_remote_hash_ready=0`
- checkpoint payload bytes downloaded or committed by v61aq remain zero
- executed remote hash expansion, full MoE remote-hash coverage, full
  safetensors page-hash coverage, local materialization, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61ar MoE Remote Hash Result Intake

Close the handoff after v61aq by defining the hash-only result artifact that an
operator can return after executing reviewed remote range hash commands. The
default no-supplied-result path is explicit final deferral, not silent
readiness.

Outputs:

- `moe_remote_hash_result_required_field_rows.csv`
- `moe_remote_hash_result_template_rows.csv`
- `moe_remote_hash_result_validation_rows.csv`
- `moe_remote_hash_result_invalid_rows.csv`
- `moe_remote_hash_combined_coverage_rows.csv`
- `moe_remote_hash_result_metric_rows.csv`
- `V61AR_MOE_REMOTE_HASH_RESULT_INTAKE_BOUNDARY.md`

Pass condition:

- v61aq command/chunk plan is bound
- 1329 expected hash-only result rows are declared
- 15 existing v61v MoE remote hashes are preserved as verified rows
- default no-supplied path records 1329 missing rows as
  `deferred-with-reason-final`
- `remote_hash_result_intake_ready=0`
- `full_moe_coverage_remote_hash_ready=0`
- checkpoint payload bytes downloaded or committed by v61ar remain zero
- full MoE remote-hash coverage, full safetensors page-hash coverage, local
  materialization, actual generation, production-latency, near-frontier, and
  release claims remain blocked

### v61as Hotset Reuse Admission Gate

Bind the sampled source-bound token-budget rows to a persistent-hotset cache
reuse ledger. This makes the active sparse runtime assumption explicit: repeated
MoE page touches should be served from a hotset after cold fill, not reread from
SSD for every scheduled touch.

Outputs:

- `hotset_reuse_page_rows.csv`
- `hotset_reuse_token_rows.csv`
- `hotset_reuse_window_rows.csv`
- `hotset_reuse_requirement_rows.csv`
- `hotset_reuse_metric_rows.csv`
- `V61AS_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md`

Pass condition:

- v61ac sampled token-budget replay, v61ad KV+weight budget replay, and v61ar
  remote-hash result intake are bound
- 148 scheduled sampled MoE page touches collapse to 15 unique cold-fill pages
  plus 133 cache-hit rows
- uncached 310378496 SSD read bytes collapse to 31457280 cold-fill bytes over
  the 37-row source-bound window
- `sampled_hotset_reuse_ready=1`
- `full_runtime_hotset_reuse_admission_ready=0`
- checkpoint payload bytes downloaded or committed by v61as remain zero
- full MoE remote-hash coverage, full safetensors page-hash coverage, local
  materialization, actual generation, production-latency, near-frontier, and
  release claims remain blocked

### v61at Prefetch Overlap Admission Gate

Bind sampled hotset reuse rows to GPU page-kernel timing and direct-I/O latency
so steady-state prefetch overlap can be admitted only where the cold-fill read
fits inside the prior token's GPU page-kernel compute window. This separates
steady-state overlap evidence from bootstrap cold-start and full-runtime
admission.

Outputs:

- `prefetch_overlap_token_rows.csv`
- `prefetch_overlap_window_rows.csv`
- `prefetch_overlap_requirement_rows.csv`
- `prefetch_overlap_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AT_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md`

Pass condition:

- v61l GPU page-kernel timing, v61z sampled direct-I/O latency, and v61as
  hotset reuse evidence are bound
- all 36 non-bootstrap sampled token rows pass steady-state prefetch overlap
- p95 SSD page-read latency of 0.956690 ms fits inside the 2.053768 ms
  prior-token GPU page-kernel compute window
- bootstrap cold-start remains blocked because the first cold fill has no prior
  compute window to hide behind
- `steady_state_prefetch_overlap_ready=1`
- `prefetch_overlap_admission_ready=0`
- checkpoint payload bytes downloaded or committed by v61at remain zero
- full runtime admission, actual generation, production-latency, near-frontier,
  and release claims remain blocked

### v61au Prefetch Queue-Depth Scheduler Gate

Turn v61at steady-state overlap evidence into explicit queue-depth and deadline
scheduler rows. This is the scheduler-admission layer between "the read could
fit" and "an async prefetch runtime actually issued it."

Outputs:

- `prefetch_scheduler_token_rows.csv`
- `prefetch_scheduler_issue_rows.csv`
- `prefetch_queue_depth_rows.csv`
- `prefetch_deadline_requirement_rows.csv`
- `prefetch_scheduler_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AU_PREFETCH_QUEUE_DEPTH_SCHEDULER_GATE_BOUNDARY.md`

Pass condition:

- v61at sampled prefetch-overlap evidence is bound
- all 11 steady-state sampled prefetch issue rows meet the target-token
  deadline
- configured queue depth 4 covers max steady-state required queue depth 1
- bootstrap cold-fill rows remain blocked because queue depth cannot create a
  previous compute window
- `steady_state_scheduler_ready=1`
- `prefetch_scheduler_admission_ready=0`
- `actual_async_prefetch_execution_ready=0`
- checkpoint payload bytes downloaded or committed by v61au remain zero
- actual io_uring execution, registered-buffer prefetch, full runtime
  admission, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61av Async Prefetch Execution Probe

Execute the v61au sampled prefetch issue rows through a queue-depth controlled
threaded O_DIRECT worker pool. This moves from scheduler admission rows to
actual local sampled prefetch reads while still stopping short of io_uring,
registered buffers, bootstrap admission, and full runtime admission.

Outputs:

- `async_prefetch_execution_rows.csv`
- `async_prefetch_batch_rows.csv`
- `async_prefetch_requirement_rows.csv`
- `async_prefetch_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AV_ASYNC_PREFETCH_EXECUTION_PROBE_BOUNDARY.md`

Pass condition:

- v61au queue-depth scheduler rows and v61z local direct-I/O page rows are bound
- all 15 sampled prefetch issue reads execute through the queue-depth 4 worker
  pool
- all 15 async prefetch reads hash-match the remote checkpoint page hashes
- all 11 steady-state sampled prefetch issue rows execute successfully
- `actual_async_prefetch_execution_ready=1`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `prefetch_scheduler_admission_ready=0`
- checkpoint payload bytes downloaded or committed by v61av remain zero
- bootstrap prefetch admission, io_uring execution, registered-buffer prefetch,
  full runtime admission, actual generation, production-latency, near-frontier,
  and release claims remain blocked

### v61aw io_uring Registered-Buffer Preflight

Probe the current host for an io_uring prefetch backend and bind the v61av
threaded O_DIRECT worker pool as the explicit fallback. This moves the runtime
from "not tested" to a current-host io_uring/registered-buffer preflight while
keeping actual SQ/CQ submission and buffer registration blocked.

Outputs:

- `io_uring_capability_rows.csv`
- `io_uring_setup_probe_rows.csv`
- `registered_buffer_preflight_rows.csv`
- `io_uring_requirement_rows.csv`
- `io_uring_fallback_binding_rows.csv`
- `io_uring_preflight_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AW_IO_URING_REGISTERED_BUFFER_PREFLIGHT_BOUNDARY.md`

Pass condition:

- v61av threaded O_DIRECT async prefetch evidence is bound
- Linux io_uring UAPI header availability is recorded
- liburing development-header absence is recorded without treating it as raw
  syscall failure
- raw `io_uring_setup` is attempted with a valid params structure
- the current-host `EPERM` setup blocker is recorded
- setup/enter/register and registered-buffer prefetch readiness remain `0`
- threaded O_DIRECT fallback readiness remains `1`
- checkpoint payload bytes downloaded or committed by v61aw remain zero
- actual io_uring execution, registered-buffer prefetch, full runtime
  admission, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61ax Async-I/O Backend Selection Gate

Bind the current-host io_uring preflight to the sampled threaded O_DIRECT
execution evidence and select the active async-I/O backend for the sampled
prefetch runtime path. This makes the fallback policy explicit without turning
it into a production-latency or full-runtime claim.

Outputs:

- `async_io_backend_candidate_rows.csv`
- `async_io_backend_selection_rows.csv`
- `async_io_backend_policy_rows.csv`
- `async_io_backend_requirement_rows.csv`
- `async_io_backend_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AX_ASYNC_IO_BACKEND_SELECTION_GATE_BOUNDARY.md`

Pass condition:

- v61aw io_uring/registered-buffer preflight evidence is bound
- v61av threaded O_DIRECT execution evidence is bound
- `io_uring_registered_buffer` is listed as preferred but blocked on the
  current host
- `threaded_odirect` is selected as the current-host backend
- the selected backend is backed by 15/15 sampled hash matches and zero read
  errors
- bootstrap prefetch admission and full runtime async-I/O admission remain `0`
- checkpoint payload bytes downloaded or committed by v61ax remain zero
- actual io_uring execution, registered-buffer prefetch, full runtime
  admission, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61ay Selected-Backend Token Runtime Binding

Bind the v61ax selected current-host async-I/O backend to every v61ad
KV+weight token budget row. This closes the sampled token/runtime binding layer
while still leaving materialization, bootstrap admission, full page-hash
coverage, generation, and production claims blocked.

Outputs:

- `selected_backend_token_runtime_binding_rows.csv`
- `selected_backend_context_runtime_binding_rows.csv`
- `selected_backend_runtime_requirement_rows.csv`
- `selected_backend_runtime_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AY_SELECTED_BACKEND_TOKEN_RUNTIME_BINDING_BOUNDARY.md`

Pass condition:

- v61ad KV+weight token budget rows are bound
- v61ax selected backend evidence is bound
- all 185 combined KV+weight token budget rows bind to `threaded_odirect`
- all five KV context profiles bind to the selected backend
- host RAM spill remains zero
- bootstrap and full runtime async-I/O admission remain `0`
- checkpoint payload bytes downloaded or committed by v61ay remain zero
- actual io_uring execution, registered-buffer prefetch, full checkpoint
  materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61az Ubuntu-1 Warehouse Target Admission

Bind the user-approved ubuntu-1 NVMe partition as a live outside-repository
checkpoint warehouse capacity target without creating the target directory or
downloading checkpoint payload bytes.

Outputs:

- `ubuntu1_warehouse_capacity_rows.csv`
- `ubuntu1_warehouse_admission_rows.csv`
- `ubuntu1_warehouse_operator_command_rows.csv`
- `ubuntu1_warehouse_requirement_rows.csv`
- `ubuntu1_warehouse_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61AZ_UBUNTU1_WAREHOUSE_TARGET_ADMISSION_BOUNDARY.md`

Pass condition:

- v61aj storage profile evidence, v61ak target preflight evidence, and v61ay
  selected-backend runtime binding evidence are bound
- `/dev/nvme0n1p8` label `ubuntu-1` is observed as an ext4 mount at
  `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25`
- the selected target path is outside the repository
- live free bytes cover `required_with_reserve_bytes=315601231712`
- the 512 GiB operator-margin recommendation remains explicit and may stay a
  recommended gap
- the current managed session records target write/activation readiness as
  blocked instead of silently creating the warehouse directory
- checkpoint payload bytes downloaded or committed by v61az remain zero
- download execution, local checkpoint materialization, full page-hash coverage,
  actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61ba Ubuntu-1 Activation Handoff Package

Rewrite the checkpoint activation handoff commands to the ubuntu-1 warehouse
target, including post-download verification, full page hashing, and generation
admission recheck commands, without executing checkpoint payload downloads.

Outputs:

- `ubuntu1_activation_handoff_command_rows.csv`
- `ubuntu1_activation_handoff_requirement_rows.csv`
- `ubuntu1_activation_handoff_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BA_UBUNTU1_ACTIVATION_HANDOFF_BOUNDARY.md`

Pass condition:

- v61az ubuntu-1 capacity evidence is bound
- v61ah curl-resume backend plan evidence is bound
- all 59 checkpoint shard handoff rows point to the ubuntu-1 target path
- all 59 post-download materialization verifier commands point to the ubuntu-1
  target path
- all 59 post-download full page-hash commands point to the ubuntu-1 target
  path
- all 59 generation-admission recheck commands point to the ubuntu-1 target path
- no handoff command row retains the stale `/tmp/v61aj-warehouse-override`
  target
- handoff commands remain dry-run and require explicit operator/escalated write
  action
- checkpoint payload bytes downloaded or committed by v61ba remain zero
- download execution, local checkpoint materialization, full page-hash coverage,
  actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61bb Ubuntu-1 Write Sentinel Activation Probe

Write and verify a tiny JSON sentinel under the ubuntu-1 warehouse target to
prove the operator/escalated write path without executing checkpoint payload
downloads.

Outputs:

- `ubuntu1_write_sentinel_witness_rows.csv`
- `ubuntu1_write_sentinel_requirement_rows.csv`
- `ubuntu1_write_sentinel_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BB_UBUNTU1_WRITE_SENTINEL_ACTIVATION_PROBE_BOUNDARY.md`

Pass condition:

- v61ba target-bound handoff evidence is bound
- the sentinel file lives under the ubuntu-1 target directory
- the sentinel JSON is parseable and target-bound
- the sentinel records zero checkpoint payload bytes downloaded or committed
- `ubuntu1_write_witness_ready=1`
- `operator_write_step_resolved_by_witness=1`
- `activation_target_write_witness_ready=1`
- checkpoint payload execution remains blocked with
  `activation_payload_execution_ready=0`
- local checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bc Ubuntu-1 Sampled Hotset Materialization

Materialize only the 16 bounded sampled hotset pages under the ubuntu-1
warehouse target by copying from the already verified v61y local hotset pages.
This proves sampled payload residency on the selected NVMe target without
executing full checkpoint downloads.

Outputs:

- `ubuntu1_sampled_hotset_materialization_rows.csv`
- `ubuntu1_sampled_hotset_readback_rows.csv`
- `ubuntu1_sampled_hotset_requirement_rows.csv`
- `ubuntu1_sampled_hotset_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BC_UBUNTU1_SAMPLED_HOTSET_MATERIALIZATION_BOUNDARY.md`

Pass condition:

- v61bb ubuntu-1 write witness evidence is bound
- v61y sampled hotset materialization evidence is bound
- all 16 sampled pages live under the ubuntu-1 target directory
- all 16 sampled pages match their remote page hashes
- all 16 sampled pages read back with matching hashes
- exactly 33554432 sampled checkpoint payload bytes are persisted on ubuntu-1
- `checkpoint_payload_bytes_downloaded_by_v61bc=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bd Ubuntu-1 Sampled Hotset Direct-I/O Replay

Replay direct reads over the 16 sampled hotset pages that v61bc materialized
under the ubuntu-1 warehouse target. This measures the selected NVMe target
read path while keeping full checkpoint download and generation blocked.

Outputs:

- `ubuntu1_hotset_direct_io_read_rows.csv`
- `ubuntu1_hotset_direct_io_prefetch_order_rows.csv`
- `ubuntu1_hotset_direct_io_latency_rows.csv`
- `ubuntu1_hotset_direct_io_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BD_UBUNTU1_SAMPLED_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md`

Pass condition:

- v61bc ubuntu-1 sampled hotset materialization evidence is bound
- all 16 sampled pages are read through O_DIRECT from the ubuntu-1 target
- all 16 direct reads match the remote page hashes
- 15 MoE sampled pages are ordered before the embedding sampled page
- `direct_io_bytes_read_total=33554432`
- `ssd_read_bytes_per_token=8388608`
- `checkpoint_payload_bytes_downloaded_by_v61bd=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61be Ubuntu-1 Hotset Tensor-Slice Verifier

Interpret the 16 ubuntu-1 resident sampled hotset pages as BF16 tensor segments
using the real v61v safetensors tensor/page bindings and the v61bd direct-I/O
hash witnesses. This proves that the selected NVMe target is not only holding
opaque page bytes, but page bytes that can be decoded into real checkpoint
tensor slices.

Outputs:

- `ubuntu1_hotset_tensor_slice_stat_rows.csv`
- `ubuntu1_hotset_tensor_slice_sample_value_rows.csv`
- `ubuntu1_hotset_tensor_slice_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BE_UBUNTU1_HOTSET_TENSOR_SLICE_BOUNDARY.md`

Pass condition:

- v61bd ubuntu-1 direct-I/O evidence is bound
- v61v tensor/page binding evidence is bound
- all 16 tensor slices read from the ubuntu-1 hotset root
- all 16 ubuntu-1 pages match their remote page hashes
- all 16 tensor slices inherit direct-read hash matches
- 65536 sampled BF16 values are finite with zero NaN/Inf rows
- `checkpoint_payload_bytes_downloaded_by_v61be=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bf Ubuntu-1 Tensor-Tile Quant Probe

Run bounded BF16/q8/q4 dot-tile probes over the ubuntu-1 resident tensor slices
from v61be. This extends the selected NVMe target evidence from page residency
and BF16 slice interpretation into page-local quantization risk measurement.

Outputs:

- `ubuntu1_tensor_tile_probe_rows.csv`
- `ubuntu1_tensor_tile_sample_trace_rows.csv`
- `ubuntu1_tensor_tile_quant_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BF_UBUNTU1_TENSOR_TILE_QUANT_BOUNDARY.md`

Pass condition:

- v61be ubuntu-1 tensor-slice evidence is bound
- 128 bounded tile probes are emitted
- 120 MoE tile probes and 8 embedding tile probes are emitted
- 524288 BF16 tile values are consumed from ubuntu-1 resident pages
- all baseline/q8/q4 dot rows are finite
- all q8/q4 error rows are finite
- all tile rows inherit ubuntu-1 page hash and direct-read hash witnesses
- `checkpoint_payload_bytes_downloaded_by_v61bf=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bg Ubuntu-1 Token-Budget Replay

Bind the v61x source-bound workload rows to the v61bd ubuntu-1 direct-I/O
latency evidence and the v61bf resident tensor-tile quant evidence. This turns
the selected NVMe target from a page-local probe into a per-token hotset budget
object while preserving the no-generation/no-production-claim boundary.

Outputs:

- `ubuntu1_token_budget_rows.csv`
- `ubuntu1_token_budget_page_schedule_rows.csv`
- `ubuntu1_token_budget_tile_binding_rows.csv`
- `ubuntu1_token_budget_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BG_UBUNTU1_TOKEN_BUDGET_BOUNDARY.md`

Pass condition:

- v61x source-bound replay binding is ready
- v61bd ubuntu-1 direct-I/O latency evidence is bound
- v61bf ubuntu-1 tensor-tile quant evidence is bound
- 37 token-budget rows are emitted
- 148 active page schedule rows are emitted
- 1184 tile-binding rows are emitted
- 8388608 SSD read bytes/token are recorded
- 131072 BF16 tile values/token are recorded
- token direct-I/O p50/p95 budgets are computed from ubuntu-1 latency evidence
- q8/q4 per-token error budgets are computed from resident tile evidence
- `checkpoint_payload_bytes_downloaded_by_v61bg=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bh Ubuntu-1 KV + Weight Token-Budget Replay

Bind the v61bg ubuntu-1 token-budget rows to the v61m KV-cache
residency/eviction policy. This extends the selected NVMe target evidence from
weight-page token budgets to combined weight+new-KV per-token budgets while
preserving the no-host-RAM-KV-spill and no-generation boundaries.

Outputs:

- `kv_weight_context_profile_rows.csv`
- `kv_weight_token_budget_rows.csv`
- `kv_weight_token_budget_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BH_UBUNTU1_KV_WEIGHT_TOKEN_BUDGET_BOUNDARY.md`

Pass condition:

- v61bg ubuntu-1 token-budget replay is ready
- v61m KV-cache residency/eviction policy is ready
- 37 ubuntu-1 token-budget rows are bound
- five KV context profiles are bound
- 185 combined KV+weight budget rows are emitted
- 185/185 combined rows pass resident KV policy
- 74/185 rows pass full-KV-in-VRAM
- 111 rows require NVMe cold KV eviction
- host RAM KV spill remains zero bytes
- 8617984 weight+new-KV bytes/token are recorded
- `checkpoint_payload_bytes_downloaded_by_v61bh=0`
- checkpoint payload bytes committed to the repository remain zero
- full checkpoint materialization, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bi Ubuntu-1 Hotset Reuse Admission Gate

Bind the v61bg ubuntu-1 page schedule and v61bh KV+weight budget rows to a
persistent-hotset reuse ledger. This verifies that repeated source-bound page
touches collapse to unique cold fills plus cache hits on the selected ubuntu-1
target while preserving the no-full-runtime-admission boundary.

Outputs:

- `ubuntu1_hotset_reuse_page_rows.csv`
- `ubuntu1_hotset_reuse_token_rows.csv`
- `ubuntu1_hotset_reuse_window_rows.csv`
- `ubuntu1_hotset_reuse_requirement_rows.csv`
- `ubuntu1_hotset_reuse_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BI_UBUNTU1_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md`

Pass condition:

- v61bg ubuntu-1 token-budget replay is ready
- v61bh ubuntu-1 KV+weight budget replay is ready
- v61ar MoE remote-hash result-intake boundary is bound
- 37 ubuntu-1 source-bound token rows are bound
- 148 scheduled ubuntu-1 page reads are bound
- 15 unique cold-fill pages are recorded
- 133 cache-hit rows are recorded
- persistent hotset cold-fill bytes are 31457280
- persistent hotset saved bytes are 278921216
- `checkpoint_payload_bytes_downloaded_by_v61bi=0`
- checkpoint payload bytes committed to the repository remain zero
- full runtime admission, full page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bj Ubuntu-1 Prefetch Overlap Admission Gate

Bind v61l GPU page-kernel timing, v61bd ubuntu-1 direct-I/O latency, and v61bi
ubuntu-1 persistent-hotset reuse rows into a target-resident prefetch-overlap
ledger. This verifies that non-bootstrap sampled cold fills can be hidden under
the prior token compute window on the selected ubuntu-1 target while preserving
the bootstrap/full-runtime blocker.

Outputs:

- `ubuntu1_prefetch_overlap_token_rows.csv`
- `ubuntu1_prefetch_overlap_window_rows.csv`
- `ubuntu1_prefetch_overlap_requirement_rows.csv`
- `ubuntu1_prefetch_overlap_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BJ_UBUNTU1_PREFETCH_OVERLAP_ADMISSION_GATE_BOUNDARY.md`

Pass condition:

- v61l GPU page-kernel timing is bound
- v61bd ubuntu-1 direct-I/O p95 latency is bound
- v61bi ubuntu-1 persistent-hotset reuse evidence is bound
- 37 ubuntu-1 source-bound token rows are bound
- 36/36 non-bootstrap rows pass steady-state prefetch overlap
- 11 actual prefetch rows and 25 no-prefetch-required rows are recorded
- page p95 read latency 1.309456 ms fits inside the prior-token GPU page-kernel
  window 2.053768 ms
- minimum steady-state overlap slack is 0.744312 ms
- `checkpoint_payload_bytes_downloaded_by_v61bj=0`
- checkpoint payload bytes committed to the repository remain zero
- bootstrap cold-start, full checkpoint materialization, full page-hash
  coverage, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61bk Ubuntu-1 Prefetch Queue-Depth Scheduler Gate

Turn v61bj ubuntu-1 sampled prefetch-overlap rows into queue-depth/deadline
scheduler rows. This proves the target-resident steady-state cold-fill fanout
fits a queue-depth 4 scheduler while preserving the actual async-I/O and
bootstrap blockers.

Outputs:

- `ubuntu1_prefetch_scheduler_token_rows.csv`
- `ubuntu1_prefetch_scheduler_issue_rows.csv`
- `ubuntu1_prefetch_queue_depth_rows.csv`
- `ubuntu1_prefetch_deadline_requirement_rows.csv`
- `ubuntu1_prefetch_scheduler_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BK_UBUNTU1_PREFETCH_QUEUE_DEPTH_SCHEDULER_GATE_BOUNDARY.md`

Pass condition:

- v61bj ubuntu-1 prefetch-overlap evidence is bound
- 37 ubuntu-1 scheduler token rows are bound
- 15 cold-fill issue rows are bound
- 11/11 steady-state prefetch issue rows meet deadline
- 25 no-prefetch-required rows are recorded
- configured prefetch queue depth is 4
- max steady-state required queue depth is 1
- `ubuntu1_steady_state_scheduler_ready=1`
- `bootstrap_scheduler_ready=0`
- `ubuntu1_prefetch_scheduler_admission_ready=0`
- `actual_async_prefetch_execution_ready=0`
- `actual_io_uring_execution_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bk=0`
- checkpoint payload bytes committed to the repository remain zero
- bootstrap scheduling, actual async/io_uring execution, registered buffers,
  full checkpoint materialization, full page-hash coverage, full runtime
  admission, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61bl Ubuntu-1 Async Prefetch Execution Probe

Execute the v61bk ubuntu-1 sampled prefetch issue rows through a queue-depth
controlled threaded O_DIRECT worker pool. This closes the gap between
"ubuntu-1 scheduler rows fit" and "the target-resident prefetch reads were
actually issued and hash-verified", while preserving the bootstrap, io_uring,
full checkpoint, full page-hash, and generation blockers.

Outputs:

- `ubuntu1_async_prefetch_execution_rows.csv`
- `ubuntu1_async_prefetch_batch_rows.csv`
- `ubuntu1_async_prefetch_requirement_rows.csv`
- `ubuntu1_async_prefetch_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BL_UBUNTU1_ASYNC_PREFETCH_EXECUTION_PROBE_BOUNDARY.md`

Pass condition:

- v61bk ubuntu-1 queue-depth scheduler rows and v61bd ubuntu-1 local direct-I/O
  page rows are bound
- all 15 ubuntu-1 sampled prefetch issue reads execute through the queue-depth
  4 worker pool
- all 15 reads hash-match the remote checkpoint page hashes
- 11/11 steady-state issue rows hash-match
- four bootstrap reads hash-match, but bootstrap admission remains blocked
- `actual_async_prefetch_execution_ready=1`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bl=0`
- checkpoint payload bytes committed to the repository remain zero
- bootstrap admission, io_uring execution, registered buffers, full checkpoint
  materialization, full page-hash coverage, full runtime admission, actual
  generation, production-latency, near-frontier, and release claims remain
  blocked

### v61bm Ubuntu-1 Bootstrap Cold-Start Admission Gate

Consume v61bl actual threaded O_DIRECT evidence and separate token-0 bootstrap
from steady-state prefetch. Token 0 still cannot be prefetched against a prior
compute window, but its four cold-fill pages can be admitted as a blocking
cold-start batch before generation begins.

Outputs:

- `ubuntu1_bootstrap_cold_start_page_rows.csv`
- `ubuntu1_bootstrap_cold_start_batch_rows.csv`
- `ubuntu1_bootstrap_cold_start_requirement_rows.csv`
- `ubuntu1_bootstrap_cold_start_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BM_UBUNTU1_BOOTSTRAP_COLD_START_ADMISSION_GATE_BOUNDARY.md`

Pass condition:

- v61bl actual threaded O_DIRECT execution rows are bound
- four token-0 bootstrap cold-fill page rows are bound
- 4/4 bootstrap pages hash-match
- bootstrap cold-start batch elapsed time fits the configured startup budget
- `bootstrap_cold_start_admission_ready=1`
- `bootstrap_prefetch_admission_ready=0`
- `ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready=1`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bm=0`
- checkpoint payload bytes committed to the repository remain zero
- bootstrap prefetch overlap, io_uring execution, registered buffers, full
  runtime admission, full checkpoint materialization, full page-hash coverage,
  actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61bn Ubuntu-1 Activation Admission Refresh Gate

Consume v61az capacity evidence, v61ba target-bound handoff commands, and the
later v61bb ubuntu-1 write witness to refresh activation target admission.
This admits the ubuntu-1 target for the 59 checkpoint shard handoff rows without
executing payload downloads.

Outputs:

- `ubuntu1_activation_admission_rows.csv`
- `ubuntu1_activation_admission_requirement_rows.csv`
- `ubuntu1_activation_admission_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md`

Pass condition:

- v61az ubuntu-1 full-reserve capacity evidence is bound
- v61ba target-bound 59-shard handoff package is bound
- v61bb ubuntu-1 write witness is bound
- 59/59 target-bound shard handoff rows are admitted to the ubuntu-1 activation
  target
- `selected_activation_target_id=ubuntu-1-write-witness-admitted`
- `activation_target_admission_ready=1`
- `activation_target_admitted_rows=59`
- `payload_execution_ready_rows=0`
- `activation_payload_execution_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bn=0`
- checkpoint payload bytes committed to the repository remain zero
- explicit payload execution, full checkpoint materialization, full page-hash
  coverage, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61bo Ubuntu-1 Payload Execution Readiness Gate

Consume v61bn activation target admission and separate payload execution
preflight from payload execution itself. This records that all 59 checkpoint
shard download commands are target-bound to ubuntu-1 and resumable, with
post-download verification, full page-hash, and generation-admission recheck
commands present, while executing no checkpoint downloads.

Outputs:

- `ubuntu1_payload_execution_readiness_rows.csv`
- `ubuntu1_payload_execution_chunk_rows.csv`
- `ubuntu1_payload_execution_requirement_rows.csv`
- `ubuntu1_payload_execution_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md`

Pass condition:

- v61bn activation target admission evidence is bound
- 59/59 admitted shard rows have target-bound resumable curl commands
- 59/59 rows include post-download materialization verification commands
- 59/59 rows include post-download full page-hash commands
- 59/59 rows include generation-admission recheck commands
- three priority execution chunks are recorded
- `payload_execution_preflight_ready=1`
- `payload_execution_ready_rows=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bo=0`
- checkpoint payload bytes committed to the repository remain zero
- explicit payload execution, full checkpoint materialization, full page-hash
  coverage, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61bp Ubuntu-1 Payload Execution Launch Bundle

Consume v61bo payload-execution readiness rows and emit a dry-run-first
operator launch bundle for the ubuntu-1 checkpoint warehouse. The bundle keeps
payload execution blocked until both an execute flag and the exact approval
phrase are supplied, while preserving post-download materialization, full
page-hash, and generation-admission recheck scripts.

Outputs:

- `ubuntu1_payload_execution_launch_command_rows.csv`
- `ubuntu1_payload_execution_chunk_launch_rows.csv`
- `ubuntu1_payload_execution_approval_rows.csv`
- `ubuntu1_payload_execution_script_probe_rows.csv`
- `ubuntu1_payload_execution_dry_run_probe_rows.csv`
- `ubuntu1_payload_execution_operator_bundle_file_rows.csv`
- `ubuntu1_payload_execution_launch_requirement_rows.csv`
- `ubuntu1_payload_execution_launch_metric_rows.csv`
- `runtime_gap_rows.csv`
- `operator_bundle/`
- `V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md`

Pass condition:

- v61bo payload execution readiness evidence is bound
- 59 launch command rows are emitted
- three priority chunk launch rows are emitted
- seven operator bundle files are emitted
- four operator scripts pass bash syntax and executable-bit checks
- dry-run probe processes one planned row without payload execution
- `dry_run_guard_ready=1`
- `approval_required_rows=2`
- `approval_supplied_rows=0`
- `payload_execution_approval_ready=0`
- `payload_execution_launch_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bp=0`
- checkpoint payload bytes committed to the repository remain zero
- explicit payload execution approval, full checkpoint materialization, full
  page-hash coverage, actual generation, production-latency, near-frontier, and
  release claims remain blocked

### v61bq Ubuntu-1 Payload Execution Receipt Intake

Consume v61bp launch rows and define the receipt surface for an approved
ubuntu-1 checkpoint payload execution run. The gate also records non-invasive
live target-file presence/size rows for all 59 shard paths, while executing no
downloads and reading no checkpoint payload bytes.

Outputs:

- `ubuntu1_payload_execution_receipt_required_field_rows.csv`
- `ubuntu1_payload_execution_receipt_template_rows.csv`
- `ubuntu1_payload_execution_live_presence_rows.csv`
- `ubuntu1_payload_execution_receipt_validation_rows.csv`
- `ubuntu1_payload_execution_receipt_invalid_rows.csv`
- `ubuntu1_payload_execution_receipt_status_rows.csv`
- `ubuntu1_payload_execution_receipt_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BQ_UBUNTU1_PAYLOAD_EXECUTION_RECEIPT_INTAKE_BOUNDARY.md`

Pass condition:

- v61bp launch bundle evidence is bound
- receipt required-field rows and templates are emitted
- 59 live target-file presence rows are emitted
- 59 receipt status rows are emitted
- `payload_execution_receipt_input_supplied=0`
- `accepted_payload_execution_receipt_rows=0`
- `missing_payload_execution_receipt_rows=59`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `payload_execution_receipt_intake_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bq=0`
- checkpoint payload bytes committed to the repository remain zero
- actual payload execution, full checkpoint materialization, full page-hash
  coverage, actual generation, production-latency, near-frontier, and release
  claims remain blocked

### v61br Ubuntu-1 Post-Receipt Materialization Promotion Gate

Consume v61bq receipt rows and convert them into an explicit post-receipt
promotion checklist for ubuntu-1 materialization verification. The gate emits
targeted v61t/v61an/v61ae command rows but executes no downloads, full page
hashing, or Mixtral generation.

Outputs:

- `ubuntu1_post_receipt_materialization_requirement_rows.csv`
- `ubuntu1_post_receipt_verification_command_rows.csv`
- `ubuntu1_post_receipt_materialization_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BR_UBUNTU1_POST_RECEIPT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md`

Pass condition:

- v61bq receipt intake evidence is bound
- the ubuntu-1 target root is single-root, outside-repository, and not `/tmp`
- post-receipt verification command rows are emitted
- `expected_payload_execution_receipt_rows=59`
- `accepted_payload_execution_receipt_rows=0`
- `missing_payload_execution_receipt_rows=59`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `receipt_backed_materialization_input_ready=0`
- `identity_verification_execution_ready=0`
- `required_page_hash_rows=134161`
- `verified_page_hash_rows=0`
- `full_page_hash_execution_ready=0`
- `complete_source_review_return_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61br=0`
- checkpoint payload bytes committed to the repository remain zero
- completed checkpoint download, full checkpoint materialization, full
  safetensors page-hash coverage, actual generation, production-latency,
  near-frontier, and release claims remain blocked

### v61bs Ubuntu-1 Post-Receipt Verification Result Intake

Consume the results of the v61br post-receipt verification commands. The gate
validates returned v61t/v61an/v61ae summary artifacts and keeps the result
intake separate from checkpoint download, full page hashing, and Mixtral
generation execution.

Outputs:

- `post_receipt_verification_result_required_field_rows.csv`
- `post_receipt_verification_result_template_rows.csv`
- `post_receipt_verification_result_status_rows.csv`
- `post_receipt_verification_result_validation_rows.csv`
- `post_receipt_verification_promotion_requirement_rows.csv`
- `post_receipt_verification_result_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BS_UBUNTU1_POST_RECEIPT_VERIFICATION_RESULT_INTAKE_BOUNDARY.md`

Pass condition:

- v61br post-receipt promotion evidence is bound
- required result-field rows and templates are emitted
- `expected_verification_result_artifacts=3`
- `supplied_verification_result_artifacts=0`
- `accepted_verification_result_artifacts=0`
- `missing_verification_result_artifacts=3`
- `identity_verification_result_ready=0`
- `local_checkpoint_materialization_ready=0`
- `required_page_hash_rows=134161`
- `verified_page_hash_rows_from_result=0`
- `full_page_hash_result_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `complete_source_review_return_ready=0`
- `generation_admission_result_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bs=0`
- checkpoint payload bytes committed to the repository remain zero
- actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61bt Ubuntu-1 Actual Generation Result Intake

Consume v61bs plus the v53r complete-source review query packet and define the
returned actual-generation result surface. The gate validates source-bound
Mixtral answer, citation, abstain/fallback, latency, and acceptance summary
artifacts, but it does not execute generation or download checkpoint payloads.

Outputs:

- `actual_generation_result_required_field_rows.csv`
- `actual_generation_result_template_rows.csv`
- `actual_generation_result_status_rows.csv`
- `actual_generation_result_validation_rows.csv`
- `actual_generation_query_result_rows.csv`
- `actual_generation_result_requirement_rows.csv`
- `actual_generation_result_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BT_UBUNTU1_ACTUAL_GENERATION_RESULT_INTAKE_BOUNDARY.md`

Pass condition:

- v61bs post-receipt verification result intake evidence is bound
- v53r complete-source query packet evidence is bound
- required result-field rows and templates are emitted
- `expected_generation_result_artifacts=5`
- `supplied_generation_result_artifacts=0`
- `accepted_generation_result_artifacts=0`
- `missing_generation_result_artifacts=5`
- `expected_generation_rows=1000`
- `generation_query_result_rows=1000`
- `accepted_generation_rows=0`
- `post_receipt_verification_result_intake_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `complete_source_review_return_ready=0`
- `generation_admission_result_ready=0`
- `actual_model_generation_ready=0`
- `source_bound_qa_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bt=0`
- checkpoint payload bytes committed to the repository remain zero
- actual generation, production-latency, near-frontier, and release claims
  remain blocked

### v61bu Ubuntu-1 Partial Checkpoint Materialization Witness

Consume v61bq live target presence rows and v61t local checkpoint
materialization rows to record the current partial ubuntu-1 shard evidence. The
gate treats an external shard as witnessed only when the local size,
safetensors-header hash, and identity checks pass. It downloads no payload
bytes and commits no checkpoint payload bytes to the repository.

Outputs:

- `partial_checkpoint_materialization_witness_rows.csv`
- `partial_checkpoint_materialization_requirement_rows.csv`
- `partial_checkpoint_materialization_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BU_UBUNTU1_PARTIAL_CHECKPOINT_MATERIALIZATION_WITNESS_BOUNDARY.md`

Pass condition:

- v61bq live presence evidence is bound
- v61t local identity verification evidence is bound
- `checkpoint_shard_rows=59`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `local_existing_shard_rows=1`
- `local_size_match_shard_rows=1`
- `local_header_hash_match_shard_rows=1`
- `local_identity_verified_shard_rows=1`
- `local_identity_verified_bytes=4932529864`
- `remaining_identity_unverified_shard_rows=58`
- `remaining_identity_unverified_bytes=276308963480`
- `partial_checkpoint_materialization_witness_ready=1`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bu=0`
- `observed_external_checkpoint_payload_bytes=4932529864`
- checkpoint payload bytes committed to the repository remain zero
- receipt-backed full materialization, full page-hash coverage, actual
  generation, production-latency, near-frontier, and release claims remain
  blocked

### v61bv Ubuntu-1 Remaining Checkpoint Materialization Queue

Consume the v61bp dry-run-first launch bundle and the v61bu partial checkpoint
materialization witness, skip already identity-verified shards, and emit a
remaining-only ubuntu-1 materialization queue. This keeps the next payload
execution resumable and avoids re-downloading the shard that already passed
local size, safetensors-header, and identity checks.

Outputs:

- `remaining_checkpoint_materialization_queue_rows.csv`
- `verified_checkpoint_shard_skip_rows.csv`
- `remaining_checkpoint_materialization_chunk_rows.csv`
- `remaining_checkpoint_materialization_requirement_rows.csv`
- `remaining_checkpoint_materialization_metric_rows.csv`
- `remaining_checkpoint_materialization_script_probe_rows.csv`
- `remaining_checkpoint_materialization_dry_run_probe_rows.csv`
- `remaining_checkpoint_materialization_operator_file_rows.csv`
- `runtime_gap_rows.csv`
- `V61BV_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_QUEUE_BOUNDARY.md`

Pass condition:

- v61bp dry-run-first launch bundle evidence is bound
- v61bu partial materialization witness evidence is bound
- `checkpoint_shard_rows=59`
- `verified_identity_shard_rows=1`
- `skipped_verified_shard_rows=1`
- `remaining_queue_rows=58`
- `remaining_chunk_rows=3`
- `remaining_unverified_bytes=276308963480`
- `local_identity_verified_bytes=4932529864`
- `remaining_bytes_fit_current_free_space=1`
- `remaining_queue_ready=1`
- `dry_run_guard_ready=1`
- `payload_execution_launch_ready=0`
- `download_execution_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bv=0`
- checkpoint payload bytes committed to the repository remain zero
- explicit payload execution, receipt-backed full materialization, full
  page-hash coverage, actual generation, production-latency, near-frontier, and
  release claims remain blocked

### v61bw Ubuntu-1 Partial Page-Hash Witness

Consume the v61bu partial checkpoint materialization witness and the v61q real
checkpoint page map, then read each page of identity-verified ubuntu-1 shard
files to emit local page-hash witness rows. This turns the first resident
checkpoint shard from size/header identity evidence into concrete local
2 MiB-page hash coverage while keeping full safetensors coverage and generation
blocked.

Outputs:

- `partial_page_hash_witness_rows.csv`
- `partial_page_hash_shard_status_rows.csv`
- `partial_page_hash_requirement_rows.csv`
- `partial_page_hash_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BW_UBUNTU1_PARTIAL_PAGE_HASH_WITNESS_BOUNDARY.md`

Pass condition:

- v61bu partial materialization witness evidence is bound
- v61q real checkpoint page map evidence is bound
- `checkpoint_shard_rows=59`
- `total_checkpoint_unique_page_rows=134161`
- `local_identity_verified_shard_rows=1`
- `local_identity_verified_bytes=4932529864`
- `identity_shard_page_rows=2353`
- `identity_shard_page_bytes=4932529864`
- `page_hash_witness_rows=2353`
- `page_hash_witness_bytes=4932529864`
- `partial_full_shard_page_hash_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bw=0`
- `observed_external_checkpoint_payload_bytes=4932529864`
- checkpoint payload bytes committed to the repository remain zero
- full safetensors page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bx Ubuntu-1 Page-Hash Coverage Ledger

Consume the v61bw partial page-hash witness, v61bv remaining materialization
queue, and v61q real checkpoint page map, then emit a checkpoint-wide coverage
ledger. This promotes the first identity-verified shard from standalone witness
rows into full-model accounting: verified rows, remaining rows, queue binding,
and blocked full-coverage status per shard.

Outputs:

- `page_hash_coverage_ledger_rows.csv`
- `page_hash_coverage_requirement_rows.csv`
- `page_hash_coverage_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BX_UBUNTU1_PAGE_HASH_COVERAGE_LEDGER_BOUNDARY.md`

Pass condition:

- v61bw partial page-hash witness evidence is bound
- v61bv remaining materialization queue evidence is bound
- v61q real checkpoint page map evidence is bound
- `checkpoint_shard_rows=59`
- `total_checkpoint_unique_page_rows=134161`
- `verified_page_hash_shard_rows=1`
- `verified_page_hash_rows=2353`
- `verified_page_hash_bytes=4932529864`
- `remaining_page_hash_shard_rows=58`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_materialization_queue_rows=58`
- `partial_page_hash_coverage_ledger_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bx=0`
- checkpoint payload bytes committed to the repository remain zero
- completed full safetensors page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61by Ubuntu-1 Remaining Page-Hash Execution Plan

Consume the v61bx page-hash coverage ledger and v61bv remaining materialization
queue, then emit a remaining-only page-hash execution plan. This skips the
already page-hashed shard and schedules only the unverified checkpoint pages for
future post-materialization hashing.

Outputs:

- `remaining_page_hash_execution_chunk_rows.csv`
- `verified_page_hash_skip_rows.csv`
- `remaining_page_hash_execution_requirement_rows.csv`
- `remaining_page_hash_execution_metric_rows.csv`
- `runtime_gap_rows.csv`
- `V61BY_UBUNTU1_REMAINING_PAGE_HASH_EXECUTION_PLAN_BOUNDARY.md`

Pass condition:

- v61bx page-hash coverage ledger evidence is bound
- v61bv remaining materialization queue evidence is bound
- `checkpoint_shard_rows=59`
- `total_checkpoint_unique_page_rows=134161`
- `verified_page_hash_rows=2353`
- `verified_page_hash_bytes=4932529864`
- `skipped_verified_page_hash_rows=2353`
- `skipped_verified_page_hash_bytes=4932529864`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_page_hash_execution_chunk_size_pages=512`
- `remaining_page_hash_execution_chunk_rows=286`
- `remaining_page_hash_execution_plan_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61by=0`
- checkpoint payload bytes committed to the repository remain zero
- completed full safetensors page-hash coverage, actual generation,
  production-latency, near-frontier, and release claims remain blocked

### v61bz Ubuntu-1 Remaining Page-Hash Operator Bundle

Consume the v61by remaining page-hash execution plan and emit a dry-run-first
operator bundle that can hash the remaining checkpoint pages only after the
remaining shards are materialized and identity-verified. The bundle mirrors the
v61by chunks, preserves the verified-shard skip rows, and requires an execute
flag, approval phrase, and identity-verification confirmation before reading
checkpoint payload bytes.

Outputs:

- `operator_bundle/remaining_page_hash_execution_chunk_rows.csv`
- `operator_bundle/verified_page_hash_skip_rows.csv`
- `operator_bundle/remaining_page_hash_result_schema_rows.csv`
- `operator_bundle/hash_remaining_page_chunks.sh`
- `operator_bundle/verify_remaining_page_hash_results.sh`
- `operator_bundle/operator_env.template`
- `remaining_page_hash_operator_requirement_rows.csv`
- `remaining_page_hash_operator_metric_rows.csv`
- `remaining_page_hash_operator_dry_run_probe_rows.csv`
- `runtime_gap_rows.csv`
- `V61BZ_UBUNTU1_REMAINING_PAGE_HASH_OPERATOR_BUNDLE_BOUNDARY.md`

Pass condition:

- v61by remaining page-hash execution plan evidence is bound
- `verified_page_hash_rows=2353`
- `skipped_verified_page_hash_rows=2353`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_page_hash_execution_chunk_rows=286`
- `operator_bundle_file_rows=7`
- `script_probe_rows=2`
- `script_bash_syntax_pass_rows=2`
- `dry_run_guard_ready=1`
- `remaining_page_hash_operator_bundle_ready=1`
- `page_hash_execution_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bz=0`
- checkpoint payload bytes committed to the repository remain zero
- explicit page-hash execution, completed full safetensors page-hash coverage,
  actual generation, production-latency, near-frontier, and release claims
  remain blocked

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
18. Materialization admission and download-resume plan.
19. NVMe hotset runtime replay manifest over remote-hashed pages.
20. Local sampled-hotset page materialization and readback verification.
21. Sampled hotset direct-I/O read replay with latency metrics.
22. Sampled hotset BF16 tensor-slice interpretation and stats.
23. Sampled hotset BF16/q8/q4 numeric tile probes.
24. Sampled source-bound hotset token-budget replay.
25. Sampled KV + weight token-budget replay.
26. Real generation admission gate over complete-source candidates.
27. Guarded checkpoint warehouse operator bundle.
28. Checkpoint warehouse execution preflight.
29. Checkpoint download backend fallback plan.
30. Checkpoint storage budget remediation plan.
31. Checkpoint storage profile admission matrix.
32. Checkpoint warehouse target preflight.
33. Checkpoint warehouse activation gate.
34. Checkpoint post-activation verification gate.
35. Checkpoint full page-hash execution gate.
36. Real model page-manifest coverage audit.
37. MoE coverage remote-hash expansion plan.
38. MoE remote-hash execution gate.
39. MoE remote-hash result intake gate.
40. Sampled persistent-hotset reuse admission gate.
41. Sampled prefetch-overlap admission gate.
42. Sampled prefetch queue-depth/deadline scheduler gate.
43. Sampled async prefetch execution probe.
44. Current-host io_uring/registered-buffer preflight.
45. Current-host async-I/O backend selection gate.
46. Selected-backend token runtime binding gate.
47. Ubuntu-1 outside-repository warehouse capacity target admission.
48. Ubuntu-1 target-bound checkpoint activation handoff package.
49. Ubuntu-1 write sentinel activation witness.
50. Ubuntu-1 bounded sampled-hotset payload materialization.
51. Ubuntu-1 bounded sampled-hotset direct-I/O replay.
52. Ubuntu-1 resident BF16 tensor-slice interpretation and stats.
53. Ubuntu-1 resident BF16/q8/q4 tensor-tile quant probes.
54. Ubuntu-1 source-bound token-budget replay.
55. Ubuntu-1 KV + weight token-budget replay.
56. Ubuntu-1 persistent-hotset reuse admission.
57. Ubuntu-1 sampled prefetch-overlap admission.
58. Ubuntu-1 sampled prefetch queue-depth scheduler admission.
59. Ubuntu-1 sampled async prefetch execution probe.
60. Ubuntu-1 bootstrap cold-start admission.
61. Ubuntu-1 activation target admission refresh.
62. Ubuntu-1 payload execution readiness gate.
63. Ubuntu-1 payload execution launch bundle.
64. Ubuntu-1 payload execution receipt intake.
65. Ubuntu-1 post-receipt materialization promotion gate.
66. Ubuntu-1 post-receipt verification result intake.
67. Ubuntu-1 actual generation result intake.
68. Ubuntu-1 partial checkpoint materialization witness.
69. Ubuntu-1 remaining checkpoint materialization queue.
70. Complete-source 1000+ QA workload with real model generation.
71. Same runtime under long-context workloads with source-bound quality checks.
72. One-command local assistant demo.

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

The v61 real-model page manifest and coverage-audit steps are implemented and
covered by:

```bash
./experiments/test_v61k_real_model_page_manifest.sh
./experiments/test_v61ao_real_model_page_manifest_coverage_audit.sh
./experiments/test_v61ap_moe_coverage_remote_hash_plan.sh
./experiments/test_v61aq_moe_remote_hash_execution_gate.sh
./experiments/test_v61ar_moe_remote_hash_result_intake.sh
./experiments/test_v61as_hotset_reuse_admission_gate.sh
./experiments/test_v61at_prefetch_overlap_admission_gate.sh
./experiments/test_v61au_prefetch_queue_depth_scheduler_gate.sh
./experiments/test_v61av_async_prefetch_execution_probe.sh
./experiments/test_v61aw_io_uring_registered_buffer_preflight.sh
./experiments/test_v61ax_async_io_backend_selection_gate.sh
./experiments/test_v61ay_selected_backend_token_runtime_binding.sh
./experiments/test_v61az_ubuntu1_warehouse_target_admission.sh
./experiments/test_v61ba_ubuntu1_activation_handoff_package.sh
./experiments/test_v61bb_ubuntu1_write_sentinel_activation_probe.sh
./experiments/test_v61bc_ubuntu1_sampled_hotset_materialization.sh
./experiments/test_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh
./experiments/test_v61be_ubuntu1_hotset_tensor_slice_verifier.sh
./experiments/test_v61bf_ubuntu1_tensor_tile_quant_probe.sh
./experiments/test_v61bg_ubuntu1_token_budget_replay.sh
./experiments/test_v61bh_ubuntu1_kv_weight_token_budget_replay.sh
./experiments/test_v61bi_ubuntu1_hotset_reuse_admission_gate.sh
./experiments/test_v61bj_ubuntu1_prefetch_overlap_admission_gate.sh
./experiments/test_v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate.sh
./experiments/test_v61bl_ubuntu1_async_prefetch_execution_probe.sh
./experiments/test_v61bm_ubuntu1_bootstrap_cold_start_admission_gate.sh
./experiments/test_v61bn_ubuntu1_activation_admission_refresh_gate.sh
./experiments/test_v61bo_ubuntu1_payload_execution_readiness_gate.sh
./experiments/test_v61bp_ubuntu1_payload_execution_launch_bundle.sh
./experiments/test_v61bq_ubuntu1_payload_execution_receipt_intake.sh
./experiments/test_v61br_ubuntu1_post_receipt_materialization_promotion_gate.sh
./experiments/test_v61bs_ubuntu1_post_receipt_verification_result_intake.sh
./experiments/test_v61bt_ubuntu1_actual_generation_result_intake.sh
./experiments/test_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh
./experiments/test_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh
./experiments/test_v61bw_ubuntu1_partial_page_hash_witness.sh
./experiments/test_v61bx_ubuntu1_page_hash_coverage_ledger.sh
./experiments/test_v61by_ubuntu1_remaining_page_hash_execution_plan.sh
./experiments/test_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh
```

They emit:

- `results/v61k_real_model_page_manifest/manifest_001/`
- `results/v61ao_real_model_page_manifest_coverage_audit/audit_001/`
- `results/v61at_prefetch_overlap_admission_gate/gate_001/`
- `results/v61au_prefetch_queue_depth_scheduler_gate/gate_001/`
- `results/v61av_async_prefetch_execution_probe/probe_001/`
- `results/v61aw_io_uring_registered_buffer_preflight/preflight_001/`
- `results/v61ax_async_io_backend_selection_gate/gate_001/`
- `results/v61ay_selected_backend_token_runtime_binding/binding_001/`
- `results/v61az_ubuntu1_warehouse_target_admission/admission_001/`
- `results/v61ba_ubuntu1_activation_handoff_package/handoff_001/`
- `results/v61bb_ubuntu1_write_sentinel_activation_probe/write_probe_001/`
- `results/v61bc_ubuntu1_sampled_hotset_materialization/materialization_001/`
- `results/v61bd_ubuntu1_sampled_hotset_direct_io_replay/replay_001/`
- `results/v61be_ubuntu1_hotset_tensor_slice_verifier/verify_001/`
- `results/v61bf_ubuntu1_tensor_tile_quant_probe/probe_001/`
- `results/v61bg_ubuntu1_token_budget_replay/replay_001/`
- `results/v61bh_ubuntu1_kv_weight_token_budget_replay/replay_001/`
- `results/v61bi_ubuntu1_hotset_reuse_admission_gate/gate_001/`
- `results/v61bj_ubuntu1_prefetch_overlap_admission_gate/gate_001/`
- `results/v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate/gate_001/`
- `results/v61bl_ubuntu1_async_prefetch_execution_probe/probe_001/`
- `results/v61bm_ubuntu1_bootstrap_cold_start_admission_gate/gate_001/`
- `results/v61bn_ubuntu1_activation_admission_refresh_gate/gate_001/`
- `results/v61bo_ubuntu1_payload_execution_readiness_gate/gate_001/`
- `results/v61bp_ubuntu1_payload_execution_launch_bundle/bundle_001/`
- `results/v61bq_ubuntu1_payload_execution_receipt_intake/intake_001/`
- `results/v61br_ubuntu1_post_receipt_materialization_promotion_gate/gate_001/`
- `results/v61bs_ubuntu1_post_receipt_verification_result_intake/intake_001/`
- `results/v61bt_ubuntu1_actual_generation_result_intake/intake_001/`
- `results/v61bu_ubuntu1_partial_checkpoint_materialization_witness/witness_001/`
- `results/v61bv_ubuntu1_remaining_checkpoint_materialization_queue/queue_001/`
- `results/v61bw_ubuntu1_partial_page_hash_witness/hash_001/`
- `results/v61bx_ubuntu1_page_hash_coverage_ledger/ledger_001/`
- `results/v61by_ubuntu1_remaining_page_hash_execution_plan/plan_001/`
- `results/v61bz_ubuntu1_remaining_page_hash_operator_bundle/bundle_001/`

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
binding the page manifest to a public MoE model config and license, then
auditing complete metadata coverage over the real checkpoint page map.

The current v61ao coverage audit records:

- `checkpoint_shard_rows=59`
- `checkpoint_tensor_rows=1739`
- `checkpoint_unique_page_rows=134161`
- `checkpoint_page_segment_rows=135841`
- `moe_layer_expert_tensor_coverage_rows=1344`
- `moe_layer_expert_tensor_coverage_ready_rows=1344`
- `remote_hash_bound_tensor_rows=16`
- `real_model_page_manifest_coverage_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ao=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61ap MoE coverage remote hash plan records:

- `remote_hash_plan_rows=1344`
- `already_remote_hash_bound_rows=15`
- `planned_remote_hash_rows=1329`
- `planned_remote_hash_bytes=2818572288`
- `remaining_remote_hash_bytes=2787115008`
- `full_moe_coverage_remote_hash_ready=0`
- `remote_hash_expansion_execution_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ap=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61aq MoE remote hash execution gate records:

- `planned_remote_hash_command_rows=1329`
- `remote_hash_execution_chunk_rows=21`
- `blocked_execution_chunk_rows=21`
- `remote_hash_verified_rows=15`
- `planned_remote_hash_bytes=2787115008`
- `full_moe_coverage_remote_hash_ready=0`
- `remote_hash_execution_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61aq=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61ar MoE remote hash result intake gate records:

- `expected_remote_hash_result_rows=1329`
- `accepted_remote_hash_result_rows=0`
- `missing_remote_hash_result_rows=1329`
- `existing_remote_hash_rows=15`
- `required_moe_remote_hash_rows=1344`
- `verified_remote_hash_rows=15`
- `remote_hash_result_intake_ready=0`
- `full_moe_coverage_remote_hash_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ar=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61as hotset reuse admission gate records:

- `source_bound_token_budget_rows=37`
- `scheduled_hotset_page_read_rows=148`
- `unique_hotset_page_rows=15`
- `cache_miss_page_rows=15`
- `cache_hit_page_rows=133`
- `cache_hit_rate=0.898648649`
- `uncached_ssd_read_bytes_total=310378496`
- `persistent_hotset_cold_fill_bytes=31457280`
- `persistent_hotset_saved_bytes=278921216`
- `amortized_cold_fill_bytes_per_token=850196.756756757`
- `sampled_hotset_reuse_ready=1`
- `full_runtime_hotset_reuse_admission_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61as=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61at prefetch-overlap admission gate records:

- `steady_state_token_rows=36`
- `steady_state_prefetch_overlap_pass_rows=36`
- `steady_state_prefetch_overlap_blocked_rows=0`
- `no_prefetch_required_rows=25`
- `ssd_read_latency_ms_p95_per_page=0.956690`
- `gpu_kernel_avg_ms_per_page=0.513442`
- `token_page_kernel_compute_window_ms=2.053768`
- `bootstrap_cold_fill_latency_ms_p95=3.826760`
- `max_steady_state_cold_fill_latency_ms_p95=0.956690`
- `min_steady_state_overlap_slack_ms=1.097078`
- `steady_state_prefetch_overlap_ready=1`
- `bootstrap_cold_start_ready=0`
- `prefetch_overlap_admission_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61at=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61au prefetch queue-depth scheduler gate records:

- `total_cold_fill_page_rows=15`
- `bootstrap_cold_fill_page_rows=4`
- `steady_state_prefetch_issue_rows=11`
- `steady_state_deadline_met_rows=11`
- `steady_state_deadline_miss_rows=0`
- `no_prefetch_required_rows=25`
- `configured_prefetch_queue_depth=4`
- `max_steady_state_required_queue_depth=1`
- `max_bootstrap_required_queue_depth=4`
- `steady_state_queue_depth_headroom=3`
- `ssd_read_latency_ms_p95_per_page=0.956690`
- `prior_token_compute_window_ms=2.053768`
- `min_deadline_slack_ms=1.097078`
- `steady_state_scheduler_ready=1`
- `bootstrap_scheduler_ready=0`
- `prefetch_scheduler_admission_ready=0`
- `actual_async_prefetch_execution_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61au=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61av async prefetch execution probe records:

- `prefetch_issue_rows=15`
- `executed_prefetch_issue_rows=15`
- `async_prefetch_hash_match_rows=15`
- `async_prefetch_error_rows=0`
- `steady_state_prefetch_issue_rows=11`
- `steady_state_async_prefetch_hash_match_rows=11`
- `bootstrap_prefetch_issue_rows=4`
- `bootstrap_async_prefetch_hash_match_rows=4`
- `configured_prefetch_queue_depth=4`
- `async_prefetch_batch_rows=4`
- `max_submitted_batch_size=4`
- `async_prefetch_bytes_read_total=31457280`
- `actual_async_prefetch_execution_ready=1`
- `steady_state_actual_async_prefetch_ready=1`
- `bootstrap_prefetch_admission_ready=0`
- `prefetch_scheduler_admission_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61av=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61aw io_uring registered-buffer preflight records:

- `v61aw_io_uring_registered_buffer_preflight_ready=1`
- `v61av_async_prefetch_execution_probe_ready=1`
- `v61av_actual_async_prefetch_execution_ready=1`
- `kernel_release=6.5.0-26-generic`
- `linux_io_uring_header_ready=1`
- `liburing_header_ready=0`
- `io_uring_setup_syscall_number=425`
- `io_uring_enter_syscall_number=426`
- `io_uring_register_syscall_number=427`
- `io_uring_setup_errno=1`
- `io_uring_setup_errno_name=EPERM`
- `io_uring_setup_ready=0`
- `io_uring_enter_ready=0`
- `io_uring_register_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `registered_buffer_prefetch_ready=0`
- `threaded_odirect_fallback_ready=1`
- `checkpoint_payload_bytes_downloaded_by_v61aw=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61ax async-I/O backend selection gate records:

- `v61ax_async_io_backend_selection_gate_ready=1`
- `v61aw_io_uring_registered_buffer_preflight_ready=1`
- `v61av_async_prefetch_execution_probe_ready=1`
- `io_uring_registered_buffer_candidate_ready=0`
- `threaded_odirect_candidate_ready=1`
- `selected_async_io_backend=threaded_odirect`
- `selected_backend_ready=1`
- `selected_backend_queue_depth=4`
- `selected_backend_hash_match_rows=15`
- `selected_backend_error_rows=0`
- `steady_state_selected_backend_ready=1`
- `bootstrap_prefetch_admission_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffer_prefetch_ready=0`
- `full_runtime_async_io_admission_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ax=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61ay selected-backend token runtime binding records:

- `v61ay_selected_backend_token_runtime_binding_ready=1`
- `v61ad_kv_weight_token_budget_replay_ready=1`
- `v61ax_async_io_backend_selection_gate_ready=1`
- `selected_async_io_backend=threaded_odirect`
- `selected_backend_ready=1`
- `selected_backend_queue_depth=4`
- `selected_backend_hash_match_rows=15`
- `selected_backend_error_rows=0`
- `source_bound_query_rows=37`
- `source_bound_token_budget_rows=37`
- `kv_context_profile_rows=5`
- `combined_kv_weight_budget_rows=185`
- `selected_backend_bound_token_rows=185`
- `selected_backend_bound_context_rows=5`
- `full_kv_vram_budget_pass_rows=74`
- `nvme_eviction_required_rows=111`
- `host_ram_spill_bytes_total=0`
- `total_selected_backend_token_ssd_read_bytes=1551892480`
- `total_selected_backend_weight_plus_new_kv_bytes=1594327040`
- `max_context_tokens=8192`
- `max_token_direct_io_latency_ms_p95=3.826760`
- `bootstrap_prefetch_admission_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffer_prefetch_ready=0`
- `full_runtime_async_io_admission_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ay=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61az ubuntu-1 warehouse target admission records:

- `v61az_ubuntu1_warehouse_target_admission_ready=1`
- `ubuntu1_mount_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25`
- `ubuntu1_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_filesystem_source=/dev/nvme0n1p8`
- `ubuntu1_filesystem_fstype=ext4`
- `ubuntu1_filesystem_label=ubuntu-1`
- `ubuntu1_available_bytes_live=410615001088`
- `required_with_reserve_bytes=315601231712`
- `recommended_operator_free_bytes=549755813888`
- `ubuntu1_deficit_to_full_reserve_bytes=0`
- `ubuntu1_deficit_to_operator_margin_bytes=139140812800`
- `ubuntu1_full_reserve_capacity_pass=1`
- `ubuntu1_operator_margin_pass=0`
- `target_outside_repository=1`
- `target_parent_write_access_ready=0`
- `target_prepare_command_ready=1`
- `operator_write_step_required=1`
- `selected_capacity_target_id=ubuntu-1-full-reserve-capacity`
- `selected_activation_target_id=none`
- `activation_target_ready=0`
- `download_execution_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61az=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61ba ubuntu-1 activation handoff package records:

- `v61ba_ubuntu1_activation_handoff_package_ready=1`
- `selected_capacity_target_id=ubuntu-1-full-reserve-capacity`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `selected_backend_id=curl-resume`
- `activation_handoff_command_rows=59`
- `target_path_ubuntu1_rows=59`
- `download_command_ubuntu1_rows=59`
- `target_bound_verify_command_rows=59`
- `target_bound_full_page_hash_command_rows=59`
- `target_bound_generation_recheck_command_rows=59`
- `stale_tmp_target_command_rows=0`
- `p0_remote_moe_sampled_rows=15`
- `p0_embedding_sampled_rows=1`
- `p2_checkpoint_backfill_rows=43`
- `total_expected_checkpoint_bytes=281241493344`
- `activation_handoff_package_ready=1`
- `activation_execution_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61ba=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bb ubuntu-1 write sentinel activation probe records:

- `v61bb_ubuntu1_write_sentinel_activation_probe_ready=1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `sentinel_file=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_activation_sentinel/v61bb_write_probe.json`
- `sentinel_exists=1`
- `sentinel_json_valid=1`
- `sentinel_target_path_match=1`
- `sentinel_no_payload_claim=1`
- `ubuntu1_write_witness_ready=1`
- `operator_write_step_resolved_by_witness=1`
- `activation_target_write_witness_ready=1`
- `activation_handoff_command_rows=59`
- `activation_payload_execution_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bb=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bc ubuntu-1 sampled hotset materialization records:

- `v61bc_ubuntu1_sampled_hotset_materialization_ready=1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `ubuntu1_write_witness_ready=1`
- `hotset_page_rows=16`
- `source_local_hotset_hash_match_rows=16`
- `ubuntu1_hotset_page_present_rows=16`
- `ubuntu1_hotset_hash_match_rows=16`
- `ubuntu1_hotset_readback_hash_match_rows=16`
- `moe_hotset_page_rows=15`
- `embedding_hotset_page_rows=1`
- `sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1=33554432`
- `checkpoint_payload_bytes_downloaded_by_v61bc=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`

The current v61bd ubuntu-1 sampled hotset direct-I/O replay records:

- `v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `hotset_page_rows=16`
- `direct_io_read_rows=16`
- `direct_io_hash_match_rows=16`
- `direct_io_error_rows=0`
- `moe_direct_read_rows=15`
- `embedding_direct_read_rows=1`
- `direct_io_bytes_read_total=33554432`
- `direct_io_read_latency_ms_p50=1.102615`
- `direct_io_read_latency_ms_p95=1.234314`
- `direct_io_read_throughput_mib_s=1946.456509`
- `ssd_read_bytes_per_token=8388608`
- `source_bound_workload_binding_rows=37`
- `ubuntu1_direct_io_replay_ready=1`
- `checkpoint_payload_bytes_downloaded_by_v61bd=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`

The current v61be ubuntu-1 hotset tensor-slice verifier records:

- `v61be_ubuntu1_hotset_tensor_slice_verifier_ready=1`
- `v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1`
- `v61bc_ubuntu1_sampled_hotset_materialization_ready=1`
- `v61v_remote_page_tensor_binding_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `tensor_slice_rows=16`
- `moe_tensor_slice_rows=15`
- `embedding_tensor_slice_rows=1`
- `tensor_segment_bytes_bound=33550832`
- `sampled_bf16_value_rows=65536`
- `sampled_bf16_finite_rows=65536`
- `sampled_bf16_nan_rows=0`
- `sampled_bf16_inf_rows=0`
- `sampled_bf16_nonzero_rows=65536`
- `ubuntu1_page_under_hotset_root_rows=16`
- `ubuntu1_page_hash_match_rows=16`
- `direct_read_hash_match_rows=16`
- `slice_hash_match_rows=16`
- `ubuntu1_bf16_tensor_slice_stats_ready=1`
- `direct_io_bytes_read_total=33554432`
- `checkpoint_payload_bytes_downloaded_by_v61be=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `real_100b_open_weight_materialized=0`
- `actual_model_generation_ready=0`

The current v61bf ubuntu-1 tensor-tile quant probe records:

- `v61bf_ubuntu1_tensor_tile_quant_probe_ready=1`
- `v61be_ubuntu1_hotset_tensor_slice_verifier_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `tensor_slice_rows=16`
- `tensor_tile_probe_rows=128`
- `moe_tensor_tile_probe_rows=120`
- `embedding_tensor_tile_probe_rows=8`
- `tile_bf16_value_rows=524288`
- `tile_sample_trace_rows=384`
- `finite_baseline_dot_rows=128`
- `finite_q8_dot_rows=128`
- `finite_q4_dot_rows=128`
- `finite_q8_error_rows=128`
- `finite_q4_error_rows=128`
- `q8_abs_error_mean=0.00113809798`
- `q4_abs_error_mean=0.0244754219`
- `q8_abs_error_max=0.0044396754`
- `q4_abs_error_max=0.114740279`
- `ubuntu1_page_hash_match_rows=16`
- `direct_read_hash_match_rows=16`
- `ubuntu1_numeric_tile_probe_ready=1`
- `ubuntu1_q8_quant_probe_ready=1`
- `ubuntu1_q4_quant_probe_ready=1`
- `checkpoint_payload_bytes_downloaded_by_v61bf=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `real_100b_open_weight_materialized=0`
- `actual_model_generation_ready=0`

The current v61bg ubuntu-1 token-budget replay records:

- `v61bg_ubuntu1_token_budget_replay_ready=1`
- `v61x_hotset_runtime_replay_manifest_ready=1`
- `v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1`
- `v61bf_ubuntu1_tensor_tile_quant_probe_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `source_bound_workload_binding_rows=37`
- `token_budget_rows=37`
- `token_page_schedule_rows=148`
- `token_tile_binding_rows=1184`
- `finite_token_budget_rows=37`
- `finite_tile_binding_rows=1184`
- `active_page_reads_per_token=4`
- `active_tile_probe_rows_per_token=32`
- `tile_bf16_values_per_token=131072`
- `ssd_read_bytes_per_token=8388608`
- `ubuntu1_token_direct_io_latency_ms_p50=4.289692`
- `ubuntu1_token_direct_io_latency_ms_p95=5.237824`
- `q8_abs_error_budget_mean_per_token=0.0364191354`
- `q4_abs_error_budget_mean_per_token=0.783213501`
- `ubuntu1_token_budget_replay_ready=1`
- `checkpoint_payload_bytes_downloaded_by_v61bg=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `real_100b_open_weight_materialized=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`
- `route_jump_rows=0`

The current v61bh ubuntu-1 KV+weight token-budget replay records:

- `v61bh_ubuntu1_kv_weight_token_budget_replay_ready=1`
- `v61bg_ubuntu1_token_budget_replay_ready=1`
- `v61m_kv_cache_residency_eviction_policy_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `source_bound_token_budget_rows=37`
- `kv_context_profile_rows=5`
- `combined_kv_weight_budget_rows=185`
- `combined_kv_weight_budget_ready_rows=185`
- `vram_policy_pass_rows=185`
- `full_kv_vram_budget_pass_rows=74`
- `nvme_eviction_required_rows=111`
- `host_ram_spill_bytes_total=0`
- `hot_window_tokens=1024`
- `sink_tokens=128`
- `kv_bytes_per_token=229376`
- `ssd_read_bytes_per_token=8388608`
- `weight_plus_new_kv_bytes_per_token=8617984`
- `ubuntu1_token_direct_io_latency_ms_p50=4.289692`
- `ubuntu1_token_direct_io_latency_ms_p95=5.237824`
- `q8_abs_error_budget_mean_per_token=0.0364191354`
- `q4_abs_error_budget_mean_per_token=0.783213501`
- `max_context_tokens=8192`
- `max_kv_resident_vram_bytes=270532608`
- `max_kv_evicted_nvme_bytes=1639972864`
- `kv_weight_token_budget_replay_ready=1`
- `checkpoint_payload_bytes_downloaded_by_v61bh=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `real_100b_open_weight_materialized=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`
- `route_jump_rows=0`

The current v61bi ubuntu-1 hotset reuse admission gate records:

- `v61bi_ubuntu1_hotset_reuse_admission_gate_ready=1`
- `v61bg_ubuntu1_token_budget_replay_ready=1`
- `v61bh_ubuntu1_kv_weight_token_budget_replay_ready=1`
- `v61ar_moe_remote_hash_result_intake_ready=1`
- `model_id=mistralai/Mixtral-8x22B-v0.1`
- `selected_target_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `ubuntu1_hotset_root=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/.v61_sampled_hotset_pages`
- `source_bound_token_budget_rows=37`
- `scheduled_hotset_page_read_rows=148`
- `unique_hotset_page_rows=15`
- `cache_miss_page_rows=15`
- `cache_hit_page_rows=133`
- `cache_hit_rate=0.898648649`
- `reuse_factor=9.866666667`
- `page_bytes=2097152`
- `uncached_ssd_read_bytes_total=310378496`
- `persistent_hotset_cold_fill_bytes=31457280`
- `persistent_hotset_saved_bytes=278921216`
- `uncached_ssd_read_bytes_per_token=8388608`
- `amortized_cold_fill_bytes_per_token=850196.756756757`
- `amortized_saved_bytes_per_token=7538411.243243244`
- `ubuntu1_token_direct_io_latency_ms_p50=4.289692`
- `ubuntu1_token_direct_io_latency_ms_p95=5.237824`
- `weight_plus_new_kv_bytes_per_token=8617984`
- `host_ram_spill_bytes_total=0`
- `ubuntu1_sampled_hotset_reuse_ready=1`
- `remote_hash_result_intake_ready=0`
- `full_moe_coverage_remote_hash_ready=0`
- `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bi=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`
- `route_jump_rows=0`

The current v61bj ubuntu-1 prefetch-overlap admission gate records:

- `v61bj_ubuntu1_prefetch_overlap_admission_gate_ready=1`
- `v61l_gpu_page_dequant_matmul_measurement_ready=1`
- `v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1`
- `v61bi_ubuntu1_hotset_reuse_admission_gate_ready=1`
- `source_bound_token_rows=37`
- `scheduled_hotset_page_read_rows=148`
- `unique_hotset_page_rows=15`
- `bootstrap_cold_start_rows=1`
- `steady_state_token_rows=36`
- `ubuntu1_steady_state_prefetch_overlap_pass_rows=36`
- `ubuntu1_steady_state_prefetch_overlap_blocked_rows=0`
- `no_prefetch_required_rows=25`
- `ubuntu1_ssd_read_latency_ms_p95_per_page=1.309456`
- `gpu_kernel_avg_ms_per_page=0.513442`
- `token_page_kernel_compute_window_ms=2.053768`
- `bootstrap_cold_fill_latency_ms_p95=5.237824`
- `max_steady_state_cold_fill_latency_ms_p95=1.309456`
- `min_steady_state_overlap_slack_ms=0.744312`
- `uncached_p95_read_latency_ms_total=193.799488`
- `persistent_hotset_cold_fill_p95_latency_ms_total=19.641840`
- `persistent_hotset_saved_p95_latency_ms_total=174.157648`
- `ubuntu1_steady_state_prefetch_overlap_ready=1`
- `bootstrap_cold_start_ready=0`
- `ubuntu1_prefetch_overlap_admission_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bj=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

The current v61bk ubuntu-1 prefetch queue-depth scheduler gate records:

- `v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready=1`
- `v61bj_ubuntu1_prefetch_overlap_admission_gate_ready=1`
- `source_bound_token_rows=37`
- `total_cold_fill_page_rows=15`
- `bootstrap_cold_fill_page_rows=4`
- `ubuntu1_steady_state_prefetch_issue_rows=11`
- `ubuntu1_steady_state_deadline_met_rows=11`
- `ubuntu1_steady_state_deadline_miss_rows=0`
- `no_prefetch_required_rows=25`
- `configured_prefetch_queue_depth=4`
- `max_steady_state_required_queue_depth=1`
- `max_bootstrap_required_queue_depth=4`
- `steady_state_queue_depth_headroom=3`
- `bootstrap_queue_depth_headroom=0`
- `ubuntu1_ssd_read_latency_ms_p95_per_page=1.309456`
- `prior_token_compute_window_ms=2.053768`
- `min_deadline_slack_ms=0.744312`
- `ubuntu1_steady_state_scheduler_ready=1`
- `bootstrap_scheduler_ready=0`
- `ubuntu1_prefetch_scheduler_admission_ready=0`
- `queue_depth_control_ready=1`
- `actual_async_prefetch_execution_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bk=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

The current v61bl ubuntu-1 async prefetch execution probe records:

- `v61bl_ubuntu1_async_prefetch_execution_probe_ready=1`
- `v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready=1`
- `v61bi_ubuntu1_hotset_reuse_admission_gate_ready=1`
- `v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready=1`
- `configured_prefetch_queue_depth=4`
- `ubuntu1_prefetch_issue_rows=15`
- `ubuntu1_executed_prefetch_issue_rows=15`
- `ubuntu1_async_prefetch_hash_match_rows=15`
- `ubuntu1_async_prefetch_error_rows=0`
- `ubuntu1_steady_state_prefetch_issue_rows=11`
- `ubuntu1_steady_state_async_prefetch_hash_match_rows=11`
- `bootstrap_prefetch_issue_rows=4`
- `bootstrap_async_prefetch_hash_match_rows=4`
- `ubuntu1_async_prefetch_batch_rows=4`
- `max_submitted_batch_size=4`
- `ubuntu1_async_prefetch_bytes_read_total=31457280`
- `ubuntu1_async_prefetch_read_latency_ms_p50=1.995130`
- `ubuntu1_async_prefetch_read_latency_ms_p95=4.986956`
- `ubuntu1_async_prefetch_effective_throughput_mib_s=1257.582542`
- `actual_async_prefetch_execution_ready=1`
- `ubuntu1_steady_state_actual_async_prefetch_ready=1`
- `bootstrap_prefetch_admission_ready=0`
- `ubuntu1_prefetch_scheduler_admission_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bl=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

The current v61bm ubuntu-1 bootstrap cold-start admission gate records:

- `v61bm_ubuntu1_bootstrap_cold_start_admission_gate_ready=1`
- `v61bl_ubuntu1_async_prefetch_execution_probe_ready=1`
- `v61bk_ubuntu1_prefetch_queue_depth_scheduler_gate_ready=1`
- `ubuntu1_target_available_bytes=410581364736`
- `configured_prefetch_queue_depth=4`
- `configured_bootstrap_cold_start_budget_ms=100.000000`
- `bootstrap_prefetch_issue_rows=4`
- `bootstrap_cold_start_admitted_rows=4`
- `bootstrap_async_prefetch_hash_match_rows=4`
- `bootstrap_async_prefetch_error_rows=0`
- `bootstrap_cold_start_bytes_read_total=8388608`
- `bootstrap_cold_start_read_latency_ms_sum=12.445780`
- `bootstrap_cold_start_read_latency_ms_max=4.986956`
- `bootstrap_cold_start_batch_elapsed_ms=9.918070`
- `bootstrap_cold_start_budget_headroom_ms=90.081930`
- `ubuntu1_steady_state_prefetch_issue_rows=11`
- `ubuntu1_steady_state_async_prefetch_hash_match_rows=11`
- `actual_async_prefetch_execution_ready=1`
- `bootstrap_cold_start_admission_ready=1`
- `bootstrap_prefetch_admission_ready=0`
- `ubuntu1_bootstrap_plus_steady_state_sampled_admission_ready=1`
- `ubuntu1_prefetch_scheduler_admission_ready=0`
- `actual_io_uring_execution_ready=0`
- `registered_buffers_ready=0`
- `full_runtime_ubuntu1_hotset_reuse_admission_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bm=0`
- `checkpoint_payload_bytes_committed_to_repo=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`

The current v61bn ubuntu-1 activation admission refresh gate records:

- `v61bn_ubuntu1_activation_admission_refresh_gate_ready=1`
- `v61az_ubuntu1_warehouse_target_admission_ready=1`
- `v61ba_ubuntu1_activation_handoff_package_ready=1`
- `v61bb_ubuntu1_write_sentinel_activation_probe_ready=1`
- `selected_capacity_target_id=ubuntu-1-full-reserve-capacity`
- `selected_activation_target_id=ubuntu-1-write-witness-admitted`
- `selected_backend_id=curl-resume`
- `selected_backend_ready=1`
- `ubuntu1_available_bytes_live=410581364736`
- `required_with_reserve_bytes=315601231712`
- `ubuntu1_full_reserve_capacity_pass=1`
- `ubuntu1_operator_margin_pass=0`
- `operator_write_step_resolved_by_witness=1`
- `activation_target_write_witness_ready=1`
- `activation_handoff_command_rows=59`
- `target_bound_handoff_rows=59`
- `stale_tmp_target_command_rows=0`
- `activation_target_admission_ready=1`
- `activation_target_admitted_rows=59`
- `activation_target_blocked_rows=0`
- `payload_execution_ready_rows=0`
- `payload_execution_blocked_rows=59`
- `explicit_payload_execution_required=1`
- `activation_payload_execution_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `near_frontier_claim_ready=0`
- `production_latency_claim_ready=0`
- `real_release_package_ready=0`
- `total_expected_checkpoint_bytes=281241493344`
- `checkpoint_payload_bytes_downloaded_by_v61bn=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bo ubuntu-1 payload execution readiness gate records:

- `v61bo_ubuntu1_payload_execution_readiness_gate_ready=1`
- `v61bn_ubuntu1_activation_admission_refresh_gate_ready=1`
- `selected_payload_execution_target_id=ubuntu-1-payload-readiness-pending-approval`
- `selected_backend_id=curl-resume`
- `selected_backend_ready=1`
- `activation_target_admission_ready=1`
- `activation_target_admitted_rows=59`
- `payload_execution_preflight_ready=1`
- `payload_execution_readiness_rows=59`
- `payload_execution_chunk_rows=3`
- `target_bound_download_command_rows=59`
- `curl_resume_command_rows=59`
- `post_download_verify_command_rows=59`
- `post_download_full_page_hash_command_rows=59`
- `post_download_generation_admission_command_rows=59`
- `payload_execution_ready_rows=0`
- `payload_execution_blocked_rows=59`
- `explicit_payload_execution_required=1`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `total_expected_checkpoint_bytes=281241493344`
- `p0_remote_moe_sampled_rows=15`
- `p0_embedding_sampled_rows=1`
- `p2_checkpoint_backfill_rows=43`
- `checkpoint_payload_bytes_downloaded_by_v61bo=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bp ubuntu-1 payload execution launch bundle records:

- `v61bp_ubuntu1_payload_execution_launch_bundle_ready=1`
- `v61bo_ubuntu1_payload_execution_readiness_gate_ready=1`
- `selected_launch_bundle_id=ubuntu-1-payload-launch-bundle-dry-run-default`
- `selected_backend_id=curl-resume`
- `selected_backend_ready=1`
- `payload_execution_preflight_ready=1`
- `payload_execution_readiness_rows=59`
- `launch_command_rows=59`
- `priority_chunk_launch_rows=3`
- `operator_bundle_file_rows=7`
- `script_probe_rows=4`
- `script_bash_syntax_pass_rows=4`
- `script_executable_rows=4`
- `dry_run_probe_rows=1`
- `dry_run_guard_ready=1`
- `approval_required_rows=2`
- `approval_supplied_rows=0`
- `payload_execution_approval_ready=0`
- `payload_execution_launch_ready=0`
- `payload_execution_ready_rows=0`
- `payload_execution_blocked_rows=59`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `total_expected_checkpoint_bytes=281241493344`
- `checkpoint_payload_bytes_downloaded_by_v61bp=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bq ubuntu-1 payload execution receipt intake records:

- `v61bq_ubuntu1_payload_execution_receipt_intake_ready=1`
- `v61bp_ubuntu1_payload_execution_launch_bundle_ready=1`
- `payload_execution_receipt_input_supplied=0`
- `expected_payload_execution_receipt_rows=59`
- `supplied_payload_execution_receipt_rows=0`
- `accepted_payload_execution_receipt_rows=0`
- `invalid_payload_execution_receipt_rows=0`
- `missing_payload_execution_receipt_rows=59`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `result_schema_ready=0`
- `result_artifact_ready=0`
- `payload_execution_receipt_intake_ready=0`
- `download_execution_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `total_expected_checkpoint_bytes=281241493344`
- `checkpoint_payload_bytes_downloaded_by_v61bq=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61br ubuntu-1 post-receipt materialization promotion gate records:

- `v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `target_root_outside_repo=1`
- `tmp_target_rows=0`
- `expected_payload_execution_receipt_rows=59`
- `accepted_payload_execution_receipt_rows=0`
- `missing_payload_execution_receipt_rows=59`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `receipt_backed_materialization_input_ready=0`
- `identity_verification_execution_ready=0`
- `required_page_hash_rows=134161`
- `verified_page_hash_rows=0`
- `full_page_hash_execution_ready=0`
- `complete_source_review_return_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61br=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bs ubuntu-1 post-receipt verification result intake records:

- `v61bs_ubuntu1_post_receipt_verification_result_intake_ready=1`
- `expected_verification_result_artifacts=3`
- `supplied_verification_result_artifacts=0`
- `accepted_verification_result_artifacts=0`
- `missing_verification_result_artifacts=3`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `identity_verification_result_ready=0`
- `local_checkpoint_materialization_ready=0`
- `required_page_hash_rows=134161`
- `verified_page_hash_rows_from_result=0`
- `full_page_hash_result_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `complete_source_review_return_ready=0`
- `generation_admission_result_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bs=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bt ubuntu-1 actual generation result intake records:

- `v61bt_ubuntu1_actual_generation_result_intake_ready=1`
- `expected_generation_result_artifacts=5`
- `supplied_generation_result_artifacts=0`
- `accepted_generation_result_artifacts=0`
- `missing_generation_result_artifacts=5`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `expected_generation_rows=1000`
- `generation_query_result_rows=1000`
- `accepted_generation_rows=0`
- `accepted_answer_rows=0`
- `accepted_citation_rows=0`
- `accepted_latency_rows=0`
- `post_receipt_verification_result_intake_ready=0`
- `local_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `complete_source_review_return_ready=0`
- `generation_admission_result_ready=0`
- `actual_model_generation_ready=0`
- `source_bound_qa_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bt=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bu ubuntu-1 partial checkpoint materialization witness records:

- `v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready=1`
- `v61bq_ubuntu1_payload_execution_receipt_intake_ready=1`
- `v61t_local_checkpoint_materialization_verifier_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `total_checkpoint_bytes_expected=281241493344`
- `live_existing_shard_rows=1`
- `live_size_match_shard_rows=1`
- `accepted_payload_execution_receipt_rows=0`
- `missing_payload_execution_receipt_rows=59`
- `local_existing_shard_rows=1`
- `local_size_match_shard_rows=1`
- `local_header_hash_match_shard_rows=1`
- `local_identity_verified_shard_rows=1`
- `local_identity_verified_bytes=4932529864`
- `remaining_identity_unverified_shard_rows=58`
- `remaining_identity_unverified_bytes=276308963480`
- `partial_checkpoint_materialization_witness_ready=1`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bu=0`
- `observed_external_checkpoint_payload_bytes=4932529864`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bv ubuntu-1 remaining checkpoint materialization queue records:

- `v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1`
- `v61bp_ubuntu1_payload_execution_launch_bundle_ready=1`
- `v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `verified_identity_shard_rows=1`
- `skipped_verified_shard_rows=1`
- `remaining_queue_rows=58`
- `remaining_chunk_rows=3`
- `remaining_unverified_bytes=276308963480`
- `local_identity_verified_bytes=4932529864`
- `ubuntu1_available_bytes_live=405648830464`
- `remaining_bytes_fit_current_free_space=1`
- `remaining_queue_ready=1`
- `dry_run_guard_ready=1`
- `p0_remote_moe_sampled_remaining_rows=14`
- `p0_embedding_sampled_remaining_rows=1`
- `p2_checkpoint_backfill_remaining_rows=43`
- `payload_execution_launch_ready=0`
- `download_execution_ready=0`
- `full_checkpoint_materialization_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bv=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bw ubuntu-1 partial page-hash witness records:

- `v61bw_ubuntu1_partial_page_hash_witness_ready=1`
- `v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready=1`
- `v61q_real_checkpoint_page_map_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `total_checkpoint_bytes_expected=281241493344`
- `total_checkpoint_unique_page_rows=134161`
- `local_identity_verified_shard_rows=1`
- `local_identity_verified_bytes=4932529864`
- `identity_shard_page_rows=2353`
- `identity_shard_page_bytes=4932529864`
- `page_hash_witness_rows=2353`
- `page_hash_witness_bytes=4932529864`
- `partial_full_shard_page_hash_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bw=0`
- `observed_external_checkpoint_payload_bytes=4932529864`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bx ubuntu-1 page-hash coverage ledger records:

- `v61bx_ubuntu1_page_hash_coverage_ledger_ready=1`
- `v61bw_ubuntu1_partial_page_hash_witness_ready=1`
- `v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1`
- `v61q_real_checkpoint_page_map_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `total_checkpoint_unique_page_rows=134161`
- `total_checkpoint_bytes_expected=281241493344`
- `verified_page_hash_shard_rows=1`
- `verified_page_hash_rows=2353`
- `verified_page_hash_bytes=4932529864`
- `remaining_page_hash_shard_rows=58`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_materialization_queue_rows=58`
- `remaining_materialization_chunk_rows=3`
- `partial_page_hash_coverage_ledger_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bx=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61by ubuntu-1 remaining page-hash execution plan records:

- `v61by_ubuntu1_remaining_page_hash_execution_plan_ready=1`
- `v61bx_ubuntu1_page_hash_coverage_ledger_ready=1`
- `v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `checkpoint_shard_rows=59`
- `total_checkpoint_unique_page_rows=134161`
- `total_checkpoint_bytes_expected=281241493344`
- `verified_page_hash_rows=2353`
- `verified_page_hash_bytes=4932529864`
- `skipped_verified_page_hash_rows=2353`
- `skipped_verified_page_hash_bytes=4932529864`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_page_hash_execution_chunk_size_pages=512`
- `remaining_page_hash_execution_chunk_rows=286`
- `remaining_page_hash_execution_plan_ready=1`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61by=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

The current v61bz ubuntu-1 remaining page-hash operator bundle records:

- `v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready=1`
- `v61by_ubuntu1_remaining_page_hash_execution_plan_ready=1`
- `target_root_path=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse`
- `verified_page_hash_rows=2353`
- `skipped_verified_page_hash_rows=2353`
- `remaining_page_hash_rows=131808`
- `remaining_page_hash_bytes=276308963480`
- `remaining_page_hash_execution_chunk_rows=286`
- `operator_bundle_file_rows=7`
- `script_probe_rows=2`
- `script_bash_syntax_pass_rows=2`
- `dry_run_guard_ready=1`
- `remaining_page_hash_operator_bundle_ready=1`
- `page_hash_execution_ready=0`
- `full_safetensors_page_hash_binding_ready=0`
- `actual_model_generation_ready=0`
- `checkpoint_payload_bytes_downloaded_by_v61bz=0`
- `checkpoint_payload_bytes_committed_to_repo=0`

It also shows that reading uncached active expert weights per token is still
far over the current SSD budget, and that sampled steady-state overlap plus
queue-depth admission plus threaded O_DIRECT execution plus current-host
io_uring preflight plus backend selection plus token/runtime binding plus
ubuntu-1 capacity admission plus target-bound handoff packaging plus the
ubuntu-1 write sentinel witness plus ubuntu-1 sampled hotset materialization
plus ubuntu-1 sampled hotset direct-I/O replay plus ubuntu-1 resident BF16
tensor-slice verification plus ubuntu-1 resident tensor-tile quant probing plus
ubuntu-1 source-bound token-budget replay plus ubuntu-1 KV+weight
token-budget replay plus ubuntu-1 persistent-hotset reuse admission plus
ubuntu-1 sampled prefetch-overlap admission plus ubuntu-1 sampled
queue-depth scheduler admission plus ubuntu-1 sampled threaded O_DIRECT async
prefetch execution plus ubuntu-1 bootstrap cold-start admission plus ubuntu-1
activation target admission refresh plus ubuntu-1 payload execution readiness
plus ubuntu-1 payload execution launch bundling
plus ubuntu-1 payload execution receipt intake
plus ubuntu-1 post-receipt materialization promotion gating
plus ubuntu-1 post-receipt verification result intake
plus ubuntu-1 actual generation result intake
plus ubuntu-1 partial checkpoint materialization witnessing
plus ubuntu-1 remaining checkpoint materialization queueing
plus ubuntu-1 partial page-hash witnessing
plus ubuntu-1 page-hash coverage ledgering
plus ubuntu-1 remaining page-hash execution planning
plus ubuntu-1 remaining page-hash operator bundling
is
not full payload
download execution, checkpoint materialization, bootstrap prefetch overlap,
io_uring SQ/CQ execution, registered-buffer prefetch, or full-runtime
admission. The next runtime work must continue toward explicit payload
execution, full coverage, local checkpoint materialization, io_uring/registered-buffer
execution, and actual generation evidence rather than claiming practical
near-frontier inference.

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
10. Closed as v61w planner: turn v61p/v61t blockers and v61v sampled tensor bindings into a 59-shard materialization admission/download-resume plan, with `V61W_WAREHOUSE_ROOT` forcing fresh external-target materialization planning, while keeping SSD budget admission and materialization blocked on the current host.
11. Closed as v61x hotset manifest: bind v61w/v61v/v61s/v61m into 16 planned NVMe hotset page slots and 37 source-bound replay rows while keeping hotset payload materialization and real generation blocked.
12. Closed as v61y sampled hotset verifier: materialize the 16 sampled hotset pages outside the repository and verify local/readback hashes while keeping full checkpoint materialization and real generation blocked.
13. Closed as v61z sampled hotset direct-I/O replay: read the 16 local sampled hotset pages with O_DIRECT, verify hashes, and record latency/throughput while keeping full checkpoint materialization and real generation blocked.
14. Closed as v61aa sampled hotset tensor-slice verifier: interpret the 16 local pages as BF16 tensor segments, record finite sampled stats, and keep real generation blocked.
15. Closed as v61ab sampled hotset tensor-tile quant probe: run bounded BF16/q8/q4 dot-tile probes over the sampled tensor slices, record finite numeric rows, and keep real generation blocked.
16. Closed as v61ac sampled hotset token-budget replay: bind v61x source-bound rows to v61z direct-I/O latency and v61ab tile probes, record bounded per-token budgets, and keep real generation blocked.
17. Closed as v61ad KV + weight token-budget replay: bind v61ac token rows to v61m KV context profiles, record combined VRAM-hot/NVMe-cold budget rows, and keep full-KV-in-VRAM and real generation blocked.
18. Closed as v61ae real generation admission gate: bind v61ad/v53r/v61r/v61t/v61w into 1000 complete-source generation candidates, admit 0 rows, and keep source-review/materialization/full-page-hash blockers explicit, with `V61AE_WAREHOUSE_ROOT` refreshing target-bound source evidence.
19. Closed as v61af checkpoint warehouse operator bundle: emit guarded repo-outside download, verify, full-page-hash, and admission-recheck scripts with dry-run defaults, zero payload bytes downloaded by v61af, and `V61AF_WAREHOUSE_ROOT` propagated into source evidence and operator scripts.
20. Closed as v61ag checkpoint warehouse execution preflight: syntax-check v61af operator scripts, run a guarded one-row dry-run probe, preserve `V61AG_WAREHOUSE_ROOT` target-bound operator evidence, record current CLI/SSD blockers, and keep real download execution blocked.
21. Closed as v61ah checkpoint download backend fallback plan: select curl-resume over missing huggingface-cli, emit 59 guarded backend commands, preserve `V61AH_WAREHOUSE_ROOT` in backend target paths/scripts, and keep SSD-budget execution blocked.
22. Closed as v61ai checkpoint storage budget remediation plan: quantify the current SSD deficit from target-bound v61p/v61w evidence, preserve `V61AI_WAREHOUSE_ROOT`, record zero reserve-safe shard rows, and keep materialization/download execution blocked.
23. Closed as v61aj checkpoint storage profile admission matrix: map current/minimum/operator storage profiles from target-bound remediation evidence, preserve `V61AJ_WAREHOUSE_ROOT`, identify the exact full-reserve profile, and keep current-host execution blocked.
24. Closed as v61ak checkpoint warehouse target preflight: probe live warehouse targets, reject repository-local payload paths, and keep current-host target selection/download execution blocked.
25. Closed as v61al checkpoint warehouse activation gate: emit 59 dry-run activation rows over curl-resume, admit 0 rows without a selected full-reserve target, and keep payload execution blocked.
26. Closed as v61am checkpoint post-activation verification gate: bind activation, local identity, and full page-hash readiness into 59 blocked post-activation rows, with generation/release gates still closed.
27. Closed as v61an checkpoint full page-hash execution gate: chunk 134161 planned page hashes into 291 execution chunks, hash 0 chunks on the current host, and keep full page-hash coverage blocked.
28. Closed as v61ao real model page manifest coverage audit: bind v61q/v61v/v61an into 59-shard, 134161-page, 1344-cell MoE manifest coverage evidence while keeping full page-hash coverage and real generation blocked.
29. Closed as v61ap MoE coverage remote hash plan: preserve 15 already remote-hashed MoE cells and plan 1329 remaining representative layer/expert/tensor page hashes without fetching payload bytes.
30. Closed as v61aq MoE remote hash execution gate: emit 1329 guarded curl-range commands and 21 resumable chunks while preserving 15 existing hashes and keeping execution disabled.
31. Closed as v61ar MoE remote hash result intake gate: define hash-only result return rows, preserve 15 existing hashes, record 1329 missing rows as final-deferred, and keep full MoE coverage blocked.
32. Closed as v61as hotset reuse admission gate: collapse 148 sampled MoE page touches to 15 unique cold-fill pages plus 133 cache-hit rows while keeping full runtime admission blocked.
33. Closed as v61at prefetch overlap admission gate: bind GPU page-kernel timing/direct-I/O p95/hotset reuse rows and show 36/36 non-bootstrap sampled rows pass steady-state overlap while keeping bootstrap/full runtime admission blocked.
34. Closed as v61au prefetch queue-depth scheduler gate: turn v61at overlap rows into 11/11 steady-state deadline-met scheduler issue rows at queue depth 4 while keeping bootstrap, actual async I/O, and full runtime admission blocked.
35. Closed as v61av async prefetch execution probe: execute 15/15 sampled prefetch issue reads through a queue-depth 4 threaded O_DIRECT worker pool while keeping io_uring, registered buffers, bootstrap admission, and full runtime admission blocked.
36. Closed as v61aw io_uring registered-buffer preflight: attempt raw `io_uring_setup`, record the current-host `EPERM` blocker, keep setup/enter/register and registered-buffer prefetch readiness at 0, and bind the v61av threaded O_DIRECT fallback as ready.
37. Closed as v61ax async-I/O backend selection gate: choose `threaded_odirect` on the current host because io_uring registered-buffer prefetch remains blocked, while keeping bootstrap and full runtime admission blocked.
38. Closed as v61ay selected-backend token runtime binding: bind 185/185 KV+weight token budget rows and 5/5 context profiles to the selected `threaded_odirect` backend while keeping full runtime admission blocked.
39. Closed as v61az ubuntu-1 warehouse target admission: record ubuntu-1 as a full-reserve outside-repository capacity target while keeping write activation and payload execution blocked in the current managed session.
40. Closed as v61ba ubuntu-1 activation handoff package: rewrite all 59 shard download, materialization verify, full page-hash, and generation-admission recheck commands to the ubuntu-1 target while keeping payload execution blocked.
41. Closed as v61bb ubuntu-1 write sentinel activation probe: record an operator/escalated write witness under the ubuntu-1 target while keeping checkpoint payload execution blocked.
42. Closed as v61bc ubuntu-1 sampled hotset materialization: persist the 16 bounded sampled hotset pages under the ubuntu-1 target, verify hashes/readback, and keep full checkpoint payload execution blocked.
43. Closed as v61bd ubuntu-1 sampled hotset direct-I/O replay: read the ubuntu-1 sampled hotset pages with O_DIRECT, verify hashes, and record target-specific latency/throughput while keeping full checkpoint payload execution blocked.
44. Closed as v61be ubuntu-1 hotset tensor-slice verifier: interpret those ubuntu-1 resident pages as real BF16 tensor segments, verify finite sampled stats and page/direct-read hash binding, and keep full checkpoint payload execution blocked.
45. Closed as v61bf ubuntu-1 tensor-tile quant probe: run bounded BF16/q8/q4 dot-tile probes over the ubuntu-1 resident tensor slices and keep full checkpoint payload execution blocked.
46. Closed as v61bg ubuntu-1 token-budget replay: bind source-bound workload rows to ubuntu-1 direct-I/O latency and resident tensor-tile quant evidence while keeping full checkpoint payload execution blocked.
47. Closed as v61bh ubuntu-1 KV+weight token-budget replay: bind ubuntu-1 token budgets to KV context profiles while keeping host RAM spill, full checkpoint payload execution, and generation blocked.
48. Closed as v61bi ubuntu-1 hotset reuse admission gate: collapse ubuntu-1 scheduled page reads into persistent-hotset cold fills/cache hits while keeping full runtime admission and generation blocked.
49. Closed as v61bj ubuntu-1 prefetch overlap admission gate: bind ubuntu-1 page p95 latency to persistent-hotset reuse rows and show 36/36 non-bootstrap sampled rows pass steady-state overlap while keeping bootstrap/full checkpoint/full page-hash/generation blocked.
50. Closed as v61bk ubuntu-1 prefetch queue-depth scheduler gate: turn ubuntu-1 overlap rows into 11/11 steady-state deadline-met scheduler issue rows at queue depth 4 while keeping bootstrap, actual async I/O, full checkpoint, full page-hash, and generation blocked.
51. Closed as v61bl ubuntu-1 async prefetch execution probe: execute 15/15 ubuntu-1 sampled prefetch issue reads through a queue-depth 4 threaded O_DIRECT worker pool while keeping bootstrap admission, io_uring, registered buffers, full checkpoint, full page-hash, and generation blocked.
52. Closed as v61bm ubuntu-1 bootstrap cold-start admission gate: admit 4/4 token-0 cold-fill pages as a blocking pre-generation batch while keeping bootstrap prefetch overlap, io_uring, full runtime admission, full checkpoint, full page-hash, and generation blocked.
53. Closed as v61bn ubuntu-1 activation admission refresh gate: admit 59/59 target-bound shard handoff rows to the ubuntu-1 activation target using the write witness while keeping payload execution, full checkpoint materialization, full page-hash, and generation blocked.
54. Closed as v61bo ubuntu-1 payload execution readiness gate: record 59/59 target-bound resumable curl rows and three priority execution chunks while keeping actual payload execution, full checkpoint materialization, full page-hash, and generation blocked.
55. Closed as v61bp ubuntu-1 payload execution launch bundle: emit a dry-run-first operator bundle with 59 launch rows, three priority chunks, guarded approval requirements, and post-download recheck scripts while keeping actual payload execution, full checkpoint materialization, full page-hash, and generation blocked.
56. Closed as v61bq ubuntu-1 payload execution receipt intake: define receipt rows and live target-file presence rows for 59 launch commands while keeping actual payload execution, full checkpoint materialization, full page-hash, and generation blocked.
57. Closed as v61br ubuntu-1 post-receipt materialization promotion gate: bind the ubuntu-1 target root and emit targeted v61t/v61an/v61ae post-receipt command rows while keeping receipt-backed materialization, full page-hash, and generation blocked.
58. Closed as v61bs ubuntu-1 post-receipt verification result intake: define result-artifact intake for v61t/v61an/v61ae post-receipt summaries while keeping materialization, full page-hash, generation admission, and actual generation blocked.
59. Closed as v61bt ubuntu-1 actual generation result intake: define source-bound answer/citation/abstain/latency/acceptance result intake over v61bs and v53r while keeping actual generation, production latency, near-frontier quality, and release claims blocked.
60. Closed as v61bu ubuntu-1 partial checkpoint materialization witness: bind the first live size/header identity-verified shard while keeping receipt-backed full materialization, full page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
61. Closed as v61bv ubuntu-1 remaining checkpoint materialization queue: skip the first identity-verified shard and rewrite the remaining 58-shard dry-run-first execution queue while keeping explicit payload execution, receipt-backed full materialization, full page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
62. Closed as v61bw ubuntu-1 partial page-hash witness: read the first identity-verified shard into 2353 local page-hash witness rows while keeping completed full safetensors page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
63. Closed as v61bx ubuntu-1 page-hash coverage ledger: promote the 2353 verified page hashes into a 59-shard ledger with 131808 remaining page hashes while keeping completed full safetensors page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
64. Closed as v61by ubuntu-1 remaining page-hash execution plan: skip the 2353 verified page hashes and schedule the remaining 131808 page hashes into 286 guarded chunks while keeping completed full safetensors page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
65. Closed as v61bz ubuntu-1 remaining page-hash operator bundle: convert the 286 remaining page-hash chunks into a dry-run-first, approval-gated operator bundle while keeping explicit page-hash execution, completed full safetensors page-hash coverage, generation, production latency, near-frontier quality, and release claims blocked.
66. Promote activation-admitted, identity-verified local shards into completed full safetensors page-hash coverage.
67. Promote the v53i complete-source query set into A-H QA and real model generation only after checkpoint/page hash binding exists.
68. Keep real 100B materialization, near-frontier quality, production latency, and release claims blocked until external review passes.

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
- checkpoint residency requires 315601231712 bytes with reserve; the default
  current target remains budget-blocked, while ubuntu-1 now passes the
  full-reserve capacity target check and v61bv records enough current free
  bytes for the remaining 276308963480 unverified checkpoint bytes
- local checkpoint materialization has an identity verifier, and the current
  ubuntu-1 path has one local existing, size-matched, safetensors-header-matched,
  identity-verified shard covering 4932529864 bytes; full 59-shard
  materialization remains blocked
- that identity-verified shard now has local page-hash witness coverage for
  all 2353 pages / 4932529864 bytes, while completed full safetensors page-hash
  coverage remains blocked at 2353/134161 pages
- checkpoint-wide page-hash accounting now records 2353 verified page hashes
  and 131808 remaining page hashes across 59 shards
- remaining page-hash execution planning now skips the verified shard and
  schedules 131808 remaining page hashes into 286 guarded chunks
- remaining page-hash operator bundling now exposes those 286 chunks through
  seven dry-run-first operator files, with explicit execution, approval, and
  identity-verification confirmation gates still required before hashing the
  remaining shard pages
- bounded remote page-hash sampling has read 16 full 2 MiB checkpoint pages and
  stored hashes only, not payload bytes or full coverage
- those 16 remote-hashed pages are bound to 16 real tensor/runtime-node rows,
  including 15 MoE expert page bindings across 15 layers and all eight expert
  indices
- materialization planning has 59 download-resume rows, 16 sampled-priority
  shard rows, 15 MoE-first shard rows, and keeps
  `materialization_admission_ready=0` until the SSD budget and local identity
  gates pass
- the 16 remote-hashed real checkpoint pages now have planned NVMe hotset slots
  and are bound to 37 source-bound replay rows, with real model generation still
  blocked
- those 16 sampled hotset page payloads are now materialized outside the
  repository with 33554432 persisted bytes, 16 local hash matches, and 16
  readback hash matches, but this is still not full checkpoint materialization
- those 16 sampled hotset page payloads are also materialized under the
  ubuntu-1 target with 33554432 persisted bytes, 16 local hash matches, and 16
  readback hash matches, but this is still not full checkpoint materialization
- those 16 ubuntu-1 sampled hotset pages can be read through O_DIRECT with
  16 hash matches, 33554432 direct-I/O bytes, p50/p95 read latency
  1.102615/1.234314 ms, and 1946.456509 MiB/s sampled throughput, but this is
  still not real model generation or production latency
- those ubuntu-1 resident pages can be interpreted as BF16 tensor slices, probed
  as bounded BF16/q8/q4 tensor tiles, replayed through 37 source-bound
  token-budget rows, and combined into 185 KV+weight budget rows, but this is
  still not full checkpoint materialization or real Mixtral generation
- the ubuntu-1 sampled source-bound page schedule can collapse 148 scheduled
  page reads into 15 unique persistent-hotset cold fills plus 133 cache-hit
  rows, saving 278921216 sampled bytes in the replay window, but this is still
  not full runtime admission or production latency
- those 16 local sampled hotset pages can be read through O_DIRECT with 16 hash
  matches, 33554432 direct-I/O bytes, p50/p95 read latency
  0.580768/0.956690 ms, and 2784.734538 MiB/s sampled throughput, but this is
  still not real model generation or production latency
- those local pages can be interpreted as 16 real BF16 tensor slices covering
  33550832 segment bytes, with 65536 sampled finite values, zero sampled
  NaN/Inf values, and 16 slice/page hash matches, but this is still not real
  Mixtral generation
- those sampled slices can feed 128 bounded BF16/q8/q4 dot-tile probes over
  524288 BF16 values, with 128/128 finite baseline/q8/q4 dot rows and q8/q4
  mean absolute dot errors of 0.00113809798/0.0244754219, but this is still not
  real Mixtral generation or production latency
- the sampled hotset path can replay 37 source-bound token-budget rows with
  148 active page schedule rows, 1184 tile-binding rows, 8388608 SSD read bytes
  per token, 131072 BF16 tile values per token, and sampled token direct-I/O
  p50/p95 budgets of 2.323072/3.82676 ms, but this is still not production
  latency or real Mixtral generation
- the sampled token-budget rows can be combined with five KV context profiles
  into 185 KV+weight budget rows, with 185 resident KV policy passes, 74
  full-KV-in-VRAM passes, 111 NVMe cold KV eviction-required rows, zero host RAM
  spill bytes, and 8617984 sampled weight+new-KV bytes per token, but this is
  still not full KV-in-VRAM residency, production latency, or real Mixtral
  generation
- the real generation admission gate can emit 1000 complete-source generation
  candidate rows with 1000 runtime-budget-ready rows, but admits 0 rows until
  source review, materialization, and full page-hash gates pass
- the checkpoint warehouse operator bundle can emit 59 priority download
  commands, 62 guarded operator command rows, and dry-run scripts for download,
  materialization verification, full page hashing, and generation-admission
  recheck, but downloads zero checkpoint payload bytes by default
- the checkpoint warehouse execution preflight can verify 4/4 operator scripts,
  run a one-row guarded dry-run download probe, and show that current download
  execution remains blocked by missing CLI/SSD-budget gates
- the download backend fallback plan can select `curl-resume` from three ready
  backends and emit 59 guarded backend download rows, but SSD budget still
  blocks actual checkpoint download execution
- the storage budget remediation plan can quantify the current full-checkpoint
  deficit as 294263770976 bytes with reserve, admit zero reserve-safe shard rows,
  and record a 4-shard / 19478756392-byte diagnostic no-reserve batch, but it
  still blocks download execution and materialization
- the storage profile admission matrix can show that the current reserve policy
  admits zero shards, the current no-reserve diagnostic profile admits 4 shards,
  the exact full-reserve profile admits all 59 shards, and a 512 GiB free-space
  profile provides the recommended operator margin, but current-host execution
  remains blocked
- the warehouse target preflight can probe live target paths, reject
  repository-local checkpoint payload targets, and report current target free
  bytes and full-reserve deficit, but it still downloads zero checkpoint payload
  bytes and keeps explicit execution blocked
- the warehouse activation gate can bind 59 shard activation rows to the
  selected `curl-resume` backend, but admits zero rows until a full-reserve
  outside-repository target is selected
- the post-activation verification gate can bind activation rows to local
  identity and full page-hash readiness, but records zero ready rows until
  activation, local shard identity, and full page-hash coverage all pass
- the full page-hash execution gate can schedule 134161 planned page hashes into
  291 resumable chunks, but records zero hashed chunks until activation and
  local shard identity pass
- the real model page-manifest coverage audit can bind v61q/v61v/v61an into
  59-shard, 134161-page, 1344-cell MoE metadata coverage with zero checkpoint
  payload bytes downloaded by v61ao, but still does not provide full page-hash
  coverage or real generation
- the MoE coverage remote hash plan can preserve 15 already remote-hashed MoE
  cells and plan 1329 remaining representative layer/expert/tensor page hashes,
  but it performs no new range reads and still does not provide full MoE or full
  safetensors page-hash coverage
- the MoE remote hash execution gate can emit 1329 guarded curl-range commands
  and 21 resumable chunks while preserving 15 existing hashes, but remote hash
  execution remains disabled and no new payload bytes are downloaded
- the MoE remote hash result intake gate defines 1329 hash-only return rows,
  preserves 15 existing hashes, and records the missing rows as final-deferred
  by default, but full MoE remote-hash coverage still remains blocked
- the sampled hotset reuse admission gate shows 148 scheduled sampled MoE page
  touches collapsing to 15 cold-fill pages plus 133 cache-hit rows, but full
  runtime admission still requires full MoE hash and full page-hash coverage
- the sampled prefetch-overlap admission gate shows 36/36 non-bootstrap token
  rows fitting p95 SSD cold-fill reads inside the prior token GPU page-kernel
  window, but bootstrap cold-start and full runtime admission remain blocked
- the sampled prefetch queue-depth scheduler gate turns those overlap rows into
  11/11 steady-state deadline-met issue rows at configured queue depth 4, but
  bootstrap scheduling, actual async I/O, and full runtime admission remain
  blocked
- the sampled async prefetch execution probe executes 15/15 sampled issue reads
  through a queue-depth 4 threaded O_DIRECT worker pool with 15 hash matches,
  but io_uring, registered buffers, bootstrap admission, and full runtime
  admission remain blocked
- the current-host io_uring registered-buffer preflight records Linux UAPI
  header ready 1, liburing header ready 0, setup/enter/register syscall numbers
  425/426/427, raw setup blocked by `EPERM`, setup/enter/register readiness 0,
  registered-buffer prefetch readiness 0, and threaded O_DIRECT fallback
  readiness 1
- the async-I/O backend selection gate chooses `threaded_odirect` as the
  current-host sampled prefetch backend, with queue depth 4, 15 hash-match rows,
  zero backend errors, io_uring registered-buffer candidate ready 0,
  registered-buffer prefetch ready 0, and full runtime async-I/O admission
  still blocked
- the selected-backend token runtime binding gate binds 185/185 KV+weight token
  budget rows and 5/5 context profiles to `threaded_odirect`, preserving
  37 source-bound query rows, 74 full-KV-in-VRAM pass rows, 111 NVMe
  eviction-required rows, zero host RAM spill bytes, and blocked full runtime
  async-I/O admission
- the ubuntu-1 warehouse target admission gate records `/dev/nvme0n1p8`
  label `ubuntu-1` as an outside-repository full-reserve capacity target, but
  the managed-session direct probe still blocks target write/activation
  readiness and performs no checkpoint payload download
- the ubuntu-1 activation handoff package rewrites all 59 shard handoff rows,
  post-download verifier rows, full page-hash rows, and generation-admission
  recheck rows to the ubuntu-1 target with zero stale `/tmp` target commands,
  while keeping explicit download execution blocked
- the ubuntu-1 write sentinel activation probe records an operator/escalated
  write witness under the target path, resolving the write-step evidence for
  metadata activation while keeping checkpoint payload execution blocked
- the ubuntu-1 sampled hotset materialization verifier persists 16 bounded
  sampled pages under the ubuntu-1 target with 16/16 hash and readback matches,
  while keeping full checkpoint materialization blocked
- the ubuntu-1 sampled hotset direct-I/O replay reads those 16 bounded sampled
  pages with O_DIRECT, records 16/16 hash matches and target-specific
  p50/p95/throughput rows, while keeping production-latency claims blocked
- the ubuntu-1 resident tensor-slice verifier interprets those sampled pages as
  real BF16 tensor segments with finite sampled values and inherited
  page/direct-read hash witnesses, while keeping generation blocked
- the ubuntu-1 resident tensor-tile quant probe measures bounded BF16/q8/q4
  numeric tile risk over those slices, while keeping release claims blocked
- the ubuntu-1 token-budget replay binds source-bound workload rows to
  target-specific direct-I/O latency and resident tile evidence, while keeping
  production-latency and near-frontier claims blocked
- the ubuntu-1 KV+weight token-budget replay combines target-specific weight
  budgets with KV context profiles, preserving zero host RAM KV spill while
  keeping generation and production-latency claims blocked
- the ubuntu-1 hotset reuse admission gate records persistent-hotset cold
  fills/cache hits over the sampled source-bound schedule, while keeping full
  runtime admission, generation, and production-latency claims blocked
- the ubuntu-1 sampled prefetch-overlap admission gate shows 36/36
  non-bootstrap rows fitting p95 target-resident SSD reads inside the prior
  token GPU page-kernel window, while keeping bootstrap and full runtime
  admission blocked
- the ubuntu-1 sampled prefetch queue-depth scheduler gate turns those overlap
  rows into 11/11 steady-state deadline-met issue rows at configured queue
  depth 4, while keeping bootstrap scheduling and actual async execution
  blocked
- the ubuntu-1 sampled async prefetch execution probe executes 15/15 sampled
  issue reads through a queue-depth 4 threaded O_DIRECT worker pool with 15
  hash matches, while keeping bootstrap admission, io_uring, registered
  buffers, full checkpoint materialization, full page-hash coverage, and
  generation blocked
- the ubuntu-1 bootstrap cold-start admission gate admits the four token-0
  cold-fill reads as a blocking pre-generation batch inside a configured
  startup budget, while keeping bootstrap prefetch overlap, io_uring,
  registered buffers, full runtime admission, full checkpoint materialization,
  full page-hash coverage, and generation blocked
- the ubuntu-1 activation admission refresh gate admits 59/59 target-bound
  shard handoff rows to the ubuntu-1 activation target using the write witness,
  while keeping explicit payload execution, full checkpoint materialization,
  full page-hash coverage, and generation blocked
- the ubuntu-1 payload execution readiness gate records 59/59 target-bound
  resumable curl rows and three priority execution chunks as preflight-ready,
  while keeping actual payload execution, full checkpoint materialization, full
  page-hash coverage, and generation blocked
- the ubuntu-1 payload execution launch bundle emits dry-run-first operator
  scripts with explicit approval requirements, 59 launch rows, and three
  priority chunks, while keeping actual payload execution, full checkpoint
  materialization, full page-hash coverage, and generation blocked
- the ubuntu-1 payload execution receipt intake gate defines the receipt schema
  and live target-file presence rows for 59 launch commands, records one live
  size-matched shard on the current ubuntu-1 target, while keeping receipt-backed
  full checkpoint materialization, full page-hash coverage, and generation
  blocked
- the ubuntu-1 post-receipt materialization promotion gate binds the ubuntu-1
  target root and emits targeted v61t/v61an/v61ae post-receipt verification
  commands, while keeping receipt-backed materialization, full page-hash
  coverage, and generation blocked
- the ubuntu-1 post-receipt verification result intake defines the returned
  v61t/v61an/v61ae summary artifact schema and keeps missing result artifacts,
  full materialization, full page-hash coverage, and generation blocked
- the ubuntu-1 actual generation result intake defines source-bound
  answer/citation/abstain/latency/acceptance result schemas over 1000 query rows,
  while keeping accepted generation rows at zero until post-receipt verification,
  complete-source review, and page-hash gates pass
- the ubuntu-1 partial checkpoint materialization witness binds one live
  size/header identity-verified shard and 4932529864 externally observed payload
  bytes, while keeping repo payload bytes at zero and full materialization,
  full page-hash coverage, actual generation, production latency, near-frontier
  quality, and release claims blocked
- the ubuntu-1 remaining checkpoint materialization queue excludes that verified
  shard, emits a 58-row dry-run-first remaining queue across three priority
  chunks, records current free-space fit for 276308963480 remaining bytes, and
  still requires explicit payload execution before full materialization can
  advance

The full local assistant claim additionally requires source-bound tasks with citation, abstain, and fallback evidence over real open-weight model rows.

The correct current claim is:

> v61 is a measured prototype artifact for SSD-resident active-sparse local LLM runtime research. It proves the prepared SSD page-store path, logical 100B+ MoE contract, real-model redistributable page manifest, checkpoint identity/header/sample-page binding, local SSD residency preflight, local checkpoint materialization identity verification mechanics, bounded remote checkpoint page-hash samples, remote-hashed page tensor/runtime-node bindings, materialization admission/resume planning, planned NVMe hotset/runtime replay binding, sampled local hotset page materialization, sampled direct-I/O hotset read replay, sampled BF16 tensor-slice interpretation, sampled BF16/q8/q4 tensor-tile numeric probes, sampled source-bound hotset token-budget replay, sampled KV+weight token-budget replay, real generation admission gating, guarded checkpoint warehouse operator scripting, checkpoint warehouse execution preflight, checkpoint download backend fallback planning, checkpoint storage budget remediation planning, checkpoint storage profile admission matrixing, checkpoint warehouse target preflight, checkpoint warehouse activation gating, checkpoint post-activation verification gating, checkpoint full page-hash execution gating, real model page-manifest coverage auditing, MoE coverage remote-hash expansion planning, MoE remote-hash execution gating, MoE remote-hash result intake gating, sampled hotset reuse admission gating, sampled prefetch-overlap admission gating, sampled prefetch queue-depth scheduler admission gating, sampled threaded O_DIRECT async prefetch execution, current-host io_uring/registered-buffer preflight, current-host async-I/O backend selection, selected-backend token runtime binding, ubuntu-1 full-reserve warehouse capacity admission, ubuntu-1 target-bound activation handoff packaging, ubuntu-1 write sentinel activation witnessing, ubuntu-1 bounded sampled-hotset materialization, ubuntu-1 sampled-hotset direct-I/O replay, ubuntu-1 resident BF16 tensor-slice verification, ubuntu-1 resident BF16/q8/q4 tensor-tile quant probing, ubuntu-1 source-bound token-budget replay, ubuntu-1 KV+weight token-budget replay, ubuntu-1 persistent-hotset reuse admission, ubuntu-1 sampled prefetch-overlap admission, ubuntu-1 sampled prefetch queue-depth scheduler admission, ubuntu-1 sampled threaded O_DIRECT async prefetch execution, ubuntu-1 bootstrap cold-start admission, ubuntu-1 activation target admission refresh, ubuntu-1 payload execution readiness gating, ubuntu-1 payload execution launch bundling, ubuntu-1 payload execution receipt intake, ubuntu-1 post-receipt materialization promotion gating, ubuntu-1 post-receipt verification result intake, ubuntu-1 actual generation result intake, ubuntu-1 partial checkpoint materialization witnessing, and ubuntu-1 remaining checkpoint materialization queueing, not completed real-checkpoint residency, full checkpoint payload activation/download execution, full safetensors page-hash coverage, actual io_uring/registered-buffer prefetch, full KV-in-VRAM residency, production-latency evidence, or real near-frontier open-weight inference.
