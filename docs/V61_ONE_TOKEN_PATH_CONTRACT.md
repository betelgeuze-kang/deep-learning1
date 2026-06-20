# v61 One-Token Runtime Path Contract

v61 is not an SSD-resident real model runtime until the one-token path closes
through logits parity. The source-controlled contract is
`v61/one_token_path.json`.

Verify the contract against the current v61 summaries:

```bash
tools/verify_artifact.py v61-one-token v61/one_token_path.json \
  --v61aa-summary results/v61aa_hotset_tensor_slice_verifier_summary.csv \
  --v61ab-summary results/v61ab_hotset_tensor_tile_quant_probe_summary.csv
```

The verifier intentionally fails if summary evidence is omitted while milestones
are marked `pass` or carry summary checks.

Current accepted evidence:

- actual Mixtral hotset tensor page read/binding evidence
- sampled BF16 dtype/stat evidence and q8/q4 tile quant probes
- PyTorch CPU matvec parity over bounded hotset tiles

Current blockers:

- real expert FFN forward parity
- real MoE block forward parity
- one-token logits parity
- 16-token decode
- cold/warm cache measurement
- SSD bytes/token, miss/token, and TPS recording

The next real-runtime evidence must be emitted as replayable CSV rows, not
summary prose. The verifier now treats each required artifact as a typed gate:

- `path` names the replayable CSV artifact.
- `min_rows` must be satisfied whenever the artifact exists; pass milestones
  require the artifact to exist.
- `pass_field` must contain at least one `1` row with
  `real_model_execution_ready=1` before the linked milestone can move to
  `pass`.
- blocked linked milestones must not contain any `pass_field=1` row, and must
  not contain `local_checkpoint_root_supplied=1`,
  `real_model_execution_ready=1`, release, generation, human-review,
  independent-reproduction, near-frontier, or production-latency readiness
  signals.

The contract requires these artifact shapes:

- `mixtral-ssd-tensor-page-read-rows`
  (`results/v61aa_hotset_tensor_slice_verifier/verify_001/source_v61v/remote_sample_tensor_binding_rows.csv`):
  remote page hash, shard/tensor identity, dtype, tensor segment/page offsets,
  expert/embedding page flags, `remote_hash_bound`,
  `checkpoint_payload_bytes_committed_to_repo`, and `route_jump_rows`
- `tensor-dtype-stat-rows`
  (`results/v61aa_hotset_tensor_slice_verifier/verify_001/hotset_tensor_slice_stat_rows.csv`):
  bound local/remote page hashes, BF16 sample counts, finite/nan/inf counts,
  tensor statistics, `bf16_tensor_slice_stats_ready`,
  `actual_model_generation_ready`, and payload/route guards
- `tensor-quant-dequant-metric-rows`
  (`results/v61ab_hotset_tensor_tile_quant_probe/probe_001/hotset_tensor_tile_quant_metric_rows.csv`):
  q8/q4 finite row counts, q8/q4 error summaries,
  `q8_quant_probe_ready`, `q4_quant_probe_ready`,
  `torch_matvec_parity_ready`, and real-generation/release guards
- `torch-matvec-parity-rows`
  (`results/v61ab_hotset_tensor_tile_quant_probe/probe_001/hotset_tensor_tile_torch_parity_rows.csv`):
  tile and tensor hashes, PyTorch reference backend, candidate/reference dot
  values, tolerance, delta, `torch_matvec_parity_pass`,
  real checkpoint page binding, and payload/generation/route guards
- `expert-ffn-forward-parity-rows`
  (`results/v61ab_hotset_tensor_tile_quant_probe/probe_001/expert_ffn_forward_parity_rows.csv`):
  checkpoint/config/tokenizer/shard/manifest hashes, real layer/expert tensor
  names, router top-k, RMSNorm and router payload hashes, W1/W2/W3 payload
  hashes and shapes, residual input/output hashes, reserved original
  Transformers expert output hash, independent C++ runtime output hash, typed
  readiness fields, tolerance, max delta, and `expert_ffn_parity_pass`.
  Fixture-only rows may populate the independent C++ runtime hash, but must
  leave the original Transformers module output empty until that module capture
  exists. A real `expert_ffn_parity_pass=1` row with
  `real_model_execution_ready=1` must bind both hashes: the candidate output
  must match the independent runtime output hash, and the torch reference
  output must match the original Transformers expert output hash.
- `moe-block-forward-parity-rows`
  (`results/v61_moe_block_forward_parity/moe_block_forward_parity_rows.csv`):
  token input hash, router logits hash,
  router tensor/payload hash, selected experts/weights with selected expert
  payload hashes, upstream expert-FFN artifact hash, typed readiness fields,
  expert and block output hashes, reference output hash, tolerance, max delta,
  and `moe_block_parity_pass`
- `one-token-logits-parity-rows`
  (`results/v61_one_token_logits_parity/one_token_logits_parity_rows.csv`):
  checkpoint/revision identity, tokenizer input
  hash, tokenizer revision, exact token ID, router top-k, layer activation
  trace hash/row count, route path hash, upstream MoE-block artifact hash,
  final hidden hash, LM-head tensor/payload hash, vocab/logit counts,
  candidate/reference logits hashes, typed readiness fields, top-1 agreement,
  max and mean absolute logit error, tolerance, top-k token ranking agreement,
  and `logits_parity_pass`. A passing row must bind valid SHA-256 hashes for
  the upstream MoE-block artifact, tokenizer input, route path, layer
  activation trace, final hidden state, LM-head payload, candidate logits, and
  reference logits. The verifier also checks that `logit_count` equals
  `vocab_size`, and that candidate/reference top-k token ID lists are
  parseable, have exactly `top_k_token_count` entries, and match when
  `top_k_token_ranking_match=1`.
- `sixteen-token-decode-rows`
  (`results/v61_sixteen_token_decode/sixteen_token_decode_rows.csv`):
  checkpoint/revision and tokenizer revision, upstream logits-parity artifact
  hash, prompt input hash, candidate/reference token IDs and text hashes,
  typed readiness fields, token mismatch count, and `decode_parity_pass`
- `cold-warm-cache-measurement-rows`
  (`results/v61_cold_warm_cache_measurement/cold_warm_cache_measurement_rows.csv`):
  cold and warm `cache_state` rows, upstream decode artifact hash, runtime
  settings hash, decoded token count, wall time, first-token latency,
  steady-state TPS, SSD bytes read, cache hit/miss counts, typed readiness
  fields, and `cache_measurement_pass`
- `ssd-bytes-miss-tps-rows`
  (`results/v61_ssd_runtime_metrics/ssd_bytes_miss_tps_rows.csv`):
  cold/warm measurement hashes, bytes/token, miss/token, TPS for cold and warm
  runs, typed readiness fields, and `ssd_runtime_metrics_pass`

`torch_matvec_parity_ready=1` is not a real runtime claim. The phrase
`SSD-resident real model runtime` remains blocked until milestones 1-6 are all
accepted with replayable artifacts.
