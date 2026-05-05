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
