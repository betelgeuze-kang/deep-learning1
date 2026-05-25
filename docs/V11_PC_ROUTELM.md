# h11 PC RouteLM / NLG Prototype Boundary

h11 opens the PC RouteLM prototype gate. It is a readiness and evidence
contract, not a claim that a real local LLM exists yet.

Current completed status:

- h11-a is closed as a schema/readiness and supplied-component import gate.
- h11-b is closed as an artifact/provenance verifier gate.
- The supplied fixture can exercise the component contract, but it is still
  diagnostic-only.
- Supplied local artifact fixtures can verify generator, route-memory, scorer,
  decoder, NLG-smoke, benchmark, license, and provenance hashes, but they remain
  non-real.
- Real PC RouteLM / NLG remains blocked by h7 promotion, h10-j real
  teacher-source distillation, v08-l real external benchmark verification, and
  h9-g real HIP-backed speed evidence.

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

The readiness summary now also consumes h11-b artifact verification:

```text
prototype_artifact_chain_verified = 0|1
real_pc_routelm_artifact_verified = 0|1
prototype_artifact_action = ...
```

For local fixtures, h11-a can stay `diagnostic-prototype-only` while h11-b
keeps the real artifact claim blocked.

## h11-b Artifact Verifier

Entry points:

```bash
experiments/run_v11_pc_routelm_prototype_artifact_verifier.sh
experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh
experiments/test_v11_pc_routelm_prototype_artifact_import.sh
```

`V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV` can supply artifact evidence rows. The
h11-b verifier requires URI/hash evidence for:

- generator model artifact
- route-memory store
- candidate scoring implementation
- decoder binding
- NLG smoke result
- benchmark result
- license artifact
- provenance artifact

The default run blocks before component evidence exists:

```text
prototype_rows = 0
artifact_rows = 0
prototype_artifact_chain_verified = 0
real_pc_routelm_artifact_verified = 0
action = pc-routelm-components-missing
```

A supplied local fixture can pass hash-chain mechanics:

```text
prototype_rows = 1
artifact_rows = 1
matched_prototype_rows = 1
ready_rows = 1
prototype_artifact_chain_verified = 1
real_pc_routelm_artifact_verified = 0
action = pc-routelm-real-artifact-review-missing
```

The real claim is deliberately stricter than hash-chain mechanics:

- local `results/` fixture artifacts count as fixture evidence
- `real_prototype_declared=1` is not enough
- `fixture_or_synthetic_declared=0` is not enough
- routing and jump-neighbor rates must remain zero

## Blocking Conditions

h11-a/h11-b deliberately keep the real prototype blocked until these are true:

- route-memory default promotion is allowed
- teacher-distilled chunk quality is ready from real external labels
- external benchmark comparison is ready
- measured GPU speed evidence exists
- non-fixture prototype artifacts and provenance pass review

Until then, this remains an interface and evidence gate. It is not real natural
language generation solved, not GPU acceleration proven, and not a Transformer
replacement claim.
