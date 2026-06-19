# OpenCode Worker Slice

You are OpenCode Minimax M3 acting as an exploration worker for this research repository. Codex owns design, review, evidence-boundary judgment, and final acceptance.

## Goal

Audit the current PR-normalization and v58 blind-eval contracts for the smallest remaining machine-verifiable gap that would move the active PM objective forward.

## Scope

- Exploration only. Do not edit files.
- Inspect current local files and tracked results where useful.
- Focus on:
  - `pr_slices/pr2.json`
  - `docs/PR2_SPLIT_PLAN.md`
  - `v58/blind_eval_real.json`
  - `schemas/v58_blind_eval.schema.json`
  - `tools/verify_artifact.py`
  - `experiments/run_v58*.sh`
  - `experiments/test_v58*.sh`
  - `operations/review_return_workflow.json`
  - `scripts/ai-verify.sh`
- Identify one or two concrete gaps where the current contracts might allow a misleading claim about:
  - actual A/B/C/D/E/G/H responses,
  - same corpus/context budget,
  - blind identity,
  - at least two independent reviewers,
  - disagreement/adjudication,
  - unseen repository split,
  - source-span exactness,
  - unsupported abstention,
  - latency/memory separated from answer quality,
  - PR #2 split/title/body readiness.

## Verification Criteria

- Run only cheap read-only commands such as `rg`, `sed`, `git diff --stat`, and focused verifier invocations that do not mutate artifacts.
- If you run a command that fails, report the exact command and failure.
- Return a ranked recommendation for the single smallest patch Codex should make next, including exact file candidates and expected focused test.

## Forbidden Changes / Invariants

- Do not edit files.
- Do not stage, commit, push, merge, or mutate remotes.
- Do not run long benchmarks, model generation, downloads, network fetches, GPU/ROCm jobs, or checkpoint materialization.
- Do not read or print `.env`, `.env.*`, `*.env`, or `*.env.*`.
- Do not change seeds, splits, metric definitions, leakage controls, baseline protocol, acceptance thresholds, or reviewer independence requirements.
- Do not treat fixture/supplied mechanics as real blind-eval execution evidence.

## Return Format

Return only:

- changed files: `none`
- test results
- failing test names
- core audit summary
- blockers
- specific files or diffs needing Codex review
