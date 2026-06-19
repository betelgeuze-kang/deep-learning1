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

`torch_matvec_parity_ready=1` is not a real runtime claim. The phrase
`SSD-resident real model runtime` remains blocked until milestones 1-6 are all
accepted with replayable artifacts.
