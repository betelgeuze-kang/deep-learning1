# h5 Quality Diagnostics Plan

This is the implementation plan I would use after h5-t.

The goal is not to solve learned routing yet. The goal is to measure why some
retry/fallback candidate sets produce better value-bearing hints than others,
without changing route behavior.

## Fixed Principles

- Keep the live nonlocal path unchanged:

  ```text
  candidate value_pos -> value byte read -> proposal hint
  ```

- Keep jump-neighbor replacement default-off / diagnostic-only.
- For the first application slice, use soft `route_quality_apply=source-ranking`
  only; do not use hard threshold/filter.
- Do not use these metrics to drop candidates in the first slice.
- Do not claim learned routing, source-credit robustness, fallback robustness,
  or wrong-candidate robustness.
- Treat `key-shape` as symbolic diagnostic evidence, not learned routing.

## Slice Order

### h5-u Candidate-quality Diagnostics

Implement three metric-only diagnostics:

1. Candidate-feature Gram LogDet
2. Multi-channel Coupling Margin Matrix proxies
3. Continuous Quality/Credit Score, computed only with `apply=none`

The h5-u acceptance target is PASS as candidate-quality
logdet/channel/quality-score instrumentation:

- New CLI flags parse correctly.
- New CSV columns are populated when diagnostics are enabled.
- `route_quality_apply=none` leaves qacc and route selection behavior unchanged
  within the smoke tolerance.
- The value-bearing route path remains populated.
- `routing_trigger_rate=0` and `active_jump_rate=0`.

### h5-v Weak Quality Application Decision

`h5-v` passes as weak quality source-ranking application diagnostics /
neutral-to-slight-regression. It does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

- `route_quality_apply=source-ranking` is active and uses a bounded soft delta.
- The live path stays unchanged:

  ```text
  candidate value_pos -> value byte read -> proposal hint
  ```

- No hard thresholding or hard filtering is used.
- Jump-neighbor replacement remains default-off / no-go.
- Candidate-weight and strength remain follow-ups only.

Readout:

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
source-ranking quality application is wired and avoids noisy retry selection,
but it slightly lowers qacc in this smoke. Treat it as calibration diagnostics,
not limited mitigation.

### h5-w Source-quality Calibration Decision

`h5-w` passes as source-quality calibration diagnostics. It does not solve
learned routing, source-credit robustness, wrong-candidate robustness, or
fallback robustness.

The slice keeps the h5-v behavior path but exposes the per-source quality
proxy, soft delta, and selected-source qacc:

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
the current quality proxy is active and explains the source choice: it strongly
prefers raw-key over key-shape/noisy and continues to avoid noisy retry.
However, this raw-key preference is not qacc-optimal in the current smoke. The
next step is h5-x proxy weight/sign calibration: normalize or reweight the
vote/logdet/entropy/channel terms against selected-source qacc before trying
stronger application modes.

### h5-x Proxy Weight/Sign Calibration Decision

`h5-x` passes as proxy weight/sign calibration diagnostics and single-smoke
limited mitigation. It keeps the live path unchanged:

```text
candidate value_pos -> value byte read -> proposal hint
```

It keeps the h5-v source-ranking path fixed and calibrates the proxy term
signs and weights against selected-source qacc.

```text
proxy_score =
    w_raw * raw_proxy
  + w_keyshape * keyshape_proxy
  + w_noisy * noisy_proxy
```

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
the channel term sign is a useful calibration handle in this smoke. The
best row improves qacc without selecting noisy retry, but it still keeps the
same broad source choice. Treat this as single-smoke limited mitigation and
diagnostics, not source-credit robustness or learned routing solved. Next:
multi-seed/scale stability for the channel-sign calibration.

### h5-y Channel-sign Multi-seed / Scale Stability Decision

`h5-y` passes as channel-sign calibration multi-seed/scale diagnostics and
weak limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

It keeps the same safety boundaries:

```text
candidate value_pos -> value byte read -> proposal hint
jump-neighbor replacement stays inactive
route_quality_apply is limited to none/source-ranking
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off qacc_mean          = 0.622656
proxy-default qacc_mean      = 0.621094
proxy-channel-sign qacc_mean = 0.636198

proxy-channel-sign:
  selected_raw_rate_mean = 0.753385
  selected_keyshape_rate_mean = 0.000000
  selected_noisy_rate_mean = 0.000000
  selected_raw_qacc_mean = 0.672334
```

Interpretation:
the negative channel term remains useful on the first multi-seed/key smoke and
does not reintroduce noisy retry selection. But the selected source remains
raw-key, so h5-y does not solve source selection quality. The next calibration
target is source-specific normalization or candidate-level quality scoring,
not stronger route-strength application.

### h5-z Source-normalization Decision

`h5-z` passes as source-normalization instrumentation and neutral diagnostics,
but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

New diagnostic knobs:

```text
--route-quality-source-normalization none|center|zscore
--route-quality-source-norm-eps <float>
```

The raw source proxy remains visible, while normalized proxy metrics show the
actual score used by source-ranking:

```text
route_quality_retry_raw_norm_proxy_mean
route_quality_retry_keyshape_norm_proxy_mean
route_quality_retry_noisy_norm_proxy_mean
```

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
center/zscore normalization lowers raw-key pressure, but source choice and qacc
remain unchanged relative to unnormalized channel-sign. This is useful plumbing:
proxy scale is now controllable, but source selection quality is still not
solved. Next: candidate-level quality diagnostics/application with
route-strength modulation still off.

### h5-aa Candidate-level Quality Diagnostics Decision

`h5-aa` passes as candidate-level quality diagnostics and an actionable split,
but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds candidate-level readouts while preserving the existing
value-bearing path:

```text
candidate value_pos -> value byte read -> proposal hint
```

New metrics:

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

channel-sign-center/zscore:
  qacc_mean = 0.636198
  candidate_weight_gap = 0.179034
  candidate_best_correct_rate = 0.838021
```

Interpretation:
candidate weights already contain a positive correctness signal: correct
candidate weight is higher than wrong candidate weight, and the best weighted
candidate is correct more often than final query accuracy. Therefore the
remaining bottleneck is not raw candidate ranking alone. It is likely the
conversion from candidate-level support into stable query-state convergence,
aggregation, or hint integration. Source normalization does not change these
candidate-level metrics in this smoke, so the next application slice should be
candidate-level and weakly bounded, not route-strength modulation.

### h5-ab Weak Candidate-level Quality Application Decision

`h5-ab` passes as weak bounded candidate-level quality application diagnostics
and limited mitigation, but it does not solve learned routing, source-credit
robustness, wrong-candidate robustness, or fallback robustness.

The slice enables the previously reserved `candidate-weight` apply path. It
does not use target labels and does not change route strength. It sharpens
candidate weights using only each candidate's base weight relative to the
candidate-set mean:

```text
factor = clamp(
  1 + beta * (base_weight / mean_base_weight - 1),
  min_factor,
  max_factor
)
```

New knobs:

```text
--route-quality-apply candidate-weight
--route-quality-candidate-weight-beta <float>
--route-quality-candidate-weight-min <float>
--route-quality-candidate-weight-max <float>
```

Standard smoke:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.25

proxy-off:
  qacc_mean = 0.622656
  candidate_weight_gap = 0.180509

source-ranking:
  qacc_mean = 0.636198
  candidate_weight_gap = 0.179034

candidate-b0p10:
  qacc_mean = 0.635156
  factor_gap = 0.052627
  candidate_weight_gap = 0.193792

candidate-b0p25:
  qacc_mean = 0.663542
  factor_gap = 0.131568
  candidate_weight_gap = 0.212711

candidate-b0p50:
  qacc_mean = 0.725261
  factor_gap = 0.263136
  candidate_weight_gap = 0.241817
```

Interpretation:
candidate-level application converts the h5-aa candidate correctness signal
into a clear qacc lift on this first multi-seed/key smoke. The best row remains
below `candidate_best_correct_rate = 0.838021`, so the remaining gap is still
aggregation-to-state or hint-integration limited. This is limited mitigation,
not learned routing or robustness solved. Next: test candidate-weight scale
stability and whether it composes with source-ranking without over-sharpening.

