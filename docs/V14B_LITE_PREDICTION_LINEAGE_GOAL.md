# V14-b-lite Prediction Lineage Goal

This document is the implementation goal for the next local/lightweight
RouteMemory step after v14-a.

v14-a proves that the runner can execute this chain in one run directory:

```text
official source acquisition
  -> source snapshot / query repo
  -> query and dataset materialization
  -> mmap RouteMemory store
  -> raw predictions
  -> evaluator output
  -> metrics / RouteQA / benchmark rows
  -> evidence / promotion rows
```

v14-b-lite must prove the next, narrower claim:

```text
Each promoted raw prediction is derived from RouteMemory mmap evidence,
not from an oracle answer, copied evaluator output, or raw-input extractor.
```

This is a local proof track, not a real external benchmark or release claim.
`candidate_external_benchmark_result_ready`, `real_external_benchmark_verified`,
and `real_release_package_ready` must remain `0`.

## Implementation Status

Implemented in `tools/routelm_benchmark_run` and covered by
`experiments/test_v14b_lite_prediction_lineage.sh`.

The closed smoke path enables:

- Stage 8-L: prediction lineage, no oracle/no extractor, and RouteMemory
  exact/hint/abstain prediction sources.
- Stage 8.2-L: shortcut/corruption negative suite covering wrong spans,
  corrupted route index/chunk offsets, raw-input shortcut attempts, oracle
  attempts, and input-extractor promotion blocks.
- Stage 8.5-L: 50-row public-codebase RouteQA-mini lightweight benchmark.
- Stage 9-L: tiny generator-hint NLG under `nlg/`, with generator hint rows and
  grounding rows proving the proposal hint is present in the generated answer
  text and unsupported claims remain zero.
- Stage 9.5-L: CPU-canonical RX 6900XT/32GB/500GB-lite resource envelope with
  HIP parity recorded as optional.
- Stage 10-Lite: one-PC reproducible run directory with source, dataset,
  explicit query alias, store, explicit mmap alias, prediction alias,
  evaluator, metrics, evidence, promotion, and resource artifacts hash-bound by
  `sha256sums.txt`, `run_layout_manifest.json`,
  `objective_requirements_manifest.json`, and `execution_chain_manifest.json`.

The smoke verifies `prediction_lineage_ready=1`,
`no_extractor_prediction_ready=1`,
`promoted_prediction_rows == promoted_route_memory_prediction_rows`,
`shortcut_negative_suite_ready=1`, `hash_clean_wrong_span_block=1`,
`corrupted_route_index_block=1`, `corrupted_chunk_offsets_block=1`,
`generator_hint_nlg_ready=1`, `resource_envelope_ready=1`,
`run_layout_ready=1`, `objective_requirements_ready=1`, and
`execution_chain_manifest_ready=1`, while leaving
`candidate_external_benchmark_result_ready=0`,
`real_external_benchmark_verified=0`, and `real_release_package_ready=0`.

## Pasteable Goal

