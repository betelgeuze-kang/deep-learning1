# v0.3 Static Routing Slice

This note tracks the first `jump-neighbors` candidate-ranking slice.

It is still experimental and stays below the promotion bar.

The current conservative gate removes the fixture regression on the reference
runs, but it also flattens `jump-neighbors` back to probe-equivalent behavior.
We have now tried scored top-K tables based on both route-anchor closeness and
target-free joint-code confidence, and neither ranking revives active usage
under the present gate.

The new gate diagnostics now make the bottleneck explicit: the default
`route-min-anchor-gap` follows `lambda_u`, and on the reference runs the
triggered nodes never clear that gate.

Current scope:

- keep `v0.2-b` as the shipped default path
- keep `probe` mode as the passive routing diagnostics path
- keep `--route-mode jump-neighbors` default-off; the original active path uses `joint-code`, while `input-byte` and `state-code` remain diagnostic candidate-source controls; jump-neighbor replacement stays no-go/default-off/diagnostic-only
- keep total degree bounded by reusing the existing `K` slots

Current helper:

- `experiments/run_v03_static_routing_compare.sh`
- `experiments/summarize_v03_routing_slice.sh`
- `experiments/run_v03_gap_gate_ablation.sh`
- `experiments/run_v03_adaptive_gate_ablation.sh`
- `experiments/run_v03_confidence_gate_ablation.sh`
- `experiments/run_v03_confidence_acceptance_ablation.sh`
- `experiments/run_v03_gate_diagnostics.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `experiments/run_v03_input_byte_jump_compare.sh`
- `experiments/run_v03_rejection_diagnostics.sh`
- `experiments/run_v03_route_hint_oracle.sh`
- `experiments/run_v03_route_hint_parsed.sh`
- `experiments/run_v03_route_hint_kv_exact.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/test_v03_route_hint_oracle.sh`
- `experiments/test_v03_route_hint_parsed.sh`
- `experiments/test_v03_route_hint_kv_exact.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_agreement.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_gated_agg.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_lowconf_policy.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_source.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_projected_delta.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_strength.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh`
- `experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh`
- `experiments/test_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh`

The h4-5n/o/p/q route-hint diagnostics stay ancillary to this static-routing
slice. In particular, h4-5p only scales fallback-used queries via
`--route-fallback-strength-mult` and should be read as a bottleneck probe, not
as a new routing mechanism. The smoke does show limited mitigation for the
value-bearing route-hint path (`fallback_qacc 0.237037 -> 0.518518` under
target-only key-shape fallback at multiplier `10.0`), but this remains
query-local hint integration and does not revive jump-neighbor replacement.
h4-5q adds fallback-specific margin strength and lowers the mean fallback
strength needed for limited mitigation, but it remains query-local and
diagnostic; it still does not promote jump-neighbor replacement.
h5-q source-credit retry-policy tie-break diagnostics are also ancillary to
this static-routing slice; they keep the same `candidate value_pos -> value
byte read -> proposal hint` path while choosing retry sources, but they do
not promote jump-neighbor replacement.
h5-r source-prior retry schedule diagnostics remain in the same category: they
scale or warm up retry-source priors for source-credit tie-breaks while
preserving `candidate value_pos -> value byte read -> proposal hint`, but they
still do not promote jump-neighbor replacement.
h5-s source-prior handoff diagnostics stay ancillary in the same way: they
compare static, warmup, and decay source priors for retry-source selection
while keeping the value-bearing retry path and still do not promote
jump-neighbor replacement.
h5-t retry-source evidence-quality diagnostics stay ancillary in the same way:
they expose retry-source credit means and reward/slash rates while preserving
the value-bearing retry path, but they still do not promote jump-neighbor
replacement.
h5-u candidate-quality logdet/channel/quality-score instrumentation stays
outside this slice as well: it adds metric-only readouts on value-bearing
route-hint candidates, not jump-neighbor promotion.
h5-v weak quality source-ranking application stays outside this slice as well:
it starts with `route_quality_apply=source-ranking`, stays soft with no hard
threshold/filter while keeping `candidate value_pos -> value byte read ->
proposal hint`, and still does not promote jump-neighbor replacement. The
reference smoke is neutral-to-slight-regression, so it is calibration
instrumentation rather than a routing win.
h5-w source-quality calibration diagnostics stay in the same category: they
split the h5-v source-ranking proxy/delta/qacc by retry source while preserving
the value-bearing route path and still do not promote jump-neighbor
replacement.
h5-x proxy weight/sign calibration stays in the same category: it reweights or
sign-flips the same source-quality proxy terms while preserving the
value-bearing route path and still does not promote jump-neighbor replacement.
h5-y channel-sign scale diagnostics also stay in the same category: they test
that calibrated source-quality proxy over several key/seed cells, but still
only affect value-bearing source ranking and never revive topology replacement.
h5-z source-normalization diagnostics remain there too: they rescale the same
source-quality proxy before soft source ranking and leave graph topology,
candidate collection, and route strength unchanged.
h5-aa candidate-level quality diagnostics remain there as well: they only
measure correct/wrong candidate weight separation and best-candidate
correctness inside the existing value-bearing route-hint path.
h5-ab weak candidate-level quality application remains there too: it only
sharpens candidate weights inside value-bearing aggregation and does not change
graph topology, route strength, or jump-neighbor gating.
h5-ac candidate-weight composition diagnostics remain there as well: the
combined source/candidate quality mode changes only value-bearing source and
candidate weights, not static topology.
h5-ad candidate-only beta/noise scale diagnostics remain there as well:
candidate quality still only sharpens value-bearing aggregation weights, with
route strength, graph topology, and jump-neighbor gates unchanged.
h5-ae candidate-weight saturation/cap diagnostics remain there as well: they
calibrate bounded candidate-weight sharpening and concentration metrics inside
value-bearing aggregation only, with no topology or jump-neighbor changes.
h5-af candidate-quality regression diagnostics remain there as well: they
promote the best bounded candidate-weight setting into a broader key/seed/noise
regression sweep while keeping route strength, graph topology, and
jump-neighbor gates unchanged.
h5-ag candidate-quality over-sharpen boundary diagnostics remain there as well:
they increase only bounded candidate-weight beta/cap inside value-bearing
aggregation and keep route strength, graph topology, and jump-neighbor gates
unchanged.
h5-ah high-beta candidate-quality boundary diagnostics remain there as well:
they continue the bounded candidate-weight beta/cap sweep without changing
route strength, graph topology, or jump-neighbor gates.
h5-ai extreme-beta candidate-quality boundary diagnostics remain there as well:
they push only bounded candidate-weight beta/cap higher while keeping route
strength, graph topology, and jump-neighbor gates unchanged.
h5-aj ultra-beta candidate-quality plateau/boundary diagnostics remain there as
well: they continue only bounded candidate-weight beta/cap calibration and keep
route strength, graph topology, and jump-neighbor gates unchanged.
h5-ak candidate-quality guardrail selection diagnostics remain there as well:
they compare bounded candidate-weight settings over key/seed/noise guardrails
without changing route strength, graph topology, or jump-neighbor gates.
h5-al candidate-quality safe-default application diagnostics remain there as
well: they select candidate-weight-only `beta=8, cap=8` as the current safe
quality default and do not promote source-ranking composition, route strength,
graph topology, or jump-neighbor gates.
h5-am candidate-feature basis calibration diagnostics remain there as well:
they compare `candidate-weight-basis=base` against `quality-score` bases, keep
the base default, and do not promote source-ranking, route strength, graph
topology, or jump-neighbor gates.
h5-an/h5-ao/h5-ap hybrid candidate-basis diagnostics remain there as well:
they compare `base` and `hybrid` candidate-weight bases, keep `base` as the
default, and do not promote source-ranking, route strength, graph topology, or
jump-neighbor gates.
h5-aq concentration-aware candidate-basis switching remains there as well:
`basis=auto` switches only the candidate-weight basis between base and
`hybrid-m0p25` under concentration thresholds, with no route-strength,
topology, or jump-neighbor changes.
h5-ar auto-threshold calibration remains there as well: it only changes the
thresholds used by `basis=auto` and keeps the same value-bearing aggregation
path, with no route-strength, topology, or jump-neighbor changes.
h5-as auto-trigger decomposition remains there as well: it only explains
whether `basis=auto` switched because of candidate-weight factor concentration
or top-share concentration. It adds metrics, not behavior, and keeps the same
value-bearing aggregation path with no route-strength, topology, or
jump-neighbor changes.
h5-at auto-trigger policy ablation remains there as well: it restricts the
`basis=auto` switch to `any`, `factor`, or `top-share` trigger modes, still
only changing candidate-weight basis selection with no route-strength,
topology, or jump-neighbor changes.
h5-au factor-trigger threshold refinement remains there as well: it sweeps the
factor-only auto threshold and still only changes candidate-weight basis
selection with no route-strength, topology, or jump-neighbor changes.
h5-av through h5-bc also remain on this non-topological path: they summarize,
guard, preset, regression-test, and directly compare the `base-default` and
`hybrid-safe` candidate-weight presets, then wrap those checks in a closure
smoke. These slices only change or test candidate weighting inside
value-bearing aggregation. They do not create remote neighbors, route triggers,
active jumps, or any jump-neighbor promotion.
h4-5v/w route-credit diagnostics also stay ancillary to this static-routing
slice; they are value-bearing route-hint memory diagnostics, not jump-neighbor
promotion.

State-code route-signal probe:

- `experiments/run_v03_state_code_compare.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `state-code` uses the node's current `(high, low)` state as the candidate bucket key
- to avoid the zero-gap degeneracy, the route anchor and gate stay tied to the learned target-free `joint-code` cache rather than the current `state-code`
- the route-key diagnostics helper now compares `joint-code` probe, `state-code` probe with `--route-refresh cycle`, `joint-code` guarded jump, `state-code` guarded jump with `--route-refresh cycle`, and `state-code` guarded jump with default `epoch` refresh; it is diagnostic-only and does not claim a routing win
- the helper prints the final row and last-10 means for `byte/field/joint` plus every column from `routing_trigger_rate` onward, so any triggered-only route-key diagnostics columns already present in the CSV schema are surfaced automatically