### h5-ac Candidate-weight Composition Decision

`h5-ac` passes as candidate-weight scale/composition diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds a combined quality apply mode:

```text
--route-quality-apply source-candidate
```

This turns on both soft source-ranking and bounded candidate-weight sharpening
while still preserving:

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

source-ranking:
  qacc_mean = 0.636198

candidate-b0p25:
  qacc_mean = 0.663542

candidate-b0p50:
  qacc_mean = 0.725261

source-candidate-b0p25:
  qacc_mean = 0.667708

source-candidate-b0p50:
  qacc_mean = 0.717708
```

Interpretation:
candidate-level sharpening remains the cleaner improvement path in this smoke.
Composing source-ranking with candidate-weight is active and safe, but it does
not add to `candidate-b0p50`; it slightly underperforms candidate-only
application. Noisy retry selection and jump-neighbor activity remain zero.
Therefore the next slice should scale candidate-only `beta=0.50` across more
keys/seeds/noise before making source-composition or route-strength claims.

### h5-ad Candidate-only Beta / Noise Scale Decision

`h5-ad` passes as candidate-only beta/noise scale diagnostics and limited
mitigation, but it does not solve learned routing, source-credit robustness,
wrong-candidate robustness, or fallback robustness.

The slice adds:

```text
experiments/run_v05_route_quality_candidate_scale.sh
experiments/test_v05_route_quality_candidate_scale.sh
```

It keeps the behavior-changing surface narrow:

```text
candidate value_pos -> value byte read -> proposal hint
```

The standard sweep expands h5-ab/h5-ac over:

```text
keys = 64, 128
seeds = 1..3
noisy_source_rate = 0.10, 0.25, 0.50
```

Reference aggregate:

```text
proxy-off:
  qacc_mean = 0.615799

candidate-b0p25:
  qacc_mean = 0.666580
  factor_gap = 0.132544

candidate-b0p50:
  qacc_mean = 0.722222
  factor_gap = 0.265089

candidate-b0p75:
  qacc_mean = 0.775434
  factor_gap = 0.397633
  candidate_weight_gap = 0.266717
```

All arms preserve the non-topological guard:

```text
route_quality_selected_noisy_rate = 0.000000
routing_trigger_rate = 0.000000
active_jump_rate = 0.000000
```

Interpretation:
candidate-only quality application remains the cleanest quality path. Within
the tested bounded factor range, `beta=0.75` continues to improve qacc rather
than showing an over-sharpening regression. This is still controlled route-hint
mitigation: qacc remains below the best-candidate diagnostic ceiling, and no
learned routing or robustness claim is warranted. The next slice should test
candidate-weight saturation/cap behavior before applying route-quality to route
strength.

## Diagnostic 1: Candidate-feature Gram LogDet

Start with `value-only` features:

```text
f_k = [one_hot(value_hi, 16), one_hot(value_lo, 16)]
```

For a candidate set with K candidates and D features:

```text
G = F F^T / D + eps I
logdet = log(det(G))
logdet_norm = logdet / K
```

This measures candidate-set dispersion, not correctness. Interpret it only
together with entropy, vote margin, and correct-value vote share.

## Diagnostic 2: Channel Tension Proxies

Start with a simple 2x2 proxy rather than a full virtual proposal simulation:

```text
T = [ hi_margin      offdiag_proxy
      offdiag_proxy  lo_margin     ]
```

Use existing local channel margins for the diagonal terms. Use a conservative
B-coupling disagreement proxy for off-diagonal tension. This is only a metric.

## Diagnostic 3: Continuous Quality Score

Compute a score, but do not apply it in h5-u:

```text
quality_score =
    vote_margin_weight * vote_margin
  + top_share_weight * top_value_share
  + source_credit_weight * source_credit_proxy
  - entropy_weight * entropy
  - logdet_weight * logdet_norm
  - channel_weight * channel_offdiag
```

Initial default weights:

```text
logdet_weight = 0.1
entropy_weight = 0.5
vote_margin_weight = 1.0
top_share_weight = 1.0
source_credit_weight = 0.5
edge_credit_weight = 0.5
channel_weight = 0.1
```

## CLI

```bash
--route-quality-diagnostics 0|1
--route-quality-feature-set value-only
--route-quality-apply none|candidate-weight|source-ranking|strength
--route-quality-eps 1e-4

--route-channel-tension-diagnostics 0|1
--route-channel-tension-mode margin

--route-quality-score 0|1
--route-quality-logdet-weight 0.1
--route-quality-entropy-weight 0.5
--route-quality-vote-margin-weight 1.0
--route-quality-top-share-weight 1.0
--route-quality-source-credit-weight 0.5
--route-quality-edge-credit-weight 0.5
--route-quality-channel-weight 0.1
```

For h5-u, only `feature-set=value-only` and `apply=none` are valid for behavior.
The `dynamics` and `full` feature sets are planned follow-ups, not accepted
by the current implementation. h5-v opens only the first weak apply path:
`source-ranking`, with a bounded soft delta and no hard threshold/filter.
`candidate-weight` and `strength` remain reserved for later slices.

## h5-u Decision

The h5-u slice passes as candidate-quality logdet/channel/quality-score
instrumentation:

```text
quality-off-source-order qacc = 0.645313
quality-on-source-order  qacc = 0.645313

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

The readout supports using candidate-quality metrics as instrumentation. It
does not solve learned routing or fallback robustness.

## Metrics

Core metrics:

```text
route_quality_logdet_mean
route_quality_logdet_norm_mean
route_quality_condition_mean
route_quality_score_mean
route_quality_score_correct_mean
route_quality_score_wrong_mean
route_quality_score_gap
```

Channel metrics:

```text
route_channel_tension_det_mean
route_channel_tension_trace_mean
route_channel_tension_offdiag_mean
route_channel_hi_margin_mean
route_channel_lo_margin_mean
route_channel_margin_imbalance_mean
```

Source summary is done in runners by grouping arms:

```text
raw_quality_logdet_mean
keyshape_quality_logdet_mean
policy_keyshape_logdet_mean
fixed_keyshape_logdet_mean
route_quality_retry_raw_proxy_mean
route_quality_retry_keyshape_proxy_mean
route_quality_retry_noisy_proxy_mean
route_quality_retry_raw_delta_mean
route_quality_retry_keyshape_delta_mean
route_quality_retry_noisy_delta_mean
route_quality_selected_raw_qacc
route_quality_selected_keyshape_qacc
route_quality_selected_noisy_qacc
```

## h5-u Runner

Use:

```text
experiments/run_v05_route_candidate_quality_logdet.sh
experiments/test_v05_route_candidate_quality_logdet.sh
```

Recommended smoke arms:

```text
quality-off-source-order
quality-on-source-order
quality-on-keyshape-prior
quality-on-fixed-raw
quality-on-fixed-keyshape
```

Acceptance:

- All quality columns exist and are finite.
- Quality-on source-order does not materially change qacc versus quality-off.
- Fixed key-shape remains the symbolic upper reference if it was already so in
  h5-s/h5-t.
- At least one diagnostic signal differs between raw-key and key-shape rows:
  logdet, entropy, vote margin, channel offdiag, or quality score.

## Interpretation Rules

Allowed:

- `PASS as candidate-quality logdet/channel/quality-score instrumentation`
- `PASS as candidate-quality diagnostics`
- `PASS as logdet/channel/quality-score instrumentation`
- `PASS as quality proxy calibration diagnostics`
- `PASS as proxy weight/sign calibration diagnostics`
- `limited mitigation` only if qacc improves without behavior-changing apply
  modes, which is unlikely and should be treated cautiously

Forbidden:

- `learned routing solved`
- `source-credit robustness solved`
- `fallback robustness solved`
- `wrong-candidate robustness solved`
- `jump-neighbor routing revived`
- `proxy weight/sign calibration solved`
