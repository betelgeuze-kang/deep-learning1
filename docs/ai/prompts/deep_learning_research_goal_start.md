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
4. Codex owns research design, task slicing, review, metric validity, evidence boundary checks, and final acceptance.
5. Use Cursor Composer 2.5 (`composer-2.5`) for large-context implementation slices, broad document/result/log sweeps, multi-file C++/script edits, and repeated low-cost implementation passes.
6. Use Cursor auto for selected code, currently open files, notebooks, or IDE-attached edits.
7. If Cursor cannot run and Codex uses an internal code-implementation sub-agent for the same slice, spawn a `worker` sub-agent with `model=gpt-5.4-mini`, `reasoning_effort=xhigh`, using `docs/ai/prompts/internal_subagent_worker_slice.md`.
8. Use one worker slice at a time. Codex must inspect the diff before another delegation.
9. Delegate only broad exploration, large mechanical edits, repeated test-fix cycles, multi-file refactors, or long docs/results/log sweeps. Do not delegate simple docs, small tests, clear localized fixes, or changes expected under roughly 100-200 LOC.
10. Worker TASK prompts should stay short: goal, scope, file candidates, verification criteria, and forbidden changes or invariants.
11. When delegating to the former OpenCode slot, create a prompt under `docs/ai/dispatch/`, using `docs/ai/prompts/opencode_worker_slice.md`, then run:

   ```bash
   ./scripts/ai-worker-opencode.sh docs/ai/dispatch/<task-id>.md
   ```

12. When delegating to Cursor auto, create a prompt under `docs/ai/dispatch/`, using `docs/ai/prompts/cursor_worker_slice.md`, then run:

   ```bash
   ./scripts/ai-worker-cursor.sh docs/ai/dispatch/<task-id>.md
   ```

13. After worker output, avoid full log review by default. Inspect `git diff --stat`, core changed-file diffs, failing-test output if present, and any research claim or evidence-boundary changes. Run `./scripts/ai-verify.sh` before acceptance.

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
