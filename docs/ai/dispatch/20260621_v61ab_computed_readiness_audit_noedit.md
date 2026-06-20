Goal:
Audit the v61ab computed-readiness verifier change.

Scope:
- Read only. Do not edit files.
- Inspect `tools/verify_artifact.py`, `scripts/ai-verify.sh`,
  `experiments/test_p0_v61ab_computed_readiness_negative_controls.sh`, and
  `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`.

Verification criteria:
- Confirm `tools/verify_artifact.py v61ab-tile-probe` recomputes v61ab
  readiness/pass summary fields from raw row artifacts in the run directory.
- Confirm it compares recomputed values against summary CSV, metric CSV, and
  manifest JSON instead of trusting runner-declared summary values.
- Confirm negative controls mutate raw torch parity rows and summary readiness
  and expect verifier failures.
- Confirm `scripts/ai-verify.sh` invokes the new negative control and verifier.
- Confirm claim boundaries are unchanged: no real model generation, release,
  full checkpoint materialization, or one-token logits parity claim is opened.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, long benchmarks, or remote commands.
- Do not alter evidence boundaries, seeds, metrics, readiness semantics, or
  artifact paths.

Output:
Changed files: none
Checks run:
Core findings:
Unresolved risks:
