# discrete-local-energy

Deterministic C++17 reference code for a staged discrete local-energy research prototype.

Korean README: [README.ko.md](README.ko.md)

Latest completed checkpoint:

- Branch `codex/route-memory-local-energy-policy` is current through the h10-l source-verified learned chunk-quality scorer checkpoint and the h11-b PC RouteLM artifact verification checkpoint.
- h10-j is closed as the latest route-memory teacher-source gate. The new verifier checks teacher source artifact, label export, teacher identity, teacher policy, license, provenance, and sha256 hash-chain mechanics. Default/no-env remains blocked; a supplied external-label CSV can import labels but cannot enable distillation without source evidence; a supplied local source fixture can verify mechanics but stays `real_teacher_source_verified=0`, `distillation_ready=0`, `default_promotion=0`. Any local `file://` URI, including one outside `results/`, cannot become real teacher-source evidence by declaration flags alone.
- h10-k is closed as the latest local learned chunk-quality scorer gate. It trains a deterministic `linear-contrastive-chunk-v1` scorer from the h10-f local teacher-label harness, rewards correct chunk evidence, slashes coherent wrong/noisy/missing features, and separates reward from negative actions in the smoke (`learned_score_gap=3.064325`, `coherent_wrong_negative_rate=1.000000`). Because the labels are still `local-teacher-harness`, it keeps `external_label_source_ready=0`, `distillation_ready=0`, and `default_promotion=0`.
- h10-l is closed as the source-verified learned scorer binding gate. It requires learned chunk-quality feature labels to be supplied, non-local, teacher-ID linked to the source evidence, row-bound to external teacher-label rows via `source_uri` and `provenance_hash`, and backed by h10-j real teacher-source verification before `source_verified_learned_chunk_scorer_ready=1`. Default/local labels, relabeled local labels without row provenance, and mismatched external-label rows remain blocked (`source_verified_feature_labels_ready=0`, `source_verified_learned_chunk_scorer_ready=0`). A supplied local source fixture can link feature labels but still blocks on `real_teacher_source_verified=0`.
- h7 route-memory closure is current through h10-l. The closure still keeps `default_promotion=0`, `status=diagnostic-only`, `routing_trigger_rate=0`, and `active_jump_rate=0`. The positive chunk-credit and learned local scorer results are therefore guarded diagnostic route-memory policies, not default sparse-routing policies.
- v08-l is closed as the current external-benchmark evidence boundary. Adapter, evidence schema, supplied CSV import, comparison deltas, real-evidence format, local artifact hash verification, benchmark authenticity, execution-output, independent attestation, attestor identity, and final-review mechanics are all covered. Local/fixture rows remain non-publishable with `real_external_benchmark_verified=0`; v08-e publishability requires v08-l real verification.
- h9-g is closed as the current GPU/backend evidence boundary. CPU remains canonical, HIP remains optional/environment-dependent, and fixture timing evidence keeps `gpu_speedup_claim=deferred`.
- h11-b is closed as the current PC RouteLM / NLG artifact boundary. The verifier checks generator, route-memory, scorer, decoder, NLG-smoke, benchmark, license, and provenance artifact hashes. A supplied local artifact fixture can verify the chain mechanics with `prototype_artifact_chain_verified=1`, but local `results/` fixture URIs and declaration flags still keep `real_pc_routelm_artifact_verified=0`.
- Latest verified command stack: `bash -n experiments/*.sh`, `git diff --check`, focused h10-k/h10-l scorer/distillation tests, focused h11-b verifier/import tests, h11 readiness/import tests, and `bash experiments/test_v09_gpu_backend_closure.sh`.

Current open blockers:

- Real external teacher-label source evidence must pass the h10-j verifier before teacher-distilled chunk retrieval can be claimed.
- Real external benchmark source/result/review evidence must pass the v08-f through v08-l chain before any v0.8 external comparison can be published.
- Real HIP-backed measurements must replace fixture timing before any GPU speedup claim.
- A real PC RouteLM/NLG artifact smoke remains future work; h11-b is an artifact/provenance gate, not a working product claim.

Current headline:

