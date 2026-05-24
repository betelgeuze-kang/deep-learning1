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

## Current h6 Progression

1. `h6-a span boundary`: document and guard the current single-byte route-memory
   boundary.
2. `h6-b exact span parser`: add value-span metadata and query offset hints
   while preserving the same value-bearing proposal path.
3. `h6-c exact span KV scale`: solve exact symbolic multi-byte span recall under the
   existing route-hint dynamics.
4. `h6-d span hash candidates`: move from exact span lookup to hashed candidate
   span retrieval.
5. `h6-e span hash scale diagnostics`: scale hashed span-candidate lookup over
   key-count/value-length/hash-bit arms before moving to chunk-quality metrics.
6. `h6-f..h6-i`: expose span ambiguity, learned-like source collapse, recall/top1
   separation, and coherent wrong-key span selection.
7. `h6-j..h6-k`: test non-key-shape prefix and same-key-support ranking probes;
   both are useful diagnostics but not sufficient replacements for key-shape.
8. `h6-l..h6-m`: add and scale `span-local-energy`, the first non-key-shape
   span-record scorer with limited positive signal.
9. `h6-n..h6-p`: compose local-energy with h5 candidate-quality presets, then
   record byte-qacc versus span-exact policy selection as separate objectives.
10. `h6-q`: add a span-first guardrail over the h6-p policy artifact.
11. `h6-r`: scale the guardrail over weak and harsher learned-like source
    degradation.
12. `h6-s`: calibrate an adaptive utility guardrail over qacc loss versus span
    exact-match gain.

Current checkpoint:

```text
h6-s passes as adaptive guardrail calibration diagnostics.
h7 quick closure includes h6-s.
h9 quick closure passes with HIP parity optional.
```

Next h6 boundary:

```text
h6-t should scale the `utility-w0p75` adaptive guardrail across broader
degradation regimes while reporting byte qacc and span exact-match separately.
```

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

## h6-e Span Hash Scale Decision

`h6-e` passes as span hash scale diagnostics. It does not solve chunk routing,
learned routing, source-credit robustness, wrong-candidate robustness, fallback
robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_hash_scale.sh
experiments/test_v06_route_memory_span_hash_scale.sh
```

The runner scales h6-d over key count, value length, and hash-bit settings while
recording span-level candidate recall/top1, bucket load, collision rate, qacc,
and the existing jump-neighbor inactivity guards.

Smoke readout:

```text
key_count = 2
value_len = 5
hash_bits = 16
route_hint_query_count = 10
route_candidate_query_count = 10
route_candidate_recall_rate = 1.000000
route_candidate_top1_rate = 1.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Standard scale readout:

```text
rows = 8
qacc_mean = 1.000000
query_count_mean = 12.000000
expected_match_rate = 1.000000
hit_rate_mean = 1.000000
applied_rate_mean = 1.000000
recall_mean = 1.000000
top1_mean = 1.000000
bucket_load_mean = 1.000000
collision_rate_mean = 0.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
h6-e is a span-candidate scale guard for the symbolic hashed path. It verifies
that offset-aware hash candidates preserve exact per-offset recall/top1 in the
current no-collision matrix. It is still not learned chunk retrieval; the next
real boundary is chunk-quality diagnostics over ambiguous or learned-like span
candidate sets.

## h6-f Span Ambiguity / Collision Decision

`h6-f` passes as span collision / ambiguity diagnostics and actionable split.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_ambiguity.sh
experiments/test_v06_route_memory_span_ambiguity.sh
```

The smoke intentionally lowers hash bits while keeping `--route-span-hints 1`.
It compares a collision-free control, a low-bit ambiguous bucket, a larger
`K_route`, a symbolic key-shape scorer, and the current candidate-quality
default preset.

Reference smoke readout:

```text
high-bits-control:
  qacc = 1.000000
  collision = 0.000000
  recall = 1.000000
  top1 = 1.000000

low-bits-k4:
  qacc = 0.237500
  collision = 1.000000
  recall = 0.500000
  top1 = 0.125000

low-bits-k16:
  qacc = 0.293750
  recall = 1.000000
  top1 = 0.125000

low-bits-keyshape:
  qacc = 1.000000
  recall = 1.000000
  top1 = 1.000000

low-bits-quality:
  qacc = 0.293750
  recall = 1.000000
  top1 = 0.125000
```

