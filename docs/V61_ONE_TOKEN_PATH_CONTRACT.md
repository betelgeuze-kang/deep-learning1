# v61 One-Token Runtime Path Contract

v61 is not an SSD-resident real model runtime until the one-token path closes
through logits parity. The source-controlled contract is
`v61/one_token_path.json`.

Verify the contract with:

```bash
tools/verify_artifact.py v61-one-token v61/one_token_path.json
```

When the current v61 summaries exist, compare the contract against them:

```bash
tools/verify_artifact.py v61-one-token v61/one_token_path.json \
  --v61aa-summary results/v61aa_hotset_tensor_slice_verifier_summary.csv \
  --v61ab-summary results/v61ab_hotset_tensor_tile_quant_probe_summary.csv
```

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
- blocked linked milestones must not contain a real-model pass row.

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
  real layer/expert tensor names, W1/W2/W3
  payload hashes and shapes, typed readiness fields, candidate/reference output
  hashes, tolerance, max delta, and `expert_ffn_parity_pass`
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
  hash, tokenizer revision, route path hash, upstream MoE-block artifact hash,
  final hidden hash, LM-head tensor/payload hash, vocab/logit counts,
  candidate/reference logits hashes, typed readiness fields, top-1 agreement,
  tolerance, max delta, and `logits_parity_pass`

`torch_matvec_parity_ready=1` is not a real runtime claim. The phrase
`SSD-resident real model runtime` remains blocked until milestones 1-6 are all
accepted with replayable artifacts.
