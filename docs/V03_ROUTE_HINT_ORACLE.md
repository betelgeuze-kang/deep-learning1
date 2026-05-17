# v0.3 Route-Hint Oracle

This note tracks the first value-bearing route-signal slice.

It is oracle-only and experimental, but it passes its first fixture test.

## Decision

The oracle route-hint slice passes its first fixture test.

Unlike jump-neighbor replacement, which either regressed the fixture when active
or collapsed to a no-op under conservative gates, value-bearing route hints
improve the fixture query metric without perturbing `repeating-text`.

Reference result:

- fixture query byte accuracy improves from `0.200000` to `1.000000` at
  `lambda_route = 0.30`
- `repeating-text` remains unchanged across tested route strengths

Interpretation:

The failure of previous v0.3 routing slices was not the existence of
long-range information, but the representation of that information as
neighbor replacement. When the remote signal is injected as a value-bearing
proposal hint, the local dynamics can use it.

## Scope

- `--route-mode hint-oracle`
- `--lambda-route`
- fixture syntax: `@id=value` records and `?id=` query positions
- query node: the `=` byte in `?id=`
- oracle hint: matching record value byte
- injection: additive proposal-energy bias toward the value byte's high/low
  nibbles

This slice does not replace local neighbors, change graph topology, discover
candidates, or learn routing keys.

Allowed wording:

- `oracle value-bearing route hint works on the fixture`
- `value-bearing route signal improves query positions`
- `local topology is preserved`

Do not say:

- `sparse routing solved`
- `long-context retrieval solved`
- `learned routing works`
- `passkey retrieval works`

## Current Readout

Helper:

```bash
./experiments/test_v03_route_hint_oracle.sh
./experiments/run_v03_route_hint_oracle.sh
```

Reference readout, seed `1`, last-10:

| Run | byte_acc | field_byte_acc | joint_byte_acc | query_count | applied | query_byte_acc | query_field_acc | query_joint_acc |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `fixture-off` | `0.257552` | `0.228776` | `0.259618` | `4.000000` | `0.000000` | `0.200000` | `0.150000` | `0.175000` |
| `fixture-lr0p01` | `0.249285` | `0.228299` | `0.249285` | `4.000000` | `1.000000` | `0.150000` | `0.125000` | `0.125000` |
| `fixture-lr0p03` | `0.248808` | `0.231002` | `0.252464` | `4.000000` | `1.000000` | `0.250000` | `0.250000` | `0.250000` |
| `fixture-lr0p10` | `0.254054` | `0.234340` | `0.254213` | `4.000000` | `1.000000` | `0.300000` | `0.150000` | `0.150000` |
| `fixture-lr0p20` | `0.253895` | `0.235453` | `0.250397` | `4.000000` | `1.000000` | `0.875000` | `0.150000` | `0.200000` |
| `fixture-lr0p30` | `0.251828` | `0.232591` | `0.247377` | `4.000000` | `1.000000` | `1.000000` | `0.200000` | `0.200000` |
| `fixture-lr0p50` | `0.256439` | `0.232591` | `0.252464` | `4.000000` | `1.000000` | `1.000000` | `0.100000` | `0.175000` |
| `repeat-off` | `0.687500` | `0.683594` | `0.687500` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` |
| `repeat-lr0p30` | `0.687500` | `0.683594` | `0.687500` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` |
| `repeat-lr0p50` | `0.687500` | `0.683594` | `0.687500` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` |

Primary gate:

- fixture query positions improve
- `repeating-text` does not regress

Whole-file `byte_acc` is secondary because query positions are sparse.

The current transition curve is weak below `lambda_route = 0.20`, nearly solved
at `0.20`, and saturated by `0.30`.

## Ablation Summary

| Routing method | Fixture effect | Repeat effect | Interpretation |
| --- | ---: | ---: | --- |
| `probe` | no effect | no effect | diagnostics only |
| `jump-neighbor` | regression or no-op | no useful lift | replacement semantics wrong |
| confidence guard | suppresses bad jumps | no lift | guardrail, not routing |
| oracle route hint | query acc `0.2 -> 1.0` | no regression | value-bearing signal works |

Core finding:

> Long-range information must enter as a value-bearing signal, not as a
> topology replacement.

## Roadmap

Current state:

- `v0.3-h1`: oracle route hint, `PASS`
- `v0.3-h2`: parsed key-value candidate with non-oracle value delivery, `PASS`
- `v0.3-h3`: exact key-match routing with O(1) record lookup, `PASS`
- `v0.3-h3a`: exact KV scale-up, `PASS` for exact retrieval and distance
  scaling; many-key/noisy query saturation depends on route strength
- `v0.3-h4-1`: hashed symbolic key candidate retrieval, `PASS` for candidate
  recall instrumentation and high-bit route hints; lossy buckets expose a
  top-1 ranking bottleneck
- `v0.3-h4-2`: multi-candidate vote aggregation, `PASS` as an ambiguity
  mitigation; it improves lossy buckets but does not eliminate ranking/scoring
- `v0.3-h4-3`: weighted value-vote candidate scoring, `PASS` as controlled
  scoring instrumentation; neutral on the default 32-key sweep because collided
  bucket values are mostly unique
- `v0.3-h4-4`: deterministic key-shape candidate scoring, `PASS` as a symbolic
  scoring baseline; it resolves the current 32-key lossy hash ambiguity, but it
  uses parsed key-string shape and is not learned routing
- `v0.3-h4-5b`: learned joint-code key-region hash, `PASS` as plumbing and
  diagnostic instrumentation, but `NOT YET` a learned routing win on the
  32-key sweep
- `v0.3-h4-5c`: key-region joint-code representation diagnostics, `PASS` as
  instrumentation; current joint-code has low key-byte reconstruction and high
  signature collision
- `v0.3-h4-5d`: route-code identity auxiliary, `PASS` as an identity-code
  baseline; key-region identity code recovers the 32-key route-code sweep, but
  it is still an explicit identity auxiliary, not general semantic routing
- `v0.3-h4-5e`: route-code stress/ablation, `PASS` as diagnostics; route
  identity stays separable, while many-key scaling exposes a downstream
  dynamics/hint-strength limit
- `v0.3-h4-5f`: many-key route-hint dynamics margin ablation, `PASS` as
  diagnostics; 128-key retrieval stays perfect and `lambda_route = 10.0`
  restores query accuracy, identifying hint strength/effective margin as the
  primary bottleneck
- `v0.3-h4-5g`: adaptive route strength, `PASS` as calibrated strength
  diagnostics; margin mode nearly matches fixed strong routing with lower mean
  strength
- `v0.3-h4-5h`: wrong-candidate corruption stress, `PASS` as confidence
  guardrail instrumentation; low-confidence corrupted hints are suppressed, but
  this is not yet full wrong-candidate robustness
- `v0.3-h4-5i`: candidate/value confidence calibration, `PASS` as
  instrumentation; value-support confidence lowers wrong hint strength but does
  not yet improve corruption robustness

Recommended next stages:

- stronger candidate ranking/confidence features before noisy learned routing
- `v0.3-h5`: route plasticity / source-credit calibration
- `v0.3-h5-i`: fallback-source policy calibration; pair with
  `./experiments/test_v05_route_source_credit_fallback_policy.sh` and
  `./experiments/run_v05_route_source_credit_fallback_policy.sh`

The center of v0.3 is no longer whether to jump. The question is which value to
bring into the local dynamics.

## Parsed Value Candidate

`v0.3-h2` lowers the oracle one step.

Instead of directly handing `value_byte` to the query, the parser provides the
matching record value position. The graph then reads the byte at that candidate
position and injects it through the same proposal-hint energy.

Helper:

```bash
./experiments/test_v03_route_hint_parsed.sh
./experiments/run_v03_route_hint_parsed.sh
```

Reference parsed readout, seed `1`, last-10:

| Run | query_count | applied | candidate_lookup_count | candidate_hit_rate | value_read_distance | query_byte_acc |
| --- | --- | --- | --- | --- | --- | --- |
| `fixture-off` | `4.000000` | `0.000000` | `4.000000` | `1.000000` | `126.750000` | `0.200000` |
| `fixture-lr0p01` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `0.150000` |
| `fixture-lr0p03` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `0.250000` |
| `fixture-lr0p10` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `0.300000` |
| `fixture-lr0p20` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `0.875000` |
| `fixture-lr0p30` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `1.000000` |
| `fixture-lr0p50` | `4.000000` | `1.000000` | `4.000000` | `1.000000` | `126.750000` | `1.000000` |
| `repeat-lr0p50` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` |

Decision:

- `v0.3-h2 parsed value candidate`: `PASS`
- the query metric curve matches the direct oracle route-hint slice
- `repeating-text` remains unchanged because it has no parsed hints
- this is still fixture-aware symbolic candidate delivery, not learned routing

## Exact Key-Value Route Hint

`v0.3-h3` removes the pre-attached value position and performs exact symbolic
lookup from parsed records and queries.

Format:

```text
@KEY=VALUE; ... ?KEY=
```

Lookup rule:

- records update `record_table[KEY] = value_pos`
- queries read `record_table[KEY]`
- duplicate keys use latest-record-wins at query time

This is still symbolic routing, not learned routing.

Helper:

```bash
./experiments/test_v03_route_hint_kv_exact.sh
./experiments/run_v03_route_hint_kv_exact.sh
```

Reference exact-KV readout, seed `1`, last-10:

| Run | kv_records | kv_queries | kv_hit_rate | duplicate_rate | missing_rate | candidate_hit_rate | value_read_distance | query_byte_acc |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `fixture-off` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `0.200000` |
| `fixture-lr0p01` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `0.150000` |
| `fixture-lr0p03` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `0.250000` |
| `fixture-lr0p10` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `0.300000` |
| `fixture-lr0p20` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `0.875000` |
| `fixture-lr0p30` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `1.000000` |
| `fixture-lr0p50` | `4.000000` | `4.000000` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `126.750000` | `1.000000` |
| `repeat-lr0p50` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` |

Decision:

- `v0.3-h3 exact key-value route hint`: `PASS`
- exact lookup reproduces the parsed/oracle query curve
- duplicate and missing key rates are now instrumented
- `repeating-text` remains unchanged because it has no key-value hints
- this provides a symbolic upper bound for learned key/value candidate routing

## Exact KV Scale-Up

`v0.3-h3a` keeps the same exact symbolic lookup path and varies distance,
number of keys, duplicate-key policy, missing-key behavior, and filler noise.

Helper:

```bash
./experiments/test_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh --strong
```

Profiles:

- default: practical scale-up with `lambda_route = 0.50`
- `--strong`: stress follow-up with `lambda_route = 5.0` for cases where exact
  retrieval succeeds but the proposal hint is not strong enough to saturate the
  query metric
- `--full`: heavier distance/key sweep for slower runs

Reference default readout, seed `1`, last-5:

| Run | kv_hit_rate | duplicate_rate | missing_rate | value_read_distance | query_byte_acc |
| --- | --- | --- | --- | --- | --- |
| `distance_d64` | `1.000000` | `0.000000` | `0.000000` | `72.000000` | `1.000000` |
| `distance_d256` | `1.000000` | `0.000000` | `0.000000` | `264.000000` | `1.000000` |
| `distance_d1024` | `1.000000` | `0.000000` | `0.000000` | `1032.000000` | `1.000000` |
| `distance_d4096` | `1.000000` | `0.000000` | `0.000000` | `4104.000000` | `1.000000` |
| `keys_k16` | `1.000000` | `0.000000` | `0.000000` | `72.000000` | `0.775000` |
| `keys_k64` | `1.000000` | `0.000000` | `0.000000` | `72.000000` | `0.271875` |
| `duplicate_latest` | `1.000000` | `0.500000` | `0.000000` | `70.000000` | `1.000000` |
| `missing_key` | `0.000000` | `0.000000` | `1.000000` | `0.000000` | `0.000000` |
| `noisy_mixed` | `1.000000` | `0.000000` | `0.000000` | `264.000000` | `0.250000` |

Reference strong readout, seed `1`, last-5:

| Run | kv_hit_rate | value_read_distance | query_byte_acc |
| --- | --- | --- | --- |
| `keys_k64` | `1.000000` | `72.000000` | `1.000000` |
| `noisy_mixed` | `1.000000` | `264.000000` | `1.000000` |

Decision:

- `v0.3-h3a exact KV scale-up`: `PASS` for symbolic exact retrieval,
  duplicate/missing diagnostics, and distance scaling through `4096`
- the default `lambda_route = 0.50` profile saturates the distance sweep but not
  the many-key and noisy fixtures
- the `--strong` profile recovers `keys_k64` and `noisy_mixed` to
  `query_byte_acc = 1.000000`, so those failures are currently best read as
  hint-strength/dynamics-margin limits, not candidate lookup failures
- this is still symbolic exact KV routing, not learned routing or general
  long-context retrieval

## Hashed Key Candidate Retrieval

`v0.3-h4-1` replaces exact string lookup with symbolic key hashing:

```text
record KEY -> hash(KEY) bucket -> value_pos candidates
query KEY  -> hash(KEY) bucket -> top-K_route candidates
```

The route hint path is unchanged:

```text
selected candidate value_pos -> value byte read -> proposal hint
```

This still parses fixture keys symbolically. It is a hashed candidate-retrieval
step, not learned routing.

Helper:

```bash
./experiments/test_v03_route_hint_kv_hash.sh
./experiments/test_v03_route_hint_kv_hash_vote.sh
./experiments/test_v03_route_hint_kv_hash_weighted.sh
./experiments/test_v03_route_hint_kv_hash_key_shape.sh
./experiments/run_v03_route_hint_kv_hash.sh
```

New metrics:

- `route_candidate_query_count`
- `route_candidate_recall_rate`
- `route_candidate_top1_rate`
- `route_candidate_rank_mean`
- `route_bucket_load_mean`
- `route_bucket_load_max`
- `route_bucket_collision_rate`

Reference default readout, keys `32`, records-block then queries-block,
`lambda_route = 5.0`, last-5:

| Run | recall | top1 | rank | bucket_mean | bucket_max | collision | query_byte_acc |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `bits4_kr1_top1` | `0.500000` | `0.500000` | `1.000000` | `2.125000` | `3.000000` | `0.937500` | `0.500000` |
| `bits4_kr4_top1` | `1.000000` | `0.500000` | `1.562500` | `2.125000` | `3.000000` | `0.937500` | `0.500000` |
| `bits6_kr1_top1` | `0.875000` | `0.875000` | `1.000000` | `1.250000` | `2.000000` | `0.250000` | `0.875000` |
| `bits6_kr4_top1` | `1.000000` | `0.875000` | `1.125000` | `1.250000` | `2.000000` | `0.250000` | `0.875000` |
| `bits8_kr1_top1` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `0.000000` | `1.000000` |
| `bits16_kr1_top1` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `0.000000` | `1.000000` |

Interpretation:

- high-bit hash buckets reproduce exact-KV behavior with rank-1 candidates
- lossy buckets degrade gracefully as collisions rise
- increasing `K_route` can recover candidate-set recall, but the current hint
  injection uses only the selected rank-1 value, so query accuracy follows
  `route_candidate_top1_rate`, not top-K recall
- this exposes the next h4 bottleneck: candidate ranking or multi-candidate
  hint aggregation, before moving to learned joint-context keys
- `repeating-text` has no KV queries and remains unchanged in the hash smoke

Decision:

- `v0.3-h4-1 hashed symbolic key candidate retrieval`: `PASS` as a candidate
  retrieval diagnostic and high-bit hash route-hint path
- do not call this learned routing; the key source is still symbolic fixture KEY
- do not revive jump-neighbor replacement

## Multi-Candidate Vote Aggregation

`v0.3-h4-2` adds route-hint aggregation:

```bash
--route-hint-agg top1
--route-hint-agg vote
```

`top1` preserves the previous h4-1 behavior. `vote` reads all top-`K_route`
candidate value positions and adds normalized nibble votes to the proposal
energy:

```text
candidates -> value bytes -> high/low vote tables -> proposal hint
```

The topology is still unchanged. No remote candidate becomes a neighbor.

Additional metrics:

- `route_hint_vote_candidate_count_mean`
- `route_hint_vote_margin_mean`

Controlled smoke readout, `bits4`, `K_route = 4`, last row:

| Aggregation | recall | top1 | vote_count | vote_margin | query_byte_acc |
| --- | --- | --- | --- | --- | --- |
| `top1` | `1.000000` | `0.000000` | `4.000000` | `0.750000` | `0.000000` |
| `vote` | `1.000000` | `0.000000` | `4.000000` | `0.750000` | `1.000000` |

Reference 32-key lossy-hash readout, `lambda_route = 5.0`, last-5:

| Run | recall | top1 | vote_margin | query_byte_acc |
| --- | --- | --- | --- | --- |
| `bits4_kr4_top1` | `1.000000` | `0.500000` | `0.671875` | `0.500000` |
| `bits4_kr4_vote` | `1.000000` | `0.500000` | `0.671875` | `0.700000` |
| `bits6_kr4_top1` | `1.000000` | `0.875000` | `0.937500` | `0.875000` |
| `bits6_kr4_vote` | `1.000000` | `0.875000` | `0.937500` | `0.956250` |

Decision:

- `v0.3-h4-2 multi-candidate vote aggregation`: `PASS` as a mitigation for
  top-1 ranking failures
- vote aggregation can recover a controlled top1-failure case and improves the
  lossy 32-key sweep
- vote aggregation is not a full ambiguity solution; heavily collided buckets
  still need better candidate scoring, confidence, or learned ranking
- the next learned-key slice should preserve the value-position route-hint path
  and treat ranking/aggregation as first-class diagnostics

## Weighted Candidate Scoring

`v0.3-h4-3` adds candidate scoring for weighted aggregation:

```bash
--route-hint-agg weighted-vote
--route-candidate-score insertion
--route-candidate-score recency
--route-candidate-score value-vote
--route-candidate-score key-shape
```

Current scoring semantics:

- `insertion`: equal candidate weights
- `recency`: higher weight for the current rank-1/latest bucket candidate
- `value-vote`: candidates whose value byte appears more often in the top-K set
  receive higher weight
- `key-shape`: rank hash-bucket candidates by deterministic key-string shape
  against the query key: length match, digit-count match, common prefix, and
  common suffix, with latest-record tie-breaking

Additional diagnostics:

- `route_hint_correct_value_vote_share_mean`
- `route_hint_vote_entropy_mean`
- `route_hint_unique_values_mean`

Controlled weighted smoke, `bits4`, `K_route = 4`, last row:

| Aggregation | score | recall | top1 | qacc | correct_share | entropy | unique_values |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `weighted-vote` | `value-vote` | `1.000000` | `0.000000` | `1.000000` | `0.900000` | `0.468996` | `2.000000` |

Reference 32-key lossy-hash readout, `lambda_route = 5.0`, last-5:

| Run | qacc | correct_share | entropy | unique_values |
| --- | --- | --- | --- | --- |
| `bits4_kr4_vote` | `0.700000` | `0.739583` | `0.536560` | `1.562500` |
| `bits4_kr4_weighted_value` | `0.700000` | `0.739583` | `0.536560` | `1.562500` |
| `bits6_kr4_vote` | `0.956250` | `0.937500` | `0.125000` | `1.125000` |
| `bits6_kr4_weighted_value` | `0.956250` | `0.937500` | `0.125000` | `1.125000` |

Decision:

- `v0.3-h4-3 weighted value-vote scoring`: `PASS` as controlled scoring
  instrumentation
- value-frequency weighting can amplify repeated supporting values in a
  collision bucket
- on the default 32-key lossy hash sweep it is neutral because most collided
  candidate sets do not contain repeated value bytes, so weighting collapses
  back to ordinary vote
- this motivated testing information beyond value frequency; the next slice
  below starts with deterministic key-shape/length scoring

## Deterministic Key-shape Scoring

`v0.3-h4-4` adds a deterministic symbolic scoring baseline:

```bash
--route-mode hint-kv-hash
--route-hint-agg top1
--route-candidate-score key-shape
```

The scorer does not change the successful route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

It only changes candidate order inside a hash bucket. Candidates whose record
key has stronger shape agreement with the query key are ranked first. The score
uses length match, digit-count match, common prefix, and common suffix, then
falls back to latest-record tie-breaking.

Controlled key-shape smoke:

- insertion baseline: recall `1.000000`, top1 `0.000000`, qacc `0.000000`,
  rank `2.000000`
- key-shape scorer: recall `1.000000`, top1 `1.000000`, qacc `1.000000`,
  rank `1.000000`

Reference 32-key lossy-hash readout, `lambda_route = 5.0`, last-5:

| Run | qacc | recall | top1 | rank |
| --- | --- | --- | --- | --- |
| `bits4_kr1_top1` | `0.500000` | `0.500000` | `0.500000` | `1.000000` |
| `bits4_kr1_key_shape` | `1.000000` | `1.000000` | `1.000000` | `1.000000` |
| `bits4_kr4_vote` | `0.700000` | `1.000000` | `0.500000` | `1.562500` |
| `bits4_kr4_key_shape` | `1.000000` | `1.000000` | `1.000000` | `1.000000` |
| `bits6_kr4_vote` | `0.956250` | `1.000000` | `0.875000` | `1.125000` |
| `bits6_kr4_key_shape` | `1.000000` | `1.000000` | `1.000000` | `1.000000` |

Decision:

- `v0.3-h4-4 key-shape scoring`: `PASS` as a deterministic symbolic scoring
  baseline
- it shows that the current lossy hash ambiguity is resolvable when a strong
  candidate feature is available
- it should not be described as learned routing, because it uses parsed key
  strings and deterministic shape comparison
- next: replace this symbolic feature with raw key-region and learned
  joint-code key-region candidate sources

## Joint-code Key-region Hash

`v0.3-h4-5b` adds a learned-code candidate source:

```bash
--route-mode hint-kv-hash
--route-hash-source joint-code-key
```

This keeps the same value-bearing path:

```text
candidate value_pos -> value byte read -> proposal hint
```

The difference is only the bucket key. Instead of hashing the parsed raw key
bytes directly, the graph maps each key byte through the current learned
`best_joint_byte()` code from the `H+B` local substrate, hashes that code
sequence, and rebuilds hash buckets at `begin_epoch()`.

Controlled smoke:

- one-key fixture reaches recall `1.000000`, top1 `1.000000`, qacc
  `1.000000`
- this verifies that the learned-code bucket path is wired into route hints

Reference 32-key joint-code sweep, `lambda_route = 5.0`, last-5:

| Run | qacc | recall | top1 | bucket_load | collision |
| --- | --- | --- | --- | --- | --- |
| `bits4_kr4_vote` | `0.500000` | `0.675000` | `0.337500` | `5.875000` | `0.812500` |
| `bits6_kr4_vote` | `0.481250` | `0.687500` | `0.368750` | `6.000000` | `0.762500` |
| `bits8_kr4_vote` | `0.462500` | `0.687500` | `0.368750` | `6.000000` | `0.762500` |
| `bits16_kr4_vote` | `0.462500` | `0.687500` | `0.375000` | `5.987500` | `0.750000` |

`v0.3-h4-5c` adds representation diagnostics:

- `key_region_count`
- `key_region_joint_decode_acc`
- `raw_key_unique_count`
- `joint_key_unique_count`
- `joint_signature_collision_rate`
- `joint_vs_raw_candidate_overlap_rate`

Reference 32-key representation readout, `lambda_route = 5.0`, last-5:

| Run | key_bytes | decode_acc | raw_unique | joint_unique | signature_collision | raw_overlap |
| --- | --- | --- | --- | --- | --- | --- |
| `bits4_kr4_vote` | `256.000000` | `0.093750` | `32.000000` | `13.200000` | `0.587500` | `0.502083` |
| `bits6_kr4_vote` | `256.000000` | `0.071875` | `32.000000` | `12.000000` | `0.625000` | `0.631250` |
| `bits8_kr4_vote` | `256.000000` | `0.093750` | `32.000000` | `12.000000` | `0.625000` | `0.687500` |
| `bits16_kr4_vote` | `256.000000` | `0.093750` | `32.000000` | `12.000000` | `0.625000` | `0.687500` |

Decision:

- `v0.3-h4-5b joint-code key-region hash`: `PASS` as plumbing and diagnostic
  instrumentation
- `v0.3-h4-5c representation diagnostics`: `PASS` as instrumentation
- it is not yet a learned routing win; the learned joint-code representation
  collapses too many key strings into ambiguous buckets on the 32-key fixture
- key-region decode accuracy is only about `0.07-0.094`, and 32 raw keys collapse
  to about `12-13.2` joint signatures under the current learned code
- the gap to `raw-key` and `key-shape` is now measurable with the same
  candidate metrics plus representation diagnostics
- next: add an identity-preserving route-code auxiliary before claiming learned
  sparse routing

## Route-code Identity Auxiliary

`v0.3-h4-5d` adds a separate route identity code:

```bash
--route-hash-source route-code-key
--route-code-aux 1
--route-code-key-region-only 1
--eta-route-code 0.25
--lambda-route-code-id 1.0
```

This keeps the successful nonlocal path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

The new route-code path does not use the prediction joint-code as the routing
key. Instead, it trains a separate `route_field_` table toward input-byte
identity on key-region bytes only:

```text
route target high = input_byte / 16
route target low  = input_byte % 16
```

The route hash then uses the route-code sequence for the parsed key region.

Additional diagnostics:

- `key_region_route_decode_acc`
- `route_key_unique_count`
- `route_signature_collision_rate`
- `route_vs_raw_candidate_overlap_rate`

Reference 32-key route-code sweep, `lambda_route = 5.0`, last-5:

| Run | qacc | recall | top1 | route_decode | route_unique | route_collision | raw_overlap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `bits4_kr4_vote` | `0.731250` | `1.000000` | `0.500000` | `1.000000` | `32.000000` | `0.000000` | `1.000000` |
| `bits6_kr4_vote` | `0.968750` | `1.000000` | `0.875000` | `1.000000` | `32.000000` | `0.000000` | `1.000000` |
| `bits8_kr4_vote` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` | `1.000000` |
| `bits16_kr4_vote` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` | `1.000000` |

Decision:

- `v0.3-h4-5d route-code identity auxiliary`: `PASS` as an identity-code
  baseline
- compared with joint-code key hash, the route-code auxiliary preserves key
  identity on the 32-key fixture: route decode reaches `1.000000`, 32 raw keys
  remain 32 route signatures, and signature collision drops to `0.000000`
- candidate recall/top1/query accuracy recover to the raw/key-shape baseline
  for sufficiently wide hashes
- this should not be overclaimed as general learned semantic routing; it is an
  explicit identity-preserving route code trained on key-region bytes
- next: stress the route-code auxiliary under more keys, noisy fillers, lower
  route-code learning rates, and less symbolic supervision

## Route-code Stress / Ablation

`v0.3-h4-5e` adds a focused stress helper:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_stress.sh
```

The helper writes a summary CSV and probes representative axes:

- key count
- hash bits and `K_route`
- route-code learning rate
- key-region-only versus full-sequence identity auxiliary
- noisy and repeating-text filler

Reference standard stress readout, `lambda_route = 5.0`, last-5:

| Scenario | keys | bits | K | eta | filler | qacc | recall | top1 | route_decode | route_unique | collision |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `keycount` | `32` | `16` | `4` | `0.25` | `clean` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |
| `keycount` | `64` | `16` | `4` | `0.25` | `clean` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `64.000000` | `0.000000` |
| `keycount` | `128` | `16` | `4` | `0.25` | `clean` | `0.562500` | `1.000000` | `1.000000` | `1.000000` | `128.000000` | `0.000000` |
| `hashK` | `32` | `4` | `1` | `0.25` | `clean` | `0.500000` | `0.500000` | `0.500000` | `1.000000` | `32.000000` | `0.000000` |
| `hashK` | `32` | `4` | `4` | `0.25` | `clean` | `0.693750` | `1.000000` | `0.500000` | `1.000000` | `32.000000` | `0.000000` |
| `hashK` | `32` | `6` | `4` | `0.25` | `clean` | `0.943750` | `1.000000` | `0.875000` | `1.000000` | `32.000000` | `0.000000` |
| `hashK` | `32` | `16` | `4` | `0.25` | `clean` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |
| `eta` | `32` | `16` | `4` | `0.005` | `clean` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |
| `scope` | `32` | `16` | `4` | `0.25` | `clean` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |
| `filler` | `32` | `16` | `4` | `0.25` | `noisy` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |
| `filler` | `32` | `16` | `4` | `0.25` | `repeat` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `32.000000` | `0.000000` |

Decision:

- `v0.3-h4-5e route-code stress`: `PASS` as diagnostics
- route-code identity separability is robust in the tested 32/64-key clean
  cases and under noisy/repeating fillers
- low hash bits still behave like sparse hash buckets: `K_route` recovers
  recall, but top1 and qacc remain collision-sensitive
- the 128-key case is important: route identity, recall, and top1 remain
  perfect, but query accuracy falls to `0.562500`; this is not a candidate
  retrieval failure, but a downstream dynamics/hint-strength/relaxation limit
- next: run many-key route-hint strength, epochs/cycles, and proposal-margin
  ablations before claiming scale robustness

## Many-key Route-hint Dynamics Margin

`v0.3-h4-5f` adds a focused dynamics helper:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh
```

It keeps the route-code candidate path fixed and varies:

- `lambda_route`
- `cycles_per_epoch`
- `proposal_count`
- `route_target_proposals`

It also adds query-only dynamics diagnostics:

- `fixture_query_hi_acc`
- `fixture_query_lo_acc`
- `query_route_hint_margin_mean`
- `query_local_margin_against_route_mean`
- `query_effective_route_margin_mean`

Reference 128-key standard readout, last-5:

| Scenario | lambda | cycles | proposals | target proposals | qacc | hi | lo | recall | top1 | route decode | route margin | local against | effective |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `lambda` | `0.5` | `20` | `30` | `0` | `0.198438` | `0.517188` | `0.312500` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `7.308821` | `-6.808821` |
| `lambda` | `2.0` | `20` | `30` | `0` | `0.393750` | `0.717188` | `0.537500` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.339314` | `-3.339314` |
| `lambda` | `5.0` | `20` | `30` | `0` | `0.625000` | `0.753125` | `0.800000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.203670` | `-0.203670` |
| `lambda` | `10.0` | `20` | `30` | `0` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `4.508486` | `5.491514` |
| `cycles` | `5.0` | `10` | `30` | `0` | `0.779688` | `0.834375` | `0.932813` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `3.637665` | `1.362335` |
| `cycles` | `5.0` | `40` | `30` | `0` | `0.629688` | `0.834375` | `0.729688` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.460103` | `-0.460103` |
| `proposal` | `5.0` | `20` | `8` | `0` | `0.693750` | `0.831250` | `0.814062` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.174281` | `-0.174281` |
| `proposal` | `5.0` | `20` | `8` | `1` | `0.651563` | `0.834375` | `0.767188` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.394144` | `-0.394144` |

Decision:

- `v0.3-h4-5f route-hint dynamics margin`: `PASS` as diagnostics
- candidate discovery, top-1 selection, and route-code identity remain solved
  in every 128-key row above
- increasing `lambda_route` moves the effective route margin from negative to
  positive and recovers query accuracy to `1.000000` at `lambda_route = 10.0`
- increasing cycles does not monotonically help, and route-target proposal
  injection does not improve the current 128-key setting; proposal coverage is
  therefore not the primary bottleneck in this slice
- next: keep the value-position -> value-byte -> proposal-hint path, but add
  adaptive or confidence-gated route strength so strong hints are reserved for
  high-confidence candidates

## Adaptive Route Strength

`v0.3-h4-5g` adds margin-calibrated route strength:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh
```

The fixed route-hint path is unchanged. The new mode only changes the effective
route strength used inside the proposal delta:

```text
--route-strength-mode fixed
--route-strength-mode margin
--lambda-route-base 0.5
--lambda-route-max 10.0
--route-margin-alpha 1.0
--route-confidence-power 1.0
--route-min-confidence 0.0
```

The margin mode uses the local energy margin against the route target:

```text
lambda_route_eff = min(lambda_route_max,
                      lambda_route_base + alpha * max(0, local_margin))
```

The implementation caches the effective strength once per cycle so the local
margin is not recomputed for every sampled proposal. Diagnostics include:

- `route_strength_mean`
- `route_strength_p50`
- `route_strength_p90`
- `route_strength_max`

Reference 128-key standard readout, last-5:

| Scenario | mode | alpha | qacc | hi | lo | recall | top1 | route decode | effective margin | strength mean | p50 | p90 | max |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `fixed-low` | `fixed` | `1.0` | `0.173437` | `0.517188` | `0.262500` | `1.000000` | `1.000000` | `1.000000` | `-6.603894` | `0.500000` | `0.500000` | `0.500000` | `0.500000` |
| `fixed-strong` | `fixed` | `1.0` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `5.646099` | `10.000000` | `10.000000` | `10.000000` | `10.000000` |
| `adaptive-margin` | `margin` | `1.5` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `2.049732` | `6.454238` | `6.581428` | `9.950191` | `10.000000` |
| `alpha` | `margin` | `1.0` | `0.998438` | `1.000000` | `0.998438` | `1.000000` | `1.000000` | `1.000000` | `0.432887` | `4.871687` | `4.656845` | `8.664847` | `9.127506` |
| `alpha` | `margin` | `2.0` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `1.000000` | `2.877283` | `7.449980` | `8.629980` | `10.000000` | `10.000000` |

Decision:

- `v0.3-h4-5g adaptive route strength`: `PASS` as calibrated strength
  diagnostics
- retrieval remains perfect in all rows, so the comparison isolates
  hint-to-state conversion rather than candidate discovery
- adaptive margin mode recovers near/final query accuracy with lower mean
  strength than fixed `lambda_route = 10.0`
- `alpha = 1.0` is already nearly solved (`qacc = 0.998438`) with mean
  strength `4.871687`; `alpha = 1.5` fully solves the tested 128-key slice
  with mean strength `6.454238`
- this is still not learned semantic routing; it is a calibrated route-hint
  strength baseline under correct high-confidence route-code candidates
