# discrete-local-energy

Deterministic C++17 reference code for a staged discrete local-energy research prototype.

Korean README: [README.ko.md](README.ko.md)

Current headline:

- The project is now best described as a discrete local-energy learner plus a value-bearing route-hint memory research prototype. Through v0.3, the strongest routing conclusion is that long-range information should enter as `candidate value_pos -> value byte read -> proposal hint`, not as remote-neighbor replacement.
- This is not yet learned sparse routing, long-context retrieval solved, wrong-candidate robustness solved, or a Transformer replacement claim. The current live path is a controlled fixture/research scaffold with careful diagnostics around candidate discovery, identity preservation, hint strength, confidence, fallback, and route credit.
- Latest route-hint status: h4-5t calibrated the fallback low-channel strength sweet spot, h4-5u showed short fallback TTL/persistence is neutral, h4-5v added route-credit separation instrumentation with only a tiny qacc mitigation, h4-5w is the route-credit ablation diagnostics sweep, h4-5x is the credit × fallback integration ablation, h4-5y is the credit strength/stability calibration sweep, h5-a adds a persistent route-plasticity ledger plus learn/apply warmup gates, h5-b adds source/bucket route-credit responsibility instrumentation, h5-c adds source-credit policy calibration around key-shape fallback `hi_mult=5` / `lo_mult=10`, h5-d adds noisy / learned-like source policy diagnostics across weak `joint-code-key` primary, symbolic `key-shape` fallback, and explicit `noisy-route-code` stress, h5-e adds noisy-source multi-seed / scale stability smoke, h5-f weakens the `route-code-key` identity auxiliary itself, h5-g scales that weak learned-source stress over key/seed arms, h5-h compares fallback-source dependence across `off`, `raw-key`, `key-shape`, and `noisy-route-code`, h5-i calibrates source-credit fallback policy modes, h5-j diagnoses fallback candidate-quality gaps, h5-k calibrates fallback aggregation policy, h5-l adds source/noise-aware fallback aggregation diagnostics, h5-m scales that source/noise-aware aggregation pattern over key/seed smoke arms, and h5-n adds source-credit bad-source filter / abstain diagnostics. Treat them as diagnostics / limited mitigation, not robustness solved.

Current status:

- `v0.1` implemented as `dmv01`
- `v0.2-pre` implemented as `dmv02` and treated as the locked baseline
- `v0.2-b` now includes a block-local coupled proposal path, and the default weak-coupling path clears a 5-seed regression on both `counter` and `repeating-text`
- a routing probe scaffold now exists behind `--K-jump` and `--route-source`, including `input-byte` and `joint-code` candidate sources, but it only logs O(1)-candidate diagnostics and does not yet change graph dynamics
- an experimental `--route-mode jump-neighbors` candidate-ranking slice now exists behind `joint-code`; the current conservative gate removes the fixture regression on the reference runs, and the new `gap_pass` diagnostics show that this happens because triggered nodes still fail the default anchor-gap gate. Reservoir/tick adaptive gating, confidence-aware gating, and confidence-aware acceptance were all tested as default-off slices. The acceptance slice can suppress fixture-side active jumps and recover the sentinel close to baseline under `--route-min-anchor-gap 0.0`, but it still leaves `repeating-text` effectively closed, so it is a guardrail probe rather than a routing win and the whole slice remains experimental
- a default-off `state-code` route-signal probe now exists behind `--route-source state-code` and optional `--route-refresh cycle`; candidate buckets use the current node state while the route anchor stays on learned `joint-code`. On the reference runs this slice is still no-go: `repeating-text` stays probe-equivalent, `cycle` refresh only perturbs the fixture-side guarded jump slightly, and `epoch` refresh collapses back to the baseline/no-op boundary. The route-key diagnostics confirm why: `state-code + cycle` stays almost identical to the learned anchor on all nodes and on triggered nodes (`triggered_key_anchor ~= 0.996` on repeating text and `~= 0.994` on the fixture, last-10 mean), so it is not a meaningfully new routing signal. The diagnostics helper reads every column from `routing_trigger_rate` onward; keep reading these fields as diagnostic output only, not as a routing-success claim
- a diagnostic-only candidate-source compare helper now exists behind `experiments/run_v03_input_byte_jump_compare.sh`; it compares `joint-code`, `input-byte`, and `state-code + cycle` buckets across probe, forced-open `gap0`, and confidence-accepted jump cases on `repeating-text` and the routing fixture. The reference run confirms `input-byte` is a genuinely anchor-different bucket key (`triggered_key_anchor = 0.000` on `repeating-text`, `~= 0.019` on the fixture). In `gap0`, it opens a few jumps but produces no repeat-side lift and hurts the fixture; with positive confidence gain it is structurally suppressed because same-input candidates have the same confidence. Treat it as a candidate-source probe only, not as a routing-success claim
- a diagnostic-only candidate-rejection helper now exists behind `experiments/run_v03_rejection_diagnostics.sh`; it compares `joint-code` and `input-byte` on forced-open `gap0` and confidence-accepted jump-neighbor arms across `repeating-text` and the routing fixture. The helper prints every column from `routing_trigger_rate` onward, including the appended `jump_filter_*` counters. Current readout: fixture `input-gap0` selects many inspected slots but is not neutral, while fixture `input-accept` is dominated by `jump_filter_confidence_gain_rate`; `repeating-text` still barely passes the gate. Treat it as diagnostics only, not as a routing-success claim
- a focused gate/anchor-gap diagnostics helper now exists behind `experiments/run_v03_gate_diagnostics.sh`; it compares `joint-code` and `input-byte` on `repeating-text` and the routing fixture under the default `jump-neighbors` gate, forced-open `gap0`, and the confidence-lowered `c=8.0` gate. Its summary is header-driven, so the appended anchor-gap threshold, quantile, gate-margin, and trigger-reason columns show up automatically. Current readout: `repeating-text` still has near-zero positive anchor-gap mass and no lift, while the fixture opens first under `gap0`; treat it as diagnostic-only and do not read it as a routing win
- an experimental value-bearing route-hint oracle slice now exists behind `--route-mode hint-oracle` and `--lambda-route`; it does not replace local neighbors or alter topology, and instead adds an oracle value-byte bias to proposal energy on parsed `?id=` query positions. This is the first v0.3 slice where long-range signal improves a task metric: fixture query byte accuracy rises from `0.200000` to `1.000000` at `lambda_route = 0.30`, while `repeating-text` remains unchanged because it has no oracle hints. Treat this as `oracle value-bearing route hint works on the fixture`, not as learned or sparse routing
- a follow-up parsed value-candidate route-hint slice now exists behind `--route-mode hint-parsed`; the parser gives the query a matching record value position rather than a direct value byte, and the graph reads the byte at that candidate position. It reproduces the oracle curve on the fixture (`0.20 -> 0.875000`, `0.30/0.50 -> 1.000000`) with `candidate_hit_rate = 1.000000` and mean read distance `126.750000`, while `repeating-text` remains unchanged. Treat this as parsed key/value candidate delivery, not learned routing
- an exact key-value route-hint slice now exists behind `--route-mode hint-kv-exact`; it parses `@KEY=VALUE` records and `?KEY=` queries, uses latest-record-wins lookup, and then reads the matched value position as a proposal hint. On the reference fixture it matches the parsed/oracle curve (`0.20 -> 0.875000`, `0.30/0.50 -> 1.000000`) with `kv_query_hit_rate = 1.000000`, duplicate/missing rates at `0.000000`, and mean read distance `126.750000`; `repeating-text` remains unchanged. Treat this as symbolic exact key-value routing, not learned routing
- the exact KV scale-up helper now probes distance, key count, duplicate, missing, and noisy filler cases via `experiments/run_v03_route_hint_kv_scale.sh`. With `lambda_route = 0.50`, exact lookup stays perfect and distance `64/256/1024/4096` all solve query positions; many-key and noisy fixtures keep `kv_query_hit_rate = 1.000000` but need the `--strong` profile (`lambda_route = 5.0`) to recover `fixture_query_byte_acc = 1.000000`. Treat this as exact retrieval/path validation plus a hint-strength sensitivity finding, not robust learned routing
- a hashed symbolic key candidate slice now exists behind `--route-mode hint-kv-hash`, `--K-route`, and `--route-hash-bits`. It replaces exact string lookup with hash buckets but preserves `candidate value_pos -> value byte read -> proposal hint`; high-bit buckets reproduce exact-KV behavior, while lossy buckets separate top-K recall from rank-1 hint quality (`bits4_kr4` gets recall `1.000000` but top1/query accuracy `0.500000`). `--route-hint-agg vote` now adds multi-candidate nibble voting: it solves a controlled top1-failure smoke (`0.000000 -> 1.000000`) and improves the 32-key lossy sweep (`bits4_kr4: 0.500000 -> 0.700000`, `bits6_kr4: 0.875000 -> 0.956250`). `--route-hint-agg weighted-vote --route-candidate-score value-vote` adds h4-3 scoring diagnostics; it passes a controlled repeated-value collision smoke but is neutral on the default 32-key sweep where bucket values are mostly unique. `--route-candidate-score key-shape` adds h4-4 deterministic symbolic scoring and resolves the current 32-key lossy ambiguity (`bits4_kr4_key_shape` reaches query accuracy `1.000000`), but it uses parsed key-string shape and is not learned routing. `--route-hash-source joint-code-key` adds h4-5b/h4-5c learned-code key-region diagnostics; the one-key smoke passes, but the 32-key sweep is not yet a learned routing win (`bits16_kr4_vote` query accuracy `0.462500`, recall `0.687500`). New representation diagnostics show why: `key_region_joint_decode_acc = 0.093750` and `joint_signature_collision_rate = 0.625000` on `bits16_kr4_vote`. `--route-hash-source route-code-key --route-code-aux 1` adds h4-5d/e/f/g/h/i/j/k/l/m/n/o identity-code, dynamics, corruption, confidence, aggregation-policy, low-confidence subset, low-confidence policy, fallback-source, and projected-delta diagnostics; the 32-key `bits16_kr4_vote` route-code run reaches query accuracy/recall/top1 `1.000000` with route decode `1.000000` and signature collision `0.000000`. Stress shows 32/64 clean keys solve, while 128 keys keep retrieval perfect but query accuracy drops to `0.562500`; h4-5f then shows this is strength/effective-margin limited because `lambda_route = 10.0` recovers 128-key query accuracy to `1.000000`, while cycles and route-target proposal injection do not monotonically fix it. h4-5g adds `--route-strength-mode margin` and recovers the 128-key setting with lower mean route strength (`alpha=1.0`: qacc `0.998438`, mean strength `4.871687`; `alpha=1.5`: qacc `1.000000`, mean strength `6.454238`). h4-5h adds wrong-candidate corruption diagnostics: low-confidence corrupted hints are strength-suppressed, but qacc damage reduction is modest. h4-5i adds confidence calibration: value-support confidence lowers wrong hint strength but does not improve qacc. h4-5j adds `--route-strength-confidence agreement`; scorer agreement gives positive confidence separation and lowers wrong strength, but only limited qacc mitigation. h4-5k adds `--route-hint-agg confidence-gated`: it uses confidence as an aggregation-policy selector, sending low-confidence queries to `vote` and high-confidence queries to `weighted-vote`; the smoke shows a real low/high split and limited qacc mitigation, but wrong-candidate robustness is still not solved. h4-5l adds low-confidence subset diagnostics: preserve-correct low-confidence failures keep top-K recall at `1.000000` but lose top1/value support, while remove-correct lowers recall and points to fallback/abstain. h4-5m adds `--route-lowconf-policy aggregate|none|weak-vote` plus `--route-lowconf-weak-scale`: preserve-correct shows policy leverage (`aggregate qacc = 0.854688`, `none = 0.812500`, `weak-vote = 0.848438`), while remove-correct remains candidate-availability limited (`qacc = 0.804688`, high-confidence recall `0.789062`). h4-5n adds `--route-fallback-source off|raw-key|key-shape`: symbolic key-shape fallback recovers remove-correct candidate availability (`fallback_recall = 1.000000`, `fallback_success = 1.000000`) and improves qacc (`0.804688 -> 0.839062`), but fallback-used qacc remains low (`0.237037`). h4-5o adds `--route-delta-mode target-only|projected` plus pull/push scales; projected C-version stays query-local, rewards only direct target-nibble entry, and penalizes only direct target-nibble exit. Smoke shows `projected 1.0/1.0` matches target-only, `pull=2.0` improves preserve qacc (`0.854688 -> 0.875000`) but does not improve remove-correct fallback qacc (`0.237037`). Treat h4-5m/n/o as instrumentation/actionable split, not robustness solved
- h4-5p smoke passes as fallback-strength diagnostics / limited mitigation:
  target-only key-shape fallback improves qacc `0.839062 -> 0.898437` and
  fallback_qacc `0.237037 -> 0.518518` from multiplier `1.0 -> 10.0`, while
  projected `pull=2.0` is helpful at moderate multipliers but non-monotonic.
  This keeps the finding narrow: fallback-used failures are partly
  strength-limited, but learned routing and wrong-candidate robustness are not
  solved
