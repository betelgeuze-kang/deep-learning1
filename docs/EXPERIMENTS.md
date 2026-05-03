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

- h4-5p fallback hint strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh
```

- h4-5p standard fallback hint strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh --full
```

- h4-5p writes
  `results/v03_route_hint_kv_hash_route_code_fallback_strength_summary.csv`
- h4-5p compares `--route-fallback-strength-mult` on remove-correct
  key-shape fallback, with target-only and projected `pull=2.0` baselines when
  cheap; this is diagnostics-only and should be read as a bottleneck probe,
  not as a new robustness claim
- h4-5p smoke decision: `PASS` as fallback-strength diagnostics / limited
  mitigation. Target-only key-shape fallback improves from qacc `0.839062` and
  fallback_qacc `0.237037` at `mult=1.0` to qacc `0.898437` and fallback_qacc
  `0.518518` at `mult=10.0`. Projected `pull=2.0` improves at moderate
  multipliers but is less monotonic (`mult=5.0` qacc `0.868750`,
  fallback_qacc `0.377777`; `mult=10.0` qacc `0.846875`,
  fallback_qacc `0.274074`). This shows fallback-used failures are partly
  strength / hint-integration limited, but it is still not learned routing or
  wrong-candidate robustness solved.

- h4-5q fallback adaptive strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh
```

- h4-5q standard fallback adaptive strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh --full
```

- h4-5q writes
  `results/v03_route_hint_kv_hash_route_code_fallback_adaptive_summary.csv`
- h4-5q adds `--route-fallback-strength-mode fixed|margin`,
  `--route-fallback-lambda-base`, `--route-fallback-lambda-max`, and
  `--route-fallback-margin-alpha`, plus fallback subset strength distribution
  columns
- h4-5q smoke decision: `PASS` as fallback-adaptive diagnostics /
  lower-strength limited mitigation. Fixed `mult=10.0` remains stronger
  (`fallback_qacc=0.518518`, mean strength `55.376972`), while margin
  `alpha=8.0`, max `40.0` improves over fixed `mult=1.0` with lower mean
  strength (`fallback_qacc=0.400000`, mean strength `25.902632`). This does
  not solve fallback robustness; next probe is fallback persistence / TTL.

- h4-5r fallback channel-specific strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh
```

- h4-5r standard fallback channel-specific strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh --full
```

- h4-5r writes
  `results/v03_route_hint_kv_hash_route_code_fallback_channel_summary.csv`
- h4-5r adds `--route-fallback-hi-strength-mult` and
  `--route-fallback-lo-strength-mult`, plus
  `route_fallback_hi_effective_strength_mean` and
  `route_fallback_lo_effective_strength_mean`
- h4-5r smoke decision: `PASS` as fallback-channel diagnostics / limited
  mitigation. Balanced fallback `mult=5` reaches qacc `0.887500` and
  fallback_qacc `0.466666`; low-channel boost reaches qacc `0.904687` and
  fallback_qacc `0.548148`; high-channel boost falls to qacc `0.868750` and
  fallback_qacc `0.377778`. This suggests the residual fallback-used
  integration bottleneck is more low-nibble sensitive, but it still uses
  symbolic key-shape fallback and hand-set channel multipliers.

- h4-5s fallback channel-adaptive strength smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh
```

- h4-5s standard fallback channel-adaptive strength sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh --full
```

- h4-5s writes
  `results/v03_route_hint_kv_hash_route_code_fallback_channel_adaptive_summary.csv`
- h4-5s adds `--route-fallback-channel-strength-mode fixed|margin`,
  `--route-fallback-hi-margin-alpha`, `--route-fallback-lo-margin-alpha`,
  `--route-fallback-hi-lambda-max`, and `--route-fallback-lo-lambda-max`, plus
  channel-local margin diagnostics
- h4-5s smoke decision: `PASS` as fallback channel-adaptive instrumentation /
  lower-strength limited mitigation. Margin-balanced reaches qacc `0.864062`
  and fallback_qacc `0.355555`; lo-biased margin reaches qacc `0.871875` and
  fallback_qacc `0.392592` by increasing low-channel effective strength
  (`16.427150 -> 23.382717`). Fixed lo-boost remains stronger
  (`fallback_qacc = 0.525926`), so this is not fallback robustness solved.