- next: add wrong-candidate/corruption stress and confidence guardrails before
  using strong adaptive hints with learned or noisy candidates

## Wrong-candidate Corruption Stress

`v0.3-h4-5h` adds a corruption stress helper:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh
```

The helper corrupts a fraction of query candidates by replacing the selected
`value_pos` with a wrong record value position. It compares:

- clean adaptive route strength
- corrupted candidates with confidence kept high
- corrupted candidates with low confidence and a minimum-confidence guard

New controls:

```text
--route-corrupt-candidate-rate
--route-corrupt-confidence keep|low
--route-corrupt-confidence-value
--route-min-confidence
```

New diagnostics:

- `route_candidate_corrupt_rate`
- `route_correct_candidate_rate`
- `route_wrong_hint_applied_rate`
- `route_wrong_hint_strength_mean`
- `route_correct_hint_strength_mean`

Reference 128-key standard readout, last-5:

| Scenario | corrupt rate | confidence | qacc | damage | corrupt observed | correct candidate | wrong strength | correct strength | strength mean |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `clean-adaptive` | `0.00` | `keep` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `0.000000` | `6.642268` | `6.642268` |
| `corrupt-keep` | `0.10` | `keep` | `0.867188` | `0.132812` | `0.132812` | `0.867188` | `5.664520` | `6.493022` | `6.382987` |
| `corrupt-lowconf` | `0.10` | `low` | `0.871875` | `0.128125` | `0.132812` | `0.867188` | `0.000000` | `7.536517` | `6.535573` |
| `corrupt-keep` | `0.25` | `keep` | `0.648438` | `0.351562` | `0.351562` | `0.648438` | `6.178977` | `6.339243` | `6.282900` |
| `corrupt-lowconf` | `0.25` | `low` | `0.662500` | `0.337500` | `0.351562` | `0.648438` | `0.000000` | `7.953271` | `5.157199` |

Decision:

- `v0.3-h4-5h wrong-candidate corruption stress`: `PASS` as confidence
  guardrail instrumentation
- when corrupted candidates keep high confidence, adaptive strength pushes wrong
  hints strongly and query accuracy degrades roughly with the observed
  corruption rate
- when corrupted candidates are marked low-confidence and
  `route_min_confidence = 0.5`, wrong hint strength is suppressed to `0.000000`
- the qacc damage improvement is modest in this fixture, so this should not be
  overclaimed as wrong-candidate robustness
- next: learn or estimate candidate confidence/ranking quality; strength
  guardrails help only when wrong candidates carry lower confidence

## Candidate / Value Confidence Calibration

`v0.3-h4-5i` adds a confidence calibration helper:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh
```

This slice preserves the route-hint path and tests whether confidence can
separate correct from wrong candidates/values under corruption with a preserved
correct fallback candidate.

New option:

```text
--route-strength-confidence weight|value-support
--route-corrupt-preserve-correct 0|1
```

Additional diagnostics:

- `route_candidate_conf_correct_mean`
- `route_candidate_conf_wrong_mean`
- `route_candidate_conf_gap`
- `route_value_top_correct_rate`
- `route_value_conf_correct_mean`
- `route_value_conf_wrong_mean`
- `route_value_conf_gap`

Reference 128-key standard readout, last-5:

| Scenario | confidence | corrupt rate | qacc | damage | corrupt observed | candidate conf gap | top value correct | value conf gap | wrong strength | correct strength |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `clean-reference` | `weight` | `0.00` | `1.000000` | `0.000000` | `0.000000` | `1.000000` | `1.000000` | `1.000000` | `0.000000` | `6.681508` |
| `corrupt-unscaled` | `weight` | `0.10` | `0.959375` | `0.040625` | `0.085938` | `0.000000` | `0.968750` | `0.479839` | `6.671535` | `6.642376` |
| `corrupt-valueconf` | `value-support` | `0.10` | `0.939062` | `0.060938` | `0.085938` | `0.000000` | `0.968750` | `0.479839` | `3.536750` | `6.724178` |
| `corrupt-unscaled` | `weight` | `0.25` | `0.853125` | `0.146875` | `0.210938` | `0.000000` | `0.937500` | `0.429167` | `5.874975` | `6.339989` |
| `corrupt-valueconf` | `value-support` | `0.25` | `0.837500` | `0.162500` | `0.210938` | `0.000000` | `0.937500` | `0.429167` | `3.596367` | `6.675715` |

Decision:

- `v0.3-h4-5i confidence calibration`: `PASS` as instrumentation
- candidate confidence based on route weight does not distinguish correct from
  wrong candidates in this diagnostic (`candidate_conf_gap = 0.000000`)
- value-support confidence does identify weaker support for wrong top values
  (`value_conf_gap > 0`) and reduces wrong hint strength
- reduced wrong hint strength does not improve qacc in this setting; it slightly
  increases damage because the fallback correct value is also weakened by the
  ambiguous vote
- next: add stronger ranking/confidence features, not just value-support
  scaling. Candidate confidence must become predictive before noisy learned
  routing claims.

## Scorer-agreement Confidence

`v0.3-h4-5j` adds scorer-agreement confidence:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh
```

This slice keeps the same value-bearing route-hint path and uses hard
agreement between four diagnostic scorers:

- insertion/top candidate
- value-vote top value
- recency/latest value position
- key-shape top value

New strength mode:

```text
--route-strength-confidence agreement
```

Additional diagnostics:

- `route_agreement_conf_correct_mean`
- `route_agreement_conf_wrong_mean`
- `route_agreement_conf_gap`
- `route_agreement_top_correct_rate`

Reference 128-key standard readout, last-5:

| Scenario | confidence | power | corrupt rate | qacc | damage | agreement gap | agreement top correct | wrong strength | correct strength |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `clean-reference` | `weight` | `1.0` | `0.00` | `1.000000` | `0.000000` | `1.000000` | `1.000000` | `0.000000` | `6.320159` |
| `corrupt-unscaled` | `weight` | `1.0` | `0.10` | `0.953125` | `0.046875` | `0.495868` | `0.945312` | `6.388133` | `6.441135` |
| `corrupt-valueconf` | `value-support` | `1.0` | `0.10` | `0.939062` | `0.060938` | `0.495868` | `0.945312` | `3.910505` | `6.729169` |
| `corrupt-agreement` | `agreement` | `1.0` | `0.10` | `0.940625` | `0.059375` | `0.495868` | `0.945312` | `3.734211` | `6.393201` |
| `corrupt-agreement-p2` | `agreement` | `2.0` | `0.10` | `0.939062` | `0.060938` | `0.495868` | `0.945312` | `2.807783` | `6.662031` |
| `corrupt-unscaled` | `weight` | `1.0` | `0.25` | `0.842188` | `0.157812` | `0.458020` | `0.890625` | `6.308168` | `6.314110` |
| `corrupt-valueconf` | `value-support` | `1.0` | `0.25` | `0.831250` | `0.168750` | `0.458020` | `0.890625` | `3.059740` | `6.488814` |
| `corrupt-agreement` | `agreement` | `1.0` | `0.25` | `0.843750` | `0.156250` | `0.458020` | `0.890625` | `3.775402` | `6.320678` |
| `corrupt-agreement-p2` | `agreement` | `2.0` | `0.25` | `0.832812` | `0.167188` | `0.458020` | `0.890625` | `2.423250` | `6.414787` |

Decision:

- `v0.3-h4-5j scorer-agreement confidence`: `PASS` as confidence
  instrumentation
- agreement confidence has a positive separation signal
  (`agreement_conf_gap > 0`) under corruption
- agreement scaling reduces wrong hint strength relative to unscaled margin
  strength
- this is only a limited mitigation: qacc does not consistently improve over
  unscaled/value-support, and stronger `confidence_power = 2.0` suppresses wrong
  hints further while also weakening useful signal
- next: test confidence-gated aggregation, where low-confidence buckets switch
  to broader vote/fallback behavior instead of only scaling route strength

## Confidence-gated Aggregation

`v0.3-h4-5k` adds confidence-gated aggregation:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh
```

This slice does not use confidence as a strength multiplier. Instead, it uses
confidence to choose the aggregation policy:

```text
--route-hint-agg confidence-gated
--route-aggregation-confidence agreement
--route-confidence-threshold 0.75
--route-lowconf-agg vote
--route-highconf-agg weighted-vote
```

Additional diagnostics:

- `route_lowconf_query_rate`
- `route_highconf_query_rate`
- `route_lowconf_qacc`
- `route_highconf_qacc`
- `route_lowconf_wrong_strength_mean`
- `route_highconf_wrong_strength_mean`
- `route_agg_policy_vote_rate`
- `route_agg_policy_weighted_rate`

Reference 128-key preserve-correct standard readout, last-5:

| Scenario | corrupt rate | qacc | damage | lowconf rate | highconf rate | low qacc | high qacc | vote policy | weighted policy | wrong strength |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `corrupt-unscaled` | `0.10` | `0.953125` | `0.046875` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `6.742592` |
| `corrupt-valueconf` | `0.10` | `0.940625` | `0.059375` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `3.881346` |
| `corrupt-agreement` | `0.10` | `0.950000` | `0.050000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `4.684187` |
| `corrupt-gated-agg` | `0.10` | `0.953125` | `0.046875` | `0.070312` | `0.929688` | `0.333333` | `1.000000` | `0.070312` | `0.929688` | `6.742592` |
| `corrupt-unscaled` | `0.25` | `0.850000` | `0.150000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `5.286897` |
| `corrupt-valueconf` | `0.25` | `0.831250` | `0.168750` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `3.242260` |
| `corrupt-agreement` | `0.25` | `0.834375` | `0.165625` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `0.000000` | `3.987625` |
| `corrupt-gated-agg` | `0.25` | `0.851563` | `0.148437` | `0.187500` | `0.812500` | `0.250000` | `0.990385` | `0.187500` | `0.812500` | `5.806380` |

Decision:

- `v0.3-h4-5k confidence-gated aggregation`: `PASS` as aggregation-policy
  instrumentation
- the low/high confidence split is observable, and the policy switch uses both
  `vote` and `weighted-vote`
- the preserve-correct corruption `0.25` run is a limited mitigation:
  `qacc` is slightly above unscaled (`0.851563` vs `0.850000`) and above the
  value-support/agreement strength-scaled arms
- wrong hint strength is not reliably reduced by this policy, so this is still
  not wrong-candidate robustness solved
- next: compare remove-correct vs preserve-correct in the full runner and test
  redundant candidate sources or a learned scorer that preserves correct
  support while lowering wrong support

## Low-confidence Subset Diagnostics

`v0.3-h4-5l` adds low/high confidence subset diagnostics:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh
```

This slice does not change route behavior. It keeps the h4-5k policy and splits
the remaining query failures into low-confidence and high-confidence buckets.

Additional diagnostics:

- `route_lowconf_candidate_recall`
- `route_highconf_candidate_recall`
- `route_lowconf_top1`
- `route_highconf_top1`
- `route_lowconf_correct_value_vote_share`
- `route_highconf_correct_value_vote_share`
- `route_lowconf_unique_values`
- `route_highconf_unique_values`
- `route_lowconf_vote_entropy`
- `route_highconf_vote_entropy`
- `route_lowconf_route_margin`
- `route_highconf_route_margin`
- `route_lowconf_local_margin`
- `route_highconf_local_margin`
- `route_lowconf_hi_acc`
- `route_highconf_hi_acc`
- `route_lowconf_lo_acc`
- `route_highconf_lo_acc`

Reference 128-key smoke readout, last-5, corruption `0.25`:

| Scenario | qacc | damage | low rate | high rate | low qacc | high qacc | low recall | high recall | low top1 | high top1 | low share | high share | low entropy | high entropy |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `preserve-correct` | `0.853125` | `0.146875` | `0.187500` | `0.812500` | `0.258333` | `0.990385` | `1.000000` | `1.000000` | `0.000000` | `0.971154` | `0.500000` | `0.993590` | `1.000000` | `0.008830` |
| `remove-correct` | `0.804688` | `0.195312` | `0.000000` | `1.000000` | `0.000000` | `0.804688` | `0.000000` | `0.789062` | `0.000000` | `0.789062` | `0.000000` | `0.804688` | `0.000000` | `0.000000` |

Decision:

- `v0.3-h4-5l low-confidence subset diagnostics`: `PASS` as diagnostics and
  actionable split
- in preserve-correct corruption, low-confidence failures are not retrieval
  failures: `lowconf_candidate_recall = 1.000000`
- the preserve-correct low-confidence subset is an aggregation/ranking problem:
  `lowconf_top1 = 0.000000`, `correct_value_vote_share = 0.500000`, and
  `vote_entropy = 1.000000`
- in remove-correct corruption, recall drops because the correct candidate is
  removed, so recovery requires fallback/redundant candidate sources or abstain
  behavior
- this is still not wrong-candidate robustness solved; it identifies the next
  intervention target

## Low-confidence Policy Split

`v0.3-h4-5m` adds the low-confidence policy instrumentation slice:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh --full
```

This slice keeps the same confidence-gated route setup as h4-5k/h4-5l:

```text
--route-hint-agg confidence-gated
--route-aggregation-confidence agreement
--route-confidence-threshold 0.75
--route-highconf-agg weighted-vote
--route-strength-confidence weight
--route-strength-mode margin
--route-lowconf-policy aggregate|none|weak-vote
--route-lowconf-weak-scale 0.5
```

Additional diagnostics:

- `route_lowconf_policy_none_rate`
- `route_lowconf_policy_weak_vote_rate`
- `route_lowconf_policy_aggregate_rate`
- `route_lowconf_effective_strength_mean`
- `route_highconf_effective_strength_mean`

Smoke readout at preserve/remove corruption `0.25`:

- preserve-correct `aggregate`: `qacc = 0.854688`, `damage = 0.145312`,
  `lowconf_qacc = 0.275000`, `highconf_qacc = 0.988462`,
  `lowconf_candidate_recall = 1.000000`, `lowconf_top1 = 0.000000`
- preserve-correct `none`: `qacc = 0.812500`, `damage = 0.187500`,
  `lowconf_effective_strength_mean = 0.000000`
- preserve-correct `weak-vote`: `qacc = 0.848438`, `damage = 0.151562`,
  `lowconf_effective_strength_mean = 4.623492`
- remove-correct rows stay at `qacc = 0.804688`; the agreement threshold puts
  all queries in the high-confidence bucket, but candidate recall drops to
  `0.789062`, so this branch still needs fallback or redundant candidate source
  work

Decision:

- `v0.3-h4-5m low-confidence policy split`: `PASS` as policy
  instrumentation and actionable split
- preserve-correct is an aggregation/ranking problem: the correct candidate is
  present, `none` hurts, and `weak-vote` is close to aggregate but weaker
- remove-correct is a candidate availability problem: changing low-confidence
  aggregation cannot help when the correct candidate is absent from the bucket
- this is not wrong-candidate robustness solved; the next intervention should
  separate aggregation/ranking improvements from fallback/abstain or redundant
  source work

## Low-confidence Fallback Source

`v0.3-h4-5n` adds a diagnostic fallback source:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh --full
```

New option:

```text
--route-fallback-source off|raw-key|key-shape
```

New diagnostics:

- `route_primary_recall`
- `route_primary_lowconf_rate`
- `route_fallback_used_rate`
- `route_fallback_recall`
- `route_fallback_qacc`
- `route_fallback_success_rate`
- `route_abstain_rate`

Smoke readout at corruption `0.25`:

- preserve-correct: fallback remains unused because primary recall is already
  `1.000000`; `key-shape` matches `off` at `qacc = 0.854688`
- remove-correct `off`: `qacc = 0.804688`, `route_primary_recall = 0.789062`
- remove-correct `key-shape`: `qacc = 0.839062`,
  `route_fallback_used_rate = 0.210938`, `route_fallback_recall = 1.000000`,
  `route_fallback_success_rate = 1.000000`
- fallback-used subset qacc is still low (`0.237037`), so the source recovers
  candidate availability but does not by itself solve state convergence

Decision:

- `v0.3-h4-5n low-confidence fallback source`: `PASS` as fallback-source
  instrumentation and limited mitigation
- the key-shape fallback is a symbolic diagnostic upper-bound, not learned
  routing
- remove-correct now has recovered candidate recall, but the low fallback-used
  qacc shows that the next bottleneck is fallback hint integration/dynamics, not
  candidate discovery alone

## Projected Route-hint Delta

`v0.3-h4-5o` keeps the route reaction inside the query node's proposal delta.
It does not distribute reaction into neighbors and does not modify local
topology.

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh --full
```

New options:

```text
--route-delta-mode target-only|projected
--route-pull-scale <float>
--route-push-scale <float>
```

Implementation:

- `target-only` is the default and preserves the previous route-hint behavior
- `projected` is the C-version projected delta:
  - entering the routed target nibble gets route reward
  - leaving the routed target nibble gets route penalty
  - all other route-hint contribution is neutral
- this is local to the query node's proposal energy and preserves the
  `candidate value_pos -> value byte read -> proposal hint` path

Additional fallback subset diagnostics:

- `route_fallback_hi_acc`
- `route_fallback_lo_acc`
- `route_fallback_route_margin_mean`
- `route_fallback_effective_strength_mean`

Smoke readout at corruption `0.25`:

- `projected 1.0/1.0` matches `target-only`, as expected for the C-version at
  equal scales
- preserve-correct: `target-only qacc = 0.854688`; `projected pull=2.0 push=1.0`
  reaches `qacc = 0.875000`
- remove-correct with key-shape fallback: `target-only qacc = 0.839062`,
  `fallback_qacc = 0.237037`; `projected pull=2.0 push=1.0` stays at
  `qacc = 0.839062`, `fallback_qacc = 0.237037`
- fallback subset remains asymmetric (`hi_acc` high, `lo_acc` low), so the
  remaining bottleneck is not solved by a stronger projected pull alone

Decision:

- `v0.3-h4-5o projected route-hint delta`: `PASS` as projected-delta
  instrumentation and limited mitigation
- it is not fallback integration solved and not wrong-candidate robustness
  solved
- spatial dragging / neighbor reaction remains out of scope and should stay
  deferred

## Fallback Hint Strength Diagnostics

`v0.3-h4-5p` extends the h4-5n/h4-5o setup with a fallback-used-query-only
strength multiplier. It is diagnostic-only and exists to test whether the last
bottleneck is hint integration/strength rather than fallback-source discovery.

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh --full
```

New option:

```text
--route-fallback-strength-mult <float>
```

New summary columns:

- `route_fallback_strength_mult`
- `route_fallback_effective_strength_mean`

The runner keeps the h4-5n fallback source and the h4-5o delta setup, then
sweeps `1.0`, `2.0`, `5.0`, and `10.0` on remove-correct key-shape rows. It
also keeps target-only and projected `pull=2.0` baselines when that extra check
is cheap. Read the result as a bottleneck diagnostic only; it does not imply
fallback robustness is solved.

Smoke readout at preserve/remove corruption `0.25`:

- target-only key-shape fallback improves with fallback-only strength:
  - `mult=1.0`: qacc `0.839062`, fallback_qacc `0.237037`,
    fallback effective strength `5.446080`
  - `mult=5.0`: qacc `0.876563`, fallback_qacc `0.414815`,
    fallback effective strength `27.167871`
  - `mult=10.0`: qacc `0.898437`, fallback_qacc `0.518518`,
    fallback effective strength `55.376972`
- projected `pull=2.0` also improves at moderate multiplier, but is less
  monotonic:
  - `mult=1.0`: qacc `0.839062`, fallback_qacc `0.237037`
  - `mult=2.0`: qacc `0.862500`, fallback_qacc `0.348148`
  - `mult=5.0`: qacc `0.868750`, fallback_qacc `0.377777`
  - `mult=10.0`: qacc `0.846875`, fallback_qacc `0.274074`

Decision:

- `v0.3-h4-5p fallback hint strength`: `PASS` as fallback-strength
  diagnostics and limited mitigation
- the fallback candidate is already recovered; the improvement shows that
  fallback-used query failure is partly strength / hint-integration limited
- this still uses symbolic key-shape fallback and a hand-set multiplier, so it
  is not learned routing, not fallback robustness solved, and not a general
  wrong-candidate robustness solution

## Fallback Adaptive Strength

`v0.3-h4-5q` replaces the hand-set fallback-only multiplier with a fallback-
specific margin strength mode:

```text
--route-fallback-strength-mode fixed|margin
--route-fallback-strength-mult <float>
--route-fallback-lambda-base <float>
--route-fallback-lambda-max <float>
--route-fallback-margin-alpha <float>
```

In `fixed` mode, fallback-used queries keep the h4-5p behavior: the normal
route strength is multiplied by `route_fallback_strength_mult`. In `margin`
mode, fallback-used queries use a separate local-margin strength:

```text
fallback_strength =
  route_fallback_lambda_base
  + route_fallback_margin_alpha * max(0, local_margin_against_route)
```

then apply `route_fallback_lambda_max` as a cap. This affects only fallback-used
query nodes; primary route nodes and local topology are unchanged.

Additional fallback subset diagnostics:

- `route_fallback_strength_p50`
- `route_fallback_strength_p90`
- `route_fallback_strength_max`
- `route_fallback_local_margin_against_route_mean`

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh
```

Smoke readout at remove-correct corruption `0.25`:

- fixed `mult=1.0`: qacc `0.839062`, fallback_qacc `0.237037`,
  fallback strength mean `5.446080`
- fixed `mult=10.0`: qacc `0.898437`, fallback_qacc `0.518518`,
  fallback strength mean `55.376972`
- fallback margin `alpha=6.0`, max `40.0`: qacc `0.864062`,
  fallback_qacc `0.355555`, fallback strength mean `21.749088`
- fallback margin `alpha=8.0`, max `40.0`: qacc `0.873437`,
  fallback_qacc `0.400000`, fallback strength mean `25.902632`

Decision:

- `v0.3-h4-5q fallback adaptive strength`: `PASS` as fallback-adaptive
  diagnostics and lower-strength limited mitigation
- fallback-specific margin strength improves fallback-used qacc with much lower
  mean strength than fixed `mult=10.0`
- it does not match fixed strong performance yet, so the next candidate remains
  fallback persistence / TTL rather than claiming fallback robustness
- this still uses symbolic key-shape fallback and is not learned routing,
  fallback robustness solved, or wrong-candidate robustness solved

## Fallback Channel-specific Strength

`v0.3-h4-5r` follows the h4-5p/q finding that fallback-used query states move
when their route hint is stronger. The core already applies route hints on every
cycle within an epoch, so this slice keeps behavior query-local and instead
separates fallback-used high/low nibble route delta strength:

```text
--route-fallback-hi-strength-mult <float>
--route-fallback-lo-strength-mult <float>
```

These multipliers affect only fallback-used query nodes. Primary route nodes,
candidate retrieval, fallback source selection, and local topology are
unchanged.

Additional fallback subset diagnostics:

- `route_fallback_hi_effective_strength_mean`
- `route_fallback_lo_effective_strength_mean`

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh
```

Smoke readout at remove-correct corruption `0.25`, fixed fallback `mult=5.0`:

- balanced hi/lo `1.0/1.0`: qacc `0.887500`, fallback_qacc `0.466666`,
  fallback_hi_acc `0.800000`, fallback_lo_acc `0.600000`
- low-channel boost hi/lo `1.0/2.0`: qacc `0.904687`,
  fallback_qacc `0.548148`, fallback_hi_acc `0.800000`,
  fallback_lo_acc `0.674074`
- high-channel boost hi/lo `2.0/1.0`: qacc `0.868750`,
  fallback_qacc `0.377778`, fallback_hi_acc `0.785185`,
  fallback_lo_acc `0.533333`

Decision:

- `v0.3-h4-5r fallback channel strength`: `PASS` as fallback-channel
  diagnostics and limited mitigation
- the residual fallback-used integration bottleneck appears more low-nibble
  sensitive in this smoke
- this is not fallback robustness solved, not learned routing, and not
  wrong-candidate robustness solved; it is a hand-set channel diagnostic on top
  of symbolic key-shape fallback

## Fallback Channel-adaptive Strength

`v0.3-h4-5s` extends h4-5r from hand-set channel multipliers to fallback-used
channel-local margin strength. The goal is not to solve fallback robustness; it
is to test whether the low-nibble-sensitive path can be calibrated by a
channel-specific local margin.

```text
--route-fallback-channel-strength-mode fixed|margin
--route-fallback-hi-margin-alpha <float>
--route-fallback-lo-margin-alpha <float>
--route-fallback-hi-lambda-base <float>
--route-fallback-lo-lambda-base <float>
--route-fallback-hi-lambda-max <float>
--route-fallback-lo-lambda-max <float>
```

In `margin` mode, fallback-used query nodes use channel-specific strength:

```text
fallback_strength_c =
  route_fallback_{hi,lo}_lambda_base
  + route_fallback_{hi,lo}_margin_alpha * max(0, local_channel_margin_c)
```

then apply the corresponding channel cap. Primary route nodes and the local
topology remain unchanged.

Additional diagnostics:

- `route_fallback_hi_local_margin_against_route_mean`
- `route_fallback_lo_local_margin_against_route_mean`

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh
```

Smoke readout at remove-correct corruption `0.25`:

- fixed lo-boost: qacc `0.900000`, fallback_qacc `0.525926`,
  hi_eff `26.685386`, lo_eff `53.370773`
- margin-balanced: qacc `0.864062`, fallback_qacc `0.355555`,
  hi_eff `9.961847`, lo_eff `16.427150`
- margin-lo-biased: qacc `0.871875`, fallback_qacc `0.392592`,
  hi_eff `9.980158`, lo_eff `23.382717`

Decision:

- `v0.3-h4-5s fallback channel-adaptive strength`: `PASS` as
  channel-adaptive instrumentation and lower-strength limited mitigation
- lo-biased channel margin improves over balanced channel margin, confirming
  that the low-channel adaptive path is wired and relevant
- fixed lo-boost remains stronger, so this is not fallback robustness solved
  and not learned routing solved

## Low-nibble Fallback Strength Grid

`v0.3-h4-5t` is a calibration slice before fallback persistence / TTL. It uses
the existing h4-5r fallback channel multipliers and keeps high-channel
multiplier fixed while sweeping low-channel multiplier:

```text
route_fallback_hi_strength_mult = 5.0
route_fallback_lo_strength_mult = 5.0, 7.5, 10.0, 15.0
```

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh
```

Smoke readout at remove-correct corruption `0.25`:

- `lo5`: qacc `0.873438`, fallback_qacc `0.400000`,
  fallback_hi_acc `0.800000`, fallback_lo_acc `0.533333`
- `lo7.5`: qacc `0.903125`, fallback_qacc `0.540741`,
  fallback_hi_acc `0.800000`, fallback_lo_acc `0.666667`
- `lo10`: qacc `0.904688`, fallback_qacc `0.548148`,
  fallback_hi_acc `0.800000`, fallback_lo_acc `0.674074`
- `lo15`: qacc `0.901562`, fallback_qacc `0.533333`,
  fallback_hi_acc `0.800000`, fallback_lo_acc `0.659260`

Decision:

- `v0.3-h4-5t low-nibble fallback strength grid`: `PASS` as low-channel
  strength calibration and limited mitigation
- the current smoke has a narrow sweet spot around `lo_mult=7.5..10.0`; pushing
  to `15.0` mildly degrades fallback_qacc
- this does not solve fallback robustness, but it gives a calibrated static
  strength target for the next fallback persistence / TTL slice

## Fallback Persistence / TTL Diagnostics

`v0.3-h4-5u` tests whether the calibrated fallback low-channel strength still
needs a short persistence window. Since route hints already affect proposal
delta on every cycle, this slice interprets TTL narrowly as fallback-used query
update-priority persistence: fallback-used nodes bypass tick throttling for the
first `route_fallback_persist_cycles` cycles of the epoch.

```text
--route-fallback-persist-cycles <int>
```

Additional diagnostics:

- `route_fallback_persist_used_rate`
- `route_fallback_persist_cycles_mean`

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh
```

Smoke readout at remove-correct corruption `0.25`:

- `lo7.5 ttl0`: qacc `0.903125`, fallback_qacc `0.540741`,
  persist_used `0.000000`, persist_cycles `0.000000`
- `lo7.5 ttl3`: qacc `0.900000`, fallback_qacc `0.525926`,
  persist_used `1.000000`, persist_cycles `3.000000`
- `lo10 ttl0`: qacc `0.904688`, fallback_qacc `0.548148`,
  persist_used `0.000000`, persist_cycles `0.000000`
- `lo10 ttl3`: qacc `0.904688`, fallback_qacc `0.548148`,
  persist_used `1.000000`, persist_cycles `3.000000`

Decision:

- `v0.3-h4-5u fallback persistence / TTL`: `PASS` as persistence
  instrumentation and neutral diagnostics
- the persistence hook and metrics are wired, but the current short TTL
  priority policy does not improve fallback_qacc over the h4-5t static
  low-channel sweet spot
- this is not fallback robustness solved and not learned routing solved

## Route-credit Slashing / Binding Diagnostics

`v0.3-h4-5v` starts route-credit learning as a diagnostic ledger over
candidate value positions. It does not touch tick/reservoir credit, local
topology, or `route_field_` identity code. The successful path remains:

```text
candidate value_pos
-> value byte read
-> proposal hint
```

Initial credit scope:

```text
--route-credit-learning <0|1>
--route-credit-mode value-pos
--route-credit-score-weight <float>
--route-credit-eta-reward <float>
--route-credit-eta-slash <float>
--route-credit-decay <float>
--route-credit-clip <float>
```

Credit update:

```text
candidate value byte == target byte -> reward value_pos credit
candidate value byte != target byte -> slash value_pos credit
```

When enabled, weighted-vote candidate weights are multiplied by
`exp(route_credit_score_weight * credit[value_pos])`.

Additional diagnostics:

- `route_credit_correct_mean`
- `route_credit_wrong_mean`
- `route_credit_gap`
- `route_credit_rewarded_rate`
- `route_credit_slashed_rate`
- `route_credit_top1_rate`
- `route_credit_qacc`

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh
```

Smoke readout on preserve-correct corruption:

- `credit_off`: qacc `0.845312`, credit gap `0.000000`
- `credit_on`: qacc `0.850000`, correct credit `0.313938`,
  wrong credit `-0.796331`, credit gap `1.110268`,
  rewarded rate `0.696774`, slashed rate `0.283871`

Decision:

- `v0.3-h4-5v route-credit`: `PASS` as route-credit separation
  instrumentation and tiny mitigation
- the ledger distinguishes correct and wrong value-position candidates, and
  the weighting path is active
- the qacc move is small, so this is not wrong-candidate robustness solved and
  not learned routing solved

Interpretation:

- route credit can accumulate a candidate-quality signal: correct candidate
  value positions move positive, while wrong candidate value positions move
  negative
- the small qacc move means the current ledger is not yet enough to turn credit
  separation into robust query prediction
- likely remaining issues are credit score strength, reward/slash balance,
  credit memory/clip settings, value-position granularity, and fallback hint
  integration dynamics

Next route-credit ablation:

```text
v0.3-h4-5w route-credit ablation
```

Recommended knobs:

- `--route-credit-score-weight`: `0.5`, `1.0`, `2.0`, `4.0`
- `--route-credit-eta-reward` / `--route-credit-eta-slash` ratios, especially
  stronger slash settings such as `0.05/0.20` and `0.10/0.20`
- `--route-credit-decay`: `0.0`, `0.001`, `0.01`
- `--route-credit-clip`: `2`, `4`, `8`
- compare value-position credit with future `(query_signature, value_pos)`
  edge credit
- combine credit with fallback low-channel strength, especially the h4-5t
  `hi_mult=5`, `lo_mult=7.5..10` sweet spot

Success criteria for h4-5w should be modest:

- `credit_gap` remains positive or increases
- qacc rises more reliably above credit-off
- wrong hint/value influence decreases without suppressing correct support
- query-value probe stays wired in the smoke so the mode split remains visible
- if qacc still does not move, document that route credit is connected but
  needs stronger granularity or integration with fallback/channel dynamics

## h4-5w Route-credit Ablation Decision

`v0.3-h4-5w` passes as route-credit ablation instrumentation and limited
mitigation.

New behavior:

- `--route-credit-mode value-pos|query-value`
- value-pos credit keeps the h4-5v ledger behavior
- query-value mode stores credit on a deterministic query signature plus
  candidate `value_pos` edge
- weighted-vote uses the same exp-scaled credit weight, but looks up the ledger
  according to the selected mode

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh
```

Smoke readout:

- `value-pos-base`: qacc `0.862500`, credit gap `0.000000`
- `value-pos-strong-slash`: qacc `0.862500`, credit gap `0.618182`
- `query-value-probe`: qacc `0.862500`, credit gap `0.598951`
- `fallback-lo7p5-off`: qacc `0.912500`, fallback_qacc `0.688889`
- `fallback-lo10-on`: qacc `0.937500`, fallback_qacc `0.777778`,
  credit gap `0.812801`

Interpretation:

- query-value edge credit is now wired and can separate correct/wrong
  candidate edges in the smoke
- stronger slash/weight settings change credit separation, but the clean
  preserve-correct qacc is neutral in this small smoke
- combining credit with the low-channel fallback sweet spot can improve the
  fallback subset, suggesting credit/ranking and fallback integration may need
  to be tuned together

This is still not wrong-candidate robustness solved and not learned routing
solved. Treat it as ablation diagnostics plus limited mitigation.

## h4-5x Credit × Fallback Integration Factorial Decision

`v0.3-h4-5x` passes as credit × fallback integration diagnostics and limited
mitigation, but it does not solve wrong-candidate robustness or learned
routing.

The factorial smoke reuses the key-shape fallback sweet spot at `hi_mult=5`
and `lo_mult=7.5/10/15`, then compares true `off`, `value-pos`, and
`query-value` route credit on both preserve-correct and remove-correct rows.
The C++ core now accepts `--route-credit-mode off` as a real no-credit control.

Key smoke readouts:

- preserve-correct rows remain neutral in qacc (`0.862500`) while credit
  separates candidates (`value-pos gap = 0.463636`, `query-value gap =
  0.750000`)
- remove-correct `lo=7.5`: `off qacc = 0.912500`, credit-on qacc =
  `0.925000`
- remove-correct `lo=10`: `off qacc = 0.912500`, credit-on qacc =
  `0.925000`
- remove-correct `lo=15`: `off qacc = 0.906250`, credit-on qacc =
  `0.918750`
- remove-correct fallback_qacc improves from `0.688889` off to `0.733334`
  with credit at `lo=7.5/10`, but falls to `0.711111` at `lo=15`

Interpretation:
route credit provides a candidate-quality separation signal, and it gives a
small qacc/fallback_qacc lift when combined with key-shape fallback low-channel
integration. The effect is still narrow and non-final: `lo=15` remains weaker
than the `7.5/10` region, and this is still symbolic fallback instrumentation.

Smoke command:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
./experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
```

Next:
run score/slash calibration around the `lo=7.5..10` region before promoting
route credit toward a persistent h5 route-plasticity mechanism.

## h4-5y Route-credit Strength/Stability Calibration Decision

`v0.3-h4-5y` passes as route-credit strength/stability calibration diagnostics
and limited mitigation, but it does not solve wrong-candidate robustness or
learned routing.

The calibration smoke keeps the value-bearing path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

It probes active `value-pos` and `query-value` route credit around the
key-shape fallback sweet spot, while retaining true `off` rows as no-credit
baselines.

Key smoke readouts:

- off baselines remain credit-neutral (`route_credit_gap = 0.000000`)
- `query-value` preserve rows keep a strong credit gap (`0.750000`)
- value-pos preserve rows are positive but smaller (`0.290625` at one low
  corruption row and `0.236364` at one higher corruption row)
- remove-correct rows populate fallback diagnostics; for example:
  - value-pos `lo=10`, score weight `1.0`, slash `0.20`, corruption `0.25`:
    qacc `0.925000`, credit gap `0.642326`, fallback_qacc `0.733334`
  - query-value `lo=7.5`, score weight `2.0`, slash `0.10`, corruption
    `0.25`: qacc `0.925000`, credit gap `0.450000`, fallback_qacc `0.733334`

Interpretation:
query-value credit continues to be the cleaner separation signal, but the
qacc/fallback_qacc effect remains condition-dependent and limited. This keeps
h4-5y in the calibration/instrumentation category. It is not a learned routing
or robustness claim.

Next:
either run the full h4-5y grid to choose a stable carry-forward cell, or move
to a very narrow h5-a route-plasticity slice using the best query-value credit
settings as the diagnostic baseline.

## h5-a Persistent Route-plasticity Ledger Decision

`h5-a` passes as route-plasticity ledger instrumentation, but it does not solve
wrong-candidate robustness or learned routing.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

New knobs:

- `--route-plasticity-ledger <0|1>`
- `--route-plasticity-ledger-decay <float>`
- `--route-credit-learn-after-epoch <int>`
- `--route-credit-apply-after-epoch <int>`

Interpretation:
the ledger makes route credit a persistent query/value identity memory, while
the learn/apply gates separate when credit is accumulated from when it is used
to weight candidate votes. The h5-a smoke verifies that ledger size and mean
absolute credit become nonzero, that route credit keeps a positive
correct/wrong gap, and that candidate lookup/read distance remain populated.

Guardrails:
the smoke also verifies `routing_trigger_rate = 0.000000` and
`active_jump_rate = 0.000000`. This means h5-a remains on the value-bearing
route-hint path and does not revive neighbor replacement.

Smoke command:

```bash
./experiments/test_v05_route_credit_plasticity.sh
```

Current narrow readout:

- immediate remove-correct row: qacc `0.931250`, credit gap `1.500000`,
  ledger size `59.000000`, fallback_qacc `0.755556`
- warmup-apply remove-correct row: qacc `0.918750`, apply-active rate
  `0.400000`, fallback_qacc `0.711111`
- delayed-learn remove-correct row: qacc `0.918750`, credit gap `0.750000`,
  fallback_qacc `0.711111`

This is instrumentation, not a robustness claim. The next step is to run the
full h5-a grid or add a narrow h5-b source-level credit/fallback policy only
after the ledger schedule behavior is stable.

## h5-b Source/Bucket Route-credit Decision

`h5-b` passes as source/bucket route-credit instrumentation and a responsibility
signal, but it does not solve fallback robustness, wrong-candidate robustness,
or learned routing.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

New knobs:

- `--route-source-credit-learning <0|1>`
- `--route-source-credit-score-weight <float>`
- `--route-source-credit-eta-reward <float>`
- `--route-source-credit-eta-slash <float>`
- `--route-source-credit-decay <float>`
- `--route-source-credit-clip <float>`

Interpretation:
source credit is keyed by query/source/bucket rather than by `value_pos`, so it
tracks whether the primary route-code source provided the correct candidate and
whether the fallback source recovered a missing candidate. Candidate/edge
ranking remains the job of `value-pos`, `query-value`, and persistent
route-plasticity ledgers.

Smoke command:

```bash
./experiments/test_v05_route_source_credit.sh
```

Current narrow readout:

- source-off remove-correct: qacc `0.912500`, source credit size `0.000000`,
  source gap `0.000000`
- source-on remove-correct: qacc `0.912500`, source credit size `73.000000`,
  primary mean `0.023438`, fallback mean `0.300000`, source gap `0.276563`,
  primary slashed rate `0.281250`, fallback rewarded rate `1.000000`
- source-on preserve-correct: qacc `0.818750`, fallback used rate `0.000000`,
  primary mean `0.150000`

Guardrails:
the smoke verifies `route_hint_candidate_lookup_count > 0`,
`route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
and `active_jump_rate = 0.000000`. This keeps h5-b on the value-bearing
route-hint path and does not revive neighbor replacement.

This is source/bucket responsibility instrumentation. qacc is neutral in the
smoke, so it is not a fallback robustness or learned-routing claim. The next
step is to calibrate whether source/bucket credit should influence fallback
selection more strongly or combine with the persistent query/value ledger.

## h5-c Source-credit Policy Calibration Decision

`h5-c` passes as source-credit / persistent-ledger policy calibration
instrumentation, but it does not solve fallback robustness, wrong-candidate
robustness, or learned routing.

The slice separates source-credit learning from how the learned
source/bucket responsibility signal is applied:

- `--route-source-credit-learning`
- `--route-source-credit-score-weight`
- `--route-source-credit-eta-reward`
- `--route-source-credit-eta-slash`
- `--route-plasticity-ledger`
- `--route-credit-learning`
- `--route-credit-mode query-value`
- `--route-credit-learn-after-epoch`
- `--route-credit-apply-after-epoch`

The successful nonlocal path remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_policy.sh
./experiments/run_v05_route_source_credit_policy.sh --full
```

Current narrow readout on remove-correct corruption:

- source-off: qacc `0.000000`, source credit size `0.000000`, source gap
  `0.000000`
- learn-only: qacc `0.000000`, source credit size `73.000000`, source gap
  `0.276563`, source apply active `0.000000`
- ranking: qacc `0.000000`, source gap `0.276563`, source apply active
  `1.000000`
- ranking-strength: qacc `0.000000`, source gap `0.553125`, source apply
  active `1.000000`
- ledger-off: qacc `0.931250`, credit gap `1.500000`, ledger size `0.000000`
- ledger-on: qacc `0.931250`, credit gap `1.500000`, ledger size `59.000000`,
  ledger mean abs credit `0.711864`

Guardrails:
the smoke verifies `route_hint_candidate_lookup_count > 0`,
`route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
and `active_jump_rate = 0.000000`. This keeps h5-c on the value-bearing
route-hint path and does not revive neighbor replacement.

Interpretation:
source credit now has separate learn-only, ranking, strength, and persistent
ledger policy controls. In the current smoke, the source-only rows are
qacc-neutral while the ledger rows stay at `0.931250`; the knobs are wired and
measurable, but this is still policy instrumentation, not a robustness
solution. The next step is to test whether stronger source-credit policy
application improves fallback choice or to introduce noisier learned candidate
sources where source preference can matter more.

## h5-d Noisy / Learned-like Source Policy Diagnostics Decision

`h5-d` passes as noisy / learned-like source policy diagnostics and
source-quality separation instrumentation, but it does not solve fallback
robustness, wrong-candidate robustness, or learned routing.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

New knobs and branches:

- `--route-hash-source joint-code-key`
- `--route-fallback-source key-shape`
- `--route-fallback-source noisy-route-code`
- `--route-noisy-source-rate`
- `--route-source-credit-learning`
- `--route-source-credit-apply-mode off|ranking|ranking-strength`
- `--route-plasticity-ledger`
- `--route-corrupt-candidate-rate 0.25`
- `--route-corrupt-preserve-correct 0`

Interpretation:
the smoke has two controlled source-quality branches. The weak learned-like
branch uses `joint-code-key` as primary and symbolic `key-shape` as fallback;
it should learn a positive source gap for the useful fallback source. The bad
source branch uses `route-code-key` primary plus `noisy-route-code` fallback
and `--route-noisy-source-rate 1.0`; it should learn a negative source gap and
populate the noisy-source credit/slash diagnostics. Both branches remain
diagnostic fixtures and keep key-shape as a symbolic upper-bound fallback, not
a learned routing claim.

Smoke command:

```bash
./experiments/test_v05_route_source_credit_noisy_source.sh
```

Current narrow readout:

- joint-source off stays neutral
- joint-source learn-only accumulates fallback source credit without applying it
- joint-source ranking selects the key-shape fallback more often, and
  ranking-strength adds source weighting
- noisy-source learn-only/ranking rows learn a negative source gap for bad
  noisy candidates
- noisy-source rows expose `route_source_credit_noisy_mean < 0` and nonzero
  `route_source_credit_noisy_slashed_rate`
- ledger-on rows add persistent state only
- all rows keep `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`

This is source-quality instrumentation, not a robustness claim.

## h5-e Noisy-source Multi-seed / Scale Stability Decision

`h5-e` passes as noisy-source multi-seed / scale stability instrumentation,
but it does not solve source-credit robustness, wrong-candidate robustness, or
learned routing.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_noisy_scale.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_noisy_scale.sh
./experiments/run_v05_route_source_credit_noisy_scale.sh --full
```

Smoke grid:

- key counts `32/64`
- seeds `1/2`
- noisy-source rates `0.50/1.00`
- weak branch: `joint-code-key` primary with `key-shape` fallback
- bad-source branch: `route-code-key` primary with `noisy-route-code` fallback

Current narrow readout:

- weak joint/key-shape rows keep positive source gap across key counts and
  seeds
- explicit noisy rows keep `route_source_credit_noisy_mean < 0`
- explicit noisy rows keep nonzero `route_source_credit_noisy_slashed_rate`
- fully noisy `noise=1.0` rows also get negative source gap
- mixed noisy `noise=0.5` rows may keep positive source gap because the source
  still contains correct fallback support; in those rows the noisy-candidate
  credit/slash metrics are the sharper separation signal
- all rows keep `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`

Interpretation:
h5-e shows that h5-d's source-quality separation is not only a single-row
smoke artifact. It repeats over the small key/seed scale smoke. This remains a
controlled diagnostic with symbolic fallback and explicit noisy-source stress,
not learned sparse routing.

## h5-f Weaker Learned-source Stress Decision

`h5-f` passes as weaker learned-source stress instrumentation, but it does not
solve learned routing, source-credit robustness, or wrong-candidate robustness.

This slice weakens the `route-code-key` source itself rather than only adding a
separate bad noisy source:

- `--route-code-key-region-keep-prob <0..1>` skips a deterministic fraction of
  key-region route-code identity auxiliary updates
- `--route-code-aux-noise-rate <0..1>` trains a deterministic fraction of kept
  route-code identity updates toward a low-entropy wrong target

The value-bearing route-hint path remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_learned_source_stress.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_learned_source_stress.sh
./experiments/run_v05_route_source_credit_learned_source_stress.sh --full
```

Smoke grid:

- key counts `32/64`
- seeds `1/2`
- clean branch: `keep=1.0`, `aux_noise=0.0`
- weak branch: `keep=0.25`, `aux_noise=0.75`
- primary source: `route-code-key`
- fallback source: symbolic `key-shape`

Current narrow readout:

- clean rows keep `key_region_route_decode_acc`, `route_primary_recall`, and
  query accuracy at `1.000000`
- weak rows lower route-code decode and primary recall
- weak rows trigger key-shape fallback and keep fallback recall at `1.000000`
- weak rows produce positive source-credit gap, nonzero primary slash, and
  nonzero fallback reward diagnostics
- all rows keep `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`

Interpretation:
h5-f creates an intermediate point between the strong explicit route-code
identity auxiliary and the weak prediction-oriented joint-code source. Source
credit can detect the degraded route-code source and route responsibility
toward the symbolic fallback in this controlled fixture. This is still an
instrumentation result with key-shape fallback, not learned sparse routing.

## h5-g Weak Learned-source Scale Stability Decision

`h5-g` passes as weak learned-source multi-seed / scale stability
instrumentation, but it does not solve learned routing, source-credit
robustness, or wrong-candidate robustness.

This slice extends h5-f from a clean/weak smoke into a small degradation curve:

- `clean-off`: `keep=1.0`, `aux_noise=0.0`, fallback off
- `mid-off`: `keep=0.5`, `aux_noise=0.25`, fallback off
- `weak-off`: `keep=0.25`, `aux_noise=0.75`, fallback off
- `weak-fallback-ledger`: `keep=0.25`, `aux_noise=0.75`,
  symbolic `key-shape` fallback, source-credit `ranking-strength`, and ledger
  enabled

Smoke command:

```bash
./experiments/test_v05_route_source_credit_learned_source_scale.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_learned_source_scale.sh
./experiments/run_v05_route_source_credit_learned_source_scale.sh --full
```

Smoke grid:

- key counts `64/128`
- seeds `1/2`
- four arms per key/seed pair

Mean smoke readout:

```text
clean-off:
  qacc = 1.000000
  key_region_route_decode_acc = 1.000000
  route_primary_recall = 1.000000

mid-off:
  qacc = 0.970313
  key_region_route_decode_acc = 0.630937
  route_primary_recall = 0.994531

weak-off:
  qacc = 0.185938
  key_region_route_decode_acc = 0.000000
  route_primary_recall = 0.285938

weak-fallback-ledger:
  qacc = 0.460156
  key_region_route_decode_acc = 0.000000
  route_primary_recall = 0.285938
  route_fallback_used_rate = 0.714063
  route_source_credit_gap = 0.305619
  route_source_credit_primary_slashed_rate = 0.467693
  route_source_credit_fallback_rewarded_rate = 1.000000
```

All rows keep the value-bearing route-hint path active:

- `route_hint_candidate_lookup_count > 0`
- `route_hint_value_read_distance_mean > 0`
- `routing_trigger_rate = 0.000000`
- `active_jump_rate = 0.000000`

Interpretation:
weakening the route-code identity auxiliary produces a stable degradation curve
over the small key/seed smoke. Key-shape fallback plus source-credit ledger
partially mitigates the weak-source damage and assigns responsibility to the
fallback source. This is still controlled instrumentation with symbolic
fallback, not learned sparse routing.

## h5-h Fallback-source Dependence / Stability Decision

`h5-h` passes as fallback-source dependence / stability diagnostics, but it
does not solve learned routing, source-credit robustness, or wrong-candidate
robustness.

This slice keeps the weak route-code source from h5-g fixed and compares four
fallback-source arms:

- `off`: no fallback
- `raw-key`: exact symbolic raw-key fallback
- `key-shape`: symbolic key-shape fallback with source-credit
  `ranking-strength`
- `noisy-route-code`: bad fallback-source stress with source-credit
  `ranking-strength`

The value-bearing route-hint path remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_ablation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_ablation.sh
./experiments/run_v05_route_source_credit_fallback_ablation.sh --full
```

Smoke grid:

- key counts `64/128`
- seeds `1/2`
- weak route-code source: `keep=0.25`, `aux_noise=0.75`
- fallback sources `off`, `raw-key`, `key-shape`, `noisy-route-code`

Mean smoke readout:

```text
fallback-off:
  qacc = 0.213281
  route_primary_recall = 0.316406
  route_fallback_used_rate = 0.000000

fallback-raw-key:
  qacc = 0.650000
  route_fallback_used_rate = 0.683594
  route_fallback_recall = 1.000000
  route_fallback_qacc = 0.670102

fallback-key-shape:
  qacc = 0.437500
  route_fallback_used_rate = 0.683594
  route_fallback_recall = 1.000000
  route_source_credit_gap = 0.299223

fallback-noisy-route-code:
  qacc = 0.173437
  route_fallback_used_rate = 0.683594
  route_fallback_recall = 0.000000
  route_source_credit_gap = -0.207562
  route_source_credit_noisy_mean = -0.201440
  route_source_credit_noisy_slashed_rate = 0.979234