The confidence-aware acceptance probe keeps the same `jump-neighbors` /
`joint-code` path but applies `--route-accept-confidence-gain` after the
existing node gate and candidate anchor-gap filter. It stays default-off and
is only evaluated with `--route-min-anchor-gap 0.0` so the acceptance slice is
observable.

Current readout, final row, seed `1`, `80` epochs:

| Run | byte_acc | field_byte_acc | joint_byte_acc | active_jump_rate | mean_active_jump_neighbors | mean_jump_distance |
| --- | --- | --- | --- | --- | --- | --- |
| `v03_static_repeat_off.csv` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `0.000000` | `0.000000` |
| `v03_static_repeat_probe.csv` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `0.000000` | `0.000000` |
| `v03_static_repeat_jump.csv` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `0.000000` | `0.000000` |
| `v03_static_fixture_off.csv` | `0.242188` | `0.210938` | `0.253906` | `0.000000` | `0.000000` | `0.000000` |
| `v03_static_fixture_probe.csv` | `0.242188` | `0.210938` | `0.253906` | `0.000000` | `0.000000` | `0.000000` |
| `v03_static_fixture_jump.csv` | `0.242188` | `0.210938` | `0.253906` | `0.000000` | `0.000000` | `0.000000` |

Current readout, last-10 mean, from `summarize_v03_routing_slice.sh`:

| Run | byte_acc | field_byte_acc | joint_byte_acc | active_jump_rate | mean_active_jump_neighbors | mean_jump_distance |
| --- | --- | --- | --- | --- | --- | --- |
| `repeat-off` | `0.684766` | `0.684375` | `0.684766` | `0.000000` | `0.000000` | `0.000000` |
| `repeat-probe` | `0.684766` | `0.684375` | `0.684766` | `0.000000` | `0.000000` | `0.000000` |
| `repeat-jump` | `0.684766` | `0.684375` | `0.684766` | `0.000000` | `0.000000` | `0.000000` |
| `fixture-off` | `0.200000` | `0.167969` | `0.205469` | `0.000000` | `0.000000` | `0.000000` |
| `fixture-probe` | `0.200000` | `0.167969` | `0.205469` | `0.000000` | `0.000000` | `0.000000` |
| `fixture-jump` | `0.200000` | `0.167969` | `0.205469` | `0.000000` | `0.000000` | `0.000000` |