Interpretation:
hash collisions create a real span-candidate quality problem. Increasing
`K_route` recovers recall, but not top1 or qacc. The current byte-level
candidate-quality preset does not fix this span ambiguity by itself. The
symbolic `key-shape` scorer resolves the controlled ambiguity, so the next
learned span step should focus on source/candidate features that can replace
that symbolic upper bound.

The route mechanism remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

and `routing_trigger_rate = active_jump_rate = 0.000000`.

## h6-g Learned-like Span-source Stress Decision

`h6-g` passes as learned-like span-source stress instrumentation. It does not
solve learned chunk retrieval, source-credit robustness, wrong-candidate
robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_learned_source.sh
experiments/test_v06_route_memory_span_learned_source.sh
```

The implementation first makes learned/source fallback paths span-offset aware:
`KVRecord` now carries `value_len`, and learned-code / fallback source candidate
positions use the query's value-span offset instead of always using the first
value byte. This keeps the route-memory invariant intact:

```text
candidate value_pos -> value byte read -> proposal hint
```

Reference smoke:

```text
clean-route-code-span:
  qacc = 0.987500
  span_exact = 0.937500
  selected_correct_key = 1.000000
  route_decode = 1.000000
  recall = 1.000000
  top1 = 1.000000
  route_collision = 0.000000

weak-route-code-k4:
  qacc = 0.606250
  span_exact = 0.281250
  selected_correct_key = 0.250000
  route_decode = 0.000000
  recall = 0.843750
  top1 = 0.250000
  route_collision = 0.750000

weak-route-code-k16:
  qacc = 0.637500
  span_exact = 0.375000
  recall = 1.000000
  top1 = 0.250000

weak-route-code-quality:
  qacc = 0.637500
  span_exact = 0.375000
  recall = 1.000000
  top1 = 0.250000
```

Interpretation:
clean route-code identity can support span-offset route hints, but weakened
route-code identity creates a learned-like source failure: decode collapses,
bucket collisions appear, top1/qacc drop, and span exact-match falls sharply.
Increasing `K_route` recovers recall, but not top1 or span exact-match. The
current byte-level candidate-quality preset remains neutral in this span
learned-source stress. The next span step should focus on span-level candidate
quality and consistency features rather than treating recall recovery as
sufficient.

`routing_trigger_rate = active_jump_rate = 0.000000`, so jump-neighbor
replacement remains closed.

## h6-h Span-level Candidate-quality Diagnostics Decision

`h6-h` passes as span-level candidate-quality diagnostics and actionable split.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_quality_diagnostics.sh
experiments/test_v06_route_memory_span_quality_diagnostics.sh
```

It also adds span-level metrics:

```text
route_span_candidate_all_recall_rate
route_span_candidate_all_top1_rate
route_span_candidate_offset_recall_rate
route_span_candidate_offset_top1_rate
route_span_exact_match_rate
route_span_selected_key_consistency_rate
route_span_selected_correct_key_rate
```

Reference smoke:

```text
clean-route-code-span:
  qacc = 1.000000
  span_exact = 1.000000
  all_recall = 1.000000
  all_top1 = 1.000000

weak-k4:
  qacc = 0.518750
  span_exact = 0.250000
  all_recall = 0.718750
  all_top1 = 0.250000

weak-k16:
  qacc = 0.556250
  span_exact = 0.250000
  all_recall = 1.000000
  all_top1 = 0.250000

weak-quality:
  qacc = 0.556250
  span_exact = 0.250000
  all_recall = 1.000000
  all_top1 = 0.250000

weak-keyshape:
  qacc = 1.000000
  span_exact = 1.000000
  all_recall = 1.000000
  all_top1 = 1.000000
```

Interpretation:
span recall recovery is not enough. Under weak route-code identity, larger
`K_route` restores all-span recall but leaves all-span top1 and span exact-match
low. The current byte-level candidate-quality preset remains neutral. The
symbolic `key-shape` scorer recovers span-level top1/exact-match, so the next
learned route-memory step should replace that symbolic upper bound with
span-level ranking or consistency features.

## h6-i Span Candidate-quality Gap Decision

