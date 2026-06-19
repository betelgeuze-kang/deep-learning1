# OpenCode Worker Slice: v50 Artifact Contract Audit

Goal:
Audit whether the v50 auditor correctness contract and verifier actually prove replayable artifact shape, not just path presence or summary flags.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `audits/v50_public_repo_auditor_correctness.json`
- `schemas/v50_auditor_correctness.schema.json`
- `tools/verify_artifact.py`
- `experiments/run_v50_public_repo_auditor_3repo.sh`
- `experiments/test_v50_public_repo_auditor_3repo.sh`
- `results/v50_public_repo_auditor_3repo_*`
- `results/commercial_return/*`

Verification criteria:
- Identify required v50 artifacts and their current CSV/header contracts.
- Identify verifier gaps where a false-positive ready/pass state could occur.
- Recommend the smallest contract/verifier additions needed to preserve claim boundaries.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, or long benchmark runs.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, leakage controls, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Current checked files/artifacts
- Concrete verifier/schema/contract gaps
- Suggested exact fields or checks
- Any blockers
