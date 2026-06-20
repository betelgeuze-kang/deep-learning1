Goal:
Audit the P1 atomic run directory contract change without editing files.

Scope:
- Confirm `tools/pipeline_lib.py` exposes a reusable atomic run-dir helper that
  publishes a new `<stage_id>/<run_id>` directory only after artifacts and
  `summary.csv` are written.
- Confirm failed runs clean temporary directories and do not publish final run
  directories.
- Confirm existing final run directories are not overwritten.
- Confirm `experiments/test_p1_atomic_run_dir_contract.sh` covers success,
  failure cleanup, missing summary, and bad path segment cases.
- Confirm `scripts/ai-verify.sh` runs the new contract smoke.

File candidates:
- `tools/pipeline_lib.py`
- `experiments/test_p1_atomic_run_dir_contract.sh`
- `scripts/ai-verify.sh`

Verification criteria:
- No edits.
- Report files reviewed, contract gaps, and recommended local tests.

Forbidden changes / invariants:
- Do not change files.
- Do not run network, downloads, GPU/ROCm, or long sweeps.
- Do not change benchmark protocols, metric definitions, seeds, or evidence
  thresholds.