`h6-i` passes as span candidate-quality gap diagnostics and actionable split.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_candidate_quality_gap.sh
experiments/test_v06_route_memory_span_candidate_quality_gap.sh
```

It extends span diagnostics with candidate-key quality metrics:

```text
route_span_candidate_correct_key_share_mean
route_span_candidate_unique_key_count_mean
route_span_candidate_key_entropy_mean
route_span_candidate_top_key_consistency_rate
route_span_candidate_top_key_correct_rate
route_span_candidate_coherent_wrong_top_key_rate
```

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  correct_key_share = 0.503125
  unique_key_count = 2.750000
  key_entropy = 1.238921
  top_key_consistency = 1.000000
  top_key_correct = 0.250000
  coherent_wrong_top_key = 0.750000

weak-base-default:
  qacc = 0.625000
  span_exact = 0.281250

weak-hybrid-safe:
  qacc = 0.368750
  span_exact = 0.250000

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
  correct_key_share = 1.000000
  key_entropy = 0.000000
  coherent_wrong_top_key = 0.000000
```

Interpretation:
the weak route-code source recovers all-span recall, but it often coherently
selects the wrong key across the whole span. That is different from random
per-offset noise: `top_key_consistency` is high, while `top_key_correct` is
low. The byte-level candidate-quality presets do not repair this span-level
record-ranking failure, and `hybrid-safe` can be worse in this stress. Symbolic
`key-shape` remains an upper bound because it collapses candidate-key entropy
and restores correct-key share/top1. The next learned route-memory step should
target span-record ranking or consistency features, not only byte-level
candidate weighting.

## h6-j Span-prefix Ranking Decision

`h6-j` passes as span-prefix ranking diagnostics and negative/limited
instrumentation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-candidate-score span-prefix
experiments/run_v06_route_memory_span_prefix_ranking.sh
experiments/test_v06_route_memory_span_prefix_ranking.sh
```

`span-prefix` ranks same-bucket span candidates by agreement between the
already-visible query span prefix and the candidate record prefix. It does not
use `key-shape`, does not inspect the current target byte, and does not change
route topology.

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-span-prefix:
  qacc = 0.587500
  span_exact = 0.218750
  all_recall = 1.000000
  all_top1 = 0.218750
  coherent_wrong_top_key = 0.593750

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
prefix agreement alone is not enough. It preserves all-span recall and reduces
coherent wrong-key selection somewhat, but qacc, all-span top1, and span
exact-match regress in this smoke. This is a useful negative result: the next
span route-memory step needs a stronger learned record-ranking signal than
visible prefix consistency, while `key-shape` remains a symbolic upper bound
only.

## h6-k Span-key-support Ranking Decision

`h6-k` passes as span-key-support ranking diagnostics and neutral
instrumentation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
--route-candidate-score span-key-support
experiments/run_v06_route_memory_span_key_support_ranking.sh
experiments/test_v06_route_memory_span_key_support_ranking.sh
```

`span-key-support` is a non-`key-shape` record-level probe. For each query span,
it counts which candidate record keys appear across the recovered offset
candidates, then ranks candidates whose key has broader offset support first.
It does not inspect the target byte and does not change route topology.

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-span-key-support:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  coherent_wrong_top_key = 0.750000

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
cross-offset key support is wired but neutral on the current weak route-code
stress. The failure mode is coherent: the same wrong key can have strong
support across offsets, so support consistency alone does not distinguish the
correct record. This reinforces the h6-i/h6-j conclusion that the next
route-memory step needs a stronger learned record-quality signal than recall,
visible prefix agreement, or same-key support. Symbolic `key-shape` remains an
upper-bound diagnostic only.

## h6-l Span-local-energy Ranking Decision

`h6-l` passes as span-local-energy ranking diagnostics and limited mitigation.
It does not solve learned chunk retrieval, source-credit robustness,
wrong-candidate robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
--route-candidate-score span-local-energy
experiments/run_v06_route_memory_span_local_energy_ranking.sh
experiments/test_v06_route_memory_span_local_energy_ranking.sh
```

`span-local-energy` scores each candidate record by applying its full value
span to the corresponding query span positions under the existing local
energy, excluding route-hint energy. It does not inspect target bytes, does not
use `key-shape`, and does not change route topology.

Reference smoke:

```text
weak-k16:
  qacc = 0.625000
  span_exact = 0.281250
  all_recall = 1.000000
  all_top1 = 0.250000
  correct_key_share = 0.503125
  key_entropy = 1.238921
  coherent_wrong_top_key = 0.750000

weak-span-local-energy:
  qacc = 0.675000
  span_exact = 0.406250
  all_recall = 1.000000
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081
  coherent_wrong_top_key = 0.593750

weak-keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
local-energy span scoring is the first non-`key-shape` record-ranking probe in
this h6 series that improves qacc and span exact-match on the weak route-code
stress. It also increases correct-key share and reduces key entropy. The result
is still limited: coherent wrong-key selection remains, and symbolic
`key-shape` is still far above it. The next step should scale this scorer over
keys/seeds/noise and test whether combining local-energy record ranking with
candidate-quality weighting can close more of the span exact-match gap.

