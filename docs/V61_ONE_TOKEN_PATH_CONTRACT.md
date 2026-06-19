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
summary prose. The contract requires these artifact shapes:

- `expert-ffn-forward-parity-rows`: real layer/expert tensor names, W1/W2/W3
  payload hashes and shapes, typed readiness fields, candidate/reference output
  hashes, tolerance, max delta, and `expert_ffn_parity_pass`
- `moe-block-forward-parity-rows`: token input hash, router logits hash,
  selected experts/weights, expert and block output hashes, reference output
  hash, tolerance, max delta, and `moe_block_parity_pass`
- `one-token-logits-parity-rows`: checkpoint/revision identity, tokenizer input
  hash, route path hash, candidate/reference logits hashes, top-1 agreement,
  tolerance, max delta, and `logits_parity_pass`

`torch_matvec_parity_ready=1` is not a real runtime claim. The phrase
`SSD-resident real model runtime` remains blocked until milestones 1-6 are all
accepted with replayable artifacts.
