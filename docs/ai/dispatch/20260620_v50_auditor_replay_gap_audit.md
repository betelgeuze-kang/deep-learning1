Goal:
Audit the current v50 auditor correctness replay blocker and identify the smallest local change that would improve replay-artifact evidence without changing research claims.

Scope:
- Inspect v50-related files only: audits/v50_public_repo_auditor_correctness.json, results/v50_public_repo_auditor_3repo*, tools/verify_artifact.py, experiments/test_v1_0_pm_pr_claim_slice_gate.sh, docs/PR2* if needed.
- Determine which required v50 artifacts are missing, present-but-untracked, schema-invalid, or only blocked by verifier/test metadata.

File candidates:
- audits/v50_public_repo_auditor_correctness.json
- results/v50_public_repo_auditor_3repo*
- tools/verify_artifact.py
- experiments/test_v1_0_pm_pr_claim_slice_gate.sh
- docs/PR2_SPLIT_PLAN.md
- pr_slices/pr2.json

Verification criteria:
- Use only local lightweight commands.
- Do not run network, downloads, public source refresh, model generation, GPU/ROCm jobs, or long benchmarks.
- Report exact commands run and exact failing/passing fields.

Forbidden changes / invariants:
- Exploration only; do not edit files.
- Do not promote v50 auditor correctness to ready unless real replay artifacts are present and hash-bound.
- Do not change seeds, data splits, metric definitions, evidence boundaries, or acceptance thresholds.
- Keep fixture/simulated/replayed status explicit.

Output:
- Changed files: none.
- Core finding: missing/present v50 artifacts and the smallest safe next patch.
- Test results or commands run.
- Blockers that require human approval or external network.