- h4-5t low-nibble fallback strength grid smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh
```

- h4-5t standard low-nibble fallback strength grid:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh --full
```

- h4-5t writes
  `results/v03_route_hint_kv_hash_route_code_fallback_low_grid_summary.csv`
- h4-5t keeps `route_fallback_hi_strength_mult = 5.0` and sweeps the low
  channel multiplier; it uses the existing h4-5r channel-strength options and
  does not add new C++ behavior
- h4-5t smoke decision: `PASS` as low-channel strength calibration /
  limited mitigation. The current smoke peaks around `lo_mult=10.0`:
  `lo5 fallback_qacc=0.400000`, `lo7.5=0.540741`, `lo10=0.548148`,
  `lo15=0.533333`. This supports the low-nibble bottleneck interpretation and
  suggests the next TTL/persistence probe should compare against the
  `lo_mult=7.5..10` sweet spot.

- h4-5u fallback persistence / TTL smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh
```

- h4-5u standard fallback persistence / TTL sweep:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh
./experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh --full
```

- h4-5u writes
  `results/v03_route_hint_kv_hash_route_code_fallback_persistence_summary.csv`
- h4-5u adds `--route-fallback-persist-cycles`, plus
  `route_fallback_persist_used_rate` and
  `route_fallback_persist_cycles_mean`
- h4-5u smoke decision: `PASS` as fallback persistence instrumentation /
  neutral diagnostics. Persistence accounting is wired (`ttl=3` reports
  used rate `1.000000` and mean cycles `3.000000`), but the current policy
  does not improve the calibrated low-channel baselines:
  `lo7.5 ttl0 -> ttl3` fallback_qacc `0.540741 -> 0.525926`, and
  `lo10 ttl0 -> ttl3` remains `0.548148 -> 0.548148`. This suggests the
  current short TTL update-priority hook is not the missing lever for
  fallback robustness.

- h4-5v route-credit smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh
```

- h4-5v standard route-credit run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh --full
```

- h4-5v writes
  `results/v03_route_hint_kv_hash_route_code_route_credit_summary.csv`
- h4-5v adds value-position credit options:
  `--route-credit-learning`, `--route-credit-score-weight`,
  `--route-credit-eta-reward`, `--route-credit-eta-slash`,
  `--route-credit-decay`, and `--route-credit-clip`
- h4-5v smoke decision: `PASS` as route-credit separation instrumentation /
  tiny mitigation. Preserve-correct corruption with credit learning produces
  a positive credit separation (`correct_mean=0.313938`,
  `wrong_mean=-0.796331`, `gap=1.110268`) and a small qacc move
  (`0.845312 -> 0.850000`). This validates the credit ledger and weighting
  path but does not solve wrong-candidate robustness.
- h4-5v interpretation: route credit can learn a candidate-quality signal, but
  the current effect on query accuracy is small. The remaining bottleneck is
  likely a combination of credit strength, credit granularity, and fallback
  hint integration dynamics.
- h4-5w route-credit ablation smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh
```

- h4-5w standard route-credit ablation run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh
./experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh --full
```

- h4-5w writes
  `results/v03_route_hint_kv_hash_route_code_route_credit_ablation_summary.csv`
- h4-5w is route-credit ablation diagnostics only: it sweeps value-pos credit
  knobs, compares fallback low-channel strength combinations, and keeps a
  query-value probe wired into the smoke; do not read it as robustness solved
  or learned routing solved
- h4-5w smoke decision: `PASS` as route-credit ablation instrumentation /
  limited mitigation. The smoke keeps value-pos credit active
  (`value-pos-strong-slash` gap `0.618182`), wires query-value edge credit
  (`query-value-probe` gap `0.598951`), and shows credit plus low-channel
  fallback can move the fallback subset (`fallback-lo7p5-off` fallback_qacc
  `0.688889`, `fallback-lo10-on` fallback_qacc `0.777778`). This is not
  wrong-candidate robustness solved and not learned routing solved.
