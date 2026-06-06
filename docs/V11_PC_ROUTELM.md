# h11 PC RouteLM / NLG Prototype Boundary

h11 opens the PC RouteLM prototype gate. It is a readiness and evidence
contract, not a claim that a real local LLM exists yet.

Current completed status:

- h11-a is closed as a schema/readiness and supplied-component import gate.
- h11-b is closed as an artifact/provenance verifier gate.
- h11-c is closed as an NVMe-resident RouteMemory store artifact smoke.
- h11-d is closed as a diagnostic PC RouteLM small-generator NLG smoke.
- The supplied fixture can exercise the component contract, but it is still
  diagnostic-only.
- Supplied local artifact fixtures can verify generator, route-memory, scorer,
  decoder, NLG-smoke, benchmark, license, and provenance hashes, but they remain
  non-real.
- The h11-c store smoke creates and verifies a concrete route-memory store
  bundle with page table, chunk offsets, sha256 manifest, route lookup, and
  candidate span reads.
- The h11-d smoke consumes the h11-c store substrate and writes a generated
  NLG transcript/result artifact while verifying grounding, citation, missing
  abstain, and wrong-answer guardrails.
- Real PC RouteLM / NLG remains blocked by h7-c promotion review, h10-r/h10-s
  real teacher-source plus source-verified scorer evidence, v08-ab real
  external benchmark review/publication evidence, and h9-h real HIP/NVMe
  workload-speed evidence. v12 audits the same stack and keeps PC RouteLM
  release claims at diagnostic artifact packaging only.

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

## h11-c NVMe RouteMemory Store

Entry points:

```bash
experiments/run_v11_nvme_route_memory_store.sh
experiments/test_v11_nvme_route_memory_store.sh
experiments/test_v11_nvme_route_memory_artifact.sh
```

h11-c creates a deterministic store under `results/.../routelm/store` with:

- `route_memory_store.bin`
- `route_index.bin`
- `chunk_pages.bin`
- `chunk_offsets.bin`
- `chunk_credit.bin`
- `page_table.bin`
- `manifest.json`
- `sha256sums.txt`

The smoke verifies that the sha256 manifest matches all store files, route
lookup returns the expected chunks, candidate span reads match byte offsets, and
missing queries abstain:

```text
route_memory_artifact_chain_verified = 1
route_lookup_works = 1
candidate_span_read_works = 1
span_exact = 1.000000
chunk_exact = 1.000000
missing_abstain = 1.000000
wrong_answer_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

The artifact guard also checks that a corrupted store file blocks with
`nvme-route-memory-artifact-hash-mismatch`. h11-c is therefore a concrete
RouteMemory store/artifact smoke, not a real PC RouteLM product or external
benchmark claim.

The v08-ab codebase-mini benchmark instrumentation now consumes this h11-c
store as its RouteMemory substrate. That downstream smoke verifies source,
dataset, baseline, result, and sha256 artifacts for real local repository files
while keeping `real_external_benchmark_verified=0`, so h11-c remains storage
instrumentation rather than a product or benchmark claim.

## h11-d PC RouteLM NLG Smoke

Entry points:

```bash
experiments/run_v11_pc_routelm_nlg_smoke.sh
experiments/test_v11_pc_routelm_nlg_smoke.sh
```

h11-d adds the first generator-facing smoke above the verified h11-c store. It
does not claim a real local LLM. The generated fixture writes:

- `artifacts/routelm/nlg/smoke_transcript.jsonl`
- `artifacts/routelm/nlg/result_summary.json`
- an NLG metric CSV consumed by the gate

The smoke verifies:

```text
diagnostic_artifact_ready = 1
teacher_off_inference = 1
retrieved_evidence_used = 1
evidence_binding_ready = 1
answer_grounded_rate = 1.000000
span_citation_accuracy = 1.000000
span_exact = 1.000000
chunk_exact = 1.000000
missing_abstain = 1.000000
wrong_answer_rate = 0.000000
pc_routelm_nlg_smoke_ready = 1
real_pc_routelm_nlg_verified = 0
action = diagnostic-nlg-smoke-ready
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

`V11_PC_ROUTELM_NLG_SMOKE_CSV` can supply alternate NLG rows. The guard rejects
bad grounding/wrong-answer rows and malformed row widths. Real NLG remains
blocked unless non-fixture generator artifacts, non-fixture transcript/result
evidence, real artifact verification, promotion, teacher-source, benchmark, and
speed gates all line up.

v12 consumes the h11-c/h11-d boundary in the paper/release claim audit:

```text
h11c_route_memory_artifact_chain_verified = 1
h11c_real_pc_routelm_artifact_verified = 0
h11d_pc_routelm_nlg_smoke_ready = 1
h11d_real_pc_routelm_nlg_verified = 0
release_claim = diagnostic-artifact-package-only
forbidden_frontier_pc_llm_claim = blocked
```

## Blocking Conditions

h11-a/h11-b/h11-c/h11-d deliberately keep the real prototype blocked until these are true:

- h7-c promotion review allows route-memory default promotion
- teacher-distilled chunk quality is ready from real external labels
- external benchmark comparison is backed by real reviewed evidence
- real CPU/HIP/NVMe workload-speed evidence exists
- non-fixture prototype artifacts, NLG transcripts/results, and provenance pass
  review
- v12 is rerun and moves beyond diagnostic artifact packaging

Until then, this remains an interface and evidence gate. It is not real natural
language generation solved, not GPU acceleration proven, and not a Transformer
replacement claim.