## h6-m Span-local-energy Scale Decision

`h6-m` passes as span-local-energy scale/stability diagnostics and limited
mitigation. It does not solve learned chunk retrieval, source-credit
robustness, wrong-candidate robustness, fallback robustness, or long-context
retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_scale.sh
experiments/test_v06_route_memory_span_local_energy_scale.sh
```

The standard runner compares weak insertion-order ranking, `span-local-energy`,
and symbolic `key-shape` over a small key/seed matrix.

Reference standard aggregate:

```text
rows = 12
groups = 4
weak_qacc_mean = 0.546094
local_energy_qacc_mean = 0.571875
keyshape_qacc_mean = 0.984375
local_energy_qacc_delta_mean = 0.025781

weak_span_exact_mean = 0.273438
local_energy_span_exact_mean = 0.378906
keyshape_span_exact_mean = 0.921875
local_energy_span_exact_delta_mean = 0.105469

weak_all_recall_mean = 0.992188
local_energy_all_recall_mean = 0.992188
weak_all_top1_mean = 0.277344
local_energy_all_top1_mean = 0.382812

weak_correct_key_share_mean = 0.492722
local_energy_correct_key_share_mean = 0.565547
weak_key_entropy_mean = 1.406354
local_energy_key_entropy_mean = 1.200587
weak_coherent_wrong_mean = 0.722656
local_energy_coherent_wrong_mean = 0.617188
```

Interpretation:
the h6-l single-smoke lift is not just a one-row artifact. Across the small
key/seed matrix, local-energy span ranking preserves all-span recall while
improving qacc, span exact-match, all-span top1, correct-key share, entropy,
and coherent-wrong-key rate. The effect is still limited and remains far below
symbolic `key-shape`, especially as key count rises. The next span step should
combine local-energy record ranking with route-quality candidate weighting or
scale it over harsher learned-like source degradation.

## h6-n Span-local-energy Composition Decision

`h6-n` passes as span-local-energy / candidate-quality composition diagnostics
and mixed limited mitigation. It does not solve learned chunk retrieval,
source-credit robustness, wrong-candidate robustness, fallback robustness, or
long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_composition.sh
experiments/test_v06_route_memory_span_local_energy_composition.sh
```

It compares weak insertion-order ranking, `span-local-energy`, `span-local-energy`
plus h5 candidate-quality presets, and symbolic `key-shape`.

Reference smoke:

```text
weak:
  qacc = 0.625000
  span_exact = 0.281250
  all_top1 = 0.250000
  correct_key_share = 0.503125
  key_entropy = 1.238921

local-energy:
  qacc = 0.675000
  span_exact = 0.406250
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081

local-energy-base:
  qacc = 0.675000
  span_exact = 0.406250
  all_top1 = 0.406250
  correct_key_share = 0.631250
  key_entropy = 0.862081

local-energy-hybrid:
  qacc = 0.631250
  span_exact = 0.593750
  all_top1 = 0.593750
  correct_key_share = 0.768229
  key_entropy = 0.510620

keyshape:
  qacc = 0.993750
  span_exact = 0.968750
  all_top1 = 1.000000
```

Interpretation:
composition exposes a real span-vs-byte objective tradeoff. `base-default`
does not change the local-energy arm in this smoke, while `hybrid-safe`
substantially improves span exact-match, all-span top1, correct-key share, and
entropy but gives back much of the byte-level qacc gain. That means the next
span-memory step should evaluate span exact-match as a first-class objective
instead of selecting policies only by byte qacc. This is still not learned
chunk retrieval solved, and `key-shape` remains the symbolic upper bound.

## h6-o Span-local-energy Policy Calibration Decision

