# Deep Learning Research Profile

Use this profile for work touching model architecture, routing, training/evaluation loops, benchmark evidence, checkpoint handling, result packets, reproducibility, or research claims.

## Role Split

```text
Codex: research plan, experiment design, metric validity, evidence boundary review, final acceptance
OpenCode Minimax M3: large-context implementation, doc/log/result sweeps, broad edits, synthetic checks
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

Prefer OpenCode Minimax M3 for:

- reading long roadmap, benchmark, evidence, or result packet context
- adding or updating C++ experiment logic across several files
- adding shell/Python validators for a scoped experiment gate
- updating generated-artifact contracts, manifests, and smoke tests
- broad mechanical edits across `docs/`, `experiments/`, and `src/`

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

Every delegated worker slice should specify:

```text
Task:
Files in scope:
Files out of scope:
Allowed runtime:
Dataset/checkpoint/network policy:
Acceptance criteria:
Verification allowed:
Forbidden changes:
```

If runtime is not specified, assume local lightweight checks only.