- h4-5x credit × fallback factorial smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
```

- h4-5x standard credit × fallback factorial run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh
./experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh --full
```

- h4-5x writes
  `results/v03_route_hint_kv_hash_route_code_credit_fallback_factorial_summary.csv`
- h4-5x crosses true `--route-credit-mode off`, `value-pos`, and
  `query-value` with key-shape fallback `hi_mult=5`, low-channel multipliers
  `7.5/10/15`, and both preserve-correct and remove-correct corruption rows
- h4-5x smoke decision: `PASS` as credit × fallback integration diagnostics /
  limited mitigation. Preserve-correct qacc stays neutral (`0.862500`) while
  credit separates candidates (`value-pos gap 0.463636`, `query-value gap
  0.750000`). In remove-correct rows, credit lifts qacc from `0.912500` to
  `0.925000` at `lo=7.5/10` and fallback_qacc from `0.688889` to `0.733334`;
  `lo=15` remains weaker (`off qacc 0.906250`, credit-on qacc 0.918750,
  fallback_qacc 0.711111). This is not wrong-candidate robustness solved and
  not learned routing solved.
- h4-5y route-credit calibration smoke:

```bash
./experiments/test_v03_route_hint_kv_hash_route_code_credit_calibration.sh
```

- h4-5y standard route-credit calibration run:

```bash
./experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh
./experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh --full
```

- h4-5y writes
  `results/v03_route_hint_kv_hash_route_code_credit_calibration_summary.csv`
- h4-5y calibrates active `value-pos` versus `query-value` credit around
  key-shape fallback with `hi_mult=5`, `lo_mult=7.5/10`, score weight,
  slash strength, corruption rate, and preserve/remove rows; smoke also keeps
  true `off` baselines
- h4-5y smoke decision: `PASS` as route-credit strength/stability
  calibration diagnostics and limited mitigation. Off baselines remain
  credit-neutral. Active credit rows all produce positive gaps. Query-value
  preserve rows show larger separation (`gap=0.750000`) than comparable
  value-pos rows (`0.290625` or `0.236364` in the smoke). Remove rows populate
  fallback metrics; examples include `value-pos remove lo10 sw1 slash0.20
  cr0.25` with qacc `0.925000`, gap `0.642326`, fallback_qacc `0.733334`,
  and `query-value remove lo7.5 sw2 slash0.10 cr0.25` with qacc `0.925000`,
  gap `0.450000`, fallback_qacc `0.733334`. This is calibration only, not
  wrong-candidate robustness solved.
- h5-a route-plasticity smoke:

```bash
./experiments/test_v05_route_credit_plasticity.sh
```

- h5-a standard route-plasticity run:

```bash
./experiments/run_v05_route_credit_plasticity.sh
./experiments/run_v05_route_credit_plasticity.sh --full
```

- h5-a writes `results/v05_route_credit_plasticity_summary.csv`
- h5-a adds a persistent `--route-plasticity-ledger` plus
  `--route-credit-learn-after-epoch` / `--route-credit-apply-after-epoch`
  warmup gates. The smoke uses the h4-5y query-value credit carry-forward cell
  with key-shape fallback `hi_mult=5`, `lo_mult=10`.
- h5-a smoke decision: `PASS` as route-plasticity ledger instrumentation.
  Ledger rows populate `route_plasticity_ledger_size` and
  `route_plasticity_ledger_mean_abs_credit`, while learn/apply gates separate
  accumulated credit from when it affects weighted candidate votes. The smoke
  also asserts `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`, preserving the value-bearing path and not
  reviving jump-neighbor replacement. This is not learned routing solved and
  not wrong-candidate robustness solved.
- h5-b source/bucket route-credit smoke:

```bash
./experiments/test_v05_route_source_credit.sh
```

- h5-b standard source/bucket route-credit run:

```bash
./experiments/run_v05_route_source_credit.sh
./experiments/run_v05_route_source_credit.sh --full
```

