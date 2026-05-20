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
h6-t/u/v/w route-memory diagnostics and h7-b promotion gates are wired into h7.
h9 quick closure passes CPU default behavior, CPU-only HIP error handling, h9-e
extended-boundary checks, h7, and v08 benchmark readiness.
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
experiments/test_v05_route_quality_closure.sh
experiments/test_v07_goal_route_memory_closure.sh
experiments/test_v08_external_benchmark_readiness.sh
```

Optional HIP check:

```bash
experiments/test_v09_gpu_backend_candidate_weight_parity.sh
```

This script skips cleanly when `hipcc`, an offload architecture, or ROCm device
libraries are unavailable. On a usable ROCm/HIP install, it builds with
`DLE_ENABLE_HIP=ON`, runs fixed synthetic candidate-weight and proposal-score
parity checks, then compares a small route-quality fixture under CPU and HIP.

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
with h9-e extended-boundary checks in quick closure
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
