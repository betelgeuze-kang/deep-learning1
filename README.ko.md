# discrete-local-energy 한국어 README

[English README](README.md)

이 저장소는 단계적으로 확장 중인 deterministic C++17 이산 local-energy 연구 프로토타입입니다.

## 현재 한 줄 요약

현재 프로젝트는 **이산 local-energy learner + value-bearing route-hint memory** 연구 프로토타입으로 보는 것이 가장 정확합니다. v0.3에서 가장 강하게 확인된 결론은 장거리 정보가 `remote node as neighbor`로 들어오면 안 되고, `candidate value_pos -> value byte read -> proposal hint` 형태로 들어와야 한다는 점입니다.

아직 다음을 주장하는 단계는 아닙니다.

- learned sparse routing solved
- long-context retrieval solved
- wrong-candidate robustness solved
- Transformer replacement

현재 live path는 `candidate value_pos -> value byte read -> proposal hint` 경로이며, candidate discovery, identity preservation, hint strength, confidence, fallback, route credit을 분리해서 계측하는 단계입니다.

- h5-u는 candidate-quality logdet/channel/quality-score instrumentation으로 PASS했고, h5-v는 weak quality source-ranking application diagnostics / neutral-to-slight-regression으로 PASS했으며, h5-w는 source-quality calibration diagnostics로 PASS했고, h5-x는 proxy weight/sign calibration diagnostics / single-smoke limited mitigation으로 PASS했으며, h5-y는 channel-sign multi-seed/scale stability diagnostics / weak limited mitigation으로 PASS했고, h5-z는 source-normalization instrumentation / neutral diagnostics로 PASS했으며, h5-aa는 candidate-level quality diagnostics / actionable split으로 PASS했고, h5-ab는 weak bounded candidate-level quality application / limited mitigation으로 PASS했으며, h5-ac는 candidate-weight composition diagnostics / limited mitigation으로 PASS했고, h5-ad는 candidate-only beta/noise scale diagnostics / limited mitigation으로 PASS했으며, h5-ae는 candidate-weight saturation/cap diagnostics / limited mitigation으로 PASS했고, h5-af는 candidate-quality best-setting scale regression diagnostics / limited mitigation으로 PASS했으며, h5-ag는 candidate-quality over-sharpen boundary diagnostics / limited mitigation으로 PASS했고, h5-ah는 high-beta candidate-quality boundary diagnostics / limited mitigation으로 PASS했으며, h5-ai는 extreme-beta candidate-quality boundary diagnostics / limited mitigation으로 PASS했고, h5-aj는 ultra-beta candidate-quality plateau/boundary diagnostics / limited mitigation으로 PASS했으며, h5-ak는 candidate-quality guardrail selection diagnostics로 PASS했고, h5-al은 candidate-quality safe-default application diagnostics / limited mitigation으로 PASS했으며, h5-am은 candidate-feature basis calibration diagnostics로 PASS했고, h5-an은 hybrid candidate-basis calibration diagnostics / lower-concentration limited mitigation으로 PASS했으며, h5-ao는 hybrid candidate-basis guardrail scale diagnostics / lower-concentration limited mitigation으로 PASS했고, h5-ap는 hybrid candidate-basis promotion check / safe alternative diagnostics로 PASS했으며, h5-aq는 concentration-aware candidate-basis switching diagnostics / safe alternative instrumentation으로 PASS했고, h5-ar는 auto-threshold calibration diagnostics / safe alternative instrumentation으로 PASS했으며, h5-as는 auto-trigger decomposition diagnostics로 PASS했고, h5-at는 auto-trigger policy ablation diagnostics로 PASS했으며, h5-au는 factor-trigger threshold refinement diagnostics로 PASS했습니다. `route_quality_apply=source-ranking`은 soft bounded delta만 쓰며 noisy retry 선택은 `0.000000`으로 유지됩니다. `route_quality_apply=candidate-weight`는 route strength를 바꾸지 않고 후보 weight만 clamped relative factor로 약하게 sharpen합니다. `route_quality_apply=source-candidate`는 source-ranking과 candidate-weight를 같이 켭니다. h5-ak standard sweep(`keys=64,128,256`, seeds `1..5`, noisy source rates `0.10,0.25,0.50`)에서는 `beta=8, cap=8`이 더 안전한 guardrail 설정입니다. h5-al은 이 설정을 default arm으로 확인했고, `candidate-default` qacc는 `0.886429`, `proxy-off`는 `0.646962`, `source-candidate-default`는 `0.884896`입니다. h5-am은 `--route-quality-candidate-weight-basis base|quality-score`를 추가했고, feature-score basis는 연결됐지만 `base-default qacc=0.837630`보다 낮습니다(`feature-margin qacc=0.800000`). h5-an/h5-ao/h5-ap는 `hybrid` basis와 `--route-quality-candidate-weight-basis-mix`를 추가/확장했고, h5-aq부터 h5-au까지는 `--route-quality-candidate-weight-basis auto`와 concentration threshold 옵션을 추가/분해했습니다. h5-au에서 factor threshold는 거칠게 양자화됩니다. `5.6/5.8`은 같은 broad arm입니다(`auto_hybrid_rate=0.875304`, `factor_gap=3.241454`, `qacc=0.886328`). `6.0/6.2`는 같은 balanced arm입니다(`auto_hybrid_rate=0.315668`, `factor_gap=3.471377`, `qacc=0.886328`). `6.4`는 factor switching이 꺼져 base-like입니다(`auto_hybrid_rate=0.000000`, `factor_gap=3.596599`, `qacc=0.886458`). noisy source 선택, routing trigger, active jump는 계속 `0.000000`입니다. 따라서 이는 controlled route-hint fixture 내부의 bounded candidate-weight default/basis calibration이지 learned routing이나 robustness solved가 아닙니다.

## 현재 권장 기본 해석

- 기본 경로는 계속 `candidate value_pos -> value byte read -> proposal hint`입니다. quality proxy, source credit, candidate weight는 이 경로 위에서만 사용하며, `jump-neighbor` topology replacement는 부활시키지 않습니다.
- 현재 candidate-quality 기본값은 `--route-quality-apply candidate-weight`와 `--route-quality-candidate-weight-basis base`입니다. h5-au 기준 `base-default qacc=0.886458`로 여전히 가장 단순하고 안전한 기본값입니다.
- concentration을 낮춰야 할 때는 `hybrid-m0p25`를 안전한 대안으로 봅니다. qacc는 사실상 동률(`0.886545`)이고, factor concentration과 wrong strength를 base보다 낮춥니다.
- factor-only `auto` threshold는 diagnostic-only입니다. h5-au는 `5.6/5.8`, `6.0/6.2`, `6.4` threshold가 broad / balanced / base-like regime을 설명한다는 점을 보여줬지만, base default나 `hybrid-m0p25`를 성능 기준으로 넘지는 못했습니다.
- 따라서 현재 상태는 candidate-quality weighting과 basis calibration의 controlled fixture 성과입니다. learned routing solved, source-credit robustness solved, wrong-candidate robustness solved, fallback robustness solved, long-context retrieval solved로 주장하면 안 됩니다.
- h5-av는 이 결론을 key/noise cell별 policy CSV로 읽기 쉽게 만든 slice입니다. Smoke에서는 `base-default`와 `hybrid-m0p25` qacc가 `0.887500`으로 같고, `hybrid-m0p25`가 factor gap을 `3.650981 -> 3.304388`로 낮춰 `hybrid-m0p25-safe` 추천을 받습니다.
- h5-aw는 같은 policy summary를 9개 key/noise cell(`keys=64,128,256`, noisy rates `0.10,0.25,0.50`, seeds `1..5`)로 확장했습니다. 평균 qacc는 `0.885746 -> 0.885747`로 동률이고, factor gap은 `3.607673 -> 3.252902`, wrong strength는 `5.852729 -> 5.779043`으로 내려가며, 모든 cell에서 `hybrid-m0p25-safe` 추천이 나옵니다.
- h5-ax는 이 safe-alternative 결론을 regression guard로 고정합니다. `hybrid-m0p25`는 base 대비 qacc `0.001` 이내, factor gap 감소, factor max no-increase, aggregate wrong-strength no-regression, jump-neighbor 비활성 조건을 계속 통과해야 합니다.
- h5-ay는 `--route-quality-candidate-weight-preset none|base-default|hybrid-safe`를 추가해 긴 candidate-weight 옵션 묶음을 안전하게 줄입니다. Preset smoke에서 explicit 설정과 preset 설정이 metric 단위로 일치했고, `routing_trigger_rate = active_jump_rate = 0.000000`을 유지합니다.
- h5-az는 preset adoption을 작은 key/seed/noise matrix로 확장했습니다. 16개 row에서 explicit 설정과 preset 설정이 완전히 일치합니다(`equivalent_rate=1.000000`, 모든 metric delta `0.000000`). lookup/read는 살아 있고 jump-neighbor routing은 계속 비활성입니다.
- h5-ba는 preset 자체를 실험 arm으로 직접 비교합니다. 같은 작은 key/seed/noise matrix에서 `hybrid-safe`가 모든 row에서 추천됩니다. qacc는 `0.863281 -> 0.864258`, factor gap은 `3.440251 -> 3.118539`, factor max는 `6.333333 -> 6.049084`로 내려가며 jump-neighbor routing은 계속 비활성입니다.
- h5-bb는 h5-ba preset-policy matrix를 scale guardrail test로 고정합니다. 두 preset arm이 모두 있어야 하고, 모든 policy row가 `hybrid-safe`를 추천해야 하며, factor gap/max와 aggregate wrong strength가 악화되지 않고 `routing_trigger_rate = active_jump_rate = 0.000000`을 유지해야 합니다.
- h5-bc는 현재 route-quality stack을 닫는 closure smoke입니다. shell syntax, `dmv02` build, oracle route-hint, preset equivalence, preset policy smoke, preset policy scale guardrail을 한 번에 확인합니다. `--extended`는 route-code adaptive, preset regression, candidate-basis guardrail scale까지 추가로 확인합니다.
- h6-a는 route-memory phase를 여는 span-boundary diagnostic입니다. multi-byte fixture(`HELLO` / `WORLD`)에서도 현재 stack은 `kv_query_count = route_hint_query_count = 2`로 key당 첫 value byte 하나만 route hint로 노출합니다. 이는 span/chunk routing solved가 아니라 h6의 시작 경계를 명시하는 instrumentation입니다.
- h6-b는 exact KV용 `--route-span-hints 0|1`을 추가합니다. `--route-mode hint-kv-exact --route-span-hints 1`에서 같은 `HELLO` / `WORLD` fixture는 `kv_query_count = route_hint_query_count = 10`으로 확장되어 value-span offset마다 route hint를 가집니다. 경로는 여전히 value-bearing proposal hint이고 jump-neighbor routing은 비활성입니다.
- h6-c는 exact span scale diagnostics를 추가합니다. Smoke는 `key_count=2`, `value_len=5`에서 first-byte arm과 span arm을 비교하며, `--route-span-hints 1`에서 route hint query count가 `2 -> 10`으로 확장되고 exact hit/apply와 jump-neighbor 비활성을 유지합니다.
- h6-d는 hashed symbolic candidate에도 span hint를 확장합니다. `--route-mode hint-kv-hash --route-span-hints 1`에서 hash bucket entry가 span offset을 보존하고 query offset마다 같은 offset candidate만 비교합니다. Smoke는 `kv_query_count = route_hint_query_count = route_candidate_query_count = 10`, candidate recall/top1 `1.000000`, `routing_trigger_rate = active_jump_rate = 0.000000`을 확인합니다. 이는 controlled symbolic span-candidate routing이지 learned chunk retrieval은 아닙니다.
- h6-e는 span hash scale diagnostics를 추가합니다. 표준 matrix는 key count, value length, hash bits를 교차한 8개 row이며, offset-aware hash candidate가 `qacc_mean = recall_mean = top1_mean = 1.000000`, `collision_rate_mean = 0.000000`, jump-neighbor 비활성을 유지합니다. 이는 span-candidate scale guard이지 learned chunk retrieval은 아닙니다.