- h4-5q adds fallback-specific adaptive strength via
  `--route-fallback-strength-mode fixed|margin`; margin mode improves over
  fixed `mult=1.0` with much lower mean strength than fixed `mult=10.0`
  (`alpha=8.0,max=40.0`: qacc `0.873437`, fallback_qacc `0.400000`, mean
  fallback strength `25.902632`), but it does not match fixed strong and is
  still diagnostics / limited mitigation only
- h4-5r adds fallback-used channel-specific strength diagnostics via
  `--route-fallback-hi-strength-mult` and `--route-fallback-lo-strength-mult`.
  The smoke indicates the residual fallback integration bottleneck is more
  low-nibble sensitive: balanced `m=5` reaches fallback_qacc `0.466666`, while
  low-channel boost reaches `0.548148` and high-channel boost falls to
  `0.377778`. This is a narrow fallback-channel diagnostic, not fallback
  robustness solved
- h4-5s adds fallback channel-adaptive strength via
  `--route-fallback-channel-strength-mode margin` with separate high/low
  channel margin alphas and caps. It confirms the adaptive channel path is
  wired: lo-biased margin raises fallback_qacc over balanced margin
  (`0.355555 -> 0.392592`) by increasing low-channel effective strength, but
  fixed lo-boost remains stronger (`fallback_qacc = 0.525926`). Treat this as
  channel-adaptive instrumentation / lower-strength limited mitigation only
