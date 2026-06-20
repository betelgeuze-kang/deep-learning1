Goal:
Audit the v61ab expert FFN fixture path now that it uses an independent C++
runtime executable instead of a Python/Torch candidate path.

Scope:
- Read only. Do not edit files.
- Inspect `src/tools/expert_ffn_forward_parity.cpp`, `CMakeLists.txt`,
  `experiments/run_v61ab_hotset_tensor_tile_quant_probe.sh`,
  `experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh`, and
  `docs/V61_ONE_TOKEN_PATH_CONTRACT.md`.

Verification criteria:
- Confirm the new C++ executable computes `W2 * (silu(W1*x) * (W3*x))`
  independently from Torch and writes a float32 output.
- Confirm the v61ab runner uses the C++ executable for the local safetensors
  expert FFN fixture candidate output and compares it with the Torch reference.
- Confirm the runner populates `independent_runtime_output_sha256` from the C++
  output, keeps `transformers_expert_output_sha256` empty, and keeps
  `real_model_execution_ready=0`.
- Confirm the test builds the C++ target and checks the candidate hash comes
  from `independent_runtime_output_sha256`.
- Confirm this does not open real expert FFN, real generation, release, or
  original Transformers-module evidence claims.

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
