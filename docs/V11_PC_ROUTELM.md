# h11 PC RouteLM / NLG Prototype Boundary

h11 opens the PC RouteLM prototype gate. It is a readiness and evidence
contract, not a claim that a real local LLM exists yet.

The target architecture is:

```text
small quantized generator
+ CPU RAM / NVMe resident O(n) route memory
+ GPU candidate scoring
+ GPU decoder binding
+ NLG smoke evidence
```

## h11-a Readiness Gate

Entry points:

```bash
experiments/run_v11_pc_routelm_prototype_readiness.sh
experiments/test_v11_pc_routelm_prototype_readiness.sh
experiments/test_v11_pc_routelm_prototype_import.sh
```

The default run validates the schema but blocks all component evidence:

```text
prototype_contract_schema_ready = 1
component_evidence_ready = 0
nlg_smoke_ready = 0
pc_routelm_prototype_ready = 0
publishable_pc_routelm_ready = 0
action = pc-routelm-components-missing
```

`V11_PC_ROUTELM_PROTOTYPE_CSV` can supply a component-evidence row. The h11-a
fixture requires:

- `parameter_class` in the 3B-14B range
- quantization metadata
- `route_memory_residency` of `cpu-ram` or `nvme`
- `route_memory_index_policy = o-n-scan`
- `candidate_scoring_device = gpu`
- `decoder_device = gpu`
- an `nlg_smoke_uri`
- license and provenance fields

The supplied fixture reaches only diagnostic prototype readiness:

```text
component_evidence_ready = 1
diagnostic_prototype_ready = 1
pc_routelm_prototype_ready = 0
publishable_pc_routelm_ready = 0
action = diagnostic-prototype-only
```

## Blocking Conditions

h11-a deliberately keeps the real prototype blocked until these are true:

- route-memory default promotion is allowed
- teacher-distilled chunk quality is ready from real external labels
- external benchmark comparison is ready
- measured GPU speed evidence exists

Until then, this remains an interface and evidence gate. It is not real natural
language generation solved, not GPU acceleration proven, and not a Transformer
replacement claim.
