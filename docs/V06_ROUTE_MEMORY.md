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
2. `h6-b span parser`: add value-span metadata and query offset hints while
   preserving the same value-bearing proposal path.
3. `h6-c exact span KV`: solve exact symbolic multi-byte span recall under the
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