- The project is now best described as a discrete local-energy learner plus a value-bearing route-hint memory research prototype. Through v0.3, the strongest routing conclusion is that long-range information should enter as `candidate value_pos -> value byte read -> proposal hint`, not as remote-neighbor replacement.
- This is not yet learned sparse routing, long-context retrieval solved, wrong-candidate robustness solved, or a Transformer replacement claim. The current live path is the `candidate value_pos -> value byte read -> proposal hint` route-hint path, and jump-neighbor replacement stays no-go/default-off/diagnostic-only.
- Latest route-hint status: h4-5t calibrated the fallback low-channel strength sweet spot, h4-5u showed short fallback TTL/persistence is neutral, h4-5v added route-credit separation instrumentation with only a tiny qacc mitigation, h4-5w is the route-credit ablation diagnostics sweep, h4-5x is the credit × fallback integration ablation, h4-5y is the credit strength/stability calibration sweep, h5-a adds a persistent route-plasticity ledger plus learn/apply warmup gates, h5-b adds source/bucket route-credit responsibility instrumentation, h5-c adds source-credit policy calibration around key-shape fallback `hi_mult=5` / `lo_mult=10`, h5-d adds noisy / learned-like source policy diagnostics across weak `joint-code-key` primary, symbolic `key-shape` fallback, and explicit `noisy-route-code` stress, h5-e adds noisy-source multi-seed / scale stability smoke, h5-f weakens the `route-code-key` identity auxiliary itself, h5-g scales that weak learned-source stress over key/seed arms, h5-h compares fallback-source dependence across `off`, `raw-key`, `key-shape`, and `noisy-route-code`, h5-i calibrates source-credit fallback policy modes, h5-j diagnoses fallback candidate-quality gaps, h5-k calibrates fallback aggregation policy, h5-l adds source/noise-aware fallback aggregation diagnostics, h5-m scales that source/noise-aware aggregation pattern over key/seed smoke arms, h5-n adds source-credit bad-source filter / abstain diagnostics, h5-o adds retry-source replacement after bad-source filtering, h5-p adds source-credit retry-policy calibration, and h5-q passes as source-credit retry-policy tie-break calibration diagnostics / limited mitigation: `noisy-filter` stays at `qacc=0.103125`, `fallback_recall=0.000000`, `noisy_slashed=1.000000`, `source_retry_used=0.000000`; `policy-source-order`, `policy-keyshape-prior`, and `policy-noisy-penalty/mixed` all recover at `qacc=0.957813`, `fallback_recall=1.000000`, with `retry_noisy_selected=0.000000`; `fixed-keyshape` remains the upper bound at `qacc=0.970313`, `fallback_qacc=1.000000`. NOT learned routing solved, NOT source-credit robustness solved, NOT wrong-candidate/fallback robustness solved.
- h5-r adds source-prior schedule diagnostics for retry tie-breaks via `--route-source-retry-prior-mode none|static|decay|warmup`, `--route-source-retry-prior-decay`, and `--route-source-retry-prior-warmup-epochs`. The smoke keeps noisy retry selection at `0.000000`: source-order recovers through raw-key (`qacc=0.957813`, `retry_raw_selected=0.875000`), while static/decay/warmup key-shape priors recover through key-shape (`qacc=0.957813`, `retry_keyshape_selected=0.875000`). The fixed key-shape reference remains higher (`qacc=0.970313`, `fallback_qacc=1.000000`), so this is prior-schedule calibration / limited mitigation, not learned routing or robustness solved.
- h5-u passes as candidate-quality logdet/channel/quality-score instrumentation, h5-v passes as weak quality source-ranking application diagnostics / neutral-to-slight-regression, h5-w passes as source-quality calibration diagnostics, h5-x passes as proxy weight/sign calibration diagnostics / single-smoke limited mitigation, h5-y passes as channel-sign multi-seed/scale stability diagnostics / weak limited mitigation, h5-z passes as source-normalization instrumentation / neutral diagnostics, h5-aa passes as candidate-level quality diagnostics / actionable split, h5-ab passes as weak bounded candidate-level quality application / limited mitigation, h5-ac passes as candidate-weight composition diagnostics / limited mitigation, h5-ad passes as candidate-only beta/noise scale diagnostics / limited mitigation, h5-ae passes as candidate-weight saturation/cap diagnostics / limited mitigation, h5-af passes as candidate-quality best-setting scale regression diagnostics / limited mitigation, h5-ag passes as candidate-quality over-sharpen boundary diagnostics / limited mitigation, h5-ah passes as high-beta candidate-quality boundary diagnostics / limited mitigation, h5-ai passes as extreme-beta candidate-quality boundary diagnostics / limited mitigation, h5-aj passes as ultra-beta candidate-quality plateau/boundary diagnostics / limited mitigation, h5-ak passes as candidate-quality guardrail selection diagnostics, h5-al passes as candidate-quality safe-default application diagnostics / limited mitigation, h5-am passes as candidate-feature basis calibration diagnostics, h5-an passes as hybrid candidate-basis calibration diagnostics / lower-concentration limited mitigation, h5-ao passes as hybrid candidate-basis guardrail scale diagnostics / lower-concentration limited mitigation, h5-ap passes as hybrid candidate-basis promotion check / safe alternative diagnostics, h5-aq passes as concentration-aware candidate-basis switching diagnostics / safe alternative instrumentation, h5-ar passes as auto-threshold calibration diagnostics / safe alternative instrumentation, h5-as passes as auto-trigger decomposition diagnostics, h5-at passes as auto-trigger policy ablation diagnostics, and h5-au passes as factor-trigger threshold refinement diagnostics. `route_quality_apply=source-ranking` activates a soft bounded source-ranking delta while keeping noisy retry selection at `0.000000`; `route_quality_apply=candidate-weight` applies a bounded relative candidate-weight factor without changing route strength; `route_quality_apply=source-candidate` combines both. In h5-ak (`keys=64,128,256`, seeds `1..5`, noisy source rates `0.10,0.25,0.50`), `beta=8, cap=8` is the safer guardrail setting: aggregate qacc is `0.885747` versus `0.885573` for `beta=12, cap=12`. h5-al then checks the safe setting as a default application arm over `keys=64,128,256`, seeds `1..3`, and noisy rates `0.10,0.25,0.50`: `candidate-default` reaches qacc `0.886429`, versus `proxy-off` `0.646962` and `source-candidate-default` `0.884896`. h5-am adds `--route-quality-candidate-weight-basis base|quality-score`; the quality-score basis is wired but lower than the base default (`feature-margin qacc=0.800000` vs `base-default qacc=0.837630`). h5-an adds `hybrid` basis with `--route-quality-candidate-weight-basis-mix`; h5-ao/h5-ap scale the comparison. h5-aq through h5-au add and dissect `--route-quality-candidate-weight-basis auto` plus concentration thresholds. h5-au shows factor-trigger thresholds are quantized: `5.6/5.8` are broad (`auto_hybrid_rate=0.875304`, `factor_gap=3.241454`, `qacc=0.886328`), `6.0/6.2` are balanced (`auto_hybrid_rate=0.315668`, `factor_gap=3.471377`, `qacc=0.886328`), and `6.4` is base-like (`auto_hybrid_rate=0.000000`, `factor_gap=3.596599`, `qacc=0.886458`). The safe default remains `basis=base`; `hybrid-m0p25` remains the cleaner lower-concentration alternative, and factor-only auto stays diagnostic.

Current calibrated route-quality default:

- Keep `--route-quality-apply candidate-weight` on the value-bearing route-hint path only; do not use quality features to revive jump-neighbor topology replacement.
- Keep `--route-quality-candidate-weight-basis base` as the default. It remains the best qacc default in the latest h5-au threshold refinement (`base-default qacc=0.886458`).
- Use `hybrid-m0p25` as the safer lower-concentration alternative when factor concentration matters: it keeps qacc essentially tied (`0.886545`) while lowering `factor_gap` and `wrong_strength` relative to base.
- Keep factor-only `auto` thresholds diagnostic-only. h5-au shows they explain broad/balanced/base-like concentration regimes, but they do not beat the base default or the `hybrid-m0p25` alternative.
- This is still a controlled route-hint fixture result. It is not learned routing solved, source-credit robustness solved, wrong-candidate robustness solved, fallback robustness solved, or a long-context benchmark claim.

Current stage / next steps:

- Treat the h5 route-quality stack as closed by `experiments/test_v05_route_quality_closure.sh` and the h7 goal closure.
- Treat h10-a through h10-l, h7-b, v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l, and h11-a/h11-b as the current route-memory policy checkpoint. h6-p exposes the byte-qacc versus span-exact objective split, h6-t/u/v/w keep promotion guarded, h6-x/y show simple local transforms and direct learned-code similarity are not enough, h10-a adds a teacher-free chunk-credit ranker, h10-d forces the fallback/retry path to exercise without selecting noisy sources, h10-e defines the teacher-label contract, h10-f collects local teacher-label harness supervision, h10-g fits a local distilled-rule learner over those labels, h10-h defines the external teacher-label ingestion schema while keeping the default source blocked, h10-i adds a supplied external teacher-label CSV import path, h10-j verifies teacher source/provenance/license/hash chains while keeping any local `file://` fixture non-real, h10-k adds a local linear learned chunk-quality scorer over the teacher-label features while keeping external source and default promotion blocked, h10-l binds learned scorer readiness to source-verified feature labels only when those feature rows match external teacher-label rows by `teacher_id/query_key/candidate_key/teacher_label/source_uri/provenance_hash`, v08-b defines the external benchmark adapter manifest, v08-c defines the external benchmark evidence schema, v08-d adds a supplied-CSV import path, v08-e computes baseline-vs-route-memory deltas while requiring v08-l real verification before publish, v08-f separates placeholder supplied evidence from real benchmark evidence, v08-g verifies local artifact hashes, v08-h verifies benchmark authenticity/evaluator contracts, v08-i verifies execution/evaluator-output artifacts, v08-j adds independent attestation checks over execution hashes and metrics, v08-k verifies attestor identity/provenance, v08-l verifies final-review mechanics while keeping local fixtures non-publishable, h11-a defines the PC RouteLM / NLG prototype readiness contract, and h11-b verifies prototype artifact/provenance hash chains while keeping local fixtures non-real.
- Treat the h6 exact/hash/local-energy span path as symbolic route-memory instrumentation. It proves per-offset value-bearing hints, offset-aware hash candidates, and limited non-`key-shape` span-record scoring under controlled fixtures, not learned chunk retrieval.
- Keep candidate-quality weighting as the strongest route-quality application path so far, with `base` as the default and `hybrid-safe` as the lower-concentration alternative.
- Do not keep increasing route strength or revive topology replacement by default. The current h7-b promotion gate still blocks default promotion: h10-a is positive over chunk ranking, h10-b routes it to `weak-hint-with-abstain`, h10-c keeps noisy wrong candidates unselected, h10-d shows raw fallback retry can recover a forced-corrupt primary path (`qacc 0.290000 -> 0.910000`), h10-e covers correct/wrong/near-miss/missing/abstain grounded-span labels, h10-f marks local teacher-label collection ready, h10-g marks local distillation training/eval ready, h10-h marks the external ingestion schema ready, h10-i can import a supplied external teacher-label CSV, h10-j requires real source verification before distillation, h10-k proves only a local learned chunk scorer from local labels, and h10-l prevents that local scorer from satisfying a source-verified distillation gate unless row-level external label provenance matches. Supplied/local fixtures can verify mechanics, but `real_teacher_source_verified=0`, `source_verified_learned_chunk_scorer_ready=0`, `distillation_ready=0`, and `default_promotion=0` remain in force; external comparison still remains deferred because no real benchmark source/result evidence is ready.
- Real learned/noisy source robustness, chunk-level long-context retrieval, and external long-context baselines remain future work. v08 readiness deliberately defers external benchmark comparison until the promotion gate passes.
- Real PC RouteLM / NLG also remains future work. h11-a can import supplied component evidence for a quantized 3B-14B generator, CPU RAM/NVMe O(n) route memory, GPU candidate scoring, GPU decoder binding, and an NLG smoke URI; h11-b can verify local artifact hash-chain mechanics for those pieces. The readiness path stays `diagnostic-prototype-only` and the artifact path stays `real_pc_routelm_artifact_verified=0` for local fixtures because default promotion, real benchmark comparison, real teacher-source distillation, and measured GPU speed evidence are still absent.
- h5-av now adds that policy-summary layer: the smoke ties qacc between `base-default` and `hybrid-m0p25` at `0.887500`, while `hybrid-m0p25` lowers `factor_gap` from `3.650981` to `3.304388` and receives the diagnostic recommendation `hybrid-m0p25-safe`.
- h5-aw scales the same policy summary across 9 key/noise cells (`keys=64,128,256`, noisy rates `0.10,0.25,0.50`, seeds `1..5`): `hybrid-m0p25` remains qacc-neutral on average (`0.885746 -> 0.885747`), lowers factor gap (`3.607673 -> 3.252902`), lowers wrong strength (`5.852729 -> 5.779043`), and is recommended as `hybrid-m0p25-safe` in all cells.
- h5-ax turns that safe-alternative conclusion into a regression guard: `hybrid-m0p25` must stay within `0.001` qacc of base, lower factor gap, not raise factor max, keep aggregate wrong-strength no-regression, and keep jump-neighbor routing inactive.
- h5-ay adds `--route-quality-candidate-weight-preset none|base-default|hybrid-safe` so the guarded base and hybrid-safe candidate-weight settings can be selected without copying long option blocks. The preset smoke shows exact metric equivalence with explicit settings and keeps `routing_trigger_rate = active_jump_rate = 0.000000`.
- h5-az scales preset adoption over a small key/seed/noise matrix: explicit settings and presets match exactly across 16 rows (`equivalent_rate=1.000000`, all metric deltas `0.000000`), while lookup/read stay populated and jump-neighbor routing remains inactive.
- h5-ba compares the presets directly as experiment arms over the same small key/seed/noise matrix. `hybrid-safe` is recommended in every row: qacc moves `0.863281 -> 0.864258`, factor gap drops `3.440251 -> 3.118539`, factor max drops `6.333333 -> 6.049084`, and jump-neighbor routing remains inactive.
- h5-bb turns the h5-ba preset-policy matrix into a scale guardrail test: summary rows must contain both preset arms, every policy row must recommend `hybrid-safe`, factor gap/max must not regress, aggregate wrong strength must not rise, and `routing_trigger_rate = active_jump_rate = 0.000000`.
- h5-bc adds a closure smoke for the current route-quality stack. It runs shell syntax, `dmv02` build, oracle route-hint, preset equivalence, preset policy smoke, and preset policy scale guardrail together; `--extended` also runs route-code adaptive, preset regression, and candidate-basis guardrail scale checks.
- h6-a opens the route-memory phase with a span-boundary diagnostic. A multi-byte fixture (`HELLO` / `WORLD`) still produces `kv_query_count = route_hint_query_count = 2`, confirming the current stack exposes one first-byte route hint per key, not per span offset. This is explicit boundary instrumentation, not span/chunk routing solved.
- h6-b adds `--route-span-hints 0|1` for exact KV span hints. With `--route-mode hint-kv-exact --route-span-hints 1`, the same `HELLO` / `WORLD` fixture exposes `kv_query_count = route_hint_query_count = 10`, one route hint per value-span offset, while preserving the value-bearing proposal path and keeping jump-neighbor routing inactive.
- h6-c adds exact span scale diagnostics. The smoke compares first-byte and span arms at `key_count=2`, `value_len=5`; route hint query count expands from `2` to `10` under `--route-span-hints 1`, with exact hits/applied hints and jump-neighbor routing inactive.
- h6-d extends span hints to hashed symbolic candidates. With `--route-mode hint-kv-hash --route-span-hints 1`, hash bucket entries retain span offsets and each query offset only compares against same-offset candidates. The smoke exposes `kv_query_count = route_hint_query_count = route_candidate_query_count = 10`, candidate recall/top1 `1.000000`, and keeps `routing_trigger_rate = active_jump_rate = 0.000000`. This is controlled symbolic span-candidate routing, not learned chunk retrieval.
- h6-e adds span hash scale diagnostics. The standard matrix has 8 rows over key count, value length, and hash bits; offset-aware hash candidates keep `qacc_mean = recall_mean = top1_mean = 1.000000`, `collision_rate_mean = 0.000000`, and jump-neighbor routing inactive. This is a span-candidate scale guard, not learned chunk retrieval.
- h6-f adds span ambiguity / collision diagnostics. With `hash_bits=2`, span bucket collision reaches `1.000000`; `K_route=4` drops recall/top1/qacc to `0.500000/0.125000/0.237500`, while `K_route=16` recovers recall to `1.000000` but leaves top1/qacc low at `0.125000/0.293750`. The symbolic `key-shape` scorer recovers `top1=qacc=1.000000`, but the current byte-level candidate-quality preset does not. This is an actionable span-candidate quality split, not learned chunk retrieval solved.
- h6-g adds learned-like span-source stress and span exact-match instrumentation. Clean `route-code-key` span lookup keeps decode/recall/top1 high (`decode=1.000000`, `recall=1.000000`, `top1=1.000000`, `qacc=0.987500`, `span_exact=0.937500`), while weakened route-code identity collapses decode (`0.000000`), creates collisions (`0.750000`), and drops top1/qacc/span-exact (`0.250000/0.606250/0.281250`). Larger `K_route` restores recall to `1.000000` without fixing top1 or span exact-match, and the byte-level candidate-quality preset remains neutral. This is learned-like source stress instrumentation, not learned chunk retrieval solved.
- h6-h adds span-level candidate-quality diagnostics. In weak route-code span stress, `K_route=16` restores all-span recall to `1.000000` but all-span top1 and span exact-match stay at `0.250000`; the byte-level quality preset is neutral, while symbolic `key-shape` recovers all-span top1/span exact-match to `1.000000`. This confirms the next bottleneck is span-level ranking/quality, not recall alone.
- h6-i adds span candidate-quality gap diagnostics. Under weak route-code identity, `K_route=16` restores all-span recall to `1.000000`, but the top candidate is often a coherent wrong key across the whole span (`top_key_consistency=1.000000`, `top_key_correct=0.250000`, `coherent_wrong_top_key=0.750000`). Byte-level `base-default` remains neutral and `hybrid-safe` can be worse in this stress; symbolic `key-shape` restores correct-key share/key entropy/top1 as an upper bound. The next span bottleneck is learned span-record ranking or consistency features, not recall alone.
- h6-j adds `--route-candidate-score span-prefix`, a first non-key-shape span-record ranking probe based only on already-visible query span prefix agreement. It preserves all-span recall but regresses qacc/span exact-match in the smoke (`qacc 0.625000 -> 0.587500`, `span_exact 0.281250 -> 0.218750`) while reducing coherent wrong-key selection (`0.750000 -> 0.593750`). This is useful negative instrumentation: visible prefix consistency alone is not enough to replace symbolic key-shape.
- h6-k adds `--route-candidate-score span-key-support`, a second non-key-shape span-record ranking probe based on candidate keys that appear across multiple offsets in the recovered span candidate set. It preserves all-span recall but is neutral in the current coherent wrong-key stress (`qacc=0.625000`, `span_exact=0.281250`, `coherent_wrong_top_key=0.750000`, unchanged from weak-k16). Same-key support alone is therefore not enough to replace symbolic `key-shape`; a wrong key can also be coherently supported across offsets.
- h6-l adds `--route-candidate-score span-local-energy`, which ranks candidate records by how well their full value span fits the current query span under local energy without route-hint energy. It is the first non-`key-shape` span-record scorer in this series with a limited positive signal: `qacc 0.625000 -> 0.675000`, `span_exact 0.281250 -> 0.406250`, `correct_key_share 0.503125 -> 0.631250`, and `key_entropy 1.238921 -> 0.862081`. It still remains well below symbolic `key-shape`.
- h6-m scales `span-local-energy` over a small key/seed matrix. The limited lift survives on average: `weak_qacc_mean=0.546094`, `local_energy_qacc_mean=0.571875`, `local_energy_qacc_delta_mean=0.025781`; `span_exact_mean` improves `0.273438 -> 0.378906`, while symbolic `key-shape` remains much higher at `qacc_mean=0.984375`, `span_exact_mean=0.921875`.
- h6-n composes `span-local-energy` with h5 candidate-quality presets. `base-default` is neutral on top of local-energy, while `hybrid-safe` improves span-level quality (`span_exact 0.406250 -> 0.593750`, `correct_key_share 0.631250 -> 0.768229`, `key_entropy 0.862081 -> 0.510620`) but lowers byte qacc (`0.675000 -> 0.631250`). This exposes a span exact-match versus byte-qacc policy split.
- h6-o turns that split into an explicit policy artifact. Byte-qacc objective selects `local-energy` (`qacc=0.675000`, `span_exact=0.406250`), while span-exact and balanced objectives select `local-energy-hybrid` (`qacc=0.631250`, `span_exact=0.593750`). The span objective gains `+0.187500` span exact-match while giving back `-0.043750` qacc.
- h6-p scales the h6-o policy artifact over a small key/seed matrix. Byte-qacc selects `local-energy` in every group, while span-exact selects `local-energy-hybrid` in 3/4 groups. The span policy trades mean qacc `-0.033594` for mean span exact-match `+0.062500`; objective split rate is `0.750000`.
- h6-q adds a span-first policy guardrail over h6-p. The strict guardrail accepts the span policy in 1/4 groups, moving qacc `0.571875 -> 0.560937` while improving span exact-match `0.378906 -> 0.425781`; looser guardrails approach the raw span-exact policy. This is guardrail instrumentation, not learned chunk retrieval solved.
- h6-r scales h6-q over weak and harsher learned-like source degradation. In this fixture family, weak degradation keeps objective split but all guardrails reject span-first because qacc loss exceeds the caps; harsher degradation has split in 1/2 groups, and only the looser `span-first-g0p025-cap0p075` guardrail accepts (`qacc_delta=-0.029688`, `span_delta=+0.023438`). This is degradation guardrail instrumentation, not learned source robustness solved.
- h6-s calibrates an adaptive utility guardrail `span_gain - loss_weight*qacc_loss > 0`. `utility-w0p50` accepts weak high-loss splits (`qacc_delta=-0.109375`, `span_delta=+0.062500`), while `utility-w0p75` rejects those and accepts the lower-loss harsher split (`qacc_delta=-0.029688`, `span_delta=+0.023438`). This is adaptive guardrail calibration, not learned source robustness solved.
- h6-t scales the adaptive guardrail smoke over weak/harsher degradation and keeps `utility-w0p75` safe but diagnostic (`bad_accept_rate=0.000000`, no default promotion). h6-u derives chunk-quality diagnostics: smoke `chunk_exact_mean=0.156250`, `coherent_wrong_key_mean=0.828125`, `top1_recall_gap_mean=0.796875`, `keyshape_gap_mean=0.734375`. h6-v/h6-w show source-credit retry can stay noisy-clean but chunk-quality blocks promotion. h6-x/y show plain `span-local-energy` remains better than local transform and route-code similarity probes. h10-a adds `span-chunk-credit` and `span-local-energy-chunk-credit`; in smoke it reaches `qacc=1.000000`, `chunk_exact=1.000000`, `coherent_wrong=0.000000`, and in the 32/64-key scale guard it keeps `chunk_exact=0.960938`, `coherent_wrong=0.000000`, `keyshape_chunk_gap=0.000000`. h10-c/d/e/f/g/h/i/j/k/l add joint noisy, fallback/retry, teacher-label contract, local teacher-label collection, local teacher-distillation learner, external ingestion schema, supplied-label import, real teacher-source verification, local learned chunk-quality scorer, and row-bound source-verified scorer binding gates. Default no-env ingestion remains blocked with `teacher_external_label_source_ready=0`; relabeled local rows without provenance and mismatched external label rows are rejected, any local `file://` source fixture remains non-real, and h10-l stays blocked with `source_verified_learned_chunk_scorer_ready=0`, `distillation_ready=0`, `status=diagnostic-only`, with `default_promotion=0`.
- h7-a adds a goal closure smoke. h7-b adds a promotion gate over h6-t/u/v/w/x/y and keeps `default_promotion=0`, `status=diagnostic-only`; h10-a/b/c/d/e/f/g/h/i/j/k/l are wired into the route-memory closure as later chunk-ranking/source/fallback/teacher-label/scorer smokes, not yet as a default promotion path.
- v08 adds an external benchmark readiness gate. v08-b adds an external benchmark adapter manifest for RULER, LongBench, codebase retrieval, and real document QA (`benchmark_adapter_ready=1`, `benchmark_families=4`), v08-c adds the evidence-ingestion schema (`benchmark_evidence_schema_ready=1`), v08-d can import a supplied `V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV`, v08-e computes comparison deltas, v08-f blocks placeholder supplied evidence from being treated as real benchmark evidence, v08-g verifies local `file://` artifact hashes, v08-h verifies benchmark authenticity/evaluator contracts, v08-i verifies execution/evaluator-output artifacts, v08-j requires independent attestation of execution hashes and metric values, v08-k verifies attestor identity/provenance/conflict-disclosure artifacts, and v08-l verifies final review reports against source/provenance, execution hashes, metrics, attestation IDs, reviewer identity, and conflict-disclosure artifacts. Source/result/baseline/license evidence is still absent in the default run, so readiness still defers external comparison (`external_benchmark_ready=0`, `action=defer-external-comparison`) until promotion and real evidence exist. The supplied fixture comparison is diagnostic-only and unpublished before promotion; v08-f marks the same placeholder fixture `fixture-evidence-not-real-benchmark`, v08-g leaves local hash-verified fixtures blocked on authenticity, v08-h leaves authenticity/evaluator fixtures blocked on actual benchmark execution, v08-i leaves execution fixtures blocked on attestation, v08-j keeps local/fixture attestations diagnostic, v08-k verifies local identity mechanics only, and v08-l keeps local final-review fixtures blocked with `real_external_benchmark_verified=0`.
- h9-a/h9-b/h9-d/h9-e/h9-f/h9-g add an optional ROCm/HIP backend scaffold behind `-DDLE_ENABLE_HIP=ON` and `--backend hip`. CPU remains canonical and default. The first HIP boundaries are bounded route-quality candidate-weight factor parity and diagnostic-only 16x16 proposal-score parity; h9-f runs the parity tool in CPU mode during quick closure and adds a speed-evidence no-claim schema, while h9-g verifies timing/environment artifacts but keeps `gpu_speedup_claim=deferred` unless real HIP-backed measurements exist. KV parsing, hash/source-credit orchestration, update acceptance, RNG, age/tick/reservoir mutation, and CSV stay on CPU. This is backend/parity instrumentation, not GPU acceleration proven and not learned routing solved.
- Current verification checkpoint: h6-t/u/v/w/x/y, h10-a/b/c/d/e/f/g/h/i/j/k/l, and h7-b are wired into the h7 goal closure, v08-b/v08-c/v08-d/v08-e/v08-f/v08-g/v08-h/v08-i/v08-j/v08-k/v08-l adapter/evidence/import/comparison/real-evidence/artifact-verifier/authenticity/execution/attestation/attestor-identity/final-review/readiness plus h11-a readiness/import, h11-b artifact verifier/import, and h9-g measured-speed gate/import are wired into h9 quick closure, and HIP parity remains optional/environment-dependent.

