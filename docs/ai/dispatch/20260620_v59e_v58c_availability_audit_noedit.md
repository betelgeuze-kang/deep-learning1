Goal:
Audit why the v59e PM foundation demo reports v58c_intake_artifact_available=0 even after v58c blind response intake smoke can emit the 4000-row A/B/C/D/E/F/G/H template artifact.

Scope:
- Read only. Do not edit files.
- Focus on:
  - experiments/run_v59e_one_command_pm_foundation_demo.sh
  - experiments/test_v59e_one_command_pm_foundation_demo.sh
  - examples/v1_0_architecture_challenge_pm_foundation_demo.sh
  - experiments/run_v58c_blind_response_evidence_intake.sh
  - experiments/test_v58c_blind_response_evidence_intake.sh
  - results/v58c_blind_response_evidence_intake_summary.csv if present
  - results/v58c_blind_response_evidence_intake/intake_001/

Verification criteria:
- Identify the exact availability predicate that makes v59e choose the v58c dependency blocker path.
- Identify whether the predicate is stale after the v58b/v58c template expansion.
- Identify the minimal edit set needed for v59e to copy the ready v58c intake artifact when it is already present, while still refusing implicit v57/v58 seed rebuilds.
- Confirm release/public comparison claims remain blocked: v58_ready=0, required_blind_response_ready=0, human_blind_review_ready=0.

Forbidden changes / invariants:
- Do not change benchmark protocol, metrics, seeds, splits, thresholds, or claim boundaries.
- Do not run long benchmarks, GPU/ROCm work, downloads, network commands, checkpoint materialization, model generation, or remote mutations.
- Do not modify files.

Return only:
- Files inspected.
- Availability predicate and why it fails.
- Proposed minimal edit set.
- Commands run.
- Any unresolved risks.