Current gate diagnostics:

- final row, `repeat-probe/jump`: `trig=1.000000`, `gap_pass=0.000000`, `gap_mean=0.000000`, `gap_max=0.000000`, `gate=1.000000`, `stress=0.096579`
- final row, `fixture-probe/jump`: `trig=0.996094`, `gap_pass=0.000000`, `gap_mean=0.000785`, `gap_max=0.064839`, `gate=1.000000`, `stress=0.087036`
- last-10 mean, `repeat-probe/jump`: `trig=1.000000`, `gap_pass=0.000000`, `gap_mean=0.000058`, `gap_max=0.008369`, `gate=1.000000`, `stress=0.094978`
- last-10 mean, `fixture-probe/jump`: `trig=0.992969`, `gap_pass=0.000000`, `gap_mean=0.000690`, `gap_max=0.040831`, `gate=1.000000`, `stress=0.076324`
- confidence also separates the datasets in the right direction: last-10 mean `repeat-probe/jump` has `conf=0.381079`, `conf_max=0.805028`, while `fixture-probe/jump` has `conf=0.163383`, `conf_max=0.422761`

Short gate ablation with `--route-min-anchor-gap 0.0`:

- `repeating-text` stays effectively closed: final `gap_pass=0.000000`, `active=0.000000`; last-10 `gap_pass=0.001562`, `active=0.001172`
- `fixture` partially opens and regresses: final `byte/field/joint = 0.218750/0.152344/0.203125`, `gap_pass=0.070866`, `active=0.023438`; last-10 `byte/field/joint = 0.198828/0.162109/0.199219`, `gap_pass=0.052674`, `active=0.030860`

Adaptive gate ablation with `--route-adaptive-gap-scale` and base gate left at `lambda_u`:

- tested scales: `0`, `10`, `11`, `12`, `13`
- no safe opening window appears in the tested range
- `repeating-text` remains effectively closed throughout: final `active=0.000000` for all tested scales; last-10 only reaches `active=0.000391` at scales `12` and `13`, with no accuracy lift
- `fixture` opens earlier and regresses as the adaptive gate lowers

Selected adaptive results, final row:

| Run | byte_acc | field_byte_acc | joint_byte_acc | gap_pass | gate | stress | active_jump_rate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `repeat-s0` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `1.000000` | `0.096579` | `0.000000` |
| `repeat-s13` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `0.033272` | `0.096579` | `0.000000` |
| `fixture-s0` | `0.242188` | `0.210938` | `0.253906` | `0.000000` | `1.000000` | `0.087036` | `0.000000` |
| `fixture-s10` | `0.238281` | `0.175781` | `0.257812` | `0.031250` | `0.167685` | `0.091823` | `0.019531` |
| `fixture-s11` | `0.234375` | `0.144531` | `0.230469` | `0.023438` | `0.248046` | `0.069771` | `0.015625` |
| `fixture-s12` | `0.234375` | `0.144531` | `0.230469` | `0.023438` | `0.201505` | `0.069769` | `0.015625` |
| `fixture-s13` | `0.230469` | `0.191406` | `0.234375` | `0.039216` | `0.068240` | `0.089555` | `0.019531` |

Confidence-aware gate probe with `--route-confidence-gap-scale`:

- this family uses the already-measured `route_confidence_margin` to lower the gate on high-confidence triggered nodes
- the direction is promising as a diagnostic signal, because `repeating-text` has higher triggered confidence than the fixture
- but the gate family still fails as a routing slice

Focused confidence results:

- `c=3.0` still leaves both datasets closed: last-10 `repeat-c3` stays at `active=0.000000`, `gap_pass=0.000000`, `gate=0.182103`; last-10 `fixture-c3` stays at `active=0.000000`, `gap_pass=0.000000`, `gate=0.575290`
- `c=8.0` is enough to push the gate down hard on `repeating-text`, but it still does not open: last-10 `repeat-c8` stays at `active=0.000000`, `gap_pass=0.000000`, `gate=0.036995`
- by that point the fixture is already degrading: last-10 `fixture-c8` falls to `byte/field/joint = 0.194922/0.169531/0.196875`, with `active=0.000391` and `gap_pass=0.000398`

Confidence-aware acceptance probe with `--route-accept-confidence-gain` and
`--route-min-anchor-gap 0.0`:

- tested gains: `0`, `0.05`, `0.10`, `0.20`
- `repeating-text` stays effectively closed for all tested gains: last-10 `byte/field/joint` remains `0.684896/0.684462/0.684896`, and `active_jump_rate` moves from only `0.001302` at gain `0` down to `0.000000` for gains `0.05+`
- `fixture` does respond to the acceptance gain, but in a conservative direction: last-10 `active_jump_rate` falls from `0.029080` at gain `0` to `0.017361` at `0.05`, `0.015625` at `0.10`, and `0.006510` at `0.20`
- the strongest tested gain mostly recovers the fixture sentinel instead of opening `repeating-text`: last-10 `fixture-a0p20` reaches `byte/field/joint = 0.204861/0.168837/0.208767`, close to the current `fixture-off` baseline `0.198351/0.171007/0.203559`
- final-row `repeating-text` is exactly unchanged for every tested gain at `0.687500/0.687500/0.687500`, while final-row `fixture` remains volatile: `a0=0.218750/0.152344/0.203125`, `a0p05=0.246094/0.195312/0.253906`, `a0p10=0.246094/0.195312/0.253906`, `a0p20=0.183594/0.148438/0.199219`

Gate / anchor-gap diagnostics:

- `experiments/run_v03_gate_diagnostics.sh`
- compares `joint-code` and `input-byte` on `repeating-text` and the routing fixture under the default `jump-neighbors` gate, forced-open `gap0`, and the confidence-lowered `c=8.0` gate
- the helper prints the final row and last-10 means for `byte/field/joint` plus every column from `routing_trigger_rate` onward, so the current anchor-gap threshold, quantile, gate-margin, state-anchor hamming, and trigger-reason diagnostics surface automatically when present
- use it to inspect the gate and anchor-gap distribution only; do not treat it as a routing win

Reference gate readout, seed `1`, last-10:

- all `12` helper outputs have `80` data rows and `71` CSV columns
- default-gate `repeating-text` remains closed: `active = 0.000000`, `gap_pass = 0.000000`, `gt0 = 0.001562`, `p90_gap = 0.000000`, `p99_gap = 0.000000`, `mean_gate_margin = -0.999942`
- forced-open `repeating-text gap0` still has no prediction lift: `byte/field/joint = 0.684766/0.684375/0.684766`, `active = 0.001172`, `gap_pass = 0.001562`, `equal_gate = 0.998438`
- default-gate fixture is also closed but has a larger positive tail: `gt0 = 0.050850`, `p99_gap = 0.018800`, `mean_gate_margin = -0.999310`
- forced-open fixture moves first and is not neutral: `joint-gap0 active = 0.030860`, `gap_pass = 0.052674`, `p99_gap = 0.034741`; `input-gap0 active = 0.022656`, `gap_pass = 0.042190`, `p99_gap = 0.016135`
- confidence-lowered `c=8.0` still leaves `repeating-text` closed (`active = 0.000000`, `gap_pass = 0.000000`) while the fixture starts to move slightly (`active = 0.000391`, `gap_pass = 0.000398`)
- trigger reasons overlap heavily: on `repeating-text`, last-10 `reservoir/stagnation/both = 0.970703/0.984375/0.955078`; on fixture default, `0.890217/0.841325/0.731542`

Value-bearing route-hint oracle:

- `docs/V03_ROUTE_HINT_ORACLE.md`
- `experiments/run_v03_route_hint_oracle.sh`
- `experiments/test_v03_route_hint_oracle.sh`
- `data/route_hint_oracle_fixture.txt`
- `--route-mode hint-oracle` keeps the local `K=8` topology intact and does not use jump-neighbor replacement
- oracle hints are parsed from `@id=value` records and `?id=` query positions; the query node is the `=` byte, and the hint value is the byte after the matching record `=`
- `--lambda-route` adds a value-bearing proposal-energy bias toward the hint byte's high/low nibbles
- status: `PASS` for the first oracle fixture test
- this is still oracle-only; do not present it as learned key/value routing or sparse routing solved

Reference route-hint readout, seed `1`, last-10:

- `fixture-off`: `query_count = 4.000000`, `applied = 0.000000`, `query_byte_acc = 0.200000`, `query_field_acc = 0.150000`, `query_joint_acc = 0.175000`
- `fixture-lr0p01`: `applied = 1.000000`, `query_byte_acc = 0.150000`
- `fixture-lr0p03`: `applied = 1.000000`, `query_byte_acc = 0.250000`
- `fixture-lr0p10`: `applied = 1.000000`, `query_byte_acc = 0.300000`
- `fixture-lr0p20`: `applied = 1.000000`, `query_byte_acc = 0.875000`
- `fixture-lr0p30`: `applied = 1.000000`, `query_byte_acc = 1.000000`, `route_hint_value_match_rate = 1.000000`
- `fixture-lr0p50`: `applied = 1.000000`, `query_byte_acc = 1.000000`
- `repeating-text` is unchanged for all tested strengths: `byte/field/joint = 0.687500/0.683594/0.687500`, `query_count = 0.000000`
- read this as a semantic-routing milestone: value-bearing nonlocal information can improve query positions without replacing neighbors; the next risk is learning/discovering the hints, not another gate threshold
- parsed value-candidate mode (`--route-mode hint-parsed`) reproduces the same curve while reading the value from the matched record position: `candidate_hit_rate = 1.000000`, `value_read_distance_mean = 126.750000`, and `query_byte_acc = 1.000000` at `lambda_route = 0.30/0.50`
- exact key-value mode (`--route-mode hint-kv-exact`) also reproduces the curve with `kv_query_hit_rate = 1.000000`, `kv_duplicate_key_rate = 0.000000`, `kv_missing_key_rate = 0.000000`, and `query_byte_acc = 1.000000` at `lambda_route = 0.30/0.50`
- exact KV scale-up keeps `kv_query_hit_rate = 1.000000` through distance `4096` and solves those query positions at `lambda_route = 0.50`; many-key/noisy cases still hit exact candidates but require the stronger `lambda_route = 5.0` profile to saturate query accuracy, so this is a hint-strength sensitivity finding rather than learned routing
- hashed key candidate mode (`--route-mode hint-kv-hash`) replaces exact lookup with symbolic hash buckets while preserving the value-position hint path; high-bit buckets reproduce exact-KV behavior, while lossy buckets show that top-K recall can recover before top-1 hint quality does
- multi-candidate vote aggregation (`--route-hint-agg vote`) improves lossy hash buckets by turning candidate value positions into nibble vote hints; this mitigates top1 failures but does not replace the need for candidate scoring/ranking
- weighted value-vote scoring (`--route-hint-agg weighted-vote --route-candidate-score value-vote`) passes as controlled scoring instrumentation, but is neutral on the current 32-key sweep because collided bucket values are mostly unique
- deterministic key-shape scoring (`--route-candidate-score key-shape`) passes as a symbolic scoring baseline and resolves the current 32-key lossy hash ambiguity, but it uses parsed key-string shape and should not be claimed as learned routing
- learned joint-code key-region hashing (`--route-hash-source joint-code-key`) is now wired as a diagnostic candidate source; the smoke passes, but the 32-key sweep still has high bucket ambiguity and is not a learned routing win. h4-5c representation diagnostics show low key-region reconstruction and high joint-signature collision, so prediction joint codes are not yet routing identity codes
- route-code identity auxiliary (`--route-hash-source route-code-key --route-code-aux 1`) passes as an explicit identity-code baseline and recovers the 32-key route-code sweep, showing that prediction code and routing identity code should be separated
- route-code stress/ablation shows the route identity code remains separable under tested 32/64-key and filler cases, but 128 keys can keep perfect retrieval while query accuracy drops; this is a route-hint dynamics/margin issue, not a reason to revive neighbor replacement
- route-hint dynamics margin ablation confirms that the 128-key issue is strength/effective-margin limited: retrieval remains perfect and `lambda_route = 10.0` recovers query accuracy to `1.000000`, while cycles and route-target proposal injection are not the primary fix
- adaptive route strength (`--route-strength-mode margin`) recovers the same 128-key setting with lower mean route strength than fixed `lambda_route = 10.0`; this is a calibrated route-hint diagnostic, not a reason to reopen neighbor replacement
- wrong-candidate corruption stress shows confidence guardrails can suppress wrong hint strength when corrupted candidates are marked low-confidence, but qacc damage reduction is modest; this reinforces that candidate confidence/ranking must improve before noisy learned routing claims
- candidate/value confidence calibration shows route weight confidence does not separate correct from wrong candidates in the current diagnostic, and value-support confidence lowers wrong strength without improving qacc; this is still a confidence instrumentation path, not routing robustness
- scorer-agreement confidence and confidence-gated aggregation extend the guardrail instrumentation: agreement creates a real confidence split and `confidence-gated` switches low-confidence queries to broad vote aggregation, but the current readout is only limited mitigation and does not solve wrong-candidate robustness
- low-confidence subset diagnostics keep the same value-bearing route-hint path and show two different failure modes: preserve-correct low-confidence queries keep top-K recall but lose top1/value support, while remove-correct corruption lowers recall and needs fallback or abstain behavior
- low-confidence policy split (`--route-lowconf-policy aggregate|none|weak-vote`) is policy instrumentation only: preserve-correct confirms the low-confidence branch is an aggregation/ranking problem (`none` hurts, `weak-vote` stays close to aggregate), while remove-correct remains a candidate availability problem that needs fallback, abstain, or redundant sources
- fallback source diagnostics (`--route-fallback-source key-shape`) are symbolic upper-bound instrumentation: remove-correct candidate availability can be recovered (`fallback_recall = 1.000000`) and qacc improves slightly, but fallback-used qacc remains low, so this is not wrong-candidate robustness solved and not learned routing
- projected route-hint delta diagnostics (`--route-delta-mode projected`) keep the reaction inside the query node's proposal energy: the C-version rewards only direct target-nibble entry and penalizes direct target-nibble exit, with no neighbor/spatial dragging. The current smoke is instrumentation / limited mitigation only; `pull=2.0` improves preserve-correct qacc but does not improve remove-correct fallback qacc