- h4-5t adds a low-nibble fallback strength grid using the existing
  fallback-channel multipliers. With `hi_mult=5`, the smoke shows a narrow
  sweet spot around `lo_mult=7.5..10` (`fallback_qacc 0.540741..0.548148`) and
  mild degradation by `lo_mult=15` (`0.533333`). This calibrates low-channel
  strength before any TTL/persistence work; it is still diagnostics / limited
  mitigation only
- h4-5u adds fallback persistence / TTL diagnostics via
  `--route-fallback-persist-cycles`. In the current smoke, TTL metrics are
  wired (`ttl=3` gives persist used rate `1.000000` and mean cycles
  `3.000000`), but qacc is neutral or slightly worse (`lo7.5: 0.540741 ->
  0.525926`, `lo10: 0.548148 -> 0.548148`). Treat this as persistence
  instrumentation, not fallback robustness solved
- h4-5v adds value-position route-credit diagnostics via
  `--route-credit-learning`. On preserve-correct corruption, credit separates
  correct and wrong candidates (`credit_gap = 1.110268`) and gives a tiny qacc
  move (`0.845312 -> 0.850000`). Treat this as route-credit separation
  instrumentation / tiny mitigation only, not wrong-candidate robustness solved
  and not learned routing solved. Next route-credit work should ablate score
  weight, reward/slash ratio, decay, clip, value-pos versus query-value edge
  credit, and credit combined with the fallback low-channel strength sweet spot
- h4-5w adds route-credit ablation diagnostics and `--route-credit-mode
  query-value`. The smoke keeps value-pos credit working, wires query-value
  edge credit (`query-value-probe` gap `0.598951`), and shows credit plus
  low-channel fallback can move the fallback subset (`fallback_qacc 0.688889 ->
  0.777778` in the smoke). Treat this as ablation instrumentation / limited
  mitigation only, not robustness solved