## 현재 상태

- `v0.1`: `dmv01`로 구현된 discrete local-energy dynamics 기준 구현입니다.
- `v0.2-pre`: `dmv02`로 구현된 shared field `H[channel][input_byte][state]` 기반 byte-level contrastive learning baseline입니다.
- `v0.2-b`: block-local coupled proposal과 `B[x, high, low]` coupling을 포함합니다. 기본 weak-coupling path는 `counter`와 `repeating-text` 5-seed regression을 통과했습니다.
- `v0.3 static routing`: `jump-neighbors`, confidence gate/acceptance, `state-code`, `input-byte` route source 계열은 diagnostic/default-off입니다. 현재 결론은 routing success가 아니라 **jump-neighbor replacement no-go/default-off/diagnostic-only**입니다.
- `v0.3 route-hint`: 살아남은 장거리 경로입니다. 핵심 경로는 `candidate value_pos -> value byte read -> proposal hint`입니다.
- 최신 route-hint 상태: h4-5t는 fallback low-channel strength sweet spot을 보정했고, h4-5u는 짧은 fallback TTL/persistence가 현재 조건에서 neutral임을 보였고, h4-5v는 route-credit separation instrumentation을 추가했으며, h4-5w는 route-credit ablation diagnostics이고, h4-5x는 credit × fallback integration ablation이며, h4-5y는 credit strength/stability calibration이고, h5-a는 persistent route-plasticity ledger와 learn/apply warmup gate이며, h5-b는 source/bucket route-credit responsibility instrumentation이고, h5-c는 key-shape fallback `hi_mult=5` / `lo_mult=10` 주변의 source-credit policy calibration이며, h5-d는 weak `joint-code-key` primary, symbolic `key-shape` fallback, explicit `noisy-route-code` stress를 비교하는 noisy / learned-like source policy diagnostics이고, h5-e는 noisy-source multi-seed / scale stability smoke이며, h5-f는 `route-code-key` identity auxiliary 자체를 약하게 만드는 learned-source stress이고, h5-g는 이 weak learned-source stress를 key/seed 축으로 확장하며, h5-h는 fallback `off`, `raw-key`, `key-shape`, `noisy-route-code` 의존성을 비교하고, h5-i는 source-credit fallback policy mode를 보정하며, h5-j는 fallback candidate-quality gap을 진단하고, h5-k는 fallback aggregation policy를 보정하며, h5-l은 source/noise-aware fallback aggregation diagnostics를 추가했고, h5-m은 그 source/noise-aware aggregation 패턴을 key/seed smoke로 확장하며, h5-n은 source-credit bad-source filter / abstain diagnostics를 추가하고, h5-o는 bad-source filtering 이후 retry-source replacement diagnostics를 추가하며, h5-p는 source-credit retry-policy calibration을 추가하고, h5-q는 `PASS as source-credit retry-policy tie-break calibration diagnostics / limited mitigation`입니다. `noisy-filter`는 `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`; `policy-source-order`는 `qacc=0.957813`, `fallback_recall=1.000000`, `retry_raw_selected=0.875000`; `policy-keyshape-prior`와 `policy-noisy-penalty/mixed`는 `retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`으로 회복했고, `fixed-keyshape`는 `qacc=0.970313`, `fallback_qacc=1.000000`의 상한입니다. NOT learned routing solved, NOT source-credit robustness solved, NOT wrong-candidate/fallback robustness solved.
- h5-r은 retry tie-break용 source-prior schedule diagnostics를 추가했습니다. 새 옵션은 `--route-source-retry-prior-mode none|static|decay|warmup`, `--route-source-retry-prior-decay`, `--route-source-retry-prior-warmup-epochs`입니다. Smoke에서 source-order는 raw-key로 회복합니다 (`qacc=0.957813`, `retry_raw_selected=0.875000`), static/decay/warmup key-shape prior는 key-shape를 선택합니다 (`qacc=0.957813`, `retry_keyshape_selected=0.875000`), noisy retry 선택은 계속 `0.000000`입니다. fixed key-shape reference는 여전히 더 높습니다 (`qacc=0.970313`, `fallback_qacc=1.000000`). 이는 source-prior schedule calibration / limited mitigation이지 learned routing solved나 robustness solved가 아닙니다.