Current status:

- `v0.1` implemented as `dmv01`
- `v0.2-pre` implemented as `dmv02` and treated as the locked baseline
- `v0.2-b` now includes a block-local coupled proposal path, and the default weak-coupling path clears a 5-seed regression on both `counter` and `repeating-text`
- a routing probe path now exists behind `--K-jump` and `--route-source`, including `input-byte` and `joint-code` candidate sources, but it only logs O(1)-candidate diagnostics, does not change graph dynamics, and keeps jump-neighbor replacement no-go/default-off/diagnostic-only
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
  (`source_gap=-0.140244`, noisy slash `1.000000`) and receives no strength
  amplification (`strength_mean=1.000000`).
- h5-m adds source/noise-aware aggregation scale stability diagnostics. The
  smoke crosses key count `64/128` with seeds `1/2` and compares vote versus
  source-aware weighted aggregation for `raw-key`, `key-shape`, and
  `noisy-route-code` fallback sources. Averaged over the smoke, raw-key improves
  from qacc `0.378516` to `0.925391`, and key-shape improves from `0.275781` to
  `0.932813`; both keep `fallback_recall=1.000000`. The noisy branch remains
  unresolved (`fallback_recall=0.000000`) while keeping negative source/noisy
  credit (`source_gap=-0.268339`, noisy slash `1.000000`) and no strength
  amplification (`strength_mean=1.000000`).
