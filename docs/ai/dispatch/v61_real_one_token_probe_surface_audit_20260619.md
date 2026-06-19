Goal:
Find the smallest existing v61 surface to extend toward the real one-token milestone: local SSD safetensors page read, real dtype/quant decode, matvec parity, expert FFN parity, MoE block/logits parity.

Scope:
- Inspect only existing local files under `experiments/`, `src/`, `docs/`, and small scripts/tests.
- Do not edit files.
- Do not run network, downloads, GPU, long benchmark, model generation, checkpoint materialization, or destructive commands.

File candidates:
- `experiments/run_v61*.sh`
- `experiments/test_v61*.sh`
- `src/`
- `docs/V61_SSD_RESIDENT_MOE_RUNTIME.md`

Verification criteria:
- Report 3-5 best extension points with exact files and why.
- Identify whether any existing script already reads a local safetensors payload from disk.
- Identify whether any existing test can be extended without claiming real execution from fixtures.
- Identify required evidence fields for the first real one-token slice.

Forbidden changes / invariants:
- No file edits.
- Do not add another pure gate as the recommendation if an actual local payload probe can be implemented.
- Preserve evidence boundary: fixture/synthetic rows must not imply real Mixtral execution.
