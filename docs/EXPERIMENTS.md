# Experiments

## v0.2-pre Locked Baseline

The current baseline is `dmv02` with `v0.2-pre` behavior locked. `v0.2-b` now adds coupling plus a block-local coupled proposal path, so the default weak-coupling run is no longer expected to fail the `counter` gate.

## Staged Flow 1-5

1. Run the counter baseline.

```bash
./experiments/run_v02_counter.sh
```

Expected: `counter` with `lambda_v = 0` succeeds strongly.

2. Run the counter ablation.

```bash
./experiments/run_v02_ablation.sh
```

Expected: higher `lambda_v` hurts `counter`; that confirms the baseline is already doing the right thing.

3. Run the repeating-text baseline.

```bash
./experiments/run_v02_repeating.sh
```

Expected: `field_byte_acc` stays below `oracle1_acc` but clearly above `byte_acc` during early and mid learning.

4. Run the tuned `v0.2-b` helper.

```bash
./experiments/run_v02b_tuned.sh
```

Expected: the tuned helper still gives a clean isolation control, but it is no longer the only way to keep `counter` healthy.

5. Read the control-vs-coupling comparison.

```bash
./experiments/run_v02b_counter_compare.sh
./experiments/run_v02b_repeating_compare.sh
```

Expected:

- default weak coupling now keeps `counter` at `field_byte_acc = 1.000000`, `joint_byte_acc = 1.000000`, `byte_acc = 1.000000`
- tuned no-coupling repeating text ends at `0.597656 / 0.597656 / 0.597656`
- tuned weak-coupling repeating text ends at `0.687500 / 0.687500 / 0.687500`

6. Run the 5-seed default-path regression before moving the stage boundary.

```bash
./experiments/run_v02b_counter_multiseed_compare.sh
./experiments/run_v02b_repeating_multiseed_compare.sh
```

Expected:

- `counter` weak coupling stays on the exactness plateau across seeds, with average last-10 `byte_acc` near `1.0`
- `repeating-text` weak coupling stays around `0.686` on average and beats the default no-coupling control across all five seeds
- `proposal_count = 30` remains a control for isolation, not the main `v0.2-b` gate

7. Probe the routing scaffold without changing dynamics.

```bash
./experiments/run_v03_routing_probe.sh
./experiments/run_v03_routing_fixture_compare.sh
```

Expected:

- `byte_acc`, `field_byte_acc`, and `joint_byte_acc` stay unchanged between probe off/on
- routing columns stay at zero when routing is off
- with `--route-source input-byte` or `--route-source joint-code` and `--K-jump 2`, routing columns become nonzero and show O(1)-candidate coverage only
- do not read this probe as a sparse-routing win; it is diagnostics scaffolding for a later chunk/token stage

8. Run the experimental static routing slice separately from the probe.

```bash
./experiments/run_v03_static_routing_compare.sh
./experiments/summarize_v03_routing_slice.sh
./experiments/run_v03_gap_gate_ablation.sh
./experiments/run_v03_adaptive_gate_ablation.sh
./experiments/run_v03_confidence_gate_ablation.sh
./experiments/run_v03_confidence_acceptance_ablation.sh
./experiments/run_v03_gate_diagnostics.sh
```

Watch for:

- `probe` mode stays prediction-neutral
- `jump-neighbors` may stay probe-equivalent under a conservative gate, or it may show nonzero active usage under a candidate-ranking slice
- either way, keep it default-off and experimental
- do not promote it unless the fixture sentinel stays neutral and the `repeating-text` signal is still worth carrying forward
- if scored top-K candidate ranking still leaves active usage at zero, treat the gate rather than the table ordering as the next bottleneck
- if `route-min-anchor-gap 0.0` opens the fixture faster than `repeating-text`, treat that as a diagnostic red flag, not as progress
- if reservoir/tick adaptive lowering also opens the fixture earlier than `repeating-text`, treat that as a no-go for the current gate family, not as a tuning opportunity
- if confidence-aware lowering still leaves `repeating-text` closed while the fixture starts regressing, treat confidence as a useful diagnostic signal but not yet a viable gate family
- if confidence-aware acceptance only pushes `active_jump_rate` back down on the fixture while leaving `repeating-text` unchanged, treat it as a guardrail rather than a routing win
- `run_v03_gate_diagnostics.sh` is the companion when you want the anchor-gap distribution itself; it compares `joint-code` and `input-byte` on both datasets under the default `jump-neighbors` gate, forced-open `gap0`, and the confidence-lowered `c=8.0` gate, and it is header-driven so anchor-gap thresholds, p50/p90/p99, gate margins, state-anchor hamming, trigger reasons, and later routing counters surface automatically
- treat it as diagnostic-only; if only the anchor-gap and filter counters move, that is still not a routing win
- `--route-min-anchor-gap 0.0` is only there to open the acceptance slice enough to observe whether `--route-accept-confidence-gain` changes anything; do not promote it as a default tuning path