`h6-o` passes as span-local-energy policy calibration diagnostics. It does not
solve learned chunk retrieval, source-credit robustness, wrong-candidate
robustness, fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_policy.sh
experiments/test_v06_route_memory_span_local_energy_policy.sh
```

It reuses the h6-n composition arms and writes an explicit objective-policy
summary:

```text
objective,selected_scenario,qacc,span_exact
byte-qacc,local-energy,0.675000,0.406250
span-exact,local-energy-hybrid,0.631250,0.593750
balanced,local-energy-hybrid,0.631250,0.593750
```

Reference aggregate:

```text
objectives_differ = 1
span_objective_qacc_delta_vs_qacc_objective = -0.043750
span_objective_span_exact_delta_vs_qacc_objective = 0.187500
routing_trigger_rate_sum = 0.000000
active_jump_rate_sum = 0.000000
```

Interpretation:
h6-o converts the h6-n qualitative split into an explicit policy-calibration
artifact. Optimizing byte qacc selects plain `span-local-energy`; optimizing
span exact-match selects `span-local-energy-hybrid`. The span objective gains
substantial full-span correctness while giving back byte qacc. This makes
span exact-match a first-class policy objective for future h6 work rather than
a secondary metric hidden behind byte qacc.

## h6-p Span-local-energy Policy Scale Decision

`h6-p` passes as span-local-energy policy-scale diagnostics. It does not solve
learned chunk retrieval, source-credit robustness, wrong-candidate robustness,
fallback robustness, or long-context retrieval.

The slice adds:

```text
experiments/run_v06_route_memory_span_local_energy_policy_scale.sh
experiments/test_v06_route_memory_span_local_energy_policy_scale.sh
```

It scales the h6-o policy calibration over a small key/seed matrix.

Reference standard aggregate:

```text
rows = 20
groups = 4
objectives_differ_rate = 0.750000
qacc_policy_local_energy_rate = 1.000000
span_policy_hybrid_rate = 0.750000
balanced_policy_hybrid_rate = 0.500000

qacc_policy_qacc_mean = 0.571875
qacc_policy_span_exact_mean = 0.378906
span_policy_qacc_mean = 0.538281
span_policy_span_exact_mean = 0.441406
span_policy_qacc_delta_vs_qacc_policy_mean = -0.033594
span_policy_span_exact_delta_vs_qacc_policy_mean = 0.062500
```

Interpretation:
the objective split survives scale, but not uniformly. Byte-qacc consistently
selects plain `span-local-energy`, while span-exact selects
`local-energy-hybrid` in most groups. The span objective buys higher full-span
exactness by giving back byte qacc on average. This confirms h6-o is not a
one-off, but it also shows a future policy needs an explicit objective knob or
guardrail instead of a single universal preset.

## h6-q Span-first Guardrail

`h6-q` passes as span-first policy guardrail diagnostics. It does not solve
chunk retrieval or learned source robustness.

Entry points:

```bash
experiments/run_v06_route_memory_span_first_guardrail.sh
experiments/test_v06_route_memory_span_first_guardrail.sh
```

The runner consumes the h6-p policy artifact and compares four policies:

```text
qacc-default
strict-g0p050-cap0p050
balanced-g0p025-cap0p050
span-first-g0p025-cap0p075
```

Reference standard aggregate:

```text
qacc-default:
  qacc_mean = 0.571875
  span_exact_mean = 0.378906

strict-g0p050-cap0p050:
  span_accept_rate = 0.250000
  selected_hybrid_rate = 0.250000
  qacc_mean = 0.560937
  span_exact_mean = 0.425781
  qacc_delta_vs_qacc_policy_mean = -0.010938
  span_exact_delta_vs_qacc_policy_mean = 0.046875

balanced-g0p025-cap0p050:
  span_accept_rate = 0.500000
  qacc_mean = 0.553125
  span_exact_mean = 0.433594

span-first-g0p025-cap0p075:
  span_accept_rate = 0.750000
  qacc_mean = 0.538281
  span_exact_mean = 0.441406
```

Interpretation:
the strict guardrail captures most of the span-exact gain while avoiding the
small-gain / high-qacc-loss cells. Looser guardrails converge toward the raw
span-exact policy. This is the first useful policy-level guardrail over the
h6-p objective split, but it is still calibrated on controlled symbolic span
fixtures.

## h6-r Span-first Guardrail Degradation

`h6-r` passes as span-first policy guardrail degradation diagnostics. It does
not solve learned source robustness or chunk retrieval.

Entry points:

```bash
experiments/run_v06_route_memory_span_first_guardrail_degradation.sh
experiments/test_v06_route_memory_span_first_guardrail_degradation.sh
```

The runner repeats the h6-q guardrail policy readout over two degradation
levels:

```text
weak: keep=0.25, aux_noise=0.75
harsher: keep=0.125, aux_noise=0.875
```

Reference standard aggregate:

```text
weak:
  groups = 2
  objective_split_rate = 1.000000
  strict span_accept_rate = 0.000000
  strict qacc_mean = 0.517187
  strict span_exact_mean = 0.289062