```text
Implement v14-b-lite prediction lineage for the runner-owned RouteMemory
benchmark path.

Starting from the existing v14-a runner-owned execution chain, add a
prediction-lineage layer that proves each promoted raw prediction came from the
RouteMemory mmap value-byte path rather than from an oracle, evaluator output,
or raw input extractor.

Required runner outputs:

- predictions/prediction_lineage.jsonl
- predictions/prediction_source_summary.json
- traces/mmap_prediction_trace.jsonl
- traces/selected_candidate_trace.jsonl
- evidence/prediction_source_rows.csv
- evidence/route_memory_prediction_rows.csv
- evidence/evidence_span_to_prediction.csv

Required lineage fields per prediction:

- query_id
- prediction_id
- prediction_source
- oracle_prediction_used
- input_extractor_used
- route_memory_store_used
- mmap_read_used
- candidate_value_pos_used
- value_byte_read_used
- proposal_hint_used
- selected_candidate_id
- selected_candidate_rank
- chunk_id
- byte_offset
- byte_len
- evidence_span_sha256
- prediction_sha256
- prediction_text

Allowed prediction_source values:

- oracle
- input_extractor
- route_memory_exact
- route_memory_hint
- generator_hint
- abstain
- fallback

Promotion rules:

- oracle and input_extractor rows may appear only as baselines or blocked rows.
- promoted RouteQA / benchmark rows must use route_memory_exact,
  route_memory_hint, abstain, or fallback.
- present / multi_hop answers should be route_memory_exact or
  route_memory_hint.
- missing / near_miss rows should abstain or reject safely.
- any oracle or input_extractor source must force
  no_extractor_prediction_ready=0 and candidate promotion must remain blocked.

Required summary flags:

- prediction_lineage_ready=1
- prediction_source_summary_ready=1
- mmap_prediction_trace_ready=1
- route_memory_prediction_rows_ready=1
- evidence_span_to_prediction_ready=1
- no_extractor_prediction_ready=1
- oracle_prediction_used=0
- input_extractor_used=0
- route_memory_store_used=1
- mmap_read_used=1
- candidate_value_pos_used=1
- value_byte_read_used=1
- proposal_hint_used=1
- promoted_route_memory_prediction_rows == promoted_prediction_rows
- routing_trigger_rate=0.000000
- active_jump_rate=0.000000

Required test coverage:

- default v14 smoke verifies all new lineage artifacts and summary flags.
- direct canonical-query smoke uses bare routelm_benchmark_run and verifies the
  lineage artifacts through sha256sums.txt.
- live source snapshot smoke verifies the lineage artifacts while keeping
  runner-owned external benchmark rows at 5 and real/release flags at 0.
- corruption/shortcut preflight rejects oracle, input_extractor, hash-clean
  wrong span, corrupted route_index, and corrupted chunk_offsets rows from
  promotion.

Hardware budget:

- target hardware: RX 6900 XT 16GB VRAM, RAM 32GB, SSD 500GB.
- CPU remains canonical.
- HIP remains optional parity only.
- first pass should keep run directory below 5GB and RAM peak below 8GB.
- do not claim GPU speedup, real external benchmark verification, or release
  readiness.
```

## Research Rationale

v14-a closes the runner-owned execution chain, but raw predictions can still be
criticized as "too close to an extractor" unless the prediction source is
explicitly bound to the mmap store and selected candidate span.

v14-b-lite should therefore answer this reviewer question:

```text
Did the prediction come from the RouteMemory value-byte path, or did it come
from an oracle/input shortcut?
```

The correct next proof is not a bigger benchmark and not a bigger generator.
It is lineage: source row, candidate row, mmap read, byte span hash, prediction
hash, evaluator row, and promotion decision all bound together.

## Scope

### In Scope

- Extend `tools/routelm_benchmark_run`.
- Add prediction lineage artifacts under `predictions/`, `traces/`, and
  `evidence/`.
- Bind lineage artifacts into:
  - `evidence/evidence_packet.csv`
  - `evidence/run_layout_manifest.json`
  - `evidence/objective_requirements_manifest.json`
  - `evidence/execution_chain_manifest.json`
  - `sha256sums.txt`
- Add summary fields and decision rows for lineage readiness.
- Update `experiments/test_v14_real_query_result_evaluator_runner.sh`.
- Keep all real/release/candidate flags blocked unless independent external
  verification exists.

### Out of Scope

- Full RULER/LongBench runs.
- 3B-14B generator integration.
- GPU acceleration claims.
- Real external benchmark verification.
- Release package readiness.
- Default promotion of learned sparse routing.

## Artifact Contract

### `predictions/prediction_lineage.jsonl`

One row per raw prediction.

Required fields:

```json
{
  "query_id": "q_function_main_v02",
  "prediction_id": "p_q_function_main_v02",
  "prediction_source": "route_memory_exact",
  "oracle_prediction_used": false,
  "input_extractor_used": false,
  "route_memory_store_used": true,
  "mmap_read_used": true,
  "candidate_value_pos_used": true,
  "value_byte_read_used": true,
  "proposal_hint_used": true,
  "selected_candidate_id": "c_q_function_main_v02_0001",
  "selected_candidate_rank": 1,
  "chunk_id": "src/v02_pre/main_v02.cpp:8",
  "byte_offset": 32202,
  "byte_len": 61,
  "evidence_span_sha256": "sha256:...",
  "prediction_sha256": "sha256:...",
  "prediction_text": "src/v02_pre/main_v02.cpp:8"
}
```

Missing and near-miss queries may use:

```text
prediction_source=abstain
route_memory_store_used=true
mmap_read_used=false
candidate_value_pos_used=false
value_byte_read_used=false
proposal_hint_used=true
```

Those rows are not evidence-span predictions, but they are still lineage-bound
because the route memory store and negative decision are recorded.

### `traces/mmap_prediction_trace.jsonl`

One row per mmap evidence read used by a prediction.

Required fields:

```text
query_id
prediction_id
route_key
chunk_id
route_index_offset
chunk_offset_row
byte_offset
byte_len
read_sha256
read_ready
prediction_source
```

### `traces/selected_candidate_trace.jsonl`

One row per selected candidate.

Required fields:

```text
query_id
prediction_id
candidate_id
candidate_rank
candidate_source
candidate_value_pos
candidate_chunk_id
candidate_byte_offset
candidate_byte_len
candidate_score
selected
selection_reason
```

### `evidence/prediction_source_rows.csv`

One row per prediction source decision.

Required columns:

```text
query_id
prediction_id
prediction_source
promotion_eligible
oracle_prediction_used
input_extractor_used
route_memory_store_used
mmap_read_used
candidate_value_pos_used
value_byte_read_used
proposal_hint_used
blocker
```

### `evidence/route_memory_prediction_rows.csv`

One row per prediction that is actually RouteMemory-derived.

Required columns:

```text
query_id
prediction_id
prediction_source
chunk_id
byte_offset
byte_len
evidence_span_sha256
prediction_sha256
route_memory_prediction_ready
```

### `evidence/evidence_span_to_prediction.csv`

One row per span-to-prediction binding.

Required columns:

```text
query_id
prediction_id
chunk_id
evidence_span_sha256
prediction_sha256
evaluator_row_bound
routeqa_row_bound
benchmark_row_bound
```

## Prediction Source Semantics

### `oracle`

The answer is copied from labels, evaluator expected output, or benchmark
oracle field. This is allowed only in explicit baseline artifacts. It must not
be promotion eligible.

### `input_extractor`

The answer is extracted from raw input text without proving the route memory
value-byte path. This is allowed only as a baseline or blocked row. It must not
be promotion eligible.

### `route_memory_exact`

The prediction is exactly the value read from the selected RouteMemory span.
This is the preferred source for present symbol/file/line answers.

### `route_memory_hint`

The prediction is derived from a RouteMemory span plus a bounded proposal hint.
The span hash and prediction hash must both be recorded.

### `generator_hint`

Reserved for v15-lite. It may appear only when a generator consumes a
RouteMemory proposal hint and emits a grounded answer. It is not required for
v14-b-lite.

### `abstain`

The system safely abstains for missing, near-miss, or corrupted inputs. This is
promotion eligible for missing/near-miss labels when the evaluator expects an
abstention.

### `fallback`

A non-oracle fallback path. It must declare the fallback reason and must not
hide extractor use.

## Readiness Flags

Add these to `run_summary.csv`, `run_manifest.json` where appropriate, and
`evidence/objective_requirements_manifest.json`:

```text
prediction_lineage_ready
prediction_source_summary_ready
mmap_prediction_trace_ready
selected_candidate_trace_ready
prediction_source_rows_ready
route_memory_prediction_rows_ready
evidence_span_to_prediction_ready
no_extractor_prediction_ready
oracle_prediction_used
input_extractor_used
route_memory_store_used
mmap_read_used
candidate_value_pos_used
value_byte_read_used
proposal_hint_used
promoted_prediction_rows
promoted_route_memory_prediction_rows
blocked_oracle_prediction_rows
blocked_input_extractor_prediction_rows
```

Success requires:

```text
prediction_lineage_ready=1
prediction_source_summary_ready=1
mmap_prediction_trace_ready=1
selected_candidate_trace_ready=1
prediction_source_rows_ready=1
route_memory_prediction_rows_ready=1
evidence_span_to_prediction_ready=1
no_extractor_prediction_ready=1
oracle_prediction_used=0
input_extractor_used=0
route_memory_store_used=1
promoted_prediction_rows == promoted_route_memory_prediction_rows
candidate_external_benchmark_result_ready=0
real_external_benchmark_verified=0
real_release_package_ready=0
```

## Test Plan

### Static checks

```bash
python3 -m py_compile tools/routelm_benchmark_run
bash -n routelm_benchmark_run \
  experiments/test_v14_real_query_result_evaluator_runner.sh \
  experiments/run_v14_real_query_result_evaluator_runner.sh
```

### Focused smoke

```bash
bash experiments/test_v14_real_query_result_evaluator_runner.sh
```

Must verify:

```text
prediction_lineage_ready=1
no_extractor_prediction_ready=1
route_memory_prediction_rows_ready=1
candidate_external_benchmark_result_ready=0
real_external_benchmark_verified=0
real_release_package_ready=0
```

### Live source snapshot smoke

```bash
V14_LIVE_SOURCE_SNAPSHOT_QUERY_TEST=1 \
  bash experiments/test_v14_real_query_result_evaluator_runner.sh
```

Must keep the existing v14-a values:

```text
external_benchmark_rows=5
external_benchmark_execution_chain_ready=1
runner_owned_external_benchmark_result_ready=1
```

and add:

```text
prediction_lineage_ready=1
no_extractor_prediction_ready=1
```

### Negative preflight

Add focused corruption cases before scaling:

```text
oracle_prediction_row
input_extractor_prediction_row
hash_clean_wrong_span
corrupted_route_index
corrupted_chunk_offsets
raw_input_contains_answer_but_store_masked
store_contains_answer_but_raw_input_masked
```

Expected result:

```text
promotion_eligible=0
no_extractor_prediction_ready=0 for extractor/oracle cases
hash_clean_wrong_span_block=1
corrupted_route_index_block=1
corrupted_chunk_offsets_block=1
```

## Local Hardware Budget

Target profile:

```text
GPU: RX 6900 XT, 16GB VRAM
RAM: 32GB
SSD: 500GB
Backend: CPU canonical
HIP: optional parity only
```

First-pass budgets:

```text
queries: 7 built-in -> 10 -> 30 -> 50
run directory: <= 5GB
RAM peak: <= 8GB
VRAM peak: 0-1GB for CPU-only
store: current small store first; do not chase 100GB stores
```

Do not claim:

```text
GPU speedup
frontier local LLM
real external benchmark verification
release readiness
```

## Implementation Order

1. Add lineage rows for the existing 7-query RouteQA path.
2. Bind lineage artifacts into manifests and sha256sums.
3. Verify no oracle/input-extractor promotion.
4. Add selected-candidate and mmap trace artifacts.
5. Add negative preflight cases.
6. Scale query count only after lineage is clean.

## Completion Definition

v14-b-lite is complete when a fresh run proves:

```text
source_chain_evidence_mirror_ready=1
objective_requirements_ready=1
prediction_lineage_ready=1
no_extractor_prediction_ready=1
route_memory_prediction_rows_ready=1
promoted_prediction_rows == promoted_route_memory_prediction_rows
candidate_external_benchmark_result_ready=0
real_external_benchmark_verified=0
real_release_package_ready=0
```

and the focused plus live v14 smoke tests pass.
