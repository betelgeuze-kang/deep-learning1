# h9 ROCm/HIP Backend Scaffold

h9 introduces an optional ROCm/HIP backend scaffold. It is a backend boundary
and parity harness, not a performance claim.

The CPU reference remains canonical:

```text
candidate value_pos -> value byte read -> proposal hint
```

The forbidden route remains closed:

```text
remote node as neighbor / jump-neighbor replacement
```

## Current Stage

h9 is currently a quick-closure backend scaffold layered after the h7
route-memory goal closure:

```text
h6-t/u/v/w route-memory diagnostics plus h7-b promotion and h7-c promotion
review gates are wired into h7.
h9 quick closure passes CPU default behavior, CPU-only HIP error handling,
h9-f CPU numeric parity, h9-g measured-speed no-claim checks, h9-h diagnostic
CPU/HIP/NVMe workload-speed checks, h7, and
v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l/v08-m/v08-n/v08-o/v08-p/v08-q/v08-r/v08-s/v08-t/v08-u/v08-v/v08-w/v08-x/v08-y/v08-z/v08-aa/v08-ab/v08-ac/v08-ad/v08-ae/v08-af/v08-ag/v08-ah/v08-ai/v08-aj/v08-ak/v08-al/v08-am/v08-an/v08-ao/v08-ap/v08-aq/v08-ar/v08-as/v08-at benchmark
adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/source-import/source-import-verifier/live-verifier/live-review/authoritative-review/public-registry/live-registry-query/live-registry-fetcher/live-registry-network-proof/real-verification/official-authority/result-authority/publication/source-acquisition/source-acquisition-content/codebase-mini/content-result-bridge/family-result-bridge/independent-reproduction/official-release/live-release/canonical-confirmation/publication-result-review/live-publication-result-ingestion/authority-promotion-evidence/run-evaluator-trace/independent-run-evaluator-evidence/live-replay-final-review/public-nonfixture-verification/runner-owned-live-execution-audit/independent-live-rerun-confirmation/real-nonfixture-run-package/live-package-artifact-fetch-authority/official-result-reconciliation/readiness
plus h11-a PC RouteLM prototype readiness/import, h11-b artifact verifier/import,
h11-c NVMe RouteMemory store/artifact smokes, h11-d diagnostic NLG smoke, and
h7-c promotion review plus v12 paper/release claim audit plus v13-a real-run
binder manifest plus v13-b RouteLM mmap reader plus v13-c evidence packet ABI
plus v13-d real NLG transcript binding plus v13-e public codebase RouteQA
binding plus v13-f resource envelope binding plus v13-g real evidence
promotion gate plus v13-h real evidence intake gate plus v13-i real evidence
live-network gate plus v13-j real evidence rebind gate plus v13-k runtime fetch
provenance gate plus v13-l source seed gate plus v13-m source seed live-fetch
gate plus v13-n external benchmark official source acquisition gate.
HIP parity remains optional and environment-dependent.
```

This means the active research boundary returns to adaptive route-memory
guardrail scaling, not GPU acceleration claims. CPU remains the reference
behavior.

## h9-a Backend Scaffold Decision

`h9-a` passes as HIP backend scaffold instrumentation when the CPU build,
runtime backend validation, and CSV backend metrics work.

New build option:

```bash
cmake -S . -B build
cmake -S . -B build-hip -DDLE_ENABLE_HIP=ON
```

New runtime options:

```bash
--backend cpu|hip
--hip-device <int>
```

New metrics:

```text
backend_active
hip_enabled
hip_device
hip_kernel_calls
hip_fallback_count
```

`--backend cpu` is the default. `--backend hip` in a CPU-only binary fails with
a clear `DLE_ENABLE_HIP=ON` runtime error.

## h9-b Candidate-weight Parity Kernel

The first HIP kernel is intentionally narrow: it computes the bounded
candidate-quality weight factor used by route-quality candidate weighting.

It does not:

- parse KV strings on GPU
- build hash buckets on GPU
- mutate graph topology
- accept or reject node updates on GPU
- change route strength
- revive jump-neighbor replacement

The factor formula is the existing CPU formula:

```text
factor = clamp(1 + beta * (base_weight / mean_base_weight - 1), min, max)
```

When HIP is active, `route_quality_candidate_weight_factor` calls the backend
factor path. Unsupported or failed HIP paths may fall back to CPU and increment
`hip_fallback_count`.

## h9-d Proposal-score Diagnostic Kernel

