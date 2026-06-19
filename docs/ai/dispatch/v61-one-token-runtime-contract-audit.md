# OpenCode Worker Slice: v61 One-Token Runtime Contract Audit

Goal:
Audit whether the v61 one-token path contract fail-closes SSD-resident real model runtime claims until milestones 1-6 are satisfied: actual Mixtral SSD tensor page read, tensor dtype/quant dequant, PyTorch matvec parity, expert FFN parity, MoE block parity, and one-token logits parity.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `v61/one_token_path.json`
- `schemas/v61_one_token_path.schema.json`
- `tools/verify_artifact.py`
- `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`
- `experiments/run_v61aa_hotset_tensor_slice_verifier.sh`
- `experiments/test_v61aa_hotset_tensor_slice_verifier.sh`
- `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`
- `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`
- `pr_slices/pr2.json`

Verification criteria:
- Identify missing milestone fields needed for actual tensor page, dtype/quant, PyTorch parity, FFN/MoE/logits parity.
- Identify missing artifact columns or row minimums.
- Identify verifier gaps where fixture/runtime-admission evidence could be promoted into SSD-resident real runtime wording.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, long benchmark runs, or checkpoint payload writes.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete contract/verifier gaps
- Suggested exact fields or checks
- Blockers