- h4-5x adds the credit × fallback integration factorial: true
  `--route-credit-mode off`, `value-pos`, and `query-value` crossed with
  key-shape fallback `hi_mult=5`, `lo_mult=7.5/10/15`, and preserve/remove
  corruption. Smoke shows credit separates candidates while preserve-correct
  qacc stays neutral, and remove-correct qacc moves from `0.912500` to
  `0.925000` at `lo=7.5/10`. This is integration diagnostics / limited
  mitigation only.
- h4-5y adds route-credit strength/stability calibration. The smoke keeps true
  no-credit `off` baselines and diagonal active `value-pos/query-value` cells
  over score weight, slash strength, corruption rate, and low-channel fallback
  multiplier. Off rows remain credit-neutral, active rows produce positive
  gaps, and query-value preserve rows show stronger separation (`0.750000`)
  than comparable value-pos rows (`0.290625` / `0.236364`). Remove-correct rows
  populate fallback diagnostics, but the qacc/fallback_qacc effect remains
  condition-dependent. This is calibration diagnostics / limited mitigation
  only, not wrong-candidate robustness solved.
- h5-a adds a persistent route-plasticity ledger via
  `--route-plasticity-ledger`, plus `--route-credit-learn-after-epoch` and
  `--route-credit-apply-after-epoch` warmup gates. The smoke keeps the same
  value-bearing path, verifies candidate lookup/read distance stays populated,
  and verifies `routing_trigger_rate` / `active_jump_rate` stay `0.000000`.
  Treat this as route-plasticity instrumentation only, not learned routing
  solved and not wrong-candidate robustness solved.
- h5-b adds source/bucket-level route credit via
  `--route-source-credit-learning`. The smoke keeps the value-bearing path
  active and jump-neighbor replacement inactive, then separates remove-correct
  responsibility: source-on remove-correct has source credit size `73`,
  fallback mean `0.300000`, primary mean `0.023438`, source gap `0.276563`,
  primary slashed rate `0.281250`, and fallback rewarded rate `1.000000`.
  qacc is neutral in the smoke, so this is source/bucket responsibility
  instrumentation, not fallback robustness or learned routing solved.
- h5-c adds source-credit policy calibration on remove-correct corruption
  `0.25` with key-shape fallback `hi_mult=5` / `lo_mult=10`. The smoke keeps
  the value-bearing path active, but source-only rows stay qacc-neutral while
  they learn a source gap (`0.276563` without apply, `0.553125` with stronger
  source weighting) and the ledger row only changes persistent state (`ledger
  size 0 -> 59`, `mean_abs_credit = 0.711864`) while qacc stays `0.931250` on
  the ledger rows. This is policy instrumentation, not robustness solved.
- h5-d adds noisy / learned-like source policy diagnostics on remove-correct
  corruption `0.25`. The smoke has two controlled branches: weak
  `joint-code-key` primary with `key-shape` fallback, and explicit
  `noisy-route-code` fallback/source stress with `--route-noisy-source-rate
  1.0`. It keeps `route_hint_candidate_lookup_count` and
  `route_hint_value_read_distance_mean` populated, leaves
  `routing_trigger_rate` / `active_jump_rate` at `0.000000`, gives positive
  source gap for useful key-shape fallback, and gives negative noisy-source
  credit/slash diagnostics for bad noisy candidates. This is source-quality
  separation instrumentation, not robustness solved.
- h5-e adds noisy-source multi-seed / scale stability diagnostics. The smoke
  crosses key counts `32/64`, seeds `1/2`, and noisy rates `0.50/1.00`.
  The weak joint branch keeps positive key-shape fallback source gaps across
  the smoke, while the noisy branch keeps negative noisy-candidate credit and
  nonzero noisy slash diagnostics. Fully noisy rows also get negative source
  gap. This is stability instrumentation, not source-credit robustness solved.
- h5-f adds weaker learned-source stress diagnostics for `route-code-key` via
  `--route-code-key-region-keep-prob` and `--route-code-aux-noise-rate`. The
  smoke crosses key counts `32/64` and seeds `1/2`, comparing clean full
  identity supervision to a weak route-code branch (`keep=0.25`,
  `aux_noise=0.75`). Clean rows keep decode/primary recall/qacc at
  `1.000000`, while weak rows drop route-code decode and primary recall,
  trigger key-shape fallback, and produce positive source-credit gap plus
  primary slash / fallback reward signals. This is weaker learned-source
  instrumentation, not learned routing solved.
