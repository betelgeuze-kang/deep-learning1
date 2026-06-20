Goal:
Audit the v61 one-token logits parity pass-row guard after Codex changes.

Scope:
Read only. Do not edit files. Inspect:
- tools/verify_artifact.py
- experiments/test_v61_one_token_path_contract.sh
- docs/V61_ONE_TOKEN_PATH_CONTRACT.md
- schemas/v61_one_token_path.schema.json
- v61/one_token_path.json

Verification criteria:
- `logits_parity_pass=1` requires numeric finite max/mean/tolerance and max/mean <= tolerance.
- `logits_parity_pass=1` requires valid SHA-256 evidence for tokenizer input, upstream MoE artifact, route path, layer activation trace, final hidden state, LM-head payload, candidate logits, and reference logits.
- `logits_parity_pass=1` requires token/router/trace/top-k/logit count fields to parse correctly, with `logit_count == vocab_size`.
- Candidate and reference top-k token ID lists must be parseable, have exactly `top_k_token_count` entries, and match when ranking match is claimed.
- Negative controls cover mismatched top-k lists, top-k count drift, invalid candidate logits hash, bad top-k ranking flag, mean error above tolerance, and missing activation trace hash.
- Claim boundaries remain unchanged: this is not a real logits parity pass, decode pass, release claim, or SSD-resident runtime claim.

Forbidden changes / invariants:
- Do not modify files.
- Do not run network, downloads, GPU/ROCm, checkpoint materialization, full benchmark sweeps, or remote writes.
- Do not change milestone status, artifact paths, metric definitions, acceptance thresholds, seeds, data splits, or evidence semantics.

Return only:
Changed files: none
Checks run:
Core findings:
Risks/blockers:
