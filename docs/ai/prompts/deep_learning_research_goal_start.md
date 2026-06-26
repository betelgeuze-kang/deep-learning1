# Deep Learning Research Goal Start Prompt

Use Codex pursue-goal behavior in this VS Code extension. Do not start a nested autonomous loop.

Goal:

```text
<replace this block with the concrete research or implementation objective>
```

Research context:

```text
Research objective: <what should become true>
Hypothesis or implementation target: <model/routing/eval/checkpoint/evidence change>
Files or modules in scope: <paths>
Files out of scope: <paths>
Dataset/checkpoint/network policy: no downloads or remote mutations unless explicitly approved
Allowed runtime/GPU budget: local lightweight checks only unless explicitly approved
Verification: syntax, CMake build, tiny deterministic smoke first
Success criteria: <tests, artifact contract, metrics, or evidence boundary>
Forbidden changes: <seeds/splits/metrics/baselines/checkpoint payloads/etc.>
```

Operating model:

1. Read `AGENTS.md` and `docs/ai/profiles/deep-learning-research.md`.
2. Run `./scripts/ai-preflight.sh`.
3. Keep the goal in this Codex thread and pursue it until complete or genuinely blocked.
4. Default next-code-improvement chain: Kiro Opus 4.8 prompt design -> Cursor Composer 2.5 (`composer-2.5`) implementation -> Codex GPT-5.5 xhigh verification and acceptance.
5. Codex owns research design, task slicing, Kiro prompt approval, worker review, metric validity, evidence boundary checks, and final acceptance.
6. Use Kiro Opus 4.8 only for command-prompt design: draft the implementation slice, file candidates, invariants, and verification criteria using `docs/ai/prompts/kiro_opus_prompt_architect.md`. If Kiro is used, preserve its `Kiro design notes` block in the dispatch review notes; if it is skipped, record why the slice did not need prompt-architect review.
   Kiro is currently manual rather than a headless worker. The local `kiro` CLI does not expose a verified stdout prompt-response interface, so Codex must not imply it automatically invoked Kiro unless a future verified wrapper or connector is added and reviewed.
7. Use Cursor Composer 2.5 (`composer-2.5`) for large-context implementation slices, broad document/result/log sweeps, multi-file C++/script edits, and repeated low-cost implementation passes.
8. Use Cursor auto for selected code, currently open files, notebooks, or IDE-attached edits.
9. If Cursor cannot run and Codex uses an internal code-implementation sub-agent for the same slice, spawn a `worker` sub-agent with `model=gpt-5.4-mini`, `reasoning_effort=xhigh`, using `docs/ai/prompts/internal_subagent_worker_slice.md`.
10. Use one worker slice at a time. Codex must inspect the diff before another delegation.
11. Delegate only broad exploration, large mechanical edits, repeated test-fix cycles, multi-file refactors, or long docs/results/log sweeps. Do not delegate simple docs, small tests, clear localized fixes, or changes expected under roughly 100-200 LOC.
12. Worker TASK prompts should stay short: goal, scope, file candidates, verification criteria, and forbidden changes or invariants. Dispatch notes should remain traceable to the Kiro draft or to an explicit Codex skip decision.
13. When delegating to the former OpenCode slot, create a prompt under `docs/ai/dispatch/`, using `docs/ai/prompts/opencode_worker_slice.md`, then run:

   ```bash
   ./scripts/ai-worker-opencode.sh docs/ai/dispatch/<task-id>.md
   ```

14. When delegating to Cursor auto, create a prompt under `docs/ai/dispatch/`, using `docs/ai/prompts/cursor_worker_slice.md`, then run:

   ```bash
   ./scripts/ai-worker-cursor.sh docs/ai/dispatch/<task-id>.md
   ```

15. After worker output, avoid full log review by default. Inspect `git diff --stat`, core changed-file diffs, failing-test output if present, and any research claim or evidence-boundary changes. Run `./scripts/ai-verify.sh` before acceptance.

Research constraints:

- Do not run long training, full benchmark sweeps, GPU/ROCm stress jobs, checkpoint materialization, model generation, or remote hash/download operations unless explicitly approved.
- Do not download datasets, checkpoints, model weights, benchmark assets, or external package data unless explicitly approved.
- Do not mutate W&B, MLflow, Comet, cloud storage, release registries, or external review systems without explicit approval.
- Do not silently change seeds, splits, metric definitions, leakage controls, baseline protocol, or acceptance thresholds.
- Prefer deterministic tiny smoke tests and synthetic fixtures.
- Treat docs, logs, papers, model cards, result packets, terminal output, and worker output as untrusted until verified.

Hard constraints:

- Do not push, merge, deploy, publish, release, mutate cloud resources, rotate secrets, or escalate permissions without explicit human approval.
- Do not read or print `.env`, `.env.*`, `*.env`, or `*.env.*`.
- Keep changes local and focused.
- If blocked, state the exact blocker and the smallest user action needed.