- h5-g adds weak learned-source multi-seed / scale stability diagnostics. The
  smoke crosses key counts `64/128`, seeds `1/2`, and clean/mid/weak route-code
  weakening arms, then compares weak fallback-off against weak key-shape
  fallback with source-credit `ranking-strength` plus ledger. Mean smoke
  readout: clean-off keeps qacc/decode/recall `1.000000`; mid-off reaches
  qacc `0.970313`, decode `0.630937`, recall `0.994531`; weak-off drops to
  qacc `0.185938`, decode `0.000000`, recall `0.285938`; weak fallback-ledger
  improves qacc to `0.460156` while fallback_used reaches `0.714063` and
  source gap / slash / reward are populated. This is scale/stability
  instrumentation, not source-credit robustness solved.
- h5-h adds fallback-source dependence / stability diagnostics. The smoke keeps
  the weak route-code source fixed and compares fallback `off`, exact symbolic
  `raw-key`, symbolic `key-shape` with source-credit `ranking-strength`, and
  bad `noisy-route-code`. Mean smoke readout: fallback-off qacc `0.213281`;
  raw-key qacc `0.650000`, fallback_recall `1.000000`; key-shape qacc
  `0.437500`, source_gap `0.299223`; noisy-route-code qacc `0.173437`,
  source_gap `-0.207562`, noisy_mean `-0.201440`, noisy_slash `0.979234`.
  This separates symbolic fallback dependence from bad-source diagnostics; it
  is not learned routing solved.
- h5-i adds source-credit fallback-policy calibration diagnostics. The smoke
  keeps the weak route-code source fixed, then separates `key-shape`
  learn-only, ranking, strength, and ranking-strength apply modes against
  `raw-key` symbolic ceiling and `noisy-route-code` negative control. Mean
  smoke readout: off-control qacc `0.206250`; raw-key qacc `0.661328`,
  fallback_recall `1.000000`; key-shape source_gap `0.299047`, selected
  fallback `0.660209` under ranking, strength mean `1.402324` under strength;
  noisy-route-code source_gap `-0.182191`, noisy_mean `-0.189995`, noisy_slash
  `0.976094`, fallback_recall `0.000000`. This is policy calibration
  instrumentation, not fallback robustness or learned routing solved.
- h5-j adds fallback candidate-quality gap diagnostics. The smoke compares
  `raw-key` and `key-shape` fallbacks under `vote`, `weighted-vote`, and
  source-credit `ranking-strength`. Both fallback sources recover candidates,
  but top1 remains low (`0.031250`, mean rank `2.500000`). Plain vote stays
  weak (`raw` qacc `0.225000`, `key-shape` qacc `0.200000`), while
  weighted-vote raises correct value support and lowers entropy, nearly solving
  both (`raw` qacc `0.942188`, `key-shape` qacc `0.960938`). This says the
  exposed bottleneck is fallback aggregation quality, not fallback recall
  alone.
- h5-k adds fallback aggregation policy calibration. The smoke compares
  `top1`, `vote`, `weighted-vote`, and confidence-gated policies for `raw-key`
  and `key-shape` fallback. Plain vote is the weak policy (`raw` qacc
  `0.328125`, `key-shape` qacc `0.204688`), while top1 and weighted-vote are
  strong in this controlled fallback setting (`top1` qacc `0.906250` for both;
  weighted qacc `0.943750` / `0.956250`). Confidence-gated
  low=`vote`, high=`weighted-vote` inherits the vote weakness, while
  low=`weighted-vote`, high=`weighted-vote` preserves the weighted baseline.
- h5-l adds source/noise-aware fallback aggregation diagnostics. The smoke
  applies weighted aggregation plus source-credit policy to symbolic fallback
  sources and keeps the noisy fallback as a negative control. Raw-key improves
  from vote qacc `0.401563` to source-aware qacc `0.965625`; key-shape improves
  from `0.218750` to `0.964063`. The noisy fallback remains unsolved
  (`fallback_recall=0.000000`) but is detected by negative source/noisy credit
  (`source_gap=-0.140244`, noisy slash `0.972107`) and receives no strength
  amplification (`strength_mean=1.000000`).