```

All rows keep the route-hint safety guard:

- `route_hint_candidate_lookup_count > 0`
- `route_hint_value_read_distance_mean > 0`
- `routing_trigger_rate = 0.000000`
- `active_jump_rate = 0.000000`

Interpretation:
raw-key and key-shape show that symbolic fallback sources can recover
candidate availability when the learned-like route-code source is weak.
Noisy-route-code shows the opposite branch: a bad fallback source receives
negative source/noisy credit and does not recover recall. This separates
fallback-source dependence from learned-source quality, but it remains
controlled diagnostics with symbolic fallbacks, not learned sparse routing.

## h5-i Source-credit Fallback Policy Calibration Decision

`h5-i` passes as source-credit fallback-policy calibration diagnostics, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_policy.sh
```

The smoke keeps the weak route-code source from h5-g/h5-h fixed and separates
source-credit fallback policy modes:

- key counts `64/128`
- seeds `1/2`
- `off-control`
- `raw-key-ceiling`
- `key-shape-learn-only`
- `key-shape-ranking`
- `key-shape-strength`
- `key-shape-ranking-strength`
- `noisy-learn-only`
- `noisy-ranking-strength`

Average smoke readout:

```text
off-control:
  qacc=0.206250, primary_recall=0.309375, fallback_recall=0.000000

raw-key-ceiling:
  qacc=0.661328, fallback_recall=1.000000, fallback_qacc=0.689142

key-shape-learn-only:
  qacc=0.473437, fallback_recall=1.000000, source_gap=0.299047

key-shape-ranking:
  qacc=0.473437, selected_fallback=0.660209, strength_mean=1.000000

key-shape-strength:
  qacc=0.473437, selected_fallback=0.000000, strength_mean=1.402324

key-shape-ranking-strength:
  qacc=0.473437, selected_fallback=0.660209, strength_mean=1.402324

noisy-learn-only:
  qacc=0.170703, fallback_recall=0.000000, source_gap=-0.182191,
  noisy_mean=-0.189995, noisy_slashed=0.976094

noisy-ranking-strength:
  qacc=0.170703, fallback_recall=0.000000, source_gap=-0.182191,
  selected_fallback=0.363317, strength_mean=1.000000,
  noisy_mean=-0.189995, noisy_slashed=0.976094
```

Interpretation:
source-credit fallback policy is wired and separable. `key-shape` produces a
positive source gap, ranking changes selected-fallback diagnostics, strength
raises route-source strength, and ranking-strength combines both. However,
qacc is neutral across the key-shape policy modes. `noisy-route-code` produces
negative noisy/source credit and high noisy slash, does not recover fallback
recall, and does not receive strength amplification. `raw-key` remains a
symbolic ceiling. This is fallback-policy calibration instrumentation, not
learned sparse routing.

## h5-j Fallback Candidate-quality Gap Decision

`h5-j` passes as fallback candidate-quality gap diagnostics, but it does not
solve learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_quality.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_quality.sh
```

Reference smoke readout:

```text
raw-vote-off:
  qacc=0.225000, fallback_qacc=0.198214,
  correct_vote_share=0.296354, entropy=1.868280

keyshape-vote-off:
  qacc=0.200000, fallback_qacc=0.167857,
  correct_vote_share=0.287760, entropy=1.881561

raw-weighted-off:
  qacc=0.942188, fallback_qacc=0.996429,
  correct_vote_share=0.789853, entropy=0.958879

keyshape-weighted-off:
  qacc=0.960938, fallback_qacc=1.000000,
  correct_vote_share=0.842201, entropy=0.766750
```

Candidate top1 remains low for both fallback sources (`0.031250`, mean rank
`2.500000`). The useful explanatory signal is aggregation quality:
weighted-vote raises correct-value support and lowers vote entropy, rescuing
both raw-key and key-shape fallback. This means fallback recall alone is not
the current bottleneck; the next question is how to choose or learn the
fallback aggregation/reranking policy without relying on symbolic controls.

## h5-k Fallback Aggregation Policy Calibration Decision

`h5-k` passes as fallback aggregation-policy calibration diagnostics, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_aggregation.sh
```

Reference smoke readout:

```text
raw-key:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.328125, fallback_qacc=0.312500
  weighted qacc=0.943750, fallback_qacc=0.987500
  gated vote/weighted qacc=0.739062
  gated weighted/weighted qacc=0.943750

key-shape:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.204688, fallback_qacc=0.166071
  weighted qacc=0.956250, fallback_qacc=0.996429
  gated vote/weighted qacc=0.443750
  gated weighted/weighted qacc=0.956250
```

Interpretation:
fallback aggregation quality is policy-sensitive. In this controlled fallback
setting, broad unweighted vote is not the safe default; it washes out the
usable candidate signal. Top1 and weighted-vote are strong baselines, and
confidence-gated aggregation degrades when low-confidence queries are routed to
plain vote. Setting low/high confidence aggregation to weighted-vote preserves
the weighted baseline. This motivates the next slice: source/noise-aware
aggregation policy, rather than a single broad-vote fallback rule.

## h5-l Source/noise-aware Fallback Aggregation Decision

`h5-l` passes as source/noise-aware fallback aggregation diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_aggregation.sh
```

Reference smoke readout:

```text
raw-key:
  vote qacc=0.401563, fallback_qacc=0.391071
  source-aware qacc=0.965625, fallback_qacc=1.000000,
  source_gap=0.355541, strength_mean=1.544219

key-shape:
  vote qacc=0.218750, fallback_qacc=0.176786
  source-aware qacc=0.964063, fallback_qacc=1.000000,
  source_gap=0.355541, strength_mean=1.544219

noisy-route-code:
  source-aware qacc=0.189062, fallback_recall=0.000000,
  source_gap=-0.140244, noisy_mean=-0.197850,
  noisy_slashed=1.000000, noisy_selected=0.000000,
  strength_mean=1.000000
```

Interpretation:
symbolic fallback sources benefit from weighted/source-aware aggregation, while
the noisy fallback source remains unsolved but is correctly down-signaled. The
important split is now clear: source-credit can detect bad fallback sources,
and weighted aggregation can integrate good fallback candidates, but missing
or noisy candidates still require source quality improvements rather than
stronger aggregation alone.

## h5-m Source/noise-aware Aggregation Scale Stability Decision

`h5-m` passes as source/noise-aware aggregation scale stability diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_scale.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_scale.sh
```

The smoke crosses `key_count=64/128` with `seed=1/2` and compares vote against
source-aware weighted aggregation for symbolic fallback sources and an explicit
noisy fallback negative control.

Reference smoke averages:

```text
raw-key:
  vote qacc=0.378516, fallback_qacc=0.297216
  source-aware qacc=0.925391, fallback_qacc=0.996875,
  source_gap=0.314231, strength_mean=1.439082

key-shape:
  vote qacc=0.275781, fallback_qacc=0.115804
  source-aware qacc=0.932813, fallback_qacc=1.000000,
  source_gap=0.314231, strength_mean=1.439082

noisy-route-code:
  source-aware qacc=0.317969, fallback_recall=0.000000,
  source_gap=-0.268339, noisy_mean=-0.231653,
  noisy_slashed=1.000000, strength_mean=1.000000
```

Interpretation:
the source-aware aggregation pattern from h5-l repeats across the tested
key/seed smoke arms. Good symbolic fallback candidates are integrated by
weighted/source-aware aggregation, while a noisy fallback remains unsolved but
is assigned negative source/noisy credit and receives no strength
amplification. This is still controlled diagnostics with symbolic fallback
controls, not learned routing solved.

## h5-n Bad-source Filter / Abstain Decision

`h5-n` passes as bad-source filtering / abstention instrumentation, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice keeps the successful path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

It adds:

```bash
--route-source-filter-mode negative-credit
--route-source-filter-threshold <float>
```

Candidates from sources with credit below the threshold are removed from route
hint voting/proposal energy. If all candidates for a routed query are removed,
the source-filter abstain metric is populated.

Smoke command:

```bash
./experiments/test_v05_route_source_credit_bad_source_filter.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_bad_source_filter.sh
```

Reference smoke readout:

```text
raw-filter:
  qacc=0.951562, fallback_recall=1.000000,
  source_gap=0.328890, source_filter_abstain=0.000000

keyshape-filter:
  qacc=0.965625, fallback_recall=1.000000,
  source_gap=0.328890, source_filter_abstain=0.000000

noisy-filter:
  qacc=0.100000, fallback_recall=0.000000,
  source_gap=-0.116147, noisy_mean=-0.177831,
  noisy_slashed=0.974458,
  source_filter_filtered=0.935065,
  source_filter_abstain=0.875000,
  strength_mean=1.000000
```

Interpretation:
bad-source filtering is now connected: negative source credit can remove noisy
fallback candidates from the proposal hint path. This is useful
instrumentation and a guardrail, but it is not a robustness solution. When a
bad source is filtered, the system still needs a replacement source or retry
policy to recover the correct candidate.

## h5-o Retry-source Replacement Decision

`h5-o` passes as retry-source replacement instrumentation and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice keeps the successful route path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

It adds:

```bash
--route-source-retry-source off|raw-key|key-shape|joint-code-key|noisy-route-code
```

The retry source is a secondary candidate source inserted after the primary
fallback path. It is useful when a bad/noisy fallback source is detected and
removed by `--route-source-filter-mode negative-credit`.

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_source.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_source.sh
```

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  source_filter_filtered=0.937013,
  source_filter_abstain=0.876562

retry-raw:
  qacc=0.950000, fallback_recall=1.000000,
  fallback_qacc=0.991071,
  source_retry_used=0.875000,
  source_retry_success=0.875000,
  source_filter_abstain=0.003125

retry-keyshape:
  qacc=0.962500, fallback_recall=1.000000,
  fallback_qacc=1.000000,
  source_retry_used=0.875000,
  source_retry_success=0.875000,
  source_filter_abstain=0.003125
```

Interpretation:
h5-n connected bad-source filtering, but filtering alone only abstains when
the correct candidate is missing. h5-o shows that a secondary symbolic retry
source can fill that gap: after noisy candidates are filtered, raw-key or
key-shape retry candidates restore recall and qacc. This is a controlled
retry/replacement diagnostic with symbolic upper-bound sources, not learned
routing solved.

Next:
calibrate retry-source policy selection so source credit chooses when to retry
and which retry source to use, rather than always relying on a fixed symbolic
retry source.

## h5-p Source-credit Retry-policy Decision

`h5-p` passes as source-credit retry-policy calibration instrumentation and
limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```bash
--route-source-retry-policy fixed|source-credit
--route-source-retry-candidates <csv>
--route-source-retry-per-source-limit <int>
```

The policy-selected retry path still uses only:

```text
candidate value_pos -> value byte read -> proposal hint
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_policy.sh
```

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  source_filter_abstain=0.878125

fixed-raw:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000

policy-mixed:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

policy-raw-noisy:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000
```

Interpretation:
h5-p confirms that retry-source selection is now policy-visible: a
source-credit retry policy can recover after noisy-source filtering while
avoiding the bad/noisy retry source in the smoke. The current policy is still
limited. Under equal initial source credit it selects the raw-key retry first,
so it recovers but does not beat the fixed key-shape symbolic upper bound. This
is calibration instrumentation, not learned retry-source selection solved.

Follow-up:
h5-q closes the tie-break layer and measures whether source-order or
source-prior wins without selecting the noisy retry source.

## h5-q Source-credit Retry-policy Tie-break Calibration

`h5-q` passes as source-credit retry-policy tie-break calibration diagnostics
/ limited mitigation. It keeps the same value-bearing path and tests whether
source-order or source-prior should win when retry sources are available.

The slice adds:

```bash
--route-source-retry-tiebreak source-order|source-prior
--route-source-retry-priorities <csv>
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_tiebreak.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_tiebreak.sh
```

Reference smoke readout:

```text
noisy-filter:
  qacc=0.103125, fallback_recall=0.000000,
  noisy_slashed=1.000000, source_retry_used=0.000000

policy-source-order:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

policy-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

policy-noisy-penalty/mixed:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  fallback_qacc=1.000000
```

Decision:

- `v0.3-h5-q source-credit retry-policy tie-break`: `PASS` as source-credit
  retry-policy tie-break calibration diagnostics / limited mitigation
- it is not learned routing solved, not source-credit robustness solved, and
  not wrong-candidate/fallback robustness solved

Interpretation:
the tie-break layer makes source-order versus source-prior explicit for the
retry path. It can route around the noisy retry and preserve the symbolic
retry-source path, but the fixed key-shape reference remains the upper bound.
That makes h5-q a calibration/guardrail result, not a new routing capability.

## h5-r Source-prior Schedule / Retry Tie-break Calibration

`h5-r` passes as source-prior schedule calibration diagnostics / limited
mitigation. It keeps the same value-bearing route path and compares whether
source-order, static source-prior, decaying source-prior, or warmup source-prior
controls retry-source selection.

The slice adds:

```bash
--route-source-retry-prior-mode none|static|decay|warmup
--route-source-retry-prior-decay <float>
--route-source-retry-prior-warmup-epochs <int>
```

Smoke command:

```bash
./experiments/test_v05_route_source_credit_retry_prior_schedule.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_retry_prior_schedule.sh
```

Reference smoke readout:

```text
source-order:
  qacc=0.957813, fallback_recall=1.000000,
  retry_raw_selected=0.875000,
  retry_noisy_selected=0.000000

static-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

decay-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

warmup-keyshape-prior:
  qacc=0.957813, fallback_recall=1.000000,
  retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_recall=1.000000,
  fallback_qacc=1.000000
```

Decision:

- `v0.3-h5-r source-prior retry schedule`: `PASS` as source-prior schedule
  calibration diagnostics / limited mitigation
- it is not learned routing solved, not source-credit robustness solved, and
  not wrong-candidate/fallback robustness solved

Interpretation:
static, decaying, and warmup key-shape priors all steer retry selection toward
key-shape and avoid the bad/noisy retry source, but they do not exceed the
fixed key-shape reference. The next useful question is not another tie-break
switch; it is whether source-credit evidence can eventually dominate or decay
away the symbolic prior under scale/seed stress.

## h5-s Source-prior Handoff Diagnostics

`h5-s` passes as source-prior handoff calibration diagnostics / limited
mitigation. It remains on the same value-bearing route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

The slice compares source-order, static key-shape prior, short/long warmup,
fast decay, and fixed key-shape reference rows:

```text
source-order:
  qacc=0.957813, retry_raw_selected=0.875000,
  retry_keyshape_selected=0.000000,
  retry_noisy_selected=0.000000

static-keyshape-prior:
  qacc=0.957813, retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

warmup-short:
  qacc=0.957813, retry_raw_selected=0.062500,
  retry_keyshape_selected=0.812500,
  retry_noisy_selected=0.000000

warmup-long:
  qacc=0.957813, retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

decay-fast:
  qacc=0.957813, retry_keyshape_selected=0.875000,
  retry_noisy_selected=0.000000

fixed-keyshape:
  qacc=0.970313, fallback_qacc=1.000000
```

Decision:

- `v0.3-h5-s source-prior handoff`: `PASS` as source-prior handoff
  calibration diagnostics / limited mitigation
- it is not learned routing solved, not source-credit robustness solved, and
  not wrong-candidate/fallback robustness solved

Interpretation:
short warmup exposes a small handoff effect from key-shape back toward raw-key,
while long warmup/static/decay schedules keep key-shape selected. Noisy retry
selection remains suppressed. The scheduled-prior rows still do not match the
fixed key-shape reference, so the remaining issue is not tie-break plumbing; it
is source-credit evidence quality and whether it can eventually choose the
better source without a persistent symbolic prior.

## h5-t Retry-source Evidence-quality Diagnostics

`h5-t` passes as retry-source evidence-quality instrumentation. It keeps the
same value-bearing route-hint path:

```text
candidate value_pos -> value byte read -> proposal hint
```

The slice adds retry-source credit evidence metrics for raw-key, key-shape, and
noisy retry sources:

```text
route_source_retry_raw_mean
route_source_retry_keyshape_mean
route_source_retry_noisy_mean
route_source_retry_raw_rewarded_rate
route_source_retry_keyshape_rewarded_rate
route_source_retry_noisy_slashed_rate
```

Reference smoke readout:

```text
source-order:
  qacc=0.960937,
  retry_raw_selected=0.875000,
  retry_raw_mean=0.222951,
  retry_noisy_mean=-0.206811

static-keyshape-prior:
  qacc=0.960937,
  retry_keyshape_selected=0.875000,
  retry_keyshape_mean=0.222951,
  retry_noisy_mean=-0.206811

raw-quality-evidence:
  retry_raw_mean=0.222951,
  retry_raw_rewarded=1.000000,
  retry_noisy_slashed=1.000000

keyshape-quality-evidence:
  retry_keyshape_mean=0.222951,
  retry_keyshape_rewarded=1.000000,
  retry_noisy_slashed=1.000000