9. Run the `state-code` route-signal probe and the candidate-source compare as diagnostic comparisons only.

```bash
./experiments/run_v03_route_key_diagnostics.sh
./experiments/run_v03_input_byte_jump_compare.sh
```

Expected:

- compare `joint-code` and default-off `state-code` on both `repeating-text` and the routing fixture
- read `state-code` as a bucket-key experiment only: the route anchor still comes from learned `joint-code`
- watch both `cycle` and `epoch` refresh on the guarded-jump arm
- treat the helper as diagnostic-only; the current CSV schema already includes the route-key / state-anchor diagnostics block, and the helper prints every column from `routing_trigger_rate` onward, so any triggered-only route-key diagnostics columns show up alongside the prediction metrics
- compare `joint-code`, `input-byte`, and `state-code + cycle` candidate buckets under probe, forced-open `gap0`, and confidence-accepted jump cases with the new helper; it is candidate-source probing only, not a routing-success claim
- if `state-code + cycle` only nudges candidate counts or fixture-side active usage while `repeating-text` stays unchanged, treat it as no-go for the current route-signal family
- if `state-code + epoch` collapses back to the off/probe boundary, treat that as confirmation that refresh, not the key itself, was the only moving part
- current reference readout: `state-code + cycle` has last-10 `route_key_anchor_match_rate ~= 0.996` on `repeating-text` and `~= 0.993` on the fixture, so the candidate key is nearly the same as the learned anchor
- current triggered-only readout says the same thing on the nodes that can actually use jumps: `triggered_route_key_anchor_match_rate ~= 0.996` on `repeating-text` and `~= 0.994` on the fixture
- current epoch-refresh readout: `route_key_anchor_match_rate` falls near zero and active routing stays off, so epoch state keys are stale rather than useful
- current candidate-source readout: `input-byte` is anchor-different as intended (`triggered_route_key_anchor_match_rate = 0.000` on `repeating-text`, `~= 0.019` on the fixture)
- current `input-byte gap0` readout: active jumps appear (`0.001172` on `repeating-text`, `0.022656` on the fixture), but `repeating-text` stays probe-equivalent while fixture `field_byte_acc` and `joint_byte_acc` drop, so this fails the repeat-lift/fixture-neutrality bar
- current `input-byte accept` readout: `active_jump_rate = 0.000` is expected under positive `route-accept-confidence-gain`, because same-input candidates have the same confidence; read this as an acceptance-predicate sanity check, not as the empirical no-go by itself
- no-go criterion for this slice: if an anchor-different bucket key only helps after forced opening, and forced opening moves the fixture before repeat-side lift appears, do not try to promote the key source; inspect candidate rejection/filter reasons with `experiments/run_v03_rejection_diagnostics.sh` before adding another candidate generator

10. Inspect candidate rejection/filter reasons as a follow-up diagnostic only.

```bash
./experiments/run_v03_rejection_diagnostics.sh
```

Expected:

- compare `joint-code` and `input-byte` under forced-open `gap0` and confidence-accepted jump-neighbor arms on both `repeating-text` and the routing fixture
- treat the helper as diagnostic-only; it prints every column from `routing_trigger_rate` onward, so any candidate-slot or reject/filter counters already present in the CSV schema are surfaced automatically
- use it to explain why a slice stays closed or why the fixture opens first; do not treat it as a routing win
- read `mean_jump_filter_candidates` over gate-passed triggered nodes; read `jump_filter_*_rate` fields as slot-level first-terminal reasons; read `jump_filter_underfilled_rate` as the node-level rate where fewer than `K-jump` candidates survive all filters
- current `fixture-input-gap0` readout: `jump_filter_selected_rate = 0.442083`, `jump_filter_anchor_gap_rate = 0.245495`, `jump_filter_local_replacement_rate = 0.121191`, and `jump_filter_underfilled_rate = 0.710330`
- current `fixture-input-accept` readout: `jump_filter_confidence_gain_rate = 0.556284`, `jump_filter_selected_rate = 0.000000`, and `jump_filter_underfilled_rate = 1.000000`
- current `repeating-text` readout: `route_gap_pass_rate = 0.001562` and `mean_jump_filter_candidates = 0.400000`, so the candidate-filter evidence is sparse there; this reinforces that the gate remains the first bottleneck

11. Run the value-bearing route-hint oracle slice.

```bash
./experiments/test_v03_route_hint_oracle.sh
./experiments/run_v03_route_hint_oracle.sh
```

Expected:

- treat this as the next semantic route-signal slice, not as another jump-neighbor gate
- `hint-oracle` must keep local neighbors intact and only add an oracle value-byte bias to proposal energy
- fixture query metrics are the primary gate; whole-file `byte_acc` is secondary because query positions are sparse
- current readout: `fixture-lr0p20` reaches `fixture_query_byte_acc = 0.875000`, and `fixture-lr0p30` / `fixture-lr0p50` move `fixture_query_byte_acc` and `route_hint_value_match_rate` to `1.000000`, while `fixture-off` is `0.200000`
- current no-regression check: `repeating-text` has `route_hint_query_count = 0.000000` and stays at `byte/field/joint = 0.687500/0.683594/0.687500` for all tested `lambda_route`
- decision: `v0.3-h1 oracle route hint` is `PASS`
- do not call this learned routing or sparse routing solved; the next stage is parsed key/value candidate delivery, then exact key lookup, then learned key/value hint discovery

12. Run the parsed value-candidate route-hint slice.

```bash
./experiments/test_v03_route_hint_parsed.sh
./experiments/run_v03_route_hint_parsed.sh
```

Expected:

- treat this as `v0.3-h2`, not learned routing
- parser should provide the matched record value position, and the graph should read the value byte from that candidate position
- watch `route_hint_candidate_lookup_count`, `route_hint_candidate_hit_rate`, and `route_hint_value_read_distance_mean`
- current readout: candidate hit rate is `1.000000`, mean value-read distance is `126.750000`, and `fixture_query_byte_acc` reaches `1.000000` at `lambda_route = 0.30/0.50`
- `repeating-text` remains unchanged with `route_hint_query_count = 0.000000`

13. Run the exact key-value route-hint slice.

```bash
./experiments/test_v03_route_hint_kv_exact.sh
./experiments/run_v03_route_hint_kv_exact.sh
```

Expected:

- treat this as `v0.3-h3`, not learned routing
- parser should build exact `KEY -> value_pos` records and resolve `?KEY=` queries with latest-record-wins semantics
- watch `kv_record_count`, `kv_query_count`, `kv_query_hit_rate`, `kv_duplicate_key_rate`, and `kv_missing_key_rate`
- current reference readout: `kv_query_hit_rate = 1.000000`, duplicate/missing rates are `0.000000`, mean value-read distance is `126.750000`, and `fixture_query_byte_acc = 1.000000` at `lambda_route = 0.30/0.50`
- smoke coverage includes one duplicate key and one missing key to verify the diagnostic counters
- `repeating-text` remains unchanged with `kv_query_count = 0.000000`

14. Run the exact key-value scale-up slice.

```bash
./experiments/test_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh
./experiments/run_v03_route_hint_kv_scale.sh --strong
```

Expected:

- treat this as `v0.3-h3a`, still symbolic exact KV routing and not learned routing
- default profile uses `lambda_route = 0.50`; `--strong` uses `lambda_route = 5.0`
  to separate candidate lookup failures from hint-strength/dynamics-margin limits