- h5-m adds source/noise-aware aggregation scale stability diagnostics. The
  smoke crosses key count `64/128` with seeds `1/2` and compares vote versus
  source-aware weighted aggregation for `raw-key`, `key-shape`, and
  `noisy-route-code` fallback sources. Averaged over the smoke, raw-key improves
  from qacc `0.378516` to `0.925391`, and key-shape improves from `0.275781` to
  `0.932813`; both keep `fallback_recall=1.000000`. The noisy branch remains
  unresolved (`fallback_recall=0.000000`) while keeping negative source/noisy
  credit (`source_gap=-0.268339`, noisy slash `0.973848`) and no strength
  amplification (`strength_mean=1.000000`).
- h5-n adds bad-source filtering / abstain diagnostics. New
  `--route-source-filter-mode negative-credit` drops candidates whose source
  credit is below `--route-source-filter-threshold`. In the smoke, symbolic
  fallbacks stay usable (`raw-filter` qacc `0.951562`, `keyshape-filter` qacc
  `0.965625`), while noisy fallback candidates are heavily filtered
  (`source_filter_filtered=0.929220`, `source_filter_abstain=0.846875`).
  Noisy qacc does not improve (`0.187500 -> 0.125000`), so this is bad-source
  abstention instrumentation, not fallback robustness solved.

## Build

```bash
cmake -S . -B build
cmake --build build -j
```

## Run

`v0.1` logs CSV to stdout by default:

```bash
./build/dmv01 --cycles 100 --N 256 > results/v01_smoke.csv
```

Or write directly to a file:

```bash
./build/dmv01 --cycles 100 --N 256 --csv results/v01_smoke.csv
```

The implemented `v0.1` reference includes:

- bounded-degree ring graph
- color-based block-asynchronous updates
- fixed synthetic per-node `h_table`
- local energy proposals with inertia
- tick gating
- stagnation-triggered Metropolis escape
- reservoir redistribution
- per-cycle CSV diagnostics

`v0.2-pre` supports:

- byte-level next-byte prediction on `counter`, `repeating-text`, or `--input` bytes
- two-channel nibble state initialized from input bytes
- shared field table `H[channel][input_byte][state]`
- local contrastive positive/negative updates
- diagnostics including `field_byte_acc`, `oracle1_acc`, and `field_margin`
- defaults tuned for the first correctness gate: `lambda_v = 0`, `mass_init = 0`

Baseline interpretation:

- `counter` with `lambda_v = 0` is the first locked correctness gate and should succeed strongly.
- Higher `lambda_v` values are expected to hurt `counter`; if they do, that confirms the stage default still needs tuning.
- `repeating-text` should show `field_byte_acc` below `oracle1_acc` but clearly above `byte_acc` during early and mid learning.
- For `v0.2-b`, the default weak-coupling run now lands around `field/joint/byte = 0.687500/0.687500/0.687500` on repeating text and keeps the `counter` gate at `1.000000/1.000000/1.000000`.
- The 5-seed default weak-coupling regression now averages `counter byte/field/joint = 0.999688/1.000000/1.000000` and `repeating-text byte/field/joint = 0.685625/0.681094/0.685703`.
- On the same 5-seed repeating-text regression, default weak coupling lifts `byte_acc` by `+0.177578` on average over the default no-coupling control.
- The tuned `proposal_count = 30` control is still useful when we want to isolate proposal coverage from coupling benefit. In that control setting, no coupling ends around `0.597656/0.597656/0.597656`, while weak coupling ends around `0.687500/0.687500/0.687500`.

Example:

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --lambda-v 0 \
  --csv results/counter_lv0.csv
