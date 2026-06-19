# OpenCode Worker Slice: v52 Baseline Admission Contract Audit

Goal:
Audit whether the v52 C 7B actual adapter packet and D/E 30B/70B intake guard prevent fixture evidence from entering measured registry or public comparison claims.

Scope:
Read-only exploration only. Do not edit files.

File candidates:
- `baselines/v52_adapter_guard.json`
- `baselines/de_30b70b_real.json`
- `schemas/v52_adapter_guard.schema.json`
- `schemas/de_30b70b_real.schema.json`
- `tools/verify_artifact.py`
- `experiments/run_v52l_7b14b_local_model_rag_v53e_1000.sh`
- `experiments/test_v52l_7b14b_local_model_rag_v53e_1000.sh`
- `experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh`
- `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh`
- `pr_slices/pr2.json`

Verification criteria:
- Identify if C 7B packet is clearly separated from quality/public-comparison claims.
- Identify if D/E fixture rows are barred from measured registry admission.
- Identify missing required real-evidence fields, row artifacts, or verifier checks.

Forbidden changes / invariants:
- No edits.
- No downloads, network fetches, GPU/ROCm jobs, checkpoint materialization, model generation, or long benchmark runs.
- Do not read or print `.env*`.
- Do not change seeds, splits, metric definitions, baseline protocol, acceptance thresholds, or artifact contents.

Output:
Limit output to:
- Checked files
- Concrete contract/verifier gaps
- Suggested exact fields or checks
- Blockers
