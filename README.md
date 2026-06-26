# discrete-local-energy

Deterministic C++17 reference code for a staged discrete local-energy research prototype.

Korean README: [README.ko.md](README.ko.md)

**Artifact boundary:** This is a machine-verifiable research artifact, not a human-reviewed release package.

## Readiness status

Central readiness is tracked per scope in [`readiness/typed_ready.json`](readiness/typed_ready.json) and enforced by `tools/verify_artifact.py typed-readiness` via `./scripts/ai-verify.sh`. Only typed flags are claimable; bare `vXX_ready` wording is forbidden.

- Human-readable mirror and full scope table: [`docs/STATUS.md`](docs/STATUS.md)
- Tooling, packets, and docs index: [`docs/INDEX.md`](docs/INDEX.md)
- `v53` and `v54` are tracked as separate scopes:
  - `v53-benchmark-foundation`: `contract_ready` and `fixture_execution_ready` (mirrors `benchmarks/v53_source_bound_freeze.json`).
  - `v54-free-running-generation`: `contract_ready` only; `fixture_execution_ready` stays `false` because `v54/free_running_generation_evidence_intake_contract.json` reports 0 of 7 required artifacts present.
- Real-model execution, heldout metric, human review, independent reproduction, and release remain blocked for every scope.

## v1.0 Architecture Challenge Roadmap

`discrete-local-energy` explores RouteMemory, compact RouteHint routing, source-bound evaluation, non-attention generation contracts, and SSD-resident MoE runtime mechanics. The repository is organized as claim-bound research artifacts: a capability is only described as ready when a typed readiness row and its evidence path support that exact claim.

Canonical status lives in [`readiness/typed_ready.json`](readiness/typed_ready.json). Historical checkpoint notes moved to [`docs/archive/IMPLEMENTATION_HISTORY.md`](docs/archive/IMPLEMENTATION_HISTORY.md).

## Current Readiness

| Scope | Contract | Fixture | Real execution | Heldout | Human review | Release |
|---|---:|---:|---:|---:|---:|---:|
| v53 benchmark foundation | ✅ | ✅ | N/A | ⛔ | ⛔ | ⛔ |
| v54 generation | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| D/E 30B-70B baselines | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| v58 blind evaluation | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| v61 SSD-MoE | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |

Canonical status: [`readiness/typed_ready.json`](readiness/typed_ready.json)

Last reviewed: 2026-06-25

## What Works Now

- v53 benchmark foundation is frozen as a machine-prepared source-bound benchmark surface: 10 pinned public repositories, 1000 query rows, 1000 source-span rows, direct query/span binding audit, unseen repository split, and A/B/G/H internal pre-baseline evidence.
- v54 generation contracts and fixture paths are present, but real free-running generation evidence is still blocked.
- v61 SSD-MoE is a contract/fixture R&D track. It is not a real SSD-resident model runtime claim.
- Local preview tooling exists for evidence-bound repository audit and scaling demos, but these are local artifact surfaces, not release or public benchmark claims.

## Next Blockers

- D/E 30B-70B real baseline evidence intake is still missing, so public comparison wording remains blocked.
- v54 real free-running generation needs actual model execution evidence before promotion beyond fixture readiness.
- v58 blind evaluation needs real blind responses, independent reviewers, disagreement adjudication, and accepted human review evidence.
- v61 one-token logits parity, real runtime execution, generation, latency, and near-frontier quality claims remain blocked.
- Release readiness remains blocked until typed readiness, evidence ledgers, human review, independent reproduction, and artifact contracts all agree.

## Verification

Use cheap local checks first:

```bash
./scripts/ai-verify.sh
tools/verify_artifact.py typed-readiness readiness/typed_ready.json
```

Focused contract checks:

```bash
tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json   --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv   --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv   --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv   --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv   --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv
```

## Key Entrypoints

- Roadmap: [`docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`](docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md)
- v61 runtime direction: [`docs/V61_SSD_RESIDENT_MOE_RUNTIME.md`](docs/V61_SSD_RESIDENT_MOE_RUNTIME.md)
- Pipeline migration notes: [`docs/PIPELINE_MIGRATION.md`](docs/PIPELINE_MIGRATION.md)
- Review-return contract: [`operations/review_return_workflow.json`](operations/review_return_workflow.json)
- Historical implementation log: [`docs/archive/IMPLEMENTATION_HISTORY.md`](docs/archive/IMPLEMENTATION_HISTORY.md)