- h5-b writes `results/v05_route_source_credit_summary.csv`
- h5-b adds disabled-by-default source/bucket credit knobs:
  `--route-source-credit-learning`,
  `--route-source-credit-score-weight`,
  `--route-source-credit-eta-reward`,
  `--route-source-credit-eta-slash`,
  `--route-source-credit-decay`, and
  `--route-source-credit-clip`
- h5-b smoke decision: `PASS` as source/bucket route-credit
  instrumentation / responsibility signal. In remove-correct corruption,
  source-on keeps the value-bearing lookup/read path populated and separates
  source responsibility: source credit size `73.000000`, primary mean
  `0.023438`, fallback mean `0.300000`, gap `0.276563`, primary slashed rate
  `0.281250`, and fallback rewarded rate `1.000000`. The smoke also verifies
  `routing_trigger_rate = 0.000000` and `active_jump_rate = 0.000000`. qacc is
  neutral in this smoke, so this is not fallback robustness solved and not
  learned routing solved.
- h5-c source-credit policy smoke:

```bash
./experiments/test_v05_route_source_credit_policy.sh
```

- h5-c standard source-credit policy run:

```bash
./experiments/run_v05_route_source_credit_policy.sh
./experiments/run_v05_route_source_credit_policy.sh --full
```

- h5-c writes `results/v05_route_source_credit_policy_summary.csv`
- h5-c adds `--route-source-credit-learning`,
  `--route-source-credit-score-weight`,
  `--route-source-credit-eta-reward`,
  `--route-source-credit-eta-slash`, and the persistent
  `--route-plasticity-ledger` carry-forward cell. The smoke keeps remove-correct
  corruption at `0.25` with key-shape fallback `hi_mult=5`, `lo_mult=10`.
- h5-c smoke decision: `PASS` as source-credit policy calibration
  instrumentation / neutral diagnostics. Learn-only creates a source gap
  (`0.276563`) without applying it; source ranking keeps the same gap but
  turns on `source_apply_active = 1.000000`; source ranking+strength doubles
  the gap to `0.553125`; and the persistent-ledger row only changes persistent
  state (`ledger_size = 0 -> 59`, `mean_abs_credit = 0.711864`) while qacc
  stays `0.931250` on the ledger rows. This is policy calibration, not
  robustness solved.
- h5-d noisy-source policy smoke:

```bash
./experiments/test_v05_route_source_credit_noisy_source.sh
```

- h5-d standard noisy-source policy run:

```bash
./experiments/run_v05_route_source_credit_noisy_source.sh
./experiments/run_v05_route_source_credit_noisy_source.sh --full
```

- h5-d writes `results/v05_route_source_credit_noisy_source_summary.csv`
- h5-d keeps remove-correct corruption at `0.25` and probes two source-quality
  branches: weak `joint-code-key` primary with symbolic `key-shape` fallback,
  and explicit `noisy-route-code` fallback/source stress with
  `--route-noisy-source-rate 1.0`.
- h5-d smoke decision: `PASS` as noisy / learned-like source policy
  diagnostics. The smoke keeps `route_hint_candidate_lookup_count > 0`,
  `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`,
  and `active_jump_rate = 0.000000`. The weak joint branch learns a positive
  source gap for useful key-shape fallback, while the explicit noisy branch
  learns a negative source gap and populates
  `route_source_credit_noisy_mean < 0` plus nonzero noisy slash diagnostics.
  This is source-quality separation instrumentation, not robustness solved.
- h5-e noisy-source scale smoke:

```bash
./experiments/test_v05_route_source_credit_noisy_scale.sh
```

- h5-e standard noisy-source scale run:

```bash
./experiments/run_v05_route_source_credit_noisy_scale.sh
./experiments/run_v05_route_source_credit_noisy_scale.sh --full
```

- h5-e writes `results/v05_route_source_credit_noisy_scale_summary.csv`
- h5-e smoke crosses key counts `32/64`, seeds `1/2`, and noisy rates
  `0.50/1.00`. Standard mode uses key counts `64/128`, seeds `1..3`, and
  noisy rates `0.25/0.50`; full mode expands to key counts `64/128/256`,
  seeds `1..5`, and noisy rates `0.10/0.25/0.50/1.00`.