- h5-s: source-prior handoff diagnostics를 추가했습니다. 같은 `candidate value_pos -> value byte read -> proposal hint` 경로에서 source-order, static key-shape prior, warmup-short/long, decay-fast, fixed key-shape reference를 비교합니다. Short warmup은 일부 handoff를 드러냅니다 (`retry_raw_selected=0.062500`, `retry_keyshape_selected=0.812500`). Long warmup/decay/static prior는 key-shape 선택을 유지하고 (`retry_keyshape_selected=0.875000`), noisy retry는 계속 선택되지 않습니다. qacc는 `0.957813`로 fixed key-shape `0.970313`보다 낮으므로 source-prior handoff calibration / limited mitigation으로만 읽어야 합니다.
- h5-t: retry-source evidence-quality diagnostics를 추가했습니다. 새 CSV metric은 raw-key, key-shape, noisy retry source의 source-credit mean과 reward/slash rate를 분리합니다. Smoke에서 source-order는 raw-key를 reward합니다 (`retry_raw_mean=0.222951`), static/warmup key-shape prior는 key-shape를 reward합니다 (`retry_keyshape_mean=0.222951`), noisy retry는 음수로 남습니다 (`retry_noisy_mean=-0.206811`, `retry_noisy_slashed=1.000000`). 이는 evidence-quality instrumentation이지 source-credit ranking solved가 아닙니다. raw-key와 key-shape는 선택되면 둘 다 positive credit을 받기 때문에, source-credit evidence만으로 더 좋은 symbolic retry source를 독립적으로 고르는 단계는 아직 아닙니다.
- h5-u는 candidate-quality logdet/channel/quality-score instrumentation을 추가했습니다. `route_quality_apply=none`에서 `quality-off-source-order`와 `quality-on-source-order`가 모두 `qacc=0.645313`이라 행동 변경 없이 계측만 된 것이 확인됐고, fixed raw-key와 fixed key-shape는 `qacc=0.742187` vs `0.645313`, `logdet=-5.818573` vs `-15.330912`, condition `7.050210` vs `52.270703`으로 분리됩니다. 이는 instrumentation이지 learned routing이나 robustness win이 아닙니다.
- h5-v는 첫 약한 quality 적용입니다. `route_quality_apply=source-ranking`에서 `route_quality_apply_active=1.000000`, delta `0.227710..0.250000`이 관측되고 noisy retry 선택은 `0.000000`으로 유지됩니다. 그러나 qacc는 apply-none `0.568750`에서 `0.560938`로 소폭 낮아졌으므로 weak application calibration diagnostics이지 robustness win이 아닙니다.
- h5-w는 이 약한 적용 경로의 source-quality calibration diagnostics입니다. source별 proxy/delta/qacc를 분리해 보니 raw-key proxy는 강하게 양수 (`2.277099`)이고 key-shape/noisy는 음수 (`-0.472130`, `-0.513364`)입니다. 즉 source-ranking이 raw-key를 고르고 noisy를 피하는 이유는 설명되지만, 그 선택이 qacc 개선으로 이어지지는 않습니다.
- h5-x는 proxy sign을 보정했습니다. channel-sign row가 단일 smoke에서 가장 좋았습니다 (`qacc=0.662500`, `selected_raw_qacc=0.720536`)이며 proxy-default `qacc=0.560938`보다 높습니다. h5-y는 이 channel-sign을 multi-seed/key smoke로 확장했고, 평균 qacc는 channel-sign `0.636198`, proxy-default `0.621094`, proxy-off `0.622656`입니다. h5-z는 `--route-quality-source-normalization none|center|zscore`를 추가했고, 정규화가 raw delta를 낮추는 것은 확인했지만 source 선택은 여전히 raw-key 중심입니다. h5-aa는 후보 단위 weight에 이미 correct/wrong 분리 신호가 있음을 확인했고, h5-ab는 그 신호를 후보 weight에 약하게 반영하면 qacc가 실제로 오른다는 것을 확인했습니다. h5-ac에서는 source-ranking 조합이 candidate-only를 넘지 못했습니다. h5-ad에서는 candidate-only beta를 noise/key/seed 축으로 확장했고, h5-ae에서는 `beta=2.0, cap=3.0/4.0`까지는 over-sharpen 신호 없이 qacc가 계속 상승했습니다. h5-af에서는 `keys=64,128,256`까지 확장해 `b2p00-cap3`이 평균 qacc `0.869965`로 가장 안정적인 regression setting임을 확인했습니다. h5-ag에서는 `beta=3.0`까지도 over-sharpen collapse가 나오지 않았고, h5-ah에서는 `beta=5.0, cap=6/8`까지 qacc가 `0.952669`로 더 올랐습니다. h5-ai에서는 `beta=8.0, cap=8/12`까지 qacc가 `0.957813`로 더 올라갔고, h5-aj에서는 `beta=12.0, cap=12/16`이 `0.958008`로 아주 약간 더 높지만 concentration 비용이 큽니다. h5-ak 5-seed guardrail에서는 `beta=8, cap=8`이 더 안전한 설정으로 정리됐고, h5-al에서는 이 설정을 candidate-weight-only default로 확인했습니다. h5-am에서는 feature-score basis가 현재 base-weight default를 대체하지 못함을 확인했습니다. h5-an/h5-ao/h5-ap에서는 hybrid basis가 base qacc를 유지하면서 concentration을 낮출 수 있음을 확인했고, h5-aq/h5-ar에서는 concentration-aware auto switching이 base qacc를 유지하면서 threshold별 concentration tradeoff를 드러냈습니다. h5-as는 auto trigger를 factor와 top-share로 분해했고, h5-at는 factor/top/any trigger policy를 비교했으며, h5-au는 factor-only threshold를 더 촘촘히 보정했습니다. 현재 결론은 `basis=base`가 기본값이고, `hybrid-m0p25`가 lower-concentration safe alternative이며, factor-only auto는 threshold regime을 설명하는 diagnostic이라는 것입니다.

## 중요한 아키텍처 결론

### 1. Remote node as neighbor: NO-GO

`jump-neighbors` 계열은 active long-distance edge를 만들 수는 있었지만 fixture regression 또는 no-op 경계로 갔습니다. 현재 문서와 실험에서는 이 경로를 promotion 대상이 아니라 diagnostic/default-off branch로 유지합니다.

### 2. Remote value as proposal hint: WORKS

route-hint 계열은 다음 경로를 유지합니다.

```text
candidate value_pos
-> value byte read
-> proposal hint
```

oracle, parsed value-position, exact KV, hashed candidate, route-code identity, fallback source까지 이 경로가 이어졌습니다.

### 3. Prediction code와 route identity code는 다릅니다

`joint-code-key`는 plumbing은 통과했지만 key identity를 충분히 보존하지 못했습니다.

```text
key_region_joint_decode_acc = 0.093750
joint_signature_collision_rate = 0.625000
```

별도 route-code identity auxiliary를 넣으면 32-key route-code run에서 query accuracy/recall/top1이 `1.000000`까지 회복됩니다. 현재 결론은 **prediction joint-code is not a routing identity-code**입니다.

### 4. Retrieval과 state convergence는 별도 병목입니다

128-key stress에서는 candidate retrieval, top1, route decode가 모두 `1.000000`이어도 query accuracy가 낮아질 수 있었습니다. `lambda_route`와 margin-adaptive strength가 이를 회복했기 때문에, 후보 찾기와 value를 state로 밀어 넣는 dynamics margin은 별도 문제입니다.

### 5. Low-confidence failure는 둘로 나뉩니다

```text
preserve-correct:
  정답 후보는 있음 -> ranking / aggregation 문제

remove-correct:
  정답 후보가 없음 -> fallback / abstain / secondary source 문제
```

이 구분은 fallback, route-credit, future route plasticity 설계의 기준입니다.