harsher:
  groups = 2
  objective_split_rate = 0.500000
  strict span_accept_rate = 0.000000
  span-first-g0p025-cap0p075 span_accept_rate = 0.500000
  span-first-g0p025-cap0p075 qacc_delta = -0.029688
  span-first-g0p025-cap0p075 span_delta = 0.023438
```

Interpretation:
the fixed h6-q guardrails are regime-sensitive. Weak degradation still exposes
the byte-qacc versus span-exact split, but the span policy qacc loss is too high
for every configured cap. Harsher degradation collapses the split in one group
and leaves only the looser span-first guardrail active in the other. The next
slice should calibrate or adapt the guardrail thresholds instead of promoting a
single fixed policy.

## h6-s Adaptive Guardrail Calibration

`h6-s` passes as adaptive guardrail calibration diagnostics. It does not solve
learned source robustness or chunk retrieval.

Entry points:

```bash
experiments/run_v06_route_memory_span_adaptive_guardrail.sh
experiments/test_v06_route_memory_span_adaptive_guardrail.sh
```

The runner consumes the h6-r policy artifact and tests:

```text
span_gain - loss_weight * qacc_loss > 0
```

Reference standard aggregate:

```text
weak utility-w0p50:
  span_accept_rate = 1.000000
  qacc_delta = -0.109375
  span_delta = 0.062500

weak utility-w0p75:
  span_accept_rate = 0.000000

harsher utility-w0p75:
  span_accept_rate = 0.500000
  qacc_delta = -0.029688
  span_delta = 0.023438

harsher utility-w1p00:
  span_accept_rate = 0.000000
```

Interpretation:
`utility-w0p50` is too permissive for weak high-loss splits. `utility-w0p75`
rejects those weak splits while accepting the lower-loss harsher split. This
makes `utility-w0p75` the current diagnostic candidate, but it needs broader
scale before promotion beyond a controlled fixture calibration.

## h6-t Adaptive Guardrail Scale

`h6-t` passes as adaptive guardrail scale diagnostics. It does not promote the
span policy.

Entry points:

```bash
experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh
experiments/test_v06_route_memory_span_adaptive_guardrail_scale.sh
```

Smoke result:

```text
all utility-w0p75:
  groups = 2
  bad_accept_rate = 0.000000
  span_accept_rate = 0.000000
  top1_recall_gap = 0.796875
  coherent_wrong_top_key = 0.828125
```

Interpretation:
`utility-w0p75` stays safe in the smoke gate, but the large top1/recall gap and
coherent wrong-key rate show that adaptive span acceptance is not enough for a
chunk-level claim.

## h6-u Chunk-quality Diagnostics

`h6-u` passes as chunk-quality diagnostics over the value span.

Entry points:

```bash
experiments/run_v06_route_memory_chunk_quality_diagnostics.sh
experiments/test_v06_route_memory_chunk_quality_diagnostics.sh
```

Smoke result:

```text
chunk_exact_mean = 0.156250
coherent_wrong_key_mean = 0.828125
top1_recall_gap_mean = 0.796875
keyshape_gap_mean = 0.734375
```

Interpretation:
the recovered candidate set still contains a coherent wrong-key failure mode.
Symbolic `key-shape` remains a large upper-bound gap, so the current local-energy
policy is not a learned chunk retrieval policy.

## h6-v/h6-w Wrong-candidate and Abstain Gates

`h6-v` and `h6-w` pass as wrong-candidate/fallback robustness gates.

Entry points:

```bash
experiments/run_v06_route_memory_wrong_candidate_robustness.sh
experiments/test_v06_route_memory_wrong_candidate_robustness.sh
experiments/run_v06_route_memory_abstain_retry_guardrail.sh
experiments/test_v06_route_memory_abstain_retry_guardrail.sh
```

Smoke result:

```text
source_arm = policy-source-order
source_qacc = 0.957813
source_retry_noisy_selected = 0.000000
chunk_ready = 0
combined_ready = 0
guardrail_action = abstain-or-weak-hint
```

Interpretation:
source-credit retry can avoid noisy retry selection, but chunk quality still
blocks promotion. The correct route-memory action is to keep the policy
diagnostic-only and separate weak-hint/abstain behavior from default promotion.

## h6-x Chunk-local Scorer Diagnostics

`h6-x` passes as chunk-local scorer diagnostics and closes the first recursive
post-promotion-gate probe as diagnostic-only.

Entry points:

```bash
experiments/run_v06_route_memory_chunk_local_energy_prefix.sh
experiments/test_v06_route_memory_chunk_local_scorers.sh
```

The slice compares the current `span-local-energy` scorer against visible-prefix
composition, worst-offset local energy, mean local margin, and worst-offset local
margin. None of the non-key-shape variants beats plain `span-local-energy` on
the smoke chunk metric:

```text
best_non_keyshape_scorer = span-local-energy
local_energy_qacc = 0.700000
local_energy_chunk_exact = 0.531250
local_energy_coherent_wrong = 0.468750
local_energy_prefix_qacc_delta = -0.006250
local_energy_prefix_chunk_delta = -0.031250
local_margin_chunk_exact = 0.531250
keyshape_chunk_gap = 0.468750
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
simple prefix, worst-offset, and margin transforms do not break the coherent
wrong-key mode. `span-local-energy` remains the best current non-key-shape
record scorer, while symbolic `key-shape` remains an upper-bound diagnostic only.