- distance sweep through `4096` should keep `kv_query_hit_rate = 1.000000` and
  `fixture_query_byte_acc = 1.000000`
- duplicate-key smoke should show latest-record-wins behavior with
  `kv_duplicate_key_rate > 0` and solved query accuracy
- missing-key smoke should show `kv_missing_key_rate > 0` and
  `route_hint_applied_rate = 0.000000`
- current default readout: distance `64/256/1024/4096` all solve query positions;
  `keys_k16`, `keys_k64`, and `noisy_mixed` keep exact hit rate at `1.000000` but
  do not saturate query accuracy at `lambda_route = 0.50`
- current strong readout: `keys_k64` and `noisy_mixed` recover to
  `fixture_query_byte_acc = 1.000000`, so those default failures are currently
  interpreted as hint-strength/dynamics-margin limits rather than exact lookup
  failures

15. Run the hashed key candidate route-hint slice.

```bash
./experiments/test_v03_route_hint_kv_hash.sh
./experiments/test_v03_route_hint_kv_hash_vote.sh
./experiments/test_v03_route_hint_kv_hash_weighted.sh
./experiments/test_v03_route_hint_kv_hash_key_shape.sh
./experiments/test_v03_route_hint_kv_hash_joint_code.sh
./experiments/test_v03_route_hint_kv_hash_route_code.sh
./experiments/test_v03_route_hint_kv_hash_route_code_stress.sh
./experiments/run_v03_route_hint_kv_hash.sh
./experiments/run_v03_route_hint_kv_hash_joint_code.sh
./experiments/run_v03_route_hint_kv_hash_route_code.sh
./experiments/run_v03_route_hint_kv_hash_route_code_stress.sh
```

Expected:

- treat this as `v0.3-h4-1`, still symbolic key hashing and not learned routing
- `hint-kv-hash` keeps the same route-hint path:
  `candidate value_pos -> value byte read -> proposal hint`
- watch `route_candidate_recall_rate`, `route_candidate_top1_rate`,
  `route_candidate_rank_mean`, `route_bucket_load_mean`,
  `route_bucket_load_max`, and `route_bucket_collision_rate`
- current default readout on a 32-key records-block/queries-block fixture:
  `bits8` and `bits16` have recall/top1/query accuracy all at `1.000000`
- current lossy readout: `bits4_kr4` recovers top-K recall to `1.000000`, but
  top-1 stays `0.500000` and query accuracy stays `0.500000`; this means the
  next bottleneck is ranking or multi-candidate hint aggregation, not whether a
  correct value_pos exists somewhere in the bucket
- `--route-hint-agg top1` is the h4-1 baseline; `--route-hint-agg vote` is the
  h4-2 multi-candidate aggregation slice
- watch `route_hint_vote_candidate_count_mean` and
  `route_hint_vote_margin_mean` when using `vote`
- current controlled vote smoke: top1 aggregation fails with
  `query_byte_acc = 0.000000`, while vote aggregation recovers the same fixture
  to `query_byte_acc = 1.000000`
- current standard vote readout: `bits4_kr4` improves from `0.500000` to
  `0.700000`, and `bits6_kr4` improves from `0.875000` to `0.956250`; this is a
  mitigation, not a complete collision/ranking solution
- `--route-hint-agg weighted-vote` with `--route-candidate-score value-vote` is
  the h4-3 scoring instrumentation slice
- watch `route_hint_correct_value_vote_share_mean`,
  `route_hint_vote_entropy_mean`, and `route_hint_unique_values_mean`
- current weighted smoke: `value-vote` reaches `query_byte_acc = 1.000000`,
  `correct_value_vote_share = 0.900000`, and `unique_values = 2.000000`
- current standard weighted readout: `bits4_kr4_weighted_value` stays at
  `0.700000`, and `bits6_kr4_weighted_value` stays at `0.956250`; this means
  value-frequency scoring is neutral on the default 32-key sweep because most
  collided buckets do not contain repeated value bytes
- `--route-candidate-score key-shape` is the h4-4 deterministic symbolic
  scoring baseline; it ranks hash-bucket candidates by key length, digit count,
  common prefix, and common suffix before top1 selection
- current key-shape smoke: insertion baseline has `recall = 1.000000` but
  `top1 = 0.000000` and `query_byte_acc = 0.000000`; key-shape promotes the
  correct candidate to `top1 = 1.000000` and recovers `query_byte_acc = 1.000000`
- current standard key-shape readout: `bits4_kr1_key_shape`,
  `bits4_kr4_key_shape`, and `bits6_kr4_key_shape` all reach
  `query_byte_acc = 1.000000`; this is a symbolic deterministic scoring
  baseline, not learned routing
- `--route-hash-source joint-code-key` is the h4-5b learned-code key-region
  diagnostic; it hashes each parsed key byte through the current learned
  `best_joint_byte()` code and rebuilds buckets in `GraphV02::begin_epoch`
- current joint-code smoke reaches `query_byte_acc = 1.000000`, which verifies
  the route-hint plumbing
- current 32-key joint-code readout is not yet a learned routing win:
  `bits4_kr4_vote` reaches `query_byte_acc = 0.500000` with
  `recall = 0.675000`, while `bits16_kr4_vote` reaches
  `query_byte_acc = 0.462500` with `recall = 0.687500`; this exposes a learned
  representation/bucket ambiguity gap relative to raw-key and key-shape
- h4-5c representation diagnostics are appended as
  `key_region_count`, `key_region_joint_decode_acc`, `raw_key_unique_count`,
  `joint_key_unique_count`, `joint_signature_collision_rate`, and
  `joint_vs_raw_candidate_overlap_rate`
- current 32-key representation readout: `bits16_kr4_vote` has
  `key_region_joint_decode_acc = 0.093750`, `raw_key_unique_count = 32.000000`,
  `joint_key_unique_count = 12.000000`, and
  `joint_signature_collision_rate = 0.625000`; this supports the interpretation
  that current next-byte joint code does not preserve key identity strongly
- `--route-hash-source route-code-key` with `--route-code-aux 1` is the h4-5d
  route identity auxiliary slice; it trains a separate route field toward input
  identity on key-region bytes before hashing the route-code key sequence
- route-code diagnostics are appended as `key_region_route_decode_acc`,
  `route_key_unique_count`, `route_signature_collision_rate`, and
  `route_vs_raw_candidate_overlap_rate`
- current 32-key route-code readout: `bits16_kr4_vote` reaches
  `query_byte_acc = 1.000000`, `recall = 1.000000`, `top1 = 1.000000`,
  `key_region_route_decode_acc = 1.000000`, `route_key_unique_count = 32.000000`,
  and `route_signature_collision_rate = 0.000000`; this is an explicit identity
  auxiliary baseline, not general learned semantic routing
- h4-5e route-code stress writes
  `results/v03_route_hint_kv_hash_route_code_stress_summary.csv`
- current stress readout: 32/64 keys at `bits16,K=4,eta=0.25` solve with
  `query_byte_acc = 1.000000`, while 128 keys keep
  `recall = 1.000000`, `top1 = 1.000000`, and route collision `0.000000` but
  drop to `query_byte_acc = 0.562500`; interpret this as a downstream
  dynamics/hint-strength/relaxation limit, not candidate retrieval failure
- current low-bit route-code readout mirrors sparse hash behavior:
  `bits4,K=4` has `recall = 1.000000` but `top1 = 0.500000` and
  `query_byte_acc = 0.693750`; `bits6,K=4` improves to
  `query_byte_acc = 0.943750`
- h4-5f route-code dynamics margin smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_dynamics.sh
```

- h4-5f standard dynamics sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh
```

- h4-5f writes
  `results/v03_route_hint_kv_hash_route_code_dynamics_summary.csv` with
  `fixture_query_hi_acc`, `fixture_query_lo_acc`,
  `query_route_hint_margin_mean`,
  `query_local_margin_against_route_mean`, and
  `query_effective_route_margin_mean`
- current 128-key dynamics readout: retrieval remains solved
  (`recall = 1.000000`, `top1 = 1.000000`,
  `key_region_route_decode_acc = 1.000000`) across the sweep; increasing
  `lambda_route` from `0.5 -> 10.0` moves query byte accuracy
  `0.198438 -> 1.000000` and effective margin `-6.808821 -> 5.491514`
- cycles and route-target proposal injection do not monotonically recover the
  128-key setting, so this slice points primarily to hint strength/effective
  margin rather than candidate retrieval or proposal coverage
- h4-5g adaptive route strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh
```

- h4-5g standard adaptive sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh
```

- h4-5g writes
  `results/v03_route_hint_kv_hash_route_code_adaptive_summary.csv`
- current 128-key adaptive readout: fixed low `lambda_route = 0.5` stays weak
  (`query_byte_acc = 0.173437`), fixed strong `lambda_route = 10.0` solves
  (`1.000000`), and margin mode recovers with lower mean strength:
  `alpha = 1.0` reaches `query_byte_acc = 0.998438` with
  `route_strength_mean = 4.871687`; `alpha = 1.5` reaches `1.000000` with
  `route_strength_mean = 6.454238`
- interpret h4-5g as a calibrated route-hint strength diagnostic under correct
  candidates, not as learned/noisy routing robustness
- h4-5h wrong-candidate corruption smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_corruption.sh
```

- h4-5h standard corruption sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh
```

- h4-5h writes
  `results/v03_route_hint_kv_hash_route_code_corruption_summary.csv`
- current corruption readout: with corruption `0.25`, keep-confidence adaptive
  gets `query_byte_acc = 0.648438`, `damage = 0.351562`, and
  `wrong_hint_strength_mean = 6.178977`; low-confidence corrupted hints with
  `route_min_confidence = 0.5` suppress wrong strength to `0.000000` and reach
  `query_byte_acc = 0.662500`
- interpret h4-5h as confidence guardrail instrumentation: wrong hint strength
  can be suppressed when wrong candidates are low-confidence, but damage
  reduction is modest and wrong-candidate robustness is not solved
- h4-5i candidate/value confidence calibration smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_confidence.sh
```

- h4-5i standard confidence sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh
```

- h4-5i writes
  `results/v03_route_hint_kv_hash_route_code_confidence_summary.csv`
- current confidence readout: under corruption `0.25` with correct fallback
  preserved, candidate route weight gives `candidate_conf_gap = 0.000000`;
  value-support confidence gives `value_conf_gap = 0.429167` and lowers
  `wrong_hint_strength_mean` from `5.874975` to `3.596367`
- value-support confidence does not improve qacc here
  (`0.853125 -> 0.837500`), so h4-5i is confidence calibration
  instrumentation, not wrong-candidate robustness
- h4-5j scorer-agreement confidence smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh
```

- h4-5j standard scorer-agreement sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh
```

- h4-5j writes
  `results/v03_route_hint_kv_hash_route_code_agreement_summary.csv`
- current scorer-agreement readout: under corruption `0.25` with correct
  fallback preserved, agreement confidence gives `route_agreement_conf_gap =
  0.458020`, lowers `wrong_hint_strength_mean` from `6.308168` to `3.775402`,
  and gives qacc `0.843750` versus unscaled `0.842188`
- power `2.0` suppresses wrong strength further (`2.423250`) but also lowers
  qacc (`0.832812`), so h4-5j is scorer-agreement confidence
  instrumentation with only limited mitigation
- h4-5k confidence-gated aggregation smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh
```

- h4-5k standard confidence-gated aggregation sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh
```

- h4-5k writes
  `results/v03_route_hint_kv_hash_route_code_gated_agg_summary.csv`
- current h4-5k readout: under preserve-correct corruption `0.25`,
  `confidence-gated` uses both policies (`vote_rate = 0.187500`,
  `weighted_rate = 0.812500`) and splits query quality
  (`lowconf_qacc = 0.250000`, `highconf_qacc = 0.990385`)
- h4-5k qacc is a limited mitigation in this setting:
  `corrupt-gated-agg = 0.851563` versus unscaled `0.850000`,
  value-support `0.831250`, and agreement-strength scaling `0.834375`
- wrong hint strength is not reliably reduced (`5.806380` vs unscaled
  `5.286897`), so h4-5k is aggregation-policy instrumentation, not
  wrong-candidate robustness solved
