# TASK: v60 propagation for D/E registry exclusion and v58 real execution readiness

Goal:
Propagate the two PM/v59e sidecar ledgers now emitted by `experiments/run_v1_0_pm_pr_claim_slice_gate.sh` and bundled by `experiments/run_v59e_one_command_pm_foundation_demo.sh` into the v60 release contract.

Scope:
- `experiments/run_v60_architecture_challenge_release_contract.sh`
- `experiments/test_v60_architecture_challenge_release_contract.sh`

File candidates:
- Source v59e sidecar files:
  - `source_pm_pr_claim_slice_gate/de_measured_registry_exclusion_rows.csv`
  - `source_pm_pr_claim_slice_gate/v58_real_execution_readiness_rows.csv`
- Existing v60 patterns around `de_30b70b_acceptance_evidence_rows.csv`, v58 acceptance evidence, summary dict, manifest dict, required_files, and manifest checks.

Verification criteria:
- `bash -n experiments/run_v60_architecture_challenge_release_contract.sh experiments/test_v60_architecture_challenge_release_contract.sh`
- `./experiments/test_v60_architecture_challenge_release_contract.sh`
- The v60 summary/manifest expose:
  - `pm_pr_de_measured_registry_exclusion_rows=2`
  - `pm_pr_de_measured_registry_fixture_registry_rows=0`
  - `pm_pr_de_measured_registry_admission_ready_rows=0`
  - `pm_pr_de_measured_registry_blocked_rows=2`
  - `pm_pr_v58_real_execution_readiness_rows=9`
  - `pm_pr_v58_real_execution_ready_rows=0`
  - `pm_pr_v58_real_execution_blocked_rows=9`
  - `pm_pr_v58_real_execution_fixture_allowed_rows=0`
- Required files include the two copied v59e sidecar CSVs under `source_v59e/source_pm_pr_claim_slice_gate/`.
- Tests inspect row content enough to prove:
  - fixture D/E rows do not enter measured registry,
  - raw answer/citation output and model/runtime evidence remain required,
  - v58 real execution requires A/B/C/D/E/G/H actual responses,
  - v58 real execution remains blocked and non-fixture-only.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, source/query splits, acceptance thresholds, or release readiness.
- Do not mark v60, v58, D/E, real release, or public comparison ready.
- Do not run downloads, GPU jobs, long benchmark sweeps, or network operations.
- Keep fixture D/E schema evidence out of measured registry.
