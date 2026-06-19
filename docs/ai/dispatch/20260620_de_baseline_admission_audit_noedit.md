Goal:
Audit D/E 30B/70B baseline admission guard coverage for the active PR #2 normalization goal.

Scope:
Read-only audit across baselines/, pr_slices/, tools/, experiments/, docs/, and results/v1_0_pm_pr_claim_slice_gate/gate_001/.

File candidates:
- baselines/de_30b70b_real.json
- pr_slices/pr2.json
- tools/verify_artifact.py
- experiments/run_v1_0_pm_pr_claim_slice_gate.sh
- experiments/test_v1_0_pm_pr_claim_slice_gate.sh
- experiments/run_v52*.sh
- experiments/test_v52*.sh
- docs/PR2_SPLIT_PLAN.md
- docs/PR2_REWRITE_DRAFT.md

Verification criteria:
- Identify whether fixture/schema-test D/E rows can enter any measured registry or public comparison row.
- Identify whether the PR2 v52 slice verification commands validate both D/E PM ledgers:
  - de_measured_registry_exclusion_rows.csv
  - de_30b70b_acceptance_evidence_rows.csv
- Identify whether all 11 real evidence fields are enforced for both D and E.
- Identify whether any docs imply D/E measured readiness without real pinned model repository, revision, quantization, artifact hash, runtime, prompt, budgets, hardware, seed, raw output, and evaluator version.
- Keep output short: changed files must be "none"; include findings with file paths and line numbers where possible, plus a short recommendation.

Forbidden changes / invariants:
- Do not edit files.
- Do not run network, downloads, model generation, GPU/ROCm jobs, checkpoint materialization, or long benchmark sweeps.
- Do not change seeds, splits, metrics, evidence boundaries, acceptance thresholds, generated results, or release/public-comparison claims.