- h5-e smoke decision: `PASS` as noisy-source multi-seed / scale stability
  instrumentation. The weak `joint-code-key` primary plus `key-shape`
  fallback branch keeps positive fallback source gaps across the smoke. The
  explicit `noisy-route-code` branch keeps negative noisy-candidate credit and
  nonzero noisy slash diagnostics across key counts and seeds. At
  `noise=1.0`, source gap is also negative; at mixed `noise=0.5`, source gap
  can be positive because the source still contains correct fallback support,
  so the noisy-candidate credit/slash metrics are the sharper signal. This is
  stability instrumentation, not source-credit robustness solved.
- h5-f learned-source stress smoke:

```bash
./experiments/test_v05_route_source_credit_learned_source_stress.sh
```

- h5-f standard learned-source stress run:

```bash
./experiments/run_v05_route_source_credit_learned_source_stress.sh
./experiments/run_v05_route_source_credit_learned_source_stress.sh --full
```

- h5-f writes
  `results/v05_route_source_credit_learned_source_stress_summary.csv`
- h5-f adds `--route-code-key-region-keep-prob` and
  `--route-code-aux-noise-rate` as default-off route-code identity weakening
  controls. They apply only to the route-code identity auxiliary update, so
  key signature readout still reads the learned route field rather than
  directly corrupting the route key.
- h5-f smoke crosses key counts `32/64`, seeds `1/2`, and two branches:
  clean full route-code identity supervision and weak learned-source stress
  (`keep=0.25`, `aux_noise=0.75`). Clean rows keep route decode, primary
  recall, and qacc at `1.000000`. Weak rows lower route-code decode and
  primary recall, trigger key-shape fallback, and populate positive
  source-credit gap, primary slash, and fallback reward diagnostics.
- h5-f smoke decision: `PASS` as weaker learned-source stress
  instrumentation. This is source-quality detection under controlled route-code
  identity weakening, not learned routing solved and not source-credit
  robustness solved.
- h5-g weak learned-source scale smoke:

```bash
./experiments/test_v05_route_source_credit_learned_source_scale.sh
```

- h5-g standard weak learned-source scale run:

```bash
./experiments/run_v05_route_source_credit_learned_source_scale.sh
./experiments/run_v05_route_source_credit_learned_source_scale.sh --full
```

- h5-g writes
  `results/v05_route_source_credit_learned_source_scale_summary.csv`
- h5-g smoke crosses key counts `64/128`, seeds `1/2`, and four arms:
  `clean-off`, `mid-off`, `weak-off`, and `weak-fallback-ledger`.
- h5-g uses clean route-code identity (`keep=1.0`, `aux_noise=0.0`), mid
  weakening (`keep=0.5`, `aux_noise=0.25`), and weak learned-source stress
  (`keep=0.25`, `aux_noise=0.75`).
- h5-g smoke decision: `PASS` as weak learned-source multi-seed / scale
  stability diagnostics. Mean smoke readout:

```text
clean-off:
  qacc=1.000000, decode=1.000000, primary_recall=1.000000
mid-off:
  qacc=0.970313, decode=0.630937, primary_recall=0.994531
weak-off:
  qacc=0.185938, decode=0.000000, primary_recall=0.285938
weak-fallback-ledger:
  qacc=0.460156, decode=0.000000, primary_recall=0.285938,
  fallback_used=0.714063, source_gap=0.305619,
  primary_slash=0.467693, fallback_reward=1.000000
```

Interpretation:
source weakening produces a stable degradation curve over the small key/seed
smoke, and key-shape fallback plus source-credit ledger partially mitigates
the weak-source damage while populating responsibility signals. This remains
controlled scale/stability instrumentation with symbolic fallback, not learned
routing solved and not source-credit robustness solved.
- h5-h fallback-source ablation smoke:

```bash
./experiments/test_v05_route_source_credit_fallback_ablation.sh
```

- h5-h standard fallback-source ablation run:

```bash
./experiments/run_v05_route_source_credit_fallback_ablation.sh
./experiments/run_v05_route_source_credit_fallback_ablation.sh --full
```

- h5-h writes
  `results/v05_route_source_credit_fallback_ablation_summary.csv`