## 최근 h4-5 계열 요약

- h4-5g adaptive strength: 128-key correct-candidate setting에서 fixed strong보다 낮은 평균 strength로 qacc를 거의 회복했습니다.
- h4-5h/i/j: confidence guard, value-support confidence, scorer-agreement confidence는 wrong hint strength를 낮추는 instrumentation으로는 작동하지만 wrong-candidate robustness는 해결하지 못했습니다.
- h4-5k: confidence-gated aggregation은 high/low confidence split을 만들고 limited mitigation을 보였지만 robustness solved는 아닙니다.
- h4-5l/m: low-confidence failure를 preserve-correct aggregation/ranking 문제와 remove-correct candidate availability 문제로 분리했습니다.
- h4-5n: key-shape fallback은 remove-correct candidate availability를 회복했지만 fallback-used qacc는 낮았습니다.
- h4-5o: projected delta는 preserve-correct에 제한적 개선을 보였지만 fallback integration을 해결하지 못했습니다.
- h4-5p: fallback-only strength multiplier가 fallback qacc를 실제로 움직였습니다.
- h4-5q: fallback adaptive strength는 fixed strong보다 낮은 평균 strength로 일부 개선했지만 fixed strong을 대체하지는 못했습니다.
- h4-5r/s/t: fallback-used query는 low nibble 쪽이 더 큰 병목이며, `hi_mult=5`, `lo_mult=7.5..10` 근처에 sweet spot이 있습니다.
- h4-5u: 짧은 fallback persistence / TTL 계측은 정상 연결됐지만 qacc 개선은 neutral입니다.
- h4-5v: value-position route credit은 correct/wrong candidate credit을 분리합니다 (`credit_gap = 1.110268`) 그리고 qacc를 아주 작게 움직입니다 (`0.845312 -> 0.850000`). 이는 route-credit separation instrumentation / tiny mitigation이지 wrong-candidate robustness solved나 learned routing solved가 아닙니다. 다음 route-credit 작업은 score weight, reward/slash 비율, decay, clip, value-pos 대비 query-value edge credit, 그리고 fallback low-channel strength sweet spot과의 조합 ablation입니다.
- h4-5w: route-credit ablation diagnostics와 `--route-credit-mode query-value`를 추가했습니다. Smoke에서 value-pos credit은 유지되고, query-value edge credit도 동작합니다 (`query-value-probe` gap `0.598951`). credit + low-channel fallback 조합은 fallback subset을 움직입니다 (`fallback_qacc 0.688889 -> 0.777778`). 이는 ablation instrumentation / limited mitigation이지 robustness solved가 아닙니다.
- h4-5x: credit × fallback integration factorial을 추가했습니다. true `--route-credit-mode off`, `value-pos`, `query-value`를 key-shape fallback `hi_mult=5`, `lo_mult=7.5/10/15`, preserve/remove corruption과 교차합니다. Smoke에서는 preserve-correct qacc는 중립이지만 credit gap이 생기고, remove-correct qacc가 `lo=7.5/10`에서 `0.912500 -> 0.925000`으로 움직입니다. 이는 integration diagnostics / limited mitigation입니다.
- h4-5y: credit strength/stability calibration을 추가했습니다. Smoke는 active `value-pos/query-value` credit의 score weight와 slash 강도, corruption rate를 대각선 셀로 점검하고 true `off` baseline을 포함합니다. Query-value credit은 preserve rows에서 강한 gap을 유지하고, remove rows는 fallback diagnostics를 채웁니다. 이는 calibration diagnostics / limited mitigation이지 robustness solved가 아닙니다.
- h5-a: `--route-plasticity-ledger` persistent ledger와 `--route-credit-learn-after-epoch` / `--route-credit-apply-after-epoch` warmup gate를 추가했습니다. Smoke는 value-bearing path가 유지되는지, candidate lookup/read distance가 채워지는지, `routing_trigger_rate`와 `active_jump_rate`가 `0.000000`인지 확인합니다. 이는 route-plasticity instrumentation이지 learned routing solved나 wrong-candidate robustness solved가 아닙니다.
- h5-b: `--route-source-credit-learning` source/bucket credit을 추가했습니다. Smoke는 remove-correct에서 fallback source가 primary보다 높은 책임 신호를 얻는지 확인합니다 (`source gap = 0.276563`, fallback mean `0.300000`, primary mean `0.023438`, primary slashed rate `0.281250`, fallback rewarded rate `1.000000`). qacc는 neutral이므로 source/bucket responsibility instrumentation이지 fallback robustness solved나 learned routing solved가 아닙니다.
- h5-c: `--route-source-credit-learning`, `--route-source-credit-score-weight`, `--route-source-credit-eta-reward`, `--route-source-credit-eta-slash`, `--route-plasticity-ledger`를 더해 source-credit policy calibration을 추가했습니다. Smoke는 remove-correct corruption `0.25`와 key-shape fallback `hi_mult=5` / `lo_mult=10`을 고정한 채 learn-only, ranking, ranking+strength, ledger row를 분리합니다. Learn-only는 source gap `0.276563`을 만들지만 적용하지 않고, ranking-strength는 그 gap을 `0.553125`로 키우며, ledger row는 persistent state만 채워서 ledger size `59.000000`, mean abs credit `0.711864`를 보입니다. 이건 policy instrumentation이지 robustness solved가 아닙니다.
- h5-d: remove-correct corruption `0.25`에서 noisy / learned-like source policy diagnostics를 추가했습니다. Smoke는 두 branch를 봅니다. 하나는 weak `joint-code-key` primary와 `key-shape` fallback이고, 다른 하나는 `--route-noisy-source-rate 1.0`의 명시적 `noisy-route-code` stress입니다. `route_hint_candidate_lookup_count > 0`, `route_hint_value_read_distance_mean > 0`, `routing_trigger_rate = 0.000000`, `active_jump_rate = 0.000000`를 유지하면서, 유용한 key-shape fallback에는 positive source gap이 생기고 나쁜 noisy candidate에는 negative noisy-source credit/slash가 생기는지 확인합니다. 이는 source-quality separation instrumentation이지 robustness solved가 아닙니다.
- h5-e: noisy-source multi-seed / scale stability diagnostics를 추가했습니다. Smoke는 key count `32/64`, seed `1/2`, noisy rate `0.50/1.00`을 교차합니다. Weak joint branch는 key-shape fallback positive source gap을 유지하고, noisy branch는 negative noisy-candidate credit과 noisy slash diagnostic을 유지합니다. Fully noisy row에서는 source gap도 음수입니다. 이는 stability instrumentation이지 source-credit robustness solved가 아닙니다.
- h5-f: `--route-code-key-region-keep-prob`와 `--route-code-aux-noise-rate`로 `route-code-key` identity auxiliary 자체를 약하게 만드는 learned-source stress diagnostics를 추가했습니다. Smoke는 key count `32/64`, seed `1/2`에서 clean full-supervision branch와 weak branch(`keep=0.25`, `aux_noise=0.75`)를 비교합니다. Clean row는 decode/primary recall/qacc `1.000000`을 유지하고, weak row는 route-code decode와 primary recall이 낮아지며 key-shape fallback, source-credit gap, primary slash / fallback reward signal이 켜집니다. 이는 weaker learned-source instrumentation이지 learned routing solved가 아닙니다.
- h5-g: weak learned-source multi-seed / scale stability diagnostics를 추가했습니다. Smoke는 key count `64/128`, seed `1/2`, clean/mid/weak route-code weakening arm을 교차하고, weak fallback-off와 key-shape fallback + source-credit `ranking-strength` + ledger arm을 비교합니다. 평균 readout은 clean-off qacc/decode/recall `1.000000`, mid-off qacc `0.970313`, decode `0.630937`, recall `0.994531`, weak-off qacc `0.185938`, decode `0.000000`, recall `0.285938`, weak fallback-ledger qacc `0.460156`, fallback_used `0.714063`입니다. source gap/slash/reward도 켜집니다. 이는 scale/stability instrumentation이지 source-credit robustness solved가 아닙니다.
- h5-h: fallback-source dependence / stability diagnostics를 추가했습니다. Smoke는 weak route-code source를 고정하고 fallback `off`, exact symbolic `raw-key`, source-credit `ranking-strength`가 붙은 symbolic `key-shape`, bad `noisy-route-code`를 비교합니다. 평균 readout은 fallback-off qacc `0.213281`, raw-key qacc `0.650000` 및 fallback_recall `1.000000`, key-shape qacc `0.437500` 및 source_gap `0.299223`, noisy-route-code qacc `0.173437`, source_gap `-0.207562`, noisy_mean `-0.201440`, noisy_slash `0.979234`입니다. 이는 symbolic fallback dependence와 bad-source diagnostics를 분리하는 계측이지 learned routing solved가 아닙니다.
- h5-i: source-credit fallback-policy calibration diagnostics를 추가했습니다. Smoke는 weak route-code source를 고정하고 `key-shape` learn-only, ranking, strength, ranking-strength apply mode를 `raw-key` symbolic ceiling 및 `noisy-route-code` negative control과 비교합니다. 평균 readout은 off-control qacc `0.206250`, raw-key qacc `0.661328` 및 fallback_recall `1.000000`, key-shape source_gap `0.299047`, ranking selected_fallback `0.660209`, strength mean `1.402324`, noisy-route-code source_gap `-0.182191`, noisy_mean `-0.189995`, noisy_slash `0.976094`, fallback_recall `0.000000`입니다. 이는 policy calibration instrumentation이지 fallback robustness나 learned routing solved가 아닙니다.
- h5-j: fallback candidate-quality gap diagnostics를 추가했습니다. Smoke는 `raw-key`와 `key-shape` fallback을 `vote`, `weighted-vote`, source-credit `ranking-strength` 조건에서 비교합니다. 두 fallback source 모두 후보는 회복하지만 top1은 낮습니다 (`0.031250`, 평균 rank `2.500000`). Plain vote는 약하고 (`raw` qacc `0.225000`, `key-shape` qacc `0.200000`), weighted-vote는 correct value support를 올리고 entropy를 낮춰 둘 다 거의 풉니다 (`raw` qacc `0.942188`, `key-shape` qacc `0.960938`). 즉 현재 병목은 fallback recall 단독이 아니라 fallback aggregation quality입니다.
- h5-k: fallback aggregation policy calibration을 추가했습니다. Smoke는 `raw-key`와 `key-shape` fallback에서 `top1`, `vote`, `weighted-vote`, confidence-gated policy를 비교합니다. Plain vote는 약한 정책입니다 (`raw` qacc `0.328125`, `key-shape` qacc `0.204688`). 반면 이 controlled fallback 조건에서는 top1과 weighted-vote가 강합니다 (`top1` qacc는 둘 다 `0.906250`, weighted qacc는 `0.943750` / `0.956250`). Confidence-gated low=`vote`, high=`weighted-vote`는 vote 약점을 물려받고, low/high 모두 `weighted-vote`일 때 weighted baseline을 보존합니다.
- h5-l: source/noise-aware fallback aggregation diagnostics를 추가했습니다. Smoke는 symbolic fallback source에는 weighted aggregation + source-credit policy를 적용하고, noisy fallback은 negative control로 유지합니다. Raw-key는 vote qacc `0.401563`에서 source-aware qacc `0.965625`로, key-shape는 `0.218750`에서 `0.964063`으로 올라갑니다. Noisy fallback은 여전히 해결되지 않지만 (`fallback_recall=0.000000`), negative source/noisy credit으로 감지됩니다 (`source_gap=-0.140244`, noisy slash `1.000000`) 그리고 strength amplification은 없습니다 (`strength_mean=1.000000`).
- h5-m: source/noise-aware aggregation scale stability diagnostics를 추가했습니다. Smoke는 key count `64/128`, seed `1/2`를 교차하고 `raw-key`, `key-shape`, `noisy-route-code` fallback에서 vote와 source-aware weighted aggregation을 비교합니다. 평균적으로 raw-key는 qacc `0.378516 -> 0.925391`, key-shape는 `0.275781 -> 0.932813`으로 개선되고 둘 다 `fallback_recall=1.000000`을 유지합니다. Noisy branch는 여전히 해결되지 않지만 (`fallback_recall=0.000000`), negative source/noisy credit으로 감지됩니다 (`source_gap=-0.268339`, noisy slash `1.000000`) 그리고 strength amplification은 없습니다 (`strength_mean=1.000000`).
- h5-n: bad-source filtering / abstain diagnostics를 추가했습니다. 새 `--route-source-filter-mode negative-credit`는 source credit이 `--route-source-filter-threshold`보다 낮은 candidate를 제거합니다. Smoke에서 symbolic fallback은 계속 사용 가능합니다 (`raw-filter` qacc `0.951562`, `keyshape-filter` qacc `0.965625`). 반면 noisy fallback은 강하게 필터링됩니다 (`source_filter_filtered=0.935065`, `source_filter_abstain=0.875000`). 하지만 noisy qacc는 개선되지 않습니다 (`0.185937 -> 0.100000`). 따라서 이는 bad-source abstention instrumentation이지 fallback robustness solved가 아닙니다.
- h5-o: retry-source replacement diagnostics를 추가했습니다. 새 `--route-source-retry-source`는 bad/noisy fallback 후보가 negative-credit filter로 제거된 뒤 secondary source 후보를 같은 value-bearing route-hint path에 넣습니다. Smoke에서 noisy-filter baseline은 회복 없이 abstain합니다 (`qacc=0.103125`, `fallback_recall=0.000000`, `source_filter_abstain=0.876562`). 반면 symbolic retry를 붙이면 recall과 qacc가 회복됩니다 (`retry-raw` qacc `0.950000`, `fallback_recall=1.000000`; `retry-keyshape` qacc `0.962500`, `fallback_recall=1.000000`). 이는 retry/replacement instrumentation이지 learned routing이나 fallback robustness solved가 아닙니다.
- h5-p: source-credit retry-policy calibration을 추가했습니다. 새 `--route-source-retry-policy source-credit`, `--route-source-retry-candidates`, `--route-source-retry-per-source-limit`는 bad/noisy source filtering 이후 여러 retry source 후보를 source-credit 순서로 넣습니다. Smoke에서 noisy-filter baseline은 회복 없이 abstain합니다 (`qacc=0.103125`, `fallback_recall=0.000000`). fixed symbolic retry는 회복합니다 (`fixed-raw` qacc `0.957813`, `fixed-keyshape` qacc `0.970313`). source-credit mixed policy도 noisy retry 선택 없이 회복합니다 (`policy-mixed` qacc `0.957813`, `retry_noisy_selected=0.000000`). 이는 retry policy selection 배관이지 learned routing이나 fallback robustness solved가 아닙니다.
- h5-q: source-credit retry-policy tie-break calibration을 추가했고 `PASS` as source-credit retry-policy tie-break calibration diagnostics / limited mitigation입니다. `noisy-filter`는 `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`이고, `policy-source-order`는 `qacc=0.957813`, `fallback_recall=1.000000`, `retry_raw_selected=0.875000`으로 회복합니다. `policy-keyshape-prior`와 `policy-noisy-penalty/mixed`도 `retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`으로 회복하고, `fixed-keyshape`는 `qacc=0.970313`, `fallback_qacc=1.000000`의 상한입니다. 이는 learned routing solved도, source-credit robustness solved도, wrong-candidate/fallback robustness solved도 아닙니다.
- h5-r: source-prior schedule diagnostics를 추가했습니다. `none/static/decay/warmup` prior mode를 비교하고, 같은 `candidate value_pos -> value byte read -> proposal hint` 경로를 유지합니다. Source-order는 raw-key를 선택하고, static/decay/warmup key-shape prior는 key-shape를 선택하며, noisy retry는 선택하지 않습니다. qacc는 `0.957813`으로 fixed key-shape reference `0.970313` 아래에 머물기 때문에 prior schedule calibration / limited mitigation으로만 읽어야 합니다.