## h6-y Chunk-code Similarity Diagnostics

`h6-y` passes as chunk-code similarity diagnostics and closes the learned-code
signature reranking probe as diagnostic-only.

Entry points:

```bash
experiments/run_v06_route_memory_chunk_code_similarity.sh
experiments/test_v06_route_memory_chunk_code_similarity.sh
```

The slice adds:

```text
--route-candidate-score span-route-code
--route-candidate-score span-local-energy-route-code
```

`span-route-code` compares learned code signatures rather than raw key strings.
`span-local-energy-route-code` adds that signature score to the existing
`span-local-energy` score. On the weak route-code smoke, route-code signature
collision remains high and the new scorer does not improve the local-energy
chunk result:

```text
best_non_keyshape_scorer = span-local-energy
local_energy_qacc = 0.706250
local_energy_chunk_exact = 0.531250
local_energy_coherent_wrong = 0.468750
route_code_qacc = 0.587500
route_code_chunk_exact = 0.281250
local_energy_route_code_chunk_exact = 0.531250
route_signature_collision_mean = 0.750000
keyshape_chunk_gap = 0.406250
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Interpretation:
learned route-code signatures are wired as a non-symbolic ranking diagnostic,
but this weak-source regime has too much signature collision for code similarity
to break the coherent wrong-key mode. The best current non-key-shape scorer is
still plain `span-local-energy`.

## h10-a Teacher-free Chunk-credit Ranker

`h10-a` passes as the first teacher-free chunk-ranker smoke. It reuses the
existing route-credit reward/slash loop and reads the candidate record span as a
single unit. The new rankers are:

```text
--route-candidate-score span-chunk-credit
--route-candidate-score span-local-energy-chunk-credit
```

Entry points:

```bash
experiments/run_v10_teacher_free_chunk_ranker.sh
experiments/test_v10_teacher_free_chunk_ranker.sh
experiments/test_v10_teacher_free_chunk_ranker_scale.sh
```

Smoke result:

```text
best_non_keyshape_scorer = span-chunk-credit
local_energy_qacc = 0.700000
local_energy_chunk_exact = 0.562500
local_energy_coherent_wrong = 0.437500
chunk_credit_qacc = 1.000000
chunk_credit_chunk_exact = 1.000000
chunk_credit_coherent_wrong = 0.000000
local_energy_chunk_credit_chunk_exact = 1.000000
route_credit_gap_mean = 0.800000
route_credit_top1_mean = 1.000000
chunk_credit_gap_mean = 0.800000
chunk_credit_top1_mean = 1.000000
routing_trigger_rate_mean = 0.000000
active_jump_rate_mean = 0.000000
```

Standard scale result:

```text
groups = 2
chunk_credit_qacc = 0.992188
chunk_credit_chunk_exact = 0.960938
chunk_credit_coherent_wrong = 0.000000
local_energy_qacc = 0.512500
local_energy_chunk_exact = 0.351562
best_chunk_delta_vs_local_energy = 0.609375
route_credit_gap_mean = 0.799219
chunk_credit_top1_mean = 1.000000
keyshape_chunk_gap = 0.000000
```

Interpretation:
this is the first controlled positive chunk-ranker result after h6-x/h6-y. It
does not use symbolic `key-shape` as the scorer and it preserves the
value-bearing route-hint path. It is not yet default promotion: it must be
scaled through key/seed/degradation/noisy/fallback regimes and then pass a new
promotion gate.

## h10-b Chunk-credit Abstain Policy

`h10-b` passes as the first policy layer above h10-a. It deliberately separates
chunk-credit readiness from default promotion.

Entry points:

```bash
experiments/run_v10_chunk_credit_abstain_policy.sh
experiments/test_v10_chunk_credit_abstain_policy.sh
```

Smoke result:

```text
guardrail_action = weak-hint-with-abstain
default_promotion = 0
diagnostic_only = 1
weak_hint_or_abstain = 1
chunk_credit_ready = 1
source_safe = 1
fallback_not_keyshape_only = 1
joint_chunk_source_ready = 0
joint_noisy_used = 1.000000
joint_fallback_retry_exercised = 0
distillation_ready = 0
combined_ready = 0
noisy_selection_clean = 1
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
chunk credit is strong enough in the controlled fixture, and the existing source
gate is noisy-clean. At the h10-b layer, fallback/retry is intentionally not
claimed from the successful chunk-credit path. h10-d exercises that path
separately; the correct action here remains weak-hint/abstain, not default
promotion.

