Goal:
Audit the P1 content-addressed cache key contract without editing files.

Scope:
- Confirm `tools/pipeline_lib.py` exposes a deterministic cache key helper that
  includes source SHA, input SHA, environment, and config state.
- Confirm key generation is canonical/order-stable and changes when any of the
  four required axes changes.
- Confirm empty source/input/environment/config axes are rejected.
- Confirm `experiments/test_p1_content_addressed_cache_contract.sh` covers these
  cases and `scripts/ai-verify.sh` runs the smoke.

File candidates:
- `tools/pipeline_lib.py`
- `experiments/test_p1_content_addressed_cache_contract.sh`
- `scripts/ai-verify.sh`

Verification criteria:
- No edits.
- Report files reviewed, contract gaps, and recommended local tests.

Forbidden changes / invariants:
- Do not change files.
- Do not run network, downloads, GPU/ROCm, or long sweeps.
- Do not change benchmark protocols, metric definitions, seeds, or evidence
  thresholds.