- h4-5l low-confidence diagnostics smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh
```

- h4-5l standard low-confidence diagnostics sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh
```

- h4-5l writes
  `results/v03_route_hint_kv_hash_route_code_lowconf_diagnostics_summary.csv`
- current h4-5l readout separates preserve-correct and remove-correct failure
  modes under corruption `0.25`
- preserve-correct low-confidence failures keep the correct candidate in top-K
  (`lowconf_candidate_recall = 1.000000`) but lose rank/aggregation quality
  (`lowconf_top1 = 0.000000`, `correct_value_vote_share = 0.500000`,
  `vote_entropy = 1.000000`)
- remove-correct drops candidate recall (`lowconf_candidate_recall = 0.000000`,
  `highconf_candidate_recall = 0.789062`), so that branch needs fallback or
  abstain behavior rather than another aggregation tweak
- h4-5l is diagnostics/actionable split only; it does not change route behavior
  and does not solve wrong-candidate robustness
- `repeating-text` has no KV queries and remains unchanged in the hash smoke

- h4-5m low-confidence policy split smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
```

- h4-5m standard low-confidence policy sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh
./experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh --full
```

- h4-5m writes
  `results/v03_route_hint_kv_hash_route_code_lowconf_policy_summary.csv`
- h4-5m compares `aggregate`, `none`, and `weak-vote` under the same
  confidence-gated routing setup as h4-5k/h4-5l, with policy-specific clean
  baselines for `damage_vs_clean`
- current h4-5m smoke readout at corruption `0.25`: preserve-correct aggregate
  reaches `qacc = 0.854688` with `lowconf_candidate_recall = 1.000000` and
  `lowconf_top1 = 0.000000`; preserve-correct `none` drops to
  `qacc = 0.812500`, while `weak-vote` stays close at `qacc = 0.848438`
- remove-correct rows stay at `qacc = 0.804688` with high-confidence candidate
  recall `0.789062`; this is candidate availability / fallback territory, not
  an aggregation-policy fix
- h4-5m passes as low-confidence policy instrumentation/actionable split only:
  preserve-correct points to aggregation/ranking, remove-correct points to
  abstain, fallback, or redundant candidate sources

- h4-5n fallback source smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh
```

- h4-5n standard fallback source sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh --full
```

- h4-5n writes
  `results/v03_route_hint_kv_hash_route_code_fallback_source_summary.csv`
- h4-5n compares `--route-fallback-source off`, `key-shape`, and in
  standard/full mode `raw-key`; fallback is a diagnostic secondary candidate
  source and must not be described as learned routing
- current h4-5n smoke readout at corruption `0.25`: preserve-correct keeps
  fallback unused and unchanged (`qacc = 0.854688`), while remove-correct
  `key-shape` improves `qacc = 0.804688 -> 0.839062`
- key-shape fallback recovers candidate availability in remove-correct
  (`fallback_used_rate = 0.210938`, `fallback_recall = 1.000000`,
  `fallback_success_rate = 1.000000`), but fallback-used qacc remains low
  (`0.237037`), so this is fallback instrumentation / limited mitigation, not
  robustness solved

- h4-5o projected route-hint delta smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh
```

- h4-5o standard projected delta sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh
./experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh --full
```

- h4-5o writes
  `results/v03_route_hint_kv_hash_route_code_projected_delta_summary.csv`
- h4-5o compares `--route-delta-mode target-only` with `projected`, plus
  `--route-pull-scale` / `--route-push-scale`; projected C-version only rewards
  direct transitions into the routed target nibble and penalizes direct
  transitions away from it
- current h4-5o smoke readout at corruption `0.25`: `projected 1.0/1.0`
  matches `target-only`; `projected pull=2.0 push=1.0` improves preserve-correct
  qacc (`0.854688 -> 0.875000`) but does not improve remove-correct
  key-shape fallback qacc (`0.237037 -> 0.237037`)
- h4-5o passes as projected-delta instrumentation / limited mitigation only:
  it verifies the local query-node route-delta hook and fallback subset metrics,
  but it does not solve fallback integration or wrong-candidate robustness
