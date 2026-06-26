# Codex + Kiro/Cursor Research Orchestration

This repository uses Codex VS Code extension pursue-goal as the top-level loop.

```text
User gives Codex a research/implementation goal
-> Codex reads AGENTS.md and the research profile
-> Kiro Opus 4.8 drafts the next-code-improvement prompt when prompt design is useful
-> Codex reviews and approves the scoped worker prompt
-> Cursor Composer 2.5 (`composer-2.5`) or Cursor auto implements one scoped slice
-> Codex GPT-5.5 xhigh inspects the diff and runs ./scripts/ai-verify.sh
-> Codex accepts, fixes, or delegates the next scoped slice
```

## Role Split

```text
Codex GPT-5.5 xhigh: goal tracking, research design, task slicing, code review, evidence review, final acceptance
Kiro Opus 4.8: prompt architecture, implementation-slice design draft, risk/invariant checklist
Cursor Composer 2.5 (`composer-2.5`): large-context code/doc/result sweeps and scoped implementation
Cursor auto: IDE-attached edits and selected-code implementation
ai-verify.sh: local lightweight verification gate
Human owner: downloads, long GPU jobs, benchmark sweeps, remote writes, publication claims
```

## Start

Paste this into Codex VS Code extension and replace the goal block:

```text
docs/ai/prompts/deep_learning_research_goal_start.md
```

## Worker Selection

Use Kiro Opus 4.8 for next-code-improvement prompt design:

- convert the Codex goal into a scoped Cursor worker prompt
- identify likely file candidates and out-of-scope paths
- state research invariants and forbidden changes
- propose cheap verification criteria
- surface blockers or questions before implementation

Kiro does not edit code, mutate artifacts, change research design, or accept
results. Codex reviews the Kiro draft before Cursor runs.

Kiro is currently a manual IDE-assisted prompt-architect step. The installed
`kiro` command opens and controls the Kiro IDE; it does not provide a verified
headless Opus 4.8 worker interface for Codex to call automatically. To use
Kiro, paste `docs/ai/prompts/kiro_opus_prompt_architect.md` into Kiro, then
paste the returned `Kiro design notes` block into the dispatch review notes.

When Kiro is used, preserve the `Kiro design notes` block in the dispatch review
notes. If Codex skips Kiro for a small/local slice, record the skip reason so
the worker prompt remains traceable to a Codex-owned design decision.

Use Cursor Composer 2.5 (`composer-2.5`) for:

- long `docs/` or `results/` context
- broad `experiments/` and `src/` changes
- generated artifact contract updates
- C++/shell/Python implementation slices
- cheap repeated implementation passes

`scripts/ai-worker-opencode.sh` is kept as a compatibility wrapper for the former OpenCode slot, but it routes tasks to Cursor Composer 2.5 (`composer-2.5`).

If Cursor cannot run and Codex uses an internal code-implementation sub-agent
for the same slice, use a `worker` sub-agent with `model=gpt-5.4-mini` and
`reasoning_effort=xhigh`, using
`docs/ai/prompts/internal_subagent_worker_slice.md`.

Use Cursor auto for:

- current editor selections
- notebook-local work
- small changes around open files
- IDE-state-sensitive edits

Use only one worker slice at a time. Codex reviews before continuing.

## Verification

Default checks are intentionally lightweight:

```bash
./scripts/ai-preflight.sh
./scripts/ai-verify.sh
```

The default verify path may configure/build CMake with HIP disabled and run tiny deterministic smoke checks. It must not perform network fetches, checkpoint downloads, model generation, or long GPU/ROCm runs.

## Safety Boundary

Do not automate these without explicit user approval:

```text
git push / merge / release / publish
long training or full benchmark sweeps
GPU/ROCm stress jobs
checkpoint/model/dataset downloads
remote experiment tracker writes
cloud/resource mutation
secret rotation
destructive data operations
```