## h10-c Joint Source and Distillation Gate

`h10-c` adds the joint noisy gate, h10-d adds the forced fallback/retry
exercise, h10-e adds the teacher-label contract, and h10-f adds the local
teacher-label collection harness consumed by the distillation gate:

- `run_v10_chunk_credit_source_robustness.sh` injects noisy candidates while
  using the teacher-free chunk-credit scorer.
- `run_v10_chunk_credit_fallback_retry_exercise.sh` clears correct primary
  candidates and requires source retry to recover without selecting noisy
  sources.
- `run_v10_teacher_label_contract.sh` defines the label schema for correct,
  wrong, near-miss, missing-query, abstain, and grounded-span supervision.
- `run_v10_teacher_label_collection_harness.sh` collects deterministic local
  fixture labels under that schema and keeps external-label/training readiness
  blocked.
- `run_v10_chunk_credit_distillation_gate.sh` decides whether chunk credit can
  be distilled or promoted above the diagnostic policy layer.

Entry points:

```bash
experiments/run_v10_chunk_credit_source_robustness.sh
experiments/test_v10_chunk_credit_source_robustness.sh
experiments/run_v10_chunk_credit_fallback_retry_exercise.sh
experiments/test_v10_chunk_credit_fallback_retry_exercise.sh
experiments/run_v10_teacher_label_contract.sh
experiments/test_v10_teacher_label_contract.sh
experiments/run_v10_teacher_label_collection_harness.sh
experiments/test_v10_teacher_label_collection_harness.sh
experiments/run_v10_chunk_credit_distillation_gate.sh
experiments/test_v10_chunk_credit_distillation_gate.sh
```

Smoke result:

```text
best_joint_arm = chunk-credit-source-order
fallback_exercise_arm = raw-retry
joint_chunk_ready = 1
joint_source_safe = 1
noisy_clean = 1
joint_noisy_used = 1.000000
noisy_selected = 0.000000
fallback_retry_exercised = 1
fallback_exercise_ready = 1
fallback_qacc_delta_vs_corrupt = 0.620000
fallback_retry_raw_selected = 1.000000
fallback_retry_noisy_selected = 0.000000
joint_chunk_source_ready = 0
teacher_label_contract_ready = 1
teacher_label_collection_ready = 1
teacher_external_labels_ready = 0
teacher_distillation_training_ready = 0
teacher_grounded_span_coverage = 1.000000
teacher_label_source = local-teacher-harness
distillation_ready = 0
reason = teacher-distillation-training-missing
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
this is positive wrong-candidate evidence for chunk credit plus a real
fallback/retry exercise and a concrete teacher-label schema. The forced-corrupt
primary path recovers through raw retry evidence and does not select noisy
retry/source candidates. The contract covers correct, wrong, near-miss,
missing-query, abstain, and grounded-span labels. The h10-f local collection
harness now marks local supervision ready. Distillation is still blocked because
external teacher-label ingestion and the distillation learner are not ready.

## Current Route-memory Handoff

h10-a/b/c/d/e/f are the current route-memory checkpoint. h6-y remains
diagnostic-only, h10-a/b/c/d/e/f are wired into the route-memory closure path, and
h7-b still blocks default promotion until teacher-label distillation evidence
exists. The live invariant remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The next slice should train/stub the distillation learner and/or ingest external
teacher labels while preserving the h6-p objective split:

```text
byte-qacc objective: optimize local-energy policy
span-exact objective: allow local-energy-hybrid when full-span correctness wins
```
