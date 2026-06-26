# Deep Learning Research Profile

Use this profile for work touching model architecture, routing, training/evaluation loops, benchmark evidence, checkpoint handling, result packets, reproducibility, or research claims.

## Role Split

```text
Codex GPT-5.5 xhigh: research plan, experiment design, metric validity, evidence boundary review, final acceptance
Kiro Opus 4.8: prompt architecture, implementation-slice design draft, risk/invariant checklist
Cursor Composer 2.5 (`composer-2.5`): large-context implementation, doc/log/result sweeps, broad edits, synthetic checks
Cursor auto: current editor/selection/notebook-local edits
Human owner: long runs, GPU/ROCm budget, downloads, remote writes, publication claims
```

## Project-Specific Context

- Core C++ code lives under `src/`.
- Experiment launchers and smoke gates live under `experiments/`.
- Research plans and claim boundaries live under `docs/`.
- Generated evidence and run packets live under `results/`; most of this tree is intentionally ignored by git.
- `build/` is generated CMake output.
- Current roadmap heavily uses v61 checkpoint/SSD/MoE evidence gates. Avoid materializing checkpoint payloads unless explicitly authorized.

## Routing

Default next-code-improvement chain:

```text
Codex goal owner
-> Kiro Opus 4.8 prompt design using docs/ai/prompts/kiro_opus_prompt_architect.md
-> Cursor Composer 2.5 (`composer-2.5`) implementation
-> Codex GPT-5.5 xhigh diff review, evidence-boundary review, ./scripts/ai-verify.sh, acceptance
```

Use Kiro Opus 4.8 when the next improvement needs a designed command prompt,
task decomposition, file candidates, invariants, or verification criteria before
implementation. Kiro drafts the worker prompt only; Codex reviews it before any
implementation worker runs.

Kiro is currently manual rather than a headless worker in this repository. The
local `kiro` CLI is the IDE command and does not expose a verified stdout
prompt-response interface. If Kiro is used, the human/Codex operator must paste
`docs/ai/prompts/kiro_opus_prompt_architect.md` into Kiro and preserve the
returned `Kiro design notes` block. If Kiro is skipped, record the skip reason
in the dispatch notes.

Prefer Cursor Composer 2.5 (`composer-2.5`) for:

- reading long roadmap, benchmark, evidence, or result packet context
- adding or updating C++ experiment logic across several files
- adding shell/Python validators for a scoped experiment gate
- updating generated-artifact contracts, manifests, and smoke tests
- broad mechanical edits across `docs/`, `experiments/`, and `src/`

`scripts/ai-worker-opencode.sh` remains as a compatibility wrapper for existing dispatch habits, but it now routes the former OpenCode worker slot to Cursor Composer 2.5 (`composer-2.5`).

If Cursor cannot run and Codex uses an internal sub-agent for the same
code-implementation slice, spawn a `worker` sub-agent with:

```text
model=gpt-5.4-mini
reasoning_effort=xhigh
prompt_template=docs/ai/prompts/internal_subagent_worker_slice.md
```

This is a fallback worker for the same slice, not a nested autonomous loop.

Prefer Cursor auto for:

- small localized C++ edits around an open file
- selected shell/Python script edits
- notebook or editor-state-dependent changes
- quick UI/editor affordance work

Keep Codex responsible for:

- deciding whether a proposed experiment answers the research question
- checking claims against fixture/real evidence boundaries
- ensuring metric, seed, split, and baseline contracts did not drift
- deciding whether worker output is accepted

## Verification Ladder

Use the cheapest meaningful checks first:

```text
1. shell/C++/Python syntax checks
2. CMake configure/build with HIP disabled unless explicitly requested
3. tiny deterministic executable smoke runs
4. scoped experiment test script
5. user-approved longer GPU/ROCm or benchmark execution
```

Default verification must not perform network fetches, checkpoint downloads, model generation, or long training.

## Worker Prompt Checklist

Every delegated worker slice should stay short and specify only:

```text
Goal:
Scope:
File candidates:
Verification criteria:
Forbidden changes / invariants:
```

If runtime, dataset/checkpoint/network policy, or forbidden changes are not specified, assume local lightweight checks only; no downloads, long GPU/ROCm jobs, checkpoint materialization, remote writes, or invariant changes.

Worker output should be limited to:

```text
Changed files:
Test results:
Failing test names:
Core diff summary:
Blockers:
Specific files/diffs needing Codex review:
```

Codex should not read full worker logs by default. Review the diff, relevant changed files, failing-test output if present, and any evidence-boundary or research-claim changes before acceptance.