- h5-n adds bad-source filtering / abstain diagnostics. New
  `--route-source-filter-mode negative-credit` drops candidates whose source
  credit is below `--route-source-filter-threshold`. In the smoke, symbolic
  fallbacks stay usable (`raw-filter` qacc `0.951562`, `keyshape-filter` qacc
  `0.965625`), while noisy fallback candidates are heavily filtered
  (`source_filter_filtered=0.935065`, `source_filter_abstain=0.875000`).
  Noisy qacc does not improve (`0.185937 -> 0.100000`), so this is bad-source
  abstention instrumentation, not fallback robustness solved.
- h5-o adds retry-source replacement diagnostics via
  `--route-source-retry-source`. The smoke keeps a bad `noisy-route-code`
  fallback, then adds a symbolic retry source after negative-credit filtering.
  The noisy-filter baseline abstains without recovery (`qacc=0.103125`,
  `fallback_recall=0.000000`, `source_filter_abstain=0.876562`). Adding a
  retry source restores candidate recall and query accuracy (`retry-raw`
  qacc `0.950000`, `fallback_recall=1.000000`; `retry-keyshape` qacc
  `0.962500`, `fallback_recall=1.000000`) while keeping jump-neighbor routing
  inactive. This is retry/replacement instrumentation with symbolic retry
  sources, not learned routing or fallback robustness solved.
- h5-p adds source-credit retry-policy calibration via
  `--route-source-retry-policy source-credit`,
  `--route-source-retry-candidates`, and
  `--route-source-retry-per-source-limit`. The smoke compares fixed retry
  sources with policy-selected retry candidates after noisy-source filtering.
  The noisy-filter baseline abstains without recovery (`qacc=0.103125`,
  `fallback_recall=0.000000`), fixed symbolic retry recovers (`fixed-raw`
  qacc `0.957813`, `fixed-keyshape` qacc `0.970313`), and the source-credit
  mixed policy recovers while avoiding noisy retry selection (`policy-mixed`
  qacc `0.957813`, `retry_noisy_selected=0.000000`). This wires retry-source
  policy selection, but the policy still relies on symbolic retry candidates
  and does not solve learned routing or fallback robustness.
- h5-q adds source-credit retry-policy tie-break calibration via
  `--route-source-retry-tiebreak source-order|source-prior` and
  `--route-source-retry-priorities <csv>`. The smoke keeps the same
  `candidate value_pos -> value byte read -> proposal hint` path and compares
  noisy-filter, policy-source-order, policy-keyshape-prior,
  policy-noisy-penalty/mixed, and fixed-keyshape reference rows. Noisy-filter
  stays at `qacc=0.103125`, `fallback_recall=0.000000`,
  `noisy_slashed=1.000000`, `source_retry_used=0.000000`; policy-source-order
  recovers through raw-key (`qacc=0.957813`, `fallback_recall=1.000000`,
  `retry_raw_selected=0.875000`), while key-shape prior and
  noisy-penalty/mixed switch selection to key-shape
  (`retry_keyshape_selected=0.875000`, `retry_noisy_selected=0.000000`) with
  no qacc regression. The fixed key-shape reference remains higher
  (`qacc=0.970313`, `fallback_qacc=1.000000`), so this is tie-break
  calibration / limited mitigation, not learned routing solved,
  source-credit robustness solved, or wrong-candidate/fallback robustness
  solved.
- h5-r adds source-prior schedule diagnostics on the same retry path via
  `--route-source-retry-prior-mode none|static|decay|warmup`,
  `--route-source-retry-prior-decay`, and
  `--route-source-retry-prior-warmup-epochs`. The smoke compares source-order,
  static key-shape prior, decaying key-shape prior, warmup key-shape prior, and
  fixed key-shape reference rows. The scheduled-prior rows switch retry
  selection to key-shape and avoid noisy retry selection, but still match
  `qacc=0.957813` rather than the fixed key-shape reference `0.970313`; read
  this as source-prior schedule calibration / limited mitigation only.
- h5-s adds source-prior handoff diagnostics on the same retry path. The smoke
  compares source-order, static key-shape prior, warmup-short/long, decay-fast,
  and fixed key-shape reference rows. Short warmup exposes a partial handoff
  (`retry_raw_selected=0.062500`, `retry_keyshape_selected=0.812500`), while
  long warmup/decay/static prior keep key-shape selected
  (`retry_keyshape_selected=0.875000`). Noisy retry remains unused, and qacc
  remains `0.957813`, below fixed key-shape `0.970313`; read this as
  source-prior handoff calibration / limited mitigation only.
- h5-t adds retry-source evidence-quality diagnostics. New CSV metrics expose
  retry-source credit means and reward/slash rates for raw-key, key-shape, and
  noisy retry sources. The smoke keeps the value-bearing path active and
  noisy retry suppressed: source-order rewards raw-key
  (`retry_raw_mean=0.222951`), static/warmup key-shape prior rewards key-shape
  (`retry_keyshape_mean=0.222951`), and noisy retry stays negative
  (`retry_noisy_mean=-0.206811`, `retry_noisy_slashed=1.000000`). This is
  evidence-quality instrumentation only: raw-key and key-shape both receive
  positive credit when selected, so source-credit evidence still does not
  independently rank the better symbolic retry source.
- h5-u passes as candidate-quality logdet/channel/quality-score instrumentation
  with `route_quality_apply=none`. The smoke keeps behavior unchanged
  (`quality-off-source-order` and `quality-on-source-order` both `qacc=0.645313`)
  while exposing candidate-set quality signals. In this diagnostic setup, fixed
  raw-key separates from fixed key-shape (`qacc=0.742187` vs `0.645313`,
  `logdet=-5.818573` vs `-15.330912`, condition `7.050210` vs `52.270703`).
  Read this only as instrumentation, not a learned-routing or robustness win.
- h5-v adds the first weak quality application via `route_quality_apply=source-ranking`.
  It uses a bounded soft delta only; no hard threshold/filter is used and the
  value-bearing route path stays active. The smoke activates the path
  (`route_quality_apply_active=1.000000`, delta `0.227710..0.250000`) and avoids
  noisy retry selection, but qacc is slightly lower than apply-none
  (`0.560938` vs `0.568750`). Read this as calibration diagnostics, not a
  robustness win.
- h5-w adds source-quality calibration diagnostics for that weak apply path.
  The retry-source proxy is now reported per source: raw-key is strongly
  positive (`2.277099`), while key-shape and noisy-route-code are negative
  (`-0.472130`, `-0.513364`). This explains why source-ranking keeps selecting
  raw-key and avoiding noisy retry, but it also shows that the current proxy is
  not qacc-optimal.