h9 also adds a diagnostic-only HIP proposal-score kernel for exhaustive high/low
nibble energy scoring:

```text
energy(high, low) =
  -lambda_u * (high_score[high] + low_score[low])
  -lambda_b * coupling_score[high, low]
```

This kernel only emits scores for a fixed 16x16 proposal grid and is currently
exercised by the parity tool. It does not accept updates, run RNG, mutate node
state, update tick/reservoir/age, or select graph neighbors. The CPU still owns
the real update decision path.

## Verification

Always-run CPU checks:

```bash
bash -n experiments/*.sh
cmake --build build --target dmv02 -j2
experiments/test_v09_gpu_backend_cpu_smoke.sh
experiments/test_v09_gpu_backend_nohip_error.sh
experiments/test_v09_gpu_backend_extended_boundary.sh
experiments/test_v09_gpu_backend_speed_evidence.sh
experiments/test_v09_gpu_backend_measured_speed_gate.sh
experiments/test_v09_gpu_backend_measured_speed_import.sh
experiments/test_v09_gpu_backend_real_workload_speed_gate.sh
experiments/test_v05_route_quality_closure.sh
experiments/test_v07_goal_route_memory_closure.sh
experiments/test_v08_external_benchmark_adapter.sh
experiments/test_v08_external_benchmark_source_acquisition_gate.sh
experiments/test_v08_external_benchmark_source_acquisition_content_verifier.sh
experiments/test_v08_external_benchmark_codebase_mini.sh
experiments/test_v08_external_benchmark_content_result_bridge.sh
experiments/test_v08_external_benchmark_family_result_bridge.sh
experiments/test_v08_external_benchmark_independent_reproduction_review.sh
experiments/test_v08_external_benchmark_official_release_evidence.sh
experiments/test_v08_external_benchmark_live_release_verification.sh
experiments/test_v08_external_benchmark_canonical_online_confirmation.sh
experiments/test_v08_external_benchmark_publication_result_review.sh
experiments/test_v08_external_benchmark_live_publication_result_ingestion.sh
experiments/test_v08_external_benchmark_authority_promotion_evidence.sh
experiments/test_v08_external_benchmark_run_evaluator_trace.sh
experiments/test_v08_external_benchmark_independent_run_evaluator_evidence.sh
experiments/test_v08_external_benchmark_live_replay_final_review.sh
experiments/test_v08_external_benchmark_public_nonfixture_verification.sh
experiments/test_v08_external_benchmark_runner_owned_live_execution_audit.sh
experiments/test_v08_external_benchmark_independent_live_rerun_confirmation.sh
experiments/test_v08_external_benchmark_real_nonfixture_run_package.sh
experiments/test_v08_external_benchmark_live_package_artifact_fetch_authority.sh
experiments/test_v08_external_benchmark_official_result_reconciliation.sh
experiments/test_v08_external_benchmark_evidence_ingestion.sh
experiments/test_v08_external_benchmark_evidence_import.sh
experiments/test_v08_external_benchmark_comparison_gate.sh
experiments/test_v08_external_benchmark_comparison_import.sh
experiments/test_v08_external_benchmark_real_evidence_gate.sh
experiments/test_v08_external_benchmark_real_evidence_placeholder.sh
experiments/test_v08_external_benchmark_real_evidence_format.sh
experiments/test_v08_external_benchmark_artifact_verifier.sh
experiments/test_v08_external_benchmark_artifact_verifier_local.sh
experiments/test_v08_external_benchmark_authenticity_gate.sh
experiments/test_v08_external_benchmark_authenticity_import.sh
experiments/test_v08_external_benchmark_execution_gate.sh
experiments/test_v08_external_benchmark_execution_import.sh
experiments/test_v08_external_benchmark_attestation_gate.sh
experiments/test_v08_external_benchmark_attestation_import.sh
experiments/test_v08_external_benchmark_attestor_identity_gate.sh
experiments/test_v08_external_benchmark_attestor_identity_import.sh
experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh
experiments/test_v08_external_benchmark_source_import_gate.sh
experiments/test_v08_external_benchmark_source_import_remote_contract.sh
experiments/test_v08_external_benchmark_source_import_verifier_gate.sh
experiments/test_v08_external_benchmark_source_import_live_verifier_gate.sh
experiments/test_v08_external_benchmark_source_import_live_review_gate.sh
experiments/test_v08_external_benchmark_final_review_gate.sh
experiments/test_v08_external_benchmark_final_review_import.sh
experiments/test_v08_external_benchmark_final_review_real_source_guard.sh
experiments/test_v08_external_benchmark_final_review_remote_review_guard.sh
experiments/test_v08_external_benchmark_final_review_remote_full_guard.sh
experiments/test_v08_external_benchmark_readiness.sh
experiments/test_v11_pc_routelm_prototype_readiness.sh
experiments/test_v11_pc_routelm_prototype_import.sh
experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh
experiments/test_v11_pc_routelm_prototype_artifact_import.sh
experiments/test_v12_paper_release_claim_audit.sh
experiments/test_v13_real_run_binder_manifest.sh
experiments/test_v13_routelm_mmap_reader.sh
experiments/test_v13_evidence_packet_abi.sh
experiments/test_v13_real_nlg_transcript.sh
experiments/test_v13_public_codebase_routeqa.sh
experiments/test_v13_resource_envelope.sh
```