State-code route-signal probe:

- with the anchor decoupled from the candidate key, `state-code + cycle + probe` is prediction-neutral on both datasets
- final row stays exactly matched on `repeating-text`: `repeat-joint-probe = repeat-state-probe = 0.687500/0.687500/0.687500`
- last-10 also stays exactly matched on `repeating-text`: `0.684896/0.684462/0.684896`, with only a tiny candidate-count shift `1.860243 -> 1.858507`
- on the fixture, `state-code + cycle + probe` stays neutral at last-10 `0.198351/0.171007/0.203559`, with a small hit/candidate drift only
- guarded jump with `state-code + cycle` does not help `repeating-text`: last-10 remains `0.684896/0.684462/0.684896`, `active=0.000000`, `gap_pass=0.001736`
- the same `state-code + cycle` guarded jump only perturbs the fixture-side guarded run: last-10 `fixture-state-guard = 0.204861/0.168837/0.208767`, `active=0.006944`, versus `fixture-joint-guard = 0.204861/0.168837/0.208767`, `active=0.006510`
- switching `state-code` back to default `epoch` refresh collapses guarded jump to the conservative boundary: last-10 `repeat-state-epoch-guard = 0.684896/0.684462/0.684896`, `active=0.000000`; `fixture-state-epoch-guard = 0.198351/0.171007/0.203559`, `active=0.000000`

Route-key diagnostics:

- `joint-code` instrumentation checks out: last-10 `route_key_anchor_match_rate = 1.000000` and `mean_route_key_anchor_hamming = 0.000000` on both datasets
- `state-code + cycle` barely diverges from the learned anchor on `repeating-text`: last-10 `key_anchor = 0.996094`, `state_anchor = 0.998264`, `key_state = 0.995226`, `key_ham = 0.003906`
- the fixture shows the same shape: `state-code + cycle + probe` last-10 `key_anchor = 0.993490`, `state_anchor = 0.951389`, `key_state = 0.944879`, `key_ham = 0.008246`
- guarded fixture routing moves a little but not usefully: `state-code + cycle + guard` last-10 `key_anchor = 0.992622`, `key_ham = 0.009114`, `active = 0.006944`
- `state-code + epoch` is stale by construction: repeat last-10 `key_anchor = 0.000000`, `key_ham = 1.713108`; fixture last-10 `key_anchor = 0.020399`, `key_ham = 1.609809`

Triggered-only route-key diagnostics:

- `joint-code` triggered controls also check out: last-10 `triggered_route_key_anchor_match_rate = 1.000000` and `mean_triggered_route_key_anchor_hamming = 0.000000` on both datasets
- `state-code + cycle` remains almost identical to the anchor on triggered `repeating-text` nodes: last-10 `trig_key_anchor = 0.996094`, `trig_state_anchor = 0.998264`, `trig_key_state = 0.995226`, `trig_key_ham = 0.003906`
- the fixture triggered readout is similar: `state-code + cycle + probe` last-10 `trig_key_anchor = 0.993877`, `trig_state_anchor = 0.953162`, `trig_key_state = 0.947039`, `trig_key_ham = 0.007439`
- guarded fixture routing still moves before repeat-side lift appears: `state-code + cycle + guard` last-10 `trig_key_anchor = 0.993023`, `trig_key_ham = 0.008716`, `active = 0.006944`
- epoch refresh remains stale under the triggered denominator too: repeat last-10 `trig_key_anchor = 0.000000`, `trig_key_ham = 1.713108`; fixture last-10 `trig_key_anchor = 0.020584`, `trig_key_ham = 1.608100`

Input-byte candidate-source compare:

- `experiments/run_v03_input_byte_jump_compare.sh`
- compares `joint-code`, `input-byte`, and `state-code + cycle` candidate buckets under probe, forced-open `gap0`, and confidence-accepted jump cases on both `repeating-text` and the fixture
- it reuses the existing route-key diagnostics args and prints the final row and last-10 means for `byte/field/joint` plus every column from `routing_trigger_rate` onward
- treat it as a candidate-source probe only; it does not claim a routing win

Candidate rejection diagnostics:

- `experiments/run_v03_rejection_diagnostics.sh`
- compares `joint-code` and `input-byte` under forced-open `gap0` and confidence-accepted `jump-neighbors` arms on both `repeating-text` and the fixture
- it prints the final row and last-10 means for `byte/field/joint` plus every column from `routing_trigger_rate` onward, so the candidate-slot and reject/filter counters surface automatically when present
- filter counters are appended after the existing route-key diagnostics: `mean_jump_filter_candidates` is averaged over gate-passed triggered nodes, `jump_filter_*_rate` fields are first-terminal slot-level rates, and `jump_filter_underfilled_rate` is node-level
- treat it as diagnostic-only; the rejection counters explain the slice, but they do not turn a closed arm into a routing win

Reference readout, seed `1`, last-10:

- `input-byte` does create the desired anchor-different key: `repeating-text` has `triggered_route_key_anchor_match_rate = 0.000000` and `mean_triggered_route_key_anchor_hamming = 1.706641`; the fixture has `triggered_route_key_anchor_match_rate = 0.018526` and `mean_triggered_route_key_anchor_hamming = 1.612112`
- candidate coverage stays O(1): `input-byte` probe reports `mean_jump_candidates = 1.781250` on `repeating-text` and `1.798197` on the fixture, with `routing_hit_rate = 1.000000` and `0.992135`
- forced-open `input-byte gap0` is no longer structurally inert: it reaches `active_jump_rate = 0.001172` on `repeating-text` and `0.022656` on the fixture
- even when `input-byte gap0` opens, it gives no repeat-side lift (`byte/field/joint = 0.684766/0.684375/0.684766`) and hurts the fixture relative to probe (`0.197266/0.155859/0.198828` versus `0.200000/0.167969/0.205469`)
- `input-byte accept` with `--route-accept-confidence-gain 0.20` is expected to be inert because same-input candidates have the same `route_confidence_margin`; it is a sanity check for the acceptance predicate, not evidence that input buckets cannot jump
- `joint-code gap0` and `state-code + cycle gap0` also open the fixture more than `repeating-text`, so this remains a no-go for the present static-routing family
- rejection diagnostics explain the fixture-side behavior: `fixture-input-gap0` has last-10 `mean_jump_filter_candidates = 2.000000`, `jump_filter_selected_rate = 0.442083`, `jump_filter_anchor_gap_rate = 0.245495`, `jump_filter_local_replacement_rate = 0.121191`, and `jump_filter_underfilled_rate = 0.710330`
- confidence acceptance suppresses the same input bucket as expected: `fixture-input-accept` has `jump_filter_confidence_gain_rate = 0.556284`, `jump_filter_selected_rate = 0.000000`, and `jump_filter_underfilled_rate = 1.000000`
- on `repeating-text`, the gate barely opens even under `gap0` (`route_gap_pass_rate = 0.001562`), so last-10 filter means are sparse (`mean_jump_filter_candidates = 0.400000`); read those as averaged diagnostic evidence, not as a strong routing signal

Interpretation:

- the stronger route-anchor gate removes the fixture regression on the reference runs, but the slice still reads as probe-equivalent there
- scored top-K candidate ranking alone is not enough to revive active usage under the present gate, so the next bottleneck is no longer the table ordering itself
- the new diagnostics show the immediate bottleneck is the gate itself: default triggered nodes sit far below the current `min_anchor_gap`
- opening the gate to `0.0` revives some active usage on the fixture, but it also reintroduces the regression there while still doing almost nothing on `repeating-text`
- reservoir/tick adaptive lowering does not rescue that tradeoff in the tested range: it still opens the fixture earlier than `repeating-text`
- confidence is a real separator signal, but the current confidence-aware gate family still does not open `repeating-text` before the fixture starts to regress
- confidence-aware acceptance is better behaved than confidence-aware gate lowering, but it still acts as a suppression guard on the fixture rather than as a selective opener for `repeating-text`
- in other words, the acceptance family can reduce bad active usage, but it does not produce a routing lift worth carrying forward yet
- the route-hint oracle slice changes the semantics from "which remote node becomes a neighbor" to "which value-byte biases the local proposal"; the first oracle fixture passes at `lambda_route = 0.30`
- `state-code` does not create a meaningfully new route signal on `repeating-text` in the current static-routing slice
- the route-key diagnostics explain the no-go: cycle-refreshed `state-code` is already almost equal to the learned anchor on all nodes and on triggered nodes, while epoch-refreshed `state-code` is stale and inactive
- `cycle` refresh changes fixture-side guarded routing slightly, but not in a way that produces a repeat-side win
- `epoch` refresh collapses the state-key experiment back to the baseline/no-op boundary
- `input-byte` is a cleaner anchor-different candidate source than `state-code`, but forced-open usage still fails the repeat-lift/fixture-neutrality bar and positive confidence-gain acceptance suppresses it by construction
- if you need to separate gate failure from candidate-filter failure, start with `experiments/run_v03_rejection_diagnostics.sh` before adding another candidate generator
- `repeating-text` neutrality is still not enough on its own; any later active slice still has to keep the fixture neutral

Current decision:

- do not promote `jump-neighbors` to the main path yet
- keep `probe` mode as the safe routing diagnostics path
- treat any probe-equivalent fallback as a conservative boundary, not as a routing win
- keep the slice experimental until a later gate or diagnostic step produces a clear `repeating-text` lift while the fixture stays neutral
- treat `route-min-anchor-gap` ablation as a diagnostic tool for now, not as a default tuning path
- treat `route-adaptive-gap-scale` as a diagnostic tool for now, not as a promoted tuning path
- treat `route-confidence-gap-scale` as a diagnostic tool for now, not as a promoted tuning path
- treat `route-accept-confidence-gain` as a diagnostic guardrail tool for now, not as a promoted routing path
- treat `state-code` and `route-refresh` as diagnostic route-signal tools for now, not as a promoted routing path
- keep `hint-oracle` experimental and oracle-only until a learned key/value candidate can reproduce the query-position gain
- keep route-hint fallback/channel-strength work on the value-bearing hint path;
  it does not revive jump-neighbor replacement and should not be read as a
  static-routing promotion
- treat fallback channel-adaptive strength as value-hint integration
  diagnostics, not as evidence for neighbor-replacement routing
- treat low-nibble fallback strength grids as route-hint integration
  calibration, not as static-routing promotion
- treat fallback persistence / TTL diagnostics as query-local route-hint update
  priority instrumentation, not as static-routing promotion
- treat route-credit diagnostics as value-hint candidate/edge instrumentation,
  not as static-routing promotion
- treat route-credit ablations as value-bearing route-hint memory diagnostics;
  they may change candidate ranking/aggregation weights, but they do not
  revive neighbor replacement or prove learned routing
- `query-value` route credit is still edge-credit instrumentation on the
  value-bearing route-hint path; do not reinterpret it as static routing
  success
- treat credit × fallback integration factorials as value-bearing route-hint
  memory diagnostics; they combine candidate/edge credit with fallback
  low-channel strength but still do not revive neighbor replacement
- treat route-credit strength/stability calibration as value-bearing route-hint
  memory diagnostics; it tunes candidate/edge weighting and does not promote
  static neighbor replacement
- treat persistent route-plasticity ledger work as value-bearing route-hint
  memory instrumentation; it changes candidate/edge credit over time but does
  not promote static neighbor replacement
- treat source/bucket route-credit work as value-bearing route-hint memory
  instrumentation; it assigns responsibility to primary/fallback candidate
  sources and buckets, but it still does not promote static neighbor
  replacement
- treat source-credit policy calibration as value-bearing route-hint memory
  instrumentation; it changes whether source credit affects ranking and/or
  fallback strength, but it still does not promote static neighbor replacement
- treat noisy / learned-like source policy diagnostics as value-bearing
  route-hint memory instrumentation; they compare weak/noisy candidate sources
  through source credit while preserving `value_pos -> value byte -> proposal
  hint`, and they still do not promote static neighbor replacement
- treat noisy-source multi-seed / scale stability as value-bearing route-hint
  memory instrumentation; it checks whether source-quality separation repeats
  across small key/seed/noise sweeps, but it still does not promote static
  neighbor replacement
- treat weaker learned-source stress as value-bearing route-hint memory
  instrumentation; it weakens the route-code identity auxiliary and measures
  source-credit/fallback response while preserving `value_pos -> value byte ->
  proposal hint`, but it still does not promote static neighbor replacement
- treat weak learned-source scale stability as value-bearing route-hint memory
  instrumentation; it scales the route-code weakening over key/seed arms and
  measures fallback/source-credit response, but it still does not promote
  static neighbor replacement
- treat fallback-source ablation / stability as value-bearing route-hint memory
  instrumentation; it compares `off`, `raw-key`, `key-shape`, and
  `noisy-route-code` fallback arms while preserving `value_pos -> value byte ->
  proposal hint`, but it still does not promote static neighbor replacement
- treat h5-i source-credit fallback policy calibration as value-bearing
  route-hint memory instrumentation; it separates learn-only, ranking,
  strength, ranking-strength, and noisy negative-control fallback policy arms
  while preserving `value_pos -> value byte -> proposal hint`, but it still
  does not promote static neighbor replacement
- treat h5-j fallback candidate-quality gap diagnostics as value-bearing
  route-hint memory instrumentation; it separates fallback recall from
  top1/rank/vote-support/entropy and shows aggregation quality can dominate
  the fallback source gap, but it still does not promote static neighbor
  replacement
- treat h5-k fallback aggregation policy calibration as value-bearing
  route-hint memory instrumentation; it compares top1, vote, weighted-vote,
  and confidence-gated fallback aggregation policies while preserving
  `value_pos -> value byte -> proposal hint`, but it still does not promote
  static neighbor replacement
- treat h5-l source/noise-aware fallback aggregation diagnostics as
  value-bearing route-hint memory instrumentation; it separates symbolic
  good-source weighted aggregation from noisy bad-source detection while
  preserving `value_pos -> value byte -> proposal hint`, but it still does not
  promote static neighbor replacement
- treat h5-m source/noise-aware aggregation scale stability diagnostics as
  value-bearing route-hint memory instrumentation; it checks that the h5-l
  good-source aggregation / bad-source detection split repeats over key/seed
  smoke arms while preserving `value_pos -> value byte -> proposal hint`, but
  it still does not promote static neighbor replacement
- treat h5-n bad-source filter / abstain diagnostics as value-bearing
  route-hint memory instrumentation; it removes negative-credit source
  candidates from proposal-hint voting while preserving `value_pos -> value
  byte -> proposal hint`, but it still does not promote static neighbor
  replacement
- treat h5-o retry-source replacement diagnostics as value-bearing route-hint
  memory instrumentation; it inserts a secondary source after bad/noisy source
  filtering while preserving `value_pos -> value byte -> proposal hint`, but it
  still does not promote static neighbor replacement
- treat h5-p source-credit retry-policy diagnostics as value-bearing route-hint
  memory instrumentation; it chooses retry candidates from source-credit policy
  candidates while preserving `value_pos -> value byte -> proposal hint`, but
  it still does not promote static neighbor replacement
- treat h5-q source-credit retry-policy tie-break diagnostics as value-bearing
  route-hint memory instrumentation; it keeps `candidate value_pos -> value
  byte read -> proposal hint` while deciding source-order versus source-prior
  for retry candidates, but it still does not promote static neighbor
  replacement
- treat h5-r source-prior retry schedule diagnostics as value-bearing
  route-hint memory instrumentation; it changes retry-source prior scaling
  while preserving `candidate value_pos -> value byte read -> proposal hint`,
  but it still does not promote static neighbor replacement
- treat h5-s source-prior handoff diagnostics as value-bearing route-hint
  memory instrumentation; it compares short/long warmup and decay handoff
  behavior while preserving `candidate value_pos -> value byte read ->
  proposal hint`, but it still does not promote static neighbor replacement
- treat h5-t retry-source evidence-quality diagnostics as value-bearing
  route-hint memory instrumentation; it measures raw-key/key-shape/noisy retry
  source credit evidence while preserving `candidate value_pos -> value byte
  read -> proposal hint`, but it still does not promote static neighbor
  replacement
- treat h5-x proxy weight/sign calibration as value-bearing route-hint memory
  instrumentation; it reweights or sign-flips the source-quality proxy terms
  while preserving `candidate value_pos -> value byte read -> proposal hint`,
  but it still does not promote static neighbor replacement
- treat h5-y channel-sign multi-seed/scale diagnostics the same way: a soft
  source-quality calibration over value-bearing route hints, not a static
  neighbor-routing promotion
- treat h5-z source-normalization diagnostics the same way: proxy rescaling for
  source ranking only, not topology replacement or static routing promotion
- treat h5-aa candidate-level quality diagnostics the same way: correct/wrong
  candidate weight separation inside value-bearing route-hint memory, not
  topology replacement or static routing promotion
- treat h5-ab weak candidate-level quality application the same way: bounded
  candidate weight sharpening inside value-bearing aggregation, not topology
  replacement or static routing promotion
- treat h5-ac candidate-weight composition diagnostics the same way: source and
  candidate quality weights inside value-bearing route hints, not topology
  replacement or static routing promotion
- treat h5-ad candidate-only beta/noise scale diagnostics the same way:
  candidate quality beta calibration inside value-bearing aggregation, not
  topology replacement, route-strength promotion, or static routing promotion
- treat h5-ae candidate-weight saturation/cap diagnostics the same way:
  bounded candidate-weight cap calibration inside value-bearing aggregation,
  not topology replacement, route-strength promotion, or static routing
  promotion
- treat h5-af candidate-quality regression diagnostics the same way: broader
  key/seed/noise regression for bounded candidate weighting, not topology
  replacement, route-strength promotion, or static routing promotion
- treat h5-ag candidate-quality over-sharpen boundary diagnostics the same
  way: higher bounded candidate-weight beta/cap calibration, not topology
  replacement, route-strength promotion, or static routing promotion
- treat h5-ah high-beta candidate-quality boundary diagnostics the same way:
  continued bounded candidate-weight beta/cap calibration, not topology
  replacement, route-strength promotion, or static routing promotion
- treat h5-ai extreme-beta candidate-quality boundary diagnostics the same way:
  higher bounded candidate-weight beta/cap boundary calibration, not topology
  replacement, route-strength promotion, or static routing promotion
- treat h5-aj ultra-beta candidate-quality plateau/boundary diagnostics the
  same way: bounded candidate-weight plateau calibration, not topology
  replacement, route-strength promotion, or static routing promotion
- treat h5-ak candidate-quality guardrail selection diagnostics the same way:
  safe bounded candidate-weight setting selection, not topology replacement,
  route-strength promotion, or static routing promotion
- treat h5-al candidate-quality safe-default application diagnostics the same
  way: candidate-weight-only default selection, not source-ranking promotion,
  topology replacement, route-strength promotion, or static routing promotion
- treat h5-am candidate-feature basis calibration diagnostics the same way:
  candidate-weight basis calibration, not quality-score default promotion,
  topology replacement, route-strength promotion, or static routing promotion

Allowed wording:

- `experimental static routing candidate-ranking slice`
- `default-off jump-neighbor dynamics`
- `O(1)-candidate route coverage`
- `oracle value-bearing route hint`
- `fallback channel-strength diagnostics`
- `fallback channel-adaptive diagnostics`
- `low-nibble fallback strength calibration`
- `fallback persistence diagnostics`
- `route-credit separation diagnostics`
- `route-credit ablation diagnostics`
- `credit × fallback integration diagnostics`
- `route-credit strength/stability calibration`
- `route-plasticity ledger instrumentation`
- `route-credit learn/apply warmup diagnostics`
- `source/bucket route-credit instrumentation`
- `source-level fallback responsibility diagnostics`
- `source-credit policy calibration diagnostics`
- `source-credit retry-policy tie-break calibration diagnostics`
- `source-prior retry schedule calibration diagnostics`
- `source-prior handoff calibration diagnostics`
- `retry-source evidence-quality instrumentation`
- `candidate-quality diagnostics`
- `weak quality source-ranking application diagnostics`
- `source-quality calibration diagnostics`
- `proxy weight/sign calibration diagnostics`
- `noisy-source policy diagnostics`
- `source-quality separation instrumentation`
- `noisy-source scale stability diagnostics`
- `weaker learned-source stress instrumentation`
- `weak learned-source scale stability diagnostics`
- `fallback-source dependence diagnostics`
- `fallback-source ablation diagnostics`
- `fallback-source policy calibration diagnostics`
- `fallback candidate-quality gap diagnostics`
- `fallback aggregation policy calibration diagnostics`
- `source/noise-aware fallback aggregation diagnostics`
- `source/noise-aware aggregation scale stability diagnostics`
- `bad-source filter / abstain diagnostics`
- `retry-source replacement diagnostics`
- `source-credit retry-policy calibration diagnostics`
- `candidate-quality safe-default application diagnostics`
- `candidate-feature basis calibration diagnostics`
- `hybrid candidate-basis calibration diagnostics`
- `hybrid candidate-basis guardrail scale diagnostics`
- `hybrid candidate-basis promotion-check diagnostics`
- `concentration-aware candidate-basis switching diagnostics`
- `auto-threshold calibration diagnostics`
- `auto-trigger decomposition diagnostics`
- `auto-trigger policy ablation diagnostics`
- `factor-trigger threshold refinement diagnostics`

h5-aq concentration-aware candidate-basis switching also stays on the
non-topological route-hint path. `basis=auto` switches only the candidate-weight
basis between base and `hybrid-m0p25`; it does not create remote neighbors,
route triggers, or active jumps.
h5-as only decomposes that switch into factor-trigger and top-share-trigger
rates. It does not create remote neighbors, route triggers, or active jumps.
h5-at only selects which of those non-topological triggers is allowed to switch
the candidate-weight basis. It does not create remote neighbors, route triggers,
or active jumps.
h5-au only changes the factor threshold in that non-topological switch. It does
not create remote neighbors, route triggers, or active jumps.
h5-av/h5-aw/h5-ax/h5-ay/h5-az/h5-ba/h5-bb/h5-bc only make the
base-vs-hybrid-safe candidate-weight policy easier to summarize, guard,
preset, compare, and regression-test. They do not create remote neighbors,
route triggers, or active jumps.

Do not say:

- `sparse-routing success`
- `long-context retrieval works`
- `chunk/token routing works`
- `routing plasticity works`
- `route plasticity solved`
- `source credit solves routing`
- `noisy source credit solves robustness`
- `source-quality separation solves learned routing`
- `weakened route-code source solves learned routing`
- `weak learned-source scale proves learned routing`
- `fallback-source ablation solves learned routing`
- `key-shape fallback is learned routing`