- h5-h smoke keeps the weak route-code source fixed (`keep=0.25`,
  `aux_noise=0.75`) and crosses key counts `64/128`, seeds `1/2`, and
  fallback sources `off`, `raw-key`, `key-shape`, and `noisy-route-code`.
- h5-h smoke decision: `PASS` as fallback-source dependence / stability
  diagnostics. Mean smoke readout:

```text
fallback-off:
  qacc=0.213281, primary_recall=0.316406, fallback_used=0.000000
fallback-raw-key:
  qacc=0.650000, fallback_used=0.683594, fallback_recall=1.000000
fallback-key-shape:
  qacc=0.437500, fallback_used=0.683594, fallback_recall=1.000000,
  source_gap=0.299223
fallback-noisy-route-code:
  qacc=0.173437, fallback_used=0.683594, fallback_recall=0.000000,
  source_gap=-0.207562, noisy_mean=-0.201440, noisy_slash=0.979234
```

Interpretation:
`raw-key` and `key-shape` are symbolic fallback controls, with `key-shape`
remaining the symbolic upper-bound source-credit branch. `noisy-route-code`
acts as a bad fallback stress and gets negative source/noisy credit. This
separates fallback-source dependence from learned-source quality, but it is not
learned routing solved and not source-credit robustness solved.

## h5-i Source-credit Fallback Policy Calibration Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_policy.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_policy.sh
```

The h5-i smoke keeps the weak route-code source from h5-g/h5-h fixed and
compares source-credit fallback policy modes:

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

Decision:
`h5-i` passes as source-credit fallback-policy calibration diagnostics, but it
does not solve learned routing, source-credit robustness, wrong-candidate
robustness, or fallback robustness.

Interpretation:
`key-shape` source credit produces a positive source gap and the apply modes
are wired separately: ranking changes selected-fallback diagnostics, strength
raises route-source strength, and ranking-strength combines both. However,
qacc remains neutral across these key-shape policy modes. `noisy-route-code`
is correctly treated as a bad fallback stress: it gets negative noisy/source
credit and high noisy slash, does not recover fallback recall, and strength
does not increase beyond `1.0`. `raw-key` remains a symbolic ceiling. This is
policy calibration instrumentation on the value-bearing route-hint path, not
learned routing solved.

## h5-j Fallback Candidate-quality Gap Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_quality.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_quality.sh
```

The h5-j smoke fixes the weak route-code source and compares `raw-key` and
`key-shape` fallback candidate quality under `vote`, `weighted-vote`, and
source-credit `ranking-strength`.

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

raw-weighted-policy:
  qacc=0.943750, fallback_qacc=1.000000,
  source_gap=0.325494, selected_fallback=0.875000

keyshape-weighted-policy:
  qacc=0.960938, fallback_qacc=1.000000,
  source_gap=0.325494, selected_fallback=0.875000
```

Both fallback sources keep low top1 (`candidate_top1=0.031250`) and mean rank
`2.500000`, so the smoke does not support a top1-solved interpretation.
Instead, weighted-vote raises correct-value support and lowers entropy enough
to rescue both sources. The immediate bottleneck is fallback aggregation
quality, not fallback recall alone.

Decision:
`h5-j` passes as fallback candidate-quality gap diagnostics, but it does not
solve learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

## h5-k Fallback Aggregation Policy Calibration Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_fallback_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_fallback_aggregation.sh
```

The h5-k smoke keeps the weak route-code source fixed and compares fallback
aggregation policies for `raw-key` and `key-shape` fallback:

- `top1`
- `vote`
- `weighted-vote`
- confidence-gated low=`vote`, high=`weighted-vote`
- confidence-gated low=`weighted-vote`, high=`weighted-vote`

Reference smoke readout:

```text
raw-key:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.328125, fallback_qacc=0.312500
  weighted qacc=0.943750, fallback_qacc=0.987500
  gated vote/weighted qacc=0.739062, vote_rate=0.317188
  gated weighted/weighted qacc=0.943750

key-shape:
  top1 qacc=0.906250, fallback_qacc=1.000000
  vote qacc=0.204688, fallback_qacc=0.166071
  weighted qacc=0.956250, fallback_qacc=0.996429
  gated vote/weighted qacc=0.443750, vote_rate=0.678125
  gated weighted/weighted qacc=0.956250
```

