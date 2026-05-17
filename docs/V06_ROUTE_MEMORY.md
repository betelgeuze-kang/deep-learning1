# v0.6 / h6 Route-memory Phase

The h6 phase starts after the h5 route-quality closure. Its job is to move from
single-byte value-bearing route hints toward span/chunk route memory without
reviving jump-neighbor topology replacement.

Current hard boundary:

```text
live path:
  candidate value_pos -> value byte read -> proposal hint

forbidden promotion:
  remote node as neighbor / jump-neighbor replacement
```

## h6-a Span Boundary Decision

`h6-a` passes as route-memory span-boundary instrumentation. It does not solve
span routing, chunk routing, learned routing, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/test_v06_route_memory_span_boundary.sh
```

The fixture contains multi-byte values:

```text
@37000=HELLO;
@37001=WORLD;
?37000=HELLO.
?37001=WORLD.
```

Reference check:

```text
kv_record_count = 2
kv_query_count = 2
route_hint_query_count = 2
kv_query_hit_rate = 1.000000
route_hint_applied_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
the current route-memory stack treats each key/value query as a first-byte
route hint. Multi-byte values are present in the fixture, but the active h5
parser exposes one query hint per key, not one hint per value-span offset.

This is the correct h6 starting point: before claiming span/chunk memory, the
single-byte boundary is explicit and tested.

## Proposed h6 Progression

1. `h6-a span boundary`: document and guard the current single-byte route-memory
   boundary.
2. `h6-b exact span parser`: add value-span metadata and query offset hints
   while preserving the same value-bearing proposal path.
3. `h6-c exact span KV scale`: solve exact symbolic multi-byte span recall under the
   existing route-hint dynamics.
4. `h6-d span hash candidates`: move from exact span lookup to hashed candidate
   span retrieval.
5. `h6-e chunk-quality diagnostics`: extend candidate-quality metrics from
   value bytes to span/chunk candidate sets.

Do not claim:

```text
learned sparse routing solved
chunk-level long-context retrieval solved
Transformer replacement
```

until span/chunk routing works without symbolic upper-bound shortcuts and is
validated against external baselines.

## h6-b Exact Span Parser Decision

`h6-b` passes as exact span parser instrumentation and first exact-span
mitigation. It does not solve chunk routing, learned routing, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-span-hints 0|1
experiments/test_v06_route_memory_span_exact.sh
```

Default behavior remains unchanged:

```text
--route-span-hints 0
```

When enabled with exact KV routing:

```text
--route-mode hint-kv-exact
--route-span-hints 1
```

the parser expands a multi-byte value into one route hint per value-span
offset. For the `HELLO` / `WORLD` fixture this changes the exposed route hints
from:

```text
kv_query_count = 2
route_hint_query_count = 2
```

to:

```text
kv_query_count = 10
route_hint_query_count = 10
```

The route mechanism is still the same value-bearing path:

```text
candidate value_pos -> value byte read -> proposal hint
```

No remote-neighbor replacement is introduced.

## h6-c Exact Span Scale Decision

`h6-c` passes as exact span scale diagnostics. It does not solve hashed span
retrieval, chunk routing, learned routing, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_exact_scale.sh
experiments/test_v06_route_memory_span_exact_scale.sh
```

The runner compares:

```text
first-byte:
  --route-span-hints 0

span:
  --route-span-hints 1
```

over exact symbolic KV fixtures with variable key count and value length.

Smoke fixture:

```text
key_count = 2
value_len = 5
first-byte route_hint_query_count = 2
span route_hint_query_count = 10
```

Standard scale readout:

```text
rows = 8
first_byte_rows = 4
span_rows = 4
first_byte_qacc_mean = 1.000000
span_qacc_mean = 1.000000
first_byte_query_count_mean = 3.000000
span_query_count_mean = 12.000000
span_expected_match_rate = 1.000000
span_hit_rate_mean = 1.000000
span_applied_rate_mean = 1.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
the exact span parser scales from the single h6-b fixture into a small
key-count/value-length matrix while preserving the same route mechanism:

```text
candidate value_pos -> value byte read -> proposal hint
```

This remains exact symbolic span routing, not learned chunk retrieval.

## h6-d Span Hash Candidate Decision

`h6-d` passes as span hash candidate instrumentation and controlled symbolic
span-candidate mitigation. It does not solve chunk routing, learned routing,
source-credit robustness, wrong-candidate robustness, fallback robustness, or
long-context retrieval.

The slice adds:

```text
experiments/test_v06_route_memory_span_hash.sh
```

When both options are enabled:

```text
--route-mode hint-kv-hash
--route-span-hints 1
```

hash bucket records now retain value-span offsets. Query value spans are
expanded into one routed candidate lookup per offset, and each offset only
compares against candidates from the same record offset. This preserves the
existing value-bearing route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke fixture:

```text
@37000=HELLO;
@37001=WORLD;
?37000=HELLO.
?37001=WORLD.
```

Reference smoke readout:

```text
kv_record_count = 2
kv_query_count = 10
route_hint_query_count = 10
route_candidate_query_count = 10
kv_query_hit_rate = 1.000000
route_hint_applied_rate = 1.000000
route_candidate_recall_rate = 1.000000
route_candidate_top1_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h6-d moves the span mechanism from exact symbolic lookup to hashed symbolic
candidate lookup while keeping per-offset candidate recall/top1 exact in the
no-collision smoke. This is still controlled symbolic span routing, not learned
chunk retrieval.