- h5-x calibrates proxy signs while keeping source-ranking soft. The
  channel-sign row is the best single smoke (`qacc=0.662500`,
  `selected_raw_qacc=0.720536`) versus proxy-default `qacc=0.560938`. This is
  useful, but still narrow: the next step is multi-seed/scale stability before
  stronger candidate-weight or route-strength application.
- h5-y runs that channel-sign check across the first multi-seed/key smoke.
  With `keys=64,128`, seeds `1..3`, and noisy source rate `0.25`,
  channel-sign has mean qacc `0.636198`, proxy-default has `0.621094`, and
  proxy-off has `0.622656`; noisy selection stays `0.000000`, while raw-key
  remains the selected retry source. Treat this as weak limited mitigation and
  stability diagnostics, not source selection solved.
- h5-z adds `--route-quality-source-normalization none|center|zscore`.
  Center/zscore normalization lowers raw source-ranking pressure while keeping
  the channel-sign qacc unchanged (`0.636198`) and noisy selection at
  `0.000000`; source choice still stays raw-key-centered. This is
  source-normalization instrumentation, not a new robustness win.
- h5-aa adds candidate-level quality diagnostics. In the same standard smoke,
  correct candidate weight stays above wrong candidate weight (`0.396566` vs
  `0.217533`, gap `0.179034` on channel-sign), and the best weighted candidate
  is correct more often than final qacc (`0.838021` vs `0.636198`). This makes
  the next bottleneck candidate-level application / aggregation-to-state
  integration, not source-level normalization alone.
- h5-ab enables weak bounded candidate-level application with
  `--route-quality-apply candidate-weight`. It sharpens existing base weights
  with a clamped relative factor and keeps route strength off. In the standard
  smoke, `candidate-b0p50` reaches qacc `0.725261`, improving over proxy-off
  and source-ranking while leaving `routing_trigger_rate` and
  `active_jump_rate` at `0.000000`.
- h5-ac adds `--route-quality-apply source-candidate`, combining source-ranking
  with candidate-weight. The combined mode is wired and safe, but it does not
  beat candidate-only in the current standard smoke (`source-candidate-b0p50`
  `0.717708` vs `candidate-b0p50` `0.725261`). The next target is
  candidate-only beta/scale stability.
- h5-ad scales the candidate-only beta sweep over `keys=64,128`, seeds `1..3`,
  and noisy source rates `0.10,0.25,0.50`. Within the tested bounded factor
  range, candidate-only qacc keeps improving through `beta=0.75`:
  proxy-off `0.615799`, `b0p25` `0.666580`, `b0p50` `0.722222`, `b0p75`
  `0.775434`. This is still a controlled route-hint fixture result:
  `route_quality_selected_noisy_rate`, `routing_trigger_rate`, and
  `active_jump_rate` all remain `0.000000`.
- h5-ae adds candidate-weight saturation/cap diagnostics and concentration
  metrics (`factor_p90`, `factor_max`, entropy, and top share). In the standard
  sweep, `beta=2.0` with cap `3.0/4.0` is the best tested point
  (`qacc=0.922396`, factor max `2.333333`, top share `0.585550`), while cap
  `2.0` clips that arm and lowers qacc to `0.905729`. The slice finds a cap
  boundary, not an over-sharpening failure.
- h5-af promotes the best h5-ae-style setting into a broader regression sweep
  over `keys=64,128,256`, seeds `1..3`, and noisy source rates `0.25,0.50`.
  The aggregate qacc improves from proxy-off `0.637153` to
  `candidate-b2p00-cap3p0` `0.869965`; the same arm is best in every
  key/noise bucket. `candidate-b2p00-cap2p0` falls to `0.843620`, confirming
  that cap `2.0` is too tight at high beta. `route_quality_selected_noisy_rate`,
  `routing_trigger_rate`, and `active_jump_rate` remain `0.000000`.
- h5-ag extends the high-beta boundary over `keys=128,256`, seeds `1..3`, and
  noisy rates `0.25,0.50`. It does not find an over-sharpen collapse through
  `beta=3.0`; aggregate qacc rises from `b2p00-cap3p0` `0.934896` to
  `b3p00-cap3p0` `0.947331`. Caps `4.0/6.0` match cap `3.0` because the
  observed factor max is already `3.000000`, so cap is no longer the active
  boundary in this range.
- h5-ah extends the same boundary to `beta=4.0/5.0` and caps `4.0/6.0/8.0`.
  It still does not find collapse: aggregate qacc reaches
  `candidate-b5p00-cap6p0` / `cap8p0` `0.952669`. Cap `4.0` is slightly lower
  at `0.950195`, while cap `6.0/8.0` tie because the observed factor max is
  `4.333333`.
- h5-ai extends the same candidate-weight boundary to `beta=6.0/8.0` with
  caps `6.0/8.0/12.0`. It still does not find an over-sharpen collapse:
  aggregate qacc reaches `candidate-b8p00-cap8p0` / `cap12p0` `0.957813`.
  The guard remains intact (`selected_noisy_rate`, `routing_trigger_rate`, and
  `active_jump_rate` all `0.000000`), but concentration keeps rising
  (`factor_max=6.333333`, top share `0.689736`, entropy `1.157891`), so this is
  an extreme-beta boundary diagnostic rather than a robustness claim.
- h5-aj extends the boundary again to `beta=10.0/12.0` with caps
  `10.0/12.0/16.0`. It still does not find an over-sharpen collapse, but it
  does show a practical plateau: `candidate-b12p00-cap12p0` / `cap16p0`
  reaches only `0.958008` versus `candidate-b8p00-cap8p0` `0.957813`, while
  factor max rises to `9.000000` and top share rises to `0.713297`. Treat this
  as ultra-beta plateau/boundary diagnostics, not a reason to change route
  strength or promote robustness claims.
- h5-ak compares the plateau candidates over a broader 5-seed/key/noise
  guardrail: `keys=64,128,256`, seeds `1..5`, noisy rates `0.10/0.25/0.50`.
  `beta=8, cap=8` slightly beats `beta=12, cap=12` on aggregate qacc
  (`0.885747` vs `0.885573`) and has lower concentration and wrong strength.
  The current safe bounded candidate-weight default is therefore
  `beta=8, cap=8`, not the more concentrated `beta=12` arm.
- h5-al fixes that safe setting as a default-application comparison over
  `keys=64,128,256`, seeds `1..3`, and noisy rates `0.10/0.25/0.50`.
  Candidate-weight-only remains the cleanest default: `candidate-default`
  reaches qacc `0.886429`, versus `proxy-off` `0.646962` and
  `source-candidate-default` `0.884896`. Source-ranking composition is wired
  but not promoted; noisy source selection, routing trigger, and active jump
  remain `0.000000`.