```

Decision:

- `v0.3-h5-t retry-source evidence quality`: `PASS` as retry-source evidence
  instrumentation
- it is not learned routing solved, not source-credit robustness solved, and
  not wrong-candidate/fallback robustness solved

Interpretation:
source-credit evidence is now observable at retry-source granularity. It can
separate clean retry sources from noisy retry sources, but raw-key and
key-shape both receive positive credit when selected. Thus h5-t exposes the
next bottleneck: source-credit evidence still needs richer quality features if
it is to choose the better symbolic retry source without a prior.

## h5-u Candidate-quality Diagnostics Decision

The h5-u slice passes as candidate-quality logdet/channel/quality-score
instrumentation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The implementation is deliberately metric-only. `route_quality_apply=none` is
required in h5-u, and the smoke confirms no behavior change for the source-order
control:

```text
quality-off-source-order qacc = 0.645313
quality-on-source-order  qacc = 0.645313
```

The value-bearing route-hint guard remains active:

```text
route_hint_candidate_lookup_count = 128
route_hint_value_read_distance_mean > 0
routing_trigger_rate = 0.000000
active_jump_rate     = 0.000000
```

The fixed-source diagnostics expose a candidate-quality gap:

```text
fixed-raw:
  qacc = 0.742187
  logdet = -5.818573
  condition = 7.050210
  quality_score = 2.016223

fixed-keyshape:
  qacc = 0.645313
  logdet = -15.330912
  condition = 52.270703
  quality_score = 0.852792
```

Interpretation:
fallback/retry recall is not the whole story. Candidate-set geometry and
channel margin diagnostics can explain quality differences between sources
without changing the successful `candidate value_pos -> value byte read ->
proposal hint` path. The next slice may test weak continuous application with
`route_quality_apply=source-ranking` first, but hard threshold/filter and
jump-neighbor revival remain forbidden.

## h5-v Weak Quality Application Decision

The h5-v slice passes as weak quality source-ranking application diagnostics and
neutral-to-slight-regression. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It starts with `route_quality_apply=source-ranking` and keeps the same
`candidate value_pos -> value byte read -> proposal hint` path. No hard
thresholding or hard filtering is used, and `jump-neighbor` remains default-off
/ no-go.

Reference smoke:

```text
apply-none-source-order:
  qacc = 0.568750
  apply_active = 0.000000

source-ranking-b0p10:
  qacc = 0.560938
  apply_active = 1.000000
  source_ranking_delta = 0.227710
  selected_raw = 0.850000
  selected_noisy = 0.000000

source-ranking-b0p25:
  qacc = 0.560938
  apply_active = 1.000000
  source_ranking_delta = 0.250000
  selected_raw = 0.850000
  selected_noisy = 0.000000
```

Interpretation:
soft source-ranking is wired and avoids noisy retry selection, but the qacc
readout is neutral-to-slightly worse than apply-none. The useful conclusion is
calibration: quality metrics can drive source ordering, but the current proxy
should be tuned before trying candidate-weight or strength application.

## h5-w Source-quality Calibration Decision

The h5-w slice passes as source-quality calibration diagnostics, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

It keeps the h5-v source-ranking path and adds source-specific quality proxy,
delta, and selected-source qacc readouts:

```text
apply-none-source-order:
  qacc = 0.568750
  raw_proxy = 2.277099
  keyshape_proxy = -0.472130
  noisy_proxy = -0.513364
  selected_raw_qacc = 0.611905

source-ranking-b0p10:
  qacc = 0.560938
  raw_delta = 0.227710
  keyshape_delta = -0.047213
  noisy_delta = -0.051336
  selected_raw_qacc = 0.600298
  selected_noisy = 0.000000

source-ranking-b0p25:
  qacc = 0.560938
  raw_delta = 0.250000
  keyshape_delta = -0.118032
  noisy_delta = -0.128341
```

Interpretation:
the quality proxy is not inert; it strongly favors raw-key and suppresses
key-shape/noisy in the source-ranking score. That explains the observed source
selection, but it does not improve qacc. The next step is h5-x proxy
weight/sign calibration before using stronger candidate-weight or
route-strength applications.

## h5-x Proxy Weight/Sign Calibration

The h5-x slice passes as proxy weight/sign calibration diagnostics and
single-smoke limited mitigation. It keeps the same `candidate value_pos ->
value byte read -> proposal hint` path and calibrates the proxy term signs
against selected-source qacc.

Reference smoke:

```text
proxy-default:
  qacc = 0.560938
  raw_proxy = 2.277099
  keyshape_proxy = -0.472130
  noisy_proxy = -0.513364

logdet-sign-flip:
  qacc = 0.567187
  raw_proxy = 1.722901
  keyshape_proxy = -1.084626
  noisy_proxy = -1.118645

channel-sign-flip:
  qacc = 0.662500
  raw_proxy = 2.277099
  keyshape_proxy = -0.412249
  noisy_proxy = -0.381355
  selected_raw_qacc = 0.720536
```

Interpretation:
the channel term sign is a real calibration handle in this smoke. The best row
improves qacc and still avoids noisy retry, but selected source remains raw-key.
So this is not learned source selection solved; it is a sign that quality proxy
calibration can change the retained candidate mixture enough to matter. Next:
multi-seed/scale stability for the channel-sign calibration.

## h5-y Channel-sign Multi-seed / Scale Stability

The h5-y slice passes as channel-sign calibration multi-seed/scale diagnostics
and weak limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice keeps the route-hint path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656

proxy-default:
  qacc_mean = 0.621094
  selected_raw_rate_mean = 0.753385
  selected_noisy_rate_mean = 0.000000

proxy-channel-sign:
  qacc_mean = 0.636198
  selected_raw_rate_mean = 0.753385
  selected_keyshape_rate_mean = 0.000000
  selected_noisy_rate_mean = 0.000000
  selected_raw_qacc_mean = 0.672334
```

Interpretation:
h5-y confirms that the channel-sign proxy calibration is at least stable
across the first key/seed smoke and still avoids noisy retry. But selected
source remains raw-key, so this is not source selection solved. The next step
should test source-specific normalization or candidate-level quality scoring
before applying quality to route strength.

## h5-z Source-normalization Diagnostics

The h5-z slice passes as source-normalization instrumentation and neutral
diagnostics. It does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

It adds source-level normalization for the quality proxy:

```text
--route-quality-source-normalization none|center|zscore
```

The normalization is still only used in the source-ranking path. It does not
change graph topology, candidate collection, or route strength.

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

channel-sign-none:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 2.277099
  delta_mean = 0.227710

channel-sign-center:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 1.104578
  delta_mean = 0.110458

channel-sign-zscore:
  qacc_mean = 0.636198
  raw_norm_proxy_mean = 0.873139
  delta_mean = 0.087314
```

Interpretation:
normalization controls the source-quality proxy scale and reduces raw-key
pressure, but it does not change selected source or qacc relative to
channel-sign. This points away from source-level scaling alone and toward
candidate-level quality diagnostics/application as the next step.

## h5-aa Candidate-level Quality Diagnostics

The h5-aa slice passes as candidate-level quality diagnostics and an
actionable split. It does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The route behavior remains unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

The slice adds candidate-level quality readouts:

```text
route_quality_candidate_weight_correct_mean
route_quality_candidate_weight_wrong_mean
route_quality_candidate_weight_gap
route_quality_candidate_best_correct_rate
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656
  candidate_weight_correct = 0.398027
  candidate_weight_wrong = 0.217518
  candidate_weight_gap = 0.180509
  candidate_best_correct_rate = 0.838021

channel-sign-none:
  qacc_mean = 0.636198
  candidate_weight_correct = 0.396566
  candidate_weight_wrong = 0.217533
  candidate_weight_gap = 0.179034
  candidate_best_correct_rate = 0.838021
```

Interpretation:
candidate quality already contains a positive correctness signal: correct
candidates receive higher normalized weight than wrong candidates, and the best
weighted candidate is correct more often than final query accuracy. Therefore
the remaining bottleneck is not candidate ranking alone. It is more likely the
conversion from candidate support into aggregation, proposal acceptance, or
stable query-state convergence. The next slice should apply candidate-level
quality weakly and boundedly; route-strength modulation should remain a later
step.

## h5-ab Weak Candidate-level Quality Application

The h5-ab slice passes as weak bounded candidate-level quality application
diagnostics and limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It enables:

```text
--route-quality-apply candidate-weight
--route-quality-candidate-weight-beta <float>
--route-quality-candidate-weight-min <float>
--route-quality-candidate-weight-max <float>
```

The application is target-free and bounded. It uses each candidate's existing
base weight relative to the candidate-set mean:

```text
factor = clamp(
  1 + beta * (base_weight / mean_base_weight - 1),
  min_factor,
  max_factor
)
```

Reference standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off qacc_mean       = 0.622656
source-ranking qacc_mean  = 0.636198
candidate-b0p10 qacc_mean = 0.635156
candidate-b0p25 qacc_mean = 0.663542
candidate-b0p50 qacc_mean = 0.725261

candidate-b0p50:
  factor_gap = 0.263136
  candidate_weight_gap = 0.241817
  candidate_best_correct_rate = 0.838021
```

Interpretation:
h5-ab is the first quality-application slice where candidate-level quality
clearly improves qacc over both proxy-off and source-ranking in the first
multi-seed/key smoke. The result remains below best-candidate correctness, so
the remaining gap is still aggregation-to-state / hint-integration limited.
Keep this as limited mitigation and continue to avoid route-strength
modulation until scale stability is checked.

## h5-ac Candidate-weight Composition

The h5-ac slice passes as candidate-weight scale/composition diagnostics and
limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds the combined apply mode:

```text
--route-quality-apply source-candidate
```

This mode applies source-ranking and candidate-weight quality at the same time.
It still leaves graph topology and route strength unchanged.

Reference standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off qacc_mean              = 0.622656
source-ranking qacc_mean         = 0.636198
candidate-b0p25 qacc_mean        = 0.663542
candidate-b0p50 qacc_mean        = 0.725261
source-candidate-b0p25 qacc_mean = 0.667708
source-candidate-b0p50 qacc_mean = 0.717708
```

Interpretation:
the candidate-weight path continues to be the strongest quality application
path in this smoke. Source-ranking composition is active and avoids noisy
retry, but it does not add to `candidate-b0p50`. Keep the current conclusion
narrow: candidate-only quality application is the next scale target; learned
routing and robustness remain unsolved.

## h5-ad Candidate-only Beta / Noise Scale

The h5-ad slice passes as candidate-only beta/noise scale diagnostics and
limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_scale.sh
experiments/test_v05_route_quality_candidate_scale.sh
```

The route path is unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests candidate-only quality application over:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.10, 0.25, 0.50
```

Reference aggregate:

```text
proxy-off qacc_mean        = 0.615799
candidate-b0p25 qacc_mean  = 0.666580
candidate-b0p50 qacc_mean  = 0.722222
candidate-b0p75 qacc_mean  = 0.775434
```

`candidate-b0p75` also keeps the expected correctness separation:

```text
factor_gap = 0.397633
candidate_weight_gap = 0.266717
candidate_best_correct_rate = 0.838021
```

And the safety guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
candidate-only quality application remains the cleanest quality path in the
current route-hint fixture. Within the tested bounded factor range, increasing
candidate beta through `0.75` improves qacc rather than over-sharpening. This
is still controlled limited mitigation and should not be described as learned
routing or robustness solved.

## h5-ae Candidate-weight Saturation / Cap

The h5-ae slice passes as candidate-weight saturation/cap diagnostics and
limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds candidate-weight concentration diagnostics:

```text
route_quality_candidate_weight_factor_p90
route_quality_candidate_weight_factor_max
route_quality_candidate_weight_entropy_mean
route_quality_candidate_weight_top_share_mean
```

and:

```text
experiments/run_v05_route_quality_candidate_saturation.sh
experiments/test_v05_route_quality_candidate_saturation.sh
```

The standard sweep keeps:

```text
candidate value_pos -> value byte read -> proposal hint
```

and compares:

```text
keys = 128
seeds = 1..3
noisy_source_rate = 0.25, 0.50
beta = 0.75, 1.00, 1.25, 1.50, 2.00
cap = 2.0, 3.0, 4.0
```

Reference readout:

```text
b0p75-cap2/3/4 qacc = 0.867188
b1p50-cap2/3/4 qacc = 0.913542
b2p00-cap2 qacc     = 0.905729
b2p00-cap3/4 qacc   = 0.922396

b2p00-cap3/4:
  factor_p90 = 2.222222
  factor_max = 2.333333
  entropy = 1.465697
  top_share = 0.585550
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-ae does not find an over-sharpening collapse in the tested range. It finds
that cap `2.0` becomes too tight at `beta=2.0`, while cap `3.0/4.0` allows a
stronger useful separation. This keeps candidate-quality weighting as the
strongest current quality application path, but still only inside controlled
route-hint fixtures.

## h5-af Candidate-quality Regression / Scale

The h5-af slice passes as candidate-quality best-setting scale regression
diagnostics and limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_regression.sh
experiments/test_v05_route_quality_candidate_regression.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
```

Reference aggregate:

```text
proxy-off qacc_mean              = 0.637153
candidate-b0p75-cap2 qacc_mean   = 0.800478
candidate-b1p50-cap2 qacc_mean   = 0.854948
candidate-b2p00-cap2 qacc_mean   = 0.843620
candidate-b2p00-cap3 qacc_mean   = 0.869965
```

`candidate-b2p00-cap3` is also best in every tested key/noise bucket, including
the larger 256-key rows:

```text
k256 n0.25 qacc = 0.958073
k256 n0.50 qacc = 0.936719
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-af confirms that the current best candidate-quality setting is
`beta=2.0, cap=3.0` in the tested regression grid. The lower cap `2.0` clips
useful separation at high beta. This remains bounded candidate weighting over
the value-bearing route-hint path; it is not learned routing, source-credit
robustness, or wrong-candidate/fallback robustness solved.

## h5-ag Candidate-quality Over-sharpen Boundary

The h5-ag slice passes as candidate-quality over-sharpen boundary diagnostics
and limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_boundary.sh
experiments/test_v05_route_quality_candidate_boundary.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
```

Reference aggregate:

```text
candidate-b2p00-cap3 qacc_mean     = 0.934896
candidate-b2p50-cap3/4 qacc_mean   = 0.942448
candidate-b3p00-cap3/4/6 qacc_mean = 0.947331
```

Concentration moves smoothly:

```text
b2p00-cap3:
  factor_max = 2.333333
  top_share = 0.576942
  entropy = 1.494419

b3p00-cap3/4/6:
  factor_max = 3.000000
  top_share = 0.615203
  entropy = 1.389753
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-ag does not find an over-sharpen collapse through `beta=3.0`; it extends the
candidate-quality limited mitigation curve. Caps above `3.0` do not matter in
this range because the observed factor max is already `3.0`. The next safe
step is a higher-beta or full 5-seed guardrail before considering any
route-strength modulation.

## h5-ah High-beta Candidate-quality Boundary

The h5-ah slice passes as high-beta candidate-quality boundary diagnostics and
limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_high_beta.sh
experiments/test_v05_route_quality_candidate_high_beta.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
```

Reference aggregate:

```text
candidate-b3p00-cap3 qacc_mean   = 0.947331
candidate-b4p00-cap4/6 qacc_mean = 0.950781
candidate-b5p00-cap4 qacc_mean   = 0.950195
candidate-b5p00-cap6/8 qacc_mean = 0.952669
```

Concentration increases but remains controlled:

```text
b3p00-cap3:
  factor_max = 3.000000
  top_share = 0.615203
  entropy = 1.389753

b5p00-cap6/8:
  factor_max = 4.333333
  top_share = 0.656368
  entropy = 1.269519
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-ah still does not expose over-sharpen collapse through `beta=5.0`. The
highest tested useful setting is `beta=5.0, cap=6.0/8.0`; cap `4.0` slightly
clips this beta. The finding remains a bounded candidate-weighting result over
the value-bearing route-hint path, not learned routing or robustness solved.

## h5-ai Extreme-beta Candidate-quality Boundary

The h5-ai slice passes as extreme-beta candidate-quality boundary diagnostics
and limited mitigation. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_extreme_beta.sh
experiments/test_v05_route_quality_candidate_extreme_beta.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
```

Reference aggregate:

```text
candidate-b5p00-cap6 qacc_mean       = 0.952669
candidate-b6p00-cap6/8/12 qacc_mean  = 0.956250
candidate-b8p00-cap8/12 qacc_mean    = 0.957813
```

Concentration increases but no collapse appears:

```text
b5p00-cap6:
  factor_max = 4.333333
  top_share = 0.656368
  entropy = 1.269519

b8p00-cap8/12:
  factor_max = 6.333333
  top_share = 0.689736
  entropy = 1.157891
  wrong_strength = 7.690873
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-ai still does not expose over-sharpen collapse through `beta=8.0`. The
highest tested useful setting is `beta=8.0, cap=8.0/12.0`; cap `12.0` does not
improve over cap `8.0` because the observed factor max is already `6.333333`.
The finding remains a bounded candidate-weighting result over the
value-bearing route-hint path. Rising concentration and wrong hint strength
make this a boundary diagnostic, not learned routing or robustness solved.

## h5-aj Ultra-beta Candidate-quality Plateau

The h5-aj slice passes as ultra-beta candidate-quality plateau/boundary
diagnostics and limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_ultra_beta.sh
experiments/test_v05_route_quality_candidate_ultra_beta.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep tests:

```text
keys = 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
```

Reference aggregate:

```text
candidate-b8p00-cap8 qacc_mean       = 0.957813
candidate-b10p00-cap10/12 qacc_mean  = 0.957813
candidate-b12p00-cap12/16 qacc_mean  = 0.958008
```

Concentration continues to rise:

```text
b8p00-cap8:
  factor_max = 6.333333
  top_share = 0.689736
  entropy = 1.157891

b12p00-cap12/16:
  factor_max = 9.000000
  top_share = 0.713297
  entropy = 1.069426
  wrong_strength = 7.697217
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-aj still does not expose over-sharpen collapse through `beta=12.0`, but it
does show a practical plateau. The `beta=12.0` arm improves aggregate qacc by
only `0.000195` over `beta=8.0`, while candidate concentration continues to
increase. The finding remains bounded candidate-weighting diagnostics over the
value-bearing route-hint path, not learned routing or robustness solved.

## h5-ak Candidate-quality Guardrail Selection

The h5-ak slice passes as candidate-quality guardrail selection diagnostics. It
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_guardrail.sh
experiments/test_v05_route_quality_candidate_guardrail.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard guardrail tests:

```text
keys = 64, 128, 256
seeds = 1..5
noisy_source_rate = 0.10, 0.25, 0.50
beta/cap = 8.0/8.0, 12.0/12.0
```

Reference aggregate:

```text
candidate-b8p00-cap8:
  qacc_mean = 0.885747
  qacc_std = 0.110010
  factor_max = 6.333333
  top_share = 0.718199
  entropy = 1.064693
  wrong_strength = 5.852729

candidate-b12p00-cap12:
  qacc_mean = 0.885573
  qacc_std = 0.109432
  factor_max = 9.000000
  top_share = 0.741223
  entropy = 0.979652
  wrong_strength = 5.951053
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-ak makes the safe bounded candidate-weight choice explicit. Across the
broader guardrail, `beta=8.0, cap=8.0` slightly beats `beta=12.0, cap=12.0`
on aggregate qacc and carries less concentration and wrong hint strength. The
current safe setting is `beta=8.0, cap=8.0`. This remains value-bearing
route-hint diagnostics, not learned routing or robustness solved.

## h5-al Candidate-quality Safe-default Application

The h5-al slice passes as candidate-quality safe-default application
diagnostics and limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_default.sh
experiments/test_v05_route_quality_candidate_default.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard check compares:

```text
proxy-off
candidate-default: route_quality_apply=candidate-weight, beta=8.0, cap=8.0
source-candidate-default: route_quality_apply=source-candidate, source_beta=0.10, beta=8.0, cap=8.0
```

Reference aggregate over `keys=64,128,256`, seeds `1..3`, and noisy source
rates `0.10,0.25,0.50`:

```text
proxy-off:
  qacc_mean = 0.646962

candidate-default:
  qacc_mean = 0.886429
  factor_max = 6.333333
  top_share = 0.720014
  entropy = 1.057869
  wrong_strength = 6.224125

source-candidate-default:
  qacc_mean = 0.884896
  factor_max = 6.333333
  top_share = 0.720014
  entropy = 1.057869
  wrong_strength = 6.140892
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
h5-al makes the practical default explicit. The candidate-only quality path at
`beta=8.0, cap=8.0` keeps the non-topological value-bearing route-hint path
and outperforms both proxy-off and the combined source-candidate arm. The
source-ranking composition path remains useful instrumentation, but it is not
promoted as the default.

## h5-am Candidate-feature Basis Calibration

The h5-am slice passes as candidate-feature basis calibration diagnostics. It
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

It adds:

```text
--route-quality-candidate-weight-basis base|quality-score
experiments/run_v05_route_quality_candidate_feature_calibration.sh
experiments/test_v05_route_quality_candidate_feature_calibration.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard check keeps `route_quality_apply=candidate-weight`,
`beta=8.0`, and `cap=8.0`, then compares the existing base-weight sharpening
against several feature-score bases over `keys=64,128`, seeds `1..3`, and noisy
source rates `0.25,0.50`.

Reference aggregate:

```text
base-default:
  qacc_mean = 0.837630
  factor_gap = 3.154903
  factor_max = 6.333333
  top_share = 0.727296
  entropy = 1.031879
  quality_score_gap = 1.107729
  wrong_strength = 4.837817

feature-default:
  qacc_mean = 0.791146
  factor_gap = 0.608342
  factor_max = 3.574677
  wrong_strength = 4.364212

feature-margin:
  qacc_mean = 0.800000
  factor_gap = 0.706567
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
feature-score candidate weighting is wired, but it is currently too soft for
this fixture. It lowers wrong hint strength but also weakens correct support
and lowers qacc relative to the base default. The default remains
`candidate-weight-basis=base`, not `quality-score`.

## h5-an Hybrid Candidate-basis Calibration Decision

The h5-an slice passes as hybrid candidate-basis calibration diagnostics and
lower-concentration limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
--route-quality-candidate-weight-basis base|quality-score|hybrid
--route-quality-candidate-weight-basis-mix <float>
experiments/run_v05_route_quality_candidate_hybrid_basis.sh
experiments/test_v05_route_quality_candidate_hybrid_basis.sh
```

The route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard check keeps `route_quality_apply=candidate-weight`, `beta=8.0`,
and `cap=8.0`, then blends the h5-al base-weight basis with the best h5-am
margin feature-score basis over `keys=64,128`, seeds `1..3`, and noisy source
rates `0.25,0.50`.

Reference aggregate:

```text
base-default:
  qacc_mean = 0.837630
  factor_gap = 3.154903
  factor_max = 6.333333
  top_share = 0.727296
  entropy = 1.031879
  wrong_strength = 4.837817

feature-margin:
  qacc_mean = 0.800000
  factor_gap = 0.706567
  factor_max = 3.482540
  wrong_strength = 4.613126

hybrid-m0p25:
  qacc_mean = 0.837760
  factor_gap = 2.859539
  factor_max = 5.928332
  top_share = 0.720490
  entropy = 1.055624
  wrong_strength = 4.779110
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
small hybrid mixes preserve the base qacc while reducing candidate-weight
concentration. `hybrid-m0p25` is the cleanest current lower-concentration arm,
but the improvement is tiny and does not justify changing the safe default.
Keep `candidate-weight-basis=base` as the default and treat hybrid as a
diagnostic/ablation arm.

## h5-ao Hybrid Candidate-basis Guardrail Scale Decision

The h5-ao slice passes as hybrid candidate-basis guardrail scale diagnostics
and lower-concentration limited mitigation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

It adds:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh
experiments/test_v05_route_quality_candidate_hybrid_guardrail.sh
```

The standard guardrail expands h5-an over:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
arms = base-default, hybrid-m0p10, hybrid-m0p25, hybrid-m0p50
```

Reference aggregate:

```text
base-default:
  qacc_mean = 0.886458
  qacc_std = 0.120952
  factor_gap = 3.596599
  factor_max = 6.333333
  top_share = 0.712137
  entropy = 1.082397
  wrong_strength = 6.210653

hybrid-m0p10:
  qacc_mean = 0.886372
  factor_gap = 3.469870
  factor_max = 6.202220
  wrong_strength = 6.153818

hybrid-m0p25:
  qacc_mean = 0.886545
  qacc_std = 0.120533
  factor_gap = 3.247608
  factor_max = 5.968582
  top_share = 0.704366
  entropy = 1.107710
  wrong_strength = 6.162082

hybrid-m0p50:
  qacc_mean = 0.884071
  factor_gap = 2.756076
  factor_max = 5.438107
  wrong_strength = 6.147595
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`hybrid-m0p25` is the best current compromise: it preserves qacc at the base
level and lowers candidate-weight concentration. `hybrid-m0p50` lowers
concentration further but starts to lose qacc. The improvement is still tiny,
so the safe default remains `candidate-weight-basis=base`; use `hybrid-m0p25`
as the lower-concentration guardrail/ablation arm.

## h5-ap Hybrid Candidate-basis Promotion Check Decision

The h5-ap slice passes as hybrid candidate-basis promotion-check diagnostics
and safe-alternative instrumentation. It does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The same h5-ao runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --promotion
experiments/test_v05_route_quality_candidate_hybrid_promotion.sh
```

The promotion check narrows the arms to `base-default` and `hybrid-m0p25` and
expands the guardrail to:

```text
keys = 64, 128, 256
seeds = 1..5
noisy_source_rate = 0.10, 0.25, 0.50
candidate_beta/cap = 8.0/8.0
```

Reference aggregate:

```text
base-default:
  qacc_mean = 0.885747
  qacc_std = 0.110010
  factor_gap = 3.607673
  factor_max = 6.333333
  top_share = 0.718199
  entropy = 1.064693
  wrong_strength = 5.852729

hybrid-m0p25:
  qacc_mean = 0.885747
  qacc_std = 0.109796
  factor_gap = 3.252903
  factor_max = 5.954676
  top_share = 0.710272
  entropy = 1.090162
  wrong_strength = 5.779043
```

The guard remains:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`hybrid-m0p25` ties the base qacc exactly in the 5-seed promotion check while
lowering concentration and wrong hint strength. This is enough to keep
`hybrid-m0p25` as a safe lower-concentration alternative, but not enough to
promote it as the default. The default remains `candidate-weight-basis=base`
unless a later concentration-aware policy needs the lower-concentration arm.

## h5-aq Concentration-aware Candidate-basis Switching Decision

The h5-aq slice passes as concentration-aware candidate-basis switching
diagnostics and safe-alternative instrumentation, but it does not solve learned
routing, source-credit robustness, wrong-candidate robustness, or fallback
robustness.

The slice adds an `auto` candidate-weight basis:

```text
--route-quality-candidate-weight-basis auto
--route-quality-candidate-weight-auto-factor-max
--route-quality-candidate-weight-auto-top-share
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto
experiments/test_v05_route_quality_candidate_auto_basis.sh
```

The auto policy keeps the base basis unless the base candidate-weight
concentration crosses the configured query-level thresholds, then uses the
`hybrid-m0p25` basis for that query.

Reference scale check:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
```

Readout:

```text
base-default qacc_mean    = 0.886458
hybrid-m0p25 qacc_mean    = 0.886545
auto-f6p0-t0p72 qacc_mean = 0.886502

base-default:
  factor_gap = 3.596599
  factor_max = 6.333333
  wrong_strength = 6.210653

auto-f6p0-t0p72:
  factor_gap = 3.477531
  factor_max = 5.968582
  auto_hybrid_rate = 0.440365
  wrong_strength = 6.173549
```

The non-topological guard remains intact:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
`auto-f6p0-t0p72` is safe and reduces concentration relative to the base
default while preserving qacc, but it does not outperform always-hybrid. Keep
`candidate-weight-basis=base` as the default and treat `auto` as a diagnostic
policy arm for threshold tuning.

## h5-ar Auto-threshold Calibration Decision

The h5-ar slice passes as auto-threshold calibration diagnostics and
safe-alternative instrumentation, but it does not solve learned routing,
source-credit robustness, wrong-candidate robustness, or fallback robustness.

The same guardrail runner now supports:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-threshold
experiments/test_v05_route_quality_candidate_auto_threshold.sh
```

Reference sweep:

```text
keys = 64, 128, 256
seeds = 1..3
noisy_source_rate = 0.25, 0.50
candidate_beta/cap = 8.0/8.0
```

Readout:

```text
base-default qacc       = 0.886458
hybrid-m0p25 qacc       = 0.886545
auto-f5p8-t0p70 qacc    = 0.886545, auto_hybrid_rate = 1.000000
auto-f6p0-t0p72 qacc    = 0.886502, auto_hybrid_rate = 0.440365
auto-f6p2-t0p74 qacc    = 0.886502, auto_hybrid_rate = 0.440365
auto-f6p4-t0p76 qacc    = 0.886632, auto_hybrid_rate = 0.124696
```

Interpretation:
`auto-f5p8-t0p70` is too broad and collapses to always-hybrid. `auto-f6p0`
and `auto-f6p2` are the balanced lower-concentration thresholds. `auto-f6p4`
is more selective and has the best tiny qacc, but it gives up most
concentration relief. Keep the default at `candidate-weight-basis=base`.

## h5-as Auto-trigger Decomposition Decision

The h5-as slice passes as auto-trigger decomposition diagnostics, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds trigger/probe metrics for `candidate-weight-basis=auto`:

```text
route_quality_candidate_weight_auto_factor_trigger_rate
route_quality_candidate_weight_auto_top_share_trigger_rate
route_quality_candidate_weight_auto_factor_max_probe_mean
route_quality_candidate_weight_auto_top_share_probe_mean
```

Reference readout:

```text
auto-f5p8-t0p70:
  qacc = 0.886545
  auto_hybrid_rate = 1.000000
  factor_trigger = 0.875304
  top_share_trigger = 0.684332

auto-f6p0-t0p72:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_trigger = 0.315668
  top_share_trigger = 0.124696

auto-f6p2-t0p74:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_trigger = 0.315668
  top_share_trigger = 0.124696

auto-f6p4-t0p76:
  qacc = 0.886632
  auto_hybrid_rate = 0.124696
  factor_trigger = 0.000000
  top_share_trigger = 0.124696
```

Interpretation:
`auto-f6p0-t0p72` and `auto-f6p2-t0p74` are identical because no additional
queries fall between the two threshold pairs. `auto-f6p4-t0p76` is
top-share-only: the factor trigger is zero, so the arm is mostly base-like and
does not reduce factor max. This is useful threshold instrumentation, not a
default promotion. The live route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

## h5-at Auto-trigger Policy Ablation Decision

The h5-at slice passes as auto-trigger policy ablation diagnostics, but it does
not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds:

```text
--route-quality-candidate-weight-auto-trigger-mode any|factor|top-share
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-trigger
experiments/test_v05_route_quality_candidate_auto_trigger.sh
```

Reference readout:

```text
auto-any-f6p0-t0p72:
  qacc = 0.886502
  auto_hybrid_rate = 0.440365
  factor_gap = 3.477531
  factor_max = 5.968582

auto-factor-f6p0:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582

auto-top-t0p72:
  qacc = 0.886632
  auto_hybrid_rate = 0.124696
  factor_gap = 3.602753
  factor_max = 6.333333
```

Interpretation:
factor-triggered switching produces the lower concentration path. Top-share-only
switching matches the tiny qacc edge of the narrow auto arm but remains
base-like for factor concentration. `any` is the balanced diagnostic setting.
The default remains `candidate-weight-basis=base`, and the live route path
remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

## h5-au Factor-trigger Threshold Refinement Decision

The h5-au slice passes as factor-trigger threshold refinement diagnostics, but
it does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh --auto-factor-threshold
experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh
```

Reference readout:

```text
factor-f5p6:
  qacc = 0.886328
  auto_hybrid_rate = 0.875304
  factor_gap = 3.241454
  factor_max = 5.968582

factor-f5p8:
  qacc = 0.886328
  auto_hybrid_rate = 0.875304
  factor_gap = 3.241454
  factor_max = 5.968582

factor-f6p0:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582

factor-f6p2:
  qacc = 0.886328
  auto_hybrid_rate = 0.315668
  factor_gap = 3.471377
  factor_max = 5.968582

factor-f6p4:
  qacc = 0.886458
  auto_hybrid_rate = 0.000000
  factor_gap = 3.596599
  factor_max = 6.333333
```

Interpretation:
the factor-only threshold distribution is coarse: `5.6/5.8` are broad,
`6.0/6.2` are balanced, and `6.4` is base-like. Factor-only switching explains
the concentration-relief mechanism, but it does not outperform the cleaner
`hybrid-m0p25` lower-concentration arm or the base default on qacc. The default
remains `candidate-weight-basis=base`, and the live route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```

## h5-av Candidate-basis Policy Diagnostics Decision

The h5-av slice passes as candidate-basis policy diagnostics / safe-alternative
instrumentation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_basis_policy.sh
experiments/test_v05_route_quality_candidate_basis_policy.sh
```

It reuses the existing base-vs-hybrid promotion runner and emits a compact
policy CSV by key count and noisy-source rate. The policy compares qacc,
factor gap, factor max, wrong strength, and jump-neighbor inactivity for:

```text
base-default
hybrid-m0p25
```

Reference smoke:

```text
key_count = 128
noisy_source_rate = 0.25

base-default:
  qacc = 0.887500
  factor_gap = 3.650981
  factor_max = 6.333333
  wrong_strength = 5.471811

hybrid-m0p25:
  qacc = 0.887500
  factor_gap = 3.304388
  factor_max = 6.049084
  wrong_strength = 5.471811

recommendation = hybrid-m0p25-safe
```

Interpretation:
the smoke preserves qacc while reducing candidate-weight factor concentration,
so the policy layer recommends `hybrid-m0p25-safe` for that key/noise cell. This
does not promote factor-only `auto` and does not change route behavior. Keep the
default at `candidate-weight-basis=base`; use the policy CSV to identify
key/noise cells where `hybrid-m0p25` is a safe lower-concentration alternative.

The live route path remains:

```text
candidate value_pos -> value byte read -> proposal hint
```
