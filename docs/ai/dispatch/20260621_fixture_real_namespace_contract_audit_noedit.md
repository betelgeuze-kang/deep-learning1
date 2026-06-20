Goal:
Audit the P1 fixture/synthetic/real benchmark namespace contract without editing files.

Scope:
- Confirm `tools/pipeline_lib.py` exposes helpers that separate fixture,
  synthetic, and real benchmark evidence by directory and metric namespace.
- Confirm unsupported evidence families, path separators, and wrong metric
  prefixes fail closed.
- Confirm `experiments/test_p1_fixture_real_namespace_contract.sh` covers
  distinct directories, distinct metric namespaces, matching-prefix preservation,
  and negative cases.
- Confirm `scripts/ai-verify.sh` runs the new smoke.

File candidates:
- `tools/pipeline_lib.py`
- `experiments/test_p1_fixture_real_namespace_contract.sh`
- `scripts/ai-verify.sh`

Verification criteria:
- No edits.
- Report files reviewed, contract gaps, and recommended local tests.

Forbidden changes / invariants:
- Do not change files.
- Do not run network, downloads, GPU/ROCm, or long sweeps.
- Do not change benchmark protocols, metric definitions, seeds, or evidence
  thresholds.