## 빌드

```bash
cmake -S . -B build
cmake --build build -j
```

## 실행 예시

`v0.1`은 기본적으로 CSV를 stdout에 씁니다.

```bash
./build/dmv01 --cycles 100 --N 256 > results/v01_smoke.csv
```

파일로 직접 저장할 수도 있습니다.

```bash
./build/dmv01 --cycles 100 --N 256 --csv results/v01_smoke.csv
```

`v0.2-pre` / `v0.2-b` 예시:

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --lambda-v 0 \
  --csv results/counter_lv0.csv
```

## Baseline 해석

- `counter` with `lambda_v = 0`은 첫 locked correctness gate이며 강하게 성공해야 합니다.
- `repeating-text`는 초기/중기 학습에서 `field_byte_acc`가 `oracle1_acc`보다 낮지만 `byte_acc`보다 분명히 높아야 합니다.
- `v0.2-b` 기본 weak-coupling run은 `repeating-text`에서 대략 `field/joint/byte = 0.687500/0.687500/0.687500` 근처에 도달하고 `counter` gate는 `1.000000/1.000000/1.000000`을 유지합니다.
- 5-seed 기본 weak-coupling regression은 `counter byte/field/joint = 0.999688/1.000000/1.000000`, `repeating-text byte/field/joint = 0.685625/0.681094/0.685703` 평균을 기록합니다.
- 같은 5-seed `repeating-text` regression에서 weak coupling은 no-coupling control 대비 평균 `byte_acc +0.177578` 개선을 보입니다.

## 대표 실험 스크립트

전체 실험 목록은 [README.md](README.md)와 [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md)를 참고하세요. 주요 helper는 아래와 같습니다.

### v0.2 / v0.2-b

- `experiments/run_v02_counter.sh`
- `experiments/run_v02_ablation.sh`
- `experiments/run_v02_repeating.sh`
- `experiments/run_v02b_tuned.sh`
- `experiments/run_v02b_counter_compare.sh`
- `experiments/run_v02b_repeating_compare.sh`
- `experiments/run_v02b_counter_multiseed_compare.sh`
- `experiments/run_v02b_repeating_multiseed_compare.sh`

### v0.3 static routing diagnostics

- `experiments/run_v03_routing_probe.sh`
- `experiments/run_v03_routing_fixture_compare.sh`
- `experiments/run_v03_static_routing_compare.sh`
- `experiments/run_v03_gap_gate_ablation.sh`
- `experiments/run_v03_gate_diagnostics.sh`
- `experiments/run_v03_confidence_gate_ablation.sh`
- `experiments/run_v03_confidence_acceptance_ablation.sh`
- `experiments/run_v03_input_byte_jump_compare.sh`
- `experiments/run_v03_route_key_diagnostics.sh`
- `experiments/run_v03_rejection_diagnostics.sh`

### v0.3 value-bearing route-hint

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
- `experiments/run_v05_route_source_credit_retry_source.sh`
- `experiments/run_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/run_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/run_v05_route_source_credit_retry_policy.sh`
- `experiments/run_v05_route_candidate_quality_logdet.sh`
- `experiments/run_v05_route_quality_application.sh`
- `experiments/run_v05_route_quality_proxy_calibration.sh`
- `experiments/run_v05_route_quality_source_norm.sh`
- `experiments/run_v05_route_quality_candidate_apply.sh`
- `experiments/run_v05_route_quality_candidate_scale.sh`
- `experiments/run_v05_route_quality_candidate_saturation.sh`
- `experiments/run_v05_route_quality_candidate_boundary.sh`
- `experiments/run_v05_route_quality_candidate_high_beta.sh`
- `experiments/run_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/run_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/run_v05_route_quality_candidate_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_default.sh`
- `experiments/run_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/run_v05_route_quality_candidate_basis_policy.sh`
- `experiments/run_v05_route_quality_candidate_preset_regression.sh`
- `experiments/run_v05_route_quality_candidate_preset_policy.sh`
- `experiments/run_v05_route_quality_candidate_regression.sh`
- `experiments/run_v05_route_quality_candidate_level.sh`
- `experiments/run_v05_route_quality_candidate_composition.sh`

## 대표 smoke test

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
- `experiments/test_v05_route_source_credit_retry_source.sh`
- `experiments/test_v05_route_source_credit_retry_tiebreak.sh`
- `experiments/test_v05_route_source_credit_retry_prior_schedule.sh`
- `experiments/test_v05_route_source_credit_retry_policy.sh`
- `experiments/test_v05_route_candidate_quality_logdet.sh`
- `experiments/test_v05_route_quality_application.sh`
- `experiments/test_v05_route_quality_proxy_calibration.sh`
- `experiments/test_v05_route_quality_source_calibration.sh`
- `experiments/test_v05_route_quality_source_norm.sh`
- `experiments/test_v05_route_quality_channel_scale.sh`
- `experiments/test_v05_route_quality_candidate_level.sh`
- `experiments/test_v05_route_quality_candidate_apply.sh`
- `experiments/test_v05_route_quality_candidate_scale.sh`
- `experiments/test_v05_route_quality_candidate_saturation.sh`
- `experiments/test_v05_route_quality_candidate_boundary.sh`
- `experiments/test_v05_route_quality_candidate_high_beta.sh`
- `experiments/test_v05_route_quality_candidate_extreme_beta.sh`
- `experiments/test_v05_route_quality_candidate_ultra_beta.sh`
- `experiments/test_v05_route_quality_candidate_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_default.sh`
- `experiments/test_v05_route_quality_candidate_feature_calibration.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_basis.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_hybrid_promotion.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy.sh`
- `experiments/test_v05_route_quality_candidate_basis_policy_scale.sh`
- `experiments/test_v05_route_quality_candidate_basis_guardrail.sh`
- `experiments/test_v05_route_quality_candidate_preset.sh`
- `experiments/test_v05_route_quality_candidate_preset_regression.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy.sh`
- `experiments/test_v05_route_quality_candidate_preset_policy_scale.sh`
- `experiments/test_v05_route_quality_closure.sh`
- `experiments/test_v06_route_memory_span_boundary.sh`
- `experiments/test_v06_route_memory_span_exact.sh`
- `experiments/test_v06_route_memory_span_exact_scale.sh`
- `experiments/test_v06_route_memory_span_hash.sh`
- `experiments/test_v06_route_memory_span_hash_scale.sh`
- `experiments/test_v05_route_quality_candidate_auto_basis.sh`
- `experiments/test_v05_route_quality_candidate_auto_threshold.sh`
- `experiments/test_v05_route_quality_candidate_auto_trigger.sh`
- `experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh`
- `experiments/test_v05_route_quality_candidate_composition.sh`
- `experiments/test_v05_route_quality_candidate_regression.sh`

## 핵심 문서

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
- [v0.6 / h6 Route Memory](docs/V06_ROUTE_MEMORY.md)
- [Roadmap](docs/ROADMAP.md)

## 다음 연구 방향

- h5-au/h5-av/h5-aw 이후 기본값은 `candidate-weight + base basis`로 유지하고, `hybrid-m0p25`는 concentration을 낮추는 안전 대안으로 남깁니다.
- factor-only `auto`는 당분간 diagnostic-only로 유지합니다. 다음 개선은 auto threshold를 더 키우기보다, per-key/per-noise 조건에서 base와 hybrid를 언제 바꿀지 분리하는 쪽이 안전합니다.
- candidate-quality weighting은 현재 가장 강한 route-quality 적용 경로입니다. 다만 learned routing solved나 robustness solved가 아니므로, noisy/weak learned-like source에서 qacc와 wrong-strength가 같이 안정되는지 계속 봐야 합니다.
- source-credit은 좋은/나쁜 source responsibility signal로 유용하지만, 현재 성능 기본축은 source-ranking보다 candidate-weighting 쪽입니다. source-credit은 candidate-quality default와 결합한 보조 신호로 유지합니다.
- synthetic fixture를 넘어 real long-context / chunk-level task와 외부 baseline 비교로 확장하기 전까지는 Transformer replacement나 long-context retrieval solved claim을 하지 않습니다.