Interpretation:
plain unweighted vote is the weak policy in this fallback setting. Top1 and
weighted-vote are strong controlled baselines. Confidence-gated aggregation is
only as good as the low-confidence policy: low=`vote` inherits the vote
failure, while low=`weighted-vote` preserves the weighted-vote baseline. This
is aggregation-policy calibration, not fallback robustness or learned routing
solved.

## h5-l Source/noise-aware Fallback Aggregation Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_aggregation.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_aggregation.sh
```

The h5-l smoke keeps the weak route-code source fixed and compares symbolic
fallback sources against an explicit noisy fallback negative control. Symbolic
fallback arms use weighted aggregation and source-credit policy; noisy arms
verify that a bad fallback source is detected but not solved.

Reference smoke readout:

```text
raw-key:
  vote qacc=0.401563, fallback_qacc=0.391071
  source-aware qacc=0.965625, fallback_qacc=1.000000,
  correct_vote_share=0.872579, entropy=0.646051,
  source_gap=0.355541, strength_mean=1.544219

key-shape:
  vote qacc=0.218750, fallback_qacc=0.176786
  source-aware qacc=0.964063, fallback_qacc=1.000000,
  correct_vote_share=0.852162, entropy=0.734797,
  source_gap=0.355541, strength_mean=1.544219

noisy-route-code:
  vote qacc=0.059375, fallback_recall=0.000000
  source-aware qacc=0.193750, fallback_recall=0.000000,
  source_gap=-0.140244, noisy_mean=-0.197850,
  noisy_slashed=0.972107, noisy_selected=0.000000,
  strength_mean=1.000000
```

Decision:
`h5-l` passes as source/noise-aware fallback aggregation diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

Interpretation:
weighted/source-aware aggregation is a strong integration policy for symbolic
fallback sources in this controlled setting. A noisy fallback source is still
not recoverable by aggregation, but it is assigned negative source/noisy credit
and is not strength-amplified. This confirms that good-source aggregation and
bad-source detection are separable mechanisms.

## h5-m Source/noise-aware Aggregation Scale Stability Decision

Smoke command:

```bash
./experiments/test_v05_route_source_credit_source_aware_scale.sh
```

Standard run:

```bash
./experiments/run_v05_route_source_credit_source_aware_scale.sh
```

The h5-m smoke extends h5-l over key count and seed arms. It crosses
`key_count=64/128` with `seed=1/2` and compares plain vote with source-aware
weighted aggregation for `raw-key`, `key-shape`, and `noisy-route-code`
fallback sources.

Reference smoke averages:

```text
raw-key:
  vote qacc=0.378516, fallback_qacc=0.297216
  source-aware qacc=0.925391, fallback_qacc=0.996875,
  correct_vote_share=0.860390, entropy=0.641214,
  source_gap=0.314231, strength_mean=1.439082

key-shape:
  vote qacc=0.275781, fallback_qacc=0.115804
  source-aware qacc=0.932813, fallback_qacc=1.000000,
  correct_vote_share=0.848875, entropy=0.696635,
  source_gap=0.314231, strength_mean=1.439082

noisy-route-code:
  vote qacc=0.099219, fallback_recall=0.000000
  source-aware qacc=0.320703, fallback_recall=0.000000,
  source_gap=-0.268339, noisy_mean=-0.231653,
  noisy_slashed=0.973848, strength_mean=1.000000
```

Decision:
`h5-m` passes as source/noise-aware aggregation scale stability diagnostics and
limited mitigation for symbolic fallback controls, but it does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

Interpretation:
the h5-l pattern is not a single-smoke artifact. Source-aware weighted
aggregation repeatedly improves symbolic fallback integration over broad vote
across the tested key/seed smoke arms. The noisy fallback branch remains
unresolved, but it is consistently down-signaled by negative source/noisy
credit and is not strength-amplified. The next bottleneck is bad-source
abstention/filtering or replacing the noisy candidate source, not stronger
aggregation alone.
