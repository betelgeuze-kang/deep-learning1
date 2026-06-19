Goal:
Audit whether the current v58 blind-eval protocol gates enforce the active PM goal's real-execution requirements strongly enough.

Scope:
- Read only; do not edit files.
- Focus on v58 blind eval artifacts, PM claim-slice rows, v59e/v60 propagation, and verifier checks.

File candidates:
- v58/blind_eval_real.json
- schemas/v58_blind_eval.schema.json
- tools/verify_artifact.py
- experiments/run_v58c_blind_response_evidence_intake.sh
- experiments/test_v58c_blind_response_evidence_intake.sh
- experiments/run_v58d_blind_review_return_intake.sh
- experiments/test_v58d_blind_review_return_intake.sh
- experiments/run_v1_0_pm_pr_claim_slice_gate.sh
- experiments/test_v1_0_pm_pr_claim_slice_gate.sh
- experiments/test_v59e_one_command_pm_foundation_demo.sh
- experiments/test_v60_architecture_challenge_release_contract.sh
- docs/PR2_SPLIT_PLAN.md
- docs/PR2_REWRITE_DRAFT.md

Verification criteria:
- Identify concrete gaps, if any, for these requirements:
  A/B/C/D/E/G/H actual responses, same corpus and context budget, blind identity, at least two independent reviewers, disagreement/adjudication, unseen repository split, source span exactness, unsupported abstention, and latency/memory separate from answer quality.
- Prefer gaps where a tracked contract/verifier/test can cheaply prevent false-positive ready claims.
- Report exact files/fields/tests to change, but do not change them.

Forbidden changes / invariants:
- No network, downloads, model runs, GPU/ROCm jobs, full benchmark sweeps, checkpoint materialization, or generated artifact promotion.
- Do not change metric definitions, splits, seeds, baseline criteria, or acceptance thresholds.
- Do not propose claiming v58 real execution complete unless current evidence proves actual responses and human review exist.
