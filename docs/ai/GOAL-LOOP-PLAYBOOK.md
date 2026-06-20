# Codex + OpenCode/Cursor Research Orchestration

This repository uses Codex VS Code extension pursue-goal as the top-level loop.

```text
User gives Codex a research/implementation goal
-> Codex reads AGENTS.md and the research profile
-> Codex designs the slice and chooses a worker only when useful
-> OpenCode GLM-5.2 or Cursor auto implements one scoped slice
-> Codex inspects the diff and runs ./scripts/ai-verify.sh
-> Codex accepts, fixes, or delegates the next scoped slice
```

## Role Split

```text
Codex: goal tracking, research design, task slicing, code review, evidence review, final acceptance
OpenCode GLM-5.2: large-context code/doc/result sweeps and scoped implementation
Cursor auto: IDE-attached edits, selected-code implementation, focused test-fix passes
ai-verify.sh: local lightweight verification gate
Human owner: downloads, long GPU jobs, benchmark sweeps, remote writes, publication claims
```

## Start

Paste this into Codex VS Code extension and replace the goal block:

```text
docs/ai/prompts/deep_learning_research_goal_start.md
```

## Worker Selection

Use OpenCode GLM-5.2 for:

- long `docs/` or `results/` context
- broad `experiments/` and `src/` changes
- generated artifact contract updates
- C++/shell/Python implementation slices
- scoped implementation passes

Use Cursor auto for:

- current editor selections
- notebook-local work
- small changes around open files
- narrow implementation or validator updates
- focused test-fix loops with a clear failing check
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