Optional HIP check:

```bash
experiments/test_v09_gpu_backend_candidate_weight_parity.sh
```

This script skips cleanly when `hipcc`, an offload architecture, or ROCm device
libraries are unavailable. On a usable ROCm/HIP install, it builds with
`DLE_ENABLE_HIP=ON`, runs fixed synthetic candidate-weight and proposal-score
parity checks, then compares a small route-quality fixture under CPU and HIP.

CPU quick closure also runs the same parity tool in `--backend cpu` mode. This
turns the previous static boundary check into an executable numeric check for
candidate-weight factors and the diagnostic 16x16 proposal-score grid on
CPU-only machines.

Speed evidence is a separate no-overclaim gate:

```bash
experiments/test_v09_gpu_backend_speed_evidence.sh
experiments/test_v09_gpu_backend_measured_speed_gate.sh
experiments/test_v09_gpu_backend_measured_speed_import.sh
```

h9-f marks `speed_schema_ready=1`, but keeps `speed_evidence_ready=0`.
h9-g then verifies timing and environment artifacts, warmup/measured-run
counts, and positive CPU/HIP timing ratios. Local fixtures remain no-claim:
`gpu_speedup_claim=deferred` until the measurement source is real HIP-backed.

h9-h binds that timing contract to the h11-d PC RouteLM NLG smoke and a
CPU/HIP/NVMe workload row:

```bash
experiments/run_v09_gpu_backend_real_workload_speed_gate.sh
experiments/test_v09_gpu_backend_real_workload_speed_gate.sh
```

The diagnostic generated fixture verifies NLG-result/timing/environment
artifact hashes, positive CPU/HIP ratio, NVMe read latency,
query-to-evidence, query-to-first-token, tokens/sec, SSD bytes/query, RAM/VRAM
metrics, and zero route/jump activity:

```text
diagnostic_workload_speed_ready = 1
real_workload_speed_evidence_ready = 0
gpu_speedup_claim = deferred
```

Real speed evidence remains blocked until h9-g has real HIP-backed measured
speed evidence, h11-d has non-fixture PC RouteLM NLG evidence, and the workload
row is non-fixture with real HIP/NVMe measurements plus a verified benchmark or
product trace.

v12 consumes h9-h in the release-claim audit and keeps the GPU acceleration
claim blocked:

```text
h9h_diagnostic_workload_speed_ready = 1
h9h_real_workload_speed_evidence_ready = 0
h9h_gpu_speedup_claim = deferred
forbidden_gpu_acceleration_claim = blocked
release_claim = diagnostic-artifact-package-only
```

Closure entrypoint:

```bash
experiments/test_v09_gpu_backend_closure.sh
experiments/test_v09_gpu_backend_closure.sh --extended
```

The extended closure includes the optional HIP parity check.

## Current Interpretation

h9 is:

```text
PASS as optional HIP backend scaffold / candidate-weight and proposal-score parity instrumentation,
with h9-f executable CPU numeric parity plus h9-g/h9-h measured-speed and workload-speed no-claim checks in quick closure
and v12 blocking any release-level GPU acceleration claim
```

Do not read this as:

```text
GPU acceleration proven
CPU/HIP full training parity proven on this machine
learned routing solved
long-context retrieval solved
```

It is not:

```text
GPU acceleration proven
learned routing solved
long-context retrieval solved
wrong-candidate robustness solved
Transformer replacement
```

If future slices add proposal-score kernels, they should remain diagnostic-only
until CPU/HIP best-candidate parity is exact. RNG, update acceptance, age,
tick, reservoir mutation, string/KV parsing, source-credit ledgers, and CSV
output stay on CPU in h9.