```

Experiment helpers:

- `experiments/run_v02_counter.sh`
- `experiments/run_v02_ablation.sh`
- `experiments/run_v02_repeating.sh`
- `experiments/run_v02b_tuned.sh`
- `experiments/run_v02b_counter_compare.sh`
- `experiments/run_v02b_repeating_compare.sh`
- `experiments/run_v02b_counter_multiseed_compare.sh`
- `experiments/run_v02b_repeating_multiseed_compare.sh`
- `experiments/run_v03_routing_probe.sh`
- `experiments/run_v03_routing_fixture_compare.sh`
- `experiments/run_v03_state_code_compare.sh`
- `experiments/run_v03_static_routing_compare.sh`
- `experiments/run_v03_gap_gate_ablation.sh`
- `experiments/run_v03_gate_diagnostics.sh`
- `experiments/run_v03_adaptive_gate_ablation.sh`
- `experiments/run_v03_confidence_gate_ablation.sh`
- `experiments/run_v03_confidence_acceptance_ablation.sh`
- `experiments/summarize_v03_routing_slice.sh`
- `experiments/run_v03_input_byte_jump_compare.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `experiments/run_v03_rejection_diagnostics.sh`
- `experiments/run_v03_route_hint_oracle.sh`
- `experiments/run_v03_route_hint_parsed.sh`
- `experiments/run_v03_route_hint_kv_exact.sh`
- `experiments/run_v03_route_hint_kv_hash.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_stress.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/run_v05_route_credit_plasticity.sh`
- `experiments/run_v05_route_source_credit.sh`
- `experiments/run_v05_route_source_credit_policy.sh`
- `experiments/run_v05_route_source_credit_noisy_source.sh`
- `experiments/run_v05_route_source_credit_noisy_scale.sh`
- `experiments/run_v05_route_source_credit_learned_source_stress.sh`
- `experiments/run_v05_route_source_credit_learned_source_scale.sh`
- `experiments/run_v05_route_source_credit_fallback_ablation.sh`
- `experiments/run_v05_route_source_credit_fallback_policy.sh`
- `experiments/run_v05_route_source_credit_fallback_quality.sh`
- `experiments/run_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/run_v05_route_source_credit_source_aware_scale.sh`
- `experiments/run_v05_route_source_credit_bad_source_filter.sh`
- `experiments/test_v03_route_hint_oracle.sh`
- `experiments/test_v03_route_hint_parsed.sh`
- `experiments/test_v03_route_hint_kv_exact.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_dynamics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_corruption.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_confidence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_persistence.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_route_credit.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_credit_calibration.sh`
- `experiments/test_v05_route_credit_plasticity.sh`
- `experiments/test_v05_route_source_credit.sh`
- `experiments/test_v05_route_source_credit_policy.sh`
- `experiments/test_v05_route_source_credit_noisy_source.sh`
- `experiments/test_v05_route_source_credit_noisy_scale.sh`
- `experiments/test_v05_route_source_credit_learned_source_stress.sh`
- `experiments/test_v05_route_source_credit_learned_source_scale.sh`
- `experiments/test_v05_route_source_credit_fallback_ablation.sh`
- `experiments/test_v05_route_source_credit_fallback_policy.sh`
- `experiments/test_v05_route_source_credit_fallback_quality.sh`
- `experiments/test_v05_route_source_credit_fallback_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_aggregation.sh`
- `experiments/test_v05_route_source_credit_source_aware_scale.sh`
- `experiments/test_v05_route_source_credit_bad_source_filter.sh`

Key docs:

- [Master Prompt](DISCRETE_MANIFOLD_MASTER_CODEX_PROMPT.md)
- [Architecture Plan](docs/DISCRETE_MANIFOLD_ARCHITECTURE_PLAN_A_TO_Z.md)
- [v0.1 Design](docs/DESIGN_V01.md)
- [v0.2-pre Design](docs/DESIGN_V02_PRE.md)
- [v0.2-b Results](docs/V02B_RESULTS.md)
- [v0.2-b Decision Boundary](docs/V02B_DECISION_BOUNDARY.md)
- [v0.2-b 5-Seed Protocol](docs/V02B_MULTI_SEED_PROTOCOL.md)
- [v0.3 Routing Probe](docs/V03_ROUTING_PROBE.md)
- [v0.3 Static Routing Slice](docs/V03_STATIC_ROUTING.md)
- [v0.3 Route-Hint Oracle](docs/V03_ROUTE_HINT_ORACLE.md)
- [Roadmap](docs/ROADMAP.md)