- h5-am adds `--route-quality-candidate-weight-basis base|quality-score` and
  compares the h5-al base default against feature-score candidate bases over
  `keys=64,128`, seeds `1..3`, and noisy rates `0.25/0.50`. The feature basis
  is connected and reduces wrong hint strength, but it weakens factor
  separation and qacc: `base-default` reaches `0.837630`, while the best
  feature arm, `feature-margin`, reaches `0.800000`. The default remains
  `candidate-weight-basis=base`.
- h5-an adds `--route-quality-candidate-weight-basis hybrid` and
  `--route-quality-candidate-weight-basis-mix`. The best hybrid arm in the
  standard check is `hybrid-m0p25`: qacc is `0.837760`, essentially matching
  `base-default` (`0.837630`) while reducing candidate factor concentration
  (`factor_gap 2.859539` vs `3.154903`, `factor_max 5.928332` vs `6.333333`).
  This is lower-concentration limited mitigation, not a default promotion.
- h5-ao scales that hybrid comparison over `keys=64,128,256`, seeds `1..3`,
  and noisy rates `0.25/0.50`. `hybrid-m0p25` again preserves qacc
  (`0.886545` vs base `0.886458`) while lowering concentration
  (`factor_gap 3.247608` vs `3.596599`, `factor_max 5.968582` vs
  `6.333333`). The effect is real but tiny, so `basis=base` remains the safe
  default and `hybrid-m0p25` remains a guardrail/ablation arm.
- h5-ap runs the promotion check with `keys=64,128,256`, seeds `1..5`, and
  noisy rates `0.10/0.25/0.50`, comparing only `base-default` and
  `hybrid-m0p25`. The result is an exact qacc tie (`0.885747` each), while
  hybrid lowers concentration and wrong strength. This makes `hybrid-m0p25` a
  safe lower-concentration alternative, but not a default promotion.
- h5-aq adds `--route-quality-candidate-weight-basis auto`,
  `--route-quality-candidate-weight-auto-factor-max`, and
  `--route-quality-candidate-weight-auto-top-share`. The auto policy keeps the
  base basis unless a query's candidate-weight concentration exceeds the
  thresholds, then switches that query to the `hybrid-m0p25` basis. In the
  standard check over `keys=64,128,256`, seeds `1..3`, and noisy rates
  `0.25/0.50`, `auto-f6p0-t0p72` reaches qacc `0.886502`, lowers factor
  gap/max to `3.477531/5.968582`, lowers wrong strength to `6.173549`, and
  uses the hybrid branch on `0.440365` of query summaries. This is
  concentration-aware policy instrumentation, not a default promotion.
- h5-ar extends the same runner with `--auto-threshold` and
  `--auto-threshold-smoke` to sweep concentration thresholds. `f5.8/t0.70`
  turns into always-hybrid, `f6.0/t0.72` and `f6.2/t0.74` are the balanced
  lower-concentration arms, and `f6.4/t0.76` is the most selective arm. The
  latter has the highest tiny qacc (`0.886632`) but does not lower factor max;
  keep `basis=base` as the default and use the threshold sweep diagnostically.
- h5-as adds auto-trigger decomposition metrics:
  `route_quality_candidate_weight_auto_factor_trigger_rate`,
  `route_quality_candidate_weight_auto_top_share_trigger_rate`,
  `route_quality_candidate_weight_auto_factor_max_probe_mean`, and
  `route_quality_candidate_weight_auto_top_share_probe_mean`. These metrics
  explain the h5-ar threshold behavior without changing route behavior:
  `f6.0/t0.72` and `f6.2/t0.74` are identical because the observed trigger
  distribution has no extra mass between those thresholds; `f6.4/t0.76`
  disables factor-triggered hybrid switching and keeps only the top-share
  trigger. This is diagnostics only.
- h5-at adds `--route-quality-candidate-weight-auto-trigger-mode
  any|factor|top-share` and `--auto-trigger` runner arms. `factor` mode
  switches exactly on the factor trigger, `top-share` mode switches exactly on
  the top-share trigger, and `any` preserves the previous behavior. The
  standard sweep shows factor-triggered switching is what lowers concentration,
  while top-share-only is mostly base-like and carries only the tiny qacc edge.
- h5-au adds `--auto-factor-threshold` runner arms for factor-only thresholds
  `5.6/5.8/6.0/6.2/6.4`. The threshold distribution is coarse: `5.6/5.8`
  behave identically, `6.0/6.2` behave identically, and `6.4` disables factor
  switching. This confirms factor-only auto is useful instrumentation, but not
  a default promotion.

## Build

```bash
cmake -S . -B build
cmake --build build -j
```

Optional ROCm/HIP scaffold build:

```bash
cmake -S . -B build-hip -DDLE_ENABLE_HIP=ON
cmake --build build-hip --target dmv02 hip_candidate_weight_parity -j
```

Runtime backend selection is explicit:

```bash
./build/dmv02 --backend cpu ...
./build-hip/dmv02 --backend hip --hip-device 0 ...
```

h9 is scaffold/parity only. It does not move string/KV parsing,
source-credit ledgers, update acceptance, RNG, route strength, or topology onto
GPU.

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
- `experiments/test_v06_route_memory_span_ambiguity.sh`
- `experiments/test_v06_route_memory_span_learned_source.sh`
- `experiments/test_v06_route_memory_span_quality_diagnostics.sh`
- `experiments/test_v06_route_memory_span_candidate_quality_gap.sh`
- `experiments/test_v06_route_memory_span_prefix_ranking.sh`
- `experiments/test_v06_route_memory_span_key_support_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_ranking.sh`
- `experiments/test_v06_route_memory_span_local_energy_scale.sh`
- `experiments/test_v06_route_memory_span_local_energy_composition.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy.sh`
- `experiments/test_v06_route_memory_span_local_energy_policy_scale.sh`
- `experiments/test_v07_goal_route_memory_closure.sh`
- `experiments/test_v05_route_quality_candidate_auto_basis.sh`
- `experiments/test_v05_route_quality_candidate_auto_threshold.sh`
- `experiments/test_v05_route_quality_candidate_auto_trigger.sh`
- `experiments/test_v05_route_quality_candidate_auto_factor_threshold.sh`
- `experiments/test_v05_route_quality_candidate_composition.sh`
- `experiments/test_v05_route_quality_candidate_regression.sh`

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
- [v0.6 / h6 Route Memory](docs/V06_ROUTE_MEMORY.md)
- [v0.7 / h7 Goal Closure](docs/V07_GOAL.md)
- [h9 ROCm/HIP Backend Scaffold](docs/V09_GPU_BACKEND.md)
- [Roadmap](docs/ROADMAP.md)
